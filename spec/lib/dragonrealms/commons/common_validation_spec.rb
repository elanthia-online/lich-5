# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'rspec'

# Setup load path (standalone spec, no spec_helper dependency)
LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

# Mock dependencies — define at top level, alias into namespace

# Script mock (class — game engine class)
class Script
  def self.running
    []
  end

  def self.hidden
    []
  end
end unless defined?(Script)

# Room mock (class — game engine class)
class Room
  def self.current
    nil
  end
end unless defined?(Room)

# UserVars mock (module — game engine module)
module UserVars
  def self.slack_token
    nil
  end
end unless defined?(UserVars)

# DRC mock (module — via module_function)
module DRC
  def self.bput(*_args)
    nil
  end
end unless defined?(DRC)

# DRRoom mock (module)
module DRRoom
  def self.pcs
    []
  end
end unless defined?(DRRoom)

# Lich::Messaging mock
module Lich
  module Messaging
    def self.msg(*_args); end
  end unless defined?(Lich::Messaging)
end

# Namespace aliases — MUST be BEFORE require so code resolves correctly
module Lich
  module DragonRealms
    DRC = ::DRC unless defined?(Lich::DragonRealms::DRC)
  end
end

# Kernel methods needed by the class
module Kernel
  def waitrt?; end unless method_defined?(:waitrt?)
  def fput(*_args); end unless method_defined?(:fput)
  def put(*_args); end unless method_defined?(:put)
  def echo(*_args); end unless method_defined?(:echo)
end

# Load the module under test (AFTER mocks + aliases)
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-validation.rb')

RSpec.describe Lich::DragonRealms::CharacterValidator do
  # Helper to build a mock lnet script object
  let(:lnet_buffer) { [] }
  let(:lnet_script) do
    script = double('lnet_script')
    allow(script).to receive(:name).and_return('lnet')
    allow(script).to receive(:unique_buffer).and_return(lnet_buffer)
    script
  end

  let(:room_obj) do
    room = double('room')
    allow(room).to receive(:id).and_return(42)
    room
  end

  before do
    allow(Lich::Messaging).to receive(:msg)
  end

  describe '#initialize' do
    context 'when lnet is running' do
      before do
        allow(Script).to receive(:running).and_return([lnet_script])
        allow(Script).to receive(:hidden).and_return([])
        allow(Room).to receive(:current).and_return(room_obj)
      end

      it 'finds the lnet script' do
        validator = described_class.new(false, false, false, 'TestBot')
        expect(validator.send(:lnet_available?)).to be true
      end

      it 'calls waitrt? on init' do
        expect_any_instance_of(described_class).to receive(:waitrt?)
        described_class.new(false, false, false, 'TestBot')
      end

      it 'calls fput sleep when should_sleep is true' do
        expect_any_instance_of(described_class).to receive(:fput).with('sleep')
        described_class.new(false, true, false, 'TestBot')
      end

      it 'does not call fput sleep when should_sleep is false' do
        expect_any_instance_of(described_class).not_to receive(:fput).with('sleep')
        described_class.new(false, false, false, 'TestBot')
      end

      it 'sends announce chat when announce is true' do
        described_class.new(true, false, false, 'TestBot')
        expect(lnet_buffer).to include("chat TestBot is up and running in room 42! Whisper me 'help' for more details.")
      end

      it 'does not send announce chat when announce is false' do
        described_class.new(false, false, false, 'TestBot')
        expect(lnet_buffer).to be_empty
      end
    end

    context 'when lnet is not running' do
      before do
        allow(Script).to receive(:running).and_return([])
        allow(Script).to receive(:hidden).and_return([])
      end

      it 'warns that lnet is not running' do
        expect(Lich::Messaging).to receive(:msg).with("bold", "CharacterValidator: lnet is not running. Chat features will be unavailable.")
        described_class.new(false, false, false, 'TestBot')
      end

      it 'does not crash when announce is true and lnet is missing' do
        expect { described_class.new(true, false, false, 'TestBot') }.not_to raise_error
      end

      it 'sets lnet_available? to false' do
        validator = described_class.new(false, false, false, 'TestBot')
        expect(validator.send(:lnet_available?)).to be false
      end
    end

    context 'when lnet is in hidden scripts' do
      before do
        allow(Script).to receive(:running).and_return([])
        allow(Script).to receive(:hidden).and_return([lnet_script])
        allow(Room).to receive(:current).and_return(room_obj)
      end

      it 'finds lnet in hidden scripts' do
        validator = described_class.new(false, false, false, 'TestBot')
        expect(validator.send(:lnet_available?)).to be true
      end
    end
  end

  # Shared setup for tests requiring a working validator with lnet
  shared_context 'with lnet available' do
    let(:validator) do
      allow(Script).to receive(:running).and_return([lnet_script])
      allow(Script).to receive(:hidden).and_return([])
      allow(Room).to receive(:current).and_return(room_obj)
      described_class.new(false, false, false, 'TestBot')
    end

    before { validator } # force creation
  end

  shared_context 'without lnet' do
    let(:validator) do
      allow(Script).to receive(:running).and_return([])
      allow(Script).to receive(:hidden).and_return([])
      described_class.new(false, false, false, 'TestBot')
    end

    before { validator }
  end

  describe '#validate' do
    include_context 'with lnet available'

    it 'sends lnet who query for unvalidated character' do
      validator.validate('Mahtra')
      expect(lnet_buffer).to include('who Mahtra')
    end

    it 'logs a message when validating' do
      expect(Lich::Messaging).to receive(:msg).with("plain", "CharacterValidator: Attempting to validate: Mahtra")
      validator.validate('Mahtra')
    end

    it 'skips validation for already-validated character' do
      validator.confirm('Mahtra')
      lnet_buffer.clear
      validator.validate('Mahtra')
      expect(lnet_buffer).to be_empty
    end

    context 'without lnet' do
      include_context 'without lnet'

      it 'does not crash when lnet is missing' do
        expect { validator.validate('Mahtra') }.not_to raise_error
      end
    end
  end

  describe '#confirm' do
    include_context 'with lnet available'

    it 'adds character to validated list' do
      validator.confirm('Mahtra')
      expect(validator.valid?('Mahtra')).to be true
    end

    it 'logs a success message' do
      expect(Lich::Messaging).to receive(:msg).with("plain", "CharacterValidator: Successfully validated: Mahtra")
      validator.confirm('Mahtra')
    end

    it 'skips if character is already validated' do
      validator.confirm('Mahtra')
      expect(Lich::Messaging).not_to receive(:msg).with("plain", "CharacterValidator: Successfully validated: Mahtra")
      validator.confirm('Mahtra')
    end

    context 'when greet is enabled' do
      let(:validator) do
        allow(Script).to receive(:running).and_return([lnet_script])
        allow(Script).to receive(:hidden).and_return([])
        allow(Room).to receive(:current).and_return(room_obj)
        described_class.new(false, false, true, 'TestBot')
      end

      it 'whispers greeting to character' do
        expect(validator).to receive(:put).with(/whisper Mahtra Hi! I'm your friendly neighborhood TestBot/)
        validator.confirm('Mahtra')
      end
    end

    context 'when greet is disabled' do
      it 'does not whisper greeting' do
        expect(validator).not_to receive(:put)
        validator.confirm('Mahtra')
      end
    end
  end

  describe '#valid?' do
    include_context 'with lnet available'

    it 'returns false for unknown character' do
      expect(validator.valid?('Unknown')).to be false
    end

    it 'returns true for confirmed character' do
      validator.confirm('Mahtra')
      expect(validator.valid?('Mahtra')).to be true
    end
  end

  describe '#send_slack_token' do
    include_context 'with lnet available'

    it 'sends slack token via lnet chat' do
      allow(UserVars).to receive(:slack_token).and_return('abc123')
      validator.send_slack_token('Mahtra')
      expect(lnet_buffer).to include('chat to Mahtra slack_token: abc123')
    end

    it 'sends Not Found when slack_token is nil' do
      allow(UserVars).to receive(:slack_token).and_return(nil)
      validator.send_slack_token('Mahtra')
      expect(lnet_buffer).to include('chat to Mahtra slack_token: Not Found')
    end

    it 'logs the DM attempt' do
      allow(UserVars).to receive(:slack_token).and_return('abc123')
      expect(Lich::Messaging).to receive(:msg).with("plain", /Attempting to DM Mahtra/)
      validator.send_slack_token('Mahtra')
    end

    context 'without lnet' do
      include_context 'without lnet'

      it 'does not crash when lnet is missing' do
        expect { validator.send_slack_token('Mahtra') }.not_to raise_error
      end
    end
  end

  describe '#send_bankbot_balance' do
    include_context 'with lnet available'

    it 'sends balance via lnet chat' do
      validator.send_bankbot_balance('Mahtra', '1,234 kronars')
      expect(lnet_buffer).to include('chat to Mahtra Current Balance: 1,234 kronars')
    end

    it 'logs the DM attempt' do
      expect(Lich::Messaging).to receive(:msg).with("plain", /Attempting to DM Mahtra/)
      validator.send_bankbot_balance('Mahtra', '500 kronars')
    end

    context 'without lnet' do
      include_context 'without lnet'

      it 'does not crash when lnet is missing' do
        expect { validator.send_bankbot_balance('Mahtra', '500') }.not_to raise_error
      end
    end
  end

  describe '#send_bankbot_location' do
    include_context 'with lnet available'

    it 'sends room location via lnet chat' do
      allow(Room).to receive(:current).and_return(room_obj)
      validator.send_bankbot_location('Mahtra')
      expect(lnet_buffer).to include('chat to Mahtra Current Location: 42')
    end

    it 'logs the DM attempt' do
      allow(Room).to receive(:current).and_return(room_obj)
      expect(Lich::Messaging).to receive(:msg).with("plain", /Attempting to DM Mahtra/)
      validator.send_bankbot_location('Mahtra')
    end

    context 'without lnet' do
      include_context 'without lnet'

      it 'does not crash when lnet is missing' do
        expect { validator.send_bankbot_location('Mahtra') }.not_to raise_error
      end
    end
  end

  describe '#send_bankbot_help' do
    include_context 'with lnet available'

    it 'sends all help messages via lnet chat' do
      messages = ['Help line 1', 'Help line 2', 'Help line 3']
      validator.send_bankbot_help('Mahtra', messages)
      expect(lnet_buffer).to include('chat to Mahtra Help line 1')
      expect(lnet_buffer).to include('chat to Mahtra Help line 2')
      expect(lnet_buffer).to include('chat to Mahtra Help line 3')
    end

    it 'logs each DM attempt' do
      messages = ['Help 1', 'Help 2']
      expect(Lich::Messaging).to receive(:msg).with("plain", /Attempting to DM Mahtra.*Help 1/).once
      expect(Lich::Messaging).to receive(:msg).with("plain", /Attempting to DM Mahtra.*Help 2/).once
      validator.send_bankbot_help('Mahtra', messages)
    end

    it 'handles empty messages array' do
      validator.send_bankbot_help('Mahtra', [])
      expect(lnet_buffer).to be_empty
    end

    context 'without lnet' do
      include_context 'without lnet'

      it 'does not crash when lnet is missing' do
        expect { validator.send_bankbot_help('Mahtra', ['test']) }.not_to raise_error
      end
    end
  end

  describe '#in_game?' do
    include_context 'with lnet available'

    it 'returns true when character is found' do
      allow(DRC).to receive(:bput).and_return('  Mahtra.')
      expect(validator.in_game?('Mahtra')).to be_truthy
    end

    it 'returns false when character is not found' do
      find_not_found = described_class::FIND_NOT_FOUND
      allow(DRC).to receive(:bput).and_return(find_not_found)
      expect(validator.in_game?('Mahtra')).to be_falsey
    end

    it 'returns false on unknown command' do
      allow(DRC).to receive(:bput).and_return('Unknown command')
      expect(validator.in_game?('Mahtra')).to be_falsey
    end

    it 'calls DRC.bput with find command and expected patterns' do
      allow(DRC).to receive(:bput).and_return('  Mahtra.')
      expect(DRC).to receive(:bput).with(
        'find Mahtra',
        described_class::FIND_NOT_FOUND,
        /^\s{2}Mahtra\.$/,
        'Unknown command'
      )
      validator.in_game?('Mahtra')
    end
  end

  describe 'constants' do
    it 'defines LNET_SCRIPT_NAME' do
      expect(described_class::LNET_SCRIPT_NAME).to eq('lnet')
    end

    it 'defines FIND_NOT_FOUND' do
      expect(described_class::FIND_NOT_FOUND).to eq('There are no adventurers in the realms that match the names specified')
    end

    it 'has frozen LNET_SCRIPT_NAME' do
      expect(described_class::LNET_SCRIPT_NAME).to be_frozen
    end

    it 'has frozen FIND_NOT_FOUND' do
      expect(described_class::FIND_NOT_FOUND).to be_frozen
    end
  end
end
