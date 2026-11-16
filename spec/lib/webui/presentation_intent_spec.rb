# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/tree_builder'

RSpec.describe 'WebUI presentation intent' do
  let(:validator) { Lich::WebUI::Validator.new }
  let(:context) { { owner: 'intent', page_id: 'page', cid: 'arbitrary' } }
  let(:roles) do
    { tabs: %w[inset], group: %w[record form], button: %w[record_primary record_secondary record_favorite refresh],
      toggle: %w[settings], columns: %w[form_choices], text: %w[form_hint] }
  end
  let(:required) do
    { tabs: { names: ['One'] }, group: {}, button: { label: 'Literal' },
      toggle: { checked: false }, columns: { count: 1 }, text: { content: 'Literal' } }
  end

  it 'accepts only the independently declared role vocabulary for each component type' do
    roles.each do |type, allowed|
      schema = Lich::WebUI::Contract.schema(type)
      expect(schema[:properties].fetch(:presentation_role)[:shape][:values]).to eq(allowed)
      allowed.each do |role|
        expect(validator.validate_component!(type, required.fetch(type).merge(presentation_role: role), **context))
          .to include(presentation_role: role)
      end
    end
    expect(Lich::WebUI::Contract::PRESENTATION_ROLES).to be_frozen
    expect(Lich::WebUI::Contract::PRESENTATION_ROLES.values).to all(be_frozen)
  end

  it 'rejects unknown roles, role/type mismatches and untyped CSS or executable data' do
    roles.each do |type, allowed|
      invalid = (roles.values.flatten.uniq - allowed) + [nil, true, 12, [], {}, 'custom-class', '<script>', 'color: red', 'x' * 129]
      invalid.each do |role|
        expect { validator.validate_component!(type, required.fetch(type).merge(presentation_role: role), **context) }
          .to raise_error(Lich::WebUI::SchemaViolationError)
      end
    end
    expect { validator.validate_component!(:page, { title: 'Page', presentation_role: 'record' }, **context) }
      .to raise_error(Lich::WebUI::UnknownPropertyError)
  end

  it 'leaves omitted roles absent and preserves event and value authority' do
    required.each do |type, properties|
      expect(validator.validate_component!(type, properties, **context)).not_to have_key(:presentation_role)
    end
    button = Lich::WebUI::Contract.schema(:button)
    expect(button[:events].keys).to include(:activate)
    expect(button[:value]).to be_nil
    expect(Lich::WebUI::Contract.schema(:toggle)[:value]).to eq(Lich::WebUI::Contract::BOOL)
  end

  it 'authors literal segmented content with arbitrary identities and an unchanged terminal scope' do
    builder = Lich::WebUI::TreeBuilder.new(owner: Object.new, page_id: 'arbitrary', title: 'Intent')
    field = builder.text_input(key: 'name', value: 'Draft')
    action = builder.button(key: 'action', label: 'Unparsed  |  label', presentation_role: :record_primary,
                            a11y_label: 'Play literal', submit: [field], on: { activate: proc {} }) do
      text(key: 'content', slot: 'content', content: '', fragments: [{ content: '<literal>' }, { content: 'A  |  B' }, { content: 'Third' }])
    end
    tree = builder.build
    button = tree.each.find { |component| component.cid == action.cid }
    expect(button.props[:label]).to eq('Unparsed  |  label')
    expect(button.props[:a11y_label]).to eq('Play literal')
    expect(button.children.first.props[:fragments].map { |part| part[:content] }).to eq(['<literal>', 'A  |  B', 'Third'])
    expect(builder.submissions).to eq(action.cid => [field.cid])
    expect(builder.bindings.keys).to eq([[action.cid, :activate]])
  end
end
