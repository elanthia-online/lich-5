# frozen_string_literal: true

require 'rspec'
require 'ostruct'

# Define DATA_DIR before loading settings.rb (it uses DATA_DIR for DatabaseAdapter initialization)
DATA_DIR ||= File.expand_path('../../../../spec', __dir__)

# Use direct relative paths to avoid constant conflicts with other specs
require_relative '../../../mock_database_adapter'
require_relative '../../../../lib/common/settings'

RSpec.describe 'SettingsProxy script_name propagation' do
  before(:each) do
    @mock_db = Lich::Common::MockDatabaseAdapter.new

    Lich::Common::MockScript.current_name = 'test_script'
    Lich::Common::MockXMLData.game = 'DR'
    Lich::Common::MockXMLData.name = 'TestCharacter'

    stub_const('Script', Lich::Common::MockScript)
    stub_const('XMLData', Lich::Common::MockXMLData)

    Lich::Common::Settings.instance_variable_set(:@db_adapter, @mock_db)
    Lich::Common::Settings.instance_variable_set(:@path_navigator, Lich::Common::PathNavigator.new(@mock_db))
    Lich::Common::Settings.instance_variable_set(:@settings_cache, {})

    @mock_db.clear
  end

  describe 'SettingsProxy#script_name' do
    it 'stores script_name from initialization' do
      proxy = Lich::Common::SettingsProxy.new(
        Lich::Common::Settings,
        'test_scope',
        [],
        {},
        script_name: 'custom_script'
      )

      expect(proxy.script_name).to eq('custom_script')
    end

    it 'defaults to nil when not provided' do
      proxy = Lich::Common::SettingsProxy.new(
        Lich::Common::Settings,
        'test_scope',
        [],
        {}
      )

      expect(proxy.script_name).to be_nil
    end
  end

  describe 'Settings.root_proxy_for' do
    it 'creates proxy with provided script_name' do
      proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'custom_script')

      expect(proxy.script_name).to eq('custom_script')
    end

    it 'uses Script.current.name when script_name not provided' do
      proxy = Lich::Common::Settings.root_proxy_for('test_scope')

      expect(proxy.script_name).to eq('test_script')
    end
  end

  describe 'script_name propagation through operations' do
    let(:proxy) do
      Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
    end

    describe 'through []' do
      it 'propagates script_name to nested proxies' do
        proxy['nested'] = { 'key' => 'value' }
        # Re-fetch from proxy to get fresh data
        fresh_proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
        nested_proxy = fresh_proxy['nested']

        # SettingsProxy delegates is_a? to target, check for proxy methods instead
        expect(nested_proxy).to respond_to(:script_name)
        expect(nested_proxy.script_name).to eq('core')
      end

      it 'propagates through multiple levels' do
        proxy['level1'] = { 'level2' => { 'key' => 'value' } }
        # Re-fetch from proxy to get fresh data
        fresh_proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
        deep_proxy = fresh_proxy['level1']['level2']

        expect(deep_proxy.script_name).to eq('core')
      end
    end

    describe 'through each' do
      it 'propagates script_name to yielded container proxies' do
        proxy['items'] = [{ 'a' => 1 }, { 'b' => 2 }]
        # Re-fetch from proxy to get fresh data
        fresh_proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
        items_proxy = fresh_proxy['items']

        items_proxy.each do |item|
          # Check for proxy-specific methods instead of is_a?
          if item.respond_to?(:script_name)
            expect(item.script_name).to eq('core')
          end
        end
      end
    end

    describe 'through non-destructive methods' do
      it 'propagates script_name to map results' do
        proxy['items'] = [{ 'a' => 1 }, { 'b' => 2 }]
        # Re-fetch from proxy to get fresh data
        fresh_proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
        items = fresh_proxy['items']
        mapped = items.map { |item| item }

        # SettingsProxy delegates is_a? to target, check for proxy methods instead
        expect(mapped).to respond_to(:script_name)
        expect(mapped.script_name).to eq('core')
      end

      it 'propagates script_name to find results' do
        proxy['items'] = [{ 'name' => 'first' }, { 'name' => 'second' }]
        # Re-fetch from proxy to get fresh data
        fresh_proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
        items = fresh_proxy['items']
        found = items.find { |item| item['name'] == 'first' }

        # SettingsProxy delegates is_a? to target, check for proxy methods instead
        expect(found).to respond_to(:script_name)
        expect(found.script_name).to eq('core')
      end
    end
  end

  describe 'persistence with script_name' do
    it 'saves to database using proxy script_name' do
      proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
      proxy['key'] = 'value'

      storage = @mock_db.dump
      expect(storage['core:test_scope']).to include('key' => 'value')
    end

    it 'saves nested changes using proxy script_name' do
      proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
      proxy['nested'] = { 'key' => 'initial' }

      # Re-fetch proxy to get nested proxy
      fresh_proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
      fresh_proxy['nested']['key'] = 'value'

      storage = @mock_db.dump
      expect(storage['core:test_scope']['nested']).to include('key' => 'value')
    end

    it 'does not use Script.current.name when proxy has script_name' do
      # Script.current.name is 'test_script'
      proxy = Lich::Common::Settings.root_proxy_for('test_scope', script_name: 'core')
      proxy['key'] = 'value'

      storage = @mock_db.dump

      # Should be saved under 'core', not 'test_script'
      expect(storage['core:test_scope']).to include('key' => 'value')
      expect(storage['test_script:test_scope']).to be_nil
    end
  end

  describe 'proxy_details' do
    it 'includes script_name in output' do
      proxy = Lich::Common::SettingsProxy.new(
        Lich::Common::Settings,
        'test_scope',
        ['path'],
        {},
        script_name: 'core'
      )

      details = proxy.proxy_details
      expect(details).to include('script_name="core"')
    end
  end
end
