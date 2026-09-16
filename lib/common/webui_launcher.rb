# frozen_string_literal: true

require 'openssl'
require 'securerandom'
require 'json'
require_relative '../webui'
require_relative 'authentication/authenticator'
require_relative 'authentication/launch_data'
require_relative 'front-end'
require_relative 'frontend_locator'
require_relative 'session_launcher'
require_relative 'webui_launcher/catalog'
require_relative 'webui_launcher/serial_executor'
require_relative 'webui_launcher/window_geometry_store'

module Lich
  module Common
    # Native launcher built directly on the WebUI author API. GTK remains the default
    # entry path until the R2 human gate is accepted.
    class WebUILauncher
      TABS = ['Saved Entry', 'Manual Entry', 'Account Management'].freeze
      ACCOUNT_TABS = ['Accounts', 'Add Character', 'Add Account', 'Encryption Management'].freeze
      GAMES = %w[GS3 GSF GSX GST DR DRF DRT].map { |code| { value: code, label: code } }.freeze
      GAME_NAMES = {
        'GS3' => 'GemStone IV', 'GSF' => 'GemStone IV Shattered', 'GSX' => 'GemStone IV Platinum',
        'GST' => 'GemStone IV Prime Test', 'DR' => 'DragonRealms', 'DRF' => 'DragonRealms The Fallen',
        'DRT' => 'DragonRealms Prime Test',
      }.freeze
      GAME_REALMS = {
        'GS3' => 'GS Prime', 'GSF' => 'GS Shattered', 'GSX' => 'GS Platinum', 'GST' => 'GS Test',
        'DR' => 'DR Prime', 'DRF' => 'DR Fallen', 'DRT' => 'DR Test',
      }.freeze
      Operation = Data.define(:id, :kind, :viewer_id)

      attr_reader :page

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
        @recovery = recovery || proc { |message| $stderr.puts(message) }
        @mutex = Mutex.new
        @closed_condition = ConditionVariable.new
        @lifecycle = :starting
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
      end

      def webui_owner_id = 'core.launcher'

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
              'dedicated launcher window failed to open; install Google Chrome ' \
              '(or Microsoft Edge on Windows) and retry'
      rescue Lich::WebUI::Error => error
        @recovery.call("ERROR: #{error.message}. The WebUI launcher has stopped.")
        close(reason: :browser_failure)
        raise
      rescue StandardError => error
        @recovery.call("WebUI launcher unavailable: #{error.class}. Retry with the GTK launcher or abort safely.")
        close(reason: :browser_failure)
        raise
      end

      def close(reason: :user)
        browser_pid = nil
        accepted = @mutex.synchronize do
          next false if %i[closing closed].include?(@lifecycle)

          @lifecycle = :closing
          @active.clear
          @manual_credentials.each_value(&:discard!)
          @manual_credentials.clear
          browser_pid = @browser_pid
          @browser_pid = nil
          true
        end
        return false unless accepted

        terminate_browser(browser_pid) if browser_pid
        @service.terminate_owner(self)
        @service.stop
        @executor.stop(wait: false)
        @mutex.synchronize do
          @lifecycle = :closed
          @closed_condition.broadcast
        end
        @on_close.call(reason)
        true
      end

      def lifecycle = @mutex.synchronize { @lifecycle }
      def active_operations = @mutex.synchronize { @active.dup.freeze }

      def await_launch
        @mutex.synchronize do
          @closed_condition.wait(@mutex) until @lifecycle == :closed
          @launch_result
        end
      end

      def render_tree
        @page.render.tree
      end

      private

      def build_page
        launcher = self
        Lich::WebUI::Page.new(
          owner: self, id: 'launcher', title: "Lich v#{defined?(LICH_VERSION) ? LICH_VERSION : ''}".strip,
          props: { bare: true },
          on: {
            close: ->(_event) { launcher.close(reason: :user) },
            detach: ->(event) { launcher.browser_window_closed(event.viewer_id) },
          }
        ) do
          state = launcher.__send__(:render_state)
          manual_controls = nil
          tabs(key: 'launcher-tabs', names: TABS, selected: state[:initial_tab],
               on: { select: ->(_event) {} }) do
            stack(slot: TABS[0], key: 'saved-panel') { launcher.__send__(:render_saved, self, state) }
            stack(slot: TABS[1], key: 'manual-panel') do
              manual_controls = launcher.__send__(:render_manual, self, state)
            end
            stack(slot: TABS[2], key: 'accounts-panel') { launcher.__send__(:render_accounts, self, state) }
          end
          manual_default = state[:manual][:phase] == :editing ? manual_controls[:connect] : manual_controls[:play]
          accelerators([{ keys: 'enter', target: manual_default.cid, event: 'activate' }])
          text_input(key: 'window-geometry', value: JSON.generate(state[:window_geometry]), hidden: true,
                     max_length: 256, on: { change: ->(event) { launcher.window_geometry_changed(event) } })
          launcher.__send__(:render_modal, self, state[:modal]) if state[:modal]
          notify(state[:notice]) if state[:notice]
          geometry_options = {
            width: state[:window_geometry][:width], height: state[:window_geometry][:height]
          }
          if state[:window_geometry][:position]
            geometry_options.merge!(x: state[:window_geometry][:position][0], y: state[:window_geometry][:position][1])
          end
          geometry(**geometry_options)
          presentation(always_on_top: false, scrollbars: true)
        end
      end

      def render_state
        @mutex.synchronize do
          {
            initial_tab: @entries.empty? ? 1 : 0, entries: @entries.dup, accounts: @accounts.dup,
            encryption_mode: @encryption_mode, keychain: @catalog.enhanced_encryption_available?,
            persistent: @persistent, autosort: @autosort, tab_layout: @tab_layout,
            dark_theme: @dark_theme, settings_visible: @settings_visible,
            notice: @notice, modal: @modal&.dup,
            manual: @manual.merge(characters: @manual[:characters].dup), active: @active.keys,
            draft_entry_key: @draft_entry_key, window_geometry: @window_geometry.dup,
            frontend_options: @frontend_options.map(&:dup),
          }
        end
      end

      def render_saved(ui, state)
        launcher = self
        account_names = state[:accounts].select { |account| state[:entries].any? { |entry| entry.user_id == account } }
        names = ['FAVORITES'] + account_names
        if state[:tab_layout]
          ui.tabs(key: 'saved-account-tabs', names: names, selected: 0,
                  on: { select: ->(_event) {} }) do
            stack(slot: 'FAVORITES', key: 'favorites-panel') do
              launcher.__send__(:render_entry_rows, self, state[:entries].select(&:favorite), state,
                                empty: 'No favorite characters yet.')
            end
            account_names.each do |account|
              stack(slot: account, key: "saved-account-#{account}") do
                launcher.__send__(:render_entry_rows, self,
                                  state[:entries].select { |entry| entry.user_id == account }, state,
                                  empty: 'No saved characters for this account.')
              end
            end
          end
        else
          ui.stack(key: 'saved-list-layout') do
            account_names.each do |account|
              group(key: "saved-list-account-#{account}", label: "Account: #{account.downcase}") do
                launcher.__send__(:render_entry_rows, self,
                                  state[:entries].select { |entry| entry.user_id == account }, state,
                                  empty: 'No saved characters for this account.')
              end
            end
          end
        end
        ui.button(key: 'refresh-entries', label: 'Refresh Entries',
                  on: { activate: ->(_event) { launcher.refresh_catalog } })
        ui.toggle(key: 'gui-settings-toggle', label: 'GUI Settings', checked: state[:settings_visible],
                  on: { change: ->(event) { launcher.setting_changed(event, :settings_visible) } })
        ui.stack(key: 'gui-settings-options', hidden: !state[:settings_visible]) do
          group(label: 'GUI Settings', key: 'gui-settings') do
            columns(count: 4, weights: [1, 1, 1, 1]) do
              toggle(slot: '0', key: 'dark-theme', label: 'Dark Theme', checked: state[:dark_theme],
                     on: { change: ->(event) { launcher.setting_changed(event, :dark_theme) } })
              toggle(slot: '1', key: 'tab-layout', label: 'Tab Layout', checked: state[:tab_layout],
                     on: { change: ->(event) { launcher.setting_changed(event, :tab_layout) } })
              toggle(slot: '2', key: 'autosort', label: 'AutoSort', checked: state[:autosort],
                     on: { change: ->(event) { launcher.setting_changed(event, :autosort) } })
              toggle(slot: '3', key: 'persistent', label: 'Multi-Launch', checked: state[:persistent],
                     on: { change: ->(event) { launcher.setting_changed(event, :persistent) } })
            end
            text(key: 'sort-order-description',
                 content: state[:autosort] ? 'Sort order: favorites first, then account/game/character.' :
                                            'Sort order: saved entry order.')
          end
        end
      end

      def render_entry_rows(ui, entries, state, empty:)
        launcher = self
        if entries.empty?
          ui.text(content: empty, emphasis: :subtle)
          return
        end

        ui.collection(entries) do |entry|
          realm = launcher.__send__(:display_realm, entry)
          ui.group(key: entry.key, label: "#{entry.char_name} (#{realm})") do
            if state[:tab_layout]
              columns(count: 3, weights: [7, 2, 1], gap: 4) do
                launch_label = [entry.char_name, realm,
                                launcher.__send__(:display_frontend, entry)].join('  |  ')
                button(slot: '0', key: "play-#{entry.key}", label: launch_label, variant: :primary,
                       tooltip: "Play #{entry.char_name}", a11y_label: "Play #{entry.char_name}",
                       disabled: state[:active].include?(:saved_launch),
                       on: { activate: ->(event) { launcher.saved_launch(event, entry.key) } })
                button(slot: '1', key: "remove-#{entry.key}", label: 'Remove', variant: :danger,
                       confirm: "Remove #{entry.char_name}?",
                       on: { activate: ->(event) { launcher.remove_entry(event, entry.key) } })
                button(slot: '2', key: "favorite-#{entry.key}",
                       label: entry.favorite ? 'filled_star' : 'empty_star',
                       tooltip: entry.favorite ? "Unfavorite #{entry.char_name}" : "Favorite #{entry.char_name}",
                       a11y_label: entry.favorite ? "Unfavorite #{entry.char_name}" : "Favorite #{entry.char_name}",
                       on: { activate: ->(event) { launcher.toggle_favorite(event, entry.key) } })
              end
            else
              columns(count: 2, weights: [8, 1], gap: 4) do
                play_label = ["Play #{entry.char_name}", realm,
                              launcher.__send__(:display_frontend, entry)].join(' | ')
                button(slot: '0', key: "play-#{entry.key}", label: play_label, variant: :primary,
                       tooltip: "Play #{entry.char_name}", a11y_label: "Play #{entry.char_name}",
                       disabled: state[:active].include?(:saved_launch),
                       on: { activate: ->(event) { launcher.saved_launch(event, entry.key) } })
                button(slot: '1', key: "remove-#{entry.key}", label: 'Remove', variant: :danger,
                       confirm: "Remove #{entry.char_name}?",
                       on: { activate: ->(event) { launcher.remove_entry(event, entry.key) } })
              end
            end
          end
        end
      end

      def render_manual(ui, state)
        launcher = self
        manual = state[:manual]
        connect = nil
        play = nil
        ui.group(label: 'Credentials', key: 'manual-credentials') do
          account = text_input(key: 'manual-account', label: 'User ID', value: manual[:account],
                               disabled: manual[:phase] != :editing)
          password = password_input(key: 'manual-password', label: 'Password', disabled: manual[:phase] != :editing)
          columns(count: 2, weights: [1, 1]) do
            connect = button(slot: '0', key: 'manual-connect', label: 'Connect', variant: :primary,
                             disabled: manual[:phase] != :editing, submit: [account, password],
                             on: { activate: ->(event) { launcher.manual_connect(event, account.cid, password.cid) } })
            button(slot: '1', key: 'manual-disconnect', label: 'Disconnect',
                   disabled: manual[:phase] == :editing,
                   on: { activate: ->(event) { launcher.manual_disconnect(event.viewer_id) } })
          end
          text(content: manual[:error], tone: :danger, key: 'manual-error') if manual[:error]
        end
        ui.group(label: 'Character', key: 'manual-character') do
          rows = manual[:characters].map.with_index do |character, index|
            { key: "character-#{index}", cells: { 'game' => character[:game_name], 'character' => character[:char_name] } }
          end
          table(key: 'manual-character-list', columns: [{ key: 'game', label: 'Game' }, { key: 'character', label: 'Character' }],
                rows: rows, selection: :single, selected: Array(manual[:selected]), disabled: rows.empty?,
                on: { selection_change: ->(event) { launcher.manual_select(event) } })
        end
        ui.group(label: 'Launch Options', key: 'manual-launch-options') do
          frontend_props = {
            key: 'manual-frontend', label: 'Front end', options: state[:frontend_options],
            disabled: state[:frontend_options].empty?,
            on: { change: ->(event) { launcher.manual_option_changed(event, :frontend) } }
          }
          frontend_props[:value] = manual[:frontend] if manual[:frontend]
          frontend = select(**frontend_props)
          custom_enabled = checkbox(
            key: 'manual-custom-enabled', label: 'Custom launch command', checked: manual[:custom_enabled],
            disabled: launcher.__send__(:native_launch_only?, manual[:frontend]),
            on: { change: ->(event) { launcher.manual_option_changed(event, :custom_enabled) } }
          )
          custom_fields = stack(key: 'manual-custom-fields', hidden: !manual[:custom_enabled]) do
            text_input(key: 'manual-custom', label: 'Custom command', value: '')
            text_input(key: 'manual-custom-dir', label: 'Custom launch directory', value: '')
          end
          custom = custom_fields.children[0]
          custom_dir = custom_fields.children[1]
          save = checkbox(key: 'manual-save', label: 'Save this info for quick game entry', checked: false)
          favorite = checkbox(key: 'manual-favorite', label: 'Mark as favorite', checked: false)
          columns(key: 'manual-play-actions', count: 2, weights: [4, 1]) do
            play = button(slot: '1', key: 'manual-play', label: 'Play', variant: :primary,
                          disabled: !launcher.__send__(:manual_playable?, manual, state[:frontend_options]),
                          submit: [frontend, custom_enabled, custom, custom_dir, save, favorite],
                          on: { activate: ->(event) { launcher.manual_play(event) } })
          end
        end
        { connect: connect, play: play }
      end

      def render_accounts(ui, state)
        launcher = self
        ui.tabs(key: 'account-management-tabs', names: ACCOUNT_TABS, selected: 0,
                on: { select: ->(_event) {} }) do
          stack(slot: 'Accounts', key: 'accounts-list-panel') { launcher.__send__(:render_accounts_list, self, state) }
          stack(slot: 'Add Character', key: 'add-character-panel') { launcher.__send__(:render_character_form, self, state) }
          stack(slot: 'Add Account', key: 'add-account-panel') { launcher.__send__(:render_account_form, self, state) }
          stack(slot: 'Encryption Management', key: 'encryption-panel') { launcher.__send__(:render_encryption, self, state) }
        end
      end

      def render_accounts_list(ui, state)
        launcher = self
        rows = state[:entries].map do |entry|
          { key: entry.key, cells: { 'account' => entry.user_id, 'character' => entry.char_name,
                                     'game' => entry.game_code, 'frontend' => display_frontend(entry),
                                     'favorite' => entry.favorite ? 'Yes' : 'No' } }
        end
        ui.group(label: 'Saved Accounts and Characters', key: 'accounts-table-section') do
          table(key: 'accounts-table', columns: [
                  { key: 'account', label: 'Account' }, { key: 'character', label: 'Character' },
                  { key: 'game', label: 'Game' }, { key: 'frontend', label: 'Frontend' },
                  { key: 'favorite', label: 'Favorite' },
                ], rows: rows, selection: :single, selected: Array(state[:draft_entry_key]),
                on: { selection_change: ->(event) { launcher.select_managed_entry(event) } })
          columns(count: 4, weights: [1, 1, 1, 1]) do
            button(slot: '0', key: 'accounts-refresh', label: 'Refresh', on: { activate: ->(_event) { launcher.refresh_catalog } })
            button(slot: '1', key: 'accounts-edit', label: 'Edit Character', disabled: state[:draft_entry_key].nil?,
                   on: { activate: ->(_event) { launcher.begin_edit } })
            button(slot: '2', key: 'accounts-remove-character', label: 'Remove Character', variant: :danger,
                   disabled: state[:draft_entry_key].nil?, on: { activate: ->(event) { launcher.remove_selected_entry(event) } })
            button(slot: '3', key: 'accounts-remove-account', label: 'Remove Account', variant: :danger,
                   disabled: state[:draft_entry_key].nil?, on: { activate: ->(event) { launcher.remove_selected_account(event) } })
          end
        end
      end

      def render_character_form(ui, state)
        launcher = self
        options = state[:accounts].map { |account| { value: account, label: account } }
        draft = state[:entries].find { |entry| entry.key == state[:draft_entry_key] }
        ui.group(label: draft ? 'Edit Character' : 'Add Character', key: 'character-form-section') do
          account_props = { key: 'character-account', label: 'Account', options: options,
                            disabled: !draft.nil? || options.empty? }
          account_props[:value] = draft&.user_id || state[:accounts].first unless options.empty?
          account = select(**account_props)
          name = text_input(key: 'character-name', label: 'Character', value: draft&.char_name.to_s)
          game = select(key: 'character-game', label: 'Game', options: GAMES, value: draft&.game_code || 'GS3')
          frontend_props = {
            key: 'character-frontend', label: 'Frontend', options: state[:frontend_options],
            disabled: state[:frontend_options].empty?
          }
          unless state[:frontend_options].empty?
            frontend_props[:value] = draft&.frontend || state[:frontend_options].first[:value]
          end
          frontend = select(**frontend_props)
          custom = text_input(key: 'character-custom', label: 'Custom Launch', value: draft&.custom_launch.to_s)
          custom_dir = text_input(key: 'character-custom-dir', label: 'Custom Launch Dir', value: draft&.custom_launch_dir.to_s)
          columns(count: 2, weights: [1, 1]) do
            button(slot: '0', key: 'character-back', label: 'Back to Accounts', on: { activate: ->(_event) { launcher.cancel_edit } })
            button(slot: '1', key: 'character-save', label: draft ? 'Save Character' : 'Add Character', variant: :primary,
                   disabled: options.empty? || state[:frontend_options].empty?,
                   submit: [account, name, game, frontend, custom, custom_dir],
                   on: { activate: ->(event) { launcher.save_character(event) } })
          end
        end
      end

      def render_account_form(ui, state)
        launcher = self
        ui.group(label: 'Add Account', key: 'account-form-section') do
          account = text_input(key: 'account-name', label: 'Username', value: '')
          password = password_input(key: 'account-password', label: 'Password')
          frontend_props = {
            key: 'account-frontend', label: 'Frontend', options: state[:frontend_options],
            disabled: state[:frontend_options].empty?
          }
          frontend_props[:value] = state[:frontend_options].first[:value] unless state[:frontend_options].empty?
          frontend = select(**frontend_props)
          columns(count: 2, weights: [1, 1]) do
            button(slot: '0', key: 'account-back', label: 'Back to Accounts', on: { activate: ->(_event) { launcher.cancel_edit } })
            button(slot: '1', key: 'account-add', label: 'Add Account', variant: :primary,
                   disabled: state[:frontend_options].empty?,
                   submit: [account, password, frontend],
                   on: { activate: ->(event) { launcher.save_account(event) } })
          end
        end
      end

      def render_encryption(ui, state)
        launcher = self
        ui.group(label: 'Encryption Management', key: 'encryption-section') do
          text(content: "Current mode: #{state[:encryption_mode]}", emphasis: :strong)
          text(content: state[:keychain] ? 'Secure keychain available.' : 'Secure keychain unavailable.',
               tone: state[:keychain] ? :positive : :caution)
          modes = [
            { value: 'plaintext', label: 'Plaintext' }, { value: 'standard', label: 'Standard Encryption' },
            { value: 'enhanced', label: 'Enhanced Encryption' },
          ]
          mode = radio(key: 'encryption-mode', label: 'Encryption mode', group: 'encryption-mode',
                       options: modes, selected: state[:encryption_mode].to_s)
          master = password_input(key: 'encryption-master', label: 'Master Password')
          button(key: 'encryption-change', label: 'Change Encryption Mode', variant: :primary,
                 submit: [mode, master], on: { activate: ->(event) { launcher.change_encryption(event) } })
          divider(label: 'Change Master Password')
          current = password_input(key: 'master-current', label: 'Current Master Password')
          replacement = password_input(key: 'master-new', label: 'New Master Password')
          confirmation = password_input(key: 'master-confirm', label: 'Confirm New Master Password')
          button(key: 'master-change', label: 'Change Encryption Password', variant: :primary,
                 submit: [current, replacement, confirmation],
                 on: { activate: ->(event) { launcher.change_master_password(event) } })
        end
      end

      def render_modal(ui, modal)
        launcher = self
        case modal[:kind]
        when :unlock
          secret = ui.password_input(key: 'unlock-master', label: 'Master Password')
          ui.dialog(key: 'unlock-dialog', title: 'Enter Master Password', body: modal[:error],
                    no_viewer: :abort, buttons: [
                      { id: 'cancel', label: 'Cancel' }, { id: 'unlock', label: 'Unlock', variant: 'primary' },
                    ], submit: [secret],
                    on: { response: ->(event) { launcher.unlock_response(event, secret.cid) } })
        when :confirm_delete
          ui.dialog(key: 'delete-dialog', title: 'Confirm Removal', body: modal[:body], no_viewer: :abort,
                    buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'remove', label: 'Remove', variant: 'danger' }],
                    on: { response: ->(event) { launcher.delete_response(event) } })
        end
      end

      public

      def setting_changed(event, setting)
        value = event.payload.fetch(:value)
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
        refresh
      end

      def window_geometry_changed(event)
        geometry = @geometry_store.save(JSON.parse(event.payload.fetch(:value)))
        @mutex.synchronize { @window_geometry = geometry } if geometry
        geometry
      rescue JSON::ParserError, KeyError
        false
      end

      def manual_connect(event, account_cid, password_cid)
        account = event.submission.fetch(account_cid).to_s.strip.upcase
        return manual_error('User ID is required.') if account.empty?

        credential = transfer_secret(event.submission.fetch(password_cid))
        operation = begin_operation(:manual_auth, event)
        @mutex.synchronize { @manual.merge!(phase: :authenticating, account: account, error: nil) }
        refresh
        @executor.post do
          characters = nil
          retained = nil
          credential.consume do |password|
            characters = @authenticator.authenticate(account: account, password: password, legacy: true)
            retained = Lich::WebUI::SensitiveValue.viewer(password)
          end
          complete(operation) do
            @manual_credentials[event.viewer_id]&.discard!
            @manual_credentials[event.viewer_id] = retained
            @manual.merge!(phase: :selecting_character, characters: normalize_characters(characters), selected: nil)
          end
        rescue StandardError => error
          retained&.discard!
          fail_operation(operation, error, manual: 'Authentication failed. Correct the credentials and retry.')
        end
      end

      def manual_select(event)
        selected = event.payload.fetch(:rows).first
        @mutex.synchronize { @manual[:selected] = selected }
        refresh
      end

      def manual_option_changed(event, option)
        value = event.payload.fetch(:value)
        @mutex.synchronize do
          case option
          when :frontend
            available = @frontend_options.any? { |entry| entry[:value] == value }
            @manual[:frontend] = value if available
            @manual[:custom_enabled] = false if available && native_launch_only?(value)
          when :custom_enabled
            @manual[:custom_enabled] = value == true && !native_launch_only?(@manual[:frontend])
          else
            raise ArgumentError, "unknown manual option: #{option}"
          end
        end
        refresh
      end

      def manual_disconnect(viewer_id)
        @mutex.synchronize do
          @manual_credentials.delete(viewer_id)&.discard!
          @manual = default_manual_state
        end
        refresh
      end

      def manual_play(event)
        state = @mutex.synchronize do
          selected = @manual[:selected].to_s
          index = selected.start_with?('character-') ? Integer(selected.delete_prefix('character-'), exception: false) : nil
          character = index && @manual[:characters][index]
          [@manual[:account], character, @manual_credentials[event.viewer_id], @manual[:frontend]]
        end
        account, character, credential, frontend = state
        unless character && credential && frontend && frontend_available?(frontend, refresh: true)
          return manual_error('Enter credentials, select a character, and choose an available front end before playing.')
        end

        values = submission_values(event.submission)
        return manual_error('The selected front end changed. Choose it again.') unless submitted(values, 'select:manual-frontend') == frontend

        @mutex.synchronize { @manual_credentials.delete(event.viewer_id) }
        operation = begin_operation(:manual_launch, event)
        @mutex.synchronize { @manual[:phase] = :launching }
        refresh
        @executor.post { perform_manual_launch(operation, event.viewer_id, account, character, credential, values) }
      end

      def saved_launch(event, entry_key)
        operation = begin_operation(:saved_launch, event)
        @executor.post { perform_saved_launch(operation, entry_key) }
      end

      def unlock_response(event, password_cid)
        return cancel_modal if event.payload[:button] == 'cancel'

        entry_key = @mutex.synchronize { @modal&.fetch(:entry_key, nil) }
        return event.submission.discard_sensitive! unless entry_key

        master = transfer_secret(event.submission.fetch(password_cid))
        operation = begin_operation(:saved_launch, event)
        @executor.post do
          credential = nil
          master.consume do |password|
            raise StandardError, 'Master password was not accepted.' unless @catalog.validate_master_password(password)

            credential = @catalog.credential(entry_key, master_password: password)
          end
          perform_saved_launch(operation, entry_key, credential: credential)
        rescue StandardError => error
          credential&.discard!
          fail_operation(operation, error, modal: { kind: :unlock, entry_key: entry_key, error: 'Master password was not accepted.' })
        end
      end

      def toggle_favorite(event, entry_key)
        mutate(:favorite, event, 'Favorite update failed.') do
          raise 'favorite update failed' if @catalog.toggle_favorite(entry_key).nil?
        end
      end

      def remove_entry(_event, entry_key)
        @mutex.synchronize { @modal = { kind: :confirm_delete, entry_key: entry_key, body: 'Remove this saved character?' } }
        refresh
      end

      def select_managed_entry(event)
        @mutex.synchronize { @draft_entry_key = event.payload.fetch(:rows).first }
        refresh
      end

      def begin_edit = refresh

      def cancel_edit
        @mutex.synchronize { @draft_entry_key = nil }
        refresh
      end

      def remove_selected_entry(event)
        key = @mutex.synchronize { @draft_entry_key }
        remove_entry(event, key) if key
      end

      def remove_selected_account(_event)
        entry = @mutex.synchronize { @entries.find { |candidate| candidate.key == @draft_entry_key } }
        return unless entry

        @mutex.synchronize do
          @modal = { kind: :confirm_delete, account: entry.user_id,
                     body: "Remove account #{entry.user_id} and all saved characters?" }
        end
        refresh
      end

      def delete_response(event)
        return cancel_modal unless event.payload[:button] == 'remove'

        target = @mutex.synchronize { @modal&.dup }
        return unless target

        cancel_modal
        mutate(:delete, event, 'Removal failed.') do
          result = target[:account] ? @catalog.remove_account(target[:account]) : @catalog.remove_entry(target[:entry_key])
          raise 'removal failed' unless result
        end
      end

      def save_character(event)
        values = submission_values(event.submission)
        entry_key = @mutex.synchronize { @draft_entry_key }
        character = {
          char_name: values.find { |key, _| key.end_with?('text_input:character-name') }&.last.to_s,
          game_code: values.find { |key, _| key.end_with?('select:character-game') }&.last.to_s,
          frontend: values.find { |key, _| key.end_with?('select:character-frontend') }&.last.to_s,
          custom_launch: blank(values.find { |key, _| key.end_with?('text_input:character-custom') }&.last),
          custom_launch_dir: blank(values.find { |key, _| key.end_with?('text_input:character-custom-dir') }&.last),
        }
        character[:game_name] = GAME_NAMES.fetch(character[:game_code], character[:game_code])
        account = values.find { |key, _| key.end_with?('select:character-account') }&.last.to_s
        return set_notice('Character name is required.', :error) if character[:char_name].empty?
        return set_notice('Choose an available front end.', :error) unless frontend_available?(character[:frontend], refresh: true)

        mutate(:character, event, 'Character could not be saved.') do
          success = entry_key ? @catalog.update_character(entry_key, character) : @catalog.add_character(account, character)
          raise 'character save failed' unless success
          @mutex.synchronize { @draft_entry_key = nil }
        end
      end

      def save_account(event)
        values = submission_values(event.submission)
        account = values.find { |key, _| key.end_with?('text_input:account-name') }&.last.to_s.strip.upcase
        frontend = values.find { |key, _| key.end_with?('select:account-frontend') }&.last.to_s
        password_pair = values.find { |key, _| key.end_with?('password_input:account-password') }
        return set_notice('Account name is required.', :error) if account.empty?
        return set_notice('Choose an available front end.', :error) unless frontend_available?(frontend, refresh: true)
        return set_notice('Password is required.', :error) unless password_pair

        secret = transfer_secret(password_pair.last)
        operation = begin_operation(:account, event)
        @executor.post do
          secret.consume do |password|
            characters = @authenticator.authenticate(account: account, password: password, legacy: true)
            raise 'account persistence failed' unless @catalog.add_or_update_account(account, password, characters, frontend: frontend)
          end
          complete(operation) { reload_catalog_locked }
        rescue StandardError => error
          fail_operation(operation, error, notice: 'Account authentication or save failed.')
        end
      end

      def change_encryption(event)
        values = submission_values(event.submission)
        mode = values.find { |key, _| key.end_with?('radio:encryption-mode') }&.last.to_s.to_sym
        master_pair = values.find { |key, _| key.end_with?('password_input:encryption-master') }
        return set_notice('Master password submission is incomplete.', :error) unless master_pair

        if mode == :enhanced && !@catalog.enhanced_encryption_available?
          master_pair.last.discard!
          return set_notice('Enhanced Encryption is unavailable because no secure keychain is present.', :error)
        end
        secret = transfer_secret(master_pair.last)
        operation = begin_operation(:encryption, event)
        @executor.post do
          secret.consume do |password|
            master = mode == :enhanced ? password : nil
            raise 'encryption change failed' unless @catalog.change_encryption_mode(mode, master_password: master)
          end
          complete(operation) { reload_catalog_locked }
        rescue StandardError => error
          fail_operation(operation, error, notice: 'Encryption mode change failed.')
        end
      end

      def change_master_password(event)
        values = submission_values(event.submission)
        pairs = %w[master-current master-new master-confirm].map do |key|
          values.find { |cid, _| cid.end_with?("password_input:#{key}") }
        end
        if pairs.any?(&:nil?)
          event.submission.discard_sensitive!
          return set_notice('Master password change requires all three fields.', :error)
        end

        carriers = pairs.map { |pair| transfer_secret(pair.last) }
        operation = begin_operation(:master_password, event)
        @executor.post do
          consume_three(carriers) do |current, replacement, confirmation|
            raise 'passwords do not match' unless secure_equal?(replacement, confirmation)
            raise 'password too short' if replacement.length < 8
            raise 'master password change failed' unless @catalog.change_master_password(current, replacement)
          end
          complete(operation) { reload_catalog_locked }
          set_notice('Encryption password changed.', :info)
        rescue StandardError => error
          fail_operation(operation, error, notice: 'Master password change failed.')
        ensure
          carriers.each(&:discard!)
        end
      end

      def refresh_catalog
        @executor.post do
          reload_catalog
          refresh
        end
      end

      def viewer_gone(viewer_id)
        @mutex.synchronize do
          @manual_credentials.delete(viewer_id)&.discard!
          @active.delete_if { |_kind, operation| operation.viewer_id == viewer_id }
          @manual = default_manual_state
          @modal = nil
        end
      end

      def browser_window_closed(viewer_id)
        viewer_gone(viewer_id)
        close(reason: :browser_window_closed)
      end

      private

      def perform_manual_launch(operation, viewer_id, account, character, credential, values)
        launch = nil
        credential.consume do |password|
          auth = @authenticator.authenticate(account: account, password: password,
                                             character: character[:char_name], game_code: character[:game_code])
          frontend = submitted(values, 'select:manual-frontend')
          custom_enabled = submitted(values, 'checkbox:manual-custom-enabled')
          custom = custom_enabled ? blank(submitted(values, 'text_input:manual-custom')) : nil
          custom_dir = custom_enabled ? blank(submitted(values, 'text_input:manual-custom-dir')) : nil
          launch = @launch_data.prepare(auth, frontend, custom, custom_dir)
          save = submitted(values, 'checkbox:manual-save')
          favorite = submitted(values, 'checkbox:manual-favorite')
          if save || favorite
            entry = character.merge(user_id: account, frontend: frontend, custom_launch: custom, custom_launch_dir: custom_dir)
            saved = @catalog.upsert_manual_entry(entry, password)
            @catalog.toggle_favorite(find_entry_key(entry)) if favorite && saved
          end
        end
        complete(operation) { @manual_credentials.delete(viewer_id)&.discard! }
        terminal_launch(launch, :manual)
      rescue StandardError => error
        fail_operation(operation, error, manual: 'Launch failed. Retry from Manual Entry.')
      end

      def perform_saved_launch(operation, entry_key, credential: nil)
        entry = @mutex.synchronize { @entries.find { |candidate| candidate.key == entry_key } }
        raise KeyError, 'saved entry no longer exists' unless entry

        credential ||= @catalog.credential(entry_key)
        launch = nil
        credential.consume do |password|
          auth = @authenticator.authenticate(account: entry.user_id, password: password,
                                             character: entry.char_name, game_code: entry.game_code)
          launch = @launch_data.prepare(auth, entry.frontend, entry.custom_launch, entry.custom_launch_dir)
        end
        if @persistent
          result = @session_launcher.launch(launch, launch_context: launch_context(entry))
          raise 'session launch failed' unless result[:ok]
          complete(operation) { @modal = nil }
          set_notice('Session launched.', :info)
        else
          complete(operation) { @modal = nil }
          terminal_launch(launch, :saved_entry)
        end
      rescue Catalog::MasterPasswordRequired
        complete(operation) { @modal = { kind: :unlock, entry_key: entry_key, error: nil } }
      rescue StandardError => error
        fail_operation(operation, error, notice: 'Saved-entry launch failed. Retry is available.')
      ensure
        credential&.discard!
      end

      def mutate(kind, event, failure_message, &work)
        operation = begin_operation(kind, event)
        @executor.post do
          work.call
          complete(operation) { reload_catalog_locked }
        rescue StandardError => error
          fail_operation(operation, error, notice: failure_message)
        end
      end

      def begin_operation(kind, event)
        operation = Operation.new(SecureRandom.hex(10), kind, event.viewer_id)
        @mutex.synchronize do
          raise Lich::WebUI::Error, "#{kind} operation already active" if @active.key?(kind)
          @active[kind] = operation
        end
        operation
      end

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

      def fail_operation(operation, error, manual: nil, modal: nil, notice: nil)
        complete(operation) do
          @manual.merge!(phase: :editing, error: manual) if manual
          @modal = modal if modal
          @notice = { text: notice, level: 'error' } if notice
        end
        @logger.call(:error, "launcher operation failed kind=#{operation.kind} error=#{error.class}")
      end

      def terminal_launch(launch, origin)
        @mutex.synchronize { @launch_result = launch }
        @on_launch.call(launch, origin)
        close(reason: :launch) unless origin == :saved_entry && @persistent
      end

      def transfer_secret(carrier)
        transferred = nil
        carrier.consume { |plaintext| transferred = Lich::WebUI::SensitiveValue.viewer(plaintext) }
        transferred
      end

      def default_manual_state
        {
          phase: :editing, account: '', characters: [], selected: nil, error: nil,
          frontend: @frontend_options.first&.fetch(:value, nil), custom_enabled: false
        }
      end

      def cancel_modal
        @mutex.synchronize { @modal = nil }
        refresh
      end

      def reload_catalog
        @mutex.synchronize { reload_catalog_locked }
      end

      def reload_catalog_locked
        @entries = @catalog.entries(autosort: @autosort)
        @accounts = @catalog.accounts
        @encryption_mode = @catalog.encryption_mode
      end

      def refresh
        @service.refresh(@page) if @page && lifecycle != :closed
      rescue Lich::WebUI::Error
        nil
      end

      def manual_error(message)
        @mutex.synchronize { @manual[:error] = message }
        refresh
      end

      def set_notice(message, level)
        @mutex.synchronize { @notice = { text: message, level: level.to_s } }
        refresh
      end

      def normalize_characters(characters)
        Array(characters).map do |character|
          values = character.transform_keys { |key| key.to_s.downcase.to_sym }
          code = values[:game_code] || values[:game]
          { char_name: values[:char_name] || values[:character], game_code: code,
            game_name: values[:game_name] || GAME_NAMES.fetch(code.to_s, code.to_s) }
        end
      end

      def display_frontend(entry)
        return 'Custom' unless entry.custom_launch.to_s.empty?
        entry.frontend.to_s.casecmp?('stormfront') ? 'Wrayth' : entry.frontend.to_s.capitalize
      end

      def display_realm(entry)
        GAME_REALMS.fetch(entry.game_code.to_s, entry.game_code.to_s)
      end

      def discover_frontends(refresh: false)
        @frontend_locator.available(gui_selectable: true, refresh: refresh).map do |resolution|
          { value: resolution.frontend_id.to_s, label: Frontend.display_name(resolution.frontend_id) }
        end.freeze
      rescue StandardError => error
        @logger&.call(:warning, "frontend discovery failed error=#{error.class}")
        [].freeze
      end

      def frontend_available?(frontend, refresh: false)
        return false if frontend.to_s.empty?
        return false unless @frontend_options.any? { |option| option[:value] == frontend }

        !@frontend_locator.resolve(frontend, refresh: refresh).nil?
      rescue StandardError => error
        @logger&.call(:warning, "frontend revalidation failed error=#{error.class}")
        false
      end

      def native_launch_only?(frontend)
        return false if frontend.to_s.empty?

        Frontend.definition_for(frontend).dig(:metadata, :native_launch_only) == true
      rescue ArgumentError
        false
      end

      def manual_playable?(manual, options)
        manual[:phase] == :selecting_character && !manual[:selected].nil? &&
          options.any? { |option| option[:value] == manual[:frontend] }
      end

      def submitted(values, suffix)
        values.find { |key, _| key.end_with?(suffix) }&.last
      end

      def submission_values(submission)
        submission.cids.to_h { |cid| [cid, submission.fetch(cid)] }
      end

      def blank(value) = value.to_s.empty? ? nil : value.to_s

      def consume_three(carriers, &block)
        carriers.fetch(0).consume do |first|
          carriers.fetch(1).consume do |second|
            carriers.fetch(2).consume { |third| block.call(first, second, third) }
          end
        end
      end

      def secure_equal?(left, right)
        left.bytesize == right.bytesize && OpenSSL.fixed_length_secure_compare(left, right)
      end

      def launch_context(entry)
        { char_name: entry.char_name, game_code: entry.game_code, frontend: entry.frontend,
          custom_launch: entry.custom_launch, custom_launch_dir: entry.custom_launch_dir,
          data_dir: @data_dir, force_path_flags: true }
      end

      def terminate_browser(pid)
        @browser_terminate.call('TERM', pid)
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

      def find_entry_key(entry)
        @catalog.entries.find do |candidate|
          candidate.user_id == entry[:user_id] && candidate.char_name == entry[:char_name] &&
            candidate.game_code == entry[:game_code] && candidate.frontend == entry[:frontend]
        end&.key
      end
    end
  end
end
