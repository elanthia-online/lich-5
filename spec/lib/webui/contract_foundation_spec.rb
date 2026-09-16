# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/webui/contract'
require_relative '../../../lib/webui/component'
require_relative '../../../lib/webui/sensitive_value'

RSpec.describe 'WebUI contract foundation' do
  let(:contract) { Lich::WebUI::Contract }

  it 'publishes exactly the locked 2.15.2 vocabulary' do
    expect(contract::VERSION).to eq('2.15.2')
    expect(contract::TYPES).to contain_exactly(
      :page, :group, :stack, :columns, :grid, :tabs, :expander, :split, :overlay, :scroll, :divider,
      :text, :markdown, :log, :progress, :image, :button, :toggle, :checkbox, :radio, :text_input,
      :password_input, :textarea, :number_input, :slider, :select, :table, :dialog, :composite,
      :menu, :menu_item
    )
    expect(contract.schemas.size).to eq(31)
  end

  # 2.14: a page root has no per-cid binding channel -- its bindings go to the
  # lifecycle validator -- so a window's key press has to be a page lifecycle
  # event to be bound at all. Being lifecycle also makes it non-coalescable,
  # which is what keeps two different keys pressed in quick succession from
  # folding into one.
  it 'carries a page key event that is lifecycle but never terminal' do
    schema = contract.schema(:page)[:events].fetch(:key)

    expect(schema[:lifecycle]).to be(true)
    expect(schema[:terminal]).to be(false)
    expect(schema[:payload][:fields].keys).to contain_exactly(:keyval, :modifiers)
    expect(contract.schema(:page)[:properties]).to include(:key_events)
  end

  it 'refuses unknown types and unsupported major versions' do
    expect { contract.schema(:invented) }.to raise_error(Lich::WebUI::UnknownTypeError, /invented/)
    expect { contract.negotiate!('3.0.0') }.to raise_error(Lich::WebUI::VersionError, /unsupported contract major/)
  end

  it 'makes password values sensitive-write-only with no value-bearing change event' do
    schema = contract.schema(:password_input)

    expect(schema[:sensitive]).to be(true)
    expect(schema[:value_scope]).to eq(:sensitive_write_only)
    expect(schema[:events].keys).to eq([:submit])
    expect(schema[:properties].fetch(:sensitive)).to include(forced: true, default: true)
  end

  it 'removes a sensitive component value from serialized trees' do
    component = Lich::WebUI::Component.new(
      type: :password_input,
      cid: 'password_input:master',
      props: { label: 'Password', value: 'origin-a-canary', sensitive: true }
    )

    expect(component.to_h.to_s).not_to include('origin-a-canary')
  end

  describe Lich::WebUI::SensitiveValue do
    it 'redacts string, inspection, JSON, YAML-compatible, and Marshal representations' do
      canary = 'origin-b-7c96c297d33a4f36'
      value = described_class.server(canary)

      rendered = [value.to_s, value.inspect, value.to_json].join
      expect(rendered).to include(described_class::REDACTION)
      expect(rendered).not_to include(canary)
      expect(Marshal.dump(value)).to include(described_class::REDACTION)
      expect(Marshal.dump(value)).not_to include(canary)
      expect(value.origin).to eq(:server)
    end

    it 'provides plaintext once through an explicit consuming block and clears afterward' do
      value = described_class.viewer('viewer-secret')

      expect(value.consume { |plaintext| plaintext.reverse }).to eq('terces-reweiv')
      expect(value).to be_consumed
      expect { value.consume { nil } }.to raise_error(Lich::WebUI::ConsumedSensitiveValueError)
    end

    it 'fails fast on invalid value and origin input' do
      expect { described_class.new(nil, origin: :viewer) }.to raise_error(ArgumentError, /String/)
      expect { described_class.new('secret', origin: :unknown) }.to raise_error(ArgumentError, /origin/)
    end
  end
end
