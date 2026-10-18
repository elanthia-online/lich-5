# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'timeout'

# Global used by check_moonwatch for autostart message
$clean_lich_char ||= ';'

# Load production code. drvariables publishes the $NUM_MAP global, which
# parse_roisaen uses to convert spelled-out durations; it is a pure constants
# file (no side effects) so requiring it here is safe.
require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'drvariables.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-moonmage.rb')

DRCMM = Lich::DragonRealms::DRCMM unless defined?(DRCMM)

RSpec.describe Lich::DragonRealms::DRCMM do
  before(:each) do
    Lich::Messaging.clear_messages!
  end

  # ================================================================
  # Constants
  # ================================================================
  describe 'constants' do
    it 'MOON_WEAPON_REGEX is frozen' do
      expect(described_class::MOON_WEAPON_REGEX).to be_frozen
    end

    it 'MOON_WEAPON_NAMES is frozen' do
      expect(described_class::MOON_WEAPON_NAMES).to be_frozen
    end

    it 'MOON_WEAR_MESSAGES is frozen' do
      expect(described_class::MOON_WEAR_MESSAGES).to be_frozen
    end

    it 'MOON_DROP_MESSAGES is frozen' do
      expect(described_class::MOON_DROP_MESSAGES).to be_frozen
    end

    it 'MOON_COLOR_TO_NAME is frozen' do
      expect(described_class::MOON_COLOR_TO_NAME).to be_frozen
    end

    it 'MOON_GLANCE_REGEX is frozen' do
      expect(described_class::MOON_GLANCE_REGEX).to be_frozen
    end

    it 'MOON_FOCUS_DURATION_REGEX is frozen' do
      expect(described_class::MOON_FOCUS_DURATION_REGEX).to be_frozen
    end

    it 'MOON_FOCUS_EXPIRING_REGEX is frozen' do
      expect(described_class::MOON_FOCUS_EXPIRING_REGEX).to be_frozen
    end

    it 'DIV_TOOL_VERBS is frozen' do
      expect(described_class::DIV_TOOL_VERBS).to be_frozen
    end

    it 'MOON_VISIBILITY_TIMER_THRESHOLD equals 4' do
      expect(described_class::MOON_VISIBILITY_TIMER_THRESHOLD).to eq(4)
    end

    it 'CENTER_TELESCOPE_MESSAGES is frozen' do
      expect(described_class::CENTER_TELESCOPE_MESSAGES).to be_frozen
    end

    it 'CENTER_TELESCOPE_MESSAGES contains 10 patterns' do
      expect(described_class::CENTER_TELESCOPE_MESSAGES.length).to eq(10)
    end
  end

  # ================================================================
  # is_moon_weapon?
  # ================================================================
  describe '.is_moon_weapon?' do
    it 'returns true for "black moonblade"' do
      expect(described_class.is_moon_weapon?('black moonblade')).to be true
    end

    it 'returns true for "red-hot moonblade"' do
      expect(described_class.is_moon_weapon?('red-hot moonblade')).to be true
    end

    it 'returns true for "blue-white moonblade"' do
      expect(described_class.is_moon_weapon?('blue-white moonblade')).to be true
    end

    it 'returns true for "black moonstaff"' do
      expect(described_class.is_moon_weapon?('black moonstaff')).to be true
    end

    it 'returns true for "red-hot moonstaff"' do
      expect(described_class.is_moon_weapon?('red-hot moonstaff')).to be true
    end

    it 'returns true for "blue-white moonstaff"' do
      expect(described_class.is_moon_weapon?('blue-white moonstaff')).to be true
    end

    it 'is case-insensitive' do
      expect(described_class.is_moon_weapon?('BLACK MOONBLADE')).to be true
      expect(described_class.is_moon_weapon?('Blue-White MoonStaff')).to be true
    end

    it 'returns false for nil' do
      expect(described_class.is_moon_weapon?(nil)).to be false
    end

    it 'returns false for empty string' do
      expect(described_class.is_moon_weapon?('')).to be false
    end

    it 'returns false for regular weapon' do
      expect(described_class.is_moon_weapon?('longsword')).to be false
    end

    it 'returns false for moonblade without color prefix' do
      expect(described_class.is_moon_weapon?('moonblade')).to be false
    end

    it 'returns false for moonstaff without color prefix' do
      expect(described_class.is_moon_weapon?('moonstaff')).to be false
    end

    it 'returns false for partial match with extra text' do
      expect(described_class.is_moon_weapon?('black moonblade and shield')).to be false
    end

    it 'returns false for invalid color prefix' do
      expect(described_class.is_moon_weapon?('green moonblade')).to be false
    end
  end

  # ================================================================
  # holding_moon_weapon?
  # ================================================================
  describe '.holding_moon_weapon?' do
    it 'returns true when left hand holds moon weapon' do
      allow(DRC).to receive(:left_hand).and_return('black moonblade')
      allow(DRC).to receive(:right_hand).and_return(nil)
      expect(described_class.holding_moon_weapon?).to be true
    end

    it 'returns true when right hand holds moon weapon' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return('red-hot moonstaff')
      expect(described_class.holding_moon_weapon?).to be true
    end

    it 'returns true when both hands hold moon weapons' do
      allow(DRC).to receive(:left_hand).and_return('black moonblade')
      allow(DRC).to receive(:right_hand).and_return('blue-white moonstaff')
      expect(described_class.holding_moon_weapon?).to be true
    end

    it 'returns false when neither hand holds moon weapon' do
      allow(DRC).to receive(:left_hand).and_return('longsword')
      allow(DRC).to receive(:right_hand).and_return('shield')
      expect(described_class.holding_moon_weapon?).to be false
    end

    it 'returns false when both hands are empty' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      expect(described_class.holding_moon_weapon?).to be false
    end
  end

  # ================================================================
  # wear_moon_weapon?
  # ================================================================
  describe '.wear_moon_weapon?' do
    context 'when holding a moon weapon in left hand' do
      before do
        allow(DRC).to receive(:left_hand).and_return('black moonblade')
        allow(DRC).to receive(:right_hand).and_return(nil)
      end

      it 'returns true when wear succeeds' do
        allow(DRC).to receive(:bput).and_return('telekinetic')
        expect(described_class.wear_moon_weapon?).to be true
      end

      it 'returns false when wear fails' do
        allow(DRC).to receive(:bput).and_return("You can't wear")
        expect(described_class.wear_moon_weapon?).to be false
      end
    end

    context 'when holding moon weapons in both hands' do
      it 'returns true if either wear succeeds' do
        allow(DRC).to receive(:left_hand).and_return('black moonblade')
        allow(DRC).to receive(:right_hand).and_return('red-hot moonstaff')
        allow(DRC).to receive(:bput).with('wear black moonblade', *described_class::MOON_WEAR_MESSAGES).and_return("You can't wear")
        allow(DRC).to receive(:bput).with('wear red-hot moonstaff', *described_class::MOON_WEAR_MESSAGES).and_return('telekinetic')
        expect(described_class.wear_moon_weapon?).to be true
      end
    end

    context 'when not holding any moon weapon' do
      it 'returns false without calling bput' do
        allow(DRC).to receive(:left_hand).and_return('longsword')
        allow(DRC).to receive(:right_hand).and_return(nil)
        expect(DRC).not_to receive(:bput)
        expect(described_class.wear_moon_weapon?).to be false
      end
    end
  end

  # ================================================================
  # drop_moon_weapon?
  # ================================================================
  describe '.drop_moon_weapon?' do
    context 'when holding a moon weapon' do
      before do
        allow(DRC).to receive(:left_hand).and_return('black moonblade')
        allow(DRC).to receive(:right_hand).and_return(nil)
      end

      it 'returns true when drop succeeds' do
        allow(DRC).to receive(:bput).and_return('As you open your hand')
        expect(described_class.drop_moon_weapon?).to be true
      end

      it 'returns false when drop fails' do
        allow(DRC).to receive(:bput).and_return('What were you referring to')
        expect(described_class.drop_moon_weapon?).to be false
      end
    end

    context 'when not holding a moon weapon' do
      it 'returns false without calling bput' do
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return(nil)
        expect(DRC).not_to receive(:bput)
        expect(described_class.drop_moon_weapon?).to be false
      end
    end
  end

  # ================================================================
  # hold_moon_weapon?
  # ================================================================
  describe '.hold_moon_weapon?' do
    it 'returns true immediately if already holding one' do
      allow(DRC).to receive(:left_hand).and_return('black moonblade')
      allow(DRC).to receive(:right_hand).and_return(nil)
      expect(DRC).not_to receive(:bput)
      expect(described_class.hold_moon_weapon?).to be true
    end

    it 'returns false if both hands are full' do
      allow(DRC).to receive(:left_hand).and_return('longsword')
      allow(DRC).to receive(:right_hand).and_return('shield')
      expect(DRC).not_to receive(:bput)
      expect(described_class.hold_moon_weapon?).to be false
    end

    it 'returns true when grab succeeds for moonblade' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a wicked black moonblade')
      allow(DRC).to receive(:bput).with('hold my moonblade', anything, anything, anything, anything).and_return('You grab')
      expect(described_class.hold_moon_weapon?).to be true
    end

    it 'tries moonstaff after moonblade fails' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('I could not find')
      allow(DRC).to receive(:bput).with('glance my moonstaff', anything, anything).and_return('You glance at a wicked blue-white moonstaff')
      allow(DRC).to receive(:bput).with('hold my moonstaff', anything, anything, anything, anything).and_return('You grab')
      expect(described_class.hold_moon_weapon?).to be true
    end

    it 'returns false when no moon weapon found' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('I could not find')
      allow(DRC).to receive(:bput).with('glance my moonstaff', anything, anything).and_return('I could not find')
      expect(described_class.hold_moon_weapon?).to be false
    end

    it 'returns false when grab fails' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a wicked black moonblade')
      allow(DRC).to receive(:bput).with('hold my moonblade', anything, anything, anything, anything).and_return("You aren't wearing")
      expect(described_class.hold_moon_weapon?).to be false
    end
  end

  # ================================================================
  # moon_used_to_summon_weapon
  # ================================================================
  describe '.moon_used_to_summon_weapon' do
    it 'returns "katamba" for black moon weapon' do
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a wicked black moonblade')
      expect(described_class.moon_used_to_summon_weapon).to eq('katamba')
    end

    it 'returns "yavash" for red-hot moon weapon' do
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a fiery red-hot moonstaff')
      expect(described_class.moon_used_to_summon_weapon).to eq('yavash')
    end

    it 'returns "xibar" for blue-white moon weapon' do
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a gleaming blue-white moonblade')
      expect(described_class.moon_used_to_summon_weapon).to eq('xibar')
    end

    it 'returns nil when no moon weapon found' do
      allow(DRC).to receive(:bput).and_return('I could not find')
      expect(described_class.moon_used_to_summon_weapon).to be_nil
    end

    it 'checks moonblade before moonstaff' do
      expect(DRC).to receive(:bput).with('glance my moonblade', anything, anything).ordered.and_return('You glance at a wicked black moonblade')
      expect(DRC).not_to receive(:bput).with('glance my moonstaff', anything, anything)
      described_class.moon_used_to_summon_weapon
    end

    it 'falls back to moonstaff when moonblade not found' do
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('I could not find')
      allow(DRC).to receive(:bput).with('glance my moonstaff', anything, anything).and_return('You glance at a wicked black moonstaff')
      expect(described_class.moon_used_to_summon_weapon).to eq('katamba')
    end
  end

  # ================================================================
  # parse_roisaen
  #
  # Converts the spelled-out roisaen count reported by FOCUS into an
  # Integer. A moonblade lasts 12-41 minutes (== roisaen, at 60s each),
  # but near expiry it counts down toward 0, so the full 0-41 range is
  # exercised. An independent word generator (built here, not from the
  # production NUM_MAP) is used as the oracle so the test does not merely
  # mirror the implementation.
  # ================================================================
  describe '.parse_roisaen' do
    # Independent English-number oracle for 0..41, built from definition-time
    # locals (a lambda closure) so it is usable in example descriptions. It is
    # deliberately NOT the production NUM_MAP the method under test relies on,
    # so the test does not merely mirror the implementation.
    ones = %w[zero one two three four five six seven eight nine ten eleven twelve
              thirteen fourteen fifteen sixteen seventeen eighteen nineteen]
    tens = { 20 => 'twenty', 30 => 'thirty', 40 => 'forty' }
    words_for = lambda do |number|
      next ones[number] if number < 20

      ten = (number / 10) * 10
      one = number % 10
      one.zero? ? tens[ten] : "#{tens[ten]}-#{ones[one]}"
    end

    context 'across the full 0-41 duration range' do
      (0..41).each do |minutes|
        words = words_for.call(minutes)
        it "parses \"#{words}\" as #{minutes}" do
          expect(described_class.parse_roisaen(words)).to eq(minutes)
        end
      end
    end

    context 'boundary values' do
      it('parses the minimum documented duration (twelve)') { expect(described_class.parse_roisaen('twelve')).to eq(12) }
      it('parses the maximum documented duration (forty-one)') { expect(described_class.parse_roisaen('forty-one')).to eq(41) }
      it('parses zero (fully expired)') { expect(described_class.parse_roisaen('zero')).to eq(0) }
      it('parses one (singular, about to expire)') { expect(described_class.parse_roisaen('one')).to eq(1) }
    end

    context 'formatting tolerance' do
      it('accepts a space-separated compound') { expect(described_class.parse_roisaen('twenty nine')).to eq(29) }
      it('accepts a hyphen-separated compound') { expect(described_class.parse_roisaen('twenty-nine')).to eq(29) }
      it('is case-insensitive') { expect(described_class.parse_roisaen('Twenty-Nine')).to eq(29) }
      it('is case-insensitive for all-caps') { expect(described_class.parse_roisaen('FORTY-ONE')).to eq(41) }
      it('tolerates surrounding whitespace') { expect(described_class.parse_roisaen('  thirty-five  ')).to eq(35) }
    end

    context 'adversarial / malformed input' do
      it('returns nil for nil') { expect(described_class.parse_roisaen(nil)).to be_nil }
      it('returns nil for an empty string') { expect(described_class.parse_roisaen('')).to be_nil }
      it('returns nil for whitespace only') { expect(described_class.parse_roisaen('   ')).to be_nil }
      it('returns nil for a non-number word') { expect(described_class.parse_roisaen('banana')).to be_nil }
      it('returns nil for the article "a" (unsupported phrasing)') { expect(described_class.parse_roisaen('a')).to be_nil }
      it('returns nil when any word is unknown') { expect(described_class.parse_roisaen('twenty-banana')).to be_nil }
      it('returns nil for digits (game spells numbers out)') { expect(described_class.parse_roisaen('29')).to be_nil }
      it('does not misread a partial word') { expect(described_class.parse_roisaen('twent')).to be_nil }
    end
  end

  # ================================================================
  # moon_weapon_duration
  # ================================================================
  describe '.moon_weapon_duration' do
    # The real call passes: duration regex, expiring regex, then the two
    # not-found strings. The first example asserts the exact pattern list; the
    # rest use any_args so they do not re-encode the pattern count.
    let(:focus_args) { [described_class::MOON_FOCUS_EXPIRING_REGEX, 'I could not find', 'Focus on what'] }

    it 'focuses the moonblade with the exact pattern list and returns its roisaen' do
      allow(DRC).to receive(:bput)
        .with('focus my moonblade', described_class::MOON_FOCUS_DURATION_REGEX, *focus_args)
        .and_return('You judge that the moonblade will last for roughly twenty-nine roisaen.')
      expect(described_class.moon_weapon_duration).to eq(29)
    end

    it 'parses a small plural duration (confirmed "two roisaen")' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args)
                                  .and_return('You judge that the moonblade will last for roughly two roisaen.')
      expect(described_class.moon_weapon_duration).to eq(2)
    end

    it 'parses the maximum duration' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args)
                                  .and_return('You judge that the moonblade will last for roughly forty-one roisaen.')
      expect(described_class.moon_weapon_duration).to eq(41)
    end

    it 'returns 0 for the confirmed near-expiry phrase "less than one roisan"' do
      # Near expiry the game drops "roughly <count>" and reports "less than one
      # roisan" (singular unit); treat as 0 roisaen == expiring now.
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args)
                                  .and_return('You judge that the moonblade will last for less than one roisan.')
      expect(described_class.moon_weapon_duration).to eq(0)
    end

    it 'returns 0 for a defensive plural-unit "less than one roisaen"' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args)
                                  .and_return('You judge that the moonblade will last for less than one roisaen.')
      expect(described_class.moon_weapon_duration).to eq(0)
    end

    it 'distinguishes 0 (expiring now) from nil (no weapon)' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args)
                                  .and_return('You judge that the moonblade will last for less than one roisan.')
      expect(described_class.moon_weapon_duration).to eq(0)
      expect(described_class.moon_weapon_duration).not_to be_nil
    end

    it 'falls back to moonstaff when no moonblade is present' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args).and_return('I could not find')
      allow(DRC).to receive(:bput).with('focus my moonstaff', any_args)
                                  .and_return('You judge that the moonstaff will last for roughly forty roisaen.')
      expect(described_class.moon_weapon_duration).to eq(40)
    end

    it 'reads an expiring moonstaff after no moonblade' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args).and_return('I could not find')
      allow(DRC).to receive(:bput).with('focus my moonstaff', any_args)
                                  .and_return('You judge that the moonstaff will last for less than one roisan.')
      expect(described_class.moon_weapon_duration).to eq(0)
    end

    it 'checks moonblade before moonstaff and stops once found' do
      expect(DRC).to receive(:bput).with('focus my moonblade', any_args).ordered
                                   .and_return('You judge that the moonblade will last for roughly ten roisaen.')
      expect(DRC).not_to receive(:bput).with('focus my moonstaff', any_args)
      described_class.moon_weapon_duration
    end

    it 'returns nil when neither moon weapon is present' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args).and_return('I could not find')
      allow(DRC).to receive(:bput).with('focus my moonstaff', any_args).and_return('I could not find')
      expect(described_class.moon_weapon_duration).to be_nil
    end

    it 'returns nil on the "Focus on what" no-target response' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args).and_return('Focus on what?')
      allow(DRC).to receive(:bput).with('focus my moonstaff', any_args).and_return('Focus on what?')
      expect(described_class.moon_weapon_duration).to be_nil
    end

    it 'returns nil when the roughly-count phrase has an unknown number word' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args)
                                  .and_return('You judge that the moonblade will last for roughly banana roisaen.')
      allow(DRC).to receive(:bput).with('focus my moonstaff', any_args).and_return('I could not find')
      expect(described_class.moon_weapon_duration).to be_nil
    end

    it 'waits out the focus roundtime after a successful count read' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args)
                                  .and_return('You judge that the moonblade will last for roughly fifteen roisaen.')
      expect(described_class).to receive(:waitrt?)
      described_class.moon_weapon_duration
    end

    it 'waits out the focus roundtime on an expiring read' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args)
                                  .and_return('You judge that the moonblade will last for less than one roisan.')
      expect(described_class).to receive(:waitrt?)
      described_class.moon_weapon_duration
    end

    it 'does not wait out roundtime when nothing is focused' do
      allow(DRC).to receive(:bput).with('focus my moonblade', any_args).and_return('I could not find')
      allow(DRC).to receive(:bput).with('focus my moonstaff', any_args).and_return('I could not find')
      expect(described_class).not_to receive(:waitrt?)
      described_class.moon_weapon_duration
    end
  end

  # ================================================================
  # visible_moons
  # ================================================================
  describe '.visible_moons' do
    before do
      allow(described_class).to receive(:check_moonwatch).and_return(true)
    end

    it 'returns moons that are visible and have timer >= threshold' do
      UserVars.moons = {
        'katamba' => { 'timer' => 10 },
        'xibar'   => { 'timer' => 5 },
        'yavash'  => { 'timer' => 2 },
        'visible' => %w[katamba xibar yavash]
      }
      expect(described_class.visible_moons).to contain_exactly('katamba', 'xibar')
    end

    it 'returns empty array when no moons are visible' do
      UserVars.moons = {
        'katamba' => { 'timer' => 0 },
        'visible' => []
      }
      expect(described_class.visible_moons).to be_empty
    end

    it 'excludes moons with timer below threshold' do
      UserVars.moons = {
        'katamba' => { 'timer' => 3 },
        'visible' => ['katamba']
      }
      expect(described_class.visible_moons).to be_empty
    end

    it 'includes moons with timer exactly at threshold' do
      UserVars.moons = {
        'katamba' => { 'timer' => 4 },
        'visible' => ['katamba']
      }
      expect(described_class.visible_moons).to contain_exactly('katamba')
    end

    it 'excludes moons not in visible list even with high timer' do
      UserVars.moons = {
        'katamba' => { 'timer' => 100 },
        'visible' => []
      }
      expect(described_class.visible_moons).to be_empty
    end

    it 'returns empty array when moon data is unavailable, ignoring saved timers' do
      allow(described_class).to receive(:check_moonwatch).and_return(false)
      UserVars.moons = {
        'katamba' => { 'timer' => 100 },
        'visible' => ['katamba'],
        'running' => false
      }
      expect(described_class.visible_moons).to be_empty
      expect(described_class.moons_visible?).to be false
      expect(described_class.moon_visible?('katamba')).to be false
    end
  end

  # ================================================================
  # moon_visible?
  # ================================================================
  describe '.moon_visible?' do
    before do
      allow(described_class).to receive(:check_moonwatch).and_return(true)
      UserVars.moons = {
        'katamba' => { 'timer' => 10 },
        'xibar'   => { 'timer' => 1 },
        'visible' => %w[katamba xibar]
      }
    end

    it 'returns true for visible moon with sufficient timer' do
      expect(described_class.moon_visible?('katamba')).to be true
    end

    it 'returns false for visible moon with low timer' do
      expect(described_class.moon_visible?('xibar')).to be false
    end

    it 'returns false for non-visible moon' do
      expect(described_class.moon_visible?('yavash')).to be false
    end
  end

  # ================================================================
  # moons_visible?
  # ================================================================
  describe '.moons_visible?' do
    before do
      allow(described_class).to receive(:check_moonwatch).and_return(true)
    end

    it 'returns true when at least one moon is visible with sufficient timer' do
      UserVars.moons = {
        'katamba' => { 'timer' => 10 },
        'visible' => ['katamba']
      }
      expect(described_class.moons_visible?).to be true
    end

    it 'returns false when no moons are visible' do
      UserVars.moons = { 'visible' => [] }
      expect(described_class.moons_visible?).to be false
    end

    it 'returns false when all visible moons have low timers' do
      UserVars.moons = {
        'katamba' => { 'timer' => 2 },
        'visible' => ['katamba']
      }
      expect(described_class.moons_visible?).to be false
    end
  end

  # ================================================================
  # bright_celestial_object?
  # ================================================================
  describe '.bright_celestial_object?' do
    before do
      allow(described_class).to receive(:check_moonwatch).and_return(true)
    end

    it 'returns true when sun is up with sufficient timer' do
      UserVars.sun = { 'day' => true, 'timer' => 10 }
      UserVars.moons = { 'visible' => [] }
      expect(described_class.bright_celestial_object?).to be true
    end

    it 'returns true when xibar is visible' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'xibar' => { 'timer' => 10 }, 'visible' => ['xibar'] }
      expect(described_class.bright_celestial_object?).to be true
    end

    it 'returns true when yavash is visible' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'yavash' => { 'timer' => 10 }, 'visible' => ['yavash'] }
      expect(described_class.bright_celestial_object?).to be true
    end

    it 'returns false when only katamba is visible (not bright)' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'katamba' => { 'timer' => 10 }, 'visible' => ['katamba'] }
      expect(described_class.bright_celestial_object?).to be false
    end

    it 'returns false when sun timer is below threshold' do
      UserVars.sun = { 'day' => true, 'timer' => 3 }
      UserVars.moons = { 'visible' => [] }
      expect(described_class.bright_celestial_object?).to be false
    end

    it 'returns false when nothing is visible' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'visible' => [] }
      expect(described_class.bright_celestial_object?).to be false
    end

    it 'returns false when sun is not daytime even with high timer' do
      UserVars.sun = { 'day' => false, 'timer' => 100 }
      UserVars.moons = { 'visible' => [] }
      expect(described_class.bright_celestial_object?).to be false
    end

    it 'returns false when moon data is unavailable, ignoring saved sun and moon data' do
      allow(described_class).to receive(:check_moonwatch).and_return(false)
      UserVars.sun = { 'day' => true, 'timer' => 100, 'running' => false }
      UserVars.moons = { 'xibar' => { 'timer' => 10 }, 'visible' => ['xibar'], 'running' => false }
      expect(described_class.bright_celestial_object?).to be false
      expect(described_class).to have_received(:check_moonwatch).once
    end
  end

  # ================================================================
  # any_celestial_object?
  # ================================================================
  describe '.any_celestial_object?' do
    before do
      allow(described_class).to receive(:check_moonwatch).and_return(true)
    end

    it 'returns true when katamba is visible (unlike bright_celestial_object?)' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'katamba' => { 'timer' => 10 }, 'visible' => ['katamba'] }
      expect(described_class.any_celestial_object?).to be true
    end

    it 'returns true when sun is up' do
      UserVars.sun = { 'day' => true, 'timer' => 10 }
      UserVars.moons = { 'visible' => [] }
      expect(described_class.any_celestial_object?).to be true
    end

    it 'returns false when nothing is visible' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'visible' => [] }
      expect(described_class.any_celestial_object?).to be false
    end

    it 'returns false when moon data is unavailable, ignoring saved sun and moon data' do
      allow(described_class).to receive(:check_moonwatch).and_return(false)
      UserVars.sun = { 'day' => true, 'timer' => 100, 'running' => false }
      UserVars.moons = { 'katamba' => { 'timer' => 10 }, 'visible' => ['katamba'], 'running' => false }
      expect(described_class.any_celestial_object?).to be false
      expect(described_class).to have_received(:check_moonwatch).once
    end
  end

  # ================================================================
  # moon_data_ready?
  # ================================================================
  describe '.moon_data_ready?' do
    let(:ready) do
      {
        'katamba' => { 'timer' => 12 },
        'yavash'  => { 'timer' => 0 },
        'xibar'   => { 'timer' => 37.5 },
        'visible' => ['katamba']
      }
    end

    it 'is true when every moon has a numeric timer and visible is a list' do
      UserVars.moons = ready
      expect(described_class.moon_data_ready?).to be true
    end

    it "is true when moonwatch's extra 'running' key is present" do
      UserVars.moons = ready.merge('running' => true)
      expect(described_class.moon_data_ready?).to be true
    end

    it 'is false for an empty hash' do
      UserVars.moons = {}
      expect(described_class.moon_data_ready?).to be false
    end

    it 'is false when UserVars.moons is nil' do
      UserVars.moons = nil
      expect(described_class.moon_data_ready?).to be false
    end

    it 'is false when moonwatch marked the data as stale on exit' do
      UserVars.moons = ready.merge('running' => false)
      expect(described_class.moon_data_ready?).to be false
    end

    it "is false for moonwatch's startup skeleton" do
      UserVars.moons = { 'katamba' => {}, 'yavash' => {}, 'xibar' => {}, 'visible' => [] }
      expect(described_class.moon_data_ready?).to be false
    end

    it 'is false while only some moons have timers' do
      UserVars.moons = ready.merge('xibar' => {})
      expect(described_class.moon_data_ready?).to be false
    end

    it 'is false when a moon is missing' do
      UserVars.moons = ready.reject { |name, _| name == 'yavash' }
      expect(described_class.moon_data_ready?).to be false
    end

    it 'is false when a timer is not numeric' do
      UserVars.moons = ready.merge('katamba' => { 'timer' => '12' })
      expect(described_class.moon_data_ready?).to be false
    end

    it 'is false when visible is missing' do
      UserVars.moons = ready.reject { |name, _| name == 'visible' }
      expect(described_class.moon_data_ready?).to be false
    end

    it 'is false when a moon entry is not a hash' do
      UserVars.moons = ready.merge('yavash' => 12)
      expect(described_class.moon_data_ready?).to be false
    end

    context 'with the sun data' do
      let(:running_moons) { ready.merge('running' => true) }

      it 'is false while moonwatch has marked the sun running but not yet written it' do
        UserVars.moons = running_moons
        UserVars.sun = { 'running' => true }
        expect(described_class.moon_data_ready?).to be false
      end

      it "is false while moonwatch has written the sun's 'day' but not yet its 'timer'" do
        UserVars.moons = running_moons
        UserVars.sun = { 'running' => true, 'day' => false, 'night' => true, 'visible' => false }
        expect(described_class.moon_data_ready?).to be false
      end

      it 'is false when the sun timer is not numeric' do
        UserVars.moons = running_moons
        UserVars.sun = { 'running' => true, 'day' => true, 'timer' => '120' }
        expect(described_class.moon_data_ready?).to be false
      end

      it 'is true once moonwatch has written the sun timer, by night as by day' do
        UserVars.moons = running_moons
        [true, false].each do |day|
          UserVars.sun = { 'running' => true, 'day' => day, 'night' => !day, 'timer' => 0 }
          expect(described_class.moon_data_ready?).to be true
        end
      end

      it "does not check sun data without a 'running' key (older moonwatch versions)" do
        UserVars.moons = ready
        [{}, { 'day' => true }, nil].each do |sun|
          UserVars.sun = sun
          expect(described_class.moon_data_ready?).to be true
        end
      end

      it 'is false over a ready sun when the moons are not ready' do
        UserVars.moons = running_moons.merge('xibar' => {})
        UserVars.sun = { 'running' => true, 'day' => true, 'timer' => 120 }
        expect(described_class.moon_data_ready?).to be false
      end
    end
  end

  # ================================================================
  # check_moonwatch
  # ================================================================
  describe '.check_moonwatch' do
    let(:skeleton) { { 'katamba' => {}, 'yavash' => {}, 'xibar' => {}, 'visible' => [] } }
    let(:ready_moons) do
      {
        'katamba' => { 'timer' => 30 },
        'yavash'  => { 'timer' => 12 },
        'xibar'   => { 'timer' => 90 },
        'visible' => %w[katamba yavash],
        'running' => true
      }
    end
    # Shared, thread-visible state of the fake moonwatch.
    let(:world) { { running: false, polls: 0, on_poll: nil } }

    after do
      described_class.instance_variable_set(:@moonwatch_data_stalled, false)
      described_class.instance_variable_set(:@moonwatch_restart_blocked_until, nil)
    end

    def bold_messages
      Lich::Messaging.messages.select { |m| m[:type] == 'bold' }.map { |m| m[:message] }
    end

    # Fails the example (instead of hanging the suite) if check_moonwatch never returns.
    def check(**kwargs)
      Timeout.timeout(5) { described_class.check_moonwatch(**kwargs) }
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # Waits for another thread to signal on queue. Fails the example (instead
    # of hanging the suite) if the signal never comes.
    def await_signal(queue)
      Timeout.timeout(5) { queue.pop }
    end

    # Holds MOONWATCH_START_LOCK in another thread until release is popped,
    # as a start in progress elsewhere would. Returns once the lock is held.
    def hold_start_lock(release)
      locked = Queue.new
      holder = Thread.new do
        described_class::MOONWATCH_START_LOCK.synchronize do
          locked << true
          release.pop
        end
      end
      await_signal(locked)
      holder
    end

    before do
      described_class.instance_variable_set(:@moonwatch_data_stalled, false)
      described_class.instance_variable_set(:@moonwatch_restart_blocked_until, nil)
      stub_const("#{described_class}::MOONWATCH_READY_TIMEOUT", 0.3)
      allow(Script).to receive(:running?).with('moonwatch') { world[:running] }
      allow(Script).to receive(:exists?).with('moonwatch').and_return(true)
      allow(Script).to receive(:version).with('moonwatch').and_return(Gem::Version.new('1.0.0'))
      allow(described_class).to receive(:pause) do |*_args|
        sleep 0.002
        world[:polls] += 1
        world[:on_poll]&.call(world[:polls])
      end
    end

    context 'when moonwatch is already running with real moon data' do
      before do
        world[:running] = true
        UserVars.moons = ready_moons
      end

      it 'returns true at once without logging any messages' do
        expect(check).to be true
        expect(Lich::Messaging.messages).to be_empty
        expect(world[:polls]).to eq(0)
      end

      it 'does not call start_script' do
        expect(described_class).not_to receive(:start_script)
        check
      end
    end

    context 'when moonwatch was started elsewhere and is still starting up' do
      let(:stalled_message) { "Not waiting for moonwatch's moon data again" }

      before do
        world[:running] = true
        allow(described_class).to receive(:start_script) { raise 'check_moonwatch must not start a running moonwatch' }
      end

      it 'waits for the timers instead of returning over the skeleton' do
        UserVars.moons = skeleton.dup
        world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 3 }
        result = check
        expect(world[:polls]).to be >= 3
        expect(described_class.moon_data_ready?).to be true
        expect(result).to be true
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'does not accept saved timers that the previous moonwatch marked as stale on exit' do
        UserVars.moons = ready_moons.merge('katamba' => { 'timer' => 999 }, 'running' => false)
        world[:on_poll] = lambda do |n|
          UserVars.moons = skeleton.merge('running' => true) if n == 2
          UserVars.moons = ready_moons if n >= 4
        end
        result = check
        expect(world[:polls]).to be >= 4
        expect(UserVars.moons).to eq(ready_moons)
        expect(result).to be true
      end

      it 'waits for the sun when moonwatch has published the moons but not yet the sun' do
        UserVars.moons = ready_moons
        UserVars.sun = { 'running' => true }
        world[:on_poll] = lambda do |n|
          UserVars.sun = { 'running' => true, 'day' => true, 'night' => false, 'timer' => 120 } if n >= 2
        end
        result = check
        expect(world[:polls]).to be >= 2
        expect(result).to be true
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'lets bright_celestial_object? see a sun published just after the moons' do
        UserVars.moons = ready_moons.merge('visible' => [])
        UserVars.sun = { 'running' => true }
        world[:on_poll] = lambda do |n|
          UserVars.sun = { 'running' => true, 'day' => true, 'night' => false, 'timer' => 120 } if n >= 1
        end
        expect(Timeout.timeout(5) { described_class.bright_celestial_object? }).to be true
      end

      it 'returns false promptly when moonwatch stops before publishing, and does not latch' do
        UserVars.moons = skeleton.dup
        world[:on_poll] = ->(n) { world[:running] = false if n >= 2 }
        started = monotonic
        expect(check(timeout: 4)).to be false
        expect(monotonic - started).to be < 2
        expect(bold_messages.last).to include('moonwatch stopped before its moon data was ready')
        expect(Lich::Messaging.messages.map { |m| m[:message] }.join).not_to include(stalled_message)
      end

      it 'does not claim moonwatch never published when it stops while shutting down' do
        UserVars.moons = ready_moons.merge('running' => false)
        world[:on_poll] = ->(n) { world[:running] = false if n >= 2 }
        expect(check).to be false
        expect(bold_messages.last).to include("moonwatch stopped before its moon data was ready")
        expect(bold_messages.join).not_to include('before it published')
      end

      it 'leaves no moon or sun for the readers when it stops with the saved data marked stale' do
        UserVars.moons = ready_moons.merge('running' => false)
        UserVars.sun = { 'day' => true, 'night' => false, 'timer' => 120, 'running' => false }
        world[:on_poll] = ->(n) { world[:running] = false if n >= 1 }
        visible = Timeout.timeout(5) { described_class.visible_moons }
        expect(bold_messages.last).to include('moonwatch stopped before its moon data was ready')
        expect(visible).to eq([])

        %i[bright_celestial_object? any_celestial_object?].each do |reader|
          world[:running] = true
          world[:polls] = 0
          expect(Timeout.timeout(5) { described_class.public_send(reader) }).to be false
        end
      end

      it 'times out once when the data never becomes ready, then returns false at once on later calls' do
        UserVars.moons = skeleton.dup
        expect(check).to be false
        expect(bold_messages.last).to include('moonwatch did not publish moon data within 0.3 seconds')
        expect(Lich::Messaging.messages.last[:message]).to include(stalled_message)

        Lich::Messaging.clear_messages!
        world[:polls] = 0
        started = monotonic
        2.times { expect(check).to be false }
        expect(monotonic - started).to be < 0.2
        expect(world[:polls]).to eq(0)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'waits again after a stall once the data has been ready' do
        UserVars.moons = skeleton.dup
        expect(check).to be false
        UserVars.moons = ready_moons
        expect(check).to be true

        UserVars.moons = skeleton.dup
        world[:polls] = 0
        world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 2 }
        expect(check).to be true
        expect(world[:polls]).to be >= 2
      end

      it 'waits again after a stall once moonwatch has been seen stopped' do
        UserVars.moons = skeleton.dup
        expect(check).to be false

        world[:running] = false
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        allow(Script).to receive(:exists?).with('moonwatch').and_return(false)
        allow(Script).to receive(:version).with('moonwatch').and_return(nil)
        expect(check).to be false # missing: fails at once, and clears the latch

        world[:running] = true
        UserVars.moons = skeleton.dup
        world[:polls] = 0
        world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 2 }
        expect(check).to be true
        expect(world[:polls]).to be >= 2
      end
    end

    context 'when moonwatch is not running and starts normally' do
      before do
        allow(described_class).to receive(:start_script).with('moonwatch') do
          world[:running] = true
          UserVars.moons = skeleton.dup
          world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 3 }
          Object.new
        end
      end

      it 'returns true only after a real moon timer exists, not at the skeleton write' do
        result = check
        expect(world[:polls]).to be >= 3
        expect(described_class.moon_data_ready?).to be true
        expect(result).to be true
      end

      it "returns true only after the sun is published too, in moonwatch's startup order" do
        sun = { 'running' => true, 'day' => false, 'night' => true, 'visible' => false, 'timer' => 45 }
        allow(described_class).to receive(:start_script).with('moonwatch') do
          world[:running] = true
          UserVars.moons = skeleton.merge('running' => true)
          UserVars.sun = { 'running' => true }
          world[:on_poll] = lambda do |n|
            UserVars.moons = ready_moons if n >= 2
            UserVars.sun = sun if n >= 4
          end
          Object.new
        end
        result = check
        expect(world[:polls]).to be >= 4
        expect(UserVars.sun).to eq(sun)
        expect(result).to be true
      end

      it 'logs the starting message and the autostart hint' do
        check
        expect(bold_messages.first).to include('DRCMM: moonwatch is not running')
        plain = Lich::Messaging.messages.select { |m| m[:type] == 'plain' }.map { |m| m[:message] }
        expect(plain.first).to include(";e autostart('moonwatch')")
      end

      it 'clears the saved moon data before starting moonwatch' do
        UserVars.moons = ready_moons.merge('katamba' => { 'timer' => 999 })
        seen_at_start = nil
        allow(described_class).to receive(:start_script).with('moonwatch') do
          seen_at_start = UserVars.moons.dup
          world[:running] = true
          UserVars.moons = ready_moons
          Object.new
        end
        expect(check).to be true
        expect(seen_at_start).to eq({})
      end

      it 'clears the saved sun data before starting moonwatch' do
        UserVars.sun = { 'day' => true, 'night' => false, 'timer' => 120, 'running' => false }
        seen_at_start = nil
        allow(described_class).to receive(:start_script).with('moonwatch') do
          seen_at_start = UserVars.sun.dup
          world[:running] = true
          UserVars.moons = ready_moons
          Object.new
        end
        expect(check).to be true
        expect(seen_at_start).to eq({})
      end

      it 'does not count stale saved timers as ready while moonwatch has not published' do
        UserVars.moons = ready_moons
        allow(described_class).to receive(:start_script).with('moonwatch') do
          world[:running] = true
          world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 2 }
          Object.new
        end
        result = check
        expect(world[:polls]).to be >= 2
        expect(result).to be true
      end

      it 'waits out a slow start: the deadline starts after start_script returns' do
        allow(described_class).to receive(:start_script).with('moonwatch') do
          sleep 0.5 # longer than the 0.3 s timeout; Script.new reads the file in the caller
          world[:running] = true
          world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 2 }
          Object.new
        end
        expect(check).to be true
        expect(bold_messages.grep(/unavailable/)).to be_empty
      end
    end

    context 'when moonwatch fails to start or exits early' do
      it 'fails fast when moonwatch cannot be found, without restoring the saved data' do
        UserVars.moons = ready_moons
        allow(Script).to receive(:exists?).with('moonwatch').and_return(false)
        allow(Script).to receive(:version).with('moonwatch').and_return(nil)
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        stub_const("#{described_class}::MOONWATCH_READY_TIMEOUT", 5)
        result = check
        expect(world[:polls]).to eq(0)
        expect(bold_messages.last).to include('moonwatch could not be found')
        expect(UserVars.moons).to eq({})
        expect(result).to be false
      end

      it 'leaves no saved sun data for the celestial checks to trust when moonwatch cannot be found' do
        UserVars.moons = ready_moons
        UserVars.sun = { 'day' => true, 'night' => false, 'timer' => 120, 'running' => false }
        allow(Script).to receive(:exists?).with('moonwatch').and_return(false)
        allow(Script).to receive(:version).with('moonwatch').and_return(nil)
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        result = Timeout.timeout(5) do
          [described_class.bright_celestial_object?, described_class.any_celestial_object?, described_class.visible_moons]
        end
        expect(UserVars.sun).to eq({})
        expect(result).to eq([false, false, []])
      end

      it 'treats a malformed version header as a found script (no false "could not be found")' do
        allow(Script).to receive(:exists?).with('moonwatch').and_return(false)
        allow(Script).to receive(:version).with('moonwatch').and_raise(ArgumentError, 'Malformed version number string 1.0 beta')
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        expect(check).to be false
        expect(bold_messages.grep(/could not be found/)).to be_empty
        expect(bold_messages.last).to include('moonwatch did not start within 0.3 seconds')
      end

      it 'gives up at the deadline when start_script returns nil and moonwatch never runs' do
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        started = monotonic
        expect(check).to be false
        expect(monotonic - started).to be >= 0.3
        expect(bold_messages.last).to include('moonwatch did not start within 0.3 seconds')
        expect(UserVars.moons).to eq({})
      end

      it 'returns promptly when moonwatch dies before publishing, long before the deadline' do
        allow(described_class).to receive(:start_script).with('moonwatch') do
          world[:running] = true
          world[:on_poll] = ->(n) { world[:running] = false if n >= 2 }
          Object.new
        end
        stub_const("#{described_class}::MOONWATCH_READY_TIMEOUT", 4)
        started = monotonic
        result = check
        expect(monotonic - started).to be < 2
        expect(bold_messages.last).to include('moonwatch stopped before its moon data was ready')
        expect(result).to be false
      end

      it 'returns false when moonwatch dies after its skeleton write but before any timer' do
        allow(described_class).to receive(:start_script).with('moonwatch') do
          world[:running] = true
          UserVars.moons = skeleton.dup
          world[:on_poll] = ->(n) { world[:running] = false if n >= 2 }
          Object.new
        end
        result = check
        expect(bold_messages.last).to include('moonwatch stopped before its moon data was ready')
        expect(result).to be false
      end

      it 'gives up at the deadline when moonwatch runs but never publishes a timer' do
        allow(described_class).to receive(:start_script).with('moonwatch') do
          world[:running] = true
          UserVars.moons = skeleton.dup
          Object.new
        end
        result = check
        expect(bold_messages.last).to include('moonwatch did not publish moon data within 0.3 seconds')
        expect(UserVars.moons).to eq(skeleton)
        expect(result).to be false
      end

      it 'does not wait again on the next call after moonwatch it started never publishes' do
        allow(described_class).to receive(:start_script).with('moonwatch') do
          world[:running] = true
          UserVars.moons = skeleton.dup
          Object.new
        end
        expect(check).to be false
        expect(Lich::Messaging.messages.last[:message]).to include("Not waiting for moonwatch's moon data again")

        Lich::Messaging.clear_messages!
        world[:polls] = 0
        started = monotonic
        2.times { expect(check).to be false }
        expect(monotonic - started).to be < 0.2
        expect(world[:polls]).to eq(0)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'does not latch when the moonwatch it started is not running at the deadline' do
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        expect(check).to be false
        expect(Lich::Messaging.messages.map { |m| m[:message] }.join).not_to include("Not waiting for moonwatch's moon data again")

        world[:running] = true
        UserVars.moons = skeleton.dup
        world[:polls] = 0
        world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 2 }
        expect(check).to be true
        expect(world[:polls]).to be >= 2
      end

      it 'releases the start lock when start_script raises' do
        allow(described_class).to receive(:start_script).with('moonwatch').and_raise(RuntimeError, 'boom')
        expect { check }.to raise_error(RuntimeError, 'boom')
        expect(described_class::MOONWATCH_START_LOCK).not_to be_locked
      end
    end

    context 'after its own start of moonwatch fails (restart cooldown)' do
      let(:cooldown_message) { 'Not starting moonwatch again for' }
      let(:crashing_start) do
        lambda do
          world[:running] = true
          world[:on_poll] = ->(n) { world[:running] = false if n >= 1 }
          Object.new
        end
      end

      def all_messages
        Lich::Messaging.messages.map { |m| m[:message] }
      end

      it 'does not restart a moonwatch that crashed at startup on the next calls' do
        starts = 0
        allow(described_class).to receive(:start_script).with('moonwatch') do
          starts += 1
          crashing_start.call
        end
        expect(check).to be false
        expect(bold_messages.last).to include('moonwatch stopped before its moon data was ready')
        expect(all_messages.last).to include("#{cooldown_message} 60 seconds")

        Lich::Messaging.clear_messages!
        world[:polls] = 0
        started = monotonic
        3.times { expect(check).to be false }
        expect(monotonic - started).to be < 0.2
        expect(starts).to eq(1)
        expect(world[:polls]).to eq(0)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'starts a crashing moonwatch once per bright_celestial_object? call, not once per moon looked at' do
        starts = 0
        allow(described_class).to receive(:start_script).with('moonwatch') do
          starts += 1
          crashing_start.call
        end
        UserVars.sun = { 'day' => true, 'timer' => 120, 'running' => false }
        expect(Timeout.timeout(5) { described_class.bright_celestial_object? }).to be false
        expect(Timeout.timeout(5) { described_class.any_celestial_object? }).to be false
        expect(starts).to eq(1)
        expect(bold_messages.grep(/not running/).size).to eq(1)
        expect(all_messages.grep(/#{cooldown_message}/).size).to eq(1)
      end

      it 'does not look for a missing moonwatch again on the next calls' do
        allow(Script).to receive(:exists?).with('moonwatch').and_return(false)
        allow(Script).to receive(:version).with('moonwatch').and_return(nil)
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        expect(check).to be false
        expect(bold_messages.last).to include('moonwatch could not be found')
        expect(all_messages.last).to include(cooldown_message)

        Lich::Messaging.clear_messages!
        2.times { expect(check).to be false }
        expect(described_class).to have_received(:start_script).once
        expect(Script).to have_received(:version).once
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'does not wait out the deadline again after a start that never showed moonwatch running' do
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        expect(check).to be false
        expect(bold_messages.last).to include('moonwatch did not start within 0.3 seconds')
        expect(all_messages.last).to include(cooldown_message)

        world[:polls] = 0
        started = monotonic
        expect(check).to be false
        expect(monotonic - started).to be < 0.2
        expect(world[:polls]).to eq(0)
        expect(described_class).to have_received(:start_script).once
      end

      it 'starts moonwatch again once the cooldown has passed' do
        stub_const("#{described_class}::MOONWATCH_RESTART_COOLDOWN", 0.2)
        starts = 0
        allow(described_class).to receive(:start_script).with('moonwatch') do
          starts += 1
          next crashing_start.call if starts == 1

          world[:running] = true
          world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 1 }
          Object.new
        end
        expect(check).to be false
        expect(all_messages.last).to include("#{cooldown_message} 0.2 seconds")
        expect(check).to be false
        expect(starts).to eq(1)

        sleep 0.25
        expect(check).to be true
        expect(starts).to eq(2)
        expect(described_class.instance_variable_get(:@moonwatch_restart_blocked_until)).to be_nil
      end

      it 'still uses a moonwatch started some other way during the cooldown, waiting for its data' do
        allow(described_class).to receive(:start_script).with('moonwatch') { crashing_start.call }
        expect(check).to be false

        world[:running] = true
        UserVars.moons = skeleton.dup
        world[:polls] = 0
        world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 2 }
        expect(check).to be true
        expect(world[:polls]).to be >= 2
        expect(described_class).to have_received(:start_script).once
      end

      it 'clears the cooldown once moonwatch has been seen with real data, so a later stop is restarted at once' do
        starts = 0
        allow(described_class).to receive(:start_script).with('moonwatch') do
          starts += 1
          next crashing_start.call if starts == 1

          world[:running] = true
          world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 1 }
          Object.new
        end
        expect(check).to be false

        world[:running] = true # started elsewhere, and it publishes
        world[:on_poll] = nil
        UserVars.moons = ready_moons
        expect(check).to be true

        world[:running] = false # then it stops, well within the 60 s cooldown
        expect(check).to be true
        expect(starts).to eq(2)
      end

      it 'does not start moonwatch from a caller queued on the lock behind a start that crashed' do
        starts = 0
        in_start = Queue.new
        go = Queue.new
        allow(described_class).to receive(:start_script).with('moonwatch') do
          starts += 1
          in_start << true
          go.pop # the second caller queues on the lock meanwhile
          crashing_start.call
        end
        queued = Queue.new
        world[:on_poll] = ->(_n) { queued << true } # only the second caller polls before go
        results = {}
        threads = []
        begin
          threads << Thread.new { results[:first] = described_class.check_moonwatch }
          await_signal(in_start)
          threads << Thread.new { results[:second] = described_class.check_moonwatch }
          await_signal(queued)
          go << true
          threads.each { |t| expect(t.join(5)).not_to be_nil }
        ensure
          threads.each(&:kill)
        end

        expect(results).to eq(first: false, second: false)
        expect(starts).to eq(1)
        expect(bold_messages.grep(/not running/).size).to eq(1)
      end

      it 'clears data a moonwatch started some other way left behind when it stopped during the cooldown' do
        allow(described_class).to receive(:start_script).with('moonwatch') { crashing_start.call }
        expect(check).to be false

        # Meanwhile moonwatch ran elsewhere, unseen by any check, and exited,
        # leaving its last timers marked stale.
        UserVars.moons = ready_moons.merge('running' => false)
        UserVars.sun = { 'day' => true, 'night' => false, 'timer' => 120, 'running' => false }
        result = Timeout.timeout(5) do
          [described_class.visible_moons, described_class.bright_celestial_object?, described_class.any_celestial_object?]
        end
        expect(result).to eq([[], false, false])
        expect(UserVars.moons).to eq({})
        expect(UserVars.sun).to eq({})
        expect(described_class).to have_received(:start_script).once
      end

      it 'does not apply to a started moonwatch that keeps running without publishing' do
        starts = 0
        allow(described_class).to receive(:start_script).with('moonwatch') do
          starts += 1
          world[:running] = true
          UserVars.moons = skeleton.dup
          Object.new
        end
        expect(check).to be false
        expect(all_messages.grep(/#{cooldown_message}/)).to be_empty

        world[:running] = false # then it stops: the next call starts it again
        expect(check).to be false
        expect(starts).to eq(2)
      end
    end

    context 'when another start of moonwatch is in progress' do
      it 'treats a nil start_script as a duplicate start and waits for that start to publish' do
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        world[:on_poll] = lambda do |n|
          world[:running] = true if n >= 3
          UserVars.moons = ready_moons if n >= 5
        end
        expect(check).to be true
        expect(bold_messages.grep(/could not be found|unavailable/)).to be_empty
      end

      it 'waits on the deadline, not on Script.exists?, when moonwatch shows up running after a nil start' do
        allow(Script).to receive(:exists?).with('moonwatch').and_return(false)
        allow(described_class).to receive(:start_script).with('moonwatch') do
          world[:running] = true # published by the other starter meanwhile
          nil
        end
        world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 2 }
        expect(check).to be true
      end

      it 'waits for a duplicate start of a custom/<subdir>/ moonwatch that Script.exists? cannot see' do
        # Script.start resolves custom/<subdir>/ scripts; Script.exists? does
        # not, but Script.version does (it shares Script.start's resolver).
        allow(Script).to receive(:exists?).with('moonwatch').and_return(false)
        allow(described_class).to receive(:start_script).with('moonwatch').and_return(nil)
        world[:on_poll] = lambda do |n|
          world[:running] = true if n >= 2
          UserVars.moons = ready_moons if n >= 4
        end
        expect(check).to be true
        expect(bold_messages.grep(/could not be found|unavailable/)).to be_empty
      end

      it 'serializes concurrent callers: one start, no wiped data, both see real moon data' do
        stub_const("#{described_class}::MOONWATCH_READY_TIMEOUT", 2)
        start_calls = Queue.new
        in_start = Queue.new
        go = Queue.new
        starting = Mutex.new
        claimed = false
        allow(described_class).to receive(:start_script).with('moonwatch') do
          start_calls << :called
          # Emulates Lich's Script.start: a start while another same-name start
          # is in progress (or the script is running) returns nil; otherwise
          # the script file is read in the caller, is published (running) before
          # start returns, then its own thread writes the skeleton and, a
          # moment later, the timers.
          first = starting.synchronize { claimed ? false : (claimed = true) }
          next nil unless first

          in_start << true
          go.pop # the second caller queues on the lock meanwhile
          world[:running] = true
          Thread.new do
            sleep 0.03
            UserVars.moons = skeleton.dup
            sleep 0.05
            UserVars.moons = ready_moons
          end
          Object.new
        end

        queued = Queue.new
        world[:on_poll] = ->(_n) { queued << true } # only the second caller polls before go
        results = {}
        threads = []
        begin
          threads << Thread.new { results[:first] = [described_class.check_moonwatch, UserVars.moons == ready_moons] }
          await_signal(in_start)
          threads << Thread.new { results[:second] = [described_class.check_moonwatch, UserVars.moons == ready_moons] }
          await_signal(queued)
          go << true
          threads.each { |t| expect(t.join(5)).not_to be_nil }
        ensure
          threads.each(&:kill)
        end

        expect(results.transform_values(&:last)).to eq(first: true, second: true)
        expect(start_calls.size).to eq(1)
        expect(results.transform_values(&:first)).to eq(first: true, second: true)
        expect(bold_messages.grep(/not running/).size).to eq(1)
        expect(UserVars.moons).to eq(ready_moons)
      end

      it 'returns at once when another start is in progress but the data is already ready' do
        world[:running] = true
        UserVars.moons = ready_moons
        release = Queue.new
        holder = hold_start_lock(release)
        begin
          started = monotonic
          expect(check(timeout: 2)).to be true
          expect(monotonic - started).to be < 0.3
          expect(described_class::MOONWATCH_START_LOCK).to be_locked
        ensure
          release << :go
          holder.join
        end
      end

      it 'keeps waiting while another start holds the lock and moonwatch has only written its skeleton' do
        world[:running] = true
        UserVars.moons = skeleton.dup
        world[:on_poll] = ->(n) { UserVars.moons = ready_moons if n >= 3 }
        release = Queue.new
        holder = hold_start_lock(release)
        begin
          expect(described_class).not_to receive(:start_script)
          result = check(timeout: 2)
          expect(world[:polls]).to be >= 3
          expect(described_class.moon_data_ready?).to be true
          expect(result).to be true
          expect(Lich::Messaging.messages).to be_empty
        ensure
          release << :go
          holder.join
        end
      end

      it 'returns true once the other start publishes, even while its holder still holds the lock' do
        # e.g. the holder's script is paused inside start_script or the wait.
        world[:on_poll] = lambda do |n|
          world[:running] = true if n >= 2
          UserVars.moons = skeleton.dup if n == 3
          UserVars.moons = ready_moons if n >= 5
        end
        release = Queue.new
        holder = hold_start_lock(release)
        begin
          expect(described_class).not_to receive(:start_script)
          started = monotonic
          result = check(timeout: 2)
          expect(monotonic - started).to be < 1
          expect(result).to be true
          expect(bold_messages).to be_empty
        ensure
          release << :go
          holder.join
        end
      end

      it 'returns false at once when it waits for the lock after a wait on the running moonwatch stalled' do
        world[:running] = true
        UserVars.moons = skeleton.dup
        expect(check).to be false # times out and latches the stall
        Lich::Messaging.clear_messages!
        world[:polls] = 0
        release = Queue.new
        holder = hold_start_lock(release)
        begin
          expect(described_class).not_to receive(:start_script)
          started = monotonic
          expect(check(timeout: 2)).to be false
          expect(monotonic - started).to be < 0.2
          expect(world[:polls]).to eq(0)
          expect(Lich::Messaging.messages).to be_empty
        ensure
          release << :go
          holder.join
        end
      end

      it 'does not wait again when it gets the lock just after the holder\'s wait stalled' do
        world[:running] = true
        UserVars.moons = skeleton.dup
        release = Queue.new
        holder = hold_start_lock(release)
        # On the second poll the holder's wait times out (latching the stall)
        # and it releases the lock before this caller looks at the latch.
        world[:on_poll] = lambda do |n|
          next unless n == 2

          described_class.instance_variable_set(:@moonwatch_data_stalled, true)
          release << :go
          holder.join
        end
        begin
          expect(described_class).not_to receive(:start_script)
          expect(check(timeout: 2)).to be false
          expect(world[:polls]).to eq(2)
          expect(Lich::Messaging.messages).to be_empty
          expect(described_class::MOONWATCH_START_LOCK).not_to be_locked
        ensure
          release << :go
          holder.join
        end
      end

      it 'returns true and clears the latch when moonwatch publishes after the holder\'s wait stalled but before it gets the lock' do
        world[:running] = true
        UserVars.moons = skeleton.dup
        release = Queue.new
        holder = hold_start_lock(release)
        # On the second poll the holder's wait times out (latching the stall),
        # moonwatch then publishes, and the holder releases the lock; this
        # caller's next try_lock succeeds before it looks at the data again.
        world[:on_poll] = lambda do |n|
          next unless n == 2

          described_class.instance_variable_set(:@moonwatch_data_stalled, true)
          UserVars.moons = ready_moons
          release << :go
          holder.join
        end
        begin
          expect(described_class).not_to receive(:start_script)
          expect(check(timeout: 2)).to be true
          expect(world[:polls]).to eq(2)
          expect(described_class.instance_variable_get(:@moonwatch_data_stalled)).to be false
          expect(Lich::Messaging.messages).to be_empty
          expect(described_class::MOONWATCH_START_LOCK).not_to be_locked
        ensure
          release << :go
          holder.join
        end
      end

      it 'clears the stall latch before it starts moonwatch when moonwatch stopped while it waited for the lock' do
        world[:running] = true
        UserVars.moons = skeleton.dup
        expect(check).to be false # times out and latches the stall
        release = Queue.new
        holder = hold_start_lock(release)
        # Running (and latched) when the call begins, so it queues on the
        # lock; moonwatch has stopped by the time it next looks.
        running_calls = 0
        world[:running] = false
        allow(Script).to receive(:running?).with('moonwatch') do
          running_calls += 1
          running_calls == 1 || world[:running]
        end
        world[:on_poll] = lambda do |_n|
          release << :go
          holder.join
        end
        latch_at_start = nil
        allow(described_class).to receive(:start_script).with('moonwatch') do
          latch_at_start = described_class.instance_variable_get(:@moonwatch_data_stalled)
          world[:running] = true
          UserVars.moons = ready_moons
          Object.new
        end
        begin
          expect(check(timeout: 2)).to be true
          expect(latch_at_start).to be false
        ensure
          release << :go
          holder.join
        end
      end

      it 'reports one timeout when a second caller arrives while the started moonwatch never publishes' do
        allow(described_class).to receive(:start_script).with('moonwatch') do
          world[:running] = true
          UserVars.moons = skeleton.dup
          Object.new
        end
        first_polling = Queue.new
        world[:on_poll] = ->(n) { first_polling << true if n == 1 }
        results = {}
        threads = []
        begin
          threads << Thread.new { results[:first] = [described_class.check_moonwatch, monotonic] }
          await_signal(first_polling) # the first caller holds the lock and is waiting for the data
          # A longer timeout for the second caller, so only the first caller's
          # stall (not the second's own deadline) can end its wait.
          threads << Thread.new { results[:second] = [described_class.check_moonwatch(timeout: 2), monotonic] }
          threads.each { |t| expect(t.join(5)).not_to be_nil }
        ensure
          threads.each(&:kill)
        end

        expect(results.transform_values(&:first)).to eq(first: false, second: false)
        expect(results[:second].last - results[:first].last).to be < 0.15
        expect(bold_messages.grep(/did not publish/).size).to eq(1)
        expect(bold_messages.grep(/Timed out waiting for another start/)).to be_empty
        expect(Lich::Messaging.messages.map { |m| m[:message] }.grep(/Not waiting for moonwatch/).size).to eq(1)
      end

      it 'times out, without starting moonwatch, when another start never finishes' do
        release = Queue.new
        world[:running] = false
        holder = hold_start_lock(release)
        begin
          expect(described_class).not_to receive(:start_script)
          expect(check(timeout: 0.1)).to be false
          expect(bold_messages.last).to include('Timed out waiting for another start of moonwatch')
        ensure
          release << :go
          holder.join
        end
      end
    end
  end

  # ================================================================
  # set_moon_data
  # ================================================================
  describe '.set_moon_data' do
    before do
      allow(described_class).to receive(:check_moonwatch).and_return(true)
    end

    context 'when data has no moon key' do
      it 'returns data unchanged' do
        data = { 'stats' => ['wisdom'] }
        expect(described_class.set_moon_data(data)).to eq(data)
      end
    end

    context 'when a moon is visible' do
      it 'sets cast to the first visible moon' do
        UserVars.moons = { 'katamba' => { 'timer' => 10 }, 'visible' => ['katamba'] }
        data = { 'moon' => true, 'name' => 'Moongate' }
        result = described_class.set_moon_data(data)
        expect(result['cast']).to eq('cast katamba')
      end
    end

    context 'when no moon is visible' do
      before do
        UserVars.moons = { 'visible' => [] }
      end

      it 'sets cast to "cast ambient" for Cage of Light' do
        data = { 'moon' => true, 'name' => 'Cage of Light' }
        result = described_class.set_moon_data(data)
        expect(result['cast']).to eq('cast ambient')
      end

      it 'sets cast to "cast ambient" for cage of light (case insensitive)' do
        data = { 'moon' => true, 'name' => 'CAGE OF LIGHT' }
        result = described_class.set_moon_data(data)
        expect(result['cast']).to eq('cast ambient')
      end

      it 'returns nil for other spells when no moon available' do
        data = { 'moon' => true, 'name' => 'Moongate' }
        result = described_class.set_moon_data(data)
        expect(result).to be_nil
      end

      it 'sends a bold DRCMM-prefixed message when no moon available for non-CoL spell' do
        data = { 'moon' => true, 'name' => 'Moongate' }
        described_class.set_moon_data(data)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('No moon available to cast Moongate')
      end
    end
  end

  # ================================================================
  # set_planet_data
  # ================================================================
  describe '.set_planet_data' do
    context 'when data has no stats key' do
      it 'returns data unchanged' do
        data = { 'name' => 'Moongate', 'moon' => true }
        expect(described_class.set_planet_data(data)).to eq(data)
      end
    end

    context 'when a matching planet is visible' do
      before do
        allow(described_class).to receive(:get_data).with('constellations').and_return(
          OpenStruct.new(constellations: [
                           { 'name' => 'Yavash', 'stats' => ['wisdom'] },
                           { 'name' => 'Xibar', 'stats' => ['intelligence'] }
                         ])
        )
        allow(described_class).to receive(:find_visible_planets).and_return(['Yavash'])
      end

      it 'sets cast to the first matching visible planet' do
        data = { 'stats' => ['wisdom'], 'abbrev' => 'RTG' }
        result = described_class.set_planet_data(data)
        expect(result['cast']).to eq('cast Yavash')
      end

      it 'returns data with cast set' do
        data = { 'stats' => ['wisdom'], 'abbrev' => 'RTG' }
        result = described_class.set_planet_data(data)
        expect(result).to be_a(Hash)
        expect(result).to include('cast')
      end

      it 'prefers the first stat that matches a visible planet' do
        allow(described_class).to receive(:find_visible_planets).and_return(%w[Yavash Xibar])
        data = { 'stats' => %w[intelligence wisdom], 'abbrev' => 'RTG' }
        result = described_class.set_planet_data(data)
        expect(result['cast']).to eq('cast Xibar')
      end
    end

    context 'when no planet matches' do
      before do
        allow(described_class).to receive(:get_data).with('constellations').and_return(
          OpenStruct.new(constellations: [
                           { 'name' => 'Yavash', 'stats' => ['wisdom'] }
                         ])
        )
        allow(described_class).to receive(:find_visible_planets).and_return([])
      end

      it 'logs a bold DRCMM-prefixed message about failing to set planet data' do
        data = { 'stats' => ['wisdom'], 'abbrev' => 'RTG' }
        described_class.set_planet_data(data)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Could not set planet data')
      end

      it 'includes the spell abbreviation in the message' do
        data = { 'stats' => ['wisdom'], 'abbrev' => 'RTG' }
        described_class.set_planet_data(data)
        expect(Lich::Messaging.messages.last[:message]).to include('RTG')
      end
    end

    context 'when visible planets do not have the required stat' do
      before do
        allow(described_class).to receive(:get_data).with('constellations').and_return(
          OpenStruct.new(constellations: [
                           { 'name' => 'Yavash', 'stats' => ['wisdom'] },
                           { 'name' => 'Xibar', 'stats' => ['intelligence'] }
                         ])
        )
        allow(described_class).to receive(:find_visible_planets).and_return(['Xibar'])
      end

      it 'logs a message when the needed stat planet is not visible' do
        data = { 'stats' => ['wisdom'], 'abbrev' => 'RTG' }
        described_class.set_planet_data(data)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Could not set planet data')
      end
    end
  end

  # ================================================================
  # update_astral_data
  # ================================================================
  describe '.update_astral_data' do
    it 'delegates to set_moon_data when data has moon key' do
      data = { 'moon' => true, 'name' => 'Moongate' }
      expect(described_class).to receive(:set_moon_data).with(data).and_return(data)
      described_class.update_astral_data(data)
    end

    it 'delegates to set_planet_data when data has stats key' do
      data = { 'stats' => ['wisdom'] }
      settings = double('settings')
      expect(described_class).to receive(:set_planet_data).with(data, settings).and_return(data)
      described_class.update_astral_data(data, settings)
    end

    it 'returns data unchanged when neither moon nor stats' do
      data = { 'name' => 'Some Spell' }
      expect(described_class.update_astral_data(data)).to eq(data)
    end

    it 'prefers moon over stats when both keys present' do
      data = { 'moon' => true, 'stats' => ['wisdom'], 'name' => 'Moongate' }
      expect(described_class).to receive(:set_moon_data).with(data).and_return(data)
      expect(described_class).not_to receive(:set_planet_data)
      described_class.update_astral_data(data)
    end
  end

  # ================================================================
  # observe
  # ================================================================
  describe '.observe' do
    it 'observes heavens when thing is "heavens"' do
      expect(DRC).to receive(:bput).with('observe heavens', *described_class::OBSERVE_MESSAGES)
      described_class.observe('heavens')
    end

    it 'observes thing in heavens for other arguments' do
      expect(DRC).to receive(:bput).with('observe katamba in heavens', *described_class::OBSERVE_MESSAGES)
      described_class.observe('katamba')
    end
  end

  # ================================================================
  # predict
  # ================================================================
  describe '.predict' do
    it 'predicts state all when thing is "all"' do
      expect(DRC).to receive(:bput).with('predict state all', anything, anything, anything, anything, anything)
      described_class.predict('all')
    end

    it 'predicts the given thing otherwise' do
      expect(DRC).to receive(:bput).with('predict future', anything, anything, anything, anything, anything)
      described_class.predict('future')
    end
  end

  # ================================================================
  # study_sky
  # ================================================================
  describe '.study_sky' do
    it 'sends study sky command' do
      expect(DRC).to receive(:bput).with('study sky', anything, anything, anything, anything, anything)
      described_class.study_sky
    end
  end

  # ================================================================
  # align
  # ================================================================
  describe '.align' do
    it 'sends align command with skill' do
      expect(DRC).to receive(:bput).with('align survival', anything)
      described_class.align('survival')
    end
  end

  # ================================================================
  # center_telescope
  # ================================================================
  describe '.center_telescope' do
    it 'sends bold DRCMM-prefixed message when target not visible' do
      allow(DRC).to receive(:bput).and_return('The pain is too much')
      described_class.center_telescope('katamba')
      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
      expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
      expect(Lich::Messaging.messages.last[:message]).to include('Planet')
      expect(Lich::Messaging.messages.last[:message]).to include('katamba')
    end

    it 'sends bold DRCMM-prefixed message when sky not visible' do
      allow(DRC).to receive(:bput).and_return("That's a bit tough to do when you can't see the sky")
      described_class.center_telescope('katamba')
      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
      expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
      expect(Lich::Messaging.messages.last[:message]).to include('indoors')
    end
  end

  # ================================================================
  # peer_telescope
  # ================================================================
  describe '.peer_telescope' do
    it 'calls get_data for constellations' do
      constellation_data = OpenStruct.new(observe_finished_messages: ['You have learned everything'])
      expect(described_class).to receive(:get_data).with('constellations').and_return(constellation_data)
      allow(Lich::Util).to receive(:issue_command).and_return(['some output'])

      described_class.peer_telescope
    end

    it 'calls issue_command with correct command and options' do
      constellation_data = OpenStruct.new(observe_finished_messages: ['You have learned everything'])
      allow(described_class).to receive(:get_data).with('constellations').and_return(constellation_data)

      expect(Lich::Util).to receive(:issue_command).with(
        'peer my telescope',
        instance_of(Regexp),
        /Roundtime: /,
        usexml: false
      ).and_return(['line 1', 'line 2'])

      described_class.peer_telescope
    end

    it 'returns the result of issue_command' do
      constellation_data = OpenStruct.new(observe_finished_messages: ['You have learned everything'])
      allow(described_class).to receive(:get_data).with('constellations').and_return(constellation_data)
      allow(Lich::Util).to receive(:issue_command).and_return(['line 1', 'line 2'])

      result = described_class.peer_telescope
      expect(result).to eq(['line 1', 'line 2'])
    end

    it 'builds the start pattern from observe_finished_messages' do
      messages = ['pattern one', 'pattern two']
      constellation_data = OpenStruct.new(observe_finished_messages: messages)
      allow(described_class).to receive(:get_data).with('constellations').and_return(constellation_data)

      captured_pattern = nil
      allow(Lich::Util).to receive(:issue_command) do |_cmd, start_pattern, _end_pattern, **_opts|
        captured_pattern = start_pattern
        []
      end

      described_class.peer_telescope

      expect(captured_pattern).to be_a(Regexp)
      expect(captured_pattern).to match('The pain is too much')
      expect(captured_pattern).to match('pattern one')
      expect(captured_pattern).to match('pattern two')
      expect(captured_pattern).to match('Your vision is too fuzzy')
    end
  end

  # ================================================================
  # find_visible_planets
  # ================================================================
  describe '.find_visible_planets' do
    let(:settings) { double('settings', telescope_name: 'telescope', telescope_storage: { 'container' => 'backpack' }) }

    context 'when telescope is retrieved successfully' do
      before do
        allow(described_class).to receive(:get_telescope?).with('telescope', { 'container' => 'backpack' }).and_return(true)
        allow(described_class).to receive(:store_telescope?).with('telescope', { 'container' => 'backpack' }).and_return(true)
      end

      it 'returns all planets when none trigger the not-visible flag' do
        allow(described_class).to receive(:center_telescope)
        planets = %w[Yavash Xibar]
        result = described_class.find_visible_planets(planets, settings)
        expect(result).to eq(%w[Yavash Xibar])
      end

      it 'excludes planets that trigger the not-visible flag' do
        allow(described_class).to receive(:center_telescope) do |target|
          Flags['planet-not-visible'] = true if target == 'Xibar'
        end

        planets = %w[Yavash Xibar]
        result = described_class.find_visible_planets(planets, settings)
        expect(result).to eq(['Yavash'])
      end

      it 'resets flag between planets' do
        call_count = 0
        allow(described_class).to receive(:center_telescope) do |_target|
          call_count += 1
          Flags['planet-not-visible'] = true if call_count == 1
        end

        planets = %w[Yavash Xibar]
        result = described_class.find_visible_planets(planets, settings)
        # First planet (Yavash) not visible, second planet (Xibar) visible
        expect(result).to eq(['Xibar'])
      end

      it 'stores the telescope after observing planets' do
        allow(described_class).to receive(:center_telescope)
        expect(described_class).to receive(:store_telescope?).with('telescope', { 'container' => 'backpack' }).and_return(true)
        described_class.find_visible_planets(%w[Yavash], settings)
      end

      it 'returns observed planets even when store fails' do
        allow(described_class).to receive(:center_telescope)
        allow(described_class).to receive(:store_telescope?).with('telescope', { 'container' => 'backpack' }).and_return(false)

        result = described_class.find_visible_planets(%w[Yavash], settings)
        expect(result).to eq(['Yavash'])
      end

      it 'logs a bold DRCMM-prefixed message when store fails' do
        allow(described_class).to receive(:center_telescope)
        allow(described_class).to receive(:store_telescope?).with('telescope', { 'container' => 'backpack' }).and_return(false)

        described_class.find_visible_planets(%w[Yavash], settings)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Could not store telescope')
      end

      it 'cleans up flags even when an error occurs' do
        allow(described_class).to receive(:center_telescope).and_raise(StandardError, 'test error')
        expect { described_class.find_visible_planets(%w[Yavash], settings) }.to raise_error(StandardError)
      end
    end

    context 'when telescope cannot be retrieved' do
      before do
        allow(described_class).to receive(:get_telescope?).with('telescope', { 'container' => 'backpack' }).and_return(false)
      end

      it 'returns nil when the telescope cannot be retrieved from the container' do
        result = described_class.find_visible_planets(%w[Yavash Xibar], settings)
        expect(result).to be_nil
      end

      it 'logs a bold DRCMM-prefixed message about failing to get telescope' do
        described_class.find_visible_planets(%w[Yavash Xibar], settings)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Could not get telescope')
      end

      it 'does not attempt to center or store the telescope' do
        expect(described_class).not_to receive(:center_telescope)
        expect(described_class).not_to receive(:store_telescope?)
        described_class.find_visible_planets(%w[Yavash], settings)
      end
    end
  end

  # ================================================================
  # get_telescope? (DRCI predicate version)
  # ================================================================
  describe '.get_telescope?' do
    context 'when telescope is already in hands' do
      it 'returns true without getting' do
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        expect(DRCI).not_to receive(:get_item?)
        expect(described_class.get_telescope?('telescope', {})).to be true
      end
    end

    context 'with tied storage' do
      it 'returns true when untie succeeds' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(true)
        expect(described_class.get_telescope?('telescope', storage)).to be true
      end

      it 'returns false when untie fails' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(false)
        expect(described_class.get_telescope?('telescope', storage)).to be false
      end
    end

    context 'with container storage' do
      it 'returns true when get from container succeeds' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(true)
        expect(described_class.get_telescope?('telescope', storage)).to be true
      end

      it 'falls back to get from anywhere when container fails' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(true)
        expect(described_class.get_telescope?('telescope', storage)).to be true
      end

      it 'returns false when both container and fallback fail' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(false)
        expect(described_class.get_telescope?('telescope', storage)).to be false
      end

      it 'sends a DRCMM-prefixed plain message when falling back' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(true)
        described_class.get_telescope?('telescope', storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('plain')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Telescope not found')
      end
    end

    context 'with no storage specified' do
      it 'returns true when get succeeds' do
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(true)
        expect(described_class.get_telescope?('telescope', {})).to be true
      end

      it 'returns false when get fails' do
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(false)
        expect(described_class.get_telescope?('telescope', {})).to be false
      end
    end

    context 'with custom telescope name' do
      it 'uses the custom name' do
        storage = { 'container' => 'sack' }
        allow(DRCI).to receive(:in_hands?).with('spyglass').and_return(false)
        allow(DRCI).to receive(:get_item?).with('spyglass', 'sack').and_return(true)
        expect(described_class.get_telescope?('spyglass', storage)).to be true
      end
    end
  end

  # ================================================================
  # store_telescope? (DRCI predicate version)
  # ================================================================
  describe '.store_telescope?' do
    context 'when telescope is not in hands' do
      it 'returns true without storing' do
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        expect(DRCI).not_to receive(:put_away_item?)
        expect(described_class.store_telescope?('telescope', {})).to be true
      end
    end

    context 'with tied storage' do
      it 'returns true when tie succeeds' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(true)
        expect(described_class.store_telescope?('telescope', storage)).to be true
      end

      it 'returns false when tie fails' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(false)
        expect(described_class.store_telescope?('telescope', storage)).to be false
      end
    end

    context 'with container storage' do
      it 'returns true when put away succeeds' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(true)
        expect(described_class.store_telescope?('telescope', storage)).to be true
      end

      it 'returns false when put away fails' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(false)
        expect(described_class.store_telescope?('telescope', storage)).to be false
      end
    end

    context 'with no storage specified' do
      it 'returns true when put away succeeds' do
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope').and_return(true)
        expect(described_class.store_telescope?('telescope', {})).to be true
      end

      it 'returns false when put away fails' do
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope').and_return(false)
        expect(described_class.store_telescope?('telescope', {})).to be false
      end
    end
  end

  # ================================================================
  # get_telescope (deprecated - delegates to get_telescope?)
  # ================================================================
  describe '.get_telescope' do
    context 'when get_telescope? succeeds' do
      it 'returns without logging an error when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(true)
        described_class.get_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging an error when in container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(true)
        described_class.get_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when already in hands' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        described_class.get_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_telescope? fails' do
      it 'logs a bold DRCMM-prefixed error message' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(false)
        described_class.get_telescope(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get telescope')
      end
    end
  end

  # ================================================================
  # store_telescope (deprecated - delegates to store_telescope?)
  # ================================================================
  describe '.store_telescope' do
    context 'when store_telescope? succeeds' do
      it 'returns without logging an error when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(true)
        described_class.store_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging an error when in container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(true)
        described_class.store_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when not in hands' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        described_class.store_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_telescope? fails' do
      it 'logs a bold DRCMM-prefixed error message' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(false)
        described_class.store_telescope(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store telescope')
      end
    end
  end

  # ================================================================
  # get_bones? (DRCI predicate version)
  # ================================================================
  describe '.get_bones?' do
    context 'with tied storage' do
      it 'returns true when untie succeeds' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(true)
        expect(described_class.get_bones?(storage)).to be true
      end

      it 'returns false when untie fails' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(false)
        expect(described_class.get_bones?(storage)).to be false
      end
    end

    context 'with container storage' do
      it 'returns true when get succeeds' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)
        expect(described_class.get_bones?(storage)).to be true
      end

      it 'returns false when get fails' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(false)
        expect(described_class.get_bones?(storage)).to be false
      end
    end

    context 'with no storage specified' do
      it 'returns true when get succeeds' do
        storage = {}
        allow(DRCI).to receive(:get_item?).with('bones').and_return(true)
        expect(described_class.get_bones?(storage)).to be true
      end

      it 'returns false when get fails' do
        storage = {}
        allow(DRCI).to receive(:get_item?).with('bones').and_return(false)
        expect(described_class.get_bones?(storage)).to be false
      end
    end
  end

  # ================================================================
  # store_bones? (DRCI predicate version)
  # ================================================================
  describe '.store_bones?' do
    context 'with tied storage' do
      it 'returns true when tie succeeds' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(true)
        expect(described_class.store_bones?(storage)).to be true
      end

      it 'returns false when tie fails' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(false)
        expect(described_class.store_bones?(storage)).to be false
      end
    end

    context 'with container storage' do
      it 'returns true when put away succeeds' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)
        expect(described_class.store_bones?(storage)).to be true
      end

      it 'returns false when put away fails' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(false)
        expect(described_class.store_bones?(storage)).to be false
      end
    end

    context 'with no storage specified' do
      it 'returns true when put away succeeds' do
        storage = {}
        allow(DRCI).to receive(:put_away_item?).with('bones').and_return(true)
        expect(described_class.store_bones?(storage)).to be true
      end

      it 'returns false when put away fails' do
        storage = {}
        allow(DRCI).to receive(:put_away_item?).with('bones').and_return(false)
        expect(described_class.store_bones?(storage)).to be false
      end
    end
  end

  # ================================================================
  # get_bones (deprecated - delegates to get_bones?)
  # ================================================================
  describe '.get_bones' do
    context 'when get_bones? succeeds' do
      it 'returns without logging when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(true)
        described_class.get_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)
        described_class.get_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_bones? fails' do
      it 'logs a bold DRCMM-prefixed error message' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(false)
        described_class.get_bones(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get bones')
      end
    end
  end

  # ================================================================
  # store_bones (deprecated - delegates to store_bones?)
  # ================================================================
  describe '.store_bones' do
    context 'when store_bones? succeeds' do
      it 'returns without logging when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(true)
        described_class.store_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)
        described_class.store_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_bones? fails' do
      it 'logs a bold DRCMM-prefixed error message' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(false)
        described_class.store_bones(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store bones')
      end
    end
  end

  # ================================================================
  # roll_bones (migrated to use ? methods)
  # ================================================================
  describe '.roll_bones' do
    context 'when get_bones? succeeds' do
      before do
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)
        allow(DRC).to receive(:bput).with('roll my bones', 'roundtime').and_return('roundtime')
      end

      it 'rolls and stores bones on success' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)
        expect(DRC).to receive(:bput).with('roll my bones', 'roundtime')
        described_class.roll_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'logs error when store_bones? fails after rolling' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(false)
        described_class.roll_bones(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store bones after rolling')
      end
    end

    context 'when get_bones? fails' do
      it 'aborts without rolling and logs error' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(false)
        expect(DRC).not_to receive(:bput).with('roll my bones', anything)
        described_class.roll_bones(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get bones')
        expect(Lich::Messaging.messages.last[:message]).to include('aborting')
      end
    end
  end

  # ================================================================
  # get_div_tool? (DRCI predicate version)
  # ================================================================
  describe '.get_div_tool?' do
    context 'with tied tool' do
      it 'returns true when untie succeeds' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('charts', 'belt').and_return(true)
        expect(described_class.get_div_tool?(tool)).to be true
      end

      it 'returns false when untie fails' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('charts', 'belt').and_return(false)
        expect(described_class.get_div_tool?(tool)).to be false
      end
    end

    context 'with worn tool' do
      it 'returns true when remove succeeds' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(true)
        expect(described_class.get_div_tool?(tool)).to be true
      end

      it 'returns false when remove fails' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(false)
        expect(described_class.get_div_tool?(tool)).to be false
      end
    end

    context 'with container tool' do
      it 'returns true when get succeeds' do
        tool = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('bones', 'sack').and_return(true)
        expect(described_class.get_div_tool?(tool)).to be true
      end

      it 'returns false when get fails' do
        tool = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('bones', 'sack').and_return(false)
        expect(described_class.get_div_tool?(tool)).to be false
      end
    end
  end

  # ================================================================
  # store_div_tool? (DRCI predicate version)
  # ================================================================
  describe '.store_div_tool?' do
    context 'with tied tool' do
      it 'returns true when tie succeeds' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('charts', 'belt').and_return(true)
        expect(described_class.store_div_tool?(tool)).to be true
      end

      it 'returns false when tie fails' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('charts', 'belt').and_return(false)
        expect(described_class.store_div_tool?(tool)).to be false
      end
    end

    context 'with worn tool' do
      it 'returns true when wear succeeds' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(true)
        expect(described_class.store_div_tool?(tool)).to be true
      end

      it 'returns false when wear fails' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(false)
        expect(described_class.store_div_tool?(tool)).to be false
      end
    end

    context 'with container tool' do
      it 'returns true when put away succeeds' do
        tool = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'sack').and_return(true)
        expect(described_class.store_div_tool?(tool)).to be true
      end

      it 'returns false when put away fails' do
        tool = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'sack').and_return(false)
        expect(described_class.store_div_tool?(tool)).to be false
      end
    end
  end

  # ================================================================
  # get_div_tool (deprecated - delegates to get_div_tool?)
  # ================================================================
  describe '.get_div_tool' do
    context 'when get_div_tool? succeeds' do
      it 'returns without logging when tied' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'satchel' }
        allow(DRCI).to receive(:untie_item?).with('charts', 'satchel').and_return(true)
        described_class.get_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when worn' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(true)
        described_class.get_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)
        described_class.get_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_div_tool? fails' do
      it 'logs a bold DRCMM-prefixed error with tool name' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(false)
        described_class.get_div_tool(tool)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to get divination tool 'charts'")
      end
    end
  end

  # ================================================================
  # store_div_tool (deprecated - delegates to store_div_tool?)
  # ================================================================
  describe '.store_div_tool' do
    context 'when store_div_tool? succeeds' do
      it 'returns without logging when tied' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'satchel' }
        allow(DRCI).to receive(:tie_item?).with('charts', 'satchel').and_return(true)
        described_class.store_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when worn' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(true)
        described_class.store_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(true)
        described_class.store_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_div_tool? fails' do
      it 'logs a bold DRCMM-prefixed error with tool name' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(false)
        described_class.store_div_tool(tool)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to store divination tool 'charts'")
      end
    end
  end

  # ================================================================
  # use_div_tool (migrated to use ? methods)
  # ================================================================
  describe '.use_div_tool' do
    context 'when get_div_tool? succeeds' do
      it 'uses the tool and stores it on success' do
        tool_storage = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)
        allow(DRC).to receive(:bput).with('review my charts', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(true)
        described_class.use_div_tool(tool_storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'logs error when store_div_tool? fails after using' do
        tool_storage = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)
        allow(DRC).to receive(:bput).with('review my charts', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(false)
        described_class.use_div_tool(tool_storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to store divination tool 'charts'")
      end

      it 'uses correct verb for bones tool' do
        tool_storage = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('bones', 'sack').and_return(true)
        expect(DRC).to receive(:bput).with('roll my bones', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('bones', 'sack').and_return(true)
        described_class.use_div_tool(tool_storage)
      end

      it 'uses correct verb for mirror tool' do
        tool_storage = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(true)
        expect(DRC).to receive(:bput).with('gaze my mirror', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(true)
        described_class.use_div_tool(tool_storage)
      end

      it 'uses correct verb for bowl tool' do
        tool_storage = { 'name' => 'bowl', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('bowl', 'sack').and_return(true)
        expect(DRC).to receive(:bput).with('gaze my bowl', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('bowl', 'sack').and_return(true)
        described_class.use_div_tool(tool_storage)
      end

      it 'uses correct verb for prism tool' do
        tool_storage = { 'name' => 'prism', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('prism', 'sack').and_return(true)
        expect(DRC).to receive(:bput).with('raise my prism', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('prism', 'sack').and_return(true)
        described_class.use_div_tool(tool_storage)
      end
    end

    context 'when get_div_tool? fails' do
      it 'aborts without using the tool and logs error' do
        tool_storage = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(false)
        expect(DRC).not_to receive(:bput).with('review my charts', anything)
        described_class.use_div_tool(tool_storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to get divination tool 'charts'")
        expect(Lich::Messaging.messages.last[:message]).to include('aborting')
      end
    end
  end
end
