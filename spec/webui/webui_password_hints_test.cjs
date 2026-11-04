// Secret inputs tell the browser not to save, complete, correct or spell-check them.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { fixture } = require('./webui_renderer_fixture.cjs');

const hints = { autocomplete: 'off', spellcheck: 'false', autocapitalize: 'off', autocorrect: 'off' };

function render(children) {
  const f = fixture(null);
  f.receive({ type: 'hello', pages: [{ address: 'vault' }] });
  f.receive({ type: 'render', page: 'vault', generation: 1, bindings: {}, submissions: {},
    tree: { type: 'page', cid: 'root', props: { title: 'Vault' }, children } });
  return f.elements.pages.children[0];
}

function control(root, cid) {
  const wrapper = root.querySelector(`[data-cid="${cid}"]`);
  return wrapper.tagName === 'input' || wrapper.tagName === 'textarea' ? wrapper : wrapper.children.find(child => child.tagName === 'input' || child.tagName === 'textarea');
}

test('password and sensitive text inputs carry the no-save, no-correction hints', () => {
  const root = render([
    { type: 'password_input', cid: 'secret', props: { value: '' } },
    { type: 'text_input', cid: 'token', props: { value: '', sensitive: true } },
    { type: 'textarea', cid: 'notes', props: { value: '', sensitive: true } },
    { type: 'text_input', cid: 'account', props: { value: 'plain' } }
  ]);
  for (const cid of ['secret', 'token', 'notes']) {
    assert.deepEqual(control(root, cid).attributes, hints, cid);
  }
  assert.deepEqual(control(root, 'account').attributes, {}, 'ordinary text keeps browser defaults');
});

test('the Show/Hide toggle flips the type and keeps the hints', () => {
  const root = render([{ type: 'password_input', cid: 'secret', props: { value: '', revealable: true } }]);
  const wrapper = root.querySelector('[data-cid="secret"]');
  const secret = control(root, 'secret');
  const toggle = wrapper.children.find(child => child.tagName === 'button');
  assert.equal(secret.type, 'password');
  toggle.click();
  assert.equal(secret.type, 'text');
  assert.deepEqual(secret.attributes, hints);
  toggle.click();
  assert.equal(secret.type, 'password');
  assert.deepEqual(secret.attributes, hints);
});
