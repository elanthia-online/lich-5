// Grouped radio regressions for the shipped renderer: an unselected group submits
// the empty-String wire value, a choice submits its value, and a redraw keeps an
// unsubmitted choice until the server authors a different selection. Runtime admission
// of the empty String is pinned in spec/lib/webui/validator_spec.rb.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const { browserAssets } = require('./webui_assets_fixture.cjs');

function fixture(t) {
  const root = path.resolve(__dirname, '../../lib/webui/assets');
  const dom = new JSDOM(fs.readFileSync(path.join(root, 'index.html'), 'utf8'), {
    url: 'http://127.0.0.1/', runScripts: 'outside-only', pretendToBeVisual: true
  });
  t.after(() => dom.window.close());
  const sent = [];
  const listeners = {};
  dom.window.WebSocket = class {
    static OPEN = 1;
    readyState = 1;
    addEventListener(name, callback) { listeners[name] = callback; }
    send(json) { sent.push(JSON.parse(json)); }
  };
  for (const asset of browserAssets()) dom.window.eval(asset.source);
  return { dom, sent, receive: message => listeners.message({ data: JSON.stringify(message) }) };
}

test('an unselected radio group submits the empty String, a choice submits its value, and a redraw keeps it', t => {
  const { dom, receive, sent } = fixture(t);
  const { document, Event } = dom.window;
  const render = (generation, selected) => receive({ type: 'render', page: 'order', generation,
    bindings: { size: ['change'], save: ['activate'] }, submissions: { save: ['size'] },
    tree: { type: 'page', cid: 'root', props: { title: 'Order' }, children: [
      { type: 'radio', cid: 'size', props: { label: 'Size', group: 'size',
        options: [{ value: 's', label: 'Small' }, { value: 'm', label: 'Medium' }],
        ...(selected === undefined ? {} : { selected }) } },
      { type: 'button', cid: 'save', props: { label: 'Save' } }
    ] } });
  const save = () => {
    document.querySelector('button[data-cid="save"]').click();
    const message = sent.at(-1);
    return [message.event, message.generation, message.submission];
  };
  const checked = () => [...document.querySelectorAll('[data-cid="size"] input')].filter(input => input.checked).map(input => input.value);
  receive({ type: 'hello', pages: [{ address: 'order' }] });
  render(1);
  const observed = { unselected: save() };
  const medium = document.querySelector('[data-cid="size"] input[value="m"]');
  medium.checked = true;
  medium.dispatchEvent(new Event('change'));
  observed.change = [sent.at(-1).event, sent.at(-1).payload];
  // An unrelated redraw with no authored selection keeps the unsubmitted choice.
  render(2);
  observed.redrawChecked = checked();
  observed.chosen = save();
  // An authored selection serializes its own choice.
  render(3, 's');
  observed.authoredChecked = checked();
  observed.authored = save();
  assert.deepEqual(observed, {
    unselected: ['activate', 1, ['']],
    change: ['change', { value: 'm' }],
    redrawChecked: ['m'], chosen: ['activate', 2, ['m']],
    authoredChecked: ['s'], authored: ['activate', 3, ['s']]
  });
});
