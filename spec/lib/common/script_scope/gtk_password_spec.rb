# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# GTK has no password widget: an Entry with visibility off is one. The shim
# ignored that, so Lich's own login GUI -- which sets it on eight entries,
# including the master password -- rendered every one as a plain text box.
RSpec.describe 'GTK compatibility shim: password entries' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('gui') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }
  let(:validator) { Lich::WebUI::Validator.new }

  before do
    gtk::Session.browser_open = proc { |_url, geometry:, on_start:, on_exit:| [geometry, on_exit]; on_start.call(1); true }
    gtk::Session.browser_kill = proc { |_pid| nil }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    gtk::Session.browser_kill = nil
    session.shutdown
    service.stop
  end

  def build(visible:)
    session.sync do
      window = gtk::Window.new('Login')
      window.set_default_size(400, 300)
      box = gtk::VBox.new
      window.add(box)
      entry = gtk::Entry.new
      entry.visibility = false unless visible
      box.add(entry)
      window.show_all
      entry
    end
  end

  it 'renders an entry with visibility off as a password input' do
    entry = build(visible: false)

    expect(entry.send(:node_type)).to eq(:password_input)
    expect(build(visible: true).send(:node_type)).to eq(:text_input)
  end

  # The contract gives password_input no `value` property at all: its value
  # is sensitive and write-only, so what the viewer types is never echoed
  # back to any viewer, nor written to a golden.
  it 'never carries the value toward the browser' do
    props = build(visible: false).send(:node_props)

    expect(props).not_to include(:value)
    expect { validator.validate_component!(:password_input, props, owner: 'gui', page_id: 'p', cid: 'c') }
      .not_to raise_error
  end

  it 'still carries the value for an ordinary entry' do
    expect(build(visible: true).send(:node_props)).to include(:value)
  end

  # password_input has only `submit`; binding `change` would have the
  # adapter refuse the whole widget, which drops it from its parent.
  it 'binds only the events a password input has' do
    expect(build(visible: false).send(:always_bound_events)).to eq([])
    expect(build(visible: true).send(:always_bound_events)).to eq([:change])
  end

  it 'refuses to map a changed handler onto a password field' do
    entry = build(visible: false)

    expect(entry.send(:event_for, :changed)).to be_nil
    expect(entry.send(:event_for, :activate)).to eq(:submit)
  end

  # submit is the only event that carries a password's value, so without it
  # the typed password was lost on the way in as well as kept off the way out.
  it 'takes the typed value from a submit' do
    entry = build(visible: false)
    seen = nil
    entry.signal_connect('activate') { |widget| seen = widget.text }

    session.sync { entry.send(:receive_event, :submit, Struct.new(:payload).new({ 'value' => 'hunter2' })) }

    expect(seen).to eq('hunter2')
    expect(entry.text).to eq('hunter2')
  end

  # The login GUI turns visibility off after building the entry, and a
  # node's type is fixed once created.
  it 'rebuilds the node when a live entry becomes a password field' do
    entry = build(visible: true)
    session.commit
    page = service.registry.pages_for(owner).fetch(0)
    expect(page.last_render.tree.each.map(&:type)).to include(:text_input)

    session.sync { entry.visibility = false }
    session.commit

    types = page.last_render.tree.each.map(&:type)
    expect(types).to include(:password_input)
    expect(types).not_to include(:text_input)
  end
end
