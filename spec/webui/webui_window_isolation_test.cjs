// Run the entire shipped renderer against a small DOM/socket test double.
// These checks need only Node built-ins and never open a game session.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { fixture } = require("./webui_renderer_fixture.cjs");

const catalog = [
  { address: 'map', title: 'Map' }, { address: 'ubw', title: 'UberBarWiz' }, { address: 'spellson', title: 'Spellson' }
];
function render(address, title, width = 240, height = 200) {
  const cid = `${address}/text_input:window-content-geometry`;
  return { type: 'render', page: address, generation: 1, resume: `resume-${address}`,
    bindings: { [cid]: ['change'] }, tree: { type: 'page', cid: address, props: { title, bare: true }, children: [
      { type: 'text', cid: `${address}/label`, props: { content: `${title} only` } },
      { type: 'text_input', cid, props: { hidden: true, value: JSON.stringify({ width, height }) } }
    ] } };
}

for (const requested of catalog) {
  test(`${requested.title} attaches/renders/resizes/closes only its own page`, () => {
    const f = fixture(requested.address);
    f.receive({ type: 'hello', pages: catalog });
    assert.deepEqual(f.sent.map(message => message.page), [requested.address]);
    catalog.forEach((page, index) => f.receive(render(page.address, page.title, 200 + index, 300 + index)));
    assert.equal(f.document.title, requested.title);
    assert.equal(f.elements.pages.children.length, 1);
    assert.equal(f.elements.pages.children[0].dataset.pageAddress, requested.address);
    const index = catalog.indexOf(requested);
    assert.deepEqual(f.resized, [[200 + index, 330 + index]]);
    f.receive({ type: 'pages', pages: [...catalog, { address: 'new-script', title: 'Unrelated new script' }] });
    assert.equal(f.document.title, requested.title);
    assert.equal(f.sent.filter(message => message.type === 'attach').length, 1);
    f.windowEvents.pagehide();
    assert.deepEqual(f.sent.filter(message => message.type === 'detach').map(message => message.page), [requested.address]);
  });
}

test('same-owner dialogs appear only in their associated window and retain its title', () => {
  const f = fixture('map');
  f.receive({ type: 'hello', pages: catalog });
  f.receive(render('map', 'Map'));
  f.receive({ type: 'pages', pages: [...catalog,
    { address: 'map-dialog', title: 'Map question', modal_for: ['map'] },
    { address: 'ubw-dialog', title: 'UBW question', modal_for: ['ubw'] }] });
  f.receive({ type: 'render', page: 'map-dialog', generation: 1, tree: {
    type: 'page', cid: 'dialog-page', props: { title: 'Map question' }, children: [] } });
  assert.deepEqual(f.sent.filter(message => message.type === 'attach').map(message => message.page), ['map', 'map-dialog']);
  assert.equal(f.document.title, 'Map');
});

test('reconnect resumes only the requested page', () => {
  const f = fixture('ubw');
  f.receive({ type: 'hello', pages: catalog });
  f.receive(render('ubw', 'UberBarWiz'));
  f.receive({ type: 'hello', pages: catalog });
  assert.deepEqual(f.sent.filter(message => message.type === 'attach').map(message => [message.page, message.resume]),
    [['ubw', undefined], ['ubw', 'resume-ubw']]);
});

test('an old window cannot adopt the replacement page after its script restarts', () => {
  const f = fixture('map');
  f.receive({ type: 'hello', pages: catalog });
  f.receive(render('map', 'Map'));
  f.receive({ type: 'page_closed', page: 'map' });
  f.receive({ type: 'pages', pages: [{ address: 'map-reopened', title: 'Map' }, ...catalog.slice(1)] });
  assert.equal(f.elements.pages.children.length, 0);
  assert.deepEqual(f.sent.filter(message => message.type === 'attach').map(message => message.page), ['map']);
  const reopened = fixture('map-reopened');
  reopened.receive({ type: 'hello', pages: [{ address: 'map-reopened', title: 'Map' }, ...catalog.slice(1)] });
  assert.deepEqual(reopened.sent.map(message => message.page), ['map-reopened']);
});

test('the explicit untargeted overview retains its multi-page behavior', () => {
  const f = fixture(null);
  f.receive({ type: 'hello', pages: catalog });
  assert.deepEqual(f.sent.map(message => message.page), catalog.map(page => page.address));
});
