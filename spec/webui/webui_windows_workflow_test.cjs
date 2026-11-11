const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '../..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/\r\n/g, '\n');
const workflow = read('.github/workflows/windows_webui.yaml');
const renderer = read('.github/workflows/webui_tests.yaml').split('\n  browser:\n')[0];
const guard = workflow.match(/^    if: >-\n((?:      .+\n)+)/m)?.[1].trim();
assert.ok(guard, 'expected a job-level owner guard before any checkout');

function eligible(overrides = {}) {
  const github = {
    repository: 'elanthia-online/lich-5',
    actor: 'OSXLich-Doug', actor_id: '17682675', triggering_actor: 'OSXLich-Doug',
    event_name: 'push', ref: 'refs/heads/main', ...overrides,
  };
  return vm.runInNewContext(guard, { github }, { timeout: 1000 });
}

test('new Windows automation accepts only the owner original/re-run actor on permitted events', () => {
  assert.equal(eligible(), true);
  assert.equal(eligible({ event_name: 'workflow_dispatch', ref: 'refs/heads/webui/candidate' }), true);
  for (const overrides of [
    { repository: 'other/lich-5' }, { actor: 'contributor' }, { actor_id: '123' },
    { triggering_actor: 'contributor' }, { actor: 'contributor', triggering_actor: 'OSXLich-Doug' },
    { event_name: 'pull_request' }, { event_name: 'pull_request_target' }, { event_name: 'workflow_run' },
    { event_name: 'push', ref: 'refs/heads/contributor' },
    { event_name: 'push', ref: 'refs/tags/main' },
  ]) assert.equal(eligible(overrides), false, JSON.stringify(overrides));
  assert.ok(workflow.indexOf('    if: >-') < workflow.indexOf('uses: actions/checkout@'));
  assert.doesNotMatch(workflow, /^  (pull_request(?:_target)?|workflow_run):/m);
  assert.match(workflow, /push:\n    branches: \[main\]/);
  assert.match(workflow, /group: .*github\.actor_id.*github\.triggering_actor/);
});

test('Windows coverage stays bounded and blocking with pinned read-only actions', () => {
  assert.match(workflow, /permissions:\n  contents: read\n/);
  assert.doesNotMatch(workflow, /(?:contents|pull-requests|issues): write/);
  assert.match(workflow, /runs-on: windows-latest\n    timeout-minutes: 45/);
  const actions = [...workflow.matchAll(/uses: ([^\n]+)/g)].map(match => match[1]);
  assert.ok(actions.length >= 4);
  for (const action of actions) assert.match(action, /^[\w/-]+@[0-9a-f]{40}(?: #.*)?$/);
  assert.match(workflow, /persist-credentials: false/);
  assert.doesNotMatch(workflow, /continue-on-error:/);
  assert.doesNotMatch(workflow, /bundle exec rspec[^\n]*gemcheck_spec/);
  assert.match(workflow, /if: \$\{\{ !cancelled\(\) \}\}\n        uses: actions\/upload-artifact@/);
  assert.match(workflow, /\$principal\.Count -ne 1 -or \$principal\[0\]\.status -ne 'passed'/);
});

test('Windows selection includes the retained transport, authentication, launcher and builder boundaries', () => {
  const selected = [...workflow.matchAll(/'(spec\/[^']+)'/g)].map(match => match[1]);
  assert.ok(selected.length >= 20);
  const p22 = new Set(['spec/lib/main/webui_startup_spec.rb', 'spec/lib/main/default_webui_acceptance_spec.rb']);
  for (const filename of selected) {
    if (!p22.has(filename)) assert.ok(fs.existsSync(path.join(root, filename)), filename);
  }
  for (const filename of [
    'spec/lib/webui', 'spec/lib/real_keychain_fence_spec.rb',
    'spec/lib/common/webui_launcher/controller_regressions_spec.rb',
    'spec/lib/common/script_scope_builder_spec.rb', 'spec/lib/common/script_scope_builder_remaining_spec.rb',
    'spec/lib/main/default_webui_acceptance_report_spec.rb', ...p22,
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
