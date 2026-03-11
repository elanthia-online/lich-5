# frozen_string_literal: true

require 'rspec'
require 'ostruct'

# Define DATA_DIR before loading settings.rb (it uses DATA_DIR for DatabaseAdapter initialization)
DATA_DIR ||= File.expand_path('../../../../spec', __dir__)

# Use direct relative paths to avoid constant conflicts with other specs
require_relative '../../../mock_database_adapter'
require_relative '../../../../lib/common/settings'

# Stub Lich.deprecated if Lich module exists but method doesn't
module Lich
  def self.deprecated(*_args)
    nil
  end
end unless Lich.respond_to?(:deprecated)

RSpec.describe Lich::Common::InstanceSettings do
  before(:each) do
    @mock_db = Lich::Common::MockDatabaseAdapter.new

    # Set up MockScript to return nil for current.name to simulate non-Script context
    Lich::Common::MockScript.current_name = nil
    Lich::Common::MockXMLData.game = 'DR'
    Lich::Common::MockXMLData.name = 'TestCharacter'

    stub_const('Script', Lich::Common::MockScript)
    stub_const('XMLData', Lich::Common::MockXMLData)

    Lich::Common::Settings.instance_variable_set(:@db_adapter, @mock_db)
    Lich::Common::Settings.instance_variable_set(:@path_navigator, Lich::Common::PathNavigator.new(@mock_db))
    Lich::Common::Settings.instance_variable_set(:@settings_cache, {})

    @mock_db.clear
  end

  describe 'SCRIPT_NAME constant' do
    it 'is set to core' do
      expect(described_class::SCRIPT_NAME).to eq('core')
    end
  end

  describe '.character_scope' do
    it 'returns game:name format' do
      expect(described_class.character_scope).to eq('DR:TestCharacter')
    end
  end

  describe '.game_scope' do
    it 'returns just the game name' do
      expect(described_class.game_scope).to eq('DR')
    end
  end

  describe 'character-scoped access' do
    describe '.[]=' do
      it 'stores a value in character-scoped settings' do
        described_class[:test_key] = 'test_value'

        storage = @mock_db.dump
        expect(storage['core:DR:TestCharacter']).to include(test_key: 'test_value')
      end

      it 'works without Script.current context' do
        # Set Script.current.name to nil to simulate non-Script context
        Lich::Common::MockScript.current_name = nil

        # But InstanceSettings should still work (uses SCRIPT_NAME='core')
        expect { described_class[:key] = 'value' }.not_to raise_error
      end
    end

    describe '.[]' do
      it 'retrieves a stored value' do
        described_class[:test_key] = 'test_value'
        expect(described_class[:test_key]).to eq('test_value')
      end

      it 'returns nil for non-existent keys' do
        expect(described_class[:non_existent]).to be_nil
      end
    end

    describe '.character_proxy' do
      it 'returns a SettingsProxy' do
        proxy = described_class.character_proxy
        # SettingsProxy delegates is_a? to target, so check for proxy-specific methods
        expect(proxy).to respond_to(:script_name)
        expect(proxy).to respond_to(:scope)
        expect(proxy).to respond_to(:path)
        expect(proxy).to respond_to(:proxy_details)
      end

      it 'has the correct script_name' do
        proxy = described_class.character_proxy
        expect(proxy.script_name).to eq('core')
      end

      it 'has the correct scope' do
        proxy = described_class.character_proxy
        expect(proxy.scope).to eq('DR:TestCharacter')
      end

      it 'allows nested data access' do
        proxy = described_class.character_proxy
        proxy['nested'] = { 'key' => 'value' }

        # Re-fetch the proxy to get fresh data from cache
        fresh_proxy = described_class.character_proxy
        expect(fresh_proxy['nested']['key']).to eq('value')
      end
    end

    describe '.to_hash' do
      it 'returns a proxy wrapping character settings' do
        described_class[:key1] = 'value1'
        described_class[:key2] = 'value2'

        result = described_class.to_hash
        # SettingsProxy delegates is_a? to target, so check for proxy-specific methods
        expect(result).to respond_to(:script_name)
        expect(result[:key1]).to eq('value1')
        expect(result[:key2]).to eq('value2')
      end
    end
  end

  describe 'game-scoped access' do
    describe '.game_proxy' do
      it 'returns a SettingsProxy' do
        proxy = described_class.game_proxy
        # SettingsProxy delegates is_a? to target, so check for proxy-specific methods
        expect(proxy).to respond_to(:script_name)
        expect(proxy).to respond_to(:scope)
        expect(proxy).to respond_to(:path)
        expect(proxy).to respond_to(:proxy_details)
      end

      it 'has the correct script_name' do
        proxy = described_class.game_proxy
        expect(proxy.script_name).to eq('core')
      end

      it 'has the correct scope' do
        proxy = described_class.game_proxy
        expect(proxy.scope).to eq('DR')
      end
    end

    describe '.game accessor' do
      it 'stores values in game scope' do
        described_class.game['banking'] = { 'Crossings' => 1000 }

        storage = @mock_db.dump
        expect(storage['core:DR']).to include('banking' => { 'Crossings' => 1000 })
      end

      it 'retrieves values from game scope' do
        described_class.game['banking'] = { 'Crossings' => 1000 }
        # Re-fetch via game accessor to get fresh data
        result = described_class.game['banking']
        expect(result).to respond_to(:[])
        expect(result['Crossings']).to eq(1000)
      end

      it 'provides to_hash method' do
        described_class.game['key1'] = 'value1'
        result = described_class.game.to_hash
        expect(result).to include('key1' => 'value1')
      end
    end
  end

  describe 'data isolation' do
    it 'keeps character and game data separate' do
      described_class[:char_key] = 'char_value'
      described_class.game['game_key'] = 'game_value'

      storage = @mock_db.dump

      expect(storage['core:DR:TestCharacter']).to include(char_key: 'char_value')
      expect(storage['core:DR:TestCharacter']).not_to include('game_key' => 'game_value')

      expect(storage['core:DR']).to include('game_key' => 'game_value')
      expect(storage['core:DR']).not_to include(char_key: 'char_value')
    end

    it 'isolates from regular script settings' do
      # Simulate a script setting with Script.current
      Lich::Common::MockScript.current_name = 'my_script'

      Lich::Common::Settings[:script_key] = 'script_value'
      described_class[:instance_key] = 'instance_value'

      storage = @mock_db.dump

      expect(storage['my_script::']).to include(script_key: 'script_value')
      expect(storage['core:DR:TestCharacter']).to include(instance_key: 'instance_value')
    end
  end

  describe 'deprecated methods' do
    it '.load returns nil and logs deprecation' do
      expect(described_class.load).to be_nil
    end

    it '.save returns nil and logs deprecation' do
      expect(described_class.save).to be_nil
    end
  end
end
