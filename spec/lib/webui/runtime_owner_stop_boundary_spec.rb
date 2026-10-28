# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'json'
require 'open3'
require 'rbconfig'
require 'timeout'

# Owner stop and render-worker ownership at the runtime layer: the P05 shares of
# 1832:RC1 and 1832:RC28, plus 1837:RC1, 1836:RC11 and 1836:RC12.
RSpec.describe 'WebUI runtime owner-stop boundaries' do
  connection_class = Class.new do
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

    def close; end
    def alive? = true
    def sent = @mutex.synchronize { @sent.dup }
  end

  let(:owner) { Object.new }
  let(:registry) { Lich::WebUI::Registry.new }
  let(:logged) { Queue.new }
  let(:dispatcher) { Lich::WebUI::Dispatcher.new }
  let(:runtime) do
    Lich::WebUI::Runtime.new(registry: registry, dispatcher: dispatcher, logger: ->(level, message) { logged << [level, message] })
  end
  let(:viewer) { connection_class.new('viewer') }

  after { runtime.shutdown }

  def run_fresh(code)
    output, errors, status = Open3.capture3(RbConfig.ruby, '-I', LIB_DIR, '-e', code)
    [output, errors, status]
  end

  it 'contains script-class and exit failures from render workers and modal responses, in a fresh process (1832:RC1)' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      require 'webui'
      require 'timeout'
      registry = Lich::WebUI::Registry.new
      runtime = Lich::WebUI::Runtime.new(registry: registry)
      loaded, exiting = Object.new, Object.new
      page = registry.register(Lich::WebUI::Page.new(owner: loaded, id: 'loaded', title: 'Loaded') {})
      registry.register(Lich::WebUI::Page.new(owner: exiting, id: 'exiting', title: 'Exiting') {})
      runtime.schedule_render(:load_error, owner: loaded, delay: 0) { raise LoadError, 'missing' }
      sleep 0.2
      abort 'terminate did not finish cleanup' unless runtime.terminate_owner(loaded) == [page] && registry.pages_for(loaded).empty?
      runtime.schedule_render(:exit, owner: exiting, delay: 0) { exit 3 }
      Timeout.timeout(3) { sleep 0.02 until registry.pages_for(exiting).empty? }
      abort 'exit did not stop its owner' unless (registry.ensure_active!(exiting) rescue :stopped) == :stopped

      service = Lich::WebUI::Service.new(registry: Lich::WebUI::Registry.new, logger: ->(*) {})
      modal_owner = Object.new
      future = service.modal(owner: modal_owner, id: 'confirm', title: 'Confirm', buttons: [{ id: 'ok', label: 'OK' }],
                             no_viewer: 'wait', on_response: ->(_event, _future) { raise NotImplementedError, 'todo' })
      modal = service.registry.pages_for(modal_owner).first
      response = modal.last_render || modal.render
      dialog = response.tree.children.first
      service.runtime.instance_variable_get(:@dispatcher).enqueue(owner: modal_owner, page_id: modal.id, viewer_id: 'v',
                                                                 cid: dialog.cid, event: :response, coalescable: false) do
        response.bindings.fetch([dialog.cid, :response]).call(Struct.new(:payload).new({ button: 'ok' }))
      end
      result = future.await(timeout: 3)
      abort "modal stayed pending: \#{result.inspect}" unless result&.reason == :error
      service.stop
      runtime.shutdown
      puts 'ready'
    RUBY_CODE
    expect(status.success?).to be(true), errors
    expect(output).to eq("ready\n")
  end

  it 'stops the owner when a modal completion callback exits, runs the remaining callbacks and keeps the process, in a fresh process (1832:RC28)' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      require 'webui'
      require 'timeout'
      service = Lich::WebUI::Service.new(registry: Lich::WebUI::Registry.new, logger: ->(*) {})
      owner = Object.new
      native = service.registry.register(Lich::WebUI::Page.new(owner: owner, id: 'main', title: 'Main') {})
      future = service.modal(owner: owner, id: 'confirm', title: 'Confirm', buttons: [{ id: 'ok', label: 'OK' }], no_viewer: 'wait')
      observed = []
      future.then { exit 5 }
      future.then { |result| observed << result.reason }
      future.cancel(reason: :cancelled)
      abort 'remaining callbacks abandoned' unless observed == [:cancelled]
      Timeout.timeout(3) { sleep 0.02 until service.registry.pages_for(owner).empty? }
      abort 'owner admission still open' unless (service.registry.ensure_active!(owner) rescue :stopped) == :stopped
      abort 'native page survived' if service.registry.pages_for(owner).include?(native)
      service.stop
      puts 'ready'
    RUBY_CODE
    expect(status.success?).to be(true), errors
    expect(output).to eq("ready\n")
  end

  it 'cancels and cleans up queued callbacks behind a running one when the runtime terminates the owner (1837:RC1)' do
    stub_const('Lich::WebUI::Dispatcher::SHUTDOWN_JOIN_TIMEOUT', 2)
    entered, release, ran = Queue.new, Queue.new, Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'ending', title: 'Ending') do
      secret = password_input(key: 'secret')
      button(key: 'login', label: 'Log in', submit: [secret], on: { activate: ->(_context) { ran << :submission } })
    end)
    address = registry.address_for(page)
    runtime.handle(viewer, type: 'attach', page: address)
    render = viewer.sent.last
    runtime.dispatch(owner: owner) do
      entered << true
      release.pop
    end
    entered.pop(timeout: 2)
    snapshots = []
    allow(Lich::WebUI::Submission).to receive(:new).and_wrap_original do |original, **options|
      original.call(**options).tap { |snapshot| snapshots << snapshot }
    end
    button = render.dig('tree', 'children', 1, 'cid')
    expect(runtime.handle(viewer, type: 'event', page: address, generation: render['generation'], cid: button,
                                  event: 'activate', payload: {}, submission: ['hunter2'])).to eq(:queued)
    runtime.dispatch(owner: owner) { ran << :queued }

    terminating = Thread.new { runtime.terminate_owner(owner) }
    sleep 0.05
    release << true
    expect(terminating.value).to eq([page])
    expect(ran).to be_empty
    expect(snapshots.length).to eq(1)
    expect(snapshots.first[snapshots.first.cids.first]).to be_consumed
    expect(viewer.sent.last).to include('type' => 'page_closed', 'reason' => 'owner')
    expect(registry.pages_for(owner)).to be_empty
  ensure
    release&.push(true)
  end

  it 'bounds render cancellation and never delivers a render that outlives owner termination (1836:RC11)' do
    stub_const('Lich::WebUI::Runtime::RenderCoordinator::STOP_TIMEOUT', 0.2)
    host = Lich::WebUI::Runtime.new(registry: registry, dispatcher: dispatcher, logger: ->(level, message) { logged << [level, message] })
    blocking, entered, release = [false], Queue.new, Queue.new
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'slow', title: 'Slow') do
      if blocking.first
        entered << true
        release.pop
      end
      text(key: 'status', content: 'Ready')
    end)
    host.handle(viewer, type: 'attach', page: registry.address_for(page))
    blocking[0] = true
    host.schedule_render(page, owner: owner, delay: 0) { host.refresh(page) }
    entered.pop(timeout: 2)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(host.terminate_owner(owner)).to eq([page])
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.5
    sent_after_termination = viewer.sent.length
    release << true
    sleep 0.1
    expect(viewer.sent.length).to eq(sent_after_termination)
    expect(viewer.sent.last).to include('type' => 'page_closed')
    messages = Array.new(logged.size) { logged.pop }.map(&:last)
    expect(messages.join("\n")).to include('did not stop')
  ensure
    release&.push(true)
    host&.shutdown
  end

  it 'runs render workers and modal timers on host threads that survive the requesting script (1836:RC12)' do
    groups, timed_out = Queue.new, Queue.new
    script_group = ThreadGroup.new
    modals = Lich::WebUI::ModalCoordinator.new(registry: registry, runtime: runtime, viewers_present: ->(_) { true }, pages_changed: proc {})
    script = Thread.new do
      script_group.add(Thread.current)
      runtime.schedule_render(:host, owner: owner, delay: 0.05) { groups << Thread.current.group }
      modals.open(owner: owner, id: 'timed', title: 'Timed', buttons: [{ id: 'ok', label: 'OK' }], no_viewer: 'abort', timeout: 1)
            .then { |result| timed_out << result.reason }
      sleep
    end
    Timeout.timeout(2) { sleep 0.01 until script_group.list.include?(script) && registry.pages_for(owner).any? }
    script_group.list.each(&:kill)
    script.join(1)

    expect(groups.pop(timeout: 2)).to equal(ThreadGroup::Default)
    expect(timed_out.pop(timeout: 3)).to eq(:timeout)
  end
end
