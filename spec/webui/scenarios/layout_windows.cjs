// Scenario callbacks are inert until the Ruby-owned browser run selects one.

async function runPriority15Notebook({ page, expect }) {
    const main = page.getByRole('tab', { name: 'Main', exact: true });
    const bag = page.getByRole('tab', { name: 'Bag', exact: true });
    await expect(main).toHaveCSS('color', 'rgb(255, 0, 0)');
    await bag.click({ button: 'middle' });
    await expect(page.getByText('Bag middle command', { exact: true })).toBeVisible();
    await expect(main).toHaveAttribute('aria-selected', 'true');
    await bag.click();
    await expect(bag).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByText('Bag contents', { exact: true })).toBeVisible();
    await main.focus(); await main.press('Enter');
    await expect(main).toHaveAttribute('aria-selected', 'true');
    await bag.click({ button: 'right' });
    await expect(bag).toHaveCount(0);
    await expect(page.getByText('Bag closed', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Green tab', exact: true }).click();
    await expect(main).toHaveCSS('color', 'rgb(0, 255, 0)');
    await page.getByRole('button', { name: 'Reopen bag', exact: true }).click();
    await expect(bag).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByText('Bag contents', { exact: true })).toBeVisible();
    await main.click({ button: 'middle' });
    await expect(page.getByText('Main middle command', { exact: true })).toBeVisible();
    await expect(bag).toHaveAttribute('aria-selected', 'true');
    await main.click({ button: 'right' });
    await expect(bag).toHaveCount(0);
    await expect(main).toHaveAttribute('aria-selected', 'true');
    await expect(main).toHaveCSS('color', 'rgb(0, 255, 0)');
}

async function runPriority15Followup({ page, expect }) {
    const split = page.locator('.webui-split');
    const divider = split.locator(':scope > .split-handle');
    const table = split.locator('table');
    const allowed = table.getByRole('row').filter({ has: page.getByRole('cell', { name: 'Allowed', exact: true }) });
    const denied = table.getByRole('row').filter({ has: page.getByRole('cell', { name: 'Denied', exact: true }) });
    const failing = table.getByRole('row').filter({ has: page.getByRole('cell', { name: 'Failing', exact: true }) });
    // Resolve and measure in one task, then wait for the requested 1000 - 700
    // - 1 pixel allocation. A visible pane can still precede its first RAF.
    const rightWidth = () => page.evaluate(() => document.querySelector('.webui-split > .split-pane:last-child')?.getBoundingClientRect().width ?? 0);
    await expect.poll(async () => Math.abs(await rightWidth() - 299)).toBeLessThanOrEqual(2);
    const initial = await rightWidth();
    await allowed.click();
    await expect(allowed).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByText('Accepted: Allowed', { exact: true })).toBeVisible();
    await denied.click();
    await expect(denied).toHaveAttribute('aria-selected', 'false');
    await expect(allowed).toHaveAttribute('aria-selected', 'true');
    await failing.click();
    await expect(failing).toHaveAttribute('aria-selected', 'false');
    await expect(allowed).toHaveAttribute('aria-selected', 'true');
    await expect.poll(async () => Math.abs(await rightWidth() - initial)).toBeLessThanOrEqual(2);
    await page.setViewportSize({ width: 1100, height: 700 });
    await expect.poll(async () => Math.abs(await rightWidth() - initial)).toBeLessThanOrEqual(2);
    await divider.focus();
    await divider.press('ArrowLeft');
    await expect.poll(rightWidth).toBeGreaterThan(initial + 2);
    const dragged = await rightWidth();
    await page.setViewportSize({ width: 1000, height: 650 });
    await expect.poll(async () => Math.abs(await rightWidth() - dragged)).toBeLessThanOrEqual(2);
}

async function runFrameScroller({ page, expect }) {
    const frame = page.locator('fieldset.webui-group');
    const field = page.getByTitle('Draft entry', { exact: true });
    const entry = field.locator('input');
    const cid = await field.getAttribute('data-cid');
    await expect(frame.locator('legend')).toHaveText('Initial frame');
    await expect(frame).toHaveCSS('border-top-width', '1px');
    await entry.fill('Retained draft');
    await page.getByRole('button', { name: 'Rename frame', exact: true }).click();
    await expect(frame.locator('legend')).toHaveText('Updated frame');
    await expect(entry).toHaveValue('Retained draft');
    await expect(field).toHaveAttribute('data-cid', cid);
    await page.getByRole('button', { name: 'Remove border', exact: true }).click();
    await expect(frame).toHaveCSS('border-top-width', '0px');
    await expect(frame).toHaveAttribute('data-borderless', 'true');
    await page.getByRole('button', { name: 'Restore border', exact: true }).click();
    await expect(frame).toHaveCSS('border-top-width', '1px');
    await expect(frame).not.toHaveAttribute('data-borderless');
    await page.getByRole('button', { name: 'Empty caption', exact: true }).click();
    await expect(frame.locator('legend')).toHaveCount(0);
    await expect(frame).toHaveAttribute('data-empty-label', 'true');
    await expect(entry).toHaveValue('Retained draft');
    await entry.press('Enter');
    await expect(page.getByText('Submitted: Retained draft', { exact: true })).toBeVisible();
}

async function runShimGeometryCursors({ page, expect }) {
    for (const name of ['pointer', 'cell', 'copy']) {
      await page.getByRole('button', { name: name[0].toUpperCase() + name.slice(1), exact: true }).click();
      await expect(page.getByText(`Cursor: ${name}`, { exact: true })).toBeVisible();
      await expect(page.getByRole('button', { name: 'Measure screen', exact: true })).toHaveCSS('cursor', name);
    }
    await page.getByRole('button', { name: 'Reset cursor' }).click();
    await expect(page.getByText('Cursor: inherited', { exact: true })).toBeVisible();
    await expect(page.locator('.webui-page')).not.toHaveAttribute('data-cursor-hint');
    await page.getByRole('button', { name: 'Measure screen' }).click();
    await expect(page.getByText(/^Screen: \d+ x \d+ \(browser\)$/)).toBeVisible();
    await page.getByRole('button', { name: 'Finish', exact: true }).click();
}

async function runShimLayout({ page, expect }) {
    const hidden = page.getByRole('button', { name: 'Offscreen', exact: true });
    const canvas = page.locator('.webui-overlay');
    await expect(canvas).toHaveCSS('overflow', 'hidden');
    await expect.poll(async () => canvas.evaluate(el => el.offsetHeight)).toBeGreaterThan(80);
    const clipped = await hidden.evaluate(el => {
      const box = el.getBoundingClientRect();
      const hit = document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2);
      return !hit || hit.closest('button') !== el;
    });
    expect(clipped).toBe(true);
    await page.getByRole('button', { name: 'Move into canvas', exact: true }).click();
    await expect(hidden).toHaveCSS('left', '100px');
    await expect.poll(() => hidden.evaluate(el => {
      const box = el.getBoundingClientRect();
      return document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2)?.closest('button') === el;
    })).toBe(true);
}

async function runShimFixedEventsFocus({ page, expect }) {
    const first = page.getByPlaceholder('First field'), second = page.getByPlaceholder('Second field');
    await expect(first).toBeFocused();
    const surface = page.getByText('Pointer surface', { exact: true });
    const root = page.locator('.webui-overlay');
    const position = async (target, x, y) => {
      const outer = await root.boundingBox(), child = await target.boundingBox();
      expect(child.x - outer.x).toBeCloseTo(x, 0);
      expect(child.y - outer.y).toBeCloseTo(y, 0);
      await expect.poll(async () => {
        const measured = await root.boundingBox(), contents = await target.boundingBox();
        return measured.width - (contents.x - measured.x + contents.width);
      }).toBeGreaterThanOrEqual(-1);
      await expect.poll(async () => {
        const measured = await root.boundingBox(), contents = await target.boundingBox();
        return measured.height - (contents.y - measured.y + contents.height);
      }).toBeGreaterThanOrEqual(-1);
    };
    await position(surface, 300, 0);
    await second.fill('Changed second');
    await expect(page.getByText('Edited second', { exact: true })).toBeVisible();
    await expect(second).toBeFocused();
    await surface.click();
    const clicked = page.getByText('Pointer 1', { exact: true });
    await expect(clicked).toBeVisible();
    await position(clicked, 350, 40);
    await page.getByRole('button', { name: 'Refocus', exact: true }).click();
    await expect(first).toBeFocused();
    await page.getByRole('button', { name: 'Finish', exact: true }).click();
    await expect(first).toHaveCount(0);
}

async function runShimHeaderbar({ page, expect }) {
    const title = page.getByText('Header actions', { exact: true });
    const close = page.getByRole('button', { name: 'Close', exact: true });
    const entry = page.getByRole('textbox');
    await expect(title).toBeVisible();
    const titleBounds = await title.boundingBox();
    const closeBounds = await close.boundingBox();
    const contentBounds = await entry.boundingBox();
    expect(Math.abs(titleBounds.y - closeBounds.y)).toBeLessThan(25);
    expect(contentBounds.y).toBeGreaterThan(titleBounds.y);
    await page.getByRole('button', { name: 'Header action', exact: true }).click();
    await expect(page.getByText('Header action worked', { exact: true })).toBeVisible();
    await entry.fill('Unsaved draft');
    await close.click();
    await expect(page.getByText('Close vetoed', { exact: true })).toBeVisible();
    await expect(entry).toHaveValue('Unsaved draft');
    await close.click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runMerchanticalHelpWindow({ page, context, expect }) {
    const parentInput = page.getByPlaceholder('Parent draft');
    await parentInput.fill('Retained parent input');
    for (let cycle = 0; cycle < 2; cycle++) {
      await page.getByRole('button', { name: 'Open help', exact: true }).click();
      const address = (await page.getByText(/^Help page: /).textContent()).replace('Help page: ', '');
      const url = new URL(page.url()); url.searchParams.set('page', address);
      const help = await context.newPage();
      await help.goto(url.href);
      await expect(help.getByText('Help heading', { exact: true })).toBeVisible();
      const scroll = help.locator('.webui-scroll');
      const log = help.locator('.webui-log');
      await expect(log).toHaveCSS('padding-left', '4px');
      await expect(scroll).toHaveJSProperty('scrollTop', 0);
      await expect.poll(() => scroll.evaluate(element => element.scrollHeight > element.clientHeight)).toBe(true);
      await scroll.evaluate(element => { element.scrollTop = 160; });
      await expect.poll(() => scroll.evaluate(element => element.scrollTop)).toBe(160);
      await help.getByRole('button', { name: 'Refresh help' }).click();
      await expect(help.getByText('Help refreshed', { exact: true })).toBeVisible();
      await expect(scroll).toHaveJSProperty('scrollTop', 160);
      await page.getByRole('button', { name: 'Refresh parent' }).click();
      await expect(parentInput).toHaveValue('Retained parent input');
      await help.getByRole('button', { name: 'Follow end' }).click();
      await expect.poll(() => scroll.evaluate(element => element.scrollTop + element.clientHeight >= element.scrollHeight - 1)).toBe(true);
      await help.getByRole('button', { name: 'Close help' }).click();
      await expect(help.locator('.webui-log')).toHaveCount(0);
      await help.close();
      await expect(parentInput).toHaveValue('Retained parent input');
    }
}

async function runNativeTabRedraw({ page, expect }) {
    await page.getByRole('tab', { name: 'Two', exact: true }).click();
    await expect(page.getByRole('tab', { name: 'Two', exact: true })).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByText('Second panel', { exact: true })).toBeVisible();
    await expect(page.getByText('First panel', { exact: true })).toBeHidden();
}

async function runNativeNotebookActions({ page, expect }) {
    const notebook = page.locator('[data-component-type="tabs"]');
    const help = page.getByRole('button', { name: 'Native help', exact: true });
    await expect(notebook).toHaveAttribute('data-size-to-all', 'true');
    const panels = notebook.locator(':scope > .tab-panel');
    await expect(panels).toHaveCount(2);
    await expect(panels.nth(0)).toHaveAttribute('inert', '');
    expect((await panels.nth(1).boundingBox()).height).toBeGreaterThanOrEqual(240);
    await expect(help).toBeVisible();
    await help.click();
    await expect(page.getByText('Native help activated', { exact: true })).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Two', exact: true })).toHaveAttribute('aria-selected', 'true');
    await page.getByRole('button', { name: 'Switch tab layout' }).click();
    await expect(notebook).toHaveClass(/account-tabs-left/);
    const header = notebook.locator(':scope > .tab-header');
    const headerBox = await header.boundingBox();
    const panelBox = await panels.nth(1).boundingBox();
    expect(headerBox.x + headerBox.width).toBeLessThanOrEqual(panelBox.x + 1);
    await expect(help).toBeVisible();
    await expect(notebook.getByRole('tab')).toHaveCount(2);
}

async function runMerchanticalNotebookActions({ page, expect }) {
    const tabs = page.getByRole('tab');
    const help = page.getByRole('button', { name: 'Shop help', exact: true });
    await expect(tabs).toHaveCount(4);
    await expect(page.getByRole('tablist').getByRole('button')).toHaveCount(0);
    await expect(help).toHaveAttribute('title', 'Help on every page');
    for (let index = 0; index < 4; index++) {
      await tabs.nth(index).click();
      await expect(tabs.nth(index)).toHaveAttribute('aria-selected', 'true');
      await help.click();
      await expect(page.getByText(`Help ${index + 1}`, { exact: true })).toBeVisible();
      await expect(tabs.nth(index)).toHaveAttribute('aria-selected', 'true');
    }
    const cid = await help.getAttribute('data-cid');
    await page.getByRole('button', { name: 'Replace help', exact: true }).click();
    await expect(help).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Replacement', exact: true })).toBeVisible();
    await expect(tabs.nth(3)).toHaveAttribute('aria-selected', 'true');
    await page.getByRole('button', { name: 'Restore help', exact: true }).click();
    await expect(help).toHaveAttribute('data-cid', cid);
    await help.focus(); await page.keyboard.press('Enter');
    await expect(page.getByText('Help 5', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Toggle help sensitivity' }).click();
    await expect(help).toBeDisabled();
    await page.getByRole('button', { name: 'Toggle help sensitivity' }).click();
    await expect(help).toBeEnabled();
    await page.getByRole('button', { name: 'Toggle help visibility' }).click();
    await expect(help).toBeHidden();
    await page.getByRole('button', { name: 'Toggle help visibility' }).click();
    await expect(help).toBeVisible();
    await page.getByRole('button', { name: 'Toggle selectors' }).click();
    await expect(help).toBeHidden();
    await expect(page.getByText('Ledger content', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Toggle selectors' }).click();
    await expect(help).toBeVisible();
    await page.getByRole('button', { name: 'Remove first page' }).click();
    await expect(tabs).toHaveCount(3);
    await expect(page.getByRole('tab', { name: 'Ledger', exact: true })).toHaveAttribute('aria-selected', 'true');
    await expect(help).toHaveAttribute('data-cid', cid);
    await page.setViewportSize({ width: 480, height: 760 });
    await expect(help).toBeInViewport();
}

async function runPriority17TitleScroll({ page, expect }) {
    const spans = page.locator('.webui-text-fragment');
    await expect(spans).toHaveCount(3);
    await expect(spans.nth(0)).toHaveCSS('font-size', '24px');
    await expect(spans.nth(1)).toHaveText('COMBATICAL');
    await expect(spans.nth(1)).toHaveCSS('font-size', /29\.33/);
    await expect(spans.nth(1)).toHaveCSS('font-weight', '900');
    await expect(spans.nth(1)).toHaveCSS('letter-spacing', '4px');
    await expect(spans.nth(1)).toHaveCSS('color', 'rgb(212, 175, 55)');
    const scroller = page.locator('[data-component-type="scroll"]');
    await scroller.evaluate(element => { element.scrollTop = 200; });
    await expect.poll(() => scroller.evaluate(element => element.scrollTop)).toBeGreaterThan(0);
    const offset = await scroller.evaluate(element => element.scrollTop);
    await page.getByRole('button', { name: 'Toggle overlay preference' }).click();
    await expect(page.getByText('Overlay false', { exact: true })).toBeVisible();
    await expect.poll(() => scroller.evaluate(element => element.scrollTop)).toBe(offset);
    await page.getByRole('button', { name: 'Reset title' }).click();
    await expect(page.getByText('Plain replacement', { exact: true })).toBeVisible();
    await expect(spans).toHaveCount(0);
}

module.exports = [
  { id: 'shim-layout', run: runShimLayout },
  { id: 'shim-fixed-events-focus', run: runShimFixedEventsFocus },
  { id: 'frame-scroller', run: runFrameScroller },
  { id: 'priority15-notebook', run: runPriority15Notebook },
  { id: 'priority15-followup', run: runPriority15Followup },
  { id: 'native-tab-redraw', run: runNativeTabRedraw },
  { id: 'native-notebook-actions', run: runNativeNotebookActions },
  { id: 'merchantical-notebook-actions', run: runMerchanticalNotebookActions },
  { id: 'merchantical-help-window', run: runMerchanticalHelpWindow },
  { id: 'priority17-title-scroll', run: runPriority17TitleScroll },
  { id: 'shim-geometry-cursors', run: runShimGeometryCursors },
  { id: 'shim-headerbar', run: runShimHeaderbar },
];
