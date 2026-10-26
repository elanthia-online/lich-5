# frozen_string_literal: true

require 'openssl'
require 'securerandom'
require 'json'
require 'monitor'
require_relative '../webui'
require_relative 'authentication/authenticator'
require_relative 'authentication/launch_data'
require_relative 'front-end'
require_relative 'frontend_locator'
require_relative 'frontend_choices'
require_relative 'webui_launcher/frontend_tab'
require_relative 'session_launcher'
require_relative 'saga_launch_policy'
require_relative 'saga_managed_launcher'
require_relative 'webui_launcher/catalog'
require_relative 'webui_launcher/serial_executor'
require_relative 'webui_launcher/window_geometry_store'

module Lich
  module Common
    # Default native launcher built directly on the WebUI author API.
    class WebUILauncher
      TABS = ['Saved Entry', 'Manual Entry', 'Account Management', 'Frontends'].freeze
      ACCOUNT_TABS = ['Accounts', 'Add Character', 'Add Account', 'Encryption Management'].freeze
      GAMES = Authentication::LoginHelpers::VALID_GAME_CODES.map { |code| { value: code, label: code } }.freeze
      GAME_NAMES = Authentication::LoginHelpers::GAME_NAMES
      GAME_REALMS = {
        'GS3' => 'GS Prime', 'GSF' => 'GS Shattered', 'GSX' => 'GS Platinum', 'DRX' => 'DR Platinum', 'GST' => 'GS Test',
        'DR' => 'DR Prime', 'DRF' => 'DR Fallen', 'DRT' => 'DR Test',
      }.freeze
      Operation = Data.define(:id, :kind, :viewer_id)

      attr_reader :page

      # Builds launcher state and shares a close/write gate with its frontend editor.
      # Blocking authentication runs on the executor outside this gate; persistence
      # and launch use it only after checking that the operation is still live.
      # @param data_dir [String] login/settings directory
      # @param on_launch [Proc] receives launch data and origin after launch admission
      # @param service [WebUI::Service] page/connection lifecycle host
      # @param catalog [Catalog, nil] persistence boundary, defaulting to this directory
      # @param authenticator [Object] account/game authentication collaborator
      # @param launch_data [Object] frontend launch-data builder
      # @param session_launcher [Object] persistent child-session launcher
      # @param executor [SerialExecutor] worker owning queued resource cleanup
      # @param browser_open [Proc, nil] app-window launch override
      # @param on_close [Proc, nil] receives the final close reason
      # @param browser_terminate [Proc, Method] terminates an owned browser process
      # @param recovery [Proc, nil] reports startup/save failures outside the window
      # @param logger [Proc, nil] receives severity and redacted diagnostic text
      # @param persistent [Boolean] retain the launcher after saved-entry launches
      # @param autosort [Boolean] sort entries for display
      # @param tab_layout [Boolean] display account tabs rather than one list
      # @param dark_theme [Boolean] initial stored theme preference
      # @param geometry_store [Object, nil] window geometry persistence
      # @param frontend_locator [Object] discovers supported frontend executables
      def initialize(data_dir:, on_launch:, service: Lich::WebUI.service, catalog: nil,
                     authenticator: Authentication, launch_data: Authentication::LaunchData,
                     session_launcher: SessionLauncher, executor: SerialExecutor.new,
                     browser_open: nil, on_close: nil,
                     browser_terminate: Process.method(:kill),
                     recovery: nil, logger: nil, persistent: false, autosort: false,
                     tab_layout: true, dark_theme: false, geometry_store: nil,
                     frontend_locator: FrontendLocator)
        raise ArgumentError, 'data_dir is required' if data_dir.to_s.empty?
        raise ArgumentError, 'on_launch must respond to call' unless on_launch.respond_to?(:call)

        @service = service
        @data_dir = data_dir
        @catalog = catalog || Catalog.new(data_dir: data_dir)
        @authenticator = authenticator
        @launch_data = launch_data
        @session_launcher = session_launcher
        @executor = executor
        @logger = logger || proc { |level, message| Lich.log("#{level}: #{message}") if Lich.respond_to?(:log) }
        @frontend_locator = frontend_locator
        @frontend_options = discover_frontends(refresh: true)
        @geometry_store = geometry_store || WindowGeometryStore.new(data_dir: data_dir)
        @window_geometry = @geometry_store.load
        @browser_pid = nil
        @browser_terminate = browser_terminate
        @browser_open = browser_open || lambda do |url|
          Lich::WebUI::BrowserLauncher.open(
            url, geometry: @window_geometry,
                 on_start: ->(pid) { @mutex.synchronize { @browser_pid = pid } },
                 on_exit: -> { close(reason: :browser_process_exit) }
          )
        end
        @on_launch = on_launch
        @on_close = on_close || proc {}
        @recovery = recovery || proc { |message| Lich.msgbox(message: message, icon: :warning) }
        @mutex = Mutex.new
        @commit_mutex = Monitor.new
        @closed_condition = ConditionVariable.new
        @lifecycle = :starting
        @viewer_attached = false
        @persistent = persistent
        @autosort = autosort
        @tab_layout = tab_layout
        @dark_theme = dark_theme
        @settings_visible = false
        @active = {}
        @notice = nil
        @modal = nil
        @selected_entry = nil
        @manual = default_manual_state
        @manual_credentials = {}
        @draft_entry_key = nil
        reload_catalog
        @frontend_tab = FrontendTab.new(
          data_dir: @data_dir, locator: @frontend_locator, executor: @executor,
          commit: ->(&work) { commit(&work) },
          on_change: -> { refresh },
          on_catalog_change: lambda {
            choices = discover_frontends(refresh: false)
            @mutex.synchronize { @frontend_options = choices }
          }
        )
      end

      # Supplies a stable diagnostic label; ownership still uses this instance's identity.
      # @return [String]
      def webui_owner_id = 'core.launcher'

      # Registers the launcher page and opens its owned browser process.
      # Browser launch failure closes the service rather than opening a tab.
      # @return [WebUILauncher] this launcher, for chaining with {#await_launch}
      def start
        @page = build_page
        @service.registry.register(@page)
        @page.bind_runtime(@service.runtime)
        @service.start
        @mutex.synchronize { @lifecycle = :ready }
        @service.refresh(@page)
        opened = @browser_open.call(@service.launch_url(page: @page))
        unless opened == false
          return self
        end

        raise Lich::WebUI::Error,
              'dedicated launcher window failed to open; check the configured WebUI host and debug log, then retry'
      rescue Lich::WebUI::Error => error
        report_feedback("ERROR: #{error.message}. The WebUI launcher has stopped.")
        close(reason: :browser_failure)
        raise
      rescue StandardError => error
        report_feedback("WebUI launcher unavailable: #{error.class}. Retry after correcting the failure or abort safely.")
        close(reason: :browser_failure)
        raise
      end

      # Closes the owned browser, page, service and operation worker once.
      # Racing browser-exit and page-detach callbacks share this lifecycle gate.
      # Attempts every teardown step and the close callback, then propagates the
      # first failure. Diagnostics cannot interrupt cleanup; waiting callers are
      # always released before the close callback runs.
      # @param reason [Symbol] lifecycle reason delivered to the close callback
      # @return [Boolean] whether this call began shutdown
      # @raise [StandardError] first teardown or close-callback failure, after cleanup
      def close(reason: :user)
        browser_pid = nil
        unattached_exit = false
        accepted = @commit_mutex.synchronize do
          @mutex.synchronize do
            next false if %i[closing closed].include?(@lifecycle)

            @lifecycle = :closing
            unattached_exit = reason == :browser_process_exit && !@viewer_attached
            @active.clear
            @manual_credentials.each_value(&:discard!)
            @manual_credentials.clear
            browser_pid = @browser_pid
            @browser_pid = nil
            true
          end
        end
        return false unless accepted

        teardown_error = nil
        begin
          [
            -> { terminate_browser(browser_pid) if browser_pid },
            -> { @frontend_tab.close },
            -> { @service.terminate_owner(self) },
            -> { @service.stop },
            -> { @executor.stop(wait: false) },
          ].each do |step|
            step.call
          rescue StandardError => error
            teardown_error ||= error
          end
          log_diagnostic(:info, "WebUI launcher closed reason=#{reason}")
          report_feedback('The WebUI launcher window closed before connecting. Check the debug log and retry.') if unattached_exit
        ensure
          @mutex.synchronize do
            @lifecycle = :closed
            @closed_condition.broadcast
          end
        end
        begin
          @on_close.call(reason)
        rescue StandardError => error
          teardown_error ||= error
        end
        raise teardown_error if teardown_error

        true
      end

      # Reads the launcher state while holding its lifecycle mutex.
      # @return [Symbol] current lifecycle state
      def lifecycle = @mutex.synchronize { @lifecycle }
      # @return [Hash] immutable snapshot of pending operations
      # Snapshots pending operation tokens without exposing the mutable operation index.
      def active_operations = @mutex.synchronize { @active.dup.freeze }

      # Waits for a selected session or cancellation without a toolkit main loop.
      # @return [Object, nil] launch data, or nil when closed without a selection
      def await_launch
        @mutex.synchronize do
          @closed_condition.wait(@mutex) until @lifecycle == :closed
          @launch_result
        end
      end

      # Evaluates the current launcher page for inspection without opening a window.
      # @return [Lich::WebUI::Component] rendered root
      def render_tree
        @page.render.tree
      end

      private

      # Families reopen this controller; operation and close gates remain shared here.
      require_relative 'webui_launcher/presentation/page'

      # Captures launcher state, including recoverable catalog errors, for one render.
      # @return [Hash] presentation state without account passwords
      # @api private
      def render_state
        @mutex.synchronize do
          {
            initial_tab: @entries.empty? ? 1 : 0, entries: @entries.dup, accounts: @accounts.dup,
            encryption_mode: @encryption_mode, keychain: @catalog.enhanced_encryption_available?,
            persistent: @persistent, autosort: @autosort, tab_layout: @tab_layout,
            dark_theme: @dark_theme, settings_visible: @settings_visible,
            notice: @notice, modal: @modal&.dup, catalog_error: @catalog_error,
            manual: @manual.merge(characters: @manual[:characters].dup), active: @active.keys,
            draft_entry_key: @draft_entry_key, window_geometry: @window_geometry.dup,
            frontend_options: @frontend_options.map(&:dup),
          }
        end
      end

      require_relative 'webui_launcher/presentation/saved_entries'

      require_relative 'webui_launcher/presentation/manual_entry'

      require_relative 'webui_launcher/presentation/accounts'

      require_relative 'webui_launcher/presentation/character_form'

      require_relative 'webui_launcher/presentation/account_form'

      require_relative 'webui_launcher/presentation/encryption'

      require_relative 'webui_launcher/presentation/dialogs'

      public

      # Applies a preference only if closure has not already been accepted.
      # @param event [WebUI::Runtime::EventContext] changed control value
      # @param setting [Symbol] known launcher preference
      # @return [void]
      def setting_changed(event, setting)
        value = event.payload.fetch(:value)
        accepted = commit do
          @mutex.synchronize do
            case setting
            when :persistent then @persistent = value
            when :autosort then @autosort = value
            when :tab_layout then @tab_layout = value
            when :dark_theme then @dark_theme = value
            when :settings_visible then @settings_visible = value
            else raise ArgumentError, "unknown launcher setting: #{setting}"
            end
          end
          if setting != :settings_visible && @catalog.respond_to?(:update_launcher_setting)
            @catalog.update_launcher_setting(setting, value)
          end
          reload_catalog if setting == :autosort
        end
        @service.refresh_theme if accepted && setting == :dark_theme
        refresh
      end

      # Saves validated geometry only while the launcher is open.
      # @param event [WebUI::Runtime::EventContext] JSON geometry payload
      # @return [Hash, false, nil] accepted geometry, or invalid/closed result
      def window_geometry_changed(event)
        geometry = nil
        commit do
          geometry = @geometry_store.save(JSON.parse(event.payload.fetch(:value)))
          @mutex.synchronize { @window_geometry = geometry } if geometry
        end
        geometry
      rescue JSON::ParserError, KeyError
        false
      end

      require_relative 'webui_launcher/workflows/manual_entry'

      require_relative 'webui_launcher/workflows/saved_entries'

      require_relative 'webui_launcher/workflows/accounts'

      require_relative 'webui_launcher/workflows/encryption'

      # Queues a catalog reload and page refresh on the launcher executor.
      # @return [void]
      def refresh_catalog
        @executor.post do
          reload_catalog
          refresh
        end
      end

      # Invalidates a viewer's operations before releasing its retained credentials.
      # @param viewer_id [String] departing attachment identifier
      # @return [void]
      def viewer_gone(viewer_id)
        @commit_mutex.synchronize do
          @mutex.synchronize do
            @manual_credentials.delete(viewer_id)&.discard!
            @active.delete_if { |_kind, operation| operation.viewer_id == viewer_id }
            @manual = default_manual_state
            @modal = nil
          end
        end
      end

      # Closes only for an explicit window-close event, never a reconnectable detach.
      # @param viewer_id [String, nil] closing attachment, if known
      # @return [Boolean] whether shutdown began
      def browser_window_closed(viewer_id)
        viewer_gone(viewer_id)
        close(reason: :browser_window_closed)
      end

      # Records first connection without treating later transport loss as closure.
      # @return [Boolean] true after an attachment has been observed
      def viewer_attached
        @mutex.synchronize { @viewer_attached = true }
      end

      private

      # Reports feedback that must survive window closure through the existing
      # platform notifier (terminal/debug log off Windows). Notification failures
      # must not prevent cleanup or a valid launch after an optional save failure.
      # @param message [String] authored message containing no submitted secrets
      # @return [Object, nil] notifier result, or nil if notification failed
      # @api private
      def report_feedback(message)
        @recovery.call(message)
      rescue StandardError => error
        log_diagnostic(:warning, "launcher feedback failed error=#{error.class}")
        nil
      end

      # Attempts diagnostic logging without making feedback or closure depend on
      # logger availability. Do not recursively report a failed diagnostic sink.
      # @param level [Symbol] diagnostic severity
      # @param message [String] redacted diagnostic text
      # @return [Object, nil] logger result, or nil when logging fails
      # @api private
      def log_diagnostic(level, message)
        @logger.call(level, message)
      rescue StandardError
        nil
      end

      require_relative 'webui_launcher/launches'

      # Queues a catalog edit through the same close gate as authentication writes.
      # @param kind [Symbol] operation category
      # @param event [WebUI::Runtime::EventContext] originating viewer
      # @param failure_message [String] safe user-facing failure description
      # @param work [Proc] work admitted through the existing operation and close gates
      # @yield persistence work to run only for a live operation
      # @return [Boolean] whether work was accepted
      # @api private
      def mutate(kind, event, failure_message, &work)
        operation = begin_operation(kind, event)
        post_operation(operation) do
          commit(operation, &work)
          complete(operation) { reload_catalog_locked }
        rescue StandardError => error
          fail_operation(operation, error, notice: failure_message)
        end
      end

      # Allocates a token only while open and refuses overlapping work of the same kind.
      # @api private
      # @param kind [Symbol] operation category
      # @param event [WebUI::Runtime::EventContext] originating viewer
      # @return [Operation] fresh liveness token
      # @raise [WebUI::Error] for a closed launcher or an active operation of this kind
      def begin_operation(kind, event)
        operation = Operation.new(SecureRandom.hex(10), kind, event.viewer_id)
        @mutex.synchronize do
          raise Lich::WebUI::Error, 'launcher is closed' if %i[closing closed].include?(@lifecycle)
          raise Lich::WebUI::Error, "#{kind} operation already active" if @active.key?(kind)
          @active[kind] = operation
        end
        operation
      end

      # Accepts completion only for the current operation token while the launcher is open.
      # State mutation occurs under the lifecycle mutex; stale work cannot replace current state.
      # @param operation [Operation] token whose identity governs completion or cancellation
      # @return [Boolean] whether completion was accepted
      # @api private
      def complete(operation)
        accepted = @mutex.synchronize do
          next false unless @active[operation.kind]&.id == operation.id && @lifecycle != :closed
          @active.delete(operation.kind)
          yield if block_given?
          true
        end
        accepted ? refresh : @logger.call(:warning, "stale launcher completion refused kind=#{operation.kind}")
        accepted
      end

      # Completes a failed operation with authored, credential-safe feedback.
      # @param operation [Operation] token whose liveness guards visible changes
      # @param error [Exception] failure; only its class enters diagnostics
      # @param manual [String, nil] manual-entry error, if applicable
      # @param modal [Hash, nil, Symbol] replacement dialog, nil to close, or :unchanged
      # @param notice [String, nil] authored failure notice
      # @return [Object] logger result
      # @api private
      def fail_operation(operation, error, manual: nil, modal: :unchanged, notice: nil)
        notice = Catalog::LEGACY_CONVERSION_NOTICE if error.is_a?(Catalog::LegacyConversionRequired)
        complete(operation) do
          @manual.merge!(phase: :editing, error: manual) if manual
          @modal = modal unless modal == :unchanged
          @notice = { text: notice, level: 'error' } if notice
        end
        @logger.call(:error, "launcher operation failed kind=#{operation.kind} error=#{error.class}")
      end

      # Serializes final launch against cancellation, then releases the gate before teardown.
      # @api private
      # @param operation [Operation] launch token still owned by the worker
      # @param launch [Array] prepared frontend launch data
      # @param origin [Symbol] :manual or :saved_entry
      # @return [Boolean] whether launch was admitted
      def terminal_launch(operation, launch, origin)
        accepted = commit(operation) do
          @mutex.synchronize { @launch_result = launch }
          @on_launch.call(launch, origin)
        end
        close(reason: :launch) if accepted && !(origin == :saved_entry && @persistent)
        accepted
      end

      # Queues one operation and transfers its temporary carriers to worker cleanup.
      # @param operation [Operation] live operation token
      # @param secrets [Array<WebUI::SensitiveValue>] carriers owned by this work
      # @param work [Proc] work admitted through the existing operation and close gates
      # @yield work performed only while its operation remains live
      # @return [Boolean] whether the executor accepted the work
      # @api private
      def post_operation(operation, secrets: [], &work)
        accepted = @executor.post(cleanup: -> { secrets.each(&:discard!) }) do
          work.call if operation_live?(operation)
        end
        @mutex.synchronize { @active.delete(operation.kind) if @active[operation.kind] == operation } unless accepted
        accepted
      rescue StandardError
        secrets.each(&:discard!)
        @mutex.synchronize { @active.delete(operation.kind) if @active[operation.kind] == operation }
        raise
      end

      # Tests cancellation without holding the lock during authentication/network IO.
      # @api private
      # @param operation [Operation, nil] queued/running token, or nil for open-state only
      # @return [Boolean] whether the token can still produce side effects
      def operation_live?(operation)
        @mutex.synchronize do
          !%i[closing closed].include?(@lifecycle) && (!operation || @active[operation.kind]&.id == operation.id)
        end
      end

      # Serializes irreversible steps against close without holding the UI state lock.
      # A close accepted first refuses the step; an admitted step finishes before close.
      # @api private
      # @param operation [Operation, nil] token, or nil for synchronous settings work
      # @yield a short persistence or launch step; authentication belongs outside
      # @return [Boolean] whether the step ran
      def commit(operation = nil)
        @commit_mutex.synchronize do
          return false unless operation_live?(operation)

          yield
          true
        end
      end

      # Consumes a submission carrier into a new carrier owned by background work.
      # The source is disposed on block exit; the recipient must dispose the returned carrier.
      # @param carrier [Lich::WebUI::SensitiveValue] submission carrier consumed into worker-owned storage
      # @return [Lich::WebUI::SensitiveValue] transferred viewer-origin secret
      # @api private
      def transfer_secret(carrier)
        transferred = nil
        carrier.consume { |plaintext| transferred = Lich::WebUI::SensitiveValue.viewer(plaintext) }
        transferred
      end

      # Creates credential-free manual-entry defaults from cached frontend choices.
      # @return [Hash] initial manual state containing no credential carrier
      # @api private
      def default_manual_state
        {
          phase: :editing, account: '', characters: [], selected: nil, error: nil,
          frontend: @frontend_options.first&.fetch(:value, nil), custom_enabled: false
        }
      end

      # Clears the current dialog and refreshes its existing page.
      # @return [void] updates dialog state and requests refresh
      # @api private
      def cancel_modal
        @mutex.synchronize { @modal = nil }
        refresh
      end

      # Reloads catalog presentation state under the lifecycle mutex.
      # @return [void] replaces cached catalog presentation under the mutex
      # @api private
      def reload_catalog
        @mutex.synchronize { reload_catalog_locked }
      end

      # Loads a complete catalog or exposes a recoverable, non-writable error state.
      # @return [void]
      # @api private
      def reload_catalog_locked
        @entries = @catalog.entries(autosort: @autosort)
        @accounts = @catalog.accounts
        @encryption_mode = @catalog.encryption_mode
        @catalog_error = nil
      rescue Catalog::InvalidCatalogError => error
        @entries = []
        @accounts = []
        @encryption_mode = :plaintext
        @catalog_error = error.message
      end

      # Refreshes an open page, preserving its prior screen on WebUI render errors.
      # Reports bounded structural diagnostics and independent recovery feedback
      # without logging submitted values or attempting a recursive render.
      # @return [void]
      # @api private
      def refresh
        @service.refresh(@page) if @page && lifecycle != :closed
      rescue Lich::WebUI::Error => error
        # Exception messages can contain submitted values. Log only structural
        # attribution and use the independent notifier, never another render.
        details = %i[page_id cid field].map do |key|
          value = error.public_send(key).to_s.gsub(/[^a-zA-Z0-9_:\/.\[\]-]/, '?')[0, 256]
          "#{key}=#{value}"
        end.join(' ')
        log_diagnostic(:error, "WebUI launcher render refused error=#{error.class} #{details}")
        report_feedback('The launcher could not display the change. The previous screen is retained. Retry or restart the launcher; see the debug log for the affected field.')
        nil
      end

      # Retains authored manual-entry feedback and refreshes the open page.
      # @param message [String] authored feedback excluding submitted secrets
      # @return [void] requests refresh after retaining feedback
      # @api private
      def manual_error(message)
        @mutex.synchronize { @manual[:error] = message }
        refresh
      end

      # Retains an authored notice with its severity for the next render.
      # @param message [String] authored feedback excluding submitted secrets
      # @param level [Symbol] notice severity converted to its wire spelling
      # @return [void] requests refresh after retaining the notice
      # @api private
      def set_notice(message, level)
        @mutex.synchronize { @notice = { text: message, level: level.to_s } }
        refresh
      end

      # Projects authenticated character metadata into the manual selection rows.
      # @param characters [Array<Hash>] authenticated character metadata without passwords
      # @return [Array<Hash>] character name/game metadata in source order
      # @api private
      def normalize_characters(characters)
        Array(characters).map do |character|
          values = character.transform_keys { |key| key.to_s.downcase.to_sym }
          code = values[:game_code] || values[:game]
          { char_name: values[:char_name] || values[:character], game_code: code,
            game_name: values[:game_name] || GAME_NAMES.fetch(code.to_s, code.to_s) }
        end
      end

      # Formats saved frontend labels, retaining the explicit custom-launch label.
      # @param entry [Catalog::Entry] credential-free saved configuration
      # @return [String] literal frontend display label
      # @api private
      def display_frontend(entry)
        return 'Custom' unless entry.custom_launch.to_s.empty?
        entry.frontend.to_s.casecmp?('stormfront') ? 'Wrayth' : entry.frontend.to_s.capitalize
      end

      # Formats the saved game code using the existing compact realm vocabulary.
      # @param entry [Catalog::Entry] credential-free saved configuration
      # @return [String] compact realm label or original game code
      # @api private
      def display_realm(entry)
        GAME_REALMS.fetch(entry.game_code.to_s, entry.game_code.to_s)
      end

      # Captures supported frontend labels with bounded discovery-failure feedback.
      # @param refresh [Boolean] whether the existing frontend provider refreshes discovery
      # @return [Array<Hash>] frozen choice collection, empty if discovery fails
      # @api private
      def discover_frontends(refresh: false)
        FrontendChoices.all(refresh: refresh, locator: @frontend_locator).map do |choice|
          { value: choice.id, label: choice.label }
        end.freeze
      rescue StandardError => error
        @logger&.call(:warning, "frontend discovery failed error=#{error.class}")
        [].freeze
      end

      # Whether this frontend can actually be launched now. A configured
      # custom frontend counts even when the locator cannot resolve it: the
      # player gave it a launch command, and that is what will be run.
      # @param frontend [String, nil] configured frontend identifier
      # @param refresh [Boolean] whether the existing frontend provider refreshes discovery
      # @api private
      def frontend_available?(frontend, refresh: false)
        return false if frontend.to_s.empty?
        return false unless @frontend_options.any? { |option| option[:value] == frontend }

        choice = FrontendChoices.all(refresh: refresh, locator: @frontend_locator)
                                .find { |candidate| candidate.id == Frontend.canonical_name(frontend) }
        return true if choice&.state == :configured

        !@frontend_locator.resolve(frontend, refresh: refresh).nil?
      rescue StandardError => error
        @logger&.call(:warning, "frontend revalidation failed error=#{error.class}")
        false
      end

      # Reads the frontend capability that excludes custom launch commands.
      # @param frontend [String, nil] configured frontend identifier
      # @api private
      def native_launch_only?(frontend)
        return false if frontend.to_s.empty?

        Frontend.definition_for(frontend).dig(:metadata, :native_launch_only) == true
      rescue ArgumentError
        false
      end

      # Checks captured phase, character selection and frontend availability for Play.
      # @param manual [Hash] captured manual-entry metadata without retained credentials
      # @param options [Array<Hash>] captured frontend value/label choices
      # @api private
      def manual_playable?(manual, options)
        manual[:phase] == :selecting_character && !manual[:selected].nil? &&
          options.any? { |option| option[:value] == manual[:frontend] }
      end

      # Finds a submitted field by its component-ID suffix.
      # @param values [Hash{String => Object}] submitted component IDs and their values or one-shot carriers
      # @param suffix [String] authored component type/key suffix, preserving first-match lookup
      # @return [Object, nil] submitted value, or nil when absent
      # @api private
      def submitted(values, suffix)
        values.find { |key, _| key.end_with?(suffix) }&.last
      end

      # Copies the submission index while retaining its one-shot secret carriers.
      # @param submission [Lich::WebUI::Submission] accepted event-scoped value index
      # @return [Hash] component IDs mapped to submitted values
      # @api private
      def submission_values(submission)
        submission.cids.to_h { |cid| [cid, submission.fetch(cid)] }
      end

      # Normalizes empty submitted text to the existing absent-value representation.
      # @param value [Object] submitted text converted with to_s
      # @return [String, nil] nonempty text, or nil for the empty string
      # @api private
      def blank(value) = value.to_s.empty? ? nil : value.to_s

      # Nests three secret consumptions so every opened plaintext buffer is cleared on exit.
      # @param carriers [Array<Lich::WebUI::SensitiveValue>] three one-shot carriers opened only within the callback
      # @param block [Proc] operation receiving the three temporary plaintext strings
      # @yield [first, second, third] operation requiring all three secrets
      # @return [Object] block result
      # @api private
      def consume_three(carriers, &block)
        carriers.fetch(0).consume do |first|
          carriers.fetch(1).consume do |second|
            carriers.fetch(2).consume { |third| block.call(first, second, third) }
          end
        end
      end

      # Rejects differing byte lengths, then compares the complete equal-length secrets.
      # @param left [String] first temporary comparison value
      # @param right [String] second temporary comparison value
      # @return [Boolean]
      # @api private
      def secure_equal?(left, right)
        left.bytesize == right.bytesize && OpenSSL.fixed_length_secure_compare(left, right)
      end

      # Builds frontend launch metadata with explicit installation path flags.
      # Credentials are supplied through the separate authenticated launch path.
      # @param entry [Catalog::Entry] saved character and launch configuration without credentials
      # @return [Hash] launch arguments
      # @api private
      def launch_context(entry)
        { char_name: entry.char_name, game_code: entry.game_code, frontend: entry.frontend,
          custom_launch: entry.custom_launch, custom_launch_dir: entry.custom_launch_dir,
          data_dir: @data_dir, force_path_flags: true }
      end

      # Terminates the launcher's retained process with the OS-supported signal.
      # Missing processes are already closed; other failures are logged.
      # @param pid [Integer] process created for this launcher window
      # @return [void]
      # @api private
      def terminate_browser(pid)
        @browser_terminate.call(OS.windows? ? 'KILL' : 'TERM', pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      rescue StandardError => error
        @logger.call(:warning, "browser termination failed error=#{error.class}")
        begin
          @browser_terminate.call('KILL', pid)
        rescue StandardError
          nil
        end
      end

      # Finds the saved configuration matching manual launch identity and custom command.
      # @param entry [Hash] manual launch configuration used to find its persisted counterpart
      # @return [Catalog::Entry, nil] matching saved configuration, if retained
      # @api private
      def find_entry(entry)
        @catalog.entries.find do |candidate|
          candidate.user_id == entry[:user_id] && candidate.char_name == entry[:char_name] &&
            candidate.game_code == entry[:game_code] && candidate.frontend == entry[:frontend] &&
            candidate.custom_launch == entry[:custom_launch]
        end
      end
    end
  end
end
