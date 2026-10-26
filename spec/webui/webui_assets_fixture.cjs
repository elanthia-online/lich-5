// Execute the production HTML's ordered classic scripts in synthetic browser fixtures.
const fs = require('node:fs');
const path = require('node:path');
const assetsRoot = path.resolve(__dirname, '../../lib/webui/assets');

/**
 * Reads the shipped entry point rather than maintaining a second fixture manifest.
 * @returns {Array<{name: string, source: string}>} Same-origin deferred assets in document order.
 */
function browserAssets() {
  const html = fs.readFileSync(path.join(assetsRoot, 'index.html'), 'utf8');
  return [...html.matchAll(/<script src="\/assets\/([a-z_]+\.js)" defer><\/script>/g)]
    .map(([, name]) => ({ name, source: fs.readFileSync(path.join(assetsRoot, name), 'utf8') }));
}

module.exports = { browserAssets };
