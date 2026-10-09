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
        'Test', 2, ['will-succeed.lic'], {}, [], ['will-fail.lic'], {}
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
        'Mixed', 2, ['net-ok.lic'], {}, [], ['net-fail.lic'], {}
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

      sync.sync_all_repos

      expect(client).to have_received(:fetch_github_json).once
      expect(printed).to eq(['[lich5-update: GitHub check failed. No scripts have been updated this run. This is a temporary error that should resolve itself by your next login.]'])
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
    let(:script) { double('Script', required_lich_version_in: '9.0.0', lich_version_satisfied?: false) }

    before do
      stub_const('Lich::Common::Script', script)
      allow(client).to receive(:fetch_github_json).and_return(tree)
      allow(client).to receive(:http_get).and_return("# required: Lich >= 9.0.0\n")
    end

    def config(check)
      {
        display_name: 'Req', api_url: 'https://api.example.com/tree',
        raw_base_url: 'https://raw.example.com', tracking_mode: :all,
        script_pattern: /^[^\/]+\.lic$/, game_filter: nil, subdirs: {},
        check_lich_requirement: check
      }
    end

    it 'does not install a script that needs a newer Lich' do
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'req' => config(true) })

      expect(Lich::Util::Update::FileWriter).not_to receive(:safe_write)
      expect(Lich::Util::Update::StatusReporter).to receive(:respond_mono).with(/needy\.lic not updated, it requires Lich 9\.0\.0\+/)
      sync.sync_repo('req')
    end

    it 'ignores the header when the repo does not opt in' do
      stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'req' => config(nil) })

      expect(Lich::Util::Update::FileWriter).to receive(:safe_write).with(File.join(tmpdir, 'needy.lic'), anything)
      sync.sync_repo('req')
    end
  end
end
