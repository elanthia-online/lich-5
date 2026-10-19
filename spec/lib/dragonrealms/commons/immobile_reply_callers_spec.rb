# frozen_string_literal: true

require_relative '../../../spec_helper'

# The callers that list "You don't seem to be able to move to do that." in
# their DRC.bput patterns, driven through the real bput. Only the game I/O is
# stubbed: put queues the reply to each command, get? reads it back, and
# raises when no reply has arrived for two seconds, so a reply bput skips
# fails the example at once instead of waiting out the 15 s timeout.
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-items.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'equipmanager.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-arcana.rb')

RSpec.describe 'Callers that list the immobile reply' do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }
  let(:immobile) { "You don't seem to be able to move to do that." }
  let(:sent) { [] }

  # Answers each command with replies[command] (a line, an array of lines, or
  # a lambda returning either), falling back to replies[:default].
  def game(replies)
    buffer = []
    last_reply = Time.now
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:pause) { sleep(0.001) }
    allow(drc).to receive(:put) do |message|
      sent << message
      raise "#{message.inspect} sent #{sent.count(message)} times" if sent.count(message) > 20

      reply = replies.fetch(message) { replies.fetch(:default) }
      buffer.concat(Array(reply.respond_to?(:call) ? reply.call : reply))
      last_reply = Time.now
    end
    allow(drc).to receive(:get?) do
      raise 'bput skipped the reply and waited for another' if buffer.empty? && Time.now - last_reply > 2

      buffer.shift
    end
  end

  def messages
    Lich::Messaging.messages.map { |m| m[:message] }
  end

  before { Lich::Messaging.clear_messages! }

  describe 'DRCI' do
    before { game(default: immobile) }

    # [description, call, expected result]
    {
      'exists? (TAP)'                        => [-> { drci.exists?('gem') }, false],
      'wearing? (TAP)'                       => [-> { drci.wearing?('cloak') }, false],
      'wear_item_unsafe? (WEAR)'             => [-> { drci.wear_item_unsafe?('my cloak') }, false],
      'remove_item_unsafe? (REMOVE)'         => [-> { drci.remove_item_unsafe?('my cloak') }, false],
      'tie_item_result (TIE)'                => [-> { drci.tie_item_result('pouch', 'belt') }, :failed],
      'untie_item? (UNTIE)'                  => [-> { drci.untie_item?('pouch', 'belt') }, false],
      'stow_item_unsafe? (STOW)'             => [-> { drci.stow_item_unsafe?('my gem') }, false],
      'stow_hand (STOW)'                     => [-> { drci.stow_hand('right') }, false],
      'put_away_item_unsafe? (PUT_AWAY)'     => [-> { drci.put_away_item_unsafe?('my gem', 'my pouch') }, false],
      'open_container? (OPEN_CONTAINER)'     => [-> { drci.open_container?('my pouch') }, false],
      'close_container? (CLOSE_CONTAINER)'   => [-> { drci.close_container?('my pouch') }, false],
      'rummage_container (RUMMAGE)'          => [-> { drci.rummage_container('my pouch') }, nil],
      'execute_dispose_command (DROP_TRASH)' => [-> { drci.execute_dispose_command('drop my rock', 'rock', 3) }, :failure]
    }.each do |description, (call, expected)|
      it "#{description} fails on the first reply, with one command and no timeout" do
        expect(instance_exec(&call)).to eq(expected)
        expect(sent.size).to eq(1)
        expect(messages.grep(/No match was found/)).to be_empty
      end
    end

    it 'get_item_unsafe returns false on the first reply, with one command and no timeout' do
      allow(drci).to receive(:in_hands?).and_return(false)
      allow(drci).to receive(:sleep)
      expect(drci.get_item_unsafe('gem', 'pouch')).to be false
      expect(sent).to eq(['get gem from pouch'])
      expect(messages.grep(/No match was found/)).to be_empty
    end

    it 'lower_item? returns false on the first reply' do
      allow(drci).to receive(:in_hands?).and_return(true)
      allow(drci).to receive(:in_left_hand?).and_return(true)
      expect(drci.lower_item?('sword')).to be false
      expect(sent).to eq(['lower ground left'])
    end

    it 'rummage_container reports that it could not rummage' do
      drci.rummage_container('my pouch')
      expect(messages).to include("DRCI: Unable to rummage 'my pouch'.")
    end

    it 'dispose_trash tries the drop, reports the failure and returns false' do
      allow(drci).to receive(:get_item_if_not_held?).and_return(true)
      allow(Room).to receive(:current).and_return(OpenStruct.new(tags: []))
      allow(DRRoom).to receive(:room_objs).and_return([])
      expect(drci.dispose_trash('rock')).to be false
      expect(sent).to eq(['drop my rock'])
      expect(messages).to include("DRCI: Failed to dispose of 'rock'.")
    end

    it 'dispose_trash goes on from a worn trashcan to the room bin and the drop' do
      allow(drci).to receive(:get_item_if_not_held?).and_return(true)
      allow(drci).to receive(:trash_storage).and_return(%w[bin])
      allow(Room).to receive(:current).and_return(OpenStruct.new(tags: []))
      allow(DRRoom).to receive(:room_objs).and_return(['waste bin'])
      allow(drc).to receive(:get_noun) { |long_name| long_name.split.last }
      expect(drci.dispose_trash('rock', 'shroud', 'tap')).to be false
      expect(sent).to eq(['put my rock in my shroud', 'put my rock in waste bin', 'drop my rock'])
      expect(messages).to include("DRCI: Failed to dispose of 'rock'.")
    end
  end

  describe 'EquipmentManager' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { Lich::DragonRealms::EquipmentManager.new(settings) }

    before do
      allow(em).to receive(:waitrt?)
      allow(em).to receive(:pause)
    end

    describe '#stow_helper' do
      let(:put_away) { [*Lich::DragonRealms::DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS] }
      let(:failures) { Lich::DragonRealms::DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS }

      it 'pauses and tries again, then succeeds once the hold ends' do
        game('stow my sword' => -> { sent.size == 1 ? immobile : 'You put your sword in your pack.' })
        expect(em.send(:stow_helper, 'stow my sword', 'sword', *put_away, failure_patterns: failures)).to be true
        expect(sent).to eq(['stow my sword'] * 2)
        expect(em).to have_received(:pause).with(1).once
      end

      it 'gives up after its retry limit while the hold lasts' do
        game('stow my sword' => immobile)
        expect(em.send(:stow_helper, 'stow my sword', 'sword', *put_away, failure_patterns: failures)).to be false
        expect(sent.size).to eq(Lich::DragonRealms::EquipmentManager::STOW_HELPER_MAX_RETRIES)
        expect(messages.grep(/stow_helper exceeded max retries/).size).to eq(1)
        expect(messages.grep(/got no response/)).to be_empty
      end
    end

    describe '#remove_item' do
      let(:item) { double('item', short_name: 'helm') }

      before do
        allow(drc).to receive(:left_hand).and_return('sword')
        allow(drc).to receive(:right_hand).and_return('shield')
      end

      it 'returns false without lowering what is held' do
        game('remove my helm' => immobile, default: 'You lower it.')
        expect(em.remove_item(item)).to be false
        expect(sent).to eq(['remove my helm'])
        expect(messages).to include('EquipmentManager: Unable to move to remove helm. Try again later.')
      end

      # The first REMOVE needs both hands free, so both items are lowered;
      # then a hold starts, and the retried REMOVE and the pick-ups draw the
      # immobile reply until it ends.
      context 'when a hold starts after the hands are lowered' do
        let(:hands) { { 'left' => 'longbow', 'right' => 'shield' } }
        let(:ground) { [] }
        let(:attempts) { Lich::DragonRealms::EquipmentManager::LOWERED_ITEM_PICKUP_ATTEMPTS }

        before do
          allow(drc).to receive(:left_hand) { hands['left'] }
          allow(drc).to receive(:right_hand) { hands['right'] }
        end

        def lower(hand)
          lambda do
            ground << hands[hand]
            hands[hand] = nil
            "You lower the #{ground.last}."
          end
        end

        # Replies `immobile` to the first hold[:gets] GETs, then `free_reply` (a
        # pick-up when nil).
        def pick_up(noun, hold, free_reply = nil)
          lambda do
            next immobile if (hold[:gets] -= 1) >= 0
            next free_reply if free_reply

            ground.delete(noun)
            hands[hands['right'] ? 'left' : 'right'] = noun
            "You pick up the #{noun}."
          end
        end

        def remove_game(gets_held:, free_reply: nil)
          hold = { gets: gets_held }
          game('remove my helm'     => -> { sent.size == 1 ? "You'll need both hands free to remove that." : immobile },
               'lower ground left'  => lower('left'),
               'lower ground right' => lower('right'),
               'get my shield'      => pick_up('shield', hold, free_reply),
               'get my longbow'     => pick_up('longbow', hold, free_reply),
               'swap'               => 'Will alone cannot conquer the paralysis.')
        end

        it 'keeps trying the pick-ups until the hold ends' do
          remove_game(gets_held: 3)
          em.remove_item(item)
          expect(hands).to eq('left' => 'longbow', 'right' => 'shield')
          expect(ground).to be_empty
          expect(sent).to eq(['remove my helm', 'lower ground left', 'lower ground right', 'remove my helm'] +
                             ['get my shield'] * 4 + ['get my longbow'])
          expect(em).to have_received(:pause).with(1).exactly(3).times
          expect(messages.grep(/Unable to pick up/)).to be_empty
        end

        it 'gives up and reports each item after its attempts while the hold lasts' do
          remove_game(gets_held: 1000)
          em.remove_item(item)
          expect(ground).to eq(%w[longbow shield])
          expect(sent.count('get my shield')).to eq(attempts)
          expect(sent.count('get my longbow')).to eq(attempts)
          expect(messages).to include('EquipmentManager: Unable to pick up shield after removing helm',
                                      'EquipmentManager: Unable to pick up longbow after removing helm')
          expect(messages.grep(/No match was found/)).to be_empty
        end

        it 'picks up only what was lowered when a hold stops the lowering partway' do
          hold = { gets: 0 }
          game('remove my helm'     => "You'll need both hands free to remove that.",
               'lower ground left'  => lower('left'),
               'lower ground right' => immobile,
               'get my longbow'     => pick_up('longbow', hold))
          em.remove_item(item)
          expect(sent).to eq(['remove my helm', 'lower ground left', 'lower ground right', 'get my longbow'])
          expect(hands).to eq('left' => 'longbow', 'right' => 'shield')
          expect(messages).to include('EquipmentManager: Unable to empty your hands to remove helm')
        end

        # The shield's GETs run out during the hold, which then ends during
        # the longbow's.
        it 'tries an item given up on once more after a later item is picked up' do
          remove_game(gets_held: attempts + 3)
          em.remove_item(item)
          expect(ground).to be_empty
          expect(sent.drop(4)).to eq(['get my shield'] * attempts + ['get my longbow'] * 4 + ['get my shield', 'swap'])
          expect(messages.grep(/Unable to pick up/)).to be_empty
        end

        it 'reports an item whose extra GET fails too' do
          hold = { gets: 3 }
          shield_gets = 0
          game('remove my helm'     => -> { sent.size == 1 ? "You'll need both hands free to remove that." : immobile },
               'lower ground left'  => lower('left'),
               'lower ground right' => lower('right'),
               'get my shield'      => -> { (shield_gets += 1) <= attempts ? immobile : 'What were you referring to?' },
               'get my longbow'     => pick_up('longbow', hold),
               'swap'               => 'Will alone cannot conquer the paralysis.')
          em.remove_item(item)
          expect(sent.count('get my shield')).to eq(attempts + 1)
          expect(ground).to eq(['shield'])
          expect(messages).to include('EquipmentManager: Unable to pick up shield after removing helm')
          expect(messages.grep(/Unable to pick up longbow/)).to be_empty
        end

        # The lowered items' names collide: a held-check by name for the
        # crossbow matches "crossbow bolts" once the bolts are picked up.
        it 'picks up both items when one name contains the other noun' do
          hands.replace('left' => 'crossbow', 'right' => 'crossbow bolts')
          game('remove my helm'        => -> { sent.size == 1 ? "You'll need both hands free to remove that." : 'You remove a helm.' },
               'stow my helm'          => 'You put your helm in your pack.',
               'lower ground left'     => lower('left'),
               'lower ground right'    => lower('right'),
               'get my crossbow bolts' => pick_up('crossbow bolts', { gets: 0 }),
               'get my crossbow'       => pick_up('crossbow', { gets: 0 }))
          helm = double('item', short_name: 'helm', transforms_to: nil, tie_to: nil, wield: nil, container: nil)
          em.remove_item(helm)
          expect(ground).to be_empty
          expect(sent.last(2)).to eq(['get my crossbow bolts', 'get my crossbow'])
          expect(hands).to eq('left' => 'crossbow', 'right' => 'crossbow bolts')
        end

        it 'does not retry a pick-up that fails for another reason' do
          remove_game(gets_held: 0, free_reply: 'What were you referring to?')
          em.remove_item(item)
          expect(sent.count('get my shield')).to eq(1)
          expect(sent.count('get my longbow')).to eq(1)
          expect(em).not_to have_received(:pause).with(1)
          expect(messages).to include('EquipmentManager: Unable to pick up shield after removing helm')
        end
      end
    end

    describe '#unload_weapon' do
      let(:hands) { { 'left' => 'longbow', 'right' => 'shield' } }

      before do
        allow(drc).to receive(:left_hand) { hands['left'] }
        allow(drc).to receive(:right_hand) { hands['right'] }
      end

      it 'picks the lowered weapon up again once a hold that started after the lowering ends' do
        gets_held = 3
        lower = lambda do
          hands['left'] = nil
          'You lower the longbow.'
        end
        pick_up = lambda do
          next immobile if (gets_held -= 1) >= 0

          hands['left'] = 'longbow'
          'You pick up the longbow.'
        end
        game('unload my longbow' => 'Your arrow falls from your longbow to your feet.',
             'lower ground left' => lower,
             'stow my arrow'     => immobile,
             'get my longbow'    => pick_up)
        em.unload_weapon('longbow')
        expect(hands['left']).to eq('longbow')
        expect(sent).to eq(['unload my longbow', 'lower ground left', 'stow my arrow'] + ['get my longbow'] * 4)
        expect(messages.grep(/Unable to pick longbow back up/)).to be_empty
      end

      # The weapon's noun is part of the name in the other hand, so a
      # held-check by name would match it and skip the GET.
      it 'sends the GET even when the other hand holds an item whose name contains the weapon noun' do
        hands.replace('left' => 'crossbow', 'right' => 'crossbow bolts')
        game('unload my crossbow' => 'Your bolt falls from your crossbow to your feet.',
             'lower ground left'  => -> { hands['left'] = nil; 'You lower the crossbow.' },
             'stow my bolt'       => 'You put your bolt in your quiver.',
             'get my crossbow'    => -> { hands['left'] = 'crossbow'; 'You pick up the crossbow.' })
        em.unload_weapon('crossbow')
        expect(sent).to eq(['unload my crossbow', 'lower ground left', 'stow my bolt', 'get my crossbow'])
        expect(hands).to eq('left' => 'crossbow', 'right' => 'crossbow bolts')
      end

      # The other hand's "crossbow bolts" matches the noun before and after
      # the GETs; it must not count as picking the crossbow up.
      it 'reports the weapon left on the ground when the hold outlasts the GETs and the other hand holds a name containing its noun' do
        hands.replace('left' => 'crossbow', 'right' => 'crossbow bolts')
        game('unload my crossbow' => 'Your bolt falls from your crossbow to your feet.',
             'lower ground left'  => -> { hands['left'] = nil; 'You lower the crossbow.' },
             'stow my bolt'       => immobile,
             'get my crossbow'    => immobile)
        em.unload_weapon('crossbow')
        expect(sent.count('get my crossbow')).to eq(Lich::DragonRealms::EquipmentManager::LOWERED_ITEM_PICKUP_ATTEMPTS)
        expect(hands).to eq('left' => nil, 'right' => 'crossbow bolts')
        expect(messages).to include('EquipmentManager: Unable to pick crossbow back up after unloading')
      end

      # A stray line that matches a GET success pattern answers the GET, and
      # the other hand's "crossbow bolts" contains the weapon's noun. Neither
      # may count as picking the crossbow up.
      it 'reports the weapon left on the ground when a stray success-like line answers the GET' do
        hands.replace('left' => 'crossbow', 'right' => 'crossbow bolts')
        game('unload my crossbow' => 'Your bolt falls from your crossbow to your feet.',
             'lower ground left'  => -> { hands['left'] = nil; 'You lower the crossbow.' },
             'stow my bolt'       => 'You put your bolt in your quiver.',
             'get my crossbow'    => ['You get down on one knee.', immobile])
        em.unload_weapon('crossbow')
        expect(hands).to eq('left' => nil, 'right' => 'crossbow bolts')
        expect(messages).to include('EquipmentManager: Unable to pick crossbow back up after unloading')
      end

      # A stray failure-like line answers the GET, but the hand gains the
      # weapon all the same.
      it 'counts the weapon as picked up when its hand gains it, even on a failure-like reply' do
        hands.replace('left' => 'crossbow', 'right' => 'crossbow bolts')
        game('unload my crossbow' => 'Your bolt falls from your crossbow to your feet.',
             'lower ground left'  => -> { hands['left'] = nil; 'You lower the crossbow.' },
             'stow my bolt'       => 'You put your bolt in your quiver.',
             'get my crossbow'    => -> { hands['left'] = 'crossbow'; 'What were you referring to?' })
        em.unload_weapon('crossbow')
        expect(messages.grep(/Unable to pick crossbow back up/)).to be_empty
      end
    end

    describe '#get_item_helper' do
      let(:item) do
        double('item', short_regex: /\bsword/i, name: 'sword', short_name: 'sword',
                       transform_verb: 'twist', transform_text: 'The sword twists', worn: false)
      end

      before do
        allow(drc).to receive(:left_hand).and_return(nil)
        allow(drc).to receive(:right_hand).and_return(nil)
        allow(em).to receive(:item_noun_in_hands?).and_return(false)
      end

      { worn: 'remove my sword', tied: 'untie my sword', stowed: 'get my sword' }.each do |type, command|
        it "returns false for a #{type} item on the first reply" do
          game(command => immobile)
          expect(em.send(:get_item_helper, item, type)).to be false
          expect(sent).to eq([command])
          expect(messages.grep(/No response from game|No match was found/)).to be_empty
        end
      end
    end
  end

  describe 'DRCA.check_discern' do
    let(:drca) { Lich::DragonRealms::DRCA }
    let(:settings) do
      OpenStruct.new(check_discern_timer_in_hours: 24, prep_scaling_factor: 1, cambrinth_num_charges: 0,
                     cambrinth_items: [{ 'name' => 'armband', 'cap' => 10 }], cambrinth_distribute_charges: false)
    end
    let(:stale) { Time.now - (25 * 60 * 60) }

    before do
      allow(drc).to receive(:retreat)
      allow(drca).to receive(:waitrt?)
      UserVars.discerns = { 'bs' => { 'time_stamp' => stale, 'mana' => 7, 'cambrinth' => [[3]] } }
    end

    it 'casts at the minimum when held, and discerns again on the next cast' do
      game('discern bs' => -> { sent.size == 1 ? immobile : 'The spell requires at minimum 5 mana streams and you think you can reinforce it with 10 more.' })
      data = drca.check_discern({ 'abbrev' => 'bs' }, settings)
      expect(data).to include('mana' => 1, 'cambrinth' => nil)
      expect(UserVars.discerns['bs']['time_stamp']).to eq(stale)

      data = drca.check_discern({ 'abbrev' => 'bs' }, settings)
      expect(sent).to eq(['discern bs'] * 2)
      expect(data['mana']).to eq(15)
      expect(UserVars.discerns['bs']['time_stamp']).to be > stale
    end

    it 'caches a reply that the spell cannot be cast' do
      game('discern bs' => 'You have no idea how to cast that spell.')
      data = drca.check_discern({ 'abbrev' => 'bs' }, settings)
      expect(data).to include('mana' => 1, 'cambrinth' => nil)
      expect(UserVars.discerns['bs']['time_stamp']).to be > stale
    end

    it 'does not cache when discern gets no reply' do
      game('discern bs' => [])
      # Still the real bput, with its 15 s timeout cut short.
      allow(drc).to receive(:bput).and_wrap_original do |bput, message, *patterns|
        bput.call(message, { 'timeout' => 0.2 }, *patterns)
      end
      data = drca.check_discern({ 'abbrev' => 'bs' }, settings)
      expect(sent).to eq(['discern bs'])
      expect(messages.grep(/No match was found/)).not_to be_empty
      expect(data['mana']).to eq(7)
      expect(UserVars.discerns['bs']['time_stamp']).to eq(stale)
    end
  end
end
