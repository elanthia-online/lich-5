# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_shim_bindings'
require 'timeout'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_browser'

RSpec.describe 'bounded text, image and menu compatibility' do
  include WebUISpecSupport::ShimBindings

  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('pilot.lic') }
  let(:asset_directory) { Dir.mktmpdir('shim-images-') }
  let(:service) { Lich::WebUI::Service.new(application_roots: [asset_directory]) }
  let(:compatibility) { scope.const_get(:Gtk, false) }

  before do
    @core_gtk = [Object, Lich::Common].to_h do |namespace|
      [namespace, namespace.const_defined?(:Gtk, false) ? namespace.const_get(:Gtk, false) : nil]
    end
    install_webui_shim_bindings
    allow(Lich::WebUI).to receive(:service).and_return(service)
    allow(Lich).to receive(:log)
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
    FileUtils.remove_entry(asset_directory)
  end

  def wait_for(&block)
    Timeout.timeout(3) { sleep 0.005 until block.call }
  end

  def show(window)
    window.show_all
    page = nil
    wait_for { (page = service.registry.pages_for(owner).first)&.last_render }
    page
  end

  def connect(page, id)
    connection = Struct.new(:viewer_id, :messages).new(id, [])
    def connection.alive? = true
    def connection.send_text(text) = messages << JSON.parse(text)
    service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page))
    connection
  end

  def send_event(page, connection, node, name, payload = {}, submission: nil, **fields)
    render = connection.messages.reverse.find { |message| message['type'] == 'render' }
    message = { type: 'event', page: service.registry.address_for(page), generation: render.fetch('generation'),
                cid: node.cid, event: name, payload: payload.merge(fields) }
    message[:submission] = submission if submission
    service.runtime.handle(connection, message)
  end

  def flatten(node)
    [node] + Array(node['children']).flat_map { |child| flatten(child) }
  end

  def rendered_node(connection, type)
    render = connection.messages.reverse.find { |message| message['type'] == 'render' }
    flatten(render.fetch('tree')).find { |node| node['type'] == type.to_s }
  end

  it 'bounds initial Paned pixels to the measured resize policy and refuses live resets' do
    split = compatibility::Paned.new(:horizontal)
    split.pack1(compatibility::Label.new('First'), true, false)
    split.pack2(compatibility::Label.new('Second'), false, true)
    split.position = 700
    expect(split.send(:component_props)).to include(position_pixels: 700, resize_side: :first)
    [-1, 65_537, 1.5, '700'].each { |value| expect { split.position = value }.to raise_error(compatibility::UnsupportedOperation) }
    window = compatibility::Window.new
    window.add(split)
    show(window)
    expect { split.set_position(600) }.to raise_error(compatibility::UnsupportedOperation)
    expect(split.send(:component_props)[:position_pixels]).to eq(700)
    unsupported = compatibility::Paned.new(:horizontal)
    unsupported.pack1(compatibility::Label.new('First'), true, false)
    unsupported.pack2(compatibility::Label.new('Second'), true, true)
    expect { unsupported.position = 700 }.to raise_error(compatibility::UnsupportedOperation)
  end

  it 'preserves EventBox tab clicks, live color and page operations in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    notebook = compatibility::Notebook.new
    status = compatibility::Label.new('No tab command')
    gdk = scope.const_get(:Gdk)
    main_label = compatibility::Label.new('Main')
    main_label.override_color(:normal, gdk::RGBA.new(1, 0, 0, 1))
    main = compatibility::EventBox.new.add(main_label)
    bag_page = nil
    add_bag = proc do
      bag_page = compatibility::Label.new('Bag contents')
      label = compatibility::Label.new('Bag')
      wrapper = compatibility::EventBox.new.add(label)
      wrapper.signal_connect('button-press-event') do |widget, event|
        next unless event.event_type == gdk::EventType::BUTTON_PRESS
        if event.button == gdk::BUTTON_SECONDARY
          notebook.remove_page(notebook.children.index(bag_page))
          status.text = 'Bag closed'
        elsif event.button == gdk::BUTTON_MIDDLE
          status.text = widget.equal?(wrapper) ? 'Bag middle command' : 'Wrong tab widget'
        end
      end
      notebook.append_page(bag_page, wrapper)
    end
    main.signal_connect('button-press-event') do |_widget, event|
      if event.button == gdk::BUTTON_SECONDARY
        notebook.remove_page(-1) while notebook.n_pages > 1
        status.text = 'Other tabs closed'
      elsif event.button == gdk::BUTTON_MIDDLE
        status.text = 'Main middle command'
      end
    end
    notebook.append_page(compatibility::Label.new('Main contents'), main)
    add_bag.call
    recolor = compatibility::Button.new('Green tab')
    recolor.signal_connect('clicked') { main_label.override_color(:normal, gdk::RGBA.new(0, 1, 0, 1)) }
    reopen = compatibility::Button.new('Reopen bag')
    reopen.signal_connect('clicked') { add_bag.call; notebook.set_current_page(notebook.n_pages - 1) }
    box = compatibility::Box.new(:vertical, 4)
    [notebook, status, recolor, reopen].each { |widget| box.add(widget) }
    WebUIBrowser.check(service: service, page: show(compatibility::Window.new('Notebook tabs').add(box)), scenario: 'priority15-notebook')
    expect(notebook.n_pages).to eq(1)
    expect(main_label.send(:component_props)[:foreground][:g]).to eq(255)
  end

  it 'preserves filtered selection and initial pixel splits across updates and resizing in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Priority 15 follow-up')
    window.set_default_size(1000, 600)
    model = compatibility::ListStore.new(String)
    %w[Allowed Denied Failing].each { |name| model.append[0] = name }
    view = compatibility::TreeView.new(model)
    view.append_column(compatibility::TreeViewColumn.new('Choice', compatibility::CellRendererText.new, text: 0))
    view.selection.set_select_function do |_selection, store, path, _selected|
      name = store.get_iter(path)[0]
      raise 'predicate failure' if name == 'Failing'
      name == 'Allowed'
    end
    status = compatibility::Label.new('No accepted selection')
    view.selection.signal_connect('changed') { status.text = "Accepted: #{view.selection.selected[0]}" }
    split = compatibility::Paned.new(:horizontal)
    split.pack1(view, true, false)
    split.pack2(status, false, true)
    split.position = 700
    WebUIBrowser.check(service: service, page: show(window.add(split)), scenario: 'priority15-followup')
  end

  it 'renders Priority 15 cell colors, minimum widths, custom headers and word-character wrapping in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Priority 15')
    box = compatibility::Box.new(:vertical, 4)
    model = compatibility::ListStore.new(String, TrueClass)
    first, second = model.append, model.append
    first[0], first[1] = '<b>Alpha</b>', true
    second[0], second[1] = 'Beta', false
    view = compatibility::TreeView.new(model)
    view.tooltip_text = 'Inventory help'
    cell = compatibility::CellRendererText.new
    column = compatibility::TreeViewColumn.new('Custom order', cell, text: 0)
    column.min_width = 160
    column.fixed_width = 90
    column.resizable = true
    column.clickable = true
    column.set_tooltip_text('Custom header help')
    column.set_cell_data_func(cell) do |_column, renderer, store, iter|
      renderer.text = store.get_value(iter, 0)
      renderer.foreground_rgba = scope.const_get(:Gdk)::RGBA.new(1, 0, 0, 1) if iter[1]
    end
    column.signal_connect('clicked') do
      first[0] = 'Zulu'
      column.min_width = 240
      model.set_sort_column_id(0, :ascending)
    end
    view.append_column(column)
    log = compatibility::TextView.new
    log.editable = false
    log.wrap_mode = compatibility::WrapMode::WORD_CHAR
    log.tooltip_text = 'Wrapped log'
    log.set_size_request(160, 80)
    log.buffer.text = 'x' * 120
    editor = compatibility::TextView.new
    editor.wrap_mode = :word_char
    editor.set_size_request(160, 80)
    editor.buffer.text = 'y' * 120
    nowrap = compatibility::Button.new('Disable wrap')
    nowrap.signal_connect('clicked') { log.wrap_mode = :none; editor.wrap_mode = :none }
    [view, log, editor, nowrap].each { |widget| box.add(widget) }
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority15-tree-text')
    expect(model.rows.map { |iter| iter[0] }).to eq(%w[Beta Zulu])
  end

  it 'accepts legacy markup and width setters with bounded named sizes' do
    label = compatibility::Label.new('<b>Ready</b>')
    label.set_use_markup(true)
    label.width_chars = 12
    label.text = "<b><span foreground='#d4af37' size='large'>Gold</span></b>"
    props = label.send(:component_props)
    expect(props).to include(content: 'Gold', min_width_chars: 12)
    expect(props[:fragments].first).to include(emphasis: :strong, scale: 1.2)
    original = props.dup
    ["<span size='huge'>Bad</span>", "<span size='xx-large'><big>Too large</big></span>"].each do |markup|
      expect { label.markup = markup }.to raise_error(compatibility::UnsupportedOperation)
      expect(label.send(:component_props)).to eq(original)
    end
    [0, 1025, 2.5].each do |count|
      expect { label.width_chars = count }.to raise_error(compatibility::UnsupportedOperation)
    end
    window = compatibility::Window.new
    window.add(label)
    page = show(window)
    expect(page.last_render.tree.each.find { |node| node.type == :text }.props[:fragments].first[:scale]).to eq(1.2)
  end

  it 'keeps bounded LinkButton destinations, captions and sensitivity live without accepting executable markup' do
    link = compatibility::LinkButton.new('https://example.org/wiki?x=1&y=2', 'Open <wiki>')
    link.sensitive = false
    window = compatibility::Window.new
    window.add(link)
    page = show(window)
    viewer = connect(page, 'link-button')
    expect(rendered_node(viewer, :markdown)['props']).to include('disabled' => true)
    expect(link.label).to eq('Open <wiki>')
    link.uri = 'https://example.org/new'
    link.label = 'New wiki'
    link.sensitive = true
    wait_for { rendered_node(viewer, :markdown).dig('props', 'disabled') == false }
    expect(rendered_node(viewer, :markdown)['props']['content']).to eq('[New wiki](https://example.org/new)')
    original = link.send(:component_props).dup
    ['javascript:alert(1)', 'file:///tmp/test', 'https://user:secret@example.org', 'https://example.org/ bad'].each do |uri|
      expect { link.uri = uri }.to raise_error(compatibility::UnsupportedOperation)
      expect(link.uri).to eq('https://example.org/new')
      expect(link.send(:component_props)).to eq(original)
    end
    link.sensitive = false
    wait_for { rendered_node(viewer, :markdown).dig('props', 'disabled') == true }
  end

  it 'uses fill allocation and whole-label monospace markup through existing typed properties' do
    entry = compatibility::Entry.new
    entry.halign = :fill
    expect(entry.send(:component_props)[:align]).to eq(:stretch)
    expect { entry.halign = :unknown }.to raise_error(compatibility::UnsupportedOperation)
    label = compatibility::Label.new
    label.override_font(scope::Pango::FontDescription.new('serif 12'))
    label.markup = '<tt> A &lt; B </tt>'
    expect(label.text).to eq(' A < B ')
    expect(label.send(:component_props)[:font_family]).to eq('monospace')
    original = label.send(:component_props).dup
    expect { label.markup = '<tt><script>bad</script></tt>' }.to raise_error(compatibility::UnsupportedOperation)
    expect(label.send(:component_props)).to eq(original)
    label.markup = '<b>Plain</b>'
    expect(label.send(:component_props)[:font_family]).to eq('serif')
  end

  it 'validates fill geometry, live links and directional button callbacks in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Three compatibility controls')
    box = compatibility::Box.new(:vertical, 5)
    grid = compatibility::Grid.new
    4.times { |index| grid.attach(compatibility::Label.new("Column #{index}"), index, 0, 1, 1) }
    entry = compatibility::Entry.new
    entry.hexpand = true
    entry.halign = :fill
    entry.margin_start = 40
    entry.tooltip_text = 'Fill entry'
    grid.attach(entry, 0, 1, 4, 1)
    box.add(grid)
    mono = compatibility::Label.new
    mono.markup = '<tt>Mono caption</tt>'
    box.add(mono)
    link = compatibility::LinkButton.new('https://example.invalid/wiki', 'Open wiki')
    link.sensitive = false
    box.add(link)
    select = compatibility::Button.new('Select spell')
    select.signal_connect('clicked') do
      link.uri = 'https://example.invalid/spell'
      link.label = 'Open selected wiki'
      link.sensitive = true
    end
    clear = compatibility::Button.new('Clear selection')
    clear.signal_connect('clicked') { link.sensitive = false }
    box.add(select)
    box.add(clear)
    order = %w[First Second]
    status = compatibility::Label.new(order.join(', '))
    up, down = compatibility::Button.new, compatibility::Button.new
    up.relief = down.relief = :none
    up.image = compatibility::Image.new(icon_name: 'go-up', icon_size: :button)
    down.image = compatibility::Image.new(icon_name: 'go-down', icon_size: :button)
    up.sensitive = false
    up.signal_connect('clicked') do
      order.reverse!
      up.sensitive = false
      down.sensitive = true
      status.text = order.join(', ')
    end
    down.signal_connect('clicked') do
      order.reverse!
      up.sensitive = true
      down.sensitive = false
      status.text = order.join(', ')
    end
    [up, down, status].each { |widget| box.add(widget) }
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'three-compatibility')
    expect(order).to eq(%w[First Second])
    expect(link.sensitive?).to be(false)
  end

  it 'renders populated nonselecting rich lists with alpha, recall styling and independent controls in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Merchantical rich list fixture')
    root = compatibility::Box.new(:vertical)
    lists = 2.times.map { compatibility::ListBox.new }
    names = ['Locked sword', 'Unlocked gem']
    crossing = compatibility::Label.new('Crossings 0/0')
    entered = left = 0
    root.add(crossing)
    lists.each_with_index do |list, index|
      list.selection_mode = :none
      row = compatibility::ListBoxRow.new
      row.activatable = row.selectable = false
      row.opacity = index.zero? ? 1 : 0.35
      content = compatibility::Box.new(:vertical)
      detail = compatibility::Frame.new
      detail.no_show_all = true
      detail.visible = false
      recall = compatibility::Label.new
      recall.set_markup("<span foreground='#aaa' font_family='monospace' size='small'>Recall #{index}</span>")
      detail.add(recall)
      recall.show
      action = compatibility::Button.new.add(compatibility::Label.new(names[index]))
      if index.zero?
        action.signal_connect('enter-notify-event') { entered += 1; crossing.text = "Crossings #{entered}/#{left}" }
        action.signal_connect('leave-notify-event') { left += 1; crossing.text = "Crossings #{entered}/#{left}" }
      end
      action.opacity = 0.45
      action.signal_connect('clicked') { detail.visible = !detail.visible? }
      content.add(action)
      content.add(compatibility::Entry.new) if index.zero?
      cue = compatibility::Label.new
      cue.set_markup("<span background='#3c9c3c'>Found</span>")
      content.add(cue)
      content.add(detail)
      list.add(row.add(content))
      root.add(list)
    end
    remove = compatibility::Button.new('Remove locked list')
    remove.signal_connect('clicked') { root.remove(lists.first) }
    root.add(remove)
    spacer = compatibility::Button.new('Alignment spacer')
    spacer.opacity = 0
    spacer.sensitive = false
    root.add(spacer)
    window.add(root)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'merchantical-list')
  end

  it 'keeps Notebook help actions independent of four indexed pages through live replacement in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    notebook = compatibility::Notebook.new
    %w[Stock Sale Queue Ledger].each { |name| notebook.append_page(compatibility::Label.new("#{name} content"), compatibility::Label.new(name)) }
    status = compatibility::Label.new('Help idle')
    start = compatibility::Button.new('Start action')
    start.signal_connect('clicked') { status.text = 'Start activated' }
    help_label = compatibility::Label.new
    help_label.set_markup("<b><span foreground='#d4af37'>Shop help</span></b>")
    help = compatibility::Button.new.add(help_label)
    help.tooltip_text = 'Help on every page'
    count = 0
    help.signal_connect('clicked') { count += 1; status.text = "Help #{count}" }
    notebook.set_action_widget(start, :start)
    notebook.set_action_widget(help, :end)
    root = compatibility::Box.new(:vertical)
    root.add(notebook)
    root.add(status)
    controls = {
      'Replace help'            => proc { notebook.set_action_widget(compatibility::Button.new('Replacement'), :end) },
      'Restore help'            => proc { notebook.set_action_widget(help, :end) },
      'Toggle help sensitivity' => proc { help.sensitive = !help.sensitive? },
      'Toggle help visibility'  => proc { help.visible = !help.visible? },
      'Toggle selectors'        => proc { notebook.show_tabs = notebook.send(:component_props)[:show_tabs] == false },
      'Remove first page'       => proc { notebook.remove_page(0) }
    }
    controls.each do |label, callback|
      button = compatibility::Button.new(label)
      button.signal_connect('clicked', &callback)
      root.add(button)
    end
    window = compatibility::Window.new('Merchantical Notebook actions').add(root)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'merchantical-notebook-actions')
    expect(notebook.n_pages).to eq(3)
    expect(count).to eq(5)
  end

  it 'opens and closes independent help documents while preserving parent input and static scroll in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    main = compatibility::Window.new('Merchantical help fixture')
    root = compatibility::Box.new(:vertical)
    entry = compatibility::Entry.new
    entry.placeholder_text = 'Parent draft'
    status = compatibility::Label.new('Help idle')
    repaint = compatibility::Button.new('Refresh parent')
    refreshes = 0
    repaint.signal_connect('clicked') { refreshes += 1; status.text = "Parent refresh #{refreshes}" }
    open = compatibility::Button.new('Open help')
    children = []
    closed = 0
    open.signal_connect('clicked') do
      help = compatibility::Window.new('Fixture help')
      help.set_default_size(560, 520)
      help.transient_for = main
      help.set_window_position(:center_on_parent)
      help.keep_above = true
      outer = compatibility::Box.new(:vertical)
      scroll = compatibility::ScrolledWindow.new
      scroll.set_size_request(400, 180)
      inner = compatibility::Box.new(:vertical)
      inner.margin = 16
      title = compatibility::Label.new
      title.set_markup('<b>Help heading</b>')
      text = compatibility::TextView.new
      text.editable = false
      text.cursor_visible = false
      text.wrap_mode = :word
      text.left_margin = 4
      text.buffer.text = 80.times.map { |index| "Help line #{index}" }.join("\n")
      inner.add(title).add(text)
      scroll.add(inner)
      outer.add(scroll)
      refresh = compatibility::Button.new('Refresh help')
      refresh.signal_connect('clicked') { title.text = 'Help refreshed' }
      follow = compatibility::Button.new('Follow end')
      follow.signal_connect('clicked') { text.scroll_to_iter(text.buffer.end_iter, 0.0, true, 0, 0) }
      close = compatibility::Button.new('Close help')
      close.signal_connect('clicked') { help.destroy }
      help.signal_connect('destroy') { closed += 1 }
      [refresh, follow, close].each { |widget| outer.add(widget) }
      help.add(outer).show_all
      children << help
      # Publication runs after this callback; a timer observes completion without blocking its owner.
      scope.const_get(:GLib, false)::Timeout.add(10) do
        page = service.registry.pages_for(owner).find { |candidate| candidate.title == 'Fixture help' }
        if page&.last_render
          status.text = "Help page: #{service.registry.address_for(page)}"
          false
        else
          true
        end
      end
    end
    [entry, open, repaint, status].each { |widget| root.add(widget) }
    WebUIBrowser.check(service: service, page: show(main.add(root)), scenario: 'merchantical-help-window')
    expect(children.size).to eq(2)
    expect(closed).to eq(2)
    expect(children.all?(&:destroyed?)).to be(true)
  end

  it 'updates subclass Frame captions and shadow transitions without replacing child handles' do
    frame = Class.new(compatibility::Frame).new('Initial')
    entry = compatibility::Entry.new
    frame.add(entry)
    frame.set_label_widget(compatibility::Label.new('Copied'))
    expect(frame.label).to eq('Copied')
    frame.shadow_type = :none
    frame.set_shadow_type(:in)
    window = compatibility::Window.new
    window.add(frame)
    page = show(window)
    viewer = connect(page, 'frame-caption')
    original_child = rendered_node(viewer, :text_input)['cid']
    frame.label = 'Updated'
    wait_for { rendered_node(viewer, :group).dig('props', 'label') == 'Updated' }
    expect(rendered_node(viewer, :group)['props']['border_width']).to eq(1)
    expect(rendered_node(viewer, :text_input)['cid']).to eq(original_child)
    expect(frame.children).to eq([entry])
    [nil, 42, 'x' * 513, [255].pack('C').force_encoding('UTF-8')].each do |value|
      expect { frame.label = value }.to raise_error(compatibility::UnsupportedOperation)
      expect(frame.label).to eq('Updated')
    end
    frame.shadow_type = :etched_in
    expect(frame.send(:component_props)[:border_width]).to eq(1)
    expect(rendered_node(viewer, :text_input)['cid']).to eq(original_child)
    %i[out etched_out unknown].each do |value|
      expect { frame.shadow_type = value }.to raise_error(compatibility::UnsupportedOperation)
      expect(frame.send(:component_props)[:border_width]).to eq(1)
    end
    frame.set_label('')
    wait_for { rendered_node(viewer, :group).dig('props', 'label') == '' }
    expect(frame.label).to eq('')
  end

  it 'warns only for omitted Expander caption markup while synchronizing live text' do
    expander = compatibility::Expander.new('Initial')
    window = compatibility::Window.new.add(expander)
    viewer = connect(show(window), 'expander-caption-warning')
    expander.label = 'Plain update'
    wait_for { rendered_node(viewer, :expander)['props']['label'] == 'Plain update' }
    expect(Lich).not_to have_received(:log).with(/compatibility expander_caption_style/)
    expander.label_widget.set_markup('<b>Styled</b> <i>heading</i>')
    wait_for { rendered_node(viewer, :expander)['props']['label'] == 'Styled heading' }
    expander.label_widget.set_markup('<i>Another</i> heading')
    wait_for { rendered_node(viewer, :expander)['props']['label'] == 'Another heading' }
    expect(Lich).to have_received(:log).with(/compatibility expander_caption_style/).once
    expander.label = 'Plain again'
    wait_for { rendered_node(viewer, :expander)['props']['label'] == 'Plain again' }
    expect(Lich).to have_received(:log).with(/compatibility expander_caption_style/).once
  end

  it 'retires replaced Frame captions and style contexts without accumulating resources' do
    frame = compatibility::Frame.new('Initial')
    retired = []
    destroyed = []
    8.times do |index|
      previous = frame.label_widget
      previous.style_context
      previous.signal_connect('destroy') { destroyed << previous }
      retired << previous
      replacement = compatibility::Label.new("Caption #{index}")
      replacement.style_context
      frame.set_label_widget(replacement)
      expect(previous.destroyed?).to be(true)
      expect(previous.instance_variable_defined?(:@frame_caption_owner)).to be(false)
      expect(replacement.instance_variable_get(:@frame_caption_owner)).to equal(frame)
      expect(frame.session.instance_variable_get(:@style_contexts).size).to eq(1)
    end
    expect(destroyed).to eq(retired)
    current = frame.label_widget
    current.signal_connect('destroy') { destroyed << current }
    frame.destroy
    frame.destroy
    expect(destroyed).to eq(retired + [current])
    expect(frame.session.instance_variable_get(:@style_contexts)).to be_empty
  end

  it 'preserves Frame caption ownership when replacement validation refuses' do
    frame = compatibility::Frame.new('Initial')
    previous = frame.label_widget
    previous.style_context
    parented = compatibility::Label.new('Parented')
    compatibility::Box.new.add(parented)
    retired = compatibility::Label.new('Retired')
    retired.destroy
    [compatibility::Label.new('x' * 513), previous, parented, retired].each do |replacement|
      expect { frame.set_label_widget(replacement) }.to raise_error(compatibility::UnsupportedOperation)
      expect(frame.label_widget).to equal(previous)
      expect(frame.label).to eq('Initial')
      expect(previous.destroyed?).to be(false)
      expect(previous.instance_variable_get(:@frame_caption_owner)).to equal(frame)
      expect(frame.session.instance_variable_get(:@style_contexts).size).to eq(1)
    end
  end

  it 'preserves the live Frame caption and child identity when publication fails' do
    frame = compatibility::Frame.new('Initial')
    frame.add(compatibility::Entry.new)
    window = compatibility::Window.new.add(frame)
    viewer = connect(show(window), 'caption-refusal')
    child = rendered_node(viewer, :text_input)['cid']
    previous = frame.label_widget
    replacement = compatibility::Label.new('Replacement')
    allow(frame.session.port).to receive(:set).with(anything, :label, 'Replacement').and_raise(Lich::WebUI::Error, 'caption refused')
    expect { frame.set_label_widget(replacement) }.to raise_error(Lich::WebUI::Error, /caption refused/)
    expect(frame.label_widget).to equal(previous)
    expect(frame.label).to eq('Initial')
    expect(previous.destroyed?).to be(false)
    expect(previous.instance_variable_get(:@frame_caption_owner)).to equal(frame)
    expect(replacement.instance_variable_defined?(:@frame_caption_owner)).to be(false)
    expect(rendered_node(viewer, :text_input)['cid']).to eq(child)
  end

  it 'preserves a caption installed reentrantly by the previous caption destroy handler' do
    frame = compatibility::Frame.new('Initial')
    previous = frame.label_widget
    middle, final = compatibility::Label.new('Middle'), compatibility::Label.new('Final')
    [previous, middle, final].each(&:style_context)
    observed = []
    previous.signal_connect('destroy') do
      observed << frame.label_widget
      frame.set_label_widget(final)
    end
    frame.set_label_widget(middle)
    expect(observed).to eq([middle])
    expect(frame.label_widget).to equal(final)
    expect(frame.label).to eq('Final')
    expect([previous, middle].all?(&:destroyed?)).to be(true)
    expect(final.destroyed?).to be(false)
    expect(final.instance_variable_get(:@frame_caption_owner)).to equal(frame)
    expect(frame.session.instance_variable_get(:@style_contexts).size).to eq(1)
  end

  it 'retires the new caption if the previous caption destroy handler destroys the Frame' do
    frame = compatibility::Frame.new('Initial')
    previous = frame.label_widget
    replacement = compatibility::Label.new('Replacement')
    [previous, replacement].each(&:style_context)
    previous.signal_connect('destroy') { frame.destroy }
    frame.set_label_widget(replacement)
    expect([frame, previous, replacement].all?(&:destroyed?)).to be(true)
    expect(frame.session.instance_variable_get(:@style_contexts)).to be_empty
  end

  it 'bounds ButtonBox layout and live spacing without replacing button identities' do
    expect { compatibility::ButtonBox.new(:vertical) }.to raise_error(compatibility::UnsupportedOperation)
    footer = compatibility::ButtonBox.new(:horizontal)
    footer.layout = :end
    footer.spacing = 10
    first = compatibility::Button.new('Save')
    footer.add(first)
    window = compatibility::Window.new
    window.add(footer)
    viewer = connect(show(window), 'footer')
    original = rendered_node(viewer, :button)['cid']
    second = compatibility::Button.new('Cancel')
    footer.add(second)
    footer.set_spacing(12)
    wait_for { rendered_node(viewer, :grid).dig('props', 'gap') == 12 }
    expect(rendered_node(viewer, :grid)['props']).to include('cols' => 2, 'align' => 'end', 'expand_columns' => [])
    expect(rendered_node(viewer, :button)['cid']).to eq(original)
    expect(footer.children).to eq([first, second])
    [:start, :spread, nil].each do |value|
      expect { footer.layout = value }.to raise_error(compatibility::UnsupportedOperation)
      expect(footer.layout).to eq(:end)
    end
    [-1, 65, 1.5, '10', nil].each do |value|
      expect { footer.spacing = value }.to raise_error(compatibility::UnsupportedOperation)
      expect(footer.spacing).to eq(12)
    end
    footer.remove(second)
    wait_for { rendered_node(viewer, :grid).dig('props', 'cols') == 1 }
    expect(first.parent).to equal(footer)
  end

  it 'renders end-aligned ButtonBox actions and empty named combo choices in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('ButtonBox and empty IDs')
    box = compatibility::Box.new(:vertical, 4)
    combo = compatibility::ComboBoxText.new
    combo.append('', '-- select spell --')
    combo.append('spell', 'Spell')
    combo.active = 0
    status = compatibility::Label.new('Ready')
    combo.signal_connect('changed') { status.text = "Choice: #{combo.active_id.inspect}" }
    footer = compatibility::ButtonBox.new(:horizontal)
    footer.layout = :end
    footer.spacing = 10
    save = compatibility::Button.new('Save & Close')
    save.signal_connect('clicked') do
      footer.spacing = 18
      combo.append('extra', 'Extra')
      status.text = "Saved: #{combo.active_id.inspect}"
    end
    cancel = compatibility::Button.new('Cancel')
    cancel.signal_connect('clicked') { combo.active_id = ''; status.text = "Reset: #{combo.active_id.inspect}" }
    footer.add(save)
    footer.add(cancel)
    box.add(combo)
    box.add(status)
    box.pack_end(footer, expand: false, fill: false, padding: 10)
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'buttonbox-empty-id')
    expect(footer.spacing).to eq(18)
    expect(combo.active_id).to eq('')
  end

  it 'normalizes only omitted or nil scroller adjustments and preserves the existing facade' do
    [compatibility::ScrolledWindow.new, compatibility::ScrolledWindow.new(nil, nil)].each do |scroll|
      expect(scroll.vadjustment).to be_a(compatibility::ScrollAdjustment)
      original = scroll.vadjustment
      scroll.shadow_type = compatibility::SHADOW_IN
      expect(scroll.vadjustment).to equal(original)
      expect(compatibility::SHADOW_IN).to eq(:in)
    end
    [[Object.new, nil], [nil, Object.new]].each do |arguments|
      expect { compatibility::ScrolledWindow.new(*arguments) }.to raise_error(compatibility::UnsupportedOperation)
    end
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'preserves frame captions, borders and input drafts through live updates in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Frame and scroller compatibility')
    box = compatibility::Box.new(:vertical, 4)
    frame = compatibility::Frame.new('Initial frame')
    entry = compatibility::Entry.new
    entry.tooltip_text = 'Draft entry'
    frame.add(entry)
    frame.shadow_type = :in
    scroll = compatibility::ScrolledWindow.new(nil, nil)
    scroll.shadow_type = compatibility::SHADOW_IN
    scroll.add(frame)
    box.add(scroll)
    status = compatibility::Label.new('No submit')
    entry.signal_connect('activate') { status.text = "Submitted: #{entry.text}" }
    actions = {
      'Rename frame'   => proc { frame.label = 'Updated frame' },
      'Remove border'  => proc { frame.shadow_type = :none },
      'Restore border' => proc { frame.shadow_type = :in },
      'Empty caption'  => proc { frame.set_label('') }
    }
    actions.each do |caption, action|
      button = compatibility::Button.new(caption)
      button.signal_connect('clicked', &action)
      box.add(button)
    end
    box.add(status)
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'frame-scroller')
    expect(frame.label).to eq('')
    expect(entry.text).to eq('Retained draft')
    expect(status.text).to eq('Submitted: Retained draft')
  end

  it 'preserves nested and mixed label styles as literal fragments and clears them on a live text replacement' do
    label = compatibility::Label.new
    label.markup = '<b>Attack &amp; defend</b>  <i>(optional)</i>'
    window = compatibility::Window.new
    window.add(label)
    page = show(window)
    viewer = connect(page, 'mixed-label')
    props = rendered_node(viewer, :text)['props']
    expect(label.text).to eq('Attack & defend  (optional)')
    expected = [
      { 'content' => 'Attack & defend', 'emphasis' => 'strong' },
      { 'content' => '  ' }, { 'content' => '(optional)', 'font_style' => 'italic' }
    ]
    expect(props['fragments']).to eq(expected)
    label.markup = "<small><i><span foreground='#888888'>A &lt; B</span></i></small>"
    wait_for { rendered_node(viewer, :text).dig('props', 'content') == 'A < B' }
    fragment = rendered_node(viewer, :text)['props']['fragments'].first
    expect(fragment).to include('font_style' => 'italic', 'foreground' => { 'r' => 136, 'g' => 136, 'b' => 136, 'a' => 1.0 })
    expect(fragment['scale']).to be_within(0.001).of(1 / 1.2)
    label.text = 'Plain replacement'
    wait_for { rendered_node(viewer, :text).dig('props', 'content') == 'Plain replacement' }
    expect(rendered_node(viewer, :text)['props']).not_to have_key('fragments')
  end

  it 'preserves Combatical title typography as bounded fragments and resets it on replacement' do
    glyph = [0x2694].pack('U')
    label = compatibility::Label.new
    label.markup = "<span font_desc='18' weight='bold' foreground='#D4AF37'>#{glyph} </span>" \
                   "<span font_desc='22' weight='heavy' foreground='#D4AF37' letter_spacing='4096'>COMBATICAL</span>" \
                   "<span font_desc='18' weight='bold' foreground='#D4AF37'> #{glyph}</span>"
    fragments = label.send(:component_props).fetch(:fragments)
    expect(fragments.map { |part| part[:content] }.join).to eq("#{glyph} COMBATICAL #{glyph}")
    expect(fragments[0]).to include(font_size: 18.0, font_unit: :pt, emphasis: :strong)
    expect(fragments[1]).to include(font_size: 22.0, font_weight: 900, letter_spacing: 4.0)
    label.markup = "<span foreground='red' font_desc='Sans 12' weight='heavy'><b>Bold</b> Heavy</span>"
    parts = label.send(:component_props).fetch(:fragments)
    expect(parts[0]).to include(font_family: 'sans-serif', emphasis: :strong)
    expect(parts[0]).not_to have_key(:font_weight)
    expect(parts[1]).to include(font_weight: 900)
    label.markup = '<b>Plain replacement</b>'
    expect(label.send(:component_props)).not_to have_key(:fragments)
    original = label.send(:component_props).dup
    ["font_desc='5'", "font_desc='49'", "font_desc='18px'", "weight='900; color:red'",
     "letter_spacing='65537'", "letter_spacing='-16385'", "letter_spacing='4px'"].each do |attribute|
      expect { label.markup = "<span foreground='red' #{attribute}>Bad</span>" }.to raise_error(compatibility::UnsupportedOperation)
      expect(label.send(:component_props)).to eq(original)
    end
  end

  it 'retains only boolean overlay preferences without changing scroll policy or content' do
    scroll = compatibility::ScrolledWindow.new
    expect(scroll.overlay_scrolling?).to be(true)
    expect(scroll.set_overlay_scrolling(false)).to equal(scroll)
    expect(scroll.overlay_scrolling).to be(false)
    scroll.set_policy(:never, :automatic)
    scroll.add(compatibility::Label.new('Scrollable content'))
    window = compatibility::Window.new
    window.add(scroll)
    viewer = connect(show(window), 'overlay-preference')
    identity = rendered_node(viewer, :scroll)['cid']
    scroll.overlay_scrolling = true
    expect(scroll.overlay_scrolling?).to be(true)
    expect(rendered_node(viewer, :scroll)['cid']).to eq(identity)
    expect([scroll.hscrollbar_policy, scroll.vscrollbar_policy]).to eq(%i[never automatic])
    [nil, 0, 'true'].each { |value| expect { scroll.set_overlay_scrolling(value) }.to raise_error(compatibility::UnsupportedOperation) }
    allow(Lich::Common::Script).to receive(:current).and_return(Struct.new(:name).new('foreign'))
    expect { scroll.set_overlay_scrolling(false) }.to raise_error(compatibility::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    scroll.destroy
    expect { scroll.set_overlay_scrolling(false) }.to raise_error(compatibility::UnsupportedOperation)
    expect { scroll.overlay_scrolling? }.to raise_error(compatibility::UnsupportedOperation)
  end

  it 'maps foreground warning spans and use-markup initialization without leaking color into later markup' do
    label = compatibility::Label.new('<span foreground="black">12</span>')
    label.use_markup = true
    expect(label.text).to eq('12')
    expect(label.send(:component_props)[:fragments].first[:foreground]).to eq(r: 0, g: 0, b: 0, a: 1.0)
    label.markup = '<span foreground="#ffbf40" weight="bold">Cleric-only &amp; ready</span>'
    expect(label.send(:component_props)[:fragments].first).to include(emphasis: :strong, foreground: { r: 255, g: 191, b: 64, a: 1.0 })
    label.markup = '<span color="blue" weight="bold">Tip</span>'
    label.markup = '<b>Normal heading</b>'
    expect(label.send(:component_props).keys & %i[foreground fragments]).to be_empty
  end

  it 'rejects malformed, executable and excessive inline markup before changing a live label' do
    label = compatibility::Label.new
    label.markup = '<b>Retained</b><i> style</i>'
    window = compatibility::Window.new
    window.add(label)
    show(window)
    original = label.send(:component_props).dup
    [
      '<i>unclosed', '<i><script>bad</script></i>', '<i onclick="bad">bad</i>',
      '<i><span foreground="url(x)">bad</span></i>', '<i><span foreground="red" style="color:red">bad</span></i>',
      '<i><!--comment--></i>', '<i><?instruction bad?></i>',
      '<!DOCTYPE label [<!ENTITY x "bad">]><i>&x;</i>',
      '<i>' * 17 + 'deep' + '</i>' * 17,
      '<b>x</b><i>y</i>' * 257,
      '<i>' + 'x' * 65_537 + '</i>', '<i>'.b + [255].pack('C') + '</i>'.b
    ].each do |markup|
      expect { label.markup = markup }.to raise_error(compatibility::UnsupportedOperation)
      expect(label.send(:component_props)).to eq(original)
    end
    expect { label.text = 'x' * 65_537 }.to raise_error(Lich::WebUI::SchemaViolationError)
    expect(label.send(:component_props)).to eq(original)
  end

  it 'supports bounded size-only font descriptions while retaining the theme family' do
    pango = scope.const_get(:Pango)
    label = compatibility::Label.new('Timer')
    label.override_font(pango::FontDescription.new('12.5'))
    expect(label.send(:component_props)).to include(font_size: 12.5, font_unit: :pt)
    expect(label.send(:component_props)).not_to have_key(:font_family)
    expect(pango::FontDescription.from_string('14').properties).to eq(font_size: 14.0, font_unit: :pt)
    ['5', '49', '-12', 'NaN', 'Infinity', '12px', '0' * 513].each do |value|
      expect { pango::FontDescription.new(value) }.to raise_error(compatibility::UnsupportedOperation)
    end
  end

  it 'caps label width and requests end ellipsis without shortening the retained content' do
    label = compatibility::Label.new('A long service bonus description')
    expect(label.set_max_width_chars(40).set_ellipsize(:end)).to equal(label)
    window = compatibility::Window.new
    window.add(label)
    show(window)
    label.max_width_chars = 20
    label.ellipsize = :end
    expect(label.session.port.get(label.materialize, :max_width_chars)).to eq(20)
    expect(label.session.port.get(label.materialize, :ellipsize)).to eq('end')
    expect(label.text).to eq('A long service bonus description')
    [0, -1, 1025, 1.5, '40'].each do |width|
      expect { label.set_max_width_chars(width) }.to raise_error(compatibility::UnsupportedOperation)
    end
    expect { label.set_ellipsize(:start) }.to raise_error(compatibility::UnsupportedOperation)
    linked = compatibility::Label.new
    linked.markup = '<a href="https://example.com">Help</a>'
    expect { linked.set_max_width_chars(20) }.to raise_error(compatibility::UnsupportedOperation)
    expect { linked.set_ellipsize(:end) }.to raise_error(compatibility::UnsupportedOperation)
    capped = compatibility::Label.new
    capped.set_max_width_chars(20)
    expect { capped.markup = '<a href="https://example.com">Help</a>' }.to raise_error(compatibility::UnsupportedOperation)
  end

  it 'renders shared combo entry widths, text assignment and tooltip readback in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Priority 14 controls')
    box = compatibility::Box.new(:vertical)
    box.tooltip_text = 'Container help'
    row = compatibility::Box.new(:horizontal)
    row.tooltip_text = 'Horizontal help'
    row.add(compatibility::Label.new('Horizontal caption'))
    profile = compatibility::ComboBoxText.new(entry: true)
    profile.append_text('Profile A')
    profile.append_text('Profile B')
    profile.margin = 20
    profile.child.margin_start = 12
    profile.child.margin_top = 3
    profile.child.width_request = 400
    profile.child.tooltip_text = 'Profile name'
    profile.active_text = 'Profile A'
    material = compatibility::ComboBoxText.new
    %w[bronze iron].each { |text| material.append_text(text) }
    material.active_text = 'bronze'
    material.set_tooltip_text('Material help') unless material.tooltip_text
    status = compatibility::Label.new('Ready')
    update = compatibility::Button.new('Update controls')
    update.signal_connect('clicked') do
      material.active_text = 'iron'
      profile.child.margin = 0
      profile.child.width_request = 320
      profile.child.tooltip_text = 'Updated profile'
      status.text = "#{profile.child.get_tooltip_text} / #{material.active_text}"
    end
    [row, profile, material, status, update].each { |child| box.add(child) }
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority14-controls')
    expect(status.text).to eq('Updated profile / iron')
  end

  it 'renders mixed inline styles and real end truncation in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Priority 11 labels')
    box = compatibility::Box.new(:vertical)
    mixed = compatibility::Label.new
    mixed.markup = '<b>Attack</b>  <i>(optional)</i>'
    mixed.set_max_width_chars(40)
    mixed.set_line_wrap(true)
    warning = compatibility::Label.new
    warning.markup = '<span foreground="#ffbf40" weight="bold" size="large">Cleric-only</span>'
    bonus = compatibility::Label.new('A long service bonus description ' * 8)
    bonus.set_width_request(180)
    bonus.set_max_width_chars(20)
    bonus.set_ellipsize(:end)
    reset = compatibility::Button.new('Reset label')
    reset.signal_connect('clicked') { mixed.text = 'Plain replacement' }
    [mixed, warning, bonus, reset].each { |child| box.add(child) }
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority11-labels')
    expect(mixed.text).to eq('Plain replacement')
  end

  it 'replaces, inserts and deletes literal Unicode text and refuses foreign or out-of-range iterators' do
    buffer = compatibility::TextBuffer.new
    seen = []
    buffer.signal_connect('changed') { seen << buffer.text }
    accent = [233].pack('U')
    buffer.text = "#{accent}\n<literal>"
    expect(buffer.char_count).to eq(11)
    expect(buffer.get_iter_at_line(1).offset).to eq(2)
    buffer.insert(buffer.get_iter_at_offset(1), '!')
    buffer.delete(buffer.get_iter_at_offset(2), buffer.end_iter)
    expect(buffer.get_text).to eq("#{accent}!")
    buffer.text = ''
    expect(seen).to eq(["#{accent}\n<literal>", "#{accent}!\n<literal>", "#{accent}!", ''])
    expect { buffer.insert(compatibility::TextBuffer.new.end_iter, 'wrong') }.to raise_error(compatibility::UnsupportedOperation)
    expect { buffer.get_iter_at_offset(1) }.to raise_error(compatibility::UnsupportedOperation)
    expect { buffer.insert_markup(buffer.end_iter, '<b>lost</b>') }.to raise_error(compatibility::UnsupportedOperation)
  end

  it 'advances the insertion iterator before notifications and preserves it on refusal' do
    buffer = compatibility::TextBuffer.new
    buffer.text = 'ab'
    iterator = buffer.get_iter_at_offset(1)
    offsets = []
    buffer.signal_connect('changed') { offsets << iterator.offset }
    buffer.insert(iterator, [233, 128512].pack('U*'))
    expect(iterator.offset).to eq(3)
    expect(buffer.text.length).to eq(4)
    expect(offsets).to eq([3])
    expect { buffer.insert(iterator, 'x' * 65_537) }.to raise_error(compatibility::UnsupportedOperation)
    expect(iterator.offset).to eq(3)
    expect(buffer.text.length).to eq(4)
  end

  it 'supports the complete append/end-mark/scroll/delete sequence and rejects foreign or retired marks' do
    view = compatibility::TextView.new
    view.editable = false
    buffer = view.buffer
    buffer.text = "old\n" * 999
    3.times do
      iterator = buffer.end_iter
      buffer.insert(iterator, [233].pack('U') + " appended\n")
      expect(iterator.offset).to eq(buffer.char_count)
      expect(buffer.line_count).to eq(1000)
      mark = buffer.create_mark(nil, iterator, false)
      expect(view.scroll_mark_onscreen(mark)).to equal(view)
      expect(buffer.delete_mark(mark)).to equal(buffer)
      expect { view.scroll_mark_onscreen(mark) }.to raise_error(compatibility::UnsupportedOperation)
      expect { buffer.delete_mark(mark) }.to raise_error(compatibility::UnsupportedOperation)
    end
    expect(view.send(:component_props)[:follow]).to be(true)
    expect { buffer.create_mark('named', buffer.end_iter, false) }.to raise_error(compatibility::UnsupportedOperation)
    expect { buffer.create_mark(nil, buffer.start_iter, false) }.to raise_error(compatibility::UnsupportedOperation)
    expect { buffer.create_mark(nil, buffer.end_iter, true) }.to raise_error(compatibility::UnsupportedOperation)
    other = compatibility::TextBuffer.new
    foreign = other.create_mark(nil, other.end_iter, false)
    expect { buffer.delete_mark(foreign) }.to raise_error(compatibility::UnsupportedOperation)
    expect { view.scroll_mark_onscreen(foreign) }.to raise_error(compatibility::UnsupportedOperation)
    mark = buffer.create_mark(nil, buffer.end_iter, false)
    buffer.text = ''
    buffer.insert(buffer.end_iter, 'replacement')
    expect(view.scroll_mark_onscreen(mark)).to equal(view)
    view.buffer = other
    expect { view.scroll_mark_onscreen(mark) }.to raise_error(compatibility::UnsupportedOperation)
    buffer.delete_mark(mark)
    view.destroy
    expect { view.scroll_mark_onscreen(foreign) }.to raise_error(compatibility::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(Object.new)
    expect { other.delete_mark(foreign) }.to raise_error(compatibility::UnsupportedOperation)
  end

  it 'applies selected colors live without changing another table or viewer selection' do
    model = compatibility::ListStore.new(String)
    model.append[0] = 'First'
    model.append[0] = 'Second'
    view = compatibility::TreeView.new(model)
    view.append_column(compatibility::TreeViewColumn.new('Choice', compatibility::CellRendererText.new, text: 0))
    other = compatibility::TreeView.new(model)
    other.append_column(compatibility::TreeViewColumn.new('Other', compatibility::CellRendererText.new, text: 0))
    rgba = scope.const_get(:Gdk)::RGBA
    color = rgba.new(0.2, 0.4, 0.6, 0.5)
    view.override_background_color(:selected, color)
    window = compatibility::Window.new
    window.add(view).add(other)
    page = show(window)
    first, second = connect(page, 'one'), connect(page, 'two')
    table = page.last_render.tree.each.find { |node| node.type == :table }
    key = model.rows.first.key
    send_event(page, first, table, 'selection_change', rows: [key])
    # Drain accepted selection before the explicit color update publishes it.
    # The fake connection has no optimistic DOM and acceptance needs no repaint.
    accepted = Queue.new
    service.runtime.dispatch(owner: owner) { accepted << true }
    expect(accepted.pop(timeout: 2)).to be(true)
    view.override_background_color(:selected, rgba.new(0, 1, 0, 1))
    wait_for { rendered_node(first, :table)['props']['selection_background']['g'] == 255 }
    expect(rendered_node(first, :table)['props']['selected']).to eq([key])
    expect(rendered_node(second, :table)['props']['selected']).to eq([])
    expect(other.send(:component_props)).not_to have_key(:selection_background)
    [:active, :prelight].each do |state|
      expect { view.override_background_color(state, color) }.to raise_error(compatibility::UnsupportedOperation)
    end
    expect { view.override_background_color(:selected, '#fff') }.to raise_error(compatibility::UnsupportedOperation)
    expect(view.send(:component_props)[:selection_background]).to eq(rgba.new(0, 1, 0, 1).to_h)
    view.destroy
    expect { view.override_background_color(:selected, color) }.to raise_error(compatibility::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(Object.new)
    expect { other.override_background_color(:selected, color) }.to raise_error(compatibility::UnsupportedOperation)
  end

  it 'shows end-mark scrolling and live selected fills in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Log and selected color')
    box = compatibility::Box.new(:vertical, 4)
    model = compatibility::ListStore.new(String)
    %w[First Second].each { |value| model.append[0] = value }
    rgba = scope.const_get(:Gdk)::RGBA
    views = 2.times.map do |index|
      view = compatibility::TreeView.new(model)
      view.tooltip_text = index.zero? ? 'Custom selection' : 'Default selection'
      cell = compatibility::CellRendererText.new
      cell.background = '#ffffff'
      column = compatibility::TreeViewColumn.new('Choice', cell, text: 0)
      column.set_cell_data_func(cell) { |_column, renderer, _store, _iter| renderer.foreground_rgba = rgba.new(1, 0, 0, 1) }
      view.append_column(column)
      view.selection.select_iter(model.rows.first)
      view.override_background_color(:selected, rgba.new(0.2, 0.4, 0.6, 1)) if index.zero?
      box.add(view)
      view
    end
    log = compatibility::TextView.new
    log.editable = false
    log.buffer.text = "Initial line\n" * 150
    scroller = compatibility::ScrolledWindow.new
    scroller.set_size_request(400, 100)
    scroller.add(log)
    append = compatibility::Button.new('Append marked line')
    append.signal_connect('clicked') do
      iterator = log.buffer.end_iter
      log.buffer.insert(iterator, "Marked final line\n")
      mark = log.buffer.create_mark(nil, iterator, false)
      log.scroll_mark_onscreen(mark)
      log.buffer.delete_mark(mark)
      views.first.override_background_color(:selected, rgba.new(0, 1, 0, 1))
    end
    clear = compatibility::Button.new('Clear log')
    clear.signal_connect('clicked') { log.buffer.text = '' }
    [scroller, append, clear].each { |widget| box.add(widget) }
    WebUIBrowser.check(service: service, page: show(window.add(box)), scenario: 'priority15-log-style')
  end

  it 'keeps independent buffer ownership and preserves replaced buffers' do
    first = compatibility::TextBuffer.new
    first.text = 'First'
    view = compatibility::TextView.new(first)
    replacement = compatibility::TextBuffer.new
    replacement.text = 'Second'
    view.buffer = replacement
    expect(first.text).to eq('First')
    expect(view.buffer.text).to eq('Second')
    first.text = 'Detached'
    expect(view.buffer.text).to eq('Second')
    expect { compatibility::TextView.new(replacement) }.to raise_error(compatibility::UnsupportedOperation, /bind/)
    expect { replacement.text = 'x' * 65_537 }.to raise_error(compatibility::UnsupportedOperation)
    expect(view.buffer.text).to eq('Second')
  end

  it 'retains bounded read-only log history, replacement and follow-to-end behavior' do
    view = compatibility::TextView.new
    view.buffer.text = 'Before'
    view.editable = false
    expect(view.buffer.text).to eq('Before')
    view.buffer.text = ''
    view.buffer.insert(view.buffer.end_iter, "line\n" * 1001)
    expect(view.buffer.line_count).to eq(1000)
    expect(view.send(:component_type)).to eq(:log)
    expect(view.scroll_to_iter(view.buffer.end_iter, 0.0, true, 0, 0)).to equal(view)
    expect { view.buffer.text = 'x' * 4097 }.to raise_error(compatibility::UnsupportedOperation)
    expect(view.buffer.line_count).to eq(1000)
  end

  it 'keeps editable text and expander state viewer-local and commits them before Save' do
    window = compatibility::Window.new
    expander = compatibility::Expander.new('Options')
    view = compatibility::TextView.new
    view.buffer.text = 'Initial'
    expander.add(view)
    save = compatibility::Button.new('Save')
    observed = Queue.new
    changed = Queue.new
    view.buffer.signal_connect('changed') { view.set_buffer(view.buffer); changed << view.buffer.text }
    expander.signal_connect('notify::expanded') { changed << expander.expanded }
    save.signal_connect('clicked') { observed << [view.buffer.text, expander.expanded]; window.destroy }
    window.add(expander)
    window.add(save)
    page = show(window)
    first, second = connect(page, 'one'), connect(page, 'two')
    input = page.last_render.tree.each.find { |node| node.type == :textarea }
    fold = page.last_render.tree.each.find { |node| node.type == :expander }
    send_event(page, first, input, 'change', value: 'Draft')
    expect(changed.pop(timeout: 2)).to eq('Draft')
    expect(view.buffer.text).to eq('Initial')
    send_event(page, first, fold, 'toggle', open: true)
    expect(changed.pop(timeout: 2)).to be(true)
    wait_for { rendered_node(first, :expander)['props']['open'] }
    expect(rendered_node(second, :expander)['props']['open']).to be(false)
    button = page.last_render.tree.each.find { |node| node.type == :button }
    send_event(page, first, button, 'activate', {}, submission: ['Final text'])
    expect(observed.pop(timeout: 2)).to eq(['Final text', true])
    wait_for { window.destroyed? }
    expect(view.buffer.text).to eq('Final text')
  end

  it 'restores buffer notification context after nested changes and exceptions' do
    buffer = compatibility::TextBuffer.new
    view = compatibility::TextView.new(buffer)
    observed = []
    buffer.signal_connect('changed') do
      observed << buffer.text
      buffer.text = 'Nested' if buffer.text == 'Outer'
      raise 'handler failure' if buffer.text == 'Fail'
    end
    buffer.text = 'Outer'
    expect(observed).to eq(%w[Outer Nested])
    expect { buffer.text = 'Fail' }.to raise_error('handler failure')
    buffer.text = 'Recovered'
    expect(view.buffer.text).to eq('Recovered')
    expect(observed.last).to eq('Recovered')
  end

  it 'refuses browser edits and forged submissions after an editor becomes read-only' do
    window = compatibility::Window.new
    view = compatibility::TextView.new
    view.buffer.text = 'Original'
    save = compatibility::Button.new('Save')
    saved = Queue.new
    save.signal_connect('clicked') { saved << view.buffer.text }
    window.add(view)
    window.add(save)
    page = show(window)
    connection = connect(page, 'reader')
    view.editable = false
    wait_for { rendered_node(connection, :textarea)['props']['read_only'] }
    input = page.last_render.tree.each.find { |node| node.type == :textarea }
    button = page.last_render.tree.each.find { |node| node.type == :button }
    expect(send_event(page, connection, input, 'change', value: 'Forged')).to eq(:refused)
    expect(send_event(page, connection, button, 'activate', {}, submission: ['Forged'])).to eq(:refused)
    expect(saved).to be_empty
    expect(send_event(page, connection, button, 'activate', {}, submission: ['Original'])).to eq(:queued)
    expect(saved.pop(timeout: 2)).to eq('Original')
  end

  it 'reads Pixbuf file metadata through both spellings without creating a page or loading pixels' do
    path = File.join(asset_directory, 'metadata.png')
    File.binwrite(path, [137, 80, 78, 71, 13, 10, 26, 10].pack('C*') + [13].pack('N') + 'IHDR' + [20, 10].pack('NN'))
    [scope::GdkPixbuf::Pixbuf, scope::Gdk::Pixbuf].each do |pixbuf|
      format, width, height = pixbuf.get_file_info(path)
      expect(format.name).to eq('png')
      expect(format).to be_frozen
      expect([width, height]).to eq([20, 10])
      expect(service.registry.pages_for(owner)).to be_empty
    end
    _, width, height = scope::GdkPixbuf::Pixbuf.get_file_info(path)
    image = scope::GdkPixbuf::Pixbuf.new(file: path).scale_simple(width / 2, height / 2)
    expect([image.width, image.height]).to eq([10, 5])
    expect { scope::GdkPixbuf::Pixbuf.get_file_info(nil) }.to raise_error(compatibility::UnsupportedOperation, /get_file_info/)
  end

  it 'authorizes metadata paths before reading bytes and refuses symlink escapes' do
    Dir.mktmpdir('outside-metadata-') do |outside|
      path = File.join(outside, 'outside.png')
      File.binwrite(path, 'unreadable fixture')
      link = File.join(asset_directory, 'linked.png')
      File.symlink(path, link)
      expect(Lich::WebUI::ImageSize).not_to receive(:info)
      [path, link].each do |candidate|
        expect { scope::GdkPixbuf::Pixbuf.get_file_info(candidate) }.to raise_error(Lich::WebUI::Error, /outside/)
      end
    end
  end

  it 'preserves metadata failures for missing, malformed and oversized image files' do
    path = File.join(asset_directory, 'metadata.png')
    expect { scope::GdkPixbuf::Pixbuf.get_file_info(path) }.to raise_error(compatibility::UnsupportedOperation, /operation=file/)
    File.binwrite(path, 'not an image')
    expect { scope::GdkPixbuf::Pixbuf.get_file_info(path) }.to raise_error(ArgumentError, /image header/)
    File.binwrite(path, 'GIF89a' + [0, 10].pack('vv'))
    expect { scope::GdkPixbuf::Pixbuf.get_file_info(path) }.to raise_error(ArgumentError, /dimensions/)
  end

  it 'renders authorized file images, scales without decoding, and clears without a broken source' do
    path = File.join(asset_directory, 'space image.png')
    # PNG signature and IHDR dimensions are enough for the bounded header reader.
    File.binwrite(path, [137, 80, 78, 71, 13, 10, 26, 10].pack('C*') + [13].pack('N') + 'IHDR' + [20, 10].pack('NN'))
    pixbuf = scope::GdkPixbuf::Pixbuf.new(file: path, width: 10, height: 10)
    expect([pixbuf.width, pixbuf.height]).to eq([10, 5])
    scaled = pixbuf.scale_simple(40, 20, :bilinear)
    expect([scaled.width, scaled.height, pixbuf.width]).to eq([40, 20, 10])
    fractional = pixbuf.scale(40.9, 20.1)
    expect([fractional.width, fractional.height]).to eq([40, 20])
    [Float::NAN, Float::INFINITY, -Float::INFINITY, 0.9, 65_536.1, '40'].each do |width|
      expect { pixbuf.scale(width, 20) }.to raise_error(compatibility::UnsupportedOperation)
    end
    expect([pixbuf.width, pixbuf.height]).to eq([10, 5])
    expect { scaled.pixels }.to raise_error(compatibility::UnsupportedOperation)
    expect { pixbuf.scale_simple(0, 5) }.to raise_error(compatibility::UnsupportedOperation)
    window = compatibility::Window.new
    image = compatibility::Image.new(pixbuf: scaled)
    window.add(image)
    page = show(window)
    source = page.last_render.tree.each.find { |node| node.type == :image }.props[:src]
    expect(source).to end_with('/space%20image.png')
    expect(service.file_service.resolve_url(source)).not_to be_nil
    image.clear
    wait_for { page.last_render.tree.each.find { |node| node.type == :image }.props[:src] == '' }
    expect(image.pixbuf).to be_nil
    service.terminate_owner(owner)
    expect(service.file_service.resolve_url(source)).to be_nil
  end

  it 'refuses image paths outside approved roots and never loads a native image library' do
    Dir.mktmpdir('outside-shim-') do |outside|
      path = File.join(outside, 'secret.png')
      File.binwrite(path, 'not read as an image')
      expect { scope::Gdk::Pixbuf.new(path) }.to raise_error(Lich::WebUI::Error, /outside/)
    end
    expect { compatibility::Image.new(file: 'missing.png', pixbuf: Object.new) }.to raise_error(compatibility::UnsupportedOperation)
    expect { scope::GdkPixbuf.const_get(:Loader) }.to raise_error(compatibility::UnsupportedOperation)
  end

  it 'attributes filesystem resolution failures without hiding file-policy refusals' do
    path = File.join(asset_directory, 'missing.png')
    expect { scope::Gdk::Pixbuf.new(path) }
      .to raise_error(compatibility::UnsupportedOperation, /script=pilot\.lic .*operation=file/)
    allow(File).to receive(:realpath).with(path).and_raise(Errno::EACCES)
    expect { scope::Gdk::Pixbuf.new(path) }
      .to raise_error(compatibility::UnsupportedOperation, /operation=file/)
  end

  it 'opens a dynamically created menu only for the originating pointer viewer and dismisses it once' do
    window = compatibility::Window.new
    label = compatibility::Label.new('Choose')
    label.add_events(scope::Gdk::EventMask::BUTTON_PRESS_MASK)
    seen = Queue.new
    menu = nil
    label.signal_connect('button-press-event') do |_widget, event|
      menu = compatibility::Menu.new
      item = compatibility::MenuItem.new('Inspect')
      item.signal_connect('activate') { seen << :activated }
      menu.append(item)
      menu.signal_connect('deactivate') { seen << :dismissed }
      menu.popup(nil, nil, event.button, event.time)
      seen << :opened
    end
    window.add(label)
    page = show(window)
    first, second = connect(page, 'one'), connect(page, 'two')
    node = page.last_render.tree.each.find { |item| item.type == :text }
    send_event(page, first, node, 'pointer_press', x: 120, y: 80, button: 3, time: 1, state: 0)
    expect(seen.pop(timeout: 2)).to eq(:opened)
    wait_for { rendered_node(first, :group)&.dig('props', 'open') }
    expect(rendered_node(first, :group)['props']['popup_position']).to eq([120, 80])
    wait_for { rendered_node(second, :group) }
    expect(rendered_node(second, :group)['props']['open']).to be(false)
    item = page.last_render.tree.each.find { |entry| entry.type == :button }
    send_event(page, first, item, 'activate')
    expect(seen.pop(timeout: 2)).to eq(:activated)
    group = page.last_render.tree.each.find { |entry| entry.type == :group }
    send_event(page, first, group, 'dismiss')
    expect(seen.pop(timeout: 2)).to eq(:dismissed)
    expect { menu.popup_at_pointer }.to raise_error(compatibility::UnsupportedOperation)
    window.destroy
    expect(menu).to be_destroyed
  end

  it 'keeps submenu ownership and ordered check/radio transitions without cross-group mutation' do
    menu = compatibility::Menu.new
    parent = compatibility::MenuItem.new('Nested')
    nested = compatibility::Menu.new
    first = compatibility::RadioMenuItem.new('First', false)
    second = compatibility::RadioMenuItem.new(first, 'Second', false)
    check = compatibility::CheckMenuItem.new('Enabled')
    order = []
    [first, second, check].each do |item|
      nested.append(item)
      item.signal_connect('toggled') { order << [item.label, item.active?] }
    end
    second.signal_connect('activate') { order << :activate }
    parent.submenu = nested
    menu.append(parent)
    second.activate
    expect(order).to eq([['First', false], ['Second', true], :activate])
    expect(check.active?).to be(false)
    expect(nested.toplevel).to equal(menu)
    mnemonic = compatibility::CheckMenuItem.new('Plain', true)
    expect { mnemonic.label = '_Pick' }.to raise_error(compatibility::UnsupportedOperation, /mnemonic/)
    expect(mnemonic.label).to eq('Plain')
    expect { nested.add(menu) }.to raise_error(compatibility::UnsupportedOperation)
    expect { compatibility::Expander.new.add(parent) }.to raise_error(compatibility::UnsupportedOperation)
  end

  it 'replaces live submenus and retires destroyed references without changing the trigger' do
    trigger = compatibility::MenuItem.new('Scale')
    original = compatibility::Menu.new
    original.add(compatibility::MenuItem.new('Original'))
    trigger.submenu = original
    trigger.materialize
    identity = trigger.instance_variable_get(:@handle)
    replacement = compatibility::Menu.new
    replacement.add(compatibility::MenuItem.new('Replacement'))
    port = trigger.session.port
    allow(port).to receive(:replace_child).and_raise(Lich::WebUI::Error, 'injected replacement failure')
    expect { trigger.submenu = replacement }.to raise_error(Lich::WebUI::Error, /injected/)
    expect(trigger.children).to eq([original])
    expect(trigger.submenu).to equal(original)
    expect(replacement.parent).to be_nil
    allow(port).to receive(:replace_child).and_call_original
    trigger.submenu = replacement
    expect(trigger.children).to eq([replacement])
    expect(trigger.submenu).to equal(replacement)
    expect(original.parent).to be_nil
    expect(original).not_to be_destroyed
    expect(trigger.instance_variable_get(:@handle)).to equal(identity)
    other = compatibility::MenuItem.new('Other')
    expect { other.submenu = replacement }.to raise_error(compatibility::UnsupportedOperation)
    expect(trigger.children).to eq([replacement])
    replacement.destroy
    expect(trigger.submenu).to be_nil
    expect(trigger.children).to be_empty
    expect { trigger.activate }.to raise_error(compatibility::UnsupportedOperation)
    third = compatibility::Menu.new
    trigger.submenu = third
    expect(trigger.submenu).to equal(third)
    expect(trigger.instance_variable_get(:@handle)).to equal(identity)
    terminal = compatibility::MenuItem.new('Terminal')
    terminal.materialize
    expect { terminal.submenu = compatibility::Menu.new }.to raise_error(compatibility::UnsupportedOperation)
  end

  it 'inherits bounded underline, bold and color without leaking styles into siblings or replacement' do
    label = compatibility::Label.new
    label.markup = "<span foreground='#d8dee9'><b><u>Group &amp; role</u> plain</b></span> end"
    parts = label.send(:component_props).fetch(:fragments)
    expect(parts[0]).to include(content: 'Group & role', underline: true, emphasis: :strong,
                                foreground: { r: 216, g: 222, b: 233, a: 1.0 })
    expect(parts[1]).not_to have_key(:underline)
    expect(parts[2]).to eq(content: ' end')
    expect { label.markup = '<u onclick="bad">bad</u>' }.to raise_error(compatibility::UnsupportedOperation)
    expect(label.text).to eq('Group & role plain end')
    label.markup = 'Plain'
    expect(label.send(:component_props)).not_to have_key(:fragments)
  end

  it 'retains opposite scrollbar policies and bounds live minimum width independently of height' do
    scroll = compatibility::ScrolledWindow.new
    scroll.set_policy(:never, :always)
    scroll.set_hscrollbar_policy(:AUTOMATIC)
    expect([scroll.hscrollbar_policy, scroll.vscrollbar_policy]).to eq(%i[automatic always])
    scroll.vscrollbar_policy = :never
    scroll.min_content_height = 120
    scroll.min_content_width = 300
    window = compatibility::Window.new
    window.add(scroll)
    viewer = connect(show(window), 'scroll-width')
    expect(rendered_node(viewer, :scroll)['props']).to include('min_width' => 300, 'min_height' => 120)
    identity = rendered_node(viewer, :scroll)['cid']
    scroll.min_content_width = -1
    wait_for { rendered_node(viewer, :scroll).dig('props', 'min_width') == 0 }
    expect(scroll.min_content_width).to eq(-1)
    expect(rendered_node(viewer, :scroll)['cid']).to eq(identity)
    [-2, 65_537, 0.5, '300'].each do |value|
      expect { scroll.min_content_width = value }.to raise_error(compatibility::UnsupportedOperation)
    end
    expect { scroll.set_policy(:always, :unknown) }.to raise_error(compatibility::UnsupportedOperation)
    expect([scroll.hscrollbar_policy, scroll.vscrollbar_policy]).to eq(%i[automatic never])
  end

  it 'renders successor fragments, live submenus and Notebook callbacks in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Priority 16 successor controls')
    box = compatibility::Box.new(:vertical)
    heading = compatibility::Label.new
    heading.markup = "<span foreground='#d8dee9'><b><u>Group heading</u></b></span>"
    frame = compatibility::Frame.new('Etched frame')
    frame.shadow_type = :etched_in
    scroll = compatibility::ScrolledWindow.new
    scroll.min_content_width = 300
    scroll.min_content_height = 40
    scroll.add(heading)
    frame.add(scroll)
    notebook = compatibility::Notebook.new
    notebook.append_page(compatibility::Label.new('First content'), compatibility::Label.new('First'))
    notebook.append_page(compatibility::Label.new('Second content'), compatibility::Label.new('Second'))
    status = compatibility::Label.new('No page change')
    seen = []
    notebook.signal_connect('switch-page') { |widget, page, index| seen << [widget, page, index]; status.text = "Page #{index}: #{page.text}" }
    action = compatibility::Label.new('Open choices')
    menu, nested = compatibility::Menu.new, compatibility::Menu.new
    trigger = compatibility::MenuItem.new('Choices')
    nested.add(compatibility::MenuItem.new('Old choice'))
    trigger.submenu = nested
    menu.add(trigger)
    action.signal_connect('button-press-event') { |_widget, event| menu.popup_at_pointer(event) }
    rebuild = compatibility::Button.new('Replace choices')
    rebuild.signal_connect('clicked') do
      nested.destroy
      replacement = compatibility::Menu.new
      item = compatibility::MenuItem.new('New choice')
      item.signal_connect('activate') { status.text = 'New choice activated' }
      replacement.add(item)
      trigger.submenu = replacement
    end
    [frame, notebook, status, action, rebuild].each { |widget| box.add(widget) }
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority16-successor-controls')
    expect(seen.map(&:last)).to eq([1])
    expect(status.text).to eq('New choice activated')
  end

  it 'allocates only expanding columns and protects insensitive combo cells in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    model = compatibility::ListStore.new(String, String, TrueClass)
    first, second = model.append, model.append
    first[0], first[1], first[2] = 'Active skill', 'Old', true
    second[0], second[1], second[2] = 'Disabled skill', 'Old', false
    options = compatibility::ListStore.new(String)
    options.append[0] = 'Old'
    options.append[0] = 'New'
    view = compatibility::TreeView.new(model)
    skill = compatibility::TreeViewColumn.new('Skill', compatibility::CellRendererText.new, text: 0)
    skill.expand = true
    skill.resizable = true
    editor = compatibility::CellRendererCombo.new
    editor.model = options
    editor.text_column = 0
    editor.editable = true
    editor.has_entry = false
    choice = compatibility::TreeViewColumn.new('Choice', editor, text: 1, sensitive: 2)
    editor.signal_connect('edited') { |_cell, path, value| model.get_iter(path)[1] = value }
    [skill, choice].each { |column| view.append_column(column) }
    view.set_tooltip_text('Selective expansion')
    shared = compatibility::TreeView.new(model)
    shared.set_tooltip_text('Shared expansion')
    %w[First Second Fixed].each_with_index do |name, index|
      column = compatibility::TreeViewColumn.new(name, compatibility::CellRendererText.new, text: 0)
      column.expand = index < 2
      column.min_width = index == 0 ? 80 : 120
      column.fixed_width = 150 if index == 2
      shared.append_column(column)
    end
    window = compatibility::Window.new('Priority 16 successor columns')
    box = compatibility::Box.new(:vertical)
    box.add(view)
    box.add(shared)
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority16-successor-columns')
    expect(first[1]).to eq('New')
    expect(second[1]).to eq('Old')
  end

  it 'shares Label selectability validation and validates combined EventBox crossing masks atomically' do
    label = compatibility::Label.new('Selectable')
    expect(label.selectable = true).to be(true)
    expect(label.set_selectable(false)).to equal(label)
    expect { label.selectable = :yes }.to raise_error(compatibility::UnsupportedOperation)
    box = compatibility::EventBox.new.add(label)
    masks = scope::Gdk::EventMask
    expect(box.add_events(masks::ENTER_NOTIFY_MASK | masks::LEAVE_NOTIFY_MASK)).to equal(box)
    expect { box.add_events(masks::ENTER_NOTIFY_MASK | (1 << 14)) }.to raise_error(compatibility::UnsupportedOperation)
    expect { compatibility::Layout.new.add_events(masks::BUTTON_PRESS_MASK) }.not_to raise_error
    calls = Queue.new
    box.signal_connect('enter-notify-event') { |widget, event| calls << [widget, event.event_type] }
    box.signal_connect('leave-notify-event') { |widget, event| calls << [widget, event.event_type] }
    window = compatibility::Window.new
    window.add(box)
    page = show(window)
    viewer = connect(page, 'crossings')
    node = page.last_render.tree.each.find { |item| item.type == :stack }
    send_event(page, viewer, node, 'pointer_enter')
    expect(calls.pop(timeout: 2)).to eq([box, :enter_notify])
    send_event(page, viewer, node, 'pointer_leave')
    expect(calls.pop(timeout: 2)).to eq([box, :leave_notify])
  end

  it 'retains EventBox hover through redraw and sends iterator-backed combo choices in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Priority 16 hover and choices')
    outer, inner = compatibility::Box.new(:vertical), compatibility::Box.new(:vertical)
    box = compatibility::EventBox.new.add(inner)
    counts = [0, 0]
    status = compatibility::Label.new('Hover 0/0')
    box.add_events(scope::Gdk::EventMask::ENTER_NOTIFY_MASK | scope::Gdk::EventMask::LEAVE_NOTIFY_MASK)
    box.signal_connect('enter-notify-event') { counts[0] += 1; status.text = "Hover #{counts.join('/')}" }
    box.signal_connect('leave-notify-event') { counts[1] += 1; status.text = "Hover #{counts.join('/')}" }
    first, second = compatibility::Label.new('Hover first'), compatibility::Label.new('Hover second')
    refresh = compatibility::Button.new('Refresh hovered box')
    refresh.signal_connect('clicked') { first.text = 'Hover refreshed' }
    [first, second, refresh].each { |widget| inner.add(widget) }
    model = compatibility::ListStore.new(String)
    row = model.append
    row[0] = 'Original'
    choices = compatibility::ListStore.new(String, Integer)
    [['Original', 0], ['Duplicate', 42], ['Duplicate', 99]].each do |text, number|
      choice = choices.append
      choice[0], choice[1] = text, number
    end
    renderer = compatibility::CellRendererCombo.new
    renderer.model = choices
    renderer.editable = true
    selected = compatibility::Label.new('No choice')
    renderer.signal_connect('changed') { |_cell, path, choice| model.get_iter(path)[0] = choice[0]; selected.text = "Choice #{choice[1]}" }
    view = compatibility::TreeView.new(model)
    view.append_column(compatibility::TreeViewColumn.new('Choice', renderer, text: 0))
    [box, status, view, selected].each { |widget| outer.add(widget) }
    window.add(outer)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority16-hover-choice')
    expect(counts).to eq([2, 2])
    expect(row[0]).to eq('Duplicate')
    expect(selected.text).to eq('Choice 99')
  end

  it 'rebuilds combo callbacks and changes hidden Notebook pages through their real widgets in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Priority16 facade follow-ups')
    box = compatibility::Box.new(:vertical)
    combo = compatibility::ComboBoxText.new
    combo.append_text('Original')
    calls = []
    old = combo.signal_connect('changed') { calls << :stale }
    combo.active = 0
    calls.clear
    status = compatibility::Label.new('No choice')
    rebuild = compatibility::Button.new('Rebuild choices')
    rebuild.signal_connect('clicked') do
      combo.signal_handler_disconnect(old)
      combo.remove_all
      combo.append_text('Rebuilt')
      combo.signal_connect('changed') { calls << :new; status.text = combo.active_text }
    end
    notebook = compatibility::Notebook.new
    first, second = compatibility::Label.new('Main content'), compatibility::Label.new('Profession content')
    notebook.append_page(first, compatibility::Label.new('Main'))
    notebook.append_page(second, compatibility::Label.new('Profession'))
    notebook.get_nth_page(1).no_show_all = true
    notebook.get_nth_page(1).hide
    reveal = compatibility::Button.new('Show profession')
    identities = []
    reveal.signal_connect('clicked') { identities << notebook.get_nth_page(1).equal?(second); notebook.get_nth_page(1).no_show_all = false; notebook.get_nth_page(1).show }
    hide = compatibility::Button.new('Hide profession')
    hide.signal_connect('clicked') { identities << notebook.get_nth_page(1).equal?(second); notebook.get_nth_page(1).no_show_all = true; notebook.get_nth_page(1).hide }
    [combo, rebuild, status, notebook, reveal, hide].each { |widget| box.add(widget) }
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority16-two-facades')
    expect(calls).to eq([:new])
    expect(identities).to eq([true, true])
    expect(second.visible?).to be(false)
  end
  it 'updates and clears container tooltips while retaining selection and scroll in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Container tooltips')
    box = compatibility::Box.new(:vertical)
    notebook, scroll = compatibility::Notebook.new, compatibility::ScrolledWindow.new
    content = compatibility::Box.new(:vertical)
    40.times { |index| content.add(compatibility::Label.new("Tooltip content #{index}")) }
    scroll.set_size_request(300, 140)
    scroll.add_with_viewport(content)
    notebook.append_page(compatibility::Label.new('First content'), compatibility::Label.new('First'))
    notebook.append_page(scroll, compatibility::Label.new('Second'))
    [notebook, scroll].each { |widget| widget.set_tooltip_text(nil) }
    assign = compatibility::Button.new('Assign tooltips')
    clear = compatibility::Button.new('Clear tooltips')
    identities = []
    assign.signal_connect('clicked') do
      identities << notebook.get_nth_page(1).equal?(scroll)
      [notebook, scroll].each { |widget| widget.tooltip_text = '<literal help>' }
    end
    clear.signal_connect('clicked') { [notebook, scroll].each { |widget| widget.set_tooltip_text(nil) } }
    [notebook, assign, clear].each { |widget| box.add(widget) }
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority16-tooltips')
    expect(identities).to eq([true])
  end
  it 'renders title typography and retains scrolling across overlay preference changes in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    gtk = compatibility
    glyph = [0x2694].pack('U')
    window = gtk::Window.new('Combatical typography')
    root = gtk::Box.new(:vertical)
    title = gtk::Label.new
    title.markup = "<span font_desc='18' weight='bold' foreground='#D4AF37'>#{glyph} </span>" \
                   "<span font_desc='22' weight='heavy' foreground='#D4AF37' letter_spacing='4096'>COMBATICAL</span>" \
                   "<span font_desc='18' weight='bold' foreground='#D4AF37'> #{glyph}</span>"
    scroll = gtk::ScrolledWindow.new
    scroll.set_overlay_scrolling(true)
    scroll.set_policy(:never, :automatic)
    scroll.set_size_request(320, 100)
    content = gtk::Box.new(:vertical)
    50.times { |index| content.add(gtk::Label.new("Scroll line #{index}")) }
    scroll.add_with_viewport(content)
    status = gtk::Label.new('Overlay true')
    toggle = gtk::Button.new('Toggle overlay preference')
    toggle.signal_connect('clicked') { scroll.overlay_scrolling = !scroll.overlay_scrolling?; status.text = "Overlay #{scroll.overlay_scrolling?}" }
    reset = gtk::Button.new('Reset title')
    reset.signal_connect('clicked') { title.text = 'Plain replacement' }
    [title, scroll, toggle, status, reset].each { |widget| root.add(widget) }
    window.add(root)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority17-title-scroll')
  end

  it 'moves ability widgets between containers without firing callbacks for cancelled drags in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    gtk = compatibility
    window = gtk::Window.new('Combatical widget drag fixture')
    root = gtk::Box.new(:vertical)
    row = gtk::Box.new(:horizontal)
    pool, assigned = gtk::Box.new(:vertical), gtk::Box.new(:vertical)
    pool.add(gtk::Label.new('Ability pool'))
    assigned.add(gtk::Label.new('Assigned abilities'))
    [pool, assigned].each { |box| box.set_size_request(240, 180); row.add(box) }
    ability = gtk::EventBox.new
    ability.add(gtk::Label.new('Spirit Barrier'))
    pool.add(ability)
    descriptor = gtk::TargetEntry.new('text/plain', :same_app, 0)
    ability.drag_source_set(:button1, [descriptor], :move)
    status = gtk::Label.new('Moves 0; unlocked')
    calls, moves = [], 0
    ability.signal_connect('button-release-event') { calls << :released }
    ability.signal_connect('drag-begin') { calls << :begin }
    ability.signal_connect('drag-data-get') { |_widget, _context, data| calls << :get; data.set_text('Spirit Barrier') }
    ability.signal_connect('drag-end') { calls << :end; status.text = "Moves #{moves}; unlocked" }
    [pool, assigned].each do |target|
      target.drag_dest_set(gtk::DestDefaults::MOTION, [descriptor], :move)
      target.signal_connect('drag-motion') { calls << :motion }
      target.signal_connect('drag-drop') do |_widget, _context, _x, y|
        calls << :drop
        index = target.children.index { |child| y < child.allocation.y + child.allocation.height / 2.0 } || target.children.length
        ability.parent.remove(ability)
        target.add(ability)
        target.reorder_child(ability, index)
        moves += 1
      end
      target.signal_connect('drag-data-received') { |_widget, _context, _x, _y, data| calls << [:received, data.text] }
      target.signal_connect('drag-leave') { calls << :leave }
    end
    ticker = gtk::Label.new('Tick 0')
    release = gtk::EventBox.new
    release.add(gtk::Label.new('Release refresh target'))
    release_status = gtk::Label.new('Releases 0')
    releases = 0
    release.signal_connect('button-release-event') { releases += 1; release_status.text = "Releases #{releases}" }
    root.add(row); root.add(status); root.add(ticker); root.add(release); root.add(release_status); window.add(root)
    tick = 0
    scope.const_get(:GLib)::Timeout.add(25) { tick += 1; ticker.text = "Tick #{tick}"; true }
    page = show(window)
    overtaken = 0
    phases = []
    allow(service.runtime).to receive(:log).and_wrap_original do |method, level, message|
      phases << message if message.match?(/\AWebUI (widget_drop|pointer_release) phase=/)
      method.call(level, message)
    end
    # Force the previously flaky wire ordering for every browser drop/release:
    # even a retry would be overtaken. The real timer and native drag stay active.
    allow(service.runtime).to receive(:handle).and_wrap_original do |method, connection, message|
      if message[:type] == 'event' && %w[widget_drop pointer_release].include?(message[:event])
        2.times { service.runtime.refresh(page) }
        overtaken += 1
      end
      method.call(connection, message)
    end
    begin
      WebUIBrowser.check(service: service, page: page, scenario: 'priority17-widget-drag')
    rescue RuntimeError => error
      raise RuntimeError, "#{error.message}\nWidget server admission: \n#{phases.join("\n")}", cause: error
    end
    expect(overtaken).to eq(3)
    %w[widget_drop pointer_release].zip([2, 1]).each do |event, count|
      expect(phases.grep(/#{event} phase=queued/).length).to eq(count)
      expect(phases.grep(/#{event} phase=completed/).length).to eq(count)
    end
    expect(calls).to eq([:begin, :motion, :get, :drop, [:received, 'Spirit Barrier'], :leave, :end] * 2)
    expect(releases).to eq(1)
    expect(ability.parent).to equal(pool)
  end

  it 'rebuilds live combo options and selects a new duplicate row in one callback in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Combo rebuild')
    box = compatibility::Box.new(:vertical)
    combo = compatibility::ComboBoxText.new
    combo.append_text('Old')
    combo.active = 0
    status = compatibility::Label.new('Not rebuilt')
    rebuild = compatibility::Button.new('Rebuild combo')
    rebuild.signal_connect('clicked') do
      combo.remove_all
      2.times { combo.append_text('All') }
      combo.set_active(1) if combo.model.iter_n_children(nil).positive?
      status.text = "Selected #{combo.active}: #{combo.active_text}"
    end
    clear = compatibility::Button.new('Clear combo')
    clear.signal_connect('clicked') { combo.remove_all; combo.active = -1; status.text = "Cleared #{combo.active}" }
    [combo, rebuild, clear, status].each { |widget| box.add(widget) }
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority16-combo-rebuild')
  end
  it 'batches wheel bursts and keeps optional signals and additive cell bindings in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    window = compatibility::Window.new('Priority16 review fixes')
    box = compatibility::Box.new(:vertical)
    scroll, layout = compatibility::ScrolledWindow.new, compatibility::Layout.new
    scroll.set_size_request(300, 120)
    content = compatibility::Label.new('Wheel burst surface')
    content.set_size_request(800, 6000)
    layout.put(content, 0, 0)
    wheel_calls = []
    layout.signal_connect('scroll-event') { |_widget, event| sleep 0.02; wheel_calls << event.deltas; false }
    scroll.add(layout)
    entry = compatibility::Entry.new
    entry.placeholder_text = 'Unsent entry'
    entry_changes = []
    entry.signal_connect('changed') { entry_changes << entry.text }
    first = compatibility::RadioButton.new('First plain radio')
    second = compatibility::RadioButton.new(first, 'Second plain radio')
    model = compatibility::ListStore.new(String, TrueClass, TrueClass, String)
    row = model.append
    ['Old', false, true, 'Mapped'].each_with_index { |value, index| row[index] = value }
    renderer = compatibility::CellRendererText.new
    renderer.editable = true
    column = compatibility::TreeViewColumn.new('Bound', renderer, text: 0, background_set: 2)
    column.add_attribute(renderer, 'sensitive', 1)
    column.add_attribute(renderer, 'text', 3)
    view = compatibility::TreeView.new(model)
    view.append_column(column)
    [scroll, entry, first, second, view].each { |widget| box.add(widget) }
    window.add(box)
    WebUIBrowser.check(service: service, page: show(window), scenario: 'priority16-review')
    expect(wheel_calls).to eq([[0, 200]])
    expect(entry_changes).to be_empty
  end
  it 'keeps native radio activation current across redraws without a submission scope in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    observed, activations = [], 0
    page = service.registry.register(Lich::WebUI::Page.new(owner: owner, id: 'native-radio-order', title: 'Native radio ordering') do
      status = text(key: 'status', content: 'Waiting')
      radio_option(key: 'one', group: 'choice', label: 'Native first', checked: true,
                   on: { change: ->(event) { observed << [:one, event.payload[:value]] } })
      radio_option(key: 'two', group: 'choice', label: 'Native second', checked: false,
                   on: { change: lambda { |event|
                     observed << [:two, event.payload[:value]]
                     event.page.set(status.cid, :content, 'Changed')
                   }, activate: lambda { |event|
                     selected = event.page.get(event.component.cid, :checked, viewer: event.viewer_id)
                     observed << [:activate, selected]
                     activations += 1
                     event.page.set(status.cid, :content, "Native #{selected} #{activations}")
                   } })
    end)
    WebUIBrowser.check(service: service, page: page, scenario: 'pr64-native-radio')
    expect(observed).to eq([[:one, false], [:two, true], [:activate, true], [:activate, true]])
  end

  %i[height width].each do |axis|
    it "writes scroller minimum #{axis} before retaining the new request and preserves reset semantics" do
      scroll = compatibility::ScrolledWindow.new
      setter, getter, property = :"set_min_content_#{axis}", :"min_content_#{axis}", :"min_#{axis}"
      expect(scroll.public_send(getter)).to eq(-1)
      expect(scroll.public_send(setter, 120)).to equal(scroll)
      show(compatibility::Window.new.add(scroll))
      handle, port = scroll.materialize, scroll.session.port
      fail_write = true
      seen = []
      allow(port).to receive(:set).and_wrap_original do |method, *args|
        if args[0] == handle && args[1] == property
          seen << scroll.public_send(getter)
          raise IOError, 'synthetic minimum write failure' if fail_write
        end
        method.call(*args)
      end

      expect { scroll.public_send(setter, 250) }.to raise_error(IOError, 'synthetic minimum write failure')
      expect([scroll.public_send(getter), port.get(handle, property)]).to eq([120, 120])
      fail_write = false
      expect(scroll.public_send(setter, -1)).to equal(scroll)
      expect([scroll.public_send(getter), port.get(handle, property)]).to eq([-1, 0])
      expect(seen).to eq([120, 120])
      [0, 65_536].each { |value| expect(scroll.public_send(setter, value)).to equal(scroll) }
      [-2, 65_537, nil, '5', 0.5].each do |value|
        expect { scroll.public_send(setter, value) }.to raise_error(compatibility::UnsupportedOperation, /operation=#{setter}/)
      end
      scroll.destroy
      expect(scroll.public_send(getter)).to eq(65_536)
      expect { scroll.public_send(setter, 1) }.to raise_error(compatibility::UnsupportedOperation, /operation=#{setter}/)
    end
  end

  %i[Frame Expander].each do |kind|
    it "preserves #{kind} caption refresh guards, returns and partial state after a refused write" do
      subject = compatibility.const_get(kind).new('Initial')
      caption = subject.label_widget
      show(compatibility::Window.new.add(subject))
      handle, port = subject.materialize, subject.session.port
      writes = []
      fail_write = false
      allow(port).to receive(:set).and_wrap_original do |method, *args|
        if args[0] == handle && args[1] == :label
          writes << args.last
          raise IOError, 'synthetic caption write failure' if fail_write
        end
        method.call(*args)
      end
      foreign = compatibility::Label.new('Foreign')
      foreign.set_markup('<b>Foreign</b>')
      expect(subject.send(:refresh_caption, foreign)).to be_nil
      expect(subject.send(:refresh_caption, caption)).to be_nil
      expect(writes).to be_empty
      expect(Lich).not_to have_received(:log).with(/compatibility (frame|expander)_caption_style/)

      fail_write = true
      expect { caption.text = 'Changed' }.to raise_error(IOError, 'synthetic caption write failure')
      expect([caption.text, subject.label]).to eq(['Changed', 'Initial'])
      fail_write = false
      expect(subject.send(:refresh_caption, caption)).to equal(subject)
      expect(subject.label).to eq('Changed')
      subject.destroy
      count = writes.length
      expect(subject.send(:refresh_caption, caption)).to be_nil
      expect(writes.length).to eq(count)
    end
  end
end
