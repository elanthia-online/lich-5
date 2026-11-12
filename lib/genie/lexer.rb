# frozen_string_literal: true

module Lich
  module Genie
    # Compiles Genie script source into a flat instruction list + label map: a literal port of
    # Remix Script.cs AppendFile / AddLine / GetFunctionType / AddLabel (Script.cs:3683-4320 R),
    # with Script.PrintError's load-time format (Script.cs:4340-4360 R). See
    # docs/genie-engine/interpreter-spec.md sections 2.1 and 6.
    #
    # The load model:
    #   * the source splits into lines like StreamReader.ReadLine (CR, LF or CRLF; the encoding
    #     from a byte-order mark only at the START of each file -- UTF-8, UTF-16 or UTF-32 -- else
    #     UTF-8; invalid input decodes to U+FFFD; a zero-byte main file or include is "Unable to
    #     load file") and each line is TrimStart()ed -- a trailing space or NUL stays in the
    #     row (Script.cs:3719 R);
    #   * a line starting with `#` is a comment, `<%` opens a JavaScript block that runs to a
    #     line ending with `%>`; its rows (and every row of a `.js` include) are `jsblock` rows
    #     the interpreter collects and runs ({JsRuntime});
    #   * AddLine: the `U+00A4` sentinel splits a row; `%x ...` becomes `setvariable x ...` and
    #     `$x ...` becomes `put #var x ...` with EVERY " = " replaced; a label is a row ending in
    #     `:` with no space; `if_N` becomes `if %argcount >= N`; an inline `if`/`while`/`else`/
    #     `elseif`/`}` splits into its head plus the rest, which goes through AddLine again (no
    #     comment skip there: `if x then #echo y` is the unknown command `#echo y`);
    #   * fatal (the script does not start): an unknown command unless ignorescriptwarnings, an
    #     `if` without " then " (or a block `if` without a trailing " then"), a `while` without a
    #     case-sensitive " do " (or a block `while` without " do"), a missing or empty include;
    #     a duplicate label is a warning (unless ignorescriptwarnings) and the last one wins;
    #   * every error/warning is printed as `[Script error(<row>): <text>]` (an include's row:
    #     `[Script error, <include>(<row>): ...]`; a file error has no row) -- the script's file
    #     name is not known yet while it loads -- and its text is the last %lastscripterror.
    #
    # One Remix quirk kept on purpose: AddLine reuses ONE ScriptLine object for every
    # `U+00A4`-separated part of a row (Script.cs:3804-3806 R), so the instructions it adds
    # are the same object and a later part rewrites the earlier ones (0 corpus rows use it).
    class Lexer
      # A single compiled instruction.
      Instruction = Struct.new(:file_id, :file_row, :content, :function)

      # The compiled program.
      #
      # @!attribute instructions [Array<Instruction>]
      # @!attribute labels [Hash{String=>Integer}] lowercased label name => index
      # @!attribute files [Array<String>] file id => name (0 = the main file)
      # @!attribute warnings [Array<Hash>] unknown rows dropped under ignorescriptwarnings
      # @!attribute messages [Array<String>] the PrintError lines the load printed (warnings)
      # @!attribute last_error [String, nil] the last PrintError text (%lastscripterror)
      Program = Struct.new(:instructions, :labels, :files, :warnings, :messages, :last_error) do
        # @return [String] the main file's name (Script.FileName once loaded)
        def file_name = files.first.to_s
      end

      # The load failed: Remix's AppendFile/AddLine returned false, so LoadFile did not start the
      # script. +lines+ are every PrintError line the load printed, the fatal one last.
      class LoadFailed < Error
        # @return [Array<String>]
        attr_reader :lines
        # @return [String] the fatal error's text (%lastscripterror)
        attr_reader :text

        def initialize(lines, text)
          @lines = lines
          @text = text
          super(lines.last)
        end
      end

      # Genie's non-ASCII inline-newline sentinel (built via an ASCII-producing
      # escape so the source stays ASCII-only).
      MULTILINE_SEP = [0xA4].pack('U')

      # First-word keyword => function symbol (GetFunctionType, Script.cs:4085-4320 R).
      FUNCTION_MAP = {
        'action' => :action, 'include' => :include, 'echo' => :echo,
        'put' => :put, 'send' => :send, 'do' => :do_func, 'exit' => :exit_func,
        'goto' => :goto_func, 'save' => :save,
        'var' => :setvariable, 'vars' => :setvariable, 'variable' => :setvariable,
        'setvar' => :setvariable, 'setvariable' => :setvariable,
        'unvar' => :deletevariable, 'unvariable' => :deletevariable,
        'unsetvar' => :deletevariable, 'unsetvariable' => :deletevariable,
        'counter' => :counter, 'shift' => :shift, 'pause' => :pause, 'delay' => :delay,
        'waitfor' => :waitfor, 'waitforre' => :waitforre, 'waiteval' => :waiteval,
        'match' => :match, 'matchre' => :matchre, 'matchwait' => :matchwait,
        'wait' => :wait, 'move' => :move, 'nextroom' => :nextroom,
        'gosub' => :gosub_func, 'return' => :return_func,
        'if' => :if_func, 'while' => :while_func, 'else' => :else_func, 'elseif' => :elseif_func,
        'timer' => :timer, 'random' => :random, 'math' => :math_func,
        'eval' => :eval_func, 'evaluate' => :eval_func,
        'evalmath' => :evalmath_func, 'evaluatemath' => :evalmath_func,
        'debug' => :debuglevel, 'debuglevel' => :debuglevel,
        'js' => :js, 'javascript' => :js, 'jscall' => :jscall,
        'plugin' => :plugin, 'pluginscript' => :pluginscript,
        '{' => :blockstart, 'begin' => :blockstart, '}' => :blockend, 'end' => :blockend
      }.freeze

      # The C# ScriptFunctions enum name of each function (oFunction.ToString(), the level-15
      # debug line of RunScript, Script.cs:1772-1776 R).
      REMIX_NAMES = {
        do_func: 'dofunc', exit_func: 'exitfunc', goto_func: 'gotofunc', gosub_func: 'gosubfunc',
        return_func: 'returnfunc', if_func: 'iffunc', while_func: 'whilefunc', else_func: 'elsefunc',
        elseif_func: 'elseiffunc', math_func: 'mathfunc', eval_func: 'eval', evalmath_func: 'evalmath',
        unknown: 'empty'
      }.freeze

      # @param source [String, Array<String>] the main file's text, or its lines already split
      # @param file_name [String] the main file's name (Remix's sFriendlyName: "<name>.cmd")
      # @param include_loader [#call, nil] include name => the file's text (nil: not found; "": an
      #   empty file); nil = includes are recorded but not loaded (headless)
      # @param ignore_warnings [Boolean] Config.bIgnoreScriptWarnings (Remix default false)
      # @return [Program]
      # @raise [LoadFailed] when Remix would refuse to load the script
      def self.compile(source, file_name: 'script', include_loader: nil, ignore_warnings: false)
        new(include_loader: include_loader, ignore_warnings: ignore_warnings).compile(source, file_name)
      end

      # StreamReader.ReadLine over a whole file: `new StreamReader(stream)` detects the encoding
      # from a byte-order mark at the start (UTF-8, UTF-16 LE/BE, UTF-32 LE/BE; UTF-8 without one)
      # and drops it (never elsewhere), invalid input decodes to U+FFFD, CR, LF and CRLF each end
      # a line and a final line needs no terminator ({ConfigFile.decode}, the same reader).
      # @param text [String]
      # @return [Array<String>]
      def self.split_lines(text)
        lines = ConfigFile.decode(text.to_s).split(/\r\n|\r|\n/, -1)
        lines.pop if !lines.empty? && lines.last.empty?
        lines
      end

      # @return [Symbol] the function symbol for a keyword (:unknown if none)
      def self.function_type(keyword)
        FUNCTION_MAP.fetch(keyword, :unknown)
      end

      def initialize(include_loader: nil, ignore_warnings: false)
        @include_loader = include_loader
        @ignore_warnings = ignore_warnings
        @instructions = []
        @labels = {}
        @files = []
        @warnings = []
        @messages = []
        @last_error = nil
      end

      # @return [Program]
      # @raise [LoadFailed]
      def compile(source, file_name)
        file_id = add_file(file_name)
        # AppendFile's `fi.Length > 0` for the main file (Script.cs:3709, 3771-3777 R): a typed
        # `;name` of a zero-byte .cmd is refused here (an engine launch already is, ScriptLaunch).
        fatal("Unable to load file: #{file_name}", 0, 0) if source.is_a?(String) && source.empty?
        lines = source.is_a?(Array) ? source : self.class.split_lines(source)
        append_file(lines, file_id)
        Program.new(@instructions, @labels, @files, @warnings, @messages, @last_error)
      end

      private

      def add_file(name)
        @files << name
        @files.length - 1
      end

      # AppendFile's reader loop (Script.cs:3715-3768 R) over one file's lines; +js+ = a `.js`
      # include, all of whose lines are JavaScript rows, closed by a jsblockend row (row -1, no
      # content). In a script file a `<%` line opens a JavaScript block (its rest is a row when not
      # blank) that runs to a line ending with `%>` (that line minus the `%>` is a row, even an
      # empty one) -- even when the `<%` line itself ends with `%>`.
      def append_file(lines, file_id, js: false)
        in_js_block = false
        lines.each_with_index do |raw, i|
          line = Text.net_trim_start(raw)
          next if line.empty?

          if js then add_js_row(line, file_id, i + 1)
          elsif in_js_block
            in_js_block = !line.end_with?('%>')
            add_js_row(in_js_block ? line : line[0...-2], file_id, i + 1)
          elsif line.start_with?('<%')
            add_js_row(line[2..], file_id, i + 1) unless Text.net_trim(line[2..]).empty?
            in_js_block = true
          elsif !line.start_with?('#')
            add_line(line, file_id, i + 1)
          end
        end
        @instructions << Instruction.new(file_id, -1, '', :jsblockend) if js
      end

      # AddLine with bJSBlock (Script.cs:3819-3828 R): the row as it stands, no label or keyword.
      def add_js_row(text, file_id, file_row)
        @instructions << Instruction.new(file_id, file_row, text, :jsblock)
      end

      # AddLine (Script.cs:3802-4083 R).
      def add_line(text, file_id, file_row)
        line = Instruction.new(file_id, file_row, nil, nil) # one object for every part (see class doc)
        text.split(MULTILINE_SEP).each do |part|
          next if Text.net_trim(part).empty?

          part = rewrite_prefix(part)
          line.content = part
          if Text.net_trim_end(part).end_with?(':') && !Text.net_trim(part).include?(' ')
            name = Text.net_trim_end(part)
            add_label(name[0...-1], file_id, file_row)
            line.function = :label
          else
            next unless add_row(line, part, file_id, file_row)
          end
          @instructions << line
        end
      end

      # `%x = y` -> `setvariable x y`; `$x = y` -> `put #var x y` (every " = ", String.Replace).
      def rewrite_prefix(row)
        row = "setvariable #{row[1..]}".gsub(' = ', ' ') if row.start_with?('%')
        row = "put #var #{row[1..]}".gsub(' = ', ' ') if row.start_with?('$')
        row
      end

      # The non-label arm of AddLine. @return [Boolean] whether +line+ is added as it stands
      def add_row(line, row, file_id, file_row)
        keyword = Text.net_downcase(Text.keyword_string(row))
        argument = Text.argument_string(row)
        if keyword.start_with?('if_')
          line.content = if Text.net_downcase(argument).start_with?('then')
                           "if %argcount >= #{keyword[3..]} #{argument}"
                         else
                           "if %argcount >= #{keyword[3..]} then #{argument}"
                         end
          keyword = 'if'
          argument = Text.argument_string(line.content)
        end
        line.function = self.class.function_type(keyword)
        structural(line, row, argument, file_id, file_row)
      end

      # AddLine's switch (Script.cs:3882-4078 R). @return [Boolean] whether to add +line+
      def structural(line, row, argument, file_id, file_row)
        case line.function
        when :include then include_file(argument, file_id)
        when :pluginscript then false # EvalPluginScript: no plugins, nothing appended
        when :if_func then split_if(line, row, argument, file_id, file_row)
        when :while_func then split_while(line, row, argument, file_id, file_row)
        when :else_func, :elseif_func, :blockend then split_prefixed(line, argument, file_id, file_row)
        when :unknown then unknown_command(row, file_id, file_row)
        else true
        end
      end

      # The iffunc arm (Script.cs:3923-3961 R): a row ending in " then" opens a block; otherwise
      # the head up to the first " then " is added and the rest goes through AddLine.
      def split_if(line, row, argument, file_id, file_row)
        lower = Text.net_downcase(argument)
        return true if lower.end_with?(' then')

        at = lower.index(' then ')
        return fatal("Invalid IF statement: #{row}", file_id, file_row) if at.nil? || argument.length <= at + 6

        cut = Text.net_downcase(line.content).index(' then ') + 6
        return fatal("Invalid IF statement: #{row}", file_id, file_row) if cut >= line.content.length

        line.content = Text.net_trim(line.content[0...cut])
        @instructions << line
        add_line(Text.net_trim(argument[(at + 6)..]), file_id, file_row)
        false
      end

      # The whilefunc arm (Script.cs:3963-4004 R): like `if`, but " do " is found
      # CASE-SENSITIVELY in the argument and the head is LOWERCASED (`while %X do ...` tests %x).
      def split_while(line, row, argument, file_id, file_row)
        return true if Text.net_downcase(argument).end_with?(' do')

        at = argument.index(' do ')
        return fatal("Invalid WHILE statement: #{row}", file_id, file_row) if at.nil? || argument.length <= at + 4

        lower = Text.net_downcase(line.content)
        cut = lower.index(' do ') + 4
        return fatal("Invalid WHILE statement: #{row}", file_id, file_row) if cut >= line.content.length

        line.content = Text.net_trim(lower[0...cut])
        @instructions << line
        add_line(Text.net_trim(argument[(at + 4)..]), file_id, file_row)
        false
      end

      # The elsefunc / elseiffunc / blockend arms (Script.cs:4006-4065 R): with an argument, the
      # head ("else" / "}") is added and the rest goes through AddLine ("if <rest>" for elseif).
      def split_prefixed(line, argument, file_id, file_row)
        return true if argument.empty?

        tail = Text.net_trim(argument)
        if line.function == :blockend
          line.content = '}'
        else
          tail = "if #{tail}" if line.function == :elseif_func
          line.content = 'else'
          line.function = :else_func
        end
        @instructions << line
        add_line(tail, file_id, file_row)
        false
      end

      # The empty arm (Script.cs:4070-4078 R).
      def unknown_command(row, file_id, file_row)
        return fatal("Unknown script command: #{row}", file_id, file_row) unless @ignore_warnings

        @warnings << { file_id: file_id, file_row: file_row, content: row }
        false
      end

      # AddLabel (Script.cs:4322-4338 R): lowercased and trimmed; a duplicate is a warning
      # unless ignorescriptwarnings, and the last one wins.
      def add_label(name, file_id, file_row)
        label = Text.net_trim(Text.net_downcase(name))
        print_error("Replacing duplicate label: #{label}", file_id, file_row) if @labels.key?(label) && !@ignore_warnings
        @labels[label] = @instructions.length
      end

      # The include arm (Script.cs:3884-3906 R) + AppendFile (Script.cs:3683-3800 R): an include
      # already in the file list (exact name, the main file included) is skipped; a `.js` include's
      # lines are JavaScript rows. A missing file is "File not found", an
      # empty one "Unable to load file" (FileInfo.Length throws / is 0, Script.cs:3709, 3775-3784 R).
      # @return [false] the include row itself is never added
      def include_file(name, _file_id)
        return false if @files.include?(name)

        included = add_file(name)
        return false unless @include_loader

        # new FileInfo(path) throws ArgumentException on a NUL, which AppendFile does not catch:
        # Remix's script never starts (a host exception, nothing printed; genieflow probe). Ours
        # refuses the load with the exception's text rather than raise on the script thread.
        fatal("Null character in path. (Parameter 'path')", 0, 0) if name.include?("\0")

        source = @include_loader.call(name)
        fatal("File not found: #{name}", 0, 0) if source.nil?
        fatal("Unable to load file: #{name}", 0, 0) if source.empty?
        append_file(self.class.split_lines(source), included, js: name.downcase.end_with?('.js'))
        false
      end

      # A load error: printed, and the load stops.
      # @raise [LoadFailed]
      def fatal(text, file_id, file_row)
        print_error(text, file_id, file_row)
        raise LoadFailed.new(@messages.dup, text)
      end

      # Script.PrintError while loading (Script.cs:4340-4360 R): the file name is still "" (LoadFile
      # sets it only after AppendFile succeeded, Script.cs:1982-1985 R).
      def print_error(text, file_id, file_row)
        @last_error = text
        @messages << self.class.error_line(text, file_id: file_id, file_row: file_row, files: @files, file_name: '')
      end

      class << self
        # Script.PrintError's line (Script.cs:4340-4360 R): "[Script error", " in <file>" once the
        # file name is known, ", <include>" for a row of another file, "(<row>)" for a row, then
        # ": <text>]".
        # @param text [String]
        # @param file_id [Integer]
        # @param file_row [Integer]
        # @param files [Array<String>] m_oScriptFiles
        # @param file_name [String] m_sFileName
        # @param kind [String] "Javascript error" for PrintJSError (Script.cs:4362-4386 R)
        # @return [String]
        def error_line(text, file_id:, file_row:, files:, file_name:, kind: 'Script error')
          line = +"[#{kind}"
          line << " in #{file_name}" unless file_name.empty?
          other = file_id.to_i.positive? ? files[file_id].to_s : file_name
          line << ", #{other}" if other != file_name
          line << "(#{file_row})" if file_row.to_i.positive?
          line << ": #{text}]"
        end
      end
    end
  end
end
