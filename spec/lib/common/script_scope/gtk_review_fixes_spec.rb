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
    gtk::Session.browser_open = proc { |_url, geometry:, on_start:, on_exit:| [geometry, on_exit]; on_start.call(1); true }
    gtk::Session.browser_kill = proc { |_pid| nil }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
    recorder = pushes
    session.define_singleton_method(:viewer_write) do |_window, widget, name, value|
      recorder << [widget.class.name.split('::').last, name, value]
    end
  end

  after do
    gtk::Session.browser_open = nil
    gtk::Session.browser_kill = nil
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

    it 'deselects the other radio menu item on the viewer' do
      x, y = in_window do |box|
        bar = gtk::MenuBar.new
        top = gtk::MenuItem.new(label: 'Top')
        bar.append(top)
        sub = gtk::Menu.new
        top.submenu = sub
        first = gtk::RadioMenuItem.new(nil, 'X')
        second = gtk::RadioMenuItem.new(first, 'Y')
        sub.append(first)
        sub.append(second)
        box.add(bar)
        [first, second]
      end

      session.sync { x.active = true; y.active = true }

      expect(pushes).to include(['RadioMenuItem', :active, false])
    end

    it 'takes a menu down on the viewer when the script pops it down' do
      bar = in_window { |box| gtk::MenuBar.new.tap { |b| b.append(gtk::MenuItem.new(label: 'Top')); box.add(b) } }

      session.sync { bar.instance_variable_set(:@open, true); bar.popdown }

      expect(pushes).to include(['MenuBar', :open, false])
    end

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

    before { gtk.instance_variable_set(:@unsupported, {}) }

    def warnings
      gtk.instance_variable_get(:@unsupported).keys
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

    it 'reports the widget it evicted from an occupied pane' do
      paned = gtk::Paned.new(:horizontal)
      paned.add1(gtk::Label.new('first'))
      paned.add1(gtk::Label.new('second'))

      expect(warnings.join).to include('occupied first pane')
    end
  end
end
