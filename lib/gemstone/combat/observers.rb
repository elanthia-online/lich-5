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
#   3. Persistence: registry entries are session-only and swept
#      (cleanup_max_age) - recording/logging scripts must capture events
#      at parse time.
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
#
# @example
#   Combat::Tracker.on(:damage) { |type, data| my_queue << data }
#   handler = Combat::Tracker.on(:status, :wound) { |type, data| ... }
#   Combat::Tracker.off(handler)
#
module Lich
  module Gemstone
    module Combat
      module Observers
        @mutex = Mutex.new
        @subscribers = Hash.new { |h, k| h[k] = [] }
        @named = {}

        class << self
          # Subscribe to one or more event types (or :any for everything).
          # Returns the block; keep it to unsubscribe via .off.
          #
          # With name:, registration is idempotent (DownstreamHook.add
          # semantics): re-registering the same name replaces the previous
          # handler instead of stacking - safe for script restarts and
          # interactive ;e testing.
          def on(*types, name: nil, &block)
            raise ArgumentError, 'block required' unless block

            types = [:any] if types.empty?
            @mutex.synchronize do
              if name
                old = @named.delete(name.to_s)
                @subscribers.each_value { |list| list.delete(old) } if old
                @named[name.to_s] = block
              end
              types.each { |t| @subscribers[t.to_sym] << block }
            end
            block
          end

          # Remove a handler - pass the Proc returned by {on}, or the name
          # it was registered under.
          def off(handler_or_name)
            @mutex.synchronize do
              handler = if handler_or_name.is_a?(Proc)
                          handler_or_name
                        else
                          @named.delete(handler_or_name.to_s)
                        end
              @named.delete_if { |_, h| h == handler }
              @subscribers.each_value { |list| list.delete(handler) } if handler
            end
            nil
          end

          # Emit an event to type + :any subscribers. Subscriber errors are
          # isolated and logged, never raised to the caller (the processor).
          def emit(type, data)
            handlers = @mutex.synchronize { @subscribers[type].dup + @subscribers[:any].dup }
            handlers.each do |handler|
              begin
                handler.call(type, data)
              rescue StandardError => e
                Lich.log "error: Combat::Observers subscriber (#{type}): #{e.message}\n\t#{e.backtrace&.first}"
              end
            end
            nil
          end

          def any_for?(type)
            @mutex.synchronize { !@subscribers[type].empty? || !@subscribers[:any].empty? }
          end

          def clear!
            @mutex.synchronize do
              @subscribers.clear
              @named.clear
            end
          end
        end
      end
    end
  end
end
