# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'timeout'

RSpec.describe 'WebUI owner and modal termination' do
  let(:owner) { Object.new }
  let(:opened) { [] }
  let(:service) { Lich::WebUI::Service.new(browser_open: ->(url, **) { opened << url; true }) }
  let(:buttons) { [{ id: 'ok', label: 'OK' }] }

  before do
    allow(service.server).to receive(:launch_url).and_return('http://127.0.0.1/fixture')
    allow(Lich::WebUI).to receive(:service).and_return(service)
    stub_const('Lich::WebUI::Dispatcher::SHUTDOWN_JOIN_TIMEOUT', 0.01)
  end

  after { service.stop }

  # Builds a real page without starting a browser or listener.
  # @return [Lich::WebUI::Page] registered owner page
  def page
    Lich::WebUI.page(owner: owner, id: 'main', title: 'Main') { text(content: 'Fixture') }
  end

  # Attaches a transport double while exercising production viewer tracking.
  # @param target [Lich::WebUI::Page] page to view
  # @param id [String] distinct connection identity
  # @return [Object] connection supporting runtime delivery
  def attach(target, id = 'viewer')
    connection = double('connection', viewer_id: id, alive?: true, send_text: true)
    service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(target), version: Lich::WebUI::Contract::VERSION)
    connection
  end

  # Opens a modal using the owner's actual viewer availability.
  # @param policy [Symbol] existing no-viewer policy
  # @param id [String] unique modal identifier
  # @return [Lich::WebUI::Future] completion under test
  def modal(policy = :abort, id = 'question')
    service.modal(owner: owner, id: id, title: 'Question', buttons: buttons,
                  no_viewer: policy, **(policy == :default ? { default_button: 'ok' } : {}))
  end

  it 'refuses new pages and modals after an owner terminates while allowing a new owner' do
    service.terminate_owner(owner)
    expect { page }.to raise_error(Lich::WebUI::Error, /terminated/)
    expect { modal(:wait) }.to raise_error(Lich::WebUI::Error, /terminated/)
    expect { Lich::WebUI.page(owner: Object.new, id: 'fresh', title: 'Fresh') {} }.not_to raise_error
  end

  it 'refuses window opening as soon as owner teardown begins' do
    target = page
    dispatcher = service.runtime.instance_variable_get(:@dispatcher)
    allow(dispatcher).to receive(:shutdown_owner) do
      expect { service.open(target) }.to raise_error(Lich::WebUI::Error, /terminated/)
    end
    service.terminate_owner(owner)
    expect(opened).to be_empty
  end

  it 'refuses a late page from an admitted callback after the shutdown join expires' do
    target = page
    started, release, result = Queue.new, Queue.new, Queue.new
    dispatcher = service.runtime.instance_variable_get(:@dispatcher)
    dispatcher.enqueue(owner: owner, page_id: target.id, viewer_id: nil, cid: nil, event: :activate, coalescable: false) do
      started << true
      release.pop
      begin
        Lich::WebUI.page(owner: owner, id: 'late', title: 'Late') {}
        result << :accepted
      rescue Lich::WebUI::Error
        result << :refused
      end
    end
    Timeout.timeout(2) { started.pop }
    service.terminate_owner(owner)
    release << true
    expect(Timeout.timeout(2) { result.pop }).to eq(:refused)
    expect(service.registry.pages_for(owner)).to be_empty
  ensure
    release << true if release
  end

  it 'finishes owner cleanup and all modal callbacks when one completion callback raises' do
    attach(page)
    first = modal
    second = modal(:wait, 'second')
    completed = []
    first.then { raise 'callback failure' }
    first.then { completed << :first }
    expect(service.file_service).to receive(:revoke_owner).with(owner).and_call_original
    expect { service.terminate_owner(owner) }.not_to raise_error
    expect(completed).to eq([:first])
    expect([first, second].map { |future| future.await(timeout: 0).reason }).to eq([:terminated, :terminated])
    expect(service.registry.pages_for(owner)).to be_empty
  end

  it 'cancels pending modals and refuses new registration when the service stops' do
    future = modal(:wait)
    service.stop
    expect(future.await(timeout: 0)).to have_attributes(reason: :terminated)
    expect(service.modals.pending_count).to eq(0)
    expect { page }.to raise_error(Lich::WebUI::Error, /stopped/)
  end

  it 'includes a modal admitted concurrently with owner termination in cleanup' do
    admitted, release, retiring = Queue.new, Queue.new, Queue.new
    allow(service.registry).to receive(:register).and_wrap_original do |original, target, **options|
      original.call(target, **options).tap do
        if options[:modal]
          admitted << true
          release.pop
        end
      end
    end
    allow(service.registry).to receive(:terminate_owner).and_wrap_original do |original, target|
      original.call(target)
      retiring << true
    end
    opening = Thread.new { modal(:wait) }
    Timeout.timeout(2) { admitted.pop }
    closing = Thread.new { service.terminate_owner(owner) }
    Timeout.timeout(2) { retiring.pop }
    release << true
    future = Timeout.timeout(2) { opening.value }
    Timeout.timeout(2) { closing.value }
    expect(future.await(timeout: 0)).to have_attributes(reason: :terminated)
    expect(service.modals.pending_count).to eq(0)
    expect(service.registry.pages_for(owner)).to be_empty
  ensure
    release << true if release
    opening&.kill
    closing&.kill
  end

  it 'still revokes files and removes pages if modal teardown itself raises' do
    page
    allow(service.modals).to receive(:terminate_owner).and_raise('cleanup failed')
    expect(service.file_service).to receive(:revoke_owner).with(owner).and_call_original
    expect { service.terminate_owner(owner) }.to raise_error(RuntimeError, 'cleanup failed')
    expect(service.registry.pages_for(owner)).to be_empty
  end

  %i[abort default wait].each do |policy|
    it "applies #{policy} only when the last active viewer is lost" do
      target = page
      first = attach(target)
      second = attach(target, 'other')
      future = modal(policy)
      service.runtime.disconnect(first)
      expect(future).not_to be_resolved
      service.runtime.disconnect(second)
      if policy == :wait
        expect(future).not_to be_resolved
      else
        expect(future.await(timeout: 0)).to have_attributes(reason: :no_viewer, button: policy == :default ? 'ok' : nil)
      end
    end
  end

  it 'rechecks no-viewer policy after an explicit detach' do
    target = page
    connection = attach(target)
    future = modal
    service.runtime.handle(connection, type: 'detach', page: service.registry.address_for(target), generation: target.last_render.generation)
    expect(future.await(timeout: 0)).to have_attributes(reason: :no_viewer)
  end
end
