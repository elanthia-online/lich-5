# frozen_string_literal: true

module Lich
  module Genie
    # Delivery of a GLOBAL variable change: Remix FormMain.TriggerVariableChanged
    # (FormMain.cs:4725-4989 R), raised synchronously on the changing thread by Command's `#var`/
    # `#tvar`/`#svar`/`#math` (Command.cs:933, 954, 985, 1042 R), by Game.cs while it parses a row
    # ($health, $prompt, ..., Game.cs:1396-2716 R), by Game.SendText ("lastcommand"/"lastinput",
    # Game.cs:529-551 R) and by a plugin's `#var` (the SpellTimer port), all through
    # ClassCommand_EventVariableChanged (FormMain.cs:5045-5050 R, no queue, no depth guard):
    #
    #   * the compass names return at once ({BLOCKED}, FormMain.cs:4779-4795 R);
    #   * every active eval #trigger whose key CONTAINS the name fires when its key equals the
    #     name or `Eval(ParseGlobalVars(key))` is non-empty and not "0" (FormMain.cs:4936-4963 R),
    #     with no captures ({.fire_eval_triggers});
    #   * then every script in the list gets Script.TriggerVariableChanged (FormMain.cs:4964-4969
    #     R). Here each script has its own thread, so like {ParseDispatch}: the thread's dispatch
    #     OWNER (the interpreter running on it, {ParseDispatch.owner}) gets it inline at its
    #     position (Interpreter#deliver_variable_change), every other unpaused script gets it
    #     queued on its input as a {Change} stamped with its nesting depth, which its interpreter
    #     handles at its next read (Remix would take the script's lock and run it on the changing
    #     thread; a script busy in a tick holds that lock, so it sees the change after the tick
    #     too).
    #
    # Queueing is filtered and coalesced: every queued entry takes a slot in the
    # script's bounded Lich buffer (LimitedArray, 400 lines), so a name is queued only for a
    # script whose interpreter could react to it (Interpreter#wants_variable_change?: one of its
    # watching rows or registered eval keys contains the name), and the names of one
    # {.broadcast} call (one game row, one send) share ONE {Change} per script. Remix delivers
    # every name to every script, which ignores the rest, so the filter is invisible except for
    # the residual race documented on Interpreter#wants_variable_change?.
    #
    # The nested-dispatch cap (a decided divergence: Remix has no bound and crashes, flow t51):
    # every FIRING -- an eval #trigger here, an eval action in Interpreter#variable_changed -- is
    # one {DispatchDepth} level, and a condition that is checked and false is none (`action math
    # y add 1 when eval %y < 20` runs its 20 firings like Remix). Past the cap the chain stops with
    # one script error: the owner's script stops ({Interpreter#dispatch_overflow}), or
    # +on_overflow+ prints it when no script owns the thread (Lich's parser thread, the client
    # thread, the hook thread).
    #
    # Pure: the host passes the trigger registry, the trigger runner and its scripts (Lich glue:
    # GenieScript.variable_broadcast; specs: the flow harness).
    module VariableDispatch
      # TriggerVariableChanged returns before the trigger and script loops for these
      # ("Block direction triggers", FormMain.cs:4779-4795 R). Game.cs raises only "compass".
      BLOCKED = %w[compass $north $northeast $east $southeast $south $southwest $west $northwest
                   $up $down $out].freeze

      # A queued batch of variable changes: a String (Lich's script buffer and the interpreter
      # read it as one; its text is the names, space-separated) carrying each name with the
      # {DispatchDepth} it was raised at, in raise order, and whether a GAME ROW raised it
      # ({#game?}: part of a DR packet, so the reading interpreter holds its resumes until the
      # packet ends -- Interpreter "end of chunk").
      class Change < String
        # @return [Array<Array(String, Integer)>] frozen [name, dispatch_depth] pairs
        attr_reader :entries

        # @param entries [Array<Array(String, Integer)>] [name, dispatch_depth] pairs (at least one)
        # @param game [Boolean] raised by a game row
        # @return [Change]
        def self.batch(entries, game: false)
          first, *rest = entries
          new(first[0], first[1], more: rest, game: game)
        end

        # @param name [String] the variable name as Remix raises it ("$health", "lastcommand", ...)
        # @param dispatch_depth [Integer]
        # @param more [Array<Array(String, Integer)>] further [name, dispatch_depth] pairs
        # @param game [Boolean] raised by a game row (see {#game?})
        def initialize(name, dispatch_depth, more: [], game: false)
          @entries = [[name, dispatch_depth], *more].map { |n, d| [n.dup.freeze, d].freeze }.freeze
          @game = game ? true : false
          super(@entries.map(&:first).join(' '))
        end

        # @return [Boolean] whether a game row raised these changes
        def game?
          @game
        end

        # @return [Array<String>]
        def names
          entries.map(&:first)
        end
      end

      # The per-script entries of one {.broadcast} call, pushed as one {Change} each. Flushed
      # before anything that can run script code (an eval #trigger firing, the owner's inline
      # delivery), so a nested change raised there still reaches each script after the names
      # raised before it -- Remix's synchronous order.
      class Pending
        # @param game [Boolean] the broadcast is a game row's ({Change#game?})
        def initialize(game: false)
          @game = game
          @entries = {}.compare_by_identity # buffer => [[name, depth], ...]
        end

        # @param buffer [#push]
        # @param name [String]
        # @param depth [Integer]
        def add(buffer, name, depth)
          (@entries[buffer] ||= []) << [name, depth]
        end

        def flush
          return if @entries.empty?

          entries = @entries
          @entries = {}.compare_by_identity
          entries.each { |buffer, list| buffer.push(Change.batch(list, game: @game)) }
        end
      end

      module_function

      # EvalString's truth test as Script.TriggerVariableChanged and FormMain's eval-trigger loop
      # apply it (Script.cs:1386, FormMain.cs:4957 R): non-empty and not "0".
      # @param text [String]
      # @return [Boolean]
      def truthy?(text)
        !text.empty? && text != '0'
      end

      # FormMain.TriggerVariableChanged for each name, in order (see the module comment).
      # @param names [String, Array<String>] one name, or the names one game row / send raised
      # @param triggers [#eval_candidates] the global #trigger registry
      # @param runner [#fire, #eval_true?] the global trigger-action runner
      # @param recipients [Enumerable<ParseDispatch::Recipient>] the running scripts, in launch order
      # @param on_error [#call] callable(exception) for a failing eval trigger
      # @param on_overflow [#call] callable(message) for a nesting-cap overflow on a thread no script owns
      # @param queue_owner [Boolean] queue for the dispatch owner too instead of delivering
      #   inline: a change Remix raises at a LATER tick than the row in progress (the "scriptlist"
      #   change after a `#goto` walk, which this script's next row -- a waiteval -- must see)
      # @param game [Boolean] +names+ are a game row's (GameState::Row): the queued {Change}s
      #   say so ({Change#game?})
      # @return [void]
      def broadcast(names, triggers:, runner:, recipients:, on_error:, on_overflow:, queue_owner: false, game: false)
        pending = Pending.new(game: game)
        Array(names).each do |name|
          next if BLOCKED.include?(name)

          candidates = triggers.eval_candidates(name)
          unless candidates.empty?
            pending.flush
            break if fire_eval_triggers(name, candidates, runner: runner, on_error: on_error,
                                                          on_overflow: on_overflow) == :overflow
          end
          deliver(name, recipients, pending, queue_owner: queue_owner)
        end
        # Script code runs only after a flush (above, and in {.deliver}), so nothing that can
        # raise sits between an entry and this push.
        pending.flush
      end

      # FormMain's eval-trigger loop (FormMain.cs:4936-4963 R): each candidate whose condition
      # holds fires its action with no captures (TriggerAction(sAction, new ArrayList())), one
      # nesting level per firing. A failing condition or action goes to +on_error+ and the loop goes
      # on (Remix lets an Eval exception leave TriggerVariableChanged: 0 corpus, open-items.md
      # Q7); a cap overflow unwinds, and at the outermost level ends this broadcast.
      # @param candidates [Array<Array(String, String, Boolean)>] Triggers#eval_candidates(name)
      # @return [Symbol, nil] :overflow when the cap was hit at this (outermost) level
      def fire_eval_triggers(name, candidates, runner:, on_error:, on_overflow:)
        candidates.each do |key, commands, authored|
          next unless condition_holds?(runner, key, name, on_error)

          overflowed = false
          handler = overflow_handler(on_overflow)
          DispatchDepth.nest("variable change #{name}", on_overflow: lambda { |message|
            overflowed = true
            handler.call(message)
          }) { ParseDispatch.fire_trigger(runner, commands, [], on_error: on_error, authored: authored) }
          return :overflow if overflowed
        end
        nil
      end

      # @return [Boolean] the eval trigger's condition (a fault goes to +on_error+: false)
      def condition_holds?(runner, key, name, on_error)
        runner.eval_true?(key, name)
      rescue DispatchDepth::Exceeded
        raise
      rescue StandardError => e
        on_error.call(e)
        false
      end

      # The script loop (FormMain.cs:4964-4969 R): the owner inline (unless +queue_owner+), the
      # others queued -- only those whose interpreter can use a change (see the module comment)
      # -- and a paused script skipped (Script.TriggerVariableChanged returns at once,
      # Script.cs:1360-1363 R).
      # @return [void]
      def deliver(name, recipients, pending, queue_owner: false)
        dispatcher = queue_owner ? nil : ParseDispatch.owner
        depth = DispatchDepth.current
        recipients.each do |recipient|
          next if recipient.paused?

          interpreter = recipient.interpreter
          if dispatcher && interpreter.equal?(dispatcher)
            pending.flush if dispatcher.wants_variable_change?(name) # it may raise nested changes
            dispatcher.deliver_variable_change(name)
          elsif interpreter&.wants_variable_change?(name)
            pending.add(recipient.buffer, name, depth)
          end
        end
      end

      # The nesting-cap overflow of a broadcast: the script owning the thread stops with the script
      # error; with no owner the host prints it.
      # @return [Proc]
      def overflow_handler(on_overflow)
        lambda do |message|
          owner = ParseDispatch.owner
          owner.respond_to?(:dispatch_overflow) ? owner.dispatch_overflow(message) : on_overflow.call(message)
        end
      end
    end
  end
end
