# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/websocket/stream'

# A minimal double standing in for the OpenSSL::SSL::SSLSocket that Stream
# normally wraps. #readpartial deliberately returns small chunks (default 4
# bytes) even when more is already buffered, and #pending reports what's
# left -- exercising the same "OpenSSL already decrypted more than it handed
# back" situation Stream#pump! has to drain itself instead of trusting
# #wait_readable for (see the comment on Stream#pump!).
class FakeSSLSocket
  attr_reader :written

  def initialize(chunk_size: 4)
    @incoming = +''.b
    @written = []
    @closed = false
    @eof = false
    @ssl_error = nil
    @chunk_size = chunk_size
  end

  def feed(bytes)
    @incoming << bytes.b
  end

  def signal_eof!
    @eof = true
  end

  # Simulates a raw TCP close surfacing through OpenSSL as an SSLError
  # instead of an IOError/EOFError -- see Stream#pump!'s handling of it.
  def signal_ssl_error!(message)
    @ssl_error = message
  end

  def readpartial(_maxlen)
    # Mirrors a real SSLSocket: reading after *we* closed it locally (a
    # racing Stream#close/Game.close) raises IOError, distinct from a
    # remote EOF -- see Stream#pump!'s @io.closed? check.
    raise IOError, 'stream closed in another thread' if @closed
    raise OpenSSL::SSL::SSLError, @ssl_error if @incoming.empty? && @ssl_error
    raise EOFError if @incoming.empty? && @eof
    raise IO::EAGAINWaitReadable if @incoming.empty?

    chunk = @incoming.byteslice(0, @chunk_size)
    @incoming = @incoming.byteslice(@chunk_size..-1) || +''.b
    chunk
  end

  def pending
    @incoming.bytesize
  end

  def wait_readable(_timeout = nil)
    return true if @closed || @eof || @ssl_error
    return nil if @incoming.empty?

    true
  end

  # Makes every subsequent #write fail, like a peer that has already reset.
  def fail_writes!(error)
    @write_error = error
  end

  def write(bytes)
    raise @write_error if @write_error

    @written << bytes
    bytes.bytesize
  end

  def close
    @closed = true
  end

  def closed?
    @closed
  end
end

Frame = Lich::Common::WebSocket::Frame

RSpec.describe Lich::Common::WebSocket::Stream do
  # Builds a raw, unmasked server->client frame (server frames must not be masked).
  def server_frame(payload, opcode: Frame::OPCODE_TEXT, fin: true)
    first = (fin ? 0x80 : 0x00) | opcode
    len = payload.bytesize
    length_bytes =
      case len
      when 0..125 then [len].pack('C')
      when 126..0xFFFF then [126, len].pack('Cn')
      else [127, len].pack('CQ>')
      end
    "#{first.chr}#{length_bytes}#{payload}".b
  end

  # Unmasks a client->server frame this test captured from FakeSSLSocket#written,
  # returning [opcode, payload].
  def unmask_client_frame(bytes)
    first = bytes.getbyte(0)
    opcode = first & 0x0F
    second = bytes.getbyte(1)
    len = second & 0x7F
    offset = 2
    case len
    when 126
      len = bytes.byteslice(2, 2).unpack1('n')
      offset = 4
    when 127
      len = bytes.byteslice(2, 8).unpack1('Q>')
      offset = 10
    end
    key = bytes.byteslice(offset, 4)
    payload = Frame.apply_mask(bytes.byteslice(offset + 4, len), key)
    [opcode, payload]
  end

  describe '.connect' do
    it 'closes the raw socket on a failed connect instead of leaking it' do
      # Covers the "close on failure" half of the fix; the Thread#kill-
      # skips-rescue-runs-ensure half (a stalled connect/handshake killed by
      # open_with_timeout's watchdog) needs a real thread and socket to
      # exercise meaningfully and was verified that way in review, not here.
      raw_socket = instance_double(Socket, close: nil, closed?: false)
      allow(Socket).to receive(:tcp).and_return(raw_socket)
      allow(described_class).to receive(:wrap_tls).and_raise(OpenSSL::SSL::SSLError, 'handshake failed')

      expect { described_class.connect(host: 'host', port: 443, path: '/shim/1') }
        .to raise_error(described_class::ConnectionError)
      expect(raw_socket).to have_received(:close)
    end

    it 'does not close the raw socket once connected successfully' do
      raw_socket = instance_double(Socket, close: nil, closed?: false)
      allow(Socket).to receive(:tcp).and_return(raw_socket)
      ssl_socket = FakeSSLSocket.new
      allow(described_class).to receive(:wrap_tls).and_return(ssl_socket)
      allow(described_class).to receive(:read_handshake_response).and_return(['HTTP/1.1 101 x', ''.b])
      allow(Lich::Common::WebSocket::Handshake).to receive(:validate_response)

      described_class.connect(host: 'host', port: 443, path: '/shim/1')

      expect(raw_socket).not_to have_received(:close)
    end

    it 'closes the raw socket when a malformed frame in the same read as the 101 makes .new raise' do
      # Regression: `connected = true` used to run before `new`, so a
      # ProtocolError raised while feeding a bad prefill through the frame
      # reader (inside #initialize) left the ensure block believing the
      # connect had succeeded, leaking raw_socket.
      raw_socket = instance_double(Socket, close: nil, closed?: false)
      allow(Socket).to receive(:tcp).and_return(raw_socket)
      ssl_socket = FakeSSLSocket.new
      allow(described_class).to receive(:wrap_tls).and_return(ssl_socket)
      bad_frame = [0xC1, 0x00].pack('C*') # reserved bit set
      allow(described_class).to receive(:read_handshake_response).and_return(['HTTP/1.1 101 x', bad_frame])
      allow(Lich::Common::WebSocket::Handshake).to receive(:validate_response)

      expect { described_class.connect(host: 'host', port: 443, path: '/shim/1') }
        .to raise_error(described_class::ConnectionError)
      expect(raw_socket).to have_received(:close)
    end
  end

  describe '#gets' do
    it 'returns a line delivered whole in a single frame' do
      io = FakeSSLSocket.new
      io.feed(server_frame("look\n"))
      stream = described_class.new(io)
      expect(stream.gets).to eq("look\n")
    end

    it 'assembles a line split across two frames with no message boundary of its own' do
      io = FakeSSLSocket.new
      io.feed(server_frame('par'))
      io.feed(server_frame("tial\n"))
      stream = described_class.new(io)
      expect(stream.gets).to eq("partial\n")
    end

    it 'returns multiple queued lines one at a time without re-reading the socket' do
      io = FakeSSLSocket.new
      io.feed(server_frame("one\ntwo\n"))
      stream = described_class.new(io)
      expect(stream.gets).to eq("one\n")
      expect(stream.gets).to eq("two\n")
    end

    it 'ingests handshake-remainder prefill bytes immediately' do
      io = FakeSSLSocket.new
      stream = described_class.new(io, prefill: server_frame("prefilled\n"))
      expect(stream.gets).to eq("prefilled\n")
    end

    it 'returns a trailing non-newline-terminated fragment once, then nil, at EOF' do
      io = FakeSSLSocket.new
      io.feed(server_frame('no newline here'))
      io.signal_eof!
      stream = described_class.new(io)
      expect(stream.gets).to eq('no newline here')
      expect(stream.gets).to be_nil
    end

    it 'returns nil immediately at EOF with nothing buffered' do
      io = FakeSSLSocket.new
      io.signal_eof!
      stream = described_class.new(io)
      expect(stream.gets).to be_nil
    end

    it 'treats a raw TCP close surfaced as SSLError("unexpected eof while reading") as EOF' do
      io = FakeSSLSocket.new
      io.signal_ssl_error!('unexpected eof while reading')
      stream = described_class.new(io)
      expect(stream.gets).to be_nil
    end

    it 're-raises any other SSLError instead of treating it as EOF' do
      io = FakeSSLSocket.new
      io.signal_ssl_error!('certificate verify failed')
      stream = described_class.new(io)
      expect { stream.gets }.to raise_error(OpenSSL::SSL::SSLError, 'certificate verify failed')
    end

    it 're-raises IOError from a local close instead of treating it as a remote EOF' do
      # A racing Stream#close (or Game.close) closing the same socket the
      # reader thread is blocked on raises "stream closed in another
      # thread" -- @io.closed? is how #pump! tells that apart from the
      # remote end actually hanging up (which leaves @io open).
      io = FakeSSLSocket.new
      stream = described_class.new(io)
      io.close

      expect { stream.gets }.to raise_error(IOError, 'stream closed in another thread')
    end
  end

  describe '#wait_readable' do
    it 'drains already-fed data via #pending without calling the underlying #wait_readable' do
      io = FakeSSLSocket.new
      io.feed(server_frame("ready\n"))
      stream = described_class.new(io)
      stream.gets # drains the frame into the line buffer... and returns it

      io.feed(server_frame("next\n"))
      def io.wait_readable(*)
        raise 'wait_readable should not be called while #pending is positive'
      end
      expect(stream.wait_readable(1)).to be(true)
    end

    it 'returns false on timeout when the underlying socket never becomes readable' do
      io = FakeSSLSocket.new
      def io.wait_readable(_timeout = nil) = nil # never ready, never EOF
      stream = described_class.new(io)
      expect(stream.wait_readable(0)).to be(false)
    end

    it 'returns true at EOF even with no buffered line' do
      io = FakeSSLSocket.new
      io.signal_eof!
      stream = described_class.new(io)
      expect(stream.wait_readable(1)).to be(true)
    end
  end

  describe '#puts' do
    it 'sends a single masked text frame' do
      io = FakeSSLSocket.new
      stream = described_class.new(io)
      stream.puts('north')
      expect(io.written.size).to eq(1)
      opcode, payload = unmask_client_frame(io.written.first)
      expect(opcode).to eq(Frame::OPCODE_TEXT)
      expect(payload).to eq("north\n")
    end

    it "does not double a trailing newline the caller already included" do
      io = FakeSSLSocket.new
      stream = described_class.new(io)
      stream.puts("north\n")
      _opcode, payload = unmask_client_frame(io.written.first)
      expect(payload).to eq("north\n")
    end
  end

  describe 'ping/pong keepalive' do
    it 'answers a server ping with a pong carrying the same payload' do
      io = FakeSSLSocket.new
      io.feed(server_frame('ping-token', opcode: Frame::OPCODE_PING))
      io.feed(server_frame("after\n"))
      stream = described_class.new(io)
      expect(stream.gets).to eq("after\n")

      pong_frames = io.written.map { |bytes| unmask_client_frame(bytes) }
                              .select { |opcode, _| opcode == Frame::OPCODE_PONG }
      expect(pong_frames.size).to eq(1)
      expect(pong_frames.first.last).to eq('ping-token')
    end
  end

  describe 'server close' do
    it 'answers a close frame, marks the stream at EOF, and #gets returns nil' do
      io = FakeSSLSocket.new
      io.feed(server_frame([1000].pack('n'), opcode: Frame::OPCODE_CLOSE))
      stream = described_class.new(io)
      expect(stream.gets).to be_nil

      close_frames = io.written.map { |bytes| unmask_client_frame(bytes) }
                               .select { |opcode, _| opcode == Frame::OPCODE_CLOSE }
      expect(close_frames.size).to eq(1)
    end
  end

  describe 'a protocol violation arriving after a valid frame in the same read' do
    it 'still surfaces the valid line before raising, instead of discarding it' do
      # Regression: Frame::Reader#feed used to lose messages it had already
      # decoded earlier in the same call when a later frame in that call
      # raised ProtocolError -- often the last, most explanatory line before
      # a forced disconnect.
      io = FakeSSLSocket.new(chunk_size: 4096) # deliver both frames in one #readpartial
      io.feed(server_frame("last words\n"))
      io.feed([0xC1, 0x00].pack('C*')) # reserved bit set -- fatal
      stream = described_class.new(io)

      expect(stream.gets).to eq("last words\n")
      expect { stream.gets }.to raise_error(Frame::ProtocolError, /reserved/)
    end

    it 'keeps the ProtocolError as the failure when answering a salvaged ping fails to write' do
      io = FakeSSLSocket.new(chunk_size: 4096)
      io.feed(server_frame("last words\n"))
      io.feed(server_frame('hb', opcode: Frame::OPCODE_PING))
      io.feed([0xC1, 0x00].pack('C*')) # reserved bit set -- fatal
      io.fail_writes!(Errno::EPIPE.new)
      stream = described_class.new(io)

      expect(stream.gets).to eq("last words\n")
      expect { stream.gets }.to raise_error(Frame::ProtocolError, /reserved/)
    end

    it 'still surfaces a trailing newline-less tail before raising, the same way EOF does' do
      # Regression: #gets checked @pending_error before flush_remaining!, so
      # a non-newline-terminated tail decoded just before the violation was
      # discarded instead of returned once (matching how the @eof branch
      # already flushes a leftover tail via #flush_remaining!).
      io = FakeSSLSocket.new(chunk_size: 4096)
      io.feed(server_frame("last words\ntail-no-newline"))
      io.feed([0xC1, 0x00].pack('C*')) # reserved bit set -- fatal
      stream = described_class.new(io)

      expect(stream.gets).to eq("last words\n")
      expect(stream.gets).to eq('tail-no-newline')
      expect { stream.gets }.to raise_error(Frame::ProtocolError, /reserved/)
    end
  end

  describe '#close' do
    it 'sends a normal-closure close frame and closes the underlying socket' do
      io = FakeSSLSocket.new
      stream = described_class.new(io)
      stream.close
      opcode, payload = unmask_client_frame(io.written.first)
      expect(opcode).to eq(Frame::OPCODE_CLOSE)
      expect(payload.unpack1('n')).to eq(1000)
      expect(io.closed?).to be(true)
      expect(stream.closed?).to be(true)
    end
  end

  describe '#sync=' do
    it 'accepts and ignores the assignment (no internal write buffering to flush)' do
      stream = described_class.new(FakeSSLSocket.new)
      expect { stream.sync = true }.not_to raise_error
    end
  end
end
