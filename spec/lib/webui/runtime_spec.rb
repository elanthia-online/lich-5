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

  [
    ['accepted proposal', ['b'], ['b'], nil, 0, ['b']],
    ['no-op proposal', ['a'], ['a'], nil, 0, ['a']],
    ['veto', ['b'], ['a'], nil, 1, ['a']],
    ['modified proposal', ['a'], ['b'], nil, 1, ['b']],
    ['guard failure', ['b'], ['b'], :guard, 1, ['a']],
    ['validation failure', ['b'], ['missing'], nil, 1, ['a']],
    ['update failure', ['b'], ['b'], :update, 1, ['a']],
    ['callback failure', ['b'], ['b'], :callback, 1, ['b']],
  ].each do |name, requested, decision, failure, refresh_count, final_rows|
    it "PR63 refreshes guarded selection appropriately after #{name}" do
      refreshes, calls = [], []
      allow(runtime).to receive(:schedule_refresh) { |page| refreshes << page.id }
      allow(viewers).to receive(:update).and_raise(Lich::WebUI::Error, 'update failure') if failure == :update
      callback = proc do |context|
        calls << context.payload[:rows]
        raise 'changed callback failure' if failure == :callback
      end
      callback.define_singleton_method(:prepare_selection) do |_context|
        raise 'guard failure' if failure == :guard
        { rows: decision }
      end
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'guard-refresh', title: 'Guard refresh') do
        table(key: 'choices', columns: [{ key: 'name', label: 'Name' }],
              rows: [{ key: 'a', cells: { name: 'A' } }, { key: 'b', cells: { name: 'B' } }],
              selection: :single, selected: ['a'], on: { selection_change: callback })
      end)
      address, frame = attach(first_connection, page)
      component = page.last_render.tree.children.first
      refreshes.clear
      runtime.handle(first_connection, type: 'event', page: address, generation: frame['generation'],
                     cid: component.cid, event: 'selection_change', payload: { rows: requested })
      finished = Queue.new
      runtime.dispatch(owner: owner) { finished << true }
      expect(finished.pop(timeout: 2)).to be(true)
      viewer = viewers.attachments_for(page).first
      expect(viewers.property(viewer, component, :selected)).to eq(final_rows)
      expect(refreshes.length).to eq(refresh_count)
      expect(calls).to eq(final_rows == ['a'] ? [] : [final_rows])
    end
  end

  it 'PR63 retains callback-authored refreshes without adding a redundant selection repaint' do
    refreshes = []
    allow(runtime).to receive(:schedule_refresh) { |page| refreshes << page.id }
    callback = proc do |context|
      status = context.page.last_render.tree.children.find { |node| node.type == :text }
      context.page.set(status.cid, :content, 'Changed')
    end
    callback.define_singleton_method(:prepare_selection) { |context| context.payload }
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'guard-mutation', title: 'Guard mutation') do
      table(key: 'choices', columns: [{ key: 'name', label: 'Name' }],
            rows: [{ key: 'a', cells: { name: 'A' } }, { key: 'b', cells: { name: 'B' } }],
            selection: :single, selected: ['a'], on: { selection_change: callback })
      text(key: 'status', content: 'Initial')
    end)
    address, frame = attach(first_connection, page)
    component = page.last_render.tree.children.first
    refreshes.clear
    runtime.handle(first_connection, type: 'event', page: address, generation: frame['generation'],
                   cid: component.cid, event: 'selection_change', payload: { rows: ['b'] })
    finished = Queue.new
    runtime.dispatch(owner: owner) { finished << true }
    expect(finished.pop(timeout: 2)).to be(true)
    expect(refreshes).to eq(['guard-mutation'])
    expect(page.last_render.tree.children.last.then { |node| page.get(node.cid, :content) }).to eq('Changed')
  end

  it 'commits only validated guarded selections on the owner worker and retains state after guard failures' do
    calls = Queue.new
    seen = []
    decision = ['b']
    store = viewers
    callback = proc { |context| calls << context.payload[:rows] }
    callback.define_singleton_method(:prepare_selection) do |context|
      attachment = store.attachment_for_viewer(context.page, context.viewer_id)
      seen << store.property(attachment, context.component, :selected)
      raise 'guard failure' if decision == :raise
      { rows: decision }
    end
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'guarded', title: 'Guarded') do
      table(key: 'choices', columns: [{ key: 'name', label: 'Name' }],
            rows: [{ key: 'a', cells: { name: 'A' } }, { key: 'b', cells: { name: 'B' } }],
            selection: :single, selected: ['a'], on: { selection_change: callback })
    end)
    address, _frame = attach(first_connection, page)
    component = page.last_render.tree.children.first
    viewer = viewers.attachments_for(page).first
    submit = lambda do |rows|
      latest = first_connection.sent.reverse.find { |message| message['type'] == 'render' }
      runtime.handle(first_connection, type: 'event', page: address, generation: latest['generation'],
                     cid: component.cid, event: 'selection_change', payload: { rows: rows })
    end
    barrier = lambda do
      finished = Queue.new
      runtime.dispatch(owner: owner) { finished << true }
      expect(finished.pop(timeout: 2)).to be(true)
    end
    expect(submit.call(['b'])).to eq(:queued)
    barrier.call
    expect(calls.pop(timeout: 2)).to eq(['b'])
    expect(seen).to eq([['a']])
    expect(viewers.property(viewer, component, :selected)).to eq(['b'])
    decision = ['missing']
    submit.call(['a'])
    barrier.call
    expect(viewers.property(viewer, component, :selected)).to eq(['b'])
    decision = :raise
    submit.call(['a'])
    barrier.call
    expect(viewers.property(viewer, component, :selected)).to eq(['b'])
    expect(calls).to be_empty
  end

  it 'refuses events through disabled ancestors or a hidden window and accepts them after restoration' do
    received = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'disabled', title: 'Disabled') do
      stack(key: 'parent', disabled: true) do
        button(key: 'go', label: 'Go', on: { activate: ->(_) { received << true } })
      end
    end)
    address, frame = attach(first_connection, page)
    parent = frame['tree']['children'].first
    button = parent['children'].first
    submit = lambda do
      frame = first_connection.sent.reverse.find { |message| message['type'] == 'render' }
      runtime.handle(first_connection, type: 'event', page: address, generation: frame['generation'],
                     cid: button['cid'], event: 'activate', payload: {})
    end
    expect(submit.call).to eq(:refused)
    expect(received).to be_empty
    page.set(parent['cid'], :disabled, false)
    runtime.refresh(page)
    expect(submit.call).to eq(:queued)
    expect(received.pop(timeout: 2)).to be(true)
    page.set(page.last_render.tree.cid, :presentation, { hidden: true })
    runtime.refresh(page)
    expect(submit.call).to eq(:refused)
    page.set(page.last_render.tree.cid, :presentation, { hidden: false })
    runtime.refresh(page)
    expect(submit.call).to eq(:queued)
    expect(received.pop(timeout: 2)).to be(true)
  end

  it 'delivers lifecycle callbacks through disabled ancestors and a hidden page' do
    received = Queue.new
    callback = ->(event) { received << event.event }
    page = Lich::WebUI::Page.new(owner: owner, id: 'lifecycle', title: 'Lifecycle',
                                 props: { presentation: { hidden: true }, disabled: true }) do
      group(key: 'menu', menu: :context, on: { dismiss: callback }) {}
      text_input(key: 'field', value: '', on: { focus: callback, change: callback })
      textarea(key: 'notes', value: 'Retained', on: { blur: callback })
      group(key: 'surface', pointer_events: true, on: { pointer_press: callback }) {}
    end
    registry.register(page)
    address, frame = attach(first_connection, page)
    payloads = [[:dismiss, {}], [:focus, {}], [:blur, { value: 'Retained' }],
                [:pointer_press, { x: 1, y: 2, button: 1, time: 0, state: 0 }]]
    frame['tree']['children'].zip(payloads).each do |node, (event, payload)|
      expect(runtime.handle(first_connection, type: 'event', page: address, generation: frame['generation'],
                            cid: node['cid'], event: event.to_s, payload: payload)).to eq(:queued)
      expect(received.pop(timeout: 2)).to eq(event)
    end
    expect(runtime.handle(first_connection, type: 'event', page: address, generation: frame['generation'],
                          cid: frame['tree']['children'][1]['cid'], event: 'change', payload: { value: 'Forged' })).to eq(:refused)
  end

  it 'acknowledges validated text input only to its originating viewer' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'search', title: 'Search') do
      text_input(key: 'query', value: '', change_mode: :input, on: { change: proc {} })
    end)
    address, frame = attach(first_connection, page)
    attach(second_connection, page)
    # Use the latest delivered generation for this viewer, independent of its peer.
    input = frame['tree']['children'].first
    expect(runtime.handle(first_connection, type: 'event', page: address, generation: frame['generation'],
                          cid: input['cid'], event: 'change', payload: { value: 'Dreaven' }, request: 7)).to eq(:queued)
    runtime.refresh(page)
    expect(first_connection.sent.last['input_requests']).to eq(input['cid'] => 7)
    expect(second_connection.sent.last['input_requests']).to be_empty
    frame = first_connection.sent.last
    expect(runtime.handle(first_connection, type: 'event', page: address, generation: frame['generation'],
                          cid: input['cid'], event: 'change', payload: { value: 123 }, request: 8)).to eq(:refused)
    runtime.refresh(page)
    expect(first_connection.sent.last['input_requests']).to eq(input['cid'] => 7)
  end

  %i[text_input textarea].each do |kind|
    it "accepts delivered read-only #{kind} while preserving a newer server value and refusing forgeries" do
      received = Queue.new
      allow(runtime).to receive(:schedule_render)
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'readonly', title: 'Read only') do
        input = public_send(kind, key: 'text', value: 'Default', read_only: true)
        button(key: 'save', label: 'Save', submit: [input], on: {
          activate: ->(event) { received << event.submission[event.submission.cids.first] },
        })
      end)
      address, = attach(first_connection, page)
      attach(second_connection, page)
      first = viewers.fetch(connection_id: first_connection.viewer_id, address: address)
      second = viewers.fetch(connection_id: second_connection.viewer_id, address: address)
      input, button = page.last_render.tree.children
      page.set(input.cid, :value, 'Delivered override', viewer: first.viewer_id)
      runtime.refresh(page)
      render = first_connection.sent.last

      # Hold refresh scheduling so Save deterministically arrives after the server
      # write but before delivery. The authored default is not the wire value.
      page.set(input.cid, :value, 'Newest server value', viewer: first.viewer_id)
      viewers.snapshot(first) # Lifecycle capture must not rewrite delivery evidence.
      submit = lambda do |value|
        runtime.handle(first_connection, type: 'event', page: address, generation: render['generation'],
                       cid: button.cid, event: 'activate', payload: {}, submission: [value])
      end
      expect(submit.call('Default')).to eq(:refused)
      expect(submit.call('Forged')).to eq(:refused)
      expect(submit.call('Newest server value')).to eq(:refused)
      expect(submit.call('Delivered override')).to eq(:queued)
      expect(received.pop(timeout: 2)).to eq('Newest server value')
      expect(viewers.property(first, input, :value)).to eq('Newest server value')
      expect(viewers.property(second, input, :value)).to eq('Default')

      runtime.refresh(page)
      render = first_connection.sent.last
      expect(submit.call('Delivered override')).to eq(:refused)
      expect(submit.call('Newest server value')).to eq(:queued)
      expect(received.pop(timeout: 2)).to eq('Newest server value')
      runtime.handle(first_connection, type: 'detach', page: address)
      expect(first.delivered_read_only).to be_empty
    end
  end

  { 'CRLF' => "\r\n", 'lone CR' => "\r" }.each do |label, line_break|
    it "accepts browser-normalized #{label} text without changing server text or accepting edits" do
      received = Queue.new
      original = "First#{line_break}Second#{line_break}"
      allow(runtime).to receive(:schedule_render)
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'line-breaks', title: 'Read only') do
        input = textarea(key: 'text', value: original, read_only: true)
        button(key: 'save', label: 'Save', submit: [input], on: {
          activate: ->(event) { received << event.submission[event.submission.cids.first] },
        })
      end)
      address, render = attach(first_connection, page)
      attachment = viewers.fetch(connection_id: first_connection.viewer_id, address: address)
      input, button = page.last_render.tree.children
      submit = lambda do |text|
        runtime.handle(first_connection, type: 'event', page: address, generation: render['generation'],
                       cid: button.cid, event: 'activate', payload: {}, submission: [text])
      end
      # textarea.value sends LF even when its assigned server text contains CR.
      # Comparison may normalize that representation; storage and callbacks must not.
      expect(submit.call("First\nChanged\n")).to eq(:refused)
      expect(received).to be_empty
      expect(submit.call("First\nSecond\n")).to eq(:queued)
      expect(received.pop(timeout: 2)).to eq(original)
      expect(viewers.property(attachment, input, :value)).to eq(original)
      expect(attachment.delivered_read_only[input.cid]).to eq(original)

      latest = "New#{line_break}server text"
      page.set(input.cid, :value, latest, viewer: attachment.viewer_id)
      expect(submit.call("First\nSecond\n")).to eq(:queued)
      expect(received.pop(timeout: 2)).to eq(latest)
      expect(viewers.property(attachment, input, :value)).to eq(latest)
      expect(attachment.delivered_read_only[input.cid]).to eq(original)
      runtime.refresh(page)
      render = first_connection.sent.last
      expect(submit.call("First\nSecond\n")).to eq(:refused)
      expect(submit.call("New\nserver text")).to eq(:queued)
      expect(received.pop(timeout: 2)).to eq(latest)
    end
  end

  it 'continues seeding after stale targets and attributed invalid properties without reviving departed viewers' do
    warnings = []
    host = described_class.new(registry: registry, dispatcher: dispatcher, viewers: viewers,
                               logger: ->(level, message) { warnings << [level, message] })
    allow(host).to receive(:schedule_render)
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'seeds', title: 'Seeds') do
      textarea(key: 'text', value: 'Default')
    end)
    address = registry.address_for(page)
    host.handle(first_connection, type: 'attach', page: address)
    live = viewers.fetch(connection_id: first_connection.viewer_id, address: address)
    input = page.last_render.tree.children.first
    undelivered = viewers.attach(connection_id: 'waiting', address: address, page: page)
    departed = viewers.attach(connection_id: 'gone', address: address, page: page)
    viewers.deliver(departed, page.last_render)
    viewers.close(connection_id: 'gone', address: address)
    changes = [
      [undelivered.viewer_id, input.cid, :value, 'Not delivered'],
      [departed.viewer_id, input.cid, :value, 'Departed'],
      [live.viewer_id, 'removed-cid', :value, 'Stale'],
      [live.viewer_id, input.cid, :read_only, true],
      [live.viewer_id, input.cid, :missing, true],
      [live.viewer_id, input.cid, :value, Object.new],
      [live.viewer_id, input.cid, :value, 'Accepted'],
    ]
    expect { host.seed_viewer_properties(page, changes) }.not_to raise_error
    expect(viewers.property(live, input, :value)).to eq('Accepted')
    expect(undelivered.values).to be_empty
    expect(departed.values).to be_empty
    expect(warnings.length).to eq(3)
    expect(warnings).to all(satisfy { |level, message| level == :warning && message.include?('page=seeds') && message.include?("cid=#{input.cid}") })
    expect(host).to have_received(:schedule_render).with(page, owner: owner, delay: 0)
  end

  it 'queues every detach before notifying each distinct owner once' do
    owner_class = Struct.new(:name)
    first_owner = owner_class.new('same-name')
    second_owner = owner_class.new('same-name')
    queued, notifications = [], []
    completed = Queue.new
    host = described_class.new(registry: registry, dispatcher: dispatcher, viewers: viewers,
                               viewers_changed: ->(owner) { notifications << [owner.object_id, queued.dup] })
    allow(dispatcher).to receive(:enqueue).and_wrap_original do |original, **options, &work|
      queued << options[:page_id] if options[:event] == :detach
      original.call(**options, &work)
    end
    [first_owner, first_owner, second_owner].each_with_index do |page_owner, index|
      id = "page-#{index}"
      page = registry.register(Lich::WebUI::Page.new(owner: page_owner, id: id, title: 'Fixture',
                                                     on: { detach: ->(_event) { completed << id } }) {})
      host.handle(first_connection, type: 'attach', page: registry.address_for(page), version: Lich::WebUI::Contract::VERSION)
    end

    host.disconnect(first_connection)

    page_ids = %w[page-0 page-1 page-2]
    expect(notifications).to eq([[first_owner.object_id, page_ids], [second_owner.object_id, page_ids]])
    expect(Timeout.timeout(2) { Array.new(3) { completed.pop } }).to match_array(page_ids)
  end

  %i[shutdown refusal overflow].each do |termination|
    it "disposes a sensitive submission on #{termination} before its callback runs" do
      captured = []
      allow(Lich::WebUI::SensitiveValue).to receive(:viewer).and_wrap_original do |original, value|
        original.call(value).tap { |carrier| captured << carrier }
      end
      started = Queue.new
      release = Queue.new
      callbacks = []
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'cleanup', title: 'Cleanup') do
        password = password_input(key: 'password')
        button(key: 'save', label: 'Save', submit: [password], on: { activate: ->(_event) { callbacks << true } })
      end)
      address, render = attach(first_connection, page)
      dispatcher.enqueue(owner: owner, page_id: page.id, viewer_id: 'blocker', cid: 'blocker', event: :activate,
                         coalescable: false) do
        started << true
        release.pop
        dispatcher.shutdown_owner(owner) if termination == :shutdown
      end
      started.pop
      if termination != :shutdown
        error = termination == :overflow ? Lich::WebUI::Dispatcher::OverflowError : Lich::WebUI::Error
        allow(dispatcher).to receive(:enqueue).and_raise(error, 'refused')
      end
      runtime.handle(first_connection, type: 'event', page: address, cid: render.dig('tree', 'children', 1, 'cid'),
                     event: 'activate', generation: render['generation'], payload: {}, submission: [+'synthetic-secret'])
      release << true
      Timeout.timeout(2) { Thread.pass until captured.first&.consumed? }
      expect(captured.size).to eq(1)
      expect(callbacks).to be_empty
    ensure
      release << true if release
    end
  end

  it 'permits spell-list transfers only between declared peers with an existing source row' do
    calls = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'spells', title: 'Spells') do
      table(key: 'available', transfer_group: 'spells', columns: [{ key: 'name', label: 'Spell' }],
            rows: [{ key: '101', cells: { 'name' => 'Spirit Warding I' } }])
      table(key: 'cast', transfer_group: 'spells', columns: [{ key: 'name', label: 'Spell' }], rows: [],
            on: { row_drop: proc { |event| calls << event.payload } })
      table(key: 'unrelated', transfer_group: 'other', columns: [{ key: 'name', label: 'Other' }],
            rows: [{ key: 'secret', cells: { 'name' => 'Unrelated row' } }])
    end)
    address, render = attach(first_connection, page)
    trees = page.last_render.tree.children.to_h { |child| [child.props[:key], child.cid] }
    drop = proc do |source, row|
      runtime.handle(first_connection, type: 'event', page: address, generation: render.fetch('generation'),
                     cid: trees.fetch('cast'), event: 'row_drop', payload: { source: trees.fetch(source), row: row })
    end
    drop.call('unrelated', 'secret')
    drop.call('available', 'missing')
    expect(calls).to be_empty
    drop.call('available', '101')
    expect(Timeout.timeout(2) { calls.pop }).to eq(source: trees.fetch('available'), row: '101')
  end

  it 'counts connected viewers only for the requested owner' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'map', title: 'Map') {})
    other_owner = Object.new
    expect(runtime.viewers_present?(owner)).to be false
    attach(first_connection, page)
    expect(runtime.viewers_present?(owner)).to be true
    expect(runtime.viewers_present?(other_owner)).to be false
    runtime.disconnect(first_connection)
    expect(runtime.viewers_present?(owner)).to be false
  end

  [true, false].each do |process_first|
    it "settles retained-page modal policies after native close with process_first=#{process_first}" do
      coordinator = nil
      notifications, enqueued = [], []
      host = described_class.new(registry: registry, dispatcher: dispatcher, viewers: viewers,
                                 viewers_changed: lambda { |who|
                                   notifications << enqueued.dup
                                   coordinator.viewers_changed(who)
                                 })
      coordinator = Lich::WebUI::ModalCoordinator.new(
        registry: registry, runtime: host, viewers_present: host.method(:viewers_present?), pages_changed: -> {}
      )
      allow(dispatcher).to receive(:enqueue).and_wrap_original do |original, **options, &work|
        original.call(**options, &work).tap { enqueued << options[:event] }
      end
      calls = Queue.new
      page = registry.register(Lich::WebUI::Page.new(
        owner: owner, id: 'retained', title: 'Retained', on: { close: ->(_event) { calls << :closed } }
      ) { text(key: 'body', content: 'Retained page') })
      address = registry.address_for(page)
      host.handle(first_connection, type: 'attach', page: address)
      viewer = viewers.attachments_for(page).first.viewer_id
      page.observe_monitors(viewer, { source: 'browser', screens: [] })
      host.watch_window(page)
      buttons = [{ id: 'ok', label: 'OK' }]
      aborted = coordinator.open(owner: owner, id: 'abort', title: 'Abort', buttons: buttons, no_viewer: :abort)
      defaulted = coordinator.open(owner: owner, id: 'default', title: 'Default', buttons: buttons,
                                   no_viewer: :default, default_button: 'ok')
      expect(aborted).not_to be_resolved
      expect(defaulted).not_to be_resolved

      host.disconnect(first_connection) unless process_first
      expect(host.browser_closed(page)).to eq(:queued)
      host.disconnect(first_connection) if process_first

      expect(calls.pop(timeout: 2)).to eq(:closed)
      expect(registry.address_for(page)).to eq(address)
      expect(host.viewers_present?(owner)).to be(false)
      expect(page.monitor_snapshot(viewer)).to be_nil
      expect(notifications.first).to include(:close) if process_first
      expect(aborted).to be_resolved
      expect(defaulted).to be_resolved
      expect(aborted.await).to have_attributes(reason: :no_viewer, button: nil)
      expect(defaulted.await).to have_attributes(reason: :no_viewer, button: 'ok')
      notification_count = notifications.length
      expect(host.browser_closed(page)).to be_nil
      expect(notifications.length).to eq(notification_count)
      expect(calls).to be_empty
    ensure
      coordinator&.shutdown
      host&.shutdown
    end
  end

  %i[shutdown overflow].each do |refusal|
    it "cleans up a retired native viewer when close dispatch is refused by #{refusal}" do
      notifications = []
      host = described_class.new(registry: registry, dispatcher: dispatcher, viewers: viewers,
                                 viewers_changed: ->(who) { notifications << who })
      callback = double('close callback')
      expect(callback).not_to receive(:call)
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'refused-close', title: 'Close',
                                                     on: { close: callback }) {})
      host.handle(first_connection, type: 'attach', page: registry.address_for(page))
      viewer = viewers.attachments_for(page).first.viewer_id
      page.observe_monitors(viewer, { source: 'browser', screens: [] })
      host.watch_window(page)
      if refusal == :shutdown
        dispatcher.shutdown_owner(owner)
      else
        allow(dispatcher).to receive(:enqueue).and_raise(Lich::WebUI::Dispatcher::OverflowError, 'queue is full')
      end

      expect(host.browser_closed(page)).to be_nil
      expect(page.monitor_snapshot(viewer)).to be_nil
      expect(notifications).to eq([owner])
      host.disconnect(first_connection)
      expect(host.browser_closed(page)).to be_nil
      expect(notifications).to eq([owner])
    ensure
      host&.shutdown
    end
  end

  it 'preserves monitor data and viewer availability when native close cannot identify one viewer' do
    notifications = []
    host = described_class.new(registry: registry, dispatcher: dispatcher, viewers: viewers,
                               viewers_changed: ->(who) { notifications << who })
    calls = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'shared-close', title: 'Close',
                                                   on: { close: ->(_event) { calls << :closed } }) {})
    [first_connection, second_connection].each do |connection|
      host.handle(connection, type: 'attach', page: registry.address_for(page))
    end
    attached = viewers.attachments_for(page)
    attached.each { |viewer| page.observe_monitors(viewer.viewer_id, { source: 'browser', screens: [] }) }
    host.watch_window(page)

    expect(host.browser_closed(page)).to eq(:queued)
    expect(calls.pop(timeout: 2)).to eq(:closed)
    expect(viewers.attachments_for(page)).to match_array(attached)
    attached.each { |viewer| expect(page.monitor_snapshot(viewer.viewer_id)).not_to be_nil }
    expect(notifications).to be_empty
  ensure
    host&.shutdown
  end

  it 'delivers detach even when the close callback immediately unregisters the page' do
    callbacks = []
    # Execute on enqueue to deterministically expose the real worker race.
    allow(dispatcher).to receive(:enqueue) { |**_, &callback| callback.call }
    page = nil
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'closing', title: 'Closing', on: {
      close: proc { runtime.close_page(page); callbacks << :close },
      detach: proc { callbacks << :detach }
    }) {})
    address, render = attach(first_connection, page)

    expect(runtime.handle(first_connection, type: 'detach', page: address, generation: render['generation'])).to eq(:detached)
    expect(callbacks).to eq(%i[close detach])
    expect(registry.size).to eq(0)
  end

  it 'keeps close callback reads available after detaching and disposes them afterwards' do
    queued = []
    allow(dispatcher).to receive(:enqueue) do |**options, &callback|
      queued << Lich::WebUI::WorkItem.new(cleanup: options[:cleanup], &callback)
    end
    observed = []
    page = nil
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'save-close', title: 'Save', on: {
      close: proc { |event| observed << page.get('page:save-close/text_input:name', viewer: event.viewer_id) }
    }) { text_input(key: 'name', value: 'old', on: { change: proc {} }) })
    address, render = attach(first_connection, page)
    runtime.handle(first_connection, type: 'event', page: address, generation: render['generation'],
                                     cid: 'page:save-close/text_input:name', event: 'change', payload: { value: 'edited' })
    runtime.handle(first_connection, type: 'detach', page: address, generation: render['generation'])
    expect(runtime.viewers_present?(owner)).to be false
    queued.each(&:call)
    expect(observed).to eq(['edited'])
    expect { page.get('page:save-close/text_input:name', viewer: 'connection-one') }.to raise_error(Lich::WebUI::Error)
  end

  it 'disposes a closing snapshot if owner shutdown cancels its callback' do
    entered = Queue.new
    release = Queue.new
    snapshots = []
    allow(viewers).to receive(:snapshot).and_wrap_original do |original, *args, **options|
      original.call(*args, **options).tap { |snapshot| snapshots << snapshot }
    end
    callback = double('close callback')
    expect(callback).not_to receive(:call)
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'cancel-close', title: 'Cancel', on: { close: callback }) do
      text_input(key: 'name', value: 'draft')
    end)
    address, render = attach(first_connection, page)
    dispatcher.enqueue(owner: owner, page_id: page.id, viewer_id: 'busy', cid: 'busy', event: :activate, coalescable: false) do
      entered << true
      release.pop
    end
    Timeout.timeout(2) { entered.pop }
    runtime.handle(first_connection, type: 'detach', page: address, generation: render['generation'])
    closing = snapshots.last
    expect(closing.values).not_to be_empty
    shutdown = Thread.new { dispatcher.shutdown_owner(owner) }
    Timeout.timeout(2) { sleep 0.001 until closing.values.empty? }
    release << true
    shutdown.join
    expect(closing.values).to be_empty
  ensure
    release << true
    shutdown&.join(2)
  end

  it 'does not retain a page when an in-flight render finishes after close' do
    entered = Queue.new
    release = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'retention', title: 'Retention') do
      entered << true
      release.pop
      text(content: 'late')
    end)
    worker = Thread.new { runtime.refresh(page) rescue Lich::WebUI::Error }
    Timeout.timeout(2) { entered.pop }
    runtime.close_page(page)
    release << true
    expect(worker.join(2)).to equal(worker)
    expect(runtime.instance_variable_get(:@degradations)).not_to have_key(page)
  ensure
    release << true
    worker&.join(2)
  end

  it 'discards a queued refresh after close without refreshing a replacement page' do
    entered, release = Queue.new, Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'close-refresh', title: 'Old') do
      text(content: 'old')
    end)
    allow(runtime).to receive(:log)
    allow(runtime).to receive(:refresh).and_wrap_original do |original, target|
      entered << Thread.current
      release.pop
      original.call(target)
    end
    runtime.send(:schedule_refresh, page)
    worker = Timeout.timeout(2) { entered.pop }
    coordinator = runtime.instance_variable_get(:@render_coordinator)
    expect(runtime.close_page(page)).to equal(page)
    replacement = registry.register(Lich::WebUI::Page.new(owner: owner, id: page.id, title: 'New') do
      text(content: 'new')
    end)
    release << true
    expect(worker.join(2)).to equal(worker)
    expect(runtime).not_to have_received(:log)
    expect(replacement.last_render).to be_nil
    expect(coordinator.instance_variable_get(:@refresh_state)).not_to have_key(page)
    allow(runtime).to receive(:refresh).and_call_original
    expect { runtime.refresh(page) }.to raise_error(Lich::WebUI::Error, /not registered/)
    expect { runtime.refresh(replacement) }.not_to raise_error
  ensure
    release << true
    worker&.join(2)
  end

  it 'still reports scheduled refresh failures for a registered page' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'live-refresh', title: 'Live') do
      raise Lich::WebUI::Error, 'invalid live render'
    end)
    scheduled = nil
    allow(runtime).to receive(:schedule_render) { |_key, **_options, &work| scheduled = work }
    runtime.send(:schedule_refresh, page)
    expect { scheduled.call }.to raise_error(Lich::WebUI::Error, 'invalid live render')
  end

  it 'sends a coherent frame when a newer render arrives during serialization' do
    number = 0
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'frames', title: 'Frames') do
      number += 1
      button(key: "button-#{number}", label: number.to_s, on: { activate: proc {} })
    end)
    address, = attach(first_connection, page)
    attachment = viewers.fetch(connection_id: first_connection.viewer_id, address: address)
    # Reproduce a delivery between binding selection and tree serialization.
    allow(viewers).to receive(:serialize).and_wrap_original do |original, *args|
      viewers.deliver(attachment, page.render)
      original.call(*args)
    end
    runtime.send(:send_render, first_connection, attachment)
    frame = first_connection.sent.last
    expect(frame['bindings'].keys).to contain_exactly(frame['tree']['cid'], frame['tree']['children'].first['cid'])
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

  it 'accepts actions after concurrent refreshes deliver in reverse generation order' do
    callbacks = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'actions', title: 'Actions') do
      button(key: 'save', label: 'Save', on: { activate: ->(_event) { callbacks << :saved } })
    end)
    address, initial = attach(first_connection, page)
    waiting = Queue.new
    release = Queue.new
    allow(viewers).to receive(:deliver).and_wrap_original do |original, attachment, render|
      if render.generation == initial['generation'] + 1
        waiting << true
        release.pop
      end
      original.call(attachment, render)
    end
    delayed = Thread.new { runtime.refresh(page) }
    Timeout.timeout(2) { waiting.pop }
    runtime.refresh(page)
    newest = first_connection.sent.last
    release << true
    Timeout.timeout(2) { delayed.value }

    expect(first_connection.sent.last['generation']).to eq(newest['generation'])
    result = runtime.handle(first_connection, type: 'event', page: address,
                            generation: newest['generation'], cid: newest.dig('tree', 'children', 0, 'cid'),
                            event: 'activate', payload: {})
    expect(result).to eq(:queued)
    expect(Timeout.timeout(2) { callbacks.pop }).to eq(:saved)
  ensure
    delayed&.kill&.join
  end

  it 'reports presentation support and records refused requests as declared degradations' do
    allow(Lich::WebUI::NativeHost).to receive(:platform).and_return(nil)
    allow(Lich::WebUI::WindowPresentation).to receive(:support).and_return({})
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'presentation', title: 'Presentation') do
      presentation(always_on_top: true, borderless: true, hidden: true, opacity: 0.8, scrollbars: false)
    end)

    attach(first_connection, page)

    expect(page.presentation_support).to eq(
      always_on_top: false, borderless: false, hidden: false, minimized: false, minimized_revision: false, opacity: true, scrollbars: true
    )
    expect(page.degradations).to contain_exactly(
      { facility: :presentation, property: :always_on_top, reason: :unsupported_by_browser_host },
      { facility: :presentation, property: :borderless, reason: :unsupported_by_browser_host },
      { facility: :presentation, property: :hidden, reason: :unsupported_by_browser_host }
    )
  end

  it 'reports native window support for both declarative and shim presentation requests on macOS' do
    allow(Lich::WebUI::NativeHost).to receive(:platform).and_return(:macos)
    page = registry.register(
      Lich::WebUI::Page.new(owner: owner, id: 'native-host', title: 'Native host',
                            props: { presentation: { always_on_top: true } }) do
        presentation(borderless: true)
      end
    )
    attach(first_connection, page)
    expect(page.presentation_support).to include(always_on_top: true, borderless: true)
    expect(page.degradations).to be_empty
  end

  it 'reports Windows topmost and opacity support while retaining the Chrome borderless limitation' do
    allow(Lich::WebUI::NativeHost).to receive(:platform).and_return(nil)
    allow(Lich::WebUI::WindowPresentation).to receive(:support).and_return(always_on_top: true, opacity: true)
    expect(runtime.presentation_support).to include(always_on_top: true, opacity: true, borderless: false)
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
      generation: render['generation'] + 1, payload: {}, request: 42,
    })
    expect(first_connection.sent.last(2).map { |message| message['type'] }).to eq(%w[refusal render])
    expect(first_connection.sent[-2]).to include('request' => 42, 'event' => 'activate')
    fabricated = runtime.handle(first_connection, {
      type: 'event', page: address, cid: 'page:actions/button:forged', event: 'activate',
      generation: render['generation'], payload: {},
    })

    expect(stale).to eq(:refused)
    expect(fabricated).to eq(:refused)
    expect(callbacks).to be_empty
    expect(first_connection.sent.map { |message| message['reason'] }).to include('stale_generation', 'component_id')
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
    expect(first_connection.sent.last).to eq('type' => 'clear_sensitive', 'cids' => [password_cid])
    expect(observed).to eq('canary-credential')
    expect(carrier).to be_consumed
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

  it 'refuses submission values on a nonterminal input change' do
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'submit-event', title: 'Submit') do
      text_input(key: 'name', value: '', on: { change: proc {} })
    end)
    address, render = attach(first_connection, page)
    input_cid = render.dig('tree', 'children', 0, 'cid')

    result = runtime.handle(first_connection, {
      type: 'event', page: address, cid: input_cid, event: 'change',
      generation: render['generation'], payload: { value: 'draft' }, submission: ['unrequested'],
    })

    expect(result).to eq(:refused)
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

  it 'accepts Save immediately after blur without invalidating the delivered form' do
    allow(runtime).to receive(:schedule_render) { |_key, **_options, &render| render.call }
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'blur-save', title: 'Form') do
      input = text_input(key: 'name', value: '', on: { change: proc {} })
      button(key: 'save', label: 'Save', submit: [input], on: { activate: proc {} })
    end)
    address, render = attach(first_connection, page)
    input, save = render.fetch('tree').fetch('children')
    runtime.handle(first_connection, type: 'event', page: address, cid: input['cid'],
                                     generation: render['generation'], event: 'change', payload: { value: 'draft' })

    result = runtime.handle(first_connection, type: 'event', page: address, cid: save['cid'],
                                             generation: render['generation'], event: 'activate', payload: {}, submission: ['draft'])

    expect(result).to eq(:queued)
  end

  [["\r\n", "\n"], ["\r", "\n"], ["\n", "\r\n"]].each do |stored_break, submitted_break|
    it "compares textarea #{stored_break.inspect} and #{submitted_break.inspect} without rewriting the snapshot" do
      received = Queue.new
      original = "First#{stored_break}Second"
      submitted = "First#{submitted_break}Second"
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'editable-lines', title: 'Form') do
        input = textarea(key: 'text', value: original)
        button(key: 'save', label: 'Save', submit: [input], on: {
          activate: ->(event) { received << event.submission },
        })
      end)
      address, render = attach(first_connection, page)
      input, save = render.fetch('tree').fetch('children')
      result = runtime.handle(first_connection, type: 'event', page: address, cid: save['cid'],
                                               generation: render['generation'], event: 'activate', payload: {}, submission: [submitted])
      expect(result).to eq(:queued)
      snapshot = received.pop(timeout: 2)
      expect(snapshot.input_changes).to be_empty
      expect(snapshot[input['cid']]).to eq(submitted)
    end
  end

  it 'records submission-only changes without invoking native input callbacks' do
    observed = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'snapshot-changes', title: 'Form') do
      input = text_input(key: 'name', value: 'before', on: { change: ->(_event) { observed << :change } })
      button(key: 'save', label: 'Save', submit: [input], on: {
        activate: ->(event) { observed << event.submission },
      })
    end)
    address, render = attach(first_connection, page)
    input, save = render.fetch('tree').fetch('children')
    runtime.handle(first_connection, type: 'event', page: address, cid: save['cid'],
                                     generation: render['generation'], event: 'activate', payload: {}, submission: ['after'])
    snapshot = observed.pop(timeout: 2)
    expect(snapshot).to be_a(Lich::WebUI::Submission)
    expect(snapshot.input_changes.map(&:cid)).to eq([input['cid']])
    expect(snapshot.input_changes).to be_frozen
    expect(snapshot[input['cid']]).to eq('after')
    expect(observed).to be_empty
  end

  [false, true].each do |stale|
    it "preserves table selection, cursor and activation ordering#{stale ? ' after a stale-generation retry' : ''}" do
      # Make automatic refreshes immediate so a selection redraw cannot hide
      # behind scheduler timing, as it did in the local Chrome run for PR #35.
      allow(runtime).to receive(:schedule_render) { |_key, **_options, &render| render.call }
      observed = Queue.new
      page = nil
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'table-activation', title: 'Table') do
        status = text(key: 'status', content: 'waiting')
        table(key: 'spells', columns: [{ key: 'name', label: 'Spell' }],
              rows: [{ key: 'barrier', cells: { name: 'Spirit Barrier' } }], selection: :single,
              on: {
                selection_change: ->(_event) { observed << :selection },
                cursor_change: ->(_event) { observed << :cursor },
                row_activate: lambda { |event|
                  observed << [page.get(event.component.cid, :selected), page.get(event.component.cid, :cursor)]
                  page.set(status.cid, :content, 'activated')
                },
              })
      end)
      address, render = attach(first_connection, page)
      table_cid = render.fetch('tree').fetch('children').last.fetch('cid')
      events = {
        selection_change: { rows: ['barrier'] },
        cursor_change: { row: 'barrier', column: 'name' },
        row_activate: { row: 'barrier', column: 'name' },
      }
      if stale
        runtime.refresh(page)
        events.each do |event, payload|
          expect(runtime.handle(first_connection, type: 'event', page: address, cid: table_cid,
                                                 generation: render['generation'], event: event, payload: payload)).to eq(:refused)
        end
        render = first_connection.sent.last
      end

      events.each do |event, payload|
        expect(runtime.handle(first_connection, type: 'event', page: address, cid: table_cid,
                                               generation: render['generation'], event: event, payload: payload)).to eq(:queued)
      end
      expect(observed.pop(timeout: 2)).to eq(:selection)
      expect(observed.pop(timeout: 2)).to eq(:cursor)
      expect(observed.pop(timeout: 2)).to eq([['barrier'], { row: 'barrier', column: 'name' }])
      Timeout.timeout(2) do
        sleep(0.001) until first_connection.sent.last.dig('tree', 'children', 0, 'props', 'content') == 'activated'
      end
      expect(first_connection.sent.last['generation']).to be > render['generation']
    end
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
  it 'keeps independently placed radio groups exclusive per viewer and rejects contradictory submissions' do
    seen = Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'radio-options', title: 'Options') do
      first = radio_option(key: 'one', group: 'choice', label: 'One', checked: true,
                           on: { change: ->(event) { seen << [event.component.props[:label], event.payload[:value]] } })
      second = radio_option(key: 'two', group: 'choice', label: 'Two', checked: false,
                            on: { change: ->(event) { seen << [event.component.props[:label], event.payload[:value]] } })
      button(key: 'save', label: 'Save', submit: [first, second], on: { activate: proc {} })
    end)
    address, render = attach(first_connection, page)
    attach(second_connection, page)
    one, two, save = render.fetch('tree').fetch('children')
    request = { type: 'event', page: address, generation: render['generation'], cid: two['cid'], event: 'change', payload: { value: true } }
    expect(runtime.handle(first_connection, request)).to eq(:queued)
    expect(Timeout.timeout(2) { [seen.pop, seen.pop] }).to eq([['One', false], ['Two', true]])
    first, second = viewers.attachments_for(page)
    expect([one, two].map { |node| page.get(node['cid'], viewer: first.viewer_id) }).to eq([false, true])
    expect([one, two].map { |node| page.get(node['cid'], viewer: second.viewer_id) }).to eq([true, false])
    runtime.handle(first_connection, request)
    barrier = Queue.new
    runtime.dispatch(owner: owner) { barrier << true }
    Timeout.timeout(2) { barrier.pop }
    expect(seen).to be_empty
    runtime.handle(first_connection, type: 'event', page: address, generation: render['generation'], cid: save['cid'],
                                     event: 'activate', payload: {}, submission: [true, true])
    expect(first_connection.sent.last).to include('type' => 'refusal', 'reason' => 'submission_scope')
    expect([one, two].map { |node| page.get(node['cid'], viewer: first.viewer_id) }).to eq([false, true])
    runtime.handle(first_connection, request.merge(payload: { value: false }))
    expect(first_connection.sent.last['type']).to eq('refusal')
  end

  it 'refuses a rendered radio group with multiple selected defaults' do
    page = Lich::WebUI::Page.new(owner: owner, id: 'invalid-options', title: 'Options') do
      radio_option(group: 'choice', label: 'One', checked: true)
      radio_option(group: 'choice', label: 'Two', checked: true)
    end
    expect { page.render }.to raise_error(Lich::WebUI::SchemaViolationError, /multiple selected/)
  end
end
