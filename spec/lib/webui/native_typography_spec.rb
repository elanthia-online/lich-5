# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/validator'

RSpec.describe 'bounded native typography' do
  let(:validator) { Lich::WebUI::Validator.new }
  let(:context) { { owner: 'native', page_id: 'type', cid: 'text:example' } }
  let(:color) { { r: 224, g: 27, b: 36, a: 0.75 } }

  it 'uses the same bounded style for literal text and composite labels' do
    style = { font_size: 12.5, foreground: color, background: { r: 0, g: 0, b: 0, a: 0.5 } }
    text = '<span onclick="untrusted()">literal</span>'
    expect(validator.validate_component!(:text, { content: text, **style }, **context)).to include(content: text, **style)
    props = { width: 100, height: 30, layers: [{ kind: 'label', x: 0, y: 0, text: text, **style }] }
    expect(validator.validate_component!(:composite, props, **context)[:layers].first).to include(text: text, **style)
  end

  it 'rejects unbounded sizes, malformed colors, markup and CSS without clamping' do
    [5, 97, Float::INFINITY, '12px'].each do |size|
      expect { validator.validate_component!(:text, { content: 'x', font_size: size }, **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError)
    end
    ['red', { r: 256, g: 0, b: 0, a: 1 }, color.merge(a: -0.1), color.merge(url: 'example')].each do |value|
      expect { validator.validate_component!(:text, { content: 'x', foreground: value }, **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError)
    end
    %i[markup css font_desc].each do |property|
      expect { validator.validate_component!(:text, { content: 'x', property => 'arbitrary' }, **context) }
        .to raise_error(Lich::WebUI::UnknownPropertyError)
    end
  end

  it 'shares bounded fonts with entries while keeping text colors out and retaining the vocabulary' do
    expect(validator.validate_component!(:text_input, { value: '', font_size: 12 }, **context)).to include(font_size: 12)
    expect { validator.validate_component!(:text_input, { value: '', foreground: color }, **context) }
      .to raise_error(Lich::WebUI::UnknownPropertyError)
    expect(Lich::WebUI::Contract::TYPES.size).to eq(30)
  end
end
