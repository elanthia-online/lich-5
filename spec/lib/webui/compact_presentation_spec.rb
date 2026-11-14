# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe 'bounded compact presentation' do
  let(:validator) { Lich::WebUI::Validator.new }
  let(:context) { { owner: 'presentation', page_id: 'test', cid: 'test' } }

  it 'carries a deterministic page theme and density without arbitrary CSS' do
    expect(validator.validate_component!(:page, { title: 'Spells', bare: true, theme: 'light', density: 'compact' }, **context))
      .to include(theme: 'light', density: 'compact', bare: true)
    expect { validator.validate_component!(:page, { title: 'x', theme: 'url(untrusted)' }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'carries a bounded progress color and height and rejects stylesheet input' do
    color = { r: 176, g: 224, b: 230, a: 1.0 }
    expect(validator.validate_component!(:progress, { value: 0.5, height: 24, fill_color: color }, **context))
      .to include(height: 24, fill_color: color)
    expect { validator.validate_component!(:progress, { fill_color: 'powderblue' }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError)
    expect { validator.validate_component!(:progress, { css: 'progress { color:red }' }, **context) }
      .to raise_error(Lich::WebUI::UnknownPropertyError)
  end

  it 'validates page measurements without accepting arbitrary state in the configure event' do
    payload = { width: 340, height: 144, position: [-10, 28] }
    expect(validator.validate_event!(:page, :configure, payload, props: {}, **context)).to eq(payload)
    expect { validator.validate_event!(:page, :configure, payload.merge(width: -1), props: {}, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError)
  end
end
