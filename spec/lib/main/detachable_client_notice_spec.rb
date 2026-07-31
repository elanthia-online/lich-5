# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/detachable_client_notice'

RSpec.describe Lich::Main::DetachableClientNotice do
  describe '.address' do
    it 'joins an IPv4 host and port' do
      expect(described_class.address('127.0.0.1', 8000)).to eq('127.0.0.1:8000')
    end

    it 'brackets an IPv6 literal' do
      expect(described_class.address('::1', 8000)).to eq('[::1]:8000')
    end

    it 'leaves an already-bracketed IPv6 host untouched' do
      expect(described_class.address('[::1]', 8000)).to eq('[::1]:8000')
    end

    it 'joins a hostname and port' do
      expect(described_class.address('mypc.tailnet.ts.net', 8000)).to eq('mypc.tailnet.ts.net:8000')
    end

    it 'renders a nil host as an empty host' do
      expect(described_class.address(nil, 8000)).to eq(':8000')
    end
  end

  describe '.listening' do
    it 'formats the listening notice' do
      expect(described_class.listening(host: '127.0.0.1', port: 8000))
        .to eq('--- Lich: detachable client listening on 127.0.0.1:8000')
    end

    it 'brackets an IPv6 endpoint' do
      expect(described_class.listening(host: '::1', port: 8000))
        .to eq('--- Lich: detachable client listening on [::1]:8000')
    end
  end

  describe '.disconnected' do
    it 'includes the session name, endpoint, and remaining attached count' do
      expect(described_class.disconnected(name: 'Mahtra', host: '127.0.0.1', port: 8000, attached: 0))
        .to eq('--- Lich: detachable client Mahtra disconnected from 127.0.0.1:8000 (0 attached)')
    end

    it 'reports remaining clients when more than one was attached' do
      expect(described_class.disconnected(name: 'Mahtra', host: '127.0.0.1', port: 8000, attached: 2))
        .to eq('--- Lich: detachable client Mahtra disconnected from 127.0.0.1:8000 (2 attached)')
    end

    it 'omits the name when it is nil' do
      expect(described_class.disconnected(name: nil, host: '127.0.0.1', port: 8000, attached: 0))
        .to eq('--- Lich: detachable client disconnected from 127.0.0.1:8000 (0 attached)')
    end

    it 'omits the name when it is blank' do
      expect(described_class.disconnected(name: '', host: '127.0.0.1', port: 8000, attached: 0))
        .to eq('--- Lich: detachable client disconnected from 127.0.0.1:8000 (0 attached)')
    end

    it 'brackets an IPv6 endpoint' do
      expect(described_class.disconnected(name: 'Mahtra', host: '::1', port: 8000, attached: 0))
        .to eq('--- Lich: detachable client Mahtra disconnected from [::1]:8000 (0 attached)')
    end
  end
end
