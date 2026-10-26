// Scenario callbacks are inert until the Ruby-owned browser run selects one.
const { sampleCanvasScroll } = require('./canvas_sampling.cjs');

async function runShimCanvas({ page, expect }) {
    const scroll = page.locator('.webui-scroll');
    const scrollPosition = property => page.evaluate(sampleCanvasScroll, property);
    await expect.poll(() => scroll.evaluate(el => el.scrollWidth)).toBeGreaterThan(1200);
    await scroll.evaluate(el => { el.scrollLeft = 400; el.scrollTop = 300; });
    await expect.poll(() => scrollPosition('scrollLeft')).toBe(400);
    const bounds = await scroll.boundingBox();
    const x = bounds.x + 220, y = bounds.y + 150;
    await page.mouse.move(x, y);
    await page.mouse.down();
    await page.mouse.move(x - 90, y - 60, { steps: 6 });
    // The original script must see movement and scroll while the button is held.
    await expect.poll(() => scrollPosition('scrollLeft')).toBeGreaterThan(450);
    await expect.poll(() => scrollPosition('scrollTop')).toBeGreaterThan(330);
    await page.mouse.move(bounds.x - 10, bounds.y - 10);
    await page.mouse.up();
    await expect(page.getByText('Released 1', { exact: true })).toBeVisible();
    await page.mouse.move(x, y);
    await page.mouse.down();
    await page.mouse.move(x - 30, y - 20);
    await page.evaluate(() => window.dispatchEvent(new Event('blur')));
    await page.mouse.up();
    await expect(page.getByText('Released 2', { exact: true })).toBeVisible();
    await page.mouse.move(x, y);
    const left = await scrollPosition('scrollLeft');
    await page.keyboard.down('Shift');
    await page.mouse.wheel(0, 60);
    await page.keyboard.up('Shift');
    await expect.poll(() => scrollPosition('scrollLeft')).toBeGreaterThan(left);
    await page.keyboard.down('Control');
    await page.mouse.wheel(0, -40);
    await page.keyboard.up('Control');
    await expect(page.getByText(/^Anchor \d+,\d+$/)).toBeVisible();
}

async function runShimKeyboardRedraw({ page, expect }) {
    for (let cycle = 0; cycle < 2; cycle++) {
      await page.getByText('Enter local mode', { exact: true }).click();
      await expect(page.getByText('Mode active - Escape to cancel', { exact: true })).toBeVisible();
      await expect(page.locator('.webui-page')).toBeFocused();
      await page.keyboard.press('Escape');
      await expect(page.getByText('Mode cancelled', { exact: true })).toBeVisible();
    }
}

async function runPriority16Events({ page, context, expect }) {
    const entry = page.getByPlaceholder('Blur fixture');
    await entry.fill('latest');
    await page.getByRole('button', { name: 'Reveal', exact: true }).focus();
    await expect(page.getByText('Blur: latest', { exact: true })).toBeVisible();
    await expect(page.getByText('Opted out', { exact: true })).toBeHidden();
    await page.getByRole('button', { name: 'Reveal', exact: true }).click();
    await expect(page.getByText('Opted out', { exact: true })).toBeVisible();
    const search = page.getByPlaceholder('Search fixture');
    await search.fill('ab');
    await search.fill('abc');
    await expect(page.getByText('Search: abc', { exact: true })).toBeVisible();
    await search.fill('');
    await expect(page.getByText('Search: ', { exact: true })).toBeVisible();
    await page.getByRole('radio', { name: 'Second radio', exact: true }).click();
    await expect(page.getByText('Radio: true:1', { exact: true })).toBeVisible();
    await page.getByRole('radio', { name: 'Second radio', exact: true }).click();
    await expect(page.getByText('Radio: true:2', { exact: true })).toBeVisible();
    const spin = page.getByRole('spinbutton');
    await spin.hover();
    await expect(page.getByText('Hover delivered', { exact: true })).toBeVisible();
    await spin.focus();
    await spin.dispatchEvent('wheel', { deltaY: 100, deltaMode: 0 });
    await expect(spin).toHaveValue('5');
    await entry.focus();
    await entry.press('q');
    await expect(page.getByText('Key: 113', { exact: true })).toBeVisible();
    const surface = page.locator('[data-scroll-surface]').filter({ hasText: 'Scroll surface' });
    const scroller = page.locator('.webui-scroll');
    await surface.dispatchEvent('wheel', { deltaY: 40, deltaMode: 0 });
    await expect.poll(() => scroller.evaluate(element => element.scrollTop)).toBe(40);
    await surface.dispatchEvent('wheel', { deltaY: 30, deltaMode: 0 });
    await expect.poll(() => scroller.evaluate(element => element.scrollTop)).toBe(70);
    await surface.dispatchEvent('wheel', { deltaY: 25, deltaMode: 0, shiftKey: true });
    await expect.poll(() => scroller.evaluate(element => element.scrollLeft)).toBe(25);
    await surface.dispatchEvent('wheel', { deltaY: 200, deltaMode: 0, ctrlKey: true });
    await entry.fill('barrier');
    await page.getByRole('button', { name: 'Reveal', exact: true }).focus();
    await expect(page.getByText('Blur: barrier', { exact: true })).toBeVisible();
    expect(await scroller.evaluate(element => element.scrollTop)).toBe(70);
    const other = await context.newPage();
    await other.goto(page.url());
    await expect(other.getByPlaceholder('Search fixture')).toHaveValue('');
    expect(await other.locator('.webui-scroll').evaluate(element => element.scrollTop)).toBe(0);
    await other.close();
}

async function runPriority17WidgetDrag({ page, expect }) {
    const targets = page.locator('[data-widget-drag-destination]');
    const status = page.getByText(/^Moves \d+; unlocked$/);
    await expect(status).toHaveText('Moves 0; unlocked');
    // An external drop cannot supply the page-local drag state.
    await targets.nth(1).dispatchEvent('drop', { dataTransfer: await page.evaluateHandle(() => new DataTransfer()) });
    await expect(status).toHaveText('Moves 0; unlocked');
    // Reproduce the acquisition boundary: a legitimate render detaches a
    // previously resolved element and its rectangle becomes zero. Never use
    // that old ElementHandle to choose native mouse coordinates below.
    const retired = await page.evaluate(() => {
      const element = document.querySelector('[data-widget-drag-source]');
      window.fixtureRedraw();
      return { connected: element.isConnected, width: element.getBoundingClientRect().width };
    });
    expect(retired).toEqual({ connected: false, width: 0 });
    const count = type => page.evaluate(type => window.fixtureDragEvents.filter(event => event.type === type && event.trusted).length, type);
    const beginDrag = async () => {
      const starts = await count('dragstart');
      // A single browser task measures the current source, using its interior
      // rather than offsets that can leave a 15 px-high Linux label.
      const point = await page.evaluate(() => {
        const rect = document.querySelector('[data-widget-drag-source]').getBoundingClientRect();
        return { x: rect.x + rect.width / 3, y: rect.y + rect.height / 2, width: rect.width, height: rect.height };
      });
      expect(point.width).toBeGreaterThan(0); expect(point.height).toBeGreaterThan(0);
      await page.mouse.move(point.x, point.y);
      await page.mouse.down();
      expect(await page.evaluate(() => window.fixtureDragEvents.findLast(event => event.type === 'pointerdown')?.sourceHit)).toBe(true);
      const renders = await page.evaluate(() => window.fixtureRenderCount);
      // Prove the real timer delivers a render while the pressed source lives.
      await expect.poll(() => page.evaluate(() => window.fixtureRenderCount)).toBeGreaterThan(renders);
      expect(await page.evaluate(() => window.fixturePressedSource?.isConnected)).toBe(true);
      await page.mouse.move(point.x + Math.min(20, point.width / 4), point.y, { steps: 4 });
      await expect.poll(() => count('dragstart')).toBe(starts + 1);
    };
    const ends = await count('dragend');
    await beginDrag();
    await page.keyboard.press('Escape');
    await page.mouse.up();
    await expect.poll(() => count('dragend')).toBe(ends + 1);
    expect(await count('drop')).toBe(0);
    await expect(status).toHaveText('Moves 0; unlocked');
    const moveTo = async index => {
      const drops = await count('drop');
      const marker = await page.evaluate(() => window.fixtureDragEvents.length);
      await beginDrag();
      const end = await page.evaluate(index => {
        const element = document.querySelectorAll('[data-widget-drag-destination]')[index];
        const rect = element.getBoundingClientRect();
        return { x: rect.x + rect.width / 2, y: rect.y + rect.height * 0.75, cid: element.dataset.cid };
      }, index);
      await page.mouse.move(end.x, end.y, { steps: 8 });
      // Chromium needs a destination dragover before mouseup can produce drop.
      await page.mouse.move(end.x + 1, end.y);
      await expect.poll(() => page.evaluate(({ marker, cid }) => window.fixtureDragEvents.slice(marker)
        .some(event => event.type === 'dragover' && event.trusted && event.destination === cid), { marker, cid: end.cid })).toBe(true);
      await page.mouse.up();
      await expect.poll(() => count('drop')).toBe(drops + 1);
    };
    await moveTo(1);
    await expect(status).toHaveText('Moves 1; unlocked');
    await expect(targets.nth(1).locator('[data-widget-drag-source]')).toHaveCount(1);
    await moveTo(0);
    await expect(status).toHaveText('Moves 2; unlocked');
    // Read the rectangle in one task: the 25 ms refresh can detach a locator
    // between its resolution and boundingBox acquisition before pointerdown.
    const position = await page.evaluate(() => [...document.querySelectorAll('[data-component-type="text"]')]
      .find(element => element.textContent === 'Release refresh target').getBoundingClientRect().toJSON());
    await page.mouse.move(position.x + 4, position.y + 4);
    await page.mouse.down();
    const before = await page.getByText(/^Tick \d+$/).textContent();
    // Let several real timer renders arrive while the release-only surface holds.
    await page.waitForTimeout(150);
    await expect(page.getByText(/^Tick \d+$/)).toHaveText(before);
    await page.mouse.up();
    await expect(page.getByText('Releases 1', { exact: true })).toBeVisible();
    await expect(page.getByText(/^Tick \d+$/)).not.toHaveText(before);
}

async function preparePriority17WidgetDrag({ page }) {
    // Observe real browser events without dispatching or changing their behavior.
    // Keep gesture evidence separate from the 25 ms render traffic ring buffer.
    await page.addInitScript(() => {
      window.fixtureDragEvents = [];
      window.fixtureRenderCount = 0;
      const NativeWebSocket = window.WebSocket;
      window.WebSocket = class extends NativeWebSocket {
        constructor(...args) {
          super(...args);
          this.addEventListener('message', event => {
            let message;
            try { message = JSON.parse(event.data); } catch { return; }
            if (message.type !== 'render') return;
            window.fixtureRenderCount += 1;
            // Reproduce the old detached-element sample using an actual render.
            window.fixtureRedraw = () => this.dispatchEvent(new MessageEvent('message', { data: event.data }));
          });
        }
      };
      const remember = entry => {
        window.fixtureDragEvents.push(entry);
        if (window.fixtureDragEvents.length > 80) window.fixtureDragEvents.shift();
      };
      for (const type of ['pointerdown', 'pointerup', 'pointercancel', 'dragstart', 'dragover', 'drop', 'dragend']) {
        document.addEventListener(type, event => {
          const surface = event.target.closest?.('[data-cid]');
          const source = document.querySelector('[data-widget-drag-source]');
          const rect = source?.getBoundingClientRect();
          const sourceHit = event.target.closest?.('[data-widget-drag-source]');
          if (type === 'pointerdown') window.fixturePressedSource = sourceHit;
          const entry = { type, trusted: event.isTrusted, target: surface?.dataset.cid,
            destination: event.target.closest?.('[data-widget-drag-destination]')?.dataset.cid,
            x: event.clientX, y: event.clientY, source: source?.dataset.cid, sourceHit: !!sourceHit,
            sourceConnected: source?.isConnected,
            rect: rect && { x: rect.x, y: rect.y, width: rect.width, height: rect.height } };
          // One dragover per destination is enough to establish the boundary.
          const previous = window.fixtureDragEvents.at(-1);
          if (type === 'dragover' && previous?.type === type && previous.target === entry.target) return;
          remember(entry);
        }, true);
      }
    });
}

async function afterWidgetDrag({ page, testInfo }) {
  if (!page.isClosed()) {
    const body = JSON.stringify(await page.evaluate(() => window.fixtureDragEvents || []), null, 2);
    await testInfo.attach('widget-drag-events.json', { body, contentType: 'application/json' });
    if (testInfo.status !== testInfo.expectedStatus) console.log(`Widget drag events: ${body}`);
  }
}

async function afterCanvasFailure({ interactions, testInfo }) {
  if (testInfo.status === testInfo.expectedStatus) return;
  console.log(interactions.join('\n'));
}

module.exports = [
  { id: 'shim-canvas', run: runShimCanvas, afterEach: afterCanvasFailure },
  { id: 'shim-keyboard-redraw', run: runShimKeyboardRedraw },
  { id: 'priority16-events', run: runPriority16Events },
  { id: 'priority17-widget-drag', run: runPriority17WidgetDrag, prepare: preparePriority17WidgetDrag, afterEach: afterWidgetDrag },
];
