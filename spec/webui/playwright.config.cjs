const { defineConfig } = require('@playwright/test');

// Separate native and node:test/jsdom runners share the ordinary npm test entrypoint.
module.exports = defineConfig({
  testDir: __dirname,
  testMatch: '**/*.spec.cjs',
  respectGitIgnore: true,
  // Native popup focus belongs to the desktop; concurrent browsers can dismiss it.
  workers: 1,
  use: { headless: true },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium', channel: 'chrome' } },
    // Pinned WebKit checks page logic; the real WKWebView helper needs its own receipt.
    { name: 'webkit', use: { browserName: 'webkit' },
      // The no-popup boundary is calibrated in headless Chrome; WebKit opens a popup.
      grepInvert: /@chromium-no-popup/ }
  ]
});
