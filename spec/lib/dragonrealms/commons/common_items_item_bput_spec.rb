# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'timeout'
require_relative '../../../../lib/dragonrealms/commons/common'
require_relative '../../../../lib/dragonrealms/commons/common-items'
require_relative '../../../../lib/dragonrealms/commons/equipmanager'

# DRCI.item_bput -- a player's custom_item_success_patterns -- through the real
# DRC.bput, against a small model of the game stream: each send queues that
# send's replies and get? reads them back in order. Every example is bounded
# well below BPUT_DEFAULT_TIMEOUT, so a reply nothing matched fails the example
# instead of waiting 15 seconds.
#
# 'You unhook your quiver from your belt.' stands for a reply no built-in
# pattern knows; the first example pins that. The other replies are verbatim
# from game logs.
RSpec.describe 'DRCI.item_bput through the real DRC.bput' do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }
  let(:subs) { Lich::DragonRealms::CustomSubstitutions }
  let(:player_success) { Lich::DragonRealms::DRCI::PlayerSuccess }
  let(:buffer) { [] }
  let(:sent) { [] }
  let(:replies) { [] }
  let(:unknown_reply) { 'You unhook your quiver from your belt.' }
  let(:not_worn) { "You aren't wearing that." }

  before do
    subs.reset!
    Lich::Messaging.clear_messages!
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:pause) { |_seconds| sleep(0.001) }
    allow(drc).to receive(:get?) { buffer.shift }
    # replies: the same Array for every send, or a Hash of command => Array.
    allow(drc).to receive(:put) do |message|
      sent << message
      buffer.concat(replies.is_a?(Hash) ? replies.fetch(message, []) : replies)
    end
  end

  after { subs.reset! }

  def player_patterns(value)
    allow(subs).to receive(:get_settings).and_return(OpenStruct.new(custom_item_success_patterns: value))
  end

  def bounded(&block)
    Timeout.timeout(3, &block)
  end

  def warnings
    Lich::Messaging.messages.select { |m| m[:type] == 'warn' }.map { |m| m[:message] }.join("\n")
  end

  it 'uses a reply no built-in remove pattern matches' do
    patterns = drci::REMOVE_ITEM_SUCCESS_PATTERNS + drci::REMOVE_ITEM_FAILURE_PATTERNS
    expect(patterns.none? { |p| p.match?(unknown_reply) }).to be(true)
  end

  describe 'DRCI.remove_item?' do
    context 'with a player pattern for the unknown reply' do
      before { player_patterns('remove' => ['^You unhook']) }

      let(:replies) { [unknown_reply] }

      it 'returns true at once' do
        expect(bounded { drci.remove_item?('quiver') }).to be(true)
        expect(sent).to eq(['remove my quiver'])
      end

      it 'marks the reply as a PlayerSuccess' do
        result = bounded { drci.item_bput('remove my quiver', drci::REMOVE_ITEM_SUCCESS_PATTERNS, drci::REMOVE_ITEM_FAILURE_PATTERNS) }
        expect(result).to be_a(player_success)
        expect(result).to eq('You unhook')
        expect(result).to be_frozen
      end
    end

    context 'with a broad player pattern' do
      before { player_patterns('remove' => ['^You']) }

      context 'when the game refuses' do
        let(:replies) { [not_worn] }

        it 'still returns false: the built-in failure wins the line' do
          expect(bounded { drci.remove_item?('cloak') }).to be(false)
        end
      end

      context 'when the game confirms in words Lich knows' do
        let(:replies) { ['You remove a cloak.'] }

        it 'returns the built-in match, not a PlayerSuccess' do
          result = bounded { drci.item_bput('remove my cloak', drci::REMOVE_ITEM_SUCCESS_PATTERNS, drci::REMOVE_ITEM_FAILURE_PATTERNS) }
          expect(result).not_to be_a(player_success)
          expect(drci::REMOVE_ITEM_SUCCESS_PATTERNS.any? { |p| p.match?(result) }).to be(true)
        end
      end
    end

    # The documented limit (DRCI.item_bput): bput reads every line while it
    # waits, so a broad pattern can match an unrelated line before the reply.
    context 'with a broad player pattern and an unrelated line before the refusal' do
      let(:replies) { ['You hear the distant howl of a wolf.', not_worn] }

      it 'counts the unrelated line as success' do
        player_patterns('remove' => ['^You'])
        expect(bounded { drci.remove_item?('cloak') }).to be(true)
      end

      it 'returns false with no player patterns' do
        player_patterns(nil)
        expect(bounded { drci.remove_item?('cloak') }).to be(false)
      end

      it 'returns false with a pattern for the exact reply' do
        player_patterns('remove' => ['^You unhook your .* from your belt'])
        expect(bounded { drci.remove_item?('cloak') }).to be(false)
      end
    end

    # bput returns only the matched text, which a lookaround pattern need not
    # match a second time; item_bput must not match the player's patterns again.
    ['^You unhook(?= your)', '(?<=^You )unhook'].each do |pattern|
      context "with a player pattern using a lookaround (#{pattern})" do
        before { player_patterns('remove' => [pattern]) }

        let(:replies) { [unknown_reply] }

        it 'returns true' do
          expect(bounded { drci.remove_item?('quiver') }).to be(true)
        end
      end
    end

    context 'with a player pattern that also matches the built-in failure text' do
      before { player_patterns('remove' => ["aren't wearing"]) }

      let(:replies) { [not_worn] }

      it 'returns false: the reply came from a built-in pattern' do
        expect(bounded { drci.remove_item?('cloak') }).to be(false)
      end
    end

    context 'with a pattern that runs past its match timeout' do
      before { player_patterns('remove' => ['^(a|aa)+\1$']) }

      let(:replies) { ["#{'a' * 40}b"] }

      it 'reports it and returns false instead of hanging or raising' do
        expect(bounded { drci.remove_item?('cloak') }).to be(false)
        expect(warnings).to include('custom_item_success_patterns[remove]', 'took too long', "'remove my cloak' was treated as unanswered")
      end
    end
  end

  # item_bput tells a player's match from a built-in one by matching the
  # built-in patterns against bput's return value, the matched text alone. A
  # built-in pattern that does not match its own match text (a positive
  # lookahead or lookbehind, or \B) would have its replies counted as player
  # successes.
  describe 'the built-in patterns item_bput classifies against' do
    not_self_matching = /\(\?<?=|\\B/

    it 'has no positive lookaround or \\B in any DRCI or EquipmentManager pattern constant' do
      [Lich::DragonRealms::DRCI, Lich::DragonRealms::EquipmentManager].each do |mod|
        mod.constants.each do |name|
          Array(mod.const_get(name)).grep(Regexp).each do |pattern|
            expect(pattern.source).not_to match(not_self_matching), "#{mod}::#{name} has #{pattern.inspect}"
          end
        end
      end
    end

    it 'has none in the inline patterns either, apart from one String#sub' do
      %w[common-items.rb equipmanager.rb].each do |file|
        lines = File.readlines(File.join(LIB_DIR, 'dragonrealms', 'commons', file))
        offenders = lines.each_with_index.select { |line, _| line.match?(not_self_matching) }
                         .reject { |line, _| line.include?('.sub(/ and (?=a|an|some)/') || line.lstrip.start_with?('#') }
        expect(offenders.map { |line, index| "#{file}:#{index + 1}: #{line.strip}" }).to eq([])
      end
    end
  end

  describe 'the verb' do
    let(:replies) { [unknown_reply] }

    it 'comes from the first word of the command' do
      player_patterns('wear' => ['^You unhook'])
      expect(bounded { drci.item_bput('remove my quiver', drci::REMOVE_ITEM_SUCCESS_PATTERNS, ['^You unhook your']) }).not_to be_a(player_success)
      expect(bounded { drci.item_bput('wear my quiver', drci::WEAR_ITEM_SUCCESS_PATTERNS) }).to be_a(player_success)
    end

    it 'accepts Symbol verb keys' do
      player_patterns(remove: ['^You unhook'])
      expect(bounded { drci.remove_item?('quiver') }).to be(true)
    end

    it 'never reads the settings for a verb it does not support' do
      expect(subs).not_to receive(:get_settings)
      expect(bounded { drci.item_bput('turn my quiver', /^You unhook/) }).to eq('You unhook')
    end
  end

  describe 'what bput receives' do
    it 'is the caller arguments unchanged when the player has no patterns' do
      player_patterns(nil)
      expect(drc).to receive(:bput).with('remove my cloak', drci::REMOVE_ITEM_SUCCESS_PATTERNS, drci::REMOVE_ITEM_FAILURE_PATTERNS).and_return('')
      drci.item_bput('remove my cloak', drci::REMOVE_ITEM_SUCCESS_PATTERNS, drci::REMOVE_ITEM_FAILURE_PATTERNS)
    end

    it 'keeps an options Hash first and puts the player patterns last' do
      player_patterns('give' => ['^You hand'])
      expect(drc).to receive(:bput) do |command, *args|
        expect(command).to eq('give my sword to Ragge')
        expect(args.first).to eq('timeout' => 35)
        expect(args.last.source).to eq('^You hand')
        ''
      end
      drci.give_item?('Ragge', 'sword')
    end
  end

  describe 'the setting' do
    let(:replies) { [unknown_reply] }

    it 'reports a misspelt verb once and keeps the rest' do
      player_patterns('remvoe' => ['^You unhook'], 'wear' => ['^You unhook'])
      2.times { bounded { drci.item_bput('wear my quiver', drci::WEAR_ITEM_SUCCESS_PATTERNS) } }
      bounded { drci.item_bput('remove my quiver', drci::REMOVE_ITEM_SUCCESS_PATTERNS, ['^You unhook your']) }
      expect(warnings.scan('custom_item_success_patterns[remvoe] ignored').size).to eq(1)
      expect(bounded { drci.item_bput('wear my quiver', drci::WEAR_ITEM_SUCCESS_PATTERNS) }).to be_a(player_success)
    end

    it 'reports a value that is not a map and loads nothing' do
      player_patterns(['^You unhook'])
      expect(bounded { drci.item_bput('remove my quiver', ['^You unhook your']) }).not_to be_a(player_success)
      expect(warnings).to include('custom_item_success_patterns ignored -- expected a map')
    end
  end

  # Every helper routed through item_bput, given a reply only the player's
  # pattern for its verb matches: each must count the PlayerSuccess as success.
  # A helper that went back to DRC.bput would wait out the bput timeout, and
  # one that dropped PlayerSuccess from its success branch would fail.
  describe 'each DRCI helper counts a PlayerSuccess as success' do
    let(:replies) { [unknown_reply] }

    before do
      allow(drci).to receive(:item_bput).and_call_original
      allow(drci).to receive(:in_hands?).and_return(true)
      allow(drci).to receive(:in_left_hand?).and_return(true)
      allow(drci).to receive(:id_in_hand?).and_return(false)
    end

    {
      'wear_item?'           => ['wear', -> { wear_item?('quiver') }, true],
      'remove_item?'         => ['remove', -> { remove_item?('quiver') }, true],
      'tie_item_result'      => ['tie', -> { tie_item_result('quiver', 'belt') }, :tied],
      'untie_item?'          => ['untie', -> { untie_item?('quiver', 'belt') }, true],
      'stow_item?'           => ['stow', -> { stow_item?('quiver') }, true],
      'stow_hand'            => ['stow', -> { stow_hand('left') }, true],
      'lower_item?'          => ['lower', -> { lower_item?('quiver') }, true],
      'lift?'                => ['lift', -> { lift?('quiver') }, true],
      'put_away_item?'       => ['put', -> { put_away_item?('quiver', 'pack') }, true],
      'put_away_item_result' => ['put', -> { put_away_item_result('quiver', 'pack') }, :put],
      'open_container?'      => ['open', -> { open_container?('pack') }, true],
      'close_container?'     => ['close', -> { close_container?('pack') }, true],
      'give_item?'           => ['give', -> { give_item?('Ragge', 'quiver') }, true]
    }.each do |helper, (verb, call, expected)|
      it "#{helper} (#{verb})" do
        player_patterns(verb => ['^You unhook'])
        expect(bounded { drci.instance_exec(&call) }).to eq(expected)
        expect(drci).to have_received(:item_bput).with(start_with("#{verb} "), any_args)
      end
    end

    it 'get_item_from_eddy_portal? (get)' do
      allow(drci).to receive(:open_container?).and_return(true)
      allow(drci).to receive(:look_in_container).and_return(true)
      player_patterns('get' => ['^You unhook'])
      expect(bounded { drci.get_item_from_eddy_portal?('quiver', 'portal in my eddy') }).to be(true)
    end

    it 'get_item_unsafe ends the wait on the PlayerSuccess (get)' do
      player_patterns('get' => ['^You unhook'])
      expect(bounded { drci.get_item_unsafe('quiver', 'pack') }).to be(true)
      expect(sent).to eq(['get quiver from pack'])
    end

    context 'when give has to swap the item into the right hand first' do
      let(:replies) do
        { 'give my quiver to Ragge' => ["You don't need to specify the object"], 'swap' => [unknown_reply],
          'give Ragge' => ['Ragge has accepted your offer.'] }
      end

      it 'counts a PlayerSuccess swap and gives again' do
        allow(drci).to receive(:in_right_hand?).and_return(false)
        allow(drci).to receive(:in_left_hand?).and_return(true)
        player_patterns('swap' => ['^You unhook'])
        expect(bounded { drci.give_item?('Ragge', 'quiver') }).to be(true)
        expect(sent).to eq(['give my quiver to Ragge', 'swap', 'give Ragge'])
      end
    end
  end

  describe 'each EquipmentManager command counts a PlayerSuccess as success' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { Lich::DragonRealms::EquipmentManager.new(settings) }
    let(:weapon) { double('weapon', short_name: 'sword', short_regex: /sword/, swappable: false, wield: true) }
    let(:replies) { [unknown_reply] }

    before { allow(em).to receive(:waitrt?) }

    it 'get_item? wields (wield)' do
      allow(DRCI).to receive(:in_hands?).and_return(false)
      player_patterns('wield' => ['^You unhook'])
      expect(bounded { em.get_item?(weapon) }).to be(true)
      expect(sent).to eq(['wield my sword'])
    end

    it 'stow_helper (sheath)' do
      player_patterns('sheath' => ['^You unhook'])
      result = bounded do
        em.send(:stow_helper, 'sheath my sword', 'sword', *DRCI::SHEATH_ITEM_SUCCESS_PATTERNS, failure_patterns: DRCI::SHEATH_ITEM_FAILURE_PATTERNS)
      end
      expect(result).to be(true)
    end

    it 'unload_weapon stows the ammo hand (unload)' do
      allow(DRC).to receive(:left_hand).and_return('basilisk arrows')
      allow(DRC).to receive(:right_hand).and_return('longbow')
      expect(DRCI).to receive(:stow_hand).with('left').and_return(true)
      player_patterns('unload' => ['^You unhook'])
      bounded { em.unload_weapon('longbow') }
    end

    %w[wield_weapon_offhand? wield_weapon?].each do |method|
      it "#{method} swaps into the off hand (swap)" do
        allow(em).to receive(:item_by_desc).and_return(weapon)
        allow(em).to receive(:get_item?).and_return(true)
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return(nil)
        allow(DRCI).to receive(:in_right_hand?).and_return(true)
        player_patterns('swap' => ['^You unhook'])
        expect(bounded { em.public_send(method, 'steel sword', 'Offhand Weapon') }).to be(true)
        expect(sent).to eq(['swap'])
      end
    end

    # These decide from the hands, not the reply: the player's pattern only
    # has to end the wait, so a plain DRC.bput would hang past the bound.
    context 'when the reply only ends the wait' do
      let(:item) do
        double('item', short_name: 'quiver', short_regex: /quiver/, name: 'quiver', transforms_to: nil,
                       tie_to: nil, wield: nil, container: nil)
      end

      before do
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return(nil)
      end

      it 'remove_item stows after a PlayerSuccess remove (stow)' do
        allow(em).to receive(:wear_item?)
        player_patterns('remove' => ['^You unhook'], 'stow' => ['^You unhook'])
        bounded { em.remove_item(item) }
        expect(sent).to eq(['remove my quiver', 'stow my quiver'])
      end

      # get_item_helper also matches any "You ... quiver" line, so this reply
      # leaves the item out.
      it 'get_item_helper (remove)' do
        allow(item).to receive_messages(transform_verb: 'turn', transform_text: 'turns')
        allow(em).to receive(:item_noun_in_hands?).and_return(true)
        player_patterns('remove' => ['^You unhook'])
        replies.replace(['You unhook it from your belt.'])
        expect(bounded { em.send(:get_item_helper, item, :worn) }).to be(true)
      end

      it 'pick_up_lowered_item? (get)' do
        allow(em).to receive(:newly_in_hand?).and_return(true)
        player_patterns('get' => ['^You unhook'])
        expect(bounded { em.send(:pick_up_lowered_item?, 'quiver') }).to be(true)
        expect(sent).to eq(['get my quiver'])
      end
    end

    context 'when remove has to empty the hands and restore their order' do
      let(:item) { double('item', short_name: 'helm') }
      let(:replies) { { 'remove my helm' => ["You'll need both hands free to do that."], 'swap' => [unknown_reply] } }

      it 'counts a PlayerSuccess swap as restored (swap)' do
        allow(DRC).to receive(:left_hand).and_return('sword', 'shield')
        allow(DRC).to receive(:right_hand).and_return('shield', 'sword')
        allow(DRCI).to receive(:lower_item?).and_return(true)
        allow(em).to receive(:pick_up_lowered_items)
        player_patterns('swap' => ['^You unhook'])
        bounded { em.remove_item(item, retries: 1) }
        expect(sent).to eq(['remove my helm', 'swap'])
        expect(warnings + Lich::Messaging.messages.map { |m| m[:message] }.join).not_to include('Unable to restore hand order')
      end
    end
  end

  describe 'EquipmentManager#remove_item' do
    let(:settings) { double('settings', gear_sets: {}, sort_auto_head: false, gear: []) }
    let(:em) { Lich::DragonRealms::EquipmentManager.new(settings) }
    let(:item) { double('item', short_name: 'quiver', transforms_to: nil, tie_to: nil, wield: nil, container: 'pack') }
    let(:replies) { [unknown_reply] }

    before do
      allow(em).to receive(:waitrt?)
      player_patterns('remove' => ['^You unhook'])
    end

    it 'takes the success branch for a PlayerSuccess' do
      expect(em).to receive(:stow_by_type).with(item)
      expect(DRCI).not_to receive(:lower_item?)
      bounded { em.remove_item(item) }
    end
  end
end
