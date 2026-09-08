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
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:verify_mode=)
  end

  def response_double(location: nil, set_cookie: [], body: nil)
    instance_double(
      Net::HTTPResponse,
      :[] => location,
      get_fields: set_cookie,
      body: body
    )
  end

  describe '.web_game_code' do
    it 'maps GS3 to GS4 (confirmed live mismatch from EAccess)' do
      expect(described_class.web_game_code('GS3')).to eq('GS4')
    end

    it 'passes through codes confirmed identical to EAccess' do
      expect(described_class.web_game_code('DR')).to eq('DR')
      expect(described_class.web_game_code('DRT')).to eq('DRT')
      expect(described_class.web_game_code('GST')).to eq('GST')
    end
  end

  describe '.game_family' do
    it 'maps DR-family codes to "dr"' do
      %w[DR DRT DRF DRX].each { |code| expect(described_class.game_family(code)).to eq('dr') }
    end

    it 'maps GS-family codes to "gs4"' do
      %w[GS3 GST GSF GSX].each { |code| expect(described_class.game_family(code)).to eq('gs4') }
    end

    it 'raises for an unknown game code' do
      expect { described_class.game_family('ZZ') }.to raise_error(described_class::AuthenticationError, /UNKNOWN_GAME_CODE/)
    end
  end

  describe '.auth' do
    let(:preflight_response) { response_double(set_cookie: ['ASPSESSIONID=abc123; secure; path=/; HttpOnly']) }
    let(:login_okay_response) { response_double(location: '/dr/play/home.asp', set_cookie: ['AWSALB=xyz; Path=/']) }
    # Real markup captured live from /dr/play/home.asp -- see protocol doc "1a".
    let(:home_page_body) do
      <<~HTML
        <input type=radio name="charID" id="W_TESTACCOUNT_000" value="W_TESTACCOUNT_000" checked  >
        <label for="W_TESTACCOUNT_000"><span class="normS1">Raiyen</span></label><br>
      HTML
    end
    let(:home_page_response) { response_double(body: home_page_body) }
    let(:goplay2_response) { response_double(location: '/dr/play/playing_web.asp') }
    let(:redirect1_response) { response_double(location: '/includes/common/play/goplay_web.asp') }
    let(:redirect2_response) do
      response_double(location: 'https://www.play.net/play/home.asp?host=hydra.simutronics.com&port=11624&key=abc123')
    end

    before do
      allow(http).to receive(:request).and_return(
        preflight_response, login_okay_response, home_page_response,
        goplay2_response, redirect1_response, redirect2_response
      )
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

    context 'when the requested character is not on the scraped page' do
      it 'raises CHARACTER_NOT_FOUND' do
        expect {
          described_class.auth(password: 'pw', account: 'TESTACCOUNT', character: 'NoSuchChar', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /CHARACTER_NOT_FOUND/)
      end
    end

    context 'when login redirects to the error page' do
      let(:login_okay_response) { response_double(location: '/dr/login_error.asp?error=&returnto=/dr/') }

      it 'raises LOGIN_FAILED without attempting character resolution' do
        expect {
          described_class.auth(password: 'wrong', account: 'TESTACCOUNT', character: 'Raiyen', game_code: 'DRT')
        }.to raise_error(described_class::AuthenticationError, /LOGIN_FAILED/)
        expect(http).to have_received(:request).twice # preflight + login POST only
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
        }.to raise_error(described_class::AuthenticationError)
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
      allow(described_class).to receive(:auth).and_return({ 'gamehost' => 'h' })
      result = described_class.auth_with_timeout(password: 'pw', account: 'A', character: 'C', game_code: 'DRT')
      expect(result).to eq({ 'gamehost' => 'h' })
    end
  end
end
