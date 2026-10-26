# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require_relative '../../../lib/webui/contract'
require_relative '../../../lib/webui/validator'
require_relative '../../../lib/webui/component'
require_relative '../../../lib/webui/sensitive_value'

RSpec.describe 'WebUI contract foundation' do
  let(:contract) { Lich::WebUI::Contract }

  it 'publishes exactly the supported component vocabulary' do
    expect(contract::VERSION).to eq('2.51.0')
    expect(contract::TYPES).to contain_exactly(
      :page, :group, :stack, :columns, :grid, :tabs, :expander, :split, :overlay, :scroll, :divider,
      :text, :markdown, :log, :progress, :image, :button, :toggle, :checkbox, :radio, :radio_option, :text_input,
      :password_input, :textarea, :number_input, :slider, :select, :table, :dialog, :composite
    )
    expect(contract.schemas.size).to eq(30)
  end

  it 'bounds literal tooltips on tabs and scroll, including empty clearing values' do
    validator = Lich::WebUI::Validator.new
    context = { owner: 'tooltips', page_id: 'page', cid: 'container' }
    { tabs: { names: ['One'] }, scroll: {} }.each do |type, props|
      ['', '<literal help>', 'x' * 8192].each do |text|
        expect(validator.validate_component!(type, props.merge(tooltip: text), **context)).to include(tooltip: text)
      end
      [nil, true, 42, {}, 'x' * 8193].each do |value|
        expect { validator.validate_component!(type, props.merge(tooltip: value), **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
      end
    end
  end

  it 'keeps renderer lifecycle exemptions aligned with every contract event' do
    renderer = File.read(File.expand_path('../../../lib/webui/assets/app.js', __dir__))
    names = JSON.parse(renderer.match(/const LIFECYCLE_EVENTS = new Set\((\[.*?\])\);/)[1])
    events = contract.schemas.values.flat_map { |schema| schema[:events].to_a }
    lifecycle = events.select { |_name, definition| definition[:lifecycle] }.map { |name, _| name.to_s }.uniq
    expect(names).to match_array(lifecycle)
    expect(events.reject { |_name, definition| definition[:lifecycle] }.map { |name, _| name.to_s } & names).to be_empty
  end

  it 'provides a browser renderer for every advertised component type' do
    assets = File.join(LIB_DIR, 'webui/assets')
    names = File.read(File.join(assets, 'index.html')).scan(%r{<script src="/assets/([a-z_]+\.js)" defer></script>}).flatten
    source = names.map { |name| File.read(File.join(assets, name)) }.join("\n")
    contract::TYPES.each { |type| expect(source).to match(/      #{type}\(_?page, component\)/), "missing renderer: #{type}" }
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

  it 'keeps the independently shipped client version aligned with the host contract' do
    source = File.read(File.join(LIB_DIR, 'webui/assets/app.js'))
    expect(source.match(/const VERSION = "([^"]+)";/)[1]).to eq(contract::VERSION)
  end

  it 'keeps browser input-scope terminals aligned while excluding close and drag payloads' do
    source = File.read(File.join(LIB_DIR, 'webui/assets/app.js'))
    names = JSON.parse(source.match(/const TERMINAL_EVENTS = new Set\((\[.*?\])\);/)[1])
    events = contract.schemas.values.flat_map { |schema| schema[:events].to_a }
    terminals = events.select { |_name, definition| definition[:terminal] }.map { |name, _| name.to_s }.uniq
    expect(terminals).to include('close', 'row_drop', 'widget_drop')
    expect(names).to match_array(terminals - %w[close row_drop widget_drop])
  end

  it 'finds exact component IDs without coercing callers or changing depth-first identity' do
    leaf = Lich::WebUI::Component.new(type: :text, cid: 'leaf', props: {})
    branch = Lich::WebUI::Component.new(type: :stack, cid: 'branch', props: {}, children: [leaf])
    root = Lich::WebUI::Component.new(type: :page, cid: 'root', props: {}, children: [branch])
    expect(root.find('root')).to equal(root)
    expect(root.find('leaf')).to equal(leaf)
    expect(root.find(:leaf)).to be_nil
    expect(root.find('missing')).to be_nil
  end
end
