# frozen_string_literal: true

require 'timeout'
require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'legacy GTK calls that scripts use outside the widget catalog' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:owner) { Struct.new(:name).new('compat-gaps.lic') }
  let(:service) { Lich::WebUI::Service.new }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    allow(Lich).to receive(:log)
  end

  after do
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  it 'reports one main loop level, from any script thread, so the zero-level guard skips Gtk.main' do
    expect(gtk.main_level).to eq(1)
    expect(Thread.new { gtk.main_level }.value).to eq(1)
  end

  describe 'the script view of RubyGems' do
    # A registry known not to hold gtk3 stands in for the real one, so the
    # check never depends on the gems installed on the host.
    let(:registry) { { 'rspec' => Gem.loaded_specs['rspec'] } }

    before { allow(Gem).to receive(:loaded_specs).and_return(registry) }

    it 'shows gtk3 to scripts while presenting and leaves the real registry unchanged' do
      allow(Lich::WebUI).to receive(:presentation_enabled?).and_return(true)
      before_query = registry.dup
      view = eval('Gem.loaded_specs', scope.script_binding)
      expect(view.fetch('gtk3')).to be_a(Gem::Specification)
      expect(view.fetch('gtk3').name).to eq('gtk3')
      expect(view.fetch('rspec')).to equal(registry.fetch('rspec'))
      expect(view).not_to equal(registry)
      expect(registry).to eq(before_query)
      expect(Gem.loaded_specs).not_to have_key('gtk3')
    end

    it 'returns the real registry itself, without gtk3, when presentation is disabled' do
      allow(Lich::WebUI).to receive(:presentation_enabled?).and_return(false)
      view = eval('Gem.loaded_specs', scope.script_binding)
      expect(view).to equal(registry)
      expect(registry.keys).to eq(['rspec'])
    end

    it 'returns the real registry untouched when gtk3 really is loaded' do
      allow(Lich::WebUI).to receive(:presentation_enabled?).and_return(true)
      real = Gem::Specification.new { |spec| spec.name = 'gtk3' }
      registry['gtk3'] = real
      expect(eval('Gem.loaded_specs', scope.script_binding).fetch('gtk3')).to equal(real)
      expect(registry.keys).to eq(%w[rspec gtk3])
    end

    it 'forwards RubyGems calls and keeps constant feature guards truthful' do
      script = scope.script_binding
      expect(eval('Gem::Version.new("1.2")', script)).to eq(Gem::Version.new('1.2'))
      expect(eval('Gem.ruby_version', script)).to eq(Gem.ruby_version)
      expect(eval('Gem::Version', script)).to equal(Gem::Version)
      expect(eval('defined?(Gem::Version)', script)).to eq(defined?(Gem::Version))
      expect(eval('Gem.const_defined?(:Version)', script)).to eq(Gem.const_defined?(:Version))
      expect(eval('Gem.constants.include?(:Specification)', script)).to be(true)
      expect(eval('defined?(Gem::NoSuchCompatConstant)', script)).to be_nil
      expect(eval('Gem.const_defined?(:NoSuchCompatConstant)', script)).to be(false)
      expect { eval('Gem::NoSuchCompatConstant', script) }.to raise_error(NameError, /NoSuchCompatConstant/)
    end
  end

  it 'removes a combo row by position through the GTK2-era remove_text name' do
    combo = gtk::ComboBoxText.new
    %w[alpha beta gamma].each { |text| combo.append_text(text) }
    combo.remove_text(1)
    expect(combo.model.rows.map { |row| row[0] }).to eq(%w[alpha gamma])
    combo.remove_text(-1)
    combo.remove_text(5)
    expect(combo.model.rows.map { |row| row[0] }).to eq(%w[alpha gamma])
  end

  it 'lays out grids wider than 24 columns and clamps a flow maximum to the grid bound' do
    grid = gtk::Grid.new
    grid.attach(gtk::Label.new('Title'), 0, 0, 25, 1)
    expect(grid.send(:read, :cols)).to eq(25)
    flow = gtk::FlowBox.new
    flow.max_children_per_line = 40.0
    expect(flow.max_children_per_line).to eq(40)
    flow.max_children_per_line = 500
    expect(flow.max_children_per_line).to eq(Lich::WebUI::Contract::BOUNDS[:grid_columns])
    flow.max_children_per_line = 0
    expect(flow.max_children_per_line).to eq(Lich::WebUI::Contract::BOUNDS[:grid_columns])
    expect { flow.max_children_per_line = '3' }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'emits clicked, moves focus requests and keeps default-button requests' do
    window = gtk::Window.new
    box = gtk::Box.new(:vertical)
    button = gtk::Button.new(label: 'Save')
    box.add(button)
    window.add(box)
    hits = 0
    button.signal_connect('clicked') { hits += 1 }
    button.clicked
    expect(hits).to eq(1)
    expect { button.grab_focus }.not_to raise_error
    expect(window.instance_variable_get(:@initial_focus)).to equal(button)
    expect { button.set_can_default(true) }.not_to raise_error
    expect { gtk::Label.new('plain').grab_focus }.not_to raise_error
  end

  it 'moves a labelled button caption into a child label that takes markup' do
    button = gtk::Button.new(label: 'one')
    caption = button.child
    expect(caption).to be_a(gtk::Label)
    expect(button.child).to equal(caption)
    caption.set_markup("<span size='20480'>two</span>")
    expect(caption.text).to eq('two')
    expect(gtk::Button.new.child).to be_nil
  end

  it 'keeps a button label and its caption child the same text in both directions' do
    button = gtk::Button.new(label: 'Before')
    caption = button.child
    observed = [button.label]
    caption.text = 'From child'
    observed << button.label
    button.set_label('From button')
    observed << button.label << caption.text
    expect(observed).to eq(['Before', 'From child', 'From button', 'From button'])
    expect(button.send(:read, :label)).to eq('')
    button.label = 'Again'
    expect(caption.text).to eq('Again')
    expect(button.child).to equal(caption)
  end

  it 'shows a button label written after its caption child is removed or destroyed' do
    button = gtk::Button.new(label: 'Before')
    caption = button.child
    button.remove(caption)
    expect(button.label).to eq('')
    button.label = 'After removal'
    expect(caption.text).to eq('Before')
    expect(button.send(:read, :label)).to eq('After removal')
    expect(button.children).to be_empty
    replacement = button.child
    expect(replacement).not_to equal(caption)
    expect(replacement.text).to eq('After removal')
    replacement.destroy
    button.label = 'After destroy'
    expect(button.send(:read, :label)).to eq('After destroy')
    expect(button.label).to eq('After destroy')
  end

  it 'publishes a button label change through the caption child the page renders' do
    window = gtk::Window.new
    button = gtk::Button.new(label: 'Before')
    window.add(button)
    caption = button.child
    window.show_all
    button.label = 'After'
    rendered = caption.send(:session).port.get(caption.materialize, :content)
    expect(rendered).to eq('After')
    expect(button.send(:session).port.get(button.materialize, :label)).to eq('')
  end

  it 'joins a radio member to another group before the page is built' do
    first = gtk::RadioButton.new(label: 'first')
    other = gtk::RadioButton.new(label: 'other')
    other.join_group(first)
    expect(first.group).to eq([first, other])
    expect(first.active?).to be(true)
    expect(other.active?).to be(false)
    other.join_group(nil)
    expect(other.group).to eq([other])
    expect(other.active?).to be(true)
  end

  it 'accepts GTK2 notebook and frame spellings, unset backgrounds and focus hints' do
    notebook = gtk::Notebook.new
    2.times { |index| notebook.append_page(gtk::Label.new("page #{index}"), gtk::Label.new("tab #{index}")) }
    notebook.set_page(1)
    expect(notebook.send(:read, :selected)).to eq(1)
    frame = gtk::Frame.new
    title = gtk::Label.new('Title')
    frame.label_widget = title
    expect(frame.label_widget).to equal(title)
    label = gtk::Label.new('x')
    expect(label.override_background_color(gtk::StateFlags::NORMAL, nil)).to equal(label)
    view = gtk::TextView.new
    expect { view.can_focus = false }.not_to raise_error
    expect { view.can_focus = 'no' }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'leaves an already parented widget where it is when a grid attaches it, as GTK does' do
    first = gtk::Grid.new
    second = gtk::Grid.new
    child = gtk::Label.new('kept')
    first.attach(child, 0, 0, 1, 1)
    expect(second.attach(child, 0, 0, 1, 1)).to equal(second)
    expect(child.parent).to equal(first)
    expect(second.children).to be_empty
    expect(Lich).to have_received(:log).with(/already has a parent/).once
  end

  it 'inserts a notebook page at a position, appending for a negative one' do
    notebook = gtk::Notebook.new
    %w[a c].each { |name| notebook.append_page(gtk::Label.new(name), gtk::Label.new(name.upcase)) }
    expect(notebook.insert_page(gtk::Label.new('b'), gtk::Label.new('B'), 1)).to eq(1)
    expect(notebook.insert_page(gtk::Label.new('d'), gtk::Label.new('D'), -1)).to eq(3)
    expect(notebook.children.map(&:text)).to eq(%w[a b c d])
    expect { notebook.insert_page(gtk::Label.new('e'), gtk::Label.new('E'), '1') }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'clamps colour channels, takes CSS colour names and keeps undelivered signals' do
    gdk = scope.const_get(:Gdk, false)
    expect(gdk::RGBA.new(255, 0, -1, 1.0).to_h).to include(r: 255, g: 0, b: 0)
    label = gtk::Label.new('x')
    label.set_markup("<span foreground='orange'>Enter both item name and container.</span>")
    expect(label.text).to eq('Enter both item name and container.')
    view = gtk::TextView.new
    scroller = gtk::ScrolledWindow.new
    expect(view.signal_connect('button-release-event') { true }).to be_a(Integer)
    expect(scroller.signal_connect('size-allocate') {}).to be_a(Integer)
  end

  it 'runs realize and map handlers on window children when the window shows' do
    window = gtk::Window.new
    view = gtk::TextView.new
    window.add(view)
    events = []
    view.signal_connect('realize') { events << :realize }
    view.signal_connect('map') { events << :map }
    window.show_all
    expect(events).to eq(%i[realize map])
  end

  it 'maps a child excluded from show_all only when it is shown, and sees it visible' do
    window = gtk::Window.new
    box = gtk::Box.new(:vertical)
    window.add(box)
    label = gtk::Label.new('hidden until requested')
    label.no_show_all = true
    box.add(label)
    events = []
    label.signal_connect('realize') { events << [:realize, label.visible?] }
    label.signal_connect('map') { events << [:map, label.visible?] }
    window.show_all
    expect(events).to be_empty
    expect(label.mapped?).to be(false)
    label.show
    expect(events).to eq([[:realize, true], [:map, true]])
    label.show
    expect(events.length).to eq(2)
    expect(label.mapped?).to be(true)
  end

  it 'maps a subtree when its hidden ancestor is shown, and again after a hide' do
    window = gtk::Window.new
    outer = gtk::Box.new(:vertical)
    inner = gtk::Label.new('inside')
    outer.add(inner)
    window.add(outer)
    outer.no_show_all = true
    events = []
    inner.signal_connect('realize') { events << :realize }
    inner.signal_connect('map') { events << :map }
    window.show_all
    inner.show
    expect(events).to be_empty
    outer.show
    expect(events).to eq(%i[realize map])
    outer.hide
    expect(inner.mapped?).to be(false)
    outer.show
    expect(events).to eq(%i[realize map map])
  end

  it 'maps a child attached to a window that is already shown, and unmaps it on removal' do
    window = gtk::Window.new
    box = gtk::Box.new(:vertical)
    window.add(box)
    window.show_all
    late = gtk::Label.new('late')
    events = []
    late.signal_connect('map') { events << :map }
    late.show
    expect(events).to be_empty
    box.add(late)
    expect(events).to eq([:map])
    box.remove(late)
    expect(late.mapped?).to be(false)
    box.add(late)
    expect(events).to eq(%i[map map])
  end

  it 'maps window children again on each window show, in realize, show, map order' do
    window = gtk::Window.new
    view = gtk::TextView.new
    window.add(view)
    events = []
    window.signal_connect('realize') { events << :window_realize }
    window.signal_connect('show') { events << :window_show }
    window.signal_connect('map') { events << :window_map }
    view.signal_connect('realize') { events << :realize }
    view.signal_connect('map') { events << :map }
    window.show_all
    expect(events).to eq(%i[window_realize realize window_show window_map map])
    window.show
    expect(events.length).to eq(5)
    window.hide
    expect(view.mapped?).to be(false)
    window.show
    expect(events.drop(5)).to eq(%i[window_show window_map map])
  end

  it 'blocks a main loop until quit, and refuses a nested run' do
    loop = scope.const_get(:GLib, false)::MainLoop.new
    quitter = Thread.new do
      sleep 0.05 until loop.running?
      loop.quit
    end
    expect(loop.run).to be_nil
    quitter.join
    expect(loop.running?).to be(false)
  end

  it 'refuses a main loop quit from another script and keeps the waiter running' do
    loop = scope.const_get(:GLib, false)::MainLoop.new
    waiter = Thread.new { loop.run }
    Timeout.timeout(2) { sleep 0.01 until loop.running? }
    other = Struct.new(:name).new('other-script.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(other)
    expect { loop.quit }.to raise_error(gtk::UnsupportedOperation)
    expect(waiter.join(0.4)).to be_nil
    expect(loop.running?).to be(true)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    expect(loop.quit).to be_nil
    expect(waiter.join(2)).to equal(waiter)
  ensure
    waiter&.kill
    waiter&.join
  end

  it 'lets the owner quit an idle main loop, and a loop whose session has closed' do
    loop = scope.const_get(:GLib, false)::MainLoop.new
    expect(loop.quit).to be_nil
    expect(loop.running?).to be(false)
    Lich::Common::ScriptDeath.run(owner)
    expect(loop.quit).to be_nil
  end

  it 'drops clipboard copies and reports an empty clipboard' do
    gdk = scope.const_get(:Gdk, false)
    clipboard = gtk::Clipboard.get(gdk::Selection::CLIPBOARD)
    expect(clipboard.set_text('copied')).to equal(clipboard)
    expect(clipboard.wait_for_text).to be_nil
  end

  it 'resolves require pango to the compatibility layer while it presents' do
    allow(Lich::WebUI).to receive(:presentation_enabled?).and_return(true)
    boundary = scope::Gtk::RequireBoundary
    expect(boundary.handled?('pango', :require, caller_locations.first)).to be(true)
  end

  it 'lets a reopened script reuse a size group cached by its previous run' do
    group = gtk::SizeGroup.new(:horizontal)
    group.add_widget(gtk::Label.new('First run'))
    Lich::Common::ScriptDeath.run(owner)
    reopened = Struct.new(:name).new('compat-gaps.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(reopened)
    label = gtk::Label.new('Second run')
    expect(group.add_widget(label)).to equal(group)
    expect(group.widgets).to eq([label])
    stranger = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(stranger)
    expect { group.add_widget(gtk::Label.new('Foreign')) }.to raise_error(gtk::UnsupportedOperation)
  ensure
    allow(Lich::Common::Script).to receive(:current).and_return(reopened) if reopened
    Lich::Common::ScriptDeath.run(reopened) if reopened
    Lich::Common::ScriptDeath.run(stranger) if defined?(stranger) && stranger
  end
end
