// Dialog Escape regressions for the shipped renderer: the native cancel never
// dismisses a server-owned dialog, and only a declared cancel action responds.
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

for (const declared of [true, false]) {
  test(`Escape is prevented on a dialog ${declared ? 'with' : 'without'} cancel_button and responds only when declared`, async t => {
    const { dom, receive, sent } = fixture(t);
    const { document, Event } = dom.window;
    receive({ type: 'hello', pages: [{ address: 'confirm-page' }] });
    receive({ type: 'render', page: 'confirm-page', generation: 1, bindings: { confirm: ['response'] },
      tree: { type: 'page', cid: 'root', props: { title: 'Accounts' }, children: [
        { type: 'dialog', cid: 'confirm', props: { title: 'Delete account?', body: 'This cannot be undone.',
          buttons: [{ id: 'keep', label: 'Keep' }, { id: 'delete', label: 'Delete' }],
          ...(declared ? { cancel_button: 'keep' } : {}) } }
      ] } });
    await new Promise(resolve => setImmediate(resolve));
    const dialog = document.querySelector('dialog[data-cid="confirm"]');
    assert.equal(dialog.open, true);
    const cancel = new Event('cancel', { cancelable: true });
    dialog.dispatchEvent(cancel);
    assert.equal(cancel.defaultPrevented, true, 'native Escape dismissal must be prevented');
    assert.equal(dialog.isConnected && dialog.open, true, 'the dialog stays until the server renders again');
    const responses = sent.filter(message => message.event === 'response');
    if (declared) {
      assert.deepEqual(responses.map(message => [message.cid, message.generation, message.payload]),
        [['confirm', 1, { button: 'keep' }]]);
    } else assert.deepEqual(responses, [], 'an undeclared cancel must not invent a response');
  });
}
