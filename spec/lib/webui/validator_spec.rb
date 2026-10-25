# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/validator'

RSpec.describe Lich::WebUI::Validator do
  subject(:validator) { described_class.new }

  let(:context) { { owner: 'spec-owner', page_id: 'spec-page', cid: 'test:component' } }

  it 'bounds per-control alpha independently of whole-window presentation' do
    { stack: {}, button: { label: 'Action' }, text: { content: 'Item' } }.each do |type, base|
      expect(validator.validate_component!(type, base, **context)).not_to have_key(:opacity)
      [0, 0.35, 0.45, 1].each do |alpha|
        expect(validator.validate_component!(type, base.merge(opacity: alpha), **context)[:opacity]).to eq(alpha)
      end
      [-0.1, 1.1, Float::NAN, Float::INFINITY, '0.5'].each do |alpha|
        expect { validator.validate_component!(type, base.merge(opacity: alpha), **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
      end
    end
  end

  it 'accepts effective Markdown sensitivity without adding arbitrary destination or HTML fields' do
    expect(validator.validate_component!(:markdown, { content: '[Wiki](https://example.org)', disabled: true }, **context))
      .to include(disabled: true)
    expect { validator.validate_component!(:markdown, { content: '', disabled: 'true' }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { validator.validate_component!(:markdown, { content: '', href: 'javascript:bad' }, **context) }.to raise_error(Lich::WebUI::UnknownPropertyError)
  end

  it 'bounds internal select margins independently and admits literal stack tooltips' do
    props = validator.validate_component!(:select, { options: [], margin: 7, control_margin: { left: 12, top: 3 } }, **context)
    expect(props).to include(margin: 7, control_margin: { left: 12, top: 3 })
    %i[stack grid].each do |type|
      properties = type == :grid ? { cols: 1, tooltip: '<literal>' } : { tooltip: '<literal>' }
      expect(validator.validate_component!(type, properties, **context)[:tooltip]).to eq('<literal>')
    end
    [513, -1, { left: 513 }, { unknown: 1 }].each do |margin|
      expect { validator.validate_component!(:select, { options: [], control_margin: margin }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
    expect { validator.validate_component!(:text, { content: '', control_margin: 1 }, **context) }.to raise_error(Lich::WebUI::UnknownPropertyError)
  end

  it 'accepts an empty tab set but refuses selection until a page exists' do
    props = validator.validate_component!(:tabs, { names: [], selected: 0 }, **context)
    expect(props[:names]).to be_empty
    expect { validator.validate_component!(:tabs, { names: [], selected: 1 }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { validator.validate_event!(:tabs, :select, { index: 0 }, props: props, **context) }.to raise_error(Lich::WebUI::Error)
  end

  it 'allows bounded long plain text without widening input or option label limits' do
    content = 'x' * 65_536
    expect(validator.validate_component!(:text, { content: content }, **context)[:content]).to eq(content)
    expect { validator.validate_component!(:text, { content: content + 'x' }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError, /65536/)
    expect { validator.validate_component!(:text_input, { value: 'x' * 8193 }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError, /8192/)
    expect do
      validator.validate_component!(:select, { options: [{ value: 'one', label: 'x' * 513 }] }, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /512/)
  end

  it 'accepts literal and styled fragments while refusing untyped styles, oversized content and styled middle ellipsis' do
    parts = ['Plain ', { content: '<literal>', emphasis: :strong, font_style: :italic, underline: true, foreground: { r: 255, g: 0, b: 0, a: 1.0 }, scale: 0.9 }]
    props = validator.validate_component!(:text, { content: '', fragments: parts, ellipsize: :end }, **context)
    expect(props[:fragments].last).to include(content: '<literal>', emphasis: 'strong', font_style: 'italic', underline: true)
    [
      [{ content: 'x', style: 'color:red' }], [{ content: 'x', scale: 3 }], [{ content: 'x', underline: 'yes' }],
      [{ content: 'x' * 8193 }], Array.new(9) { { content: 'x' * 8192 } }
    ].each do |fragments|
      expect { validator.validate_component!(:text, { content: '', fragments: fragments }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
    expect { validator.validate_component!(:text, { content: '', fragments: parts, ellipsize: :middle }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError, /plain text/)
  end

  it 'bounds rectangle coordinates, drawing styles and opt-in clipping' do
    layer = { kind: :rectangle, mode: :fill, x: 0, y: 0, w: 17.5, h: 8, color: { r: 204, g: 0, b: 0, a: 1.0 } }
    base = { width: 120, height: 8, clip_layers: true, layers: [layer] }
    expect(validator.validate_component!(:composite, base, **context)[:layers][0][:w]).to eq(17.5)
    [{ w: -1 }, { x: Float::NAN }, { line_width: 17 }, { mode: :script }].each do |invalid|
      expect { validator.validate_component!(:composite, base.merge(layers: [layer.merge(invalid)]), **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError)
    end
    expect { validator.validate_component!(:composite, base.merge(clip_layers: 'true'), **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'bounds fragment typography independently from literal content' do
    fragment = { content: 'COMBATICAL', font_size: 22, font_unit: :pt, font_weight: 900, letter_spacing: 4 }
    expect(validator.validate_component!(:text, { content: '', fragments: [fragment] }, **context)[:fragments][0])
      .to include(font_size: 22, font_weight: 900, letter_spacing: 4)
    [{ font_size: 97 }, { font_size: 5 }, { font_unit: :em }, { font_family: 'url(evil)' },
     { font_weight: 1001 }, { font_weight: '900' }, { letter_spacing: 65 }, { letter_spacing: Float::INFINITY }].each do |invalid|
      expect { validator.validate_component!(:text, { content: '', fragments: [fragment.merge(invalid)] }, **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError)
    end
  end

  it 'accepts bounded plain-text line justification without changing placement or other controls' do
    %i[left center right].each do |justify|
      expect(validator.validate_component!(:text, { content: 'Caption', align: :start, line_justify: justify }, **context))
        .to include(align: 'start', line_justify: justify.to_s)
    end
    expect { validator.validate_component!(:text, { content: 'Caption', line_justify: :fill }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { validator.validate_component!(:markdown, { content: 'Caption', line_justify: :right }, **context) }.to raise_error(Lich::WebUI::UnknownPropertyError)
  end

  it 'requires the search column to belong to the table' do
    props = { columns: [{ key: 'text', label: 'Text' }], rows: [], search_column: 'missing' }
    expect { validator.validate_component!(:table, props, **context) }.to raise_error(Lich::WebUI::SchemaViolationError, /search column/)
    expect(validator.validate_component!(:table, props.merge(search_column: 'text'), **context)).to include(search_column: 'text')
  end

  it 'validates table identity references and refuses forged cursor, selection and disabled edits' do
    props = validator.validate_component!(:table, {
      columns: [{ key: 'flag', label: 'Flag', editor: { type: 'checkbox', disabled: true } }],
      rows: [{ key: 'one', cells: { flag: false } }, { key: 'two', cells: { flag: true } }],
      selection: :browse, expanded: ['one'], cursor: { row: 'one', column: 'flag' },
    }, **context)
    expect do
      validator.validate_event!(:table, :cursor_change, { row: 'one', column: 'missing' }, props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /column/)
    expect do
      validator.validate_event!(:table, :selection_change, { rows: %w[one two] }, props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /single selection/)
    expect do
      validator.validate_event!(:table, :cell_edit, { row: 'one', column: 'flag', value: true }, props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /disabled/)
    expect do
      validator.validate_property!(:table, :expanded, ['missing'], props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /expanded/)
    expect do
      validator.validate_property!(:table, :cursor, { column: 'flag' }, props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /cursor/)
  end

  it 'requires free-text encodings to be disjoint from option identities and clearing values to be declared' do
    props = { options: [{ value: 'row', label: 'Label' }], editable: true, free_text_prefix: 'text:' }
    expect(validator.validate_component!(:select, props.merge(value: 'text:row'), **context)[:value]).to eq('text:row')
    expect do
      validator.validate_component!(:select, props.merge(free_text_prefix: 'r'), **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /disjoint/)
    expect do
      validator.validate_component!(:select, props.merge(empty_value: 'missing'), **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /empty value/)
    expect do
      validator.validate_component!(:select, props.merge(editable: false), **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /editable/)
  end

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
    radio_option: { label: 'Choice', group: 'choice', checked: true },
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

  it 'refuses numeric presentations whose requested stepping behavior cannot run' do
    props = { value: 1, min: 0, max: 10 }
    expect { validator.validate_component!(:number_input, props.merge(acceleration: 1), **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /free numeric stepping/)
    expect { validator.validate_component!(:number_input, props.merge(snap_to_step: false), **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /requires stepper_buttons/)
    expect(validator.validate_component!(:number_input, props.merge(snap_to_step: false, stepper_buttons: true, digits: 2), **context))
      .to include(digits: 2)
  end

  it 'allows a fixed number input but rejects reversed bounds, other values and fixed sliders' do
    props = validator.validate_component!(:number_input, { value: 0, min: 0, max: 0, step: 1 }, **context)
    expect(validator.validate_event!(:number_input, :change, { value: 0 }, props: props, **context)).to eq(value: 0)
    expect { validator.validate_event!(:number_input, :change, { value: 1 }, props: props, **context) }.to raise_error(Lich::WebUI::Error)
    expect { validator.validate_component!(:number_input, { value: 0, min: 1, max: 0 }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { validator.validate_component!(:slider, { value: 0, min: 0, max: 0 }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'bounds page-local width group identifiers without admitting selectors or duplicates' do
    expect(validator.validate_component!(:checkbox, { label: 'Check', checked: false, width_groups: ['one', 'two'] }, **context))
      .to include(width_groups: %w[one two])
    [%w[one one], ['#selector'], Array.new(9) { |i| "group-#{i}" }].each do |groups|
      expect { validator.validate_component!(:text, { content: 'Text', width_groups: groups }, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
    expect { validator.validate_component!(:page, { title: 'Page', width_groups: ['one'] }, **context) }.to raise_error(Lich::WebUI::UnknownPropertyError)
  end

  it 'attributes unknown properties to owner, page, cid, and field' do
    expect { validator.validate_component!(:button, { label: 'Go', css: 'color:red' }, **context) }
      .to raise_error(Lich::WebUI::UnknownPropertyError, /owner=spec-owner page=spec-page cid=test:component field=css/)
  end

  it 'refuses raw colors and accepts structured RGBA in composite tint and bar tone' do
    expect { validator.validate_component!(:button, { label: 'Go', tone: '#ff0000' }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /must be one of/)

    composite = valid_properties[:composite].merge(layers: [
                                                     { kind: 'image', src: 'asset.png', x: 0, y: 0, tint: { r: 255, g: 0, b: 0, a: 0.5 } },
                                                     { kind: 'bar', x: 0, y: 0, w: 10, h: 2, value: 0.5, tone: { r: 0, g: 1, b: 2, a: 1.0 } },
                                                   ])
    expect { validator.validate_component!(:composite, composite, **context) }.not_to raise_error
  end

  it 'validates bounded RGBA table selection backgrounds without accepting raw CSS' do
    valid = { r: 51, g: 102, b: 153, a: 0.5 }
    props = valid_properties[:table].merge(selection_background: valid)
    expect { validator.validate_component!(:table, props, **context) }.not_to raise_error
    ['red', { r: 256, g: 0, b: 0, a: 1 }, { r: 0, g: 0, b: 0, a: -1 }, valid.merge(css: 'red')].each do |color|
      expect { validator.validate_component!(:table, props.merge(selection_background: color), **context) }
        .to raise_error(Lich::WebUI::Error)
    end
  end

  it 'validates tab header identity, color and pointer eligibility' do
    props = { names: ['Main'], headers: [{ key: 'main', foreground: { r: 255, g: 0, b: 0, a: 1 }, pointer_events: true }] }
    expect { validator.validate_component!(:tabs, props, **context) }.not_to raise_error
    [[], [{ key: 'a' }, { key: 'a' }], [{ key: 'main', foreground: 'red' }]].each do |headers|
      expect { validator.validate_component!(:tabs, props.merge(headers: headers), **context) }.to raise_error(Lich::WebUI::Error)
    end
  end

  it 'rejects stale tab identities and disabled custom tab gestures' do
    pointer = { tab: 'current', x: 1, y: 2, button: 3, time: 0, state: 0 }
    props = { names: ['Current'], headers: [{ key: 'current', pointer_events: true }] }
    expect { validator.validate_event!(:tabs, :tab_pointer, pointer, props: props, **context) }.not_to raise_error
    expect { validator.validate_event!(:tabs, :tab_pointer, pointer.merge(tab: 'removed'), props: props, **context) }.to raise_error(Lich::WebUI::Error)
    expect { validator.validate_event!(:tabs, :select, { index: 0, tab: 'removed' }, props: props, **context) }.to raise_error(Lich::WebUI::Error)
    expect { validator.validate_event!(:tabs, :select, { index: 0 }, props: props, **context) }.to raise_error(Lich::WebUI::Error)
    props[:headers][0][:disabled] = true
    expect { validator.validate_event!(:tabs, :tab_pointer, pointer, props: props, **context) }.to raise_error(Lich::WebUI::Error)
    expect { validator.validate_event!(:tabs, :select, { index: 0, tab: 'current' }, props: props, **context) }.to raise_error(Lich::WebUI::Error)
  end

  it 'enforces boundary values without clamping' do
    expect { validator.validate_component!(:stack, { gap: 64 }, **context) }.not_to raise_error
    expect { validator.validate_component!(:stack, { gap: 65 }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /must be <= 64/)
    expect { validator.validate_component!(:text, { content: 'x' * 65_537 }, **context) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /exceeds 65536/)
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

  it 'bounds table presentation and authorizes only displayed activatable header targets' do
    props = { columns: [{ key: 'name', label: 'Name', min_width: 120, activatable: true, tooltip: 'Literal help' }],
              rows: [{ key: 'one', cells: { name: '<literal>' },
                       cell_foregrounds: [{ column: 'name', color: { r: 255, g: 0, b: 0, a: 1.0 } }] }] }
    normalized = validator.validate_component!(:table, props, **context)
    expect(validator.validate_event!(:table, :column_activate, { column: 'name' }, props: normalized, **context)).to eq(column: 'name')
    ['missing', nil].each do |key|
      expect { validator.validate_event!(:table, :column_activate, { column: key }, props: normalized, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
    blocked = validator.validate_component!(:table, props.merge(columns: [{ key: 'name', label: 'Name' }]), **context)
    expect { validator.validate_event!(:table, :column_activate, { column: 'name' }, props: blocked, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    [-1, 65_537, 2.5].each do |width|
      expect { validator.validate_component!(:table, props.merge(columns: [{ key: 'name', label: 'Name', min_width: width }]), **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
    row = props[:rows].first
    [row[:cell_foregrounds] * 2, [{ column: 'missing', color: { r: 0, g: 0, b: 0, a: 1 } }],
     [{ column: 'name', color: 'red' }]].each do |colors|
      expect { validator.validate_component!(:table, props.merge(rows: [row.merge(cell_foregrounds: colors)]), **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
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
  end

  it 'requires dialog defaults only for the default absent-viewer policy' do
    expect do
      validator.validate_component!(
        :dialog, { title: 'Confirm', buttons: [{ id: 'ok', label: 'OK' }], no_viewer: 'default' },
        **context
      )
    end.to raise_error(Lich::WebUI::SchemaViolationError, /default_button is required/)
  end
  it 'accepts typed cell fills and refuses CSS or invalid background masks' do
    props = { columns: [{ key: 'name', label: 'Name', background: { r: 255, g: 255, b: 255, a: 1 } }],
              rows: [{ key: 'row', cells: { name: 'Literal' }, background_disabled: ['name'] }] }
    expect(validator.validate_component!(:table, props, **context)[:columns][0][:background][:r]).to eq(255)
    expect { validator.validate_component!(:table, props.merge(columns: [{ key: 'name', label: 'Name', background: 'white' }]), **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    [['missing'], ['name', 'name']].each do |mask|
      expect { validator.validate_component!(:table, props.merge(rows: [{ key: 'row', cells: { name: 'Literal' }, background_disabled: mask }]), **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
    expect(validator.validate_component!(:toggle, { checked: false, appearance: :switch }, **context)[:appearance]).to eq('switch')
  end

  it 'requires unique displayed sensitivity keys and refuses only their disabled cell edits' do
    base = { columns: [{ key: 'name', label: 'Name', expand: true, editor: { type: 'text' } }],
             rows: [{ key: 'one', cells: { name: 'Old' }, cell_disabled: ['name'] },
                    { key: 'two', cells: { name: 'Old' } }] }
    props = validator.validate_component!(:table, base, **context)
    expect do
      validator.validate_event!(:table, :cell_edit, { row: 'one', column: 'name', value: 'New' }, props: props, **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError, /disabled/)
    expect(validator.validate_event!(:table, :cell_edit, { row: 'two', column: 'name', value: 'New' }, props: props, **context))
      .to include(value: 'New')
    [%w[name name], ['missing']].each do |keys|
      invalid = base.merge(rows: [base[:rows][0].merge(cell_disabled: keys)])
      expect { validator.validate_component!(:table, invalid, **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
    end
    expect do
      validator.validate_component!(:table, base.merge(columns: [base[:columns][0].merge(expand: 1)]), **context)
    end.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'shares explicit text limits while preserving event and submission error attribution' do
    %i[text_input textarea].each do |type|
      props = validator.validate_component!(type, { value: '', max_length: 4 }, **context)
      expect(validator.validate_event!(type, :change, { value: 'four' }, props: props, **context)).to eq(value: 'four')
      expect(validator.validate_input_value!(type, 'four', props: props, **context)).to eq('four')
      expect { validator.validate_event!(type, :change, { value: 'fives' }, props: props, **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError, 'event value exceeds 4 characters (owner=spec-owner page=spec-page cid=test:component field=change)')
      expect { validator.validate_input_value!(type, 'fives', props: props, **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError, 'value exceeds 4 characters (owner=spec-owner page=spec-page cid=test:component field=value)')
    end
  end

  it 'retains read-only event refusal while allowing a bounded terminal value' do
    %i[text_input textarea].each do |type|
      props = validator.validate_component!(type, { value: 'kept', read_only: true, max_length: 4 }, **context)
      expect { validator.validate_event!(type, :change, { value: 'edit' }, props: props, **context) }
        .to raise_error(Lich::WebUI::SchemaViolationError, /text is read-only.*field=change/)
      expect(validator.validate_input_value!(type, 'kept', props: props, **context)).to eq('kept')
    end
  end
end
