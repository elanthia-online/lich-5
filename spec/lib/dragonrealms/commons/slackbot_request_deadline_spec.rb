# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'net/http'
require 'openssl'
require 'socket'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'slackbot.rb')

# Exercises SlackBot#request_before, the deadline-bounded transport of the
# send path, against real Net::HTTP connections to a loopback server. The
# server side checks whether the client socket was closed when the call
# returned or raised.
RSpec.describe Lich::DragonRealms::SlackBot, 'deadline-bounded request' do
  # request_before only reads the monotonic clock; no bot state is needed.
  let(:bot) { described_class.allocate }
  let(:server) { TCPServer.new('127.0.0.1', 0) }
  let(:port) { server.addr[1] }
  let(:accepted) { Queue.new }
  let(:req) do
    Net::HTTP::Post.new('/api/chat.postMessage').tap { |r| r.set_form_data('token' => 't', 'text' => 'hi') }
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def tls_http
    Net::HTTP.new('127.0.0.1', port).tap do |http|
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
  end

  def plain_http
    Net::HTTP.new('127.0.0.1', port)
  end

  # Accepts one connection and hands it to the example; the server never
  # writes unless +reply+ is given.
  def serve(reply: nil)
    @server_thread = Thread.new do
      conn = server.accept
      accepted << conn
      if reply
        conn.readpartial(65_536)
        conn.write(reply)
      end
    end
  end

  # True when the peer closed its end within +wait+ seconds. Bytes read on
  # the way are appended to +received+.
  def peer_closed?(conn, wait: 2, received: +'')
    stop = monotonic + wait
    loop do
      left = stop - monotonic
      return false if left <= 0
      return false unless conn.wait_readable(left)

      begin
        received << conn.read_nonblock(65_536)
      rescue EOFError, Errno::ECONNRESET
        return true
      rescue IO::WaitReadable
        next
      end
    end
  end

  def call(http, budget)
    bot.send(:request_before, http, req, monotonic + budget)
  end

  after do
    @server_thread&.kill
    server.close
  end

  it 'closes the socket when the deadline hits during the TLS handshake' do
    serve # accepts the TCP connection and never answers the ClientHello
    # A leaked socket is only closed by its finalizer; keep GC from hiding it.
    GC.disable
    started = monotonic

    expect { call(tls_http, 0.4) }.to raise_error(Timeout::Error)

    expect(monotonic - started).to be < 1.5
    expect(peer_closed?(accepted.pop)).to be true
  ensure
    GC.enable
  end

  it 'closes the socket when the deadline hits while waiting for the response' do
    serve
    http = plain_http
    started = monotonic

    expect { call(http, 0.4) }.to raise_error(Timeout::Error)

    expect(monotonic - started).to be < 1.5
    expect(http.started?).to be false
    expect(peer_closed?(accepted.pop)).to be true
  end

  it 'returns the response and closes the connection' do
    serve(reply: "HTTP/1.1 200 OK\r\nContent-Length: 11\r\nContent-Type: application/json\r\n\r\n{\"ok\":true}")
    http = plain_http

    res = call(http, 2)

    expect(res).to be_a(Net::HTTPOK)
    expect(res.body).to eq('{"ok":true}')
    expect(http.started?).to be false
    expect(peer_closed?(accepted.pop)).to be true
  end

  it 'bounds connecting and each read by the remaining budget' do
    serve(reply: "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}")
    http = plain_http

    call(http, 2)

    expect(http.open_timeout).to be_between(0.5, 1.0)
    expect(http.read_timeout).to be_between(1.0, 2.0)
    expect(http.write_timeout).to be_between(1.0, 2.0)
  end

  it 'does not connect when the budget is already spent' do
    expect { bot.send(:request_before, plain_http, req, monotonic - 0.1) }
      .to raise_error(described_class::NetworkError, /exhausted/)

    expect(IO.select([server], nil, nil, 0.2)).to be_nil
  end

  it 'does not send the request and closes the socket when connecting used up the budget' do
    serve
    http = plain_http
    deadline = monotonic + 2
    # The first check (before connecting) sees time left, the second (after
    # connecting) sees none.
    allow(bot).to receive(:seconds_left).with(deadline).and_return(2.0, -0.01)

    expect { bot.send(:request_before, http, req, deadline) }
      .to raise_error(described_class::NetworkError, /ran out while connecting/)

    received = +''
    expect(peer_closed?(accepted.pop, received: received)).to be true
    expect(received).to be_empty
    expect(http.started?).to be false
  end
end
