# frozen_string_literal: true

module Lich
  module Common
    module Authentication
      # Handles formatting of launch data for different game frontends
      module LaunchData
        # @api private
        # Prepares launch data from authentication result
        # Formats the authentication data for use with different frontends
        #
        # @param auth_data [Hash] Authentication data from the authenticate method
        # @param frontend [String] Frontend type ('wizard', 'stormfront', 'avalon', 'suks')
        # @param custom_launch [String, nil] Custom launch command (optional)
        # @param custom_launch_dir [String, nil] Custom launch directory (optional)
        # @return [Array<String>] Launch data strings formatted for the selected frontend
        def self.prepare(auth_data, frontend, custom_launch = nil, custom_launch_dir = nil)
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

        # @api private
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
        def self.create_entry(char_name:, game_code:, game_name:, user_id:, password:, frontend:, custom_launch: nil, custom_launch_dir: nil)
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
