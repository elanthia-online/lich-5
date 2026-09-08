# frozen_string_literal: true

require_relative 'eaccess'
require_relative 'web_login'

module Lich
  module Common
    module Authentication
      # Fatal auth failure - should not be retried
      class FatalAuthError < StandardError; end

      # Retry configuration for transient SSL/network errors
      # These errors are often temporary and resolve on retry:
      # - SSL_read: unexpected eof while reading (server closed connection)
      # - Connection reset by peer
      # - Connection timed out
      MAX_AUTH_RETRIES = 3
      AUTH_RETRY_BASE_DELAY = 5 # seconds, doubles each retry: 5s, 10s, 20s

      # Known fatal error codes that should not be retried. Shared across
      # every provider's AuthenticationError (EAccess, WebLogin) -- with_retry
      # classifies by error_code alone, not by exception class, so this list
      # applies uniformly regardless of which provider raised it.
      # REJECT = bad credentials, NORECORD = account not found, INVALID = invalid request
      # PASSWORD = wrong password, CHARACTER_NOT_FOUND = character not in account
      # GENERATOR_NOT_AVAILABLE = account not entitled to create a character on the instance
      # LOGIN_FAILED = WebLogin's credential-rejection signal (see web_login.rb)
      FATAL_ERROR_CODES = %w[REJECT NORECORD INVALID PASSWORD CHARACTER_NOT_FOUND GENERATOR_NOT_AVAILABLE LOGIN_FAILED].freeze

      # Authenticates a user with the game server.
      #
      # By default, authenticates via EAccess (eaccess.play.net:7910). If
      # EAccess fails for any reason OTHER than rejected credentials (a
      # FatalAuthError -- REJECT/PASSWORD/NORECORD/etc), automatically falls
      # back to the HTTPS WebLogin path once EAccess's own retries are
      # exhausted. This distinction matters: EAccess being unreachable is a
      # reason to try a different transport; EAccess correctly rejecting a
      # bad password is not -- falling back in that case would just resubmit
      # the same bad credentials to a second system for no benefit. See
      # docs/web-login-protocol-analysis.md.
      #
      # Fallback only applies to a normal single-character login (character
      # AND game_code present, not legacy, not generator) -- WebLogin has no
      # equivalent yet for the legacy multi-game enumeration mode or
      # character-generator entry.
      #
      # @param account [String] User account name
      # @param password [String] User password
      # @param character [String, nil] Character name (optional)
      # @param game_code [String, nil] Game code (optional)
      # @param legacy [Boolean] Whether to use legacy authentication
      # @param generator [Boolean] Whether to enter the character generator instead of selecting a character
      # @param auth_provider [Symbol] :eaccess (default, with automatic web fallback) or :web to force
      #   the HTTPS WebLogin path directly, skipping EAccess entirely
      # @return [Hash, Array] Authentication data containing connection information
      # @raise [StandardError] Re-raises the last error after all retries (and fallback, if applicable) exhausted
      def self.authenticate(account:, password:, character: nil, game_code: nil, legacy: false, generator: false, auth_provider: :eaccess)
        if auth_provider == :web
          unless web_fallback_supported?(character: character, game_code: game_code, legacy: legacy, generator: generator)
            raise ArgumentError, "auth_provider: :web requires character and game_code, and supports neither legacy nor generator"
          end

          result = with_retry {
            WebLogin.auth_with_timeout(account: account, password: password, character: character, game_code: game_code)
          }
          Lich.log "info: authenticated via web login (forced by auth_provider: :web)"
          return result
        end

        begin
          result = authenticate_via_eaccess(account: account, password: password, character: character, game_code: game_code, legacy: legacy, generator: generator)
          Lich.log "info: authenticated via eaccess"
          result
        rescue FatalAuthError
          # Credentials were rejected -- WebLogin would reject the same
          # credentials too, so falling back would just resubmit them to a
          # second system for no benefit. Surface the real problem.
          raise
        rescue StandardError => e
          raise unless web_fallback_supported?(character: character, game_code: game_code, legacy: legacy, generator: generator)

          Lich.log "warn: EAccess authentication unavailable (#{e.class}: #{e.message}); falling back to web login"
          result = with_retry {
            WebLogin.auth_with_timeout(account: account, password: password, character: character, game_code: game_code)
          }
          Lich.log "info: authenticated via web login (fallback from eaccess)"
          result
        end
      end

      # @api private
      def self.authenticate_via_eaccess(account:, password:, character:, game_code:, legacy:, generator:)
        with_retry do
          if game_code && (character || generator)
            EAccess.auth_with_timeout(
              account: account,
              password: password,
              character: character,
              game_code: game_code,
              generator: generator
            )
          elsif legacy
            EAccess.auth_with_timeout(
              account: account,
              password: password,
              legacy: true
            )
          else
            EAccess.auth_with_timeout(
              account: account,
              password: password
            )
          end
        end
      end

      # @api private
      # WebLogin only implements a normal single-character login -- no
      # equivalent yet for legacy multi-game enumeration or character
      # generator entry (see docs/web-login-protocol-analysis.md).
      def self.web_fallback_supported?(character:, game_code:, legacy:, generator:)
        character && game_code && !legacy && !generator
      end

      # Executes a block with retry logic for transient errors
      #
      # @yield The block to execute with retry
      # @return [Object] The result of the block
      # @raise [FatalAuthError] For fatal auth failures (bad credentials, etc.)
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
          rescue FatalAuthError
            # Don't retry fatal auth failures - re-raise immediately
            raise
          rescue StandardError => e
            # Classified by error_code alone, not exception class, so this
            # applies uniformly to any provider's AuthenticationError
            # (EAccess, WebLogin) -- both expose the same error_code shape.
            if e.respond_to?(:error_code) && FATAL_ERROR_CODES.any? { |code| e.error_code&.include?(code) }
              Lich.log "error: Authentication fatally failed: #{e.message}"
              raise FatalAuthError, e.message
            end

            # Transient auth error - allow retry
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
    end
  end
end
