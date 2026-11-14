const fs = require('node:fs');
const path = require('node:path');
const { expect } = require('@playwright/test');

const assetsRoot = path.resolve(__dirname, '../../lib/webui/assets');
const origin = 'http://127.0.0.1:4173';

/**
 * Loads the shipped entry point/assets in a real engine, intercepting only transport.
 * @param {import('@playwright/test').Page} page Isolated browser page owned by the test.
 * @returns {Promise<{sent: Object[], receive: function(Object): void}>} Server-side wire capture.
 */
async function openRenderer(page) {
  const sent = [];
  let socket;
  await page.route(`${origin}/**`, route => {
    const pathname = new URL(route.request().url()).pathname;
    const asset = pathname === '/' ? 'index.html' : pathname.match(/^\/assets\/([a-z_]+\.(?:js|css))$/)?.[1];
    if (!asset) return route.fulfill({ status: 404, body: '' });
    const contentType = asset.endsWith('.js') ? 'application/javascript' :
      asset.endsWith('.css') ? 'text/css' : 'text/html';
    return route.fulfill({ contentType, body: fs.readFileSync(path.join(assetsRoot, asset)) });
  });
  await page.routeWebSocket(`${origin.replace('http:', 'ws:')}/ws`, route => {
    socket = route;
    route.onMessage(message => sent.push(JSON.parse(message.toString())));
  });
  await page.goto(origin);
  await expect.poll(() => Boolean(socket), { message: 'renderer opened its socket' }).toBe(true);
  return { sent, receive: message => socket.send(JSON.stringify(message)) };
}

module.exports = { openRenderer };
