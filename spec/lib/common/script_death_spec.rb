# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_death'

RSpec.describe Lich::Common::ScriptDeath do
  # Handlers are registered globally at subsystem load (e.g. the hook
  # registries). Save and restore the real list around each example rather than
  # clearing it, so this spec cannot wipe handlers other specs rely on.
  around do |example|
    saved = described_class.instance_variable_get(:@handlers)
    described_class.instance_variable_set(:@handlers, [])
    example.run
  ensure
    described_class.instance_variable_set(:@handlers, saved)
  end

  it 'runs each registered handler with the dying script, in order' do
    seen = []
    described_class.on_death { |s| seen << [:a, s] }
    described_class.on_death { |s| seen << [:b, s] }

    script = Object.new
    described_class.run(script)

    expect(seen).to eq([[:a, script], [:b, script]])
  end

  it 'isolates a handler that raises so sibling handlers still run' do
    allow(Lich).to receive(:log)
    ran = false
    described_class.on_death { raise 'boom' }
    described_class.on_death { ran = true }

    expect { described_class.run(Object.new) }.not_to raise_error
    expect(ran).to be true
  end

  it 'ignores on_death called without a block' do
    expect { described_class.on_death }.not_to raise_error
    expect { described_class.run(Object.new) }.not_to raise_error
  end
end
