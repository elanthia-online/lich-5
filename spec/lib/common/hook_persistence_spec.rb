# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

# Covers HookRegistry#cleanup_on_death, run from the ScriptDeath handler when a
# script dies. Hooks declared persist: false are removed, persist: true are
# kept, and undeclared hooks are kept (back-compat) but warned about once.
# Cleanup is keyed on the owner's object_id, so a force: true sibling that
# shares a name is unaffected.
RSpec.describe 'hook persistence on script death' do
  shared_examples 'cleanup_on_death' do |klass_proc|
    let(:klass) { klass_proc.call }

    before do
      klass._hooks.clear
      klass._hook_sources.clear
      klass._hook_owners.clear
      klass._hook_persist.clear
      klass.instance_variable_set(:@warned_undeclared, {})
      allow(klass).to receive(:respond)
      allow(Lich).to receive(:log)
    end

    # Returns the stand-in script so the example can read its object_id (the
    # value add records as the hook owner).
    def as_script(name)
      Script.current = OpenStruct.new(name: name)
    end

    it 'removes a persist: false hook when its owner dies' do
      owner = as_script('scoped-script')
      klass.add('scoped', proc { |s| s }, persist: false)

      expect(klass.cleanup_on_death(owner.object_id)).to eq(1)
      expect(klass.list).to be_empty
    end

    it 'keeps a persist: true hook when its owner dies (the ;alias case)' do
      owner = as_script('alias')
      klass.add('persistent', proc { |s| s }, persist: true)

      expect(klass.cleanup_on_death(owner.object_id)).to eq(0)
      expect(klass.list).to contain_exactly('persistent')
    end

    it 'keeps an undeclared hook but warns once so the author can declare intent' do
      owner = as_script('careless')
      klass.add('leaky', proc { |s| s }) # no persist:

      expect(klass.cleanup_on_death(owner.object_id)).to eq(0)
      expect(klass.list).to contain_exactly('leaky')
      expect(Lich).to have_received(:log).with(/persist: true/)
    end

    it 'does not warn again for the same hook name' do
      first = as_script('careless')
      klass.add('leaky', proc { |s| s }, persist: nil)
      klass.cleanup_on_death(first.object_id)

      second = as_script('careless') # a fresh run re-registers it and dies again
      klass.add('leaky', proc { |s| s }, persist: nil)
      klass.cleanup_on_death(second.object_id)

      expect(Lich).to have_received(:log).once
    end

    it 'only touches hooks owned by the dying script' do
      a = as_script('a')
      klass.add('a1', proc { |s| s }, persist: false)
      as_script('b')
      klass.add('b1', proc { |s| s }, persist: false)

      klass.cleanup_on_death(a.object_id)

      expect(klass.list).to contain_exactly('b1')
    end
  end

  describe Lich::Common::DownstreamHook do
    include_examples 'cleanup_on_death', -> { Lich::Common::DownstreamHook }
  end

  describe Lich::Common::UpstreamHook do
    include_examples 'cleanup_on_death', -> { Lich::Common::UpstreamHook }
  end
end
