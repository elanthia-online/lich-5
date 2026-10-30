# frozen_string_literal: true

module WebUISpecSupport
  # Explicit launcher doubles; each suite retains its distinct catalog behavior.
  module Launcher
    # Production entry shape shared by launcher fixtures.
    Entry = Lich::Common::WebUILauncher::Catalog::Entry

    # Contract-suite discovery exposes Wrayth and Saga without launching either.
    class ReduxFrontendLocator
      Resolution = Data.define(:frontend_id) do
        def executable_path = '/fixture/frontend'
        def source = :detected
      end

      def self.available(gui_selectable:, refresh:)
        raise unless gui_selectable && refresh

        [Resolution.new('stormfront'), Resolution.new('saga')]
      end

      def self.resolve(frontend, refresh: false)
        Resolution.new(frontend) if %w[stormfront saga].include?(frontend) && [true, false].include?(refresh)
      end
    end

    # Supplies renderable catalog state and records contract-suite mutations.
    class ReduxCatalogFixture
      attr_reader :mutations

      def initialize(entries: [], keychain: true, mode: :standard)
        @entries = entries
        @keychain = keychain
        @mode = mode
        @mutations = []
      end

      def entries(autosort: false)
        autosort ? @entries.sort_by(&:char_name) : @entries
      end

      def accounts = @entries.map(&:user_id).uniq
      def encryption_mode = @mode
      def enhanced_encryption_available? = @keychain
      def toggle_favorite(key) = @mutations << [:favorite, key]
      def remove_entry(key) = @mutations << [:remove_entry, key]
      def remove_account(account) = @mutations << [:remove_account, account]
      def update_character(key, character) = @mutations << [:update_character, key, character]
      def add_character(account, character) = @mutations << [:add_character, account, character]
    end

    # Carries the originating viewer, event payload and submitted values.
    Event = Data.define(:viewer_id, :payload, :submission)

    # Runs workflow work immediately and always invokes completion cleanup.
    class ImmediateExecutor
      # Executes synchronously while honoring the production cleanup ownership contract.
      # @param cleanup [Proc, nil] completion cleanup
      # @yield fixture work
      # @return [Boolean] true after accepting the work
      def post(cleanup: nil, &work)
        work.call
        true
      ensure
        cleanup&.call
      end

      def stop(wait: true) = wait
    end

    # Workflow discovery exposes Wrayth and records explicit resolution requests.
    class WorkflowFrontendLocator
      Resolution = Data.define(:frontend_id) do
        def executable_path = '/fixture/frontend'
        def source = :detected
      end

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

    # Records refresh, owner termination and shutdown without creating a server.
    class WorkflowService
      attr_reader :terminated, :stopped, :refreshes

      def initialize
        @refreshes = 0
      end

      def refresh(_page) = @refreshes += 1
      def terminate_owner(owner) = @terminated = owner
      def stop = @stopped = true
    end

    # Supplies workflow credentials and records account/preference mutations.
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
        @calls << [:validate_master, password.dup]
        @master_valid
      end

      def upsert_manual_entry(entry, password)
        @calls << [:save_manual, entry, password]
        true
      end

      def toggle_favorite(key) = @calls << [:favorite, key]
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
  end
end
