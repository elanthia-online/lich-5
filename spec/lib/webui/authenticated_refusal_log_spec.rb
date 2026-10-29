# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'socket'
require 'tmpdir'
require 'webui/server'

# Authenticated message and WebSocket refusals and handler failures use the
# same once-per-interval log throttle as malformed requests, each kind on its
# own interval; handler failures are keyed by class and raise location.
RSpec.describe Lich::WebUI::Server do
  let(:logs) { [] }
  let(:server) do
    described_class.new(assets_dir: @assets_dir, pages_provider: -> { [] }, message_handler: proc {},
                        logger: ->(level, message) { logs << [level, message] })
  end
  let(:connection) { instance_double(Lich::WebUI::Server::Connection, send_text: true) }

  around do |example|
    Dir.mktmpdir('webui-assets') do |assets_dir|
      @assets_dir = assets_dir
      example.run
    end
  end

  # Moves one refusal kind's interval into the past so its next refusal reports.
  def expire_window(kind)
    windows = server.instance_variable_get(:@refusal_windows)
    logged_at, suppressed = windows.fetch(kind)
    windows[kind] = [logged_at - described_class::REFUSAL_LOG_INTERVAL - 1, suppressed]
  end

  # Runs the WebSocket loop over a peer that sends an unmasked frame.
  def refuse_websocket
    client, accepted = Socket.pair(:UNIX, :STREAM, 0)
    client.write(Lich::WebUI::WebSocket.encode_frame('{"secret":"payload"}'))
    peer = instance_double(Lich::WebUI::Server::Connection, socket: accepted, alive?: true, send_pong: true)
    server.send(:websocket_loop, peer)
  ensure
    client&.close
    accepted&.close
  end

  it 'logs one message refusal per interval, still answers each, and reports the suppressed count next' do
    4.times { server.send(:dispatch_message, connection, '{"secret": "payload"') }

    expect(connection).to have_received(:send_text).exactly(4).times
    expect(logs).to eq([[:warning, 'WebUI message refusal=malformed']])

    expire_window(:message)
    server.send(:dispatch_message, connection, JSON.generate(type: 'nope', secret: 'payload'))
    expect(logs.last).to eq([:warning, 'WebUI message refusal=malformed suppressed=3'])
    expect(logs.size).to eq(2)
    expect(logs.flatten.join).not_to include('secret', 'payload')
  end

  it 'logs one WebSocket refusal per interval and reports the suppressed count next' do
    3.times { refuse_websocket }
    expect(logs).to eq([[:warning, 'WebUI websocket refusal=Lich::WebUI::WebSocket::ProtocolError']])

    expire_window(:websocket)
    refuse_websocket
    expect(logs.last).to eq([:warning, 'WebUI websocket refusal=Lich::WebUI::WebSocket::ProtocolError suppressed=2'])
    expect(logs.flatten.join).not_to include('secret', 'payload')
  end

  it 'logs one handler failure per class and raise location per interval, never its message' do
    handler = lambda do |_connection, message|
      raise ArgumentError, 'secret payload' if message[:page] == 'a'

      raise ArgumentError, 'secret payload'
    end
    failing = described_class.new(assets_dir: @assets_dir, pages_provider: -> { [] }, message_handler: handler,
                                  logger: ->(level, message) { logs << [level, message] })
    detach = ->(page) { JSON.generate(type: 'detach', page: page, generation: 1) }

    3.times { failing.send(:dispatch_message, connection, detach.call('a')) }
    failing.send(:dispatch_message, connection, detach.call('b'))

    expect(connection).to have_received(:send_text).exactly(4).times
    expect(logs.size).to eq(2)
    expect(logs.map(&:first)).to eq(%i[warning warning])
    expect(logs.map(&:last)).to all(match(/\AWebUI handler refusal=ArgumentError at=authenticated_refusal_log_spec\.rb:\d+:/))
    expect(logs.map(&:last).uniq.size).to eq(2)

    windows = failing.instance_variable_get(:@refusal_windows)
    first_key = windows.keys.find { |key| logs.first.last.end_with?("at=#{key.last}") }
    logged_at, suppressed = windows.fetch(first_key)
    windows[first_key] = [logged_at - described_class::REFUSAL_LOG_INTERVAL - 1, suppressed]
    failing.send(:dispatch_message, connection, detach.call('a'))
    expect(logs.last).to eq([:warning, "#{logs.first.last} suppressed=2"])
    expect(logs.flatten.join).not_to include('secret', 'payload')
  end

  it 'throttles each refusal kind independently' do
    server.send(:log_request_refusal, Lich::WebUI::Error.new('malformed request line'))
    server.send(:dispatch_message, connection, 'not json')
    refuse_websocket
    server.send(:dispatch_message, connection, 'not json')

    expected = [
      [:warning, 'WebUI request refused=Lich::WebUI::Error'],
      [:warning, 'WebUI message refusal=malformed'],
      [:warning, 'WebUI websocket refusal=Lich::WebUI::WebSocket::ProtocolError'],
    ]
    expect(logs).to eq(expected)
  end
end
