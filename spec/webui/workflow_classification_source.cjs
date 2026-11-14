const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Normalized once so markers and regexes also work on CRLF checkouts.
const lf = text => text.replace(/\r\n/g, '\n');
const read = name => lf(fs.readFileSync(path.join(__dirname, '../..', name), 'utf8'));
const ci = read('.github/workflows/ci.yml');
const workflow = read('.github/workflows/webui_tests.yaml');

// The lines of one top-level job, from its key to the next job key.
function jobBlock(text, job) {
  const lines = text.split('\n');
  const starts = lines.flatMap((line, index) => line === `  ${job}:` ? [index] : []);
  assert.equal(starts.length, 1, `expected one ${job} job`);
  const next = lines.findIndex((line, index) => index > starts[0] && /^ {2}[A-Za-z_][\w-]*:$/.test(line));
  return lines.slice(starts[0], next < 0 ? lines.length : next);
}

// Extract the production script rather than maintaining a copied policy.
function inlineScript(text, job) {
  const block = jobBlock(text, job);
  const scripts = block.flatMap((line, index) => line === '          script: |' ? [index] : []);
  assert.equal(scripts.length, 1, `expected one literal script in the ${job} job`);
  const rest = block.slice(scripts[0] + 1);
  const end = rest.findIndex(line => line.trim() && !line.startsWith('            '));
  const body = end < 0 ? rest : rest.slice(0, end);
  assert.ok(body.some(line => line.trim()), `${job} script must not be empty`);
  return body.map(line => line.slice(12)).join('\n');
}

const classifierSource = (text = ci) => inlineScript(text, 'classify');
const gateSource = (text = ci) => inlineScript(text, 'ci-gate');

// The guard and classifier use the very same table parser. Only this named
// function is evaluated here; the workflow content it receives stays data.
const parsers = [...classifierSource().matchAll(/^function windowsSpecPaths\(workflow\) \{\n[\s\S]*?^\}/gm)];
assert.equal(parsers.length, 1, 'expected one production Windows selection parser');
const parse = vm.runInNewContext(`(${parsers[0][0]})`, {}, { timeout: 1000 });
const windowsSpecPaths = text => Array.from(parse(text));

module.exports = { lf, read, ci, workflow, jobBlock, classifierSource, gateSource, windowsSpecPaths };
