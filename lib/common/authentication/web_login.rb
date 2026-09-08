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
      # what remains unconfirmed (GS4/DR Fallen/Platinum/Shattered instance
      # codes, full error vocabulary, HTML-scrape fragility).
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
          def absorb(response)
            response.get_fields("set-cookie").to_a.each do |raw|
              name, value = raw.split(";", 2).first.to_s.split("=", 2)
              @pairs[name] = value if name && !name.empty?
            end
            self
          end

          # Cookie header value for the next request, or nil if empty.
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

        # Game family per instance code, used to build the correct /{family}/... paths.
        GAME_FAMILY = {
          "DR" => "dr", "DRT" => "dr", "DRF" => "dr", "DRX" => "dr",
          "GS3" => "gs4", "GST" => "gs4", "GSF" => "gs4", "GSX" => "gs4"
        }.freeze

        # The web login flow's own `game` form value, which is NOT always the
        # same as the EAccess game_code -- confirmed live mismatch: GemStone
        # Prime is "GS4" here vs "GS3" over EAccess. Only DR, DRT, GS3(->GS4),
        # and GST are confirmed live; DRF/DRX/GSF/GSX are unconfirmed and
        # assumed unchanged from the EAccess code pending verification (see
        # docs/web-login-protocol-analysis.md).
        WEB_GAME_CODE = {
          "GS3" => "GS4"
        }.freeze

        # @api private
        def self.web_game_code(game_code)
          WEB_GAME_CODE.fetch(game_code, game_code)
        end

        # @api private
        def self.game_family(game_code)
          GAME_FAMILY.fetch(game_code) { raise AuthenticationError, "UNKNOWN_GAME_CODE" }
        end

        # Authenticates against play.net's web login flow and resolves a
        # character launch. Does not support EAccess's `legacy` multi-game
        # enumeration mode or the `generator` (character-0) flow -- neither
        # has a confirmed web-flow equivalent yet (see protocol doc).
        #
        # @param password [String] account password (sent as an HTTPS form field, not obfuscated client-side)
        # @param account [String] account name
        # @param character [String] character name to select (resolved to a charID by scraping home.asp)
        # @param game_code [String] EAccess-style game instance code (e.g. "DR", "GS3", "GST")
        # @return [Hash] login info hash: gamehost, gameport, key (confirmed from the server),
        #   plus game/gamecode/fullgamename/gamefile (NOT server-provided by this flow --
        #   synthesized locally to match EAccess's STORM/Wrayth defaults so downstream
        #   LaunchData formatting keeps working; verify these are still correct before
        #   trusting them for a frontend other than Stormfront/Wrayth)
        # @raise [AuthenticationError] on login failure or unresolved character/game code
        def self.auth(password:, account:, character:, game_code:)
          family = game_family(game_code)
          http = Net::HTTP.new(BASE_HOST, 443)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          jar = CookieJar.new

          login(http, jar, account: account, password: password, family: family)
          char_code = resolve_char_code(http, jar, family: family, character: character)
          host, port, key = select_character(http, jar, char_code: char_code, family: family, game_code: game_code)

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

        # @api private
        # Step 0 + 1: GET the family's sign-in page first to establish an ASP
        # session cookie, then POST credentials against that session --
        # confirmed live as required: posting login.asp cold (no prior GET,
        # no session cookie) gets a bare 500 from the server, matching how a
        # real browser always visits signin_needed.asp before submitting the
        # form. Failure is detected by comparing the redirect target against
        # the error page we supplied -- NOT by parsing response body text.
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

          location = response["location"].to_s
          if location.start_with?(error_page)
            raise AuthenticationError, "LOGIN_FAILED"
          end
          unless location.start_with?(okay_page)
            raise AuthenticationError, "UNEXPECTED_LOGIN_RESPONSE"
          end
        end

        # @api private
        # Step 1a: scrape the family's home.asp for the charID matching
        # `character`. See docs/web-login-protocol-analysis.md for the exact
        # markup this depends on and why it's the most fragile part of this
        # module.
        def self.resolve_char_code(http, jar, family:, character:)
          response = get(http, jar, "/#{family}/play/home.asp")
          body = response.body.to_s

          body.scan(/id="(W_[A-Za-z0-9_]+)"[^>]*>\s*<label for="\1"><span[^>]*>([^<]+)<\/span>/).each do |char_code, name|
            return char_code if name.strip.casecmp?(character)
          end

          raise AuthenticationError, "CHARACTER_NOT_FOUND"
        end

        # @api private
        # Steps 2-4: submit the character/instance selection and follow the
        # two redirects to the final host/port/key triple, without ever
        # fetching the web client page itself.
        def self.select_character(http, jar, char_code:, family:, game_code:)
          request = Net::HTTP::Post.new("/includes/common/play/goplay2.asp")
          set_common_headers(request, jar)
          request["Content-Type"] = "application/x-www-form-urlencoded"
          request.body = URI.encode_www_form(
            charID: char_code,
            managesub: 0,
            gameName: family,
            instanceID: 0,
            game: web_game_code(game_code),
            frontend: "web"
          )
          response = http.request(request)
          jar.absorb(response)
          location = follow_redirects(http, jar, response)

          uri = URI.parse(location)
          params = URI.decode_www_form(uri.query.to_s).to_h
          host, port, key = params["host"], params["port"], params["key"]
          raise AuthenticationError, "NO_CONNECTION_INFO" unless host && port && key

          [host, port, key]
        end

        # @api private
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
        # rather than ever being handed to `get` as if it were a path: an
        # off-host or downgraded-to-http redirect (compromised/MITM'd
        # response, unexpected play.net change) must not be trusted, and
        # must not be silently misinterpreted as a relative path either.
        def self.follow_redirects(http, jar, response)
          loop do
            location = response["location"].to_s
            if location =~ %r{\Ahttps?://}i
              uri = URI.parse(location)
              raise AuthenticationError, "UNTRUSTED_REDIRECT_HOST" unless uri.scheme == "https" && uri.host == BASE_HOST

              return location
            end

            response = get(http, jar, location)
          end
        end

        # @api private
        def self.get(http, jar, path)
          request = Net::HTTP::Get.new(path)
          set_common_headers(request, jar)
          response = http.request(request)
          jar.absorb(response)
          response
        end

        # @api private
        # User-Agent is required on every request -- see USER_AGENT.
        def self.set_common_headers(request, jar)
          request["User-Agent"] = USER_AGENT
          cookie = jar.header
          request["Cookie"] = cookie if cookie
        end
      end
    end
  end
end
