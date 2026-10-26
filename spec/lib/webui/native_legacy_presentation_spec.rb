# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe 'native legacy presentation values' do
  let(:builder) { Lich::WebUI::TreeBuilder.new(owner: :fixture, page_id: 'form', title: 'Form') }

  it 'keeps committed entry changes as the default and permits explicit live changes' do
    builder.text_input(value: '1.0')
    builder.text_input(value: 'search', change_mode: :input)
    expect(builder.build.children.map { |child| child.props[:change_mode].to_s }).to eq(%w[commit input])
    expect { builder.text_input(value: '', change_mode: :keypress) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'preserves full multiline tooltips within the existing body-text bound' do
    builder.text_input(key: 'signs', value: '', tooltip: 'Instructions. ' * 80)
    expect { builder.build }.not_to raise_error
    expect { builder.text(content: 'Label', tooltip: 'x' * (Lich::WebUI::Contract::BOUNDS[:body_text] + 1)) }
      .to raise_error(Lich::WebUI::SchemaViolationError, /exceeds/)
  end

  it 'keeps numeric sort values separate from formatted table text' do
    builder.table(columns: [{ key: 'size', label: 'Size', resizable: true }],
                  rows: [{ key: 'first', cells: { 'size' => '1.9k' }, sort_cells: { 'size' => 1999 } }])
    expect(builder.build.children.first.props[:rows].first[:sort_cells]).to eq('size' => 1999)
  end

  it 'rejects a sort value for an undeclared column' do
    expect do
      builder.table(columns: [{ key: 'size', label: 'Size' }],
                    rows: [{ key: 'first', cells: { 'size' => '1.9k' }, sort_cells: { 'other' => 1 } }])
    end.to raise_error(Lich::WebUI::SchemaViolationError, /sort cell names unknown column/)
  end

  it 'accepts free text only for explicitly editable native choices' do
    options = [{ value: 'auto', label: 'auto' }]
    builder.select(options: options, value: 'legacy value', editable: true)
    validator = Lich::WebUI::Validator.new
    expect { builder.build }.not_to raise_error
    expect { builder.select(options: options, value: 'legacy value') }.to raise_error(Lich::WebUI::SchemaViolationError)
    context = { owner: :fixture, page_id: 'form', cid: 'choice' }
    expect { validator.validate_event!(:select, :change, { value: 'custom' }, props: { options: options, editable: true }, **context) }.not_to raise_error
  end
  it 'accepts bounded native panel styling and compact entry rows without GTK' do
    builder.group(label: '', padding: 2, border_color: { r: 255, g: 215, b: 0, a: 1.0 },
                  context_menu: 'menu', surface_events: true, on: { surface_activate: proc {} }) do
      text_input(value: '1.0', label: 'Scale:', inline: true, control_width: 65)
    end
    expect { builder.build }.not_to raise_error
    expect { builder.group(label: '', padding: 65) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { builder.text_input(value: '', control_width: 1025) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'supports content-sized native grid columns without changing the equal-width default' do
    builder.grid(cols: 3, homogeneous: false) { text(content: 'Label') }
    expect(builder.build.children.first.props[:homogeneous]).to eq(false)
  end

  it 'supports expanding spell lists beside top-aligned option frames' do
    builder.columns(count: 2, row_align: :stretch, fill: true) do
      stack(slot: '0') { table(columns: [{ key: 'name', label: '' }], rows: [], fill: true) }
      stack(slot: '1') { text(content: 'Options') }
    end
    expect { builder.build }.not_to raise_error
  end

  it 'accepts explicit native spin controls with their original step and bounds' do
    builder.number_input(value: 4, min: 4, max: 20, step: 1, stepper_buttons: true)
    expect { builder.build }.not_to raise_error
  end

  it 'carries the original panel border and centered pixel-sized bar text' do
    builder.group(label: '', border_width: 3, radius: 3, min_height: 181, content_align: :center) do
      composite(width: 90, height: 16, layers: [{ kind: :label, x: 0, y: 0, w: 90, h: 16,
        align: :center, text: 'HP: 75/100', font_size: 11, font_unit: :px }])
    end
    expect { builder.build }.not_to raise_error
  end

  it 'permits partially clipped image layers while retaining bounded coordinates' do
    builder.composite(width: 100, height: 180, layers: [{ kind: :image, src: '/fixture.png', x: -8, y: 12 }])
    expect { builder.build }.not_to raise_error
    expect { builder.composite(width: 100, height: 180, layers: [{ kind: :image, src: '/fixture.png', x: -65_537, y: 12 }]) }
      .to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'retains explicit native font families and logical pixel sizes as literal style values' do
    builder.text(content: 'Name', font_size: 12, font_unit: :px, font_family: 'Arial')
    expect { builder.build }.not_to raise_error
    expect { builder.text(content: '', font_family: 'x' * 129) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'separates requested minimum widths from fixed widths and expanding grid tracks' do
    builder.grid(cols: 3, homogeneous: false, expand_columns: [2]) do
      button(label: 'Add', min_width: 80, placement: { column: 1 })
      text_input(value: '', min_width: 168, placement: { column: 2 })
      button(label: 'Delete', min_width: 80, placement: { column: 3 })
    end
    expect { builder.build }.not_to raise_error
    expect { builder.grid(cols: 2, expand_columns: [3]) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { builder.text_input(value: '', min_width: -1) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'retains a character-based natural entry cap without a fixed pixel width' do
    builder.text_input(value: '', min_width: 168, max_width_chars: 35)
    expect { builder.build }.not_to raise_error
    expect { builder.text_input(value: '', max_width_chars: 0) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'keeps a status label on one line and permits the original middle-ellipsized name cap' do
    builder.stack(orientation: :horizontal, gap: 0) do
      13.times { text(content: ' S', wrap: false) }
    end
    builder.text(content: 'a long creature name', wrap: false, max_width_chars: 15, ellipsize: :middle)
    expect { builder.build }.not_to raise_error
    expect { builder.stack(orientation: :diagonal) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { builder.text(content: '', ellipsize: :arbitrary) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'supports an initial pixel divider with only its first pane consuming resize growth' do
    builder.split(orientation: :horizontal, position_pixels: 700, resize_side: :first, fill: true)
    expect { builder.build }.not_to raise_error
    expect { builder.split(orientation: :horizontal, position_pixels: -1) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'accepts bounded literal fragments without relaxing individual string limits' do
    builder.text(content: '', fragments: ['x' * 8192, 'tail'])
    builder.log(lines: [['x' * 4096, 'tail']], max_lines: 10)
    expect { builder.build }.not_to raise_error
    expect { builder.text(content: '', fragments: ['x' * 8193]) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { builder.log(lines: [['x' * 4097]], max_lines: 10) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'retains character-sized controls and the natural size of every notebook page' do
    builder.text_input(value: '1.0', inline: true, control_width_chars: 5)
    builder.tabs(names: ['First', 'Second'], size_to_all: true)
    builder.text(content: 'Instructions', font_style: :italic)
    expect { builder.build }.not_to raise_error
    expect { builder.text_input(value: '', control_width_chars: 0) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'retains source character minima and editable combo entry widths' do
    builder.text(content: 'Entire Group', min_width_chars: 17)
    builder.text_input(value: '', min_width_chars: 20, min_width: 300)
    builder.select(options: [], editable: true, control_width_chars: 12)
    expect { builder.build }.not_to raise_error
    expect { builder.text(content: '', min_width_chars: 0) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { builder.text_input(value: '', min_width_chars: 1025) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { builder.select(options: [], editable: true, control_width_chars: 0) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'requires positioned overlays for coordinates and a target for focus revisions' do
    builder.overlay(positioned: true) { text(content: 'Positioned', placement: { x: -5, y: 60 }) }
    input = builder.text_input(value: '')
    builder.focus(input.cid)
    builder.focus_revision(1)
    expect { builder.build }.not_to raise_error
    invalid = Lich::WebUI::TreeBuilder.new(owner: :fixture, page_id: 'invalid', title: 'Invalid')
    invalid.overlay { text(content: 'Unpositioned', placement: { x: 10 }) }
    expect { invalid.build }.to raise_error(Lich::WebUI::SchemaViolationError, /positioned/)
    missing = Lich::WebUI::TreeBuilder.new(owner: :fixture, page_id: 'missing', title: 'Missing')
    missing.focus_revision(1)
    expect { missing.build }.to raise_error(Lich::WebUI::SchemaViolationError, /requires a focus target/)
  end

  it 'accepts one typed text Button child and rejects interactive or duplicate content' do
    builder.button(label: '') { text(slot: 'content', content: 'Die') }
    expect { builder.build }.not_to raise_error
    interactive = Lich::WebUI::TreeBuilder.new(owner: :fixture, page_id: 'input', title: 'Invalid')
    interactive.button(label: '') { text_input(slot: 'content', value: '') }
    expect { interactive.build }.to raise_error(Lich::WebUI::SchemaViolationError, /child type/)
    duplicate = Lich::WebUI::TreeBuilder.new(owner: :fixture, page_id: 'duplicate', title: 'Invalid')
    duplicate.button(label: '') do
      text(slot: 'content', content: 'First')
      text(slot: 'content', content: 'Second')
    end
    expect { duplicate.build }.to raise_error(Lich::WebUI::SchemaViolationError, /unique/)
  end

  it 'validates typography on native buttons and entry frames alongside label line limits' do
    builder.button(label: 'Roll', font_family: 'monospace', font_size: 10)
    builder.text_input(value: '', has_frame: false, font_family: 'serif', font_size: 12)
    builder.text(content: 'Instructions', line_limit: -1)
    expect { builder.build }.not_to raise_error
    expect { builder.button(label: 'Invalid', font_size: 97) }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { builder.text_input(value: '', has_frame: 'false') }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect { builder.text(content: 'Invalid', line_limit: 0) }.to raise_error(Lich::WebUI::SchemaViolationError)
  end

  it 'bounds native grid row spans including their starting row' do
    builder.grid(cols: 2) do
      text(content: 'Instructions', placement: { column: 2, row: 9, row_span: 92 })
      text(content: 'Last row', placement: { row: 1024 })
    end
    expect { builder.build }.not_to raise_error
    other = Lich::WebUI::TreeBuilder.new(owner: :fixture, page_id: 'overflow', title: 'Overflow')
    other.grid(cols: 2) { text(content: 'Overflow', placement: { row: 1024, row_span: 2 }) }
    expect { other.build }.to raise_error(Lich::WebUI::SchemaViolationError, /exceeds grid rows/)
  end

  it 'requires explicit bounded placement for spread grid row sizing' do
    builder.grid(cols: 2, row_sizing: :spread) do
      text(content: 'First', placement: { column: 1, row: 1 })
      text(content: 'Tall', placement: { column: 2, row: 1, row_span: 8 })
    end
    expect { builder.build }.not_to raise_error
    expect { builder.grid(cols: 2, row_sizing: :unknown) }.to raise_error(Lich::WebUI::SchemaViolationError)
    other = Lich::WebUI::TreeBuilder.new(owner: :fixture, page_id: 'missing', title: 'Missing')
    other.grid(cols: 2, row_sizing: :spread) { text(content: 'Unplaced') }
    expect { other.build }.to raise_error(Lich::WebUI::SchemaViolationError, /explicit row/)
  end
end
