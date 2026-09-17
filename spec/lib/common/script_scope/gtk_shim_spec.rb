# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'

# The shim is a ScriptScope plugin; load it the way activate! would, without
# flipping the global switch for the rest of the suite.
require 'common/script_scope/gtk/boot'

RSpec.describe 'GTK compatibility shim (slice one)' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('vars') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }
  let(:opened) { [] }

  before do
    gtk::Session.browser_open = proc { |url, geometry:, on_start:, on_exit:| opened << [url, geometry, on_exit]; on_start.call(4242); true }
    gtk::Session.browser_kill = proc { |pid| opened << [:killed, pid] }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    gtk::Session.browser_kill = nil
    session.shutdown
  end

  # Runs +block+ as a script would: on the session thread, with Gtk resolving
  # to the shim. Returns the block's value.
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

  def fire(key, event, viewer_id: 'attachment-spec', payload: {})
    cid = component(key).cid
    callback = page.last_render.bindings[[cid, event]] || raise("no binding for #{cid}/#{event}")
    context = Lich::WebUI::Runtime::EventContext.new('attachment-spec'.dup.replace(viewer_id), page, component(key), event, payload, nil)
    callback.call(context)
    session.sync {} # wait for the enqueued handler to run and commit
  end

  def build_vars_window
    in_scope do
      @rows = []
      @table = gtk::Table.new(3, 3)
      %w[alpha beta].each_with_index do |name, i|
        label = gtk::Label.new(name)
        box = gtk::Box.new(:horizontal)
        box.pack_end(label, expand: false, fill: false, padding: 0)
        @table.attach(box, 0, 1, i, i + 1, gtk::AttachOptions::FILL, gtk::AttachOptions::FILL, 3, 3)
        entry = gtk::Entry.new
        entry.text = "value-#{name}"
        @table.attach(entry, 1, 2, i, i + 1, gtk::AttachOptions::EXPAND | gtk::AttachOptions::FILL, gtk::AttachOptions::FILL, 3, 3)
        button = gtk::Button.new(label: 'Delete Entry')
        @table.attach(button, 2, 3, i, i + 1, gtk::AttachOptions::SHRINK, gtk::AttachOptions::FILL, 3, 3)
        button.signal_connect('clicked') do
          label.sensitive = false
          entry.sensitive = false
          button.sensitive = false
        end
        @rows << [label, entry, button]
      end
      @new_name = gtk::Entry.new
      @new_name.text = '(new var name)'
      @new_name.signal_connect('focus-in-event') { @new_name.text = '' if @new_name.text == '(new var name)' }
      @table.attach(@new_name, 0, 1, 2, 3, gtk::AttachOptions::FILL, gtk::AttachOptions::FILL, 3, 3)
      viewport = gtk::Viewport.new(nil, nil)
      viewport.add(@table)
      @scrolled = gtk::ScrolledWindow.new
      @scrolled.set_policy(:automatic, :always)
      @scrolled.add(viewport)
      @window = gtk::Window.new
      @window.title = "Lich - Spec's Vars"
      @window.set_icon(nil)
      @window.add(@scrolled)
      @window.set_default_size(640, 300)
      @window.set_window_position(:center)
      @closed = false
      @window.signal_connect('delete_event') { @closed = true }
      @window.show_all
    end
    session.sync {}
  end

  describe 'ScriptScope binding' do
    it 'resolves Gtk to the shim only inside a scope binding' do
      binding = scope.script_binding
      expect(eval('defined?(Gtk)', binding)).to be_truthy
      expect(eval('Gtk', binding)).to equal(gtk)
      expect(eval('Gtk::Version::MAJOR == 3', binding)).to be(true)
      expect(eval('Gtk::Entry.new.class == Gtk::Entry', binding)).to be(true)
    end

    it 'lets a script define and call a top-level method' do
      binding = scope.script_binding
      expect(eval("def __gtk_shim_spec_helper; 42; end\n__gtk_shim_spec_helper", binding)).to eq(42)
    end

    it 'reaches a top-level method from the modules and classes the script defines' do
      scope.instance_variable_set(:@adopt_nested_constants, true)
      # An ordinary Lich script's `def` lands on Object, so its own modules
      # can call it; armor.lic calls a top-level `message` from a module.
      source = <<~SCRIPT
        def __shim_spec_message(text) = "MSG:" + text

        module ShimSpecArmorinfo
          def self.display = __shim_spec_message("info")

          module Nested
            class Deep
              def go = __shim_spec_message("deep")
            end
          end
        end

        [ShimSpecArmorinfo.display, ShimSpecArmorinfo::Nested::Deep.new.go]
      SCRIPT

      expect(eval(source, scope.script_binding)).to eq(%w[MSG:info MSG:deep])
    ensure
      scope.instance_variable_set(:@adopt_nested_constants, false)
      scope.send(:remove_const, :ShimSpecArmorinfo) if scope.const_defined?(:ShimSpecArmorinfo, false)
    end

    it 'keeps a shim superclass authoritative over a script helper of the same name' do
      scope.instance_variable_set(:@adopt_nested_constants, true)
      source = <<~SCRIPT
        def __shim_spec_helper = "SCRIPT-HELPER"
        def label = "SCRIPT-SHADOW"

        class ShimSpecToggle < Gtk::CheckButton
          def helper_reaches = __shim_spec_helper
          def inherited_wins = label
          def unknown_degrades = some_unimplemented_gtk_call
        end

        toggle = ShimSpecToggle.new("Check me")
        [toggle.helper_reaches, toggle.inherited_wins, toggle.unknown_degrades, toggle.class == ShimSpecToggle]
      SCRIPT

      result = session.sync { eval(source, scope.script_binding) }

      expect(result[0]).to eq('SCRIPT-HELPER')
      expect(result[1]).to eq('Check me') # the widget's own #label, not the script's shadow
      expect(result[2]).to be_nil # Widget#method_missing still degrades
      expect(result[3]).to be(true)
    ensure
      scope.instance_variable_set(:@adopt_nested_constants, false)
      scope.send(:remove_const, :ShimSpecToggle) if scope.const_defined?(:ShimSpecToggle, false)
    end
  end

  describe 'validation at the GTK boundary' do
    it 'keeps all grid cells and fillers when an entry has a long tooltip' do
      # rubocop:disable Custom/AsciiOnlySource -- a non-ASCII tooltip is the
      # point: the contract truncates by characters, not by bytes.
      tooltip = 'é' * 600
      in_scope do
        @window = gtk::Window.new
        grid = gtk::Grid.new
        @entry = gtk::Entry.new
        @entry.text = 'hunting commands'
        @entry.tooltip_text = tooltip
        grid.attach(gtk::Label.new('(a)'), 0, 0, 1, 1)
        grid.attach(@entry, 1, 0, 1, 1)
        grid.attach(gtk::Label.new('Valid Targets:'), 0, 1, 1, 1)
        @window.add(grid)
        @window.show_all
      end
      grid = tree.each.find { |node| node.type == :grid }
      expect(grid.children.map(&:type)).to eq(%i[text text_input text text])
      expect(grid.children[1].props).to include(value: 'hunting commands', tooltip: 'é' * 512)
      # rubocop:enable Custom/AsciiOnlySource
      expect(@entry.tooltip_text).to eq(tooltip)
    end

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

  describe 'a vars.lic-shaped window' do
    before { build_vars_window }

    it 'renders as a page > scroll > stack > grid of columns/text, text_input, button' do
      expect(opened.length).to eq(1)
      url, geometry, = opened.first
      expect(url).to include('/auth?token=')
      expect(geometry).to eq(width: 640, height: 300)

      root = tree
      expect(root.type).to eq(:page)
      expect(root.props).to include(title: "Lich - Spec's Vars", bare: true, size: [640, 300])
      scroll = root.children.first
      expect(scroll.type).to eq(:scroll)
      expect(scroll.props[:max_height]).to eq(252)
      grid = scroll.children.first.children.first
      expect(grid.type).to eq(:grid)
      expect(grid.props[:cols]).to eq(3)
      # the last row has only a column-0 child; the grid fills the hole so flow order holds
      expect(grid.children.map(&:type)).to eq(%i[columns text_input button columns text_input button text_input text text])
      expect(grid.children[0].children.first.props[:content]).to eq('alpha')
      expect(grid.children[1].props[:value]).to eq('value-alpha')
      expect(grid.children[2].props[:label]).to eq('Delete Entry')
    end

    it 'runs a clicked handler on the session thread and re-renders sensitivity' do
      label, entry, button = @rows.first
      fire(button.key, :activate)

      expect(label.sensitive?).to be(false)
      expect(component(label.key).props[:emphasis]).to eq('subtle')
      expect(component(entry.key).props[:disabled]).to be(true)
      expect(component(button.key).props[:disabled]).to be(true)
      expect(component(@rows.last[1].key).props).not_to include(:disabled)
    end

    it 'updates the entry shadow from a change event before handlers see it' do
      entry = @rows.first[1]
      seen = nil
      in_scope { entry.signal_connect('changed') { seen = entry.text } }
      fire(entry.key, :change, payload: { value: 'typed' })

      expect(seen).to eq('typed')
      expect(entry.text).to eq('typed')
    end

    it 'clears a placeholder on focus-in and pushes the write to the attached viewer' do
      writes = []
      allow(page).to receive(:set) { |cid, name, value, viewer:| writes << [cid, name, value, viewer] }
      fire(@new_name.key, :focus, viewer_id: 'attachment-1')

      expect(@new_name.text).to eq('')
      expect(component(@new_name.key).props[:value]).to eq('')
      expect(writes).to eq([[component(@new_name.key).cid, :value, '', 'attachment-1']])
    end

    it 'emits delete_event once when the viewer closes the page' do
      closes = page.lifecycle_bindings[:close]
      expect(closes).not_to be_nil
      closes.call(Lich::WebUI::Runtime::EventContext.new('attachment-1', page, tree, :close, { reason: 'user' }, nil))
      session.sync {}
      in_scope { @window.browser_exited }

      expect(@closed).to be(true)
      expect(session.adapter.page_for(@window.handle)).not_to be_nil
    end

    it 'destroys the page and the browser window on Window#destroy' do
      handle = @window.handle
      in_scope { @window.destroy }
      session.sync {}

      expect(session.adapter.page_for(handle)).to be_nil
      expect(service.registry.pages_for(owner)).to be_empty
      expect(opened.last).to eq([:killed, 4242])
    end
  end

  describe 'MessageDialog#run' do
    it 'maps a yes response to ResponseType::YES and a cancelled future to DELETE_EVENT' do
      future = Lich::WebUI::Future.new
      allow(session).to receive(:modal).and_return(future)
      responses = Queue.new
      session.enqueue do
        dialog = gtk::MessageDialog.new(parent: nil, flags: :modal, type: :question, buttons: :yes_no, message: 'Save changes?')
        dialog.title = 'Vars'
        responses << dialog.run
      end
      future.resolve(button: 'yes')
      expect(responses.pop).to eq(gtk::ResponseType::YES)

      cancelled = Lich::WebUI::Future.new
      allow(session).to receive(:modal).and_return(cancelled)
      session.enqueue { responses << gtk::MessageDialog.new(buttons: :ok, message: 'x').run }
      cancelled.cancel(reason: :closed)
      expect(responses.pop).to eq(gtk::ResponseType::DELETE_EVENT)
    end

    it 'sends the contract buttons and waits for a viewer' do
      captured = nil
      allow(service).to receive(:modal) { |**options| captured = options; Lich::WebUI::Future.new.tap { |f| f.resolve(button: 'no') } }
      allow(service).to receive(:server).and_return(double(connection_count: 1))
      result = session.sync { gtk::MessageDialog.new(buttons: :yes_no, message: 'Save changes?', type: :question).run }

      expect(result).to eq(gtk::ResponseType::NO)
      expect(captured).to include(owner: owner, title: 'Question', body: 'Save changes?', no_viewer: 'wait')
      expect(captured[:buttons].map { |b| b[:id] }).to eq(%w[yes no])
    end
  end

  describe 'Session.start_service' do
    it 'starts the server from a thread outside the calling thread group' do
      group = ThreadGroup.new
      groups = []
      accept_thread = nil
      probe = Lich::WebUI::Service.new
      allow(probe.server).to receive(:start) do
        groups << Thread.current.group
        accept_thread = Thread.new { sleep }
        probe.server
      end
      allow(probe.server).to receive(:running?).and_return(false)

      Thread.new do
        group.add(Thread.current)
        gtk::Session.start_service(probe)
      end.join

      expect(groups).to eq([ThreadGroup::Default])
      expect(accept_thread.group).to eq(ThreadGroup::Default)
      accept_thread.kill
    end
  end

  describe 'Gtk.queue' do
    it 'runs blocks in order on one thread and reports errors without killing it' do
      log = []
      threads = []
      session.enqueue { log << 1; threads << Thread.current }
      session.enqueue { raise 'boom' }
      session.enqueue { log << 2; threads << Thread.current }
      session.sync {}

      expect(log).to eq([1, 2])
      expect(threads.uniq.length).to eq(1)
    end
  end

  describe 'unsupported API' do
    it 'degrades instead of raising' do
      entry = session.sync { gtk::Entry.new }
      expect(session.sync { entry.set_icon_from_icon_name(:primary, 'x') }).to equal(entry)
      expect(session.sync { entry.some_query }).to be_nil
    end

    it 'gives an unimplemented widget constant an empty container that swallows placement' do
      # Gtk::Layout and friends: the script keeps running and loses only
      # that part of its window. Restored so the constant stays missing.
      gtk.send(:remove_const, :Layout) if gtk.const_defined?(:Layout, false)

      layout = session.sync { gtk::Layout.new }
      expect(layout).to be_a(gtk::Container)
      expect(layout.class.name).to eq('Gtk::Layout')

      child = session.sync { gtk::Label.new('marker') }
      expect(session.sync { layout.put(child, 10, 20) }).to equal(layout)
      expect(session.sync { layout.move(child, 30, 40) }).to equal(layout)
      expect(session.sync { layout.set_size(800, 600) }).to equal(layout)
      expect(layout.children).to eq([child])
    ensure
      gtk.send(:remove_const, :Layout) if gtk.const_defined?(:Layout, false)
    end

    it 'gives an unimplemented non-widget constant the symbol it was named' do
      gtk.send(:remove_const, :INVENTED_FLAG) if gtk.const_defined?(:INVENTED_FLAG, false)

      expect(gtk::INVENTED_FLAG).to eq(:invented_flag)
    ensure
      gtk.send(:remove_const, :INVENTED_FLAG) if gtk.const_defined?(:INVENTED_FLAG, false)
    end
  end

  describe 'Gtk::Alignment' do
    it 'wraps its child and carries xalign as the contract align, unless the scale fills' do
      aligned = session.sync do
        box = gtk::Alignment.new(1.0, 0.5, 0.0, 0.0)
        box.set_padding(4, 4, 8, 8)
        box.add(gtk::Label.new('Resting Room ID:'))
        box
      end
      filled = session.sync { gtk::Alignment.new(0.0, 0.5, 1.0, 1.0).add(gtk::Label.new('wide')) }

      expect(aligned.common_props).to include(align: 'end', margin: { top: 4, bottom: 4, left: 8, right: 8 })
      expect(aligned.node_type).to eq(:stack)
      expect(filled.common_props).not_to include(:align)
    end
  end
end
