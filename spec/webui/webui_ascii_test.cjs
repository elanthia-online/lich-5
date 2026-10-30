// Keep shipped browser sources and their executable fixtures ASCII-only.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('browser code and fixtures use escapes rather than raw Unicode source', () => {
  const roots = [path.resolve(__dirname, '../../lib/webui/assets'), __dirname, path.join(__dirname, 'scenarios')];
  const files = roots.flatMap(root => fs.readdirSync(root)
    .filter(name => /\.(?:js|cjs|css|html)$/.test(name)).map(name => path.join(root, name)));
  for (const file of files) assert.match(fs.readFileSync(file, 'utf8'), /^[\x00-\x7f]*$/, file);
});
