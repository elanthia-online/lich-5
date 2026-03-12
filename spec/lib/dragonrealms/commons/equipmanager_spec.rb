# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load production code - Item class is in common.rb, EquipmentManager in equipmanager.rb
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-items.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'equipmanager.rb')

RSpec.describe Lich::DragonRealms::EquipmentManager do
  # Build a minimal settings double with a fan weapon
  let(:fan_gear) do
    [{ name: 'fan', adjective: 'thick-bladed', swappable: true }]
  end

  let(:settings) do
    double('Settings',
           gear: fan_gear,
           gear_sets: {},
           sort_auto_head: false)
  end

  let(:em) { described_class.new(settings) }

  before(:each) do
    Lich::Messaging.clear_messages!
  end

  # ─── Fan stow recovery ──────────────────────────────────────────────

  describe '#stow_weapon (fan close recovery)' do
    let(:fan_item) { em.item_by_desc('thick-bladed fan') }

    before do
      # Confirm the item was found and configured correctly
      expect(fan_item).not_to be_nil
      expect(fan_item.short_name).to eq('thick-bladed.fan')
      expect(fan_item.swappable).to be true
    end

    it 'fan item takes the else branch (not wield/worn/tie/transform/container)' do
      # Verify none of the preceding branches would be taken
      expect(fan_item.wield).to be_falsy
      expect(fan_item.worn).to be_falsy
      expect(fan_item.tie_to).to be_nil
      expect(fan_item.transforms_to).to be_nil
      expect(fan_item.container).to be_nil
    end

    context 'when game says to close the fan before stowing' do
      it 'calls close then retries stow successfully' do
        # First bput: "stow my thick-bladed.fan" -> game says close the fan
        # Second bput (after close): "stow my thick-bladed.fan" -> success
        call_count = 0
        allow(DRC).to receive(:bput) do |command, *_patterns|
          call_count += 1
          case call_count
          when 1
            expect(command).to eq('stow my thick-bladed.fan')
            "close the fan"
          when 2
            expect(command).to eq('stow my thick-bladed.fan')
            "You put your fan in your duffel bag."
          else
            raise "Unexpected bput call ##{call_count}: #{command}"
          end
        end

        # fput is a Kernel-level method called inside stow_helper
        expect(em).to receive(:fput).with('close my thick-bladed.fan')

        em.stow_weapon('thick-bladed fan')
      end

      it 'traces what bput actually returns for the close-the-fan response' do
        # This test directly exercises bput's pattern matching to see
        # what it returns when PUT_AWAY_ITEM_FAILURE_PATTERNS has /close the fan/
        # and STOW_RECOVERY_PATTERNS also has /close the fan/
        game_response = "You'll need to close the fan before you put it away."

        # Simulate what bput does internally:
        patterns = [
          *DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS,
          *DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS,
          *described_class::STOW_RECOVERY_PATTERNS
        ]

        # bput does: matches.flatten!; matches.map! { |item| item.is_a?(Regexp) ? item : /#{item}/i }
        patterns.flatten!
        patterns.map! { |item| item.is_a?(Regexp) ? item : /#{item}/i }

        # Find which pattern matches first (same as bput's matches.each loop)
        matched_pattern = nil
        bput_return = nil
        patterns.each do |match|
          result = game_response.match(match)
          if result
            matched_pattern = match
            bput_return = result.to_a.first
            break
          end
        end

        puts "  Game response: #{game_response.inspect}"
        puts "  First matching pattern: #{matched_pattern.inspect}"
        puts "  bput return value: #{bput_return.inspect}"
        puts "  Pattern source: #{pattern_source(matched_pattern, patterns)}"

        # Now check if stow_helper's case/when would match
        case_matches_unload = (bput_return =~ /unload/)
        case_matches_fan = (bput_return =~ /close the fan/)
        puts "  case/when /unload/ matches: #{!case_matches_unload.nil?}"
        puts "  case/when /close the fan/ matches: #{!case_matches_fan.nil?}"

        expect(bput_return).not_to be_nil
        expect(bput_return).to match(/close the fan/)
      end
    end

    context 'pattern ordering analysis' do
      it 'shows which constant contains /close the fan/ and at what index' do
        [
          ['PUT_AWAY_ITEM_SUCCESS_PATTERNS', DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS],
          ['PUT_AWAY_ITEM_FAILURE_PATTERNS', DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS],
          ['STOW_RECOVERY_PATTERNS', described_class::STOW_RECOVERY_PATTERNS],
          ['SHEATH_SUCCESS_PATTERNS', described_class::SHEATH_SUCCESS_PATTERNS],
          ['SHEATH_FAILURE_PATTERNS', described_class::SHEATH_FAILURE_PATTERNS],
          ['WEAR_ITEM_FAILURE_PATTERNS', DRCI::WEAR_ITEM_FAILURE_PATTERNS],
          ['TIE_ITEM_FAILURE_PATTERNS', DRCI::TIE_ITEM_FAILURE_PATTERNS]
        ].each do |name, patterns|
          idx = patterns.index { |p| p.is_a?(Regexp) && "close the fan" =~ p }
          puts "  #{name}: #{idx.nil? ? 'NOT FOUND' : "index #{idx} of #{patterns.length}"}"
        end
      end
    end
  end

  # Helper to identify which constant a pattern came from
  def pattern_source(pattern, _all_patterns)
    success_count = DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS.length
    failure_count = DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS.length

    idx = [
      *DRCI::PUT_AWAY_ITEM_SUCCESS_PATTERNS,
      *DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS,
      *described_class::STOW_RECOVERY_PATTERNS
    ].index(pattern)

    return 'unknown' if idx.nil?

    if idx < success_count
      "PUT_AWAY_ITEM_SUCCESS_PATTERNS[#{idx}]"
    elsif idx < success_count + failure_count
      "PUT_AWAY_ITEM_FAILURE_PATTERNS[#{idx - success_count}]"
    else
      "STOW_RECOVERY_PATTERNS[#{idx - success_count - failure_count}]"
    end
  end
end
