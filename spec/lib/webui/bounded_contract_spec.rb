# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/webui/validator'
require_relative '../../../lib/webui/tree_builder'

RSpec.describe 'bounded compatibility contract additions' do
  let(:validator) { Lich::WebUI::Validator.new }
  let(:context) { { owner: 'vars', page_id: 'setup', cid: 'name' } }

  it 'distinguishes an absent group label from an explicitly empty label' do
    expect(validator.validate_component!(:group, {}, **context)).not_to have_key(:label)
    expect(validator.validate_component!(:group, { label: '' }, **context)).to include(label: '')
  end

  it 'admits an ordered focus notification without a value or submission' do
    props = validator.validate_component!(:text_input, { value: '(new var name)' }, **context)
    expect(validator.validate_event!(:text_input, :focus, {}, props: props, **context)).to eq({})
    expect(Lich::WebUI::Contract.schema(:text_input)[:events][:focus][:lifecycle]).to be(true)
    expect do
      validator.validate_event!(:text_input, :focus, { value: 'not permitted' }, props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'bounds vertical scroll measurements and keeps requested position viewer-local' do
    props = validator.validate_component!(:scroll, { scroll_position: 120 }, **context)
    payload = { position: 120, upper: 800, page_size: 300 }
    expect(validator.validate_event!(:scroll, :scrolled, payload, props: props, **context)).to eq(payload)
    expect(Lich::WebUI::Contract.schema(:scroll)[:properties][:scroll_position][:scope]).to eq(:viewer)
    expect do
      validator.validate_event!(:scroll, :scrolled, payload.merge(upper: -1), props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError)
    expect do
      validator.validate_event!(:scroll, :scrolled, payload.merge(upper: 20), props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'bounds explicit resize requests without accepting arbitrary window operations' do
    request = { id: 'tick-1', size: [200, 551] }
    props = validator.validate_component!(:page, { title: 'CB', resize_request: request }, **context)
    expect(props[:resize_request]).to eq(request)
    [{ id: 'tick-1', size: [0, 551] }, { size: [200, 551] },
     request.merge(operation: 'arbitrary'), request.merge(size: [200, 551, 300])].each do |invalid|
      expect do
        validator.validate_component!(:page, { title: 'CB', resize_request: invalid }, **context)
      end.to raise_error(Lich::WebUI::SchemaViolationError)
    end
  end

  it 'bounds status-list presentation while preserving literal cell values' do
    table = { columns: [{ key: 'color', label: '', color_preview: { width: 30, height: 20 } }],
              rows: [{ key: 'a', cells: { color: 'not a color' } }],
              min_height: 300, row_height: 34, border_width: 0 }
    expect(validator.validate_component!(:table, table, **context)).to include(min_height: 300, row_height: 34)
    [{ row_height: 0 }, { border_width: 9 },
     { columns: [{ key: 'color', label: '', color_preview: { width: 129, height: 20 } }] },
     { columns: [{ key: 'color', label: '', color_preview: { width: 30, height: 20, css: 'x' } }] }].each do |invalid|
      expect { validator.validate_component!(:table, table.merge(invalid), **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError)
    end
  end

  it 'accepts an explicit table wrapping choice without changing the default' do
    table = { columns: [{ key: 'name', label: 'Name' }], rows: [] }
    expect(validator.validate_component!(:table, table, **context)).not_to have_key(:wrap)
    [true, false].each do |wrap|
      expect(validator.validate_component!(:table, table.merge(wrap: wrap), **context)[:wrap]).to eq(wrap)
    end
    expect { validator.validate_component!(:table, table.merge(wrap: 'nowrap'), **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'allows dismissal only through an existing dialog response' do
    dialog = { title: 'Editor', buttons: [{ id: 'cancel', label: 'Cancel' }], cancel_button: 'cancel', no_viewer: :wait, min_height: 200 }
    expect(validator.validate_component!(:dialog, dialog, **context)[:cancel_button]).to eq('cancel')
    expect { validator.validate_component!(:dialog, dialog.merge(cancel_button: 'missing'), **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'allows a dialog title to be accessible without an in-content heading' do
    dialog = { title: 'Add Status Effect', buttons: [{ id: 'cancel', label: 'Cancel' }],
               no_viewer: :wait, show_title: false }
    expect(validator.validate_component!(:dialog, dialog, **context)[:show_title]).to eq(false)
  end

  it 'carries long plain text in bounded fragments without altering its content' do
    builder = Lich::WebUI::TreeBuilder.new(owner: :fixture, page_id: 'long-text', title: 'Long text')
    content = "First line\n" + (0x03B1.chr(Encoding::UTF_8) * 9_000) + "\nLast line"
    builder.text(key: 'comments', content: content)
    node = builder.build.each.find { |component| component.props[:key] == 'comments' }
    expect(node.props[:content]).to eq('')
    expect(node.props[:fragments].join).to eq(content)
    expect(node.props[:fragments].map(&:length).max).to be <= Lich::WebUI::Contract::BOUNDS[:body_text]
  end

  it 'uses one literal fragmentation rule for bounded text and log lines' do
    content = "first\n" + (0x03B2.chr(Encoding::UTF_8) * 5_000)
    expect(Lich::WebUI::Contract.fragment_text('short', bound: :body_text)).to eq('short')
    parts = Lich::WebUI::Contract.fragment_text(content, bound: :log_line)
    expect(parts).to be_an(Array)
    expect(parts.join).to eq(content)
    expect(parts.map(&:length).max).to be <= Lich::WebUI::Contract::BOUNDS[:log_line]
  end

  it 'includes independent radio options while keeping sensitive input event vocabulary unchanged' do
    expect(Lich::WebUI::Contract::TYPES.length).to eq(30)
    expect(Lich::WebUI::Contract.schema(:password_input)[:events].keys).to eq([:submit])
  end
end
