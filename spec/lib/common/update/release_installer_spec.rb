# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::ReleaseInstaller do
  subject(:installer) { described_class.new(client, resolver, snapshot_manager) }

  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:resolver) { instance_double(Lich::Util::Update::ChannelResolver) }
  let(:snapshot_manager) { instance_double(Lich::Util::Update::SnapshotManager) }
  let(:release) do
    {
      'tag_name'   => 'v5.19.0',
      'prerelease' => false,
      'body'       => 'Release notes',
      'assets'     => [
        {
          'name'                 => Lich::Util::Update::ASSET_TARBALL_NAME,
          'browser_download_url' => 'https://example.test/lich-5.tar.gz'
        }
      ]
    }
  end
  let(:messages) { [] }

  before do
    allow(client).to receive(:fetch_github_json).and_return(release)
    allow(installer).to receive(:respond) { |message = ''| messages << message }
    allow(installer).to receive(:_respond) { |message| messages << message }
    allow(installer).to receive(:monsterbold_start).and_return('')
    allow(installer).to receive(:monsterbold_end).and_return('')
    stub_const('RUBY_VERSION', '3.4.7')
  end

  describe '#announce' do
    it 'returns when release preparation does not identify an update version' do
      allow(client).to receive(:fetch_github_json).and_return(nil)
      allow(client).to receive(:last_error).and_return(nil)
      allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono)

      expect { installer.announce }.not_to raise_error
    end

    it 'reports a failed release check as one plain message' do
      printed = []
      allow(client).to receive(:fetch_github_json).and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :unavailable, status: 401))
      allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono) { |msg| printed << msg }

      installer.announce

      expect(printed).to eq(['[lich5-update: GitHub check failed. Could not check for a new Lich version; your current installation is unaffected. This is a temporary error that should resolve itself by your next login.]'])
      expect(messages.join).not_to include('prep_update')
    end

    it 'warns about the target Ruby floor and does not invite an incompatible update' do
      allow(client).to receive(:http_get).and_return("REQUIRED_RUBY = '4.0'\n")

      installer.announce

      expect(messages).to include('Lich version 5.19.0 requires Ruby 4.0 or higher.')
      expect(messages).to include('Your current Ruby version is 3.4.7.')
      expect(messages).to include(
        'Upgrade Ruby before updating Lich: https://gswiki.play.net/Lich:Software/Installation'
      )
      expect(messages.grep(/If you are interested in updating/)).to be_empty
    end

    it 'retains the normal update invitation when Ruby satisfies the target floor' do
      allow(client).to receive(:http_get).and_return("REQUIRED_RUBY = '3.0'\n")

      installer.announce

      expect(messages).to include(a_string_matching(/If you are interested in updating, run '.*lich5-update --update' now\./))
      expect(messages.grep(/Upgrade Ruby/)).to be_empty
    end

    it 'retains the normal update invitation when target Ruby metadata is unavailable' do
      allow(client).to receive(:http_get).and_return(nil)

      installer.announce

      expect(messages).to include(a_string_matching(/If you are interested in updating, run '.*lich5-update --update' now\./))
    end
  end
end
