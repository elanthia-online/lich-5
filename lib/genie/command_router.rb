# frozen_string_literal: true

module Lich
  module Genie
    # No-op script-control port (the default). Used headless (specs) or when no host
    # script system is wired: there are no running scripts to enumerate and every
    # lifecycle action is a silent no-op, so `#script abort/pause/...` do nothing.
    class NullScriptControl
      def names = []
      def abort(_name) = nil
      def pause(_name) = nil
      def resume(_name) = nil
      def pauseorresume(_name) = nil
      def reload(_name) = nil
      def debug(_level, _name) = nil
    end

    # Runs Genie `#command` rows: the arms of Remix Core/Command.cs `ParseCommand`
    # (Command.cs:255-2535 R). The row pipeline around them -- the separator split, the `-`
    # quick send, `.script` launches, sending plain rows -- is {ParseCommand}, which this
    # router owns ({#parse_command}, {#run}) and which calls {#command} for each `#` row.
    #
    # Three kinds of arm, mirroring Genie:
    #   * the engine's own state: the variables (`#var`/`#tvar`/`#svar`/`#unvar`/`#math`, the
    #     listings), the global lists Remix keeps on Globals ({Lists}: `#trigger`, `#class`,
    #     `#gag`, `#sub`, `#alias` and their load/save/clear/listing forms), `#config` (the
    #     settings the engine reads, and SetSetting's echoes), the timed queues (`#send`/`#do`/
    #     `#queue`/`#event`), `#echo`, `#log`, computation (`#eval`/`#evalmath`/`#if`/`#random`),
    #     `#put`, `#parse`, `#script`;
    #   * front-end effects (`#highlight`, `#macro`, `#preset`, `#window`, `#name`, `#layout`,
    #     sounds, the launcher/connection commands ...): a self-describing hook via {#emit}
    #     (docs/genie-engine/hook-protocol.md), after the echo Remix's arm itself prints, if any;
    #   * anything else is Remix's default arm: a `#RRGGBB` row is its own result, every other
    #     row echoes "Unknown command: <row>" (Command.cs:2518-2530 R; `#ping`, `# echo`, `#`).
    #
    # Faithful behaviors preserved from Command.cs:
    #   * the keyword is ParseArgs(row)[0] minus its first char, lower-cased (Command.cs:259-265
    #     R): `# echo x` has the keyword "" and is unknown;
    #   * a `#command`'s **result string** (`#evalmath`/`#eval`/`#if`/`#random`/`#cr` produce one)
    #     is never sent to the game: it only becomes a value where an arm re-parses its arguments
    #     (ParseAllArgs: `#var x #evalmath 1+1`) or an #if branch;
    #   * each arm expands `$globals` itself where Remix calls Globals.ParseGlobalVars (once,
    #     at that point -- a script row has already been expanded by the script, so a value
    #     holding `$x` text is expanded again, exactly like Remix), and the raw arms (#class,
    #     #alias, #unvar, #queue, #goto, ...) take their arguments as given;
    #   * an arm that indexes an argument Remix assumes is there (`#log`, `#icon`, `#unvar` with
    #     none) faults, which ends that ParseCommand quietly ({INDEX_FAULT}).
    class CommandRouter
      # The message of the ArgumentOutOfRangeException an arm's oArgs[n] throws past the end;
      # the fault ends the ParseCommand (genieflow `swallowed-fault`, on `#log`).
      INDEX_FAULT = "Index was out of range. Must be non-negative and less than the size of the collection. (Parameter 'index')"
      # Environment.NewLine: Remix is a Windows build (`#cr`'s result, Command.cs:831-835 R).
      NEWLINE = "\r\n"
      # Utility.RandomNumber's Random.Next(min, max + 1) fault (Utility.cs:251-255 R).
      RANDOM_SWAPPED = "'minValue' cannot be greater than maxValue. (Parameter 'minValue')"
      # The preset keys Remix's Globals.Presets knows (`#preset` with another key echoes
      # "Invalid #preset keyword.", Command.cs:1859-1867 R; the keys genieflow's ListPresets shows).
      PRESET_KEYS = %w[
        automapper.here automapper.line automapper.lineclimb automapper.linego automapper.linestump
        automapper.node automapper.panel automapper.path castbar concentration creatures familiar health
        inputother inputuser mana roomdesc roomname roundtime scriptecho speech spirit stamina thoughts
        ui.button ui.menu ui.menu.checked ui.menu.highlight ui.status ui.textbox ui.window whispers
      ].freeze

      # Enum.GetNames(typeof(KeyCode.Keys)) (Utility/KeyCode.cs R), what `#keys` lists (ListKeys,
      # Command.cs:2995-3000 R) -- the order genieflow prints from Remix's own enum.
      KEY_NAMES = %w[
        Cancel Back Tab LineFeed Clear Enter Return ShiftKey ControlKey Menu Pause Capital CapsLock Escape
        Space Prior PageUp PageDown Next End Home Left Up Right Down Select Print Execute Snapshot
        PrintScreen Insert Delete Help D0 D1 D2 D3 D4 D5 D6 D7 D8 D9 A B C D E F G H I J K L M N O P Q R S T
        U V W X Y Z LWin RWin Apps NumPad0 NumPad1 NumPad2 NumPad3 NumPad4 NumPad5 NumPad6 NumPad7 NumPad8
        NumPad9 Multiply Add Separator Subtract Decimal Divide F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 F13 F14
        F15 F16 F17 F18 F19 F20 F21 F22 F23 F24 NumLock Scroll LShiftKey RShiftKey LControlKey RControlKey
        LMenu RMenu BrowserBack BrowserForward BrowserRefresh BrowserStop BrowserSearch BrowserFavorites
        BrowserHome VolumeMute VolumeDown VolumeUp MediaNextTrack MediaPreviousTrack MediaStop MediaPlayPause
        LaunchMail SelectMedia LaunchApplication1 LaunchApplication2 OemSemicolon Oemplus Oemcomma OemMinus
        OemPeriod OemQuestion Oemtilde OemOpenBrackets OemPipe OemCloseBrackets OemQuotes Oem8 OemBackslash
        ProcessKey Attn Crsel Exsel EraseEof Play Zoom OemClear Shift Control Alt
      ].freeze

      # @param vars [Variables] local/global variable store
      # @param eval [Eval] boolean/string expression evaluator (for #eval/#if)
      # @param echo [#call] local echo sink
      # @param send [#call] callable(text): a command for the game, after ParseCommand's
      #   SendTextToGame / ClassCommand_SendText step (Game.SendText)
      # @param hooks [#emit, nil] front-end effect sink
      # @param mover [#call, nil] callable(room_arg) that walks to a room (#goto)
      # @param script_control [#names, #abort, #pause, #resume, #pauseorresume,
      #   #reload, #debug, nil] host script-registry port for `#script` (defaults to a no-op)
      # @param script_name [String, nil] name of the script issuing commands
      # @param parse [#call, nil] callable(text) that delivers a `#parse` line to the
      #   global #triggers and the scripts (FormMain.ClassCommand_ParseText ->
      #   ParseTriggers, FormMain.cs:4659-4667, 4425-4512 R); nil = nowhere (headless)
      # @param var_changed [#call, nil] callable(name) raised after `#var`/`#tvar`/`#svar` set a
      #   global and after a successful `#math`, with "$" + the name argument (Command.
      #   VariableChanged, Command.cs:931-933, 952-954, 983-985, 1040-1042 R; `#unvar`, `#var
      #   clear|load` raise nothing) -- the host's VariableDispatch.broadcast; nil = nowhere
      # @param launch [#call, nil] callable(name, args): a `.name args` row (RunScript)
      # @param queue [CommandQueue, #call, nil] the session's timed queue for `#send`/`#do`/
      #   `#queue`/`#event` and the `-` quick send (Globals.CommandQueue + Globals.Events), or a
      #   callable returning the current one, read at each use; nil = a private one nobody drains
      # @param queue_owner [Object, nil] the issuing script's host handle, stored with every item
      #   this router queues ({CommandQueue::Item#owner}); nil = none
      # @param input_box [#call, nil] callable(text): a sent text holding `@` or `\x`
      #   (SendTextInputBox, FormMain.cs:4378-4384 R); nil = the front-end `inputbox` effect
      # @param globals [#call, nil] callable(text) => Globals.ParseGlobalVars(text); nil = a
      #   {Substitution#expand_globals} over +vars+
      # @param lists [Lists, nil] the global lists (#triggers, classes, gags/subs, aliases) and
      #   their config dir; nil = a private set with no files (headless)
      # @param log_dir [#call, nil] callable => the directory `#log` writes to; nil = `#log`
      #   writes nothing
      # @param directory [#call, nil] callable(path) => LocalDirectory.ValidateDirectory's message
      #   for a `#config` directory key; nil = +lists+' ({Lists#validate_directory})
      # @param aliases [#call, nil] callable => the AliasList ParseCommand expands (Hash-like);
      #   nil = +lists+' ({Lists#aliases})
      # @param wall_clock [#call, nil] callable => Remix's DateTime.Now (a Time, read in its own
      #   offset) for `#log`'s daily file name and header; nil = Time.now (the machine's local time)
      def initialize(vars:, eval:, echo:, send:, hooks:, mover: nil, script_control: nil, script_name: nil, parse: nil,
                     var_changed: nil, launch: nil, queue: nil, queue_owner: nil, input_box: nil, globals: nil,
                     lists: nil, log_dir: nil, directory: nil, aliases: nil, wall_clock: nil)
        @vars = vars
        @eval = eval
        @echo = echo
        @send = send
        @hooks = hooks
        @mover = mover || ->(_room) {}
        @script_control = script_control || NullScriptControl.new
        @script_name = script_name
        @parse = parse || ->(_text) {}
        @var_changed = var_changed || ->(_name) {}
        @queue_source = CommandQueue.source(queue)
        @queue_owner = queue_owner
        @globals = globals || Substitution.new(variables: vars).method(:expand_globals)
        @lists = lists || Lists.new
        @log_dir = log_dir
        @wall_clock = wall_clock || -> { Time.now }
        @directory = directory || ->(path) { @lists.validate_directory(path) }
        @parser = ParseCommand.new(
          router: self, game: ->(text) { @send.call(text) }, launch: launch || ->(_name, _args) {},
          globals: @globals,
          input_box: input_box || ->(text) { emit('inputbox', 'text' => text) },
          chars: -> { config }, aliases: aliases || -> { @lists.aliases }
        )
      end

      # @return [Lists]
      attr_reader :lists

      # @return [CommandQueue] the queue `#send`/`#do`/`#queue`/`#event` fill (looked up now)
      def queue
        @queue_source.call
      end

      # Command.ParseCommand on +text+ ({ParseCommand#call}); a fault propagates.
      # @return [String] the last row's result
      def parse_command(text, send_to_game: false, parse_quick_send: true)
        @parser.call(text, send_to_game: send_to_game, parse_quick_send: parse_quick_send)
      end

      # A top-level, un-awaited ParseCommand ({ParseCommand#run}): a fault ends it silently.
      # @return [void]
      def run(text, send_to_game:)
        @parser.run(text, send_to_game: send_to_game)
      end

      # A typed / #trigger-body / queued command line: ParseCommand(text, bSendToGame: true),
      # top level.
      # @param line [String]
      # @return [void]
      def route(line)
        run(line, send_to_game: true)
      end

      # .NET double.Parse of a run of digits and dots (Command.cs:2582, 2621 R).
      # @param number [String] digits and dots, not "."
      # @return [Float]
      # @raise [Error] "The input string '...' was not in a correct format." (FormatException)
      def self.parse_double(number)
        raise Error, "The input string '#{number}' was not in a correct format." unless number.match?(/\A(?:\d+\.?\d*|\.\d+)\z/)

        Float(number)
      end

      # One `#command` row (ParseCommand's command-char arm, Command.cs:255-2535 R).
      # @param row [String] the row as split (sRow), its trimmed text starting with the command char
      # @return [String] the arm's result ("" for side-effect-only commands)
      # @raise [Error] an arm's fault (ParseArgs on a malformed row, a missing argument, ...)
      def command(row)
        row = row.to_s
        args = Text.parse_args(row) # ParseArgs(sRow) (Command.cs:260 R)
        return '' if args.empty? || args[0].empty?

        dispatch(Text.net_downcase(args[0][1..].to_s), args, row)
      end

      # Globals.ParseGlobalVars.
      # @param text [String]
      # @return [String]
      def expand_globals(text)
        @globals.call(text.to_s)
      end

      # The live settings ({GameState::Config}): the variables' capture, else the defaults.
      # @return [GameState::Config]
      def config
        state = @vars.respond_to?(:game_state) ? @vars.game_state : nil
        state.respond_to?(:config) ? state.config : GameState::DEFAULT_CONFIG
      end

      # The SendTextToGame / ClassCommand_SendText step for a text a caller already decided
      # to send ({ParseCommand#send_text_to_game}).
      # @param text [String]
      # @return [void]
      def send_text_to_game(text)
        @parser.send_text_to_game(text)
      end

      private

      # The arm for +keyword+ (Command.cs:266-2531 R). +row+ is sRow.
      def dispatch(keyword, args, row)
        case keyword
        when 'echo' then do_echo(args)
        when 'link' then emit_link(args)
        when 'icon' then emit('icon', 'file' => expand_globals(arg!(args, 1)))
        when 'log' then do_log(args)
        when 'connect' then do_connect(args, row)
        when 'img', 'image' then do_image(args)
        when 'lc', 'lconnect', 'lichconnect' then do_lich_connect(args, row)
        when 'save' then persist_command('Saved', args, row)
        when 'load' then persist_command('Loaded', args, row)
        when 'nop', 'push' then '' # Command.cs:825-829, 865-872 R
        when 'cr' then NEWLINE
        when 'send' then queue_command(args, restricted: false)
        when 'do' then queue_command(args, restricted: true)
        when 'put' then do_put(args)
        when 'var', 'vars', 'variable', 'setvar', 'setvariable' then var_command(args, row)
        when 'tvar', 'tempvar', 'tempvariable' then args.length < 3 ? list_variables('') : set_variable(args, persist: false)
        when 'svar', 'servervar', 'servervariable' then args.length < 3 ? list_variables('') : set_variable(args, persist: false, server: true)
        when 'unvar', 'unvariable', 'unsetvar', 'unsetvariable' then delete_variable(args)
        when 'eval' then args.length > 1 ? @eval.eval_string(expand_globals(Text.array_to_string(args, 1))) : ''
        when 'math' then do_math(args)
        when 'evalmath' then args.length > 1 ? eval_math(expand_globals(Text.array_to_string(args, 1))) : ''
        when 'if' then do_if(args)
        when 'event', 'events' then do_event(args)
        when 'que', 'queue' then do_queue(args)
        when 'alias', 'aliases' then alias_command(args, row)
        when 'unalias', 'unclass' then remove_alias(args) # `#unclass` removes an ALIAS (Command.cs:1356-1364 R)
        when 'class', 'classes' then class_command(args, row)
        when 'trigger', 'triggers', 'action', 'actions' then trigger_command(args, row)
        when 'untrigger' then remove_trigger(args)
        when 'random' then do_random(args)
        when 'config', 'set', 'setting', 'settings' then config_command(args, row)
        when 'parse' then do_parse(Text.argument_string(row))
        when 'beep', 'bell' then emit('beep', {})
        when 'play', 'playwave', 'playsound' then emit_sound(Text.argument_string(row))
        when 'macro', 'macros' then macro_command(args, row)
        when 'sub', 'subs', 'substitute' then sub_command(args, row)
        when 'unsub', 'unsubs', 'unsubstitute' then remove_sub(args)
        when 'gag', 'gags', 'squelch', 'ignore', 'ignores' then gag_command(args, row)
        when 'ungag', 'unsquelch', 'unignore', 'unignores' then remove_gag(args)
        when 'preset', 'presets' then preset_command(args, row)
        when 'highlight', 'highlights' then highlight_command(args, row)
        when 'colors', 'colours' then list_colors
        when 'name', 'names' then name_command(args, row)
        when 'unname' then emit_unname(args)
        when 'flash' then emit('flash', {})
        when 'script' then do_script(args, row)
        when 'layout' then emit_layout(args)
        when 'window' then window_command(args, row)
        # the mapper aliases (Command.cs:2441-2449 R: the row becomes `#mapper <keyword> ...`): the
        # goto family is the AutoMapper goto arm (AutoMapper.cs:1140-1144 R); `#path` needs Genie's
        # own map path text (GetNodePath, AutoMapper.cs:1435-1450, 1579-1593 R) -- a no-op, tracked
        when 'goto', 'go', 'g', 'walk', 'walkto' then goto_room(mapper_argument(row))
        when 'path', 'mapper', 'map', 'm' then '' # reset/etc: no-op (we route movement via go2/DRC)
        when 'keys' then list_keys
        when 'clear' then emit('clear', generic(args, row).merge('window' => expand_globals(parse_all_args(args, 1))))
        when 'status', 'statusbar' then status_bar(keyword, args, row)
        when 'comment' then window_title(args, row)
        when 'playsystem', 'disconnect', 'exit', 'browser', 'unmacro', 'edit', 'help',
             'profile', 'plugin', 'xml', 'raw', 'ls', 'lichsettings'
          emit_generic(keyword, args, row)
        else unknown(args, row)
        end
      end

      # The default arm (Command.cs:2518-2530 R): a `#RRGGBB` first argument makes the row its
      # own result; anything else echoes "Unknown command: <row>" (sResult "").
      def unknown(args, row)
        first = Text.net_trim(args[0].to_s)
        return row if first.start_with?('#') && ColorCode.hex_string?(first)

        @echo.call("Unknown command: #{row}")
        ''
      end

      # oArgs[i], or the ArgumentOutOfRangeException an arm that assumes it is there throws.
      def arg!(args, index)
        raise Error, INDEX_FAULT if index >= args.length

        args[index].to_s
      end

      def lower(text) = Text.net_downcase(text.to_s)

      # --- engine-side: #config --------------------------------------------

      # `#config` / `#set` / `#setting` / `#settings` (Command.cs:1457-1528 R): with a key and a
      # value, Config.SetSetting(key, ArrayToString(args, 2)); with a lone key that is not
      # load/save/edit, SetSetting(key) with an empty value. SetSetting's messages are echoed
      # ({ConfigSetting}: "Set key: value", "Don't forget to #save config"), its exception becomes
      # "Invalid syntax: <row>" + the message; the keys the engine reads take the value
      # ({GameState::Config}). `#config load|save` echo "Settings Loaded|Saved"; the listing,
      # `edit` and the settings file itself are the front end's (hook).
      def config_command(args, row)
        if args.length <= 1 then emit('config', 'action' => 'list')
        elsif args.length == 2
          case lower(args[1])
          when 'load' then persist_kind('Settings', 'Loaded')
          when 'save' then persist_kind('Settings', 'Saved')
          when 'edit' then emit('config', 'action' => 'edit')
          else set_setting(args[1].to_s, '', row)
          end
        else
          set_setting(args[1].to_s, Text.array_to_string(args, 2), row)
        end
        ''
      end

      def set_setting(key, value, row)
        messages = ConfigSetting.set(key, value, file_exists: ->(path) { File.exist?(path) }, directory: @directory)
        messages.each { |message| @echo.call(message) }
        apply_setting(key, value)
        emit('config', 'key' => key, 'value' => value)
      rescue Error => e
        @echo.call("Invalid syntax: #{row}")
        @echo.call(e.message)
      end

      def apply_setting(key, value)
        state = @vars.respond_to?(:game_state) ? @vars.game_state : nil
        state.apply_setting(key, value) if state.respond_to?(:apply_setting)
      end

      # --- engine-side: #parse ---------------------------------------------

      # `#parse <text>` (Command.cs:1530-1535 R): ParseGlobalVars of the argument, then
      # ParseLine -> ClassCommand_ParseText, which ignores a blank line and otherwise runs
      # ParseTriggers(text, bBufferWait: false) (FormMain.cs:4659-4667 R). Never reaches
      # the game or the front end. Result "" (sResult = "").
      def do_parse(argument)
        text = expand_globals(argument)
        @parse.call(text) unless Text.net_trim(text).empty?
        ''
      end

      # --- engine-side: #script host control -------------------------------

      # Genie lifecycle subcommands routed to the host script registry (the injected
      # script-control port). The listings (list/vars/trace/explorer) stay front-end effects.
      LIFECYCLE_SCRIPT_ACTIONS = {
        'abort' => :abort, 'pause' => :pause, 'resume' => :resume,
        'pauseorresume' => :pauseorresume, 'reload' => :reload
      }.freeze

      # #script {abort|pause|resume|pauseorresume|reload} [all [except <name>] | <name>]
      # (Command.cs:2167-2267 R -> FormMain.Command_ScriptAbort/Pause/Resume/...), and `#script
      # debug|debuglevel <level> [all|<name>]` (Command_ScriptDebugLevel, FormMain.cs:6083 R:
      # Conversions.ToInteger(StringToDouble(level)) to every listed match, all = every script).
      # The name/"all"/"except" resolution mirrors FormMain; the actual kill/pause/unpause is the
      # host port's job.
      def do_script(args, row)
        return emit_generic('script', args, row) if args.length < 2

        sub = lower(args[1])
        return script_debug(args) if %w[debug debuglevel].include?(sub)

        action = LIFECYCLE_SCRIPT_ACTIONS[sub]
        return emit_generic('script', args, row) if action.nil?

        # EventScriptAbort?.Invoke(ParseGlobalVars(ArrayToString(oArgs, 2))) (Command.cs:2176-2200 R)
        apply_script_action(action, expand_globals(Text.array_to_string(args, 2)))
      end

      def script_debug(args)
        return '' unless args.length > 2

        level = VbConversions.double_to_integer(Numeric.string_to_double(args[2].to_s))
        spec = expand_globals(Text.array_to_string(args, 3))
        spec = '' if lower(spec) == 'all'
        @script_control.names.map(&:to_s).reject(&:empty?).uniq.each do |name|
          @script_control.debug(level, name) if spec.empty? || name == spec
        end
        ''
      end

      # --- engine-side: the timed CommandQueue ------------------------------

      # `#send` / `#do` (Command.Send / Command.Do, Command.cs:2561-2640 R): the argument is
      # ParseGlobalVars(ParseAllArgs(oArgs, 1)) -- so it is re-parsed first, and `#send -1 x`
      # queues `x` through the inner quick send and then nothing -- then `clear` empties the
      # queue, else a leading run of digits and dots is the delay (double.Parse: `1.2.3`
      # throws, ending the whole ParseCommand) and the rest, Trim()med, is queued if non-blank.
      # `#send` waits out roundtime; `#do` also waits while webbed or stunned.
      def queue_command(args, restricted:)
        return '' if args.length < 2

        text = expand_globals(parse_all_args(args, 1))
        if text.downcase == 'clear'
          queue.clear
          return ''
        end

        number = text[/\A[0-9.]*/]
        delay = 0.0
        if !number.empty? && number != '.'
          text = Text.net_trim(text[number.length..])
          delay = self.class.parse_double(number)
        end
        return '' if Text.net_trim(text).empty?

        queue.add(delay, text, wait_rt: true, wait_webbed: restricted, wait_stunned: restricted, owner: @queue_owner)
        ''
      end

      # `#queue` / `#que` (Command.cs:1134-1162 R): `#queue <delay> <command...>` queues
      # ArrayToString(oArgs, 2) unexpanded with no restriction (StringToDouble: -1 for a bad
      # delay, so it goes at once); `#queue clear` empties the queue; anything else lists it.
      def do_queue(args)
        if args.length > 2
          action = Text.array_to_string(args, 2)
          queue.add(Numeric.string_to_double(args[1].to_s), action, wait_rt: false, owner: @queue_owner) unless Text.net_trim(action).empty?
        elsif args.length == 2 && lower(args[1]) == 'clear'
          queue.clear
        else
          list_queue(Text.array_to_string(args, 1))
        end
        ''
      end

      # ListCommandQueue (Command.cs:3588-3626 R): "(delay) action" per item containing the
      # filter (String.Contains, ordinal), or "None.". Remix wraps the header in newlines; the
      # echo port takes single lines, so the blank line before it is not reproduced.
      def list_queue(pattern)
        @echo.call('Active command queue: ')
        @echo.call("Filter: #{pattern}") unless pattern.empty?
        shown = queue.items.select { |item| pattern.empty? || item.action.include?(pattern) }
        shown.each { |item| @echo.call("(#{Numeric.format_double(item.delay.to_f)}) #{item.action}") }
        @echo.call('None.') if shown.empty?
      end

      # `#event` / `#events` (Command.cs:1103-1132 R): `#event <seconds> <action...>` adds
      # ArrayToString(oArgs, 2), unexpanded, to the event queue (StringToDouble of the seconds;
      # {CommandQueue#add_event}); `#event clear` empties it; anything else lists it.
      def do_event(args)
        if args.length > 2
          action = Text.array_to_string(args, 2)
          queue.add_event(Numeric.string_to_double(args[1].to_s), action) unless Text.net_trim(action).empty?
        elsif args.length == 2 && lower(args[1]) == 'clear'
          queue.clear_events
        else
          list_events(Text.array_to_string(args, 1))
        end
        ''
      end

      # ListEvents (Command.cs:3548-3586 R): "(<due DateTime>) action" per item containing the
      # filter, or "None.".
      def list_events(pattern)
        listing('Active event queue: ', pattern) do
          queue.events.select { |item| pattern.empty? || item.action.include?(pattern) }
                      .map { |item| "(#{LogFile.date_time(item.due)}) #{item.action}" }
        end
      end

      # ParseAllArgs (Command.cs:2857-2898 R): the arguments from +start+ joined with single
      # spaces; unless that starts with " ." (a script launch kept as text), it goes back
      # through ParseCommand (not sent) and the LAST row's result is the value -- so `{a;b}`
      # is "b", `#evalmath 1+2` is "3", `-1 x` queues x and is "", `x;.helper` launches helper.
      # @return [String]
      def parse_all_args(args, start, parse_quick_send: true)
        joined = (args[start..] || []).compact.map { |arg| " #{arg}" }.join
        return '' if joined.empty?
        return joined[1..] if joined.start_with?(' .')

        parse_command(joined[1..], parse_quick_send: parse_quick_send)
      end

      # Command_ScriptAbort / Pause / Resume / PauseOrResume / Reload walk the script list in
      # order and act on every match, the caller included where it stands (FormMain.cs:5783-6080
      # R; a self-abort is cooperative, so the rest of an `abort all` still runs).
      # The host port acts on every listed script of a name, so each name is handed over once:
      # two listed copies are each paused/toggled once, not twice.
      def apply_script_action(action, spec)
        target, except = parse_script_spec(spec)
        matching_scripts(target, except).uniq.each { |name| @script_control.public_send(action, name) }
        ''
      end

      # Port of FormMain's "all"/"except"/exact-name resolution (Command_ScriptAbort):
      # split off `except <name>`, then an "all " prefix (or an empty spec) means "all
      # scripts" (target ""), otherwise the trimmed spec is an exact script name.
      # Returns [target, except]. NOTE: `except` is trimmed here (Genie left it raw);
      # our args arrive as clean single-space-joined tokens, so trimming only guards
      # against an accidental trailing space stranding the script meant to survive.
      def parse_script_spec(spec)
        text = spec.to_s
        except = ''
        idx = text.downcase.index('except ')
        if idx&.positive?
          except = text[(idx + 7)..].to_s.strip
          text = text[0...idx].rstrip
        end
        target = "#{text} ".downcase.start_with?('all ') ? '' : text.strip
        [target, except]
      end

      # Names of running host scripts to act on: empty target => all; a set except
      # name is always spared. Exact-name match (case-sensitive), like Genie.
      def matching_scripts(target, except)
        @script_control.names.map(&:to_s).reject(&:empty?).select do |name|
          (target.empty? || name == target) && (except.empty? || name != except)
        end
      end

      # #goto <room>: walk there (Genie automapper). Room-number translation +
      # the actual walk are the injected mover's job (Lich-side); see the glue. A bare `#goto`
      # reaches it too: the goto arm's "please specify" echo and $destination 0
      # (AutoMapper.cs:1196-1200 R; GotoWalk.go).
      def goto_room(argument)
        @mover.call(argument.to_s)
        ''
      end

      # The AutoMapper's sArg for `#mapper <keyword> <rest>` (AutoMapper.cs:955-965 R): everything
      # after the first space that follows the keyword, inner spaces kept ("#walkto  15" -> " 15"),
      # unlike GetArgumentString's trimmed argument.
      # @param row [String] sRow
      # @return [String]
      def mapper_argument(row)
        body = Text.net_trim(row)
        idx = body.index(' ')
        idx ? body[(idx + 1)..] : ''
      end

      # --- engine-side: variables ------------------------------------------

      # #var (Command.cs:874-937 R). Three or more args set a SaveToFile global; with
      # exactly two, `load`/`save`/`clear` act on the store (the echo comes first, as
      # in Remix), `edit` opens the front end's editor, and anything else is the variable
      # listing filtered by ArrayToString(oArgs, 1); with one, the whole listing. So
      # `#var save extra` sets a variable named "save", exactly like Remix.
      def var_command(args, row)
        return set_variable(args, persist: true) if args.length >= 3
        return list_variables('') if args.length < 2

        case lower(args[1])
        when 'load' then persist_kind('Variables', 'Loaded')
        when 'save' then persist_kind('Variables', 'Saved')
        when 'clear'
          @echo.call('Variables Cleared')
          @vars.global_clear_user
        when 'edit' then emit_generic('var', args, row)
        else list_variables(Text.array_to_string(args, 1))
        end
        ''
      end

      # ListVariables (Command.cs:3002-3079 R; {Variables#listing}).
      def list_variables(pattern)
        @vars.listing(pattern).each { |line| @echo.call(line) }
        ''
      end

      # `#save` / `#load` keyword -> the list label Remix echoes (Command.cs:488-822 R).
      PERSIST_KINDS = {
        'var' => 'Variables', 'vars' => 'Variables', 'variable' => 'Variables',
        'setvar' => 'Variables', 'setvariable' => 'Variables',
        'alias' => 'Aliases', 'aliases' => 'Aliases',
        'class' => 'Classes', 'classes' => 'Classes',
        'trigger' => 'Triggers', 'triggers' => 'Triggers', 'action' => 'Triggers', 'actions' => 'Triggers',
        'config' => 'Settings', 'set' => 'Settings', 'setting' => 'Settings', 'settings' => 'Settings',
        'macro' => 'Macros', 'macros' => 'Macros',
        'sub' => 'Substitutes', 'subs' => 'Substitutes', 'substitute' => 'Substitutes',
        'gag' => 'Gags', 'gags' => 'Gags', 'squelch' => 'Gags', 'ignore' => 'Gags', 'ignores' => 'Gags',
        'highlight' => 'Highlights', 'highlights' => 'Highlights',
        'name' => 'Names', 'names' => 'Names',
        'preset' => 'Presets', 'presets' => 'Presets',
        'layout' => 'Layout', 'profile' => 'Profile'
      }.freeze

      # What `#save all` / `#load all` cover, in Remix's order (Command.cs:611-636, 780-816 R).
      PERSIST_ALL = %w[Variables Aliases Classes Triggers Settings Macros Substitutes Gags
                       Highlights Names Presets].freeze

      # The lists this engine owns ({Lists}, {GlobalStore}); every other kind belongs to the
      # front end in Lich (settings, macros, highlights, ...): for those we echo Remix's line and
      # pass the command on as a front-end effect.
      ENGINE_PERSIST_KINDS = %w[Variables Triggers Classes Aliases Gags Substitutes].freeze

      # #save / #load {kind...} (Command.cs:488-822 R): each argument in turn, unknown
      # ones silently ignored, `all` expanding to PERSIST_ALL. `#load <kind>` clears the list
      # first; `#load classes` (not `#load all`) then raises the class event (Command.cs:674-681 R).
      def persist_command(verb, args, row)
        front_end = false
        args[1..].each do |word|
          key = lower(word)
          kinds = key == 'all' ? PERSIST_ALL : Array(PERSIST_KINDS[key])
          kinds.each do |kind|
            persist_kind(kind, verb, clear_first: true, class_event: key != 'all')
            front_end ||= !ENGINE_PERSIST_KINDS.include?(kind)
          end
        end
        emit_generic(verb == 'Saved' ? 'save' : 'load', args, row) if front_end
        ''
      end

      # The list files under Config.ConfigDir (Command.cs:500-816 R).
      LIST_FILES = { 'Triggers' => 'triggers.cfg', 'Classes' => 'classes.cfg', 'Aliases' => 'aliases.cfg',
                     'Gags' => 'gags.cfg', 'Substitutes' => 'substitutes.cfg' }.freeze

      # Echo Remix's "<Kind> Saved|Loaded" line, then act if the engine owns the list.
      # `#load <kind>` clears first (Command.cs:653-816 R); `#var load`, `#trigger load`,
      # `#gag load`, `#sub load`, `#alias load`, `#class load` merge.
      def persist_kind(kind, verb, clear_first: false, class_event: true)
        @echo.call("#{kind} #{verb}")
        return persist_variables(verb, clear_first) if kind == 'Variables'
        return load_names if kind == 'Names' && verb == 'Loaded'
        return unless LIST_FILES.key?(kind)

        verb == 'Saved' ? save_list(kind) : load_list(kind, clear_first, class_event)
      end

      # `#load names` / `#load all`: NameList.Clear then Load (Command.cs:751-752, 811-812 R) -- its
      # RebuildIndex may fault, ending the command there ({NameList}); the colours stay the front end's.
      def load_names
        @lists.names.clear
        @lists.names.load(@lists.file('names.cfg'))
      end

      def persist_variables(verb, clear_first)
        verb == 'Saved' ? @vars.global_save : @vars.global_load(clear_first: clear_first)
      end

      def save_list(kind)
        path = @lists.save_file(LIST_FILES[kind])
        case kind
        when 'Triggers' then @lists.triggers.save(path)
        when 'Classes' then @lists.classes.save(path)
        when 'Aliases' then @lists.aliases.save(@lists.writable? ? @lists.aliases.file || path : nil)
        when 'Gags' then @lists.filters.save_gags(path)
        when 'Substitutes' then @lists.filters.save_subs(path)
        end
      end

      def load_list(kind, clear_first, class_event)
        path = @lists.file(LIST_FILES[kind])
        case kind
        when 'Triggers' then load_into(@lists.triggers, :clear, clear_first) { |list| list.load(path) }
        when 'Classes'
          load_into(@lists.classes, :clear, clear_first) { |list| list.load(path) }
          class_changed if class_event
        when 'Aliases' then load_into(@lists.aliases, :clear, clear_first) { |list| list.load(list.file || path) }
        when 'Gags' then load_into(@lists.filters, :clear_gags, clear_first) { |list| list.load_gags(path) }
        when 'Substitutes' then load_into(@lists.filters, :clear_subs, clear_first) { |list| list.load_subs(path) }
        end
      end

      def load_into(list, clear, clear_first)
        list.public_send(clear) if clear_first
        yield list
      end

      # #var / #tvar / #svar add (Command.cs:925-934, 946-955, 967-986 R): key = ParseGlobalVars
      # (oArgs[1]), value = ParseGlobalVars(ParseAllArgs(oArgs, 2)) -- re-parsed, so `{a;b}` is
      # "b" and `#evalmath 1+2` is "3" -- and VariableChanged("$" + the raw oArgs[1]). `#svar`'s
      # `<stgupd>` raw send to the server is not reproduced (0 corpus; open-items.md K5).
      def set_variable(args, persist:, server: false)
        key = expand_globals(args[1].to_s)
        value = expand_globals(parse_all_args(args, 2))
        @vars.global_set(key, value, persist: persist, server: server)
        @var_changed.call("$#{args[1]}")
        ''
      end

      # #unvar (Command.cs:993-1015 R): oArgs[1] raw, removed if present (a lone `#unvar`
      # faults on the missing argument).
      def delete_variable(args)
        @vars.global_delete(arg!(args, 1))
        ''
      end

      # --- engine-side: computation ----------------------------------------

      # Command.EvalMath (Command.cs:2907-2916 R): `d.ToString()`; MathEval's
      # InvalidCastException is not caught there, so it ends the whole ParseCommand -- quietly,
      # like any fault of a ParseCommand nobody awaits ({ParseCommand#run}): `#var x #evalmath
      # bad` sets nothing. Eval's faults (#eval, #if) end it the same way.
      def eval_math(argument)
        Numeric.format_double(MathEval.evaluate(argument))
      end

      # #math {var} {expr}: keyword-based arithmetic into a global (Command.cs:1029-1053 R). The
      # current value is double.TryParse'd, a failure (or no such variable) being 0 -- not
      # StringToDouble's -1 (Command.cs:1033-1035 R); the expression is ParseGlobalVars(
      # ArrayToString(oArgs, 2)). A bad keyword sets nothing and echoes the catch's "Invalid
      # #math expression: <args>" (Command.cs:1044-1049 R). Only the calculation is rescued: a
      # nested-dispatch cap overflow ({DispatchDepth::Exceeded}) from the variable-change dispatch
      # must unwind.
      def do_math(args)
        return '' if args.length < 2

        key = args[1].to_s
        current = Numeric.net_double(@vars.global_get(key).to_s) || 0.0
        result = begin
          MathCalc.calc(current, expand_globals(Text.array_to_string(args, 2)))
        rescue Error
          @echo.call("Invalid #math expression: #{Text.array_to_string(args, 1)}")
          return ''
        end
        @vars.global_set(key, Numeric.format_double(result), persist: true)
        @var_changed.call("$#{key}")
        ''
      end

      # #if {cond} {then} {else} (Command.cs:1067-1100 R): a condition starting with `#` is first
      # replaced by its ParseCommand result; the condition is ParseGlobalVars'd into DoEval. A
      # taken branch starting with `#` runs as ParseCommand(ParseGlobalVars(branch)); any other
      # runs as ParseCommand(ArrayToString(oArgs, i)) -- the args from it on, so a plain then-
      # branch carries the else-branch with it. Never sent (bSendToGame false): the branch's
      # LAST row's result is the #if's result, and the `#` rows in it run (every `;` part).
      def do_if(args)
        return '' unless args.length > 2

        condition = args[1].to_s
        condition = parse_command(expand_globals(condition)) if condition.start_with?('#')
        if @eval.do_eval(expand_globals(condition))
          if_branch(args, 2)
        elsif args.length > 3
          if_branch(args, 3)
        else
          ''
        end
      end

      def if_branch(args, index)
        branch = args[index].to_s
        return parse_command(expand_globals(branch)) if branch.start_with?('#')

        parse_command(Text.array_to_string(args, index))
      end

      # #random [min max] (Command.cs:1441-1455 R): each bound is the ParseCommand result of its
      # ParseGlobalVars'd argument, Utility.StringToInteger'd (-1 unless a positive Int32); then
      # Utility.RandomNumber = Random.Next(min, max + 1) (Utility.cs:251-255 R; Int32.MaxValue + 1
      # wraps; min > max + 1 throws). Without both bounds, 1..1000.
      def do_random(args)
        return rand(1..1000).to_s unless args.length > 2

        low = Numeric.string_to_integer(parse_command(expand_globals(args[1].to_s)))
        high = Numeric.string_to_integer(parse_command(expand_globals(args[2].to_s)))
        bound = high == 2_147_483_647 ? -2_147_483_648 : high + 1
        raise Error, RANDOM_SWAPPED if low > bound

        (low == bound ? low : rand(low...bound)).to_s
      end

      # #put <text> (Command.cs:851-863 R): ParseGlobalVars(ParseAllArgs(oArgs, 1)) through
      # SendTextToGame (as the issuer: sOrigin).
      def do_put(args)
        send_text_to_game(expand_globals(parse_all_args(args, 1))) if args.length > 1
        ''
      end

      # --- engine-side: echo and log -----------------------------------------

      # #echo [>window] text | #echo <colour> >window text (Command.cs:268-328 R): the window is
      # ParseGlobalVars'd and dropped from the args; the colour argument (iColorIndex: arg 2 after
      # a `>window` arg 1, else arg 1) is dropped when ColorCode.StringToColor gives a colour -- a
      # `#RRGGBB`, a KnownColor name (`red`, `Crimson`), the fg of `fg,bg` ({ColorCode.echo_color?});
      # the text is ParseGlobalVars(ParseAllArgs(oArgs, 1, no quick send)). A `>window` goes to a
      # named-window front-end echo, else the local echo; the colour itself is not carried.
      def do_echo(args)
        list = args.dup
        window = ''
        color_index = 0 # iColorIndex
        if list.length > 1 && list[1].to_s.start_with?('>')
          window = expand_globals(list[1].to_s[1..])
          list[1] = nil
          color_index = 2 if list.length > 2
        elsif list.length > 2 && list[2].to_s.start_with?('>')
          window = expand_globals(list[2].to_s[1..])
          list[2] = nil
          color_index = 1
        elsif list.length > 1
          color_index = 1
        end
        list[color_index] = nil if color_index.positive? && ColorCode.echo_color?(list[color_index])
        text = expand_globals(parse_all_args(list, 1, parse_quick_send: false))
        window.empty? ? @echo.call(text) : @hooks&.emit('echo', { 'window' => window, 'text' => text })
        ''
      end

      # #log [>file] text (Command.cs:361-385 R): `>file` (ParseGlobalVars'd) appends
      # ParseGlobalVars(ParseAllArgs(oArgs, 2, no quick send)) as one line to that file
      # (Log.LogLine); otherwise ParseGlobalVars(ParseAllArgs(oArgs, 1, no quick send)) + a line
      # end goes to $charactername's daily log (Log.LogText with $game). A lone `#log` faults on
      # oArgs[1]. Nothing is written without a log dir. A failed write (a file in a missing folder:
      # no folder is created but the log dir itself, {LogFile}) is Remix's GenieError dialog, which
      # its own handler turns into an endless re-raise (Game.cs:3291-3294 R): ours echoes
      # "[LogLine: <message>]" / "[LogText: <message>]" and goes on (a decided divergence).
      def do_log(args)
        report = ->(section, message) { @echo.call("[#{section}: #{message}]") }
        if arg!(args, 1).start_with?('>')
          file = expand_globals(args[1].to_s[1..])
          if args.length > 2
            text = expand_globals(parse_all_args(args, 2, parse_quick_send: false))
            dir = @log_dir&.call
            LogFile.log_line(text, file_name: file, dir: dir, on_error: report) if dir
          end
        else
          text = expand_globals(parse_all_args(args, 1, parse_quick_send: false))
          dir = @log_dir&.call
          if dir
            LogFile.log_text("#{text}\r\n", character: @vars.global_get('charactername').to_s,
                                            instance: @vars.global_get('game').to_s, dir: dir, now: @wall_clock.call,
                                            on_error: report)
          end
        end
        ''
      end

      # --- engine-side: the global lists -------------------------------------

      # A listing in Remix's shape (Command.cs:3002-3626 R): the header, "Filter: <p>" when a
      # filter is given, the block's lines, or "None.".
      def listing(header, pattern)
        lines = yield
        @echo.call(header)
        @echo.call("Filter: #{pattern}") unless pattern.empty?
        lines.each { |line| @echo.call(line) }
        @echo.call('None.') if lines.empty?
        ''
      end

      # #class (Command.cs:1234-1354 R; {ClassList}): no argument lists; `+name`/`-name` tokens
      # (every token of the row, lower-cased names; `+all`/`-all` switch everything) then the
      # class event; two args: load (merge) / save / clear / edit, or the listing filtered by
      # ArrayToString(oArgs, 1) -- followed by the class event; `#class all on|off` (only
      # true/on/1 and false/off/0 do anything) or `#class name value` (Classes.Add: anything but
      # true/on/1 is off), then the class event. `clear` raises none.
      def class_command(args, row)
        classes = @lists.classes
        if args.length == 1
          list_classes('')
        elsif args[1].to_s.start_with?('+', '-')
          args.each { |item| class_token(classes, item.to_s) }
          class_changed
        elsif args.length < 3
          class_word(classes, args, row)
        else
          class_set(classes, args[1].to_s, args[2].to_s)
          class_changed
        end
        ''
      end

      def class_token(classes, item)
        return unless item.length > 1 && item.start_with?('+', '-')

        on = item.start_with?('+')
        name = lower(item[1..])
        if name == 'all'
          @echo.call(on ? 'All Classes Activated' : 'All Classes InActivated')
          on ? classes.activate_all : classes.inactivate_all
        else
          classes.add(name, on ? 'True' : 'False')
        end
      end

      def class_word(classes, args, row)
        case lower(args[1])
        when 'load'
          @echo.call('Classes Loaded')
          classes.load(@lists.file('classes.cfg'))
          class_changed
        when 'save'
          @echo.call('Classes Saved')
          classes.save(@lists.save_file('classes.cfg'))
        when 'clear'
          @echo.call('Classes Cleared')
          classes.clear
        when 'edit' then emit_generic('class', args, row)
        else
          list_classes(Text.array_to_string(args, 1))
          class_changed
        end
      end

      def class_set(classes, name, value)
        return classes.add(name, value) unless lower(name) == 'all'

        case lower(value)
        when 'true', 'on', '1'
          @echo.call('All Classes Activated')
          classes.activate_all
        when 'false', 'off', '0'
          @echo.call('All Classes InActivated')
          classes.inactivate_all
        end
      end

      # ListClasses (Command.cs:3508-3546 R): "key=True|False" for each key containing the filter.
      def list_classes(pattern)
        listing('Active classes: ', pattern) do
          @lists.classes.entries.select { |key, _| pattern.empty? || key.include?(pattern) }
                                .map { |key, state| "#{key}=#{state ? 'True' : 'False'}" }
        end
      end

      # EventClassChange -> Command_EventClassChange (FormMain.cs:7483-7519 R): the whole class
      # list re-applied to the triggers and gags/subs ({Lists#class_changed}); the front end gets
      # the list for its highlights.
      def class_changed
        @lists.class_changed
        emit('class', 'classes' => @lists.classes.entries.to_h)
      end

      # #trigger / #triggers / #action / #actions (Command.cs:1366-1429 R): no argument lists;
      # with one, load (merge) / save / clear / edit, or the listing filtered by it (so `#trigger
      # list` filters on "list"); with two or more, Globals.AddTrigger(pattern, action, class =
      # oArgs[3] trimmed) -- the pattern ParseGlobalVars'd unless it is an eval trigger (Globals.
      # cs:920-936 R) -- and "Invalid regexp in trigger: <raw pattern>" when Add refuses it.
      def trigger_command(args, row)
        if args.length < 2 then list_triggers('')
        elsif args.length == 2
          case lower(args[1])
          when 'load' then persist_kind('Triggers', 'Loaded')
          when 'save' then persist_kind('Triggers', 'Saved')
          when 'clear'
            @echo.call('Triggers Cleared')
            @lists.triggers.clear
          when 'edit' then emit_generic('trigger', args, row)
          else list_triggers(Text.array_to_string(args, 1))
          end
        else
          add_trigger(args[1].to_s, args[2].to_s, args.length > 3 ? Text.net_trim(args[3].to_s) : '')
        end
        ''
      end

      # #untrigger (Command.cs:1431-1439 R): TriggerList.Remove(oArgs[1]), raw.
      def remove_trigger(args)
        @lists.triggers.remove(args[1].to_s) if args.length > 1
        ''
      end

      def add_trigger(raw, commands, klass)
        pattern = TriggerFile.normalize(raw).eval ? raw : expand_globals(raw)
        authored = AuthoredCommand.authored_definitions? # see AuthoredCommand: decided now, at the definition
        return @echo.call("Invalid regexp in trigger: #{raw}") unless @lists.triggers.add(pattern, commands, klass: klass, authored: authored)

        # A .NET-valid pattern NetRegex cannot match is added silently by Remix; here it never
        # fires, so one warning line says so.
        unsupported = Triggers.unsupported(pattern)
        @echo.call(unsupported.warning('#trigger')) if unsupported
      end

      # ListTriggers (Command.cs:3428-3466 R): "key=action" for each key containing the filter.
      def list_triggers(pattern)
        listing('Active triggers: ', pattern) do
          @lists.triggers.entries.select { |key, *| pattern.empty? || key.include?(pattern) }
                                 .map { |key, _pattern, commands| "#{key}=#{commands}" }
        end
      end

      # #gag / #gags / #squelch / #ignore / #ignores (Command.cs:1744-1804 R): no argument lists;
      # load (merge) / save / clear / edit; anything else adds ParseGlobalVars(oArgs[1]) with the
      # class oArgs[2] (raw) and IgnoreCase = oArgs[3] is TRUE (the argument Remix calls
      # caseSensitive), echoing "Invalid regexp in gag: <ParseGlobalVars(ArrayToString(1))>" when
      # Add refuses it -- so `#gag list` adds a gag "list".
      def gag_command(args, row)
        return list_gags('') if args.length < 2

        filters = @lists.filters
        case lower(args[1])
        when 'load'
          @echo.call('Gags Loaded')
          filters.load_gags(@lists.file('gags.cfg'))
        when 'save'
          @echo.call('Gags Saved')
          filters.save_gags(@lists.save_file('gags.cfg'))
        when 'clear'
          @echo.call('Gags Cleared')
          filters.clear_gags
        when 'edit' then emit_generic('gag', args, row)
        else
          added = filters.add_gag(expand_globals(args[1].to_s), ignore_case: args.length > 3 && Text.net_upcase(args[3].to_s) == 'TRUE',
                                                                klass: args.length > 2 ? args[2].to_s : '')
          @echo.call("Invalid regexp in gag: #{expand_globals(Text.array_to_string(args, 1))}") unless added
        end
        ''
      end

      # #ungag / #unsquelch / #unignore / #unignores (Command.cs:1872-1884 R): GagList.Remove(
      # ParseGlobalVars(ArrayToString(oArgs, 1))) -- the whole argument, exact text.
      def remove_gag(args)
        @lists.filters.remove_gag(expand_globals(Text.array_to_string(args, 1))) if args.length > 1
        ''
      end

      # #unsub / #unsubs / #unsubstitute (Command.cs:1731-1742 R): SubstituteList.Remove(
      # ParseGlobalVars(oArgs[1])).
      def remove_sub(args)
        @lists.filters.remove_sub(expand_globals(args[1].to_s)) if args.length > 1
        ''
      end

      # ListGags (Command.cs:3120-3157 R): the filter line is printed but filters nothing.
      def list_gags(pattern)
        listing('Active gags: ', pattern) { @lists.filters.gags.map(&:text) }
      end

      # #sub / #subs / #substitute (Command.cs:1661-1729 R): no argument lists; one: load (merge) /
      # save / clear / edit or the listing; two or more add ParseGlobalVars of the text, the
      # replacement and the class (oArgs[3]), echoing "Invalid regexp in substitute:
      # <ParseGlobalVars(oArgs[1])>" when Add refuses it.
      def sub_command(args, row)
        return sub_word(args, row) if args.length < 3

        klass = args.length > 3 ? expand_globals(args[3].to_s) : ''
        text = expand_globals(args[1].to_s)
        added = @lists.filters.add_sub(text, expand_globals(args[2].to_s), klass: klass)
        @echo.call("Invalid regexp in substitute: #{expand_globals(args[1].to_s)}") unless added
        ''
      end

      def sub_word(args, row)
        return list_subs('') if args.length < 2

        filters = @lists.filters
        case lower(args[1])
        when 'load'
          @echo.call('Substitutes Loaded')
          filters.load_subs(@lists.file('substitutes.cfg'))
        when 'save'
          @echo.call('Substitutes Saved')
          filters.save_subs(@lists.save_file('substitutes.cfg'))
        when 'clear'
          @echo.call('Substitutes Cleared')
          filters.clear_subs
        when 'edit' then emit_generic('sub', args, row)
        else list_subs(Text.array_to_string(args, 1))
        end
        ''
      end

      # ListSubstitutes (Command.cs:3081-3118 R): "text => replacement" for every substitute; the
      # filter line filters nothing.
      def list_subs(pattern)
        listing('Active substitutes: ', pattern) { @lists.filters.subs.map { |sub| "#{sub.text} => #{sub.replacement}" } }
      end

      # #alias / #aliases (Command.cs:1166-1222 R): no argument lists; one: load (merge) / save /
      # clear / edit or the listing; two or more add oArgs[1] -> oArgs[2] raw. The engine's list
      # ({AliasList}) is what a script's `put` expands; the front end also gets the alias (its own
      # typed input).
      def alias_command(args, row)
        return alias_word(args, row) if args.length < 3

        @lists.aliases.add(args[1].to_s, args[2].to_s, authored: AuthoredCommand.authored_definitions?) # see AuthoredCommand
        emit('alias', 'pattern' => args[1].to_s, 'command' => args[2].to_s)
      end

      def alias_word(args, row)
        return list_aliases('') if args.length < 2

        case lower(args[1])
        when 'load' then persist_kind('Aliases', 'Loaded')
        when 'save' then persist_kind('Aliases', 'Saved')
        when 'clear'
          @echo.call('Aliases Cleared')
          @lists.aliases.clear
        when 'edit' then emit_generic('alias', args, row)
        else list_aliases(Text.array_to_string(args, 1))
        end
        ''
      end

      def remove_alias(args)
        return '' unless args.length > 1

        @lists.aliases.remove(args[1].to_s)
        emit('unalias', 'pattern' => args[1].to_s)
      end

      # ListAliases (Command.cs:3468-3506 R): "key=alias" for each key containing the filter.
      def list_aliases(pattern)
        listing('Active aliases: ', pattern) do
          @lists.aliases.entries.select { |key, _| pattern.empty? || key.include?(pattern) }.map { |key, value| "#{key}=#{value}" }
        end
      end

      # ListKeys (Command.cs:2995-3000 R).
      def list_keys
        @echo.call('Available keycodes: ')
        KEY_NAMES.each { |name| @echo.call(name) }
        ''
      end

      # ListColors (Command.cs:2978-2993 R): each KnownColor web colour, in enum order.
      def list_colors
        @echo.call('Available colors: ')
        ColorCode::KNOWN_COLORS.each { |name| @echo.call(name) }
        ''
      end

      # --- front-end effects: structured payloads --------------------------

      # The list-management words every front-end list shares (Command.cs:1595-1630, 1817-1857,
      # 2035-2070 R): load/save/clear echo "<Kind> Loaded|Saved|Cleared", then the effect.
      def front_end_word(kind, op, args, row)
        word = lower(args[1])
        label = { 'load' => 'Loaded', 'save' => 'Saved', 'clear' => 'Cleared' }[word]
        @echo.call("#{kind} #{label}") if label
        emit_generic(op, args, row)
      end

      # #macro (Command.cs:1584-1640 R): listing / list words; two or more args add a macro
      # (the "Unknown key combination" echo needs the front end's KeysConverter: not reproduced).
      def macro_command(args, row)
        return front_end_word('Macros', 'macro', args, row) if args.length == 2
        return emit_generic('macro', args, row) if args.length < 2

        emit('macro', 'key' => args[1].to_s, 'command' => args[2].to_s)
      end

      # #preset (Command.cs:1806-1870 R): two or more args set a known preset (lower-cased key),
      # any other key echoes "Invalid #preset keyword."; fewer: listing / list words.
      def preset_command(args, row)
        return front_end_word('Presets', 'preset', args, row) if args.length == 2
        return emit_generic('preset', args, row) if args.length < 2
        return emit('preset', 'name' => lower(args[1]), 'value' => args[2].to_s) if PRESET_KEYS.include?(lower(args[1]))

        @echo.call('Invalid #preset keyword.')
        ''
      end

      # #name (Command.cs:2024-2082 R): two or more args name each target; fewer: listing / words.
      def name_command(args, row)
        if args.length == 2
          word = lower(args[1])
          front_end_word('Names', 'name', args, row)
          @lists.names.clear if word == 'clear'
          @lists.names.load(@lists.file('names.cfg')) if word == 'load' # merged, then RebuildIndex (Command.cs:2041 R)
          return ''
        end
        return emit_generic('name', args, row) if args.length < 2

        value = args[1].to_s
        @lists.names.add(args[2..].map(&:to_s)) # RebuildIndex may fault ({NameList}; parity 7)
        args[2..].each { |target| emit('name', 'name' => target.to_s, 'value' => value) unless target.to_s.empty? }
        ''
      end

      # #highlight (Command.cs:1886-2015 R): no argument lists; load / save / clear (echoed);
      # `line(s)` / `string(s)` / `beginswith` / `regexp|regex` with more than three args add a
      # highlight -- pattern ParseGlobalVars(oArgs[3]), colour ParseGlobalVars(oArgs[2]), class
      # oArgs[4], sound oArgs[5], case-sensitive oArgs[6] == TRUE, active oArgs[7] == TRUE (default
      # true) -- Remix's argument order; an invalid regexp echoes "Invalid RegExp in
      # highlight: <ParseGlobalVars(ArrayToString(3))>"; any other word lists.
      HIGHLIGHT_KINDS = { 'line' => 'line', 'lines' => 'line', 'string' => 'string', 'strings' => 'string',
                          'beginswith' => 'beginswith', 'regexp' => 'regex', 'regex' => 'regex' }.freeze

      def highlight_command(args, row)
        return emit_generic('highlight', args, row) if args.length < 2

        word = lower(args[1])
        if word == 'clear'
          @echo.call('Highlights Cleared')
          return emit('highlight', 'clear' => true)
        end
        return front_end_word('Highlights', 'highlight', args, row) if %w[load save].include?(word)

        kind = HIGHLIGHT_KINDS[word]
        return emit_generic('highlight', args, row) if kind.nil?
        return '' unless args.length > 3

        pattern = expand_globals(args[3].to_s)
        if kind == 'regex' && !NetRegex.valid?(pattern)
          @echo.call("Invalid RegExp in highlight: #{expand_globals(Text.array_to_string(args, 3))}")
          return ''
        end
        key, case_sensitive = highlight_key(kind, pattern, Text.net_upcase(args[6].to_s) == 'TRUE')
        return '' if key.nil? # Add returns false: nothing added

        emit('highlight', 'kind' => kind, 'whole_row' => kind == 'line', 'color' => expand_globals(args[2].to_s),
                          'pattern' => key, 'class' => args[4].to_s, 'sound' => args[5].to_s,
                          'case_sensitive' => case_sensitive,
                          'active' => args.length > 7 ? Text.net_upcase(args[7].to_s) == 'TRUE' : true)
      end

      # The key a highlight list's Add keeps, and its case sensitivity: an empty
      # text adds nothing; line/string (Highlights.Add, StripCaseMarker, Highlights.cs:116-149 R)
      # strip only a `/`-led text longer than its markers -- `/x/i` (case-insensitive) or `/x/` --
      # and refuse what is empty after; beginswith/regex (Globals.cs:1240-1262, 1361-1383 R) drop a
      # leading `/`, then a trailing `/i` (case-insensitive) or `/`.
      # @return [Array(String, Boolean), nil]
      def highlight_key(kind, pattern, case_sensitive)
        return nil if pattern.empty?

        if %w[line string].include?(kind)
          if pattern.start_with?('/') && pattern.end_with?('/i') && pattern.length > 3
            pattern = pattern[1...-2]
            case_sensitive = false
          elsif pattern.start_with?('/') && pattern.end_with?('/') && pattern.length > 2
            pattern = pattern[1...-1]
          end
          return pattern.empty? ? nil : [pattern, case_sensitive]
        end
        pattern = pattern[1..] if pattern.start_with?('/')
        if pattern.end_with?('/i')
          [pattern[0...-2], false]
        else
          [pattern.end_with?('/') ? pattern[0...-1] : pattern, case_sensitive]
        end
      end

      # #window (Command.cs:2331-2405 R): add/show, remove, close/hide, load/save (layouts), and
      # position with its syntax checks echoed (EchoColorText in the scriptecho preset).
      def window_command(args, row)
        return '' if args.length < 2

        case lower(args[1])
        when 'add', 'show' then window_event(lower(args[1]), parse_all_args(args, 2), 'width' => 300, 'height' => 200, 'top' => 10, 'left' => 10)
        when 'position' then window_position(args, row)
        when 'remove', 'close', 'hide' then window_event(lower(args[1]), parse_all_args(args, 2))
        when 'load', 'save' then emit('layout', 'action' => 'load', 'name' => expand_globals(parse_all_args(args, 2)))
        else ''
        end
      end

      def window_event(action, name, extra = {})
        emit('window', { 'action' => action, 'name' => expand_globals(name) }.merge(extra))
      end

      # The position arm (Command.cs:2348-2374 R): its exceptions -- incl. the IndexOutOfRange of
      # oArgs[4] with only four args -- are echoed.
      def window_position(args, row)
        raise Error, 'Syntax Error: Window Name, and one of (Width, Height, Top, or Left) are required.' if args.length < 4
        if args.length > 7
          hint = Numeric.net_int32(args[3].to_s) ? '' : ' Window names with spaces need to be "enclosed" in double quotes'
          raise Error, "Error in command: #{row}: #{args.length - 7} too many Args in Position command.#{hint}"
        end

        width = Numeric.net_int32(args[3].to_s)
        width_bad = width.nil? && args[3].to_s != ''
        height = Numeric.net_int32(arg!(args, 4)) unless width_bad
        if width_bad || (height.nil? && args[4].to_s != '')
          raise Error, "Syntax Error: Width (#{args[3]}) and/or Height (#{arg!(args, 4)}) are not formatted correctly."
        end

        emit('window', 'action' => 'position', 'name' => expand_globals(args[2].to_s),
                       'width' => nonzero(width), 'height' => nonzero(height),
                       'top' => args.length > 5 ? Numeric.net_int32(args[5].to_s) : nil,
                       'left' => args.length > 6 ? Numeric.net_int32(args[6].to_s) : nil)
      rescue Error => e
        @echo.call(e.message)
        ''
      end

      def nonzero(value)
        value.nil? || value.zero? ? nil : value
      end

      # #play/#playwave/#playsound <file>|stop (Command.cs:1550-1568 R; uses the arg string).
      def emit_sound(argument)
        arg = argument.to_s
        return '' if arg.empty?

        arg.casecmp?('stop') ? emit('playsound', 'stop' => true) : emit('playsound', 'file' => arg)
      end

      # #link [>window] {text} {command} (Command.cs:330-353 R).
      def emit_link(args)
        if args.length > 3 && args[1].to_s.start_with?('>')
          # ParseGlobalVars of the window and the text, not the command (Command.cs:335-345 R)
          emit('link', 'window' => expand_globals(args[1].to_s[1..]), 'text' => expand_globals(args[2].to_s),
                       'command' => Text.array_to_string(args, 3))
        elsif args.length > 2
          emit('link', 'window' => '', 'text' => expand_globals(args[1].to_s), 'command' => Text.array_to_string(args, 2))
        else
          ''
        end
      end

      # #img/#image [>window] [w:N] [h:N] {file} (Command.cs:392-416 R): every argument but those
      # starting with `#`; `w:`/`width:`/`h:`/`height:` with a bad number echo "Invalid Width|Height
      # Specified: <arg>"; no file echoes "No File Name was specified for the Image Command.".
      def do_image(args)
        window = ''
        width = 0
        height = 0
        filename = ''
        args.each do |arg|
          t = arg.to_s
          next if t.start_with?('#')

          if t.start_with?('>') then window = t[1..]
          elsif (t.length > 2 && t.start_with?('w:')) || (t.length > 6 && t.start_with?('width:'))
            width = image_size(t, 'Width', width)
          elsif (t.length > 2 && t.start_with?('h:')) || (t.length > 7 && t.start_with?('height:'))
            height = image_size(t, 'Height', height)
          else filename = t
          end
        end
        if filename.empty?
          @echo.call('No File Name was specified for the Image Command.')
          return ''
        end

        emit('image', 'filename' => filename, 'window' => window, 'width' => width, 'height' => height)
      end

      # int.TryParse(arg.Split(":")[1]): a failure echoes and leaves 0.
      def image_size(arg, label, _current)
        value = Numeric.net_int32(arg.split(':', -1)[1].to_s)
        @echo.call("Invalid #{label} Specified: #{arg}") if value.nil?
        value || 0
      end

      # #connect (Command.Connect, Command.cs:2638-2667 R): one, two or five args are the host's
      # (re)connect; any other count echoes the syntax line.
      def do_connect(args, row)
        return emit_generic('connect', args, row) if [1, 2, 5].include?(args.length)

        @echo.call('Invalid number of arguments in #connect command. Syntax: #connect account password character game')
        ''
      end

      # #lc / #lconnect / #lichconnect <profile> (Command.cs:418-446 R): a profile with no
      # Config\Profiles\<profile>.xml echoes "Profile "<profile>" not found. Lich was not started."
      # (OrangeRed); starting Lich and connecting is the launcher's (hook) -- we are inside Lich.
      def do_lich_connect(args, row)
        if args.length == 2
          profile = Text.net_trim(expand_globals(args[1].to_s))
          path = @lists.file(File.join('Profiles', "#{profile}.xml"))
          unless path && File.exist?(path)
            @echo.call("Profile \"#{profile}\" not found. Lich was not started.")
            return ''
          end
        end
        emit_generic('lc', args, row)
      end

      # #unname {name...} (Command.cs:2084-2093 R).
      def emit_unname(args)
        return '' if args.length < 2

        @lists.names.remove(args[1..].map(&:to_s)) # Names.Remove: no RebuildIndex (Command.cs:2084-2092 R)
        args[1..].each { |target| emit('unname', 'name' => target.to_s) }
        ''
      end

      # #layout [load|save] {name} (Command.cs:2303-2329 R); no args -> load @windowsize@.
      def emit_layout(args)
        return emit('layout', 'action' => 'load', 'name' => '@windowsize@') if args.length < 2

        action = lower(args[1])
        return '' unless %w[load save].include?(action)

        emit('layout', 'action' => action, 'name' => expand_globals(parse_all_args(args, 2))) # Command.cs:2312-2318 R
      end

      # Any other front-end op: the tokenized args + the raw argument string (safe to ignore).
      def emit_generic(keyword, args, row)
        emit(keyword, generic(args, row))
      end

      def generic(args, row) = { 'args' => args[1..], 'raw' => Text.argument_string(row) }

      # #status / #statusbar (Command.cs:2269-2300 R): with an argument, StatusBar(ParseGlobalVars(
      # ParseAllArgs(oArgs, 2)), n) when the first one is 1..10, else StatusBar(ParseGlobalVars(
      # ParseAllArgs(oArgs, 1))) -- bar 1 (StatusBar's default, Command.cs:2715 R); none: nothing.
      STATUS_BARS = (1..10).map(&:to_s).freeze

      def status_bar(keyword, args, row)
        return '' if args.length < 2

        index = STATUS_BARS.include?(lower(args[1])) ? args[1].to_i : nil
        text = expand_globals(parse_all_args(args, index ? 2 : 1))
        emit(keyword, generic(args, row).merge('text' => text, 'index' => index || 1))
      end

      # #comment (Command.cs:2407-2414 R): with more than two arguments, EventChangeWindowTitle(
      # oArgs[1], ParseGlobalVars(ParseAllArgs(oArgs, 2))); else nothing.
      def window_title(args, row)
        return '' if args.length < 3

        emit('comment', generic(args, row).merge('window' => args[1].to_s, 'text' => expand_globals(parse_all_args(args, 2))))
      end

      def emit(op, payload)
        @hooks&.emit(op, payload)
        ''
      end
    end
  end
end
