// Scenario callbacks are inert until the Ruby-owned browser run selects one.

async function runPr64NativeRadio({ page, expect }) {
    await page.getByRole('radio', { name: 'Native second', exact: true }).click();
    await expect(page.getByText('Native true 1', { exact: true })).toBeVisible();
    await page.getByRole('radio', { name: 'Native second', exact: true }).click();
    await expect(page.getByText('Native true 2', { exact: true })).toBeVisible();
    await expect(page.getByRole('radio', { name: 'Native first', exact: true })).not.toBeChecked();
    await expect(page.getByRole('radio', { name: 'Native second', exact: true })).toBeChecked();
}

async function runPriority16Review({ page, expect }) {
    const surface = page.locator('[data-scroll-surface]').filter({ hasText: 'Wheel burst surface' });
    await surface.evaluate(element => {
      for (let index = 0; index < 100; index++) element.dispatchEvent(new WheelEvent('wheel', { deltaY: 2, bubbles: true, cancelable: true }));
    });
    await expect.poll(() => page.locator('.webui-scroll').evaluate(element => element.scrollTop)).toBe(200);
    const cell = page.getByRole('cell', { name: 'Mapped', exact: true });
    await expect(cell).toHaveAttribute('aria-disabled', 'true');
    await cell.dblclick();
    await expect(cell.locator('input')).toHaveCount(0);
    const entry = page.getByPlaceholder('Unsent entry');
    await entry.evaluate(element => { element.value = 'Unsent draft'; });
    await page.getByRole('radio', { name: 'Second plain radio', exact: true }).click();
    await expect(page.getByRole('radio', { name: 'Second plain radio', exact: true })).toBeChecked();
    await expect(page.getByText('Connected', { exact: true })).toBeVisible();
}

async function runPriority16Tooltips({ page, expect }) {
    const tabs = page.locator('.webui-tabs');
    const scroll = page.locator('.webui-scroll');
    await page.getByRole('tab', { name: 'Second', exact: true }).click();
    await expect(page.getByRole('tab', { name: 'Second', exact: true })).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByText('Tooltip content 0', { exact: true })).toBeVisible();
    await scroll.evaluate(element => { element.scrollTop = 70; });
    await expect.poll(() => scroll.evaluate(element => element.scrollTop)).toBe(70);
    await expect(tabs).not.toHaveAttribute('title');
    await expect(scroll).not.toHaveAttribute('title');
    for (const name of ['Assign tooltips', 'Clear tooltips']) {
      await page.getByRole('button', { name, exact: true }).click();
      if (name === 'Assign tooltips') {
        await expect(tabs).toHaveAttribute('title', '<literal help>');
        await expect(scroll).toHaveAttribute('title', '<literal help>');
        await expect(page.locator('literal')).toHaveCount(0);
      } else {
        await expect(tabs).not.toHaveAttribute('title');
        await expect(scroll).not.toHaveAttribute('title');
      }
      await expect(page.getByRole('tab', { name: 'Second', exact: true })).toHaveAttribute('aria-selected', 'true');
      await expect.poll(() => scroll.evaluate(element => element.scrollTop)).toBe(70);
    }
}

async function runPriority16TwoFacades({ page, expect }) {
    await expect(page.getByRole('tab', { name: 'Profession', exact: true })).toHaveCount(0);
    await page.getByRole('button', { name: 'Rebuild choices', exact: true }).click();
    await page.getByRole('combobox').selectOption({ label: 'Rebuilt' });
    await expect(page.locator('.webui-text').filter({ hasText: /^Rebuilt$/ })).toBeVisible();
    await page.getByRole('button', { name: 'Show profession', exact: true }).click();
    await page.getByRole('tab', { name: 'Profession', exact: true }).click();
    await expect(page.getByText('Profession content', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Hide profession', exact: true }).click();
    await expect(page.getByRole('tab', { name: 'Profession', exact: true })).toHaveCount(0);
    await expect(page.getByRole('tab', { name: 'Main', exact: true })).toHaveAttribute('aria-selected', 'true');
}

async function runPriority16HoverChoice({ page, context, expect }) {
    await page.getByText('Hover first', { exact: true }).hover();
    await expect(page.getByText('Hover 1/0', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Refresh hovered box', exact: true }).click();
    await expect(page.getByText('Hover refreshed', { exact: true })).toBeVisible();
    await page.getByText('Hover second', { exact: true }).hover();
    await expect(page.getByText('Hover 1/0', { exact: true })).toBeVisible();
    await page.getByText('Hover 1/0', { exact: true }).hover();
    await expect(page.getByText('Hover 1/1', { exact: true })).toBeVisible();
    const cell = page.getByRole('cell', { name: 'Choice: Original', exact: true });
    await cell.click();
    const control = cell.locator('select');
    await expect(control.locator('option')).toHaveCount(3);
    await control.selectOption({ index: 2 });
    await expect(page.getByText('Choice 99', { exact: true })).toBeVisible();
    await expect(page.getByRole('cell', { name: 'Choice: Duplicate', exact: true })).toBeVisible();
    const other = await context.newPage();
    await other.goto(page.url());
    await other.getByText('Hover refreshed', { exact: true }).hover();
    await expect(other.getByText('Hover 2/1', { exact: true })).toBeVisible();
    await other.getByText('Hover 2/1', { exact: true }).hover();
    await expect(other.getByText('Hover 2/2', { exact: true })).toBeVisible();
    await other.close();
}

async function runPriority16SuccessorControls({ page, expect }) {
    const heading = page.getByText('Group heading', { exact: true });
    const fragment = page.locator('.webui-text-fragment').filter({ hasText: /^Group heading$/ });
    await expect(fragment).toHaveCSS('text-decoration-line', 'underline');
    await expect(fragment).toHaveCSS('font-weight', '700');
    await expect(fragment).toHaveCSS('color', 'rgb(216, 222, 233)');
    await expect(page.locator('.webui-scroll')).toHaveCSS('min-width', '300px');
    await page.getByRole('tab', { name: 'Second', exact: true }).click();
    await expect(page.getByText('Page 1: Second content', { exact: true })).toBeVisible();
    await page.getByRole('tab', { name: 'Second', exact: true }).click();
    await page.getByText('Open choices', { exact: true }).click({ button: 'right' });
    await page.getByRole('menuitem', { name: 'Choices', exact: true }).click();
    await expect(page.getByRole('menuitem', { name: 'Old choice', exact: true })).toBeVisible();
    await page.keyboard.press('Escape');
    await page.keyboard.press('Escape');
    await page.getByRole('button', { name: 'Replace choices', exact: true }).click();
    await page.getByText('Open choices', { exact: true }).click({ button: 'right' });
    const trigger = page.getByRole('menuitem', { name: 'Choices', exact: true });
    await trigger.focus();
    await trigger.press('ArrowRight');
    await expect(page.getByRole('menuitem', { name: 'Old choice', exact: true })).toHaveCount(0);
    await page.getByRole('menuitem', { name: 'New choice', exact: true }).click();
    await expect(page.getByText('New choice activated', { exact: true })).toBeVisible();
}

async function runButtonboxEmptyId({ page, expect }) {
    const save = page.getByRole('button', { name: 'Save & Close', exact: true });
    const cancel = page.getByRole('button', { name: 'Cancel', exact: true });
    const footer = save.locator('..');
    const combo = page.getByRole('combobox');
    const cid = await save.getAttribute('data-cid');
    /**
     * Waits for connected footer geometry without weakening layout tolerances.
     * @param {number} gap Required inter-button spacing in pixels.
     * @returns {Promise<void>} Resolves when both buttons align in the live footer.
     */
    const checkFooter = async gap => {
      await expect.poll(() => footer.evaluate(el => {
        const buttons = [...el.querySelectorAll('button')];
        if (!el.isConnected || buttons.length !== 2) return null;
        const rect = el.getBoundingClientRect();
        const [first, second] = buttons.map(button => button.getBoundingClientRect());
        if (![rect, first, second].every(box => box.width > 0 && box.height > 0)) return null;
        return { count: buttons.length, gap: second.left - first.right, end: rect.right - second.right };
      }).then(sizes => sizes !== null && sizes.count === 2 &&
        Math.abs(sizes.gap - gap) <= 1 && Math.abs(sizes.end) <= 1),
      { message: 'connected footer must retain two buttons, spacing and end alignment' }).toBe(true);
    };
    await expect(combo.locator('option:checked')).toHaveText('-- select spell --');
    await checkFooter(10);
    await page.setViewportSize({ width: 640, height: 480 });
    await checkFooter(10);
    await combo.selectOption({ label: 'Spell' });
    await expect(page.getByText('Choice: "spell"', { exact: true })).toBeVisible();
    await save.focus();
    await save.press('Enter');
    await expect(page.getByText('Saved: "spell"', { exact: true })).toBeVisible();
    await expect(combo.locator('option')).toHaveCount(4);
    await expect(save).toHaveAttribute('data-cid', cid);
    await checkFooter(18);
    await combo.selectOption({ label: '-- select spell --' });
    await expect(page.getByText('Choice: ""', { exact: true })).toBeVisible();
    await combo.selectOption({ label: 'Extra' });
    await expect(page.getByText('Choice: "extra"', { exact: true })).toBeVisible();
    await cancel.click();
    await expect(page.getByText('Reset: ""', { exact: true })).toBeVisible();
    await expect(combo.locator('option:checked')).toHaveText('-- select spell --');
    await checkFooter(18);
}

async function runThreeCompatibility({ page, expect }) {
    const field = page.getByTitle('Fill entry', { exact: true });
    const checkFill = async () => {
      const dimensions = await field.evaluate(el => ({ width: el.getBoundingClientRect().width,
        input: el.querySelector('input').getBoundingClientRect().width, parent: el.parentElement.getBoundingClientRect().width,
        columns: el.style.gridColumn, margin: getComputedStyle(el).marginLeft }));
      expect(dimensions.columns).toContain('span 4');
      expect(dimensions.margin).toBe('40px');
      expect(Math.abs(dimensions.width + 40 - dimensions.parent)).toBeLessThanOrEqual(2);
      expect(Math.abs(dimensions.input - dimensions.width)).toBeLessThanOrEqual(2);
    };
    await expect(field).toBeVisible();
    await checkFill();
    await page.setViewportSize({ width: 900, height: 700 });
    await checkFill();
    await page.setViewportSize({ width: 640, height: 480 });
    const mono = page.getByText('Mono caption', { exact: true });
    await expect(mono).toHaveCSS('font-family', 'monospace');
    const disabled = page.locator('a').filter({ hasText: 'Open wiki' });
    await expect(disabled).not.toHaveAttribute('href');
    await expect(disabled).toHaveAttribute('aria-disabled', 'true');
    await page.getByRole('button', { name: 'Select spell', exact: true }).click();
    const active = page.getByRole('link', { name: 'Open selected wiki' });
    await expect(active).toHaveAttribute('href', 'https://example.invalid/spell');
    await active.evaluate(el => el.addEventListener('click', event => {
      event.preventDefault(); el.dataset.keyboardActivated = 'true';
    }));
    await active.focus();
    await active.press('Enter');
    await expect(active).toHaveAttribute('data-keyboard-activated', 'true');
    await page.getByRole('button', { name: 'Clear selection', exact: true }).click();
    await expect(page.locator('a').filter({ hasText: 'Open selected wiki' })).not.toHaveAttribute('href');
    const up = page.getByRole('button', { name: 'Up', exact: true });
    const down = page.getByRole('button', { name: 'Down', exact: true });
    await expect(up).toBeDisabled();
    await down.click();
    await expect(page.getByText('Second, First', { exact: true })).toBeVisible();
    await expect(down).toBeDisabled();
    await up.click();
    await expect(page.getByText('First, Second', { exact: true })).toBeVisible();
    await expect(up).toBeDisabled();
}

async function runPriority14Controls({ page, expect }) {
    const profileMargin = page.locator('input[title="Profile name"], [title="Profile name"] input').first();
    await expect(profileMargin).toHaveCSS('margin-left', '12px');
    await expect(profileMargin).toHaveCSS('margin-top', '3px');
    await expect(page.locator('.webui-stack[title="Container help"]')).toBeVisible();
    await expect(page.locator('.webui-grid[title="Horizontal help"]')).toBeVisible();

    const profile = page.getByTitle('Profile name', { exact: true });
    await expect(profile.locator('.webui-editable-select')).toHaveCSS('width', '400px');
    await expect(profile.locator('input')).toHaveValue('Profile A');
    await expect(page.getByTitle('Material help').locator('option:checked')).toHaveText('bronze');
    await page.getByRole('button', { name: 'Update controls', exact: true }).click();
    const updated = page.getByTitle('Updated profile', { exact: true });
    await expect(updated.locator('.webui-editable-select')).toHaveCSS('width', '320px');
    await expect(updated.locator('input')).toHaveValue('Profile A');
    await expect(updated.locator('input')).toHaveCSS('margin-left', '0px');
    await expect(updated).toHaveCSS('margin-left', '20px');
    await expect(page.getByTitle('Material help').locator('option:checked')).toHaveText('iron');
    await expect(page.getByText('Updated profile / iron', { exact: true })).toBeVisible();
}

async function runPriority11Labels({ page, expect }) {
    const mixed = page.locator('.webui-text').filter({ hasText: 'Attack  (optional)' });
    await expect(mixed).toBeVisible();
    await expect(mixed.locator('.webui-text-fragment').first()).toHaveCSS('font-weight', '700');
    await expect(mixed.locator('.webui-text-fragment').last()).toHaveCSS('font-style', 'italic');
    const warning = page.locator('.webui-text-fragment').filter({ hasText: 'Cleric-only' });
    await expect(warning).toHaveCSS('color', 'rgb(255, 191, 64)');
    expect(await warning.evaluate(el => el.style.fontSize)).toBe('1.2em');
    const bonus = page.getByLabel('A long service bonus description '.repeat(8), { exact: true });
    await expect(bonus).toHaveCSS('text-overflow', 'ellipsis');
    expect(await bonus.evaluate(el => el.scrollWidth > el.clientWidth)).toBe(true);
    await page.getByRole('button', { name: 'Reset label', exact: true }).click();
    const plain = page.getByText('Plain replacement', { exact: true });
    await expect(plain).toBeVisible();
    await expect(plain.locator('.webui-text-fragment')).toHaveCount(0);
}

async function runContractInputs({ page, expect }) {
    const volume = page.getByRole('slider', { name: 'Volume', exact: true });
    await volume.focus();
    await volume.press('ArrowRight');
    await expect(volume).toHaveValue('2.5');
    const notes = page.getByRole('textbox', { name: 'Notes 0', exact: true });
    for (const character of ['a', '\u{1f512}', '\u0000']) {
      await notes.fill(character.repeat(65536));
      await expect(notes).toHaveValue(character.repeat(65536));
    }
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await expect(page.getByText('Saved 1', { exact: true })).toBeVisible();
    for (const index of [0, 1, 2]) await page.getByRole('textbox', { name: `Notes ${index}`, exact: true }).fill('\u0000'.repeat(65536));
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await expect(page.getByText(/This change is too large to send/)).toBeVisible();
    await expect(notes).toHaveValue('\u0000'.repeat(65536));
    await expect(page.getByText('Saved 1', { exact: true })).toBeVisible();
    for (const index of [0, 1, 2]) await page.getByRole('textbox', { name: `Notes ${index}`, exact: true }).fill('smaller');
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await expect(page.getByText('Saved 2', { exact: true })).toBeVisible();
}

async function runShimControls({ page, expect }) {
    const first = page.getByRole('radio', { name: 'First' });
    const second = page.getByRole('radio', { name: 'Second' });
    await expect(first).toBeChecked();
    await second.check();
    await expect(first).not.toBeChecked();
    await expect(second).toBeChecked();
    const toggle = page.getByRole('button', { name: 'Enabled' });
    await toggle.click();
    await expect(toggle).toHaveAttribute('aria-pressed', 'true');
    const spin = page.getByRole('spinbutton');
    await expect(spin).toHaveValue('0.5');
    await spin.fill('2.75');
    await page.getByRole('button', { name: 'Increase' }).click();
    await expect(spin).toHaveValue('2.9');
    await page.getByRole('searchbox').fill('query');
    await page.locator('summary', { hasText: 'Details' }).click();
    const text = page.locator('textarea');
    await expect(text).toBeVisible();
    await text.focus();
    // Force a server redraw without moving focus or depending on delivery timing.
    // Ruby must receive only the later, genuine blur when Details is collapsed.
    await page.getByRole('button', { name: 'Redraw fixture' }).evaluate(button => button.click());
    await expect(page.getByText('Redraw received', { exact: true })).toBeVisible();
    await expect(text).toBeFocused();
    await text.fill('line one\nline two');
    await page.locator('summary', { hasText: 'Details' }).click();
    await expect(text).not.toBeVisible();
    const image = page.locator('img[title="Fixture image"]');
    await expect(image).toBeVisible();
    await expect.poll(() => image.evaluate(element => element.naturalWidth)).toBe(1);
    const actions = page.getByText('Actions', { exact: true });
    await actions.click({ button: 'right' });
    const menuCheck = page.getByRole('menuitemcheckbox', { name: 'Menu enabled' });
    await expect(menuCheck).toBeFocused();
    // Real browser key activation complements DOM tests, which cannot synthesize
    // the browser's default Enter/Space click behavior.
    await page.keyboard.press('Space');
    await actions.click({ button: 'right' });
    await expect(menuCheck).toHaveAttribute('aria-checked', 'true');
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitem', { name: 'Choices', exact: true })).toBeFocused();
    await page.keyboard.press('ArrowRight');
    await expect(page.getByRole('menuitemradio', { name: 'Menu first' })).toBeFocused();
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitemradio', { name: 'Menu second' })).toBeFocused();
    await page.keyboard.press('Enter');
    await actions.click({ button: 'right' });
    await page.getByRole('menuitem', { name: 'Choices', exact: true }).click();
    await expect(page.getByRole('menuitemradio', { name: 'Menu first' })).toHaveAttribute('aria-checked', 'false');
    await expect(page.getByRole('menuitemradio', { name: 'Menu second' })).toHaveAttribute('aria-checked', 'true');
    await page.keyboard.press('Escape');
    await page.getByRole('menuitem', { name: 'Clear image', exact: true }).click();
    await expect(image).not.toBeVisible();
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await expect(spin).toHaveCount(0);
}

async function runShimEntry({ page, expect, scenario }) {
    const entry = page.getByRole('textbox');
    await expect(entry).toHaveValue('');
    if (scenario === 'shim-entry') {
      const checkbox = page.getByRole('checkbox', { name: 'Shim checked' });
      await expect(checkbox).not.toBeChecked();
      await checkbox.check();
      await expect(checkbox).toBeChecked();
      await entry.fill('retained draft');
      await page.getByRole('button', { name: 'Toggle editing', exact: true }).click();
      await expect(entry).not.toBeEditable();
      await expect(entry).toHaveValue('retained draft');
      await page.getByRole('button', { name: 'Toggle editing', exact: true }).click();
      await expect(entry).toBeEditable();
      await expect(entry).toHaveValue('retained draft');
      await entry.fill('saved while locked');
      await page.getByRole('button', { name: 'Toggle editing', exact: true }).click();
      await expect(entry).not.toBeEditable();
      await expect(entry).toHaveValue('saved while locked');
      await page.getByRole('button', { name: 'Save', exact: true }).click();
    } else {
      const divider = page.locator('.webui-divider');
      await expect(divider).toBeVisible();
      await expect(divider).toHaveCSS('border-top-width', '1px');
      await expect(divider).toHaveCSS('margin-top', '0px');
      await expect(divider).toHaveCSS('margin-bottom', '0px');
      await entry.fill('shim separator');
      await entry.press('Enter');
    }
    await expect(entry).toHaveCount(0);
}

module.exports = [
  { id: 'shim-entry', run: runShimEntry },
  { id: 'shim-separator', run: runShimEntry },
  { id: 'shim-controls', run: runShimControls },
  { id: 'pr64-native-radio', run: runPr64NativeRadio },
  { id: 'priority14-controls', run: runPriority14Controls },
  { id: 'priority11-labels', run: runPriority11Labels },
  { id: 'priority16-tooltips', run: runPriority16Tooltips },
  { id: 'priority16-two-facades', run: runPriority16TwoFacades },
  { id: 'priority16-hover-choice', run: runPriority16HoverChoice },
  { id: 'priority16-successor-controls', run: runPriority16SuccessorControls },
  { id: 'priority16-review', run: runPriority16Review },
  { id: 'contract-inputs', run: runContractInputs },
  { id: 'three-compatibility', run: runThreeCompatibility },
  { id: 'buttonbox-empty-id', run: runButtonboxEmptyId },
];
