# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/script_runtime_harness'
require_relative '../../mock_database_adapter'

require 'digest'
require 'sqlite3'
require 'common/settings'
require 'common/vars'

RSpec.describe 'script runtime settings and vars contracts' do
  include ScriptRuntimeHarness

  around do |example|
    original_game = Lich::Common::MockXMLData.game
    original_name = Lich::Common::MockXMLData.name
    original_current_name = Lich::Common::MockScript.current_name

    example.run
  ensure
    Lich::Common::MockXMLData.game = original_game
    Lich::Common::MockXMLData.name = original_name
    Lich::Common::MockScript.current_name = original_current_name
  end

  before do
    Lich::Common::MockXMLData.game = 'GSIV'
    Lich::Common::MockXMLData.name = 'TestCharacter'
    Lich::Common::MockScript.current_name = 'current_script'

    stub_const('XMLData', Lich::Common::MockXMLData)
    stub_const('Script', Lich::Common::MockScript)
  end

  describe 'Settings script_name namespaces' do
    let(:settings_db) { Lich::Common::MockDatabaseAdapter.new }

    around do |example|
      original_db_adapter = Lich::Common::Settings.instance_variable_get(:@db_adapter)
      original_path_navigator = Lich::Common::Settings.instance_variable_get(:@path_navigator)
      original_settings_cache = Lich::Common::Settings.instance_variable_get(:@settings_cache)

      example.run
    ensure
      Lich::Common::Settings.instance_variable_set(:@db_adapter, original_db_adapter)
      Lich::Common::Settings.instance_variable_set(:@path_navigator, original_path_navigator)
      Lich::Common::Settings.instance_variable_set(:@settings_cache, original_settings_cache)
    end

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

    after do
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

  describe 'UserVars compatibility facade' do
    let(:user_vars) { @script_runtime_user_vars }

    around do |example|
      original_defined = Lich::Common.const_defined?(:UserVars, false)
      original_user_vars = Lich::Common.const_get(:UserVars, false) if original_defined

      Lich::Common.send(:remove_const, :UserVars) if original_defined
      load File.expand_path('../../../lib/common/uservars.rb', __dir__)
      @script_runtime_user_vars = Lich::Common::UserVars

      example.run
    ensure
      Lich::Common.send(:remove_const, :UserVars) if Lich::Common.const_defined?(:UserVars, false)
      Lich::Common.const_set(:UserVars, original_user_vars) if original_defined
      @script_runtime_user_vars = nil
    end

    before do
      allow(Lich).to receive(:db).and_return(ScriptRuntimeHarness::FakeDb.new)
      allow(Lich).to receive(:db_mutex).and_return(Mutex.new)
      reset_vars_state
    end

    after do
      reset_vars_state
    end

    it 'delegates bracket and method access to Vars' do
      user_vars['container'] = 'satchel'
      user_vars.weapon = 'sword'

      expect(Lich::Common::Vars['container']).to eq('satchel')
      expect(Lich::Common::Vars['weapon']).to eq('sword')
      expect(user_vars.weapon).to eq('sword')
    end

    it 'preserves change/add/delete convenience helpers and ignored legacy parameters' do
      expect(user_vars.change('tags', 'foo', :ignored)).to eq('foo')
      expect(user_vars.add('tags', 'bar', :ignored)).to eq('foo, bar')
      expect(user_vars.delete('tags', :ignored)).to be_nil
      expect(user_vars['tags']).to be_nil
    end

    it 'keeps global and character list compatibility behavior' do
      user_vars['local'] = 'value'

      expect(user_vars.list_global).to eq([])
      expect(user_vars.list_char).to include('local' => 'value')
    end
  end
end
