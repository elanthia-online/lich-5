const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = name => fs.readFileSync(path.join(__dirname, '../..', name), 'utf8').replace(/\r\n/g, '\n');
const workflow = read('.github/workflows/macos_webui.yaml');
const native = workflow.split('\n  macos_native:\n')[1];
assert.ok(native, 'expected focused macOS native coverage');

test('macOS coverage runs when CI calls it or on a manual dispatch, and on no other event', () => {
  assert.match(workflow, /^on:\n  workflow_call:\n  workflow_dispatch:\n\npermissions:/m);
  assert.doesNotMatch(workflow, /^  (push|pull_request|pull_request_target|pull_request_review|workflow_run|schedule):/m);
  assert.doesNotMatch(workflow, /^\s*concurrency:/m);
});

test('macOS coverage has no gate of its own: CI decides whether to call it', () => {
  const jobs = [...workflow.slice(workflow.indexOf('\njobs:\n')).matchAll(/^ {2}([A-Za-z_][\w-]*):$/gm)].map(match => match[1]);
  assert.deepEqual(jobs, ['macos_native']);
  assert.doesNotMatch(native, /^    (if|needs):/m);
  assert.doesNotMatch(workflow, /getCollaboratorPermissionLevel|github\.actor|triggering_actor|github\.repository ==/);
});

test('macOS runs two real native scenarios and the packaged helper within a bounded read-only job', () => {
  assert.match(native, /runs-on: macos-15\n    timeout-minutes: 10/);
  assert.match(workflow, /permissions:\n  contents: read\n/);
  assert.doesNotMatch(workflow, /(?:^\s*[\w-]+: write$|permissions: write-all|continue-on-error:)/m);
  for (const action of [...workflow.matchAll(/uses: ([^\n]+)/g)].map(match => match[1])) {
    assert.match(action, /^[\w/-]+@[0-9a-f]{40}(?: #.*)?$/);
  }
  assert.match(native, /persist-credentials: false/);
  assert.match(native, /ruby-version: '4\.0\.9'\n          bundler: none\n          bundler-cache: false/);
  assert.match(native, /gem install os ffi --no-document/);
  assert.match(native, /NATIVE_HOST: '1'/);
  const rspec = [...native.matchAll(/^\s+rspec (.+)$/gm)].map(match => match[1]);
  assert.equal(rspec.length, 1);
  assert.match(rspec[0], /^spec\/lib\/webui\/native_host_presentation_spec\.rb --tag native_host /);
  assert.match(native, /assert data\['summary'\]\['example_count'\] == 2/);
  assert.match(native, /assert data\['summary'\]\['pending_count'\] == 0/);
  assert.match(native, /assert all\(e\['status'\] == 'passed' for e in data\['examples'\]\)/);
  assert.match(native, /zsh lib\/webui\/native\/macos\/build\.sh\n          python3 \.github\/scripts\/macos_webui_smoke\.py/);
  assert.match(native, /if: always\(\)\n        uses: actions\/upload-artifact@/);
  assert.doesNotMatch(workflow, /testbed|Disposable/);
});
