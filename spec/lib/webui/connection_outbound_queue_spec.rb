# frozen_string_literal: true

require_relative '../../spec_helper'
require 'socket'
require 'timeout'
require 'webui/server'

RSpec.describe Lich::WebUI::Server::Connection do
  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Reassembles one unmasked, possibly fragmented server text message.
  def read_text(socket, seconds = 2)
    Timeout.timeout(seconds) do
      data = +''
      loop do
        frame = Lich::WebUI::WebSocket.read_frame(socket, require_mask: false, allow_fragments: true)
        data << frame.payload
        break data if frame.final
      end
    end
  end

  def stalled_pair
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    sender.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, 4096)
    [sender, receiver]
  end

  # Writes until the kernel refuses more, so the next write stalls whatever the platform's
  # socket buffer size. Windows AF_UNIX sockets absorb far more than SO_SNDBUF suggests, so a
  # fixed message size does not reliably stall there. Bounded by time and by bytes.
  def fill_send_buffer(sender, limit: 512 * 1024 * 1024)
    chunk = 'f' * 65_536
    total = 0
    deadline = monotonic + 5
    loop do
      written = sender.write_nonblock(chunk, exception: false)
      break if written == :wait_writable

      total += written
      raise "send buffer never filled (#{total} bytes)" if total > limit || monotonic > deadline
    end
  end

  it 'returns to a broadcasting caller at once and still delivers to other viewers when one peer stops reading' do
    slow_sender, slow_receiver = stalled_pair
    fast_sender, fast_receiver = Socket.pair(:UNIX, :STREAM, 0)
    slow = described_class.new(slow_sender)
    fast = described_class.new(fast_sender)
    server = Lich::WebUI::Server.new(assets_dir: Dir.pwd, pages_provider: -> { [] }, message_handler: proc {})
    server.instance_variable_get(:@connections).push(slow, fast)
    large = JSON.generate(type: 'pages', pages: ['x' * (512 * 1024)])

    started = monotonic
    3.times { server.broadcast(large) }
    server.broadcast(type: 'pages', pages: ['last'])
    elapsed = monotonic - started

    expect(elapsed).to be < 1.0
    expect(3.times.map { read_text(fast_receiver) }).to all(eq(large))
    expect(JSON.parse(read_text(fast_receiver))).to eq('type' => 'pages', 'pages' => ['last'])
    expect(slow).to be_alive
  ensure
    [slow, fast].each { |connection| connection&.close }
    [slow_sender, slow_receiver, fast_sender, fast_receiver].each { |socket| socket&.close }
  end

  it 'writes queued messages in send order on one writer' do
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    connection = described_class.new(sender)
    messages = Array.new(20) { |index| JSON.generate(index: index, pad: 'p' * (index * 4096)) }
    messages.each { |message| expect(connection.send_text(message)).to be(true) }

    expect(messages.map { read_text(receiver) }).to eq(messages)
  ensure
    connection&.close
    sender&.close
    receiver&.close
  end

  it 'retires an overflowing connection and clears every undelivered message' do
    stub_const("#{described_class}::MAX_QUEUED_BYTES", 256 * 1024)
    sender, receiver = stalled_pair
    connection = described_class.new(sender)
    queue = connection.instance_variable_get(:@queue)
    retained = []
    allow(queue).to receive(:<<).and_wrap_original do |original, bytes|
      retained << bytes
      original.call(bytes)
    end

    results = Array.new(8) { connection.send_text('s' * (64 * 1024)) }

    expect(results).to include(false)
    expect(connection).not_to be_alive
    expect(connection.send_text('late')).to be(false)
    expect(retained).not_to be_empty
    Timeout.timeout(2) { sleep 0.005 until queue.empty? && retained.all?(&:empty?) }
    expect(retained).to all(be_empty)
  ensure
    connection&.close
    sender&.close
    receiver&.close
  end

  it 'still retires a peer that stops reading past the write deadline' do
    stub_const("#{described_class}::WRITE_TIMEOUT", 0.05)
    sender, receiver = stalled_pair
    fill_send_buffer(sender)
    connection = described_class.new(sender)

    expect(connection.send_text('x' * (1024 * 1024))).to be(true)
    Timeout.timeout(2) { sleep 0.005 while connection.alive? }
    expect(connection.send_text('late')).to be(false)
  ensure
    connection&.close
    sender&.close
    receiver&.close
  end

  it 'bounds outbound messages by the render budget, not the client message budget' do
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    connection = described_class.new(sender)
    limit = Lich::WebUI::Protocol::MAX_RENDER_BYTES
    expect(limit).to be > Lich::WebUI::Protocol::MAX_MESSAGE_BYTES

    reader = Thread.new { read_text(receiver, 5) }
    expect(connection.send_text('r' * limit)).to be(true)
    expect(reader.join(5)&.value&.bytesize).to eq(limit)
    expect { connection.send_text('r' * (limit + 1)) }.to raise_error(Lich::WebUI::Protocol::Refusal) { |error|
      expect(error.reason).to eq(:frame_size)
      expect(error.message).to include(limit.to_s, 'reduce page content')
    }
    expect(connection).to be_alive
  ensure
    reader&.kill&.join
    connection&.close
    sender&.close
    receiver&.close
  end
end
