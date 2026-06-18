# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

# Exercises DownstreamHook/UpstreamHook.remove_by_source, the backstop the
# script kill path uses to drop hooks a dying script forgot to remove itself.
RSpec.describe 'hook removal by source' do
  before do
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hooks, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_sources, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hooks, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_sources, {})
  end

  shared_examples 'remove_by_source' do |klass_proc, hooks_cv, sources_cv|
    let(:klass) { klass_proc.call }

    def as_script(name)
      Script.current = OpenStruct.new(name: name)
    end

    it 'removes only the hooks registered by the given script' do
      as_script('alpha')
      klass.add('a1', proc { |s| s })
      klass.add('a2', proc { |s| s })
      as_script('beta')
      klass.add('b1', proc { |s| s })

      removed = klass.remove_by_source('alpha')

      expect(removed).to eq(2)
      expect(klass.list).to contain_exactly('b1')
      expect(klass.class_variable_get(sources_cv).keys).to contain_exactly('b1')
      expect(klass.class_variable_get(hooks_cv).keys).to contain_exactly('b1')
    end

    it 'returns 0 and changes nothing when no hooks match the source' do
      as_script('alpha')
      klass.add('a1', proc { |s| s })

      expect(klass.remove_by_source('nobody')).to eq(0)
      expect(klass.list).to contain_exactly('a1')
    end
  end

  describe Lich::Common::DownstreamHook do
    include_examples 'remove_by_source',
                     -> { Lich::Common::DownstreamHook },
                     :@@downstream_hooks,
                     :@@downstream_hook_sources
  end

  describe Lich::Common::UpstreamHook do
    include_examples 'remove_by_source',
                     -> { Lich::Common::UpstreamHook },
                     :@@upstream_hooks,
                     :@@upstream_hook_sources
  end
end
