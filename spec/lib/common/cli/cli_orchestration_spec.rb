# frozen_string_literal: true

require 'stringio'

require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/cli/cli_orchestration'

RSpec.describe Lich::Common::CLI::CLIOrchestration do
  around do |example|
    original_stdout = $stdout
    $stdout = StringIO.new
    example.run
    $stdout = original_stdout
  end

  before do
    stub_const('LICH_DIR', '/tmp/lich')
  end

  describe '.handle_refresh_characters' do
    before do
      allow(Lich::Common::Authentication::CLIPassword).to receive(:refresh_characters).and_return(0)
    end

    it 'passes an explicit valid --frontend through' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', 'password', '--frontend', 'wizard'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:refresh_characters)
        .with('DOUG', 'password', 'wizard')
    end

    it 'passes nil when --frontend is omitted' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', 'password'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:refresh_characters)
        .with('DOUG', 'password', nil)
    end

    it 'exits 1 without authenticating when --frontend has no value' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', 'password', '--frontend'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:refresh_characters)
    end

    it 'exits 1 without authenticating when --frontend is followed by another flag' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', 'password', '--frontend', '--other-flag'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:refresh_characters)
    end

    it 'exits 1 without authenticating when --frontend is not a recognized frontend' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', 'password', '--frontend', 'bogus'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:refresh_characters)
    end
  end
end
