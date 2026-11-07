const { defineConfig } = require('@playwright/test');

// RSpec owns each fixture service and passes its one-use launch-file URL.
// Run one browser scenario at a time; retries would hide first-attempt failures.
// Headless Chrome verifies real DOM/cookies/navigation, not OS app-window behavior.
module.exports = defineConfig({
  testDir: __dirname,
  testMatch: 'browser.spec.cjs',
  // Parallel RSpec workers run Playwright concurrently, each writing its own
  // test-results/<scenario>. Skip that tree while discovering tests (via
  // spec/webui/.gitignore), or one run can scan a folder another just replaced.
  respectGitIgnore: true,
  workers: 1,
  retries: 0,
  timeout: 30_000,
  globalTimeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: 'line',
  use: {
    browserName: 'chromium',
    channel: 'chrome',
    headless: true,
    viewport: { width: 640, height: 480 },
    actionTimeout: 10_000,
    navigationTimeout: 10_000,
    screenshot: 'only-on-failure',
    // Ruby checks saved state after Playwright exits. Keep these fixture-only
    // traces even when browser assertions pass; CI uploads them if Ruby fails.
    trace: 'on',
  },
});
