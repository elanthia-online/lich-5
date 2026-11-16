const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { windowsSpecPaths } = require('./workflow_classification_source.cjs');

const root = path.join(__dirname, '../..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/\r\n/g, '\n');
const workflow = read('.github/workflows/windows_webui.yaml');
const selected = windowsSpecPaths(workflow);
const renderer = read('.github/workflows/webui_tests.yaml').split('\n  browser:\n')[0];
const windows = workflow.split('\n  windows_webui:\n')[1];
assert.ok(windows, 'expected the Windows coverage job');

test('Windows coverage runs when CI calls it or on a manual dispatch, and on no other event', () => {
  assert.match(workflow, /^on:\n  workflow_call:\n  workflow_dispatch:\n\npermissions:/m);
  assert.doesNotMatch(workflow, /^  (push|pull_request|pull_request_target|pull_request_review|workflow_run|schedule):/m);
  assert.doesNotMatch(workflow, /^\s*concurrency:/m);
});

test('Windows coverage has no gate of its own: CI decides whether to call it', () => {
  const jobs = [...workflow.slice(workflow.indexOf('\njobs:\n')).matchAll(/^ {2}([A-Za-z_][\w-]*):$/gm)].map(match => match[1]);
  assert.deepEqual(jobs, ['windows_webui']);
  assert.doesNotMatch(windows, /^    (if|needs):/m);
  assert.doesNotMatch(workflow, /getCollaboratorPermissionLevel|github\.actor|triggering_actor|github\.repository ==/);
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
