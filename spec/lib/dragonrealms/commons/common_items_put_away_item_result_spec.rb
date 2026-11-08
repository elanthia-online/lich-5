# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'timeout'
require 'ox'
require 'common/gameobj'
require 'dragonrealms/commons/common'
require 'dragonrealms/commons/common-items'

DRCI = Lich::DragonRealms::DRCI unless defined?(DRCI)

# DRCI.put_away_item_result through the real DRC.bput, against a small model
# of the game stream (each send queues that send's lines; get? reads them
# back), with the real GameObj hands. The real bput matters here: it returns
# only the part of the line its first matching pattern matched, and the
# result is classified from that part.
#
# Verbatim from Barrask's 2026-11-04 logs (tm-leftover sweep): the hand tag
# <right exist="1739939" noun="leather">rat-pelt leather</right>, the worn
# "sinuous leathers" 758572, the bucket 758550, "Perhaps you should be holding
# that first.", "There isn't any more room in the pack for that.", "You
# combine the stacks of leather together." and "You drop some rat-pelt
# leather into a portable silversteel bucket" (the log cuts the rest of that
# line; " with a flared rim." completes it here). "What were you referring
# to?" is the game's usual not-found reply. In the table, rows marked
# "written" were made up to match one pattern; the others are the lines
# above or lines reused from the other lich-5 specs.
RSpec.describe 'DRCI.put_away_item_result' do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }
  let(:gameobj) { Lich::Common::GameObj }
  let(:buffer) { [] }
  let(:sent) { [] }

  let(:leather) { ['1739939', 'leather', 'rat-pelt leather'] }
  let(:other_leather) { ['63721991', 'leather', 'rat-pelt leather'] }
  let(:bucket_ref) { '#758550' }

  let(:not_holding) { 'Perhaps you should be holding that first.' }
  let(:pack_full) { "There isn't any more room in the pack for that." }
  let(:not_found) { 'What were you referring to?' }
  let(:dropped) { 'You drop some rat-pelt leather into a portable silversteel bucket with a flared rim.' }

  def hands(right: nil, left: nil)
    gameobj.new_right_hand(*(right || [nil, nil, 'Empty']))
    gameobj.new_left_hand(*(left || [nil, nil, 'Empty']))
  end

  # The game: replies[:put] (for put and stow) and replies[:open] list, per
  # successive send of that verb, the lines it answers with (a String, an
  # Array of lines, or nil for silence). on_send runs before the lines are
  # queued, as DR sends the hand tag before the reply text.
  def game(put: [], open: [], &on_send)
    counts = Hash.new(0)
    allow(drc).to receive(:put) do |message|
      sent << message
      verb = message.split.first == 'open' ? :open : :put
      lines = { put: put, open: open }[verb][counts[verb]]
      counts[verb] += 1
      on_send&.call(message)
      buffer.concat(Array(lines))
    end
  end

  def result(*args, **opts)
    Timeout.timeout(3) { drci.put_away_item_result(*args, **opts) }
  end

  def messages
    Lich::Messaging.messages.map { |m| m[:message] }
  end

  before do
    stub_const('Lich::DragonRealms::DRC::BPUT_DEFAULT_TIMEOUT', 0.05)
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:pause) { |_seconds| sleep(0.001) }
    allow(drc).to receive(:get?) { buffer.shift }
    allow(drc).to receive(:put).and_raise('sent a command the example did not expect')
    Lich::Messaging.clear_messages!
    gameobj.clear_inv
    hands(right: leather)
  end

  describe 'the failure groupings' do
    let(:failures) { drci::PUT_AWAY_ITEM_FAILURE_PATTERNS }
    let(:groupings) do
      {
        not_holding: drci::PUT_AWAY_ITEM_NOT_HOLDING_PATTERNS,
        missing: drci::PUT_AWAY_ITEM_MISSING_PATTERNS,
        no_room: drci::PUT_AWAY_ITEM_NO_ROOM_PATTERNS
      }
    end

    it 'are frozen' do
      groupings.each_value { |patterns| expect(patterns).to be_frozen }
    end

    it 'hold the very Regexp objects of PUT_AWAY_ITEM_FAILURE_PATTERNS' do
      groupings.each_value do |patterns|
        patterns.each { |pattern| expect(failures.any? { |f| f.equal?(pattern) }).to be(true), pattern.inspect }
      end
    end

    # Each source listed in the grouping must still be in the array; an
    # edit to the array that drops or rewrites one shows up here.
    it 'find every pattern they list' do
      expect(groupings.transform_values { |patterns| patterns.map(&:source) }).to eq(
        not_holding: ['^Perhaps you should be holding that first'],
        missing: [
          '^Stow what',
          "^I can't find your container for stowing things in",
          '^What were you referring to',
          '^I could not find what you were referring to'
        ],
        no_room: [
          "^There isn't any more room in",
          "^There's no room",
          '^(The|That).* too heavy to go in there',
          "^Weirdly, you can't manage .* to fit",
          'even after stuffing it',
          'is too .* to (fit|hold)',
          'no matter how you arrange it',
          'completely full'
        ]
      )
    end

    it 'do not overlap' do
      all = groupings.values.flatten
      expect(all.uniq.size).to eq(all.size)
    end
  end

  # One row per reply: the reply, the Symbol it must give, and the pattern
  # it is there to cover. The spec below checks every pattern of the four
  # arrays put_away_item_unsafe? passes to bput is covered by some row.
  table = [
    # CONTAINER_IS_CLOSED_PATTERNS and the retry pattern: closed_lines and
    # retry_line below.
    # PUT_AWAY_ITEM_SUCCESS_PATTERNS
    ['You put your leather in your duffel bag.', :put],
    ['You hold out the leather and the clerk takes it.', :put], # written for /^You hold out/
    ['You stuff your cloth into your pack.', :put], # written for /^You stuff/
    ['You tuck your tongs into your backpack.', :put],
    ['You open your pouch and put the gem inside.', :put], # written
    ['You guide your puppy into the basket.', :put], # written
    ['You nudge your monkey into the cage.', :put], # written
    ['As you open your hand to release the moonblade, it crumbles away.', :put], # written
    ['The clerk nods toward you as your locket falls into the pawn bin.', :put], # written
    ['You add the leather to the stack in your bag.', :put], # written
    ['You rearrange a few things and fit the sword in your pack.', :put], # written
    ['You combine the stacks of leather together.', :put],
    ['You secure your dagger.', :put],
    ['You drop some rat-pelt leather into a portable silversteel bucket with a flared rim.', :put],
    ['You set the box on the table.', :put], # written
    ['You put the ingot on the anvil.', :put], # written for /^You put/i
    ['You carefully fit the pelt into your bundle.', :put], # written
    ['You gently set the egg on the cushion.', :put], # written
    ['Sheathing your sword, you put it away.', :put],
    ['You sheath your sword in your scabbard.', :put],
    ['You slip the knife into your boot.', :put], # written
    ['You hang the axe on your harness.', :put],
    ['You strap a longsword to your back.', :put],
    ['You easily strap the shield to your back.', :put], # written
    ['With a flick of your wrist you stealthily sheath your weapon.', :put],
    ['With fluid and stealthy movements you slip the sabre into your harness.', :put],
    ['The longsword slides easily into the scabbard.', :put],
    ['You toss the alcohol into the bowl and mix it in thoroughly.', :put],
    # PUT_AWAY_ITEM_FAILURE_PATTERNS
    ['Stow what?', :missing],
    ["I can't find your container for stowing things in!", :missing], # written
    ['Please rephrase that command.', :refused],
    ['What were you referring to?', :missing],
    ['I could not find what you were referring to.', :missing],
    ["There isn't any more room in the pack for that.", :no_room],
    ["There's no room in the backpack.", :no_room],
    ["That's too heavy to go in there!", :no_room],
    ['You need to unload the crossbow first.', :refused], # written
    ['You should unload the crossbow first.', :refused], # written
    ["You can't do that while submerged under water.", :refused],
    ["You just can't get the sword in there.", :refused], # written for /^You just can't get/ alone
    # Matches /^You just can't get/ first in the array, but is no room.
    ["You just can't get the small brazier to fit in the leather satchel, no matter how you arrange it.", :no_room],
    ["You can't put items in the vault.", :refused], # written
    ['You can only take items out of the vault.', :refused], # written
    ["You don't seem to be able to move to do that.", :refused],
    ['Perhaps you should be holding that first.', :not_holding],
    ["Containers can't be placed in the satchel.", :refused], # written
    ['The tray is not designed to carry anything.', :refused], # written
    ["You can't put that there.", :refused],
    ["Weirdly, you can't manage to get the bundle to fit in the pack.", :no_room], # written
    ["[Containers can't be placed in the vault.]", :refused], # written
    ["You can't fit the tongs in the backpack, even after stuffing it.", :no_room],
    ['The tongs is too long to fit in the backpack.', :no_room],
    ['You should close the fan first.', :refused],
    # /to fit in the/ alone is not one of DESIGN's no-room replies.
    ["You can't seem to get the haversack to fit in the pack.", :refused], # written
    ["Your kitten doesn't seem to want to leave you.", :refused], # written
    ['Oddly, when you attempt to stash it away safely, it slips from your grasp.', :refused], # written
    ['The duffel bag is completely full.', :no_room], # written
    ["That doesn't belong in there!", :refused], # written
    ['The vault exerts a steady force preventing you from putting that inside.', :refused] # written
  ]

  # Retry and closed replies need a second put; they have their own rows.
  retry_line = 'Something appears different about the lotion, perhaps try doing that again.'
  closed_lines = ["But that's closed.", 'That is closed.', "While it's closed, you can't reach inside."].freeze

  it 'covers every pattern put_away_item_unsafe? passes to bput' do
    lines = table.map(&:first) + [retry_line] + closed_lines
    patterns = drci::CONTAINER_IS_CLOSED_PATTERNS + drci::PUT_AWAY_ITEM_SUCCESS_PATTERNS +
               drci::PUT_AWAY_ITEM_FAILURE_PATTERNS + drci::PUT_AWAY_ITEM_RETRY_PATTERNS
    uncovered = patterns.reject { |pattern| lines.any? { |line| pattern.match?(line) } }
    expect(uncovered).to be_empty
  end

  # The same reply stream to both methods, item still in hand throughout:
  # the result is :put exactly when put_away_item_unsafe? is true, and both
  # send the same commands.
  describe 'against put_away_item_unsafe?' do
    calls = [
      ['my leather', '#758550'],
      ['#1739939', '#758550'],
      ['#1739939', nil],
      ['leather', 'bin']
    ]

    def both(item, container, put:, open: [])
      game(put: put, open: open)
      symbol = result(item, container)
      symbol_sent = sent.dup
      sent.clear
      game(put: put, open: open)
      boolean = Timeout.timeout(3) { drci.put_away_item_unsafe?(item, container) }
      expect(sent).to eq(symbol_sent)
      [symbol, boolean]
    end

    calls.each do |item, container|
      context "with put_away_item_result(#{item.inspect}, #{container.inspect})" do
        table.each do |line, expected|
          it "gives #{expected.inspect} for #{line.inspect}, :put only where unsafe? is true" do
            symbol, boolean = both(item, container, put: [line])
            expect(symbol).to eq(expected)
            expect(symbol == :put).to eq(boolean)
          end
        end

        it 'gives :timeout for no reply, and unsafe? false' do
          symbol, boolean = both(item, container, put: [nil])
          expect(symbol).to eq(:timeout)
          expect(boolean).to be(false)
        end

        it 'sends the retry and takes the second reply' do
          symbol, boolean = both(item, container, put: [retry_line, pack_full])
          expect(symbol).to eq(:no_room)
          expect(boolean).to be(false)
          expect(sent.size).to eq(2)
        end

        it 'gives :refused after retries run out, and unsafe? false' do
          symbol, boolean = both(item, container, put: [retry_line] * 4)
          expect(symbol).to eq(:refused)
          expect(boolean).to be(false)
          expect(sent.size).to eq(3)
        end

        closed_lines.each do |closed|
          it "opens after #{closed.inspect} and puts again, same as unsafe?" do
            symbol, boolean = both(item, container, put: [closed, dropped], open: ['You open the bucket.'])
            if container
              expect(symbol).to eq(:put)
              expect(boolean).to be(true)
              expect(sent).to eq(["put #{item} in #{container}", "open #{container}", "put #{item} in #{container}"])
            else
              expect(symbol).to eq(:closed)
              expect(boolean).to be(false)
              expect(sent).to eq(["stow #{item}"])
            end
          end

          it "gives :closed when the container won't open after #{closed.inspect}" do
            symbol, boolean = both(item, container, put: [closed], open: [not_found])
            expect(symbol).to eq(:closed)
            expect(boolean).to be(false)
          end
        end
      end
    end

    # The one place they differ, by design: no reply, and the "#<id>" item
    # was in hand when the put went out and is in neither hand now.
    it 'differs only when a #<id> item has left both hands without a reply' do
      game(put: [nil]) { |_| hands }
      expect(result('#1739939', bucket_ref)).to eq(:put)
      sent.clear
      hands(right: leather)
      game(put: [nil]) { |_| hands }
      expect(Timeout.timeout(3) { drci.put_away_item_unsafe?('#1739939', bucket_ref) }).to be(false)
    end
  end

  describe 'the incident' do
    it 'gives :not_holding when "my leather" names the worn leathers, and the leather stays in hand' do
      gameobj.new_inv('758572', 'leathers', 'sinuous leathers')
      game(put: [not_holding])
      expect(result('my leather', bucket_ref)).to eq(:not_holding)
      expect(sent).to eq(['put my leather in #758550'])
      expect(drci.held_ids).to eq(['1739939'])
    end

    it 'gives :put by id, as the hand tag empties the hand before the reply' do
      game(put: [dropped]) { |_| hands }
      expect(result('#1739939', bucket_ref)).to eq(:put)
      expect(sent).to eq(['put #1739939 in #758550'])
    end

    it 'gives :no_room for a full pack on stow, leaving the item held' do
      game(put: [pack_full])
      expect(result('#1739939')).to eq(:no_room)
      expect(sent).to eq(['stow #1739939'])
    end

    it 'gives :missing for "What were you referring to?"' do
      game(put: [not_found])
      expect(result('#1739939', bucket_ref)).to eq(:missing)
    end

    it 'is not fooled by the refusal quoted in speech' do
      game(put: [["Mahtra says, \"#{not_holding}\"", dropped]])
      expect(result('#1739939', bucket_ref)).to eq(:put)
    end
  end

  describe 'a reply that never comes' do
    it 'gives :put, and says so, when the #<id> item has left both hands' do
      game(put: ['The clerk looks up.']) { |_| hands }
      expect(result('#1739939', bucket_ref)).to eq(:put)
      expect(messages.last).to include("No reply to 'put #1739939 in #758550'", 'treating it as put away')
    end

    it 'gives :timeout when the #<id> item is still held' do
      game(put: [nil])
      expect(result('#1739939', bucket_ref)).to eq(:timeout)
    end

    it 'gives :timeout when the item only moved to the other hand' do
      game(put: [nil]) { |_| hands(left: leather) }
      expect(result('#1739939', bucket_ref)).to eq(:timeout)
    end

    it 'gives :timeout when the #<id> item was never in hand (empty hands, id nil)' do
      hands
      expect(gameobj.right_hand.name).to eq('Empty')
      game(put: [nil])
      expect(result('#1739939', bucket_ref)).to eq(:timeout)
    end

    it 'gives :timeout before any hand tag has been seen (GameObj hands nil)' do
      gameobj.class_variable_set(:@@right_hand, nil)
      gameobj.class_variable_set(:@@left_hand, nil)
      game(put: [nil])
      expect(result('#1739939', bucket_ref)).to eq(:timeout)
    end

    it 'gives :timeout for a name, even when the named item left the hand' do
      game(put: [nil]) { |_| hands }
      expect(result('my leather', bucket_ref)).to eq(:timeout)
    end

    it 'judges the hands at the put that timed out, after an open and retry' do
      game(put: ['That is closed.', nil], open: ['You open the bucket.']) do |message|
        hands if message.start_with?('put') && sent.size == 3
      end
      expect(result('#1739939', bucket_ref)).to eq(:put)
      expect(sent).to eq(['put #1739939 in #758550', 'open #758550', 'put #1739939 in #758550'])
    end
  end

  describe 'arguments' do
    it 'treats an Integer item and container as ids' do
      game(put: [dropped]) { |_| hands }
      expect(result(1_739_939, 758_550)).to eq(:put)
      expect(sent).to eq(['put #1739939 in #758550'])
    end

    it 'applies the lost-reply rule to an Integer item' do
      game(put: [nil]) { |_| hands }
      expect(result(1_739_939, 758_550)).to eq(:put)
    end

    it 'sends names as given, adding no "my "' do
      game(put: [dropped])
      expect(result('leather', 'bucket')).to eq(:put)
      expect(sent).to eq(['put leather in bucket'])
    end

    it 'does not pick an id for a name, even one held_id would resolve' do
      hands(right: leather, left: other_leather)
      game(put: [not_holding])
      expect(result('my leather', bucket_ref)).to eq(:not_holding)
      expect(sent).to eq(['put my leather in #758550'])
    end

    it 'uses the preposition' do
      game(put: ['You put the ingot on the anvil.'])
      expect(result('#1739939', 'anvil', preposition: 'on')).to eq(:put)
      expect(sent).to eq(['put #1739939 on anvil'])
    end

    it 'gives :refused and sends nothing with no retries left' do
      expect(result('#1739939', bucket_ref, retries: 0)).to eq(:refused)
      expect(messages.last).to include('put_away_item_result exceeded max retries')
    end

    it 'gives :refused when the last retry is used opening the container' do
      game(put: ['That is closed.'], open: ['You open the bucket.'])
      expect(result('#1739939', bucket_ref, retries: 1)).to eq(:refused)
      expect(sent).to eq(['put #1739939 in #758550', 'open #758550'])
    end

    it 'drops whitespace around a #<id> item, so the lost-reply rule still applies' do
      game(put: [nil]) { |_| hands }
      expect(result('#1739939 ', bucket_ref)).to eq(:put)
      expect(sent).to eq(['put #1739939 in #758550'])
    end

    it 'drops whitespace around the item and container, in the put and the open' do
      game(put: ['That is closed.', dropped], open: ['You open the bucket.']) { |_| hands }
      expect(result(" #1739939\t", " #{bucket_ref} ")).to eq(:put)
      expect(sent).to eq(['put #1739939 in #758550', 'open #758550', 'put #1739939 in #758550'])
    end

    it 'drops whitespace around the item on stow' do
      game(put: [pack_full])
      expect(result('  my leather  ')).to eq(:no_room)
      expect(sent).to eq(['stow my leather'])
    end

    # held_id gives the id without "#". As a String it is sent as written, a
    # name to the game, so no lost-reply rule; the caller writes "#<id>".
    it 'sends a digits-only String as written, not as an id' do
      hands(right: leather)
      id = drci.held_id('leather')
      expect(id).to eq('1739939')
      game(put: [nil]) { |_| hands }
      expect(result(id, bucket_ref)).to eq(:timeout)
      expect(sent).to eq(['put 1739939 in #758550'])
    end

    it 'puts by id when the caller adds "#" to held_id\'s result' do
      hands(right: leather)
      game(put: [nil]) { |_| hands }
      expect(result("##{drci.held_id('leather')}", bucket_ref)).to eq(:put)
      expect(sent).to eq(['put #1739939 in #758550'])
    end

    [nil, '', '   '].each do |item|
      it "gives :missing and sends nothing for item #{item.inspect}" do
        expect(result(item, bucket_ref)).to eq(:missing)
      end
    end
  end
end
