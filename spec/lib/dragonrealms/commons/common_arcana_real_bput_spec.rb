# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../../lib/dragonrealms/commons/common'
require_relative '../../../../lib/dragonrealms/commons/common-arcana'

# DRCA.prepare? and DRCA.cast? run through the real DRC.bput here, against a
# small model of the game stream: each send queues that send's replies and
# get? reads them back in order. A queued line has arrived, so it also sets any
# Flag whose registered pattern it matches, as DRParser.check_events does in
# the game thread whether or not the script ever reads the line.
# common_arcana_spec.rb stubs DRC.bput, so this file pins what only the real
# bput decides: bput returns the leftmost match of the first message pattern
# that matches a line, so a custom message pattern that can match an empty
# string makes bput return '' on any line where the first custom pattern that
# matches it matches empty ('You chant|' on a line not starting with
# 'You chant', '|You chant' on every line). bput tries the built-in messages
# before the custom ones, and handles its own retry replies (a wait, a
# stun...) before matching anything.
RSpec.describe 'DRCA spell helpers through the real DRC.bput' do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drca) { Lich::DragonRealms::DRCA }
  let(:buffer) { [] }
  let(:sent) { [] }
  let(:spell_data) do
    OpenStruct.new(
      prep_messages: ['You begin to', 'Something in the area interferes with your spell preparations'],
      cast_messages: ['You gesture', 'Your target pattern dissipates'],
      invoke_messages: ['Your cambrinth absorbs', 'Invoke what?']
    )
  end

  before do
    Flags.reset!
    drca.instance_variable_set(:@backfired_status, false)
    allow(drca).to receive(:get_data).and_return(spell_data)
    allow(drca).to receive(:waitrt?)
    allow(drca).to receive(:pause)
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:pause) { |_seconds| sleep(0.001) }
  end

  def game(replies)
    allow(drc).to receive(:put) do |message|
      sent << message
      arrive(*Array(replies[message]))
    end
    allow(drc).to receive(:get?) { buffer.shift }
  end

  # A line arriving from the game: queue it for get? and set the Flags it
  # matches, at arrival rather than when the script reads it.
  def arrive(*lines)
    lines.each do |line|
      Flags.matchers.each do |name, patterns|
        match = patterns.lazy.map { |pattern| line.match(pattern) }.find(&:itself)
        Flags[name] = match if match
      end
      buffer << line
    end
  end

  describe '.prepare?' do
    it "returns the listed prep message when a custom message cannot match ''" do
      game('prepare fireball 10' => ['A goblin arrives.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You chant')).to eq('You begin to')
      expect(buffer).to be_empty
    end

    it "returns '' on the first unrelated line when the custom prep message can match ''" do
      game('prepare fireball 10' => ['A goblin arrives.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You chant|')).to eq('')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "returns '' the same way for an empty-matching custom_spell_prep fallback" do
      game('prepare fireball 10' => ['A goblin arrives.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, custom_spell_prep: '|You chant')).to eq('')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it 'still returns false when the first line is a failure the built-in list matches' do
      game('prepare fireball 10' => ['Something in the area interferes with your spell preparations'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You chant|')).to be false
    end

    it "returns the custom text, not '', when the first line starts with it" do
      game('prepare fireball 10' => ['You chant softly.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You chant|')).to eq('You chant')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "returns '' even on a line that starts with the custom text when the pattern's empty branch comes first" do
      game('prepare fireball 10' => ['You chant softly.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, '|You chant')).to eq('')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "returns '' when an empty-matching per-spell message comes before a custom_spell_prep the line starts with" do
      game('prepare fireball 10' => ['You murmur the words.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'xyz|', custom_spell_prep: 'You murmur')).to eq('')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "returns the whole line, not '', for a custom pattern whose leftmost match on it is not empty" do
      game('prepare fireball 10' => ['A goblin arrives.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, '.*')).to eq('A goblin arrives.')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "resends on a wait reply rather than returning '' for it" do
      replies = [['...wait 1 seconds.'], ['You begin to chant.']]
      allow(drc).to receive(:put) do |message|
        sent << message
        arrive(*(replies.shift || []))
      end
      allow(drc).to receive(:get?) { buffer.shift }
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You chant|')).to eq('You begin to')
      expect(sent).to eq(['prepare fireball 10', 'prepare fireball 10'])
    end

    it "resends on a type-ahead reply rather than returning '' for it" do
      replies = [['Sorry, you may only type ahead 1 command.'], ['You begin to chant.']]
      allow(drc).to receive(:put) do |message|
        sent << message
        arrive(*(replies.shift || []))
      end
      allow(drc).to receive(:get?) { buffer.shift }
      expect(drca.prepare?('fireball', 10, custom_spell_prep: '|You chant')).to eq('You begin to')
      expect(sent).to eq(['prepare fireball 10', 'prepare fireball 10'])
    end

    it "skips the can't-move line rather than returning '' for it" do
      game('prepare fireball 10' => ["You don't seem to be able to move to do that.", 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, custom_spell_prep: '|You chant')).to eq('You begin to')
      expect(sent).to eq(['prepare fireball 10'])
    end
  end

  describe '.cast?' do
    it 'returns false when a failure line follows an unrelated line and no custom message can match empty' do
      game(
        'cast'         => ['A goblin arrives.', 'Something is interfering with the spell', 'You gesture.'],
        'release mana' => ["You aren't harnessing any mana"]
      )
      expect(drca.cast?('cast', false, [], [], 'You gesture')).to be false
      expect(sent).to eq(['cast', 'release mana'])
    end

    it "still returns false with a custom cast message that can match '' when the failure line has arrived behind the unrelated line" do
      game(
        'cast'         => ['A goblin arrives.', 'Something is interfering with the spell', 'You gesture.'],
        'release mana' => ["You aren't harnessing any mana"]
      )
      expect(drca.cast?('cast', false, [], [], 'You gesture|')).to be false
      expect(sent).to eq(['cast', 'release mana'])
    end

    it "returns true on the first unrelated line when the custom cast message can match '', missing a failure line that arrives after the flag read" do
      game('cast' => ['A goblin arrives.'])
      expect(drca.cast?('cast', false, [], [], 'You gesture|')).to be true
      expect(sent).to eq(['cast'])
      arrive('Something is interfering with the spell')
      expect(Flags['spell-fail']).to be_truthy
    end

    it 'fails the next cast when a missed failure line arrives while that cast is running' do
      replies = [['A goblin arrives.'], ['Something is interfering with the spell', 'You gesture.']]
      allow(drc).to receive(:put) do |message|
        sent << message
        arrive(*(message == 'cast' ? replies.shift : ["You aren't harnessing any mana"]))
      end
      allow(drc).to receive(:get?) { buffer.shift }
      expect(drca.cast?('cast', false, [], [], 'You gesture|')).to be true
      expect(drca.cast?('cast', false, [], [], 'You gesture|')).to be false
      expect(sent).to eq(['cast', 'cast', 'release mana'])
    end
  end

  # prep_confirmed? (used by ritual and cast_spell) reads the prepared-spell
  # indicator, which the game sets on the same line as its prep reply. Here a
  # prep reply can be held back until the script pauses, as a reply that lands
  # just after bput returned would be, and it sets the indicator when it
  # arrives.
  describe '.ritual after an empty-matching custom prep message' do
    let(:settings) { OpenStruct.new(ignored_npcs: [], custom_spell_prep: nil) }
    let(:data) do
      { 'abbrev' => 'fireball', 'mana' => 10, 'skip_retreat' => true, 'focus' => 'totem', 'cast' => 'cast',
        'before' => [], 'after' => [], 'custom_prep_message' => 'You chant|' }
    end
    let(:held_back) { [] }

    before do
      Lich::Messaging.clear_messages!
      @indicator = 'None'
      allow(XMLData).to receive(:prepared_spell) { @indicator }
      allow(drc).to receive(:release_invisibility)
      allow(drca).to receive(:find_focus)
      allow(drca).to receive(:invoke)
      allow(drca).to receive(:stow_focus)
      allow(drca).to receive(:waitcastrt?)
      allow(drca).to receive(:pause) do |_seconds|
        line = held_back.shift
        next unless line

        @indicator = 'Fire Ball'
        arrive(line)
      end
    end

    it 'goes on to the focus and the cast when the prep reply lands during the wait' do
      game('prepare fireball 10' => ['A goblin arrives.'], 'cast' => ['You gesture.'])
      held_back << 'You begin to chant.'
      drca.ritual(data, settings)
      expect(drca).to have_received(:invoke).with('totem', nil, nil)
      expect(sent).to eq(['prepare fireball 10', 'cast'])
    end

    it 'stops without touching the focus or casting when no prep reply lands' do
      game('prepare fireball 10' => ['A goblin arrives.'])
      expect(drca.ritual(data, settings)).to be_nil
      expect(drca).not_to have_received(:find_focus)
      expect(sent).to eq(['prepare fireball 10'])
      expect(Lich::Messaging.messages.map { |m| m[:message] }).to include("DRCA: no prep reply was recognised for 'fireball' and no spell is being prepared - not casting")
    end
  end
end
