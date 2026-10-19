#!/usr/bin/env bash
# Execute the actual workflow script with inert GitHub API stubs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
node <<'JS'
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const workflow = fs.readFileSync('.github/workflows/guard-pre-branch-pr.yaml', 'utf8');
const trigger = workflow.split('\non:\n')[1].split('\nconcurrency:')[0];
assert.match(trigger, /^  workflow_dispatch:\n/);
assert.doesNotMatch(trigger, /pull_request|push:|workflow_run|repository_dispatch/);
assert.match(trigger, /required: true\n        type: string/);
assert.match(workflow, /permissions:\n  contents: read\n  pull-requests: write\n/);
assert.doesNotMatch(workflow, /actions: write|gh api|checkout@|cancel-in-progress: true|[^\x00-\x7f]/);
assert.match(workflow, /PR_NUMBER: \$\{\{ inputs.pr_number \}\}/);
assert.match(workflow, /TRIGGERING_ACTOR: \$\{\{ github.triggering_actor \}\}/);
const condition = workflow.match(/    if: \$\{\{ (.*?) \}\}/)[1];
const allowed = github => vm.runInNewContext(condition, { github });
assert.equal(allowed({ event_name: 'workflow_dispatch', ref: 'refs/heads/main' }), true);
for (const event_name of ['pull_request_target', 'pull_request', 'workflow_run', 'push']) {
  assert.equal(allowed({ event_name, ref: 'refs/heads/main' }), false);
}
assert.equal(allowed({ event_name: 'workflow_dispatch', ref: 'refs/heads/pre/beta' }), false);
const scriptBlock = workflow.split('          script: |\n');
assert.equal(scriptBlock.length, 2);
const script = scriptBlock[1].split('\n').map(line => line.replace(/^            /, '')).join('\n');
assert.doesNotMatch(script, /\$\{\{/);
const execute = new vm.Script(`(async () => { ${script}\n})()`);
let cases = 0;

// Each case gets a fresh API and PR. No network capability enters the sandbox.
async function run(overrides = {}) {
  const writes = [];
  const failures = [];
  const reads = [];
  const repository = { id: 123, full_name: 'elanthia-online/lich-5' };
  const pr = { number: 6, state: 'open', merged: false,
    base: { ref: 'main', repo: { ...repository } },
    head: { ref: 'pre/beta', sha: 'a'.repeat(40), repo: { ...repository } } };
  if (overrides.pr) overrides.pr(pr);
  const context = { eventName: 'workflow_dispatch', ref: 'refs/heads/main', actor: 'admin',
    repo: { owner: 'elanthia-online', repo: 'lich-5' }, payload: { repository }, ...overrides.context };
  const github = { rest: {
    repos: { getCollaboratorPermissionLevel: async args => {
      reads.push(['permission', args]);
      if (overrides.permissionError) throw new Error('Permission lookup failed');
      return { data: { permission: overrides.permission || 'admin' } };
    } },
    pulls: {
      get: async args => { reads.push(['pr', args]); return { data: pr }; },
      update: async args => { writes.push(['close', args]); }
    },
    issues: { createComment: async args => { writes.push(['comment', args]); } }
  } };
  await execute.runInNewContext({ github, context,
    process: { env: { PR_NUMBER: '6', TRIGGERING_ACTOR: 'admin', ...overrides.env } },
    core: { setFailed: message => failures.push(message) } });
  cases++;
  return { writes, failures, reads };
}

// The positive control proves the executable script still performs its purpose.
(async () => {
  const good = await run();
  assert.equal(good.failures.length, 0);
  assert.deepEqual(good.writes.map(([kind]) => kind), ['comment', 'close']);
  for (const [, args] of good.writes) {
    assert.equal(args.owner, 'elanthia-online');
    assert.equal(args.repo, 'lich-5');
    assert.equal(args.issue_number || args.pull_number, 6);
  }
  for (const eventName of ['pull_request_target', 'pull_request', 'workflow_run', 'push']) {
    assert.equal((await run({ context: { eventName } })).writes.length, 0);
  }
  for (const permission of ['write', 'maintain', 'read', 'none']) {
    assert.equal((await run({ permission })).writes.length, 0);
  }
  assert.equal((await run({ context: { ref: 'refs/heads/pre/beta' } })).writes.length, 0);
  assert.equal((await run({ env: { TRIGGERING_ACTOR: 'other-user' } })).writes.length, 0);
  for (const PR_NUMBER of ['', '0', '-1', '1.5', '6; process.exit()', '9007199254740992']) {
    const result = await run({ env: { PR_NUMBER } });
    assert.equal(result.writes.length, 0);
    assert.equal(result.reads.length, 0);
  }
  for (const pr of [
    p => { p.number = 7; },
    p => { p.state = 'closed'; },
    p => { p.merged = true; },
    p => { p.base.ref = 'staging'; },
    p => { p.head.ref = 'feature'; },
    p => { p.head.sha = 'not-a-sha'; },
    p => { p.head.repo = null; },
    p => { p.base.repo.id = 999; },
    p => { p.head.repo.id = 999; },
    p => { p.base.repo.full_name = 'other/lich-5'; },
    // A fork with the exact same branch name/SHA cannot cause writes.
    p => { p.head.repo = { id: 999, full_name: 'outsider/lich-5' }; }
  ]) {
    assert.equal((await run({ pr })).writes.length, 0);
  }
  await assert.rejects(run({ permissionError: true }), /Permission lookup failed/);
  const quoted = await run({ pr: p => { p.head.ref = 'pre/beta"; throw new Error("injected")'; } });
  assert.equal(quoted.failures.length, 0);
  assert.equal(quoted.writes.length, 2);
  console.log(`PASS: actual workflow guard; ${cases} inert execution cases and trigger/permission wiring`);
})().catch(error => { console.error(error); process.exitCode = 1; });
JS
