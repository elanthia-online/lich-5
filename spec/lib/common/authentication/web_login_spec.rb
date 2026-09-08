# frozen_string_literal: true

# NOTE: This spec intentionally does NOT require spec_helper. It tests the
# Web login fallback in isolation, stubbing Net::HTTP so no real network
# calls are made. The request/response fixtures below (paths, form bodies,
# HTML markup, redirect chains) are taken verbatim from a live capture
# against play.net -- see docs/web-login-protocol-analysis.md. The module
# itself has also been exercised live end-to-end (DR/DRT/GS3->GS4/GST, plus
# a bad-password failure) as part of building it; these specs are regression
# coverage for that already-verified behavior, not a substitute for it.

require 'rspec'
require_relative '../../../../lib/common/authentication/web_login'

RSpec.describe Lich::Common::Authentication::WebLogin do
  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  def response_double(code: '302', location: nil, set_cookie: [], body: nil)
    instance_double(
      Net::HTTPResponse,
      code: code,
      :[] => location,
      get_fields: set_cookie,
      body: body
    )
  end

  describe '.instance_for' do
    it 'returns the confirmed instance data for a supported game code' do
      instance = described_class.instance_for('DRT')
      expect(instance).to eq(
        family: 'dr', web_game_code: 'DRT', character_list_path: '/dr/play/playdrt.asp',
        expected_host: 'hydra.simutronics.com', expected_port: '11624'
      )
    end

    it 'maps GS3 to the web layer\'s own GS4 code (confirmed live mismatch from EAccess)' do
      expect(described_class.instance_for('GS3')[:web_game_code]).to eq('GS4')
    end

    it 'confirms GSF matches the EAccess code directly (unlike GS3->GS4)' do
      expect(described_class.instance_for('GSF')[:web_game_code]).to eq('GSF')
    end

    it 'gives each instance its own character-selection page (a character can exist on one ' \
       'instance of a family without appearing on that family\'s generic home.asp -- confirmed ' \
       'live: a GemStone Shattered-only character does not show up on the GemStone Prime page)' do
      expect(described_class.instance_for('GS3')[:character_list_path]).to eq('/gs4/play/home.asp')
      expect(described_class.instance_for('GST')[:character_list_path]).to eq('/gs4/play/play_test.asp')
      expect(described_class.instance_for('GSF')[:character_list_path]).to eq('/gs4/play/playf.asp')
    end

    it 'raises UNSUPPORTED_GAME_CODE for a game code not in the table at all (fail closed)' do
      %w[GSX ZZ].each do |code|
        expect { described_class.instance_for(code) }
          .to raise_error(described_class::AuthenticationError, /UNSUPPORTED_GAME_CODE/), "expected #{code} to be rejected"
      end
    end

    it 'accepts DRX/DRF (unverified -- no live account entitlement to confirm host/port yet) with nil expected_host/expected_port' do
      %w[DRX DRF].each do |code|
        instance = described_class.instance_for(code)
        expect(instance[:expected_host]).to be_nil
        expect(instance[:expected_port]).to be_nil
        expect(instance[:family]).to eq('dr')
      end
    end
  end

  describe '.auth' do
    let(:login_requests) { [] }
    let(:goplay2_requests) { [] }

    let(:preflight_response) { response_double(code: '200', set_cookie: ['ASPSESSIONID=abc123; secure; path=/; HttpOnly']) }
    let(:login_okay_response) { response_double(location: '/dr/play/home.asp', set_cookie: ['AWSALB=xyz; Path=/']) }
    # Real markup captured live from /dr/play/playdrt.asp (DRT's
    # character_list_path) -- see protocol doc "1a".
    let(:home_page_body) do
      <<~HTML
        <input type=radio name="charID" id="W_TESTACCOUNT_000" value="W_TESTACCOUNT_000" checked  >
        <label for="W_TESTACCOUNT_000"><span class="normS1">Raiyen</span></label><br>
      HTML
    end
    let(:home_page_response) { response_double(code: '200', body: home_page_body) }
    let(:goplay2_response) { response_double(location: '/dr/play/playing_web.asp') }
    let(:redirect1_response) { response_double(location: '/includes/common/play/goplay_web.asp') }
    let(:redirect2_response) do
      response_double(location: 'https://www.play.net/play/home.asp?host=hydra.simutronics.com&port=11624&key=abc123')
    end

    before do
      allow(http).to receive(:request) do |req|
        case req.path
        when '/dr/signin_needed.asp' then preflight_response
        when '/includes/common/login/login.asp'
          login_requests << req
          login_okay_response
        when '/dr/play/playdrt.asp' then home_page_response # DRT's character_list_path, not the family's generic home.asp
        when '/dr/play/playx.asp' then home_page_response # DRX's character_list_path (unverified instance)
        when '/dr/play/playf.asp' then home_page_response # DRF's character_list_path (unverified instance)
        when '/includes/common/play/goplay2.asp'
          goplay2_requests << req
          goplay2_response
        when '/dr/play/playing_web.asp' then redirect1_response
        when '/includes/common/play/goplay_web.asp' then redirect2_response
        else raise "unstubbed request to #{req.path}"
        end
      end
    end

    it 'returns the confirmed host/port/key plus synthesized STORM/Wrayth launch fields' do
      result = described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')

      expect(result).to eq(
        'gamehost'     => 'hydra.simutronics.com',
        'gameport'     => '11624',
        'key'          => 'abc123',
        'game'         => 'STORM',
        'gamecode'     => 'DRT',
        'fullgamename' => 'Wrayth',
        'gamefile'     => 'WRAYTH.EXE'
      )
    end

    it 'matches the character by display name case-insensitively' do
      result = described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'raiyen', game_code: 'DRT')
      expect(result['gamehost']).to eq('hydra.simutronics.com')
    end

    it 'GETs the sign-in page before POSTing credentials (login.asp cold gets a bare 500 -- see protocol doc)' do
      described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
      expect(http).to have_received(:request).with(an_object_having_attributes(path: '/dr/signin_needed.asp')).ordered
    end

    it 'includes NEWCHARSUB=TRUE on the goplay2.asp POST (present in every confirmed capture but GS Test\'s)' do
      described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
      expect(goplay2_requests.first.body).to include('NEWCHARSUB=TRUE')
    end

    it 'raises for an unsupported game code without making any request' do
      expect {
        described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'GSX')
      }.to raise_error(described_class::AuthenticationError, /UNSUPPORTED_GAME_CODE/)
      expect(http).not_to have_received(:request)
    end

    context 'when login redirects to the account security-question setup gate instead of okay_page' do
      # Confirmed live: an account that has never set a security question is
      # redirected to /playdotnet/account/security_qa.asp on an otherwise-
      # successful login. The session is already authenticated at that point
      # (Set-Cookie already carries the real session) -- this must not be
      # treated as a login failure.
      let(:login_okay_response) { response_double(location: '/playdotnet/account/security_qa.asp') }

      it 'does not raise, and resolve_char_code proceeds using the already-authenticated session' do
        result = described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        expect(result['gamehost']).to eq('hydra.simutronics.com')
      end
    end

    context 'when the requested character is not on the scraped page' do
      it 'raises CHARACTER_NOT_FOUND' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'NoSuchChar', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /CHARACTER_NOT_FOUND/)
      end
    end

    context 'when the account has no active subscription on the requested instance' do
      # Confirmed live: login.asp's own redirect still lands on okay_page
      # successfully (login() does not raise), but okay_page ITSELF then
      # redirects a second time to subscription_needed.asp -- `get` doesn't
      # follow that second redirect, so without this check it would
      # silently fall through to an empty body scrape and a misleading
      # CHARACTER_NOT_FOUND instead of the real cause.
      let(:home_page_response) { response_double(location: '/dr/play/subscription_needed.asp') }

      it 'raises NO_SUBSCRIPTION rather than a misleading CHARACTER_NOT_FOUND' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /NO_SUBSCRIPTION/)
      end
    end

    context 'when the account has no subscription on an instance with its own named subscription page' do
      # Confirmed live: DR's is plain "subscription_needed.asp", but DRX's
      # (Platinum) is "subscription_to_plat_needed.asp" and DRF's (Fallen) is
      # "subscription_to_fall_needed.asp" -- matched by pattern, not an exact
      # string, so these instance-specific variants are still recognized.
      let(:home_page_response) { response_double(location: '/dr/play/subscription_to_plat_needed.asp') }

      it 'raises NO_SUBSCRIPTION for the Platinum-specific redirect too' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRX')
        }.to raise_error(described_class::AuthenticationError, /NO_SUBSCRIPTION/)
      end
    end

    context 'when the character-list page redirects somewhere other than subscription_needed.asp' do
      let(:home_page_response) { response_double(location: '/dr/some_other_redirect.asp') }

      it 'raises UNEXPECTED_CHARACTER_LIST_RESPONSE' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /UNEXPECTED_CHARACTER_LIST_RESPONSE/)
      end
    end

    context 'when the character-list page returns a non-3xx HTTP error (e.g. a transient 503)' do
      # A 4xx/5xx must NOT fall through to the body scraper: an empty/error
      # body scrapes to no match, which would otherwise raise the same
      # CHARACTER_NOT_FOUND a real "no such character" case raises --
      # and Authenticator treats CHARACTER_NOT_FOUND as fatal (no retry),
      # silently discarding what may well have been a transient, retryable
      # server error.
      let(:home_page_response) { response_double(code: '503', location: nil, body: 'Temporarily unavailable') }

      it 'raises UNEXPECTED_CHARACTER_LIST_RESPONSE rather than a fatal CHARACTER_NOT_FOUND' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /UNEXPECTED_CHARACTER_LIST_RESPONSE/)
      end
    end

    context 'when login redirects to the error page (bad password on a real account)' do
      let(:login_okay_response) { response_double(location: '/dr/login_error.asp?error=&returnto=/dr/') }

      it 'raises LOGIN_FAILED without attempting character resolution' do
        expect {
          described_class.auth(password: 'wrong', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /LOGIN_FAILED/)
        expect(http).to have_received(:request).twice # preflight + login POST only
      end
    end

    context 'when login redirects to the error page (nonexistent account name)' do
      # Confirmed live with a random fictitious account name (e.g.
      # "SDLG3kDSKk38"): distinct body heading ("Invalid account." vs
      # "Invalid password.") but the same login_error.asp redirect target --
      # classified identically as LOGIN_FAILED. Matters in practice for a
      # stale/mistyped saved account name: fails fast and fatally, same as a
      # bad password, rather than hanging or producing an unclear error.
      let(:login_okay_response) { response_double(location: '/dr/login_error.asp?error=&returnto=/dr/play/home.asp') }

      it 'raises LOGIN_FAILED, identically to a bad password' do
        expect {
          described_class.auth(password: 'RandomFakePassword123!', account: 'SDLG3kDSKk38', character: 'Whoever', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /LOGIN_FAILED/)
        expect(http).to have_received(:request).twice # preflight + login POST only
      end
    end

    context 'when login redirects to an absolute URL on the error page path (not just a relative one)' do
      let(:login_okay_response) { response_double(location: 'https://www.play.net/dr/login_error.asp?error=1') }

      it 'still classifies it as LOGIN_FAILED by comparing the parsed path, not a raw prefix match' do
        expect {
          described_class.auth(password: 'wrong', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /LOGIN_FAILED/)
      end
    end

    context 'when login redirects to an unrelated page that merely shares the error page as a string prefix' do
      let(:login_okay_response) { response_double(location: '/dr/login_error.aspSOMETHINGELSE') }

      it 'does NOT misclassify it as LOGIN_FAILED (path comparison, not prefix match)' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /UNEXPECTED_LOGIN_RESPONSE/)
      end
    end

    context 'when login redirects somewhere unexpected' do
      let(:login_okay_response) { response_double(location: '/dr/some_other_page.asp') }

      it 'raises UNEXPECTED_LOGIN_RESPONSE' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /UNEXPECTED_LOGIN_RESPONSE/)
      end
    end

    context 'when the login response is not a redirect at all (no Location, or non-3xx)' do
      let(:login_okay_response) { response_double(code: '200', location: nil) }

      it 'raises UNEXPECTED_NON_REDIRECT_RESPONSE rather than treating a blank location as a path' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /UNEXPECTED_NON_REDIRECT_RESPONSE/)
      end
    end

    context 'when the final redirect points off www.play.net' do
      let(:redirect2_response) do
        response_double(location: 'https://attacker.example/play/home.asp?host=evil.example&port=1&key=x')
      end

      it 'raises UNTRUSTED_REDIRECT_HOST rather than trusting the connection info' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /UNTRUSTED_REDIRECT_HOST/)
      end
    end

    context 'when the final redirect downgrades to plain http' do
      let(:redirect2_response) do
        response_double(location: 'http://www.play.net/play/home.asp?host=h&port=1&key=x')
      end

      it 'raises rather than following a non-https redirect' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /UNTRUSTED_REDIRECT_HOST/)
      end
    end

    context 'when the final redirect carries userinfo, a non-default port, and the wrong path' do
      let(:redirect2_response) do
        response_double(location: 'https://user@www.play.net:444/not-the-launch-page?host=&port=&key=')
      end

      it 'raises UNTRUSTED_REDIRECT_HOST' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /UNTRUSTED_REDIRECT_HOST/)
      end
    end

    context 'when the final redirect has a duplicate query key' do
      let(:redirect2_response) do
        response_double(location: 'https://www.play.net/play/home.asp?host=hydra.simutronics.com&port=11624&key=abc123&key=evil')
      end

      it 'raises DUPLICATE_QUERY_PARAM rather than silently taking one of the two key values' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /DUPLICATE_QUERY_PARAM/)
      end
    end

    context 'when the final redirect has a blank connection value' do
      let(:redirect2_response) do
        response_double(location: 'https://www.play.net/play/home.asp?host=hydra.simutronics.com&port=&key=abc123')
      end

      it 'raises NO_CONNECTION_INFO' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /NO_CONNECTION_INFO/)
      end
    end

    context 'when the returned host/port do not match the requested instance\'s confirmed values' do
      let(:redirect2_response) do
        response_double(location: 'https://www.play.net/play/home.asp?host=unexpected.example&port=1&key=abc123')
      end

      it 'raises UNEXPECTED_CONNECTION_INFO rather than trusting arbitrary connection data' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /UNEXPECTED_CONNECTION_INFO/)
      end
    end

    context 'for an unverified instance (DRX/DRF -- no live account entitlement to confirm host/port yet)' do
      context 'when the returned host is a recognized Simutronics game-server domain' do
        let(:redirect2_response) do
          response_double(location: 'https://www.play.net/play/home.asp?host=storm.dr.game.play.net&port=11324&key=abc123')
        end

        it 'accepts it and logs the observed host/port for later promotion into CONFIRMED_INSTANCES' do
          allow(Lich).to receive(:log)

          result = described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRX')

          expect(result['gamehost']).to eq('storm.dr.game.play.net')
          expect(result['gameport']).to eq('11324')
          expect(Lich).to have_received(:log).with(/DRX has no pinned host\/port yet.*observed host=storm\.dr\.game\.play\.net port=11324/)
        end
      end

      context 'when the returned host is NOT a recognized Simutronics game-server domain' do
        let(:redirect2_response) do
          response_double(location: 'https://www.play.net/play/home.asp?host=attacker.example&port=1&key=abc123')
        end

        it 'raises UNTRUSTED_CONNECTION_HOST rather than trusting an unverified instance\'s connection data blindly' do
          expect {
            described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRF')
          }.to raise_error(described_class::AuthenticationError, /UNTRUSTED_CONNECTION_HOST/)
        end
      end
    end

    context 'when a redirect never resolves to an absolute URL' do
      let(:redirect2_response) { response_double(location: '/includes/common/play/goplay_web.asp') } # loops back on itself

      it 'raises TOO_MANY_REDIRECTS rather than looping forever' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /TOO_MANY_REDIRECTS/)
      end
    end

    context 'when a mid-chain relative redirect Location is malformed' do
      # redirect_path(..., full_url: true) used to return the raw Location
      # before ever calling URI.parse, so a malformed relative Location was
      # handed to `get` unvalidated instead of raising MALFORMED_REDIRECT_URL
      # here. A literal space is invalid in a URI (confirmed:
      # URI.parse("/invalid path") raises URI::InvalidURIError).
      let(:goplay2_response) { response_double(location: '/invalid path') }

      it 'raises MALFORMED_REDIRECT_URL rather than requesting the malformed path unvalidated' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /MALFORMED_REDIRECT_URL/)
      end
    end
  end

  describe described_class::CookieJar do
    it 'returns nil when nothing has been absorbed yet' do
      expect(subject.header).to be_nil
    end

    it 'keeps the newer value for a cookie absorbed twice, but keeps other cookies' do
      subject.absorb(response_double(set_cookie: ['A=1; Path=/', 'B=2; Path=/']))
      subject.absorb(response_double(set_cookie: ['B=3; Path=/']))
      expect(subject.header).to eq('A=1; B=3')
    end

    it 'ignores a response with no Set-Cookie headers' do
      subject.absorb(response_double(set_cookie: ['A=1']))
      subject.absorb(response_double(set_cookie: []))
      expect(subject.header).to eq('A=1')
    end
  end

  describe '.auth_with_timeout' do
    it 'raises when the exchange exceeds the timeout' do
      allow(described_class).to receive(:auth) { sleep 0.2 }
      expect {
        described_class.auth_with_timeout(timeout: 0.01, password: 'pw', account: 'A', character: 'C', game_code: 'DRT')
      }.to raise_error(/timed out authenticating with web login/)
    end

    it 'returns the result of .auth on success' do
      allow(described_class).to receive(:auth).and_return('key' => 'k')
      result = described_class.auth_with_timeout(password: 'pw', account: 'A', character: 'C', game_code: 'DRT')
      expect(result).to eq('key' => 'k')
    end
  end
end
