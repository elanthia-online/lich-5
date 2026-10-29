// Native input refresh regressions for the shipped renderer: a focused textarea keeps
// its scroll offsets across a redraw, a focused native select keeps its DOM node and
// only the newest deferred render until focusout rechecks gesture admission, and
// socket loss retires that deferred render.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const { browserAssets } = require('./webui_assets_fixture.cjs');

function fixture(t) {
  const root = path.resolve(__dirname, '../../lib/webui/assets');
  const dom = new JSDOM(fs.readFileSync(path.join(root, 'index.html'), 'utf8'), {
    url: 'http://127.0.0.1/', runScripts: 'outside-only', pretendToBeVisual: true
  });
  t.after(() => dom.window.close());
  // Fake timers: focusout admission, pointer release and reconnect run only when a test asks.
  const timers = new Map();
  let sequence = 0;
  dom.window.setTimeout = (callback, delay = 0) => { timers.set(++sequence, { callback, delay }); return sequence; };
  dom.window.clearTimeout = id => timers.delete(id);
  const runTimers = delay => {
    for (const [id, timer] of [...timers]) if (timer.delay === delay) { timers.delete(id); timer.callback(); }
  };
  const sent = [];
  const sockets = [];
  dom.window.WebSocket = class {
    static OPEN = 1;
    readyState = 1;
    listeners = {};
    constructor() { sockets.push(this); }
    addEventListener(name, callback) { this.listeners[name] = callback; }
    send(json) { sent.push(JSON.parse(json)); }
  };
  for (const asset of browserAssets()) dom.window.eval(asset.source);
  const current = () => sockets.at(-1);
  return { dom, sent, sockets, runTimers,
    receive: message => current().listeners.message({ data: JSON.stringify(message) }),
    disconnect: () => { current().readyState = 3; current().listeners.close(); },
    reconnect: () => { const count = sockets.length; runTimers(250); assert.equal(sockets.length, count + 1, 'expected a reconnect socket'); } };
}

const choiceRender = (generation, title) => ({ type: 'render', page: 'form', generation,
  bindings: { save: ['activate'] }, submissions: { save: ['choice'] },
  tree: { type: 'page', cid: 'root', props: { title }, children: [
    { type: 'select', cid: 'choice', props: { label: 'Choice', value: 'a',
      options: [{ value: 'a', label: 'A' }, { value: 'b', label: 'B' }] } },
    { type: 'button', cid: 'save', props: { label: 'Save' } }
  ] } });

test('a focused textarea keeps its scroll offsets and selection across a redraw', t => {
  const { dom, receive } = fixture(t);
  const { document } = dom.window;
  const value = Array.from({ length: 80 }, (_, line) => `line ${line} ${'x'.repeat(120)}`).join('\n');
  const render = (generation, title) => receive({ type: 'render', page: 'notes', generation,
    tree: { type: 'page', cid: 'root', props: { title }, children: [
      { type: 'textarea', cid: 'notes', props: { value, rows: 4, wrap: 'none' } }
    ] } });
  receive({ type: 'hello', pages: [{ address: 'notes' }] });
  render(1, 'Notes');
  const before = document.querySelector('[data-cid="notes"] textarea');
  before.focus();
  before.setSelectionRange(10, 14);
  before.scrollTop = 120;
  before.scrollLeft = 36;
  render(2, 'Notes (2)');
  const after = document.querySelector('[data-cid="notes"] textarea');
  assert.deepEqual({
    title: document.querySelector('h1').textContent,
    replaced: after !== before,
    focused: document.activeElement === after,
    selection: [after.selectionStart, after.selectionEnd],
    scroll: [after.scrollTop, after.scrollLeft]
  }, { title: 'Notes (2)', replaced: true, focused: true, selection: [10, 14], scroll: [120, 36] });
});

test('a focused native select keeps its node and only the newest render until focusout rechecks gesture admission', t => {
  const { dom, receive, sent, runTimers } = fixture(t);
  const { document, MouseEvent } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'One'));
  const observed = {};

  // Focusout alone admits the retained render.
  const first = select();
  first.focus();
  receive(choiceRender(2, 'Two'));
  observed.whileFocused = [select() === first, first.isConnected, title()];
  first.blur();
  observed.beforeTimer = title();
  runTimers(0);
  observed.afterFocusout = [title(), select() === first];

  // With a pointer gesture still held, focusout re-defers until the release.
  const second = select();
  second.focus();
  receive(choiceRender(3, 'Three'));
  receive(choiceRender(4, 'Four'));
  observed.newestOnly = [select() === second, title()];
  document.querySelector('[data-page-address="form"]').dispatchEvent(new MouseEvent('pointerdown', { button: 0, bubbles: true }));
  second.blur();
  runTimers(0);
  observed.heldGesture = [select() === second, title()];
  document.dispatchEvent(new MouseEvent('pointerup', { button: 0, bubbles: true }));
  runTimers(0);
  observed.released = title();
  document.querySelector('button[data-cid="save"]').click();
  observed.save = [sent.at(-1).event, sent.at(-1).generation, sent.at(-1).submission];
  assert.deepEqual(observed, {
    whileFocused: [true, true, 'One'],
    beforeTimer: 'One',
    afterFocusout: ['Two', false],
    newestOnly: [true, 'Two'],
    heldGesture: [true, 'Two'],
    released: 'Four',
    save: ['activate', 4, ['a']]
  });
});

test('socket loss retires a render deferred by a focused native select', t => {
  const { dom, receive, sent, runTimers, disconnect, reconnect } = fixture(t);
  const { document } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'One'));
  const focused = select();
  focused.focus();
  receive(choiceRender(2, 'Two'));
  const observed = { deferred: [select() === focused, title()] };
  disconnect();
  focused.blur();
  runTimers(0);
  observed.afterLoss = [select() === focused, title()];
  reconnect();
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(3, 'Three'));
  observed.fresh = title();
  document.querySelector('button[data-cid="save"]').click();
  observed.save = [sent.at(-1).event, sent.at(-1).generation];
  assert.deepEqual(observed, {
    deferred: [true, 'One'],
    afterLoss: [true, 'One'],
    fresh: 'Three',
    save: ['activate', 3]
  });
});
