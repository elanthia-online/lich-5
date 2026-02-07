require 'rspec'

LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-healing-data.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-healing.rb')

# Define DRSkill inside the same namespace that common-healing.rb resolves it from.
# Must be a class (not module) to match the real DRSkill definition in drskill.rb.
# When running alongside drskill_spec, the real class is already loaded here.
class Lich::DragonRealms::DRSkill
  def self.getrank(_skill)
    0
  end
end unless defined?(Lich::DragonRealms::DRSkill)

# Top-level alias matching the pattern used by drskill_spec.
DRSkill = Lich::DragonRealms::DRSkill unless defined?(DRSkill)

DRCH = Lich::DragonRealms::DRCH

RSpec.describe DRCH do
  # ─── Wound class ──────────────────────────────────────────────────────

  describe DRCH::Wound do
    describe '#initialize' do
      it 'downcases body_part and bleeding_rate' do
        wound = DRCH::Wound.new(body_part: 'LEFT ARM', bleeding_rate: 'SLIGHT')
        expect(wound.body_part).to eq('left arm')
        expect(wound.bleeding_rate).to eq('slight')
      end

      it 'handles nil body_part and bleeding_rate' do
        wound = DRCH::Wound.new
        expect(wound.body_part).to be_nil
        expect(wound.severity).to be_nil
        expect(wound.bleeding_rate).to be_nil
      end

      it 'coerces boolean flags' do
        wound = DRCH::Wound.new(is_internal: 'truthy', is_scar: nil)
        expect(wound.internal?).to be true
        expect(wound.scar?).to be false
      end
    end

    describe '#bleeding?' do
      it 'returns true for active bleed rates' do
        wound = DRCH::Wound.new(bleeding_rate: 'slight')
        expect(wound.bleeding?).to be true
      end

      it 'returns false for (tended)' do
        wound = DRCH::Wound.new(bleeding_rate: '(tended)')
        expect(wound.bleeding?).to be false
      end

      it 'returns false for nil bleeding_rate' do
        wound = DRCH::Wound.new
        expect(wound.bleeding?).to be false
      end
    end

    describe '#tendable?' do
      it 'returns true for parasites' do
        wound = DRCH::Wound.new(is_parasite: true)
        expect(wound.tendable?).to be true
      end

      it 'returns true for lodged items' do
        wound = DRCH::Wound.new(is_lodged_item: true)
        expect(wound.tendable?).to be true
      end

      it 'returns false for skin wounds' do
        wound = DRCH::Wound.new(body_part: 'skin', bleeding_rate: 'slight')
        expect(wound.tendable?).to be false
      end

      it 'returns false for tended wounds' do
        wound = DRCH::Wound.new(body_part: 'right arm', bleeding_rate: '(tended)')
        expect(wound.tendable?).to be false
      end

      it 'returns true for bleeding wound when skilled' do
        allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
        wound = DRCH::Wound.new(body_part: 'right arm', bleeding_rate: 'slight')
        expect(wound.tendable?).to be true
      end

      it 'returns false when unskilled' do
        allow(DRSkill).to receive(:getrank).with('First Aid').and_return(0)
        wound = DRCH::Wound.new(body_part: 'right arm', bleeding_rate: 'slight')
        expect(wound.tendable?).to be false
      end
    end

    describe '#location' do
      it 'returns external for non-internal wounds' do
        expect(DRCH::Wound.new.location).to eq('external')
      end

      it 'returns internal for internal wounds' do
        expect(DRCH::Wound.new(is_internal: true).location).to eq('internal')
      end
    end

    describe '#type' do
      it 'returns wound for fresh wounds' do
        expect(DRCH::Wound.new.type).to eq('wound')
      end

      it 'returns scar for scars' do
        expect(DRCH::Wound.new(is_scar: true).type).to eq('scar')
      end
    end

    describe '#to_h' do
      it 'returns a hash of all fields' do
        wound = DRCH::Wound.new(body_part: 'chest', severity: 5, is_internal: true)
        h = wound.to_h
        expect(h[:body_part]).to eq('chest')
        expect(h[:severity]).to eq(5)
        expect(h[:internal]).to be true
        expect(h[:scar]).to be false
      end
    end

    describe '#to_s' do
      it 'includes body part and severity' do
        wound = DRCH::Wound.new(body_part: 'chest', severity: 5)
        expect(wound.to_s).to include('chest')
        expect(wound.to_s).to include('severity:5')
      end
    end
  end

  # ─── HealthResult class ───────────────────────────────────────────────

  describe DRCH::HealthResult do
    describe '#initialize' do
      it 'has sensible defaults' do
        result = DRCH::HealthResult.new
        expect(result.wounds).to eq({})
        expect(result.bleeders).to eq({})
        expect(result.poisoned).to be false
        expect(result.diseased).to be false
        expect(result.score).to eq(0)
        expect(result.dead).to be false
      end
    end

    describe '#[]' do
      it 'provides backward-compatible string key access' do
        result = DRCH::HealthResult.new(poisoned: true, score: 42)
        expect(result['poisoned']).to be true
        expect(result['score']).to eq(42)
        expect(result['wounds']).to eq({})
      end
    end

    describe '#injured?' do
      it 'returns false for score 0' do
        expect(DRCH::HealthResult.new.injured?).to be false
      end

      it 'returns true for positive score' do
        expect(DRCH::HealthResult.new(score: 5).injured?).to be true
      end
    end

    describe '#bleeding?' do
      it 'returns false with no bleeders' do
        expect(DRCH::HealthResult.new.bleeding?).to be false
      end

      it 'returns true with active bleeders' do
        bleeders = { 3 => [DRCH::Wound.new(body_part: 'arm', bleeding_rate: 'slight')] }
        result = DRCH::HealthResult.new(bleeders: bleeders)
        expect(result.bleeding?).to be true
      end
    end

    describe '#has_tendable_bleeders?' do
      it 'returns false with no bleeders' do
        expect(DRCH::HealthResult.new.has_tendable_bleeders?).to be false
      end

      it 'returns true with tendable bleeders' do
        allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
        bleeders = { 3 => [DRCH::Wound.new(body_part: 'arm', bleeding_rate: 'slight')] }
        result = DRCH::HealthResult.new(bleeders: bleeders)
        expect(result.has_tendable_bleeders?).to be true
      end
    end
  end

  # ─── strip_xml ────────────────────────────────────────────────────────

  describe '.strip_xml' do
    it 'removes XML tags' do
      lines = ['<pushStream id="familiar">Some text</pushStream>']
      expect(DRCH.strip_xml(lines)).to eq(['Some text'])
    end

    it 'decodes HTML entities' do
      lines = ['You say &gt; hello &lt; world']
      expect(DRCH.strip_xml(lines)).to eq(['You say > hello < world'])
    end

    it 'strips whitespace and rejects empty lines' do
      lines = ['  hello  ', '', '   ', 'world']
      expect(DRCH.strip_xml(lines)).to eq(%w[hello world])
    end

    it 'removes inline XML tags' do
      lines = ['<output class=""/>Your body feels at full strength.']
      expect(DRCH.strip_xml(lines)).to eq(['Your body feels at full strength.'])
    end
  end

  # ─── calculate_score ──────────────────────────────────────────────────

  describe '.calculate_score' do
    it 'returns 0 for no wounds' do
      expect(DRCH.calculate_score({})).to eq(0)
    end

    it 'calculates quadratic score' do
      wounds = {
        1 => [DRCH::Wound.new],
        3 => [DRCH::Wound.new, DRCH::Wound.new]
      }
      # 1^2 * 1 + 3^2 * 2 = 1 + 18 = 19
      expect(DRCH.calculate_score(wounds)).to eq(19)
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
      result = DRCH.parse_health_lines(lines)
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
      result = DRCH.parse_health_lines(lines)
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
      result = DRCH.parse_health_lines(lines)
      expect(result.poisoned).to be true
    end

    it 'detects disease' do
      lines = [
        'Your body feels beat up.',
        'Your spirit feels full of life.',
        'You have some minor abrasions to the right arm.',
        'Your body is covered in open oozing sores.'
      ]
      result = DRCH.parse_health_lines(lines)
      expect(result.diseased).to be true
    end

    it 'ignores fatigue lines' do
      lines = [
        'Your body feels at full strength.',
        'You are slightly fatigued.',
        'Your spirit feels full of life.',
        'You have no significant injuries.'
      ]
      result = DRCH.parse_health_lines(lines)
      expect(result.wounds).to be_empty
      expect(result.poisoned).to be false
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
      result = DRCH.parse_health_lines(lines)
      expect(result.bleeders).not_to be_empty
      bleeders = result.bleeders.values.flatten
      expect(bleeders.length).to eq(1)
      expect(bleeders.first.body_part).to eq('tail')
      expect(bleeders.first.bleeding_rate).to eq('slight')
    end

    it 'detects both internal and external bleeders' do
      lines = [
        'Your body feels in bad shape.',
        'Your spirit feels full of life.',
        'You have a severely swollen and deeply bruised right leg compounded by deep cuts across the right leg.',
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'right leg       slight',
        'inside r. leg       slight'
      ]
      result = DRCH.parse_health_lines(lines)
      bleeders = result.bleeders.values.flatten
      expect(bleeders.length).to eq(2)
      external = bleeders.find { |w| !w.internal? }
      internal = bleeders.find { |w| w.internal? }
      expect(external.body_part).to eq('right leg')
      expect(internal.body_part).to eq('right leg')
    end

    it 'detects lodged items' do
      lines = [
        'Your body feels at full strength.',
        'Your spirit feels full of life.',
        'You are slightly fatigued.',
        'You have cuts and bruises about the chest area.',
        'You have a retch maggot lodged firmly into your chest.',
        'You feel fully rested.'
      ]
      result = DRCH.parse_health_lines(lines)
      lodged = result.lodged.values.flatten
      expect(lodged.length).to eq(1)
      expect(lodged.first.body_part).to eq('chest')
      expect(lodged.first.lodged?).to be true
    end
  end

  # ─── parse_bleeders ──────────────────────────────────────────────────

  describe '.parse_bleeders' do
    it 'returns empty hash when no bleeding section' do
      lines = [
        'Your body feels at full strength.',
        'You have no significant injuries.'
      ]
      expect(DRCH.parse_bleeders(lines)).to be_empty
    end

    it 'parses external bleeders' do
      lines = [
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'tail       slight'
      ]
      bleeders = DRCH.parse_bleeders(lines)
      expect(bleeders.values.flatten.length).to eq(1)
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
      bleeders = DRCH.parse_bleeders(lines)
      wound = bleeders.values.flatten.first
      expect(wound.body_part).to eq('right arm')
      expect(wound.internal?).to be true
    end

    it 'parses tended bleeders' do
      lines = [
        'Bleeding',
        'Area       Rate',
        '-----------------------------------------',
        'right arm       (tended)'
      ]
      bleeders = DRCH.parse_bleeders(lines)
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
      bleeders = DRCH.parse_bleeders(lines)
      all_bleeders = bleeders.values.flatten
      expect(all_bleeders.length).to eq(5)
    end
  end

  # ─── parse_wounds ────────────────────────────────────────────────────

  describe '.parse_wounds' do
    it 'returns empty hash for nil' do
      expect(DRCH.parse_wounds(nil)).to be_empty
    end

    it 'parses simple wound' do
      line = 'You have some tiny scratches to the neck.'
      wounds = DRCH.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds.length).to eq(1)
      expect(all_wounds.first.body_part).to eq('neck')
      expect(all_wounds.first.severity).to eq(2) # negligible
    end

    it 'parses multiple wounds in comma-separated line' do
      line = 'You have some tiny scratches to the neck, some minor abrasions to the left hand, some tiny scratches to the chest.'
      wounds = DRCH.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds.length).to eq(3)
      body_parts = all_wounds.map(&:body_part)
      expect(body_parts).to include('neck', 'left hand', 'chest')
    end

    it 'parses compounded wounds correctly (comma within wound text)' do
      line = 'You have minor swelling and bruising around the left arm compounded by cuts and bruises about the left arm.'
      wounds = DRCH.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds.length).to eq(2)
      expect(all_wounds.any? { |w| w.internal? }).to be true
      expect(all_wounds.any? { |w| !w.internal? }).to be true
    end

    it 'parses skin wounds' do
      line = 'You have a small skin rash.'
      wounds = DRCH.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds.length).to eq(1)
    end

    it 'parses internal twitching wounds' do
      line = 'You have an occasional twitching in the left leg.'
      wounds = DRCH.parse_wounds(line)
      all_wounds = wounds.values.flatten
      expect(all_wounds).not_to be_empty
      expect(all_wounds.any? { |w| w.internal? && w.scar? }).to be true
    end
  end

  # ─── parse_parasites ─────────────────────────────────────────────────

  describe '.parse_parasites' do
    it 'returns empty hash for nil' do
      expect(DRCH.parse_parasites(nil)).to be_empty
    end

    it 'parses a parasite on a body part' do
      line = 'You have a retch maggot on your chest.'
      parasites = DRCH.parse_parasites(line)
      all_parasites = parasites.values.flatten
      expect(all_parasites.length).to eq(1)
      expect(all_parasites.first.body_part).to eq('chest')
      expect(all_parasites.first.parasite?).to be true
    end
  end

  # ─── parse_lodged_items ──────────────────────────────────────────────

  describe '.parse_lodged_items' do
    it 'returns empty hash for nil' do
      expect(DRCH.parse_lodged_items(nil)).to be_empty
    end

    it 'parses a lodged item' do
      line = 'You have a retch maggot lodged firmly into your chest.'
      lodged = DRCH.parse_lodged_items(line)
      all_lodged = lodged.values.flatten
      expect(all_lodged.length).to eq(1)
      expect(all_lodged.first.body_part).to eq('chest')
      expect(all_lodged.first.lodged?).to be true
      expect(all_lodged.first.severity).to eq(3) # firmly = 3
    end
  end

  # ─── parse_perceived_health_lines ────────────────────────────────────

  describe '.parse_perceived_health_lines' do
    it 'parses wound details from perceive output' do
      lines = [
        "Your injuries include...",
        "Wounds to the HEAD:",
        "Fresh External:  light scratches -- negligible",
        "Wounds to the LEFT ARM:",
        "Fresh External:  cuts and bruises -- minor",
        "Fresh Internal:  minor swelling and bruising -- minor",
        "Roundtime: 5 sec."
      ]
      result = DRCH.parse_perceived_health_lines(lines)
      all_wounds = result.wounds.values.flatten
      expect(all_wounds.length).to eq(3)

      head_wound = all_wounds.find { |w| w.body_part == 'head' }
      expect(head_wound).not_to be_nil
      expect(head_wound.severity).to eq(2) # negligible
      expect(head_wound.internal?).to be false
      expect(head_wound.scar?).to be false

      arm_wounds = all_wounds.select { |w| w.body_part == 'left arm' }
      expect(arm_wounds.length).to eq(2)
      expect(arm_wounds.any? { |w| w.internal? }).to be true
    end

    it 'parses scars' do
      lines = [
        "Your injuries include...",
        "Wounds to the RIGHT LEG:",
        "Scars External:  minor scarring -- minor"
      ]
      result = DRCH.parse_perceived_health_lines(lines)
      wound = result.wounds.values.flatten.first
      expect(wound.scar?).to be true
    end

    it 'detects dead target' do
      lines = [
        "She is dead."
      ]
      result = DRCH.parse_perceived_health_lines(lines)
      expect(result.dead).to be true
    end

    it 'detects poisoned target' do
      lines = [
        "Muleoak has a mildly poisoned right leg."
      ]
      result = DRCH.parse_perceived_health_lines(lines)
      expect(result.poisoned).to be true
    end

    it 'detects diseased target' do
      lines = [
        "Muleoak wounds are infected."
      ]
      result = DRCH.parse_perceived_health_lines(lines)
      expect(result.diseased).to be true
    end

    it 'calculates score from perceived wounds' do
      lines = [
        "Your injuries include...",
        "Wounds to the HEAD:",
        "Fresh External:  light scratches -- negligible"
      ]
      result = DRCH.parse_perceived_health_lines(lines)
      # severity 2 (negligible), 1 wound: 2^2 * 1 = 4
      expect(result.score).to eq(4)
    end
  end

  # ─── skilled_to_tend_wound? ──────────────────────────────────────────

  describe '.skilled_to_tend_wound?' do
    it 'returns true when skilled enough' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
      expect(DRCH.skilled_to_tend_wound?('slight')).to be true
    end

    it 'returns false when unskilled' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(0)
      expect(DRCH.skilled_to_tend_wound?('slight')).to be false
    end

    it 'returns false for unknown bleed rate' do
      expect(DRCH.skilled_to_tend_wound?('nonexistent')).to be false
    end

    it 'returns false for tended wounds' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
      expect(DRCH.skilled_to_tend_wound?('(tended)')).to be false
    end

    it 'requires higher skill for internal wounds' do
      allow(DRSkill).to receive(:getrank).with('First Aid').and_return(100)
      expect(DRCH.skilled_to_tend_wound?('slight', false)).to be true  # external: 30
      expect(DRCH.skilled_to_tend_wound?('slight', true)).to be false  # internal: 600
    end
  end

  # ─── Data constants ──────────────────────────────────────────────────

  describe 'data constants' do
    it 'freezes BLEED_RATE_TO_SEVERITY' do
      expect(DRCH::BLEED_RATE_TO_SEVERITY).to be_frozen
    end

    it 'freezes inner hashes of BLEED_RATE_TO_SEVERITY' do
      DRCH::BLEED_RATE_TO_SEVERITY.each_value do |info|
        expect(info).to be_frozen
      end
    end

    it 'freezes WOUND_SEVERITY_REGEX_MAP' do
      expect(DRCH::WOUND_SEVERITY_REGEX_MAP).to be_frozen
    end

    it 'freezes PARASITES_REGEX' do
      expect(DRCH::PARASITES_REGEX).to be_frozen
    end

    it 'has backward-compat global aliases' do
      expect($DRCH_BLEED_RATE_TO_SEVERITY_MAP).to equal(DRCH::BLEED_RATE_TO_SEVERITY)
      expect($DRCH_WOUND_TO_SEVERITY_MAP).to equal(DRCH::WOUND_SEVERITY)
      expect($DRCH_PARASITES_REGEX_LIST).to equal(DRCH::PARASITES_REGEX)
    end
  end
end
