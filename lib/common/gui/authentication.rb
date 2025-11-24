# frozen_string_literal: true

require_relative '../eaccess'

module Lich
  module Common
    module GUI
      # Handles authentication and launch data preparation for the Lich GUI
      # Provides methods for user authentication and preparing launch data for different frontends
      module Authentication
        # Authenticates a user with the game server
        #
        # @param account [String] User account name
        # @param password [String] User password
        # @param character [String, nil] Character name (optional)
        # @param game_code [String, nil] Game code (optional)
        # @param legacy [Boolean] Whether to use legacy authentication
        # @return [Hash, Array] Authentication data containing connection information
        def self.authenticate(account:, password:, character: nil, game_code: nil, legacy: false)
          if character && game_code
            EAccess.auth(
              account: account,
              password: password,
              character: character,
              game_code: game_code
            )
          elsif legacy
            EAccess.auth(
              account: account,
              password: password,
              legacy: true
            )
          else
            EAccess.auth(
              account: account,
              password: password
            )
          end
        end

        # Prepares launch data from authentication result
        # Formats the authentication data for use with different frontends
        #
        # @param auth_data [Hash] Authentication data from the authenticate method
        # @param frontend [String] Frontend type ('wizard', 'stormfront', 'avalon', 'suks')
        # @param custom_launch [String, nil] Custom launch command (optional)
        # @param custom_launch_dir [String, nil] Custom launch directory (optional)
        # @return [Array<String>] Launch data strings formatted for the selected frontend
        def self.prepare_launch_data(auth_data, frontend, custom_launch = nil, custom_launch_dir = nil)
          launch_data = auth_data.map { |k, v| "#{k.upcase}=#{v}" }

          # Modify launch data based on frontend
          case frontend.to_s.downcase
          when 'wizard'
            launch_data.collect! { |line|
              line.sub(/GAMEFILE=.+/, 'GAMEFILE=WIZARD.EXE')
                  .sub(/GAME=.+/, 'GAME=WIZ')
                  .sub(/FULLGAMENAME=.+/, 'FULLGAMENAME=Wizard Front End')
            }
          when 'avalon'
            launch_data.collect! { |line| line.sub(/GAME=.+/, 'GAME=AVALON') }
          when 'suks'
            launch_data.collect! { |line|
              line.sub(/GAMEFILE=.+/, 'GAMEFILE=WIZARD.EXE')
                  .sub(/GAME=.+/, 'GAME=SUKS')
            }
          end

          # Add custom launch information if provided
          if custom_launch
            launch_data.push "CUSTOMLAUNCH=#{custom_launch}"
            launch_data.push "CUSTOMLAUNCHDIR=#{custom_launch_dir}" if custom_launch_dir
          end

          launch_data
        end

        # Creates a hash entry for saved login data
        # This standardizes the format of saved login entries
        #
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param game_name [String] Game name
        # @param user_id [String] User ID
        # @param password [String] Password
        # @param frontend [String] Frontend type
        # @param custom_launch [String, nil] Custom launch command (optional)
        # @param custom_launch_dir [String, nil] Custom launch directory (optional)
        # @return [Hash] Entry data hash ready for storage
        def self.create_entry_data(char_name:, game_code:, game_name:, user_id:, password:, frontend:, custom_launch: nil, custom_launch_dir: nil)
          {
            char_name: char_name,
            game_code: game_code,
            game_name: game_name,
            user_id: user_id,
            password: password,
            frontend: frontend,
            custom_launch: custom_launch,
            custom_launch_dir: custom_launch_dir
          }
        end
      end
    end
  end
end
