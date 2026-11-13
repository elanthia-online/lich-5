const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const read = name => fs.readFileSync(path.join(__dirname, '../..', name), 'utf8').replace(/\r\n/g, '\n');
const workflow = read('.github/workflows/macos_webui.yaml');
const windows = read('.github/workflows/windows_webui.yaml');
const authorization = workflow.split('\n  authorize:\n')[1]?.split('\n  macos_native:\n')[0];
assert.ok(authorization, 'expected authorization before macOS coverage');
const guard = authorization.match(/^    if: >-\n((?:      .+\n)+)/m)?.[1].trim();
const native = workflow.split('\n  macos_native:\n')[1];
assert.ok(native, 'expected focused macOS native coverage');
const executionGuard = native.match(/^    if: (.+)$/m)?.[1];

test('macOS coverage requires an explicit dispatch in the production repository', () => {
  assert.match(workflow, /^on:\n  workflow_dispatch:\npermissions:/m);
  assert.ok(guard, 'expected a repository and event guard before checkout');
  for (const event_name of ['workflow_dispatch', 'push', 'pull_request', 'pull_request_target', 'workflow_run', 'schedule', 'repository_dispatch']) {
    for (const repository of ['elanthia-online/lich-5', 'other/lich-5', 'Lich5/lich-6']) {
      assert.equal(vm.runInNewContext(guard, { github: { repository, event_name } }, { timeout: 1000 }),
        event_name === 'workflow_dispatch' && repository === 'elanthia-online/lich-5');
    }
  }
  assert.doesNotMatch(authorization, /uses: actions\/checkout@/);
  assert.match(workflow, /group: .*github\.actor_id.*github\.triggering_actor/);
});

test('macOS reuses the tested both-actor admin gate and wires the current attempt', () => {
  // The Windows guard suite exercises this same script against denied roles,
  // malformed API responses, failures, missing actors, and full reruns.
  const script = source => source.match(/^          script: \|\n((?:            .*\n)+)/m)?.[1];
  assert.ok(script(authorization), 'expected the repository-permission script');
  assert.equal(script(authorization), script(windows));
  for (const [name, expression] of [
    ['ORIGINAL_ACTOR', 'github.actor'], ['TRIGGERING_ACTOR', 'github.triggering_actor'],
    ['AUTHORIZATION_ATTEMPT', 'github.run_attempt'],
  ]) assert.ok(authorization.includes(`${name}: \${{ ${expression} }}`), name);
  assert.match(authorization, /allowed: \$\{\{ steps\.admin\.outputs\.allowed \}\}/);
  assert.match(authorization, /attempt: \$\{\{ steps\.admin\.outputs\.attempt \}\}/);
  assert.match(authorization, /^        id: admin$/m);
  assert.match(native, /^    needs: authorize$/m);
  assert.ok(executionGuard, 'expected current-attempt authorization before macOS execution');
  for (const allowed of ['true', 'false', '', undefined]) {
    for (const attempt of ['1', '2', '', undefined]) {
      const needs = { authorize: { outputs: { allowed, attempt } } };
      assert.equal(vm.runInNewContext(executionGuard, { needs, github: { run_attempt: '2' } }, { timeout: 1000 }),
        allowed === 'true' && attempt === '2');
    }
  }
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
