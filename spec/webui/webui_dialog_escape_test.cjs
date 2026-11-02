// Dialog Escape regressions for the shipped renderer: a server-owned dialog is never
// dismissed natively however many times Escape is pressed, and only a declared
// cancel_button answers an Escape.
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
  // jsdom lacks modal dialogs; showModal stands in by setting the reflected open state.
  dom.window.HTMLDialogElement.prototype.showModal = function () { this.setAttribute('open', ''); };
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

const render = (generation, declared, withDialog = true) => ({ type: 'render', page: 'confirm-page', generation,
  bindings: { confirm: ['response'] },
  tree: { type: 'page', cid: 'root', props: { title: 'Accounts' }, children: withDialog ? [
    { type: 'dialog', cid: 'confirm', props: { title: 'Delete account?', body: 'This cannot be undone.',
      buttons: [{ id: 'keep', label: 'Keep' }, { id: 'delete', label: 'Delete' }],
      ...(declared ? { cancel_button: 'keep' } : {}) } }
  ] : [] } });

async function open(t, declared) {
  const env = fixture(t);
  env.receive({ type: 'hello', pages: [{ address: 'confirm-page' }] });
  env.receive(render(1, declared));
  await new Promise(resolve => setImmediate(resolve));
  const dialog = env.dom.window.document.querySelector('dialog[data-cid="confirm"]');
  assert.equal(dialog.open, true);
  return { ...env, dialog };
}

// Chrome stops honoring preventDefault on cancel after repeated Escapes: the cancel is
// no longer cancelable and the dialog closes natively. jsdom has no such dismissal, so
// this stands in for it unless the dialog opted out through closedby="none".
function nativeDismissal(dialog) {
  if (dialog.getAttribute('closedby') === 'none') return;
  dialog.dispatchEvent(new dialog.ownerDocument.defaultView.Event('cancel', { cancelable: false }));
  dialog.removeAttribute('open');
  dialog.dispatchEvent(new dialog.ownerDocument.defaultView.Event('close'));
}

const responses = sent => sent.filter(message => message.event === 'response')
  .map(message => [message.cid, message.generation, message.payload]);

test('five consecutive Escapes on a dialog without cancel_button leave it open with no response', async t => {
  const { dom, dialog, sent } = await open(t, false);
  const { document, KeyboardEvent } = dom.window;
  assert.equal(dialog.getAttribute('closedby'), 'none', 'the dialog opts out of native close requests');
  for (let press = 1; press <= 5; press += 1) {
    const escape = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true });
    document.dispatchEvent(escape);
    assert.equal(escape.defaultPrevented, true, `Escape ${press} is swallowed`);
    nativeDismissal(dialog);
    assert.equal(dialog.isConnected && dialog.open, true, `the dialog is still open after Escape ${press}`);
  }
  assert.deepEqual(responses(sent), [], 'an undeclared cancel must not invent a response');
});

test('Escape on a dialog with cancel_button sends that response on every press and keeps the dialog open', async t => {
  const { dom, dialog, sent } = await open(t, true);
  const { document, KeyboardEvent } = dom.window;
  for (let press = 1; press <= 5; press += 1) {
    const escape = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true });
    document.dispatchEvent(escape);
    assert.equal(escape.defaultPrevented, true, `Escape ${press} is consumed`);
    nativeDismissal(dialog);
    assert.equal(dialog.isConnected && dialog.open, true, `the dialog stays until the server renders again (press ${press})`);
    assert.equal(responses(sent).length, press, `Escape ${press} sends exactly one response`);
  }
  assert.deepEqual(responses(sent).at(-1), ['confirm', 1, { button: 'keep' }]);
});

for (const declared of [true, false]) {
  test(`the native cancel event is only prevented on a dialog ${declared ? 'with' : 'without'} cancel_button and never responds`, async t => {
    const { dom, dialog, sent } = await open(t, declared);
    const cancel = new dom.window.Event('cancel', { cancelable: true });
    dialog.dispatchEvent(cancel);
    assert.equal(cancel.defaultPrevented, true, 'native Escape dismissal must be prevented');
    assert.equal(dialog.isConnected && dialog.open, true);
    assert.deepEqual(responses(sent), [], 'the response comes from the Escape keydown, not from cancel');
  });
}

test('a composing Escape is left to the input method and sends nothing', async t => {
  const { dom, sent } = await open(t, true);
  const escape = new dom.window.KeyboardEvent('keydown', { key: 'Escape', isComposing: true, bubbles: true, cancelable: true });
  dom.window.document.dispatchEvent(escape);
  assert.equal(escape.defaultPrevented, false);
  assert.deepEqual(responses(sent), []);
});

test('a native close of the delivered dialog re-opens it, whatever closed it', async t => {
  const { dom, dialog } = await open(t, false);
  dialog.removeAttribute('open');
  dialog.dispatchEvent(new dom.window.Event('close'));
  assert.equal(dialog.isConnected && dialog.open, true, 'no empty modal is left behind');
});

test('a close of a dialog the server has replaced does not re-open it', async t => {
  const { dom, dialog, receive } = await open(t, false);
  receive(render(2, false, false));
  const stale = dialog;
  assert.equal(dom.window.document.querySelector('dialog'), null, 'the next render removed the dialog');
  stale.removeAttribute('open');
  stale.dispatchEvent(new dom.window.Event('close'));
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(stale.open, false, 'only the delivered dialog is re-opened');
  assert.equal(dom.window.document.querySelector('dialog'), null);
});
