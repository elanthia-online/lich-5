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
end
