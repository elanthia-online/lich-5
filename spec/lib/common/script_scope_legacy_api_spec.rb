# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'legacy GTK spellings and entry initialization' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:gdk) { scope.const_get(:Gdk, false) }
  let(:owner) { Struct.new(:name).new('legacy-api.lic') }
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
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  it 'uses existing measured geometry and its nominal fallback without creating a window' do
    allow(service).to receive(:monitor_geometry).and_return(x: -1280, y: 0, width: 1280, height: 800, source: 'native', fallback: false)
    expect([gdk.screen_width, gdk.screen_height]).to eq([1280, 800])
    allow(service).to receive(:monitor_geometry).and_return(source: 'unavailable', fallback: true)
    expect([gdk.screen_width, gdk.screen_height]).to eq([1024, 768])
    expect(service.registry.pages_for(owner)).to be_empty
    allow(Lich::Common::Script).to receive(:current).and_return(nil)
    expect { gdk.screen_width }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'projects legacy bold, etched-frame and center constants through existing properties' do
    font = scope::Pango::FontDescription.new
    font.weight = scope::Pango::FontDescription::WEIGHT_BOLD
    label = gtk::Label.new('Bold')
    label.modify_font(font)
    expect(label.send(:component_props)[:emphasis]).to eq(:strong)
    entry = gtk::Entry.new
    entry.modify_font(font)
    expect(entry.send(:component_props)[:emphasis]).to eq(:strong)
    expect(gtk::SELECTION_SINGLE).to eq(gtk::SelectionMode::SINGLE)
    frame = gtk::Frame.new.set_shadow_type(gtk::SHADOW_ETCHED_IN)
    expect(frame.materialize).not_to be_nil
    window = gtk::Window.new
    expect(window.set_window_position(gtk::Window::POS_CENTER)).to equal(window)
  end

  it 'packs default children in order and normalizes only supported capitalized orientations' do
    box = gtk::Box.new(:Vertical, 1)
    first, last = gtk::Label.new('First'), gtk::Label.new('Last')
    box.pack_end(last)
    expect(box.pack_start_defaults(first)).to equal(box)
    expect(box.children).to eq([first, last])
    expect(box.send(:component_type)).to eq(:stack)
    expect(box.send(:component_props)[:gap]).to eq(1)
    expect(gtk::Box.new(:Horizontal, 0).send(:component_type)).to eq(:grid)
    expect { gtk::Box.new(:diagonal) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::VBox.new.pack_start_defaults(first) }.to raise_error(gtk::UnsupportedOperation)
    expect(first.parent).to equal(box)
  end

  it 'keeps a legacy text combo on one model and one stable editable entry' do
    combo = gtk::ComboBoxEntry.new
    entry = combo.child
    expect(entry.class).to eq(gtk::Entry)
    combo.append_text('sack').append_text('sack')
    observed = []
    combo.signal_connect('changed') { observed << [:combo, combo.active] }
    entry.signal_connect('changed') { |widget| observed << [:entry, widget.text] }
    combo.active = 1
    expect(combo.active).to eq(1)
    expect(entry.text).to eq('sack')
    entry.text = 'custom sack'
    expect(combo.active).to eq(-1)
    expect(observed).to eq([[:combo, 1], [:entry, 'sack'], [:combo, -1], [:entry, 'custom sack']])
    expect(combo.child).to equal(entry)
    expect(combo.materialize).not_to be_nil
    expect { gtk::VBox.new.add(entry) }.to raise_error(gtk::UnsupportedOperation)
  end

  [false, true].each do |internal|
    it "emits changed synchronously without changing text for an #{internal ? 'internal' : 'ordinary'} entry" do
      entry = internal ? gtk::ComboBoxText.new(entry: true).child : gtk::Entry.new
      entry.text = 'sack'
      observed = []
      entry.signal_connect('changed') { |widget| observed << [widget, widget.text] }
      expect(entry.signal_emit('changed')).to be_nil
      expect(entry.signal_emit(:changed)).to be_nil
      expect(observed).to eq([[entry, 'sack'], [entry, 'sack']])
      expect(entry.text).to eq('sack')
      expect { entry.signal_emit('activate') }.to raise_error(gtk::UnsupportedOperation)
      expect { entry.signal_emit('changed', 'payload') }.to raise_error(ArgumentError)
      expect(observed.length).to eq(2)
    end
  end

  it 'preserves callback exceptions and refuses explicit emission after destruction or across owners' do
    entry = gtk::ComboBoxText.new(entry: true).child
    entry.signal_connect('changed') { raise 'source callback failure' }
    expect { entry.signal_emit('changed') }.to raise_error(RuntimeError, 'source callback failure')
    allow(Lich::Common::Script).to receive(:current).and_return(Object.new)
    expect { entry.signal_emit('changed') }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    entry.parent.destroy
    expect { entry.signal_emit('changed') }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'shares legacy colors with the bounded themed-background disposition' do
    entry = gtk::Entry.new
    color = gdk::Color.parse('#ffff00000000')
    expect(color).to be_frozen
    expect(color.to_rgba.to_h).to eq(r: 255, g: 0, b: 0, a: 1.0)
    expect(entry.modify_base(gtk::STATE_NORMAL, color)).to equal(entry)
    expect(entry.send(:component_props)).not_to have_key(:background)
    [nil, 'url(file:///tmp/color)', 'red;display:none', 'x'.dup.force_encoding(Encoding::UTF_16LE)].each do |invalid|
      expect { gdk::Color.parse(invalid) }.to raise_error(gtk::UnsupportedOperation)
    end
    expect { entry.modify_base(:selected, color) }.to raise_error(gtk::UnsupportedOperation)
    expect { entry.modify_base(:normal, color.to_rgba) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(Object.new)
    expect { entry.modify_base(:normal, color) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    entry.destroy
    expect { entry.modify_base(:normal, color) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'retains explicit-change disconnection and nested emission order' do
    entry = gtk::Entry.new
    seen = []
    nested = false
    later = nil
    entry.signal_connect('changed') do
      seen << :first
      unless nested
        nested = true
        entry.send(:disconnect_signal_handler, later)
        entry.signal_emit('changed')
      end
    end
    later = entry.signal_connect('changed') { seen << :disconnected }
    entry.signal_connect('changed') { seen << :last }
    entry.signal_emit('changed')
    expect(seen).to eq(%i[first first last last])
  end

  it 'runs after-switch handlers after normal handlers and supports disconnection' do
    notebook = gtk::Notebook.new
    pages = [gtk::VBox.new, gtk::VBox.new]
    pages.each_with_index { |page, i| notebook.append_page(page, gtk::Label.new(i.to_s)) }
    seen = []
    after = notebook.signal_connect_after('switch-page') { |widget, page, index| seen << [:after, widget, page, index] }
    notebook.signal_connect('switch-page') { |widget, page, index| seen << [:normal, widget, page, index] }
    notebook.set_current_page(1)
    expect(seen).to eq([[:normal, notebook, pages[1], 1], [:after, notebook, pages[1], 1]])
    notebook.send(:disconnect_signal_handler, after)
    seen.clear
    notebook.set_current_page(0)
    expect(seen).to eq([[:normal, notebook, pages[0], 0]])
    expect { notebook.signal_connect_after('show') {} }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'preserves a close veto before after-handlers and orders permitted close notifications' do
    window = gtk::Window.new
    seen = []
    window.signal_connect_after('delete-event') { seen << :after; false }
    veto = window.signal_connect('delete-event') { seen << :veto; true }
    expect(window.send(:emit_handlers, :close)).to be(true)
    expect(seen).to eq([:veto])
    window.signal_handler_disconnect(veto)
    window.signal_connect('delete-event') { seen << :normal; false }
    seen.clear
    expect(window.send(:emit_handlers, :close)).to be(false)
    expect(seen).to eq(%i[normal after])
  end

  it 'uses existing table placements for legacy default attachment and flags' do
    table = gtk::Table.new(1, 2)
    label = gtk::Label.new('default')
    expect(table.attach_defaults(label, 0, 1, 0, 1)).to equal(table)
    table.attach(gtk::Entry.new, 1, 2, 0, 1, gtk::EXPAND | gtk::FILL, gtk::FILL, 3, 3)
    expect(table.materialize).not_to be_nil
    expect(label.instance_variable_get(:@placement)).to eq(column: 1, row: 1, span: 1, row_span: 1)
    expect { gtk::FlowBox.new.attach_defaults(gtk::Label.new, 0, 1, 0, 1) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::Grid.new.attach_defaults(gtk::Label.new, 0, 1, 0, 1) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'changes live entry editability without replacing the handle or text' do
    entry = gtk::Entry.new
    entry.text = 'retained'
    handle = entry.materialize
    entry.editable = false
    expect(entry.materialize).to equal(handle)
    expect(entry.send(:component_props)[:read_only]).to be(true)
    expect(entry.text).to eq('retained')
    entry.editable = true
    expect(entry.send(:component_props)[:read_only]).to be(false)
    expect { entry.editable = nil }.to raise_error(gtk::UnsupportedOperation)
    entry.destroy
    expect { entry.editable = true }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'refuses unimplemented legacy combo models without accepting arbitrary constructor truthiness' do
    [nil, true].each { |argument| expect(gtk::ComboBoxEntry.new(argument).child).to be_a(gtk::Entry) }
    [false, 1, {}, Object.new].each do |argument|
      expect { gtk::ComboBoxEntry.new(argument) }.to raise_error(gtk::UnsupportedOperation)
    end
  end

  it 'normalizes only the legacy text-only combo argument without making it editable' do
    combo = gtk::ComboBoxText.new(true)
    combo.append_text('kind').append_text('grateful')
    combo.active = 1
    expect(combo.active_text).to eq('grateful')
    expect(combo.has_entry?).to be(false)
    expect(combo.materialize).not_to be_nil
    expect(Lich).to have_received(:log).with(/legacy text-only argument normalized/)
    [false, nil, 1, {}, Object.new].each do |value|
      expect { gtk::ComboBoxText.new(value) }.to raise_error(gtk::UnsupportedOperation)
    end
    expect { gtk::ComboBoxText.new(true, entry: true) }.to raise_error(gtk::UnsupportedOperation)
    expect { gtk::ComboBoxText.new(true, true) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'ignores redundant descendant packing without changing the owned graph or layout' do
    box = gtk::HBox.new
    frame = gtk::Frame.new
    inner = gtk::VBox.new
    entry = gtk::Entry.new
    inner.add(entry)
    frame.add(inner)
    box.add(frame)
    handle = box.materialize
    original_props = inner.send(:component_props).dup
    expect(box.pack_start(inner, false, true, 20)).to equal(box)
    expect(box.pack_end(inner, true, true, 10)).to equal(box)
    expect(box.children).to eq([frame])
    expect(frame.children).to eq([inner])
    expect(inner.parent).to equal(frame)
    expect(inner.send(:component_props)).to eq(original_props)
    expect(box.materialize).to equal(handle)
    expect(Lich).to have_received(:log).with(/redundant packing ignored/).twice
    expect { gtk::VBox.new.pack_start(inner) }.to raise_error(gtk::UnsupportedOperation)
    expect { inner.pack_start(box) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(Object.new)
    expect { box.pack_start(inner) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    frame.destroy
    expect { box.pack_start(inner) }.to raise_error(gtk::UnsupportedOperation)
  end
end
