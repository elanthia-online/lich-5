# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

# Exercises DownstreamHook/UpstreamHook.remove_by_owner, the backstop the
# script kill path uses to drop hooks a dying script forgot to remove itself.
# Removal keys on the owning script's object_id, so a sibling started with
# force: true that shares a name keeps its own hooks.
RSpec.describe 'hook removal by owner' do
  before do
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hooks, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_sources, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_owners, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hooks, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_sources, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_owners, {})
  end

  shared_examples 'remove_by_owner' do |klass_proc, hooks_cv, owners_cv|
    let(:klass) { klass_proc.call }

    # Returns the stand-in script so the example can read its object_id (the
    # value add records as the hook owner).
    def as_script(name)
      Script.current = OpenStruct.new(name: name)
    end

    it 'removes only the hooks owned by the given script instance' do
      alpha = as_script('alpha')
      klass.add('a1', proc { |s| s })
      klass.add('a2', proc { |s| s })
      as_script('beta')
      klass.add('b1', proc { |s| s })

      removed = klass.remove_by_owner(alpha.object_id)

      expect(removed).to eq(2)
      expect(klass.list).to contain_exactly('b1')
      expect(klass.class_variable_get(owners_cv).keys).to contain_exactly('b1')
      expect(klass.class_variable_get(hooks_cv).keys).to contain_exactly('b1')
    end

    it 'keeps a same-named sibling script\'s hooks (the force: true case)' do
      first = as_script('dup')
      klass.add('first-hook', proc { |s| s })
      as_script('dup') # same name, distinct instance
      klass.add('second-hook', proc { |s| s })

      expect(klass.remove_by_owner(first.object_id)).to eq(1)
      expect(klass.list).to contain_exactly('second-hook')
    end

    it 'returns 0 and changes nothing when no hooks match the owner' do
      as_script('alpha')
      klass.add('a1', proc { |s| s })

      expect(klass.remove_by_owner(Object.new.object_id)).to eq(0)
      expect(klass.list).to contain_exactly('a1')
    end
  end

  describe Lich::Common::DownstreamHook do
    include_examples 'remove_by_owner',
                     -> { Lich::Common::DownstreamHook },
                     :@@downstream_hooks,
                     :@@downstream_hook_owners
  end

  describe Lich::Common::UpstreamHook do
    include_examples 'remove_by_owner',
                     -> { Lich::Common::UpstreamHook },
                     :@@upstream_hooks,
                     :@@upstream_hook_owners
  end
end
