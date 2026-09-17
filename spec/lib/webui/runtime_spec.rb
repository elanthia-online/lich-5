# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'timeout'

WebUIRuntimeSpecConnection = Class.new do
  attr_reader :viewer_id

  def initialize(viewer_id)
    @viewer_id = viewer_id
    @sent = []
    @closed = false
    @mutex = Mutex.new
  end

  def send_text(payload)
    @mutex.synchronize { @sent << JSON.parse(payload) }
    true
  end

  def close
    @mutex.synchronize { @closed = true }
  end

  def sent = @mutex.synchronize { @sent.dup }
  def closed? = @mutex.synchronize { @closed }
  def alive? = !closed?
end

RSpec.describe Lich::WebUI::Runtime do
  let(:owner) { Object.new }
  let(:registry) { Lich::WebUI::Registry.new }
  let(:dispatcher) { Lich::WebUI::Dispatcher.new }
  let(:viewers) { Lich::WebUI::ViewerStore.new }
  let(:runtime) { described_class.new(registry: registry, dispatcher: dispatcher, viewers: viewers) }
  let(:first_connection) { WebUIRuntimeSpecConnection.new('connection-one') }
  let(:second_connection) { WebUIRuntimeSpecConnection.new('connection-two') }

  after { dispatcher.shutdown }

  def attach(connection, page)
    address = registry.address_for(page)
    runtime.handle(connection, type: 'attach', page: address, version: '2.5.0')
    [address, connection.sent.last]
  end

  it 'accepts viewer-delivered generations independently and routes callbacks server-side' do
    callbacks = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'actions', title: 'Actions') do
      button(key: 'go', label: 'Go', on: { activate: ->(event) { callbacks << event } })
    end)
    address, first_render = attach(first_connection, page)
    _address, second_render = attach(second_connection, page)
    button_cid = first_render.dig('tree', 'children', 0, 'cid')

    result = runtime.handle(first_connection, {
      type: 'event', page: address, cid: button_cid, event: 'activate',
      generation: first_render['generation'], payload: {},
    })
    callback = callbacks.pop

    expect(second_render['generation']).to be > first_render['generation']
    expect(result).to eq(:queued)
    expect(callback.viewer_id).to start_with('attachment-')
    expect(callback.component.cid).to eq(button_cid)
  end

  it 'reports presentation support and records refused requests as declared degradations' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'presentation', title: 'Presentation') do
      presentation(always_on_top: true, borderless: true, opacity: 0.8, scrollbars: false)
    end)

    attach(first_connection, page)

    # always_on_top and opacity depend on the host: a page cannot raise its
    # own window or make the frame translucent, but on a host that can reach
    # the real window the shim does it there instead. borderless is refused
    # everywhere -- a frameless Chromium app window cannot be moved or closed.
    host = Lich::WebUI::WindowPresentation.support
    expect(page.presentation_support).to eq(
      { always_on_top: false, borderless: false, opacity: true, scrollbars: true }.merge(host)
    )
    expect(page.presentation_support.keys).to contain_exactly(
      :always_on_top, :borderless, :opacity, :scrollbars
    )
    refused = page.degradations.map { |refusal| refusal[:property] }
    %i[always_on_top borderless].each do |property|
      host[property] ? expect(refused).not_to(include(property)) : expect(refused).to(include(property))
    end
    # A page can always do these two itself.
    expect(refused).not_to include(:opacity, :scrollbars)
  end

  # The host's contribution is fixed for the life of the process, so the
  # merged table need not be rebuilt and re-frozen on every render.
  it 'reports the same frozen presentation support table on every call' do
    allow(Lich::WebUI::WindowPresentation).to receive(:support).and_return(always_on_top: true, opacity: true)

    first = runtime.presentation_support
    second = runtime.presentation_support

    expect(first).to eq(always_on_top: true, borderless: false, opacity: true, scrollbars: true)
    expect(first).to be_frozen
    expect(second).to equal(first)
  end

  # An unknown property must not be fetched out of the support table without a
  # default: that raised out of validated_render, which runs on both attach and
  # refresh, and took down every page carrying a presentation facility.
  it 'treats a presentation property it has no opinion about as honoured' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'unknown-presentation', title: 'P2') do
      presentation(opacity: 0.5)
    end)
    forged = double(facilities: { presentation: { opacity: 0.5, invented_property: true } })

    expect { runtime.send(:record_presentation_degradations, page, forged) }.not_to raise_error
    expect(runtime.degradations(page).map { |refusal| refusal[:property] }).not_to include(:invented_property)
  end

  it 'refuses stale and fabricated component events without invoking callbacks', security_id: 'sec-component-id' do
    callbacks = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'actions', title: 'Actions') do
      button(key: 'go', label: 'Go', on: { activate: ->(_event) { callbacks << true } })
    end)
    address, render = attach(first_connection, page)
    button_cid = render.dig('tree', 'children', 0, 'cid')

    stale = runtime.handle(first_connection, {
      type: 'event', page: address, cid: button_cid, event: 'activate',
      generation: render['generation'] + 1, payload: {},
    })
    fabricated = runtime.handle(first_connection, {
      type: 'event', page: address, cid: 'page:actions/button:forged', event: 'activate',
      generation: render['generation'], payload: {},
    })

    expect(stale).to eq(:refused)
    expect(fabricated).to eq(:refused)
    expect(callbacks).to be_empty
    sent = first_connection.sent
    expect(sent.map { |message| message['reason'] }).to include('stale_generation', 'component_id')
    # One transaction, in order: the refusal names the exact event, so the
    # client can find the record it kept for it, and the render that
    # superseded that event follows the refusal -- never precedes it, since
    # a render makes the client forget every record for its page.
    refusal_at = sent.index { |message| message['reason'] == 'stale_generation' }
    expect(sent[refusal_at]).to include('page' => address, 'cid' => button_cid, 'event' => 'activate')
    expect(sent[refusal_at + 1]).to include('type' => 'render', 'page' => address)
    expect(sent.count { |message| message['reason'] == 'stale_generation' }).to eq(1)
  end

  it 'captures a targeted one-shot sensitive submission without bulk disclosure' do
    callbacks = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'login', title: 'Login') do
      password = password_input(key: 'password')
      button(
        key: 'submit', label: 'Log in', submit: [password],
        on: {
          activate: lambda do |event|
            carrier = event.submission[event.submission.cids.first]
            callbacks << [event, carrier, carrier.consume(&:dup)]
          end,
        }
      )
    end)
    address, render = attach(first_connection, page)
    password_cid = render.dig('tree', 'children', 0, 'cid')
    button_cid = render.dig('tree', 'children', 1, 'cid')
    secret = +'canary-credential'
    message = {
      type: 'event', page: address, cid: button_cid, event: 'activate',
      generation: render['generation'], payload: {}, submission: [secret],
    }

    runtime.handle(first_connection, message)
    _callback, carrier, observed = callbacks.pop

    expect(carrier).to be_a(Lich::WebUI::SensitiveValue)
    expect(carrier.origin).to eq(:viewer)
    expect(message[:submission].first).to eq('')
    expect(render.to_s).not_to include('canary-credential')
    # 2.18 (D17): a submission does not empty the field on its own. The
    # script decides -- a wrong password re-prompts with what was typed
    # still there -- through clear_sensitive below.
    expect(first_connection.sent.map { |sent| sent['type'] }).not_to include('clear_sensitive')
    expect(observed).to eq('canary-credential')
    expect(carrier).to be_consumed

    runtime.clear_sensitive(page, password_cid)
    expect(first_connection.sent.last).to eq('type' => 'clear_sensitive', 'cids' => [password_cid])
  end

  # 2.18 (D17): a strength meter needs to know the password changed without
  # ever seeing it. The event reaches the script with an empty payload, no
  # submission, and empties nothing on screen.
  it 'delivers a payload-free password change to its binding without clearing the field' do
    callbacks = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'login', title: 'Login') do
      password_input(key: 'password', on: { change: ->(event) { callbacks << event } })
    end)
    address, render = attach(first_connection, page)
    password_cid = render.dig('tree', 'children', 0, 'cid')

    result = runtime.handle(first_connection, {
      type: 'event', page: address, cid: password_cid, event: 'change',
      generation: render['generation'], payload: {},
    })
    event = Timeout.timeout(2) { callbacks.pop }

    expect(result).to eq(:queued)
    expect(event.event).to eq(:change)
    expect(event.payload).to eq({})
    expect(event.submission.cids).to be_empty
    expect(first_connection.sent.map { |sent| sent['type'] }).not_to include('clear_sensitive')
  end

  it 'discards a sensitive submission when the enqueue itself overflows' do
    # The carrier is normally zeroed by an `ensure` inside the enqueued
    # block. When enqueue raises OverflowError the block is never stored, so
    # that ensure never runs -- the overflow path has to discard it itself.
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'login', title: 'Login') do
      password = password_input(key: 'password')
      button(key: 'submit', label: 'Log in', submit: [password], on: { activate: ->(_event) {} })
    end)
    address, render = attach(first_connection, page)
    button_cid = render.dig('tree', 'children', 1, 'cid')
    carriers = []
    allow(Lich::WebUI::SensitiveValue).to receive(:viewer).and_wrap_original do |original, *args|
      original.call(*args).tap { |carrier| carriers << carrier }
    end
    allow(dispatcher).to receive(:enqueue).and_raise(
      Lich::WebUI::Dispatcher::OverflowError.new(
        'WebUI event queue overflow', owner: 'login', page_id: page.id, cid: button_cid, field: 'activate'
      )
    )

    result = runtime.handle(first_connection, {
      type: 'event', page: address, cid: button_cid, event: 'activate',
      generation: render['generation'], payload: {}, submission: [+'canary-credential'],
    })

    expect(result).to eq(:refused)
    expect(first_connection.sent.last['reason']).to eq('overflow')
    expect(first_connection).to be_closed
    expect(carriers.length).to eq(1)
    expect(carriers.first).to be_consumed
  end

  it 'refuses attempts to widen or shorten the registered submission scope' do
    callbacks = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'login', title: 'Login') do
      name = text_input(key: 'name', value: '')
      button(key: 'submit', label: 'Go', submit: [name], on: { activate: ->(_event) { callbacks << true } })
    end)
    address, render = attach(first_connection, page)
    button_cid = render.dig('tree', 'children', 1, 'cid')

    result = runtime.handle(first_connection, {
      type: 'event', page: address, cid: button_cid, event: 'activate',
      generation: render['generation'], payload: {}, submission: [],
    })

    expect(result).to eq(:refused)
    expect(callbacks).to be_empty
    expect(first_connection.sent.last['reason']).to eq('submission_scope')
  end

  it 'removes pages and attachments when their owner terminates' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'page', title: 'Page') {})
    address, = attach(first_connection, page)

    expect(runtime.terminate_owner(owner)).to eq([page])
    expect { registry.fetch_address(address) }.to raise_error(Lich::WebUI::Error)
    expect { viewers.fetch(connection_id: first_connection.viewer_id, address: address) }
      .to raise_error(Lich::WebUI::Error)
  end

  it 'renders once and delivers the same generation to every attached viewer on refresh' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'shared', title: 'Shared') do
      text(content: 'updated')
    end)
    _address, = attach(first_connection, page)
    _address, = attach(second_connection, page)

    generation = runtime.refresh(page)

    expect(first_connection.sent.last['generation']).to eq(generation)
    expect(second_connection.sent.last['generation']).to eq(generation)
    expect(first_connection.sent.last['tree']).to eq(second_connection.sent.last['tree'])
  end

  it 'replaces logical composite popup page ids with opaque registered addresses only on delivery' do
    registry.register(Lich::WebUI::Page.new(owner: owner, id: 'detail', title: 'Detail') { text(content: 'detail') })
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'main', title: 'Main') do
      composite(width: 100, height: 100, layers: [], popup: { page: 'detail', size: [320, 240] })
    end)

    _address, render = attach(first_connection, page)
    delivered_popup = render.dig('tree', 'children', 0, 'props', 'popup')
    authored_popup = page.last_render.tree.children.first.props[:popup]

    expect(delivered_popup).to include('size' => [320, 240])
    expect(delivered_popup['page']).to match(/\Apage-[0-9a-f]{32}\z/)
    expect(delivered_popup['page']).not_to include('detail')
    expect(authored_popup).to eq(page: 'detail', size: [320, 240])
  end

  it 'resolves viewer-local reads to callback context and requires explicit context elsewhere' do
    observed = Queue.new
    page = nil
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'state', title: 'State') do
      input = text_input(key: 'name', value: '', on: { change: ->(_event) { observed << page.get(input.cid) } })
    end)
    address, render = attach(first_connection, page)
    input_cid = render.dig('tree', 'children', 0, 'cid')

    runtime.handle(first_connection, {
      type: 'event', page: address, cid: input_cid, event: 'change',
      generation: render['generation'], payload: { value: 'Alice' },
    })

    expect(observed.pop).to eq('Alice')
    expect { page.get(input_cid) }.to raise_error(Lich::WebUI::AmbiguousViewerError, /explicit viewer/)
    attachment = viewers.attachments_for(page).first
    expect(page.get(input_cid, viewer: attachment.viewer_id)).to eq('Alice')
  end

  it 'writes shared state asynchronously and delivers it without changing viewer drafts' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'shared', title: 'Shared') do
      text(key: 'status', content: 'before')
      text_input(key: 'draft', value: '')
    end)
    _address, render = attach(first_connection, page)
    status_cid = render.dig('tree', 'children', 0, 'cid')
    draft_cid = render.dig('tree', 'children', 1, 'cid')

    expect(page.set(status_cid, :content, 'after')).to be_nil
    Timeout.timeout(2) do
      sleep(0.001) until first_connection.sent.last.dig('tree', 'children', 0, 'props', 'content') == 'after'
    end

    expect(page.get(status_cid, :content)).to eq('after')
    expect { page.set(draft_cid, :value, 'ambiguous') }
      .to raise_error(Lich::WebUI::AmbiguousViewerError)
  end

  it 'schedules an authoritative render after accepted viewer-state events' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'tabs', title: 'Tabs') do
      tabs(names: %w[One Two], selected: 0, on: { select: proc {} }) do
        text(slot: 'One', content: 'one')
        text(slot: 'Two', content: 'two')
      end
    end)
    address, render = attach(first_connection, page)
    tabs_cid = render.dig('tree', 'children', 0, 'cid')

    runtime.handle(first_connection, {
      type: 'event', page: address, cid: tabs_cid, event: 'select',
      generation: render['generation'], payload: { index: 1 },
    })
    Timeout.timeout(2) do
      sleep(0.001) until first_connection.sent.last.dig('tree', 'children', 0, 'props', 'selected') == 1
    end

    expect(first_connection.sent.last.dig('tree', 'children', 0, 'props', 'selected')).to eq(1)
  end

  it 'refuses every server-side read and bulk write of sensitive values' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'secret', title: 'Secret') do
      password_input(key: 'password')
    end)
    _address, render = attach(first_connection, page)
    cid = render.dig('tree', 'children', 0, 'cid')

    expect { page.get(cid) }.to raise_error(Lich::WebUI::SensitiveReadError, /write-only/)
    expect { page.set(cid, :value, 'secret') }.to raise_error(Lich::WebUI::SensitiveReadError, /bulk state/)
  end

  it 'delivers attach, user close, and detach lifecycle callbacks in order' do
    lifecycle = Queue.new
    callbacks = %i[attach close detach].to_h do |event|
      [event, ->(context) { lifecycle << [context.event, context.payload] }]
    end
    page = registry.register(Lich::WebUI::Page.new(
      owner: owner, id: 'life', title: 'Life', on: callbacks
    ) {})
    address, render = attach(first_connection, page)
    runtime.handle(first_connection, {
      type: 'detach', page: address, generation: render['generation'],
    })

    expected = [[:attach, {}], [:close, { reason: :user }], [:detach, {}]]
    expect(3.times.map { lifecycle.pop }).to eq(expected)
  end

  it 'refuses events after disconnect and after page removal with distinct reasons' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'races', title: 'Races') do
      button(key: 'go', label: 'Go', on: { activate: proc {} })
    end)
    address, render = attach(first_connection, page)
    button_cid = render.dig('tree', 'children', 0, 'cid')
    message = {
      type: 'event', page: address, cid: button_cid, event: 'activate',
      generation: render['generation'], payload: {},
    }

    runtime.disconnect(first_connection)
    expect(runtime.handle(first_connection, message)).to eq(:refused)
    expect(first_connection.sent.last['reason']).to eq('viewer_gone')

    registry.unregister(owner, page.id)
    expect(runtime.handle(first_connection, message)).to eq(:refused)
    expect(first_connection.sent.last['reason']).to eq('page_gone')
  end

  it 'allows an active callback to finish before owner teardown removes its page' do
    entered = Queue.new
    release = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'ending', title: 'Ending') do
      button(key: 'go', label: 'Go', on: { activate: ->(_event) { entered << true; release.pop } })
    end)
    address, render = attach(first_connection, page)
    button_cid = render.dig('tree', 'children', 0, 'cid')
    runtime.handle(first_connection, {
      type: 'event', page: address, cid: button_cid, event: 'activate',
      generation: render['generation'], payload: {},
    })
    entered.pop
    teardown = Thread.new { runtime.terminate_owner(owner) }

    expect(registry.fetch_address(address)).to equal(page)
    release << true
    teardown.join
    expect { registry.fetch_address(address) }.to raise_error(Lich::WebUI::Error)
    expect(first_connection.sent.last).to include('type' => 'page_closed', 'reason' => 'owner')
  end

  it 'refuses image resources that do not resolve through a registered served root' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'image', title: 'Image') do
      image(src: 'https://example.com/hostile.png')
    end)

    expect(runtime.handle(first_connection, {
      type: 'attach', page: registry.address_for(page), version: '2.5.0',
    })).to eq(:refused)
    expect(first_connection.sent.last['reason']).to eq('contract')
  end

  # A Cairo-drawn marker has no file to serve, so the shim inlines it as a
  # base64 data: URI. The CSP already allows those; the render validator did
  # not, and refused the whole map the moment its room marker appeared.
  it 'accepts a base64 data image, which references no served resource' do
    pixel = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'marker', title: 'Marker') do
      image(src: pixel)
    end)

    expect(runtime.handle(first_connection, {
      type: 'attach', page: registry.address_for(page), version: '2.5.0',
    })).to eq(:attached)
  end

  # Gtk::Image.new with no source, or one that was cleared, has nothing to
  # show and emits an empty src so the layout keeps its place. The render
  # validator treated that as an unregistered file and refused the whole
  # page: one blank widget, and the window never opened.
  it 'accepts an image with an empty src as one with nothing to show' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'blank', title: 'Blank') do
      image(src: '', alt: 'no image')
      button(key: 'go', label: 'Go')
    end)

    expect(runtime.handle(first_connection, {
      type: 'attach', page: registry.address_for(page), version: '2.5.0',
    })).to eq(:attached)
    render = first_connection.sent.last
    expect(render['type']).to eq('render')
    expect(render.dig('tree', 'children', 0, 'props')).to include('src' => '', 'alt' => 'no image')
  end

  # Composite layers used to be an image-only affair: every layer was a PNG
  # and each was rasterised, PNG-encoded and shipped inline under a size
  # cap. Shapes are data; they reference nothing and need no source check.
  it 'accepts a composite of drawn shapes, which reference no served resource' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'marks', title: 'Marks') do
      composite(key: 'surface', width: 100, height: 100, layers: [
                  { kind: 'ellipse', x: 10, y: 10, w: 20, h: 20, stroke: { r: 255, g: 0, b: 0, a: 0.8 }, stroke_width: 3 },
                  { kind: 'rect', x: 40, y: 40, w: 30, h: 20, stroke: { tone: 'danger' } },
                  { kind: 'line', x1: 0, y1: 0, x2: 99, y2: 99, stroke: { r: 0, g: 200, b: 0, a: 1.0 }, stroke_width: 2 },
                  { kind: 'line', x1: 99, y1: 0, x2: 0, y2: 99, stroke: { r: 0, g: 200, b: 0, a: 1.0 }, stroke_width: 2 },
                ])
    end)

    expect(runtime.handle(first_connection, {
      type: 'attach', page: registry.address_for(page), version: '2.5.0',
    })).to eq(:attached)
    layers = first_connection.sent.last.dig('tree', 'children', 0, 'props', 'layers')
    expect(layers.map { |layer| layer['kind'] }).to eq(%w[ellipse rect line line])
    expect(layers.first).to include('stroke_width' => 3, 'opacity' => 1.0)
  end

  it 'still refuses a data URI that is not a base64 image' do
    [
      'data:text/html;base64,PHNjcmlwdD4=',
      'data:image/svg+xml;base64,PHN2Zy8+',
      'data:image/png;base64,not valid base64!',
      # Base64 comes in quads: a body whose length is not a multiple of
      # four is not base64 at all, whatever characters it uses.
      'data:image/png;base64,iVBOR',
      'data:image/png;base64,iVBORw=',
      'data:image/png;base64,iVBO===',
    ].each do |hostile|
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: "bad-#{hostile.hash.abs}", title: 'Bad') do
        image(src: hostile)
      end)

      expect(runtime.handle(first_connection, {
        type: 'attach', page: registry.address_for(page), version: '2.5.0',
      })).to eq(:refused), "expected #{hostile.inspect} to be refused"
    end
  end

  # The per-page refresh lock was created on first refresh and never released,
  # so every page a long-lived session ever opened stayed reachable through
  # @page_locks -- the page, its tree and its owner with it. @refresh_state
  # was already cleaned up on the same paths; this was the one that was not.
  describe 'per-page refresh state' do
    def page_locks
      runtime.instance_variable_get(:@page_locks)
    end

    # A refresh thread parked in a write to a browser that stopped reading
    # held shutdown for as long as the write did; the join is budgeted now.
    it 'shuts down within its budget even when a refresh thread never returns' do
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'stuck', title: 'Stuck') do
        text(content: 'stuck')
      end)
      parked = Thread.new { sleep }
      sleep 0.01 until parked.status == 'sleep'
      runtime.instance_variable_get(:@refresh_state)[page] = { dirty: false, thread: parked }

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      runtime.shutdown(budget: 0.2)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(elapsed).to be < 2.0
      expect(parked.join(1)).not_to be_nil
      expect(parked).not_to be_alive
    end

    it 'releases the refresh lock of a closed page' do
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'closing', title: 'Closing') do
        text(content: 'bye')
      end)
      attach(first_connection, page)
      runtime.refresh(page)

      expect(page_locks.keys).to include(page)

      runtime.close_page(page)

      expect(page_locks.keys).not_to include(page)
    end

    it 'releases every lock the owner held when the owner terminates' do
      pages = %w[one two].map do |id|
        registry.register(Lich::WebUI::Page.new(owner: owner, id: id, title: id) { text(content: id) })
      end
      pages.each { |page| attach(first_connection, page) }
      pages.each { |page| runtime.refresh(page) }

      expect(page_locks.keys).to include(*pages)

      runtime.terminate_owner(owner)

      expect(page_locks.keys).to be_empty
    end
  end

  # refresh held a per-page lock across render and delivery; attach rendered
  # and delivered outside it. The attachment is visible in ViewerStore before
  # its first render lands, so a concurrent refresh could deliver generation 2
  # and attach then overwrite it with 1.
  it 'delivers the first render under the same lock refresh uses' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'ordering', title: 'Ordering') do
      text(content: 'hi')
    end)
    held = Queue.new
    observed = Queue.new
    allow(runtime).to receive(:send_render).and_wrap_original do |original, *args|
      observed << args.last
      original.call(*args)
    end

    # Refresh cannot interleave: it must wait for the whole attach.
    attacher = Thread.new { attach(first_connection, page); held << :done }
    refresher = Thread.new { runtime.refresh(page) }
    [attacher, refresher].each { |thread| thread.join(5) }

    expect(held.pop).to eq(:done)
    generations = first_connection.sent.filter_map { |m| m['generation'] }
    expect(generations).to eq(generations.sort)
  end
end
