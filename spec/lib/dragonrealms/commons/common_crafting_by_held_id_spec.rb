# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'common/gameobj'
require 'dragonrealms/commons/common'
require 'dragonrealms/commons/common-items'
require 'dragonrealms/commons/common-travel'
require 'dragonrealms/commons/common-crafting'

DRCC = Lich::DragonRealms::DRCC unless defined?(DRCC)

# DRCC.get_crafting_item, stow_crafting_item and check_consumables name the
# held item and the worn container by id when the real DRCI.held_id and
# DRCI.worn_ref resolve them, and send today's "my <name>" strings when they
# don't. Everything below runs the real DRCI readers over the real GameObj
# hands and worn list, set as the XML parser sets them; an empty hand is the
# parser's placeholder (id nil, noun nil, name 'Empty'). Item ids and names
# are from Barrask's 2026-11-04 logs (the taskmaster incident), as in
# common_items_held_ids_spec.rb; the bucket and pins ids are illustrative.
RSpec.describe Lich::DragonRealms::DRCC do
  let(:gameobj) { Lich::Common::GameObj }
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }
  let(:drct) { Lich::DragonRealms::DRCT }

  let(:leather) { ['2222485', 'leather', 'rat-pelt leather'] }
  let(:other_leather) { ['2222486', 'leather', 'rat-pelt leather'] }
  let(:cloth) { ['2227674', 'cloth', 'burlap cloth'] }
  let(:sinuous_leathers) { ['758572', 'leathers', 'sinuous leathers'] }
  let(:pack) { ['758573', 'pack', "scuffed traveler's pack"] }
  let(:duffel) { ['758689', 'bag', 'heavy silk duffel bag'] }
  let(:bucket) { ['758700', 'bucket', 'portable silversteel bucket'] }
  let(:pins) { ['5550001', 'pins', 'straight iron pins'] }
  let(:old_pins) { ['5550002', 'pins', 'straight iron pins'] }

  # Commands sent, in order: bput, fput, walks, orders and disposes.
  let(:sent) { [] }
  # Game lines per command, in order; a command with none left is a bug.
  let(:replies) { Hash.new { |_hash, command| raise "unexpected command #{command.inspect}" } }
  # Hand changes the game makes when it answers a command, or sends a line.
  let(:effects) { {} }
  let(:line_effects) { {} }

  def hands(right: nil, left: nil)
    gameobj.new_right_hand(*(right || [nil, nil, 'Empty']))
    gameobj.new_left_hand(*(left || [nil, nil, 'Empty']))
  end

  def worn(*items)
    gameobj.clear_inv
    items.each { |id, noun, name| gameobj.new_inv(id, noun, name) }
  end

  # The game answers +command+ with +lines+, one per send; a block runs at
  # the first send (e.g. the item leaves the hand), also when the reply is
  # '' (a bput timeout whose command still worked).
  def game(command, *lines, &effect)
    replies[command] = lines
    effects[command] = effect if effect
  end

  # The game changes the hands when it sends +line+, whatever the command.
  def on_line(line, &effect)
    line_effects[line] = effect
  end

  # An exit that escapes an example ends rspec early with status 0.
  around(:each) do |example|
    example.run
  rescue SystemExit
    raise 'DRCC stopped the script where the example expected it to continue'
  end

  before(:each) do
    gameobj.clear_inv
    hands
    # Same contract as the real DRC.bput: String patterns become /pattern/i,
    # the matched text is returned, '' on a timeout. A non-empty line that no
    # pattern matches raises: the real bput would wait out its 15 s timeout.
    allow(drc).to receive(:bput) do |command, *patterns|
      sent << command
      line = replies[command].shift.to_s
      effects.delete(command)&.call
      line_effects[line]&.call
      match = patterns.flatten.lazy.map { |p| line.match(p.is_a?(Regexp) ? p : /#{p}/i) }.find(&:itself)
      raise "real bput would wait 15 s: #{line.inspect} matches none of #{patterns.flatten.inspect}" if match.nil? && !line.empty?

      match ? match.to_a.first : ''
    end
    allow(described_class).to receive(:fput) { |command| sent << command }
    allow(described_class).to receive(:waitrt?)
    allow(described_class).to receive(:pause)
    allow(drc).to receive(:beep)
    allow(drc).to receive(:wait_for_script_to_complete)
    allow(drct).to receive(:walk_to) do |room|
      sent << "walk #{room}"
      true
    end
    allow(Room).to receive(:current) { OpenStruct.new(id: 8775) }
    allow(Lich::Messaging).to receive(:msg)
  end

  after(:each) do
    gameobj.clear_inv
    hands
  end

  describe '.stow_crafting_item' do
    # The incident: the rat-pelt leather is in the left hand, the worn
    # "sinuous leathers" share the "leather" prefix, and "put my leather in
    # my bucket" got "Perhaps you should be holding that first."
    context 'with the rat-pelt leather held and the sinuous leathers worn' do
      before(:each) do
        hands(right: cloth, left: leather)
        worn(sinuous_leathers, pack, bucket)
      end

      it 'puts the held leather in the worn bucket by their ids' do
        game('put #2222485 in #758700', 'You put your leather in your portable silversteel bucket.') { hands(right: cloth) }
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(true)
        expect(sent).to eq(['put #2222485 in #758700'])
      end

      it 'matches the noun ignoring case' do
        game('put #2222485 in #758700', 'You put your leather in your portable silversteel bucket.')
        expect(described_class.stow_crafting_item('Leather', 'Bucket', nil)).to be(true)
        expect(sent).to eq(['put #2222485 in #758700'])
      end

      it 'returns false and names the tool when the PUT by id still leaves it in hand' do
        game('put #2222485 in #758700', 'Perhaps you should be holding that first.')
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(false)
        expect(Lich::Messaging).to have_received(:msg)
          .with('bold', 'DRCC: Could not put leather in bucket. It is still in your hands.').once
      end

      it 'checks a PUT that timed out by id: true once the leather left the hand' do
        # The PUT landed, but its reply came after bput gave up.
        game('put #2222485 in #758700', '') { hands(right: cloth) }
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(true)
      end

      it 'checks a PUT that timed out by id: false while the leather is held' do
        allow(drci).to receive(:in_hands?).and_call_original
        game('put #2222485 in #758700', '')
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(false)
        expect(drci).to have_received(:in_hands?).with('#2222485')
      end

      # The same reply on the parent read the hands by name: a held "leather
      # backpack" counted as the leather. By id, only the leather counts.
      it 'checks a PUT that timed out by id: true when only another leather item is left' do
        game('put #2222485 in #758700', '') { hands(right: ['3', 'backpack', 'leather backpack']) }
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(true)
      end

      it 'falls back to STOW by id when the bucket is full' do
        game('put #2222485 in #758700', "There isn't any more room in the bucket for that.")
        game('stow #2222485', 'You put your leather in your scuffed traveler\'s pack.') { hands(right: cloth) }
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(true)
        expect(sent).to eq(['put #2222485 in #758700', 'stow #2222485'])
      end

      it 'returns false when the bucket is full and the STOW by id is refused, the leather still held' do
        game('put #2222485 in #758700', "There isn't any more room in the bucket for that.")
        game('stow #2222485', "There isn't any more room in the pack for that.")
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(false)
        expect(Lich::Messaging).to have_received(:msg)
          .with('bold', 'DRCC: bucket would not take leather, and stowing it failed too. It is still in your hands.').once
      end

      it 'sends the other-bag PUT with the id but keeps "my other <bag>"' do
        game('put #2222485 in #758700', "You can't put that there.")
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(false)
        expect(sent).to eq(['put #2222485 in #758700', 'put #2222485 in my other bucket'])
      end

      ['#758700', 758_700].each do |bag|
        it "sends no \"my other\" PUT for a bag given as #{bag.inspect}: false while the leather is held" do
          game('put #2222485 in #758700', "You can't put that there.")
          expect(described_class.stow_crafting_item('leather', bag, nil)).to be(false)
          expect(sent).to eq(['put #2222485 in #758700'])
          expect(Lich::Messaging).to have_received(:msg)
            .with('bold', "DRCC: #{bag} would not take leather. It is still in your hands.").once
        end
      end

      it 'ties a belt-listed tool by name first, as before, and sends no PUT when the tie works' do
        belt = { 'name' => 'toolbelt', 'items' => ['leather'] }
        game('tie my leather to my toolbelt', 'You attach the leather to your toolbelt.') { hands(right: cloth) }
        expect(described_class.stow_crafting_item('leather', 'bucket', belt)).to be(true)
        expect(sent).to eq(['tie my leather to my toolbelt'])
      end

      it 'puts the tool away by id after the belt tie by name fails' do
        belt = { 'name' => 'toolbelt', 'items' => ['leather'] }
        game('tie my leather to my toolbelt', "There's no more free ties on the belt.")
        game('put #2222485 in #758700', 'You put your leather in your portable silversteel bucket.')
        expect(described_class.stow_crafting_item('leather', 'bucket', belt)).to be(true)
        expect(sent).to eq(['tie my leather to my toolbelt', 'put #2222485 in #758700'])
      end
    end

    # Ambiguity falls back to exactly today's command string.
    context 'when the name or the bag does not resolve to one item' do
      before(:each) { worn(sinuous_leathers, pack, bucket) }

      it 'sends "put my leather in ..." when both hands hold a leather' do
        hands(right: other_leather, left: leather)
        game('put my leather in #758700', 'You put your leather in your portable silversteel bucket.')
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(true)
        expect(sent).to eq(['put my leather in #758700'])
      end

      it 'sends "put my tongs in my backpack" with empty hands and no worn backpack' do
        game('put my tongs in my backpack', 'What were you referring to?')
        expect(described_class.stow_crafting_item('tongs', 'backpack', nil)).to be(true)
        expect(sent).to eq(['put my tongs in my backpack'])
      end

      it 'never takes the worn "leathers" for "leather" (noun must be equal)' do
        hands(right: cloth)
        game('put my leather in #758700', 'Perhaps you should be holding that first.')
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(true)
        expect(sent).to eq(['put my leather in #758700'])
      end

      %w[second other].each do |word|
        it "keeps a name starting with #{word.inspect} as a name" do
          hands(left: leather)
          game("put my #{word} leather in #758700", 'You put your leather in your portable silversteel bucket.')
          expect(described_class.stow_crafting_item("#{word} leather", 'bucket', nil)).to be(true)
          expect(sent).to eq(["put my #{word} leather in #758700"])
        end
      end

      it 'sends exactly today\'s string when both the leather and the bag are ambiguous' do
        worn(duffel, ['758690', 'bag', 'leather bag'])
        hands(right: other_leather, left: leather)
        game('put my leather in my bag', 'You put your leather in your heavy silk duffel bag.')
        expect(described_class.stow_crafting_item('leather', 'bag', nil)).to be(true)
        expect(sent).to eq(['put my leather in my bag'])
      end

      it 'sends "my bag" when two worn items are bags' do
        worn(duffel, ['758690', 'bag', 'leather bag'])
        hands(left: leather)
        game('put #2222485 in my bag', 'You put your leather in your heavy silk duffel bag.')
        expect(described_class.stow_crafting_item('leather', 'bag', nil)).to be(true)
        expect(sent).to eq(['put #2222485 in my bag'])
      end

      it 'sends "my pelt pack" when the only worn pack is a "rat-pelt pack" (whole words)' do
        worn(['758691', 'pack', 'rat-pelt pack'])
        hands(left: leather)
        game('put #2222485 in my pelt pack', 'You put your leather in your rat-pelt pack.')
        expect(described_class.stow_crafting_item('leather', 'pelt pack', nil)).to be(true)
        expect(sent).to eq(['put #2222485 in my pelt pack'])
      end

      it 'sends "my bucket" when the bucket is held, not worn' do
        worn(pack)
        hands(right: bucket, left: leather)
        game('put #2222485 in my bucket', 'You put your leather in your portable silversteel bucket.')
        expect(described_class.stow_crafting_item('leather', 'bucket', nil)).to be(true)
        expect(sent).to eq(['put #2222485 in my bucket'])
      end

      it 'sends today\'s string when nothing is worn at all (GameObj.inv nil)' do
        gameobj.clear_inv
        expect(gameobj.inv).to be_nil
        game('put my tongs in my backpack', 'You put your tongs in your backpack.')
        expect(described_class.stow_crafting_item('tongs', 'backpack', nil)).to be(true)
      end
    end

    # The shortened DRC.right_hand name ("heavy bag") resolves to the held
    # "heavy silk duffel bag", the sew.lic / forge.lic / craft.lic pattern.
    it 'resolves a shortened hand name to the held item' do
      hands(right: duffel)
      worn(pack)
      game('put #758689 in #758573', "You put your bag in your scuffed traveler's pack.")
      expect(described_class.stow_crafting_item('heavy bag', 'pack', nil)).to be(true)
      expect(sent).to eq(['put #758689 in #758573'])
    end

    context 'with a "#<id>" or Integer name' do
      let(:belt) { { 'name' => 'toolbelt', 'items' => ['leather', '2222485'] } }

      before(:each) do
        hands(left: leather)
        worn(bucket)
      end

      ['#2222485', 2_222_485].each do |name|
        it "skips the belt and puts #{name.inspect} away by id" do
          game('put #2222485 in #758700', 'You put your leather in your portable silversteel bucket.')
          expect(described_class.stow_crafting_item(name, 'bucket', belt)).to be(true)
          expect(sent).to eq(['put #2222485 in #758700'])
        end
      end

      it 'sends "#<id>", never "my #<id>", for an id that is not held' do
        game('put #999 in #758700', 'What were you referring to?')
        expect(described_class.stow_crafting_item(999, 'bucket', belt)).to be(true)
        expect(sent).to eq(['put #999 in #758700'])
      end

      [' #999', "#999 \n"].each do |name|
        it "strips #{name.inspect} to the id, never \"my  #999\", and skips the belt" do
          game('put #999 in #758700', 'What were you referring to?')
          expect(described_class.stow_crafting_item(name, 'bucket', belt)).to be(true)
          expect(sent).to eq(['put #999 in #758700'])
        end
      end

      it 'puts a held " #2222485" away by id' do
        game('put #2222485 in #758700', 'You put your leather in your portable silversteel bucket.') { hands }
        expect(described_class.stow_crafting_item(' #2222485 ', 'bucket', belt)).to be(true)
        expect(sent).to eq(['put #2222485 in #758700'])
      end

      it 'checks the hands by id after a STOW fallback fails' do
        game('put #2222485 in #758700', "There isn't any more room in the bucket for that.")
        game('stow #2222485', "There isn't any more room in the pack for that.")
        expect(described_class.stow_crafting_item('#2222485', 'bucket', nil)).to be(false)
        expect(sent).to eq(['put #2222485 in #758700', 'stow #2222485'])
      end
    end

    it 'never sends "my #", held or not, String or Integer' do
      hands(left: leather)
      worn(bucket)
      {
        'leather'  => 'put #2222485 in #758700',
        '#2222485' => 'put #2222485 in #758700',
        2_222_485  => 'put #2222485 in #758700',
        '#1'       => 'put #1 in #758700',
        1          => 'put #1 in #758700'
      }.each do |name, command|
        game(command, 'What were you referring to?')
        described_class.stow_crafting_item(name, 'bucket', nil)
      end
      expect(sent).to eq(['put #2222485 in #758700'] * 3 + ['put #1 in #758700'] * 2)
    end
  end

  describe '.get_crafting_item' do
    before(:each) { worn(duffel, pack) }

    it 'names the worn bag by id in the GET' do
      game('get my mallet from #758689', 'You get a mallet from inside your heavy silk duffel bag.')
      expect(described_class.get_crafting_item('mallet', 'duffel bag', ['mallet'], nil)).to be(true)
      expect(sent).to eq(['get my mallet from #758689'])
    end

    it 'keeps "my <bag>" when two worn bags match' do
      worn(duffel, ['758690', 'bag', 'leather bag'])
      game('get my mallet from my bag', 'You get a mallet from inside your heavy silk duffel bag.')
      expect(described_class.get_crafting_item('mallet', 'bag', ['mallet'], nil)).to be(true)
      expect(sent).to eq(['get my mallet from my bag'])
    end

    it 'sends no from-clause when bag_items does not list the item, as before' do
      game('get my mallet', 'You get a mallet from inside your heavy silk duffel bag.')
      expect(described_class.get_crafting_item('mallet', 'duffel bag', ['hammer'], nil)).to be(true)
      expect(sent).to eq(['get my mallet'])
    end

    # held_id would name the leather already in hand, so a call fetching a
    # second one (stock to combine) would GET the held one; the GET keeps
    # the caller's name. What the game answers a GET of a held item is not
    # verified, so only the string is pinned.
    it 'does not swap the item for a held id: the GET keeps "my leather"' do
      hands(left: leather)
      game('get my leather from #758689', 'You get a rat-pelt leather from inside your heavy silk duffel bag.')
      expect(described_class.get_crafting_item('leather', 'duffel bag', ['leather'], nil)).to be(true)
      expect(sent).to eq(['get my leather from #758689'])
    end

    it 'unties a belt tool by name first, as before' do
      belt = { 'name' => 'toolbelt', 'items' => ['mallet'] }
      game('untie my mallet from my toolbelt', 'You remove a mallet from your toolbelt.')
      expect(described_class.get_crafting_item('mallet', 'duffel bag', ['mallet'], belt)).to be(true)
      expect(sent).to eq(['untie my mallet from my toolbelt'])
    end

    context 'with a "#<id>" or Integer name' do
      let(:belt) { { 'name' => 'toolbelt', 'items' => ['leather', '2222485'] } }

      ['#2222485', 2_222_485].each do |name|
        it "skips the belt and GETs #{name.inspect} by id" do
          game('get #2222485', 'You get a rat-pelt leather from inside your heavy silk duffel bag.')
          expect(described_class.get_crafting_item(name, 'duffel bag', ['leather'], belt)).to be(true)
          expect(sent).to eq(['get #2222485'])
        end
      end

      it 'strips " #2222485" to the id and skips the belt' do
        game('get #2222485', 'You get a rat-pelt leather from inside your heavy silk duffel bag.')
        expect(described_class.get_crafting_item(' #2222485', 'duffel bag', ['leather'], belt)).to be(true)
        expect(sent).to eq(['get #2222485'])
      end

      it 'adds the bag by id when bag_items lists the "#<id>"' do
        game('get #2222485 from #758689', 'You get a rat-pelt leather from inside your heavy silk duffel bag.')
        expect(described_class.get_crafting_item('#2222485', 'duffel bag', ['#2222485'], nil)).to be(true)
        expect(sent).to eq(['get #2222485 from #758689'])
      end

      it 'answers a timed-out GET by the id in hand: true when it arrived' do
        game('get #2222485', '') { hands(left: leather) }
        expect(described_class.get_crafting_item('#2222485', 'duffel bag', nil, nil)).to be(true)
      end

      it 'answers a timed-out GET by the id in hand: false when only another leather is held' do
        game('get #2222485', '') { hands(left: other_leather) }
        expect(described_class.get_crafting_item('#2222485', 'duffel bag', nil, nil)).to be(false)
      end

      it 'is true after "What were you referring to?" when the id is already in hand' do
        hands(right: leather)
        game('get #2222485', 'What were you referring to?')
        expect(described_class.get_crafting_item('#2222485', 'duffel bag', nil, nil, true)).to be(true)
      end

      it 'is a final failure after "What were you referring to?" when the id is not in hand' do
        hands(right: other_leather)
        game('get #2222485', 'What were you referring to?')
        expect(described_class.get_crafting_item('#2222485', 'duffel bag', nil, nil, true)).to be(false)
        expect(Lich::Messaging).to have_received(:msg).with('bold', 'DRCC: You seem to be missing: #2222485')
      end

      it 'is a final failure on "You need a free hand to do that."' do
        hands(right: cloth, left: other_leather)
        game('get #2222485', 'You need a free hand to do that.')
        expect(described_class.get_crafting_item(2_222_485, 'duffel bag', nil, nil, true)).to be(false)
        expect(sent).to eq(['get #2222485'])
      end

      # A GET by id can reach a tied item; the untie must name it by id too.
      ['#2222485', 2_222_485].each do |name|
        it "unties #{name.inspect} as \"untie #2222485\" after \"You should untie\"" do
          game('get #2222485', 'You should untie the leather first.')
          game('untie #2222485', 'You untie the leather.') { hands(left: leather) }
          expect(described_class.get_crafting_item(name, 'duffel bag', nil, nil, true)).to be(true)
          expect(sent).to eq(['get #2222485', 'untie #2222485'])
        end
      end

      it 'resends "untie #2222485" after the safe-room trip when wounds hinder it' do
        game('get #2222485', 'You should untie the leather first.')
        game('untie #2222485', 'Your wounds hinder your ability to do that.', 'You untie the leather.')
        expect(described_class.get_crafting_item('#2222485', 'duffel bag', nil, nil, true)).to be(true)
        expect(sent).to eq(['get #2222485', 'untie #2222485', 'walk 8775', 'untie #2222485'])
        expect(drc).to have_received(:wait_for_script_to_complete).with('safe-room', ['force']).once
      end

      it 'checks the id in hand when the untie by id finds nothing' do
        hands(right: other_leather)
        game('get #2222485', 'You should untie the leather first.')
        game('untie #2222485', 'Untie what?')
        expect(described_class.get_crafting_item('#2222485', 'duffel bag', nil, nil, true)).to be(false)
        expect(Lich::Messaging).to have_received(:msg)
          .with('bold', 'DRCC: Told to untie it, but found nothing to untie: #2222485')
      end
    end

    it 'still unties a name as "untie my <name>" after "You should untie"' do
      game('get my mallet', 'You should untie the mallet first.')
      game('untie my mallet', 'You untie the mallet.')
      expect(described_class.get_crafting_item('mallet', 'duffel bag', nil, nil, true)).to be(true)
      expect(sent).to eq(['get my mallet', 'untie my mallet'])
    end
  end

  describe '.check_consumables' do
    let(:got_pins) { 'You get some straight iron pins from inside your heavy silk duffel bag.' }
    let(:put_away) { 'You put your pins in your heavy silk duffel bag.' }
    let(:order_result) { 'takes some coins from you' }

    before(:each) do
      worn(duffel, pack)
      allow(drct).to receive(:order_item) do |room, number|
        sent << "order #{number} at #{room}"
        hands(right: pins) if order_result == 'takes some coins from you'
        order_result
      end
      allow(drct).to receive(:dispose) do |name|
        sent << "dispose #{name}"
        hands
      end
    end

    def check(room = 'tool-room')
      described_class.check_consumables('pins', room, 5, 'duffel bag', [], nil, 5)
    end

    it 'GETs from the worn bag by id, then counts and puts back the pins by id' do
      game('get my pins from #758689', got_pins) { hands(right: pins) }
      game('count #5550001', 'The straight iron pins has 12 uses remaining.')
      game('put #5550001 in #758689', put_away) { hands }
      expect(check).to be(true)
      expect(sent).to eq(['get my pins from #758689', 'count #5550001', 'put #5550001 in #758689', 'walk 8775'])
    end

    it 'disposes worn-out pins by id, then replaces them' do
      game('get my pins from #758689', got_pins, 'What were you referring to?') { hands(right: old_pins) }
      game('count #5550002', 'The straight iron pins has 2 uses remaining.')
      game('put #5550001 in #758689', put_away) { hands }
      expect(check).to be(true)
      expect(sent).to eq(['get my pins from #758689', 'count #5550002', 'dispose #5550002',
                          'get my pins from #758689', 'order 5 at tool-room', 'put #5550001 in #758689', 'walk 8775'])
    end

    it 'falls back to "count my pins" and dispose("pins") when two pins are held' do
      hands(left: old_pins)
      game('get my pins from #758689', got_pins, 'What were you referring to?') { hands(right: pins, left: old_pins) }
      game('count my pins', 'The straight iron pins has 2 uses remaining.')
      allow(drct).to receive(:dispose) do |name|
        sent << "dispose #{name}"
        hands(left: old_pins)
      end
      allow(drct).to receive(:order_item) do |room, number|
        sent << "order #{number} at #{room}"
        hands(right: pins, left: old_pins)
        order_result
      end
      game('put my pins in #758689', put_away)
      expect(check).to be(true)
      expect(sent).to eq(['get my pins from #758689', 'count my pins', 'dispose pins',
                          'get my pins from #758689', 'order 5 at tool-room', 'put my pins in #758689', 'walk 8775'])
    end

    it 'puts bought pins away by id after a not-found GET' do
      game('get my pins from #758689', 'I could not find what you were referring to.')
      game('put #5550001 in #758689', put_away) { hands }
      expect(check).to be(true)
      expect(sent).to eq(['get my pins from #758689', 'order 5 at tool-room', 'put #5550001 in #758689', 'walk 8775'])
    end

    it 'returns false without walking or ordering on "You need a free hand to pick that up."' do
      hands(right: cloth, left: leather)
      game('get my pins from #758689', 'You need a free hand to pick that up.')
      expect(check).to be(false)
      expect(sent).to eq(['get my pins from #758689'])
    end

    context 'when the order fails' do
      let(:order_result) { nil }

      it 'returns false with no PUT' do
        game('get my pins from #758689', 'What were you referring to?')
        expect(check).to be(false)
        expect(sent).to eq(['get my pins from #758689', 'order 5 at tool-room', 'walk 8775'])
      end
    end

    # The real DRCT.order_item on the same bput: both ORDERs go out, the
    # paying one puts the pins in the right hand, and the PUT goes by id.
    context 'through the real DRCT.order_item' do
      let(:paid) { 'The clerk takes some coins from you and hands you some straight iron pins.' }

      before(:each) do
        allow(drct).to receive(:order_item).and_call_original
        on_line(paid) { hands(right: pins) }
      end

      it 'puts the bought pins away by id after "takes some coins from you"' do
        game('get my pins from #758689', 'What were you referring to?')
        game('order 5', 'Just order it again', paid)
        game('put #5550001 in #758689', put_away)
        expect(check(19_073)).to be(true)
        expect(sent).to eq(['get my pins from #758689', 'walk 19073', 'order 5', 'order 5', 'put #5550001 in #758689', 'walk 8775'])
      end

      it 'returns false with no PUT when the paying ORDER finds the hands full' do
        hands(left: leather)
        game('get my pins from #758689', 'What were you referring to?')
        game('order 5', 'Just order it again', 'You realize your hands are full, and stop.')
        expect(check(19_073)).to be(false)
        expect(sent).to eq(['get my pins from #758689', 'walk 19073', 'order 5', 'order 5', 'walk 8775'])
      end
    end

    # held_id(nil) means "any held item"; a nil name must not count one.
    it 'counts "my " for a nil name, not whatever single item is held' do
      game('get my  from #758689', got_pins) { hands(right: pins) }
      game('count my ', 'The straight iron pins has 12 uses remaining.')
      expect(described_class.check_consumables(nil, 'tool-room', 5, 'duffel bag', [], nil, 5)).to be(true)
      expect(sent).to eq(['get my  from #758689', 'count my ', 'walk 8775'])
    end

    context 'with a "#<id>" or Integer name' do
      ['#5550002', 5_550_002].each do |name|
        it "returns false for #{name.inspect} without ordering when the GET finds no such item" do
          game('get #5550002 from #758689', 'What were you referring to?')
          expect(described_class.check_consumables(name, 'tool-room', 5, 'duffel bag', [], nil, 5)).to be(false)
          expect(sent).to eq(['get #5550002 from #758689'])
          expect(Lich::Messaging).to have_received(:msg)
            .with('bold', "DRCC: #5550002 is not in duffel bag, and an id can't be ordered. Not buying more.")
        end
      end

      it 'counts and puts back the id it got' do
        game('get #5550002 from #758689', got_pins) { hands(right: old_pins) }
        game('count #5550002', 'The straight iron pins has 12 uses remaining.')
        game('put #5550002 in #758689', put_away) { hands }
        expect(described_class.check_consumables(5_550_002, 'tool-room', 5, 'duffel bag', [], nil, 5)).to be(true)
        expect(sent).to eq(['get #5550002 from #758689', 'count #5550002', 'put #5550002 in #758689', 'walk 8775'])
      end

      # The disposed id names nothing any more: the replacement goes by the
      # first word of the hand name and the hand's noun ("straight iron pins",
      # noun pins, gives "straight pins"), and the bought pins are put away
      # by their own id.
      it 'disposes a worn-out id, then replaces it by its first word and noun and stows the new id' do
        game('get #5550002 from #758689', got_pins) { hands(right: old_pins) }
        game('count #5550002', 'The straight iron pins has 1 uses remaining.')
        game('get my straight pins from #758689', 'What were you referring to?')
        game('put #5550001 in #758689', put_away) { hands }
        expect(described_class.check_consumables('#5550002', 'tool-room', 5, 'duffel bag', [], nil, 5)).to be(true)
        expect(sent).to eq(['get #5550002 from #758689', 'count #5550002', 'dispose #5550002',
                            'get my straight pins from #758689', 'order 5 at tool-room', 'put #5550001 in #758689', 'walk 8775'])
        expect(gameobj.right_hand.id).to be_nil
      end

      # A bare noun would GET (and count, and keep) another brush in the bag
      # and never buy the wire brush that was thrown away.
      context 'with a worn-out "stiff wire brush" and a "sanding brush" in the bag' do
        let(:wire_brush) { ['5550010', 'brush', 'stiff wire brush'] }
        let(:new_wire_brush) { ['5550011', 'brush', 'stiff wire brush'] }
        let(:sanding_brush) { ['5550020', 'brush', 'sanding brush'] }

        before(:each) do
          allow(drct).to receive(:order_item) do |room, number|
            sent << "order #{number} at #{room}"
            hands(right: new_wire_brush)
            order_result
          end
        end

        it 'GETs "my stiff brush", which the sanding brush does not answer, and buys a wire brush' do
          game('get #5550010 from #758689', 'You get a stiff wire brush from inside your heavy silk duffel bag.') { hands(right: wire_brush) }
          game('count #5550010', 'The stiff wire brush has 1 uses remaining.')
          game('get my stiff brush from #758689', 'What were you referring to?')
          game('get my brush from #758689', 'You get a sanding brush from inside your heavy silk duffel bag.') { hands(right: sanding_brush) }
          game('put #5550011 in #758689', 'You put your brush in your heavy silk duffel bag.') { hands }
          expect(described_class.check_consumables(5_550_010, 'tool-room', 7, 'duffel bag', [], nil, 5)).to be(true)
          expect(sent).to eq(['get #5550010 from #758689', 'count #5550010', 'dispose #5550010',
                              'get my stiff brush from #758689', 'order 7 at tool-room', 'put #5550011 in #758689', 'walk 8775'])
        end
      end

      # The replacement is named from the hand's own noun, never from the
      # last word of its name. Every hand tag logged so far ends in its noun,
      # so this is a guard, not a replay: the brush below (noun="brush") is
      # logged 549 times in the 2026-11 logs, all in room or container
      # listings, never as a hand tag. If a hand name ever carried that
      # postfix, first and last word would GET "my steel dragon", miss the
      # brushes in the bag and order another one.
      context 'with a worn-out brush whose name does not end in its noun' do
        let(:etched_brush) { ['5550030', 'brush', 'steel wire-bristled brush acid-etched with a stylized dragon'] }
        let(:new_etched_brush) { ['5550031', 'brush', 'steel wire-bristled brush acid-etched with a stylized dragon'] }

        before(:each) do
          allow(drct).to receive(:order_item) do |room, number|
            sent << "order #{number} at #{room}"
            hands(right: new_etched_brush)
            order_result
          end
        end

        it 'GETs "my steel brush", not "my steel dragon", then buys and stows by id' do
          game('get #5550030 from #758689', 'You get a steel wire-bristled brush from inside your heavy silk duffel bag.') { hands(right: etched_brush) }
          game('count #5550030', 'The steel wire-bristled brush has 1 uses remaining.')
          game('get my steel brush from #758689', 'What were you referring to?')
          game('put #5550031 in #758689', 'You put your brush in your heavy silk duffel bag.') { hands }
          expect(described_class.check_consumables(5_550_030, 'tool-room', 7, 'duffel bag', [], nil, 5)).to be(true)
          expect(sent).to eq(['get #5550030 from #758689', 'count #5550030', 'dispose #5550030',
                              'get my steel brush from #758689', 'order 7 at tool-room', 'put #5550031 in #758689', 'walk 8775'])
        end
      end

      # A hand with an id but no noun gives no name to buy by: the worn-out
      # one is still disposed of by id, and nothing is fetched or bought.
      it 'disposes a worn-out id whose hand has no noun, then stops without buying' do
        game('get #5550002 from #758689', got_pins) { hands(right: ['5550002', nil, 'straight pins']) }
        game('count #5550002', 'The straight iron pins has 1 uses remaining.')
        expect(described_class.check_consumables('#5550002', 'tool-room', 5, 'duffel bag', [], nil, 5)).to be(false)
        expect(sent).to eq(['get #5550002 from #758689', 'count #5550002', 'dispose #5550002'])
        expect(Lich::Messaging).to have_received(:msg)
          .with('bold', 'DRCC: Disposed of worn-out #5550002 but could not tell its name. Not buying more.')
      end

      it 'returns false with the bought pins still held when the replacement PUT fails' do
        game('get #5550002 from #758689', got_pins) { hands(right: old_pins) }
        game('count #5550002', 'The straight iron pins has 1 uses remaining.')
        game('get my straight pins from #758689', 'What were you referring to?')
        game('put #5550001 in #758689', 'Perhaps you should be holding that first.')
        expect(described_class.check_consumables('#5550002', 'tool-room', 5, 'duffel bag', [], nil, 5)).to be(false)
        expect(gameobj.right_hand.id).to eq('5550001')
      end

      it 'returns false after the dispose when the id it got is not in hand to read a name from' do
        game('get #5550002 from #758689', got_pins)
        game('count #5550002', 'The straight iron pins has 1 uses remaining.')
        expect(described_class.check_consumables('#5550002', 'tool-room', 5, 'duffel bag', [], nil, 5)).to be(false)
        expect(sent).to eq(['get #5550002 from #758689', 'count #5550002', 'dispose #5550002'])
        expect(Lich::Messaging).to have_received(:msg)
          .with('bold', 'DRCC: Disposed of worn-out #5550002 but could not tell its name. Not buying more.')
      end

      it 'strips " #5550002" to the id: GET, COUNT and PUT by id, never "my  #5550002"' do
        game('get #5550002 from #758689', got_pins) { hands(right: old_pins) }
        game('count #5550002', 'The straight iron pins has 12 uses remaining.')
        game('put #5550002 in #758689', put_away) { hands }
        expect(described_class.check_consumables(' #5550002 ', 'tool-room', 5, 'duffel bag', [], nil, 5)).to be(true)
        expect(sent).to eq(['get #5550002 from #758689', 'count #5550002', 'put #5550002 in #758689', 'walk 8775'])
      end
    end

    it 'keeps "my duffel bag" when nothing is worn' do
      gameobj.clear_inv
      game('get my pins from my duffel bag', got_pins) { hands(right: pins) }
      game('count #5550001', 'The straight iron pins has 12 uses remaining.')
      game('put #5550001 in my duffel bag', put_away) { hands }
      expect(check).to be(true)
      expect(sent).to eq(['get my pins from my duffel bag', 'count #5550001', 'put #5550001 in my duffel bag', 'walk 8775'])
    end
  end

  # The name check_consumables replaces a worn-out "#<id>" consumable by: the
  # first word of the hand's name before its GameObj noun. Item names and
  # nouns are real (noun= from the 2026-11 logs).
  describe '.crafting_held_name' do
    def held_name(id, noun, name)
      hands(right: [id, noun, name])
      described_class.send(:crafting_held_name, "##{id}")
    end

    # Names that do not end in their noun, as logged in room and container
    # listings (no logged hand tag has this shape): first and last word
    # would give "bone audrualm", "sturdy bristles", "big stripes" and
    # "bucket gloop".
    [
      ['saw', 'bone saw with a blade edged in audrualm', 'bone saw'],
      ['brush', 'sturdy wire brush with stiff magenta bristles', 'sturdy brush'],
      ['oil', 'big flask of oil painted with viridian stripes', 'big oil'],
      ['bucket', 'bucket of viscous gloop', 'bucket']
    ].each do |noun, name, expected|
      it "gives #{expected.inspect} for #{name.inspect} (noun #{noun})" do
        expect(held_name('9201', noun, name)).to eq(expected)
      end
    end

    # Hand tags as logged: short, ending in the noun. The name is the one
    # DRC.fix_dr_bullshit gave before.
    [
      ['pins', 'straight pins', 'straight pins'],
      ['pins', 'sepia pins', 'sepia pins'],
      ['pouch', 'soft gem pouch', 'soft pouch'],
      ['shaper', 'jagged wood shaper', 'jagged shaper'],
      ['invitation', 'Hollow Eve invitation', 'Hollow invitation'],
      ["hhr'ata", "hhr'ata", "hhr'ata"]
    ].each do |noun, name, expected|
      it "gives #{expected.inspect} for the hand tag #{name.inspect}, as before" do
        expect(held_name('9202', noun, name)).to eq(expected)
        expect(drc.fix_dr_bullshit(name)).to eq(expected)
      end
    end

    it 'matches the first word to the noun ignoring case' do
      expect(held_name('9203', 'bucket', 'Bucket of viscous gloop')).to eq('bucket')
    end

    it 'reads the left hand too' do
      hands(right: pins, left: ['9204', 'saw', 'bone saw with a blade edged in audrualm'])
      expect(described_class.send(:crafting_held_name, '#9204')).to eq('bone saw')
    end

    [nil, '', '  '].each do |noun|
      it "gives nil for a held id whose noun is #{noun.inspect}" do
        expect(held_name('9205', noun, 'straight pins')).to be_nil
      end
    end

    it 'gives nil when no hand holds the id' do
      hands(right: pins)
      expect(described_class.send(:crafting_held_name, '#9999')).to be_nil
    end
  end
end
