// A renderer failure is reported to the server as one bounded client_error message, so
// the failure is recorded outside the page; the report never carries page content.
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

function failing(f, error, run) {
  const { renderers } = f.window.LichWebUI;
  const working = renderers.text_input;
  renderers.text_input = () => { throw error; };
  try { run(); } finally { renderers.text_input = working; }
}

function reports(f) {
  return f.sent.filter(message => message.type === 'client_error');
}

test('a renderer throw sends one client_error naming the page, generation and error', () => {
  const f = fixture(null);
  f.receive({ type: 'hello', pages: [{ address: 'main' }] });
  f.receive(frame(1, 'First'));
  f.sent.length = 0;
  failing(f, new Error('renderer fixture failure'), () => f.receive(frame(2, 'draft-canary')));

  const sent = reports(f);
  assert.equal(sent.length, 1);
  assert.deepEqual(Object.keys(sent[0]).sort(), ['generation', 'message', 'page', 'stack', 'type']);
  assert.equal(sent[0].page, 'main');
  assert.equal(sent[0].generation, 2);
  assert.equal(sent[0].message, 'renderer fixture failure');
  assert.match(sent[0].stack, /renderer fixture failure/);
  assert.doesNotMatch(JSON.stringify(sent[0]), /draft-canary|resume-2/);
  assert.equal(f.elements.notifications.children.length, 1, 'the toast is still shown');
});

test('the report is bounded and drops origins from the stack', () => {
  const f = fixture(null);
  f.receive({ type: 'hello', pages: [{ address: 'main' }] });
  const error = new Error('m'.repeat(5000));
  error.stack = `Error: boom\n    at render (http://127.0.0.1:4321/assets/app.js?v=1:10:5)\n${'    at frame (x.js:1:1)\n'.repeat(500)}`;
  failing(f, error, () => f.receive(frame(1, 'First')));

  const [sent] = reports(f);
  assert.equal(sent.message.length, 160);
  assert.ok(sent.stack.length <= 600);
  assert.doesNotMatch(sent.stack, /127\.0\.0\.1|4321/);
  assert.match(sent.stack, /\/assets\/app\.js/);
});

test('a non-Error throw still reports a message and omits an empty stack', () => {
  const f = fixture(null);
  f.receive({ type: 'hello', pages: [{ address: 'main' }] });
  failing(f, null, () => assert.doesNotThrow(() => f.receive(frame(1, 'First'))));

  const [sent] = reports(f);
  assert.equal(sent.message, 'renderer error');
  assert.equal(Object.hasOwn(sent, 'stack'), false);
});

test('a failed report send does not escape the render path', () => {
  const f = fixture(null);
  f.receive({ type: 'hello', pages: [{ address: 'main' }] });
  f.receive(frame(1, 'First'));
  // The fixture socket records through this array, so a throwing push is a throwing send.
  f.sent.push = () => { throw new Error('socket closed'); };
  failing(f, new Error('renderer fixture failure'), () => assert.doesNotThrow(() => f.receive(frame(2, 'Second'))));
  assert.equal(f.elements.notifications.children.length, 1);
});
