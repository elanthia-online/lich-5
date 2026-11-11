# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require 'common/webui_launcher'
require_relative '../../../support/webui_launcher_fakes'
require 'open3'
require 'rbconfig'
require 'timeout'
require 'tmpdir'

RSpec.describe Lich::Common::WebUILauncher, 'controller corrections' do
  let(:entry) do
    Lich::Common::WebUILauncher::Catalog::Entry.new(
      'entry-0', 'DOUG', 'Aldor', 'GS3', 'GemStone IV', 'stormfront', nil, nil, false, nil
    )
  end
  let(:catalog) { WebUISpecSupport::Launcher::WorkflowCatalog.new(entry) }
  let(:service) { WebUISpecSupport::Launcher::WorkflowService.new }
  let(:launches) { [] }
  let(:messages) { [] }
  let(:feedback) { [] }
  let(:scheduled) { [] }
  let(:executor) { WebUISpecSupport::Launcher::ImmediateExecutor.new }
  let(:on_launch) { ->(launch, origin) { launches << [origin, launch] } }
  let(:authenticator) do
    Class.new do
      class << self
        attr_accessor :calls
      end
      self.calls = []

      def self.authenticate(**arguments)
        calls << arguments.transform_values { |value| value.is_a?(String) ? value.dup : value }
        if arguments[:legacy]
          [{ char_name: 'Aldor', game_code: 'GS3', game_name: 'GemStone IV' }]
        else
          { game: 'STORM', key: 'session-key', gamehost: 'example', gameport: '1' }
        end
      end
    end
  end
  let(:launcher_options) { {} }
  let(:launcher) do
    described_class.new(
      data_dir: '/fixture', catalog: catalog, service: service, authenticator: authenticator,
      executor: executor, on_launch: on_launch, browser_open: proc { true },
      frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator,
      recovery: ->(message) { feedback << message },
      logger: ->(level, message) { messages << [level, message] },
      **launcher_options
    )
  end

  def event(values = {}, viewer: 'viewer-1', payload: {})
    WebUISpecSupport::Launcher::Event.new(viewer, payload, Lich::WebUI::Submission.new(viewer_id: viewer, values: values))
  end

  def viewer_secret(value)
    Lich::WebUI::SensitiveValue.viewer(value)
  end

  def tree
    launcher.send(:build_page).render.tree
  end

  def find(component, cid_suffix)
    component.each.find { |candidate| candidate.cid.end_with?(cid_suffix) }
  end

  def connect_manual
    launcher.manual_connect(event({ 'account' => 'DOUG', 'password' => viewer_secret('manual-canary') }), 'account', 'password')
    launcher.manual_select(event({}, payload: { rows: ['character-0'] }))
  end

  def started_service
    registry = instance_double(Lich::WebUI::Registry, register: nil)
    instance_double(
      Lich::WebUI::Service, registry: registry, runtime: instance_double(Lich::WebUI::Runtime),
      start: nil, refresh: nil, launch_url: 'http://127.0.0.1:1234/auth?token=redacted',
      terminate_owner: nil, stop: nil
    )
  end

  describe 'launcher dialogs' do
    it 'declares the removal dialog cancel action so Escape resolves the server dialog' do
      launcher.remove_entry(event, 'entry-0')
      dialog = find(tree, 'dialog:delete-dialog')

      expect(dialog.props[:cancel_button]).to eq('cancel')
      launcher.delete_response(event({}, payload: { button: 'cancel' }))
      expect(launcher.send(:render_state)[:modal]).to be_nil
      expect(catalog.calls.map(&:first)).not_to include(:remove_entry)
    end
  end

  describe 'viewer detach' do
    let(:page) { launcher.send(:build_page) }
    let(:launcher_options) { { viewer_expiry: ->(delay, &work) { scheduled << [delay, work] } } }

    before do
      connect_manual
      launcher.remove_entry(event, 'entry-0')
    end

    def retained_credential = launcher.instance_variable_get(:@manual_credentials)['viewer-1']

    it 'keeps manual entry, credentials and dialogs for a resumable viewer' do
      credential = retained_credential
      page.lifecycle_bindings.fetch(:detach).call(event)

      state = launcher.send(:render_state)
      expect(state[:manual][:phase]).to eq(:selecting_character)
      expect(state[:modal]).to include(kind: :confirm_delete)
      expect(credential).not_to be_consumed
      expect(scheduled.map(&:first)).to eq([Lich::WebUI::ViewerStore::RECONNECT_WINDOW])

      page.lifecycle_bindings.fetch(:attach).call(event)
      scheduled.each { |_delay, work| work.call }
      expect(launcher.send(:render_state)[:manual][:phase]).to eq(:selecting_character)
      expect(credential).not_to be_consumed
      expect(launcher.lifecycle).not_to eq(:closed)
    end

    it 'discards the viewer state only when its reconnect window expires' do
      credential = retained_credential
      page.lifecycle_bindings.fetch(:detach).call(event)
      scheduled.each { |_delay, work| work.call }

      state = launcher.send(:render_state)
      expect(state[:manual][:phase]).to eq(:editing)
      expect(state[:modal]).to be_nil
      expect(credential).to be_consumed
      expect(launcher.lifecycle).not_to eq(:closed)
    end
  end

  describe 'viewer expiry with another viewer present' do
    let(:page) { launcher.send(:build_page) }
    let(:launcher_options) { { viewer_expiry: ->(delay, &work) { scheduled << [delay, work] } } }
    let(:second) { event({}, viewer: 'viewer-2') }

    def credential_of(viewer) = launcher.instance_variable_get(:@manual_credentials)[viewer]

    def lifecycle(name, viewer_event) = page.lifecycle_bindings.fetch(name).call(viewer_event)

    def second_viewer_connects_and_opens_dialog
      lifecycle(:attach, second)
      launcher.manual_connect(event({ 'account' => 'OTHER', 'password' => viewer_secret('second-canary') }, viewer: 'viewer-2'),
                              'account', 'password')
      launcher.manual_select(event({}, viewer: 'viewer-2', payload: { rows: ['character-0'] }))
      launcher.remove_entry(second, 'entry-0')
    end

    before do
      lifecycle(:attach, event)
      connect_manual
      lifecycle(:detach, event)
    end

    it 'keeps a later viewer manual entry and dialog when the earlier viewer expires' do
      first_credential = credential_of('viewer-1')
      second_viewer_connects_and_opens_dialog
      second_credential = credential_of('viewer-2')

      scheduled.each { |_delay, work| work.call }

      state = launcher.send(:render_state)
      expect(state[:manual]).to include(phase: :selecting_character, account: 'OTHER')
      expect(state[:modal]).to include(kind: :confirm_delete)
      expect(second_credential).not_to be_consumed
      expect(first_credential).to be_consumed
      expect(credential_of('viewer-1')).to be_nil
    end

    it 'keeps shared state while another viewer is inside its reconnect window, then resets it' do
      second_viewer_connects_and_opens_dialog
      lifecycle(:detach, second)
      first_expiry, second_expiry = scheduled.map(&:last)

      first_expiry.call
      expect(launcher.send(:render_state)[:manual]).to include(phase: :selecting_character, account: 'OTHER')
      expect(launcher.send(:render_state)[:modal]).to include(kind: :confirm_delete)

      second_expiry.call
      expect(launcher.send(:render_state)[:manual][:phase]).to eq(:editing)
      expect(launcher.send(:render_state)[:modal]).to be_nil
    end

    it 'resets the manual entry the departing viewer started even while another viewer is attached' do
      lifecycle(:attach, second)
      first_credential = credential_of('viewer-1')

      scheduled.each { |_delay, work| work.call }

      expect(launcher.send(:render_state)[:manual][:phase]).to eq(:editing)
      expect(first_credential).to be_consumed
    end
  end

  describe 'startup failure reporting' do
    it 'reports the host-start reason and records a failure distinct from cancellation' do
      allow(Lich::WebUI::BrowserLauncher).to receive(:open) do |_url, **options|
        options[:on_failure]&.call('unable to open WebUI window: Google Chrome is required to open the WebUI launcher window; ' \
                                   'install it, or set the Browser path in the launcher Settings to another browser')
        false
      end
      failing = described_class.new(
        data_dir: '/fixture', catalog: catalog, service: started_service, on_launch: proc {},
        frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator,
        recovery: ->(message) { feedback << message }, logger: ->(level, message) { messages << [level, message] }
      )

      expect { failing.start }.to raise_error(Lich::WebUI::Error, /Google Chrome is required/)
      expect(feedback).to contain_exactly(match(/ERROR:.*Google Chrome is required.*launcher has stopped/))
      expect(failing.failure).to match(/Google Chrome is required/)
      expect(messages).to include([:error, failing.failure])
    end

    it 'records a host exit before connection as a failure but not a connected close' do
      launcher.close(reason: :browser_process_exit)
      expect(launcher.failure).to match(/closed before connecting/)
      expect(messages).to include([:error, launcher.failure])

      connected = described_class.new(
        data_dir: '/fixture', catalog: catalog, service: WebUISpecSupport::Launcher::WorkflowService.new,
        on_launch: proc {}, browser_open: proc { true }, recovery: ->(message) { feedback << message },
        frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator, logger: proc {}
      )
      connected.viewer_attached('viewer-1')
      connected.close(reason: :browser_process_exit)
      expect(connected.failure).to be_nil
    end
  end

  describe 'launcher browser' do
    let(:chromium) { '/usr/bin/chromium' }

    def start_with(options = {}, saved: nil)
      saved_path = saved
      browsing = catalog
      browsing.define_singleton_method(:browser_path) { saved_path }
      opened = []
      allow(Lich::WebUI::BrowserLauncher).to receive(:open) do |_url, **arguments|
        opened << arguments
        true
      end
      configured = described_class.new(
        data_dir: '/fixture', catalog: browsing, service: started_service, on_launch: proc {},
        frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator,
        recovery: ->(message) { feedback << message }, logger: ->(level, message) { messages << [level, message] }, **options
      )
      yield configured if block_given?
      configured.start
      opened
    end

    let(:browser_directories) { [] }

    after { browser_directories.each { |directory| FileUtils.remove_entry(directory, true) } }

    def executable_file(name = 'chromium.exe', mode: 0o755)
      directory = Dir.mktmpdir('webui-browser')
      browser_directories << directory
      File.join(directory, name).tap do |path|
        File.write(path, '')
        File.chmod(mode, path)
      end
    end

    it 'opens the window with the saved browser path' do
      saved = executable_file
      expect(start_with(saved: saved).map { |arguments| arguments[:browser_path] }).to eq([saved])
    end

    context 'when the saved browser path is stale' do
      let(:missing) { File.join(Dir.mktmpdir('webui-browser').tap { |directory| browser_directories << directory }, 'gone', 'chromium') }

      def delivered_notice(launcher)
        launcher.viewer_attached('viewer-1')
        launcher.send(:build_page).render.facilities[:notify]
      end

      it 'logs it, falls through to the variable and detection, and names the path in a notice' do
        notice = nil
        opened = start_with(saved: missing) { |configured| notice = configured }

        expect(opened.map { |arguments| arguments[:browser_path] }).to eq([nil])
        expect(messages).to include([:warning, a_string_including('saved browser path', missing)])
        expect(delivered_notice(notice)).to eq(
          text: "The saved Browser path '#{missing}' no longer exists or is not an executable file, so it was skipped. " \
                'Save a new path in Settings, or clear it.', level: 'warn'
        )
      end

      it 'skips a saved path that exists but is not an executable file' do
        plain = executable_file('chromium', mode: 0o644)
        directory = File.dirname(plain)

        expect(start_with(saved: plain).map { |arguments| arguments[:browser_path] }).to eq([nil])
        expect(start_with(saved: directory).map { |arguments| arguments[:browser_path] }).to eq([nil])
      end

      it 'tries a working saved path first and the variable once the saved path is stale' do
        saved = executable_file('saved-browser.exe')
        variable = executable_file('variable-browser.exe')
        spawned = []
        allow(Lich::WebUI::BrowserLauncher).to receive(:open).and_wrap_original do |original, url, **arguments|
          original.call(url, **arguments, platform: 'linux', environment: { 'LICH_WEBUI_BROWSER' => variable },
                                          spawn: ->(*argv, **_options) { spawned.push(argv).length + 4241 }, waitpid: ->(*) {},
                                          thread_factory: ->(&_work) {})
        end

        [saved, missing].each do |path|
          catalog.define_singleton_method(:browser_path) { path }
          described_class.new(
            data_dir: '/fixture', catalog: catalog, service: started_service, on_launch: proc {},
            frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator, browser_terminate: ->(_signal, _pid) {},
            recovery: ->(message) { feedback << message }, logger: ->(level, message) { messages << [level, message] }
          ).start
        end

        expect(spawned.map(&:first)).to eq([saved, variable])
      ensure
        spawned.flatten.grep(/\A--user-data-dir=/).each { |argument| FileUtils.remove_entry(argument.delete_prefix('--user-data-dir='), true) }
      end

      it 'skips a saved snap-packaged Chromium path and names it as snap in the notice' do
        # Windows decides executability by extension, so the stand-in carries .exe there.
        snap = executable_file(OS.windows? ? 'chromium-browser.exe' : 'chromium-browser')
        File.write(snap, "#!/bin/sh\nexec /snap/bin/chromium \"$@\"\n")
        notice = nil
        opened = start_with(saved: snap) { |configured| notice = configured }

        expect(opened.map { |arguments| arguments[:browser_path] }).to eq([nil])
        expect(messages).to include([:warning, a_string_including('snap-packaged', snap)])
        expect(delivered_notice(notice)).to eq(
          text: "The saved Browser path '#{snap}' is snap-packaged Chromium, which cannot open the launcher, so it " \
                'was skipped. Save a non-snap Chrome or Chromium in Settings, or clear it.', level: 'warn'
        )
      end

      it 'still fails hard for an explicit browser path passed by the caller' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:open).and_wrap_original do |original, url, **arguments|
          original.call(url, **arguments, platform: 'linux', spawn: ->(*) { raise 'must not spawn' })
        end
        configured = described_class.new(
          data_dir: '/fixture', catalog: catalog, service: started_service, on_launch: proc {}, browser_path: missing,
          frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator,
          recovery: ->(message) { feedback << message }, logger: ->(level, message) { messages << [level, message] }
        )

        expect { configured.start }.to raise_error(Lich::WebUI::Error, /does not exist/)
        expect(messages.map(&:last).join).not_to include('was skipped')
      end

      it 'recovers without a window when nothing else is found' do
        stale = missing
        catalog.define_singleton_method(:browser_path) { stale }
        allow(Lich::WebUI::BrowserLauncher).to receive(:open).and_wrap_original do |original, url, **arguments|
          original.call(url, **arguments, platform: 'linux', environment: {}, spawn: ->(*) { raise 'must not spawn' })
        end
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).and_return(nil)
        configured = described_class.new(
          data_dir: '/fixture', catalog: catalog, service: started_service, on_launch: proc {},
          frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator,
          recovery: ->(message) { feedback << message }, logger: ->(level, message) { messages << [level, message] }
        )

        expect { configured.start }.to raise_error(Lich::WebUI::Error) do |error|
          expect(error.message).to include("saved Browser path '#{missing}' was skipped", 'LICH_WEBUI_BROWSER', 'restart')
        end
      end
    end

    context 'on a Chromium-only Linux host' do
      it 'reaches a launcher window through distro Chromium discovery' do
        distro = '/usr/bin/chromium'
        spawned = []
        allow(File).to receive(:executable?) { |path| path == distro }
        allow(File).to receive(:file?) { |path| path == distro }
        allow(Lich::WebUI::BrowserLauncher).to receive(:snap_browser?).and_return(false)
        allow(Lich::WebUI::BrowserLauncher).to receive(:open).and_wrap_original do |original, url, **arguments|
          original.call(url, **arguments, platform: 'x86_64-linux', environment: { 'PATH' => '/nonexistent/bin' },
                                          spawn: ->(*argv, **_options) { spawned.push(argv).length + 4241 }, waitpid: ->(*) {},
                                          thread_factory: ->(&_work) {})
        end
        configured = described_class.new(
          data_dir: '/fixture', catalog: catalog, service: started_service, on_launch: proc {},
          frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator, browser_terminate: ->(_signal, _pid) {},
          recovery: ->(message) { feedback << message }, logger: ->(level, message) { messages << [level, message] }
        )

        expect(configured.start).to be(configured)
        expect(spawned.length).to eq(1)
        expect(spawned.first.first).to eq(distro)
        expect(spawned.first).to include('--new-window')
        expect(spawned.first.last.start_with?('--app=file://')).to be(true)
        expect(feedback).to be_empty
      ensure
        spawned.flatten.grep(/\A--user-data-dir=/).each { |argument| FileUtils.remove_entry(argument.delete_prefix('--user-data-dir='), true) }
      end
    end

    it 'lets an explicit browser path win over the saved one' do
      expect(start_with({ browser_path: '/opt/other/browser' }, saved: chromium).map { |arguments| arguments[:browser_path] })
        .to eq(['/opt/other/browser'])
    end

    it 'detects Chrome or Edge automatically when no path is set' do
      expect(start_with.map { |arguments| arguments[:browser_path] }).to eq([nil])
    end

    it 'gives a configured Chromium an isolated profile that is removed after it exits' do
      # An explicit browser path must be a real executable file or open refuses it.
      Dir.mktmpdir('webui-browser') do |directory|
        browser = File.join(directory, 'chromium.exe')
        File.write(browser, '')
        File.chmod(0o755, browser)
        calls = []
        profile = nil
        spawn = lambda do |*arguments, **_options|
          calls << arguments
          profile = arguments.find { |argument| argument.start_with?('--user-data-dir=') }.delete_prefix('--user-data-dir=')
          expect(File.directory?(profile)).to be(true)
          42
        end

        expect(Lich::WebUI::BrowserLauncher.open('http://127.0.0.1:1234/auth?token=x', spawn: spawn, platform: 'linux',
                                                                                        browser_path: browser, waitpid: ->(_pid, _flags) {},
                                                                                        thread_factory: ->(&work) { work.call })).to be(true)
        expect(calls.first.first).to eq(browser)
        expect(calls.first).to include('--new-window', '--no-first-run')
        expect(File.exist?(profile)).to be(false)
      end
    end

    it 'builds the isolated-profile command for a configured browser without the native host' do
      expect(Lich::WebUI::NativeHost).not_to receive(:command_for)

      command = Lich::WebUI::BrowserLauncher.command_for('file:///launch.html', platform: 'linux', browser_path: chromium,
                                                                                profile_dir: '/tmp/profile')

      expect(command).to eq([chromium, '--new-window', '--user-data-dir=/tmp/profile', '--no-first-run',
                             '--no-default-browser-check', '--app=file:///launch.html'])
    end

    context 'when the player edits the setting' do
      let(:stored) { [] }
      let(:browser_file) do
        directory = Dir.mktmpdir('webui-browser')
        (@browser_dirs ||= []) << directory
        File.join(directory, 'chromium.exe').tap do |path|
          File.write(path, '')
          File.chmod(0o755, path)
        end
      end

      after { (@browser_dirs || []).each { |directory| FileUtils.remove_entry(directory) } }

      before do
        recorded = stored
        catalog.define_singleton_method(:update_browser_path) do |path|
          recorded << path
          true
        end
      end

      def save_browser(path) = launcher.browser_path_changed(event({ 'browser' => path }), 'browser')

      it 'states the support line and shows the saved path' do
        launcher.instance_variable_set(:@browser_path, chromium)
        launcher.setting_changed(event({}, payload: { value: true }), :settings_visible)
        rendered = tree

        expect(find(rendered, 'text_input:browser-path').props[:value]).to eq(chromium)
        support = find(rendered, 'text:browser-support').props[:content]
        expect(support).to include('Google Chrome and Microsoft Edge are supported', 'at your own risk')
        expect(support).to include('LICH_WEBUI_BROWSER')
      end

      it 'stores an executable path and uses it the next time the window opens' do
        path = browser_file
        save_browser(path)

        expect(stored).to eq([path])
        expect(launcher.send(:render_state)[:browser_path]).to eq(path)
        expect(launcher.send(:render_state)[:notice]).to include(level: 'info')
        expect(launcher.instance_variable_get(:@browser_path)).to eq(path)
      end

      it 'refuses a path that is not an absolute executable file, storing nothing' do
        save_browser('chromium')
        save_browser(File.dirname(browser_file))
        save_browser(File.join(File.dirname(browser_file), 'missing.exe'))

        expect(stored).to be_empty
        expect(launcher.send(:render_state)[:browser_path]).to be_nil
        expect(launcher.send(:render_state)[:notice]).to include(level: 'error')
      end

      it 'refuses a snap-packaged Chromium path, storing nothing' do
        snap = browser_file
        File.write(snap, "#!/bin/sh\nexec /snap/bin/chromium \"$@\"\n")
        save_browser(snap)

        expect(stored).to be_empty
        expect(launcher.send(:render_state)[:browser_path]).to be_nil
        expect(launcher.send(:render_state)[:notice]).to include(
          level: 'error', text: 'Browser path is snap-packaged Chromium, which cannot open the launcher. ' \
                                'Choose a non-snap Chrome or Chromium.'
        )
      end

      it 'clears the choice with an empty path' do
        launcher.instance_variable_set(:@browser_path, chromium)
        save_browser('  ')

        expect(stored).to eq([''])
        expect(launcher.send(:render_state)[:browser_path]).to be_nil
      end

      it 'reports a failed store and keeps the current choice' do
        catalog.define_singleton_method(:update_browser_path) { |_path| false }
        launcher.instance_variable_set(:@browser_path, chromium)
        save_browser(browser_file)

        expect(launcher.send(:render_state)[:browser_path]).to eq(chromium)
        expect(launcher.send(:render_state)[:notice][:text]).to match(/could not be saved/)
      end
    end
  end

  describe 'process-exit cleanup' do
    let(:harness) do
      <<~RUBY
        out, mode = ARGV
        require File.expand_path('spec/spec_helper', Dir.pwd)
        require 'common/webui_launcher'
        require File.expand_path('spec/support/webui_launcher_fakes', Dir.pwd)
        Lich::WebUI::BrowserLauncher.define_singleton_method(:open) do |_url, **options|
          options[:on_start].call(4242)
          true
        end
        service = Object.new
        registry = Object.new
        def registry.register(_page) = nil
        service.define_singleton_method(:registry) { registry }
        %i[runtime start stop].each { |name| service.define_singleton_method(name) { nil } }
        service.define_singleton_method(:refresh) { |_page| nil }
        service.define_singleton_method(:terminate_owner) { |_owner| nil }
        service.define_singleton_method(:launch_url) { |page:| 'http://127.0.0.1:1/launcher' }
        entry = Lich::Common::WebUILauncher::Catalog::Entry.new('entry-0', 'DOUG', 'Aldor', 'GS3', 'GemStone IV',
                                                                 'stormfront', nil, nil, false, nil)
        launcher = Lich::Common::WebUILauncher.new(
          data_dir: Dir.pwd, catalog: WebUISpecSupport::Launcher::WorkflowCatalog.new(entry), service: service,
          on_launch: proc {}, recovery: proc {}, logger: proc {},
          frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator,
          geometry_store: Struct.new(:load, :save).new({ width: 840, height: 680, position: nil }, nil),
          browser_terminate: ->(signal, pid) { File.write(out, "\#{signal} \#{pid}") }
        )
        launcher.start
        if mode == 'signal'
          Process.kill('TERM', Process.pid)
          sleep
        end
      RUBY
    end

    %w[exit signal].each do |mode|
      it "terminates the owned launcher browser on #{mode} before any viewer connects" do
        Dir.mktmpdir('launcher-exit') do |directory|
          out = File.join(directory, 'terminated')
          pid = Process.spawn(RbConfig.ruby, '-Ilib', '-e', harness, out, mode,
                              chdir: File.expand_path('../../../..', __dir__), %i[out err] => File::NULL)
          begin
            Timeout.timeout(30) { Process.wait(pid) }
          rescue Timeout::Error
            Process.kill('KILL', pid)
            Process.wait(pid)
            raise
          end

          expect(File.exist?(out) ? File.read(out) : '').to match(/\A(TERM|KILL) 4242\z/)
        end
      end
    end
  end

  describe 'browser process identity' do
    let(:terminated) { [] }
    let(:callbacks) { {} }
    let(:owned) do
      described_class.new(
        data_dir: '/fixture', catalog: catalog, service: started_service, on_launch: proc {},
        frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator, recovery: proc {}, logger: proc {},
        browser_terminate: ->(signal, pid) { terminated << [signal, pid] }
      )
    end

    before do
      allow(Lich::WebUI::BrowserLauncher).to receive(:open) do |_url, **options|
        callbacks.merge!(options)
        options[:on_start].call(4321)
        true
      end
      owned.start
    end

    it 'never signals a PID the monitor has already reaped' do
      callbacks.fetch(:on_exit).call

      expect(owned.lifecycle).to eq(:closed)
      expect(terminated).to be_empty
    end

    it 'still terminates the live owned process on an explicit close' do
      owned.close

      expect(terminated).to eq([[OS.windows? ? 'KILL' : 'TERM', 4321]])
      callbacks.fetch(:on_exit).call
      expect(terminated.size).to eq(1)
    end
  end

  describe 'notices' do
    it 'delivers a notice in one render and does not repeat it on later refreshes' do
      launcher.viewer_attached('viewer-1')
      launcher.send(:set_notice, 'Synthetic notice', :info)
      page = launcher.send(:build_page)

      expect(page.render.facilities[:notify]).to eq(text: 'Synthetic notice', level: 'info')
      expect(page.render.facilities).not_to have_key(:notify)

      launcher.send(:set_notice, 'Synthetic notice', :info)
      expect(page.render.facilities[:notify]).to eq(text: 'Synthetic notice', level: 'info')
    end

    context 'when a render reaches no viewer' do
      let(:launcher_options) { { viewer_expiry: ->(delay, &work) { scheduled << [delay, work] } } }
      let(:notified) { [] }

      before do
        seen = notified
        service.define_singleton_method(:refresh) do |page|
          seen << page.render.facilities[:notify]
          @refreshes += 1
        end
        launcher.instance_variable_set(:@page, launcher.send(:build_page))
      end

      it 'keeps the notice until a viewer attaches, then delivers it once' do
        launcher.viewer_attached('viewer-1')
        launcher.viewer_gone('viewer-1')
        launcher.send(:set_notice, 'Operation failed while reconnecting', :error)
        launcher.send(:refresh)
        expect(notified).to eq([nil, nil])

        launcher.viewer_attached('viewer-1')
        expect(notified.last).to eq(text: 'Operation failed while reconnecting', level: 'error')

        launcher.send(:refresh)
        expect(notified.last).to be_nil
        expect(notified.compact.size).to eq(1)
      end

      it 'does not refresh on attach when no notice is waiting' do
        launcher.viewer_attached('viewer-1')

        expect(notified).to be_empty
      end
    end

    it 'clears a stale failure when a later operation succeeds' do
      allow(catalog).to receive(:change_encryption_mode).and_return(false)
      launcher.change_encryption(event({ 'radio:encryption-mode' => 'plaintext', 'password_input:encryption-master' => viewer_secret(''),
                                        'checkbox:encryption-plaintext-confirm' => true }))
      expect(launcher.send(:render_state)[:notice]).to include(level: 'error')

      allow(catalog).to receive(:change_encryption_mode).and_call_original
      launcher.change_encryption(event({ 'radio:encryption-mode' => 'plaintext', 'password_input:encryption-master' => viewer_secret(''),
                                        'checkbox:encryption-plaintext-confirm' => true }))
      expect(launcher.send(:render_state)[:notice]).to be_nil
    end
  end

  describe 'unsupported saved game code' do
    before do
      catalog.entries_value = [entry.with(game_code: 'GSZ')]
      launcher.send(:reload_catalog)
      launcher.instance_variable_set(:@draft_entry_key, 'entry-0')
    end

    it 'renders the editor with an annotated repair option' do
      game = find(tree, 'select:character-game')

      expect(game.props[:value]).to eq('GSZ')
      expect(game.props[:options].last).to eq(value: 'GSZ', label: 'GSZ (unsupported; choose a replacement)')
    end

    it 'refuses to save an unsupported game code without rewriting the entry' do
      values = { 'select:character-account' => 'DOUG', 'text_input:character-name' => 'Aldor',
                 'select:character-game' => 'GSZ', 'select:character-frontend' => 'stormfront' }
      launcher.save_character(event(values))
      expect(catalog.calls).to be_empty
      expect(launcher.send(:render_state)[:notice][:text]).to eq('Choose a supported game.')

      launcher.save_character(event(values.merge('select:character-game' => 'GS3')))
      expect(catalog.calls.last).to match([:update_character, 'entry-0', hash_including(game_code: 'GS3')])
    end
  end

  describe 'manual custom launch command' do
    it 'refuses an enabled blank command before consuming credentials or launching' do
      connect_manual
      credential = launcher.instance_variable_get(:@manual_credentials)['viewer-1']
      launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront', 'checkbox:manual-custom-enabled' => true,
                                   'text_input:manual-custom' => '  ' }))

      expect(launches).to be_empty
      expect(credential).not_to be_consumed
      expect(launcher.send(:render_state)[:manual][:error]).to match(/Custom launch command is required/)

      launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront', 'checkbox:manual-custom-enabled' => false }))
      expect(launches.map(&:first)).to eq([:manual])
    end
  end

  describe 'account password change' do
    let(:changes) { [] }
    let(:accepted) { true }

    before do
      recorded = changes
      result = accepted
      catalog.define_singleton_method(:change_account_password) do |account, current, replacement|
        recorded << [account, current.dup, replacement.dup]
        result
      end
      launcher.select_managed_entry(event({}, payload: { rows: ['entry-0'] }))
    end

    def respond(current, replacement, confirmation, button: 'change')
      carriers = [current, replacement, confirmation].map { |value| viewer_secret(value) }
      launcher.change_password_response(
        event({ 'current' => carriers[0], 'new' => carriers[1], 'confirm' => carriers[2] }, payload: { button: button }),
        %w[current new confirm]
      )
      carriers
    end

    it 'offers a dedicated per-account action and dialog' do
      expect(find(tree, 'button:accounts-change-password').props[:disabled]).to be(false)
      launcher.begin_change_password(event)
      dialog = find(tree, 'dialog:change-password-dialog')

      expect(dialog.props).to include(cancel_button: 'cancel', title: 'Change Password')
      expect(dialog.props[:body]).to include('Account: DOUG')
      expect(dialog.each.select { |component| component.type == :password_input }.size).to eq(3)
    end

    it 'changes the password through the catalog provider' do
      launcher.begin_change_password(event)
      carriers = respond('old-secret', 'new-secret', 'new-secret')

      expect(changes).to eq([%w[DOUG old-secret new-secret]])
      expect(carriers).to all(be_consumed)
      expect(launcher.send(:render_state)[:modal]).to be_nil
      expect(launcher.send(:render_state)[:notice][:text]).to eq('Password changed for account DOUG.')
    end

    it 'keeps the dialog open with a fixed reason for a mismatch' do
      launcher.begin_change_password(event)
      carriers = respond('old-secret', 'new-secret', 'other-secret')

      expect(changes).to be_empty
      expect(carriers).to all(be_consumed)
      expect(launcher.send(:render_state)[:modal]).to include(kind: :change_password, error: 'New passwords do not match.')
    end

    context 'when the current password is wrong' do
      let(:accepted) { false }

      it 'reports it without echoing password contents' do
        launcher.begin_change_password(event)
        respond('wrong-secret', 'new-secret', 'new-secret')

        modal = launcher.send(:render_state)[:modal]
        expect(modal).to include(kind: :change_password, error: 'Current password was not accepted.')
        expect(modal.to_s).not_to include('wrong-secret', 'new-secret')
      end
    end

    it 'tells the player how to unlock a locked master password instead of a generic failure' do
      catalog.define_singleton_method(:change_account_password) do |*_arguments|
        raise Lich::Common::WebUILauncher::Catalog::MasterPasswordRequired, 'master password is required'
      end
      launcher.begin_change_password(event)
      respond('old-secret', 'new-secret', 'new-secret')

      expect(launcher.send(:render_state)[:modal])
        .to include(kind: :change_password, error: described_class::MASTER_PASSWORD_LOCKED_HINT)
    end

    it 'still reports other failures generically' do
      catalog.define_singleton_method(:change_account_password) { |*_arguments| raise IOError, 'synthetic' }
      launcher.begin_change_password(event)
      respond('old-secret', 'new-secret', 'new-secret')

      expect(launcher.send(:render_state)[:modal]).to include(kind: :change_password, error: 'Password change failed.')
    end

    it 'cancels without changing anything' do
      launcher.begin_change_password(event)
      respond('old-secret', 'new-secret', 'new-secret', button: 'cancel')

      expect(changes).to be_empty
      expect(launcher.send(:render_state)[:modal]).to be_nil
    end
  end

  describe 'account whose characters were all removed' do
    let(:account_row) { described_class::Catalog.account_key('DOUG') }
    let(:saved_accounts) { ['DOUG'] }

    before do
      names = saved_accounts
      catalog.entries_value = []
      catalog.define_singleton_method(:accounts) { names }
      catalog.define_singleton_method(:remove_account) do |account|
        @calls << [:remove_account, account]
        names.delete(account)
        true
      end
      launcher.send(:reload_catalog)
    end

    def table_rows = find(tree, 'table:accounts-table').props[:rows]

    it 'keeps a row for the account so Remove Account and Change Password can reach it' do
      expect(table_rows.map { |row| row[:key] }).to eq([account_row])
      expect(table_rows.first[:cells]).to include('account' => 'DOUG', 'character' => '(no characters)')
      expect(find(tree, 'button:accounts-change-password').props[:disabled]).to be(true)

      launcher.select_managed_entry(event({}, payload: { rows: [account_row] }))

      expect(find(tree, 'table:accounts-table').props[:selected]).to eq([account_row])
      expect(find(tree, 'button:accounts-change-password').props[:disabled]).to be(false)
      expect(find(tree, 'button:accounts-remove-account').props[:disabled]).to be(false)
      expect(find(tree, 'button:accounts-edit').props[:disabled]).to be(true)
      expect(find(tree, 'button:accounts-remove-character').props[:disabled]).to be(true)
    end

    it 'opens the password dialog and the removal confirmation for that account' do
      launcher.select_managed_entry(event({}, payload: { rows: [account_row] }))

      launcher.begin_change_password(event)
      expect(launcher.send(:render_state)[:modal]).to include(kind: :change_password, account: 'DOUG')

      launcher.remove_selected_account(event)
      expect(launcher.send(:render_state)[:modal]).to include(kind: :confirm_delete, account: 'DOUG')
      launcher.delete_response(event({}, payload: { button: 'remove' }))
      expect(catalog.calls).to include([:remove_account, 'DOUG'])
    end

    it 'clears the selection when the account is removed, so the page still renders' do
      launcher.select_managed_entry(event({}, payload: { rows: [account_row] }))
      launcher.remove_selected_account(event)
      launcher.delete_response(event({}, payload: { button: 'remove' }))

      removed = find(tree, 'table:accounts-table')
      expect(removed.props[:rows]).to be_empty
      expect(removed.props[:selected]).to be_empty
    end

    it 'does not offer character actions for an account row' do
      launcher.select_managed_entry(event({}, payload: { rows: [account_row] }))
      launcher.remove_selected_entry(event)

      expect(launcher.send(:render_state)[:modal]).to be_nil
    end

    context 'when the selected row disappears from the catalog' do
      let(:added) { entry }

      before do
        gained = added
        catalog.define_singleton_method(:add_character) do |_account, _character|
          @entries_value = [gained]
          true
        end
        catalog.define_singleton_method(:add_or_update_account) do |_account, _password, _characters, **_options|
          @entries_value = [gained]
          true
        end
      end

      def selected = find(tree, 'table:accounts-table').props[:selected]

      it 'drops the selected "(no characters)" row once Add Character gives the account a character' do
        launcher.select_managed_entry(event({}, payload: { rows: [account_row] }))
        launcher.save_character(event({ 'text_input:character-name' => 'Aldor', 'select:character-game' => 'GS3',
                                        'select:character-frontend' => 'stormfront', 'select:character-account' => 'DOUG' }))

        expect(selected).to be_empty
        expect(table_rows.map { |row| row[:key] }).to eq([entry.key])
        expect(find(tree, 'button:accounts-change-password').props[:disabled]).to be(true)
        expect(feedback).to be_empty
      end

      it 'drops it once re-adding the account imports characters' do
        launcher.select_managed_entry(event({}, payload: { rows: [account_row] }))
        launcher.save_account(event({ 'text_input:account-name' => 'DOUG', 'select:account-frontend' => 'stormfront',
                                      'password_input:account-password' => viewer_secret('synthetic-password') }))

        expect(selected).to be_empty
        expect(table_rows.map { |row| row[:key] }).to eq([entry.key])
        expect(feedback).to be_empty
      end

      it 'drops a selected character that a reload no longer lists' do
        catalog.entries_value = [entry]
        launcher.send(:reload_catalog)
        launcher.select_managed_entry(event({}, payload: { rows: [entry.key] }))
        expect(selected).to eq([entry.key])

        catalog.entries_value = []
        launcher.send(:reload_catalog)

        expect(selected).to be_empty
        expect(find(tree, 'button:accounts-edit').props[:disabled]).to be(true)
      end

      it 'keeps a selection whose row is still listed' do
        launcher.select_managed_entry(event({}, payload: { rows: [account_row] }))
        launcher.send(:reload_catalog)

        expect(selected).to eq([account_row])
      end
    end
  end

  describe 'persistent manual launch' do
    let(:session_launcher) { class_double(Lich::Common::SessionLauncher, launch: { ok: true }) }
    let(:launcher_options) { { persistent: true, session_launcher: session_launcher } }
    let(:credential) { launcher.instance_variable_get(:@manual_credentials)['viewer-1'] }

    before do
      connect_manual
      credential
    end

    def play_manual(values = {})
      launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront' }.merge(values)))
    end

    it 'uses the authenticated terminal launch without Save even when a matching entry exists' do
      play_manual

      expect(catalog.calls).to be_empty
      expect(session_launcher).not_to have_received(:launch)
      expect(launches).to contain_exactly([:manual, array_including('KEY=session-key', 'FRONTEND=stormfront')])
      expect(credential).to be_consumed
      expect(launcher.lifecycle).to eq(:closed)
      expect(feedback).to be_empty
    end

    it 'uses the authenticated terminal launch and custom options when no entry has been saved' do
      catalog.entries_value = []

      play_manual('checkbox:manual-custom-enabled' => true, 'text_input:manual-custom' => '/fixture/custom',
                  'text_input:manual-custom-dir' => '/fixture/work')

      expect(catalog.calls).to be_empty
      expect(session_launcher).not_to have_received(:launch)
      expect(launches).to contain_exactly([:manual, array_including('KEY=session-key', 'FRONTEND=stormfront',
                                                                    'CUSTOMLAUNCH=/fixture/custom', 'CUSTOMLAUNCHDIR=/fixture/work')])
      expect(credential).to be_consumed
      expect(launcher.lifecycle).to eq(:closed)
    end

    %i[refused raised].each do |failure|
      it "uses the authenticated terminal launch when Save is #{failure}, after disposing the password" do
        password_buffer = nil
        allow(catalog).to receive(:upsert_manual_entry) do |_entry, password|
          password_buffer = password
          raise IOError, 'synthetic save failure' if failure == :raised

          false
        end
        allow(launcher).to receive(:report_feedback).and_wrap_original do |original, notice|
          expect(credential).to be_consumed
          expect(password_buffer).to eq('')
          original.call(notice)
        end

        play_manual('checkbox:manual-save' => true)

        expect(session_launcher).not_to have_received(:launch)
        expect(launches).to contain_exactly([:manual, array_including('KEY=session-key', 'FRONTEND=stormfront')])
        expect(credential).to be_consumed
        expect(password_buffer).to eq('')
        expect(feedback).to contain_exactly('Login succeeded, but the entry or favorite was not saved.')
        expect(launcher.lifecycle).to eq(:closed)
      end
    end

    it 'keeps the launcher open and starts a child session after manual Save' do
      play_manual('checkbox:manual-save' => true)

      expect(catalog.calls.map(&:first)).to include(:save_manual)
      expect(catalog.calls.find { |call| call.first == :save_manual }.last).to eq('')
      expect(session_launcher).to have_received(:launch).with(
        kind_of(Array),
        launch_context: hash_including(char_name: 'Aldor', game_code: 'GS3', frontend: 'stormfront',
                                       data_dir: '/fixture', force_path_flags: true)
      )
      expect(credential).to be_consumed
      expect(launches).to be_empty
      expect(launcher.lifecycle).not_to eq(:closed)
      expect(launcher.send(:render_state)[:manual][:phase]).to eq(:editing)
      expect(launcher.send(:render_state)[:notice][:text]).to eq('Session launched.')
    end

    it 'preserves the manual custom command and directory on a successfully saved child launch' do
      play_manual('checkbox:manual-save' => true, 'checkbox:manual-custom-enabled' => true,
                  'text_input:manual-custom' => '/fixture/custom', 'text_input:manual-custom-dir' => '/fixture/work')

      expect(session_launcher).to have_received(:launch).with(
        array_including('CUSTOMLAUNCH=/fixture/custom', 'CUSTOMLAUNCHDIR=/fixture/work'),
        launch_context: hash_including(frontend: 'stormfront', custom_launch: '/fixture/custom',
                                       custom_launch_dir: '/fixture/work', data_dir: '/fixture', force_path_flags: true)
      )
      expect(launches).to be_empty
    end

    it 'starts a child after Favorite saves both the entry and favorite without requiring Save' do
      play_manual('checkbox:manual-favorite' => true)

      expect(catalog.calls.map(&:first)).to eq(%i[save_manual favorite])
      expect(session_launcher).to have_received(:launch)
      expect(launches).to be_empty
      expect(launcher.lifecycle).not_to eq(:closed)
      expect(feedback).to be_empty
    end

    it 'starts a child for an already-favorite entry without toggling it off' do
      catalog.entries_value = [entry.with(favorite: true)]

      play_manual('checkbox:manual-favorite' => true)

      expect(catalog.calls.map(&:first)).to eq([:save_manual])
      expect(session_launcher).to have_received(:launch)
      expect(launches).to be_empty
    end

    [false, nil].each do |result|
      it "uses the authenticated terminal launch when the favorite write returns #{result.inspect}" do
        allow(catalog).to receive(:toggle_favorite).and_return(result)

        play_manual('checkbox:manual-favorite' => true)

        expect(catalog.calls.map(&:first)).to include(:save_manual)
        expect(session_launcher).not_to have_received(:launch)
        expect(launches).to contain_exactly([:manual, array_including('KEY=session-key')])
        expect(credential).to be_consumed
        expect(feedback).to contain_exactly('Login succeeded, but the entry or favorite was not saved.')
        expect(launcher.lifecycle).to eq(:closed)
      end
    end

    it 'keeps the existing saved-entry child route and frontend/path context' do
      launcher.saved_launch(event, entry.key)

      expect(session_launcher).to have_received(:launch).with(
        array_including('FRONTEND=stormfront'),
        launch_context: hash_including(char_name: 'Aldor', game_code: 'GS3', frontend: 'stormfront',
                                       data_dir: '/fixture', force_path_flags: true)
      )
      expect(launches).to be_empty
      expect(launcher.lifecycle).not_to eq(:closed)
    end

    %i[disconnect close].each do |cancellation|
      it "refuses Save and both launch routes when #{cancellation} occurs during authentication" do
        allow(authenticator).to receive(:authenticate).and_wrap_original do |original, **arguments|
          result = original.call(**arguments)
          cancellation == :close ? launcher.close : launcher.manual_disconnect('viewer-1')
          result
        end

        play_manual('checkbox:manual-save' => true)

        expect(catalog.calls).to be_empty
        expect(session_launcher).not_to have_received(:launch)
        expect(launches).to be_empty
        expect(credential).to be_consumed
        expect(feedback).to be_empty
      end

      it "refuses the child launch when #{cancellation} follows a successful save" do
        allow(credential).to receive(:consume).and_wrap_original do |original, &work|
          result = original.call(&work)
          cancellation == :close ? launcher.close : launcher.manual_disconnect('viewer-1')
          result
        end

        play_manual('checkbox:manual-save' => true)

        expect(catalog.calls.map(&:first)).to eq([:save_manual])
        expect(session_launcher).not_to have_received(:launch)
        expect(launches).to be_empty
        expect(credential).to be_consumed
        expect(feedback).to be_empty
      end
    end
  end

  describe 'keychain capability' do
    it 'probes once at construction and on explicit refresh, never per render' do
      probes = 0
      allow(catalog).to receive(:enhanced_encryption_available?) { probes += 1; true }
      launcher
      expect(probes).to eq(1)

      3.times { tree }
      expect(probes).to eq(1)
      expect(launcher.send(:render_state)[:keychain]).to be(true)

      launcher.refresh_catalog
      expect(probes).to eq(2)
    end
  end

  describe 'window geometry' do
    let(:saved) { [] }
    let(:geometry_store) do
      store = Lich::Common::WebUILauncher::WindowGeometryStore.new(data_dir: '/fixture')
      recorded = saved
      store.define_singleton_method(:load) { { width: 840, height: 680, position: nil } }
      store.define_singleton_method(:save) { |geometry| recorded << geometry; validate(geometry) }
      store
    end
    let(:launcher_options) { { geometry_store: geometry_store } }

    def resize(width)
      launcher.window_geometry_changed(Struct.new(:payload).new({ value: JSON.generate(width: width, height: 700, position: [10, 20]) }))
    end

    it 'coalesces resize events and writes the final value once on close' do
      expect(resize(900)).to eq(width: 900, height: 700, position: [10, 20])
      resize(950)
      resize(1000)
      expect(saved).to be_empty
      expect(launcher.send(:render_state)[:window_geometry]).to eq(width: 1000, height: 700, position: [10, 20])

      launcher.close
      expect(saved).to eq([{ width: 1000, height: 700, position: [10, 20] }])
      expect(resize(1100)).to be_nil
      expect(saved.size).to eq(1)
    end

    it 'writes nothing on close when geometry did not change' do
      launcher.close
      expect(saved).to be_empty
    end
  end

  describe 'launch result publication' do
    let(:on_launch) { ->(_launch, _origin) { raise IOError, 'synthetic launch callback failure' } }

    it 'does not expose a launch whose callback failed' do
      launcher.saved_launch(event, 'entry-0')
      launcher.close

      expect(Timeout.timeout(2) { launcher.await_launch }).to be_nil
      expect(launcher.send(:render_state)[:notice][:level]).to eq('error')
    end

    context 'when the callback succeeds' do
      let(:observed) { [] }
      let(:on_launch) { ->(_launch, origin) { observed << [origin, launcher.instance_variable_get(:@launch_result)] } }

      it 'publishes the launch after the callback returns' do
        launcher.saved_launch(event, 'entry-0')

        expect(observed).to eq([[:saved_entry, nil]])
        expect(Timeout.timeout(2) { launcher.await_launch }).to be_an(Array)
      end
    end
  end

  describe 'master password change reasons' do
    def change(current, replacement, confirmation)
      launcher.change_master_password(event({
        'password_input:master-current' => viewer_secret(current),
        'password_input:master-new'     => viewer_secret(replacement),
        'password_input:master-confirm' => viewer_secret(confirmation),
      }))
      launcher.send(:render_state)[:notice][:text]
    end

    it 'names a mismatch, the minimum length and a refused current password separately' do
      expect(change('current-pass', 'replacement-1', 'replacement-2')).to eq('New master passwords do not match.')
      expect(change('current-pass', 'short', 'short')).to eq('New master password must be at least 8 characters.')
      allow(catalog).to receive(:change_master_password).and_return(false)
      expect(change('wrong-current', 'replacement', 'replacement'))
        .to eq('The current master password was not accepted, or the change could not be saved.')
      expect(messages.to_s).not_to include('current-pass', 'replacement', 'wrong-current', 'short')
    end

    it 'refuses edge whitespace through the shared new-password check, saving nothing' do
      checked = []
      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:new_password_refusal).and_wrap_original do |original, password|
        checked << password.dup
        original.call(password)
      end
      expect(catalog).not_to receive(:change_master_password)

      expect(change('current-pass', ' replacement-1', ' replacement-1'))
        .to eq('New master password cannot begin or end with whitespace.')
      expect(checked).to eq([' replacement-1'])
    end
  end

  describe 'encryption mode change reasons' do
    def switch(mode, master, confirmation = master)
      launcher.change_encryption(event({
        'radio:encryption-mode'             => mode,
        'password_input:encryption-master'  => viewer_secret(master),
        'password_input:encryption-confirm' => viewer_secret(confirmation),
      }))
      launcher.send(:render_state)[:notice]
    end

    def changes = catalog.calls.select { |call| call.first == :change_encryption }

    context 'when creating an Enhanced master password' do
      it 'names empty, mismatched and too short passwords separately, writing nothing' do
        expect(switch('enhanced', '')).to include(level: 'error', text: 'Master password cannot be empty.')
        expect(switch('enhanced', 'eightchr', 'eightchs')).to include(level: 'error', text: 'New master passwords do not match.')
        expect(switch('enhanced', 'seven77')).to include(
          level: 'error', text: "New master password must be at least #{described_class::MASTER_PASSWORD_MIN_LENGTH} characters."
        )

        expect(changes).to be_empty
        expect(messages.to_s).not_to include('eightchr', 'eightchs', 'seven77')
      end

      it 'refuses edge whitespace through the shared new-password check, writing nothing' do
        checked = []
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:new_password_refusal).and_wrap_original do |original, password|
          checked << password.dup
          original.call(password)
        end

        expect(switch('enhanced', 'new-secret ')).to include(
          level: 'error', text: 'New master password cannot begin or end with whitespace.'
        )
        expect(checked).to eq(['new-secret '])
        expect(changes).to be_empty
      end

      it 'refuses with the same text the replacement workflow uses' do
        launcher.change_master_password(event({ 'password_input:master-current' => viewer_secret('current-pass'),
                                                'password_input:master-new'     => viewer_secret('seven77'),
                                                'password_input:master-confirm' => viewer_secret('seven77') }))
        replacement = launcher.send(:render_state)[:notice][:text]

        expect(switch('enhanced', 'seven77')[:text]).to eq(replacement)
      end

      it 'accepts exactly the minimum length' do
        written = []
        allow(catalog).to receive(:change_encryption_mode) do |mode, master_password:|
          written << [mode, master_password.dup]
          true
        end

        expect(switch('enhanced', 'eightchr')).to be_nil
        expect(written).to eq([[:enhanced, 'eightchr']])
      end

      it 'keeps the generic message for a failure that is not a password refusal' do
        allow(catalog).to receive(:change_encryption_mode).and_return(false)

        expect(switch('enhanced', 'eightchr')).to include(text: 'Encryption mode change failed. Check the password and confirmation.')
      end
    end

    context 'when leaving Enhanced mode' do
      before { catalog.mode = :enhanced }

      it 'names an empty and a refused current master password separately' do
        expect(switch('standard', '')).to include(level: 'error', text: 'Master password cannot be empty.')
        catalog.master_valid = false
        expect(switch('standard', 'wrong-master')).to include(level: 'error', text: 'The current master password was not accepted.')

        expect(changes).to be_empty
        expect(messages.to_s).not_to include('wrong-master')
      end

      it 'applies no length rule to the existing master password' do
        expect(switch('standard', 'old')).to be_nil
        expect(changes).to eq([[:change_encryption, :standard, nil]])
      end

      it 'checks an existing master password with edge spaces as typed' do
        checked = []
        catalog.define_singleton_method(:validate_master_password) { |password| checked << password.dup; true }

        expect(switch('standard', ' padded ')).to be_nil
        expect(checked).to eq([' padded '])
      end
    end
  end

  describe 'legacy entry.dat users' do
    around do |example|
      Dir.mktmpdir('launcher-legacy') do |directory|
        @data_dir = directory
        legacy = [{ user_id: 'DOUG', password: 'legacy-secret', char_name: 'Aldor', game_code: 'GS3',
                    game_name: 'GemStone IV', frontend: 'stormfront' }]
        File.binwrite(File.join(directory, 'entry.dat'), [Marshal.dump(legacy)].pack('m'))
        example.run
      end
    end

    let(:catalog) do
      described_class::Catalog.new(data_dir: @data_dir, master_password_manager: double(keychain_available?: false))
    end

    it 'shows a non-modal conversion notice while keeping legacy reads and the write guard' do
      rendered = tree
      notice = find(rendered, 'text:legacy-conversion')

      expect(notice.props[:content]).to include('--convert-entries', 'release notes')
      expect(notice.props[:tone]).to eq('caution')
      expect(launcher.send(:render_state)[:modal]).to be_nil
      expect(find(rendered, 'group:entry-0')).to be_nil
      expect(launcher.send(:render_state)[:entries].map(&:char_name)).to eq(['Aldor'])

      launcher.save_character(event({ 'select:character-account' => 'DOUG', 'text_input:character-name' => 'Cera',
                                       'select:character-game' => 'GS3', 'select:character-frontend' => 'stormfront' }))
      expect(launcher.send(:render_state)[:notice][:text]).to eq(described_class::Catalog::LEGACY_CONVERSION_NOTICE)
      expect(Dir.children(@data_dir)).to eq(['entry.dat'])
    end
  end

  describe 'account component keys' do
    let(:names) { ["O'BRIEN+ X", 'A B', 'A_B', 'L' * 150] }

    before do
      catalog.entries_value = names.each_with_index.map do |name, index|
        entry.with(key: "entry-#{index}", user_id: name, char_name: "Char#{index}")
      end
      launcher.send(:reload_catalog)
    end

    it 'uses distinct identifier-safe keys while labels, slots and authentication keep the name' do
      tab_tree = tree
      tabs = find(tab_tree, 'tabs:saved-account-tabs')
      panels = tabs.children.drop(1)

      expect(tabs.props[:names]).to eq(['FAVORITES'] + names)
      expect(panels.map(&:slot)).to eq(names)
      expect(panels.map { |panel| panel.props[:key] }.uniq.size).to eq(names.size)
      expect(panels.map { |panel| panel.props[:key] }).to all(match(/\Asaved-account-\h{64}\z/))

      launcher.setting_changed(event({}, payload: { value: false }), :tab_layout)
      groups = tree.each.select { |component| component.type == :group && component.cid.match?(/group:saved-list-account-\h{64}\z/) }
      expect(groups.map { |group| group.props[:label] }).to eq(names.map { |name| "Account: #{name.downcase}" })
      expect(groups.map { |group| group.props[:key] }.uniq.size).to eq(names.size)

      launcher.saved_launch(event, 'entry-0')
      expect(authenticator.calls.last[:account]).to eq("O'BRIEN+ X")
    end
  end

  describe 'saved-entry Play while authenticating' do
    let(:queued) { [] }
    let(:executor) do
      work = queued
      Object.new.tap do |deferred|
        deferred.define_singleton_method(:post) { |cleanup: nil, &block| work << [block, cleanup]; true }
        deferred.define_singleton_method(:stop) { |wait: true| wait }
      end
    end

    it 'delivers a disabled Play to the viewer once the launch begins, and still refuses an overlapping launch' do
      # A rebuilt page always reflects the active operation, so only the render the
      # service delivered at each refresh shows what the viewer actually sees.
      delivered = []
      service.define_singleton_method(:refresh) do |page|
        delivered << page.render.tree
        @refreshes += 1
      end
      launcher.instance_variable_set(:@page, launcher.send(:build_page))
      launcher.send(:refresh)
      expect(find(delivered.last, 'button:play-entry-0').props[:disabled]).to be_falsey

      launcher.saved_launch(event, 'entry-0')

      expect(find(delivered.last, 'button:play-entry-0').props[:disabled]).to be(true)
      expect { launcher.saved_launch(event, 'entry-0') }.to raise_error(Lich::WebUI::Error, /already active/)
    end
  end
end
