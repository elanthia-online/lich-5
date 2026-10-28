# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'json'

# Viewer detach versus managed-window close, resume and expiry, and attach
# rollback (B2): 1836:RC5, 1836:RC7, 1836:RC8, 1836:RC9, 1836:RC17 and
# 1832:RC32.
RSpec.describe 'WebUI viewer lifecycle boundaries' do
  connection_class = Class.new do
    attr_reader :viewer_id

    def initialize(viewer_id, fail_sends: 0)
      @viewer_id = viewer_id
      @fail_sends = fail_sends
      @sent = []
      @mutex = Mutex.new
    end

    def send_text(payload)
      @mutex.synchronize do
        if @fail_sends.positive?
          @fail_sends -= 1
          raise Lich::WebUI::Protocol::Refusal.new(:frame_size, 'fixture frame refused')
        end
        @sent << JSON.parse(payload)
      end
      true
    end

    def close; end
    def alive? = true
    def sent = @mutex.synchronize { @sent.dup }
  end

  let(:owner) { Object.new }
  let(:registry) { Lich::WebUI::Registry.new }
  let(:dispatcher) { Lich::WebUI::Dispatcher.new }
  let(:now) { [100.0] }
  let(:viewers) { Lich::WebUI::ViewerStore.new(clock: -> { now.first }) }
  let(:coordinator) { [nil] }
  let(:runtime) do
    Lich::WebUI::Runtime.new(registry: registry, dispatcher: dispatcher, viewers: viewers,
                             viewers_changed: ->(who) { coordinator.first&.viewers_changed(who) })
  end
  let(:events) { Queue.new }

  after do
    runtime.shutdown
  end

  define_method(:connection) { |id, **options| connection_class.new(id, **options) }

  def attach(connection, page, resume: nil)
    message = { type: 'attach', page: registry.address_for(page) }
    message[:resume] = resume if resume
    runtime.handle(connection, message)
  end

  def detach(connection, page)
    runtime.handle(connection, type: 'detach', page: registry.address_for(page), generation: page.last_render.generation)
  end

  def drain
    marker = Queue.new
    runtime.dispatch(owner: owner) { marker << true }
    marker.pop(timeout: 2)
  end

  def settings_page
    recorder = events
    registry.register(Lich::WebUI::Page.new(
      owner: owner, id: 'settings', title: 'Settings',
      on: { close: ->(_context) { recorder << :close }, detach: ->(context) { recorder << [:detach, context.viewer_id] } }
    ) do
      button(key: 'save', label: 'Save', on: { activate: ->(context) { recorder << [:activate, context.viewer_id] } })
    end)
  end

  def drained_events
    drain
    Array.new(events.size) { events.pop }
  end

  describe 'viewer detach versus managed-window close (1836:RC8)' do
    it 'detaches one of two live viewers without closing the page for the other viewer' do
      page = settings_page
      first, second = connection('first'), connection('second')
      attach(first, page)
      attach(second, page)
      first_viewer = viewers.fetch(connection_id: 'first', address: registry.address_for(page)).viewer_id
      expect(detach(first, page)).to eq(:detached)

      render = second.sent.last
      runtime.handle(second, type: 'event', page: registry.address_for(page), generation: render['generation'],
                             cid: render.dig('tree', 'children', 0, 'cid'), event: 'activate', payload: {})
      recorded = drained_events
      expect(recorded).not_to include(:close)
      expect(recorded).to include([:detach, first_viewer])
      expect(recorded.count { |event| event.is_a?(Array) && event.first == :activate }).to eq(1)
      expect(registry.pages_for(owner)).to eq([page])
    end

    it 'keeps a reloaded viewer resumable and still dispatches the later managed-window close once' do
      page = settings_page
      runtime.watch_window(page)
      viewer = connection('viewer')
      attach(viewer, page)
      token = viewer.sent.last['resume']
      runtime.disconnect(viewer)
      reloaded = connection('reloaded')
      attach(reloaded, page, resume: token)
      expect(viewers.attachments_for(page).map(&:resume_state)).to eq([:resumed])
      expect(drained_events).not_to include(:close)

      detach(reloaded, page)
      runtime.browser_closed(page)
      runtime.browser_closed(page)
      expect(drained_events.count(:close)).to eq(1)
    end
  end

  describe 'detach with a refused lifecycle enqueue (1836:RC5)' do
    it 'still retires the attachment and leaves the window-close claim for the owned process path' do
      page = settings_page
      runtime.watch_window(page)
      viewer = connection('viewer')
      attach(viewer, page)
      drain
      allow(dispatcher).to receive(:enqueue).and_wrap_original do |original, **options, &work|
        raise Lich::WebUI::Dispatcher::OverflowError, 'fixture overflow' if options[:event] == :detach

        original.call(**options, &work)
      end

      expect(detach(viewer, page)).to eq(:refused)
      expect(viewer.sent.last).to include('type' => 'refusal')
      expect(viewers.attachments_for(page)).to be_empty
      expect { viewers.fetch(connection_id: 'viewer', address: registry.address_for(page)) }.to raise_error(Lich::WebUI::Error)

      runtime.browser_closed(page)
      expect(drained_events).to include(:close)
    end
  end

  describe 'disconnect with a refused detach enqueue (1836:RC17)' do
    it 'attempts every detach, schedules expiry and notifies owners before re-raising the first refusal' do
      recorder = events
      pages = %w[first second].map do |id|
        registry.register(Lich::WebUI::Page.new(owner: owner, id: id, title: id,
                                                on: { detach: ->(_context) { recorder << [:detach, id] } }) do
          text(key: 'status', content: 'Ready')
        end)
      end
      viewer = connection('viewer')
      pages.each { |page| attach(viewer, page) }
      drain
      notified = []
      coordinator[0] = Struct.new(:calls) { def viewers_changed(who) = calls << who }.new(notified)
      allow(dispatcher).to receive(:enqueue).and_wrap_original do |original, **options, &work|
        raise Lich::WebUI::Dispatcher::OverflowError, 'fixture overflow' if options[:event] == :detach && options[:page_id] == 'first'

        original.call(**options, &work)
      end

      expect { runtime.disconnect(viewer) }.to raise_error(Lich::WebUI::Dispatcher::OverflowError)
      expect(drained_events).to eq([[:detach, 'second']])
      expect(notified).to eq([owner])
      expect(runtime.instance_variable_get(:@expiry_queue).map(&:last)).to eq([owner])
      expect(runtime.viewers_present?(owner)).to be(true)
    end
  end

  describe 'modal no-viewer policy across resume and expiry (1836:RC7)' do
    def modal_coordinator
      coordinator[0] = Lich::WebUI::ModalCoordinator.new(
        registry: registry, runtime: runtime, viewers_present: ->(who) { runtime.viewers_present?(who) },
        pages_changed: proc {}
      )
    end

    def open_modal(policy)
      coordinator.first.open(owner: owner, id: "modal-#{policy}", title: 'Confirm', buttons: [{ id: 'ok', label: 'OK' }],
                             no_viewer: policy, default_button: 'ok')
    end

    %i[abort default].each do |policy|
      it "defers #{policy} while the only viewer is resumable and applies it once the store expires the viewer" do
        modal_coordinator
        page = settings_page
        viewer = connection('viewer')
        attach(viewer, page)
        future = open_modal(policy)

        runtime.disconnect(viewer)
        expect(future).not_to be_resolved
        expect(runtime.viewers_present?(owner)).to be(true)

        now[0] += Lich::WebUI::ViewerStore::RECONNECT_WINDOW
        coordinator.first.viewers_changed(owner)
        expect(future.await(timeout: 0)).to have_attributes(reason: :no_viewer, button: policy == :default ? 'ok' : nil)
      end
    end

    it 'keeps the modal pending when the viewer resumes inside the window' do
      modal_coordinator
      page = settings_page
      viewer = connection('viewer')
      attach(viewer, page)
      future = open_modal(:abort)
      token = viewer.sent.last['resume']
      runtime.disconnect(viewer)
      now[0] += Lich::WebUI::ViewerStore::RECONNECT_WINDOW - 1
      attach(connection('back'), page, resume: token)
      now[0] += 5
      coordinator.first.viewers_changed(owner)
      expect(future).not_to be_resolved
    end

    it 'delivers expiry at the deadline without any later request' do
      stub_const('Lich::WebUI::ViewerStore::RECONNECT_WINDOW', 0.2)
      real_viewers = Lich::WebUI::ViewerStore.new
      host = Lich::WebUI::Runtime.new(registry: registry, dispatcher: dispatcher, viewers: real_viewers,
                                      viewers_changed: ->(who) { coordinator.first&.viewers_changed(who) })
      coordinator[0] = Lich::WebUI::ModalCoordinator.new(
        registry: registry, runtime: host, viewers_present: ->(who) { host.viewers_present?(who) }, pages_changed: proc {}
      )
      page = settings_page
      viewer = connection('viewer')
      host.handle(viewer, type: 'attach', page: registry.address_for(page))
      future = open_modal(:abort)
      host.disconnect(viewer)
      expect(future).not_to be_resolved
      expect(future.await(timeout: 3)).to have_attributes(reason: :no_viewer, button: nil)
    ensure
      host&.shutdown
    end
  end

  describe 'failed attach rollback (1836:RC9)' do
    it 'leaves no viewer or connection record when delivery fails and accepts a retry on the same connection' do
      page = settings_page
      viewer = connection('viewer', fail_sends: 1)
      expect(attach(viewer, page)).to eq(:refused)
      expect(viewers.attachments_for(page)).to be_empty
      expect(runtime.viewers_present?(owner)).to be(false)
      expect(runtime.instance_variable_get(:@connections)).not_to have_key('viewer')

      expect(attach(viewer, page)).to eq(:attached)
      expect(viewers.attachments_for(page).length).to eq(1)
    end

    it 'validates the render before touching an earlier resumable attachment' do
      broken = [false]
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'flaky', title: 'Flaky') do
        raise Lich::WebUI::Error, 'fixture render failure' if broken.first

        text(key: 'status', content: 'Ready')
      end)
      viewer = connection('viewer')
      attach(viewer, page)
      token = viewer.sent.last['resume']
      runtime.disconnect(viewer)

      broken[0] = true
      expect(attach(connection('retry'), page, resume: token)).to eq(:refused)
      broken[0] = false
      expect(attach(connection('later'), page, resume: token)).to eq(:attached)
      expect(viewers.attachments_for(page).map(&:resume_state)).to eq([:resumed])
    end

    it 're-suspends a resumed viewer whose render cannot be delivered, so a later resume keeps it (1832:RC32)' do
      page = settings_page
      viewer = connection('viewer')
      attach(viewer, page)
      token = viewer.sent.last['resume']
      viewer_id = viewers.fetch(connection_id: 'viewer', address: registry.address_for(page)).viewer_id
      runtime.disconnect(viewer)

      failing = connection('retry', fail_sends: 1)
      # A presence check that saw no live viewer just before the resume reaches its
      # resumable check while the resume is live, pruning the runtime's record.
      allow(failing).to receive(:send_text).and_wrap_original do |original, *args|
        runtime.__send__(:resumable_viewers?, page)
        original.call(*args)
      end
      expect(attach(failing, page, resume: token)).to eq(:refused)
      expect(viewers.attachments_for(page)).to be_empty
      expect(runtime.viewers_present?(owner)).to be(true)
      expect(runtime.instance_variable_get(:@connections)).not_to have_key('retry')

      expect(attach(connection('later'), page, resume: token)).to eq(:attached)
      expect(viewers.attachments_for(page).map { |attachment| [attachment.viewer_id, attachment.resume_state] })
        .to eq([[viewer_id, :resumed]])
    end
  end
end
