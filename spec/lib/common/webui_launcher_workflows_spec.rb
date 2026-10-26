# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../login_spec_helper'
require 'common/webui_launcher'
require_relative '../../support/webui_launcher_fakes'
require 'timeout'

RSpec.describe Lich::Common::WebUILauncher, 'actual-core workflows' do
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
  let(:executor) { WebUISpecSupport::Launcher::ImmediateExecutor.new }
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
  let(:launcher) do
    described_class.new(
      data_dir: '/fixture', catalog: catalog, service: service, authenticator: authenticator,
      executor: executor, on_launch: ->(launch, origin) { launches << [origin, launch] },
      browser_open: proc { true }, frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator,
      recovery: ->(message) { feedback << message },
      logger: ->(level, message) { messages << [level, message] }
    )
  end

  def event(values = {}, viewer: 'viewer-1', payload: {})
    WebUISpecSupport::Launcher::Event.new(viewer, payload, Lich::WebUI::Submission.new(viewer_id: viewer, values: values))
  end

  def viewer_secret(value)
    Lich::WebUI::SensitiveValue.viewer(value)
  end

  it 'refuses preference writes after launcher closure' do
    launcher.close
    launcher.setting_changed(event({}, payload: { value: true }), :dark_theme)

    expect(catalog.calls).to be_empty
    expect(launcher.send(:render_state)[:dark_theme]).to be(false)
  end

  it 'applies both theme toggle values to the launcher and persists through the existing catalog' do
    host = Lich::WebUI::Service.new
    allow(self).to receive(:service).and_return(host)
    launcher.start
    [true, false].each do |dark|
      launcher.setting_changed(event({}, payload: { value: dark }), :dark_theme)
      expect(catalog.calls).to include([:setting, :dark_theme, dark])
      expect(launcher.render_tree.props[:theme]).to eq(dark ? 'dark' : 'light')
    end
  ensure
    launcher.close
    host&.stop
  end

  context 'cancellation with the real launcher worker' do
    let(:executor) { described_class::SerialExecutor.new }
    let(:started) { Queue.new }
    let(:release) { Queue.new }
    let(:carriers) { [] }

    before do
      allow(Lich::WebUI::SensitiveValue).to receive(:viewer).and_wrap_original do |original, value|
        original.call(value).tap { |carrier| carriers << carrier }
      end
    end

    after do
      release << true
      launcher.close
      executor.stop
    end

    it 'cancels a queued master-password write and clears its transferred carriers' do
      executor.post { started << true; release.pop }
      Timeout.timeout(2) { started.pop }
      launcher.change_master_password(event({
        'password_input:master-current' => viewer_secret('synthetic-current'),
        'password_input:master-new'     => viewer_secret('synthetic-replacement'),
        'password_input:master-confirm' => viewer_secret('synthetic-replacement'),
      }))
      launcher.close

      expect(carriers.size).to eq(6)
      expect(carriers).to all(be_consumed)
      release << true
      executor.stop
      expect(catalog.calls).to be_empty
    end

    it 'refuses an account write after authentication returns to an already closed launcher' do
      allow(authenticator).to receive(:authenticate) do
        started << true
        release.pop
        [{ char_name: 'Aldor', game_code: 'GS3' }]
      end
      launcher.save_account(event({ 'text_input:account-name' => 'DOUG', 'select:account-frontend' => 'stormfront',
                                   'password_input:account-password' => viewer_secret('synthetic-account') }))
      Timeout.timeout(2) { started.pop }
      launcher.close
      release << true
      executor.stop

      expect(catalog.calls).to be_empty
      expect(carriers).to all(be_consumed)
    end

    it 'disposes credentials produced by manual authentication that completes after close' do
      allow(authenticator).to receive(:authenticate) do
        started << true
        release.pop
        [{ char_name: 'Aldor', game_code: 'GS3' }]
      end
      launcher.manual_connect(event({ 'account' => 'DOUG', 'password' => viewer_secret('synthetic-account') }),
                              'account', 'password')
      Timeout.timeout(2) { started.pop }
      launcher.close
      release << true
      executor.stop

      expect(carriers.size).to eq(3)
      expect(carriers).to all(be_consumed)
      expect(launches).to be_empty
    end

    it 'does not launch a saved session after close wins during authentication' do
      allow(authenticator).to receive(:authenticate) do
        started << true
        release.pop
        { game: 'STORM', key: 'synthetic-key', gamehost: 'example', gameport: '1' }
      end
      launcher.saved_launch(event, 'entry-0')
      Timeout.timeout(2) { started.pop }
      launcher.close
      release << true
      executor.stop

      expect(launches).to be_empty
    end

    it 'lets an admitted write finish before close completes' do
      writes = []
      allow(catalog).to receive(:change_master_password) do
        started << true
        release.pop
        writes << :saved
        true
      end
      launcher.change_master_password(event({
        'password_input:master-current' => viewer_secret('synthetic-current'),
        'password_input:master-new'     => viewer_secret('synthetic-replacement'),
        'password_input:master-confirm' => viewer_secret('synthetic-replacement'),
      }))
      Timeout.timeout(2) { started.pop }
      closer = Thread.new { launcher.close; writes << :closed }
      Timeout.timeout(2) { Thread.pass until closer.status == 'sleep' || !closer.alive? }
      expect(writes).to be_empty
      release << true
      Timeout.timeout(2) { closer.join }
      executor.stop
      expect(writes).to eq(%i[saved closed])
    ensure
      release << true
      closer&.join
    end
  end

  it 'launches a saved entry with an Origin B credential that never enters the render tree' do
    launcher.saved_launch(event, 'entry-0')

    expect(authenticator.calls.last[:password]).to eq('origin-b-saved-canary')
    expect(launches.last.first).to eq(:saved_entry)
    tree_text = launcher.send(:build_page).render.tree.to_h.to_s
    expect(tree_text).not_to include('origin-b-saved-canary')
  end

  it 'refuses a saved frontend that disappears before Play without unlocking or authenticating' do
    launcher
    allow(WebUISpecSupport::Launcher::WorkflowFrontendLocator).to receive(:resolve).and_return(nil)

    launcher.saved_launch(event, entry.key)

    expect(catalog.calls).to be_empty
    expect(authenticator.calls).to be_empty
    expect(launches).to be_empty
    expect(launcher.active_operations).to be_empty
    expect(launcher.send(:render_state)[:notice][:text]).to match(/front end is unavailable.*Frontends/)
    expect(WebUISpecSupport::Launcher::WorkflowFrontendLocator).to have_received(:resolve).with('stormfront', refresh: true).at_least(:once)
  end

  it 'retains an explicit saved custom command when its stock frontend is not detected' do
    catalog.entries_value = [entry.with(custom_launch: '/fixture/custom')]
    allow(WebUISpecSupport::Launcher::WorkflowFrontendLocator).to receive(:resolve).and_return(nil)

    launcher.saved_launch(event, entry.key)

    expect(authenticator.calls.length).to eq(1)
    expect(launches.last.first).to eq(:saved_entry)
    expect(launches.last.last).to include('CUSTOMLAUNCH=/fixture/custom')
  end

  it 'rechecks frontend availability after unlock without authenticating or retaining the credential' do
    catalog.require_master = true
    launcher.saved_launch(event, entry.key)
    expect(launcher.send(:render_state)[:modal]).to include(kind: :unlock)
    credential = Lich::WebUI::SensitiveValue.server('unlocked-fixture')
    allow(catalog).to receive(:credential).and_return(credential)
    allow(credential).to receive(:discard!).and_call_original
    allow(WebUISpecSupport::Launcher::WorkflowFrontendLocator).to receive(:resolve).and_return(nil)

    launcher.unlock_response(event({ 'password' => viewer_secret('correct') }, payload: { button: 'unlock' }), 'password')

    expect(authenticator.calls).to be_empty
    expect(launches).to be_empty
    expect(credential).to have_received(:discard!)
    expect(launcher.send(:render_state)[:modal]).to be_nil
    expect(launcher.send(:render_state)[:notice][:text]).to match(/front end is unavailable/)
  end

  it 'supports master-password unlock failure, retry, success, and cancel' do
    catalog.require_master = true
    launcher.saved_launch(event, 'entry-0')
    expect(launcher.send(:render_state)[:modal]).to include(kind: :unlock)

    catalog.master_valid = false
    launcher.unlock_response(event({ 'password' => viewer_secret('wrong') }, payload: { button: 'unlock' }), 'password')
    expect(launcher.send(:render_state)[:modal][:error]).to match(/not accepted/)

    catalog.master_valid = true
    launcher.unlock_response(event({ 'password' => viewer_secret('correct') }, payload: { button: 'unlock' }), 'password')
    expect(launches.last.first).to eq(:saved_entry)

    alternate = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WebUISpecSupport::Launcher::WorkflowService.new, executor: WebUISpecSupport::Launcher::ImmediateExecutor.new,
      on_launch: proc {}, browser_open: proc { true }
    )
    alternate.instance_variable_set(:@modal, { kind: :unlock, entry_key: 'entry-0' })
    alternate.unlock_response(event({}, payload: { button: 'cancel' }), 'password')
    expect(alternate.send(:render_state)[:modal]).to be_nil
  end

  it 'renders the real initial unlock, retry and cancel with the password inside the modal' do
    page = launcher.send(:build_page)
    launcher.instance_variable_set(:@page, page)
    allow(service).to receive(:refresh) { |target| target.render }
    catalog.require_master = true
    launcher.saved_launch(event, 'entry-0')
    initial = page.last_render
    dialog = initial.tree.each.find { |node| node.type == :dialog }
    secret = dialog.children.find { |node| node.type == :password_input }
    expect(dialog.props[:body]).to eq('')
    expect(initial.submissions[dialog.cid]).to eq([secret.cid])
    catalog.master_valid = false
    initial.bindings.fetch([dialog.cid, :response]).call(event({ secret.cid => viewer_secret('wrong') }, payload: { button: 'unlock' }))
    expect(page.last_render.tree.each.find { |node| node.type == :dialog }.props[:body]).to match(/not accepted/)
    page.last_render.bindings.fetch([dialog.cid, :response]).call(event({}, payload: { button: 'cancel' }))
    expect(page.last_render.tree.each.map(&:type)).not_to include(:dialog)
    expect(feedback).to be_empty
  end

  it 'keeps removed frontend metadata repairable and requires an explicit valid replacement' do
    catalog.entries_value = [entry.with(frontend: 'removed-custom')]
    launcher.refresh_catalog
    launcher.instance_variable_set(:@draft_entry_key, 'entry-0')
    page = launcher.send(:build_page)
    control = page.render.tree.each.find { |node| node.cid.end_with?('select:character-frontend') }
    expect(control.props[:value]).to eq('removed-custom')
    expect(control.props[:options]).to include(hash_including(value: 'removed-custom', label: /removed/))
    values = { 'text_input:character-name' => 'Aldor', 'select:character-game' => 'GS3',
               'select:character-frontend' => 'removed-custom', 'select:character-account' => 'DOUG' }
    launcher.save_character(event(values))
    expect(catalog.calls.none? { |call| call.first == :update_character }).to be(true)
    launcher.save_character(event(values.merge('select:character-frontend' => 'stormfront')))
    expect(catalog.calls).to include([:update_character, 'entry-0', hash_including(frontend: 'stormfront')])
  end

  it 'reports refused renders independently and redacts exception messages without recursively rendering' do
    page = launcher.send(:build_page)
    launcher.instance_variable_set(:@page, page)
    page.render
    prior = page.last_render
    failure = Lich::WebUI::SchemaViolationError.new('password-canary secret-url', page_id: 'launcher', cid: 'dialog:unlock', field: 'body')
    allow(service).to receive(:refresh).and_raise(failure)
    launcher.send(:refresh)
    expect(service).to have_received(:refresh).once
    expect(page.last_render).to equal(prior)
    expect(messages.last.last).to include('SchemaViolationError', 'field=body', 'cid=dialog:unlock')
    expect(feedback.last).to include('previous screen is retained')
    expect([messages, feedback].inspect).not_to include('password-canary', 'secret-url')
    allow(launcher).to receive(:report_feedback).and_call_original
    launcher.instance_variable_set(:@recovery, ->(_message) { raise 'notifier unavailable' })
    expect { launcher.send(:refresh) }.not_to raise_error
    expect(service).to have_received(:refresh).twice
  end

  it 'runs manual authentication, selection, save, favorite, and launch through core collaborators' do
    connect = event({ 'account' => 'doug', 'password' => viewer_secret('manual-canary') })
    launcher.manual_connect(connect, 'account', 'password')
    launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront' }))
    expect(launches).to be_empty
    expect(launcher.send(:render_state)[:manual][:error]).to match(/select a character/)

    launcher.manual_select(event({}, payload: { rows: ['character-0'] }))
    launch = event({
      'select:manual-frontend' => 'stormfront', 'checkbox:manual-custom-enabled' => false,
      'text_input:manual-custom' => '', 'text_input:manual-custom-dir' => '',
      'checkbox:manual-save' => true, 'checkbox:manual-favorite' => true,
    })
    launcher.manual_play(launch)

    expect(catalog.calls.map(&:first)).to include(:save_manual, :favorite)
    expect(launches.last.first).to eq(:manual)
    expect(authenticator.calls.map { |call| call[:password] }).to include('manual-canary')
    expect(WebUISpecSupport::Launcher::WorkflowFrontendLocator.resolved).to include(['stormfront', true])
  end

  it 'distinguishes account authentication failure from successful master-password unlock' do
    catalog.require_master = true
    launcher.saved_launch(event, 'entry-0')
    allow(authenticator).to receive(:authenticate).and_raise(StandardError, 'private-auth-error')

    launcher.unlock_response(event({ 'password' => viewer_secret('correct') }, payload: { button: 'unlock' }), 'password')

    state = launcher.send(:render_state)
    expect(state[:modal]).to be_nil
    expect(state[:notice][:text]).to match(/account authentication failed/i)
    expect(state[:notice][:text]).not_to include('private-auth-error', 'Master password')
    expect(launcher.active_operations).to be_empty
    expect(launches).to be_empty
  end

  it 'reports launch preparation separately from account authentication' do
    allow(Lich::Common::Authentication::LaunchData).to receive(:prepare).and_raise(StandardError, 'private-launch-error')
    launcher.saved_launch(event, 'entry-0')
    expect(launcher.send(:render_state)[:notice][:text]).to match(/launch preparation failed/i)
    expect(messages.to_s).not_to include('private-launch-error')
  end

  it 'explains when a selected manual frontend is no longer available' do
    launcher.manual_connect(event({ 'account' => 'DOUG', 'password' => viewer_secret('manual-canary') }), 'account', 'password')
    launcher.manual_select(event({}, payload: { rows: ['character-0'] }))
    allow(WebUISpecSupport::Launcher::WorkflowFrontendLocator).to receive(:resolve).and_return(nil)
    launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront' }))
    expect(launcher.send(:render_state)[:manual][:error]).to match(/front end is unavailable.*Frontends/)
    expect(launches).to be_empty
  end

  it 'reports a host exit before first attachment once and still completes cleanup' do
    reporting_states = []
    launcher.instance_variable_set(:@recovery, proc do |message|
      feedback << message
      reporting_states << launcher.lifecycle
    end)
    expect(launcher.close(reason: :browser_process_exit)).to be(true)
    expect(launcher.close(reason: :browser_process_exit)).to be(false)
    expect(feedback).to contain_exactly(match(/closed before connecting/))
    expect(messages).to include([:info, 'WebUI launcher closed reason=browser_process_exit'])
    expect(reporting_states).to eq([:closing]) # Report before await_launch releases the main thread.
    expect(service.stopped).to be(true)
  end

  it 'does not report ordinary closure of a connected window as a startup failure' do
    launcher.viewer_attached
    launcher.close(reason: :browser_process_exit)
    expect(feedback).to be_empty
    expect(service.stopped).to be(true)
  end

  it 'releases an existing launch waiter and reports early closure even when logging fails' do
    launcher.instance_variable_set(:@logger, proc { raise IOError, 'logger failed' })
    closed = []
    launcher.instance_variable_set(:@on_close, proc { |reason| closed << reason })
    waiting = Queue.new
    condition = launcher.instance_variable_get(:@closed_condition)
    allow(condition).to receive(:wait).and_wrap_original do |original, *args|
      waiting << true
      original.call(*args)
    end
    waiter = Thread.new { launcher.await_launch }
    Timeout.timeout(2) { waiting.pop }

    expect(launcher.close(reason: :browser_process_exit)).to be(true)
    expect(waiter.join(2)).to equal(waiter)
    expect(waiter.value).to be_nil
    expect(service.stopped).to be(true)
    expect(feedback).to contain_exactly(match(/closed before connecting/))
    expect(closed).to eq([:browser_process_exit])
  ensure
    waiter&.kill
    waiter&.join
  end

  it 'signals closure while preserving a teardown exception' do
    error = IOError.new('stop failed')
    allow(service).to receive(:stop).and_raise(error)

    expect { launcher.close }.to(raise_error { |actual| expect(actual).to equal(error) })
    expect(launcher.lifecycle).to eq(:closed)
    expect(Timeout.timeout(2) { launcher.await_launch }).to be_nil
  end

  %i[terminate_owner stop executor_stop all].each do |failure|
    it "attempts all teardown and close reporting when #{failure} fails" do
      attempts = []
      error = IOError.new('first teardown failure')
      allow(service).to receive(:terminate_owner) do
        attempts << :terminate_owner
        raise error if %i[terminate_owner all].include?(failure)
      end
      allow(service).to receive(:stop) do
        attempts << :stop
        raise(failure == :all ? IOError.new('later failure') : error) if %i[stop all].include?(failure)
      end
      allow(executor).to receive(:stop).with(wait: false) do
        attempts << :executor_stop
        raise(failure == :all ? IOError.new('later failure') : error) if %i[executor_stop all].include?(failure)
      end
      launcher.instance_variable_set(:@on_close, proc do |reason|
        attempts << :on_close
        expect(reason).to eq(:browser_process_exit)
        expect(launcher.lifecycle).to eq(:closed)
        raise IOError, 'callback failure' if failure == :all
      end)

      expect { launcher.close(reason: :browser_process_exit) }.to(raise_error { |actual| expect(actual).to equal(error) })
      expect(attempts).to eq(%i[terminate_owner stop executor_stop on_close])
      expect(messages).to include([:info, 'WebUI launcher closed reason=browser_process_exit'])
      expect(feedback).to contain_exactly(match(/closed before connecting/))
      expect(Timeout.timeout(2) { launcher.await_launch }).to be_nil
      expect(launcher.close).to be(false)
    end
  end

  it 'discards an unlock submission if its modal has already closed' do
    secret = viewer_secret('late-secret')

    expect(launcher.unlock_response(
             event({ 'password' => secret }, payload: { button: 'unlock' }), 'password'
           )).to be_nil
    expect(secret).to be_consumed
    expect(catalog.calls).to be_empty
  end

  [Lich::Common::WebUILauncher::Catalog::MasterPasswordRequired,
   Lich::Common::WebUILauncher::Catalog::LegacyConversionRequired, IOError, false].each do |failure|
    it "still launches after optional manual persistence fails with #{failure}" do
      if failure
        allow(catalog).to receive(:upsert_manual_entry).and_raise(failure, 'synthetic-secret-must-not-be-logged')
      else
        allow(catalog).to receive(:upsert_manual_entry).and_return(false)
      end
      launcher.manual_connect(event({ 'account' => 'doug', 'password' => viewer_secret('manual-canary') }),
                              'account', 'password')
      launcher.manual_select(event({}, payload: { rows: ['character-0'] }))
      launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront', 'checkbox:manual-save' => true }))

      expect(launches.size).to eq(1)
      expect(launches.first.first).to eq(:manual)
      expect(messages).to include([:warning, a_string_matching(/not saved/)])
      expect(feedback).to contain_exactly(match(/not saved/))
      expect(messages.to_s).not_to include('synthetic-secret-must-not-be-logged', 'manual-canary')
      expect(messages.to_s).to include('--convert-entries') if failure == described_class::Catalog::LegacyConversionRequired
    end
  end

  it 'still launches and reports a failed optional favorite write' do
    allow(catalog).to receive(:toggle_favorite).and_return(nil)
    launcher.manual_connect(event({ 'account' => 'doug', 'password' => viewer_secret('manual-canary') }),
                            'account', 'password')
    launcher.manual_select(event({}, payload: { rows: ['character-0'] }))
    launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront', 'checkbox:manual-favorite' => true }))

    expect(launches.size).to eq(1)
    expect(messages).to include([:warning, a_string_matching(/not saved/)])
    expect(feedback).to contain_exactly(match(/not saved/))
  end

  it 'still reports an optional save failure and launches when its warning logger fails' do
    allow(catalog).to receive(:upsert_manual_entry).and_return(false)
    launcher.instance_variable_set(:@logger, proc { raise IOError, 'logger failed' })
    launcher.manual_connect(event({ 'account' => 'doug', 'password' => viewer_secret('manual-canary') }),
                            'account', 'password')
    launcher.manual_select(event({}, payload: { rows: ['character-0'] }))
    launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront', 'checkbox:manual-save' => true }))

    expect(launches.size).to eq(1)
    expect(launches.first.first).to eq(:manual)
    expect(feedback).to contain_exactly(match(/not saved/))
  end

  [false, true].each do |cancel|
    it "preserves #{cancel ? 'cancellation' : 'launch'} when save feedback #{cancel ? 'closes the launcher' : 'raises'}" do
      allow(catalog).to receive(:upsert_manual_entry).and_return(false)
      allow(launcher).to receive(:report_feedback).and_wrap_original do |original, message|
        expect(launcher.instance_variable_get(:@commit_mutex).mon_owned?).to be(false)
        original.call(message)
      end
      launcher.instance_variable_set(:@recovery, proc do |_message|
        cancel ? launcher.close : raise(IOError, 'private notifier error')
      end)
      launcher.manual_connect(event({ 'account' => 'DOUG', 'password' => viewer_secret('manual-canary') }), 'account', 'password')
      launcher.manual_select(event({}, payload: { rows: ['character-0'] }))
      launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront', 'checkbox:manual-save' => true }))
      expect(launches.size).to eq(cancel ? 0 : 1)
      expect(messages.to_s).not_to include('private notifier error', 'manual-canary')
    end
  end

  it 'gives actionable conversion guidance when an account save encounters legacy entries' do
    allow(catalog).to receive(:add_or_update_account).and_raise(described_class::Catalog::LegacyConversionRequired)
    launcher.save_account(event({ 'text_input:account-name' => 'DOUG', 'select:account-frontend' => 'stormfront',
                                 'password_input:account-password' => viewer_secret('synthetic-password') }))

    expect(launcher.send(:render_state)[:notice][:text]).to include('--convert-entries')
  end

  context 'manual favorites with the persisted catalog' do
    let(:data_dir) { Dir.mktmpdir('webui-manual-favorites') }
    let(:catalog) do
      described_class::Catalog.new(data_dir: data_dir,
                                   master_password_manager: double(keychain_available?: false))
    end

    before do
      catalog.upsert_manual_entry(entry.to_h, 'synthetic-password')
      catalog.upsert_manual_entry(entry.to_h.merge(custom_launch: '/fixture/custom'), 'synthetic-password')
      catalog.toggle_favorite(catalog.entries.first.key)
    end

    after { FileUtils.remove_entry(data_dir) }

    def play_manual_favorite(custom: nil)
      launcher.manual_connect(event({ 'account' => 'doug', 'password' => viewer_secret('manual-canary') }),
                              'account', 'password')
      launcher.manual_select(event({}, payload: { rows: ['character-0'] }))
      launcher.manual_play(event({
        'select:manual-frontend' => 'stormfront', 'checkbox:manual-custom-enabled' => !custom.nil?,
        'text_input:manual-custom' => custom, 'text_input:manual-custom-dir' => '',
        'checkbox:manual-save' => true, 'checkbox:manual-favorite' => true,
      }))
    end

    it 'keeps an existing favorite and its ordering when played again' do
      before = catalog.entries.first

      play_manual_favorite

      expect(launches.last.first).to eq(:manual)
      expect(catalog.entries.first.favorite).to be(true)
      expect(catalog.entries.first.favorite_order).to eq(before.favorite_order)
      expect(catalog.entries.last.favorite).to be(false)
    end

    it 'marks only the matching custom-launch variant as a favorite' do
      play_manual_favorite(custom: '/fixture/custom')

      expect(launches.last.first).to eq(:manual)
      expect(catalog.entries.map(&:favorite)).to eq([true, true])
      expect(catalog.entries.map(&:custom_launch)).to eq([nil, '/fixture/custom'])
    end
  end

  it 'refuses manual Play unless credentials, character, and an available frontend are selected' do
    rendered = launcher.send(:build_page).render.tree
    play = rendered.each.find { |component| component.cid.end_with?('button:manual-play') }
    expect(play.props[:disabled]).to be(true)

    launcher.manual_connect(event({ 'account' => 'doug', 'password' => viewer_secret('manual-canary') }),
                            'account', 'password')
    launcher.manual_select(event({}, payload: { rows: ['character-0'] }))
    ready = launcher.send(:build_page).render.tree.each.find { |component| component.cid.end_with?('button:manual-play') }
    expect(ready.props[:disabled]).to be(false)
    expect(launcher.send(:build_page).render.facilities[:accelerators])
      .to contain_exactly(hash_including(keys: 'enter', target: ready.cid, event: 'activate'))

    allow(WebUISpecSupport::Launcher::WorkflowFrontendLocator).to receive(:resolve).and_return(nil)
    launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront' }))
    expect(launcher.send(:render_state)[:manual][:error]).to match(/front end is unavailable/)
    expect(launches).to be_empty
  end

  it 'handles add and edit character persistence through the real catalog boundary' do
    values = {
      'select:character-account' => 'DOUG', 'text_input:character-name' => 'Cera',
      'select:character-game' => 'DR', 'select:character-frontend' => 'stormfront',
      'text_input:character-custom' => '', 'text_input:character-custom-dir' => '',
    }
    launcher.save_character(event(values))
    expect(catalog.calls.last.first).to eq(:add_character)

    launcher.instance_variable_set(:@draft_entry_key, 'entry-0')
    launcher.save_character(event(values.merge('text_input:character-name' => 'Aldor Prime')))
    expect(catalog.calls.last.first).to eq(:update_character)
  end

  it 'saves supported but undetected frontends while refusing Saga custom-launch conflicts' do
    values = {
      'select:character-account' => 'DOUG', 'text_input:character-name' => 'Cera',
      'select:character-game' => 'GS3', 'select:character-frontend' => 'wizard',
    }
    launcher.save_character(event(values))
    expect(catalog.calls.last).to match([:add_character, 'DOUG', hash_including(frontend: 'wizard')])

    launcher.save_account(event({ 'text_input:account-name' => 'DOUG', 'select:account-frontend' => 'wizard',
                                 'password_input:account-password' => viewer_secret('synthetic') }))
    expect(catalog.calls.last.first).to eq(:save_account)
    expect(catalog.calls.last.last).to eq('wizard')

    before = catalog.calls.dup
    launcher.save_character(event(values.merge('select:character-frontend' => 'saga', 'text_input:character-custom' => 'custom-client')))
    expect(catalog.calls).to eq(before)
    expect(launcher.send(:render_state)[:notice][:text]).to include('requires native launch')
  end

  it 'keeps the launcher open on detach while invalidating viewer-owned work' do
    launcher.manual_connect(event({ 'account' => 'DOUG', 'password' => viewer_secret('synthetic') }), 'account', 'password')
    page = launcher.send(:build_page)
    page.lifecycle_bindings.fetch(:detach).call(event)
    expect(launcher.lifecycle).not_to eq(:closed)
    expect(service.stopped).to be_nil
    expect(launcher.send(:render_state)[:manual][:phase]).to eq(:editing)
  end

  it 'keeps Manual Entry renderable when the catalog is damaged' do
    Dir.mktmpdir('launcher-recovery') do |directory|
      path = File.join(directory, 'entry.yaml')
      File.write(path, "accounts: [unclosed\n")
      recovery_catalog = described_class::Catalog.new(data_dir: directory)
      allow(recovery_catalog).to receive(:enhanced_encryption_available?).and_return(false)
      allow(self).to receive(:catalog).and_return(recovery_catalog)
      expect { launcher.send(:build_page).render }.not_to raise_error
      expect(launcher.send(:render_state)[:catalog_error]).to match(/unreadable/)
      launcher.manual_connect(event({ 'account' => 'DOUG', 'password' => viewer_secret('synthetic') }), 'account', 'password')
      expect(launcher.send(:render_state)[:manual][:phase]).to eq(:selecting_character)
      File.write(path, YAML.dump('accounts' => {}, 'encryption_mode' => 'standard'))
      launcher.refresh_catalog
      expect(launcher.send(:render_state).values_at(:catalog_error, :encryption_mode)).to eq([nil, :standard])
    end
  end

  [['', ''], ['new-master', 'different']].each do |password, confirmation|
    it "refuses enhanced encryption with empty or mismatched creation fields #{password.inspect}" do
      launcher.change_encryption(event({
        'radio:encryption-mode' => 'enhanced', 'password_input:encryption-master' => viewer_secret(password),
        'password_input:encryption-confirm' => viewer_secret(confirmation)
      }))
      expect(catalog.calls.map(&:first)).not_to include(:change_encryption)
    end
  end

  it 'requires explicit acknowledgement before storing passwords as plaintext' do
    launcher.change_encryption(event({ 'radio:encryption-mode' => 'plaintext', 'password_input:encryption-master' => viewer_secret('') }))
    expect(catalog.calls.map(&:first)).not_to include(:change_encryption)
  end

  it 'preserves GTK creation policy for a nonempty confirmed password without imposing a new length limit' do
    expect(catalog).to receive(:change_encryption_mode).with(:enhanced, master_password: 'x').and_call_original
    launcher.change_encryption(event({
      'radio:encryption-mode' => 'enhanced', 'password_input:encryption-master' => viewer_secret('x'),
      'password_input:encryption-confirm' => viewer_secret('x')
    }))
    expect(catalog.mode).to eq(:enhanced)
  end

  it 'disposes an incomplete enhanced submission without changing encryption' do
    secret = viewer_secret('synthetic')
    launcher.change_encryption(event({ 'radio:encryption-mode' => 'enhanced', 'password_input:encryption-master' => secret }))
    expect(secret).to be_consumed
    expect(catalog.calls.map(&:first)).not_to include(:change_encryption)
  end

  it 'routes saved Saga through its managed launcher without reading credentials or creating a game key' do
    catalog.entries_value = [entry.with(frontend: 'saga')]
    allow(WebUISpecSupport::Launcher::WorkflowFrontendLocator).to receive(:resolve).and_call_original
    allow(WebUISpecSupport::Launcher::WorkflowFrontendLocator).to receive(:resolve).with('saga', refresh: true).and_return(WebUISpecSupport::Launcher::WorkflowFrontendLocator::Resolution.new('saga'))
    expect(Lich::Common::SagaManagedLauncher).to receive(:launch).with(account: 'DOUG', character: 'Aldor', game_code: 'GS3').and_return(ok: true, pid: 123)
    launcher.saved_launch(event, entry.key)
    expect(catalog.calls.map(&:first)).not_to include(:credential)
    expect(authenticator.calls).to be_empty
    expect(launches).to be_empty
    expect(launcher.lifecycle).to eq(:closed)
  end

  it 'refuses saved Saga plus custom launch before authentication' do
    catalog.entries_value = [entry.with(frontend: 'saga', custom_launch: 'custom-client')]
    launcher.saved_launch(event, entry.key)
    expect(authenticator.calls).to be_empty
    expect(launches).to be_empty
    expect(launcher.send(:render_state)[:notice][:text]).to include('Saga')
  end

  it 'covers plaintext, standard, enhanced, keychain-unavailable, and master-password change paths' do
    %w[plaintext standard enhanced].each do |mode|
      launcher.change_encryption(event({
        'radio:encryption-mode'                 => mode,
        'password_input:encryption-master'      => viewer_secret(mode == 'enhanced' ? 'master-pass' : ''),
        'password_input:encryption-confirm'     => viewer_secret(mode == 'enhanced' ? 'master-pass' : ''),
        'checkbox:encryption-plaintext-confirm' => true,
      }))
    end
    expect(catalog.calls.select { |call| call.first == :change_encryption }.map { |call| call[1] })
      .to eq(%i[plaintext standard enhanced])

    launcher.change_master_password(event({
      'password_input:master-current' => viewer_secret('current-pass'),
      'password_input:master-new'     => viewer_secret('replacement-pass'),
      'password_input:master-confirm' => viewer_secret('replacement-pass'),
    }))
    expect(catalog.calls.map(&:first)).to include(:change_master)

    catalog.keychain = false
    catalog.mode = :standard
    launcher.send(:reload_catalog)
    launcher.change_encryption(event({
      'radio:encryption-mode'            => 'enhanced',
      'password_input:encryption-master' => viewer_secret('blocked-pass'),
    }))
    expect(launcher.send(:render_state)[:notice][:text]).to match(/unavailable/)
  end

  %w[plaintext standard].each do |mode|
    ['', 'wrong', 'valid-master'].each do |password|
      it "requires the current master password before changing enhanced encryption to #{mode} with #{password.inspect}" do
        catalog.mode = :enhanced
        catalog.master_valid = password == 'valid-master'
        secret = viewer_secret(password)
        launcher.change_encryption(event({ 'radio:encryption-mode' => mode, 'password_input:encryption-master' => secret,
                                          'checkbox:encryption-plaintext-confirm' => true }))

        changes = catalog.calls.select { |call| call.first == :change_encryption }
        if catalog.master_valid
          expect(catalog.calls).to include([:validate_master, password])
          expect(changes).to eq([[:change_encryption, mode.to_sym, nil]])
        else
          expect(changes).to be_empty
          expect(launcher.send(:render_state)[:notice][:text]).to match(/failed/)
        end
        expect(secret).to be_consumed
      end
    end
  end

  it 'keeps saved multi-launch open but closes manual and single saved launches' do
    persistent_service = WebUISpecSupport::Launcher::WorkflowService.new
    session_launcher = class_double(Lich::Common::SessionLauncher, launch: { ok: true })
    persistent = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: persistent_service, authenticator: authenticator,
      executor: WebUISpecSupport::Launcher::ImmediateExecutor.new, session_launcher: session_launcher, persistent: true,
      on_launch: proc {}, browser_open: proc { true }, frontend_locator: WebUISpecSupport::Launcher::WorkflowFrontendLocator
    )
    persistent.saved_launch(event, 'entry-0')
    persistent.saved_launch(event, 'entry-0')

    expect(persistent.lifecycle).not_to eq(:closed)
    expect(persistent.active_operations).to be_empty
    expect(session_launcher).to have_received(:launch).with(
      kind_of(Array), launch_context: hash_including(data_dir: '/fixture', force_path_flags: true)
    ).twice
  end

  it 'switches tab/list layout and exercises saved versus automatic sort order under GUI Settings' do
    second = entry.with(key: 'entry-1', char_name: 'Bera')
    first = entry.with(key: 'entry-0', char_name: 'Aldor')
    catalog.entries_value = [second, first]

    launcher.setting_changed(event({}, payload: { value: true }), :settings_visible)
    launcher.setting_changed(event({}, payload: { value: false }), :tab_layout)
    list_tree = launcher.send(:build_page).render.tree
    expect(list_tree.each.map(&:cid)).to include(a_string_ending_with('stack:saved-list-layout'))
    expect(list_tree.each.map(&:cid)).not_to include(a_string_ending_with('tabs:saved-account-tabs'))

    launcher.setting_changed(event({}, payload: { value: true }), :tab_layout)
    launcher.setting_changed(event({}, payload: { value: true }), :autosort)
    sorted_tree = launcher.send(:build_page).render.tree
    doug_panel = sorted_tree.each.find { |component| component.cid.end_with?('stack:saved-account-DOUG') }
    expect(doug_panel.each.select { |component| component.type == :group }.map { |group| group.props[:label] })
      .to eq(['Aldor (GS Prime)', 'Bera (GS Prime)'])
    expect(catalog.calls).to include([:setting, :tab_layout, false], [:setting, :tab_layout, true],
                                     [:setting, :autosort, true])
  end

  it 'clears viewer-owned state and closes the launcher service on explicit window close' do
    launcher.manual_connect(event({ 'account' => 'DOUG', 'password' => viewer_secret('disconnect-canary') }), 'account', 'password')
    launcher.browser_window_closed('viewer-1')

    expect(launcher.send(:render_state)[:manual][:phase]).to eq(:editing)
    expect(launcher.active_operations).to be_empty
    expect(launcher.lifecycle).to eq(:closed)
    expect(service.stopped).to be(true)
    expect(launcher.close(reason: :shutdown)).to be(false)
  end

  it 'admits only one shutdown path when window and process close signals race' do
    launcher.instance_variable_set(:@lifecycle, :closing)

    expect(launcher.close(reason: :browser_process_exit)).to be(false)
    expect(service.stopped).to be_nil
  end

  [true, false].each do |windows|
    it "terminates only its owned launcher PID with #{windows ? 'KILL' : 'TERM'}" do
      allow(OS).to receive(:windows?).and_return(windows)
      terminated = []
      launcher.instance_variable_set(:@browser_pid, 1234)
      launcher.instance_variable_set(:@browser_terminate, ->(signal, pid) { terminated << [signal, pid] })

      expect(launcher.close(reason: :launch)).to be(true)
      expect(terminated).to eq([[windows ? 'KILL' : 'TERM', 1234]])
    end
  end

  it 'uses the first namespaced submission match and retains character conversions and blanks' do
    launcher.save_character(event({
      'first/text_input:character-name' => :'cera two', 'second/text_input:character-name' => 'ignored',
      'nested/select:character-game' => :GST, 'nested/select:character-frontend' => 'wizard',
      'nested/select:character-account' => :doug, 'nested/text_input:character-custom' => false,
      'nested/text_input:character-custom-dir' => '',
    }))

    expect(catalog.calls.last).to eq([:add_character, 'doug', {
      char_name: 'cera two', game_code: 'GST', frontend: 'wizard', custom_launch: 'false',
      custom_launch_dir: nil, game_name: 'GemStone IV Prime Test',
    }])
  end

  it 'normalizes namespaced account values while retaining password pair presence checks' do
    values = { 'first/text_input:account-name' => '  doug  ', 'second/text_input:account-name' => 'ignored',
               'nested/select:account-frontend' => 'wizard' }
    launcher.save_account(event(values))
    expect(authenticator.calls).to be_empty
    expect(launcher.send(:render_state)[:notice][:text]).to eq('Password is required.')

    launcher.save_account(event(values.merge('nested/password_input:account-password' => viewer_secret(''))))
    expect(authenticator.calls.last).to eq(account: 'DOUG', password: '', legacy: true)
    expect(catalog.calls.last).to match([:save_account, 'DOUG', anything, anything, 'wizard'])
  end
end
