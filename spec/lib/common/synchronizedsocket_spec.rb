# frozen_string_literal: true

require_relative '../../spec_helper'
require 'socket'
require 'common/class_exts/synchronizedsocket'

RSpec.describe Lich::Common::SynchronizedSocket do
  let(:delegate) { instance_double(TCPSocket) }
  let(:socket) { described_class.new(delegate) }

  before do
    allow(delegate).to receive(:closed?).and_return(false)
    allow(Lich).to receive(:log)
  end

  describe '#initialize' do
    it 'starts alive' do
      expect(socket.alive?).to be true
    end
  end

  # ===========================================================================
  # alive?
  # ===========================================================================
  describe '#alive?' do
    it 'returns true when alive and delegate is open' do
      expect(socket.alive?).to be true
    end

    it 'returns false when delegate is closed' do
      allow(delegate).to receive(:closed?).and_return(true)
      expect(socket.alive?).to be false
    end

    it 'returns false after a write failure' do
      allow(delegate).to receive(:write).and_raise(Errno::ECONNRESET)
      socket.write("test")
      expect(socket.alive?).to be false
    end
  end

  # ===========================================================================
  # puts - write-side resilience
  # ===========================================================================
  describe '#puts' do
    it 'delegates to the underlying socket' do
      allow(delegate).to receive(:puts).with("hello")
      socket.puts("hello")
      expect(delegate).to have_received(:puts).with("hello")
    end

    context 'when delegate raises Errno::ECONNRESET' do
      before { allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET) }

      it 'returns nil instead of raising' do
        expect(socket.puts("test")).to be_nil
      end

      it 'marks the socket as not alive' do
        socket.puts("test")
        expect(socket.alive?).to be false
      end

      it 'logs the failure via Lich.log' do
        socket.puts("test")
        expect(Lich).to have_received(:log).with(/client socket write failed.*ECONNRESET/)
      end
    end

    context 'when delegate raises Errno::EPIPE' do
      before { allow(delegate).to receive(:puts).and_raise(Errno::EPIPE) }

      it 'absorbs the error and returns nil' do
        expect(socket.puts("test")).to be_nil
      end

      it 'marks the socket as not alive' do
        socket.puts("test")
        expect(socket.alive?).to be false
      end
    end

    context 'when delegate raises Errno::ECONNABORTED' do
      before { allow(delegate).to receive(:puts).and_raise(Errno::ECONNABORTED) }

      it 'absorbs the error and returns nil' do
        expect(socket.puts("test")).to be_nil
      end
    end

    context 'when delegate raises IOError' do
      before { allow(delegate).to receive(:puts).and_raise(IOError.new("closed stream")) }

      it 'absorbs the error and returns nil' do
        expect(socket.puts("test")).to be_nil
      end
    end

    context 'when already dead' do
      before do
        allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
        socket.puts("first call dies")
      end

      it 'returns nil without touching the delegate' do
        expect(delegate).to have_received(:puts).once
        expect(socket.puts("second call")).to be_nil
        expect(delegate).to have_received(:puts).once
      end

      it 'does not log again' do
        expect(Lich).to have_received(:log).once
        socket.puts("second call")
        expect(Lich).to have_received(:log).once
      end
    end

    context 'when delegate raises a non-fatal error' do
      before { allow(delegate).to receive(:puts).and_raise(ArgumentError, "bad args") }

      it 'lets the error propagate' do
        expect { socket.puts("test") }.to raise_error(ArgumentError, "bad args")
      end

      it 'does not mark the socket as dead' do
        socket.puts("test") rescue nil
        expect(socket.alive?).to be true
      end
    end
  end

  # ===========================================================================
  # write - write-side resilience
  # ===========================================================================
  describe '#write' do
    it 'delegates to the underlying socket' do
      allow(delegate).to receive(:write).with("data").and_return(4)
      expect(socket.write("data")).to eq(4)
    end

    context 'when delegate raises Errno::ECONNRESET' do
      before { allow(delegate).to receive(:write).and_raise(Errno::ECONNRESET) }

      it 'returns nil instead of raising' do
        expect(socket.write("test")).to be_nil
      end

      it 'marks the socket as not alive' do
        socket.write("test")
        expect(socket.alive?).to be false
      end
    end

    context 'when already dead' do
      before do
        allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
        socket.write("die")
      end

      it 'returns nil without touching the delegate' do
        expect(delegate).to have_received(:write).once
        expect(socket.write("nope")).to be_nil
        expect(delegate).to have_received(:write).once
      end
    end
  end

  # ===========================================================================
  # puts_if - conditional write with resilience
  # ===========================================================================
  describe '#puts_if' do
    it 'writes when block returns true' do
      allow(delegate).to receive(:puts).with("data")
      result = socket.puts_if("data") { true }
      expect(result).to be true
      expect(delegate).to have_received(:puts).with("data")
    end

    it 'does not write when block returns false' do
      allow(delegate).to receive(:puts)
      result = socket.puts_if("data") { false }
      expect(result).to be false
      expect(delegate).not_to have_received(:puts)
    end

    context 'when delegate raises Errno::ECONNRESET during write' do
      before { allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET) }

      it 'returns false instead of raising' do
        expect(socket.puts_if("test") { true }).to be false
      end

      it 'marks the socket as not alive' do
        socket.puts_if("test") { true }
        expect(socket.alive?).to be false
      end

      it 'logs the failure' do
        socket.puts_if("test") { true }
        expect(Lich).to have_received(:log).with(/client socket write failed/)
      end
    end

    context 'when already dead' do
      before do
        allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
        socket.puts_if("die") { true }
      end

      it 'returns false without evaluating the block' do
        block_called = false
        result = socket.puts_if("nope") { block_called = true }
        expect(result).to be false
        expect(block_called).to be false
      end
    end
  end

  # ===========================================================================
  # method_missing - read-side passthrough (still raises)
  # ===========================================================================
  describe '#method_missing' do
    it 'delegates reads to the underlying socket' do
      allow(delegate).to receive(:gets).and_return("game data\n")
      expect(socket.gets).to eq("game data\n")
    end

    it 'lets read-side errors propagate' do
      allow(delegate).to receive(:gets).and_raise(Errno::ECONNRESET)
      expect { socket.gets }.to raise_error(Errno::ECONNRESET)
    end

    it 'does not mark the socket as dead on read errors' do
      allow(delegate).to receive(:gets).and_raise(Errno::ECONNRESET)
      socket.gets rescue nil
      expect(socket.alive?).to be true
    end

    it 'delegates close to the underlying socket' do
      allow(delegate).to receive(:close)
      socket.close
      expect(delegate).to have_received(:close)
    end

    it 'delegates closed? to the underlying socket' do
      allow(delegate).to receive(:closed?).and_return(true)
      expect(socket.closed?).to be true
    end
  end

  # ===========================================================================
  # respond_to_missing?
  # ===========================================================================
  describe '#respond_to_missing?' do
    it 'returns true for methods the delegate supports' do
      allow(delegate).to receive(:respond_to?).with(:gets, false).and_return(true)
      expect(socket.respond_to?(:gets)).to be true
    end

    it 'returns false for methods the delegate does not support' do
      allow(delegate).to receive(:respond_to?).with(:nonexistent, false).and_return(false)
      expect(socket.respond_to?(:nonexistent)).to be false
    end
  end

  # ===========================================================================
  # Thread safety
  # ===========================================================================
  describe 'thread safety' do
    it 'handles concurrent writes without corruption' do
      call_count = 0
      allow(delegate).to receive(:write) { |_| call_count += 1; call_count }

      threads = 10.times.map do |i|
        Thread.new { socket.write("msg #{i}") }
      end
      threads.each(&:join)

      expect(call_count).to eq(10)
    end

    it 'handles concurrent writes when socket dies mid-burst' do
      call_count = 0
      allow(delegate).to receive(:write) do |_|
        call_count += 1
        raise Errno::ECONNRESET if call_count == 3

        call_count
      end

      threads = 10.times.map do |i|
        Thread.new { socket.write("msg #{i}") }
      end
      threads.each(&:join)

      expect(socket.alive?).to be false
      expect(call_count).to be <= 10
    end
  end

  # ===========================================================================
  # Liveness transition is one-way
  # ===========================================================================
  describe 'liveness state machine' do
    it 'cannot be revived once dead' do
      allow(delegate).to receive(:write).and_raise(Errno::ECONNRESET)
      socket.write("die")
      expect(socket.alive?).to be false

      allow(delegate).to receive(:closed?).and_return(false)
      expect(socket.alive?).to be false
    end

    it 'logs exactly once per death' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)

      socket.puts("first")
      socket.puts("second")
      socket.puts("third")

      expect(Lich).to have_received(:log).once
    end
  end

  # ===========================================================================
  # FATAL_WRITE_ERRORS coverage
  # ===========================================================================
  describe 'FATAL_WRITE_ERRORS' do
    described_class::FATAL_WRITE_ERRORS.each do |error_class|
      it "absorbs #{error_class} on puts" do
        allow(delegate).to receive(:puts).and_raise(error_class.new("test"))
        expect { socket.puts("x") }.not_to raise_error
      end

      it "absorbs #{error_class} on write" do
        allow(delegate).to receive(:write).and_raise(error_class.new("test"))
        expect { socket.write("x") }.not_to raise_error
      end

      it "absorbs #{error_class} on puts_if" do
        allow(delegate).to receive(:puts).and_raise(error_class.new("test"))
        expect { socket.puts_if("x") { true } }.not_to raise_error
      end
    end
  end

  # ===========================================================================
  # Integration: recursion scenario
  # ===========================================================================
  describe 'recursion prevention' do
    it 'does not recurse when error handler writes to dead socket' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
      allow(delegate).to receive(:write).and_raise(Errno::ECONNRESET)

      # Simulate the old recursion path: write fails, error handler writes again
      socket.puts("initial write")
      # Socket is now dead; subsequent writes are no-ops
      100.times { socket.puts("error handler retry") }
      100.times { socket.write("error handler retry") }
      100.times { socket.puts_if("error handler retry") { true } }

      expect(socket.alive?).to be false
      # Only one log entry for the initial death
      expect(Lich).to have_received(:log).once
    end
  end
end
