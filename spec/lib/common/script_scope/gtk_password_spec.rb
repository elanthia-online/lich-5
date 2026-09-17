# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'
require 'timeout'

# A viewer connection that records what the runtime sent it.
PasswordSpecConnection = Class.new do
  attr_reader :viewer_id

  def initialize(viewer_id)
    @viewer_id = viewer_id
    @sent = []
    @mutex = Mutex.new
  end

  def send_text(payload)
    @mutex.synchronize { @sent << JSON.parse(payload) }
    true
  end

  def close = nil
  def sent = @mutex.synchronize { @sent.dup }
  def alive? = true
end

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

  # An ordinary entry's value does arrive in the event payload, on `change`.
  it 'takes the typed value from an ordinary entry event' do
    entry = build(visible: true)
    seen = nil
    entry.signal_connect('changed') { |widget| seen = widget.text }

    session.sync { entry.send(:receive_event, :change, Struct.new(:payload).new({ 'value' => 'hunter2' })) }

    expect(seen).to eq('hunter2')
    expect(entry.text).to eq('hunter2')
  end

  # A password's value travels only in the submission scope: the contract gives
  # password_input's `submit` no payload at all, so a spec that hands the widget
  # a fabricated `{ value: ... }` proves nothing the runtime can ever deliver.
  it 'never reads a password from an event payload' do
    entry = build(visible: false)

    session.sync { entry.send(:receive_event, :submit, Struct.new(:payload).new({ 'value' => 'hunter2' })) }

    expect(entry.text).to eq('')
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

  # The end-to-end test F3 needs. Every earlier assertion here is about the
  # component tree, which proves the nodes exist and says nothing about whether
  # the typed password ever reaches the script. This drives a real viewer
  # message through the runtime and asserts a GTK-style handler reads it back
  # with `entry.text` -- which is how Lich's own login GUI reads it, from the
  # *button's* handler rather than the entry's.
  describe 'a password reaching the script' do
    let(:connection) { PasswordSpecConnection.new('connection-one') }

    def login_window
      session.sync do
        window = gtk::Window.new('Login')
        box = gtk::VBox.new
        window.add(box)
        entry = gtk::Entry.new
        entry.visibility = false
        box.add(entry)
        button = gtk::Button.new('Connect')
        box.add(button)
        window.show_all
        [window, entry, button]
      end
    end

    def attach(page)
      address = service.registry.address_for(page)
      service.runtime.handle(connection, type: 'attach', page: address,
                                         version: Lich::WebUI::Contract::VERSION)
      [address, connection.sent.last]
    end

    # `password_entry.text = ""` after a rejected password zeroed the script's
    # copy and pushed nothing: a password's value is write-only, so there was
    # no property to send, and the viewer kept seeing the text it had typed.
    it 'empties the viewer field when the script clears a password entry' do
      window, entry, _button = login_window
      session.commit
      page = service.registry.pages_for(owner).fetch(0)
      attach(page)
      cid = page.last_render.tree.each.find { |node| node.props[:key] == entry.key }.cid
      before = connection.sent.count { |message| message['type'] == 'clear_sensitive' }

      session.sync { entry.text = '' }
      session.sync { nil }

      clears = connection.sent.select { |message| message['type'] == 'clear_sensitive' }
      expect(clears.length).to eq(before + 1)
      expect(clears.last).to eq('type' => 'clear_sensitive', 'cids' => [cid])
      expect(window.handle).not_to be_nil
    end

    it 'delivers the typed password to a button handler that reads entry.text' do
      window, entry, button = login_window
      seen = Queue.new
      session.sync { button.signal_connect('clicked') { seen << entry.text } }
      session.commit
      page = service.registry.pages_for(owner).fetch(0)
      address, render = attach(page)
      cid = ->(widget) { page.last_render.tree.each.find { |node| node.props[:key] == widget.key }.cid }
      secret = +'hunter2'

      service.runtime.handle(
        connection, type: 'event', page: address, cid: cid.call(button), event: 'activate',
                    generation: render['generation'], payload: {}, submission: [secret]
      )

      expect(Timeout.timeout(5) { seen.pop }).to eq('hunter2')
      expect(entry.text).to eq('hunter2')
      # The value never travels back toward the browser, and the raw carrier the
      # viewer sent is zeroed rather than left on the heap.
      expect(page.last_render.to_s).not_to include('hunter2')
      expect(secret).to eq('')
      expect(window).to be_a(gtk::Window)
    end

    it 'names the password entry in the button submit scope, and no plain entry' do
      window, entry, button = login_window
      plain = session.sync do
        extra = gtk::Entry.new
        window.children.first.add(extra)
        window.show_all
        extra
      end
      session.commit
      render = service.registry.pages_for(owner).fetch(0).last_render
      cid = ->(widget) { render.tree.each.find { |node| node.props[:key] == widget.key }.cid }

      expect(render.submissions[cid.call(button)]).to eq([cid.call(entry)])
      expect(render.submissions[cid.call(button)]).not_to include(cid.call(plain))
    end
  end
end
