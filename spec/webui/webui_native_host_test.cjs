const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const { fixture } = require('./webui_renderer_fixture.cjs');

test('native and shim presentation share the host; dialogs cannot change the parent window', () => {
  const f = fixture('main');
  const calls = [];
  f.window.lichNativeWindow = { present: value => calls.push(value) };
  f.receive({ type: 'hello', pages: [{ address: 'main', title: 'Main' }] });
  const render = (generation, props, facilities = {}) => f.receive({ type: 'render', page: 'main', generation,
    tree: { type: 'page', cid: 'page', props: { title: 'Main', ...props }, children: [] }, facilities });
  render(1, { presentation: { always_on_top: true } });
  assert.equal(calls.at(-1).always_on_top, true);
  render(2, {}, { presentation: { always_on_top: false, borderless: true } });
  assert.equal(calls.at(-1).always_on_top, false);
  assert.equal(calls.at(-1).borderless, true);
  render(3, { presentation: { hidden: true } });
  assert.equal(calls.at(-1).hidden, true);
  render(4, { presentation: { hidden: false } });
  assert.equal(calls.at(-1).hidden, false);
  render(5, {});
  assert.equal(calls.at(-1).always_on_top, undefined); // absent resets native defaults
  const count = calls.length;
  f.receive({ type: 'render', page: 'dialog', generation: 1,
    tree: { type: 'page', cid: 'dialog', props: { title: 'Dialog' }, children: [] },
    facilities: { presentation: { always_on_top: false } } });
  assert.equal(calls.length, count);
});

test('the injected bridge reports native geometry and forwards ordinary window operations', () => {
  const calls = [], events = [];
  const window = { webkit: { messageHandlers: { lichWindow: { postMessage: value => calls.push(value) } } },
    dispatchEvent: event => events.push(event.type) };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../lib/webui/native/macos/window.js'), 'utf8'),
    { window, Event: class { constructor(type) { this.type = type; } } });
  window.lichNativeWindow.update({ outerWidth: 600, outerHeight: 430, screenX: -120, screenY: 50 });
  assert.equal(window.outerWidth, 600);
  assert.equal(window.screenX, -120);
  assert.deepEqual(events, ['resize']);
  window.resizeTo(700, 500);
  window.moveTo(-20, 90);
  window.close();
  assert.deepEqual(JSON.parse(JSON.stringify(calls)), [
    { action: 'resize', width: 700, height: 500 }, { action: 'move', x: -20, y: 90 }, { action: 'close' }
  ]);
});

test('native state measurements report only actual minimize transitions and forward request revisions', () => {
  const calls = [], events = [];
  const window = { webkit: { messageHandlers: { lichWindow: { postMessage: value => calls.push(value) } } }, dispatchEvent: event => events.push(event.type) };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../lib/webui/native/macos/window.js'), 'utf8'),
    { window, Event: class { constructor(type) { this.type = type; } } });
  window.lichNativeWindow.update({ minimized: false });
  window.lichNativeWindow.update({ minimized: true });
  window.lichNativeWindow.update({ minimized: true });
  window.lichNativeWindow.update({ minimized: false });
  assert.equal(window.lichNativeWindow.minimized, false);
  assert.equal(events.filter(type => type === 'lich-window-state').length, 3);
  window.lichNativeWindow.present({ minimized: true, minimized_revision: 2 });
  assert.deepEqual(JSON.parse(JSON.stringify(calls)), [{ action: 'present', minimized: true, minimized_revision: 2 }]);
});

test('native monitor snapshots reach the renderer through the existing geometry bridge', () => {
  const window = { webkit: { messageHandlers: { lichWindow: { postMessage() {} } } }, dispatchEvent() {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../lib/webui/native/macos/window.js'), 'utf8'),
    { window, Event: class {} });
  const monitors = { source: 'native', screens: [{ x: -1280, y: -100, width: 1280, height: 800, primary: false, active: true }] };
  window.lichNativeWindow.update({ outerWidth: 400, outerHeight: 200, screenX: -1000, screenY: 20, monitors });
  assert.deepEqual(window.lichNativeWindow.monitors, monitors);
});
