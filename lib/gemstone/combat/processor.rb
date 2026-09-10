# frozen_string_literal: true

#
# Combat Processor V2 - State machine approach for efficient parsing
# Transitions: SEEKING_ATTACK -> SEEKING_DAMAGE -> SEEKING_CRIT -> (repeat)
#

require_relative '../creature'
require_relative '../critranks'
require_relative 'observers'

module Lich
  module Gemstone
    module Combat
      module Processor
        # The floor positions are mutually exclusive: a creature is prone
        # OR sitting OR kneeling (or none), never several at once, and the
        # stand-up messagings are shared between them.
        POSITION_STATUSES = %w[prone sitting kneeling].freeze

        # Trailing-effect / DoT tick defs whose line names the VICTIM but
        # never the CASTER (pestilence's per-round boils, web's ensnare).
        # They exist so the tick damage is not dropped - but when the tick
        # arrives with no cast in the blob (a nearby player's DoT ticking on
        # a creature we can see, or one we walked in on), it is NOT ours.
        # Marked :unowned so the damage still lands on the creature (its
        # received-total is real) while staying out of our damage-dealt
        # rollup, and sits in the recorder's other/unknown bucket for later
        # adjudication - missing def vs genuine drive-by (owner ruling
        # 2026-09-06). A tick IS ours only when our own cast of that spell
        # is visible in the same blob (see cast_owner tracking below).
        UNOWNED_TICK_ATTACKS = %i[pestilence web].freeze

        module_function

        # Include attack details for persistent recording or transient observers.
        # @return [Boolean] whether attack events are currently requested
        def attack_events_requested?
          Tracker.settings[:emit_attacks] || Observers.any_for?(:attack)
        end

        # Scalar allowlist copied before any event retains it. Metadata is not
        # invented for legacy/replay callers which supply no ingestion source.
        # @param value [Object] proposed ingestion metadata
        # @return [Hash, nil] frozen validated context, or nil when incomplete
        def observation_source(value)
          return nil unless value.is_a?(Hash)
          integers = %i[connection_id room_epoch sequence]
          return nil unless integers.all? { |key| value[key].is_a?(Integer) && value[key] >= 0 } && value[:connection_id].positive? && value[:sequence].positive?
          return nil unless %i[game character].all? { |key| value[key].is_a?(String) && !value[key].empty? }
          at = value[:received_at]
          return nil unless at.is_a?(Numeric) && at.real? && at.finite? && at >= 0

          value.slice(*integers, :game, :character, :received_at)
               .transform_values { |item| item.is_a?(String) ? item.dup.freeze : item }.freeze
        end

        # Process a chunk of game lines for combat events. Parses the chunk
        # into events, resolves their in-blob spawn-tree links (event-object
        # refs -> stable per-chunk uids the recorder maps to row ids), stamps
        # each with the chunk's server time, and emits them.
        #
        # @param chunk [Array<String>] game lines
        # @param at [Time, nil] server time for this chunk (from the chunk's
        #   <prompt time=>). Duration estimates are anchored to this rather
        #   than to parse time, which the async worker can lag under load.
        # @param source [Hash, nil] optional socket-ingestion context; invalid or
        #   absent metadata leaves events without verified source provenance
        # @return [void]
        # @note Calls must be serialized; production uses the ordered async worker
        def process(chunk, at: nil, source: nil)
          # Parse-phase fact emits (:status/:ucs/:spell_loss) queue up here
          # and go out AFTER this chunk's :attack emits - see emit_fact.
          @deferred_emits = []
          include_attack_events = attack_events_requested?
          events = parse_events(chunk, source: source, include_attack_events: include_attack_events)
          # Death sweep runs AFTER this chunk's attacks emit, never before:
          # the async worker lags the game stream, so the creature registry
          # already shows a death that THIS chunk's attack caused. Sweeping
          # first credited it to the previous attack (real-feed 2026-09-07:
          # the fatal shot's kill filed under the shot before it). A quiet
          # chunk still sweeps, so a room refresh that lands a chunk after
          # the death message is caught too.
          if events.empty?
            sweep_death_watch
            return
          end

          at ||= prompt_time(chunk) || Time.now
          # Resolve the in-blob spawn-tree links from event-object references
          # into stable per-chunk uids the recorder can map to row ids. Each
          # event gets a _uid; :root_uid/:parent_uid point at other events in
          # THIS chunk (or self for a root). A ref to an event not in the emit
          # set (should not happen) degrades to self-root / no-parent.
          uids = {}.compare_by_identity
          @observation_batch_id = (@observation_batch_id || 0) + 1
          events.each_with_index { |ev, i| uids[ev] = i }
          events.each_with_index do |event, i|
            event[:observation_batch] = { id: @observation_batch_id, index: i, size: events.length }.freeze
            event[:_uid] = i
            root = event[:root_ref]
            event[:root_uid] = root ? (uids[root] || i) : i
            parent = event[:parent_ref]
            event[:parent_uid] = parent ? uids[parent] : nil
            event.delete(:root_ref)
            event.delete(:parent_ref)
          end
          events.each do |event|
            event[:at] = at
            persist_event(event, include_attack_events: include_attack_events)
          end
          sweep_death_watch

          respond "[Combat] Processed #{events.size} events" if Tracker.debug?(:verbose)
        ensure
          flush_deferred_emits
        end

        # -- parse-phase fact emits --------------------------------------------
        #
        # Message statuses ("You blinded X!"), UCS facts and spell losses are
        # recognised while a chunk PARSES, but the chunk's :attack emits only
        # happen afterwards in persist_event. Emitting them immediately put
        # every such fact in front of the attack it belongs to, so a recorder
        # keying on "the attack currently open" filed it under the PREVIOUS
        # attack (real-feed 2026-09-07: every blind stamped 1-3s before its
        # attack). Inside process() they queue and flush after the attacks;
        # a bare parse_events (tests, tools) still emits at once.
        def emit_fact(type, payload)
          if @deferred_emits
            @deferred_emits << [type, payload]
          else
            Observers.emit(type, payload)
          end
        end

        def flush_deferred_emits
          pending = @deferred_emits
          @deferred_emits = nil
          pending&.each { |type, payload| Observers.emit(type, payload) }
        end

        PROMPT_TIME_PATTERN = /<prompt time="(\d+)"/.freeze

        # Extracts the server timestamp from a chunk's <prompt> tag.
        #
        # Chunks are segmented on the prompt, so the last match is this
        # chunk's own prompt.
        #
        # @return [Time, nil] the chunk's prompt time expressed on the LOCAL
        #   clock, or nil when the chunk has no prompt.
        #
        # The prompt stamp is the game SERVER's epoch, but every duration
        # estimate downstream (stun expiry, status timestamps) is compared
        # against local Time.now. XMLData tracks the skew between the two
        # clocks for exactly this reason - a raw Time.at(server_epoch) on a
        # machine 40s ahead of the server produces stun estimates that are
        # already expired the moment they land.
        def prompt_time(chunk)
          chunk.reverse_each do |line|
            if (m = PROMPT_TIME_PATTERN.match(line))
              offset = defined?(XMLData) ? XMLData.server_time_offset.to_f : 0.0
              return Time.at(m[1].to_i + offset)
            end
          end
          nil
        end

        # Flares whose announce spawns a fresh own swing of the same attack
        # (the image/afterimage "echoes your attack with one of its own").
        ECHO_FLARES = %i[mirror_image hunters_afterimage].freeze

        # Creature-linked lines that carry no combat fact and must not drive
        # the target switcher (see the skip in parse_events).
        NARRATION_PATTERN = Regexp.union(
          / leaps from the back of .+? as .+? topples, narrowly avoiding being pinned/,
          / looks a little bit more wary after that display!/,
          /\AYou are now targeting /
        ).freeze

        # A fact-less bare gesture: attack-born :cast with no hits, outcomes or
        # statuses yet. Flares that themselves carry no hit or outcome (a
        # mirror image echoing the gesture - "Nothing happens.") do not make
        # it a real cast; they travel with it to the superseding event. The
        # WRAPPER the spell-specific def supersedes (see the attack branch),
        # and the shape held across a chunk boundary.
        def bare_cast?(event)
          event && event[:_attack_born] && event[:name] == :cast &&
            event[:hits].empty? && event[:outcomes].empty? &&
            event[:flares].all? { |f| f[:hits].empty? && f[:outcomes].empty? } &&
            event[:statuses].empty? && !event[:_had_status]
        end

        # An event is worth persisting only if it has a target to apply data to
        # and any data to apply. Single predicate so every save site agrees
        # (previously three sites used three different criteria).
        def event_worth_saving?(event)
          return false unless event && event[:target][:id]

          !event[:hits].empty? || !event[:statuses].empty? ||
            event[:flares].any? { |f| !f[:hits].empty? }
        end

        # Whether an event survives to persist_event. Registry-wise only
        # events with data matter, but a recorder subscribed to :attack
        # needs more: a clean miss IS data, and an ATTACK-BORN event with
        # nothing attached still records "this attack was initiated" (a
        # wand wave whose crystal roll we cannot parse yet). What must NOT
        # emit is a fact-less SWITCH ARTIFACT: guard-intercept and
        # UCS-positioning lines spawn empty inherited events that used to
        # emit as phantom attacks (real-feed replay, logs/examples/fury.txt).
        def event_savable?(event, include_attack_events: attack_events_requested?)
          return false unless event

          unless event[:target][:id]
            # Inbound (creature -> us) and foreign-target (creature -> a
            # third party) events carry no creature-target id BY
            # CONSTRUCTION - the subject is the attacker. They used to be
            # dropped here wholesale, which was correct for the registry
            # (nothing to apply damage to) but starved the recorder: the
            # replay corpus showed the entire ambush family (and every
            # other inbound family) never emitting (2026-09-05, 237/1000
            # blobs missing their attack). Save them when attack-born or
            # carrying facts; persist_event still returns early on the
            # missing target id, so nothing is ever applied to a creature
            # from these - they exist for :attack subscribers only.
            # ...and the same for OUR OWN targetless events (assault
            # middle rounds arriving in chunks that never name the
            # target - barrage re-nocks lost 101-damage hits): an
            # attack-born event is a fact regardless of whether the
            # chunk let us bind a target. Switch artifacts remain
            # excluded - they are never _attack_born.
            return false unless event[:inbound] || event[:foreign_target] ||
                                event[:_attack_born]

            return include_attack_events &&
                   (event[:_attack_born] || !event[:outcomes].empty? ||
                    !event[:resolutions].empty? || !event[:hits].empty?)
          end

          event_worth_saving?(event) ||
            (include_attack_events &&
             (event[:_attack_born] ||
              !event[:outcomes].empty? || !event[:resolutions].empty? ||
              !event[:flares].empty? || event[:_had_status]))
        end

        # A flare's weapon (linked on its announce line) against a swing's
        # weapon text: "slim short sword" is a substring of "kelyn-edged
        # slim short sword". Flares without weapon info match any swing.
        def flare_matches_weapon?(flare, weapon_text)
          return true unless flare[:weapon] && weapon_text

          weapon_text.include?(flare[:weapon][:name])
        end

        # Whether a flare positively belongs to a DIFFERENT attack than the
        # one currently open.
        #
        # Only a weapon name can prove that, and only when the open event
        # already holds a flare from another weapon. That is the back-to-back
        # signature: two weapons' flares arriving with no attack line between
        # them (dual-wield rounds where the game printed the rolls but not the
        # swings). Without this the second flare would silently join the
        # first flare's attack and its damage would be credited to the wrong
        # weapon.
        #
        # A weapon MISMATCH against the swing text is deliberately NOT
        # sufficient: bow flares name the bow while the swing names the
        # arrow, and a second flare on one swing legitimately names the other
        # held weapon. Both are the same attack.
        def flare_contradicts_weapon?(flare, event)
          fw = flare[:weapon] && flare[:weapon][:name]
          return false unless fw

          event[:flares].any? do |prior|
            pw = prior[:weapon] && prior[:weapon][:name]
            pw && pw != fw
          end
        end

        # Parse combat lines into events without inventing ingestion provenance.
        # @param lines [Array<String>] game lines for one parser chunk
        # @param source [Hash, nil] optional ingestion context to validate and copy
        # @param include_attack_events [Boolean, nil] fixed transient attack
        #   demand for this parse, or nil to snapshot current demand
        # @return [Array<Hash>] parsed attack and related outcome events
        def parse_events(lines, source: nil, include_attack_events: nil)
          source = observation_source(source)
          include_attack_events = attack_events_requested? if include_attack_events.nil?
          events = []
          current_event = nil
          parse_state = :seeking_attack
          current_target = nil

          # Flare state (all chunk-local; see defs/flares.rb):
          #   flare_ctx     - the flare whose damage/crit lines are arriving
          #   pending_flares - flares seen before the swing they belong to
          #                    (pre-flares); claimed by weapon on the next swing
          #   spawn_pending / active_spawn - a spawn-class flare (Blink) casts
          #                    an imbedded spell as a separate attack; its
          #                    sequence brackets mark those events as children
          flare_ctx = nil
          pending_flares = []
          spawn_pending = nil
          active_spawn = nil
          # Echo flares seen in this blob whose spawned swing has not arrived
          # yet, in announce order: [{ flare:, owner: event }]. Consumed FIFO
          # by the bare own swings that follow (see echo lineage below).
          pending_echoes = []
          # Spawn lineage within THIS blob. The whole attack (initiating shot,
          # its flares, any spawned echo attacks and their own flares) resolves
          # inside one prompt-bounded chunk before roundtime - so the blob is a
          # closed spawn tree with a single root. spawn_root holds the current
          # tree's root event (our own initiating attack); every later OWN
          # attack in the blob that is spawn-born (a mirror/afterimage echo, or
          # a bracketed blink cast) points its :root at it. Foreign/inbound/
          # orphan events are their own root and reset it. Only lineage we can
          # assert is stamped: blink via its bracket (:parent + confidence
          # :bracket); ambiguous mirror/afterimage immediate-parent is left
          # nil (root still known) rather than guessed. See recorder root/
          # parent_attack_id.
          spawn_root = nil
          # Rolls that could not claim a virgin sink. An array: several can
          # stack up (volley's per-arrow SMRs, trailing rider maneuvers) and
          # the old single slot silently overwrote all but the last.
          pending_resolutions = []
          # Armed by an ambush prefix line; claimed by the next attack (or
          # by an outcome when the ambush is wholly negated and no attack
          # line is ever printed).
          pending_ambush = nil
          # Armed by a guardian redirect prefix ("<shield-maiden> throws
          # herself between you and the <mastodon> to intercept your
          # attack!"); claimed by the next own attack, whose target IS the
          # guardian. Records that the DS rolled against was the
          # guardian's, not the intended victim's (see REDIRECT_PREFIXES).
          pending_redirect = nil
          # Dispel-family flares seen in THIS chunk, by stripped target id
          # (:any when the flare line names no target). Used to attribute
          # spell_loss cause - a wear-off riding a dispel strip means
          # something different from natural expiry or death cleanup.
          chunk_dispels = []
          # Ownership of DoT/effect casts we saw in this blob, keyed PER VICTIM
          # as [spell_name, target_key] (target_key = the victim's exist id, or
          # its name when unresolved). :self when our 2p cast line fired ("You
          # exhale a virulent green mist toward X..."), so X's trailing ticks
          # are ours; a player name when a foreign cast opener fired. A tick
          # whose (spell, victim) is NOT in here is unowned - a fact about the
          # creature, not a claim on our ledger (see UNOWNED_TICK_ATTACKS).
          #
          # Per-victim is load-bearing: keying by spell name alone let our
          # pestilence cast on creature A mark a DIFFERENT player's pestilence
          # tick on creature B as ours, in the same chunk (overlapping same-
          # family AoE DoTs are normal in group hunts). The victim dimension
          # keeps each cast's ownership bound to the creature it targeted.
          cast_owner = {}
          # [spell_name, victim] key: id when we have it, else the printed name.
          cast_owner_key = lambda do |name, tgt|
            [name, (tgt && (tgt[:id] || tgt[:name]))]
          end
          # Foreign-attacker latch: a nearby player's AoE (pulverize, and
          # other openers that name the actor but whose per-target swing
          # lines do NOT) fans out into actor-less swing/effect lines. Their
          # opener sets this to the player's name; while set, actor-less
          # attack events inherit foreign_caster so the whole chain stays off
          # our ledger (real-feed, GSIV-Nisugi 2026-09-06: Heavenscent's
          # pulverize dumped ~825 swing damage into our web event). Cleared
          # the instant WE act (a 2p "You ..." attack reclaims ownership).
          # Chunk-local, so a prompt boundary clears it for free.
          foreign_latch = nil
          # Facts with NO recognized initiation anywhere in the chunk
          # (bespoke initiations we have no def for - the burnt-arms
          # snatch, the wraith-shark charge). The def layer sees their
          # damage and outcomes; without this sink the state machine
          # silently dropped them (replay 2026-09-05, grasp_arms blobs).
          # Wrapped at end-of-chunk as a targetless :unknown orphan -
          # persist_event never applies it (no target id), recorders see
          # the facts.
          orphan_hits = []
          orphan_outcomes = []

          # A bare gesture held over from the previous chunk (see the hold at
          # the end of this method). Re-open it as the current event so the
          # spell-result line that begins THIS chunk can supersede it exactly
          # as it would in-blob. _held marks it so it is emitted, not re-held,
          # if nothing supersedes it here; _line is cleared so the switch-
          # artifact check cannot mistake it for an event born on this chunk's
          # first line.
          if (held = @held_cast)
            @held_cast = nil
            unless held[:source] && source && %i[connection_id game character room_epoch].all? { |key| held[:source][key] == source[key] }
              held[:source] = nil
            end
            held[:_held] = true
            held[:_line] = nil
            current_event = held
            current_target = held[:target] if held[:target] && held[:target][:id]
            parse_state = :seeking_damage
          end

          lines.each_with_index do |line, index|
            next if line.strip.empty?
            # Room-window components (objs/players) are full of bold creature
            # links; feeding them to the target-switcher spawns phantom events
            # for bystander creatures that were never attacked.
            next if line.include?('<component id=')
            # Narration that links creatures but is no combat fact: a rider
            # leaping clear of its toppling mount, bystanders growing wary
            # after a kill, our own target-set echo. Fed to the target
            # switcher these split the open attack into phantom per-creature
            # events (real-feed 2026-09-07: one briar lash recorded as three
            # tangleweed rows because the rider dismounted mid-lash).
            next if NARRATION_PATTERN.match?(line)

            # Extract creature target once per line; reused by the status
            # handler and the target-switch logic below.
            #
            # On an INBOUND line (a creature attacking US) the only creature
            # link is the ATTACKER. Feeding it to the switcher would retarget
            # the event onto that creature, so the damage and crits it dealt
            # to us get applied to it instead - the same misattribution the
            # parser fallback caused, arriving by a second route.
            # ONE attack scan per line, shared by the two consumers below.
            #
            # inbound_attack? used to re-run the whole ATTACK_LOOKUP loop that
            # the attack branch runs again 250 lines down, and threw away
            # everything but a boolean. That duplicate scan measured 3.2s of a
            # 11.4s parse (98,800 lines) - the two calls together were 56% of
            # total parse time, half of it pure repetition. parse_attack
            # already reports :inbound, so hoisting it serves both.
            line_attack = Parser.parse_attack(line)
            inbound_line = line_attack ? line_attack[:inbound] : false
            line_target = inbound_line ? nil : Parser.extract_target_from_line(line)
            # Guardian redirect announce (see pending_redirect decl). Hoisted
            # here because the line BOLDS THE GUARDIAN, and the target
            # switcher below would otherwise read that link as a switch off
            # the open attack - saving it fact-less and spawning an inherited
            # phantom on the guardian (the UAC shape then re-switched back on
            # the positioning line: three events for one kick).
            line_redirect = Definitions::Attacks.redirect_prefix(line)
            # The id a status applied to on THIS line: after the switch/attack
            # handling below, the event holding that target is flagged - a
            # status IS a fact, and a per-target line whose only payload is
            # the status (pindown's immobilize) must keep its event alive
            # through event_savable? (statuses live on the creature, not the
            # event, so the fields alone can't show it).
            line_status_id = nil

            # Always check for status effects on every line (even outside combat)
            if Tracker.settings[:track_statuses]
              if (status_result = Parser.parse_status(line))
                if line_target && line_target[:id]
                  # Use ID-based lookup - this is most reliable
                  line_status_id = line_target[:id]
                  if status_result.is_a?(Hash)
                    apply_status_to_target(status_result[:status], line_target[:name], line_target[:id], status_result[:action])
                  else
                    # Legacy format - status_result is just the status symbol
                    apply_status_to_target(status_result, line_target[:name], line_target[:id], :add)
                  end
                elsif status_result.is_a?(Hash) && status_result[:target]
                  # Fallback to name-based lookup only if no ID available
                  apply_status_to_target(status_result[:status], status_result[:target], nil, status_result[:action])
                elsif status_result.is_a?(Hash) && !line.match?(/\A\s*Your?\b/) &&
                      (subject = (current_target && current_target[:id] ? current_target : nil) ||
                                 (flare_ctx && flare_ctx[:target_info]))
                  # Pronoun status lines ("It is knocked to the ground!")
                  # carry no link and no name capture - they describe the
                  # creature we are fighting, so bind them to the current
                  # target. During an INBOUND event there is no current
                  # target, but an active flare's own target still binds
                  # (shield-spike knockdown: our spike jabs the attacker
                  # and ITS pronoun knockdown follows - replay 2026-09-05).
                  # 2p lines ("You are stunned!") describe US, never
                  # the creature - the Your?/You guard keeps them out.
                  line_status_id = subject[:id]
                  apply_status_to_target(status_result[:status], subject[:name],
                                         subject[:id], status_result[:action])
                elsif status_result.is_a?(Hash) && line.match?(/\A\s*Your?\b/)
                  # 2p: the status is OURS ("You are stunned!"). Never a
                  # creature application - but it IS a fact (inbound
                  # attacks stun US), so emit it for recorders with the
                  # :self subject instead of dropping it (replay
                  # 2026-09-05: every 2p status was invisible).
                  emit_fact(:status, id: nil, name: 'self',
                                     status: status_result[:status],
                                     action: status_result[:action])
                end
                respond "[Combat] Found status effect: #{status_result}" if Tracker.debug?(:verbose)
              end

              # Spell wear-off lines (third-person, pinned spells only -
              # defs/spell_losses.rb). Observer feed, not creature state:
              # the loss is a fact about a spell, not a status, and the
              # subject may be a player in view rather than a creature.
              #
              # cause distinguishes the three ways a spell leaves (owner
              # ruling 2026-09-04): :dispel when a dispel-family flare
              # struck this chunk (untargeted flares count for any
              # subject), :death when the subject creature is already
              # known dead (death cleanup strips the whole stack - not a
              # meaningful expiry), nil when neither is visible (natural
              # expiry, or cause outside this chunk).
              if (loss = Parser.parse_spell_loss(line))
                cause = nil
                if chunk_dispels.include?(loss[:id]) || chunk_dispels.include?(:any)
                  cause = :dispel
                elsif loss[:id] && defined?(Creature) && (c = Creature[loss[:id]]) &&
                      (c.dead? || (c.respond_to?(:crtr_flag?) && c.crtr_flag?(:dead)))
                  cause = :death
                end
                emit_fact(:spell_loss, id: loss[:id], name: loss[:name],
                                       spell: loss[:spell], spell_name: loss[:spell_name],
                                       cause: cause)
                respond "[Combat] Spell loss: #{loss[:spell]} #{loss[:spell_name]} off #{loss[:name]}#{cause ? " (#{cause})" : ''}" if Tracker.debug?(:verbose)
              end
            end

            # Always check for UCS events on every line
            if Tracker.settings[:track_ucs]
              if (ucs_result = Parser.parse_ucs(line))
                apply_ucs_to_target(ucs_result, current_target)
                respond "[Combat] Found UCS event: #{ucs_result}" if Tracker.debug?(:verbose)
              end
            end

            # Flare announce lines. A flare attaches to the current event when
            # its weapon matches the swing's (post-flare); otherwise it is held
            # for the next matching swing (pre-flare, e.g. dispel gloves that
            # resolve before the attack). Position is ground truth for timing.
            if (flare = Parser.parse_flare(line))
              flare[:hits] = []
              flare[:outcomes] = []
              flare[:resolutions] = []
              flare[:target_info] = line_target if line_target
              # arm spell_loss cause attribution for the rest of the chunk
              if %i[dispel sigil_dispel dispel_flux sigil_bane].include?(flare[:name])
                chunk_dispels << (line_target ? line_target[:id] : :any)
              end
              # Some flare announce lines carry damage INLINE ("the miasma
              # around X flares causing 58 points of damage!") - the same
              # shape as inline attack damage (replay 2026-09-05)
              if (inline = Parser.parse_damage(line))
                flare[:hits] << { damage: inline, crit: nil }
                respond "[Combat] Found inline flare damage: #{inline}" if Tracker.debug?(:verbose)
              end

              # A flare belongs to the attack that is open when it fires.
              # Weapon info DISAMBIGUATES rather than gates: it is only
              # consulted to reject a flare whose named weapon contradicts
              # the open swing, and 63% of attacks name no weapon at all
              # (spells, volley), so requiring a match orphaned them.
              #
              # Gating on the match cost real attributions: a second flare
              # on one swing ("Your slim short sword glows..." after a
              # baselard swing) and every bow flare whose swing line names
              # the ARROW ("ghezyte long bow" vs "firewheel arrow") were
              # held as pre-flares and emitted as standalone events - 229
              # cases in a 60-file replay. Both belong to the open attack.
              #
              # The reject clause still matters: when two weapons' flares
              # fire back to back with no attack line between them, the
              # weapon name is the ONLY thing telling them apart.
              if current_event && !flare_contradicts_weapon?(flare, current_event)
                current_event[:flares] << flare
              else
                pending_flares << flare
              end

              # Only damaging flares own subsequent damage lines; a buff flare
              # (breeze, tailwind) claiming the cursor would steal the parent
              # swing's damage.
              flare_ctx = flare[:damaging] ? flare : nil
              spawn_pending = flare if flare[:spawns]
              # An echo flare (mirror image, hunter's afterimage) is the spawn
              # point of the bare 2p swing that follows it in this blob; queue
              # it so that swing can be parented to it (see echo lineage).
              pending_echoes << { flare: flare, owner: current_event } if ECHO_FLARES.include?(flare[:name])
              respond "[Combat] Found flare: #{flare[:name]}" if Tracker.debug?(:verbose)
            end

            # Spawn-class flares (Blink) fire an imbedded spell whose cast
            # unfolds as a bracketed sequence. Events inside the bracket are
            # children of the flare, not independent casts.
            if spawn_pending && (seq = Parser.parse_sequence_start(line))
              active_spawn = { flare: spawn_pending[:name], sequence: seq, weapon: spawn_pending[:weapon] }
              spawn_pending = nil
              respond "[Combat] Spawn sequence started: #{seq} from #{active_spawn[:flare]}" if Tracker.debug?(:verbose)
            elsif active_spawn && Parser.parse_sequence_end(line) == active_spawn[:sequence]
              respond "[Combat] Spawn sequence ended: #{active_spawn[:sequence]}" if Tracker.debug?(:verbose)
              active_spawn = nil
            end

            # Assault brackets (single-target multi-round attacks: flurry,
            # barrage, pummel, guardant thrusts, thrash). The opener names
            # the ONLY target the whole assault can strike; the rounds in
            # between usually don't. MODULE state, not a local - the middle
            # rounds arrive in later chunks. The end line also prints when
            # the target dies mid-assault, so death needs no special case.
            if (assault = Parser.parse_assault_start(line))
              @active_assault = { name: assault[:name], target: line_target }
              respond "[Combat] Assault started: #{assault[:name]} on #{line_target ? line_target[:name] : '(unknown)'}" if Tracker.debug?(:verbose)
            elsif @active_assault && Parser.parse_assault_end(line) == @active_assault[:name]
              respond "[Combat] Assault ended: #{@active_assault[:name]}" if Tracker.debug?(:verbose)
              @active_assault = nil
            end

            # Handle target switching (for multi-target attacks like volley).
            # An INBOUND event is aimed at us and has no creature target by
            # construction. It must never adopt one: any creature link later
            # in the chunk (an emote, a room echo) would fill its empty
            # target slot through the nil-branch below and carry the damage
            # the creature dealt US onto that creature (real-feed replay,
            # GSIV-Bodegap 2025-09-17: an ogre's killing 28 damage landed on
            # the ogre via its own "laughs hysterically" emote).
            # A foreign-target event (the def named a player or an
            # unresolvable name) is bound to a non-creature for the same
            # reason and must not adopt one either.
            # A flare announce that names ITS OWN target (a spectral bloom on
            # a creature the glowbark chain reached) is not a target switch:
            # the damage line that follows belongs to that flare, creature-
            # attributed, not to a phantom copy of the swing opened on the
            # bloom's creature (real-feed 2026-09-07: every bloom recorded as
            # a `fire` echo attack with a PLASMA crit while the flare row sat
            # empty). Likewise a non-attack line naming a creature one of this
            # event's flares already touched ("You blinded <bloom target>!")
            # stays with this event.
            flare_owned_target = line_target && current_event &&
                                 ((flare && flare[:target_info]) ||
                                  (!line_attack && (current_event[:flares] || []).any? do |f|
                                    f[:target_info] && f[:target_info][:id] == line_target[:id]
                                  end))
            if line_target && !line_redirect && parse_state != :seeking_attack && !flare_owned_target &&
               !(current_event && (current_event[:inbound] || current_event[:foreign_target] ||
                                   current_event[:foreign_caster]))
              # Check if this is a real target switch (different creature)
              if current_target && current_target[:id] != line_target[:id]
                # Save previous event if it has data
                if event_savable?(current_event, include_attack_events: include_attack_events)
                  events << current_event
                  respond "[Combat] Saved event for #{current_event[:target][:name]}: #{current_event[:hits].size} hits, #{current_event[:statuses].size} statuses" if Tracker.debug?(:verbose)
                end

                # Create new event for this target (inherit attack name and
                # lineage from previous - a target switch mid-AoE stays inside
                # the same spawned sequence)
                current_event = {
                  source: current_event ? current_event[:source] : source,
                  name: current_event ? current_event[:name] : :unknown,
                  target: line_target,
                  weapon: current_event && current_event[:weapon],
                  parent: current_event && current_event[:parent],
                  # Same attack, another AoE target: it sits at the SAME point
                  # in the spawn tree as the event it split from, so it carries
                  # the same lineage. root_ref resolves to a real event below.
                  root_ref: current_event && current_event[:root_ref],
                  parent_ref: current_event && current_event[:parent_ref],
                  parent_confidence: current_event && current_event[:parent_confidence],
                  hits: [],

                  statuses: [],
                  flares: [],
                  outcomes: [],
                  resolutions: [],
                  # A line can be BOTH a target switch and a new attack (an
                  # AoE's per-target line). The switch fires first, creating
                  # this inherited event; if the attack branch then replaces
                  # it on the SAME line, it is an artifact, not a miss - mark
                  # the birth line so the attack branch can tell.
                  _line: index
                }
                # A held roll belongs to the target this line names, not to
                # a later attack: volley's per-arrow SMR precedes the arrow
                # line, and for a MISSED arrow the outcome line is all there
                # is - without this claim the miss's roll leaked into the
                # next arrow's event (real-feed replay, volley.txt).
                unless pending_resolutions.empty?
                  current_event[:resolutions].concat(pending_resolutions)
                  pending_resolutions = []
                end
                flare_ctx = nil
                current_target = line_target
                respond "[Combat] Switched to target: #{line_target[:name]} (#{line_target[:id]})" if Tracker.debug?(:verbose)

              elsif current_target.nil?
                # First target for current event - just set it, don't discard
                # data. But a creature can never be its own victim: on a 3p
                # initiation with no target of its own (":ambush" - "<creature>
                # leaps from hiding to attack!") the only link in the chunk is
                # the ATTACKER, and adopting it applied the damage it dealt US
                # to itself (real-feed replay, GSIV-Nisugi 2024-11-21: a triton
                # assassin's 15-damage ambush landed on the assassin).
                attacker_id = current_event[:attacker] && current_event[:attacker][:id]
                unless attacker_id && attacker_id == line_target[:id]
                  current_event[:target] = line_target
                  current_target = line_target
                end
                respond "[Combat] Found target: #{line_target[:name]} (#{line_target[:id]})" if Tracker.debug?(:verbose)
              end
              # If current_target[:id] == line_target[:id], do nothing (same target)
            end

            # Outcomes (why nothing landed) and resolutions (the roll lines)
            # attach to whatever the cursor points at - an active flare owns
            # its own SMR line, the swing owns its AS/DS line. Arrays because
            # multi-strike attacks (flurry) roll several times per target.
            # Runs AFTER target switching: an outcome line names its target
            # ("the warg evades!"), so the switch must happen first or the
            # outcome lands on the previous target's event.
            # Only parsed when a recorder-class subscriber wants the blob.
            if include_attack_events
              if (resolution = Parser.parse_resolution(line))
                # Most rolls FOLLOW their attack line (swing -> AS/DS), but
                # volley's SMR PRECEDES each arrow line. A roll claims the
                # current sink only while that sink has no damage yet;
                # otherwise it is held for the next attack event, which
                # claims it on creation. Damage alone is the boundary -
                # "no roll yet" was part of it, but barrage pairs an aim
                # SMR (claimed at creation) WITH a per-arrow AS/DS, and the
                # stricter rule orphaned every arrow's roll (real-feed
                # replay, logs/examples/Barrage.txt).
                # A damaging flare claims a roll only while it has no damage
                # yet (mirror image: flare -> roll -> damage). One that
                # already dealt its damage is complete - an acid proc must
                # not steal the next swing's AS/DS (real-feed replay,
                # logs/examples/weapon_pulverize.txt).
                flare_ctx = nil if flare_ctx && flare_ctx[:hits].any?
                sink = flare_ctx
                # Roll routing differs by roll class (fixture-verified,
                # logs/examples/):
                #   SMR/SSR/maneuver rolls PRECEDE their per-target line
                #   (volley, barrage, pin) - one arriving on a settled event
                #   (has damage or an outcome) belongs to the NEXT target,
                #   so it is held.
                #   AS/DS-class rolls always FOLLOW their attack line - a
                #   multi-strike (flurry: one initiation, five rolls with
                #   outcomes and damage interleaved) keeps every roll on
                #   the attack-born event.
                if sink.nil? && current_event
                  maneuver_roll = %i[smr ssr maneuver_roll fear].include?(resolution[:type])
                  born = current_event[:_attack_born]
                  if maneuver_roll
                    # On an ATTACK-BORN event only damage settles it: cripple
                    # prints init -> resisted outcome -> SMR, and that roll is
                    # the maneuver's own (logs/examples/cripple.txt). On a
                    # switch-born event an outcome settles too - a volley
                    # miss's roll came BEFORE its outcome, so one arriving
                    # after belongs to the next arrow.
                    settled = current_event[:hits].any? ||
                              (!born && current_event[:outcomes].any?)
                    sink = current_event unless settled
                  elsif born || (current_event[:hits].empty? && current_event[:outcomes].empty?)
                    sink = current_event
                  end
                end
                if sink
                  sink[:resolutions] << resolution
                else
                  pending_resolutions << resolution
                end
                respond "[Combat] Found resolution: #{resolution[:type]} = #{resolution[:result]}" if Tracker.debug?(:verbose)
              elsif (outcome = Parser.parse_outcome(line))
                if flare_ctx || current_event
                  (flare_ctx || current_event)[:outcomes] << outcome
                elsif line_target && line_target[:id]
                  # An outcome with a named target and no event at all: the
                  # first arrow of a volley round can be a miss - roll +
                  # outcome, no attack line, at the top of the chunk. Open
                  # the event here (chunk-locally the maneuver name is
                  # unknowable) so the miss and its roll survive.
                  current_event = {
                    source: source,
                    name: pending_ambush ? :ambush : :unknown,
                    target: line_target, attacker: nil,
                    weapon: nil, parent: nil, hits: [],
                    statuses: [], flares: [], outcomes: [outcome],
                    # A wholly-negated ambush prints its prefix and then an
                    # intercept, with no attack line between - this is the
                    # only record that the ambush was attempted.
                    ambush: !pending_ambush.nil?,
                    resolutions: pending_resolutions
                  }
                  pending_ambush = nil
                  pending_resolutions = []
                  current_target = line_target
                  parse_state = :seeking_damage
                else
                  # No event, no named target: an outcome for an
                  # initiation we have no def for. Orphan-sink it.
                  orphan_outcomes << outcome
                end
                respond "[Combat] Found outcome: #{outcome}" if Tracker.debug?(:verbose)
              end
            end

            # Ambush prefix ("<X> leaps from hiding to strike!"). Attacking
            # from hiding is still just an attack - the prefix only marks
            # that it carries the ambush bonuses (DS pushdown + crit
            # weighting). It is NOT an attack of its own: the real attack
            # line follows and carries the target and the roll. Arm the flag
            # and move on; the next attack claims it.
            if (amb = Definitions::Attacks.ambush_prefix(line))
              pending_ambush = { attacker: amb[:attacker] }
              respond '[Combat] Ambush prefix armed' if Tracker.debug?(:verbose)
            end

            # Guardian redirect prefix (see pending_redirect decl). Like the
            # ambush prefix it is a modifier on the attack line that follows,
            # never an event or outcome of its own. The interceptor is the
            # bolded creature on the line when the feed carries links.
            if (rdr = line_redirect)
              redirect = {
                interceptor: line_target || { name: Parser.strip_links(rdr[:interceptor]) },
                intended: rdr[:intended]
              }
              # UAC shape (corpus: 21/130, all "You attempt to kick <X>!"):
              # the announce comes AFTER the attack line, no re-issued
              # attack follows, and the roll/damage still land on the
              # intended victim. The guardian announced but did not take
              # the hit. Stamp the open attack as an unhonored redirect so
              # the fact survives, and do NOT arm the pending marker - a
              # later unrelated swing in the chunk must not claim it.
              # (noun from the link; in stripped mode the open event carries
              # no target identity at all, so an open fact-less attack is
              # taken as the intended one - the only shape the corpus shows)
              open_noun = current_event && current_event[:target] &&
                          (current_event[:target][:noun] || current_event[:target][:name]&.split&.last)
              if current_event && !current_event[:redirect] && current_event[:_attack_born] &&
                 (open_noun.nil? || open_noun == rdr[:intended]) &&
                 current_event[:resolutions].empty? && current_event[:hits].empty? &&
                 current_event[:outcomes].empty?
                current_event[:redirect] = redirect.merge(honored: false)
                respond "[Combat] Redirect announced but not honored (#{rdr[:intended]})" if Tracker.debug?(:verbose)
              else
                pending_redirect = redirect.merge(honored: true)
                respond "[Combat] Redirect prefix armed: intended #{rdr[:intended]}" if Tracker.debug?(:verbose)
              end
            end

            # Attack check is needed in both states (a new attack while seeking
            # damage closes the previous event), so run it once per line. This
            # replaces the old `redo`, which re-ran the status/UCS handlers
            # above on the same line and double-applied their effects.
            attack = (amb || rdr) ? nil : line_attack

            if attack
              # A bare gesture :cast event is the WRAPPER for whatever
              # spell-specific initiation follows in the same chunk (searing
              # light's engulf, evoked tangleweed's lash): the specific def
              # supersedes it. Hand its rolls to the new event, mark the new
              # event via: :cast, and discard the wrapper instead of emitting
              # a fact-less phantom cast. Guards:
              #   - facts on the wrapper (wild entropy, moonbeam - no
              #     specific def ever fires) mean it emits normally;
              #   - an ATTACKER on the new line that differs from the
              #     wrapper's means an unrelated (creature) attack
              #     interleaved - that must not eat our cast. Spell-result
              #     lines are attackerless, so they supersede.
              #   - a cast HELD over from the previous chunk (see @held_cast)
              #     is superseded only by a spell-result line, never by a
              #     fresh 2p initiation of our own ("You fire ...") - that is
              #     the next action, not this cast's effect.
              superseded_cast = nil
              superseded_source = nil
              if bare_cast?(current_event) &&
                 (attack[:attacker].nil? ||
                  (current_event[:attacker] && attack[:attacker][:name] == current_event[:attacker][:name])) &&
                 (!current_event[:_held] || !line.match?(/\AYou\b/))
                pending_resolutions = current_event[:resolutions] + pending_resolutions
                # fact-less flares on the wrapper (a mirror echoing the
                # gesture) belong to the spell event that replaces it
                pending_flares.concat(current_event[:flares])
                superseded_cast = true
                superseded_source = current_event[:source]
                current_event = nil
              end
              # Save previous event before starting a new one - unless the
              # target-switcher created it on this very line (see _line)
              if event_savable?(current_event, include_attack_events: include_attack_events) && current_event[:_line] != index
                events << current_event
                respond "[Combat] Completed event for #{current_event[:target][:name]}: #{current_event[:hits].size} hits" if Tracker.debug?(:verbose)
              end
              # A same-line artifact event may have claimed held rolls in
              # the switch branch above (volley: the arrow's own SMR) -
              # they belong to THIS attack, so carry them across the
              # replacement instead of discarding them with the artifact.
              # The switch artifact also inherited spawn-tree lineage from the
              # sibling it split from (a multi-target AoE per-target line is the
              # same attack striking another creature - same tree node). Capture
              # it here so the fresh current_event below can carry it forward
              # instead of recomputing a fresh root and fragmenting the AoE.
              switch_artifact_lineage = nil
              if current_event && current_event[:_line] == index
                pending_resolutions = current_event[:resolutions] + pending_resolutions if current_event[:resolutions].any?
                if current_event[:root_ref]
                  switch_artifact_lineage = {
                    root_ref: current_event[:root_ref],
                    parent_ref: current_event[:parent_ref],
                    parent_confidence: current_event[:parent_confidence]
                  }
                end
              end

              # Foreign-attacker latch (see foreign_latch decl). A 2p "You..."
              # attack is ours and reclaims ownership - clear the latch. A
              # foreign_caster attack (its line names a player) arms it, so
              # the actor-less swing/effect lines that fan out from a nearby
              # player's AoE inherit their ownership. An event is foreign when
              # its own def said so, OR when the latch is armed and this line
              # named no actor of its own (an anonymous AoE per-target swing).
              our_2p = line.match?(/\AYou\b/) && attack[:attacker].nil? &&
                       !attack[:foreign_caster]
              foreign_latch = nil if our_2p
              foreign_latch = attack[:attacker][:name] if attack[:foreign_caster] && attack[:attacker]
              eff_foreign = attack[:foreign_caster] ||
                            (foreign_latch && attack[:attacker].nil? && !our_2p) || nil

              current_event = {
                source: superseded_cast ? superseded_source : source,
                name: attack[:name],
                target: attack[:target] || {},
                attacker: attack[:attacker], # nil for our own (2nd-person) attacks
                # Aimed at US. Carries no creature target, so event_savable?
                # drops it and its damage/crits are never applied to the
                # attacker - but it still closes the previous event and
                # absorbs the roll/damage lines that follow, keeping them
                # off the creature we were fighting.
                inbound: attack[:inbound],
                # The def named a target that is not a creature (a player,
                # an unresolvable name). Same rule as inbound: never adopt
                # a creature later in the chunk.
                foreign_target: attack[:foreign_target],
                # A nearby player's attack on a creature we can see. Unlike
                # foreign_target it DOES have a creature target; persist_event
                # emits it for observers but never applies it to the creature.
                # eff_foreign folds in the foreign_latch: an anonymous swing
                # inside a nearby player's AoE is theirs even though its own
                # line named nobody.
                foreign_caster: eff_foreign,
                # A DoT/effect TICK line (pestilence boils, web ensnare) that
                # named the victim but no caster, arriving with no owning cast
                # of that spell in this blob. Its damage still applies to the
                # creature (real received damage) but is NOT our deal - the
                # recorder files it under other/unknown. Ours only when our
                # own cast set cast_owner[[name, victim]] = :self this blob; a
                # foreign cast makes it foreign_caster instead. A CAST line
                # ("You exhale...") is our own initiation, never unowned - it
                # is excluded by the owning-cast check below (which set :self
                # for it) plus the 2p-line guard. Keyed by THIS tick's victim,
                # so our cast on another creature can't claim it.
                unowned: (UNOWNED_TICK_ATTACKS.include?(attack[:name]) &&
                          attack[:attacker].nil? && !eff_foreign &&
                          !line.match?(/\AYou\b/) &&
                          cast_owner[cast_owner_key.call(attack[:name], attack[:target])] != :self) || nil,
                # Struck from hiding: this attack carries the ambush
                # bonuses (DS pushdown + crit weighting). A modifier on the
                # attack, not an attack of its own.
                ambush: !pending_ambush.nil?,
                # A guardian stepped in front of the creature we struck at
                # and this attack resolved against the guardian instead:
                # { interceptor: {id?, name}, intended: <victim noun> }.
                # A modifier, not an outcome - nothing was nullified.
                redirect: pending_redirect,
                # Aimed shot ("take aim and", or UAC's "make a precise").
                # Same shape as :ambush - a modifier, not an attack. The
                # defs captured this all along and it was never surfaced.
                aimed: attack[:aimed] || false,
                weapon: Parser.parse_swing_weapon(line) || attack[:weapon],
                # the gesture line that opened this spell (see wrapper rule)
                via: superseded_cast ? :cast : nil,
                parent: active_spawn ? { flare: active_spawn[:flare], weapon: active_spawn[:weapon] } : nil,
                # Spawn-tree links (resolved to row ids by the recorder):
                #   :root_ref   - the initiating own attack of this blob's tree
                #   :parent_ref - the immediate spawner, ONLY when we can assert
                #                 it (blink's bracket); nil when ambiguous
                #   :parent_confidence - :bracket (declared by the game) for
                #                 blink; nil otherwise. Reserved for :count
                #                 (count-constraint-forced) in a later pass.
                # eff_foreign/inbound events are their own root and do not join
                # our tree; they are handled after the hash is built.
                root_ref: nil,
                parent_ref: nil,
                parent_confidence: nil,
                hits: [],

                statuses: [],
                flares: [],
                outcomes: [],
                resolutions: [],
                # Born from a real initiation line - multi-strike rolls keep
                # attaching here even after outcomes/damage (see roll routing)
                _attack_born: true
              }

              # Spawn-tree lineage (see spawn_root decl). We stamp ONLY lineage
              # we can assert, never a positional guess:
              #   - blink's bracketed cast (active_spawn) is a child DECLARED by
              #     the game: root = the open tree root, parent = that root,
              #     confidence :bracket.
              #   - a mirror/afterimage ECHO: the echo flare announces, then the
              #     spawned swing prints as a bare 2p line of the same attack
              #     ("You fire ..."). The whole tree resolves inside one blob
              #     before roundtime, so a bare own swing arriving while an echo
              #     flare of this blob is unconsumed IS that flare's swing -
              #     pair them FIFO (the count constraint: N echo flares, N echo
              #     swings). parent = the event the flare rode, confidence
              #     :count, parent flare recorded so reports can hang the echo
              #     under the flare row (owner ruling 2026-09-07: "the flare
              #     is the attack"). An echo's own echo flare parents the next
              #     swing to the echo, so mirror->afterimage chains nest.
              #   - every other own attack becomes the root of its OWN tree.
              #   - inbound/foreign/orphan events are their own root regardless.
              # A foreign/inbound/unowned/orphan event is NEVER part of our
              # spawn tree - it must not graft onto or become a linkable node in
              # it. This single flag gates every branch below (the switch-
              # artifact branch omitted it once and let a nearby player's attack
              # on another creature inherit our lineage - real-feed group play).
              not_ours = current_event[:inbound] || current_event[:foreign_target] ||
                         current_event[:foreign_caster] || current_event[:unowned] ||
                         current_event[:_orphan]
              if switch_artifact_lineage && !not_ours
                # Same-line AoE per-target line: this is the same attack
                # striking another creature, so it sits at the SAME spawn-tree
                # node as the sibling it split from. Carry that lineage forward
                # rather than recomputing (which would fragment the AoE into N
                # independent single-hit roots).
                current_event[:root_ref] = switch_artifact_lineage[:root_ref]
                current_event[:parent_ref] = switch_artifact_lineage[:parent_ref]
                current_event[:parent_confidence] = switch_artifact_lineage[:parent_confidence]
              elsif active_spawn && spawn_root && !not_ours
                current_event[:root_ref] = spawn_root
                current_event[:parent_ref] = spawn_root
                current_event[:parent_confidence] = :bracket
              elsif !not_ours && spawn_root && !pending_echoes.empty? && line.match?(/\AYou\b/) &&
                    current_event[:name] == (pending_echoes.first[:owner] || spawn_root)[:name]
                echo = pending_echoes.shift
                owner = echo[:owner] || spawn_root
                current_event[:root_ref] = spawn_root
                current_event[:parent_ref] = owner
                current_event[:parent_confidence] = :count
                current_event[:parent] = { flare: echo[:flare][:name], weapon: echo[:flare][:weapon] }
              else
                spawn_root = current_event unless not_ours
                current_event[:root_ref] = current_event
              end

              # Record ownership of a DoT/effect spell from its CAST line so
              # the ticks that follow (this blob or later) can be claimed.
              # Our 2p cast ("You exhale a virulent green mist...") makes the
              # spell ours; a 3p cast names the foreign caster. Cast lines
              # carry no inline damage, so a same-name event WITH damage is a
              # tick, not a cast - only the cast sets ownership.
              if UNOWNED_TICK_ATTACKS.include?(current_event[:name]) && current_event[:hits].empty?
                owner =
                  if current_event[:foreign_caster] then (current_event[:attacker] && current_event[:attacker][:name]) || :foreign
                  elsif current_event[:attacker].nil? && line.match?(/\AYou\b/) then :self
                  end
                # Bind ownership to the creature this cast targeted, not the
                # spell globally (see cast_owner decl).
                cast_owner[cast_owner_key.call(current_event[:name], current_event[:target])] = owner
              end

              # Claimed - the ambush/redirect belong to this attack only.
              pending_ambush = nil
              pending_redirect = nil
              current_target = current_event[:target][:id] ? current_event[:target] : nil

              # Assault binding: while an assault is open, its own targetless
              # rounds (barrage's re-nock, flurry's direction-reverse) strike
              # the assault target by definition. :ambush is neutral - the
              # restealth re-emerge line rides inside shadow-mastery assaults
              # (see weapon_pulverize.txt) and binds the same way. Any OTHER
              # outbound attack def is impossible during an assault, so it
              # means our bracket state is stale (missed end line, script
              # restart) - drop the context rather than misattribute.
              if @active_assault && !current_event[:inbound] && !current_event[:foreign_target]
                if current_event[:name] == @active_assault[:name] || current_event[:name] == :ambush
                  if current_target.nil? && @active_assault[:target] && @active_assault[:target][:id]
                    current_event[:target] = @active_assault[:target]
                    current_target = @active_assault[:target]
                    respond "[Combat] Assault bound target: #{current_target[:name]}" if Tracker.debug?(:verbose)
                  elsif current_target && @active_assault[:target].nil?
                    # barrage's opener names no target - the first named
                    # round inside the bracket backfills it
                    @active_assault[:target] = current_target
                  end
                elsif current_event[:attacker].nil? &&
                      !%i[unknown companion].include?(current_event[:name])
                  # Only OUR OWN attacks are impossible mid-assault. A third
                  # party's are normal and must not disturb the bracket:
                  # :companion defs capture (?<companion>) not (?<attacker>)
                  # so they parse attackerless, hence the explicit exemption;
                  # creature-vs-groupmate defs carry :attacker and fall out
                  # on the nil check. Those events keep their own captured
                  # targets and attribute normally either way - this guard
                  # only decides whether the assault context survives them.
                  respond "[Combat] Assault context dropped (unexpected attack: #{current_event[:name]})" if Tracker.debug?(:verbose)
                  @active_assault = nil
                end
              end

              # Some initiation lines carry their damage INLINE rather than on
              # a following "... N points of damage!" line - the damage-over-
              # time ticks ("Pustules break out all over X causing 44 points
              # of damage!") are the whole event, message and damage in one.
              # The attack branch returns before the damage branch runs, so
              # without this the tick's damage was dropped entirely while an
              # unrelated swing later in the same chunk persisted normally
              # (real-feed replay: 59 and 44 lost against a gigas berserker).
              # No track_damage gate: the main damage branch has none, and
              # gating only here made inline-damage events vanish under
              # configs that omit the key (replay 2026-09-05, pestilence)
              if (inline = Parser.parse_damage(line))
                current_event[:hits] << { damage: inline, crit: nil }
                respond "[Combat] Found inline damage: #{inline}" if Tracker.debug?(:verbose)
              end

              # A new swing claims any held pre-flares whose weapon matches it
              # (they resolved before this swing but belong to it). An inbound
              # attack claims neither pre-flares nor held rolls: both were
              # produced by OUR weapon and still belong to our next swing.
              unless current_event[:inbound]
                unless pending_flares.empty?
                  claimed, pending_flares = pending_flares.partition { |f| flare_matches_weapon?(f, current_event[:weapon]) }
                  current_event[:flares].concat(claimed)
                end
                unless pending_resolutions.empty?
                  current_event[:resolutions].concat(pending_resolutions)
                  pending_resolutions = []
                end
              end
              flare_ctx = nil

              respond "[Combat] Found attack: #{attack[:name]}" if Tracker.debug?(:verbose)
              parse_state = :seeking_damage
            elsif flare_ctx || parse_state == :seeking_damage
              # Accumulate damage lines. An active flare cursor owns them
              # (its damage arrives after its announce line, before the next
              # swing); otherwise they belong to the current attack. flare_ctx
              # alone also routes pre-flare damage arriving before any swing.
              #
              # A coup de grace prints no damage line: its success line is the
              # killing blow. Record it as a zero-damage FATAL hit so the kill
              # is credited and shown like a fatal crit (owner ruling
              # 2026-09-07); the room-feed death that follows agrees.
              if current_event && current_event[:name] == :coup_de_grace &&
                 (coup_loc = Definitions::Attacks.coup_kill_location(line))
                current_event[:hits] << { damage: 0, crit: { location: coup_loc, type: 'coup_de_grace', rank: nil,
                                                             wound_rank: nil, fatal: true } }
                respond '[Combat] Coup de grace kill' if Tracker.debug?(:verbose)
              elsif (damage = Parser.parse_damage(line))
                sink = flare_ctx || current_event
                # ONE record per landed hit, damage bound to the crit it
                # produced. Parallel :damages/:crits arrays could not express
                # the pairing: their counts differ on 28.7% of events and
                # 48.5% of flares (examples corpus), and a consumer had no way
                # to tell which crit came from which damage. The binding only
                # exists here, where both are in scope.
                #
                # crit stays nil when the lookahead finds none - which IS the
                # concussion marker. Holy fire prints "ravaged for 65" then
                # "... 5 points of damage!"; the 65 is concussion and takes no
                # crit (the lookahead breaks on the next damage line), the 5
                # carries the fire crit.
                hit = { damage: damage, crit: nil }
                sink[:hits] << hit
                respond "[Combat] Found damage: #{damage}#{flare_ctx ? " (flare: #{flare_ctx[:name]})" : ''}" if Tracker.debug?(:verbose)

                # When we find damage, look ahead 2-3 lines for related crit.
                # This populates hit[:crit], consumed by wound application
                # (apply_crit), status derivation (apply_crit_statuses) AND the
                # emitted :attack payload itself (a recorder reads the crit
                # location/rank/fatal straight off the hit). So it must run
                # whenever ANY of those is enabled. Gating it on track_wounds
                # alone starved status tracking; gating it on wounds||statuses
                # alone starved an emit_attacks-only recorder (combat_stats
                # enables only emit_attacks) of every crit - the emit carried a
                # crit-shaped hole.
                if Tracker.settings[:track_wounds] || Tracker.settings[:track_statuses] ||
                   include_attack_events
                  (1..3).each do |offset|
                    next_line_index = index + offset
                    break if next_line_index >= lines.size

                    next_line = lines[next_line_index]

                    # Stop looking if we hit another damage line (belongs to next damage)
                    if Parser.parse_damage(next_line)
                      respond "[Combat] Stopped crit search - found next damage line" if Tracker.debug?(:verbose)
                      break
                    end

                    # Look for crit on this line
                    if (c = CritRanks.parse(next_line.gsub(/<.+?>/, '')).values.first)
                      # Keep the whole CritRanks hash rather than copying five
                      # keys out of it: it is already allocated, and the rest
                      # (stunned, roundtime, amputated, position, silenced,
                      # slowed, dazed, secondary_wound, ...) is state we would
                      # otherwise have to infer from messaging - or, for the
                      # UCS-only fields, could not obtain at all.
                      #
                      # :regex is dropped - it is a compiled Regexp that only
                      # documents which table row matched, and it makes the
                      # payload unserialisable for any recorder downstream.
                      hit[:crit] = c.reject { |k, _| k == :regex }
                      respond "[Combat] Found critical hit: #{c[:location]} rank #{c[:wound_rank]}" if Tracker.debug?(:verbose)
                      break # Only take first crit found after this damage
                    end
                  end
                end
              end
            elsif (orphan_dmg = Parser.parse_damage(line))
              # Damage while seeking an attack: its initiation had no def
              # (or lived in a prior chunk we cannot see). Orphan-sink it
              # rather than dropping the fact.
              orphan_hits << { damage: orphan_dmg, crit: nil }
              respond "[Combat] Orphan damage: #{orphan_dmg}" if Tracker.debug?(:verbose)
            end

            # The line's status belongs to whichever event now holds that
            # target (the switch above may have just created it) - flag it
            # so event_savable? counts the status as a fact.
            if line_status_id && current_event && current_event[:target][:id] == line_status_id
              current_event[:_had_status] = true
            end
          end

          # Don't forget the last event - unless it is a bare gesture whose
          # spell result has not arrived yet. Live chunks split at the prompt,
          # and "You gesture at X." / "Cast Roundtime 1 Second." end right
          # there, so the wrapper closed and emitted as a fact-less `cast`
          # attack before the briar's lash arrived in the next chunk (real-
          # feed 2026-09-07: 15 phantom casts per hunt, every tangleweed
          # recorded without its via: :cast). Hold it for ONE chunk; the next
          # parse re-opens it (see the top of this method) and either
          # supersedes it or emits it as it stands.
          if bare_cast?(current_event) && !current_event[:_held] && current_event[:attacker].nil?
            @held_cast = current_event
          elsif event_savable?(current_event, include_attack_events: include_attack_events)
            events << current_event
          end

          # Orphaned rolls: no attack ever claimed them (trailing rider
          # maneuvers - the pilfer pat-down roll, a topple - or a bespoke
          # initiation we have no def for). Measured at 21% of exchanges
          # lost before this existed (replay harness, 2026-08-21). Wrap
          # them as a synthetic :unknown event bound to the creature being
          # fought, so the roll survives to subscribers - the first slice
          # of the orphan-resolution fallback.
          unless pending_resolutions.empty?
            anchor = current_target || (events.last && events.last[:target])
            if anchor && anchor[:id]
              events << {
                source: source,
                name: :unknown, target: anchor, attacker: nil, weapon: nil,
                parent: nil, hits: [], statuses: [],
                flares: [], outcomes: [], resolutions: pending_resolutions
              }
              pending_resolutions = []
            end
          end

          # Orphan sink: facts whose initiation had no def. Targetless
          # (persist_event never applies it - damage the state machine
          # could not attribute must not land on a guessed creature);
          # exists for recorders, same rationale as inbound events.
          if !orphan_hits.empty? || !orphan_outcomes.empty? || !pending_resolutions.empty?
            events << {
              source: source,
              name: :unknown, target: {}, attacker: nil, weapon: nil,
              parent: nil, hits: orphan_hits, statuses: [],
              flares: [], outcomes: orphan_outcomes,
              resolutions: pending_resolutions, _orphan: true
            }
          end

          # Pre-flares no swing claimed (e.g. the chunk ended first). Ones
          # that resolved damage against a known target still count - wrap
          # each as its own event so the damage is applied, not dropped.
          pending_flares.each do |f|
            next unless f[:target_info] && !f[:hits].empty?

            # Data stays on the flare (persist_event applies flare damage
            # separately); duplicating it into the event arrays would
            # double-apply it.
            events << {
              source: source,
              name: f[:name], target: f[:target_info], weapon: f[:weapon] && f[:weapon][:name],
              parent: nil, hits: [], statuses: [], flares: [f],
              outcomes: [], resolutions: []
            }
          end

          events
        end

        # Apply combat event to creature instance (same as before)
        def persist_event(event, include_attack_events: attack_events_requested?)
          target = event[:target]

          # The whole parsed event as one emit: swing + flares + spawned-cast
          # lineage, already correlated. Recorder-class subscribers get the
          # ledger without reassembling per-fact emits. Emitted FIRST:
          #   - before the target-id guard, because inbound/foreign/orphan
          #     events exist for :attack subscribers only (event_savable?
          #     saves them for exactly this emit; the guard below still
          #     keeps them off any creature),
          #   - before the track_* gates strip anything, so the payload is
          #     complete regardless of settings - and therefore BEFORE the
          #     creature is mutated (an :attack subscriber reading
          #     Creature[id] sees pre-swing state; per-fact emits see post).
          Observers.emit(:attack, event) if include_attack_events

          # A nearby player's attack (foreign_caster) DOES resolve onto a
          # creature we can see, so unlike inbound/foreign_target it passes
          # the target-id guard - but its damage, wounds and statuses belong
          # to that player, not to us. Emit it for observers (done above),
          # then stop before touching the creature registry: applying it
          # would credit their kill/damage to us and mutate a creature we
          # did not act on (real-feed, GSIV-Nisugi 2026-09-06: Heavenscent's
          # infused Web on a gigas shield-maiden).
          return if event[:foreign_caster]

          # The swing's own creature (nil for an inbound/self/orphan attack
          # that carries no creature target). Its DIRECT hits/wounds/statuses
          # apply only when it exists - but the event may still carry FLARES
          # that strike a creature (a reactive shield spike on an INBOUND
          # attack hits the attacker). Those flares resolve their own creature
          # below, so we must NOT bail here just because the swing was
          # targetless - that dropped reactive-flare damage, wounds and
          # statuses entirely (they returned before the flare loop).
          creature = target[:id] ? Creature[target[:id].to_i] : nil
          if target[:id] && !creature
            respond "[Combat] No creature found for ID #{target[:id]}" if Tracker.debug?(:verbose)
          end
          # Nothing to apply at all: no swing creature AND no flare could name
          # one. (A targetless event with flares still falls through.)
          return if creature.nil? && (event[:flares] || []).all? { |f| f[:hits].empty? }

          respond "[Combat] Applying to #{creature.name} (#{target[:id]})" if creature && Tracker.debug?(:verbose)

          # Summary mode records what this event actually changed, per
          # creature - a flare can land on a different creature than the
          # swing, so damage/wounds/statuses are keyed by id rather than
          # summed together. nil when off, which is what makes the collector
          # calls in apply_crit/apply_secondary_wound/apply_crit_statuses
          # free in the normal path.
          @delta = Tracker.debug?(:summary) ? Hash.new { |h, k| h[k] = { creature: nil, damage: 0, wounds: [], statuses: [] } } : nil

          # Apply direct damage.
          #
          # Damage for EVERY hit lands before any crit is applied - the two
          # passes are deliberate, not an artifact of the old parallel
          # arrays. Interleaving them would reorder the observer emits a
          # subscriber sees.
          total_damage = 0
          # Direct-hit application needs the swing's creature; skipped for a
          # targetless (inbound/self) parent, whose only creature-bound facts
          # are its reactive flares, handled in the flare loop below.
          if creature && Tracker.settings[:track_damage]
            event[:hits].each do |hit|
              damage = hit[:damage]
              creature.add_damage(damage)
              total_damage += damage
              Observers.emit(:damage, id: creature.id, name: creature.name,
                                      attack: event[:name], amount: damage)
              record_delta(creature) { |d| d[:damage] += damage }
              respond "  +#{damage} damage" if Tracker.debug?(:verbose)
            end
          end

          # Apply critical wounds
          if creature && Tracker.settings[:track_wounds]
            event[:hits].each { |hit| apply_crit(creature, hit[:crit], event) if hit[:crit] }
          end

          # Flare damage/crits apply to the flare's own target when its
          # announce line named one (AoE flares can hit a different creature
          # than the swing), falling back to the swing's target.
          (event[:flares] || []).each do |flare|
            next if flare[:hits].empty?

            f_target = flare[:target_info] || target
            f_creature = f_target[:id] ? Creature[f_target[:id].to_i] : creature
            next unless f_creature

            if Tracker.settings[:track_damage]
              flare[:hits].each do |hit|
                damage = hit[:damage]
                f_creature.add_damage(damage)
                total_damage += damage
                Observers.emit(:damage, id: f_creature.id, name: f_creature.name,
                                        attack: event[:name], flare: flare[:name], amount: damage)
                record_delta(f_creature) { |d| d[:damage] += damage }
                respond "  +#{damage} damage (flare: #{flare[:name]})" if Tracker.debug?(:verbose)
              end
            end

            if Tracker.settings[:track_wounds]
              flare[:hits].each { |hit| apply_crit(f_creature, hit[:crit], event, flare: flare[:name]) if hit[:crit] }
            end
          end

          # Status effects: crit-table-derived and message-derived, under
          # one gate so they can never drift onto different flags. Passing a
          # nil swing creature is fine - apply_crit_statuses skips the direct
          # hits and still applies each flare's crit statuses to its own
          # creature (a reactive flare on an inbound attack). Message-derived
          # statuses on event[:statuses] belong to the swing target, so they
          # only apply when that creature exists.
          if Tracker.settings[:track_statuses]
            apply_crit_statuses(creature, event)
            if creature
              event[:statuses].each do |status|
                creature.add_status(status)
                Observers.emit(:status, id: creature.id, name: creature.name,
                                        status: status, action: :add)
                record_delta(creature) { |d| d[:statuses] << status }
                respond "  +status: #{status}" if Tracker.debug?(:verbose)
              end
            end
          end

          respond "  Total damage applied: #{total_damage}" if total_damage > 0 && Tracker.debug?(:verbose)
          emit_debug_summary(event)

          # Death detection (2026-09-07). Crit tables flag a FATAL crit, but a
          # creature that dies of hit-point loss, or to a coup de grace (no
          # damage line at all), printed only its creature-specific death
          # message - and nothing here emitted a death, so every such kill
          # stayed "alive" for recorders (real-feed: 9 mastodon deaths in a
          # hunt, 3 recorded). The universal signal is the room feed's
          # <crtrStatus dead="1"/>, already parsed onto the creature as
          # crtr_flag?(:dead). Watch every creature this event touched; the
          # sweep that emits ONE `dead` status when the flag turns on runs in
          # process() after the whole chunk's attacks have emitted.
          watch_for_death(target[:id])
          (event[:flares] || []).each { |f| watch_for_death(f.dig(:target_info, :id)) }
        end

        # -- death watch ---------------------------------------------------

        # How many sweeps a touched creature stays watched without dying.
        # Two chunks covers the room-refresh lag seen in real feeds; anything
        # longer is a creature that simply survived.
        DEATH_WATCH_SWEEPS = 3

        def watch_for_death(id)
          return unless id

          @death_watch ||= {}
          @death_watch[id.to_i] = DEATH_WATCH_SWEEPS
        end

        # Emits :status dead (add) for any watched creature whose registry
        # entry now reports the dead classification flag, once per creature.
        def sweep_death_watch
          return if @death_watch.nil? || @death_watch.empty?
          return unless defined?(Creature)

          @death_announced ||= {}
          @death_watch.keys.each do |id|
            creature = Creature[id]
            if creature.nil?
              @death_watch.delete(id) # left the registry - nothing to confirm
              next
            end
            if creature_dead?(creature)
              @death_watch.delete(id)
              next if @death_announced.key?(id)

              @death_announced[id] = true
              @death_announced.shift if @death_announced.size > 1_000 # bound the memory
              Observers.emit(:status, id: creature.id, name: creature.name,
                                      status: 'dead', action: :add)
              respond "[Combat] #{creature.name} (#{id}) confirmed dead" if Tracker.debug?(:verbose)
            elsif (@death_watch[id] -= 1) <= 0
              @death_watch.delete(id)
            end
          end
        end

        def creature_dead?(creature)
          (creature.respond_to?(:crtr_flag?) && creature.crtr_flag?(:dead)) ||
            (creature.respond_to?(:has_status?) && creature.has_status?('dead'))
        rescue StandardError
          false
        end

        # Records one change against a creature for :summary output.
        #
        # No-op unless summary debug is on - `@delta` is nil in the normal
        # path, so this costs a nil check per applied fact.
        def record_delta(creature)
          return unless @delta

          entry = @delta[creature.id]
          entry[:creature] ||= creature
          yield entry
        end

        # One line per creature this event touched: what changed, nothing else.
        #
        # Deliberately the delta rather than the creature's running totals -
        # the point is to diff a single attack against the game text that
        # produced it. Cumulative state is a click away via the creature link.
        def emit_debug_summary(event)
          return unless @delta && !@delta.empty?

          @delta.each_value do |d|
            creature = d[:creature] or next

            parts = ["#{d[:damage]} dmg"]
            parts << "wounds: #{d[:wounds].join(', ')}" unless d[:wounds].empty?
            parts << "statuses: #{d[:statuses].uniq.join(', ')}" unless d[:statuses].empty?

            link = Lich::Messaging.make_cmd_link("#{creature.name} (#{creature.id})",
                                                 ";e echo Creature[#{creature.id}]")
            _respond "[Combat] #{link} | #{event[:name]} | #{parts.join(' | ')}"
          end
        ensure
          @delta = nil
        end

        # Applies one parsed crit to a creature: primary wound, secondary
        # wound, amputation, fatal. Shared by swing crits and flare crits
        # (flares crit through the same tables their damage type uses).
        def apply_crit(creature, crit, event, flare: nil)
          if crit[:wound_rank] && crit[:wound_rank] > 0
            # Map CritRanks location to creature body part format
            body_part = map_critranks_to_body_part(crit[:location])
            if body_part
              creature.add_injury(body_part, crit[:wound_rank])
              Observers.emit(:wound, id: creature.id, name: creature.name,
                                     attack: event[:name], flare: flare, location: crit[:location],
                                     body_part: body_part, rank: crit[:wound_rank])
              record_delta(creature) { |d| d[:wounds] << "#{body_part}:#{crit[:wound_rank]}" }
              respond "  +wound: #{body_part} rank #{crit[:wound_rank]}" if Tracker.debug?(:verbose)
            else
              # Surfaced in summary too: a crit that parsed but could not be
              # mapped is exactly the drift worth spotting against game text.
              record_delta(creature) { |d| d[:wounds] << "?#{crit[:location]}:#{crit[:wound_rank]}" }
              respond "  !unknown body part: #{crit[:location]}" if Tracker.debug?(:verbose)
            end
          end

          # A crit can wound a second location (e.g. a strike that carries
          # through); previously only the primary was registered.
          if (secondary = crit[:secondary_wound])
            apply_secondary_wound(creature, secondary, event)
          end

          # Amputation is a distinct terminal state, not accumulated rank.
          if crit[:amputated] && (part = map_critranks_to_body_part(crit[:location]))
            creature.amputate!(part)
            Observers.emit(:amputation, id: creature.id, name: creature.name,
                                        attack: event[:name], flare: flare, location: crit[:location],
                                        body_part: part)
            record_delta(creature) { |d| d[:wounds] << "#{part}:AMPUTATED" }
            respond "  +AMPUTATED: #{part}" if Tracker.debug?(:verbose)
          end

          # Check for fatal critical hit
          if crit[:fatal]
            creature.mark_fatal_crit!
            Observers.emit(:fatal_crit, id: creature.id, name: creature.name,
                                        attack: event[:name], flare: flare, location: crit[:location])
            record_delta(creature) { |d| d[:statuses] << 'FATAL' }
            respond "  +FATAL CRIT: #{crit[:location]} - creature died from crit, not HP loss" if Tracker.debug?(:verbose)
          end
        end

        # Registers a crit's secondary wound, when it has one.
        #
        # Crits that injure two body parts at once carry the second as
        # { :location => ..., :wound_rank => ... } - e.g. "Massive electrical
        # bolt burns a hole through the back and kidneys" wounds `back`
        # (primary) and `nerves` (secondary). Populated on 156 of ~2400 table
        # rows and nil on the rest; observed locations are head, nerves, back,
        # abdomen, neck, chest, right leg and "both eyes".
        def apply_secondary_wound(creature, secondary, event)
          # bare (non-Hash) value with no location is ambiguous - skip
          # rather than guess
          return unless secondary.is_a?(Hash)

          location = secondary[:location] || secondary['location']
          # The tables key this :wound_rank ({ :location => "head",
          # :wound_rank => 3 }); reading :rank made every secondary wound
          # a silent no-op. :rank kept as a fallback for older data.
          rank = (secondary[:wound_rank] || secondary['wound_rank'] ||
                  secondary[:rank] || secondary['rank']).to_i
          return unless rank > 0

          # "both eyes" is a real table location with no single body part -
          # it is two wounds, one per eye.
          parts = if location.to_s.downcase.gsub(/[^a-z]/, '') == 'botheyes'
                    %w[leftEye rightEye]
                  else
                    [map_critranks_to_body_part(location)].compact
                  end
          if parts.empty?
            record_delta(creature) { |d| d[:wounds] << "?#{location}:#{rank}" }
            respond "  !unknown secondary wound location: #{location}" if Tracker.debug?(:verbose)
            return
          end

          parts.each do |part|
            creature.add_injury(part, rank)
            Observers.emit(:wound, id: creature.id, name: creature.name,
                                   attack: event[:name], location: location,
                                   body_part: part, rank: rank, secondary: true)
            record_delta(creature) { |d| d[:wounds] << "#{part}:#{rank}*" }
            respond "  +secondary wound: #{part} rank #{rank}" if Tracker.debug?(:verbose)
          end
        end

        # Applies the status effects a critical hit carries.
        #
        # Deliberately not gated behind :track_ucs. The crit *tables* only
        # populate roundtime/slowed/silenced/dazed for UCS attacks, but the
        # underlying states are general - silence from Silence (210) or a
        # silencing flare, slow from Slow (506), daze from various maneuvers.
        # Gating the state on the UCS flag would mean a non-UCS character sees
        # `silenced?` return false for a genuinely silenced creature, which is
        # worse than having no answer at all.
        #
        # Units differ inside one CritRanks hash: `stunned` is in ROUNDS,
        # `roundtime` is already in SECONDS.
        def apply_crit_statuses(creature, event)
          at = event[:at] || Time.now

          # Direct-hit crits land on the swing's creature (nil for a targetless
          # inbound/self parent - its only creature-bound facts are its flares).
          if creature
            event[:hits].each do |hit|
              crit = hit[:crit] or next

              apply_hit_crit_statuses(creature, crit, event, at)
            end
          end

          # Flare crits land on the FLARE's creature (an AoE flare can strike a
          # different creature than the swing). Flare damage and flare wounds
          # are already applied in persist_event; their crit-derived statuses
          # (stun/roundtime/knockdown/silence/...) were being dropped - a
          # silencing or stunning flare recorded its wound but never its state.
          (event[:flares] || []).each do |flare|
            f_target = flare[:target_info] || event[:target] || {}
            f_creature = f_target[:id] ? Creature[f_target[:id].to_i] : creature
            next unless f_creature

            (flare[:hits] || []).each do |hit|
              crit = hit[:crit] or next

              apply_hit_crit_statuses(f_creature, crit, event, at, flare: flare[:name])
            end
          end
        end

        # Apply one crit's status effects (stun/roundtime/position/silence/...)
        # to a creature. Shared by direct-hit and flare-hit crits so both paths
        # stay identical; `flare` tags the observer/debug provenance.
        def apply_hit_crit_statuses(creature, crit, event, at, flare: nil)
          if crit[:stunned].to_i > 0
            # The boolean stays owned by <crtrStatus>/messaging; this records
            # the table-derived duration estimate beside it.
            creature.add_status('stunned')
            creature.add_stun_estimate(crit[:stunned], at: at)
            Observers.emit(:stun, id: creature.id, name: creature.name,
                                  attack: event[:name], flare: flare, rounds: crit[:stunned],
                                  seconds: crit[:stunned].to_i * CreatureInstance::STUN_ROUND_SECONDS)
            record_delta(creature) { |d| d[:statuses] << "stunned(#{crit[:stunned]}r)" }
          end

          # roundtime is in seconds already - do not scale it.
          if crit[:roundtime].to_i > 0
            creature.add_status('roundtime', crit[:roundtime].to_i)
            Observers.emit(:roundtime, id: creature.id, name: creature.name,
                                       attack: event[:name], flare: flare, seconds: crit[:roundtime].to_i)
            record_delta(creature) { |d| d[:statuses] << "roundtime(#{crit[:roundtime].to_i}s)" }
          end

          # Position changes carry better provenance than the messaging
          # equivalents: /It is knocked to the ground!/ has no target
          # capture, while this crit is already bound to a creature id.
          if (pos = crit[:position])
            # Tables report "PRONE"/"KNEELING"/"SITTING"; the status
            # canon (messaging, <crtrStatus>, consumers) is lowercase.
            # add_status canonicalizes too, but the observer payload
            # must match what subscribers compare against.
            status = pos.to_s.downcase
            (POSITION_STATUSES - [status]).each { |s| creature.remove_status(s) }
            creature.add_status(status)
            Observers.emit(:status, id: creature.id, name: creature.name,
                                    status: status, action: :add)
            record_delta(creature) { |d| d[:statuses] << status }
          end

          %i[silenced slowed dazed sleeping crippled limb_favored].each do |flag|
            next unless crit[flag]

            creature.add_status(flag.to_s)
            Observers.emit(:status, id: creature.id, name: creature.name,
                                    status: flag.to_s, action: :add)
            record_delta(creature) { |d| d[:statuses] << flag.to_s }
            respond "  +status: #{flag} (from crit#{flare ? ", flare: #{flare}" : ''})" if Tracker.debug?(:verbose)
          end
        end

        # Apply UCS event to a creature
        def apply_ucs_to_target(ucs_result, current_target = nil)
          target_id = ucs_result[:target_id]

          # For tierup events, use current combat target if no ID in the event
          target_id ||= current_target[:id] if current_target && ucs_result[:type] == :tierup

          return unless target_id

          creature = Creature[target_id.to_i]
          return unless creature

          case ucs_result[:type]
          when :position
            creature.set_ucs_position(ucs_result[:value])
            respond "[Combat] Set UCS position #{ucs_result[:value]} on #{creature.name} (#{creature.id})" if Tracker.debug?(:verbose)

          when :position_inbound
            # Per-swing metadata (the creature's tier against us) - no
            # creature state to update; it exists for observers/recorder.
            respond "[Combat] #{creature.name} (#{creature.id}) has #{ucs_result[:value]} positioning against us" if Tracker.debug?(:verbose)

          when :tierup
            creature.set_ucs_tierup(ucs_result[:value])
            respond "[Combat] Set UCS tierup #{ucs_result[:value]} on #{creature.name} (#{creature.id})" if Tracker.debug?(:verbose)

          when :smite_on
            creature.smite!
            respond "[Combat] Applied smite to #{creature.name} (#{creature.id})" if Tracker.debug?(:verbose)

          when :smite_off
            creature.clear_smote
            respond "[Combat] Cleared smite from #{creature.name} (#{creature.id})" if Tracker.debug?(:verbose)
          end
          emit_fact(:ucs, id: creature.id, name: creature.name,
                          kind: ucs_result[:type], value: ucs_result[:value],
                          tier: ucs_result[:tier])
        rescue => e
          respond "[Combat] Error applying UCS: #{e.message}" if Tracker.debug?(:verbose)
        end

        # Apply status effect directly to a creature (outside combat events)
        def apply_status_to_target(status, target_name_or_id, target_id = nil, action = :add)
          # Handle both name lookup and direct ID
          if target_id
            creature = Creature[target_id.to_i]
          else
            # Try to find creature by name - this is less reliable
            # but might work for some cases
            return unless defined?(Creature)
            creatures = Creature.all.select { |c| c.name&.downcase&.include?(target_name_or_id.downcase) }
            creature = creatures.first if creatures.size == 1
          end

          if creature
            if action == :remove
              # Position is one mutually-exclusive channel. The stand-up
              # messagings are shared between prone and sitting, and parse
              # returns the FIRST match (:prone, defined earlier) - so
              # removing only the reported status left 'sitting' (and
              # kneeling, which has no removal def at all) latched forever.
              # A creature that stood up is in no floor position, whichever
              # one the pattern happened to name.
              if POSITION_STATUSES.include?(status.to_s)
                POSITION_STATUSES.each { |s| creature.remove_status(s) }
              else
                creature.remove_status(status)
              end
              respond "[Combat] Removed status #{status} from #{creature.name} (#{creature.id})" if Tracker.debug?(:verbose)
            else
              # ...and adding one displaces the others: knocked prone while
              # sitting is prone, not both.
              if POSITION_STATUSES.include?(status.to_s)
                (POSITION_STATUSES - [status.to_s]).each { |s| creature.remove_status(s) }
              end
              creature.add_status(status)
              respond "[Combat] Applied status #{status} to #{creature.name} (#{creature.id})" if Tracker.debug?(:verbose)
            end
            emit_fact(:status, id: creature.id, name: creature.name,
                               status: status, action: action == :remove ? :remove : :add)
          else
            respond "[Combat] Could not find creature for status: #{status} -> #{target_name_or_id}" if Tracker.debug?(:verbose)
          end
        end

        # Map CritRanks location strings to creature body part constants
        def map_critranks_to_body_part(location)
          return nil unless location

          case location.to_s.downcase.gsub(/[^a-z]/, '')
          when 'leftarm', 'larm' then 'leftArm'
          when 'rightarm', 'rarm' then 'rightArm'
          when 'leftleg', 'lleg' then 'leftLeg'
          when 'rightleg', 'rleg' then 'rightLeg'
          when 'lefthand', 'lhand' then 'leftHand'
          when 'righthand', 'rhand' then 'rightHand'
          when 'leftfoot', 'lfoot' then 'leftFoot'
          when 'rightfoot', 'rfoot' then 'rightFoot'
          when 'lefteye', 'leye' then 'leftEye'
          when 'righteye', 'reye' then 'rightEye'
          when 'head' then 'head'
          when 'neck' then 'neck'
          when 'chest' then 'chest'
          when 'abdomen', 'abs' then 'abdomen'
          when 'back' then 'back'
          when 'nerves' then 'nerves'
          else
            # Try the location as-is in case it's already correct
            location.to_s if CreatureInstance::BODY_PARTS.include?(location.to_s)
          end
        end
      end
    end
  end
end
