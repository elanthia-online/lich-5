# frozen_string_literal: true

module Lich
  module Genie
    # The script-timing events Remix's Game.cs raises while it parses a row, and their
    # delivery to the scripts:
    #
    #   * {RoundTime}: a prompt that carries a roundtime -> Game.SetRoundTime -> FormMain
    #     SetRoundTime -> Script.SetRoundTime for EVERY script in the list, paused or not
    #     (Game.cs:2369-2373, 3256 R; FormMain.cs:6927-6954 R; Script.cs:999-1007 R): the
    #     script's m_oRoundTimeEnd = Now + rt + RTOffset, which gates every resume but
    #     `delay` and `action instant` (TickScript, Script.cs:1505-1511 R).
    #   * {Prompt}: EventTriggerPrompt -> Script.TriggerPrompt (`wait`'s flag, Game.cs:2411 R;
    #     FormMain.cs:6860-6886 R; Script.cs:1460-1485 R), plus the prompt text Game.cs prints
    #     with parse (Game.cs:2397-2405 R: "> ", "R> ", ...), which reaches the #triggers and
    #     every script like a game line (PrintTextToWindow -> TriggerParse, Game.cs:3062-3069 R).
    #     In Lich the prompt row is the END OF THE DR PACKET (interpreter-spec.md section 12, "Lich
    #     delivery facts"), so it also stands for Remix's end of the socket buffer (SetBufferEnd,
    #     FormMain.cs:5620-5643 R).
    #   * {Move}: the `room desc` component -> EventTriggerMove -> Script.TriggerMove (`move`'s
    #     flag, Game.cs:1763-1765 R; FormMain.cs:6889-6915 R; Script.cs:1434-1458 R).
    #   * {TextLine}: every text the row parser prints with parse to a parsed window
    #     (PrintTextWithParse -> PrintTextToWindow -> TriggerParse, Game.cs:2808-2933, 3062-3069
    #     R) -- the game lines the scripts and the #triggers see. Since v0.20.0 the glue no longer
    #     hands scripts Lich's strip_xml lines: this is their only game text.
    #
    # GameState records them per row, in the order the row prints them ({GameState::Row#events});
    # the host turns each into an item on every listed script's input ({.deliver}), after the
    # row's variable changes -- Remix raises those synchronously while it parses the row, and the
    # row's text reaches TriggerParse through the trigger Channel afterwards (genieflow row
    # delivery). Pure: the host passes its scripts as ParseDispatch::Recipients.
    module GameEvents
      # A prompt with a roundtime (GameState's side): +seconds+ = rt + RTOffset (the double
      # offset, Script.cs:1007 R). Delivered as a {RoundTimeEnd} on the reading interpreter's clock.
      RoundTime = Struct.new(:seconds)

      # The input items below are Strings, like every other item on a script's input (Lich's
      # script buffer holds lines; ParseDispatch::Line, VariableDispatch::Change), with an
      # empty text: no Lich code that reads a buffer as text sees anything.

      # Script.SetRoundTime's m_oRoundTimeEnd, absolute on the reading interpreter's own clock.
      class RoundTimeEnd < String
        # @return [Float]
        attr_reader :ends_at

        # @param ends_at [Float]
        def initialize(ends_at)
          super('')
          @ends_at = ends_at
          freeze
        end
      end

      # A prompt: +text+ is the prompt text printed with parse, or nil when Remix prints none
      # (`#config prompt` off, the last row printed to the main window was a prompt -- GameState#
      # last_row_was_prompt --, or the prompt printed to the room/inv window, Game.cs:2397,
      # 3062-3069 R).
      class Prompt < String
        # @return [String, nil]
        attr_reader :text

        # @param text [String, nil]
        def initialize(text)
          super('')
          @text = text&.dup&.freeze
          freeze
        end
      end

      # A text the row parser prints with parse to a window whose text reaches TriggerParse
      # (PrintTextToWindow, Game.cs:3062-3069 R: not Room/Inv/Log; with `parsegameonly`, only
      # Main): +text+ is Utility.Trim(text) -- CR/LF trimmed from both ends, nothing else
      # (Utility.cs:847-861 R) -- and never Trim()-blank. GameState records one per printed
      # segment: a row's text at its end, a roomDesc preset on its own, the text
      # flushed at a mid-row stream change, the bold `< `/`> `/`* ` combat split, a thoughts
      # <stream>. Delivered like the prompt text: the global #triggers, then every unpaused
      # script as a game line (a plain String).
      class TextLine
        # @return [String]
        attr_reader :text

        # @param text [String]
        def initialize(text)
          @text = text.dup.freeze
          freeze
        end
      end

      # A `room desc` component (TriggerMove).
      class Move < String
        def initialize
          super('')
          freeze
        end
      end

      # The one Move item (it carries nothing).
      MOVE = Move.new

      # Not a game event: the host resumed the paused script (Lich's unpause). It only wakes the
      # interpreter parked on its input; it carries nothing and changes nothing.
      class Resumed < String
        def initialize
          super('')
          freeze
        end
      end

      # The one Resumed item.
      RESUMED = Resumed.new

      module_function

      # Deliver one row's events, in order: a {RoundTime} to every listed script (Script.
      # SetRoundTime has no pause check), a {Prompt}'s text to the global #triggers first
      # (ParseTriggers: #triggers, then scripts, FormMain.cs:4425-4512 R) and then the {Prompt}
      # and a {Move} to every unpaused script (TriggerPrompt / TriggerMove / TriggerParse return
      # for a paused script, Script.cs:1181, 1434-1485 R); a {TextLine} like the prompt text: the
      # #triggers, then the unpaused scripts (a trigger body's `#parse` reaches the scripts
      # before the line itself, as in ParseTriggers).
      # @param events [Enumerable<RoundTime, Prompt, Move>]
      # @param recipients [Enumerable<ParseDispatch::Recipient>] the listed scripts, launch order
      # @param clock [#call] the interpreters' clock (Float seconds) for {RoundTimeEnd}
      # @param triggers [#apply] the global #trigger registry
      # @param runner [#fire] the global trigger-action runner
      # @param on_error [#call] callable(exception) for a failing trigger action
      # @param trace [#call, nil] callable(text) told about each {TextLine} before its #triggers (the
      #   glue's `trace_triggers` diagnostics)
      # @return [void]
      def deliver(events, recipients:, clock:, triggers:, runner:, on_error:, trace: nil)
        events.each do |event|
          case event
          when RoundTime
            item = RoundTimeEnd.new(clock.call + event.seconds)
            recipients.each { |recipient| recipient.buffer.push(item) }
          when Prompt
            ParseDispatch.fire_triggers(event.text, triggers: triggers, runner: runner, on_error: on_error) if offered?(event.text)
            push_unpaused(recipients, event)
          when Move then push_unpaused(recipients, event)
          when TextLine
            trace&.call(event.text)
            ParseDispatch.fire_triggers(event.text, triggers: triggers, runner: runner, on_error: on_error)
            line = event.text.dup # a game line: a plain, unfrozen String like Lich's own pushes
            push_unpaused(recipients, line)
          end
        end
      end

      # @param text [String, nil]
      # @return [Boolean] whether TriggerParse would look at +text+ (it returns for a Trim()-empty
      #   one, Script.cs:1188-1191 R; ParseTriggers too)
      def offered?(text)
        !text.nil? && !Text.net_trim(text).empty?
      end

      # Whether a paused script's input still takes +item+: only a {RoundTimeEnd} (SetRoundTime
      # has no pause check); every line, `#parse`, variable change, prompt and move is dropped
      # while the script is paused (Script.cs:1179-1184, 1360-1363, 1434-1485 R) -- in the
      # Lich glue only by Genie's own `#script pause` (a decided divergence: a Lich-level
      # pause buffers the input instead).
      # @param item [Object]
      # @return [Boolean]
      def kept_while_paused?(item)
        item.is_a?(RoundTimeEnd)
      end

      def push_unpaused(recipients, event)
        recipients.each { |recipient| recipient.buffer.push(event) unless recipient.paused? }
      end
      private_class_method :push_unpaused
    end
  end
end
