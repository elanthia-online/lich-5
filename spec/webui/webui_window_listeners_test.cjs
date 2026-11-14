// Window listener bookkeeping and shipped render-lifetime regression checks.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { fixture } = require('./webui_renderer_fixture.cjs');

test('window resize dispatch retains registration order and removes only the named callback', () => {
  const f = fixture(null);
  const calls = [], event = { type: 'resize' };
  const first = received => { assert.equal(received, event); calls.push('first'); };
  const temporary = received => { assert.equal(received, event); calls.push('temporary'); };
  const last = received => { assert.equal(received, event); calls.push('last'); };
  f.window.addEventListener('resize', first);
  f.window.addEventListener('resize', temporary);
  f.window.addEventListener('resize', last);
  f.windowEvents.resize(event);
  assert.deepEqual(calls, ['first', 'temporary', 'last']);

  calls.length = 0;
  f.window.removeEventListener('resize', temporary);
  f.window.removeEventListener('resize', () => {});
  f.windowEvents.resize(event);
  assert.deepEqual(calls, ['first', 'last']);

  calls.length = 0;
  f.window.removeEventListener('resize', first);
  f.window.removeEventListener('resize', last);
  f.windowEvents.resize(event);
  assert.deepEqual(calls, []);
});

function frame(generation, stepper = false) {
  return { type: 'render', page: 'main', generation, bindings: {}, submissions: {},
    tree: { type: 'page', cid: 'root', props: { title: `Frame ${generation}` }, children: stepper ? [
      { type: 'number_input', cid: 'count', props: { value: 1, min: 0, max: 10, step: 1, stepper_buttons: true } }
    ] : [] } };
}

test('disposing a stepper blur listener preserves lifetime pointer release for later renders', () => {
  const f = fixture(null);
  const timers = [];
  f.window.setTimeout = callback => { timers.push(callback); return timers.length; };
  f.receive({ type: 'hello', pages: [{ address: 'main' }] });
  f.receive(frame(1, true));
  assert.ok(f.elements.pages.children[0].querySelector('[data-cid="count"]'), 'stepper renders its temporary blur listener');
  f.receive(frame(2)); // Shipped input disposal removes the stepper's blur callback.
  const root = () => f.elements.pages.children[0];
  const held = root();
  held.listeners.pointerdown({});
  f.receive(frame(3));
  assert.equal(root(), held, 'pointer hold defers the incoming render');

  assert.equal(typeof f.windowEvents.blur, 'function');
  f.windowEvents.blur({ type: 'blur' });
  timers.splice(0).forEach(callback => callback());
  assert.notEqual(root(), held, 'the surviving lifetime listener releases the deferred render');
  assert.equal(f.document.title, 'Frame 3');
  assert.equal(f.elements.notifications.children.length, 0);
});
