const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { lf, workflow, classifierSource, windowsSpecPaths } = require('./workflow_classification_source.cjs');
const windowsWorkflow = lf(fs.readFileSync(path.join(__dirname, '../../.github/workflows/windows_webui.yaml'), 'utf8'));

async function classify({ files = [], eventName = 'pull_request', apiError = null, contentError = null, windows = windowsWorkflow, contentData = null } = {}) {
  const outputs = [], notices = [], calls = [], contentCalls = [];
  const listFiles = () => { throw new Error('listFiles must be passed to paginate, not called directly'); };
  const sandbox = {
    context: {
      eventName,
      repo: { owner: 'fixture-owner', repo: 'fixture-repo' },
      payload: { pull_request: { number: 42, head: { sha: 'fixture-head-sha', repo: { owner: { login: 'fixture-fork-owner' }, name: 'fixture-fork' } } } },
    },
    core: {
      info() {},
      notice(message) { notices.push(message); },
      setOutput(name, value) { outputs.push([name, value]); },
    },
    github: {
      rest: {
        pulls: { listFiles },
        repos: {
          async getContent(options) {
            contentCalls.push(options);
            assert.equal(options.owner, 'fixture-fork-owner');
            assert.equal(options.repo, 'fixture-fork');
            assert.equal(options.ref, 'fixture-head-sha');
            assert.equal(options.path, '.github/workflows/windows_webui.yaml');
            if (contentError) throw contentError;
            return { data: contentData || { encoding: 'base64', content: Buffer.from(windows).toString('base64') } };
          },
        },
      },
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
    Buffer,
  };
  await vm.runInNewContext(`(async () => {\n${classifierSource()}\n})()`, sandbox, { timeout: 1_000 });
  return { outputs, notices, calls, contentCalls };
}

test('every Windows-selected spec change, rename and deletion selects WebUI jobs', async () => {
  for (const filename of windowsSpecPaths(windowsWorkflow)) {
    for (const file of [
      { filename, status: 'modified' },
      { filename: 'spec/retired_spec.rb', previous_filename: filename, status: 'renamed' },
      { filename, status: 'removed' },
    ]) {
      assert.deepEqual((await classify({ files: [file] })).outputs, [['webui', 'true']], `${filename}: ${file.status}`);
    }
  }
});

test('new Windows groups flow through the shared parser with exact file and directory boundaries', async () => {
  const windows = windowsWorkflow.replace('          $groups = [ordered]@{', "          $groups = [ordered]@{\n            future = @('spec/future/principal_spec.rb', 'spec/future/windows')");
  assert.ok(windowsSpecPaths(windows).includes('spec/future/principal_spec.rb'));
  for (const filename of ['spec/future/principal_spec.rb', 'spec/future/windows', 'spec/future/windows/nested/example_spec.rb']) {
    assert.deepEqual((await classify({ windows, files: [{ filename }] })).outputs, [['webui', 'true']], filename);
  }
  for (const filename of ['spec/future/other_spec.rb', 'spec/future/principal_spec.rb.bak', 'spec/future/windows_extra/example_spec.rb']) {
    assert.deepEqual((await classify({ windows, files: [{ filename }] })).outputs, [['webui', 'false']], filename);
  }
  assert.deepEqual(windowsSpecPaths(windows.replace(/\n/g, '\r\n')), windowsSpecPaths(windows));
});

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
  '.github/workflows/windows_webui.yaml',
  '.github/scripts/windows_runtime_prepare.ps1', '.github/scripts/windows_runtime_observer.rb',
  '.ruby-version', // setup-ruby reads it for the browser job (1852:RC10)
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

// Every helper that .rspec or .rspec_parallel loads into all examples (browser
// ones included) must select WebUI jobs, so an edit to the next globally loaded
// helper cannot skip the browser checks (1852:RC11).
// Parses the require targets of an rspec options file. The space, `=` and
// attached (`-r./path`) forms are accepted; any other line that starts with
// --require or -r fails visibly instead of being skipped (1852:RC12).
function rspecRequires(text) {
  const required = [];
  for (const line of lf(text).split('\n')) {
    const trimmed = line.trim();
    if (!/^(?:--require|-r)/.test(trimmed)) continue;
    const match = /^(?:--require(?:[ =]+)|-r[ =]*)(\S+)$/.exec(trimmed);
    assert.ok(match, `unparsed require-looking line: ${trimmed}`);
    required.push(match[1]);
  }
  return required;
}

for (const rspecFile of ['.rspec', '.rspec_parallel']) {
  test(`every --require in ${rspecFile} selects WebUI jobs`, async () => {
    const root = path.join(__dirname, '../..');
    const required = rspecRequires(fs.readFileSync(path.join(root, rspecFile), 'utf8'));
    assert.ok(required.length > 0, `expected --require lines in ${rspecFile}`);
    for (const target of required) {
      // Relative to the repo root (RSpec runs there); a bare name resolves on
      // the load path, so only ./ paths can be classified here.
      assert.ok(target.startsWith('./'), `${rspecFile}: --require ${target} must be a ./ path`);
      const relative = target.slice(2);
      const filename = path.extname(relative) ? relative : `${relative}.rb`;
      assert.ok(fs.existsSync(path.join(root, filename)), `${rspecFile}: ${filename} does not exist`);
      assert.deepEqual((await classify({ files: [{ filename }] })).outputs, [['webui', 'true']], `${rspecFile}: ${filename}`);
    }
  });
}

test('require drift guard parses every spelling and rejects unparsed lines', () => {
  assert.deepEqual(rspecRequires('--require ./a\n--require=./b\n-r ./c\n-r=./d\n-r./e\n--color\n'), ['./a', './b', './c', './d', './e']);
  assert.deepEqual(rspecRequires('-r./a\r\n--require ./b\r\n'), ['./a', './b']);
  assert.throws(() => rspecRequires('--require\n'), /unparsed require-looking line/);
  assert.throws(() => rspecRequires('-r\n'), /unparsed require-looking line/);
  assert.throws(() => rspecRequires('--require ./a ./b\n'), /unparsed require-looking line/);
});

function browserShardFiles(text) {
  const browser = text.slice(text.indexOf('\n  browser:\n'));
  return [...browser.matchAll(/^ {14}(spec\/\S+_spec\.rb)$/gm)].map(match => match[1]);
}

test('every browser shard spec file selects WebUI jobs', async () => {
  const shardFiles = browserShardFiles(workflow);
  assert.ok(shardFiles.length > 0, 'expected browser shard spec files');
  for (const filename of shardFiles) {
    assert.deepEqual((await classify({ files: [{ filename }] })).outputs, [['webui', 'true']], filename);
  }
});

test('a CRLF checkout of the workflow yields the same markers and shards', () => {
  const crlf = workflow.replace(/\n/g, '\r\n');
  assert.ok(crlf.includes('\r\n'));
  const normalized = lf(crlf);
  assert.equal(normalized, workflow);
  assert.equal(classifierSource(normalized), classifierSource());
  assert.deepEqual(browserShardFiles(normalized), browserShardFiles(workflow));
  assert.ok(normalized.indexOf('\n  renderer:\n') >= 0 && normalized.indexOf('\n  browser:\n') >= 0);
});

for (const filename of [
  'docs/unrelated.md',
  'lib/common/webui_launcher.rb.bak', 'lib/common/webui_launcher_extra.rb',
  'lib/common/webui_launcher_other/catalog.rb',
  'spec/login_spec_helper.rb.bak', 'spec/support/frontend_mock.rb.bak', 'spec/support/real_keychain_fence.rb.bak',
  'lib/common/gui_login.rb.bak', 'spec/support/data_dir.rb.bak',
  'spec/lib/main/unrelated_spec.rb', 'spec/lib/main/default_webui_acceptance_report_spec.rb.bak',
  'spec/lib/real_keychain_fence_spec.rb.bak', 'spec/lib/common/authentication/unrelated_spec.rb',
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
  assert.deepEqual(result.notices, ['Could not classify changed files (fixture pagination failure); running WebUI jobs.']);
  assert.deepEqual(result.contentCalls, []);
});

test('Windows selection API and parse failures run WebUI jobs and record the reason', async () => {
  for (const [options, reason] of [
    [{ contentError: new Error('fixture content failure') }, 'fixture content failure'],
    [{ contentData: { encoding: 'none', content: '' } }, 'expected the Windows workflow file content'],
    [{ windows: 'missing table' }, 'expected the Windows RSpec selection table'],
    [{ windows: '          $groups = [ordered]@{\n          }' }, 'expected the Windows RSpec selection table'],
    [{ windows: "          $groups = [ordered]@{\n            empty = @()\n          }" }, 'expected selected Windows specs'],
  ]) {
    const result = await classify(options);
    assert.deepEqual(result.outputs, [['webui', 'true']]);
    assert.equal(result.contentCalls.length, 1);
    assert.deepEqual(result.notices, [`Could not classify changed files (${reason}); running WebUI jobs.`]);
  }
});

for (const eventName of ['push', 'workflow_dispatch']) {
  test(`${eventName} runs WebUI jobs without calling the PR API`, async () => {
    const result = await classify({ eventName });
    assert.deepEqual(result.outputs, [['webui', 'true']]);
    assert.deepEqual(result.calls, []);
    assert.deepEqual(result.contentCalls, []);
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
