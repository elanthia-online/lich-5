# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/viewer_store'
require 'webui/page'

RSpec.describe Lich::WebUI::ViewerStore do
  let(:owner) { Object.new }
  let(:page) do
    Lich::WebUI::Page.new(owner: owner, id: 'form', title: 'Form') do
      text_input(key: 'name', value: '')
    end
  end

  it 'keeps viewer-local values isolated and shared display content common' do
    store = described_class.new
    first = store.attach(connection_id: 'one', address: 'page-one', page: page)
    second = store.attach(connection_id: 'two', address: 'page-one', page: page)
    first_render = page.render
    second_render = page.render
    store.deliver(first, first_render)
    store.deliver(second, second_render)
    first_input = first_render.tree.each.find { |component| component.type == :text_input }

    store.update(first, first_input, :change, value: 'Alice')

    expect(store.serialize(first).dig(:children, 0, :props, :value)).to eq('Alice')
    expect(store.serialize(second).dig(:children, 0, :props, :value)).to eq('')
  end

  it 'refuses serialization before a render has been delivered' do
    store = described_class.new
    attachment = store.attach(connection_id: 'one', address: 'page-one', page: page)

    expect { store.serialize(attachment) }.to raise_error(Lich::WebUI::Error, /no delivered render/)
  end

  it 'resumes within the transient window and destroys values after expiry' do
    now = 100.0
    store = described_class.new(clock: -> { now })
    attachment = store.attach(connection_id: 'one', address: 'page-one', page: page)
    render = page.render
    store.deliver(attachment, render)
    input = render.tree.each.find { |component| component.type == :text_input }
    store.update(attachment, input, :change, value: 'retained')
    store.transient_disconnect('one')

    resumed = store.attach(
      connection_id: 'two', address: 'page-one', page: page, resume_token: attachment.resume_token
    )
    expect(resumed).to equal(attachment)
    expect(resumed.values[[input.cid, :value]]).to eq('retained')

    store.transient_disconnect('two')
    now += described_class::RECONNECT_WINDOW + 1
    fresh = store.attach(
      connection_id: 'three', address: 'page-one', page: page, resume_token: attachment.resume_token
    )
    expect(fresh).not_to equal(attachment)
    expect(attachment.values).to be_empty
  end

  it 'destroys all viewer state when its page owner terminates' do
    store = described_class.new
    attachment = store.attach(connection_id: 'one', address: 'page-one', page: page)
    store.deliver(attachment, page.render)

    store.destroy_page(page)

    expect(attachment.values).to be_empty
    expect { store.fetch(connection_id: 'one', address: 'page-one') }.to raise_error(Lich::WebUI::Error)
  end

  it 'retains false viewer values when a later render redeclares a true default' do
    page = Lich::WebUI::Page.new(owner: owner, id: 'expander', title: 'Expander') do
      expander(key: 'details', label: 'Details', open: true) { text(content: 'body') }
    end
    store = described_class.new
    attachment = store.attach(connection_id: 'one', address: 'page-one', page: page)
    first = page.render
    store.deliver(attachment, first)
    expander = first.tree.each.find { |component| component.type == :expander }
    store.update(attachment, expander, :toggle, open: false)

    store.deliver(attachment, page.render)

    serialized = store.serialize(attachment)
    expect(serialized.dig(:children, 0, :props, :open)).to be false
  end

  # One table decides both what an event writes into the viewer's overlay
  # and whether the owner is refreshed. It must name only events the
  # contract declares on that type, and every property it writes must be
  # one the contract scopes to the viewer.
  it 'lists only contract events that touch viewer-scoped properties, and the runtime refreshes from it' do
    contract = Lich::WebUI::Contract
    described_class::VIEWER_STATE_EVENTS.each do |(type, event), entry|
      schema = contract.schema(type)
      expect(schema[:events]).to have_key(event), "#{type} declares no #{event} event"
      property = entry[:property]
      property = property.call(row: 'r').to_s.split(':').first.to_sym if property.respond_to?(:call)
      next if property == :expanded # nested in table rows

      expect(schema.dig(:properties, property, :scope)).to eq(:viewer), "#{type}.#{property} is not viewer-scoped"
    end

    expect(described_class.viewer_state_event?(:toggle, :change)).to be(true)
    expect(described_class.refresh_after?(:toggle, :change)).to be(true)
    expect(described_class.viewer_state_event?(:menu, :close)).to be(true)
    expect(described_class.refresh_after?(:menu, :close)).to be(false)
    expect(described_class.viewer_state_event?(:button, :activate)).to be(false)
    expect(described_class.refresh_after?(:button, :activate)).to be(false)
    expect(File.read(File.join(__dir__, '../../../lib/webui/runtime.rb'))).to include('ViewerStore.refresh_after?')
  end
end
