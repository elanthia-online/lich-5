# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'api/webui'
require 'timeout'

RSpec.describe 'core-owned adapter hosting' do
  after { Lich::WebUI.reset! }

  it 'approves configured and legacy data assets through the production factory without approving unrelated roots' do
    Dir.mktmpdir('webui-host-roots-') do |directory|
      home = File.join(directory, 'home')
      configured = File.join(directory, 'relocated-data')
      legacy = File.join(home, 'data', 'uberBarWiz')
      scripts = File.join(home, 'scripts')
      outside = File.join(directory, 'outside')
      FileUtils.mkdir_p([configured, legacy, scripts, outside])
      stub_const('LICH_DIR', home)
      stub_const('DATA_DIR', configured)
      Lich::WebUI.reset!
      host = Lich::WebUI.service
      owner = Struct.new(:name).new('UberBarWiz')
      File.binwrite(File.join(legacy, 'StatusBAR.png'), 'fixture image bytes')
      File.binwrite(File.join(outside, 'private.png'), 'outside')
      File.symlink(File.join(outside, 'private.png'), File.join(legacy, 'escape.png'))
      File.symlink(outside, File.join(legacy, 'escape-directory'))
      expect(host.register_files('legacy', legacy, owner: owner, script_root: scripts)).to eq('/files/legacy/')
      expect(host.register_files('configured', configured, owner: owner, script_root: scripts)).to eq('/files/configured/')
      expect(host.file_service.resolve('legacy', 'StatusBAR.png')&.first).to eq(File.realpath(File.join(legacy, 'StatusBAR.png')))
      expect(host.file_service.resolve('legacy', 'escape.png')).to be_nil
      expect(host.file_service.resolve('legacy', '../private.png')).to be_nil
      expect { host.register_files('outside', outside, owner: owner, script_root: scripts) }.to raise_error(Lich::WebUI::Error, /outside registered/)
      expect { host.register_files('escape-directory', File.join(legacy, 'escape-directory'), owner: owner, script_root: scripts) }.to raise_error(Lich::WebUI::Error, /outside registered/)
      host.terminate_owner(owner)
      expect(host.file_service.resolve('legacy', 'StatusBAR.png')).to be_nil
      Lich::WebUI.reset!
    end
  end

  it 'does not create missing optional data roots while initializing the host' do
    Dir.mktmpdir('webui-host-missing-') do |directory|
      missing = File.join(directory, 'missing')
      stub_const('LICH_DIR', missing)
      stub_const('DATA_DIR', File.join(missing, 'relocated'))
      Lich::WebUI.reset!
      expect { Lich::WebUI.service }.not_to raise_error
      expect(File.exist?(missing)).to be(false)
      expect(Lich::WebUI.application_asset_roots).to eq([File.realpath(Lich::WebUI::Service::ASSETS_DIR)])
      Lich::WebUI.reset!
    end
  end

  it 'orders queued owner work with native callbacks on the same dispatcher' do
    owner = Object.new
    host = Lich::WebUI.service
    queue = Lich::WebUI.callback_queue(owner: owner)
    started, release, delivered = Queue.new, Queue.new, Queue.new
    queue.call { started << true; release.pop; delivered << :first }
    expect(started.pop(timeout: 2)).to be(true)
    page = host.registry.register(Lich::WebUI::Page.new(owner: owner, id: 'ordered', title: 'Ordered',
                                                        on: { attach: ->(_) { delivered << :native } }) {})
    connection = double('connection', viewer_id: 'queue-order', send_text: true)
    host.runtime.handle(connection, type: 'attach', page: host.registry.address_for(page))
    queue.call { delivered << :last }
    release << true
    expect(3.times.map { delivered.pop(timeout: 2) }).to eq(%i[first native last])
  ensure
    release&.push(true)
  end

  it 'binds a callback queue to its original host and refuses work after shutdown' do
    owner = Object.new
    queue = Lich::WebUI.callback_queue(owner: owner)
    previous = Lich::WebUI.service
    previous.stop
    expect { queue.call { raise 'must not execute' } }.to raise_error(Lich::WebUI::Error, /stopped/)
    expect(Lich::WebUI.instance_variable_get(:@service)).to equal(previous)
  end

  it 'keeps a captured scheduler on its original host after shutdown' do
    scheduler = Lich::WebUI.callback_scheduler(owner: Object.new)
    previous = Lich::WebUI.service
    previous.stop
    expect { scheduler.schedule(0) {} }.to raise_error(Lich::WebUI::Error, /stopped/)
    expect(Lich::WebUI.instance_variable_get(:@service)).to equal(previous)
  end

  it 'refuses owner work when the existing dispatcher queue reaches its bound' do
    owner = Object.new
    queue = Lich::WebUI.callback_queue(owner: owner)
    started, release = Queue.new, Queue.new
    queue.call { started << true; release.pop }
    expect(started.pop(timeout: 2)).to be(true)
    Lich::WebUI::Dispatcher::VIEWER_LIMIT.times { expect(queue.call {}).to eq(:queued) }
    expect { queue.call {} }.to raise_error(Lich::WebUI::Dispatcher::OverflowError)
  ensure
    release&.push(true)
  end

  it 'hosts and opens a page published through the author API' do
    owner = Object.new
    host = Lich::WebUI.service
    opened = Queue.new
    allow(Lich::WebUI::BrowserLauncher).to receive(:open) { |url, **| opened << url; true }
    expect(Lich::WebUI).to receive(:adapter).with(owner: owner, viewer: 'viewer-api').and_call_original
    expect(host.server).to receive(:broadcast).with(hash_including(type: 'pages')).and_call_original

    adapter = Lich::API.webui_adapter(owner: owner, viewer: 'viewer-api')
    adapter.create(:page, title: 'API setup')

    url = Timeout.timeout(2) { opened.pop }
    expect(host.server).to be_running
    page = host.registry.pages_for(owner).fetch(0)
    expect(url).to include(host.registry.address_for(page))
  end

  it 'opens the published page and creates a fresh service after launcher shutdown' do
    previous = Lich::WebUI.service
    previous.stop
    opened = Queue.new
    allow(Lich::WebUI::BrowserLauncher).to receive(:open) { |url| opened << url; true }
    owner = Object.new
    adapter = Lich::WebUI.adapter(owner: owner)
    adapter.create(:page, title: 'Script setup')

    expect(Timeout.timeout(2) { opened.pop }).to include('127.0.0.1')
    expect(Lich::WebUI.service).not_to equal(previous)
    expect(Lich::WebUI.service.registry.pages_for(owner).length).to eq(1)
  end

  it 'registers and opens a native page after the previous service stops' do
    previous = Lich::WebUI.service
    previous.stop
    opened = []
    allow(Lich::WebUI::BrowserLauncher).to receive(:open) { |url, **| opened << url; true }
    owner = Object.new
    page = Lich::WebUI.page(owner: owner, id: 'after-stop', title: 'Native setup') do
      text(key: 'status', content: 'Ready')
    end

    host = Lich::WebUI.service
    expect(host).not_to equal(previous)
    expect(host.registry.pages_for(owner)).to eq([page])
    host.refresh(page)
    host.start
    expect(Lich::WebUI.open(page: page)).to be(true)
    expect(opened.length).to eq(1)
    expect(opened.first).to include(host.registry.address_for(page))
  end
end
