# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe Lich::WebUI::Service do
  subject(:service) { described_class.new(registry: registry) }

  let(:registry) { Lich::WebUI::Registry.new }

  after { service.stop }

  it 'composes the bundled renderer, registry, runtime, and loopback server' do
    service.start
    page = registry.register(Lich::WebUI::Page.new(owner: Object.new, id: 'page', title: 'Page') {})

    expect(service.server).to be_running
    expect(service.server.host).to eq('127.0.0.1')
    expect(service.launch_url(page: page)).to start_with("http://127.0.0.1:#{service.server.port}/auth?")
    expect(File).to be_directory(Lich::WebUI::Service::ASSETS_DIR)
  end

  it 'revokes an owners pages and file routes together' do
    owner = Object.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'page', title: 'Page') {})
    service.register_files('assets', described_class::ASSETS_DIR, owner: owner)

    expect(service.terminate_owner(owner)).to eq([page])
    expect(service.file_service.resolve('assets', 'missing.png')).to be_nil
    expect(registry.size).to be_zero
  end
end
