# frozen_string_literal: true

require 'timeout'
require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# 2.14: a window that connects key-press-event receives keys aimed at the
# window itself. calibrate_creaturebar does `case event.keyval; when
# Gdk::Keyval::KEY_Left` -- a free-form case, so the event's keyval has to
# compare equal to the symbol that constant resolves to. A page root has no
# per-cid binding channel, so the key rides the lifecycle path.
RSpec.describe 'GTK compatibility shim: window key events' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:gdk) { Lich::Common::ScriptScope::Gdk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('keys') }
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

  describe 'Gtk.keyval_for' do
    it 'reproduces the symbol Gdk::Keyval::KEY_<name> resolves to' do
      # The two must agree: keyval_for is "key_#{name}".downcase, and
      # Gdk.const_missing downcases the whole constant name the same way.
      expect(gtk.keyval_for('Left')).to eq(:key_left)
      expect(gtk.keyval_for('Right')).to eq(:key_right)
      expect(gtk.keyval_for('Up')).to eq(:key_up)
      expect(gtk.keyval_for('Down')).to eq(:key_down)
      expect(gtk.keyval_for('Page_Up')).to eq(:key_page_up)
    end

    it 'collapses upper- and lower-case a letter the same way const_missing does' do
      # KEY_s and KEY_S both downcase to :key_s; a script telling them apart
      # reads the shift modifier, not the keyval.
      expect(gtk.keyval_for('s')).to eq(:key_s)
      expect(gtk.keyval_for('S')).to eq(:key_s)
    end

    it 'is nil for an absent name so no phantom key fires' do
      expect(gtk.keyval_for(nil)).to be_nil
      expect(gtk.keyval_for('')).to be_nil
    end

    it 'equals the constant a script actually compares against' do
      # Gdk is a sibling namespace of Gtk, not a child. Resolving
      # Gdk::Keyval::KEY_Left here goes through the same const_missing
      # fallbacks a script's `case event.keyval` does, so this is the real
      # comparison and not a restatement of keyval_for's own arithmetic.
      %w[Left Right Up Down s S Page_Up].each do |name|
        # Literal :: syntax, because const_get does not fire const_missing.
        constant = gdk.module_eval("Keyval::KEY_#{name}", __FILE__, __LINE__)
        expect(gtk.keyval_for(name)).to eq(constant)
      end
    end
  end

  describe 'a window opting into key events' do
    def window_with_key_handler
      received = []
      window = session.sync do
        w = gtk::Window.new('Keys')
        w.set_default_size(300, 200)
        w.signal_connect('key-press-event') { |_widget, event| received << event }
        w.show_all
        w
      end
      session.commit
      [window, received]
    end

    it 'declares key_events on the page node only when a handler is connected' do
      session.sync { w = gtk::Window.new('Quiet'); w.show_all; w }
      session.commit
      quiet_page = service.registry.pages_for(owner).find { |page| page.title == 'Quiet' }
      quiet_node = quiet_page.last_render.tree.each.find { |component| component.type == :page }
      expect(quiet_node.props).not_to include(:key_events)

      window_with_key_handler
      page = service.registry.pages_for(owner).find { |candidate| candidate.title == 'Keys' }
      node = page.last_render.tree.each.find { |component| component.type == :page }
      expect(node.props[:key_events]).to eq(true)
    end

    it 'delivers a key as a Gdk-shaped event whose keyval matches the constant' do
      window, received = window_with_key_handler
      context = Struct.new(:payload).new({ keyval: 'Left', modifiers: [] })

      session.sync { window.receive_key(context) }

      expect(received.length).to eq(1)
      event = received.first
      expect(event.keyval).to eq(:key_left)
      # The same symbol a script's `when Gdk::Keyval::KEY_Left` compares to.
      expect(event.keyval).to eq(gdk.module_eval('Keyval::KEY_Left', __FILE__, __LINE__))
    end

    it 'carries the modifier state so shift and ctrl are readable' do
      window, received = window_with_key_handler
      context = Struct.new(:payload).new({ keyval: 'S', modifiers: %w[shift ctrl] })

      session.sync { window.receive_key(context) }

      event = received.first
      expect(event.state.shift_mask?).to be(true)
      expect(event.state.control_mask?).to be(true)
      expect(event.state.mod1_mask?).to be(false)
    end
  end

  describe 'the contract' do
    it 'accepts a key event only on a page that enabled it' do
      payload = { keyval: 'Left', modifiers: [] }
      expect do
        validator.validate_event!(:page, :key, payload, props: { key_events: true }, owner: 'o', page_id: 'p', cid: 'c')
      end.not_to raise_error

      expect do
        validator.validate_event!(:page, :key, payload, props: {}, owner: 'o', page_id: 'p', cid: 'c')
      end.to raise_error(Lich::WebUI::Error, /key events are not enabled/)
    end

    it 'is a lifecycle event, so it dispatches non-coalescably' do
      schema = Lich::WebUI::Contract.schema(:page)[:events].fetch(:key)
      expect(schema[:lifecycle]).to be(true)
      expect(schema[:terminal]).to be(false)
    end

    it 'bumps the contract version alongside the client' do
      client = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.js'))
      expect(client).to include(%(const VERSION = "#{Lich::WebUI::Contract::VERSION}"))
    end
  end
end
