const { test } = require('node:test');
const assert = require('node:assert/strict');
const { measuredDomFixture } = require('./webui_measured_dom_fixture.cjs');

// Observe the existing renderer boundary; do not export private lifecycle helpers.
function fixture(t) {
  const f = measuredDomFixture();
  t.after(() => f.dom.window.close());
  const renderer = f.dom.window.LichWebUI.renderers.page;
  f.dom.window.LichWebUI.renderers.page = (page, component) => {
    f.page = page;
    return renderer(page, component);
  };
  f.receive({ type: 'hello', pages: [{ address: 'lifecycle' }] });
  return f;
}

function frame(generation) {
  return { type: 'render', page: 'lifecycle', generation, resume: `resume-${generation}`,
    bindings: { name: ['change'], notes: ['blur'], save: ['activate'], table: ['cell_edit'] },
    submissions: { save: ['name'] },
    tree: { type: 'page', cid: 'root', props: { title: `Generation ${generation}`, bare: true }, children: [
      { type: 'text_input', cid: 'name', props: { value: 'Base' } },
      { type: 'text_input', cid: 'draft', props: { value: 'Local' } },
      { type: 'textarea', cid: 'notes', props: { value: 'Notes' } },
      { type: 'button', cid: 'save', props: { label: 'Save' } },
      { type: 'table', cid: 'table', props: {
        columns: [{ key: 'name', label: 'Name', editor: { type: 'text' } }],
        rows: [{ key: 'one', cells: { name: 'Original' } }]
      } }
    ] } };
}

// The base frame plus one surface for each gesture hold: a split handle, a
// resizable and transferable table column/row, and a widget drag source.
function holdFrame(generation) {
  const message = frame(generation);
  const table = message.tree.children.find(child => child.cid === 'table');
  table.props = { ...table.props, transfer_group: 'rows',
    columns: table.props.columns.map(column => ({ ...column, resizable: true })) };
  message.tree.children.push(
    { type: 'split', cid: 'split', props: { orientation: 'horizontal' }, children: [
      { type: 'text', cid: 'left', slot: 'first', props: { content: 'Left' } },
      { type: 'text', cid: 'right', slot: 'second', props: { content: 'Right' } }
    ] },
    { type: 'button', cid: 'carry', props: { label: 'Carry', drag_source: true } });
  return message;
}

function pointer(f, type) {
  return new f.dom.window.MouseEvent(type, { bubbles: true, cancelable: true, button: 0 });
}

function drag(f, type) {
  const event = new f.dom.window.Event(type, { bubbles: true, cancelable: true });
  Object.defineProperty(event, 'dataTransfer', { value: { effectAllowed: '', setData() {} } });
  return event;
}

function key(f, value) {
  return new f.dom.window.KeyboardEvent('keydown', { key: value, bubbles: true });
}

// Each hold is entered and released only through the shipped event handler
// that owns it, so a release handler that stops replaying the deferred render
// fails its own case. Document-level releases replay after a zero timeout.
const holds = {
  splitDragging: {
    target: f => f.element('split').querySelector('.split-handle'),
    enter: (f, handle) => handle.dispatchEvent(pointer(f, 'pointerdown')),
    release: (f, handle) => handle.dispatchEvent(pointer(f, 'pointerup'))
  },
  columnDragging: {
    target: f => f.element('table').querySelector('.webui-column-resize'),
    enter: (f, handle) => handle.dispatchEvent(pointer(f, 'pointerdown')),
    release: (f, handle) => handle.dispatchEvent(pointer(f, 'pointerup'))
  },
  editingCell: {
    target: f => f.element('table').querySelector('td'),
    enter: (f, cell) => cell.dispatchEvent(key(f, 'F2')),
    release: (f, cell) => cell.querySelector('input').dispatchEvent(key(f, 'Escape'))
  },
  pointerActive: {
    target: f => f.element('carry'),
    enter: (f, source) => source.dispatchEvent(pointer(f, 'pointerdown')),
    release: (f, source) => source.dispatchEvent(pointer(f, 'pointerup'))
  },
  rowDragging: {
    target: f => f.element('table').querySelector('tbody tr'),
    enter: (f, row) => row.dispatchEvent(drag(f, 'dragstart')),
    release: (f, row) => row.dispatchEvent(drag(f, 'dragend'))
  }
};

for (const [hold, gesture] of Object.entries(holds)) {
  test(`${hold} defers only the newest generation without retiring the current DOM`, async t => {
    const f = fixture(t);
    // jsdom has no pointer capture; the split handle requires the call to exist.
    f.dom.window.Element.prototype.setPointerCapture ??= () => {};
    f.receive(holdFrame(1));
    const root = f.page.element;
    let retired = 0;
    f.page.inputDisposers.push(() => retired++);
    const target = gesture.target(f);
    gesture.enter(f, target);
    assert.equal(f.page[hold], true, `the real ${hold} gesture did not start`);
    f.receive(holdFrame(3));
    f.receive(holdFrame(2));
    f.receive(holdFrame(3));
    assert.equal(f.page.element, root);
    assert.equal(f.page.generation, 1);
    assert.equal(f.page.deferredRender.generation, 3);
    assert.equal(retired, 0);
    gesture.release(f, target);
    await new Promise(resolve => f.dom.window.setTimeout(resolve, 0));
    assert.equal(f.page[hold], false);
    assert.equal(f.page.deferredRender, null);
    assert.equal(f.page.generation, 3, `releasing ${hold} did not install the deferred generation`);
    assert.equal(root.isConnected, false);
    assert.equal(retired, 1);
    f.receive(holdFrame(2));
    assert.equal(f.page.generation, 3);
    assert.equal(retired, 1);
  });
}

test('replacement retires resources before construction and restores drafts before retry replay', t => {
  const f = fixture(t);
  f.receive(frame(1));
  const root = f.page.element;
  const input = f.element('draft').querySelector('input');
  input.value = 'Draft';
  input.focus();
  input.setSelectionRange(2, 4);
  f.element('save').click();
  const first = f.sent.find(message => message.event === 'activate');
  f.receive({ type: 'refusal', reason: 'stale_generation', page: first.page,
    cid: first.cid, event: first.event, request: first.request });
  const order = [];
  f.page.layoutObservers.push({ disconnect() {
    assert.equal(f.page.generation, 2);
    assert.equal(f.page.controls.size, 0);
    assert.equal(root.isConnected, true);
    order.push('observer');
  } });
  f.page.inputDisposers.push(() => {
    assert.equal(f.page.layoutObservers.length, 0);
    assert.equal(root.isConnected, true);
    order.push('input');
  });
  const renderer = f.dom.window.LichWebUI.renderers.page;
  f.dom.window.LichWebUI.renderers.page = (page, component) => {
    order.push('construct');
    if (page.generation === 2) assert.equal(page.inputDisposers.length, 0);
    return renderer(page, component);
  };
  const replace = root.replaceWith.bind(root);
  root.replaceWith = next => {
    order.push('replace');
    assert.equal(f.page.restoringFocus, true);
    // Force Chrome's replacement blur in this DOM fixture; it is mechanical.
    f.element('notes').querySelector('textarea').dispatchEvent(new f.dom.window.Event('blur'));
    replace(next);
  };
  f.receive(frame(2));
  assert.deepEqual(order, ['observer', 'input', 'construct', 'replace']);
  const restored = f.element('draft').querySelector('input');
  assert.equal(restored.value, 'Draft');
  assert.equal(f.dom.window.document.activeElement, restored);
  assert.deepEqual([restored.selectionStart, restored.selectionEnd], [2, 4]);
  const replay = f.sent.filter(message => message.event === 'activate');
  assert.equal(replay.length, 2);
  assert.equal(replay[1].generation, 2);
  assert.deepEqual(replay[1].submission, ['Base']);
  assert.equal(f.sent.some(message => message.event === 'blur'), false);
  assert.equal(f.page.restoringFocus, false);
  f.receive(frame(3));
  assert.equal(f.sent.filter(message => message.event === 'activate').length, 2);
});

for (const ending of ['close', 'disconnect', 'detach']) {
  test(`${ending} preserves its own resource and attachment lifetime`, t => {
    const f = fixture(t);
    f.receive(frame(1));
    const root = f.page.element;
    const order = [];
    f.page.layoutObservers.push({ disconnect: () => order.push('observer') });
    f.page.inputDisposers.push(() => order.push('input'));
    f.page.trackedPointer = { finish: event => order.push(event.type) };
    f.page.reportGeometry = () => order.push('geometry');
    f.page.reportWindowState = () => {};
    if (ending === 'close') {
      f.receive({ type: 'page_closed', page: 'lifecycle' });
      assert.deepEqual(order, ['close', 'observer', 'input']);
      assert.equal(root.isConnected, false);
      f.receive(frame(2));
      assert.equal(f.element('root'), null);
    } else if (ending === 'disconnect') {
      f.disconnect();
      assert.deepEqual(order, ['input', 'disconnect']);
      assert.equal(root.isConnected, true);
      assert.equal(f.element('name').querySelector('input').value, 'Base');
      f.receive({ type: 'hello', pages: [{ address: 'lifecycle' }] });
      assert.equal(f.sent.at(-1).resume, 'resume-1');
    } else {
      f.dom.window.dispatchEvent(new f.dom.window.Event('pagehide'));
      assert.deepEqual(order, ['geometry']);
      assert.equal(root.isConnected, true);
      // Pagehide also fires on reload; the page stays resumable, so no detach is sent.
      assert.equal(f.sent.filter(message => message.type === 'detach').length, 0);
    }
  });
}

for (const finish of ['Enter', 'Escape']) {
  test(`cell ${finish} releases the newest deferred tree once before a duplicate blur`, t => {
    const f = fixture(t);
    f.receive(frame(1));
    const cell = f.element('table').querySelector('td');
    cell.dispatchEvent(new f.dom.window.KeyboardEvent('keydown', { key: 'F2', bubbles: true }));
    const control = cell.querySelector('input');
    control.value = 'Edited';
    f.receive(frame(3));
    f.receive(frame(2));
    assert.equal(f.page.generation, 1);
    control.dispatchEvent(new f.dom.window.KeyboardEvent('keydown', { key: finish, bubbles: true }));
    control.dispatchEvent(new f.dom.window.Event('blur'));
    const edits = f.sent.filter(message => message.event === 'cell_edit');
    assert.equal(f.page.generation, 3);
    assert.equal(f.page.editingCell, false);
    assert.equal(f.page.deferredRender, null);
    assert.equal(f.element('table').querySelector('td').textContent, finish === 'Enter' ? 'Edited' : 'Original');
    assert.equal(edits.length, finish === 'Enter' ? 1 : 0);
    if (finish === 'Enter') {
      assert.equal(edits[0].generation, 3);
      assert.deepEqual(edits[0].payload, { row: 'one', column: 'name', value: 'Edited' });
    }
  });
}
