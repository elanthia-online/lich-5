# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/protocol'

RSpec.describe Lich::WebUI::Protocol do
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
    expect { described_class.parse_client_message('x' * 65_537) }
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
