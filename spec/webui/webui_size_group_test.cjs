const { test } = require('node:test');
const assert = require('node:assert/strict');
const { measuredDomFixture: fixture } = require('./webui_measured_dom_fixture.cjs');

function render(f, address, generation, members) {
  f.receive({ type: 'render', page: address, generation,
    tree: { type: 'page', cid: `${address}-root`, props: { title: address }, children: members.map(([cid, groups]) => ({
      type: 'checkbox', cid, props: { label: cid, checked: false, width_groups: groups }
    })) } });
}

test('shared and overlapping widths stay page-local, shrink and clean up across renders', t => {
  const f = fixture(); t.after(() => f.dom.window.close());
  f.receive({ type: 'hello', pages: [{ address: 'first' }, { address: 'second' }] });
  [['a', 60], ['bridge', 40], ['b', 120], ['separate', 30], ['other-page', 300]].forEach(([key, value]) => f.widths.set(key, value));
  render(f, 'first', 1, [['a', ['one']], ['bridge', ['one', 'two']], ['b', ['two']], ['separate', ['separate']]]);
  render(f, 'second', 1, [['other-page', ['one']]]);
  f.frame();
  for (const cid of ['a', 'bridge', 'b']) assert.equal(f.element(cid).style.minWidth, '120px');
  assert.equal(f.element('separate').style.minWidth, '30px');
  assert.equal(f.element('other-page').style.minWidth, '300px');
  assert.equal(f.dom.window.document.querySelectorAll('[aria-hidden="true"]').length, 0, 'measurement probes are removed');
  const previousObserver = f.observers[0];
  render(f, 'first', 2, [['a', ['one']], ['bridge', ['one']], ['b', []]]);
  f.frame();
  assert.equal(previousObserver.disconnected, true);
  assert.equal(f.element('a').style.minWidth, '60px');
  assert.equal(f.element('bridge').style.minWidth, '60px');
  assert.equal(f.element('b').style.minWidth, '');
  f.widths.set('a', 75);
  f.observers.at(-1).callback();
  f.frame();
  assert.equal(f.element('bridge').style.minWidth, '75px');
});

test('measuring grouped radio controls preserves the live selection and input drafts', t => {
  const f = fixture(); t.after(() => f.dom.window.close());
  f.receive({ type: 'hello', pages: [{ address: 'radio' }] });
  f.receive({ type: 'render', page: 'radio', generation: 1, tree: { type: 'page', cid: 'root', props: { title: 'Radio' }, children: [
    { type: 'radio_option', cid: 'choice', props: { label: 'Chosen', group: 'choice-group', checked: true, width_groups: ['one'] } },
    { type: 'text_input', cid: 'draft', props: { value: 'Before', width_groups: ['one'] } }
  ] } });
  f.widths.set('choice', 80); f.widths.set('draft', 150);
  const radio = f.element('choice').querySelector('input');
  const draft = f.element('draft').querySelector('input');
  draft.value = 'Unsaved'; draft.focus();
  const before = f.sent.length;
  f.frame();
  assert.equal(radio.checked, true);
  assert.equal(draft.value, 'Unsaved');
  assert.equal(f.dom.window.document.activeElement, draft);
  assert.equal(f.sent.length, before, 'layout does not emit input events');
});

test('fixed number steppers preserve their only valid value', t => {
  const f = fixture(); t.after(() => f.dom.window.close());
  f.receive({ type: 'hello', pages: [{ address: 'fixed' }] });
  f.receive({ type: 'render', page: 'fixed', generation: 1, bindings: { porter: ['change'] }, tree: {
    type: 'page', cid: 'root', props: { title: 'Fixed' }, children: [{ type: 'number_input', cid: 'porter', props: {
      value: 0, min: 0, max: 0, step: 1, digits: 0, snap_to_step: false, stepper_buttons: true
    } }]
  } });
  const control = f.element('porter').querySelector('input');
  control.dispatchEvent(new f.dom.window.KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true }));
  assert.equal(control.value, '0');
  control.dispatchEvent(new f.dom.window.KeyboardEvent('keydown', { key: 'PageDown', bubbles: true }));
  assert.equal(control.value, '0');
});
