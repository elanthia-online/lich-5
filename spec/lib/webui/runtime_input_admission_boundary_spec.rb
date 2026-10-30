# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'json'

# Disabled and hidden input admission and atomic submission:
# 1831:RC3, 1831:RC4 and the P05 share of 1831:RC29.
RSpec.describe 'WebUI input admission boundaries' do
  connection_class = Class.new do
    attr_reader :viewer_id

    def initialize(viewer_id)
      @viewer_id = viewer_id
      @sent = []
    end

    def send_text(payload)
      @sent << JSON.parse(payload)
      true
    end

    def close; end
    def alive? = true
    def sent = @sent.dup
  end

  let(:owner) { Object.new }
  let(:registry) { Lich::WebUI::Registry.new }
  let(:dispatcher) { Lich::WebUI::Dispatcher.new }
  let(:viewers) { Lich::WebUI::ViewerStore.new }
  let(:runtime) { Lich::WebUI::Runtime.new(registry: registry, dispatcher: dispatcher, viewers: viewers) }
  let(:viewer) { connection_class.new('viewer') }
  let(:received) { Queue.new }

  after { runtime.shutdown }

  def attach(page)
    allow(runtime).to receive(:schedule_render)
    runtime.handle(viewer, type: 'attach', page: registry.address_for(page))
    [registry.address_for(page), viewer.sent.last]
  end

  def attachment(page)
    viewers.fetch(connection_id: viewer.viewer_id, address: registry.address_for(page))
  end

  def component(page, key)
    page.last_render.tree.each.find { |candidate| candidate.cid.end_with?(key) }
  end

  def event(page, render, key, name, payload = {}, submission: nil)
    message = { type: 'event', page: registry.address_for(page), generation: render['generation'],
                cid: component(page, key).cid, event: name, payload: payload }
    message[:submission] = submission if submission
    runtime.handle(viewer, message)
  end

  describe 'disabled and hidden event admission (1831:RC3)' do
    it 'runs blur cleanup from a disabled input with the server value and no viewer-state change' do
      sink = received
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'blur', title: 'Blur') do
        text_input(key: 'name', value: 'server', disabled: true, on: { blur: ->(context) { sink << context.payload[:value] } })
      end)
      _address, render = attach(page)
      expect(event(page, render, 'name', 'blur', { value: 'forged' })).to eq(:queued)
      expect(received.pop(timeout: 2)).to eq('server')
      expect(viewers.input_value(attachment(page), component(page, 'name'))).to eq('server')
    end

    it 'refuses interaction inside a hidden ancestor, matching the widget-transfer visibility policy' do
      sink = received
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'hidden', title: 'Hidden') do
        group(key: 'panel', hidden: true) do
          button(key: 'go', label: 'Go', on: { activate: ->(_context) { sink << :activated } })
        end
        button(key: 'shown', label: 'Shown', on: { activate: ->(_context) { sink << :shown } })
      end)
      _address, render = attach(page)
      expect(event(page, render, 'go', 'activate')).to eq(:refused)
      expect(viewer.sent.last).to include('type' => 'refusal', 'reason' => 'payload')
      expect(event(page, render, 'shown', 'activate')).to eq(:queued)
      expect(received.pop(timeout: 2)).to eq(:shown)
      expect(received).to be_empty
    end
  end

  describe 'disabled submission values (1831:RC4)' do
    it 'retains the server value of a disabled input and of an input under a disabled ancestor' do
      sink = received
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'disabled-submit', title: 'Disabled') do
        choice = select(key: 'choice', options: [{ value: 'a', label: 'A' }, { value: 'b', label: 'B' }], value: 'a', disabled: true)
        nested = nil
        group(key: 'locked', disabled: true) { nested = text_input(key: 'nested', value: 'kept') }
        button(key: 'save', label: 'Save', submit: [choice, nested],
               on: { activate: ->(context) { sink << context.submission.cids.map { |cid| context.submission[cid] } } })
      end)
      _address, render = attach(page)
      expect(event(page, render, 'save', 'activate', submission: %w[b changed])).to eq(:queued)
      expect(received.pop(timeout: 2)).to eq(%w[a kept])
      expect(viewers.input_value(attachment(page), component(page, 'choice'))).to eq('a')
      expect(viewers.input_value(attachment(page), component(page, 'nested'))).to eq('kept')
    end
  end

  describe 'atomic submission commit (1831:RC29)' do
    it 'commits no viewer value and disposes earlier secret carriers when a later wrap fails' do
      sink = received
      page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'atomic', title: 'Atomic') do
        name = text_input(key: 'name', value: 'old')
        first = password_input(key: 'first')
        second = password_input(key: 'second')
        button(key: 'save', label: 'Save', submit: [name, first, second], on: { activate: ->(_context) { sink << :ran } })
      end)
      _address, render = attach(page)
      carriers = []
      calls = 0
      allow(Lich::WebUI::SensitiveValue).to receive(:viewer).and_wrap_original do |original, value|
        calls += 1
        raise ArgumentError, 'fixture wrap failure' if calls == 2

        original.call(value).tap { |carrier| carriers << carrier }
      end
      expect { event(page, render, 'save', 'activate', submission: %w[new secret-one secret-two]) }
        .to raise_error(ArgumentError, 'fixture wrap failure')
      expect(viewers.input_value(attachment(page), component(page, 'name'))).to eq('old')
      expect(carriers.length).to eq(1)
      expect(carriers.first).to be_consumed
      expect(received).to be_empty
    end
  end
end
