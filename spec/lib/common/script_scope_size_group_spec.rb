# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'horizontal size groups and fixed spin ranges' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:owner) { Struct.new(:name).new('size-groups.lic') }
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

  it 'publishes shared width membership across rows and removes only the requested group live' do
    group = gtk::SizeGroup.new(:horizontal)
    other = gtk::SizeGroup.new(gtk::SizeGroupMode::HORIZONTAL)
    first, last = [gtk::CheckButton.new('First'), gtk::Entry.new]
    last.width_request = 90
    group.add_widget(first).add_widget(last).add_widget(first)
    other.add_widget(last)
    snapshot = group.widgets
    snapshot.clear
    expect(group.get_widgets).to eq([first, last])
    window = gtk::Window.new
    column = gtk::VBox.new
    [first, last].each do |widget|
      row = gtk::HBox.new
      row.pack_start(widget, false, false, 0)
      column.add(row)
    end
    window.add(column)
    window.show_all
    port = window.session.port
    handle = last.materialize
    expect(port.get(first.materialize, :width_groups)).to eq([group.key])
    expect(port.get(handle, :width_groups)).to eq([group.key, other.key])
    group.remove_widget(last)
    expect(port.get(handle, :width_groups)).to eq([other.key])
    expect(last.materialize).to equal(handle)
    expect(port.get(handle, :width)).to eq(90)
    last.destroy
    expect(other.widgets).to be_empty
  end

  it 'refuses foreign, dead, cross-window and unsupported group use' do
    group = gtk::SizeGroup.new(:horizontal)
    first, second = [gtk::Button.new('First'), gtk::Button.new('Second')]
    one, two = [gtk::Window.new, gtk::Window.new]
    one.add(first)
    two.add(second)
    group.add_widget(first)
    expect { group.add_widget(second) }.to raise_error(gtk::UnsupportedOperation)
    expect { group.add_widget(one) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::SizeGroup.new(:vertical) }.to raise_error(gtk::UnsupportedOperation)
    second.destroy
    expect { group.add_widget(second) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(Struct.new(:name).new('other.lic'))
    expect { group.add_widget(gtk::Button.new('Foreign')) }.to raise_error(gtk::UnsupportedOperation)
    expect { group.widgets }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    Lich::Common::ScriptDeath.run(owner)
    expect { group.widgets }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'refuses groups split into separate windows after their members were registered' do
    group = gtk::SizeGroup.new(:horizontal)
    first, second = [gtk::Label.new('First'), gtk::Label.new('Second')]
    group.add_widget(first).add_widget(second)
    one, two = [gtk::Window.new, gtk::Window.new]
    one.add(first)
    two.add(second)
    expect { one.show_all }.to raise_error(gtk::UnsupportedOperation)
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'bounds overlapping memberships without corrupting an existing widget' do
    widget = gtk::Label.new('Bounded')
    groups = 9.times.map { gtk::SizeGroup.new(:horizontal) }
    groups.first(8).each { |group| group.add_widget(widget) }
    expect { groups.last.add_widget(widget) }.to raise_error(gtk::UnsupportedOperation)
    expect(widget.send(:component_props)[:width_groups]).to eq(groups.first(8).map(&:key))
    expect(groups.last.widgets).to be_empty
  end

  it 'publishes the original zero-width adjustment and clamps writes without false change signals' do
    adjustment = gtk::Adjustment.new(0, 0, 0, 1, 5, 0)
    spin = gtk::SpinButton.new(adjustment, 1, 0)
    changes = []
    spin.signal_connect('value_changed') { changes << spin.value }
    spin.value = 100
    spin.value = -100
    expect([spin.value, adjustment.value, spin.text]).to eq([0, 0, '0'])
    expect(changes).to be_empty
    window = gtk::Window.new
    window.add(spin)
    window.show_all
    port = window.session.port
    expect(%i[min max].map { |property| port.get(spin.materialize, property) } + [spin.value]).to eq([0, 0, 0])
    expect { gtk::SpinButton.new(1, 0, 1) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::SpinButton.new(gtk::Adjustment.new(0, 0, 0, 0, 5, 0)) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'expands and collapses adjustment bounds before publication with ordered coherent notifications' do
    adjustment = gtk::Adjustment.new(0, 0, 0, 1, 5, 0)
    spin = gtk::SpinButton.new(adjustment)
    handle = spin.materialize
    events = []
    adjustment.signal_connect('changed') { |source| events << [:bounds, source.lower, source.upper, source.value] }
    adjustment.signal_connect('value_changed') { |source| events << [:value, source.value] }
    adjustment.upper = 10
    spin.value = 7
    adjustment.upper = 0
    expect(spin.value).to eq(0)
    expect(events).to eq([[:bounds, 0, 10, 0], [:value, 7], [:bounds, 0, 0, 0], [:value, 0]])
    expect(spin.session.port.get(handle, :max)).to eq(0)
    adjustment.lower = -500
    expect(spin.session.port.get(handle, :min)).to eq(-500)
    expect { adjustment.lower = 1 }.to raise_error(gtk::UnsupportedOperation)
    expect { adjustment.upper = Float::INFINITY }.to raise_error(gtk::UnsupportedOperation)
    expect([adjustment.lower, adjustment.upper, spin.value]).to eq([-500, 0, 0])
  end
end
