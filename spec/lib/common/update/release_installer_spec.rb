# frozen_string_literal: true

require 'socket'
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

  describe 'beta confirmation' do
    let(:window) { described_class::BETA_CONFIRM_WINDOW }

    describe '#prep_betatest without a file type' do
      # Swap real sockets in for both client globals, restoring them afterwards,
      # so the examples can prove the notice step never reads client input.
      around do |example|
        saved_client = $_CLIENT_
        saved_detachable = $_DETACHABLE_CLIENT_
        @frontend_side, @lich_side = UNIXSocket.pair
        @detach_frontend_side, @detach_lich_side = UNIXSocket.pair
        $_CLIENT_ = @lich_side
        $_DETACHABLE_CLIENT_ = @detach_lich_side
        example.run
      ensure
        $_CLIENT_ = saved_client
        $_DETACHABLE_CLIENT_ = saved_detachable
        [@frontend_side, @lich_side, @detach_frontend_side, @detach_lich_side].each { |io| io&.close unless io&.closed? }
      end

      it 'returns at once instead of waiting for client input' do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        installer.prep_betatest

        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.0
      end

      it 'leaves every typed line on both client sockets for the normal input loops' do
        @frontend_side.write("look\n;send Y\n")
        @detach_frontend_side.write("north\n")

        installer.prep_betatest

        expect(@lich_side.read_nonblock(100)).to eq("look\n;send Y\n")
        expect(@detach_lich_side.read_nonblock(100)).to eq("north\n")
      end

      it 'never installs on its own, even when a confirming line is already waiting' do
        allow(resolver).to receive(:resolve_channel_ref).and_return(nil)
        allow(resolver).to receive(:last_error).and_return(nil)
        @frontend_side.write(";send Y\n")

        installer.prep_betatest

        expect(resolver).not_to have_received(:resolve_channel_ref)
        expect(messages.grep(/accepted/)).to be_empty
      end

      it 'tells the user how and how long to confirm, without the old send prompt' do
        installer.prep_betatest

        expect(messages).to include(a_string_matching(/To confirm your participation, run:  .*lich5-update --beta --confirm\z/))
        expect(messages).to include(a_string_matching(/You have #{window} seconds to confirm\./))
        expect(messages.grep(/send Y|send N/)).to be_empty
      end
    end

    describe '#prep_betatest with a file type' do
      it 'updates the single file from the beta channel and opens no confirmation window' do
        file_updater = instance_double(Lich::Util::Update::FileUpdater)
        allow(Lich::Util::Update::FileUpdater).to receive(:new).and_return(file_updater)
        expect(file_updater).to receive(:update_file).with('library', 'foo.rb', 'beta')

        installer.prep_betatest('library', 'foo.rb')
        installer.confirm_betatest

        expect(messages).to include(a_string_matching(/There is no beta test request to confirm/))
      end
    end

    describe '#confirm_betatest' do
      let(:clock) { [1000.0] }

      def advance(seconds)
        clock[0] += seconds
      end

      before do
        allow(installer).to receive(:monotonic_now) { clock.first }
        allow(resolver).to receive(:resolve_channel_ref).with(:beta).and_return(nil)
        allow(resolver).to receive(:last_error).and_return(nil)
      end

      it 'refuses when no notice was shown' do
        installer.confirm_betatest

        expect(messages).to include(a_string_matching(/There is no beta test request to confirm\.  Run .*lich5-update --beta first/))
        expect(resolver).not_to have_received(:resolve_channel_ref)
      end

      it 'installs when confirmed inside the window' do
        installer.prep_betatest
        advance(5)
        installer.confirm_betatest

        expect(messages).to include('Beta test installation accepted.  Thank you for considering!')
        expect(resolver).to have_received(:resolve_channel_ref).with(:beta).once
        expect(messages).to include('No viable beta found. Aborting beta update.')
      end

      it 'accepts a confirmation at exactly the end of the window' do
        installer.prep_betatest
        advance(window)
        installer.confirm_betatest

        expect(resolver).to have_received(:resolve_channel_ref).once
      end

      it 'refuses a confirmation just after the window and does not install' do
        installer.prep_betatest
        advance(window + 0.001)
        installer.confirm_betatest

        expect(messages).to include(a_string_matching(/Your beta test request expired after #{window} seconds/))
        expect(resolver).not_to have_received(:resolve_channel_ref)
      end

      it 'consumes an expired notice, so a later confirmation needs a fresh notice' do
        installer.prep_betatest
        advance(window + 1)
        installer.confirm_betatest
        messages.clear
        installer.confirm_betatest

        expect(messages).to include(a_string_matching(/There is no beta test request to confirm/))
        expect(resolver).not_to have_received(:resolve_channel_ref)
      end

      it 'accepts one confirmation per notice' do
        installer.prep_betatest
        installer.confirm_betatest
        installer.confirm_betatest

        expect(resolver).to have_received(:resolve_channel_ref).once
        expect(messages.grep(/There is no beta test request to confirm/).size).to eq(1)
      end

      it 'restarts the window when the notice is shown again' do
        installer.prep_betatest
        advance(window - 1)
        installer.prep_betatest
        advance(window - 1)
        installer.confirm_betatest

        expect(resolver).to have_received(:resolve_channel_ref).once
      end

      it 'checks and clears the notice under the lock, so racing confirmations install once' do
        installer.prep_betatest
        confirmers = []
        begin
          described_class::BETA_LOCK.synchronize do
            confirmers = Array.new(2) { Thread.new { installer.confirm_betatest } }
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
            until confirmers.all? { |t| t.status == 'sleep' || !t.alive? } ||
                  Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
              Thread.pass
            end

            # Both confirmers are parked on the lock: neither has read or
            # cleared the notice, and nothing has been installed.
            expect(confirmers.map(&:status)).to eq(%w[sleep sleep])
            expect(installer.instance_variable_get(:@beta_prompted_at)).not_to be_nil
            expect(resolver).not_to have_received(:resolve_channel_ref)
          end
        ensure
          confirmers.each(&:join)
        end

        expect(resolver).to have_received(:resolve_channel_ref).once
        expect(messages.grep(/There is no beta test request to confirm/).size).to eq(1)
      end

      it 'still arms and confirms on an installer built without the current initializer' do
        # An installer memoized at login keeps its ivars when this file is
        # reloaded in place, so the lock must not live in #initialize.
        legacy = described_class.allocate
        legacy.instance_variable_set(:@resolver, resolver)
        allow(legacy).to receive(:respond) { |message = ''| messages << message }

        legacy.prep_betatest
        legacy.confirm_betatest

        expect(messages).to include('Beta test installation accepted.  Thank you for considering!')
        expect(resolver).to have_received(:resolve_channel_ref).with(:beta).once
      end

      it 'reports a GitHub failure while resolving the beta' do
        error = Lich::Util::Update::FetchError.new(kind: :unavailable, status: 503)
        allow(resolver).to receive(:last_error).and_return(error)
        expect(Lich::Util::Update::StatusReporter).to receive(:respond_github_failure).with(error, 'No beta update was installed.')

        installer.prep_betatest
        installer.confirm_betatest
      end

      it 'downloads the release asset of the resolved prerelease' do
        allow(resolver).to receive(:resolve_channel_ref).with(:beta).and_return('v5.20.0-beta.1')
        releases = [
          { 'tag_name' => 'v5.19.0', 'prerelease' => false, 'assets' => [] },
          {
            'tag_name'   => 'v5.20.0-beta.1',
            'prerelease' => true,
            'body'       => "Beta notes\n## What's Changed\n* stuff",
            'assets'     => [{ 'name' => Lich::Util::Update::ASSET_TARBALL_NAME, 'browser_download_url' => 'https://example.test/beta.tar.gz' }]
          }
        ]
        releases_url = "https://api.github.com/repos/#{Lich::Util::Update::GITHUB_REPO}/releases"
        allow(URI).to receive(:parse).and_call_original
        allow(URI).to receive(:parse).with(releases_url).and_return(double(open: StringIO.new(JSON.generate(releases))))
        expect(installer).to receive(:download_release_update)

        installer.prep_betatest
        installer.confirm_betatest

        expect(installer.instance_variable_get(:@update_to)).to eq('5.20.0-beta.1')
        expect(installer.instance_variable_get(:@zipfile)).to eq('https://example.test/beta.tar.gz')
        expect(installer.instance_variable_get(:@new_features)).to eq("Beta notes\n")
      end
    end
  end
end
