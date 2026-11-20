# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::ScriptSync do
  let(:tmpdir) { Dir.mktmpdir('sync-test') }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:sync) { described_class.new(client) }

  before do
    stub_const('SCRIPT_DIR', tmpdir)
    allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono)
    allow(Lich::Util::Update::StatusReporter).to receive(:render_sync_summary)
  end

  after { FileUtils.remove_entry(tmpdir, true) }

  describe '#filter_syncable_scripts' do
    let(:tree) do
      [
        { 'path' => 'forge.lic', 'type' => 'blob', 'sha' => 'abc' },
        { 'path' => 'pick.lic', 'type' => 'blob', 'sha' => 'def' },
        { 'path' => 'base-setup.lic', 'type' => 'blob', 'sha' => 'ghi' },
        { 'path' => 'data/base-spells.yaml', 'type' => 'blob', 'sha' => 'jkl' },
        { 'path' => 'profiles/base.yaml', 'type' => 'blob', 'sha' => 'mno' },
        { 'path' => 'subdir/nested.lic', 'type' => 'blob', 'sha' => 'pqr' },
      ]
    end

    context 'with :all tracking mode' do
      it 'returns all root .lic files except -setup files' do
        config = { tracking_mode: :all, script_pattern: /^[^\/]+\.lic$/ }

        result = sync.filter_syncable_scripts(tree, config)
        filenames = result.map { |e| e['path'] }

        expect(filenames).to contain_exactly('forge.lic', 'pick.lic')
      end
    end

    context 'with :explicit tracking mode' do
      it 'returns only tracked scripts' do
        config = { tracking_mode: :explicit, script_pattern: /^[^\/]+\.lic$/, default_tracked: %w[forge.lic].freeze }

        result = sync.filter_syncable_scripts(tree, config)
        filenames = result.map { |e| e['path'] }

        expect(filenames).to contain_exactly('forge.lic')
      end
    end
  end

  describe '#sync_repo continues after safe_write failure on one file' do
    it 'downloads remaining files and records the failure' do
      tree = {
        'tree' => [
          { 'path' => 'will-fail.lic', 'type' => 'blob', 'sha' => 'aaa' },
          { 'path' => 'will-succeed.lic', 'type' => 'blob', 'sha' => 'bbb' },
        ]
      }
      config = {
        display_name: 'Test', api_url: 'https://api.example.com/tree',
        raw_base_url: 'https://raw.example.com', tracking_mode: :all,
        script_pattern: /^[^\/]+\.lic$/, game_filter: nil, subdirs: {}
      }
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'test' => config })

      allow(client).to receive(:fetch_github_json).and_return(tree)
      allow(client).to receive(:http_get)
        .with('https://raw.example.com/will-fail.lic', auth: false)
        .and_return("# fail content")
      allow(client).to receive(:http_get)
        .with('https://raw.example.com/will-succeed.lic', auth: false)
        .and_return("# success content")

      call_count = 0
      allow(Lich::Util::Update::FileWriter).to receive(:safe_write) do |path, content|
        call_count += 1
        if File.basename(path) == 'will-fail.lic'
          raise Errno::EACCES, "Permission denied"
        else
          File.binwrite(path, content)
        end
      end

      sync.sync_repo('test')

      expect(File.exist?(File.join(tmpdir, 'will-succeed.lic'))).to be true
      expect(call_count).to eq(2)
      expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).with(
        'Test', 2, ['will-succeed.lic'], {}, [], ['will-fail.lic'], {}, [], missing_tracked: []
      )
    end
  end

  describe '#sync_repo when download fails for some files' do
    it 'records download failures separately from write failures' do
      tree = {
        'tree' => [
          { 'path' => 'net-fail.lic', 'type' => 'blob', 'sha' => 'xxx' },
          { 'path' => 'net-ok.lic', 'type' => 'blob', 'sha' => 'yyy' },
        ]
      }
      config = {
        display_name: 'Mixed', api_url: 'https://api.example.com/tree',
        raw_base_url: 'https://raw.example.com', tracking_mode: :all,
        script_pattern: /^[^\/]+\.lic$/, game_filter: nil, subdirs: {}
      }
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'mixed' => config })

      allow(client).to receive(:fetch_github_json).and_return(tree)
      allow(client).to receive(:http_get)
        .with('https://raw.example.com/net-fail.lic', auth: false).and_return(nil)
      allow(client).to receive(:http_get)
        .with('https://raw.example.com/net-ok.lic', auth: false).and_return("# ok content")
      allow(Lich::Util::Update::FileWriter).to receive(:safe_write) do |path, content|
        File.binwrite(path, content)
      end

      sync.sync_repo('mixed')

      expect(File.exist?(File.join(tmpdir, 'net-ok.lic'))).to be true
      expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).with(
        'Mixed', 2, ['net-ok.lic'], {}, [], ['net-fail.lic'], {}, [], missing_tracked: []
      )
    end
  end

  describe '#sync_repo with unknown repo key' do
    it 'does not crash and reports the error' do
      expect { sync.sync_repo('nonexistent') }.not_to raise_error
    end
  end

  describe '#sync_repo skips repos not matching game_filter' do
    it 'returns silently for GS repo when game is DR' do
      allow(XMLData).to receive(:game).and_return('DR')
      config = {
        display_name: 'GS Only', api_url: 'https://api.example.com/tree',
        raw_base_url: 'https://raw.example.com', tracking_mode: :all,
        script_pattern: /^[^\/]+\.lic$/, game_filter: /^GS/, subdirs: {}
      }
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'gs-only' => config })

      expect(client).not_to receive(:fetch_github_json)
      sync.sync_repo('gs-only')
    end
  end

  describe '#sync_repo when GitHub API returns nil' do
    it 'reports failure and does not crash' do
      config = {
        display_name: 'Broken', api_url: 'https://api.example.com/tree',
        raw_base_url: 'https://raw.example.com', tracking_mode: :all,
        script_pattern: /^[^\/]+\.lic$/, game_filter: nil, subdirs: {}
      }
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'broken' => config })
      allow(client).to receive(:fetch_github_json).and_return(nil)
      allow(client).to receive(:last_error).and_return(nil)

      expect { sync.sync_repo('broken') }.not_to raise_error
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:render_sync_summary)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        /GitHub check failed\. No scripts have been updated this run\. This is a temporary error/
      )
    end
  end

  describe '#sync_all_repos when GitHub fails' do
    let(:printed) { [] }

    def repo(api_url)
      { api_url: api_url, raw_base_url: 'https://raw.example.com', tracking_mode: :all,
        script_pattern: /^[^\/]+\.lic$/, game_filter: nil, subdirs: {} }
    end

    before do
      allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono) { |msg| printed << msg }
      stub_const('Lich::Util::Update::SCRIPT_REPOS', {
        'first'  => repo('https://api.example.com/first'),
        'second' => repo('https://api.example.com/second')
      })
      allow(client).to receive(:http_get).and_return(nil)
    end

    it 'stops after the first GitHub-wide failure and prints exactly one message' do
      allow(Lich::Util::Update::CustomRepos).to receive(:all).and_return({})
      allow(client).to receive(:fetch_github_json).and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :unavailable, status: 401))

      expect(sync.sync_all_repos).to eq(:github_unavailable)

      expect(client).to have_received(:fetch_github_json).once
      expect(printed).to eq(['[lich5-update: GitHub check failed. No scripts have been updated this run. This is a temporary error that should resolve itself by your next login.]'])
    end

    it 'returns nil when every repo was reached' do
      allow(Lich::Util::Update::CustomRepos).to receive(:all).and_return({})
      allow(client).to receive(:fetch_github_json).and_return({ 'tree' => [] })

      expect(sync.sync_all_repos).to be_nil
    end

    it 'keeps going after a repo-specific 404 and names that repo' do
      allow(Lich::Util::Update::CustomRepos).to receive(:all).and_return({})
      allow(client).to receive(:fetch_github_json).with('https://api.example.com/first').and_return(nil)
      allow(client).to receive(:fetch_github_json).with('https://api.example.com/second').and_return({ 'tree' => [] })
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :not_found, status: 404))

      sync.sync_all_repos

      expect(client).to have_received(:fetch_github_json).twice
      expect(printed.first).to include('(first not found)', 'No scripts were updated from first.')
      expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).once
    end

    it 'does not claim nothing was updated when an earlier repo already synced' do
      allow(Lich::Util::Update::CustomRepos).to receive(:all).and_return({})
      allow(client).to receive(:fetch_github_json).with('https://api.example.com/first').and_return({ 'tree' => [] })
      allow(client).to receive(:fetch_github_json).with('https://api.example.com/second').and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :unavailable, status: 401))

      sync.sync_all_repos

      expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).once
      failure = printed.grep(/GitHub check failed/)
      expect(failure.length).to eq(1)
      expect(failure.first).to include('No further scripts have been updated this run.')
      expect(failure.first).not_to include('No scripts have been updated')
    end

    it 'treats a repo-specific refusal like a 404 and carries on' do
      allow(Lich::Util::Update::CustomRepos).to receive(:all).and_return({})
      allow(client).to receive(:fetch_github_json).with('https://api.example.com/first').and_return(nil)
      allow(client).to receive(:fetch_github_json).with('https://api.example.com/second').and_return({ 'tree' => [] })
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :rejected, status: 409))

      sync.sync_all_repos

      expect(client).to have_received(:fetch_github_json).twice
      expect(printed.first).to include('GitHub refused access to first', 'No scripts were updated from first.')
    end

    it 'also stops before custom repos once GitHub is down' do
      allow(Lich::Util::Update::CustomRepos).to receive(:all).and_return({ 'me/repo' => {} })
      allow(client).to receive(:fetch_github_json).and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :network))

      sync.sync_all_repos

      expect(client).to have_received(:fetch_github_json).once
      expect(printed.length).to eq(1)
    end
  end

  describe '#sync_repo skips files whose SHA matches local' do
    it 'does not re-download files that are already current' do
      existing_content = "# already installed\n"
      File.binwrite(File.join(tmpdir, 'current.lic'), existing_content)
      local_sha = git_blob_sha(existing_content)

      tree = { 'tree' => [{ 'path' => 'current.lic', 'type' => 'blob', 'sha' => local_sha }] }
      config = {
        display_name: 'ShaTest', api_url: 'https://api.example.com/tree',
        raw_base_url: 'https://raw.example.com', tracking_mode: :all,
        script_pattern: /^[^\/]+\.lic$/, game_filter: nil, subdirs: {}
      }
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'sha-test' => config })
      allow(client).to receive(:fetch_github_json).and_return(tree)

      expect(client).not_to receive(:http_get)
      sync.sync_repo('sha-test')
    end
  end

  describe '#sync_repo with check_lich_requirement' do
    let(:tree) { { 'tree' => [{ 'path' => 'needy.lic', 'type' => 'blob', 'sha' => 'new' }] } }

    # Load the real Script so the header parser and version check are exercised
    # through sync_repo; torn down the same way as script_version_gate_spec.rb.
    before(:context) do
      require_relative '../../../../lib/common/script'
    end

    after(:context) do
      %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
        Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
      end
      $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
    end

    before do
      stub_const('LICH_VERSION', '5.22.0')
      allow(client).to receive(:fetch_github_json).and_return(tree)
      allow(client).to receive(:http_get).and_return("=begin\n  required: Lich >= 5.23.0\n=end\necho 'hi'\n")
    end

    def config(check)
      {
        display_name: 'Req', api_url: 'https://api.example.com/tree',
        raw_base_url: 'https://raw.example.com', tracking_mode: :all,
        script_pattern: /^[^\/]+\.lic$/, game_filter: nil, subdirs: {},
        check_lich_requirement: check
      }
    end

    after { UserVars.held_scripts = nil }

    it 'keeps the local copy and reports the script as needing a newer Lich' do
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'req' => config(true) })
      File.binwrite(File.join(tmpdir, 'needy.lic'), "echo 'runs on 5.22'\n")

      expect(Lich::Util::Update::FileWriter).not_to receive(:safe_write)
      sync.sync_repo('req')
      expect(File.binread(File.join(tmpdir, 'needy.lic'))).to eq("echo 'runs on 5.22'\n")
      expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).with(
        'Req', 1, [], {}, [], [], {}, [['needy.lic', '5.23.0']], missing_tracked: []
      )
    end

    it 'installs the script once the running Lich meets the requirement' do
      stub_const('LICH_VERSION', '5.23.0')
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'req' => config(true) })

      expect(Lich::Util::Update::FileWriter).to receive(:safe_write).with(File.join(tmpdir, 'needy.lic'), anything)
      sync.sync_repo('req')
    end

    it 'ignores the header when the repo does not opt in' do
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'req' => config(nil) })

      expect(Lich::Util::Update::FileWriter).to receive(:safe_write).with(File.join(tmpdir, 'needy.lic'), anything)
      sync.sync_repo('req')
    end
  end

  describe '#sync_repo when the newest version of a script needs a newer Lich' do
    include_context 'with the real script floor reader'

    let(:raw) { 'https://raw.githubusercontent.com/acme/scripts' }
    let(:commits_url) { 'https://api.github.com/repos/acme/scripts/commits?sha=master&path=scripts%2Fneedy.lic&per_page=30' }
    let(:shas) { %w[a b c d].map { |letter| letter * 40 } }
    let(:newest) { script_requiring('5.26.0', 'v4') }
    let(:compatible) { script_requiring('5.25.0', 'v2') }
    let(:history) { [newest, script_requiring('5.26.0', 'v3'), compatible, script_requiring('5.24.0', 'v1')] }
    let(:live_path) { File.join(tmpdir, 'needy.lic') }
    let(:tree) { { 'tree' => [{ 'path' => 'scripts/needy.lic', 'type' => 'blob', 'sha' => git_blob_sha(newest) }] } }
    let(:config) do
      {
        display_name: 'Core', api_url: 'https://api.github.com/repos/acme/scripts/git/trees/master?recursive=1',
        raw_base_url: "#{raw}/master", tracking_mode: :all, script_pattern: /^scripts\/[^\/]+\.lic$/,
        game_filter: nil, subdirs: {}, check_lich_requirement: true
      }
    end
    let(:summaries) { [] }

    before do
      stub_const('LICH_VERSION', '5.25.1')
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'core' => config })
      UserVars.held_scripts = nil
      allow(Vars).to receive(:save)
      allow(Lich::Util::Update::StatusReporter).to receive(:render_sync_summary) { |*args, **| summaries << args[7] }
      allow(client).to receive(:last_error).and_return(nil)
      allow(client).to receive(:fetch_github_json).with(config[:api_url]) { tree }
      allow(client).to receive(:fetch_github_json).with(commits_url) { history.each_index.map { |index| { 'sha' => shas[index] } } }
      allow(client).to receive(:http_get).with("#{raw}/master/scripts/needy.lic", auth: false) { newest }
      shas.each_with_index do |sha, index|
        allow(client).to receive(:http_get).with("#{raw}/#{sha}/scripts/needy.lic", auth: false) { history[index] }
      end
    end

    after { UserVars.held_scripts = nil }

    def remembered
      UserVars.held_scripts&.dig('core', 'needy.lic')
    end

    context 'when the script is not installed' do
      it 'installs the newest version in the history that the running Lich can run' do
        sync.sync_repo('core')

        expect(File.binread(live_path)).to eq(compatible)
        expect(summaries).to eq([[['needy.lic', '5.26.0', :installed_compatible, shas[2]]]])
      end

      it 'stops at that version without reading anything older' do
        sync.sync_repo('core')

        expect(client).to have_received(:http_get).with("#{raw}/#{shas[2]}/scripts/needy.lic", auth: false).once
        expect(client).not_to have_received(:http_get).with("#{raw}/#{shas[3]}/scripts/needy.lic", auth: false)
      end

      it 'installs nothing and says so when no version in the history can run here' do
        history.replace([newest, script_requiring('5.26.0', 'v3')])

        sync.sync_repo('core')

        expect(File.exist?(live_path)).to be(false)
        expect(summaries).to eq([[['needy.lic', '5.26.0', :none_compatible]]])
      end

      it 'looks no further back than the bound on the history walk' do
        stub_const('Lich::Util::Update::ScriptFloor::MAX_HISTORY', 2)
        allow(client).to receive(:fetch_github_json)
          .with(commits_url.sub('per_page=30', 'per_page=2')) { shas.map { |sha| { 'sha' => sha } } }

        sync.sync_repo('core')

        expect(File.exist?(live_path)).to be(false)
        expect(client).not_to have_received(:http_get).with("#{raw}/#{shas[2]}/scripts/needy.lic", auth: false)
        expect(summaries).to eq([[['needy.lic', '5.26.0', :none_compatible]]])
      end

      it 'reports the script, writes nothing and tries again next time when the history cannot be read' do
        printed = []
        allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono) { |text| printed << text }
        allow(client).to receive(:fetch_github_json).with(commits_url).and_return(nil)
        allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :rate_limited, status: 403))

        2.times { sync.sync_repo('core') }

        expect(File.exist?(live_path)).to be(false)
        expect(summaries).to eq([[['needy.lic', '5.26.0', :history_unavailable]]] * 2)
        expect(printed.grep(/GitHub check failed \(rate limit reached\)\. Older versions of scripts in Core that need a newer Lich could not be checked\./).size).to eq(2)
        expect(client).to have_received(:fetch_github_json).with(commits_url).twice
        expect(remembered).to be_nil
      end
    end

    context 'when the installed copy is the newest version and its floor is not met' do
      before { File.binwrite(live_path, newest) }

      it 'replaces it with the newest version the running Lich can run' do
        sync.sync_repo('core')

        expect(File.binread(live_path)).to eq(compatible)
        expect(summaries).to eq([[['needy.lic', '5.26.0', :installed_compatible, shas[2]]]])
      end

      it 'works from the installed bytes instead of downloading the same version again' do
        sync.sync_repo('core')

        expect(client).to have_received(:fetch_github_json).with(commits_url).once
        expect(client).not_to have_received(:http_get).with("#{raw}/master/scripts/needy.lic", auth: false)
      end

      it 'leaves it alone when the running Lich meets its floor' do
        stub_const('LICH_VERSION', '5.26.0')

        sync.sync_repo('core')

        expect(File.binread(live_path)).to eq(newest)
        expect(client).not_to have_received(:http_get)
        expect(summaries).to eq([[]])
      end
    end

    context 'when the installed copy is another version' do
      it 'replaces a copy whose own floor is not met' do
        File.binwrite(live_path, script_requiring('5.26.0', 'v3'))

        sync.sync_repo('core')

        expect(File.binread(live_path)).to eq(compatible)
      end

      it 'keeps a copy the running Lich can run, without reading the history' do
        File.binwrite(live_path, script_requiring('5.24.0', 'v1'))

        sync.sync_repo('core')

        expect(File.binread(live_path)).to eq(script_requiring('5.24.0', 'v1'))
        expect(client).not_to have_received(:fetch_github_json).with(commits_url)
        expect(summaries).to eq([[['needy.lic', '5.26.0']]])
      end
    end

    it 'installs the newest version once the running Lich meets its floor' do
      stub_const('LICH_VERSION', '5.26.0')

      sync.sync_repo('core')

      expect(File.binread(live_path)).to eq(newest)
      expect(client).not_to have_received(:fetch_github_json).with(commits_url)
      expect(summaries).to eq([[]])
    end

    it 'does not search the history of a repo that does not check floors' do
      config.delete(:check_lich_requirement)

      sync.sync_repo('core')

      expect(File.binread(live_path)).to eq(newest)
      expect(client).not_to have_received(:fetch_github_json).with(commits_url)
    end

    describe 'remembering the decision' do
      it 'records the remote SHA, the running Lich version and the commit installed' do
        sync.sync_repo('core')

        expect(remembered).to eq(
          'remote_sha' => git_blob_sha(newest), 'lich_version' => '5.25.1', 'local_sha' => git_blob_sha(compatible),
          'required' => '5.26.0', 'outcome' => 'installed', 'commit' => shas[2]
        )
        expect(Vars).to have_received(:save).once
      end

      it 'repeats neither the download nor the history walk while nothing has changed' do
        sync.sync_repo('core')
        sync.sync_repo('core')

        expect(client).to have_received(:fetch_github_json).with(commits_url).once
        expect(client).to have_received(:http_get).with("#{raw}/master/scripts/needy.lic", auth: false).once
        expect(Vars).to have_received(:save).once
      end

      it 'keeps reporting the script as needing a newer Lich, as a held script was before' do
        sync.sync_repo('core')
        sync.sync_repo('core')

        expect(summaries).to eq([[['needy.lic', '5.26.0', :installed_compatible, shas[2]]], [['needy.lic', '5.26.0']]])
      end

      it 'is read back by a later session, which has a new sync object' do
        sync.sync_repo('core')

        described_class.new(client).sync_repo('core')

        expect(client).to have_received(:fetch_github_json).with(commits_url).once
      end

      it 'remembers that a local copy was kept, and skips the download next time' do
        File.binwrite(live_path, script_requiring('5.24.0', 'v1'))

        2.times { sync.sync_repo('core') }

        expect(remembered).to include('outcome' => 'held', 'local_sha' => git_blob_sha(script_requiring('5.24.0', 'v1')))
        expect(client).to have_received(:http_get).with("#{raw}/master/scripts/needy.lic", auth: false).once
        expect(summaries).to eq([[['needy.lic', '5.26.0']]] * 2)
      end

      it 'remembers that no version can run here, and skips the walk next time' do
        history.replace([newest])

        2.times { sync.sync_repo('core') }

        expect(remembered).to include('outcome' => 'none', 'local_sha' => nil)
        expect(client).to have_received(:fetch_github_json).with(commits_url).once
        expect(summaries).to eq([[['needy.lic', '5.26.0', :none_compatible]]] * 2)
      end

      it 'checks again when the remote SHA changes' do
        sync.sync_repo('core')
        newer = script_requiring('5.26.0', 'v5')
        tree['tree'].first['sha'] = git_blob_sha(newer)
        allow(client).to receive(:http_get).with("#{raw}/master/scripts/needy.lic", auth: false).and_return(newer)

        sync.sync_repo('core')

        expect(client).to have_received(:http_get).with("#{raw}/master/scripts/needy.lic", auth: false).twice
        expect(File.binread(live_path)).to eq(compatible)
        expect(remembered).to include('remote_sha' => git_blob_sha(newer), 'outcome' => 'held')
      end

      it 'checks again when the running Lich version changes, and installs the newest version it now meets' do
        sync.sync_repo('core')
        expect(remembered).to include('lich_version' => '5.25.1')
        stub_const('LICH_VERSION', '5.26.0')

        sync.sync_repo('core')

        expect(File.binread(live_path)).to eq(newest)
        expect(remembered).to be_nil
        expect(summaries.last).to eq([])
      end

      it 'checks again when the installed copy is deleted' do
        sync.sync_repo('core')
        File.delete(live_path)

        sync.sync_repo('core')

        expect(File.binread(live_path)).to eq(compatible)
        expect(client).to have_received(:fetch_github_json).with(commits_url).twice
      end

      it 'checks again, whatever was remembered, when forced' do
        sync.sync_repo('core')

        sync.sync_repo('core', force: true)

        expect(client).to have_received(:http_get).with("#{raw}/master/scripts/needy.lic", auth: false).twice
        expect(File.binread(live_path)).to eq(compatible)
      end

      it 'forgets a script the sync no longer covers' do
        sync.sync_repo('core')
        expect(remembered).to include('outcome' => 'installed')
        tree['tree'].clear

        sync.sync_repo('core')

        expect(remembered).to be_nil
      end

      it 'remembers nothing when the write fails, so the next sync tries again' do
        allow(Lich::Util::Update::FileWriter).to receive(:safe_write).and_raise(Errno::EACCES, 'Permission denied')

        sync.sync_repo('core')

        expect(Lich::Util::Update::FileWriter).to have_received(:safe_write).with(live_path, compatible)
        expect(remembered).to be_nil
      end

      # raw.githubusercontent.com serves a branch path from its cache for up
      # to five minutes after a push, while the file list is already current.
      context 'when the branch download is older than the version the file list names' do
        let(:kept) { script_requiring('5.24.0', 'v1') }
        let(:released) { "# v5 needs no particular Lich\necho 'v5'\n" }

        before do
          File.binwrite(live_path, kept)
          tree['tree'].first['sha'] = git_blob_sha(released)
        end

        it 'keeps a runnable local copy for this sync only, and installs the listed version once the download catches up' do
          sync.sync_repo('core')

          expect(File.binread(live_path)).to eq(kept)
          expect(remembered).to be_nil

          allow(client).to receive(:http_get).with("#{raw}/master/scripts/needy.lic", auth: false).and_return(released)
          sync.sync_repo('core')

          expect(File.binread(live_path)).to eq(released)
        end

        it 'does not remember that no version can run here' do
          File.delete(live_path)
          history.replace([newest])

          sync.sync_repo('core')

          expect(summaries).to eq([[['needy.lic', '5.26.0', :none_compatible]]])
          expect(remembered).to be_nil
        end
      end
    end
  end

  describe '#sync_repo reports tracked names the repo does not contain' do
    let(:tree) { { 'tree' => [{ 'path' => 'scripts/kept.lic', 'type' => 'blob', 'sha' => 'aaa' }] } }
    let(:config) do
      {
        display_name: 'Test', api_url: 'https://api.example.com/tree',
        raw_base_url: 'https://raw.example.com', tracking_mode: :explicit,
        script_pattern: /^scripts\/[^\/]+\.lic$/, game_filter: nil, subdirs: {},
        default_tracked: %w[kept.lic gone-default.lic].freeze
      }
    end

    before do
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'test' => config })
      UserVars.tracked_scripts = { 'test' => ['typo.lic'] }
      allow(client).to receive(:fetch_github_json).and_return(tree)
      allow(client).to receive(:http_get).and_return('# kept')
      allow(Lich::Util::Update::FileWriter).to receive(:safe_write)
    end

    after { UserVars.tracked_scripts = nil }

    it 'passes each missing name with how to remove it, without an extra GitHub read' do
      sync.sync_repo('test')

      expect(client).to have_received(:fetch_github_json).once
      expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).with(
        'Test', 1, ['kept.lic'], {}, [], [], {}, [],
        missing_tracked: [
          ['gone-default.lic', 'not in repo, not synced (default script)'],
          ['typo.lic', "not in repo, not synced (remove with #{$clean_lich_char}lich5-update --untrack=test:typo.lic)"]
        ]
      )
    end

    it 'names the repo file an old entry meant when only case or .lic differs' do
      UserVars.tracked_scripts = { 'test' => ['Kept.lic', 'kept'] }

      sync.sync_repo('test')

      expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).with(
        'Test', 1, ['kept.lic'], {}, [], [], {}, [],
        missing_tracked: [
          ['gone-default.lic', 'not in repo, not synced (default script)'],
          ['Kept.lic', "not in repo, not synced (the repo has 'kept.lic'; remove with #{$clean_lich_char}lich5-update --untrack=test:Kept.lic)"],
          ['kept', "not in repo, not synced (the repo has 'kept.lic'; remove with #{$clean_lich_char}lich5-update --untrack=test:kept)"]
        ]
      )
    end

    it 'reports nothing missing for an :all-mode repo' do
      config[:tracking_mode] = :all
      UserVars.tracked_scripts = { 'test' => ['leftover.lic'] }

      sync.sync_repo('test')

      expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary)
        .with(anything, anything, anything, anything, anything, anything, anything, anything, missing_tracked: [])
    end
  end

  describe Lich::Util::Update::StatusReporter, '.render_sync_summary' do
    it 'lists a held-back script instead of reporting everything up to date' do
      allow(described_class).to receive(:render_sync_summary).and_call_original
      output = nil
      allow(described_class).to receive(:respond_mono) { |text| output = text }

      described_class.render_sync_summary('Req', 1, [], {}, [], [], {}, [['needy.lic', '5.23.0']])

      expect(output).to include('needy.lic', 'needs Lich 5.23.0+ (not updated)', '1 need newer Lich')
      expect(output).not_to include('all up to date')
    end

    it 'says what was done for a held-back script when the local copy was not simply kept' do
      allow(described_class).to receive(:render_sync_summary).and_call_original
      output = nil
      allow(described_class).to receive(:respond_mono) { |text| output = text }
      held = [
        ['kept.lic', '5.26.0'], ['fell-back.lic', '5.26.0', :installed_compatible, '46da55d0' + ('0' * 32)],
        ['nothing.lic', '5.27.0', :none_compatible], ['unknown.lic', '5.26.0', :history_unavailable]
      ]

      described_class.render_sync_summary('Core', 4, [], {}, [], [], {}, held)

      expect(output).to include(
        'needs Lich 5.26.0+ (not updated)', 'needs Lich 5.26.0+ (installed newest compatible version, commit 46da55d)',
        'needs Lich 5.27.0+ (no compatible version found)', 'needs Lich 5.26.0+ (older versions not checked; will retry next login)',
        'Total: 1 updated, 4 need newer Lich'
      )
    end

    it 'lists tracked names missing from the repo instead of reporting everything up to date' do
      allow(described_class).to receive(:render_sync_summary).and_call_original
      output = nil
      allow(described_class).to receive(:respond_mono) { |text| output = text }

      described_class.render_sync_summary('Core', 3, [], {}, [], [], {}, [], missing_tracked: [['typo.lic', 'not in repo, not synced (x)']])

      expect(output).to include('typo.lic', 'not in repo, not synced (x)', '1 tracked but not in repo', '3 found, up to date')
      expect(output).not_to include('all up to date')
    end
  end
end
