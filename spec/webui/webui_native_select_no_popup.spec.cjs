const { test, expect } = require('@playwright/test');
const { render, selectState, openSelect, attachObservation } = require('./webui_native_select_fixture.cjs');

// Calibrated headless Chrome leaves this boundary gesture without a native popup.
// The WebKit project excludes this Chrome-only condition at discovery.
test.use({ headless: true });

test('last-option ArrowDown releases the newest render at keyup when no popup opened', { tag: '@chromium-no-popup' }, async ({ page }, testInfo) => {
  const { select, receive } = await openSelect(page, 'b');
  let before = null, during = null, afterKeyup = null;
  try {
    await page.keyboard.down('ArrowDown');
    before = await selectState(select);
    expect(before.value).toBe('b');
    expect(before.changes).toBe(0);
    expect(before.keys).toContainEqual({ key: 'ArrowDown', trusted: true,
      alt: false, control: false, meta: false, shift: false });
    expect(before.open).toBe(false);
    receive(render(2));
    receive(render(3));
    during = await selectState(select);
    expect(during.connected && during.delivered).toBe(true);
    await expect(page.locator('h1')).toHaveText('Render 1');
    await page.keyboard.up('ArrowDown');
    afterKeyup = await selectState(select);
    await expect(page.locator('h1')).toHaveText('Render 3');
    expect(afterKeyup.connected || afterKeyup.delivered).toBe(false);
  } finally {
    try {
      await attachObservation(testInfo, 'native-boundary-observation', { before, during, afterKeyup });
    } finally {
      await page.keyboard.up('ArrowDown');
      await page.keyboard.press('Escape');
      await page.locator('button[data-cid="after"]').focus();
    }
  }
  await expect(page.locator('h1')).toHaveText('Render 3');
});
