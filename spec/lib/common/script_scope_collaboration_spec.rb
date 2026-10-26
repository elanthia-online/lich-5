# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_shim_bindings'
require_relative '../../../lib/common/script_scope'

RSpec.describe 'bounded shim collaboration contracts' do
  include WebUISpecSupport::ShimBindings

  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:owner) { Struct.new(:name).new('collaboration.lic') }
  let(:service) { Lich::WebUI::Service.new }

  before do
    install_webui_shim_bindings
    allow(service.runtime).to receive(:schedule_render)
    allow(Lich).to receive(:log)
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  def context(payload = {}, viewer: 'origin')
    Struct.new(:viewer_id, :payload).new(viewer, payload)
  end

  def bindings_for(widget)
    callbacks = {}
    allow(widget.session.port).to receive(:bind).and_wrap_original do |method, handle, event, callback|
      callbacks[[handle, event]] = callback
      method.call(handle, event, callback)
    end
    widget.materialize
    callbacks
  end

  context 'queue and scheduled execution' do
    let(:jobs) { [] }
    let(:scheduler) { double('capturing scheduler', cancel_all: nil) }

    before do
      allow(Lich::WebUI).to receive(:callback_queue) { |**| proc { |&work| jobs << work; :queued } }
      allow(Lich::WebUI).to receive(:callback_scheduler).and_return(scheduler)
      allow(scheduler).to receive(:schedule) { |_interval, &work| jobs << work; 77 }
    end

    def admit(kind, &block)
      kind == :queue ? gtk.session.queue(&block) : gtk.session.schedule(gtk, :fixture, 0, &block)
    end

    %i[queue schedule].each do |kind|
      it "preserves #{kind} ownership adoption, pause checkpoint, context, batching and result" do
        group, main, trace = ThreadGroup.new, Thread.current, []
        allow(owner).to receive(:thread_group).and_return(group)
        allow(group).to(receive(:add).and_wrap_original do |method, thread|
          trace << :adopt
          method.call(thread)
        end)
        allow(Lich::Common::Script).to receive(:current) do
          adopted = group.list.include?(Thread.current)
          trace << (adopted ? :owner_lookup : :unowned_lookup) unless Thread.current.equal?(main)
          owner if Thread.current.equal?(main) || adopted
        end
        session = gtk.session
        window = gtk::Window.new
        model = gtk::ListStore.new(String)
        row = model.append
        row[0] = 'Original'
        expect(model).to receive(:begin_batch!).once.and_call_original
        expect(model).to receive(:publish_batch!).once.and_call_original
        observed = []
        session.callback(context, widget: window) do
          expect(admit(kind) {
            trace << :block
            observed << [session.viewer_id, session.with_widget(window) { session.viewer_id }, Lich::Common::Script.current]
            row[0] = 'First'
            row[0] = 'Final'
            :retained_result
          }).to eq(kind == :queue ? :queued : 77)
        end

        expect(Thread.new { jobs.shift.call }.value).to eq(:retained_result)
        expect(trace.first(3)).to eq(%i[unowned_lookup adopt owner_lookup])
        expect(trace.index(:owner_lookup)).to be < trace.index(:block)
        expect(observed).to eq([['origin', 'origin', owner]])
        expect(row[0]).to eq('Final')
        expect(session.in_callback?).to be(false)
        expect(session.viewer_id).to be_nil
      end

      it "discards admitted #{kind} work after stopping without running or adopting it" do
        stopping = false
        allow(owner).to receive(:stopping?) { stopping }
        expect(owner).not_to receive(:thread_group)
        ran = false
        admit(kind) { ran = true }
        stopping = true
        expect(jobs.shift.call).to be_nil
        expect(ran).to be(false)
        expect(gtk.session.in_callback?).to be(false)
      end

      it "rolls back #{kind} model edits and restores context after callback failure" do
        session = gtk.session
        model = gtk::ListStore.new(String)
        row = model.append
        row[0] = 'Original'
        session.send(:with_callback_context, 'origin', nil) do
          admit(kind) { row[0] = 'Rejected'; raise IOError, 'synthetic private detail' }
        end
        expect(jobs.shift.call).to be_nil
        expect(row[0]).to eq('Original')
        expect(session.in_callback?).to be(false)
        expect(session.viewer_id).to be_nil
        expect(Lich).to have_received(:log).with(/operation=queue.*error=IOError/)
        expect(Lich).not_to have_received(:log).with(/synthetic private detail/)
      end
    end

    it 'executes cleanup-thread queue work inline despite stopping and keeps schedule registration refused' do
      session = gtk.session
      allow(owner).to receive(:stopping?).and_return(true)
      stub_const('Lich::Common::Script::CLEANUP_SCRIPT_THREAD_KEY', :u08_cleanup_owner)
      previous = Thread.current.thread_variable_get(:u08_cleanup_owner)
      Thread.current.thread_variable_set(:u08_cleanup_owner, owner)
      seen = []
      expect(session.queue { seen << Thread.current; :ignored_result }).to eq(:queued)
      expect(seen).to eq([Thread.current])
      expect(jobs).to be_empty
      expect { session.schedule(gtk, :fixture, 0) {} }.to raise_error(gtk::UnsupportedOperation)
    ensure
      Thread.current.thread_variable_set(:u08_cleanup_owner, previous)
    end
  end

  context 'handler snapshots and pointer ownership' do
    [[:key_press, 'key-press-event', { keyval: 65, state: 0 }],
     [:pointer_enter, 'enter-notify-event', {}],
     [:window_state, 'window-state-event', { minimized: true }]].each do |event, signal, payload|
      it "stops #{event} handlers after destruction within an admitted snapshot" do
        widget = event == :pointer_enter ? gtk::EventBox.new : gtk::Window.new
        seen = []
        widget.signal_connect(signal) { seen << :first; widget.destroy; false }
        widget.signal_connect(signal) { seen << :unreachable; false }
        callbacks = bindings_for(widget)
        callbacks.fetch([widget.materialize, event]).call(context(payload))
        expect(seen).to eq([:first])
      end
    end

    [false, true].each do |header|
      it "keeps #{header ? 'header' : 'ordinary'} pointer true-stopping and connection guards after destruction" do
        widget = gtk::EventBox.new
        seen = []
        destroy_first = false
        widget.signal_connect('button-press-event') { seen << :first; widget.destroy if destroy_first; false }
        widget.signal_connect('button-press-event') { seen << :second; :truthy }
        widget.signal_connect('button-press-event') { seen << :handled; true }
        widget.signal_connect('button-press-event') { seen << :unreachable }
        source = widget
        if header
          widget.add(gtk::Label.new('Header'))
          source = gtk::Notebook.new
          source.append_page(gtk::Label.new('Page'), widget)
        end
        callbacks = bindings_for(source)
        payload = { x: 4, y: 5, button: 1, time: 0, state: 0 }
        payload[:tab] = source.send(:component_props)[:headers].first[:key] if header
        event = header ? :tab_pointer : :pointer_press
        callbacks.fetch([source.materialize, event]).call(context(payload))
        expect(seen).to eq(%i[first second handled])
        seen.clear
        destroy_first = true
        callbacks.fetch([source.materialize, event]).call(context(payload))
        expect(seen).to eq([:first])
      end
    end

    it 'retains a Layout drag on its first viewer and cancels all release handlers exactly once' do
      window, layout = gtk::Window.new, gtk::Layout.new
      seen = []
      layout.signal_connect('button-press-event') { false }
      layout.signal_connect('button-release-event') { seen << :first; true }
      layout.signal_connect('button-release-event') { seen << :second; false }
      window.add(layout)
      callbacks = bindings_for(window)
      press = callbacks.fetch([layout.materialize, :pointer_press])
      payload = { x: 4, y: 5, button: 1, time: 0, state: 0 }
      press.call(context(payload))
      expect([window.pointer_viewer, layout.pointer_viewer]).to eq(%w[origin origin])
      expect { press.call(context(payload, viewer: 'other')) }.to raise_error(gtk::UnsupportedOperation, /operation=pointer_press/)
      2.times { layout.cancel_pointer('origin') }
      expect(seen).to eq(%i[first second])
      expect(window.pointer_viewer).to be_nil
    end
  end

  it 'keeps new collaboration seams outside the public script API' do
    label = gtk::Label.new('Caption')
    %i[tab_owner caption_owner hidden? pointer_events? caption_fragments? header_presentation publish_layout!].each do |method|
      expect(label.respond_to?(method)).to be(false)
      expect { label.public_send(method) }.to raise_error(gtk::UnsupportedOperation, /operation=#{Regexp.escape(method.to_s)}/)
    end
  end
end
