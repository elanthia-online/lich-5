# frozen_string_literal: true

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

  it 'shows gtk3 as a loaded gem to scripts only while the compatibility layer presents' do
    allow(Lich::WebUI).to receive(:presentation_enabled?).and_return(true)
    spec = scope::Gem.loaded_specs['gtk3']
    expect(spec).to be_a(Gem::Specification)
    expect(spec.name).to eq('gtk3')
    expect(Gem.loaded_specs).not_to have_key('gtk3') unless Gem.loaded_specs.key?('gtk3')
    expect(scope::Gem::Version.new('1.2')).to eq(Gem::Version.new('1.2'))
    expect(scope::Gem.ruby_version).to eq(Gem.ruby_version)
    allow(Lich::WebUI).to receive(:presentation_enabled?).and_return(false)
    expect(scope::Gem.loaded_specs['gtk3']).to eq(Gem.loaded_specs['gtk3'])
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
