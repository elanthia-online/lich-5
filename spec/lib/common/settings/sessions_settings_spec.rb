# frozen_string_literal: true

require 'rspec'
require 'ostruct'

# Define DATA_DIR before loading settings.rb (it initializes settings adapters).
DATA_DIR ||= File.expand_path('../../../../spec', __dir__)

require_relative '../../../mock_database_adapter'
require_relative '../../../../lib/common/settings'
require_relative '../../../../lib/common/settings/sessions_settings'

RSpec.describe Lich::Common::SessionsSettings do
  let(:adapter) { instance_double('Lich::Common::SessionDatabaseAdapter') }

  before(:each) do
    # Stub runtime globals expected by settings consumers.
    Lich::Common::MockScript.current_name = nil
    Lich::Common::MockXMLData.game = 'DR'
    Lich::Common::MockXMLData.name = 'Tsetem'

    stub_const('Script', Lich::Common::MockScript)
    stub_const('XMLData', Lich::Common::MockXMLData)

    # Inject adapter so the facade can be unit tested without DB coupling.
    described_class.instance_variable_set(:@adapter, adapter)
  end

  describe '.register_session' do
    it 'delegates a normalized payload to adapter.upsert_session' do
      allow(adapter).to receive(:upsert_session)

      described_class.register_session(
        pid: 50_001,
        session_name: 'Tsetem',
        role: 'session',
        state: 'running'
      )

      expect(adapter).to have_received(:upsert_session).with(hash_including(
                                                               pid: 50_001,
                                                               session_name: 'Tsetem',
                                                               role: 'session',
                                                               state: 'running'
                                                             ))
    end
  end

  describe '.heartbeat' do
    it 'updates heartbeat data for an existing pid via adapter.upsert_session' do
      allow(adapter).to receive(:upsert_session)
      allow(described_class).to receive(:os_presence).and_return(os_seen: 1, os_name: 1, os_seen_at: 1_001)

      described_class.heartbeat(pid: 50_001, state: 'sleeping', session_name: 'Tsetem')

      expect(adapter).to have_received(:upsert_session).with(hash_including(
                                                               pid: 50_001,
                                                               state: 'sleeping',
                                                               os_seen: 1,
                                                               os_name: 1,
                                                               os_seen_at: 1_001
                                                             ))
    end
  end

  describe '.unregister_session' do
    it 'marks session as exited and not-seen in OS for historical reporting' do
      allow(adapter).to receive(:upsert_session)

      described_class.unregister_session(pid: 50_001)

      expect(adapter).to have_received(:upsert_session).with(hash_including(
                                                               pid: 50_001,
                                                               state: 'exited',
                                                               os_seen: 0,
                                                               os_name: 0
                                                             ))
    end
  end

  describe '.snapshot' do
    # Snapshot examples assert reporting-schema stability and marker semantics.
    it 'returns stable report schema with aggregated counters' do
      allow(Time).to receive(:now).and_return(Time.at(1_000))
      allow(adapter).to receive(:active_sessions).and_return([
                                                               { 'pid' => 1, 'state' => 'running', 'hidden' => 0, 'session_name' => 'A', 'last_heartbeat_at' => 950, 'os_seen' => 1, 'os_name' => 1 },
                                                               { 'pid' => 2, 'state' => 'sleeping', 'hidden' => 1, 'session_name' => 'B', 'last_heartbeat_at' => 950, 'os_seen' => 0, 'os_name' => 0 }
                                                             ])

      snapshot = described_class.snapshot

      expect(snapshot[:source]).to eq('SessionsSettings')
      expect(snapshot[:total]).to eq(2)
      expect(snapshot[:stale]).to eq(1)
      expect(snapshot[:running]).to eq(1)
      expect(snapshot[:sleeping]).to eq(1)
      expect(snapshot[:hidden]).to eq(1)
      expect(snapshot[:sessions]).to be_a(Array)
      expect(snapshot[:sessions].map { |s| s[:marker] }).to contain_exactly('active', 'stale')
    end

    it 'surfaces duplicate names as data, not as hard failures' do
      allow(adapter).to receive(:active_sessions).and_return([
                                                               { 'pid' => 10, 'state' => 'running', 'hidden' => 0, 'session_name' => 'Tsetem', 'last_heartbeat_at' => 1_000, 'os_seen' => 1, 'os_name' => 1 },
                                                               { 'pid' => 11, 'state' => 'running', 'hidden' => 0, 'session_name' => 'Tsetem', 'last_heartbeat_at' => 1_000, 'os_seen' => 1, 'os_name' => 1 }
                                                             ])
      allow(Time).to receive(:now).and_return(Time.at(1_000))

      snapshot = described_class.snapshot
      names = snapshot[:sessions].map { |s| s[:session_name] }
      expect(names.count('Tsetem')).to eq(2)
    end

    it 'clears stale marker when a later heartbeat is seen' do
      allow(Time).to receive(:now).and_return(Time.at(2_000))
      allow(adapter).to receive(:active_sessions).and_return(
        [{ 'pid' => 7, 'state' => 'running', 'hidden' => 0, 'session_name' => 'Tsetem', 'last_heartbeat_at' => 1_500, 'os_seen' => 1, 'os_name' => 1 }],
        [{ 'pid' => 7, 'state' => 'running', 'hidden' => 0, 'session_name' => 'Tsetem', 'last_heartbeat_at' => 1_950, 'os_seen' => 1, 'os_name' => 1 }]
      )

      first = described_class.snapshot
      second = described_class.snapshot

      expect(first[:sessions].first[:marker]).to eq('stale')
      expect(second[:sessions].first[:marker]).to eq('active')
    end

    it 'marks clean exits as inactive instead of stale' do
      allow(Time).to receive(:now).and_return(Time.at(2_000))
      allow(adapter).to receive(:active_sessions).and_return(
        [{ 'pid' => 9, 'state' => 'exited', 'hidden' => 0, 'session_name' => 'Tsetem', 'last_heartbeat_at' => 1_000, 'os_seen' => 0, 'os_name' => 0 }]
      )

      snapshot = described_class.snapshot

      expect(snapshot[:stale]).to eq(0)
      expect(snapshot[:sessions].first[:marker]).to eq('inactive')
    end

    it 'returns deterministic fallback payload on adapter errors' do
      allow(adapter).to receive(:active_sessions).and_raise(StandardError, 'db busy')

      snapshot = described_class.snapshot

      expect(snapshot[:source]).to eq('SessionsSettings')
      expect(snapshot[:total]).to eq(0)
      expect(snapshot[:stale]).to eq(0)
      expect(snapshot[:sessions]).to eq([])
      expect(snapshot[:error]).to include('db busy')
    end

    it 'preserves os_name as nil when command-line matching is unavailable' do
      allow(Time).to receive(:now).and_return(Time.at(2_000))
      allow(adapter).to receive(:active_sessions).and_return(
        [{ 'pid' => 12, 'state' => 'running', 'hidden' => 0, 'session_name' => 'Tsetem', 'last_heartbeat_at' => 1_950, 'os_seen' => 1, 'os_name' => nil }]
      )

      snapshot = described_class.snapshot

      expect(snapshot[:sessions].first[:os_seen]).to be true
      expect(snapshot[:sessions].first[:os_name]).to be_nil
    end
  end
end
