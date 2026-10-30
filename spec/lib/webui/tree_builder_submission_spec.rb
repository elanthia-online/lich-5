# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe Lich::WebUI::TreeBuilder do
  it 'binds a terminal action to inputs rendered later without weakening input validation' do
    builder = described_class.new(owner: :fixture, page_id: 'form', title: 'Form')
    action = builder.button(key: 'load', label: 'Load')
    name = builder.text_input(key: 'name', value: '')
    builder.submit(action, [name])
    builder.build
    expect(builder.submissions.fetch(action.cid)).to eq([name.cid])
    label = builder.text(content: 'Label')
    expect { builder.submit(label, []) }.to raise_error(Lich::WebUI::SchemaViolationError, /terminal/)
    builder.submit(action, ['missing'])
    expect { builder.build }.to raise_error(Lich::WebUI::SchemaViolationError, /unknown or non-input/)
  end

  it 'rejects a terminal draft from another builder' do
    first = described_class.new(owner: :fixture, page_id: 'form', title: 'Form')
    second = described_class.new(owner: :fixture, page_id: 'form', title: 'Form')
    foreign = second.button(key: 'load', label: 'Load')
    first.button(key: 'load', label: 'Load')
    expect { first.submit(foreign, []) }.to raise_error(ArgumentError, /this builder/)
  end
end
