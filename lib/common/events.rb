# frozen_string_literal: true

require_relative 'script_death'

module Lich
  module Common
    # Events - the shared notice board for script-to-script notifications.
    #
    # One process-wide registry of topic -> subscribers. An emitter says what
    # just happened; it does not know or care who is listening:
    #
    #   Events.emit('go2.status', Go2.status)
    #
    # A listener pins a note saying "when anyone says go2.status, run this":
    #
    #   Events.on('go2.status', name: 'eohunter') { |topic, status|
    #     @need_heal = true if status.phase == :blocked
    #   }
    #
    # Design (extracted from the former Combat::Observers and from HookRegistry,
    # the two places this was previously re-solved):
    #
    #   * Topics are dotted strings ('combat.damage', 'go2.status'). A
    #     subscription may name a topic exactly, a family with a trailing
    #     wildcard ('combat.*' matches 'combat.damage' but not 'combat'), or
    #     everything with '*'. Symbols are accepted and stringified.
    #   * Named registration is idempotent: subscribing again under the same
    #     name replaces the previous handler instead of stacking, so script
    #     restarts and interactive ;e testing are safe. An unnamed
    #     subscription gets a generated name (returned by {on}).
    #   * Every subscription records the registering script (Script.current)
    #     as its owner. When that script dies, its persist: false subscriptions
    #     (the default) are removed by the {ScriptDeath} handler, so a crashed
    #     supervisor cannot leave a ghost listener. persist: true keeps a
    #     subscription past its owner's exit (a daemon that re-registers on
    #     boot should still off itself in before_dying).
    #   * Delivery is synchronous on the emitter's thread. Handlers must be
    #     cheap and non-blocking, and must never send game commands (fput,
    #     Spell#cast, PSMS.use) - set a flag or queue work for your own script
    #     thread. A raising handler is isolated and logged; it never breaks
    #     other handlers or the emitter.
    #   * Deliberately not here: async delivery, queues, history, persistence.
    #     A consumer that wants its own thread pushes onto its own queue.
    #
    # State versus events: keep a read model (Go2.status, the Creature
    # registry) for "what is true now" and poll it. Emit events for the edges
    # that polling cannot see - transitions, transients, the moment something
    # changed. Payloads should be the read model's own object or a small Hash.
    module Events
      # One registration. +topics+ are the normalized patterns it listens to.
      Subscription = Struct.new(:name, :topics, :block, :owner_id, :owner_name, :persist, keyword_init: true)

      @mutex     = Mutex.new
      @subs      = {} # name => Subscription
      @on_change = []
      @anon_seq  = 0

      class << self
        # Subscribe to one or more topics.
        #
        # @param topics [Array<String, Symbol>] exact topics, 'family.*'
        #   wildcards, or '*' for everything; empty means everything
        # @param name [String, Symbol, nil] idempotent handle; generated when nil
        # @param persist [Boolean] keep the subscription after the registering
        #   script dies (default false: removed on owner death)
        # @yieldparam topic [String] the emitted topic
        # @yieldparam payload [Object] whatever the emitter passed
        # @return [String] the subscription name - pass it to {off}
        # @raise [ArgumentError] without a block
        def on(*topics, name: nil, persist: false, &block)
          raise ArgumentError, 'Events.on requires a block' unless block

          patterns = topics.flatten.compact.map { |t| normalize(t) }
          patterns = ['*'] if patterns.empty?
          owner    = current_script
          sub = Subscription.new(
            name: (name ? name.to_s : generated_name(owner)),
            topics: patterns.uniq.freeze,
            block: block,
            owner_id: owner&.object_id,
            owner_name: (owner&.name || 'Unknown'),
            persist: (persist ? true : false)
          )
          replaced = @mutex.synchronize do
            old = @subs[sub.name]
            @subs[sub.name] = sub
            old
          end
          # A named re-registration may move to a different topic family; the
          # family it left needs its on_change too (Combat::Messages would
          # otherwise keep its hook installed with nobody listening).
          changed(replaced ? [replaced, sub] : [sub])
          sub.name
        end

        # Remove a subscription by the name {on} returned, or by the block
        # that was registered.
        #
        # Not synchronous with in-flight delivery: {emit} snapshots its
        # handler list before calling any, so a handler removed while an emit
        # is iterating can still run once more. Handlers that must not act
        # after their owner starts shutting down should check their own state
        # rather than rely on off having taken effect.
        #
        # @param name_or_block [String, Symbol, Proc]
        # @return [Boolean] whether anything was removed
        def off(name_or_block)
          removed = @mutex.synchronize do
            if name_or_block.is_a?(Proc)
              key = @subs.find { |_, s| s.block.equal?(name_or_block) }&.first
              key ? @subs.delete(key) : nil
            else
              @subs.delete(name_or_block.to_s)
            end
          end
          changed([removed]) if removed
          !removed.nil?
        end

        # Deliver +payload+ to every subscriber whose pattern matches +topic+.
        # Synchronous, on the caller's thread; subscriber errors are logged and
        # swallowed so an emitter is never broken by a listener.
        #
        # @param topic [String, Symbol]
        # @param payload [Object]
        # @return [Integer] the number of handlers invoked
        def emit(topic, payload = nil)
          topic    = normalize(topic)
          handlers = @mutex.synchronize { @subs.values.select { |s| matches?(s, topic) } }
          handlers.each do |sub|
            begin
              sub.block.call(topic, payload)
            rescue StandardError => e
              log "error: Events subscriber #{sub.name} (#{topic}): #{e.message}\n\t#{e.backtrace&.first}"
            end
          end
          handlers.length
        end

        # Whether any subscription would receive +topic+. Emitters with an
        # expensive payload can skip building it when nobody is listening.
        #
        # @param topic [String, Symbol]
        # @return [Boolean]
        def any_for?(topic)
          topic = normalize(topic)
          @mutex.synchronize { @subs.each_value.any? { |s| matches?(s, topic) } }
        end

        # A block run after a registration change (on, off, clear!, owner
        # death). Lets a producer scan only for families somebody wants (the
        # way Combat::Messages does). Errors are isolated like handlers.
        #
        # @param prefix [String, nil] only fire when the changed subscription
        #   listens to this topic family (e.g. 'combat.') or to '*'; nil fires
        #   on every change
        # @return [Proc] the block, for {off_change}
        def on_change(prefix: nil, &block)
          return nil unless block

          entry = [prefix&.to_s, block]
          @mutex.synchronize { @on_change << entry }
          block
        end

        # @param block [Proc] the block given to {on_change}
        # @return [void]
        def off_change(block)
          @mutex.synchronize { @on_change.delete_if { |(_, b)| b.equal?(block) } }
          nil
        end

        # Subscriptions as a table: name, topics, owner script, persist flag.
        # @return [Array<Array>]
        def list
          @mutex.synchronize { @subs.values.map { |s| [s.name, s.topics.dup, s.owner_name, s.persist] } }
        end

        # Names of the current subscriptions.
        # @return [Array<String>]
        def names
          @mutex.synchronize { @subs.keys.dup }
        end

        # Remove every subscription, or only those listening to a topic family
        # when +prefix+ is given (e.g. 'combat.').
        #
        # @param prefix [String, nil]
        # @return [Integer] how many were removed
        def clear!(prefix = nil)
          removed = @mutex.synchronize do
            doomed = prefix ? @subs.values.select { |s| touches?(s, prefix.to_s) } : @subs.values.dup
            doomed.each { |s| @subs.delete(s.name) }
            doomed
          end
          changed(removed) unless removed.empty?
          removed.length
        end

        # {ScriptDeath} hook: drop the dying script's persist: false
        # subscriptions. Keyed on object_id so a same-named sibling script is
        # unaffected.
        #
        # @param owner_id [Integer] the dying script's object_id
        # @return [Integer] how many were removed
        def cleanup_on_death(owner_id)
          return 0 if owner_id.nil? # core registrations have no owner

          removed = @mutex.synchronize do
            doomed = @subs.values.select { |s| s.owner_id == owner_id && !s.persist }
            doomed.each { |s| @subs.delete(s.name) }
            doomed
          end
          changed(removed) unless removed.empty?
          removed.length
        end

        private

        def normalize(topic)
          topic.to_s.strip
        end

        # Exact match, '*' catch-all, or 'family.*' prefix match.
        def matches?(sub, topic)
          sub.topics.any? do |pat|
            if pat == '*'
              true
            elsif pat.end_with?('.*')
              topic.start_with?(pat[0..-2]) # keep the dot: 'combat.' prefix
            else
              pat == topic
            end
          end
        end

        # Whether a subscription listens to anything under +prefix+ (a topic
        # family such as 'combat.'). '*' touches every family.
        def touches?(sub, prefix)
          sub.topics.any? { |pat| pat == '*' || pat.start_with?(prefix) }
        end

        def generated_name(owner)
          seq = @mutex.synchronize { @anon_seq += 1 }
          "#{owner&.name || 'anon'}##{seq}"
        end

        def current_script
          return nil unless defined?(Script) && Script.respond_to?(:current)
          Script.current
        rescue StandardError
          nil
        end

        # @param subs [Array<Subscription>] the subscriptions that changed
        def changed(subs)
          callbacks = @mutex.synchronize { @on_change.dup }
          callbacks.each do |(prefix, cb)|
            next if prefix && subs.none? { |s| touches?(s, prefix) }
            begin
              cb.call
            rescue StandardError => e
              log "error: Events on_change: #{e.message}\n\t#{e.backtrace&.first}"
            end
          end
        end

        def log(msg)
          Lich.log(msg) if defined?(Lich) && Lich.respond_to?(:log)
        end
      end

      # Apply the per-script-death policy so the kill path does not need to
      # know about Events by name.
      ScriptDeath.on_death { |script| cleanup_on_death(script.object_id) }
    end
  end
end
