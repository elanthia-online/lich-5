# frozen_string_literal: true

require 'stringio'

require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/cli/cli_orchestration'

RSpec.describe Lich::Common::CLI::OneShotCommands do
  describe '.present?' do
    it 'recognizes every flag CLIOrchestration dispatches, anywhere on the command line' do
      described_class::HANDLERS.each_key do |flag|
        expect(described_class.present?([flag])).to be(true), flag
        expect(described_class.present?(['--frontend', 'wizard', flag, 'DOUG'])).to be(true), flag
      end
    end

    it 'recognizes the session queries in both --session-info forms' do
      expect(described_class.present?(['--active-sessions'])).to be(true)
      expect(described_class.present?(['--session-info', 'Doug'])).to be(true)
      expect(described_class.present?(['--session-info=Doug'])).to be(true)
    end

    it 'does not treat a session start or near-miss arguments as one-shot commands' do
      [
        [],
        ['--login', 'Doug'],
        ['--login', 'Doug', '--password=-aa'],
        ['--add-accounts'],
        ['x-aa'],
        ['-AA'],
        ['--session-infox'],
        ['--active-sessions-now'],
        ['x--active-sessions'],
        ['x--session-info=Doug']
      ].each do |argv|
        expect(described_class.present?(argv)).to be(false), argv.inspect
      end
    end
  end

  describe 'dispatch table' do
    let(:orchestration) { Lich::Common::CLI::CLIOrchestration }

    it 'sends each short flag to the same handler as its long form' do
      {
        '-cap' => '--change-account-password', '-aa' => '--add-account', '-rc' => '--refresh-characters',
        '-ac' => '--add-character', '-cmp' => '--change-master-password', '-rmp' => '--recover-master-password',
        '-cem' => '--change-encryption-mode'
      }.each do |short, long|
        expect(described_class::HANDLERS.fetch(short)).to eq(described_class::HANDLERS.fetch(long)), short
      end
    end

    it 'sends each long flag to the handler named after it' do
      described_class::HANDLERS.select { |flag, _| flag.start_with?('--') }.each do |flag, handler|
        expect(handler).to eq(:"handle_#{flag.delete_prefix('--').tr('-', '_')}"), flag
      end
    end

    it 'names a CLIOrchestration handler for every flag' do
      described_class::HANDLERS.each do |flag, handler|
        expect(orchestration).to respond_to(handler), "#{flag} -> #{handler}"
      end
    end

    it 'covers every CLIOrchestration handler, so a new command cannot skip the recovery check' do
      handlers = orchestration.singleton_methods.grep(/\Ahandle_/)

      expect(handlers).to match_array(described_class::HANDLERS.values.uniq)
    end

    it 'is what CLIOrchestration.execute dispatches from' do
      allow(Lich::Common::CLI::ActiveSessionsQuery).to receive(:execute)
      calls = []
      described_class::HANDLERS.values.uniq.each do |handler|
        allow(orchestration).to receive(handler) { calls << handler }
      end

      described_class::HANDLERS.each do |flag, handler|
        calls.clear
        stub_const('ARGV', [flag, 'DOUG'])
        orchestration.execute
        expect(calls).to eq([handler]), flag
      end
    end
  end
end
