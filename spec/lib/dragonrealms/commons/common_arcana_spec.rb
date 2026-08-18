# frozen_string_literal: true

require_relative '../../../spec_helper'

# Ensure XMLData has prepared_spell accessor for tests
unless XMLData.respond_to?(:prepared_spell=)
  XMLData.singleton_class.attr_accessor(:prepared_spell)
end

# Helper to extract bold messages from Lich::Messaging captures
def bold_messages
  Lich::Messaging.messages.select { |m| m[:type] == 'bold' }.map { |m| m[:message] }
end

# Override get_data for this spec with DRCA-specific data (barb_abilities)
def get_data(_type)
  @mock_data ||= OpenStruct.new(
    prep_messages: ['You begin to', 'But you\'ve already prepared', 'Your desire to prepare this offensive spell suddenly slips away', 'Something in the area interferes with your spell preparations'],
    cast_messages: ['You gesture', 'Your target pattern dissipates'],
    invoke_messages: ['Your cambrinth absorbs', 'you find it too clumsy', 'Invoke what?'],
    charge_messages: ['Your cambrinth absorbs all of the energy', 'You are in no condition to do that', 'You\'ll have to hold it', 'you find it too clumsy'],
    segue_messages: ['You segue', 'You must be performing a cyclic spell to segue from', 'It is too soon to segue'],
    khri_preps: ['You focus your mind', 'Your mind and body are willing', 'Your body is willing'],
    spell_data: {},
    barb_abilities: {
      'Famine' => { 'type' => 'meditation', 'start_command' => 'meditate famine', 'activated_message' => 'You feel hungry' }
    }
  )
end

# Load the module under test
require_relative '../../../../lib/dragonrealms/commons/common-arcana'

DRCA = Lich::DragonRealms::DRCA unless defined?(DRCA)

RSpec.describe Lich::DragonRealms::DRCA do
  before(:each) do
    Lich::Messaging.clear_messages!
    DRSpells.active_spells = {}
    Flags.reset!
    allow(DRCMM).to receive(:update_astral_data) { |data, _settings| data }
    allow(DRC).to receive(:bput).and_return('default')
  end

  # ----------------------------------------------
  # Constants
  # ----------------------------------------------
  describe 'constants' do
    it 'freezes CYCLIC_RELEASE_SUCCESS_PATTERNS' do
      expect(DRCA::CYCLIC_RELEASE_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes INFUSE_OM_SUCCESS_PATTERNS' do
      expect(DRCA::INFUSE_OM_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes INFUSE_OM_FAILURE_PATTERNS' do
      expect(DRCA::INFUSE_OM_FAILURE_PATTERNS).to be_frozen
    end

    it 'freezes WIELD_FOCUS_SUCCESS_PATTERNS' do
      expect(DRCA::WIELD_FOCUS_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes WIELD_FOCUS_FAILURE_PATTERNS' do
      expect(DRCA::WIELD_FOCUS_FAILURE_PATTERNS).to be_frozen
    end

    it 'freezes SHEATHE_FOCUS_SUCCESS_PATTERNS' do
      expect(DRCA::SHEATHE_FOCUS_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes SHEATHE_FOCUS_FAILURE_PATTERNS' do
      expect(DRCA::SHEATHE_FOCUS_FAILURE_PATTERNS).to be_frozen
    end

    it 'defines retry limits as positive integers' do
      expect(DRCA::INFUSE_OM_MAX_RETRIES).to be_a(Integer).and be > 0
      expect(DRCA::PREPARE_MAX_RETRIES).to be_a(Integer).and be > 0
      expect(DRCA::CAST_MAX_RETRIES).to be_a(Integer).and be > 0
      expect(DRCA::BARB_BUFF_MAX_RETRIES).to be_a(Integer).and be > 0
      expect(DRCA::STOW_FOCUS_MAX_RETRIES).to be_a(Integer).and be > 0
    end

    it 'contains regex patterns in CYCLIC_RELEASE_SUCCESS_PATTERNS' do
      DRCA::CYCLIC_RELEASE_SUCCESS_PATTERNS.each do |pattern|
        expect(pattern).to be_a(Regexp)
      end
    end

    it 'freezes STARLIGHT_MESSAGES' do
      expect(DRCA::STARLIGHT_MESSAGES).to be_frozen
    end

    it 'freezes CHARGE_LEVELS' do
      expect(DRCA::CHARGE_LEVELS).to be_frozen
    end

    it 'freezes USELESS_RUNESTONE_PATTERNS' do
      expect(DRCA::USELESS_RUNESTONE_PATTERNS).to be_frozen
    end

    it 'freezes GET_RUNESTONE_SUCCESS_PATTERNS' do
      expect(DRCA::GET_RUNESTONE_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes GET_RUNESTONE_FAILURE_PATTERNS' do
      expect(DRCA::GET_RUNESTONE_FAILURE_PATTERNS).to be_frozen
    end

    it 'defines named capture patterns' do
      expect(DRCA::SYMBIOSIS_PATTERN).to be_a(Regexp)
      expect(DRCA::DISCERN_SORCERY_PATTERN).to be_a(Regexp)
      expect(DRCA::DISCERN_FULL_PATTERN).to be_a(Regexp)
      expect(DRCA::PERC_MANA_START_PATTERN).to be_a(Regexp)
      expect(DRCA::PERC_MANA_END_PATTERN).to be_a(Regexp)
    end
  end

  # ----------------------------------------------
  # infuse_om
  # ----------------------------------------------
  describe '.infuse_om' do
    it 'returns early when Osrel Meraud is not active' do
      DRSpells.active_spells = {}
      expect(DRC).not_to receive(:bput).with(/infuse om/, anything, anything)
      DRCA.infuse_om(true, 10)
    end

    it 'returns early when Osrel Meraud is at or above 90' do
      DRSpells.active_spells = { 'Osrel Meraud' => 91 }
      expect(DRC).not_to receive(:bput).with(/infuse om/, anything, anything)
      DRCA.infuse_om(true, 10)
    end

    it 'returns early when amount is nil' do
      DRSpells.active_spells = { 'Osrel Meraud' => 50 }
      expect(DRC).not_to receive(:bput).with(/infuse om/, anything, anything)
      DRCA.infuse_om(true, nil)
    end

    it 'stops infusing after a successful full-capacity response without looping' do
      DRSpells.active_spells = { 'Osrel Meraud' => 50 }
      allow(DRStats).to receive(:mana).and_return(100)
      allow(DRC).to receive(:bput).with(/infuse om/, anything, anything).and_return('having reached its full capacity')
      DRCA.infuse_om(false, 10)
      # No exception means it didn't infinite loop
    end

    it 'gives up after INFUSE_OM_MAX_RETRIES' do
      DRSpells.active_spells = { 'Osrel Meraud' => 50 }
      allow(DRStats).to receive(:mana).and_return(100)
      allow(DRC).to receive(:bput).with(/infuse om/, anything, anything).and_return('as if it hungers for more')
      DRCA.infuse_om(false, 10)
      expect(bold_messages.any? { |m| m.include?('infuse_om exhausted') }).to be true
    end
  end

  # ----------------------------------------------
  # harness? / harness_mana
  # ----------------------------------------------
  describe '.harness?' do
    it 'returns truthy on success' do
      allow(DRC).to receive(:bput).with(/harness/, anything, anything).and_return('You tap into')
      expect(DRCA.harness?(10)).to be_truthy
    end

    it 'returns falsy on failure' do
      allow(DRC).to receive(:bput).with(/harness/, anything, anything).and_return('Strain though you may')
      expect(DRCA.harness?(10)).to be_falsy
    end
  end

  describe '.harness_mana' do
    it 'stops on first failure' do
      call_count = 0
      allow(DRC).to receive(:bput).with(/harness/, anything, anything) do
        call_count += 1
        call_count == 1 ? 'You tap into' : 'Strain though you may'
      end
      DRCA.harness_mana([10, 20, 30])
      expect(call_count).to eq(2)
    end
  end

  # ----------------------------------------------
  # activate_barb_buff?
  # ----------------------------------------------
  describe '.activate_barb_buff?' do
    it 'returns true when ability is already active' do
      DRSpells.active_spells = { 'Famine' => 300 }
      expect(DRCA.activate_barb_buff?('Famine')).to be true
    end

    it 'returns false when max retries exhausted' do
      DRSpells.active_spells = {}
      allow(DRC).to receive(:bput).with('meditate famine', anything, anything, anything, anything, anything, anything, anything, anything, anything).and_return('You must be unengaged')
      result = DRCA.activate_barb_buff?('Famine', 20, false, retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('activate_barb_buff? exhausted') }).to be true
    end

    it 'returns true on successful activation' do
      DRSpells.active_spells = {}
      allow(DRC).to receive(:bput).with('meditate famine', anything, anything, anything, anything, anything, anything, anything, anything, anything).and_return('You feel hungry')
      result = DRCA.activate_barb_buff?('Famine', nil, false)
      expect(result).to be true
    end
  end

  # ----------------------------------------------
  # prepare?
  # ----------------------------------------------
  describe '.prepare?' do
    it 'returns false for nil abbrev' do
      expect(DRCA.prepare?(nil, 10)).to be false
    end

    it 'returns match on successful prep' do
      allow(DRC).to receive(:bput).with(/prepare/, anything).and_return('You begin to')
      result = DRCA.prepare?('fireball', 10)
      expect(result).to eq('You begin to')
    end

    it 'retries on offensive spell slip and gives up at 0 retries' do
      allow(DRC).to receive(:bput).with(/prepare/, anything).and_return('Your desire to prepare this offensive spell suddenly slips away')
      result = DRCA.prepare?('fireball', 10, false, 'prepare', false, nil, false, nil, retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('prepare? exhausted') }).to be true
    end

    it 'returns false on area interference' do
      allow(DRC).to receive(:bput).with(/prepare/, anything).and_return('Something in the area interferes with your spell preparations')
      expect(DRCA.prepare?('fireball', 10)).to be false
    end
  end

  # ----------------------------------------------
  # adversarial: the shared guard that compiles player-supplied messages. Hostile
  # inputs must be dropped (nil), never crash and never compile to // (which would
  # match every line and corrupt bput).
  # ----------------------------------------------
  describe '#custom_message_pattern (shared guard)' do
    it 'drops nil' do
      expect(DRCA.custom_message_pattern(nil)).to be_nil
    end

    it 'drops non-string types (number, array, hash, boolean) rather than crashing' do
      [42, ['a message'], { 'from' => 'to' }, true].each do |hostile|
        expect(DRCA.custom_message_pattern(hostile)).to be_nil
      end
    end

    it 'drops empty and whitespace-only strings so they cannot compile to //' do
      ['', '   ', "\t", "\n ", " \t\n "].each do |blank|
        expect(DRCA.custom_message_pattern(blank)).to be_nil
      end
    end

    it 'drops invalid regular expressions instead of raising' do
      ['oops(', 'a[b', '*repeat', '(?<broken'].each do |malformed|
        expect { DRCA.custom_message_pattern(malformed) }.not_to raise_error
        expect(DRCA.custom_message_pattern(malformed)).to be_nil
      end
    end

    it 'compiles a valid message case-insensitively' do
      pattern = DRCA.custom_message_pattern('Your Focus Hums')
      expect(pattern).to be_a(Regexp)
      expect('your focus hums loudly').to match(pattern)
      expect('YOUR FOCUS HUMS').to match(pattern)
    end

    it 'trims surrounding whitespace so an accidental yaml space still matches' do
      pattern = DRCA.custom_message_pattern("   You murmur   ")
      expect(pattern.source).to eq('You murmur')
      expect('You murmur an incantation').to match(pattern)
    end

    it 'preserves regex metacharacters supplied by the player' do
      pattern = DRCA.custom_message_pattern('You (cup|wave) your (left|right) hand')
      expect('You cup your left hand').to match(pattern)
      expect('You wave your right hand').to match(pattern)
    end
  end

  # ----------------------------------------------
  # adversarial: the merge helper. A mix of valid/invalid/hostile customs must
  # yield base + only-the-valid patterns, in order, without mutating the base.
  # ----------------------------------------------
  describe '#with_custom_messages (merge helper)' do
    it 'appends only the valid custom patterns, in order, after the base list' do
      result = DRCA.with_custom_messages(['base one', 'base two'], 'first', '', 'bad(', nil, 42, 'second')
      expect(result[0, 2]).to eq(['base one', 'base two'])
      customs = result[2..]
      expect(customs).to all(be_a(Regexp))
      expect(customs.map(&:source)).to eq(%w[first second])
    end

    it 'returns the base list unchanged when no custom message is valid' do
      expect(DRCA.with_custom_messages(['only base'], nil, '', '   ', 5)).to eq(['only base'])
    end

    it 'does not mutate the base list it was given' do
      base = ['do not touch']
      DRCA.with_custom_messages(base, 'added')
      expect(base).to eq(['do not touch'])
    end

    it 'keeps a custom that duplicates a built-in (dedup is left to config validation)' do
      result = DRCA.with_custom_messages(['You gesture'], 'You gesture')
      expect(result[0]).to eq('You gesture')
      expect(result[1]).to be_a(Regexp)
      expect(result[1].source).to eq('You gesture')
    end
  end

  # ----------------------------------------------
  # custom invoke message: per-character custom_invoke_message (single), appended
  # to the built-in list by #invoke_messages (dropped if blank/invalid)
  # ----------------------------------------------
  describe 'custom invoke message (custom_invoke_message key)' do
    it 'returns just the built-in list when no custom message is set' do
      allow(DRCA).to receive(:get_settings).and_return(OpenStruct.new)
      expect(DRCA.invoke_messages).to eq(get_data('spells').invoke_messages)
    end

    it 'appends a valid custom_invoke_message as a case-insensitive pattern' do
      allow(DRCA).to receive(:get_settings).and_return(OpenStruct.new(custom_invoke_message: 'Your artifact hums'))
      result = DRCA.invoke_messages
      expect(result).to include('Your cambrinth absorbs') # built-in string preserved
      pattern = result.find { |m| m.is_a?(Regexp) && m.source == 'Your artifact hums' }
      expect(pattern).not_to be_nil
      expect(pattern.options & Regexp::IGNORECASE).not_to eq(0) # matches like the built-ins
    end

    it 'drops a blank custom_invoke_message so it cannot compile to // (match anything)' do
      allow(DRCA).to receive(:get_settings).and_return(OpenStruct.new(custom_invoke_message: '   '))
      expect(DRCA.invoke_messages).to eq(get_data('spells').invoke_messages)
    end

    it 'drops a malformed-regex custom_invoke_message instead of raising in bput' do
      allow(DRCA).to receive(:get_settings).and_return(OpenStruct.new(custom_invoke_message: 'bad(regex'))
      expect { DRCA.invoke_messages }.not_to raise_error
      expect(DRCA.invoke_messages).to eq(get_data('spells').invoke_messages)
    end

    it 'merges the per-character setting and a per-spell custom invoke message' do
      allow(DRCA).to receive(:get_settings).and_return(OpenStruct.new(custom_invoke_message: 'Your focus hums'))
      result = DRCA.invoke_messages('The runestone flares')
      expect(result.any? { |m| m.is_a?(Regexp) && m.source == 'Your focus hums' }).to be true
      expect(result.any? { |m| m.is_a?(Regexp) && m.source == 'The runestone flares' }).to be true
    end

    it 'drops a list given under the singular key (it is a single string) rather than misapplying it' do
      allow(DRCA).to receive(:get_settings).and_return(OpenStruct.new(custom_invoke_message: %w[one two]))
      expect(DRCA.invoke_messages).to eq(get_data('spells').invoke_messages)
    end

    # End-to-end: exercise invoke / prepare? through the REAL invoke_messages
    # (no stubbing the method under test), proving the configured message reaches bput.
    it 'invoke feeds the real merged messages (built-ins + per-character setting) to bput' do
      allow(DRCA).to receive(:get_settings).and_return(OpenStruct.new(custom_invoke_message: 'Your artifact hums'))
      captured = nil
      allow(DRC).to receive(:bput).with(/^invoke my cambrinth/, anything, 'Invoke what?') { |_cmd, matches, _fallback| captured = matches; 'Your cambrinth absorbs' }
      DRCA.invoke('cambrinth', nil, nil)
      expect(captured).to include('Invoke what?') # a built-in invoke message
      expect(captured.any? { |m| m.is_a?(Regexp) && m.source == 'Your artifact hums' }).to be true
    end

    it 'runestone prepare feeds the real merged messages (built-ins + per-character + per-spell) to bput' do
      allow(DRCA).to receive(:get_settings).and_return(OpenStruct.new(custom_invoke_message: 'Your artifact hums'))
      captured = nil
      allow(DRC).to receive(:bput).with(/^prepare my rune/, anything) { |_cmd, matches| captured = matches; 'Your cambrinth absorbs' }
      DRCA.prepare?('fireball', 10, false, 'prepare', false, 'rune', false, nil, custom_invoke_message: 'The runestone flares')
      expect(captured).to include('Invoke what?') # built-in
      expect(captured.any? { |m| m.is_a?(Regexp) && m.source == 'Your artifact hums' }).to be true # per-character
      expect(captured.any? { |m| m.is_a?(Regexp) && m.source == 'The runestone flares' }).to be true # per-spell
    end
  end

  # ----------------------------------------------
  # per-spell custom_prep_message / custom_cast_message / custom_invoke_message keys
  # (declared in a spell's waggle entry): validated and appended to the built-in
  # prep / cast / invoke messages by prepare? / cast?
  # ----------------------------------------------
  describe 'per-spell custom_prep_message / custom_cast_message / custom_invoke_message keys' do
    let(:cast_spell_settings) do
      OpenStruct.new(
        cambrinth_items: [{ 'name' => nil }],
        cambrinth: 'armband',
        cambrinth_cap: 50,
        stored_cambrinth: false,
        use_harness_when_arcana_locked: false,
        dedicated_camb_use: nil,
        cambrinth_invoke_exact_amount: nil,
        custom_spell_prep: 'GLOBAL PREP FALLBACK'
      )
    end

    it 'appends a valid custom_prep_message as a case-insensitive pattern' do
      captured = nil
      allow(DRC).to receive(:bput).with(/^prepare fireball/, anything) { |_cmd, matches| captured = matches; 'You begin to' }
      DRCA.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'You murmur an incantation')
      expect(captured).to include('You begin to') # built-in prep message still present
      pattern = captured.find { |m| m.is_a?(Regexp) && m.source == 'You murmur an incantation' }
      expect(pattern).not_to be_nil
      expect(pattern.options & Regexp::IGNORECASE).not_to eq(0)
    end

    it 'drops a blank custom_prep_message instead of matching every line' do
      captured = nil
      allow(DRC).to receive(:bput).with(/^prepare fireball/, anything) { |_cmd, matches| captured = matches; 'You begin to' }
      DRCA.prepare?('fireball', 10, false, 'prepare', false, nil, false, '   ')
      expect(captured).to eq(get_data('spells').prep_messages)
    end

    it 'drops a malformed-regex custom_prep_message instead of crashing' do
      captured = nil
      allow(DRC).to receive(:bput).with(/^prepare fireball/, anything) { |_cmd, matches| captured = matches; 'You begin to' }
      expect { DRCA.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'oops(') }.not_to raise_error
      expect(captured).to eq(get_data('spells').prep_messages)
    end

    it 'cast_spell sources custom_prep_message from the spell data' do
      data = { 'abbrev' => 'fb', 'mana' => 10, 'cambrinth' => [5], 'prep_time' => 0, 'custom_prep_message' => 'PER SPELL PREP' }
      captured_prep = nil
      allow(DRCA).to receive(:prepare?) { |*args, **_kwargs| captured_prep = args[7]; 'You begin to' }
      allow(DRCA).to receive(:cast?).and_return(true)
      allow(DRCA).to receive(:find_charge_invoke_stow)
      DRCA.cast_spell(data, cast_spell_settings)
      expect(captured_prep).to eq('PER SPELL PREP')
    end

    it 'cast_spell passes the global custom_spell_prep to prepare? as the validated fallback' do
      data = { 'abbrev' => 'fb', 'mana' => 10, 'cambrinth' => [5], 'prep_time' => 0 }
      captured = nil
      allow(DRCA).to receive(:prepare?) { |*_args, **kwargs| captured = kwargs[:custom_spell_prep]; 'You begin to' }
      allow(DRCA).to receive(:cast?).and_return(true)
      allow(DRCA).to receive(:find_charge_invoke_stow)
      DRCA.cast_spell(data, cast_spell_settings)
      expect(captured).to eq('GLOBAL PREP FALLBACK')
    end

    # Regression (CodeRabbit P2): a blank/invalid per-spell message must NOT
    # suppress a valid global custom_spell_prep. They are validated independently.
    it 'still applies a valid global custom_spell_prep when the per-spell message is blank' do
      captured = nil
      allow(DRC).to receive(:bput).with(/^prepare fireball/, anything) { |_cmd, matches| captured = matches; 'You begin to' }
      DRCA.prepare?('fireball', 10, false, 'prepare', false, nil, false, '   ', custom_spell_prep: 'Valid global prep')
      expect(captured.any? { |m| m.is_a?(Regexp) && m.source == 'Valid global prep' }).to be true
    end

    it 'still applies a valid global custom_spell_prep when the per-spell message is invalid regex' do
      captured = nil
      allow(DRC).to receive(:bput).with(/^prepare fireball/, anything) { |_cmd, matches| captured = matches; 'You begin to' }
      DRCA.prepare?('fireball', 10, false, 'prepare', false, nil, false, 'bad(', custom_spell_prep: 'Valid global prep')
      expect(captured.any? { |m| m.is_a?(Regexp) && m.source == 'Valid global prep' }).to be true
    end

    it 'appends a valid custom_cast_message as a case-insensitive pattern' do
      captured = nil
      allow(DRC).to receive(:bput).with('cast', anything) { |_cmd, matches| captured = matches; 'You gesture' }
      DRCA.cast?('cast', false, [], [], 'A rare shimmer surrounds you')
      expect(captured).to include('You gesture') # built-in cast message still present
      pattern = captured.find { |m| m.is_a?(Regexp) && m.source == 'A rare shimmer surrounds you' }
      expect(pattern).not_to be_nil
      expect(pattern.options & Regexp::IGNORECASE).not_to eq(0)
    end

    it 'drops a blank custom_cast_message instead of matching every line' do
      captured = nil
      allow(DRC).to receive(:bput).with('cast', anything) { |_cmd, matches| captured = matches; 'You gesture' }
      DRCA.cast?('cast', false, [], [], '   ')
      expect(captured).to eq(get_data('spells').cast_messages)
    end

    it 'drops a malformed-regex custom_cast_message instead of crashing' do
      captured = nil
      allow(DRC).to receive(:bput).with('cast', anything) { |_cmd, matches| captured = matches; 'You gesture' }
      expect { DRCA.cast?('cast', false, [], [], 'oops(') }.not_to raise_error
      expect(captured).to eq(get_data('spells').cast_messages)
    end

    it 'cast_spell sources custom_cast_message from the spell data' do
      data = { 'abbrev' => 'fb', 'mana' => 10, 'cambrinth' => [5], 'prep_time' => 0, 'custom_cast_message' => 'PER SPELL CAST' }
      captured_cast = nil
      allow(DRCA).to receive(:prepare?).and_return('You begin to')
      allow(DRCA).to receive(:cast?) { |*args| captured_cast = args[4]; true }
      allow(DRCA).to receive(:find_charge_invoke_stow)
      DRCA.cast_spell(data, cast_spell_settings)
      expect(captured_cast).to eq('PER SPELL CAST')
    end

    it 'cast_spell sources custom_invoke_message from the spell data' do
      data = { 'abbrev' => 'fb', 'mana' => 10, 'cambrinth' => [5], 'prep_time' => 0, 'custom_invoke_message' => 'PER SPELL INVOKE' }
      captured = nil
      allow(DRCA).to receive(:prepare?) { |*_args, **kwargs| captured = kwargs[:custom_invoke_message]; 'You begin to' }
      allow(DRCA).to receive(:cast?).and_return(true)
      allow(DRCA).to receive(:find_charge_invoke_stow)
      DRCA.cast_spell(data, cast_spell_settings)
      expect(captured).to eq('PER SPELL INVOKE')
    end

    it 'ignores a non-string custom_prep_message without crashing prepare?' do
      captured = nil
      allow(DRC).to receive(:bput).with(/^prepare fireball/, anything) { |_cmd, matches| captured = matches; 'You begin to' }
      expect { DRCA.prepare?('fireball', 10, false, 'prepare', false, nil, false, 42) }.not_to raise_error
      expect(captured).to eq(get_data('spells').prep_messages)
    end

    it 'ignores a non-string custom_cast_message without crashing cast?' do
      captured = nil
      allow(DRC).to receive(:bput).with('cast', anything) { |_cmd, matches| captured = matches; 'You gesture' }
      expect { DRCA.cast?('cast', false, [], [], %w[not a string]) }.not_to raise_error
      expect(captured).to eq(get_data('spells').cast_messages)
    end

    it 'for a runestone spell, applies custom_invoke_message but ignores custom_prep_message' do
      allow(DRCA).to receive(:get_settings).and_return(OpenStruct.new)
      captured = nil
      allow(DRC).to receive(:bput).with(/^prepare my rune/, anything) { |_cmd, matches| captured = matches; 'Your cambrinth absorbs' }
      DRCA.prepare?('fireball', 10, false, 'prepare', false, 'rune', false, 'PREP IS INERT HERE', custom_invoke_message: 'The runestone flares')
      expect(captured.any? { |m| m.is_a?(Regexp) && m.source == 'The runestone flares' }).to be true
      expect(captured.any? { |m| m.is_a?(Regexp) && m.source == 'PREP IS INERT HERE' }).to be false
    end
  end

  # ----------------------------------------------
  # spell_preparing / spell_prepared? / spell_preparing?
  # ----------------------------------------------
  describe '.spell_preparing' do
    it 'returns nil when no spell prepared' do
      XMLData.prepared_spell = 'None'
      expect(DRCA.spell_preparing).to be_nil
    end

    it 'returns nil for empty string' do
      XMLData.prepared_spell = ''
      expect(DRCA.spell_preparing).to be_nil
    end

    it 'returns the spell name when preparing' do
      XMLData.prepared_spell = 'Fire Ball'
      expect(DRCA.spell_preparing).to eq('Fire Ball')
    end
  end

  describe '.spell_preparing?' do
    it 'returns false when not preparing' do
      XMLData.prepared_spell = 'None'
      expect(DRCA.spell_preparing?).to be false
    end

    it 'returns true when preparing' do
      XMLData.prepared_spell = 'Fire Ball'
      expect(DRCA.spell_preparing?).to be true
    end
  end

  # ----------------------------------------------
  # cast?
  # ----------------------------------------------
  describe '.cast?' do
    before(:each) do
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      Flags.reset!
    end

    it 'returns true on successful cast' do
      expect(DRCA.cast?).to be true
    end

    it 'returns false when spell-fail flag set' do
      allow(DRC).to receive(:bput).and_return('default')
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      allow(Flags).to receive(:[]).and_call_original
      allow(Flags).to receive(:[]).with('spell-fail').and_return(['Something is interfering with the spell'])
      expect(DRCA.cast?).to be false
    end

    it 'retries on cyclic-too-recent and gives up at 0 retries' do
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      allow(Flags).to receive(:[]).and_call_original
      allow(Flags).to receive(:[]).with('cyclic-too-recent').and_return(['The mental strain'])
      result = DRCA.cast?('cast', false, [], [], retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('cast? exhausted') }).to be true
    end

    it 'falls back from barrage on barrage-fail' do
      allow(DRC).to receive(:bput).with('barrage', anything).and_return('You gesture')
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      allow(Flags).to receive(:[]).and_call_original
      allow(Flags).to receive(:[]).with('barrage-fail').and_return(['That was an invalid attack choice.'])
      result = DRCA.cast?('barrage', false, [], [])
      expect(result).to be_truthy
    end

    it 'gives up on barrage fallback at 0 retries' do
      allow(DRC).to receive(:bput).with('barrage', anything).and_return('You gesture')
      allow(Flags).to receive(:[]).and_call_original
      allow(Flags).to receive(:[]).with('barrage-fail').and_return(['That was an invalid attack choice.'])
      result = DRCA.cast?('barrage', false, [], [], retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('barrage fallback exhausted') }).to be true
    end

    it 'releases mana and symbiosis on spell-fail with symbiosis' do
      allow(Flags).to receive(:[]).and_call_original
      allow(Flags).to receive(:[]).with('spell-fail').and_return(['Something is interfering'])
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      allow(DRC).to receive(:bput).with('release mana', anything, anything)
      allow(DRC).to receive(:bput).with('release symbiosis', anything, anything)
      DRCA.cast?('cast', true)
    end
  end

  # ----------------------------------------------
  # backfired?
  # ----------------------------------------------
  describe '.backfired?' do
    it 'returns false by default' do
      expect(DRCA.backfired?).to be false
    end
  end

  # ----------------------------------------------
  # find_focus
  # ----------------------------------------------
  describe '.find_focus' do
    it 'returns nil when focus is nil' do
      expect(DRCA.find_focus(nil, false, nil, false)).to be_nil
    end

    it 'calls DRCI.remove_item? for worn focus' do
      expect(DRCI).to receive(:remove_item?).with('orb').and_return(true)
      expect(DRCA.find_focus('orb', true, nil, false)).to be true
    end

    it 'calls DRCI.untie_item? for tied focus' do
      expect(DRCI).to receive(:untie_item?).with('orb', 'belt').and_return(true)
      expect(DRCA.find_focus('orb', false, 'belt', false)).to be true
    end

    it 'uses wield bput for sheathed focus' do
      allow(DRC).to receive(:bput).with(/wield my orb/, anything, anything).and_return('You draw out')
      expect(DRCA.find_focus('orb', false, nil, true)).to be true
    end

    it 'returns false on wield failure' do
      allow(DRC).to receive(:bput).with(/wield my orb/, anything, anything).and_return('Wield what')
      expect(DRCA.find_focus('orb', false, nil, true)).to be false
    end

    it 'calls DRCI.get_item? for stowed focus' do
      expect(DRCI).to receive(:get_item?).with('orb').and_return(true)
      expect(DRCA.find_focus('orb', false, nil, false)).to be true
    end
  end

  # ----------------------------------------------
  # stow_focus
  # ----------------------------------------------
  describe '.stow_focus' do
    it 'returns nil when focus is nil' do
      expect(DRCA.stow_focus(nil, false, nil, false)).to be_nil
    end

    it 'calls DRCI.wear_item? for worn focus' do
      expect(DRCI).to receive(:wear_item?).with('orb').and_return(true)
      expect(DRCA.stow_focus('orb', true, nil, false)).to be true
    end

    it 'calls DRCI.tie_item? for tied focus' do
      expect(DRCI).to receive(:tie_item?).with('orb', 'belt').and_return(true)
      expect(DRCA.stow_focus('orb', false, 'belt', false)).to be true
    end

    it 'retries tie on failure and gives up at 0 retries' do
      expect(DRCI).to receive(:tie_item?).with('orb', 'belt').and_return(false)
      result = DRCA.stow_focus('orb', false, 'belt', false, retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('stow_focus exhausted') }).to be true
    end

    it 'uses sheathe bput for sheathed focus' do
      allow(DRC).to receive(:bput).with(/sheathe my orb/, anything, anything).and_return('You sheathe')
      expect(DRCA.stow_focus('orb', false, nil, true)).to be true
    end

    it 'returns false on sheathe failure' do
      allow(DRC).to receive(:bput).with(/sheathe my orb/, anything, anything).and_return("Sheathe your sword where")
      expect(DRCA.stow_focus('orb', false, nil, true)).to be false
    end

    it 'calls DRCI.stow_item? for stowed focus' do
      expect(DRCI).to receive(:stow_item?).with('orb').and_return(true)
      expect(DRCA.stow_focus('orb', false, nil, false)).to be true
    end
  end

  # ----------------------------------------------
  # find_cambrinth / stow_cambrinth / skilled_to_charge_while_worn?
  # ----------------------------------------------
  describe '.find_cambrinth' do
    it 'gets stored cambrinth from stow or tries remove' do
      expect(DRCI).to receive(:get_item_if_not_held?).with('armband').and_return(true)
      DRCA.find_cambrinth('armband', true, 50)
    end

    it 'checks hands then removes then gets for non-skilled worn' do
      allow(DRSkill).to receive(:getrank).with('Arcana').and_return(0)
      expect(DRCI).to receive(:in_hands?).with('armband').and_return(true)
      DRCA.find_cambrinth('armband', false, 50)
    end

    it 'returns true when skilled to charge while worn' do
      allow(DRSkill).to receive(:getrank).with('Arcana').and_return(999)
      expect(DRCA.find_cambrinth('armband', false, 50)).to be true
    end
  end

  describe '.stow_cambrinth' do
    it 'stows stored cambrinth' do
      allow(DRCI).to receive(:get_item_if_not_held?).and_return(true)
      expect(DRCI).to receive(:stow_item?).with('armband').and_return(true)
      DRCA.stow_cambrinth('armband', true, 50)
    end

    it 'wears cambrinth if in hands' do
      allow(DRCI).to receive(:in_hands?).with('armband').and_return(true)
      expect(DRCI).to receive(:wear_item?).with('armband').and_return(true)
      DRCA.stow_cambrinth('armband', false, 50)
    end

    it 'returns true if not in hands and not stored' do
      allow(DRCI).to receive(:in_hands?).with('armband').and_return(false)
      expect(DRCA.stow_cambrinth('armband', false, 50)).to be true
    end
  end

  describe '.skilled_to_charge_while_worn?' do
    it 'returns true when arcana rank is sufficient' do
      allow(DRSkill).to receive(:getrank).with('Arcana').and_return(300)
      expect(DRCA.skilled_to_charge_while_worn?(50)).to be true
    end

    it 'returns false when arcana rank is insufficient' do
      allow(DRSkill).to receive(:getrank).with('Arcana').and_return(100)
      expect(DRCA.skilled_to_charge_while_worn?(50)).to be false
    end
  end

  # ----------------------------------------------
  # charge_and_invoke
  # ----------------------------------------------
  describe '.charge_and_invoke' do
    it 'returns early for nil charges' do
      expect(DRCA).not_to receive(:charge?)
      DRCA.charge_and_invoke('armband', nil, nil)
    end

    it 'returns early for empty charges' do
      expect(DRCA).not_to receive(:charge?)
      DRCA.charge_and_invoke('armband', nil, [])
    end

    it 'charges and invokes with exact amount' do
      allow(DRCA).to receive(:charge?).and_return(true)
      expect(DRCA).to receive(:invoke).with('armband', nil, 30)
      DRCA.charge_and_invoke('armband', nil, [10, 20], true)
    end

    it 'invokes without amount when invoke_exact_amount is nil' do
      allow(DRCA).to receive(:charge?).and_return(true)
      expect(DRCA).to receive(:invoke).with('armband', nil, nil)
      DRCA.charge_and_invoke('armband', nil, [10, 20], nil)
    end

    it 'stops charging on first charge failure' do
      charge_count = 0
      allow(DRCA).to receive(:charge?) do
        charge_count += 1
        charge_count == 1
      end
      allow(DRCA).to receive(:invoke)
      DRCA.charge_and_invoke('armband', nil, [10, 20, 30], nil)
      expect(charge_count).to eq(2)
    end
  end

  # ----------------------------------------------
  # invoke
  # ----------------------------------------------
  describe '.invoke' do
    it 'returns early for nil cambrinth' do
      expect(DRC).not_to receive(:bput)
      DRCA.invoke(nil, nil, nil)
    end

    it 'invokes successfully' do
      allow(DRC).to receive(:bput).and_return('Your cambrinth absorbs')
      DRCA.invoke('armband', nil, 10)
    end

    it 'warns and retries on clumsy error when not in hands' do
      allow(DRC).to receive(:bput).and_return('you find it too clumsy', 'Your cambrinth absorbs')
      allow(DRCI).to receive(:in_hands?).with('armband').and_return(false, true)
      allow(DRCA).to receive(:find_cambrinth)
      allow(DRCA).to receive(:stow_cambrinth)
      DRCA.invoke('armband', nil, 10)
      expect(bold_messages.any? { |m| m.include?('arcana skill is too low to invoke') }).to be true
    end
  end

  # ----------------------------------------------
  # charge?
  # ----------------------------------------------
  describe '.charge?' do
    it 'returns truthy on success' do
      allow(DRC).to receive(:bput).and_return('Your cambrinth absorbs all of the energy')
      expect(DRCA.charge?('armband', 10)).to be_truthy
    end

    it 'tries harness on no condition' do
      allow(DRC).to receive(:bput).with(/charge my armband/, anything, anything).and_return('You are in no condition to do that')
      expect(DRCA).to receive(:harness?).with(10).and_return(true)
      expect(DRCA.charge?('armband', 10)).to be true
    end

    it 'warns on missing cambrinth' do
      allow(DRC).to receive(:bput).with(/charge my armband/, anything, anything).and_return("You'll have to hold it")
      allow(DRCI).to receive(:in_hands?).and_return(true)
      DRCA.charge?('armband', 10)
      expect(bold_messages.any? { |m| m.include?('where did your cambrinth go') }).to be true
    end
  end

  # ----------------------------------------------
  # release_cyclics
  # ----------------------------------------------
  describe '.release_cyclics' do
    it 'releases active cyclics' do
      spell_data = {
        'Fire Rain' => { 'cyclic' => true, 'abbrev' => 'fr' },
        'Fire Ball' => { 'cyclic' => false, 'abbrev' => 'fb' }
      }
      DRSpells.active_spells = { 'Fire Rain' => 300 }
      mock_data = double('data', spell_data: spell_data)
      allow(DRCA).to receive(:get_data).with('spells').and_return(mock_data)
      expect(DRC).to receive(:bput).with('release fr', DRCA::CYCLIC_RELEASE_SUCCESS_PATTERNS, 'Release what?')
      DRCA.release_cyclics
    end

    it 'skips spells in no-release list' do
      spell_data = { 'Fire Rain' => { 'cyclic' => true, 'abbrev' => 'fr' } }
      DRSpells.active_spells = { 'Fire Rain' => 300 }
      mock_data = double('data', spell_data: spell_data)
      allow(DRCA).to receive(:get_data).with('spells').and_return(mock_data)
      expect(DRC).not_to receive(:bput).with('release fr', anything, anything)
      DRCA.release_cyclics(['Fire Rain'])
    end
  end

  # ----------------------------------------------
  # prepare_to_cast_runestone? / get_runestone?
  # ----------------------------------------------
  describe '.prepare_to_cast_runestone?' do
    let(:settings) { OpenStruct.new(runestone_storage: 'pouch') }
    let(:spell) { { 'runestone_name' => 'moonstone' } }

    it 'returns true when runestone is available' do
      allow(DRCI).to receive(:inside?).and_return(true)
      allow(DRCI).to receive(:in_hands?).and_return(true)
      expect(DRCA.prepare_to_cast_runestone?(spell, settings)).to be true
    end

    it 'returns false with message when out of runestones' do
      allow(DRCI).to receive(:inside?).and_return(false)
      expect(DRCA.prepare_to_cast_runestone?(spell, settings)).to be false
      expect(bold_messages.any? { |m| m.include?('out of moonstone') }).to be true
    end
  end

  describe '.get_runestone?' do
    let(:settings) { OpenStruct.new(runestone_storage: 'pouch') }

    it 'returns true if already in hands' do
      allow(DRCI).to receive(:in_hands?).with('moonstone').and_return(true)
      expect(DRCA.get_runestone?('moonstone', settings)).to be true
    end

    it 'returns true on successful get' do
      allow(DRCI).to receive(:in_hands?).with('moonstone').and_return(false)
      allow(DRC).to receive(:bput).and_return('You get a moonstone')
      expect(DRCA.get_runestone?('moonstone', settings)).to be true
    end

    it 'returns false and disposes useless runestone' do
      allow(DRCI).to receive(:in_hands?).with('moonstone').and_return(false)
      allow(DRC).to receive(:bput).and_return('You get a useless moonstone')
      expect(DRCI).to receive(:dispose_trash).with('moonstone')
      expect(DRCA.get_runestone?('moonstone', settings)).to be false
      expect(bold_messages.any? { |m| m.include?('useless moonstone') }).to be true
    end

    it 'returns false when runestone not found' do
      allow(DRCI).to receive(:in_hands?).with('moonstone').and_return(false)
      allow(DRC).to receive(:bput).and_return('What were you referring to')
      expect(DRCA.get_runestone?('moonstone', settings)).to be false
      expect(bold_messages.any? { |m| m.include?('could not find moonstone') }).to be true
    end
  end

  # ----------------------------------------------
  # cast_spell? / cast_spell
  # ----------------------------------------------
  describe '.cast_spell?' do
    it 'returns true when cast_spell returns truthy' do
      allow(DRCA).to receive(:cast_spell).and_return('You gesture')
      expect(DRCA.cast_spell?({}, {})).to be true
    end

    it 'returns false when cast_spell returns nil' do
      allow(DRCA).to receive(:cast_spell).and_return(nil)
      expect(DRCA.cast_spell?(nil, {})).to be false
    end
  end

  describe '.cast_spell' do
    it 'returns nil for nil data' do
      expect(DRCA.cast_spell(nil, {})).to be_nil
    end

    it 'returns nil for nil settings' do
      expect(DRCA.cast_spell({}, nil)).to be_nil
    end
  end

  # ----------------------------------------------
  # segue?
  # ----------------------------------------------
  describe '.segue?' do
    it 'returns true on successful segue' do
      allow(DRC).to receive(:bput).and_return('You segue')
      expect(DRCA.segue?('ae', 10)).to be true
    end

    it 'returns false when not performing cyclic' do
      allow(DRC).to receive(:bput).and_return('You must be performing a cyclic spell to segue from')
      expect(DRCA.segue?('ae', 10)).to be false
    end
  end

  # ----------------------------------------------
  # check_to_harness
  # ----------------------------------------------
  describe '.check_to_harness' do
    it 'returns false when should_harness is false' do
      expect(DRCA.check_to_harness(false)).to be false
    end

    it 'returns false when Attunement xp exceeds Arcana xp' do
      allow(DRSkill).to receive(:getxp).with('Attunement').and_return(30)
      allow(DRSkill).to receive(:getxp).with('Arcana').and_return(10)
      expect(DRCA.check_to_harness(true)).to be false
    end

    it 'returns true when Arcana xp >= Attunement xp' do
      allow(DRSkill).to receive(:getxp).with('Attunement').and_return(10)
      allow(DRSkill).to receive(:getxp).with('Arcana').and_return(30)
      expect(DRCA.check_to_harness(true)).to be true
    end
  end

  # ----------------------------------------------
  # normalize_cambrinth_items (private, tested via cast_spell)
  # ----------------------------------------------
  describe 'normalize_cambrinth_items (via cast_spell)' do
    it 'normalizes settings when cambrinth_items name is nil' do
      settings = OpenStruct.new(
        cambrinth_items: [{ 'name' => nil }],
        cambrinth: 'armband',
        cambrinth_cap: 50,
        stored_cambrinth: false,
        use_harness_when_arcana_locked: false,
        dedicated_camb_use: nil,
        cambrinth_invoke_exact_amount: nil,
        osrel_no_harness: true,
        osrel_amount: 0,
        waggle_spells_mana_threshold: 10,
        waggle_spells_concentration_threshold: 10
      )
      data = { 'abbrev' => 'fb', 'mana' => 10, 'cambrinth' => [5], 'prep_time' => 0 }
      allow(DRCA).to receive(:prepare?).and_return('You begin to')
      allow(DRCA).to receive(:cast?).and_return(true)
      allow(DRCA).to receive(:find_charge_invoke_stow)
      DRCA.cast_spell(data, settings)
      expect(settings.cambrinth_items[0]['name']).to eq('armband')
    end
  end

  # ----------------------------------------------
  # choose_avtalia
  # ----------------------------------------------
  describe '.choose_avtalia' do
    it 'returns nil when no cambrinth matches' do
      allow(UserVars).to receive(:avtalia).and_return({})
      expect(DRCA.choose_avtalia(10, 50)).to be_nil
    end
  end

  # ----------------------------------------------
  # check_elemental_charge
  # ----------------------------------------------
  describe '.check_elemental_charge' do
    it 'returns 0 for non-warrior-mages' do
      DRStats.guild = 'Bard'
      expect(DRCA.check_elemental_charge).to eq(0)
    end

    it 'returns correct charge level for warrior mage' do
      DRStats.guild = 'Warrior Mage'
      allow(DRC).to receive(:bput).and_return('A charge dances through your body.')
      expect(DRCA.check_elemental_charge).to eq(3)
    end
  end

  # ----------------------------------------------
  # perc_symbiotic_research / release_magical_research
  # ----------------------------------------------
  describe '.perc_symbiotic_research' do
    it 'returns symbiosis type when active' do
      allow(DRC).to receive(:bput).and_return('combine the weaves of the lunar symbiosis')
      expect(DRCA.perc_symbiotic_research).to eq('lunar')
    end

    it 'returns nil when no symbiosis active' do
      allow(DRC).to receive(:bput).and_return('Roundtime')
      expect(DRCA.perc_symbiotic_research).to be_nil
    end
  end

  describe '.release_magical_research' do
    it 'sends release symbiosis twice' do
      expect(DRC).to receive(:bput).with('release symbiosis', anything, anything, anything).twice
      DRCA.release_magical_research
    end
  end

  # ----------------------------------------------
  # perc_mana
  # ----------------------------------------------
  describe '.perc_mana' do
    it 'returns nil for barbarians' do
      DRStats.guild = 'Barbarian'
      expect(DRCA.perc_mana).to be_nil
    end

    it 'returns nil for thieves' do
      DRStats.guild = 'Thief'
      expect(DRCA.perc_mana).to be_nil
    end

    it 'returns mana levels for moon mages via issue_command' do
      DRStats.guild = 'Moon Mage'
      mock_lines = [
        'The developing streams of Enlightened Geometry mana flowing through',
        'The developing streams of Moonlight Manipulation mana flowing through',
        'The developing streams of Perception mana flowing through',
        'The developing streams of Psychic Projection mana flowing through'
      ]
      allow(Lich::Util).to receive(:issue_command).and_return(mock_lines)
      allow(DRCA).to receive(:parse_mana_message).and_return(3)
      result = DRCA.perc_mana
      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly('enlightened_geometry', 'moonlight_manipulation', 'perception', 'psychic_projection')
    end

    it 'returns nil when issue_command times out for moon mage' do
      DRStats.guild = 'Moon Mage'
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(DRCA.perc_mana).to be_nil
    end

    it 'returns parsed mana for non-moon-mage casters' do
      DRStats.guild = 'Warrior Mage'
      allow(DRC).to receive(:bput).and_return('You reach out with your senses and see developing')
      allow(DRCA).to receive(:parse_mana_message).and_return(5)
      expect(DRCA.perc_mana).to eq(5)
    end
  end

  # ----------------------------------------------
  # shatter_regalia?
  # ----------------------------------------------
  describe '.shatter_regalia?' do
    it 'returns false for non-traders' do
      DRStats.guild = 'Warrior Mage'
      expect(DRCA.shatter_regalia?).to be false
    end

    it 'returns false for empty regalia' do
      DRStats.guild = 'Trader'
      expect(DRCA.shatter_regalia?([])).to be false
    end

    it 'removes each regalia item' do
      DRStats.guild = 'Trader'
      expect(DRC).to receive(:bput).with(/remove my gauntlet/, anything, anything, anything)
      expect(DRCA.shatter_regalia?(['gauntlet'])).to be true
    end
  end

  # ----------------------------------------------
  # find_charge_invoke_stow
  # ----------------------------------------------
  describe '.find_charge_invoke_stow' do
    it 'returns early for nil charges' do
      expect(DRCA).not_to receive(:find_cambrinth)
      DRCA.find_charge_invoke_stow('armband', false, 50, nil, nil)
    end

    it 'calls find, charge_and_invoke, and stow in sequence' do
      expect(DRCA).to receive(:find_cambrinth).with('armband', false, 50).ordered
      expect(DRCA).to receive(:charge_and_invoke).with('armband', nil, [10], nil).ordered
      expect(DRCA).to receive(:stow_cambrinth).with('armband', false, 50).ordered
      DRCA.find_charge_invoke_stow('armband', false, 50, nil, [10])
    end
  end
end
