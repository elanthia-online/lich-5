# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'open3'
require 'rbconfig'
require 'timeout'

# Host service boundaries: 1836:RC6, the P05 shares of 1836:RC10, 1853:RC1,
# 1853:RC2 and 1853:RC7, and 1836:RC14.
RSpec.describe 'WebUI host service boundaries' do
  let(:owner) { Object.new }
  let(:registry) { Lich::WebUI::Registry.new }
  let(:logged) { [] }
  let(:opened) { [] }
  let(:opener) { ->(url, **) { opened << url; true } }
  let(:service) do
    Lich::WebUI::Service.new(registry: registry, logger: ->(level, message) { logged << [level, message] }, browser_open: opener)
  end

  after { service.stop }

  def drain(host, who)
    marker = Queue.new
    host.runtime.dispatch(owner: who) { marker << true }
    marker.pop(timeout: 2)
  end

  describe 'closed-page lookup (1836:RC6)' do
    it 'refuses an unregistered page without inspecting it' do
      page = Lich::WebUI::Page.new(owner: owner, id: 'gone', title: 'Gone') {}
      expect(page).not_to receive(:inspect)
      expect { registry.address_for(page) }.to raise_error(Lich::WebUI::Error, /page is not registered/)
    end
  end

  describe 'file routes after owner termination (1836:RC10)' do
    it 'refuses registration after termination and host stop' do
      service.terminate_owner(owner)
      expect { service.register_files('assets', Lich::WebUI::Service::ASSETS_DIR, owner: owner) }
        .to raise_error(Lich::WebUI::Error, /terminated/)
      other = Object.new
      service.stop
      expect { service.register_files('other', Lich::WebUI::Service::ASSETS_DIR, owner: other) }
        .to raise_error(Lich::WebUI::Error, /stopped/)
    end

    it 'refuses a registration whose admission check races owner termination' do
      allow(registry).to receive(:ensure_active!).and_wrap_original do |original, who|
        original.call(who)
        service.terminate_owner(who)
      end
      expect { service.register_files('assets', Lich::WebUI::Service::ASSETS_DIR, owner: owner) }
        .to raise_error(Lich::WebUI::Error, /terminated/)
      expect(service.file_service.resolve('assets', 'index.html')).to be_nil
    end
  end

  describe 'failed window start (P05 share of 1853:RC1)' do
    let(:closes) { Queue.new }

    def closable_page
      recorder = closes
      registry.register(Lich::WebUI::Page.new(owner: owner, id: 'setup', title: 'Setup',
                                              on: { close: ->(_context) { recorder << :close } }) {})
    end

    it 'closes the owner page once and reports a safe diagnostic when the opener fails' do
      opener_result = [false]
      failing = Lich::WebUI::Service.new(registry: registry, logger: ->(level, message) { logged << [level, message] },
                                         browser_open: ->(*, **) { opener_result.first })
      failing.start
      page = closable_page
      expect(failing.open(page)).to be(false)
      drain(failing, owner)
      expect(Array.new(closes.size) { closes.pop }).to eq([:close])
      expect(failing.pending_windows?).to be(false)
      warning = logged.map(&:last).grep(/could not be opened/)
      expect(warning).to eq(['WebUI window could not be opened page=setup'])
      expect(logged.map(&:last).join).not_to match(/http|token|auth/)
    ensure
      failing&.stop
    end

    it 'reports the opener failure class without its message' do
      failing = Lich::WebUI::Service.new(registry: registry, logger: ->(level, message) { logged << [level, message] },
                                         browser_open: ->(*, **) { raise IOError, 'private-launch-detail' })
      failing.start
      page = closable_page
      expect { failing.open(page) }.to raise_error(IOError)
      expect(logged.map(&:last)).to include('WebUI window could not be opened page=setup error=IOError')
      expect(logged.map(&:last).join).not_to include('private-launch-detail')
    ensure
      failing&.stop
    end
  end

  describe 'core presentation capability (P05 share of 1853:RC2)' do
    after do
      Lich::WebUI.reset!
      Lich::WebUI.configure_presentation(enabled: nil)
    end

    it 'reads false until core configures it, without starting a host or loading compatibility code' do
      Lich::WebUI.reset!
      # Other specs in the same process may already have loaded compatibility code;
      # these calls must not load any more.
      compatibility = $LOADED_FEATURES.grep(%r{script_scope/gtk})
      Lich::WebUI.configure_presentation(enabled: nil)
      expect(Lich::WebUI.presentation_enabled?).to be(false)
      Lich::WebUI.configure_presentation(enabled: true)
      expect(Lich::WebUI.presentation_enabled?).to be(true)
      Lich::WebUI.configure_presentation(enabled: false)
      expect(Lich::WebUI.presentation_enabled?).to be(false)
      expect(Lich::WebUI.instance_variable_get(:@service)).to be_nil
      expect($LOADED_FEATURES.grep(%r{script_scope/gtk})).to eq(compatibility)
      expect { Lich::WebUI.configure_presentation(enabled: 'yes') }.to raise_error(ArgumentError)
    end

    it 'refuses native and adapter presentation without spawning when the policy is not enabled' do
      expect(Lich::WebUI::BrowserLauncher).not_to receive(:open)
      host = Lich::WebUI.service
      expect(host).not_to receive(:open)
      page = Lich::WebUI.page(owner: owner, id: 'native', title: 'Native') { text(key: 'status', content: 'Ready') }
      host.refresh(page)
      expect(Lich::WebUI.open(page: page)).to be(false)

      closed = Queue.new
      adapter_owner = Object.new
      adapter = Lich::WebUI.adapter(owner: adapter_owner)
      root = adapter.create(:page, title: 'Adapter')
      adapter.bind(root, :close, ->(_context) { closed << :close })
      expect(closed.pop(timeout: 2)).to eq(:close)
      expect(host.server).not_to be_running
    end
  end

  describe 'process-exit window cleanup (P05 share of 1853:RC7)' do
    def owned_child_after(exit_code)
      code = <<~RUBY_CODE
        require 'webui'
        $stdout.sync = true
        child = nil
        opener = lambda do |_url, on_start:, **|
          # Detached from the captured pipes, so only the exit cleanup can end it early.
          child = Process.spawn('sleep', '30', in: File::NULL, out: File::NULL, err: File::NULL)
          on_start.call(child)
          true
        end
        service = Lich::WebUI::Service.new(registry: Lich::WebUI::Registry.new, browser_open: opener, logger: ->(*) {})
        service.start
        page = service.registry.register(Lich::WebUI::Page.new(owner: Object.new, id: 'owned', title: 'Owned') {})
        service.open(page)
        puts child
        #{exit_code}
      RUBY_CODE
      output, errors, = Open3.capture3(RbConfig.ruby, '-I', LIB_DIR, '-e', code)
      pid = Integer(output.lines.first, exception: false)
      raise "fixture did not start a child: #{errors}" unless pid

      pid
    end

    def child_gone?(pid)
      Timeout.timeout(3) do
        loop do
          Process.kill(0, pid)
          sleep 0.05
        end
      end
    rescue Errno::ESRCH
      true
    rescue Timeout::Error
      Process.kill('KILL', pid)
      false
    end

    it 'terminates an owned window process when Lich exits before any viewer connects' do
      expect(child_gone?(owned_child_after('exit 0'))).to be(true)
    end

    it 'terminates an owned window process on a default-handled SIGTERM' do
      expect(child_gone?(owned_child_after("Process.kill('TERM', Process.pid); sleep 5"))).to be(true)
    end
  end

  describe 'settings form save failures (1836:RC14)' do
    it 'shows a generic message, keeps the draft and logs no values for an unexpected normalizer error' do
      messages = []
      allow(Lich).to receive(:log) { |message| messages << message }
      allow(Lich::WebUI).to receive(:refresh)
      allow(Lich::WebUI).to receive(:close)
      form = Lich::WebUI::SettingsForm.new(owner: owner, id: 'settings', title: 'Settings', values: { name: 'old' },
                                           fields: [{ key: :name, type: :text_input, label: 'Name' }],
                                           normalize: ->(_draft) { raise KeyError, 'private-normalizer-value' })
      ref = Struct.new(:cid).new('cid-name')
      form.send(:save, { 'cid-name' => 'typed draft' }, { name: ref })

      expect(form.instance_variable_get(:@completion)).not_to be_resolved
      expect(form.instance_variable_get(:@values)).to eq(name: 'typed draft')
      expect(form.instance_variable_get(:@error)).to match(/could not be saved/)
      expect(form.instance_variable_get(:@error)).not_to include('private-normalizer-value')
      expect(messages.join).to include('KeyError')
      expect(messages.join).not_to include('private-normalizer-value', 'typed draft')
      expect(Lich::WebUI).to have_received(:refresh)
    end

    it 'keeps showing ordinary validation messages' do
      allow(Lich::WebUI).to receive(:refresh)
      form = Lich::WebUI::SettingsForm.new(owner: owner, id: 'settings', title: 'Settings', values: { name: 'old' },
                                           fields: [{ key: :name, type: :text_input, label: 'Name' }],
                                           normalize: ->(_draft) { raise ArgumentError, 'Name is required' })
      form.send(:save, { 'cid-name' => '' }, { name: Struct.new(:cid).new('cid-name') })
      expect(form.instance_variable_get(:@error)).to eq('Name is required')
    end
  end
end
