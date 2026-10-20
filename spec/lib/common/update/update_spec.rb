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

RSpec.describe 'Lich::Util::Update.request beta routing' do
  let(:update) { Lich::Util::Update }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:resolver) { instance_double(Lich::Util::Update::ChannelResolver, last_error: nil) }
  let(:snapshot_manager) { instance_double(Lich::Util::Update::SnapshotManager) }
  let(:installer) { Lich::Util::Update::ReleaseInstaller.new(client, resolver, snapshot_manager) }
  let(:messages) { [] }

  before do
    allow(update).to receive(:release_installer).and_return(installer)
    allow(installer).to receive(:respond) { |message = ''| messages << message }
    allow(update).to receive(:respond) { |message = ''| messages << message }
    allow(resolver).to receive(:resolve_channel_ref).with(:beta).and_return(nil)
  end

  ['--beta --confirm', '--beta confirm', '--test --confirm', '--test confirm', '--beta --confirm '].each do |form|
    it "installs after the notice when confirmed with '#{form}'" do
      update.request('--beta')
      update.request(form)

      expect(resolver).to have_received(:resolve_channel_ref).with(:beta).once
      expect(messages).to include('No viable beta found. Aborting beta update.')
    end
  end

  it 'does not install from a confirmation that was never preceded by the notice' do
    update.request('--beta --confirm')

    expect(resolver).not_to have_received(:resolve_channel_ref)
    expect(messages).to include(a_string_matching(/There is no beta test request to confirm/))
  end

  ['--beta --confirmed', '--beta --confirm --library=foo.rb', '--beta --CONFIRM', '--beta-confirm'].each do |form|
    it "does not treat '#{form}' as a confirmation" do
      update.request('--beta')
      update.request(form)

      expect(resolver).not_to have_received(:resolve_channel_ref)
    end
  end

  it 'still routes a single-file beta update to the file updater' do
    expect(installer).to receive(:prep_betatest).with('library', 'foo.rb')

    update.request('--beta --library=foo.rb')
  end

  it 'documents the beta commands in the help text' do
    update.request('--help')
    help = messages.join("\n")

    expect(help).to include('lich5-update --beta --confirm')
    expect(help).to match(/lich5-update --beta\s+Show the beta notice; confirm within #{Lich::Util::Update::ReleaseInstaller::BETA_CONFIRM_WINDOW} seconds/)
    expect(help).to include('lich5-update --beta --library=<name>')
  end
end
