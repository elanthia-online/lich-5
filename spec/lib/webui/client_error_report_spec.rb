# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'tmpdir'
require 'webui'

# A browser renderer failure is reported once per page and interval to the
# diagnostic sink as an error class and script positions only, and is never
# answered.
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
                                                  error: 'TypeError' }.merge(fields)))
  end

  def failure_lines
    logs.select { |_level, message| message.start_with?('WebUI client render failure') }
  end

  def windows
    runtime.instance_variable_get(:@client_error_windows)
  end

  # Moves a page's report interval into the past so its next report is logged.
  def expire_window(target)
    logged_at, suppressed = windows.fetch(target)
    windows[target] = [logged_at - Lich::WebUI::Runtime::CLIENT_ERROR_LOG_INTERVAL - 1, suppressed]
  end

  describe 'protocol admission' do
    it 'accepts an error class with optional script positions' do
      expect(report('page-1')).to include(type: 'client_error', page: 'page-1', generation: 3, error: 'TypeError')
      expect(report('page-1', frames: ['app.js:10:5', 'renderers_table.js:1:2'])[:frames]).to eq(['app.js:10:5', 'renderers_table.js:1:2'])
      expect(report('page-1', frames: [])[:frames]).to eq([])
    end

    it 'refuses free text, misshapen positions, unsafe generations and unknown fields' do
      refused = lambda do |fields, reason|
        raw = JSON.generate({ type: 'client_error', page: 'page-1', generation: 3, error: 'Error' }.merge(fields))
        expect { protocol.parse_client_message(raw) }.to raise_error(protocol::Refusal) { |error| expect(error.reason).to eq(reason) }
      end

      expect { protocol.parse_client_message(JSON.generate(type: 'client_error', page: 'page-1', generation: 3)) }
        .to raise_error(protocol::Refusal, /missing error/)
      refused.call({ error: 7 }, :malformed)
      refused.call({ error: '' }, :malformed)
      refused.call({ error: 'cell is undefined' }, :malformed)
      refused.call({ error: "Type\nError" }, :malformed)
      refused.call({ error: 'E' * 65 }, :malformed)
      refused.call({ frames: 'app.js:1:2' }, :malformed)
      refused.call({ frames: [7] }, :malformed)
      refused.call({ frames: ['renderTable (app.js:1:2)'] }, :malformed)
      refused.call({ frames: ['http://127.0.0.1/assets/app.js:1:2'] }, :malformed)
      refused.call({ frames: ["app.js:1:2\nINJECTED"] }, :malformed)
      refused.call({ frames: ['app.js:12345678:1'] }, :malformed)
      refused.call({ frames: ['app.js:1:2'] * (protocol::CLIENT_ERROR_FRAMES + 1) }, :malformed)
      refused.call({ generation: 0 }, :malformed)
      refused.call({ generation: protocol::MAX_SAFE_INTEGER + 1 }, :malformed)
      refused.call({ page: 'not an address' }, :malformed)
      refused.call({ message: 'cell is undefined' }, :routing_field)
      refused.call({ stack: 'at render (app.js:1:2)' }, :routing_field)
      refused.call({ payload: {} }, :routing_field)
      refused.call({ cid: 'root' }, :routing_field)
    end

    it 'admits the frame the browser sends for an error whose text holds supplementary characters' do
      # Byte-for-byte the frame the renderer test asserts for a message and stack
      # that each place a supplementary character across a former cut point.
      wire = '{"type":"client_error","page":"main","generation":1,"error":"Error","frames":["app.js:10:5"]}'

      expect(wire).to match(/\A[\x20-\x7E]+\z/)
      expect(protocol.parse_client_message(wire)).to eq(type: 'client_error', page: 'main', generation: 1, error: 'Error',
                                                        frames: ['app.js:10:5'])
    end
  end

  describe 'runtime logging' do
    it 'logs one attributed line of structural fields and sends nothing back to the page' do
      address = attach(connection, page)
      sent_before = connection.sent.size

      result = runtime.handle(connection, report(address, frames: ['renderers_table.js:120:14', 'app.js:1391:24']))

      expect(result).to eq(:logged)
      expect(connection.sent.size).to eq(sent_before)
      expect(failure_lines).to eq(
        [[:error, 'WebUI client render failure owner=boon.lic page=boons generation=3 ' \
                  'error=TypeError at=renderers_table.js:120:14,app.js:1391:24']]
      )
    end

    it 'names only shipped renderer scripts in positions' do
      address = attach(connection, page)

      runtime.handle(connection, report(address, frames: ['app.js:1:2', 'canary_word.js:3:4']))

      expect(failure_lines.last.last).to end_with('error=TypeError at=app.js:1:2,other:3:4')
      expect(logs.flatten.join).not_to include('canary_word')
    end

    it 'keeps the whole line bounded, printable and single for a long or multi-line owner label' do
      owner.name = "boon\r\nINJECTED #{233.chr(Encoding::UTF_8)}\e[31m #{'W' * 2048}"
      address = attach(connection, page)

      runtime.handle(connection, report(address, generation: protocol::MAX_SAFE_INTEGER, error: 'E' * 64,
                                                 frames: ['renderers_table.js:1234567:1234567'] * protocol::CLIENT_ERROR_FRAMES))

      line = failure_lines.last.last
      expect(line).to match(/\A[\x20-\x7E]+\z/)
      expect(line).to start_with('WebUI client render failure owner=boon INJECTED ? [31m WWW')
      expect(line.bytesize).to be < 600
    end

    it 'logs one line per page and interval, then reports the suppressed count' do
      address = attach(connection, page)

      5.times { |index| expect(runtime.handle(connection, report(address, generation: index + 1))).to eq(index.zero? ? :logged : :suppressed) }
      expect(failure_lines.size).to eq(1)

      expire_window(page)
      runtime.handle(connection, report(address, generation: 9))
      expect(failure_lines.size).to eq(2)
      expect(failure_lines.last.last).to end_with('generation=9 error=TypeError suppressed=4')
    end

    it 'keeps a live page window and its suppressed count across garbage collection' do
      address = attach(connection, page)

      runtime.handle(connection, report(address))
      3.times do
        GC.start(full_mark: true, immediate_sweep: true)
        expect(runtime.handle(connection, report(address))).to eq(:suppressed)
      end
      GC.start(full_mark: true, immediate_sweep: true)
      expect(failure_lines.size).to eq(1)
      expect(windows.fetch(page).last).to eq(3)

      expire_window(page)
      GC.start(full_mark: true, immediate_sweep: true)
      runtime.handle(connection, report(address))
      expect(failure_lines.last.last).to end_with('error=TypeError suppressed=3')
    end

    it 'releases the window when its page closes or its owner terminates' do
      other_owner = Struct.new(:name).new('other.lic')
      other = registry.register(Lich::WebUI::Page.new(owner: other_owner, id: 'other', title: 'Other') { text(content: 'ready') })
      first, second = attach(connection, page), attach(connection, other)
      runtime.handle(connection, report(first))
      runtime.handle(connection, report(second))
      expect(windows.keys).to contain_exactly(page, other)

      runtime.close_page(page)
      expect(windows.keys).to contain_exactly(other)
      expect(runtime.handle(connection, report(first))).to eq(:refused)
      expect(windows.keys).to contain_exactly(other)

      runtime.terminate_owner(other_owner)
      expect(windows).to be_empty
    end

    it 'throttles each page separately' do
      other = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'other', title: 'Other') { text(content: 'ready') })
      first, second = attach(connection, page), attach(connection, other)

      2.times { runtime.handle(connection, report(first)) }
      runtime.handle(connection, report(second))

      expect(failure_lines.map(&:last)).to contain_exactly(a_string_including('page=boons'), a_string_including('page=other'))
    end

    it 'refuses a report from a viewer that is not attached to the page, without logging it' do
      address = attach(connection, page)
      stranger = connection_class.new('connection-two')

      expect(runtime.handle(stranger, report(address, error: 'ForgedCanary'))).to eq(:refused)

      expect(failure_lines).to be_empty
      expect(windows).to be_empty
      expect(logs.flatten.join).not_to include('ForgedCanary')
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
                  JSON.generate(type: 'client_error', page: address, generation: 2, error: 'RangeError', frames: ['app.js:7:9']))

      expect(connection.sent.size).to eq(sent_before)
      expect(failure_lines.map(&:last)).to eq(['WebUI client render failure owner=boon.lic page=boons generation=2 error=RangeError at=app.js:7:9'])
    end
  end
end
