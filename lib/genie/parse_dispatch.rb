# frozen_string_literal: true

module Lich
  module Genie
    # Delivery of a `#parse` line: Remix ParseTriggers (FormMain.cs:4425-4512 R) runs the
    # global #triggers on it, then every script's TriggerParse (Script.cs:1179-1316 R) in
    # script-list order, all synchronously on the issuing thread. Here each script has its
    # own thread, so:
    #
    #   * the global #triggers fire on the calling thread ({.broadcast}), a failing action
    #     reported and the remaining triggers still fired ({.fire_trigger});
    #   * the script whose own `#parse` started the chain -- this thread's dispatch OWNER
    #     ({.as_owner}, set by Interpreter#parse_text) -- handles every line of the chain
    #     inline, at its position in the script list (Interpreter#deliver_parse): its own
    #     `#parse` text and a nested trigger-body `#parse` (TriggerRunner) alike;
    #   * every other unpaused script gets the line queued on its input, stamped with the
    #     dispatch depth it was issued at ({Line}), so a cross-script chain keeps counting towards
    #     {DispatchDepth::LIMIT} on the receiving thread (Interpreter resumes the count).
    #
    # Pure: the host passes the trigger registry, the trigger runner and its scripts as
    # {Recipient}s (Lich glue: GenieScript.parse_broadcast; specs: the flow harness).
    module ParseDispatch
      OWNER_KEY = :lich_genie_parse_owner

      # A queued `#parse` line. A String (Lich's script buffer and the interpreter read it as
      # one) that also carries the {DispatchDepth} it was issued at, and whether TriggerParse
      # treats it as a game line (bBufferWait: a trigger-on-input line, {.input}; a `#parse` is
      # not one, ParseTriggers(s, false), FormMain.cs:4659-4667 R).
      class Line < String
        # @return [Integer]
        attr_reader :dispatch_depth

        # @param text [String]
        # @param dispatch_depth [Integer]
        # @param game [Boolean]
        def initialize(text, dispatch_depth, game: false)
          super(text)
          @dispatch_depth = dispatch_depth
          @game = game
        end

        # @return [Boolean] whether it is part of a DR packet (bBufferWait = true)
        def game?
          @game
        end
      end

      # One running script as the host sees it: its interpreter (compared with the owner;
      # nil while it is still being built), its input buffer (#push), and whether it is
      # paused (Remix TriggerParse returns at once for a paused script, Script.cs:1181 R):
      # true/false, or a callable read when the line reaches this script -- a #trigger of
      # the same line, or an earlier script's action, may have paused it meanwhile.
      Recipient = Struct.new(:interpreter, :buffer, :paused, keyword_init: true) do
        # @return [Boolean]
        def paused?
          paused.respond_to?(:call) ? paused.call : paused
        end
      end

      module_function

      # @return [Object, nil] the interpreter dispatching a `#parse` on this fiber/thread
      def owner
        Thread.current[OWNER_KEY]
      end

      # Run the block with +interpreter+ as this fiber's dispatch owner (restored after).
      # @return [Object] the block's value
      def as_owner(interpreter)
        previous = Thread.current[OWNER_KEY]
        Thread.current[OWNER_KEY] = interpreter
        yield
      ensure
        Thread.current[OWNER_KEY] = previous
      end

      # @param line [String]
      # @return [Integer] the dispatch depth a queued `#parse` line carries; 0 for a game line
      def depth_of(line)
        line.is_a?(Line) ? line.dispatch_depth : 0
      end

      # @param text [String]
      # @return [String] +text+ as a {Line} carrying the current dispatch depth inside a dispatch
      #   chain, +text+ itself outside one. For a line fed to the scripts while a chain runs
      #   (the glue's echo feed) so an echo -> action -> `#parse` loop hits the depth cap.
      def stamp(text)
        depth = DispatchDepth.current
        depth.zero? ? text : Line.new(text, depth)
      end

      # ParseTriggers for one `#parse` line (the caller has already dropped a blank one):
      # the global #triggers ({.fire_triggers}), then every running script in list order
      # (FormMain.cs:4488-4489 R). The dispatch owner gets it inline AT ITS POSITION through
      # its #deliver_parse -- the scripts before it are queued first, the ones after it once
      # its own actions (and any chain they start) are done; the others get it queued with
      # the depth it was issued at. A paused script gets nothing (TriggerParse returns at
      # once, Script.cs:1181 R), and neither does an owner that is no longer in the list. A
      # fault in the owner's delivery is re-raised only after the scripts after it have the
      # line ({.deliver_to_owner}).
      #
      # @param text [String]
      # @param triggers [#apply] the global #trigger registry (yields commands, captures)
      # @param runner [#fire] the global trigger-action runner
      # @param recipients [Enumerable<Recipient>] the running scripts, in launch order
      # @param on_error [#call] callable(exception) for a failing trigger action
      # @return [void]
      def broadcast(text, triggers:, runner:, recipients:, on_error:)
        fire_triggers(text, triggers: triggers, runner: runner, on_error: on_error)
        dispatcher = owner
        depth = DispatchDepth.current
        owner_fault = nil
        recipients.each do |recipient|
          next if recipient.paused?

          if dispatcher && recipient.interpreter.equal?(dispatcher)
            owner_fault = deliver_to_owner(dispatcher, text)
          else
            recipient.buffer.push(Line.new(text, depth))
          end
        end
        raise owner_fault if owner_fault
      end

      # The owner's inline TriggerParse. A fault in it (an action's evaluator error)
      # stops only the owner: Remix ParseTriggers still offers the line to every script
      # after it (FormMain.cs:4488-4489 R), so the fault is returned and
      # re-raised by {.broadcast} once they all have it. The depth-cap overflow unwinds at
      # once (decided: nothing after the cap runs).
      # @return [StandardError, nil] the owner's fault
      def deliver_to_owner(dispatcher, text, game: false)
        game ? dispatcher.deliver_parse(text, game: true) : dispatcher.deliver_parse(text)
        nil
      rescue DispatchDepth::Exceeded
        raise
      rescue StandardError => e
        e
      end
      private_class_method :deliver_to_owner

      # Trigger-on-input: Remix's ClassCommand_SendText runs ParseTriggers(sText) right after
      # Game.SendText when `triggeroninput` is on (Config.cs:19 R, default on; FormMain.cs:
      # 4391-4422 R) -- for a script's send, an action body's, a #trigger body's, a released queue
      # command's and the user's typed command alike. ParseTriggers(sText) has bBufferWait = true
      # (FormMain.cs:4425 R), so a script handles the text like a game line ({Line#game?}). The
      # host checks `triggeroninput` and calls this after the send (and its "lastcommand" change).
      #
      # Remix has no guard (FormMain.cs:4425 R): a trigger that re-sends its own text recurses
      # until the client dies (flow t39). Decided divergence, the nested-dispatch cap: every
      # synchronous dispatch of the text -- each #trigger it fires, and the sending script's own
      # inline TriggerParse -- is one {DispatchDepth} level ("input <text>"); the other scripts
      # get it queued with the depth it was sent at. At the cap the script owning the thread
      # stops with the cap's error, or +on_overflow+ prints it when no script owns the thread;
      # nothing more of the text is dispatched.
      #
      # @param text [String] the text sent
      # @param triggers [#apply]
      # @param runner [#fire]
      # @param recipients [Enumerable<Recipient>] the listed scripts, in list order
      # @param on_error [#call] callable(exception) for a failing trigger action
      # @param on_overflow [#call] callable(message) for a depth-cap overflow no script owns
      # @return [void]
      def input(text, triggers:, runner:, recipients:, on_error:, on_overflow:)
        return if Text.net_trim(text.to_s).empty? # ParseTriggers: sText.Trim().Length > 0

        level = InputLevel.new("input #{text}", VariableDispatch.overflow_handler(on_overflow))
        triggers.apply(text) do |commands, captures, authored|
          level.run { fire_trigger(runner, commands, captures, on_error: on_error, authored: authored) } unless level.overflowed
        end
        return if level.overflowed

        input_to_scripts(text, recipients, level)
      end

      # {.input}'s script loop: the owner inline (one level), the others queued.
      def input_to_scripts(text, recipients, level)
        dispatcher = owner
        depth = DispatchDepth.current
        owner_fault = nil
        recipients.each do |recipient|
          break if level.overflowed
          next if recipient.paused?

          if dispatcher && recipient.interpreter.equal?(dispatcher)
            level.run { owner_fault = deliver_to_owner(dispatcher, text, game: true) }
          else
            recipient.buffer.push(Line.new(text, depth, game: true))
          end
        end
        raise owner_fault if owner_fault && !level.overflowed
      end
      private_class_method :input_to_scripts

      # One {.input} dispatch level at a time; remembers whether the cap was hit at the outermost.
      class InputLevel
        # @return [Boolean]
        attr_reader :overflowed

        def initialize(label, handler)
          @label = label
          @handler = handler
          @overflowed = false
        end

        # @return [void]
        def run(&block)
          DispatchDepth.nest(@label, on_overflow: lambda { |message|
            @overflowed = true
            @handler.call(message)
          }, &block)
        end
      end

      # The glue's script-output feed for one genuine Lich-echoed line (the filtered stand-in
      # for want_script_output): push it into every running genie script's match buffer,
      # then run the global #triggers on it ({.fire_triggers}).
      #
      # * The line is {.stamp}ed with the running dispatch depth: echoed while a dispatch chain
      #   runs -- a #trigger's `#echo` fired by a `#parse` -- it would otherwise start a
      #   fresh, uncapped chain in the script that reads it (the unbounded echo -> action ->
      #   `#parse` loop). Remix never feeds an echo back at all (ClassCommand_EchoText only
      #   AddText, FormMain.cs:4229-4276 R).
      # * The feed runs inside Lich's respond/_respond, whose `rescue => e` swallows anything
      #   raised (lib/global_defs.rb:1761-1798): a depth-cap overflow is handed to the thread's
      #   enclosing dispatch level ({DispatchDepth.defer}), which re-raises it; outside any
      #   chain it goes to +report+.
      # * A buffer that refuses the line is skipped; the others and the #triggers still run.
      #
      # @param text [String] the stripped, non-empty line
      # @param buffers [Enumerable<#push>] the running genie scripts' downstream buffers
      # @param triggers [#apply]
      # @param runner [#fire]
      # @param on_error [#call] callable(exception) for a failing trigger action
      # @param report [#call] callable(exception) for an overflow no chain will re-raise
      # @return [void]
      def feed_output(text, buffers:, triggers:, runner:, on_error:, report:)
        buffers.each do |buffer|
          buffer.push(stamp(text))
        rescue StandardError
          nil
        end
        fire_triggers(text, triggers: triggers, runner: runner, on_error: on_error)
      rescue DispatchDepth::Exceeded => e
        report.call(e) unless DispatchDepth.defer(e)
      end

      # The global #trigger loop of ParseTriggers (FormMain.cs:4435-4459 R): every matching
      # active trigger fires, each through {.fire_trigger}.
      # @param text [String]
      # @param triggers [#apply]
      # @param runner [#fire]
      # @param on_error [#call] callable(exception)
      # @return [void]
      def fire_triggers(text, triggers:, runner:, on_error:)
        triggers.apply(text) do |commands, captures, authored|
          fire_trigger(runner, commands, captures, on_error: on_error, authored: authored)
        end
      end

      # One trigger action (TriggerAction, FormMain.cs:4615-4655 R). Remix wraps each
      # action's ParseCommand in its own try/catch (FormMain.cs:4644-4654 R), and
      # ParseCommand is an un-awaited async Task (Command.cs:219 R) whose exception never
      # reaches that catch: a failing action only abandons its own remaining commands,
      # silently, and the trigger loop goes on. Ours reports it through +on_error+ (the glue
      # prints a `--- Lich: genie trigger error:` diagnostic: a decided divergence)
      # and goes on too. The depth-cap overflow is re-raised so it unwinds to the outermost
      # dispatcher.
      #
      # @param runner [#fire]
      # @param commands [String]
      # @param captures [Array<String>]
      # @param on_error [#call] callable(exception)
      # @param authored [Boolean, nil] whether the trigger is author-written ({Triggers::Trigger}#authored)
      # @return [void]
      def fire_trigger(runner, commands, captures, on_error:, authored: false)
        runner.fire(commands, captures, authored: authored ? true : false)
      rescue DispatchDepth::Exceeded
        raise
      rescue StandardError => e
        on_error.call(e)
      end
    end
  end
end
