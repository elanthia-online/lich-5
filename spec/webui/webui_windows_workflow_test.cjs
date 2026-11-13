const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { windowsSpecPaths } = require('./workflow_classification_source.cjs');

const root = path.join(__dirname, '../..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/\r\n/g, '\n');
const workflow = read('.github/workflows/windows_webui.yaml');
const selected = windowsSpecPaths(workflow);
const renderer = read('.github/workflows/webui_tests.yaml').split('\n  browser:\n')[0];
const authorization = workflow.split('\n  authorize:\n')[1]?.split('\n  windows_webui:\n')[0];
assert.ok(authorization, 'expected an authorization job before Windows coverage');
const guard = authorization.match(/^    if: >-\n((?:      .+\n)+)/m)?.[1].trim();
const gateSource = authorization.match(/^          script: \|\n((?:            .*\n)+)/m)?.[1];
assert.ok(guard, 'expected a job-level event guard before any checkout');
assert.ok(gateSource, 'expected the inline repository-permission gate');
const windows = workflow.split('\n  windows_webui:\n')[1];
const windowsGuard = windows.match(/^    if: (.+)$/m)?.[1];

function eligible(overrides = {}) {
  const github = {
    repository: 'elanthia-online/lich-5',
    event_name: 'push', ref: 'refs/heads/main', ...overrides,
  };
  return vm.runInNewContext(guard, { github }, { timeout: 1000 });
}

async function authorize(responses = {}, actors = {}, attempt = '1') {
  const calls = [];
  const outputs = {};
  const failures = [];
  const env = {
    ORIGINAL_ACTOR: 'original-admin', TRIGGERING_ACTOR: 'rerun-admin',
    AUTHORIZATION_ATTEMPT: attempt, ...actors,
  };
  const github = { rest: { repos: { getCollaboratorPermissionLevel: async params => {
    calls.push(params);
    const response = Object.hasOwn(responses, params.username) ? responses[params.username] :
      { status: 200, data: { permission: 'admin' } };
    if (response instanceof Error) throw response;
    return response;
  } } } };
  const core = {
    setOutput: (name, value) => { outputs[name] = value; },
    setFailed: message => { failures.push(message); },
    notice: () => {},
  };
  await vm.runInNewContext(`(async () => {\n${gateSource}\n})()`, {
    github, core, context: { repo: { owner: 'elanthia-online', repo: 'lich-5' } }, process: { env },
  }, { timeout: 1000 });
  return { calls, outputs, failures };
}

test('Windows authorization permits main pushes and dispatches and rejects external events', () => {
  assert.equal(eligible(), true);
  assert.equal(eligible({ event_name: 'workflow_dispatch', ref: 'refs/heads/webui/candidate' }), true);
  for (const overrides of [
    { repository: 'other/lich-5' },
    { event_name: 'pull_request' }, { event_name: 'pull_request_target' }, { event_name: 'workflow_run' },
    { event_name: 'push', ref: 'refs/heads/contributor' },
    { event_name: 'push', ref: 'refs/tags/main' },
    { event_name: 'schedule' }, { event_name: 'repository_dispatch' },
  ]) assert.equal(eligible(overrides), false, JSON.stringify(overrides));
  assert.ok(workflow.indexOf('    if: >-') < workflow.indexOf('uses: actions/checkout@'));
  assert.doesNotMatch(workflow, /^  (pull_request(?:_target)?|workflow_run):/m);
  assert.match(workflow, /push:\n    branches: \[main\]/);
  assert.match(workflow, /group: .*github\.actor_id.*github\.triggering_actor/);
});

test('Windows permission gate reads both actor roles from the repository API before checkout', async () => {
  const result = await authorize();
  assert.deepEqual(result.outputs, { allowed: 'true', attempt: '1' });
  assert.deepEqual(result.failures, []);
  assert.equal(result.calls.length, 2);
  assert.deepEqual(result.calls.map(call => ({ ...call })), [
    { owner: 'elanthia-online', repo: 'lich-5', username: 'original-admin' },
    { owner: 'elanthia-online', repo: 'lich-5', username: 'rerun-admin' },
  ]);
  const sameActor = await authorize({}, { ORIGINAL_ACTOR: 'another-admin', TRIGGERING_ACTOR: 'another-admin' });
  assert.equal(sameActor.outputs.allowed, 'true');
  assert.deepEqual(sameActor.calls.map(call => call.username), ['another-admin', 'another-admin']);
  assert.doesNotMatch(authorization, /uses: actions\/checkout@/);
  assert.ok(workflow.indexOf('\n  authorize:\n') < workflow.indexOf('uses: actions/checkout@'));
  assert.match(authorization, /ORIGINAL_ACTOR: \$\{\{ github\.actor \}\}/);
  assert.match(authorization, /TRIGGERING_ACTOR: \$\{\{ github\.triggering_actor \}\}/);
  assert.match(authorization, /AUTHORIZATION_ATTEMPT: \$\{\{ github\.run_attempt \}\}/);
  assert.match(authorization, /allowed: \$\{\{ steps\.admin\.outputs\.allowed \}\}/);
  assert.match(authorization, /attempt: \$\{\{ steps\.admin\.outputs\.attempt \}\}/);
  assert.match(authorization, /^        id: admin$/m);
});

test('Windows permission gate requires admin for each actor and fails closed at the API boundary', async () => {
  const rejected = [
    ...['maintain', 'write', 'read', 'triage', 'none', 'unknown', 'ADMIN', ''].map(permission =>
      ({ status: 200, data: { permission } })),
    { status: 403, data: { permission: 'admin' } },
    { status: 404, data: { permission: 'admin' } },
    { status: 500, data: { permission: 'admin' } },
    { data: { permission: 'admin' } }, { status: 200, data: {} },
    { status: 200, data: { permission: null } },
    { status: 200 }, {}, null, undefined, new Error('permission request failed'),
  ];
  for (const actor of ['original-admin', 'rerun-admin']) {
    for (const response of rejected) {
      const result = await authorize({ [actor]: response });
      assert.equal(result.outputs.allowed, 'false', `${actor}: ${JSON.stringify(response)}`);
      assert.equal(result.calls.at(-1).username, actor);
      if (response instanceof Error) assert.equal(result.failures.length, 1);
    }
  }
  for (const actor of ['ORIGINAL_ACTOR', 'TRIGGERING_ACTOR']) {
    const result = await authorize({}, { [actor]: '' });
    assert.equal(result.outputs.allowed, 'false', actor);
    assert.equal(result.failures.length, 1);
  }
});

test('Windows execution depends on a successful admin gate with explicit approval', () => {
  assert.match(windows, /^    needs: authorize$/m);
  assert.ok(windowsGuard, 'expected the Windows approval guard');
  for (const allowed of ['true', 'false', '', undefined]) {
    const needs = { authorize: { outputs: { allowed, attempt: '1' } } };
    const github = { run_attempt: '1' };
    assert.equal(vm.runInNewContext(windowsGuard, { needs, github }, { timeout: 1000 }), allowed === 'true');
  }
});

test('Windows rejects retained authorization on partial reruns and rechecks actors on full reruns', async () => {
  const executionAllowed = (outputs, attempt) => vm.runInNewContext(windowsGuard, {
    needs: { authorize: { outputs } }, github: { run_attempt: attempt },
  }, { timeout: 1000 });
  const original = await authorize({}, {}, '1');
  assert.equal(executionAllowed(original.outputs, '1'), true);
  // A failed-jobs or selected-job re-run can retain successful dependency outputs.
  assert.equal(executionAllowed(original.outputs, '2'), false);
  assert.equal(executionAllowed({ allowed: 'true' }, '2'), false);
  assert.equal(executionAllowed({ allowed: 'true', attempt: '' }, '2'), false);
  const adminRerun = await authorize({}, {}, '2');
  assert.equal(adminRerun.outputs.attempt, '2');
  assert.equal(executionAllowed(adminRerun.outputs, '2'), true);
  assert.deepEqual(adminRerun.calls.map(call => call.username), ['original-admin', 'rerun-admin']);
  const nonadminRerun = await authorize({
    contributor: { status: 200, data: { permission: 'write' } },
  }, { TRIGGERING_ACTOR: 'contributor' }, '2');
  assert.deepEqual(nonadminRerun.calls.map(call => call.username), ['original-admin', 'contributor']);
  assert.equal(executionAllowed(nonadminRerun.outputs, '2'), false);
});

test('Windows coverage stays bounded and blocking with pinned read-only actions', () => {
  assert.match(workflow, /permissions:\n  contents: read\n/);
  assert.doesNotMatch(workflow, /(?:^\s*[\w-]+: write$|permissions: write-all)/m);
  assert.match(workflow, /runs-on: windows-latest\n    timeout-minutes: 45/);
  const actions = [...workflow.matchAll(/uses: ([^\n]+)/g)].map(match => match[1]);
  assert.ok(actions.length >= 4);
  for (const action of actions) assert.match(action, /^[\w/-]+@[0-9a-f]{40}(?: #.*)?$/);
  assert.match(workflow, /persist-credentials: false/);
  assert.doesNotMatch(workflow, /continue-on-error:/);
  assert.ok(!selected.includes('spec/lib/gemcheck_spec.rb'));
  assert.match(workflow, /^            & ruby -S rspec @specFiles[^\n]*\n            \$code = \$LASTEXITCODE\n/m);
  assert.match(workflow, /^            if \(\$code -ne 0\) \{ \$failed = \$true \}$/m);
  assert.match(workflow, /^          if \(\$failed\) \{ exit 1 \}$/m);
  assert.match(workflow, /if: \$\{\{ !cancelled\(\) \}\}\n        uses: actions\/upload-artifact@/);
});

test('WebUI workflows share one pinned Ruby setup action revision', () => {
  const pins = [workflow, read('.github/workflows/webui_tests.yaml')]
    .flatMap(source => [...source.matchAll(/uses: ruby\/setup-ruby@([^\n]+)/g)].map(match => match[1]));
  assert.equal(pins.length, 2, 'each WebUI workflow sets up Ruby once');
  for (const pin of pins) assert.match(pin, /^[0-9a-f]{40} # v\d+\.\d+\.\d+$/);
  assert.equal(new Set(pins).size, 1, 'both WebUI workflows use the same setup-ruby revision');
});

test('Windows uses production runtime preparation before separate discoverable RSpec tooling', () => {
  assert.match(workflow, /ruby-version: '4\.0\.9'\n          windows-toolchain: none\n          bundler: none\n          bundler-cache: false/);
  assert.doesNotMatch(workflow, /BUNDLE_WITHOUT|bundle exec|GEM_HOME=/);
  const prepare = workflow.indexOf('run: ./.github/scripts/windows_runtime_prepare.ps1');
  const tooling = workflow.indexOf('gem install rspec --version 3.13.2 --no-document --install-dir $toolHome');
  const discovery = workflow.indexOf('& ruby -S rspec --version');
  const groups = workflow.indexOf('$groups = [ordered]@{');
  assert.ok(prepare > 0 && prepare < tooling && tooling < discovery && discovery < groups);
  assert.match(workflow, /GEM_PATH=\$toolHome\$\(\[IO\.Path\]::PathSeparator\)\$runtimePaths/);
  assert.match(workflow, /\(Join-Path \$toolHome 'bin'\) \| Out-File \$env:GITHUB_PATH -Append/);
  assert.match(workflow, /& ruby -S rspec @specFiles/);
});

test('Windows selection includes the retained transport, authentication, launcher and builder boundaries', () => {
  assert.ok(selected.length >= 20);
  for (const filename of selected) {
    assert.ok(fs.existsSync(path.join(root, filename)), filename);
  }
  for (const filename of [
    'spec/lib/webui', 'spec/lib/real_keychain_fence_spec.rb',
    'spec/lib/common/webui_launcher/controller_regressions_spec.rb',
    'spec/lib/common/script_scope_builder_spec.rb', 'spec/lib/common/script_scope_builder_remaining_spec.rb',
    'spec/lib/main/default_webui_acceptance_report_spec.rb',
  ]) assert.ok(selected.includes(filename), filename);
});

test('standing npm entrypoint has engines and a headed display on hosted Linux and Windows', () => {
  assert.match(renderer, /playwright install --with-deps webkit/);
  assert.match(renderer, /playwright install-deps chrome/);
  assert.match(renderer, /google-chrome --version \|\| npx --no-install playwright install chrome/);
  assert.match(renderer, /xvfb-run --auto-servernum npm test --prefix spec\/webui/);
  assert.match(workflow, /playwright install webkit/);
  assert.match(workflow, /playwright install chrome/);
  assert.match(workflow, /run: npm test --prefix spec\/webui/);
  const scripts = JSON.parse(read('spec/webui/package.json')).scripts;
  assert.equal(scripts.test, 'npm run test:logic && npm run test:engine');
  assert.match(scripts['test:engine'], /playwright\.engine\.config\.cjs/);
  assert.match(read('spec/webui/playwright.engine.config.cjs'), /workers: 1/);
});
