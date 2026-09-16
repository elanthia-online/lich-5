# frozen_string_literal: true

require 'timeout'
require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# Slice five's long tail: Paned, Overlay, ProgressBar, ListBox and custom
# Dialog, plus the Stock labels a dialog's OK button names. Each used to
# fall through Gtk.const_missing into an empty box.
RSpec.describe 'GTK compatibility shim: slice five widgets' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('slice5') }
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

  def props_of(type, &build)
    node = nil
    session.sync do
      window = gtk::Window.new('Slice5')
      window.set_default_size(600, 400)
      window.add(build.call)
      window.show_all
      node = build.call
    end
    session.commit
    page = service.registry.pages_for(owner).fetch(0)
    found = nil
    page.last_render.tree.each { |component| found = component if component.type == type }
    found
  end

  it 'gives every slice-five class a real implementation, not a stub' do
    %i[Paned HPaned VPaned Overlay ListBox ListBoxRow ProgressBar].each do |name|
      expect(gtk.const_get(name)).not_to respond_to(:webui_stub?)
    end
  end

  describe 'ProgressBar' do
    # Real GTK (3.24.52, checked): `text =` alone leaves show-text false and
    # the text does not render. The shim's guard was tautological, so the
    # label went out either way and a bar whose text a script had switched
    # off still showed it. creaturebar's calibrator drives this from a "Text"
    # checkbox, so it is a live difference rather than a theoretical one.
    it 'renders a progress node with a fraction and label' do
      bar = session.sync do
        b = gtk::ProgressBar.new
        b.fraction = 0.4
        b.text = 'Spirit Warding I'
        b.show_text = true
        b
      end
      props = bar.send(:node_props)

      expect(props).to include(value: 0.4, label: 'Spirit Warding I')
      expect { validator.validate_component!(:progress, props, owner: 's', page_id: 'p', cid: 'c') }.not_to raise_error
    end

    it 'withholds the label until show_text asks for it, as GTK does' do
      bar = session.sync { b = gtk::ProgressBar.new; b.fraction = 0.4; b.text = 'hidden'; b }

      expect(bar.send(:node_props)).to include(value: 0.4)
      expect(bar.send(:node_props)).not_to have_key(:label)
    end

    it 'reports a pulse as indeterminate, and a later fraction ends it' do
      bar = session.sync { gtk::ProgressBar.new }
      session.sync { bar.pulse }
      expect(bar.send(:node_props)).to include(indeterminate: true)

      session.sync { bar.fraction = 0.5 }
      expect(bar.send(:node_props)).not_to include(:indeterminate)
    end
  end

  describe 'Paned' do
    it 'renders as a split with its panes in slot order' do
      component = props_of(:split) do
        paned = gtk::Paned.new(:horizontal)
        paned.add1(gtk::Label.new('left'))
        paned.add2(gtk::Label.new('right'))
        paned
      end

      expect(component.props[:orientation]).to eq('horizontal')
      expect(component.children.map(&:slot)).to eq(%w[first second])
      expect { validator.validate_component!(:split, component.props, owner: 's', page_id: 'p', cid: 'c') }.not_to raise_error
    end

    it 'converts a pixel position to a percent of the window axis' do
      paned = session.sync do
        window = gtk::Window.new('P'); window.set_default_size(400, 300)
        p = gtk::Paned.new(:horizontal); window.add(p); window.show_all
        p.position = 100
        p
      end

      # 100 of a 400px window is a quarter.
      expect(paned.send(:node_props)[:position]).to eq(25)
    end
  end

  describe 'Overlay' do
    it 'renders the base and its overlays as one overlay node' do
      component = props_of(:overlay) do
        overlay = gtk::Overlay.new
        overlay.add(gtk::Label.new('base'))
        overlay.add_overlay(gtk::Label.new('on top'))
        overlay
      end

      expect(component.children.length).to eq(2)
      expect { validator.validate_component!(:overlay, component.props, owner: 's', page_id: 'p', cid: 'c') }.not_to raise_error
    end
  end

  describe 'ListBox' do
    it 'renders as a stack of group rows' do
      component = props_of(:stack) do
        list = gtk::ListBox.new
        list.selection_mode = :single
        2.times { |i| row = gtk::ListBoxRow.new; row.add(gtk::Label.new("row #{i}")); list.add(row) }
        list
      end

      expect(component.children.map(&:type)).to eq(%i[group group])
    end
  end

  describe 'Stock labels' do
    it 'resolves the constants a dialog OK button names' do
      expect(gtk::Stock::OK).to eq('OK')
      expect(gtk::Stock::CANCEL).to eq('Cancel')
    end
  end

  describe 'a custom Dialog' do
    it 'renders its content and buttons and validates' do
      session.sync do
        d = gtk::Dialog.new(title: 'Question', buttons: [['Cancel', :cancel], ['OK', :ok]])
        d.content_area.add(gtk::Label.new('Are you sure?'))
        d.show
        d
      end
      session.commit
      page = service.registry.pages_for(owner).find { |candidate| candidate.title == 'Question' }

      expect(page).not_to be_nil
      expect(page.last_render.tree.each.map(&:type)).to include(:button)
    end

    # gtk_dialog_run blocks on the main thread while still servicing events.
    # run() is called from a queued job (a button handler) and the response
    # arrives as another queued job, which run() pumps.
    it 'blocks run on the session thread until a response is queued' do
      dialog = ok = nil
      session.sync do
        dialog = gtk::Dialog.new(title: 'Q2')
        dialog.add_button('Cancel', :cancel)
        ok = dialog.add_button('OK', :ok)
      end
      # The press lands as its own queued job while run() pumps.
      Thread.new { sleep 0.3; session.enqueue { ok.send(:receive_event, :activate, Struct.new(:payload).new({})) } }

      result = Queue.new
      session.enqueue { result << dialog.run }

      expect(Timeout.timeout(6) { result.pop }).to eq(:ok)
    end

    it 'returns the exact response object the script gave add_button' do
      response = Object.new
      dialog = ok = nil
      session.sync do
        dialog = gtk::Dialog.new(title: 'Q3', buttons: [['OK', response]])
        ok = dialog.action_area.children.last
      end
      result = nil
      thread = Thread.new { result = dialog.run }
      sleep 0.2
      session.sync { ok.send(:receive_event, :activate, Struct.new(:payload).new({})) }
      thread.join(3)

      expect(result).to equal(response)
    end

    it 'unblocks with DELETE_EVENT when the viewer closes it' do
      dialog = session.sync { gtk::Dialog.new(title: 'Q4', buttons: [['OK', :ok]]) }
      result = nil
      thread = Thread.new { result = dialog.run }
      sleep 0.2
      session.sync { dialog.destroy }
      thread.join(3)

      expect(result).to eq(gtk::ResponseType::DELETE_EVENT)
    end

    # The spec above closes the dialog with #destroy, which is what a script
    # does. A viewer closing the browser TAB arrives as #viewer_closed
    # instead -- and Dialog overrode #browser_exited (the whole browser
    # dying) without overriding that. So the ordinary way to dismiss a
    # confirmation dialog left #run parked on a queue nobody would push to.
    it 'unblocks with DELETE_EVENT when the viewer closes the tab' do
      dialog = session.sync { gtk::Dialog.new(title: 'Q5', buttons: [['OK', :ok]]) }
      result = nil
      thread = Thread.new { result = dialog.run }
      sleep 0.2
      session.sync { dialog.viewer_closed }

      expect(thread.join(3)).not_to be_nil
      expect(result).to eq(gtk::ResponseType::DELETE_EVENT)
    end

    it 'unblocks when the whole browser exits' do
      dialog = session.sync { gtk::Dialog.new(title: 'Q6', buttons: [['OK', :ok]]) }
      result = nil
      thread = Thread.new { result = dialog.run }
      sleep 0.2
      session.sync { dialog.browser_exited }

      expect(thread.join(3)).not_to be_nil
      expect(result).to eq(gtk::ResponseType::DELETE_EVENT)
    end

    # One push wakes one consumer. Two threads waiting on the same dialog
    # left the second parked forever.
    it 'unblocks every thread waiting on the same dialog' do
      dialog = session.sync { gtk::Dialog.new(title: 'Q7', buttons: [['OK', :ok]]) }
      results = Queue.new
      threads = Array.new(2) { Thread.new { results << dialog.run } }
      sleep 0.3
      session.sync { dialog.viewer_closed }
      joined = threads.map { |thread| thread.join(3) }

      expect(joined).to all(be_truthy)
      expect([results.pop, results.pop]).to all(eq(gtk::ResponseType::DELETE_EVENT))
    end

    it 'still delivers a real response rather than releasing waiters early' do
      dialog = ok = nil
      session.sync do
        dialog = gtk::Dialog.new(title: 'Q8')
        ok = dialog.add_button('OK', :ok)
      end
      result = nil
      thread = Thread.new { result = dialog.run }
      sleep 0.2
      session.sync { ok.send(:receive_event, :activate, Struct.new(:payload).new({})) }
      thread.join(3)

      expect(result).to eq(:ok)
    end
  end
end
