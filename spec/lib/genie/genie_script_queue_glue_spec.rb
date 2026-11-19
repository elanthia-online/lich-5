# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/common/feature_flags'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'
require_relative '../../../lib/genie'
require_relative 'support/glue_autoinstall_off'

# The command-queue glue in lib/genie/genie_script.rb, loaded for real on Lich's real Script
# class (setup as in command_queue_lifecycle_spec.rb):
#   * after `;hmr genie` (HMR.reload `load`s lib/genie.rb, which resets
#     Lich::Genie's @command_queue / @global_store / @game_state) the memoized trigger runner
#     kept the OLD queue and store, so a #trigger's `#send` / `#queue` / `-N` went to a queue
#     nobody drains and its `#var` to a dropped store.
#   * the queue worker thread has no Script.current, so a released
#     `send` went out as "[(unknown script)]>cmd" and ignored the script's `silent`.
module GenieQueueGlueSpec
  GLUE_FILE = File.expand_path('../../../lib/genie/genie_script.rb', __dir__)
  GENIE_FILE = File.expand_path('../../../lib/genie.rb', __dir__)
  GLUE_CONSTANTS = %i[GenieScript LichScriptControl LichGamePort LichInputPort LichHookSink LichGameState].freeze

  def self.load_quietly(file)
    verbose = $VERBOSE
    $VERBOSE = nil # constant redefinitions on a re-load, exactly as HMR.reload produces them
    load file
  ensure
    $VERBOSE = verbose
  end
end

RSpec.describe 'Genie glue: command queue across a hot reload and on the worker thread' do
  before(:context) do
    require_relative '../../../lib/common/script'
    GenieQueueGlueSpec.load_quietly(GenieQueueGlueSpec::GLUE_FILE)
  end

  after(:context) do
    GenieQueueGlueSpec::GLUE_CONSTANTS.each { |name| Lich::Genie.send(:remove_const, name) if Lich::Genie.const_defined?(name, false) }
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  # The reload resets every Lich::Genie singleton; put the pre-example ones back so the
  # examples that follow in this process see the session they had.
  around do |example|
    saved = Lich::Genie.instance_variables.to_h { |name| [name, Lich::Genie.instance_variable_get(name)] }
    example.run
  ensure
    saved.each { |name, value| Lich::Genie.instance_variable_set(name, value) }
  end

  # The engine is on for the character (the hot paths' gate, Lich::Genie.engine_active?); the
  # turn-off examples say otherwise.
  before { allow(Lich::Genie).to receive(:engine_active?).and_return(true) }

  let(:glue) { Lich::Genie::GenieScript }

  def hot_reload!
    GenieQueueGlueSpec.load_quietly(GenieQueueGlueSpec::GENIE_FILE)
    GenieQueueGlueSpec.load_quietly(GenieQueueGlueSpec::GLUE_FILE)
  end

  describe 'after a hot reload of lib/genie.rb' do
    it 'sends a #trigger body\'s #send / #queue / -N to the rebuilt queue and its #var to the rebuilt store' do
      old_runner = glue.trigger_runner
      old_queue = Lich::Genie.command_queue
      old_store = Lich::Genie.global_store
      hot_reload!
      expect(Lich::Genie.command_queue).not_to be(old_queue)
      expect(Lich::Genie.global_store).not_to be(old_store)
      runner = glue.trigger_runner
      expect(runner).not_to be(old_runner)
      runner.run_command('#send 0 look;#queue 1 smile;-2 bow;#var wp4_hmr_probe 1')
      expect(Lich::Genie.command_queue.items.map(&:action)).to eq(%w[look smile bow])
      expect(old_queue).to be_empty
      expect(Lich::Genie.global_store.get('wp4_hmr_probe')).to eq('1')
      expect(old_store.get('wp4_hmr_probe')).to be_nil
    end

    it 'keeps one trigger runner while the session singletons stay, and rebuilds after reset_global_store!' do
      runner = glue.trigger_runner
      expect(glue.trigger_runner).to be(runner)
      Lich::Genie.reset_global_store!
      rebuilt = glue.trigger_runner
      expect(rebuilt).not_to be(runner)
      rebuilt.run_command('#var wp4_reset_probe 2')
      expect(Lich::Genie.global_store.get('wp4_reset_probe')).to eq('2')
    end

    it 'reads $webbed / $stunned for the queue gate from the live store, not the dropped one' do
      expect(glue.command_queue_state.webbed).to be(false)
      hot_reload!
      Lich::Genie.global_store.set('webbed', '1')
      Lich::Genie.global_store.set('stunned', '1')
      state = glue.command_queue_state
      expect([state.webbed, state.stunned]).to eq([true, true])
    end
  end

  describe 'a released command sent for its script' do
    let(:owner_class) { Struct.new(:name, :silent) }
    let(:wire) { [] }
    let(:shown) { [] }

    before do
      stub_const('Game', Module.new)
      sent = wire
      Game.define_singleton_method(:_puts) { |str| sent << str }
      displayed = shown
      allow_any_instance_of(Lich::Genie::LichGamePort).to receive(:respond) { |_port, text| displayed << text }
      allow_any_instance_of(Lich::Genie::LichGamePort).to receive(:put) { |_port, text| wire << "put:#{text}" }
    end

    it 'goes out labelled as the queuing script, through the client buffer, with the script\'s name' do
      glue.run_queued_command('look;smile', owner_class.new('hunt', false))
      expect(wire).to eq(%w[look smile])
      expect(shown).to eq(["[hunt]>look\r\n", "[hunt]>smile\r\n"])
      expect($_CLIENTBUFFER_.last(2)).to eq(["[hunt]>look\r\n", "[hunt]>smile\r\n"])
      expect($_LASTUPSTREAM_).to eq('[hunt]>smile')
      expect(Thread.current[Lich::Genie::GenieScript::QUEUE_OWNER_KEY]).to be_nil
    end

    it 'shows nothing for a silent script but still sends' do
      glue.run_queued_command('look', owner_class.new('quiet', true))
      expect(wire).to eq(['look'])
      expect(shown).to be_empty
    end

    it 'uses Lich\'s own put for an ownerless item (a #trigger body or typed command)' do
      glue.run_queued_command('look', nil)
      expect(wire).to eq(['put:look'])
    end

    it 'clears the owner even when the command raises, so a later ownerless send is not mislabelled' do
      allow(glue.trigger_runner).to receive(:run_command).and_raise(IOError, 'gone')
      expect { glue.run_queued_command('look', owner_class.new('hunt', false)) }.to raise_error(IOError)
      expect(Thread.current[Lich::Genie::GenieScript::QUEUE_OWNER_KEY]).to be_nil
    end
  end
end
