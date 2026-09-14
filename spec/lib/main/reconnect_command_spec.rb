# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/reconnect_command'

RSpec.describe Lich::Main::ReconnectCommand do
  describe '.ruby_executable' do
    it 'delegates selection to the shared common resolver' do
      allow(Lich::Common::RubyExecutable).to receive(:resolve).and_return('C:/Ruby/bin/rubyw.exe')

      expect(
        described_class.ruby_executable(
          platform_key: :windows,
          configured_ruby: 'C:/Ruby/bin/ruby.exe'
        )
      ).to eq('C:/Ruby/bin/rubyw.exe')
      expect(Lich::Common::RubyExecutable).to have_received(:resolve).with(
        platform_key: :windows,
        configured_ruby: 'C:/Ruby/bin/ruby.exe'
      )
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

    it 'does not duplicate the reconnect marker on later reconnects' do
      result = described_class.build(
        argv: ['--reconnect', '--reconnected'],
        program: 'lich.rbw',
        ruby_executable: 'ruby',
        reconnect_arg: nil,
        reconnect_delay: 60,
        reconnect_step: 0
      )

      expect(result.count('--reconnected')).to eq(1)
    end

    it 'preserves the reconnect delay argument when the step is zero' do
      result = described_class.build(
        argv: ['--reconnect', '--reconnect-delay=60'],
        program: 'lich.rbw',
        ruby_executable: 'ruby',
        reconnect_arg: '--reconnect-delay=60',
        reconnect_delay: 60,
        reconnect_step: 0
      )

      expect(result).to include('--reconnect-delay=60')
    end

    it 'normalizes invalid reconnect delay values' do
      [
        [nil, 0],
        ['abc', 0],
        [0, nil],
        [0, 'abc']
      ].each do |delay, step|
        expect {
          described_class.build(
            argv: [],
            program: 'lich.rbw',
            ruby_executable: 'ruby',
            reconnect_arg: nil,
            reconnect_delay: delay,
            reconnect_step: step
          )
        }.to raise_error(ArgumentError, 'reconnect delay values must be integers')
      end
    end

    it 'rejects negative reconnect delay values without remapping the error' do
      expect {
        described_class.build(
          argv: [],
          program: 'lich.rbw',
          ruby_executable: 'ruby',
          reconnect_arg: nil,
          reconnect_delay: -1,
          reconnect_step: 0
        )
      }.to raise_error(ArgumentError, 'reconnect delay values must not be negative')
    end

    it 'rejects blank program and Ruby executable inputs' do
      {
        program: ['', 'ruby', 'program must not be empty'],
        ruby_executable: ['lich.rbw', '', 'Ruby executable must not be empty']
      }.each_value do |program, ruby_executable, message|
        expect {
          described_class.build(
            argv: [],
            program: program,
            ruby_executable: ruby_executable,
            reconnect_arg: nil,
            reconnect_delay: 60,
            reconnect_step: 0
          )
        }.to raise_error(ArgumentError, message)
      end
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

  describe '.log_line' do
    it 'masks the password while leaving everything else as-is' do
      args = ['ruby', 'lich.rbw', '--login', '--password=hunter2', '--reconnected']

      expect(described_class.log_line(args)).to eq(
        'ruby lich.rbw --login --password=[scrubbed] --reconnected'
      )
    end

    it 'does not mutate the argv it is given' do
      # main.rb logs this string and execs the same array on the very next
      # line, so building the log message must never touch the real argv.
      args = ['ruby', 'lich.rbw', '--login', '--password=hunter2']

      described_class.log_line(args)

      expect(args).to include('--password=hunter2')
    end

    it 'reflects exactly what exec would receive, chained the way main.rb chains them' do
      # Exercises the same two calls main.rb makes back to back -- build the
      # exec argv, then render its log line -- with nothing stubbed in
      # between, so a regression in either method or in how they compose
      # would fail here.
      args = described_class.build(
        argv: ['--reconnect', '--login', '--password=hunter2'],
        program: 'lich.rbw',
        ruby_executable: 'ruby',
        reconnect_arg: nil,
        reconnect_delay: 60,
        reconnect_step: 0
      )

      log_line = described_class.log_line(args)

      expect(log_line).to eq('ruby lich.rbw --reconnect --login --password=[scrubbed] --reconnected')
      # The array build() returned -- the one exec(*args) would actually
      # receive -- still carries the real password after log_line ran.
      expect(args).to include('--password=hunter2')
    end
  end
end
