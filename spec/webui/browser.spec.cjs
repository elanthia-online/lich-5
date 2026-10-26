const { test, expect } = require('@playwright/test');
const { selectScenario } = require('./scenarios/index.cjs');

// Ruby owns the service and verifies the resulting script-side state. Each run
// starts with a fresh browser cookie jar and the actual private file bootstrap.
const scenario = process.env.WEBUI_TEST_SCENARIO;
let selected;

// Compact websocket/console record, printed only when the test fails. Traces
// do not capture websocket frames, so without this a lost event (for example a
// Close that never reaches the server) leaves no evidence in CI.
const wire = [];
const interactions = [];
const wireStart = Date.now();
function record(direction, data) {
  const raw = String(data).slice(0, 200);
  let summary = raw;
  // Only websocket frames are condensed; console text is kept as written.
  if (direction !== 'console') {
    try {
      const message = JSON.parse(data);
      summary = ['type', 'event', 'cid', 'page', 'generation', 'request', 'reason']
        .filter(key => message[key] !== undefined)
        .map(key => `${key}=${typeof message[key] === 'string' ? message[key].slice(0, 40) : message[key]}`)
        .join(' ') || raw;
    } catch (_error) { /* non-JSON frame: keep the truncated text */ }
  }
  const entry = `${String(Date.now() - wireStart).padStart(6)}ms ${direction} ${summary}`;
  wire.push(entry);
  // Render frames can be fragmented; keep only identified interaction traffic.
  if (direction === '->' || direction === 'console' || /^type=(refusal|reply|error)(?: |$)/.test(summary)) {
    interactions.push(entry);
    if (interactions.length > 100) interactions.shift();
  }
  if (wire.length > 200) wire.shift();
}

test.afterEach(async ({ page }, testInfo) => {
  await selected?.afterEach?.({ page, testInfo, interactions });
  if (testInfo.status === testInfo.expectedStatus) return;
  const body = wire.join('\n');
  console.log(`WebUI wire log (${scenario}, last ${wire.length} entries):\n${body}`);
  await testInfo.attach('webui-wire.log', { body, contentType: 'text/plain' });
  await testInfo.attach('webui-interactions.log', { body: interactions.join('\n'), contentType: 'text/plain' });
});

test(`WebUI ${scenario || 'missing fixture'}`, async ({ page, context }) => {
  page.on('websocket', socket => {
    socket.on('framesent', frame => record('->', frame.payload));
    socket.on('framereceived', frame => record('<-', frame.payload));
    socket.on('close', () => record('--', 'socket closed'));
  });
  page.on('console', message => record('console', `${message.type()}: ${message.text()}`));
  const target = process.env.WEBUI_TEST_URL;
  expect(target, 'Run through the browser-tagged RSpec fixtures').toMatch(/^file:\/\//);
  selected = selectScenario(scenario);
  const errors = [];
  const documents = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => {
    if (response.request().resourceType() === 'document') documents.push(response);
  });
  await selected.prepare?.({ page });
  await page.goto(target);
  await expect(page).toHaveURL(/^http:\/\/127\.0\.0\.1:\d+\/\?page=/);
  await expect(page.locator('.webui-page')).toBeVisible();

  // No fabricated Cookie/Origin/Fetch Metadata headers: Chrome must redeem the
  // bootstrap, commit /auth, and send its Strict cookie on the final document.
  const auth = documents.find(response => new URL(response.url()).pathname === '/auth');
  expect(auth, 'The browser must visit the authentication intermediate document').toBeTruthy();
  expect(auth.status()).toBe(200);
  const final = documents.find(response => response.url() === page.url());
  expect(final.status()).toBe(200);
  const cookies = await context.cookies(page.url());
  expect(cookies).toEqual(expect.arrayContaining([
    expect.objectContaining({ name: `lich_webui_${new URL(page.url()).port}`, httpOnly: true, sameSite: 'Strict' }),
  ]));
  expect(new URL(page.url()).searchParams.has('token')).toBe(false);

  await selected.run({ page, context, expect, scenario, wire, __dirname });
  expect(errors).toEqual([]);
});
