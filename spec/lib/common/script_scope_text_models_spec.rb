# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require_relative '../../../lib/common/script_scope/gtk/session'
require_relative '../../../lib/common/script_scope/gtk/widgets'
require_relative '../../../lib/common/script_scope/gtk/models'
require_relative '../../../lib/common/script_scope/gtk/tree_view'
require_relative '../../../lib/common/script_scope/gtk/text'
require_relative '../../../lib/common/script_scope/gtk/combo_box'
require_relative '../../../lib/common/script_scope/gtk/menus'
require_relative '../../../lib/common/script_scope/gtk/transfers'

# Model, table and text boundaries. A recording port stands in for core.
RSpec.describe 'script compatibility models, tables and text' do
  port_class = Class.new do
    attr_reader :sets

    def initialize
      @sets = []
      @values = {}
    end

    def create(_type, _props) = Object.new
    def attach(*) = nil
    def detach(*) = nil
    def destroy(_handle) = nil
    def bind(*) = 'binding'
    def schema(type) = Lich::WebUI::Contract.schema(type)

    def set(handle, property, value)
      @sets << [property, value]
      @values[[handle, property]] = value
    end

    def get(handle, property) = @values[[handle, property]]
  end

  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name, :thread_group).new('models.lic', ThreadGroup.new) }
  let(:port) { port_class.new }
  let(:session) { gtk::Session.new(owner) }
  let(:limit) { Lich::WebUI::Contract::BOUNDS[:table_rows] }

  before do
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter).and_return(port)
    allow(Lich::WebUI).to receive(:callback_queue).and_return(proc { |&work| work.call })
    allow(Lich).to receive(:log)
    allow(gtk).to receive(:session) { session }
  end

  def log_view(buffer = gtk::TextBuffer.new)
    view = gtk::TextView.new(buffer)
    view.set_editable(false)
    view
  end

  # Byte-built fixtures keep this source ASCII-only.
  def bytes(*values) = values.pack('C*')
  def utf8(binary) = binary.dup.force_encoding(Encoding::UTF_8)

  it 'stores binary-tagged UTF-8 cells as UTF-8 and refuses other bytes without changing the row' do
    store = gtk::ListStore.new(String)
    view = gtk::TreeView.new(store)
    view.append_column(gtk::TreeViewColumn.new('Name', gtk::CellRendererText.new, text: 0))
    view.materialize
    iter = store.append
    cafe = 'caf'.b + bytes(0xC3, 0xA9)
    invalid = 'caf'.b + bytes(0xFF)

    store.set_value(iter, 0, cafe)
    value = store.get_value(iter, 0)
    expect([value, value.encoding]).to eq([utf8(cafe), Encoding::UTF_8])
    expect(port.sets.last[1].first[:cells].values).to eq([utf8(cafe)])
    [invalid, utf8(invalid)].each do |rejected|
      expect { store.set_value(iter, 0, rejected) }.to raise_error(gtk::ModelValueError, /actual=non-UTF-8 String/)
    end
    expect(store.get_value(iter, 0)).to eq(utf8(cafe))
  end

  it 'admits binary-tagged UTF-8 text into a buffer and refuses other bytes without editing it' do
    buffer = gtk::TextBuffer.new
    cafe = utf8('caf'.b + bytes(0xC3, 0xA9))
    naive = 'na'.b + bytes(0xC3, 0xAF) + 've'.b
    resume = 'r'.b + bytes(0xC3, 0xA9) + 'sum'.b + bytes(0xC3, 0xA9)
    buffer.text = "#{cafe} "

    buffer.insert(buffer.end_iter, naive)
    expect(buffer.text).to eq("#{cafe} #{utf8(naive)}")
    buffer.text = resume
    expect([buffer.text, buffer.text.encoding]).to eq([utf8(resume), Encoding::UTF_8])
    expect { buffer.insert(buffer.end_iter, bytes(0xFF)) }.to raise_error(gtk::UnsupportedOperation, /operation=insert/)
    expect { buffer.text = bytes(0xFF) }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
    expect(buffer.text).to eq(utf8(resume))
  end

  it 'leaves an editor intact when log conversion refuses, and degrades long history' do
    long_line = 'x' * (Lich::WebUI::Contract::BOUNDS[:log_line] + 1)
    view = gtk::TextView.new
    view.buffer.text = "#{long_line}\nshort"

    expect { view.set_editable(false) }.to raise_error(gtk::UnsupportedOperation, /class=\S*TextView operation=editable=/)
    expect([view.send(:log?), view.editable?, view.send(:component_type), view.buffer.text]).to eq([false, true, :textarea, "#{long_line}\nshort"])

    lines = Array.new(gtk::TextBuffer::MAX_LINES + 5) { |index| "line #{index}" }
    view.buffer.text = lines.join("\n")
    view.set_editable(false)
    expect([view.send(:log?), view.editable?, view.buffer.text]).to eq([true, false, lines.last(gtk::TextBuffer::MAX_LINES).join("\n")])
  end

  it 'releases a destroyed view buffer with its text so a replacement view can bind it' do
    buffer = gtk::TextBuffer.new
    view = gtk::TextView.new(buffer)
    buffer.text = 'kept'

    view.destroy
    expect(view.destroy).to equal(view)
    replacement = gtk::TextView.new(buffer)
    expect([replacement.buffer, buffer.text]).to eq([buffer, 'kept'])
    buffer.text = 'next'
    expect(replacement.send(:buffer_text)).to eq('next')
  end

  context 'when a signal callback destroys the window holding an editor' do
    retiring_port = Class.new(port_class) do
      attr_reader :bindings, :retired_reads

      def bind(handle, event, callback) = (@bindings ||= {})[[handle, event]] = callback
      def seed(handle, property, value) = @values[[handle, property]] = value
      # Like the core adapter, retiring the root retires every subtree handle.
      def destroy(_handle) = @retired = true

      def get(handle, property)
        return super unless @retired

        (@retired_reads ||= []) << [property, 'handle is already destroyed']
        raise Lich::WebUI::Error, 'handle is already destroyed'
      end
    end
    let(:port) { retiring_port.new }

    it 'completes teardown and keeps the last editor text for a replacement view' do
      logs = []
      allow(Lich).to receive(:log) { |message| logs << message }
      buffer = gtk::TextBuffer.new
      buffer.text = 'saved'
      window = gtk::Window.new('form')
      box = gtk::VBox.new
      view = gtk::TextView.new(buffer)
      close = gtk::Button.new('Close')
      box.add(view)
      box.add(close)
      window.add(box)
      window.materialize
      port.seed(view.materialize, :value, 'typed')
      closed = []
      window.signal_connect('destroy') { closed << :window }
      close.signal_connect('clicked') { window.destroy }

      port.bindings.fetch([close.materialize, :activate]).call(Struct.new(:viewer_id, :payload).new('viewer', {}))

      expect(port.retired_reads).to be_nil
      expect(logs.grep(/callback failed/)).to be_empty
      expect([window.destroyed?, view.destroyed?, closed]).to eq([true, true, [:window]])
      expect(buffer.text).to eq('typed')
      replacement = gtk::TextView.new(buffer)
      expect([replacement.buffer, replacement.send(:buffer_text)]).to eq([buffer, 'typed'])
    end
  end

  it 'refuses out-of-capacity path and child indices with attribution while missing rows stay nil' do
    store = gtk::TreeStore.new(String)
    store.append
    huge = 2**64

    [huge, [0, huge], "0:#{huge}", limit, [limit]].each do |path|
      expect { store.get_iter(path) }.to raise_error(gtk::UnsupportedOperation, /TreePath operation=new/)
    end
    expect { store.iter_nth_child(nil, huge) }.to raise_error(gtk::UnsupportedOperation, /operation=iter_nth_child/)
    expect { store.iter_nth_child(nil, limit) }.to raise_error(gtk::UnsupportedOperation, /operation=iter_nth_child/)
    expect([store.get_iter(limit - 1), store.get_iter('0:5'), store.iter_nth_child(nil, limit - 1)]).to eq([nil, nil, nil])
    expect(gtk::TreePath.new(limit - 1).indices).to eq([limit - 1])
  end

  it 'answers selection membership without rebuilding the model rows' do
    store = gtk::ListStore.new(String)
    first, second = store.append, store.append
    view = gtk::TreeView.new(store)
    view.selection.select_iter(first)
    foreign = gtk::ListStore.new(String).append
    allow(store).to receive(:rows).and_call_original

    expect(view.selection.iter_is_selected?(first)).to be(true)
    expect(view.selection.iter_is_selected?(second)).to be(false)
    expect(view.selection.iter_is_selected?(foreign)).to be(false)
    expect([view.selection.path_is_selected?('0'), view.selection.path_is_selected?('1'), view.selection.path_is_selected?('5')]).to eq([true, false, false])
    expect(store).not_to have_received(:rows)
  end

  it 'reports a removed row as unselected even while viewer state still names it' do
    store = gtk::ListStore.new(String)
    store.append
    view = gtk::TreeView.new(store)
    stale = store.get_iter('0')
    store.remove(store.get_iter('0'))
    allow(view).to receive(:view_state).with(:selected).and_return([stale.key])

    expect(view.selection.iter_is_selected?(stale)).to be(false)
  end

  it 'keeps a valid log tail when only discarded lines are overlong' do
    view = log_view
    long_line = 'x' * (Lich::WebUI::Contract::BOUNDS[:log_line] + 1)
    tail = Array.new(gtk::TextBuffer::MAX_LINES) { |index| "line #{index}" }

    view.buffer.text = ([long_line] + tail).join("\n")
    expect(view.buffer.text).to eq(tail.join("\n"))
    expect { view.buffer.text = (tail + [long_line]).join("\n") }.to raise_error(gtk::UnsupportedOperation, /operation=text/)
    expect(view.buffer.text).to eq(tail.join("\n"))
  end

  it 'keeps a retained iterator as a current-bounds offset across edits' do
    buffer = gtk::TextBuffer.new
    buffer.text = 'abcdef'
    iter = buffer.get_iter_at_offset(4)

    buffer.text = 'XYZabcdef'
    expect(buffer.get_text(buffer.start_iter, iter)).to eq('XYZa')
    buffer.text = 'ab'
    expect { buffer.get_text(buffer.start_iter, iter) }.to raise_error(gtk::UnsupportedOperation, /operation=get_text/)
    expect { buffer.insert(gtk::TextBuffer.new.start_iter, 'x') }.to raise_error(gtk::UnsupportedOperation, /operation=insert/)
  end

  it 'leaves no row behind when a combo text append, prepend or insert is refused' do
    invalid = bytes(0xFF)
    overlong = 'x' * (Lich::WebUI::Contract::BOUNDS[:short_text] + 1)
    cafe = 'caf'.b + bytes(0xC3, 0xA9)
    combo = gtk::ComboBox.new
    combo.append_text('ok')
    labels = -> { combo.model.rows.map { |iter| iter[0] } }
    revision = combo.model.revision

    [invalid, utf8(invalid), overlong].each do |rejected|
      { append_text: [rejected], prepend_text: [rejected], insert_text: [0, rejected], append: ['id', rejected] }.each do |operation, args|
        expect { combo.public_send(operation, *args) }.to raise_error(gtk::UnsupportedOperation, /operation=#{operation}/)
      end
    end
    expect([labels.call, combo.model.revision]).to eq([['ok'], revision])

    combo.append_text(cafe)
    expect([labels.call, labels.call.last.encoding]).to eq([['ok', utf8(cafe)], Encoding::UTF_8])
  end

  it 'leaves no row behind when a combo item append is refused for its id' do
    combo = gtk::ComboBox.new
    combo.append('a', 'one')
    revision = combo.model.revision

    expect { combo.append('a', 'two') }.to raise_error(gtk::UnsupportedOperation, /operation=append/)
    expect { combo.append(:b, 'two') }.to raise_error(gtk::UnsupportedOperation, /operation=append/)
    expect([combo.model.rows.map { |iter| iter[0] }, combo.model.revision]).to eq([['one'], revision])
  end

  it 'refuses non-UTF-8 renderer text at the setter and re-tags binary-tagged UTF-8' do
    store = gtk::ListStore.new(String)
    store.append[0] = 'row'
    renderer = gtk::CellRendererText.new
    column = gtk::TreeViewColumn.new('Name', renderer, text: 0)
    view = gtk::TreeView.new(store)
    view.append_column(column)
    proposed = nil
    column.set_cell_data_func(renderer) { |_column, cell, _model, _iter| cell.text = proposed }
    cafe = 'caf'.b + bytes(0xC3, 0xA9)

    [bytes(0xFF), utf8(bytes(0xFF)), 'caf'.b + bytes(0xFF)].each do |rejected|
      expect { renderer.text = rejected }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
      proposed = rejected
      expect { view.materialize }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
    end
    expect(renderer.text).to be_nil

    renderer.text = cafe
    expect([renderer.text, renderer.text.encoding]).to eq([utf8(cafe), Encoding::UTF_8])
    proposed = cafe
    expect { view.materialize }.not_to raise_error
    expect(view.send(:row_definitions).first[:cells].values).to eq([utf8(cafe)])
  end

  it 'refuses non-UTF-8 combo entry text at the setter and re-tags binary-tagged UTF-8' do
    cafe = 'caf'.b + bytes(0xC3, 0xA9)
    combo = gtk::ComboBox.new(entry: true)
    handle = combo.materialize
    entry = combo.child

    [bytes(0xFF), utf8(bytes(0xFF)), 'caf'.b + bytes(0xFF)].each do |rejected|
      expect { entry.text = rejected }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
    end
    expect([entry.text, port.sets.count { |property, _| property == :value }]).to eq(['', 0])

    entry.text = cafe
    published = port.get(handle, :value)
    expect([published, published.encoding, entry.text, entry.text.encoding]).to eq(['text:caf' + utf8(bytes(0xC3, 0xA9)), Encoding::UTF_8, utf8(cafe), Encoding::UTF_8])
  end

  it 'matches binary-tagged UTF-8 entry text to a closed combo label' do
    cafe = 'caf'.b + bytes(0xC3, 0xA9)
    combo = gtk::ComboBox.new(entry: true)
    combo.append_text(utf8(cafe))
    combo.child.editable = false

    combo.child.text = cafe
    expect(combo.child.text).to eq(utf8(cafe))
  end

  it 'selects a just-appended binary-tagged UTF-8 combo label by the same raw text' do
    name = 'Grunwald'.b.sub('u', bytes(0xC3, 0xBC)) # u-umlaut, binary-tagged as game text arrives
    combo = gtk::ComboBox.new
    combo.append_text(name)
    combo.append_text('other')

    combo.set_active_text(name)
    expect([combo.active, combo.active_text, combo.active_text.encoding]).to eq([0, utf8(name), Encoding::UTF_8])
    combo.set_active_text('other')
    expect(combo.active).to eq(1)
    combo.active_text = name
    expect(combo.active).to eq(0)

    [bytes(0xFF), 'caf'.b + bytes(0xFF), name.dup.force_encoding(Encoding::ISO_8859_1)].each do |rejected|
      expect { combo.set_active_text(rejected) }.to raise_error(gtk::UnsupportedOperation, /operation=active_text=/)
    end
    expect(combo.active).to eq(0)
  end

  it 'refuses non-UTF-8 column tooltips at the setter and re-tags binary-tagged UTF-8' do
    store = gtk::ListStore.new(String)
    store.append[0] = 'row'
    column = gtk::TreeViewColumn.new('Name', gtk::CellRendererText.new, text: 0)
    view = gtk::TreeView.new(store)
    view.append_column(column)
    cafe = 'caf'.b + bytes(0xC3, 0xA9)

    [bytes(0xFF), utf8(bytes(0xFF)), 'caf'.b + bytes(0xFF), cafe.dup.force_encoding(Encoding::ISO_8859_1)].each do |rejected|
      expect { column.tooltip_text = rejected }.to raise_error(gtk::UnsupportedOperation, /operation=tooltip_text=/)
    end
    expect(column.tooltip_text).to be_nil

    column.tooltip_text = cafe
    expect([column.tooltip_text, column.tooltip_text.encoding]).to eq([utf8(cafe), Encoding::UTF_8])
    expect { view.materialize }.not_to raise_error
    expect(column.send(:definition)[:tooltip]).to eq(utf8(cafe))
  end

  # Text kept as ASCII-8BIT, or in another encoding, failed only at publication.
  # The setters now share Gtk.wire_text: binary-tagged UTF-8 is re-tagged and every
  # other non-UTF-8 text is refused at the call.
  describe 'non-UTF-8 text at the model, table and text setters' do
    let(:cafe) { 'caf'.b + bytes(0xC3, 0xA9) }
    let(:rejected) do
      [
        'caf'.b + bytes(0xFF),
        utf8('caf'.b + bytes(0xFF)),
        'caf'.dup.force_encoding(Encoding::ISO_8859_1) + bytes(0xE9).force_encoding(Encoding::ISO_8859_1),
        cafe.dup.force_encoding(Encoding::ISO_8859_1),
        'hi'.encode(Encoding::UTF_16LE)
      ]
    end

    # [name, refused operation, build, apply, read]
    g = Lich::Common::ScriptScope::Gtk
    cases = [
      ['MenuItem#set_label', :label, -> { g::MenuItem.new('old') }, ->(w, v) { w.set_label(v) }, ->(w) { w.label }],
      ['MenuItem#label=', :label, -> { g::MenuItem.new('old') }, ->(w, v) { w.label = v }, ->(w) { w.label }],
      ['MenuItem.new', :label, nil, ->(_w, v) { g::MenuItem.new(v) }, ->(w) { w.label }],
      ['CheckMenuItem.new', :new, nil, ->(_w, v) { g::CheckMenuItem.new(v) }, ->(w) { w.label }],
      ['RadioMenuItem.new', :new, nil, ->(_w, v) { g::RadioMenuItem.new(v) }, ->(w) { w.label }],
      ['SelectionData#set', :set, -> { g::SelectionData.new }, ->(w, v) { w.set(Lich::Common::ScriptScope::Gdk::Selection::TYPE_STRING, v) }, ->(w) { w.text }],
      ['SelectionData#text=', :set, -> { g::SelectionData.new }, ->(w, v) { w.text = v }, ->(w) { w.text }],
      ['SelectionData#set_text', :set, -> { g::SelectionData.new }, ->(w, v) { w.set_text(v) }, ->(w) { w.text }],
      ['TreeViewColumn#title=', :title=, -> { g::TreeViewColumn.new('old') }, ->(w, v) { w.title = v }, ->(w) { w.title }],
      ['TreeViewColumn#set_title', :title=, -> { g::TreeViewColumn.new('old') }, ->(w, v) { w.set_title(v) }, ->(w) { w.title }],
      ['TreeViewColumn.new', :new, nil, ->(_w, v) { g::TreeViewColumn.new(v) }, ->(w) { w.title }],
      ['Expander#set_label', :label=, -> { g::Expander.new('old') }, ->(w, v) { w.set_label(v) }, ->(w) { [w.label, w.label_widget.text] }],
      ['Expander#label=', :label=, -> { g::Expander.new('old') }, ->(w, v) { w.label = v }, ->(w) { [w.label, w.label_widget.text] }],
      ['Expander.new', :new, nil, ->(_w, v) { g::Expander.new(v) }, ->(w) { [w.label, w.label_widget.text] }]
    ]

    cases.each do |name, operation, build, apply, read|
      it "#{name} refuses other non-UTF-8 text at the call and re-tags binary-tagged UTF-8" do
        target = build&.call
        before = target && read.call(target)

        rejected.each do |text|
          expect { apply.call(target, text) }.to raise_error(gtk::UnsupportedOperation, /operation=#{operation}/)
        end
        expect(read.call(target)).to eq(before) if target

        result = target || apply.call(nil, cafe)
        apply.call(target, cafe) if target
        value = Array(read.call(result))
        expect(value.map { |text| [text, text.encoding] }).to all(eq([utf8(cafe), Encoding::UTF_8]))
      end
    end

    it 'publishes a re-tagged menu label and column title as UTF-8' do
      item = gtk::MenuItem.new(cafe)
      item.materialize
      item.label = cafe
      column = gtk::TreeViewColumn.new('Name', gtk::CellRendererText.new, text: 0)
      column.title = cafe
      store = gtk::ListStore.new(String)
      view = gtk::TreeView.new(store)
      view.append_column(column)
      view.materialize

      expect(port.sets.select { |property, _| property == :label }.map { |_, text| text.encoding }.uniq).to eq([Encoding::UTF_8])
      expect(column.send(:definition)[:label]).to eq(utf8(cafe))
      expect(column.send(:definition)[:label].encoding).to eq(Encoding::UTF_8)
    end

    it 'keeps the mnemonic refusal for a re-tagged menu label' do
      expect { gtk::MenuItem.new('a_b'.b, true) }.to raise_error(gtk::UnsupportedOperation, /operation=mnemonic/)
    end

    it 'takes a notebook tab label only through a Label, which already normalizes text' do
      notebook = gtk::Notebook.new
      label = gtk::Label.new('one')
      notebook.append_page(gtk::Label.new('page'), label)

      rejected.each { |text| expect { label.text = text }.to raise_error(gtk::UnsupportedOperation, /operation=text=/) }
      expect(label.text).to eq('one')
      label.text = cafe
      expect([label.text, label.text.encoding]).to eq([utf8(cafe), Encoding::UTF_8])
    end

    it 'defines Gtk.wire_text once' do
      expect(gtk.method(:wire_text).source_location.first).to end_with('gtk/widgets.rb')
    end
  end

  # Classes that a later layer first defines (images, style). hide_const makes any
  # layer behave as P13 does, where none of them exist.
  context 'without the classes a later layer defines' do
    before do
      %w[Gtk::Image Gtk::Color Gdk::RGBA Pango::FontDescription].each do |name|
        hide_const("Lich::Common::ScriptScope::#{name}")
      end
    end

    # [description, refused operation, call against fresh widgets]
    [
      ['MenuButton#set_image', 'set_image', ->(w) { w[:menu_button].set_image(Object.new) }],
      ['TextView#override_font', 'override_font', ->(w) { w[:text_view].override_font(Object.new) }],
      ['CellRenderer#background= with a color string', 'background=', ->(w) { w[:renderer].background = 'red' }],
      ['CellRenderer#foreground_rgba=', 'foreground_rgba=', ->(w) { w[:renderer].foreground_rgba = Object.new }],
      ['TreeView#override_background_color', 'override_background_color', ->(w) { w[:tree_view].override_background_color(:selected, Object.new) }]
    ].each do |description, operation, call|
      it "#{description} refuses instead of raising NameError" do
        widgets = { menu_button: gtk::MenuButton.new, text_view: gtk::TextView.new, renderer: gtk::CellRendererText.new,
                    tree_view: gtk::TreeView.new(gtk::ListStore.new(String)) }

        expect { call.call(widgets) }.to raise_error(gtk::UnsupportedOperation, /operation=#{Regexp.escape(operation)}/)
      end
    end

    it 'still clears a cell fill and foreground with nil' do
      renderer = gtk::CellRendererText.new

      expect { renderer.background = nil }.not_to raise_error
      expect { renderer.foreground_rgba = nil }.not_to raise_error
    end
  end
end
