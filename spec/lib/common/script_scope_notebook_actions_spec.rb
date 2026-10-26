# frozen_string_literal: true

require_relative '../../spec_helper'
require 'timeout'
require 'weakref'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'Notebook auxiliary action ownership' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('merchantical-notebook.lic') }
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

  def populated
    notebook = gtk::Notebook.new
    %w[Stock Sale Queue Ledger].each { |name| notebook.append_page(gtk::Label.new(name), gtk::Label.new(name)) }
    notebook
  end

  it 'keeps action replacement, clearing and page rebuilding outside indexed pages' do
    notebook = populated
    pages = notebook.children
    help = gtk::Button.new.add(gtk::Label.new('Help'))
    notebook.set_action_widget(help, :end)
    notebook.materialize
    handle = help.materialize
    notebook.set_current_page(2)
    other = gtk::Button.new('Other')
    notebook.set_action_widget(other, :start)
    notebook.remove(help)
    expect(help.destroyed?).to be(false)
    expect(help.parent).to be_nil
    notebook.set_action_widget(help, :end)
    expect(help.materialize).to equal(handle)
    expect(notebook.n_pages).to eq(4)
    expect(notebook.get_nth_page(-1)).to equal(pages.last)
    expect(notebook.children).to eq(pages)
    expect(notebook.send(:read, :selected)).to eq(2)
    notebook.remove_page(0)
    expect(notebook.get_action_widget(:end)).to equal(help)
    notebook.set_action_widget(nil, :end)
    box = gtk::Box.new(:vertical).add(help)
    box.materialize
    expect(help.materialize).to equal(handle)
    notebook.destroy
    expect(other.destroyed?).to be(true)
    expect(help.destroyed?).to be(false)
    box.destroy
  end

  it 'does not commit shadow ownership on invalid or refused replacement' do
    notebook, old, candidate = populated, gtk::Button.new('Old'), gtk::Button.new('New')
    notebook.set_action_widget(old, :end)
    notebook.materialize
    allow(notebook.session.port).to receive(:layout_tab_actions).and_raise(Lich::WebUI::Error, 'refused')
    expect { notebook.set_action_widget(candidate, :end) }.to raise_error(Lich::WebUI::Error, /refused/)
    expect(notebook.get_action_widget(:end)).to equal(old)
    expect(old.parent).to equal(notebook)
    expect(candidate.parent).to be_nil
    expect(notebook.n_pages).to eq(4)
    expect { notebook.set_action_widget(old, :end) }.not_to raise_error
    expect { notebook.set_action_widget(old, :start) }.to raise_error(gtk::UnsupportedOperation)
    [[:wrong, candidate], [:start, notebook], [:start, gtk::Window.new], [:start, notebook.children.first]].each do |side, widget|
      expect { notebook.set_action_widget(widget, side) }.to raise_error(gtk::UnsupportedOperation)
    end
  end

  it 'refuses action access from another owner without modifying the original collection' do
    notebook, help = populated, gtk::Button.new('Help')
    notebook.set_action_widget(help, :end)
    allow(Lich::Common::Script).to receive(:current).and_return(Object.new)
    expect { notebook.set_action_widget(nil, :end) }.to raise_error(gtk::UnsupportedOperation)
    expect { notebook.get_action_widget(:end) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    expect(notebook.get_action_widget(:end)).to equal(help)
    expect(help.parent).to equal(notebook)
  end

  it 'shows and retires auxiliary descendants once, and independent destruction does not remove pages' do
    notebook, help = populated, gtk::Button.new('Help')
    count = 0
    help.signal_connect('destroy') { count += 1 }
    notebook.set_action_widget(help, :end)
    help.no_show_all = true
    notebook.show_all
    expect(help.visible?).to be(false)
    help.no_show_all = false
    notebook.show_all
    expect(help.visible?).to be(true)
    help.destroy
    expect(notebook.get_action_widget(:end)).to be_nil
    expect(notebook.n_pages).to eq(4)
    notebook.destroy
    expect(count).to eq(1)
  end

  it 'remains retired when a child destroy callback reenters owner teardown' do
    notebook, help = populated, gtk::Button.new('Help')
    count = 0
    help.signal_connect('destroy') { count += 1; notebook.destroy }
    notebook.set_action_widget(help, :end)
    notebook.materialize
    notebook.destroy
    notebook.destroy
    expect(count).to eq(1)
    expect(help.destroyed?).to be(true)
    expect(notebook.get_action_widget(:end)).to be_nil
  end

  def replace_generation(notebook, provider)
    label = gtk::Label.new('Help')
    action = gtk::Button.new.add(label)
    label.style_context.add_class('help')
    label.style_context.add_provider(provider)
    action.signal_connect('clicked') { action.label = 'Clicked' }
    notebook.set_action_widget(action, :end)
    WeakRef.new(action)
  end

  it 'collects abandoned replacements while retained detached actions retain callbacks, styles and handles' do
    notebook, provider = populated, gtk::CssProvider.new
    notebook.materialize
    references = 30.times.map { replace_generation(notebook, provider) }
    retained = notebook.get_action_widget(:end)
    handle = retained.materialize
    notebook.set_action_widget(nil, :end)
    3.times { GC.start(full_mark: true, immediate_sweep: true) }
    expect(references.take(29).none?(&:weakref_alive?)).to be(true)
    provider.load_from_data('label.help { color: gold; }')
    gtk::Box.new(:vertical).add(retained).materialize
    expect(retained.materialize).to equal(handle)
    expect(retained.children.first.send(:component_props)[:foreground]).to include(r: 255, g: 215, b: 0)
  end
end
