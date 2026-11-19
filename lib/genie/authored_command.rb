# frozen_string_literal: true

require 'securerandom'

module Lich
  module Genie
    # A game send the engine hands to Lich's command path (do_client) instead of the game: the
    # only kind {LichGamePort#send_command} dispatches as a Lich command. Built only by
    # {AuthoredCommand.lich_command} (from {ParseCommand#send_text_to_game}) for a row whose leading
    # `,`/`;` the author wrote ({AuthoredCommand}). A String, so every game sink takes it as the
    # text it is; any change to the text (to_s, strip, +, gsub) gives a plain String back, which
    # is a game send again.
    class LichCommand < String
      # @param text [String]
      # @return [LichCommand] frozen
      def self.[](text)
        new(text.to_s).freeze
      end
    end

    # Decided divergence (security over Genie-in-front-of-Lich parity): text another player
    # can put in front of a script -- a whisper a capture takes, a variable set from one, a
    # definition made from one -- never reaches Lich's command path. Two layers:
    #
    # Provenance layer. A send goes to Lich as a Lich command (`,go2 123`, `;kill x`) only when its
    # leading `,`/`;` stands in text the user authored, before any variable, `$n` capture or
    # global is put in:
    #   * a .cmd file's `put`/`send` row (its argument as the file has it);
    #   * the body of a #trigger, an alias or a script action whose DEFINITION was authored,
    #     decided when it is defined: read from the user's cfg file (triggers.cfg / aliases.cfg at
    #     engine start, `#load`, `#trigger load`, `#alias load`) and not listed in its side file
    #     ({DefinitionTrust}); or defined by a .cmd `put` row
    #     whose text needed no expansion at all (`put #trigger {x} {,go2 1}`), or by an authored
    #     #trigger body with no capture put in ({.authored_definitions?}); a script action is
    #     authored when its `action` row is a .cmd row, not an action body's row. A definition
    #     made from an action body, a #trigger body with captures, an expanded row, a queued
    #     send, JS or the typed input is not authored: its `,`/`;` rows are game text.
    #   A saved definition keeps its flag: `#trigger save`/`#alias save` list the ones that are not
    #   authored in a side file the load reads ({DefinitionTrust}); the cfg keeps Remix's format.
    #   The command NAME must be literal too: a `$`, `%` or `@` in it ({EXPANDABLE_NAME}: `,$1`,
    #   `,%cmd`, `;pro%x args`) leaves the `,`/`;` unmarked, so game text never chooses which Lich
    #   script runs; the arguments after it may be expanded (`put ,go2 %dest`).
    # Code layer. A Lich command that runs code ({.code_command?}: Ruby through `,e`/`,eq`/`,exec`/
    #   `,execq`/`,execname`/`,en`, Lich code installed by `,lich5-update`/`,l5u`) dispatches only
    #   from a .cmd file's `put` row whose text needed no expansion at all -- `put ,e
    #   $T2.reload_settings` while no global T2 exists. From anywhere else (a `send` row, which
    #   queues; any #trigger, alias or action body, authored or not; `#send`/`#put`/`#if`; JS; an
    #   expanded row) it goes to the game as text.
    # Anything that is not a Lich command goes to the game as ordinary text, as it does when
    # Genie is connected straight to the game.
    #
    # How, at the send: where a row is still raw, {.mark} puts {MARK} (or {CODE_MARK} on the
    # code layer's rows) right after each author-written leading `,`/`;` of a SafeSplit piece.
    # The marks are inert to everything between there and the send (variable and capture
    # substitution, ParseGlobalVars, the SafeSplit itself: no `%`, `$`, `@`, quote, brace,
    # backslash or separator in them, and coming AFTER the piece's first character they never
    # move a separator onto or off a piece start, so the split is the unmarked text's), so they
    # stay glued to their character however the expansion reshapes the line. ParseCommand reads
    # them per row ({.leads?}, {.leads_code?}) and takes them out ({.strip}) before anything else
    # sees the row; the clean text is what every other consumer gets ($lastcommand, the echo, the
    # `#queue` listing, the variables, an error line). The marks hold a per-process random part,
    # so no game text, file or variable can carry one.
    module AuthoredCommand
      # Two ASCII controls around 16 random hex digits: no white space, sigil, quote, brace,
      # backslash or separator in it. Marks an author-written Lich command char.
      MARK = "\x05#{SecureRandom.hex(8)}\x05".freeze
      # The same shape, other controls and digits. Marks an author-written Lich command char in a
      # .cmd `put` row that needed no expansion -- a code-running Lich command may dispatch.
      CODE_MARK = "\x06#{SecureRandom.hex(8)}\x06".freeze
      # What LichGamePort skips before its Lich command test (`text.lstrip =~ /\A(?:<c>)?[,;]/`):
      # Ruby lstrip's white space (NUL included) and a `<c>` prefix.
      LEADING = /\A[\0\t\n\v\f\r ]*(?:<c>)?/.freeze
      # A Lich command char at a row start with either mark behind it.
      MARKED = /#{LEADING.source}[,;](?:#{Regexp.escape(MARK)}|#{Regexp.escape(CODE_MARK)})/.freeze
      # A Lich command char at a row start with {CODE_MARK} behind it.
      CODE_MARKED = /#{LEADING.source}[,;]#{Regexp.escape(CODE_MARK)}/.freeze
      # The script verbs whose argument is a send ParseCommand runs (put) or queues (send). `move`
      # and `do` are not marked: a Lich command there goes to the game (0 corpus rows).
      SEND_VERBS = %i[put send].freeze
      # A `send` row's delay: the leading run of digits and dots (Interpreter.send_delay).
      DELAY = /\A[0-9.]*/.freeze
      # do_client's Lich command test (lib/global_defs.rb `def do_client`: `strip!`, then
      # `/^(?:<c>)?#{$lich_char_regex}(.+)$/`, `$lich_char_regex` = `,` or `;`), whose `(.+)` is
      # what ClientCommands.dispatch matches. `^` is any line start in Ruby.
      CLIENT_COMMAND = /^(?:<c>)?[,;](.+)$/.freeze
      # The built-in ;commands that run code (lib/common/client_commands/builtins.rb): exec,
      # `/^(?:exec|e)(q)? (.+)$/` and `/^(?:execname|en) ([\w\d-]+) (.+)$/` (ExecScript.start: the
      # text is Ruby), and lich5-update, `/^(?:lich5-update|l5u)/i` (Lich::Util::Update.request:
      # `--branch=<fork>:<branch>` downloads and installs Lich code). Any case and any white space
      # after the word: wider than Lich's own patterns on purpose.
      CODE_COMMAND = /\A(?:(?:exec|e)q?|execname|en)(?:\s|\z)|\A(?:lich5-update|l5u)/i.freeze
      # A command name (after the `,`/`;` and any white space, up to the next white space) that
      # holds a sigil something may expand -- `%var`/`%1` and `$global`/`$1`/`$0` (Substitution, a
      # capture, an alias argument), `@special@` (Specials): the name might not be the text the
      # author wrote, so game text could choose which Lich script runs (`action put ,$1 when ...`).
      # Checked on the raw text, whether or not such a variable exists, so the name is literal.
      EXPANDABLE_NAME = /\A\s*[^\s$%@]*[$%@]/.freeze
      # Thread-local: whether a #trigger/alias/action defined by the text running now is authored
      # ({.defining}).
      DEFINITION_KEY = :lich_genie_authored_definition

      module_function

      # +text+ with a mark after the leading `,`/`;` of each of its SafeSplit pieces.
      # @param text [String] raw (author-written) text
      # @param separator [String] the live separator char
      # @param delay [Boolean] the text is a `send` argument: its first piece may open with a delay
      # @param code [Boolean] {CODE_MARK} (a literal .cmd `put` row) instead of {MARK}
      # @return [String]
      def mark(text, separator, delay: false, code: false)
        text = text.to_s
        return text unless text.include?(',') || text.include?(';')

        token = code ? CODE_MARK : MARK
        out = +''
        last = 0
        Text.remix_safe_split_ranges(text, separator).each_with_index do |range, index|
          at = command_char_at(text, range, delay: delay && index.zero?)
          next unless at

          out << text[last..at] << token
          last = at + 1
        end
        last.zero? ? text : out << text[last..]
      end

      # The argument of a `put`/`send` row (+function+), marked; any other row unchanged. The
      # argument is what Text.argument_string gives: after the first space of the trimmed row.
      # @param row [String]
      # @param function [Symbol] the row's verb (Lexer function type)
      # @param separator [String]
      # @param code [Boolean] see {.mark}
      # @return [String]
      def mark_argument(row, function, separator, code: false)
        return row unless SEND_VERBS.include?(function)

        lead = row.length - Text.net_trim_start(row).length
        space = Text.net_trim(row).index(' ')
        return row unless space

        start = lead + space + 1
        row[0...start] + mark(row[start..], separator, delay: function == :send, code: code)
      end

      # +text+ with every {CODE_MARK} turned into a {MARK}: the row needed expansion after all.
      # @param text [String]
      # @return [String]
      def downgrade(text)
        text.include?(CODE_MARK) ? text.gsub(CODE_MARK, MARK) : text
      end

      # @param text [String] a row as split
      # @return [Boolean] whether its leading Lich command char is author-written (either mark)
      def leads?(text)
        MARKED.match?(text)
      end

      # @param text [String] a row as split
      # @return [Boolean] whether its leading Lich command char carries {CODE_MARK}
      def leads_code?(text)
        CODE_MARKED.match?(text)
      end

      # @param text [String]
      # @return [Boolean] whether +text+ holds a mark
      def marked?(text)
        text.include?(MARK) || text.include?(CODE_MARK)
      end

      # @param text [String]
      # @return [String] +text+ without its marks
      def strip(text)
        text = text.gsub(MARK, '') if text.include?(MARK)
        text = text.gsub(CODE_MARK, '') if text.include?(CODE_MARK)
        text
      end

      # Whether Lich's do_client would run +text+ as a code-running built-in ({CODE_COMMAND}):
      # any line of the stripped text that is a Lich command whose command is one (do_client acts
      # on the first such line; every one is checked).
      # @param text [String]
      # @return [Boolean]
      def code_command?(text)
        text.to_s.strip.scan(CLIENT_COMMAND).any? { |(command)| CODE_COMMAND.match?(command.lstrip) }
      end

      # The one place a {LichCommand} is made: +text+ (a send whose leading `,`/`;` is
      # author-written) as a LichCommand -- unless it is a code-running command
      # ({.code_command?}) and +code+ is false (the code layer), which stays a plain String: game text.
      # @param text [String]
      # @param code [Boolean] the send came from a literal .cmd `put` row ({.leads_code?})
      # @return [LichCommand, String]
      def lich_command(text, code:)
        return text.to_s if !code && code_command?(text)

        LichCommand[text]
      end

      # Run the block with the definitions it makes authored or not: `#trigger`, `#alias`
      # and `action` read {.authored_definitions?}. Each entry point that runs text sets it --
      # never inherited from an outer one, so a #trigger fired inside a literal row decides its
      # own.
      # @param authored [Boolean]
      # @return [Object] the block's value
      def defining(authored)
        previous = Thread.current[DEFINITION_KEY]
        Thread.current[DEFINITION_KEY] = authored ? true : false
        yield
      ensure
        Thread.current[DEFINITION_KEY] = previous
      end

      # @return [Boolean] whether a definition made now is authored ({.defining}; false outside)
      def authored_definitions?
        Thread.current[DEFINITION_KEY] == true
      end

      # The index of the `,`/`;` a piece opens with (after a delay, white space and `<c>`), or nil
      # -- nil too when the command name after it is not all literal ({EXPANDABLE_NAME}).
      def command_char_at(text, range, delay:)
        piece = text[range]
        skip = delay ? piece[DELAY].length : 0
        at = skip + piece[skip..][LEADING].length
        return nil unless at < piece.length && [',', ';'].include?(piece[at])
        return nil if EXPANDABLE_NAME.match?(piece[(at + 1)..])

        range.begin + at
      end
    end
  end
end
