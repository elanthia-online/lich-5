// A renderer that throws must not leave the old DOM live against the new registries:
// the page goes inert, sends nothing, reports the failure and recovers on the next render.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { fixture } = require('./webui_renderer_fixture.cjs');

function frame(generation, label) {
  return { type: 'render', page: 'main', generation, resume: `resume-${generation}`,
    bindings: { save: ['activate'] }, submissions: { save: ['name'] },
    tree: { type: 'page', cid: 'root', props: { title: label }, children: [
      { type: 'text_input', cid: 'name', props: { value: label } },
      { type: 'button', cid: 'save', props: { label: 'Save' } }
    ] } };
}

function mountedButton(f) {
  const root = f.elements.pages.children[0];
  return { root, button: root.querySelector('[data-cid="save"]') };
}

test('a renderer throw fails closed: old DOM inert, no null submission, failure reported, next render recovers', () => {
  const f = fixture(null);
  f.receive({ type: 'hello', pages: [{ address: 'main' }] });
  f.receive(frame(1, 'First'));
  const before = mountedButton(f);
  assert.ok(before.button, 'first render mounts the save button');

  const { renderers } = f.window.LichWebUI;
  const working = renderers.text_input;
  renderers.text_input = () => { throw new Error('renderer fixture failure'); };
  f.sent.length = 0;
  assert.doesNotThrow(() => f.receive(frame(2, 'Second')));

  const after = mountedButton(f);
  assert.equal(f.elements.pages.children.length, 1);
  assert.equal(after.root, before.root, 'the previous DOM stays mounted');
  assert.equal(f.elements.notifications.children.length, 1);
  assert.match(f.elements.notifications.children[0].textContent, /renderer fixture failure/);

  // The old DOM can no longer match the accepted registries, so it is inert and a
  // click sends nothing; before the fix it sent generation 2 with a null submission.
  assert.equal(after.root.inert, true);
  after.button.click();
  assert.deepEqual(f.sent.filter(message => message.type === 'event'), []);

  // A later good render installs normally and the page is fully usable again.
  renderers.text_input = working;
  f.receive(frame(3, 'Third'));
  const later = mountedButton(f);
  assert.notEqual(later.root, before.root);
  f.sent.length = 0;
  later.button.click();
  const retried = f.sent.filter(message => message.type === 'event');
  assert.equal(retried[0].generation, 3);
  assert.deepEqual(retried[0].submission, ['Third']);
});

test('a first render that throws mounts nothing and a later render still installs', () => {
  const f = fixture(null);
  f.receive({ type: 'hello', pages: [{ address: 'main' }] });
  const { renderers } = f.window.LichWebUI;
  const working = renderers.text_input;
  renderers.text_input = () => { throw new Error('first render failure'); };
  assert.doesNotThrow(() => f.receive(frame(1, 'First')));
  assert.equal(f.elements.pages.children.length, 0);
  assert.equal(f.elements.notifications.children.length, 1);
  renderers.text_input = working;
  f.receive(frame(2, 'Second'));
  assert.equal(f.elements.pages.children.length, 1);
  assert.ok(mountedButton(f).button);
});
