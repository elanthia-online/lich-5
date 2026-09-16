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
      registry: registry, runtime: runtime, viewers_present: -> { viewers_present },
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
end
