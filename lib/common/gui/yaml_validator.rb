# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Validates the YAML persistence and data integrity for the Lich GUI login system
      # Provides testing and validation functions for the YAML-based entry file
      module YamlValidator
        # Validates the YAML file structure and integrity
        # Checks if the YAML file exists and has the correct structure
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Hash] Validation results with status and messages
        def self.validate_yaml_file(data_dir)
          yaml_file = File.join(data_dir, "entry.yml")

          results = {
            status: true,
            messages: []
          }

          # Check if file exists
          unless File.exist?(yaml_file)
            results[:status] = false
            results[:messages] << "YAML file does not exist: #{yaml_file}"
            return results
          end

          begin
            # Load YAML data
            yaml_data = YAML.load_file(yaml_file)

            # Validate structure
            unless yaml_data.is_a?(Hash)
              results[:status] = false
              results[:messages] << "Invalid YAML structure: Root element is not a Hash"
              return results
            end

            unless yaml_data.key?('accounts')
              results[:status] = false
              results[:messages] << "Invalid YAML structure: Missing 'accounts' key"
              return results
            end

            unless yaml_data['accounts'].is_a?(Hash)
              results[:status] = false
              results[:messages] << "Invalid YAML structure: 'accounts' is not a Hash"
              return results
            end

            # Validate accounts
            yaml_data['accounts'].each do |username, account_data|
              unless account_data.is_a?(Hash)
                results[:status] = false
                results[:messages] << "Invalid account structure for '#{username}': Not a Hash"
                next
              end

              unless account_data.key?('password')
                results[:status] = false
                results[:messages] << "Invalid account structure for '#{username}': Missing 'password'"
              end

              unless account_data.key?('characters')
                results[:status] = false
                results[:messages] << "Invalid account structure for '#{username}': Missing 'characters'"
                next
              end

              unless account_data['characters'].is_a?(Array)
                results[:status] = false
                results[:messages] << "Invalid account structure for '#{username}': 'characters' is not an Array"
                next
              end

              # Validate characters
              account_data['characters'].each_with_index do |character, index|
                unless character.is_a?(Hash)
                  results[:status] = false
                  results[:messages] << "Invalid character structure for '#{username}' at index #{index}: Not a Hash"
                  next
                end

                # Check required fields
                required_fields = ['char_name', 'game_code', 'game_name', 'frontend']
                required_fields.each do |field|
                  unless character.key?(field)
                    results[:status] = false
                    results[:messages] << "Invalid character structure for '#{username}' at index #{index}: Missing '#{field}'"
                  end
                end
              end
            end

            # Add success message if no errors
            if results[:status]
              results[:messages] << "YAML file structure is valid"
            end
          rescue => e
            results[:status] = false
            results[:messages] << "Error validating YAML file: #{e.message}"
          end

          results
        end

        # Tests round-trip conversion between YAML and legacy formats
        # Verifies that data can be converted between formats without loss
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Hash] Test results with status and messages
        def self.test_format_conversion(data_dir)
          results = {
            status: true,
            messages: []
          }

          begin
            # Get legacy format entries
            legacy_entries = AccountManager.to_legacy_format(data_dir)

            if legacy_entries.empty?
              results[:messages] << "No entries found for conversion test"
              return results
            end

            # Convert to YAML format
            yaml_data = YamlState.convert_legacy_to_yaml_format(legacy_entries)

            # Convert back to legacy format
            converted_entries = YamlState.convert_yaml_to_legacy_format(yaml_data)

            # Compare original and converted entries
            if legacy_entries.length != converted_entries.length
              results[:status] = false
              results[:messages] << "Conversion test failed: Entry count mismatch (#{legacy_entries.length} vs #{converted_entries.length})"
            end

            # Check each entry for data integrity
            legacy_entries.each do |original|
              # Find matching entry in converted data
              match = converted_entries.find do |converted|
                converted[:char_name] == original[:char_name] &&
                  converted[:game_code] == original[:game_code] &&
                  converted[:user_id] == original[:user_id]
              end

              if match.nil?
                results[:status] = false
                results[:messages] << "Conversion test failed: Entry not found after conversion: #{original[:char_name]} (#{original[:game_code]}) for #{original[:user_id]}"
                next
              end

              # Compare all fields
              original.each do |key, value|
                if match[key] != value
                  results[:status] = false
                  results[:messages] << "Conversion test failed: Value mismatch for #{key} in #{original[:char_name]} (#{original[:game_code]}) for #{original[:user_id]}"
                end
              end
            end

            # Add success message if no errors
            if results[:status]
              results[:messages] << "Format conversion test passed: All entries converted correctly"
            end
          rescue => e
            results[:status] = false
            results[:messages] << "Error testing format conversion: #{e.message}"
          end

          results
        end

        # Tests account management operations
        # Verifies that account CRUD operations work correctly
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Hash] Test results with status and messages
        def self.test_account_management(data_dir)
          results = {
            status: true,
            messages: []
          }

          begin
            # Create test account
            test_username = "test_account_#{Time.now.to_i}"
            test_password = "test_password"

            # Test adding account
            add_result = AccountManager.add_or_update_account(data_dir, test_username, test_password)
            unless add_result
              results[:status] = false
              results[:messages] << "Failed to add test account"
              return results
            end

            results[:messages] << "Successfully added test account"

            # Test changing password
            new_password = "new_password"
            change_result = AccountManager.change_password(data_dir, test_username, new_password)
            unless change_result
              results[:status] = false
              results[:messages] << "Failed to change test account password"
              return results
            end

            results[:messages] << "Successfully changed test account password"

            # Test adding character
            test_character = {
              char_name: "TestCharacter",
              game_code: "GS3",
              game_name: "GemStone IV",
              frontend: "stormfront",
              custom_launch: nil,
              custom_launch_dir: nil
            }

            add_char_result = AccountManager.add_character(data_dir, test_username, test_character)
            unless add_char_result
              results[:status] = false
              results[:messages] << "Failed to add test character"
              return results
            end

            results[:messages] << "Successfully added test character"

            # Test getting characters
            characters = AccountManager.get_characters(data_dir, test_username)
            if characters.empty?
              results[:status] = false
              results[:messages] << "Failed to get characters for test account"
              return results
            end

            results[:messages] << "Successfully retrieved characters for test account"

            # Test removing character
            remove_char_result = AccountManager.remove_character(
              data_dir,
              test_username,
              test_character[:char_name],
              test_character[:game_code]
            )

            unless remove_char_result
              results[:status] = false
              results[:messages] << "Failed to remove test character"
              return results
            end

            results[:messages] << "Successfully removed test character"

            # Test removing account
            remove_result = AccountManager.remove_account(data_dir, test_username)
            unless remove_result
              results[:status] = false
              results[:messages] << "Failed to remove test account"
              return results
            end

            results[:messages] << "Successfully removed test account"

            # Add success message if all tests passed
            if results[:status]
              results[:messages] << "Account management tests passed: All operations completed successfully"
            end
          rescue => e
            results[:status] = false
            results[:messages] << "Error testing account management: #{e.message}"
          end

          results
        end

        # Runs all validation tests
        # Executes all validation tests and combines the results
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Hash] Combined test results with status and messages
        def self.run_all_tests(data_dir)
          results = {
            status: true,
            messages: ["Starting validation tests..."]
          }

          # Run YAML structure validation
          yaml_results = validate_yaml_file(data_dir)
          results[:status] &&= yaml_results[:status]
          results[:messages] << "YAML Structure Validation:"
          results[:messages].concat(yaml_results[:messages].map { |m| "  - #{m}" })

          # Run format conversion test
          conversion_results = test_format_conversion(data_dir)
          results[:status] &&= conversion_results[:status]
          results[:messages] << "Format Conversion Test:"
          results[:messages].concat(conversion_results[:messages].map { |m| "  - #{m}" })

          # Run account management test
          account_results = test_account_management(data_dir)
          results[:status] &&= account_results[:status]
          results[:messages] << "Account Management Test:"
          results[:messages].concat(account_results[:messages].map { |m| "  - #{m}" })

          # Add overall result
          if results[:status]
            results[:messages] << "All validation tests passed successfully!"
          else
            results[:messages] << "Some validation tests failed. See details above."
          end

          results
        end
      end
    end
  end
end
