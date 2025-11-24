# frozen_string_literal: true

require_relative 'state'
require_relative 'password_cipher'
require_relative 'master_password_manager'
require_relative 'master_password_prompt'

module Lich
  module Common
    module GUI
      # Handles YAML-based state management for the Lich GUI login system
      # Provides a more maintainable alternative to the Marshal-based state system
      # Enhanced with password encryption support
      module YamlState
        # Generates the full path to the entry.yaml file.
        #
        # @param data_dir [String] The directory where the entry.yaml file is located.
        # @return [String] The full path to the entry.yaml file.
        def self.yaml_file_path(data_dir)
          File.join(data_dir, "entry.yaml")
        end

        # Loads saved entry data from YAML file
        # Reads and deserializes entry data from the entry.yaml file, with fallback to entry.dat
        # Enhanced to support favorites functionality and encryption with backward compatibility
        #
        # @param data_dir [String] Directory containing entry data
        # @param autosort_state [Boolean] Whether to use auto-sorting
        # @return [Array] Array of saved login entries in the legacy format with favorites info
        def self.load_saved_entries(data_dir, autosort_state)
          # Guard against nil data_dir
          return [] if data_dir.nil?

          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
          dat_file = File.join(data_dir, "entry.dat")

          if File.exist?(yaml_file)
            # Load from YAML format
            begin
              yaml_data = YAML.load_file(yaml_file)

              # Migrate data structure if needed to support favorites and encryption
              yaml_data = migrate_to_favorites_format(yaml_data)
              yaml_data = migrate_to_encryption_format(yaml_data)

              entries = convert_yaml_to_legacy_format(yaml_data)

              # Apply sorting with favorites priority if enabled
              sort_entries_with_favorites(entries, autosort_state)

              entries
            rescue StandardError => e
              Lich.log "error: Error loading YAML entry file: #{e.message}"
              []
            end
          elsif File.exist?(dat_file)
            # Fall back to legacy format if YAML doesn't exist
            Lich.log "info: YAML entry file not found, falling back to legacy format"
            State.load_saved_entries(data_dir, autosort_state)
          else
            # No entry file exists
            []
          end
        end

        # Saves entry data to YAML file
        # Converts and serializes entry data to the entry.yaml file with encryption support
        # Preserves master_password_validation_test from existing YAML during round-trip conversion
        #
        # @param data_dir [String] Directory to save entry data
        # @param entry_data [Array] Array of entry data in legacy format
        # @return [Boolean] True if save was successful
        def self.save_entries(data_dir, entry_data)
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          # Preserve validation test from existing YAML if it exists
          original_validation_test = nil
          if File.exist?(yaml_file)
            begin
              original_data = YAML.load_file(yaml_file)
              original_validation_test = original_data['master_password_validation_test'] if original_data.is_a?(Hash)
            rescue StandardError => e
              Lich.log "warning: Could not load existing YAML to preserve validation test: #{e.message}"
            end
          end

          # Convert legacy format to YAML structure, passing validation test to preserve it
          yaml_data = convert_legacy_to_yaml_format(entry_data, original_validation_test)

          # Create backup of existing file if it exists
          if File.exist?(yaml_file)
            backup_file = "#{yaml_file}.bak"
            FileUtils.cp(yaml_file, backup_file)
          end

          # Write YAML data to file with secure permissions
          begin
            write_yaml_file(yaml_file, yaml_data)
            true
          rescue StandardError => e
            Lich.log "error: Error saving YAML entry file: #{e.message}"
            false
          end
        end

        # Migrates from legacy Marshal format to YAML format with encryption support
        # Converts entry.dat to entry.yaml format for improved maintainability
        #
        # @param data_dir [String] Directory containing entry data
        # @param encryption_mode [Symbol] Encryption mode (:plaintext, :account_name, :enhanced)
        # @return [Boolean] True if migration was successful
        def self.migrate_from_legacy(data_dir, encryption_mode: :plaintext)
          dat_file = File.join(data_dir, "entry.dat")
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          # Skip if YAML file already exists or DAT file doesn't exist
          return false unless File.exist?(dat_file)
          return false if File.exist?(yaml_file)

          # ====================================================================
          # Handle master_password mode - check for existing or create new
          # ====================================================================
          master_password = nil
          validation_test = nil
          if encryption_mode == :enhanced
            # First check if master password already exists in keychain
            result = get_existing_master_password_for_migration

            # If no existing password, prompt user to create one
            if result.nil?
              result = ensure_master_password_exists
            end

            if result.nil?
              Lich.log "error: Master password not available for migration"
              return false
            end

            # Handle both new (Hash) and existing (String) password returns
            if result.is_a?(Hash)
              master_password = result[:password]
              validation_test = result[:validation_test]
            else
              master_password = result
            end
          end

          # Load legacy data
          legacy_entries = State.load_saved_entries(data_dir, false)

          # Add encryption_mode to entries
          legacy_entries.each do |entry|
            entry[:encryption_mode] = encryption_mode
          end

          # Encrypt passwords if not plaintext mode
          if encryption_mode != :plaintext
            legacy_entries.each do |entry|
              entry[:password] = encrypt_password(
                entry[:password],
                mode: encryption_mode,
                account_name: entry[:user_id],
                master_password: master_password # NEW: Pass master password
              )
            end
          end

          # Use save_entries to maintain test compatibility
          save_entries(data_dir, legacy_entries)

          # Save validation test to YAML if it was created
          if validation_test && encryption_mode == :enhanced
            yaml_file = yaml_file_path(data_dir)
            if File.exist?(yaml_file)
              yaml_data = YAML.load_file(yaml_file)
              yaml_data['master_password_validation_test'] = validation_test
              write_yaml_file(yaml_file, yaml_data)
            end
          end

          # Log conversion summary
          account_names = legacy_entries.map { |entry| entry[:user_id] }.uniq.sort.join(', ')
          Lich.log "info: Migration complete - Encryption mode: #{encryption_mode.upcase}, Converted accounts: #{account_names}"

          true
        end

        # Encrypts a password based on the current encryption mode
        #
        # @param password [String] Plaintext password
        # @param mode [Symbol] Encryption mode (:plaintext, :account_name, :enhanced)
        # @param account_name [String, nil] Account name for :account_name mode
        # @param master_password [String, nil] Master password for :enhanced mode
        # @return [String] Encrypted password or plaintext if mode is :plaintext
        def self.encrypt_password(password, mode:, account_name: nil, master_password: nil)
          return password if mode == :plaintext || mode.to_sym == :plaintext

          PasswordCipher.encrypt(password, mode: mode.to_sym, account_name: account_name, master_password: master_password)
        rescue StandardError => e
          Lich.log "error: encrypt_password failed - #{e.class}: #{e.message}"
          raise
        end

        # Decrypts a password based on the current encryption mode
        #
        # @param encrypted_password [String] Encrypted password
        # @param mode [Symbol] Encryption mode (:plaintext, :account_name, :enhanced)
        # @param account_name [String, nil] Account name for :account_name mode
        # @param master_password [String, nil] Master password for :enhanced mode
        # @return [String] Decrypted plaintext password
        def self.decrypt_password(encrypted_password, mode:, account_name: nil, master_password: nil)
          return encrypted_password if mode == :plaintext || mode.to_sym == :plaintext

          # For enhanced mode: auto-retrieve from Keychain if not provided
          if mode.to_sym == :enhanced && master_password.nil?
            master_password = MasterPasswordManager.retrieve_master_password
            raise StandardError, "Master password not found in Keychain - cannot decrypt" if master_password.nil?
          end

          PasswordCipher.decrypt(encrypted_password, mode: mode.to_sym, account_name: account_name, master_password: master_password)
        rescue StandardError => e
          Lich.log "error: decrypt_password failed - #{e.class}: #{e.message}"
          raise
        end

        # Decrypts password with recovery mechanism for missing master password
        # If master password is missing from Keychain but validation test exists,
        # prompts user to re-enter master password, validates it, and saves to Keychain
        #
        # @param encrypted_password [String] Encrypted password to decrypt
        # @param mode [Symbol] Encryption mode (:plaintext, :account_name, :enhanced)
        # @param account_name [String] Account name for account_name mode
        # @param master_password [String, nil] Master password if already known
        # @param validation_test [Hash, nil] Validation test hash from YAML (optional)
        # @return [String] Decrypted password
        # @raise [StandardError] If decryption fails and cannot be recovered
        def self.decrypt_password_with_recovery(encrypted_password, mode:, account_name: nil, master_password: nil, validation_test: nil)
          # Try normal decryption first
          return decrypt_password(encrypted_password, mode: mode, account_name: account_name, master_password: master_password)
        rescue StandardError => e
          # Only attempt recovery for enhanced mode with missing master password
          if mode.to_sym == :enhanced && e.message.include?("Master password not found") && validation_test && !validation_test.empty?
            Lich.log "info: Master password missing from Keychain, attempting recovery via user prompt"

            # Show appropriate dialog based on context - use data access for conversion, recovery for actual recovery
            recovery_result = MasterPasswordPromptUI.show_password_for_data_access(validation_test)

            if recovery_result.nil? || recovery_result[:password].nil?
              Lich.log "info: User cancelled master password recovery"
              Gtk.main_quit
              return nil
            end

            recovered_password = recovery_result[:password]
            continue_session = recovery_result[:continue_session]

            # Password was validated by the UI layer, proceed with recovery
            Lich.log "info: Master password recovered and validated, storing to Keychain"

            # Save recovered password to Keychain for future use
            unless MasterPasswordManager.store_master_password(recovered_password)
              Lich.log "warning: Failed to store recovered master password to Keychain"
              # Continue anyway - decryption will still work with in-memory password
            end

            # Handle session continuation decision
            if !continue_session
              Lich.log "info: User chose to close application after password recovery"
              # Exit the application gracefully
              Gtk.main_quit
            end

            # Retry decryption with recovered password
            return decrypt_password(encrypted_password, mode: mode, account_name: account_name, master_password: recovered_password)
          else
            # Re-raise if not recoverable
            raise
          end
        end

        # Encrypts all passwords in yaml_data structure
        #
        # @param yaml_data [Hash] YAML data structure
        # @param mode [Symbol] Encryption mode
        # @param master_password [String, nil] Master password if using :enhanced mode
        # @return [Hash] YAML data with encrypted passwords
        def self.encrypt_all_passwords(yaml_data, mode, master_password: nil)
          return yaml_data if mode == :plaintext

          yaml_data['accounts'].each do |account_name, account_data|
            next unless account_data['password']

            # Encrypt password based on mode
            account_data['password'] = encrypt_password(
              account_data['password'],
              mode: mode,
              account_name: account_name,
              master_password: master_password
            )
          end

          yaml_data
        end

        # Changes encryption mode for all accounts
        # Re-encrypts all passwords from current mode to new mode
        # Automatically retrieves old master password from keychain if leaving Enhanced mode
        # Requires new_master_password if entering Enhanced mode (caller must check keychain first and prompt if needed)
        #
        # @param data_dir [String] Directory containing account data
        # @param new_mode [Symbol] Target encryption mode (:plaintext, :standard, :enhanced)
        # @param new_master_password [String, nil] New master password (required if entering Enhanced)
        # @return [Boolean] true if successful, false on failure (errors logged to Lich.log)
        def self.change_encryption_mode(data_dir, new_mode, new_master_password = nil)
          yaml_file = yaml_file_path(data_dir)

          # Load YAML
          begin
            yaml_data = YAML.load_file(yaml_file)
          rescue StandardError => e
            Lich.log "error: Failed to load YAML for encryption mode change: #{e.message}"
            return false
          end

          current_mode = yaml_data['encryption_mode']&.to_sym || :plaintext

          # If already in target mode, return success
          if current_mode == new_mode
            Lich.log "info: Already in #{new_mode} encryption mode"
            return true
          end

          # Determine old_master_password
          old_master_password = nil
          if current_mode == :enhanced
            # Auto-retrieve from keychain when leaving Enhanced
            old_master_password = MasterPasswordManager.retrieve_master_password
            if old_master_password.nil?
              Lich.log "error: Master password not found in keychain for encryption mode change"
              return false
            end
          end

          # Validate new_master_password if entering Enhanced mode
          if new_mode == :enhanced && new_master_password.nil?
            Lich.log "error: New master password required for Enhanced mode encryption"
            return false
          end

          # Create backup
          backup_file = "#{yaml_file}.bak"
          begin
            FileUtils.cp(yaml_file, backup_file)
            Lich.log "info: Backup created for encryption mode change: #{backup_file}"
          rescue StandardError => e
            Lich.log "error: Failed to create backup: #{e.message}"
            return false
          end

          begin
            # Re-encrypt all accounts
            accounts = yaml_data['accounts'] || {}
            accounts.each do |account_name, account_data|
              # Decrypt with current mode
              plaintext = decrypt_password(
                account_data['password'],
                mode: current_mode,
                account_name: account_name,
                master_password: old_master_password
              )

              if plaintext.nil?
                Lich.log "error: Failed to decrypt password for #{account_name}"
                return restore_backup_and_return_false(backup_file, yaml_file)
              end

              # Encrypt with new mode
              encrypted = encrypt_password(
                plaintext,
                mode: new_mode,
                account_name: account_name,
                master_password: new_master_password
              )

              if encrypted.nil?
                Lich.log "error: Failed to encrypt password for #{account_name}"
                return restore_backup_and_return_false(backup_file, yaml_file)
              end

              account_data['password'] = encrypted
            end

            # Update encryption_mode
            yaml_data['encryption_mode'] = new_mode.to_s

            # Handle Enhanced mode metadata
            if new_mode == :enhanced
              # Create validation test
              validation_test = MasterPasswordManager.create_validation_test(new_master_password)
              yaml_data['master_password_validation_test'] = validation_test

              # Store in keychain
              unless MasterPasswordManager.store_master_password(new_master_password)
                Lich.log "error: Failed to store master password in keychain"
                return restore_backup_and_return_false(backup_file, yaml_file)
              end
            elsif current_mode == :enhanced
              # Remove validation test and keychain when leaving Enhanced
              yaml_data.delete('master_password_validation_test')
              MasterPasswordManager.delete_master_password
            end

            # Save YAML with headers
            write_yaml_file(yaml_file, yaml_data)

            # Clean up backup on success
            FileUtils.rm(backup_file) if File.exist?(backup_file)

            Lich.log "info: Encryption mode changed successfully: #{current_mode} → #{new_mode}"
            true
          rescue StandardError => e
            Lich.log "error: Encryption mode change failed: #{e.class}: #{e.message}"
            restore_backup_and_return_false(backup_file, yaml_file)
          end
        end

        # Restores backup and returns false
        # @private
        def self.restore_backup_and_return_false(backup_file, yaml_file)
          if File.exist?(backup_file)
            FileUtils.cp(backup_file, yaml_file)
            FileUtils.rm(backup_file)
            Lich.log "info: Backup restored after encryption mode change failure"
          end
          false
        end

        # Migrates YAML data to support encryption format
        # Adds encryption_mode field if not present
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [Hash] YAML data structure with encryption support
        def self.migrate_to_encryption_format(yaml_data)
          return yaml_data unless yaml_data.is_a?(Hash)

          # Add encryption_mode if not present (defaults to plaintext for backward compatibility)
          yaml_data['encryption_mode'] ||= 'plaintext'
          # Add validation test field if master_password mode (for Phase 2)
          yaml_data['master_password_validation_test'] ||= nil

          yaml_data
        end

        # Adds a character to the favorites list
        # Marks the specified character as a favorite with proper ordering
        # Optimized to preserve account ordering in YAML structure
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Boolean] True if operation was successful
        def self.add_favorite(data_dir, username, char_name, game_code, frontend = nil)
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            # Find the character with frontend precision
            character = find_character(yaml_data, username, char_name, game_code, frontend)
            return false unless character

            # Don't add if already a favorite
            return true if character['is_favorite']

            # Mark as favorite and assign order
            character['is_favorite'] = true
            character['favorite_order'] = get_next_favorite_order(yaml_data)
            character['favorite_added'] = Time.now.to_s

            # Save updated data directly without conversion round-trip
            # This preserves the original YAML structure and account ordering
            content = generate_yaml_content(yaml_data)
            result = Utilities.safe_file_operation(yaml_file, :write, content)

            result ? true : false
          rescue StandardError => e
            Lich.log "error: Error adding favorite: #{e.message}"
            false
          end
        end

        # Removes a character from the favorites list
        # Unmarks the specified character as a favorite and reorders remaining favorites
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Boolean] True if operation was successful
        def self.remove_favorite(data_dir, username, char_name, game_code, frontend = nil)
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            # Find the character with frontend precision
            character = find_character(yaml_data, username, char_name, game_code, frontend)
            return false unless character

            # Don't remove if not a favorite
            return true unless character['is_favorite']

            # Remove favorite status
            character['is_favorite'] = false
            character.delete('favorite_order')
            character.delete('favorite_added')

            # Reorder remaining favorites
            reorder_all_favorites(yaml_data)

            # Save updated data
            content = generate_yaml_content(yaml_data)
            result = Utilities.safe_file_operation(yaml_file, :write, content)

            result ? true : false
          rescue StandardError => e
            Lich.log "error: Error removing favorite: #{e.message}"
            false
          end
        end

        # Checks if a character is marked as a favorite
        # Returns true if the specified character is in the favorites list
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Boolean] True if character is a favorite
        def self.is_favorite?(data_dir, username, char_name, game_code, frontend = nil)
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            character = find_character(yaml_data, username, char_name, game_code, frontend)
            character && character['is_favorite'] == true
          rescue StandardError => e
            Lich.log "error: Error checking favorite status: #{e.message}"
            false
          end
        end

        # Gets all favorite characters across all accounts
        # Returns an array of favorite characters sorted by favorite order
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Array] Array of favorite character data in legacy format
        def self.get_favorites(data_dir)
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
          return [] unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            favorites = []

            yaml_data['accounts'].each do |username, account_data|
              next unless account_data['characters']

              account_data['characters'].each do |character|
                if character['is_favorite']
                  favorites << {
                    user_id: username,
                    char_name: character['char_name'],
                    game_code: character['game_code'],
                    game_name: character['game_name'],
                    frontend: character['frontend'],
                    favorite_order: character['favorite_order'] || 999,
                    favorite_added: character['favorite_added']
                  }
                end
              end
            end

            # Sort by favorite order
            favorites.sort_by { |fav| fav[:favorite_order] }
          rescue StandardError => e
            Lich.log "error: Error getting favorites: #{e.message}"
            []
          end
        end

        # Reorders favorites based on provided character list
        # Updates the favorite order for all favorites based on new ordering
        #
        # @param data_dir [String] Directory containing entry data
        # @param ordered_favorites [Array] Array of hashes with username, char_name, game_code, frontend
        # @return [Boolean] True if operation was successful
        def self.reorder_favorites(data_dir, ordered_favorites)
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            # Update favorite order for each character in the provided order
            ordered_favorites.each_with_index do |favorite_info, index|
              character = find_character(
                yaml_data,
                favorite_info[:username] || favorite_info['username'],
                favorite_info[:char_name] || favorite_info['char_name'],
                favorite_info[:game_code] || favorite_info['game_code'],
                favorite_info[:frontend] || favorite_info['frontend']
              )

              if character && character['is_favorite']
                character['favorite_order'] = index + 1
              end
            end

            # Save updated data
            content = generate_yaml_content(yaml_data)
            result = Utilities.safe_file_operation(yaml_file, :write, content)

            result ? true : false
          rescue StandardError => e
            Lich.log "error: Error reordering favorites: #{e.message}"
            false
          end
        end

        # Converts YAML data structure to legacy format
        # Transforms the YAML structure into the format expected by existing code
        # Maintains normalized case formatting from YAML storage
        # Handles encrypted passwords transparently
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [Array] Array of entry data in legacy format with decrypted passwords
        def self.convert_yaml_to_legacy_format(yaml_data)
          entries = []

          return entries unless yaml_data['accounts']

          encryption_mode = (yaml_data['encryption_mode'] || 'plaintext').to_sym

          yaml_data['accounts'].each do |username, account_data|
            next unless account_data['characters']

            # Decrypt password if needed (with recovery for missing master password)
            password = if encryption_mode == :plaintext
                         account_data['password']
                       else
                         decrypt_password_with_recovery(
                           account_data['password'],
                           mode: encryption_mode,
                           account_name: username,
                           validation_test: yaml_data['master_password_validation_test']
                         )
                       end

            account_data['characters'].each do |character|
              entry = {
                user_id: username, # Already normalized to UPCASE in YAML
                password: password, # Decrypted password
                char_name: character['char_name'], # Already normalized to Title case in YAML
                game_code: character['game_code'],
                game_name: character['game_name'],
                frontend: character['frontend'],
                custom_launch: character['custom_launch'],
                custom_launch_dir: character['custom_launch_dir'],
                is_favorite: character['is_favorite'] || false,
                favorite_order: character['favorite_order'],
                encryption_mode: encryption_mode
              }

              entries << entry
            end
          end

          entries
        end

        # Converts legacy format to YAML data structure
        # Transforms legacy entry data into the YAML structure for storage
        # Enhanced with case normalization to prevent duplicate accounts and ensure consistent formatting
        # Preserves encryption_mode from entries and master_password_validation_test if provided
        #
        # @param entry_data [Array] Array of entry data in legacy format
        # @param validation_test [Hash, nil] Master password validation test to preserve (optional)
        # @return [Hash] YAML data structure
        def self.convert_legacy_to_yaml_format(entry_data, validation_test = nil)
          yaml_data = { 'accounts' => {} }

          # Preserve encryption_mode if present in entries
          encryption_mode = entry_data.first&.[](:encryption_mode) || :plaintext
          yaml_data['encryption_mode'] = encryption_mode.to_s

          # Preserve master_password_validation_test if provided
          yaml_data['master_password_validation_test'] = validation_test

          entry_data.each do |entry|
            # Normalize account name to UPCASE for consistent storage
            normalized_username = normalize_account_name(entry[:user_id])

            # Initialize account if not exists, with password at account level
            yaml_data['accounts'][normalized_username] ||= {
              'password'   => entry[:password],
              'characters' => []
            }

            character_data = {
              'char_name'         => normalize_character_name(entry[:char_name]),
              'game_code'         => entry[:game_code],
              'game_name'         => entry[:game_name],
              'frontend'          => entry[:frontend],
              'custom_launch'     => entry[:custom_launch],
              'custom_launch_dir' => entry[:custom_launch_dir],
              'is_favorite'       => entry[:is_favorite] || false
            }

            # Add favorite metadata if character is a favorite
            if entry[:is_favorite]
              character_data['favorite_order'] = entry[:favorite_order]
              character_data['favorite_added'] = entry[:favorite_added] || Time.now.to_s
            end

            # Check for duplicate character using precision matching (account/character/game_code/frontend)
            existing_character = yaml_data['accounts'][normalized_username]['characters'].find do |char|
              char['char_name'] == character_data['char_name'] &&
                char['game_code'] == character_data['game_code'] &&
                char['frontend'] == character_data['frontend']
            end

            # Only add if no exact match exists
            unless existing_character
              yaml_data['accounts'][normalized_username]['characters'] << character_data
            end
          end

          yaml_data
        end

        # Sorts entries with favorites priority based on autosort setting
        # When autosort is enabled, favorites are placed first and all entries are sorted
        # When autosort is disabled, original order is preserved without reordering
        #
        # @param entries [Array] Array of entry data
        # @param autosort_state [Boolean] Whether to use auto-sorting
        # @return [Array] Sorted array of entries (if autosort enabled) or original order (if disabled)
        def self.sort_entries_with_favorites(entries, autosort_state)
          # If autosort is disabled, preserve original order without any reordering
          return entries unless autosort_state

          # Autosort enabled: apply favorites-first sorting
          # Separate favorites and non-favorites
          favorites = entries.select { |entry| entry[:is_favorite] }
          non_favorites = entries.reject { |entry| entry[:is_favorite] }

          # Sort favorites by favorite_order
          favorites.sort_by! { |entry| entry[:favorite_order] || 999 }

          # Sort non-favorites by account name (upcase), game name, and character name
          sorted_non_favorites = non_favorites.sort do |a, b|
            [a[:user_id].upcase, a[:game_name], a[:char_name]] <=> [b[:user_id].upcase, b[:game_name], b[:char_name]]
          end

          # Return favorites first, then non-favorites
          favorites + sorted_non_favorites
        end

        # Migrates YAML data to support favorites format
        # Adds favorites fields to existing character records if not present
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [Hash] YAML data structure with favorites support
        def self.migrate_to_favorites_format(yaml_data)
          return yaml_data unless yaml_data.is_a?(Hash) && yaml_data['accounts']

          yaml_data['accounts'].each do |_username, account_data|
            next unless account_data['characters'].is_a?(Array)

            account_data['characters'].each do |character|
              # Add favorites fields if not present
              character['is_favorite'] ||= false
              # Don't add favorite_order or favorite_added unless character is actually a favorite
            end
          end

          yaml_data
        end

        # Finds a character in the YAML data with precise matching
        # Prioritizes exact frontend matches for newly added characters
        #
        # @param yaml_data [Hash] YAML data structure
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String, nil] Frontend identifier
        # @return [Hash, nil] Character hash or nil if not found
        def self.find_character(yaml_data, username, char_name, game_code, frontend = nil)
          return nil unless yaml_data['accounts'] && yaml_data['accounts'][username]
          account_data = yaml_data['accounts'][username]
          return nil unless account_data['characters']

          # If frontend is specified, find exact match first
          if frontend
            exact_match = account_data['characters'].find do |character|
              character['char_name'] == char_name &&
                character['game_code'] == game_code &&
                character['frontend'] == frontend
            end
            return exact_match if exact_match
          end

          # Fallback to basic matching only if no exact match found and frontend is nil
          if frontend.nil?
            account_data['characters'].find do |character|
              character['char_name'] == char_name && character['game_code'] == game_code
            end
          else
            # If frontend was specified but no exact match found, return nil
            nil
          end
        end

        # Gets the next available favorite order number
        # Finds the highest current favorite order and returns the next number
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [Integer] Next available favorite order number
        def self.get_next_favorite_order(yaml_data)
          max_order = 0

          yaml_data['accounts'].each do |_username, account_data|
            next unless account_data['characters']

            account_data['characters'].each do |character|
              if character['is_favorite'] && character['favorite_order']
                max_order = [max_order, character['favorite_order']].max
              end
            end
          end

          max_order + 1
        end

        # Finds an entry in legacy format array using the same matching logic as find_character
        # Searches for an entry based on key identifying fields rather than exact hash equality
        # This method reuses the proven matching logic from find_character for consistency
        #
        # @param entry_data [Array] Array of entry data in legacy format
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Hash, nil] Entry hash if found, nil otherwise
        def self.find_entry_in_legacy_format(entry_data, username, char_name, game_code, frontend = nil)
          entry_data.find do |entry|
            # Match on username first
            next unless entry[:user_id] == username

            # Apply same matching logic as find_character
            matches_basic = entry[:char_name] == char_name && entry[:game_code] == game_code

            if frontend.nil?
              # Backward compatibility: if no frontend specified, match any frontend
              matches_basic
            else
              # Frontend precision: must match exact frontend
              matches_basic && entry[:frontend] == frontend
            end
          end
        end

        # Reorders all favorites to have consecutive order numbers
        # Ensures favorite_order values are consecutive starting from 1
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [void]
        def self.reorder_all_favorites(yaml_data)
          # Collect all favorites
          all_favorites = []

          yaml_data['accounts'].each do |_username, account_data|
            next unless account_data['characters']

            account_data['characters'].each do |character|
              if character['is_favorite']
                all_favorites << character
              end
            end
          end

          # Sort by current order and reassign consecutive numbers
          all_favorites.sort_by! { |char| char['favorite_order'] || 999 }
          all_favorites.each_with_index do |character, index|
            character['favorite_order'] = index + 1
          end
        end

        # Prepares YAML data for serialization with password preservation
        # Ensures encrypted passwords are serialized as quoted strings to prevent YAML multiline formatting
        # Clones the data to avoid mutating the caller's object
        # Ensures required top-level fields exist (encryption_mode, master_password_validation_test)
        #
        # @param yaml_data [Hash] YAML data structure to prepare for serialization
        # @return [Hash] Cloned yaml_data with passwords forced to plain strings and required fields set
        def self.prepare_yaml_for_serialization(yaml_data)
          # Clone to avoid mutating caller's object
          prepared_data = Marshal.load(Marshal.dump(yaml_data))

          # Ensure top-level fields are explicitly present (defensive programming)
          prepared_data['encryption_mode'] ||= 'plaintext'
          prepared_data['master_password_validation_test'] ||= nil

          # Preserve encrypted passwords by ensuring they are serialized as quoted strings
          # This prevents YAML from using multiline formatting (|, >) which breaks Base64 decoding
          if prepared_data['accounts']
            prepared_data['accounts'].each do |_username, account_data|
              if account_data.is_a?(Hash) && account_data['password']
                # Force password to be treated as a plain scalar string
                account_data['password'] = account_data['password'].to_s
              end
            end
          end

          prepared_data
        end

        # Normalizes account names to UPCASE for consistent storage and comparison
        # Prevents duplicate accounts due to case variations
        #
        # @param name [String] Raw account name
        # @return [String] Normalized account name in UPCASE
        def self.normalize_account_name(name)
          return '' if name.nil?
          name.to_s.strip.upcase
        end

        # Normalizes character names to Title case (first letter capitalized)
        # Ensures consistent character name formatting across the application
        #
        # @param name [String] Raw character name
        # @return [String] Normalized character name in Title case
        def self.normalize_character_name(name)
          return '' if name.nil?
          name.to_s.strip.capitalize
        end

        # Generates YAML file content with standard header and dumped data
        # Reduces code duplication by providing a common method for formatting YAML output
        #
        # @param yaml_data [Hash] YAML data structure to dump
        # @return [String] Complete YAML file content with header
        def self.generate_yaml_content(yaml_data)
          # Prepare YAML with password preservation (clones to avoid mutation)
          prepared_yaml = prepare_yaml_for_serialization(yaml_data)

          content = "# Lich 5 Login Entries - YAML Format\n" \
                  + "# Generated: #{Time.now}\n" \
                  + YAML.dump(prepared_yaml, permitted_classes: [Symbol])
          return content
        end

        # Writes YAML data to file with standard headers and secure permissions
        # Handles preparation and formatting of YAML data for all save operations
        #
        # @param yaml_file [String] Path to YAML file to write
        # @param yaml_data [Hash] YAML data structure to save
        # @return [void]
        def self.write_yaml_file(yaml_file, yaml_data)
          prepared_yaml = prepare_yaml_for_serialization(yaml_data)

          File.open(yaml_file, 'w', 0o600) do |file|
            file.puts "# Lich 5 Login Entries - YAML Format"
            file.puts "# Generated: #{Time.now}"
            file.write(YAML.dump(prepared_yaml, permitted_classes: [Symbol]))
          end
        end

        # Ensures master password exists for master_password mode conversions
        # Shows UI prompt to user if not found in Keychain
        # Creates validation test and stores in Keychain
        #
        # @return [Hash, String, nil] Hash with {password, validation_test} if new, password string if existing, nil if cancelled
        def self.ensure_master_password_exists
          # Check if master password already in Keychain
          existing = MasterPasswordManager.retrieve_master_password
          return existing if !existing.nil? && !existing.empty?

          # Show UI prompt to CREATE master password
          master_password = MasterPasswordPrompt.show_create_master_password_dialog

          if master_password.nil?
            Lich.log "info: User declined to create master password"
            return nil
          end

          # Create validation test (expensive 100k iterations, one-time)
          validation_test = MasterPasswordManager.create_validation_test(master_password)

          if validation_test.nil?
            Lich.log "error: Failed to create validation test"
            return nil
          end

          # Store in Keychain
          stored = MasterPasswordManager.store_master_password(master_password)

          unless stored
            Lich.log "error: Failed to store master password in Keychain"
            return nil
          end

          Lich.log "info: Master password created and stored in Keychain"
          # Return both password and validation test for YAML storage
          { password: master_password, validation_test: validation_test }
        end

        # Gets existing master password and creates validation test for migration scenarios
        # Used when converting DAT to YAML and a master password already exists in keychain
        # This handles the case: no YAML, DAT exists, master password in keychain
        #
        # @return [Hash, nil] Hash with {password, validation_test} or nil if error
        def self.get_existing_master_password_for_migration
          # Retrieve existing master password from keychain
          existing_password = MasterPasswordManager.retrieve_master_password

          if existing_password.nil? || existing_password.empty?
            Lich.log "info: No existing master password found in keychain - user should create one"
            return nil
          end

          Lich.log "info: Found existing master password in keychain - creating validation test for migration"

          # Create a NEW validation test with the existing password
          # This is needed because we don't have the old validation test in YAML yet
          validation_test = MasterPasswordManager.create_validation_test(existing_password)

          if validation_test.nil?
            Lich.log "error: Failed to create validation test for existing master password"
            return nil
          end

          Lich.log "info: Validation test created for existing master password"
          { password: existing_password, validation_test: validation_test }
        end
      end
    end
  end
end
