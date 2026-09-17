# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# GLib::Idle.add re-enqueued itself directly and registered a fresh source on
# every pass. A block that kept returning true queued its next run with no
# delay, so the session thread spun on it, and @sources grew by one each time.
# The id it handed back mapped to nil, so Source.remove could never stop it.
RSpec.describe 'GTK compatibility shim: GLib sources' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:glib) { Lich::Common::ScriptScope::GLib }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('idle') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }

  before do
    gtk::Session.browser_open = proc { |_url, geometry:, on_start:, on_exit:| [geometry, on_exit]; on_start.call(1); true }
    gtk::Session.browser_kill = proc { |_pid| nil }
    allow(gtk::Session).to receive(:current).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    gtk::Session.browser_kill = nil
    session.shutdown
    service.stop
  end

  def sources
    glib.instance_variable_get(:@sources)
  end

  describe 'Idle.add' do
    it 'repeats while the block asks to and then stops' do
      runs = 0
      glib::Idle.add { (runs += 1) < 3 }

      # Bounded: a regression spins rather than hanging the suite.
      20.times { break if runs >= 3; sleep 0.05 }

      expect(runs).to eq(3)
    end

    it 'registers one source for the whole run, not one per pass' do
      before_count = sources.size
      runs = 0
      glib::Idle.add { (runs += 1) < 4 }
      20.times { break if runs >= 4; sleep 0.05 }
      sleep 0.05

      expect(sources.size).to be <= before_count + 1
    end

    # The id mapped to nil, so remove reported false and killed nothing.
    it 'hands back an id that Source.remove can actually cancel' do
      runs = 0
      id = glib::Idle.add { runs += 1; true }
      10.times { break if runs.positive?; sleep 0.05 }

      expect(glib::Source.remove(id)).to be(true)

      # The killed thread may be mid-pass, so let it settle before sampling
      # rather than racing it: what matters is that it stops, not exactly when.
      sleep 0.2
      settled = runs
      sleep 0.2

      expect(runs).to eq(settled)
    end
  end

  # The spawned thread's ensure read a closure variable that the caller
  # assigned only after Thread.new returned. With interval 0 and a block that
  # answers false at once, the thread could reach its ensure before the id
  # existed, skip the removal, and leave a dead entry in @sources forever.
  describe 'Timeout.add' do
    def source_thread(id)
      glib.instance_variable_get(:@sources_mutex).synchronize { sources[id] }
    end

    it 'removes its source even when the block finishes before the id is handed back' do
      # Widens the window the race needs: the thread is well past its ensure
      # by the time the id is registered.
      allow(glib).to receive(:register_source).and_wrap_original do |original, *args|
        sleep 0.1
        original.call(*args)
      end

      id = glib::Timeout.add(0) { false }
      source_thread(id)&.join(2)
      sleep 0.05

      expect(sources).not_to have_key(id)
    end

    it 'hands back an id that Source.remove can cancel while the timer is still waiting' do
      runs = 0
      id = glib::Timeout.add(50) { runs += 1; true }

      expect(glib::Source.remove(id)).to be(true)
      sleep 0.15

      expect(runs).to eq(0)
    end
  end

  describe 'Idle.add registration' do
    it 'removes its source even when the block finishes before the id is handed back' do
      allow(glib).to receive(:register_source).and_wrap_original do |original, *args|
        sleep 0.1
        original.call(*args)
      end

      id = glib::Idle.add { false }
      glib.instance_variable_get(:@sources_mutex).synchronize { sources[id] }&.join(2)
      sleep 0.05

      expect(sources).not_to have_key(id)
    end
  end
end
