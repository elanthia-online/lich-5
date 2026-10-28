# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

# Adapter owner attribution, per-root publication and attach diagnostics:
# 1836:RC1, 1836:RC2 and 1836:RC3.
RSpec.describe 'WebUI adapter modal and publication boundaries' do
  let(:owner) { Object.new }
  let(:registry) { Lich::WebUI::Registry.new }
  let(:service) { Lich::WebUI::Service.new(registry: registry, logger: ->(*) {}) }
  let(:published) { [] }
  let(:publish_failures) { [] }
  let(:adapter) do
    Lich::WebUI::Adapter.new(owner: owner, service: service, on_publish: lambda { |page|
      raise IOError, 'fixture presentation failure' if publish_failures.delete(page.title)

      published << page.title
      true
    })
  end
  let(:modal_options) { { title: 'Confirm', buttons: [{ id: 'ok', label: 'OK' }], no_viewer: 'wait' } }

  # Publication is driven explicitly; the coalesced background flush is held.
  before { allow(service.runtime).to receive(:schedule_render) }

  after { service.stop }

  describe 'modal owner attribution (1836:RC1)' do
    it 'refuses a foreign or same owner prop and registers a plain modal under the adapter owner' do
      foreign = Object.new
      expect { adapter.modal(modal_options.merge(owner: foreign)) }
        .to raise_error(Lich::WebUI::Error) { |error| expect(error.field).to eq(:owner) }
      expect { adapter.modal(modal_options.merge('owner' => owner)) }
        .to raise_error(Lich::WebUI::Error) { |error| expect(error.field).to eq(:owner) }
      expect(registry.pages_for(foreign)).to be_empty
      expect(service.modals.pending_count).to eq(0)

      future = adapter.modal(modal_options.merge(id: 'confirm'))
      expect(registry.pages_for(owner).map(&:id)).to eq(['confirm'])
      service.modals.terminate_owner(owner)
      expect(future.await(timeout: 1)).to have_attributes(reason: :terminated)
    end
  end

  describe 'per-root publication (1836:RC2)' do
    it 'publishes later roots after one fails and retries only the unpublished root' do
      first = adapter.create(:page, title: 'First')
      adapter.create(:page, title: 'Second')
      calls = 0
      allow(service).to receive(:refresh).and_wrap_original do |original, page|
        calls += 1
        raise Lich::WebUI::Error, 'fixture refresh failure' if page.title == 'First' && calls == 1

        original.call(page)
      end

      expect { adapter.send(:flush!) }.to raise_error(Lich::WebUI::Error, 'fixture refresh failure')
      expect(published).to eq(['Second'])
      adapter.send(:flush!)
      expect(published).to eq(%w[Second First])
      adapter.send(:flush!)
      expect(published).to eq(%w[Second First])
      expect(adapter.send(:node!, first).published).to be(true)
    end

    it 'records first presentation only after the host accepted it' do
      adapter.create(:page, title: 'Shown')
      publish_failures << 'Shown'
      expect { adapter.send(:flush!) }.to raise_error(IOError)
      expect(published).to be_empty
      adapter.send(:flush!)
      expect(published).to eq(['Shown'])
    end
  end

  describe 'attach diagnostics (1836:RC3)' do
    it 'reports an invalid placement name as itself, not as an index error' do
      parent = adapter.create(:page, title: 'Parent')
      child = adapter.create(:button, label: 'Go')
      expect { adapter.attach(parent, child, 0, placement: { '9 bad' => 1 }) }
        .to raise_error(ArgumentError, /invalid contract name/)
      expect { adapter.attach(parent, child, 'first') }
        .to raise_error(Lich::WebUI::Error, /child index is out of range/)
      expect(adapter.attach(parent, child, 0)).to be_nil
    end
  end
end
