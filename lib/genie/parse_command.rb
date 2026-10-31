# frozen_string_literal: true

module Lich
  module Genie
    # Port of Remix Command.ParseCommand's row pipeline (Command.cs:219-2558 R) plus the
    # SendTextToGame / ClassCommand_SendText step that follows it (Command.cs:2826-2839 R,
    # FormMain.cs:4391-4422 R). The `#command` arms themselves live in {CommandRouter}
    # (+router+), which owns one instance of this class and calls back into it for the arms
    # that re-parse their arguments (ParseAllArgs, #if branches).
    #
    # Every text that reaches it -- a script's `put`/`move`/`do` row (Script_EventSendText,
    # FormMain.cs:6812-6823 R), a released CommandQueue item (RunQueueCommand, FormMain.cs:3857
    # R), a #trigger body (TriggerAction, FormMain.cs:4645-4647 R), a typed command, a
    # ParseAllArgs argument, an #if branch -- goes through {#call}:
    #   1. a text starting (case-insensitively) with `bug `, `sing ` or `;` is not split at
    #      all: with +send_to_game+ it is sent whole (ParseGlobalVars + SendTextToGame), and
    #      the text itself is the result (Command.cs:223-233 R);
    #   2. otherwise it is SafeSplit on the separator char ({Text.remix_safe_split}); a piece
    #      whose first word is an alias key is replaced by the alias (ParseAlias) and split
    #      again (Command.cs:235-244 R);
    #   3. each RAW row (never trimmed): a leading `-` becomes `#send ` when +parse_quick_send+
    #      (Command.cs:246-253 R); a row whose TRIMMED text starts with the command char is a
    #      `#command` -- the router's result is this row's result; a row starting with the
    #      script char launches that script; any other row is sent (ParseGlobalVars +
    #      SendTextToGame) when +send_to_game+ and is its own result (Command.cs:255-2550 R).
    #      The result of the LAST row is returned (sResult is reset per row).
    #
    # Lich commands only from author-written text ({AuthoredCommand}; a decided divergence, for
    # security): a row is handed to the game sink as a {LichCommand} -- the only send the glue
    # gives Lich's command path -- when its leading `,`/`;` carries an author mark the raw-text
    # caller put there (a script's put/send row, an authored #trigger or action body, a
    # lich-key alias with an authored value); a code-running Lich command (`,e ...`) only when
    # that mark is the code mark (a literal .cmd `put` row) and ParseGlobalVars left the row as it
    # was. The marks are read and taken out per row before anything else sees it. Every other
    # send, including one whose `,`/`;` came in with a variable or capture, is plain game text.
    #
    # A fault (ParseArgs on a lone quote, double.Parse in #send ...) propagates out of
    # {#call}, as Remix's awaited inner ParseCommands do; the top-level callers never await
    # the Task (Command.cs:219 R is async; FormMain.cs:3861, 4647, 6823 R discard it), so the
    # fault ends that ParseCommand -- its remaining rows never run -- and nothing is shown:
    # {#run} is that top level. A nested-dispatch cap overflow ({DispatchDepth::Exceeded}) is
    # never swallowed.
    class ParseCommand
      # Config.cQuickSendChar (Config.cs:15 R): no #config setting changes it.
      QUICK_SEND_CHAR = '-'
      # The prefixes that bypass the split (Command.cs:223 R), compared on ToLower().
      BYPASS_PREFIXES = ['bug ', 'sing ', ';'].freeze
      # Config.iArgumentCount (Config.cs:18 R): ParseAlias replaces $1..$14.
      ALIAS_ARGUMENT_COUNT = 15
      # Stands in for Remix's U+00A4 marker (Command.cs:2830-2836 R; FormMain.cs:4397-4405 R):
      # an ASCII control keeps the source ASCII-only and never meets a non-UTF-8 game text. So
      # a literal U+00A4 in a sent text stays as it is, where Remix turns it into `\` or `@`
      # (0 corpus).
      MARK = "\x04"
      # What the input box gets for a marker still in the text (Remix shows the U+00A4 itself).
      INPUT_BOX_MARK = [0xA4].pack('U')

      # @param router [#command] runs one `#command` row and returns its result (CommandRouter)
      # @param game [#call] callable(text): a command for the game, after SendTextToGame and
      #   ClassCommand_SendText (Game.SendText)
      # @param launch [#call] callable(name, args): ClassCommand_RunScript
      # @param globals [#call] callable(text) => text: Globals.ParseGlobalVars
      # @param input_box [#call] callable(text): SendTextInputBox -- a text holding `@` or `\x`
      #   goes to the front end's input box, nothing to the game (FormMain.cs:4378-4384 R)
      # @param chars [#call] callable => an object with +separator_char+, +command_char+ and
      #   +script_char+ (the live {GameState::Config})
      # @param aliases [#call] callable => a Hash-like AliasList (key?, []): the engine's
      #   AliasList (CommandRouter passes Lists#aliases); empty by default
      def initialize(router:, game:, launch:, globals:, input_box:, chars:, aliases: -> { {} })
        @router = router
        @game = game
        @launch = launch
        @globals = globals
        @input_box = input_box
        @chars = chars
        @aliases = aliases
      end

      # Command.ParseCommand (Command.cs:219-2558 R).
      # @param text [String]
      # @param send_to_game [Boolean] bSendToGame
      # @param parse_quick_send [Boolean] bParseQuickSend
      # @return [String] sResult
      def call(text, send_to_game: false, parse_quick_send: true)
        text = text.to_s
        plain = AuthoredCommand.strip(text)
        if bypass?(plain)
          send_marked(plain, text) if send_to_game
          return plain
        end

        chars = @chars.call
        result = ''
        Text.remix_safe_split(text, chars.separator_char).each do |piece|
          piece = parse_alias(piece, chars.separator_char) if alias?(AuthoredCommand.strip(piece))
          Text.remix_safe_split(piece, chars.separator_char).each do |row|
            result = run_row(row, chars, send_to_game, parse_quick_send)
          end
        end
        result
      end

      # A top-level ParseCommand whose Task nobody awaits (Script_EventSendText, RunQueueCommand,
      # TriggerAction, typed input): a fault ends it silently (see the class comment).
      # @return [void]
      def run(text, send_to_game:)
        call(text, send_to_game: send_to_game)
        nil
      rescue DispatchDepth::Exceeded
        raise
      rescue Error
        nil
      end

      # Command.SendTextToGame (Command.cs:2826-2839 R) then FormMain.ClassCommand_SendText
      # (FormMain.cs:4391-4422 R): `\\` -> `\`, `\x` and `\@` kept, every other `\` dropped;
      # then a text holding `@` or `\x` (a `\@` does not count) goes to the input box, else
      # `\@` -> `@` and a non-empty text goes to the game. (SafeParsePluginInput: no plugins.)
      # @param text [String]
      # @param lich_command [Boolean] the text's leading `,`/`;` is author-written: the
      #   game sink gets a {LichCommand} ({AuthoredCommand.lich_command})
      # @param code [Boolean] it may be a code-running Lich command (a literal .cmd `put` row)
      # @return [void]
      def send_text_to_game(text, lich_command: false, code: false)
        text = unescape(text)
        text = text.gsub('\\@', MARK)
        if text.include?('\\x') || text.include?('@')
          @input_box.call(text.gsub(MARK, INPUT_BOX_MARK))
        else
          text = text.gsub(MARK, '@')
          @game.call(lich_command ? AuthoredCommand.lich_command(text, code: code) : text) unless text.empty?
        end
      end

      private

      def bypass?(text)
        lower = text.downcase
        BYPASS_PREFIXES.any? { |prefix| lower.start_with?(prefix) }
      end

      # One row of the inner loop (Command.cs:244-2551 R); returns its sResult. The author mark is
      # read and removed first ({AuthoredCommand}), so every test below sees the row as Remix does.
      def run_row(row, chars, send_to_game, parse_quick_send)
        marked = row
        row = AuthoredCommand.strip(row)
        row = "#send #{row[1..]}" if parse_quick_send && row.start_with?(QUICK_SEND_CHAR)
        if Text.net_trim(row).start_with?(chars.command_char)
          @router.command(row).to_s
        elsif row.start_with?(chars.script_char)
          launch(row)
          ''
        else
          send_marked(row, marked) if send_to_game
          row
        end
      end

      # RunScript -> ClassCommand_RunScript (Command.cs:2536-2539, 2695-2698 R): the name is
      # ParseArgs token 0 minus the script char ({ScriptArgs.split_launch}). An empty one (`put .`,
      # `put . x`) still launches: Remix looks for ".cmd" and prints "File not found: .cmd" (flow
      # t162; {ScriptLaunch}).
      def launch(row)
        name, rest = ScriptArgs.split_launch(row)
        @launch.call(name, rest)
      end

      # SendTextToGame(ParseGlobalVars(+row+)) for a row whose marked form is +marked+: a
      # LichCommand when its leading `,`/`;` is marked, one that may run code only when that
      # mark is the code mark and ParseGlobalVars changed nothing (the row needed no expansion).
      def send_marked(row, marked)
        expanded = @globals.call(row)
        send_text_to_game(expanded, lich_command: AuthoredCommand.leads?(marked),
                                    code: AuthoredCommand.leads_code?(marked) && expanded == row)
      end

      # The AliasList test (Command.cs:238 R): the first word of the Trim()med piece, lower-cased.
      def alias?(piece)
        @aliases.call.key?(Text.keyword_string(piece).downcase)
      end

      # Command.ParseAlias (Command.cs:2746-2780 R). Its own lookup uses the word AS TYPED, so a
      # key that only matched lower-cased expands to "" (the piece then runs nothing).
      # The alias value is author-marked ({AuthoredCommand.mark}) when the alias was
      # defined authored ({AliasList#authored?}: aliases.cfg, or a literal `put #alias` row) AND the
      # piece invoking it was marked -- a lich-key alias (`,t2r`) the author wrote; the `$n`/rest
      # put in come from the piece and stay unmarked. Never with the code mark: no alias runs code.
      # Any other alias or piece (a key out of a variable, a non-lich key, a value defined from a
      # capture) expands to a value whose `,`/`;` rows are game text.
      def parse_alias(piece, separator)
        text = AuthoredCommand.strip(piece)
        aliases = @aliases.call
        key = Text.keyword_string(text)
        return '' unless aliases.key?(key)

        result = aliases[key].to_s
        result = AuthoredCommand.mark(result, separator) if AuthoredCommand.leads?(piece) && authored_alias?(aliases, key)
        rest = Text.argument_string(text)
        return "#{result} #{rest}" unless result.include?('$')

        args = Text.parse_args(text)
        result = result.gsub('$0') { rest.delete('"') }
        (1...ALIAS_ARGUMENT_COUNT).each do |i|
          value = i < args.length ? args[i].delete('"') : ''
          result = result.gsub("$#{i}") { value }
        end
        result
      end

      # Whether +aliases+ (an {AliasList}; a plain Hash knows no provenance) holds +key+ as authored.
      def authored_alias?(aliases, key)
        aliases.respond_to?(:authored?) && aliases.authored?(key)
      end

      def unescape(text)
        return text unless text.include?('\\')

        text.gsub('\\\\', MARK).gsub('\\x', "#{MARK}x").gsub('\\@', "#{MARK}@").delete('\\').gsub(MARK, '\\')
      end
    end
  end
end
