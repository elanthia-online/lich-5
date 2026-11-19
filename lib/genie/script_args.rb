# frozen_string_literal: true

module Lich
  module Genie
    # Genie script-launch arguments and `shift`, as pure functions over a {Variables}
    # store (no Lich dependency; the GenieScript glue and the flow harness both call
    # these, so the headless specs exercise the production code path).
    #
    # Genie4 Remix v4.2.4 model:
    #   * Launch text `.name args` is tokenized with Utility.ParseArgs(text, true)
    #     (FormMain.cs:4683 R, ClassCommand_RunScript): quotes/braces group, and `_`
    #     becomes a space in every token after the first (the script name), so the
    #     first ARGUMENT is underscore-expanded too (Utility.cs:390-517 R).
    #   * The args live ONLY in the %-locals (Script.cs:2064-2082 R, LoadFile(al)):
    #     %1..%n = args, %(n+1)..%9 = "", %0 = args joined by " " then TrimEnd,
    #     %argcount = n. The launch line's $-arg list stays EMPTY, so top-level
    #     $0..$14 are "" and $argcount is -1 (Script.cs:180-192, 2282-2299 R).
    #   * `shift` rotates the %-locals only (EvalShift, Script.cs:3003-3027 R); it never
    #     touches the $-arg list, from a row or an action body alike.
    module ScriptArgs
      module_function

      # Highest numbered local Genie always seeds (Script.cs:2077-2079 R).
      SEEDED_ARGS = 9
      # System.NullReferenceException.Message (EvalShift's sPrevious.Length on a null slot).
      NULL_REFERENCE_MESSAGE = 'Object reference not set to an instance of an object.'

      # Tokenize a launch exactly as Genie does for the typed/`put` text `.name args`.
      # Lich hands the glue the script name and the raw argument string separately, so
      # the launch text is rebuilt and the first token (the name) dropped.
      #
      # @param name [String] script name (without the script char)
      # @param cli [String, Array<String>, nil] raw argument text (an Array is joined
      #   with spaces, as Lich's start_script does)
      # @return [Array<String>] the arguments, Genie's al[1..]
      # @raise [Error] "Invalid string in Parse Arguments: .name args" on a malformed
      #   string (a lone quote token), like Utility.ParseArgs (Utility.cs:486-489 R)
      def parse_launch(name, cli)
        text = cli.is_a?(Array) ? cli.join(' ') : cli.to_s
        return [] if text.empty?

        # A fixed one-token stand-in for the name: Lich can resolve files Genie could
        # never type as one token (`pc{1}.cmd`, `my script.cmd`), whose name would
        # otherwise split or swallow arguments. The ParseArgs state after "<token> " is
        # the same for any plain token, so this is exactly al[1..].
        Text.parse_args(".x #{text}", treat_underscore_as_space: true).drop(1)
      rescue Error
        raise Error, "Invalid string in Parse Arguments: .#{name} #{text}"
      end

      # Split a launch row `.name args` (script char included, already stripped) the way
      # ClassCommand_RunScript does (FormMain.cs:4683-4684 R): the name is ParseArgs
      # token al[0], lower-cased, Trim'd, minus the script char. Token al[0] ends at the
      # first depth-0 space (consumed) or depth-0 `{` (kept: it opens the next token),
      # outside a "..." string and not after a backslash (Utility.cs:390-485 R), so
      # `._pc{a_b} c` names `_pc`. The raw remainder is returned untouched: re-parsed as
      # `.name <rest>` by {parse_launch} it yields exactly al[1..] (the ParseArgs state
      # at that point is identical), and its malformed-string error stays the child's.
      #
      # @param text [String] the row, starting with the script char
      # @return [Array(String, String)] [name, raw argument text]
      def split_launch(text)
        cut, skip = token_end(text)
        name = trim(text[0, cut].downcase)[1..].to_s
        [name, text[(cut + skip)..].to_s]
      end

      # Where ParseArgs ends token al[0] (it starts at 0: the script char), and how
      # many separator chars to drop. A `}` cannot end it: reaching depth 0 needs a
      # depth-0 `{` first, which already ended it.
      def token_end(text)
        inside = escape = false
        depth = 0
        text.each_char.with_index do |ch, cp|
          if escape then escape = false
          elsif inside then inside = false if ch == '"'
          elsif ch == '"' then inside = true
          elsif ch == '{'
            return [cp, 0] if depth.zero? && cp.positive?

            depth += 1
          elsif ch == '}' then depth -= 1
          elsif ch == ' ' && depth.zero? then return [cp, 1]
          elsif ch == '\\' then escape = true
          end
        end
        [text.length, 0]
      end

      # Seed the %-locals for a launch (LoadFile(al), Script.cs:2064-2082 R). Keys
      # above 9 are added only when that many args were given.
      #
      # @param vars [Variables]
      # @param args [Array<String>] Genie's al[1..] (see {parse_launch})
      # @return [void]
      def seed(vars, args)
        args = Array(args).map(&:to_s)
        args.each_with_index { |value, i| vars.local_set((i + 1).to_s, value) }
        ((args.length + 1)..SEEDED_ARGS).each { |i| vars.local_set(i.to_s, '') }
        vars.local_set('0', trim_end(args.map { |value| "#{value} " }.join))
        vars.local_set('argcount', args.length.to_s)
      end

      # Port of EvalShift (Script.cs:3003-3027 R). With I = %argcount > 0: %argcount
      # becomes I-1, %k takes %(k+1) for k < I, %I becomes "", and %0 is rebuilt from
      # the shifted values joined by " ", skipping EMPTY ones, then Trim'd. Nothing
      # happens when %argcount <= 0.
      #
      # A missing %argcount (`unvar argcount`) reads as null from the SortedList and
      # Conversions.ToInteger(Nothing) is 0, so nothing happens. Where the C# throws,
      # this raises {Error} instead: a %argcount VB cannot convert (see
      # {VbConversions.to_integer}, e.g. `abc`, `0x2`, `1_0`; `&H2` and `1,000` DO convert)
      # or a missing %k below it (`unvar 2`, or a %argcount above the seeded slots:
      # Conversions.ToString(null) is null, then sPrevious.Length throws a
      # NullReferenceException, so the message is .NET's NRE text, checked with the lab
      # dotnet). 0 corpus uses.
      #
      # @param vars [Variables]
      # @return [void]
      # @raise [Error]
      def shift(vars)
        count = to_integer(vars.local_get('argcount'))
        return unless count.positive?

        vars.local_set('argcount', (count - 1).to_s)
        joined = +''
        previous = ''
        count.downto(1) do |i|
          raise Error, NULL_REFERENCE_MESSAGE if previous.nil?

          joined = "#{previous} #{joined}" unless previous.empty?
          held = vars.local_get(i.to_s)
          vars.local_set(i.to_s, previous)
          previous = held
        end
        vars.local_set('0', trim(joined))
      end

      # Conversions.ToInteger(m_oLocalVarList["argcount"]) (Script.cs:3005 R): nil -> 0,
      # VB's own string grammar, and the .NET message when it throws.
      def to_integer(value) = VbConversions.to_integer(value)

      # C# String.TrimEnd() / Trim(): Unicode whitespace (char.IsWhiteSpace), not
      # Ruby's rstrip (which also eats NUL).
      def trim_end(text) = text.sub(/[[:space:]]+\z/, '')
      def trim(text) = trim_end(text).sub(/\A[[:space:]]+/, '')
    end
  end
end
