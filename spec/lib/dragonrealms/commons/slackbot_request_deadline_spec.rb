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

  context 'through a proxy' do
    let(:proxy) { TCPServer.new('127.0.0.1', 0) }
    let(:proxy_port) { proxy.addr[1] }
    let(:proxied) { Queue.new }

    # Accepts one connection on the proxy, reads the client's first request
    # (a CONNECT for TLS) and hands the socket to +behaviour+.
    def serve_proxy(&behaviour)
      @proxy_thread = Thread.new do
        conn = proxy.accept
        proxied << conn
        conn.readpartial(65_536)
        behaviour.call(conn)
      end
    end

    def proxied_http(use_ssl:)
      Net::HTTP.new('127.0.0.1', port, '127.0.0.1', proxy_port).tap { |http| http.use_ssl = use_ssl }
    end

    after do
      @proxy_thread&.kill
      proxy.close
    end

    # The real send path: post builds its connection with Net::HTTP.new(host,
    # port), which takes the proxy from http_proxy.
    it 'keeps a late CONNECT reply followed by a TLS hang within the budget of post' do
      allow(Lich).to receive(:log)
      saved = %w[http_proxy HTTP_PROXY no_proxy NO_PROXY].to_h { |k| [k, ENV.fetch(k, nil)] }
      saved.each_key { |k| ENV.delete(k) }
      ENV['http_proxy'] = "http://127.0.0.1:#{proxy_port}"
      budget = 1.5
      # Answers the CONNECT just before the budget runs out, then never
      # answers the ClientHello.
      serve_proxy do |conn|
        sleep budget - 0.05
        conn.write("HTTP/1.1 200 Connection established\r\n\r\n")
      end
      started = monotonic

      expect { bot.send(:post, 'auth.test', { 'token' => 't' }, deadline: monotonic + budget) }
        .to raise_error(described_class::NetworkError)

      expect(monotonic - started).to be < budget + 0.3
      expect(peer_closed?(proxied.pop, wait: 3)).to be true
    ensure
      saved&.each { |k, v| v.nil? ? ENV.delete(k) : ENV.store(k, v) }
    end

    it 'gives each connect step an equal share of the budget' do
      http = proxied_http(use_ssl: true)
      allow(http).to receive(:start).and_raise(Net::OpenTimeout)

      expect { call(http, 3) }.to raise_error(Net::OpenTimeout)

      expect(http.open_timeout).to be_between(0.9, 1.0)
      expect(http.read_timeout).to be_between(0.9, 1.0)
      expect(http.write_timeout).to be_between(0.9, 1.0)
    end

    it 'times out a CONNECT reply that is slower than its share' do
      serve_proxy { |_conn| sleep 10 }
      started = monotonic

      expect { call(proxied_http(use_ssl: true), 1.5) }.to raise_error(Net::ReadTimeout)

      expect(monotonic - started).to be < 1.0
      expect(peer_closed?(proxied.pop)).to be true
    end

    it 'gives the response the rest of the budget once connected' do
      # A plain-HTTP request through a proxy needs no CONNECT; the proxy
      # answers the request itself, later than the connect share.
      serve_proxy do |conn|
        sleep 0.8
        conn.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}")
      end
      http = proxied_http(use_ssl: false)

      res = call(http, 1.5)

      expect(res).to be_a(Net::HTTPOK)
      expect(http.started?).to be false
      expect(peer_closed?(proxied.pop)).to be true
    end
  end
end
