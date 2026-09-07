# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../login_spec_helper'

RSpec.describe Lich::Common::GUI::AccountManager, '.update_launch_settings' do
  around do |example|
    Dir.mktmpdir('lich-frontend-edit') do |directory|
      @data_dir = directory
      @path = Lich::Common::Authentication::EntryStore.yaml_file_path(directory)
      example.run
    end
  end

  let(:entry) do
    { 'char_name' => 'Tester', 'game_code' => 'GS3', 'frontend' => 'stormfront',
      'custom_launch' => nil, 'custom_launch_dir' => nil, 'is_favorite' => true }
  end
  let(:other_entry) { entry.merge('custom_launch' => '/opt/other-client') }
  let(:original) do
    { 'encryption_mode' => 'enhanced', 'master_password_validation_test' => 'opaque-validation', 'accounts' => {
      'TEST' => { 'password' => 'opaque-encrypted-value', 'characters' => [other_entry, entry] }
    } }
  end

  before { File.write(@path, YAML.dump(original)) }

  def change(frontend = 'profanity', **identity)
    described_class.update_launch_settings(@data_dir, 'test', 'Tester', 'GS3',
                                           old_frontend: 'stormfront', custom_launch: nil,
                                           frontend: frontend, **identity)
  end

  it 'changes only the exact saved entry, preserving credentials, favorites and launch data' do
    expect(change).to be true
    expected = Marshal.load(Marshal.dump(original))
    expected['accounts']['TEST']['characters'][1]['frontend'] = 'profanity'
    expect(YAML.load_file(@path)).to eq(expected)
  end

  it 'rejects a duplicate destination without writing' do
    data = original
    data['accounts']['TEST']['characters'] << entry.merge('frontend' => 'profanity')
    File.write(@path, YAML.dump(data))
    before = File.binread(@path)
    expect(change).to be false
    expect(File.binread(@path)).to eq(before)
  end

  it 'refuses an unknown frontend without changing the file' do
    before = File.binread(@path)
    expect(change('not-a-frontend')).to be false
    expect(File.binread(@path)).to eq(before)
  end

  it 'rejects an alias-equivalent destination without writing' do
    data = original
    data['accounts']['TEST']['characters'][1]['frontend'] = 'wizard'
    data['accounts']['TEST']['characters'] << entry.merge('frontend' => 'wrayth')
    File.write(@path, YAML.dump(data))
    before = File.binread(@path)
    expect(change('stormfront', old_frontend: 'wizard')).to be false
    expect(File.binread(@path)).to eq(before)
  end

  it 'refuses a stale selection without changing another entry' do
    before = File.binread(@path)
    expect(change(old_frontend: 'wizard')).to be false
    expect(File.binread(@path)).to eq(before)
  end

  it 'rejects Saga when the saved entry has a custom launch command' do
    before = File.binread(@path)
    expect(change('saga', custom_launch: '/opt/other-client')).to be false
    expect(File.binread(@path)).to eq(before)
  end
end
