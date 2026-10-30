# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'
require 'rbconfig'
require 'webui/validator'

RSpec.describe 'WebUI table editor contract' do
  let(:validator) { Lich::WebUI::Validator.new }
  let(:context) { { owner: 'editor-owner', page_id: 'editor-page', cid: 'table' } }

  def table_with(editor)
    { columns: [{ key: 'value', label: 'Value', editor: editor }],
      rows: [{ key: 'row', cells: { value: 'Initial' } }] }
  end

  {
    text: [{ 'type' => 'text', 'max_length' => 3 }, { type: 'text', max_length: 3 }],
    number: [{ type: :number, min: 0, max: 10 }, { type: 'number', min: 0, max: 10, step: 1 }],
    checkbox: [{ type: :checkbox }, { type: 'checkbox', disabled: false }],
    select: [{ type: :select, options: [{ value: 'one', label: 'One' }] },
             { type: 'select', options: [{ value: 'one', label: 'One' }], option_labels: false }],
  }.each do |type, (input, expected)|
    it "normalizes #{type} declarations with the existing defaults and field order" do
      editor = validator.validate_component!(:table, table_with(input), **context)[:columns][0][:editor]
      expect(editor).to eq(expected)
      expect(editor.keys).to eq(expected.keys)
      expect(editor).to be_frozen
    end
  end

  it 'keeps omitted and explicit nil editors read-only' do
    [table_with(nil), table_with(nil).tap { |table| table[:columns][0].delete(:editor) }].each do |table|
      props = validator.validate_component!(:table, table, **context)
      expect(props[:columns][0][:editor]).to be_nil
      expect do
        validator.validate_event!(:table, :cell_edit, { row: 'row', column: 'value', value: 'New' }, props: props, **context)
      end.to raise_error(Lich::WebUI::SchemaViolationError, /column is read-only/)
    end
  end

  [
    [false, 'must be a Hash or nil', 'columns[0].editor'],
    [{}, 'has unknown editor type', 'columns[0].editor.type'],
    [{ type: :script }, 'has unknown editor type', 'columns[0].editor.type'],
    [{ type: :number, max: 10 }, 'missing required field min', 'columns[0].editor.min'],
    [{ type: :number, min: 0 }, 'missing required field max', 'columns[0].editor.max'],
    [{ type: :select }, 'missing required field options', 'columns[0].editor.options'],
    [{ type: :text, max_length: 8193 }, 'must be <= 8192', 'columns[0].editor.max_length'],
    [{ type: :checkbox, disabled: 'false' }, 'must be true or false', 'columns[0].editor.disabled'],
    [{ type: :text, extra: true }, 'contains unknown field extra', 'columns[0].editor.extra'],
    [{ type: :number, min: 1, max: 1 }, 'editor min must be less than max', 'columns[0].editor'],
    [{ type: :select, options: [{ value: 'one', label: 'A' }, { value: 'one', label: 'B' }] },
     'option values must be unique', 'columns[0].editor'],
  ].each do |editor, message, field|
    it "refuses #{editor.inspect} with the existing field attribution" do
      expect do
        validator.validate_component!(:table, table_with(editor), **context)
      end.to raise_error(Lich::WebUI::SchemaViolationError) { |error|
        expect(error.message).to include(message)
        expect([error.owner, error.page_id, error.cid, error.field]).to eq(['editor-owner', 'editor-page', 'table', field])
      }
    end
  end

  [
    [{ type: :text, max_length: 3 }, 'New', 'Long', 'edited text exceeds 3 characters'],
    [{ type: :number, min: 0, max: 10 }, 5, 11, 'edited number is out of range'],
    [{ type: :checkbox }, true, 'true', 'edited value must be boolean'],
    [{ type: :select, options: [{ value: 'one', label: 'One' }] }, 'one', 'other', 'edited value is not a select option'],
  ].each do |editor, accepted, rejected, message|
    it "checks #{editor[:type]} edit values against the current column declaration" do
      props = validator.validate_component!(:table, table_with(editor), **context)
      payload = { row: 'row', column: 'value', value: accepted }
      expect(validator.validate_event!(:table, :cell_edit, payload, props: props, **context)).to eq(payload)
      expect do
        validator.validate_event!(:table, :cell_edit, payload.merge(value: rejected), props: props, **context)
      end.to raise_error(Lich::WebUI::SchemaViolationError, /#{message}/)
    end
  end

  it 'copies authored editor data without freezing or retaining its mutable containers' do
    input = { type: :select, options: [{ value: +'one', label: +'One' }] }
    first = validator.validate_component!(:table, table_with(input), **context)[:columns][0][:editor]
    input[:options][0][:label].replace('Changed')
    input[:options] << { value: 'two', label: 'Two' }
    second = validator.validate_component!(:table, table_with(input), **context)[:columns][0][:editor]
    expect(first[:options]).to eq([{ value: 'one', label: 'One' }])
    expect(first[:options][0][:label]).to be_frozen
    expect(second[:options].map { |option| option[:label] }).to eq(%w[Changed Two])
  end

  %w[contract validator].each do |first|
    it "loads through #{first} first in a fresh process without duplicate declarations" do
      code = <<~RUBY_CODE
        require 'webui/#{first}'
        require 'webui/validator'
        require 'webui/contract'
        validator = Lich::WebUI::Validator.new
        props = validator.validate_component!(:table,
          { columns: [{ key: 'n', label: 'N', editor: { type: :number, min: 0, max: 1 } }], rows: [] },
          owner: 'boot', page_id: 'boot', cid: 'table')
        abort 'wrong default' unless props[:columns][0][:editor][:step] == 1
        abort 'not frozen' unless Lich::WebUI::Contract.schemas.frozen?
        puts 'ready'
      RUBY_CODE
      output, errors, status = Open3.capture3(RbConfig.ruby, '-w', '-I', LIB_DIR, '-e', code)
      expect(status.success?).to be(true), errors
      expect(errors).to be_empty
      expect(output).to eq("ready\n")
    end
  end
end
