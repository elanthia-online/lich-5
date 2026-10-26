# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe 'coherent widget-transfer admission' do
  let(:owner) { Object.new }
  let(:registry) { Lich::WebUI::Registry.new }
  let(:dispatcher) { Lich::WebUI::Dispatcher.new }
  let(:viewers) { Lich::WebUI::ViewerStore.new(clock: -> { @now }) }
  let(:runtime) { Lich::WebUI::Runtime.new(registry: registry, dispatcher: dispatcher, viewers: viewers, logger: ->(_level, message) { @logs << message }) }

  before do
    @now = 100.0
    @tick = 0
    @source_key = 'original'
    @disabled = @hidden = false
    @children = %w[first second]
    @source_text = 'Ability'
    @calls = []
    @callback = proc { |context| @calls << context.render.tree.children.first.children.first.props[:drag_source] }
    @logs = []
    @frames = []
    @connection = Object.new
    @connection.define_singleton_method(:viewer_id) { 'widget-admission-viewer' }
    @connection.define_singleton_method(:alive?) { true }
    frames = @frames
    @connection.define_singleton_method(:send_text) { |text| frames << JSON.parse(text); true }
  end

  after { dispatcher.shutdown }

  def publish
    state = self
    @page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'drops', title: 'Drop admission') do
      stack(key: 'ancestor', disabled: state.instance_variable_get(:@disabled), hidden: state.instance_variable_get(:@hidden)) do
        unless state.instance_variable_get(:@remove_source)
          stack(key: 'source', drag_source: state.instance_variable_get(:@source_key)) do
            text(key: 'caption', content: state.instance_variable_get(:@source_text))
          end
        end
        stack(key: 'target', drag_destination: true, on: { widget_drop: state.instance_variable_get(:@callback) }) do
          state.instance_variable_get(:@children).each { |key| text(key: key, content: key) }
        end
      end
      text(key: 'ticker', content: "Tick #{state.instance_variable_get(:@tick)}")
    end)
    @address = registry.address_for(@page)
    runtime.handle(@connection, type: 'attach', page: @address, version: Lich::WebUI::Contract::VERSION)
    frame = @frames.last
    source, target = frame['tree']['children'].first['children']
    @event = { type: 'event', page: @address, cid: target['cid'], event: 'widget_drop', request: 1,
               generation: frame['generation'], payload: { source: source['cid'], x: 12, y: 25,
                                                         allocations: target['children'].map { |child| { cid: child['cid'], y: 10, height: 30 } } } }
  end

  def paint
    @tick += 1
    runtime.refresh(@page)
  end

  def drain
    done = Queue.new
    runtime.dispatch(owner: owner) { done << true }
    expect(done.pop(timeout: 3)).to be(true)
  end

  it 'admits one measured insertion through repeated unrelated paints without retry or duplicate execution' do
    publish
    12.times { paint }
    expect(runtime.handle(@connection, @event)).to eq(:queued)
    expect(runtime.handle(@connection, @event)).to eq(:queued)
    drain
    expect(@calls).to eq(['original'])
    expect(@logs.grep(/phase=queued/).length).to eq(1)
    expect(@logs.grep(/phase=completed/).length).to eq(1)
    expect(@frames.none? { |frame| frame['type'] == 'refusal' }).to be(true)
  end

  %i[source binding order ancestor hidden geometry aba removal].each do |change|
    it "rejects old transfer authority after #{change} changes" do
      publish
      case change
      when :source then @source_key = 'replacement'
      when :binding then @callback = proc { @calls << 'replacement' }
      when :order then @children.reverse!
      when :ancestor then @disabled = true
      when :hidden then @hidden = true
      when :geometry then @source_text = 'Different ability caption'
      when :removal then @remove_source = true
      when :aba
        @source_key = 'replacement'
        paint
        @source_key = 'original'
      end
      paint
      expect(runtime.handle(@connection, @event)).to eq(:refused)
      drain
      expect(@calls).to be_empty
      expect(@frames.reverse.find { |frame| frame['type'] == 'refusal' }['reason']).to eq('stale_generation')
    end
  end

  it 'expires the compressed generation range and admits the fresh range after a bounded refusal' do
    publish
    @now += Lich::WebUI::ViewerStore::WIDGET_ADMISSION_WINDOW + 1
    paint
    expect(runtime.handle(@connection, @event)).to eq(:refused)
    retry_event = @event.merge(generation: @frames.last['generation'], request: 2)
    5.times { paint }
    expect(runtime.handle(@connection, retry_event)).to eq(:queued)
    drain
    expect(@calls).to eq(['original'])
  end

  %i[replace detach expire].each do |change|
    it "retires an already queued transfer on #{change}" do
      publish
      gate, entered = Queue.new, Queue.new
      runtime.dispatch(owner: owner) { entered << true; gate.pop }
      entered.pop(timeout: 3)
      expect(runtime.handle(@connection, @event)).to eq(:queued)
      case change
      when :replace then @source_key = 'replacement'; paint
      when :detach then runtime.disconnect(@connection)
      when :expire then @now += Lich::WebUI::ViewerStore::WIDGET_ADMISSION_WINDOW + 1
      end
      gate << true
      drain
      expect(@calls).to be_empty
      expect(@logs.grep(/phase=retired/).length).to eq(1)
    ensure
      gate << true if gate
    end
  end

  it 'blocks delivery between the generation check and lookup, then retires replaced queued authority' do
    publish
    gate, entered = Queue.new, Queue.new
    runtime.dispatch(owner: owner) { entered << true; gate.pop }
    entered.pop(timeout: 3)
    attempted, worker = Queue.new, nil
    allow(runtime).to receive(:find_component!).and_wrap_original do |method, *args|
      unless worker
        worker = Thread.new { @source_key = 'replacement'; attempted << true; paint }
        attempted.pop(timeout: 3)
      end
      method.call(*args)
    end
    expect(runtime.handle(@connection, @event)).to eq(:queued)
    worker.value
    gate << true
    drain
    expect(@calls).to be_empty
  ensure
    gate << true if gate
    worker&.join(3)
  end

  it 'never resolves a normal event against a render delivered after its generation check' do
    callback = proc { @calls << 'original-binding' }
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'button', title: 'Coherent') do
      button(key: 'action', label: 'Action', on: { activate: callback })
    end)
    address = registry.address_for(page)
    runtime.handle(@connection, type: 'attach', page: address, version: Lich::WebUI::Contract::VERSION)
    frame = @frames.last
    attempted, worker = Queue.new, nil
    allow(runtime).to receive(:find_component!).and_wrap_original do |method, *args|
      unless worker
        worker = Thread.new do
          callback = proc { @calls << 'replacement-binding' }
          attempted << true
          runtime.refresh(page)
        end
        attempted.pop(timeout: 3)
      end
      method.call(*args)
    end
    expect(runtime.handle(@connection, type: 'event', page: address, cid: frame['tree']['children'].first['cid'],
                                      event: 'activate', payload: {}, generation: frame['generation'])).to eq(:queued)
    worker.value
    drain
    expect(@calls).to eq(['original-binding'])
  ensure
    worker&.join(3)
  end

  it 'refuses future generations and generations belonging only to another viewer' do
    publish
    expect(runtime.handle(@connection, @event.merge(generation: @event[:generation] + 100))).to eq(:refused)
    second = Object.new
    frames = []
    second.define_singleton_method(:viewer_id) { 'second-connection' }
    second.define_singleton_method(:alive?) { true }
    second.define_singleton_method(:send_text) { |text| frames << JSON.parse(text); true }
    runtime.handle(second, type: 'attach', page: @address, version: Lich::WebUI::Contract::VERSION)
    expect(runtime.handle(second, @event)).to eq(:refused)
    drain
    expect(@calls).to be_empty
  end

  it 'runs callbacks outside the store monitor and retains their admitted render' do
    @callback = proc do |context|
      result = Thread.new { viewers.fetch(connection_id: @connection.viewer_id, address: @address) }
      expect(result.join(2)).to be(result)
      @calls << context.render.generation
    end
    publish
    paint
    expect(runtime.handle(@connection, @event)).to eq(:queued)
    drain
    expect(@calls).to eq([@page.last_render.generation])
  end

  it 'preserves strict generation checks for other event families' do
    publish
    paint
    expect(runtime.handle(@connection, @event.merge(event: 'pointer_press', payload: { x: 1, y: 1, button: 1, time: 0, state: 0, click_count: 1 }))).to eq(:refused)
    expect(@frames.reverse.find { |frame| frame['type'] == 'refusal' }['reason']).to eq('stale_generation')
  end
end
