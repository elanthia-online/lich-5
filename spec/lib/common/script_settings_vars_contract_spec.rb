# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/script_runtime_harness'
require_relative '../../mock_database_adapter'

require 'digest'
require 'sqlite3'
require 'common/settings'
require 'common/vars'
require 'common/uservars'

SCRIPT_RUNTIME_USER_VARS = Lich::Common::UserVars
Lich::Common.send(:remove_const, :UserVars)

RSpec.describe 'script runtime settings and vars contracts' do
  include ScriptRuntimeHarness

  before do
    Lich::Common::MockXMLData.game = 'GSIV'
    Lich::Common::MockXMLData.name = 'TestCharacter'
    Lich::Common::MockScript.current_name = 'current_script'

    stub_const('XMLData', Lich::Common::MockXMLData)
    stub_const('Script', Lich::Common::MockScript)
  end

  describe 'Settings script_name namespaces' do
    let(:settings_db) { Lich::Common::MockDatabaseAdapter.new }

    before do
      Lich::Common::Settings.instance_variable_set(:@db_adapter, settings_db)
      Lich::Common::Settings.instance_variable_set(:@path_navigator, Lich::Common::PathNavigator.new(settings_db))
      Lich::Common::Settings.instance_variable_set(:@settings_cache, {})
    end

    it 'stores default Settings values under the current script name' do
      Lich::Common::Settings[:key] = 'value'

      expect(settings_db.dump).to include('current_script::' => { key: 'value' })
    end

    it 'supports fixed non-current script namespaces through script_name:' do
      Lich::Common::Settings.set_script_settings('GSIV:TestCharacter', :key, 'value', script_name: 'core')

      expect(settings_db.dump).to include('core:GSIV:TestCharacter' => { key: 'value' })
    end
  end

  describe Lich::Common::Vars do
    let(:fake_db) { ScriptRuntimeHarness::FakeDb.new }
    let(:mutex) { Mutex.new }

    before do
      allow(Lich).to receive(:db).and_return(fake_db)
      allow(Lich).to receive(:db_mutex).and_return(mutex)
      reset_vars_state
    end

    it 'loads and saves through the uservars table, not script_auto_settings' do
      described_class[:loot_sack] = 'backpack'
      described_class.save

      queries = fake_db.queries.map { |_kind, query, _params| query }
      expect(queries).to include(a_string_matching(/FROM uservars/))
      expect(queries).to include(a_string_matching(/INTO uservars/))
      expect(queries).not_to include(a_string_matching(/script_auto_settings/))
    end

    it 'normalizes string and symbol keys to the same storage key' do
      described_class[:loot_sack] = 'backpack'

      expect(described_class['loot_sack']).to eq('backpack')
      expect(described_class.list).to include('loot_sack' => 'backpack')
    end

    it 'deletes keys when assigned nil' do
      described_class['temporary'] = 'value'
      described_class['temporary'] = nil

      expect(described_class['temporary']).to be_nil
      expect(described_class.list).not_to have_key('temporary')
    end

    it 'returns a duplicate from list' do
      described_class['kept'] = 'value'

      listed = described_class.list
      listed['kept'] = 'changed'

      expect(described_class['kept']).to eq('value')
    end
  end

  describe SCRIPT_RUNTIME_USER_VARS do
    before do
      allow(Lich).to receive(:db).and_return(ScriptRuntimeHarness::FakeDb.new)
      allow(Lich).to receive(:db_mutex).and_return(Mutex.new)
      reset_vars_state
    end

    it 'delegates bracket and method access to Vars' do
      described_class['container'] = 'satchel'
      described_class.weapon = 'sword'

      expect(Lich::Common::Vars['container']).to eq('satchel')
      expect(Lich::Common::Vars['weapon']).to eq('sword')
      expect(described_class.weapon).to eq('sword')
    end

    it 'preserves change/add/delete convenience helpers and ignored legacy parameters' do
      expect(described_class.change('tags', 'foo', :ignored)).to eq('foo')
      expect(described_class.add('tags', 'bar', :ignored)).to eq('foo, bar')
      expect(described_class.delete('tags', :ignored)).to be_nil
      expect(described_class['tags']).to be_nil
    end

    it 'keeps global and character list compatibility behavior' do
      described_class['local'] = 'value'

      expect(described_class.list_global).to eq([])
      expect(described_class.list_char).to include('local' => 'value')
    end
  end
end
