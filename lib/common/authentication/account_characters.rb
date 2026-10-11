# frozen_string_literal: true

require 'yaml'
require_relative 'entry_store'
require_relative 'authenticator'
require_relative '../gui/account_manager'

module Lich
  module Common
    module Authentication
      # Account-level operations shared by the CLI and the GUI launcher: reading an
      # account's stored password, choosing its default frontend, and merging a
      # server character list into entry.yaml.
      #
      # Nothing here prints or prompts. Failures raise AccountCharacters::Error with
      # a reason symbol so each caller can report them in its own way (CLI exit
      # codes, GUI message boxes).
      module AccountCharacters
        # Frontend used when an account has no characters to take a preference from.
        DEFAULT_FRONTEND = 'stormfront'

        # Raised for expected account-level failures.
        class Error < StandardError
          # @return [Symbol] :account_not_found, :decrypt_failed, :no_characters or :save_failed
          attr_reader :reason

          # @param reason [Symbol] failure category
          # @param message [String] human-readable detail
          def initialize(reason, message)
            @reason = reason
            super(message)
          end
        end

        # Decrypts the password stored for an existing account.
        #
        # @param data_dir [String] directory containing entry.yaml
        # @param account [String] account username (matched upcased, as stored)
        # @return [String] plaintext password
        # @raise [Error] :account_not_found when entry.yaml or the account is missing,
        #   :decrypt_failed when no password is saved or it cannot be decrypted
        def self.stored_password(data_dir, account)
          account = account.to_s.upcase
          yaml_file = EntryStore.yaml_file_path(data_dir)
          raise Error.new(:account_not_found, 'entry.yaml not found') unless File.exist?(yaml_file)

          yaml_data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol])
          account_data = yaml_data['accounts'] && yaml_data['accounts'][account]
          raise Error.new(:account_not_found, "account '#{account}' not found") unless account_data
          # Plaintext "decryption" would hand back the nil and send it to the server.
          raise Error.new(:decrypt_failed, "no password saved for account '#{account}'") if account_data['password'].to_s.empty?

          begin
            EntryStore.decrypt_password(
              account_data['password'],
              mode: (yaml_data['encryption_mode'] || 'plaintext').to_sym,
              account_name: account
            )
          rescue StandardError => e
            # CRITICAL: Only surface e.message, NEVER password values
            raise Error.new(:decrypt_failed, e.message)
          end
        end

        # Determines the predominant frontend among a single account's existing
        # characters. Scoped to one account so a multi-account entry.yaml doesn't
        # leak another account's frontend preference into this one.
        #
        # @param yaml_file [String] path to entry.yaml
        # @param account [String] account username (already upcased) to scope the count to
        # @return [String, nil] predominant frontend, or nil when the account has none
        def self.predominant_frontend(yaml_file, account)
          return nil unless File.exist?(yaml_file)

          yaml_data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol])
          account_data = yaml_data['accounts'] && yaml_data['accounts'][account]
          return nil unless account_data && account_data['characters']

          frontend_counts = Hash.new(0)
          account_data['characters'].each do |char|
            fe = char['frontend']
            frontend_counts[fe] += 1 if fe && !fe.empty?
          end

          return nil if frontend_counts.empty?

          frontend_counts.max_by { |_fe, count| count }&.first
        end

        # The frontend to use for an account when none was requested: the one most
        # of its characters use, else DEFAULT_FRONTEND.
        #
        # @param data_dir [String] directory containing entry.yaml
        # @param account [String] account key exactly as stored in entry.yaml
        # @return [String] frontend identifier
        def self.default_frontend(data_dir, account)
          predominant_frontend(EntryStore.yaml_file_path(data_dir), account) || DEFAULT_FRONTEND
        end

        # Fetches an account's character list from the game servers.
        #
        # @param account [String] account username
        # @param password [String] plaintext password
        # @return [Array<Hash>] legacy authentication rows (one per character)
        # @raise [Error] :no_characters when the server returns no characters
        # @raise [StandardError] authentication failures propagate unchanged
        def self.fetch_characters(account, password)
          auth_data = Authentication.authenticate(
            account: account,
            password: password,
            legacy: true
          )

          unless auth_data && auth_data.is_a?(Array) && !auth_data.empty?
            raise Error.new(:no_characters, 'Authentication failed or no characters found')
          end

          auth_data
        end

        # Stores the characters from a server character list that the account does
        # not already have. Every stored record for a known character - including
        # its frontend, custom launch config and favorite flag - is left exactly as
        # it was, and entry.yaml is not rewritten when nothing is new.
        #
        # @param data_dir [String] directory containing entry.yaml
        # @param account [String] account username (already upcased)
        # @param password [String] plaintext password (re-encrypted on save)
        # @param auth_data [Array<Hash>] rows from fetch_characters
        # @param frontend [String, nil] frontend for new characters (nil means DEFAULT_FRONTEND)
        # @return [Hash] { found: Integer, added: Integer }
        # @raise [Error] :no_characters when no row is a usable character,
        #   :save_failed when entry.yaml cannot be written
        def self.store_new_characters(data_dir, account, password, auth_data, frontend)
          character_list = Lich::Common::GUI::AccountManager.convert_auth_data_to_characters(auth_data, frontend || DEFAULT_FRONTEND)

          # Defensive guard: fetch_characters already rejected an empty response, and
          # on the only production path (EAccess.auth's legacy branch) every entry
          # carries char_name/game_name/game_code, so this can't currently happen.
          # Guards against the conversion filter (or the auth path) changing later
          # and silently reporting "success (0 found)".
          raise Error.new(:no_characters, 'No valid characters found after conversion') if character_list.empty?

          yaml_file = EntryStore.yaml_file_path(data_dir)
          yaml_data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol])
          stored = yaml_data.dig('accounts', account, 'characters')

          # A stored character is the user's own record - they chose its frontend,
          # custom launch, and favorite flag - so a refresh must not restate it.
          # add_or_update_account keys character identity on
          # char_name+game_code+frontend+custom_launch, and every record built here
          # carries the one selected frontend and a nil custom launch, so handing it a
          # stored character under any other frontend or launch config would append a
          # second entry rather than match the existing one.
          new_characters = reject_stored_characters(character_list, stored)
          result = { found: character_list.length, added: new_characters.length }
          return result if new_characters.empty?

          unless Lich::Common::GUI::AccountManager.add_or_update_account(data_dir, account, password, new_characters)
            raise Error.new(:save_failed, 'Failed to save characters')
          end

          result
        end

        # @api private
        # Drops fetched characters the account already has a stored record for.
        #
        # Identity here is char_name + game_code, deliberately coarser than the
        # char_name + game_code + frontend + custom_launch that add_or_update_account
        # uses. A single character legitimately has several stored records - one per
        # frontend or custom launch config the user set up - and all of them describe
        # a character the server has already told us about, so any of them is enough
        # to consider it known.
        #
        # @param fetched [Array<Hash>] characters built from the auth response (symbol keys)
        # @param stored [Array<Hash>, nil] the account's entry.yaml characters (string keys)
        # @return [Array<Hash>] the subset of fetched not already present in stored
        def self.reject_stored_characters(fetched, stored)
          known = (stored || []).map { |char| [normalize_char_name(char['char_name']), char['game_code']] }

          fetched.reject { |char| known.include?([normalize_char_name(char[:char_name]), char[:game_code]]) }
        end

        # @api private
        # Normalizes a character name to the form add_or_update_account persists, so
        # names compare equal regardless of the casing the server or entry.yaml used.
        #
        # @param name [String, nil] character name
        # @return [String] normalized name
        def self.normalize_char_name(name)
          name.to_s.strip.split.map(&:capitalize).join(' ')
        end
      end
    end
  end
end
