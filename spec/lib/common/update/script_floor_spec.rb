# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::ScriptFloor do
  include_context 'with the real script floor reader'

  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:floor) { described_class.new(client) }
  let(:source) { { repo: 'acme/scripts', branch: 'master' } }
  let(:commits_url) { 'https://api.github.com/repos/acme/scripts/commits?sha=master&path=scripts%2Ffoo.lic&per_page=30' }
  let(:shas) { %w[a b c d].map { |letter| letter * 40 } }

  before { stub_const('LICH_VERSION', '5.25.1') }

  def raw_url(sha)
    "https://raw.githubusercontent.com/acme/scripts/#{sha}/scripts/foo.lic"
  end

  # Stubs the commit list, newest first, and the file as it was at each
  # commit: content, or a FetchError kind for a read that fails.
  def stub_history(versions)
    commits = versions.each_index.map { |index| { 'sha' => shas[index] } }
    allow(client).to receive(:fetch_github_json).with(commits_url).and_return(commits)
    versions.each_with_index do |version, index|
      allow(client).to receive(:http_get).with(raw_url(shas[index]), auth: false) do
        allow(client).to receive(:last_error).and_return(version.is_a?(Symbol) ? Lich::Util::Update::FetchError.new(kind: version) : nil)
        version.is_a?(Symbol) ? nil : version
      end
    end
  end

  describe '.unmet' do
    it 'returns the floor of a script the running Lich cannot run' do
      expect(described_class.unmet(script_requiring('5.26.0'))).to eq('5.26.0')
    end

    it 'returns nil for a floor the running Lich meets, and for a script with none' do
      expect(described_class.unmet(script_requiring('5.25.1'))).to be_nil
      expect(described_class.unmet("echo 'hi'\n")).to be_nil
    end

    it 'reads the floor of a script holding bytes that are not UTF-8, however the text is tagged' do
      latin1_e_acute = 233.chr
      script = "=begin\n  author: caf#{latin1_e_acute}\n  required: Lich >= 5.26.0\n=end\necho 'x'\r\n"

      expect(described_class.unmet(script.b)).to eq('5.26.0')
      expect(described_class.unmet(script.dup.force_encoding('UTF-8'))).to eq('5.26.0')
    end

    it 'counts a prerelease as the release it leads up to, as a starting script does' do
      stub_const('LICH_VERSION', '5.26.0-beta.1')

      expect(described_class.unmet(script_requiring('5.26.0'))).to be_nil
    end
  end

  describe '.source_for' do
    it 'reads the repository and branch from a built-in repo config' do
      config = { api_url: 'https://api.github.com/repos/elanthia-online/scripts/git/trees/master?recursive=1' }

      expect(described_class.source_for(config)).to eq(repo: 'elanthia-online/scripts', branch: 'master')
    end

    it 'keeps the slashes of a custom repo branch' do
      config = Lich::Util::Update::CustomRepos.build_config('me/repo', 'branch' => 'feature/x')

      expect(described_class.source_for(config)).to eq(repo: 'me/repo', branch: 'feature/x')
    end

    it 'returns nil for a config that does not name a GitHub file list' do
      expect(described_class.source_for(api_url: 'https://api.example.com/tree')).to be_nil
    end
  end

  describe '#newest_compatible' do
    it 'returns the first version, newest first, whose floor the running Lich meets' do
      stub_history([script_requiring('5.26.0', 'v4'), script_requiring('5.26.0', 'v3'), script_requiring('5.25.0', 'v2'), script_requiring('5.24.0', 'v1')])

      result = floor.newest_compatible(source, 'scripts/foo.lic')

      expect(result.to_h).to include(status: :found, content: script_requiring('5.25.0', 'v2'), commit: shas[2], examined: 3)
    end

    it 'stops at that version without reading anything older' do
      stub_history([script_requiring('5.26.0'), script_requiring('5.25.0'), script_requiring('5.24.0')])

      floor.newest_compatible(source, 'scripts/foo.lic')

      expect(client).not_to have_received(:http_get).with(raw_url(shas[2]), auth: false)
    end

    it 'takes a version that declares no floor as one this Lich can run' do
      stub_history([script_requiring('5.26.0'), "echo 'no header'\n"])

      expect(floor.newest_compatible(source, 'scripts/foo.lic').to_h).to include(status: :found, commit: shas[1])
    end

    it 'reports none when no version in the history can run here' do
      stub_history([script_requiring('5.27.0'), script_requiring('5.26.0')])

      expect(floor.newest_compatible(source, 'scripts/foo.lic').to_h).to include(status: :none, examined: 2, content: nil)
    end

    it 'examines at most MAX_HISTORY commits, even when GitHub returns more' do
      stub_const("#{described_class}::MAX_HISTORY", 2)
      commits = shas.map { |sha| { 'sha' => sha } }
      allow(client).to receive(:fetch_github_json)
        .with('https://api.github.com/repos/acme/scripts/commits?sha=master&path=scripts%2Ffoo.lic&per_page=2').and_return(commits)
      allow(client).to receive(:http_get).and_return(script_requiring('5.26.0'))
      allow(client).to receive(:http_get).with(raw_url(shas[3]), auth: false).and_return(script_requiring('5.20.0'))

      result = floor.newest_compatible(source, 'scripts/foo.lic')

      expect(result.to_h).to include(status: :none, examined: 2)
      expect(client).to have_received(:http_get).twice
    end

    it 'passes over a commit at which the file does not exist' do
      stub_history([script_requiring('5.26.0'), :not_found, script_requiring('5.25.0')])

      expect(floor.newest_compatible(source, 'scripts/foo.lic').to_h).to include(status: :found, commit: shas[2], examined: 2)
    end

    it 'fails, rather than reaching past it, when a version cannot be read' do
      stub_history([script_requiring('5.26.0'), :network, script_requiring('5.25.0')])

      result = floor.newest_compatible(source, 'scripts/foo.lic')

      expect(result.status).to eq(:failed)
      expect(result.error.kind).to eq(:network)
      expect(client).not_to have_received(:http_get).with(raw_url(shas[2]), auth: false)
    end

    it 'fails with the client error when the commit list cannot be read' do
      error = Lich::Util::Update::FetchError.new(kind: :rate_limited, status: 403)
      allow(client).to receive(:fetch_github_json).with(commits_url).and_return(nil)
      allow(client).to receive(:last_error).and_return(error)

      expect(floor.newest_compatible(source, 'scripts/foo.lic').to_h).to include(status: :failed, error: error)
    end

    it 'ignores list entries that carry no commit SHA' do
      allow(client).to receive(:fetch_github_json).with(commits_url).and_return([{ 'sha' => '../main' }, 'junk', { 'sha' => shas[0] }])
      allow(client).to receive(:http_get).with(raw_url(shas[0]), auth: false).and_return(script_requiring('5.25.0'))

      expect(floor.newest_compatible(source, 'scripts/foo.lic').to_h).to include(status: :found, commit: shas[0], examined: 1)
    end

    it 'reports none, without a request, when the repository is not known' do
      expect(floor.newest_compatible(nil, 'scripts/foo.lic').to_h).to include(status: :none, examined: 0)
    end
  end
end
