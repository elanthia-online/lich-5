# frozen_string_literal: true

#
# Message Definitions - non-combat game lines scripts react to, as
# observer events.
#
# The combat defs answer "what happened to whom in a fight". These answer
# the other questions a hunting script keeps a DownstreamHook open for:
# a weapon knocked away, a curse or infection taken, a trap sprung, an
# ambusher arriving, a bolt, a bless shrugged off, an arrow stuck, a
# charge counter, a spell mark on a creature. Every one of these was a
# private regex in bigshot, ecleanse or eohunter; here each is one def in
# a family, gated by PatternGate like the combat tables, scanned only
# while something subscribes to the family (see Combat::Messages).
#
# A def is an event name, a pattern, and a data block that turns the
# MatchData into the event payload. Payloads always also carry :raw, the
# line. Patterns are pinned to the messaging the scripts were matching in
# the wild (ecleanse set_hooks, bigshot hunt_monitor, eohunter watch
# rules, 2026-09), one form per def so PatternGate can gate each; a
# top-level alternation would gate nothing.
#

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        module Messages
          MessageDef = Struct.new(:event, :pattern, :data)
          Family = Struct.new(:name, :defs, :gate, :always_scan) do
            # Every event this family can emit.
            def events = defs.map(&:event).uniq

            def rejects?(line) = PatternGate.rejects?(gate, always_scan, line)
          end

          LINK = /<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">[^<]+<\/a>/i.freeze

          # Build a family from [event, pattern, data] rows.
          def self.family(name, rows)
            defs = rows.map { |event, pattern, data| MessageDef.new(event, pattern, data) }
            gate, always = PatternGate.build(defs.map(&:pattern))
            Family.new(name, defs.freeze, gate, always)
          end

          NONE = ->(_m) { {} }

          FAMILIES = [
            # ecleanse set_hooks 1618: the line-driven recoveries. The disarm
            # lines carry the weapon's noun; what hand it was in and where
            # we stood is the subscriber's to read at the moment.
            family(:disarm, [
                     [:disarm_seen, %r{Your <a exist="[^"]+" noun="(?<noun>[^"]+)">[^<]+</a> is knocked from your grasp}, ->(m) { { kind: :recover, noun: m[:noun] } }],
                     [:disarm_seen, %r{your <a exist="[^"]+" noun="(?<noun>[^"]+)">[^<]+</a> at .+?\.  The weapon rebounds off of the hardened .+? and is wrenched from your hand\.  It slides along the ground and disappears into the shadows!}, ->(m) { { kind: :recover, noun: m[:noun] } }],
                     [:disarm_seen, %r{^Your <a exist="[^"]+" noun="(?<noun>[^"]+)">[^<]+</a> strikes one of the bony protrusions on <pushBold/>an? <a exist="\d+" noun="[^"]+">[^<]+</a><popBold/> \w+ and it is wrenched out of your grasp!}, ->(m) { { kind: :recover, noun: m[:noun] } }],
                     [:disarm_seen, %r{^You swing your <a exist="[^"]+" noun="(?<noun>[^"]+)">[^<]+</a> at <pushBold/>(?:an?|the) <a exist="[^"]+" noun="[^"]+">[^<]+</a><popBold/>\.  The weapon strikes one of the bony protrusions on the <pushBold/><a exist="[^"]+" noun="[^"]+">[^<]+</a><popBold/> \w+ and it is wrenched out of your grasp!}, ->(m) { { kind: :recover, noun: m[:noun] } }],
                     [:disarm_seen, %r{Your <a exist="[^"]+" noun="(?<noun>[^"]+)">[^<]+</a> tears free from your hands and floats}, ->(m) { { kind: :telekinetic_recover, noun: m[:noun] } }],
                     [:disarm_seen, %r{The webbing entangles your <a exist="[^"]+" noun="(?<noun>[^"]+)">[^<]+</a>, rendering it useless}, ->(m) { { kind: :recover_weapon_webbing, noun: m[:noun] } }],
                     [:sanctum_transform, %r{Striking with a serpent's unsettling quickness, .*\.  Vile .*, kindling it into an unholy semblance of life\.  The .* form twists and mutates, sprouting scales and cold eyes as it transforms into a <a exist="\d+" noun="(?<noun>[^"]+)">[^<]+</a>!}, ->(m) { { noun: m[:noun] } }]
                   ]),

            # ecleanse: afflictions and traps that take a trip to clear.
            family(:hazard, [
                     [:itchy_curse, /You shiver slightly as an invisible rash covers your body/, NONE],
                     [:infected_wound, /The flesh around the wound feels hot and cold at the same time, heavy with infection\./, NONE],
                     [:hive_trap, /You notice a flickering glint in the shadows/, ->(_m) { { kind: :apparatus } }],
                     [:hive_trap, /The apparatus flickers with deadly radiance/, ->(_m) { { kind: :apparatus } }],
                     [:hive_trap, /The ground churns violently as flashes of chitin jut from its depths/, ->(_m) { { kind: :ground } }],
                     [:hive_trap, /The ground underfoot churns violently and huge chitinous mandibles flash as the insectoid monstrosity below goes into a feeding frenzy!/, ->(_m) { { kind: :ground } }],
                     [:hive_trap, /Hindered by the churning terrain, you are helpless as the concealed assailant's mandibles snap at you from the safety of its pit trap!/, ->(_m) { { kind: :ground } }],
                     [:entangled, /^An unseen force entangles you, restricting your movement!/, NONE]
                   ]),

            # bigshot hunt_monitor 2322-2383: the flee rules' lines.
            family(:ambush, [
                     [:ambusher, %r{<a exist="-?\d+" noun="(?<noun>[a-zA-Z]*?)">[a-zA-Z]*?</a> leaps from hiding to attack!}i, ->(m) { { noun: m[:noun] } }],
                     [:ambusher, /flies out of the shadows toward/i, ->(_m) { { noun: nil } }],
                     [:ambusher, /A shadowy figure leaps from hiding to attack/i, ->(_m) { { noun: nil } }],
                     [:bolted, /^You bolt/i, NONE]
                   ]),

            # bigshot hunt_monitor 2406-2416: held in place, freed, the item
            # limit.
            family(:hold, [
                     [:rooted, /You don't seem to be able to move(?: your legs)? to do that\./, NONE],
                     [:rooted, %r{You are unable to get out of the way as <pushBold/>the <a exist="(?<id>\d+)" noun="snake">snake</a><popBold/> coils tightly around you, holding you in place!}, ->(m) { { id: m[:id] } }],
                     [:unrooted, %r{You're finally able to break free of <pushBold/>the <a exist="(?<id>\d+)" noun="snake">snake's</a><popBold/> coils!}, ->(m) { { id: m[:id] } }],
                     [:item_limit, /^You are unable to hold the number of items /, NONE],
                     [:item_limit, /^You note some treasure of interest but are unable to pick any up\./, NONE],
                     [:item_limit, /^At your touch, the lit sigils marking your .+ ignite, then quickly sputter out again\./, NONE]
                   ]),

            # bigshot hunt_monitor 2359-2367: a blessing shrugged off or gone.
            family(:bless, [
                     [:bless_shrugged, %r{The <a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">[^<]+</a> strikes? true.* shrugs off some of the damage!}i, ->(m) { { id: m[:id], noun: m[:noun] } }],
                     [:bless_expired, %r{Your <a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">[^<]+</a> returns? to normal\.}i, ->(m) { { id: m[:id], noun: m[:noun] } }]
                   ]),

            # bigshot's archery state (cmd_dislodge, archery aiming, the
            # bonded weapon's return).
            family(:archery, [
                     [:arrow_stuck, %r{The .* sticks in <pushBold/>an? <a exist="(?<id>\d+)" noun="[^"]+">[^<]+</a><popBold/>'s (?:left |right )?(?<where>.*)!}i, ->(m) { { id: m[:id], where: m[:where] } }],
                     [:aiming, /You're now aiming at the (?<where>.*) of/i, ->(m) { { where: m[:where] } }],
                     [:aiming, /You're now no longer aiming at anything in particular/i, ->(_m) { { where: nil } }],
                     [:bond_return, /^An? (?<what>.*) rises out of the shadows and flies back to your waiting hand!/i, ->(m) { { what: m[:what] } }]
                   ]),

            # Marks a spell leaves on a creature, and counters on us
            # (bigshot hunt_monitor 2387-2405).
            family(:marks, [
                     [:haze_703, %r{<pushBold/>.*?<a exist="(?<id>[^"]+)" noun="[^"]+">[^<]+</a><popBold/>.*?is suddenly surrounded by a blood red haze\.}i, ->(m) { { id: m[:id], on: true } }],
                     [:haze_703, %r{The blood red haze dissipates from around.*?<pushBold/>.*?<a exist="(?<id>[^"]+)" noun="[^"]+">[^<]+</a><popBold/>}i, ->(m) { { id: m[:id], on: false } }],
                     [:rebuke_1614, %r{<pushBold/>.*?<a exist="(?<id>[^"]+)" noun="[^"]+">[^<]+</a><popBold/>.*?visibly struggling against your radiant aura!}i, ->(m) { { id: m[:id], on: true } }],
                     [:rebuke_1614, %r{<pushBold/>.*?<a exist="(?<id>[^"]+)" noun="[^"]+">[^<]+</a><popBold/>.*?in awe of your radiant aura!}i, ->(m) { { id: m[:id], on: true } }],
                     [:rebuke_1614, %r{<pushBold/>.*?<a exist="(?<id>[^"]+)" noun="[^"]+">[^<]+</a><popBold/>.*?recovers from being rebuked}i, ->(m) { { id: m[:id], on: false } }],
                     [:swift_justice, /Your Swift Justice charges are increased to (?<n>\d+)\./i, ->(m) { { charges: m[:n].to_i } }],
                     [:swift_justice, /Your Swift Justice surges through you! Its charges are reduced to (?<n>\d+)\./i, ->(m) { { charges: m[:n].to_i } }],
                     [:arcane_reflex, /^Vital energy infuses you, hastening your arcane reflexes!/i, ->(_m) { { active: true } }],
                     [:arcane_reflex, /^Nature's blessing of vitality departs as your arcane prowess returns to normal\./i, ->(_m) { { active: false } }]
                   ]),

            # The weapon reaction prompt (bigshot perform_reaction).
            family(:reaction, [
                     [:weapon_reaction, %r{^You could use this opportunity to <d cmd='WEAPON (?<reaction>\w+\s#\d+)'>.*</d>!}i, ->(m) { { reaction: m[:reaction] } }]
                   ])
          ].freeze

          BY_NAME = FAMILIES.to_h { |f| [f.name, f] }.freeze
          # event -> family, for subscription gating
          FAMILY_OF = FAMILIES.each_with_object({}) { |f, h| f.events.each { |e| h[e] = f } }.freeze
          EVENTS = FAMILY_OF.keys.freeze

          # Every event a line yields across +families+, as [event, data].
          #
          # @param families [Array<Family>] the ones to scan (all by default)
          # @return [Array<Array(Symbol, Hash)>]
          def self.scan(line, families = FAMILIES)
            found = []
            families.each do |family|
              next if family.rejects?(line)

              family.defs.each do |d|
                m = d.pattern.match(line)
                next unless m

                found << [d.event, (d.data.call(m) || {}).merge(raw: line)]
              end
            end
            found
          end
        end
      end
    end
  end
end
