# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/value_helpers'
require 'webui/contract'
require 'webui/viewer_store'

RSpec.describe Lich::WebUI::ValueHelpers do
  it 'isolates nested editable strings/containers while retaining keys and other leaves' do
    key, leaf = Object.new, Object.new
    text = +'initial'
    source = { key => [text, { nested: 'frozen' }, leaf] }
    copied = described_class.deep_copy(source)
    expect(copied).to eq(source)
    expect(copied).not_to equal(source)
    expect(copied.keys.first).to equal(key)
    expect(copied[key]).not_to equal(source[key])
    expect(copied[key][1]).not_to equal(source[key][1])
    expect(copied[key][2]).to equal(leaf)
    copied[key][0] << ' edited'
    copied[key][1][:nested] << ' edited'
    expect(text).to eq('initial')
    expect(source[key][1][:nested]).to eq('frozen')
  end

  it 'keeps the Contract container-copy policy distinct from editable value copies' do
    text = +'schema leaf'
    source = { nested: [text] }
    copied = Lich::WebUI::Contract.deep_dup(source)
    expect(copied).not_to equal(source)
    expect(copied[:nested]).not_to equal(source[:nested])
    expect(copied[:nested].first).to equal(text)
    expect(described_class.deep_copy(source)[:nested].first).not_to equal(text)
    expect(text).not_to be_frozen
  end

  it 'classifies password values and explicit true sensitivity without accepting other truthy values' do
    [[:password_input, false, true], [:password_input, nil, true], [:text_input, true, true],
     [:text_input, false, false], [:textarea, 'true', false], [:text_input, 1, false]].each do |type, sensitive, expected|
      component = Struct.new(:type, :props).new(type, { sensitive: sensitive })
      expect(described_class.sensitive_value?(component)).to eq(expected)
    end
  end

  it 'unwraps viewer contexts while preserving identity, nil and false without string coercion' do
    [nil, false, 0, 'viewer', Object.new].each do |id|
      expect(described_class.viewer_id(id)).to equal(id)
      expect(described_class.viewer_id(Struct.new(:viewer_id).new(id))).to equal(id)
    end
  end

  it 'normalizes CRLF and bare CR without changing the authoritative string' do
    text = +"one\r\ntwo\rthree\nfour"
    expect(described_class.normalize_text_line_breaks(text)).to eq("one\ntwo\nthree\nfour")
    expect(text).to eq("one\r\ntwo\rthree\nfour")
    expect { described_class.normalize_text_line_breaks(nil) }.to raise_error(NoMethodError)
  end

  it 'leaves the viewer store nontext normalization guard intact' do
    store = Lich::WebUI::ViewerStore.allocate
    [nil, false, 17, Object.new].each do |value|
      expect(store.send(:normalize_text_line_breaks, value)).to equal(value)
    end
  end
end
