const { expect } = require('@playwright/test');
const { openRenderer } = require('./webui_engine_fixture.cjs');

const render = (generation, value = 'b') => ({ type: 'render', page: 'form', generation,
  bindings: { choice: ['change'] },
  tree: { type: 'page', cid: 'root', props: { title: `Render ${generation}` }, children: [
    { type: 'select', cid: 'choice', props: { label: 'Choice', value,
      options: [{ value: 'a', label: 'A' }, { value: 'b', label: 'B' }] } },
    { type: 'button', cid: 'after', props: { label: 'After' } }
  ] } });

/**
 * Observes the actual native select without assuming any modifier opens a popup.
 * @param {import('@playwright/test').ElementHandle} select Retained delivered select.
 * @returns {Promise<Object>} Native popup support/state, value and observed events.
 */
async function selectState(select) {
  return select.evaluate(async element => {
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    let open = null;
    try { open = element.matches(':open'); } catch { /* Older WebKit retains the documented fallback. */ }
    return { connected: element.isConnected,
      delivered: document.querySelector('[data-cid="choice"] select') === element,
      open, value: element.value, ...element.selectProbe };
  });
}

/**
 * Delivers one production-rendered select and records native change/focus/key events.
 * @param {import('@playwright/test').Page} page Isolated real-engine page.
 * @param {string} value Initial option, chosen at the tested arrow's boundary.
 * @returns {Promise<Object>} Transport and the original select handle.
 */
async function openSelect(page, value) {
  const wire = await openRenderer(page);
  wire.receive({ type: 'hello', pages: [{ address: 'form' }] });
  await expect.poll(() => wire.sent.some(message => message.type === 'attach' && message.page === 'form')).toBe(true);
  wire.receive(render(1, value));
  const control = page.locator('[data-cid="choice"] select');
  await expect(control).toBeVisible();
  const select = await control.elementHandle();
  await select.evaluate(element => {
    element.selectProbe = { changes: 0, focusouts: 0, keys: [] };
    element.addEventListener('change', () => element.selectProbe.changes += 1);
    element.addEventListener('focusout', () => element.selectProbe.focusouts += 1);
    element.addEventListener('keydown', event => element.selectProbe.keys.push({ key: event.key,
      trusted: event.isTrusted, alt: event.altKey, control: event.ctrlKey, meta: event.metaKey, shift: event.shiftKey }));
  });
  await control.focus();
  return { ...wire, control, select };
}

module.exports = { render, selectState, openSelect };
