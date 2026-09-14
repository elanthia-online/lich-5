# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "launch_result"

module Lich
  module Common
    module Authentication
      # HTTPS-based fallback authentication against play.net's web login flow
      # (www.play.net), for use when the TLS EAccess protocol
      # (eaccess.play.net:7910) is unreachable.
      #
      # Mirrors EAccess's public interface (.auth / .auth_with_timeout) and
      # returns the same login_info hash shape (lowercase GAMEHOST/GAMEPORT/KEY
      # keys, etc.) so Authenticator can select a backend without callers
      # changing. See docs/web-login-protocol-analysis.md for how this
      # contract was reverse-engineered from a live browser capture, and for
      # what remains unconfirmed.
      #
      # Only game codes confirmed live against the real servers are enabled
      # (see CONFIRMED_INSTANCES) -- fail closed rather than assume an
      # untested instance code behaves like a confirmed one; the web layer's
      # own game codes are not always identical to EAccess's (confirmed
      # mismatch: GemStone Prime is "GS4" here vs "GS3" over EAccess).
      #
      # Unlike EAccess, there is no enumeration endpoint for an account's
      # characters -- the character list is server-rendered into the game's
      # home.asp page as radio inputs, so resolving a character name to its
      # charID means scraping that HTML (see .resolve_char_code). This is the
      # most fragile part of this module: a play.net markup change breaks it
      # silently rather than with a clear protocol error.
      module WebLogin
        # Raised on login failure or when a character/game code can't be resolved.
        # error_code is a best-effort label, not a stable server-provided code
        # like EAccess's REJECT/NORECORD/etc -- see docs/web-login-protocol-analysis.md
        # "Open Questions" for what remains unconfirmed.
        class AuthenticationError < StandardError
          attr_reader :error_code

          def initialize(error_code)
            @error_code = error_code
            super("Error(#{error_code})")
          end
        end

        BASE_HOST = "www.play.net"

        # Redirect hops .follow_redirects will chase before giving up. The
        # confirmed live chain is 2 hops (goplay2.asp -> playing_web.asp ->
        # goplay_web.asp -> final https:// Location); this leaves headroom
        # without allowing an unbounded loop on an unexpected response.
        MAX_REDIRECTS = 5

        # Bounds each individual HTTP request's connect and read phases (see
        # .auth) so a single black-holed request fails in seconds instead of
        # relying entirely on auth_with_timeout's 30s overall watchdog --
        # mirrors EAccess::CONNECT_TIMEOUT's rationale.
        OPEN_TIMEOUT = 5
        READ_TIMEOUT = 10

        # Minimal in-memory cookie jar, private to a single .auth call (a
        # fresh instance per call -- never shared across accounts/sessions).
        # Only tracks name=value pairs; attributes (Path/HttpOnly/Secure/
        # Expires/etc) are dropped since we're just replaying whatever the
        # server issued back to the same host, not implementing full RFC 6265
        # scoping.
        # @api private
        class CookieJar
          def initialize
            @pairs = {}
          end

          # Reads Set-Cookie headers from a response and merges them in,
          # keyed by cookie name, so a response that only rotates one cookie
          # doesn't drop others still needed from an earlier response.
          #
          # @param response [Net::HTTPResponse] response to read Set-Cookie from
          # @return [CookieJar] self
          def absorb(response)
            response.get_fields("set-cookie").to_a.each do |raw|
              name, value = raw.split(";", 2).first.to_s.split("=", 2)
              @pairs[name] = value if name && !name.empty?
            end
            self
          end

          # Builds the Cookie header value for the next request.
          #
          # @return [String, nil] Cookie header value for the next request, or nil if empty
          def header
            return nil if @pairs.empty?

            @pairs.map { |name, value| "#{name}=#{value}" }.join("; ")
          end
        end

        # play.net's front end (CloudFront/WAF) returns a bare 500 for any
        # request without a browser-like User-Agent -- confirmed live, not
        # documented anywhere. Ruby's Net::HTTP default UA ("Ruby/x.y.z") is
        # rejected outright, including on the very first GET. Every request
        # this module makes must carry this header.
        USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        # Every game code this module will accept, each with a
        # `character_list_path` (the actual page a user would pick that game
        # code from -- see below) and a `web_game_code` (the `game` form
        # value; not always identical to the EAccess code -- confirmed
        # mismatch: GemStone Prime is "GS4" here vs "GS3" over EAccess).
        # Fail closed: a game_code not in this table raises rather than
        # guessing at any of this from the EAccess table.
        #
        # `expected_host`/`expected_port`, when present, pin
        # .extract_connection_info to the exact live-confirmed values rather
        # than trusting whatever the server's response says. DR, DRT, GS3,
        # GST, and GSF are all confirmed this way.
        #
        # DRX (Platinum) and DRF (Fallen) are enabled with `expected_host`/
        # `expected_port` deliberately left nil: nobody has an account with
        # these entitlements to confirm live yet, but they're wired in
        # end-to-end (character_list_path, family, and a best-guess
        # web_game_code assuming it matches the EAccess code, as it does for
        # DR/DRT/GSF -- only GS3->GS4 has ever diverged) so a tester who does
        # have access can exercise this without a code change. See
        # .extract_connection_info for what "unverified" relaxes and what it
        # still enforces, and docs/web-login-protocol-analysis.md for what to
        # do once a real result comes back: hardcode the observed host/port
        # here and this comment no longer applies.
        #
        # GSX (GemStone Platinum) is absent because the instance itself has
        # been retired -- LoginHelpers.VALID_GAME_CODES already excludes it
        # for the same reason, independent of this module.
        #
        # `character_list_path` matters: confirmed live that a character can
        # exist on ONE instance of a family but not appear on that family's
        # generic /home.asp at all (a GemStone Shattered-only character does
        # not show up on the GemStone Prime page) -- so .resolve_char_code
        # must scrape the same instance-specific page a user would actually
        # pick this game code from, not assume the family's home.asp always
        # has the full account-wide picture (true for DR/DRT/GS3/GST, where
        # the same character happens to be shared, but not a safe general
        # assumption).
        CONFIRMED_INSTANCES = {
          "DR"  => { family: "dr",  web_game_code: "DR",  character_list_path: "/dr/play/home.asp",       expected_host: "storm.dr.game.play.net",  expected_port: "11024" },
          "DRT" => { family: "dr",  web_game_code: "DRT", character_list_path: "/dr/play/playdrt.asp",    expected_host: "hydra.simutronics.com",   expected_port: "11624" },
          "DRX" => { family: "dr",  web_game_code: "DRX", character_list_path: "/dr/play/playx.asp",      expected_host: nil, expected_port: nil }, # unverified -- see comment above
          "DRF" => { family: "dr",  web_game_code: "DRF", character_list_path: "/dr/play/playf.asp",      expected_host: nil, expected_port: nil }, # unverified -- see comment above
          "GS3" => { family: "gs4", web_game_code: "GS4", character_list_path: "/gs4/play/home.asp",      expected_host: "storm.gs4.game.play.net", expected_port: "10024" },
          "GST" => { family: "gs4", web_game_code: "GST", character_list_path: "/gs4/play/play_test.asp", expected_host: "chimera.simutronics.com", expected_port: "10624" },
          "GSF" => { family: "gs4", web_game_code: "GSF", character_list_path: "/gs4/play/playf.asp",     expected_host: "storm.gs4.game.play.net", expected_port: "10324" },
        }.freeze

        # The fallback guard for an unverified instance's connection info
        # (.extract_connection_info), since there's no exact expected_host to
        # match yet -- the returned host must at least end in one of these.
        # A confirmed instance's exact-match check already implies this, so
        # this only comes into play for the unverified case.
        TRUSTED_GAME_HOST_SUFFIXES = [".simutronics.com", ".simutronics.net", ".game.play.net"].freeze

        # @param host [String] hostname to check
        # @return [Boolean] true if host ends in a known Simutronics game-server domain
        # @api private
        def self.trusted_game_host?(host)
          TRUSTED_GAME_HOST_SUFFIXES.any? { |suffix| host.to_s.end_with?(suffix) }
        end

        # @param game_code [String] EAccess-style game instance code
        # @return [Hash] the CONFIRMED_INSTANCES entry for game_code
        # @raise [AuthenticationError] "UNSUPPORTED_GAME_CODE" if game_code is not in CONFIRMED_INSTANCES at all
        # @api private
        def self.instance_for(game_code)
          CONFIRMED_INSTANCES.fetch(game_code) { raise AuthenticationError, "UNSUPPORTED_GAME_CODE" }
        end

        # Authenticates against play.net's web login flow and resolves a
        # character launch. Does not support EAccess's `legacy` multi-game
        # enumeration mode or the `generator` (character-0) flow -- neither
        # has a confirmed web-flow equivalent yet (see protocol doc).
        #
        # @param password [String] account password (sent as an HTTPS form field, not obfuscated client-side)
        # @param account [String] account name
        # @param character [String] character name to select (resolved to a charID by scraping home.asp)
        # @param game_code [String] EAccess-style game instance code -- must be a key of CONFIRMED_INSTANCES
        # @return [Hash] login info hash: gamehost, gameport, key (confirmed from the server),
        #   plus game/gamecode/fullgamename/gamefile (NOT server-provided by this flow --
        #   synthesized locally to match EAccess's STORM/Wrayth defaults so downstream
        #   LaunchData formatting keeps working; verify these are still correct before
        #   trusting them for a frontend other than Stormfront/Wrayth)
        # @raise [AuthenticationError] on login failure, an unsupported/unresolved game code or
        #   character, or a server response that doesn't match the confirmed protocol shape
        def self.auth(password:, account:, character:, game_code:)
          instance = instance_for(game_code)
          jar = CookieJar.new

          # Block form: Net::HTTP.start finishes (closes) the connection in
          # an ensure regardless of how the block exits, on every path --
          # previously a bare Net::HTTP.new was never explicitly closed on
          # success or failure, leaving the socket open until GC finalized
          # it. open_timeout/read_timeout also bound each individual
          # request's connect/read phases, so a single black-holed request
          # fails in seconds instead of relying entirely on
          # auth_with_timeout's 30s overall watchdog to unstick it --
          # mirrors EAccess::CONNECT_TIMEOUT's rationale.
          Net::HTTP.start(BASE_HOST, 443, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER,
                                           open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
            login(http, jar, account: account, password: password, family: instance[:family])
            char_code = resolve_char_code(http, jar, instance: instance, character: character)
            host, port, key = select_character(http, jar, char_code: char_code, instance: instance)

            LaunchResult.normalize(
              "gamehost"     => host,
              "gameport"     => port,
              "key"          => key,
              # Not returned by this flow -- synthesized to match EAccess's
              # STORM/Wrayth defaults (see class doc). LaunchData.prepare
              # already overrides GAME/GAMEFILE/FULLGAMENAME per-frontend for
              # wizard/avalon/saga/suks, so this only needs to be a correct
              # default for the Stormfront/Wrayth case.
              "game"         => "STORM",
              "gamecode"     => game_code,
              "fullgamename" => "Wrayth",
              "gamefile"     => "WRAYTH.EXE",
            )
          end
        end

        # @param timeout [Integer, Float] seconds to wait for the full exchange
        # @param kwargs [Hash] forwarded to {.auth}
        # @return [Hash] see {.auth}
        # @raise [RuntimeError] if the exchange does not complete within +timeout+
        # @raise [StandardError] re-raises whatever {.auth} raises
        # @see .auth
        def self.auth_with_timeout(timeout: 30, **kwargs)
          auth_thread = Thread.new {
            Thread.current.report_on_exception = false
            auth(**kwargs)
          }
          if auth_thread.join(timeout).nil?
            auth_thread.kill rescue nil
            raise "error: timed out authenticating with web login after #{timeout}s"
          end
          auth_thread.value
        end

        # An account that has never set a security question is redirected
        # here instead of okay_page on an otherwise-successful login --
        # confirmed live. The session is already fully authenticated at this
        # point (the account name renders in the page banner; Set-Cookie
        # already carries the real session), so this is not a login failure
        # -- .resolve_char_code's own subsequent GET of okay_page picks up
        # the same authenticated session, matching what manually navigating
        # straight to the game's play page does in a browser. If that
        # assumption were ever wrong, resolve_char_code fails safely with
        # CHARACTER_NOT_FOUND rather than proceeding on bad data.
        SECURITY_QA_PATH = "/playdotnet/account/security_qa.asp"

        # GETs the family's sign-in page first to establish an ASP session
        # cookie, then POSTs credentials against that session -- confirmed
        # live as required: posting login.asp cold (no prior GET, no session
        # cookie) gets a bare 500 from the server, matching how a real
        # browser always visits signin_needed.asp before submitting the
        # form. Failure is detected by comparing the redirect target's PATH
        # against the two page paths we supplied -- not a prefix match
        # against the raw Location string, which would also match an
        # unrelated same-prefix page (e.g. "login_error.aspX") and would
        # miss an absolute-URL redirect entirely -- and NOT by parsing
        # response body text. See SECURITY_QA_PATH for the one other
        # accepted redirect target.
        #
        # @param http [Net::HTTP] open connection to BASE_HOST
        # @param jar [CookieJar] session cookie jar, mutated in place
        # @param account [String] account name
        # @param password [String] account password
        # @param family [String] game family path segment ("dr" or "gs4")
        # @return [void]
        # @raise [AuthenticationError] "LOGIN_FAILED" on rejected credentials, "UNEXPECTED_LOGIN_RESPONSE"
        #   on any other redirect target, or "UNEXPECTED_NON_REDIRECT_RESPONSE"/"MALFORMED_LOGIN_REDIRECT"
        #   if the response isn't a well-formed redirect at all
        # @api private
        def self.login(http, jar, account:, password:, family:)
          okay_page = "/#{family}/play/home.asp"
          error_page = "/#{family}/login_error.asp"

          get(http, jar, "/#{family}/signin_needed.asp")

          request = Net::HTTP::Post.new("/includes/common/login/login.asp")
          set_common_headers(request, jar)
          request["Content-Type"] = "application/x-www-form-urlencoded"
          request.body = URI.encode_www_form(
            return_okay_page: okay_page,
            return_error_page: error_page,
            remember_account: "",
            remember_password: "",
            account_name: account,
            account_password: password,
            submit: "Login"
          )
          response = http.request(request)
          jar.absorb(response)

          path = redirect_path(response, malformed_code: "MALFORMED_LOGIN_REDIRECT")
          raise AuthenticationError, "LOGIN_FAILED" if path == error_page
          return if path == okay_page || path == SECURITY_QA_PATH

          raise AuthenticationError, "UNEXPECTED_LOGIN_RESPONSE"
        end

        # Step 1a: scrape the requested instance's character-selection page
        # for the charID matching `character`. See
        # docs/web-login-protocol-analysis.md for the exact markup this
        # depends on and why it's the most fragile part of this module.
        #
        # @param http [Net::HTTP] open connection to BASE_HOST
        # @param jar [CookieJar] session cookie jar
        # @param instance [Hash] a CONFIRMED_INSTANCES entry
        # @param character [String] character name to match (case-insensitive)
        # @return [String] the matched charID (e.g. "W_ACCOUNT_000")
        # @raise [AuthenticationError] "NO_SUBSCRIPTION" if the account has no active subscription
        #   on this instance, "CHARACTER_NOT_FOUND" if no radio input matches a 200 response, or
        #   "UNEXPECTED_CHARACTER_LIST_RESPONSE" for any other non-200 response (a 3xx to anywhere
        #   but subscription_needed.asp, or a 4xx/5xx)
        # @api private
        def self.resolve_char_code(http, jar, instance:, character:)
          response = get(http, jar, instance[:character_list_path])
          code = response.code.to_i

          if (300..399).cover?(code)
            # Confirmed live: an account with no active subscription on this
            # instance gets a *second* redirect here (the first, from
            # login.asp, already landed on okay_page successfully) --
            # `get` doesn't follow it, so this would otherwise silently fall
            # through to an empty body scrape and a misleading
            # CHARACTER_NOT_FOUND instead of the real cause.
            #
            # Not one fixed path: confirmed live that this varies per
            # instance -- DR's is plain "subscription_needed.asp", but
            # DRX's/DRF's are "subscription_to_plat_needed.asp" /
            # "subscription_to_fall_needed.asp". Matched by pattern rather
            # than an exact string so an instance-specific variant we
            # haven't seen yet (e.g. if GST/GSF ever needs one) is still
            # recognized instead of falling through to the generic
            # UNEXPECTED_CHARACTER_LIST_RESPONSE below.
            subscription_needed_pattern = %r{\A/#{Regexp.escape(instance[:family])}/play/subscription(?:_to_\w+)?_needed\.asp\z}
            raise AuthenticationError, "NO_SUBSCRIPTION" if response["location"].to_s.match?(subscription_needed_pattern)

            raise AuthenticationError, "UNEXPECTED_CHARACTER_LIST_RESPONSE"
          end

          # A non-3xx error response (4xx/5xx -- e.g. a transient 503) must
          # not fall through to the scraper either: an empty/error body
          # scrapes to no match, which would otherwise raise the same
          # CHARACTER_NOT_FOUND a real "no such character" case raises --
          # and Authenticator treats CHARACTER_NOT_FOUND as fatal (no
          # retry), silently discarding what may well have been a transient,
          # retryable server error.
          raise AuthenticationError, "UNEXPECTED_CHARACTER_LIST_RESPONSE" unless code == 200

          body = response.body.to_s
          body.scan(/id="(W_[A-Za-z0-9_]+)"[^>]*>\s*<label for="\1"><span[^>]*>([^<]+)<\/span>/).each do |char_code, name|
            return char_code if name.strip.casecmp?(character)
          end

          raise AuthenticationError, "CHARACTER_NOT_FOUND"
        end

        # Steps 2-4: submit the character/instance selection and follow the
        # redirects to the final host/port/key triple, without ever fetching
        # the web client page itself.
        #
        # @param http [Net::HTTP] open connection to BASE_HOST
        # @param jar [CookieJar] session cookie jar
        # @param char_code [String] charID from .resolve_char_code
        # @param instance [Hash] a CONFIRMED_INSTANCES entry
        # @return [Array(String, String, String)] [host, port, key]
        # @api private
        def self.select_character(http, jar, char_code:, instance:)
          request = Net::HTTP::Post.new("/includes/common/play/goplay2.asp")
          set_common_headers(request, jar)
          request["Content-Type"] = "application/x-www-form-urlencoded"
          request.body = URI.encode_www_form(
            charID: char_code,
            # Present in every confirmed live capture except GemStone Test's
            # (see docs/web-login-protocol-analysis.md) -- sent unconditionally
            # since an extra form field the server doesn't need for that one
            # case is far cheaper than silently omitting one it does need.
            NEWCHARSUB: "TRUE",
            managesub: 0,
            gameName: instance[:family],
            instanceID: 0,
            game: instance[:web_game_code],
            frontend: "web"
          )
          response = http.request(request)
          jar.absorb(response)
          location = follow_redirects(http, jar, response)

          extract_connection_info(location, instance: instance)
        end

        # Follows relative Location redirects via GET until an absolute
        # Location is reached, validates its origin, and returns that URL
        # string without fetching it -- the final hop carries the connection
        # info in its query string; fetching it would load the web client
        # page itself, which we don't want (see class doc).
        #
        # A relative Location can never escape www.play.net on its own,
        # since every GET here reuses the same `http` connection, which is
        # bound to BASE_HOST regardless of what path string it's given. The
        # one point that guarantee doesn't hold is an absolute Location, so
        # any absolute URL -- https or otherwise -- is validated immediately
        # (.validate_final_url!) rather than ever being handed to `get` as if
        # it were a path.
        #
        # @param http [Net::HTTP] open connection to BASE_HOST
        # @param jar [CookieJar] session cookie jar
        # @param response [Net::HTTPResponse] the response to start following redirects from
        # @return [String] the validated final absolute URL (not fetched)
        # @raise [AuthenticationError] "TOO_MANY_REDIRECTS" past MAX_REDIRECTS hops, or anything
        #   .redirect_path / .validate_final_url! raises
        # @api private
        def self.follow_redirects(http, jar, response)
          MAX_REDIRECTS.times do
            location = redirect_path(response, malformed_code: "MALFORMED_REDIRECT_URL", full_url: true)
            # Any absolute URL -- not just https:// -- must be validated
            # immediately rather than ever reaching `get` as if it were a
            # relative path: a plain http:// Location would otherwise be
            # requested literally as a path string on the existing HTTPS
            # connection instead of being recognized (and rejected) as the
            # downgrade attempt it is.
            if location =~ %r{\Ahttps?://}i
              validate_final_url!(location)
              return location
            end

            response = get(http, jar, location)
          end

          raise AuthenticationError, "TOO_MANY_REDIRECTS"
        end

        # Extracts a redirect's target from a response, rejecting anything
        # that isn't an actual well-formed redirect. Used for both the login
        # POST's single redirect (where the target only needs to be a path,
        # to compare against okay_page/error_page) and each hop of
        # .follow_redirects (where the raw Location -- absolute or relative
        # -- is needed to continue the chain).
        #
        # @param response [Net::HTTPResponse] response to read the redirect from
        # @param malformed_code [String] AuthenticationError code to raise if Location doesn't parse
        # @param full_url [Boolean] if true, return the raw Location string (for chaining, since it
        #   may be relative); if false (default), return just the parsed path (for a same-request
        #   pass/fail comparison against a known path, robust to an absolute-URL redirect too)
        # @return [String] the redirect's path, or the raw Location if full_url is true
        # @raise [AuthenticationError] "UNEXPECTED_NON_REDIRECT_RESPONSE" if the response isn't a 3xx
        #   with a non-blank Location, or malformed_code if Location doesn't parse as a URI
        # @api private
        def self.redirect_path(response, malformed_code:, full_url: false)
          code = response.code.to_i
          location = response["location"]
          raise AuthenticationError, "UNEXPECTED_NON_REDIRECT_RESPONSE" unless (300..399).cover?(code) && location && !location.empty?

          # Always parse -- even when returning the raw string for chaining
          # (full_url) -- so a malformed Location raises malformed_code here
          # rather than being handed unvalidated to `get` as if it were a
          # well-formed relative path.
          parsed = URI.parse(location)
          full_url ? location : parsed.path
        rescue URI::InvalidURIError
          raise AuthenticationError, malformed_code
        end

        # Strict origin/shape check on the final redirect target: exactly
        # `https://www.play.net/play/home.asp`, default port, no userinfo.
        # An off-host target, a downgraded-to-http target, or an unexpected
        # path/port (compromised/MITM'd response, unexpected play.net
        # change) must not be trusted, and must not be silently
        # misinterpreted as something else either.
        #
        # @param location [String] absolute URL to validate
        # @return [void]
        # @raise [AuthenticationError] "UNTRUSTED_REDIRECT_HOST" if any check fails
        # @api private
        def self.validate_final_url!(location)
          uri = URI.parse(location)
          valid = uri.is_a?(URI::HTTPS) && uri.host == BASE_HOST && uri.port == 443 &&
                  uri.userinfo.nil? && uri.path == "/play/home.asp"
          raise AuthenticationError, "UNTRUSTED_REDIRECT_HOST" unless valid
        rescue URI::InvalidURIError
          raise AuthenticationError, "UNTRUSTED_REDIRECT_HOST"
        end

        # Parses the final redirect's query string into the host/port/key
        # triple. Rejects a duplicate query key (last-value-wins would
        # otherwise let a repeated `key` param silently override the real
        # one) and any blank value.
        #
        # For a confirmed instance (expected_host/expected_port both
        # present), the returned host/port must match exactly rather than
        # being trusted as-is. For an unverified instance (see
        # CONFIRMED_INSTANCES), there's nothing yet to match exactly, so the
        # host is instead checked against TRUSTED_GAME_HOST_SUFFIXES -- a
        # looser but still real guard, and the observed host/port are logged
        # so they can be promoted into CONFIRMED_INSTANCES once a live
        # result confirms them.
        #
        # @param location [String] the validated final URL from .follow_redirects
        # @param instance [Hash] a CONFIRMED_INSTANCES entry
        # @return [Array(String, String, String)] [host, port, key]
        # @raise [AuthenticationError] "MALFORMED_LAUNCH_URL" if the query string doesn't parse,
        #   "DUPLICATE_QUERY_PARAM" if host/port/key appears more than once, "NO_CONNECTION_INFO"
        #   if any of host/port/key is missing or blank, "UNEXPECTED_CONNECTION_INFO" if a
        #   confirmed instance's returned host/port don't match its expected values, or
        #   "UNTRUSTED_CONNECTION_HOST" if an unverified instance's returned host isn't a
        #   recognized Simutronics game-server domain
        # @api private
        def self.extract_connection_info(location, instance:)
          uri = URI.parse(location)
          grouped = URI.decode_www_form(uri.query.to_s).group_by(&:first)

          %w[host port key].each do |name|
            raise AuthenticationError, "DUPLICATE_QUERY_PARAM" if grouped[name] && grouped[name].size > 1
          end

          host = grouped["host"]&.first&.last
          port = grouped["port"]&.first&.last
          key = grouped["key"]&.first&.last
          raise AuthenticationError, "NO_CONNECTION_INFO" if [host, port, key].any? { |v| v.to_s.empty? }

          if instance[:expected_host] && instance[:expected_port]
            unless host == instance[:expected_host] && port == instance[:expected_port]
              raise AuthenticationError, "UNEXPECTED_CONNECTION_INFO"
            end
          else
            raise AuthenticationError, "UNTRUSTED_CONNECTION_HOST" unless trusted_game_host?(host)

            Lich.log "warn: WebLogin -- #{instance[:web_game_code]} has no pinned host/port yet " \
                     "(unverified instance); observed host=#{host} port=#{port}. If this login " \
                     "succeeded, hardcode these into CONFIRMED_INSTANCES."
          end

          [host, port, key]
        rescue URI::InvalidURIError, ArgumentError
          raise AuthenticationError, "MALFORMED_LAUNCH_URL"
        end

        # Issues a GET with the common headers set, absorbing any cookies
        # from the response into the jar before returning it.
        #
        # @param http [Net::HTTP] open connection to BASE_HOST
        # @param jar [CookieJar] session cookie jar, mutated in place
        # @param path [String] request path
        # @return [Net::HTTPResponse]
        # @api private
        def self.get(http, jar, path)
          request = Net::HTTP::Get.new(path)
          set_common_headers(request, jar)
          response = http.request(request)
          jar.absorb(response)
          response
        end

        # User-Agent is required on every request -- see USER_AGENT.
        #
        # @param request [Net::HTTPRequest] request to set headers on, mutated in place
        # @param jar [CookieJar] session cookie jar
        # @return [void]
        # @api private
        def self.set_common_headers(request, jar)
          request["User-Agent"] = USER_AGENT
          cookie = jar.header
          request["Cookie"] = cookie if cookie
        end
      end
    end
  end
end
