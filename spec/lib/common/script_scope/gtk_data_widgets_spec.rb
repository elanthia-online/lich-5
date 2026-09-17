# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# Examples that need the data widgets -- ComboBox, SpinButton, TextView,
# TreeView, Notebook, Expander, Paned -- parked out of L6a's spec files
# when the shim was split into shim-core and shim-data. They are the tip's
# examples, unchanged but for the D1 opener stub and two rows in the
# viewer-scope table saying menus are not shimmed.
RSpec.describe 'GTK compatibility shim: data widgets on the viewer' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('review') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }
  let(:pushes) { [] }

  before do
    gtk::Session.browser_open = proc { |_url, on_start:, **| on_start.call(1); true }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
    recorder = pushes
    session.define_singleton_method(:viewer_write) do |_window, widget, name, value|
      recorder << [widget.class.name.split('::').last, name, value]
    end
  end

  after do
    gtk::Session.browser_open = nil
    session.shutdown
    service.stop
  end

  # Builds a window around the widgets the block returns, so they have handles.
  def in_window
    result = nil
    session.sync do
      window = gtk::Window.new('Review')
      window.set_default_size(400, 300)
      box = gtk::VBox.new
      window.add(box)
      result = yield(box)
      window.show_all
    end
    session.commit
    pushes.clear
    result
  end

  describe 'the viewer push that five sites forgot' do
    it 'pushes a spin button value written through its adjustment' do
      spin = in_window { |box| gtk::SpinButton.new(0, 100, 1).tap { |s| box.add(s) } }

      session.sync { spin.adjustment.value = 42 }

      expect(pushes).to include(['SpinButton', :value, 42])
    end

    it 'pushes a combo selection that names a real option' do
      combo = in_window { |box| gtk::ComboBoxText.new.tap { |c| c.append_text('one'); c.append_text('two'); box.add(c) } }

      session.sync { combo.active = 1 }

      expect(pushes).to eq([['ComboBoxText', :value, '2']])
    end

    # The validator refuses any select value not among the options, and a
    # refusal makes viewer_write forget the viewer. Neither "" nor nil is a
    # legal value, so a clear is not pushed at all -- pushing it would have
    # dropped the viewer, which is worse than the stale choice it leaves.
    it 'never pushes a cleared combo selection, which no legal value expresses' do
      combo = in_window { |box| gtk::ComboBoxText.new.tap { |c| c.append_text('one'); box.add(c) } }
      session.sync { combo.active = 0 }
      pushes.clear

      session.sync { combo.active = -1 }

      expect(pushes).to be_empty
      expect(combo.send(:node_props)).not_to include(:value)
    end
  end

  # mrhoribu #1641: nothing structural tied a contract property declared
  # `scope: :viewer` to the requirement that its shim writer route through
  # Widget#viewer_push. This walks the contract for every viewer-scoped
  # (type, property), nested record fields included, and demands each one
  # appear in `writers`: either the shim class and method that pushes it (whose
  # source is then checked for the viewer_push call), or :not_modelled. A
  # new viewer-scoped property fails here until someone decides its writer.
  describe 'the viewer-scope invariant' do
    let(:writers) do
      {
        [:group, :selected]          => :not_modelled, # ListBoxRow never emits selectable, so nothing to push
        [:tabs, :selected]           => [[:Notebook, :page=]],
        [:expander, :open]           => [[:Expander, :expanded=]],
        [:split, :position]          => [[:Paned, :position=]],
        [:scroll, :scroll_to]        => :not_modelled,
        [:scroll, :scroll_position]  => [[:ScrolledWindow, :adjustment_moved]],
        [:toggle, :checked]          => [[:ToggleButton, :active=]],
        [:checkbox, :checked]        => [[:ToggleButton, :active=], [:RadioButton, :deactivate_quietly]],
        [:radio, :selected]          => :not_modelled, # RadioButton renders as checkbox
        [:text_input, :value]        => [[:Entry, :text=]],
        [:textarea, :value]          => [[:TextView, :buffer_changed!]],
        [:number_input, :value]      => [[:SpinButton, :adjustment_moved]],
        [:slider, :value]            => :not_modelled, # no shim widget renders slider
        [:select, :value]            => [[:ComboBox, :active=]],
        [:nav, :selected]            => :not_modelled, # no shim widget renders nav
        [:table, 'rows.[].expanded'] => :not_modelled, # TreeView#expand_row is a no-op
        [:table, :selected]          => [[:TreeView, :select_keys]],
        [:table, :sort]              => :not_modelled, # sort is applied to the model, never pushed
        [:composite, :scroll_to]     => :not_modelled,
        [:menu, :open]               => :not_modelled, # menus are not shimmed (admission rule)
        [:menu_item, :active]        => :not_modelled, # menus are not shimmed (admission rule)
      }
    end

    def viewer_scoped_pairs
      contract = Lich::WebUI::Contract
      pairs = []
      contract.schemas.each do |type, schema|
        schema[:properties].each do |name, prop|
          pairs << [type, name] if prop[:scope] == :viewer
          nested = []
          nested_viewer_fields(prop[:shape], [], nested)
          nested.each { |path| pairs << [type, ([name] + path).join('.')] }
        end
      end
      pairs
    end

    def nested_viewer_fields(shape, path, out)
      return unless shape.is_a?(Hash)

      case shape[:kind]
      when :record
        shape[:fields].each do |name, prop|
          out << path + [name] if prop[:scope] == :viewer
          nested_viewer_fields(prop[:shape], path + [name], out)
        end
      when :array then nested_viewer_fields(shape[:items], path + ['[]'], out)
      when :union then shape[:variants].each { |variant| nested_viewer_fields(variant, path, out) }
      end
    end

    # The method's source, from its def to the first `end` at method depth.
    def method_source(klass, method)
      file, line = gtk.const_get(klass).instance_method(method).source_location
      lines = File.readlines(file)
      finish = (line...lines.length).find { |index| lines[index] =~ /\A {10}end\s*\z/ }
      lines[(line - 1)..finish].join
    end

    it 'names a shim writer, or declines to model, every viewer-scoped contract property' do
      missing = viewer_scoped_pairs - writers.keys
      stale = writers.keys - viewer_scoped_pairs

      expect(missing).to eq([]), "viewer-scoped properties with no writer decision: #{missing.inspect}"
      expect(stale).to eq([]), "writers names properties the contract no longer scopes to the viewer: #{stale.inspect}"
    end

    it 'routes every named writer through viewer_push for that property' do
      writers.each do |(_type, property), pushers|
        next unless pushers.is_a?(Array)

        pushers.each do |(klass, method)|
          expect(method_source(klass, method)).to include("viewer_push(:#{property}"),
                                                  "#{klass}##{method} does not viewer_push(:#{property})"
        end
      end
    end

    # Paned#position= was the one writer that spelled the pairing by hand
    # (viewer_write directly); it is on viewer_push now, so no writer may.
    it 'has no writer that calls viewer_write by hand' do
      writers.each_value do |pushers|
        next unless pushers.is_a?(Array)

        pushers.each do |(klass, method)|
          expect(method_source(klass, method)).not_to include('viewer_write('),
                                                      "#{klass}##{method} writes the viewer by hand"
        end
      end
    end
  end
end

RSpec.describe 'GTK compatibility shim: data widgets' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('data') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }

  before do
    gtk::Session.browser_open = proc { |_url, on_start:, **| on_start.call(1); true }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    session.shutdown
    service.stop
  end

  def in_scope(&block)
    session.sync(&block)
  end

  def page
    session.adapter.page_for(@window.handle)
  end

  def tree
    page.last_render.tree
  end

  def component(key)
    tree.each.find { |candidate| candidate.props[:key] == key } || raise("no component with key #{key}")
  end

  describe 'validation at the GTK boundary' do
    [nil, 0].each do |selection|
      ['Second', 'Custom'].each do |typed|
        it "renders editable combo text #{typed.inspect} with prior selection #{selection.inspect}" do
          in_scope do
            @window = gtk::Window.new
            @combo = gtk::ComboBoxText.new(has_entry: true)
            @combo.append('first', 'First')
            @combo.append('second', 'Second')
            @combo.active = selection unless selection.nil?
            @combo.child.text = typed
            @window.add(@combo)
            @window.show_all
          end
          node = component(@combo.key)
          selected = node.props[:options].find { |option| option[:value] == node.props[:value] }
          expect(selected[:label]).to eq(typed)
          expect(node.props[:value]).to eq(typed == 'Second' ? 'second' : 'typed:Custom')
        end
      end
    end
  end

  describe 'the rendered tree' do
    it 'reaches the contract with weights on the row and grow on the column' do
      window = session.sync do
        window = gtk::Window.new('Setup')
        column = gtk::Box.new(:vertical, 6)
        row = gtk::Box.new(:horizontal, 4)
        row.pack_start(gtk::Label.new('Resting Room ID:'), expand: false, fill: false, padding: 0)
        row.pack_start(gtk::Entry.new, expand: true, fill: true, padding: 0)
        column.pack_start(row, expand: false, fill: false, padding: 0)
        column.pack_start(gtk::TextView.new, expand: true, fill: true, padding: 0)
        window.add(column)
        window.show_all
        window
      end
      session.show_window(window)
      session.sync {}

      tree = session.adapter.page_for(window.handle).last_render.tree
      columns = tree.each.find { |node| node.type == :columns }
      textarea = tree.each.find { |node| node.type == :textarea }

      expect(columns.props[:weights]).to eq([0, 1])
      expect(textarea.placement).to eq(grow: 1)
    end
  end

  # A tree view used as a plain list names its columns for the model and
  # hides the header row. eloot has twelve, and every one of them showed a
  # bare "Exclusion" heading inside the box.
  describe 'headers-visible on a tree view' do
    def tree_with(headers:)
      session.sync do
        view = gtk::TreeView.new
        view.apply_builder_property('headers-visible', headers) unless headers.nil?
        view.append_column(gtk::TreeViewColumn.new('Exclusion', gtk::CellRendererText.new, text: 0))
        view.send(:node_props)
      end
    end

    it 'hides the header row when the Glade file asked it to' do
      expect(tree_with(headers: 'False')[:headers]).to be(false)
    end

    it 'says nothing when the file left headers alone' do
      expect(tree_with(headers: nil)).not_to have_key(:headers)
    end
  end

  # ;armor died at `tv.buffer.tag_table`: a TextBuffer had no tag table, and
  # Gtk::TextTag was an unimplemented-widget stub. A tag is state a script
  # builds and applies; the textarea shows plain text, so applying one is
  # reported through the ledger and the text is kept whole.
  describe 'text tags on a buffer' do
    before { gtk.reset_unsupported! }

    it 'lets a script build, add and apply a tag the way armor does, keeping the text and saying so once' do
      buffer = gtk::TextBuffer.new
      buffer.text = "Head\nBody"
      tag = gtk::TextTag.new('just_page')
      tag.set_property('justification', :center)
      buffer.tag_table.add(tag)
      buffer.apply_tag(tag, buffer.start_iter, buffer.end_iter)
      buffer.apply_tag(tag, buffer.start_iter, buffer.end_iter)

      expect(gtk::TextTag).not_to respond_to(:webui_stub?)
      expect(buffer.tag_table.lookup('just_page')).to be(tag)
      expect(tag['justification']).to eq(:center)
      expect(buffer.text).to eq("Head\nBody")
      report = gtk.unsupported_report.values.first || {}
      expect(report.fetch('Gtk::TextBuffer#apply_tag')).to include(count: 2)
    end

    it 'inserts markup as its text, and degrades any other buffer call instead of raising' do
      buffer = gtk::TextBuffer.new
      buffer.text = ''
      buffer.insert_markup(buffer.start_iter, "<b>Legend</b>\n<span foreground=\"red\">A &amp; B</span> &lt;x&gt;")
      expect(buffer.text).to eq("Legend\nA & B <x>")

      expect(buffer.frobnicate(1)).to be_nil
      expect(buffer.set_frobnicate(1)).to be(buffer)
      expect(buffer.delete_mark(:mark)).to be_nil
      expect(buffer).not_to respond_to(:frobnicate)
      expect(buffer).to respond_to(:set_frobnicate)
      expect { 100 - buffer }.to raise_error(TypeError)
      report = gtk.unsupported_report.values.first || {}
      expect(report.keys).to include('Gtk::TextBuffer#insert_markup', 'Gtk::TextBuffer#frobnicate')
    end

    it 'creates a tag into its own table and inserts tagged text as plain text' do
      buffer = gtk::TextBuffer.new
      created = buffer.create_tag('bold', 'weight' => 700)
      expect(buffer.tag_table.lookup('bold')).to be(created)
      expect(created['weight']).to eq(700)

      buffer.insert_with_tags(buffer.end_iter, 'hello', created)
      buffer.insert_with_tags_by_name(buffer.end_iter, ' world', 'bold')
      expect(buffer.text).to eq('hello world')
      report = gtk.unsupported_report.values.first || {}
      expect(report.fetch('Gtk::TextBuffer#insert_with_tags')).to include(count: 2)
    end
  end

  describe 'a value the contract cannot carry' do
    before { gtk.reset_unsupported! }

    def warnings
      gtk.unsupported_report.values.flat_map(&:keys)
    end

    it 'reports the widget it evicted from an occupied pane' do
      paned = gtk::Paned.new(:horizontal)
      paned.add1(gtk::Label.new('first'))
      paned.add1(gtk::Label.new('second'))

      expect(warnings.join).to include('occupied first pane')
    end
  end

  # viewer_write rescued every Lich::WebUI::Error as 'the viewer left'. A
  # value the contract refuses is a bug in what the script asked for, and
  # treating it as a departure dropped a viewer whose attachment was still
  # live -- so later programmatic updates silently missed that browser.
  describe 'a viewer write the contract refuses' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }
    let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('combo') }
    let(:service) { Lich::WebUI::Service.new }
    let(:session) { gtk::Session.new(owner, service: service) }

    before do
      gtk::Session.browser_open = proc { |_url, on_start:, **| on_start.call(1); true }
    end

    after do
      gtk::Session.browser_open = nil
      session.shutdown
      service.stop
    end

    it 'keeps the viewer and reports the refusal' do
      window = combo = nil
      session.sync do
        window = gtk::Window.new('C')
        combo = gtk::ComboBoxText.new
        combo.append_text('one')
        window.add(combo)
        window.show_all
      end
      session.commit
      page = session.adapter.page_for(window.handle)
      session.send(:note_viewer, page, 'viewer-one')
      gtk.reset_unsupported!

      session.viewer_write(window, combo, :value, 'not an option')
      session.commit

      expect(session.send(:viewers_for, page)).to include('viewer-one')
      expect(gtk.unsupported_report.values.flat_map(&:keys).join).to include('viewer write of value')
    end

    # Appending an option and selecting it in one job pushed the selection
    # while the page's last render still knew only the old option. The write
    # was refused against that schema, the structural render then carried
    # both options, and the viewer's retained copy still named the old one:
    # Ruby said the new choice, the browser showed the old.
    it 'applies a selection that depends on an option added in the same job' do
      connection = Class.new do
        attr_reader :viewer_id

        def initialize(viewer_id) = @viewer_id = viewer_id
        def send_text(_payload) = true
        def close = nil
        def alive? = true
      end.new('viewer-one')
      window = combo = nil
      session.sync do
        window = gtk::Window.new('C')
        combo = gtk::ComboBoxText.new
        combo.append_text('one')
        combo.active = 0
        window.add(combo)
        window.show_all
      end
      session.commit
      page = session.adapter.page_for(window.handle)
      service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page),
                                         version: Lich::WebUI::Contract::VERSION)
      viewer = service.runtime.instance_variable_get(:@viewers).attachments_for(page).first.viewer_id
      session.send(:note_viewer, page, viewer)
      cid = page.last_render.tree.each.find { |node| node.props[:key] == combo.key }.cid

      session.sync do
        combo.append_text('two')
        combo.active = 1
      end
      session.sync { nil } # queued behind the commit that follows the job above

      expect(combo.active).to eq(1)
      expect(service.runtime.read(page, cid, :value, viewer: viewer)).to eq(combo.active_id)
    end
  end

  # The gesture existed on both ends and nothing joined them: the shim binds
  # row-activated and advertises editors, the client emitted neither. These
  # assert the shim half reaches a script handler, so the two cannot drift
  # apart again without one of them failing.
  describe 'a tree view a script made interactive' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }
    let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('tree') }
    let(:service) { Lich::WebUI::Service.new }
    let(:session) { gtk::Session.new(owner, service: service) }

    before do
      gtk::Session.browser_open = proc { |_url, on_start:, **| on_start.call(1); true }
    end

    after do
      gtk::Session.browser_open = nil
      session.shutdown
      service.stop
    end

    it 'advertises an editor per column and delivers both gestures' do
      fired = []
      window = view = store = nil
      session.sync do
        window = gtk::Window.new('T')
        store = gtk::ListStore.new(String, TrueClass)
        %w[alpha beta].each_with_index do |value, index|
          row = store.append
          row[0] = value
          row[1] = index.zero?
        end
        view = gtk::TreeView.new(store)
        text = gtk::CellRendererText.new
        text.editable = true
        view.append_column(gtk::TreeViewColumn.new('Name', text, text: 0))
        view.append_column(gtk::TreeViewColumn.new('On', gtk::CellRendererToggle.new, active: 1))
        view.signal_connect('row-activated') { |_widget, path, _column| fired << [:activated, path.to_s] }
        text.signal_connect('edited') { |_renderer, path, value| fired << [:edited, path, value] }
        window.add(view)
        window.show_all
      end
      session.commit
      table = session.adapter.page_for(window.handle).last_render.tree.each.find { |node| node.type == :table }
      row_key = table.props[:rows].first[:key]

      expect(table.props[:columns].map { |column| column[:editor]&.fetch(:type) }).to eq(%w[text checkbox])

      session.sync { view.send(:receive_event, :row_activate, Struct.new(:payload).new({ row: row_key })) }
      session.sync do
        view.send(:receive_event, :cell_edit,
                  Struct.new(:payload).new({ row: row_key, column: 'c0', value: 'ALPHA' }))
      end

      expect(fired).to eq([[:activated, '0'], [:edited, '0', 'ALPHA']])
      # The script owns the model: an `edited` handler that does not write
      # the value has refused the edit, and the model still says alpha.
      expect(store.to_enum(:each).map { |_model, _path, row| row[0] }).to eq(%w[alpha beta])
    end

    # Review 2026-09-17, R7: the shim wrote the submitted value and then
    # emitted `toggled`, so the conventional handler inverted the value the
    # shim had just set and the checkbox went back to where it started.
    it 'lets the script mutate the model on a cell edit, as GTK does' do
      window = view = store = nil
      session.sync do
        window = gtk::Window.new('T')
        store = gtk::ListStore.new(String, TrueClass)
        row = store.append
        row[0] = 'alpha'
        row[1] = false
        view = gtk::TreeView.new(store)
        text = gtk::CellRendererText.new
        text.editable = true
        toggle = gtk::CellRendererToggle.new
        view.append_column(gtk::TreeViewColumn.new('Name', text, text: 0))
        view.append_column(gtk::TreeViewColumn.new('On', toggle, active: 1))
        text.signal_connect('edited') { |_renderer, path, value| store.get_iter(path)[0] = value.upcase if value != 'refused' }
        toggle.signal_connect('toggled') { |_renderer, path| iter = store.get_iter(path); iter[1] = !iter[1] }
        window.add(view)
        window.show_all
      end
      session.commit
      table = session.adapter.page_for(window.handle).last_render.tree.each.find { |node| node.type == :table }
      row_key = table.props[:rows].first[:key]
      edit = ->(column, value) { session.sync { view.send(:receive_event, :cell_edit, Struct.new(:payload).new({ row: row_key, column: column, value: value })) } }

      edit.call('c1', true)
      expect(store.to_enum(:each).map { |_model, _path, row| row[1] }).to eq([true]), 'the toggle handler flipped false to true'
      edit.call('c0', 'refused')
      expect(store.to_enum(:each).map { |_model, _path, row| row[0] }).to eq(['alpha']), 'a refused edit leaves the model alone'
      edit.call('c0', 'beta')
      expect(store.to_enum(:each).map { |_model, _path, row| row[0] }).to eq(['BETA']), 'an accepted edit is whatever the handler wrote'
    end
  end
end
