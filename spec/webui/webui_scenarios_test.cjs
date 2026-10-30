const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { createRegistry, scenarioIds, selectScenario } = require('./scenarios/index.cjs');

// Independent baseline: the runner's complete allowlist before family extraction.
const originalIds = [
  "shim-canvas",
  "shim-keyboard-redraw",
  "contract-inputs",
  "launcher-unlock",
  "native-opacity-reset",
  "native-tab-redraw",
  "merchantical-help-window",
  "native-notebook-actions",
  "merchantical-notebook-actions",
  "merchantical-list",
  "priority17-drawing",
  "priority17-title-scroll",
  "priority17-widget-drag",
  "pr64-native-radio",
  "priority16-review",
  "priority16-combo-rebuild",
  "priority16-tooltips",
  "priority16-two-facades",
  "priority16-hover-choice",
  "priority16-successor-controls",
  "priority16-successor-columns",
  "priority16-events",
  "priority15-notebook",
  "priority15-log-style",
  "priority15-followup",
  "priority15-tree-text",
  "buttonbox-empty-id",
  "frame-scroller",
  "three-compatibility",
  "priority14-controls",
  "priority11-labels",
  "native-bmp",
  "shim-layout",
  "shim-fixed-events-focus",
  "shim-abyssx",
  "shim-compass",
  "shim-eloot-stance",
  "shim-gemstonev-difficulty",
  "shim-scheduled-visibility",
  "shim-repository-scheduling",
  "shim-sail2-scheduling",
  "shim-geometry-cursors",
  "native-progress-sizing",
  "shim-manatimer",
  "shim-tpick-information",
  "shim-tpick-settings",
  "shim-headerbar",
  "shim-tpick-welcome",
  "shim-entry",
  "shim-separator",
  "shim-controls",
  "shim-progress-style",
  "shim-models",
  "shim-builder",
  "shim-ewaggle",
  "shim-ebounty",
  "shim-eherbs",
  "shim-blackarts",
  "shim-eloot-corrected",
  "shim-bigshot-corrected",
  "shim-repository",
  "shim-go2",
  "shim-huntplan",
  "native-bootstrap"
];

const expectedIds = [...originalIds, 'launcher-presentation'];

test('registration preserves every original scenario exactly once and provides run callbacks', () => {
  assert.equal(originalIds.length, 64);
  assert.equal(scenarioIds.length, 65);
  assert.deepEqual([...scenarioIds].sort(), [...expectedIds].sort());
  for (const id of expectedIds) {
    const descriptor = selectScenario(id);
    assert.equal(descriptor.id, id);
    assert.equal(typeof descriptor.run, 'function');
  }
});

test('only the four original scenarios prepare the browser before navigation', () => {
  assert.deepEqual(scenarioIds.filter(id => selectScenario(id).prepare).sort(), [
    'priority17-widget-drag', 'shim-builder', 'shim-ewaggle', 'shim-manatimer',
  ]);
  assert.deepEqual(scenarioIds.filter(id => selectScenario(id).afterEach).sort(), [
    'priority17-widget-drag', 'shim-canvas',
  ]);
});

test('aliases retain one shared callback per original branch', () => {
  for (const ids of [
    ['shim-entry', 'shim-separator'],
    ['shim-repository', 'shim-go2'],
    ['shim-ebounty', 'shim-eherbs', 'shim-blackarts', 'shim-eloot-corrected', 'shim-bigshot-corrected'],
  ]) {
    for (const id of ids) assert.equal(selectScenario(id).run, selectScenario(ids[0]).run);
  }
});

test('registration refuses duplicate IDs rather than overwriting a scenario', () => {
  const run = async () => {};
  assert.throws(() => createRegistry([[{ id: 'same', run }], [{ id: 'same', run }]]), /Duplicate WebUI scenario: same/);
});

test('registration refuses malformed IDs and run/optional-hook callbacks', () => {
  const run = async () => {};
  for (const descriptor of [null, {}, { id: '', run }, { id: 1, run }, { id: 'bad' }, { id: 'bad', run: true }]) {
    assert.throws(() => createRegistry([[descriptor]]), TypeError);
  }
  for (const hook of ['prepare', 'afterEach']) {
    for (const value of [null, false, 'callback']) {
      assert.throws(() => createRegistry([[{ id: 'bad', run, [hook]: value }]]), /invalid .* callback/);
    }
  }
});

test('unknown and missing selections cannot fall through to entry/separator behavior', () => {
  for (const id of [undefined, null, '', 'unknown', 'toString', '__proto__']) {
    assert.throws(() => selectScenario(id), /Unknown WebUI scenario:/);
  }
});

test('requiring the family graph reads no environment and registers no Playwright tests', () => {
  const cache = new Map();
  const environment = new Proxy({}, { get() { throw new Error('scenario modules must not read environment at load'); } });
  function load(file) {
    if (cache.has(file)) return cache.get(file).exports;
    const module = { exports: {} };
    cache.set(file, module);
    const requireLocal = request => {
      assert.ok(request.startsWith('./'), `scenario module must not load a browser/test package: ${request}`);
      return load(path.resolve(path.dirname(file), request));
    };
    vm.runInNewContext(fs.readFileSync(file, 'utf8'), {
      module, exports: module.exports, require: requireLocal, process: { env: environment },
    }, { filename: file });
    return module.exports;
  }
  const registry = load(path.join(__dirname, 'scenarios/index.cjs'));
  assert.equal(cache.size, 11, 'one registry, nine explicit families and the canvas sampler');
  assert.deepEqual(Array.from(registry.scenarioIds).sort(), [...expectedIds].sort());
});

// Capture the real runner's test and hook declarations without starting a browser.
function runnerFixture(scenario, target) {
  let body, afterEach;
  const registrations = [];
  const playwrightTest = (name, callback) => { registrations.push(name); body = callback; };
  playwrightTest.afterEach = callback => { afterEach = callback; };
  const expect = actual => ({ toMatch: pattern => assert.match(actual, pattern) });
  const calls = [];
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'browser.spec.cjs'), 'utf8'), {
    require(request) {
      if (request === '@playwright/test') return { test: playwrightTest, expect };
      assert.equal(request, './scenarios/index.cjs');
      return { selectScenario(id) { calls.push(id); return selectScenario(id); } };
    },
    process: { env: { WEBUI_TEST_SCENARIO: scenario, WEBUI_TEST_URL: target } },
    console: { log() {} }, __dirname,
  });
  assert.equal(registrations.length, 1);
  return { body, afterEach, calls };
}

test('runner validates the bootstrap URL before selecting a scenario', async () => {
  const fixture = runnerFixture('unknown', 'http://127.0.0.1/');
  await assert.rejects(fixture.body({ page: { on() {} }, context: {} }), /did not match/);
  assert.deepEqual(fixture.calls, []);
});

test('failed selection still attaches common diagnostics without a secondary hook error', async () => {
  for (const scenario of [undefined, 'unknown']) {
    const fixture = runnerFixture(scenario, 'file:///fixture.html');
    const page = { on() {} };
    await assert.rejects(fixture.body({ page, context: {} }), /Unknown WebUI scenario:/);
    const attachments = [];
    await fixture.afterEach({ page }, { status: 'failed', expectedStatus: 'passed',
      async attach(name) { attachments.push(name); } });
    assert.deepEqual(attachments, ['webui-wire.log', 'webui-interactions.log']);
  }
});

test('drag diagnostics attach on success and failure while canvas output remains failure-only', async () => {
  const drag = selectScenario('priority17-widget-drag');
  for (const status of ['passed', 'failed']) {
    const attachments = [];
    const originalLog = console.log;
    console.log = () => {};
    try {
      await drag.afterEach({ page: { isClosed: () => false, evaluate: async () => [] },
        testInfo: { status, expectedStatus: 'passed', async attach(name) { attachments.push(name); } } });
    } finally { console.log = originalLog; }
    assert.deepEqual(attachments, ['widget-drag-events.json']);
  }
  const messages = [];
  const originalLog = console.log;
  console.log = value => messages.push(value);
  try {
    const hook = selectScenario('shim-canvas').afterEach;
    await hook({ testInfo: { status: 'passed', expectedStatus: 'passed' }, interactions: ['passed'] });
    await hook({ testInfo: { status: 'failed', expectedStatus: 'passed' }, interactions: ['failed'] });
  } finally { console.log = originalLog; }
  assert.deepEqual(messages, ['failed']);
});
