# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require 'weakref'

RSpec.describe 'bounded rich list compatibility' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('merchantical-list.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:gtk) { scope.const_get(:Gtk, false) }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    allow(Lich).to receive(:log)
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  def collect_lists
    3.times { GC.start(full_mark: true, immediate_sweep: true) }
  end

  def detached_generation(parent, provider)
    list, row = gtk::ListBox.new, gtk::ListBoxRow.new
    label, button = gtk::Label.new('Item'), gtk::Button.new('Action')
    [list, row].each { |widget| widget.style_context.add_class('fixture') }
    label.style_context.add_class('fixture')
    label.style_context.add_provider(provider)
    button.signal_connect('clicked') { label.text = 'Clicked' }
    content = gtk::Box.new(:vertical).add(label).add(button)
    parent.add(list.add(row.add(content)))
    parent.materialize
    parent.remove(list)
    WeakRef.new(list)
  end

  it 'collects abandoned rich generations without a provider or index retaining their graphs' do
    parent, provider = gtk::Box.new(:vertical), gtk::CssProvider.new
    references = 40.times.map { detached_generation(parent, provider) }
    collect_lists
    expect(references.none?(&:weakref_alive?)).to be(true)
    parent.session.port.send(:prune_bindings!)
    expect(parent.session.instance_variable_get(:@style_contexts)).to be_empty
    expect(provider.instance_variable_get(:@contexts)).to be_empty
    expect(parent.session.port.instance_variable_get(:@nodes).size).to eq(1)
    expect(parent.session.port.instance_variable_get(:@bindings)).to be_empty
  end

  %i[list child context].each do |retained|
    it "preserves a detached list retained through its #{retained}, including provider reload and handle identity" do
      first, second = gtk::Box.new(:vertical), gtk::Box.new(:vertical)
      provider = gtk::CssProvider.new
      keep, reference, handle = retained_generation(first, provider, retained)
      collect_lists
      list = reference.__getobj__
      label = list.children.first.children.first
      provider.load_from_data('label.fixture { color: gold; }')
      second.add(list)
      second.materialize
      expect(list.materialize).to equal(handle.__getobj__)
      expect(label.send(:component_props)[:foreground]).to include(r: 255, g: 215, b: 0)
      expect(keep).not_to be_nil
      second.destroy
      expect(provider.instance_variable_get(:@contexts)).to be_empty
    end
  end

  def retained_generation(parent, provider, retained)
    list, row, label = gtk::ListBox.new, gtk::ListBoxRow.new, gtk::Label.new('Retained')
    label.style_context.add_class('fixture')
    label.style_context.add_provider(provider)
    parent.add(list.add(row.add(label)))
    parent.materialize
    handle = WeakRef.new(list.materialize)
    parent.remove(list)
    keep = { list: list, child: label, context: label.style_context }.fetch(retained)
    [keep, WeakRef.new(list), handle]
  end

  it 'maps ordered button crossing signals without adding activation side effects' do
    button = gtk::Button.new('Action')
    observed = []
    button.signal_connect('enter-notify-event') { |_widget, event| observed << event.event_type }
    button.signal_connect('leave-notify-event') { |_widget, event| observed << event.event_type }
    button.signal_connect('clicked') { observed << :clicked }
    button.materialize
    node = button.session.port.instance_variable_get(:@nodes).fetch(button.materialize)
    %i[pointer_enter pointer_leave].each do |event|
      callback = node.callbacks.fetch(node.bindings.fetch(event)).last
      callback.call(Lich::WebUI::Runtime::EventContext.new(nil, nil, nil, event, {}, nil))
    end
    expect(observed).to eq(%i[enter_notify leave_notify])
  end

  it 'owns explicit nonselecting rows with one rich content child and stable order' do
    list = gtk::ListBox.new
    list.selection_mode = :none
    rows = 2.times.map do |index|
      row = gtk::ListBoxRow.new
      row.activatable = row.selectable = false
      content = gtk::Box.new(:horizontal)
      content.add(gtk::Button.new("Item #{index}"))
      content.add(gtk::Entry.new)
      row.add(content)
      list.add(row)
      row
    end
    list.materialize
    expect(list.children).to eq(rows)
    expect(rows.first.children.first.children.size).to eq(2)
    expect { list.selection_mode = :single }.to raise_error(gtk::UnsupportedOperation)
    expect { list.add(gtk::Label.new('Unwrapped')) }.to raise_error(gtk::UnsupportedOperation)
    expect { rows.first.add(gtk::Label.new('Second child')) }.to raise_error(gtk::UnsupportedOperation)
    expect { rows.first.activatable = true }.to raise_error(gtk::UnsupportedOperation)
    expect { rows.first.selectable = true }.to raise_error(gtk::UnsupportedOperation)
    list.remove(rows.first)
    other = gtk::ListBox.new.add(rows.first)
    expect(rows.first.parent).to equal(other)
    expect(list.children).to eq([rows.last])
    other.destroy
    expect(rows.first.children.first.children.all?(&:destroyed?)).to be(true)
  end

  it 'keeps live opacity separate from visibility and sensitivity and rejects malformed alpha' do
    [gtk::ListBoxRow.new, gtk::Button.new('Action'), gtk::Label.new('Item')].each do |widget|
      expect(widget.opacity).to eq(1.0)
      widget.materialize
      [0, 0.35, 0.45, 1].each do |alpha|
        widget.opacity = alpha
        expect(widget.opacity).to eq(alpha)
        expect(widget.sensitive?).to be(true)
      end
      [-0.1, 1.1, Float::NAN, Float::INFINITY, '0.5', nil].each do |alpha|
        expect { widget.opacity = alpha }.to raise_error(gtk::UnsupportedOperation)
        expect(widget.opacity).to eq(1)
      end
    end
  end

  it 'translates combined recall font-family markup and whole-label background cues' do
    label = gtk::Label.new
    label.set_markup("<span foreground='#aaaaaa' font_family='monospace' size='small'>Recall &amp; details</span>")
    expect(label.text).to eq('Recall & details')
    expect(label.send(:component_props)[:fragments].first).to include(font_family: 'monospace')
    label.set_markup("<span foreground='#666' size='small'>Type</span>")
    expect(label.send(:component_props)[:fragments].first[:foreground]).to include(r: 102, g: 102, b: 102)
    label.set_markup("<span background='#3c9c3c'> Found </span>")
    expect(label.send(:component_props)[:background]).to include(r: 60, g: 156, b: 60)
    expect(label.text).to eq(' Found ')
    label.materialize
    label.set_markup('Plain')
    expect(label.send(:component_props)).not_to have_key(:background)
    ["<span font_family='url(bad)' size='small'>Bad</span>", "<span background='url(bad)'>Bad</span>",
     "<span background='#3c9c3c' onclick='bad'>Bad</span>"].each do |markup|
      expect { label.set_markup(markup) }.to raise_error(gtk::UnsupportedOperation)
      expect(label.text).to eq('Plain')
    end
  end

  [false, true].each do |live|
    it "clears prior italic markup when applying a whole-label background with live=#{live}" do
      label = gtk::Label.new
      label.set_markup('<i>Item</i>')
      handle = label.materialize if live
      label.set_markup("<span background='#3c9c3c'>Found &amp; kept</span>")
      props = label.send(:component_props)
      expect(props).to include(content: 'Found & kept', font_style: :normal)
      expect(props[:background]).to include(r: 60, g: 156, b: 60)
      handle ||= label.materialize
      expect(label.session.port.get(handle, :font_style)).to eq('normal')
      expect(label.session.port.get(handle, :content)).to eq('Found & kept')
      expect(label.session.port.get(handle, :background)).to include(r: 60, g: 156, b: 60)
    end
  end

  it 'cleans current list style contexts on destruction while detached lists remain reusable' do
    parent = gtk::Box.new(:vertical)
    list = gtk::ListBox.new
    row = gtk::ListBoxRow.new.add(gtk::Button.new('Action'))
    [list, row].each { |widget| widget.style_context.add_class('fixture') }
    parent.add(list.add(row))
    parent.materialize
    parent.remove(list)
    expect(list.destroyed?).to be(false)
    expect(list.session.instance_variable_get(:@style_contexts).size).to eq(2)
    parent.add(list)
    parent.destroy
    expect(list.session.instance_variable_get(:@style_contexts)).to be_empty
  end
end
