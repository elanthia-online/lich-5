// Scenario callbacks are inert until the Ruby-owned browser run selects one.

async function runNativeBootstrap({ page, expect }) {
    await page.getByRole('button', { name: 'Activate' }).click();
    await expect(page.getByText('Callback received', { exact: true })).toBeVisible();
    // Real line rectangles establish both line justification and placement;
    // checking CSS alone would miss moving the whole label to the wrong edge.
    for (const align of ['start', 'center', 'end']) {
      const geometry = await page.locator(`[data-cid$="text:justified-${align}"]`).evaluate(label => {
        const lines = label.firstElementChild, text = lines.firstChild;
        const range = document.createRange();
        range.setStart(text, 0); range.setEnd(text, 11);
        const first = range.getBoundingClientRect();
        range.setStart(text, 12); range.setEnd(text, 17);
        const second = range.getBoundingClientRect();
        const box = lines.getBoundingClientRect(), outer = label.getBoundingClientRect();
        return { firstRight: first.right, secondRight: second.right, secondTop: second.top, firstTop: first.top,
          left: box.left - outer.left, right: outer.right - box.right };
      });
      expect(Math.abs(geometry.firstRight - geometry.secondRight)).toBeLessThan(1);
      expect(geometry.secondTop).toBeGreaterThan(geometry.firstTop);
      if (align === 'start') expect(geometry.left).toBeLessThan(1);
      if (align === 'end') expect(geometry.right).toBeLessThan(1);
      if (align === 'center') expect(Math.abs(geometry.left - geometry.right)).toBeLessThan(1);
    }
    const wrapped = await page.locator('[data-cid$="text:justified-wrap"]').evaluate(label => {
      const text = label.firstElementChild.firstChild, range = document.createRange();
      const edges = new Map();
      // pre-wrap preserves hanging spaces at a soft break. Measure visible
      // words, since those spaces are not part of the justified ink edge.
      for (const word of text.textContent.matchAll(/\S+/g)) {
        range.setStart(text, word.index); range.setEnd(text, word.index + word[0].length);
        for (const rect of range.getClientRects()) edges.set(rect.top, Math.max(edges.get(rect.top) || 0, rect.right));
      }
      const box = label.getBoundingClientRect();
      return { count: edges.size, right: box.right, edges: [...edges.values()] };
    });
    expect(wrapped.count).toBeGreaterThan(1);
    expect(wrapped.edges.every(right => Math.abs(right - wrapped.right) < 1)).toBe(true);
}

async function runLauncherUnlock({ page, expect }) {
    const dialog = page.getByRole('dialog');
    const password = dialog.locator('input[type="password"]');
    await expect(password).toBeVisible();
    await password.fill('fixture-password');
    await expect(password).toBeFocused();
    await dialog.getByRole('button', { name: 'Unlock', exact: true }).click();
    await expect(dialog).toContainText('Master password was not accepted.');
    await expect(password).toBeEditable();
    await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(dialog).toHaveCount(0);
    await expect(page.getByText('Unlock cancelled')).toBeVisible();
}


/** Exercises real Launcher authorship; optional snapshots compare measured styles across a refactor. */
async function runLauncherPresentation({ page, expect }) {
  const captures = {};
  const measure = async (name, selectors) => {
    captures[name] = await page.evaluate(selectors => Object.fromEntries(Object.entries(selectors).map(([key, selector]) => {
      const element = document.querySelector(selector);
      if (!element) throw new Error(`Missing presentation element: ${key}`);
      const box = element.getBoundingClientRect(), style = getComputedStyle(element);
      return [key, { x: box.x, y: box.y, width: box.width, height: box.height,
        styles: Object.fromEntries(['display', 'minHeight', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft',
          'fontSize', 'fontWeight', 'lineHeight', 'textAlign', 'backgroundColor', 'borderTopWidth', 'gap']
          .map(property => [property, style[property]])) }];
    })), selectors);
  };
  const row = '[data-cid$="group:entry-0"]';
  const rowSelectors = { row, columns: `${row} > .webui-columns`,
    play: `${row} [data-cid$="button:play-entry-0"]`, remove: `${row} [data-cid$="button:remove-entry-0"]`,
    favorite: `${row} [data-cid$="button:favorite-entry-0"]` };
  const play = page.getByRole('button', { name: 'Play Aldor', exact: true });
  await expect(play).toBeVisible();
  await expect(play).toContainText('Aldor');
  await expect(play).toContainText('GS Prime');
  await expect(play).toContainText('Wrayth');
  const segments = play.locator('.webui-text-fragment');
  await expect(segments).toHaveCount(3);
  const boxes = await segments.evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect();
    return { x: rect.x, width: rect.width };
  }));
  expect(Math.abs(boxes[0].width / boxes[1].width - 1.4)).toBeLessThan(0.02);
  expect(Math.abs(boxes[1].width - boxes[2].width)).toBeLessThan(1);
  expect(Math.abs(boxes[0].x + boxes[0].width - boxes[1].x)).toBeLessThan(1);
  expect(Math.abs(boxes[1].x + boxes[1].width - boxes[2].x)).toBeLessThan(1);
  await measure('tabs640', rowSelectors);
  await page.setViewportSize({ width: 480, height: 480 });
  await measure('tabs480', rowSelectors);
  const narrowRow = await page.locator(`${row}:visible`).boundingBox();
  for (const name of ['Play Aldor', 'Remove', 'Unfavorite Aldor']) {
    const box = await page.getByRole('button', { name, exact: true }).boundingBox();
    expect(Math.abs(box.width - narrowRow.width)).toBeLessThan(1);
  }
  await play.click();
  await expect(page.getByText('Synthetic Play received', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Unfavorite Aldor', exact: true }).click();
  await expect(page.getByText('No favorite characters yet.', { exact: true })).toBeVisible();
  await page.getByRole('tab', { name: 'SYNTHETIC', exact: true }).click();
  const favorite = page.getByRole('button', { name: 'Favorite Aldor', exact: true });
  await expect(favorite).toHaveText('\u2606');
  await favorite.click();
  await expect(page.getByRole('button', { name: 'Unfavorite Aldor', exact: true })).toHaveText('\u2605');
  await page.locator('[data-cid$="toggle:gui-settings-toggle"]').click();
  await page.getByRole('checkbox', { name: 'Tab Layout', exact: true }).uncheck();
  await expect(page.getByRole('button', { name: 'Unfavorite Aldor', exact: true })).toHaveCount(0);
  await expect(play).toHaveText('Play Aldor | GS Prime | Wrayth');
  const listSelectors = { ...rowSelectors };
  delete listSelectors.favorite;
  await measure('list480', listSelectors);
  await page.setViewportSize({ width: 640, height: 480 });
  await measure('list640', listSelectors);
  await page.getByRole('tab', { name: 'Account Management', exact: true }).click();
  await measure('nested', { tabs: '[data-cid$="tabs:account-management-tabs"] > .tab-list' });
  await page.getByRole('tab', { name: 'Frontends', exact: true }).click();
  await expect(page.getByRole('textbox', { name: 'Executable override', exact: true })).toBeVisible();
  const formSelectors = { form: '[data-cid$="group:frontend-editor-section"]',
    field: '[data-cid$="text_input:frontend-command"]',
    label: '[data-cid$="text_input:frontend-command"] > .field-label',
    choices: '[data-cid$="columns:frontend-capability-row-0"]', hint: '[data-cid$="text:frontend-detected"]' };
  await measure('form640', formSelectors);
  await page.setViewportSize({ width: 480, height: 480 });
  await measure('form480', formSelectors);
  await page.getByRole('button', { name: 'Add Custom', exact: true }).click();
  await expect(page.getByRole('textbox', { name: 'Stable ID', exact: true })).toBeEditable();
  await expect(page.getByRole('textbox', { name: 'Command', exact: true })).toBeEditable();
  const controls = JSON.parse(process.env.WEBUI_TEST_CONTROLS || '{}');
  if (controls.capture) require('node:fs').writeFileSync(controls.capture, JSON.stringify(captures, null, 2));
}

module.exports = [
  { id: 'launcher-presentation', run: runLauncherPresentation },
  { id: 'launcher-unlock', run: runLauncherUnlock },
  { id: 'native-bootstrap', run: runNativeBootstrap },
];
