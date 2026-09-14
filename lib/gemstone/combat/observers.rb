# frozen_string_literal: true

#
# Combat Observers - subscription seam for parsed combat facts.
#
# The Creature registry is the public read model for "now" (Processor
# applies every parsed fact to CreatureInstance, and consumers read
# current state from there). Observers are the feed of "what just
# happened" - the three things state reads structurally cannot provide:
#
#   1. Edges, not levels: transition notifications, transients that occur
#      between polls (stunned-then-unstunned, brief statuses).
#   2. The ledger, not the balance: persist_event aggregates (damage
#      totals, wound ranks); the per-event detail is consumed at
#      application time and only exists here.
#   3. Persistence: registry entries are session-only and swept by the
#      registry's own housekeeping (Creature.cleanup_max_age) - recording/
#      logging scripts must capture events at parse time.
#
# Contract for subscribers:
#   - Callbacks may run on AsyncProcessor worker threads. They must be
#     cheap and non-blocking, and must NEVER send game commands (fput /
#     Spell#cast / PSMS.use) - queue work for your own script thread.
#   - A raising subscriber is isolated and logged; it never breaks other
#     subscribers or the processor.
#
# Event types and payloads (all include :id, :name of the creature):
#   :damage     { id:, name:, attack:, amount: }
#   :wound      { id:, name:, attack:, location:, body_part:, rank: }
#   :fatal_crit { id:, name:, attack:, location: }
#   :status     { id:, name:, status:, action: :add | :remove }
#   :ucs        { id:, name:, kind: :position|:position_inbound|:tierup|:smite_on|:smite_off, value:, tier: }
#                 (:position_inbound = the creature's tier against US,
#                 per-swing metadata printed inside its UCS attack block.
#                 tier: 1..3 for decent/good/excellent on the two position
#                 kinds, nil otherwise - the numeric form the recorder keeps)
#   :spell_loss { id:, name:, spell:, spell_name:, cause: } - a spell
#                 wearing off the subject (creature OR player in view;
#                 player ids are negative, id is nil in plain-text logs).
#                 cause: :dispel (a dispel-family flare struck this
#                 chunk), :death (subject already known dead - stack
#                 cleanup, not meaningful expiry), or nil (natural
#                 expiry, or cause not visible in this chunk)
#   :recorded_attack { protocol:, recorder_id:, database:, file_identity:,
#                      session_id:, attack_id:, source: } - emitted by
#                 Combat::Recorder only after the complete attack transaction
#                 commits. Local observers can use the opaque IDs and trusted
#                 local database identity to read that exact row. source is
#                 validated ingestion provenance when available, otherwise nil.
#
# Message events (defs/messages.rb, delivered by Combat::Messages; every
# payload also carries :raw, the line). Scanned only while subscribed:
#   :disarm_seen  { kind: :recover|:telekinetic_recover|:recover_weapon_webbing, noun: }
#   :sanctum_transform { noun: }
#   :itchy_curse, :infected_wound, :entangled   {}
#   :hive_trap    { kind: :apparatus|:ground }
#   :ambusher     { noun: }  (nil for the shadowy figure)
#   :bolted       {}
#   :rooted / :unrooted  { id: } (the snake's), :item_limit {}
#   :bless_shrugged / :bless_expired  { id:, noun: }
#   :arrow_stuck  { id:, where: }, :aiming { where: } (nil when cleared),
#   :bond_return  { what: }
#   :haze_703 / :rebuke_1614  { id:, on: }, :swift_justice { charges: },
#   :arcane_reflex { active: }, :weapon_reaction { reaction: }
#
# Since 5.22 this is a thin facade over Lich::Common::Events: every combat
# event type is the topic "combat.<type>" on the shared board, so a script
# may equally subscribe with Events.on('combat.damage') or 'combat.*'. The
# facade keeps the (type, data) callback shape and the Symbol types. It
# also inherits Events' owner tracking: a subscription made from a script is
# removed when that script dies (previously it leaked), unless registered
# with persist: true.
#
# @example
#   Combat::Tracker.on(:damage) { |type, data| my_queue << data }
#   handler = Combat::Tracker.on(:status, :wound) { |type, data| ... }
#   Combat::Tracker.off(handler)
#
require_relative '../../common/events'

module Lich
  module Gemstone
    module Combat
      module Observers
        PREFIX = 'combat.'

        @mutex   = Mutex.new
        @handles = {} # user block => Events subscription name

        class << self
          # A block run after every subscription change to a combat topic
          # (on, off, clear!, owner death): how Combat::Messages learns which
          # families to scan. Errors are isolated the way subscriber errors are.
          def on_change(&block)
            Lich::Common::Events.on_change(prefix: PREFIX, &block)
          end

          # Subscribe to one or more event types (or :any for everything).
          # Returns the block; keep it to unsubscribe via .off.
          #
          # With name:, registration is idempotent (DownstreamHook.add
          # semantics): re-registering the same name replaces the previous
          # handler instead of stacking - safe for script restarts and
          # interactive ;e testing.
          #
          # persist: true keeps the subscription after the registering script
          # dies; the default removes it with the script.
          def on(*types, name: nil, persist: false, &block)
            raise ArgumentError, 'block required' unless block

            types  = [:any] if types.empty?
            topics = types.map { |t| topic_for(t) }
            wrapper = proc { |topic, data| block.call(type_for(topic), data) }
            handle = Lich::Common::Events.on(*topics, name: (name ? "#{PREFIX}#{name}" : nil), persist: persist, &wrapper)
            @mutex.synchronize do
              # a named re-registration replaced an older block; forget it
              @handles.delete_if { |_, h| h == handle }
              @handles[block] = handle
            end
            block
          end

          # Remove a handler - pass the Proc returned by {on}, or the name
          # it was registered under.
          def off(handler_or_name)
            handle = if handler_or_name.is_a?(Proc)
                       @mutex.synchronize { @handles.delete(handler_or_name) }
                     else
                       "#{PREFIX}#{handler_or_name}"
                     end
            return nil unless handle

            @mutex.synchronize { @handles.delete_if { |_, h| h == handle } }
            Lich::Common::Events.off(handle)
            nil
          end

          # Emit an event to type + :any subscribers. Subscriber errors are
          # isolated and logged, never raised to the caller (the processor).
          def emit(type, data)
            Lich::Common::Events.emit(topic_for(type), data)
            nil
          end

          def any_for?(type)
            Lich::Common::Events.any_for?(topic_for(type))
          end

          # Drop every combat subscription (other topic families untouched).
          def clear!
            @mutex.synchronize { @handles.clear }
            Lich::Common::Events.clear!(PREFIX)
          end

          private

          # Forget block handles whose subscription Events already dropped
          # (owner death, or an off by name), so the map cannot grow.
          def prune!
            live = Lich::Common::Events.names
            @mutex.synchronize { @handles.delete_if { |_, h| !live.include?(h) } }
          end

          def topic_for(type)
            type.to_sym == :any ? "#{PREFIX}*" : "#{PREFIX}#{type}"
          end

          def type_for(topic)
            topic.delete_prefix(PREFIX).to_sym
          end
        end

        Lich::Common::Events.on_change(prefix: PREFIX) { prune! }
      end
    end
  end
end
