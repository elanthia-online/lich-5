# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/protocol'
require 'webui/websocket'
require 'webui/validator'
require 'stringio'

RSpec.describe Lich::WebUI::Protocol do
  it 'round-trips maximum multiline fields through validation, JSON and masked frames' do
    validator = Lich::WebUI::Validator.new
    ['a', "\u{1f512}", "\u0000", "\n", '"', "\\"].each do |character| # rubocop:disable Custom/AsciiOnlySource -- Functional Unicode encoding fixture.
      value = character * Lich::WebUI::Contract::BOUNDS[:multiline_text]
      validator.validate_input_value!(:textarea, value, props: { value: '' }, owner: 'fixture', page_id: 'form', cid: 'notes')
      raw = JSON.generate(type: 'event', page: 'form', cid: 'notes', event: 'change', generation: 1, payload: { value: value })
      frame = Lich::WebUI::WebSocket.encode_client_frame(raw)
      decoded = Lich::WebUI::WebSocket.read_frame(StringIO.new(frame))
      expect(described_class.parse_client_message(decoded.payload)[:payload][:value]).to eq(value)
    end
  end

  it 'enforces aggregate and payload budgets independently of envelope size' do
    limits = Lich::WebUI::Contract::WIRE_LIMITS
    base = { type: 'event', page: 'form', cid: 'save', event: 'activate', generation: 1 }
    # Array brackets and string quotes account for the final four bytes.
    at_limit = ['a' * (limits[:submission_bytes] - 4)]
    expect(described_class.parse_client_message(JSON.generate(base.merge(submission: at_limit)))[:submission]).to eq(at_limit)
    expect { described_class.parse_client_message(JSON.generate(base.merge(submission: [at_limit.first + 'a']))) }
      .to raise_error(described_class::Refusal, /submission exceeds/)
    expect { described_class.parse_client_message(JSON.generate(base.merge(payload: { value: 'a' * limits[:event_payload_bytes] }))) }
      .to raise_error(described_class::Refusal, /payload exceeds/)
    greeting = JSON.parse(described_class.hello(viewer_id: 'test', pages: []))
    expect(greeting['limits']).to eq(limits.transform_keys(&:to_s))
    source = File.read(File.join(LIB_DIR, 'webui/assets/app.js'))
    limits.each { |name, value| expect(source).to include("#{name}: #{value}") }
  end

  it 'accepts a bounded request correlation number, never client routing authority' do
    event = { type: 'event', page: 'page-abc', cid: 'page:form/button:save', event: 'activate', generation: 1, request: 42 }
    expect(described_class.parse_client_message(JSON.generate(event))[:request]).to eq(42)
    expect { described_class.parse_client_message(JSON.generate(event.merge(request: -1))) }
      .to raise_error(Lich::WebUI::Protocol::Refusal)
    expect { described_class.parse_client_message(JSON.generate(event.merge(request: 'callback'))) }
      .to raise_error(Lich::WebUI::Protocol::Refusal)
  end
  it 'accepts only the strict attach and event shapes' do
    attach = described_class.parse_client_message(
      JSON.generate(type: 'attach', page: 'page-abc', version: '2.5.0')
    )
    event = described_class.parse_client_message(JSON.generate(
                                                   type: 'event', page: 'page-abc', cid: 'page:login/button:go',
                                                   event: 'activate', generation: 1, payload: {}, submission: ['typed value']
                                                 ))

    expect(attach).to eq(type: 'attach', page: 'page-abc', version: '2.5.0')
    expect(event[:submission]).to eq(['typed value'])
    expect(event).to be_frozen
  end

  %i[owner script callback method command path source submission_scope].each do |field|
    it "refuses the client routing field #{field}", security_id: 'sec-server-routing' do
      message = {
        type: 'event', page: 'page-abc', cid: 'page:login/button:go',
        event: 'activate', generation: 1, field => 'forged',
      }

      expect { described_class.parse_client_message(JSON.generate(message)) }
        .to raise_error(Lich::WebUI::Protocol::Refusal) { |error| expect(error.reason).to eq(:routing_field) }
    end
  end

  it 'refuses malformed, oversized, and unsupported-version messages atomically' do
    expect { described_class.parse_client_message('{') }
      .to raise_error(Lich::WebUI::Protocol::Refusal) { |error| expect(error.reason).to eq(:malformed) }
    expect { described_class.parse_client_message('x' * (described_class::MAX_MESSAGE_BYTES + 1)) }
      .to raise_error(Lich::WebUI::Protocol::Refusal) { |error| expect(error.reason).to eq(:frame_size) }
    expect do
      described_class.parse_client_message(JSON.generate(type: 'attach', page: 'page-abc', version: '3.0.0'))
    end.to raise_error(Lich::WebUI::Protocol::Refusal) { |error| expect(error.reason).to eq(:version) }
  end

  it 'compares bearer tokens without accepting missing or different-length values' do
    expect(described_class.secure_compare('a' * 64, 'a' * 64)).to be true
    expect(described_class.secure_compare('a' * 64, nil)).to be false
    expect(described_class.secure_compare('a' * 64, 'a' * 63)).to be false
  end

  it 'renders only server-derived binding and ordered submission metadata' do
    message = JSON.parse(described_class.render(
                           address: 'page-abc', generation: 2, tree: {},
                           bindings: { 'page:x/button:go' => ['activate'] },
                           submissions: { 'page:x/button:go' => ['page:x/password_input:secret'] }
                         ))

    expect(message['bindings']).to eq('page:x/button:go' => ['activate'])
    expect(message['submissions']).to eq('page:x/button:go' => ['page:x/password_input:secret'])
  end
end
