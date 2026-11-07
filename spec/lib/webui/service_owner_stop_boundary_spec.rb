# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'timeout'

# Owner stop for an exiting callback at the host service: the P05 share of
# 1843:RC3. A Script owner is asked to stop and its own teardown finishes
# before its pages go; an owner without kill is retired at once; an ignored
# kill is bounded.
RSpec.describe 'WebUI service owner-stop boundary' do
  # Script-shaped owner: kill is requested asynchronously, join reports teardown.
  script_class = Class.new do
    attr_reader :name, :kills

    def initialize(name)
      @name = name
      @kills = []
      @finished = Queue.new
      @stopping = false
    end

    def kill(**options)
      @kills << options
      @stopping = true
      @name
    end

    def stopping? = @stopping
    def finish = @finished << true
    def join(timeout = nil) = @finished.pop(timeout: timeout) ? self : nil
  end

  let(:registry) { Lich::WebUI::Registry.new }
  let(:logged) { Queue.new }
  let(:service) do
    Lich::WebUI::Service.new(registry: registry, logger: ->(level, message) { logged << [level, message] })
  end

  after { service.stop }

  def stopped?(owner) = (registry.ensure_active!(owner) rescue :stopped) == :stopped

  def wait_until(seconds)
    Timeout.timeout(seconds) { sleep 0.02 until yield }
  end

  it 'asks an exiting Script owner to stop, lets its teardown finish, then retires its pages (1843:RC3)' do
    owner = script_class.new('exiting.lic')
    page = registry.register(Lich::WebUI::Page.new(owner: owner, id: 'main', title: 'Main') {})
    service.runtime.dispatch(owner: owner) { exit 3 }
    wait_until(3) { owner.stopping? }
    expect(owner.kills).to eq([{ async: true }])
    # Until the owner's own cleanup reports completion, its pages stay registered.
    expect(registry.pages_for(owner)).to eq([page])
    expect(stopped?(owner)).to be(false)

    owner.finish
    wait_until(3) { stopped?(owner) }
    expect(registry.pages_for(owner)).to be_empty
  end

  it 'retires an owner without kill immediately (1843:RC3)' do
    owner = Object.new
    registry.register(Lich::WebUI::Page.new(owner: owner, id: 'main', title: 'Main') {})
    service.runtime.dispatch(owner: owner) { exit 3 }
    wait_until(3) { stopped?(owner) }
    expect(registry.pages_for(owner)).to be_empty
  end

  it 'retires the owner once the bound expires when its kill is ignored (1843:RC3)' do
    stub_const('Lich::WebUI::Service::OWNER_STOP_TIMEOUT', 0.2)
    owner = script_class.new('hung.lic')
    registry.register(Lich::WebUI::Page.new(owner: owner, id: 'main', title: 'Main') {})
    service.runtime.dispatch(owner: owner) { exit 3 }
    wait_until(3) { stopped?(owner) }
    expect(owner.kills).to eq([{ async: true }])
    expect(registry.pages_for(owner)).to be_empty
    messages = Array.new(logged.size) { logged.pop }
    expect(messages).to include([:warning, 'WebUI owner did not stop within 0.2s owner=hung.lic; retiring its pages'])
  end
end
