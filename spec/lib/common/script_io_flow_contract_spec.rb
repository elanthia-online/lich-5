# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/script_runtime_harness'

RSpec.describe 'script runtime IO and flow helpers' do
  include ScriptRuntimeHarness

  let(:runtime_module) do
    ScriptRuntimeHarness.global_defs_module(
      :echo, :respond, :put, :clear, :get, :get?, :wait, :waitfor,
      :waitforre, :match, :matchwait, :goto
    )
  end
  let(:runtime) { Object.new.extend(runtime_module) }
  let(:script) { ScriptRuntimeHarness::FakeScript.new(name: 'alpha', lines: lines) }
  let(:lines) { [] }
  let(:script_output) { [] }
  let(:game_output) { [] }

  around do |example|
    original_client = $_CLIENT_
    original_detachable_client = $_DETACHABLE_CLIENT_

    example.run
  ensure
    $_CLIENT_ = original_client
    $_DETACHABLE_CLIENT_ = original_detachable_client
  end

  before do
    stub_const('Buffer', Class.new)
    Buffer.const_set(:SCRIPT_OUTPUT, :script_output)
    allow(Buffer).to receive(:update) { |line, _kind| script_output << line }

    stub_const('Frontend', Class.new)
    allow(Frontend).to receive(:supports_mono?).and_return(false)
    allow(Frontend).to receive(:client).and_return('stormfront')

    stub_const('Game', Class.new do
      def self.puts(_message); end
    end)
    allow(Game).to receive(:puts) { |message| game_output << message }

    stub_const('WizardScript', Class.new)

    $_CLIENT_ = nil
    $_DETACHABLE_CLIENT_ = nil

    allow(Script).to receive(:current).and_return(script)
    allow(Script).to receive(:new_script_output) { |line| script_output << "script:#{line}" }

    stub_const('Lich::Common::Script', Class.new)
    Lich::Common::Script.const_set(:JUMP, StandardError.new('JUMP'))
  end

  describe '#echo' do
    it 'prefixes messages with the current script name and returns nil' do
      expect(runtime.echo('hello')).to be_nil

      expect(script_output).to include('script:[alpha: hello]')
    end

    it 'does not emit messages when the script has no_echo set' do
      script.no_echo = true

      runtime.echo('hidden')

      expect(script_output).to be_empty
    end
  end

  describe '#respond' do
    it 'records each output line as script output and buffer output' do
      runtime.respond(['one', 'two'], 'three')

      expect(script_output).to include('script:one', 'one', 'script:two', 'two', 'script:three', 'three')
    end
  end

  describe '#put' do
    it 'sends each message to Game.puts' do
      runtime.put('look', 'health')

      expect(game_output).to eq(%w[look health])
    end
  end

  describe '#clear' do
    let(:lines) { %w[first second] }

    it 'returns a duplicate of the downstream buffer before clearing it' do
      previous = runtime.clear

      expect(previous).to eq(%w[first second])
      expect(script.downstream_buffer).to be_empty
    end
  end

  describe '#get and #get?' do
    let(:lines) { %w[first second] }

    it 'consumes a line with get' do
      expect(runtime.get).to eq('first')
      expect(script.downstream_buffer).to eq(['second'])
    end

    it 'peeks a line with get?' do
      expect(runtime.get?).to eq('first')
      expect(script.downstream_buffer).to eq(%w[first second])
    end
  end

  describe '#wait' do
    let(:lines) { %w[stale fresh] }

    it 'clears the script buffer before reading the next line' do
      expect(runtime.wait).to be_nil
      expect(script).to be_cleared
    end
  end

  describe '#waitfor' do
    let(:lines) { ['nothing here', 'The target arrives.'] }

    it 'returns the first matching line using case-insensitive string matching' do
      expect(runtime.waitfor('target')).to eq('The target arrives.')
    end
  end

  describe '#waitforre' do
    let(:lines) { ['nothing here', 'Roundtime: 3 sec.'] }

    it 'consumes lines until the regexp matches and returns nil' do
      result = runtime.waitforre(/Roundtime: (\d+)/)

      expect(result).to be_nil
      expect(script.downstream_buffer).to be_empty
    end
  end

  describe '#match and #matchwait' do
    it 'stores label/string pairs on the script match stack' do
      runtime.match('done', 'You are done')

      expect(script.match_stack_labels).to eq(['done'])
      expect(script.match_stack_strings).to eq(['You are done'])
    end

    it 'sets jump_label and raises the jump sentinel when the match stack fires' do
      script.downstream_buffer << 'You are done.'
      runtime.match('done', 'done')

      expect { runtime.matchwait }.to raise_error(StandardError, 'JUMP')
      expect(script.jump_label).to eq('done')
      expect(script.match_stack_labels).to be_empty
      expect(script.match_stack_strings).to be_empty
    end
  end
end
