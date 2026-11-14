const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { lf, read, ci, workflow, jobBlock, classifierSource, windowsSpecPaths } = require('./workflow_classification_source.cjs');
const windowsWorkflow = read('.github/workflows/windows_webui.yaml');

const SUITES = ['renderer', 'browser', 'windows', 'macos'];
const decide = (...selected) => Object.fromEntries(SUITES.map(suite => [suite, selected.includes(suite) ? 'true' : 'false']));
const NONE = decide();
const ALL = decide(...SUITES);
// Linux and Windows load the same WebUI code; macOS has its own narrower list.
const SHARED = decide('renderer', 'browser', 'windows');
const WINDOWS_ONLY = decide('windows');

// Runs the production classifier against a fixture event. A pull request reads
// its files through the paginated list; a push reads the comparison between
// the previous tip and the new one.
async function classify({
  files = [], eventName = 'pull_request', apiError = null, contentError = null,
  windows = windowsWorkflow, contentData = null, before = 'fixture-before-sha', compareData = null,
} = {}) {
  const decisions = {}, notices = [], infos = [], calls = [], contentCalls = [];
  const listFiles = () => { throw new Error('listFiles must be passed to paginate, not called directly'); };
  const pull = eventName === 'pull_request';
  const sandbox = {
    context: {
      eventName,
      sha: 'fixture-pushed-sha',
      repo: { owner: 'fixture-owner', repo: 'fixture-repo' },
      payload: pull ?
        { pull_request: { number: 42, head: { sha: 'fixture-head-sha', repo: { owner: { login: 'fixture-fork-owner' }, name: 'fixture-fork' } } } } :
        { before },
    },
    core: {
      info(message) { infos.push(message); },
      notice(message) { notices.push(message); },
      setOutput(name, value) {
        assert.ok(!(name in decisions), `${name} decided twice`);
        decisions[name] = value;
      },
    },
    github: {
      rest: {
        pulls: { listFiles },
        repos: {
          async compareCommits(options) {
            calls.push('compareCommits');
            assert.deepEqual({ ...options }, { owner: 'fixture-owner', repo: 'fixture-repo', base: before, head: 'fixture-pushed-sha' });
            if (apiError) throw apiError;
            return { data: compareData || { files } };
          },
          async getContent(options) {
            contentCalls.push(options);
            assert.equal(options.owner, pull ? 'fixture-fork-owner' : 'fixture-owner');
            assert.equal(options.repo, pull ? 'fixture-fork' : 'fixture-repo');
            assert.equal(options.ref, pull ? 'fixture-head-sha' : 'fixture-pushed-sha');
            assert.equal(options.path, '.github/workflows/windows_webui.yaml');
            if (contentError) throw contentError;
            return { data: contentData || { encoding: 'base64', content: Buffer.from(windows).toString('base64') } };
          },
        },
      },
      async paginate(method, options) {
        calls.push('listFiles');
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
  assert.deepEqual(Object.keys(decisions).sort(), [...SUITES].sort(), 'every suite gets exactly one decision');
  return { decisions, notices, infos, calls, contentCalls };
}

const decisionsFor = async (filename, options = {}) => (await classify({ files: [{ filename }], ...options })).decisions;

// The macOS job compiles the native host and runs its presentation spec, so
// only these paths reach it. Everything here is also WebUI code, so the shared
// suites are selected too.
const MACOS_FILES = [
  'lib/webui/native/macos/Host.swift', 'lib/webui/native/macos/ExternalLinks.swift',
  'lib/webui/native/macos/Info.plist', 'lib/webui/native/macos/build.sh', 'lib/webui/native/macos/window.js',
  'spec/lib/webui/native_host_presentation_spec.rb', 'spec/webui/native_presentation.swift',
  'spec/spec_helper.rb', 'spec/support/data_dir.rb', 'spec/support/frontend_mock.rb',
  'spec/support/real_keychain_fence.rb', '.rspec',
];

// Startup and gem recovery, which only the Windows job runs end to end.
const WINDOWS_STARTUP_FILES = [
  'lich.rbw', 'lib/main/early_exit.rb', 'lib/gemcheck.rb', 'lib/bundler_recovery.rb',
  'lib/dependency_recovery.rb', 'lib/accepted_gem_policy.rb', 'lib/runtime_gem_contract.rb',
  'lib/recovery_unit_policy.rb',
];

// Default-startup acceptance helpers, which only the Windows job exercises.
const WINDOWS_ACCEPTANCE_FILES = [
  'spec/support/default_webui_acceptance_report.rb',
  'spec/support/default_webui_acceptance_check.rb',
  'spec/support/default_webui_acceptance_probe.rb',
];

// A change to how the suites are selected or run must run all of them.
const ALL_SUITE_FILES = [
  '.github/workflows/ci.yml', '.github/workflows/webui_tests.yaml',
  '.github/workflows/windows_webui.yaml', '.github/workflows/macos_webui.yaml',
  '.github/scripts/macos_webui_smoke.py',
  '.github/scripts/windows_runtime_prepare.ps1', '.github/scripts/windows_runtime_observer.rb',
];

const expectedFor = filename => MACOS_FILES.includes(filename) ? ALL : SHARED;

test('every Windows-selected spec change, rename and deletion selects the shared suites', async () => {
  for (const filename of windowsSpecPaths(windowsWorkflow)) {
    for (const file of [
      { filename, status: 'modified' },
      { filename: 'spec/retired_spec.rb', previous_filename: filename, status: 'renamed' },
      { filename, status: 'removed' },
    ]) {
      assert.deepEqual((await classify({ files: [file] })).decisions, SHARED, `${filename}: ${file.status}`);
    }
  }
});

test('new Windows groups flow through the shared parser with exact file and directory boundaries', async () => {
  const windows = windowsWorkflow.replace('          $groups = [ordered]@{', "          $groups = [ordered]@{\n            future = @('spec/future/principal_spec.rb', 'spec/future/windows')");
  assert.ok(windowsSpecPaths(windows).includes('spec/future/principal_spec.rb'));
  for (const filename of ['spec/future/principal_spec.rb', 'spec/future/windows', 'spec/future/windows/nested/example_spec.rb']) {
    assert.deepEqual(await decisionsFor(filename, { windows }), SHARED, filename);
  }
  for (const filename of ['spec/future/other_spec.rb', 'spec/future/principal_spec.rb.bak', 'spec/future/windows_extra/example_spec.rb']) {
    assert.deepEqual(await decisionsFor(filename, { windows }), NONE, filename);
  }
  assert.deepEqual(windowsSpecPaths(windows.replace(/\n/g, '\r\n')), windowsSpecPaths(windows));
});

for (const filename of [
  'lib/common/webui_launcher.rb',
  'lib/common/webui_launcher/',
  'lib/common/webui_launcher/frontend_tab.rb',
  'spec/login_spec_helper.rb',
]) {
  test(`launcher browser dependency selects the shared suites: ${filename}`, async () => {
    const result = await classify({ files: [{ filename }] });
    assert.deepEqual(result.decisions, SHARED);
    assert.deepEqual(result.calls, ['listFiles']);
    assert.deepEqual(result.notices, []);
  });
}

for (const filename of [
  'lib/webui/runtime.rb', 'lib/webui.rb',
  'lib/common/script_scope/gtk/boot.rb', 'lib/common/script_scope.rb', 'lib/common/script_death.rb',
  'spec/webui/browser.spec.cjs', 'spec/fixtures/webui/fixture.json', 'spec/lib/webui/runtime_spec.rb',
  'spec/lib/common/script_scope_widgets_spec.rb', 'spec/support/webui_browser.rb', 'spec/spec_helper.rb',
  'spec/support/frontend_mock.rb',
  'Gemfile', 'Gemfile.lock',
  '.ruby-version', // setup-ruby reads it for the browser job
]) {
  test(`existing WebUI dependency remains selected: ${filename}`, async () => {
    assert.deepEqual(await decisionsFor(filename), expectedFor(filename));
  });
}

// Files the launcher presentation browser spec and the login helpers load;
// each one maps to a distinct WEBUI_PATHS entry.
for (const filename of [
  'spec/lib/common/webui_launcher_presentation_browser_spec.rb', 'spec/support/data_dir.rb',
  '.rspec', '.rspec_parallel',
  'lib/common/authentication/entry_store.rb', 'lib/common/gui/master_password_manager.rb', 'lib/common/gui_login.rb',
  'lib/common/front-end.rb', 'lib/common/frontend.rb', 'lib/common/frontend_editor.rb',
  'lib/common/session_launcher.rb', 'lib/common/saga_launch_policy.rb', 'lib/common/saga_managed_launcher.rb',
  'lib/common/process_launcher.rb', 'lib/common/ruby_executable.rb', 'lib/common/sharing_violation_retry.rb',
  'lib/common/windows_command_line.rb', 'lib/util/deep_freeze.rb',
]) {
  test(`launcher provider dependency selects the shared suites: ${filename}`, async () => {
    assert.deepEqual(await decisionsFor(filename), expectedFor(filename));
  });
}

for (const filename of MACOS_FILES) {
  test(`macOS native dependency selects every suite: ${filename}`, async () => {
    const result = await classify({ files: [{ filename }] });
    assert.deepEqual(result.decisions, ALL);
    assert.ok(result.infos.some(message => message.startsWith('macos:') && message.includes(filename)), 'the matched path is explained');
  });
}

test('WebUI code outside the native host does not select macOS', async () => {
  for (const filename of [
    'lib/webui/runtime.rb', 'lib/webui/native_host.rb', 'lib/webui/assets/app.js', 'lib/webui/nativeish/Host.swift',
    'lib/common/webui_launcher.rb', 'lib/common/script_scope.rb', 'lib/common/authentication/entry_store.rb',
    'spec/lib/webui/runtime_spec.rb', 'spec/lib/webui/native_host_presentation_spec.rb.bak',
    'spec/webui/browser.spec.cjs', 'spec/support/webui_browser.rb', '.rspec_parallel', 'Gemfile.lock',
  ]) {
    assert.deepEqual(await decisionsFor(filename), SHARED, filename);
  }
});

for (const filename of WINDOWS_STARTUP_FILES) {
  test(`startup or gem-recovery dependency selects only Windows: ${filename}`, async () => {
    const result = await classify({ files: [{ filename }] });
    assert.deepEqual(result.decisions, WINDOWS_ONLY);
    assert.ok(result.infos.some(message => message.startsWith('windows:') && message.includes(filename)), 'the matched path is explained');
    assert.ok(result.infos.includes('macos: not needed'));
  });
}

test('the Windows startup list names files that exist, and leaves the release version file out', async () => {
  const root = path.join(__dirname, '../..');
  for (const filename of WINDOWS_STARTUP_FILES) assert.ok(fs.existsSync(path.join(root, filename)), filename);
  // Every release rewrites lib/version.rb; it must not start a Windows run.
  assert.deepEqual(await decisionsFor('lib/version.rb'), NONE);
});

for (const filename of WINDOWS_ACCEPTANCE_FILES) {
  test(`default-startup acceptance helper selects only Windows: ${filename}`, async () => {
    const result = await classify({ files: [{ filename }] });
    assert.deepEqual(result.decisions, WINDOWS_ONLY);
    assert.ok(result.infos.some(message => message.startsWith('windows:') && message.includes(filename)), 'the matched path is explained');
    assert.ok(result.infos.includes('macos: not needed'));
  });
}

test('the acceptance helper list names files that exist, and near-miss paths select nothing', async () => {
  const root = path.join(__dirname, '../..');
  for (const filename of WINDOWS_ACCEPTANCE_FILES) assert.ok(fs.existsSync(path.join(root, filename)), filename);
  for (const filename of ['spec/support/default_webui_acceptance.rb', 'spec/support/default_webui_report.rb']) {
    assert.deepEqual(await decisionsFor(filename), NONE, filename);
  }
});

test('a rename out of the acceptance helper prefix still selects Windows', async () => {
  const result = await classify({ files: [{ filename: 'spec/support/retired_helper.rb', previous_filename: WINDOWS_ACCEPTANCE_FILES[0], status: 'renamed' }] });
  assert.deepEqual(result.decisions, WINDOWS_ONLY);
});

for (const filename of ALL_SUITE_FILES) {
  test(`a change to suite selection or execution selects every suite: ${filename}`, async () => {
    assert.deepEqual(await decisionsFor(filename), ALL);
  });
}

test('one shared dependency among unrelated files selects exactly its suites', async () => {
  const unrelated = Array.from({ length: 5 }, (_, index) => ({ filename: `docs/unrelated-${index}.md` }));
  assert.deepEqual((await classify({ files: [...unrelated, { filename: 'lib/gemcheck.rb' }] })).decisions, WINDOWS_ONLY);
  assert.deepEqual((await classify({ files: [...unrelated, { filename: 'lib/webui/page.rb' }] })).decisions, SHARED);
  assert.deepEqual((await classify({ files: [{ filename: 'lib/gemcheck.rb' }, { filename: 'lib/webui/native/macos/Host.swift' }] })).decisions, ALL);
});

// Every helper that .rspec or .rspec_parallel loads into all examples (browser
// ones included) must select the shared suites, so an edit to the next globally
// loaded helper cannot skip the browser checks.
// Parses the require targets of an rspec options file. The space, `=` and
// attached (`-r./path`) forms are accepted; any other line that starts with
// --require or -r fails visibly instead of being skipped.
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
  test(`every --require in ${rspecFile} selects the shared suites`, async () => {
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
      const decisions = await decisionsFor(filename);
      for (const suite of ['renderer', 'browser', 'windows']) assert.equal(decisions[suite], 'true', `${rspecFile}: ${filename}: ${suite}`);
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

test('every browser shard spec file selects the shared suites', async () => {
  const shardFiles = browserShardFiles(workflow);
  assert.ok(shardFiles.length > 0, 'expected browser shard spec files');
  for (const filename of shardFiles) {
    assert.deepEqual(await decisionsFor(filename), SHARED, filename);
  }
});

test('a CRLF checkout of the workflows yields the same classifier and shards', () => {
  const crlf = ci.replace(/\n/g, '\r\n');
  assert.ok(crlf.includes('\r\n'));
  assert.equal(lf(crlf), ci);
  assert.equal(classifierSource(lf(crlf)), classifierSource());
  const webui = workflow.replace(/\n/g, '\r\n');
  assert.deepEqual(browserShardFiles(lf(webui)), browserShardFiles(workflow));
  assert.ok(workflow.indexOf('\n  renderer:\n') >= 0 && workflow.indexOf('\n  browser:\n') >= 0);
});

for (const filename of [
  'docs/unrelated.md', 'README.adoc', 'scripts/unrelated.lic', 'lib/common/unrelated.rb', 'lib/dragonrealms/commons/common.rb',
  'lib/common/webui_launcher.rb.bak', 'lib/common/webui_launcher_extra.rb',
  'lib/common/webui_launcher_other/catalog.rb',
  'spec/login_spec_helper.rb.bak', 'spec/support/frontend_mock.rb.bak', 'spec/support/real_keychain_fence.rb.bak',
  'lib/common/gui_login.rb.bak', 'spec/support/data_dir.rb.bak',
  'spec/lib/main/unrelated_spec.rb', 'spec/lib/main/default_webui_acceptance_report_spec.rb.bak',
  'spec/lib/real_keychain_fence_spec.rb.bak', 'spec/lib/common/authentication/unrelated_spec.rb',
  'lich.rbw.bak', 'lib/gemcheck.rb.bak', 'lib/main/early_exit_extra.rb', 'lib/gemcheck_extra.rb',
  '.github/workflows/lint_pr.yaml', '.github/workflows/ci.yml.bak', '.github/scripts/check_r4l5_contract.rb',
]) {
  test(`unrelated or near-prefix path selects nothing: ${filename}`, async () => {
    const result = await classify({ files: [{ filename }] });
    assert.deepEqual(result.decisions, NONE);
    for (const suite of SUITES) assert.ok(result.infos.includes(`${suite}: not needed`), suite);
  });
}

test('renames into and out of a suite scope select that suite', async () => {
  for (const file of [
    { filename: 'lib/common/webui_launcher/new_view.rb', previous_filename: 'lib/common/old_view.rb' },
    { filename: 'lib/common/retired_view.rb', previous_filename: 'lib/common/webui_launcher/old_view.rb' },
  ]) {
    assert.deepEqual((await classify({ files: [file] })).decisions, SHARED);
  }
  assert.deepEqual((await classify({ files: [{ filename: 'lib/retired.rb', previous_filename: 'lib/gemcheck.rb', status: 'renamed' }] })).decisions, WINDOWS_ONLY);
  assert.deepEqual((await classify({ files: [{ filename: 'docs/retired.swift', previous_filename: 'lib/webui/native/macos/Host.swift', status: 'renamed' }] })).decisions, ALL);
  assert.deepEqual((await classify({ files: [{ filename: 'lib/webui/native/macos/Host.swift', status: 'removed' }] })).decisions, ALL);
});

for (const [count, expected] of [[0, NONE], [2_999, NONE], [3_000, ALL]]) {
  test(`unrelated pull request file count ${count} preserves the API-cap fallback`, async () => {
    const files = Array.from({ length: count }, (_, index) => ({ filename: `docs/unrelated-${index}.md` }));
    assert.deepEqual((await classify({ files })).decisions, expected);
  });
}

test('changed-file API failure runs every suite and records the reason', async () => {
  for (const eventName of ['pull_request', 'push']) {
    const result = await classify({ eventName, apiError: new Error('fixture API failure') });
    assert.deepEqual(result.decisions, ALL);
    assert.equal(result.calls.length, 1);
    assert.deepEqual(result.notices, ['Could not classify changed files (fixture API failure); running every WebUI suite.']);
    assert.deepEqual(result.contentCalls, []);
  }
});

test('Windows selection API and parse failures run every suite and record the reason', async () => {
  for (const [options, reason] of [
    [{ contentError: new Error('fixture content failure') }, 'fixture content failure'],
    [{ contentData: { encoding: 'none', content: '' } }, 'expected the Windows workflow file content'],
    [{ windows: 'missing table' }, 'expected the Windows RSpec selection table'],
    [{ windows: '          $groups = [ordered]@{\n          }' }, 'expected the Windows RSpec selection table'],
    [{ windows: "          $groups = [ordered]@{\n            empty = @()\n          }" }, 'expected selected Windows specs'],
  ]) {
    for (const eventName of ['pull_request', 'push']) {
      const result = await classify({ eventName, ...options });
      assert.deepEqual(result.decisions, ALL);
      assert.equal(result.contentCalls.length, 1);
      assert.deepEqual(result.notices, [`Could not classify changed files (${reason}); running every WebUI suite.`]);
    }
  }
});

test('a push is classified from its own files, like a pull request', async () => {
  for (const [filename, expected] of [
    ['docs/unrelated.md', NONE], ['scripts/unrelated.lic', NONE],
    ['lib/webui/page.rb', SHARED], ['lib/gemcheck.rb', WINDOWS_ONLY],
    ['lib/webui/native/macos/Host.swift', ALL], ['.github/workflows/ci.yml', ALL],
  ]) {
    const result = await classify({ eventName: 'push', files: [{ filename }] });
    assert.deepEqual(result.decisions, expected, filename);
    assert.deepEqual(result.calls, ['compareCommits']);
    assert.deepEqual(result.notices, []);
  }
  const renamed = await classify({ eventName: 'push', files: [{ filename: 'lib/retired.rb', previous_filename: 'lib/gemcheck.rb' }] });
  assert.deepEqual(renamed.decisions, WINDOWS_ONLY);
});

test('a push with no usable comparison runs every suite', async () => {
  for (const before of ['', '0000000000000000000000000000000000000000', null]) {
    const result = await classify({ eventName: 'push', before, files: [{ filename: 'docs/unrelated.md' }] });
    assert.deepEqual(result.decisions, ALL, String(before));
    assert.deepEqual(result.calls, []);
    assert.equal(result.notices.length, 1);
  }
  // The comparison lists at most 300 files, and may omit the list entirely.
  const capped = Array.from({ length: 300 }, (_, index) => ({ filename: `docs/unrelated-${index}.md` }));
  assert.deepEqual((await classify({ eventName: 'push', files: capped })).decisions, ALL);
  assert.deepEqual((await classify({ eventName: 'push', files: capped.slice(1) })).decisions, NONE);
  assert.deepEqual((await classify({ eventName: 'push', compareData: {} })).decisions, ALL);
});

for (const eventName of ['workflow_dispatch', 'schedule', 'pull_request_target']) {
  test(`${eventName} runs every suite without calling the changed-file APIs`, async () => {
    const result = await classify({ eventName });
    assert.deepEqual(result.decisions, ALL);
    assert.deepEqual(result.calls, []);
    assert.deepEqual(result.contentCalls, []);
    assert.equal(result.notices.length, 1);
  });
}

test('one checkout-free classify job decides for every suite', () => {
  const block = jobBlock(ci, 'classify').join('\n');
  assert.doesNotMatch(block, /uses: actions\/checkout@/);
  for (const suite of SUITES) {
    assert.ok(block.includes(`      ${suite}: \${{ steps.classify.outputs.${suite} }}`), suite);
  }
  assert.match(block, /^        id: classify$/m);
  assert.equal((ci.match(/const WEBUI_PATHS = \[/g) || []).length, 1);
  // The called workflow no longer classifies for itself.
  assert.doesNotMatch(workflow, /classify|WEBUI_PATHS|pulls\.listFiles/);
});
