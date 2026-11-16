# frozen_string_literal: true

require 'open3'
require 'webui/browser_launcher'

RSpec.configure { |config| config.fail_if_no_examples = true } if ENV['NATIVE_BROWSER'] == '1'

# Runs browser assertions against an RSpec-owned service without opening an OS app
# window. The production launch-file writer supplies the real authentication path.
module WebUIBrowser
  # Drives a fixture with Playwright and propagates browser failures into RSpec.
  # Playwright bounds the run and closes its browser; the caller owns service cleanup.
  # @param service [Lich::WebUI::Service] isolated fixture host
  # @param page [Lich::WebUI::Page] registered native or shim page
  # @param scenario [String] browser scenario and diagnostic directory name
  # @param controls [Hash] scenario controls serialized to the browser child process
  # @return [void]
  # @raise [RuntimeError] when the browser assertions or dependency loading fail
  def self.check(service:, page:, scenario:, controls: {})
    root = File.expand_path('../webui', __dir__)
    service.start
    Dir.mktmpdir('webui-browser-spec-') do |directory|
      target = Lich::WebUI::BrowserLauncher.launch_file(service.launch_url(page: page), directory, native: nil)
      environment = { 'WEBUI_TEST_URL' => target, 'WEBUI_TEST_SCENARIO' => scenario, 'WEBUI_TEST_CONTROLS' => JSON.generate(controls) }
      output, status = Open3.capture2e(
        environment, 'node', File.join(root, 'node_modules/@playwright/test/cli.js'), 'test',
        '--config', File.join(root, 'playwright.config.cjs'),
        '--output', File.join(root, 'test-results', scenario)
      )
      raise "WebUI browser check failed (#{scenario}):\n#{output}" unless status.success?
    end
  end
end
