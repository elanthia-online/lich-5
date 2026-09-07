# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# Inbound attribution at the PROCESSOR level.
#
# parse_attack correctly reports a creature's attack on us as inbound with no
# target, but the event still flows through the target-switcher. Two separate
# leaks put the attacker back on the event, and with it the damage that
# creature dealt US:
#
#   1. the parser's line-scan fallback (covered in attack_defs_spec), and
#   2. the switcher's "first target for current event" branch - an inbound
#      event has an empty target, so ANY later creature link in the chunk
#      (a room echo, an emote) filled the slot.
#
# Leak 2 is what this spec pins. Real case (GSIV-Bodegap 2025-09-17): a
# mountain ogre killed the character for 28, then laughed - and its own
# emote handed it the 28 damage it had just dealt.
RSpec.describe Lich::Gemstone::Combat::Processor do
  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
      track_statuses: false, track_ucs: false, emit_attacks: true,
      track_damage: true, track_wounds: false
    )
    allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)
    stub_const('Lich::Gemstone::Combat::Observers', Module.new)
    allow(Lich::Gemstone::Combat::Observers).to receive(:emit)
  end

  def bolded(id, noun, name)
    %(<pushBold/><a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)
  end

  it 'does not apply a creature\'s damage to itself when it attacks us' do
    ogre = bolded(296470739, 'ogre', 'A mountain ogre')
    chunk = [
      "#{ogre} swings a cudgel at you!",
      '  AS: +176 vs DS: +76 with AvD: +20 + d100 roll: +64 = +184',
      '   ... and hits for 28 points of damage!',
      '   Smack to the eye bursts blood vessels.',
      # the emote that used to hand the ogre its own damage
      "#{ogre} throws her head back and laughs hysterically.",
      '<prompt time="1758161234">&gt;</prompt>'
    ]

    events = described_class.parse_events(chunk)
    # Contract change 2026-09-05: inbound events now EMIT (recorder
    # subscribers need them - the whole ambush family was invisible),
    # but still carry no creature-target id, so persist_event can never
    # apply the ogre's damage to the ogre. The original bug stays dead.
    expect(events.size).to eq(1)
    expect(events.first[:inbound]).to be true
    expect(events.first[:target][:id]).to be_nil
    expect(events.first[:attacker][:id]).to eq(296470739)
  end

  it 'keeps an inbound event from adopting a bystander creature as target' do
    brawler = bolded(121838976, 'brawler', 'A triton brawler')
    panther = bolded(999111, 'panther', 'a bearded woodland panther')
    chunk = [
      "You notice #{panther} nearby.",
      "#{brawler} swings a fist at you!",
      '[SMR result: 139 (Open d100: 36, Bonus: 20)]',
      '   ... 4 points of damage!',
      '<prompt time="1728940099">&gt;</prompt>'
    ]

    events = described_class.parse_events(chunk)
    expect(events.map { |e| e[:target][:id] }).not_to include(121838976, 999111)
  end

  it 'still applies our own damage to the creature we attacked' do
    orc = bolded(4242, 'orc', 'a greater orc')
    chunk = [
      "You swing a slim short sword at #{orc}!",
      '  AS: +400 vs DS: +200 with AvD: +30 + d100 roll: +50 = +280',
      '   ... and hits for 30 points of damage!',
      '<prompt time="1758161235">&gt;</prompt>'
    ]

    events = described_class.parse_events(chunk)
    expect(events.size).to eq(1)
    expect(events.first[:target][:id]).to eq(4242)
    expect(events.first[:hits].map { |h| h[:damage] }).to eq([30])
  end

  # A creature AoE that strikes a GROUP MEMBER names them by plain text
  # ("striking Sugiin!") - no link, so the event has no creature target.
  # The caster's own bolded prop (a summoned ethereal sphere) then filled
  # that empty slot through the switcher, and the group member's damage
  # was applied to the sphere (GSIV-Monstr 2025-09-30).
  it 'does not apply a group member\'s damage to the caster\'s summoned prop' do
    sphere = bolded(527976197, 'sphere', 'ethereal sphere')
    chunk = [
      "A blast of multihued plasma flares out from the center of the #{sphere}, striking Sugiin!",
      '  CS: +443 - TD: +375 + CvA: +15 + d100: +43 - -5 == +131',
      '   Warding failed!',
      '   Sugiin is stricken for 29 points of damage!',
      '   ... 4 points of damage!',
      "The #{sphere} in a brawny gigas shield-maiden's hand vanishes from sight.",
      '<prompt time="1759261782">&gt;</prompt>'
    ]

    events = described_class.parse_events(chunk)
    expect(events.map { |e| e[:target][:id] }).not_to include(527976197)
  end

  # ":ambush" ("<creature> leaps from hiding to attack!") has an attacker
  # capture, NO target capture, and never says "you" - so neither the
  # inbound nor the foreign-target rule fires. The only link in the chunk
  # is the attacker, and the switcher adopted it, applying the damage the
  # creature dealt US to itself (GSIV-Nisugi 2024-11-21).
  it 'never adopts the attacker as its own victim on a targetless 3p attack' do
    assassin = bolded(129427134, 'assassin', 'A wavering triton assassin')
    chunk = [
      "#{assassin} leaps from hiding to attack!",
      "A swirling burst of essence lashes out from #{assassin}, consuming nearby magical energy!",
      '   ... 15 points of damage!',
      '   Plasma scorches a hole in your shield arm!',
      '   You are stunned for 1 round!',
      '<prompt time="1732215987">&gt;</prompt>'
    ]

    events = described_class.parse_events(chunk)
    expect(events.map { |e| e[:target][:id] }).not_to include(129427134)
  end

  # Ambush is a MODIFIER, not an attack. "<X> leaps from hiding to strike!"
  # carries no target and no roll - the attack that follows carries both,
  # and only gains the ambush bonuses (DS pushdown + crit weighting).
  # As a def it opened a second, fact-less event per ambush (35,549
  # occurrences across the log archive).
  describe 'ambush prefix' do
    let(:ghast) { bolded(9001, 'ghast', 'a cadaverous tatterdemalion ghast') }
    let(:butch) { '<a exist="-1000" noun="Butch">Butch</a>' }

    it 'flags the following attack instead of opening its own event' do
      chunk = [
        "#{butch} leaps from hiding to strike!",
        "#{butch} attempts to punch #{ghast}!",
        '  UAF: 681 vs UDF: 575 = 1.184 * MM: 103 + d100: 9 = 130',
        '   ... and hit for 33 points of damage!',
        '<prompt time="1">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      expect(events.size).to eq(1)
      expect(events.first[:name]).to eq(:uac)
      expect(events.first[:ambush]).to be(true)
      expect(events.first[:hits].map { |h| h[:damage] }).to eq([33])
    end

    it 'leaves a normal attack unflagged' do
      chunk = [
        "You swing a short sword at #{ghast}!",
        '   ... and hits for 30 points of damage!',
        '<prompt time="2">&gt;</prompt>'
      ]

      expect(described_class.parse_events(chunk).first[:ambush]).to be(false)
    end

    it 'does not leak the flag onto a later attack' do
      chunk = [
        "#{butch} leaps from hiding to strike!",
        "#{butch} attempts to punch #{ghast}!",
        '   ... and hit for 33 points of damage!',
        "You swing a short sword at #{ghast}!",
        '   ... and hits for 10 points of damage!',
        '<prompt time="3">&gt;</prompt>'
      ]

      expect(described_class.parse_events(chunk).map { |e| e[:ambush] }).to eq([true, false])
    end

    it 'records a wholly-negated ambush via its intercept outcome' do
      # No attack line is ever printed - the prefix plus the intercept are
      # the only record that the ambush happened.
      executioner = bolded(9002, 'executioner', 'a triton executioner')
      chunk = [
        "#{executioner} leaps from hiding to attack!",
        "The thorny barrier surrounding you blocks the attack from #{executioner}!",
        '<prompt time="4">&gt;</prompt>'
      ]

      event = described_class.parse_events(chunk).first
      expect(event[:name]).to eq(:ambush)
      expect(event[:ambush]).to be(true)
      expect(event[:outcomes]).to eq([:intercept])
      expect(event[:hits]).to be_empty
    end
  end

  # The other half of the 2026-09-05 contract: parse_events SAVES
  # targetless inbound/orphan events for recorders, so persist_event must
  # emit :attack for them BEFORE its target-id guard - otherwise the whole
  # inbound universe survives parsing only to vanish at the emit seam
  # (found while wiring tools/combat_recorder.rb: the guard sat above the
  # emit, so no targetless event ever reached a subscriber live).
  it 'emits :attack for a targetless inbound event without applying it' do
    event = { name: :ambush, target: {}, inbound: true, attacker: { id: 1, name: 'x' },
              hits: [{ damage: 28, crit: nil }], statuses: [], flares: [],
              outcomes: [], resolutions: [] }

    described_class.persist_event(event)
    expect(Lich::Gemstone::Combat::Observers).to have_received(:emit).with(:attack, event)
  end

  # A nearby player's attack on a creature we can see (foreign_caster).
  # The paladin weapon-infusion proc names the caster in prose, not a
  # link, and its target IS a bolded creature - so without the
  # foreign_caster classification it matched attacker=nil/target=creature
  # and its Web/damage was credited to us (real-feed, GSIV-Nisugi
  # 2026-09-06: Heavenscent's infused Web on a gigas shield-maiden).
  describe 'foreign caster (nearby player attacks a creature)' do
    let(:maiden) { bolded(555001, 'shield-maiden', 'a brawny gigas shield-maiden') }

    it 'flags a paladin weapon-infusion proc as foreign_caster' do
      chunk = [
        "As Heavenscent attempts to strike with her star, a surge of power flows out of it, through Heavenscent, and leaps out at #{maiden}!",
        '[SMR result: 271 (Open d100: 58, Bonus: 125)]',
        "The wisps solidify into thick strands of webbing that tighten about #{maiden}!",
        '   ... 20 points of damage!',
        '<prompt time="1757183315">&gt;</prompt>'
      ]

      event = described_class.parse_events(chunk).first
      expect(event[:name]).to eq(:weapon_infusion)
      expect(event[:foreign_caster]).to be(true)
      expect(event[:attacker][:name]).to eq('Heavenscent')
      expect(event[:target][:id]).to eq(555001)
    end

    it 'does not apply a foreign caster event to the creature' do
      event = { name: :weapon_infusion, target: { id: 555001, name: 'a brawny gigas shield-maiden' },
                foreign_caster: true, attacker: { name: 'Heavenscent' },
                hits: [{ damage: 20, crit: nil }], statuses: [], flares: [],
                outcomes: [], resolutions: [] }

      described_class.persist_event(event)
      # emitted for observers, but Creature[] never consulted for application
      expect(Lich::Gemstone::Combat::Observers).to have_received(:emit).with(:attack, event)
    end

    it 'keeps our OWN weapon infusion (through you) as ours' do
      chunk = [
        "As you attempt to strike with your star, it sends a surge of power through you that quickly leaps out at #{maiden}!",
        '  AS: +400 vs DS: +200 with AvD: +30 + d100 roll: +50 = +280',
        '   ... and hits for 30 points of damage!',
        '<prompt time="1757183316">&gt;</prompt>'
      ]

      event = described_class.parse_events(chunk).first
      expect(event[:foreign_caster]).to be_falsey
      expect(event[:target][:id]).to eq(555001)
    end
  end

  # A DoT/effect tick that names the victim but no caster, arriving with
  # no owning cast in the blob (a nearby player's pestilence ticking on a
  # creature we can see, or one we walked in on). Owner ruling 2026-09-06:
  # apply the damage to the creature (its received-total is real) but keep
  # it OFF our deal - the recorder files it under other/unknown.
  describe 'unowned effect tick (no owning cast)' do
    let(:skald) { bolded(556001, 'skald', 'a grim gigas skald') }

    it 'flags a lone pestilence tick as unowned' do
      chunk = [
        "Boils rupture all over #{skald} causing 54 points of damage!",
        '   ... 10 points of damage!',
        '<prompt time="1757186800">&gt;</prompt>'
      ]

      event = described_class.parse_events(chunk).first
      expect(event[:name]).to eq(:pestilence)
      expect(event[:unowned]).to be(true)
      # still bound to the creature, so its damage applies
      expect(event[:target][:id]).to eq(556001)
      expect(event[:hits].map { |h| h[:damage] }).to include(54)
    end

    it 'does NOT flag a pestilence tick that follows our own cast in-blob' do
      chunk = [
        "You exhale a virulent green mist toward #{skald}, instantly infecting it!",
        "Boils rupture all over #{skald} causing 54 points of damage!",
        '<prompt time="1757186801">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      expect(events.none? { |e| e[:unowned] }).to be(true)
    end
  end

  # A nearby player's AoE (pulverize) fans out into anonymous per-target
  # swing lines that name no actor. The opener names the player, arming
  # the foreign latch so the whole chain stays off our ledger (real-feed,
  # GSIV-Nisugi 2026-09-06: Heavenscent's pulverize dumped ~825 swing
  # damage into our open web event).
  describe 'foreign AoE latch' do
    let(:warg) { bolded(557001, 'warg', 'a niveous giant warg') }
    let(:maiden) { bolded(557002, 'shield-maiden', 'a brawny gigas shield-maiden') }

    it 'attributes an anonymous foreign AoE swing chain to the opener' do
      chunk = [
        'Heavenscent wheels her star overhead before slamming it around in a wide arc to pulverize her foes!',
        '[SMR result: 281 (Open d100: 69, Bonus: 146)]',
        "As Heavenscent attempts to strike with her star, a surge of power flows out of it, through Heavenscent, and leaps out at #{maiden}!",
        "Cloudy wisps swirl about #{maiden}.",
        "A #{maiden} becomes ensnared in thick strands of webbing!",
        '  AS: +673 vs DS: +333 with AvD: +42 + d100 roll: +25 = +407',
        '   ... and hits for 159 points of damage!',
        '<prompt time="1757186900">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      # every damaging event in this blob is foreign, none credited to us
      dmg_events = events.select { |e| e[:hits].any? { |h| h[:damage].to_i > 0 } }
      expect(dmg_events).not_to be_empty
      expect(dmg_events).to all(satisfy { |e| e[:foreign_caster] })
    end

    it 'clears the latch when WE act, keeping our own attack ours' do
      chunk = [
        'Heavenscent wheels her star overhead before slamming it around in a wide arc to pulverize her foes!',
        "You fire a firewheel arrow at #{warg}!",
        '  AS: +500 vs DS: +200 with AvD: +30 + d100 roll: +40 = +370',
        '   ... and hits for 88 points of damage!',
        '<prompt time="1757186901">&gt;</prompt>'
      ]

      fire = described_class.parse_events(chunk).find { |e| e[:name] == :fire }
      expect(fire).not_to be_nil
      expect(fire[:foreign_caster]).to be_falsey
      expect(fire[:hits].map { |h| h[:damage] }).to eq([88])
    end
  end

  it 'still switches targets across a multi-target AoE' do
    chunk = [
      'You wheel your maul overhead before slamming it around in a wide arc to pulverize your foes!',
      '  AS: +400 vs DS: +200 with AvD: +30 + d100 roll: +50 = +280',
      '   ... and hits for 30 points of damage!',
      "#{bolded(500, 'orc', 'A greater orc')} is struck!",
      '  AS: +400 vs DS: +220 with AvD: +30 + d100 roll: +60 = +270',
      '   ... and hits for 25 points of damage!',
      "#{bolded(501, 'troll', 'A cave troll')} is struck!",
      '  AS: +400 vs DS: +210 with AvD: +30 + d100 roll: +40 = +260',
      '   ... and hits for 20 points of damage!',
      '<prompt time="1758161236">&gt;</prompt>'
    ]

    events = described_class.parse_events(chunk)
    expect(events.map { |e| e[:target][:id] }.compact.uniq).to contain_exactly(500, 501)
  end

  # Major review finding (mrhoribu, PR #1559): the crit lookahead that fills
  # hit[:crit] was gated on track_wounds ALONE, but apply_crit_statuses also
  # consumes hit[:crit]. With track_wounds:false + track_statuses:true, crit
  # capture went dark and status derivation became a silent no-op. The gate is
  # now (track_wounds || track_statuses). These pin both directions.
  describe 'crit capture is not coupled to track_wounds alone' do
    # a real crush-table crit line that CritRanks parses (carries stun/rt)
    let(:crit_chunk) do
      orc = bolded(7777, 'orc', 'a greater orc')
      [
        "You swing a slim short sword at #{orc}!",
        '  AS: +400 vs DS: +200 with AvD: +30 + d100 roll: +50 = +280',
        '   ... and hits for 30 points of damage!',
        '   Smack to the eye bursts blood vessels.',
        '<prompt time="1758161240">&gt;</prompt>'
      ]
    end

    def parse_with(settings)
      allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(settings)
      described_class.parse_events(crit_chunk).first
    end

    it 'captures the crit when statuses are on even though wounds are off' do
      event = parse_with(track_statuses: true, track_ucs: false, emit_attacks: true,
                         track_damage: true, track_wounds: false)
      crit = event[:hits].first[:crit]
      expect(crit).not_to be_nil
      expect(crit[:location]).to eq('left eye')
      # the field apply_crit_statuses actually consumes to emit :stun
      expect(crit[:stunned]).to eq(3)
    end

    it 'still captures the crit when wounds are on and statuses are off' do
      event = parse_with(track_statuses: false, track_ucs: false, emit_attacks: true,
                         track_damage: true, track_wounds: true)
      expect(event[:hits].first[:crit]).not_to be_nil
    end

    it 'skips the lookahead entirely when both are off (fast path preserved)' do
      event = parse_with(track_statuses: false, track_ucs: false, emit_attacks: true,
                         track_damage: true, track_wounds: false)
      expect(event[:hits].first[:crit]).to be_nil
    end
  end
end
