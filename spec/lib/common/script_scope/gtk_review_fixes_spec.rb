# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# Fixes from the 2026-09-16 review. A viewer-scoped property (checked,
# value, open, selected) has a per-viewer copy that shadows the shared prop,
# so re-rendering alone changes nothing the browser shows. The write has to
# be pushed to every viewer as well; that pairing was hand-copied at ten
# sites and forgotten at five, each a separate user-visible bug.
RSpec.describe 'GTK compatibility shim: review fixes' do
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
    it 'deselects the other radio button on the viewer, not only in the shim' do
      a, b = in_window { |box| [gtk::RadioButton.new('A'), nil].tap { |pair| pair[1] = gtk::RadioButton.new(pair[0], 'B'); box.add(pair[0]); box.add(pair[1]) } }

      session.sync { a.active = true; b.active = true }

      expect(pushes).to include(['RadioButton', :checked, false])
      expect(a.active?).to be(false)
    end
  end

  # D3 (ledger part 2): every property write from a script thread used to
  # enqueue a full commit, and every job the session ran ended in another,
  # so a script setting twenty labels re-rendered every window forty
  # times. The session now drains everything already queued and commits
  # once per batch; a nested pump does the same.
  describe 'coalesced commits (D3)' do
    let(:sequence) { [] }

    def shown_label
      label = nil
      session.sync do
        window = gtk::Window.new('Burst')
        window.set_default_size(100, 100)
        label = gtk::Label.new('0')
        window.add(label)
        window.show_all
      end
      session.sync {}
      label
    end

    def rendered_content(label)
      page = service.registry.pages_for(owner).fetch(0)
      page.last_render.tree.each.find { |node| node.props[:key] == label.key }.props[:content]
    end

    it 'runs a burst of off-thread writes as one batch with one commit after it' do
      label = shown_label
      log = sequence
      allow(session).to(receive(:commit).and_wrap_original { |original, *args| log << :commit; original.call(*args) })
      gate = Queue.new
      session.enqueue { gate.pop }
      20.times { |i| label.text = i.to_s } # off the session thread: each asks for a commit
      session.enqueue { log << :done }
      gate << :go
      session.sync {}

      expect(log.take_while { |entry| entry != :done }).to eq([])
      expect(log.index(:commit)).to eq(log.index(:done) + 1)
      expect(rendered_content(label)).to eq('19')
    end

    it 'commits once per pump, however many jobs were waiting' do
      shown_label
      commits = 0
      allow(session).to(receive(:commit).and_wrap_original { |original, *args| commits += 1; original.call(*args) })
      gate = Queue.new
      session.enqueue { gate.pop }
      sleep 0.05 # the session thread is now parked inside that job
      ran = []
      5.times { |i| session.enqueue { ran << i } }

      before = commits
      pumped = session.pump(0.05)
      during = commits - before
      gate << :go
      session.sync {}

      expect(pumped).to be(true)
      expect(ran).to eq([0, 1, 2, 3, 4])
      expect(during).to eq(1)
    end

    it 'bounds a batch so a flood still renders between batches' do
      expect(gtk::Session::BATCH_LIMIT).to be <= gtk::Session::HOP_LIMIT
    end
  end

  describe 'a widget that is destroyed' do
    it 'says so, for every widget and not only a window' do
      label = session.sync { gtk::Label.new('x') }

      session.sync { label.destroy }

      expect(label.destroyed?).to be(true)
    end
  end

  describe 'the session thread' do
    # commit rescued only WebUI errors, so a plain NoMethodError inside a
    # widget's node_props escaped run_loop and ended the thread.
    it 'survives a script error raised during commit' do
      allow(session).to receive(:report)
      boom = session.sync { gtk::Label.new('boom') }
      boom.define_singleton_method(:node_props) { raise NoMethodError, 'deliberate' }
      session.sync do
        window = gtk::Window.new('Boom')
        window.set_default_size(100, 100)
        window.add(boom)
        window.show_all
      end
      sleep 0.2

      expect(session.sync { :alive }).to eq(:alive)
      expect(session).to have_received(:report).with(an_instance_of(NoMethodError)).at_least(:once)
    end
  end
end

RSpec.describe Lich::WebUI::Adapter, 'review fixes' do
  let(:service) { Lich::WebUI::Service.new }
  let(:adapter) { described_class.new(owner: Object.new, service: service, viewer: 'viewer-one') }

  after { service.stop }

  # A later bind for the same event replaces the earlier one; unbinding the
  # old id must not remove its replacement.
  it 'keeps a replacement binding when the binding it replaced is unbound' do
    button = adapter.create(:button, label: 'Go')
    first = adapter.bind(button, :activate, ->(_event) { :first })
    second = adapter.bind(button, :activate, ->(_event) { :second })

    adapter.unbind(first)

    expect(adapter.instance_variable_get(:@nodes)[button].bindings[:activate]).to eq(second)
  end

  # detach reassigns named slots; destroy did not, so a destroyed child left
  # a gap that shifted every later sibling.
  it 'reassigns named slots after a child is destroyed, as detach does' do
    columns = adapter.create(:columns, count: 3)
    children = 3.times.map { |i| adapter.create(:text, content: "c#{i}").tap { |h| adapter.attach(columns, h, i) } }
    nodes = adapter.instance_variable_get(:@nodes)
    slots_before = children.map { |h| nodes[h].slot }

    adapter.destroy(children[0])

    slots_after = children.drop(1).map { |h| nodes[h].slot }
    expect(slots_before).to eq(%w[0 1 2])
    expect(slots_after).to eq(%w[0 1])
  end
end

RSpec.describe Lich::WebUI::Dispatcher, 'review fixes' do
  # Two viewers editing the same control are two events; folding them
  # together dropped one viewer's update.
  it 'coalesces a repeat from the same viewer but never across viewers' do
    dispatcher = described_class.new(logger: proc { |*| }, thread_factory: ->(&_block) { Thread.new { sleep } })
    owner = Object.new
    enqueue = ->(viewer) { dispatcher.enqueue(owner: owner, page_id: 'p', viewer_id: viewer, cid: 'c', event: 'change', coalescable: true) {} }

    results = [enqueue.call('v1'), enqueue.call('v2'), enqueue.call('v2'), enqueue.call('v1')]

    expect(results).to eq(%i[queued queued coalesced queued])
  end
end

RSpec.describe Lich::WebUI::Runtime, 'review fixes' do
  # A refresh_loop thread and a direct refresh from the script's commit could
  # deliver renders for one page out of order.
  it 'serialises refreshes per page with one lock per page' do
    service = Lich::WebUI::Service.new
    runtime = service.runtime
    page_a = Lich::WebUI::Page.new(owner: Object.new, id: 'a', title: 'A') { text(content: 'a') }
    page_b = Lich::WebUI::Page.new(owner: Object.new, id: 'b', title: 'B') { text(content: 'b') }

    lock_a = runtime.send(:page_refresh_lock, page_a)

    expect(lock_a).to be_a(Mutex)
    expect(runtime.send(:page_refresh_lock, page_a)).to equal(lock_a)
    expect(runtime.send(:page_refresh_lock, page_b)).not_to equal(lock_a)
  ensure
    service&.stop
  end

  # `alias set_foo foo=` looks like it defines GTK's set_foo and does
  # everything except return the right thing: Ruby makes an assignment method
  # evaluate to its argument whatever the body returns, and an alias of one
  # keeps that rule. 829 setters answered the value instead of the widget, so
  # `Gtk::Entry.new.set_text(v)` -- the first line of real work in
  # perfume.lic -- handed back a String, and `.text` on it raised
  # NoMethodError. ruby-gnome's own set_* return the widget.
  describe 'a set_ mutator' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }

    it 'returns the widget so the constructor idiom chains' do
      entry = gtk::Entry.new.set_text('cologne')

      expect(entry).to be_a(gtk::Entry)
      expect(entry.text).to eq('cologne')
    end

    it 'chains more than once' do
      button = gtk::Button.new('go').set_sensitive(false).set_tooltip_text('no')

      expect(button).to be_a(gtk::Button)
      expect(button.sensitive?).to be(false)
    end

    it 'still writes the value it was given' do
      check = gtk::CheckButton.new('Wearable?').set_active(true)

      expect(check.active?).to be(true)
    end

    # The margin family is declared in a loop, and the loop used alias_method
    # rather than the writer, so it kept the same trap after the rest was fixed.
    it 'returns the widget from the margin family too' do
      label = gtk::Label.new('x')

      expect(label.set_margin_top(4)).to equal(label)
      expect(label.set_margin_left(2)).to equal(label)
    end

    it 'leaves no set_ mutator answering something other than the widget' do
      offenders = []
      gtk.constants.filter_map { |name| gtk.const_get(name) rescue nil }
                   .select { |value| value.is_a?(Class) && value <= gtk::Widget }
                   .each do |klass|
        instance = (klass.new rescue (klass.new('x') rescue nil))
        next unless instance

        (klass.instance_methods.grep(/\Aset_[a-z_]+\z/) - Object.instance_methods).each do |method|
          next unless [1, -1, -2].include?(klass.instance_method(method).arity)

          result = begin
            instance.public_send(method, nil)
          rescue StandardError
            next
          end
          offenders << "#{klass}##{method}" unless result.equal?(instance)
        end
      end

      expect(offenders).to be_empty
    end
  end

  # Grid reads hexpand? at render rather than recording it at attach, exactly
  # so a script can set it after attaching. Neither setter called changed!, so
  # the widget never became dirty and the column kept its old weight.
  describe 'hexpand and vexpand' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }

    it 'marks the widget dirty so a later set re-renders' do
      label = gtk::Label.new('x')
      label.instance_variable_set(:@dirty, false)
      label.hexpand = true

      expect(label.instance_variable_get(:@dirty)).to be(true)
    end

    it 'marks the widget dirty for vexpand too' do
      label = gtk::Label.new('x')
      label.instance_variable_set(:@dirty, false)
      label.vexpand = true

      expect(label.instance_variable_get(:@dirty)).to be(true)
    end

    # @vexpand was written and never read by anything.
    it 'lets the recorded vexpand be read back' do
      label = gtk::Label.new('x')
      label.vexpand = true

      expect(label.vexpand?).to be(true)
      expect(gtk::Label.new('y').vexpand?).to be(false)
    end
  end

  # Deriving the next handler id from the hash's size reused a live id after
  # any disconnect, so disconnecting the handler a script meant to drop
  # silently killed a later one instead.
  describe 'signal handler ids' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }

    it 'never reuses an id after a disconnect' do
      button = gtk::Button.new('x')
      first = button.signal_connect('clicked') { :first }
      second = button.signal_connect('clicked') { :second }
      button.signal_handler_disconnect(second)
      third = button.signal_connect('clicked') { :third }

      expect([first, second, third].uniq.length).to eq(3)
      expect(third).to be > second
    end

    it 'disconnects the handler it was asked to, and only that one' do
      button = gtk::Button.new('x')
      fired = []
      button.signal_connect('clicked') { fired << :first }
      second = button.signal_connect('clicked') { fired << :second }
      button.signal_handler_disconnect(second)
      button.signal_connect('clicked') { fired << :third }
      button.send(:emit, :clicked)

      expect(fired).to contain_exactly(:first, :third)
    end
  end

  # The shim's stated principle is to report what it cannot honour rather
  # than drop it quietly, and it is applied well in some places (dropped
  # cells, stubbed classes, the borderless refusal) and not at all in
  # others. A horizontal box past twelve children, a grid past twenty-four
  # columns, a margin past 512px and a second widget in an occupied pane all
  # lost the excess in silence, which turns a script bug into a rendering
  # mystery.
  describe 'a value the contract cannot carry' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }

    before { gtk.reset_unsupported! }

    def warnings
      gtk.unsupported_report.values.flat_map(&:keys)
    end

    it 'reports a horizontal box past what the contract counts' do
      box = gtk::Box.new(:horizontal, 0)
      15.times { |index| box.add(gtk::Label.new("c#{index}")) }
      box.send(:node_props)

      expect(warnings).to include('Gtk::Box.children')
    end

    it 'says nothing when the box fits' do
      box = gtk::Box.new(:horizontal, 0)
      4.times { |index| box.add(gtk::Label.new("c#{index}")) }
      box.send(:node_props)

      expect(warnings).to be_empty
    end

    it 'reports a margin past what the contract carries' do
      label = gtk::Label.new('x')
      label.margin_top = 900
      label.send(:common_props)

      expect(warnings).to include('Gtk::Label.margin')
    end

    it 'reports a grid wider than the contract allows' do
      grid = gtk::Grid.new
      grid.attach(gtk::Label.new('x'), 40, 0, 1, 1)
      grid.column_count

      expect(warnings).to include('Gtk::Grid.columns')
    end
  end

  # Unsupported-API warnings were deduplicated per API for the whole process,
  # so the second script to hit the same gap was never mentioned and "no
  # warnings on the next run" passed for support. The ledger is per script
  # and counts every hit, so a supported-script manifest can be written from
  # what happened rather than from what loaded without error.
  describe 'the ledger of what the shim did not support' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }

    before { gtk.reset_unsupported! }
    after { gtk.reset_unsupported! }

    def as_script(name)
      allow(gtk::Session).to receive(:current_script).and_return(Struct.new(:name).new(name))
      yield
    end

    it 'records each script separately and counts every hit' do
      logged = []
      allow(Lich).to receive(:log) { |line| logged << line }

      as_script('map') { 2.times { gtk.log_unsupported('Cairo::Context', 'show_text') } }
      as_script('bsprofiles') { gtk.log_unsupported('Cairo::Context', 'show_text', note: 'text') }

      report = gtk.unsupported_report
      expect(report.fetch('map')).to eq('Cairo::Context#show_text' => { count: 2, note: nil })
      expect(report.fetch('bsprofiles')).to eq('Cairo::Context#show_text' => { count: 1, note: 'text' })
      expect(logged.grep(/unsupported Cairo::Context#show_text/).length).to eq(2)
      expect(logged).to include(a_string_matching(/script=map/), a_string_matching(/script=bsprofiles/))
      expect(gtk.unsupported_summary('map')).to eq('webui-gtk-shim: script=map unsupported: Cairo::Context#show_text (2)')
      expect(gtk.unsupported_summary('nobody')).to be_nil
    end
  end

  # A container's identity map of child handles was only ever added to. A
  # child removed from the tree was destroyed and released, but the map kept
  # it -- and through it the widget's whole reachable state -- for as long as
  # the container lived. A window that replaces its rows leaked every one.
  describe 'a child removed from a container' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }
    let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('rows') }
    let(:service) { Lich::WebUI::Service.new }
    let(:session) { gtk::Session.new(owner, service: service) }

    # These show windows; without the seam a real browser opens on the desktop.
    before do
      gtk::Session.browser_open = proc { |_url, on_start:, **| on_start.call(1); true }
    end

    after do
      gtk::Session.browser_open = nil
      session.shutdown
      service.stop
    end

    it 'is forgotten by the synchronisation bookkeeping, not just destroyed' do
      window = box = label = nil
      session.sync do
        window = gtk::Window.new('R')
        box = gtk::VBox.new
        label = gtk::Label.new('row')
        box.add(label)
        window.add(box)
        window.show_all
      end
      session.commit
      expect(box.instance_variable_get(:@synced_handles)).to have_key(label)

      session.sync { box.remove(label) }
      session.commit

      expect(box.children).not_to include(label)
      expect(label.handle).to be_nil
      expect(box.instance_variable_get(:@synced_handles)).not_to have_key(label)
    end

    # The other retention path: the shim adapter keeps a presentation reader
    # per page root, a closure over the window, and the base adapter's
    # destroy did not know to drop it.
    it 'releases a destroyed window from the presentation readers' do
      window = nil
      session.sync do
        window = gtk::Window.new('P')
        window.add(gtk::Label.new('x'))
        window.show_all
      end
      session.commit
      handle = window.handle
      sources = session.adapter.instance_variable_get(:@presentation_sources)
      expect(sources).to have_key(handle)

      session.close_window(window)

      expect(sources).not_to have_key(handle)
    end
  end

  # The dispatcher's bounded queue protected nothing: dispatch_proc moved
  # every event straight onto the session's unbounded queue, so with the
  # session thread blocked a thousand events were accepted and kept.
  describe 'the hop from the dispatcher onto the session thread' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }
    let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('hop') }
    let(:service) { Lich::WebUI::Service.new }
    let(:session) { gtk::Session.new(owner, service: service) }

    after do
      session.shutdown
      service.stop
    end

    it 'parks the dispatcher while the session queue is full, then drops rather than grows' do
      stub_const('Lich::Common::ScriptScope::Gtk::Session::HOP_LIMIT', 4)
      stub_const('Lich::Common::ScriptScope::Gtk::Session::HOP_WAIT', 0.05)
      gate = Queue.new
      ran = Queue.new
      session.enqueue { gate.pop }
      sleep 0.02 # the session thread is now parked inside that job
      hop = session.dispatch_proc(Struct.new(:handle).new(nil)) { ran << :ran }
      context = Struct.new(:event).new(:activate)

      4.times { hop.call(context) }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      hop.call(context) # no room: waits HOP_WAIT, then drops
      waited = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(waited).to be >= 0.05
      expect(session.instance_variable_get(:@queue).size).to eq(4)
      gate << :go
      4.times { expect(ran.pop).to eq(:ran) }
      sleep 0.05
      expect(ran).to be_empty
    end
  end

  # Session teardown left the queue open. A timer or a browser-exit callback
  # firing afterwards was queued, and ensure_thread started a fresh session
  # thread to run it: a callback executing with the session closed and every
  # window already gone.
  describe 'a session after shutdown' do
    let(:gtk) { Lich::Common::ScriptScope::Gtk }
    let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('late') }
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

    it 'drops late work instead of starting a new thread to run it' do
      session.sync { gtk::Window.new('S').show_all }
      session.shutdown
      thread_before = session.instance_variable_get(:@thread)
      ran = false

      session.enqueue { ran = true }
      sleep 0.05

      expect(ran).to be(false)
      expect(session.instance_variable_get(:@thread)).to equal(thread_before)
      expect { session.sync { :never } }.to raise_error(Lich::WebUI::Error, /shut down/)
    end
  end
end

# The registry mutex exists to make "one session per owner" a safe
# check-then-act, but the shared null owner was memoised before taking it.
# Two concurrent Session.for(nil) calls could each build their own
# NullOwner and register two "shared" sessions under two keys.
RSpec.describe 'GTK compatibility shim: the shared null owner' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:mutex) { gtk::Session.instance_variable_get(:@registry_mutex) }

  around do |example|
    previous = gtk::Session.instance_variable_get(:@null_owner)
    gtk::Session.instance_variable_set(:@null_owner, nil)
    example.run
  ensure
    owner = gtk::Session.instance_variable_get(:@null_owner)
    gtk::Session.release(owner)&.shutdown if owner
    gtk::Session.instance_variable_set(:@null_owner, previous)
  end

  it 'is memoised under the registry mutex, never outside it' do
    lock = mutex
    allow(gtk::Session::NullOwner).to receive(:new).and_wrap_original do |original, *args|
      raise 'NullOwner built outside the registry mutex' unless lock.owned?

      original.call(*args)
    end

    expect { gtk::Session.for(nil) }.not_to raise_error
    expect(gtk::Session::NullOwner).to have_received(:new).once
  end

  it 'gives two racing callers the same session' do
    barrier = Queue.new
    sessions = Array.new(2) { Thread.new { barrier.pop; gtk::Session.for(nil) } }
    2.times { barrier << :go }

    first, second = sessions.map(&:value)

    expect(first).to equal(second)
  end
end

# @viewers was a default-proc Hash, so asking which viewers watch a page
# inserted an entry for that page. Only close_window deleted, and every
# page ever asked about stayed alive through the table.
RSpec.describe 'GTK compatibility shim: the viewer table' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('viewers') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }

  after do
    session.shutdown
    service.stop
  end

  it 'is not grown by a read' do
    page = Object.new

    expect(session.send(:viewers_for, page)).to eq([])
    session.send(:forget_viewer, page, 'nobody')

    expect(session.instance_variable_get(:@viewers)).to be_empty
  end

  it 'still records and forgets a viewer' do
    page = Object.new

    session.send(:note_viewer, page, 'v1')
    expect(session.send(:viewers_for, page)).to eq(['v1'])

    session.send(:forget_viewer, page, 'v1')
    expect(session.send(:viewers_for, page)).to eq([])
  end
end

# The ledger deduplicated per script NAME for the life of the process, so
# a script run, exited, and run again ten minutes later never got its
# "not supported yet" notice the second time: once per class per process,
# not per session. A session now forgets its script's entries at shutdown,
# after the summary line has been logged from them.
RSpec.describe 'GTK compatibility shim: the ledger across script runs' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('map') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }

  before do
    gtk.reset_unsupported!
    allow(gtk::Session).to receive(:current_script).and_return(owner)
    allow(Lich).to receive(:log)
  end

  after do
    gtk.reset_unsupported!
    session.shutdown
    service.stop
  end

  it 'fires the first-hit notice again on the next run of the same script' do
    expect(gtk.send(:record_unsupported, 'Gtk::Zap#pow', nil)).to eq(['map', true])

    session.shutdown

    expect(Lich).to have_received(:log).with(a_string_matching(/script=map unsupported: Gtk::Zap#pow \(1\)/))
    expect(gtk.unsupported_report).not_to have_key('map')
    expect(gtk.send(:record_unsupported, 'Gtk::Zap#pow', nil)).to eq(['map', true])
  end

  it 'forgets only the script it is asked about' do
    gtk.send(:record_unsupported, 'Gtk::Zap#pow', nil)
    allow(gtk::Session).to receive(:current_script).and_return(Struct.new(:name).new('other'))
    gtk.send(:record_unsupported, 'Gtk::Zap#pow', nil)

    gtk.forget_unsupported('map')

    expect(gtk.unsupported_report.keys).to eq(['other'])
  end
end

# OWN_DEFINITIONS keeps const_missing from stubbing a class a later slice
# file defines, but it is hand-maintained: a name left off the list meant
# the real class was silently shadowed by an empty box for the rest of the
# process. Boot now checks the list once loading is done and refuses to
# load rather than render a mystery.
RSpec.describe 'GTK compatibility shim: the own-definitions check at boot' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }

  it 'finds every listed name defined by the shim, not by a stub' do
    gtk.singleton_class::OWN_DEFINITIONS.each do |name|
      expect(gtk.const_defined?(name, false)).to be(true), "Gtk::#{name} is not defined"
      expect(gtk.const_get(name)).not_to respond_to(:webui_stub?), "Gtk::#{name} is a stub"
    end
    expect { gtk.verify_own_definitions! }.not_to raise_error
  end

  it 'refuses to load when a listed name resolved to a stub' do
    gtk.const_set(:TemporaryStubbed, gtk.unimplemented_widget(:TemporaryStubbed))

    expect { gtk.verify_own_definitions!([:TemporaryStubbed]) }
      .to raise_error(LoadError, /Gtk::TemporaryStubbed.*stub/)
  ensure
    gtk.send(:remove_const, :TemporaryStubbed) if gtk.const_defined?(:TemporaryStubbed, false)
  end

  it 'refuses to load when a listed name was never defined' do
    expect { gtk.verify_own_definitions!([:NeverDefined]) }
      .to raise_error(LoadError, /Gtk::NeverDefined.*not defined/)
    expect(gtk.const_defined?(:NeverDefined, false)).to be(false)
  end
end
