// Markdown link-scan bound for the shipped renderer: a contract-maximum run of
// opening brackets renders in bounded work, and valid links still parse with
// bracket-free link text.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { performance } = require('node:perf_hooks');
const { JSDOM } = require('jsdom');
const { browserAssets } = require('./webui_assets_fixture.cjs');

// lib/webui/contract.rb bounds rich_text (Markdown content) at 65,536 characters.
const RICH_TEXT_LIMIT = 65536;
// The renderer exposes no regex step count, so this is a wall-clock bound. The
// fixed renderer takes well under 100 ms here; the quadratic pre-fix scan takes
// several seconds, so a 1 s bound separates them without timing flakiness.
const RENDER_BOUND_MS = 1000;

function fixture(t) {
  const root = path.resolve(__dirname, '../../lib/webui/assets');
  const dom = new JSDOM(fs.readFileSync(path.join(root, 'index.html'), 'utf8'), {
    url: 'http://127.0.0.1/', runScripts: 'outside-only', pretendToBeVisual: true
  });
  t.after(() => dom.window.close());
  dom.window.WebSocket = class {
    static OPEN = 1;
    readyState = 1;
    addEventListener() {}
    send() {}
  };
  for (const asset of browserAssets()) dom.window.eval(asset.source);
  const page = { controls: new Map(), bindings: {}, submissions: {} };
  return { dom, markdown: content => dom.window.LichWebUI.render(page, { type: 'markdown', cid: 'help', props: { content } }) };
}

test('a contract-maximum run of opening brackets renders in bounded time as literal text', t => {
  const { markdown } = fixture(t);
  const content = '['.repeat(RICH_TEXT_LIMIT);
  const started = performance.now();
  const wrapper = markdown(content);
  const elapsed = performance.now() - started;
  t.diagnostic(`rendered ${RICH_TEXT_LIMIT} brackets in ${elapsed.toFixed(1)} ms`);
  assert.ok(elapsed < RENDER_BOUND_MS, `rendering ${RICH_TEXT_LIMIT} brackets took ${elapsed.toFixed(1)} ms`);
  assert.equal(wrapper.textContent, content);
  assert.equal(wrapper.querySelectorAll('a').length, 0);
});

test('valid Markdown links still parse, and link text excludes brackets', t => {
  const { markdown } = fixture(t);
  const links = wrapper => [...wrapper.querySelectorAll('a')].map(anchor => [anchor.textContent, anchor.href, anchor.title]);
  const plain = markdown('See [Docs](https://example.com/docs) and [Guide](https://example.com/guide "Read first").');
  assert.deepEqual(links(plain), [
    ['Docs', 'https://example.com/docs', ''],
    ['Guide', 'https://example.com/guide', 'Read first']
  ]);
  assert.equal(plain.textContent, 'See Docs and Guide.');
  const prefix = '['.repeat(1000);
  const afterRun = markdown(`${prefix}[Docs](https://example.com/docs)`);
  assert.deepEqual(links(afterRun), [['Docs', 'https://example.com/docs', '']]);
  assert.equal(afterRun.textContent, `${prefix}Docs`);
});
