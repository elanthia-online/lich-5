// Scenario callbacks are inert until the Ruby-owned browser run selects one.

async function runPriority16ComboRebuild({ page, expect }) {
    const combo = page.getByRole('combobox');
    await page.getByRole('button', { name: 'Rebuild combo', exact: true }).click();
    await expect(page.getByText('Selected 1: All', { exact: true })).toBeVisible();
    await expect(combo.locator('option')).toHaveCount(3);
    await expect.poll(() => combo.evaluate(element => element.selectedIndex)).toBe(2);
    await page.getByRole('button', { name: 'Clear combo', exact: true }).click();
    await expect(page.getByText('Cleared -1', { exact: true })).toBeVisible();
    await expect(combo.locator('option')).toHaveCount(1);
    await expect(combo).toHaveValue('none');
}

async function runPriority16SuccessorColumns({ page, expect }) {
    const table = page.getByTitle('Selective expansion', { exact: true });
    const shared = page.getByTitle('Shared expansion', { exact: true });
    const measure = target => target.locator('thead th').evaluateAll(cells => cells.map(cell => cell.getBoundingClientRect().width));
    const widths = () => measure(table);
    await expect.poll(async () => (await widths())[0]).toBeGreaterThan(300);
    await expect.poll(async () => Math.abs(((await measure(shared))[1] - (await measure(shared))[0]) - 40)).toBeLessThan(2);
    const before = await widths();
    const sharedBefore = await measure(shared);
    await page.setViewportSize({ width: 1500, height: 900 });
    await expect.poll(async () => (await widths())[0]).toBeGreaterThan(before[0] + 50);
    expect(Math.abs((await widths())[1] - before[1])).toBeLessThan(2);
    await expect.poll(async () => (await measure(shared))[0]).toBeGreaterThan(sharedBefore[0] + 20);
    const sharedAfter = await measure(shared);
    expect(Math.abs((sharedAfter[0] - sharedBefore[0]) - (sharedAfter[1] - sharedBefore[1]))).toBeLessThan(2);
    expect(Math.abs(sharedAfter[2] - sharedBefore[2])).toBeLessThan(2);
    expect(sharedAfter[2]).toBeGreaterThanOrEqual(150);
    const resize = table.getByRole('separator', { name: 'Resize Skill' });
    await resize.focus();
    await resize.press('ArrowLeft');
    const authored = (await widths())[0];
    await page.setViewportSize({ width: 1600, height: 900 });
    expect(Math.abs((await widths())[0] - authored)).toBeLessThan(2);
    const disabled = table.locator('tbody tr').filter({ hasText: 'Disabled skill' }).locator('td').nth(1);
    await expect(disabled).toHaveAttribute('aria-disabled', 'true');
    await disabled.dblclick();
    await expect(disabled.locator('select')).toHaveCount(0);
    const enabled = table.locator('tbody tr').filter({ hasText: 'Active skill' }).locator('td').nth(1);
    await enabled.dblclick();
    await enabled.locator('select').selectOption('New');
    await expect(enabled).toHaveText('New');
}

async function runPriority15TreeText({ page, expect }) {
    const table = page.getByTitle('Inventory help', { exact: true }).locator('table');
    const header = table.getByRole('columnheader');
    const resize = table.getByRole('separator', { name: 'Resize Custom order' });
    const literal = table.getByRole('cell', { name: '<b>Alpha</b>', exact: true });
    const rowKey = await literal.locator('..').getAttribute('data-row-key');
    await expect(literal).toHaveCSS('color', 'rgb(255, 0, 0)');
    await expect(literal.locator('b')).toHaveCount(0);
    await expect(header).toHaveAttribute('title', 'Custom header help');
    await resize.focus();
    for (let index = 0; index < 20; index++) await resize.press('ArrowLeft');
    expect(await header.evaluate(el => el.getBoundingClientRect().width)).toBeGreaterThanOrEqual(160);
    await page.setViewportSize({ width: 640, height: 700 });
    await table.getByRole('button', { name: 'Custom order', exact: true }).click();
    await expect(table.getByRole('cell').first()).toHaveText('Beta');
    await expect(table.getByRole('cell').last()).toHaveText('Zulu');
    await expect(table.getByRole('cell').last().locator('..')).toHaveAttribute('data-row-key', rowKey);
    await expect(table.getByRole('cell').last()).toHaveCSS('color', 'rgb(255, 0, 0)');
    expect(await header.evaluate(el => el.getBoundingClientRect().width)).toBeGreaterThanOrEqual(240);
    expect(Number(await resize.getAttribute('aria-valuenow'))).toBeGreaterThanOrEqual(240);
    const log = page.getByRole('log');
    const editor = page.locator('textarea');
    await expect(log).toHaveCSS('overflow-wrap', 'anywhere');
    await expect(editor).toHaveCSS('overflow-wrap', 'anywhere');
    expect(await log.evaluate(el => el.scrollWidth <= el.clientWidth + 1)).toBe(true);
    await expect(log).toHaveAttribute('title', 'Wrapped log');
    await page.getByRole('button', { name: 'Disable wrap' }).click();
    await expect(log).toHaveCSS('white-space', 'pre');
    await expect(editor).toHaveAttribute('wrap', 'off');
    expect(await log.evaluate(el => el.scrollWidth > el.clientWidth)).toBe(true);
}

async function runMerchanticalList({ page, expect }) {
    const locked = page.getByRole('button', { name: 'Locked sword', exact: true });
    const unlocked = page.getByRole('button', { name: 'Unlocked gem', exact: true });
    await page.mouse.move(0, 0);
    const crossings = page.getByText(/^Crossings /);
    await locked.hover();
    await expect(crossings).toHaveText('Crossings 1/0');
    // The enter callback redraws the page. A stationary pointer and movement
    // inside the nested label must not manufacture another enter or a leave.
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    const labelBox = await locked.getByText('Locked sword', { exact: true }).boundingBox();
    await page.mouse.move(labelBox.x + labelBox.width / 2 + 1, labelBox.y + labelBox.height / 2);
    await expect(crossings).toHaveText('Crossings 1/0');
    await expect(page.getByText('Recall 0', { exact: true })).toBeHidden();
    await unlocked.hover();
    await expect(crossings).toHaveText('Crossings 1/1');
    await expect(locked).toHaveCSS('opacity', '0.45');
    await expect(unlocked).toHaveCSS('opacity', '0.45');
    const row = unlocked.locator('xpath=../..');
    await expect(row).toHaveCSS('opacity', '0.35');
    await expect(page.getByText('Recall 1', { exact: true })).not.toBeVisible();
    await unlocked.click();
    await expect(page.getByText('Recall 1', { exact: true })).toBeVisible();
    await expect(page.locator('.webui-text-fragment').filter({ hasText: /^Recall 1$/ })).toHaveCSS('font-family', 'monospace');
    await locked.click();
    await expect(page.getByText('Recall 0', { exact: true })).toBeVisible();
    await page.getByRole('textbox').fill('1K');
    await expect(page.getByRole('textbox')).toHaveValue('1K');
    await expect(page.getByText('Found', { exact: true }).first()).toHaveCSS('background-color', 'rgb(60, 156, 60)');
    const spacer = page.getByRole('button', { name: 'Alignment spacer', exact: true });
    await expect(spacer).toHaveCSS('opacity', '0');
    await expect(spacer).toBeDisabled();
    expect((await spacer.boundingBox()).height).toBeGreaterThan(0);
    await page.getByRole('button', { name: 'Remove locked list' }).click();
    await expect(locked).toHaveCount(0);
    await expect(unlocked).toBeVisible();
}

async function runShimModels({ page, expect }) {
    await expect(page.locator('tbody tr')).toHaveCount(1);
    await page.getByRole('button', { name: 'Expand Parent' }).click();
    await expect(page.locator('tbody tr')).toHaveCount(2);
    const childKey = await page.locator('tbody tr').filter({ hasText: 'Child' }).getAttribute('data-row-key');
    const child = page.locator(`tr[data-row-key="${childKey}"]`);
    await child.locator('td').first().click();
    const editor = child.locator('input[type="text"]');
    await editor.fill('Edited child');
    await editor.press('Enter');
    const edited = page.locator('tbody tr').filter({ hasText: 'Edited child' });
    await edited.getByRole('checkbox', { name: 'Enabled' }).check();
    await expect(edited.getByRole('checkbox', { name: 'Enabled' })).toBeChecked();
    await page.locator('.webui-choice-picker select').selectOption({ index: 2 });
    // Choose rows without entering an editor, then retain both across the Save render.
    await edited.click({ position: { x: 2, y: 2 } });
    await page.locator('tbody tr').first().click({ position: { x: 2, y: 2 }, modifiers: ['ControlOrMeta'] });
    await expect(page.locator('tbody tr[aria-selected="true"]')).toHaveCount(2);
    await page.getByRole('button', { name: 'Read models' }).click();
    await expect(page.getByText('Edited child / true / second / true / 2', { exact: true })).toBeVisible();
    await expect(page.locator('tbody tr')).toHaveCount(2);
}

module.exports = [
  { id: 'shim-models', run: runShimModels },
  { id: 'priority16-combo-rebuild', run: runPriority16ComboRebuild },
  { id: 'priority16-successor-columns', run: runPriority16SuccessorColumns },
  { id: 'priority15-tree-text', run: runPriority15TreeText },
  { id: 'merchantical-list', run: runMerchanticalList },
];
