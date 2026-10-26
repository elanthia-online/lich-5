// Scenario callbacks are inert until the Ruby-owned browser run selects one.

async function runShimRepository({ page, expect, scenario }) {
    const ids = JSON.parse(process.env.WEBUI_TEST_CONTROLS);
    const widget = name => page.locator(`[data-cid="${ids[name]}"]`);
    if (scenario === 'shim-repository') {
      // The script requests an 800px list plus its comments pane; headless
      // Chrome cannot honor the renderer's native window resize request.
      await page.setViewportSize({ width: 1200, height: 650 });
      await expect(page.getByRole('tab')).toHaveCount(0);
      const table = widget('repository');
      await expect(table.locator('tbody tr')).toHaveCount(42);
      const listScroll = table.locator('..');
      const heading = table.locator('th').first();
      const headerTop = (await heading.boundingBox()).y;
      await listScroll.evaluate(element => { element.scrollTop = 300; });
      await expect.poll(async () => Math.abs((await heading.boundingBox()).y - headerTop)).toBeLessThan(2);
      await listScroll.evaluate(element => { element.scrollTop = 0; });
      const lastHeader = table.locator('th').last();
      const grip = lastHeader.getByRole('separator', { name: 'Resize Tags' });
      // Do not scroll or focus the edge into view: the first display must expose
      // the last column and its actual mouse target, even with long cell text.
      await expect.poll(() => grip.evaluate(element => {
        const rect = element.getBoundingClientRect();
        return document.elementFromPoint(rect.x + rect.width / 2, rect.y + 10) === element;
      })).toBe(true);
      expect(await listScroll.evaluate(element => element.scrollLeft)).toBe(0);
      const oldWidth = (await lastHeader.boundingBox()).width;
      const edge = await grip.boundingBox();
      await page.mouse.move(edge.x + edge.width / 2, edge.y + 10);
      await page.mouse.down();
      await page.mouse.move(edge.x + edge.width / 2 + 30, edge.y + 10, { steps: 6 });
      await page.mouse.up();
      expect((await lastHeader.boundingBox()).width).toBeGreaterThan(oldWidth + 28);
      await grip.focus();
      await grip.press('ArrowRight');
      const resizedWidth = (await lastHeader.boundingBox()).width;
      expect(resizedWidth).toBeGreaterThan(oldWidth + 38);
      await listScroll.evaluate(element => { element.scrollLeft = 0; });
      await table.getByRole('button', { name: 'Size', exact: true }).click();
      await expect(table.locator('tbody tr').first()).toContainText('zeta.lic');
      await table.getByText('zeta.lic', { exact: true }).click();
      await expect(widget('comments')).toHaveText('');
      const search = widget('search_entry').locator('input');
      await search.click();
      await search.pressSequentially('Dreaven', { delay: 480 });
      await expect(search).toHaveValue('Dreaven');
      await expect(table.locator('tbody tr')).toHaveCount(1);
      expect(await search.evaluate(element => element.selectionStart)).toBe(7);
      expect((await lastHeader.boundingBox()).width).toBeCloseTo(resizedWidth, 0);
      await widget('search_entry').fill('travel');
      await expect(table.locator('tbody tr')).toHaveCount(1);
      await table.getByText('alpha.lic', { exact: true }).click();
      await expect(widget('comments')).toHaveText('Alpha comments Dreaven' + ' more details.'.repeat(1000));
      const commentsScroll = widget('comments').locator('xpath=ancestor::*[contains(concat(" ", normalize-space(@class), " "), " webui-scroll ")][1]');
      expect((await commentsScroll.boundingBox()).height).toBeLessThanOrEqual(510);
      expect(Math.abs((await listScroll.boundingBox()).y - (await commentsScroll.boundingBox()).y)).toBeLessThan(2);
      await commentsScroll.evaluate(element => { element.scrollTop = element.scrollHeight; });
      expect(await commentsScroll.evaluate(element => element.scrollTop)).toBeGreaterThan(1000);
      await expect(widget('download_link')).toHaveText('alpha.lic');
      await widget('download_link').click();
    } else {
      const fragments = page.getByText('Minimum fragments before using', { exact: true });
      if (await widget('portals_passes_frame').isVisible()) {
        await expect(fragments).toBeVisible();
        await fragments.scrollIntoViewIfNeeded();
        const heading = page.getByText('Hinterwilds Travel Options', { exact: true });
        expect(Math.abs((await fragments.boundingBox()).x - (await heading.boundingBox()).x)).toBeLessThan(2);
      }
      await widget('delay').fill('7');
      await widget('echo_input').uncheck();
    }
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimHuntplan({ page, expect }) {
    const ids = JSON.parse(process.env.WEBUI_TEST_CONTROLS);
    const widget = name => page.locator(`[data-cid="${ids[name]}"]`);
    await expect(page.getByRole('tab')).toHaveCount(0);
    await widget('default_profile').fill('fixture-default');
    await widget('bounty_profile').fill('fixture-bounty');
    const slot = widget('ebounty_slot').locator('input');
    await slot.fill('');
    await slot.pressSequentially('zz');
    await expect(slot).toHaveValue('z');
    await page.getByRole('button', { name: 'Save & Exit', exact: true }).click();
    await expect(widget('status_label')).toHaveText('invalid ebounty profile slot: z');
    await slot.fill('j');
    await page.getByRole('button', { name: 'Save & Exit', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimEbounty({ page, expect, scenario, __dirname }) {
    const ids = JSON.parse(process.env.WEBUI_TEST_CONTROLS);
    const widget = name => page.locator(`[data-cid="${ids[name]}"]`);
    const reveal = async name => {
      const parents = await widget(name).evaluate(element => {
        const result = [];
        for (let panel = element.closest('[role="tabpanel"]'); panel; panel = panel.parentElement.closest('[role="tabpanel"]')) {
          result.unshift({ cid: panel.parentElement.dataset.cid,
            index: [...panel.parentElement.children].filter(child => child.matches('[role="tabpanel"]')).indexOf(panel) });
        }
        return result;
      });
      for (const parent of parents) {
        await page.locator(`[data-cid="${parent.cid}"] > .tab-list > button`).nth(parent.index).click();
      }
      const expanders = await widget(name).evaluate(element => {
        const result = [];
        for (let parent = element.parentElement; parent; parent = parent.parentElement) {
          if (parent.tagName === 'DETAILS') result.unshift(parent.dataset.cid);
        }
        return result;
      });
      for (const cid of expanders) {
        const details = page.locator(`details[data-cid="${cid}"]`);
        if (!(await details.evaluate(element => element.open))) await details.locator(':scope > summary').click();
      }
      await expect(widget(name)).toBeVisible();
      return widget(name);
    };
    await page.setViewportSize(scenario === 'shim-eherbs' ? { width: 800, height: 700 } : { width: 1000, height: 850 });
    if (scenario === 'shim-bigshot-corrected') {
      await page.setViewportSize({ width: 1200, height: 900 });
      await (await reveal('resting_room_id')).locator('input').fill('1234');
      await (await reveal('wander_wait')).locator('input').fill('0.7');
      await (await reveal('attack_drop')).locator('input').fill('Guarded');
      await widget('attack_drop').locator('input').press('Tab');
      await (await reveal('fog_return')).locator('select').selectOption({ label: 'Custom' });
      await expect(widget('custom_fog').locator('input')).toBeEnabled();
      await widget('fog_return').locator('select').selectOption({ label: 'None' });
      await expect(widget('custom_fog').locator('input')).toBeDisabled();
      await (await reveal('boons_all:flee')).locator('input').check();
      await expect(widget('immunity:flee').locator('input')).toBeChecked();
      await (await reveal('immunity:crit_death_immune_ignore')).locator('input').check();
      await expect(widget('immunity:crit_death_immune_flee').locator('input')).not.toBeChecked();
      await expect(widget('boons_all:flee').locator('input')).not.toBeChecked();
      await (await reveal('notes')).locator('textarea').fill('Acceptance notes\nsecond line');
      await widget('notes').locator('textarea').press('Tab');
      await (await reveal('save_profile_name')).locator('input').fill('browser-profile');
      await widget('profile_save').click();
      await expect(widget('profile_current').locator('input')).toHaveValue('browser-profile');
      await expect(widget('profile_current').locator('input')).toHaveAttribute('readonly', '');
    } else if (scenario === 'shim-eloot-corrected') {
      await (await reveal('sell_locksmith')).locator('input').check();
      await expect(widget('locksmith_priority').locator('select')).toBeEnabled();
      await widget('locksmith_priority').locator('select').selectOption({ label: 'Locksmith First' });
      await widget('use_incremental_tipping').locator('input').check();
      await expect(widget('use_standard_tipping').locator('input')).not.toBeChecked();
      await widget('alpha_rate').locator('input').fill('3.5');
      await (await reveal('sell_exclude_entry')).locator('input').fill('fixture exclusion');
      const listGeometry = await widget('sell_exclude_entry').evaluate(element => {
        const input = element.getBoundingClientRect(), frame = element.closest('fieldset').getBoundingClientRect();
        const grid = element.parentElement.getBoundingClientRect();
        return { width: input.width, top: grid.top - frame.top, bottom: frame.bottom - grid.bottom };
      });
      expect(listGeometry.width).toBeGreaterThan(100);
      expect(listGeometry.top).toBeGreaterThanOrEqual(0);
      expect(listGeometry.bottom).toBeGreaterThanOrEqual(0);
      await widget('sell_exclude_add').click();
      await expect(widget('sell_exclude').locator('tbody tr')).toHaveCount(1);
      await widget('sell_exclude').getByText('fixture exclusion', { exact: true }).click();
      await widget('sell_exclude_delete').click();
      await expect(widget('sell_exclude').locator('tbody tr')).toHaveCount(0);
      await (await reveal('loot_types:alchemy')).locator('input').check();
      await (await reveal('skin_enable')).locator('input').check();
      await (await reveal('gem_horde')).locator('input').check();
      await widget('gem_only_list').locator('input').check();
      await expect(widget('gem_everything_list').locator('input')).not.toBeChecked();
      await widget('gem_list_entry').locator('input').fill('ruby');
      await widget('gem_list_add').click();
      await expect(widget('gem_list').locator('tbody tr')).toHaveCount(1);
      await widget('gem_horde_locker').locator('input').check();
      await expect(widget('gem_locker').locator('select')).toBeEnabled();
      await widget('gem_horde_locker_che').locator('input').check();
      await expect(widget('gem_locker').locator('select')).toBeDisabled();
      await expect(widget('gem_horde_che_rooms').locator('input')).toBeEnabled();
      await widget('gem_horde_che_rooms').locator('input').fill('1234');
    } else if (scenario === 'shim-ebounty') {
      await (await reveal('culling_max')).locator('input').fill('25');
      await widget('culling_max').locator('input').press('Tab');
      await (await reveal('selling_script')).locator('input').fill('fixture-sell');
      await widget('selling_script').locator('input').press('Tab');
      await (await reveal('once_and_done')).locator('input').check();
      await expect(widget('new_bounty_on_exit').locator('input')).toBeEnabled();
      await widget('new_bounty_on_exit').locator('input').check();
      await widget('once_and_done').locator('input').uncheck();
      await expect(widget('new_bounty_on_exit').locator('input')).toBeDisabled();
      await expect(widget('new_bounty_on_exit').locator('input')).not.toBeChecked();
      await (await reveal('keep_hunting')).locator('input').check();
      await widget('exp_pause').locator('input').check();
      await expect(widget('keep_hunting').locator('input')).not.toBeChecked();
      await (await reveal('creature_exclude_entry')).locator('input').fill('fixture creature');
      await widget('creature_exclude_add').click();
      await expect(widget('creature_exclude').locator('tbody tr')).toHaveCount(1);
      await widget('creature_exclude').locator('tbody tr').click();
      await widget('creature_exclude_delete').click();
      await expect(widget('creature_exclude').locator('tbody tr')).toHaveCount(0);
      // A quarter-turn must contribute a vertical footprint instead of merely
      // painting rotated text over neighboring grid cells.
      const rotation = page.locator('.webui-rotated-text');
      const rotationPanel = await rotation.evaluate(el => [...el.closest('.tab-panel').parentElement.children]
        .filter(child => child.matches('.tab-panel')).indexOf(el.closest('.tab-panel')));
      await page.getByRole('tab').nth(rotationPanel).click();
      await expect(rotation).toBeVisible();
      const box = await rotation.boundingBox();
      expect(box.height).toBeGreaterThan(box.width);
    } else if (scenario === 'shim-eherbs') {
      await (await reveal('herb_container')).locator('input').fill('herb sack');
      await widget('herb_container').locator('input').press('Tab');
      await widget('buy_missing').locator('input').check();
      await expect(widget('use650').locator('input')).toBeDisabled();
    } else {
      await (await reveal('guild_pause')).locator('input').fill('25');
      await widget('guild_pause').locator('input').press('Tab');
      await expect((await reveal('shadow_drop_item')).locator('input')).toBeDisabled();
      await expect((await reveal('use_wracking')).locator('input')).toBeDisabled();
      // The internal GTK entry has no separate focus target. The shared combo
      // remains operable by both keyboard text input and named option selection.
      const profile = (await reveal('profile_a')).locator('input');
      await profile.focus();
      await expect(profile).toBeFocused();
      await profile.fill('travel');
      await profile.press('Tab');
      const guild = (await reveal('home_guild')).locator('input');
      await guild.fill("Wehnimer's Landing");
      await guild.press('Tab');
      for (const [key, reset] of [['item_include', 'btn_reset'], ['consignment_include', 'btn_consignment_reset']]) {
        const table = await reveal(key);
        const count = await table.locator('tbody tr').count();
        await widget(`${key}_entry`).locator('input').fill('fixture reagent');
        await widget(`${key}_add`).click();
        await expect(table.locator('tbody tr')).toHaveCount(count + 1);
        await table.getByText('fixture reagent', { exact: true }).click();
        await widget(`${key}_delete`).click();
        await expect(table.locator('tbody tr')).toHaveCount(count);
        await widget(`${key}_entry`).locator('input').fill('fixture reset');
        await widget(`${key}_add`).click();
        await expect(table.locator('tbody tr')).toHaveCount(count + 1);
        await widget(reset).click();
        await expect(table.locator('tbody tr')).toHaveCount(count);
      }
      const reset = widget('btn_consignment_reset');
      await expect(reset).toBeVisible();
      await expect(reset).toHaveCSS('min-height', '20px');
      expect((await reset.boundingBox()).height).toBeGreaterThan(20);
      expect(await reset.evaluate(button => button.scrollWidth <= button.clientWidth)).toBe(true);
    }
    await page.screenshot({ path: require('path').join(__dirname, 'test-results', `${scenario}.png`), fullPage: true });
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimEwaggle({ page, expect }) {
    await page.setViewportSize({ width: 730, height: 800 });
    await expect.poll(() => page.evaluate(() => {
      const fields = [...document.querySelectorAll('.field.inline')].map(field => {
        const rect = field.getBoundingClientRect();
        const frame = field.closest('fieldset')?.getBoundingClientRect();
        return { rect, frame };
      });
      return fields.every(({ rect, frame }, index) => (!frame || rect.right <= frame.right + 1) &&
        fields.slice(index + 1).every(({ rect: other }) =>
          Math.min(rect.right, other.right) - Math.max(rect.left, other.left) <= 1 ||
          Math.min(rect.bottom, other.bottom) - Math.max(rect.top, other.top) <= 1));
    })).toBe(true);
    const tables = page.locator('.webui-table-wrap');
    await expect(tables).toHaveCount(2);
    const available = tables.filter({ hasText: '102  Spirit Barrier' });
    const casting = tables.filter({ hasText: '101  Spirit Warding I' });
    const row = available.locator('tbody tr').first();
    await row.focus();
    await page.keyboard.type('102');
    await expect(available.locator('tr[aria-selected="true"]')).toContainText('Spirit Barrier');
    // The bottom blank area must be a target, not just the populated row.
    const blankArea = async target => {
      let box;
      await expect.poll(async () => {
        box = await target.boundingBox();
        return box?.height || 0;
      }).toBeGreaterThan(200);
      return { x: box.width / 2, y: box.height - 20 };
    };
    await row.dragTo(casting, { targetPosition: await blankArea(casting) });
    await expect(tables.nth(0).locator('tbody tr')).toHaveCount(2);
    const destination = tables.nth(0);
    const empty = tables.nth(1);
    await expect(empty.locator('tbody tr')).toHaveCount(0);
    await destination.locator('tbody tr').filter({ hasText: 'Spirit Barrier' }).dragTo(empty,
      { targetPosition: await blankArea(empty) });
    await expect(empty.locator('tbody tr')).toHaveCount(1);
    // Hold the third native gesture across background server renders. Chrome
    // emits pointercancel on handoff to HTML drag-and-drop; that is not dragend.
    const visibleBox = async locator => {
      let box;
      await expect.poll(async () => {
        box = await locator.boundingBox();
        return !!box && box.width > 0 && box.height > 0;
      }, { message: 'drag geometry must be visible after background redraws' }).toBe(true);
      return box;
    };
    const starts = await page.evaluate(() => window.fixtureDragStarts || 0);
    const sourceBox = await visibleBox(empty.locator('tbody tr'));
    await page.mouse.move(sourceBox.x + sourceBox.width / 2, sourceBox.y + sourceBox.height / 2);
    await page.mouse.down();
    await page.mouse.move(sourceBox.x + sourceBox.width / 2 + 15, sourceBox.y + sourceBox.height / 2, { steps: 5 });
    await expect.poll(() => page.evaluate(() => window.fixtureDragStarts || 0)).toBe(starts + 1);
    // Signal the Ruby fixture only after Chrome starts the real third drag.
    // This local test handshake excludes browser startup from synchronization.
    const controls = JSON.parse(process.env.WEBUI_TEST_CONTROLS);
    require('node:fs').writeFileSync(controls.drag_ready, 'ready');
    // Wait for the finite server-render batch while still holding the native
    // gesture. Finish churn before dropping, preserving the one-stale-retry contract.
    await expect.poll(() => page.evaluate(() => window.fixtureDragRenderBatchFinished === true)).toBe(true);
    expect(await page.evaluate(() => window.fixtureDragSource?.isConnected), 'the third drag source must survive background renders').toBe(true);
    const targetBox = await visibleBox(destination);
    await page.mouse.move(targetBox.x + targetBox.width / 2, targetBox.y + targetBox.height - 20, { steps: 5 });
    await page.mouse.up();
    await expect(destination.locator('tbody tr')).toHaveCount(2);
    const barrier = destination.locator('tbody tr').filter({ hasText: 'Spirit Barrier' });
    await barrier.dragTo(destination);
    await expect(destination.locator('tbody tr')).toHaveCount(3);
    await destination.locator('tbody tr').filter({ hasText: 'Spirit Barrier' }).first().dblclick();
    await expect(destination.locator('tbody tr')).toHaveCount(2);
    await tables.nth(1).locator('tbody tr').filter({ hasText: 'Spirit Barrier' }).dblclick();
    await expect(destination.locator('tbody tr')).toHaveCount(3);
    await page.getByLabel('Choose option').selectOption({ label: 'Full Plate (20)' });
    const spin = page.locator('input[type="number"]').first();
    await spin.fill('90');
    await spin.press('Tab');
    await expect(page.getByRole('link')).toHaveCount(3);
    await expect(page.getByRole('link').first()).toHaveAttribute('rel', 'noopener noreferrer');
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimBuilder({ page, expect }) {
    await expect(page.getByRole('tab', { name: 'General', exact: true })).toBeVisible();
    for (const viewport of [{ width: 650, height: 675 }, { width: 1000, height: 850 }]) {
      await page.setViewportSize(viewport);
      await expect.poll(() => page.evaluate(() => {
        const root = document.querySelector('.webui-page');
        const ranges = [...root.querySelectorAll('.field.inline')].map(field => {
          const text = field.querySelector('.field-label');
          const input = field.querySelector('input');
          if (!text || !input) return null;
          const range = document.createRange();
          range.selectNodeContents(text);
          const a = input.getBoundingClientRect(), b = range.getBoundingClientRect();
          return { label: text.textContent, left: Math.min(a.left, b.left), right: Math.max(a.right, b.right),
            top: Math.min(a.top, b.top), bottom: Math.max(a.bottom, b.bottom) };
        }).filter(Boolean);
        const overlaps = ranges.flatMap((a, i) => ranges.slice(i + 1).filter(b =>
          Math.min(a.right, b.right) - Math.max(a.left, b.left) > 1 &&
          Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > 1).map(b => `${a.label} / ${b.label}`));
        const close = [...root.querySelectorAll('button')].find(button => button.textContent === 'Close');
        const footer = close.getBoundingClientRect();
        return { overlaps, horizontalOverflow: root.scrollWidth > innerWidth + 1,
          footerVisible: footer.top >= 0 && footer.bottom <= innerHeight + 1,
          footerOutsideScroll: !close.closest('.webui-scroll') };
      })).toEqual({ overlaps: [], horizontalOverflow: false, footerVisible: true, footerOutsideScroll: true });
    }
    const scripts = page.getByPlaceholder('list of scripts to pause eg - bigshot, eloot, go2');
    await expect(scripts).toHaveValue('bigshot');
    expect(await scripts.evaluate(control => control.getBoundingClientRect().width)).toBeGreaterThan(400);
    await scripts.fill('hunting, travel');
    await scripts.press('Enter');
    // receives-default on Close must not promote it to a page-wide Enter action.
    const close = page.getByRole('button', { name: 'Close', exact: true });
    await expect(close).toBeVisible();
    await expect(page.getByRole('checkbox', { name: 'Cure Disease', exact: true })).toBeDisabled();
    const poison = page.getByRole('checkbox', { name: 'Cure Poison', exact: true });
    await poison.focus();
    await poison.press('Space');
    await expect(poison).toBeChecked();
    await poison.press('Enter');
    await expect(poison).toBeChecked();
    const stance = page.getByRole('checkbox', { name: 'Stunman Stance1', exact: true });
    await stance.check();
    await page.getByRole('checkbox', { name: 'Stunman Flee', exact: true }).check();
    await expect(stance).not.toBeChecked();
    await expect(page.getByText('To save properly, exit with the close button and not the X window -->', { exact: true })).toHaveCSS('font-style', 'italic');
    await close.focus();
    await page.evaluate(() => window.fixtureRedraw());
    await expect(close).toBeFocused();
    await close.press('Enter');
    // Keep the transport alive through save/close callbacks and any stale-event
    // retry. A dispatched DOM click is not server confirmation of completion.
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function prepareShimBuilder({ page }) {
    // Redeliver an accepted tree on demand to force the CI focus/Enter race.
    // This fixture hook changes neither the production protocol nor callbacks.
    await page.addInitScript(() => {
      const NativeWebSocket = window.WebSocket;
      window.WebSocket = class extends NativeWebSocket {
        constructor(...args) {
          super(...args);
          this.addEventListener('message', event => {
            let message;
            try { message = JSON.parse(event.data); } catch { return; }
            if (message.type === 'render') {
              window.fixtureRedraw = () => this.dispatchEvent(new MessageEvent('message', { data: event.data }));
            }
          });
        }
      };
    });
}

async function prepareShimEwaggle({ page }) {
    // Capture the actual native drag source, not a locator resolved before a redraw.
    await page.addInitScript(() => {
      // Observe reassembled messages; Playwright's frame events can contain only
      // part of a valid JSON message when the transport fragments large renders.
      const NativeWebSocket = window.WebSocket;
      window.WebSocket = class extends NativeWebSocket {
        constructor(...args) {
          super(...args);
          this.addEventListener('message', event => {
            let message;
            try { message = JSON.parse(event.data); } catch { return; }
            if (message?.type === 'render' && message.tree?.props?.title === 'EWaggle drag fixture complete') {
              window.fixtureDragRenderBatchFinished = true;
            }
          });
        }
      };
      document.addEventListener('dragstart', event => {
        window.fixtureDragSource = event.target;
        window.fixtureDragStarts = (window.fixtureDragStarts || 0) + 1;
      }, true);
    });
}

module.exports = [
  { id: 'shim-builder', run: runShimBuilder, prepare: prepareShimBuilder },
  { id: 'shim-ewaggle', run: runShimEwaggle, prepare: prepareShimEwaggle },
  { id: 'shim-ebounty', run: runShimEbounty },
  { id: 'shim-eherbs', run: runShimEbounty },
  { id: 'shim-blackarts', run: runShimEbounty },
  { id: 'shim-eloot-corrected', run: runShimEbounty },
  { id: 'shim-bigshot-corrected', run: runShimEbounty },
  { id: 'shim-repository', run: runShimRepository },
  { id: 'shim-go2', run: runShimRepository },
  { id: 'shim-huntplan', run: runShimHuntplan },
];
