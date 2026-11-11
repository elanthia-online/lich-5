// Application admission/replay checks with supplied selector outcomes. These
// deterministic doubles do not establish which keys open a native browser popup.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { fixture } = require('./webui_renderer_fixture.cjs');

function frame(generation) {
  return { type: 'render', page: 'main', generation, bindings: {}, submissions: {},
    tree: { type: 'page', cid: 'root', props: { title: `Frame ${generation}` }, children: [
      { type: 'select', cid: 'choice', props: { value: 'last', options: [
        { value: 'first', label: 'First' }, { value: 'last', label: 'Last' }
      ] } }
    ] } };
}

function mounted() {
  const f = fixture(null);
  f.document.querySelectorAll = () => []; // These frames contain no dialogs.
  const timers = [];
  f.window.setTimeout = callback => { timers.push(callback); return timers.length; };
  f.receive({ type: 'hello', pages: [{ address: 'main' }] });
  f.receive(frame(1));
  const root = () => f.elements.pages.children[0];
  const original = root();
  const select = original.querySelector('[data-cid="choice"]').children.find(child => child.tagName === 'select');
  select.tagName = 'SELECT';
  // The fixture has no selector engine or native popup; each test supplies only
  // the :open outcome and the select target used by the document listeners.
  select.closest = selector => selector.split(',').includes('select') ? select : null;
  const event = (name, properties = {}) => f.documentEvents[name]?.({ target: select,
    key: 'ArrowDown', preventDefault() { this.defaultPrevented = true; }, ...properties });
  return { f, root, original, select, event,
    flush: () => { timers.splice(0).forEach(callback => callback()); } };
}

for (const key of ['ArrowUp', 'ArrowDown']) {
  for (const modifier of [null, 'altKey', 'shiftKey', 'ctrlKey', 'metaKey']) {
    test(`${modifier || 'plain'} ${key} holds the latest render while :open reports true`, () => {
      const m = mounted();
      m.select.matches = selector => selector === ':open';
      m.event('keydown', { key, ...(modifier && { [modifier]: true }) });
      m.f.receive(frame(2));
      m.f.receive(frame(3));
      assert.equal(m.root(), m.original);
      m.event('keyup', { key });
      m.flush();
      assert.equal(m.root(), m.original, 'an open popup keeps its select mounted');
      m.select.matches = () => false;
      m.event('keyup', { key });
      m.flush();
      assert.notEqual(m.root(), m.original, 'closed popup releases the retained render');
      assert.equal(m.root().dataset.pageAddress, 'main');
      assert.equal(m.f.elements.notifications.children.length, 0);
      assert.equal(m.f.document.title, 'Frame 3');
    });
  }
}

for (const key of [' ', 'F4', 'ArrowUp', 'ArrowDown']) {
  test(`${JSON.stringify(key)} without a popup releases at keyup even without change`, () => {
    const m = mounted();
    m.select.matches = () => false;
    m.event('keydown', { key });
    m.f.receive(frame(2));
    assert.equal(m.root(), m.original);
    m.event('keyup', { key });
    m.flush();
    assert.notEqual(m.root(), m.original);
    assert.equal(m.f.document.title, 'Frame 2');
  });
}

for (const release of ['change', 'focusout', 'Escape']) {
  test(`unsupported :open retains the hold until ${release}`, () => {
    const m = mounted();
    m.select.matches = selector => {
      if (selector === ':open') throw new SyntaxError('unsupported selector');
      return false;
    };
    m.event('keydown', { shiftKey: true });
    m.f.receive(frame(2));
    assert.doesNotThrow(() => m.event('keyup'));
    m.flush();
    assert.equal(m.root(), m.original);
    m.event(release === 'Escape' ? 'keydown' : release, { key: release });
    m.flush();
    assert.notEqual(m.root(), m.original);
  });
}
