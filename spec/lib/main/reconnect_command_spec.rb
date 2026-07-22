# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/reconnect_command'

RSpec.describe Lich::Main::ReconnectCommand do
  describe '.ruby_executable' do
    it 'uses an installed rubyw.exe on Windows' do
      allow(File).to receive(:file?).with('C:/Ruby/bin/rubyw.exe').and_return(true)

      expect(
        described_class.ruby_executable(
          platform: 'x64-mingw32',
          configured_ruby: 'C:/Ruby/bin/ruby.exe'
        )
      ).to eq('C:/Ruby/bin/rubyw.exe')
    end

    it 'falls back to the configured Ruby when rubyw.exe is unavailable' do
      allow(File).to receive(:file?).with('C:/Ruby/bin/rubyw.exe').and_return(false)

      expect(
        described_class.ruby_executable(
          platform: 'x64-mingw32',
          configured_ruby: 'C:/Ruby/bin/ruby.exe'
        )
      ).to eq('C:/Ruby/bin/ruby.exe')
    end

    it 'falls back when checking rubyw.exe raises a filesystem error' do
      allow(File).to receive(:file?).with('C:/Ruby/bin/rubyw.exe').and_raise(Errno::EACCES)

      expect(
        described_class.ruby_executable(
          platform: 'x64-mingw32',
          configured_ruby: 'C:/Ruby/bin/ruby.exe'
        )
      ).to eq('C:/Ruby/bin/ruby.exe')
    end

    it 'rejects a blank configured Ruby executable' do
      expect { described_class.ruby_executable(configured_ruby: '') }
        .to raise_error(ArgumentError, 'configured Ruby executable must not be empty')
    end
  end

  describe '.build' do
    it 'preserves argument boundaries and adds the reconnect marker' do
      argv = ['--login', 'Tsetem', '--custom-launch=C:/Program Files/Saga/Saga.exe']

      expect(
        described_class.build(
          argv: argv,
          program: 'C:/Lich/lich.rbw',
          ruby_executable: 'C:/Ruby/bin/rubyw.exe',
          reconnect_arg: nil,
          reconnect_delay: 60,
          reconnect_step: 0
        )
      ).to eq([
                'C:/Ruby/bin/rubyw.exe',
                'C:/Lich/lich.rbw',
                '--login',
                'Tsetem',
                '--custom-launch=C:/Program Files/Saga/Saga.exe',
                '--reconnected'
              ])
      expect(argv).not_to include('--reconnected')
    end

    it 'increments and replaces a stepped reconnect delay' do
      result = described_class.build(
        argv: ['--reconnect', '--reconnect-delay=60+5'],
        program: 'lich.rbw',
        ruby_executable: 'ruby',
        reconnect_arg: '--reconnect-delay=60+5',
        reconnect_delay: 60,
        reconnect_step: 5
      )

      expect(result).to include('--reconnect-delay=65+5', '--reconnected')
      expect(result).not_to include('--reconnect-delay=60+5')
    end

    it 'rejects invalid caller input' do
      expect {
        described_class.build(
          argv: 'not-an-array',
          program: 'lich.rbw',
          ruby_executable: 'ruby',
          reconnect_arg: nil,
          reconnect_delay: 60,
          reconnect_step: 0
        )
      }.to raise_error(ArgumentError, 'argv must be an Array')
    end
  end
end
