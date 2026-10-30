const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const workflow = fs.readFileSync(path.join(__dirname, '../../.github/workflows/webui_tests.yaml'), 'utf8');

// Execute the checkout-free production block; its YAML location is deliberately
// narrow so a workflow rearrangement fails instead of testing a copied policy.
function classifierSource() {
  const lines = workflow.split(/\r?\n/);
  const anchors = lines.flatMap((line, index) => line === '      - &classify' ? [index] : []);
  assert.equal(anchors.length, 1, 'expected one shared classify step');
  const start = anchors[0];
  const end = lines.findIndex((line, index) => index > start && line.startsWith('      - '));
  assert.ok(end > start, 'expected another step after classify');
  const step = lines.slice(start, end);
  assert.ok(step.includes('        id: classify'));
  assert.ok(step.includes('        with:'));
  const scripts = step.flatMap((line, index) => line === '          script: |' ? [index] : []);
  assert.equal(scripts.length, 1, 'expected one literal classify script');
  const body = step.slice(scripts[0] + 1);
  assert.ok(body.some(line => line.trim()), 'classify script must not be empty');
  assert.ok(body.every(line => !line.trim() || line.startsWith('            ')), 'unexpected script indentation');
  return body.map(line => line.slice(12)).join('\n');
}

async function classify({ files = [], eventName = 'pull_request', apiError = null } = {}) {
  const outputs = [], notices = [], calls = [];
  const listFiles = () => { throw new Error('listFiles must be passed to paginate, not called directly'); };
  const sandbox = {
    context: {
      eventName,
      repo: { owner: 'fixture-owner', repo: 'fixture-repo' },
      payload: { pull_request: { number: 42 } },
    },
    core: {
      info() {},
      notice(message) { notices.push(message); },
      setOutput(name, value) { outputs.push([name, value]); },
    },
    github: {
      rest: { pulls: { listFiles } },
      async paginate(method, options) {
        calls.push(method);
        assert.equal(method, listFiles);
        assert.equal(options.owner, 'fixture-owner');
        assert.equal(options.repo, 'fixture-repo');
        assert.equal(options.pull_number, 42);
        assert.equal(options.per_page, 100);
        if (apiError) throw apiError;
        return files;
      },
    },
  };
  await vm.runInNewContext(`(async () => {\n${classifierSource()}\n})()`, sandbox, { timeout: 1_000 });
  return { outputs, notices, calls };
}

for (const filename of [
  'lib/common/webui_launcher.rb',
  'lib/common/webui_launcher/',
  'lib/common/webui_launcher/frontend_tab.rb',
  'spec/login_spec_helper.rb',
  'spec/support/frontend_mock.rb',
]) {
  test(`launcher browser dependency selects WebUI jobs: ${filename}`, async () => {
    const result = await classify({ files: [{ filename }] });
    assert.deepEqual(result.outputs, [['webui', 'true']]);
    assert.equal(result.calls.length, 1);
    assert.deepEqual(result.notices, []);
  });
}

for (const filename of [
  'lib/webui/runtime.rb', 'lib/webui.rb',
  'lib/common/script_scope/gtk/boot.rb', 'lib/common/script_scope.rb', 'lib/common/script_death.rb',
  'spec/webui/browser.spec.cjs', 'spec/fixtures/webui/fixture.json', 'spec/lib/webui/runtime_spec.rb',
  'spec/lib/common/script_scope_widgets_spec.rb', 'spec/support/webui_browser.rb', 'spec/spec_helper.rb',
  'Gemfile', 'Gemfile.lock', '.github/workflows/webui_tests.yaml',
]) {
  test(`existing WebUI dependency remains selected: ${filename}`, async () => {
    assert.deepEqual((await classify({ files: [{ filename }] })).outputs, [['webui', 'true']]);
  });
}

// Files the launcher presentation browser spec and the login helpers load
// (1852:RC4); each one maps to a distinct WEBUI_PATHS entry.
for (const filename of [
  'spec/lib/common/webui_launcher_presentation_browser_spec.rb', 'spec/support/data_dir.rb',
  '.rspec', '.rspec_parallel',
  'lib/common/authentication/entry_store.rb', 'lib/common/gui/master_password_manager.rb', 'lib/common/gui_login.rb',
  'lib/common/front-end.rb', 'lib/common/frontend.rb', 'lib/common/frontend_editor.rb',
  'lib/common/session_launcher.rb', 'lib/common/saga_launch_policy.rb', 'lib/common/saga_managed_launcher.rb',
  'lib/common/process_launcher.rb', 'lib/common/ruby_executable.rb', 'lib/common/sharing_violation_retry.rb',
  'lib/common/windows_command_line.rb', 'lib/util/deep_freeze.rb',
]) {
  test(`launcher provider dependency selects WebUI jobs: ${filename}`, async () => {
    assert.deepEqual((await classify({ files: [{ filename }] })).outputs, [['webui', 'true']]);
  });
}

test('every browser shard spec file selects WebUI jobs', async () => {
  const browser = workflow.slice(workflow.indexOf('\n  browser:\n'));
  const shardFiles = [...browser.matchAll(/^ {14}(spec\/\S+_spec\.rb)$/gm)].map(match => match[1]);
  assert.ok(shardFiles.length > 0, 'expected browser shard spec files');
  for (const filename of shardFiles) {
    assert.deepEqual((await classify({ files: [{ filename }] })).outputs, [['webui', 'true']], filename);
  }
});

for (const filename of [
  'docs/unrelated.md',
  'lib/common/webui_launcher.rb.bak', 'lib/common/webui_launcher_extra.rb',
  'lib/common/webui_launcher_other/catalog.rb',
  'spec/login_spec_helper.rb.bak', 'spec/support/frontend_mock.rb.bak',
  'lib/common/gui_login.rb.bak', 'spec/support/data_dir.rb.bak',
]) {
  test(`unrelated or near-prefix path does not select WebUI jobs: ${filename}`, async () => {
    assert.deepEqual((await classify({ files: [{ filename }] })).outputs, [['webui', 'false']]);
  });
}

test('renames into and out of browser dependency scope select WebUI jobs', async () => {
  for (const file of [
    { filename: 'lib/common/webui_launcher/new_view.rb', previous_filename: 'lib/common/old_view.rb' },
    { filename: 'lib/common/retired_view.rb', previous_filename: 'lib/common/webui_launcher/old_view.rb' },
  ]) {
    assert.deepEqual((await classify({ files: [file] })).outputs, [['webui', 'true']]);
  }
});

for (const [count, expected] of [[0, 'false'], [2_999, 'false'], [3_000, 'true']]) {
  test(`unrelated changed-file count ${count} preserves the API-cap fallback`, async () => {
    const files = Array.from({ length: count }, (_, index) => ({ filename: `docs/unrelated-${index}.md` }));
    assert.deepEqual((await classify({ files })).outputs, [['webui', expected]]);
  });
}

test('changed-file API failure runs WebUI jobs and records the reason', async () => {
  const result = await classify({ apiError: new Error('fixture pagination failure') });
  assert.deepEqual(result.outputs, [['webui', 'true']]);
  assert.equal(result.calls.length, 1);
  assert.deepEqual(result.notices, ['Could not read changed files (fixture pagination failure); running WebUI jobs.']);
});

for (const eventName of ['push', 'workflow_dispatch']) {
  test(`${eventName} runs WebUI jobs without calling the PR API`, async () => {
    const result = await classify({ eventName });
    assert.deepEqual(result.outputs, [['webui', 'true']]);
    assert.deepEqual(result.calls, []);
    assert.deepEqual(result.notices, []);
  });
}

test('renderer and browser share the checkout-free classify step', () => {
  const rendererStart = workflow.indexOf('\n  renderer:\n');
  const browserStart = workflow.indexOf('\n  browser:\n');
  assert.ok(rendererStart >= 0 && browserStart > rendererStart);
  const renderer = workflow.slice(rendererStart, browserStart);
  const browser = workflow.slice(browserStart);
  assert.equal((workflow.match(/^      - \*classify$/gm) || []).length, 1);
  for (const [job, classifyStep] of [[renderer, '      - &classify'], [browser, '      - *classify']]) {
    const checkout = job.indexOf('uses: actions/checkout@');
    assert.ok(job.indexOf(classifyStep) >= 0 && checkout > job.indexOf(classifyStep));
    assert.match(job, /if: steps\.classify\.outputs\.webui == 'true'/);
  }
});
