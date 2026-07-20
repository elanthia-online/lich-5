# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/arg_normalization'

RSpec.describe Lich::Main::ArgNormalization do
  describe '.normalize!' do
    it 'rewrites headless with an explicit port to detachable headless arguments' do
      argv = ['--login', 'Tsetem', '--headless', '8001']

      described_class.normalize!(argv)

      expect(argv).to eq(['--login', 'Tsetem', '--without-frontend', '--detachable-client=8001'])
    end

    it 'rewrites headless auto to detachable headless with OS-assigned port' do
      argv = ['--login', 'Tsetem', '--headless', 'auto']

      described_class.normalize!(argv)

      expect(argv).to eq(['--login', 'Tsetem', '--without-frontend', '--detachable-client=0'])
    end

    it 'supports inline headless port syntax' do
      argv = ['--login', 'Tsetem', '--headless=9001']

      described_class.normalize!(argv)

      expect(argv).to eq(['--login', 'Tsetem', '--without-frontend', '--detachable-client=9001'])
    end

    it 'rewrites headless with a keyword host and port' do
      argv = ['--login', 'Tsetem', '--headless', 'tailscale:8000']

      described_class.normalize!(argv)

      expect(argv).to eq(['--login', 'Tsetem', '--without-frontend', '--detachable-client=tailscale:8000'])
    end

    it 'rewrites inline headless host with an auto port' do
      argv = ['--login', 'Tsetem', '--headless=lan:auto']

      described_class.normalize!(argv)

      expect(argv).to eq(['--login', 'Tsetem', '--without-frontend', '--detachable-client=lan:0'])
    end

    it 'preserves brackets around IPv6 hosts' do
      argv = ['--login', 'Tsetem', '--headless=[::1]:8000']

      described_class.normalize!(argv)

      expect(argv).to eq(['--login', 'Tsetem', '--without-frontend', '--detachable-client=[::1]:8000'])
    end

    it 'rejects a headless host without a port' do
      argv = ['--login', 'Tsetem', '--headless', 'tailscale']

      expect { described_class.normalize!(argv) }.to raise_error(ArgumentError, /HOST:PORT/)
    end

    it 'rejects bare headless without a port or auto' do
      argv = ['--login', 'Tsetem', '--headless']

      expect { described_class.normalize!(argv) }.to raise_error(ArgumentError, /requires a port number or auto/)
    end

    it 'rejects mixed headless and detachable-client usage' do
      argv = ['--login', 'Tsetem', '--headless', '8001', '--detachable-client=9001']

      expect { described_class.normalize!(argv) }.to raise_error(ArgumentError, /cannot be combined/)
    end

    it 'rejects duplicate headless flags' do
      argv = ['--login', 'Tsetem', '--headless', '8001', '--headless=9001']

      expect { described_class.normalize!(argv) }.to raise_error(ArgumentError, /may only be specified once/)
    end
  end
end
