# frozen_string_literal: true

require 'rspec'

LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-healing-data.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-healing.rb')

# --- Mock setup ---
# DRSkill must be a class (not module) to match real definition.
class DRSkill
  def self.getrank(*_args)
    0
  end
end unless defined?(DRSkill)
Lich::DragonRealms::DRSkill = ::DRSkill unless defined?(Lich::DragonRealms::DRSkill)

# DRStats is a module in real code.
module DRStats
  def self.empath?(*_args)
    false
  end
end unless defined?(DRStats)
Lich::DragonRealms::DRStats = ::DRStats unless defined?(Lich::DragonRealms::DRStats)

# DRC is a module in real code.
module DRC
  def self.bput(*_args)
    ''
  end
end unless defined?(DRC)
Lich::DragonRealms::DRC = ::DRC unless defined?(Lich::DragonRealms::DRC)

# DRCI is a module in real code.
module DRCI
  def self.dispose_trash(*_args)
    true
  end
end unless defined?(DRCI)
Lich::DragonRealms::DRCI = ::DRCI unless defined?(Lich::DragonRealms::DRCI)

# Lich::Util for issue_command
module Lich
  module Util
    def self.issue_command(*_args, **_kwargs)
      []
    end
  end unless defined?(Lich::Util)
end

# Lich::Messaging for messaging
module Lich
  module Messaging
    def self.msg(*_args)
      nil
    end
  end unless defined?(Lich::Messaging)
end

RSpec.describe Lich::DragonRealms::DRCH do
  # ─── Wound class ──────────────────────────────────────────────────────

  describe described_class::Wound do
    describe '#initialize' do
      it 'downcases body_part and bleeding_rate' do
        wound = described_class.new(body_part: 'LEFT ARM', bleeding_rate: 'SLIGHT')
        expect(wound.body_part).to eq('left arm')
        expect(wound.bleeding_rate).to eq('slight')
      end

      it 'handles nil body_part and bleeding_rate' do
        wound = described_class.new
        expect(wound.body_part).to be_nil
        expect(wound.severity).to be_nil
        expect(wound.bleeding_rate).to be_nil
      end

      it 'coerces boolean flags' do
        wound = described_class.new(is_internal: 'truthy', is_scar: nil)
        expect(wound.internal?).to be true
        expect(wound.scar?).to be false
      end

      it 'defaults all boolean flags to false' do
        wound = described_class.new
        expect(wound.internal?).to be false
        expect(wound.scar?).to be false
        expect(wound.parasite?).to be false
        expect(wound.lodged?).to be false
      end
    end

    describe '#bleeding?' do
      it 'returns true for active bleed rates' do
        wound = described_class.new(bleeding_rate: 'slight')
        expect(wound.bleeding?).to be true
      end

      it 'returns false for (tended)' do
        wound = described_class.new(bleeding_rate: '(tended)')
        expect(wound.bleeding?).to be false
      end

      it 'returns false for nil bleeding_rate' do
        wound = described_class.new
        expect(wound.bleeding?).to be false
      end

      it 'returns false for empty bleeding_rate' do
        wound = described_class.new(bleeding_rate: '')
        expect(wound.bleeding?).to be false
      end
    end

    describe '#tendable?' do
      it 'returns true for parasites' do
        wound = described_class.new(is_parasite: true)
        expect(wound.tendable?).to be true
      end

      it 'returns true for lodged items' do
        wound = described_class.new(is_lodged_item: true)
        expect(wound.tendable?).to be true
      end

      it 'returns false for skin wounds' do
        wound = described_class.new(body_part: 'skin', bleeding_rate: 'slight')
        expect(wound.tendable?).to be false
      end

      it 'returns false for tended wounds' do
        wound = described_class.new(body_part: 'right arm', bleeding_rate: '(tended)')
        expect(wound.tendable?).to be false
      end

      it 'returns false for clotted wounds' do
        wound = described_class.new(body_part: 'right arm', bleeding_rate: 'clotted')
        expect(wound.tendable?).to be false
      end

      it 'returns false for non-bleeding wounds' do
        wound = described_class.new(body_part: 'right arm', severity: 3)
        expect(wound.tendable?).to be false
      end

      it 'returns true for bleeding wound when skilled' do
        allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
        wound = described_class.new(body_part: 'right arm', bleeding_rate: 'slight')
        expect(wound.tendable?).to be true
      end

      it 'returns false when unskilled' do
        allow(DRSkill).to receive(:getrank).with('First Aid').and_return(0)
        wound = described_class.new(body_part: 'right arm', bleeding_rate: 'slight')
        expect(wound.tendable?).to be false
      end
    end

    describe '#location' do
      it 'returns external for non-internal wounds' do
        expect(described_class.new.location).to eq('external')
      end

      it 'returns internal for internal wounds' do
        expect(described_class.new(is_internal: true).location).to eq('internal')
      end
    end

    describe '#type' do
      it 'returns wound for fresh wounds' do
        expect(described_class.new.type).to eq('wound')
      end

      it 'returns scar for scars' do
        expect(described_class.new(is_scar: true).type).to eq('scar')
      end
    end

    describe '#to_h' do
      it 'returns a hash of all fields' do
        wound = described_class.new(body_part: 'chest', severity: 5, is_internal: true)
        h = wound.to_h
        expect(h[:body_part]).to eq('chest')
        expect(h[:severity]).to eq(5)
        expect(h[:internal]).to be true
        expect(h[:scar]).to be false
        expect(h[:parasite]).to be false
        expect(h[:lodged_item]).to be false
      end
    end

    describe '#to_s' do
      it 'includes body part and severity' do
        wound = described_class.new(body_part: 'chest', severity: 5)
        str = wound.to_s
        expect(str).to include('chest')
        expect(str).to include('severity:5')
      end

      it 'includes bleeding rate when present' do
        wound = described_class.new(body_part: 'arm', bleeding_rate: 'slight')
        expect(wound.to_s).to include('bleeding:slight')
      end

      it 'includes parasite flag when parasite' do
        wound = described_class.new(is_parasite: true)
        expect(wound.to_s).to include('parasite')
      end

      it 'includes lodged flag when lodged' do
        wound = described_class.new(is_lodged_item: true)
        expect(wound.to_s).to include('lodged')
      end

      it 'uses unknown when body_part is nil' do
        wound = described_class.new
        expect(wound.to_s).to include('unknown')
      end
    end
  end

  # ─── HealthResult class ───────────────────────────────────────────────

  describe described_class::HealthResult do
    describe '#initialize' do
      it 'has sensible defaults' do
        result = described_class.new
        expect(result.wounds).to eq({})
        expect(result.bleeders).to eq({})
        expect(result.parasites).to eq({})
        expect(result.lodged).to eq({})
        expect(result.poisoned).to be false
        expect(result.diseased).to be false
        expect(result.score).to eq(0)
        expect(result.dead).to be false
      end
    end

    describe '#[]' do
      it 'provides backward-compatible string key access' do
        result = described_class.new(poisoned: true, score: 42)
        expect(result['poisoned']).to be true
        expect(result['score']).to eq(42)
        expect(result['wounds']).to eq({})
      end

      it 'provides symbol key access' do
        result = described_class.new(diseased: true)
        expect(result[:diseased]).to be true
      end
    end

    describe '#injured?' do
      it 'returns false for score 0' do
        expect(described_class.new.injured?).to be false
      end

      it 'returns true for positive score' do
        expect(described_class.new(score: 5).injured?).to be true
      end
    end

    describe '#bleeding?' do
      it 'returns false with no bleeders' do
        expect(described_class.new.bleeding?).to be false
      end

      it 'returns true with active bleeders' do
        wound_class = Lich::DragonRealms::DRCH::Wound
        bleeders = { 3 => [wound_class.new(body_part: 'arm', bleeding_rate: 'slight')] }
        result = described_class.new(bleeders: bleeders)
        expect(result.bleeding?).to be true
      end

      it 'returns false with only tended bleeders' do
        wound_class = Lich::DragonRealms::DRCH::Wound
        bleeders = { 1 => [wound_class.new(body_part: 'arm', bleeding_rate: '(tended)')] }
        result = described_class.new(bleeders: bleeders)
        expect(result.bleeding?).to be false
      end
    end

    describe '#has_tendable_bleeders?' do
      it 'returns false with no bleeders' do
        expect(described_class.new.has_tendable_bleeders?).to be false
      end

      it 'returns true with tendable bleeders' do
        allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
        wound_class = Lich::DragonRealms::DRCH::Wound
        bleeders = { 3 => [wound_class.new(body_part: 'arm', bleeding_rate: 'slight')] }
        result = described_class.new(bleeders: bleeders)
        expect(result.has_tendable_bleeders?).to be true
      end
    end
  end

  # ─── strip_xml ────────────────────────────────────────────────────────

  describe '.strip_xml' do
    it 'removes XML tags' do
      lines = ['<pushStream id="familiar">Some text</pushStream>']
      expect(described_class.strip_xml(lines)).to eq(['Some text'])
    end

    it 'decodes HTML entities' do
      lines = ['You say &gt; hello &lt; world']
      expect(described_class.strip_xml(lines)).to eq(['You say > hello < world'])
    end

    it 'strips whitespace and rejects empty lines' do
      lines = ['  hello  ', '', '   ', 'world']
      expect(described_class.strip_xml(lines)).to eq(%w[hello world])
    end

    it 'removes inline XML tags' do
      lines = ['<output class=""/>Your body feels at full strength.']
      expect(described_class.strip_xml(lines)).to eq(['Your body feels at full strength.'])
    end

    it 'handles roundtime XML tags' do
      lines = ["<roundTime value='1234'/>You feel at full strength."]
      expect(described_class.strip_xml(lines)).to eq(['You feel at full strength.'])
    end
  end

  # ─── calculate_score ──────────────────────────────────────────────────

  describe '.calculate_score' do
    it 'returns 0 for no wounds' do
      expect(described_class.calculate_score({})).to eq(0)
    end

    it 'returns 0 for empty wound lists' do
      expect(described_class.calculate_score({ 1 => [], 2 => [] })).to eq(0)
    end

    it 'calculates quadratic score' do
      wound_class = described_class::Wound
      wounds = {
        1 => [wound_class.new],
        3 => [wound_class.new, wound_class.new]
      }
      # 1^2 * 1 + 3^2 * 2 = 1 + 18 = 19
      expect(described_class.calculate_score(wounds)).to eq(19)
    end

    it 'weights higher severity wounds more' do
      wound_class = described_class::Wound
      low = { 1 => [wound_class.new] }
      high = { 8 => [wound_class.new] }
      expect(described_class.calculate_score(high)).to be > described_class.calculate_score(low)
    end
  end

  # ─── parse_health_lines ──────────────────────────────────────────────

  describe '.parse_health_lines' do
    it 'parses a healthy person' do
      lines = [
        'Your body feels at full strength.',
        'Your spirit feels full of life.',
        'You have no significant injuries.'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result).to be_a(described_class::HealthResult)
      expect(result.wounds).to be_empty
      expect(result.bleeders).to be_empty
      expect(result.poisoned).to be false
      expect(result.diseased).to be false
      expect(result.score).to eq(0)
    end

    it 'detects wounds' do
      lines = [
        'Your body feels at full strength.',
        'Your spirit feels full of life.',
        'You have some tiny scratches to the neck, minor swelling and bruising around the left arm compounded by cuts and bruises about the left arm.',
        'You have no significant injuries.'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result.wounds).not_to be_empty
      expect(result['wounds']).not_to be_empty # backward compat
    end

    it 'detects poison' do
      lines = [
        'Your body feels at full strength.',
        'Your spirit feels full of life.',
        'You have some tiny scratches to the neck.',
        'You have a mildly poisoned right leg.'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result.poisoned).to be true
    end

    it 'detects breathing-related poison' do
      lines = [
        'Your body feels at full strength.',
        'You feel somewhat tired and seem to be having trouble breathing.'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result.poisoned).to be true
    end

    it 'detects disease from infected wounds' do
      lines = [
        'Your body feels beat up.',
        'Your wounds are infected.'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result.diseased).to be true
    end

    it 'detects disease from dormant infection' do
      lines = [
        'Your body feels at full strength.',
        'You have a dormant infection.'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result.diseased).to be true
    end

    it 'detects disease from oozing sores' do
      lines = [
        'Your body feels beat up.',
        'Your body is covered in open oozing sores.'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result.diseased).to be true
    end

    it 'ignores fatigue lines' do
      lines = [
        'Your body feels at full strength.',
        'You are slightly fatigued.',
        'Your spirit feels full of life.',
        'You have no significant injuries.'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result.wounds).to be_empty
      expect(result.poisoned).to be false
    end

    it 'ignores rested lines' do
      lines = [
        'Your body feels at full strength.',
        'You feel fully rested.',
        'You have no significant injuries.'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result.wounds).to be_empty
    end

    it 'detects bleeders' do
      lines = [
        'Your body feels slightly battered.',
        'Your spirit feels full of life.',
        'You have deep cuts across the tail.',
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'tail       slight'
      ]
      result = described_class.parse_health_lines(lines)
      expect(result.bleeders).not_to be_empty
      bleeders = result.bleeders.values.flatten
      expect(bleeders.length).to eq(1)
      expect(bleeders.first.body_part).to eq('tail')
      expect(bleeders.first.bleeding_rate).to eq('slight')
    end

    it 'detects both internal and external bleeders' do
      lines = [
        'Your body feels in bad shape.',
        'You have a severely swollen and deeply bruised right leg compounded by deep cuts across the right leg.',
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'right leg       slight',
        'inside r. leg       slight'
      ]
      result = described_class.parse_health_lines(lines)
      bleeders = result.bleeders.values.flatten
      expect(bleeders.length).to eq(2)
      external = bleeders.find { |w| !w.internal? }
      internal = bleeders.find(&:internal?)
      expect(external.body_part).to eq('right leg')
      expect(internal.body_part).to eq('right leg')
    end

    it 'detects lodged items' do
      lines = [
        'Your body feels at full strength.',
        'You have cuts and bruises about the chest area.',
        'You have a retch maggot lodged firmly into your chest.',
        'You feel fully rested.'
      ]
      result = described_class.parse_health_lines(lines)
      lodged = result.lodged.values.flatten
      expect(lodged.length).to eq(1)
      expect(lodged.first.body_part).to eq('chest')
      expect(lodged.first.lodged?).to be true
    end

    it 'detects parasites' do
      lines = [
        'Your body feels at full strength.',
        'You have a retch maggot on your chest.'
      ]
      result = described_class.parse_health_lines(lines)
      parasites = result.parasites.values.flatten
      expect(parasites.length).to eq(1)
      expect(parasites.first.body_part).to eq('chest')
      expect(parasites.first.parasite?).to be true
    end

    it 'calculates wound score' do
      lines = [
        'Your body feels at full strength.',
        'You have some tiny scratches to the neck.'
      ]
      result = described_class.parse_health_lines(lines)
      # severity 2 (negligible), 1 wound: 2^2 * 1 = 4
      expect(result.score).to eq(4)
    end
  end

  # ─── parse_bleeders ──────────────────────────────────────────────────

  describe '.parse_bleeders' do
    it 'returns empty hash when no bleeding section' do
      lines = [
        'Your body feels at full strength.',
        'You have no significant injuries.'
      ]
      expect(described_class.parse_bleeders(lines)).to be_empty
    end

    it 'parses external bleeders' do
      lines = [
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'tail       slight'
      ]
      bleeders = described_class.parse_bleeders(lines)
      wound = bleeders.values.flatten.first
      expect(wound.body_part).to eq('tail')
      expect(wound.bleeding_rate).to eq('slight')
      expect(wound.internal?).to be false
    end

    it 'parses internal bleeders with abbreviated sides' do
      lines = [
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'inside r. arm       slight'
      ]
      bleeders = described_class.parse_bleeders(lines)
      wound = bleeders.values.flatten.first
      expect(wound.body_part).to eq('right arm')
      expect(wound.internal?).to be true
    end

    it 'parses left-side internal bleeders' do
      lines = [
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'inside l. leg       moderate'
      ]
      bleeders = described_class.parse_bleeders(lines)
      wound = bleeders.values.flatten.first
      expect(wound.body_part).to eq('left leg')
      expect(wound.internal?).to be true
      expect(wound.bleeding_rate).to eq('moderate')
    end

    it 'parses tended bleeders' do
      lines = [
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'right arm       (tended)'
      ]
      bleeders = described_class.parse_bleeders(lines)
      wound = bleeders.values.flatten.first
      expect(wound.bleeding_rate).to eq('(tended)')
      expect(wound.bleeding?).to be false
    end

    it 'parses multiple bleeders' do
      lines = [
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'right leg       slight',
        'left leg       light',
        'skin       slight',
        'inside r. leg       slight',
        'inside l. leg       light'
      ]
      bleeders = described_class.parse_bleeders(lines)
      all_bleeders = bleeders.values.flatten
      expect(all_bleeders.length).to eq(5)
    end
  end

  # ─── parse_wounds ────────────────────────────────────────────────────

  describe '.parse_wounds' do
    it 'returns empty hash for nil' do
      expect(described_class.parse_wounds(nil)).to be_empty
    end

    it 'parses simple wound' do
      line = 'You have some tiny scratches to the neck.'
      wounds = described_class.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds.length).to eq(1)
      expect(all_wounds.first.body_part).to eq('neck')
      expect(all_wounds.first.severity).to eq(2) # negligible
    end

    it 'parses multiple wounds in comma-separated line' do
      line = 'You have some tiny scratches to the neck, some minor abrasions to the left hand, some tiny scratches to the chest.'
      wounds = described_class.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds.length).to eq(3)
      body_parts = all_wounds.map(&:body_part)
      expect(body_parts).to include('neck', 'left hand', 'chest')
    end

    it 'parses compounded wounds correctly (comma within wound text)' do
      line = 'You have minor swelling and bruising around the left arm compounded by cuts and bruises about the left arm.'
      wounds = described_class.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds.length).to eq(2)
      expect(all_wounds.any?(&:internal?)).to be true
      expect(all_wounds.any? { |w| !w.internal? }).to be true
    end

    it 'parses skin wounds' do
      line = 'You have a small skin rash.'
      wounds = described_class.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds.length).to eq(1)
    end

    it 'parses internal twitching wounds' do
      line = 'You have an occasional twitching in the left leg.'
      wounds = described_class.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds).not_to be_empty
      expect(all_wounds.any? { |w| w.internal? && w.scar? }).to be true
    end

    it 'parses severe head wounds' do
      line = 'You have a cracked skull with deep slashes.'
      wounds = described_class.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds).not_to be_empty
      expect(all_wounds.first.severity).to eq(6)
    end

    it 'parses useless body part wounds' do
      line = 'You have an ugly stump for a right arm.'
      wounds = described_class.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds).not_to be_empty
      expect(all_wounds.first.severity).to eq(8)
    end
  end

  # ─── parse_parasites ─────────────────────────────────────────────────

  describe '.parse_parasites' do
    it 'returns empty hash for nil' do
      expect(described_class.parse_parasites(nil)).to be_empty
    end

    it 'parses a parasite on a body part' do
      line = 'You have a retch maggot on your chest.'
      parasites = described_class.parse_parasites(line)
      all_parasites = parasites.values.flatten
      expect(all_parasites.length).to eq(1)
      expect(all_parasites.first.body_part).to eq('chest')
      expect(all_parasites.first.parasite?).to be true
      expect(all_parasites.first.severity).to eq(1)
    end

    it 'parses blood mite parasites' do
      line = 'You have a small black blood mite on your left arm.'
      parasites = described_class.parse_parasites(line)
      all_parasites = parasites.values.flatten
      expect(all_parasites.length).to eq(1)
      expect(all_parasites.first.body_part).to eq('left arm')
    end
  end

  # ─── parse_lodged_items ──────────────────────────────────────────────

  describe '.parse_lodged_items' do
    it 'returns empty hash for nil' do
      expect(described_class.parse_lodged_items(nil)).to be_empty
    end

    it 'parses a firmly lodged item' do
      line = 'You have a retch maggot lodged firmly into your chest.'
      lodged = described_class.parse_lodged_items(line)
      all_lodged = lodged.values.flatten
      expect(all_lodged.length).to eq(1)
      expect(all_lodged.first.body_part).to eq('chest')
      expect(all_lodged.first.lodged?).to be true
      expect(all_lodged.first.severity).to eq(3) # firmly = 3
    end

    it 'parses a shallowly lodged item' do
      line = 'You have an arrow lodged shallowly into your right leg.'
      lodged = described_class.parse_lodged_items(line)
      all_lodged = lodged.values.flatten
      expect(all_lodged.first.severity).to eq(2) # shallowly = 2
    end

    it 'parses a deeply lodged item' do
      line = 'You have a bolt lodged deeply into your abdomen.'
      lodged = described_class.parse_lodged_items(line)
      all_lodged = lodged.values.flatten
      expect(all_lodged.first.severity).to eq(4) # deeply = 4
    end
  end

  # ─── parse_perceived_health_lines ────────────────────────────────────

  describe '.parse_perceived_health_lines' do
    it 'parses wound details from perceive output' do
      lines = [
        'Your injuries include...',
        'Wounds to the HEAD:',
        'Fresh External:  light scratches -- negligible',
        'Wounds to the LEFT ARM:',
        'Fresh External:  cuts and bruises -- minor',
        'Fresh Internal:  minor swelling and bruising -- minor',
        'Roundtime: 5 sec.'
      ]
      result = described_class.parse_perceived_health_lines(lines)
      expect(result).to be_a(described_class::HealthResult)
      all_wounds = result.wounds.values.flatten
      expect(all_wounds.length).to eq(3)

      head_wound = all_wounds.find { |w| w.body_part == 'head' }
      expect(head_wound).not_to be_nil
      expect(head_wound.severity).to eq(2) # negligible
      expect(head_wound.internal?).to be false
      expect(head_wound.scar?).to be false

      arm_wounds = all_wounds.select { |w| w.body_part == 'left arm' }
      expect(arm_wounds.length).to eq(2)
      expect(arm_wounds.any?(&:internal?)).to be true
    end

    it 'parses scars' do
      lines = [
        'Your injuries include...',
        'Wounds to the RIGHT LEG:',
        'Scars External:  minor scarring -- minor'
      ]
      result = described_class.parse_perceived_health_lines(lines)
      wound = result.wounds.values.flatten.first
      expect(wound.scar?).to be true
    end

    it 'detects dead target' do
      lines = ['She is dead.']
      result = described_class.parse_perceived_health_lines(lines)
      expect(result.dead).to be true
    end

    it 'detects He is dead' do
      lines = ['He is dead.']
      result = described_class.parse_perceived_health_lines(lines)
      expect(result.dead).to be true
    end

    it 'detects poisoned target' do
      lines = ['Muleoak has a mildly poisoned right leg.']
      result = described_class.parse_perceived_health_lines(lines)
      expect(result.poisoned).to be true
    end

    it 'detects diseased target' do
      lines = ['Muleoak wounds are infected.']
      result = described_class.parse_perceived_health_lines(lines)
      expect(result.diseased).to be true
    end

    it 'detects badly infected diseases' do
      lines = ['Muleoak wounds are badly infected.']
      result = described_class.parse_perceived_health_lines(lines)
      expect(result.diseased).to be true
    end

    it 'calculates score from perceived wounds' do
      lines = [
        'Your injuries include...',
        'Wounds to the HEAD:',
        'Fresh External:  light scratches -- negligible'
      ]
      result = described_class.parse_perceived_health_lines(lines)
      # severity 2 (negligible), 1 wound: 2^2 * 1 = 4
      expect(result.score).to eq(4)
    end

    it 'handles multiple severity levels' do
      lines = [
        'Your injuries include...',
        'Wounds to the HEAD:',
        'Fresh External:  light scratches -- negligible',
        'Fresh Internal:  a bruised head -- minor',
        'Wounds to the LEFT ARM:',
        'Scars External:  minor scarring -- minor'
      ]
      result = described_class.parse_perceived_health_lines(lines)
      all_wounds = result.wounds.values.flatten
      expect(all_wounds.length).to eq(3)
    end
  end

  # ─── skilled_to_tend_wound? ──────────────────────────────────────────

  describe '.skilled_to_tend_wound?' do
    it 'returns true when skilled enough for external' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
      expect(described_class.skilled_to_tend_wound?('slight')).to be true
    end

    it 'returns false when unskilled' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(0)
      expect(described_class.skilled_to_tend_wound?('slight')).to be false
    end

    it 'returns false for unknown bleed rate' do
      expect(described_class.skilled_to_tend_wound?('nonexistent')).to be false
    end

    it 'returns false for tended wounds' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
      expect(described_class.skilled_to_tend_wound?('(tended)')).to be false
    end

    it 'requires higher skill for internal wounds' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
      expect(described_class.skilled_to_tend_wound?('slight', false)).to be true  # external: 30
      expect(described_class.skilled_to_tend_wound?('slight', true)).to be false  # internal: 600
    end

    it 'returns true when exactly at minimum skill' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(30)
      expect(described_class.skilled_to_tend_wound?('slight', false)).to be true
    end

    it 'returns false when one below minimum skill' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(29)
      expect(described_class.skilled_to_tend_wound?('slight', false)).to be false
    end
  end

  # ─── Game I/O methods ────────────────────────────────────────────────

  describe '.check_health' do
    it 'returns HealthResult on timeout' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      allow(Lich::Messaging).to receive(:msg)
      result = described_class.check_health
      expect(result).to be_a(described_class::HealthResult)
      expect(result.score).to eq(0)
    end

    it 'logs timeout message' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(Lich::Messaging).to receive(:msg).with('bold', /DRCH:.*timeout/)
      described_class.check_health
    end

    it 'parses successful health output' do
      raw_lines = [
        '<output class=""/>Your body feels at full strength.',
        'Your spirit feels full of life.',
        'You have some tiny scratches to the neck.'
      ]
      allow(Lich::Util).to receive(:issue_command).and_return(raw_lines)
      result = described_class.check_health
      expect(result).to be_a(described_class::HealthResult)
      expect(result.wounds).not_to be_empty
    end

    it 'calls issue_command with correct params' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      allow(Lich::Messaging).to receive(:msg)
      expect(Lich::Util).to receive(:issue_command).with(
        'health',
        /^Your body feels\b/,
        /<prompt/,
        hash_including(usexml: true, quiet: true, include_end: false)
      )
      described_class.check_health
    end
  end

  describe '.perceive_health' do
    before do
      allow(Lich::Messaging).to receive(:msg)
    end

    it 'returns nil when not an empath' do
      allow(DRStats).to receive(:empath?).and_return(false)
      expect(described_class.perceive_health).to be_nil
    end

    it 'logs messaging when not an empath' do
      allow(DRStats).to receive(:empath?).and_return(false)
      expect(Lich::Messaging).to receive(:msg).with('bold', /DRCH:.*empath/)
      described_class.perceive_health
    end

    it 'returns nil on timeout' do
      allow(DRStats).to receive(:empath?).and_return(true)
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(described_class.perceive_health).to be_nil
    end

    it 'logs timeout message' do
      allow(DRStats).to receive(:empath?).and_return(true)
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(Lich::Messaging).to receive(:msg).with('bold', /DRCH:.*PERCEIVE HEALTH.*timeout/)
      described_class.perceive_health
    end

    it 'falls back to check_health when permashocked' do
      allow(DRStats).to receive(:empath?).and_return(true)
      allow(described_class).to receive(:waitrt?)
      permashock_lines = ['You feel only an aching emptiness where your sense of empathy should be.']
      allow(Lich::Util).to receive(:issue_command).and_return(permashock_lines)
      # check_health will be called as fallback
      health_result = described_class::HealthResult.new(score: 5)
      allow(described_class).to receive(:check_health).and_return(health_result)
      result = described_class.perceive_health
      expect(result.score).to eq(5)
    end
  end

  describe '.perceive_health_other' do
    before do
      allow(Lich::Messaging).to receive(:msg)
    end

    it 'returns nil when not an empath' do
      allow(DRStats).to receive(:empath?).and_return(false)
      expect(described_class.perceive_health_other('Muleoak')).to be_nil
    end

    it 'returns nil on timeout' do
      allow(DRStats).to receive(:empath?).and_return(true)
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(described_class.perceive_health_other('Muleoak')).to be_nil
    end

    it 'returns nil when touch fails' do
      allow(DRStats).to receive(:empath?).and_return(true)
      allow(Lich::Util).to receive(:issue_command).and_return(['Touch what?'])
      expect(described_class.perceive_health_other('Muleoak')).to be_nil
    end

    it 'returns nil when target avoids touch' do
      allow(DRStats).to receive(:empath?).and_return(true)
      allow(Lich::Util).to receive(:issue_command).and_return(['Muleoak avoids your touch.'])
      expect(described_class.perceive_health_other('Muleoak')).to be_nil
    end

    it 'logs unable message on touch failure' do
      allow(DRStats).to receive(:empath?).and_return(true)
      allow(Lich::Util).to receive(:issue_command).and_return(['Touch what?'])
      expect(Lich::Messaging).to receive(:msg).with('bold', /DRCH:.*Unable.*Muleoak/)
      described_class.perceive_health_other('Muleoak')
    end

    it 'extracts character name from empathic link message' do
      allow(DRStats).to receive(:empath?).and_return(true)
      touch_lines = [
        'You sense a successful empathic link has been forged between you and Muleoak.',
        'Wounds to the HEAD:',
        'Fresh External:  light scratches -- negligible'
      ]
      allow(Lich::Util).to receive(:issue_command).and_return(touch_lines)
      result = described_class.perceive_health_other('mule')
      expect(result).to be_a(described_class::HealthResult)
    end
  end

  describe '.bind_wound' do
    before do
      allow(described_class).to receive(:waitrt?)
    end

    it 'returns true on successful tend' do
      allow(DRC).to receive(:bput).and_return('You work carefully at tending your wound.')
      expect(described_class.bind_wound('right arm')).to be true
    end

    it 'returns true when already tended' do
      allow(DRC).to receive(:bput).and_return('That area has already been tended to.')
      expect(described_class.bind_wound('right arm')).to be true
    end

    it 'returns false on fumble' do
      allow(DRC).to receive(:bput).and_return('You fumble around with the bandages.')
      expect(described_class.bind_wound('right arm')).to be false
    end

    it 'returns false when too injured' do
      allow(DRC).to receive(:bput).and_return('You are too injured for you to do that.')
      expect(described_class.bind_wound('right arm')).to be false
    end

    it 'returns false when no free hand' do
      allow(DRC).to receive(:bput).and_return('You must have a hand free to tend a wound.')
      expect(described_class.bind_wound('right arm')).to be false
    end

    it 'passes person parameter to bput' do
      expect(DRC).to receive(:bput).with('tend Muleoak right arm', any_args).and_return('You work carefully at tending')
      described_class.bind_wound('right arm', 'Muleoak')
    end
  end

  describe '.unwrap_wound' do
    before do
      allow(described_class).to receive(:waitrt?)
    end

    it 'calls bput with unwrap command' do
      expect(DRC).to receive(:bput).with('unwrap my right arm', any_args)
      described_class.unwrap_wound('right arm')
    end

    it 'passes person parameter' do
      expect(DRC).to receive(:bput).with('unwrap Muleoak chest', any_args)
      described_class.unwrap_wound('chest', 'Muleoak')
    end
  end

  describe '.has_tendable_bleeders?' do
    it 'delegates to check_health result' do
      health_result = described_class::HealthResult.new
      allow(described_class).to receive(:check_health).and_return(health_result)
      expect(described_class.has_tendable_bleeders?).to be false
    end
  end

  # ─── Data constants ──────────────────────────────────────────────────

  describe 'data constants' do
    it 'freezes BLEED_RATE_TO_SEVERITY' do
      expect(described_class::BLEED_RATE_TO_SEVERITY).to be_frozen
    end

    it 'freezes inner hashes of BLEED_RATE_TO_SEVERITY' do
      described_class::BLEED_RATE_TO_SEVERITY.each_value do |info|
        expect(info).to be_frozen
      end
    end

    it 'freezes WOUND_SEVERITY_REGEX_MAP' do
      expect(described_class::WOUND_SEVERITY_REGEX_MAP).to be_frozen
    end

    it 'freezes inner hashes of WOUND_SEVERITY_REGEX_MAP' do
      described_class::WOUND_SEVERITY_REGEX_MAP.each_value do |template|
        expect(template).to be_frozen
      end
    end

    it 'freezes PARASITES_REGEX' do
      expect(described_class::PARASITES_REGEX).to be_frozen
    end

    it 'freezes LODGED_SEVERITY' do
      expect(described_class::LODGED_SEVERITY).to be_frozen
    end

    it 'freezes WOUND_SEVERITY' do
      expect(described_class::WOUND_SEVERITY).to be_frozen
    end

    it 'freezes TEND_SUCCESS_PATTERNS' do
      expect(described_class::TEND_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes TEND_FAILURE_PATTERNS' do
      expect(described_class::TEND_FAILURE_PATTERNS).to be_frozen
    end

    it 'freezes TEND_DISLODGE_PATTERNS' do
      expect(described_class::TEND_DISLODGE_PATTERNS).to be_frozen
    end

    it 'has backward-compat global aliases' do
      expect($DRCH_BLEED_RATE_TO_SEVERITY_MAP).to equal(described_class::BLEED_RATE_TO_SEVERITY)
      expect($DRCH_WOUND_TO_SEVERITY_MAP).to equal(described_class::WOUND_SEVERITY)
      expect($DRCH_PARASITES_REGEX_LIST).to equal(described_class::PARASITES_REGEX)
      expect($DRCH_PERCEIVE_HEALTH_SEVERITY_REGEX).to eq(described_class::PERCEIVE_HEALTH_SEVERITY_REGEX)
      expect($DRCH_WOUND_BODY_PART_REGEX).to eq(described_class::WOUND_BODY_PART_REGEX)
      expect($DRCH_LODGED_BODY_PART_REGEX).to eq(described_class::LODGED_BODY_PART_REGEX)
      expect($DRCH_PARASITE_BODY_PART_REGEX).to eq(described_class::PARASITE_BODY_PART_REGEX)
      expect($DRCH_WOUND_SEVERITY_REGEX_MAP).to equal(described_class::WOUND_SEVERITY_REGEX_MAP)
      expect($DRCH_WOUND_COMMA_SEPARATOR).to eq(described_class::WOUND_COMMA_SEPARATOR)
    end

    it 'has all bleed rate entries' do
      # Verify representative entries
      expect(described_class::BLEED_RATE_TO_SEVERITY['slight'][:severity]).to eq(3)
      expect(described_class::BLEED_RATE_TO_SEVERITY['death awaits'][:severity]).to eq(22)
      expect(described_class::BLEED_RATE_TO_SEVERITY['tended'][:bleeding]).to be false
      expect(described_class::BLEED_RATE_TO_SEVERITY['moderate'][:bleeding]).to be true
    end

    it 'has all lodged severity entries' do
      expect(described_class::LODGED_SEVERITY['loosely hanging']).to eq(1)
      expect(described_class::LODGED_SEVERITY['savagely']).to eq(5)
    end

    it 'has all wound severity entries' do
      expect(described_class::WOUND_SEVERITY['insignificant']).to eq(1)
      expect(described_class::WOUND_SEVERITY['useless']).to eq(13)
    end
  end
end
