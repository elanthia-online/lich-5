# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/validator'

RSpec.describe Lich::WebUI::Validator do
  subject(:validator) { described_class.new }

  let(:context) { { owner: 'spec-owner', page_id: 'spec-page', cid: 'test:component' } }

  valid_properties = {
    page: { title: 'Page' },
    group: { label: 'Group' },
    stack: {},
    columns: { count: 1 },
    grid: { cols: 1 },
    tabs: { names: ['First'] },
    expander: { label: 'More' },
    split: { orientation: 'horizontal' },
    overlay: {},
    scroll: {},
    divider: {},
    text: { content: 'Text' },
    markdown: { content: '**Text**' },
    log: { lines: ['line'], max_lines: 10 },
    progress: { indeterminate: true },
    image: { src: 'asset/image.png' },
    button: { label: 'Go' },
    toggle: { checked: false },
    checkbox: { label: 'Check', checked: false },
    radio: { label: 'Pick', group: 'g', options: [{ value: 'a', label: 'A' }] },
    text_input: { value: '' },
    password_input: {},
    textarea: { value: '' },
    number_input: { value: 1, min: 0, max: 2 },
    slider: { value: 1, min: 0, max: 2 },
    select: { options: [{ value: 'a', label: 'A' }], value: 'a' },
    table: {
      columns: [{ key: 'name', label: 'Name' }],
      rows: [{ key: 'one', cells: { name: 'One' } }],
    },
    dialog: {
      title: 'Confirm', buttons: [{ id: 'ok', label: 'OK' }], no_viewer: 'abort',
    },
    composite: {
      width: 100, height: 100,
      layers: [{ kind: 'region', key: 'area', x1: 0, y1: 0, x2: 10, y2: 10, activates: true }],
    },
  }.freeze

  valid_properties.each do |type, properties|
    it "accepts the minimal valid #{type} schema" do
      isolated_properties = Marshal.load(Marshal.dump(properties))
      expect(validator.validate_component!(type, isolated_properties, **context)).to be_a(Hash)
    end
  end

  it 'attributes unknown properties to owner, page, cid, and field' do
    expect { validator.validate_component!(:button, { label: 'Go', css: 'color:red' }, **context) }
      .to raise_error(Lich::WebUI::UnknownPropertyError, /owner=spec-owner page=spec-page cid=test:component field=css/)
  end

  it 'refuses raw colors and accepts structured RGBA only in composite tint and bar tone' do
    expect { validator.validate_component!(:button, { label: 'Go', tone: '#ff0000' }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /must be one of/)

    composite = valid_properties[:composite].merge(layers: [
                                                     { kind: 'image', src: 'asset.png', x: 0, y: 0, tint: { r: 255, g: 0, b: 0, a: 0.5 } },
                                                     { kind: 'bar', x: 0, y: 0, w: 10, h: 2, value: 0.5, tone: { r: 0, g: 1, b: 2, a: 1.0 } },
                                                   ])
    expect { validator.validate_component!(:composite, composite, **context) }.not_to raise_error
  end

  it 'accepts the Pango markup subset on text and refuses anything else', security_id: 'sec-escaping' do
    accepted = '<b>Town</b> <span color="#ff0000" size="12000" font_desc="Courier Bold 9">x</span> &amp; <tt>y</tt>'
    expect(validator.validate_component!(:text, { content: 'x', markup: accepted }, **context)[:markup]).to eq(accepted)

    {
      '<script>x</script>'                     => /tag script is not allowed/,
      '<b onclick="x">x</b>'                   => /only allowed on span/,
      '<span style="italic" href="x">x</span>' => /attribute href is not allowed/,
      '<span color="url(x)">x</span>'          => /color has an invalid value/,
      '<span font_desc="a; b">x</span>'        => /font_desc has an invalid value/,
      '<b>unclosed'                            => /not well-formed/,
    }.each do |markup, message|
      expect { validator.validate_component!(:text, { content: 'x', markup: markup }, **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError, message)
    end
  end

  it 'requires a label on every menu item but a separator, and a group only on radios' do
    expect { validator.validate_component!(:menu_item, { kind: 'separator' }, **context) }.not_to raise_error
    expect { validator.validate_component!(:menu_item, { kind: 'check' }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /missing required property label/)
    expect { validator.validate_component!(:menu_item, { kind: 'separator', label: 'x' }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /separator carries no label/)
    expect { validator.validate_component!(:menu_item, { kind: 'check', label: 'x', group: 'g' }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /group applies to radio items only/)
  end

  it 'enforces boundary values without clamping' do
    expect { validator.validate_component!(:stack, { gap: 64 }, **context) }.not_to raise_error
    expect { validator.validate_component!(:stack, { gap: 65 }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /must be <= 64/)
    expect { validator.validate_component!(:text, { content: 'x' * 8193 }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /exceeds 8192/)
  end

  it 'enforces option membership and uniqueness' do
    expect do
      validator.validate_component!(
        :select,
        { options: [{ value: 'a', label: 'A' }, { value: 'a', label: 'Again' }], value: 'b' },
        **context
      )
    end.to raise_error(Lich::WebUI::SchemaViolationError, /option values must be unique/)
  end

  it 'validates proposed input values against the rendered component constraints', security_id: 'sec-value-schema' do
    props = validator.validate_component!(
      :select, { options: [{ value: 'a', label: 'A' }], value: 'a' }, **context
    )
    expect do
      validator.validate_event!(:select, :change, { value: 'b' }, props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /not present in options/)

    number_props = validator.validate_component!(
      :number_input, { value: 1, min: 0, max: 2 }, **context
    )
    expect do
      validator.validate_event!(:number_input, :change, { value: 3 }, props: number_props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /within min and max/)
  end

  # 2.18 (D17): a password's `change` says only that the value changed. It is
  # the one change event with no payload, and the one sensitive control
  # allowed to emit change at all -- a text_input marked sensitive still may
  # not, because its change would carry the value.
  it 'accepts a payload-free change on a password, and nothing more', security_id: 'sec-sensitive-change' do
    props = validator.validate_component!(:password_input, {}, **context)

    expect(validator.validate_event!(:password_input, :change, {}, props: props, **context)).to eq({})
    expect(validator.validate_event!(:password_input, :change, nil, props: props, **context)).to eq({})
    expect { validator.validate_event!(:password_input, :change, { value: 'hunter2' }, props: props, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /accepts no payload/)

    sensitive = validator.validate_component!(:text_input, { value: '', sensitive: true }, **context)
    expect { validator.validate_event!(:text_input, :change, { value: 'x' }, props: sensitive, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /sensitive components cannot emit change/)
  end

  it 'refuses an event that is not registered for the component type', security_id: 'sec-event-type' do
    props = validator.validate_component!(:button, { label: 'Go' }, **context)

    expect { validator.validate_event!(:button, :change, {}, props: props, **context) }
      .to raise_error(Lich::WebUI::UnknownEventError, /unknown event/)
  end

  it 'enforces table hierarchy, selection, and editor event values' do
    props = {
      columns: [
        { key: 'mode', label: 'Mode', sortable: true, editor: {
          type: 'select', options: [{ value: 'on', label: 'On' }, { value: 'off', label: 'Off' }]
        } },
      ],
      rows: [{ key: 'parent', cells: { mode: 'on' } }, { key: 'child', parent: 'parent', cells: { mode: 'off' } }],
      selection: 'single', sortable: true,
    }
    validated = validator.validate_component!(:table, props, **context)

    expect do
      validator.validate_event!(
        :table, :cell_edit, { row: 'child', column: 'mode', value: 'invalid' },
        props: validated, **context
      )
    end.to raise_error(Lich::WebUI::SchemaViolationError, /not a select option/)

    cyclic = props.merge(rows: [
                           { key: 'a', parent: 'b', cells: { mode: 'on' } },
                           { key: 'b', parent: 'a', cells: { mode: 'off' } },
                         ])
    expect { validator.validate_component!(:table, cyclic, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /parent cycle/)
  end

  it 'refuses disabled composite events' do
    composite = Marshal.load(Marshal.dump(valid_properties[:composite]))
    props = validator.validate_component!(:composite, composite, **context)
    expect do
      validator.validate_event!(
        :composite, :surface_activate,
        { x: 1, y: 1, button: 'primary', modifiers: [] }, props: props, **context
      )
    end.to raise_error(Lich::WebUI::SchemaViolationError, /surface events are not enabled/)
    expect do
      validator.validate_event!(
        :composite, :surface_zoom,
        { direction: 'in', x: 1, y: 1, modifiers: ['ctrl'] }, props: props, **context
      )
    end.to raise_error(Lich::WebUI::SchemaViolationError, /surface events are not enabled/)
  end

  it 'accepts a surface_zoom with a direction and the pointer once surface events are on' do
    props = validator.validate_component!(:composite, { width: 10, height: 10, surface_events: true, layers: [] }, **context)
    expect do
      validator.validate_event!(
        :composite, :surface_zoom,
        { direction: 'out', x: 3, y: 4, modifiers: ['ctrl'], scroll_x: 0, scroll_y: 12 }, props: props, **context
      )
    end.not_to raise_error
    expect do
      validator.validate_event!(:composite, :surface_zoom, { direction: 'sideways', x: 3, y: 4, modifiers: [] }, props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'requires dialog defaults only for the default absent-viewer policy' do
    expect do
      validator.validate_component!(
        :dialog, { title: 'Confirm', buttons: [{ id: 'ok', label: 'OK' }], no_viewer: 'default' },
        **context
      )
    end.to raise_error(Lich::WebUI::SchemaViolationError, /default_button is required/)
  end
end
