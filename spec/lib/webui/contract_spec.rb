# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/contract'

RSpec.describe Lich::WebUI::Contract do
  it 'declares exactly the locked 31-type vocabulary' do
    expect(described_class::TYPES).to eq(%i[
                                           page group stack columns grid tabs expander split overlay scroll divider
                                           text markdown log progress image
                                           button toggle checkbox radio text_input password_input textarea number_input slider select
                                           table dialog composite
                                           menu menu_item
                                         ])
    expect(described_class.schemas.keys).to contain_exactly(*described_class::TYPES)
  end

  it 'returns deeply frozen machine-readable schemas' do
    schema = described_class.schema(:table)

    expect(schema).to be_frozen
    expect(schema[:properties]).to be_frozen
    expect(schema[:properties][:columns]).to be_frozen
    expect { schema[:properties][:extra] = {} }.to raise_error(FrozenError)
  end

  it 'declares password values sensitive and submit-only' do
    schema = described_class.schema(:password_input)

    expect(schema[:sensitive]).to be true
    expect(schema[:value_scope]).to eq(:sensitive_write_only)
    expect(schema[:events].keys).to eq([:submit])
    expect(schema[:properties][:sensitive]).to include(default: true, forced: true)
  end

  it 'keeps composite dimensions required after generic attributes are merged' do
    properties = described_class.schema(:composite).fetch(:properties)

    expect(properties.fetch(:width)).to include(required: true)
    expect(properties.fetch(:height)).to include(required: true)
  end

  it 'negotiates compatible versions and refuses unsupported majors' do
    expect(described_class.negotiate!('2.99.0')).to eq('2.13.0')
    expect { described_class.negotiate!('3.0.0') }
      .to raise_error(Lich::WebUI::VersionError, /unsupported contract major 3/)
    expect { described_class.negotiate!('invalid') }
      .to raise_error(Lich::WebUI::VersionError, /invalid contract version/)
  end

  it 'raises for an unknown component type' do
    expect { described_class.schema(:tree) }
      .to raise_error(Lich::WebUI::UnknownTypeError, /unknown component type :tree/)
  end
end
