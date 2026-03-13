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

    it 'does not define local SHEATH_SUCCESS_PATTERNS' do
      expect(described_class.const_defined?(:SHEATH_SUCCESS_PATTERNS)).to be false
    end

    it 'does not define local SHEATH_FAILURE_PATTERNS' do
      expect(described_class.const_defined?(:SHEATH_FAILURE_PATTERNS)).to be false
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
        allow(DRC).to receive(:bput)
          .with('sheath my sword', anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything)
          .and_return('Sheath your sword where?')
        allow(DRC).to receive(:bput)
          .with('stow my sword', anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything, anything)
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
        # Simulate "two free hands" every time — counter should stop it
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
end
