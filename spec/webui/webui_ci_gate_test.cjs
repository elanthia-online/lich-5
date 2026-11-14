const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const { ci, jobBlock, gateSource, read } = require('./workflow_classification_source.cjs');

// The classifier output that decides each suite, and the job that runs it.
const SUITE_JOBS = { renderer: 'webui_renderer', browser: 'webui_browser', windows: 'windows_webui', macos: 'macos_webui' };
const OTHER_JOBS = ['ruby', 'workflow_guard', 'test', 'changed_specs', 'windows_contract', 'webui_policy'];

// Runs the production gate script against one set of job results.
function gate(needs) {
  const failures = [], infos = [];
  const core = { info: message => infos.push(message), setFailed: message => failures.push(message) };
  vm.runInNewContext(gateSource(), { core, process: { env: { NEEDS: JSON.stringify(needs) } } }, { timeout: 1000 });
  assert.ok(failures.length <= 1, 'the gate reports once');
  return { passed: failures.length === 0, message: failures[0] || '', infos };
}

// Job results for a run in which the listed suites were selected and passed.
function results(selected = [], overrides = {}) {
  const needs = Object.fromEntries(OTHER_JOBS.map(job => [job, { result: 'success', outputs: {} }]));
  needs.classify = {
    result: 'success',
    outputs: Object.fromEntries(Object.keys(SUITE_JOBS).map(suite => [suite, selected.includes(suite) ? 'true' : 'false'])),
  };
  for (const [suite, job] of Object.entries(SUITE_JOBS)) {
    needs[job] = { result: selected.includes(suite) ? 'success' : 'skipped', outputs: {} };
  }
  for (const [job, change] of Object.entries(overrides)) {
    if (change === null) delete needs[job];
    else needs[job] = { ...needs[job], ...change };
  }
  return needs;
}

const SUITES = Object.keys(SUITE_JOBS);
const SELECTIONS = [[], ['windows'], ['macos'], ['renderer', 'browser'], ['renderer', 'browser', 'windows'], SUITES];

test('the gate passes when every selected suite passed and every other suite was skipped', () => {
  for (const selected of SELECTIONS) {
    const outcome = gate(results(selected));
    assert.equal(outcome.passed, true, `${selected.join(',') || 'none'}: ${outcome.message}`);
  }
});

test('a selected suite that failed, was cancelled or was skipped fails the gate', () => {
  for (const suite of SUITES) {
    for (const result of ['failure', 'cancelled', 'skipped']) {
      const outcome = gate(results(SUITES, { [SUITE_JOBS[suite]]: { result } }));
      assert.equal(outcome.passed, false, `${suite}: ${result}`);
      assert.ok(outcome.message.includes(SUITE_JOBS[suite]), outcome.message);
    }
  }
});

test('a suite that ran although it was not selected fails the gate', () => {
  for (const suite of SUITES) {
    for (const result of ['success', 'failure', 'cancelled']) {
      const outcome = gate(results([], { [SUITE_JOBS[suite]]: { result } }));
      assert.equal(outcome.passed, false, `${suite}: ${result}`);
      assert.ok(outcome.message.includes(SUITE_JOBS[suite]), outcome.message);
    }
  }
});

test('a classifier that failed, was cancelled or was skipped fails the gate', () => {
  for (const result of ['failure', 'cancelled', 'skipped']) {
    // Suites that depend on a failed classifier are skipped; that must not pass.
    const outcome = gate(results([], { classify: { result, outputs: {} } }));
    assert.equal(outcome.passed, false, result);
    assert.ok(outcome.message.includes('classify'), outcome.message);
  }
});

test('a missing or malformed suite decision fails the gate', () => {
  for (const suite of SUITES) {
    for (const value of [undefined, '', 'TRUE', 'yes', '1', true, null]) {
      const needs = results(SUITES);
      if (value === undefined) delete needs.classify.outputs[suite];
      else needs.classify.outputs[suite] = value;
      const outcome = gate(needs);
      assert.equal(outcome.passed, false, `${suite}: ${JSON.stringify(value)}`);
      assert.ok(outcome.message.includes(SUITE_JOBS[suite]), outcome.message);
    }
  }
  assert.equal(gate(results([], { classify: { result: 'success', outputs: undefined } })).passed, false);
});

test('every other job must succeed; none may be skipped, cancelled or failed', () => {
  for (const job of OTHER_JOBS) {
    for (const result of ['failure', 'cancelled', 'skipped']) {
      for (const selected of [[], SUITES]) {
        const outcome = gate(results(selected, { [job]: { result } }));
        assert.equal(outcome.passed, false, `${job}: ${result}`);
        assert.ok(outcome.message.includes(job), outcome.message);
      }
    }
  }
  // A job added to the gate later is held to the same rule without an edit here.
  assert.equal(gate({ ...results(), future_job: { result: 'success', outputs: {} } }).passed, true);
  assert.equal(gate({ ...results(), future_job: { result: 'skipped', outputs: {} } }).passed, false);
});

test('a suite job or the classifier missing from the gate fails it', () => {
  for (const job of ['classify', ...Object.values(SUITE_JOBS)]) {
    const outcome = gate(results(SUITES, { [job]: null }));
    assert.equal(outcome.passed, false, job);
    assert.ok(outcome.message.includes(job), outcome.message);
  }
});

test('the gate reports each job and names every failure, never a job output value', () => {
  const needs = results(['windows'], { windows_webui: { result: 'failure' }, test: { result: 'cancelled' } });
  const outcome = gate(needs);
  assert.equal(outcome.passed, false);
  assert.ok(outcome.message.includes('windows_webui') && outcome.message.includes('test'), outcome.message);
  for (const job of Object.keys(needs)) assert.ok(outcome.infos.some(message => message.startsWith(`${job}: `)), job);
});

test('ci-gate waits for exactly the jobs the gate rule covers and always evaluates', () => {
  const block = jobBlock(ci, 'ci-gate').join('\n');
  assert.match(block, /^    name: ci-gate$/m);
  assert.match(block, /^    if: always\(\)$/m);
  assert.doesNotMatch(block, /uses: actions\/checkout@|continue-on-error:/);
  const needs = block.match(/^    needs: \[([^\]]+)\]$/m)?.[1].split(',').map(name => name.trim());
  assert.ok(needs, 'expected an inline needs list');
  assert.deepEqual([...needs].sort(), [...OTHER_JOBS, 'classify', ...Object.values(SUITE_JOBS)].sort());
  assert.ok(block.includes('NEEDS: ${{ toJSON(needs) }}'));
  // Every job in the workflow other than the gate itself is in the gate.
  const jobs = [...ci.slice(ci.indexOf('\njobs:\n')).matchAll(/^ {2}([A-Za-z_][\w-]*):$/gm)].map(match => match[1]);
  assert.deepEqual(jobs.filter(job => job !== 'ci-gate').sort(), [...needs].sort());
});

test('each suite runs only on its own decision, through its called workflow', () => {
  for (const [suite, job, file, input] of [
    ['renderer', 'webui_renderer', 'webui_tests.yaml', 'renderer'],
    ['browser', 'webui_browser', 'webui_tests.yaml', 'browser'],
    ['windows', 'windows_webui', 'windows_webui.yaml', null],
    ['macos', 'macos_webui', 'macos_webui.yaml', null],
  ]) {
    const block = jobBlock(ci, job).join('\n');
    assert.match(block, /^    needs: classify$/m, job);
    assert.ok(block.includes(`    if: needs.classify.outputs.${suite} == 'true'`), job);
    assert.ok(block.includes(`    uses: ./.github/workflows/${file}`), job);
    if (input) assert.ok(block.includes(`      suite: ${input}`), job);
    else assert.doesNotMatch(block, /^    with:$/m, job);
    assert.doesNotMatch(block, /secrets:|always\(\)/, job);
  }
  // The called WebUI workflow runs one job per suite input and nothing else.
  const webui = read('.github/workflows/webui_tests.yaml');
  assert.match(jobBlock(webui, 'renderer').join('\n'), /^    if: inputs\.suite == 'renderer'$/m);
  assert.match(jobBlock(webui, 'browser').join('\n'), /^    if: inputs\.suite == 'browser'$/m);
});

test('pull request runs share a cancelling group; each push to main runs in its own', () => {
  assert.match(ci, /^concurrency:\n  group: \$\{\{ github\.workflow \}\}-\$\{\{ github\.event\.pull_request\.number \|\| github\.sha \}\}\n  cancel-in-progress: \$\{\{ github\.event_name == 'pull_request' \}\}\n/m);
  assert.doesNotMatch(ci, /cancel-in-progress: true/);
});

test('only the caller sets concurrency, and it triggers on pull requests and pushes to main', () => {
  assert.match(ci, /^on:\n  push:\n    branches:\n      - main\n  pull_request:\n\npermissions:/m);
  assert.doesNotMatch(ci, /pull_request_review|pull_request_target|^\s+types:/m);
  assert.equal((ci.match(/^concurrency:$/gm) || []).length, 1);
  for (const file of ['webui_tests.yaml', 'windows_webui.yaml', 'macos_webui.yaml']) {
    const called = read(`.github/workflows/${file}`);
    assert.doesNotMatch(called, /^\s*concurrency:/m, file);
    assert.match(called, /^on:\n  workflow_call:/m, file);
    assert.doesNotMatch(called, /^  (push|pull_request|pull_request_target|pull_request_review|workflow_run|schedule):/m, file);
  }
});

test('the policy tests run in their own job on every change, with no install step', () => {
  const block = jobBlock(ci, 'webui_policy').join('\n');
  assert.doesNotMatch(block, /^    (if|needs):/m);
  assert.doesNotMatch(block, /npm ci|npm install|playwright|bundle/);
  for (const file of [
    'webui_workflow_classification_test.cjs', 'webui_windows_workflow_test.cjs',
    'webui_macos_workflow_test.cjs', 'webui_ci_gate_test.cjs',
  ]) assert.ok(block.includes(`spec/webui/${file}`), file);
  for (const action of [...block.matchAll(/uses: ([^\n]+)/g)].map(match => match[1])) {
    assert.match(action, /^[\w/-]+@[0-9a-f]{40}(?: #.*)?$/);
  }
});
