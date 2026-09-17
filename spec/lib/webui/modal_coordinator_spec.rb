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

  # Review 2026-09-17, R6: a MessageDialog whose window the viewer closed
  # waited its full hour, because nothing about the modal page's lifecycle
  # touched its Future. Driven through the real runtime: attach a viewer,
  # then detach at the delivered generation, which is what closing the
  # window sends.
  describe 'dismissal' do
    let(:connection_class) do
      Struct.new(:sent, :viewer_id) do
        def send_text(text) = sent << JSON.parse(text)
        def alive? = true
      end
    end

    def real_runtime
      Lich::WebUI::Runtime.new(registry: registry, file_service: Lich::WebUI::FileService.new(application_roots: []))
    end

    def attach(runtime, page, viewer)
      connection = connection_class.new([], viewer)
      address = registry.address_for(page)
      result = runtime.handle(connection, type: 'attach', page: address, version: Lich::WebUI::Contract::VERSION)
      raise "attach was #{result.inspect}" unless result == :attached

      [connection, address]
    end

    it 'resolves the future as dismissed when the viewer closes the window' do
      runtime = real_runtime
      modal = described_class.new(registry: registry, runtime: runtime, viewers_present: -> { true }, pages_changed: pages_changed)
      future = modal.open(owner: owner, id: 'ask', title: 'Ask', buttons: buttons, no_viewer: :wait)
      page = registry.fetch(owner, 'ask')
      connection, address = attach(runtime, page, 'viewer-1')
      generation = connection.sent.find { |m| m['type'] == 'render' }['generation']

      expect(future).not_to be_resolved
      runtime.handle(connection, type: 'detach', page: address, generation: generation)
      expect(future.await(timeout: 2)).to have_attributes(button: nil, reason: :dismissed)
      expect(modal.pending_count).to eq(0)
    ensure
      runtime&.shutdown
    end

    it 'gives a dropped socket a grace, dismisses when nobody comes back, and not when someone does' do
      runtime = real_runtime
      modal = described_class.new(registry: registry, runtime: runtime, viewers_present: -> { true },
                                  pages_changed: pages_changed, dismiss_grace: 0.2)
      future = modal.open(owner: owner, id: 'drop', title: 'Drop', buttons: buttons, no_viewer: :wait)
      page = registry.fetch(owner, 'drop')
      connection, = attach(runtime, page, 'viewer-1')
      runtime.disconnect(connection)
      sleep 0.05
      expect(future).not_to be_resolved, 'the grace has not passed'
      attach(runtime, page, 'viewer-2')
      sleep 0.3
      expect(future).not_to be_resolved, 'a viewer came back within the grace'

      other = modal.open(owner: owner, id: 'gone', title: 'Gone', buttons: buttons, no_viewer: :wait)
      gone_page = registry.fetch(owner, 'gone')
      gone_connection, = attach(runtime, gone_page, 'viewer-3')
      runtime.disconnect(gone_connection)
      expect(other.await(timeout: 2)).to have_attributes(button: nil, reason: :dismissed)
    ensure
      runtime&.shutdown
    end
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

  # The rescue in #open cancelled the future, but a failure after the page
  # was registered and before future.then was armed left the page in the
  # registry with nothing that would ever close it: listed to every
  # viewer, never resolved, never removed.
  it 'unregisters the modal page when open fails after registering it' do
    modal = coordinator(viewers_present: true)
    # The timeout timer is created between register and future.then.
    allow(Thread).to receive(:new).and_raise(ThreadError, 'no more threads')

    expect do
      modal.open(owner: owner, id: 'orphan', title: 'Orphan', buttons: buttons, no_viewer: :abort, timeout: 1)
    end.to raise_error(ThreadError, 'no more threads')
    expect(registry.size).to be_zero
    expect(modal.pending_count).to be_zero
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
