# frozen_string_literal: true

require 'timeout'
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
    gtk::Session.browser_open = proc { |url, geometry:, on_start:| opened << [url, geometry]; on_start.call(4242); true }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
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
      # 2.15: a scroller filling its window is sized by the stylesheet, which
      # tracks the viewport. A pixel max_height taken from the startup default
      # never grew when the window was resized and, when the window opened
      # smaller than it, produced a second scrollbar.
      expect(scroll.props).not_to include(:max_height)
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
      in_scope { @window.viewer_closed }

      expect(@closed).to be(true)
      expect(session.adapter.page_for(@window.handle)).not_to be_nil
    end

    # D1: the window lands in the user's ordinary browser, sharing its
    # process, so there is no process of ours to kill; the page is closed
    # and the client removes it.
    it 'destroys the page on Window#destroy and never kills a browser process' do
      handle = @window.handle
      expect(Process).not_to receive(:kill)
      in_scope { @window.destroy }
      session.sync {}

      expect(session.adapter.page_for(handle)).to be_nil
      expect(service.registry.pages_for(owner)).to be_empty
      expect(opened).to eq([opened.first])
      expect(gtk::Session).not_to respond_to(:browser_kill)
    end
  end

  # D26 (ledger part 2): ScrolledWindow keeps one scroll extent per widget,
  # written by whichever viewer reported last, so a shim page open in two
  # browsers has two viewers overwriting one state. Single-viewer per shim
  # window is the supported case: a second attach is refused -- the
  # newcomer, because the first viewer is the window the script opened --
  # and told so with page_closed. A viewer that left makes room again.
  describe 'a second viewer on a shim page (D26)' do
    let(:connection_class) do
      Class.new do
        attr_reader :viewer_id

        def initialize(viewer_id)
          @viewer_id = viewer_id
          @sent = []
          @mutex = Mutex.new
        end

        def send_text(payload)
          @mutex.synchronize { @sent << JSON.parse(payload) }
          true
        end

        def sent = @mutex.synchronize { @sent.dup }
        def alive? = true
      end
    end

    def attach(connection)
      address = service.registry.address_for(page)
      service.runtime.handle(connection, type: 'attach', page: address, version: Lich::WebUI::Contract::VERSION)
      address
    end

    def closed_message(connection)
      connection.sent.find { |message| message['type'] == 'page_closed' }
    end

    def settle
      Timeout.timeout(3) { sleep 0.02 until yield }
    end

    # The attach lifecycle reaches the session through the dispatcher, so
    # "attached" is when the session has admitted the viewer.
    def admitted
      settle { session.send(:viewers_for, page).length == 1 }
    end

    before { build_vars_window }

    it 'refuses the newcomer and keeps the first viewer' do
      first = connection_class.new('conn-first')
      second = connection_class.new('conn-second')
      attach(first)
      admitted

      attach(second)
      settle { closed_message(second) }

      expect(closed_message(second)).to include('reason' => 'refused')
      expect(closed_message(first)).to be_nil
      expect(service.runtime.viewer_ids(page).length).to eq(1)
      expect(session.send(:viewers_for, page).length).to eq(1)
    end

    # A tab the viewer closes sends an explicit detach message, which the
    # runtime turns into `close`. A browser window closed with its X does
    # not reliably get that message out before the process tears the page
    # down; what the server sees then is the socket going away, which is
    # `detach` -- the same signal as a transient loss the client dials back
    # from -- and, with no process of ours to watch (D1), nothing else. So
    # eloot's setup window was closed and eloot ran on, never told. A
    # detach nobody returns from within the grace is the window closing.
    it 'tells the script its window closed when a dropped socket does not come back' do
      gtk::Session.detach_grace = 0.05
      first = connection_class.new('conn-first')
      attach(first)
      admitted
      service.runtime.disconnect(first)

      settle { @closed }
      expect(@closed).to be(true)
    ensure
      gtk::Session.detach_grace = nil
    end

    it 'says nothing when the viewer dials back inside the grace' do
      gtk::Session.detach_grace = 0.2
      first = connection_class.new('conn-first')
      attach(first)
      admitted
      service.runtime.disconnect(first)
      settle { service.runtime.viewer_ids(page).empty? }
      expect(@closed).to be(false)
      # A reconnect is a new connection, hence a new server-minted viewer id.
      again = connection_class.new('conn-again')
      attach(again)
      admitted
      sleep 0.35
      session.sync {}

      expect(@closed).to be(false)
    ensure
      gtk::Session.detach_grace = nil
    end

    it 'admits a new viewer once the first has detached' do
      first = connection_class.new('conn-first')
      address = attach(first)
      admitted
      generation = first.sent.last['generation']
      service.runtime.handle(first, type: 'detach', page: address, generation: generation)
      settle { service.runtime.viewer_ids(page).empty? }

      second = connection_class.new('conn-second')
      attach(second)
      settle { service.runtime.viewer_ids(page).length == 1 }
      session.sync {}

      expect(closed_message(second)).to be_nil
      expect(service.runtime.viewer_ids(page).length).to eq(1)
    end
  end

  # D1 (ledger part 2): lich-6 gives the private profile and the process
  # monitor to the launcher only; a script page opens through
  # BrowserLauncher.open(url) with no on_exit, so it lands in the user's
  # ordinary Chrome as an app window. Shim windows do the same. A closed
  # window is noticed through the viewer detach/close path, not by watching
  # a process; on_start still yields the pid the Windows presentation
  # lookup needs.
  describe 'opening a shim window (D1)' do
    it 'asks the launcher for an app window with a geometry and a pid callback, and nothing else' do
      gtk::Session.browser_open = nil
      calls = []
      allow(Lich::WebUI::BrowserLauncher).to receive(:open) { |url, **options| calls << [url, options]; true }

      build_vars_window

      expect(calls.length).to eq(1)
      url, options = calls.first
      expect(url).to include('/auth?token=')
      expect(options.keys.sort).to eq(%i[geometry on_start])
      expect(options[:geometry]).to eq(width: 640, height: 300)
      expect(options[:on_start]).to be_a(Proc)
    end

    it 'has no browser-exit path left on a window or a dialog' do
      expect(gtk::Window.instance_methods).not_to include(:browser_exited)
      expect(gtk::Dialog.instance_methods).not_to include(:browser_exited)
    end

    it 'opens a modal of its own without a process monitor when no window is open' do
      gtk::Session.browser_open = nil
      calls = []
      allow(Lich::WebUI::BrowserLauncher).to receive(:open) { |_url, **options| calls << options; true }

      future = session.modal(title: 'Q', buttons: [{ id: 'ok', label: 'OK', variant: 'primary' }])
      future.cancel(reason: :test)

      expect(calls.length).to eq(1)
      expect(calls.first.keys.sort).to eq(%i[geometry on_start])
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
      # The script keeps running and loses only that part of its window.
      #
      # This used to use Gtk::Layout, removing the constant to force the
      # stub -- and its ensure block removed it again, so every example that
      # ran afterwards saw Layout stubbed rather than implemented. Now that
      # the shim implements Layout, a name it genuinely does not implement
      # is the only safe subject: const_missing const_sets its answer, so
      # stubbing a real class leaks into the rest of the process.
      gtk.send(:remove_const, :DrawingArea) if gtk.const_defined?(:DrawingArea, false)

      layout = session.sync { gtk::DrawingArea.new }
      expect(layout).to be_a(gtk::Container)
      expect(layout.class.name).to eq('Gtk::DrawingArea')

      child = session.sync { gtk::Label.new('marker') }
      expect(session.sync { layout.put(child, 10, 20) }).to equal(layout)
      expect(session.sync { layout.move(child, 30, 40) }).to equal(layout)
      expect(session.sync { layout.set_size(800, 600) }).to equal(layout)
      expect(layout.children).to eq([child])
    ensure
      gtk.send(:remove_const, :DrawingArea) if gtk.const_defined?(:DrawingArea, false)
    end

    it 'gives an unimplemented non-widget constant the symbol it was named' do
      gtk.send(:remove_const, :INVENTED_FLAG) if gtk.const_defined?(:INVENTED_FLAG, false)

      expect(gtk::INVENTED_FLAG).to eq(:invented_flag)
    ensure
      gtk.send(:remove_const, :INVENTED_FLAG) if gtk.const_defined?(:INVENTED_FLAG, false)
    end

    # The admission rule (docs/webui-rebuild-plan.md): images, layouts,
    # drawing areas and menus are not shimmed -- the scripts that used them
    # are rewritten natively. A script that names one must get the
    # stubbed-widget notice and a ledger entry, never a shadowed class, so
    # none of these names may be in OWN_DEFINITIONS or defined by boot.
    %i[Menu MenuItem CheckMenuItem RadioMenuItem SeparatorMenuItem Image Layout DrawingArea].each do |name|
      it "answers Gtk::#{name} with the stubbed-widget notice and a ledger entry" do
        gtk.send(:remove_const, name) if gtk.const_defined?(name, false)
        gtk.reset_unsupported!
        told = []
        allow(Kernel).to receive(:respond) { |message| told << message }

        expect(gtk.singleton_class::OWN_DEFINITIONS).not_to include(name)
        stub = session.sync { gtk.const_get(name).new }
        expect(stub).to be_a(gtk::Container)
        expect(stub.class).to respond_to(:webui_stub?)
        expect(gtk.unsupported_report.values.flat_map(&:keys)).to include("Gtk::#{name}")
        expect(told.join).to include("Gtk::#{name} is not supported yet")
      ensure
        gtk.send(:remove_const, name) if gtk.const_defined?(name, false)
      end
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
