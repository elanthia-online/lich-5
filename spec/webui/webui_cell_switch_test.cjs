const { test } = require('node:test');
const assert = require('node:assert/strict');
const { measuredDomFixture: fixture } = require('./webui_measured_dom_fixture.cjs');


test('table fills apply only to enabled cells and update without interpreting source markup', t => {
  const f = fixture(); t.after(() => f.dom.window.close());
  f.receive({ type: 'hello', pages: [{ address: 'colors' }] });
  function render(generation, color) {
    f.receive({ type: 'render', page: 'colors', generation, tree: { type: 'page', cid: 'root', props: { title: 'Cells' }, children: [{
      type: 'table', cid: 'table', props: { columns: [{ key: 'text', label: 'Name', ...(color ? { background: color } : {}) }], rows: [
        { key: 'painted', cells: { text: '<b>Literal</b>' } },
        { key: 'plain', cells: { text: 'Plain' }, background_disabled: ['text'] }
      ] }
    }] } });
  }
  render(1, { r: 255, g: 255, b: 255, a: 1 });
  let cells = f.element('table').querySelectorAll('tbody td');
  assert.equal(cells[0].style.backgroundColor, 'rgb(255, 255, 255)');
  assert.equal(cells[1].style.backgroundColor, '');
  assert.equal(cells[0].textContent, '<b>Literal</b>');
  assert.equal(cells[0].querySelector('b'), null);
  render(2, null);
  cells = f.element('table').querySelectorAll('tbody td');
  assert.equal(cells[0].style.backgroundColor, '');
});

test('switch uses a keyboard-accessible boolean input, preserves state, and sends change events', t => {
  const f = fixture(); t.after(() => f.dom.window.close());
  f.receive({ type: 'hello', pages: [{ address: 'switch' }] });
  function render(generation, checked, disabled = false) {
    f.receive({ type: 'render', page: 'switch', generation, bindings: { dark: ['change'] }, tree: {
      type: 'page', cid: 'root', props: { title: 'Switch' }, children: [{ type: 'toggle', cid: 'dark', props: {
        label: 'Dark mode', appearance: 'switch', checked, disabled
      } }]
    } });
  }
  render(1, false);
  let input = f.element('dark').querySelector('input');
  assert.equal(input.type, 'checkbox');
  assert.equal(input.getAttribute('role'), 'switch');
  assert.equal(input.getAttribute('aria-label'), 'Dark mode');
  assert.equal(f.element('dark').querySelector('.webui-switch-track').getAttribute('aria-hidden'), 'true');
  input.click();
  assert.equal(input.checked, true);
  assert.deepEqual(f.sent.at(-1).payload, { value: true });
  assert.equal(f.sent.at(-1).event, 'change');
  render(2, true, true);
  input = f.element('dark').querySelector('input');
  const before = f.sent.length;
  input.click();
  assert.equal(input.disabled, true);
  assert.equal(input.checked, true);
  assert.equal(f.sent.length, before);
});
