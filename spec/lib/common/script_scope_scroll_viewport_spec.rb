# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'legacy scroll viewport composition' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope::Gtk }
  let(:owner) { Struct.new(:name).new('viewport.lic') }
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
    Lich::Common::ScriptDeath.run(@other) if @other
    service.stop
  end

  it 'maps the automatic policy spelling and retains attributed unknown-constant refusal' do
    expect(gtk::POLICY_AUTOMATIC).to eq(:automatic)
    scroll = gtk::ScrolledWindow.new
    expect(scroll.set_policy(gtk::POLICY_AUTOMATIC, gtk::POLICY_AUTOMATIC)).to equal(scroll)
    expect { gtk::POLICY_UNSUPPORTED }.to raise_error(gtk::UnsupportedOperation, /POLICY_UNSUPPORTED/)
  end

  [false, true].each do |live|
    it "composes one viewport and preserves input identity (materialized=#{live})" do
      scroll = gtk::ScrolledWindow.new
      scroll.materialize if live
      child = gtk::Entry.new
      child.text = 'draft'
      handle = child.materialize
      expect(scroll.add_with_viewport(child)).to equal(scroll)
      viewport = scroll.children.fetch(0)
      expect(viewport).to be_a(gtk::Viewport)
      expect(viewport.children).to eq([child])
      expect(child.materialize).to equal(handle)
      expect(child.text).to eq('draft')
      scroll.destroy
      expect(child).to be_destroyed
      expect(viewport).to be_destroyed
    end
  end

  it 'allocates a viewport within its host while honoring explicit expansion flags' do
    window = gtk::Window.new
    scroll = gtk::ScrolledWindow.new
    window.add(scroll)
    scroll.add_with_viewport(gtk::Box.new(:vertical))
    expect(window.send(:component_props)[:viewport]).to be(true)
    expect(scroll.send(:component_props)[:fill]).to be(true)
    scroll.set_vexpand(false)
    expect(window.send(:component_props)[:viewport]).to be(false)
    expect(scroll.send(:component_props)[:fill]).to be(false)
  end

  it 'does not wrap an existing viewport twice' do
    scroll = gtk::ScrolledWindow.new
    viewport = gtk::Viewport.new
    scroll.add_with_viewport(viewport)
    expect(scroll.children).to eq([viewport])
  end

  it 'refuses invalid, parented, destroyed, excess and cyclic children without mutation' do
    scroll = gtk::ScrolledWindow.new
    parent = gtk::Box.new
    parent.add(scroll)
    parented = gtk::Entry.new
    parent.add(parented)
    destroyed = gtk::Entry.new
    destroyed.destroy
    [Object.new, parented, destroyed, parent, scroll].each do |invalid|
      expect { scroll.add_with_viewport(invalid) }.to raise_error(gtk::UnsupportedOperation)
      expect(scroll.children).to be_empty
    end
    first, second = gtk::Entry.new, gtk::Entry.new
    scroll.add_with_viewport(first)
    expect { scroll.add_with_viewport(second) }.to raise_error(gtk::UnsupportedOperation)
    expect(second.parent).to be_nil
    scroll.destroy
    empty = gtk::Entry.new
    expect { scroll.add_with_viewport(empty) }.to raise_error(gtk::UnsupportedOperation)
    expect(empty.parent).to be_nil
  end

  it 'refuses foreign children and use by another owner' do
    scroll, child = gtk::ScrolledWindow.new, gtk::Entry.new
    @other = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other)
    foreign = gtk::Entry.new
    expect { scroll.add_with_viewport(child) }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    expect { scroll.add_with_viewport(foreign) }.to raise_error(gtk::UnsupportedOperation)
    expect(scroll.children).to be_empty
    expect(foreign.parent).to be_nil
  end

  it 'rolls back a failed live attach without destroying or reparenting the input' do
    scroll, child = gtk::ScrolledWindow.new, gtk::Entry.new
    root, handle = scroll.materialize, child.materialize
    child.text = 'retained'
    port = scroll.session.port
    allow(port).to receive(:attach).and_wrap_original do |original, parent, *args|
      raise Lich::WebUI::Error, 'attach refused' if parent.equal?(root)
      original.call(parent, *args)
    end
    expect { scroll.add_with_viewport(child) }.to raise_error(Lich::WebUI::Error, /attach refused/)
    expect(scroll.children).to be_empty
    expect(child.parent).to be_nil
    expect(child).not_to be_destroyed
    expect(child.materialize).to equal(handle)
    expect(child.text).to eq('retained')
    allow(port).to receive(:attach).and_call_original
    scroll.add_with_viewport(child)
    expect(scroll.children.first.children).to eq([child])
  end
end
