# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load production code dependencies
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-items.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'equipmanager.rb')

# Alias real classes at top level
DRCI = Lich::DragonRealms::DRCI unless defined?(DRCI)
EquipmentManager = Lich::DragonRealms::EquipmentManager unless defined?(EquipmentManager)

RSpec.describe Lich::DragonRealms::EquipmentManager do
  def stub_bput(response)
    allow(DRC).to receive(:bput).and_return(response)
  end

  describe 'constants' do
    describe 'STOW_RECOVERY_PATTERNS' do
      subject(:patterns) { described_class::STOW_RECOVERY_PATTERNS }

      it 'is a frozen constant' do
        expect(patterns).to be_frozen
      end

      it 'uses correct "Sheath" spelling (not "Sheathe")' do
        sheath_pattern = patterns.find { |p| p.source.include?('Sheath') }
        expect(sheath_pattern).not_to be_nil
        expect(sheath_pattern.source).not_to include('Sheathe')
      end

      it 'matches "Sheath your sword where?"' do
        expect(patterns.any? { |p| p.match?('Sheath your sword where?') }).to be true
      end
    end

    describe 'UNTIE_EXHAUSTED_PATTERNS' do
      subject(:patterns) { described_class::UNTIE_EXHAUSTED_PATTERNS }

      it 'is a frozen constant' do
        expect(patterns).to be_frozen
      end

      it 'does not contain recoverable "too busy" patterns' do
        patterns.each do |pat|
          expect(pat.source).not_to match(/too busy/), "#{pat} is recoverable and belongs in failures, not exhausted"
        end
      end

      it 'is a subset of DRCI::UNTIE_ITEM_FAILURE_PATTERNS' do
        patterns.each do |exhausted_pat|
          covered = DRCI::UNTIE_ITEM_FAILURE_PATTERNS.any? do |drci_pat|
            exhausted_pat.source == drci_pat.source
          end
          expect(covered).to be(true), "#{exhausted_pat} not found in DRCI::UNTIE_ITEM_FAILURE_PATTERNS"
        end
      end
    end

    it 'does not define local GET_EXHAUSTED_PATTERNS (uses DRCI directly)' do
      expect(described_class.const_defined?(:GET_EXHAUSTED_PATTERNS, false)).to be false
    end

    it 'does not define local SHEATH_SUCCESS_PATTERNS' do
      expect(described_class.const_defined?(:SHEATH_SUCCESS_PATTERNS, false)).to be false
    end

    it 'does not define local SHEATH_FAILURE_PATTERNS' do
      expect(described_class.const_defined?(:SHEATH_FAILURE_PATTERNS, false)).to be false
    end

    it 'does not define local REMOVE_ITEM_SUCCESS_PATTERNS (uses DRCI)' do
      expect(described_class.const_defined?(:REMOVE_ITEM_SUCCESS_PATTERNS, false)).to be false
    end

    it 'does not define local UNTIE_ITEM_SUCCESS_PATTERNS (uses DRCI)' do
      expect(described_class.const_defined?(:UNTIE_ITEM_SUCCESS_PATTERNS, false)).to be false
    end

    it 'does not define local GET_ITEM_SUCCESS_PATTERNS (uses DRCI)' do
      expect(described_class.const_defined?(:GET_ITEM_SUCCESS_PATTERNS, false)).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # verb_data DRCI constant synchronization
  # ---------------------------------------------------------------------------
  # These specs enforce that verb_data references DRCI constants rather than
  # hardcoding patterns. If a new game message is added to a DRCI constant,
  # verb_data must pick it up automatically.

  describe '#verb_data' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }
    let(:item) do
      double('item',
             short_regex: /\bsword/i,
             name: 'sword',
             short_name: 'sword',
             transform_verb: 'twist',
             transform_text: 'The sword twists',
             worn: false)
    end

    subject(:data) { em.send(:verb_data, item) }

    # --- :worn (remove) ---------------------------------------------------

    describe ':worn type' do
      subject(:worn) { data[:worn] }

      it 'uses the "remove" verb' do
        expect(worn[:verb]).to eq('remove')
      end

      it 'includes every DRCI::REMOVE_ITEM_SUCCESS_PATTERNS entry in matches' do
        DRCI::REMOVE_ITEM_SUCCESS_PATTERNS.each do |pat|
          expect(worn[:matches]).to include(pat),
                                    "matches missing DRCI::REMOVE_ITEM_SUCCESS_PATTERNS entry: #{pat.inspect}"
        end
      end

      it 'includes every DRCI::REMOVE_ITEM_FAILURE_PATTERNS entry in matches' do
        DRCI::REMOVE_ITEM_FAILURE_PATTERNS.each do |pat|
          expect(worn[:matches]).to include(pat),
                                    "matches missing DRCI::REMOVE_ITEM_FAILURE_PATTERNS entry: #{pat.inspect}"
        end
      end

      it 'sets exhausted to DRCI::REMOVE_ITEM_FAILURE_PATTERNS (same object)' do
        expect(worn[:exhausted]).to equal(DRCI::REMOVE_ITEM_FAILURE_PATTERNS)
      end

      it 'includes dynamic item-specific patterns in matches' do
        dynamic = worn[:matches].select { |p| p.is_a?(Regexp) && p.source.include?('sword') }
        expect(dynamic).not_to be_empty, 'expected item-specific patterns in matches'
      end

      it 'does not hardcode "you tug" as a string (covered by DRCI regex)' do
        hardcoded_strings = worn[:matches].select { |p| p.is_a?(String) && p.include?('you tug') }
        expect(hardcoded_strings).to be_empty,
                                     '"you tug" should come from DRCI::REMOVE_ITEM_SUCCESS_PATTERNS, not a hardcoded string'
      end

      it 'does not hardcode "Remove what" as a string (covered by DRCI regex)' do
        hardcoded_strings = worn[:matches].select { |p| p.is_a?(String) && p.include?('Remove what') }
        expect(hardcoded_strings).to be_empty,
                                     '"Remove what" should come from DRCI::REMOVE_ITEM_FAILURE_PATTERNS, not a hardcoded string'
      end

      it 'does not hardcode "slide themselves off" as a string (covered by DRCI regex)' do
        hardcoded_strings = worn[:matches].select { |p| p.is_a?(String) && p.include?('slide themselves') }
        expect(hardcoded_strings).to be_empty,
                                     '"slide themselves off" should come from DRCI::REMOVE_ITEM_SUCCESS_PATTERNS'
      end

      it 'matches "A brisk chill leaves you as you remove" via DRCI constant' do
        msg = 'A brisk chill leaves you as you remove the gloves'
        expect(worn[:matches].any? { |p| p.is_a?(Regexp) && p.match?(msg) }).to be(true),
                                                                                'verb_data :worn should match cold-enchanted item remove via DRCI constant'
      end

      it 'matches "Grunting with momentary exertion" via DRCI constant' do
        msg = 'Grunting with momentary exertion, you grip each of your heavy combat boots'
        expect(worn[:matches].any? { |p| p.is_a?(Regexp) && p.match?(msg) }).to be(true),
                                                                                'verb_data :worn should match boot removal via DRCI constant'
      end

      it 'failures do not overlap with exhausted (case/when ordering safety)' do
        worn[:failures].each do |fail_pat|
          worn[:exhausted].each do |ex_pat|
            # A failure pattern that also appears in exhausted would be swallowed
            # by the exhausted branch (checked first in get_item_helper), skipping recovery.
            expect(fail_pat).not_to eq(ex_pat),
                                    "failure #{fail_pat.inspect} collides with exhausted #{ex_pat.inspect} -- recovery would be skipped"
          end
        end
      end
    end

    # --- :tied (untie) ----------------------------------------------------

    describe ':tied type' do
      subject(:tied) { data[:tied] }

      it 'uses the "untie" verb' do
        expect(tied[:verb]).to eq('untie')
      end

      it 'includes every DRCI::UNTIE_ITEM_SUCCESS_PATTERNS entry in matches' do
        DRCI::UNTIE_ITEM_SUCCESS_PATTERNS.each do |pat|
          expect(tied[:matches]).to include(pat),
                                    "matches missing DRCI::UNTIE_ITEM_SUCCESS_PATTERNS entry: #{pat.inspect}"
        end
      end

      it 'includes every DRCI::UNTIE_ITEM_FAILURE_PATTERNS entry in matches' do
        DRCI::UNTIE_ITEM_FAILURE_PATTERNS.each do |pat|
          expect(tied[:matches]).to include(pat),
                                    "matches missing DRCI::UNTIE_ITEM_FAILURE_PATTERNS entry: #{pat.inspect}"
        end
      end

      it 'sets exhausted to UNTIE_EXHAUSTED_PATTERNS (same object)' do
        expect(tied[:exhausted]).to equal(described_class::UNTIE_EXHAUSTED_PATTERNS)
      end

      it 'includes dynamic item-specific patterns in matches' do
        dynamic = tied[:matches].select { |p| p.is_a?(Regexp) && p.source.include?('sword') }
        expect(dynamic).not_to be_empty, 'expected item-specific patterns in matches'
      end

      it 'does not hardcode "Untie what" or "What were you" as strings' do
        hardcoded_strings = tied[:matches].select do |p|
          p.is_a?(String) && (p.include?('Untie what') || p.include?('What were you'))
        end
        expect(hardcoded_strings).to be_empty,
                                     'failure strings should come from DRCI::UNTIE_ITEM_FAILURE_PATTERNS'
      end

      it '"too busy" patterns are in matches (via DRCI) for bput to return on' do
        msg_combat = 'You are a little too busy to do that right now'
        msg_music = 'You are a bit too busy playing your music'
        expect(tied[:matches].any? { |p| p.is_a?(Regexp) && p.match?(msg_combat) }).to be(true),
                                                                                       '"too busy" (combat) should be matchable'
        expect(tied[:matches].any? { |p| p.is_a?(Regexp) && p.match?(msg_music) }).to be(true),
                                                                                      '"too busy" (music) should be matchable'
      end

      it '"too busy" failures are NOT in exhausted (they are recoverable)' do
        too_busy = tied[:failures].select { |p| p.is_a?(Regexp) && p.source.include?('too busy') }
        expect(too_busy).not_to be_empty, 'expected "too busy" in failures for recovery'
        tied[:exhausted].each do |ex_pat|
          expect(ex_pat.source).not_to include('too busy'),
                                       "exhausted contains #{ex_pat.inspect} which should be recoverable, not terminal"
        end
      end

      it 'failures do not overlap with exhausted' do
        tied[:failures].each do |fail_pat|
          tied[:exhausted].each do |ex_pat|
            expect(fail_pat).not_to eq(ex_pat),
                                    "failure #{fail_pat.inspect} collides with exhausted #{ex_pat.inspect}"
          end
        end
      end
    end

    # --- :stowed (get) ----------------------------------------------------

    describe ':stowed type' do
      subject(:stowed) { data[:stowed] }

      it 'uses the "get" verb' do
        expect(stowed[:verb]).to eq('get')
      end

      it 'includes every DRCI::GET_ITEM_SUCCESS_PATTERNS entry in matches' do
        DRCI::GET_ITEM_SUCCESS_PATTERNS.each do |pat|
          expect(stowed[:matches]).to include(pat),
                                      "matches missing DRCI::GET_ITEM_SUCCESS_PATTERNS entry: #{pat.inspect}"
        end
      end

      it 'includes every DRCI::GET_ITEM_FAILURE_PATTERNS entry in matches' do
        DRCI::GET_ITEM_FAILURE_PATTERNS.each do |pat|
          expect(stowed[:matches]).to include(pat),
                                      "matches missing DRCI::GET_ITEM_FAILURE_PATTERNS entry: #{pat.inspect}"
        end
      end

      it 'sets exhausted to DRCI::GET_ITEM_FAILURE_PATTERNS (same object)' do
        expect(stowed[:exhausted]).to equal(DRCI::GET_ITEM_FAILURE_PATTERNS)
      end

      it 'includes "slides easily out" for sheathed weapon retrieval' do
        msg = 'The sword slides easily out of your scabbard'
        expect(stowed[:matches].any? { |p| p.is_a?(Regexp) && p.match?(msg) }).to be(true),
                                                                                  'expected "slides easily out" pattern for sheathed weapon GET'
      end

      it 'failures do not overlap with exhausted' do
        stowed[:failures].each do |fail_pat|
          stowed[:exhausted].each do |ex_pat|
            expect(fail_pat).not_to eq(ex_pat),
                                    "failure #{fail_pat.inspect} collides with exhausted #{ex_pat.inspect}"
          end
        end
      end
    end

    # --- :transform -------------------------------------------------------

    describe ':transform type' do
      subject(:transform) { data[:transform] }

      it 'uses the item transform_verb' do
        expect(transform[:verb]).to eq('twist')
      end

      it 'matches on the item transform_text' do
        expect(transform[:matches]).to include('The sword twists')
      end

      it 'uses regex patterns in failures (not plain strings)' do
        transform[:failures].each do |pat|
          expect(pat).to be_a(Regexp), "expected Regexp, got #{pat.class}: #{pat.inspect}"
        end
      end

      it 'includes failure patterns in matches so bput returns on them' do
        transform[:failures].each do |fail_pat|
          expect(transform[:matches]).to include(fail_pat),
                                         "failure #{fail_pat.inspect} missing from matches -- bput would timeout instead of triggering recovery"
        end
      end

      it 'sets exhausted to DRCI::GET_ITEM_FAILURE_PATTERNS (same object)' do
        expect(transform[:exhausted]).to equal(DRCI::GET_ITEM_FAILURE_PATTERNS)
      end
    end

    # --- Cross-type structural invariants ---------------------------------

    describe 'structural invariants (all types)' do
      %i[worn tied stowed transform].each do |type|
        context ":#{type}" do
          subject(:entry) { data[type] }

          it 'has required keys' do
            %i[verb matches failures failure_recovery exhausted].each do |key|
              expect(entry).to have_key(key), "#{type} missing required key :#{key}"
            end
          end

          it 'has a callable failure_recovery' do
            expect(entry[:failure_recovery]).to respond_to(:call),
                                                "#{type} failure_recovery is not callable"
          end

          it 'exhausted entries are all matchable by bput (present in matches)' do
            Array(entry[:exhausted]).each do |ex_pat|
              covered = entry[:matches].any? do |m_pat|
                if m_pat.is_a?(Regexp) && ex_pat.is_a?(Regexp)
                  m_pat.source == ex_pat.source
                else
                  m_pat == ex_pat
                end
              end
              expect(covered).to be(true),
                                 "exhausted pattern #{ex_pat.inspect} not found in matches -- bput would never return it"
            end
          end
        end
      end

      # This is the critical invariant that prevents the 5s timeout waste.
      # Every DRCI failure pattern that appears in matches must be categorized
      # in either exhausted or failures. If a new pattern is added to DRCI,
      # this spec fails until it's categorized -- preventing silent fallthrough
      # to the hand-change polling timeout.
      it 'every DRCI failure pattern in matches is in exhausted or failures (no timeout fallthrough)' do
        drci_failure_constants = {
          worn: DRCI::REMOVE_ITEM_FAILURE_PATTERNS,
          tied: DRCI::UNTIE_ITEM_FAILURE_PATTERNS,
          stowed: DRCI::GET_ITEM_FAILURE_PATTERNS,
          transform: DRCI::GET_ITEM_FAILURE_PATTERNS
        }

        %i[worn tied stowed transform].each do |type|
          entry = data[type]
          drci_failures = drci_failure_constants[type]
          categorized = Array(entry[:exhausted]) + Array(entry[:failures])

          drci_failures.each do |drci_pat|
            # Check if this DRCI failure is in matches
            in_matches = entry[:matches].any? do |m_pat|
              m_pat.is_a?(Regexp) && drci_pat.is_a?(Regexp) && m_pat.source == drci_pat.source
            end
            next unless in_matches

            # If it's in matches, it must be categorized
            in_categorized = categorized.any? do |c_pat|
              c_pat.is_a?(Regexp) && drci_pat.is_a?(Regexp) && c_pat.source == drci_pat.source
            end
            expect(in_categorized).to be(true),
                                      "#{type}: DRCI failure #{drci_pat.inspect} is in matches but not in exhausted or failures -- " \
                                      'it will fall through to the 5s hand-change timeout instead of failing fast'
          end
        end
      end

      it 'uses all Regexp patterns (no plain strings that break case/when matching)' do
        %i[worn tied stowed].each do |type|
          entry = data[type]
          %i[failures exhausted].each do |key|
            Array(entry[key]).each do |pat|
              expect(pat).to be_a(Regexp),
                             "#{type}[:#{key}] contains String #{pat.inspect} -- " \
                             'case/when uses String#=== (exact match), not substring; use Regexp instead'
            end
          end
        end
      end
    end
  end

  describe '#stow_helper' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    before do
      allow(DRC).to receive(:bput).and_return('')
    end

    context 'when sheath fails with "Sheath your sword where?"' do
      it 'falls back to plain stow' do
        expect(DRC).to receive(:bput)
          .with('sheath my sword', any_args)
          .ordered
          .and_return('Sheath your sword where?')
        expect(DRC).to receive(:bput)
          .with('stow my sword', any_args)
          .ordered
          .and_return('You put your sword in your scabbard.')

        # Should not raise, should fall through to stow
        em.send(:stow_helper, 'sheath my sword', 'sword',
                *DRCI::SHEATH_ITEM_SUCCESS_PATTERNS, *DRCI::SHEATH_ITEM_FAILURE_PATTERNS)
      end
    end

    context 'when max retries exceeded' do
      it 'logs a message and returns' do
        expect(Lich::Messaging).to receive(:msg).with('bold', /exceeded max retries/)
        em.send(:stow_helper, 'sheath my sword', 'sword',
                *DRCI::SHEATH_ITEM_SUCCESS_PATTERNS, retries: 0)
      end
    end
  end

  describe '#unload_weapon' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    before do
      allow(DRC).to receive(:bput).and_return('')
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(described_class).to receive(:waitrt?)
    end

    it 'uses DRCI::UNLOAD_WEAPON constants' do
      expect(DRC).to receive(:bput).with(
        'unload my crossbow',
        *DRCI::UNLOAD_WEAPON_SUCCESS_PATTERNS,
        *DRCI::UNLOAD_WEAPON_FAILURE_PATTERNS
      ).and_return('You unload the crossbow.')
      em.unload_weapon('crossbow')
    end
  end

  describe 'wield patterns use DRCI constants' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }
    let(:weapon) do
      double('weapon', short_name: 'sword', name: 'sword', short_regex: /\bsword/i,
                        wield: true, tie_to: nil, worn: false, container: nil,
                        swappable: false, transforms_to: nil, adjective: nil)
    end

    before do
      allow(DRCI).to receive(:in_hands?).and_return(false)
    end

    it 'uses DRCI::WIELD_ITEM patterns for wield command' do
      expect(DRC).to receive(:bput).with(
        'wield my sword',
        *DRCI::WIELD_ITEM_SUCCESS_PATTERNS,
        *DRCI::WIELD_ITEM_FAILURE_PATTERNS
      ).and_return('You draw your sword from your scabbard.')
      em.get_item?(weapon)
    end

    it 'returns false when wield fails' do
      allow(DRC).to receive(:bput).and_return('Wield what?')
      expect(Lich::Messaging).to receive(:msg).with('bold', /Unable to wield sword/)
      expect(em.get_item?(weapon)).to be false
    end
  end

  describe 'swap patterns use DRCI constants' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'uses DRCI::SWAP_HANDS constants in wield_weapon?' do
      weapon = double('weapon', short_name: 'sword', name: 'sword', short_regex: /\bsword/i,
                                wield: true, tie_to: nil, worn: false, container: nil,
                                swappable: false, transforms_to: nil, adjective: nil,
                                needs_unloading: false)
      allow(em).to receive(:item_by_desc).and_return(weapon)
      allow(em).to receive(:get_item?).and_return(true)
      # Return nil initially (weapon not in hand), then 'sword' after get_item? retrieves it
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil, 'sword')

      expect(DRC).to receive(:bput).with(
        'swap',
        *DRCI::SWAP_HANDS_SUCCESS_PATTERNS,
        *DRCI::SWAP_HANDS_FAILURE_PATTERNS
      ).and_return('You move a steel sword to your left hand.')
      em.wield_weapon?('sword', 'Offhand Weapon')
    end
  end

  describe '#swap_to_skill?' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    before do
      allow(em).to receive(:pause)
    end

    context 'when hands need freeing repeatedly' do
      it 'does not infinite loop (counter increments on every iteration)' do
        # Simulate "two free hands" every time - counter should stop it
        allow(DRC).to receive(:bput).and_return('You must have two free hands')
        allow(DRCI).to receive(:stow_hand)
        allow(DRC).to receive(:left_hand).and_return('sword')
        allow(DRC).to receive(:right_hand).and_return('shield')

        # Should return false after exceeding weapon_skills.length iterations
        expect(em.swap_to_skill?('sword', 'heavy edged')).to be false
      end
    end

    context 'when desired skill is reached' do
      it 'returns true' do
        allow(DRC).to receive(:bput).and_return('sword  heavy edged ')
        expect(em.swap_to_skill?('sword', 'heavy edged')).to be true
      end
    end

    context 'when fan weapon' do
      it 'opens fan for edged skill' do
        expect(DRC).to receive(:bput).with('open my fan', 'you snap', 'already')
        em.swap_to_skill?('fan', 'edged')
      end

      it 'closes fan for non-edged skill' do
        expect(DRC).to receive(:bput).with('close my fan', 'you snap', 'already')
        em.swap_to_skill?('fan', 'blunt')
      end
    end
  end

  describe '#remove_item bounded recursion' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'returns false when retries exhausted without sending a command' do
      item = double('item', short_name: 'helm')
      expect(DRC).not_to receive(:bput)
      expect(Lich::Messaging).to receive(:msg).with('bold', /remove_item exceeded max retries/)
      expect(em.remove_item(item, retries: 0)).to be false
    end
  end

  describe '#stow_helper returns boolean' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'returns true on successful stow' do
      allow(DRC).to receive(:bput).and_return('You put your sword in your scabbard.')
      expect(em.send(:stow_helper, 'stow my sword', 'sword', *DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS)).to be true
    end

    it 'returns false when retries exhausted' do
      expect(Lich::Messaging).to receive(:msg).with('bold', /exceeded max retries/)
      expect(em.send(:stow_helper, 'stow my sword', 'sword', *DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS, retries: 0)).to be false
    end
  end

  describe '#remove_item swap recovery' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    before do
      allow(em).to receive(:waitrt?)
    end

    it 'logs warning when swap fails to restore hand order' do
      item = double('item', short_name: 'helm')
      # First call (retries=1): bput returns failure, triggers hand-emptying
      allow(DRC).to receive(:bput)
        .with('remove my helm', any_args)
        .and_return("You'll need both hands free to do that.")
      allow(DRC).to receive(:left_hand).and_return('sword', 'shield')
      allow(DRC).to receive(:right_hand).and_return('shield', 'sword')
      allow(DRCI).to receive(:lower_item?).and_return(true)
      allow(DRCI).to receive(:get_item_if_not_held?)
      # Recursive call (retries=0) terminates at retry check
      allow(Lich::Messaging).to receive(:msg)
      # Swap fails when trying to restore hand order
      allow(DRC).to receive(:bput)
        .with('swap', any_args)
        .and_return('Swap what?')

      expect(Lich::Messaging).to receive(:msg).with('bold', /Unable to restore hand order/)
      em.remove_item(item, retries: 1)
    end
  end

  describe '#stow_weapon transform depth' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'logs and returns when transform_depth exhausted' do
      weapon = double('weapon', short_name: 'orb', needs_unloading: false,
                                wield: false, worn: false, tie_to: nil,
                                transforms_to: 'something', container: nil)
      allow(em).to receive(:item_by_desc).and_return(weapon)
      expect(Lich::Messaging).to receive(:msg).with('bold', /exceeded max transform depth/)
      em.stow_weapon('orb', transform_depth: 0)
    end
  end

  describe '#get_combat_items nil guard' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'returns empty array when issue_command times out' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(em.send(:get_combat_items)).to eq([])
    end
  end

  describe '#stow_helper failure detection' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'returns false when failure pattern matches' do
      allow(DRC).to receive(:bput).and_return("There isn't any more room in your backpack.")
      expect(Lich::Messaging).to receive(:msg).with('bold', /stow_helper failed/)
      result = em.send(:stow_helper, 'stow my sword', 'sword',
                       *DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS,
                       failure_patterns: DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS)
      expect(result).to be false
    end

    it 'returns true when no failure patterns provided (backward compat)' do
      allow(DRC).to receive(:bput).and_return("There isn't any more room in your backpack.")
      result = em.send(:stow_helper, 'stow my sword', 'sword',
                       *DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS,
                       *DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS)
      expect(result).to be true
    end

    it 'returns false on bput timeout (empty string)' do
      allow(DRC).to receive(:bput).and_return('')
      expect(Lich::Messaging).to receive(:msg).with('bold', /got no response/)
      result = em.send(:stow_helper, 'stow my sword', 'sword',
                       *DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS)
      expect(result).to be false
    end
  end

  describe '#unload_weapon ammo recovery' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    before do
      allow(em).to receive(:waitrt?)
    end

    it 'recovers ammo that tumbles to the ground' do
      allow(DRC).to receive(:bput)
        .with('unload my longbow', any_args)
        .and_return('As you release the string, the arrow tumbles to the ground.')
      expect(DRCI).to receive(:lower_item?).with('longbow').and_return(true)
      expect(DRCI).to receive(:put_away_item?).with('arrow')
      expect(DRCI).to receive(:get_item?).with('longbow').and_return(true)
      em.unload_weapon('longbow')
    end
  end

  describe '#unload_weapon in-hand ammo' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    before do
      allow(em).to receive(:waitrt?)
      allow(DRCI).to receive(:stow_hand).and_return(true)
    end

    it 'stows the ammo hand (not the weapon hand) even when the unload line carries a <dialogData> tag, and does not mistake "crossbow bolt" for the crossbow' do
      allow(DRC).to receive(:bput)
        .with('unload my crossbow', any_args)
        .and_return("<dialogData id='AimTimerDialog'><timer id='firingTimer' value='0' /> </dialogData>You unload the crossbow.")
      allow(DRC).to receive(:right_hand).and_return('battle crossbow') # weapon, noun: crossbow
      allow(DRC).to receive(:left_hand).and_return('crossbow bolt')    # ammo, noun: bolt

      em.unload_weapon('crossbow')

      expect(DRCI).to have_received(:stow_hand).with('left')
      expect(DRCI).not_to have_received(:stow_hand).with('right')
    end

    it 'does not stow an unrelated off-hand item when the unload fails' do
      allow(DRC).to receive(:bput)
        .with('unload my crossbow', any_args)
        .and_return("But your crossbow isn't loaded.")
      allow(DRC).to receive(:right_hand).and_return('battle crossbow')
      allow(DRC).to receive(:left_hand).and_return('steel bola') # legitimate off-hand weapon

      em.unload_weapon('crossbow')

      expect(DRCI).not_to have_received(:stow_hand)
    end

    it 'does not stow anything when bput returns nil (timeout)' do
      allow(DRC).to receive(:bput).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return('battle crossbow')
      allow(DRC).to receive(:left_hand).and_return('steel bola')

      em.unload_weapon('crossbow')

      expect(DRCI).not_to have_received(:stow_hand)
    end
  end

  describe '#wield_weapon_offhand?' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }
    let(:weapon) do
      double('weapon', short_name: 'bola', name: 'bola', short_regex: /\bbola/i, swappable: false)
    end

    before do
      allow(em).to receive(:item_by_desc).with('bola').and_return(weapon)
      allow(em).to receive(:get_item?).with(weapon).and_return(true)
    end

    it 'returns true (not a spurious false) and does not swap when the weapon is already in the left/off hand' do
      allow(DRCI).to receive(:in_right_hand?).with(weapon).and_return(false)
      allow(DRCI).to receive(:in_left_hand?).with(weapon).and_return(true)
      expect(DRC).not_to receive(:bput)

      expect(em.wield_weapon_offhand?('bola')).to be true
    end

    it 'swaps to the off hand when the weapon landed in the right hand' do
      allow(DRCI).to receive(:in_right_hand?).with(weapon).and_return(true)
      expect(DRC).to receive(:bput)
        .with('swap', *DRCI::SWAP_HANDS_SUCCESS_PATTERNS, *DRCI::SWAP_HANDS_FAILURE_PATTERNS)
        .and_return('You move a steel bola to your left hand.')

      expect(em.wield_weapon_offhand?('bola')).to be true
    end
  end

  # --- return_held_gear failure_patterns --------------------------------

  describe '#return_held_gear passes failure_patterns to stow_helper' do
    let(:settings) do
      double('settings', gear_sets: { 'standard' => ['steel sword'] },
                         sort_auto_head: false, gear: [])
    end
    let(:em) { described_class.new(settings) }
    let(:item) do
      double('item', short_name: 'sword', short_regex: /\bsteel.*\bsword/i,
                     name: 'sword', needs_unloading: false,
                     tie_to: nil, wield: false, container: nil, worn: false)
    end

    before do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return('steel sword')
      allow(em).to receive(:items).and_return([item])
    end

    it 'passes WEAR_ITEM_FAILURE_PATTERNS as failure_patterns' do
      expect(DRC).to receive(:bput).with(
        'wear my sword',
        *DRCI::WEAR_ITEM_SUCCESS_PATTERNS,
        *DRCI::WEAR_ITEM_FAILURE_PATTERNS,
        *described_class::STOW_RECOVERY_PATTERNS
      ).and_return('You put on your steel sword.')

      em.return_held_gear('standard')
    end

    it 'propagates stow_helper failure (returns false, not hard-coded true)' do
      allow(Lich::Messaging).to receive(:msg)
      allow(DRC).to receive(:bput).and_return("You can't wear that.")
      expect(em.return_held_gear('standard')).to be false
    end
  end

  # --- Item lookup and configuration -----------------------------------

  describe '#item_by_desc' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }
    let(:sword) { double('sword', short_name: 'steel.sword', name: 'sword', short_regex: /\bsteel.*\bsword/i) }
    let(:shield) { double('shield', short_name: 'bronze.shield', name: 'shield', short_regex: /\bbronze.*\bshield/i) }

    before { allow(em).to receive(:items).and_return([sword, shield]) }

    it 'finds an item matching the description' do
      result = em.item_by_desc('steel sword')
      expect(result).to eq(sword)
    end

    it 'returns nil for unrecognized descriptions' do
      expect(em.item_by_desc('golden halberd')).to be_nil
    end

    it 'matches partial descriptions via short_regex' do
      result = em.item_by_desc('a steel sword with runes')
      expect(result).to eq(sword)
    end
  end

  describe '#listed_item?' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }
    let(:sword) { double('sword', short_regex: /\bsteel.*\bsword/i) }

    before { allow(em).to receive(:items).and_return([sword]) }

    it 'returns the item when description matches gear list' do
      expect(em.listed_item?('steel sword')).to eq(sword)
    end

    it 'returns nil when description is not in gear list' do
      expect(em.listed_item?('golden halberd')).to be_nil
    end
  end

  # --- wear_item? -----------------------------------------------------

  describe '#wear_item?' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'returns false with message when item is nil' do
      expect(Lich::Messaging).to receive(:msg).with('bold', /Failed to match an item/)
      expect(em.wear_item?(nil)).to be false
    end

    it 'returns false when get_item? fails to retrieve the item' do
      item = double('item', short_name: 'helm')
      allow(em).to receive(:get_item?).with(item).and_return(false)
      expect(em.wear_item?(item)).to be false
    end

    it 'delegates to DRCI.wear_item? after successfully getting the item' do
      item = double('item', short_name: 'helm')
      allow(em).to receive(:get_item?).with(item).and_return(true)
      expect(DRCI).to receive(:wear_item?).with('helm').and_return(true)
      expect(em.wear_item?(item)).to be true
    end
  end

  # --- turn_to_weapon? ------------------------------------------------

  describe '#turn_to_weapon?' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    before { allow(em).to receive(:waitrt?) }

    it 'returns true without turning when nouns are the same' do
      expect(DRC).not_to receive(:bput)
      expect(em.turn_to_weapon?('sword', 'sword')).to be true
    end

    it 'returns true when weapon shifts successfully' do
      allow(DRC).to receive(:bput).and_return('Your steel sword shifts and flexes before resolving itself into a steel greatsword')
      expect(em.turn_to_weapon?('sword', 'greatsword')).to be true
    end

    it 'returns false when turn fails' do
      allow(DRC).to receive(:bput).and_return('Turn what?')
      expect(em.turn_to_weapon?('sword', 'greatsword')).to be false
    end
  end

  # --- stow_by_type ---------------------------------------------------

  describe '#stow_by_type' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'sheathes wield-type items' do
      item = double('item', short_name: 'sword', tie_to: nil, wield: true, container: nil)
      expect(DRC).to receive(:bput).with('sheath my sword', any_args).and_return('You sheath your sword.')
      em.send(:stow_by_type, item)
    end

    it 'ties tie-to items' do
      item = double('item', short_name: 'rope', tie_to: 'belt', wield: false, container: nil)
      expect(DRC).to receive(:bput).with('tie my rope to my belt', any_args).and_return('You tie your rope to your belt.')
      em.send(:stow_by_type, item)
    end

    it 'puts container items in their container' do
      item = double('item', short_name: 'lockpick', tie_to: nil, wield: false, container: 'toolkit')
      expect(DRC).to receive(:bput).with('put my lockpick in my toolkit', any_args).and_return('You put your lockpick in your toolkit.')
      em.send(:stow_by_type, item)
    end

    it 'uses default stow when no special type' do
      item = double('item', short_name: 'gem', tie_to: nil, wield: false, container: nil)
      expect(DRC).to receive(:bput).with('stow my gem', any_args).and_return('You put your gem in your backpack.')
      em.send(:stow_by_type, item)
    end

    it 'checks tie_to before wield (tie takes priority)' do
      item = double('item', short_name: 'whip', tie_to: 'belt', wield: true, container: nil)
      expect(DRC).to receive(:bput).with('tie my whip to my belt', any_args).and_return('You tie your whip.')
      em.send(:stow_by_type, item)
    end
  end

  # --- empty_hands ----------------------------------------------------

  describe '#empty_hands' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'falls back to DRCI.stow_hands when return_held_gear returns nil' do
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:left_hand).and_return(nil)
      expect(DRCI).to receive(:stow_hands)
      em.empty_hands
    end
  end

  # --- get_item? branches ---------------------------------------------

  describe '#get_item?' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'returns true immediately if item is already in hands' do
      item = double('item', short_regex: /\bsword/i)
      allow(DRCI).to receive(:in_hands?).with(item).and_return(true)
      expect(DRC).not_to receive(:bput)
      expect(em.get_item?(item)).to be true
    end

    it 'returns false with message when item cannot be found anywhere' do
      item = double('item', short_name: 'sword', short_regex: /\bsword/i,
                            wield: false, transforms_to: nil, tie_to: nil,
                            worn: false, container: nil, name: 'sword')
      allow(DRCI).to receive(:in_hands?).and_return(false)
      # get_item_helper(:stowed) is the last resort - stub it to return nil (not found)
      allow(em).to receive(:get_item_helper).and_return(nil)
      expect(Lich::Messaging).to receive(:msg).with('bold', /Could not find sword anywhere/)
      expect(em.get_item?(item)).to be false
    end

    it 'wields wield-type items directly via bput' do
      item = double('item', short_name: 'sword', short_regex: /\bsword/i, wield: true)
      allow(DRCI).to receive(:in_hands?).and_return(false)
      allow(DRC).to receive(:bput)
        .with('wield my sword', any_args)
        .and_return('You draw your sword from your scabbard.')
      expect(em.get_item?(item)).to be true
    end
  end

  # --- get_item_helper post-recovery snapshot check --------------------

  describe '#get_item_helper post-recovery uses snapshot comparison' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    before do
      allow(em).to receive(:waitrt?)
      allow(em).to receive(:pause)
    end

    it 'returns true when hands changed after failure recovery (not in_hands?)' do
      # This tests the transform case: after recovery the item in hand is the
      # TRANSFORMED form, not the base form. in_hands?(base_form) would return
      # false, but snapshot-changed correctly detects success.
      item = double('item',
                    short_name: 'orb', name: 'orb',
                    short_regex: /\borb/i,
                    transform_verb: 'twist',
                    transform_text: 'The orb twists into armor',
                    worn: false)

      # Snapshot: hands empty before command
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil, nil, 'armor')

      # bput returns a failure pattern
      allow(DRC).to receive(:bput)
        .with('twist my orb', any_args)
        .and_return("You'll need a free hand to do that!")

      # Recovery proc runs (stubbed to do nothing -- the hand change simulates success)
      # in_hands?(orb) would be false since hands hold "armor", not "orb"
      allow(DRCI).to receive(:in_hands?).with(item).and_return(false)

      expect(em.send(:get_item_helper, item, :transform)).to be true
    end

    it 'returns false when hands did NOT change after failure recovery' do
      item = double('item',
                    short_name: 'sword', name: 'sword',
                    short_regex: /\bsword/i,
                    transform_verb: nil, transform_text: nil, worn: false)

      # Hands unchanged throughout
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)

      # Noun check: sword not in hand (noun verification runs before case/when)
      allow(DRC).to receive(:left_hand_noun).and_return(nil)
      allow(DRC).to receive(:right_hand_noun).and_return(nil)

      # bput returns a failure; recovery does nothing; hands stay empty
      allow(DRC).to receive(:bput).and_return("You aren't wearing that.")

      expect(em.send(:get_item_helper, item, :worn)).to be false
    end
  end

  # --- item_noun_in_hands? ---------------------------------------------

  describe '#item_noun_in_hands?' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    it 'returns true when noun matches right hand' do
      allow(DRC).to receive(:left_hand_noun).and_return(nil)
      allow(DRC).to receive(:right_hand_noun).and_return('foil')
      expect(em.send(:item_noun_in_hands?, 'foil')).to be true
    end

    it 'returns true when noun matches left hand' do
      allow(DRC).to receive(:left_hand_noun).and_return('foil')
      allow(DRC).to receive(:right_hand_noun).and_return(nil)
      expect(em.send(:item_noun_in_hands?, 'foil')).to be true
    end

    it 'returns false when noun is not in either hand' do
      allow(DRC).to receive(:left_hand_noun).and_return(nil)
      allow(DRC).to receive(:right_hand_noun).and_return('sword')
      expect(em.send(:item_noun_in_hands?, 'foil')).to be false
    end

    it 'returns false when both hands are empty' do
      allow(DRC).to receive(:left_hand_noun).and_return(nil)
      allow(DRC).to receive(:right_hand_noun).and_return(nil)
      expect(em.send(:item_noun_in_hands?, 'foil')).to be false
    end
  end

  # --- get_item_helper XML noun verification (PR #1286 approach) ------

  describe '#get_item_helper XML noun verification' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }
    let(:item) do
      double('item',
             short_name: 'foil', name: 'foil',
             short_regex: /\bfoil/i,
             transform_verb: nil, transform_text: nil, worn: false)
    end

    before do
      allow(em).to receive(:waitrt?)
      allow(em).to receive(:pause)
    end

    context 'when bput false-positives on a combat message' do
      it 'returns true if the item arrived in hand despite bput returning a failure match' do
        # Scenario: "You get the feeling..." matches /^You get/ in bput,
        # bput returns "You get", which matches failure /^You get$/.
        # But the game DID process "get my foil" and the item is in hand.
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return(nil)
        allow(DRC).to receive(:bput).and_return('You get')

        # XML noun check detects the foil arrived
        allow(DRC).to receive(:left_hand_noun).and_return(nil)
        allow(DRC).to receive(:right_hand_noun).and_return('foil')

        expect(em.send(:get_item_helper, item, :stowed)).to be true
      end

      it 'does not call failure_recovery when noun check succeeds' do
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return(nil)
        allow(DRC).to receive(:bput).and_return('You get')

        allow(DRC).to receive(:left_hand_noun).and_return(nil)
        allow(DRC).to receive(:right_hand_noun).and_return('foil')

        # The stow (failure_recovery) must NOT fire
        expect(DRC).not_to receive(:bput).with('stow my foil', any_args)

        em.send(:get_item_helper, item, :stowed)
      end
    end

    context 'when bput false-positives and item is NOT in hand' do
      it 'falls through to failure recovery' do
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return(nil)
        allow(DRC).to receive(:left_hand_noun).and_return(nil)
        allow(DRC).to receive(:right_hand_noun).and_return(nil)

        # bput returns false-positive "You get"
        allow(DRC).to receive(:bput)
          .with('get my foil', any_args)
          .and_return('You get')

        # Failure recovery fires: stow command
        expect(DRC).to receive(:bput)
          .with('stow my foil', 'You put', 'But that is already in')
          .and_return('Stow what?')

        em.send(:get_item_helper, item, :stowed)
      end
    end

    context 'when item arrives after polling delay (XML feed lag)' do
      it 'returns true once noun appears in hand' do
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return(nil)
        allow(DRC).to receive(:bput).and_return('You get a steel foil')

        allow(DRC).to receive(:left_hand_noun).and_return(nil)
        # Noun not present on first 3 checks, then appears
        allow(DRC).to receive(:right_hand_noun).and_return(nil, nil, nil, 'foil')

        expect(em.send(:get_item_helper, item, :stowed)).to be true
      end
    end

    context 'with :transform type' do
      it 'skips noun verification and uses snapshot comparison' do
        transform_item = double('item',
                                short_name: 'orb', name: 'orb',
                                short_regex: /\borb/i,
                                transform_verb: 'twist',
                                transform_text: 'The orb twists into armor',
                                worn: false)

        # Snapshot detects hand change (orb -> armor)
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return('orb', 'armor')

        allow(DRC).to receive(:bput)
          .with('twist my orb', any_args)
          .and_return('The orb twists into armor')

        # Noun check would fail (orb != armor), but transform skips it
        allow(DRC).to receive(:left_hand_noun).and_return(nil)
        allow(DRC).to receive(:right_hand_noun).and_return('armor')

        expect(em.send(:get_item_helper, transform_item, :transform)).to be true
      end
    end

    context 'with :worn type (remove)' do
      it 'returns true via noun check when remove succeeds' do
        worn_item = double('item',
                           short_name: 'gloves', name: 'gloves',
                           short_regex: /\bgloves/i,
                           transform_verb: nil, transform_text: nil, worn: true)

        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return(nil)
        allow(DRC).to receive(:bput).and_return('You remove a pair of gloves')

        allow(DRC).to receive(:left_hand_noun).and_return(nil)
        allow(DRC).to receive(:right_hand_noun).and_return('gloves')

        expect(em.send(:get_item_helper, worn_item, :worn)).to be true
      end
    end
  end

  # --- transform recovery proc verb_data access -----------------------

  describe '#verb_data transform recovery proc' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }
    let(:item) do
      double('item',
             short_name: 'orb', name: 'orb',
             short_regex: /\borb/i,
             transform_verb: 'twist',
             transform_text: 'The orb twists into armor',
             worn: false)
    end

    it 'retries transform with correct patterns (verb_data[:transform][:matches], not verb_data[:matches])' do
      data = em.send(:verb_data, item)
      expected_matches = data[:transform][:matches]

      # Stub hands: left has something to stow, right is free
      allow(DRC).to receive(:left_hand).and_return('stick', nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRCI).to receive(:stow_hand).with('left').and_return(true)

      # First bput: re-get the base item
      allow(DRC).to receive(:bput)
        .with('get my orb', any_args)
        .and_return('You get an orb.')

      # Second bput: retry the transform -- verify it receives the correct patterns
      expect(DRC).to receive(:bput)
        .with('twist my orb', *expected_matches)
        .and_return('The orb twists into armor')

      data[:transform][:failure_recovery].call('orb', item, "You'll need a free hand to do that!")
    end
  end

  # --- wear_equipment_set? with gear-set items already in hand ----------

  describe '#wear_equipment_set? with gear-set items already in hand' do
    # Plain gear fixture: wear_missing_items dups items and flips @worn, so the
    # fixture must keep its state in instance variables (a double cannot).
    let(:gear_class) do
      Class.new do
        attr_reader :short_name, :short_regex, :worn, :needs_unloading, :transforms_to, :tie_to, :wield, :container

        def initialize(short_name:, short_regex:, worn:, wield: false, container: nil)
          @short_name = short_name
          @short_regex = short_regex
          @worn = worn
          @wield = wield
          @container = container
          @needs_unloading = false
          @transforms_to = nil
          @tie_to = nil
        end
      end
    end

    let(:shield) { gear_class.new(short_name: 'steel.shield', short_regex: /\bsteel.*\bshield/i, worn: true) }
    let(:helm) { gear_class.new(short_name: 'iron.helm', short_regex: /\biron.*\bhelm/i, worn: true) }
    let(:sword) { gear_class.new(short_name: 'bronze.sword', short_regex: /\bbronze.*\bsword/i, worn: false, container: 'scabbard') }
    let(:gear_sets) { { 'standard' => ['steel shield', 'iron helm'] } }
    let(:settings) { double('settings', gear_sets: gear_sets, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }

    let(:right_hand) { nil }
    let(:left_hand) { nil }
    let(:worn_now) { [] }
    let(:replies) { {} }
    let(:sent) { [] }
    let(:bold) { [] }

    before do
      allow(em).to receive(:items).and_return([shield, helm, sword])
      allow(em).to receive(:get_combat_items).and_return(worn_now)
      allow(em).to receive(:pause)
      allow(DRC).to receive(:right_hand) { right_hand }
      allow(DRC).to receive(:left_hand) { left_hand }
      allow(DRC).to receive(:beep)
      allow(DRC).to receive(:bput) do |command, *_patterns|
        sent << command
        replies.fetch(command, '')
      end
      allow(Lich::Messaging).to receive(:msg) { |type, text| bold << text if type == 'bold' }
    end

    def missing_warning?
      bold.any? { |line| line.include?('MISSING EQUIPMENT') }
    end

    def missing_list
      bold.find do |line|
        line.start_with?('EquipmentManager: ') && !line.include?('MISSING') &&
          !line.include?('stow_helper') && !line.include?('check your hands')
      end
    end

    def hands_line
      bold.find { |line| line.include?('check your hands') }
    end

    context 'when a held worn item is refused by WEAR' do
      let(:gear_sets) { { 'standard' => ['steel shield'] } }
      let(:left_hand) { 'steel shield' }
      let(:replies) { { 'wear my steel.shield' => "You can't wear that right now." } }

      it 'returns false' do
        expect(em.wear_equipment_set?('standard')).to be false
      end

      it 'raises the MISSING EQUIPMENT warning naming the held item, with beep and pause' do
        em.wear_equipment_set?('standard')
        expect(missing_warning?).to be true
        expect(missing_list).to eq('EquipmentManager: steel.shield')
        expect(DRC).to have_received(:beep).twice
        expect(em).to have_received(:pause)
      end

      it 'sends WEAR exactly once (no second attempt through the fetch-and-wear path)' do
        em.wear_equipment_set?('standard')
        expect(sent.count('wear my steel.shield')).to eq(1)
      end

      it 'tells the user to check their hands for the item' do
        em.wear_equipment_set?('standard')
        expect(hands_line).to eq('EquipmentManager: could not wear or put away, check your hands: steel.shield')
      end
    end

    context 'when the WEAR for a held worn item gets no reply (bput timeout)' do
      let(:gear_sets) { { 'standard' => ['steel shield'] } }
      let(:right_hand) { 'steel shield' }

      it 'returns false, warns, and does not resend WEAR' do
        expect(em.wear_equipment_set?('standard')).to be false
        expect(missing_warning?).to be true
        expect(sent).to eq(['wear my steel.shield'])
      end
    end

    context 'when a held worn item is worn successfully' do
      let(:gear_sets) { { 'standard' => ['steel shield'] } }
      let(:left_hand) { 'steel shield' }
      let(:replies) { { 'wear my steel.shield' => 'You strap your steel shield to your arm.' } }

      it 'returns true without a warning and sends WEAR once' do
        expect(em.wear_equipment_set?('standard')).to be true
        expect(missing_warning?).to be false
        expect(hands_line).to be_nil
        expect(DRC).not_to have_received(:beep)
        expect(sent).to eq(['wear my steel.shield'])
      end
    end

    context 'when a held non-worn set item is put away' do
      let(:gear_sets) { { 'standard' => ['bronze sword'] } }
      let(:right_hand) { 'bronze sword' }

      it 'returns true and never sends WEAR when the put-away succeeds' do
        replies['put my bronze.sword in my scabbard'] = 'You put your bronze sword in your scabbard.'
        expect(em.wear_equipment_set?('standard')).to be true
        expect(missing_warning?).to be false
        expect(sent).to eq(['put my bronze.sword in my scabbard'])
      end

      it 'returns false and warns, without a pointless WEAR, when the put-away fails' do
        replies['put my bronze.sword in my scabbard'] = "There isn't any more room in your scabbard."
        expect(em.wear_equipment_set?('standard')).to be false
        expect(missing_warning?).to be true
        expect(missing_list).to eq('EquipmentManager: bronze.sword')
        expect(sent.grep(/^wear /)).to be_empty
      end
    end

    context 'when a refused held item and an unheld item are both in the set' do
      let(:left_hand) { 'steel shield' }
      let(:replies) { { 'wear my steel.shield' => "You can't wear that right now." } }

      before do
        allow(em).to receive(:get_item?).with(having_attributes(short_name: 'iron.helm')).and_return(true)
        allow(DRCI).to receive(:wear_item?).with('iron.helm').and_return(true)
      end

      it 'wears the unheld item, lists only the held failure, and returns false' do
        expect(em.wear_equipment_set?('standard')).to be false
        expect(DRCI).to have_received(:wear_item?).with('iron.helm').once
        expect(missing_list).to eq('EquipmentManager: steel.shield')
        expect(sent.count('wear my steel.shield')).to eq(1)
      end

      it 'puts the held item away before fetching the unheld one (hands are freed first)' do
        em.wear_equipment_set?('standard')
        expect(DRC).to have_received(:bput).with('wear my steel.shield', any_args).ordered
        expect(em).to have_received(:get_item?).ordered
      end
    end

    context 'when both a held and an unheld item fail' do
      let(:right_hand) { 'iron helm' }
      let(:replies) { { 'wear my iron.helm' => "You can't wear that right now." } }

      before do
        allow(em).to receive(:get_item?).with(having_attributes(short_name: 'steel.shield')).and_return(false)
      end

      it 'lists both failures in gear-set order' do
        expect(em.wear_equipment_set?('standard')).to be false
        expect(missing_list).to eq('EquipmentManager: steel.shield, iron.helm')
      end

      it 'names only the held failure in the check-your-hands line' do
        em.wear_equipment_set?('standard')
        expect(hands_line).to eq('EquipmentManager: could not wear or put away, check your hands: iron.helm')
      end
    end

    context 'when two set items match the same held item and the first put-away empties the hand' do
      let(:chain_helm) { gear_class.new(short_name: 'iron.chain.helm', short_regex: /\biron.*\bchain.*\bhelm/i, worn: true) }
      let(:gear_sets) { { 'standard' => ['iron chain helm', 'iron helm'] } }
      let(:replies) { { 'wear my iron.chain.helm' => 'You put on an iron chain helm.' } }

      before do
        @hand = 'iron chain helm'
        allow(em).to receive(:items).and_return([chain_helm, helm])
        allow(DRC).to receive(:right_hand) { @hand }
        allow(DRC).to receive(:bput) do |command, *_patterns|
          sent << command
          @hand = nil if command == 'wear my iron.chain.helm'
          replies.fetch(command, '')
        end
        allow(em).to receive(:get_item?).with(having_attributes(short_name: 'iron.helm')).and_return(true)
        allow(DRCI).to receive(:wear_item?).with('iron.helm').and_return(true)
      end

      it 'fetches and wears the second item instead of sending it a WEAR from an empty hand' do
        expect(em.wear_equipment_set?('standard')).to be true
        expect(sent).to eq(['wear my iron.chain.helm'])
        expect(DRCI).to have_received(:wear_item?).with('iron.helm').once
        expect(missing_warning?).to be false
      end

      context 'with an unheld item after them in the set' do
        let(:gear_sets) { { 'standard' => ['iron chain helm', 'iron helm', 'steel shield'] } }

        before do
          allow(em).to receive(:items).and_return([chain_helm, helm, shield])
          allow(em).to receive(:get_item?) do |item|
            sent << "get #{item.short_name}"
            true
          end
          allow(DRCI).to receive(:wear_item?) do |name|
            sent << "wear #{name}"
            true
          end
        end

        it 'fetches and wears the re-queued item in its gear-set position, before the later unheld item' do
          expect(em.wear_equipment_set?('standard')).to be true
          expect(sent).to eq(['wear my iron.chain.helm', 'get iron.helm', 'wear iron.helm', 'get steel.shield', 'wear steel.shield'])
        end
      end
    end

    context 'when two set descriptions resolve to the same gear item' do
      # item_by_desc returns the first gear item whose regex matches, so both
      # 'cloak' and 'iron cloak' resolve to the plain cloak here.
      let(:cloak) { gear_class.new(short_name: 'cloak', short_regex: /\bcloak/i, worn: true) }
      let(:iron_cloak) { gear_class.new(short_name: 'iron.cloak', short_regex: /\biron.*\bcloak/i, worn: true) }
      let(:gear_sets) { { 'standard' => ['cloak', 'iron cloak'] } }

      before { allow(em).to receive(:items).and_return([cloak, iron_cloak]) }

      context 'and it is held and refused by WEAR' do
        let(:right_hand) { 'iron cloak' }
        let(:replies) { { 'wear my cloak' => "You can't wear that right now." } }

        it 'sends WEAR once and names the item once in each warning line' do
          expect(em.wear_equipment_set?('standard')).to be false
          expect(sent).to eq(['wear my cloak'])
          expect(hands_line).to eq('EquipmentManager: could not wear or put away, check your hands: cloak')
          expect(missing_list).to eq('EquipmentManager: cloak')
        end
      end

      context 'and it is held and its put-away empties the hand' do
        let(:right_hand) { 'iron cloak' }
        let(:replies) { { 'wear my cloak' => 'You put on an iron cloak.' } }

        before do
          allow(DRC).to receive(:right_hand) { sent.empty? ? 'iron cloak' : nil }
          allow(em).to receive(:get_item?).and_return(true)
          allow(DRCI).to receive(:wear_item?).with('cloak').and_return(true)
        end

        it 'fetches and wears the second entry, as before' do
          expect(em.wear_equipment_set?('standard')).to be true
          expect(sent).to eq(['wear my cloak'])
          expect(DRCI).to have_received(:wear_item?).with('cloak').once
        end
      end

      context 'and it is not held and cannot be fetched' do
        before { allow(em).to receive(:get_item?).and_return(false) }

        it 'lists it once' do
          expect(em.wear_equipment_set?('standard')).to be false
          expect(missing_list).to eq('EquipmentManager: cloak')
        end
      end
    end

    context 'when every set item is already worn' do
      let(:right_hand) { 'steel shield' }
      let(:worn_now) { ['a steel shield', 'an iron helm'] }

      it 'sends nothing and returns true even if a matching item is also in hand' do
        expect(em.wear_equipment_set?('standard')).to be true
        expect(sent).to be_empty
        expect(missing_warning?).to be false
      end
    end

    context 'when an unheld item cannot be fetched (existing behaviour)' do
      let(:gear_sets) { { 'standard' => ['iron helm'] } }

      it 'returns false and warns, without a check-your-hands line' do
        allow(em).to receive(:get_item?).and_return(false)
        expect(em.wear_equipment_set?('standard')).to be false
        expect(missing_list).to eq('EquipmentManager: iron.helm')
        expect(hands_line).to be_nil
      end
    end
  end

  describe '#stow_weapon return value' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { described_class.new(settings) }
    let(:shield) do
      double('shield', short_name: 'steel.shield', short_regex: /\bsteel.*\bshield/i,
                       needs_unloading: false, worn: true)
    end

    before do
      allow(em).to receive(:items).and_return([shield])
      allow(Lich::Messaging).to receive(:msg)
    end

    it 'is true when the WEAR succeeds' do
      allow(DRC).to receive(:bput).and_return('You strap your steel shield to your arm.')
      expect(em.stow_weapon('steel shield')).to be true
    end

    it 'is false when the WEAR is refused' do
      allow(DRC).to receive(:bput).and_return("You can't wear that right now.")
      expect(em.stow_weapon('steel shield')).to be false
    end

    it 'is nil when the description is not in the gear list' do
      expect(DRC).not_to receive(:bput)
      expect(em.stow_weapon('golden halberd')).to be_nil
    end

    it 'is nil when called without a description' do
      allow(DRC).to receive(:right_hand).and_return('steel shield')
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:bput).and_return('You strap your steel shield to your arm.')
      expect(em.stow_weapon).to be_nil
    end
  end
end
