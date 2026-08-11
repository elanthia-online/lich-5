# frozen_string_literal: true

# NOTE: This spec intentionally does NOT require spec_helper.
# CredentialScrub has no Lich runtime dependencies, so it is tested in
# isolation without booting the engine.

require 'rspec'
require 'tmpdir'

require_relative '../../../lib/common/credential_scrub'

RSpec.describe Lich::Common::CredentialScrub do
  describe '.scrub_launch_data!' do
    it 'overwrites the KEY entry and leaves every other entry untouched' do
      launch_data = ['GAMECODE=GS3', 'KEY=abc123secret', 'GAMEHOST=localhost']

      expect(described_class.scrub_launch_data!(launch_data)).to eq(1)
      expect(launch_data).to eq(['GAMECODE=GS3', 'KEY=[scrubbed]', 'GAMEHOST=localhost'])
    end

    it 'mutates the existing String so other holders of it lose the secret' do
      key_line = String.new('KEY=abc123secret')
      launch_data = [key_line]
      gui_reference = launch_data

      described_class.scrub_launch_data!(launch_data)

      expect(key_line).to eq('KEY=[scrubbed]')
      expect(gui_reference.first).to eq('KEY=[scrubbed]')
    end

    it 'falls back to element assignment when the entry is frozen' do
      launch_data = ['KEY=abc123secret'.freeze]

      expect(described_class.scrub_launch_data!(launch_data)).to eq(1)
      expect(launch_data.first).to eq('KEY=[scrubbed]')
    end

    it 'matches the KEY prefix case insensitively' do
      launch_data = ['key=abc123secret']

      described_class.scrub_launch_data!(launch_data)

      expect(launch_data.first).to eq('KEY=[scrubbed]')
    end

    it 'is idempotent and reports nothing rewritten on a second pass' do
      launch_data = ['KEY=abc123secret']
      described_class.scrub_launch_data!(launch_data)

      expect(described_class.scrub_launch_data!(launch_data)).to eq(0)
      expect(launch_data).to eq(['KEY=[scrubbed]'])
    end

    it 'tolerates nil, which is what direct host/port and --pipe startups produce' do
      expect(described_class.scrub_launch_data!(nil)).to eq(0)
    end

    it 'leaves a launch_data array with no KEY entry alone' do
      launch_data = ['GAMECODE=GS3']

      expect(described_class.scrub_launch_data!(launch_data)).to eq(0)
      expect(launch_data).to eq(['GAMECODE=GS3'])
    end
  end

  describe '.scrub_argv!' do
    it 'redacts the password value while preserving the flag prefix' do
      argv = ['--login', '--password=hunter2', '--without-frontend']

      expect(described_class.scrub_argv!(argv)).to eq(1)
      expect(argv).to eq(['--login', '--password=[scrubbed]', '--without-frontend'])
    end

    it 'redacts master-password as well' do
      argv = ['--master-password=vault']

      described_class.scrub_argv!(argv)

      expect(argv).to eq(['--master-password=[scrubbed]'])
    end

    it 'leaves the account identifier alone' do
      argv = ['--account=myaccount', '--password=hunter2']

      described_class.scrub_argv!(argv)

      expect(argv).to eq(['--account=myaccount', '--password=[scrubbed]'])
    end

    it 'keeps bare flags intact so ARGV.include? checks still work' do
      argv = ['--reconnect', '--login', '--password=hunter2', '--without-frontend']

      described_class.scrub_argv!(argv)

      expect(argv.include?('--without-frontend')).to be true
      expect(argv.include?('--reconnect')).to be true
      expect(argv.include?('--login')).to be true
    end

    it 'does not rewrite a flag that carries no value' do
      argv = ['--password=']

      expect(described_class.scrub_argv!(argv)).to eq(0)
      expect(argv).to eq(['--password='])
    end

    it 'is idempotent' do
      argv = ['--password=hunter2']
      described_class.scrub_argv!(argv)

      expect(described_class.scrub_argv!(argv)).to eq(0)
      expect(argv).to eq(['--password=[scrubbed]'])
    end

    it 'tolerates nil' do
      expect(described_class.scrub_argv!(nil)).to eq(0)
    end
  end

  describe '.redact_argv' do
    it 'masks the password value while preserving the flag prefix' do
      argv = ['--login', '--password=hunter2', '--without-frontend']

      expect(described_class.redact_argv(argv)).to eq(
        ['--login', '--password=[scrubbed]', '--without-frontend']
      )
    end

    it 'masks master-password as well' do
      expect(described_class.redact_argv(['--master-password=vault'])).to eq(['--master-password=[scrubbed]'])
    end

    it 'leaves the account identifier alone' do
      argv = ['--account=myaccount', '--password=hunter2']

      expect(described_class.redact_argv(argv)).to eq(['--account=myaccount', '--password=[scrubbed]'])
    end

    it 'does not mutate the input array or its String elements' do
      # This is the whole point of the method: reconnect passes the same argv
      # to exec() right after logging it, so the real password must survive.
      password_arg = String.new('--password=hunter2')
      argv = ['--login', password_arg]

      result = described_class.redact_argv(argv)

      expect(result).to eq(['--login', '--password=[scrubbed]'])
      expect(argv).to eq(['--login', '--password=hunter2'])
      expect(password_arg).to eq('--password=hunter2')
    end

    it 'returns a different array object than the one passed in' do
      argv = ['--password=hunter2']

      expect(described_class.redact_argv(argv)).not_to equal(argv)
    end

    it 'does not mask a flag that carries no value' do
      expect(described_class.redact_argv(['--password='])).to eq(['--password='])
    end

    it 'passes through non-secret entries unchanged' do
      argv = ['--reconnect', '--login', '--reconnect-delay=60']

      expect(described_class.redact_argv(argv)).to eq(argv)
    end

    it 'tolerates non-String entries in argv' do
      argv = [:not_a_string, '--password=hunter2']

      expect(described_class.redact_argv(argv)).to eq([:not_a_string, '--password=[scrubbed]'])
    end

    it 'returns an empty array for nil or non-Array input' do
      expect(described_class.redact_argv(nil)).to eq([])
      expect(described_class.redact_argv('--password=hunter2')).to eq([])
    end
  end

  describe '.scrub_options!' do
    it 'redacts the password value in place' do
      options = { password: 'hunter2', account: 'myaccount', sal: 'C:\\game.sal' }

      expect(described_class.scrub_options!(options)).to eq([:password])
      expect(options).to eq({ password: '[scrubbed]', account: 'myaccount', sal: 'C:\\game.sal' })
    end

    it 'mutates the shared hash so the argv option pipeline copy is covered too' do
      options = { password: 'hunter2' }
      pipeline_reference = options

      described_class.scrub_options!(options)

      expect(pipeline_reference[:password]).to eq('[scrubbed]')
    end

    it 'mutates the password String itself so other holders of it lose the secret' do
      password = String.new('hunter2')
      options = { password: password }

      described_class.scrub_options!(options)

      expect(password).to eq('[scrubbed]')
    end

    it 'falls back to key assignment when the password String is frozen' do
      options = { password: 'hunter2'.freeze }

      expect(described_class.scrub_options!(options)).to eq([:password])
      expect(options[:password]).to eq('[scrubbed]')
    end

    it 'is idempotent' do
      options = { password: 'hunter2' }
      described_class.scrub_options!(options)

      expect(described_class.scrub_options!(options)).to eq([])
    end

    it 'reports nothing when no password was supplied' do
      expect(described_class.scrub_options!({ sal: 'C:\\game.sal' })).to eq([])
    end

    it 'tolerates nil' do
      expect(described_class.scrub_options!(nil)).to eq([])
    end
  end

  describe 'argv snapshot aliasing' do
    # main.rb snapshots argv before scrubbing so reconnect can re-exec with the
    # real credentials. Whether an in-place scrub can reach that snapshot depends
    # on whether the argument Strings are frozen, which is an interpreter detail
    # rather than something to rely on, so main.rb copies element-wise. These
    # examples pin both halves of that reasoning.

    it 'reaches a shallow Array#dup snapshot when the arguments are mutable' do
      argv = ['--login', String.new('--password=hunter2'), '--reconnect']
      shallow_snapshot = argv.dup

      described_class.scrub_argv!(argv)

      expect(shallow_snapshot[1]).to eq('--password=[scrubbed]')
    end

    it 'cannot reach an element-wise snapshot of mutable arguments' do
      argv = ['--login', String.new('--password=hunter2'), '--reconnect']
      snapshot = argv.map(&:dup)

      described_class.scrub_argv!(argv)

      expect(argv[1]).to eq('--password=[scrubbed]')
      expect(snapshot[1]).to eq('--password=hunter2')
    end

    it 'cannot reach an element-wise snapshot of frozen arguments' do
      argv = ['--login', '--password=hunter2'.freeze, '--reconnect']
      snapshot = argv.map(&:dup)

      described_class.scrub_argv!(argv)

      expect(argv[1]).to eq('--password=[scrubbed]')
      expect(snapshot[1]).to eq('--password=hunter2')
    end
  end

  describe '.shred_file' do
    around do |example|
      Dir.mktmpdir('credential-scrub') { |dir| @dir = dir; example.run }
    end

    it 'overwrites the contents and deletes the file' do
      path = File.join(@dir, 'lich1234.sal')
      File.write(path, "KEY=abc123secret\nGAMECODE=GS3\n")

      expect(described_class.shred_file(path)).to be true
      expect(File.exist?(path)).to be false
    end

    it 'zeroes the bytes before unlinking' do
      path = File.join(@dir, 'observed.sal')
      original = "KEY=abc123secret\n"
      File.write(path, original)
      observed = nil

      allow(File).to receive(:delete) { |target| observed = File.binread(target) }
      allow(File).to receive(:exist?).and_call_original

      described_class.shred_file(path, attempts: 1)

      expect(observed).to eq("\x00" * original.bytesize)
      expect(observed).not_to include('abc123secret')
    end

    it 'reports true when the file is already gone' do
      expect(described_class.shred_file(File.join(@dir, 'absent.sal'))).to be true
    end

    it 'returns false rather than raising when deletion keeps failing' do
      path = File.join(@dir, 'locked.sal')
      File.write(path, 'KEY=abc123secret')
      allow(File).to receive(:delete).and_raise(Errno::EACCES)

      expect { @result = described_class.shred_file(path, attempts: 2) }.not_to raise_error
      expect(@result).to be false
    end

    it 'returns false for a nil or empty path' do
      expect(described_class.shred_file(nil)).to be false
      expect(described_class.shred_file('')).to be false
    end

    it 'does not raise when the overwrite step fails' do
      path = File.join(@dir, 'unwritable.sal')
      File.write(path, 'KEY=abc123secret')
      allow(File).to receive(:open).and_raise(Errno::EACCES)

      expect { described_class.shred_file(path) }.not_to raise_error
      expect(File.exist?(path)).to be false
    end
  end
end
