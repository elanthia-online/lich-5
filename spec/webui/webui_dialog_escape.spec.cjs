const { test, expect } = require('@playwright/test');
const { openRenderer } = require('./webui_engine_fixture.cjs');

const render = declared => ({ type: 'render', page: 'confirm-page', generation: 1,
  bindings: { confirm: ['response'] },
  tree: { type: 'page', cid: 'root', props: { title: 'Accounts' }, children: [
    { type: 'dialog', cid: 'confirm', props: { title: 'Delete account?', body: 'This cannot be undone.',
      buttons: [{ id: 'keep', label: 'Keep' }, { id: 'delete', label: 'Delete' }],
      ...(declared ? { cancel_button: 'keep' } : {}) } }
  ] } });

/**
 * Lets native dialog tasks/paint finish before reading the retained delivered node.
 * @param {import('@playwright/test').ElementHandle} dialog Original native modal dialog.
 * @returns {Promise<Object>} State includes close events even if the renderer reopened it.
 */
async function dialogState(dialog) {
  return dialog.evaluate(async element => {
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return { connected: element.isConnected, open: element.open,
      delivered: document.querySelector('dialog[data-cid="confirm"]') === element,
      closes: element.escapeProbe.closes, keys: element.escapeProbe.keys };
  });
}

for (const declared of [false, true]) {
  test(`five Escapes and a held Escape preserve a dialog ${declared ? 'with' : 'without'} cancel_button`, async ({ page }) => {
    const { sent, receive } = await openRenderer(page);
    receive({ type: 'hello', pages: [{ address: 'confirm-page' }] });
    await expect.poll(() => sent.some(message => message.type === 'attach' && message.page === 'confirm-page')).toBe(true);
    receive(render(declared));
    const modal = page.locator('dialog[data-cid="confirm"]');
    await expect(modal).toBeVisible();
    const dialog = await modal.elementHandle();
    await dialog.evaluate(element => {
      element.escapeProbe = { closes: 0, keys: [] };
      element.addEventListener('close', () => element.escapeProbe.closes += 1);
      document.addEventListener('keydown', event => {
        if (event.key === 'Escape') element.escapeProbe.keys.push({ trusted: event.isTrusted, repeat: event.repeat });
      });
    });

    const keys = [];
    const responses = [];
    // Check the complete wire response list after every gesture, not just the final total.
    const check = async label => {
      expect(await dialogState(dialog), label).toEqual({ connected: true, open: true, delivered: true, closes: 0, keys });
      expect(sent.filter(message => message.event === 'response').map(message => ({
        type: message.type, page: message.page, cid: message.cid, generation: message.generation, payload: message.payload
      })), label).toEqual(responses);
    };
    const response = { type: 'event', page: 'confirm-page', cid: 'confirm', generation: 1, payload: { button: 'keep' } };
    for (let press = 1; press <= 5; press += 1) {
      await page.keyboard.press('Escape');
      keys.push({ trusted: true, repeat: false });
      if (declared) responses.push(response);
      await check(`Escape ${press}`);
    }
    try {
      await page.keyboard.down('Escape');
      keys.push({ trusted: true, repeat: false });
      if (declared) responses.push(response);
      await check('held Escape initial keydown');
      for (let repeat = 1; repeat <= 3; repeat += 1) {
        await page.keyboard.down('Escape');
        keys.push({ trusted: true, repeat: true });
        await check(`held Escape repeat ${repeat}`);
      }
    } finally {
      await page.keyboard.up('Escape');
    }
    await check('held Escape release');
  });
}
