// Exercise the shipped geometry helper with measured window values. No DOM
// package is required; full layout is checked in the actual browser fixture.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Slice a private helper out of app.js, failing by marker name when the
// helper layout changes rather than evaluating a wrong or empty slice.
function helperSource(source, start, end) {
  const from = source.indexOf(start);
  assert.notEqual(from, -1, `app.js start marker not found: ${JSON.stringify(start)}`);
  const to = source.indexOf(end);
  assert.notEqual(to, -1, `app.js end marker not found: ${JSON.stringify(end)}`);
  assert.ok(to > from, `app.js end marker ${JSON.stringify(end)} precedes start marker ${JSON.stringify(start)}`);
  return source.slice(from, to);
}

function fixture(content = true) {
  const source = fs.readFileSync(path.join(__dirname, '../../lib/webui/assets/app.js'), 'utf8');
  const handlers = new Map();
  const intervals = new Set();
  const sent = [];
  const resized = [];
  const window = { innerWidth: 196, innerHeight: 220, outerWidth: 196, outerHeight: 254,
    screenX: 20, screenY: 30,
    resizeTo: (w, h) => resized.push([w, h]),
    addEventListener: (name, callback) => handlers.set(name, callback),
    removeEventListener: (name, callback) => { if (handlers.get(name) === callback) handlers.delete(name); },
    setInterval: callback => { intervals.add(callback); return callback; },
    clearInterval: callback => intervals.delete(callback) };
  const context = vm.createContext({ window, emit: (page, component, event, payload) => sent.push(JSON.parse(payload.value)) });
  vm.runInContext(helperSource(source, '  function windowGeometry(', '  function node('), context);
  const page = {};
  const component = { props: { value: JSON.stringify({ width: 196, height: 254 }) } };
  const render = () => context.trackWindowGeometry(page, component, content);
  render();
  return { window, page, context, render, handlers, intervals, sent, resized };
}

test('restores content size plus measured decorations only once', () => {
  const f = fixture();
  assert.deepEqual(f.resized, [[196, 288]]);
  f.window.innerWidth = 240;
  f.window.innerHeight = 300;
  f.handlers.get('resize')();
  assert.deepEqual(f.sent.at(-1), { width: 240, height: 300, position: [20, 30] });
  f.render();
  assert.equal(f.resized.length, 1);
  f.handlers.get('resize')();
  assert.equal(f.sent.length, 1, 'render does not reset measurement deduplication');
  assert.equal(f.intervals.size, 1, 'render replaces the old poller');
});

test('records a move between renders and removes observers on page close', () => {
  const f = fixture();
  f.page.reportGeometry();
  f.window.screenX = 100;
  f.render();
  [...f.intervals][0]();
  assert.deepEqual(f.sent.at(-1).position, [100, 30]);
  f.context.stopWindowGeometry(f.page);
  assert.equal(f.intervals.size, 0);
  assert.equal(f.handlers.size, 0);
});

test('launcher geometry retains outer-size semantics without resizing the window', () => {
  const f = fixture(false);
  f.page.reportGeometry();
  assert.deepEqual(f.resized, []);
  assert.deepEqual(f.sent.at(-1), { width: 196, height: 254, position: [20, 30] });
});
