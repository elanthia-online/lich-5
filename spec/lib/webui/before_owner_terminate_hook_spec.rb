# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

# Pre-terminate hooks on script death: the P05 share of 1836:RC20. ScriptDeath
# has no handler order, so a later layer registers here to close its own
# resources before the core handler retires the dying owner's pages.
RSpec.describe 'WebUI pre-terminate hooks on script death' do
  let(:owner) { Object.new }
  let(:hooks) { [] }
  let(:logged) { [] }

  before do
    Lich::WebUI.reset!
    allow(Lich).to receive(:log) { |message| logged << message }
  end

  after do
    registered = Lich::WebUI.instance_variable_get(:@before_terminate_hooks)
    hooks.each { |hook| registered&.delete(hook) }
    Lich::WebUI.reset!
  end

  def register(&hook) = hooks << Lich::WebUI.before_owner_terminate(&hook)

  it 'runs registered hooks with the owner, on a host thread, before the core handler retires its pages' do
    host = Lich::WebUI.service
    page = Lich::WebUI.page(owner: owner, id: 'main', title: 'Main') {}
    seen = []
    register { |dying| seen << [dying, host.registry.pages_for(dying), Thread.current.group.equal?(ThreadGroup::Default)] }

    Lich::Common::ScriptDeath.run(owner)

    expect(seen).to eq([[owner, [page], true]])
    expect(host.registry.pages_for(owner)).to be_empty
    expect { host.registry.ensure_active!(owner) }.to raise_error(Lich::WebUI::Error)
  end

  it 'runs an owner-bound hook once, for that owner only, and spends no host thread on other deaths' do
    other = Object.new
    seen = []
    hooks << Lich::WebUI.before_owner_terminate(owner: owner) { |dying| seen << dying }
    allow(Lich::WebUI::HostThread).to receive(:start).and_call_original

    Lich::Common::ScriptDeath.run(other)
    expect(seen).to be_empty
    expect(Lich::WebUI::HostThread).not_to have_received(:start)

    Lich::Common::ScriptDeath.run(owner)
    Lich::Common::ScriptDeath.run(owner)

    expect(seen).to eq([owner])
    expect(Lich::WebUI::HostThread).to have_received(:start).once
  end

  it 'retires the owner when a hook raises or exits, and still runs the remaining hooks' do
    host = Lich::WebUI.service
    Lich::WebUI.page(owner: owner, id: 'main', title: 'Main') {}
    ran = []
    register { raise LoadError, 'missing' }
    register { exit 3 }
    register { ran << :last }

    Lich::Common::ScriptDeath.run(owner)

    expect(ran).to eq([:last])
    expect(host.registry.pages_for(owner)).to be_empty
    failures = logged.grep(/WebUI pre-terminate hook failed/).map { |message| message[/error=\w+/] }
    expect(failures).to contain_exactly('error=LoadError', 'error=SystemExit')
  end

  it 'bounds a hook that does not finish and retires the owner anyway' do
    stub_const('Lich::WebUI::BEFORE_TERMINATE_TIMEOUT', 0.2)
    host = Lich::WebUI.service
    Lich::WebUI.page(owner: owner, id: 'main', title: 'Main') {}
    release = Queue.new
    register { release.pop }

    Lich::Common::ScriptDeath.run(owner)

    expect(host.registry.pages_for(owner)).to be_empty
    expect(logged.grep(/WebUI pre-terminate hook did not finish within 0.2s .*abandoning it \(not stopped\)/)).not_to be_empty
  ensure
    release&.push(true)
  end

  it 'bounds the wait at 5 seconds, matching the owner stop bound' do
    expect(Lich::WebUI::BEFORE_TERMINATE_TIMEOUT).to eq(5)
    expect(Lich::WebUI::BEFORE_TERMINATE_TIMEOUT).to eq(Lich::WebUI::Service::OWNER_STOP_TIMEOUT)
  end

  it 'waits for a hook that ends after the old 2 second bound, without abandoning it' do
    host = Lich::WebUI.service
    Lich::WebUI.page(owner: owner, id: 'main', title: 'Main') {}
    started = Queue.new
    release = Queue.new
    finished = []
    register do
      started << true
      release.pop
      finished << :done
    end

    runner = Thread.new { Lich::Common::ScriptDeath.run(owner) }
    expect(started.pop(timeout: 5)).to be(true)

    # Hold the hook past the old 2 second bound, measured on the monotonic
    # clock with a bounded poll; the runner must still be waiting.
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2.5
    sleep 0.05 while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    expect(runner).to be_alive
    expect(logged.grep(/did not finish within/)).to be_empty

    release << true
    expect(runner.join(10)).not_to be_nil
    expect(finished).to eq([:done])
    expect(logged.grep(/did not finish within/)).to be_empty
    expect(host.registry.pages_for(owner)).to be_empty
  ensure
    release&.push(true)
    runner&.join(10)
  end
end
