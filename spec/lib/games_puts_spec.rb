# frozen_string_literal: true

require_relative '../spec_helper'
require 'timeout'

require "common/sharedbuffer"
require "games"

RSpec.describe Lich::GameBase::Game, '._puts connection error handling' do
  let(:mock_socket) { double('socket') }

  before do
    described_class.instance_variable_set(:@socket, mock_socket)
    described_class.instance_variable_set(:@mutex, Mutex.new)
    allow(Lich).to receive(:log)
  end

  # -- Happy path ----------------------------------------------------------

  describe 'normal operation' do
    it 'writes the string to the socket' do
      allow(mock_socket).to receive(:puts)
      described_class.send(:_puts, 'go north')
      expect(mock_socket).to have_received(:puts).with('go north')
    end
  end

  # -- ECONNRESET (the bug that caused 9,089 lines of spam) ----------------

  describe 'Errno::ECONNRESET handling' do
    before { allow(mock_socket).to receive(:puts).and_raise(Errno::ECONNRESET) }

    it 'does not propagate the exception' do
      expect { described_class.send(:_puts, 'go north') }.not_to raise_error
    end

    it 'returns nil' do
      expect(described_class.send(:_puts, 'go north')).to be_nil
    end

    it 'logs the error with class name and backtrace' do
      described_class.send(:_puts, 'go north')
      expect(Lich).to have_received(:log).with(/error: _puts:.*(?:Connection reset|forcibly closed)/i)
    end

    it 'absorbs rapid successive ECONNRESET bursts without raising' do
      50.times do
        expect { described_class.send(:_puts, "command_#{_1}") }.not_to raise_error
      end
    end
  end

  # -- ECONNABORTED --------------------------------------------------------

  describe 'Errno::ECONNABORTED handling' do
    before { allow(mock_socket).to receive(:puts).and_raise(Errno::ECONNABORTED) }

    it 'does not propagate the exception' do
      expect { described_class.send(:_puts, 'go north') }.not_to raise_error
    end

    it 'returns nil' do
      expect(described_class.send(:_puts, 'go north')).to be_nil
    end

    it 'logs the error' do
      described_class.send(:_puts, 'go north')
      expect(Lich).to have_received(:log).with(/error: _puts:/)
    end
  end

  # -- Pre-existing rescues (regression) -----------------------------------

  describe 'Errno::EPIPE handling (regression)' do
    before { allow(mock_socket).to receive(:puts).and_raise(Errno::EPIPE) }

    it 'does not propagate the exception' do
      expect { described_class.send(:_puts, 'go north') }.not_to raise_error
    end

    it 'returns nil' do
      expect(described_class.send(:_puts, 'go north')).to be_nil
    end
  end

  describe 'IOError handling (regression)' do
    before { allow(mock_socket).to receive(:puts).and_raise(IOError, 'closed stream') }

    it 'does not propagate the exception' do
      expect { described_class.send(:_puts, 'go north') }.not_to raise_error
    end

    it 'returns nil' do
      expect(described_class.send(:_puts, 'go north')).to be_nil
    end
  end

  # -- Errors that SHOULD still propagate ----------------------------------

  describe 'non-connection errors still propagate' do
    it 'raises RuntimeError' do
      allow(mock_socket).to receive(:puts).and_raise(RuntimeError, 'unexpected')
      expect { described_class.send(:_puts, 'go north') }.to raise_error(RuntimeError, 'unexpected')
    end

    it 'raises NoMethodError' do
      allow(mock_socket).to receive(:puts).and_raise(NoMethodError, 'undefined method')
      expect { described_class.send(:_puts, 'go north') }.to raise_error(NoMethodError)
    end

    it 'raises ArgumentError' do
      allow(mock_socket).to receive(:puts).and_raise(ArgumentError, 'bad args')
      expect { described_class.send(:_puts, 'go north') }.to raise_error(ArgumentError)
    end
  end

  # -- Thread safety -------------------------------------------------------

  describe 'thread safety under connection failure' do
    it 'serializes concurrent writes through the mutex even when failing' do
      call_order = []
      mutex = Mutex.new

      allow(mock_socket).to receive(:puts) do |str|
        mutex.synchronize { call_order << str }
        raise Errno::ECONNRESET
      end

      threads = 10.times.map do |i|
        Thread.new { described_class.send(:_puts, "cmd_#{i}") }
      end
      threads.each(&:join)

      expect(call_order.size).to eq(10)
    end

    it 'does not deadlock when socket raises inside mutex' do
      allow(mock_socket).to receive(:puts).and_raise(Errno::ECONNRESET)

      result = Timeout.timeout(2) do
        5.times { described_class.send(:_puts, 'test') }
        :completed
      end

      expect(result).to eq(:completed)
    end
  end

  # -- Mixed error sequences -----------------------------------------------

  describe 'alternating error types' do
    it 'handles EPIPE then ECONNRESET then IOError in sequence' do
      call_count = 0
      allow(mock_socket).to receive(:puts) do
        call_count += 1
        case call_count
        when 1 then raise Errno::EPIPE
        when 2 then raise Errno::ECONNRESET
        when 3 then raise IOError, 'closed stream'
        end
      end

      3.times do
        expect { described_class.send(:_puts, 'test') }.not_to raise_error
      end

      expect(Lich).to have_received(:log).exactly(3).times
    end
  end
end
