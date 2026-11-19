// A renderer failure is reported to the server as one client_error message holding the
// error's class name and script positions only, so the failure is recorded outside the
// page without the error text or any page content.
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

function attached(consoleCalls = null) {
  const f = fixture(null);
  if (consoleCalls) f.window.console = { error: (...args) => consoleCalls.push(args) };
  f.receive({ type: 'hello', pages: [{ address: 'main' }] });
  return f;
}

// Throws from inside a renderer call. A function argument builds the error there, so
// its stack holds the calling renderer script as a real failure does.
function failing(f, error, run) {
  const { renderers } = f.window.LichWebUI;
  const working = renderers.text_input;
  renderers.text_input = () => { throw typeof error === 'function' ? error() : error; };
  try { run(); } finally { renderers.text_input = working; }
}

function reports(f) {
  return f.sent.filter(message => message.type === 'client_error');
}

const POSITION = /^[a-z0-9_]{1,48}\.js:\d{1,7}:\d{1,7}$/;

test('a renderer throw sends one client_error naming the page, generation, class and positions', () => {
  const f = attached();
  f.receive(frame(1, 'First'));
  f.sent.length = 0;
  failing(f, () => new TypeError('draft-canary is undefined'), () => f.receive(frame(2, 'value-canary')));

  const sent = reports(f);
  assert.equal(sent.length, 1);
  assert.deepEqual(Object.keys(sent[0]).sort(), ['error', 'frames', 'generation', 'page', 'type']);
  assert.equal(sent[0].page, 'main');
  assert.equal(sent[0].generation, 2);
  assert.equal(sent[0].error, 'TypeError');
  assert.ok(sent[0].frames.length >= 1 && sent[0].frames.length <= 8);
  sent[0].frames.forEach(position => assert.match(position, POSITION));
  assert.ok(sent[0].frames.some(position => position.startsWith('app.js:')), 'the renderer script is located');
  assert.doesNotMatch(JSON.stringify(sent[0]), /canary|resume-2|undefined/);
  assert.equal(f.elements.notifications.children.length, 1, 'the toast is still shown');
});

test('the error text stays in the local console and never enters the report', () => {
  const calls = [];
  const f = attached(calls);
  const error = new Error('account-canary could not be drawn');
  failing(f, error, () => f.receive(frame(1, 'First')));

  assert.equal(calls.length, 1);
  assert.equal(calls[0][1], error);
  assert.doesNotMatch(JSON.stringify(reports(f)), /canary|drawn/);
});

test('positions come from V8 and WebKit frame lines only, without names, origins or queries', () => {
  const f = attached();
  const error = new RangeError('boom');
  error.stack = [
    'RangeError: boom mentions secret_word.js:1:1 in its text',
    '    at renderTable (http://127.0.0.1:4321/assets/renderers_table.js?v=1:120:14)',
    '    at async Object.install (http://127.0.0.1:4321/assets/app.js:1391:24)',
    'drawCell@http://127.0.0.1:4321/assets/renderers_table.js:88:3',
    '@http://127.0.0.1:4321/assets/app.js:7:9',
    '    at http://127.0.0.1:4321/assets/app.js:5:6',
    '    at native code',
    '    at Upper (http://127.0.0.1:4321/assets/Not-A-Script.js:1:1)'
  ].join('\n');
  failing(f, error, () => f.receive(frame(1, 'First')));

  const [sent] = reports(f);
  assert.equal(sent.error, 'RangeError');
  assert.deepEqual(sent.frames, ['renderers_table.js:120:14', 'app.js:1391:24', 'renderers_table.js:88:3', 'app.js:7:9', 'app.js:5:6']);
});

test('a position inside the error message is never reported', () => {
  const f = attached();
  const error = new Error('image failed for user@cdn/secret_word.js:4242:777\nsecond line at other.js:1:2');
  error.stack = `Error: ${error.message}\n    at render (http://127.0.0.1:4321/assets/app.js:10:5)`;
  failing(f, error, () => f.receive(frame(1, 'First')));

  assert.deepEqual(reports(f)[0].frames, ['app.js:10:5']);
});

test('at most eight positions are sent', () => {
  const f = attached();
  const error = new Error('deep');
  error.stack = `Error: deep\n${'    at step (app.js:1:1)\n'.repeat(500)}`;
  failing(f, error, () => f.receive(frame(1, 'First')));

  assert.equal(reports(f)[0].frames.length, 8);
});

test('supplementary characters across any cut in the message or stack leave a well-formed ASCII frame', () => {
  const f = attached();
  const error = new Error(`${'A'.repeat(159)}\u{1f642} end`);
  error.stack = `${'B'.repeat(599)}\u{1f642} end\n    at render (http://127.0.0.1:4321/assets/app.js:10:5)`;
  failing(f, error, () => f.receive(frame(1, 'First')));

  const [sent] = reports(f);
  const wire = JSON.stringify(sent);
  // The Ruby report spec parses this exact frame.
  assert.equal(wire, '{"type":"client_error","page":"main","generation":1,"error":"Error","frames":["app.js:10:5"]}');
  assert.match(wire, /^[\x20-\x7E]+$/);
  assert.equal(Buffer.from(wire, 'utf8').toString('utf8'), wire);
});

test('an unusable error name or a non-Error throw reports the generic class and no positions', () => {
  for (const thrown of [null, 'plain text canary', Object.assign(new Error('x'), { name: 'bad name canary', stack: '' })]) {
    const f = attached();
    failing(f, thrown, () => assert.doesNotThrow(() => f.receive(frame(1, 'First'))));

    const [sent] = reports(f);
    assert.equal(sent.error, 'Error');
    assert.equal(Object.hasOwn(sent, 'frames'), false);
    assert.doesNotMatch(JSON.stringify(sent), /canary/);
  }
});

test('a failed report send does not escape the render path', () => {
  const f = attached();
  f.receive(frame(1, 'First'));
  // The fixture socket records through this array, so a throwing push is a throwing send.
  f.sent.push = () => { throw new Error('socket closed'); };
  failing(f, new Error('renderer fixture failure'), () => assert.doesNotThrow(() => f.receive(frame(2, 'Second'))));
  assert.equal(f.elements.notifications.children.length, 1);
});
