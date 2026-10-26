const { test } = require('node:test');
const assert = require('node:assert/strict');
const { measuredDomFixture } = require('./webui_measured_dom_fixture.cjs');
const { sampleCanvasScroll } = require('./scenarios/canvas_sampling.cjs');

// Real renderer restoration with explicit frame/task queues, independent of Chrome timing.
function canvasFixture(t) {
  const { dom, frame } = measuredDomFixture();
  t.after(() => dom.window.close());
  const tasks = [], channels = [];
  dom.window.MessageChannel = class {
    constructor() {
      this.port1 = { close() { this.closed = true; } };
      this.port2 = { close() { this.closed = true; },
        postMessage: () => tasks.push(() => this.port1.onmessage()) };
      channels.push(this);
    }
  };
  const page = { controls: new Map(), bindings: {}, submissions: {} };
  const paint = (x, y, revision) => {
    const element = dom.window.LichWebUI.render(page, { type: 'scroll', cid: 'canvas-scroll',
      props: { scroll_position_x: x, scroll_position: y, scroll_revision_x: revision, scroll_revision: revision },
      children: [] });
    dom.window.document.getElementById('pages').replaceChildren(element);
    return element;
  };
  // Match Playwright's serialization so the sampler cannot depend on a Node closure.
  const sample = dom.window.eval(`(${sampleCanvasScroll.toString()})`);
  return { frame, paint, sample,
    task: () => tasks.splice(0).forEach(callback => callback()),
    assertClosed: () => channels.forEach(channel => {
      assert.equal(channel.port1.closed, true);
      assert.equal(channel.port2.closed, true);
    }) };
}

for (const [property, expected] of [['scrollLeft', 490], ['scrollTop', 360]]) {
  test(`canvas sampling waits for ${property} restoration queued later in the same frame`, async t => {
    const fixture = canvasFixture(t);
    fixture.paint(400, 300, 1);
    fixture.frame();
    const sampled = fixture.sample(property);
    const replacement = fixture.paint(490, 360, 2);
    assert.equal(replacement[property], 0, 'a new scroller starts unrestored');
    fixture.frame();
    assert.equal(replacement[property], expected, 'the real renderer restores later in this frame');
    fixture.task();
    assert.equal(await sampled, expected);
    fixture.assertClosed();
  });
}

test('canvas sampling discards a scroller retired before the post-frame task', async t => {
  const fixture = canvasFixture(t);
  fixture.paint(400, 300, 1);
  fixture.frame();
  const sampled = fixture.sample('scrollLeft');
  const retired = fixture.paint(490, 360, 2);
  fixture.frame();
  const replacement = fixture.paint(610, 420, 3);
  assert.equal(retired.isConnected, false);
  fixture.task();
  fixture.frame();
  fixture.task();
  assert.equal(await sampled, 610, 'only the connected replacement supplies the result');
  assert.equal(replacement.scrollTop, 420);
  fixture.assertClosed();
});

test('canvas sampling reports a real zero after restoration instead of retaining an earlier offset', async t => {
  const fixture = canvasFixture(t);
  fixture.paint(490, 360, 1);
  fixture.frame();
  const sampled = fixture.sample('scrollLeft');
  const replacement = fixture.paint(0, 0, 2);
  fixture.frame();
  fixture.task();
  assert.equal(await sampled, 0);
  assert.equal(replacement.scrollTop, 0);
  fixture.assertClosed();
});
