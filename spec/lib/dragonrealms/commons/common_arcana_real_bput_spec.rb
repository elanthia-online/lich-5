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
# that matches a line, so a custom message pattern that makes an empty match on
# a line makes bput return '' for that line. The examples use lookaheads for
# text on the line, such as '(?=A goblin)', which make an empty match only on
# lines containing that text, so DRCA.custom_message_pattern can't tell them
# from a real message and passes them through. bput tries the built-in
# messages before the custom ones, and handles its own retry replies (a wait,
# a stun...) before matching anything.
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

    it "returns '' on the first unrelated line when the custom prep message makes an empty match on it" do
      game('prepare fireball 10' => ['A goblin arrives.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You chant|(?=A goblin)')).to eq('')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "returns '' the same way for a custom_spell_prep fallback that makes an empty match on the line" do
      game('prepare fireball 10' => ['A goblin arrives.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, custom_spell_prep: '(?=A goblin)|You chant')).to eq('')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it 'still returns false when the first line is a failure the built-in list matches' do
      game('prepare fireball 10' => ['Something in the area interferes with your spell preparations'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You chant|(?=Something)')).to be false
    end

    it "returns the custom text, not '', when the first line starts with it" do
      game('prepare fireball 10' => ['You chant softly.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You chant|(?=A goblin)')).to eq('You chant')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "returns '' even on a line that starts with the custom text when the pattern's empty-matching branch comes first" do
      game('prepare fireball 10' => ['You chant softly.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, '(?=You chant)|You chant')).to eq('')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "returns '' when a per-spell message that makes an empty match on the line comes before a custom_spell_prep the line starts with" do
      game('prepare fireball 10' => ['You murmur the words.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, '(?=You murmur)', custom_spell_prep: 'You murmur')).to eq('')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "returns the whole line, not '', for a custom pattern that consumes the whole line, such as '.+'" do
      game('prepare fireball 10' => ['A goblin arrives.', 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, '.+')).to eq('A goblin arrives.')
      expect(buffer).to eq(['You begin to chant.'])
    end

    it "resends on a wait reply rather than returning '' for it" do
      replies = [['...wait 1 seconds.'], ['You begin to chant.']]
      allow(drc).to receive(:put) do |message|
        sent << message
        arrive(*(replies.shift || []))
      end
      allow(drc).to receive(:get?) { buffer.shift }
      expect(drca.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You chant|(?=\.\.\.wait)')).to eq('You begin to')
      expect(sent).to eq(['prepare fireball 10', 'prepare fireball 10'])
    end

    it "resends on a type-ahead reply rather than returning '' for it" do
      replies = [['Sorry, you may only type ahead 1 command.'], ['You begin to chant.']]
      allow(drc).to receive(:put) do |message|
        sent << message
        arrive(*(replies.shift || []))
      end
      allow(drc).to receive(:get?) { buffer.shift }
      expect(drca.prepare?('fireball', 10, custom_spell_prep: '(?=Sorry)|You chant')).to eq('You begin to')
      expect(sent).to eq(['prepare fireball 10', 'prepare fireball 10'])
    end

    it "reads past the can't-move line when no message matches it" do
      game('prepare fireball 10' => ["You don't seem to be able to move to do that.", 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, custom_spell_prep: 'You chant')).to eq('You begin to')
      expect(sent).to eq(['prepare fireball 10'])
    end

    it "returns '' for the can't-move line, as for any other line, when the custom prep message makes an empty match on it" do
      game('prepare fireball 10' => ["You don't seem to be able to move to do that.", 'You begin to chant.'])
      expect(drca.prepare?('fireball', 10, custom_spell_prep: "(?=You don't)|You chant")).to eq('')
      expect(buffer).to eq(['You begin to chant.'])
      expect(sent).to eq(['prepare fireball 10'])
    end
  end

  describe '.cast?' do
    it 'returns false when a failure line follows an unrelated line and no custom message makes an empty match' do
      game(
        'cast'         => ['A goblin arrives.', 'Something is interfering with the spell', 'You gesture.'],
        'release mana' => ["You aren't harnessing any mana"]
      )
      expect(drca.cast?('cast', false, [], [], 'You gesture')).to be false
      expect(sent).to eq(['cast', 'release mana'])
    end

    it "still returns false with a custom cast message that makes an empty match on the unrelated line when the failure line has arrived behind the unrelated line" do
      game(
        'cast'         => ['A goblin arrives.', 'Something is interfering with the spell', 'You gesture.'],
        'release mana' => ["You aren't harnessing any mana"]
      )
      expect(drca.cast?('cast', false, [], [], 'You gesture|(?=A goblin)')).to be false
      expect(sent).to eq(['cast', 'release mana'])
    end

    it "returns true on the first unrelated line when the custom cast message makes an empty match on it, missing a failure line that arrives after the flag read" do
      game('cast' => ['A goblin arrives.'])
      expect(drca.cast?('cast', false, [], [], 'You gesture|(?=A goblin)')).to be true
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
      expect(drca.cast?('cast', false, [], [], 'You gesture|(?=A goblin)')).to be true
      expect(drca.cast?('cast', false, [], [], 'You gesture|(?=A goblin)')).to be false
      expect(sent).to eq(['cast', 'cast', 'release mana'])
    end
  end
end
