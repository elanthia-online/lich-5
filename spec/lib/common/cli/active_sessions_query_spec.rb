# frozen_string_literal: true

require 'stringio'

require_relative '../../../spec_helper'
require_relative '../../../../lib/common/cli/active_sessions_query'

RSpec.describe Lich::Common::CLI::ActiveSessionsQuery do
  around do |example|
    original_stdout = $stdout
    $stdout = StringIO.new
    example.run
    $stdout = original_stdout
  end

  before do
    stub_const('LICH_DIR', '/tmp/lich')
  end

  describe '.requested_session_name' do
    it 'extracts a session name from the split argument form' do
      stub_const('ARGV', ['--session-info', 'Char1'])

      expect(described_class.requested_session_name).to eq('Char1')
    end

    it 'extracts a session name from the inline argument form' do
      stub_const('ARGV', ['--session-info=Char1'])

      expect(described_class.requested_session_name).to eq('Char1')
    end
  end

  describe '.run' do
    it 'prints a table of active sessions' do
      stub_const('ARGV', ['--active-sessions'])
      allow(described_class).to receive(:query_snapshot).and_return(
        source: 'ActiveSessionsAPI',
        total: 1,
        connected: 1,
        detachable: 1,
        sessions: [
          {
            session_name: 'Char1',
            pid: 1234,
            role: 'session',
            connected: true,
            listener: { host: '127.0.0.1', port: 49_012 },
            uptime_seconds: 3661
          }
        ]
      )

      expect(described_class.run).to eq(0)
      expect($stdout.string).to include('Active Sessions')
      expect($stdout.string).to include('Char1')
      expect($stdout.string).to include('127.0.0.1:49012')
      expect($stdout.string).to include('01:01:01')
    end

    it 'prints a specific session when found' do
      stub_const('ARGV', ['--session-info', 'char1'])
      allow(described_class).to receive(:query_snapshot).and_return(
        source: 'ActiveSessionsAPI',
        total: 1,
        connected: 0,
        detachable: 1,
        sessions: [
          {
            session_name: 'Char1',
            pid: 1234,
            role: 'session',
            connected: false,
            listener: { host: '127.0.0.1', port: 49_012 },
            uptime_seconds: 5
          }
        ]
      )

      expect(described_class.run).to eq(0)
      expect($stdout.string).to include('Session: Char1')
      expect($stdout.string).to include('Detachable listener: 127.0.0.1:49012')
    end

    it 'returns a failure exit code when a specific session is not found' do
      stub_const('ARGV', ['--session-info', 'Char2'])
      allow(described_class).to receive(:query_snapshot).and_return(
        source: 'ActiveSessionsAPI',
        total: 1,
        connected: 1,
        detachable: 0,
        sessions: [{ session_name: 'Char1', pid: 1234 }]
      )

      expect(described_class.run).to eq(1)
      expect($stdout.string).to include('No active session found for Char2.')
    end

    it 'prints a friendly unavailable message when no service is available' do
      stub_const('ARGV', ['--active-sessions'])
      allow(described_class).to receive(:query_snapshot).and_return(
        source: 'ActiveSessionsAPI',
        total: 0,
        connected: 0,
        detachable: 0,
        sessions: [],
        error: 'active sessions service unavailable'
      )

      expect(described_class.run).to eq(0)
      expect($stdout.string).to include('No active sessions service available')
    end

    it 'prints usage when --session-info is missing a value' do
      stub_const('ARGV', ['--session-info'])

      expect(described_class.run).to eq(1)
      expect($stdout.string).to include('Usage: ruby /tmp/lich/lich.rbw --session-info NAME')
    end
  end
end
