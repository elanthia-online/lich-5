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
  assert.equal(workflow.concurrency['cancel-in-progress'], true);
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
      // GitHub string equality ignores case; normalize the compared fields.
      github: { event: { pull_request: { ...pr,
        state: pr.state.toLowerCase(),
        base: { ...pr.base, ref: pr.base.ref.toLowerCase() }
      } } },
      startsWith: (value, prefix) => value.toLowerCase().startsWith(prefix.toLowerCase())
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
  w => { w.concurrency['cancel-in-progress'] = false; }
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
  for (const head of ['pre/beta/train', 'pre/beta-next', 'PRE/BETA', 'Pre/Beta-x',
    'pre/beta"); throw new Error("injected")']) {
    expectClosed(await run({ pr: p => { p.head.ref = head; } }));
  }
  expectClosed(await run({ pr: p => { p.number = 42; } }), 42);
  expectClosed(await run({ pr: p => { p.base.ref = 'MAIN'; } }));
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

  // Exercise the actual CI preflight for both supported event types.
  const ci = parseWorkflow(fs.readFileSync('.github/workflows/rspec_tests.yaml', 'utf8'));
  const preflight = ci.jobs.test.steps.find(step => step.id === 'preflight').with.script;
  const classify = new vm.Script(`(async () => { ${preflight}\n})()`);
  const guardFiles = ['.github/workflows/guard-pre-branch-pr.yaml',
    '.github/workflows/rspec_tests.yaml', '.github/tests/test-guard-pre-branch-pr.sh'];
  let preflightCases = 0;
  for (const eventName of ['pull_request', 'push']) {
    for (const [paths, expected] of [
      [guardFiles, 'false'],
      [[...guardFiles, 'lib/lich.rb'], 'true'],
      [['spec/example_spec.rb'], 'true'],
      [['Gemfile'], 'true'],
      [['.github/tests/test-other.sh'], 'true'],
      [[], 'true']
    ]) {
      const files = paths.map(filename => ({ filename, status: 'modified' }));
      const outputs = {};
      await classify.runInNewContext({
        context: { repo: { owner: 'fixture', repo: 'fixture' }, eventName,
          payload: { pull_request: { number: 6 }, before: 'before' }, sha: 'after' },
        github: { paginate: async () => files, rest: {
          pulls: { listFiles: () => {} },
          repos: { compareCommits: async () => ({ data: { files } }) }
        } },
        core: { notice: () => {}, setOutput: (key, value) => { outputs[key] = value; } }
      });
      assert.equal(outputs.should_test, expected, `${eventName}: ${paths.join(', ')}`);
      preflightCases++;
    }
  }
  console.log(`PASS: RSpec preflight; ${preflightCases} inert cases`);
})().catch(error => { console.error(error); process.exitCode = 1; });
JS
