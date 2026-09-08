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
    # cross-chunk state lives in module ivars; never let one example's
    # death watch or held cast leak into another
    %i[@death_watch @death_announced @held_cast @held_pre_flares @deferred_emits].each do |iv|
      described_class.instance_variable_set(iv, nil)
    end
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

  # A guardian creature stepping in front of the creature we struck at is a
  # MODIFIER on the attack that follows (which now names the guardian), not
  # an intercept outcome: the attack resolved in full against the guardian.
  # Real-feed 2026-09-07 (gigas hunt, mirror echo redirected off a mastodon
  # onto a shield-maiden); corpus shows the same shape after ambush prefixes
  # and thrown/UAC openers (130 lines, always followed by an attack line).
  describe 'guardian redirect prefix' do
    let(:mastodon) { bolded(1001, 'mastodon', 'a heavily armored battle mastodon') }
    let(:maiden) { bolded(1002, 'shield-maiden', 'a brawny gigas shield-maiden') }
    let(:redirect_line) do
      "Gritting her teeth with determination, #{maiden} raises her targe and throws herself between you and the mastodon to intercept your attack!"
    end

    it 'stamps the following attack with interceptor + intended victim and opens no event of its own' do
      chunk = [
        redirect_line,
        "You fire a faewood arrow at #{maiden}!",
        '  AS: +652 vs DS: +394 with AvD: +38 + d100 roll: +32 = +328',
        '   ... and hit for 50 points of damage!',
        '<prompt time="1">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      expect(events.size).to eq(1)
      fire = events.first
      expect(fire[:name]).to eq(:fire)
      expect(fire[:target][:id]).to eq(1002)
      expect(fire[:outcomes]).to be_empty
      expect(fire[:redirect]).to eq(interceptor: { id: 1002, noun: 'shield-maiden', name: 'a brawny gigas shield-maiden' },
                                    intended: 'mastodon', honored: true)
      expect(fire[:hits].map { |h| h[:damage] }).to eq([50])
    end

    # UAC shape (corpus 21/130): the announce follows the kick line, no
    # attack is re-issued, and the roll + damage still land on the intended
    # creature. Record the announce on the open kick as unhonored and do
    # not let a later swing in the chunk claim it.
    it 'marks an announce that follows the attack line, with resolution still on the intended target, as unhonored' do
      skald = bolded(1003, 'skald', 'a grim gigas skald')
      chunk = [
        'You leap from hiding to strike!',
        "You attempt to kick #{skald}!",
        "Gritting her teeth with determination, #{maiden} raises her targe and throws herself between you and the skald to intercept your attack!",
        "You have good positioning against #{skald}.",
        '  UAF: 746 vs UDF: 629 = 1.186 * MM: 92 + d100: 94 = 203',
        '  ... and hit for 71 points of damage!',
        "You fire a faewood arrow at #{mastodon}!",
        '   ... and hit for 10 points of damage!',
        '<prompt time="5">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      expect(events.map { |e| e[:target][:id] }).to eq([1003, 1001])
      kick = events[0]
      expect(kick[:name]).to eq(:kick)
      expect(kick[:hits].map { |h| h[:damage] }).to eq([71])
      expect(kick[:redirect]).to include(intended: 'skald', honored: false)
      expect(kick[:redirect][:interceptor][:id]).to eq(1002)
      expect(events[1][:redirect]).to be_nil
    end

    it 'does not file the redirect on the previous (still open) attack, and does not leak' do
      chunk = [
        "You fire a faewood arrow at #{mastodon}!",
        '  AS: +652 vs DS: +328 with AvD: +20 + d100 roll: +1 = +345',
        '   ... and hit for 63 points of damage!',
        ' ** Fleeting and insubstantial, a whisper of shadow coalesces beside you, echoing your attack with one of its own! **',
        redirect_line,
        "You fire a faewood arrow at #{maiden}!",
        '   ... and hit for 50 points of damage!',
        "You fire a faewood arrow at #{mastodon}!",
        '   ... and hit for 10 points of damage!',
        '<prompt time="2">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      expect(events.map { |e| e[:target][:id] }).to eq([1001, 1002, 1001])
      expect(events.map { |e| e[:redirect]&.dig(:intended) }).to eq([nil, 'mastodon', nil])
      expect(events[0][:outcomes]).to be_empty
      expect(events[0][:flares].map { |f| f[:name] }).to eq([:mirror_image])
      expect(events[0][:flares].first[:outcomes]).to be_empty
    end

    it 'coexists with an ambush prefix (both flags land on the same attack)' do
      chunk = [
        'You leap from hiding to attack!',
        redirect_line,
        "You take aim and punch with a somnis katar at #{maiden}!",
        '  AS: +728 vs DS: +427 with AvD: +38 + d100 roll: +71 = +410',
        '   ... and hit for 90 points of damage!',
        '<prompt time="3">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      expect(events.size).to eq(1)
      expect(events.first[:ambush]).to be(true)
      expect(events.first[:redirect][:intended]).to eq('mastodon')
    end
  end

  # Hunter's afterimage re-forms the arrow and fires AGAIN as its own swing.
  # The announce lands on the shot it rode (still open); the echo swing that
  # follows is its own event carrying its own roll and damage - the flare
  # must NOT be damaging or it would steal that swing's cursor.
  describe 'hunters afterimage flare' do
    let(:mastodon) { bolded(1001, 'mastodon', 'a heavily armored battle mastodon') }

    it 'attaches to the shot it rode and leaves the echo swing its own damage' do
      chunk = [
        "You fire a faewood arrow at #{mastodon}!",
        '  AS: +652 vs DS: +375 with AvD: +20 + d100 roll: +20 = +317',
        '   ... and hit for 48 points of damage!',
        ' ** A radiant afterimage of the arrow appears in your ready hand, coalescing to replace its predecessor! **',
        "You fire a faewood arrow at #{mastodon}!",
        '  AS: +652 vs DS: +328 with AvD: +20 + d100 roll: +1 = +345',
        '   ... and hit for 63 points of damage!',
        '<prompt time="4">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      expect(events.size).to eq(2)
      expect(events[0][:flares].map { |f| f[:name] }).to eq([:hunters_afterimage])
      expect(events[0][:flares].first[:hits]).to be_empty
      expect(events[0][:hits].map { |h| h[:damage] }).to eq([48])
      expect(events[1][:flares]).to be_empty
      expect(events[1][:hits].map { |h| h[:damage] }).to eq([63])
    end

    # Echo lineage (owner ruling 2026-09-07: "the flare is the attack"). The
    # echo swing that follows an echo flare in the same blob is that flare's
    # child: parent = the event the flare rode, parent flare = its name,
    # confidence :count. An echo's own echo flare parents the next swing to
    # the echo, so chains nest.
    it 'parents the echo swing to the shot whose afterimage spawned it' do
      chunk = [
        "You fire a faewood arrow at #{mastodon}!",
        '  AS: +652 vs DS: +375 with AvD: +20 + d100 roll: +20 = +317',
        '   ... and hit for 48 points of damage!',
        ' ** A radiant afterimage of the arrow appears in your ready hand, coalescing to replace its predecessor! **',
        "You fire a faewood arrow at #{mastodon}!",
        '  AS: +652 vs DS: +328 with AvD: +20 + d100 roll: +1 = +345',
        '   ... and hit for 63 points of damage!',
        ' ** Fleeting and insubstantial, a mirror image of you shimmers into view at your side, echoing your attack with one of its own! **',
        "You fire a faewood arrow at #{mastodon}!",
        '  AS: +652 vs DS: +300 with AvD: +20 + d100 roll: +50 = +422',
        '   ... and hit for 90 points of damage!',
        '<prompt time="4">&gt;</prompt>'
      ]

      shot, echo1, echo2 = described_class.parse_events(chunk)
      expect(shot[:root_ref]).to equal(shot)
      expect(shot[:parent_ref]).to be_nil
      expect(echo1[:root_ref]).to equal(shot)
      expect(echo1[:parent_ref]).to equal(shot)
      expect(echo1[:parent]).to include(flare: :hunters_afterimage)
      expect(echo1[:parent_confidence]).to eq(:count)
      # the mirror rode echo1, so echo2 is echo1's child, still rooted at the shot
      expect(echo2[:root_ref]).to equal(shot)
      expect(echo2[:parent_ref]).to equal(echo1)
      expect(echo2[:parent]).to include(flare: :mirror_image)
    end

    it 'leaves two independent shots in one blob as separate roots (no echo flare between them)' do
      chunk = [
        "You fire a faewood arrow at #{mastodon}!",
        '   ... and hit for 48 points of damage!',
        "You fire a faewood arrow at #{mastodon}!",
        '   ... and hit for 63 points of damage!'
      ]
      _, b = described_class.parse_events(chunk)
      expect(b[:root_ref]).to equal(b)
      expect(b[:parent_ref]).to be_nil
    end

    it 'recognises the third-person form with the attacker' do
      flare = Lich::Gemstone::Combat::Parser.parse_flare(
        " ** A radiant afterimage of the arrow appears in Taloin's ready hand, coalescing to replace its predecessor! **"
      )
      expect(flare).not_to be_nil
      expect(flare[:name]).to eq(:hunters_afterimage)
    end
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

  # Re-review finding (PR #1559): apply_crit_statuses only walked the swing's
  # direct hits, so a FLARE that crit with a stun/roundtime/knockdown recorded
  # its damage and wound but never its status. Now flare-hit crits emit too,
  # attributed to the flare's own creature.
  describe 'flare crit statuses' do
    let(:creature) do
      instance_double('Creature', id: 700, name: 'a target').tap do |c|
        allow(c).to receive(:add_status)
        allow(c).to receive(:add_stun_estimate)
        allow(c).to receive(:remove_status)
      end
    end

    before do
      allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
        track_statuses: true, track_ucs: false, emit_attacks: true,
        track_damage: true, track_wounds: true
      )
      stub_const('Lich::Gemstone::Combat::CreatureInstance',
                 Module.new.tap { |m| m.const_set(:STUN_ROUND_SECONDS, 5) })
      # apply_crit_statuses uses record_delta; make it a no-op passthrough
      allow(described_class).to receive(:record_delta).and_yield({ statuses: [], wounds: [], damage: 0 })
    end

    it 'emits a stun for a FLARE crit (not just direct hits)' do
      event = {
        name: :fire, at: Time.at(1), target: { id: 700 },
        hits: [{ damage: 30, crit: nil }], # no direct crit
        flares: [{ name: :ensorcell, target_info: { id: 700 },
                   hits: [{ damage: 12, crit: { stunned: 2 } }] }]
      }
      creature_registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', creature_registry)
      allow(creature_registry).to receive(:[]).with(700).and_return(creature)

      described_class.apply_crit_statuses(creature, event)

      expect(Lich::Gemstone::Combat::Observers).to have_received(:emit)
        .with(:stun, hash_including(flare: :ensorcell, rounds: 2))
    end

    it 'still emits a direct-hit crit stun (no regression)' do
      event = {
        name: :fire, at: Time.at(1), target: { id: 700 },
        hits: [{ damage: 30, crit: { stunned: 3 } }],
        flares: []
      }
      described_class.apply_crit_statuses(creature, event)
      expect(Lich::Gemstone::Combat::Observers).to have_received(:emit)
        .with(:stun, hash_including(flare: nil, rounds: 3))
    end
  end

  # Re-review finding (PR #1559): persist_event returned on `unless target[:id]`
  # BEFORE the flare loop, so a reactive flare (shield spike) hanging off an
  # INBOUND attack - which has no creature target but whose flare strikes the
  # attacker creature - had its damage, wounds and statuses dropped entirely.
  describe 'reactive flare on a targetless (inbound) attack' do
    let(:attacker_creature) do
      instance_double('Creature', id: 808, name: 'a triton defender').tap do |c|
        allow(c).to receive(:add_damage)
        allow(c).to receive(:add_status)
        allow(c).to receive(:add_stun_estimate)
        allow(c).to receive(:remove_status)
      end
    end

    before do
      allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
        track_statuses: true, track_ucs: false, emit_attacks: true,
        track_damage: true, track_wounds: true
      )
      stub_const('Lich::Gemstone::Combat::CreatureInstance',
                 Module.new.tap { |m| m.const_set(:STUN_ROUND_SECONDS, 5) })
      allow(described_class).to receive(:record_delta).and_yield({ statuses: [], wounds: [], damage: 0 })
      allow(described_class).to receive(:apply_crit)
      allow(described_class).to receive(:emit_debug_summary)
      registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', registry)
      allow(registry).to receive(:[]).with(808).and_return(attacker_creature)
    end

    it 'applies the reactive flare damage and stun to the attacker creature' do
      # inbound attack: no creature target; its shield-spike flare hits 808
      event = {
        name: :ambush, inbound: true, target: {}, attacker: { id: 808, name: 'a triton defender' },
        hits: [{ damage: 10, crit: nil }], # the 10 they dealt US
        flares: [{ name: :spike, target_info: { id: 808 },
                   hits: [{ damage: 5, crit: { stunned: 2 } }] }], # our spike back
        statuses: [], outcomes: [], resolutions: []
      }

      described_class.persist_event(event)

      # the spike's 5 damage landed on the attacker creature (not dropped)
      expect(attacker_creature).to have_received(:add_damage).with(5)
      # and its crit stun emitted
      expect(Lich::Gemstone::Combat::Observers).to have_received(:emit)
        .with(:stun, hash_including(flare: :spike, rounds: 2))
    end
  end

  # A coup de grace prints no damage number; its success line is the killing
  # blow and is recorded as a zero-damage FATAL hit (owner ruling 2026-09-07).
  describe 'coup de grace kill line' do
    it 'records the kill as a fatal zero-damage hit on the coup event' do
      zerk = bolded(121654846, 'berserker', 'a tattooed gigas berserker')
      events = described_class.parse_events([
                                              "You lunge towards the #{bolded(121654846, 'berserker', 'gigas berserker')}, intending to finish her off!",
                                              '<pushBold/>[SMR result: 276 (Open d100: 89, Bonus: 105)]<popBold/>',
                                              "You stiffen your fingers and drive them into the #{bolded(121654846, 'berserker', 'gigas berserker')}'s neck, tearing out a handful of dripping trachea!  The gigas berserker gags just once.",
                                              "#{zerk}'s fists tense with impotent rage as she surrenders to death."
                                            ])
      expect(events.size).to eq(1)
      coup = events.first
      expect(coup[:name]).to eq(:coup_de_grace)
      expect(coup[:hits].size).to eq(1)
      expect(coup[:hits].first[:damage]).to eq(0)
      expect(coup[:hits].first[:crit]).to include(fatal: true, location: 'neck', type: 'coup_de_grace')
      expect(coup[:resolutions].size).to eq(1)
    end
  end

  # The gesture wrapper across a chunk boundary (2026-09-07). Live chunks split
  # at the prompt, and "You gesture at X." ends a chunk; the spell result
  # (tangleweed's briar lash) opens the next one. In-blob the specific def
  # supersedes the bare :cast; across the boundary the cast used to emit as a
  # fact-less phantom first. It is now held for one chunk.
  describe 'bare cast held across a chunk boundary' do
    let(:zerk) { bolded(121654846, 'berserker', 'a tattooed gigas berserker') }
    let(:gesture_chunk) { ["You gesture at #{zerk}.", 'Cast Roundtime 1 Second.'] }
    let(:lash_chunk) do
      [
        'A violently lashing emerald briar bestrewn with unnaturally sharp spikes suddenly sprouts from the ground and begins to thrash about violently!',
        '<pushBold/>[SMR result: 149 (Open d100: 57)]<popBold/>',
        "The lashing emerald briar lashes out violently at #{zerk}, dragging her to the ground!",
        '   ... 10 points of damage!',
        '   Blow to the diaphragm.'
      ]
    end

    before do
      registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', registry)
      described_class.instance_variable_set(:@held_cast, nil)
    end

    it 'holds the gesture and lets the next chunk\'s spell result supersede it (one tangleweed via :cast)' do
      expect(described_class.parse_events(gesture_chunk)).to be_empty
      events = described_class.parse_events(lash_chunk)
      expect(events.map { |e| e[:name] }).to eq([:tangleweed])
      tw = events.first
      expect(tw[:via]).to eq(:cast)
      expect(tw[:target][:id]).to eq(121654846)
      expect(tw[:hits].map { |h| h[:damage] }).to eq([10])
      expect(tw[:resolutions].size).to eq(1) # the SMR that followed the gesture
    end

    it 'emits the held cast as itself when the next chunk starts a NEW 2p attack instead' do
      described_class.parse_events(gesture_chunk)
      events = described_class.parse_events([
                                              "You fire a faewood arrow at #{zerk}!",
                                              '  AS: +663 vs DS: +271 with AvD: +27 + d100 roll: +80 = +499',
                                              '   ... and hit for 188 points of damage!'
                                            ])
      expect(events.map { |e| e[:name] }).to eq(%i[cast fire])
      expect(events.last[:via]).to be_nil
    end

    it 'emits the held cast at the end of a quiet chunk rather than holding it forever' do
      described_class.parse_events(gesture_chunk)
      events = described_class.parse_events(['You feel more refreshed.'])
      expect(events.map { |e| e[:name] }).to eq([:cast])
      expect(described_class.instance_variable_get(:@held_cast)).to be_nil
    end

    it 'still supersedes when a mirror image echoed the gesture ("Nothing happens.")' do
      chunk = ["You gesture at #{zerk}.",
               ' ** Fleeting and insubstantial, a mirror image of you shimmers into view at your side, echoing your attack with one of its own! **',
               'Nothing happens.',
               'Cast Roundtime 1 Second.'] + lash_chunk
      events = described_class.parse_events(chunk)
      expect(events.map { |e| e[:name] }).to eq([:tangleweed])
      expect(events.first[:via]).to eq(:cast)
      expect(events.first[:flares].map { |f| f[:name] }).to include(:mirror_image)
    end

    it 'does not split the lash when the rider dismounts mid-line (narration, not a target switch)' do
      masto = bolded(123259310, 'mastodon', 'a heavily armored battle mastodon')
      maiden = bolded(123241966, 'shield-maiden', 'a brawny gigas shield-maiden')
      events = described_class.parse_events([
                                              '<pushBold/>[SMR result: 173 (Open d100: 68, Bonus: 4)]<popBold/>',
                                              "The lashing emerald briar lashes out violently at #{masto}, dragging it to the ground!",
                                              "#{maiden} leaps from the back of #{masto} as it topples, narrowly avoiding being pinned beneath its mount!",
                                              '   ... 5 points of damage!',
                                              '   Attempt to snare hips shaken loose.'
                                            ])
      expect(events.map { |e| [e[:name], e[:target][:id], e[:hits].map { |h| h[:damage] }, e[:resolutions].size] })
        .to eq([[:tangleweed, 123259310, [5], 1]])
    end

    it "hands the line back to the lash after the pinned rider's single hit (mount collapse)" do
      masto = bolded(130483104, 'mastodon', 'a heavily armored battle mastodon')
      maiden = bolded(130483100, 'shield-maiden', 'a brawny gigas shield-maiden')
      events = described_class.parse_events([
                                              '<pushBold/>[SMR result: 125 (Open d100: 12, Bonus: 9)]<popBold/>',
                                              "The lashing emerald briar lashes out violently at #{masto}, dragging it to the ground!",
                                              "#{maiden} is pinned beneath #{masto} as it falls!",
                                              '   ... 5 points of damage!',
                                              "   Blow raises a welt on #{bolded(130483100, 'shield-maiden', "the gigas shield-maiden's")} left arm.",
                                              '   ... 5 points of damage!',
                                              '   Attempt to grab from behind shrugged off.',
                                              "You notice a number of the briar's nettles scrape into #{bolded(130483104, 'mastodon', "a heavily armored battle mastodon's")} skin.  It suddenly looks very weak!"
                                            ])
      expect(events.map { |e| [e[:name], e[:target][:id], e[:hits].map { |h| h[:damage] }, e[:resolutions].size] })
        .to contain_exactly([:tangleweed, 130483104, [5], 1], [:mount_collapse, 130483100, [5], 0])
    end

    it 'still supersedes in-blob when gesture and lash share a chunk' do
      events = described_class.parse_events(gesture_chunk + lash_chunk)
      expect(events.map { |e| e[:name] }).to eq([:tangleweed])
      expect(events.first[:via]).to eq(:cast)
    end
  end

  # Glowbark chain (2026-09-07 naming): phosphorescence (primary, names the
  # swing target) -> glowbright (chain trigger, no target) -> spectral_bloom
  # (one per extra creature). The bloom names ITS OWN creature; the target
  # switcher used to read that as a switch and open an inherited `fire`
  # event on the bloom's creature, so the bloom damage landed on a phantom
  # fire (PLASMA crit and all) while the flare row stayed empty.
  describe 'glowbark chain: spectral bloom on another creature' do
    let(:zerk) { bolded(121654846, 'berserker', 'a tattooed gigas berserker') }
    let(:masto) { bolded(121678494, 'mastodon', 'a heavily armored battle mastodon') }

    before do
      allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
        track_statuses: true, track_ucs: false, emit_attacks: true, track_damage: true, track_wounds: true
      )
      registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', registry)
    end

    let(:chunk) do
      [
        "You fire a faewood arrow at #{zerk}!",
        '  AS: +663 vs DS: +271 with AvD: +27 + d100 roll: +80 = +499',
        '   ... and hit for 188 points of damage!',
        "   Crossing slash to chest catches the #{bolded(121654846, 'berserker', 'gigas berserker')}'s attention!",
        " ** Countless points of pale phosphorescence awaken across your glowbark long bow, rapidly brightening before bursting into brilliant light around #{zerk}! **",
        '   ... 20 points of damage!',
        "   Wreath of energy burns away the #{bolded(121654846, 'berserker', 'gigas berserker')}'s hair and leaves skin blackened!",
        "You blinded #{zerk}!",
        ' ** Phosphorescent light races through the glowbark as its entire surface blossoms with dazzling radiance, flooding the surroundings in ghostly light! **',
        " ** A bloom of spectral light blossoms around #{masto}, engulfing it in searing brilliance! **",
        '   ... 5 points of damage!',
        "   Plasma scalds the #{bolded(121678494, 'mastodon', 'armored battle mastodon')}'s stomach leaving painful red streaks.",
        "You blinded #{masto}!",
        "The arrow sticks in #{zerk}'s chest!",
        'Roundtime: 3 sec.'
      ]
    end

    it 'keeps the bloom damage on the spectral_bloom flare, attributed to the bloom creature, as ONE event' do
      events = described_class.parse_events(chunk)
      expect(events.size).to eq(1)
      ev = events.first
      expect(ev[:name]).to eq(:fire)
      expect(ev[:target][:id]).to eq(121654846)
      expect(ev[:hits].map { |h| h[:damage] }).to eq([188])
      names = ev[:flares].map { |f| f[:name] }
      expect(names).to eq(%i[phosphorescence glowbright spectral_bloom])
      bloom = ev[:flares].last
      expect(bloom[:target_info][:id]).to eq(121678494)
      expect(bloom[:hits].map { |h| h[:damage] }).to eq([5])
      expect(ev[:flares].first[:hits].map { |h| h[:damage] }).to eq([20])
    end

    # A knockdown crit (leg blown off) rolls its own SMR AFTER the damage
    # and narrates the fall on the next line (hunt log 2026-09-07 19:10:54).
    # That roll rides on the hit that caused it; held, it became a synthetic
    # :unknown attack on the swing target with the swing's blind status.
    it 'keeps a crit-rider SMR (topple) on the bloom instead of orphaning it' do
      lines = chunk.dup
      i = lines.index { |l| l.include?('Plasma scalds') }
      lines[i] = "   Fiery blast of plasma blows the #{bolded(121678494, 'mastodon', 'armored battle mastodon')}'s leg into a bloody spray!"
      lines.insert(i + 1,
                   '<pushBold/>[SMR result: 35 (Open d100: 55, Penalty: 23)]<popBold/>',
                   "Despite desperate windmilling to catch its balance, #{masto} topples toward you!  You stumble into visibility as you try to dodge.",
                   "   The #{bolded(121678494, 'mastodon', 'armored battle mastodon')} is stunned!")
      events = described_class.parse_events(lines)
      expect(events.map { |e| e[:name] }).to eq([:fire])
      bloom = events.first[:flares].last
      expect(bloom[:name]).to eq(:spectral_bloom)
      expect(bloom[:resolutions].map { |r| r[:result] }).to eq([35])
    end

    # "You blinded X!" rides the flare that blinded X: the primary's blind
    # on the swing target, the bloom's blind on the bloom creature. The fact
    # carries the flare's 1-based position so the recorder can file it on
    # the flare row (owner 2026-09-07: blinds sat on the root attack).
    it 'emits each blind with the flare_seq of the flare that caused it' do
      registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', registry)
      { 121654846 => 'a tattooed gigas berserker', 121678494 => 'a heavily armored battle mastodon' }.each do |cid, cname|
        dbl = instance_double('Creature', id: cid, name: cname)
        allow(dbl).to receive(:add_status)
        allow(registry).to receive(:[]).with(cid).and_return(dbl)
      end
      emitted = []
      allow(Lich::Gemstone::Combat::Observers).to receive(:emit) { |type, payload| emitted << [type, payload] }
      described_class.instance_variable_set(:@deferred_emits, nil)
      described_class.parse_events(chunk)
      blinds = emitted.select { |t, p| t == :status && p[:status] == :blind }
      expect(blinds.map { |_, p| [p[:id], p[:flare_seq]] }).to eq([[121654846, 1], [121678494, 3]])
    end

    it "files a flare-and-status line (nature's decay) on its own flare, not the one before it" do
      registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', registry)
      dbl = instance_double('Creature', id: 129649881, name: 'a flayed gigas disciple')
      allow(dbl).to receive(:add_status)
      allow(registry).to receive(:[]).with(129649881).and_return(dbl)
      emitted = []
      allow(Lich::Gemstone::Combat::Observers).to receive(:emit) { |type, payload| emitted << [type, payload] }
      described_class.instance_variable_set(:@deferred_emits, nil)
      disc = bolded(129649881, 'disciple', 'a flayed gigas disciple')
      events = described_class.parse_events([
                                              "** Your <a exist=\"129604585\" noun=\"bow\">glowbark long bow</a> glows brightly for a moment, consuming the magical energies around #{bolded(129649881, 'disciple', 'the gigas disciple')}! **",
                                              "You fire a faewood arrow at #{disc}!",
                                              '  AS: +652 vs DS: +602 with AvD: +32 + d100 roll: +95 = +177',
                                              '   ... and hit for 30 points of damage!',
                                              "   Strike pierces #{bolded(129649881, 'disciple', "the gigas disciple's")} forearm!",
                                              "   #{bolded(129649881, 'disciple', 'The gigas disciple')} is stunned!",
                                              "#{disc} is buffeted by a burst of wind and pushed back!",
                                              "The earthy, sweet aroma clinging to #{disc} grows more pervasive.",
                                              'Vital energy infuses you, hastening your arcane reflexes!'
                                            ])
      expect(events.first[:flares].map { |f| f[:name] }).to eq(%i[dispel breeze natures_decay arcane_reflex])
      decay = emitted.select { |t, p| t == :status && p[:status].to_s == 'natures_decay' }
      expect(decay.map { |_, p| [p[:id], p[:flare_seq]] }).to eq([[129649881, 3]])
      # the swing's own crit stun is not the dispel pre-flare's doing
      stun = emitted.select { |t, p| t == :status && p[:status].to_s == 'stunned' }
      expect(stun.map { |_, p| [p[:id], p[:flare_seq]] }).to eq([[129649881, nil]])
    end
  end

  describe 'hunt-log defs 2026-09-07 (session 4 audit)' do
    let(:skald) { bolded(123995203, 'skald', 'a grim gigas skald') }
    let(:masto) { bolded(123956079, 'mastodon', 'a heavily armored battle mastodon') }
    let(:warg) { bolded(123985834, 'warg', 'a niveous giant warg') }
    let(:maiden) { bolded(124194699, 'shield-maiden', 'a brawny gigas shield-maiden') }

    before do
      allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
        track_statuses: true, track_ucs: false, emit_attacks: true, track_damage: true, track_wounds: true
      )
      registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', registry)
    end

    it 'names a tangleweed miss (unable to grasp) as a tangleweed attack with its SMR, not a targetless unknown' do
      events = described_class.parse_events([
                                              '<pushBold/>[SMR result: 71 (Open d100: -86, Bonus: 62)]<popBold/>',
                                              "The lashing emerald briar lashes out at #{maiden}, but is unable to grasp her."
                                            ])
      expect(events.map { |e| e[:name] }).to eq([:tangleweed])
      ev = events.first
      expect(ev[:target][:id]).to eq(124194699)
      expect(ev[:outcomes]).to include(:miss)
      expect(ev[:resolutions].map { |r| r[:result] }).to eq([71])
    end

    it 'records a warg howl as an inbound fear maneuver with its SSR and our save' do
      events = described_class.parse_events([
                                              "#{warg} sits back on its haunches and unleashes a long, high-pitched howl that sends a shiver of primal terror down your spine.",
                                              '<pushBold/>[SSR result: 86 (Open d100: 18)]<popBold/>',
                                              "Fear still claws at your heart, but you stand fast against the #{bolded(123985834, 'warg', 'warg')}'s unnerving howl!"
                                            ])
      expect(events.map { |e| e[:name] }).to eq([:howl])
      ev = events.first
      expect(ev[:inbound]).to be(true)
      expect(ev[:attacker][:id]).to eq(123985834)
      expect(ev[:resolutions].map { |r| r[:type] }).to eq([:ssr])
      expect(ev[:outcomes]).to include(:resisted)
    end

    it 'records a mastodon trumpet as an inbound fear maneuver' do
      events = described_class.parse_events([
                                              "#{masto} raises its trunk and rears back onto its immense hind legs, blaring out a note of sheer fury!",
                                              '<pushBold/>[SSR result: 79 (Open d100: 52)]<popBold/>',
                                              "You keep your wits amidst the #{bolded(123956079, 'mastodon', 'mastodon')}'s angry trumpeting!"
                                            ])
      expect(events.map { |e| [e[:name], e[:inbound]] }).to eq([[:trumpet, true]])
      expect(events.first[:outcomes]).to include(:resisted)
    end

    it 'parses the mastodon tusk attack as inbound natural' do
      events = described_class.parse_events([
                                              "#{masto} tries to spear you with its enormous tusks!",
                                              '  AS: +537 vs DS: +516 with AvD: +37 + d100 roll: +10 = +68',
                                              '   A clean miss.'
                                            ])
      expect(events.map { |e| [e[:name], e[:inbound]] }).to eq([[:natural, true]])
      expect(events.first[:outcomes]).to include(:miss)
    end

    it 'names the attacker from the creature link, not a pronoun link in the flavor prefix' do
      zerk_his = bolded(123957785, 'berserker', 'his')
      zerk = bolded(123957785, 'berserker', 'a tattooed gigas berserker')
      events = described_class.parse_events([
                                              "Froth bubbling on #{zerk_his} lips, #{zerk} swings an immense fel-hafted handaxe at you in a murderous arc!",
                                              'You evade the attack by a hair!'
                                            ])
      expect(events.size).to eq(1)
      expect(events.first[:attacker][:name]).to eq('a tattooed gigas berserker')
    end

    it 'keeps a pre-emptive warg evade on the warg instead of a targetless unknown' do
      events = described_class.parse_events([
                                              "With preternatural speed, #{warg} bounds to safety as you move to attack #{bolded(123985834, 'warg', 'it')}, leaving you off-balance!",
                                              'The arrow streaks off into the distance!'
                                            ])
      expect(events.size).to eq(1)
      expect(events.first[:target][:id]).to eq(123985834)
      expect(events.first[:outcomes]).to include(:evade)
    end

    it 'matches the live trumpet line, whose pronouns are links, and takes the fail line as a hit' do
      its = bolded(123956079, 'mastodon', 'its')
      events = described_class.parse_events([
                                              "#{masto} raises #{its} trunk and rears back onto #{its} immense hind legs, blaring out a note of sheer fury!",
                                              '<pushBold/>[SSR result: 174 (Open d100: 182)]<popBold/>',
                                              "The #{bolded(123956079, 'mastodon', 'mastodon')}'s angry trumpeting startles you!",
                                              'Roundtime: 20 sec.'
                                            ])
      expect(events.map { |e| [e[:name], e[:inbound]] }).to eq([[:trumpet, true]])
      expect(events.first[:outcomes]).to include(:hit)
      expect(events.first[:resolutions].map { |r| r[:result] }).to eq([174])
    end

    it 'records a 3p feint we saw through as an inbound feint with an evade outcome' do
      events = described_class.parse_events([
                                              '<pushBold/>[SMR result: 20 (Open d100: 134, Penalty: 4)]<popBold/>',
                                              "#{maiden} feints high, but you aren't fooled for a second."
                                            ])
      expect(events.map { |e| [e[:name], e[:inbound]] }).to eq([[:feint, true]])
      expect(events.first[:outcomes]).to include(:evade)
      expect(events.first[:resolutions].map { |r| r[:result] }).to eq([20])
    end

    it 'records a shield push and its whiff' do
      her = bolded(124194699, 'shield-maiden', 'her')
      events = described_class.parse_events([
                                              "#{maiden} raises #{her} <a exist=\"124194700\" noun=\"targe\">golden targe</a> and attempts to push you away!",
                                              '<pushBold/>[SMR result: 17 (Open d100: 9, Penalty: 3)]<popBold/>',
                                              "#{maiden} completely misses you, stumbles, and flails around!"
                                            ])
      expect(events.map { |e| [e[:name], e[:inbound]] }).to eq([[:shield_push, true]])
      expect(events.first[:outcomes]).to include(:miss)
    end

    it "attributes a nearby player's fiery barbs to that player (foreign_caster), with its SMR and damage" do
      events = described_class.parse_events([
                                              "Fiery red barbs uncoil from the shadows near <a exist=\"-11152917\" noun=\"Burns\">Burns</a> and lash out at #{maiden}!",
                                              '<pushBold/>[SMR result: 104 (Open d100: 40, Bonus: 15)]<popBold/>',
                                              '   ... 15 points of damage!',
                                              '   Burst of flames to right arm toasts skin to elbows.'
                                            ])
      expect(events.size).to eq(1)
      ev = events.first
      expect(ev[:name]).to eq(:fiery_barbs)
      expect(ev[:foreign_caster]).to be(true)
      expect(ev[:target][:id]).to eq(124194699)
      expect(ev[:hits].map { |h| h[:damage] }).to eq([15])
      expect(ev[:resolutions].map { |r| r[:result] }).to eq([104])
    end

    it 'opens a barrier block with no attack line as an INBOUND unknown, not an attack on the creature' do
      events = described_class.parse_events([
                                              "The thorny barrier surrounding you blocks the attack from the #{bolded(123985834, 'warg', 'giant warg')}!"
                                            ])
      expect(events.size).to eq(1)
      ev = events.first
      expect(ev[:inbound]).to be(true)
      expect(ev[:target]).to eq({})
      expect(ev[:attacker][:id]).to eq(123985834)
      expect(ev[:outcomes]).to eq([:intercept])
    end

    it 'records bleed ticks: a creature\'s as an unowned attack on it, ours as inbound' do
      theirs = described_class.parse_events([
                                              "Blood weeps from the #{bolded(123956079, 'mastodon', 'armored battle mastodon')}'s open left arm wound.",
                                              '   ... 8 points of damage!'
                                            ])
      drips = described_class.parse_events([
                                             "The #{bolded(123985834, 'warg', 'giant warg')}'s chest drips as #{bolded(123985834, 'warg', 'it')} continues to bleed.",
                                             '   ... 14 points of damage!'
                                           ])
      ours = described_class.parse_events(['Your right leg drips as you continue to bleed.', '   ... 3 points of damage!'])
      expect(theirs.map { |e| [e[:name], e[:target][:id], e[:unowned], e[:hits].map { |h| h[:damage] }] }).to eq([[:bleed, 123956079, true, [8]]])
      expect(drips.map { |e| [e[:name], e[:target][:id], e[:unowned], e[:hits].map { |h| h[:damage] }] }).to eq([[:bleed, 123985834, true, [14]]])
      expect(ours.map { |e| [e[:name], e[:inbound], e[:hits].map { |h| h[:damage] }] }).to eq([[:bleed, true, [3]]])
      expect(Lich::Gemstone::Combat::Definitions::Attacks.attackerless_line?('Your right leg drips as you continue to bleed.')).to be true
    end

    it 'names a missed first volley arrow :volley and roots the round on it (hunt log 21:03:43)' do
      lines = File.readlines(File.join(__dir__, '../../../fixtures/volley_miss_first.txt'), chomp: true)
      events = described_class.parse_events(lines)
      expect(events.map { |e| e[:name] }.uniq).to eq([:volley])
      miss = events.first
      expect(miss[:target][:id]).to eq(126382122)
      expect(miss[:outcomes]).to eq([:evade])
      expect(miss[:resolutions].map { |r| r[:result] }).to eq([29])
      expect(miss[:root_ref]).to equal(miss)
      expect(events[1..].map { |e| e[:root_ref] }.uniq).to eq([miss])
      expect(events.map { |e| e[:hits].sum { |h| h[:damage] } }).to eq([0, 10, 35, 15, 10, 30])
    end

    it 'keeps a crit-rider topple whose pronoun is a link on the swing (hunt log 21:03:06)' do
      her = bolded(124194699, 'shield-maiden', 'her')
      events = described_class.parse_events([
                                              "You fire a faewood arrow at #{maiden}!",
                                              '  AS: +646 vs DS: +414 with AvD: +38 + d100 roll: +42 = +312',
                                              '   ... and hit for 54 points of damage!',
                                              "   Deft slash to the #{bolded(124194699, 'shield-maiden', 'gigas shield-maiden')}'s left leg digs deep!",
                                              '   Bone is chipped!',
                                              '<pushBold/>[SMR result: -84 (Open d100: 45, Penalty: 26)]<popBold/>',
                                              "Despite desperate windmilling to catch #{her} balance, #{maiden} topples toward you!  You stumble into visibility as you try to dodge the falling shield-maiden."
                                            ])
      expect(events.map { |e| e[:name] }).to eq([:fire])
      expect(events.first[:resolutions].map { |r| r[:result] }).to eq([312, -84])
    end

    it 'parses the warg jaw hamstring as an inbound hamstring with its miss' do
      events = described_class.parse_events([
                                              "With a quick lunge, #{warg} tries to hamstring you with #{bolded(123985834, 'warg', 'its')} jaws!",
                                              '<pushBold/>[SMR result: 33 (Open d100: 37, Penalty: 29)]<popBold/>',
                                              "#{bolded(123985834, 'warg', 'A niveous giant warg')}'s swing goes wide!"
                                            ])
      expect(events.map { |e| [e[:name], e[:inbound]] }).to eq([[:hamstring, true]])
      expect(events.first[:outcomes]).to include(:miss)
    end

    it 'strips a possessive baked into the creature link' do
      events = described_class.parse_events([
                                              "The thorny barrier surrounding you blocks the attack from the #{bolded(126564429, 'skald', "gigas skald's")}!"
                                            ])
      expect(events.first[:attacker][:name]).to eq('gigas skald')
    end

    it 'holds a dispel-on-nock pre-flare across the chunk boundary so the next shot claims it' do
      nock_chunk = [
        'You nock a faewood <a exist="127300001" noun="arrow">arrow</a> fletched with plain white feathers in your <a exist="125479289" noun="bow">glowbark long bow</a>.',
        'You feel drained.',
        " ** Your <a exist=\"125479289\" noun=\"bow\">glowbark long bow</a> glows brightly for a moment, consuming the magical energies around the #{bolded(123956079, 'mastodon', 'armored battle mastodon')}! **",
        ' <pushBold/>[SMR result: 225 (Open d100: 40, Bonus: 110)]<popBold/>',
        '   ... 20 points of damage!',
        "   The #{bolded(123956079, 'mastodon', 'armored battle mastodon')}'s neck bones snap.",
        '   Head looks precariously balanced now.'
      ]
      fire_chunk = [
        "You fire a faewood arrow at #{masto}!",
        '  AS: +644 vs DS: +301 with AvD: +20 + d100 roll: +90 = +453',
        '   ... and hit for 88 points of damage!',
        "   Quick, powerful slash to the #{bolded(123956079, 'mastodon', 'armored battle mastodon')}'s left knee!"
      ]
      expect(described_class.parse_events(nock_chunk)).to eq([])
      events = described_class.parse_events(fire_chunk)
      expect(events.map { |e| e[:name] }).to eq([:fire])
      dispel = events.first[:flares].find { |f| f[:name] == :dispel }
      expect(dispel).not_to be_nil
      expect(dispel[:hits].map { |h| h[:damage] }).to eq([20])
      expect(dispel[:resolutions].map { |r| r[:result] }).to eq([225])
      expect(events.first[:hits].map { |h| h[:damage] }).to eq([88])
    end

    it 'claims an in-chunk dispel-on-nock pre-flare for the shot that follows (raw hunt chunk 21:44:41)' do
      lines = File.readlines(File.join(__dir__, '../../../fixtures/dispel_on_nock.txt'), chomp: true)
      events = described_class.parse_events(lines)
      expect(events.map { |e| e[:name] }).to eq([:fire])
      fire = events.first
      expect(fire[:hits].map { |h| h[:damage] }).to eq([90])
      dispel = fire[:flares].find { |f| f[:name] == :dispel }
      expect(dispel[:hits].map { |h| h[:damage] }).to eq([15])
      expect(dispel[:resolutions].map { |r| r[:result] }).to eq([175])
    end

    it 'keeps a bloom on a creature "forced out of hiding" on the flare, not a phantom fire (raw hunt chunk 22:14:27)' do
      lines = File.readlines(File.join(__dir__, '../../../fixtures/bloom_forced_out_of_hiding.txt'), chomp: true)
      events = described_class.parse_events(lines)
      expect(events.map { |e| e[:name] }).to eq([:fire])
      fire = events.first
      expect(fire[:hits].map { |h| h[:damage] }).to eq([138])
      blooms = fire[:flares].select { |f| f[:name] == :spectral_bloom }
      expect(blooms.map { |f| f[:hits].sum { |h| h[:damage] } }).to eq([15, 7, 25])
      expect(blooms.last[:target_info][:name]).to eq('bloody halfling cannibal')
    end

    it "resumes our shot after a disciple's cloak-of-shadows retaliation so our flare stays ours (raw chunk 23:18:38)" do
      lines = File.readlines(File.join(__dir__, '../../../fixtures/cloak_of_shadows_interrupt.txt'), chomp: true)
      events = described_class.parse_events(lines)
      expect(events.map { |e| [e[:name], e[:inbound]] }).to eq([[:fire, nil], [:cast, true]])
      fire, cast = events
      expect(fire[:hits].map { |h| h[:damage] }).to eq([21])
      phos = fire[:flares].find { |f| f[:name] == :phosphorescence }
      expect(phos[:hits].map { |h| h[:damage] }).to eq([25])
      # weaponless flares (nature's decay, arcane reflex) resume the shot too
      expect(fire[:flares].map { |f| f[:name] }).to contain_exactly(:natures_decay, :arcane_reflex, :phosphorescence)
      expect(cast[:hits]).to be_empty
      expect(cast[:flares]).to be_empty
      expect(cast[:outcomes]).to eq([:warded])
      expect(cast[:resolutions].map { |r| r[:type] }).to eq([:cs_td])
      expect(cast[:attacker]).to include(id: 129623615, name: 'flayed gigas disciple')
    end

    it 'names the resumed shot (attack_uid) on the blind its flare inflicted, though the cast emits last' do
      registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', registry)
      dbl = double('Creature', id: 129623615, name: 'a flayed gigas disciple').as_null_object
      allow(registry).to receive(:[]).with(129623615).and_return(dbl)
      emitted = []
      allow(Lich::Gemstone::Combat::Observers).to receive(:emit) { |type, payload| emitted << [type, payload] }
      lines = File.readlines(File.join(__dir__, '../../../fixtures/cloak_of_shadows_interrupt.txt'), chomp: true)
      described_class.process(lines)
      attacks = emitted.select { |t, _| t == :attack }.map { |_, e| [e[:name], e[:_uid]] }
      expect(attacks).to eq([[:fire, 0], [:cast, 1]])
      blind = emitted.find { |t, p| t == :status && p[:status] == :blind }.last
      expect(blind).to include(attack_uid: 0, flare_seq: 3)
      expect(blind).not_to have_key(:_event)
    end

    it 'keeps an ooze splitting on the hit off the target switcher (raw chunk 23:19:53)' do
      lines = File.readlines(File.join(__dir__, '../../../fixtures/ooze_splatter_fire.txt'), chomp: true)
      events = described_class.parse_events(lines)
      expect(events.map { |e| [e[:name], e[:hits].map { |h| h[:damage] }] }).to eq([[:fire, [51]]])
    end

    it 'parses the sanguine ooze pseudopod attacks and their misses' do
      ooze = bolded(129583295, 'ooze', 'a quivering sanguine ooze')
      smash = described_class.parse_events([
                                             "#{ooze} manifests a thick pseudopod and brings it smashing down at you!",
                                             '  AS: +556 vs DS: +585 with AvD: +38 + d100 roll: +39 = +48',
                                             '   A clean miss.'
                                           ])
      whip = described_class.parse_events([
                                            '<pushBold/>[SMR result: 47 (Open d100: 70, Penalty: 10)]<popBold/>',
                                            "#{ooze} whips a thick pseudopod at you!  The goopy appendage flies wide before retracting back into the central mass of #{bolded(129583295, 'ooze', 'the ooze')}."
                                          ])
      expect(smash.map { |e| [e[:name], e[:inbound], e[:outcomes]] }).to eq([[:natural, true, [:miss]]])
      expect(whip.map { |e| [e[:name], e[:inbound], e[:outcomes], e[:resolutions].map { |r| r[:result] }] }).to eq([[:natural, true, [:miss], [47]]])
    end

    it 'records the ooze shrapnel burst and the disciple rift as inbound room maneuvers with their rolls' do
      ooze = bolded(129583295, 'ooze', 'a quivering sanguine ooze')
      shrap = described_class.parse_events([
                                             "Froth disturbs the surface of #{ooze} as bubbling bulges form over #{bolded(129583295, 'ooze', 'its')} surface, rapidly coagulating into red-black crystalline spikes.  With a convulsive shudder, the ooze flings them outward!",
                                             '<pushBold/>[SMR result: -32 (Open d100: -36, Penalty: 13)]<popBold/>',
                                             'Bobbing and weaving, you dodge the spray of shrapnel!'
                                           ])
      disc = bolded(129629246, 'disciple', 'a flayed gigas disciple')
      rift = described_class.parse_events([
                                            "Zeal twisting #{bolded(129629246, 'disciple', 'her')} features, #{disc} raises a raw and fleshless hand overhead and draws it down, #{bolded(129629246, 'disciple', 'her')} shattered fingernails slicing open a tear in the fabric of the world.",
                                            'Writhing, milky tentacles burst forth from the tortured spatial anomaly, grasping blindly through the areas they glisten with vile humors.',
                                            '<pushBold/>[SMR result: 61 (Open d100: 67, Penalty: 53)]<popBold/>'
                                          ])
      expect(shrap.map { |e| [e[:name], e[:inbound], e[:outcomes], e[:resolutions].map { |r| r[:result] }] }).to eq([[:shrapnel_spray, true, [:evade], [-32]]])
      expect(rift.map { |e| [e[:name], e[:inbound], e[:attacker][:id], e[:resolutions].map { |r| r[:result] }] }).to eq([[:rift_tentacles, true, 129629246, [61]]])
    end

    it "attributes a nearby player's flaming aura to that player, and a spiritual malady tick once, unowned" do
      oozeling = bolded(129648792, 'oozeling', 'a quivering sanguine oozeling')
      aura = described_class.parse_events([
                                            "The flaming aura surrounding <a exist=\"-10174607\" noun=\"Meb\">Meb</a> lashes out at #{oozeling}!",
                                            '<pushBold/>[SMR result: 153 (Open d100: 76, Bonus: 8)]<popBold/>',
                                            '   ... 25 points of damage!'
                                          ])
      expect(aura.map { |e| [e[:name], e[:foreign_caster], e[:target][:id], e[:hits].map { |h| h[:damage] }, e[:resolutions].map { |r| r[:result] }] })
        .to eq([[:flaming_aura, true, 129648792, [25], [153]]])
      mutant = bolded(129575116, 'mutant', 'a squamous reptilian mutant')
      malady = described_class.parse_events([
                                              "A spiritual malady wracks #{mutant} causing 5 points of damage!",
                                              '   ... 5 points of damage!',
                                              '   Unpleasant wound to right arm!'
                                            ])
      expect(malady.map { |e| [e[:name], e[:unowned], e[:target][:id], e[:hits].map { |h| h[:damage] }] }).to eq([[:spiritual_malady, true, 129575116, [5]]])
    end

    it "parses the disciple's leech fling with its held roll and same-line dodge" do
      disc = bolded(129649883, 'disciple', 'a flayed gigas disciple')
      events = described_class.parse_events([
                                              'The layer of bark on you hardens and absorbs the attack!  The bark crackles, but maintains its form.',
                                              '<pushBold/>[SMR result: 0 (Open d100: 81, Penalty: 3)]<popBold/>',
                                              "#{disc} reaches into a pouch at #{bolded(129649883, 'disciple', 'her')} waist and draws back a hand covered in fat leeches, so deep a violet in hue as to be almost black.  With a fleshless sneer, she flings the parasites at you!  You duck to narrowly avoid the flying vermiforms!"
                                            ])
      # the barkskin absorb stays its own intercepted unknown (an attack
      # the bark ate whole); the fling owns the roll and the dodge
      expect(events.map { |e| [e[:name], e[:outcomes]] }).to contain_exactly([:natural, [:evade]], [:unknown, [:intercept]])
      fling = events.find { |e| e[:name] == :natural }
      expect([fling[:inbound], fling[:attacker][:id], fling[:resolutions].map { |r| r[:result] }]).to eq([true, 129649883, [0]])
    end

    it "gives a creature's warding-spell effect line the caster of the cast it follows (disciple's wither)" do
      disc = bolded(129649881, 'disciple', 'a flayed gigas disciple')
      events = described_class.parse_events([
                                              "A dark shadowy tendril rises up from #{disc}, writhes its way up a <a exist=\"129604585\" noun=\"bow\">scorched glowbark long bow</a> towards you and lashes out malevolently...",
                                              "The force of #{bolded(129649881, 'disciple', "a flayed gigas disciple's")} power warps the air as it surges toward you!",
                                              '  CS: +497 - TD: +485 + CvA: +13 + d100: +92 - -5 == +122',
                                              '  Warding failed!',
                                              'The layer of bark on you hardens and absorbs the magical energy!  The bark crackles, but maintains its form.',
                                              'A nebulous haze shimmers into view around you, plunging inward to envelop your left eye!',
                                              '   ... 10 points of damage!',
                                              '   Left eyelid turns to dust, causing you to blink rapidly, or try to.',
                                              'Cloudy tendrils writhe throughout your form, ravaging you for 15 points of damage!'
                                            ])
      expect(events.map { |e| [e[:name], e[:inbound], e[:attacker]&.[](:id), e[:hits].map { |h| h[:damage] }] })
        .to eq([[:cast, true, 129649881, []], [:wither, true, 129649881, [10, 15]]])
    end

    it 'parses the ooze vitality drain, the cannibal ambush swing, and rot / neck-bleed ticks' do
      ooze = bolded(129635928, 'ooze', 'a quivering sanguine ooze')
      drain = described_class.parse_events([
                                             "#{ooze} whips a pseudopod toward you, brushing your exposed flesh.  The layer of bark on you hardens and absorbs the magical energy!  The bark crackles, but maintains its form.",
                                             "  Dizziness rushes through you as #{bolded(129635928, 'ooze', "the ooze's")} appendage siphons away your vitality!",
                                             '   ... 20 points of damage!'
                                           ])
      expect(drain.map { |e| [e[:name], e[:inbound], e[:attacker][:id], e[:hits].map { |h| h[:damage] }] }).to eq([[:natural, true, 129635928, [20]]])
      cannibal = bolded(129776223, 'cannibal', 'a bloody halfling cannibal')
      ambush = described_class.parse_events([
                                              "With an ululating shriek, #{cannibal} leaps from the shadows and hammers blindly at you with grimy little fists!",
                                              '  AS: +476 vs DS: +585 with AvD: +25 + d100 roll: +48 = -36',
                                              '   A clean miss.'
                                            ])
      expect(ambush.map { |e| [e[:name], e[:inbound], e[:outcomes], e[:resolutions].size] }).to eq([[:natural, true, [:miss], 1]])
      mutant = bolded(129870380, 'mutant', 'a squamous reptilian mutant')
      ticks = described_class.parse_events([
                                             "Skin peels off #{mutant}'s body, exposing rotting flesh.",
                                             '   ... 2 points of damage!',
                                             '   Unpleasant wound to left arm!',
                                             "Trickles of blood course from #{bolded(129870380, 'mutant', 'the reptilian mutant')}'s neck.",
                                             '   ... 4 points of damage!'
                                           ])
      expect(ticks.map { |e| [e[:name], e[:unowned], e[:hits].map { |h| h[:damage] }] }).to eq([[:rot, true, [2]], [:bleed, true, [4]]])
    end

    it 'wraps a held pre-flare as its own event when no swing follows in the next chunk' do
      nock_chunk = [
        " ** Your <a exist=\"125479289\" noun=\"bow\">glowbark long bow</a> glows brightly for a moment, consuming the magical energies around the #{bolded(123956079, 'mastodon', 'armored battle mastodon')}! **",
        '   ... 20 points of damage!'
      ]
      expect(described_class.parse_events(nock_chunk)).to eq([])
      events = described_class.parse_events(['You are now in a defensive stance.'])
      expect(events.map { |e| [e[:name], e[:target][:id]] }).to eq([[:dispel, 123956079]])
    end

    it 'names the "grabs at ... unable to find a purchase" tangleweed miss' do
      golem = bolded(127053510, 'golem', 'a behemothic gorefrost golem')
      events = described_class.parse_events(["The lashing emerald briar grabs at #{golem}, unable to find a purchase."])
      expect(events.map { |e| [e[:name], e[:target][:id], e[:outcomes]] }).to eq([[:tangleweed, 127053510, [:miss]]])
    end

    it 'squeezes the doubled space a hidden adjective leaves in a creature link' do
      events = described_class.parse_events([
                                              'The thorny barrier surrounding you blocks the attack from the <pushBold/><a exist="127089942" noun=" cannibal">halfling  cannibal</a><popBold/>!'
                                            ])
      expect(events.first[:attacker][:name]).to eq('halfling cannibal')
    end

    it 'labels environmental and self-inflicted damage by source' do
      cold = described_class.parse_events(['The burn of the cold tears precious warmth from your flesh.', '   ... 6 points of damage!'])
      thorn = described_class.parse_events(['As a darkened ruic longbow etched with thorns leaves your left hand, the thorns embedded in your skin painfully rip away, vines quickly retreating.',
                                            '   ... 1 point of damage!'])
      expect(cold.first.values_at(:name, :inbound)).to eq([:frigid_wind, true])
      expect(cold.first[:attacker]).to eq({ name: 'environment' })
      expect(thorn.first.values_at(:name, :inbound)).to eq([:thorn_recoil, true])
      expect(thorn.first[:attacker]).to eq({ name: 'self' })
    end
  end

  # Parse-phase facts (message statuses, UCS, spell loss) used to be emitted
  # the moment their line parsed - BEFORE the chunk's :attack emit - so a
  # recorder keying on "the open attack" filed them under the previous one
  # (real-feed 2026-09-07: every blind 1-3s ahead of its attack). process()
  # now queues them and flushes after the attacks.
  describe 'fact emit ordering (statuses after their chunk\'s attack)' do
    let(:creature) do
      instance_double('Creature', id: 121654846, name: 'a tattooed gigas berserker').tap do |c|
        allow(c).to receive(:add_damage)
        allow(c).to receive(:add_status)
        allow(c).to receive(:remove_status)
        allow(c).to receive(:add_stun_estimate)
        allow(c).to receive(:has_status?).and_return(false)
        allow(c).to receive(:crtr_flag?).and_return(false)
      end
    end

    before do
      allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
        track_statuses: true, track_ucs: false, emit_attacks: true, track_damage: true, track_wounds: false
      )
      allow(described_class).to receive(:record_delta).and_yield({ statuses: [], wounds: [], damage: 0 })
      allow(described_class).to receive(:emit_debug_summary)
      allow(described_class).to receive(:apply_crit)
      stub_const('Lich::Gemstone::Combat::CreatureInstance', Module.new.tap { |m| m.const_set(:STUN_ROUND_SECONDS, 5) })
      registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', registry)
      allow(registry).to receive(:[]).with(121654846).and_return(creature)
      described_class.instance_variable_set(:@death_watch, nil)
    end

    it 'emits the :attack before the blind :status parsed from the same chunk' do
      zerk = bolded(121654846, 'berserker', 'a tattooed gigas berserker')
      order = []
      allow(Lich::Gemstone::Combat::Observers).to receive(:emit) { |type, data| order << [type, data[:status]] }
      described_class.process([
                                "You fire a faewood arrow at #{zerk}!",
                                '  AS: +663 vs DS: +271 with AvD: +27 + d100 roll: +80 = +499',
                                '   ... and hit for 188 points of damage!',
                                "You blinded #{zerk}!"
                              ], at: Time.at(1))
      attack_i = order.index { |t, _| t == :attack }
      blind_i = order.index { |t, s| t == :status && s == :blind }
      expect(attack_i).not_to be_nil
      expect(blind_i).not_to be_nil
      expect(attack_i).to be < blind_i
    end

    it 'still emits immediately when parse_events is called on its own' do
      zerk = bolded(121654846, 'berserker', 'a tattooed gigas berserker')
      described_class.parse_events(["You blinded #{zerk}!"])
      expect(Lich::Gemstone::Combat::Observers).to have_received(:emit)
        .with(:status, hash_including(status: :blind))
    end
  end

  # Death detection (2026-09-07). Only fatal crits marked kills; a creature
  # that died of hit-point loss or a coup de grace never emitted anything, so
  # recorders kept it alive forever (9 mastodon deaths in a hunt, 3 recorded).
  # The room feed's <crtrStatus dead="1"/> lands on the creature as
  # crtr_flag?(:dead); the processor watches every creature an event touched
  # and emits one `dead` status when that flag turns on - immediately, or on
  # a later chunk when the room refresh lags the death message.
  describe 'death watch (room-feed dead flag -> :status dead)' do
    let(:dead_flag) { { value: false } }
    let(:creature) do
      flag = dead_flag
      instance_double('Creature', id: 900, name: 'a heavily armored battle mastodon').tap do |c|
        allow(c).to receive(:add_damage)
        allow(c).to receive(:add_status)
        allow(c).to receive(:remove_status)
        allow(c).to receive(:has_status?).and_return(false)
        allow(c).to receive(:crtr_flag?) { |key| key == :dead && flag[:value] }
      end
    end

    before do
      allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
        track_statuses: true, track_ucs: false, emit_attacks: true,
        track_damage: true, track_wounds: false
      )
      allow(described_class).to receive(:record_delta).and_yield({ statuses: [], wounds: [], damage: 0 })
      allow(described_class).to receive(:emit_debug_summary)
      registry = Class.new { def self.[](_id); end }
      stub_const('Lich::Gemstone::Combat::Creature', registry)
      allow(registry).to receive(:[]).with(900).and_return(creature)
      # fresh watch state per example (module-level ivars)
      described_class.instance_variable_set(:@death_watch, nil)
      described_class.instance_variable_set(:@death_announced, nil)
    end

    def hp_kill_event
      { name: :fire, at: Time.at(1), target: { id: 900 },
        hits: [{ damage: 120, crit: nil }], flares: [], statuses: [], outcomes: [], resolutions: [] }
    end

    it 'emits :status dead when the touched creature is flagged dead after the event' do
      dead_flag[:value] = true
      described_class.persist_event(hp_kill_event) # watches the creature
      described_class.process([]) # the sweep runs at chunk level
      expect(Lich::Gemstone::Combat::Observers).to have_received(:emit)
        .with(:status, hash_including(id: 900, status: 'dead', action: :add)).once
    end

    it 'emits nothing for a creature that is still alive' do
      described_class.persist_event(hp_kill_event)
      expect(Lich::Gemstone::Combat::Observers).not_to have_received(:emit)
        .with(:status, hash_including(status: 'dead'))
    end

    it 'emits the dead status AFTER the chunk\'s :attack, even when the registry already shows the death' do
      # the async worker lags the stream: by the time this chunk processes,
      # the room feed has already flagged the creature this chunk killed
      dead_flag[:value] = true
      order = []
      allow(Lich::Gemstone::Combat::Observers).to receive(:emit) { |type, data| order << [type, data[:status]] }
      described_class.process(["You fire a faewood arrow at #{bolded(900, 'mastodon', 'a heavily armored battle mastodon')}!",
                               '  AS: +663 vs DS: +271 with AvD: +27 + d100 roll: +80 = +499',
                               '   ... and hit for 188 points of damage!'], at: Time.at(1))
      expect(order.index { |t, _| t == :attack }).to be < order.index { |t, s| t == :status && s == 'dead' }
    end

    it 'catches a death whose room flag arrives on a later, event-less chunk, and only once' do
      described_class.persist_event(hp_kill_event) # alive at this point
      dead_flag[:value] = true
      described_class.process([]) # quiet chunk: the sweep still runs
      described_class.process([])
      expect(Lich::Gemstone::Combat::Observers).to have_received(:emit)
        .with(:status, hash_including(id: 900, status: 'dead', action: :add)).once
    end

    it 'keeps watching a survivor until it dies (someone else finishing it minutes later still counts)' do
      described_class.persist_event(hp_kill_event)
      8.times { described_class.process([]) }
      dead_flag[:value] = true
      described_class.process([])
      expect(Lich::Gemstone::Combat::Observers).to have_received(:emit)
        .with(:status, hash_including(id: 900, status: 'dead', action: :add)).once
    end

    it 'stops watching a creature that left the registry' do
      described_class.persist_event(hp_kill_event)
      registry = Lich::Gemstone::Combat::Creature
      allow(registry).to receive(:[]).with(900).and_return(nil)
      described_class.process([])
      expect(described_class.instance_variable_get(:@death_watch)).to be_empty
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

    # Re-review finding (mrhoribu, PR #1559): cast_owner was keyed by spell
    # name alone, so OUR pestilence cast on creature A marked a DIFFERENT
    # player's pestilence tick on creature B as ours in the same chunk. Now
    # keyed per victim, so B's tick stays unowned (off our ledger).
    it 'does not let our DoT cast on one creature claim a foreign tick on another' do
      chunk = [
        # WE cast pestilence on the warg -> cast_owner[[:pestilence, warg]] = :self
        "You exhale a virulent green mist toward #{warg}, instantly infecting it!",
        # a DIFFERENT player's pestilence ticks on the maiden (no caster named)
        "Boils rupture all over #{maiden} causing 54 points of damage!",
        '<prompt time="1757186902">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      tick = events.find { |e| e[:name] == :pestilence && e[:hits].any? { |h| h[:damage].to_i == 54 } }
      expect(tick).not_to be_nil
      # the maiden's tick is NOT ours - our cast targeted the warg
      expect(tick[:unowned]).to be_truthy
    end

    it 'still marks OUR OWN DoT tick on the creature we cast on as ours' do
      chunk = [
        "You exhale a virulent green mist toward #{warg}, instantly infecting it!",
        # a later tick on the SAME creature we cast on -> ours (not unowned)
        "Boils rupture all over #{warg} causing 44 points of damage!",
        '<prompt time="1757186903">&gt;</prompt>'
      ]

      events = described_class.parse_events(chunk)
      tick = events.find { |e| e[:name] == :pestilence && e[:hits].any? { |h| h[:damage].to_i == 44 } }
      expect(tick).not_to be_nil
      expect(tick[:unowned]).to be_falsey
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

    it 'captures the crit under emit_attacks alone (recorder reads it off the payload)' do
      # combat_stats enables ONLY emit_attacks; the emitted :attack payload
      # carries the crit, so the lookahead must run for it too.
      event = parse_with(track_statuses: false, track_ucs: false, emit_attacks: true,
                         track_damage: true, track_wounds: false)
      expect(event[:hits].first[:crit]).not_to be_nil
      expect(event[:hits].first[:crit][:location]).to eq('left eye')
    end

    it 'skips the lookahead only when wounds, statuses AND emit are all off' do
      event = parse_with(track_statuses: false, track_ucs: false, emit_attacks: false,
                         track_damage: true, track_wounds: false)
      expect(event[:hits].first[:crit]).to be_nil
    end
  end

  # Spawn-tree lineage: within one prompt blob, the initiating shot is the
  # root; blink's bracketed cast is a game-DECLARED child (parent = the shot,
  # confidence :bracket); everything else is its own root. We assert only what
  # the game declares - a mirror/afterimage echo is NOT chained by guess.
  describe 'spawn-tree lineage (root/parent within a blob)' do
    def process_chunk(chunk)
      events = described_class.parse_events(chunk)
      # mirror Processor.process's uid resolution (object refs -> uids)
      uids = {}.compare_by_identity
      events.each_with_index { |ev, i| uids[ev] = i }
      events.each_with_index do |event, i|
        event[:_uid] = i
        r = event[:root_ref]
        event[:root_uid] = r ? (uids[r] || i) : i
        p = event[:parent_ref]
        event[:parent_uid] = p ? uids[p] : nil
      end
      events
    end

    it 'makes a lone swing its own root with no parent' do
      orc = bolded(4242, 'orc', 'a greater orc')
      chunk = [
        "You swing a slim short sword at #{orc}!",
        '  AS: +400 vs DS: +200 with AvD: +30 + d100 roll: +50 = +280',
        '   ... and hits for 30 points of damage!',
        '<prompt time="1758161235">&gt;</prompt>'
      ]
      ev = process_chunk(chunk).first
      expect(ev[:_uid]).to eq(0)
      expect(ev[:root_uid]).to eq(0)         # its own root
      expect(ev[:parent_uid]).to be_nil      # no spawner
      expect(ev[:parent_confidence]).to be_nil
    end

    it 'links blink\'s bracketed spawned cast to the initiating shot' do
      orc = bolded(4242, 'orc', 'a greater orc')
      chunk = [
        "You swing a glowbark long bow at #{orc}!",
        '  AS: +400 vs DS: +200 with AvD: +30 + d100 roll: +50 = +280',
        '   ... and hits for 30 points of damage!',
        # blink flare (spawns:true) then its bracketed natures_fury cast
        'Your glowbark long bow suddenly lights up with hundreds of tiny blue sparks!',
        'You close your eyes in a moment of intense concentration, channeling the pure natural power of your surroundings.',
        "The surroundings advance upon #{orc} with relentless fury!",
        '  CS: +484 - TD: +293 + CvA: +25 + d100: +93 == +309',
        '  Warding failed!',
        "#{orc} is struck by a sharp piece of mist-covered debris!",
        '   ... 56 points of damage!',
        'As swiftly as the chaos came to be, it recedes again into the surroundings.',
        '<prompt time="1758161236">&gt;</prompt>'
      ]
      events = process_chunk(chunk)
      root = events.find { |e| e[:name] == :swing || e[:_uid] == 0 } || events.first
      child = events.find { |e| e[:parent_uid] }
      expect(child).not_to be_nil
      expect(child[:parent_uid]).to eq(root[:_uid])
      expect(child[:root_uid]).to eq(root[:_uid])
      expect(child[:parent_confidence]).to eq(:bracket)
    end

    it 'does NOT chain an unbracketed follow-on shot (no guessed lineage)' do
      orc = bolded(4242, 'orc', 'a greater orc')
      chunk = [
        "You fire a faewood arrow at #{orc}!",
        '   ... and hits for 20 points of damage!',
        # a second bare shot with no bracket - must be its own root, not a guess
        "You fire a faewood arrow at #{orc}!",
        '   ... and hits for 25 points of damage!',
        '<prompt time="1758161237">&gt;</prompt>'
      ]
      events = process_chunk(chunk).select { |e| e[:_attack_born] }
      expect(events.size).to be >= 2
      # neither shot claims the other as parent
      expect(events.map { |e| e[:parent_uid] }.compact).to be_empty
      # each is its own root
      events.each { |e| expect(e[:root_uid]).to eq(e[:_uid]) }
    end

    # Re-review finding (PR #1559): a multi-target AoE line that BOTH switches
    # target AND matches an attack def (per-target arrow at a different
    # creature) had the attack branch discard the switch artifact's inherited
    # lineage and recompute a fresh root - fragmenting the AoE into N
    # single-hit roots. Each per-target hit is the SAME attack on another
    # creature and must share the opener's root.
    it 'shares one root across a multi-target AoE hitting different creatures' do
      orc = bolded(501, 'orc', 'a greater orc')
      troll = bolded(502, 'troll', 'a cave troll')
      chunk = [
        "You fire a faewood arrow at #{orc}!",
        '   ... and hits for 20 points of damage!',
        # same attack, next creature - a target switch that is also an attack def
        "You fire a faewood arrow at #{troll}!",
        '   ... and hits for 15 points of damage!',
        '<prompt time="1758161238">&gt;</prompt>'
      ]
      events = process_chunk(chunk).select { |e| e[:_attack_born] }
      expect(events.size).to eq(2)
      expect(events.map { |e| e[:target][:id] }).to eq([501, 502]) # different creatures
      # both share the opener's root (uid 0), not fragmented into two roots
      expect(events.map { |e| e[:root_uid] }).to eq([0, 0])
    end

    # Re-review round 4 (PR #1559): the switch-artifact lineage-carry branch
    # added above had no foreign/inbound guard (its sibling branches do), so a
    # nearby player's attack on a DIFFERENT creature in the same chunk - which
    # is both a target switch AND an attack def - inherited our lineage and
    # grafted onto our spawn tree (over-counting root rollups). A foreign event
    # must self-root regardless of the switch artifact.
    it 'does not graft a foreign attack (switched target) onto our spawn tree' do
      orc = bolded(501, 'orc', 'a greater orc')
      troll = bolded(502, 'troll', 'a cave troll')
      chunk = [
        "You fire a faewood arrow at #{orc}!",
        '   ... and hits for 20 points of damage!',
        # a NEARBY PLAYER's own attack on another creature, same chunk: switches
        # target (building an artifact that inherited OUR lineage) AND parses as
        # a foreign_caster attack def
        "Heavenscent swings a warhammer at #{troll}!",
        '   ... and hits for 33 points of damage!',
        '<prompt time="1758161239">&gt;</prompt>'
      ]
      events = process_chunk(chunk).select { |e| e[:_attack_born] }
      ours = events.find { |e| !e[:foreign_caster] }
      foreign = events.find { |e| e[:foreign_caster] }
      expect(ours).not_to be_nil
      expect(foreign).not_to be_nil
      # the foreign attack is its OWN root, not a child of ours
      expect(foreign[:root_uid]).to eq(foreign[:_uid])
      expect(foreign[:root_uid]).not_to eq(ours[:_uid])
      expect(foreign[:parent_uid]).to be_nil
    end
  end
end
