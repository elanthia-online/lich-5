// Announcement and reconnect regressions for the shipped renderer: announcements
// are literal text in one persistent live region with the authored politeness, and
// reconnect delay doubles per failed attempt, caps at 5 seconds and resets on open.
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
  // Fake timers: reconnect attempts run only when a test asks.
  const timers = new Map();
  let sequence = 0;
  dom.window.setTimeout = (callback, delay = 0) => { timers.set(++sequence, { callback, delay }); return sequence; };
  dom.window.clearTimeout = id => timers.delete(id);
  const sockets = [];
  dom.window.WebSocket = class {
    static OPEN = 1;
    readyState = 0;
    listeners = {};
    constructor() { sockets.push(this); }
    addEventListener(name, callback) { this.listeners[name] = callback; }
    send() {}
  };
  for (const asset of browserAssets()) dom.window.eval(asset.source);
  const current = () => sockets.at(-1);
  return { dom, sockets,
    open: () => { current().readyState = 1; current().listeners.open(); },
    receive: message => current().listeners.message({ data: JSON.stringify(message) }),
    // Closes the current socket and runs only the reconnect timer that close scheduled.
    fail: () => {
      const before = sequence;
      current().readyState = 3;
      current().listeners.close();
      const scheduled = [...timers].filter(([id]) => id > before);
      assert.equal(scheduled.length, 1, 'close schedules exactly one reconnect');
      const [[id, timer]] = scheduled;
      timers.delete(id);
      const count = sockets.length;
      timer.callback();
      assert.equal(sockets.length, count + 1, 'the reconnect timer opens a new socket');
      return timer.delay;
    } };
}

test('announcements render literal text into one live region with the authored politeness, replacing the last', t => {
  const { dom, open, receive } = fixture(t);
  const { document } = dom.window;
  const announcer = document.getElementById('announcer');
  const announce = (generation, text, politeness) => receive({ type: 'render', page: 'status', generation,
    facilities: { announce: { text, politeness } },
    tree: { type: 'page', cid: 'root', props: { title: 'Status' }, children: [] } });
  const region = () => {
    const live = document.querySelectorAll('[aria-live]');
    return {
      same: document.getElementById('announcer') === announcer,
      live: announcer.getAttribute('aria-live'),
      hidden: announcer.getAttribute('aria-hidden'),
      text: announcer.textContent,
      elements: announcer.children.length,
      duplicates: [...live].filter(node => node.textContent === announcer.textContent && node !== announcer).length
    };
  };
  open();
  receive({ type: 'hello', pages: [{ address: 'status' }] });
  const markup = '<b>Saved</b> & <img src="x" onerror="alert(1)">';
  announce(1, markup, 'assertive');
  const first = region();
  announce(2, 'Second update', 'polite');
  const second = region();
  assert.deepEqual({ first, second }, {
    first: { same: true, live: 'assertive', hidden: null, text: markup, elements: 0, duplicates: 0 },
    second: { same: true, live: 'polite', hidden: null, text: 'Second update', elements: 0, duplicates: 0 }
  });
});

test('reconnect delay doubles on each failed attempt, caps at 5 seconds and resets after a successful open', t => {
  const { fail, open } = fixture(t);
  const failures = Array.from({ length: 8 }, () => fail());
  open();
  const afterOpen = [fail(), fail()];
  assert.deepEqual({ failures, afterOpen }, {
    failures: [250, 500, 1000, 2000, 4000, 5000, 5000, 5000],
    afterOpen: [250, 500]
  });
});
