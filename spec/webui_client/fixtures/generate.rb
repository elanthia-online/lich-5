# frozen_string_literal: true

# Regenerates renders.json: the `render` messages the REAL runtime sends for
# the pages the client harness drives, so a case runs app.js against what
# the server actually emits rather than a hand-typed imitation of it.
#
#   bundle exec ruby spec/webui_client/fixtures/generate.rb
#
# Rerun it when the contract or the tree builder changes what a render
# carries, and commit the result.

$LOAD_PATH.unshift(File.expand_path('../../../lib', __dir__))
require 'webui'
require 'json'

connection = Class.new do
  attr_reader :sent

  def initialize
    @sent = []
  end

  def viewer_id = 'harness'

  def send_text(payload)
    @sent << JSON.parse(payload)
    true
  end

  def close; end
  def alive? = true
end.new

registry = Lich::WebUI::Registry.new
dispatcher = Lich::WebUI::Dispatcher.new
runtime = Lich::WebUI::Runtime.new(registry: registry, dispatcher: dispatcher, viewers: Lich::WebUI::ViewerStore.new)
owner = Object.new
noop = ->(_event) {}

pages = {
  # Two independent actions, for the stale-generation replay cases.
  'actions' => Lich::WebUI::Page.new(owner: owner, id: 'actions', title: 'Actions') do
    button(key: 'a', label: 'A', on: { activate: noop })
    button(key: 'b', label: 'B', on: { activate: noop })
    note = text_input(key: 'note', value: 'first', on: { change: noop })
    button(key: 'save', label: 'Save', submit: [note], on: { activate: noop })
  end,
  # Text-like controls whose drafts a render must not wipe, and a password
  # with its submit button.
  'edits'   => Lich::WebUI::Page.new(owner: owner, id: 'edits', title: 'Edits') do
    text_input(key: 'name', value: 'Alice', on: { change: noop })
    number_input(key: 'count', value: 3, min: 0, max: 100, on: { change: noop })
    password = password_input(key: 'secret', on: { change: noop, submit: noop })
    button(key: 'login', label: 'Log in', submit: [password], on: { activate: noop })
  end,
  # Multi-select table, a disabled one, and a select in both states.
  'tables'  => Lich::WebUI::Page.new(owner: owner, id: 'tables', title: 'Tables') do
    columns = [{ key: 'name', label: 'Name' }]
    rows = %w[a b c d e].map { |key| { key: key, cells: { name: key.upcase } } }
    table(key: 'live', columns: columns, rows: rows, selection: 'multi',
          on: { selection_change: noop, row_activate: noop })
    table(key: 'locked', columns: columns, rows: rows, selection: 'multi', disabled: true,
          on: { selection_change: noop, row_activate: noop })
    options = [{ value: 'x', label: 'X' }, { value: 'y', label: 'Y' }]
    select(key: 'pick', options: options, value: 'x', on: { change: noop })
    select(key: 'frozen', options: options, value: 'x', disabled: true, on: { change: noop })
    # A tree: a collapsed parent with two children, an expanded one with one.
    table(key: 'tree', columns: columns, selection: 'single',
          rows: [
            { key: 'p1', cells: { name: 'Parent 1' }, expanded: false },
            { key: 'c1', parent: 'p1', cells: { name: 'Child 1' } },
            { key: 'c2', parent: 'p1', cells: { name: 'Child 2' } },
            { key: 'p2', cells: { name: 'Parent 2' }, expanded: true },
            { key: 'c3', parent: 'p2', cells: { name: 'Child 3' } },
            { key: 'leaf', cells: { name: 'Leaf' } },
          ], on: { selection_change: noop, row_toggle: noop })
    # An editable text column.
    table(key: 'editable', columns: [{ key: 'name', label: 'Name', editor: { type: 'text' } }],
          rows: [{ key: 'r1', cells: { name: 'old' } }], selection: 'none',
          on: { cell_edit: noop })
  end,
  # 2.20 chips: a searchable picker, one with custom values and a cap, and
  # one that lists everything on focus.
  'chips'   => Lich::WebUI::Page.new(owner: owner, id: 'chips', title: 'Chips') do
    areas = [
      { value: 'thanot', label: 'Thanot', group: 'Icemule' }, { value: 'pinefar', label: 'Pinefar', group: 'Icemule' },
      { value: 'zul', label: 'Zul Logoth', group: 'Wehnimer' }, { value: 'gyre', label: 'Gyre', group: 'Wehnimer' },
    ]
    chips(key: 'areas', label: 'Areas', options: areas, value: ['thanot'], placeholder: 'area', on: { change: noop })
    chips(key: 'rooms', label: 'Rooms', allow_custom: true, max: 3, value: %w[12345 23456], on: { change: noop })
    chips(key: 'all', label: 'All', options: areas, searchable: false, on: { change: noop })
    # 2.20 on the older inputs: a select as a list box with groups, and a
    # radio with groups.
    select(key: 'town', label: 'Town', options: areas, value: 'zul', size: 4, on: { change: noop })
    radio(key: 'side', label: 'Side', group: 'side', options: areas, selected: 'gyre', on: { change: noop })
  end,
  # Drawn shapes: the 2.17 layers.
  'shapes'  => Lich::WebUI::Page.new(owner: owner, id: 'shapes', title: 'Shapes') do
    composite(key: 'surface', width: 100, height: 100, surface_events: true,
              on: { surface_activate: noop, surface_zoom: noop }, layers: [
                { kind: 'ellipse', x: 10, y: 10, w: 20, h: 20, stroke: { r: 255, g: 0, b: 0, a: 0.8 }, stroke_width: 3 },
                { kind: 'rect', x: 40, y: 40, w: 30, h: 20, stroke: { tone: 'danger' }, fill: { r: 0, g: 0, b: 255, a: 0.5 } },
                { kind: 'line', x1: 0, y1: 0, x2: 99, y2: 99, stroke: { r: 0, g: 200, b: 0, a: 1.0 }, stroke_width: 2 },
              ])
  end,
}

renders = pages.to_h do |name, page|
  registered = registry.register(page)
  address = registry.address_for(registered)
  result = runtime.handle(connection, type: 'attach', page: address, version: Lich::WebUI::Contract::VERSION)
  raise "attach for #{name} was #{result.inspect}: #{connection.sent.last.inspect}" unless result == :attached

  render = connection.sent.last
  raise "expected a render for #{name}, got #{render['type']}" unless render['type'] == 'render'

  [name, render]
end

path = File.join(__dir__, 'renders.json')
File.write(path, "#{JSON.pretty_generate(renders)}\n")
puts "wrote #{path} (#{renders.size} pages)"
dispatcher.shutdown
