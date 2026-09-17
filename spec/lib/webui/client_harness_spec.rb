# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'

# The client's behaviour is pinned by spec/webui_client: the real app.js in
# jsdom against a fake WebSocket, driven through DOM events. This example
# runs it under node so the suite fails when the client does. Without node
# the example is pending, loudly: a client claim nobody executed is exactly
# the weakness the harness exists to close (ledger D22).
RSpec.describe 'WebUI client harness' do
  harness_dir = File.expand_path('../../webui_client', __dir__)
  npm = Gem.win_platform? ? 'npm.cmd' : 'npm'

  def tool_present?(command)
    system(command, '--version', out: File::NULL, err: File::NULL)
  rescue SystemCallError
    false
  end

  it 'passes every app.js behavioural case under node' do
    pending 'node is not installed; the client harness (spec/webui_client) did not run' unless tool_present?('node')

    unless File.directory?(File.join(harness_dir, 'node_modules'))
      pending 'npm is not installed; cannot install the client harness dependencies' unless tool_present?(npm)
      output, status = Open3.capture2e(npm, 'ci', '--no-audit', '--no-fund', chdir: harness_dir)
      expect(status.success?).to be(true), "npm ci failed in #{harness_dir}:\n#{output}"
    end

    output, status = Open3.capture2e('node', '--test', 'cases/*.test.mjs', chdir: harness_dir)
    summary = output.lines.grep(/^# (tests|pass|fail)/).map(&:strip).join(', ')
    expect(status.success?).to be(true), "client harness failed (#{summary}):\n#{output}"
    expect(output).to match(/^# fail 0$/)
    expect(output).to match(/^# pass [1-9]\d*$/)
  end
end
