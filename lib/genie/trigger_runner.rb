# frozen_string_literal: true

module Lich
  module Genie
    # Runs a matched trigger's action string (Remix FormMain.TriggerAction, FormMain.cs:4615-4657
    # R): the captures replace `$1`..`$15` (quotes removed, "" when missing) and then `$0` (the
    # FIRST capture), and the body goes to Command.ParseCommand(body, bSendToGame: true) -- the
    # separator split, `#` commands (each expanding `$globals` itself where Remix does), `.`
    # launches, `-` quick sends, and the plain rows sent after ParseGlobalVars. The body itself
    # is not expanded first (`sAction = ParseGlobalVars(sAction)` is commented out, 4643 R), and
    # `%locals` mean nothing here. The ParseCommand Task is not awaited, so a fault ends the
    # body quietly ({ParseCommand#run}). Also the queue's executor: {#run_command} is
    # RunQueueCommand (FormMain.cs:3857-3870 R).
    #
    # Reuses the same {CommandRouter} as the interpreter. Collaborators are injected so this
    # runs headless in specs.
    class TriggerRunner
      # Config.iArgumentCount (Config.cs:18 R): TriggerAction replaces $1..$15.
      ARGUMENT_COUNT = 15
      # Thread-local origin of the sends a #trigger body makes while {#fire} runs it: Remix's
      # TriggerAction calls ParseCommand(sAction, true, false, "Trigger") (FormMain.cs:4647 R), and
      # Game.SendText hides the echo of a send whose origin a gag matches (Game.cs:481-511 R; the
      # glue's LichGamePort reads it).
      ORIGIN_KEY = :lich_genie_send_origin
      TRIGGER_ORIGIN = 'Trigger'

      # @param vars [Variables] global-scoped store (shared with scripts)
      # @param eval [Eval] expression evaluator for #eval/#if
      # @param game [#send_command] game sink
      # @param launch [#call] callable(name, args) to start a script
      # @param hooks [#emit, nil] front-end effect sink
      # @param echo [#call] local echo sink
      # @param mover [#call, nil] callable(room_arg) for #goto inside a trigger body
      # @param script_control [#names, ..., nil] host script-registry port for `#script`
      # @param parse [#call, nil] callable(text) delivering a `#parse` from a trigger body to
      #   the global #triggers and every script, the dispatch owner inline at its position
      #   (ParseTriggers, FormMain.cs:4425-4512 R; see ParseDispatch.broadcast).
      #   Wrapped in the nested-dispatch cap: a trigger chain nested past {DispatchDepth::LIMIT} stops
      #   with one error line on +echo+ (Remix recurses until it crashes).
      # @param var_changed [#call, nil] callable(name) for a global the body's `#var`/`#tvar`/
      #   `#svar`/`#math` set (Command.VariableChanged, Command.cs:933-1042 R): the host's
      #   VariableDispatch.broadcast, which carries the cap itself.
      # @param queue [CommandQueue, nil] the session's timed queue (`#send`, `#do`, `#queue`)
      # @param lists [Lists, nil] the session's global lists ({CommandRouter}); nil = a private set
      # @param log_dir [#call, nil] callable => where `#log` writes; nil = nowhere
      # @param active [#call, nil] callable => whether a matched #trigger body runs at all (the glue:
      #   the engine is on for the character, so turning it off stops every #trigger at once); nil =
      #   always
      def initialize(vars:, eval:, game:, launch:, hooks: nil, echo: nil, mover: nil, script_control: nil, parse: nil,
                     var_changed: nil, queue: nil, lists: nil, log_dir: nil, active: nil)
        @game = game
        @active = active || -> { true }
        @echo = echo || ->(_text) {}
        @parse = parse || ->(_text) {}
        @eval = eval
        @substitution = Substitution.new(variables: vars)
        @router = CommandRouter.new(
          vars: vars, eval: eval, hooks: hooks, mover: mover, script_control: script_control,
          echo: @echo, send: ->(text) { @game&.send_command(text) }, parse: ->(text) { parse_text(text) },
          var_changed: var_changed, launch: launch, queue: queue, lists: lists, log_dir: log_dir
        )
      end

      # FormMain's eval-trigger condition (FormMain.cs:4946-4957 R): a key equal to the
      # changed name holds without evaluating; otherwise `Command.Eval(ParseGlobalVars(key))`
      # ($globals and @specials only, Globals.cs:150-202 R) must be non-empty and not "0".
      # @param key [String] the trigger's normalized pattern
      # @param name [String] the changed variable's name
      # @return [Boolean]
      def eval_true?(key, name)
        return true if key == name

        VariableDispatch.truthy?(@eval.eval_string(@substitution.expand_globals(key)))
      end

      # TriggerAction: execute +commands+ with the given regex +captures+. Only author-written
      # text may issue a Lich command ({AuthoredCommand}; a decided divergence): an +authored+
      # body (a triggers.cfg row, a `#trigger` from an authored context) has its rows' leading
      # `,`/`;` author-marked (the provenance mark, never the code mark) before the captures go
      # in, so `{,go2 x}` is a Lich command and `{$2}` fed `,e ...` is game text; any other body
      # sends its `,`/`;` rows as game text. A `#trigger`/`#alias` the body defines is authored
      # only when the body is and no capture changed it.
      # @param commands [String]
      # @param captures [Array<String>] groups 1..n
      # @param authored [Boolean] the trigger's provenance ({Triggers::Trigger}#authored)
      # @return [void]
      def fire(commands, captures, authored: false)
        return unless @active.call

        body = commands.to_s
        body = AuthoredCommand.mark(body, @router.config.separator_char) if authored
        text = self.class.substitute_captures(body, Array(captures).map(&:to_s))
        with_trigger_origin { parse_command(text, defining: authored && text == body) }
      end

      # RunQueueCommand / a typed command: ParseCommand(text, bSendToGame: true), top level. A
      # released `send ,go2 x` comes with its author marks ({CommandQueue::Item#release_text});
      # nothing it defines is authored.
      # @param text [String]
      # @return [void]
      def run_command(text)
        parse_command(text, defining: false)
      end

      # TriggerAction's `$n` pass (FormMain.cs:4619-4641 R), only when the body holds a `$`.
      # @param action [String]
      # @param captures [Array<String>]
      # @return [String]
      def self.substitute_captures(action, captures)
        return action unless action.include?('$')

        ARGUMENT_COUNT.times do |i|
          value = i < captures.length ? captures[i].delete('"') : ''
          action = action.gsub("$#{i + 1}") { value } # String.Replace: no backreferences
        end
        action.gsub('$0') { captures.empty? ? '' : captures[0].delete('"') }
      end

      private

      # ParseCommand(+text+, bSendToGame: true), top level, with the definitions it makes authored
      # or not ({AuthoredCommand.defining}).
      def parse_command(text, defining:)
        AuthoredCommand.defining(defining) { @router.run(text, send_to_game: true) }
      end

      # Run the block with the sends' origin set to "Trigger" ({ORIGIN_KEY}), restored after.
      def with_trigger_origin
        previous = Thread.current[ORIGIN_KEY]
        Thread.current[ORIGIN_KEY] = TRIGGER_ORIGIN
        yield
      ensure
        Thread.current[ORIGIN_KEY] = previous
      end

      # The host port (ParseDispatch.broadcast) fires the global #triggers and delivers the
      # text to every script in list order: the script dispatching this chain on this thread
      # (ParseDispatch.owner), if any, inline at its position -- Remix ParseTriggers calls
      # its TriggerParse synchronously too (FormMain.cs:4488-4489 R) -- the others queued.
      # On the hook thread there is no owner.
      def parse_text(text)
        DispatchDepth.nest("#parse #{text}", on_overflow: ->(message) { @echo.call("[#{message}]") }) do
          @parse.call(text)
        end
      end
    end
  end
end
