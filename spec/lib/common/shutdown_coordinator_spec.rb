# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_coordinator'

RSpec.describe Lich::Common::ShutdownCoordinator do
  before do
    described_class.reset!
    allow(Lich).to receive(:log)
  end

  after do
    described_class.reset!
  end

  it 'records the first shutdown request' do
    request = described_class.request(reason: :user_exit, source: :primary_frontend)

    expect(request.reason).to eq(:user_exit)
    expect(request.source).to eq('primary_frontend')
    expect(request).to be_frozen
    expect(described_class.current).to be_frozen
    expect(described_class.reason).to eq(:user_exit)
    expect(described_class).to be_requested
  end

  it 'keeps the first reason when a later request arrives' do
    first = described_class.request(reason: :user_exit, source: :primary_frontend)
    second = described_class.request(reason: :game_eof, source: :game_reader)

    expect(second).to equal(first)
    expect(described_class.reason).to eq(:user_exit)
    expect(described_class.current.source).to eq('primary_frontend')
  end

  it 'classifies explicit user exit as orderly' do
    described_class.request(reason: :user_exit, source: :primary_frontend)

    expect(described_class).to be_orderly_user_exit
    expect(described_class).not_to be_connection_loss
  end

  it 'classifies connection loss reasons' do
    described_class.request(reason: :connection_reset, source: :game_reader)

    expect(described_class).to be_connection_loss
    expect(described_class).not_to be_orderly_user_exit
  end

  it 'classifies game stream desync as connection loss' do
    described_class.request(reason: :game_stream_desync, source: :game_reader)

    expect(described_class).to be_connection_loss
    expect(described_class).not_to be_orderly_user_exit
  end

  it 'logs the first shutdown request with reason and source' do
    described_class.request(reason: :game_timeout, source: :game_reader, detail: Errno::ETIMEDOUT)

    expect(Lich).to have_received(:log).with(
      'info: shutdown requested reason=game_timeout source=game_reader detail=Errno::ETIMEDOUT'
    )
  end

  it 'rejects invalid reasons' do
    expect {
      described_class.request(reason: :unknown, source: :game_reader)
    }.to raise_error(ArgumentError, 'invalid shutdown reason: :unknown')
  end

  it 'rejects missing sources' do
    expect {
      described_class.request(reason: :game_eof, source: '')
    }.to raise_error(ArgumentError, 'shutdown source must be present')
  end

  describe '.record_client_socket_write_failure' do
    it 'records client disconnect when no shutdown request exists' do
      error = Errno::EPIPE.new('broken pipe')

      described_class.record_client_socket_write_failure(error: error)

      expect(described_class.reason).to eq(:client_disconnect)
      expect(described_class.current.source).to eq('client_socket_write')
      expect(described_class.current.detail).to start_with('Errno::EPIPE:')
      expect(described_class.client_socket_write_failure).to equal(error)
      expect(described_class).to be_client_socket_write_failed
    end

    it 'preserves first-wins shutdown attribution while recording the write failure' do
      request = described_class.request(reason: :user_exit, source: :primary_frontend)
      error = Errno::ECONNRESET.new('reset')

      described_class.record_client_socket_write_failure(error: error)

      expect(described_class.current).to equal(request)
      expect(described_class.reason).to eq(:user_exit)
      expect(described_class.client_socket_write_failure).to equal(error)
    end

    it 'keeps the first client socket write failure' do
      first = Errno::EPIPE.new('first')
      second = Errno::ECONNRESET.new('second')

      described_class.record_client_socket_write_failure(error: first)
      described_class.record_client_socket_write_failure(error: second)

      expect(described_class.client_socket_write_failure).to equal(first)
    end

    it 'uses the stored first write failure when requesting shutdown attribution' do
      first = Errno::EPIPE.new('first')
      second = Errno::ECONNRESET.new('second')
      described_class.instance_variable_set(:@client_socket_write_failure, first)

      described_class.record_client_socket_write_failure(error: second)

      expect(described_class.current.detail).to start_with('Errno::EPIPE:')
      expect(described_class.client_socket_write_failure).to equal(first)
    end

    it 'rejects missing errors' do
      expect {
        described_class.record_client_socket_write_failure(error: nil)
      }.to raise_error(ArgumentError, 'client socket write failure error must be present')
    end

    it 'clears write failure state on reset' do
      described_class.record_client_socket_write_failure(error: Errno::EPIPE.new('broken pipe'))

      described_class.reset!

      expect(described_class).not_to be_client_socket_write_failed
      expect(described_class.client_socket_write_failure).to be_nil
    end
  end

  describe '.begin_orderly_shutdown' do
    def result(scripts_drained: true, vars_saved: true, completed: true)
      Struct.new(:completed, :scripts_drained, :vars_saved, keyword_init: true) do
        def completed?
          completed
        end

        def scripts_drained?
          scripts_drained
        end

        def vars_saved?
          vars_saved
        end
      end.new(completed: completed, scripts_drained: scripts_drained, vars_saved: vars_saved)
    end

    it 'stores the first orderly shutdown result and exposes progress predicates' do
      stored = described_class.begin_orderly_shutdown(result(scripts_drained: true, vars_saved: false, completed: false))

      expect(described_class.orderly_shutdown_result).to equal(stored)
      expect(described_class).not_to be_orderly_shutdown_completed
      expect(described_class).to be_scripts_drained
      expect(described_class).not_to be_vars_saved
    end

    it 'keeps the first orderly shutdown result' do
      first = described_class.begin_orderly_shutdown(result)
      second = described_class.begin_orderly_shutdown(result(completed: false))

      expect(second).to equal(first)
      expect(described_class.orderly_shutdown_result).to equal(first)
    end

    it 'rejects invalid orderly shutdown results' do
      expect {
        described_class.begin_orderly_shutdown(Object.new)
      }.to raise_error(ArgumentError, 'orderly shutdown result must respond to #completed?')
    end
  end

  describe '.begin_best_effort_cleanup' do
    def result(scripts_drained: true, vars_saved: true, completed: true)
      Struct.new(:completed, :scripts_drained, :vars_saved, keyword_init: true) do
        def completed?
          completed
        end

        def scripts_drained?
          scripts_drained
        end

        def vars_saved?
          vars_saved
        end
      end.new(completed: completed, scripts_drained: scripts_drained, vars_saved: vars_saved)
    end

    it 'stores the first best-effort cleanup result and exposes progress predicates' do
      stored = described_class.begin_best_effort_cleanup(result(scripts_drained: false, vars_saved: true, completed: false))

      expect(described_class.best_effort_cleanup_result).to equal(stored)
      expect(described_class).not_to be_best_effort_cleanup_completed
      expect(described_class).not_to be_scripts_drained
      expect(described_class).to be_vars_saved
    end

    it 'keeps the first best-effort cleanup result' do
      first = described_class.begin_best_effort_cleanup(result)
      second = described_class.begin_best_effort_cleanup(result(completed: false))

      expect(second).to equal(first)
      expect(described_class.best_effort_cleanup_result).to equal(first)
    end

    it 'rejects invalid best-effort cleanup results' do
      expect {
        described_class.begin_best_effort_cleanup(Object.new)
      }.to raise_error(ArgumentError, 'best-effort cleanup result must respond to #completed?')
    end
  end
end
