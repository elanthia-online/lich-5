# frozen_string_literal: true

require_relative '../../spec_helper'
require 'socket'
require 'common/class_exts/synchronizedsocket'
require 'common/shutdown_coordinator'
require 'common/shutdown_log'

RSpec.describe Lich::Common::SynchronizedSocket do
  let(:delegate) { instance_double(TCPSocket) }
  let(:socket) { described_class.new(delegate) }

  before do
    Lich::Common::ShutdownCoordinator.reset!
    allow(delegate).to receive(:closed?).and_return(false)
    allow(delegate).to receive(:close)
    allow(Lich).to receive(:log)
  end

  def eventually(timeout: 1)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      begin
        return yield
      rescue RSpec::Expectations::ExpectationNotMetError
        raise if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.005
      end
    end
  end

  after do
    socket.close rescue nil
    Lich::Common::ShutdownCoordinator.reset!
  end

  # ===========================================================================
  # Initialization
  # ===========================================================================
  describe '#initialize' do
    it 'starts alive with an open delegate' do
      expect(socket.alive?).to be true
    end

    it 'rejects invalid roles and queue capacities' do
      expect { described_class.new(delegate, role: :unknown) }.to raise_error(ArgumentError, /role/)
      expect { described_class.new(delegate, write_queue_capacity: 0) }.to raise_error(ArgumentError, /capacity/)
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
      eventually { expect(socket.alive?).to be false }
    end

    it 'cannot be revived once dead' do
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
      socket.write('die')

      eventually { expect(socket.alive?).to be false }

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
      eventually { expect(delegate).to have_received(:close) }
    end

    it 'closes the delegate when puts fails fatally' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
      socket.puts('data')
      eventually { expect(delegate).to have_received(:close) }
    end

    it 'closes the delegate when puts_if fails fatally' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNABORTED)
      socket.puts_if('data') { true }
      eventually { expect(delegate).to have_received(:close) }
    end

    it 'survives delegate.close raising during failure cleanup' do
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
      allow(delegate).to receive(:close).and_raise(IOError, 'already closed')
      expect { socket.write('data') }.not_to raise_error
      eventually { expect(socket.alive?).to be false }
    end

    it 'logs exactly once even when multiple writes fail' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
      3.times { socket.puts('retry') }
      eventually { expect(Lich).to have_received(:log).with(/client socket write failed/).once }
    end

    it 'records client disconnect when a fatal write fails before shutdown starts' do
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)

      socket.puts('data')

      eventually { expect(Lich::Common::ShutdownCoordinator.reason).to eq(:client_disconnect) }
      expect(Lich::Common::ShutdownCoordinator.current.source).to eq('client_socket_write')
      expect(Lich::Common::ShutdownCoordinator).to be_client_socket_write_failed
    end

    it 'isolates a detachable-client write failure from process shutdown' do
      detachable = described_class.new(delegate, role: :detachable)
      allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)

      detachable.puts('data')

      eventually { expect(detachable.alive?).to be false }
      expect(Lich::Common::ShutdownCoordinator.current).to be_nil
    ensure
      detachable&.close rescue nil
    end

    it 'preserves an existing user-exit reason while recording the write failure' do
      Lich::Common::ShutdownCoordinator.request(reason: :user_exit, source: :primary_frontend)
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)

      socket.write('data')

      eventually { expect(Lich::Common::ShutdownCoordinator).to be_client_socket_write_failed }
      expect(Lich::Common::ShutdownCoordinator.reason).to eq(:user_exit)
      expect(Lich::Common::ShutdownCoordinator.current.source).to eq('primary_frontend')
      expect(Lich::Common::ShutdownCoordinator).to be_client_socket_write_failed
    end

    it 'flushes buffered user-exit context before logging a write failure' do
      messages = []
      allow(Lich).to receive(:log) { |message| messages << message }
      Lich::Common::ShutdownLog.begin_user_exit_summary!
      Lich::Common::ShutdownLog.info('shutdown requested reason=user_exit source=primary_frontend')
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)

      socket.write('data')

      info_index = nil
      error_index = nil
      eventually do
        info_index = messages.index('info: shutdown requested reason=user_exit source=primary_frontend')
        error_index = messages.index { |message| message.match?(/error: client socket write failed: Errno::EPIPE/) }
        expect(info_index).not_to be_nil
        expect(error_index).not_to be_nil
      end
      expect(info_index).to be < error_index
    end

    it 'closes the delegate exactly once under repeated failures' do
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
      3.times { socket.write('retry') }
      eventually { expect(delegate).to have_received(:close).once }
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
      eventually { expect(delegate).to have_received(:puts).with('hello') }
    end

    described_class::FATAL_WRITE_ERRORS.each do |error_class|
      context "when delegate raises #{error_class}" do
        before { allow(delegate).to receive(:puts).and_raise(error_class.new('test')) }

        it 'returns nil instead of raising' do
          expect(socket.puts('test')).to be_nil
        end

        it 'marks the socket as dead and closes the delegate' do
          socket.puts('test')
          eventually { expect(socket.alive?).to be false }
          expect(delegate).to have_received(:close)
        end
      end
    end

    context 'when delegate raises a non-fatal error' do
      before { allow(delegate).to receive(:puts).and_raise(ArgumentError, 'bad args') }

      it 'logs the writer error without propagating it to the producer' do
        expect { socket.puts('test') }.not_to raise_error
        eventually { expect(Lich).to have_received(:log).with(/client socket writer failed: ArgumentError/) }
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
        eventually { expect(socket.alive?).to be false }
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
      eventually { expect(delegate).to have_received(:puts).with(no_args) }
    end

    it 'forwards multiple arguments' do
      allow(delegate).to receive(:puts).with('a', 'b', 'c')
      socket.puts('a', 'b', 'c')
      eventually { expect(delegate).to have_received(:puts).with('a', 'b', 'c') }
    end
  end

  # ===========================================================================
  # write -- write-side resilience
  # ===========================================================================
  describe '#write' do
    it 'queues the write and returns nil' do
      allow(delegate).to receive(:write).with('data').and_return(4)
      expect(socket.write('data')).to be_nil
      eventually { expect(delegate).to have_received(:write).with('data') }
    end

    context 'when delegate raises Errno::ECONNRESET' do
      before { allow(delegate).to receive(:write).and_raise(Errno::ECONNRESET) }

      it 'returns nil instead of raising' do
        expect(socket.write('test')).to be_nil
      end

      it 'marks the socket as dead and closes the delegate' do
        socket.write('test')
        eventually { expect(socket.alive?).to be false }
        expect(delegate).to have_received(:close)
      end
    end

    context 'when already dead' do
      before do
        allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
        socket.write('die')
        eventually { expect(socket.alive?).to be false }
      end

      it 'returns nil without touching the delegate again' do
        expect(delegate).to have_received(:write).once
        socket.write('nope')
        expect(delegate).to have_received(:write).once
      end
    end
  end

  # ===========================================================================
  # wire encoding -- every write to a frontend-facing delegate goes through
  # Lich::Common::WireEncoding.encode. Regression coverage: this used to be
  # the caller's job (send_to_client had its own explicit encode call), which
  # meant callers that forgot (respond, _respond,
  # detachable_client_send_init, detachable_client_send_player_id) sent raw
  # UTF-8 to frontends that expect Windows-1252. Centralizing it here closes
  # every call site, current and future, in one place.
  # ===========================================================================
  describe 'wire encoding on write' do
    it 'encodes a #puts argument containing real non-ASCII text to Windows-1252 before writing' do
      allow(delegate).to receive(:puts)
      socket.puts("chest\u2019s lid") # rubocop:disable Custom/AsciiOnlySource
      eventually { expect(delegate).to have_received(:puts).with("chest\x92s lid".b) } # rubocop:disable Custom/AsciiOnlySource
    end

    it 'encodes a #write argument the same way' do
      allow(delegate).to receive(:write)
      socket.write("chest\u2019s lid") # rubocop:disable Custom/AsciiOnlySource
      eventually { expect(delegate).to have_received(:write).with("chest\x92s lid".b) } # rubocop:disable Custom/AsciiOnlySource
    end

    it 'encodes a #puts_main_stream argument the same way' do
      allow(delegate).to receive(:puts)
      socket.puts_main_stream("chest\u2019s lid") # rubocop:disable Custom/AsciiOnlySource
      eventually { expect(delegate).to have_received(:puts).with("chest\x92s lid".b) } # rubocop:disable Custom/AsciiOnlySource
    end

    it 'does not raise and preserves both marker and text for a Wizard marker plus non-ASCII text' do
      allow(delegate).to receive(:puts)
      marker_text = "#{Lich::Common::WireEncoding::WIZARD_SPEECH_START}chest\u2019s words#{Lich::Common::WireEncoding::WIZARD_SPEECH_END}" # rubocop:disable Custom/AsciiOnlySource
      expect { socket.puts(marker_text) }.not_to raise_error
      eventually { expect(delegate).to have_received(:puts).with("\x8Achest\x92s words\xA0".b) } # rubocop:disable Custom/AsciiOnlySource
    end

    it 'leaves plain ASCII byte-identical (only the encoding tag changes)' do
      allow(delegate).to receive(:puts)
      socket.puts('hello there')
      eventually { expect(delegate).to have_received(:puts).with('hello there') }
    end

    it 'leaves a non-String argument (e.g. nil from a caller with no args) untouched' do
      allow(delegate).to receive(:puts).with(no_args)
      socket.puts
      eventually { expect(delegate).to have_received(:puts).with(no_args) }
    end
  end

  # ===========================================================================
  # puts_main_stream -- main-stream write resilience
  # ===========================================================================
  describe '#puts_main_stream' do
    it 'accepts and writes output when no frontend stream is open' do
      allow(delegate).to receive(:puts).with('data')
      expect(socket.puts_main_stream('data')).to be true
      eventually { expect(delegate).to have_received(:puts).with('data') }
    end

    it 'defers output until a queued frontend stream closes' do
      writes = []
      allow(delegate).to receive(:write) { |data| writes << data }
      allow(delegate).to receive(:puts) { |data| writes << data }

      socket.write('<pushStream id="room">room text')
      expect(socket.puts_main_stream('script output')).to be true
      socket.write('</pushStream><popStream id="room"/>')

      eventually { expect(writes).to eq(['<pushStream id="room">room text', '</pushStream><popStream id="room"/>', 'script output']) }
    end

    it 'waits until nested streams have all closed' do
      writes = []
      allow(delegate).to receive(:write) { |data| writes << data }
      allow(delegate).to receive(:puts) { |data| writes << data }

      socket.write('<pushStream id="room">')
      socket.write('<pushStream id="inventory">')
      socket.puts_main_stream('main output')
      socket.write('<popStream id="inventory"/>')

      eventually { expect(writes).to eq(['<pushStream id="room">', '<pushStream id="inventory">', '<popStream id="inventory"/>']) }

      socket.write('<popStream id="room"/>')
      eventually { expect(writes.last(2)).to eq(['<popStream id="room"/>', 'main output']) }
    end

    it 'waits for a known main-stream boundary after attaching midstream' do
      writes = []
      detachable = described_class.new(delegate, role: :detachable)
      allow(delegate).to receive(:write) { |data| writes << data }
      allow(delegate).to receive(:puts) { |data| writes << data }

      detachable.puts_main_stream('attached output')
      sleep 0.02
      expect(writes).to be_empty

      detachable.write('<popStream id="room"/>')
      eventually { expect(writes).to eq(['<popStream id="room"/>', 'attached output']) }
    ensure
      detachable&.close rescue nil
    end

    it 'retains puts_if as a compatibility alias' do
      allow(delegate).to receive(:puts).with('legacy')

      expect(socket.puts_if('legacy') { raise 'ignored' }).to be true
      eventually { expect(delegate).to have_received(:puts).with('legacy') }
    end

    it 'preserves FIFO order across mixed puts and writes' do
      writes = []
      allow(delegate).to receive(:write) { |data| writes << [:write, data] }
      allow(delegate).to receive(:puts) { |data| writes << [:puts, data] }

      socket.write('one')
      socket.puts('two')
      socket.write('three')

      eventually { expect(writes).to eq([[:write, 'one'], [:puts, 'two'], [:write, 'three']]) }
    end

    context 'when delegate raises a fatal error during write' do
      before { allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET) }

      it 'accepts the asynchronous write without raising' do
        expect(socket.puts_main_stream('test')).to be true
      end

      it 'marks the socket as dead and closes the delegate' do
        socket.puts_main_stream('test')
        eventually { expect(socket.alive?).to be false }
        expect(delegate).to have_received(:close)
      end
    end

    context 'when already dead' do
      before do
        allow(delegate).to receive(:puts).and_raise(Errno::ECONNRESET)
        socket.puts_main_stream('die')
        eventually { expect(socket.alive?).to be false }
      end

      it 'returns false' do
        expect(socket.puts_main_stream('nope')).to be false
      end
    end
  end

  describe 'bounded writer queue' do
    it 'disconnects a slow detachable client without requesting process shutdown' do
      write_started = Queue.new
      release_write = Queue.new
      bounded = described_class.new(delegate, role: :detachable, write_queue_capacity: 1)
      allow(delegate).to receive(:write) do
        write_started << true
        release_write.pop
      end

      bounded.write('blocked')
      write_started.pop
      bounded.write('queued')
      bounded.write('overflow')

      expect(bounded.alive?).to be false
      expect(Lich::Common::ShutdownCoordinator.current).to be_nil
      expect(delegate).to have_received(:close).once
    ensure
      release_write << true if release_write
      bounded&.close rescue nil
    end

    it 'requests shutdown when the primary client queue overflows' do
      write_started = Queue.new
      release_write = Queue.new
      bounded = described_class.new(delegate, write_queue_capacity: 1)
      allow(delegate).to receive(:write) do
        write_started << true
        release_write.pop
      end

      bounded.write('blocked')
      write_started.pop
      bounded.write('queued')
      bounded.write('overflow')

      expect(bounded.alive?).to be false
      expect(Lich::Common::ShutdownCoordinator.reason).to eq(:client_disconnect)
    ensure
      release_write << true if release_write
      bounded&.close rescue nil
    end

    it 'dumps the still-pending queued writes to Lich.log on overflow' do
      write_started = Queue.new
      release_write = Queue.new
      logged = []
      allow(Lich).to receive(:log) { |message| logged << message.to_s }
      bounded = described_class.new(delegate, role: :detachable, write_queue_capacity: 2)
      allow(delegate).to receive(:write) do
        write_started << true
        release_write.pop
      end

      bounded.write('blocked')
      write_started.pop
      bounded.write("first pending\r\n")
      bounded.write('second pending')
      bounded.write('rejected')

      dump = logged.find { |message| message.include?('overflow dump') }
      expect(dump).to include('2 queued, 0 deferred (capacity=2, role=detachable)')
      expect(dump).to include('queued[0] write "first pending\\r\\n"')
      expect(dump).to include('queued[1] write "second pending"')
    ensure
      release_write << true if release_write
      bounded&.close rescue nil
    end

    it 'dumps deferred main-stream writes and truncates oversized payloads' do
      write_started = Queue.new
      release_write = Queue.new
      logged = []
      allow(Lich).to receive(:log) { |message| logged << message.to_s }
      oversized = 'x' * (described_class::OVERFLOW_DUMP_MAX_BYTES_PER_ARG + 10)
      bounded = described_class.new(delegate, role: :detachable, write_queue_capacity: 2)
      allow(delegate).to receive(:write) do
        write_started << true
        release_write.pop
      end
      allow(delegate).to receive(:puts)

      bounded.write('<pushStream id="thoughts"/>')
      write_started.pop
      expect(bounded.puts_main_stream('deferred line')).to be true
      bounded.write(oversized)
      bounded.write('rejected')

      dump = logged.find { |message| message.include?('overflow dump') }
      expect(dump).to include('1 queued, 1 deferred (capacity=2, role=detachable)')
      expect(dump).to include('deferred[0] puts "deferred line"')
      expect(dump).to include("...(#{oversized.bytesize} bytes total)")
    ensure
      release_write << true if release_write
      bounded&.close rescue nil
    end

    it 'does not dump pending writes for ordinary fatal write errors' do
      logged = []
      allow(Lich).to receive(:log) { |message| logged << message.to_s }
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)

      socket.write('boom')

      eventually { expect(socket.alive?).to be false }
      expect(logged.any? { |message| message.include?('overflow dump') }).to be false
    end
  end

  describe 'write queue compaction' do
    let(:keep) { described_class::OVERFLOW_KEEP_PROMPT_GROUPS }

    # Blocks the writer thread on its first write so the queue accumulates,
    # then fills the queue with `groups` prompt-terminated groups of one
    # write each. Returns the socket and the release gate.
    def stalled_socket_with_groups(groups, capacity:)
      write_started = Queue.new
      release_write = Queue.new
      bounded = described_class.new(delegate, role: :primary, write_queue_capacity: capacity)
      allow(delegate).to receive(:write) do
        write_started << true
        release_write.pop
      end
      bounded.write('blocker')
      write_started.pop
      groups.times { |i| bounded.write("line#{i}<prompt time=\"#{i}\">&gt;</prompt>") }
      [bounded, release_write]
    end

    it 'drops the oldest prompt groups instead of killing the session' do
      logged = []
      allow(Lich).to receive(:log) { |message| logged << message.to_s }
      bounded, release = stalled_socket_with_groups(keep + 2, capacity: keep + 2)

      # This write would previously have overflowed and ended the session.
      bounded.write('survivor<prompt time="99">&gt;</prompt>')

      expect(bounded.alive?).to be true
      expect(Lich::Common::ShutdownCoordinator.current).to be_nil
      compaction = logged.find { |m| m.include?('dropped') && m.include?('prompt groups') }
      expect(compaction).to include("write queue reached #{keep + 2}")
      expect(compaction).to include('role=primary')
    ensure
      release << true if release
      bounded&.close rescue nil
    end

    it 'retains the newest groups and discards the oldest' do
      written = []
      allow(delegate).to receive(:puts) { |arg| written << arg.to_s }
      bounded, release = stalled_socket_with_groups(keep + 3, capacity: keep + 3)
      bounded.write('newest<prompt time="99">&gt;</prompt>')

      # Recorder must be installed before the writer is unblocked, or early
      # writes are consumed by the stall stub and never observed.
      allow(delegate).to receive(:write) { |arg| written << arg.to_s }
      release << true

      eventually(timeout: 2) { expect(written.any? { |w| w.include?('newest') }).to be true }
      expect(written.any? { |w| w.include?('line0') }).to be false
    ensure
      release << true if release
      bounded&.close rescue nil
    end

    it 'still ends the session when there are too few prompt groups to compact' do
      write_started = Queue.new
      release_write = Queue.new
      bounded = described_class.new(delegate, role: :detachable, write_queue_capacity: 3)
      allow(delegate).to receive(:write) do
        write_started << true
        release_write.pop
      end

      # No prompts anywhere, so there is exactly one group and nothing to drop.
      bounded.write('blocker')
      write_started.pop
      3.times { |i| bounded.write("nopromptline#{i}") }
      bounded.write('overflows')

      expect(bounded.alive?).to be false
    ensure
      release_write << true if release_write
      bounded&.close rescue nil
    end

    it 'defaults to a 4096 write capacity' do
      expect(described_class::DEFAULT_WRITE_QUEUE_CAPACITY).to eq(4_096)
    end

    it 'injects a client-visible notice reporting how many lines were dropped' do
      written = []
      bounded, release = stalled_socket_with_groups(keep + 3, capacity: keep + 3)
      allow(delegate).to receive(:write) { |arg| written << arg.to_s }
      bounded.write('newest<prompt time="99">&gt;</prompt>')
      release << true

      eventually(timeout: 2) { expect(written.any? { |w| w.include?('fell behind') }).to be true }
      notice = written.find { |w| w.include?('fell behind') }
      expect(notice).to match(/dropped \d+ lines of display output/)
      # No XML-special characters, so no frontend-specific encoding is needed.
      expect(notice).not_to match(/[<>&]/)
    ensure
      release << true if release
      bounded&.close rescue nil
    end

    it 'replays a prompt before the notice so it cannot land in an open stream' do
      written = []
      bounded, release = stalled_socket_with_groups(keep + 3, capacity: keep + 3)
      allow(delegate).to receive(:write) { |arg| written << arg.to_s }
      bounded.write('newest<prompt time="99">&gt;</prompt>')
      release << true

      eventually(timeout: 2) { expect(written.any? { |w| w.include?('fell behind') }).to be true }
      notice_at = written.index { |w| w.include?('fell behind') }
      expect(notice_at).to be > 0
      expect(written[notice_at - 1]).to match(/<prompt\b/)
    ensure
      release << true if release
      bounded&.close rescue nil
    end

    it 'does not notify when nothing was dropped' do
      written = []
      allow(delegate).to receive(:write) { |arg| written << arg.to_s }
      socket.write("only line<prompt time=\"1\">&gt;</prompt>")

      eventually { expect(written).not_to be_empty }
      expect(written.any? { |w| w.include?('fell behind') }).to be false
    end

    # Regression: the injected preamble consumes queue budget. If retention
    # ignores it, a tight capacity leaves the queue full after compaction and
    # the session dies anyway (this spec failed before retained_groups existed).
    it 'leaves room for the preamble at a capacity barely above the keep count' do
      capacity = keep + 2
      bounded, release = stalled_socket_with_groups(keep + 2, capacity: capacity)
      bounded.write('survivor<prompt time="99">&gt;</prompt>')

      expect(bounded.alive?).to be true
      expect(bounded.instance_variable_get(:@write_queue).length).to be <= capacity
    ensure
      release << true if release
      bounded&.close rescue nil
    end

    # Regression: compact_write_queue! used to refuse to compact whenever
    # groups.length <= OVERFLOW_KEEP_PROMPT_GROUPS, treating that retention
    # cap as a precondition for compacting at all rather than a ceiling on
    # what's kept. A handful of large prompt groups can still fill a small
    # queue and provide safe drop boundaries -- this failed before the fix
    # (session ended even though two of the four groups could safely be
    # dropped).
    it 'compacts a tight queue even when far fewer groups exist than the retention cap' do
      write_started = Queue.new
      release_write = Queue.new
      bounded = described_class.new(delegate, role: :primary, write_queue_capacity: 8)
      allow(delegate).to receive(:write) do
        write_started << true
        release_write.pop
      end
      bounded.write('blocker')
      write_started.pop

      # Four two-write prompt groups exactly fill an 8-capacity queue, well
      # under OVERFLOW_KEEP_PROMPT_GROUPS (10).
      4.times do |i|
        bounded.write("group#{i}line1")
        bounded.write("group#{i}line2<prompt time=\"#{i}\">&gt;</prompt>")
      end

      # This write would previously have overflowed and ended the session
      # even though compaction had room to drop groups.
      bounded.write('survivor<prompt time="99">&gt;</prompt>')

      expect(bounded.alive?).to be true
      expect(Lich::Common::ShutdownCoordinator.current).to be_nil
    ensure
      release_write << true if release_write
      bounded&.close rescue nil
    end

    # Regression: retained_groups sized its budget only against
    # write_queue_capacity, ignoring @deferred_main_stream even though
    # ensure_pending_capacity! counts write_queue.length + deferred writes as
    # a single pending total. Compaction could report success while
    # pending_length stayed pinned at capacity, so the very next capacity
    # check overflowed anyway. This asserts the real invariant (pending
    # writes fall below capacity after a successful compaction) rather than
    # an implementation-detail count, and fails before the fix because
    # pending_length lands exactly at capacity instead of under it.
    it 'reserves budget for already-deferred main-stream writes during compaction' do
      capacity = 12
      bounded = described_class.new(delegate, write_queue_capacity: capacity)
      bounded.send(:ensure_writer_state)
      queue = bounded.instance_variable_get(:@write_queue)
      11.times { |i| queue.push([:write, ["line#{i}<prompt time=\"#{i}\">&gt;</prompt>"], nil], true) }
      bounded.instance_variable_set(:@deferred_main_stream, ['pending main-stream write'])

      expect(bounded.send(:compact_write_queue!)).to be true

      pending_length = queue.length + bounded.instance_variable_get(:@deferred_main_stream).length
      expect(pending_length).to be < capacity
    end

    # requeue_writes is reached only from compaction, where the retention budget
    # makes a full queue unreachable. This exercises the defensive path directly
    # so a future change to that budget surfaces as a counted loss rather than a
    # generic compaction error with silently discarded writes.
    it 'reports how many writes could not be requeued' do
      bounded = described_class.new(delegate, write_queue_capacity: 4)
      bounded.instance_variable_set(:@write_queue, SizedQueue.new(4))
      oversized = Array.new(6) { |i| [:write, ["item#{i}"], nil] }

      lost = bounded.send(:requeue_writes, [oversized], [])

      expect(lost).to eq(2)
      expect(bounded.instance_variable_get(:@write_queue).length).to eq(4)
    end

    it 'preserves the stop sentinel across the diagnostic drain' do
      bounded = described_class.new(delegate, write_queue_capacity: 8)
      queue = SizedQueue.new(8)
      bounded.instance_variable_set(:@write_queue, queue)
      queue.push([:write, ['payload'], nil], true)
      queue.push([:stop, [], nil], true)

      drained = bounded.send(:drain_write_queue)

      expect(drained).to eq([[:write, ['payload']]])
      expect(queue.length).to eq(1)
      expect(queue.pop(true)).to eq([:stop, [], nil])
    end

    it 'bounds the overflow dump and reports how many entries were omitted' do
      logged = []
      allow(Lich).to receive(:log) { |message| logged << message.to_s }
      edge = described_class::OVERFLOW_DUMP_EDGE_ENTRIES
      total = (edge * 2) + 25
      bounded = described_class.new(delegate, write_queue_capacity: total + 1)
      queue = SizedQueue.new(total + 1)
      bounded.instance_variable_set(:@write_queue, queue)
      bounded.instance_variable_set(:@stream_mutex, Mutex.new)
      bounded.instance_variable_set(:@deferred_main_stream, [])
      total.times { |i| queue.push([:write, ["entry#{i}"], nil], true) }

      bounded.send(:log_pending_writes)

      dump = logged.find { |m| m.include?('overflow dump') }
      expect(dump).to include("#{total} queued, 0 deferred")
      expect(dump).to include('... 25 queued entries omitted ...')
      expect(dump).to include('queued[0] write')
      expect(dump).to include("queued[#{total - 1}] write")
      expect(dump).not_to include("queued[#{edge}] write")
      expect(dump.lines.length).to eq((edge * 2) + 2) # header + 400 entries + marker
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

      eventually { expect(call_count).to eq(10) }
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

      eventually { expect(socket.alive?).to be false }
      expect(call_count).to be >= 3
      expect(call_count).to be <= 10
    end

    it 'handles two threads hitting fatal errors simultaneously' do
      allow(delegate).to receive(:write).and_raise(Errno::EPIPE)
      threads = 2.times.map { Thread.new { socket.write('boom') } }
      threads.each(&:join)

      eventually { expect(socket.alive?).to be false }
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

      eventually { expect(socket.alive?).to be false }

      100.times { socket.puts('error handler retry') }
      100.times { socket.write('error handler retry') }
      100.times { socket.puts_main_stream('error handler retry') }

      expect(socket.alive?).to be false
      expect(Lich).to have_received(:log).with(/client socket write failed/).once
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
          eventually { expect(socket.alive?).to be false }
          expect(delegate).to have_received(:close)
        end

        it "absorbs on write, closes delegate, marks dead" do
          allow(delegate).to receive(:write).and_raise(error_class.new('test'))
          expect { socket.write('x') }.not_to raise_error
          eventually { expect(socket.alive?).to be false }
          expect(delegate).to have_received(:close)
        end

        it "absorbs on puts_main_stream, closes delegate, marks dead" do
          allow(delegate).to receive(:puts).and_raise(error_class.new('test'))
          expect { socket.puts_main_stream('x') }.not_to raise_error
          eventually { expect(socket.alive?).to be false }
          expect(delegate).to have_received(:close)
        end
      end
    end
  end
end
