const { test } = require('node:test');
const assert = require('node:assert/strict');
const { fixture } = require('./webui_renderer_fixture.cjs');

function tableFrame(generation) {
  return { type: 'render', page: 'table-page', generation, bindings: { table: ['cell_edit', 'selection_change'] },
    tree: { type: 'page', cid: 'page', props: { title: 'Sounds', bare: true }, children: [
      { type: 'table', cid: 'table', props: { selection: 'single', selected: [],
        columns: [{ key: 'trigger', label: 'Trigger', editor: { type: 'text' } }],
        rows: [{ key: 'warning', cells: { trigger: 'Original' } }] } } ] } };
}
function cell(f) { return f.elements.pages.children[0].children[0].children[0].children[1].children[0].children[0]; }
const keyEvent = key => ({ key, preventDefault() {}, stopPropagation() {} });

test('single-line tables opt out of wrapping without changing default tables', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Rows' }] });
  const frame = tableFrame(1);
  frame.tree.children[0].props.wrap = false;
  frame.tree.children[0].props.rows[0].cells.trigger = 'A long author name';
  f.receive(frame);
  const table = f.elements.pages.children[0].children[0].children[0];
  assert.equal(table.dataset.wrap, 'false');
  assert.equal(cell(f).textContent, 'A long author name');
  frame.generation = 2;
  delete frame.tree.children[0].props.wrap;
  f.receive(frame);
  assert.equal(f.elements.pages.children[0].children[0].children[0].dataset.wrap, undefined);
});

test('a stale cell commit replays its original value once after the fresh tree arrives', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Sounds' }] });
  f.receive(tableFrame(1));
  const target = cell(f);
  target.listeners.keydown(keyEvent('F2'));
  target.children[0].value = 'Edited';
  target.children[0].listeners.keydown(keyEvent('Enter'));
  const first = f.sent.find(item => item.event === 'cell_edit');
  f.receive({ type: 'refusal', reason: 'stale_generation', page: first.page, cid: first.cid,
    event: first.event, request: first.request });
  f.receive(tableFrame(2));
  const edits = f.sent.filter(item => item.event === 'cell_edit');
  assert.equal(edits.length, 2);
  assert.equal(edits[1].generation, 2);
  assert.deepEqual(edits[1].payload, first.payload);
  assert.notEqual(edits[1].request, first.request);
  f.receive({ type: 'refusal', reason: 'stale_generation', page: edits[1].page, cid: edits[1].cid,
    event: edits[1].event, request: edits[1].request });
  f.receive(tableFrame(3));
  assert.equal(f.sent.filter(item => item.event === 'cell_edit').length, 2);
  assert.equal(f.elements.notifications.children.length, 1);
});

test('a text cell selects its existing text at edit start, as GtkCellRendererText does', () => {
  const f = fixture('table-page');
  const createElement = f.document.createElement;
  let selected = 0;
  f.document.createElement = tag => {
    const element = createElement(tag);
    if (tag === 'input') element.select = () => selected++;
    return element;
  };
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Text cells' }] });
  f.receive(tableFrame(1));
  cell(f).listeners.keydown(keyEvent('F2'));
  assert.equal(selected, 1);
});

test('an unscrolled expanding table retains its natural row minimum instead of a clipped viewport', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Unscrolled list' }] });
  const frame = tableFrame(1);
  Object.assign(frame.tree.children[0].props, { fill: true, scrollable: false });
  f.receive(frame);
  const wrapper = f.elements.pages.children[0].children[0];
  assert.equal(wrapper.style.overflow, 'visible');
  assert.equal(wrapper.style.flex, '1 0 auto');
  assert.equal(wrapper.style.height, 'auto');
  assert.equal(wrapper.style.minHeight, 'min-content');
  assert.notEqual(wrapper.style.contain, 'size');
  frame.generation = 2;
  delete frame.tree.children[0].props.scrollable;
  f.receive(frame);
  const scroller = f.elements.pages.children[0].children[0];
  assert.equal(scroller.style.contain, 'size');
  assert.equal(scroller.style.minHeight, '0px');
});

test('explicit column resizing stays local and survives subsequent table renders', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Repository' }] });
  const frame = tableFrame(1);
  frame.tree.children[0].props.columns[0].resizable = true;
  f.receive(frame);
  const table = f.elements.pages.children[0].children[0].children[0];
  const header = table.children[1].children[0].children[0];
  header.getBoundingClientRect = () => ({ width: 100 });
  const handle = header.children.at(-1);
  handle.listeners.pointerdown({ button: 0, clientX: 100, pointerId: 1, preventDefault() {}, stopPropagation() {} });
  handle.listeners.pointermove({ clientX: 150 });
  handle.listeners.pointerup({ pointerId: 1 });
  assert.equal(table.children[0].children[0].style.width, '150px');
  frame.generation = 2;
  f.receive(frame);
  const replacement = f.elements.pages.children[0].children[0].children[0];
  assert.equal(replacement.children[0].children[0].style.width, '150px');
  assert.equal(f.sent.some(item => item.event === 'sort_change' || item.event === 'cell_edit'), false);
});

test('selection refresh cannot erase an edited cell; commit uses the latest generation and remains visible', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Sounds' }] });
  f.receive(tableFrame(1));
  const original = cell(f);
  original.listeners.click(keyEvent(''));
  const input = original.children[0];
  input.value = 'Edited';
  f.receive(tableFrame(2));
  assert.equal(cell(f), original);
  input.listeners.keydown(keyEvent('Enter'));
  const edit = f.sent.find(item => item.event === 'cell_edit');
  assert.equal(edit.generation, 2);
  assert.equal(edit.payload.value, 'Edited');
  assert.equal(cell(f).textContent, 'Edited');
  input.listeners.blur();
  assert.equal(f.sent.filter(item => item.event === 'cell_edit').length, 1);
});

test('Escape cancels a cell edit without emitting a settings change', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Sounds' }] });
  f.receive(tableFrame(1));
  const target = cell(f);
  target.listeners.keydown(keyEvent('F2'));
  const input = target.children[0];
  input.value = 'Discard me';
  input.listeners.keydown(keyEvent('Escape'));
  assert.equal(target.textContent, 'Original');
  assert.equal(f.sent.some(item => item.event === 'cell_edit'), false);
});

test('committed cell edits update the accessible label before another server render', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Sounds' }] });
  f.receive(tableFrame(1));
  const target = cell(f);
  target.listeners.keydown(keyEvent('F2'));
  target.children[0].value = 'Changed';
  target.children[0].listeners.keydown(keyEvent('Enter'));
  assert.equal(target.attributes['aria-label'], 'Trigger: Changed');
});

test('opening an editor preserves a saved sound absent from current choices', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Sounds' }] });
  const frame = tableFrame(1);
  frame.tree.children[0].props.columns[0].editor = { type: 'select',
    options: [{ value: 'bell', label: 'bell' }, { value: 'gong', label: 'gong' }] };
  frame.tree.children[0].props.rows[0].cells.trigger = 'missing.wav';
  f.receive(frame);
  const target = cell(f);
  target.listeners.keydown(keyEvent('F2'));
  const picker = target.children[0];
  assert.equal(picker.value, 'missing.wav');
  picker.listeners.blur();
  assert.equal(target.textContent, 'missing.wav');
  assert.equal(f.sent.some(item => item.event === 'cell_edit'), false);
  target.listeners.keydown(keyEvent('F2'));
  const changed = target.children[0];
  changed.value = 'gong';
  changed.listeners.change();
  assert.equal(f.sent.filter(item => item.event === 'cell_edit').length, 1);
  assert.equal(f.sent.find(item => item.event === 'cell_edit').payload.value, 'gong');
});

test('opening a sound choice already in the list does not assign its read-only select type', () => {
  const f = fixture('table-page');
  const createElement = f.document.createElement;
  f.document.createElement = tag => {
    const element = createElement(tag);
    if (tag === 'select') Object.defineProperty(element, 'type', {
      get: () => 'select-one',
      set: () => { throw new TypeError('HTMLSelectElement.type is read-only'); }
    });
    return element;
  };
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Sounds' }] });
  const frame = tableFrame(1);
  frame.tree.children[0].props.columns[0].editor = { type: 'select',
    options: [{ value: 'bell', label: 'bell' }, { value: 'gong', label: 'gong' }] };
  frame.tree.children[0].props.rows[0].cells.trigger = 'bell';
  f.receive(frame);
  const target = cell(f);
  target.listeners.keydown(keyEvent('F2'));
  assert.equal(target.children[0].value, 'bell');
});


test('headerless peer tables transfer a row only within the same page and declared group', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Spells' }] });
  const message = tableFrame(1);
  message.bindings.table = ['row_drop'];
  const component = message.tree.children[0];
  component.props.transfer_group = 'spells';
  component.props.columns[0].label = '';
  f.receive(message);
  const wrapper = f.elements.pages.children[0].children[0];
  const table = wrapper.children[0];
  assert.equal(table.children.length, 1);
  assert.equal(table.children[0].tagName, 'tbody');
  const row = table.children[0].children[0];
  const data = {};
  const event = { preventDefault() {}, dataTransfer: {
    setData(type, value) { data[type] = value; }, getData(type) { return data[type]; }
  } };
  row.listeners.dragstart(event);
  wrapper.listeners.drop(event);
  assert.deepEqual(f.sent.find(item => item.event === 'row_drop').payload, { source: 'table', row: 'warning' });
  data['application/x-lich-row'] = JSON.stringify({ page: 'another', group: 'spells', source: 'table', row: 'warning' });
  wrapper.listeners.drop(event);
  assert.equal(f.sent.filter(item => item.event === 'row_drop').length, 1);
});

test('formatted table cells retain their original numeric sort values', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Repository' }] });
  const frame = tableFrame(1);
  frame.tree.children[0].props = { selection: 'single', sortable: true,
    columns: [{ key: 'downloads', label: 'DLs', sortable: true }],
    rows: [{ key: 'many', cells: { downloads: '1,000' }, sort_cells: { downloads: 1000 } },
      { key: 'few', cells: { downloads: '20' }, sort_cells: { downloads: 20 } }] };
  f.receive(frame);
  const table = f.elements.pages.children[0].children[0].children[0];
  table.children[0].children[0].children[0].children[0].listeners.click();
  assert.deepEqual(table.children[1].children.map(row => row.dataset.rowKey), ['few', 'many']);
  assert.equal(table.children[1].children[1].children[0].textContent, '1,000');
});


test('a nonresizable content-sized first column keeps explicit table semantics', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Spells' }] });
  const frame = tableFrame(1);
  frame.tree.children[0].props.columns = [{ key: 'trigger', label: '', width: 0 }, { key: 'name', label: '' }];
  frame.tree.children[0].props.rows[0].cells.name = 'Spell name';
  f.receive(frame);
  const table = f.elements.pages.children[0].children[0].children[0];
  assert.equal(table.attributes.role, 'table');
  assert.equal(table.children[0].tagName, 'colgroup');
  assert.equal(table.children[0].children[0].style.width, '0px');
});


test('table grid-line choice remains explicit without changing cells', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Sounds' }] });
  const message = tableFrame(1);
  message.tree.children[0].props.grid_lines = 'both';
  f.receive(message);
  const table = f.elements.pages.children[0].children[0].children[0];
  assert.equal(table.dataset.gridLines, 'both');
});


test('explicit lexical sorting preserves GTK filename order instead of natural numeric order', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Files' }] });
  const message = tableFrame(1);
  message.tree.children[0].props = { selection: 'single', sortable: true, sort_mode: 'lexical',
    sort: { column: 'file', direction: 'asc' }, columns: [{ key: 'file', label: 'File', sortable: true }],
    rows: ['file2', 'file10', 'file1'].map(file => ({ key: file, cells: { file } })) };
  f.receive(message);
  const table = f.elements.pages.children[0].children[0].children[0];
  assert.deepEqual(table.children.at(-1).children.map(row => row.dataset.rowKey), ['file1', 'file10', 'file2']);
});


test('color previews preserve literal cell text and reject non-hex styling input', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Colors' }] });
  const frame = tableFrame(1);
  frame.tree.children[0].props.columns = [{ key: 'trigger', label: '', color_preview: { width: 30, height: 20 } }];
  Object.assign(frame.tree.children[0].props, { fill: true, min_height: 300, row_height: 34, border_width: 0 });
  frame.tree.children[0].props.rows[0].cells.trigger = '#FFB000';
  f.receive(frame);
  const wrap = f.elements.pages.children[0].children[0];
  assert.equal(wrap.style.minHeight, '300px');
  assert.equal(wrap.style.contain, 'size');
  assert.equal(wrap.style.borderWidth, '0px');
  let row = wrap.children[0].children[0].children[0];
  assert.equal(row.style.height, '34px');
  assert.equal(row.children[0].children[0].style.backgroundColor, '#FFB000');
  frame.generation = 2;
  frame.tree.children[0].props.rows[0].cells.trigger = 'url(https://example.invalid)';
  f.receive(frame);
  row = f.elements.pages.children[0].children[0].children[0].children[0].children[0];
  assert.equal(row.children[0].children[0].style.backgroundColor, '#FFFFFF');
  assert.equal(row.children[0].children[1].textContent, 'url(https://example.invalid)');
});


test('editing or cancelling a preview cell retains its swatch and literal text', () => {
  const f = fixture('table-page');
  f.receive({ type: 'hello', pages: [{ address: 'table-page', title: 'Colors' }] });
  const frame = tableFrame(1);
  frame.tree.children[0].props.columns[0].color_preview = { width: 30, height: 20 };
  frame.tree.children[0].props.rows[0].cells.trigger = '#AABBCC';
  f.receive(frame);
  const target = cell(f);
  target.listeners.keydown(keyEvent('F2'));
  target.children[0].value = '#112233';
  target.children[0].listeners.keydown(keyEvent('Enter'));
  assert.equal(target.children[0].style.backgroundColor, '#112233');
  assert.equal(target.children[1].textContent, '#112233');
  target.listeners.keydown(keyEvent('F2'));
  target.children[0].value = '#FFFFFF';
  target.children[0].listeners.keydown(keyEvent('Escape'));
  assert.equal(target.children[0].style.backgroundColor, '#112233');
  assert.equal(f.sent.filter(item => item.event === 'cell_edit').length, 1);
});
