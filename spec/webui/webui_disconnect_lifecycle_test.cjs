// Transport-loss regressions for the shipped renderer: disconnected pages go inert
// and silent, reconnect reconciles the complete page catalog, and pagehide never
// turns a reload into detach or page closure.
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
  const { HTMLElement, HTMLDialogElement } = dom.window;
  // jsdom lacks inert and modal dialogs; reflect inert as its attribute and let
  // showModal set the reflected open state.
  Object.defineProperty(HTMLElement.prototype, 'inert', {
    configurable: true,
    get() { return this.hasAttribute('inert'); },
    set(value) { this.toggleAttribute('inert', value); }
  });
  HTMLDialogElement.prototype.showModal = function () { this.setAttribute('open', ''); };
  // Fake timers: reconnect backoff, spin holds and pointer release run only when a test asks.
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
  return { dom, sent, sockets, timers, runTimers,
    receive: message => current().listeners.message({ data: JSON.stringify(message) }),
    disconnect: () => { current().readyState = 3; current().listeners.close(); },
    reconnect: () => { const count = sockets.length; runTimers(250); assert.equal(sockets.length, count + 1, 'expected a reconnect socket'); } };
}

const formTree = title => ({ type: 'page', cid: 'root', props: { title }, children: [
  { type: 'text_input', cid: 'name', props: { value: '' } },
  { type: 'button', cid: 'save', props: { label: 'Save' } },
  { type: 'number_input', cid: 'spin', props: { value: 0, min: 0, max: 100, step: 1, digits: 0,
    snap_to_step: false, acceleration: 2, page_step: 5, stepper_buttons: true } },
  { type: 'dialog', cid: 'notice', props: { title: 'Notice', buttons: [{ id: 'ok', label: 'OK' }] } }
] });
const formRender = (generation, title, resume) => ({ type: 'render', page: 'form', generation, resume,
  bindings: { name: ['change'], save: ['activate'], spin: ['change'], notice: ['response'] },
  submissions: { save: ['name'] }, tree: formTree(title) });

test('socket loss shows the disconnect banner, makes pages inert and silent, and keeps drafts until a fresh render', async t => {
  const { dom, receive, sent, timers, disconnect, reconnect } = fixture(t);
  const { document, Event, MouseEvent } = dom.window;
  const status = document.getElementById('status');
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(formRender(1, 'Form', 'resume-1'));
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(status.className, 'visually-hidden');
  document.querySelector('[data-cid="name"] input').value = 'draft text';
  // A held spin step also holds the page pointer gesture.
  document.querySelector('[aria-label=Increase]').dispatchEvent(new MouseEvent('pointerdown', { button: 0, bubbles: true }));
  assert.ok([...timers.values()].some(timer => timer.delay === 500), 'the held spin starts its repeat timer');
  const beforeLoss = sent.length;

  disconnect();
  const observed = {
    banner: [status.textContent, status.className, status.getAttribute('aria-live')],
    pageInert: document.querySelector('[data-page-address="form"]').inert,
    dialogInert: document.querySelector('dialog[data-cid="notice"]').inert,
    inputTimers: [...timers.values()].filter(timer => [50, 500].includes(timer.delay)).length
  };
  reconnect();
  const name = document.querySelector('[data-cid="name"] input');
  document.querySelector('button[data-cid="save"]').click();
  name.dispatchEvent(new Event('change'));
  observed.eventsBeforeFreshRender = sent.slice(beforeLoss).filter(message => message.type === 'event').map(message => message.event);
  observed.draftAfterLoss = name.value;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  observed.attachResume = sent.filter(message => message.type === 'attach').map(message => message.resume ?? null);
  receive(formRender(2, 'Form (2)', 'resume-2'));
  observed.freshTitle = document.querySelector('h1').textContent;
  observed.freshInert = document.querySelector('[data-page-address="form"]').inert;
  observed.freshStatus = status.className;
  observed.freshDraft = document.querySelector('[data-cid="name"] input').value;
  document.querySelector('button[data-cid="save"]').click();
  observed.freshSave = [sent.at(-1).event, sent.at(-1).generation, sent.at(-1).submission];
  assert.deepEqual(observed, {
    banner: ['Disconnected; reconnecting', 'connection-status', 'polite'],
    pageInert: true, dialogInert: true, inputTimers: 0,
    eventsBeforeFreshRender: [], draftAfterLoss: 'draft text',
    attachResume: [null, 'resume-1'],
    // A gesture held across the loss must not defer the fresh render.
    freshTitle: 'Form (2)', freshInert: false, freshStatus: 'visually-hidden', freshDraft: 'draft text',
    freshSave: ['activate', 2, ['draft text']]
  });
});

test('a render deferred by a gesture is retired at socket loss, not applied while disconnected', async t => {
  const { dom, receive, runTimers, disconnect } = fixture(t);
  const { document, MouseEvent } = dom.window;
  receive({ type: 'hello', pages: [{ address: 'form' }] });
  receive(formRender(1, 'Form', 'resume-1'));
  await new Promise(resolve => setImmediate(resolve));
  document.querySelector('[data-page-address="form"]').dispatchEvent(new MouseEvent('pointerdown', { button: 0, bubbles: true }));
  receive(formRender(2, 'Form (deferred)', 'resume-2'));
  assert.equal(document.querySelector('h1').textContent, 'Form', 'the held gesture defers the render');
  disconnect();
  document.dispatchEvent(new MouseEvent('pointerup', { button: 0, bubbles: true }));
  runTimers(0);
  assert.equal(document.querySelector('h1').textContent, 'Form', 'a pre-loss deferred render must not apply after disconnect');
  assert.equal(document.querySelector('[data-page-address="form"]').inert, true);
});

test('socket loss disposes a retained secret-bearing retry and never resends the secret', t => {
  const { dom, receive, sent, disconnect, reconnect } = fixture(t);
  const { document } = dom.window;
  receive({ type: 'hello', pages: [{ address: 'login' }] });
  const render = generation => ({ type: 'render', page: 'login', generation,
    bindings: { save: ['activate'] }, submissions: { save: ['secret'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Login' }, children: [
      { type: 'password_input', cid: 'secret', props: {} },
      { type: 'button', cid: 'save', props: { label: 'Save' } }
    ] } });
  receive(render(1));
  document.querySelector('[data-cid="secret"] input').value = 'fixture-secret';
  document.querySelector('button[data-cid="save"]').click();
  const first = sent.at(-1);
  assert.deepEqual(first.submission, ['fixture-secret']);
  // The stale refusal arms a one-time retry of the secret-bearing snapshot.
  receive({ type: 'refusal', reason: 'stale_generation', page: 'login', cid: 'save', event: 'activate', request: first.request });
  const beforeLoss = sent.length;
  disconnect();
  reconnect();
  document.querySelector('button[data-cid="save"]').click();
  const reconnecting = sent.slice(beforeLoss);
  receive({ type: 'hello', pages: [{ address: 'login' }] });
  const beforeRender = sent.length;
  receive(render(2));
  const replayed = sent.slice(beforeRender);
  assert.deepEqual({
    sentBeforeFreshRender: reconnecting.filter(message => message.type === 'event'),
    replayedAfterFreshRender: replayed,
    secretResent: JSON.stringify(sent.slice(beforeLoss)).includes('fixture-secret')
  }, { sentBeforeFreshRender: [], replayedAfterFreshRender: [], secretResent: false });
});

test('a reconnect hello retires a page closed while offline and resumes survivors; pages is a complete list', t => {
  const { dom, receive, sent, disconnect, reconnect } = fixture(t);
  const { document, Event } = dom.window;
  const bridge = { minimized: false, present() {} };
  dom.window.lichNativeWindow = bridge;
  const tree = title => ({ type: 'page', cid: 'root', props: { title }, children: [] });
  const watched = (page, generation, resume) => ({ type: 'render', page, generation, resume,
    bindings: { root: ['window_state'] }, tree: tree(page) });
  const windowStates = () => sent.filter(message => message.event === 'window_state').map(message => message.page);
  const minimize = () => { bridge.minimized = !bridge.minimized; dom.window.dispatchEvent(new Event('lich-window-state')); };
  const shown = address => document.querySelector(`[data-page-address="${address}"]`) !== null;
  receive({ type: 'hello', pages: [{ address: 'keep' }, { address: 'gone' }] });
  receive({ type: 'render', page: 'keep', generation: 1, resume: 'keep-1', tree: tree('Keep') });
  receive(watched('gone', 1, 'gone-1'));
  assert.deepEqual(windowStates(), ['gone']);

  disconnect();
  reconnect();
  const beforeHello = sent.length;
  receive({ type: 'hello', pages: [{ address: 'keep' }] });
  const observed = {
    helloAttach: sent.slice(beforeHello).map(message => [message.type, message.page, message.resume]),
    goneShown: shown('gone')
  };
  // A late render for the retired page cannot revive it or its window-state listener.
  receive(watched('gone', 2, 'gone-2'));
  minimize();
  observed.goneAfterLateRender = [shown('gone'), windowStates()];
  receive({ type: 'render', page: 'keep', generation: 2, resume: 'keep-2', tree: tree('Keep (2)') });
  observed.keepResumed = document.querySelector('[data-page-address="keep"] h1')?.textContent;

  receive({ type: 'pages', pages: [{ address: 'keep' }, { address: 'extra' }] });
  receive(watched('extra', 1, 'extra-1'));
  const beforePages = sent.length;
  receive({ type: 'pages', pages: [{ address: 'keep' }] });
  observed.pagesSent = sent.slice(beforePages);
  observed.pagesShown = [shown('keep'), shown('extra')];
  minimize();
  observed.windowStates = windowStates();
  assert.deepEqual(observed, {
    helloAttach: [['attach', 'keep', 'keep-1']], goneShown: false,
    goneAfterLateRender: [false, ['gone']], keepResumed: 'Keep (2)',
    // pages is a complete list: survivors are not reattached and absent pages retire.
    pagesSent: [], pagesShown: [true, false], windowStates: ['gone', 'extra']
  });
});

test('pagehide on reload sends no detach or close while another viewer stays live and transport loss still resumes', t => {
  const viewers = [fixture(t), fixture(t)];
  viewers.forEach(({ receive }, index) => {
    receive({ type: 'hello', pages: [{ address: 'settings' }] });
    receive({ type: 'render', page: 'settings', generation: 1, resume: `viewer-${index}`, bindings: { save: ['activate'] },
      tree: { type: 'page', cid: 'root', props: { title: 'Settings' }, children: [
        { type: 'button', cid: 'save', props: { label: 'Save' } }
      ] } });
  });
  const [leaving, staying] = viewers;
  const before = leaving.sent.length;
  leaving.dom.window.dispatchEvent(new leaving.dom.window.PageTransitionEvent('pagehide', { persisted: false }));
  const closing = leaving.sent.slice(before).filter(message =>
    ['detach', 'close'].includes(message.type) || ['detach', 'close'].includes(message.event));
  assert.deepEqual(closing, [], 'reload must not send detach or claim page closure');

  staying.dom.window.document.querySelector('button[data-cid="save"]').click();
  assert.deepEqual([staying.sent.at(-1).event, staying.sent.at(-1).generation], ['activate', 1], 'the other viewer stays live');

  leaving.disconnect();
  leaving.reconnect();
  leaving.receive({ type: 'hello', pages: [{ address: 'settings' }] });
  assert.deepEqual(leaving.sent.filter(message => message.type === 'attach').map(message => message.resume), [undefined, 'viewer-0'],
    'transport loss after pagehide still resumes the viewer');
  leaving.receive({ type: 'render', page: 'settings', generation: 2, resume: 'viewer-0b', bindings: { save: ['activate'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Settings' }, children: [
      { type: 'button', cid: 'save', props: { label: 'Save' } }
    ] } });
  leaving.dom.window.document.querySelector('button[data-cid="save"]').click();
  assert.deepEqual([leaving.sent.at(-1).event, leaving.sent.at(-1).generation], ['activate', 2]);
});
