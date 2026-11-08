# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'
require 'dragonrealms/commons/common'
require 'dragonrealms/commons/common-items'

# DRCI.wearing? and DRCI.exists? answer worn and held items from the live
# worn-items list (GameObj.inv) and the hands, matching a name's words as whole
# words in the item's name, and tap for everything else. The real XMLParser
# builds the real GameObj from Quilsilgas' 2026-11-08 stream: the 09:26 login
# worn list and the 09:37 REMOVE and WEAR of the crystal, where DR re-sent the
# whole list with the hand tag, ahead of the reply text.
#
# Game commands go through the real DRC.bput. The game is a queue of lines:
# each send queues that send's lines, get? reads them in order, clear empties
# the queue. A line queued ahead of the reply is another script's reply
# arriving first: at the 09:26 login play.lic took tarantula's "I could not
# find" that way and exited with its zills worn.
RSpec.describe 'DRCI worn and held checks from the live stream' do
  subject(:drci) { Lich::DragonRealms::DRCI }

  let(:drc) { Lich::DragonRealms::DRC }
  let(:gameobj) { Lich::Common::GameObj }
  let(:parser) { Lich::Common::XMLParser.new }
  let(:buffer) { [] }
  let(:sent) { [] }

  zills_long = 'some polished thin-edged zills with silvered esoteric filigree'
  not_found = 'I could not find what you were referring to.'
  prompt = '<prompt time="1794083832">&gt;</prompt>'

  worn_list = [
    "<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
    '  a <a exist="15705096" noun="crystal">sanowret crystal</a>',
    %(  <a exist="15705095" noun="zills">#{zills_long}</a>),
    %(  a <a exist="15705078" noun="pack">spidersilk traveler's pack dyed with shifting hues of red and black</a>),
    '  a <a exist="15705077" noun="bag">heartname leather thigh bag edged in cloud turquoise beading</a>',
    '  a <a exist="15705076" noun="charm">divine charm</a>',
    %(  a <a exist="15705070" noun="pack">canvas scribe's pack</a>),
    '  a <a exist="15705069" noun="jerkin">leather jerkin</a>',
    '  <a exist="15705068" noun="vambraces">some buckled leather vambraces</a>',
    '  a <a exist="15705067" noun="skirt">flowing blue skirt</a>',
    '<popStream/>'
  ].freeze

  # REMOVE MY SANOWRET CRYSTAL: hand tag + list without the crystal, then the reply.
  remove_crystal = [
    %(<right exist="15705096" noun="crystal">sanowret crystal</right>#{worn_list.first}),
    *worn_list[2..],
    'You remove a <a exist="15705096" noun="crystal">sanowret crystal</a> from around your neck.',
    prompt
  ].freeze

  # WEAR MY CRYSTAL: empty hand + list with the crystal back, then the reply.
  wear_crystal = [
    "<right>Empty</right>#{worn_list.first}",
    *worn_list[1..],
    'You hang a <a exist="15705096" noun="crystal">sanowret crystal</a> around your neck.',
    prompt
  ].freeze

  def feed(*lines)
    lines.flatten.each { |l| Ox.sax_parse(parser, l, convert_special: false, symbolize: false, skip: :skip_none) }
  end

  def game(*lines_per_send)
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:put) do |message|
      sent << message
      buffer.concat(Array(lines_per_send[sent.size - 1]))
    end
    allow(drc).to receive(:get?) { buffer.shift }
    allow(drc).to receive(:pause) { sleep(0.001) }
  end

  before do
    allow(XMLData).to receive(:game).and_return('DR')
    parser.instance_variable_set(:@game, 'DR')
    gameobj.clear_inv
    gameobj.new_right_hand(nil, nil, 'Empty')
    gameobj.new_left_hand(nil, nil, 'Empty')
    game
    # Any send an example has not set up fails it.
    allow(drc).to receive(:put) { |message| raise "unexpected send: #{message}" }
  end

  context 'after the login worn list' do
    before { feed(worn_list) }

    describe '.exists?' do
      it "answers true for worn zills with another script's \"I could not find\" queued ahead (the 09:26 login)" do
        buffer << not_found
        allow(drc).to receive(:get?) { buffer.shift }
        expect(drci.exists?('zills')).to be true
        expect(sent).to be_empty
      end

      it 'answers true, sending nothing, for whole words of the long name in any case' do
        ['zills', 'ZILLS', 'thin-edged zills', 'my zills', 'some zills', 'a sanowret crystal', 'canvas scribe\'s pack',
         'thigh bag', '#15705095'].each do |name|
          expect(drci.exists?(name)).to be(true), name
        end
        expect(sent).to be_empty
      end

      it 'taps a name whose words are not whole words of a worn name' do
        names = ['zill', 'edged zills', 'polished zills', 'traveler', 'thin zills']
        game(*names.map { [not_found] })
        names.each { |name| expect(drci.exists?(name)).to be(false), name }
        expect(sent).to eq(names.map { |name| "tap my #{name} " })
      end

      it 'taps "bag" when only bagpipes are worn (whole words only)' do
        feed("<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
             '  some <a exist="31337" noun="bagpipes">tartan bagpipes</a>', '<popStream/>')
        game([not_found])
        expect(drci.exists?('bag')).to be false
        expect(sent).to eq(['tap my bag '])
      end

      # Synthetic name: the phrase "red pack" appears only as the front of
      # "red packet", while the item's noun (pack) is one of the words.
      it 'taps when the phrase is only the front of a longer word' do
        feed("<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
             '  a <a exist="31339" noun="pack">leather pack holding a red packet</a>', '<popStream/>')
        game([not_found])
        expect(drci.exists?('red pack')).to be false
        expect(sent).to eq(['tap my red pack '])
      end

      it 'still taps a missing item, so its own TAP is the only one in flight' do
        game([not_found])
        expect(drci.exists?('biomechanical tarantula')).to be false
        expect(sent).to eq(['tap my biomechanical tarantula '])
      end

      it 'taps an "#<id>" that nothing worn or held has' do
        game(["You tap a steel sword inside your traveler's pack."])
        expect(drci.exists?('#424242')).to be true
        expect(sent).to eq(['tap #424242 '])
      end

      it 'taps when a container is given, even for a worn item, and believes the reply' do
        game([not_found])
        expect(drci.exists?('zills', 'pack')).to be false
        expect(sent).to eq(['tap my zills from my pack'])
      end

      # DR does not promise which item TAP finds as the "second", so an ordinal
      # name asks for a count: "second pack" means "at least two".
      context 'with an ordinal name' do
        it 'answers true, sending nothing, when that many are worn (two packs)' do
          %w[first\ pack second\ pack my\ second\ pack Second\ PACK].each { |name| expect(drci.exists?(name)).to be(true), name }
          expect(sent).to be_empty
        end

        it 'taps when fewer are worn or held than asked for (the rest may be stowed)' do
          game(["You tap a canvas pack inside your duffel bag."])
          expect(drci.exists?('third pack')).to be true
          expect(sent).to eq(['tap my third pack '])
        end

        it "counts only items the rest of the name matches (one traveler's pack)" do
          game([not_found])
          expect(drci.exists?("second traveler's pack")).to be false
          expect(sent).to eq(["tap my second traveler's pack "])
        end

        it 'counts a worn and a held match together, each id once' do
          gameobj.new_right_hand('777', 'crystal', 'quartz crystal')
          expect(drci.exists?('second crystal')).to be true
          gameobj.new_right_hand('15705096', 'crystal', 'sanowret crystal')
          game([not_found])
          expect(drci.exists?('second crystal')).to be false
          expect(sent).to eq(['tap my second crystal '])
        end

        it 'taps a bare ordinal and an "other" name' do
          game([not_found], [not_found])
          expect(drci.exists?('second')).to be false
          expect(drci.exists?('other pack')).to be false
          expect(sent).to eq(['tap my second ', 'tap my other pack '])
        end
      end
    end

    describe '.wearing?' do
      it 'answers true, sending nothing, for worn zills by noun or DR short name' do
        expect(drci.wearing?('zills')).to be true
        expect(drci.wearing?('thin-edged zills')).to be true
        expect(sent).to be_empty
      end

      it 'taps a name with no worn match, and the reply decides' do
        game(["You tap a steel sword inside your traveler's pack."])
        expect(drci.wearing?('sword')).to be false
        expect(sent).to eq(['tap my sword '])
      end

      it 'taps an ordinal or "other" name even when items of that noun are worn' do
        game(["You tap a canvas scribe's pack that you are wearing."], [not_found])
        expect(drci.wearing?('second pack')).to be true
        expect(drci.wearing?('other pack')).to be false
        expect(sent).to eq(['tap my second pack ', 'tap my other pack '])
      end

      # Synthetic name containing the ordinal phrase, so only the ordinal rule
      # keeps "other bag" from answering from the list.
      it 'taps an "other" or ordinal name even when a worn name contains those words' do
        feed("<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
             '  a <a exist="31337" noun="bag">bag stitched to some other bag</a>',
             '  a <a exist="31338" noun="ring">ring worn as a second ring</a>', '<popStream/>')
        game([not_found], [not_found])
        expect(drci.wearing?('other bag')).to be false
        expect(drci.wearing?('second ring')).to be false
        expect(sent).to eq(['tap my other bag ', 'tap my second ring '])
      end

      # A worn item with the name's words is worn, whichever item TAP would have
      # picked first.
      it 'answers true when a held item and a different worn item share the words' do
        gameobj.new_right_hand('889', 'zills', 'brass zills')
        expect(drci.wearing?('zills')).to be true
        expect(sent).to be_empty
      end

      it 'does not count a held item as worn' do
        gameobj.new_right_hand('888', 'sword', 'steel sword')
        game(['You tap a steel sword that you are holding.'])
        expect(drci.wearing?('steel sword')).to be false
        expect(sent).to eq(['tap my steel sword '])
      end
    end

    # worn_ref gives a worn container's "#<id>" by the same rule, so the
    # stream's long names resolve: before, its rule needed the name to end in
    # the given words, and these all fell back to "my ...".
    describe '.worn_ref' do
      it 'gives the id for the noun or DR short name of a long-named worn item' do
        expect(drci.worn_ref('zills')).to eq('#15705095')
        expect(drci.worn_ref('thin-edged zills')).to eq('#15705095')
        expect(drci.worn_ref("traveler's pack")).to eq('#15705078')
        expect(drci.worn_ref('thigh bag')).to eq('#15705077')
        expect(sent).to be_empty
      end

      it 'falls back to "my ..." with two matches or none' do
        expect(drci.worn_ref('pack')).to eq('my pack')                  # two worn packs
        expect(drci.worn_ref('red pack')).to eq('my red pack')          # "red" is in the description
        expect(drci.worn_ref('leather bag')).to eq('my leather bag')    # not whole words in order
        expect(drci.worn_ref('turquoise beading')).to eq('my turquoise beading') # no noun
        expect(drci.worn_ref('zill')).to eq('my zill')
      end
    end

    describe '.inside?' do
      it 'still taps a worn item (the worn list says nothing about containers)' do
        game(["You tap #{zills_long} that you are wearing."])
        expect(drci.inside?('zills')).to be false
        expect(sent).to eq(['tap my zills '])
      end
    end
  end

  context 'with the 09:37 REMOVE and WEAR of the crystal' do
    before { feed(worn_list) }

    it 'answers exists? from the hand (its short name) once removed, sending nothing' do
      feed(remove_crystal)
      expect(drci.exists?('sanowret crystal')).to be true
      expect(drci.exists?('crystal')).to be true
      expect(sent).to be_empty
    end

    it 'taps for wearing? once removed, since a held item is not worn' do
      feed(remove_crystal)
      game(['You tap a sanowret crystal that you are holding.'])
      expect(drci.wearing?('crystal')).to be false
      expect(sent).to eq(['tap my crystal '])
    end

    it 'answers wearing? from the list again once worn, ahead of the reply text' do
      feed(remove_crystal)
      feed(wear_crystal[0..-3]) # the list, before the "You hang" line
      expect(drci.wearing?('sanowret crystal')).to be true
      expect(sent).to be_empty
    end
  end

  # BOOST TRAVEL on Mahtra, 2026-11-01 12:37: the orb appears in hand and, once
  # raised, crumbles away. DR sends the hand change and the whole worn list in
  # the same packet, ahead of the text, both when it appears and when it is
  # destroyed. Tag shapes and ids are verbatim; the worn list is Quilsilgas'.
  context 'with an item that crumbles away (no command moves it)' do
    before { feed(worn_list) }

    it 'answers from the hand while the orb is held, and taps once it is gone' do
      feed(%(<right exist="58193349" noun="orb">translocation orb</right>#{worn_list.first}), *worn_list[1..],
           'A <a exist="58193349" noun="orb">mottled translocation orb</a> appears in your right hand!', prompt)
      expect(drci.exists?('translocation orb')).to be true
      expect(sent).to be_empty

      feed(%(<right>Empty</right><roundTime value='1793489861'/>#{worn_list.first}), *worn_list[1..],
           'Red lights flicker from the <a exist="58193349" noun="orb">translocation orb</a> as it crumbles away into nothingness.', prompt)
      game([not_found])
      expect(drci.exists?('translocation orb')).to be false
      expect(sent).to eq(['tap my translocation orb '])
    end
  end

  context 'with a worn entry from another source' do
    it 'matches a short name with its noun (as the inventory feed gives it)' do
      gameobj.new_inv('15705095', 'zills', 'polished thin-edged zills')
      expect(drci.wearing?('zills')).to be true
      expect(drci.exists?('thin-edged zills')).to be true
      expect(sent).to be_empty
    end

    it 'taps for an entry with no noun' do
      gameobj.new_inv('15705095', nil, 'thin-edged zills')
      game(["You tap #{zills_long} that you are wearing."])
      expect(drci.wearing?('zills')).to be true
      expect(sent).to eq(['tap my zills '])
    end
  end

  # Words from a worn item's long description are in its name but are not its
  # noun, and TAP would not find the item by them. Each of these taps.
  context "with words from a worn item's description" do
    before do
      feed("<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
           '  a <a exist="501" noun="cloak">silk cloak embroidered with a red flower</a>',
           '  a <a exist="502" noun="ring">lockpick ring</a>',
           '  a <a exist="503" noun="belt">heavy rope belt</a>',
           '  a <a exist="15705077" noun="bag">heartname leather thigh bag edged in cloud turquoise beading</a>',
           '<popStream/>')
    end

    ['red flower', 'flower', 'lockpick', 'heavy rope', 'rope', 'turquoise beading', 'leather'].each do |name|
      it "taps exists?(#{name.inspect}) and wearing?(#{name.inspect})" do
        game([not_found], [not_found])
        expect(drci.exists?(name)).to be false
        expect(drci.wearing?(name)).to be false
        expect(sent).to eq(["tap my #{name} ", "tap my #{name} "])
      end
    end

    it 'still answers the items by their nouns, sending nothing' do
      %w[cloak lockpick\ ring ring rope\ belt thigh\ bag].each { |name| expect(drci.exists?(name)).to be(true), name }
      expect(sent).to be_empty
    end
  end

  context 'with no worn list' do
    it 'taps (GameObj.inv nil)' do
      expect(gameobj.inv).to be_nil
      game(["You tap #{zills_long} that you are wearing."], [not_found])
      expect(drci.wearing?('zills')).to be true
      expect(drci.exists?('zills')).to be false
      expect(sent).to eq(['tap my zills ', 'tap my zills '])
    end
  end
end
