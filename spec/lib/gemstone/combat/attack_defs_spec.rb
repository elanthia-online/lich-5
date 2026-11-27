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
      expect(defs.attackerless_line?('Bitter cold leaches warmth from your skin.')).to be true
      expect(defs.attackerless_line?('You feel more refreshed.')).to be false
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

    it 'matches 335 Divine Wrath shadowy black rose with a pronoun tail (Laethe 3p form)' do
      # GSWiki's 3p form ends "...into it." rather than repeating the target.
      line = "A shadowy black rose touches #{bolded(452450877, 'berserker', 'a tattooed gigas berserker')} and wraps immediately about it, struggling to force its long, barbed thorns into it."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:divine_wrath)
      expect(result[:target][:id]).to eq(452450877)
    end

    it 'matches 335 Divine Wrath Marlu black mist 3p form (groupmate cast, pronoun tails)' do
      # Log-confirmed: named once, then "her" twice.
      line = "As #{bolded(452450877, 'conjurer', 'a gaudy phantasmic conjurer')} comes too close to a tendril of black mist, the mist suddenly expands into a large black cloud, which rapidly surrounds her, obliterating her from view."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:divine_wrath)
      expect(result[:target][:id]).to eq(452450877)
    end

    it 'matches 335 Divine Wrath shadowy black rose with a repeated-target tail' do
      line = "A shadowy black rose touches #{bolded(452450877, 'berserker', 'a tattooed gigas berserker')} and wraps immediately about it, struggling to force its long, barbed thorns into the tattooed gigas berserker."
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

  # Round-9 inbound forms (elanthia-online/lich-5#2498). Each line is lifted
  # from GS4 XML logs exactly as the game sent it; every one used to leave the
  # AS/CS roll, damage or outcome that follows it with no event to attach to.
  describe ".parse_attack round-9 inbound forms (#2498)" do
    [
      "Surging forward powerfully, <pushBold/>a <a exist=\"41138485\" noun=\"myrmidon\">chitinous kiramon myrmidon</a><popBold/> slashes at you with <pushBold/><a exist=\"41138485\" noun=\"myrmidon\">his</a><popBold/> bladed forelegs!",
      "<pushBold/>A <a exist=\"129633263\" noun=\"dreadsteed\">smouldering skeletal dreadsteed</a><popBold/> gallops into a deadly charge at you!",
      "Without warning, <pushBold/>a <a exist=\"24997331\" noun=\"stalker\">sleek black kiramon stalker</a><popBold/> glides from the shadows and skitters mercilessly forward to slash at you with a razor-sharp foreleg!",
      "<pushBold/>A <a exist=\"368709649\" noun=\"warhorse\">skeletal warhorse</a><popBold/> stomps at you with its foot!",
      "<pushBold/>A <a exist=\"129570615\" noun=\"dreadsteed\">smouldering skeletal dreadsteed</a><popBold/> rears up onto <pushBold/><a exist=\"129570615\" noun=\"dreadsteed\">its</a><popBold/> ossified hind legs and kicks at you with steel-shod hooves!",
      "Bringing <pushBold/><a exist=\"39990558\" noun=\"myrmidon\">its</a><popBold/> forelegs together, <pushBold/>a <a exist=\"39990558\" noun=\"myrmidon\">chitinous kiramon myrmidon</a><popBold/> attempts to pincer you!",
      "<pushBold/>A <a exist=\"211525185\" noun=\"warden\">triton warden</a><popBold/> places one hand on top of the other, crossing <pushBold/><a exist=\"211525185\" noun=\"warden\">his</a><popBold/> palms toward you!",
      "<pushBold/>A <a exist=\"26221097\" noun=\"stalker\">grizzled kiramon stalker</a><popBold/> aims a preternaturally swift bite at you!",
      "Without warning, <pushBold/>a <a exist=\"40724863\" noun=\"stalker\">sleek black kiramon stalker</a><popBold/> glides from the shadows and aims a preternaturally swift bite at you!",
      "Several larvae squirming over the back of <pushBold/>a <a exist=\"40625111\" noun=\"broodtender\">bloated kiramon broodtender</a><popBold/> leap toward you, mandibles snapping.",
      "<pushBold/>A <a exist=\"39945617\" noun=\"thrall\">disfigured hive thrall</a><popBold/> flails at you with <pushBold/><a exist=\"39945617\" noun=\"thrall\">his</a><popBold/> tortured fists!",
      "<pushBold/>A <a exist=\"129762371\" noun=\"banshee\">flickering mist-wreathed banshee</a><popBold/> lifts <pushBold/><a exist=\"129762371\" noun=\"banshee\">her</a><popBold/> voice in a terrible screech at you!",
      "<pushBold/>A <a exist=\"190099458\" noun=\"psionicist\">gleaming triton psionicist</a><popBold/> levitates a jagged piece of rock at you!",
      "<pushBold/>A <a exist=\"130432872\" noun=\"banshee\">flickering mist-wreathed banshee's</a><popBold/> shrieking takes on a sepulchral resonance!  <pushBold/>A <a exist=\"130432872\" noun=\"banshee\">flickering mist-wreathed banshee</a><popBold/> lifts <pushBold/><a exist=\"130432872\" noun=\"banshee\">her</a><popBold/> voice in a terrible screech at you!",
      "<pushBold/>A <a exist=\"26221097\" noun=\"stalker\">grizzled kiramon stalker</a><popBold/> skitters mercilessly forward to slash at you with a razor-sharp foreleg!",
      "Twisted desperation contorts <pushBold/>a <a exist=\"39485159\" noun=\"thrall\">disfigured hive thrall's</a><popBold/> warped features as <pushBold/><a exist=\"39485159\" noun=\"thrall\">she</a><popBold/> tries to grab at you!",
      "<pushBold/>A <a exist=\"129567870\" noun=\"dreadsteed\">smouldering skeletal dreadsteed</a><popBold/> scrapes at the ground with a steel-shod hoof, sending off a coruscation of sparks as <pushBold/><a exist=\"129567870\" noun=\"dreadsteed\">it</a><popBold/> glares at you with eyes like burning sulphur.  <pushBold/><a exist=\"129567870\" noun=\"dreadsteed\">It</a><popBold/> charges forward at a breakneck pace, leaving fiery hoofprints behind!",
      "Misshapen limbs flail as <pushBold/>a <a exist=\"39886116\" noun=\"thrall\">disfigured hive thrall</a><popBold/> flings <pushBold/><a exist=\"39886116\" noun=\"thrall\">himself</a><popBold/> at you!",
      "<pushBold/>A <a exist=\"368859587\" noun=\"pra'eda\">pra'eda</a><popBold/> points its hands at you!",
      "<pushBold/>A <a exist=\"366962439\" noun=\"cleric\">shan cleric</a><popBold/> waves a hand dismissively at you!",
      "<pushBold/>A <a exist=\"9764796\" noun=\"marauder\">dwarven marauder</a><popBold/> pulls out a tiny shard of jet black crystal and hurls it at you!",
      "Catching you unaware, <pushBold/><a exist=\"18495497\" noun=\" stalker\">it</a><popBold/> carves into you with cruel and ruthless savagery!",
      "<pushBold/>A <a exist=\"18372629\" noun=\"thrall\">disfigured hive thrall's</a><popBold/> eyes widen as <pushBold/><a exist=\"18372629\" noun=\"thrall\">she</a><popBold/> topples forward, belching caustic bile at you!",
      "<pushBold/>A <a exist=\"151202451\" noun=\"brawler\">triton brawler</a><popBold/> raises <pushBold/><a exist=\"151202451\" noun=\"brawler\">his</a><popBold/> hands high, laces them together and brings them crashing down towards you!",
      "<pushBold/>A <a exist=\"135091696\" noun=\"dreadsteed\">smouldering skeletal dreadsteed</a><popBold/> slams <pushBold/><a exist=\"135091696\" noun=\"dreadsteed\">its</a><popBold/> head into you!",
      "<pushBold/>A <a exist=\"134766950\" noun=\"conjurer\">gaudy phantasmic conjurer</a><popBold/> shouts out a single mystical syllable, thrusting <pushBold/><a exist=\"134766950\" noun=\"conjurer\">her</a><popBold/> ghostly hands at you!",
      "<pushBold/>A <a exist=\"134686168\" noun=\"ghast\">cadaverous tatterdemalion ghast</a><popBold/> coils before leaping high into the air in a streak of fraying fabrics and rotting flesh.  <pushBold/><a exist=\"134686168\" noun=\"ghast\">He</a><popBold/> hurtles down toward you with incredible force!",
      "<pushBold/>A <a exist=\"41058070\" noun=\"strandweaver\">translucent kiramon strandweaver</a><popBold/> twists grotesquely, aiming <pushBold/><a exist=\"41058070\" noun=\"strandweaver\">her</a><popBold/> spinnerets at you before shooting a clot of thick webbing!",
    ].each_with_index do |line, i|
      it "recognizes round-9 inbound form #{i + 1} as an attack on us" do
        result = described_class.parse_attack(line)
        expect(result).not_to be_nil
        expect(result[:inbound]).to be(true)
        expect(result[:target]).to eq({})
        expect(result[:attacker][:id]).to eq(line[/exist="(\d+)"/, 1].to_i)
      end
    end

    it "files the same attack on a nearby player as a foreign target" do
      line = "Surging forward powerfully, #{bolded(41138485, "myrmidon", "a chitinous kiramon myrmidon")} slashes at <a exist=\"-10000001\" noun=\"Adventurer\">Adventurer</a> with #{bolded(41138485, "myrmidon", "its")} bladed forelegs!"
      result = described_class.parse_attack(line)
      expect(result[:inbound]).to be_falsey
      expect(result[:foreign_target]).to be(true)
      expect(result[:attacker][:id]).to eq(41138485)
    end

    it "treats the boltstone apparatus as an environmental attack on us" do
      result = described_class.parse_attack("As you move past a <a exist=\"26279035\" noun=\"apparatus\">glimmering boltstone apparatus</a>, light builds within its depths before a scintillating bolt of electricity streaks toward you!")
      expect(result[:name]).to eq(:boltstone_trap)
      expect(result[:inbound]).to be(true)
      expect(result[:attacker]).to eq({ name: "environment" })
    end

    # Lead-ins: a known attack line sits between these and the roll, so they
    # must not open an event of their own; nor may the topple,
    # a crit rider of OUR attack (its SMR precedes it).
    [
      "Despite desperate windmilling to catch <pushBold/><a exist=\"127052240\" noun=\"grotesque\">its</a><popBold/> balance, <pushBold/>a <a exist=\"127052240\" noun=\"grotesque\">horned basalt grotesque</a><popBold/> topples toward you!  You leap to the side and avoid being flattened as <pushBold/>the <a exist=\"127052240\" noun=\"grotesque\">grotesque</a><popBold/> topples over with a thunderous crash!",
      "In an awe-inspiring display of combat mastery, <pushBold/>a <a exist=\"148107057\" noun=\"protector\">spectral triton protector</a><popBold/> engages you in a furious dance macabre, spiraling into a blur of strikes and ripostes!",
      "One of the vines surrounding <pushBold/>the <a exist=\"148536136\" noun=\"warden\">triton warden</a><popBold/> lashes out at you, driving a thorn into your skin!  You feel poison coursing through your veins.",
      "<pushBold/>A <a exist=\"127072516\" noun=\"grotesque\">horned basalt grotesque</a><popBold/> twists a stony claw toward you!",
      "<pushBold/>A <a exist=\"366962081\" noun=\"ranger\">shan ranger</a><popBold/> nods at you!",
      "<pushBold/>A <a exist=\"368884496\" noun=\"mezic\">grizzled mezic</a><popBold/> waves at you!",
      "<pushBold/>A <a exist=\"18519282\" noun=\"thrall\">disfigured hive thrall</a><popBold/> desperately thrusts a hand at you!",
    ].each_with_index do |line, i|
      it "leaves lead-in #{i + 1} alone" do
        expect(described_class.parse_attack(line)).to be_nil
      end
    end
  end
end
