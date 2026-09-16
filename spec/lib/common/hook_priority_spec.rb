# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'
require 'timeout'

RSpec.describe 'hook execution priority' do
  shared_examples 'a priority-ordered hook chain' do |klass_proc|
    let(:klass) { klass_proc.call }

    before do
      klass._hooks.clear
      klass._hook_sources.clear
      klass._hook_owners.clear
      klass._hook_persist.clear
      klass._hook_priorities.clear
      allow(klass).to receive(:echo)
      allow(klass).to receive(:respond)
    end

    after do
      klass._hooks.clear
      klass._hook_sources.clear
      klass._hook_owners.clear
      klass._hook_persist.clear
      klass._hook_priorities.clear
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

    it 'cleans every metadata map after an exception and continues the chain' do
      Script.current = OpenStruct.new(name: 'failed-hook-owner')
      klass.add('broken', proc { |_line| raise 'hook failed' }, priority: 10, persist: false)
      klass.add('survivor', proc { |line| "#{line}:survived" })

      expect(klass.run('line')).to eq('line:survived')
      [klass._hooks, klass._hook_sources, klass._hook_owners,
       klass._hook_persist, klass._hook_priorities].each do |map|
        expect(map).not_to have_key('broken')
      end
      expect(klass).to have_received(:respond).with(/hook failed/)
      expect(klass.run('again')).to eq('again:survived')
    end

    it 'does not pass an initially suppressed input to any hook' do
      action = proc { |line| line }
      klass.add('observer', action)
      expect(action).not_to receive(:call)

      expect(klass.run(nil)).to be_nil
      expect(klass.list).to eq(['observer'])
    end

    it 'keeps suppression intact when the suppressor also removes a later hook' do
      calls = []
      klass.add('suppressor', proc { |_line| klass.remove('removed'); nil }, priority: 10)
      klass.add('removed', proc { |line| calls << :removed; line })
      klass.add('survivor', proc { |line| calls << :survivor; line })

      expect(klass.run('line')).to be_nil
      expect(calls).to be_empty
      expect(klass.list).to include('survivor')
    end

    it 'observes direct changes to the legacy hook map on the next dispatch' do
      klass.add('first', proc { |line| "#{line}:first" })
      expect(klass.run('line')).to eq('line:first')
      klass._hooks.clear
      klass._hooks['direct'] = proc { |line| "#{line}:direct" }

      expect(klass.run('line')).to eq('line:direct')
      klass._hooks.delete('direct')
      expect(klass.run('line')).to eq('line')
    end

    it 'takes one names snapshot when ordering a dispatch' do
      klass.add('first', proc { |line| line })
      expect(klass._hooks).to receive(:keys).once.and_call_original

      expect(klass.ordered_hook_names).to eq(['first'])
    end

    { _hooks: :keys, _hook_priorities: :fetch }.each do |storage, method|
      it "does not lose or crash a registration concurrent with #{storage}.#{method}" do
        sorting = Queue.new
        release = Queue.new
        registering = Queue.new
        klass.add('first', proc { |line| line })
        paused = false
        allow(klass.public_send(storage)).to receive(method).and_wrap_original do |original, *args|
          result = original.call(*args)
          unless paused
            paused = true
            sorting << true
            release.pop
          end
          result
        end
        reader = Thread.new { klass.ordered_hook_names }
        Timeout.timeout(3) { sorting.pop }
        writer = Thread.new do
          registering << true
          klass.add('concurrent', proc { |line| "#{line}:concurrent" }, priority: 100)
        end
        Timeout.timeout(3) do
          registering.pop
          # The writer either finishes (old unsynchronized code) or blocks on
          # the snapshot lock. No wall-clock sleep chooses the interleaving.
          Thread.pass until writer.stop?
        end
        release << true
        Timeout.timeout(3) { reader.value; writer.value }

        expect(klass.ordered_hook_names).to eq(%w[concurrent first])
        expect(klass.run('line')).to eq('line:concurrent')
      ensure
        [reader, writer].compact.each { |thread| thread.kill; thread.join }
      end
    end

    it 'runs callbacks outside the registration lock' do
      klass.add('first', proc do |line|
        Timeout.timeout(3) do
          Thread.new { klass.add('next-pass', proc { |value| "#{value}:new" }) }.value
        end
        line
      end)

      expect(klass.run('line')).to eq('line')
      expect(klass.run('line')).to eq('line:new')
    end

    it 'retains live same-name replacement at the old position for the current pass' do
      calls = []
      klass.add('replacer', proc do |line|
        klass.remove('later')
        klass.add('later', proc { |value| calls << :replacement; value }, priority: 100)
        line
      end)
      klass.add('middle', proc { |line| calls << :middle; line })
      klass.add('later', proc { |line| calls << :old; line })

      klass.run('line')
      expect(calls).to eq(%i[middle replacement])
      expect(klass.ordered_hook_names).to eq(%w[later replacer middle])
    end
  end

  describe Lich::Common::DownstreamHook do
    include_examples 'a priority-ordered hook chain', -> { Lich::Common::DownstreamHook }
  end

  describe Lich::Common::UpstreamHook do
    include_examples 'a priority-ordered hook chain', -> { Lich::Common::UpstreamHook }
  end
end
