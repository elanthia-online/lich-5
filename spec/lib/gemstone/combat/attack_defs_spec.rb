# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/defs/attacks'
require 'gemstone/combat/parser'

# Attack def coverage pinned against real game messaging (lines lifted from
# GSIV session logs, XML links intact where the game sends them). When log
# replay surfaces an unmatched variant of one of our own attacks, the fix is
# a def change - these examples keep known variants from regressing.
RSpec.describe Lich::Gemstone::Combat::Parser do
  def bolded(id, noun, name)
    %(<pushBold/><a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)
  end

  describe '.parse_attack' do
    it 'matches the summoned briar dragging its victim to the ground' do
      line = "The lashing emerald briar lashes out violently at #{bolded(452443346, 'warg', 'a niveous giant warg')}, dragging it to the ground!"
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:tangleweed)
      expect(result[:target][:id]).to eq(452443346)
    end

    it 'matches the summoned briar dragging its victim to the floor (variant found in 2026-01 logs)' do
      line = "The lashing emerald briar lashes out violently at #{bolded(452443346, 'warg', 'a niveous giant warg')}, dragging it to the floor!"
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:tangleweed)
      expect(result[:target][:id]).to eq(452443346)
    end

    it 'matches the briar entangle variant' do
      line = "The lashing emerald briar lashes out at #{bolded(452440152, 'mastodon', 'a heavily armored battle mastodon')}, wraps itself around its body and entangles it on the ground."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:tangleweed)
      expect(result[:target][:id]).to eq(452440152)
    end

    it 'matches the briar entangle variant indoors ("on the floor", real-feed 2026-09-07)' do
      line = "The lashing emerald briar lashes out at #{bolded(121654846, 'berserker', 'a tattooed gigas berserker')}, wraps itself around her body and entangles her on the floor."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:tangleweed)
      expect(result[:target][:id]).to eq(121654846)
    end

    # Environmental / self-inflicted damage (real-feed 2026-09-07): no
    # attacker, no "you" capture, yet the damage is ours to take.
    it 'reports a frigid-wind cold tick as inbound damage to us' do
      result = described_class.parse_attack('The burn of the cold tears precious warmth from your flesh.')
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:frigid_wind)
      expect(result[:inbound]).to be true
      expect(result[:target]).to eq({})
    end

    it 'reports a nearby player taking the cold tick as a foreign target, not inbound' do
      result = described_class.parse_attack('Onkel shivers as the cold settles into his flesh.')
      expect(result[:name]).to eq(:frigid_wind)
      expect(result[:inbound]).to be_nil
      expect(result[:foreign_target]).to be true
    end

    it 'flags environmental tick lines for the tracker chunk gate (they carry no creature link)' do
      defs = Lich::Gemstone::Combat::Definitions::Attacks
      expect(defs.self_inflicted_line?('Bitter cold leaches warmth from your skin.')).to be true
      expect(defs.self_inflicted_line?('You feel more refreshed.')).to be false
    end

    it 'reports the thorn bow recoil as inbound damage to us' do
      line = 'As a darkened ruic longbow etched with thorns leaves your left hand, the thorns embedded in your skin painfully rip away, vines quickly retreating.  A single vine thwaps your left hand as it returns to the longbow.'
      result = described_class.parse_attack(line)
      expect(result[:name]).to eq(:thorn_recoil)
      expect(result[:inbound]).to be true
    end

    it 'matches the classic ewave messaging' do
      line = "#{bolded(98732276, 'shield-maiden', 'A brawny gigas shield-maiden')} is buffeted by the churning ethereal waves and is knocked to the ground."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:ewave)
    end

    it 'matches the dark ewave variants found in 2026 logs (waves and sphere)' do
      ['formless black waves', 'formless black sphere'].each do |phrase|
        line = "#{bolded(98732276, 'shield-maiden', 'A brawny gigas shield-maiden')} is buffeted by the #{phrase} and is knocked to the ground."
        result = described_class.parse_attack(line)
        expect(result).not_to be_nil, "expected match for #{phrase}"
        expect(result[:name]).to eq(:ewave)
      end
    end

    it 'matches 302 Bane living-target messaging' do
      line = "A sickly, violet haze encompasses #{bolded(452450877, 'mastodon', 'a heavily armored battle mastodon')}."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:bane)
      expect(result[:target][:id]).to eq(452450877)
    end

    it 'matches 335 Divine Wrath per-target materialize line' do
      line = "A shadowy figure briefly materializes behind #{bolded(452450877, 'berserker', 'a tattooed gigas berserker')}, and a silent scream courses over a tattooed gigas berserker's visage."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:divine_wrath)
      expect(result[:target][:id]).to eq(452450877)
    end

    it 'does not claim ambient spell messaging with no caster attribution' do
      # "Bloodstained light" fires identically for ANY caster's spell (seen
      # after both "Dicate gestures at..." and "You gesture at..." in logs),
      # so it must not be parsed as one of our attacks.
      line = "Bloodstained light spills down from the heavens in an undulating deluge, bathing #{bolded(416226445, 'skald', 'a grim gigas skald')}'s form in a cascade of transcendent power!"
      expect(described_class.parse_attack(line)).to be_nil
    end
  end

  # Inbound attacks (creature -> us). The only creature link on such a line
  # is the ATTACKER; before this, the line-scan fallback installed it as its
  # own target and the damage it dealt US was applied to IT (real-feed
  # replay across the log archive: 268 self-attributed attacks).
  describe '.parse_attack with inbound attacks' do
    it 'never resolves the attacker as its own target on a swing at us' do
      line = "#{bolded(31038708, 'champion', 'A muscular tattooed champion')} swings a dagger at you!"
      result = described_class.parse_attack(line)
      expect(result[:inbound]).to be(true)
      expect(result[:target][:id]).to be_nil
      expect(result[:attacker][:id]).to eq(31038708)
    end

    it 'marks a natural-weapon attack against us inbound' do
      line = "#{bolded(22764224, 'grahnk', 'A burly grahnk')} claws at you!"
      result = described_class.parse_attack(line)
      expect(result[:inbound]).to be(true)
      expect(result[:target][:id]).to be_nil
    end

    it 'marks inbound defs that name us in the pattern literal, not a capture' do
      # These have an attacker capture and NO target capture, so they also
      # fell through to the line-scan.
      line = "#{bolded(555, 'thing', 'A shadowy thing')} springs from the shadows and strikes at you!"
      result = described_class.parse_attack(line)
      expect(result[:inbound]).to be(true)
      expect(result[:target][:id]).to be_nil
    end

    it 'still resolves a creature target for our own outbound attacks' do
      line = "You swing a kelyn-edged slim short sword at #{bolded(4242, 'orc', 'a greater orc')}!"
      result = described_class.parse_attack(line)
      expect(result[:inbound]).to be_falsey
      expect(result[:target][:id]).to eq(4242)
    end

    it 'still resolves the real target when a creature attacks another creature' do
      line = "#{bolded(7, 'ogre', 'An ogre')} swings a club at #{bolded(200, 'guard', 'a guard')}!"
      result = described_class.parse_attack(line)
      expect(result[:inbound]).to be_falsey
      expect(result[:target][:id]).to eq(200)
      expect(result[:attacker][:id]).to eq(7)
    end

    it 'drops a self-referential target on an untargeted AoE' do
      # :tremors has an attacker capture and no target capture, so the
      # line-scan returned the attacker. Nothing can attack itself.
      line = "#{bolded(22219124, 'mastodon', 'A heavily armored battle mastodon')} slams a gigantic foot down, sending tremors rippling outward from the point of impact!"
      result = described_class.parse_attack(line)
      expect(result[:target][:id]).to be_nil
    end
  end

  describe '.parse_attack positioning strike' do
    it 'matches the inbound form as an attack on us' do
      line = "#{bolded(98732276, 'shield-maiden', 'A brawny gigas shield-maiden')} positions <a exist=\"98732276\" noun=\"shield-maiden\">herself</a> to attack you."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:positioning_strike)
      expect(result[:inbound]).to be true
    end

    it 'matches the third-party form as a foreign-target attack' do
      line = "#{bolded(98732276, 'berserker', 'A tattooed gigas berserker')} positions <a exist=\"98732276\" noun=\"berserker\">himself</a> to attack Dicate."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:positioning_strike)
      expect(result[:foreign_target]).to be true
    end
  end

  describe 'UCS inbound positioning' do
    it 'parses the creature tier-against-us line' do
      line = "#{bolded(452443346, 'brawler', 'The triton brawler')} has decent positioning against you."
      result = Lich::Gemstone::Combat::Definitions::UCS.parse(line)
      expect(result).not_to be_nil
      expect(result[:type]).to eq(:position_inbound)
      expect(result[:target_id]).to eq(452443346)
      expect(result[:value]).to eq('decent')
      expect(result[:tier]).to eq(1)
    end

    it 'does not confuse it with our outbound positioning' do
      line = "You have good positioning against #{bolded(452443346, 'kobold', 'a kobold')}."
      result = Lich::Gemstone::Combat::Definitions::UCS.parse(line)
      expect(result[:type]).to eq(:position)
      expect(result[:tier]).to eq(2)
    end

    it 'maps every positioning word to an ordinal tier' do
      expect(Lich::Gemstone::Combat::Definitions::UCS::POSITION_TIERS).to eq('decent' => 1, 'good' => 2, 'excellent' => 3)
    end
  end

  describe '.parse_outcome bone shatter rider' do
    it 'claims the convulsions rider across severity grades' do
      %w[mild moderate severe].each do |grade|
        line = "The gigas berserker shudders with #{grade} convulsions as pearlescent ripples envelop his body."
        expect(described_class.parse_outcome(line)).to eq(:hit), "expected :hit for #{grade}"
      end
    end
  end

  describe '.parse_flare dispel flux' do
    it 'matches all three sphere nouns as the damaging flux crit' do
      ['elemental aura', 'hazy film', 'murky veil'].each do |noun|
        line = "The #{noun} around #{bolded(452450877, 'taint', 'a festering taint')} fluxes chaotically!"
        result = described_class.parse_flare(line)
        expect(result).not_to be_nil, "expected match for #{noun}"
        expect(result[:name]).to eq(:dispel_flux)
      end
    end

    it 'does not claim the no-flux sphere strip lines' do
      ['The elemental aura around a festering taint wavers.',
       'A hazy film coats a festering taint.',
       'A murky veil surrounds an Ithzir seer.'].each do |line|
        result = described_class.parse_flare(line)
        expect(result&.[](:name)).not_to eq(:dispel_flux), "unexpected claim of: #{line}"
      end
    end
  end
end
