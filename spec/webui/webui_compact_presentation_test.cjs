const { test } = require('node:test');
const assert = require('node:assert/strict');
const { fixture } = require('./webui_renderer_fixture.cjs');

function frame(generation = 1) {
  return { type: 'render', page: 'spells', generation, bindings: { page: ['configure'], split: ['move'] },
    tree: { type: 'page', cid: 'page', props: { title: 'Spells', bare: true, theme: 'light', density: 'compact', size: [340, 25] }, children: [
      { type: 'split', cid: 'split', props: { orientation: 'horizontal' }, children: [
        { type: 'text', cid: 'duration', slot: 'first', props: { content: '0:30:00', align: 'center', width: 72 } },
        { type: 'progress', cid: 'bar', slot: 'second', props: { value: 0.5, height: 24, fill_color: { r: 176, g: 224, b: 230, a: 1 } } }
      ] }
    ] } };
}

function viewer() {
  const f = fixture('spells');
  f.receive({ type: 'hello', pages: [{ address: 'spells', title: 'Spells' }] });
  f.receive(frame());
  return f;
}

test('groups distinguish absent labels from blank labels without changing borderless layouts', () => {
  const f = fixture('groups');
  f.receive({ type: 'hello', pages: [{ address: 'groups', title: 'Groups' }] });
  f.receive({ type: 'render', page: 'groups', generation: 1,
    tree: { type: 'page', cid: 'page', props: { bare: true, density: 'compact' }, children: [
      { type: 'group', cid: 'borderless', props: { label: '', border_width: 0 }, children: [] },
      { type: 'group', cid: 'framed', props: { label: '', border_width: 1 }, children: [] },
      { type: 'group', cid: 'default', props: { label: '' }, children: [] },
      { type: 'group', cid: 'unlabeled', props: { border_width: 3 }, children: [] },
      { type: 'group', cid: 'named', props: { label: 'Named' }, children: [] }
    ] } });
  const [borderless, framed, defaultFrame, unlabeled, named] = f.elements.pages.children[0].children;
  assert.equal(borderless.dataset.borderless, 'true');
  assert.equal(framed.dataset.borderless, undefined);
  assert.equal(defaultFrame.dataset.borderless, undefined);
  assert.equal(framed.dataset.emptyLabel, 'true');
  assert.equal(defaultFrame.dataset.emptyLabel, 'true');
  assert.equal(unlabeled.dataset.emptyLabel, undefined);
  assert.equal(unlabeled.children.length, 0);
  assert.equal(named.dataset.emptyLabel, undefined);
  assert.equal(named.children[0].tagName, 'legend');
  assert.equal(named.children[0].textContent, 'Named');
});

test('explicit native and shim page resize requests measure intrinsic content rather than the current viewport', () => {
  for (const viewport of [false, true]) {
    const f = fixture('form');
    f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Sizing' }] });
    const frame = generation => ({ type: 'render', page: 'form', generation, bindings: { root: ['configure'] },
      tree: { type: 'page', cid: 'root', props: { title: 'Sizing', bare: true, viewport, size: [600, 400] }, children: [] } });
    f.receive(frame(1));
    f.frame();
    f.resized.length = 0;
    const next = frame(2);
    next.tree.props.resize_request = { id: 'smaller', size: [400, 300] };
    f.receive(next);
    const root = f.elements.pages.children[0];
    Object.defineProperties(root, {
      scrollWidth: { get: () => root.style.width === '0px' ? 378 : 600 },
      scrollHeight: { get: () => root.style.height === '0px' ? 126 : 400 }
    });
    const previous = { width: root.style.width, height: root.style.height, minHeight: root.style.minHeight };
    f.frame();
    assert.deepEqual(f.resized, [[400, 330]]);
    assert.deepEqual({ width: root.style.width, height: root.style.height, minHeight: root.style.minHeight }, previous);
  }
});

test('only an explicitly unscrolled table constrains its host to the current natural contents', () => {
  for (const scrollable of [false, true]) {
    const f = fixture('form');
    f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Sizing' }] });
    f.receive({ type: 'render', page: 'form', generation: 1, bindings: { root: ['configure'] },
      tree: { type: 'page', cid: 'root', props: { title: 'Sizing', bare: true, size: [600, 400] }, children: [
        { type: 'table', cid: 'list', props: { fill: true, scrollable,
          columns: [{ key: 'text', label: 'Text' }], rows: [] } }
      ] } });
    f.frame();
    const root = f.elements.pages.children[0];
    Object.defineProperties(root, {
      scrollWidth: { get: () => root.style.width === '0px' ? 378 : 600 },
      scrollHeight: { get: () => root.style.height === '0px' ? 126 : 400 }
    });
    f.resized.length = 0;
    f.window.innerWidth = 100; f.window.innerHeight = 100;
    f.window.outerWidth = 100; f.window.outerHeight = 130;
    f.windowEvents.resize({ type: 'resize' });
    assert.deepEqual(f.resized, scrollable ? [] : [[378, 156]]);
    f.windowEvents.resize({ type: 'resize' });
    assert.equal(f.resized.length, scrollable ? 0 : 1, 'a refused host resize must not loop');
  }
});

test('native and shim resize measurements use the target width before measuring wrapped height', () => {
  for (const viewport of [false, true]) {
    const f = fixture('form');
    f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Wrapped control' }] });
    f.receive({ type: 'render', page: 'form', generation: 1, bindings: { root: ['configure'] },
      tree: { type: 'page', cid: 'root', props: { bare: true, viewport, size: [600, 400] }, children: [] } });
    const root = f.elements.pages.children[0];
    Object.defineProperties(root, {
      scrollWidth: { get: () => root.style.width === '0px' ? 300 : 600 },
      scrollHeight: { get: () => root.style.width === '0px' ? 900 : root.style.width === '400px' ? 420 : 180 }
    });
    f.frame();
    assert.deepEqual(f.resized, [[600, 430]]);
    assert.equal(root.style.width, undefined);
    f.receive({ type: 'render', page: 'form', generation: 2, bindings: { root: ['configure'] },
      tree: { type: 'page', cid: 'root', props: { bare: true, viewport,
        resize_request: { id: 'narrower', size: [400, 300] } }, children: [] } });
    const replacement = f.elements.pages.children[0];
    Object.defineProperties(replacement, {
      scrollWidth: { get: () => replacement.style.width === '0px' ? 300 : 600 },
      scrollHeight: { get: () => replacement.style.width === '400px' ? 420 : 900 }
    });
    f.frame();
    assert.deepEqual(f.resized.at(-1), [400, 450]);
  }
});

test('an explicitly right-aligned footer button aligns the control, not only its caption', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form' }, children: [{ type: 'button', cid: 'close', props: { label: 'Close', align: 'end' } }] } });
  const button = f.elements.pages.children[0].children.at(-1);
  assert.equal(button.style.alignSelf, 'flex-end');
  assert.equal(button.style.justifySelf, 'end');
});

test('a button width request keeps its natural label width in a natural grid', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form', bare: true, density: 'compact', theme: 'light' }, children: [
      { type: 'grid', cid: 'grid', props: { cols: 2, homogeneous: false }, children: [
        { type: 'button', cid: 'load', placement: { column: 1, row: 1 },
          props: { label: 'Load Profile', min_width: 30, align: 'start' } },
        { type: 'text', cid: 'message', placement: { column: 2, row: 1 },
          props: { content: 'Message' } }
      ] }
    ] } });
  const button = f.elements.pages.children[0].children[0].children[0];
  assert.equal(button.style.minWidth, '30px');
  assert.equal(button.style.width, 'max-content');
});

test('unconfigured native and shim entries share a natural width while requests override it', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Entries', bare: true, density: 'compact', theme: 'light' }, children: [
      { type: 'text_input', cid: 'native', props: { value: '' } },
      { type: 'text_input', cid: 'shim', props: { value: '', change_mode: 'input' } },
      { type: 'text_input', cid: 'requested', props: { value: '', control_width: 100 } },
      { type: 'text_input', cid: 'capped', props: { value: '', max_width_chars: 35 } },
      { type: 'text_input', cid: 'search', props: { value: '', search: true } },
      { type: 'select', cid: 'editable', props: { value: '', editable: true, options: [] } },
      { type: 'select', cid: 'sized_editable', props: { value: '', editable: true, control_width: 202, options: [] } }
    ] } });
  const fields = f.elements.pages.children[0].children;
  assert.equal(fields[0].children[0].dataset.naturalEntry, 'true');
  assert.equal(fields[1].children[0].dataset.naturalEntry, 'true');
  assert.equal(fields[2].children[0].dataset.naturalEntry, undefined);
  assert.equal(fields[2].children[0].style.width, '100px');
  assert.equal(fields[3].children[0].dataset.naturalEntry, undefined);
  assert.equal(fields[4].children[0].dataset.naturalEntry, undefined);
  assert.equal(fields[5].children[0].children[0].dataset.naturalEntry, 'true');
  assert.equal(fields[6].children[0].children[0].dataset.naturalEntry, undefined);
});

test('literal text fragments join without markup or inserted line breaks', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form', bare: true }, children: [
      { type: 'text', cid: 'info', props: { content: '', fragments: ['<literal>', 'tail'] } },
      { type: 'log', cid: 'log', props: { lines: [['long', 'line'], 'next'], max_lines: 10 } }
    ] } });
  const [text, log] = f.elements.pages.children[0].children;
  assert.equal(text.textContent, '<literal>tail');
  assert.equal(log.textContent, 'longline\nnext');
});

test('a notebook may retain all page sizes while inactive controls remain inert', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form', bare: true }, children: [{ type: 'tabs', cid: 'tabs',
      props: { names: ['First', 'Second'], selected: 0, size_to_all: true }, children: [
        { type: 'text', cid: 'first', props: { content: 'Short', font_style: 'italic' } },
        { type: 'text_input', cid: 'second', props: { value: '', control_width_chars: 5 } }
      ] }] } });
  const tabs = f.elements.pages.children[0].children[0];
  assert.equal(tabs.dataset.sizeToAll, 'true');
  assert.equal(tabs.style.display, 'grid');
  assert.equal(tabs.style.gridTemplateRows, 'max-content minmax(min-content, 1fr)');
  assert.equal(tabs.children[2].hidden, true);
  assert.equal(tabs.children[2].inert, true);
  assert.equal(tabs.children[1].style.fontStyle, 'italic');
  assert.equal(tabs.children[2].children[0].style.width, 'calc(5 * round(up, 1ch, 1px) + 2 * var(--entry-padding, 8px) + 2px)');
});

test('a filling notebook panel stretches to its grid track instead of keeping a zero flex-basis height', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form', bare: true }, children: [{ type: 'tabs', cid: 'tabs',
      props: { names: ['Status'], selected: 0, size_to_all: true }, children: [
        { type: 'group', cid: 'status', props: { label: '', fill: true }, children: [] }
      ] }] } });
  assert.equal(f.elements.pages.children[0].children[0].children[1].style.height, 'auto');
});

test('a pixel divider preserves the second pane through resizing and subsequent renders', () => {
  const f = fixture('spells'), observers = [];
  f.window.ResizeObserver = class {
    constructor(callback) { this.callback = callback; observers.push(this); }
    observe() {}
    disconnect() { this.disconnected = true; }
  };
  f.receive({ type: 'hello', pages: [{ address: 'spells', title: 'Spells' }] });
  const message = frame();
  Object.assign(message.tree.children[0].props, { position_pixels: 700, resize_side: 'first', fill: true });
  f.receive(message);
  let split = f.elements.pages.children[0].children[0];
  split.clientWidth = 1082;
  f.frame();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 381px');
  split.clientWidth = 1322; observers[0].callback();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 381px');
  f.receive({ ...message, generation: 2 });
  split = f.elements.pages.children[0].children[0]; split.clientWidth = 1322; f.frame();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 381px');
  assert.equal(observers[0].disconnected, true);
  split.children[1].listeners.keydown({ key: 'End', preventDefault() {} });
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 0px');
  f.receive({ ...message, generation: 3 });
  split = f.elements.pages.children[0].children[0]; split.clientWidth = 1322; f.frame();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 0px');
});

test('a pixel divider opened below its requested position recovers when the window grows', () => {
  const f = fixture('spells'), observers = [];
  f.window.ResizeObserver = class {
    constructor(callback) { this.callback = callback; observers.push(this); }
    observe() {}
    disconnect() {}
  };
  f.receive({ type: 'hello', pages: [{ address: 'spells', title: 'Spells' }] });
  const message = frame();
  Object.assign(message.tree.children[0].props, { position_pixels: 700, resize_side: 'first', fill: true });
  f.receive(message);
  const split = f.elements.pages.children[0].children[0];
  split.clientWidth = 580;
  f.frame();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 0px');
  split.clientWidth = 1082;
  observers[0].callback();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 381px');
  split.clientWidth = 1322;
  observers[0].callback();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 381px');
});

test('a pixel divider keeps the original requested allocation through intermediate widths', () => {
  const f = fixture('spells'), observers = [];
  f.window.ResizeObserver = class {
    constructor(callback) { this.callback = callback; observers.push(this); }
    observe() {}
    disconnect() {}
  };
  f.receive({ type: 'hello', pages: [{ address: 'spells', title: 'Spells' }] });
  const message = frame();
  message.tree.props.size = [1100, 700];
  Object.assign(message.tree.children[0].props, { position_pixels: 700, resize_side: 'first', fill: true });
  f.receive(message);
  const page = f.elements.pages.children[0], split = page.children[0];
  page.clientWidth = 600; split.clientWidth = 582;
  f.frame();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 381px');
  page.clientWidth = 734; split.clientWidth = 716; observers[0].callback();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 381px');
  page.clientWidth = 1100; split.clientWidth = 1082; observers[0].callback();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 381px');
});

test('a pixel divider first mounted after a page grows uses its requested allocation', () => {
  const f = fixture('spells');
  f.window.ResizeObserver = class {
    constructor(callback) { this.callback = callback; }
    observe() {}
    disconnect() {}
  };
  f.receive({ type: 'hello', pages: [{ address: 'spells', title: 'Spells' }] });
  const message = frame();
  message.tree.props.size = [1100, 700];
  Object.assign(message.tree.children[0].props, { position_pixels: 700, resize_side: 'first', fill: true });
  f.receive(message);
  const page = f.elements.pages.children[0], split = page.children[0];
  page.clientWidth = 1340; split.clientWidth = 1322;
  f.frame();
  assert.equal(split.style.gridTemplateColumns, 'minmax(0, 1fr) 1px 381px');
});

test('horizontal status runs never wrap and middle ellipsis responds to measured allocation', () => {
  const f = fixture('labels'), observers = [];
  f.receive({ type: 'hello', pages: [{ address: 'labels', title: 'Labels' }] });
  f.window.ResizeObserver = class {
    constructor(callback) { this.callback = callback; observers.push(this); }
    observe(element) { this.element = element; }
    disconnect() { this.disconnected = true; }
  };
  const message = { type: 'render', page: 'labels', generation: 1, tree: {
    type: 'page', cid: 'page', props: { title: 'Labels', bare: true }, children: [
      { type: 'stack', cid: 'statuses', props: { orientation: 'horizontal', gap: 0, align: 'center' }, children: [] },
      { type: 'text', cid: 'name', props: { content: 'abcdefghij', max_width_chars: 15, ellipsize: 'middle', wrap: false } }
    ] } };
  f.receive(message);
  const [row, name] = f.elements.pages.children[0].children;
  assert.equal(row.style.flexDirection, 'row');
  assert.equal(row.style.flexWrap, 'nowrap');
  assert.equal(row.style.justifyContent, 'center');
  Object.defineProperty(name, 'scrollWidth', { get: () => name.textContent.length * 8 });
  name.clientWidth = 48;
  f.frame();
  // Check the actual Unicode ellipsis, using ASCII source spelling.
  assert.equal(name.textContent, 'abc\u2026ij');
  assert.equal(name.attributes['aria-label'], 'abcdefghij');
  name.clientWidth = 100; observers[0].callback();
  assert.equal(name.textContent, 'abcdefghij');
  f.receive({ ...message, generation: 2 });
  assert.equal(observers[0].disconnected, true);
  f.receive({ type: 'page_closed', page: 'labels' });
  assert.equal(observers[1].disconnected, true);
});

test('middle ellipsis retains a long Pango label\u2019s preferred width when its text shortens', () => {
  const f = fixture('name'), observers = [];
  f.window.getComputedStyle = () => ({ maxWidth: '82.1484px' });
  f.window.ResizeObserver = class {
    constructor(callback) { this.callback = callback; observers.push(this); }
    observe(element) { this.element = element; }
    disconnect() {}
  };
  f.receive({ type: 'hello', pages: [{ address: 'name', title: 'Name' }] });
  f.receive({ type: 'render', page: 'name', generation: 1, tree: {
    type: 'page', cid: 'page', props: { title: 'Name', bare: true }, children: [
      { type: 'group', cid: 'name-frame', props: { label: '', constrain_width: true }, children: [
        { type: 'text', cid: 'name', props: { content: 'an unusually long creature name',
          font_size: 8, font_unit: 'px', max_width_chars: 15, ellipsize: 'middle', wrap: false,
          margin: { left: 5, right: 5 } } }
      ] }
    ] } });
  const group = f.elements.pages.children[0].children[0], name = group.children[0];
  Object.defineProperty(name, 'scrollWidth', { get: () => name.textContent.length * 8 });
  name.clientWidth = 82;
  f.frame();
  assert.equal(group.style.maxWidth, '100%');
  assert.equal(name.style.width, '110px');
  assert.equal(name.style.maxWidth, 'calc(100% - 10px)');
  assert.match(name.textContent, /\u2026/);
  name.clientWidth = 60; observers[0].callback();
  assert.equal(name.style.width, '110px');
  assert.match(name.textContent, /\u2026/);
});

test('colored progress receives the source color, fraction and 24px height', () => {
  const f = viewer();
  const root = f.elements.pages.children[0];
  const split = root.children[0];
  const bar = split.children[2].children[0];
  assert.equal(root.dataset.theme, 'light');
  assert.equal(root.dataset.density, 'compact');
  assert.equal(split.style.gridTemplateColumns, 'max-content 1px minmax(0, 1fr)');
  assert.equal(bar.style.height, '24px');
  assert.equal(bar.children[0].value, 0.5);
  assert.equal(bar.children[0].style['--progress-fill'], 'rgba(176, 224, 230, 1)');
});

test('removing progress presentation restores default rendering while retaining fraction', () => {
  const f = viewer();
  const reset = frame(2);
  reset.tree.children[0].children[1].props = { value: 0.75 };
  f.receive(reset);
  const bar = f.elements.pages.children[0].children[0].children[2].children[0];
  assert.equal(bar.style.height || '', '');
  assert.equal(bar.children[0].style['--progress-fill'] || '', '');
  assert.equal(bar.children[0].value, 0.75);
});

test('a render arriving during divider drag is applied before committing against its generation', () => {
  const f = viewer();
  const root = f.elements.pages.children[0], handle = root.children[0].children[1];
  handle.listeners.pointerdown({ button: 0, pointerId: 1, preventDefault() {} });
  f.receive(frame(3));
  f.receive(frame(2));
  assert.equal(f.elements.pages.children[0], root);
  handle.listeners.pointermove({ clientX: 170, clientY: 0 });
  handle.listeners.pointerup();
  assert.notEqual(f.elements.pages.children[0], root);
  const move = f.sent.find(message => message.event === 'move');
  assert.equal(move.generation, 3);
  assert.deepEqual(move.payload, { position: 50 });
});

test('keyboard movement is bounded and cancelled gestures release deferred renders', () => {
  const f = viewer();
  const root = f.elements.pages.children[0], handle = root.children[0].children[1];
  handle.listeners.keydown({ key: 'End', preventDefault() {} });
  handle.listeners.keydown({ key: 'ArrowRight', preventDefault() {} });
  assert.deepEqual(f.sent.filter(message => message.event === 'move').map(message => message.payload.position), [100, 100]);
  handle.listeners.pointerdown({ button: 0, pointerId: 1, preventDefault() {} });
  f.receive(frame(3));
  handle.listeners.pointercancel();
  assert.notEqual(f.elements.pages.children[0], root);
});

test('page geometry fits minimum content, reports changes and retains user size across renders', () => {
  const f = viewer();
  f.frame();
  assert.deepEqual(f.resized, [[340, 174]]);
  f.window.innerWidth = 400; f.window.innerHeight = 200; f.window.outerWidth = 400; f.window.outerHeight = 230;
  f.window.screenX = -10;
  f.windowEvents.resize();
  f.receive(frame(2)); f.frame();
  assert.equal(f.resized.length, 1);
  const configs = f.sent.filter(message => message.event === 'configure');
  assert.deepEqual(configs.at(-1).payload, { width: 400, height: 200, position: [-10, 0], monitors: { source: 'unavailable', screens: [] } });
  f.windowEvents.pagehide();
  assert.equal(f.sent.at(-1).type, 'detach');
});

test('a rerender cannot expand a manually reduced window and restores negative desktop positions once', () => {
  const f = fixture('spells'), moved = [];
  f.window.moveTo = (...position) => moved.push(position);
  f.receive({ type: 'hello', pages: [{ address: 'spells', title: 'Spells' }] });
  const initial = frame(); initial.tree.props.position = [-900, 40];
  f.receive(initial); f.frame();
  f.window.innerWidth = 200; f.window.innerHeight = 100;
  f.receive(frame(2)); f.frame();
  assert.deepEqual(moved, [[-900, 40]]);
  assert.equal(f.resized.length, 1);
  assert.deepEqual(f.sent.filter(x => x.event === 'configure').at(-1).payload,
    { width: 200, height: 100, position: [0, 0], monitors: { source: 'unavailable', screens: [] } });
});

test('compact columns keep their declared desktop layout and label links remain literal-safe', () => {
  const f = fixture('spells');
  f.receive({ type: 'hello', pages: [{ address: 'spells', title: 'Spells' }] });
  const message = frame();
  message.tree.children = [{ type: 'columns', cid: 'choices', props: { count: 2, compact: true }, children: [
    { type: 'markdown', cid: 'help', slot: '0', props: { content: 'Sonic [Shield](https://gswiki.play.net/Sonic_Shield_Song_(1009)) <script>x</script> [bad](javascript:alert(1))' } }
  ] }];
  f.receive(message);
  const columns = f.elements.pages.children[0].children[0];
  assert.equal(columns.dataset.compact, 'true');
  assert.equal(columns.style.gridTemplateColumns, '1fr 1fr');
  const label = columns.children[0];
  assert.equal(label.children[1].href, 'https://gswiki.play.net/Sonic_Shield_Song_(1009)');
  assert.equal(label.children[1].rel, 'noopener noreferrer');
  assert.equal(label.children[2].textContent, ' <script>x</script> [bad](javascript:alert(1))');
});

test('linked setup labels preserve the original GTK line breaks', () => {
  const f = fixture('spells');
  f.receive({ type: 'hello', pages: [{ address: 'spells', title: 'Setup' }] });
  const message = frame();
  message.tree.children = [{ type: 'markdown', cid: 'help', props: {
    content: 'First line\n      Indented line\n\n      Read [the guide](https://example.org/guide)'
  } }];
  f.receive(message);
  const label = f.elements.pages.children[0].children[0];
  assert.equal(label.style.whiteSpace, 'pre-wrap');
  assert.equal(label.children[0].textContent, 'First line\n      Indented line\n\n      Read ');
  assert.equal(label.children[1].href, 'https://example.org/guide');
});

test('collapsed expanders retain child inputs for submission and report user toggles', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1,
    bindings: { fold: ['toggle'], save: ['activate'] }, submissions: { save: ['choice'] },
    tree: { type: 'page', cid: 'page', props: { title: 'Form', bare: true }, children: [
      { type: 'expander', cid: 'fold', props: { label: 'Defensive', open: false }, children: [
        { type: 'checkbox', cid: 'choice', props: { label: 'Blink', checked: true } }
      ] },
      { type: 'button', cid: 'save', props: { label: 'Close' } }
    ] } });
  const root = f.elements.pages.children[0], fold = root.children[0];
  assert.equal(fold.tagName, 'details');
  assert.equal(fold.open, false);
  root.children[1].listeners.click();
  assert.deepEqual(f.sent.find(item => item.event === 'activate').submission, [true]);
  fold.listeners.toggle();
  assert.equal(f.sent.filter(item => item.event === 'toggle').length, 0);
  fold.open = true;
  fold.listeners.toggle();
  assert.deepEqual(f.sent.find(item => item.event === 'toggle').payload, { open: true });
});


test('explicit keyboard actions work without an added visible button, while disabled actions remain inert', () => {
  const f = fixture('calibration');
  f.receive({ type: 'hello', pages: [{ address: 'calibration', title: 'Calibrator' }] });
  const message = { type: 'render', page: 'calibration', generation: 1,
    bindings: { save: ['activate'] }, facilities: { accelerators: [{ keys: 's', target: 'save', event: 'activate' }] },
    tree: { type: 'page', cid: 'root', props: { title: 'Calibrator' }, children: [
      { type: 'button', cid: 'save', props: { label: 'Keyboard save', hidden: true } }
    ] } };
  f.receive(message);
  f.documentEvents.keydown({ key: 's', target: f.elements.pages, preventDefault() {} });
  assert.equal(f.sent.filter(item => item.event === 'activate').length, 1);
  message.generation = 2; message.tree.children[0].props.disabled = true;
  f.receive(message);
  f.documentEvents.keydown({ key: 's', target: f.elements.pages, preventDefault() {} });
  assert.equal(f.sent.filter(item => item.event === 'activate').length, 1);
});

test('native panels retain explicit padding and border colors around all their content', () => {
  const f = fixture('panel');
  f.receive({ type: 'hello', pages: [{ address: 'panel', title: 'Panel' }] });
  f.receive({ type: 'render', page: 'panel', generation: 1, bindings: { panel: ['surface_activate'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Panel', bare: true }, children: [
      { type: 'group', cid: 'panel', props: { label: '', padding: 2, border_color: { r: 255, g: 215, b: 0, a: 1 }, surface_events: true }, children: [] }
    ] } });
  const panel = f.elements.pages.children[0].children[0];
  assert.equal(panel.style.padding, '2px');
  assert.equal(panel.style.borderColor, 'rgba(255, 215, 0, 1)');
  panel.listeners.click({ clientX: 20, clientY: 30, target: panel });
  assert.deepEqual(f.sent.at(-1).payload, { x: 20, y: 30, button: 'primary', modifiers: [] });
});

test('entry rows keep the label before a compact fixed-width input', () => {
  const f = fixture('entry');
  f.receive({ type: 'hello', pages: [{ address: 'entry', title: 'Entry' }] });
  f.receive({ type: 'render', page: 'entry', generation: 1,
    tree: { type: 'page', cid: 'root', props: { title: 'Entry', bare: true }, children: [
      { type: 'text_input', cid: 'entry', props: { label: 'Scale:', value: '1.0', inline: true, control_width: 65 } }
    ] } });
  const row = f.elements.pages.children[0].children[0];
  assert.equal(row.children[0].textContent, 'Scale:');
  assert.equal(row.children[1].style.width, '65px');
});

test('a fixed entry width never becomes its height in a vertical field', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1,
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'text_input', cid: 'entry', props: { value: '180', control_width: 168 } }
    ] } });
  const input = f.elements.pages.children[0].children[0].children[0];
  assert.equal(input.style.width, '168px');
  assert.equal(input.style.flex, '0 0 auto');
});

test('editable choices retain suggestions and submit literal custom text', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, bindings: { ice: ['change'], save: ['activate'] }, submissions: { save: ['ice'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'select', cid: 'ice', props: { editable: true, value: 'legacy', options: [{ value: 'auto', label: 'auto' }] } },
      { type: 'button', cid: 'save', props: { label: 'Close' } }
    ] } });
  const root = f.elements.pages.children[0], field = root.children[0], row = field.children[0], input = row.children[0];
  assert.equal(input.tagName, 'input');
  assert.equal(input.value, 'legacy');
  assert.equal(field.children[1].tagName, 'datalist');
  input.value = 'custom'; input.listeners.input(); input.listeners.change();
  assert.equal(f.sent.filter(item => item.event === 'change').length, 1);
  root.children[1].listeners.click();
  assert.deepEqual(f.sent.at(-1).submission, ['custom']);
  const chooser = row.children[1].children[1];
  assert.equal(chooser.children.length, 1);
  chooser.value = 'auto'; chooser.listeners.change();
  assert.equal(input.value, 'auto');
  assert.deepEqual(f.sent.at(-1).payload, { value: 'auto' });
  // Typing after choosing must clear the picker's old selection, so picking
  // that same option again produces a native change event.
  input.value = 'custom again'; input.listeners.input();
  assert.equal(chooser.value, 'custom again');
  chooser.value = 'auto'; chooser.listeners.change();
  assert.equal(input.value, 'auto');
  assert.deepEqual(f.sent.at(-1).payload, { value: 'auto' });
});

test('editable choices display labels while events, submission and refresh retain option IDs', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  const frame = generation => ({ type: 'render', page: 'form', generation,
    bindings: { choice: ['change'], save: ['activate'] }, submissions: { save: ['choice'] },
    tree: { type: 'page', cid: 'root', props: { bare: true }, children: [
      { type: 'select', cid: 'choice', props: { editable: true, value: '0',
        options: [{ value: '0', label: 'None' }, { value: '6', label: 'Custom' }] } },
      { type: 'button', cid: 'save', props: { label: 'Close' } }
    ] } });
  f.receive(frame(1));
  let root = f.elements.pages.children[0], row = root.children[0].children[0];
  assert.equal(row.children[0].value, 'None');
  root.children[1].listeners.click();
  assert.deepEqual(f.sent.at(-1).submission, ['0']);
  const chooser = row.children[1].children[1];
  chooser.value = '6'; chooser.listeners.change();
  assert.equal(row.children[0].value, 'Custom');
  assert.deepEqual(f.sent.at(-1).payload, { value: '6' });
  f.receive(frame(2));
  root = f.elements.pages.children[0]; row = root.children[0].children[0];
  assert.equal(row.children[0].value, 'Custom');
  assert.equal(row.children[1].children[1].value, '6');
  root.children[1].listeners.click();
  assert.deepEqual(f.sent.at(-1).submission, ['6']);
  row.children[0].value = 'literal text'; row.children[0].listeners.input();
  root.children[1].listeners.click();
  assert.deepEqual(f.sent.at(-1).submission, ['literal text']);
  row.children[0].value = '0'; row.children[0].listeners.input();
  assert.equal(row.children[0].value, 'None');
  assert.deepEqual(f.sent.at(-1).payload, { value: '0' });
});

test('a requested editable choice height reaches its control and picker row', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1,
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'select', cid: 'profile', props: { editable: true, value: '', options: [], min_height: 42 } },
      { type: 'select', cid: 'other', props: { value: '', options: [] } },
      { type: 'select', cid: 'ordinary_requested', props: { value: '', options: [], min_height: 42 } }
    ] } });
  const requested = f.elements.pages.children[0].children[0];
  const ordinary = f.elements.pages.children[0].children[1];
  assert.equal(requested.style.minHeight, '42px');
  assert.equal(requested.children[0].style.minHeight, '42px');
  assert.equal(ordinary.style.minHeight, undefined);
  assert.equal(f.elements.pages.children[0].children[2].children[0].style.minHeight, '42px');
});

test('text changes reach the script before blur, with no duplicate on blur', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, bindings: { entry: ['change'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'text_input', cid: 'entry', props: { value: '', change_mode: 'input' } }
    ] } });
  const input = f.elements.pages.children[0].children[0].children[0];
  input.value = 'new value'; input.listeners.input(); input.listeners.change();
  assert.deepEqual(f.sent.filter(item => item.event === 'change').map(item => item.payload), [{ value: 'new value' }]);
});

test('committed entries retain partial typing until blur and still submit on Enter', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, bindings: { entry: ['change', 'submit'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'text_input', cid: 'entry', props: { value: '1.0' } }
    ] } });
  const input = f.elements.pages.children[0].children[0].children[0];
  input.value = '1.';
  input.listeners.input?.();
  assert.equal(f.sent.filter(item => item.event === 'change').length, 0);
  input.value = '1.5'; input.listeners.change();
  assert.deepEqual(f.sent.at(-1).payload, { value: '1.5' });
  input.listeners.keydown({ key: 'Enter' });
  assert.equal(f.sent.at(-1).event, 'submit');
});

test('content-sized native grids do not force controls into equal-width columns', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1,
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'grid', cid: 'natural', props: { cols: 3, homogeneous: false }, children: [] },
      { type: 'grid', cid: 'equal', props: { cols: 3 }, children: [] }
    ] } });
  const grids = f.elements.pages.children[0].children;
  assert.equal(grids[0].style.gridTemplateColumns, 'repeat(3, auto)');
  assert.equal(grids[0].style.justifyContent, 'start');
  assert.equal(grids[1].style.gridTemplateColumns, 'repeat(3, minmax(0, 1fr))');
});

test('natural grids preserve inline field minima without widening scroll containers', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1,
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'grid', cid: 'natural', props: { cols: 2, homogeneous: false }, children: [
        { type: 'text_input', cid: 'size', props: { inline: true, label: 'Size', control_width_chars: 5 } },
        { type: 'scroll', cid: 'list', props: { height: 200 }, children: [] },
        { type: 'text_input', cid: 'capped', props: { max_width_chars: 35 } },
        { type: 'table', cid: 'empty', props: { columns: [{ key: 'text', label: '' }], rows: [], height: 515, margin: 5 } }
      ] }
    ] } });
  const grid = f.elements.pages.children[0].children[0];
  assert.equal(grid.style.gridTemplateColumns, 'repeat(2, auto)');
  assert.equal(grid.children[0].style.minWidth, 'max-content');
  assert.equal(grid.children[1].style.minWidth, '0px');
  assert.notEqual(grid.children[1].style.width, '100%');
  assert.equal(grid.children[1].style.contain, 'inline-size');
  assert.notEqual(grid.children[2].style.minWidth, 'max-content');
  assert.equal(grid.children[3].style.contain, 'inline-size');
  assert.notEqual(grid.children[3].style.width, '100%');
  assert.equal(grid.children[3].style.height, '515px');
});

test('explicit spin buttons use the input step operation and emit only a changed value', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, bindings: { count: ['change'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'number_input', cid: 'count', props: { value: 4, min: 4, max: 20, step: 1, stepper_buttons: true, min_width: 132 } }
    ] } });
  const row = f.elements.pages.children[0].children[0].children[0], input = row.children[0];
  assert.equal(row.style.minWidth, '132px');
  let stepped = 0;
  input.checkValidity = () => true;
  input.stepUp = () => { stepped++; input.valueAsNumber = 5; input.value = '5'; };
  row.children[2].listeners.click();
  assert.equal(stepped, 1);
  assert.deepEqual(f.sent.at(-1).payload, { value: 5 });
  input.listeners.change();
  assert.equal(f.sent.filter(item => item.event === 'change').length, 1);
});

test('native bar captions retain a centered box and Cairo pixel font size', () => {
  const f = fixture('panel');
  f.receive({ type: 'hello', pages: [{ address: 'panel', title: 'Panel' }] });
  f.receive({ type: 'render', page: 'panel', generation: 1,
    tree: { type: 'page', cid: 'root', props: { title: 'Panel', bare: true }, children: [
      { type: 'composite', cid: 'health', props: { width: 90, height: 16, layers: [
        { kind: 'label', x: 0, y: 0, w: 90, h: 16, text: 'HP: 75/100', align: 'center', font_size: 11, font_unit: 'px' }
      ] } }
    ] } });
  const caption = f.elements.pages.children[0].children[0].children[0].children[0];
  assert.equal(caption.style.width, '90px');
  assert.equal(caption.style.height, '16px');
  assert.equal(caption.style.fontSize, '11px');
  assert.equal(caption.style.justifyContent, 'center');
});

test('native panel minimum height and explicit label font do not become fixed content height', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1,
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'group', cid: 'panel', props: { label: '', min_height: 181 }, children: [
        { type: 'text', cid: 'name', props: { content: 'Rat', font_size: 12, font_unit: 'px', font_family: 'Arial' } }
      ] }
    ] } });
  const panel = f.elements.pages.children[0].children[0];
  assert.equal(panel.style.minHeight, '181px');
  assert.equal(panel.style.height, undefined);
  assert.equal(panel.children[0].style.fontSize, '12px');
  assert.equal(panel.children[0].style.fontFamily, 'Arial');
});


test('natural grid allocates extra width only to declared expanding columns', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, bindings: {},
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'grid', cid: 'grid', props: { cols: 3, homogeneous: false, expand_columns: [2] }, children: [
        { type: 'text_input', cid: 'entry', props: { value: '', min_width: 168 }, placement: { column: 2 } }
      ] }
    ] } });
  const grid = f.elements.pages.children[0].children[0];
  assert.equal(grid.style.gridTemplateColumns, 'max-content auto max-content');
  assert.equal(grid.style.justifyContent, 'stretch');
  assert.equal(grid.children[0].style.minWidth, '168px');
  assert.equal(grid.children[0].style.width, undefined);
});


for (const axis of ['width', 'height']) {
  test(`${axis}-only minima apply at first display and updates without shrinking the other axis`, () => {
    for (const configure of [true, false]) {
      const f = fixture('form');
      f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Minima' }] });
      const message = { type: 'render', page: 'form', generation: 1,
        bindings: configure ? { root: ['configure'] } : {},
        tree: { type: 'page', cid: 'root', props: { bare: true, [`min_${axis}`]: 1000 }, children: [] } };
      f.receive(message); f.frame();
      const initial = axis === 'width' ? [1000, 630] : [800, 1030];
      assert.deepEqual(f.resized, [initial], 'a partial minimum is enforced without a launch size');
      // Model the host applying the request, then retaining a larger user/saved size.
      Object.assign(f.window, { innerWidth: 1200, outerWidth: 1200, innerHeight: 1100, outerHeight: 1130 });
      message.generation++;
      f.receive(message); f.frame();
      assert.equal(f.resized.length, 1, 'a larger window is preserved');
      message.tree.props[`min_${axis}`] = 1400;
      message.generation++;
      f.receive(message); f.frame();
      assert.deepEqual(f.resized.at(-1), axis === 'width' ? [1400, 1130] : [1200, 1430]);
      const attempts = f.resized.length;
      message.generation++;
      f.receive(message); f.frame();
      assert.equal(f.resized.length, attempts, 'a refusing host does not cause repeated identical requests');
      message.tree.props[`min_${axis}`] = 1000;
      message.generation++;
      f.receive(message); f.frame();
      assert.equal(f.resized.length, attempts, 'lowering a minimum does not shrink the window');
      message.tree.props.resize_request = { id: 'explicit', size: [500, 300] };
      message.generation++;
      f.receive(message); f.frame();
      assert.deepEqual(f.resized.at(-1), axis === 'width' ? [1000, 330] : [500, 1030]);
      assert.equal(f.resized.length, attempts + 1, 'minimum enforcement must not compete with an explicit resize');
      if (!configure) assert.equal(f.sent.filter(event => event.event === 'configure').length, 0);
    }
  });
}

test('explicit original window minima constrain resizing without restoring the launch size', () => {
  const f = fixture('spells');
  f.receive({ type: 'hello', pages: [{ address: 'spells', title: 'Spells' }] });
  const message = frame();
  message.tree.props = { ...message.tree.props, size: [900, 830], min_width: 900, min_height: 640 };
  f.receive(message); f.frame();
  assert.deepEqual(f.resized, [[900, 860]]);
  f.window.innerWidth = 500; f.window.innerHeight = 400;
  f.window.outerWidth = 500; f.window.outerHeight = 430;
  f.windowEvents.resize({ type: 'resize' });
  assert.deepEqual(f.resized.at(-1), [900, 670]);
  const attempts = f.resized.length;
  f.windowEvents.resize({ type: 'resize' });
  assert.equal(f.resized.length, attempts, 'a host refusing resize must not cause repeated attempts');
  f.window.innerWidth = 1140; f.window.innerHeight = 990;
  f.windowEvents.resize({ type: 'resize' });
  assert.equal(f.resized.length, attempts, 'expansion above the minimum is left alone');
});


test('initial natural window width comes from layout rather than a captured screenshot', () => {
  const f = viewer();
  f.elements.pages.children[0].scrollWidth = 626;
  f.frame();
  assert.deepEqual(f.resized, [[626, 174]]);
  f.window.innerWidth = 900; f.window.innerHeight = 650;
  f.windowEvents.resize({ type: 'resize' });
  f.receive(frame(2)); f.frame();
  assert.equal(f.resized.length, 1, 'a refreshed layout must not restore its launch width');
});


test('nonexpanding columns retain natural content widths instead of collapsing to zero', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, bindings: {},
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'columns', cid: 'natural', props: { count: 2, weights: [0, 0] }, children: [] }
    ] } });
  assert.equal(f.elements.pages.children[0].children[0].style.gridTemplateColumns, 'max-content max-content');
});


test('entry character caps allow growth up to the original natural width', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, bindings: {},
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'text_input', cid: 'entry', props: { value: '', min_width: 168, max_width_chars: 35 } }
    ] } });
  const field = f.elements.pages.children[0].children[0];
  assert.equal(field.style.minWidth, '168px');
  assert.equal(field.style.width, '100%');
  assert.equal(field.style.maxWidth, 'calc(35 * round(up, 1ch, 1px) + 18px)');
  assert.equal(field.children[0].style.width, field.style.maxWidth);
  assert.equal(field.children[0].style.maxWidth, '100%');
});


test('vertical radio choices preserve one value and their declared packing gap', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form', bare: true }, children: [{ type: 'radio', cid: 'mode',
      props: { label: '', group: 'mode', selected: 'name', orientation: 'vertical', gap: 15,
        options: [{ value: 'name', label: 'Full Name' }, { value: 'noun', label: 'Noun' }] } }] } });
  const radio = f.elements.pages.children[0].children[0];
  assert.equal(radio.children[1].style.flexDirection, 'column');
  assert.equal(radio.children[1].style.gap, '15px');
  assert.equal(radio.children[1].children[0].children[0].checked, true);
});


test('a centered fixed-width preview group centers its box within an expanding grid', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form', bare: true }, children: [{ type: 'group', cid: 'preview',
      props: { label: '', width: 114, align: 'center' } }] } });
  const group = f.elements.pages.children[0].children[0];
  assert.equal(group.style.justifySelf, 'center');
});


test('explicit script resize requests run once per id and stay scoped to their root window', () => {
  const f = viewer(); f.frame();
  const message = frame(2);
  message.tree.props.resize_request = { id: 'tick-1', size: [500, 250] };
  f.receive(message); f.frame();
  assert.deepEqual(f.resized.at(-1), [500, 280]);
  const count = f.resized.length;
  message.generation = 3;
  f.receive(message); f.frame();
  assert.equal(f.resized.length, count);
  message.generation = 4;
  message.tree.props.resize_request = { id: 'tick-2', size: [500, 250] };
  f.receive(message); f.frame();
  assert.equal(f.resized.length, count + 1);
  const dialog = frame(1); dialog.page = 'dialog';
  dialog.tree.props.resize_request = { id: 'other', size: [900, 700] };
  f.receive({ type: 'pages', pages: [{ address: 'spells', title: 'Spells' },
    { address: 'dialog', title: 'Dialog', modal_for: ['spells'] }] });
  f.receive(dialog); f.frame();
  assert.equal(f.resized.length, count + 1);
});


test('an explicitly filling group passes spare vertical space to its child layout', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1,
    tree: { type: 'page', cid: 'root', props: { title: 'Form', bare: true }, children: [
      { type: 'group', cid: 'panel', props: { label: '', fill: true }, children: [] }
    ] } });
  const group = f.elements.pages.children[0].children[0];
  assert.equal(group.style.flex, '1');
  assert.equal(group.style.display, 'flex');
  assert.equal(group.style.flexDirection, 'column');
});


test('an explicitly declared dialog dismissal sends its terminal response instead of hiding locally', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, bindings: { dialog: ['response'] },
    tree: { type: 'page', cid: 'page', props: { title: 'Form', bare: true }, children: [
      { type: 'dialog', cid: 'dialog', props: { title: 'Edit', cancel_button: 'cancel', buttons: [
        { id: 'cancel', label: 'Cancel' }, { id: 'save', label: 'Save' }
      ] }, children: [] }
    ] } });
  const dialog = f.elements.pages.children[0].children[0];
  let prevented = false;
  dialog.listeners.cancel({ preventDefault() { prevented = true; } });
  assert.equal(prevented, true);
  assert.deepEqual(f.sent.at(-1).payload, { button: 'cancel' });
});

test('a dialog may keep its accessible title without adding an in-content heading', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1,
    tree: { type: 'page', cid: 'page', props: { title: 'Form', bare: true }, children: [
      { type: 'dialog', cid: 'dialog', props: { title: 'Add Status Effect', show_title: false,
        no_viewer: 'wait', buttons: [{ id: 'cancel', label: 'Cancel' }] }, children: [] }
    ] } });
  const dialog = f.elements.pages.children[0].children[0];
  assert.equal(dialog.attributes['aria-label'], 'Add Status Effect');
  assert.equal(dialog.children.some(child => child.tagName === 'h2'), false);
});

// Original Gtk width-chars requests are minima; allocated spare width survives.
test('character minima retain pixel requests and leave stretching fields unfixed', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form', bare: true }, children: [
      { type: 'text', cid: 'group', props: { content: 'Entire Group', min_width_chars: 17 } },
      { type: 'text_input', cid: 'sheath', props: { value: '', min_width_chars: 20 } },
      { type: 'text_input', cid: 'hoard', props: { value: '', min_width_chars: 20, min_width: 300 } },
      { type: 'select', cid: 'boost', props: { value: '', editable: true, control_width_chars: 12, options: [] } }
    ] } });
  const [label, sheath, hoard, boost] = f.elements.pages.children[0].children;
  assert.equal(label.style.minWidth, 'calc(17 * round(up, 1ch, 1px))');
  assert.equal(sheath.style.minWidth, 'calc(20 * round(up, 1ch, 1px) + 2 * var(--entry-padding, 8px) + 2px)');
  assert.equal(sheath.children[0].style.width, undefined);
  assert.equal(hoard.style.minWidth, 'max(300px, calc(20 * round(up, 1ch, 1px) + 2 * var(--entry-padding, 8px) + 2px))');
  assert.equal(boost.children[0].style.width, 'calc(12 * round(up, 1ch, 1px) + 2 * var(--entry-padding, 8px) + 2px + 35px)');
});

// GTK reference: two 80px cells beside one 320px cell spanning eight rows
// allocate 100/100/20/20/20/20/20/20, including the otherwise empty rows.
test('explicit spread rows share a spanning minimum across occupied and empty tracks', () => {
  const f = fixture('form');
  const observers = [];
  f.window.ResizeObserver = class {
    constructor(callback) { this.callback = callback; observers.push(this); }
    observe() {}
    disconnect() { this.disconnected = true; }
  };
  f.window.getComputedStyle = element => ({ marginTop: element.style.marginTop || '0', marginBottom: element.style.marginBottom || '0' });
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form', bare: true }, children: [{ type: 'grid', cid: 'grid',
      props: { cols: 2, row_sizing: 'spread', row_gap: 0 }, children: [
        { type: 'text', cid: 'first', placement: { row: 1, column: 1 }, props: { content: 'First' } },
        { type: 'text', cid: 'second', placement: { row: 2, column: 1 }, props: { content: 'Second' } },
        { type: 'text', cid: 'span', placement: { row: 1, column: 2, row_span: 8 }, props: { content: 'Tall' } }
      ] }] } });
  const grid = f.elements.pages.children[0].children[0];
  const [first, second, spanning] = grid.children;
  first.clientHeight = second.clientHeight = 80; spanning.clientHeight = 320;
  f.frame();
  assert.equal(grid.style.gridTemplateRows, '100px 100px 20px 20px 20px 20px 20px 20px');
  assert.equal(first.style.alignSelf, undefined);
  spanning.clientHeight = 400;
  observers[0].callback();
  assert.equal(grid.style.gridTemplateRows, '110px 110px 30px 30px 30px 30px 30px 30px');
  observers[0].callback();
  assert.equal(grid.style.gridTemplateRows, '110px 110px 30px 30px 30px 30px 30px 30px');
  grid.hidden = true;
  spanning.clientHeight = 999;
  observers[0].callback();
  assert.equal(grid.style.gridTemplateRows, '110px 110px 30px 30px 30px 30px 30px 30px');
  f.receive({ type: 'page_closed', page: 'form' });
  assert.equal(observers[0].disconnected, true);
});

test('frame content alignment centers natural children without changing the frame size', () => {
  const f = fixture('form');
  f.receive({ type: 'hello', pages: [{ address: 'form', title: 'Form' }] });
  f.receive({ type: 'render', page: 'form', generation: 1, tree: { type: 'page', cid: 'page',
    props: { title: 'Form', bare: true }, children: [{ type: 'group', cid: 'frame',
      props: { label: 'Frame', content_align: 'center' }, children: [] }] } });
  const frame = f.elements.pages.children[0].children[0];
  assert.equal(frame.style.display, 'flex');
  assert.equal(frame.style.flexDirection, 'column');
  assert.equal(frame.style.justifyContent, 'center');
  assert.equal(frame.style.height, undefined);
});


test('natural grids retain framed control minima while explicit constraints and scrollers stay bounded', () => {
  for (const viewport of [false, true]) {
    const f = fixture('grid');
    f.receive({ type: 'hello', pages: [{ address: 'grid', title: 'Grid' }] });
    f.receive({ type: 'render', page: 'grid', generation: 1,
      tree: { type: 'page', cid: 'page', props: { bare: true, viewport }, children: [
        { type: 'grid', cid: 'grid', props: { cols: 2, homogeneous: false, expand_columns: [1, 2] }, children: [
          { type: 'group', cid: 'frame', props: { label: 'Controls' }, children: [
            { type: 'grid', cid: 'controls', props: { cols: 2, homogeneous: false }, children: [
              { type: 'text_input', cid: 'entry', props: { min_width: 218 } },
              { type: 'button', cid: 'button', props: { label: 'Delete', min_width: 80 } }
            ] }
          ] },
          { type: 'group', cid: 'capped', props: { constrain_width: true }, children: [] },
          { type: 'group', cid: 'explicit', props: { min_width: 100 }, children: [] },
          { type: 'table', cid: 'table', props: { columns: [{ key: 'name', label: '' }], rows: [], wrap: false } }
        ] }
      ] } });
    const [frame, capped, explicit, table] = f.elements.pages.children[0].children[0].children;
    assert.equal(frame.style.minWidth, 'min-content');
    assert.notEqual(capped.style.minWidth, 'min-content');
    assert.equal(explicit.style.minWidth, '100px');
    assert.equal(table.style.minWidth, '0px');
    assert.equal(table.style.contain, 'inline-size');
  }
});
