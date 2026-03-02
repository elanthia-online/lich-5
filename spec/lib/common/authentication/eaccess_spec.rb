# frozen_string_literal: true

require 'rspec'

# Mock dependencies before requiring the code
DATA_DIR = '/tmp/test_data' unless defined?(DATA_DIR)

# Define Lich.log separately
module Lich
  def self.log(_message)
    # no-op for tests
  end
end unless defined?(Lich)

# Account module must be defined with separate guard
module Lich
  module Common
    module Account
      class << self
        attr_accessor :name, :game_code, :character, :subscription, :members
      end
    end
  end
end unless defined?(Lich::Common::Account)

require_relative '../../../../lib/common/authentication/eaccess'

RSpec.describe Lich::Common::Authentication::EAccess do
  describe 'AuthenticationError' do
    it 'stores the error code' do
      error = described_class::AuthenticationError.new('REJECT')
      expect(error.error_code).to eq('REJECT')
    end

    it 'formats message with error code' do
      error = described_class::AuthenticationError.new('NORECORD')
      expect(error.message).to eq('Error(NORECORD)')
    end

    it 'is a StandardError subclass' do
      expect(described_class::AuthenticationError.superclass).to eq(StandardError)
    end
  end

  describe 'PACKET_SIZE' do
    it 'is defined as 8192' do
      expect(described_class::PACKET_SIZE).to eq(8192)
    end
  end

  describe '.pem' do
    it 'returns path to simu.pem in DATA_DIR' do
      expect(described_class.pem).to eq(File.join(DATA_DIR, 'simu.pem'))
    end
  end

  describe '.pem_exist?' do
    context 'when pem file exists' do
      before do
        allow(File).to receive(:exist?).with(described_class.pem).and_return(true)
      end

      it 'returns true' do
        expect(described_class.pem_exist?).to be true
      end
    end

    context 'when pem file does not exist' do
      before do
        allow(File).to receive(:exist?).with(described_class.pem).and_return(false)
      end

      it 'returns false' do
        expect(described_class.pem_exist?).to be false
      end
    end
  end

  describe '.auth' do
    let(:mock_socket) { double('ssl_socket') }
    let(:account) { 'testuser' }
    let(:password) { 'testpass' }

    before do
      # Reset Account state before each test
      Lich::Common::Account.name = nil
      Lich::Common::Account.game_code = nil
      Lich::Common::Account.character = nil
    end

    it 'sets Account module state when defined' do
      # Stub socket and read to simulate auth protocol
      allow(described_class).to receive(:socket).and_return(mock_socket)
      allow(described_class).to receive(:verify_pem).and_return(true)
      allow(mock_socket).to receive(:puts)
      allow(mock_socket).to receive(:close)
      allow(mock_socket).to receive(:closed?).and_return(false)

      # Simulate protocol responses:
      # K -> hashkey, A -> KEY response, M -> game list, F/G/P/C/L -> game responses
      allow(described_class).to receive(:read).and_return(
        "HASHKEY123", # K response - hash key
        "KEY\tabc123\t", # A response - auth success
        "M\tGS3\tGemstone IV", # M response - game list
        "NORMAL", # F response - subscription
        "G\tOK", # G response
        "P\tOK", # P response
        "C\t1\t0\t0\t0\t001\tTestChar", # C response - character list
        "L\tOK\tGAMEHOST=storm.gs4.game.play.net" # L response - login info
      )

      described_class.auth(
        account: account,
        password: password,
        character: 'TestChar',
        game_code: 'GS3'
      )

      expect(Lich::Common::Account.name).to eq(account)
      expect(Lich::Common::Account.game_code).to eq('GS3')
      expect(Lich::Common::Account.character).to eq('TestChar')
    end
  end
end
