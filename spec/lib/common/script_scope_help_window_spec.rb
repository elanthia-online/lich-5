# frozen_string_literal: true

require_relative '../../spec_helper'
require 'timeout'
require 'weakref'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'bounded help-window presentation' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('merchantical-help.lic') }
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

  it 'retains a validated weak parent without containment, modality or child destruction' do
    main, help = gtk::Window.new('Main'), gtk::Window.new('Help')
    expect(help.set_transient_for(main)).to equal(help)
    expect(help.get_transient_for).to equal(main)
    expect(help.parent).to be_nil
    expect(help.modal?).to be(false)
    expect { main.transient_for = help }.to raise_error(gtk::UnsupportedOperation)
    help.set_window_position(gtk::WindowPosition::CENTER_ON_PARENT)
    expect(help.get_window_position).to eq(:center_on_parent)
    help.keep_above = true
    help.materialize
    expect(help.send(:component_props)[:presentation]).to eq(always_on_top: true)
    main.destroy
    expect(help.transient_for).to be_nil
    expect(help.destroyed?).to be(false)
    expect { help.set_window_position(:center_on_parent) }.to raise_error(gtk::UnsupportedOperation)
    expect(help.window_position).to eq(:center_on_parent)
    help.transient_for = nil
    help.set_window_position(:center)
    expect(help.get_window_position).to eq(:center)
    expect(Lich).to have_received(:log).with(/logical parent retained; native parent-child stacking is host-controlled/).once
    expect(Lich).to have_received(:log).with(/parent-relative centering is host-controlled/).once
  end

  it 'refuses invalid parent and placement requests without replacing the live association' do
    main, help = gtk::Window.new, gtk::Window.new
    dead = gtk::Window.new
    dead.destroy
    help.transient_for = main
    help.set_window_position(:center)
    [help, dead, gtk::Label.new('No'), Object.new].each do |parent|
      expect { help.transient_for = parent }.to raise_error(gtk::UnsupportedOperation)
      expect(help.transient_for).to equal(main)
    end
    expect { help.set_window_position(:mouse) }.to raise_error(gtk::UnsupportedOperation)
    expect(help.window_position).to eq(:center)
    allow(Lich::Common::Script).to receive(:current).and_return(Object.new)
    expect { help.transient_for = nil }.to raise_error(gtk::UnsupportedOperation)
    expect { help.transient_for }.to raise_error(gtk::UnsupportedOperation)
  end

  def retired_parent(help)
    parent = gtk::Window.new
    help.transient_for = parent
    parent.destroy
    WeakRef.new(parent)
  end

  it 'does not retain retired parent windows through weak associations' do
    help = gtk::Window.new
    reference = retired_parent(help)
    3.times { GC.start(full_mark: true, immediate_sweep: true) }
    expect(reference.weakref_alive?).not_to be(true)
    expect(help.transient_for).to be_nil
  end

  [true, false].each do |editable|
    it "bounds inner text insets separately from outer margins with editable=#{editable}" do
      view = gtk::TextView.new
      view.editable = editable
      view.set_margin_left(12)
      view.left_margin = 4
      view.set_right_margin(7)
      view.materialize
      expect(view.get_left_margin).to eq(4)
      expect(view.right_margin).to eq(7)
      expect(view.send(:component_props)).to include(padding_left: 4, padding_right: 7, margin: { left: 12 })
      [-1, 65, 0.5, '4', nil].each do |value|
        expect { view.left_margin = value }.to raise_error(gtk::UnsupportedOperation)
        expect(view.left_margin).to eq(4)
      end
      allow(view.session.port).to receive(:set).and_raise(Lich::WebUI::Error, 'refused')
      expect { view.left_margin = 8 }.to raise_error(Lich::WebUI::Error, /refused/)
      expect(view.left_margin).to eq(4)
    end
  end

  it 'keeps static read-only documents stationary until explicit end-follow intent' do
    view = gtk::TextView.new
    view.editable = false
    view.cursor_visible = false
    view.wrap_mode = :word
    view.buffer.text = "Help\n" * 100
    expect(view.send(:component_props)[:follow]).to be(false)
    view.buffer.text = 'Replacement'
    view.editable = false
    expect(view.send(:component_props)[:follow]).to be(false)
    mark = view.buffer.create_mark(nil, view.buffer.end_iter, false)
    view.scroll_mark_onscreen(mark)
    view.buffer.delete_mark(mark)
    expect(view.send(:component_props)[:follow]).to be(true)
    view.buffer.insert(view.buffer.end_iter, '\nAppended')
    expect(view.send(:component_props)[:follow]).to be(true)
  end

  it 'limits new wire insets to log and textarea with bounded numeric values' do
    validator = Lich::WebUI::Validator.new
    context = { owner: 'help', page_id: 'help', cid: 'text' }
    { log: { lines: ['Help'], max_lines: 1000 }, textarea: { value: 'Help' } }.each do |type, props|
      expect(validator.validate_component!(type, props.merge(padding_left: 4, padding_right: 0), **context)).to include(padding_left: 4)
      [-1, 65, '4', Float::NAN].each do |value|
        expect { validator.validate_component!(type, props.merge(padding_left: value), **context) }.to raise_error(Lich::WebUI::SchemaViolationError)
      end
    end
    expect { validator.validate_component!(:text, { content: 'No', padding_left: 4 }, **context) }.to raise_error(Lich::WebUI::UnknownPropertyError)
  end
end
