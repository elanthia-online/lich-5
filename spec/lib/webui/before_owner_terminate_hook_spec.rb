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
    expect(logged.grep(/WebUI pre-terminate hook did not finish within 0.2s/)).not_to be_empty
  ensure
    release&.push(true)
  end
end
