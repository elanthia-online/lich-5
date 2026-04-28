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
    stub_const('Lich::Common::FeatureFlags', Module.new)
    allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(described_class::FEATURE_FLAG).and_return(true)
  end

  describe '.enabled?' do
    it 'returns false when feature flag plumbing is unavailable' do
      hide_const('Lich::Common::FeatureFlags')

      expect(described_class.enabled?).to be(false)
    end

    it 'delegates to FeatureFlags for the session summary flag' do
      expect(described_class.enabled?).to be(true)
      expect(Lich::Common::FeatureFlags).to have_received(:enabled?).with(:session_summary_store_and_reporting)
    end
  end

  describe '.register_session' do
    it 'delegates a normalized payload to adapter.upsert_session' do
      allow(adapter).to receive(:tracked_live_candidates).and_return([])
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

    it 'does nothing while the feature flag is disabled' do
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(described_class::FEATURE_FLAG).and_return(false)
      allow(adapter).to receive(:upsert_session)

      described_class.register_session(pid: 50_001, session_name: 'Tsetem', role: 'session', state: 'running')

      expect(adapter).not_to have_received(:upsert_session)
    end

    it 'marks dead non-exited rows as exited before registering the current session' do
      allow(adapter).to receive(:tracked_live_candidates).and_return([
                                                                       { 'pid' => 47_810, 'session_name' => 'Tsetem', 'state' => 'running' }
                                                                     ])
      allow(adapter).to receive(:upsert_session)
      allow(described_class).to receive(:process_alive?).with(47_810).and_return(false)
      allow(described_class).to receive(:os_presence).and_return(os_seen: 1, os_name: 1, os_seen_at: 1_001)

      described_class.register_session(
        pid: 50_001,
        session_name: 'Urgoyle',
        role: 'session',
        state: 'running'
      )

      expect(adapter).to have_received(:upsert_session).with(hash_including(
                                                               pid: 47_810,
                                                               state: 'exited',
                                                               os_seen: 0,
                                                               os_name: 0
                                                             ))
      expect(adapter).to have_received(:upsert_session).with(hash_including(
                                                               pid: 50_001,
                                                               session_name: 'Urgoyle',
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

    it 'does nothing while the feature flag is disabled' do
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(described_class::FEATURE_FLAG).and_return(false)
      allow(adapter).to receive(:upsert_session)

      described_class.heartbeat(pid: 50_001, state: 'sleeping', session_name: 'Tsetem')

      expect(adapter).not_to have_received(:upsert_session)
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

    it 'does nothing while the feature flag is disabled' do
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(described_class::FEATURE_FLAG).and_return(false)
      allow(adapter).to receive(:upsert_session)

      described_class.unregister_session(pid: 50_001)

      expect(adapter).not_to have_received(:upsert_session)
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
      allow(described_class).to receive(:os_presence).with(pid: 1, session_name: 'A', now: 1_000).and_return(os_seen: 1, os_name: 1, os_seen_at: 1_000)
      allow(described_class).to receive(:os_presence).with(pid: 2, session_name: 'B', now: 1_000).and_return(os_seen: 0, os_name: 0, os_seen_at: 1_000)

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

    it 'returns an empty deterministic payload while the feature flag is disabled' do
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(described_class::FEATURE_FLAG).and_return(false)
      allow(adapter).to receive(:active_sessions)

      snapshot = described_class.snapshot

      expect(snapshot[:source]).to eq('SessionsSettings')
      expect(snapshot[:total]).to eq(0)
      expect(snapshot[:sessions]).to eq([])
      expect(adapter).not_to have_received(:active_sessions)
    end

    it 'surfaces duplicate names as data, not as hard failures' do
      allow(adapter).to receive(:active_sessions).and_return([
                                                               { 'pid' => 10, 'state' => 'running', 'hidden' => 0, 'session_name' => 'Tsetem', 'last_heartbeat_at' => 1_000, 'os_seen' => 1, 'os_name' => 1 },
                                                               { 'pid' => 11, 'state' => 'running', 'hidden' => 0, 'session_name' => 'Tsetem', 'last_heartbeat_at' => 1_000, 'os_seen' => 1, 'os_name' => 1 }
                                                             ])
      allow(Time).to receive(:now).and_return(Time.at(1_000))
      allow(described_class).to receive(:os_presence).with(pid: 10, session_name: 'Tsetem', now: 1_000).and_return(os_seen: 1, os_name: 1, os_seen_at: 1_000)
      allow(described_class).to receive(:os_presence).with(pid: 11, session_name: 'Tsetem', now: 1_000).and_return(os_seen: 1, os_name: 1, os_seen_at: 1_000)

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
      allow(described_class).to receive(:os_presence).with(pid: 7, session_name: 'Tsetem', now: 2_000).and_return(os_seen: 1, os_name: 1, os_seen_at: 2_000)

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
      allow(described_class).to receive(:os_presence).with(pid: 12, session_name: 'Tsetem', now: 2_000).and_return(os_seen: 1, os_name: nil, os_seen_at: 2_000)

      snapshot = described_class.snapshot

      expect(snapshot[:sessions].first[:os_seen]).to be true
      expect(snapshot[:sessions].first[:os_name]).to be_nil
    end

    it 'uses fresh OS visibility for non-exited rows instead of trusting persisted os_seen' do
      allow(Time).to receive(:now).and_return(Time.at(2_000))
      allow(adapter).to receive(:active_sessions).and_return(
        [{ 'pid' => 47_810, 'state' => 'running', 'hidden' => 0, 'session_name' => 'Tsetem', 'last_heartbeat_at' => 1_950, 'os_seen' => 1, 'os_name' => 1 }]
      )
      allow(described_class).to receive(:os_presence).with(pid: 47_810, session_name: 'Tsetem', now: 2_000).and_return(os_seen: 0, os_name: 0, os_seen_at: 2_000)

      snapshot = described_class.snapshot

      expect(snapshot[:sessions].first[:os_seen]).to be false
      expect(snapshot[:sessions].first[:marker]).to eq('stale')
      expect(snapshot[:stale]).to eq(1)
    end
  end

  describe 'admitted paths' do
    it 'admitted methods are private' do
      expect { described_class.register_session_admitted(pid: 1, session_name: 'X', role: 'session', state: 'running') }.to raise_error(NoMethodError)
      expect { described_class.heartbeat_admitted(pid: 1, state: 'running', session_name: 'X') }.to raise_error(NoMethodError)
      expect { described_class.unregister_session_admitted(pid: 1) }.to raise_error(NoMethodError)
    end

    it 'register_session_admitted bypasses enabled? gate' do
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(described_class::FEATURE_FLAG).and_return(false)
      allow(adapter).to receive(:tracked_live_candidates).and_return([])
      allow(adapter).to receive(:upsert_session)
      allow(described_class).to receive(:os_presence).and_return(os_seen: 1, os_name: 1, os_seen_at: 1_001)

      described_class.send(:register_session_admitted, pid: 50_001, session_name: 'Tsetem', role: 'session', state: 'running')

      expect(adapter).to have_received(:upsert_session).with(hash_including(pid: 50_001, session_name: 'Tsetem', state: 'running'))
    end

    it 'heartbeat_admitted bypasses enabled? gate' do
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(described_class::FEATURE_FLAG).and_return(false)
      allow(adapter).to receive(:upsert_session)
      allow(described_class).to receive(:os_presence).and_return(os_seen: 1, os_name: 1, os_seen_at: 1_001)

      described_class.send(:heartbeat_admitted, pid: 50_001, state: 'running', session_name: 'Tsetem')

      expect(adapter).to have_received(:upsert_session).with(hash_including(pid: 50_001, state: 'running'))
    end

    it 'unregister_session_admitted bypasses enabled? gate' do
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(described_class::FEATURE_FLAG).and_return(false)
      allow(adapter).to receive(:upsert_session)

      described_class.send(:unregister_session_admitted, pid: 50_001)

      expect(adapter).to have_received(:upsert_session).with(hash_including(pid: 50_001, state: 'exited', os_seen: 0, os_name: 0))
    end
  end
end
