# frozen_string_literal: true

require_relative '../eaccess'

module Lich
  module Common
    module GUI
      # Handles authentication and launch data preparation for the Lich GUI
      # Provides methods for user authentication and preparing launch data for different frontends
      module Authentication
        # Retry configuration for transient SSL/network errors
        # These errors are often temporary and resolve on retry:
        # - SSL_read: unexpected eof while reading (server closed connection)
        # - Connection reset by peer
        # - Connection timed out
        MAX_AUTH_RETRIES = 3
        AUTH_RETRY_BASE_DELAY = 5 # seconds, doubles each retry: 5s, 10s, 20s

        # Authenticates a user with the game server
        # Includes automatic retry with exponential backoff for transient errors
        #
        # @param account [String] User account name
        # @param password [String] User password
        # @param character [String, nil] Character name (optional)
        # @param game_code [String, nil] Game code (optional)
        # @param legacy [Boolean] Whether to use legacy authentication
        # @return [Hash, Array] Authentication data containing connection information
        # @raise [StandardError] Re-raises the last error after all retries exhausted
        def self.authenticate(account:, password:, character: nil, game_code: nil, legacy: false)
          with_retry do
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
        end

        # Executes a block with retry logic for transient errors
        #
        # @yield The block to execute with retry
        # @return [Object] The result of the block
        # @raise [StandardError] Re-raises the last error after all retries exhausted
        def self.with_retry
          last_error = nil

          MAX_AUTH_RETRIES.times do |attempt|
            begin
              result = yield

              # Success - log if this was a retry
              if attempt.positive?
                Lich.log "info: Authentication succeeded on attempt #{attempt + 1}"
              end

              return result
            rescue StandardError => e
              last_error = e

              if attempt < MAX_AUTH_RETRIES - 1
                delay = AUTH_RETRY_BASE_DELAY * (2**attempt)
                Lich.log "warn: Authentication attempt #{attempt + 1}/#{MAX_AUTH_RETRIES} failed: " \
                         "#{e.message}, retrying in #{delay}s..."
                sleep(delay)
              end
            end
          end

          # All retries exhausted - re-raise the last error
          Lich.log "error: Authentication failed after #{MAX_AUTH_RETRIES} attempts: #{last_error&.message}"
          raise last_error
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
