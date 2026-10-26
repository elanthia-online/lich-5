// Scenario callbacks are inert until the Ruby-owned browser run selects one.

async function runShimAbyssx({ page, expect }) {
    const controls = JSON.parse(process.env.WEBUI_TEST_CONTROLS);
    await page.locator(`[data-cid="${controls.entry_lootsack}"] input`).fill('browser sack');
    await page.locator(`[data-cid="${controls.entry_spell}"] input`).fill('901');
    await page.getByRole('radio', { name: 'Spam spell', exact: true }).check();
    await expect(page.getByRole('radio', { name: 'Use bigshot quick', exact: true })).not.toBeChecked();
    await page.getByRole('button', { name: 'Save & Close', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimCompass({ page, expect }) {
    const controls = JSON.parse(process.env.WEBUI_TEST_CONTROLS);
    const tattoo = page.locator(`[data-cid="${controls.tattoo}"] input`);
    await tattoo.fill('tattoo;look');
    const save = page.getByRole('button', { name: 'Save', exact: true });
    await save.scrollIntoViewIfNeeded();
    expect(await page.locator('.webui-scroll').evaluate(el => el.scrollHeight > el.clientHeight)).toBe(true);
    await save.click();
    await expect(page.getByText('Enter a tattoo name or one RUB command; no semicolons or extra lines.', { exact: true })).toBeVisible();
    await tattoo.fill('my tattoo');
    await save.click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimElootStance({ page, expect }) {
    const controls = JSON.parse(process.env.WEBUI_TEST_CONTROLS);
    const stance = page.locator(`[data-cid="${controls.stance}"] select`);
    await expect(stance.locator('option:checked')).toHaveText('No change');
    await expect(stance.locator('option')).toHaveCount(8); // Includes the shim's empty selection.
    await stance.selectOption({ label: 'Defensive' });
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimGemstonevDifficulty({ page, expect }) {
    for (const name of ['Easy', 'Medium', 'Hard']) {
      await expect(page.getByRole('button', { name, exact: true })).toBeVisible();
    }
    await page.getByRole('button', { name: 'Easy', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimTpickInformation({ page, expect }) {
    await page.setViewportSize({ width: 1100, height: 850 });
    await page.getByRole('tab', { name: 'Messages', exact: true }).click();
    await expect(page.getByRole('log')).toContainText('Fixture update');
    await page.getByRole('tab', { name: 'Stats', exact: true }).click();
    await page.getByRole('tab', { name: 'Lockpicking', exact: true }).click();
    await expect(page.getByRole('tab', { name: 'Traps', exact: true })).toBeVisible();
    await page.getByRole('tab', { name: 'Settings', exact: true }).click();
    await expect(page.getByRole('button', { name: 'Save', exact: true })).toBeVisible();
    await page.getByRole('tab', { name: 'Main', exact: true }).click();
    await page.getByRole('button', { name: 'Start', exact: true }).click();
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimTpickSettings({ page, expect }) {
    const ids = JSON.parse(process.env.WEBUI_TEST_CONTROLS);
    const entry = page.locator(`[data-cid="${ids.vaalin}"] input`);
    await page.setViewportSize({ width: 1100, height: 850 });
    for (const name of ['Lockpicks', 'Repair', 'Containers', 'Other', 'Rogues Only', 'Spells', 'Experience', 'Speech', 'Popping', 'Pool']) {
      await page.getByRole('tab', { name, exact: true }).click();
      await expect(page.getByRole('tab', { name, exact: true })).toHaveAttribute('aria-selected', 'true');
    }
    await page.getByRole('tab', { name: 'Main', exact: true }).click();
    await page.getByRole('combobox').selectOption({label: 'Second'});
    await page.getByRole('button', { name: 'Load', exact: true }).click();
    await page.getByRole('tab', { name: 'Lockpicks', exact: true }).click();
    await expect(entry).toHaveValue('second pick');
    const grid = entry.locator('xpath=ancestor::*[contains(@class,"webui-grid")][1]');
    await expect(grid).toHaveCSS('display', 'grid');
    const label = page.getByText('2.50 mod (Vaalin Lockpick)', {exact: true});
    const fieldBounds = await entry.boundingBox(), labelBounds = await label.boundingBox();
    expect(Math.abs(fieldBounds.y + fieldBounds.height / 2 - labelBounds.y - labelBounds.height / 2)).toBeLessThan(3);
    expect(fieldBounds.x).toBeGreaterThan(labelBounds.x);

    await expect(page.getByText('2.50 mod (Vaalin Lockpick)', {exact: true})).toHaveCSS('color', 'rgb(255, 77, 77)');
    await page.getByRole('tab', { name: 'Main', exact: true }).click();
    await page.getByRole('button', { name: 'Defaults', exact: true }).click();
    await page.getByRole('tab', { name: 'Lockpicks', exact: true }).click();
    await expect(entry).toHaveValue('');
    await entry.fill('WebKit acceptance pick');
    await page.getByRole('tab', { name: 'Main', exact: true }).click();
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimTpickWelcome({ page, expect }) {
    await expect(page.getByText('WELCOME TO TPICK!', { exact: true })).toBeVisible();
    await expect(page.getByRole('log')).toContainText('Welcome to ;tpick!');
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

module.exports = [
  { id: 'shim-abyssx', run: runShimAbyssx },
  { id: 'shim-compass', run: runShimCompass },
  { id: 'shim-eloot-stance', run: runShimElootStance },
  { id: 'shim-gemstonev-difficulty', run: runShimGemstonevDifficulty },
  { id: 'shim-tpick-information', run: runShimTpickInformation },
  { id: 'shim-tpick-settings', run: runShimTpickSettings },
  { id: 'shim-tpick-welcome', run: runShimTpickWelcome },
];
