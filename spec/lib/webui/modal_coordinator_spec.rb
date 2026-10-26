# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe Lich::WebUI::ModalCoordinator do
  let(:owner) { Object.new }
  let(:registry) { Lich::WebUI::Registry.new }
  let(:runtime) { instance_double(Lich::WebUI::Runtime) }
  let(:pages_changed) { proc {} }
  let(:buttons) { [{ id: 'ok', label: 'OK' }] }

  def coordinator(viewers_present:)
    described_class.new(
      registry: registry, runtime: runtime, viewers_present: ->(_owner) { viewers_present },
      pages_changed: pages_changed
    )
  end

  it 'applies default and abort policy immediately when no viewer exists' do
    defaulted = coordinator(viewers_present: false).open(
      owner: owner, id: 'default', title: 'Default', buttons: buttons,
      no_viewer: :default, default_button: 'ok'
    )
    aborted = coordinator(viewers_present: false).open(
      owner: owner, id: 'abort', title: 'Abort', buttons: buttons, no_viewer: :abort
    )

    expect(defaulted.await).to have_attributes(button: 'ok', reason: :no_viewer)
    expect(aborted.await).to have_attributes(button: nil, reason: :no_viewer)
    expect(registry.size).to be_zero
  end

  it 'registers a wait modal and resolves it on owner termination' do
    modal = coordinator(viewers_present: false)
    allow(runtime).to receive(:close_page) do |page, **|
      registry.unregister(page.owner, page.id)
    end
    future = modal.open(
      owner: owner, id: 'wait', title: 'Wait', buttons: buttons, no_viewer: :wait
    )

    expect(future).not_to be_resolved
    expect(registry.size).to eq(1)
    expect(modal.terminate_owner(owner)).to eq(1)
    expect(future.await).to have_attributes(button: nil, reason: :terminated)
    expect(registry.size).to be_zero
  end

  it 'makes response win atomically over timeout and removes the modal page' do
    modal = coordinator(viewers_present: true)
    allow(runtime).to receive(:close_page) do |page, **|
      registry.unregister(page.owner, page.id)
    end
    future = modal.open(
      owner: owner, id: 'race', title: 'Race', buttons: buttons, no_viewer: :abort, timeout: 1
    )

    expect(future.resolve(button: 'ok')).to be true
    expect(future.resolve(reason: :timeout)).to be false
    expect(future.await).to have_attributes(button: 'ok', reason: nil)
    expect(registry.size).to be_zero
  end

  it 'prohibits credential modals from waiting for a viewer' do
    expect do
      coordinator(viewers_present: false).open(
        owner: owner, id: 'secret', title: 'Secret', buttons: buttons,
        no_viewer: :wait, credential: true
      )
    end.to raise_error(ArgumentError, /credential modals cannot wait/)
  end

  it 'routes dialogs only to their owners normal pages and removes stale destinations' do
    main = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'main', title: 'Map') {})
    other = registry.register(Lich::WebUI::Page.new(owner: Object.new, id: 'main', title: 'UBW') {})
    modal = coordinator(viewers_present: true)
    allow(runtime).to receive(:close_page) { |page, **| registry.unregister(page.owner, page.id) }
    first = modal.open(owner: owner, id: 'first', title: 'Question', buttons: buttons, no_viewer: :abort)
    second = modal.open(owner: owner, id: 'second', title: 'Another', buttons: buttons, no_viewer: :abort)
    descriptors = registry.descriptors
    expect(descriptors.select { |item| item.key?(:modal_for) }.map { |item| item[:modal_for] })
      .to eq([[registry.address_for(main)], [registry.address_for(main)]])
    expect(descriptors.find { |item| item[:address] == registry.address_for(other) }).not_to have_key(:modal_for)

    registry.unregister(owner, main.id)
    expect(registry.descriptors.select { |item| item.key?(:modal_for) }.map { |item| item[:modal_for] })
      .to eq([[], []])
    first.resolve(button: 'ok')
    second.resolve(button: 'ok')
    expect(registry.descriptors).to contain_exactly(
      address: registry.address_for(other), title: 'UBW', contract_version: Lich::WebUI::Contract::VERSION
    )
  end

  it 'submits declared modal fields to a nonblocking response callback and retains owner cleanup' do
    modal = coordinator(viewers_present: true)
    allow(runtime).to receive(:close_page) { |page, **| registry.unregister(page.owner, page.id) }
    received = []
    future = modal.open(owner: owner, id: 'editor', title: 'Edit', buttons: buttons, no_viewer: :wait,
                        props: { width: 400, height: 200 }, page_props: { theme: :light, density: :compact },
                        on_response: proc { |event, completion| received << event.submission; completion.resolve(button: event.payload[:button]) }) do |tree, dialog|
      input = tree.text_input(key: 'name', value: '')
      tree.submit(dialog, [input])
    end
    page = registry.fetch(owner, 'editor')
    render = page.render
    dialog = render.tree.children.first
    input = dialog.children.first
    expect(render.tree.props).to include(theme: 'light', density: 'compact')
    expect(dialog.props).to include(width: 400, height: 200)
    expect(render.submissions[dialog.cid]).to eq([input.cid])
    event = double(payload: { button: 'ok' }, submission: { input.cid => 'Typed, not yet blurred' })
    render.bindings.fetch([dialog.cid, :response]).call(event)
    expect(received).to eq([{ input.cid => 'Typed, not yet blurred' }])
    expect(future.await.button).to eq('ok')
    expect(registry.size).to eq(0)
  end

  it 'can retain an editor during a warning and still cancel it on owner termination' do
    modal = coordinator(viewers_present: true)
    allow(runtime).to receive(:close_page) { |page, **| registry.unregister(page.owner, page.id) }
    future = modal.open(owner: owner, id: 'editor', title: 'Edit', buttons: buttons,
                        no_viewer: :wait, on_response: proc { |_event, _completion| })
    render = registry.fetch(owner, 'editor').render
    dialog = render.tree.children.first
    render.bindings.fetch([dialog.cid, :response]).call(double(payload: { button: 'ok' }))
    expect(future).not_to be_resolved
    modal.terminate_owner(owner)
    expect(future.await.reason).to eq(:terminated)
  end

  it 'checks viewer availability for the requesting owner' do
    present = double('viewer predicate')
    expect(present).to receive(:call).with(owner).and_return(false)
    modal = described_class.new(registry: registry, runtime: runtime, viewers_present: present, pages_changed: pages_changed)
    result = modal.open(owner: owner, id: 'absent', title: 'Absent', buttons: buttons, no_viewer: :abort).await
    expect(result.reason).to eq(:no_viewer)
  end

  it 'resolves a modal when its browser page is closed' do
    modal = coordinator(viewers_present: true)
    allow(runtime).to receive(:close_page) { |page, **| registry.unregister(page.owner, page.id) }
    future = modal.open(owner: owner, id: 'closed', title: 'Close', buttons: buttons, no_viewer: :abort)
    page = registry.fetch(owner, 'closed')

    page.lifecycle_bindings.fetch(:close).call(double(payload: { reason: :user }))

    expect(future.await(timeout: 0.1)).to have_attributes(reason: :cancelled)
    expect(modal.pending_count).to eq(0)
    expect(registry.size).to eq(0)
  end

  it 'unregisters a modal when opening fails before completion cleanup is installed' do
    modal = coordinator(viewers_present: true)
    allow_any_instance_of(Lich::WebUI::Page).to receive(:bind_runtime).and_raise(Lich::WebUI::Error, 'bind failed')
    allow(runtime).to receive(:close_page) { |page, **| registry.unregister(page.owner, page.id) }

    expect do
      modal.open(owner: owner, id: 'failed', title: 'Failure', buttons: buttons, no_viewer: :abort)
    end.to raise_error(Lich::WebUI::Error, 'bind failed')

    expect(registry.size).to eq(0)
    expect(modal.pending_count).to eq(0)
  end

  it 'returns the live modal when its post-registration viewer check fails' do
    checks = 0
    present = lambda do |_owner|
      checks += 1
      raise 'viewer lookup failed' if checks > 1

      true
    end
    logger = double('logger', call: nil)
    modal = described_class.new(registry: registry, runtime: runtime, viewers_present: present,
                                pages_changed: pages_changed, logger: logger)
    allow(runtime).to receive(:close_page) { |page, **| registry.unregister(page.owner, page.id) }

    future = modal.open(owner: owner, id: 'live', title: 'Live', buttons: buttons, no_viewer: :abort)

    expect(future).not_to be_resolved
    expect(modal.pending_count).to eq(1)
    expect(registry.fetch(owner, 'live')).to be_a(Lich::WebUI::Page)
    expect(logger).to have_received(:call).with(:warning, 'WebUI modal viewer check failed: RuntimeError')
    future.resolve(button: 'ok')
    expect(future.await.button).to eq('ok')
    expect(modal.pending_count).to eq(0)
    expect(registry.size).to eq(0)
  ensure
    modal&.shutdown
  end
end
