const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Normalized once so markers and regexes also work on CRLF checkouts.
const lf = text => text.replace(/\r\n/g, '\n');
const workflow = lf(fs.readFileSync(path.join(__dirname, '../../.github/workflows/webui_tests.yaml'), 'utf8'));

// Extract the production block rather than maintaining a copied policy.
function classifierSource(text = workflow) {
  const lines = text.split('\n');
  const anchors = lines.flatMap((line, index) => line === '      - &classify' ? [index] : []);
  assert.equal(anchors.length, 1, 'expected one shared classify step');
  const start = anchors[0];
  const end = lines.findIndex((line, index) => index > start && line.startsWith('      - '));
  assert.ok(end > start, 'expected another step after classify');
  const step = lines.slice(start, end);
  assert.ok(step.includes('        id: classify'));
  assert.ok(step.includes('        with:'));
  const scripts = step.flatMap((line, index) => line === '          script: |' ? [index] : []);
  assert.equal(scripts.length, 1, 'expected one literal classify script');
  const body = step.slice(scripts[0] + 1);
  assert.ok(body.some(line => line.trim()), 'classify script must not be empty');
  assert.ok(body.every(line => !line.trim() || line.startsWith('            ')), 'unexpected script indentation');
  return body.map(line => line.slice(12)).join('\n');
}

// The guard and classifier use the very same table parser. Only this named
// function is evaluated here; the workflow content it receives stays data.
const parsers = [...classifierSource().matchAll(/^function windowsSpecPaths\(workflow\) \{\n[\s\S]*?^\}/gm)];
assert.equal(parsers.length, 1, 'expected one production Windows selection parser');
const parse = vm.runInNewContext(`(${parsers[0][0]})`, {}, { timeout: 1000 });
const windowsSpecPaths = text => Array.from(parse(text));

module.exports = { lf, workflow, classifierSource, windowsSpecPaths };
