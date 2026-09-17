# frozen_string_literal: true

require 'timeout'
require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# Gtk::Dialog: a window with a content area, an action area and a blocking
# run, plus the Stock labels a dialog OK button names. Taken from the
# tip's slice-five spec; Dialog is part of the core widget vocabulary.
RSpec.describe 'GTK compatibility shim: Dialog' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('dialog') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }

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

    # run promises the very object given to add_button, and false and nil
    # are legal ones. The loop was `until @response`, so a false answer could
    # never end it, and the fallback `@response || DELETE_EVENT` turned one
    # that did into a close.
    it 'returns a false response as itself from an off-thread run' do
      dialog = no = nil
      session.sync do
        dialog = gtk::Dialog.new(title: 'Q11', buttons: [['No', false]])
        no = dialog.action_area.children.last
      end
      result = :unset
      thread = Thread.new { result = dialog.run }
      sleep 0.2
      session.sync { no.send(:receive_event, :activate, Struct.new(:payload).new({})) }
      thread.join(3)

      expect(result).to be(false)
    end

    it 'returns a false response as itself from a run on the session thread' do
      dialog = no = nil
      session.sync do
        dialog = gtk::Dialog.new(title: 'Q12')
        no = dialog.add_button('No', false)
      end
      Thread.new { sleep 0.3; session.enqueue { no.send(:receive_event, :activate, Struct.new(:payload).new({})) } }

      result = Queue.new
      session.enqueue { result << dialog.run }

      expect(Timeout.timeout(6) { result.pop }).to be(false)
    end

    it 'returns a nil response as itself' do
      dialog = cancel = nil
      session.sync do
        dialog = gtk::Dialog.new(title: 'Q13')
        cancel = dialog.add_button('Cancel', nil)
      end
      result = :unset
      thread = Thread.new { result = dialog.run }
      sleep 0.2
      session.sync { cancel.send(:receive_event, :activate, Struct.new(:payload).new({})) }
      thread.join(3)

      expect(result).to be_nil
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

    # A run answered more than once -- a double click, or a respond racing a
    # close -- left the extra answers on the queue, and the next run popped
    # one and returned before the viewer had seen the dialog at all.
    it 'does not answer a second run with a leftover from the first' do
      dialog = ok = nil
      session.sync do
        dialog = gtk::Dialog.new(title: 'Q9')
        ok = dialog.add_button('OK', :ok)
      end
      first = nil
      opener = Thread.new { first = dialog.run }
      sleep 0.2
      session.sync { 2.times { ok.send(:receive_event, :activate, Struct.new(:payload).new({})) } }
      opener.join(3)

      expect(first).to eq(:ok)

      second = :never_returned
      waiter = Thread.new { second = dialog.run }
      finished = waiter.join(1)
      waiter.kill unless finished

      expect(finished).to be_nil
      expect(second).to eq(:never_returned)
    end

    # Session teardown is a cancellation, not just a cleanup. close_window
    # removed adapter and browser state but never released a parked run, so an
    # off-thread caller stayed blocked for the life of the process and the
    # dialog never reported itself destroyed. Distinct from tab-close and
    # browser-exit, which are the viewer's doing.
    it 'releases a waiting run when the session shuts down' do
      dialog = session.sync { gtk::Dialog.new(title: 'Q10', buttons: [['OK', :ok]]) }
      result = nil
      waiter = Thread.new { result = dialog.run }
      sleep 0.2
      session.shutdown

      expect(waiter.join(3)).not_to be_nil
      expect(result).to eq(gtk::ResponseType::DELETE_EVENT)
      expect(dialog.destroyed?).to be(true)
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
