# frozen_string_literal: true

require_relative '../../spec_helper'
require 'pp'
require 'webui/tree_builder'

RSpec.describe Lich::WebUI::TreeBuilder do
  subject(:builder) { described_class.new(owner: :fixture, page_id: 'spec-page', title: 'Spec') }

  let(:canary) { 'canary-draft-5c1e' }

  describe 'component identity' do
    it 'numbers unkeyed siblings by position and names keyed siblings by their key' do
      builder.text(content: 'first')
      builder.text_input(key: 'name', value: '')
      builder.text(content: 'second')

      expect(builder.build.children.map(&:cid)).to eq(
        %w[page:spec-page/text:0 page:spec-page/text_input:name page:spec-page/text:1]
      )
    end

    it 'keeps fixed identities when a keyed collection before them gains or loses members' do
      fixed_cids = [%w[a b c], %w[a c], []].map do |keys|
        fresh = described_class.new(owner: :fixture, page_id: 'spec-page', title: 'Spec')
        fresh.collection(keys) { |key| fresh.text_input(key: key, value: '') }
        fresh.text_input(value: '')
        fresh.text(content: 'after')
        fresh.build.children.map(&:cid).grep(%r{/(?:text_input:\d+|text:\d+)\z})
      end

      expect(fixed_cids.uniq).to eq([%w[page:spec-page/text_input:0 page:spec-page/text:1]])
    end

    it 'refuses duplicate identities and unkeyed members of a variable collection' do
      builder.text_input(key: 'name', value: '')
      expect { builder.text_input(key: 'name', value: '') }
        .to raise_error(Lich::WebUI::IdentityError, /duplicate component identity/)
      expect { builder.collection(%w[a]) { builder.text_input(value: '') } }
        .to raise_error(Lich::WebUI::IdentityError, /author key required/)
    end
  end

  describe 'long plain text' do
    it 'accepts the display bound and refuses one character beyond it' do
      builder.text(content: 'x' * 65_536)
      expect(builder.build.children.first.props[:fragments].sum(&:length)).to eq(65_536)

      over = described_class.new(owner: :fixture, page_id: 'spec-page', title: 'Spec')
      expect { over.text(content: 'x' * 65_537) }
        .to raise_error(Lich::WebUI::SchemaViolationError, /fragments exceed display text bound/)
    end
  end

  describe 'bindings' do
    it 'records callables by component and event, and refuses unknown events or non-callables' do
      action = proc {}
      button = builder.button(label: 'Go', on: { activate: action })

      expect(builder.bindings).to eq([button.cid, :activate] => action)
      expect { builder.button(label: 'Bad', on: { hover: action }) }.to raise_error(Lich::WebUI::UnknownEventError, /unknown event/)
      expect { builder.button(label: 'Bad', on: { activate: :not_callable }) }.to raise_error(ArgumentError, /must respond to call/)
      expect { builder.button(label: 'Bad', on: [:activate]) }.to raise_error(ArgumentError, /on must be a Hash/)
    end
  end

  describe 'submission scopes' do
    it 'snapshots named inputs for a terminal bound before or after they render' do
      early = builder.button(key: 'early', label: 'Early')
      name = builder.text_input(key: 'name', value: '')
      late = builder.button(key: 'late', label: 'Late', submit: [name])
      builder.submit(early, [name, 'page:spec-page/text_input:name'])

      expect(builder.submissions).to eq(
        early.cid => [name.cid, name.cid], late.cid => [name.cid]
      )
      expect(builder.build).to be_a(Lich::WebUI::Component)
    end

    it 'refuses scopes on non-terminals, foreign terminals and unknown or non-input targets' do
      label = builder.text(content: 'label')
      expect { builder.text(content: 'bad', submit: []) }
        .to raise_error(Lich::WebUI::SchemaViolationError, /requires a terminal component/)
      expect { builder.submit(Struct.new(:cid).new('page:other/button:0'), []) }
        .to raise_error(ArgumentError, /must belong to this builder/)

      action = builder.button(label: 'Go', submit: [label])
      expect { builder.build }.to raise_error(Lich::WebUI::SchemaViolationError, /unknown or non-input cid/)
      expect(builder.submissions.fetch(action.cid)).to eq([label.cid])
    end
  end

  describe 'selection groups' do
    it 'refuses a radio group with more than one selected option at build time' do
      builder.radio_option(label: 'One', group: 'pick', checked: true)
      builder.radio_option(label: 'Two', group: 'pick', checked: true)

      expect { builder.build }.to raise_error(Lich::WebUI::SchemaViolationError, /multiple selected options/)
    end
  end

  describe 'draft inspection' do
    it 'redacts a sensitive input value from the draft and from drafts that contain it' do
      secret = canary
      group = builder.group { text_input(key: 'token', value: secret, sensitive: true) }
      visible = builder.text_input(key: 'name', value: 'visible-name')

      [group.inspect, group.to_s, PP.pp(group, +''), visible.inspect].each { |text| expect(text).not_to include(canary) }
      expect(group.inspect).to include(Lich::WebUI::SensitiveValue::REDACTION)
      expect(visible.inspect).to include('visible-name')
      expect(group.children.first.props[:value]).to eq(canary)
    end
  end
  it 'G3 RC13 normalizes a single Draft in keyword and post-render submission scopes' do
    input = builder.text_input(key: 'name', value: '')
    action = builder.button(label: 'Go', submit: input)
    later = builder.button(label: 'Later')
    builder.submit(later, input)
    expect(builder.submissions).to eq(action.cid => [input.cid], later.cid => [input.cid])
    expect(builder.build).to be_a(Lich::WebUI::Component)
  end

  it 'G3 RC14 refuses column span overflow and admits a span ending at the last column' do
    builder.grid(cols: 3) { text(content: 'Fits', placement: { column: 2, span: 2 }) }
    expect(builder.build).to be_a(Lich::WebUI::Component)
    overflow = described_class.new(owner: :fixture, page_id: 'overflow', title: 'Overflow')
    overflow.grid(cols: 3) { overflow.text(content: 'Too wide', placement: { column: 3, span: 2 }) }
    expect { overflow.build }.to raise_error(Lich::WebUI::SchemaViolationError, /exceeds grid columns/)
  end

  it 'G3 RC30 separates numeric keys and reserved prefixes from fixed positional IDs' do
    numeric = builder.text_input(key: '0', value: '')
    fixed = builder.text_input(value: '')
    reserved = builder.text_input(key: 'key:0', value: '')
    nested = builder.text_input(key: 'key:key:0', value: '')
    ordinary = builder.text_input(key: 'name', value: '')
    expect([numeric.cid, fixed.cid, reserved.cid, nested.cid, ordinary.cid]).to eq(%w[
                                                                                     page:spec-page/text_input:key:0 page:spec-page/text_input:0 page:spec-page/text_input:key:key:0
                                                                                     page:spec-page/text_input:key:key:key:0 page:spec-page/text_input:name
                                                                                   ])
    expect(builder.build.children.map(&:cid).uniq.length).to eq(5)
  end
end
