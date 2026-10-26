// Scenario callbacks are inert until the Ruby-owned browser run selects one.

async function runShimRepositoryScheduling({ page, expect }) {
    await page.setViewportSize({ width: 1200, height: 650 });
    await page.getByRole('cell', { name: 'alpha.lic', exact: true }).click();
    const download = page.getByRole('button', { name: 'alpha.lic', exact: true });
    await download.click();
    await expect(download).toBeDisabled();
    // An actual ten-second source runs; no test clock or source rewrite.
    await expect(download).toBeEnabled({ timeout: 15_000 });
    await page.getByRole('button', { name: 'Close', exact: true }).click();
}

async function runShimScheduledVisibility({ page, expect }) {
    await page.getByRole('textbox').fill('Retained draft');
    await page.getByRole('button', { name: 'Hide for 2 seconds' }).click();
    await expect(page.locator('.webui-page')).toBeHidden();
    await expect(page.locator('.webui-page')).toBeVisible({ timeout: 6_000 });
    await expect(page.getByRole('textbox')).toHaveValue('Retained draft');
    await page.getByRole('button', { name: 'Finish', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimSail2Scheduling({ page, expect }) {
    const flag = page.getByRole('checkbox', { name: 'Change ship flag when sailing' });
    const color = page.getByRole('combobox');
    await color.selectOption({ label: 'Black' });
    await flag.uncheck();
    await expect(flag).not.toBeChecked();
    await expect(color).toBeDisabled();
    await flag.check();
    await expect(color).toBeEnabled();
    await expect(color.locator('option:checked')).toHaveText('Black');
    await flag.uncheck();
    await expect(color).toBeDisabled();
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimManatimer({ page, expect, wire }) {
    const overlay = page.locator('.webui-overlay');
    const label = overlay.locator('.webui-text');
    const bar = overlay.locator('progress');
    await page.getByRole('button', { name: 'Next tick', exact: true }).click();
    await expect(label).toHaveText('01:00');
    await expect(bar).toHaveJSProperty('value', 0.5);
    await expect(overlay.locator('.webui-progress > span')).toHaveCount(0);
    const bounds = await Promise.all([label.boundingBox(), bar.boundingBox()]);
    expect(bounds[1].height).toBeCloseTo(18, 0);
    expect(Math.abs(bounds[0].y + bounds[0].height / 2 - bounds[1].y - bounds[1].height / 2)).toBeLessThan(2);
    expect(Math.abs(bounds[0].x + bounds[0].width / 2 - bounds[1].x - bounds[1].width / 2)).toBeLessThan(2);
    const center = () => label.boundingBox().then(box => ({ x: box.x + box.width / 2, y: box.y + box.height / 2 }));
    let point = await center();
    await page.mouse.click(point.x, point.y, { button: 'right' });
    await expect.poll(() => page.evaluate(() => window.fixturePresentation.borderless)).toBe(true);
    await page.getByRole('button', { name: 'Toggle pass-through', exact: true }).click();
    await expect(label).not.toHaveAttribute('data-overlay-pass-through', 'true');
    point = await center();
    const presses = wire.filter(entry => entry.includes('->') && entry.includes('event=pointer_press')).length;
    await page.mouse.click(point.x, point.y, { button: 'right' });
    await page.getByRole('button', { name: 'Next tick', exact: true }).click();
    await expect(bar).toHaveJSProperty('value', 0.5);
    expect(wire.filter(entry => entry.includes('->') && entry.includes('event=pointer_press')).length).toBe(presses);
    await expect.poll(() => page.evaluate(() => window.fixturePresentation.borderless)).toBe(true);
    await page.getByRole('button', { name: 'Finish', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function prepareShimManatimer({ page }) {
    // Chrome verifies the existing presentation request; native host behavior is
    // checked separately in the actual macOS WebKit window.
    await page.addInitScript(() => {
      window.fixturePresentation = {};
      window.lichNativeWindow = { present: props => { window.fixturePresentation = props; } };
    });
}

module.exports = [
  { id: 'shim-manatimer', run: runShimManatimer, prepare: prepareShimManatimer },
  { id: 'shim-scheduled-visibility', run: runShimScheduledVisibility },
  { id: 'shim-repository-scheduling', run: runShimRepositoryScheduling },
  { id: 'shim-sail2-scheduling', run: runShimSail2Scheduling },
];
