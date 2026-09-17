# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# A Glade-shaped document that touches every construct the nine Builder
# scripts use: window with a destroy signal, box packing with pack-type and
# position, notebook tab labels (with a duplicate), a frame label widget, a
# grid with a span and a hole, and one of every data widget.
GTK_BUILDER_SPEC_XML = <<~'XML'
    <?xml version="1.0" encoding="UTF-8"?>
    <interface>
      <requires lib="gtk+" version="3.20"/>
      <object class="GtkAdjustment" id="count_adjustment">
        <property name="lower">4</property>
        <property name="upper">20</property>
        <property name="step-increment">1</property>
        <property name="page-increment">10</property>
      </object>
      <object class="GtkListStore" id="exclude_store">
        <columns>
          <column type="gchararray"/>
          <column type="gint"/>
        </columns>
      </object>
      <object class="GtkWindow" id="main">
        <property name="can-focus">False</property>
        <property name="title" translatable="yes">Spec Setup</property>
        <property name="default-width">800</property>
        <property name="default-height">600</property>
        <signal name="destroy" handler="on_destroy" swapped="no"/>
        <child>
          <object class="GtkBox">
            <property name="visible">True</property>
            <property name="orientation">vertical</property>
            <property name="spacing">5</property>
            <child>
              <object class="GtkButton" id="close_button">
                <property name="label" translatable="yes">Close</property>
                <property name="visible">True</property>
                <property name="halign">end</property>
                <property name="margin-top">6</property>
                <signal name="clicked" handler="on_close_clicked" swapped="no"/>
              </object>
              <packing>
                <property name="expand">False</property>
                <property name="fill">True</property>
                <property name="pack-type">end</property>
                <property name="position">1</property>
              </packing>
            </child>
            <child>
              <object class="GtkNotebook" id="book">
                <property name="visible">True</property>
                <child>
                  <object class="GtkFrame" id="loot_frame">
                    <property name="visible">True</property>
                    <property name="label-xalign">0</property>
                    <child>
                      <!-- n-columns=3 n-rows=3 -->
                      <object class="GtkGrid" id="loot_grid">
                        <property name="visible">True</property>
                        <property name="row-spacing">2</property>
                        <property name="column-spacing">5</property>
                        <child>
                          <object class="GtkCheckButton" id="loot_types:alchemy">
                            <property name="label" translatable="yes">Alchemy</property>
                            <property name="visible">True</property>
                            <property name="active">True</property>
                            <property name="draw-indicator">True</property>
                          </object>
                          <packing>
                            <property name="left-attach">0</property>
                            <property name="top-attach">0</property>
                          </packing>
                        </child>
                        <child>
                          <object class="GtkEntry" id="notes">
                            <property name="visible">True</property>
                            <property name="placeholder-text" translatable="yes">Notes</property>
                          </object>
                          <packing>
                            <property name="left-attach">1</property>
                            <property name="top-attach">0</property>
                            <property name="width">2</property>
                          </packing>
                        </child>
                        <child>
                          <object class="GtkSpinButton" id="count">
                            <property name="visible">True</property>
                            <property name="text" translatable="yes">2</property>
                            <property name="adjustment">count_adjustment</property>
                          </object>
                          <packing>
                            <property name="left-attach">2</property>
                            <property name="top-attach">1</property>
                          </packing>
                        </child>
                        <child>
                          <object class="GtkLabel" id="hidden_label">
                            <property name="visible">False</property>
                            <property name="label" translatable="yes">hidden</property>
                          </object>
                          <packing>
                            <property name="left-attach">0</property>
                            <property name="top-attach">2</property>
                          </packing>
                        </child>
                      </object>
                    </child>
                    <child type="label">
                      <object class="GtkLabel">
                        <property name="visible">True</property>
                        <property name="label" translatable="yes">Loot Types</property>
                      </object>
                    </child>
                  </object>
                </child>
                <child type="tab">
                  <object class="GtkLabel">
                    <property name="visible">True</property>
                    <property name="label" translatable="yes">Looting</property>
                  </object>
                  <packing>
                    <property name="tab-fill">False</property>
                  </packing>
                </child>
                <child>
                  <object class="GtkBox" id="second_page">
                    <property name="visible">True</property>
                    <property name="orientation">vertical</property>
                    <child>
                      <object class="GtkComboBoxText" id="locker">
                        <property name="visible">True</property>
                        <property name="active">1</property>
                        <property name="has-entry">True</property>
                        <items>
                          <item id="none" translatable="yes">None</item>
                          <item id="voln" translatable="yes">Voln Symbol of Return</item>
                        </items>
                        <child internal-child="entry">
                          <object class="GtkEntry" id="locker_name">
                            <property name="can-focus">True</property>
                            <property name="placeholder-text" translatable="yes">Select Locker</property>
                          </object>
                        </child>
                      </object>
                    </child>
                    <child>
                      <object class="GtkTreeView" id="exclude">
                        <property name="visible">True</property>
                        <property name="model">exclude_store</property>
                        <property name="headers-visible">False</property>
                        <child internal-child="selection">
                          <object class="GtkTreeSelection"/>
                        </child>
                        <child>
                          <object class="GtkTreeViewColumn">
                            <property name="title" translatable="yes">Exclusion</property>
                            <child>
                              <object class="GtkCellRendererText"/>
                              <attributes>
                                <attribute name="text">0</attribute>
                              </attributes>
                            </child>
                          </object>
                        </child>
                      </object>
                    </child>
                    <child>
                      <object class="GtkTextView" id="overflow">
                        <property name="visible">True</property>
                        <property name="wrap-mode">word</property>
                      </object>
                    </child>
                    <child>
                      <object class="GtkExpander" id="advanced">
                        <property name="visible">True</property>
                        <property name="label" translatable="yes">Advanced</property>
                        <child>
                          <object class="GtkSeparator">
                            <property name="visible">True</property>
                          </object>
                        </child>
                      </object>
                    </child>
                  </object>
                </child>
                <child type="tab">
                  <object class="GtkLabel">
                    <property name="visible">True</property>
                    <property name="label" translatable="yes">Looting</property>
                  </object>
                </child>
              </object>
              <packing>
                <property name="expand">True</property>
                <property name="fill">True</property>
                <property name="position">0</property>
              </packing>
            </child>
          </object>
        </child>
      </object>
  </interface>
XML

RSpec.describe 'GTK compatibility shim (slice two): Builder and data widgets' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('eloot') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }
  let(:fixtures) { File.expand_path('../../../fixtures/webui_builder', __dir__) }

  before do
    gtk::Session.browser_open = proc { |*| true }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    session.shutdown
  end

  # The scripts subclass Gtk::Builder and wire handlers with method(name).
  def setup_class
    gtk_module = gtk
    Class.new(gtk_module::Builder) do
      attr_reader :events

      define_method(:initialize) do
        super()
        @events = []
      end

      def on_destroy
        @events << :destroyed
      end

      def on_close_clicked(button)
        @events << [:closed, button.builder_name]
      end
    end
  end

  def page_for(window)
    session.adapter.page_for(window.handle)
  end

  def component(page, key)
    page.last_render.tree.each.find { |candidate| candidate.props[:key] == key } || raise("no component with key #{key}")
  end

  def fire(page, widget, event, payload = {}, viewer_id: 'attachment-spec')
    cid = component(page, widget.key).cid
    callback = page.last_render.bindings[[cid, event]] || raise("no binding for #{cid}/#{event}")
    context = Lich::WebUI::Runtime::EventContext.new(viewer_id, page, component(page, widget.key), event, payload, nil)
    callback.call(context)
    session.sync {}
  end

  describe 'a synthetic Glade document' do
    let(:setup) { setup_class.new }
    # Lazy lets must be evaluated on the main thread before the session
    # thread runs: RSpec's memoization mutex is not reentrant across threads.
    let!(:window) do
      builder = setup
      session.sync do
        builder.add_from_string(GTK_BUILDER_SPEC_XML)
        builder.connect_signals { |handler| builder.method(handler) }
        builder['main'].show_all
      end
      session.sync {}
      builder['main']
    end
    let(:page) { page_for(window) }

    it 'exposes objects by id, iterates them, and names them' do
      expect(setup['main']).to be_a(gtk::Window)
      expect(setup.get_object('close_button')).to be_a(gtk::Button)
      expect(setup['loot_types:alchemy'].builder_name).to eq('loot_types:alchemy')
      expect(setup.objects.count { |object| object.respond_to?(:builder_name) && object.builder_name }).to be >= 12
      expect(setup['exclude_store']).to be_a(gtk::ListStore)
      expect(setup['count_adjustment']).to be_a(gtk::Adjustment)
      expect(setup['locker_name']).to be_a(gtk::Entry)
      expect(setup['loot_types:alchemy'].class == gtk::CheckButton).to be(true)
      expect(setup['loot_types:alchemy']).to be_a(gtk::ToggleButton)
      expect(setup['locker']).to be_a(gtk::ComboBox)
      expect(setup['loot_grid']).to be_a(gtk::Container)
    end

    it 'renders the window as page > stack with the end-packed button last' do
      root = page.last_render.tree
      expect(root.type).to eq(:page)
      expect(root.props).to include(title: 'Spec Setup', size: [800, 600])
      stack = root.children.first
      expect(stack.type).to eq(:stack)
      expect(stack.children.map(&:type)).to eq(%i[tabs button])
      button = stack.children.last
      expect(button.props).to include(label: 'Close', align: 'end', margin: { top: 6 })
    end

    it 'maps the notebook to tabs with tab-label names, disambiguating duplicates' do
      tabs = component(page, setup['book'].key)
      expect(tabs.props[:names]).to eq(['Looting', 'Looting (2)'])
      expect(tabs.props[:selected]).to eq(0)
      expect(tabs.children.map(&:slot)).to eq(['Looting', 'Looting (2)'])
      expect(tabs.children.first.type).to eq(:group)
      expect(tabs.children.first.props[:label]).to eq('Loot Types')
    end

    it 'lays the grid out row by row with a span placement and fillers for holes' do
      grid = component(page, setup['loot_grid'].key)
      expect(grid.props[:cols]).to eq(3)
      expect(grid.children.map(&:type)).to eq(%i[checkbox text_input text text number_input])
      expect(grid.children[1].placement).to eq(span: 2)
      expect(grid.children[0].props).to include(label: 'Alchemy', checked: true)
      expect(grid.children[1].props).to include(placeholder: 'Notes')
      expect(grid.children.map { |child| child.props[:key] }).not_to include(setup['hidden_label'].key)
    end

    it 'gives the spin button its adjustment range and clamps the value into it' do
      spin = setup['count']
      expect(spin).to be_a(gtk::Entry)
      expect(spin.instance_of?(gtk::Entry)).to be(false)
      expect(spin.adjustment).to equal(setup['count_adjustment'])
      node = component(page, spin.key)
      expect(node.type).to eq(:number_input)
      expect(node.props).to include(min: 4, max: 20, step: 1, value: 4)

      fire(page, spin, :change, { value: 12 })
      expect(spin.value).to eq(12.0)
      expect(spin.value_as_int).to eq(12)
      expect(setup['count_adjustment'].value).to eq(12.0)
    end

    it 'renders a has-entry combo as a select whose child entry mirrors the choice' do
      combo = setup['locker']
      node = component(page, combo.key)
      expect(node.type).to eq(:select)
      expect(node.props[:options]).to eq([{ value: 'none', label: 'None' }, { value: 'voln', label: 'Voln Symbol of Return' }])
      expect(node.props[:value]).to eq('voln')
      expect(combo.active).to eq(1)
      expect(combo.active_text).to eq('Voln Symbol of Return')
      expect(combo.child).to equal(setup['locker_name'])

      fire(page, combo, :change, { value: 'none' })
      expect(combo.active_text).to eq('None')
      expect(combo.active_id).to eq('none')

      session.sync { combo.append_text('Custom Locker'); combo.remove_all; combo.append_text('Only') }
      session.sync {}
      expect(component(page, combo.key).props[:options].map { |option| option[:label] }).to eq(['Only'])
    end

    it 'renders a tree view as a table fed by its list store and reflects selection' do
      view = setup['exclude']
      store = setup['exclude_store']
      expect(view.model).to equal(store)
      expect(component(page, view.key).props[:rows]).to eq([])

      iters = session.sync do
        first = store.append
        first[0] = 'aquamarine wand'
        first[1] = '3'
        second = store.append
        second[0] = 'gold ring'
        [first, second]
      end
      session.sync {}
      table = component(page, view.key)
      expect(table.type).to eq(:table)
      expect(table.props[:columns].length).to eq(1)
      expect(table.props[:columns].first).to include(key: 'c0', label: 'Exclusion')
      expect(table.props[:rows].map { |row| row[:cells] }).to eq([{ 'c0' => 'aquamarine wand' }, { 'c0' => 'gold ring' }])
      expect(iters.first[1]).to eq(3)

      fire(page, view, :selection_change, { rows: [iters.last.key] })
      expect(view.selection.selected).to eq(iters.last)
      expect(view.selection.selected[0]).to eq('gold ring')
      expect(component(page, view.key).props[:selected]).to eq([iters.last.key])

      activated = nil
      session.sync { view.signal_connect('row-activated') { |_view, path, _column| activated = path.to_s } }
      fire(page, view, :row_activate, { row: iters.first.key })
      expect(activated).to eq('0')

      session.sync { store.clear }
      session.sync {}
      expect(component(page, view.key).props[:rows]).to eq([])
      expect(view.selection.selected).to be_nil
    end

    it 'keeps the text view buffer in step with the viewer' do
      view = setup['overflow']
      session.sync { view.buffer.text = 'rucksack, cloak' }
      session.sync {}
      node = component(page, view.key)
      expect(node.type).to eq(:textarea)
      expect(node.props[:value]).to eq('rucksack, cloak')

      fire(page, view, :change, { value: 'orange pack' })
      expect(view.buffer.text).to eq('orange pack')
    end

    it 'maps the expander and separator and tracks open state' do
      expander = setup['advanced']
      node = component(page, expander.key)
      expect(node.type).to eq(:expander)
      expect(node.props).to include(label: 'Advanced', open: false)
      expect(node.children.map(&:type)).to eq([:divider])

      fire(page, expander, :toggle, { open: true })
      expect(expander.expanded?).to be(true)
    end

    it 'wires XML signals through connect_signals with the handler arity ruby-gnome honors' do
      fire(page, setup['close_button'], :activate)
      expect(setup.events).to eq([[:closed, 'close_button']])

      session.sync { window.destroy }
      session.sync {}
      expect(setup.events).to eq([[:closed, 'close_button'], :destroyed])
    end
  end

  describe 'real Glade files from the community scripts' do
    {
      'repository.ui' => { objects: 41, nodes: 20, types: %i[table tabs scroll] },
      'eherbs.ui'     => { objects: 30, nodes: 32, types: %i[checkbox group grid] },
    }.each do |name, expected|
      it "builds and renders #{name} without logging unsupported API" do
        logged = []
        allow(Lich).to receive(:log) { |message| logged << message } if defined?(Lich) && Lich.respond_to?(:log)
        builder = gtk::Builder.new
        window_class = gtk::Window
        xml = File.read(File.join(fixtures, name))
        window = session.sync do
          builder.add_from_string(xml)
          builder.objects.find { |object| object.is_a?(window_class) }.tap(&:show_all)
        end
        session.sync {}

        tree = page_for(window).last_render.tree
        expect(builder.objects.length).to eq(expected[:objects])
        expect(tree.each.count).to eq(expected[:nodes])
        expect(tree.each.map(&:type).uniq).to include(*expected[:types])
        expect(logged.grep(/unsupported/)).to be_empty
      end
    end
  end

  # The admission rule (docs/webui-rebuild-plan.md): menus, images, layouts
  # and drawing areas are not shimmed, so a Glade file that declares one
  # loses that object -- with a ledger entry naming the class -- and keeps
  # the rest of its window. None of them may map to a real class here.
  describe 'a Glade file that names a class the shim does not admit' do
    let(:xml) do
      <<~XML
        <interface>
          <object class="GtkWindow" id="main">
            <property name="title">Not admitted</property>
            <child>
              <object class="GtkBox" id="column">
                <property name="orientation">vertical</property>
                <child><object class="GtkMenuBar" id="bar"><child><object class="GtkMenuItem" id="file"/></child></object></child>
                <child><object class="GtkImage" id="picture"/></child>
                <child><object class="GtkLayout" id="canvas"/></child>
                <child><object class="GtkDrawingArea" id="surface"/></child>
                <child><object class="GtkLabel" id="kept"><property name="label">still here</property></object></child>
              </object>
            </child>
          </object>
        </interface>
      XML
    end

    it 'drops each one with a ledger entry and renders the rest' do
      gtk.reset_unsupported!
      builder = gtk::Builder.new
      window_class = gtk::Window
      window = session.sync do
        builder.add_from_string(xml)
        builder.objects.find { |object| object.is_a?(window_class) }.tap(&:show_all)
      end
      session.sync {}

      %w[GtkMenuBar GtkImage GtkLayout GtkDrawingArea].each do |name|
        expect(gtk::Builder::CLASSES).not_to have_key(name)
        expect(gtk.unsupported_report.values.flat_map(&:keys)).to include("Gtk::Builder#class #{name}")
      end
      expect(builder.objects.map(&:builder_name)).to eq(%w[main column kept])
      expect(page_for(window).last_render.tree.each.map(&:type)).to eq(%i[page stack text])
    end
  end
end
