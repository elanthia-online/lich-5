# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../login_spec_helper'
require 'common/webui_launcher'

# Fixture types stay local to this workflow-focused example group.
# rubocop:disable Lint/ConstantDefinitionInBlock
RSpec.describe Lich::Common::WebUILauncher, 'actual-core workflows' do
  Event = Data.define(:viewer_id, :payload, :submission)

  class ImmediateExecutor
    def post(&work) = work.call
    def stop(wait: true) = wait
  end

  # Holds posted work so an operation stays in flight for the example.
  class QueuedExecutor
    def initialize = @queue = []
    def post(&work) = @queue << work
    def stop(wait: true) = wait
  end

  class WorkflowFrontendLocator
    Resolution = Data.define(:frontend_id)

    class << self
      attr_accessor :resolved
    end
    self.resolved = []

    def self.available(gui_selectable:, refresh:)
      raise unless gui_selectable && refresh

      [Resolution.new('stormfront')]
    end

    def self.resolve(frontend, refresh: false)
      self.resolved << [frontend, refresh]
      Resolution.new(frontend) if frontend == 'stormfront'
    end
  end

  class WorkflowService
    attr_reader :terminated, :stopped, :refreshes

    def initialize
      @refreshes = 0
    end

    def refresh(_page) = @refreshes += 1
    def terminate_owner(owner) = @terminated = owner
    def stop = @stopped = true
  end

  class WorkflowCatalog
    attr_accessor :entries_value, :mode, :keychain, :require_master, :master_valid
    attr_reader :calls

    def initialize(entry)
      @entries_value = [entry]
      @mode = :standard
      @keychain = true
      @require_master = false
      @master_valid = true
      @calls = []
    end

    def entries(autosort: false) = autosort ? @entries_value.sort_by(&:char_name) : @entries_value
    def accounts = @entries_value.map(&:user_id).uniq
    def encryption_mode = @mode
    def enhanced_encryption_available? = @keychain

    def credential(key, master_password: nil)
      @calls << [:credential, key, master_password]
      raise Lich::Common::WebUILauncher::Catalog::MasterPasswordRequired if @require_master && master_password.nil?

      Lich::WebUI::SensitiveValue.server('origin-b-saved-canary')
    end

    def validate_master_password(password)
      @calls << [:validate_master, password]
      @master_valid
    end

    def upsert_manual_entry(entry, password)
      @calls << [:save_manual, entry, password]
      'entry-saved'
    end

    def toggle_favorite(key) = @calls << [:favorite, key]
    def set_favorite(key, wanted) = @calls << [:favorite, key, wanted]
    def remove_entry(key) = @calls << [:remove_entry, key]
    def remove_account(account) = @calls << [:remove_account, account]
    def add_character(account, character) = @calls << [:add_character, account, character]
    def update_character(key, character) = @calls << [:update_character, key, character]
    def update_launcher_setting(setting, value) = @calls << [:setting, setting, value]

    def add_or_update_account(account, password, characters, frontend:)
      @calls << [:save_account, account, password, characters, frontend]
      true
    end

    def change_encryption_mode(mode, master_password: nil)
      @calls << [:change_encryption, mode, master_password]
      @mode = mode
      true
    end

    def change_master_password(current, replacement)
      @calls << [:change_master, current, replacement]
      true
    end
  end

  let(:entry) do
    Lich::Common::WebUILauncher::Catalog::Entry.new(
      'entry-0', 'DOUG', 'Aldor', 'GS3', 'GemStone IV', 'stormfront', nil, nil, false, nil
    )
  end
  let(:catalog) { WorkflowCatalog.new(entry) }
  let(:service) { WorkflowService.new }
  let(:launches) { [] }
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
      executor: ImmediateExecutor.new, on_launch: ->(launch, origin) { launches << [origin, launch] },
      browser_open: proc { true }, frontend_locator: WorkflowFrontendLocator
    )
  end

  def event(values = {}, viewer: 'viewer-1', payload: {})
    Event.new(viewer, payload, Lich::WebUI::Submission.new(viewer_id: viewer, values: values))
  end

  def viewer_secret(value)
    Lich::WebUI::SensitiveValue.viewer(value)
  end

  it 'launches a saved entry with an Origin B credential that never enters the render tree' do
    launcher.saved_launch(event, 'entry-0')

    expect(authenticator.calls.last[:password]).to eq('origin-b-saved-canary')
    expect(launches.last.first).to eq(:saved_entry)
    tree_text = launcher.send(:build_page).render.tree.to_h.to_s
    expect(tree_text).not_to include('origin-b-saved-canary')
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
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new, executor: ImmediateExecutor.new,
      on_launch: proc {}, browser_open: proc { true }
    )
    alternate.instance_variable_set(:@modal, { kind: :unlock, entry_key: 'entry-0' })
    alternate.unlock_response(event({}, payload: { button: 'cancel' }), 'password')
    expect(alternate.send(:render_state)[:modal]).to be_nil
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
    expect(WorkflowFrontendLocator.resolved).to include(['stormfront', true])
  end

  it 'refuses a second Connect while authentication is in flight without consuming its secret' do
    queued = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: service, authenticator: authenticator,
      executor: QueuedExecutor.new, on_launch: proc {}, browser_open: proc { true },
      frontend_locator: WorkflowFrontendLocator
    )
    first = viewer_secret('first-click')
    second = viewer_secret('second-click')

    queued.manual_connect(event({ 'account' => 'doug', 'password' => first }), 'account', 'password')
    expect(first).to be_consumed
    connect = queued.send(:build_page).render.tree.each.find { |component| component.cid.end_with?('button:manual-connect') }
    expect(connect.props[:disabled]).to be(true)

    # A double-click can outrun the refresh that disables the button, so the
    # second submission must be refused on the server without raising into
    # the dispatcher (which would swallow it) and without eating the secret.
    expect { queued.manual_connect(event({ 'account' => 'doug', 'password' => second }), 'account', 'password') }
      .not_to raise_error
    expect(second).not_to be_consumed
    expect(queued.send(:render_state)[:manual][:error]).to match(/already in progress/i)
    expect(queued.send(:render_state)[:manual][:phase]).to eq(:authenticating)
    expect(queued.active_operations.keys).to eq([:manual_auth])
  end

  it 'discards an unlock submission if its modal has already closed' do
    secret = viewer_secret('late-secret')

    expect(launcher.unlock_response(
             event({ 'password' => secret }, payload: { button: 'unlock' }), 'password'
           )).to be_nil
    expect(secret).to be_consumed
    expect(catalog.calls).to be_empty
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

    allow(WorkflowFrontendLocator).to receive(:resolve).and_return(nil)
    launcher.manual_play(event({ 'select:manual-frontend' => 'stormfront' }))
    expect(launcher.send(:render_state)[:manual][:error]).to match(/available front end/)
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

  it 'covers plaintext, standard, enhanced, keychain-unavailable, and master-password change paths' do
    %w[plaintext standard enhanced].each do |mode|
      launcher.change_encryption(event({
        'radio:encryption-mode'            => mode,
        'password_input:encryption-master' => viewer_secret(mode == 'enhanced' ? 'master-pass' : ''),
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
    launcher.change_encryption(event({
      'radio:encryption-mode'            => 'enhanced',
      'password_input:encryption-master' => viewer_secret('blocked-pass'),
    }))
    expect(launcher.send(:render_state)[:notice][:text]).to match(/unavailable/)
  end

  it 'keeps saved multi-launch open but closes manual and single saved launches' do
    persistent_service = WorkflowService.new
    session_launcher = class_double(Lich::Common::SessionLauncher, launch: { ok: true })
    persistent = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: persistent_service, authenticator: authenticator,
      executor: ImmediateExecutor.new, session_launcher: session_launcher, persistent: true,
      on_launch: proc {}, browser_open: proc { true }
    )
    persistent.saved_launch(event, 'entry-0')

    expect(persistent.lifecycle).not_to eq(:closed)
    expect(session_launcher).to have_received(:launch).with(
      kind_of(Array), launch_context: hash_including(data_dir: '/fixture', force_path_flags: true)
    )
  end

  # SerialExecutor#stop(wait: false) does not interrupt work already running,
  # and authentication can take seconds. Closing the launcher mid-authentication
  # used to launch anyway: the persistent path called SessionLauncher before
  # consulting complete, and the terminal paths ignored whether the completion
  # was accepted. An immediate executor cannot show this -- the launch has to be
  # in flight while close runs.
  it 'does not launch a session for a launcher closed during authentication' do
    reached = Queue.new
    release = Queue.new
    blocking_authenticator = Class.new do
      define_method(:authenticate) do |**_keywords|
        reached << :authenticating
        release.pop
        { ok: true, sal: 'SAL' }
      end
    end.new
    session_launcher = class_double(Lich::Common::SessionLauncher, launch: { ok: true })
    closing = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new,
      authenticator: blocking_authenticator, executor: ImmediateExecutor.new,
      session_launcher: session_launcher, persistent: true,
      on_launch: proc {}, browser_open: proc { true }
    )
    operation = closing.send(:begin_operation, :saved_entry, event)
    worker = Thread.new { closing.send(:perform_saved_launch, operation, 'entry-0') }

    reached.pop
    closing.close(reason: :user)
    release << :go

    expect(worker.join(5)).not_to be_nil
    expect(session_launcher).not_to have_received(:launch)
  end

  # The manual path persisted the entry inside authentication, before it
  # consulted whether the launcher was still open: close mid-authentication
  # and the launch was refused but the catalog still gained the entry.
  it 'neither saves nor launches a manual entry for a launcher closed during authentication' do
    reached = Queue.new
    release = Queue.new
    blocking_authenticator = Class.new do
      define_method(:authenticate) do |**_keywords|
        reached << :authenticating
        release.pop
        { game: 'STORM', key: 'session-key', gamehost: 'example', gameport: '1' }
      end
    end.new
    closing = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new,
      authenticator: blocking_authenticator, executor: ImmediateExecutor.new,
      on_launch: ->(launch, origin) { launches << [origin, launch] }, browser_open: proc { true },
      frontend_locator: WorkflowFrontendLocator
    )
    operation = closing.send(:begin_operation, :manual, event)
    values = {
      'select:manual-frontend' => 'stormfront', 'checkbox:manual-custom-enabled' => false,
      'checkbox:manual-save' => true, 'checkbox:manual-favorite' => true,
    }
    character = { char_name: 'Aldor', game_code: 'GS3', game_name: 'GemStone IV' }
    worker = Thread.new do
      closing.send(:perform_manual_launch, operation, 'viewer-1', 'doug', character, viewer_secret('manual-canary'), values)
    end

    reached.pop
    closing.close(reason: :user)
    release << :go

    expect(worker.join(5)).not_to be_nil
    expect(catalog.calls.map(&:first)).not_to include(:save_manual, :favorite)
    expect(launches).to be_empty
  end

  # Review 2026-09-17, R4: Add Account authenticated and then saved before
  # asking whether the launcher was still open, and the persistent launch
  # checked liveness, released the lock, and then launched -- a close in
  # that gap was accepted and the side effect happened anyway. Every
  # irreversible step now runs under `commit`, which refuses after an
  # accepted close and makes a concurrent close wait for it.
  it 'does not save an account for a launcher closed during authentication' do
    reached = Queue.new
    release = Queue.new
    blocking_authenticator = Class.new do
      define_method(:authenticate) do |**_keywords|
        reached << :authenticating
        release.pop
        [{ char_name: 'Aldor', game_code: 'GS3', game_name: 'GemStone IV' }]
      end
    end.new
    closing = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new,
      authenticator: blocking_authenticator, executor: ImmediateExecutor.new,
      on_launch: proc {}, browser_open: proc { true }, frontend_locator: WorkflowFrontendLocator
    )
    submission = Lich::WebUI::Submission.new(viewer_id: 'viewer-1', values: {
      'page:l/text_input:account-name' => 'DOUG', 'page:l/select:account-frontend' => 'stormfront',
      'page:l/password_input:account-password' => viewer_secret('account-canary'),
    })
    worker = Thread.new { closing.save_account(Event.new('viewer-1', {}, submission)) }

    reached.pop
    closing.close(reason: :user)
    release << :go

    expect(worker.join(5)).not_to be_nil
    expect(catalog.calls.map(&:first)).not_to include(:save_account)
  end

  # Review 2026-09-17 (b), F2: the master-password change called the
  # catalog directly from its queued job, and only its completion consulted
  # the arbiter. Closing the launcher stops the executor without dropping
  # what is already queued, so a change waiting behind other work still
  # rewrote the credential store after the close.
  it 'does not change the master password for a launcher closed while the change was queued' do
    queued = QueuedExecutor.new
    closing = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new,
      authenticator: authenticator, executor: queued,
      on_launch: proc {}, browser_open: proc { true }
    )
    closing.change_master_password(event({
      'password_input:master-current' => viewer_secret('current-pass'),
      'password_input:master-new'     => viewer_secret('replacement-pass'),
      'password_input:master-confirm' => viewer_secret('replacement-pass'),
    }))
    closing.close(reason: :user)
    queued.instance_variable_get(:@queue).each(&:call)

    expect(catalog.calls.map(&:first)).not_to include(:change_master)
  end

  it 'refuses a commit after a close was accepted, and a close waits for a commit in progress' do
    operation = launcher.send(:begin_operation, :favorite, event)
    launcher.close(reason: :user)
    ran = false
    expect(launcher.send(:commit, operation) { ran = true }).to be_nil
    expect(ran).to be(false)

    open_launcher = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new,
      authenticator: authenticator, executor: ImmediateExecutor.new,
      on_launch: proc {}, browser_open: proc { true }
    )
    operation = open_launcher.send(:begin_operation, :favorite, event)
    inside = Queue.new
    release = Queue.new
    order = []
    committer = Thread.new do
      open_launcher.send(:commit, operation) do
        inside << true
        release.pop
        order << :committed
        :effect
      end
    end
    inside.pop
    closer = Thread.new do
      open_launcher.close(reason: :user)
      order << :closed
    end
    sleep 0.05
    expect(closer.alive?).to be(true), 'close waits for the commit'
    release << true
    expect(committer.value).to eq([true, :effect])
    closer.join(5)
    expect(order).to eq(%i[committed closed])
  end

  it 'does not launch terminally after a close was accepted, and closes with the launch reason otherwise' do
    reasons = []
    closed_first = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new,
      authenticator: authenticator, executor: ImmediateExecutor.new,
      on_launch: ->(launch, origin) { launches << [origin, launch] }, browser_open: proc { true },
      on_close: ->(reason) { reasons << reason }
    )
    closed_first.close(reason: :user)
    expect(closed_first.send(:terminal_launch, { sal: 'SAL' }, :manual)).to be(false)
    expect(launches).to be_empty

    open_launcher = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new,
      authenticator: authenticator, executor: ImmediateExecutor.new,
      on_launch: ->(launch, origin) { launches << [origin, launch] }, browser_open: proc { true },
      on_close: ->(reason) { reasons << reason }
    )
    expect(open_launcher.send(:terminal_launch, { sal: 'SAL' }, :manual)).to be(true)
    expect(launches).to eq([[:manual, { sal: 'SAL' }]])
    expect(open_launcher.lifecycle).to eq(:closed)
    expect(reasons).to eq(%i[user launch])
    expect(open_launcher.close(reason: :user)).to be(false)
  end

  it 'still launches when the launcher stays open' do
    session_launcher = class_double(Lich::Common::SessionLauncher, launch: { ok: true })
    open_launcher = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new,
      authenticator: authenticator, executor: ImmediateExecutor.new,
      session_launcher: session_launcher, persistent: true,
      on_launch: proc {}, browser_open: proc { true }
    )
    operation = open_launcher.send(:begin_operation, :saved_entry, event)
    open_launcher.send(:perform_saved_launch, operation, 'entry-0')

    expect(session_launcher).to have_received(:launch).once
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

  # The persisted half of Lich.launcher lives in lich_settings; the launcher
  # is where a player who is already in the WebUI can choose to come back to
  # GTK next time, or pin the WebUI. An explicit flag still wins over it.
  it 'offers the native-launcher-next-time toggle only when a launcher choice exists, and writes it' do
    choice = Class.new do
      attr_accessor :setting

      def initialize(setting) = @setting = setting
      def native_next? = @setting == :gtk

      def native_next=(wanted)
        @setting = wanted ? :gtk : :webui
      end
    end.new(:gtk)
    choosing = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: service, authenticator: authenticator,
      executor: ImmediateExecutor.new, on_launch: ->(*) {}, browser_open: proc { true },
      frontend_locator: WorkflowFrontendLocator, launcher_choice: choice
    )
    choosing.setting_changed(event({}, payload: { value: true }), :settings_visible)
    tree = choosing.send(:build_page).render.tree
    toggle = tree.each.find { |component| component.cid.end_with?('toggle:native-launcher-next') }
    expect(toggle.props[:checked]).to be(true)

    choosing.setting_changed(event({}, payload: { value: false }), :native_launcher_next)
    expect(choice.setting).to eq(:webui)
    choosing.setting_changed(event({}, payload: { value: true }), :native_launcher_next)
    expect(choice.setting).to eq(:gtk)
    expect(catalog.calls).not_to include(a_collection_including(:native_launcher_next))

    silent = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: service, authenticator: authenticator,
      executor: ImmediateExecutor.new, on_launch: ->(*) {}, browser_open: proc { true },
      frontend_locator: WorkflowFrontendLocator, launcher_choice: nil
    )
    silent.setting_changed(event({}, payload: { value: true }), :settings_visible)
    cids = silent.send(:build_page).render.tree.each.map(&:cid)
    expect(cids).not_to include(a_string_ending_with('toggle:native-launcher-next'))
    expect { silent.setting_changed(event({}, payload: { value: true }), :native_launcher_next) }
      .to raise_error(ArgumentError, /not offered/)
  end

  # The runtime emits detach for any transport loss, and the client dials
  # back and re-attaches with its resume token. Closing on the detach itself
  # tore the launcher down before that reconnect could land.
  it 'survives a socket detach that re-attaches within the grace, and closes on one that does not' do
    resilient = described_class.new(
      data_dir: '/fixture', catalog: catalog, service: WorkflowService.new, executor: ImmediateExecutor.new,
      on_launch: proc {}, browser_open: proc { true }, detach_grace: 0.05
    )
    expect(resilient.send(:build_page).lifecycle_bindings.keys).to include(:attach, :detach)

    resilient.browser_window_detached('viewer-1')
    resilient.browser_window_attached('viewer-1')
    sleep 0.2
    expect(resilient.lifecycle).not_to eq(:closed)

    resilient.browser_window_detached('viewer-1')
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    sleep 0.02 until resilient.lifecycle == :closed || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    expect(resilient.lifecycle).to eq(:closed)
  end

  it 'clears viewer-owned state and closes the launcher service when its browser window disconnects' do
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

  it 'terminates only its exactly owned browser process during launcher shutdown' do
    terminated = []
    launcher.instance_variable_set(:@browser_pid, 1234)
    launcher.instance_variable_set(:@browser_terminate, ->(signal, pid) { terminated << [signal, pid] })

    expect(launcher.close(reason: :launch)).to be(true)
    expect(terminated).to eq([['TERM', 1234]])
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock
