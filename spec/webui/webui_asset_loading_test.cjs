// Asset admission and startup checks use the production HTML and shipped source.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { browserAssets } = require('./webui_assets_fixture.cjs');
const { fixture } = require('./webui_renderer_fixture.cjs');

const assets = browserAssets();
const familyNames = ['menus', 'layout', 'display', 'inputs', 'table'];
const types = ['page', 'group', 'stack', 'columns', 'grid', 'scroll', 'tabs', 'expander',
  'divider', 'overlay', 'split', 'text', 'markdown', 'log', 'progress', 'image', 'button',
  'checkbox', 'toggle', 'radio_option', 'radio', 'text_input', 'password_input', 'textarea',
  'number_input', 'slider', 'select', 'table', 'dialog', 'composite'];

test('production HTML loads every shipped JavaScript asset once, before application startup', () => {
  const root = path.resolve(__dirname, '../../lib/webui/assets');
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const tags = html.match(/<script\b[^>]*>[\s\S]*?<\/script>/g);
  assert.equal(tags.length, 6);
  assert.deepEqual(assets.map(asset => asset.name), [...familyNames.map(name => `renderers_${name}.js`), 'app.js']);
  assert.deepEqual(tags, assets.map(asset => `<script src="/assets/${asset.name}" defer></script>`));
  assert.deepEqual(fs.readdirSync(root).filter(name => name.endsWith('.js')).sort(), assets.map(asset => asset.name).sort());
});

test('family loading registers factories without DOM, timers, listeners, sockets or application startup', () => {
  const context = vm.createContext({ window: {} });
  for (const asset of assets.slice(0, -1)) vm.runInContext(asset.source, context, { filename: asset.name });
  assert.deepEqual(Object.keys(context.window), ['LichWebUIRendererFamilies']);
  assert.deepEqual(Object.keys(context.window.LichWebUIRendererFamilies), familyNames);
  for (const factory of Object.values(context.window.LichWebUIRendererFamilies)) assert.equal(typeof factory, 'function');
});

for (const missing of familyNames) test(`missing ${missing} family stops startup before a socket is opened`, () => {
  let sockets = 0;
  const context = vm.createContext({ window: { location: { search: '' } },
    document: { getElementById() { return {}; } }, URLSearchParams,
    WebSocket: class { constructor() { sockets++; } } });
  for (const asset of assets.slice(0, -1)) {
    if (asset.name !== `renderers_${missing}.js`) vm.runInContext(asset.source, context, { filename: asset.name });
  }
  assert.throws(() => vm.runInContext(assets.at(-1).source, context), /is not a function/);
  assert.equal(sockets, 0);
});

test('application keeps its public facade and complete renderer vocabulary after family assembly', () => {
  const f = fixture(null);
  assert.deepEqual(Object.keys(f.window.LichWebUI).sort(), ['VERSION', 'render', 'renderers']);
  assert.deepEqual(Object.keys(f.window.LichWebUI.renderers).sort(), types.sort());
  assert.equal(Object.isFrozen(f.window.LichWebUI), true);
  assert.equal(Object.isFrozen(f.window.LichWebUIRendererFamilies), true);
});

test('input aliases continue to resolve through the public renderer dictionary', () => {
  const { renderers } = fixture(null).window.LichWebUI;
  const page = {}, toggle = { props: {} }, slider = { props: { value: 4 } };
  const checkbox = {}, number = {};
  renderers.checkbox = (owner, component) => { assert.equal(owner, page); assert.equal(component, toggle); return checkbox; };
  renderers.number_input = (owner, component) => {
    assert.equal(owner, page);
    assert.equal(component, slider);
    return number;
  };
  assert.equal(renderers.toggle(page, toggle), checkbox);
  assert.equal(renderers.slider(page, slider), number);
});

test('standalone menu fixture loads the same family sequence as the production entry point', () => {
  const html = fs.readFileSync(path.join(__dirname, 'webui_menu_fixture.html'), 'utf8');
  const scripts = [...html.matchAll(/<script src="\.\.\/\.\.\/lib\/webui\/assets\/([a-z_]+\.js)"><\/script>/g)];
  assert.deepEqual(scripts.map(match => match[1]), assets.map(asset => asset.name));
});
