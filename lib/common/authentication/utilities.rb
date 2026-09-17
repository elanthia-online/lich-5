# frozen_string_literal: true

require 'fileutils'

module Lich
  module Common
    module Authentication
      # Widget-free helpers shared by every launcher front end: realm name
      # conversion, guarded file operations for the saved-login store, and
      # entry sorting. The GTK launcher's Lich::Common::GUI::Utilities
      # delegates here for the same names.
      module Utilities
        # Converts a game code to a realm name
        # Translates internal game codes to user-friendly realm names
        #
        # @param game_code [String] Game code (e.g., "GS3", "GSX")
        # @return [String] Realm name
        def self.game_code_to_realm(game_code)
          case game_code
          when "GS3"
            "GS Prime"
          when "GSF"
            "GS Shattered"
          when "GSX"
            "GS Platinum"
          when "GST"
            "GS Test"
          when "DR"
            "DR Prime"
          when "DRF"
            "DR Fallen"
          when "DRT"
            "DR Test"
          else
            game_code
          end
        end

        # Converts a realm name to a game code
        # Translates user-friendly realm names to internal game codes
        #
        # @param realm [String] Realm name
        # @return [String] Game code
        def self.realm_to_game_code(realm)
          case realm.downcase
          when "gemstone iv", "prime"
            "GS3"
          when "gemstone iv shattered", "shattered"
            "GSF"
          when "gemstone iv platinum", "platinum"
            "GSX"
          when "gemstone iv prime test", "test"
            "GST"
          when "dragonrealms", "dr prime"
            "DR"
          when "dragonrealms the fallen", "dr fallen"
            "DRF"
          when "dragonrealms prime test", "dr test"
            "DRT"
          else
            "GS3" # Default to GS3 if unknown
          end
        end

        # Handles file operations with error handling and backups
        # Provides a safe way to read, write, and backup files
        #
        # @param file_path [String] Path to the file
        # @param operation [Symbol] Operation to perform (:read, :write, :backup)
        # @param content [String] Content to write (for :write operation)
        # @return [String, Boolean] File content for :read, success status for others
        def self.safe_file_operation(file_path, operation, content = nil)
          case operation
          when :read
            File.read(file_path)
          when :write
            # Create backup if file exists
            safe_file_operation(file_path, :backup) if File.exist?(file_path)

            # Write content to file with secure permissions
            File.open(file_path, 'w', 0600) do |file|
              file.write(content)
            end
            true
          when :backup
            return false unless File.exist?(file_path)

            backup_file = "#{file_path}.bak"
            FileUtils.cp(file_path, backup_file)
            true
          end
        rescue StandardError => e
          Lich.log "error: Error in file operation (#{operation}): #{e.message}"
          operation == :read ? "" : false
        end

        # Handles file operations with verification to ensure data persistence
        # Provides verified file operations that confirm successful completion before returning
        # Uses flush and fsync to ensure data is written to disk before verification
        #
        # @param file_path [String] Path to the file
        # @param operation [Symbol] Operation to perform (:read, :write, :backup)
        # @param content [String] Content to write (for :write operation)
        # @return [String, Boolean] File content for :read, success status for others
        def self.verified_file_operation(file_path, operation, content = nil)
          case operation
          when :read
            File.read(file_path)
          when :write
            # Create backup if file exists
            safe_file_operation(file_path, :backup) if File.exist?(file_path)

            # Write content with forced synchronization and secure permissions
            File.open(file_path, 'w', 0600) do |file|
              file.write(content)
              file.flush    # Force write to OS buffer
              file.fsync    # Force OS to write to disk
            end

            # Verify write completed by reading back and comparing
            written_content = File.read(file_path)
            return written_content == content
          when :backup
            return false unless File.exist?(file_path)

            backup_file = "#{file_path}.bak"
            FileUtils.cp(file_path, backup_file)

            # Verify backup was created successfully
            File.exist?(backup_file) && File.size(backup_file) == File.size(file_path)
          end
        rescue StandardError => e
          Lich.log "error: Error in verified file operation (#{operation}): #{e.message}"
          operation == :read ? "" : false
        end

        # Sorts entries based on autosort setting
        # Provides consistent sorting of entry data based on user preference
        #
        # @param entries [Array] Array of entry data
        # @param autosort_state [Boolean] Whether to use auto-sorting
        # @return [Array] Sorted array of entry data
        def self.sort_entries(entries, autosort_state)
          if autosort_state
            # Sort by game name, account name, and character name
            entries.sort do |a, b|
              [a[:game_name], a[:user_id], a[:char_name]] <=> [b[:game_name], b[:user_id], b[:char_name]]
            end
          else
            # Sort by account name and character name (old Lich 4 style)
            entries.sort do |a, b|
              [a[:user_id].downcase, a[:char_name]] <=> [b[:user_id].downcase, b[:char_name]]
            end
          end
        end
      end
    end
  end
end
