# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/authentication/master_password_prompts'

# MasterPasswordPrompts is the seam through which EntryStore asks a front
# end for a master password. Core never names a dialog: with no provider
# the prompts answer nil (the user declined) and quitting is a no-op.
RSpec.describe Lich::Common::Authentication::MasterPasswordPrompts do
  around do |example|
    previous = described_class.provider
    described_class.provider = nil
    example.run
  ensure
    described_class.provider = previous
  end

  context 'with no provider registered' do
    it 'is not available' do
      expect(described_class.available?).to be(false)
    end

    it 'declines creation and recovery and quits nothing' do
      expect(described_class.show_create_master_password_dialog).to be_nil
      expect(described_class.show_password_for_data_access({ 'salt' => 'x' })).to be_nil
      expect(described_class.quit_session).to be_nil
    end
  end

  context 'with a provider registered' do
    let(:provider) do
      Class.new do
        attr_reader :seen, :quit_count

        def initialize
          @quit_count = 0
        end

        def show_create_master_password_dialog
          'Created123'
        end

        def show_password_for_data_access(validation_test)
          @seen = validation_test
          { password: 'Recovered123', continue_session: true }
        end

        def quit_session
          @quit_count += 1
          :quit
        end
      end.new
    end

    before { described_class.provider = provider }

    it 'is available' do
      expect(described_class.available?).to be(true)
    end

    it 'forwards creation, recovery and quitting to the provider' do
      validation_test = { 'salt' => 'abc', 'hash' => 'def' }

      expect(described_class.show_create_master_password_dialog).to eq('Created123')
      expect(described_class.show_password_for_data_access(validation_test))
        .to eq({ password: 'Recovered123', continue_session: true })
      expect(provider.seen).to equal(validation_test)
      expect(described_class.quit_session).to eq(:quit)
      expect(provider.quit_count).to eq(1)
    end

    it 'treats a provider without quit_session as a no-op quit' do
      described_class.provider = Object.new

      expect(described_class.quit_session).to be_nil
    end
  end
end
