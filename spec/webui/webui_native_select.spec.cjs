const { test, expect } = require('@playwright/test');
const { render, selectState, openSelect } = require('./webui_native_select_fixture.cjs');

// Chrome's headless native select has no expanded popup on the supported macOS host.
test.use({ headless: false });

for (const key of ['ArrowUp', 'ArrowDown']) {
  for (const modifier of ['', 'Alt', 'Shift', 'Control', 'Meta']) {
    test(`${modifier || 'plain'} ${key} holds a native select until its observed release`, async ({ page }, testInfo) => {
      const value = key === 'ArrowDown' ? 'b' : 'a';
      const { select, receive } = await openSelect(page, value);
      if (modifier) await page.keyboard.down(modifier);
      await page.keyboard.down(key);
      let before = null, during = null, afterKeyup = null;
      try {
        before = await selectState(select);
        expect(before.keys).toContainEqual({ key, trusted: true, alt: modifier === 'Alt',
          control: modifier === 'Control', meta: modifier === 'Meta', shift: modifier === 'Shift' });
        receive(render(2, value));
        receive(render(3, value));
        during = await selectState(select);
        // Native change/focusout may already have released this gesture. Otherwise
        // a potential opening key holds the original node, even when ignored natively.
        if (before.open === true || (before.changes === 0 && before.focusouts === 0)) {
          expect(during.connected && during.delivered).toBe(true);
          await expect(page.locator('h1')).toHaveText('Render 1');
        } else {
          await expect(page.locator('h1')).toHaveText('Render 3');
        }
        await page.keyboard.up(key);
        afterKeyup = await selectState(select);
        if (during.delivered && afterKeyup.open === false) {
          // In particular, last-option ArrowDown with no popup must not strand a
          // periodic render when the engine supports select :open.
          await expect(page.locator('h1')).toHaveText('Render 3');
        } else if (during.delivered && afterKeyup.open === null &&
                   afterKeyup.changes === 0 && afterKeyup.focusouts === 0) {
          expect(afterKeyup.connected && afterKeyup.delivered).toBe(true);
          await expect(page.locator('h1')).toHaveText('Render 1');
        } else if (afterKeyup.open === true) {
          expect(afterKeyup.connected && afterKeyup.delivered).toBe(true);
          await expect(page.locator('h1')).toHaveText('Render 1');
        }
      } finally {
        try {
          await testInfo.attach('native-select-observation', { contentType: 'application/json',
            body: JSON.stringify({ key, modifier, before, during, afterKeyup }, null, 2) });
        } finally {
          await page.keyboard.up(key);
          if (modifier) await page.keyboard.up(modifier);
          await page.keyboard.press('Escape');
          // Focusout is the documented fallback when a native popup consumes Escape.
          await page.locator('button[data-cid="after"]').focus();
        }
      }
      await expect(page.locator('h1')).toHaveText('Render 3');
    });
  }
}

test('a pointer-opened native popup retains its delivered select through periodic renders', async ({ page }, testInfo) => {
  const { control, select, receive } = await openSelect(page, 'b');
  await control.click();
  const before = await selectState(select);
  // Where available, :open verifies this really is native-popup coverage.
  if (before.open !== null) expect(before.open).toBe(true);
  receive(render(2));
  receive(render(3));
  const during = await selectState(select);
  expect(during.connected && during.delivered).toBe(true);
  await expect(page.locator('h1')).toHaveText('Render 1');
  if (before.open === true) expect(during.open).toBe(true);
  await testInfo.attach('native-popup-observation', { contentType: 'application/json',
    body: JSON.stringify({ before, during }, null, 2) });
  await page.keyboard.press('Escape');
  await page.locator('button[data-cid="after"]').focus();
  await expect(page.locator('h1')).toHaveText('Render 3');
});

