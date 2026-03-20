# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../../lib/internal_api/active_sessions/registry'

RSpec.describe Lich::InternalAPI::ActiveSessions::Registry do
  let(:now) { 1_700_000_000 }
  let(:time_source) { -> { now } }
  let(:alive_pids) { [101, 202] }
  let(:process_checker) { ->(pid) { alive_pids.include?(pid) } }
  let(:registry) { described_class.new(time_source: time_source, process_checker: process_checker) }

  describe '#upsert and #session' do
    it 'stores normalized live session data and preserves started_at across updates' do
      registry.upsert(pid: 101, session_name: 'Tsetem', role: 'session', started_at: now, connected: true)
      registry.upsert(pid: 101, frontend: 'stormfront', connected: false)

      session = registry.session(101)

      expect(session[:session_name]).to eq('Tsetem')
      expect(session[:frontend]).to eq('stormfront')
      expect(session[:started_at]).to eq(now)
      expect(session[:connected]).to be(false)
    end
  end

  describe '#snapshot' do
    it 'removes dead sessions before returning the active snapshot' do
      registry.upsert(pid: 101, session_name: 'Live', role: 'session', started_at: now, connected: true)
      registry.upsert(pid: 303, session_name: 'Dead', role: 'session', started_at: now, connected: true)

      snapshot = registry.snapshot

      expect(snapshot[:total]).to eq(1)
      expect(snapshot[:sessions].map { |session| session[:pid] }).to contain_exactly(101)
    end

    it 'includes detachable listener metadata and uptime_seconds' do
      registry.upsert(
        pid: 202,
        session_name: 'Urgoyle',
        role: 'detachable',
        started_at: now - 120,
        connected: true,
        listener_host: '127.0.0.1',
        listener_port: 7000
      )

      snapshot = registry.snapshot
      session = snapshot[:sessions].first

      expect(snapshot[:detachable]).to eq(1)
      expect(snapshot[:connected]).to eq(1)
      expect(session[:listener]).to eq(host: '127.0.0.1', port: 7000)
      expect(session[:uptime_seconds]).to eq(120)
    end
  end
end
