# frozen_string_literal: true

require 'tmpdir'
require_relative '../../.github/scripts/check_r4l5_contract'

RSpec.describe Lich::ContractDocument do
  it 'reads offline documents without network access' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'manifest.json')
      File.binwrite(path, 'offline bytes')
      expect(Net::HTTP).not_to receive(:start)
      expect(described_class.read(path)).to eq('offline bytes')
    end
  end

  it 'rejects oversized offline documents' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'large.json')
      File.binwrite(path, 'x' * (described_class::LIMIT + 1))
      expect { described_class.read(path) }.to raise_error(Lich::RuntimeGemContract::Error, /size limit/)
    end
  end

  it 'rejects credential-bearing HTTPS URLs before making a request' do
    expect(Net::HTTP).not_to receive(:start)
    expect { described_class.read('https://name:password@example.org/manifest') }.to raise_error(Lich::RuntimeGemContract::Error, /without credentials/)
  end

  it 'refuses downgrade redirects' do
    response = Net::HTTPFound.new('1.1', '302', 'Found')
    response['location'] = 'http://example.org/insecure'
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_yield(response)
    expect { described_class.read('https://example.org/manifest') }.to raise_error(Lich::RuntimeGemContract::Error, /redirect must use HTTPS/)
  end

  it 'caps redirect depth' do
    response = Net::HTTPFound.new('1.1', '302', 'Found')
    response['location'] = 'https://example.org/again'
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_yield(response)
    expect { described_class.read('https://example.org/manifest', redirects: 0) }.to raise_error(Lich::RuntimeGemContract::Error, /too many/)
  end

  it 'fails closed for unavailable documents' do
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_yield(Net::HTTPNotFound.new('1.1', '404', 'Not Found'))
    expect { described_class.read('https://example.org/manifest') }.to raise_error(Lich::RuntimeGemContract::Error, /HTTP 404/)
  end

  ['', [239, 187, 191].pack('C*')].each do |prefix|
    it "decodes offline JSON with #{prefix.empty? ? 'no BOM' : 'a BOM'} without changing raw bytes" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'provenance.json')
        bytes = prefix + '{"value":1}'.b
        File.binwrite(path, bytes)
        expect(described_class.read_json(path)).to eq('value' => 1)
        expect(described_class.read(path)).to eq(bytes)
        File.binwrite(path, prefix + '{invalid'.b)
        expect { described_class.read_json(path) }.to raise_error(JSON::ParserError)
      end
    end

    it "decodes HTTPS JSON with #{prefix.empty? ? 'no BOM' : 'a BOM'} without changing raw bytes" do
      bytes = prefix + '{"value":1}'.b
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request).and_yield(response)
      allow(response).to receive(:read_body) { |&block| block.call(bytes) }
      expect(described_class.read_json('https://example.org/provenance')).to eq('value' => 1)
      expect(described_class.read('https://example.org/provenance')).to eq(bytes)
      bytes = prefix + '{invalid'.b
      expect { described_class.read_json('https://example.org/provenance') }.to raise_error(JSON::ParserError)
    end
  end
end
