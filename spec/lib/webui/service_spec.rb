# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'timeout'

RSpec.describe Lich::WebUI::Service do
  subject(:service) { described_class.new(registry: registry) }

  let(:registry) { Lich::WebUI::Registry.new }

  after { service.stop }

  it 'refreshes open native and adapter pages on theme changes without replacing explicit palettes' do
    allow(Lich).to receive(:track_dark_mode).and_return(false)
    pages = [{}, { theme: :light }, { theme: :dark }].each_with_index.map do |props, index|
      registry.register(Lich::WebUI::Page.new(owner: self, id: "theme-#{index}", title: 'Theme', props: props) {})
    end
    published = Queue.new
    adapter = Lich::WebUI::Adapter.new(owner: self, service: service, on_publish: proc { |page| published << page })
    adapter.create(:page, title: 'Shim')
    shim = Timeout.timeout(2) { published.pop }
    pages.each { |page| service.refresh(page) }
    allow(Lich).to receive(:track_dark_mode).and_return(true)
    service.refresh_theme
    expect(pages.map { |page| page.last_render.tree.props[:theme] }).to eq(%w[dark light dark])
    expect(shim.last_render.tree.props[:theme]).to eq('dark')
    expect(service.server).not_to be_running
  end

  it 'reports callback failures through the default Lich logger without logging exception values' do
    messages = Queue.new
    allow(Lich).to receive(:log) { |message| messages << message }
    dispatcher = service.runtime.instance_variable_get(:@dispatcher)
    dispatcher.enqueue(owner: Object.new, page_id: 'page', viewer_id: 'viewer', cid: 'button',
                       event: :activate, coalescable: false) { raise 'private-test-value' }

    message = Timeout.timeout(1) { messages.pop }
    expect(message).to include('RuntimeError', 'service_spec.rb')
    expect(message).not_to include('private-test-value')
  end

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
