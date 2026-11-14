// Tone style regressions for the shipped stylesheet: positive and caution notices
// render with their app.css rules applied, and each foreground/background pair
// meets the WCAG AA 4.5:1 contrast ratio for normal text.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const { browserAssets } = require('./webui_assets_fixture.cjs');

const root = path.resolve(__dirname, '../../lib/webui/assets');

function fixture(t) {
  const dom = new JSDOM(fs.readFileSync(path.join(root, 'index.html'), 'utf8'), {
    url: 'http://127.0.0.1/', runScripts: 'outside-only', pretendToBeVisual: true
  });
  t.after(() => dom.window.close());
  // jsdom does not fetch the linked stylesheet; install the shipped app.css inline
  // so its parser and getComputedStyle cascade see the same rules.
  const style = dom.window.document.createElement('style');
  style.textContent = fs.readFileSync(path.join(root, 'app.css'), 'utf8');
  dom.window.document.head.append(style);
  const listeners = {};
  dom.window.WebSocket = class {
    static OPEN = 1;
    readyState = 1;
    addEventListener(name, callback) { listeners[name] = callback; }
    send() {}
  };
  for (const asset of browserAssets()) dom.window.eval(asset.source);
  return { dom, sheet: style.sheet, receive: message => listeners.message({ data: JSON.stringify(message) }) };
}

/** Parses jsdom's serialized rgb() value into 0-255 channels. */
function channels(value) {
  const match = /^rgb\((\d+), (\d+), (\d+)\)$/.exec(value);
  assert.ok(match, `expected an opaque rgb() color, got ${value}`);
  return match.slice(1).map(Number);
}

/** WCAG 2 contrast ratio between two opaque sRGB colors. */
function contrast(foreground, background) {
  const luminance = rgb => {
    const [r, g, b] = rgb.map(channel => {
      const value = channel / 255;
      return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const [light, dark] = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
  return (light + 0.05) / (dark + 0.05);
}

test('positive and caution notices apply their app.css tone rules with at least 4.5:1 contrast', t => {
  const { dom, sheet, receive } = fixture(t);
  const { document } = dom.window;
  receive({ type: 'hello', pages: [{ address: 'launcher' }] });
  receive({ type: 'render', page: 'launcher', generation: 1,
    tree: { type: 'page', cid: 'root', props: { title: 'Launcher' }, children: [
      { type: 'text', cid: 'saved', props: { content: 'Settings saved', tone: 'positive' } },
      { type: 'text', cid: 'catalog', props: { content: 'Catalog unavailable', tone: 'caution' } }
    ] } });
  const observed = {};
  for (const [tone, cid] of [['positive', 'saved'], ['caution', 'catalog']]) {
    const rule = [...sheet.cssRules].find(candidate => candidate.selectorText === `.tone-${tone}`);
    assert.ok(rule, `app.css defines .tone-${tone}`);
    const notice = document.querySelector(`[data-cid="${cid}"]`);
    const computed = dom.window.getComputedStyle(notice);
    const ratio = contrast(channels(rule.style.color), channels(rule.style.backgroundColor));
    observed[tone] = {
      classed: notice.classList.contains(`tone-${tone}`),
      color: computed.color === rule.style.color,
      background: computed.backgroundColor === rule.style.backgroundColor,
      contrast: ratio >= 4.5
    };
    t.diagnostic(`${tone}: ${rule.style.color} on ${rule.style.backgroundColor} = ${ratio.toFixed(2)}:1`);
  }
  assert.deepEqual(observed, {
    positive: { classed: true, color: true, background: true, contrast: true },
    caution: { classed: true, color: true, background: true, contrast: true }
  });
});
