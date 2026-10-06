# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::GitHubClient do
  describe '#initialize' do
    it 'starts with empty cache' do
      client = described_class.new
      expect(client.http_cache).to eq({})
    end
  end

  describe '#fetch_github_json cache serves fresh entries without re-fetching' do
    it 'returns cached data for requests within TTL' do
      client = described_class.new(cache_ttl: 300)
      url = 'https://api.github.com/repos/test/tree'
      json_body = '{"tree": [{"path": "foo.lic"}]}'

      call_count = 0
      allow(client).to receive(:http_get).with(url) do
        call_count += 1
        json_body
      end

      result1 = client.fetch_github_json(url)
      result2 = client.fetch_github_json(url)

      expect(call_count).to eq(1)
      expect(result1).to eq(result2)
      expect(result1['tree'].first['path']).to eq('foo.lic')
    end
  end

  describe '#fetch_github_json cache expires entries after TTL' do
    it 're-fetches when entry exceeds TTL' do
      client = described_class.new(cache_ttl: 0)
      url = 'https://api.github.com/repos/test/tree'

      call_count = 0
      allow(client).to receive(:http_get).with(url) do
        call_count += 1
        '{"version": ' + call_count.to_s + '}'
      end

      result1 = client.fetch_github_json(url)
      sleep 0.01
      result2 = client.fetch_github_json(url)

      expect(call_count).to eq(2)
      expect(result1['version']).to eq(1)
      expect(result2['version']).to eq(2)
    end
  end

  describe '#fetch_github_json cache does not store failed requests' do
    it 'retries after a network failure' do
      client = described_class.new(cache_ttl: 300)
      url = 'https://api.github.com/repos/test/tree'

      call_count = 0
      allow(client).to receive(:http_get).with(url) do
        call_count += 1
        call_count == 1 ? nil : '{"ok": true}'
      end

      result1 = client.fetch_github_json(url)
      result2 = client.fetch_github_json(url)

      expect(result1).to be_nil
      expect(result2).to eq({ 'ok' => true })
      expect(call_count).to eq(2)
    end
  end

  # Drives the real http_get through a fake Net::HTTP so classification,
  # the anonymous retry, and silence on failure are all exercised.
  describe '#http_get failure handling' do
    let(:data_dir) { Dir.mktmpdir('gh-client') }
    let(:client) { described_class.new }
    let(:url) { 'https://api.github.com/repos/elanthia-online/scripts/git/trees/master' }
    let(:sent) { [] }
    let(:printed) { [] }
    let(:logged) { [] }

    def response(code, body: '', headers: {})
      res = Net::HTTPResponse::CODE_TO_OBJ[code.to_s].new('1.1', code.to_s, 'msg')
      headers.each { |k, v| res[k] = v }
      res.instance_variable_set(:@body, body)
      res.instance_variable_set(:@read, true)
      res
    end

    # Each request pops the next response; raises when one is an exception.
    def serve(*responses)
      http = double('Net::HTTP', 'use_ssl=': nil, 'verify_mode=': nil)
      allow(http).to receive(:request) do |req|
        sent << req['Authorization']
        nxt = responses.shift
        raise nxt if nxt.is_a?(Exception)

        nxt
      end
      allow(Net::HTTP).to receive(:new).and_return(http)
    end

    def write_token(token)
      File.write(File.join(data_dir, 'githubtoken.txt'), token)
    end

    before do
      stub_const('DATA_DIR', data_dir)
      allow(client).to receive(:respond) { |msg = ''| printed << msg }
      allow(Lich).to receive(:log) { |msg| logged << msg }
    end

    after { FileUtils.remove_entry(data_dir, true) }

    it 'classifies a 401 without a token as a temporary outage, prints nothing, and does not retry' do
      serve(response(401, body: '{"message":"Requires authentication"}'))

      expect(client.http_get(url)).to be_nil
      expect(client.last_error.kind).to eq(:unavailable)
      expect(client.last_error.status).to eq(401)
      expect(client.last_error.global?).to be(true)
      expect(sent).to eq([nil])
      expect(printed).to be_empty
      expect(logged.join).to include('HTTP 401 fetching /repos/elanthia-online/scripts/git/trees/master')
    end

    it 'retries anonymously when GitHub rejects the token, succeeds, and tells the user once' do
      write_token('ghp_stale')
      serve(response(401), response(200, body: 'ok'), response(200, body: 'again'))

      expect(client.http_get(url)).to eq('ok')
      expect(client.last_error).to be_nil
      expect(client.http_get(url)).to eq('again')

      expect(sent).to eq(['Bearer ghp_stale', nil, nil])
      expect(printed.length).to eq(1)
      expect(printed.first).to include('rejected the token', 'githubtoken.txt', 'Replace or delete')
    end

    it 'reports the anonymous retry result when both attempts fail, without the token notice' do
      write_token('ghp_stale')
      serve(response(401), response(503))

      expect(client.http_get(url)).to be_nil
      expect(client.last_error.kind).to eq(:unavailable)
      expect(client.last_error.status).to eq(503)
      expect(printed).to be_empty
    end

    it 'does not retry a non-401 failure when a token was sent' do
      write_token('ghp_good')
      serve(response(500))

      client.http_get(url)
      expect(sent).to eq(['Bearer ghp_good'])
    end

    it 'never sends a token or retries for auth: false requests' do
      write_token('ghp_good')
      serve(response(401))

      client.http_get(url, auth: false)
      expect(sent).to eq([nil])
      expect(printed).to be_empty
    end

    it 'reads the reset time from x-ratelimit-reset when the limit is exhausted' do
      reset = Time.now.to_i + 1800
      serve(response(403, headers: { 'x-ratelimit-remaining' => '0', 'x-ratelimit-reset' => reset.to_s }))

      client.http_get(url)
      expect(client.last_error.kind).to eq(:rate_limited)
      expect(client.last_error.reset_at.to_i).to eq(reset)
    end

    it 'reads the reset time from retry-after on a 429' do
      serve(response(429, headers: { 'retry-after' => '60' }))

      client.http_get(url)
      expect(client.last_error.kind).to eq(:rate_limited)
      expect(client.last_error.reset_at).to be_within(5).of(Time.now + 60)
    end

    it 'leaves reset_at nil on a 403 without rate-limit headers' do
      serve(response(403, headers: { 'x-ratelimit-remaining' => '12', 'x-ratelimit-reset' => '1' }))

      client.http_get(url)
      expect(client.last_error.kind).to eq(:rate_limited)
      expect(client.last_error.reset_at).to be_nil
    end

    it 'classifies a 404 as not_found, which is not GitHub-wide' do
      serve(response(404))

      client.http_get(url)
      expect(client.last_error.kind).to eq(:not_found)
      expect(client.last_error.global?).to be(false)
    end

    it 'classifies a connection failure as a network error and prints nothing' do
      serve(Net::OpenTimeout.new('execution expired'))

      expect(client.http_get(url)).to be_nil
      expect(client.last_error.kind).to eq(:network)
      expect(printed).to be_empty
      expect(logged.join).to include('Net::OpenTimeout')
    end

    it 'clears last_error after a later success' do
      serve(response(502), response(200, body: 'ok'))

      client.http_get(url)
      expect(client.last_error).not_to be_nil
      client.http_get(url)
      expect(client.last_error).to be_nil
    end
  end

  describe '#fetch_github_json failure handling' do
    let(:client) { described_class.new(cache_ttl: 300) }
    let(:url) { 'https://api.github.com/repos/test/tree' }

    before { allow(client).to receive(:respond) { |msg = ''| raise "unexpected print: #{msg}" } }

    it 'classifies an unparseable body as bad_response without printing' do
      allow(client).to receive(:http_get).with(url).and_return('<html>Unicorn!</html>')

      expect(client.fetch_github_json(url)).to be_nil
      expect(client.last_error.kind).to eq(:bad_response)
    end

    it 'clears a stale last_error on a cache hit' do
      other = 'https://api.github.com/repos/test/other'
      allow(client).to receive(:http_get).with(url).and_return('{"ok":true}')
      allow(client).to receive(:http_get).with(other).and_return('not json')

      client.fetch_github_json(url)
      client.fetch_github_json(other)
      expect(client.last_error).not_to be_nil

      expect(client.fetch_github_json(url)).to eq({ 'ok' => true })
      expect(client.last_error).to be_nil
    end
  end
end
