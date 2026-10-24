# frozen_string_literal: true

module Lich
  module Genie
    # Executes a compiled Genie program. Clean-room port of Genie4 Script.cs
    # RunScript/RunScriptRow/TickScript, adapted to Lich's thread-per-script model
    # (Option A, design doc Decision 4): instead of a 10ms cooperative tick, the
    # interpreter runs rows until a wait verb, then blocks on the injected input
    # port (with a deadline) while still firing async actions. See
    # docs/genie-engine/interpreter-spec.md.
    #
    # Collaborators are injected (DIP) so this runs headless in specs:
    #   * game  -- responds to #send_command(String)
    #   * input -- responds to #next_line(timeout:) => an item or nil (nil on timeout; a zero
    #     timeout only looks, like Lich's LimitedArray#wait_shift(0))
    #   * echo  -- callable(String) for script echo/errors
    #   * hooks -- responds to #emit(op, payload) for <genieHook> front-end effects
    #   * clock -- callable => monotonic Float seconds
    #
    # Every incoming line, and every `#parse` this script issues, goes through
    # {#trigger_parse} (Remix Script.TriggerParse): the pending waitfor, the matchwait
    # list, then the actions. A `#parse` reaches the global #triggers and every script,
    # this one included, through the injected +broadcast+ port.
    #
    # Timing (TickScript, Script.cs:1487-1664 R): the input also carries the game's
    # {GameEvents} -- SetRoundTime, TriggerPrompt (+ the prompt text), TriggerMove -- and a wait
    # resumes only (a) between DR packets ("end of chunk": the packet's prompt, or
    # CHUNK_IDLE_SECONDS with no further game row -- Lich has no packet boundary, see
    # interpreter-spec.md section 12), (b) outside the roundtime except `delay` and
    # `action instant` (Script.cs:1505-1511 R), (c) while the script is not paused, and
    # (d) when its own Remix condition holds ({#resume_ready}).
    #
    # JavaScript (`js` / `jscall` / `<% %>` blocks) runs on JsRuntime, a stand-in for Remix's
    # bundled Jint 4 covering the published js_arrays.js functions and the recognised blocks
    # (failing where Remix's Jint 4 fails); anything else is announced unsupported.
    #
    # Actions are Remix's (EvalAction/ClassActionList/TriggerParse/ParseAction): see
    # {ActionList} for the registry and {#parse_action} for how a body runs -- each row
    # goes through the normal row executor, so every verb works in an action body and an
    # action goto behaves like the script's own goto.
    class Interpreter
      # The default per-run wall-clock limit: if a continuous row loop (no wait yield) runs
      # longer than Config.iScriptTimeout (5000 ms by default; settings.cfg / `#config
      # scripttimeout`, read at every check), abort as a runaway (oTimerStart taken per
      # RunScript call, checked before every normal row, Script.cs:1713, 1819-1830 R). This is
      # Remix's ONLY runaway guard: SendText keeps no send history (Script.cs:4438-4441 R; the
      # "10 identical / 30 total sends in 10 s" guard is upstream 4.5.0.3 only and was removed
      # for parity).
      SCRIPT_TIMEOUT_SECONDS = 5.0

      # Int32.MaxValue: the `send` verb's int.Parse delay overflows past it (FormMain.cs:6842 R).
      INT32_MAX = 2_147_483_647

      # One Remix timer tick (TimerBgWorker.Interval = 10 ms, FormMain.Designer.cs:1409 R): TickScript
      # looks at a timed wait only on a tick, so a wait entered on one tick resumes on a later one
      # -- `pause`, `delay`, `wait N` and a matchwait timeout resume no sooner than one tick after
      # entry (Script.cs:1513-1548, 1635-1650 R; {#timed_end}). A sub-tick `delay 0.001` loop
      # (automapper.cmd WAVE_DO, ~3000 corpus pause/delay <= 0.001) thus runs one pass per tick.
      TICK_SECONDS = 0.01

      # An action goto taken while the script is RUNNING (its own `#parse` fired the action)
      # stops the current RunScript (m_bStopRunning, Script.cs:1861-1869 R) and resumes in
      # the actionwait state on the next tick (Script.cs:2246-2263, 1653-1663 R).
      ACTION_RESUME_SECONDS = TICK_SECONDS

      # Config.iArgumentCount (Lists/Config.cs:18 R): ParseAction replaces $1..$15 with the
      # action's regex groups (Script.cs:2157-2168 R).
      ACTION_ARGUMENT_COUNT = 15

      # Rows ParseAction refuses with a script error + abort (Script.cs:2205-2239 R).
      ACTION_FORBIDDEN = { gosub_func: 'GOSUB', blockstart: 'BLOCK START', blockend: 'BLOCK END',
                           return_func: 'RETURN' }.freeze

      # Shields an escaped `\$` from ParseAction's $n pass (Remix uses `\` + U+00A4; an ASCII
      # control keeps the source ASCII-only and never meets a non-UTF-8 game line).
      ESCAPED_DOLLAR = "\\\x02"

      # Lich has no packet boundary (it reads the game socket line by line, games.rb:963-967), so
      # the end of a DR packet is its prompt row ({GameEvents::Prompt}) or, for a burst with no
      # prompt, this long with no further game row on the input: the rows of one packet reach a
      # script <= 3.6 ms apart (the tester's capture, 910 rows; one TCP split at 110 ms), and Remix's
      # own resume comes on the next 10 ms tick after the socket buffer ends (interpreter-spec.md
      # section 12). Measured under GVL contention (1-4 CPU-bound threads, 0.65-21 ms
      # of parse work per row): 0 mid-packet splits at 10 ms, the smallest value tried -- a
      # CPU-bound parser keeps the GVL, so only a blocking socket gap ends a packet early.
      CHUNK_IDLE_SECONDS = 0.01

      # How often a paused script looks at its pause flag (Lich's own pause checkpoint polls
      # every 0.2 s, Script#wait_while_paused!, script.rb:2927-2930).
      PAUSE_POLL_SECONDS = 0.2

      # The states TickScript resumes without waiting for the roundtime (Script.cs:1505 R); the
      # scripterror arm comes before the roundtime check (Script.cs:1498-1503 R).
      RT_EXEMPT = %i[delayed actioninstant scripterror].freeze

      # The wait states (TickScript's arms, Script.cs:1498-1664 R). (ScriptState.waitdo has an arm,
      # Script.cs:1561-1571 R, but nothing ever enters it: not ported.)
      WAIT_STATES = %i[pausing delayed wait waitfor waiteval move matchwait actionwait actioninstant scripterror].freeze

      # The label AbortOnScriptError jumps to (Script.cs:1109-1125 R).
      SCRIPT_ERROR_LABEL = 'scripterror'

      # The `do` verb's internal matchwait label (GENIE_INTERNAL_ACTION_DO, Script.cs:20, 981 R).
      DO_LABEL = '550276ca-49f0-4067-aa5b-b3cba4869564'

      # Script.Trace's ring size (Trace.cs:8-9 R).
      TRACE_SIZE = 20

      # @param program [Lexer::Program]
      # @param variables [Variables]
      # @param name [String] script name (for messages)
      # @param game [#send_command]
      # @param input [#next_line]
      # @param echo [#call]
      # @param hooks [#emit]
      # @param clock [#call]
      # @param args [Array<String>] launch arguments, Genie's al[1..] (no $0 entry)
      # @param launch [#call] callable(name, args_string) to start another script
      # @param specials [Specials]
      # @param wall_clock [#call, nil] the wall clock (Time) the @-specials read (default
      #   Time.now; the flow harness passes genieflow's virtual clock)
      # @param broadcast [#call, nil] callable(text): deliver this script's `#parse` text to
      #   the global #triggers and to every script in list order (ParseTriggers,
      #   FormMain.cs:4425-4512 R) -- ParseDispatch.broadcast, which hands it to this
      #   interpreter (ParseDispatch.owner during the call) through {#deliver_parse} at its
      #   position, unless it is paused. nil = no host: offered to this script only.
      # @param var_broadcast [#call, nil] callable(name): deliver a GLOBAL variable change this
      #   script raised (`#var`, `#tvar`, `#svar`, `#math`) to the eval #triggers and every
      #   script (FormMain.TriggerVariableChanged, FormMain.cs:4725-4989 R) --
      #   VariableDispatch.broadcast, which hands it back to this interpreter (the thread's
      #   dispatch owner) through {#deliver_variable_change}. nil = no host: this script only.
      # @param queue [CommandQueue, #call, nil] the session's timed queue (the `send` verb,
      #   `#send`, `#do`, `#queue`, the `-` quick send), or a callable returning the current one
      #   (read at each use: a hot reload rebuilds Lich::Genie.command_queue); nil =
      #   a private one nobody drains (headless)
      # @param queue_owner [Object, nil] this script's host handle, stored with every item it
      #   queues so the host sends the released command as this script
      # @param host_error [#call, nil] callable(section, message): a fault Remix shows through
      #   HandleGenieException (the `send` verb's int.Parse, FormMain.cs:6846-6851 R); nil = an
      #   echo line
      # @param paused [#call, nil] callable => whether the host has paused this script (Lich's
      #   `;pause` / `#script pause`); nil = never paused. A paused script runs no row and takes no
      #   resume (Script.cs:1488-1492, 1731-1734 R); its host drops its input meanwhile
      # @param print [#call, nil] callable(text, kind) for Script.PrintError (:error), PrintText
      #   (:text: "[Script moving to scripterror label ...]", "[Script timeout ...]", the trace)
      #   and PrintDebug (:debug) lines -- each a main-window line in Remix (Script.cs:4340-4430 R);
      #   nil = the echo port
      # @param lists [Lists, nil] the session's global lists for the `#command` arms (#trigger,
      #   #class, #gag, #sub, #alias; {CommandRouter}); nil = a private set
      # @param log_dir [#call, nil] callable => where `#log` writes; nil = nowhere
      def initialize(program:, variables:, name: 'genie', args: [], game: nil, input: nil,
                     echo: nil, hooks: nil, clock: nil, launch: nil, mover: nil, specials: nil,
                     script_control: nil, broadcast: nil, wall_clock: nil, var_broadcast: nil, queue: nil,
                     queue_owner: nil, host_error: nil, paused: nil, print: nil, lists: nil, log_dir: nil)
        @program = program
        @vars = variables
        @name = name
        @abort_lock = Mutex.new # {#announce_abort}'s check-then-set (script thread vs genie_abort)
        @game = game
        @input = input
        @echo = echo || ->(_text) {}
        @print = print || ->(text, _kind) { @echo.call(text) }
        @file_name = (program.respond_to?(:file_name) ? program.file_name : program.files.first.to_s).dup.freeze
        @wall_clock = wall_clock || -> { Time.now }
        @trace = Trace.new(TRACE_SIZE)
        @debug_level = 0 # m_iDebugLevel (Script.cs:689 R)
        @timer_last_ms = 0.0 # m_dTimerLastTime (Script.cs:3034-3105 R)
        @do_text = '' # DoCommandText / DoCommandAdditionalRegex / DoCommandRepeatRegex / DoCommandMatchList
        @do_additional = ''
        @do_repeat = ''
        @do_match_list = []
        @row = nil # the row running now (oLine), for the file/row a script error names
        @run_started = nil
        @scripterror_end = nil
        @hooks = hooks
        @launch = launch || ->(_name, _args) {}
        @broadcast = broadcast
        @var_broadcast = var_broadcast
        @queue_source = CommandQueue.source(queue)
        @queue_owner = queue_owner
        @host_error = host_error || ->(section, message) { echo_line("[#{section}: #{message}]") }
        @paused = paused
        @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        @timer_start = nil
        @call_stack = CallStack.new
        # Wire @timer@ to this interpreter's script timer unless a custom Specials given.
        resolved_specials = specials || Specials.new(clock: @wall_clock, source: @vars, timer: -> { timer_text })
        @substitution = Substitution.new(variables: @vars, specials: resolved_specials)
        @eval = Eval.new(globals: GlobalsAdapter.new(@vars), on_unsupported: method(:warn_unsupported))
        # Command's own m_oEval (Command.cs:210 R): a `#eval`/`#if` never touches this script's
        # result list (and so never its $-args).
        @router = CommandRouter.new(
          vars: @vars, eval: Eval.new(globals: GlobalsAdapter.new(@vars), on_unsupported: method(:warn_unsupported)),
          hooks: @hooks, mover: mover,
          script_control: script_control, script_name: name,
          echo: ->(text) { echo_line(text) },
          send: ->(text) { game_send(text) },
          parse: ->(text) { parse_text(text) },
          var_changed: ->(name) { variable_broadcast(name) },
          launch: ->(script, args) { @launch.call(script, args) },
          queue: @queue_source, queue_owner: @queue_owner, globals: @substitution.method(:expand_globals),
          lists: lists, log_dir: log_dir, wall_clock: @wall_clock
        )
        @js_runtime = nil # m_JintEngine: made on first use (InitJintEngine, Script.cs:694-706 R)
        @js_block = false # bJSBlock: collecting the rows of a JavaScript block
        @js_block_source = +'' # sJSBlockContent
        @js_block_row = nil # the block's first row (iJsFileId / iJsBlockLine)
        @state = :running
        @aborted = false # Script.AbortScript ({#abort_script})
        @match_list = []
        @actions = ActionList.new
        @warned_patterns = {} # [verb, pattern] => true once warned about ({#warn_unsupported})
        # m_bStopRunning: an action goto taken while a row runs (its own `#parse`) stops the
        # row loop; reset when the actionwait/actioninstant state resumes (Script.cs:1653-1663,
        # 1861-1869, 2253 R).
        @stop_running = false
        @waitfor_pending = false # !m_bWaitForStringResume: set by waitfor/waitforre, cleared on its match
        @match_label = nil # m_sWaitForMatchLabel once m_bWaitForMatch
        # Remix runs a launched script's first rows before the timer's AddScripts puts it in
        # the ParseTriggers list (FormMain.cs:4689-4713, 3809-3835, 8345 R), so a `#parse`
        # issued before the script's first wait does not reach its own actions.
        @parse_listed = false
        # waiteval (Script.cs:672-673, 3439-3445 R): the armed text and whether a variable
        # change has satisfied it (true until the first waiteval).
        @waiteval_text = ''
        @wait_for_event = true
        # TickScript's other inputs (Script.cs:667-690 R): m_bWaitForPrompt / m_bWaitForMove start
        # true; m_oRoundTimeEnd starts at DateTime's default (long past: nil here).
        @wait_for_prompt = true
        @wait_for_move = true
        @rt_end = nil
        # Whether a DR packet is still arriving (see CHUNK_IDLE_SECONDS) and when its last game
        # item was read.
        @chunk_open = false
        @chunk_seen_at = nil
        # A waitfor / matchwait match a trigger-on-input line made waits for the next packet's end
        # (Remix's m_bBufferEnd false; {#buffer_wait}).
        @await_packet = false
        # The texts a variable change must be part of to matter to this script (see
        # {#wants_variable_change?}): the program's watching rows, then every eval-action key
        # registered at run time ({#do_action}). Replaced, never mutated: read on other threads.
        @watch_texts = self.class.watch_rows(program).freeze
        seed_args(args)
      end

      # AbortScript's line (Script.cs:1143-1158 R): "[Script aborted! (Run time: <s> seconds):
      # <file>]", the run time since the load (RunTimeSeconds, Script.cs:958-965 R) formatted
      # {0:F2} under 10 s, {0:F0} from 10 s. .NET's F formats round half to even on the exact
      # binary value (probed on .NET 10: 2.675 -> "2.67", 9.995 -> "9.99", 0.125 -> "0.12",
      # 12.5 -> "12"); Ruby's format('%.2f') would give "2.68" and "10.00" for the first two.
      # @param seconds [Float]
      # @param file_name [String]
      # @return [String]
      def self.abort_line(seconds, file_name)
        exact = seconds.to_r
        run_time = seconds < 10 ? format('%.2f', exact.round(2, half: :even)) : exact.round(0, half: :even).to_s
        "[Script aborted! (Run time: #{run_time} seconds): #{file_name}]"
      end

      # The `send` verb's delay prefix (FormMain.cs:6829-6843 R): chars that are VB IsNumeric
      # (an ASCII digit) or '.', up to the first other one; not a lone ".". int.Parse.
      # @param text [String]
      # @return [Array(Integer, String)] [delay seconds, the text to queue]
      # @raise [Error] int.Parse's FormatException / OverflowException message
      def self.send_delay(text)
        number = text[/\A[0-9.]*/]
        return [0, text] if number.empty? || number == '.'

        raise Error, "The input string '#{number}' was not in a correct format." unless number.match?(/\A\d+\z/)
        raise Error, 'Value was either too large or too small for an Int32.' if number.to_i > INT32_MAX

        [number.to_i, Text.net_trim(text[number.length..])]
      end

      # m_iDebugLevel: `debuglevel N` in the script, or the host's `#script debug N <name>`
      # (FormMain.Command_ScriptDebugLevel, FormMain.cs:6083 R).
      # @return [Integer]
      attr_accessor :debug_level

      # Run the program to completion. This interpreter is its thread's dispatch owner for the
      # whole run ({ParseDispatch.as_owner}): a `#parse` or a global variable change raised on
      # this thread -- by a row, an action, or a #trigger body a dispatch fired here -- reaches
      # it inline, like Remix's synchronous ParseTriggers / TriggerVariableChanged.
      # @return [void]
      def run
        @script_start ||= now # m_oScriptStart, set by LoadFile right before the first run (Script.cs:1996 R)
        ParseDispatch.as_owner(self) { run_states }
      end

      # One global variable change offered to this script by FormMain's script loop
      # (VariableDispatch.broadcast, FormMain.cs:4964-4969 R) inline, on its own thread: like a
      # `#parse` (see {#deliver_parse}) only once the script is in the list -- a global set
      # before the script's first wait does not reach its own eval actions (flow t125).
      #
      # A fault inside (an eval action's evaluator error) is caught like FormMain's script-loop
      # catch does (FormMain.cs:4970-4978 R, which echoes "Error in TriggerVariableChange" and
      # the message to the Debug window): one line here, and the script runs on.
      # @param name [String]
      # @return [void]
      def deliver_variable_change(name)
        listed_variable_changed(name) if @parse_listed
      end

      # An overflow of the nested-dispatch cap (20 levels; a decided divergence: Remix recurses
      # until the client crashes) in a variable-change chain this script started
      # (VariableDispatch): the script error, and the script stops.
      # @param message [String]
      # @return [void]
      def dispatch_overflow(message)
        abort_with(message, @call_stack.line_value)
        nil
      end

      # Whether a change of global +name+ queued for this script could do anything (asked by
      # VariableDispatch on the CHANGING thread: every queued entry takes a slot in
      # the script's bounded Lich buffer). Script.TriggerVariableChanged reacts only through an
      # eval action whose KEY contains the name or an armed waiteval whose RAW text contains it
      # (Script.cs:1358-1433 R; {#variable_changed}), so the change matters only if a watch text
      # contains +name+: a program row that can arm a waiteval or register an eval action
      # ({.watch_rows}: an `eval ` key and a waiteval text are literal parts of their row), or
      # the key of an eval action registered at run time (an `e/` key is expanded at
      # registration, `action x when %t` may become one; {#do_action}). Exact for literal rows;
      # anything a superset lets through is ignored by {#variable_changed}.
      #
      # Residual divergence (a timing race, not emulated): a change raised on another thread while this
      # script is in the tick that registers an eval action whose key is NOT a literal part of
      # its row (`e/%v = 1/` -> "$health = 1"; a substituted trigger) is dropped, where Remix's
      # TriggerVariableChanged waits for the script's tick lock and would then check it.
      # @param name [String]
      # @return [Boolean]
      def wants_variable_change?(name)
        @watch_texts.any? { |text| text.include?(name) }
      end

      # A row that can arm a waiteval or register an eval action, anywhere: its own row, an
      # `if ... then` row or an action body. A function is always a literal keyword (Lexer), and
      # EvalAction splits at a literal " when " and trims the trigger (Script.cs:3122-3220 R).
      WATCH_ROW = %r{waiteval| when\s+(?:eval |e/)}i

      # @param program [Lexer::Program]
      # @return [Array<String>] the contents of +program+'s rows matching {WATCH_ROW}
      def self.watch_rows(program)
        program.instructions.filter_map do |instruction|
          content = instruction.content.to_s
          content if WATCH_ROW.match?(content)
        end
      end

      # Script.TriggerParse (Script.cs:1179-1316 R): offer one line -- game text or a
      # `#parse` -- to this script, synchronously: a blank line is ignored; then the pending
      # waitfor/waitforre (in ANY state while it is pending, like m_bWaitForStringResume),
      # the matchwait list (only in the matchwait state), then every active action. Only
      # FLAGS are set here; the wait loops act on them (TickScript, Script.cs:1487-1690 R).
      # @param text [String]
      # @return [void]
      def trigger_parse(text)
        return if @state == :finished || @aborted
        return if Text.net_trim(text).empty?

        check_waitfor(text) if @waitfor_pending
        check_matchwait(text) if @state == :matchwait
        fire_actions(text)
      end

      # Script.AbortScript (Script.cs:1137-1176 R) from the host (`#script abort`, the dupe check of
      # a relaunch): ScriptDone and the finished state, so no further row runs -- RunScript's loop
      # checks the state before every row (Script.cs:1726-1730 R), so a script aborting itself
      # stops right after that row (a corpus stop label's `put #script abort all` / `put .cleanup`)
      # -- and no line, change or action reaches it (TriggerParse returns for a done script,
      # Script.cs:1181 R). May come from another thread: every loop re-checks the flag, so a state
      # the script thread sets afterwards cannot revive it. A script not finished yet prints
      # Remix's abort line first ({#announce_abort}).
      # @return [void]
      def abort_script
        announce_abort
        @aborted = true
        @state = :finished
      end

      # @return [Boolean] whether this script printed Remix's "[Script aborted! ...]" line: an
      #   AbortScript ({#abort_script}, or AbortOnScriptError with no `scripterror` label). The glue
      #   then lets Lich print no start/stop notice for it (no "--- Lich: x was killed." line).
      def abort_announced?
        @abort_announced ? true : false
      end

      # @return [Boolean] whether {#abort_script} stopped this script
      def aborted?
        @aborted
      end

      # A `#parse` line of a chain this script dispatches (ParseDispatch.owner): its own
      # `#parse` and a nested one from a #trigger it fired (TriggerRunner), handed back by
      # ParseDispatch.broadcast at this script's position in the list. ParseTriggers offers
      # it synchronously like to every other script (FormMain.cs:4488-4489 R), so it goes
      # straight to {#trigger_parse} -- once the script is in the ParseTriggers list (see
      # @parse_listed).
      #
      # A trigger-on-input line of this script's own send (ParseDispatch.input, +game+) is part
      # of a DR packet like a game line (ParseTriggers' bBufferWait, FormMain.cs:4425 R).
      # @param text [String]
      # @param game [Boolean]
      def deliver_parse(text, game: false)
        return unless @parse_listed

        game ? input_parse(text) : trigger_parse(text)
      end

      private

      def run_states
        @state = :running
        until @state == :finished || @aborted
          case @state
          when :running
            park_while_paused
            run_rows if @state == :running
            @parse_listed = true
          when *WAIT_STATES then await_resume
          else @state = :finished
          end
        end
      end

      # Adapts Variables to the #key? interface Eval's def()/defined() expects.
      class GlobalsAdapter
        def initialize(variables) = (@variables = variables)
        def key?(name) = @variables.global_key?(name)
      end

      # Seed the launch args into the %-locals only (%1..%9, %0, %argcount), even with
      # zero args; the base frame's $-arg list stays empty (Script.cs:2064-2082 R).
      # +args+ is Genie's al[1..] ({ScriptArgs.parse_launch}).
      def seed_args(args)
        ScriptArgs.seed(@vars, args)
      end

      def now
        @clock.call
      end

      # --- main row loop (RunScript) ----------------------------------------

      def run_rows
        # A run_rows entry is the initial start OR a resume from a wait
        # (matchwait/pause/waitfor/wait/move) -- i.e. the script just made real
        # progress (a game round-trip or a genuine wait), NOT a tight loop. Restart the
        # wall-clock deadline here (Genie takes oTimerStart per RunScript call,
        # Script.cs:1713 R).
        @run_started = now
        # A flag left by an action goto whose actionwait was replaced by a later action's
        # wait (goto, then `pause` in the same pass) must not stop this new loop after its
        # first row. Remix keeps it until a later RunScript row and can hang there (0 corpus);
        # we drop it here.
        @stop_running = false
        while @state == :running && !@aborted
          # A paused script stops before its next row and goes on from it once resumed
          # (RunScript's loop, Script.cs:1731-1734 R; ResumeScript, Script.cs:1079-1106 R).
          break if paused?

          index = @call_stack.line_value
          if index >= @program.instructions.length
            break unless !@js_block || run_js_block

            finish
            break
          end

          instruction = @program.instructions[index]
          debug(15) { "#{instruction.content} (#{Lexer::REMIX_NAMES.fetch(instruction.function, instruction.function.to_s)})" }
          if instruction.function == :jsblock
            collect_js_row(instruction)
            @call_stack.line_value = index + 1
            next
          end
          break unless end_js_block
          break if runaway?(instruction)

          on_blockstart if instruction.function == :blockstart
          on_blockend if instruction.function == :blockend

          if @call_stack.skip_block
            skip_row(instruction, index)
          else
            new_index = begin
              run_script_row(instruction, index)
            rescue Eval::Fault => e
              evaluator_fault(e, index)
            end
            # An action goto fired by this row's own `#parse` already moved the line pointer
            # to its label and set actionwait: stop here (m_bStopRunning, Script.cs:1861-1869 R).
            if @stop_running
              debug(30) { "Aborting previous thread: #{instruction.content}" }
              @stop_running = false
              break
            end

            # RunScript's `I++; LineValue = I` (Script.cs:1724-1726 R): also after a wait verb
            # or after an action changed the state, so the script resumes on the next row.
            @call_stack.line_value = new_index + 1 unless @state == :finished
          end
        end
      end

      def skip_row(instruction, index)
        @call_stack.skip_block = false if @call_stack.last_row_was_evaluation && instruction.function != :if_func
        @call_stack.line_value = index + 1
      end

      # --- block bookkeeping (spec section 2.2) -----------------------------

      def on_blockstart
        @call_stack.target_block_depth = @call_stack.block_count if @call_stack.skip_block && @call_stack.target_block_depth <= 0
        @call_stack.add_block(:noeval)
        @call_stack.last_row_was_evaluation = false
      end

      def on_blockend
        @call_stack.remove_block
        return unless @call_stack.skip_block && @call_stack.target_block_depth >= @call_stack.block_count

        @call_stack.skip_block = false
        @call_stack.target_block_depth = 0
      end

      # --- verb dispatch (RunScriptRow) -------------------------------------

      # RunScriptRow (Script.cs:2276-2858 R). A row that fails with a script error (PrintError +
      # AbortOnScriptError) returns 0 where Remix does `return default` (goto/gosub/return/label
      # errors), so an action body treats it as an action goto to row 0 like Remix (r02 shape).
      # Decided divergence ({AuthoredCommand}, security): only author-written text may issue a
      # Lich command. A .cmd row (+authored+) has its put/send argument author-marked before it
      # is expanded -- a `put` row's with the code mark, which survives only when the expansion
      # changed nothing at all (the row is literal); otherwise it becomes the provenance mark.
      # Whether the row is authored and literal is kept for the row's verb ({#do_put}: what its
      # `#trigger`/`#alias` define; {#do_action}). An action body's row is not authored: it comes
      # as +content+ (marked by {#run_action_row} before its `$n` when its action is authored)
      # with an +instruction+ that holds the clean text, for the error lines.
      # @return [Integer] the (possibly jumped) instruction index
      def run_script_row(instruction, index, authored: true, content: nil)
        previous = [@row, @row_authored, @row_literal]
        @row = instruction # oLine: the file and row a script error names
        content ||= instruction.content
        if authored && AuthoredCommand::SEND_VERBS.include?(instruction.function)
          content = AuthoredCommand.mark_argument(content, instruction.function, separator_char,
                                                  code: instruction.function == :put)
        end
        parsed = substitute(content)
        @row_authored = authored
        @row_literal = authored && parsed == content # raw == expanded
        parsed = AuthoredCommand.downgrade(parsed) unless @row_literal
        debug(10, instruction) { "[#{AuthoredCommand.strip(parsed)}]" }
        arg = Text.argument_string(parsed)
        script_row(instruction, index, arg)
      ensure
        @row, @row_authored, @row_literal = previous
      end

      def script_row(instruction, index, arg)
        case instruction.function
        when :echo then echo_line(arg)
        when :put then do_put(arg)
        when :send then do_send(arg)
        when :do_func then do_do(arg)
        when :move then return verb_debug('waitformove', arg) { do_move(arg, index) }
        when :nextroom then return verb_debug('nextroom', nil) { do_move('', index) }
        when :goto_func then return do_goto(arg, instruction)
        when :gosub_func then return do_gosub(arg, instruction, index)
        when :return_func then return do_return(instruction)
        when :label then return pass_label(instruction, index)
        when :exit_func then do_exit(instruction)
        when :save then local_set('s', arg)
        when :setvariable then do_setvariable(arg)
        when :deletevariable then do_deletevariable(arg)
        when :counter then do_counter(arg)
        when :math_func then do_math(arg)
        when :eval_func then do_eval(arg)
        when :evalmath_func then do_evalmath(arg)
        when :random then do_random(arg)
        when :shift then do_shift
        when :pause then return verb_debug('pause', arg) { do_pause(arg, index) }
        when :delay then return verb_debug('delay', arg) { do_delay(arg, index) }
        when :waitfor then return verb_debug('waitfor', arg) { do_waitfor(arg, index, regex: false) }
        when :waitforre then return verb_debug('waitforre', arg) { do_waitfor(arg, index, regex: true) }
        when :waiteval
          text = Text.argument_string(instruction.content)
          return verb_debug('waiteval', text) { do_waiteval(text, index) }
        when :wait then return verb_debug('wait', arg) { do_wait(arg, index) }
        when :match then add_match(arg, false, index)
        when :matchre then add_match(arg, true, index)
        when :matchwait then return verb_debug('matchwait', nil) { do_matchwait(arg, index) }
        when :if_func then do_if(instruction, arg)
        when :while_func then do_while(instruction, arg)
        when :else_func then do_else(instruction)
        when :action then do_action(Text.argument_string(instruction.content), instruction, authored: @row_authored)
        when :timer then do_timer(Text.argument_string(instruction.content))
        when :js then run_js(instruction)
        when :jscall then run_jscall(instruction)
        when :plugin then announce_unsupported('#plugin', arg)
        when :debuglevel then @debug_level = Numeric.string_to_integer(Text.argument_string(instruction.content))
        end

        index
      end

      # The level-2 debug line some verbs print first ("pause 1", "matchwait", ...;
      # Script.cs:2632-2768 R), then the verb.
      def verb_debug(verb, arg)
        debug(2, @row) { arg.nil? ? verb : "#{verb} #{arg}" }
        yield
      end

      # --- IO verbs ---------------------------------------------------------

      # EvalPut (Script.cs:3460-3467 R): only `put` sets %lastcommand, for any non-blank
      # text (a `#command` or `.script` too); send/do/move do not.
      # What the row defines (`put #trigger ...`, `put #alias ...`) is authored only when
      # the row is a literal .cmd row ({#run_script_row}).
      def do_put(arg)
        return if Text.net_trim(arg).empty?

        send_text(arg, defining: @row_literal)
        local_set('lastcommand', AuthoredCommand.strip(arg))
      end

      # Script.SendText(text) -> FormMain.Script_EventSendText with ToQueue false (FormMain.cs:
      # 6812-6823 R), for put and move: Command.ParseCommand(text, bSendToGame: text does not
      # START with the command char) -- so `put #echo a;look` never sends look -- as a top-level
      # Task nobody awaits: a fault ends that ParseCommand quietly and the script (or action
      # body) goes on ({ParseCommand#run}).
      # +defining+: whether a #trigger/#alias the text defines is authored (JS put and move: never).
      def send_text(text, defining: false)
        return if text.nil? || Text.net_trim(text).empty?

        AuthoredCommand.defining(defining) do
          @router.run(text, send_to_game: !AuthoredCommand.strip(text).start_with?(@router.config.command_char))
        end
      end

      # EvalSend (Script.cs:3469-3475 R) -> Script_EventSendText with ToQueue true (FormMain.cs:
      # 6826-6845 R): a leading run of digits and dots is the delay, int.Parse'd (`0.5`, `1.`,
      # `.5` and a value past Int32 throw: HandleGenieException shows it, nothing is queued);
      # the rest is Trim()med only after a delay; then ParseGlobalVars and AddToQueue(delay,
      # text, roundtime-gated). The queue's release runs it through ParseCommand (so `send
      # .x` launches and `send #var` sets), not this script. Never blocks: the script's RESUMES
      # are roundtime-gated ({#await_resume}), its sends are not (the v0.17.1 send stop-gap
      # is gone).
      # +restricted+: the `do` verb's item also waits out webbed and stunned (DoCommand).
      def do_send(arg, restricted: false)
        return if Text.net_trim(arg).empty?

        queue_send(arg, restricted: restricted)
      end

      # Script_EventSendText's ToQueue arm (FormMain.cs:6826-6845 R).
      def queue_send(arg, restricted: false)
        delay, text = begin
          self.class.send_delay(arg)
        rescue Error => e
          return @host_error.call('SendText', e.message)
        end
        text = @router.expand_globals(text)
        # The queue lists the clean text and releases the author-marked one (a `send ,go2 x` row)
        route = AuthoredCommand.marked?(text) ? text.freeze : nil
        @queue_source.call.add(delay, AuthoredCommand.strip(text), route: route, wait_rt: true, wait_webbed: restricted,
                                                                         wait_stunned: restricted, owner: @queue_owner)
      end

      # A game send from ParseCommand (after SendTextToGame). The host's send no longer waits
      # out roundtime (Remix gates resumes, not sends), but it may still block on Lich
      # (its pause checkpoint, a slow client write): push the deadline out by exactly the time
      # spent inside the send, so that is not "continuous loop time", while the loop's own row
      # time still counts: an endless wait-less `put look / goto` loop hits the script timeout
      # like Remix (Script.cs:1819-1830 R), it is not reset by every send.
      def game_send(text)
        sent_at = now
        @game&.send_command(text)
        @run_started += now - sent_at if @run_started
      end

      # Per-run watchdog (Script.cs:1819-1830 R): abort a continuous row loop that runs longer
      # than Config.iScriptTimeout ms with no wait yield (a goto loop that emits hooks/vars or game
      # sends alike): "[Script timeout in <file>(<row>): Possible infinite loop.]"
      # (GetFileAndRow, Script.cs:1697-1700 R), the trace, and the script ends (no scripterror).
      def runaway?(instruction)
        return false unless (now - @run_started) * 1000 > config.script_timeout

        file = @program.files[instruction.file_id].to_s
        print_text("[Script timeout in #{file}(#{instruction.file_row}): Possible infinite loop.]")
        print_trace
        finish
        true
      end

      # --- control flow -----------------------------------------------------

      # The gotofunc arm (Script.cs:2451-2477 R): an unknown label is a script error.
      def do_goto(arg, instruction)
        debug(1, instruction) { "goto #{arg}" }
        label = Text.net_downcase(arg)
        target = @program.labels[label]
        if target.nil?
          script_error("Unknown label from GOTO: #{label}", instruction)
          return 0
        end

        local_set('lastlabel', label)
        @call_stack.clear_blocks
        @trace.add("goto #{label}", file_label(instruction.file_id), instruction.file_row)
        target
      end

      # The gosubfunc arm (Script.cs:2479-2513 R): `gosub clear` empties the stack
      # (CurrentLine.Clear) and the row loop goes on; past Config.iMaxGoSubDepth frames (the base
      # frame counts) the new frame stays pushed, the error prints the trace, and the script
      # errors out.
      def do_gosub(arg, instruction, index)
        debug(1, instruction) { "gosub #{arg}" }
        label = Text.net_downcase(Text.keyword_string(arg))
        if label == 'clear'
          @call_stack.clear
          return index
        end

        target = @program.labels[label]
        if target.nil?
          script_error("Unknown label from GOSUB: #{label}", instruction)
          return 0
        end

        @trace.add("gosub #{label}", file_label(instruction.file_id), instruction.file_row)
        @call_stack.add_jump(index, Text.argument_string(arg))
        debug(40, instruction) { "Add jump (count = #{@call_stack.count})" }
        return target unless @call_stack.count > config.max_gosub_depth

        print_error("Maximum GOSUB depth (#{config.max_gosub_depth}) on: #{label}", instruction.file_id, instruction.file_row)
        print_trace
        abort_on_script_error
        0
      end

      # The returnfunc arm (Script.cs:2515-2539 R).
      def do_return(instruction)
        if @call_stack.remove_jump
          @trace.add('return', file_label(instruction.file_id), instruction.file_row)
          debug(1, instruction) { 'return' }
          debug(40, instruction) { "Remove jump (count = #{@call_stack.count})" }
          return @call_stack.line_value
        end

        print_error('RETURN command failed. There are no more gosub bookmarks to return to!', instruction.file_id, instruction.file_row)
        print_trace
        abort_on_script_error
        0
      end

      # The label arm (Script.cs:2541-2556 R): a label row the script runs into (or starts at:
      # a match, the scripterror jump) goes into the trace; inside a `{ }` block -- more than one
      # block level, the `if`'s own counts as one -- it is a script error.
      def pass_label(instruction, index)
        trimmed = Text.net_trim(instruction.content)
        name = trimmed.end_with?(':') ? trimmed[0...-1] : trimmed
        @trace.add("passing label #{name}", file_label(instruction.file_id), instruction.file_row)
        debug(1, instruction) { "passing label: #{name}" }
        return index unless @call_stack.block_count > 1

        script_error("Passing a LABEL from within a script block is not allowed: #{name}", instruction)
        0
      end

      # The exitfunc arm (Script.cs:2558-2569 R); Remix's "[Script finished ...]" line is Lich's
      # exit line here.
      def do_exit(instruction)
        @trace.add('exit', file_label(instruction.file_id), instruction.file_row)
        finish
      end

      # --- conditionals -----------------------------------------------------

      # EvalIfStatement (Script.cs:3560-3585 R): the condition is cut at the FIRST " then"
      # of the substituted text, evaluated, and a matchre() hit binds the frame's
      # $-args to Eval's result list ({#bind_capture_groups}).
      def do_if(instruction, arg)
        # sRowContent.Trim().ToLower().EndsWith(" then") (Script.cs:2573 R)
        @call_stack.last_row_was_evaluation = true if Text.net_downcase(Text.net_trim(instruction.content)).end_with?(' then')
        if eval_if_statement(arg)
          @call_stack.block_value = :evaltrue
        else
          @call_stack.block_value = :evalfalse
          @call_stack.skip_block = true
        end
      end

      # EvalWhileStatement (Script.cs:3587-3590 R): the WHOLE argument, " do" included, goes
      # to DoEval (`5 do` is the number 5 and the word "do").
      def do_while(instruction, arg)
        # NOTE: Genie's while has no back-edge; it behaves as an if-guard (spec 2.3).
        # sRowContent.ToLower().EndsWith("do"): untrimmed, no space (Script.cs:2593 R) -- a block
        # `while x do ` with a trailing space never sets it
        @call_stack.last_row_was_evaluation = true if Text.net_downcase(instruction.content).end_with?('do')
        if @eval.do_eval(eval_warned(arg, @row))
          @call_stack.block_value = :evalwhiletrue
        else
          @call_stack.block_value = :evalwhilefalse
          @call_stack.skip_block = true
        end
      end

      def do_else(instruction)
        # sRowContent.ToLower().EndsWith("else") (Script.cs:2613 R)
        @call_stack.last_row_was_evaluation = true if Text.net_downcase(instruction.content).end_with?('else')
        @call_stack.skip_block = true if @call_stack.block_value == :evaltrue
      end

      # `if (m_oEval.ResultList.Count > 0) m_oCurrentLine.ArgList = m_oEval.ResultList;`
      # (Script.cs:3263-3266, 3569-3572 R): a matchre() hit binds the frame's $-args to
      # Eval's ONE result list, by reference: the next evaluation empties them.
      def bind_capture_groups
        @call_stack.arg_list = @eval.result_list unless @eval.result_list.empty?
      end

      # --- variables / math -------------------------------------------------

      # EvalSetvariable / EvalDeletevariable (Script.cs:3536-3552 R): unvar removes the FIRST word
      # of its argument only, with no variable change.
      def do_setvariable(arg)
        debug(4, @row) { "setvariable #{arg}" }
        local_set(Text.keyword_string(arg), Text.argument_string(arg))
      end

      def do_deletevariable(arg)
        debug(4, @row) { "deletevariable #{arg}" }
        @vars.local_delete(Text.keyword_string(arg))
      end

      # EvalMath (Script.cs:3278-3291 R): a blank variable name does nothing.
      def do_math(arg)
        var = Text.keyword_string(arg)
        return if Text.net_trim(var).empty?

        debug(4, @row) { "math: #{arg}" }
        math_into(var, Text.argument_string(arg))
      end

      # EvalCounter (Script.cs:3310-3317 R): DoMath on %c.
      def do_counter(arg)
        debug(4, @row) { "counter: #{arg}" }
        math_into('c', arg)
      end

      # DoMath (Script.cs:3293-3333 R): an unknown operation is "Invalid MATH expression" +
      # AbortOnScriptError (DoMathCalc's catch, which returns 0), and the variable is set to 0
      # anyway -- when the script goes on to its scripterror label (r01 shape); once it stopped
      # Remix's set runs on cleared state (GenieError): ours stops there. Only the
      # calculation is rescued: the set's variable-change dispatch may raise the dispatch-cap overflow,
      # which must unwind to its outermost level.
      def math_into(var, expression)
        current = @vars.local_key?(var) ? Numeric.string_to_double(@vars.local_get(var)) : 0.0
        result = begin
          MathCalc.calc(current, expression)
        rescue Error
          script_error("Invalid MATH expression: #{expression}")
          return if @state == :finished

          0.0
        end
        debug(4, @row) { "math result: #{var}=#{Numeric.format_double(result)}" }
        local_set(var, Numeric.format_double(result))
      end

      # EvalEval (Script.cs:3254-3276 R): a matchre() hit binds the $-args to Eval's result
      # list BEFORE the set, whose variable change re-evaluates (an eval action's condition)
      # and so empties them again.
      def do_eval(arg)
        var = Text.keyword_string(arg)
        return if Text.net_trim(var).empty?

        value = @eval.eval_string(eval_warned(Text.argument_string(arg), @row))
        bind_capture_groups
        debug(4, @row) { "eval: #{arg}" }
        debug(4, @row) { "eval result: #{var}=#{value}" }
        local_set(var, value)
      end

      # EvalEvalMath (Script.cs:3220-3252 R): MathEval's InvalidCastException is a PrintError
      # (message + ". Local Variable <var> has been set to 0.") and the variable is set to 0;
      # either way the set raises the variable change (TriggerVariableChanged, Script.cs:3244,
      # 3250 R). A missing variable name does nothing.
      def do_evalmath(arg)
        var = Text.keyword_string(arg)
        return if Text.net_trim(var).empty?

        value = begin
          result = Numeric.format_double(MathEval.evaluate(Text.argument_string(arg)))
          debug(4, @row) { "evalmath: #{arg}" }
          debug(4, @row) { "evalmath result: #{var}=#{result}" }
          result
        rescue Error => e
          print_error("#{e.message}. Local Variable #{var} has been set to 0.")
          '0'
        end
        local_set(var, value)
      end

      # EvalRandom (Script.cs:2809, 3107-3120 R): min = the first word, max = the word after it
      # ("" -> "1" / "10"), each Utility.StringToInteger (-1 unless a positive Int32), then
      # Utility.RandomNumber = Random.Next(min, max + 1) (Utility.cs:251-255 R): Int32 arithmetic
      # (Int32.MaxValue + 1 wraps), one choice when min == max + 1, and an
      # ArgumentOutOfRangeException when min > max + 1 -- an evaluator-class fault (the script stops).
      RANDOM_SWAPPED = "'minValue' cannot be greater than maxValue. (Parameter 'minValue')"

      def do_random(arg)
        min_text = Text.keyword_string(arg)
        max_text = Text.keyword_string(Text.argument_string(arg))
        low = Numeric.string_to_integer(min_text.empty? ? '1' : min_text)
        high = Numeric.string_to_integer(max_text.empty? ? '10' : max_text)
        bound = high == 2_147_483_647 ? -2_147_483_648 : high + 1
        raise Eval::Fault, RANDOM_SWAPPED if low > bound

        value = low == bound ? low : rand(low...bound)
        @vars.local_set('r', value.to_s) # EvalRandom raises no variable change (Script.cs:3119 R)
      end

      # EvalShift (Script.cs:3003-3027 R): rotates the %-locals, never the $-arg list.
      # A fault (a %argcount VB cannot convert, or a missing slot below it) is caught by
      # RunScript / Script Action (Script.cs:1885-1888, 1310 R) and handed to GenieError.Error,
      # which Game.HandleGenieException re-raises without end (Game.cs:149-160, 3291-3294 R):
      # Remix's own client stack-overflows. Ours prints the .NET message as one error line
      # and stops the script: a decided divergence.
      def do_shift
        ScriptArgs.shift(@vars)
      rescue Error => e
        abort_with(e.message, @call_stack.line_value)
      end

      # --- waits ------------------------------------------------------------

      # Enter a wait state. The line pointer is left alone: the row loop moves it past this
      # row (RunScript, Script.cs:1724-1726 R), and a wait verb run from an action body
      # (index -1) leaves it where the script was (EvalPauseScript etc. only set the state).
      def enter_wait(state, index)
        yield if block_given?
        @state = state
        index
      end

      # EvalWaitEval (Script.cs:3439-3445 R): arm the wait with the RAW argument (expanded on
      # every check); only a variable change can satisfy it ({#check_waiteval}).
      def do_waiteval(text, index)
        @waiteval_text = text
        @wait_for_event = false
        enter_wait(:waiteval, index)
      end

      def do_pause(arg, index)
        @pause_end = timed_end(parse_seconds(arg, 1.0))
        enter_wait(:pausing, index)
      end

      def do_delay(arg, index)
        @delay_end = timed_end(parse_seconds(arg, 1.0))
        enter_wait(:delayed, index)
      end

      # EvalWait (Script.cs:3381-3393 R; EvalDoubleTime, Utility.cs:707-725 R): the prompt flag
      # cleared, the end N s away (a blank, non-positive or unparseable N is 1 s). TickScript
      # resumes on a prompt seen since then AND the end passed (Script.cs:1537-1548 R).
      def do_wait(arg, index)
        @wait_for_prompt = false
        @wait_end = timed_end(parse_seconds(arg, 1.0))
        enter_wait(:wait, index)
      end

      # EvalMove (Script.cs:3447-3458 R): a blank text (nextroom, a bare `move`) does nothing --
      # no state change, no send; otherwise the move flag is cleared, the state is move and the
      # text is sent. TickScript resumes once a room-desc component raised TriggerMove
      # (Script.cs:1585-1597 R).
      def do_move(arg, index)
        return index if Text.net_trim(arg).empty?

        @wait_for_move = false
        @state = :move
        send_text(arg)
        index
      end

      # EvalMatch (Script.cs:3351-3367 R) + ClassMatchList.Add (Script.cs:517-535 R). The
      # whole argument must equal "clear" (no trim); matchre validates the WHOLE argument,
      # label included, before splitting it; label and pattern are each trimmed; a matchre
      # pattern loses a leading `/` and a trailing `/i` (-> IgnoreCase) or `/`.
      def add_match(arg, regex, index)
        if Text.net_downcase(arg) == 'clear'
          @match_list = []
          return
        end
        return script_error("Invalid RegExp in matchre: #{arg}") if regex && !NetRegex.valid?(arg)

        add_match_entry(Text.net_trim(Text.argument_string(arg)), Text.net_trim(Text.keyword_string(arg)), regex, index)
      end

      # ClassMatchList.Add (Script.cs:517-535 R): a regex pattern loses a leading `/` and a
      # trailing `/i` (-> IgnoreCase) or `/`; the label is lowercased when it matches
      # (Script.cs:1239, 1257 R).
      def add_match_entry(pattern, label, regex, index)
        compiled = nil
        if regex
          pattern, ignore_case = slash_delimited(pattern)
          begin
            compiled = NetRegex.compile(pattern, ignore_case: ignore_case)
          rescue StandardError => e
            # The label-included check passed but the bare pattern does not compile:
            # Remix's `new Regex` throws inside RunScriptRow -> RunScript catch ->
            # GenieError (Script.cs:1885-1888 R), which overflows Remix's stack.
            # Decided: one error line, the script stops.
            return abort_with("Invalid pattern '#{pattern}': #{e.message}", index)
          end
        end
        warn_unsupported(compiled, 'matchre')
        @match_list << { label: Text.net_downcase(label), pattern: pattern, regex: regex, compiled: compiled }
      end

      # The `/re/` and `/re/i` delimiters of ClassMatchList.Add (Script.cs:521-533 R) and
      # EvalWaitString (Script.cs:3402-3416 R). @return [[String, Boolean]] pattern, ignore_case
      def slash_delimited(text)
        text = text[1..] if text.start_with?('/')
        return [text[0...-2], true] if text.end_with?('/i')
        return [text[0...-1], false] if text.end_with?('/')

        [text, false]
      end

      # EvalWaitString (Script.cs:3395-3437 R). A blank argument is a no-op for waitfor and
      # an "Invalid RegExp" abort for waitforre (Script.cs:2676-2684 R). waitforre strips
      # the `/re/i` delimiters but ignores the `i` (m_bWaitForStringIgnoreCase is commented
      # out), validates, and compiles once; waitfor keeps its text as given (case-sensitive
      # ordinal Contains, leading spaces kept).
      def do_waitfor(arg, index, regex:)
        if Text.net_trim(arg).empty?
          script_error("Invalid RegExp in waitforre: #{arg}") if regex
          return index
        end

        text = arg
        @wait_regex = nil
        if regex
          text, _ignored = slash_delimited(text)
          begin
            @wait_regex = NetRegex.compile(text)
          rescue StandardError
            script_error("Invalid RegExp in waitforre: #{arg}")
            return index
          end
          warn_unsupported(@wait_regex, 'waitforre')
        end
        @wait_text = text
        @waitfor_pending = true
        enter_wait(:waitfor, index)
      end

      def do_matchwait(arg, index)
        seconds = arg.strip.empty? ? 0 : Numeric.string_to_double(arg)
        @match_timeout = seconds.positive? ? timed_end(seconds) : nil
        @match_label = nil # EvalMatchWait: m_bWaitForMatch = false (Script.cs:3347 R)
        @state = :matchwait
        index
      end

      # TriggerParse's waitfor half (Script.cs:1197-1222 R): plain = case-sensitive Contains
      # on the untrimmed line; regex = Match on the TRIMMED line, whose groups (0..n) replace
      # the $-arg list.
      def check_waitfor(text)
        if @wait_regex
          match = @wait_regex.match(Text.net_trim(text))
          return unless match

          @call_stack.arg_list.replace(match.to_a.map(&:to_s))
        else
          return unless text.include?(@wait_text)
        end
        @waitfor_pending = false
        buffer_wait
      end

      # SetBufferWait (Script.cs:2098-2104 R) for a match made by a trigger-on-input line (its
      # TriggerParse has bBufferWait = true but is not part of a game packet): the waitfor /
      # matchwait resumes only at the end of the NEXT game packet (m_bBufferEnd is set by
      # SetBufferEnd, at the end of received data; FormMain.cs:5620-5643 R) -- the reply to the
      # command usually -- or never, when no game data comes (flow t171). A game line's match is
      # covered by the packet it is part of ({#game_item}); so is an input line that arrives while
      # a packet is still arriving (Remix's next SetBufferEnd is that packet's
      # end). Only the waitfor and matchwait (match) resumes wait for it (Script.cs:1551, 1600 R;
      # waitdo is not ported): an action goto out of the wait, a `pause`, a matchwait timeout
      # resume at once. The flag stays set across such a state change until
      # the next packet, as m_bBufferEnd does (only SetBufferEnd resets it, Script.cs:1021-1023 R).
      def buffer_wait
        @await_packet = true if @input_line && !@chunk_open
      end

      # TriggerParse's matchwait half (Script.cs:1229-1272 R): the first hit wins and clears
      # the list; match = Contains on the untrimmed line, matchre = Match on the trimmed line
      # (groups 0..n -> the $-arg list).
      def check_matchwait(text)
        @match_list.each do |entry|
          if entry[:regex]
            match = entry[:compiled].match(Text.net_trim(text))
            next unless match

            @call_stack.arg_list.replace(match.to_a.map(&:to_s))
          else
            next unless text.include?(entry[:pattern])
          end
          @match_label = entry[:label]
          @match_list = []
          buffer_wait
          break
        end
      end

      # A `#parse` issued by this script (router parse port). ParseTriggers
      # (FormMain.cs:4425-4512 R): the global #triggers, then every script in list order --
      # this one included, inline, at its own position: the +broadcast+ host
      # (ParseDispatch.broadcast) calls back {#deliver_parse} for it, and skips it while it
      # is paused. No buffering into its own input, so a later matchwait never sees it.
      # Without a host it is only offered to itself. The nested-dispatch cap stops a nested chain with a
      # script error.
      #
      # Time spent inside +broadcast+ is excluded from the runaway deadline, like a send's
      # time (see #game_send): the global #triggers fire on THIS thread, and their work is not
      # this script's row loop. (This script's own actions fired inside it are covered too.)
      #
      # This interpreter is the thread's dispatch owner for the whole chain
      # (ParseDispatch.as_owner), so a nested trigger-body `#parse` reaches it inline too.
      def parse_text(text)
        DispatchDepth.nest("#parse #{text}", on_overflow: ->(message) { abort_with(message, @call_stack.line_value) }) do
          ParseDispatch.as_owner(self) do
            if @broadcast
              started = now
              @broadcast.call(text)
              @run_started += now - started if @run_started
            else
              deliver_parse(text)
            end
          end
        end
      end

      # One item read from the input (in a wait, or while paused), in arrival order -- Remix
      # handles each on its own thread as it arrives, under the script's lock, which a running
      # row loop holds, so an item arriving meanwhile is handled in the wait state the loop
      # ends in (Script.cs:1186, 1365, 1440, 1467, 1703 R); ours waits on the input there:
      #   * a game line (a plain String): {#trigger_parse}; it is part of a DR packet;
      #   * a `#parse` queued by another script (ParseDispatch::Line): {#trigger_parse},
      #     continuing the dispatch-depth count it was issued at, so a chain that hops between scripts is
      #     capped like the synchronous Remix recursion (past the cap this script stops); a
      #     trigger-on-input line (Line#game?) is part of a DR packet too;
      #   * a batch of global variable changes (VariableDispatch::Change): {#offer_changes}; a
      #     game row's batch is part of its packet;
      #   * GameEvents::RoundTimeEnd: Script.SetRoundTime (m_oRoundTimeEnd, Script.cs:999-1007 R);
      #   * GameEvents::Move: TriggerMove (m_bWaitForMove = true, Script.cs:1434-1458 R);
      #   * GameEvents::Prompt: TriggerPrompt (m_bWaitForPrompt = true, Script.cs:1460-1485 R),
      #     then the prompt text through {#trigger_parse} like a game line, then the end of
      #     the packet (Remix's SetBufferEnd, FormMain.cs:5620-5643 R).
      def receive(item)
        case item
        when VariableDispatch::Change
          game_item if item.game?
          offer_changes(item)
        when GameEvents::RoundTimeEnd
          game_item
          @rt_end = item.ends_at
        when GameEvents::Move
          game_item
          @wait_for_move = true
        when GameEvents::Prompt
          game_item
          @wait_for_prompt = true
          trigger_parse(item.text) if item.text
          @chunk_open = false
        when GameEvents::Resumed then nil # only wakes the park ({#park_while_paused})
        when ParseDispatch::Line
          DispatchDepth.resume_at(item.dispatch_depth, on_overflow: ->(message) { abort_with(message, @call_stack.line_value) }) do
            item.game? ? input_parse(item) : trigger_parse(item)
          end
        else
          game_item
          trigger_parse(item)
        end
      end

      # A game item opens (or continues) the packet in progress -- the one a trigger-on-input
      # match waits for ({#buffer_wait}), whose end resumes it like any packet's.
      def game_item
        @chunk_open = true
        @chunk_seen_at = now
        @await_packet = false
      end

      # TriggerParse(text, bBufferWait = true) for a trigger-on-input line ({ParseDispatch.input}):
      # a waitfor / matchwait it satisfies waits for the next game packet's end ({#buffer_wait}).
      def input_parse(text)
        @input_line = true
        trigger_parse(text)
      ensure
        @input_line = false
      end

      # Each name of a queued VariableDispatch::Change in raise order, through
      # {#listed_variable_changed}, continuing the dispatch-depth count it was raised at (like a queued
      # `#parse`); once the script stopped the rest are no-ops ({#variable_changed}).
      def offer_changes(change)
        change.entries.each do |name, depth|
          DispatchDepth.resume_at(depth, on_overflow: method(:dispatch_overflow)) { listed_variable_changed(name) }
        end
      end

      # @return [Boolean] whether the host has paused this script
      def paused?
        @paused&.call ? true : false
      end

      # A paused script in the running state (paused mid-run, or before its first row) runs no
      # row until it is resumed. Its host drops the input that arrives while it is paused
      # (TriggerParse / TriggerVariableChanged / TriggerPrompt / TriggerMove return for a paused
      # script, Script.cs:1179-1184, 1360-1363, 1434-1485 R; GameEvents.kept_while_paused?), so
      # what is read here arrived before the pause (Remix handles it once the row loop lets go
      # of the lock) or is a roundtime (SetRoundTime has no pause check). An item that moves the
      # script to another state (an action goto) ends the park: {#await_resume} goes on waiting.
      def park_while_paused
        while @state == :running && !@aborted && paused?
          item = @input&.next_line(timeout: PAUSE_POLL_SECONDS)
          receive(item) if item
        end
      end

      # TickScript for the current wait state (Script.cs:1487-1664 R): every item is
      # {#receive}d as it arrives, and the wait resumes once
      #   1. the script is not paused (TickScript returns for a paused script, Script.cs:
      #      1488-1492 R),
      #   2. no DR packet is arriving: Remix ticks every 10 ms on its UI thread while the socket
      #      thread parses a packet; genieflow (the parity target, deterministic row delivery)
      #      never ticks inside a packet, and neither do we -- so a match on the packet's first
      #      line resumes only after its later lines and variable changes are handled (the
      #      waitfor/matchwait m_bBufferEnd, Script.cs:1551, 1600, 2098-2104 R; the same holds for
      #      every other state's flag set mid-packet). Not emulated (decided): Remix's Channel race
      #      that can push a resume one packet later (t49) and its 100 ms lock-wait drop,
      #   3. it is not in roundtime, unless the state is `delayed` or `actioninstant`
      #      (Script.cs:1505-1511 R),
      #   4. the state's own condition holds ({#resume_ready}).
      # An item that changes the state (an action goto -> actionwait, a `pause` in an action body,
      # a fault that finished the script) ends this wait; the run loop then handles the new state
      # (TickScript only looks at the CURRENT state).
      def await_resume
        state = @state
        loop do
          return unless @state == state && !@aborted
          next if chunk_idle_check
          return if !paused? && !@chunk_open && !roundtime?(state) && resume_ready(state)

          item = @input&.next_line(timeout: wake_after(state))
          receive(item) if item
        end
      end

      # A packet with no prompt ends once no further game row came for CHUNK_IDLE_SECONDS --
      # but an item already waiting on the input (read late because the script was busy) is
      # still part of it.
      # @return [Boolean] whether an item was received (the caller re-checks its state)
      def chunk_idle_check
        return false unless @chunk_open && now >= @chunk_seen_at + CHUNK_IDLE_SECONDS

        item = @input&.next_line(timeout: 0)
        if item
          receive(item)
          return true
        end

        @chunk_open = false
        false
      end

      # @return [Boolean] whether +state+ is held by the roundtime (Script.cs:1505-1511 R)
      def roundtime?(state)
        !RT_EXEMPT.include?(state) && !@rt_end.nil? && now < @rt_end
      end

      # How long {#await_resume} may block on the input before something it waits for is due:
      # the state's own deadline, the roundtime's end, the packet's idle end, the pause poll --
      # the next one still ahead (a passed deadline that cannot resume yet waits on the others).
      # nil = until the next item.
      # @return [Float, nil]
      def wake_after(state)
        current = now
        due = [state_deadline(state), roundtime?(state) ? @rt_end : nil, @chunk_open ? @chunk_seen_at + CHUNK_IDLE_SECONDS : nil,
               paused? ? current + PAUSE_POLL_SECONDS : nil].compact.select { |at| at > current }.min
        due && (due - current)
      end

      # @return [Float, nil] when +state+ can resume on time alone
      def state_deadline(state)
        case state
        when :pausing then @pause_end
        when :delayed then @delay_end
        when :wait then @wait_for_prompt ? @wait_end : nil
        when :matchwait then @match_timeout
        when :actionwait, :actioninstant then @actionwait_end
        when :scripterror then @scripterror_end
        end
      end

      # TickScript's state arms (Script.cs:1513-1664 R); resumes the script when the arm fires.
      # @return [Boolean] whether it resumed (or jumped, or stopped)
      def resume_ready(state)
        ready = case state
                when :scripterror then return resume_script_error # Script.cs:1498-1503 R
                when :pausing then now >= @pause_end # Script.cs:1513-1523 R
                when :delayed then now >= @delay_end # Script.cs:1525-1535 R
                when :wait then @wait_for_prompt && now >= @wait_end # Script.cs:1537-1548 R
                when :waitfor then !@waitfor_pending && !@await_packet # & m_bBufferEnd, Script.cs:1549-1559 R
                when :waiteval then @wait_for_event # Script.cs:1573-1583 R
                when :move then resume_move # Script.cs:1585-1597 R
                when :matchwait then return resume_matchwait
                when :actionwait, :actioninstant then resume_action # Script.cs:1653-1663 R
                end
        if ready
          debug(20) { RESUME_DEBUG[state] }
          @state = :running
        end
        ready ? true : false
      rescue Eval::Fault => e
        # TickScript's catch (Script.cs:1660-1664 R): GenieError("TickScript"). Reached by
        # the matchwait arm's %lastlabel set, whose TriggerVariableChanged runs the eval actions
        # (Script.cs:1608-1609 R).
        evaluator_fault(e, @call_stack.line_value)
        true
      end

      # TickScript's debug line for each resumed state (Script.cs:1517-1659 R).
      RESUME_DEBUG = {
        pausing: 'Resume ScriptState.Pausing', delayed: 'Resume ScriptState.Delayed', wait: 'Resume ScriptState.Wait',
        waitfor: 'Resume ScriptState.WaitFor', waiteval: 'Resume ScriptState.WaitForEvent', move: 'Resume ScriptState.Move',
        actionwait: 'Resume ScriptState.ActionWait', actioninstant: 'Resume ScriptState.ActionWait'
      }.freeze

      # The scripterror arm (Script.cs:1498-1503 R), first in TickScript (before the roundtime
      # check): on the next tick the script runs from its `scripterror` label.
      def resume_script_error
        return false unless now >= @scripterror_end

        @state = :running
        @call_stack.line_value = @program.labels.fetch(SCRIPT_ERROR_LABEL)
        true
      end

      # The move arm: RunScript, then m_bWaitForMove = false (Script.cs:1585-1597 R; nothing can
      # set it in between: RunScript holds the script's lock). Not observable on its own -- every
      # `move` clears the flag again at entry ({#do_move}) -- but kept as Remix has it.
      def resume_move
        return false unless @wait_for_move

        @wait_for_move = false
        true
      end

      # The actionwait/actioninstant arm (Script.cs:1653-1663 R): on the next tick, m_bStopRunning
      # = false and RunScript from the action's label (the line pointer is on it already).
      def resume_action
        return false unless now >= @actionwait_end

        @stop_running = false
        true
      end

      # TickScript's matchwait arm (Script.cs:1598-1650 R): a match first, else the timeout
      # -- checked on EVERY pass, even while lines keep arriving.
      # The line pointer already sits on the row after the matchwait (the row loop moved
      # it), so a timeout just resumes there (RunScript(), Script.cs:1634-1647 R).
      # @return [Boolean]
      def resume_matchwait
        return true if !@await_packet && take_match # m_bWaitForMatch & m_bBufferEnd (Script.cs:1600 R)
        return false unless @match_timeout && now >= @match_timeout

        debug(2) { 'matchwait TIMEOUT!' }
        @trace.add('matchwait timeout')
        @match_list = []
        @state = :running
        true
      end

      # Jump to the matched label (Script.cs:1600-1632 R); `do`'s internal label repeats the
      # command and the script stays in its matchwait (ScriptInternalLabels, RepeatDoCommand,
      # Script.cs:1622-1625, 3519-3531 R). An unknown label is a script error (no row).
      # @return [Boolean] true when a match was pending
      def take_match
        label = @match_label
        return false if label.nil?

        @match_label = nil
        @match_list = []
        target = @program.labels[label]
        if target.nil?
          if label == DO_LABEL
            repeat_do_command
            return true
          end

          print_error("Unknown label from MATCH command: #{label}")
          abort_on_script_error
          return true
        end
        debug(20) { 'Resume ScriptState.MatchWait' }
        local_set('lastlabel', label)
        @trace.add("match #{label}")
        debug(2) { "match goto #{label}" }
        # An eval action on %lastlabel that jumped, paused or aborted keeps its state (Remix runs
        # RunScript(label) regardless: a tracked divergence, 0 corpus).
        return true unless @state == :matchwait

        @call_stack.clear_blocks
        @call_stack.line_value = target
        @state = :running
        true
      end

      # --- variable changes (TriggerVariableChanged) ----------------------------

      # Script.TriggerVariableChanged (Script.cs:1358-1433 R), synchronously on this thread: a
      # local set ({#local_set}), a global change offered by FormMain's script loop
      # ({#deliver_variable_change}, or queued: {#receive}). Every active eval action whose
      # key CONTAINS +name+ fires when the key equals +name+ or EvalString(ParseVariables(key))
      # is non-empty and not "0", in SortedList order, with no groups and $0 = +name+
      # (ParseAction(key, new ArrayList(), name)); an abort ends the pass. Then the armed
      # waiteval ({#check_waiteval}). Each FIRING is one dispatch-depth level (a condition
      # checked false nests nothing): a body that sets a variable re-enters here (Remix's
      # Monitor is re-entrant and recursion is unbounded, crashing the client: decided nested-dispatch cap,
      # script error + stop).
      def variable_changed(name)
        return if @state == :finished || @aborted
        return unless @actions.eval_entries.any? { |entry| entry.key.include?(name) } || waiteval_watches?(name)

        @actions.eval_entries.each do |entry|
          next unless @actions.current?(entry) && entry.active && entry.key.include?(name)
          next unless eval_true?(entry.key, name)

          DispatchDepth.nest("variable change #{name}", on_overflow: method(:dispatch_overflow)) do
            parse_action(entry, [], name)
          end
          break if @state == :finished
        end
        check_waiteval(name) unless @state == :finished
      end

      # A global change offered by FormMain's script loop, inline or queued: its catch
      # (FormMain.cs:4970-4978 R) contains a fault (see {#deliver_variable_change}).
      def listed_variable_changed(name)
        variable_changed(name)
      rescue DispatchDepth::Exceeded
        raise
      rescue StandardError => e
        echo_line("[Error in TriggerVariableChange: #{e.message}]")
      end

      # The waiteval half of TriggerVariableChanged (Script.cs:1407-1424 R): an armed text that
      # contains +name+ and now evaluates true satisfies the wait (checked in every state; the
      # flag stays set until the next waiteval).
      def check_waiteval(name)
        @wait_for_event = true if waiteval_watches?(name) && eval_true?(@waiteval_text, name)
      end

      def waiteval_watches?(name)
        !@wait_for_event && @waiteval_text.include?(name)
      end

      # TriggerVariableChanged's condition (Script.cs:1377-1386 R): equal to the name -> true
      # unevaluated; otherwise the expanded text through EvalString.
      def eval_true?(text, name)
        text == name || VariableDispatch.truthy?(@eval.eval_string(eval_warned(substitute(text), nil)))
      end

      # A global change this script raised (router var port: `#var`, `#tvar`, `#svar`, `#math`;
      # Command.VariableChanged, Command.cs:933-1042 R): the host's VariableDispatch.broadcast
      # (eval #triggers, then every script, this one inline). With no host, FormMain's loop is
      # this script alone.
      def variable_broadcast(name)
        if @var_broadcast
          @var_broadcast.call(name)
        elsif !VariableDispatch::BLOCKED.include?(name)
          deliver_variable_change(name)
        end
      end

      # --- actions (EvalAction / TriggerParse / ParseAction) ------------------

      # EvalAction (Script.cs:3122-3220 R). +text+ is GetArgumentString of the UNEXPANDED row
      # (an action body's row after its $n pass), so it may start with a space -- then no
      # `(class)` prefix is recognised anywhere (`action  (c) ...`). Forms:
      #   * `(class) on|off|1|0|true|false|activate|inactivate` -> SetClass;
      #   * `remove <pattern>` (expanded unless it starts with `eval `), `clear`;
      #   * `[add|instant] <body> when <trigger>`: split at the FIRST literal " when "; the
      #     trigger is Trim()med and variable-expanded unless it starts with `eval ` (an `e/`
      #     trigger IS expanded); the body keeps any `(class)` prefix for ClassActionList.Add.
      #     With a `(class)` prefix the keyword is the class, so `action (c) add|instant ...`
      #     keeps "add"/"instant" as the body's first word (a silent no-op when it fires).
      # No " when " -> "Invalid ACTION command" + abort; an invalid regex -> "Invalid RegExp
      # in action" + abort. Classes are the script's own ClassActionList, not #class.
      # The action is authored (its body's `,`/`;` rows may be Lich commands) when its
      # `action` row is a .cmd row (+authored+), not an action body's row.
      def do_action(text, instruction = nil, authored: false)
        if text.start_with?('(') && (close = text.index(')'))
          klass = Text.net_trim(text[1...close].downcase)
          case Text.keyword_string(Text.net_trim(text[(close + 1)..])).downcase
          when '0', 'off', 'false', 'inactivate'
            debug(4, instruction) { "class off: #{klass}" }
            return @actions.set_class(klass, false)
          when '1', 'on', 'true', 'activate'
            debug(4, instruction) { "class on: #{klass}" }
            return @actions.set_class(klass, true)
          end
        end

        instant = false
        case Text.keyword_string(text).downcase
        when 'remove'
          pattern = Text.argument_string(text)
          pattern = substitute(pattern) unless pattern.downcase(:ascii).start_with?('eval ')
          return @actions.remove(pattern)
        when 'clear' then return @actions.clear
        when 'add' then text = Text.argument_string(text)
        when 'instant'
          instant = true
          text = Text.argument_string(text)
        end

        split = text.downcase(:ascii).index(' when ')
        return script_error("Invalid ACTION command: #{text}", instruction) if split.nil?

        trigger = Text.net_trim(text[(split + 6)..])
        trigger = substitute(trigger) unless trigger.downcase(:ascii).start_with?('eval ')
        added = @actions.add(trigger, text[0...split], file_id: instruction&.file_id.to_i, file_row: instruction&.file_row.to_i,
                                                       instant: instant, authored: authored)
        return script_error("Invalid RegExp in action: #{text}", instruction) unless added

        key = TriggerFile.normalize(trigger)
        add_watch_text(key.key) if key.eval
        warn_unsupported(@actions[TriggerFile.normalize(trigger).key].regex, 'action')
      end

      # Watch an eval action key registered at run time (see {#wants_variable_change?}). A key a
      # watch text already contains adds nothing -- every name it contains is wanted already --
      # so an `action ... when eval ...` re-registered in a loop does not grow the list that
      # every change scans on Lich's parser thread.
      def add_watch_text(key)
        return if @watch_texts.any? { |text| text.include?(key) }

        @watch_texts = [*@watch_texts, key].freeze
      end

      # A .NET-valid pattern NetRegex cannot match (NetRegex::Unsupported, e.g. a
      # variable-length lookbehind inside a quantified group) is registered like Remix does,
      # never fires, and gets ONE warning line per script and pattern instead of the abort an
      # invalid pattern gets (a decided divergence). An `action` re-registered in a
      # loop warns once.
      def warn_unsupported(compiled, where)
        return unless compiled.is_a?(NetRegex::Unsupported)
        return if @warned_patterns.key?([where, compiled.pattern])

        @warned_patterns[[where, compiled.pattern]] = true

        echo_line(compiled.warning(where))
      end

      # TriggerParse's action half (Script.cs:1281-1305 R): every active non-eval action, in
      # SortedList order, matched against the UNTRIMMED line; all matching actions fire (an
      # action goto does not stop the later ones -- the last goto wins); a finished script
      # stops the pass. The list is walked as a snapshot: an action that a body removed or
      # re-registered mid-pass is skipped (Remix's enumerator throws "Collection was
      # modified" there, a GenieError that kills the client; tracked divergence, 0 corpus).
      def fire_actions(line)
        @actions.to_a.each do |entry|
          next unless @actions.current?(entry)

          if entry.active && !entry.eval
            match = entry.regex.match(line)
            parse_action(entry, match.to_a.drop(1).map(&:to_s), line) if match
          end
          break if @state == :finished
        end
      rescue Eval::Fault => e
        # TriggerParse's catch (Script.cs:1306-1309 R): GenieError("Script Action").
        evaluator_fault(e, @call_stack.line_value)
      end

      # An exception from Eval/MathEval that Remix lets reach RunScript's or TriggerParse's
      # catch (Script.cs:1306-1309, 1885-1888 R): GenieError.Error, which Remix's own client
      # re-raises without end (Game.cs:149-160, 3291-3294 R). Decided divergence: the fault's message
      # (.NET's text; an invalid pattern's reason is Onigmo's) as one error line, and the script
      # stops. Also TickScript's catch (Script.cs:1660-1664 R, {#resume_ready}).
      # @param fault [Eval::Fault]
      # @param index [Integer]
      # @return [Integer]
      def evaluator_fault(fault, index)
        abort_with(fault.message, index)
      end

      # ParseAction (Script.cs:2119-2270 R). The body is SafeSplit on the separator char
      # (Config.cSeparatorChar, `;` by default, Script.cs:2135 R; Remix's quirks,
      # {Text.remix_safe_split}); each row, UNTRIMMED:
      #   1. a leading `%` -> `setvariable ...`, a leading `$` -> `put #var ...`, every " = "
      #      -> " ";
      #   2. its function is looked up from the first word CASE-SENSITIVELY (`Put` or an
      #      unknown word or a bare `#var ...` is a silent no-op);
      #   3. `$1`..`$15` -> the groups (quotes removed, "" when missing, replaced low to high,
      #      so `$10` is `$1` + "0"), then `$0` -> the whole line, quotes removed; `\$` escapes;
      #   4. `if <c> then <cmd>` evaluates <c> (expanded) and runs <cmd> as the row; a
      #      gosub/block/return row is a script error + abort;
      #   5. the row runs through the normal row executor ({#run_script_row}, which expands it
      #      again: a group holding `%x` is expanded too), so every verb works.
      # A row that jumps (goto, or gosub/return reached through `if ... then`) is an action
      # goto: the rest of this body is skipped. A finished script stops the body (Remix runs
      # on and then dies in a GenieError).
      def parse_action(entry, args, line)
        debug(5, entry) { "action triggered: #{entry.key}" }
        debug(5, entry) { "action commands: #{entry.action}" }
        Text.remix_safe_split(entry.action, @router.config.separator_char).each do |row|
          break if run_action_row(entry, row, args, line) == :stop
        end
      end

      # One row of {#parse_action}. @return [:stop, nil] :stop ends the body
      def run_action_row(entry, row, args, line)
        text = action_row_prefix(row)
        function = Lexer.function_type(Text.keyword_string(text))
        text = mark_action_row(text, function) if entry.authored # before the captures go in
        text = action_arguments(text, args, line) if text.include?('$')
        if function == :if_func
          text, function = action_if(text, entry)
          return :stop if @state == :finished
          return if text.nil?
        elsif (verb = ACTION_FORBIDDEN[function])
          print_error("#{verb} is not allowed from an ACTION command!")
          abort_on_script_error
          return :stop
        end

        # the marked text runs; the row a script error or a debug line names is the clean one
        line_ref = Lexer::Instruction.new(entry.file_id, entry.file_row, AuthoredCommand.strip(text), function)
        target = run_script_row(line_ref, -1, authored: false, content: text)
        return :stop if @state == :finished
        return unless target > -1

        debug(1, line_ref) { "action goto: #{entry.key}" }
        @trace.add('action goto', file_label(entry.file_id), entry.file_row)
        action_goto(target, entry.instant)
        :stop
      end

      # {AuthoredCommand}: an authored action's body row as the author wrote it, its
      # put/send argument marked (never with the code mark) -- or, for `if <c> then <row>`, the THEN row's, cut where {#action_if} cuts the raw
      # text: a capture holding " then " moves the cut into the capture, and the mark then lies
      # inside the THEN row, not at its start.
      def mark_action_row(text, function)
        return text unless function == :if_func || AuthoredCommand::SEND_VERBS.include?(function)
        return AuthoredCommand.mark_argument(text, function, separator_char) unless function == :if_func

        split = text.downcase(:ascii).index(' then ')
        return text if split.nil? || split.zero?

        then_row = text[(split + 6)..]
        then_function = Lexer.function_type(Text.keyword_string(then_row))
        text[0...(split + 6)] + AuthoredCommand.mark_argument(then_row, then_function, separator_char)
      end

      # The live separator char (Config.cSeparatorChar).
      def separator_char
        @router.config.separator_char
      end

      # ParseAction's `%`/`$` row rewrites (Script.cs:2138-2150 R; String.Replace = all).
      def action_row_prefix(row)
        row = "setvariable #{row[1..]}".gsub(' = ', ' ') if row.start_with?('%')
        row = "put #var #{row[1..]}".gsub(' = ', ' ') if row.start_with?('$')
        row
      end

      # ParseAction's $n pass (Script.cs:2155-2171 R).
      def action_arguments(text, args, line)
        out = text.gsub('\\$', ESCAPED_DOLLAR)
        ACTION_ARGUMENT_COUNT.times do |i|
          value = i < args.length ? args[i].gsub('"', '') : ''
          out = out.gsub("$#{i + 1}") { value }
        end
        whole = line.gsub('"', '') # (delete raises on a non-UTF-8 game line)
        out.gsub('$0') { whole }.gsub(ESCAPED_DOLLAR) { '\\$' }
      end

      # ParseAction's `if` row (Script.cs:2178-2203 R): cut at the first " then "; the
      # condition (expanded, its keyword dropped) goes through EvalIfStatement. A row with
      # no " then " makes Remix's Substring throw: a GenieError (decided: one error
      # line, the script stops).
      # @return [Array(String, Symbol), nil] the THEN row and its function, nil to skip
      def action_if(text, entry)
        split = text.downcase(:ascii).index(' then ')
        return nil if split&.zero? || text.length < 6

        if split.nil?
          abort_with("Length cannot be less than zero. (Parameter 'length')", @call_stack.line_value)
          return nil
        end
        return nil unless eval_if_statement(Text.argument_string(substitute(text[0...split])), entry)

        then_row = text[(split + 6)..]
        [then_row, Lexer.function_type(Text.keyword_string(then_row))]
      end

      # EvalIfStatement (Script.cs:3560-3585 R): cut at the first " then" (ToLower +
      # IndexOf), evaluate, and a matchre() hit binds the $-args to Eval's result list.
      # +line+: the file and row Eval's debug warning names (the row, or the action's).
      def eval_if_statement(expression, line = @row)
        cut = expression.downcase(:ascii).index(' then')
        expression = expression[0...cut] if cut
        result = @eval.do_eval(eval_warned(expression, line))
        bind_capture_groups
        debug(3) { "if evaluate: #{expression}" }
        debug(3) { "if returned: #{result ? 'True' : 'False'}" }
        result
      end

      # An action row that jumped (Script.cs:2247-2268 R): m_bStopRunning, actionwait (or
      # actioninstant), the call stack and match list cleared, the line pointer on the label.
      # The script resumes there on the next tick ({#resume_action}); a row loop running
      # right now stops after its current row ({#run_rows}).
      def action_goto(target, instant)
        @stop_running = true
        @state = instant ? :actioninstant : :actionwait
        @actionwait_end = now + ACTION_RESUME_SECONDS
        @call_stack.clear
        @match_list = []
        @call_stack.line_value = target
      end

      # --- timer / misc -----------------------------------------------------

      # EvalTimer (Script.cs:3034-3105 R). `start` (only while stopped) resumes from the last
      # stopped time and sets %t to the literal "@timer@" (the @-special reads the running timer
      # at each use); `stop` stores the elapsed seconds in %t; `clear` zeroes both; `setstart
      # <date>` starts the timer at a DateTime.Parse date; anything else (a bare `timer`) does
      # nothing. %t is set without a variable change (m_oLocalVarList.Add).
      def do_timer(raw)
        case Text.net_downcase(Text.keyword_string(raw))
        when 'start' then timer_start
        when 'stop' then timer_stop
        when 'setstart' then timer_setstart(Text.argument_string(raw))
        when 'clear'
          @timer_start = nil
          @timer_last_ms = 0.0
          @vars.local_set('t', '0')
        end
      end

      def timer_start
        return if @timer_start

        @timer_start = now
        @timer_start -= @timer_last_ms / 1000.0 if @timer_last_ms.positive?
        @vars.local_set('t', '@timer@')
      end

      def timer_stop
        if @timer_start
          @timer_last_ms = elapsed_ms(@timer_start)
          @timer_start = nil
          @vars.local_set('t', @timer_last_ms.positive? ? Numeric.format_double(@timer_last_ms / 1000) : '0')
        else
          @vars.local_set('t', '0')
        end
      end

      # `timer setstart <date>`: DateTime.Parse of the argument (en-US); a text it cannot read is
      # a script error. The start is placed that far in the past on this interpreter's clock.
      # 0001-01-01 00:00:00 is m_oBlankTimer itself (Script.cs:678 R): the timer counts as never
      # started (`stop` stores "0", `start` starts afresh), and @timer@ reads the same value.
      def timer_setstart(text)
        date = NetDate.parse(text, today: @wall_clock.call)
        return script_error("Invalid datetime format in TIMER SETSTART command: #{text}") if date.nil?

        @timer_start = date == BLANK_TIMER ? nil : now - (wall_seconds(@wall_clock.call) - wall_seconds(date)).to_f
        @vars.local_set('t', '@timer@')
      end

      # m_oBlankTimer = DateTime.Parse("0001-01-01") (Script.cs:678 R): naive, as NetDate builds it.
      BLANK_TIMER = Time.utc(1, 1, 1).freeze

      # A Time as DateTime's naive wall-clock seconds, in the Time's OWN offset (DateTime
      # subtraction ignores the zone, so a DST or historical offset change between two dates does
      # not count): the injected wall clock's offset for now, 0 for a NetDate (naive) date.
      def wall_seconds(time)
        time.to_r + time.utc_offset
      end

      # @timer@ (Script.ParseVariables, Script.cs:2350-2361 R): the running timer's seconds,
      # "0" unless positive. With no timer running Remix measures from m_oTimerStart's default,
      # 0001-01-01 -- the local wall clock's seconds since then.
      # @return [String]
      def timer_text
        ms = @timer_start ? elapsed_ms(@timer_start) : blank_timer_ms
        ms.positive? ? Numeric.format_double(ms / 1000) : '0'
      end

      # TimeSpan.TotalMilliseconds of now - +start+: whole 100 ns ticks / 10000 (DateTime's
      # resolution, so 1.5 s of clock is exactly 1500 ms).
      def elapsed_ms(start)
        ((now - start) * 10_000_000).round / 10_000.0
      end

      # Seconds from 0001-01-01 (DateTime default) to DateTime.Now, local time, in ms.
      DAYS_0001_TO_1970_SECONDS = 62_135_596_800

      def blank_timer_ms
        ((wall_seconds(@wall_clock.call) + DAYS_0001_TO_1970_SECONDS) * 10_000_000).round / 10_000.0
      end

      # --- JavaScript (Jint 4 in Remix; JsRuntime here) ----------------------

      # The jsblock arm of RunScript (Script.cs:1777-1815 R): the first row of a block starts its
      # source unless the script is skipping a block (then the previous source is kept, and still
      # grows), every later row is appended.
      def collect_js_row(instruction)
        if @js_block
          @js_block_source << instruction.content << "\n"
        else
          unless @call_stack.skip_block
            @js_block_source = +"#{instruction.content}\n"
            @js_block_row = instruction
          end
          @js_block = true
        end
      end

      # The first non-jsblock row after a block runs it, unless the script is skipping a block
      # (Script.cs:1777-1803 R). @return [Boolean] false when the block failed (stop the loop)
      def end_js_block
        return true unless @js_block

        @js_block = false
        return true if @call_stack.skip_block || @js_block_source.empty?

        run_js_block
      end

      # RunJsblock (Script.cs:3614-3619 R) with RunScript's catch (Script.cs:1739-1750, 1785-1797
      # R): a JavaScript error prints "[Javascript error ...]" naming the block's first row, drops
      # the engine (m_JintEngine = null: what it defined is gone) and AbortOnScriptError. At the
      # end of the script the block runs whatever the skip state and bJSBlock is not reset, so the
      # next ordinary row the script reaches (its scripterror label) runs it again (Script.cs:
      # 1736-1750 R; t231). A block outside {JsRuntime}'s reach is announced and skipped.
      # @return [Boolean] false when the block failed
      def run_js_block
        js_runtime.execute(@js_block_source)
        true
      rescue JsRuntime::JsError => e
        print_js_error(e.message, @js_block_row)
        @js_runtime = nil
        abort_on_script_error
        false
      rescue JsRuntime::Unsupported => e
        announce_unsupported('JavaScript', "#{script_place(@js_block_row)} #{@js_block_source.lines.first}", e)
        true
      end

      # `js <code>` (Script.cs:2833-2838 R): the ROW'S OWN TEXT, not the variable-expanded line,
      # goes to Jint (`%name` in a js_arrays argument is resolved by the library itself).
      # @param instruction [Lexer::Instruction]
      def run_js(instruction)
        eval_js(Text.argument_string(instruction.content))
      end

      # `jscall <var> <code>` (Script.cs:2840-2846 R): the result goes through EvalSetvariable
      # ("<var> <result>"), so it raises "%var" too.
      # @param instruction [Lexer::Instruction]
      def run_jscall(instruction)
        rest = Text.argument_string(instruction.content)
        result = eval_js(Text.argument_string(rest))
        do_setvariable("#{Text.keyword_string(rest)} #{result}") unless result.nil?
      end

      # EvalJS (Script.cs:2861-2877 R): the completion value's ToString(), "undefined" for
      # undefined/null and after a JavaScript error, which is a PrintError on this row (the script
      # goes on). @return [String, nil] nil when the code is outside what JsRuntime runs
      def eval_js(code)
        value = js_runtime.evaluate(code)
        JsValue.nullish?(value) ? 'undefined' : JsValue.to_string(value)
      rescue JsRuntime::JsError => e
        print_error(e.message, @row.file_id, @row.file_row)
        'undefined'
      rescue JsRuntime::Unsupported => e
        announce_unsupported(@row.function == :jscall ? '#jscall' : '#js', code, e)
        nil
      end

      # InitJintEngine (Script.cs:694-706 R): echo, put, getGlobal, getVar, setGlobal, setVar.
      def js_runtime
        @js_runtime ||= JsRuntime.new(
          JsRuntime::Host.new(
            local: ->(name) { @vars.local_get(name) },
            global: ->(name) { @vars.global_get(name) },
            set_local: ->(name, value) { local_set(name, value) },
            set_global: ->(name, value) { @vars.global_assign(name, value) },
            echo: ->(text) { echo_line(text) },
            send_text: ->(text) { send_text(text) }
          )
        )
      end

      # "<file>[, <include>](<row>)" of +line+, for the unsupported-JavaScript notice.
      def script_place(line)
        other = file_label(line&.file_id)
        "#{@file_name}#{", #{other}" unless other.empty?}(#{line&.file_row})"
      end

      # "[Genie: <verb> not supported in the in-Lich engine: <code>[ (<why>)]]": white space runs
      # (a js_arrays.js tab) shown as one space.
      # @param error [JsRuntime::Unsupported, nil] the reason
      def announce_unsupported(verb, detail, error = nil)
        reason = error ? " (#{error.message})" : ''
        echo_line("[Genie: #{verb} not supported in the in-Lich engine: #{detail.to_s.gsub(/\s+/, ' ').strip}#{reason}]")
      end

      # --- helpers ----------------------------------------------------------

      def substitute(content)
        @substitution.expand(content, args: @call_stack.arg_list)
      end

      # AddLocalVariable and the verbs that write m_oLocalVarList then raise "%name"
      # (TriggerVariableChanged, Script.cs:3554-3558 R; setvariable, save, put's %lastcommand,
      # eval, evalmath, math, counter, goto/match %lastlabel, jscall). The writes Remix makes
      # without it -- random's %r, shift, the launch args, %scriptname -- go straight to @vars.
      def local_set(name, value)
        @vars.local_set(name, value)
        variable_changed("%#{name}")
      end

      def echo_line(text)
        @echo.call(text.to_s)
      end

      # When a timed wait of +seconds+ entered now may resume: no sooner than one Remix tick
      # (see TICK_SECONDS). EvalPauseScript / EvalDelayScript / EvalWait / EvalMatchWait take
      # DateTime.Now.AddMilliseconds(EvalDoubleTime's ms) (Script.cs:3339, 3372, 3378, 3387 R),
      # which throws past MaxMillis (Infinity included) or past year 9999
      # ({Numeric.add_milliseconds_fault}; the injected wall clock, whatever the interpreter's
      # monotonic clock is -- never a Time.now of its own, so a virtual clock near year 9999
      # faults as Remix's virtual DateTime.Now would). That reaches RunScript's /
      # TriggerParse's catch: an evaluator-class fault (the script stops). Nor
      # may such a time reach the input port: Lich's LimitedArray#wait_shift raises RangeError
      # on an Infinity or anything past ~9.2e18 s.
      # @param seconds [Float] positive
      # @return [Float]
      # @raise [Eval::Fault]
      def timed_end(seconds)
        fault = Numeric.add_milliseconds_fault(seconds * 1000, now: @wall_clock.call)
        raise Eval::Fault, fault if fault

        now + [seconds, TICK_SECONDS].max
      end

      def parse_seconds(arg, default)
        return default if arg.strip.empty?

        value = Numeric.string_to_double(arg)
        value.positive? ? value : default
      end

      def finish
        @state = :finished
      end

      # --- script errors (PrintError / AbortOnScriptError / PrintTrace) ------

      # @return [GameState::Config] the live settings (scripttimeout, maxgosubdepth,
      #   ignorescriptwarnings: a runtime `#config` applies at the next check)
      def config
        @router.config
      end

      # Script.GetFileName (Script.cs:2106-2117 R): an include's name, "" for the main file.
      def file_label(file_id)
        name = @program.files[file_id.to_i].to_s
        file_id.to_i.positive? && name != @file_name ? name : ''
      end

      # Script.PrintError (Script.cs:4340-4360 R): %lastscripterror (no variable change), then
      # "[Script error in <file>[, <include>][(<row>)]: <text>]" on the main window.
      def print_error(text, file_id = 0, file_row = 0)
        @vars.local_set('lastscripterror', text)
        @print.call(Lexer.error_line(text, file_id: file_id.to_i, file_row: file_row.to_i, files: @program.files,
                                           file_name: @file_name), :error)
      end

      # Script.PrintJSError (Script.cs:4362-4386 R): the text up to " at line ", as
      # "[Javascript error in <file>[, <include>][(<row>)]: <text>]"; no %lastscripterror.
      def print_js_error(text, line)
        text = text[0...text.index(' at line ')] if text.include?(' at line ')
        @print.call(Lexer.error_line(text, file_id: line&.file_id.to_i, file_row: line&.file_row.to_i, files: @program.files,
                                           file_name: @file_name, kind: 'Javascript error'), :error)
      end

      # PrintError naming +line+'s file and row, then AbortOnScriptError.
      # @param line [#file_id, #file_row, nil] the row (oLine); nil = no row
      def script_error(text, line = @row)
        print_error(text, line&.file_id.to_i, line&.file_row.to_i)
        abort_on_script_error
      end

      # Script.AbortOnScriptError (Script.cs:1109-1135 R): with a `scripterror` label (and not
      # already on the way there) the blocks are cleared and the script resumes at that label on
      # the next tick (the scripterror state); otherwise AbortScript -- the script ends.
      def abort_on_script_error
        if @state != :scripterror && @program.labels.key?(SCRIPT_ERROR_LABEL)
          print_text("[Script moving to scripterror label (#{@file_name})]")
          @call_stack.clear_blocks
          @state = :scripterror
          @scripterror_end = now + TICK_SECONDS
        else
          announce_abort # AbortScript (Script.cs:1124 R)
          finish
        end
      end

      # AbortScript's line (Script.cs:1143-1158 R), only while the script is not finished, once
      # per script ({.abort_line}). The claim is atomic: a cross-thread abort ({#abort_script} from
      # GenieScript#genie_abort) racing the script thread's own script-error abort prints one line.
      def announce_abort
        claimed = @abort_lock.synchronize do
          next false if @state == :finished || @aborted || @abort_announced

          @abort_announced = true
        end
        return unless claimed

        print_text(Interpreter.abort_line(@script_start ? now - @script_start : 0.0, @file_name))
      end

      # Script.PrintText (Script.cs:4428-4431 R).
      def print_text(text)
        @print.call(text, :text)
      end

      # Script.PrintTrace (Script.cs:1901-1905 R): "Trace follows:", then the trace's entries
      # (each "\t<entry>"; the lines Genie ends with a newline are shown without it).
      def print_trace
        print_text('Trace follows:')
        print_text(@trace.to_s.chomp)
      end

      # Script.PrintDebug (Script.cs:4388-4426 R): a line for +level+ when the debug level is at
      # least it (levels up to 9) or exactly it (10 and above), "<file>[, <include>][(<row>)]: "
      # in front; never for a pluginscript's rows. The block builds the text only when shown.
      # @param line [#file_id, #file_row, nil] nil = no file/row
      def debug(level, line = nil)
        return unless @debug_level > 9 ? @debug_level == level : @debug_level >= level

        file_id = line&.file_id.to_i
        return if @program.files[file_id].to_s == 'genie'

        prefix = @file_name.dup
        other = file_label(file_id)
        prefix << ", #{other}" unless other.empty?
        prefix << "(#{line.file_row})" if line&.file_row.to_i.positive?
        prefix << ': ' unless prefix.empty?
        @print.call(prefix + yield.to_s, :debug)
      end

      # Script.EvalString / Eval's debug warning (Script.cs:1324-1356 R): with a debug level and
      # warnings not ignored, an expression still holding `%` or `$` gets a PrintError (which sets
      # %lastscripterror); the text is returned for evaluation either way.
      def eval_warned(text, line)
        if @debug_level.positive? && !config.ignore_script_warnings
          char = if text.include?('%') then '%'
                 elsif text.include?('$') then '$'
                 end
          if char
            print_error("Eval (#{text}) contains variable character '#{char}'. Did you use an unassigned variable?",
                        line&.file_id.to_i, line&.file_row.to_i)
          end
        end
        text
      end

      # --- the do verb (EvalDo, Script.cs:2718-2727, 3477-3531 R) -------------

      # The dofunc arm: the match list so far is kept for RepeatDoCommand, then EvalDo; a text
      # that is not a valid regex as a whole is "Invalid RegExp in Do" + AbortOnScriptError.
      def do_do(arg)
        @do_match_list = @match_list.dup
        script_error("Invalid RegExp in Do: #{arg}") unless eval_do(arg, @call_stack.line_value)
      end

      # EvalDo: `clear` empties the match list; otherwise the command is the text, or the first
      # `{...}`'s content, and a second `{...}` is added to $repeatregex; a regex match entry for
      # the repeat pattern (the internal label) joins the match list and the command is queued
      # like `send` but held while webbed or stunned (SendText(text, true, true) -> AddToQueue,
      # FormMain.cs:6826-6845 R). A matchwait that sees the repeat pattern sends it again.
      # @return [Boolean] false for an invalid regex
      def eval_do(text, index)
        return true if Text.net_trim(text).empty?

        if Text.net_downcase(text) == 'clear'
          @match_list = []
          return true
        end
        return false unless NetRegex.valid?(text)

        braces = text.scan(/\{.*?\}/)
        repeat = @vars.global_get('repeatregex').to_s
        @do_text = braces.empty? ? text : braces[0][1...-1]
        @do_additional = braces.length > 1 ? braces[1][1...-1] : ''
        @do_repeat = braces.length > 1 ? "#{repeat}|#{@do_additional}" : repeat
        add_match_entry(@do_repeat, DO_LABEL, true, index)
        queue_send(@do_text, restricted: true)
        true
      end

      # RepeatDoCommand (Script.cs:3519-3531 R): the match list as it was before the `do`, then
      # EvalDo again (with the grown repeat pattern when there was an additional one).
      def repeat_do_command
        @match_list = @do_match_list.dup
        if Text.net_trim(@do_additional).empty?
          eval_do(@do_text, @call_stack.line_value)
        else
          eval_do("{#{@do_text}} {#{@do_repeat}}", @call_stack.line_value)
        end
      end

      def abort_with(message, index)
        echo_line("[#{message}]")
        finish
        index
      end
    end
  end
end
