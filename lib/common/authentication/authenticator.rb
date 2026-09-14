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
      # NO_SUBSCRIPTION = WebLogin: account has no active subscription on the requested instance
      FATAL_ERROR_CODES = %w[REJECT NORECORD INVALID PASSWORD CHARACTER_NOT_FOUND GENERATOR_NOT_AVAILABLE LOGIN_FAILED NO_SUBSCRIPTION].freeze

      # Connection-level failures where the endpoint itself didn't respond.
      # with_retry can stop after the first attempt for these (see its
      # fast_fail_unreachable: parameter) when an alternate provider is
      # actually available to hand off to -- retrying the same unreachable
      # endpoint 3 times with backoff only wastes time in that case, since
      # it just delays the handoff. When there is NO alternate provider
      # (legacy/generator EAccess calls, or a WebLogin call itself, forced
      # or already-the-fallback), these same error classes get full retries
      # like any other transient error: an ECONNRESET or "SSL_read:
      # unexpected eof" mid-exchange is not proof the endpoint is down, and
      # there is nothing to fail fast *to*.
      UNREACHABLE_ERROR_CLASSES = [
        SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT,
        Errno::EHOSTUNREACH, Errno::ENETUNREACH, OpenSSL::SSL::SSLError
      ].freeze

      # @api private
      # True for a connection-level failure (see UNREACHABLE_ERROR_CLASSES),
      # or the "timed out authenticating" RuntimeError EAccess/WebLogin's own
      # auth_with_timeout watchdogs raise when the endpoint never responds at
      # all (a black-holed connection times out rather than refusing
      # immediately, so it never raises one of the Errno classes).
      #
      # @param error [StandardError] the error caught by with_retry
      # @return [Boolean]
      def self.unreachable_error?(error)
        return true if UNREACHABLE_ERROR_CLASSES.any? { |klass| error.is_a?(klass) }

        error.is_a?(RuntimeError) && error.message.to_s.start_with?('error: timed out authenticating')
      end

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
        # Provider-neutral: EAccess.auth also sets this internally (before
        # its own protocol exchange even starts, so it's visible mid-attempt
        # for the eaccess path), but WebLogin.auth does not, and the forced
        # auth_provider: :web / fallback-to-web paths would otherwise skip
        # EAccess entirely and leave this unset -- breaking session-file
        # creation, setup-file resolution, and active-session lifecycle
        # naming, which all read Account.character.
        if defined?(Lich::Common::Account)
          Lich::Common::Account.name = account
          Lich::Common::Account.game_code = game_code
          Lich::Common::Account.character = character
        end

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

        fallback_available = web_fallback_supported?(character: character, game_code: game_code, legacy: legacy, generator: generator)

        begin
          result = authenticate_via_eaccess(
            account: account, password: password, character: character, game_code: game_code,
            legacy: legacy, generator: generator, fast_fail_unreachable: fallback_available
          )
          Lich.log "info: authenticated via eaccess"
          result
        rescue FatalAuthError
          # Credentials were rejected -- WebLogin would reject the same
          # credentials too, so falling back would just resubmit them to a
          # second system for no benefit. Surface the real problem.
          raise
        rescue StandardError => e
          raise unless fallback_available

          Lich.log "warn: EAccess authentication unavailable (#{e.class}: #{e.message}); falling back to web login"
          result = with_retry {
            WebLogin.auth_with_timeout(account: account, password: password, character: character, game_code: game_code)
          }
          Lich.log "info: authenticated via web login (fallback from eaccess)"
          result
        end
      end

      # Dispatches to the appropriate EAccess.auth_with_timeout call shape
      # based on which of character/game_code/legacy/generator were given.
      #
      # @param account [String] account name
      # @param password [String] account password
      # @param character [String, nil] character name
      # @param game_code [String, nil] game instance code
      # @param legacy [Boolean] use the legacy multi-game enumeration mode
      # @param generator [Boolean] enter the character generator
      # @param fast_fail_unreachable [Boolean] stop after one attempt on a connection-level
      #   failure instead of retrying -- only pass true when a WebLogin fallback is actually
      #   available to hand off to (see Authenticator.authenticate)
      # @return [Hash, Array] see EAccess.auth
      # @api private
      def self.authenticate_via_eaccess(account:, password:, character:, game_code:, legacy:, generator:, fast_fail_unreachable: false)
        with_retry(fast_fail_unreachable: fast_fail_unreachable) do
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

      # WebLogin only implements a normal single-character login -- no
      # equivalent yet for legacy multi-game enumeration or character
      # generator entry (see docs/web-login-protocol-analysis.md).
      #
      # @param character [String, nil] character name
      # @param game_code [String, nil] game instance code
      # @param legacy [Boolean] legacy multi-game enumeration mode requested
      # @param generator [Boolean] character generator entry requested
      # @return [Boolean] true if this request shape has a WebLogin equivalent
      # @api private
      def self.web_fallback_supported?(character:, game_code:, legacy:, generator:)
        !!(character && game_code && !legacy && !generator)
      end

      # Executes a block with retry logic for transient errors
      #
      # @param fast_fail_unreachable [Boolean] if true, a connection-level failure (see
      #   .unreachable_error?) stops retrying after the first attempt instead of exhausting
      #   MAX_AUTH_RETRIES. Only pass true when an alternate provider is actually available to
      #   hand off to (see Authenticator.authenticate) -- otherwise this just gives up early on
      #   what may be a genuinely transient, reachable-endpoint error (e.g. an ECONNRESET or
      #   "SSL_read: unexpected eof" mid-exchange) with nothing to fail over to.
      # @yield The block to execute with retry
      # @return [Object] The result of the block
      # @raise [FatalAuthError] For fatal auth failures (bad credentials, etc.)
      # @raise [StandardError] Re-raises the last error after all retries exhausted
      def self.with_retry(fast_fail_unreachable: false)
        last_error = nil
        attempts_made = 0

        MAX_AUTH_RETRIES.times do |attempt|
          attempts_made = attempt + 1

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

            last_error = e

            if fast_fail_unreachable && unreachable_error?(e)
              # The endpoint itself didn't respond, and an alternate
              # provider is available -- retrying it again immediately
              # isn't going to help, and every retry here directly delays
              # the handoff. Stop now instead of exhausting MAX_AUTH_RETRIES.
              Lich.log "warn: Authentication endpoint unreachable (#{e.class}: #{e.message}); not retrying the same endpoint -- an alternate provider is available"
              break
            end

            # Transient auth error - allow retry (this covers
            # unreachable_error? classes too when fast_fail_unreachable is
            # false, e.g. legacy/generator EAccess calls or any WebLogin
            # call -- there is no alternate provider to fail fast *to* there,
            # so a reset mid-exchange gets the same retry chance as any
            # other transient error).
            if attempt < MAX_AUTH_RETRIES - 1
              delay = AUTH_RETRY_BASE_DELAY * (2**attempt)
              Lich.log "warn: Authentication attempt #{attempt + 1}/#{MAX_AUTH_RETRIES} failed: " \
                       "#{e.message}, retrying in #{delay}s..."
              sleep(delay)
            end
          end
        end

        # All retries exhausted (or fast-failed early) - re-raise the last
        # error, logging how many attempts actually happened rather than
        # always claiming MAX_AUTH_RETRIES.
        attempt_word = attempts_made == 1 ? 'attempt' : 'attempts'
        Lich.log "error: Authentication failed after #{attempts_made} #{attempt_word}: #{last_error&.message}"
        raise last_error
      end
    end
  end
end
