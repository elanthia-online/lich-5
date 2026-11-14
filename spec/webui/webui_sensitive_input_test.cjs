// Sensitive entry regressions for the shipped renderer: nonterminal events never
// carry a secret, and only an uncomposed Enter submits the declared scope.
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

const events = sent => sent.filter(message => message.type === 'event');

test('sensitive text blur and change emit no value while terminal submit keeps its declared scope', t => {
  const { dom, receive, sent } = fixture(t);
  const { document, Event, KeyboardEvent } = dom.window;
  receive({ type: 'hello', pages: [{ address: 'vault' }] });
  receive({ type: 'render', page: 'vault', generation: 1,
    bindings: { token: ['change', 'blur', 'submit'] }, submissions: { token: ['account', 'token'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Vault' }, children: [
      { type: 'text_input', cid: 'account', props: { value: 'fixture-account' } },
      { type: 'text_input', cid: 'token', props: { value: '', sensitive: true, change_mode: 'input' } }
    ] } });
  const token = document.querySelector('[data-cid="token"] input');
  token.value = 'fixture-secret';
  token.dispatchEvent(new Event('input'));
  token.dispatchEvent(new Event('change'));
  token.dispatchEvent(new Event('blur'));
  assert.deepEqual(events(sent), [], 'sensitive change and blur must not emit value-bearing messages');
  assert.equal(JSON.stringify(sent).includes('fixture-secret'), false);
  token.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
  assert.equal(events(sent).length, 1);
  const submit = events(sent)[0];
  assert.equal(submit.event, 'submit');
  assert.equal(submit.cid, 'token');
  assert.equal(submit.generation, 1);
  assert.deepEqual(submit.payload, {});
  assert.deepEqual(submit.submission, ['fixture-account', 'fixture-secret']);
});

test('password Enter submits its declared scope and composing Enter submits nothing', t => {
  const { dom, receive, sent } = fixture(t);
  const { document, KeyboardEvent } = dom.window;
  receive({ type: 'hello', pages: [{ address: 'login' }] });
  receive({ type: 'render', page: 'login', generation: 1,
    bindings: { password: ['submit'] }, submissions: { password: ['user', 'password'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Login' }, children: [
      { type: 'text_input', cid: 'user', props: { value: 'fixture-user' } },
      { type: 'password_input', cid: 'password', props: {} }
    ] } });
  const password = document.querySelector('[data-cid="password"] input');
  password.focus();
  password.value = 'fixture-pass';
  password.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', isComposing: true, bubbles: true, cancelable: true }));
  assert.deepEqual(events(sent), [], 'Enter that commits an IME composition must not submit');
  password.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
  assert.equal(events(sent).length, 1);
  const submit = events(sent)[0];
  assert.equal(submit.event, 'submit');
  assert.equal(submit.cid, 'password');
  assert.deepEqual(submit.payload, {});
  assert.deepEqual(submit.submission, ['fixture-user', 'fixture-pass']);
});
