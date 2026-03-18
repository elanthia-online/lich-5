# frozen_string_literal: true

require 'stringio'

require_relative '../../../spec_helper'
require_relative '../../../../lib/internal_api/active_sessions/registry'
require_relative '../../../../lib/internal_api/active_sessions/server'
require_relative '../../../../lib/internal_api/active_sessions/client'

RSpec.describe 'ActiveSessions server/client' do
  let(:registry) { instance_double(Lich::InternalAPI::ActiveSessions::Registry) }
  let(:listener) do
    instance_double(
      TCPServer,
      addr: ['AF_INET', 41_234, '127.0.0.1', '127.0.0.1'],
      setsockopt: 0,
      close: nil
    )
  end
  let(:accept_thread) { instance_double(Thread, alive?: true, kill: nil) }
  let(:client_thread) { instance_double(Thread, alive?: false) }
  let(:server) do
    Lich::InternalAPI::ActiveSessions::Server.new(
      host: '127.0.0.1',
      port: 0,
      registry: registry,
      server_factory: ->(_host, _port) { listener },
      accept_thread_factory: ->(&block) do
        @accept_loop = block
        accept_thread
      end,
      client_thread_factory: ->(socket, &block) do
        block.call(socket)
        client_thread
      end
    )
  end
  let(:socket) { instance_double(TCPSocket) }
  let(:client) do
    Lich::InternalAPI::ActiveSessions::Client.new(
      host: '127.0.0.1',
      port: 41_234,
      socket_factory: ->(_host, _port) { socket }
    )
  end

  it 'starts with injected transport dependencies and updates the bound port' do
    expect(server.start).to be(true)
    expect(server.port).to eq(41_234)
    expect(server).to be_running
  ensure
    server.stop
  end

  it 'encodes ping, upsert, snapshot, and remove requests over the JSON protocol' do
    allow(socket).to receive(:close)

    expect(socket).to receive(:write).with("{\"command\":\"ping\",\"payload\":{}}\n")
    allow(socket).to receive(:gets).and_return('{"ok":true,"payload":{"status":"ok"}}')
    expect(client.ping).to be(true)

    expect(socket).to receive(:write).with("{\"command\":\"upsert\",\"payload\":{\"pid\":444,\"session_name\":\"Tsetem\",\"role\":\"session\",\"started_at\":1700000000,\"connected\":true}}\n")
    allow(socket).to receive(:gets).and_return('{"ok":true,"payload":{"pid":444,"session_name":"Tsetem"}}')
    expect(client.upsert(pid: 444, session_name: 'Tsetem', role: 'session', started_at: 1_700_000_000, connected: true)[:ok]).to be(true)

    expect(socket).to receive(:write).with("{\"command\":\"snapshot\",\"payload\":{}}\n")
    allow(socket).to receive(:gets).and_return('{"ok":true,"payload":{"source":"ActiveSessionsAPI","total":1,"connected":1,"detachable":0,"sessions":[{"pid":444,"session_name":"Tsetem"}]}}')
    snapshot = client.snapshot
    expect(snapshot[:ok]).to be(true)
    expect(snapshot[:payload][:sessions].map { |session| session[:session_name] }).to include('Tsetem')

    expect(socket).to receive(:write).with("{\"command\":\"remove\",\"payload\":{\"pid\":444}}\n")
    allow(socket).to receive(:gets).and_return('{"ok":true,"payload":{"removed":true}}')
    expect(client.remove(444)[:ok]).to be(true)
  end

  it 'handles a single client request through the server protocol processor' do
    expect(registry).to receive(:snapshot).and_return(source: 'ActiveSessionsAPI', total: 0, connected: 0, detachable: 0, sessions: [])

    request_socket = StringIO.new("{\"command\":\"snapshot\"}\n")
    response_socket = StringIO.new
    allow(request_socket).to receive(:puts) { |payload| response_socket.write("#{payload}\n") }
    allow(request_socket).to receive(:close)

    server.send(:handle_client, request_socket)

    response_socket.rewind
    response = JSON.parse(response_socket.read, symbolize_names: true)
    expect(response[:ok]).to be(true)
    expect(response[:payload][:source]).to eq('ActiveSessionsAPI')
  end

  it 'dispatches upsert and remove requests to the registry' do
    expect(registry).to receive(:upsert).with(hash_including(pid: 444, session_name: 'Tsetem')).and_return(pid: 444)
    expect(server.send(:process_request, '{"command":"upsert","payload":{"pid":444,"session_name":"Tsetem"}}'))
      .to eq(ok: true, payload: { pid: 444 })

    expect(registry).to receive(:remove).with(444).and_return(true)
    expect(server.send(:process_request, '{"command":"remove","payload":{"pid":444}}'))
      .to eq(ok: true, payload: { removed: true })
  end
end
