# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/gui/launch_settings'

RSpec.describe Lich::Common::GUI::LaunchSettings do
  it 'preserves native behavior for an existing Wrayth entry' do
    expect(described_class.resolve(frontend: 'stormfront')).to eq(mode: 'client', port: nil)
  end

  it 'supports Profanity as an external XML client without an executable' do
    expect(described_class.resolve(frontend: 'profanity')).to eq(mode: 'external', port: 8000)
  end

  it 'preserves existing Profanity entries that explicitly launch a custom application' do
    entry = { frontend: 'profanity', custom_launch: '/opt/terminal-client' }
    expect(described_class.resolve(entry)).to eq(mode: 'client', port: nil)
    expect(described_class.external?(entry)).to be false
  end

  it 'uses the existing headless CLI path with a loopback-only listener' do
    expect(described_class.flags(frontend: 'profanity', launch_mode: 'external', listen_port: '8001'))
      .to eq(['--without-frontend', '--detachable-client=127.0.0.1:8001'])
  end

  it 'configures the existing process for an unsaved manual headless login' do
    argv = ['--gui', '--frontend=stormfront', '--detachable-client=9000']
    options = {}
    described_class.apply_to_runtime!({ frontend: 'profanity', listen_port: 8001 }, argv: argv, options: options)
    expect(argv).to eq(['--gui', '--without-frontend', '--detachable-client=127.0.0.1:8001', '--frontend=profanity'])
    expect(options).to eq(detachable_client_host: '127.0.0.1', detachable_client_port: 8001)
  end

  it 'rejects a non-XML frontend in external mode' do
    expect { described_class.resolve(frontend: 'wizard', launch_mode: 'external') }.to raise_error(ArgumentError, /XML/)
  end

  ['0', '65536', '8000garbage', '-1', 'lan:8000'].each do |port|
    it "rejects invalid listener port #{port}" do
      expect { described_class.resolve(frontend: 'profanity', launch_mode: 'external', listen_port: port) }
        .to raise_error(ArgumentError, /port/)
    end
  end

  it 'rejects an occupied port' do
    expect(TCPServer).to receive(:new).with('127.0.0.1', 8000).and_raise(Errno::EADDRINUSE)
    expect { described_class.preflight!(frontend: 'profanity', launch_mode: 'external', listen_port: 8000) }
      .to raise_error(ArgumentError, /unavailable/)
  end

  it 'closes only its own temporary preflight socket' do
    socket = double('preflight socket')
    expect(TCPServer).to receive(:new).with('127.0.0.1', 8001).and_return(socket)
    expect(socket).to receive(:close)
    described_class.preflight!(frontend: 'profanity', launch_mode: 'external', listen_port: 8001)
  end
end
