# frozen_string_literal: true

require 'openssl'
require 'yaml'
require_relative '../authentication/entry_store'
require_relative '../authentication/master_password_manager'
require_relative '../../webui/sensitive_value'

module Lich
  module Common
    class WebUILauncher
      # Reads and mutates launcher data without retaining decrypted credentials.
      #
      # The WebUI launcher's view of the saved-login store (entry.yaml, or the
      # legacy entry.dat until it is converted). Every read hands back password-free
      # {Entry} values; the one method that produces a plaintext password,
      # {#credential}, wraps it in a Lich::WebUI::SensitiveValue. All access is
      # serialised on an internal mutex.
      class Catalog
        # Launcher settings the catalog persists, mapped to the Lich writer for each.
        SETTING_WRITERS = {
          dark_theme: :track_dark_mode=,
          tab_layout: :track_layout_state=,
          autosort: :track_autosort_state=,
          persistent: :track_persistent_launcher_mode=,
        }.freeze

        # Raised when enhanced encryption is in effect and no master password is in the
        # keychain or supplied by the caller.
        class MasterPasswordRequired < StandardError; end

        # One saved character, without its password. `key` is the stable identity
        # derived from account, character, game, frontend and custom launch.
        Entry = Data.define(
          :key, :user_id, :char_name, :game_code, :game_name, :frontend,
          :custom_launch, :custom_launch_dir, :favorite, :favorite_order
        )

        # @return [String] directory the saved-login files live in
        attr_reader :data_dir

        # @param data_dir [String] directory the saved-login files live in
        # @param entry_store [Module] the entry.yaml codec (Authentication::EntryStore in production)
        # @param master_password_manager [Module] keychain access
        #   (Authentication::MasterPasswordManager in production)
        # @return [Catalog]
        def initialize(data_dir:, entry_store: Authentication::EntryStore,
                       master_password_manager: Authentication::MasterPasswordManager)
          @data_dir = data_dir
          @entry_store = entry_store
          @master_password_manager = master_password_manager
          @mutex = Mutex.new
        end

        # Every saved character, favorites first, with no password attached.
        #
        # @param autosort [Boolean] true sorts by game, account and character after the favorites;
        #   false keeps saved order (favorites by their favorite_order)
        # @return [Array<Entry>]
        def entries(autosort: false)
          @mutex.synchronize do
            source_entries.map do |entry|
              Entry.new(
                entry.fetch(:key), entry.fetch(:user_id).to_s, entry.fetch(:char_name).to_s,
                entry.fetch(:game_code).to_s, entry[:game_name].to_s, entry[:frontend].to_s,
                entry[:custom_launch], entry[:custom_launch_dir], entry[:is_favorite] == true,
                entry[:favorite_order]
              )
            end.then { |items| sort_entries(items, autosort) }
          end
        end

        # The account names in the store, including accounts with no characters.
        #
        # @return [Array<String>] upper-cased account names
        def accounts
          @mutex.synchronize do
            file = @entry_store.yaml_file_path(data_dir)
            next entries_without_lock.map { |entry| entry[:user_id] }.uniq unless File.exist?(file)

            yaml_data.fetch('accounts', {}).keys
          end
        end

        # Persists one launcher setting through the matching Lich writer.
        #
        # @param setting [Symbol] a key of {SETTING_WRITERS}
        # @param value [Boolean] the new value
        # @return [Boolean] true
        # @raise [KeyError] when the setting is not one the catalog persists
        def update_launcher_setting(setting, value)
          Lich.public_send(SETTING_WRITERS.fetch(setting), value)
          true
        end

        # Whether only the legacy entry.dat exists and should be migrated to entry.yaml.
        #
        # @return [Boolean]
        def legacy_conversion_needed?
          !File.exist?(@entry_store.yaml_file_path(data_dir)) && File.exist?(File.join(data_dir, 'entry.dat'))
        end

        # The store's password encryption mode.
        #
        # @return [Symbol] :plaintext, :standard or :enhanced
        def encryption_mode
          @mutex.synchronize { yaml_data.fetch('encryption_mode', 'plaintext').to_sym }
        end

        # The master password validation test stored with the file, if any.
        #
        # @return [Hash{String => Object}, nil] as built by MasterPasswordManager.create_validation_test
        def validation_test
          @mutex.synchronize { yaml_data['master_password_validation_test'] }
        end

        # Whether an OS keychain is available, which enhanced encryption requires.
        #
        # @return [Boolean]
        def enhanced_encryption_available?
          @master_password_manager.keychain_available?
        end

        # Decrypts one entry's account password into a server-origin sensitive carrier.
        #
        # The returned carrier is the first plaintext representation produced by
        # this boundary and never enters launcher state or a page tree.
        #
        # @param entry_key [String] the {Entry#key} to look up
        # @param master_password [String, nil] master password for enhanced mode; when nil it is
        #   read from the keychain
        # @return [Lich::WebUI::SensitiveValue] the plaintext password, consumable once
        # @raise [KeyError] when no entry has that key
        # @raise [MasterPasswordRequired] when enhanced mode is in effect and no master password is
        #   supplied or stored
        def credential(entry_key, master_password: nil)
          @mutex.synchronize do
            metadata = entries_without_lock.find { |entry| entry[:key] == entry_key }
            raise KeyError, 'saved entry no longer exists' unless metadata

            raw, mode = raw_credential(metadata)
            if mode == :enhanced && master_password.nil?
              master_password = @master_password_manager.retrieve_master_password
              raise MasterPasswordRequired, 'master password is required' if master_password.to_s.empty?
            end
            plaintext = @entry_store.decrypt_password(
              raw, mode: mode, account_name: metadata[:user_id], master_password: master_password
            )
            Lich::WebUI::SensitiveValue.server(plaintext)
          ensure
            plaintext&.replace("\0" * plaintext.bytesize)&.clear if plaintext.is_a?(String) && !plaintext.frozen?
          end
        end

        # Checks a master password against the stored validation test and, when it
        # passes, stores it in the keychain for later reads.
        #
        # @param password [String] the master password to check
        # @return [Boolean] true when the password is accepted
        def validate_master_password(password)
          test = validation_test
          return false unless @master_password_manager.validate_master_password(password, test)

          @master_password_manager.store_master_password(password)
          true
        end

        # Saves the entry a Manual Entry play produced: the account password is
        # (re)encrypted and the character is added or updated in place.
        #
        # @param entry [Hash{Symbol => Object}] :user_id, :char_name, :game_code, :frontend, and
        #   optionally :game_name, :custom_launch, :custom_launch_dir
        # @param password [String] the account password to store
        # @return [String, nil] the {Entry#key} of the entry written, or nil when the write failed
        # @raise [MasterPasswordRequired] when enhanced mode is in effect and no master password is
        #   in the keychain
        def upsert_manual_entry(entry, password)
          @mutex.synchronize do
            data = writable_yaml_data
            account = entry.fetch(:user_id).to_s.upcase
            mode = data.fetch('encryption_mode', 'plaintext').to_sym
            master = mode == :enhanced ? @master_password_manager.retrieve_master_password : nil
            raise MasterPasswordRequired, 'master password is required' if mode == :enhanced && master.to_s.empty?

            account_data = (data['accounts'][account] ||= { 'characters' => [] })
            account_data['password'] = @entry_store.encrypt_password(
              password, mode: mode, account_name: account, master_password: master
            )
            characters = (account_data['characters'] ||= [])
            character = characters.find do |candidate|
              candidate['char_name'].to_s.casecmp?(entry.fetch(:char_name).to_s) &&
                candidate['game_code'].to_s == entry.fetch(:game_code).to_s &&
                candidate['frontend'].to_s == entry.fetch(:frontend).to_s &&
                candidate['custom_launch'].to_s == entry[:custom_launch].to_s
            end
            character ||= {}.tap { |candidate| characters << candidate }
            character.merge!(
              'char_name'         => normalize_character_name(entry.fetch(:char_name)),
              'game_code'         => entry.fetch(:game_code).to_s,
              'game_name'         => entry[:game_name].to_s,
              'frontend'          => entry.fetch(:frontend).to_s,
              'custom_launch'     => entry[:custom_launch],
              'custom_launch_dir' => entry[:custom_launch_dir]
            )
            return nil unless write_yaml(data)

            # The key of the entry just written -- the whole identity, custom
            # launch included, so a caller acting on the saved entry acts on
            # this one and not on a sibling that shares its character and
            # frontend (review 2026-09-17 (b), F6).
            entries_without_lock.find do |candidate|
              candidate[:user_id] == account &&
                candidate[:char_name].to_s.casecmp?(character['char_name'].to_s) &&
                candidate[:game_code].to_s == character['game_code'] &&
                candidate[:frontend].to_s == character['frontend'] &&
                candidate[:custom_launch].to_s == character['custom_launch'].to_s
            end&.fetch(:key)
          end
        end

        # Adds an account, or replaces its password, and appends any characters not
        # already saved for that frontend.
        #
        # @param account [String] account name, upper-cased for storage
        # @param password [String] the account password to store
        # @param characters [Array<Hash{Symbol => Object}>] :char_name, :game_code and optionally
        #   :game_name, as returned by authentication
        # @param frontend [String] frontend identifier saved on every new character
        # @return [Boolean] whether the file was written
        # @raise [MasterPasswordRequired] when enhanced mode is in effect and no master password is
        #   in the keychain
        def add_or_update_account(account, password, characters, frontend:)
          @mutex.synchronize do
            data = writable_yaml_data
            name = account.to_s.upcase
            mode = data.fetch('encryption_mode', 'plaintext').to_sym
            master = mode == :enhanced ? @master_password_manager.retrieve_master_password : nil
            raise MasterPasswordRequired, 'master password is required' if mode == :enhanced && master.to_s.empty?
            account_data = (data['accounts'][name] ||= { 'characters' => [] })
            account_data['password'] = @entry_store.encrypt_password(
              password, mode: mode, account_name: name, master_password: master
            )
            existing = account_data['characters'] ||= []
            characters.each do |character|
              next if existing.any? do |candidate|
                candidate['char_name'].to_s.casecmp?(character.fetch(:char_name).to_s) &&
                candidate['game_code'].to_s == character.fetch(:game_code).to_s &&
                candidate['frontend'].to_s == frontend.to_s
              end

              existing << {
                'char_name' => normalize_character_name(character.fetch(:char_name)),
                'game_code' => character.fetch(:game_code).to_s,
                'game_name' => character[:game_name].to_s,
                'frontend'  => frontend.to_s,
              }
            end
            write_yaml(data)
          end
        end

        # Removes an account and every character saved under it.
        #
        # @param account [String] account name, matched case-insensitively
        # @return [Boolean] false when no such account exists or the write failed
        def remove_account(account)
          @mutex.synchronize do
            data = writable_yaml_data
            removed = data['accounts'].delete(account.to_s.upcase)
            removed ? write_yaml(data) : false
          end
        end

        # Adds a character to an existing account.
        #
        # @param account [String] account name, matched case-insensitively
        # @param character [Hash{Symbol => Object}] :char_name, :game_code, :game_name, :frontend and
        #   optionally :custom_launch, :custom_launch_dir
        # @return [Boolean] false when the account is unknown, the character (same name, game,
        #   frontend and custom launch) is already saved, or the write failed
        def add_character(account, character)
          @mutex.synchronize do
            data = writable_yaml_data
            account_data = data.fetch('accounts', {})[account.to_s.upcase]
            return false unless account_data

            characters = account_data['characters'] ||= []
            duplicate = characters.any? do |candidate|
              candidate['char_name'].to_s.casecmp?(character.fetch(:char_name).to_s) &&
                candidate['game_code'].to_s == character.fetch(:game_code).to_s &&
                candidate['frontend'].to_s == character.fetch(:frontend).to_s &&
                candidate['custom_launch'].to_s == character[:custom_launch].to_s
            end
            return false if duplicate

            characters << {
              'char_name'         => normalize_character_name(character.fetch(:char_name)),
              'game_code'         => character.fetch(:game_code).to_s,
              'game_name'         => character.fetch(:game_name).to_s,
              'frontend'          => character.fetch(:frontend).to_s,
              'custom_launch'     => character[:custom_launch],
              'custom_launch_dir' => character[:custom_launch_dir],
            }
            write_yaml(data)
          end
        end

        # Rewrites a saved character's fields in place, keeping its favorite status.
        #
        # @param entry_key [String] the {Entry#key} of the character to edit
        # @param character [Hash{Symbol => Object}] :char_name, :game_code, :game_name, :frontend and
        #   optionally :custom_launch, :custom_launch_dir
        # @return [Boolean] false when the key does not resolve or the write failed
        def update_character(entry_key, character)
          @mutex.synchronize do
            metadata = entries_without_lock.find { |entry| entry[:key] == entry_key }
            return false unless metadata

            data = writable_yaml_data
            account = data.fetch('accounts', {})[metadata[:user_id]]
            current = account&.fetch('characters', [])&.find { |candidate| character_match?(candidate, metadata) }
            return false unless current

            current.merge!(
              'char_name'         => normalize_character_name(character.fetch(:char_name)),
              'game_code'         => character.fetch(:game_code).to_s,
              'game_name'         => character.fetch(:game_name).to_s,
              'frontend'          => character.fetch(:frontend).to_s,
              'custom_launch'     => character[:custom_launch],
              'custom_launch_dir' => character[:custom_launch_dir]
            )
            write_yaml(data)
          end
        end

        # Replaces an account's password after checking the current one.
        #
        # @param account [String] account name, matched case-insensitively
        # @param current_password [String] the password on file
        # @param new_password [String] the replacement
        # @return [Boolean] false when the account is unknown, the current password does not match,
        #   or the write failed
        def change_account_password(account, current_password, new_password)
          @mutex.synchronize do
            data = writable_yaml_data
            name = account.to_s.upcase
            account_data = data.fetch('accounts', {})[name]
            return false unless account_data

            mode = data.fetch('encryption_mode', 'plaintext').to_sym
            master = mode == :enhanced ? @master_password_manager.retrieve_master_password : nil
            plaintext = @entry_store.decrypt_password(
              account_data.fetch('password').to_s, mode: mode, account_name: name, master_password: master
            )
            return false unless secure_equal?(plaintext, current_password)

            account_data['password'] = @entry_store.encrypt_password(
              new_password, mode: mode, account_name: name, master_password: master
            )
            write_yaml(data)
          ensure
            scrub!(plaintext)
          end
        end

        # Removes one saved character; the account and its password stay.
        #
        # @param entry_key [String] the {Entry#key} to remove
        # @return [Boolean] false when the key does not resolve or the write failed
        def remove_entry(entry_key)
          @mutex.synchronize do
            metadata = entries_without_lock.find { |entry| entry[:key] == entry_key }
            return false unless metadata

            data = writable_yaml_data
            account = data.fetch('accounts', {})[metadata[:user_id]]
            return false unless account

            characters = account.fetch('characters', [])
            before = characters.length
            characters.reject! { |candidate| character_match?(candidate, metadata) }
            return false if before == characters.length

            write_yaml(data)
          end
        end

        # Flips an entry's favorite status.
        #
        # @param entry_key [String] the {Entry#key} to change
        # @return [Boolean, nil] the new favorite status; false also when the key does not resolve,
        #   nil when the write failed
        def toggle_favorite(entry_key)
          update_favorite(entry_key) { |current| !current }
        end

        # Makes the entry a favorite, or not, whatever it was: what a box
        # labelled "favorite" on a save asks for. Answers as toggle_favorite.
        #
        # @param entry_key [String] the {Entry#key} to change
        # @param wanted [Boolean] whether the entry should be a favorite
        # @return [Boolean, nil] as {#toggle_favorite}
        def set_favorite(entry_key, wanted)
          update_favorite(entry_key) { |_current| wanted ? true : false }
        end

        # Sets an entry's favorite status from a block and renumbers favorite order.
        #
        # A new favorite is appended to the order; an unfavorited entry is dropped
        # from it and the remaining favorites are renumbered from 1.
        #
        # @param entry_key [String] the {Entry#key} to change
        # @yield [current] decides the new status
        # @yieldparam current [Boolean] whether the entry is a favorite now
        # @yieldreturn [Boolean] whether it should be one
        # @return [Boolean, nil] the resulting status; false also when the key does not resolve,
        #   nil when the write failed
        def update_favorite(entry_key)
          @mutex.synchronize do
            metadata = entries_without_lock.find { |entry| entry[:key] == entry_key }
            return false unless metadata

            data = writable_yaml_data
            account = data.fetch('accounts', {})[metadata[:user_id]]
            character = account&.fetch('characters', [])&.find { |candidate| character_match?(candidate, metadata) }
            return false unless character

            favorite = yield(character['is_favorite'] == true)
            return favorite if favorite == (character['is_favorite'] == true)

            character['is_favorite'] = favorite
            if favorite
              character['favorite_order'] = next_favorite_order(data)
              character['favorite_added'] = Time.now.to_s
            else
              character.delete('favorite_order')
              character.delete('favorite_added')
              normalize_favorite_order(data)
            end
            write_yaml(data) ? favorite : nil
          end
        end

        # Re-encrypts every stored password under a new mode, via the entry store.
        #
        # @param mode [Symbol, String] :plaintext, :standard or :enhanced
        # @param master_password [String, nil] required for :enhanced
        # @return [Boolean] whether the entry store reported success
        def change_encryption_mode(mode, master_password: nil)
          @entry_store.change_encryption_mode(data_dir, mode.to_sym, master_password)
        end

        # Converts the legacy entry.dat into entry.yaml, via the entry store.
        #
        # @param mode [Symbol, String] encryption mode for the new file
        # @param master_password [String, nil] required for :enhanced
        # @return [Boolean] whether the entry store reported success
        def migrate_legacy(mode, master_password: nil)
          @entry_store.migrate_from_legacy(
            data_dir, encryption_mode: mode.to_sym, master_password: master_password
          )
        end

        # Replaces the master password: every account password is re-encrypted, a new
        # validation test is stored, and the keychain is updated.
        #
        # When the file write fails the keychain is restored to the current password.
        #
        # @param current_password [String] the master password in effect
        # @param new_password [String] its replacement
        # @return [Boolean] false unless the mode is :enhanced, the current password validates, the
        #   keychain accepts the new one, and the file is written
        def change_master_password(current_password, new_password)
          @mutex.synchronize do
            data = writable_yaml_data
            return false unless data.fetch('encryption_mode', 'plaintext').to_sym == :enhanced
            return false unless @master_password_manager.validate_master_password(
              current_password, data['master_password_validation_test']
            )

            data.fetch('accounts', {}).each do |name, account_data|
              plaintext = @entry_store.decrypt_password(
                account_data.fetch('password').to_s, mode: :enhanced,
                account_name: name, master_password: current_password
              )
              account_data['password'] = @entry_store.encrypt_password(
                plaintext, mode: :enhanced, account_name: name, master_password: new_password
              )
              scrub!(plaintext)
            end
            data['master_password_validation_test'] = @master_password_manager.create_validation_test(new_password)
            return false unless @master_password_manager.store_master_password(new_password)

            written = write_yaml(data)
            @master_password_manager.store_master_password(current_password) unless written
            written
          ensure
            scrub!(plaintext)
          end
        end

        private

        def source_entries
          raw_entries = entries_without_lock
          raw_entries.map { |entry| entry.except(:password, :encryption_mode) }
        ensure
          raw_entries&.each do |entry|
            password = entry[:password]
            password.replace("\0" * password.bytesize).clear if password.is_a?(String) && !password.frozen?
          end
        end

        def entries_without_lock
          file = @entry_store.yaml_file_path(data_dir)
          if File.exist?(file)
            data = yaml_data
            mode = data.fetch('encryption_mode', 'plaintext').to_sym
            taken = {}
            data.fetch('accounts', {}).flat_map do |account, account_data|
              account_data.fetch('characters', []).map do |character|
                {
                  key: stable_key(account, character['char_name'], character['game_code'],
                                  character['frontend'], character['custom_launch'], taken),
                  user_id: account, password: account_data['password'],
                  encryption_mode: mode, char_name: character['char_name'], game_code: character['game_code'],
                  game_name: character['game_name'], frontend: character['frontend'],
                  custom_launch: character['custom_launch'], custom_launch_dir: character['custom_launch_dir'],
                  is_favorite: character['is_favorite'], favorite_order: character['favorite_order'],
                }
              end
            end
          else
            legacy_entries
          end
        end

        def legacy_entries
          file = File.join(data_dir, 'entry.dat')
          return [] unless File.exist?(file)

          decoded = File.open(file, 'rb') { |io| Marshal.load(io.read.unpack1('m')) }
          return [] unless decoded.is_a?(Array) && decoded.all? { |entry| valid_legacy_entry?(entry) }

          taken = {}
          decoded.map do |entry|
            entry = entry.transform_keys(&:to_sym)
            entry.merge(key: stable_key(entry[:user_id], entry[:char_name], entry[:game_code],
                                        entry[:frontend], entry[:custom_launch], taken),
                        encryption_mode: :plaintext)
          end
        rescue StandardError => error
          Lich.log("error: unable to read legacy launcher entries: #{error.class}: #{error.message}") if Lich.respond_to?(:log)
          []
        end

        # An entry's key is its identity, not its position. Keys used to be
        # "entry-N" from the enumeration index on every read, so removing one
        # entry renamed every entry after it: a stale editor, confirmation or
        # queued operation holding Beta's key then acted on the entry that
        # had moved into it, and a second launcher or process editing the
        # shared file was enough to bring that about. Derived from what
        # makes the entry itself -- account, character, game -- the key
        # survives changes to its neighbours, and a key whose entry is gone
        # simply fails to resolve, which is the refusal a stale action needs.
        # The identity is the whole of what makes an entry distinct -- the
        # catalog lets one character be saved twice with different frontends
        # or custom launch commands, and hashing only account, character and
        # game told those apart by an ordinal, which is a position again:
        # removing the first moved the second onto its key (review
        # 2026-09-17, R8). Frontend and custom launch are in the digest now;
        # an ordinal remains only for entries identical in every field.
        def stable_key(user_id, char_name, game_code, frontend, custom_launch, taken)
          digest = OpenSSL::Digest::SHA256.hexdigest(
            [user_id, char_name, game_code, frontend, custom_launch].map(&:to_s).join("\0")
          )[0, 12]
          base = "entry-#{digest}"
          count = taken[base] = (taken[base] || 0) + 1
          count == 1 ? base : "#{base}-#{count}"
        end

        def raw_credential(metadata)
          [metadata.fetch(:password).to_s, metadata.fetch(:encryption_mode).to_sym]
        end

        def writable_yaml_data
          data = yaml_data
          data['accounts'] ||= {}
          data['encryption_mode'] ||= 'plaintext'
          data
        end

        def yaml_data
          file = @entry_store.yaml_file_path(data_dir)
          return { 'accounts' => {}, 'encryption_mode' => 'plaintext' } unless File.exist?(file)

          YAML.safe_load_file(file, permitted_classes: [Symbol]) || {}
        end

        def write_yaml(data)
          @entry_store.write_yaml_file(@entry_store.yaml_file_path(data_dir), data)
          true
        rescue StandardError => error
          Lich.log("error: unable to persist launcher catalog: #{error.class}: #{error.message}") if Lich.respond_to?(:log)
          false
        end

        def character_match?(candidate, metadata)
          candidate['char_name'].to_s == metadata[:char_name].to_s &&
            candidate['game_code'].to_s == metadata[:game_code].to_s &&
            candidate['frontend'].to_s == metadata[:frontend].to_s &&
            candidate['custom_launch'].to_s == metadata[:custom_launch].to_s
        end

        def normalize_character_name(value)
          value.to_s.strip.split.map(&:capitalize).join(' ')
        end

        def valid_legacy_entry?(entry)
          return false unless entry.is_a?(Hash)

          scalar = ->(value) { value.nil? || value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Numeric) || value == true || value == false }
          entry.all? { |key, value| scalar.call(key) && scalar.call(value) }
        end

        def next_favorite_order(data)
          orders = data.fetch('accounts', {}).values.flat_map do |account|
            account.fetch('characters', []).filter_map { |character| character['favorite_order'] }
          end
          orders.map(&:to_i).max.to_i + 1
        end

        def normalize_favorite_order(data)
          favorites = data.fetch('accounts', {}).values.flat_map do |account|
            account.fetch('characters', []).select { |character| character['is_favorite'] == true }
          end
          favorites.sort_by { |character| character['favorite_order'].to_i }
                   .each_with_index { |character, index| character['favorite_order'] = index + 1 }
        end

        def sort_entries(items, autosort)
          return items.sort_by { |entry| [entry.favorite ? 0 : 1, entry.favorite_order.to_i] } unless autosort

          items.sort_by { |entry| [entry.favorite ? 0 : 1, entry.game_name, entry.user_id, entry.char_name] }
        end

        def secure_equal?(left, right)
          left = left.to_s
          right = right.to_s
          left.bytesize == right.bytesize && OpenSSL.fixed_length_secure_compare(left, right)
        end

        def scrub!(value)
          value.replace("\0" * value.bytesize).clear if value.is_a?(String) && !value.frozen?
        end
      end
    end
  end
end
