# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe 'Lich::Util::Update SCRIPT_REPOS registry' do
  it 'defines dr-scripts with :all tracking mode' do
    config = Lich::Util::Update::SCRIPT_REPOS['dr-scripts']
    expect(config[:tracking_mode]).to eq(:all)
    expect(config[:game_filter]).to eq(/^DR/)
    expect(config[:subdirs]).to have_key('profiles')
    expect(config[:subdirs]).to have_key('data')
  end

  it 'defines scripts with :explicit tracking mode and defaults' do
    config = Lich::Util::Update::SCRIPT_REPOS['scripts']
    expect(config[:tracking_mode]).to eq(:explicit)
    expect(config[:game_filter]).to be_nil
    expect(config[:default_tracked]).to include('alias.lic', 'go2.lic', 'map.lic')
  end

  it 'has frozen configs' do
    Lich::Util::Update::SCRIPT_REPOS.each_value do |config|
      expect(config).to be_frozen
    end
  end
end
