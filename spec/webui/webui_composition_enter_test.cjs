// IME composition regressions for the shipped renderer: Enter that commits a
// composition submits nothing from either local text or password handler, and an
// ordinary Enter on each still emits the terminal submit.
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
  const sent = [];
  const listeners = {};
  dom.window.WebSocket = class {
    static OPEN = 1;
    readyState = 1;
    addEventListener(name, callback) { listeners[name] = callback; }
    send(json) { sent.push(JSON.parse(json)); }
  };
  for (const asset of browserAssets()) dom.window.eval(asset.source);
  return { dom, sent, receive: message => listeners.message({ data: JSON.stringify(message) }) };
}

test('composing Enter submits nothing from text or password inputs; ordinary Enter submits each', t => {
  const { dom, receive, sent } = fixture(t);
  const { document, KeyboardEvent } = dom.window;
  receive({ type: 'hello', pages: [{ address: 'search' }] });
  receive({ type: 'render', page: 'search', generation: 1,
    bindings: { query: ['submit'], secret: ['submit'] }, submissions: { query: ['query'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Search' }, children: [
      { type: 'text_input', cid: 'query', props: { value: '' } },
      { type: 'password_input', cid: 'secret', props: {} }
    ] } });
  const enter = (cid, isComposing) => {
    const control = document.querySelector(`[data-cid="${cid}"] input`);
    control.focus();
    const before = sent.length;
    control.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', isComposing, bubbles: true, cancelable: true }));
    return sent.slice(before).filter(message => message.type === 'event').map(message => [message.event, message.cid]);
  };
  document.querySelector('[data-cid="query"] input').value = 'fixture-query';
  assert.deepEqual({
    textComposing: enter('query', true),
    passwordComposing: enter('secret', true),
    text: enter('query', false),
    password: enter('secret', false)
  }, {
    textComposing: [], passwordComposing: [],
    text: [['submit', 'query']], password: [['submit', 'secret']]
  });
  assert.deepEqual(sent.filter(message => message.cid === 'query').at(-1).submission, ['fixture-query']);
});
