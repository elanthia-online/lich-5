// Accelerator regressions for the shipped renderer: focused controls keep their
// own keys, and shortcuts never activate unavailable or modal-blocked targets.
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
  // jsdom performs no layout and lacks inert and modal dialogs. Stand in for the
  // browser contract: a [hidden] subtree has no boxes, inert reflects its
  // attribute, and showModal sets the reflected open state.
  HTMLElement.prototype.getClientRects = function () { return this.closest('[hidden]') ? [] : [{ width: 80, height: 24 }]; };
  Object.defineProperty(HTMLElement.prototype, 'inert', {
    configurable: true,
    get() { return this.hasAttribute('inert'); },
    set(value) { this.toggleAttribute('inert', value); }
  });
  HTMLDialogElement.prototype.showModal = function () { this.setAttribute('open', ''); };
  const sent = [];
  const listeners = {};
  dom.window.WebSocket = class {
    static OPEN = 1;
    readyState = 1;
    addEventListener(name, callback) { listeners[name] = callback; }
    send(json) { sent.push(JSON.parse(json)); }
  };
  for (const asset of browserAssets()) dom.window.eval(asset.source);
  const press = (target, key, init = {}) => {
    target.focus();
    const event = new dom.window.KeyboardEvent('keydown', { key, bubbles: true, cancelable: true, ...init });
    target.dispatchEvent(event);
    return event;
  };
  const activations = () => sent.filter(message => message.event === 'activate').map(message => message.cid);
  return { dom, sent, press, activations, receive: message => listeners.message({ data: JSON.stringify(message) }) };
}

const button = (cid, props = {}) => ({ type: 'button', cid, props: { label: cid, ...props } });

// 1835:RC1 and 1839:RC1 share these focus cases. Each case records its own
// activations so a failure names every case that regressed.
test('bare keys stay with focused entries, buttons and modal Cancel while modified shortcuts and entry Enter still work', async t => {
  const { dom, receive, sent, press, activations } = fixture(t);
  const { document } = dom.window;
  const during = action => { const before = activations().length; action(); return activations().slice(before); };
  receive({ type: 'hello', pages: [{ address: 'login' }] });
  receive({ type: 'render', page: 'login', generation: 1,
    bindings: { connect: ['activate'], disconnect: ['activate'], password: ['submit'] },
    submissions: { password: ['user', 'password'] },
    facilities: { accelerators: [
      { keys: 'Enter', target: 'connect', event: 'activate' },
      { keys: 'd', target: 'disconnect', event: 'activate' },
      { keys: 'ctrl+d', target: 'disconnect', event: 'activate' }
    ] },
    tree: { type: 'page', cid: 'root', props: { title: 'Login' }, children: [
      { type: 'text_input', cid: 'user', props: { value: '' } },
      { type: 'password_input', cid: 'password', props: {} },
      button('connect'), button('disconnect')
    ] } });
  const user = document.querySelector('[data-cid="user"] input');
  const password = document.querySelector('[data-cid="password"] input');
  const disconnect = document.querySelector('button[data-cid="disconnect"]');
  password.value = 'fixture-pass';
  let native, shortcut;
  const observed = {
    userBareKey: during(() => press(user, 'd')),
    passwordBareKey: during(() => press(password, 'd')),
    disconnectEnter: during(() => { native = press(disconnect, 'Enter'); }),
    passwordEnterSubmit: during(() => press(password, 'Enter')),
    userEnter: during(() => press(user, 'Enter')),
    userModifiedShortcut: during(() => { shortcut = press(user, 'd', { ctrlKey: true }); })
  };
  observed.disconnectEnterNativeKept = !native.defaultPrevented;
  observed.shortcutPrevented = shortcut.defaultPrevented;
  observed.submissions = sent.filter(message => message.event === 'submit').map(message => message.submission);

  receive({ type: 'pages', pages: [{ address: 'login' }, { address: 'confirm' }] });
  receive({ type: 'render', page: 'confirm', generation: 1,
    bindings: { dialog: ['response'], 'delete-now': ['activate'] },
    facilities: { accelerators: [{ keys: 'Enter', target: 'delete-now', event: 'activate' }] },
    tree: { type: 'page', cid: 'root', props: { title: 'Confirm' }, children: [
      { type: 'dialog', cid: 'dialog', props: { title: 'Delete account?', cancel_button: 'cancel',
        buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'delete', label: 'Delete' }] },
      children: [button('delete-now')] }
    ] } });
  await new Promise(resolve => setImmediate(resolve));
  const cancel = [...document.querySelectorAll('dialog[data-cid="dialog"] .dialog-actions button')]
    .find(element => element.textContent === 'Cancel');
  observed.modalCancelEnter = during(() => press(cancel, 'Enter'));
  observed.modalCancelUnregisteredModified = during(() => press(cancel, 'Enter', { ctrlKey: true }));
  assert.deepEqual(observed, {
    userBareKey: [], passwordBareKey: [], disconnectEnter: [],
    passwordEnterSubmit: [], userEnter: ['connect'], userModifiedShortcut: ['disconnect'],
    disconnectEnterNativeKept: true, shortcutPrevented: true, submissions: [['', 'fixture-pass']],
    modalCancelEnter: [], modalCancelUnregisteredModified: []
  });
});

test('accelerators skip hidden actions, inactive tabs, disabled controls and pages behind a modal', async t => {
  const { dom, receive, press, activations } = fixture(t);
  const { document } = dom.window;
  const shortcut = digit => { const before = activations().length; press(document.body, digit, { ctrlKey: true }); return activations().slice(before); };
  receive({ type: 'hello', pages: [{ address: 'main' }] });
  const targets = ['hidden-action', 'tab-two', 'locked-action', 'disabled-action', 'visible'];
  receive({ type: 'render', page: 'main', generation: 1,
    bindings: Object.fromEntries([...targets, 'tab-one'].map(cid => [cid, ['activate']])),
    facilities: { accelerators: targets.map((target, index) => ({ keys: `ctrl+${index + 1}`, target, event: 'activate' })) },
    tree: { type: 'page', cid: 'root', props: { title: 'Main' }, children: [
      button('hidden-action', { hidden: true }),
      { type: 'tabs', cid: 'tabs', props: { names: ['One', 'Two'], selected: 0 }, children: [button('tab-one'), button('tab-two')] },
      { type: 'stack', cid: 'locked', props: { disabled: true }, children: [button('locked-action')] },
      button('disabled-action', { disabled: true }),
      button('visible')
    ] } });
  const observed = {
    hiddenAction: shortcut('1'), inactiveTab: shortcut('2'), disabledContainer: shortcut('3'),
    disabledControl: shortcut('4'), visible: shortcut('5')
  };
  receive({ type: 'pages', pages: [{ address: 'main' }, { address: 'modal' }] });
  receive({ type: 'render', page: 'modal', generation: 1, bindings: { ok: ['activate'] },
    facilities: { accelerators: [{ keys: 'ctrl+6', target: 'ok', event: 'activate' }] },
    tree: { type: 'page', cid: 'root', props: { title: 'Modal' }, children: [
      { type: 'dialog', cid: 'notice', props: { title: 'Notice', buttons: [{ id: 'close', label: 'Close' }] }, children: [button('ok')] }
    ] } });
  await new Promise(resolve => setImmediate(resolve));
  assert.ok(document.querySelector('dialog[open]'));
  observed.behindModal = shortcut('5');
  observed.insideModal = shortcut('6');
  assert.deepEqual(observed, {
    hiddenAction: [], inactiveTab: [], disabledContainer: [], disabledControl: [], visible: ['visible'],
    behindModal: [], insideModal: ['ok']
  });
});
