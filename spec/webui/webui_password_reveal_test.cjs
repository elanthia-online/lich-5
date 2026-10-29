// Password reveal regressions for the shipped renderer: Show exists only for an
// authored revealable password, toggling is local, and neither the revealed state
// nor the plaintext reaches a message or survives a redraw. Wire serialization of
// the authored permission is pinned in spec/lib/webui/viewer_store_boundary_spec.rb.
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

test('Show is offered only when revealable is authored true and reveals locally without leaking the plaintext', t => {
  const { dom, receive, sent } = fixture(t);
  const { document } = dom.window;
  const render = generation => receive({ type: 'render', page: 'login', generation,
    bindings: { save: ['activate'] }, submissions: { save: ['user'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Login' }, children: [
      { type: 'text_input', cid: 'user', props: { value: 'fixture-user' } },
      { type: 'password_input', cid: 'secret', props: { revealable: true } },
      { type: 'password_input', cid: 'pin', props: { revealable: false } },
      { type: 'password_input', cid: 'code', props: {} },
      { type: 'button', cid: 'save', props: { label: 'Save' } }
    ] } });
  const reveal = cid => document.querySelector(`[data-cid="${cid}"] button`);
  const secret = () => document.querySelector('[data-cid="secret"] input');
  const state = () => [secret().type, reveal('secret').textContent];
  receive({ type: 'hello', pages: [{ address: 'login' }] });
  render(1);
  const observed = { offered: ['secret', 'pin', 'code'].map(cid => reveal(cid)?.textContent ?? null) };
  secret().value = 'fixture-pass';
  const beforeToggle = sent.length;
  reveal('secret').click();
  observed.revealed = state();
  reveal('secret').click();
  observed.hidden = state();
  reveal('secret').click();
  observed.revealedAgain = state();
  observed.toggleSent = sent.slice(beforeToggle);
  document.querySelector('button[data-cid="save"]').click();
  observed.save = [sent.at(-1).event, sent.at(-1).submission];
  // A redraw rebuilds the control masked: the revealed state is never retained.
  render(2);
  observed.afterRedraw = state();
  const wire = JSON.stringify(sent);
  observed.leaked = ['fixture-pass', 'reveal', 'Hide'].filter(text => wire.includes(text));
  assert.deepEqual(observed, {
    offered: ['Show', null, null],
    revealed: ['text', 'Hide'], hidden: ['password', 'Show'], revealedAgain: ['text', 'Hide'],
    toggleSent: [],
    save: ['activate', ['fixture-user']],
    afterRedraw: ['password', 'Show'],
    leaked: []
  });
});
