# frozen_string_literal: true

require 'spec_helper'

# Stub Lich::Util for inv command
module Lich
  module Util
    def self.issue_command(_command, *_args, **_kwargs)
      []
    end
  end
end unless defined?(Lich::Util)

# Stub UserVars
module UserVars
  def self.equipmanager_debug
    false
  end
end unless defined?(UserVars)

# Define global methods used by EquipmentManager as private Object methods.
# These exist in the game runtime as Kernel-level methods.
def echo(_msg); end

def pause(_seconds = nil); end

def waitrt?; end

def fput(_command); end

def get_settings
  OpenStruct.new(gear_sets: {}, sort_auto_head: false, gear: [])
end

# Load production code
require_relative '../../../../lib/dragonrealms/commons/common'
require_relative '../../../../lib/dragonrealms/commons/common-items'
require_relative '../../../../lib/dragonrealms/commons/equipmanager'

RSpec.describe Lich::DragonRealms::EquipmentManager do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }

  def make_item(overrides = {})
    defaults = {
      name: 'sword', leather: false, worn: false,
      hinders_locks: false, swappable: false, tie_to: nil,
      adjective: nil, bound: false, wield: false,
      transforms_to: nil, transform_verb: nil, transform_text: nil,
      lodges: true, skip_repair: false, ranged: false, needs_unloading: false,
      container: nil
    }
    Lich::DragonRealms::DRC::Item.new(**defaults.merge(overrides))
  end

  def make_settings(gear: [], gear_sets: {}, sort_auto_head: false)
    OpenStruct.new(
      gear: gear,
      gear_sets: gear_sets,
      sort_auto_head: sort_auto_head
    )
  end

  # Shared stubs for EquipmentManager instances.
  # Game-runtime methods (echo, waitrt?, pause, fput) are private Object methods.
  # We stub them on the EM instance so RSpec can intercept them.
  def stub_game_methods(em)
    allow(em).to receive(:echo)
    allow(em).to receive(:waitrt?)
    allow(em).to receive(:pause)
    allow(em).to receive(:fput)
  end

  # ── wear_equipment_set? ──────────────────────────────────────────

  describe '#wear_equipment_set?' do
    context 'when set_name is nil' do
      it 'returns false' do
        em = described_class.new(make_settings)
        expect(em.wear_equipment_set?(nil)).to be false
      end
    end

    context 'when gear set does not exist' do
      it 'returns false and prints a message' do
        em = described_class.new(make_settings(gear_sets: { 'combat' => ['sword'] }))
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Could not find gear set 'missing'/)
        expect(em.wear_equipment_set?('missing')).to be false
      end
    end

    context 'when gear set exists and all items are worn' do
      it 'returns true' do
        gear = [{ name: 'gloves', is_leather: true, is_worn: true }]
        sets = { 'standard' => ['gloves'] }
        em = described_class.new(make_settings(gear: gear, gear_sets: sets))
        stub_game_methods(em)

        allow(Lich::Util).to receive(:issue_command).and_return(['leather gloves'])
        allow(drc).to receive(:bput)
        allow(drc).to receive(:right_hand).and_return(nil)
        allow(drc).to receive(:left_hand).and_return(nil)

        expect(em.wear_equipment_set?('standard')).to be true
      end
    end
  end

  # ── wield_weapon? ────────────────────────────────────────────────

  describe '#wield_weapon?' do
    let(:gear) { [{ name: 'sword', is_worn: false, is_leather: false }] }
    let(:em) { described_class.new(make_settings(gear: gear)) }

    before do
      stub_game_methods(em)
      allow(drc).to receive(:right_hand).and_return(nil)
      allow(drc).to receive(:left_hand).and_return(nil)
    end

    context 'with nil description' do
      it 'returns nil' do
        expect(em.wield_weapon?(nil)).to be_nil
      end
    end

    context 'with empty description' do
      it 'returns nil' do
        expect(em.wield_weapon?('')).to be_nil
      end
    end

    context 'when description does not match any item' do
      it 'returns false with a message' do
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Failed to match a weapon/)
        expect(em.wield_weapon?('nonexistent')).to be false
      end
    end

    context 'when get_item? succeeds (non-offhand)' do
      it 'returns true (bug fix 1b validation)' do
        allow(em).to receive(:get_item?).and_return(true)
        expect(em.wield_weapon?('sword')).to be true
      end
    end

    context 'when get_item? fails' do
      it 'returns false' do
        allow(em).to receive(:get_item?).and_return(false)
        expect(em.wield_weapon?('sword')).to be false
      end
    end

    context 'when skill is Offhand Weapon and swap succeeds' do
      it 'returns true' do
        allow(em).to receive(:get_item?).and_return(true)
        allow(em).to receive(:stow_weapon)
        allow(drc).to receive(:right_hand).and_return('sword')
        allow(drc).to receive(:bput).and_return('You move a sword to your left hand')
        expect(em.wield_weapon?('sword', 'Offhand Weapon')).to be true
      end
    end

    context 'when skill is Offhand Weapon and swap fails' do
      it 'returns false' do
        allow(em).to receive(:get_item?).and_return(true)
        allow(em).to receive(:stow_weapon)
        allow(drc).to receive(:right_hand).and_return('sword')
        allow(drc).to receive(:bput).and_return('Will alone cannot conquer the paralysis')
        expect(em.wield_weapon?('sword', 'Offhand Weapon')).to be false
      end
    end

    context 'with swappable weapon and skill' do
      let(:gear) { [{ name: 'sword', is_worn: false, is_leather: false, swappable: true }] }

      it 'calls swap_to_skill? after getting item' do
        allow(em).to receive(:get_item?).and_return(true)
        expect(em).to receive(:swap_to_skill?).with('sword', 'Large Edged')
        em.wield_weapon?('sword', 'Large Edged')
      end
    end
  end

  # ── wear_item? ───────────────────────────────────────────────────

  describe '#wear_item?' do
    let(:gear) { [{ name: 'gloves', is_worn: true, is_leather: true }] }
    let(:em) { described_class.new(make_settings(gear: gear)) }

    before { stub_game_methods(em) }

    context 'when item is nil' do
      it 'returns false' do
        expect(em.wear_item?(nil)).to be false
      end
    end

    context 'when get_item? succeeds and DRCI.wear_item? succeeds' do
      it 'returns true' do
        item = em.items.first
        allow(em).to receive(:get_item?).with(item).and_return(true)
        allow(drci).to receive(:wear_item?).with(item.short_name).and_return(true)
        expect(em.wear_item?(item)).to be true
      end
    end

    context 'when get_item? succeeds but DRCI.wear_item? fails (bug fix 1f)' do
      it 'returns false instead of always true' do
        item = em.items.first
        allow(em).to receive(:get_item?).with(item).and_return(true)
        allow(drci).to receive(:wear_item?).with(item.short_name).and_return(false)
        expect(em.wear_item?(item)).to be false
      end
    end

    context 'when get_item? fails' do
      it 'returns false' do
        item = em.items.first
        allow(em).to receive(:get_item?).with(item).and_return(false)
        expect(em.wear_item?(item)).to be false
      end
    end
  end

  # ── get_item? transforms_to ──────────────────────────────────────

  describe '#get_item? with transforms_to' do
    let(:gear) do
      [
        { name: 'orb', is_worn: false, is_leather: false, transforms_to: 'gauntlets', transform_verb: 'wear', transform_text: 'The orb shifts' },
        { name: 'gauntlets', is_worn: true, is_leather: false }
      ]
    end
    let(:em) { described_class.new(make_settings(gear: gear)) }

    before do
      stub_game_methods(em)
      allow(drci).to receive(:in_hands?).and_return(false)
    end

    context 'when pre-transform retrieval fails (bug fix 1c)' do
      it 'returns false and prints a message' do
        allow(em).to receive(:get_item_helper).with(anything, :worn).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Unable to retrieve .* for transform/)
        expect(em.get_item?(em.items.first)).to be false
      end
    end

    context 'when transforms_to item not found in gear list' do
      let(:gear) do
        [{ name: 'orb', is_worn: false, is_leather: false, transforms_to: 'nonexistent', transform_verb: 'wear', transform_text: 'The orb shifts' }]
      end

      it 'returns false with a message' do
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Could not find transformed item/)
        expect(em.get_item?(em.items.first)).to be false
      end
    end

    context 'when pre-transform retrieval succeeds' do
      it 'calls get_item_helper with :transform' do
        gauntlets_item = em.items.find { |i| i.name == 'gauntlets' }
        allow(em).to receive(:get_item_helper).with(gauntlets_item, :worn).and_return(true)
        expect(em).to receive(:get_item_helper).with(gauntlets_item, :transform)
        em.get_item?(em.items.first)
      end
    end
  end

  # ── get_item_helper ──────────────────────────────────────────────

  describe '#get_item_helper' do
    let(:gear) { [{ name: 'shield', is_worn: true, is_leather: false }] }
    let(:em) { described_class.new(make_settings(gear: gear)) }
    let(:item) { em.items.first }

    before do
      stub_game_methods(em)
      allow(drc).to receive(:left_hand).and_return(nil)
      allow(drc).to receive(:right_hand).and_return(nil)
    end

    context 'with nil item' do
      it 'returns false' do
        expect(em.send(:get_item_helper, nil, :worn)).to be false
      end
    end

    context 'when bput returns nil (timeout)' do
      it 'returns false with a message' do
        allow(drc).to receive(:bput).and_return(nil)
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: No response from game/)
        expect(em.send(:get_item_helper, item, :worn)).to be false
      end
    end

    context 'when bput returns empty string' do
      it 'returns false with a message' do
        allow(drc).to receive(:bput).and_return('')
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: No response from game/)
        expect(em.send(:get_item_helper, item, :worn)).to be false
      end
    end

    context 'when response matches an exhausted pattern' do
      it 'returns false' do
        allow(drc).to receive(:bput).and_return('Remove what')
        expect(em.send(:get_item_helper, item, :worn)).to be false
      end
    end

    context 'when response matches a failure and recovery is invoked (bug fix 1e)' do
      before do
        # Stub DRC.message since failure_recovery proc calls it (bput("wear my shield") in the recovery)
        allow(Lich::Messaging).to receive(:msg)
        allow(drc).to receive(:bput).and_return("You get ")
      end

      it 'returns result of DRCI.in_hands? after recovery' do
        allow(drci).to receive(:in_hands?).with(item).and_return(true)
        expect(em.send(:get_item_helper, item, :worn)).to be true
      end

      it 'returns false when item not in hands after recovery' do
        allow(drci).to receive(:in_hands?).with(item).and_return(false)
        expect(em.send(:get_item_helper, item, :worn)).to be false
      end
    end

    context 'when response is a success and hands change' do
      it 'returns true' do
        call_count = 0
        allow(drc).to receive(:bput).and_return('You remove a shield')
        allow(drc).to receive(:right_hand) { call_count += 1; call_count > 1 ? 'shield' : nil }
        expect(em.send(:get_item_helper, item, :worn)).to be true
      end
    end
  end

  # ── unload_weapon ────────────────────────────────────────────────

  describe '#unload_weapon' do
    let(:gear) { [{ name: 'crossbow', is_worn: false, is_leather: false, ranged: true, needs_unloading: true }] }
    let(:em) { described_class.new(make_settings(gear: gear)) }

    before { stub_game_methods(em) }

    context 'when ammo falls to the ground (hands full path)' do
      it 'lowers weapon, stows ammo, and picks weapon back up' do
        allow(drc).to receive(:bput).and_return('Your bolt falls from your crossbow to your feet.')
        expect(drci).to receive(:lower_item?).with('crossbow').and_return(true)
        expect(drci).to receive(:put_away_item?).with('bolt')
        expect(drci).to receive(:get_item?).with('crossbow').and_return(true)
        em.send(:unload_weapon, 'crossbow')
      end

      context 'when lower_item? fails' do
        it 'prints a warning and returns' do
          allow(drc).to receive(:bput).and_return('Your bolt falls from your crossbow to your feet.')
          allow(drci).to receive(:lower_item?).with('crossbow').and_return(false)
          expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Unable to lower crossbow to pick up ammo/)
          em.send(:unload_weapon, 'crossbow')
        end
      end

      context 'when get_item? fails after picking up ammo' do
        it 'prints a warning' do
          allow(drc).to receive(:bput).and_return('Your bolt falls from your crossbow to your feet.')
          allow(drci).to receive(:lower_item?).with('crossbow').and_return(true)
          allow(drci).to receive(:put_away_item?).with('bolt')
          allow(drci).to receive(:get_item?).with('crossbow').and_return(false)
          expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Unable to pick crossbow back up after unloading/)
          em.send(:unload_weapon, 'crossbow')
        end
      end
    end

    context 'when ammo is in hand after unloading' do
      it 'stows the hand not holding the weapon' do
        allow(drc).to receive(:bput).and_return('You unload the crossbow')
        allow(drci).to receive(:in_left_hand?).with('crossbow').and_return(false)
        allow(drci).to receive(:in_right_hand?).with('crossbow').and_return(true)
        expect(drci).to receive(:stow_hand).with('left').and_return(true)
        em.send(:unload_weapon, 'crossbow')
      end

      context 'when stow_hand fails' do
        it 'prints a warning' do
          allow(drc).to receive(:bput).and_return('You unload the crossbow')
          allow(drci).to receive(:in_left_hand?).with('crossbow').and_return(false)
          allow(drci).to receive(:in_right_hand?).with('crossbow').and_return(true)
          allow(drci).to receive(:stow_hand).with('left').and_return(false)
          expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Unable to stow ammo from left hand/)
          em.send(:unload_weapon, 'crossbow')
        end
      end
    end
  end

  # ── swap_to_skill? ──────────────────────────────────────────────

  describe '#swap_to_skill?' do
    let(:em) { described_class.new(make_settings) }

    before { stub_game_methods(em) }

    context 'with a fan weapon' do
      it 'opens fan for edged skill' do
        expect(drc).to receive(:bput).with('open my fan', 'you snap', 'already').and_return('you snap')
        expect(em.send(:swap_to_skill?, 'fan', 'small edged')).to be true
      end

      it 'closes fan for non-edged skill' do
        expect(drc).to receive(:bput).with('close my fan', 'you snap', 'already').and_return('you snap')
        expect(em.send(:swap_to_skill?, 'fan', 'small blunt')).to be true
      end
    end

    context 'with Offhand Weapon skill' do
      it 'returns true immediately' do
        expect(em.send(:swap_to_skill?, 'sword', 'Offhand Weapon')).to be true
      end
    end

    context 'with unsupported skill' do
      it 'returns false with a message' do
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Unsupported weapon swap/)
        expect(em.send(:swap_to_skill?, 'sword', 'Underwater Basket Weaving')).to be false
      end
    end

    context 'when two free hands are needed' do
      it 'stows non-weapon items using DRCI.stow_hand (bug fix 1h)' do
        call_count = 0
        allow(drc).to receive(:bput) do |_cmd, *_args|
          call_count += 1
          call_count == 1 ? 'You must have two free hands' : ' heavy edged '
        end
        # Before stow: left has shield, right has sword
        # After stow: left nil, right still sword
        left_values = ['shield', nil, nil]
        left_idx = 0
        allow(drc).to receive(:left_hand) { v = left_values[left_idx] || nil; left_idx += 1; v }
        allow(drc).to receive(:right_hand).and_return('sword')
        expect(drci).to receive(:stow_hand).with('left').and_return(true)
        expect(em.send(:swap_to_skill?, 'sword', 'Large Edged')).to be true
      end

      context 'when stow_hand fails to free hands' do
        it 'returns false with a message' do
          allow(drc).to receive(:bput).and_return('You must have two free hands')
          allow(drc).to receive(:left_hand).and_return('shield')
          allow(drc).to receive(:right_hand).and_return('sword')
          allow(drci).to receive(:stow_hand).with('left').and_return(true)
          expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Unable to free hands for weapon swap/)
          expect(em.send(:swap_to_skill?, 'sword', 'Large Edged')).to be false
        end
      end
    end

    context 'when swap matches desired skill on first try' do
      it 'returns true' do
        allow(drc).to receive(:bput).and_return(' heavy edged ')
        expect(em.send(:swap_to_skill?, 'sword', 'Large Edged')).to be true
      end
    end

    context 'when swap exceeds max attempts' do
      it 'returns false' do
        # Returns a wrong skill every time — loop exits after weapon_skills.length + 1 iterations
        allow(drc).to receive(:bput).and_return('sword light edged')
        expect(em.send(:swap_to_skill?, 'sword', 'Large Edged')).to be false
      end
    end
  end

  # ── stow_helper ─────────────────────────────────────────────────

  describe '#stow_helper' do
    let(:em) { described_class.new(make_settings) }

    before do
      stub_game_methods(em)
      allow(drc).to receive(:retreat)
    end

    context 'when action succeeds on first try' do
      it 'does not recurse' do
        allow(drc).to receive(:bput).and_return('You put your sword in your bag')
        em.send(:stow_helper, 'stow my sword', 'sword', /You put/)
      end
    end

    context 'when retries are exhausted' do
      it 'prints a warning and returns' do
        allow(drc).to receive(:bput).and_return('You are a little too busy')
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: stow_helper exceeded max retries/)
        em.send(:stow_helper, 'stow my sword', 'sword', /You put/, retries: 1)
      end
    end

    context 'when unload recovery is triggered' do
      it 'calls unload_weapon and retries' do
        call_count = 0
        allow(drc).to receive(:bput) do |_cmd, *_args|
          call_count += 1
          call_count == 1 ? 'unload' : 'You sheathe your sword'
        end
        expect(em).to receive(:unload_weapon).with('sword')
        em.send(:stow_helper, 'sheath my sword', 'sword', /You sheathe/)
      end
    end

    context 'when fan close recovery is triggered' do
      it 'closes the fan and retries' do
        call_count = 0
        allow(drc).to receive(:bput) do |_cmd, *_args|
          call_count += 1
          call_count == 1 ? 'close the fan' : 'You sheathe your fan'
        end
        expect(em).to receive(:fput).with('close my fan')
        em.send(:stow_helper, 'sheath my fan', 'fan', /You sheathe/)
      end
    end

    context 'when too busy recovery is triggered' do
      it 'retreats and retries' do
        call_count = 0
        allow(drc).to receive(:bput) do |_cmd, *_args|
          call_count += 1
          call_count == 1 ? 'You are a little too busy' : 'You put your sword in your bag'
        end
        expect(drc).to receive(:retreat)
        em.send(:stow_helper, 'stow my sword', 'sword', /You put/)
      end
    end

    context 'when immobilized recovery is triggered' do
      it 'pauses and retries' do
        call_count = 0
        allow(drc).to receive(:bput) do |_cmd, *_args|
          call_count += 1
          call_count == 1 ? "You don't seem to be able to move" : 'You put your sword'
        end
        expect(em).to receive(:pause).with(1)
        em.send(:stow_helper, 'stow my sword', 'sword', /You put/)
      end
    end

    context 'when too-small-to-hold recovery is triggered' do
      it 'swaps and retries' do
        call_count = 0
        allow(drc).to receive(:bput) do |_cmd, *_args|
          call_count += 1
          call_count == 1 ? 'is too small to hold that' : 'You sheathe'
        end
        expect(em).to receive(:fput).with('swap my sword')
        em.send(:stow_helper, 'sheath my sword', 'sword', /You sheathe/)
      end
    end

    context 'when wounds/sheathe-where recovery is triggered' do
      it 'falls back to generic stow' do
        call_count = 0
        allow(drc).to receive(:bput) do |_cmd, *_args|
          call_count += 1
          call_count == 1 ? 'Your wounds hinder your ability to do that' : 'You put your sword in your bag'
        end
        em.send(:stow_helper, 'sheath my sword', 'sword', /You sheathe/)
      end
    end
  end

  # ── remove_item ─────────────────────────────────────────────────

  describe '#remove_item' do
    let(:gear) do
      [
        { name: 'shield', is_worn: true, is_leather: false },
        { name: 'orb', is_worn: true, is_leather: false, transforms_to: 'gauntlets' },
        { name: 'gauntlets', is_worn: true, is_leather: false, tie_to: 'belt' }
      ]
    end
    let(:em) { described_class.new(make_settings(gear: gear)) }

    before { stub_game_methods(em) }

    context 'when item has constriction timer' do
      it 'returns false with a message' do
        item = em.items.find { |i| i.name == 'shield' }
        allow(drc).to receive(:bput).and_return('then constricts tighter around your')
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager:.*not ready to be removed yet/)
        expect(em.remove_item(item)).to be false
      end
    end

    context 'when removing an item that transforms (bug fix 1d)' do
      it 'handles nil transform item gracefully' do
        item = make_item(name: 'widget', worn: true, transforms_to: 'nonexistent')
        allow(drc).to receive(:bput).and_return('You remove a widget')
        allow(drci).to receive(:in_hands?).with('nonexistent').and_return(true)
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Could not find transformed item/)
        em.remove_item(item)
      end
    end

    context 'when remove fails and one hand was empty' do
      it 'does not call get_item_if_not_held? with nil' do
        item = em.items.find { |i| i.name == 'shield' }
        bput_count = 0
        allow(drc).to receive(:bput) do |_cmd, *_args|
          bput_count += 1
          if bput_count == 1
            'You need a free hand to do that'
          else
            # Recursive remove_item call succeeds
            'You sling a shield over your shoulder'
          end
        end
        allow(drc).to receive(:left_hand).and_return(nil)
        allow(drc).to receive(:right_hand).and_return('sword')
        allow(drci).to receive(:lower_item?).with('sword').and_return(true)
        # Should only pick up the non-nil hand item, never call with nil
        expect(drci).to receive(:get_item_if_not_held?).with('sword').once
        expect(drci).not_to receive(:get_item_if_not_held?).with(nil)
        em.remove_item(item)
      end
    end

    context 'when removing succeeds and item has tie_to' do
      it 'ties item to the correct location' do
        item = em.items.find { |i| i.name == 'gauntlets' }
        allow(drc).to receive(:bput).and_return('You remove a pair of gauntlets')
        allow(drci).to receive(:in_hands?).and_return(false)
        expect(em).to receive(:stow_helper).with(
          'tie my gauntlets to my belt', 'gauntlets',
          *Lich::DragonRealms::DRCI::TIE_ITEM_SUCCESS_PATTERNS,
          *Lich::DragonRealms::DRCI::TIE_ITEM_FAILURE_PATTERNS
        )
        em.remove_item(item)
      end
    end

    context 'when removing succeeds and item has wield' do
      it 'sheathes the item' do
        item = make_item(name: 'dagger', wield: true, worn: false)
        allow(drc).to receive(:bput).and_return('You remove a dagger')
        allow(drci).to receive(:in_hands?).and_return(false)
        expect(em).to receive(:stow_helper).with(
          'sheath my dagger', 'dagger',
          *described_class::SHEATH_SUCCESS_PATTERNS,
          *described_class::SHEATH_FAILURE_PATTERNS
        )
        em.remove_item(item)
      end
    end
  end

  # ── return_held_gear ────────────────────────────────────────────

  describe '#return_held_gear' do
    let(:gear) { [{ name: 'shield', is_worn: true, is_leather: false, tie_to: 'belt' }] }
    let(:sets) { { 'standard' => ['shield'] } }
    let(:em) { described_class.new(make_settings(gear: gear, gear_sets: sets)) }

    before { stub_game_methods(em) }

    context 'when hands are empty' do
      it 'returns nil' do
        allow(drc).to receive(:right_hand).and_return(nil)
        allow(drc).to receive(:left_hand).and_return(nil)
        expect(em.return_held_gear).to be_nil
      end
    end

    context 'when holding an item from gear set' do
      it 'wears the item' do
        allow(drc).to receive(:right_hand).and_return('shield')
        allow(drc).to receive(:left_hand).and_return(nil)
        expect(em).to receive(:stow_helper).with(
          'wear my shield', 'shield',
          *Lich::DragonRealms::DRCI::WEAR_ITEM_SUCCESS_PATTERNS
        )
        em.return_held_gear('standard')
      end
    end

    context 'when gear set does not exist' do
      it 'does not crash and returns false' do
        allow(drc).to receive(:right_hand).and_return('sword')
        allow(drc).to receive(:left_hand).and_return(nil)
        # 'nonexistent' is not in @gear_sets, so @gear_sets['nonexistent'] is nil
        # With the fix, desc_to_items(nil || []) => desc_to_items([]) => []
        expect(em.return_held_gear('nonexistent')).to be false
      end
    end

    context 'when holding a tie_to item not in gear set' do
      let(:sets) { { 'standard' => [] } }

      it 'ties the item with correct my prefix (bug fix 1g)' do
        allow(drc).to receive(:right_hand).and_return('shield')
        allow(drc).to receive(:left_hand).and_return(nil)
        expect(em).to receive(:stow_helper).with(
          'tie my shield to my belt', 'shield',
          *Lich::DragonRealms::DRCI::TIE_ITEM_SUCCESS_PATTERNS,
          *Lich::DragonRealms::DRCI::TIE_ITEM_FAILURE_PATTERNS
        )
        em.return_held_gear('standard')
      end
    end
  end

  # ── listed_item? / is_listed_item? ──────────────────────────────

  describe '#listed_item? and #is_listed_item?' do
    let(:gear) { [{ name: 'sword', is_worn: false, is_leather: false, adjective: 'steel' }] }
    let(:em) { described_class.new(make_settings(gear: gear)) }

    it 'finds matching item by description' do
      expect(em.listed_item?('a steel sword')).to eq(em.items.first)
    end

    it 'returns nil for non-matching description' do
      expect(em.listed_item?('a bronze mace')).to be_nil
    end

    it 'is_listed_item? delegates to listed_item?' do
      expect(em.is_listed_item?('a steel sword')).to eq(em.listed_item?('a steel sword'))
    end
  end

  # ── matching_combat_items / worn_items ──────────────────────────

  describe '#matching_combat_items and #worn_items' do
    let(:gear) { [{ name: 'shield', is_worn: true, is_leather: false }, { name: 'gloves', is_worn: true, is_leather: true }] }
    let(:em) { described_class.new(make_settings(gear: gear)) }

    before do
      allow(Lich::Util).to receive(:issue_command).and_return(['a heavy shield', 'some leather gloves'])
    end

    it 'returns items from combat inv matching the filter list' do
      result = em.matching_combat_items(['shield'])
      expect(result.map(&:name)).to include('shield')
      expect(result.map(&:name)).not_to include('gloves')
    end

    it 'worn_items delegates to matching_combat_items' do
      filter = ['shield']
      expect(em.worn_items(filter)).to eq(em.matching_combat_items(filter))
    end
  end

  # ── stow_weapon ──────────────────────────────────────────────────

  describe '#stow_weapon' do
    let(:gear) do
      [
        { name: 'sword', is_worn: false, is_leather: false, wield: true },
        { name: 'shield', is_worn: true, is_leather: false },
        { name: 'dagger', is_worn: false, is_leather: false, tie_to: 'belt' },
        { name: 'lockpick', is_worn: false, is_leather: false, container: 'toolkit' }
      ]
    end
    let(:em) { described_class.new(make_settings(gear: gear)) }

    before do
      stub_game_methods(em)
      allow(drc).to receive(:right_hand).and_return(nil)
      allow(drc).to receive(:left_hand).and_return(nil)
    end

    context 'with nil description and both hands full' do
      it 'stows both hands' do
        allow(drc).to receive(:right_hand).and_return('sword')
        allow(drc).to receive(:left_hand).and_return('shield')
        expect(em).to receive(:stow_helper).twice
        em.stow_weapon
      end
    end

    context 'with nil description and empty hands' do
      it 'returns without stowing' do
        expect(em).not_to receive(:stow_helper)
        em.stow_weapon
      end
    end

    context 'when weapon has wield flag' do
      it 'sheathes the weapon' do
        expect(em).to receive(:stow_helper).with(
          'sheath my sword', 'sword',
          *described_class::SHEATH_SUCCESS_PATTERNS,
          *described_class::SHEATH_FAILURE_PATTERNS
        )
        em.stow_weapon('sword')
      end
    end

    context 'when weapon has worn flag' do
      it 'wears the weapon' do
        expect(em).to receive(:stow_helper).with(
          'wear my shield', 'shield',
          *Lich::DragonRealms::DRCI::WEAR_ITEM_SUCCESS_PATTERNS,
          *Lich::DragonRealms::DRCI::WEAR_ITEM_FAILURE_PATTERNS
        )
        em.stow_weapon('shield')
      end
    end

    context 'when weapon has tie_to' do
      it 'ties the weapon' do
        expect(em).to receive(:stow_helper).with(
          'tie my dagger to my belt', 'dagger',
          *Lich::DragonRealms::DRCI::TIE_ITEM_SUCCESS_PATTERNS,
          *Lich::DragonRealms::DRCI::TIE_ITEM_FAILURE_PATTERNS
        )
        em.stow_weapon('dagger')
      end
    end

    context 'when weapon has container' do
      it 'puts weapon in container' do
        expect(em).to receive(:stow_helper).with(
          'put my lockpick in my toolkit', 'lockpick',
          *Lich::DragonRealms::DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS,
          *Lich::DragonRealms::DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS
        )
        em.stow_weapon('lockpick')
      end
    end

    context 'when weapon has no special storage' do
      let(:gear) { [{ name: 'gem', is_worn: false, is_leather: false }] }

      it 'uses generic stow' do
        expect(em).to receive(:stow_helper).with(
          'stow my gem', 'gem',
          *Lich::DragonRealms::DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS,
          *Lich::DragonRealms::DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS
        )
        em.stow_weapon('gem')
      end
    end

    context 'when description does not match any item' do
      it 'returns without stowing' do
        expect(em).not_to receive(:stow_helper)
        em.stow_weapon('nonexistent')
      end
    end

    context 'when weapon needs unloading' do
      let(:gear) { [{ name: 'crossbow', is_worn: false, is_leather: false, wield: true, needs_unloading: true }] }

      it 'unloads before stowing' do
        expect(em).to receive(:unload_weapon).with('crossbow').ordered
        expect(em).to receive(:stow_helper).ordered
        em.stow_weapon('crossbow')
      end
    end
  end

  # ── turn_to_weapon? ─────────────────────────────────────────────

  describe '#turn_to_weapon?' do
    let(:em) { described_class.new(make_settings) }

    before { stub_game_methods(em) }

    context 'when old_noun equals new_noun' do
      it 'returns true without issuing a command' do
        expect(drc).not_to receive(:bput)
        expect(em.turn_to_weapon?('sword', 'sword')).to be true
      end
    end

    context 'when turn succeeds' do
      it 'returns true' do
        allow(drc).to receive(:bput).and_return('Your bastard sword shifts and reshapes before resolving itself into a longsword')
        expect(em.turn_to_weapon?('bastard sword', 'longsword')).to be true
      end
    end

    context 'when turn fails with Turn what' do
      it 'returns false' do
        allow(drc).to receive(:bput).and_return('Turn what?')
        expect(em.turn_to_weapon?('sword', 'dagger')).to be false
      end
    end

    context 'when turn fails with Which weapon' do
      it 'returns false' do
        allow(drc).to receive(:bput).and_return('Which weapon did you want to pull out')
        expect(em.turn_to_weapon?('sword', 'nonexistent')).to be false
      end
    end
  end

  # ── wield_weapon_offhand? ───────────────────────────────────────

  describe '#wield_weapon_offhand?' do
    let(:gear) { [{ name: 'dagger', is_worn: false, is_leather: false }] }
    let(:em) { described_class.new(make_settings(gear: gear)) }

    before do
      stub_game_methods(em)
      allow(drc).to receive(:right_hand).and_return(nil)
      allow(drc).to receive(:left_hand).and_return(nil)
    end

    context 'with nil description' do
      it 'returns nil' do
        expect(em.wield_weapon_offhand?(nil)).to be_nil
      end
    end

    context 'with empty description' do
      it 'returns nil' do
        expect(em.wield_weapon_offhand?('')).to be_nil
      end
    end

    context 'when description does not match any item' do
      it 'returns false with a message' do
        expect(Lich::Messaging).to receive(:msg).with("bold", /EquipmentManager: Failed to match a weapon/)
        expect(em.wield_weapon_offhand?('nonexistent')).to be false
      end
    end

    context 'when get_item? succeeds and weapon is in right hand' do
      it 'swaps to left hand and returns true' do
        allow(em).to receive(:get_item?).and_return(true)
        allow(drci).to receive(:in_right_hand?).and_return(true)
        allow(drc).to receive(:bput).and_return('You move a dagger to your left hand')
        expect(em.wield_weapon_offhand?('dagger')).to be true
      end
    end

    context 'when get_item? succeeds but swap fails (paralysis)' do
      it 'returns false' do
        allow(em).to receive(:get_item?).and_return(true)
        allow(drci).to receive(:in_right_hand?).and_return(true)
        allow(drc).to receive(:bput).and_return('Will alone cannot conquer the paralysis')
        expect(em.wield_weapon_offhand?('dagger')).to be false
      end
    end

    context 'when get_item? fails' do
      it 'returns false' do
        allow(em).to receive(:get_item?).and_return(false)
        expect(em.wield_weapon_offhand?('dagger')).to be false
      end
    end

    context 'deprecated alias wield_weapon_offhand' do
      it 'delegates to wield_weapon_offhand?' do
        allow(em).to receive(:get_item?).and_return(true)
        allow(drci).to receive(:in_right_hand?).and_return(true)
        allow(drc).to receive(:bput).and_return('You move a dagger to your left hand')
        expect(em.wield_weapon_offhand('dagger')).to be true
      end
    end
  end

  # ── wear_items ──────────────────────────────────────────────────

  describe '#wear_items' do
    let(:gear) { [{ name: 'gloves', is_worn: true, is_leather: true }, { name: 'shield', is_worn: true, is_leather: false }] }
    let(:em) { described_class.new(make_settings(gear: gear, sort_auto_head: false)) }

    before { stub_game_methods(em) }

    it 'calls wear_item? for each item in the list' do
      items_list = em.items
      items_list.each { |item| expect(em).to receive(:wear_item?).with(item) }
      em.wear_items(items_list)
    end

    context 'when sort_auto_head is true' do
      let(:em) { described_class.new(make_settings(gear: gear, sort_auto_head: true)) }

      it 'sends sort auto head command' do
        allow(em).to receive(:wear_item?)
        expect(drc).to receive(:bput).with('sort auto head', /^Your inventory is now arranged/)
        em.wear_items(em.items)
      end
    end

    context 'when sort_auto_head is false' do
      it 'does not send sort command' do
        allow(em).to receive(:wear_item?)
        expect(drc).not_to receive(:bput).with('sort auto head', anything)
        em.wear_items(em.items)
      end
    end
  end

  # ── empty_hands ─────────────────────────────────────────────────

  describe '#empty_hands' do
    let(:gear) { [{ name: 'sword', is_worn: false, is_leather: false, wield: true }] }
    let(:sets) { { 'standard' => ['sword'] } }
    let(:em) { described_class.new(make_settings(gear: gear, gear_sets: sets)) }

    before { stub_game_methods(em) }

    context 'when return_held_gear succeeds' do
      it 'does not call DRCI.stow_hands' do
        allow(em).to receive(:return_held_gear).and_return(true)
        expect(drci).not_to receive(:stow_hands)
        em.empty_hands
      end
    end

    context 'when return_held_gear returns nil (empty hands)' do
      it 'calls DRCI.stow_hands' do
        allow(em).to receive(:return_held_gear).and_return(nil)
        expect(drci).to receive(:stow_hands)
        em.empty_hands
      end
    end

    context 'when return_held_gear returns false (unknown items)' do
      it 'calls DRCI.stow_hands' do
        allow(em).to receive(:return_held_gear).and_return(false)
        expect(drci).to receive(:stow_hands)
        em.empty_hands
      end
    end
  end

  # ── Constants ───────────────────────────────────────────────────

  describe 'constants' do
    it 'defines SHEATH_SUCCESS_PATTERNS as frozen array' do
      expect(described_class::SHEATH_SUCCESS_PATTERNS).to be_frozen
      expect(described_class::SHEATH_SUCCESS_PATTERNS).to all(be_a(Regexp))
    end

    it 'defines SHEATH_FAILURE_PATTERNS as frozen array' do
      expect(described_class::SHEATH_FAILURE_PATTERNS).to be_frozen
      expect(described_class::SHEATH_FAILURE_PATTERNS).to all(be_a(Regexp))
    end

    it 'defines STOW_RECOVERY_PATTERNS as frozen array' do
      expect(described_class::STOW_RECOVERY_PATTERNS).to be_frozen
      expect(described_class::STOW_RECOVERY_PATTERNS).to all(be_a(Regexp))
    end

    it 'defines STOW_HELPER_MAX_RETRIES as 10' do
      expect(described_class::STOW_HELPER_MAX_RETRIES).to eq(10)
    end
  end
end
