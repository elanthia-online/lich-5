# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'open3'
require 'rbconfig'

RSpec.describe 'default WebUI entrypoint acceptance' do
  it 'authenticates the real page, exercises it, and shuts down without GTK' do
    root = File.expand_path('../../..', __dir__)
    script = File.join(root, 'spec/support/default_webui_acceptance_check.rb')
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, chdir: root)

    expect(status).to be_success, stderr
    result = JSON.parse(stdout)
    expect(result).to include(
      'verdict'                    => 'pass',
      'authenticated_http'         => true,
      'authenticated_websocket'    => true,
      'required_tabs'              => ['Saved Entry', 'Manual Entry', 'Account Management', 'Frontends'],
      'interaction'                => 'GUI Settings changed from hidden to visible',
      'launcher_start_replaced'    => false,
      'launcher_await_replaced'    => false,
      'entrypoint_argv'            => [],
      'clean_shutdown'             => true,
      'exit_status'                => 0,
      'gtk_family_loaded_features' => []
    )
    expect(result.fetch('launcher_start_source')).to match(%r{\Alib/common/webui_launcher\.rb:\d+\z})
    expect(result.fetch('launcher_await_source')).to match(%r{\Alib/common/webui_launcher\.rb:\d+\z})
  end
end
