# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'tmpdir'
require 'webui'

# A browser renderer failure is reported once per page and interval to the
# diagnostic sink, bounded and sanitized, and is never answered with its text.
RSpec.describe 'WebUI client error report' do
  let(:protocol) { Lich::WebUI::Protocol }
  let(:owner) { Struct.new(:name).new('boon.lic') }
  let(:logs) { [] }
  let(:registry) { Lich::WebUI::Registry.new }
  let(:dispatcher) { Lich::WebUI::Dispatcher.new }
  let(:runtime) do
    Lich::WebUI::Runtime.new(registry: registry, dispatcher: dispatcher,
                             logger: ->(level, message) { logs << [level, message] })
  end
  let(:connection_class) do
    Class.new do
      attr_reader :viewer_id, :sent

      def initialize(viewer_id)
        @viewer_id = viewer_id
        @sent = []
      end

      def send_text(payload)
        @sent << JSON.parse(payload)
        true
      end

      def alive? = true
    end
  end
  let(:connection) { connection_class.new('connection-one') }
  let(:page) do
    registry.register(Lich::WebUI::Page.new(owner: owner, id: 'boons', title: 'Boons') { text(content: 'ready') })
  end

  after { dispatcher.shutdown }

  def attach(viewer, target)
    address = registry.address_for(target)
    runtime.handle(viewer, type: 'attach', page: address, version: Lich::WebUI::Contract::VERSION)
    address
  end

  def report(address, **fields)
    protocol.parse_client_message(JSON.generate({ type: 'client_error', page: address, generation: 3,
                                                  message: 'cell is undefined' }.merge(fields)))
  end

  def failure_lines
    logs.select { |_level, message| message.start_with?('WebUI client render failure') }
  end

  # Moves a page's report interval into the past so its next report is logged.
  def expire_window(target)
    windows = runtime.instance_variable_get(:@client_error_windows)
    logged_at, suppressed = windows[target]
    windows[target] = [logged_at - Lich::WebUI::Runtime::CLIENT_ERROR_LOG_INTERVAL - 1, suppressed]
  end

  describe 'protocol admission' do
    it 'accepts a bounded report with an optional stack' do
      expect(report('page-1')).to include(type: 'client_error', page: 'page-1', generation: 3, message: 'cell is undefined')
      expect(report('page-1', stack: 'at render (app.js:1:2)')[:stack]).to eq('at render (app.js:1:2)')
    end

    it 'refuses missing, mistyped, oversized and unknown fields like any other message' do
      limits = protocol::CLIENT_ERROR_LIMITS
      refused = lambda do |fields, reason|
        raw = JSON.generate({ type: 'client_error', page: 'page-1', generation: 3, message: 'm' }.merge(fields))
        expect { protocol.parse_client_message(raw) }.to raise_error(protocol::Refusal) { |error| expect(error.reason).to eq(reason) }
      end

      expect { protocol.parse_client_message(JSON.generate(type: 'client_error', page: 'page-1', generation: 3)) }
        .to raise_error(protocol::Refusal, /missing message/)
      refused.call({ message: 7 }, :malformed)
      refused.call({ message: '' }, :malformed)
      refused.call({ stack: ['frame'] }, :malformed)
      refused.call({ generation: 0 }, :malformed)
      refused.call({ page: 'not an address' }, :malformed)
      refused.call({ message: 'm' * (limits[:message_bytes] + 1) }, :frame_size)
      refused.call({ stack: 's' * (limits[:stack_bytes] + 1) }, :frame_size)
      refused.call({ payload: {} }, :routing_field)
      refused.call({ cid: 'root' }, :routing_field)
    end
  end

  describe 'runtime logging' do
    it 'logs one attributed line and sends nothing back to the page' do
      address = attach(connection, page)
      sent_before = connection.sent.size

      result = runtime.handle(connection, report(address, stack: "TypeError: cell is undefined\n    at renderTable (/assets/app.js:10:5)"))

      expect(result).to eq(:logged)
      expect(connection.sent.size).to eq(sent_before)
      expect(failure_lines).to eq(
        [[:error, 'WebUI client render failure owner=boon.lic page=boons generation=3 ' \
                  'message="cell is undefined" stack="TypeError: cell is undefined at renderTable (/assets/app.js:10:5)"']]
      )
    end

    it 'keeps control bytes, non-ASCII text and long hexadecimal runs out of the single log line' do
      address = attach(connection, page)
      credential = 'ab' * 32
      accented = 233.chr(Encoding::UTF_8)

      runtime.handle(connection, report(address, message: "bad\r\nINJECTED line #{accented} token=#{credential}\e[31m"))

      line = failure_lines.last.last
      expect(line).to match(/\A[\x20-\x7E]+\z/)
      expect(line).not_to include(credential)
      expect(line).to include('message="bad INJECTED line ? token=[redacted]')
      expect(line).not_to include('stack=')
    end

    it 'logs one line per page and interval, then reports the suppressed count' do
      address = attach(connection, page)

      5.times { |index| expect(runtime.handle(connection, report(address, generation: index + 1))).to eq(index.zero? ? :logged : :suppressed) }
      expect(failure_lines.size).to eq(1)

      expire_window(page)
      runtime.handle(connection, report(address, generation: 9))
      expect(failure_lines.size).to eq(2)
      expect(failure_lines.last.last).to end_with('message="cell is undefined" suppressed=4')
    end

    it 'throttles each page separately' do
      other = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'other', title: 'Other') { text(content: 'ready') })
      first, second = attach(connection, page), attach(connection, other)

      2.times { runtime.handle(connection, report(first)) }
      runtime.handle(connection, report(second))

      expect(failure_lines.map(&:last)).to contain_exactly(a_string_including('page=boons'), a_string_including('page=other'))
    end

    it 'refuses a report from a viewer that is not attached to the page, without logging its text' do
      address = attach(connection, page)
      stranger = connection_class.new('connection-two')

      expect(runtime.handle(stranger, report(address, message: 'forged-canary'))).to eq(:refused)

      expect(failure_lines).to be_empty
      expect(logs.flatten.join).not_to include('forged-canary')
      expect(stranger.sent).to eq([{ 'type' => 'refusal', 'reason' => 'viewer_gone', 'message' => 'Message refused',
                                     'page' => address, 'cid' => nil, 'event' => nil, 'request' => nil }])
    end
  end

  it 'reaches the runtime through the server dispatch path without a reply' do
    Dir.mktmpdir('webui-assets') do |assets_dir|
      address = attach(connection, page)
      server = Lich::WebUI::Server.new(assets_dir: assets_dir, pages_provider: -> { [] },
                                       message_handler: ->(viewer, message) { runtime.handle(viewer, message) })
      sent_before = connection.sent.size

      server.send(:dispatch_message, connection,
                  JSON.generate(type: 'client_error', page: address, generation: 2, message: 'renderer failure'))

      expect(connection.sent.size).to eq(sent_before)
      expect(failure_lines.map(&:last)).to eq(['WebUI client render failure owner=boon.lic page=boons generation=2 message="renderer failure"'])
    end
  end
end
