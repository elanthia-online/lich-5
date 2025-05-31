# frozen_string_literal: true

require 'yaml'

module Lich
  module Common
    module GUI
      # Handles YAML-based state management for the Lich GUI login system
      # Provides a more maintainable alternative to the Marshal-based state system
      module YamlState
        # Loads saved entry data from YAML file
        # Reads and deserializes entry data from the entry.yml file, with fallback to entry.dat
        #
        # @param data_dir [String] Directory containing entry data
        # @param autosort_state [Boolean] Whether to use auto-sorting
        # @return [Array] Array of saved login entries in the legacy format
        def self.load_saved_entries(data_dir, autosort_state)
          # Guard against nil data_dir
          return [] if data_dir.nil?

          yaml_file = File.join(data_dir, "entry.yml")
          dat_file = File.join(data_dir, "entry.dat")

          if File.exist?(yaml_file)
            # Load from YAML format
            begin
              yaml_data = YAML.load_file(yaml_file)
              entries = convert_yaml_to_legacy_format(yaml_data)

              # Apply sorting if needed
              sort_entries(entries, autosort_state)
            rescue => e
              Lich.log "Error loading YAML entry file: #{e.message}"
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
        # Converts and serializes entry data to the entry.yml file
        #
        # @param data_dir [String] Directory to save entry data
        # @param entry_data [Array] Array of entry data in legacy format
        # @return [Boolean] True if save was successful
        def self.save_entries(data_dir, entry_data)
          yaml_file = File.join(data_dir, "entry.yml")

          # Convert legacy format to YAML structure
          yaml_data = convert_legacy_to_yaml_format(entry_data)

          # Create backup of existing file if it exists
          if File.exist?(yaml_file)
            backup_file = "#{yaml_file}.bak"
            FileUtils.cp(yaml_file, backup_file)
          end

          # Write YAML data to file
          File.open(yaml_file, 'w') do |file|
            file.puts "# Lich 5 Login Entries - YAML Format"
            file.puts "# Generated: #{Time.now}"
            file.puts "# WARNING: Passwords are stored in plain text"
            file.write(YAML.dump(yaml_data))
          end

          true
        rescue => e
          Lich.log "Error saving YAML entry file: #{e.message}"
          false
        end

        # Migrates from legacy Marshal format to YAML format
        # Converts entry.dat to entry.yml format for improved maintainability
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Boolean] True if migration was successful
        def self.migrate_from_legacy(data_dir)
          dat_file = File.join(data_dir, "entry.dat")
          yaml_file = File.join(data_dir, "entry.yml")

          # Skip if YAML file already exists or DAT file doesn't exist
          return false unless File.exist?(dat_file)
          return false if File.exist?(yaml_file)

          # Load legacy data
          legacy_entries = State.load_saved_entries(data_dir, false)

          # Save as YAML
          save_entries(data_dir, legacy_entries)
        rescue => e
          Lich.log "Error migrating to YAML format: #{e.message}"
          false
        end

        # Validates the YAML data structure
        # Ensures the YAML data conforms to the expected structure
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [Boolean] True if structure is valid
        def self.validate_yaml_structure(yaml_data)
          return false unless yaml_data.is_a?(Hash)
          return false unless yaml_data.key?('accounts')
          return false unless yaml_data['accounts'].is_a?(Hash)

          yaml_data['accounts'].each do |_username, account_data|
            return false unless account_data.is_a?(Hash)
            return false unless account_data.key?('password')
            return false unless account_data.key?('characters')
            return false unless account_data['characters'].is_a?(Array)

            account_data['characters'].each do |character|
              return false unless character.is_a?(Hash)
              return false unless character.key?('char_name')
              return false unless character.key?('game_code')
              return false unless character.key?('game_name')
              return false unless character.key?('frontend')
            end
          end

          true
        end

        class << self
          private

          # Converts YAML format to legacy array of hashes format
          # Transforms the hierarchical YAML structure to the flat legacy format
          #
          # @param yaml_data [Hash] YAML data structure
          # @return [Array] Array of entry data in legacy format
          def convert_yaml_to_legacy_format(yaml_data)
            return [] unless validate_yaml_structure(yaml_data)

            legacy_entries = []

            yaml_data['accounts'].each do |username, account_data|
              password = account_data['password']

              account_data['characters'].each do |character|
                legacy_entries << {
                  char_name: character['char_name'],
                  game_code: character['game_code'],
                  game_name: character['game_name'],
                  user_id: username,
                  password: password,
                  frontend: character['frontend'],
                  custom_launch: character['custom_launch'],
                  custom_launch_dir: character['custom_launch_dir']
                }
              end
            end

            legacy_entries
          end

          # Converts legacy array of hashes format to YAML structure
          # Transforms the flat legacy format to a hierarchical YAML structure
          #
          # @param legacy_entries [Array] Array of entry data in legacy format
          # @return [Hash] YAML data structure
          def convert_legacy_to_yaml_format(legacy_entries)
            yaml_data = { 'accounts' => {} }

            legacy_entries.each do |entry|
              username = entry[:user_id]

              # Initialize account if it doesn't exist
              unless yaml_data['accounts'].key?(username)
                yaml_data['accounts'][username] = {
                  'password'   => entry[:password],
                  'characters' => []
                }
              end

              # Add character to account
              yaml_data['accounts'][username]['characters'] << {
                'char_name'         => entry[:char_name],
                'game_code'         => entry[:game_code],
                'game_name'         => entry[:game_name],
                'frontend'          => entry[:frontend],
                'custom_launch'     => entry[:custom_launch],
                'custom_launch_dir' => entry[:custom_launch_dir]
              }
            end

            yaml_data
          end

          # Sorts entries based on autosort setting
          # Provides consistent sorting of entry data based on user preference
          #
          # @param entries [Array] Array of entry data
          # @param autosort_state [Boolean] Whether to use auto-sorting
          # @return [Array] Sorted array of entry data
          def sort_entries(entries, autosort_state)
            if autosort_state
              # Sort by game name, account name, and character name
              entries.sort do |a, b|
                [a[:user_id], a[:game_name], a[:char_name]] <=> [b[:user_id], b[:game_name], b[:char_name]]
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
end
