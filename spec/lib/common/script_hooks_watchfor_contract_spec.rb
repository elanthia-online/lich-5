# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/script_runtime_harness'

require 'common/downstreamhook'
require 'common/upstreamhook'
require 'common/watchfor'

RSpec.describe 'script runtime hooks and watchfor contracts' do
  include ScriptRuntimeHarness

  let(:script) { ScriptRuntimeHarness::FakeScript.new(name: 'hook-owner') }

  before do
    stub_const('Buffer', Class.new)
    Buffer.const_set(:SCRIPT_OUTPUT, :script_output)
    allow(Buffer).to receive(:update)

    stub_const('Frontend', Class.new)
    allow(Frontend).to receive(:supports_mono?).and_return(false)
    allow(Frontend).to receive(:client).and_return('stormfront')

    $_CLIENT_ = nil
    $_DETACHABLE_CLIENT_ = nil

    allow(Script).to receive(:current).and_return(script)
    allow(Script).to receive(:new_script_output)
    allow(self).to receive(:echo)

    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hooks, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_sources, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hooks, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_sources, {})
  end

  describe Lich::Common::DownstreamHook do
    it 'requires a Proc when adding hooks' do
      expect(described_class.add('bad', 'not-a-proc')).to be false
    end

    it 'adds, lists, runs, and removes hooks by name' do
      described_class.add('strip', proc { |line| line.sub('raw', 'clean') })

      expect(described_class.list).to eq(['strip'])
      expect(described_class.run('raw line')).to eq('clean line')
      expect(described_class.remove('strip')).to be_a(Proc)
      expect(described_class.list).to be_empty
    end

    it 'tracks the source script name' do
      described_class.add('named', proc { |line| line })

      expect(described_class.hook_sources).to eq('named' => 'hook-owner')
    end
  end

  describe Lich::Common::UpstreamHook do
    it 'requires a Proc when adding hooks' do
      expect(described_class.add('bad', Object.new)).to be false
    end

    it 'adds, lists, runs, and removes hooks by name' do
      described_class.add('up', proc { |line| "#{line}!" })

      expect(described_class.list).to eq(['up'])
      expect(described_class.run('command')).to eq('command!')
      expect(described_class.remove('up')).to be_a(Proc)
      expect(described_class.list).to be_empty
    end
  end

  describe Lich::Common::Watchfor do
    it 'registers string triggers as escaped regexps on the current script' do
      action = proc {}

      described_class.new('a.b', action)

      expect(script.watchfor.keys.first).to eq(/a\.b/)
      expect(script.watchfor.values.first).to eq(action)
    end

    it 'registers regexp triggers with a block' do
      block = proc {}

      described_class.new(/done/, &block)

      expect(script.watchfor).to eq(/done/ => block)
    end

    it 'does not register a trigger when called outside a script context' do
      allow(Script).to receive(:current).and_return(nil)

      expect(described_class.new('line') {}).to be_a(described_class)
      expect(script.watchfor).to be_empty
    end
  end
end
