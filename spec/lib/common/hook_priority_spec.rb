# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

RSpec.describe 'hook execution priority' do
  shared_examples 'a priority-ordered hook chain' do |klass_proc|
    let(:klass) { klass_proc.call }

    before do
      klass._hooks.clear
      klass._hook_sources.clear
      klass._hook_owners.clear
      klass._hook_persist.clear
      klass._hook_priorities.clear
      klass.instance_variable_set(:@ordered_hook_names, nil)
      allow(klass).to receive(:echo)
      allow(klass).to receive(:respond)
    end

    it 'runs higher priorities first and preserves registration order for ties' do
      calls = []
      klass.add('ordinary-first', proc { |line| calls << :ordinary_first; line }, priority: 0)
      klass.add('low', proc { |line| calls << :low; line }, priority: -999)
      klass.add('high', proc { |line| calls << :high; line }, priority: 999)
      klass.add('ordinary-second', proc { |line| calls << :ordinary_second; line })

      expect(klass.run('line')).to eq('line')
      expect(calls).to eq(%i[high ordinary_first ordinary_second low])
    end

    it 'keeps a named replacement in its original position among equal priorities' do
      calls = []
      klass.add('first', proc { |line| calls << :old; line })
      klass.add('second', proc { |line| calls << :second; line })
      klass.add('first', proc { |line| calls << :replacement; line })

      klass.run('line')
      expect(calls).to eq(%i[replacement second])
    end

    it 'reorders a named replacement when its priority changes' do
      calls = []
      klass.add('first', proc { |line| calls << :first; line })
      klass.add('second', proc { |line| calls << :second; line })
      klass.add('second', proc { |line| calls << :promoted; line }, priority: 1)

      klass.run('line')
      expect(calls).to eq(%i[promoted first])
    end

    it 'rejects priorities that cannot be ordered' do
      expect(klass.add('invalid', proc { |line| line }, priority: Float::NAN)).to be(false)
      expect(klass.list).to be_empty
      expect(klass).to have_received(:echo).with(/finite real Numeric/)
    end

    it 'lets a high-priority observer see a line before a lower hook suppresses it' do
      calls = []
      klass.add('presentation', proc { |_line| calls << :presentation; nil }, priority: -10)
      klass.add('observer', proc { |line| calls << :observer; line }, priority: 10)

      expect(klass.run('line')).to be_nil
      expect(calls).to eq(%i[observer presentation])
    end

    it 'tolerates removal of a later hook during dispatch' do
      calls = []
      klass.add('remover', proc { |line| klass.remove('removed'); calls << :remover; line })
      klass.add('removed', proc { |line| calls << :removed; line })

      expect(klass.run('line')).to eq('line')
      expect(calls).to eq([:remover])
    end
  end

  describe Lich::Common::DownstreamHook do
    include_examples 'a priority-ordered hook chain', -> { Lich::Common::DownstreamHook }
  end

  describe Lich::Common::UpstreamHook do
    include_examples 'a priority-ordered hook chain', -> { Lich::Common::UpstreamHook }
  end
end
