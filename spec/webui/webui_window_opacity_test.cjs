const { test } = require('node:test');
const assert = require('node:assert/strict');
const { fixture } = require('./webui_renderer_fixture.cjs');

test('OS window opacity is never multiplied by a second CSS fade', () => {
  for (const native of [true, false]) {
    const f = fixture('main');
    if (native) f.window.lichNativeWindow = { present() {} };
    f.receive({ type: 'hello', pages: [{ address: 'main', title: 'Opacity' }] });
    f.receive({ type: 'render', page: 'main', generation: 1, window_presentation: native ? {} : { opacity: true },
      tree: { type: 'page', cid: 'page', props: { title: 'Opacity' }, children: [] },
      facilities: { presentation: { opacity: 0.5 } } });
    assert.equal(f.elements.pages.children[0].style.opacity, '');
  }
});
