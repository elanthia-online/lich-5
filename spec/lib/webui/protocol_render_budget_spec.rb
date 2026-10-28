# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/protocol'

RSpec.describe Lich::WebUI::Protocol do
  it 'accepts a render at the byte budget and refuses one byte beyond it with actionable attribution' do
    payload = { address: 'page', generation: 1, tree: { text: 'content' } }
    size = described_class.render(**payload).bytesize
    stub_const('Lich::WebUI::Protocol::MAX_RENDER_BYTES', size)
    expect(JSON.parse(described_class.render(**payload))['tree']).to eq('text' => 'content')
    expect { described_class.render(**payload.merge(tree: { text: 'content!' })) }
      .to raise_error(described_class::Refusal) { |error|
        expect(error.reason).to eq(:frame_size)
        expect(error.page_id).to eq('page')
        expect(error.message).to include('reduce page content')
      }
  end

  it 'gives renders their own budget above the client message limit' do
    expect(described_class::MAX_RENDER_BYTES).to eq(4 * 1024 * 1024)
    expect(described_class::MAX_RENDER_BYTES).to be > described_class::MAX_MESSAGE_BYTES
  end

  it 'counts UTF-8 bytes and envelope facilities in the render budget' do
    payload = { address: 'page', generation: 1, tree: {}, facilities: { text: [0xE9].pack('U') * 20 } }
    message = described_class.render(**payload)
    stub_const('Lich::WebUI::Protocol::MAX_RENDER_BYTES', message.length)
    expect { described_class.render(**payload) }.to raise_error(described_class::Refusal)
  end
end
