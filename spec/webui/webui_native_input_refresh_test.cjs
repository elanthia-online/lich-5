// Native input refresh regressions for the shipped renderer: a focused textarea keeps
// its scroll offsets across a redraw; a native select keeps its DOM node and only the
// newest deferred render from the gesture that opens its option popup until its change,
// focusout, Escape or keyup reporting no popup, while focus alone never holds a page; and socket loss
// retires that deferred render.
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
  bindings: { save: ['activate'], choice: ['change'] }, submissions: { save: ['choice'] },
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

const pointerdown = (dom, target) => target.dispatchEvent(new dom.window.MouseEvent('pointerdown', { button: 0, bubbles: true }));
const pointerup = dom => dom.window.document.dispatchEvent(new dom.window.MouseEvent('pointerup', { button: 0, bubbles: true }));
const keydown = (dom, target, init) => target.dispatchEvent(new dom.window.KeyboardEvent('keydown', { bubbles: true, cancelable: true, ...init }));

test('focus alone does not hold a native select, so renders replace it at once', t => {
  const { dom, receive } = fixture(t);
  const { document } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'One'));
  const first = select();
  first.focus();
  receive(choiceRender(2, 'Two'));
  assert.deepEqual([select() === first, first.isConnected, title()], [false, false, 'Two']);
  assert.equal(document.activeElement, select(), 'focus follows the replacement');
});

test('a focused select receives the server answer to its change at once, with no pointer gesture', t => {
  const { dom, receive, sent } = fixture(t);
  const { document } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'Selected A'));
  const picked = select();
  picked.focus();
  picked.value = 'b';
  picked.dispatchEvent(new dom.window.Event('change', { bubbles: true }));
  assert.equal(sent.some(message => message.cid === 'choice' && message.event === 'change'), true, 'the change reached the server');
  receive(choiceRender(2, 'Selected B'));
  assert.deepEqual([title(), select() === picked, document.activeElement === select()], ['Selected B', false, true],
    'the answer shows while the select still has focus');
});

test('a pointer-opened native select keeps its node and only the newest render until its change releases it', t => {
  const { dom, receive, runTimers } = fixture(t);
  const { document } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'One'));
  const open = select();
  open.focus();
  pointerdown(dom, open);
  pointerup(dom);
  runTimers(0);
  receive(choiceRender(2, 'Two'));
  receive(choiceRender(3, 'Three'));
  const observed = { whileOpen: [select() === open, open.isConnected, title()] };
  open.value = 'b';
  open.dispatchEvent(new dom.window.Event('change', { bubbles: true }));
  observed.beforeTimer = title();
  runTimers(0);
  observed.afterChange = [select() === open, title()];
  receive(choiceRender(4, 'Four'));
  observed.answer = title();
  assert.deepEqual(observed, {
    whileOpen: [true, true, 'One'],
    beforeTimer: 'One',
    afterChange: [false, 'Three'],
    answer: 'Four'
  });
});

test('focusout or an Escape releases a held native select to the newest render', t => {
  const { dom, receive, runTimers } = fixture(t);
  const { document } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'One'));
  const observed = {};

  const first = select();
  first.focus();
  pointerdown(dom, first);
  pointerup(dom);
  runTimers(0);
  receive(choiceRender(2, 'Two'));
  observed.heldByPointer = [select() === first, title()];
  first.blur();
  observed.beforeFocusoutTimer = title();
  runTimers(0);
  observed.afterFocusout = [select() === first, title()];

  const second = select();
  second.focus();
  pointerdown(dom, second);
  pointerup(dom);
  runTimers(0);
  receive(choiceRender(3, 'Three'));
  observed.heldAgain = [select() === second, title()];
  keydown(dom, second, { key: 'Escape' });
  runTimers(0);
  observed.afterEscape = [select() === second, title()];
  assert.deepEqual(observed, {
    heldByPointer: [true, 'One'],
    beforeFocusoutTimer: 'One',
    afterFocusout: [false, 'Two'],
    heldAgain: [true, 'Two'],
    afterEscape: [false, 'Three']
  });
});

test('Space, F4 and arrows with every modifier on a select hold its page; the same keys elsewhere do not', t => {
  const { dom, receive, runTimers } = fixture(t);
  const { document } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'Zero'));
  const observed = {};
  let generation = 1;
  // Each key either holds the page (the select survives the next render) or does not;
  // an Escape then ends any hold so the next case starts clean.
  const press = (target, init) => {
    const before = select();
    target.focus();
    keydown(dom, target, init);
    receive(choiceRender(generation += 1, `Render ${generation}`));
    const held = select() === before;
    keydown(dom, document.activeElement, { key: 'Escape' });
    runTimers(0);
    return held;
  };
  observed.space = press(select(), { key: ' ' });
  observed.f4 = press(select(), { key: 'F4' });
  observed.altArrow = press(select(), { key: 'ArrowDown', altKey: true });
  // These are potential opening keys; the real engine decides whether a popup opens.
  observed.plainArrow = press(select(), { key: 'ArrowDown' });
  observed.plainArrowUp = press(select(), { key: 'ArrowUp' });
  observed.ctrlArrow = press(select(), { key: 'ArrowDown', ctrlKey: true });
  observed.metaArrow = press(select(), { key: 'ArrowDown', metaKey: true });
  observed.shiftArrow = press(select(), { key: 'ArrowDown', shiftKey: true });
  observed.spaceOnButton = press(document.querySelector('button[data-cid="save"]'), { key: ' ' });
  assert.deepEqual(observed, {
    space: true, f4: true, altArrow: true, plainArrow: true, plainArrowUp: true,
    ctrlArrow: true, metaArrow: true, shiftArrow: true, spaceOnButton: false
  });
  assert.equal(title(), `Render ${generation}`);
});

// Without a change or a keyup reporting no popup, the fallback hold lasts until
// focusout or Escape. The real-engine suite covers keyup with native :open state.
test('a plain arrow with no change or keyup keeps its hold until focus-out releases it', t => {
  const { dom, receive, runTimers } = fixture(t);
  const { document } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'One'));
  const held = select();
  held.focus();
  keydown(dom, held, { key: 'ArrowDown' });
  receive(choiceRender(2, 'Two'));
  runTimers(0);
  const observed = { whileHeld: [select() === held, title()] };
  held.blur();
  runTimers(0);
  observed.afterFocusout = [select() === held, title()];
  assert.deepEqual(observed, { whileHeld: [true, 'One'], afterFocusout: [false, 'Two'] });
});

test('with a pointer gesture still held, focusout of a native select re-defers until the release', t => {
  const { dom, receive, sent, runTimers } = fixture(t);
  const { document } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'One'));
  const held = select();
  held.focus();
  pointerdown(dom, held);
  receive(choiceRender(2, 'Two'));
  receive(choiceRender(3, 'Three'));
  const observed = { newestOnly: [select() === held, title()] };
  held.blur();
  runTimers(0);
  observed.heldGesture = [select() === held, title()];
  pointerup(dom);
  runTimers(0);
  observed.released = title();
  document.querySelector('button[data-cid="save"]').click();
  observed.save = [sent.at(-1).event, sent.at(-1).generation, sent.at(-1).submission];
  assert.deepEqual(observed, {
    newestOnly: [true, 'One'],
    heldGesture: [true, 'One'],
    released: 'Three',
    save: ['activate', 3, ['a']]
  });
});

test('socket loss retires a render deferred by an open native select', t => {
  const { dom, receive, sent, runTimers, disconnect, reconnect } = fixture(t);
  const { document } = dom.window;
  const select = () => document.querySelector('[data-cid="choice"] select');
  const title = () => document.querySelector('h1').textContent;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(choiceRender(1, 'One'));
  const focused = select();
  focused.focus();
  pointerdown(dom, focused);
  pointerup(dom);
  runTimers(0);
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
