# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'
require 'dragonrealms/commons/common'
require 'dragonrealms/commons/common-items'

DRCI = Lich::DragonRealms::DRCI unless defined?(DRCI)

# DRCI.held_ids / held_id / id_into_hand / worn_ref read the real GameObj
# hands and worn list. Hands are set through GameObj.new_right_hand /
# new_left_hand (what the XML parser calls), or by feeding the real parser
# DR's own tags; ids and names are verbatim from Barrask's 2026-11-04 logs
# unless an example says otherwise. An empty hand is the parser's placeholder:
# id nil, noun nil, name 'Empty'.
RSpec.describe Lich::DragonRealms::DRCI do
  let(:gameobj) { Lich::Common::GameObj }

  # Real hands, as the parser sets them. nil (or no args) is the 'Empty'
  # placeholder the parser makes from <right>Empty</right>.
  def hands(right: nil, left: nil)
    gameobj.new_right_hand(*(right || [nil, nil, 'Empty']))
    gameobj.new_left_hand(*(left || [nil, nil, 'Empty']))
  end

  def worn(*items)
    gameobj.clear_inv
    items.each { |id, noun, name| gameobj.new_inv(id, noun, name) }
  end

  let(:leather) { ['2222485', 'leather', 'rat-pelt leather'] }
  let(:cloth) { ['2227674', 'cloth', 'burlap cloth'] }
  let(:sinuous_leathers) { ['758572', 'leathers', 'sinuous leathers'] }
  let(:pack) { ['758573', 'pack', "scuffed traveler's pack"] }
  let(:duffel) { ['758689', 'bag', 'heavy silk duffel bag'] }
  # Bucket id and name are illustrative; the log shows "portable silversteel
  # bucket" in the drop reply but its id was not captured.
  let(:bucket) { ['758700', 'bucket', 'portable silversteel bucket'] }

  # None of these readers may send anything to the game.
  before do
    gameobj.clear_inv
    hands
    allow(Lich::DragonRealms::DRC).to receive(:bput).and_raise('DRCI sent a bput')
    allow(described_class).to receive(:fput).and_raise('DRCI sent an fput')
    allow(described_class).to receive(:put).and_raise('DRCI sent a put')
    allow(described_class).to receive(:sleep)
  end

  describe '.held_ids' do
    it 'lists the right hand first, then the left' do
      hands(right: leather, left: cloth)
      expect(described_class.held_ids).to eq(%w[2222485 2227674])
    end

    it "skips an empty hand (id nil, name 'Empty')" do
      hands(left: cloth)
      expect(gameobj.right_hand.name).to eq('Empty')
      expect(described_class.held_ids).to eq(['2227674'])
    end

    it 'is empty when both hands are empty' do
      expect(described_class.held_ids).to eq([])
    end

    it 'is empty before any hand tag has been seen (GameObj hands nil)' do
      gameobj.class_variable_set(:@@right_hand, nil)
      gameobj.class_variable_set(:@@left_hand, nil)
      expect(gameobj.right_hand).to be_nil
      expect(described_class.held_ids).to eq([])
    end

    it 'returns Strings when GameObj holds Integer ids' do
      hands(right: [2_222_485, 'leather', 'rat-pelt leather'])
      expect(described_class.held_ids).to eq(['2222485'])
    end
  end

  describe '.held_id' do
    context 'with the incident hands: rat-pelt leather held, sinuous leathers worn' do
      before do
        worn(sinuous_leathers, pack)
        hands(left: ['63721991', 'leather', 'rat-pelt leather'])
      end

      it 'resolves "leather" to the held leather, not the worn leathers' do
        expect(described_class.held_id('leather')).to eq('63721991')
      end

      it 'resolves the DRCC-style "my leather"' do
        expect(described_class.held_id('my leather')).to eq('63721991')
      end

      it 'does not resolve "leathers" (worn items are not held)' do
        expect(described_class.held_id('leathers')).to be_nil
      end

      it 'ignores case' do
        expect(described_class.held_id('My Rat-Pelt LEATHER')).to eq('63721991')
      end
    end

    it 'does not take a held "leathers" for "leather" (noun equality, not prefix)' do
      hands(right: sinuous_leathers)
      expect(described_class.held_id('leather')).to be_nil
    end

    it 'does not take a held "leather backpack" for "leather", where in_hands? does' do
      hands(right: ['555', 'backpack', 'leather backpack'])
      expect(described_class.in_hands?('leather')).to be true
      expect(described_class.held_id('leather')).to be_nil
    end

    context 'with the shortened names DRC.right_hand returns' do
      before { hands(right: duffel) }

      it 'resolves "heavy bag" (DRC.right_hand for "heavy silk duffel bag")' do
        expect(Lich::DragonRealms::DRC.right_hand).to eq('heavy bag')
        expect(described_class.held_id(Lich::DragonRealms::DRC.right_hand)).to eq('758689')
      end

      it 'resolves any words of the name ending in the noun' do
        expect(%w[bag duffel\ bag silk\ bag heavy\ silk\ duffel\ bag].map { |n| described_class.held_id(n) })
          .to all(eq('758689'))
      end

      it 'does not resolve a word that is not in the name' do
        expect(described_class.held_id('canvas bag')).to be_nil
      end

      it 'does not resolve a partial word' do
        expect(described_class.held_id('heav bag')).to be_nil
      end

      it 'does not resolve when the last word is not the noun' do
        expect(described_class.held_id('heavy duffel')).to be_nil
      end
    end

    it 'does not resolve part of a hyphenated word ("pelt" in "rat-pelt")' do
      hands(right: leather)
      expect(described_class.held_id('pelt leather')).to be_nil
    end

    context 'with two different held items matching' do
      before { hands(right: leather, left: ['2161092', 'leather', 'cougar-pelt leather']) }

      it 'is nil (ambiguous)' do
        expect(described_class.held_id('leather')).to be_nil
      end

      it 'resolves when another word tells them apart' do
        expect(described_class.held_id('cougar-pelt leather')).to eq('2161092')
      end

      it 'resolves the other one when the first is excepted by String id' do
        expect(described_class.held_id('leather', except: '2222485')).to eq('2161092')
      end

      it 'resolves the other one when the first is excepted by Integer id' do
        expect(described_class.held_id('leather', except: [2_222_485])).to eq('2161092')
      end

      it 'accepts a "#id" in except' do
        expect(described_class.held_id('leather', except: ['#2222485'])).to eq('2161092')
      end

      it 'is nil when both are excepted' do
        expect(described_class.held_id('leather', except: %w[2222485 2161092])).to be_nil
      end
    end

    context 'with a name starting with an ordinal or "other"' do
      # Synthetic names: the held item's name contains the ordinal word, so
      # the adjective rule alone would resolve the name; only the ordinal rule
      # keeps it from resolving.
      { 'second leather' => 'second leather', 'Second leather' => 'second leather',
        'other leather' => 'some other leather', 'my other leather' => 'some other leather',
        'first leather' => 'first leather', 'twentieth leather' => 'twentieth leather' }.each do |name, held_name|
        it "never resolves #{name.inspect} when holding #{held_name.inspect}, leaving the game's ordering" do
          hands(right: ['4243', 'leather', held_name])
          expect(described_class.held_id('leather')).to eq('4243')
          expect(described_class.held_id(name)).to be_nil
        end
      end

      # Synthetic name: the ordinal is a word of the item's own name, so only
      # the ordinal rule keeps it from resolving.
      it 'does not resolve even when the item name contains that word' do
        hands(right: ['4242', 'kit', 'first aid kit'])
        expect(described_class.held_id('aid kit')).to eq('4242')
        expect(described_class.held_id('first aid kit')).to be_nil
      end
    end

    context 'with no name' do
      it 'is the one held item' do
        hands(left: cloth)
        expect(described_class.held_id).to eq('2227674')
      end

      it 'is nil when both hands hold something' do
        hands(right: leather, left: cloth)
        expect(described_class.held_id).to be_nil
      end

      it 'is the other item when the sack is excepted' do
        hands(right: ['999', 'sack', 'burlap sack'], left: cloth)
        expect(described_class.held_id(nil, except: '999')).to eq('2227674')
      end

      it 'is nil with both hands empty' do
        expect(described_class.held_id).to be_nil
      end
    end

    context 'with a "#id" name' do
      it 'is the id when that item is held, as id_in_hand? says' do
        hands(left: leather)
        expect(described_class.id_in_hand?('2222485', 'either')).to be true
        expect(described_class.held_id('#2222485')).to eq('2222485')
      end

      it 'is the id when GameObj holds it as an Integer' do
        hands(left: [2_222_485, 'leather', 'rat-pelt leather'])
        expect(described_class.held_id('#2222485')).to eq('2222485')
      end

      it 'is nil when that item is not held, even if one with its noun is' do
        hands(left: leather)
        expect(described_class.held_id('#758574')).to be_nil
      end

      it 'is nil when excepted' do
        hands(left: leather)
        expect(described_class.held_id('#2222485', except: 2_222_485)).to be_nil
      end
    end

    context 'with an Integer name' do
      it 'is an id, as "#<id>", not a noun' do
        hands(left: leather)
        expect(described_class.held_id(2_222_485)).to eq('2222485')
        expect(described_class.held_id(758_574)).to be_nil
      end

      it 'is an id for id_into_hand too' do
        result = described_class.id_into_hand(name: 2_222_485, timeout: 0) do
          hands(left: leather)
          true
        end
        expect(result).to eq('2222485')
      end
    end

    it 'is nil for an empty or blank name' do
      hands(right: leather)
      expect(['', '   ', 'my '].map { |n| described_class.held_id(n) }).to all(be_nil)
    end

    it "never matches the empty-hand placeholder by its name 'Empty'" do
      expect(described_class.held_id('empty')).to be_nil
      expect(described_class.held_id('Empty')).to be_nil
    end

    it 'is nil before any hand tag has been seen (GameObj hands nil)' do
      gameobj.class_variable_set(:@@right_hand, nil)
      gameobj.class_variable_set(:@@left_hand, nil)
      expect(described_class.held_id('leather')).to be_nil
      expect(described_class.held_id).to be_nil
    end

    it 'keeps the matching rule private' do
      expect { described_class.held_obj_matches?(gameobj.right_hand, 'leather') }.to raise_error(NoMethodError, /private/)
    end
  end

  describe '.id_into_hand' do
    it "returns the id the block put in hand, at the first look (the hand tag beat the reply)" do
      result = described_class.id_into_hand(name: 'leather') do
        hands(left: leather)
        true
      end
      expect(result).to eq('2222485')
      expect(described_class).not_to have_received(:sleep)
    end

    it 'waits for a hand tag that arrives after the reply (fput-style block)' do
      looks = 0
      allow(described_class).to receive(:sleep) do |interval|
        expect(interval).to eq(0.1)
        looks += 1
        hands(left: leather) if looks == 3
      end
      expect(described_class.id_into_hand { true }).to eq('2222485')
      expect(looks).to eq(3)
    end

    it 'is nil after the timeout when nothing new arrives (10 looks at 0.1s for 1s)' do
      hands(right: leather)
      expect(described_class.id_into_hand { true }).to be_nil
      expect(described_class).to have_received(:sleep).exactly(10).times
    end

    it 'looks for timeout / 0.1 intervals, rounding up' do
      described_class.id_into_hand(timeout: 0.25) { true }
      expect(described_class).to have_received(:sleep).exactly(3).times
    end

    it 'looks once with timeout 0' do
      expect(described_class.id_into_hand(timeout: 0) { hands(left: leather) && true }).to eq('2222485')
      expect(described_class).not_to have_received(:sleep)
    end

    [nil, false].each do |falsy|
      it "is nil without looking when the block returns #{falsy.inspect}, even if an item arrived" do
        result = described_class.id_into_hand do
          hands(left: leather)
          falsy
        end
        expect(result).to be_nil
        expect(described_class).not_to have_received(:sleep)
      end
    end

    context 'with a block that runs a real GET reply' do
      def get_leather(reply, holds_after: nil)
        allow(Lich::DragonRealms::DRC).to receive(:bput) do
          hands(left: holds_after) if holds_after
          reply
        end
        described_class.id_into_hand(name: 'leather') do
          Lich::DragonRealms::DRC.bput('get my leather from my duffel bag', /^You get/, /^You need a free hand/, /^What were you referring to/)
                                 .match?(/^You get/)
        end
      end

      it 'returns the leather id on "You get"' do
        reply = "You get some rat-pelt leather from inside your duffel bag."
        expect(get_leather(reply, holds_after: leather)).to eq('2222485')
      end

      it 'is nil on "You need a free hand to do that." without waiting' do
        hands(right: leather, left: cloth)
        expect(get_leather('You need a free hand to do that.')).to be_nil
        expect(described_class).not_to have_received(:sleep)
      end

      it 'is nil on "What were you referring to?" without waiting' do
        expect(get_leather('What were you referring to?')).to be_nil
        expect(described_class).not_to have_received(:sleep)
      end
    end

    it 'is nil when the item only moved to the other hand (swap)' do
      hands(right: leather)
      result = described_class.id_into_hand do
        hands(left: leather)
        true
      end
      expect(result).to be_nil
    end

    it 'returns the new leather when another leather was already held' do
      hands(right: leather)
      result = described_class.id_into_hand(name: 'leather') do
        hands(right: leather, left: ['2161092', 'leather', 'rat-pelt leather'])
        true
      end
      expect(result).to eq('2161092')
    end

    it 'ignores a new item that does not match the name' do
      result = described_class.id_into_hand(name: 'leather') do
        hands(left: cloth)
        true
      end
      expect(result).to be_nil
      expect(described_class).to have_received(:sleep).exactly(10).times
    end

    it 'does not take worn "sinuous leathers" taken into hand for "leather"' do
      worn(sinuous_leathers)
      result = described_class.id_into_hand(name: 'leather') do
        hands(right: sinuous_leathers)
        true
      end
      expect(result).to be_nil
    end

    it 'skips an excepted id (Integer or String)' do
      result = described_class.id_into_hand(except: [999]) do
        hands(right: ['999', 'sack', 'burlap sack'])
        true
      end
      expect(result).to be_nil
    end

    it 'is nil when two new items match' do
      result = described_class.id_into_hand do
        hands(right: leather, left: cloth)
        true
      end
      expect(result).to be_nil
    end

    it 'returns a String for an Integer GameObj id' do
      result = described_class.id_into_hand do
        hands(left: [2_222_485, 'leather', 'rat-pelt leather'])
        true
      end
      expect(result).to eq('2222485')
    end

    it 'treats any truthy block value as success, so a timed-out order_item ("") must be compared' do
      expect(described_class.id_into_hand { '' }).to be_nil
      expect(described_class).to have_received(:sleep).exactly(10).times
    end

    [Float::INFINITY, Float::NAN].each do |bad|
      it "raises ArgumentError for timeout #{bad.inspect} before running the block" do
        ran = false
        expect { described_class.id_into_hand(timeout: bad) { ran = true } }.to raise_error(ArgumentError, /finite timeout/)
        expect(ran).to be false
      end
    end

    [nil, 'abc'].each do |odd|
      it "looks once for timeout #{odd.inspect} (coerced to 0)" do
        expect(described_class.id_into_hand(timeout: odd) { hands(left: leather) && true }).to eq('2222485')
        expect(described_class).not_to have_received(:sleep)
      end
    end

    it 'raises ArgumentError without a block' do
      expect { described_class.id_into_hand(name: 'leather') }.to raise_error(ArgumentError, /block/)
    end

    it "lets the block's exception through" do
      expect { described_class.id_into_hand { raise IOError, 'lost connection' } }.to raise_error(IOError)
    end
  end

  describe '.worn_ref' do
    before { worn(sinuous_leathers, pack, bucket, duffel) }

    it 'is "#id" for the one worn item whose name ends in the name' do
      expect(described_class.worn_ref('bucket')).to eq('#758700')
      expect(described_class.worn_ref('silversteel bucket')).to eq('#758700')
      expect(described_class.worn_ref('duffel bag')).to eq('#758689')
    end

    it 'ignores case' do
      expect(described_class.worn_ref('Duffel Bag')).to eq('#758689')
    end

    it "matches a name with an apostrophe (traveler's pack)" do
      expect(described_class.worn_ref("traveler's pack")).to eq('#758573')
    end

    it "does not match \"traveler's.pack\" (one word, not the noun pack)" do
      expect(described_class.worn_ref("traveler's.pack")).to eq("my traveler's.pack")
    end

    it 'does not match "leather" against worn "sinuous leathers"' do
      expect(described_class.worn_ref('leather')).to eq('my leather')
    end

    it 'does not match the end of a word ("ack" in "pack")' do
      expect(described_class.worn_ref('ack')).to eq('my ack')
    end

    it 'does not match words in the middle of the name' do
      expect(described_class.worn_ref('silk duffel')).to eq('my silk duffel')
    end

    it 'falls back to item_ref with two matches' do
      worn(duffel, ['758690', 'bag', 'leather bag'])
      expect(described_class.worn_ref('bag')).to eq('my bag')
    end

    it 'falls back to item_ref with no match' do
      expect(described_class.worn_ref('backpack')).to eq('my backpack')
    end

    it 'falls back to item_ref when GameObj.inv is nil' do
      gameobj.clear_inv
      expect(gameobj.inv).to be_nil
      expect(described_class.worn_ref('duffel bag')).to eq('my duffel bag')
    end

    it 'falls back for a name starting with an ordinal or "other" (spin.lic retries "other <bag>")' do
      expect(described_class.worn_ref('other duffel bag')).to eq('my other duffel bag')
      expect(described_class.worn_ref('second bag')).to eq('my second bag')
    end

    # Synthetic name ending in the ordinal phrase, so only the ordinal rule
    # keeps "other bag" from resolving to it.
    it 'falls back for "other ..." even when a worn name ends in it' do
      worn(['31337', 'bag', 'some other bag'])
      expect(described_class.worn_ref('bag')).to eq('#31337')
      expect(described_class.worn_ref('other bag')).to eq('my other bag')
    end

    it 'passes "#id", "my ..." and nil through' do
      expect(described_class.worn_ref('#123')).to eq('#123')
      expect(described_class.worn_ref('my duffel bag')).to eq('my duffel bag')
      expect(described_class.worn_ref('My duffel bag')).to eq('My duffel bag')
      expect(described_class.worn_ref(nil)).to be_nil
    end

    it 'gives an Integer back as "#<id>", not raising on strip' do
      expect(described_class.worn_ref(758_573)).to eq('#758573')
    end

    context 'with a held item and a worn item whose name ends in its name' do
      before do
        worn(['501', 'harness', 'weapon harness with a leather pouch'])
        hands(right: ['777', 'pouch', 'leather pouch'])
      end

      it 'does not take the harness (noun harness) for "leather pouch"' do
        expect(described_class.held_id('leather pouch')).to eq('777')
        expect(described_class.worn_ref('leather pouch')).to eq('my leather pouch')
      end

      # Its noun is a whole word of its name, even though the name does not
      # end in it ("...harness with a leather pouch"), so its noun finds it.
      it 'resolves "harness" by its noun though the name does not end in it' do
        expect(described_class.worn_ref('harness')).to eq('#501')
      end
    end

    it 'does not match part of a hyphenated word ("pelt" in "rat-pelt pack")' do
      worn(['31338', 'pack', 'rat-pelt pack'])
      expect(described_class.worn_ref('rat-pelt pack')).to eq('#31338')
      expect(described_class.worn_ref('pelt pack')).to eq('my pelt pack')
    end

    it 'drops surrounding whitespace, never giving "my  #id" or "my  my ..."' do
      expect(described_class.worn_ref(' #123')).to eq('#123')
      expect(described_class.worn_ref(' my bag ')).to eq('my bag')
      expect(described_class.worn_ref('  duffel bag ')).to eq('#758689')
      expect(described_class.worn_ref(' backpack ')).to eq('my backpack')
    end

    it 'falls back to item_ref for a blank name' do
      expect(described_class.worn_ref('   ')).to eq('my ')
    end

    it 'returns a String "#id" for an Integer GameObj id' do
      worn([758_689, 'bag', 'heavy silk duffel bag'])
      expect(described_class.worn_ref('duffel bag')).to eq('#758689')
    end

    it 'skips a worn entry without an id' do
      worn([nil, 'bag', 'duffel bag'])
      expect(described_class.worn_ref('duffel bag')).to eq('my duffel bag')
    end
  end

  # The incident, through the real XML parser: DR's own hand and worn tags,
  # then the command a script would build from the readers.
  context 'when DR streams the incident hands and worn list' do
    subject(:parser) { Lich::Common::XMLParser.new }

    def feed(*lines)
      lines.each { |l| Ox.sax_parse(parser, l, convert_special: false, symbolize: false, skip: :skip_none) }
    end

    before do
      allow(XMLData).to receive(:game).and_return('DR')
      parser.instance_variable_set(:@game, 'DR')
      feed("<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
           '  some <a exist="758572" noun="leathers">sinuous leathers</a>',
           %(  a <a exist="758573" noun="pack">scuffed traveler's pack</a>),
           '  a <a exist="758700" noun="bucket">portable silversteel bucket</a>',
           '<popStream/>',
           '<right exist="2222485" noun="leather">rat-pelt leather</right>',
           '<left>Empty</left>')
    end

    it 'parses an empty left hand as id nil' do
      expect(gameobj.left_hand.id).to be_nil
      expect(gameobj.left_hand.name).to eq('Empty')
    end

    it 'builds the bin command by id, so the worn leathers cannot be picked' do
      expect(described_class.held_ids).to eq(['2222485'])
      expect("put ##{described_class.held_id('leather')} in #{described_class.worn_ref('bucket')}")
        .to eq('put #2222485 in #758700')
    end

    it 'finds the bought cloth arriving in the empty left hand' do
      id = described_class.id_into_hand(name: 'cloth') do
        feed('<left exist="2227674" noun="cloth">burlap cloth</left>')
        true
      end
      expect(id).to eq('2227674')
      expect(described_class.held_ids).to eq(%w[2222485 2227674])
    end

    it 'drops a worn item from worn_ref once it is in hand' do
      feed('<right exist="758700" noun="bucket">portable silversteel bucket</right>')
      expect(described_class.worn_ref('bucket')).to eq('my bucket')
      expect(described_class.held_id('bucket')).to eq('758700')
    end
  end
end
