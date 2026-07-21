# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/bind_address_option'

RSpec.describe Lich::Main::BindAddressOption do
  def resolution(host:, warning: nil)
    Lich::Common::BindHostResolver::Resolution.new(host: host, warning: warning)
  end

  def resolver_returning(host:, warning: nil)
    resolver = double('BindHostResolver')
    allow(resolver).to receive(:resolve).and_return(resolution(host: host, warning: warning))
    resolver
  end

  it 'is a no-op when --bind-address was not given' do
    result = described_class.apply(nil)

    expect(result.host).to be_nil
    expect(result.warning).to be_nil
    expect(result.error).to be_nil
  end

  it 'resolves keyword tokens to a concrete address' do
    resolver = resolver_returning(host: '100.101.102.103')

    result = described_class.apply('tailscale', resolver: resolver)

    expect(resolver).to have_received(:resolve).with('tailscale')
    expect(result.host).to eq('100.101.102.103')
    expect(result.warning).to be_nil
    expect(result.error).to be_nil
  end

  it 'carries the resolver warning for exposed bindings' do
    resolver = resolver_returning(host: '192.168.1.20', warning: 'exposed')

    result = described_class.apply('lan', resolver: resolver)

    expect(result.host).to eq('192.168.1.20')
    expect(result.warning).to eq('exposed')
  end

  it 'turns resolver failures into an error result instead of raising' do
    resolver = double('BindHostResolver')
    allow(resolver).to receive(:resolve)
      .and_raise(Lich::Common::BindHostResolver::Error, 'no tailscale here')

    result = described_class.apply('tailscale', resolver: resolver)

    expect(result.host).to be_nil
    expect(result.error).to eq('no tailscale here')
  end

  describe 'through the real resolver' do
    it 'passes explicit private addresses through untouched and unwarned' do
      result = described_class.apply('127.0.0.1')

      expect(result.host).to eq('127.0.0.1')
      expect(result.warning).to be_nil
      expect(result.error).to be_nil
    end

    it 'resolves any to the wildcard with the exposure warning' do
      result = described_class.apply('any')

      expect(result.host).to eq('0.0.0.0')
      expect(result.warning).to match(/every network/)
    end
  end
end
