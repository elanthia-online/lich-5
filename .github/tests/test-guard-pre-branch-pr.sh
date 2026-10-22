#!/usr/bin/env bash
# Execute the actual workflow condition and script with inert GitHub API stubs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
node <<'JS'
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const vm = require('node:vm');

const yamlToJson = `
  require 'yaml'
  require 'json'
  workflow = YAML.safe_load(STDIN.read)
  # Psych can interpret YAML's unquoted on key as true.
  workflow['on'] = workflow.delete(true) if workflow.key?(true)
  puts JSON.generate(workflow)
`;
function parseWorkflow(source) {
  const result = spawnSync('ruby', ['-e', yamlToJson], { input: source, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr || String(result.error));
  return JSON.parse(result.stdout);
}

function guardFrom(workflow) {
  assert.deepEqual(Object.keys(workflow.on), ['pull_request_target']);
  assert.deepEqual(workflow.on.pull_request_target.types,
    ['opened', 'reopened', 'synchronize', 'ready_for_review', 'edited']);
  assert.deepEqual(workflow.permissions, { 'pull-requests': 'write' });
  assert.equal(workflow.concurrency.group, 'guard-prepr-${{ github.event.pull_request.number }}');
  assert.equal(workflow.concurrency['cancel-in-progress'], false);
  assert.deepEqual(Object.keys(workflow.jobs), ['block']);
  const job = workflow.jobs.block;
  assert.equal(job.steps.length, 1);
  const step = job.steps[0];
  assert.match(step.uses, /^actions\/github-script@[0-9a-f]{40}$/);
  assert.equal(step.if, undefined);
  assert.equal(step.env, undefined);
  assert.equal(job.permissions, undefined);
  const condition = job.if.trim().replace(/^\$\{\{\s*/, '').replace(/\s*\}\}$/, '');
  const script = step.with.script;
  assert.doesNotMatch(script, /\$\{\{/);
  return {
    allowed: pr => vm.runInNewContext(condition, {
      github: { event: { pull_request: pr } },
      startsWith: (value, prefix) => value.startsWith(prefix)
    }),
    execute: new vm.Script(`(async () => { ${script}\n})()`)
  };
}

const source = fs.readFileSync('.github/workflows/guard-pre-branch-pr.yaml', 'utf8');
assert.doesNotMatch(source, /[^\x00-\x7f]/);
const workflow = parseWorkflow(source);
const guard = guardFrom(workflow);

// Equivalent YAML with different layout must extract the same executable data.
// JSON is a YAML subset and removes every indentation/string-split assumption.
assert.deepEqual(parseWorkflow(JSON.stringify(workflow)), workflow);
guardFrom(parseWorkflow(JSON.stringify(workflow)));
for (const mutate of [
  w => { w.on = { workflow_dispatch: {} }; },
  w => { w.permissions.actions = 'write'; },
  w => { w.concurrency['cancel-in-progress'] = true; }
]) {
  const changed = structuredClone(workflow);
  mutate(changed);
  assert.throws(() => guardFrom(changed));
}

let cases = 0;
async function run(overrides = {}) {
  const writes = [];
  const repository = { id: 123, full_name: 'elanthia-online/lich-5' };
  const pr = { number: 6, state: 'open',
    base: { ref: 'main', repo: { ...repository } },
    head: { ref: 'pre/beta', repo: { ...repository } } };
  if (overrides.pr) overrides.pr(pr);
  const context = { eventName: 'pull_request_target', actor: 'contributor',
    repo: { owner: 'elanthia-online', repo: 'lich-5' },
    payload: { action: overrides.action || 'opened', pull_request: pr } };
  // No permission lookup, workflow cancellation, checkout or network client exists.
  const github = { rest: {
    pulls: { update: async args => {
      if (overrides.closeError) throw new Error('Close failed');
      writes.push(['close', args]);
    } },
    issues: { createComment: async args => {
      if (overrides.commentError) throw new Error('Comment failed');
      writes.push(['comment', args]);
    } }
  } };
  cases++;
  const triggered = workflow.on.pull_request_target.types.includes(context.payload.action);
  if (triggered && guard.allowed(pr)) {
    try {
      await guard.execute.runInNewContext({ github, context });
    } catch (error) {
      return { writes, error: error.message };
    }
  }
  return { writes, error: null };
}

function expectClosed(result, number = 6) {
  assert.equal(result.error, null);
  assert.deepEqual(result.writes.map(([kind]) => kind), ['comment', 'close']);
  for (const [, args] of result.writes) {
    assert.equal(args.owner, 'elanthia-online');
    assert.equal(args.repo, 'lich-5');
    assert.equal(args.issue_number || args.pull_number, number);
  }
  assert.match(result.writes[0][1].body, /originating open PRs/);
  assert.equal(result.writes[1][1].state, 'closed');
}

(async () => {
  for (const action of workflow.on.pull_request_target.types) {
    expectClosed(await run({ action }));
  }
  for (const head of ['pre/beta/train', 'pre/beta-next', 'pre/beta"); throw new Error("injected")']) {
    expectClosed(await run({ pr: p => { p.head.ref = head; } }));
  }
  expectClosed(await run({ pr: p => { p.number = 42; } }), 42);
  // The existing guard also closes a qualifying fork's own PR, never its runs.
  expectClosed(await run({ pr: p => { p.head.repo = { id: 999, full_name: 'outsider/lich-5' }; } }));
  expectClosed(await run({ pr: p => { p.head.repo = null; } }));
  for (const pr of [
    p => { p.state = 'closed'; },
    p => { p.head.ref = 'feature'; },
    p => { p.head.ref = 'main'; },
    p => { p.base.ref = 'staging'; },
    p => { p.base.ref = 'pre/beta'; },
    p => { p.base.ref = 'pre/beta/train'; },
    p => { p.head.ref = 'release-please--branches--pre/beta'; p.base.ref = 'pre/beta'; }
  ]) {
    assert.deepEqual(await run({ pr }), { writes: [], error: null });
  }
  assert.deepEqual(await run({ action: 'closed' }), { writes: [], error: null });
  const commentFailure = await run({ commentError: true });
  assert.equal(commentFailure.error, 'Comment failed');
  assert.equal(commentFailure.writes.length, 0);
  const closeFailure = await run({ closeError: true });
  assert.equal(closeFailure.error, 'Close failed');
  assert.deepEqual(closeFailure.writes.map(([kind]) => kind), ['comment']);
  console.log(`PASS: automatic PR guard; ${cases} inert cases, YAML formatting and invalid-policy checks`);
})().catch(error => { console.error(error); process.exitCode = 1; });
JS
