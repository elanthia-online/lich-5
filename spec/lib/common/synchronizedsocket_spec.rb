# frozen_string_literal: true

require_relative '../../spec_helper'
require 'socket'
require 'common/class_exts/synchronizedsocket'

RSpec.describe Lich::Common::SynchronizedSocket do
  let(:delegate) { instance_double(TCPSocket) }
  let(:socket) { described_class.new(delegate) }

  before do
    allow(delegate).to receive(:closed?).and_return(false)
    allow(delegate).to receive(:close)
    allow(Lich).to receive(:log)
  end

  # ===========================================================================
  # Initialization
  # ===========================================================================
  describe '#initialize' do
    it 'starts alive with an open delegate' do
      expect(socket.alive?).to be true
    end
  end

  # ===========================================================================
  # alive? -- liveness semantics and edge cases
  # ===========================================================================
  describe '#alive?' do
    it 'returns true when alive and delegate is open' do
      expect(socket.alive?).to be true
    end

    it 'returns false when delegate is closed externally' do
      allow(delegate).to receive(:closed?).and_return(true)
      expect(socket.alive?).to be false
    end

    it 'returns false after a fatal write error' do
      allow(delegate).to receive(:write).and_raise(Errno::ECONNRESET)
      socket.write('test')
      expect(socket.alive?).to be false
    end

    it 'cannot be revived once dead' do
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
      socket.write('die')

      allow(delegate).to receive(:closed?).and_return(false)
      expect(socket.alive?).to be false
    end

    context 'when delegate.closed? raises' do
      it 'propagates the error rather than masking it' do
        allow(delegate).to receive(:closed?).and_raise(RuntimeError, 'broken delegate')
        expect { socket.alive? }.to raise_error(RuntimeError, 'broken delegate')
      end
    end
  end

  # ===========================================================================
  # Close-on-death -- the core architectural behavior
  #
  # When a fatal write error occurs, handle_write_failure must close
  # the delegate socket. This unblocks readers in other threads and
  # eliminates the split-brain state where alive?=false but the OS
  # socket is still open (the root cause of issue #594 zombies).
  # ===========================================================================
  describe 'close-on-death' do
    it 'closes the delegate when a write fails fatally' do
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
      socket.write('data')
      expect(delegate).to have_received(:close)
    end

    it 'closes the delegate when puts fails fatally' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
      socket.puts('data')
      expect(delegate).to have_received(:close)
    end

    it 'closes the delegate when puts_if fails fatally' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNABORTED)
      socket.puts_if('data') { true }
      expect(delegate).to have_received(:close)
    end

    it 'survives delegate.close raising during failure cleanup' do
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
      allow(delegate).to receive(:close).and_raise(IOError, 'already closed')
      expect { socket.write('data') }.not_to raise_error
      expect(socket.alive?).to be false
    end

    it 'logs exactly once even when multiple writes fail' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
      3.times { socket.puts('retry') }
      expect(Lich).to have_received(:log).with(/client socket write failed/).once
    end

    it 'closes the delegate exactly once under repeated failures' do
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
      3.times { socket.write('retry') }
      expect(delegate).to have_received(:close).once
    end
  end

  # ===========================================================================
  # Reader unblock on concurrent write death (issue #594 scenario)
  #
  # Uses real I/O primitives (not mocks) to verify that closing the
  # delegate from a writer thread actually unblocks a concurrent reader.
  # ===========================================================================
  describe 'reader unblock on concurrent write death' do
    it 'unblocks a reader when the delegate is closed' do
      read_io, write_io = IO.pipe
      live_socket = described_class.new(write_io)

      reader_result = nil
      reader_thread = Thread.new do
        reader_result = read_io.gets
      rescue IOError => e
        reader_result = e
      end

      sleep 0.05

      write_io.close

      reader_thread.join(2)
      expect(reader_result).to satisfy('be nil (EOF) or IOError') { |r|
        r.nil? || r.is_a?(IOError)
      }

      read_io.close rescue nil
      live_socket # prevent GC warning
    end

    it 'reproduces the #594 flow: write death closes delegate and unblocks reader' do
      sock_a, sock_b = Socket.pair(:UNIX, :STREAM)
      wrapped = described_class.new(sock_a)

      reader_result = nil
      reader_thread = Thread.new do
        reader_result = wrapped.gets
      rescue IOError => e
        reader_result = e
      end

      sleep 0.05
      sock_b.close

      # Write until the socket dies (may take >1 write due to kernel buffering)
      100.times do
        break unless wrapped.alive?

        wrapped.write("data\r\n")
        sleep 0.01
      end
      expect(wrapped.alive?).to be false

      reader_thread.join(2)
      expect(reader_thread.alive?).to be false
    ensure
      [sock_a, sock_b].each { |s| s&.close rescue nil }
    end
  end

  # ===========================================================================
  # puts -- write-side resilience
  # ===========================================================================
  describe '#puts' do
    it 'delegates to the underlying socket' do
      allow(delegate).to receive(:puts).with('hello').and_return(nil)
      socket.puts('hello')
      expect(delegate).to have_received(:puts).with('hello')
    end

    described_class::FATAL_WRITE_ERRORS.each do |error_class|
      context "when delegate raises #{error_class}" do
        before { allow(delegate).to receive(:puts).and_raise(error_class.new('test')) }

        it 'returns nil instead of raising' do
          expect(socket.puts('test')).to be_nil
        end

        it 'marks the socket as dead and closes the delegate' do
          socket.puts('test')
          expect(socket.alive?).to be false
          expect(delegate).to have_received(:close)
        end
      end
    end

    context 'when delegate raises a non-fatal error' do
      before { allow(delegate).to receive(:puts).and_raise(ArgumentError, 'bad args') }

      it 'lets the error propagate' do
        expect { socket.puts('test') }.to raise_error(ArgumentError, 'bad args')
      end

      it 'does not mark the socket as dead' do
        socket.puts('test') rescue nil
        expect(socket.alive?).to be true
      end

      it 'does not close the delegate' do
        socket.puts('test') rescue nil
        expect(delegate).not_to have_received(:close)
      end
    end

    context 'when already dead' do
      before do
        allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
        socket.puts('first call dies')
      end

      it 'returns nil without touching the delegate again' do
        expect(delegate).to have_received(:puts).once
        socket.puts('second call')
        expect(delegate).to have_received(:puts).once
      end
    end

    it 'handles being called with no arguments' do
      allow(delegate).to receive(:puts).with(no_args)
      socket.puts
      expect(delegate).to have_received(:puts).with(no_args)
    end

    it 'forwards multiple arguments' do
      allow(delegate).to receive(:puts).with('a', 'b', 'c')
      socket.puts('a', 'b', 'c')
      expect(delegate).to have_received(:puts).with('a', 'b', 'c')
    end
  end

  # ===========================================================================
  # write -- write-side resilience
  # ===========================================================================
  describe '#write' do
    it 'delegates and returns the byte count from the delegate' do
      allow(delegate).to receive(:write).with('data').and_return(4)
      expect(socket.write('data')).to eq(4)
    end

    context 'when delegate raises Errno::ECONNRESET' do
      before { allow(delegate).to receive(:write).and_raise(Errno::ECONNRESET) }

      it 'returns nil instead of raising' do
        expect(socket.write('test')).to be_nil
      end

      it 'marks the socket as dead and closes the delegate' do
        socket.write('test')
        expect(socket.alive?).to be false
        expect(delegate).to have_received(:close)
      end
    end

    context 'when already dead' do
      before do
        allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
        socket.write('die')
      end

      it 'returns nil without touching the delegate again' do
        expect(delegate).to have_received(:write).once
        socket.write('nope')
        expect(delegate).to have_received(:write).once
      end
    end
  end

  # ===========================================================================
  # puts_if -- conditional write resilience
  # ===========================================================================
  describe '#puts_if' do
    it 'writes when block returns true and returns true' do
      allow(delegate).to receive(:puts).with('data')
      result = socket.puts_if('data') { true }
      expect(result).to be true
      expect(delegate).to have_received(:puts).with('data')
    end

    it 'skips the write when block returns false and returns false' do
      allow(delegate).to receive(:puts)
      result = socket.puts_if('data') { false }
      expect(result).to be false
      expect(delegate).not_to have_received(:puts)
    end

    context 'when the yield block itself raises' do
      it 'lets the block error propagate without marking socket dead' do
        expect {
          socket.puts_if('data') { raise RuntimeError, 'block exploded' }
        }.to raise_error(RuntimeError, 'block exploded')
        expect(socket.alive?).to be true
      end
    end

    context 'when delegate raises a fatal error during write' do
      before { allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET) }

      it 'returns false instead of raising' do
        expect(socket.puts_if('test') { true }).to be false
      end

      it 'marks the socket as dead and closes the delegate' do
        socket.puts_if('test') { true }
        expect(socket.alive?).to be false
        expect(delegate).to have_received(:close)
      end
    end

    context 'when already dead' do
      before do
        allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
        socket.puts_if('die') { true }
      end

      it 'returns false without evaluating the block' do
        block_called = false
        result = socket.puts_if('nope') { block_called = true }
        expect(result).to be false
        expect(block_called).to be false
      end
    end
  end

  # ===========================================================================
  # method_missing -- read-side passthrough
  # ===========================================================================
  describe '#method_missing' do
    it 'delegates read calls to the underlying socket' do
      allow(delegate).to receive(:gets).and_return("game data\n")
      expect(socket.gets).to eq("game data\n")
    end

    it 'lets read-side errors propagate (readers must detect disconnects)' do
      allow(delegate).to receive(:gets).and_raise(Errno::ECONNRESET)
      expect { socket.gets }.to raise_error(Errno::ECONNRESET)
    end

    it 'does not mark the socket as dead on read errors' do
      allow(delegate).to receive(:gets).and_raise(IOError, 'closed stream')
      socket.gets rescue nil
      expect(socket.alive?).to be true
    end

    it 'delegates close to the underlying socket' do
      socket.close
      expect(delegate).to have_received(:close)
    end

    it 'propagates IOError from gets on a closed delegate' do
      allow(delegate).to receive(:gets).and_raise(IOError, 'closed stream')
      expect { socket.gets }.to raise_error(IOError, 'closed stream')
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
    it 'serializes concurrent writes without data loss' do
      call_count = 0
      allow(delegate).to receive(:write) { |_| call_count += 1 }

      threads = 10.times.map do |i|
        Thread.new { socket.write("msg #{i}") }
      end
      threads.each(&:join)

      expect(call_count).to eq(10)
    end

    it 'stops delegating once one write kills the socket mid-burst' do
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
      expect(call_count).to be >= 3
      expect(call_count).to be <= 10
    end

    it 'handles two threads hitting fatal errors simultaneously' do
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
      threads = 2.times.map { Thread.new { socket.write('boom') } }
      threads.each(&:join)

      expect(socket.alive?).to be false
      expect(Lich).to have_received(:log).with(/client socket write failed/).at_most(:twice)
      expect(delegate).to have_received(:close).at_most(:twice)
    end
  end

  # ===========================================================================
  # Recursion prevention (the original PR #1338 scenario)
  # ===========================================================================
  describe 'recursion prevention' do
    it 'short-circuits when error handlers write to the dead socket' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
      allow(delegate).to receive(:write).and_raise(Errno::ECONNRESET)

      socket.puts('initial write')

      100.times { socket.puts('error handler retry') }
      100.times { socket.write('error handler retry') }
      100.times { socket.puts_if('error handler retry') { true } }

      expect(socket.alive?).to be false
      expect(Lich).to have_received(:log).once
      expect(delegate).to have_received(:close).once
    end
  end

  # ===========================================================================
  # FATAL_WRITE_ERRORS -- full coverage matrix
  # ===========================================================================
  describe 'FATAL_WRITE_ERRORS' do
    described_class::FATAL_WRITE_ERRORS.each do |error_class|
      context "#{error_class}" do
        it "absorbs on puts, closes delegate, marks dead" do
          allow(delegate).to receive(:puts).and_raise(error_class.new('test'))
          expect { socket.puts('x') }.not_to raise_error
          expect(socket.alive?).to be false
          expect(delegate).to have_received(:close)
        end

        it "absorbs on write, closes delegate, marks dead" do
          allow(delegate).to receive(:write).and_raise(error_class.new('test'))
          expect { socket.write('x') }.not_to raise_error
          expect(socket.alive?).to be false
          expect(delegate).to have_received(:close)
        end

        it "absorbs on puts_if, closes delegate, marks dead" do
          allow(delegate).to receive(:puts).and_raise(error_class.new('test'))
          expect { socket.puts_if('x') { true } }.not_to raise_error
          expect(socket.alive?).to be false
          expect(delegate).to have_received(:close)
        end
      end
    end
  end
end
