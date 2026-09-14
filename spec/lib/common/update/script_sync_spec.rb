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

      expect { sync.sync_repo('broken') }.not_to raise_error
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:render_sync_summary)
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
end
