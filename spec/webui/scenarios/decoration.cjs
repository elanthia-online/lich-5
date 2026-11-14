// Scenario callbacks are inert until the Ruby-owned browser run selects one.

async function runPriority15LogStyle({ page, expect }) {
    const custom = page.getByTitle('Custom selection', { exact: true }).locator('table');
    const fallback = page.getByTitle('Default selection', { exact: true }).locator('table');
    const selected = custom.locator('tr[aria-selected="true"]');
    const defaultSelected = fallback.locator('tr[aria-selected="true"]');
    await expect(selected).toHaveCSS('background-color', 'rgb(51, 102, 153)');
    await expect(defaultSelected).toHaveCSS('background-color', 'rgb(53, 132, 228)');
    await expect(selected.locator('td')).toHaveCSS('background-image', 'linear-gradient(rgb(51, 102, 153), rgb(51, 102, 153))');
    await expect(selected.locator('td')).toHaveCSS('color', 'rgb(255, 0, 0)');
    const scroll = page.locator('.webui-scroll').filter({ has: page.locator('.webui-log') });
    expect(await scroll.evaluate(el => el.scrollHeight > el.clientHeight)).toBe(true);
    await scroll.evaluate(el => { el.scrollTop = 0; });
    await page.getByRole('button', { name: 'Append marked line', exact: true }).click();
    await expect(selected).toHaveCSS('background-color', 'rgb(0, 255, 0)');
    await expect(selected.locator('td')).toHaveCSS('background-image', 'linear-gradient(rgb(0, 255, 0), rgb(0, 255, 0))');
    await expect.poll(() => scroll.evaluate(el => el.scrollHeight - el.clientHeight - el.scrollTop)).toBeLessThanOrEqual(2);
    await expect(page.locator('.webui-log')).toContainText('Marked final line');
    expect(await scroll.evaluate(el => {
      const text = el.querySelector('.webui-log').firstChild;
      const start = text.textContent.lastIndexOf('Marked final line');
      const range = document.createRange(); range.setStart(text, start); range.setEnd(text, start + 17);
      const line = range.getBoundingClientRect(), bounds = el.getBoundingClientRect();
      return line.top >= bounds.top && line.bottom <= bounds.bottom;
    })).toBe(true);
    await expect(defaultSelected).toHaveCSS('background-color', 'rgb(53, 132, 228)');
    await custom.getByRole('cell', { name: 'Second', exact: true }).click();
    await expect(selected).toContainText('Second');
    const first = custom.getByRole('cell', { name: 'First', exact: true });
    await expect(first.locator('..')).toHaveAttribute('aria-selected', 'false');
    await expect(first).toHaveCSS('background-color', 'rgb(255, 255, 255)');
    await expect(first).toHaveCSS('background-image', 'none');
    await page.getByRole('button', { name: 'Clear log', exact: true }).click();
    await expect(page.locator('.webui-log')).toHaveText('');
    await expect(selected).toHaveCSS('background-color', 'rgb(0, 255, 0)');
    await page.locator('.webui-page').evaluate(el => { el.dataset.theme = 'dark'; el.dataset.density = 'normal'; });
    await expect(selected).toHaveCSS('background-color', 'rgb(0, 255, 0)');
    await expect(selected.locator('td')).toHaveCSS('background-image', 'linear-gradient(rgb(0, 255, 0), rgb(0, 255, 0))');
    await expect(selected.locator('td')).toHaveCSS('color', 'rgb(255, 0, 0)');
}

async function runNativeBmp({ page, expect }) {
    const image = page.getByRole('img', { name: 'BMP fixture', exact: true });
    await expect.poll(() => image.evaluate(el => el.naturalWidth)).toBe(2);
    expect(await image.evaluate(el => el.naturalHeight)).toBe(1);
    const response = await page.request.get(await image.evaluate(el => el.src));
    expect(response.status()).toBe(200);
    expect(response.headers()['content-type']).toBe('image/bmp');
    expect((await response.body()).subarray(0, 2).toString()).toBe('BM');
}

async function runNativeProgressSizing({ page, expect }) {
    const control = key => page.locator(`[data-cid$="progress:${key}"]`);
    const sizes = async () => {
      for (const height of [18, 24, 36]) {
        for (const kind of ['plain', 'colored']) {
          const root = control(`${kind}-${height}`);
          const track = root.locator('progress');
          const box = await track.boundingBox();
          expect(box.width).toBeCloseTo(300, 0);
          expect(box.height).toBeCloseTo(height, 0);
          await expect(track).toHaveJSProperty('value', 0.5);
          await expect(track).toHaveCSS('appearance', 'none');
        }
      }
    };
    await sizes();
    const painted = control('colored-24').locator('progress');
    await expect(painted).toHaveCSS('--progress-fill', 'rgba(176, 224, 230, 1)');
    const labeled = control('labeled');
    const textBox = await labeled.locator('span').boundingBox();
    const trackBox = await labeled.locator('progress').boundingBox();
    expect(textBox.height).toBeGreaterThan(0);
    expect(trackBox.height).toBeGreaterThan(0);
    expect(trackBox.y).toBeGreaterThanOrEqual(textBox.y + textBox.height);
    expect((await labeled.boundingBox()).height).toBeCloseTo(48, 0);
    expect((await control('default').locator('progress').boundingBox()).height).toBeCloseTo(18, 0);
    const pending = control('pending').locator('progress');
    await expect(pending).not.toHaveAttribute('value');
    await expect(pending).toHaveCSS('animation-name', 'webui-progress-pending');
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect(pending).toHaveCSS('animation-name', 'none');
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.getByRole('button', { name: 'Toggle colors', exact: true }).click();
    await expect(painted).toHaveCSS('--progress-fill', '');
    await sizes();
    await page.getByRole('button', { name: 'Finish', exact: true }).click();
    await expect(page.locator('.webui-page')).toHaveCount(0);
}

async function runShimProgressStyle({ page, expect }) {
    const bar = page.locator('.webui-progress');
    const progress = bar.locator('progress');
    const cid = await bar.getAttribute('data-cid');
    const sibling = page.getByText('Unstyled sibling', { exact: true });
    const weight = await sibling.evaluate(element => getComputedStyle(element).fontWeight);
    await expect(page.locator('.required-setting')).toHaveCount(0);
    await expect(sibling).not.toHaveCSS('font-weight', '700');
    await expect(sibling).not.toHaveCSS('font-family', /Courier New/);
    await expect(progress).toHaveCSS('appearance', 'none');
    await expect(progress).toHaveCSS('height', '24px');
    await expect(bar).toHaveCSS('height', '24px');
    await expect(progress).toHaveCSS('--progress-fill', 'rgba(0, 0, 255, 1)');
    await page.getByRole('button', { name: 'Reload style', exact: true }).click();
    await expect(progress).toHaveCSS('--progress-fill', 'rgba(255, 215, 0, 1)');
    await expect(progress).toHaveJSProperty('value', 0.75);
    const cssRequests = [];
    page.on('request', request => {
      if (new URL(request.url()).hostname === 'invalid') cssRequests.push(request.url());
    });
    await page.getByRole('button', { name: 'Omit style', exact: true }).click();
    await expect(progress).toHaveCSS('appearance', 'none');
    await expect(progress).toHaveCSS('height', '18px');
    await expect.poll(() => bar.evaluate(element => element.style.height)).toBe('');
    await expect.poll(() => progress.evaluate(element => element.style.getPropertyValue('--progress-fill'))).toBe('');
    await expect(bar).toHaveAttribute('data-cid', cid);
    await expect(progress).toHaveJSProperty('value', 0.75);
    await expect(sibling).toHaveCSS('font-weight', weight);
    await page.getByRole('button', { name: 'Reload style', exact: true }).click();
    await expect(progress).toHaveCSS('appearance', 'none');
    await expect(progress).toHaveCSS('height', '24px');
    await expect(bar).toHaveCSS('height', '24px');
    await expect(progress).toHaveCSS('--progress-fill', 'rgba(255, 215, 0, 1)');
    await page.getByRole('button', { name: 'Remove style', exact: true }).click();
    await expect(progress).toHaveCSS('appearance', 'none');
    await expect(progress).toHaveCSS('height', '18px');
    await expect.poll(() => bar.evaluate(element => element.style.height)).toBe('');
    await expect.poll(() => progress.evaluate(element => element.style.getPropertyValue('--progress-fill'))).toBe('');
    await expect(bar).toHaveAttribute('data-cid', cid);
    await expect(progress).toHaveJSProperty('value', 0.75);
    await expect(sibling).toHaveCSS('font-weight', weight);
    await page.getByRole('button', { name: 'Close progress fixture', exact: true }).click();
    await expect(progress).toHaveCount(0);
    expect(cssRequests).toEqual([]);
}

async function runPriority17Drawing({ page, expect }) {
    const surface = page.locator('.composite-surface');
    const rectangles = surface.locator('rect');
    await expect(rectangles).toHaveCount(3);
    await expect(rectangles.nth(1)).toHaveAttribute('width', '30');
    await expect(rectangles.nth(2)).toHaveAttribute('stroke-width', '1');
    await expect(surface).toHaveCSS('overflow', 'hidden');
    await expect(page.getByText('Revealed pool')).toBeHidden();
    const target = page.getByText('Centered target', { exact: true });
    const parent = target.locator('..');
    const a = await target.boundingBox(), b = await parent.boundingBox();
    expect(Math.abs(a.y + a.height / 2 - b.y - b.height / 2)).toBeLessThan(2);
    await page.getByRole('button', { name: 'Update resources' }).click();
    await expect(rectangles.nth(1)).toHaveAttribute('width', '90');
    await expect(page.getByText('Revealed pool')).toBeVisible();
}

async function runNativeOpacityReset({ page, expect }) {
    const targets = [
      ['text:subtle', '0.72'], ['text:frontend-detected', '0.75'],
      ['stack:alpha-stack', '1'], ['button:alpha-button', '1']
    ];
    for (const [step, opacity] of [undefined, 1, 0.35, undefined].entries()) {
      if (step) await page.getByRole('button', { name: 'Cycle opacity', exact: true }).click();
      for (const [suffix, fallback] of targets) {
        const element = page.locator(`[data-cid$="${suffix}"]`);
        await expect(element).toHaveCSS('opacity', opacity === undefined ? fallback : String(opacity));
        await expect.poll(() => element.evaluate(node => node.style.opacity))
          .toBe(opacity === undefined ? '' : String(opacity));
      }
    }
}

module.exports = [
  { id: 'priority17-drawing', run: runPriority17Drawing },
  { id: 'priority15-log-style', run: runPriority15LogStyle },
  { id: 'native-bmp', run: runNativeBmp },
  { id: 'native-progress-sizing', run: runNativeProgressSizing },
  { id: 'native-opacity-reset', run: runNativeOpacityReset },
  { id: 'shim-progress-style', run: runShimProgressStyle },
];
