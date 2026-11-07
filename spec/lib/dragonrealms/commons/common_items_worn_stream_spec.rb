# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'
require 'dragonrealms/commons/common'
require 'dragonrealms/commons/common-items'

# DRCI.worn_item / worn? / wearing? / exists? read the worn-items list that the
# real XMLParser builds in the real GameObj. Stream lines, ids and names are
# verbatim from Quilsilgas' 2026-11-08 session (09:26 login, 09:37 REMOVE and
# WEAR of the sanowret crystal), where DR sent the whole linked worn list in
# the packet carrying the hand tag, ahead of the reply text.
#
# Game commands go through the real DRC.bput. The game is a queue of lines:
# each send queues that send's lines, get? reads them in order, clear empties
# the queue. A line queued ahead of the reply is another script's reply
# arriving first, which is how play.lic took tarantula's "I could not find"
# at login and exited with its zills worn.
RSpec.describe 'DRCI worn checks from the worn-items stream' do
  subject(:drci) { Lich::DragonRealms::DRCI }

  let(:drc) { Lich::DragonRealms::DRC }
  let(:gameobj) { Lich::Common::GameObj }
  let(:parser) { Lich::Common::XMLParser.new }
  let(:buffer) { [] }
  let(:sent) { [] }

  zills_name = 'some polished thin-edged zills with silvered esoteric filigree'
  not_found = 'I could not find what you were referring to.'
  zills_tap = "You tap #{zills_name} that you are wearing."
  prompt = '<prompt time="1794083832">&gt;</prompt>'

  worn_after_login = [
    "<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
    '  a <a exist="15705096" noun="crystal">sanowret crystal</a>',
    %(  <a exist="15705095" noun="zills">#{zills_name}</a>),
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
    %(<right exist="15705096" noun="crystal">sanowret crystal</right>#{worn_after_login.first}),
    *worn_after_login[2..],
    'You remove a <a exist="15705096" noun="crystal">sanowret crystal</a> from around your neck.',
    prompt
  ].freeze

  # WEAR MY CRYSTAL: empty hand + list with the crystal back, then the reply.
  wear_crystal = [
    "<right>Empty</right>#{worn_after_login.first}",
    *worn_after_login[1..],
    'You hang a <a exist="15705096" noun="crystal">sanowret crystal</a> around your neck.',
    prompt
  ].freeze

  def feed(*lines)
    lines.each { |l| Ox.sax_parse(parser, l, convert_special: false, symbolize: false, skip: :skip_none) }
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

  def worn_ids
    gameobj.inv.to_a.map(&:id)
  end

  before do
    allow(XMLData).to receive(:game).and_return('DR')
    parser.instance_variable_set(:@game, 'DR')
    gameobj.clear_inv
    gameobj.new_right_hand(nil, nil, 'Empty')
    gameobj.new_left_hand(nil, nil, 'Empty')
    # Any send not set up by an example fails it.
    game
    allow(drc).to receive(:put) { |message| raise "unexpected send: #{message}" }
  end

  context 'after the login worn list' do
    before { feed(*worn_after_login) }

    it 'files the linked worn list in GameObj.inv' do
      expect(worn_ids).to include('15705095', '15705096')
    end

    describe '.worn_item' do
      it "matches the setting's bare noun against the full long name" do
        expect(drci.worn_item('zills')&.id).to eq('15705095')
      end

      it 'matches adjectives in any position of the name, in any case' do
        %w[polished\ zills thin-edged\ zills Polished\ ZILLS filigree\ zills].each do |name|
          expect(drci.worn_item(name)&.id).to eq('15705095'), name
        end
      end

      it 'drops a leading "my "' do
        expect(drci.worn_item('my zills')&.id).to eq('15705095')
      end

      it 'matches "#<id>" and an Integer id, and nothing else, by id' do
        expect(drci.worn_item('#15705095')&.noun).to eq('zills')
        expect(drci.worn_item(15_705_095)&.noun).to eq('zills')
        expect(drci.worn_item('#99999999')).to be_nil
      end

      it 'matches a GameObj by id, as Lich::Stash.worn? does' do
        expect(drci.worn_item(gameobj.inv.find { |o| o.noun == 'crystal' })&.id).to eq('15705096')
        expect(drci.worn_item(gameobj.new_right_hand('15705096', 'crystal', 'sanowret crystal'))&.id).to eq('15705096')
      end

      it 'gives nil for an object with no id or an empty-hand placeholder' do
        expect(drci.worn_item(Object.new)).to be_nil
        expect(drci.worn_item(gameobj.right_hand)).to be_nil
      end

      it 'does not match an adjective the name lacks' do
        expect(drci.worn_item('brass zills')).to be_nil
      end

      it 'does not match a different noun (leather is not leathers, zill is not zills)' do
        expect(drci.worn_item('zill')).to be_nil
        expect(drci.worn_item('leather')).to be_nil # jerkin, vambraces and bag all have "leather" as an adjective
      end

      it 'never matches a name starting with an ordinal or "other"' do
        expect(drci.worn_item('second pack')).to be_nil
        expect(drci.worn_item('other pack')).to be_nil
      end

      it 'gives nil for nil, empty and blank names' do
        expect(drci.worn_item(nil)).to be_nil
        expect(drci.worn_item('')).to be_nil
        expect(drci.worn_item('   ')).to be_nil
        expect(drci.worn_item('my ')).to be_nil
      end
    end

    describe '.wearing?' do
      it 'answers true for worn zills with no game command' do
        expect(drci.wearing?('zills')).to be true
        expect(sent).to be_empty
      end

      it 'taps a name with no worn match, and the reply decides' do
        game(['You tap a steel sword inside your traveler\'s pack.'])
        expect(drci.wearing?('sword')).to be false
        expect(sent).to eq(['tap my sword '])
      end

      it 'taps an ordinal name even when an item of that noun is worn' do
        game(["You tap a canvas scribe's pack that you are wearing."])
        expect(drci.wearing?('second pack')).to be true
        expect(sent).to eq(['tap my second pack '])
      end
    end

    describe '.exists?' do
      it 'answers true for worn zills when another script\'s "I could not find" is ahead of any reply (the 09:26 login)' do
        buffer << not_found
        allow(drc).to receive(:get?) { buffer.shift }
        expect(drci.exists?('zills')).to be true
        expect(sent).to be_empty
      end

      it "still taps a missing item, so the other script's tap is the only one in flight" do
        game([not_found])
        expect(drci.exists?('biomechanical tarantula')).to be false
        expect(sent).to eq(['tap my biomechanical tarantula '])
      end

      it 'taps when a container is given, even for a worn item' do
        game(["You tap #{zills_name} inside your traveler's pack."])
        expect(drci.exists?('zills', 'pack')).to be true
        expect(sent).to eq(['tap my zills from my pack'])
      end

      it 'taps when a container is given and believes the reply over the worn list' do
        game([not_found])
        expect(drci.exists?('zills', 'pack')).to be false
      end

      it 'taps an "#<id>" that nothing worn or held has' do
        game(['You tap a steel sword inside your traveler\'s pack.'])
        expect(drci.exists?('#424242')).to be true
        expect(sent).to eq(['tap #424242 '])
      end

      # DR does not promise which item TAP finds as the "second", so an
      # ordinal name asks for a count: "second pack" means "at least two".
      context 'with an ordinal name' do
        it 'answers true with no game command when that many are worn (two packs)' do
          expect(drci.exists?('second pack')).to be true
          expect(drci.exists?('my second pack')).to be true
          expect(drci.exists?('Second PACK')).to be true
          expect(drci.exists?('first pack')).to be true
          expect(sent).to be_empty
        end

        it 'counts only worn items the rest of the name matches' do
          game([not_found])
          expect(drci.exists?("second traveler's pack")).to be false
          expect(sent).to eq(["tap my second traveler's pack "])
        end

        it 'taps when fewer are worn or held than asked for (the rest may be stowed)' do
          game(['You tap a spidersilk pack inside your duffel bag.'])
          expect(drci.exists?('third pack')).to be true
          expect(sent).to eq(['tap my third pack '])
        end

        it 'counts worn and held items together, each id once' do
          gameobj.new_right_hand('777', 'crystal', 'quartz crystal')
          expect(drci.exists?('second crystal')).to be true
          expect(sent).to be_empty
        end

        it 'does not count one item twice when it is in a hand and still in the worn list' do
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

    describe '.inside?' do
      it 'still taps a worn item (the worn list says nothing about containers)' do
        game([zills_tap])
        expect(drci.inside?('zills')).to be false
        expect(sent).to eq(['tap my zills '])
      end
    end
  end

  context 'with the 09:37 REMOVE and WEAR of the crystal' do
    before { feed(*worn_after_login) }

    it 'drops the crystal from the worn list on REMOVE, ahead of the reply text' do
      feed(remove_crystal.first, *remove_crystal[1..-3])
      expect(drci.worn?('crystal')).to be false
      expect(gameobj.right_hand.id).to eq('15705096')
    end

    it 'answers exists? from the hand once removed, with no game command' do
      feed(*remove_crystal)
      expect(drci.exists?('sanowret crystal')).to be true
      expect(drci.exists?('#15705096')).to be true
      expect(sent).to be_empty
    end

    it 'taps for wearing? once removed, since a held item is not worn' do
      feed(*remove_crystal)
      game(['You tap a sanowret crystal that you are holding.'])
      expect(drci.wearing?('crystal')).to be false
      expect(sent).to eq(['tap my crystal '])
    end

    it 'has the crystal back in the worn list on WEAR, ahead of the reply text' do
      feed(*remove_crystal)
      feed(wear_crystal.first, *wear_crystal[1..-3])
      expect(drci.worn_item('crystal')&.id).to eq('15705096')
      expect(gameobj.right_hand.id).to be_nil
    end
  end

  context 'with no usable worn list' do
    it 'taps when no worn list has arrived (GameObj.inv nil)' do
      expect(gameobj.inv).to be_nil
      game([zills_tap])
      expect(drci.wearing?('zills')).to be true
      expect(drci.worn?('zills')).to be false
      expect(sent).to eq(['tap my zills '])
    end

    it 'taps on the legacy stream, whose worn list has no links' do
      feed("<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
           "  #{zills_name}", '<popStream/>')
      expect(gameobj.inv).to be_nil
      game([not_found])
      expect(drci.exists?('zills')).to be false
      expect(sent).to eq(['tap my zills '])
    end

    it 'never answers from INV LIST entries, which carry no noun' do
      gameobj.new_inv('15705095', nil, zills_name)
      expect(drci.worn?('zills')).to be false
      expect(drci.worn?('#15705095')).to be true # an id still names it
    end
  end
end
