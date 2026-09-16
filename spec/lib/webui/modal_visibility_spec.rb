# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

# A script that asks a question blocks until it is answered, and the dialog
# is a page of its own. Every script window is opened scoped to one page, so
# the modal was raised where nobody was looking while the script sat stuck.
RSpec.describe 'WebUI modal visibility' do
  let(:service) { Lich::WebUI::Service.new }
  let(:owner) { Struct.new(:name).new('bigshot') }

  after { service.stop }

  def raise_modal(id: 'm1')
    thread = Thread.new do
      service.modal(
        owner: owner, id: id, title: 'Confirm', body: 'Sure?',
        buttons: [{ id: 'ok', label: 'OK' }], no_viewer: 'wait', default_button: 'ok'
      )
    end
    sleep 0.05 until service.registry.descriptors.any? { |d| d[:title] == 'Confirm' } || !thread.alive?
    thread
  end

  it 'marks a modal page before it has rendered' do
    thread = raise_modal
    descriptor = service.registry.descriptors.find { |d| d[:title] == 'Confirm' }

    # The descriptor is broadcast before the first render, so this cannot be
    # read back out of the tree.
    expect(descriptor[:modal]).to be(true)
    expect(descriptor[:owner]).to eq('bigshot')
  ensure
    thread&.kill
  end

  it 'names the owner, so a viewer can tell whose modal it is' do
    other = Struct.new(:name).new('eloot')
    page = Lich::WebUI::Page.new(owner: other, id: 'w1', title: 'Window') { text(content: 'x') }
    service.registry.register(page)
    thread = raise_modal

    descriptors = service.registry.descriptors
    expect(descriptors.find { |d| d[:title] == 'Window' }).to include(owner: 'eloot', modal: false)
    expect(descriptors.find { |d| d[:title] == 'Confirm' }).to include(owner: 'bigshot', modal: true)
  ensure
    thread&.kill
  end

  it 'leaves an ordinary page unmarked' do
    page = Lich::WebUI::Page.new(owner: owner, id: 'w1', title: 'Window') { text(content: 'x') }
    service.registry.register(page)

    expect(service.registry.descriptors.find { |d| d[:title] == 'Window' }[:modal]).to be(false)
  end
end
