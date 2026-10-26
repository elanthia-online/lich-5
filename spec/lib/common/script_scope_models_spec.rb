# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_shim_bindings'
require 'timeout'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'bounded model, tree and combo compatibility' do
  include WebUISpecSupport::ShimBindings

  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('models.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:gtk) { scope.const_get(:Gtk, false) }

  before do
    install_webui_shim_bindings
    allow(Lich).to receive(:log)
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  def wait_for(&block)
    Timeout.timeout(3) { sleep 0.005 until block.call }
  end

  def show(*widgets)
    window = gtk::Window.new
    widgets.each { |widget| window.add(widget) }
    window.show_all
    page = nil
    wait_for { (page = service.registry.pages_for(owner).first)&.last_render }
    [window, page]
  end

  def connect(page, id, resume: nil)
    connection = Struct.new(:viewer_id, :messages).new(id, [])
    def connection.alive? = true
    def connection.send_text(text) = messages << JSON.parse(text)
    service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page), resume: resume)
    connection
  end

  def nodes(connection)
    tree = connection.messages.reverse.find { |message| message['type'] == 'render' }.fetch('tree')
    flatten = ->(node) { [node] + Array(node['children']).flat_map { |child| flatten.call(child) } }
    flatten.call(tree)
  end

  def send_event(page, connection, type, event, payload, submission: nil)
    render = connection.messages.reverse.find { |message| message['type'] == 'render' }
    node = nodes(connection).find { |candidate| candidate['type'] == type.to_s }
    message = { type: 'event', page: service.registry.address_for(page), generation: render['generation'], cid: node['cid'], event: event, payload: payload }
    message[:submission] = submission if submission
    service.runtime.handle(connection, message)
  end

  def table(model)
    view = gtk::TreeView.new(model)
    view.append_column(gtk::TreeViewColumn.new('Name', gtk::CellRendererText.new, text: 0))
    view
  end

  def drain_models
    barrier = Queue.new
    gtk.queue { barrier << true }
    expect(barrier.pop(timeout: 5)).to be(true)
  end

  it 'clears container tooltips before publication and updates their live metadata' do
    notebook, scroll = gtk::Notebook.new, gtk::ScrolledWindow.new
    content = gtk::Label.new('Content')
    scroll.add(content)
    notebook.append_page(scroll, gtk::Label.new('One'))
    [notebook, scroll].each { |widget| widget.set_tooltip_text(nil); expect(widget.tooltip_text).to eq('') }
    _window, page = show(notebook)
    connection = connect(page, 'tooltips')
    expect(nodes(connection).select { |node| %w[tabs scroll].include?(node['type']) }.map { |node| node['props']['tooltip'] }).to eq(['', ''])
    [notebook, scroll].each { |widget| widget.tooltip_text = '<literal help>' }
    wait_for { nodes(connection).select { |node| %w[tabs scroll].include?(node['type']) }.all? { |node| node['props']['tooltip'] == '<literal help>' } }
    expect(nodes(connection).select { |node| %w[tabs scroll].include?(node['type']) }.map { |node| node['props']['tooltip'] }).to eq(['<literal help>', '<literal help>'])
    [notebook, scroll].each { |widget| widget.set_tooltip_text(nil); expect(widget.get_tooltip_text).to eq('') }
    wait_for { nodes(connection).select { |node| %w[tabs scroll].include?(node['type']) }.all? { |node| node['props']['tooltip'] == '' } }
    expect(nodes(connection).select { |node| %w[tabs scroll].include?(node['type']) }.map { |node| node['props']['tooltip'] }).to eq(['', ''])
    expect(notebook.get_nth_page(0)).to equal(scroll)
    expect(notebook.send(:read, :selected)).to eq(0)
  end

  it 'rebuilds a materialized combo and selects a newly appended duplicate label in the same queued callback' do
    combo = gtk::ComboBoxText.new
    combo.append_text('Old')
    combo.active = 0
    trigger = gtk::Button.new('Rebuild')
    observed = Queue.new
    changed = []
    combo.signal_connect('changed') { changed << [combo.active, combo.active_text] }
    trigger.signal_connect('clicked') do
      gtk.queue do
        combo.remove_all
        2.times { combo.append_text('All') }
        combo.set_active(1) if combo.model.iter_n_children(nil).positive?
        observed << [combo.active, combo.active_text, combo.active_iter.key]
      end
    end
    _window, page = show(combo, trigger)
    viewer = connect(page, 'combo-rebuild')
    expect(send_event(page, viewer, :button, :activate, {}, submission: [combo.model.rows.first.key])).to eq(:queued)
    result = observed.pop(timeout: 3)
    expect(result).to eq([1, 'All', combo.model.rows[1].key])
    expect(changed).to eq([[1, 'All']])
    drain_models
    expect(Lich).not_to have_received(:log).with(/callback failed/)
  end

  it 'adds partial column mappings without dropping sensitivity or background and refuses invalid candidates atomically' do
    model = gtk::ListStore.new(String, TrueClass, TrueClass, String, TrueClass)
    row = model.append
    ['Old', true, false, 'New', false].each_with_index { |value, index| row[index] = value }
    renderer = gtk::CellRendererText.new
    column = gtk::TreeViewColumn.new('Name', renderer)
    column.add_attribute(renderer, 'sensitive', 1)
    column.set_attributes(renderer, text: 0, background_set: 2)
    column.add_attribute(renderer, 'text', 3)
    column.add_attribute(renderer, 'sensitive', 4)
    column.set_attributes(renderer, background_set: 2)
    view = gtk::TreeView.new(model)
    view.append_column(column)
    expect { column.add_attribute(renderer, 'sensitive', 0) }.to raise_error(gtk::UnsupportedOperation)
    expect(column.value_column).to eq(3)
    expect(column.instance_variable_get(:@sensitive_column)).to eq(4)
    expect(column.instance_variable_get(:@background_set_column)).to eq(2)
    _window, page = show(view)
    viewer = connect(page, 'partial-bindings')
    props = nodes(viewer).find { |node| node['type'] == 'table' }['props']
    expect(props['rows'].first['cells'][column.key]).to eq('New')
    expect(props['rows'].first['cell_disabled']).to eq([column.key])
    expect(props['rows'].first['background_disabled']).to eq([column.key])
    expect { column.add_attribute(renderer, 'text', 0) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'omits optional Entry blur and radio clicked until subscribed, including late subscriptions' do
    entry, radio = gtk::Entry.new, gtk::RadioButton.new('Choice')
    _window, page = show(entry, radio)
    render = page.last_render
    input = render.tree.each.find { |node| node.type == :text_input }
    choice = render.tree.each.find { |node| node.type == :radio_option }
    expect(render.bindings).not_to have_key([input.cid, :blur])
    expect(render.bindings).not_to have_key([choice.cid, :activate])
    expect(render.bindings).to have_key([choice.cid, :change])
    blur = Queue.new
    entry.signal_connect('focus-out-event') { blur << entry.text }
    radio.signal_connect('clicked') {}
    wait_for { page.last_render.bindings.key?([input.cid, :blur]) && page.last_render.bindings.key?([choice.cid, :activate]) }
    viewer = connect(page, 'late-optional')
    send_event(page, viewer, :text_input, :blur, { value: 'Latest' })
    expect(blur.pop(timeout: 3)).to eq('Latest')
  end

  it 'changes a handler-free radio group without submitting unrelated entry drafts' do
    entry = gtk::Entry.new
    first = gtk::RadioButton.new('First')
    second = gtk::RadioButton.new(first, 'Second')
    changed = []
    entry.signal_connect('changed') { changed << entry.text }
    _window, page = show(entry, first, second)
    viewer = connect(page, 'plain-radio')
    render = viewer.messages.reverse.find { |message| message['type'] == 'render' }
    choice = nodes(viewer).find { |node| node['type'] == 'radio_option' && node['props']['label'] == 'Second' }
    expect(service.runtime.handle(viewer, type: 'event', page: service.registry.address_for(page), generation: render['generation'],
                                  cid: choice['cid'], event: 'change', payload: { value: true })).to eq(:queued)
    drain_models
    expect(changed).to be_empty
    expect(entry.text).to eq('')
    expect(page.last_render.bindings.keys).not_to include([choice['cid'], :activate])
  end

  it 'normalizes immutable key event masks while preserving wrapped instances and positional construction' do
    modifier = gtk::ModifierState.new(5)
    event = gtk::KeyEvent.new(keyval: 113, state: 5)
    expect(event).to be_frozen
    expect(event.keyval).to eq(113)
    expect(event.state.control_mask?).to be(true)
    expect(event.state.shift_mask?).to be(true)
    expect(event.state & 4).to eq(4)
    expect(event.state.to_i).to eq(5)
    expect(gtk::KeyEvent.new(113, 0).state.control_mask?).to be(false)
    expect(gtk::KeyEvent.new(keyval: 113, state: modifier).state).to equal(modifier)
  end

  it 'delivers modifier predicates in both key press and release callbacks' do
    window = gtk::Window.new
    observed = Queue.new
    %w[key-press-event key-release-event].each do |signal|
      window.signal_connect(signal) { |_widget, event| observed << [signal, event.keyval, event.state.control_mask?, event.state.shift_mask?] }
    end
    window.show_all
    page = nil
    wait_for { (page = service.registry.pages_for(owner).first)&.last_render }
    viewer = connect(page, 'modifier-events')
    send_event(page, viewer, :page, :key_press, { keyval: 113, state: 5 })
    expect(observed.pop(timeout: 3)).to eq(['key-press-event', 113, true, true])
    send_event(page, viewer, :page, :key_release, { keyval: 113, state: 0 })
    expect(observed.pop(timeout: 3)).to eq(['key-release-event', 113, false, false])
  end

  it 'returns the Notebook receiver through changed, unchanged, ignored and chained page selection' do
    notebook = gtk::Notebook.new
    expect(notebook.set_current_page(0)).to equal(notebook)
    pages = 3.times.map { |index| gtk::Label.new(index.to_s) }
    pages.each_with_index { |page, index| notebook.append_page(page, gtk::Label.new(index.to_s)) }
    calls = []
    notebook.signal_connect('switch-page') { |_widget, page, index| calls << [page, index]; :arbitrary_handler_result }
    expect(notebook.set_current_page(1)).to equal(notebook)
    expect(notebook.set_current_page(1).show_all).to equal(notebook)
    expect(calls).to eq([[pages[1], 1]])
    expect(notebook.set_current_page(99)).to equal(notebook)
    pages[2].hide
    expect(notebook.set_current_page(-1)).to equal(notebook)
    expect(notebook.send(:read, :selected)).to eq(1)
    pages[2].show
    expect(notebook.set_current_page(-2)).to equal(notebook)
    expect(calls.last).to eq([pages[2], 2])
    expect { notebook.set_current_page('1') }.to raise_error(gtk::UnsupportedOperation)
    notebook.destroy
    expect { notebook.set_current_page(0) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'filters browser and programmatic selection in owner context without committing rejected or failing proposals' do
    model = gtk::ListStore.new(String)
    rows = %w[Allowed Denied Failing].map { |name| model.append.tap { |iter| iter[0] = name } }
    view = table(model)
    calls, changed = [], []
    selection = view.selection
    selection.set_select_function do |received, store, path, selected|
      expect(received).to equal(selection)
      expect(store).to equal(model)
      name = store.get_iter(path)[0]
      calls << [name, selected]
      raise 'predicate failure' if name == 'Failing'
      name != 'Denied'
    end
    selection.signal_connect('changed') { changed << selection.selected&.[](0) }
    selection.select_iter(rows[1])
    expect(selection.selected).to be_nil
    selection.select_iter(rows[0])
    expect(selection.selected[0]).to eq('Allowed')
    expect { selection.select_iter(rows[2]) }.to raise_error('predicate failure')
    expect(selection.selected[0]).to eq('Allowed')
    _window, page = show(view)
    first = connect(page, 'predicate-one')
    other = connect(page, 'predicate-two')
    props = ->(viewer) { nodes(viewer).find { |node| node['type'] == 'table' }.fetch('props') }
    events_before = changed.dup
    before = first.messages.size
    expect(send_event(page, first, :table, 'selection_change', { rows: [rows[1].key] })).to eq(:queued)
    wait_for { first.messages.size > before }
    expect(props.call(first)['selected']).to eq([rows[0].key])
    expect(changed).to eq(events_before)
    before = first.messages.size
    expect(send_event(page, first, :table, 'selection_change', { rows: [rows[2].key] })).to eq(:queued)
    wait_for { first.messages.size > before }
    expect(props.call(first)['selected']).to eq([rows[0].key])
    expect(changed).to eq(events_before)
    selection.set_select_function { |_selection, _model, _path, _selected| true }
    expect(send_event(page, first, :table, 'selection_change', { rows: [rows[1].key] })).to eq(:queued)
    wait_for { changed.last == 'Denied' }
    # This transport double has no optimistic DOM. Request a snapshot explicitly;
    # successful unchanged acceptance deliberately does not repaint the browser.
    service.runtime.refresh(page)
    expect(props.call(first)['selected']).to eq([rows[1].key])
    expect(props.call(other)['selected']).to eq([rows[0].key])
    expect(changed.last).to eq('Denied')
    expect(calls).to include(['Allowed', true], ['Denied', false], ['Failing', false])
    selection.set_select_function { selection.select_iter(rows[0]); true }
    expect { selection.select_iter(rows[1]) }.to raise_error(gtk::UnsupportedOperation, /select_function_recursion/)
    selection.set_select_function { true }
    selection.select_iter(rows[1])
    expect(selection.selected[0]).to eq('Denied')
  end

  it 'retains vetoed multi-selection removals and browse membership using current sorted paths' do
    model = gtk::ListStore.new(String)
    first, second = model.append, model.append
    first[0], second[0] = 'Zulu', 'Alpha'
    view = table(model)
    view.selection.mode = :multiple
    view.selection.select_all
    seen = []
    view.selection.set_select_function do |_selection, store, path, selected|
      seen << [path.to_s, store.get_iter(path)[0], selected]
      store.get_iter(path)[0] != 'Zulu'
    end
    model.set_sort_column_id(0, :ascending)
    view.selection.unselect_all
    expect(view.selection.selected_rows.first.map(&:to_s)).to eq(['1'])
    expect(seen).to include(['1', 'Zulu', true], ['0', 'Alpha', true])
    view.selection.mode = :browse
    view.selection.unselect_all
    expect(view.selection.selected[0]).to eq('Zulu')
    model.remove(first)
    expect(view.selection.selected[0]).to eq('Alpha')
  end

  it 'projects cell callbacks with isolated literal text and foregrounds across rows and columns' do
    model = gtk::ListStore.new(String, TrueClass)
    first, second = model.append, model.append
    first[0], first[1] = 'First', true
    second[0], second[1] = 'Second', false
    renderer = gtk::CellRendererText.new
    view = gtk::TreeView.new(model)
    column = gtk::TreeViewColumn.new('Projected', renderer, text: 0)
    column.set_cell_data_func(renderer) do |received, cell, store, iter|
      expect(received).to equal(column)
      expect(store).to equal(model)
      cell.text = "<#{store.get_value(iter, 0)}>"
      cell.foreground_rgba = scope.const_get(:Gdk)::RGBA.new(1, 0, 0, 1) if iter[1]
    end
    view.append_column(column)
    other = gtk::TreeViewColumn.new('Plain', renderer, text: 0)
    view.append_column(other)
    _window, page = show(view)
    viewer = connect(page, 'cell-projection')
    rendered = -> { nodes(viewer).find { |node| node['type'] == 'table' }.fetch('props').fetch('rows') }
    expect(rendered.call[0]['cells']).to eq(column.key => '<First>', other.key => 'First')
    expect(rendered.call[0]['cell_foregrounds']).to eq([{ 'column' => column.key, 'color' => { 'r' => 255, 'g' => 0, 'b' => 0, 'a' => 1.0 } }])
    expect(rendered.call[1].fetch('cell_foregrounds', [])).to be_empty
    key = first.key
    first[0] = 'Updated'
    wait_for { rendered.call[0]['cells'][column.key] == '<Updated>' }
    expect(rendered.call[0]['key']).to eq(key)
    expect(model.rows.map { |iter| iter[0] }).to eq(%w[Updated Second])
    expect { column.set_cell_data_func(renderer) {} }.to raise_error(gtk::UnsupportedOperation)
    expect { renderer.project_cell('Failed') { renderer.text = 'Temporary'; raise 'source error' } }.to raise_error('source error')
    expect(renderer.text).to be_nil
    expect(renderer.project_cell('Next')).to eq(['Next', nil])
  end

  it 'keeps column minimums and tooltips bounded and dispatches custom header callbacks independently of model sorting' do
    model = gtk::ListStore.new(String)
    model.append[0] = 'Original'
    view = table(model)
    column = view.columns.first
    column.min_width = 120
    column.clickable = true
    column.set_tooltip_text('Sort by name')
    calls = []
    column.signal_connect('clicked') { |received| calls << received; model.rows.first[0] = 'Clicked' }
    view.tooltip_text = 'Inventory'
    _window, page = show(view)
    viewer = connect(page, 'header-click')
    props = nodes(viewer).find { |node| node['type'] == 'table' }['props']
    expect(props['columns'].first).to include('min_width' => 120, 'activatable' => true, 'sortable' => false, 'tooltip' => 'Sort by name')
    expect(props['tooltip']).to eq('Inventory')
    expect(send_event(page, viewer, :table, 'column_activate', { column: column.key })).to eq(:queued)
    wait_for { calls.size == 1 }
    expect(calls).to eq([column])
    expect(model.rows.first[0]).to eq('Clicked')
    column.min_width = 160
    [-1, 65_537, 1.5].each { |value| expect { column.min_width = value }.to raise_error(gtk::UnsupportedOperation) }
    expect(column.definition[:min_width]).to eq(160)
    column.clickable = false
    expect(column.definition[:activatable]).to be(false)
  end

  it 'maps hexadecimal RGBA and italic markup into bounded literal presentation' do
    rgba = scope.const_get(:Gdk)::RGBA
    expect(rgba.parse('#d3d3d3').to_h).to eq(r: 211, g: 211, b: 211, a: 1.0)
    expect(rgba.parse('#FFFF00008080').to_h).to eq(r: 255, g: 0, b: 128, a: 1.0)
    expect(rgba.parse('green').to_h).to eq(r: 0, g: 255, b: 0, a: 1.0)
    ['#abc', '#gg0000', '#000000ff', 'url(x)', nil].each do |color|
      expect { rgba.parse(color) }.to raise_error(gtk::UnsupportedOperation)
    end
    label = gtk::Label.new
    label.set_markup("<i>Explorer &amp; team\nDetails</i>".b)
    _window, page = show(label)
    connection = connect(page, 'italic')
    props = nodes(connection).find { |node| node['type'] == 'text' }['props']
    expect(props).to include('font_style' => 'italic', 'content' => "Explorer & team\nDetails")
    ['<i onclick="x">bad</i>', '<i>unclosed'].each do |markup|
      expect { label.set_markup(markup) }.to raise_error(gtk::UnsupportedOperation)
    end
    label.set_markup('Plain')
    wait_for do
      props = nodes(connection).find { |node| node['type'] == 'text' }['props']
      props['font_style'] == 'normal' && props['content'] == 'Plain'
    end
  end

  [[2, 0, 1, 0], [1, 0, 0, 0], [1, 1, 1, 0], [1, 2, 1, 0]].each do |chosen, removed, retained, default|
    it "PR63 remaps a saved notebook selection #{chosen} after removing page #{removed} without collapsing defaults" do
      notebook = gtk::Notebook.new
      %w[A B C].each { |name| notebook.append_page(gtk::Label.new(name + ' content'), gtk::Label.new(name)) }
      saved = Queue.new
      save = gtk::Button.new('Save')
      save.signal_connect('clicked') { saved << notebook.send(:read, :selected) }
      _window, page = show(notebook, save)
      viewer, other = connect(page, 'saved'), connect(page, 'independent')
      headers = nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['headers']
      send_event(page, viewer, :tabs, 'select', { index: chosen, tab: headers[chosen]['key'] })
      wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['selected'] == chosen }
      send_event(page, viewer, :button, 'activate', {})
      expect(saved.pop(timeout: 2)).to eq(chosen)
      notebook.remove_page(removed)
      wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['names'].length == 2 }
      expect(notebook.send(:read, :selected)).to eq(retained)
      expect(notebook.send(:component_props)[:selected]).to eq(default)
      expect(nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(retained)
      expect(nodes(other).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(default)
    end
  end

  it 'preserves independent viewer and committed page selections while replacing tab actions' do
    notebook = gtk::Notebook.new
    %w[A B C].each { |name| notebook.append_page(gtk::Label.new(name), gtk::Label.new(name)) }
    help = gtk::Button.new('Help')
    observed = Queue.new
    help.signal_connect('clicked') { observed << notebook.send(:read, :selected) }
    notebook.set_action_widget(help, :end)
    _window, page = show(notebook)
    viewer, other = connect(page, 'actions-one'), connect(page, 'actions-two')
    headers = nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['headers']
    send_event(page, viewer, :tabs, 'select', { index: 2, tab: headers[2]['key'] })
    wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['selected'] == 2 }
    send_event(page, viewer, :button, 'activate', {})
    expect(observed.pop(timeout: 2)).to eq(2)
    notebook.set_action_widget(gtk::Button.new('Replacement'), :end)
    wait_for { nodes(viewer).any? { |node| node['props']['label'] == 'Replacement' } }
    expect(notebook.send(:read, :selected)).to eq(2)
    expect(notebook.send(:component_props)[:selected]).to eq(0)
    expect(nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(2)
    expect(nodes(other).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(0)
    notebook.remove_page(0)
    wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['names'].length == 2 }
    expect(notebook.send(:read, :selected)).to eq(1)
    expect(nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(1)
    expect(nodes(other).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(0)
  end

  it 'PR63 preserves both notebook selection stores when a post-Save structural update refuses' do
    notebook = gtk::Notebook.new
    %w[A B C].each { |name| notebook.append_page(gtk::Label.new(name), gtk::Label.new(name)) }
    saved = Queue.new
    save = gtk::Button.new('Save')
    save.signal_connect('clicked') { saved << true }
    _window, page = show(notebook, save)
    viewer = connect(page, 'saved')
    headers = nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['headers']
    send_event(page, viewer, :tabs, 'select', { index: 2, tab: headers[2]['key'] })
    wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['selected'] == 2 }
    send_event(page, viewer, :button, 'activate', {})
    expect(saved.pop(timeout: 2)).to be(true)
    allow(notebook.session.port).to receive(:layout_tabs).and_raise(Lich::WebUI::Error, 'rejected structure')
    expect { notebook.remove_page(0) }.to raise_error(Lich::WebUI::Error, /rejected structure/)
    expect(notebook.n_pages).to eq(3)
    expect(notebook.send(:read, :selected)).to eq(2)
    expect(notebook.send(:component_props)[:selected]).to eq(0)
  end

  it 'PR63 remaps explicit post-Save choices through empty and reopened notebooks without inventing commits' do
    notebook = gtk::Notebook.new
    %w[A B C].each { |name| notebook.append_page(gtk::Label.new(name), gtk::Label.new(name)) }
    expect(notebook.instance_variable_get(:@committed)).not_to have_key(:selected)
    notebook.remove_page(2)
    expect(notebook.instance_variable_get(:@committed)).not_to have_key(:selected)
    saved = Queue.new
    save = gtk::Button.new('Save')
    save.signal_connect('clicked') { notebook.set_current_page(1); saved << true }
    _window, page = show(notebook, save)
    viewer = connect(page, 'saved')
    send_event(page, viewer, :button, 'activate', {})
    expect(saved.pop(timeout: 2)).to be(true)
    wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['selected'] == 1 }
    notebook.remove_page(0)
    expect(notebook.send(:read, :selected)).to eq(0)
    notebook.remove_page(0)
    expect(notebook.send(:read, :selected)).to eq(0)
    notebook.append_page(gtk::Label.new('New content'), gtk::Label.new('New'))
    wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['names'] == ['New'] }
    expect(notebook.send(:read, :selected)).to eq(0)
  end

  it 'owns bounded custom tab labels separately and detaches reusable pages atomically' do
    notebook = gtk::Notebook.new
    label = gtk::Label.new('Main')
    label.override_color(:normal, scope.const_get(:Gdk)::RGBA.new(1, 0, 0, 1))
    wrapper = gtk::EventBox.new.add(label)
    page = gtk::Label.new('Content')
    expect(notebook.append_page(page, wrapper)).to eq(0)
    expect(notebook.n_pages).to eq(1)
    expect(notebook.children).to eq([page])
    expect(wrapper.parent).to equal(notebook)
    expect(label.parent).to equal(wrapper)
    expect(notebook.send(:component_props)[:headers].first[:foreground][:r]).to eq(255)
    expect { notebook.append_page(gtk::Label.new('Duplicate'), wrapper) }.to raise_error(gtk::UnsupportedOperation)
    expect { notebook.append_page(notebook, gtk::Label.new('Cycle')) }.to raise_error(gtk::UnsupportedOperation)
    expect { notebook.append_page(gtk::Label.new('Wrong'), gtk::EventBox.new) }.to raise_error(gtk::UnsupportedOperation)
    expect(notebook.n_pages).to eq(1)
    notebook.remove_page(-1)
    expect(notebook.n_pages).to eq(0)
    expect([page.parent, wrapper.parent]).to eq([nil, nil])
    expect(page.destroyed?).to be(false)
    expect(notebook.append_page(page, wrapper)).to eq(0)
    notebook.destroy
    expect([wrapper.destroyed?, label.destroyed?, page.destroyed?]).to eq([true, true, true])
    expect { notebook.remove_page(0) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'preserves independent viewer tab identities and live color across removals' do
    notebook = gtk::Notebook.new
    pages = %w[First Second Third].map { |name| gtk::Label.new(name + ' content') }
    labels = %w[First Second Third].map { |name| gtk::Label.new(name) }
    pages.zip(labels).each { |page, label| notebook.append_page(page, gtk::EventBox.new.add(label)) }
    _window, page = show(notebook)
    first, second = connect(page, 'first'), connect(page, 'second')
    headers = nodes(first).find { |node| node['type'] == 'tabs' }['props']['headers']
    send_event(page, first, :tabs, 'select', { index: 1, tab: headers[1]['key'] })
    send_event(page, second, :tabs, 'select', { index: 2, tab: headers[2]['key'] })
    wait_for { nodes(second).find { |node| node['type'] == 'tabs' }['props']['selected'] == 2 }
    notebook.remove_page(0)
    wait_for { nodes(first).find { |node| node['type'] == 'tabs' }['props']['names'] == %w[Second Third] }
    expect(nodes(first).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(0)
    expect(nodes(second).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(1)
    labels[1].override_color(:normal, scope.const_get(:Gdk)::RGBA.new(0, 1, 0, 1))
    wait_for { nodes(first).find { |node| node['type'] == 'tabs' }.dig('props', 'headers', 0, 'foreground', 'g') == 255 }
    expect(nodes(second).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(1)
    expect { labels[1].text = 'x' * 513 }.to raise_error(gtk::UnsupportedOperation)
    expect(labels[1].text).to eq('Second')
    labels[1].destroy
    wait_for { nodes(first).find { |node| node['type'] == 'tabs' }['props']['names'] == ['Third'] }
    notebook.remove_page(0)
    wait_for { nodes(second).find { |node| node['type'] == 'tabs' }['props']['names'].empty? }
    expect(nodes(second).find { |node| node['type'] == 'tabs' }['props']['selected']).to eq(0)
    notebook.append_page(pages[0], labels[0].parent)
    wait_for { nodes(first).find { |node| node['type'] == 'tabs' }['props']['names'] == ['First'] }
  end

  it 'routes custom tab presses to the original wrapper and selects newly appended pages in the same callback' do
    notebook = gtk::Notebook.new
    wrapper = gtk::EventBox.new.add(gtk::Label.new('Main'))
    observed = Queue.new
    consumed = Queue.new
    wrapper.signal_connect('button-press-event') do |widget, event|
      if event.button == scope.const_get(:Gdk)::BUTTON_MIDDLE
        notebook.append_page(gtk::Label.new('Added content'), gtk::Label.new('Added'))
        notebook.set_current_page(notebook.n_pages - 1)
        observed << [widget, event.button, event.x, event.event_type, notebook.n_pages, notebook.send(:read, :selected)]
      elsif event.button == scope.const_get(:Gdk)::BUTTON_SECONDARY
        notebook.remove_page(-1)
        observed << [widget, event.button]
      end
      true
    end
    wrapper.signal_connect('button-press-event') { consumed << true }
    notebook.append_page(gtk::Label.new('Main content'), wrapper)
    _window, page = show(notebook)
    viewer = connect(page, 'tabs')
    header = nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['headers'].first
    payload = { tab: header['key'], x: 12, y: 20, time: 1, state: 0, button: 2, click_count: 1 }
    send_event(page, viewer, :tabs, 'tab_pointer', payload)
    result = observed.pop(timeout: 2)
    expect(result).to eq([wrapper, 2, 12, scope.const_get(:Gdk)::EventType::BUTTON_PRESS, 2, 1])
    wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['selected'] == 1 }
    send_event(page, viewer, :tabs, 'tab_pointer', payload.merge(button: 3))
    expect(observed.pop(timeout: 2)).to eq([wrapper, 3])
    wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['names'] == ['Main'] }
    expect(consumed).to be_empty
    wrapper.destroy
    wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['names'].empty? }
    send_event(page, viewer, :tabs, 'tab_pointer', payload)
    expect(observed).to be_empty
  end

  it 'accepts top notebook position spellings without changing tab content, handles or viewer selection' do
    notebook = gtk::Notebook.new
    expect(notebook.set_tab_pos(:top)).to equal(notebook)
    notebook.tab_pos = gtk::PositionType::TOP
    notebook.append_page(gtk::Label.new('First content'), gtk::Label.new('First tab'))
    notebook.append_page(gtk::Label.new('Second content'), gtk::Label.new('Second tab'))
    _window, page = show(notebook)
    viewer = connect(page, 'top-tabs')
    handle = notebook.materialize
    children = notebook.children
    send_event(page, viewer, :tabs, 'select', { index: 1, tab: nodes(viewer).find { |node| node['type'] == 'tabs' }['props']['headers'][1]['key'] })
    wait_for { nodes(viewer).find { |node| node['type'] == 'tabs' }.dig('props', 'selected') == 1 }
    expect(notebook.set_tab_pos(gtk::PositionType::TOP)).to equal(notebook)
    notebook.tab_pos = :top
    expect(notebook.materialize).to equal(handle)
    expect(notebook.children).to eq(children)
    tabs = nodes(viewer).find { |node| node['type'] == 'tabs' }
    expect(tabs['props']).to include('names' => ['First tab', 'Second tab'], 'selected' => 1, 'show_tabs' => true)
    expect(tabs['children'].map { |child| child.dig('props', 'content') }).to eq(['First content', 'Second content'])
  end

  it 'refuses unsupported notebook positions before and after publication without changing its state' do
    notebook = gtk::Notebook.new
    notebook.append_page(gtk::Label.new('Retained'), gtk::Label.new('Tab'))
    [false, true].each do |live|
      show(notebook) if live
      original = notebook.send(:component_props).dup
      [gtk::PositionType::LEFT, gtk::PositionType::RIGHT, gtk::PositionType::BOTTOM, :TOP, 'top', nil, 0].each do |position|
        expect { notebook.set_tab_pos(position) }.to raise_error(gtk::UnsupportedOperation)
        expect { notebook.tab_pos = position }.to raise_error(gtk::UnsupportedOperation)
        expect(notebook.send(:component_props)).to eq(original)
      end
    end
  end

  it 'normalizes uppercase scroll policy symbols and refuses unsupported tokens' do
    scroller = gtk::ScrolledWindow.new
    expect(scroller.set_policy(:AUTOMATIC, :ALWAYS)).to equal(scroller)
    expect(scroller.set_policy(:NEVER, :automatic)).to equal(scroller)
    ['AUTOMATIC', :sometimes, nil].each do |token|
      expect { scroller.set_policy(token, :ALWAYS) }.to raise_error(gtk::UnsupportedOperation)
    end
  end

  it 'renders bounded Pango-sized dice glyphs from binary source strings as literal Unicode' do
    label = gtk::Label.new
    label.set_markup("<span size='72000'>&#x25FB;</span>".b)
    _window, page = show(label)
    props = nodes(connect(page, 'dice')).find { |node| node['type'] == 'text' }['props']
    expect(props).to include('font_size' => 70.3125, 'font_unit' => 'pt', 'content' => [0x25fb].pack('U'))
    label.set_markup('<span size="72000">&#x2680;</span>'.b)
    expect(label.text).to eq([0x2680].pack('U'))
    ['1024', '98305'].each do |size|
      expect { label.set_markup("<span size='#{size}'>dice</span>") }.to raise_error(gtk::UnsupportedOperation)
    end
    expect { label.set_markup("<span size='72000'><b>dice</b></span>") }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'links native window minimization without recursive duplicate state callbacks' do
    first, second = gtk::Window.new, gtk::Window.new
    first.add(gtk::Label.new('First'))
    second.add(gtk::Label.new('Second'))
    observed = Queue.new
    [first, second].each do |window|
      window.signal_connect('window_state_event') do |_widget, event|
        observed << [event.new_window_state, event.changed_mask]
        [first, second].each do |target|
          event.new_window_state & scope.const_get(:Gdk)::WindowState::ICONIFIED != 0 ? target.iconify : target.deiconify
        end
      end
      window.show_all
    end
    page = nil
    wait_for { (page = service.registry.pages_for(owner).first)&.last_render }
    viewer = connect(page, 'window-state')
    send_event(page, viewer, :page, :window_state, { minimized: true })
    expect(observed.pop(timeout: 3)).to eq([2, 2])
    wait_for { service.registry.pages_for(owner).all? { |entry| entry.last_render&.tree&.props&.dig(:presentation, :minimized) == true } }
    send_event(page, viewer, :page, :window_state, { minimized: true })
    drain_models
    expect(observed).to be_empty
    send_event(page, viewer, :page, :window_state, { minimized: false })
    expect(observed.pop(timeout: 3)).to eq([0, 2])
    wait_for { service.registry.pages_for(owner).all? { |entry| entry.last_render.tree.props.dig(:presentation, :minimized) == false } }
    revision = first.instance_variable_get(:@props).dig(:presentation, :minimized_revision)
    first.deiconify
    expect(first.instance_variable_get(:@props).dig(:presentation, :minimized_revision)).to eq(revision + 1)
  end

  it 'positions Layout children on a clipped canvas and retains transactional moves' do
    layout = gtk::Layout.new(nil, nil)
    child = gtk::Label.new('Canvas child')
    layout.put(child, -50, -50)
    _window, page = show(layout)
    viewer = connect(page, 'layout')
    canvas = nodes(viewer).find { |node| node['type'] == 'overlay' }
    expect(canvas['props']).to include('positioned' => true, 'clip_children' => true)
    expect(canvas['children'].first['placement']).to include('x' => -50, 'y' => -50)
    layout.move(child, 80, 45)
    wait_for { nodes(viewer).find { |node| node['type'] == 'overlay' }['children'].first['placement']['x'] == 80 }
    expect { layout.move(child, 65_537, 0) }.to raise_error(gtk::UnsupportedOperation)
    layout.remove(child)
    expect(child.parent).to be_nil
    expect { layout.move(child, 0, 0) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::Layout.new(gtk::Adjustment.new, nil) }.to raise_error(gtk::UnsupportedOperation)
    layout.set_size(200, 300)
    expect([layout.width, layout.height]).to eq([200, 300])
    layout.destroy
    expect { layout.put(child, 0, 0) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'looks up original Grid cells across spans, rebasing and removal' do
    grid = gtk::Grid.new
    first, second = gtk::Label.new('First'), gtk::Label.new('Second')
    grid.attach(first, 2, 3, 2, 2)
    grid.attach(second, -2, -1, 1, 1)
    expect(grid.get_child_at(3, 4)).to equal(first)
    expect(grid.get_child_at(-2, -1)).to equal(second)
    expect(grid.get_child_at(4, 4)).to be_nil
    expect(grid.get_child_at(0, 0)).to be_nil
    grid.remove(second)
    expect(grid.get_child_at(-2, -1)).to be_nil
    expect(grid.get_child_at(2, 3)).to equal(first)
    first.destroy
    expect(grid.get_child_at(2, 3)).to be_nil
    expect { grid.get_child_at(0.5, 0) }.to raise_error(gtk::UnsupportedOperation)
    expect { grid.get_child_at(65_537, 0) }.to raise_error(gtk::UnsupportedOperation)
    grid.destroy
    expect { grid.get_child_at(0, 0) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'renders a Button Label child and retains live text, style and replacement' do
    button, label = gtk::Button.new, gtk::Label.new('Die')
    label.set_markup('<i>Die</i>')
    button.add(label)
    expect { button.add(gtk::Label.new('Second')) }.to raise_error(gtk::UnsupportedOperation)
    _window, page = show(button)
    viewer = connect(page, 'button-label')
    child = nodes(viewer).find { |node| node['type'] == 'button' }['children'].first
    expect(child['type']).to eq('text')
    expect(child['props']).to include('content' => 'Die', 'font_style' => 'italic')
    label.set_text('Six')
    wait_for { nodes(viewer).any? { |node| node.dig('props', 'content') == 'Six' } }
    button.remove(label)
    expect(label.parent).to be_nil
    button.add(gtk::Label.new('Replacement'))
    wait_for { nodes(viewer).any? { |node| node.dig('props', 'content') == 'Replacement' } }
    expect { gtk::Button.new.add(gtk::Entry.new) }.to raise_error(gtk::UnsupportedOperation)
    foreign = gtk::Label.new('Foreign')
    other = Struct.new(:name).new('foreign.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(other)
    other_button = gtk::Button.new
    expect { other_button.add(foreign) }.to raise_error(gtk::UnsupportedOperation)
    Lich::Common::ScriptDeath.run(other)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
  end

  it 'rejects retired release handlers before publication and republishes disconnected handler sets' do
    surface = gtk::EventBox.new.add(gtk::Label.new('Release'))
    calls = []
    first = surface.signal_connect('button-release-event') { calls << :first }
    _window, page = show(surface)
    connect(page, 'release-handler')
    admitted = page.last_render
    component = admitted.tree.each.find { |node| node.props[:pointer_events] }
    original = admitted.bindings[[component.cid, :pointer_release]]
    payload = { x: 1, y: 1, button: 1, time: 0, state: 0, click_count: 1 }
    context = Lich::WebUI::Runtime::EventContext.new(nil, page, component, :pointer_release, payload, nil, admitted)
    surface.signal_connect('button-release-event') { calls << :second }
    expect { original.call(context) }.to raise_error(gtk::UnsupportedOperation, /operation=pointer_release/)
    expect(calls).to be_empty
    wait_for { !page.last_render.bindings[[component.cid, :pointer_release]].equal?(original) }
    replacement = page.last_render.bindings[[component.cid, :pointer_release]]
    replacement.call(context)
    expect(calls).to eq(%i[first second])
    calls.clear
    surface.send(:disconnect_signal_handler, first)
    expect { replacement.call(context) }.to raise_error(gtk::UnsupportedOperation, /operation=pointer_release/)
    wait_for { !page.last_render.bindings[[component.cid, :pointer_release]].equal?(replacement) }
    page.last_render.bindings[[component.cid, :pointer_release]].call(context)
    expect(calls).to eq([:second])
  end

  it 'dispatches Button pointer metadata separately from ordinary activation' do
    expect(gtk::Button.new.label).to eq('')
    button = gtk::Button.new('Customize')
    events = Queue.new
    button.signal_connect('button-press-event') { |widget, event| events << [widget, event.button, event.x, event.y]; false }
    button.signal_connect('clicked') { events << :clicked }
    _window, page = show(button)
    viewer = connect(page, 'button-pointer')
    send_event(page, viewer, :button, :pointer_press, { x: 12, y: 34, button: 3, state: 0, time: 10, click_count: 1 })
    expect(events.pop(timeout: 2)).to eq([button, 3, 12, 34])
    send_event(page, viewer, :button, :activate, {})
    expect(events.pop(timeout: 2)).to eq(:clicked)
  end

  it 'positions and moves Fixed children transactionally and retains the EventBox pointer path' do
    fixed = gtk::Fixed.new
    surface = gtk::EventBox.new
    label = gtk::Label.new('Click to toggle')
    surface.add(label)
    expect { surface.add(gtk::Label.new('Second child')) }.to raise_error(gtk::UnsupportedOperation)
    clicks = Queue.new
    surface.signal_connect('button_press_event') { |_box, event| clicks << [event.button, event.x, event.y] }
    fixed.put(surface, 120, 40)
    _window, page = show(fixed)
    viewer = connect(page, 'fixed-events')
    placed = nodes(viewer).find { |node| node['type'] == 'stack' && node['props']['pointer_events'] }
    expect(placed['placement']).to include('x' => 120, 'y' => 40)
    send_event(page, viewer, :stack, :pointer_press, { x: 121, y: 42, button: 1, state: 0, time: 10, click_count: 1 })
    expect(clicks.pop(timeout: 2)).to eq([scope.const_get(:Gdk)::BUTTON_PRIMARY, 121, 42])
    fixed.move(surface, -5, 60)
    wait_for { page.last_render.tree.children.first.children.first.placement[:x] == -5 }
    drain_models
    expect(surface.instance_variable_get(:@placement)).to eq(x: -5, y: 60)
    expect { fixed.move(surface, 65_537, 0) }.to raise_error(gtk::UnsupportedOperation)
    expect(surface.instance_variable_get(:@placement)).to eq(x: -5, y: 60)
    unattached = gtk::Label.new('Unattached')
    expect { fixed.put(unattached, 0.5, 0) }.to raise_error(gtk::UnsupportedOperation)
    expect(unattached.parent).to be_nil
    expect { fixed.move(unattached, 0, 0) }.to raise_error(gtk::UnsupportedOperation)
    fixed.remove(surface)
    fixed.put(surface, 30, 70)
    wait_for { page.last_render.tree.children.first.children.first.placement[:x] == 30 }
  end

  it 'serializes concurrent EventBox additions so only one child is attached' do
    surface = gtk::EventBox.new
    first, second = gtk::Label.new('First'), gtk::Label.new('Second')
    entered, release, probed = Queue.new, Queue.new, Queue.new
    allow(surface).to receive(:insert_child).and_wrap_original do |original, *args|
      if Thread.current[:event_box_race] == :first
        entered << true
        release.pop
      end
      original.call(*args)
    end
    inserter = Thread.new do
      Thread.current[:event_box_race] = :first
      surface.add(first)
    end
    expect(entered.pop(timeout: 3)).to be(true)
    contender = Thread.new do
      monitor = surface.session.instance_variable_get(:@mutex)
      acquired = monitor.try_enter
      # An unlocked guard allows the second insertion to finish before the first.
      # A locked guard makes the contender wait until the first insertion ends.
      probed << false unless acquired
      begin
        surface.add(second)
      rescue StandardError => error
        error
      ensure
        if acquired
          monitor.exit
          probed << true
        end
      end
    end
    acquired = probed.pop(timeout: 3)
    release << true
    expect(inserter.join(3)).not_to be_nil
    expect(contender.join(3)).not_to be_nil
    expect(inserter.value).to equal(surface)
    expect(contender.value).to be_a(gtk::UnsupportedOperation)
    expect(acquired).to be(false)
    expect(surface.children).to eq([first])
    expect(first.parent).to equal(surface)
    expect(second.parent).to be_nil
  ensure
    release&.push(true)
    [inserter, contender].each { |thread| thread&.join(3) || thread&.kill }
  end

  %i[child layout].each do |target|
    it "refuses Fixed put after concurrent #{target} destruction" do
      fixed, child = gtk::Fixed.new, gtk::Label.new('Unattached')
      entered, release = Queue.new, Queue.new
      paused = false
      allow(fixed.session).to receive(:synchronize).and_wrap_original do |original, &block|
        if Thread.current[:fixed_race] == :put && !paused
          paused = true
          entered << true
          release.pop
        end
        original.call(&block)
      end
      inserter = Thread.new do
        Thread.current[:fixed_race] = :put
        fixed.put(child, 10, 20)
      rescue StandardError => error
        error
      end
      expect(entered.pop(timeout: 3)).to be(true)
      (target == :child ? child : fixed).destroy
      release << true
      expect(inserter.value).to be_a(gtk::UnsupportedOperation)
      expect(child.parent).to be_nil
      expect(fixed.children).to be_empty
      expect(child.instance_variable_get(:@placement)).to be_nil
    ensure
      release&.push(true)
      inserter&.join(3) || inserter&.kill
    end
  end

  it 'rechecks the Fixed move guard after a concurrent removal' do
    fixed, child = gtk::Fixed.new, gtk::Label.new('Movable')
    fixed.put(child, 10, 20)
    show(fixed)
    entered, release = Queue.new, Queue.new
    paused = false
    allow(fixed.session).to receive(:synchronize).and_wrap_original do |original, &block|
      if Thread.current[:fixed_race] == :move && !paused
        paused = true
        entered << true
        release.pop
      end
      original.call(&block)
    end
    mover = Thread.new do
      Thread.current[:fixed_race] = :move
      fixed.move(child, 30, 40)
    rescue StandardError => error
      error
    end
    expect(entered.pop(timeout: 3)).to be(true)
    fixed.remove(child)
    release << true
    expect(mover.value).to be_a(gtk::UnsupportedOperation)
    expect(child.parent).to be_nil
    expect(child.instance_variable_get(:@placement)).to eq(x: 10, y: 20)
  ensure
    release&.push(true)
    mover&.join(3) || mover&.kill
  end

  it 'blocks concurrent session work throughout Fixed removal' do
    fixed, child = gtk::Fixed.new, gtk::Label.new('Movable')
    fixed.put(child, 10, 20)
    show(fixed)
    entered, release = Queue.new, Queue.new
    allow(fixed.session.port).to receive(:detach).and_wrap_original do |original, *args|
      entered << true
      release.pop
      original.call(*args)
    end
    remover = Thread.new { fixed.remove(child) }
    expect(entered.pop(timeout: 3)).to be(true)
    probe = Thread.new do
      monitor = fixed.session.instance_variable_get(:@mutex)
      acquired = monitor.try_enter
      monitor.exit if acquired
      acquired
    end
    expect(probe.value).to be(false)
    expect(child.parent).to equal(fixed)
    release << true
    expect(remover.value).to equal(fixed)
    expect(child.parent).to be_nil
    expect { fixed.move(child, 30, 40) }.to raise_error(gtk::UnsupportedOperation)
    expect(child.instance_variable_get(:@placement)).to eq(x: 10, y: 20)
  ensure
    release&.push(true)
    [probe, remover].each { |thread| thread&.join(3) || thread&.kill }
  end

  %i[removed destroyed reparented].each do |state|
    it "shows a window after its pending focus target is #{state}" do
      window, entry = gtk::Window.new, gtk::Entry.new
      window.add(entry)
      window.set_focus(entry)
      if state == :destroyed
        entry.destroy
      else
        window.remove(entry)
        gtk::Window.new.add(entry) if state == :reparented
      end
      expect(window.show).to equal(window)
      wait_for { service.registry.pages_for(owner).first&.last_render }
      expect(service.registry.pages_for(owner).first.last_render.facilities).not_to have_key(:focus)
      expect(window.instance_variable_get(:@shown)).to be(true)
    end
  end

  it 'retains focus errors for a live pending descendant' do
    window, entry = gtk::Window.new, gtk::Entry.new
    window.add(entry)
    window.set_focus(entry)
    allow(gtk.session.port).to receive(:focus).and_raise(gtk::UnsupportedOperation, 'fixture focus failure')
    expect { window.show }.to raise_error(gtk::UnsupportedOperation, 'fixture focus failure')
  end

  [false, true].each do |live|
    it "clears specialized markup typography when replacing it with plain markup (live=#{live})" do
      label = gtk::Label.new
      label.set_markup('<span size="72000">Large</span>')
      _window, page = show(label) if live
      label.set_markup('<span font_family="monospace">Mono</span>')
      label.set_markup('Plain')
      _window, page = show(label) unless live
      viewer = connect(page, 'markup-reset')
      wait_for { nodes(viewer).any? { |node| node.dig('props', 'content') == 'Plain' } }
      props = nodes(viewer).find { |node| node['type'] == 'text' }['props']
      expect(props.keys & %w[font_size font_family]).to be_empty
      expect(props['font_unit']).to eq('pt')
    end
  end

  %i[before after].each do |timing|
    it "preserves explicit font overrides applied #{timing} specialized markup" do
      label = gtk::Label.new
      font = scope.const_get(:Pango)::FontDescription.new('Serif 12')
      font.weight = :bold
      label.override_font(font) if timing == :before
      label.set_markup('<span size="72000">Large</span>')
      _window, page = show(label)
      viewer = connect(page, 'markup-base')
      label.override_font(font) if timing == :after
      label.set_markup('<span font_family="monospace">Mono</span>')
      label.set_markup('Plain')
      wait_for { nodes(viewer).any? { |node| node.dig('props', 'content') == 'Plain' } }
      props = nodes(viewer).find { |node| node['type'] == 'text' }['props']
      expect(props).to include('font_size' => 12, 'font_unit' => 'pt', 'font_family' => 'serif', 'emphasis' => 'strong')
    end
  end

  it 'retains focus before show and validates live window focus targets' do
    window = gtk::Window.new
    first, second = gtk::Entry.new, gtk::Entry.new
    window.add(first)
    window.add(second)
    window.set_focus(first)
    window.show_all
    page = nil
    wait_for { (page = service.registry.pages_for(owner).first)&.last_render&.facilities&.key?(:focus) }
    initial = page.last_render.facilities
    expect(initial[:focus]).to eq(page.last_render.tree.children.first.cid)
    expect(initial[:focus]).to include('text_input:')
    window.set_focus(second)
    wait_for { page.last_render.facilities[:focus_revision] > initial[:focus_revision] }
    expect(page.last_render.facilities[:focus]).not_to eq(initial[:focus])
    expect { window.set_focus(gtk::Entry.new) }.to raise_error(gtk::UnsupportedOperation)
    expect { window.set_focus(gtk::Label.new('Not focusable')) }.to raise_error(gtk::UnsupportedOperation)
    second.destroy
    drain_models
    expect { window.set_focus(second) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'projects parsed generic fonts onto labels, buttons and entries' do
    font = scope.const_get(:Pango)::FontDescription.new('Monospace 10')
    font.weight = :bold
    label = gtk::Label.new('Score')
    label.set_line_wrap_mode(:word)
    label.lines = -1
    label.markup = '<span font_family="monospace">Score &amp; deeds</span>'
    button = gtk::Button.new('Roll')
    entry = gtk::Entry.new
    entry.set_editable(false)
    entry.set_has_frame(false)
    [label, button, entry].each { |widget| widget.override_font(font) }
    _window, page = show(label, button, entry)
    viewer = connect(page, 'fonts')
    controls = nodes(viewer).select { |node| %w[text button text_input].include?(node['type']) }
    expect(controls.length).to eq(3)
    controls.each do |node|
      expect(node['props']).to include('font_family' => 'monospace', 'font_size' => 10, 'font_unit' => 'pt', 'emphasis' => 'strong')
    end
    expect(controls.find { |node| node['type'] == 'text' }['props']['wrap']).to be(true)
    expect(controls.find { |node| node['type'] == 'text' }['props']['line_limit']).to eq(-1)
    expect(controls.find { |node| node['type'] == 'text' }['props']['content']).to eq('Score & deeds')
    expect(controls.find { |node| node['type'] == 'text_input' }['props']['read_only']).to be(true)
    expect(controls.find { |node| node['type'] == 'text_input' }['props']['has_frame']).to be(false)
    entry.set_editable(true)
    wait_for { nodes(viewer).find { |node| node['type'] == 'text_input' }['props']['read_only'] == false }
    expect { label.set_line_wrap_mode(:unsupported) }.to raise_error(gtk::UnsupportedOperation)
    ['Monospace 5', 'Monospace 49', 'Monospace 10; color:red', 10].each do |description|
      expect { scope.const_get(:Pango)::FontDescription.new(description) }.to raise_error(gtk::UnsupportedOperation)
    end
  end

  it 'leaves empty and out-of-model combo selections unset without inventing rows' do
    combo = gtk::ComboBoxText.new
    combo.active = 0
    expect(combo.active).to eq(-1)
    expect(combo.active_text).to be_nil
    expect(combo.model.size).to eq(0)
    combo.append_text('Only row')
    combo.active = 0
    expect(combo.active_text).to eq('Only row')
    changes = []
    combo.signal_connect('changed') { changes << combo.active }
    combo.active = 2
    expect(combo.active_text).to be_nil
    expect(changes).to eq([-1])
    expect { combo.active = -2 }.to raise_error(gtk::UnsupportedOperation)
    expect { combo.active = 2**80 }.to raise_error(gtk::UnsupportedOperation)
    _window, page = show(combo)
    expect(nodes(connect(page, 'empty-combo')).find { |node| node['type'] == 'select' }['props']['value']).to eq('none')
  end

  it 'publishes tall Table and Grid spans while bounding their final row' do
    table = gtk::Table.new(10, 2)
    alignment = gtk::Alignment.new(1, 40, 0, 0)
    alignment.add(gtk::Label.new('Instructions'))
    table.attach(alignment, 1, 2, 8, 100)
    grid = gtk::Grid.new
    grid.attach(gtk::Label.new('Full row range'), 0, 0, 1, 1024)
    _window, page = show(table, grid)
    viewer = connect(page, 'tall-spans')
    placed = nodes(viewer).find { |node| node.dig('placement', 'row_span') == 92 }
    expect(placed['placement']).to include('row' => 9, 'row_span' => 92)
    expect(placed['props']['align']).to eq('end')
    expect(nodes(viewer).any? { |node| node.dig('placement', 'row_span') == 1024 }).to be(true)
    child = gtk::Label.new('Outside bound')
    expect { table.attach(child, 0, 1, 1000, 1025) }.to raise_error(gtk::UnsupportedOperation)
    expect(child.parent).to be_nil
    expect(table.n_rows).to eq(100)
    expect { grid.attach(child, 0, 1024, 1, 1) }.to raise_error(gtk::UnsupportedOperation)
    expect(child.parent).to be_nil
  end

  it 'clamps finite Alignment inputs and refuses nonfinite or nonnumeric values' do
    expect(gtk::Alignment.new(-2, 40, -1, 3).send(:component_props)[:align]).to eq(:start)
    expect(gtk::Alignment.new(2, 0, 0, 0).send(:component_props)[:align]).to eq(:end)
    expect(gtk::Alignment.new(0.5, 0, 0, 0).send(:component_props)[:align]).to eq(:center)
    [Float::NAN, Float::INFINITY, Complex(1, 2), '0'].each do |value|
      expect { gtk::Alignment.new(0, value, 0, 0) }.to raise_error(gtk::UnsupportedOperation)
    end
  end

  it 'accepts natural top-aligned content in a vertical box and aligned flow inside a scroller' do
    outer = gtk::Box.new(:vertical, 0)
    heading = gtk::Box.new(:vertical, 0)
    heading.set_vexpand(false)
    heading.valign = :start
    heading.add(gtk::Label.new('Heading'))
    scroller = gtk::ScrolledWindow.new
    scroller.set_vexpand(true)
    flow = gtk::FlowBox.new
    flow.set_vexpand(true)
    flow.valign = :start
    flow.add(gtk::Label.new('North'))
    scroller.add(flow)
    outer.pack_start(heading, expand: false, fill: true, padding: 0)
    outer.pack_start(scroller, expand: true, fill: true, padding: 0)
    _window, page = show(outer)
    viewer = connect(page, 'vertical-parents')
    grid = nodes(viewer).find { |node| node['props']['flow'] }
    expect(grid['props']['vertical_align']).to eq('start')
    expect { heading.valign = :center }.to raise_error(gtk::UnsupportedOperation)
    expect(heading.instance_variable_get(:@props)[:vertical_align]).to eq(:start)
    flow.valign = :center
    wait_for { nodes(viewer).any? { |node| node['props']['flow'] && node['props']['vertical_align'] == 'center' } }
    flow.valign = :end
    wait_for { nodes(viewer).any? { |node| node['props']['flow'] && node['props']['vertical_align'] == 'end' } }
    flow.valign = :fill
    wait_for { nodes(viewer).any? { |node| node['props']['flow'] && node['props']['vertical_align'] == 'stretch' } }
  end

  it 'continues to refuse unsupported expanding vertical-box allocation and ambiguous scroller siblings' do
    outer = gtk::Box.new(:vertical, 0)
    expanding = gtk::Box.new(:vertical, 0)
    expanding.set_vexpand(true)
    outer.add(expanding)
    expect { expanding.valign = :start }.to raise_error(gtk::UnsupportedOperation)
    scroller = gtk::ScrolledWindow.new
    a, b = gtk::Label.new('First'), gtk::Label.new('Second')
    scroller.add(a)
    scroller.add(b)
    expect { a.valign = :center }.to raise_error(gtk::UnsupportedOperation)
    expect(a.instance_variable_get(:@props)).not_to have_key(:vertical_align)
  end

  it 'delivers immutable configure data after geometry observation and suppresses duplicate measurements' do
    window, page = show(gtk::Label.new('Geometry'))
    viewer = connect(page, 'geometry-events')
    seen = []
    id = window.signal_connect('configure-event') do |widget, event|
      seen << [widget.size, widget.position, event.width, event.height, event.x, event.y, event.frozen?]
      false
    end
    geometry = { width: 410, height: 230, position: [-20, 35] }
    send_event(page, viewer, :page, 'configure', geometry)
    wait_for { seen.length == 1 }
    expect(seen.last).to eq([[410, 230], [-20, 35], 410, 230, -20, 35, true])
    send_event(page, viewer, :page, 'configure', geometry)
    drain_models
    expect(seen.length).to eq(1)
    send_event(page, viewer, :page, 'configure', geometry.merge(width: -1))
    drain_models
    expect(seen.length).to eq(1)
    window.signal_handler_disconnect(id)
    send_event(page, viewer, :page, 'configure', geometry.merge(width: 420))
    drain_models
    expect(window.size).to eq([420, 230])
    expect(seen.length).to eq(1)
  end

  it 'uses distinct stable IDs across signal families and removes only the requested destroy handler' do
    window = gtk::Window.new
    calls = []
    first = window.signal_connect('destroy') { calls << :removed }
    close = window.signal_connect('delete-event') { calls << :close; true }
    configure = window.signal_connect('configure_event') { calls << :configure }
    last = window.signal_connect('destroy') { calls << :retained }
    other = gtk::Window.new
    other_id = other.signal_connect('destroy') { calls << :other }
    expect([first, close, configure, last, other_id].uniq.length).to eq(5)
    expect { gtk::Button.new('Other facade').signal_handler_disconnect(first) }.to raise_error(gtk::UnsupportedOperation)
    expect { window.signal_handler_disconnect(other_id) }.to raise_error(gtk::UnsupportedOperation)
    window.signal_handler_disconnect(first)
    expect { window.signal_handler_disconnect(first) }.to raise_error(gtk::UnsupportedOperation)
    replacement = window.signal_connect('destroy') { calls << :new }
    expect(replacement).not_to eq(first)
    window.destroy
    expect(calls).to eq([:retained, :new])
    expect { window.signal_connect('destroy') {} }.to raise_error(gtk::UnsupportedOperation)
    expect { window.signal_handler_disconnect(last) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'honors disconnection during emission and registers new handlers for the next emission' do
    window, page = show(gtk::Label.new('Ordering'))
    viewer = connect(page, 'geometry-order')
    calls = []
    second = nil
    added = false
    window.signal_connect('configure_event') do
      calls << :first
      unless added
        window.signal_handler_disconnect(second)
        window.signal_connect('configure_event') { calls << :later }
        added = true
      end
      false
    end
    second = window.signal_connect('configure_event') { calls << :removed }
    send_event(page, viewer, :page, 'configure', { width: 100, height: 50, position: [0, 0] })
    wait_for { calls.length == 1 }
    expect(calls).to eq([:first])
    send_event(page, viewer, :page, 'configure', { width: 110, height: 50, position: [0, 0] })
    wait_for { calls.length == 3 }
    expect(calls).to eq([:first, :first, :later])
    foreign = Struct.new(:name).new('foreign-signals')
    allow(Lich::Common::Script).to receive(:current).and_return(foreign)
    expect { window.signal_handler_disconnect(second) }.to raise_error(gtk::UnsupportedOperation)
  ensure
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
  end

  it 'owns an icon and positioned palette panel without publishing its choices as a second window' do
    button = gtk::MenuButton.new
    image = gtk::Image.new(icon_name: 'preferences-desktop-color-symbolic', icon_size: gtk::IconSize::SMALL_TOOLBAR)
    button.set_image(image)
    panel = gtk::Popover.new(button)
    panel.set_position(gtk::PositionType::TOP)
    choices = gtk::Box.new(:vertical, 0)
    choices.add(gtk::ToggleButton.new(label: 'Dark'))
    panel.add(choices)
    button.set_popover(panel)
    window, page = show(button)
    viewer = connect(page, 'palette')
    tree = nodes(viewer)
    expect(tree.find { |node| node['props']['menu'] == 'popover' }['props']).to include('menu_icon' => true, 'menu_position' => 'top')
    expect(tree.count { |node| node['type'] == 'page' }).to eq(1)
    expect(image.parent).to equal(button)
    expect(panel.parent).to equal(button)
    panel.set_position(:left)
    wait_for { nodes(viewer).any? { |node| node['props']['menu_position'] == 'left' } }
    expect { panel.set_position(:floating) }.to raise_error(gtk::UnsupportedOperation)
    expect(panel.position).to eq(:left)
    window.destroy
    expect([button, image, panel, choices].all?(&:destroyed?)).to be(true)
    expect { panel.set_position(:top) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'keeps popover placement off ordinary container properties before and after materialization' do
    [false, true].each do |live|
      box = gtk::Box.new(:vertical, 0)
      panel = gtk::Popover.new
      box.add(panel)
      box.materialize if live
      expect { panel.set_position(:left) }.not_to raise_error
      expect(panel.position).to eq(:left)
      expect(box.instance_variable_get(:@props)).not_to have_key(:menu_position)
      expect { box.materialize }.not_to raise_error
    end
  end

  it 'refuses foreign or multiply owned palette content and unsupported icon requests' do
    button = gtk::MenuButton.new
    other = gtk::MenuButton.new
    panel = gtk::Popover.new(button)
    expect { other.set_popover(panel) }.to raise_error(gtk::UnsupportedOperation)
    panel.add(gtk::Label.new('One'))
    expect { panel.add(gtk::Label.new('Two')) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::Image.new(icon_name: 'arbitrary-path', icon_size: :small_toolbar) }.to raise_error(gtk::UnsupportedOperation)
    foreign = Struct.new(:name).new('foreign')
    allow(Lich::Common::Script).to receive(:current).and_return(foreign)
    expect { button.set_popover(panel) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    expect(panel.parent).to be_nil
  ensure
    Lich::Common::ScriptDeath.run(foreign) if foreign
  end

  it 'reflows nonselecting children after live column changes, removal and reattachment' do
    flow = gtk::FlowBox.new
    flow.selection_mode = :none
    flow.max_children_per_line = 3
    flow.row_spacing = 4
    flow.column_spacing = 6
    flow.homogeneous = true
    labels = 5.times.map { |i| gtk::Label.new("Cell #{i}") }
    labels.each { |label| flow.add(label) }
    _window, page = show(flow)
    viewer = connect(page, 'flow')
    expect(nodes(viewer).find { |node| node['type'] == 'grid' }['props']).to include('flow' => true, 'cols' => 3, 'row_gap' => 4, 'column_gap' => 6, 'equal_rows' => true)
    flow.max_children_per_line = 2
    flow.homogeneous = false
    flow.remove(labels[1])
    flow.add(labels[1])
    wait_for { nodes(viewer).find { |node| node['type'] == 'grid' }['children'].last['props']['content'] == 'Cell 1' }
    expect(nodes(viewer).find { |node| node['type'] == 'grid' }['props']).to include('cols' => 2, 'homogeneous' => false, 'equal_rows' => false)
    [0, 25, '2'].each { |value| expect { flow.max_children_per_line = value }.to raise_error(gtk::UnsupportedOperation) }
    expect { flow.row_spacing = -1 }.to raise_error(gtk::UnsupportedOperation)
    expect { flow.selection_mode = :multiple }.to raise_error(gtk::UnsupportedOperation)
    expect(flow.max_children_per_line).to eq(2)
    flow.destroy
    expect { flow.max_children_per_line = 1 }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'publishes a bulk callback once while keeping model reads and sorted paths current' do
    model = gtk::ListStore.new(String, Integer)
    view = table(model)
    _window, page = show(view)
    viewer = connect(page, 'batch')
    expect(model).to receive(:begin_batch!).once.and_call_original
    expect(view).to receive(:model_will_change!).once.and_call_original
    expect(view).to receive(:model_changed!).once.and_call_original
    readback = Queue.new
    gtk.queue do
      200.times do |index|
        row = model.append
        row[0], row[1] = "Row #{index}", 200 - index
      end
      model.set_sort_column_id(1, :ascending)
      readback << [model.size, model.iter_first[0], model.iter_first.path.to_s]
    end
    drain_models
    expect(readback.pop(timeout: 1)).to eq([200, 'Row 199', '0'])
    wait_for { nodes(viewer).find { |node| node['type'] == 'table' }['props']['rows'].length == 200 }
  end

  it 'rolls back every staged model and removed iterator before publishing a rejected projection' do
    first, second = gtk::ListStore.new(String), gtk::ListStore.new(String)
    original, other = first.append, second.append
    original[0], other[0] = 'Original', 'Other'
    view = table(first)
    combo = gtk::ComboBox.new(second)
    show(view, combo)
    expect(view).not_to receive(:model_changed!)
    expect(combo).not_to receive(:model_changed!)
    handles = Queue.new
    gtk.queue do
      first.remove(original)
      added = first.append
      added[0] = 'Candidate'
      handles << added
      other[0] = 'x' * 513
    end
    drain_models
    expect(first.rows).to eq([original])
    expect(original[0]).to eq('Original')
    expect(first.iter_is_valid?(handles.pop(timeout: 1))).to be(false)
    expect(other[0]).to eq('Other')
    expect(Lich).to have_received(:log).with(/callback failed error=Lich::WebUI::SchemaViolationError/)
  end

  it 'flushes before widget reads and rolls back later writes when the callback raises' do
    model = gtk::ListStore.new(String)
    row = model.append
    row[0] = 'Before'
    view = table(model)
    label = gtk::Label.new('Barrier')
    show(view, label)
    publications = []
    allow(view).to receive(:model_changed!).and_wrap_original do |method|
      publications << row[0]
      method.call
    end
    gtk.queue do
      row[0] = 'Committed at read'
      label.text
      row[0] = 'Rolled back'
      raise 'abort this callback'
    end
    drain_models
    expect(publications).to eq(['Committed at read'])
    expect(row[0]).to eq('Committed at read')
    row[0] = 'Direct write'
    expect(publications.last).to eq('Direct write')
  end

  it 'repaints a failed edited callback only after its staged model mutation rolls back' do
    model = gtk::ListStore.new(String)
    row = model.append
    row[0] = 'Original'
    renderer = gtk::CellRendererText.new
    renderer.editable = true
    column = gtk::TreeViewColumn.new('Name', renderer, text: 0)
    view = gtk::TreeView.new(model)
    view.append_column(column)
    renderer.signal_connect('edited') do |_cell, path, value|
      model.get_iter(path)[0] = value
      raise 'edit aborted'
    end
    _window, page = show(view)
    viewer = connect(page, 'failed-editor')
    publications = []
    allow(view).to receive(:model_changed!).and_wrap_original do |method|
      publications << row[0]
      method.call
    end
    expect(send_event(page, viewer, :table, 'cell_edit', { row: row.key, column: column.key, value: 'Candidate' })).to eq(:queued)
    drain_models
    expect(row[0]).to eq('Original')
    expect(publications).to eq(['Original'])
    service.runtime.refresh(page)
    expect(nodes(viewer).find { |node| node['type'] == 'table' }['props']['rows'].first['cells'].values).to eq(['Original'])
  end

  it 'moves independent iterators without mutating rows and invalidates deleted handles' do
    store = gtk::ListStore.new(String, Integer)
    first = store.append
    first[0], first[1] = 'Alpha', 10
    second = store.append
    second[0], second[1] = 'Beta', 2
    walk = store.iter_first
    expect(walk.next!).to be(true)
    walk[0] = 'Changed'
    expect(first[0]).to eq('Alpha')
    expect(second[0]).to eq('Changed')
    store.set_sort_column_id(1, :ascending)
    expect(second.path.to_s).to eq('0')
    expect(first.path.to_s).to eq('1')
    deleting = store.get_iter('0')
    expect(store.remove(deleting)).to be(true)
    expect(deleting).to eq(first)
    expect { second[0] }.to raise_error(gtk::UnsupportedOperation, /iterator/)
    expect(deleting.next!).to be(false)
    expect(store.iter_is_valid?(deleting)).to be(false)
    expect(store.each.map { |_model, path, iter| [path.to_s, iter[0]] }).to eq([['0', 'Alpha']])
  end

  it 'keeps sibling paths and removes complete subtrees while preserving unrelated identities' do
    store = gtk::TreeStore.new(String)
    root = store.append
    root[0] = 'Parent'
    other = store.append
    other[0] = 'Other'
    child = store.append(root)
    child[0] = 'Child'
    grandchild = store.append(child)
    store.prepend(root)[0] = 'Before'
    expect(child.path.to_s).to eq('0:1')
    expect(grandchild.path.to_s).to eq('0:1:0')
    expect(store.iter_parent(grandchild)).to eq(child)
    expect(store.iter_n_children(root)).to eq(2)
    expect(store.iter_after(child)).to be_nil
    expect(store.remove(root)).to be(true)
    expect(root).to eq(other)
    expect(store.rows.map { |iter| iter[0] }).to eq(['Other'])
    expect(store.iter_is_valid?(grandchild)).to be(false)
  end

  it 'rejects malformed paths, foreign handles, unsupported types and aliased mutable strings' do
    store = gtk::ListStore.new(String, TrueClass)
    row = store.append
    text = +'original'
    row[0] = text
    text.replace('external')
    row[0].replace('copy')
    expect(row[0]).to eq('original')
    expect { row[-1] }.to raise_error(gtk::UnsupportedOperation)
    expect { row[1] = 'false' }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::ListStore.new(Object) }.to raise_error(gtk::UnsupportedOperation)
    expect { store.get_iter('-1') }.to raise_error(gtk::UnsupportedOperation)
    expect { store.get_iter('0:garbage') }.to raise_error(gtk::UnsupportedOperation)
    expect { store.remove(gtk::ListStore.new(String).append) }.to raise_error(gtk::UnsupportedOperation)
    expect { store.set_sort_func(0) {} }.to raise_error(gtk::UnsupportedOperation)
    expect(store.get_iter('20')).to be_nil
    store.clear
    expect(store.append.key).not_to eq(row.key)
  end

  it 'preserves nullable model strings while projecting blank table and combo labels' do
    model = gtk::ListStore.new(String, TrueClass)
    absent, blank, text = model.append, model.append, model.append
    expect(absent[0]).to be_nil
    blank[0], text[0] = '', 'Alpha'
    view = table(model)
    view.append_column(gtk::TreeViewColumn.new('Flag', gtk::CellRendererToggle.new, active: 1))
    combo = gtk::ComboBox.new(model)
    _window, page = show(view, combo)
    viewer = connect(page, 'nullable')
    expect(absent[0]).to be_nil
    expect(nodes(viewer).find { |node| node['type'] == 'table' }['props']['rows'].first['cells'].values).to eq(['', false])
    expect(nodes(viewer).find { |node| node['type'] == 'select' }['props']['options'].map { |option| option['label'] }).to eq(['', '', '', 'Alpha'])
    model.set_sort_column_id(0, gtk::SORT_ASCENDING)
    expect(model.rows.map { |iter| iter[0] }).to eq([nil, '', 'Alpha'])
    model.set_sort_column_id(0, :descending)
    expect(model.rows.map { |iter| iter[0] }).to eq(['Alpha', nil, ''])
    expect { absent[1] = nil }.to raise_error(gtk::ModelValueError, /column=1 expected=TrueClass actual=NilClass/)
  end

  it 'keeps long model metadata lossless and reports rejected boundaries without cell contents' do
    model = gtk::ListStore.new(String, String)
    row = model.append
    row[0] = 'Visible'
    row[1] = 'x' * gtk::ListStore::MAX_STRING_LENGTH
    _window, page = show(table(model))
    viewer = connect(page, 'metadata')
    expect(nodes(viewer).find { |node| node['type'] == 'table' }['props']['rows'].first['cells'].values).to eq(['Visible'])
    expect(row[1].length).to eq(65_536)
    expect { row[1] = 'private-content' * 5000 }.to raise_error(gtk::ModelValueError) do |error|
      expect(error.message).to include('column=1 expected=String actual=String length=75000 limit=65536')
      expect(error.message).not_to include('private-content')
    end
    expect(row[1].length).to eq(65_536)
    barrier = Queue.new
    gtk.queue { row[1] = 123 }
    gtk.queue { barrier << true }
    expect(barrier.pop(timeout: 3)).to be(true)
    expect(Lich).to have_received(:log).with(/callback failed.*column=1 expected=String actual=Integer length=n\/a limit=65536/)
  end

  it 'resolves sorted rows and paths without a whole-store search for each lookup' do
    store = gtk::ListStore.new(String, Integer)
    original = Array.new(40) { store.append }
    prepended = store.prepend
    inserted = store.insert(2)
    expected = [prepended, original.first, inserted, *original.drop(1)]
    # Every sort key is equal: descending must preserve explicit insert positions,
    # and its tie-breaker must not search the backing array for each comparison.
    store.set_sort_column_id(1, :descending)
    backing_rows = store.instance_variable_get(:@rows)
    %i[find select index any?].each { |method| expect(backing_rows).not_to receive(method) }
    expect(store.rows).to eq(expected)
    expected.each_with_index do |iter, index|
      expect(iter.path.to_s).to eq(index.to_s)
      expect(store.find_key(iter.key)).to eq(iter)
      expect(store.iter_is_valid?(iter)).to be(true)
      expect(iter[1]).to eq(0)
    end
  end

  it 'populates an unseen view without reading cells and reconciles retained row identities' do
    model = gtk::TreeStore.new(String)
    view = table(model)
    view.selection.mode = :browse
    expect(model).not_to receive(:get_value)
    first = model.append
    model.append(first)[0] = 'Child'
    last = model.append
    first[0] = 'Parent'
    expect(view.selection.selected).to eq(first)
    model.remove(model.find_key(first.key))
    expect(view.selection.selected).to eq(last)
    expect(view.instance_variable_get(:@handle)).to be_nil
  end

  it 'retains unseen combo and cell-editor bounds without projecting table cells' do
    model = gtk::ListStore.new(String)
    row = model.append
    row[0] = 'Small'
    table(model)
    combo = gtk::ComboBox.new(model)
    expect { row[0] = 'x' * 513 }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect(row[0]).to eq('Small')
    combo.destroy

    values = gtk::ListStore.new(String)
    values.append[0] = 'Small'
    renderer = gtk::CellRendererCombo.new
    renderer.model = model
    renderer.editable = true
    view = gtk::TreeView.new(values)
    view.append_column(gtk::TreeViewColumn.new('Choice', renderer, text: 0))
    expect(values).not_to receive(:get_value)
    expect { row[0] = 'x' * 513 }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect(row[0]).to eq('Small')
  end

  it 'restores indexed identities, subtree order and sort state after rejected mutations' do
    model = gtk::TreeStore.new(String)
    root = model.append
    root[0] = 'Zulu'
    child = model.append(root)
    child[0] = 'Child'
    other = model.prepend
    other[0] = 'Alpha'
    model.set_sort_column_id(0, :descending)
    expected = model.rows.map { |iter| [iter.key, iter.path.to_s, iter[0]] }
    observer = double(session: model.session, model_changed!: nil)
    allow(observer).to receive(:model_will_change!).and_raise('rejected candidate')
    model.watch(observer)
    [-> { root[0] = 'Changed' }, -> { model.prepend(root) },
     -> { model.remove(root) }, -> { model.clear },
     -> { model.set_sort_column_id(0, :ascending) }].each do |change|
      expect(&change).to raise_error('rejected candidate')
      expect(model.rows.map { |iter| [iter.key, iter.path.to_s, iter[0]] }).to eq(expected)
      expect(model.iter_parent(child)).to eq(root)
      expect(model.iter_is_valid?(root)).to be(true)
    end
    model.unwatch(observer)
    model.set_sort_column_id(-2)
    expect(model.rows).to eq([other, root, child])
  end

  it 'projects a live mutation once and never reuses a rejected candidate on repaint' do
    model = gtk::ListStore.new(String)
    row = model.append
    row[0] = 'Small'
    view = table(model)
    combo = gtk::ComboBox.new(model)
    _window, page = show(view, combo)
    viewer = connect(page, 'projection')
    projections = 0
    allow(view).to receive(:row_definitions).and_wrap_original do |original|
      projections += 1
      original.call
    end
    row[0] = 'Accepted'
    expect(projections).to eq(1)
    expect { row[0] = 'x' * 513 }.to raise_error(Lich::WebUI::SchemaViolationError)
    view.model_changed!
    wait_for do
      nodes(viewer).find { |node| node['type'] == 'table' }['props']['rows'].first['cells'].values == ['Accepted']
    end
    expect(row[0]).to eq('Accepted')
  end

  it 'keeps empty named IDs distinct from no selection and retires them with their model rows' do
    combo = gtk::ComboBoxText.new
    combo.append('', 'Same')
    combo.append('spell', 'Same')
    combo.append_text('Unnamed')
    expect(combo.active_id).to be_nil
    expect(combo.set_active_id('')).to be(true)
    expect([combo.active, combo.active_text, combo.active_id]).to eq([0, 'Same', ''])
    expect { combo.append('', 'Duplicate') }.to raise_error(gtk::UnsupportedOperation)
    expect(combo.model.rows.size).to eq(3)
    expect(combo.set_active_id('spell')).to be(true)
    expect(combo.set_active_id('missing')).to be(false)
    expect([combo.active, combo.active_id]).to eq([1, 'spell'])
    combo.active = 0
    expect(combo.active_id).to eq('')
    combo.active_id = nil
    expect([combo.active, combo.active_id]).to eq([-1, nil])
    combo.active = 2
    expect(combo.active_id).to be_nil
    combo.active_id = ''
    combo.remove(0)
    expect(combo.active_id).to be_nil
    expect(combo.set_active_id('')).to be(false)
    combo.append('', 'Replacement')
    combo.active_id = ''
    expect(combo.active_text).to eq('Replacement')
    combo.remove_all
    expect(combo.active_id).to be_nil
    combo.append('', 'Rebound')
    combo.model = gtk::ListStore.new(String)
    expect(combo.set_active_id('')).to be(false)
    combo.append('', 'New model')
    combo.active_id = ''
    expect(combo.active_text).to eq('New model')
    editable = gtk::ComboBoxText.new(entry: true)
    editable.append('', 'Placeholder')
    editable.child.text = 'Free text'
    expect(editable.active_id).to be_nil
    expect(editable.set_active_id('')).to be(true)
    expect(editable.child.text).to eq('Placeholder')
  end

  it 'round-trips an empty ID through viewer-local changes and a fresh attachment' do
    combo = gtk::ComboBoxText.new
    combo.append('', 'Placeholder')
    combo.append('spell', 'Spell')
    combo.active_id = 'spell'
    changed = []
    status = gtk::Label.new('Ready')
    combo.signal_connect('changed') do
      changed << [combo.active_id, combo.active_text]
      status.text = combo.active_text
    end
    _window, page = show(combo, status)
    viewer = connect(page, 'empty-id-choice')
    other = connect(page, 'other-choice')
    empty_key = combo.model.rows.first.key
    expect(empty_key).not_to eq('')
    expect(empty_key).not_to eq('none')
    expect(send_event(page, viewer, :select, 'change', { value: empty_key })).to eq(:queued)
    wait_for { changed == [['', 'Placeholder']] }
    selected = ->(connection) { nodes(connection).find { |node| node['type'] == 'select' }.dig('props', 'value') }
    wait_for { selected.call(viewer) == empty_key }
    expect(selected.call(other)).to eq(combo.model.rows[1].key)
    resume = viewer.messages.reverse.find { |message| message['type'] == 'render' }.fetch('resume')
    service.runtime.disconnect(viewer)
    reattached = connect(page, 'resumed-empty-id-choice', resume: resume)
    expect(selected.call(reattached)).to eq(empty_key)
  end

  it 'selects existing combo text rows and notifies changes once without inventing options' do
    combo = gtk::ComboBoxText.new
    %w[bronze iron bronze].each { |label| combo.append_text(label) }
    changed = []
    combo.signal_connect('changed') { changed << [combo.active, combo.active_text] }
    expect(combo.set_active_text('bronze')).to equal(combo)
    combo.active_text = 'bronze'
    expect(combo.active).to eq(0)
    expect(changed).to eq([[0, 'bronze']])
    choose = gtk::Button.new('Select iron')
    choose.signal_connect('clicked') { combo.active_text = 'iron' }
    _window, page = show(combo, choose)
    viewer = connect(page, 'material-choice')
    other = connect(page, 'other-material-choice')
    expect(send_event(page, viewer, :button, 'activate', {}, submission: [combo.model.rows.first.key])).to eq(:queued)
    wait_for { nodes(viewer).find { |node| node['type'] == 'select' }.dig('props', 'value') == combo.model.rows[1].key }
    expect(nodes(other).find { |node| node['type'] == 'select' }.dig('props', 'value')).to eq(combo.model.rows.first.key)
    expect(changed).to eq([[0, 'bronze'], [1, 'iron']])
    original = combo.send(:component_props).dup
    ['unknown', '', nil, 1, 'x' * 513].each do |value|
      expect { combo.active_text = value }.to raise_error(gtk::UnsupportedOperation)
      expect(combo.send(:component_props)).to eq(original)
    end
    expect(combo.model.rows.map { |row| row[0] }).to eq(%w[bronze iron bronze])
    expect(changed.size).to eq(2)
  end

  it 'selects real labels in editable combos while preserving literal free-text separation' do
    combo = gtk::ComboBoxText.new(entry: true)
    combo.append_text('bronze')
    combo.child.text = 'Custom'
    combo.active_text = 'bronze'
    expect(combo.active_iter.key).to eq(combo.model.iter_first.key)
    expect(combo.child.text).to eq('bronze')
    expect { combo.active_text = 'Missing' }.to raise_error(gtk::UnsupportedOperation)
    combo.child.text = 'Missing'
    expect(combo.active_iter).to be_nil
    expect(combo.active_text).to eq('Missing')
    combo.model = gtk::ListStore.new(String, Integer)
    combo.model.append[0] = 'bronze'
    expect { combo.active_text = 'bronze' }.to raise_error(gtk::UnsupportedOperation, /text_model/)
  end

  it 'reads shared tooltip metadata through combo and internal entry before, during and after display' do
    combo = gtk::ComboBoxText.new(entry: true)
    entry = combo.child
    expect(combo.tooltip_text).to be_nil
    expect(entry.get_tooltip_text).to be_nil
    combo.set_tooltip_text('Material help') unless combo.tooltip_text
    expect(entry.tooltip_text).to eq('Material help')
    window, _page = show(combo)
    entry.set_tooltip_text('Updated help')
    expect(combo.get_tooltip_text).to eq('Updated help')
    expect(entry.get_tooltip_text).to eq('Updated help')
    combo.has_tooltip = false
    expect(entry.tooltip_text).to eq('')
    window.destroy
    entry.tooltip_text = 'Retained help'
    expect(combo.tooltip_text).to eq('Retained help')
    expect(entry.tooltip_text).to eq('Retained help')
    regular = gtk::Entry.new
    expect(regular.tooltip_text).to be_nil
    regular.tooltip_text = 'Ordinary entry'
    expect(regular.get_tooltip_text).to eq('Ordinary entry')
  end

  it 'uses real combo model rows, duplicate labels and live label-column updates' do
    model = gtk::ListStore.new(String, String)
    first, second = model.append, model.append
    first[0], first[1] = 'hidden one', 'Same'
    second[0], second[1] = 'hidden two', 'Same'
    combo = gtk::ComboBox.new(model)
    renderer = gtk::CellRendererText.new
    combo.pack_start(renderer, true)
    combo.add_attribute(renderer, :text, 1)
    combo.active_iter = second
    expect(combo.active).to eq(1)
    expect(combo.active_iter[0]).to eq('hidden two')
    model.remove(first)
    expect(combo.active).to eq(0)
    expect(combo.active_text).to eq('Same')
    second[1] = 'Renamed'
    expect(combo.active_text).to eq('Renamed')
    replacement = gtk::ListStore.new(String, String)
    combo.model = replacement
    expect(combo.active).to eq(-1)
    expect(combo.active_iter).to be_nil
    second[1] = 'Old model only'
    expect(combo.send(:component_props)[:options]).to eq([{ value: 'none', label: '' }])
  end

  it 'supports legacy text-only and editable forms without adding a second input' do
    combo = gtk::ComboBox.new(true)
    combo.append_text('One')
    combo.active = 0
    expect(combo.model.get_iter('0')).to eq(combo.active_iter)
    editable = gtk::ComboBoxText.new(entry: true)
    editable.append_text('Choice')
    editable.active = 0
    expect(editable.child.text).to eq('Choice')
    editable.child.text = 'Custom'
    expect(editable.active).to eq(-1)
    expect(editable.child.text).to eq('Custom')
    expect(editable.active_text).to eq('Custom')
    editable.active = -1
    expect(editable.child.text).to eq('')
    _window, page = show(editable)
    expect(page.last_render.tree.each.count { |node| node.type == :select }).to eq(1)
    expect(page.last_render.tree.each.none? { |node| node.type == :text_input }).to be(true)
  end

  it 'keeps viewer selection and expansion separate and prunes rows removed from a shared model' do
    model = gtk::TreeStore.new(String)
    root = model.append
    root[0] = 'Parent'
    child = model.append(root)
    child[0] = 'Child'
    view = table(model)
    view.selection.mode = :multiple
    observed = Queue.new
    view.selection.signal_connect('changed') { observed << view.selection.selected_rows.first.map(&:to_s) }
    view.signal_connect('row-expanded') { |_view, iter, path| observed << [iter.key, path.to_s] }
    _window, page = show(view)
    first, second = connect(page, 'one'), connect(page, 'two')
    send_event(page, first, :table, 'selection_change', { rows: [root.key, child.key] })
    expect(observed.pop(timeout: 2)).to eq(['0', '0:0'])
    send_event(page, first, :table, 'row_toggle', { row: root.key, expanded: true })
    expect(observed.pop(timeout: 2)).to eq([root.key, '0'])
    service.runtime.refresh(page)
    wait_for { nodes(first).find { |node| node['type'] == 'table' }['props']['expanded'] == [root.key] }
    expect(nodes(second).find { |node| node['type'] == 'table' }['props']['selected']).to eq([])
    model.remove(model.get_iter('0:0'))
    wait_for { nodes(first).find { |node| node['type'] == 'table' }['props']['rows'].length == 1 }
    expect(nodes(first).find { |node| node['type'] == 'table' }['props']['selected']).to eq([root.key])
    expect(nodes(second).find { |node| node['type'] == 'table' }['props']['expanded']).to eq([])
  end

  it 'lets scripts reject text edits and toggle the old boolean exactly once' do
    model = gtk::ListStore.new(String, TrueClass)
    row = model.append
    row[0] = 'Keep'
    view = gtk::TreeView.new(model)
    text, toggle = gtk::CellRendererText.new, gtk::CellRendererToggle.new
    text.editable = true
    name = gtk::TreeViewColumn.new('Name', text, text: 0)
    flag = gtk::TreeViewColumn.new('Flag', toggle, active: 1)
    view.append_column(name)
    view.append_column(flag)
    observed = Queue.new
    text.signal_connect('edited') { |_cell, path, value| observed << [path, value, model.get_iter(path)[0]] }
    toggle.signal_connect('toggled') { |_cell, path| model.get_iter(path)[1] = !model.get_iter(path)[1]; observed << model.get_iter(path)[1] }
    _window, page = show(view)
    viewer = connect(page, 'editor')
    send_event(page, viewer, :table, 'cell_edit', { row: row.key, column: name.key, value: 'Rejected' })
    expect(observed.pop(timeout: 2)).to eq(['0', 'Rejected', 'Keep'])
    expect(row[0]).to eq('Keep')
    send_event(page, viewer, :table, 'cell_edit', { row: row.key, column: flag.key, value: true })
    expect(observed.pop(timeout: 2)).to be(true)
    expect(row[1]).to be(true)
  end

  it 'publishes a shared model into two views and detaches replacement/destruction observers' do
    first = gtk::ListStore.new(String)
    row = first.append
    row[0] = 'Shared'
    a, b = table(first), table(first)
    window, page = show(a, b)
    viewer = connect(page, 'shared')
    second = gtk::ListStore.new(String)
    second.append[0] = 'Replacement'
    a.model = second
    row[0] = 'Changed'
    wait_for do
      nodes(viewer).select { |node| node['type'] == 'table' }.map { |node| node['props']['rows'].first['cells'].values.first } == ['Replacement', 'Changed']
    end
    window.destroy
    expect(first.instance_variable_get(:@observers)).to be_empty
    expect(second.instance_variable_get(:@observers)).to be_empty
    expect { row[0] = 'After close' }.not_to raise_error
  end

  it 'rejects an incompatible model update before changing any attached view' do
    model = gtk::ListStore.new(String)
    row = model.append
    row[0] = 'Small'
    view = table(model)
    combo = gtk::ComboBox.new(model)
    _window, page = show(view, combo)
    viewer = connect(page, 'limits')
    expect { row[0] = 'x' * 513 }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect(row[0]).to eq('Small')
    expect(nodes(viewer).find { |node| node['type'] == 'select' }['props']['options'].last['label']).to eq('Small')
    expect(nodes(viewer).find { |node| node['type'] == 'table' }['props']['rows'].first['cells'].values).to eq(['Small'])
    combo.destroy
    expect { row[0] = 'x' * 513 }.not_to raise_error
  end

  it 'reads unset editable combo labels as blank without exposing row IDs to callbacks' do
    model = gtk::ListStore.new(String)
    row = model.append
    combo = gtk::ComboBox.new(model, entry: true)
    combo.active = 0
    expect([combo.child.text, combo.active_text, row[0]]).to eq(['', '', nil])

    row[0] = 'Assigned'
    expect([combo.child.text, combo.active_text]).to eq(['Assigned', 'Assigned'])
    combo.child.text = "text:#{row.key}"
    expect([combo.child.text, combo.active_text]).to eq(["text:#{row.key}", "text:#{row.key}"])
    expect(combo.active_iter).to be_nil

    row[0] = nil
    _window, page = show(combo)
    viewer = connect(page, 'unset-label')
    changed = Queue.new
    combo.child.signal_connect('changed') { |entry| changed << [entry.text, combo.active_text] }
    expect(send_event(page, viewer, :select, 'change', { value: row.key })).to eq(:queued)
    expect(changed.pop(timeout: 2)).to eq(['', ''])
    expect(row[0]).to be_nil
  end

  %i[max_length= set_max_length].each do |setter|
    it "refuses internal combo entry #{setter} without changing text or emitting changed" do
      combo = gtk::ComboBoxText.new(entry: true)
      combo.child.text = 'Existing text'
      changed = []
      combo.child.signal_connect('changed') { |entry| changed << entry.text }
      before = combo.send(:component_props).dup

      [0, 3].each do |limit|
        expect { combo.child.public_send(setter, limit) }.to raise_error(gtk::UnsupportedOperation, /max_length=/)
        expect(combo.child.text).to eq('Existing text')
        expect(combo.send(:component_props)).to eq(before)
        expect(changed).to be_empty
      end

      combo.child.text = 'Subsequent text'
      expect(combo.child.text).to eq('Subsequent text')
      expect(changed).to eq(['Subsequent text'])
    end
  end

  it 'keeps editable free text distinct from IDs and preserves it while choices change' do
    combo = gtk::ComboBoxText.new(entry: true)
    combo.append_text('Choice')
    combo.child.text = 'none'
    expect(combo.child.text).to eq('none')
    expect(combo.active_iter).to be_nil
    combo.child.text = combo.model.iter_first.key
    expect(combo.active_iter).to be_nil
    _window, page = show(combo)
    a, b = connect(page, 'a'), connect(page, 'b')
    changed = Queue.new
    combo.signal_connect('changed') { changed << combo.child.text }
    send_event(page, a, :select, 'change', { value: 'text:Custom' })
    expect(changed.pop(timeout: 2)).to eq('Custom')
    send_event(page, b, :select, 'change', { value: combo.model.iter_first.key })
    expect(changed.pop(timeout: 2)).to eq('Choice')
    combo.model.remove(combo.model.iter_first)
    wait_for { nodes(b).find { |node| node['type'] == 'select' }['props']['options'].length == 1 }
    expect(nodes(a).find { |node| node['type'] == 'select' }['props']['value']).to eq('text:Custom')
    # A removed choice clears, while a literal entry survives that same model update.
    expect(nodes(b).find { |node| node['type'] == 'select' }['props']['value']).to eq('none')
  end

  [
    ['matching text', ['Choice', 'Choice'], 'Choice', 0],
    ['empty text', ['Choice'], '', -1],
    ['an empty option label', ['', 'Choice'], '', 0],
    ['an existing duplicate-label selection', ['Choice', 'Choice'], 1, 1],
    ['an existing empty selection', ['Choice'], -1, -1]
  ].each do |description, labels, initial, expected_index|
    it "preserves #{description} when closing an editable combo before publication" do
      combo = gtk::ComboBoxText.new(entry: true)
      labels.each { |label| combo.append_text(label) }
      initial.is_a?(String) ? combo.child.text = initial : combo.active = initial

      combo.child.editable = false

      expect(combo.active).to eq(expected_index)
      expect(combo.child.text).to eq(expected_index == -1 ? '' : labels[expected_index])
      _window, page = show(combo)
      viewer = connect(page, 'closed-combo')
      props = nodes(viewer).find { |node| node['type'] == 'select' }.fetch('props')
      expect(props['editable']).to be(false)
      expect(props).not_to have_key('free_text_prefix')
      expect(props['value']).to eq(expected_index == -1 ? 'none' : combo.model.rows[expected_index].key)
      expect { combo.child.editable = true }.to raise_error(gtk::UnsupportedOperation)
    end
  end

  %i[editable= set_editable].each do |setter|
    it "routes #{setter} through the combo's presentation and publication rules" do
      combo = gtk::ComboBoxText.new(entry: true)
      combo.append_text('Choice')
      combo.child.text = 'Choice'
      combo.child.public_send(setter, false)
      expect(combo.active).to eq(0)
      _window, page = show(combo)
      viewer = connect(page, 'setter-form')
      expect(nodes(viewer).find { |node| node['type'] == 'select' }['props']['editable']).to be(false)
      expect { combo.child.public_send(setter, true) }.to raise_error(gtk::UnsupportedOperation, /entry_editable=/)
    end
  end

  it 'uses the current combo presentation for focus even when its entry facade survives' do
    combo = gtk::ComboBoxText.new(entry: true)
    expect { combo.can_focus = true }.to raise_error(gtk::UnsupportedOperation)
    expect { combo.can_focus = false }.not_to raise_error
    combo.child.editable = false
    expect(combo.has_entry?).to be(true)
    expect { combo.can_focus = true }.not_to raise_error
    expect { combo.can_focus = false }.not_to raise_error
    expect { combo.can_focus = nil }.to raise_error(gtk::UnsupportedOperation)
    combo.child.editable = true
    expect { combo.can_focus = true }.to raise_error(gtk::UnsupportedOperation)
    expect { combo.can_focus = false }.not_to raise_error
    closed = gtk::ComboBoxText.new
    expect { closed.can_focus = true }.not_to raise_error
    expect { closed.can_focus = false }.not_to raise_error
  end

  it 'refuses unmatched text before changing combo editability or its value' do
    combo = gtk::ComboBoxText.new(entry: true)
    combo.append_text('Choice')
    combo.child.text = 'Unknown'
    before = combo.send(:component_props).dup

    expect { combo.child.editable = false }.to raise_error(gtk::UnsupportedOperation, /entry_editable=/)

    expect(combo.send(:component_props)).to eq(before)
    expect(combo.child.text).to eq('Unknown')
    expect(combo.active).to eq(-1)
    _window, page = show(combo)
    viewer = connect(page, 'still-editable')
    expect(nodes(viewer).find { |node| node['type'] == 'select' }['props']).to include(
      'editable' => true, 'free_text_prefix' => 'text:', 'value' => 'text:Unknown'
    )
  end

  it 'can reopen a closed combo before publication and assign free text' do
    combo = gtk::ComboBoxText.new(entry: true)
    combo.append_text('Choice')
    combo.child.text = 'Choice'
    combo.child.editable = false
    combo.child.editable = true
    expect(combo.active).to eq(0)
    combo.child.text = 'Custom'
    _window, page = show(combo)
    viewer = connect(page, 'reopened-combo')
    expect(nodes(viewer).find { |node| node['type'] == 'select' }['props']).to include(
      'editable' => true, 'free_text_prefix' => 'text:', 'value' => 'text:Custom'
    )
  end

  it 'reconciles only undelivered input changes before Save in the submitting viewer' do
    combo = gtk::ComboBoxText.new
    combo.append_text('First')
    combo.append_text('Second')
    combo.active = 0
    first, second = combo.model.rows.map(&:key)
    spin = gtk::SpinButton.new(0, 100, 1)
    save = gtk::Button.new('Save')
    events = Queue.new
    combo.signal_connect('changed') { events << [:combo, combo.active_text] }
    spin.signal_connect('value_changed') { events << [:spin, spin.value] }
    save.signal_connect('clicked') { events << [:save, combo.active_text, spin.value] }
    _window, page = show(combo, spin, save)
    a, b = connect(page, 'a'), connect(page, 'b')

    send_event(page, a, :select, 'change', { value: second })
    expect(events.pop(timeout: 2)).to eq([:combo, 'Second'])
    send_event(page, a, :button, 'activate', {}, submission: [second, 90])
    expect(events.pop(timeout: 2)).to eq([:spin, 90])
    expect(events.pop(timeout: 2)).to eq([:save, 'Second', 90])
    expect(events).to be_empty

    # B still has its initial option and spin value. Reconciliation must compare
    # with B's accepted inputs, not A's terminal shadow state.
    send_event(page, b, :button, 'activate', {}, submission: [first, 75])
    expect(events.pop(timeout: 2)).to eq([:spin, 75])
    expect(events.pop(timeout: 2)).to eq([:save, 'First', 75])
    expect(events).to be_empty
  end

  it 'targets programmatic expansion and cursor updates to the callback viewer and retains them on Save' do
    model = gtk::TreeStore.new(String)
    root = model.append
    child = model.append(root)
    root[0], child[0] = 'Parent', 'Child'
    view = table(model)
    action = gtk::Button.new('Expand')
    saved = Queue.new
    action.signal_connect('clicked') do
      view.expand_all
      view.set_cursor('0:0', view.columns.first)
      saved << [view.cursor.first.to_s, view.row_expanded?('0')]
    end
    window, page = show(view, action)
    a, b = connect(page, 'a'), connect(page, 'b')
    send_event(page, a, :button, 'activate', {}, submission: [])
    expect(saved.pop(timeout: 2)).to eq(['0:0', true])
    wait_for { nodes(a).find { |node| node['type'] == 'table' }['props']['cursor']['row'] == child.key }
    expect(nodes(b).find { |node| node['type'] == 'table' }['props']['cursor']).to eq({})
    expect(nodes(b).find { |node| node['type'] == 'table' }['props']['expanded']).to eq([])
    # The next terminal callback commits the viewer's final table state before destruction.
    action.signal_connect('clicked') { window.destroy }
    send_event(page, a, :button, 'activate', {}, submission: [])
    saved.pop(timeout: 2)
    wait_for { window.destroyed? }
    expect(view.selection.selected).to eq(child)
    expect(view.cursor.first.to_s).to eq('0:0')
    expect(view.row_expanded?('0')).to be(true)
  end

  it 'sorts numeric model columns while activation resolves the stable row and actual column' do
    model = gtk::ListStore.new(String, Integer)
    ten, two = model.append, model.append
    ten[0], ten[1], two[0], two[1] = 'Ten', 10, 'Two', 2
    view = table(model)
    number = gtk::TreeViewColumn.new('Number', gtk::CellRendererText.new, text: 1)
    number.sort_column_id = 1
    view.append_column(number)
    activated = Queue.new
    view.signal_connect('row-activated') { |_view, path, column| activated << [path.to_s, column] }
    _window, page = show(view)
    viewer = connect(page, 'sort')
    send_event(page, viewer, :table, 'sort_change', { column: number.key, direction: 'asc' })
    wait_for { model.iter_first == two }
    wait_for { nodes(viewer).find { |node| node['type'] == 'table' }['props']['rows'].first['key'] == two.key }
    send_event(page, viewer, :table, 'row_activate', { row: ten.key, column: number.key }, submission: [])
    expect(activated.pop(timeout: 2)).to eq(['1', number])
    expect(ten[1]).to eq(10)
  end

  it 'binds choice editors to live models without committing before the edited handler' do
    values = gtk::ListStore.new(String)
    values.append[0] = 'Old'
    options = gtk::ListStore.new(String)
    options.append[0] = 'New'
    renderer = gtk::CellRendererCombo.new
    renderer.model = options
    renderer.text_column = 0
    renderer.has_entry = false
    renderer.editable = true
    view = gtk::TreeView.new(values)
    column = gtk::TreeViewColumn.new('Choice', renderer, text: 0)
    view.append_column(column)
    observed = Queue.new
    renderer.signal_connect('edited') { |_renderer, path, text| observed << [values.get_iter(path)[0], text]; values.get_iter(path)[0] = text }
    window, page = show(view)
    viewer = connect(page, 'choices')
    send_event(page, viewer, :table, 'cell_edit', { row: values.iter_first.key, column: column.key, value: 'New' })
    expect(observed.pop(timeout: 2)).to eq(['Old', 'New'])
    later = options.append
    wait_for { nodes(viewer).find { |node| node['type'] == 'table' }['props']['columns'].first['editor']['options'].last == { 'value' => '', 'label' => '' } }
    expect(later[0]).to be_nil
    later[0] = 'Later'
    wait_for { nodes(viewer).find { |node| node['type'] == 'table' }['props']['columns'].first['editor']['options'].last['label'] == 'Later' }
    window.destroy
    expect(options.instance_variable_get(:@observers)).to be_empty
  end

  it 'implements browse selection and refuses foreign ownership and unsupported presentation' do
    model = gtk::ListStore.new(String)
    row = model.append
    view = table(model)
    view.selection.mode = :browse
    expect(view.selection.selected).to eq(row)
    view.selection.unselect_all
    expect(view.selection.selected).to eq(row)
    view.selection.mode = :none
    expect(view.selection.selected).to be_nil
    expect { view.selection.select_iter(row) }.to raise_error(gtk::UnsupportedOperation)
    expect { view.set_cursor('0', nil, true) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::TreeViewColumn.new('Rich', gtk::CellRendererText.new, markup: 0) }.to raise_error(gtk::UnsupportedOperation)
    foreign = gtk::ListStore.new(String)
    foreign.instance_variable_set(:@session, Object.new)
    expect { view.model = foreign }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::ComboBox.new(foreign) }.to raise_error(gtk::UnsupportedOperation)
    expect(view.model).to equal(model)
  end

  it 'returns selected paths before their model and iterates selections in model order' do
    model = gtk::ListStore.new(String)
    first, second = model.append, model.append
    first[0], second[0] = 'Alpha', 'Beta'
    view = table(model)
    view.selection.mode = :multiple
    view.selection.select_iter(second)
    view.selection.select_iter(first)
    paths, selected_model = view.selection.selected_rows
    expect(paths.map(&:to_s)).to eq(%w[0 1])
    expect(selected_model).to equal(model)
    expect(view.selection.selected_each.map { |_store, _path, iter| iter[0] }).to eq(%w[Alpha Beta])
    model.set_sort_column_id(0, :descending)
    expect(view.selection.selected_each.map { |_store, _path, iter| iter[0] }).to eq(%w[Beta Alpha])
  end

  it 'allows a mixed-column combo model to be configured before requiring its text mapping' do
    model = gtk::ListStore.new(Integer, String)
    row = model.append
    row[0], row[1] = 7, 'Seven'
    combo = gtk::ComboBox.new(model)
    expect { combo.materialize }.to raise_error(gtk::UnsupportedOperation, /text_column/)
    renderer = gtk::CellRendererText.new
    combo.pack_start(renderer, true)
    combo.set_attributes(renderer, text: 1)
    combo.active_iter = row
    expect(combo.active_text).to eq('Seven')
    expect(combo.active_iter[0]).to eq(7)
    expect { show(combo) }.not_to raise_error
  end
  it 'projects literal cell backgrounds live and clears them without changing model data' do
    model = gtk::ListStore.new(String)
    model.append[0] = 'Original'
    renderer = gtk::CellRendererText.new
    renderer.background = 'white'
    view = gtk::TreeView.new(model)
    column = gtk::TreeViewColumn.new('Name', renderer, text: 0)
    view.append_column(column)
    _window, page = show(view)
    viewer = connect(page, 'cell-colors')
    expect(column.definition[:background]).to eq(r: 255, g: 255, b: 255, a: 1.0)
    renderer.set_property('background', '#112233')
    wait_for { nodes(viewer).find { |node| node['type'] == 'table' }['props']['columns'][0]['background'] == { 'r' => 17, 'g' => 34, 'b' => 51, 'a' => 1.0 } }
    renderer.background = nil
    wait_for { !nodes(viewer).find { |node| node['type'] == 'table' }['props']['columns'][0].key?('background') }
    expect(model.iter_first[0]).to eq('Original')
    expect { renderer.background = 'url(https://invalid.example/)' }.to raise_error(gtk::UnsupportedOperation)
    expect(renderer.background_color).to be_nil
    allow(Lich::Common::Script).to receive(:current).and_return(Struct.new(:name).new('foreign'))
    expect { renderer.background = 'white' }.to raise_error(gtk::UnsupportedOperation)
  ensure
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
  end

  it 'delivers Switch active notifications with current viewer state and ordered programmatic changes' do
    switch = gtk::Switch.new
    notifications = []
    switch.signal_connect('notify::active') { |source, property| notifications << [source.active?, property.name] }
    switch.set_active(true)
    switch.active = true
    expect(notifications).to eq([[true, 'active']])
    expect { switch.active = 1 }.to raise_error(gtk::UnsupportedOperation)
    expect { switch.signal_connect('state-set') {} }.to raise_error(gtk::UnsupportedOperation)
    _window, page = show(switch)
    viewer = connect(page, 'switch')
    expect(nodes(viewer).find { |node| node['type'] == 'toggle' }['props']).to include('appearance' => 'switch', 'checked' => true)
    send_event(page, viewer, :toggle, 'change', { value: false })
    wait_for { notifications.length == 2 }
    expect(notifications.last).to eq([false, 'active'])
    switch.active = true
    expect(notifications.last).to eq([true, 'active'])
    expect(switch.active?).to be(true)
  end

  it 'honors boolean background bindings and warns once for invalid optional source bindings' do
    model = gtk::ListStore.new(String, TrueClass)
    row = model.append
    row[0], row[1] = 'Bound', false
    renderer = gtk::CellRendererText.new
    renderer.background = 'white'
    column = gtk::TreeViewColumn.new('Name', renderer, text: 0, background_set: 1)
    view = gtk::TreeView.new(model)
    view.append_column(column)
    _window, page = show(view)
    viewer = connect(page, 'background-binding')
    definition = -> { nodes(viewer).find { |node| node['type'] == 'table' }['props']['rows'][0] }
    expect(definition.call['background_disabled']).to eq([column.key])
    row[1] = true
    drain_models
    wait_for { !definition.call.key?('background_disabled') }
    invalid = gtk::TreeViewColumn.new('Bad binding', renderer, text: 0, background_set: 2)
    invalid_view = gtk::TreeView.new(model)
    invalid_view.append_column(invalid)
    2.times { invalid_view.columns_changed! }
    expect(invalid.background_enabled?(row)).to be(true)
    expect(Lich).to have_received(:log).with(/background_set.*expected boolean/).once
    expect { gtk::TreeViewColumn.new('CSS', renderer, text: 0, background: 1) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::TreeViewColumn.new('Huge index', renderer, text: 0, background_set: 2**80) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'dispatches bounded widget moves with measured insertion geometry and guaranteed drag cleanup' do
    source, target = gtk::EventBox.new, gtk::Box.new(:vertical)
    source.add(gtk::Label.new('Spirit Barrier'))
    child = gtk::Label.new('Existing ability')
    target.add(child)
    descriptor = gtk::TargetEntry.new('text/plain', :same_app, 0)
    source.drag_source_set(:button1, [descriptor], :move)
    target.drag_dest_set(gtk::DestDefaults::MOTION | gtk::DestDefaults::HIGHLIGHT, [descriptor], :move)
    calls = []
    source.signal_connect('drag-begin') { calls << :begin }
    source.signal_connect('drag-end') { calls << :end }
    target.signal_connect('drag-motion') { |_w, _ctx, x, y| calls << [:motion, x, y, child.allocation.y, child.allocation.height] }
    target.signal_connect('drag-drop') { calls << :drop }
    target.signal_connect('drag-leave') { calls << :leave }
    box = gtk::Box.new(:vertical)
    box.add(source); box.add(target)
    _window, page = show(box)
    viewer = connect(page, 'widget-transfer')
    from = nodes(viewer).find { |node| node['props']['drag_source'] }
    to = nodes(viewer).find { |node| node['props']['drag_destination'] }
    payload = { source: from['cid'], x: 12, y: 25, allocations: [{ cid: to['children'][0]['cid'], y: 10, height: 30 }] }
    deliver = lambda do |proposed|
      render = viewer.messages.reverse.find { |message| message['type'] == 'render' }
      service.runtime.handle(viewer, type: 'event', page: service.registry.address_for(page), generation: render['generation'],
                             cid: to['cid'], event: 'widget_drop', payload: proposed)
      drain_models
    end
    deliver.call(payload.merge(allocations: []))
    deliver.call(payload.merge(source: to['cid']))
    deliver.call(payload.merge(x: 65_537))
    deliver.call(payload.merge(allocations: [{ cid: to['children'][0]['cid'], y: 0, height: 65_537 }]))
    expect(calls).to be_empty
    deliver.call(payload)
    expect(calls).to eq([:begin, [:motion, 12, 25, 10, 30], :drop, :leave, :end])
    expect(child.instance_variable_defined?(:@transfer_allocation)).to be(false)
    data = gtk::SelectionData.new
    data.set_text('Spirit Barrier')
    expect(data.text).to eq('Spirit Barrier')
    calls.clear
    admitted = page.last_render
    previous_binding = admitted.bindings[[to['cid'], :widget_drop]]
    target.signal_connect('drag-drop') { raise 'drop callback failed' }
    retired_context = Lich::WebUI::Runtime::EventContext.new(
      nil, page, admitted.tree.each.find { |node| node.cid == to['cid'] }, :widget_drop, payload, nil, admitted
    )
    expect { previous_binding.call(retired_context) }.to raise_error(gtk::UnsupportedOperation, /operation=widget_drop/)
    expect(calls).to be_empty
    wait_for { !page.last_render.bindings[[to['cid'], :widget_drop]].equal?(previous_binding) }
    deliver.call(payload)
    expect(calls.last(2)).to eq([:leave, :end])
    expect(child.instance_variable_defined?(:@transfer_allocation)).to be(false)
    calls.clear
    source.sensitive = false
    wait_for { nodes(viewer).find { |node| node['cid'] == from['cid'] }['props']['disabled'] }
    deliver.call(payload)
    expect(calls).to be_empty
    source.sensitive = true
    source.hide
    wait_for { nodes(viewer).find { |node| node['cid'] == from['cid'] }['props']['hidden'] }
    deliver.call(payload)
    expect(calls).to be_empty
  end

  [[:manual, 'Ability'], [:received, 'Ability'], [:received, ''], [:received, nil],
   [:received, 'x' * 8193], [:disconnected, 'Ability'], [:failure, 'Ability']].each do |mode, text|
    it "delivers bounded source-owned widget data with cleanup for #{mode}/#{text&.length.inspect}" do
      source, target = gtk::EventBox.new, gtk::Box.new(:vertical)
      child = gtk::Label.new('Existing')
      target.add(child)
      descriptor = gtk::TargetEntry.new('text/plain', :same_app, 0)
      source.drag_source_set(:button1, [descriptor], :move)
      target.drag_dest_set(1, [descriptor], :move)
      box = gtk::Box.new(:vertical)
      box.add(source); box.add(target)
      calls, moves, data_objects = [], [], []
      source.signal_connect('drag-begin') { calls << :begin }
      source.signal_connect('drag-data-get') do |_widget, _context, data, info, time|
        calls << [:get, info, time]
        data_objects << data
        data.set_text(text) unless text.nil?
      end
      target.signal_connect('drag-drop') do
        calls << :drop
        if mode == :manual
          source.parent.remove(source)
          target.add(source)
          moves << :manual
        end
      end
      receiver = target.signal_connect('drag-data-received') do |_widget, _context, x, y, data, info, time|
        calls << [:received, x, y, data.text, info, time]
        expect(data).to equal(data_objects.last)
        raise 'receiver failure' if mode == :failure
        if mode == :received
          source.parent.remove(source)
          target.add(source)
          moves << :received
        end
      end
      target.send(:disconnect_signal_handler, receiver) if mode == :disconnected
      target.signal_connect('drag-leave') { calls << :leave }
      source.signal_connect('drag-end') { calls << :end }
      _window, page = show(box)
      viewer = connect(page, "widget-data-#{mode}")
      from = nodes(viewer).find { |node| node['props']['drag_source'] }
      to = nodes(viewer).find { |node| node['props']['drag_destination'] }
      render = viewer.messages.reverse.find { |message| message['type'] == 'render' }
      service.runtime.handle(viewer, type: 'event', page: service.registry.address_for(page), generation: render['generation'],
                             cid: to['cid'], event: 'widget_drop', payload: { source: from['cid'], x: 12, y: 25,
                                                                                 allocations: [{ cid: to['children'][0]['cid'], y: 10, height: 30 }] })
      drain_models
      expected = [:begin, [:get, 0, 0]]
      expected << :drop unless text && text.length > 8192
      expected << [:received, 12, 25, text, 0, 0] if text && text.length <= 8192 && mode != :disconnected
      expect(calls).to eq(expected + [:leave, :end])
      expect(moves).to eq((mode == :manual || (mode == :received && text && text.length <= 8192)) ? [mode] : [])
      expect(child.instance_variable_defined?(:@transfer_allocation)).to be(false)
    end
  end

  it 'retires source and destination authority when live shadow drag handlers change' do
    source, target = gtk::EventBox.new, gtk::Box.new(:vertical)
    descriptor = gtk::TargetEntry.new('text/plain', :same_app, 0)
    source.drag_source_set(:button1, [descriptor], :move)
    target.drag_dest_set(1, [descriptor], :move)
    box = gtk::Box.new(:vertical)
    box.add(source); box.add(target)
    target_handler = target.signal_connect('drag-drop') {}
    _window, page = show(box)
    viewer = connect(page, 'transfer-authority')
    source_key = -> { nodes(viewer).find { |node| node['props']['drag_source'] }['props']['drag_source'] }
    original = source_key.call
    admitted = page.last_render
    before_source, before_target = admitted.tree.each.select { |node| node.props[:drag_source] || node.props[:drag_destination] }
    old_context = Lich::WebUI::Runtime::EventContext.new(
      nil, page, before_target, :widget_drop, { source: before_source.cid, x: 1, y: 1, allocations: [] }, nil, admitted
    )
    id = source.signal_connect('drag-data-get') { |_widget, _context, data| data.set_text('New source') }
    expect { target.send(:dispatch_widget_drop, old_context) }.to raise_error(gtk::UnsupportedOperation, /operation=widget_drop/)
    wait_for { source_key.call != original }
    connected = source_key.call
    source.send(:disconnect_signal_handler, id)
    wait_for { source_key.call != connected }
    target_cid = nodes(viewer).find { |node| node['props']['drag_destination'] }['cid']
    original_binding = page.last_render.bindings[[target_cid, :widget_drop]]
    target.send(:disconnect_signal_handler, target_handler)
    wait_for { !page.last_render.bindings[[target_cid, :widget_drop]].equal?(original_binding) }
  end

  it 'refuses widget transfer protocols outside their owner, types and lifecycle' do
    source = gtk::EventBox.new
    target = gtk::Box.new(:vertical)
    descriptor = gtk::TargetEntry.new('text/plain', :same_app, 0)
    expect { gtk::TargetEntry.new('text/uri-list', :same_app, 0) }.to raise_error(gtk::UnsupportedOperation)
    expect { source.drag_source_set(:button3, [descriptor], :move) }.to raise_error(gtk::UnsupportedOperation)
    expect { target.drag_dest_set(8, [descriptor], :move) }.to raise_error(gtk::UnsupportedOperation)
    expect { target.drag_dest_set(1, [descriptor], :copy) }.to raise_error(gtk::UnsupportedOperation)
    expect { source.signal_connect('drag-begin') {} }.to raise_error(gtk::UnsupportedOperation)
    target.drag_dest_set(1, [descriptor], :move)
    show(target)
    expect { target.drag_dest_set(1, [descriptor], :move) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(Struct.new(:name).new('foreign'))
    expect { source.drag_source_set(:button1, [descriptor], :move) }.to raise_error(gtk::UnsupportedOperation)
  end

  %i[instance module].each do |spelling|
    it "routes #{spelling} legacy text drags through source-owned callbacks once" do
      original = gtk::ListStore.new(String, String)
      moved = original.append
      moved[0], moved[1] = '102', 'Spirit Barrier'
      destination = gtk::ListStore.new(String, String)
      source, target = [original, destination].map { |model| table(model) }
      [source, target].each do |view|
        if spelling == :instance
          view.drag_source_set(:button1_mask, [['text/plain', :same_app, 0]], :move)
          view.drag_dest_set(:all, [['text/plain', :same_app, 0]], :move)
        else
          gdk = scope.const_get(:Gdk)
          gtk::Drag.source_set(view, gdk::Window::BUTTON1_MASK, [['text/plain', gtk::Drag::TARGET_SAME_APP, 0]], gdk::DragContext::ACTION_MOVE)
          gtk::Drag.dest_set(view, gtk::Drag::DEST_DEFAULT_ALL, [['text/plain', gtk::Drag::TARGET_SAME_APP, 0]], gdk::DragContext::ACTION_MOVE)
        end
      end
      calls = []
      source.signal_connect('drag-data-get') do |view, _context, data|
        calls << :get
        data.text = view.selection.selected[0]
      end
      target.signal_connect('drag-data-received') do |_view, _context, _x, _y, data|
        calls << [:received, data.text]
        original.each do |_model, _path, row|
          next unless row[0] == data.text
          fresh = destination.append
          fresh[0], fresh[1] = row[0], row[1]
          original.remove(row)
          break
        end
      end
      box = gtk::HBox.new
      box.add(source); box.add(target)
      _window, page = show(box)
      viewer = connect(page, "drop-#{spelling}")
      tables = nodes(viewer).select { |node| node['type'] == 'table' }
      from = tables.find { |node| node['props']['rows'].any? }
      to = tables.find { |node| node != from }
      row_key = from['props']['rows'][0]['key']
      deliver = lambda do
        render = viewer.messages.reverse.find { |message| message['type'] == 'render' }
        service.runtime.handle(viewer, type: 'event', page: service.registry.address_for(page), generation: render['generation'],
                               cid: to['cid'], event: 'row_drop', payload: { source: from['cid'], row: row_key })
        drain_models
      end
      expect(calls).to be_empty
      deliver.call
      expect(calls).to eq([:get, [:received, '102']])
      expect(original.size).to eq(0)
      expect(destination.rows.map { |row| [row[0], row[1]] }).to eq([['102', 'Spirit Barrier']])
      wait_for { nodes(viewer).find { |node| node['cid'] == from['cid'] }['props']['rows'].empty? }
      deliver.call
      expect(calls).to eq([:get, [:received, '102']])
      expect(viewer.messages.any? { |message| message['type'] == 'refusal' }).to be(true)
    end
  end

  it 'refuses foreign or unsafe legacy transfer registrations and bounds SelectionData writes' do
    view = table(gtk::ListStore.new(String))
    targets = [['text/plain', :same_app, 0]]
    expect { view.drag_source_set(:button3_mask, targets, :move) }.to raise_error(gtk::UnsupportedOperation)
    expect { view.drag_source_set(:button1_mask, [['text/uri-list', :same_app, 0]], :move) }.to raise_error(gtk::UnsupportedOperation)
    expect { view.drag_source_set(:button1_mask, [['text/plain', :other_app, 0]], :move) }.to raise_error(gtk::UnsupportedOperation)
    expect { view.drag_source_set(:button1_mask, targets, :copy) }.to raise_error(gtk::UnsupportedOperation)
    expect { view.drag_dest_set(:motion, targets, :move) }.to raise_error(gtk::UnsupportedOperation)
    data = gtk::SelectionData.new
    text = +'102'
    data.text = text
    text.replace('changed')
    expect(data.text).to eq('102')
    expect(data.text).to be_frozen
    expect { data.text = 'x' * 8193 }.to raise_error(gtk::UnsupportedOperation)
    expect { data.text = [255].pack('C').force_encoding('UTF-8') }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(Struct.new(:name).new('foreign'))
    expect { view.drag_source_set(:button1_mask, targets, :move) }.to raise_error(gtk::UnsupportedOperation)
    expect { data.text = '101' }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    view.destroy
    expect { view.drag_dest_set(:all, targets, :move) }.to raise_error(gtk::UnsupportedOperation)
    event = gtk::PointerEvent.new(x: 0, y: 0, button: 1, time: 0, state: 0)
    expect(event.event_type).to eq(:button_press)
    double_press = gtk::PointerEvent.new(x: 0, y: 0, button: 1, time: 1, state: 0, click_count: 2)
    expect(double_press.event_type).to eq(scope.const_get(:Gdk)::Event::BUTTON2_PRESS)
  ensure
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
  end

  it 'routes switch-page with the notebook, actual page and live index while isolating viewers' do
    notebook = gtk::Notebook.new
    pages = %w[One Two Three].map { |name| gtk::Label.new("#{name} content") }
    pages.each_with_index { |page, i| notebook.append_page(page, gtk::Label.new(%w[One Two Three][i])) }
    seen = []
    notebook.signal_connect('switch-page') { |widget, page, index| seen << [widget, page, index] }
    notebook.set_current_page(1)
    notebook.set_current_page(1)
    expect(seen).to eq([[notebook, pages[1], 1]])
    _window, page = show(notebook)
    first, other = connect(page, 'tabs-one'), connect(page, 'tabs-two')
    props = ->(viewer) { nodes(viewer).find { |node| node['type'] == 'tabs' }.fetch('props') }
    expect(send_event(page, first, :tabs, 'select', { index: 2, tab: props.call(first)['headers'][2]['key'] })).to eq(:queued)
    drain_models
    expect(seen.last).to eq([notebook, pages[2], 2])
    count = seen.length
    send_event(page, first, :tabs, 'select', { index: 2, tab: props.call(first)['headers'][2]['key'] })
    drain_models
    expect(seen.length).to eq(count)
    service.runtime.refresh(page)
    expect(props.call(first)['selected']).to eq(2)
    expect(props.call(other)['selected']).to eq(1)
    before = seen.length
    notebook.remove_page(0)
    expect(seen.length).to eq(before)
    notebook.set_current_page(1)
    expect(seen.last).to eq([notebook, pages[2], 1])
    notebook.remove_page(1)
    expect(seen.last).to eq([notebook, pages[1], 0])
    expect(notebook.children).to eq([pages[1]])
  end

  it 'projects combo presentation per row and rejects edits disabled by boolean model sensitivity' do
    values = gtk::ListStore.new(String, TrueClass)
    enabled, disabled = values.append, values.append
    enabled[0], enabled[1] = 'Old', true
    disabled[0], disabled[1] = 'Old', false
    options = gtk::ListStore.new(String)
    options.append[0] = 'New'
    renderer = gtk::CellRendererCombo.new
    renderer.model = options
    renderer.text_column = 0
    renderer.has_entry = false
    renderer.editable = true
    column = gtk::TreeViewColumn.new('Choice', renderer, text: 0, sensitive: 1)
    column.expand = true
    column.set_cell_data_func(renderer) do |_column, cell, _model, iter|
      cell.foreground_rgba = scope::Gdk::RGBA.new(1, 0, 0, 1)
      cell.foreground_set = iter[1]
    end
    view = gtk::TreeView.new(values)
    view.append_column(column)
    view.selection.mode = gtk::SELECTION_NONE
    edited = []
    renderer.signal_connect('edited') { |_cell, path, value| edited << path; values.get_iter(path)[0] = value }
    _window, page = show(view)
    viewer = connect(page, 'sensitive-cells')
    props = nodes(viewer).find { |node| node['type'] == 'table' }.fetch('props')
    expect(props['selection']).to eq('none')
    expect(props['columns'][0]['expand']).to be(true)
    expect(props['rows'][0]).not_to have_key('cell_disabled')
    expect(props['rows'][0]['cell_foregrounds'].size).to eq(1)
    expect(props['rows'][1]['cell_disabled']).to eq([column.key])
    expect(props['rows'][1]).not_to have_key('cell_foregrounds')
    send_event(page, viewer, :table, 'cell_edit', { row: disabled.key, column: column.key, value: 'New' })
    drain_models
    expect(edited).to be_empty
    expect(disabled[0]).to eq('Old')
    expect(viewer.messages.last['type']).to eq('refusal')
    send_event(page, viewer, :table, 'cell_edit', { row: enabled.key, column: column.key, value: 'New' })
    drain_models
    expect(edited).to eq(['0'])
    expect(enabled[0]).to eq('New')
    expect(renderer.project_cell('Literal')).to eq(['Literal', nil])
    expect { column.expand = :yes }.to raise_error(gtk::UnsupportedOperation)
    expect { renderer.foreground_set = 1 }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'refuses a sensitivity binding to a non-boolean model column' do
    model = gtk::ListStore.new(String)
    model.append[0] = 'Name'
    view = gtk::TreeView.new(model)
    column = gtk::TreeViewColumn.new('Name', gtk::CellRendererText.new, text: 0, sensitive: 0)
    view.append_column(column)
    expect { view.materialize }.to raise_error(gtk::UnsupportedOperation, /sensitive/)
  end

  it 'delivers combo changes with distinct choice iterators before edited text without premutating rows' do
    model = gtk::ListStore.new(String)
    row = model.append
    row[0] = 'Original'
    choices = gtk::ListStore.new(String, Integer)
    a, b = choices.append, choices.append
    a[0], a[1], b[0], b[1] = 'Duplicate', 1, 'Duplicate', 2
    renderer = gtk::CellRendererCombo.new
    renderer.model = choices
    renderer.text_column = 0
    renderer.editable = true
    calls = []
    renderer.signal_connect('changed') do |cell, path, choice|
      expect(cell).to equal(renderer)
      expect(choice.model).to equal(choices)
      calls << [:changed, choices.get_value(choice, 1), model.get_iter(path)[0]]
      model.get_iter(path)[0] = choice[0]
    end
    renderer.signal_connect('edited') { |_cell, _path, text| calls << [:edited, text] }
    view = gtk::TreeView.new(model)
    column = gtk::TreeViewColumn.new('Choice', renderer, text: 0)
    view.append_column(column)
    _window, page = show(view)
    viewer = connect(page, 'choice-identities')
    editor = nodes(viewer).find { |node| node['type'] == 'table' }['props']['columns'][0]['editor']
    expect(editor['option_labels']).to be(true)
    expect(editor['options']).to eq([{ 'value' => a.key, 'label' => 'Duplicate' }, { 'value' => b.key, 'label' => 'Duplicate' }])
    send_event(page, viewer, :table, 'cell_edit', { row: row.key, column: column.key, value: b.key })
    drain_models
    expect(calls).to eq([[:changed, 2, 'Original'], [:edited, 'Duplicate']])
    expect(row[0]).to eq('Duplicate')
    choices.remove(b)
    renderer.emit_edit('0', b.key)
    expect(calls.length).to eq(2)
    replacement = gtk::ListStore.new(String)
    replacement.append[0] = 'Duplicate'
    renderer.model = replacement
    renderer.emit_edit('0', a.key)
    expect(calls.length).to eq(2)
  end

  it 'rolls back failed combo changed handlers and resolves sorted target paths at dispatch' do
    model = gtk::ListStore.new(String)
    zulu, alpha = model.append, model.append
    zulu[0], alpha[0] = 'Zulu', 'Alpha'
    choices = gtk::ListStore.new(String)
    choice = choices.append
    choice[0] = 'New'
    renderer = gtk::CellRendererCombo.new
    renderer.model = choices
    renderer.editable = true
    seen = []
    renderer.signal_connect('changed') do |_cell, path, selected|
      seen << [path, model.get_iter(path).key, selected.key]
      model.get_iter(path)[0] = selected[0]
      raise 'abort changed'
    end
    edited = []
    renderer.signal_connect('edited') { edited << true }
    view = gtk::TreeView.new(model)
    column = gtk::TreeViewColumn.new('Choice', renderer, text: 0)
    view.append_column(column)
    model.set_sort_column_id(0, :ascending)
    _window, page = show(view)
    viewer = connect(page, 'failed-choice')
    send_event(page, viewer, :table, 'cell_edit', { row: zulu.key, column: column.key, value: choice.key })
    drain_models
    expect(seen).to eq([['1', zulu.key, choice.key]])
    expect(zulu[0]).to eq('Zulu')
    expect(edited).to be_empty
  end

  it 'disconnects combo callbacks without retaining stale rebuild context or removing other listeners' do
    combo = gtk::ComboBoxText.new
    %w[First Second].each { |text| combo.append_text(text) }
    calls = []
    id = combo.signal_connect('changed') { calls << :old }
    retained = combo.signal_connect('changed') { calls << :retained }
    expect(combo.signal_handler_disconnect(id)).to equal(combo)
    replacement = combo.signal_connect('changed') { calls << :new }
    combo.active = 0
    expect(calls).to eq(%i[retained new])
    foreign = gtk::ComboBoxText.new.signal_connect('changed') {}
    [id, foreign, '1', nil].each do |invalid|
      expect { combo.signal_handler_disconnect(invalid) }.to raise_error(gtk::UnsupportedOperation)
    end
    expect([id, retained, replacement].uniq.length).to eq(3)
    combo.signal_handler_disconnect(replacement)
    combo.remove_all
    combo.append_text('Rebuilt')
    combo.signal_connect('changed') { calls << :rebuilt }
    combo.active = 0
    expect(calls.last(2)).to eq(%i[retained rebuilt])
    combo.destroy
    expect { combo.signal_handler_disconnect(retained) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'suppresses combo callbacks disconnected during an existing emission snapshot' do
    combo = gtk::ComboBoxText.new
    combo.append_text('One')
    calls = []
    later = nil
    combo.signal_connect('changed') { calls << :first; combo.signal_handler_disconnect(later) }
    later = combo.signal_connect('changed') { calls << :removed }
    combo.active = 0
    expect(calls).to eq([:first])
  end

  it 'returns actual hidden Notebook pages with GTK index semantics without changing selection or ownership' do
    notebook = gtk::Notebook.new
    expect(notebook.get_nth_page(0)).to be_nil
    expect(notebook.get_nth_page(-1)).to be_nil
    pages = %w[First Second Third].map { |name| gtk::Label.new("#{name} content") }
    pages.each_with_index { |page, i| notebook.append_page(page, gtk::Label.new("Tab #{i}")) }
    pages[1].no_show_all = true
    pages[1].hide
    notebook.set_current_page(2)
    expect(notebook.get_nth_page(1)).to equal(pages[1])
    [-1, -2, -100].each { |index| expect(notebook.get_nth_page(index)).to equal(pages[2]) }
    expect(notebook.get_nth_page(3)).to be_nil
    expect(notebook.get_nth_page(2**128)).to be_nil
    expect(notebook.send(:read, :selected)).to eq(2)
    expect(pages.map(&:parent)).to eq([notebook] * 3)
    [nil, '1', 1.5].each { |index| expect { notebook.get_nth_page(index) }.to raise_error(gtk::UnsupportedOperation) }
    notebook.remove_page(0)
    expect(notebook.get_nth_page(0)).to equal(pages[1])
    expect(notebook.get_nth_page(1)).to equal(pages[2])
    notebook.destroy
    expect { notebook.get_nth_page(0) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'keeps combo candidate validation separate from publication with duplicate and unset labels' do
    model = gtk::ListStore.new(String)
    first, blank, last = 3.times.map { model.append }
    first[0] = last[0] = 'Duplicate'
    combo = gtk::ComboBox.new(model)
    combo.active = 2
    _window, = show(combo)
    handle = combo.materialize
    port = combo.session.port
    original = [{ value: 'none', label: '' }, { value: first.key, label: 'Duplicate' },
                { value: blank.key, label: '' }, { value: last.key, label: 'Duplicate' }]
    updated = [{ value: 'none', label: '' }, { value: first.key, label: 'Duplicate' },
               { value: blank.key, label: 'Assigned' }, { value: last.key, label: 'Duplicate' }]
    phases = []
    allow(combo).to receive(:model_will_change!).and_wrap_original do |method|
      method.call
      phases << [:preflight, port.get(handle, :options)]
    end
    allow(combo).to receive(:model_changed!).and_wrap_original do |method|
      method.call
      phases << [:publication, port.get(handle, :options)]
    end

    expect(port.get(handle, :options)).to eq(original)
    blank[0] = 'Assigned'
    expect(phases).to eq([[:preflight, original], [:publication, updated]])
    expect(combo.active_iter).to eq(last)
    phases.clear
    expect { blank[0] = 'x' * 513 }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect(phases).to be_empty
    expect(blank[0]).to eq('Assigned')
    expect(port.get(handle, :options)).to eq(updated)
  end
end
