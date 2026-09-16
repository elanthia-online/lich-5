# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'webui/export'

RSpec.describe Lich::WebUI::Export do
  let(:payload) { JSON.parse(described_class.to_json_text) }

  it 'carries every contract type, so a generated client cannot silently miss one' do
    expect(payload['types']).to eq(Lich::WebUI::Contract::TYPES.map(&:to_s))
    expect(payload['schemas'].keys).to contain_exactly(*Lich::WebUI::Contract::TYPES.map(&:to_s))
  end

  it 'carries the negotiation handles a client compares against' do
    expect(payload['contract_version']).to eq(Lich::WebUI::Contract::VERSION)
    expect(payload['contract_major']).to eq(Lich::WebUI::Contract::MAJOR_VERSION)
  end

  it 'is pure JSON scalars -- no symbols, ranges or regexps survive' do
    offenders = []
    walk = lambda do |value, path|
      case value
      when Hash
        value.each do |key, child|
          offenders << path unless key.is_a?(String)
          walk.call(child, "#{path}/#{key}")
        end
      when Array
        value.each_with_index { |child, i| walk.call(child, "#{path}[#{i}]") }
      when String, Numeric, true, false, nil
        nil
      else
        offenders << "#{path} -> #{value.class}"
      end
    end
    walk.call(payload, '')
    expect(offenders).to be_empty
  end

  it 'preserves the structural children kinds a renderer must branch on' do
    # These are the shapes that a naive "children is a list" client gets
    # wrong: two of them are not lists at all.
    expect(payload['schemas']['divider']['children']).to eq('none')
    expect(payload['schemas']['group']['children']).to eq('many')
    expect(payload['schemas']['split']['children'])
      .to eq('kind' => 'named', 'slots' => %w[first second])
    expect(payload['schemas']['columns']['children'])
      .to eq('kind' => 'named_dynamic', 'count_property' => 'count')
    expect(payload['schemas']['tabs']['children'])
      .to eq('kind' => 'named_from_property', 'property' => 'names')
  end

  it 'keeps required flags and viewer scope, which the wire format depends on' do
    checked = payload['schemas']['checkbox']['properties']['checked']
    expect(checked['required']).to be(true)
    expect(checked['scope']).to eq('viewer')
  end

  it 'converts BOUNDS ranges to explicit min/max records' do
    expect(payload['bounds']['geometry']).to eq('min' => -65_536, 'max' => 65_536)
    expect(payload['bounds']['timeout']).to eq('min' => 1, 'max' => 86_400)
  end

  it 'round-trips through JSON unchanged' do
    expect(JSON.parse(JSON.generate(described_class.payload))).to eq(described_class.payload)
  end

  # The committed artifact is what OTHER repos generate from -- VellumFE
  # builds its Rust node types out of it. A contract change that does not
  # reach this file is exactly the silent drift the export exists to stop,
  # so staleness is a test failure, not a chore someone remembers.
  it 'has a committed contract.json matching the live contract' do
    path = File.expand_path('../../../lib/webui/contract.json', __dir__)
    expect(File).to exist(path),
                    'lib/webui/contract.json is missing - regenerate it (see below)'
    on_disk = File.read(path)
    expect(on_disk).to eq(described_class.to_json_text), <<~MSG
      lib/webui/contract.json is stale (contract #{Lich::WebUI::Contract::VERSION}).
      Regenerate and commit it with the contract change:
        ruby -Ilib -e 'require "webui/export"; Lich::WebUI::Export.write("lib/webui/contract.json")'
    MSG
  end
end
