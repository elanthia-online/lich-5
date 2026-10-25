# frozen_string_literal: true

require 'json'
require 'zlib'

module Lich
  module Genie
    # Lich integration glue. `GenieScript` is a `Lich::Common::Script` subclass so
    # it inherits Lich's full script lifecycle (registry, pause/kill, buffers,
    # `;list`), but instead of eval'ing Ruby labels its thread body runs the Genie
    # {Interpreter} wired to Lich via the port adapters below.
    #
    # This file requires a running Lich (it references Game/XMLData/$_CLIENT_/put/
    # respond) and must load AFTER lib/common/script.rb. The headless engine in
    # lib/genie/*.rb has no such dependency.
    #
    # NOTE: prototype. A paused script runs no row and takes no resume (Interpreter's paused
    # port), whoever paused it. Its input DROPS what arrives only while Genie's own `#script pause`
    # holds it (Remix's pause; {InputBuffer}); a Lich-level pause from any other source
    # (`;pause`, pause_script, DRC.pause_all ...) BUFFERS it for after the unpause (a decided
    # divergence: Remix has no outside pauser; {LichInputPort}; before v0.18 a Lich pause stopped
    # no row -- only the sends blocked in Game.puts). Reserved variables come from the GameState
    # capture of the raw stream (GameStateFeed, LichGameState). Roundtime gates the interpreter's
    # RESUMES (GameEvents::RoundTimeEnd), never a send.
    class GenieScript < Lich::Common::Script
      DOWNSTREAM_INSTALL_MUTEX = Mutex.new # guards ensure_downstream_hook!'s check-then-set
      QUEUE_WORKER_MUTEX = Mutex.new # guards start_command_queue!'s memo (script + parser threads)
      SESSION_MEMO_MUTEX = Mutex.new # guards the trigger_runner / queue-state memos (every thread)
      WALK_RUNNERS_MUTEX = Mutex.new # guards the walk runners waiting for their script ({.spawn_walk})
      # Thread-local slot naming the {WalkRunner} whose body runs on this thread ({.run_walk}).
      WALK_RUNNER_KEY = :genie_walk_runner
      # Fiber-local slot naming the script a released queue command is being sent for (set by
      # run_queued_command on the queue worker; read by LichGamePort#send_command).
      QUEUE_OWNER_KEY = :genie_queue_owner
      # Thread-local slot holding the launch {.start_exact} is making: the exact file Lich's finder
      # must return ({ExactLaunchFinder}) and what GenieScript#initialize takes from it.
      LAUNCH_KEY = :genie_launch
      # How long a launching script waits for the child's first run: the runaway guard stops
      # a first run of busy rows after Interpreter::SCRIPT_TIMEOUT_SECONDS, so this bounds only a
      # child that never reaches its first wait for another reason (a Lich-level pause in a send).
      FIRST_RUN_WAIT_SECONDS = Interpreter::SCRIPT_TIMEOUT_SECONDS + 1

      # A genie script's downstream buffer: Lich's LimitedArray (Script.new_downstream and every
      # dispatch push into it; Script#gets reads it), except that while its script is paused by
      # Genie's `#script pause` ({GenieScript#input_dropped?}) it drops what is pushed --
      # TriggerParse / TriggerVariableChanged / TriggerPrompt / TriggerMove return for a paused
      # Remix script (Script.cs:1179-1184, 1360-1363, 1434-1485 R) -- but a roundtime
      # (GameEvents.kept_while_paused?: SetRoundTime has no pause check). Dropping at the push, not
      # when the script next reads, keeps what arrived before the pause (flow
      # t149). A Lich-level pause drops nothing. A script not in the Genie script list yet
      # drops everything, a roundtime too: no ParseTriggers / SetRoundTime walk reaches a script
      # before AddScripts lists it (FormMain.cs:3809-3835, 4488, 6940 R; {ScriptList}, flow t165) --
      # but the engine's own injection for it ({#inject}).
      #
      # Game text: what Lich itself pushes from its game parser thread is its
      # strip_xml line of a game row (games.rb:1139-1141) -- dropped: the engine delivers the
      # game text Remix's row parser prints instead (GameState's GameEvents::TextLine, through
      # {#engine_port}). What Lich pushes from any other thread (`;send`, send_scripts) is kept.
      class InputBuffer < Lich::Common::LimitedArray
        # @param dropping [#call] => whether the owning script's input drops what arrives
        # @param unlisted [#call] => whether the owning script is not listed yet
        def initialize(dropping:, unlisted: -> { false })
          super()
          @dropping = dropping
          @unlisted = unlisted
        end

        # Lich's push (Script.new_downstream & co.).
        def push(*items)
          return self if Thread.current[GameStateFeed::READER_KEY]

          engine_push(*items)
        end
        alias << push
        alias append push

        # A push the engine's dispatch makes (game text, `#parse`, variable changes, events):
        # dropped while the script is not listed yet or `#script pause`d.
        def engine_push(*items)
          return self if @unlisted.call

          inject(*items)
        end

        # A push the engine makes for this script only: kept while the script is not listed
        # (still dropped by a `#script pause`, like any line).
        def inject(*items)
          items = items.select { |item| GameEvents.kept_while_paused?(item) } if @dropping.call
          return self if items.empty?

          Lich::Common::LimitedArray.instance_method(:push).bind_call(self, *items)
        end

        # @return [#push] a port whose pushes are {#engine_push}es (the dispatch recipients' buffer)
        def engine_port
          buffer = self
          @engine_port ||= Object.new.tap { |port| port.define_singleton_method(:push) { |*items| buffer.engine_push(*items) } }
        end
      end

      # rubocop:disable Lint/MissingSuper
      def initialize(file_name, cli_vars = [], _publish = true)
        launch = Thread.current[LAUNCH_KEY]
        launch = nil unless launch && File.expand_path(file_name) == File.expand_path(launch[:path])
        # Script.FileName (the dupe-check key and the $scriptlist name) and %scriptname
        # (ScriptLaunch.script_name): an engine launch's lowercased launch name (FormMain.cs:
        # 4682-4687 R); for a Lich-typed `;name` the file's own name, lowercased the same way.
        @genie_file_name = launch ? launch[:file_name] : File.basename(file_name).sub(/\.gz\z/i, '').downcase
        @name = ScriptLaunch.script_name(@genie_file_name)
        @file_name = file_name
        # Genie's launch tokenizer (ParseArgs(".name args", true)); a malformed string
        # raises, so Script.start reports it and the script never starts, like Remix's
        # RunScript fault (FormMain.cs:4678-4721 R). No Lich `quiet` arg convention. An engine
        # launch parsed them already (ScriptLaunch.request).
        @genie_args = launch ? launch[:args] : ScriptArgs.parse_launch(@name, cli_vars)
        @vars = @genie_args.empty? ? [] : [@genie_args.join(' '), *@genie_args]
        @quiet = false
        @killer_mutex = Mutex.new
        @abort_mutex = Mutex.new # {#announce_genie_abort}'s choice + claim (any thread)
        @downstream_buffer = InputBuffer.new(dropping: -> { input_dropped? }, unlisted: -> { !genie_listed? })
        @downstream_buffer.max_size = 400
        # want_downstream stays on (Lich's Script#gets reads only when a downstream is wanted), but
        # the InputBuffer drops the strip_xml lines Lich pushes from its game parser thread: the
        # engine delivers Remix's game text itself.
        @want_downstream = true
        # We deliberately DO NOT use want_script_output. It would route ALL of Lich's
        # "script output" into matchwait, but that channel also carries Lich's echo of
        # every command a script SENDS (`[name]>echo Backup 5`, games.rb:652) -- which
        # arrives instantly and self-matches `put echo <sentinel>` backup patterns,
        # firing them before the real game feedback (the v0.10.x combat regression).
        # Instead the ScriptOutputTriggerTap feeds matchwait a FILTERED stream: genuine
        # Lich messages (go2's "you're already there", "--- Lich: X has exited", other
        # scripts' output -- the tester's ask) but NOT `[name]>` command echoes. See
        # feed_script_output.
        @want_script_output = false
        @want_downstream_xml = false
        @upstream_buffer = LimitedArray.new
        @want_upstream = false
        @unique_buffer = LimitedArray.new
        @at_exit_procs = []
        @patchfor = {}
        @die_with = []
        # the rest of Lich's Script#initialize state (its kill/cleanup/custom? paths read
        # these; before v0.19 they were nil and only worked through Lich's NilClass patch)
        @custom = file_name.to_s.match?(%r{[/\\]custom[/\\]})
        @watchfor = {}
        @killed_externally = false
        @kill_source = nil
        @kill_requested = false
        @cleanup_started = false
        @completed_successfully = false
        @ignore_pause = false
        @paused = false
        @genie_paused = false # paused through Genie's own `#script pause` ({#genie_pause})
        @hold_mutex = Mutex.new # with @hold_signal: wakes a held read at the unpause ({#wait_while_held})
        @hold_signal = ConditionVariable.new
        @hidden = false
        @no_pause_all = false
        @no_kill_all = false
        @silent = false
        @safe = false
        @no_echo = false
        @match_stack_labels = []
        @match_stack_strings = []
        @label_order = ['~start']
        @labels = { '~start' => '' }
        @current_label = '~start'
        @thread_group = ThreadGroup.new
        @genie_source = read_source(file_name)
        return unless launch

        # m_oScriptListNew.Add, on the launching thread, before Script.start runs the thread
        # (FormMain.cs:4691-4699 R)
        launch[:script] = self
        Lich::Genie.script_list.launched(self, launcher: launch[:launcher])
      end
      # rubocop:enable Lint/MissingSuper

      # Thread body: run the Genie interpreter wired to Lich.
      # @return [void]
      def run_genie
        list = Lich::Genie.script_list
        list.launched(self) # a Lich-typed `;name` registers here, with no launcher
        run_genie_interpreter(list)
      ensure
        @quiet = true if @genie_interpreter&.abort_announced? # a script-error abort: Remix's line only
        @genie_done = true # gone from $scriptlist before the change is offered
        @genie_paused = false # Lich's teardown clears @paused directly, never through #unpause
        # the script's end is its run's end: the scripts it launched are released, then the tick end
        list.finished(self)
        GenieScript.script_list_changed if list.tick_end
      end

      # @return [String] Script.FileName ({ScriptList}'s dupe-check key and $scriptlist name)
      attr_reader :genie_file_name

      # @return [Array<String>] the launch arguments (Genie's al[1..])
      attr_reader :genie_args

      # Whether a send of this script may go out: only while the engine is on
      # for the character ({GenieScript.engine_on?}). While it is off the send is dropped -- the
      # script keeps running (it sees no game line either: the downstream hook passes them by), and
      # sends again once the engine is back on -- and the first dropped send of each off spell
      # prints one line, so the player knows why the script went quiet.
      # @return [Boolean]
      def genie_send_allowed?
        if GenieScript.engine_on?
          @genie_engine_off_noticed = false
          return true
        end
        unless @genie_engine_off_noticed
          @genie_engine_off_noticed = true
          GenieScript.engine_respond("[Genie: the engine is off (Lich::Genie.enabled) -- #{name} sends nothing until it is turned back on.]")
        end
        false
      end

      # @return [Boolean] whether this script is in the Genie script list (m_oScriptList)
      def genie_listed?
        Lich::Genie.script_list.listed?(self)
      end

      # The end of this script's run (it is about to wait, or a `#goto` walk starts): the tick end
      # of {ScriptList#run_ended}, whose "scriptlist" change this script queues for itself too.
      # @return [void]
      def genie_run_ended
        GenieScript.script_list_changed(queue_owner: true) if Lich::Genie.script_list.run_ended(self)
      end

      # Told by the list once AddScripts listed this script: wake the interpreter parked while it
      # was frozen (it polls every Interpreter::PAUSE_POLL_SECONDS otherwise).
      # @return [void]
      def genie_listed
        @downstream_buffer.engine_push(GameEvents::RESUMED)
      end

      # Script.AbortScript from `#script abort` or a relaunch's dupe check: the
      # interpreter runs no further row and gets nothing more, the script leaves the list. On the
      # script's own thread that is all -- run_genie returns and Lich ends the script as after
      # its last row (a Lich kill there would stop the thread at a random point of the row that
      # aborted, e.g. half way through `#script abort all`). From any other thread Lich kills it
      # too, which also stops a thread blocked outside the interpreter (a `#goto` walk).
      # The kill is never `killed_externally`: no "--- Lich: x was killed. (...genie_abort)"
      # notice, which every script and #trigger would see as a Lich line ({#silence_lich_notice}).
      # @return [void]
      def genie_abort
        @genie_aborted = true
        announce_genie_abort # Remix's "[Script aborted! ...]" line, engine output
        silence_lich_notice
        Lich::Genie.script_list.finished(self)
        return if Lich::Common::Script.current_without_pause.equal?(self) # Script.current blocks while paused

        kill
      end

      private

      # After an engine abort Remix prints its "[Script aborted! (Run time: ...)]" line
      # (Script.cs:1143-1158 R; Interpreter#announce_abort, through the engine-output print port, so
      # it feeds no matchwait or #trigger -- Script_EventPrintText is AddText only, FormMain.cs:
      # 5611-5618 R) and nothing else. Lich's own stop notice ("--- Lich: x has exited.") would be a
      # Lich line offered to every script and #trigger (5 tester scripts wait on `^--- Lich:`), so
      # an announced abort makes the script quiet (Lich's __complete_stop prints nothing for a quiet
      # script). An abort before the interpreter was built prints the line itself and is quiet too
      # ({#announce_genie_abort}).
      # A normal end keeps Lich's "has exited" line.
      # @return [void]
      def silence_lich_notice
        @quiet = true if @genie_early_abort || @genie_interpreter&.abort_announced?
      end

      # The abort line: the interpreter's ({Interpreter#abort_script}, once per script). An abort
      # that lands before the script thread built the interpreter prints it here, once, run time
      # 0.00: Remix's LoadFile and RunScript run in one go on the launching thread (m_oScriptStart
      # set at the load, Script.cs:1996 R), so it has no unloaded window and would print it. The
      # choice and the claim run under @abort_mutex: a second abort after the interpreter appears
      # prints nothing more (that interpreter never runs: run_genie_interpreter sees @genie_aborted).
      # @return [void]
      def announce_genie_abort
        target = @abort_mutex.synchronize do
          next nil if @genie_early_abort
          next @genie_interpreter if @genie_interpreter

          @genie_early_abort = true
          :early
        end
        return target&.abort_script unless target == :early

        GenieScript.respond_in_chain(Interpreter.abort_line(0.0, @genie_file_name))
      end

      # Body of {#run_genie}.
      # @param list [ScriptList]
      # @return [void]
      def run_genie_interpreter(list)
        GenieScript.ensure_downstream_hook! # gag/sub + trigger firing on the game stream
        GenieScript.start_command_queue! # replaces a dead queue worker
        # Process-wide global store, shared by every Genie script and the trigger thread:
        # read from GenieProfiles/Config/variables.cfg at engine start, memory-only after
        # that until `#var save` / `#save vars|all` (Remix model, see GlobalStore).
        variables = Variables.new(game_state: LichGameState.new, global_store: Lich::Genie.global_store)
        variables.local_set('scriptname', @name)

        interpreter = build_interpreter(variables, list)
        return unless interpreter # the load failed: its script error lines are out (Engine.build)

        @genie_interpreter = interpreter # compared with ParseDispatch.owner by the broadcasts
        interpreter.run unless @genie_aborted
      end

      # Script.LoadFile + the interpreter (Engine.build): ignorescriptwarnings from the live config
      # (Config.bIgnoreScriptWarnings, Remix default False), the launch's file name for the error
      # lines ("[Script error in <name>.cmd(<row>): ...]").
      # @return [Interpreter, nil] nil when Remix would refuse to load the script
      def build_interpreter(variables, list)
        Engine.build(
          @genie_source,
          name: @name,
          file_name: @genie_file_name,
          variables: variables,
          args: @genie_args,
          ignore_warnings: Lich::Genie.ignore_script_warnings?,
          include_loader: method(:load_include),
          game: LichGamePort.new,
          input: LichInputPort.new(self),
          echo: ->(text) { GenieScript.respond_in_chain(text) },
          print: ->(text, _kind) { GenieScript.respond_in_chain(text) },
          hooks: LichHookSink.new,
          lists: Lich::Genie.lists,
          log_dir: -> { Lich::Genie.directories['logdir'] },
          launch: ->(name, args) { launch_script(name, args) },
          mover: ->(room) { genie_goto(room) },
          script_control: LichScriptControl.new,
          clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
          broadcast: ->(text) { GenieScript.parse_broadcast(text) },
          var_broadcast: ->(name) { GenieScript.variable_broadcast(name) },
          # looked up at each use (a hot reload rebuilds it); items carry this script so
          # the worker sends them as it (`[name]>cmd`, honouring `silent`)
          queue: -> { Lich::Genie.command_queue }, queue_owner: self,
          # any pause freezes the rows (the input port holds a Lich-level one), and so does
          # waiting to be listed after the first run (ScriptList#frozen?: no TickScript yet)
          paused: -> { paused? || list.frozen?(self) }
        )
      rescue Lexer::LoadFailed
        nil
      end

      public

      # @return [Interpreter, nil] this script's interpreter once run_genie has built it
      attr_reader :genie_interpreter

      # Genie's `#script pause` (Remix PauseScript, Script.cs:1053-1077 R): Lich's pause, marked as
      # Genie's own so the input drops what arrives until the unpause ({#input_dropped?}). A decided
      # divergence: only this path drops; a pause from any other source buffers.
      # @return [void]
      def genie_pause
        @genie_paused = true
        pause unless paused?
        wake_held_input # a read held by a Lich-level pause now drops instead: let it go
      end

      # @return [Boolean] whether the input drops what arrives: paused, through `#script pause`
      def input_dropped?
        @paused && @genie_paused ? true : false
      end

      # @return [Boolean] whether a Lich-level pause holds the input for after the unpause:
      #   paused, but not through `#script pause`
      def input_held?
        @paused && !@genie_paused ? true : false
      end

      # How often a held read looks at the pause flags again by itself: only for a change that
      # bypasses {#unpause}/{#genie_pause} (Lich's teardown sets @paused = false directly) -- as
      # often as the interpreter polls its own pause port (measured, 10 held scripts: 0.32% of a
      # core; the 10 ms sleep poll it replaces cost 2.2%, a 50 ms recheck 0.84%).
      HOLD_RECHECK_SECONDS = Interpreter::PAUSE_POLL_SECONDS

      # Blocks the calling (script) thread while {#input_held?}, at most +timeout+ seconds (nil =
      # until the hold ends). Woken at once by {#unpause} / {#genie_pause} (a 10 ms
      # sleep poll cost 2.2% of a core for 10 held scripts).
      # @param timeout [Numeric, nil]
      # @return [void]
      def wait_while_held(timeout)
        clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        deadline = timeout && (clock.call + timeout)
        @hold_mutex.synchronize do
          while input_held?
            remaining = deadline && (deadline - clock.call)
            break if remaining && remaining <= 0

            @hold_signal.wait(@hold_mutex, remaining ? [remaining, HOLD_RECHECK_SECONDS].min : HOLD_RECHECK_SECONDS)
          end
        end
      end

      # Lich's unpause (it also ends a `#script pause`), then a wake-up for the interpreter parked
      # on the input (it polls its pause flag only every Interpreter::PAUSE_POLL_SECONDS): Remix's
      # ResumeScript runs the script at once (Script.cs:1079-1106 R). The wake item carries nothing.
      def unpause
        was_paused = @paused
        super
        return if @paused

        @genie_paused = false
        @downstream_buffer.engine_push(GameEvents::RESUMED) if was_paused
        wake_held_input
      end

      # Wakes a read parked in {#wait_while_held} so it looks at the pause flags again.
      # @return [void]
      def wake_held_input
        @hold_mutex.synchronize { @hold_signal.broadcast }
      end

      # @return [Boolean] whether this script's interpreter has finished (it may still be in
      #   Lich's running list while Lich tears it down)
      def genie_done?
        @genie_done == true
      end

      @downstream_installed = false
      @script_output_tap_installed = false
      @game_state_tap_installed = false
      @exact_finder_installed = false
      @walk_tracker_installed = false

      # Thread-local slot holding the {WalkRunner} whose walk (DRCT.walk_to) runs on this thread:
      # the scripts Lich starts there (go2, DRCT's go2 restarts) are the walk's own
      # ({WalkStartTracker}).
      WALK_TRACK_KEY = :genie_walk_tracking
      # The Lich name prefix of a walk's runner script ("automapper1", ...): Remix's walk is the
      # automapper.cmd script.
      WALK_SCRIPT_PREFIX = 'automapper'

      # A `#goto` walk's runner: the hidden Lich script the walk runs
      # in -- so Lich's Script.current-based helpers inside DRCT.walk_to (DRC.fix_standing, bput,
      # `open door`, retreat) have a calling script and their own input, as go2's caller would --
      # and the scripts its walk started, which are all a stop kills (a user's or another
      # script's go2 is never touched; DRCT.walk_to starts its go2 with force, so they coexist).
      class WalkRunner
        # @return [Lich::Common::Script, nil] the Lich script the walk runs in, once started
        attr_accessor :script
        # @return [Thread, nil] the thread running the walk's body
        attr_reader :thread

        # @param body [#call] the walk (GotoWalk's body)
        def initialize(body)
          @body = body
          @started = []
          @mutex = Mutex.new
          @script = nil
          @thread = nil
        end

        # Run the body on the calling (runner script's) thread.
        # @return [void]
        def run
          @thread = Thread.current
          @body.call
        end

        # Run the block with the scripts Lich starts on this thread recorded as this walk's.
        # @return [Object] the block's value
        def tracking
          previous = Thread.current[WALK_TRACK_KEY]
          Thread.current[WALK_TRACK_KEY] = self
          yield
        ensure
          Thread.current[WALK_TRACK_KEY] = previous
        end

        # @param script [Lich::Common::Script]
        # @return [void]
        def record(script)
          @mutex.synchronize { @started << script }
        end

        # @return [Array<Lich::Common::Script>] the scripts the walk started, in start order
        def started
          @mutex.synchronize { @started.dup }
        end

        # Stop the walk: its script, then every script the walk started that still runs. Asked on
        # the walk's own thread -- a #trigger on one of its result lines that runs `#goto` (the
        # dupe check aborts this walk) -- it stops nothing: the walk is over (its result lines are
        # being parsed) and a Lich kill would end the very trigger body asking;
        # GotoWalk parses no further result line of an aborted walk.
        # @return [void]
        def stop
          return if Thread.current.equal?(@thread)

          [@script, *started].compact.each { |script| script.kill if script.running? }
        end

        # Kill every script the walk started that still runs (the walk's own end, {.run_walk}).
        # A failing kill is skipped: the next one still runs.
        # @return [void]
        def stop_started
          started.each do |script|
            script.kill if script.running?
          rescue StandardError
            nil
          end
        end
      end

      # Prepended (once) onto Lich::Common::Script's singleton class: while {GenieScript.start_exact}
      # starts a script (thread-local LAUNCH_KEY), Lich's finder returns the one file
      # ScriptLaunch.resolve found -- Script.start has no way to take a file, and its finder
      # prefix-matches, tries .lic/.rb/.wiz and custom/ first. Any other lookup is Lich's.
      module ExactLaunchFinder
        private

        def __find_script_file(script_name)
          launch = Thread.current[Lich::Genie::GenieScript::LAUNCH_KEY]
          return super unless launch && launch[:token] == script_name

          launch[:relative]
        end
      end

      # Prepended (once) onto Lich::Common::Script's singleton class: a script Lich starts on a
      # thread whose walk is being tracked ({WalkRunner#tracking}: inside DRCT.walk_to on the walk's
      # own script) is recorded as that walk's, so stopping the walk stops it and nothing else.
      # (Script.run does not come through here: it blocks its caller until the child ends.)
      module WalkStartTracker
        def start(*args)
          started = super
          runner = Thread.current[Lich::Genie::GenieScript::WALK_TRACK_KEY]
          runner.record(started) if runner && started.is_a?(Lich::Common::Script)
          started
        end
      end

      # Prepended onto Lich::Common::Script's singleton class so EVERY line Lich echoes
      # to the client (respond/_respond -> Script.new_script_output) is offered to the
      # Genie engine -- the piece that lets matchwait/#triggers match text ECHOED BY LICH,
      # not just the raw game stream. GenieScript uses want_script_output=false, so `super`
      # does NOT fan this out to genie match buffers; feed_script_output does that itself,
      # FILTERED (dropping `[name]>` command echoes).
      module ScriptOutputTriggerTap
        def new_script_output(line)
          super
          Lich::Genie::GenieScript.feed_script_output(line)
        end
      end

      class << self
        # Start the engine (once): the stores, the game-state tap and its listener, the typed-command
        # and script-output taps, and the single Lich DownstreamHook that applies Model A gag/sub to
        # the client display. The #triggers no longer fire there: every game row's printed texts go
        # to the #triggers and then the scripts from the trigger worker ({.game_state_listener}).
        # Runs at the first row of an engine-on session (the tap installed at Lich load) or at the
        # first .cmd script, whichever comes first.
        # @return [void]
        def ensure_downstream_hook!
          # Two .cmd scripts started together must not both install the hook.
          DOWNSTREAM_INSTALL_MUTEX.synchronize do
            return if @downstream_installed

            @downstream_installed = true
            install_downstream_hook!
          rescue StandardError
            # Not installed: let the next script retry instead of running every later
            # .cmd with no trigger firing and no gag/sub for the rest of the session.
            @downstream_installed = false
            raise
          end
        end

        # Body of {ensure_downstream_hook!}; runs once per successful install.
        # @return [void]
        def install_downstream_hook!
          # One-time-per-session banner so a tester sees the running build in their log
          # without having to ask (and can still echo Lich::Genie::VERSION on demand).
          engine_respond "--- Genie engine v#{Lich::Genie::VERSION} active"
          # Engine start: read variables.cfg and triggers.cfg once, as Remix's startup
          # does (FormMain.cs:2311, 2339 R), so saved triggers fire from the first line.
          # Neither read raises (Load is catch (Exception), Globals.cs:757-762,
          # 1105-1109 R): an unreadable file starts that list empty.
          Lich::Genie.global_store
          Lich::Genie.trigger_disabled_listener = TRIGGER_DISABLED
          Lich::Genie.filter_disabled_listener = FILTER_DISABLED
          Lich::Genie.definition_notice_listener = DEFINITION_NOTICE
          # The game state's variable changes ($health, $prompt, "lastcommand", the SpellTimer
          # port's `#var`s), its events and its printed texts go to the #triggers and the scripts
          # (a game row's from the trigger worker).
          Lich::Genie.variable_listener = ->(names) { game_state_listener(names) }
          # Game lines from outside the row parser (the assess-ids shim).
          Lich::Genie.text_listener = ->(lines) { text_lines(lines) }
          # Reserved variables from the raw game stream (Remix Game.cs), and the commands
          # the user types ($lastcommand/$lastinput).
          install_game_state_tap!
          install_upstream_hook!
          # Self-install the opt-in assess exist-id shim (off by default) so it survives relogin
          # under the in-Lich engine (native-Genie users install it from autostart instead).
          Lich::Genie::AssessIds.install! if Lich::Genie::AssessIds.enabled?
          # Feed matchwait AND #triggers with text ECHOED BY LICH (go2 messages,
          # script-exit notices, other scripts' output) -- but not `[name]>` command
          # echoes -- in addition to the raw game stream (see feed_script_output).
          install_script_output_trigger_tap!
          # A substitute's replacement is ParseGlobalVars'd at display time (Game.cs:3185 R), on
          # Lich's parser thread inside a game-state row: the host values are the last ones read
          # elsewhere, never a host call there (LichGameState::READINGS).
          Lich::Genie.display_globals = lambda do |text|
            vars = Variables.new(game_state: LichGameState.new(cached: true), global_store: Lich::Genie.global_store)
            Substitution.new(variables: vars).expand_globals(text)
          end
          Lich::Common::DownstreamHook.add('genie-downstream', lambda { |server_string|
            next server_string unless engine_on? # turned off: no gag/sub, no queue kick, the line as Lich has it

            begin
              start_command_queue! # cheap while alive; a trigger body may queue with no script running
            rescue StandardError => e
              QUEUE_ERROR.call(e) # its own rescue: a start failure must not skip this line's gag/sub
            end
            begin
              Lich::Genie.stream_filters.apply(server_string) # never raises itself (StreamFilters#apply)
            rescue StandardError => e
              # Fail open: Lich's DownstreamHook.run DELETES a hook that raises, for the session
              # (downstreamhook.rb) -- every gag/sub and the queue kick would be gone.
              FILTER_ERROR.call(e)
              server_string
            end
          }, persist: true)
        end
        private :install_downstream_hook! # only via ensure_downstream_hook!'s guard

        # Lich load: put the game-state tap in, gated on the engine being on for the
        # logged-in character ({Lich::Genie.engine_active?}), so the capture, the #triggers and
        # the stores start with the session -- the tester's login trigger `{^   Last login}`
        # fires at login, before any .cmd runs -- instead of with the first script. The tap's first
        # open row replays Lich's server buffer and starts the engine ({.ensure_downstream_hook!}).
        # @return [void]
        def install_at_lich_load!
          return unless defined?(Lich::Common::Script)

          @game_state_tap_installed = true
          Lich::Genie.game_state_feed.install(Lich::Common::Script, buffer: -> { defined?($_SERVERBUFFER_) ? $_SERVERBUFFER_ : nil },
                                                                    gate: -> { Lich::Genie.engine_active? },
                                                                    on_open: -> { ensure_downstream_hook! })
        end

        # The game state's listener: a game row's batch (GameState::Row, fed on Lich's parser
        # thread) goes to the trigger worker -- Remix's trigger Channel consumer: the row's
        # changes, its events and its printed texts are dispatched there, in row order, off Lich's
        # parser thread; a send's changes on the sending thread, at once.
        # @param names [GameState::Row, Array<String>]
        # @return [void]
        def game_state_listener(names)
          return game_state_changed(names) unless names.is_a?(GameState::Row)

          Lich::Genie.trigger_worker.post { game_state_changed(names) if engine_on? } # a row queued before a turn-off
        end

        # Whether the engine is on for the logged-in character right now ({Lich::Genie.engine_active?}:
        # after login a read of the cached per-character setting, no database) -- the gate of every
        # hot path (the game-state feed, the display and typed-command hooks, the script-output feed,
        # the trigger worker's jobs, #trigger bodies, the queue's releases), so `Lich::Genie.enabled =
        # false` stops the #triggers, gags, subs and queued sends at once, and turning it back on
        # resumes them without a restart. A failing read counts as off: Lich's line passes as it is.
        # @return [Boolean]
        def engine_on?
          Lich::Genie.engine_active? ? true : false
        rescue StandardError
          false
        end

        # Game lines Lich made outside the row parser (the assess-ids shim's enriched lines, on
        # Lich's parser thread, in its DownstreamHook -- after the row's own GameState feed): posted
        # to the trigger worker, so they follow that row's texts, and delivered like them
        # (GameEvents::TextLine: the #triggers, then the unpaused listed scripts as game lines).
        # @param lines [Array<String>]
        # @return [void]
        def text_lines(lines)
          texts = lines.map { |line| Text.trim_crlf(GameState.decode(line.to_s)) }.select { |text| GameEvents.offered?(text) }
          return if texts.empty?

          Lich::Genie.trigger_worker.post { deliver_events(texts.map { |text| GameEvents::TextLine.new(text) }) if engine_on? }
        end

        # Print the engine's own text (an echo, `#echo`, a diagnostic) through Lich's respond,
        # marked as engine output: the script-output feed never offers it to matchwait or the
        # #triggers (Remix ClassCommand_EchoText only AddText, FormMain.cs:4229-4276 R).
        # @param text [String]
        # @return [void]
        def engine_respond(text)
          Lich::Genie.engine_output { respond(text) }
        end

        # `trace_triggers` diagnostics for one game text the worker is about to deliver: the
        # text and which #triggers match it, with their class state.
        # @param text [String]
        # @return [void]
        def trace_line(text)
          return unless Lich::Genie.trace_triggers

          engine_respond "--- genie rx: #{text[0, 100].inspect}"
          Lich::Genie.triggers.diagnose(text).each do |m|
            state = m['active'] ? 'ACTIVE' : "INACTIVE (class '#{m['class']}' off)"
            engine_respond "--- genie trigger MATCH [#{state}]: /#{m['pattern'][0, 60]}/"
          end
        end

        # Start (once; a dead thread is replaced -- called on every genie script start and
        # every downstream line) the worker that drains the session's CommandQueue off Lich's
        # parser thread (CommandQueue::Worker, spec'd: its thread leaves the starting script's
        # ThreadGroup, which Lich kills with that script): each released command runs as
        # RunQueueCommand through the trigger runner (global scope, ParseCommand with
        # bSendToGame), gated on roundtime ({GameState#roundtime?}) and on $webbed / $stunned
        # like FormMain's tick (FormMain.cs:8324-8339 R). The queue is looked up on every pass
        # (a hot reload of lib/genie.rb rebuilds Lich::Genie.command_queue).
        # @return [void]
        def start_command_queue!
          # script thread (run_genie) and parser thread (hook) race here: one Worker only
          worker = QUEUE_WORKER_MUTEX.synchronize do
            @queue_worker ||= CommandQueue::Worker.new(
              queue: -> { Lich::Genie.command_queue }, state: method(:command_queue_state),
              run: ->(action, owner) { run_queued_command(action, owner) }, report: QUEUE_ERROR
            )
          end
          worker.start
        end

        # RunQueueCommand for one released action: ParseCommand through the trigger runner (global
        # scope), with the queuing script (+owner+, nil for a #trigger body / typed command) in the
        # fiber-local QUEUE_OWNER_KEY so a game send goes out labelled as that script and honours
        # its `silent` flag, as the unqueued send did on the script's own thread before v0.17
        # (the worker thread has no Script.current: "[(unknown script)]>").
        # @return [void]
        def run_queued_command(action, owner)
          return unless engine_on? # a command queued before a turn-off is dropped, not sent

          previous = Thread.current[QUEUE_OWNER_KEY]
          host = Thread.current[TriggerWorker::HOST_THREAD_KEY]
          Thread.current[QUEUE_OWNER_KEY] = owner
          Thread.current[TriggerWorker::HOST_THREAD_KEY] = true # an engine host thread: a launch waits
          trigger_runner.run_command(action)
        ensure
          Thread.current[QUEUE_OWNER_KEY] = previous
          Thread.current[TriggerWorker::HOST_THREAD_KEY] = host
        end

        # FormMain's Poll arguments: HasRoundTime, $webbed == "1", $stunned == "1".
        # @return [CommandQueue::State]
        def command_queue_state
          vars = session_memo(:queue_variables) do
            Variables.new(game_state: LichGameState.new, global_store: Lich::Genie.global_store)
          end
          CommandQueue::State.new(in_rt: Lich::Genie.game_state.roundtime?, webbed: vars.global_get('webbed') == '1',
                                  stunned: vars.global_get('stunned') == '1')
        end

        # report for a fault the queue's run let through (ParseCommand swallows its own).
        QUEUE_ERROR = ->(e) { GenieScript.engine_respond "--- Lich: genie command queue error: #{e}" }

        # Build a match line from a Lich-echoed line (feed_script_output) with Lich's strip_xml.
        # (Game rows no longer come through here: GameState prints them the Remix way.)
        #
        # CRITICAL: strip_xml is a TOP-LEVEL `def` in a real Lich (global_defs.rb),
        # which Ruby makes a PRIVATE method on Object. `respond_to?(:strip_xml)` is
        # therefore FALSE (it excludes private methods) even though strip_xml is fully
        # callable here with an implicit receiver. The old `respond_to?` guard thus
        # ALWAYS took the naive-gsub fallback -- the strip_xml path was dead code, so
        # the tester's "spellcast doesn't fire / double-cast" bug was never actually fixed
        # for prepared-spell casts (their `<spell>None</spell>You gesture.` prefix
        # glued to "NoneYou gesture."; only prefix-free `wave` casts happened to work).
        # Call strip_xml directly and fall back to the naive strip ONLY when it is
        # genuinely absent (headless specs), detected via NameError. strip_xml may
        # return nil (blank line) -> coerce to "".
        # @return [String]
        def strip_xml_line(server_string)
          strip_xml(server_string).to_s
        rescue NameError
          server_string.gsub(/<[^>]+>/, '')
        end

        # Prepend the game-state feed (once) and replay Lich's server buffer (the last 400
        # raw server strings) into the capture, so a script started mid-session sees the
        # current room, prompt, hands... The logic, its locking and its error containment
        # live in GameStateFeed (spec'd); a replayed row is never applied twice, and the
        # feed (kept in Lich::Genie) installs once per process: a reload of this file resets
        # the flag below but never re-seeds over the live state.
        # @return [void]
        def install_game_state_tap!
          return if @game_state_tap_installed
          return unless defined?(Lich::Common::Script)

          @game_state_tap_installed = true
          Lich::Genie.game_state_feed.install(Lich::Common::Script, buffer: -> { defined?($_SERVERBUFFER_) ? $_SERVERBUFFER_ : nil })
        end

        # What the user types into the front end: $lastcommand/$lastinput (GameStateFeed
        # #upstream; a typed Lich command too, as Remix behind Lich records it) and its
        # trigger-on-input ({.input_broadcast}) -- both on the trigger worker, in order with the
        # game rows: Lich's client thread runs no #trigger body.
        # Registered at the lowest priority so it runs after every other UpstreamHook and
        # sees the string Lich will actually send.
        # @return [void]
        def install_upstream_hook!
          return unless defined?(Lich::Common::UpstreamHook)

          feed = Lich::Genie.game_state_feed
          Lich::Common::UpstreamHook.add('genie-upstream', lambda { |client_string|
            next client_string unless engine_on?

            feed.upstream(client_string, on_input: ->(text) { input_broadcast(text) },
                                         post: ->(&job) { Lich::Genie.trigger_worker.post(&job) })
          }, persist: true, priority: UPSTREAM_HOOK_PRIORITY)
        end

        # UpstreamHook priority of the typed-command tap: higher runs first, so this runs last.
        UPSTREAM_HOOK_PRIORITY = -1_000_000

        # Prepend the script-output tap onto Lich's Script singleton, ONCE. This is the
        # single global choke point (Script.new_script_output is called once per Lich-echoed
        # line, regardless of how many genie scripts run), so feed_script_output runs the
        # trigger pipeline exactly once per line and fans the (filtered) line out to every
        # genie matchwait buffer itself.
        # @return [void]
        def install_script_output_trigger_tap!
          return if @script_output_tap_installed
          return unless defined?(Lich::Common::Script)

          @script_output_tap_installed = true
          Lich::Common::Script.singleton_class.prepend(ScriptOutputTriggerTap)
        end

        # A Lich COMMAND ECHO: the line Game.puts writes when a script SENDS a command,
        # `[<name>]>text` (games.rb:652, `[#{name}]#{$SEND_CHARACTER}#{str}`). These are
        # NOT game feedback or Lich messages -- native Genie never matches them -- and
        # feeding them to matchwait self-matched `put echo <sentinel>` backups instantly
        # (the regression). `[[Room]]` room titles don't match (no `]>`).
        COMMAND_ECHO = /\A\[[^\]]*\]#{Regexp.escape($SEND_CHARACTER || '>')}/.freeze

        # on_error for a failing #trigger action (ParseDispatch.fire_trigger). Remix is
        # silent: the action's un-awaited ParseCommand Task keeps its exception
        # (Command.cs:219 R; FormMain.cs:4644-4654 R). This diagnostic line is a decided
        # divergence: the remaining triggers still fire either way.
        TRIGGER_ERROR = ->(e) { GenieScript.engine_respond "--- Lich: genie trigger error: #{e}" }

        # The one warning line for a #trigger shut off after Triggers::TIMEOUT_LIMIT consecutive
        # timed-out matches (Triggers::MATCH_TIMEOUT_SECONDS each; a decided divergence).
        TRIGGER_DISABLED = lambda do |pattern|
          GenieScript.engine_respond "--- Lich: genie #trigger disabled: /#{pattern[0, 60]}/ timed out " \
                                     "#{Triggers::TIMEOUT_LIMIT} times in a row (add it again to re-enable it)"
        end

        # A list file's notice ({Lich::Genie.definition_notice}: a side file of triggers.cfg /
        # aliases.cfg that cannot be read). It comes from the first build of a registry, on whatever
        # thread asked for it, so it is printed from the trigger worker like {FILTER_DISABLED}.
        DEFINITION_NOTICE = lambda do |text|
          Lich::Genie.trigger_worker.post { GenieScript.engine_respond "--- Lich: genie #{text}" }
        end

        # A gag's / substitute's shut-off ({StreamFilters#on_disabled}): reported on Lich's parser
        # thread, maybe in the middle of a game-state row, so the warning is printed from the trigger
        # worker (an engine echo reports to the game state, whose writers that row holds).
        FILTER_DISABLED = lambda do |kind, text|
          Lich::Genie.trigger_worker.post do
            GenieScript.engine_respond "--- Lich: genie #{kind} disabled: /#{text.to_s[0, 60]}/ timed out " \
                                       "#{StreamFilters::TIMEOUT_LIMIT} times in a row (add it again to re-enable it)"
          end
        end

        # A fault around the gag/sub hook (the filters' lookup): reported, throttled; the line passes.
        FILTER_ERROR = ErrorReport.new('display filter', emit: ->(text) { GenieScript.engine_respond(text) })

        # on_error/report of the script-output feed (feed_script_output).
        FEED_ERROR = ->(e) { GenieScript.engine_respond "--- Lich: genie script-output feed error: #{e}" }

        # Offer one Lich-echoed (script-output) line to the Genie engine: every running genie
        # script's matchwait buffer and the global #triggers (ParseDispatch.feed_output: the
        # dispatch-depth stamp of the nested-dispatch cap (20 levels, a decided divergence: Remix
        # recurses until the client crashes) and the overflow deferral live there, spec'd) -- but
        # SKIP `[name]>` command echoes (see COMMAND_ECHO) and the engine's own output (an echo,
        # `#echo`, a trigger echo, an engine diagnostic -- {.engine_respond}; Genie never parses them).
        # The line is decoded like a game row (invalid UTF-8 -> U+FFFD) and CR/LF-trimmed only
        # (Utility.Trim). This is the filtered replacement for
        # want_script_output: matchwait/#triggers see genuine Lich messages (go2, script-exit,
        # other scripts' output) without the script's own sent-command echoes. Game text comes
        # from GameState through the trigger worker (GameEvents::TextLine), so this only adds
        # Lich's OWN messages (a decided superset: Genie has no such text).
        #
        # Re-entrancy is guarded PER THREAD: a trigger action that itself echoes (respond ->
        # new_script_output -> here) must not recurse. fire/apply are synchronous, so a
        # thread-local flag suffices. Never raises into the respond path (Lich's respond
        # would swallow it anyway).
        #
        # Every line Lich echoes is main-window text first: it clears the game state's
        # last-row-was-prompt flag (GameState#printed; FormMain.AddText, FormMain.cs:5100-5122 R),
        # command echoes and lines echoed inside a trigger action included.
        # @param line [String]
        # @return [void]
        def feed_script_output(line)
          return unless engine_on?

          note_printed(line)
          return if Thread.current[:genie_in_script_trigger] || Lich::Genie.engine_output?
          return if line.to_s =~ COMMAND_ECHO

          Thread.current[:genie_in_script_trigger] = true
          # A #trigger body run here on a walk's thread (a Lich line DRCT.walk_to printed) starts
          # its scripts as the trigger's, not the walk's.
          walk_tracking = Thread.current[WALK_TRACK_KEY]
          Thread.current[WALK_TRACK_KEY] = nil
          begin
            text = Text.trim_crlf(GameState.decode(strip_xml_line(line).to_s))
            return if Text.net_trim(text).empty?

            ParseDispatch.feed_output(text, buffers: matchwait_buffers, triggers: Lich::Genie.triggers,
                                            runner: trigger_runner, on_error: TRIGGER_ERROR, report: FEED_ERROR)
          ensure
            Thread.current[:genie_in_script_trigger] = false
            Thread.current[WALK_TRACK_KEY] = walk_tracking
          end
        rescue StandardError => e
          FEED_ERROR.call(e)
        end

        # {feed_script_output}'s report to GameState#printed. A failure is swallowed, never
        # reported: its report would be a respond line, which comes straight back here.
        # Approximation: Lich's respond/_respond reach this path whatever stream the
        # text was meant for, so a Lich line sent to a non-main stream also clears the flag (Remix
        # clears it only for text printed to the main window). It takes GameState's state lock only
        # (never the writers' lock a row holds across the display port), and that lock
        # is never held across foreign code: a thread that prints while holding a lock of its own
        # (Map.load_json's load lock around `respond map_loaded_message`) cannot deadlock against
        # the parser thread -- and the display port reads no Lich host code (LichGameState::READINGS).
        # @param line [String]
        # @return [void]
        def note_printed(line)
          Lich::Genie.game_state.printed(line.to_s)
        rescue StandardError
          nil
        end

        # The echo port of the genie interpreters and the trigger runner: Lich's respond
        # through DispatchDepth.respond_in_chain (re-raises a nested-dispatch overflow the script-output
        # feed deferred inside it, so nothing more of the capped chain runs).
        # @param text [String]
        # @return [void]
        def respond_in_chain(text)
          DispatchDepth.respond_in_chain(->(t) { engine_respond(t) }, text)
        end

        # @return [Array] the downstream (matchwait) buffers of the listed genie scripts
        def matchwait_buffers
          listed_scripts.map { |script| script.downstream_buffer.engine_port }
        rescue StandardError
          []
        end

        # The genie scripts in the Genie script list (m_oScriptList), in list order: what every
        # Remix walker sees ({ScriptList}). Lich's own registry (Script.running) is not used: a
        # script is in it from its start, before Remix would list it, and it skips Lich-hidden
        # scripts (Genie has none).
        # @return [Array<GenieScript>]
        def listed_scripts
          Lich::Genie.script_list.listed.grep(GenieScript)
        end

        # A `.name args` launch (ClassCommand_RunScript, FormMain.cs:4678-4714 R): ParseArgs, the
        # exact `<name>.cmd`, the dupe check, the start. A script's own row passes
        # itself as +launcher+ and waits for the child's first run (Remix runs it inside the
        # launching row) -- at most FIRST_RUN_WAIT_SECONDS; so does a #trigger body run on a
        # script's own thread ({.host_launch}: that script is the launcher), and, with no
        # launcher, one run on the trigger worker or the command-queue worker (Remix runs
        # the first run synchronously on its trigger consumer / timer too). Lich's own threads
        # never wait.
        # @param name [String] ParseArgs token 0 minus the script char, lower-cased
        # @param rest [String] the text after token 0
        # @param launcher [GenieScript, nil]
        # @return [GenieScript, nil] the started script
        # @raise [Error] a malformed argument string ("Invalid string in Parse Arguments")
        # @param wait [Boolean] wait for the child's first run (default: when there is a launcher)
        def launch(name, rest, launcher: nil, wait: !launcher.nil?)
          list = Lich::Genie.script_list
          script = start_request(ScriptLaunch.request(name, rest), launcher: launcher)
          list.wait_first_run(script, timeout: FIRST_RUN_WAIT_SECONDS) if script && wait
          script_list_changed if list.tick_end_outside_script
          script
        end

        # LoadScript + RunScript for a parsed launch: the first-run nesting cap ({ScriptList::LIMIT}),
        # then, with abortdupescript, every LISTED copy of the file aborted (FormMain.cs:3401-3426 R:
        # before the file is even read, so a missing file still ends the old copy), then the file
        # (a missing or empty one prints Remix's script error and starts nothing), then the start.
        # @param request [ScriptLaunch::Request]
        # @param launcher [GenieScript, nil]
        # @return [GenieScript, nil]
        def start_request(request, launcher: nil)
          list = Lich::Genie.script_list
          if list.launch_depth(launcher) > ScriptList::LIMIT
            respond_in_chain("[Script error: maximum nested dispatch depth (#{ScriptList::LIMIT}) exceeded on: .#{request.file_name}]")
            return nil
          end
          list.duplicates(request.file_name).each(&:genie_abort) if Lich::Genie.abort_dupe_script?
          dir = Lich::Genie.directories['scriptdir']
          start_exact(ScriptLaunch.resolve(dir, request.file_name), dir, request, launcher)
        rescue ScriptLaunch::NotLoadable => e
          respond_in_chain("[Script error: #{e.message}]") # Script.PrintError (Script.cs:3779-3784 R)
          nil
        end

        # Lich's Script.start of exactly +path+ (forced: Lich's own duplicate refusal never applies,
        # the dupe check above is Remix's), with the launch in LAUNCH_KEY for ExactLaunchFinder and
        # GenieScript#initialize.
        # @return [GenieScript, nil]
        def start_exact(path, dir, request, launcher)
          install_exact_finder!
          started = nil
          launch = { token: request.file_name, relative: path.delete_prefix(File.join(dir, '')), path: path,
                     file_name: request.file_name, args: request.args, launcher: launcher, script: nil }
          previous = Thread.current[LAUNCH_KEY]
          Thread.current[LAUNCH_KEY] = launch
          started = Lich::Common::Script.start(request.file_name, request.args.join(' '), { force: true })
        ensure
          # a script built but never started (Script.start returned nil or raised) never runs: no
          # pending entry may outlive it
          Lich::Genie.script_list.finished(launch[:script]) if launch && launch[:script] && started.nil?
          Thread.current[LAUNCH_KEY] = previous if launch
        end

        # @return [GenieScript, nil] the genie script whose thread this is, when it is the
        #   thread's dispatch owner
        def dispatch_owner_script
          owner = ParseDispatch.owner
          return nil unless owner

          script = Lich::Common::Script.current_without_pause
          script.is_a?(GenieScript) && script.genie_interpreter.equal?(owner) ? script : nil
        end

        # @return [void]
        def install_exact_finder!
          return if @exact_finder_installed
          return unless defined?(Lich::Common::Script)

          @exact_finder_installed = true
          Lich::Common::Script.singleton_class.prepend(ExactLaunchFinder)
        end

        # The trigger runner's launch port (a #trigger body, a queued command): {.launch}; a fault
        # is reported like the script launch port does. A body run on a script's own thread (its
        # `#parse`, a variable change it made, its own input -- ParseDispatch.owner) runs inside
        # that script's row in Remix, so that script is the launcher; on the
        # trigger worker or the queue worker there is none, but the worker waits for the first run;
        # on any other thread nothing waits.
        # @return [GenieScript, nil]
        def host_launch(name, rest)
          launcher = dispatch_owner_script
          launch(name, rest, launcher: launcher, wait: !launcher.nil? || Thread.current[TriggerWorker::HOST_THREAD_KEY] == true)
        rescue DispatchDepth::Exceeded
          raise
        rescue StandardError => e
          engine_respond "--- Lich: genie could not launch script '#{name}': #{e}"
          nil
        end

        # Deliver a `#parse` line (ParseTriggers, FormMain.cs:4425-4512 R) through the pure
        # ParseDispatch.broadcast: the global #triggers fire on the CALLING thread (a failing
        # action prints TRIGGER_ERROR and the rest still fire), then every running, unpaused
        # genie script in Script.running order -- this thread's dispatch owner inline at its
        # position, the others queued with the dispatch depth. DispatchDepth::Exceeded is not rescued.
        # @param text [String]
        # @return [void]
        def parse_broadcast(text)
          ParseDispatch.broadcast(text, triggers: Lich::Genie.triggers, runner: trigger_runner, recipients: genie_recipients,
                                        on_error: TRIGGER_ERROR)
        end

        # Deliver a global variable change (FormMain.TriggerVariableChanged, FormMain.cs:
        # 4725-4989 R) through the pure VariableDispatch.broadcast: the eval #triggers fire on the
        # CALLING thread, then every running, unpaused genie script -- this thread's dispatch
        # owner inline, the others queued with the dispatch depth. Raised by the scripts' and the
        # trigger runner's `#var`/`#tvar`/`#svar`/`#math`, by the game state after each row
        # (Lich's parser thread, outside its lock) and after each send (the sending thread).
        # A nested-dispatch overflow stops the owning script, or is printed when no script owns
        # the thread. Never raises into the caller except the owner's own faults. Only scripts
        # whose interpreter can use a change get one queued, one per call (VariableDispatch).
        # @param names [String, Array<String>] one name, or one game row's names
        # @param queue_owner [Boolean] queue for this thread's own script too (VariableDispatch)
        # @param game [Boolean] a game row's names ({game_state_changed})
        # @return [void]
        def variable_broadcast(names, queue_owner: false, game: false)
          VariableDispatch.broadcast(names, triggers: Lich::Genie.triggers, runner: trigger_runner, recipients: genie_recipients,
                                            on_error: TRIGGER_ERROR, on_overflow: ->(message) { engine_respond("[#{message}]") },
                                            queue_owner: queue_owner, game: game)
          # then the plugins (SafeParsePluginVariable, FormMain.cs:5045-5050 R): a `#var roomname` /
          # `#var prompt` reaches the automapper (GameState#plugin_variable_changed); a game row's
          # own changes are the capture's already
          Lich::Genie.game_state.plugin_variable_changed(names) unless game
        end

        # Trigger-on-input: with `triggeroninput` (settings.cfg, default on; Config.cs:19 R)
        # a sent or typed text goes through ParseTriggers(sText) after its send (ClassCommand_
        # SendText, FormMain.cs:4391-4422 R): the global #triggers, then every listed script as a
        # game line -- the sender inline, depth-capped (ParseDispatch.input).
        # @param text [String]
        # @return [void]
        def input_broadcast(text)
          return unless engine_on? && Lich::Genie.game_state.config.trigger_on_input

          ParseDispatch.input(text.to_s, triggers: Lich::Genie.triggers, runner: trigger_runner, recipients: genie_recipients,
                                         on_error: TRIGGER_ERROR, on_overflow: ->(message) { engine_respond("[#{message}]") })
        end

        # GameState's listener (the trigger worker for a game row, the sending thread for a
        # send): a fed row's changes (a GameState::Row) are a game row's -- part of a DR packet,
        # VariableDispatch::Change#game? -- and its script-timing events follow them
        # (GameEvents.deliver: SetRoundTime to every genie script, the prompt text to the #triggers,
        # TriggerPrompt / TriggerMove to the unpaused ones), stamped on the interpreters' clock
        # (CLOCK_MONOTONIC); a send's are plain changes.
        # @param names [GameState::Row, Array<String>]
        # @return [void]
        def game_state_changed(names)
          return variable_broadcast(names) unless names.is_a?(GameState::Row)

          variable_broadcast(names, game: true)
          deliver_events(names.events)
          refresh_map_readings if names.include?('$roomid')
        end

        # The names the display port's globals take from Lich's map ({LichGameState::READINGS}).
        MAP_READINGS = %w[roomid zoneid zonename].freeze

        # At an automapper room update ("$roomid" in a game row), on the trigger worker: read the
        # map values once so the display port's globals replay this room's, not only what a script
        # last read. From a map Lich has loaded only: a load is never started here.
        # @return [void]
        def refresh_map_readings
          return unless Lich::Common::Map.loaded?

          live = LichGameState.new
          MAP_READINGS.each { |name| live[name] }
        rescue StandardError
          nil
        end

        # GameEvents.deliver of a game row's events to the listed genie scripts (stamped on the
        # interpreters' clock, CLOCK_MONOTONIC), their texts to the #triggers first.
        # @param events [Array]
        # @return [void]
        def deliver_events(events)
          return if events.empty?

          GameEvents.deliver(events, recipients: genie_recipients, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                                     triggers: Lich::Genie.triggers, runner: trigger_runner, on_error: TRIGGER_ERROR,
                                     trace: ->(text) { trace_line(text) })
        end

        # The listed genie scripts as dispatch recipients, in list order.
        # @return [Array<ParseDispatch::Recipient>]
        def genie_recipients
          listed_scripts.map do |script|
            ParseDispatch::Recipient.new(interpreter: script.genie_interpreter, buffer: script.downstream_buffer.engine_port,
                                         paused: -> { script.input_dropped? }) # only `#script pause` drops
          end
        end

        # The genie script list changed (a script started, finished, or was paused or resumed
        # by `#script`): Remix's tick-end SetScriptListVariable raises "scriptlist"
        # (FormMain.cs:3481-3483, 3832, 4516-4541, 8345-8351 R). Never raises, except a nested-dispatch
        # overflow inside an enclosing chain (DispatchDepth.contain).
        # @param queue_owner [Boolean] see {.variable_broadcast}
        # @return [void]
        def script_list_changed(queue_owner: false)
          DispatchDepth.contain(TRIGGER_ERROR) { variable_broadcast('scriptlist', queue_owner: queue_owner) }
        end

        # Global-scoped runner that executes trigger actions (shared global store, so
        # trigger #vars are visible to scripts).
        # @return [TriggerRunner]
        def trigger_runner
          session_memo(:trigger_runner) do
            vars = Variables.new(game_state: LichGameState.new, global_store: Lich::Genie.global_store)
            globals = Object.new
            globals.define_singleton_method(:key?) { |name| vars.global_key?(name) }
            TriggerRunner.new(
              vars: vars, eval: Eval.new(globals: globals),
              game: LichGamePort.new,
              launch: ->(name, args) { GenieScript.host_launch(name, args) },
              hooks: LichHookSink.new, echo: ->(text) { respond_in_chain(text) },
              script_control: LichScriptControl.new,
              # `#goto` in a #trigger body: the same async walk, launched by the body's script if it
              # runs on a script's thread (ParseDispatch.owner)
              mover: ->(room) { GenieScript.goto(room, launcher: GenieScript.dispatch_owner_script) },
              parse: ->(text) { parse_broadcast(text) },
              var_changed: ->(name) { variable_broadcast(name) },
              queue: -> { Lich::Genie.command_queue },
              lists: Lich::Genie.lists, log_dir: -> { Lich::Genie.directories['logdir'] },
              active: -> { engine_on? }
            )
          end
        end

        # A glue object built over the session singletons (Lich::Genie.global_store and
        # .game_state), rebuilt when either is replaced -- a hot reload of lib/genie.rb, a
        # config-dir change or reset_global_store! -- so the trigger runner and the queue's state
        # read never keep a dropped store. Built under a mutex: the
        # parser, queue-worker and script threads all ask.
        # @param name [Symbol]
        # @return [Object] the memoized object
        def session_memo(name)
          key = [Lich::Genie.global_store, Lich::Genie.game_state]
          SESSION_MEMO_MUTEX.synchronize do
            @session_memos ||= {}
            memo = @session_memos[name]
            next memo[1] if memo && memo[0].zip(key).all? { |old, new| old.equal?(new) }

            yield.tap { |built| @session_memos[name] = [key, built] }
          end
        end

        # `#goto <room>`: Remix's AutoMapper goto arm through GotoWalk -- it returns at once;
        # the walk (DRCT.walk_to, go2 under the hood) runs in its own hidden Lich script
        # ({WalkRunner}). Genie `#goto` / $roomid use the CURRENT zone's local node id, stamped on
        # Lich rooms as genie_zone/genie_id (Map.by_genie_ref); {.resolve_genie_room} (a decided
        # divergence). A fault is reported, never raised into the row.
        # @param room [String]
        # @param launcher [GenieScript, nil] the script whose row (or #trigger body) runs it
        # @return [GotoWalk::Handle, nil]
        def goto(room, launcher: nil)
          GotoWalk.go(room.to_s, host: goto_host, launcher: launcher)
        rescue DispatchDepth::Exceeded
          raise
        rescue StandardError => e
          engine_respond "--- Lich: genie #goto error: #{e}"
          nil
        end

        # GotoWalk's Lich side: the walk runs in a hidden Lich script ({.spawn_walk}), which is
        # what a stop kills, with the scripts its walk started ({WalkRunner#stop}).
        # @return [GotoWalk::Host]
        def goto_host
          GotoWalk::Host.new(
            resolve: ->(arg) { resolve_genie_room(arg) }, here: -> { current_room_id },
            walk: ->(target) { walk_to(target) },
            spawn: ->(&block) { spawn_walk(&block) },
            stop: ->(runner) { stop_walk(runner) },
            echo: ->(text) { respond_in_chain(text) },
            set_var: ->(name, value) { goto_set_var(name, value) },
            parse: ->(text) { goto_parse(text) },
            list: Lich::Genie.script_list, abort_dupe: Lich::Genie.abort_dupe_script?,
            changed: -> { script_list_changed }
          )
        end

        # @return [Integer, nil] the current Lich room id (Remix's m_LastNode), nil when unknown
        def current_room_id
          Lich::Common::Map.current&.id
        end

        # DRCT.walk_to, on the walk's own Lich script, with the scripts it starts recorded as the
        # walk's ({WalkRunner#tracking}).
        # @return [Boolean] whether DRCT.walk_to arrived (a fault is reported: false)
        def walk_to(target)
          runner = Thread.current[WALK_RUNNER_KEY]
          walk = -> { Lich::DragonRealms::DRCT.walk_to(target, false) ? true : false }
          runner ? runner.tracking(&walk) : walk.call
        rescue StandardError => e
          engine_respond "--- Lich: genie #goto error: #{e}"
          false
        end

        # Start a walk's body in a hidden Lich script named automapper<N> (Lich's own ExecScript,
        # as Lich starts its infomon/drinfomon helpers: quiet -- no active/exited lines that the
        # script-output feed would hand to the genie scripts -- and hidden from `;list`): its own
        # thread and ThreadGroup from the start, a Script.current for DRCT.walk_to's
        # helpers, and Lich's kill to stop it.
        # @yield the walk's body
        # @return [WalkRunner, nil] nil when Lich started no script
        def spawn_walk(&body)
          install_walk_start_tracker!
          runner = WalkRunner.new(body)
          token = WALK_RUNNERS_MUTEX.synchronize do
            @walk_runners ||= {}
            # a walk script killed before {.run_walk} took its runner leaves it here
            @walk_runners.delete_if { |_, waiting| waiting.script && !waiting.script.running? }
            @walk_token = (@walk_token || 0) + 1
            @walk_runners[@walk_token] = runner
            @walk_token
          end
          script = Lich::Common::ExecScript.start("Lich::Genie::GenieScript.run_walk(#{token})", { quiet: true, name: WALK_SCRIPT_PREFIX })
          unless script.is_a?(Lich::Common::Script)
            WALK_RUNNERS_MUTEX.synchronize { @walk_runners.delete(token) }
            return nil
          end
          script.hidden = true
          runner.script = script
          runner
        end

        # The walk script's body (its ExecScript code): run the walk registered under +token+.
        # Hidden from its first statement (this thread may run before
        # {.spawn_walk}'s own `hidden = true`). However the walk ends -- arrived, failed, or its
        # script killed by Lich itself (`;kill automapper1`) -- the scripts it started that still
        # run are killed in its ensure: a walk's go2 never walks on without it.
        # @param token [Integer]
        # @return [void]
        def run_walk(token)
          Lich::Common::Script.current&.hidden = true
          runner = WALK_RUNNERS_MUTEX.synchronize { (@walk_runners || {}).delete(token) }
          return unless runner

          Thread.current[WALK_RUNNER_KEY] = runner
          runner.run
        ensure
          Thread.current[WALK_RUNNER_KEY] = nil
          runner&.stop_started
        end

        # Stop a walk ({WalkRunner#stop}).
        # @param runner [WalkRunner]
        # @return [void]
        def stop_walk(runner)
          runner&.stop
        rescue StandardError
          nil
        end

        # @return [void]
        def install_walk_start_tracker!
          return if @walk_tracker_installed
          return unless defined?(Lich::Common::Script)

          @walk_tracker_installed = true
          Lich::Common::Script.singleton_class.prepend(WalkStartTracker)
        end

        # set_GlobalVariable (AutoMapper.cs:2003-2010 R): store, then raise "$name". The indexer
        # keeps an existing variable's type and adds a new one as SaveToFile (Globals.cs:679-693 R).
        # @return [void]
        def goto_set_var(name, value)
          store = Lich::Genie.global_store
          store.set(name, value, persist: !store.key?(name) || store.persistent?(name))
          variable_broadcast("$#{name}")
        end

        # ParseText (ParseTriggers(text, false), FormMain.cs:4659-4667 R), one nested-dispatch level
        # like a script's `#parse` (a #trigger on "DESTINATION FOUND" that runs `#goto` again recurses).
        # @return [void]
        def goto_parse(text)
          DispatchDepth.nest("#parse #{text}", on_overflow: VariableDispatch.overflow_handler(->(message) { engine_respond("[#{message}]") })) do
            parse_broadcast(text)
          end
        end

        # Genie node id -> Lich room id. In a known zone (the current Lich room carries a Genie
        # stamp) only that zone's node is found -- m_Nodes.Find(id) on the loaded zone map, else
        # Remix's not-found (AutoMapper.cs:1176-1192 R). Decided divergence:
        # with the current room unstamped (or unknown) the number is tried as a Lich room id, then
        # a game uid -- compensating for Lich mapdb stamp gaps where Remix's own map would know the
        # location.
        # @return [Integer, nil]
        def resolve_genie_room(node)
          return nil if node.empty?

          zone = (Lich::Common::Map.current&.genie_zone).to_s
          return Lich::Common::Map.by_genie_ref(zone, node)&.id unless zone.empty?
          return unless node =~ /\A\d+\z/

          id = node.to_i
          return id if Lich::Common::Map.list[id]

          Array(Lich::Common::Map.ids_from_uid(id)).first
        end
      end

      private

      # Launch another script from within this one (`put .name args`): exactly `<name>.cmd`, the
      # dupe check, and this thread waits for the child's first run ({GenieScript.launch}).
      def launch_script(name, args)
        GenieScript.launch(name, args, launcher: self)
      rescue DispatchDepth::Exceeded
        raise
      rescue StandardError => e
        GenieScript.engine_respond "--- Lich: genie could not launch script '#{name}': #{e}"
      end

      # `#goto <room>` from a script's row: the async walk ({GenieScript.goto}); the script goes
      # on with its next row.
      def genie_goto(room)
        GenieScript.goto(room, launcher: self)
      end

      # An `include <name>` (AppendFile, Script.cs:3683-3800 R): exactly that file under the
      # engine's script dir ($scriptdir) -- no extension added, no custom/ fallback, like a
      # launch (ScriptLaunch.locate). nil = not there (the Lexer's "File not found" script
      # error stops the load).
      # @return [String, nil] the file's bytes
      def load_include(name)
        path = ScriptLaunch.locate(Lich::Genie.directories['scriptdir'], name)
        path ? File.binread(path) : nil
      end

      # The script file's bytes (gunzipped for a Lich `.gz`); the Lexer splits them like
      # StreamReader.ReadLine (CR, LF, CRLF; a BOM at the start).
      # @return [String]
      def read_source(file_name)
        begin
          Zlib::GzipReader.open(file_name) { |f| return f.read }
        rescue StandardError
          nil
        end
        File.binread(file_name)
      rescue StandardError => e
        GenieScript.engine_respond "--- Lich: error reading script file (#{file_name}): #{e}"
        ''
      end
    end

    # Host script-control port backing `#script abort/pause/resume/pauseorresume/reload`
    # (Command_ScriptAbort / Pause / Resume / PauseOrResume / Reload, FormMain.cs:5783-6080 R).
    #
    # Walks the Genie script list (m_oScriptList, {ScriptList}): only genie (.cmd) scripts, so
    # `#script abort all` can never take down core Lich daemons (the mapper, infomon, the command
    # broker, unrelated .lic scripts), and only LISTED ones, so a script still in its first run
    # (or its launcher's) is not touched (a tester script's `put #script abort all except <other>` openers,
    # flow t158/t159). Names match exactly (ScriptName == the spec, case-sensitive) and every
    # listed match is acted on. The CommandRouter resolves "all"/"except"; a status change is
    # stored in $scriptlist at the next tick end ({ScriptList#tick_end_outside_script}).
    class LichScriptControl
      # @return [Array<String>] names of the listed genie scripts, in list order (a `#goto` walk
      #   in progress is "automapper", like the automapper.cmd it stands for)
      def names
        listed.map(&:name)
      end

      # AbortScript on each listed match (a script aborting itself runs no further row; a
      # walk stops, GotoWalk::Handle#genie_abort).
      def abort(name)
        listed_named(name).each(&:genie_abort)
        tick_end
      end

      # PauseScript: Genie's own pause (the input drops while it holds); every call is a
      # status change (Script.cs:1075-1076 R).
      def pause(name)
        scripts_named(name).each do |script|
          script.genie_pause unless script.input_dropped?
          list.changed!
        end
        tick_end
      end

      # ResumeScript (Script.cs:1079-1106 R).
      def resume(name)
        scripts_named(name).each do |script|
          script.unpause if script.paused?
          list.changed!
        end
        tick_end
      end

      def pauseorresume(name)
        scripts_named(name).each do |script|
          script.paused? ? script.unpause : script.genie_pause
          list.changed!
        end
        tick_end
      end

      # Genie `#script reload`: restart a listed genie script with its own launch arguments.
      # Remix instead hot-reloads it in place at its next `goto`, keeping its variables, actions
      # and matches (ReloadScript / HotReload, Script.cs:1026-1051, 1906-1950, 2457 R) --
      # tracked divergence, 0 corpus uses.
      def reload(name)
        scripts_named(name).each do |script|
          script.genie_abort
          GenieScript.start_request(ScriptLaunch::Request.new(file_name: script.genie_file_name, args: script.genie_args))
        end
        tick_end
      end

      # Command_ScriptDebugLevel (FormMain.cs:6083 R): the level for every listed script of the name.
      def debug(level, name)
        scripts_named(name).each { |script| script.genie_interpreter&.debug_level = level }
      end

      private

      def list
        Lich::Genie.script_list
      end

      # The listed genie scripts and `#goto` walks, in list order.
      def listed
        list.listed.select { |entry| entry.is_a?(GenieScript) || entry.is_a?(GotoWalk::Handle) }
      rescue StandardError
        []
      end

      def listed_named(name)
        listed.select { |script| script.name == name.to_s }
      end

      # The listed genie scripts named +name+: a walk cannot be paused or reloaded (tracked).
      def scripts_named(name)
        listed_named(name).grep(GenieScript)
      end

      def tick_end
        GenieScript.script_list_changed if list.tick_end_outside_script
      end
    end

    # Sends a Genie command to the game via Lich's `put` (echo + prefix + send).
    # Pacing/broker mediation will be layered here per design Decision 5.
    class LichGamePort
      # A Lich command char (`,` or `;`) at the very start of the command -- what a
      # user types to run a Lich script/command (`,go2 123`, `,kill sc`). Matches the
      # same set as Lich's own client-input path ($lich_char_regex = union(',',';')).
      LICH_COMMAND = /\A(?:<c>)?[,;]\S/

      # Sends at once, in roundtime too: Remix gates a script's RESUMES on roundtime
      # (Script.cs:1505-1511 R), never a send (Script_EventSendText / ClassCommand_SendText,
      # FormMain.cs:6812-6823, 4391-4422 R) -- an action body's or a #trigger's put during RT goes
      # out and the game answers "...wait N seconds", as in Remix; a released `#queue` item no
      # longer blocks the queue worker (the old waitrt? here, before v0.18, was the stand-in for
      # the missing resume gate).
      #
      # A leading `,`/`;` is NOT a game command -- it is a Lich command (script launch,
      # kill/pause/list, etc.). In native-Genie-over-Lich, `put ,go2 123` reaches
      # Lich's client-input path (do_client), which sees the `,` and dispatches it; a
      # plain `put` would send it to the GAME instead (the "Please rephrase that
      # command" bug from home.cmd). So route those through do_client exactly as if the
      # user had typed them -- but ONLY a {LichCommand}: a send whose `,`/`;` the author wrote,
      # and for a code-running command (`,e`, `,exec`, `,l5u`, ...) one from a literal .cmd `put`
      # row (a decided divergence, for security; {AuthoredCommand.lich_command}, the one place it
      # is made). Any other text starting with `,`/`;` -- one a variable or a capture of another
      # player's words put there (`action put $1 when ...` fed `,e ...`) -- goes to the game as
      # ordinary text, as from Genie connected to the game.
      #
      # Either way the text is a Remix SendText: $lastcommand (Game.cs:545-551 R; a Lich
      # command too -- Remix behind Lich does not know it is one), then trigger-on-input
      # (GenieScript.input_broadcast).
      #
      # A text starting with the mycommandchar ('/' by default; GameState#my_command?) is checked
      # first, on the raw text: SendText shows its echo but sends it nowhere -- not to the game, not
      # to Lich -- and records no $lastcommand (Game.cs:467, 527, 545 R); trigger-on-input still
      # parses it (FormMain.cs:4391-4422 R). Corpus: the tester's `put /spelltimer` (8 files), `/sort`.
      #
      # The engine off for the character: nothing is sent -- a script's send is
      # dropped with one notice per off spell ({GenieScript#genie_send_allowed?}); #trigger bodies
      # and queue releases are stopped before they get here.
      def send_command(text)
        owner = Thread.current[GenieScript::QUEUE_OWNER_KEY]
        return unless engine_sends?(owner || Lich::Common::Script.current_without_pause)

        lich_command = text.is_a?(LichCommand)
        text = text.to_s
        echoed = true
        if Lich::Genie.game_state.my_command?(text)
          echoed = echo_only(owner, text)
        elsif lich_command && text.lstrip =~ LICH_COMMAND
          dispatch_lich_command(text)
        else
          owner ? put_as(owner, text) : (echoed = put_from_script(text))
        end
        Lich::Genie.game_state.sent(text, echoed: echoed) # a hidden echo leaves the prompt flag (parity 1)
        GenieScript.input_broadcast(text)
      end

      private

      # Whether +sender+'s send may go out: a genie script asks itself (one notice per off spell),
      # anything else only reads the gate.
      def engine_sends?(sender)
        sender.is_a?(GenieScript) ? sender.genie_send_allowed? : GenieScript.engine_on?
      end

      # A mycommandchar text: the echo Lich's put would show (same label, the same origin gag and
      # `silent` rules as {#put_from_script} / {#put_as}), but no wire write, no client-buffer or
      # last-upstream record -- nothing was sent.
      # @return [Boolean] whether the echo was shown (false only when a gag hid it)
      def echo_only(owner, text)
        if owner
          respond "[#{script_label(owner)}]#{$SEND_CHARACTER}#{text}\r\n" unless owner.silent
          return true
        end

        script = Lich::Common::Script.current_without_pause
        origin = Thread.current[TriggerRunner::ORIGIN_KEY] || (script.name if script.is_a?(GenieScript))
        return false if origin && Lich::Genie.stream_filters.hides_echo_of?(origin)

        respond "[#{script ? script_label(script) : '(unknown script)'}]#{$SEND_CHARACTER}#{text}\r\n" unless script&.silent
        true
      end

      # Game.puts' "[name]" label: custom/ for a custom script.
      def script_label(script)
        "#{script.respond_to?(:custom?) && script.custom? ? 'custom/' : ''}#{script.name}"
      end

      # Lich's put -- unless a gag matches the send's ORIGIN: Game.SendText then shows no
      # "[origin]: text" echo (Game.cs:481-511 R; any gag, active or not; the send itself goes out).
      # The origin is "Trigger" for a #trigger body's send (TriggerAction, FormMain.cs:4647 R;
      # TriggerRunner::ORIGIN_KEY) and the script's name for a script's own send
      # (Script_EventSendText, FormMain.cs:6823 R); a queue release (origin "") is never hidden.
      # @return [Boolean] whether the echo was shown
      def put_from_script(text)
        script = Lich::Common::Script.current_without_pause # Script.current blocks while paused
        origin = Thread.current[TriggerRunner::ORIGIN_KEY] || (script.name if script.is_a?(GenieScript))
        unless origin && Lich::Genie.stream_filters.hides_echo_of?(origin)
          put(text)
          return true
        end

        put_named(script ? script_label(script) : '(unknown script)', text, echo: false)
        false
      end

      # Game.puts (games.rb:713-739) for a command the queue worker releases on behalf of
      # +script+: the worker thread has no Script.current, so Lich's put would label it
      # "(unknown script)" and ignore the script's `silent`. Same display, client buffer,
      # last-upstream record and wire string as put from the script's own thread;
      # Game.puts' execution-guard branch is skipped (a genie script installs no guard).
      def put_as(script, str)
        put_named(script_label(script), str, echo: !script.silent)
      end

      # Game.puts' client buffer, display (+echo+), wire string and last-upstream record under +name+.
      def put_named(name, str, echo:)
        $_CLIENTBUFFER_.push "[#{name}]#{$SEND_CHARACTER}#{$cmd_prefix}#{str}\r\n"
        respond "[#{name}]#{$SEND_CHARACTER}#{str}\r\n" if echo
        ::Game._puts "#{$cmd_prefix}#{str}"
        $_LASTUPSTREAM_ = "[#{name}]#{$SEND_CHARACTER}#{str}"
      end

      def dispatch_lich_command(text)
        # do_client mutates (strip!) and expects the command WITH its leading char;
        # pass a dup so a frozen/shared string is never mutated. do_client is a
        # top-level Lich def (private on Object) -- callable with an implicit receiver.
        previous = Thread.current[GameStateFeed::ENGINE_CLIENT_KEY]
        Thread.current[GameStateFeed::ENGINE_CLIENT_KEY] = true # the typed-command tap skips it: the sender records it
        begin
          do_client(text.to_s.lstrip.dup)
        ensure
          Thread.current[GameStateFeed::ENGINE_CLIENT_KEY] = previous
        end
      rescue StandardError => e
        GenieScript.engine_respond "--- Lich: genie could not run Lich command '#{text}': #{e}"
      end
    end

    # Reads the next downstream line from the running script's buffer, honoring the
    # interpreter's deadline via Script#gets(timeout). While a Lich-level pause holds the script
    # (GenieScript#input_held?, a decided divergence) it reads nothing: what arrives stays buffered,
    # in order, for after the unpause. (Before v0.18 a Lich pause stopped no row at all -- only the
    # sends blocked in Game.puts; the buffer keeps its last 400 ITEMS -- lines, variable changes,
    # prompts, roundtimes -- not 400 game lines.)
    class LichInputPort
      def initialize(script)
        @script = script
      end

      # Every read is where the script's run is over (it waits): the script list's tick end
      # (GenieScript#genie_run_ended) comes first.
      def next_line(timeout: nil)
        @script.genie_run_ended
        return hold(timeout) if @script.input_held?

        item = @script.gets(timeout)
        return item unless item && @script.input_held?

        # a read already blocked in gets when a Lich-level pause began took the pause's first
        # item: keep it, in front, for after the unpause (handling it now would fire
        # actions mid-pause)
        @script.downstream_buffer.unshift(item)
        nil
      end

      private

      # Wait while held, at most +timeout+ (nil = until the hold ends). Still held: nothing (the
      # interpreter re-checks its paused port and reads again). Unpaused: what was buffered first,
      # at once -- before the interpreter re-checks a deadline that ran out during the pause, so a
      # reply that came in the pause still ends its matchwait.
      def hold(timeout)
        @script.wait_while_held(timeout)
        @script.input_held? ? nil : @script.gets(0)
      end
    end

    # Consumes the interpreter's normalized front-end effect events. With the character's hook
    # setting on ({Lich::Genie.hooks_enabled?}, off by default) each becomes a `<genieHook>` tag for a
    # hook-aware front end (one that does not implement an op ignores it). Off, the text an effect
    # carries still reaches the player through Lich's own messaging, whatever the front end
    # ({#render}): `#echo >window text` and a `#link`'s text go to that window where Lich's front
    # end has it (Lich::Messaging.stream_window: a stream on an XML front end, else the main window),
    # an input-box text to the main window; every other op does nothing. The engine-owned lists
    # (#trigger, #class, #gag, #sub, #alias) are applied by the router itself ({Lists}).
    class LichHookSink
      # The ops whose payload text (in its payload 'window') is shown without hooks.
      WINDOW_TEXT_OPS = %w[echo link].freeze
      # The `<genieHook>` element for one effect: the JSON payload entity-encoded for its
      # single-quoted attribute (& < > ' "), so a payload holding an apostrophe -- `#echo >Log
      # don't` (52 corpus rows) -- or markup is well-formed XML for the front end's parser.
      # @param op [String]
      # @param payload [Hash]
      # @return [String]
      def self.hook_tag(op, payload)
        %(<genieHook v="1" op="#{xml_escape(op.to_s)}" data='#{xml_escape(JSON.generate(payload))}'/>)
      end

      XML_ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', "'" => '&apos;', '"' => '&quot;' }.freeze

      # @param text [String]
      # @return [String] +text+ with & < > ' " entity-encoded
      def self.xml_escape(text)
        text.gsub(/[&<>'"]/, XML_ESCAPES)
      end

      def emit(op, payload)
        Lich::Genie.hooks_enabled? ? emit_tag(op, payload) : render(op.to_s, payload)
      rescue StandardError
        nil
      end

      private

      # Hooks off: the text of a text-bearing effect, through Lich's messaging; anything else, nothing.
      def render(op, payload)
        if WINDOW_TEXT_OPS.include?(op)
          window_text(payload['window'].to_s, payload['text'].to_s)
        elsif op == 'inputbox'
          GenieScript.engine_respond(payload['text'].to_s)
        end
      end

      # Lich::Messaging.stream_window: the stream of that name where Lich lets the front end show it
      # (familiar, thoughts, combat, ...; Genie's names are capitalized, Lich's streams are not), else
      # the main window -- XML-encoded, and for a Wizard front end converted, by Lich. Engine output:
      # never fed back to matchwait or the #triggers. A failure falls back to a plain echo.
      def window_text(window, text)
        Lich::Genie.engine_output { Lich::Messaging.stream_window(text, window.downcase) }
      rescue StandardError
        GenieScript.engine_respond(text)
      end

      def emit_tag(op, payload)
        return unless defined?($_CLIENT_) && $_CLIENT_&.alive?

        $_CLIENT_.puts(LichHookSink.hook_tag(op, payload))
      rescue StandardError
        nil
      end
    end

    # The glue's reserved-global resolver: {ReservedState} over the process-wide
    # {GameState} capture (Lich::Genie.game_state, fed by Lich::Genie.game_state_feed), with
    # the host values only Lich has -- the automapper's $roomid/$zoneid from Lich's map,
    # the running-script list -- and, for names the capture has not seen yet (it starts
    # at the engine's start -- the first row of an engine-on session, or the first .cmd
    # script -- replaying Lich's last 400 server strings), Lich's own
    # state for the vitals, hands, prepared spell, room name/description/exits, compass
    # and status flags. Plus the plugin namespaces Remix has no core equivalent for:
    # $<Skill>.Ranks ... (EXPTracker -> DRSkill) and $Time.is... (TimeTracker -> moonwatch).
    # $SpellTimer.* comes from the SpellTimer plugin port writing the store.
    class LichGameState < ReservedState
      DIRECTIONS = GameState::COMPASS.values.freeze

      # Before the capture saw them (fallbacks; the captured value wins once it exists).
      LICH_FALLBACKS = {
        'health' => -> { XMLData.health }, 'mana' => -> { XMLData.mana },
        'stamina' => -> { XMLData.stamina }, 'spirit' => -> { XMLData.spirit },
        'concentration' => -> { XMLData.concentration }, 'encumbrance' => -> { XMLData.encumbrance_value },
        'charactername' => -> { XMLData.name }, 'gamename' => -> { XMLData.game },
        'preparedspell' => -> { XMLData.prepared_spell },
        'lefthand' => -> { GameObj.left_hand&.name || 'Empty' }, 'lefthandnoun' => -> { GameObj.left_hand&.noun.to_s },
        'lefthandid' => -> { GameObj.left_hand&.id.to_s }, 'righthand' => -> { GameObj.right_hand&.name || 'Empty' },
        'righthandnoun' => -> { GameObj.right_hand&.noun.to_s }, 'righthandid' => -> { GameObj.right_hand&.id.to_s },
        'roomname' => -> { LichGameState.clean_room_name },
        'roomdesc' => -> { XMLData.room_description.to_s.delete('"') },
        'roomexits' => -> { XMLData.room_exits_string.to_s.delete('"') }
      }.merge(
        DIRECTIONS.to_h { |dir| [dir, -> { Array(XMLData.room_exits).include?(dir) ? '1' : '0' }] },
        Reserved::INDICATOR_CHECKS.to_h { |flag, check| [flag, -> { Object.send(check) ? '1' : '0' }] }
      ).freeze

      # Host-computed names (Remix: the automapper and FormMain set these).
      LICH_HOST = {
        # $roomid is Genie's automapper current-room (zone-local) node id, stamped on Lich
        # rooms as genie_id; "0" when unmapped, Genie's "mapper lost" value that scripts
        # guard with `if $roomid = 0`. Configured targets ($part.room, ...) are Genie node
        # ids resolved through the current zone by #goto (Map.by_genie_ref).
        'roomid'     => -> { Lich::Common::Map.current&.genie_id || '0' },
        'zoneid'     => -> { LichGameState::ZONE.id(Lich::Common::Map.current&.genie_zone) },
        'zonename'   => -> { LichGameState::ZONE.name(Lich::Common::Map.current&.genie_zone) },
        'scriptlist' => -> { LichGameState.script_list },
        'game'       => -> { XMLData.game }
      }.freeze

      # $zoneid: the genie_zone stamped on the current Lich room (the zone of the map
      # Remix's automapper has loaded), sticky while unmapped; the default "0" before any.
      # $zonename: that zone's <zone name> in the Genie map files (ZONE_NAMES); the
      # previous name for a zone with no Genie map (see {ZoneTracker}). Both read
      # Map.current on the reading thread (a script, or the trigger worker for a #trigger
      # that expands $zoneid): Lich's own room lookup, not a parse.
      ZONE = ZoneTracker.new

      # The last value of every host-sourced name a live resolver read: the display
      # port's resolver (cached: true) replays these and calls no host code -- it runs on Lich's
      # parser thread inside a game-state row, where Lich's Map (it loads under a lock whose holder
      # prints through the game state) could deadlock the parser thread. The map values are also
      # read on the trigger worker at each automapper room update ({GenieScript.refresh_map_readings}).
      READINGS = HostReadings.new

      # @param game_state [GameState]
      # @param cached [Boolean] answer the host values and the plugin namespaces from {READINGS}
      #   only (the display port's globals); false: read them live and record them there
      def initialize(game_state: Lich::Genie.game_state, cached: false)
        @cached = cached
        host = LICH_HOST.merge(LICH_FALLBACKS)
        super(game_state: game_state, statics: { 'connected' => '1' },
              host: cached ? READINGS.replaying(host.keys) : READINGS.recording(host),
              host_stamps: ReservedState::HOST_STAMPS)
      end

      # Genie's $roomname is the room title without surrounding brackets. DR's
      # room_title is double-bracketed ("[[Name]]"), so strip all leading/trailing.
      def self.clean_room_name
        XMLData.room_title.to_s.gsub(/\A\[+/, '').gsub(/\]+\z/, '')
      end

      # Genie's $scriptlist: the value SetScriptListVariable stored at the last tick end -- the
      # listed scripts' GetFileNameWithoutExtension(FileName), `|`-joined, or "none"
      # (FormMain.cs:4516-4541 R; {ScriptList#value}). Only genie (.cmd) scripts, like `#script
      # abort all`.
      def self.script_list
        Lich::Genie.script_list.value
      rescue StandardError
        'none'
      end

      def key?(name)
        !self[name].nil?
      end

      # Names resolved live with no game update to stamp: the EXPTracker(skill) and
      # TimeTracker($Time) namespaces (a real Genie plugin rewrote these each tick; Lich
      # synthesizes them) and $scriptlist. Live state wins over a stored copy for these.
      # SAFE when the live source is absent: `[]` returns nil (e.g. moonwatch not running)
      # and global_get then falls through to the store, so a script's self-populated
      # $Time.* (from `observe`) still works.
      # Cached (the display port): a plugin-namespace name is authoritative once a live read
      # recorded a value for it.
      def authoritative?(name)
        return name.to_s == 'scriptlist' || (plugin_var?(name) && !READINGS[name.to_s].nil?) if @cached

        (skills_available? && Reserved.skill_var?(name)) || (time_available? && Reserved.time_var?(name)) ||
          name.to_s == 'scriptlist'
      end

      def [](name)
        value = super
        return value unless value.nil?
        return (READINGS[name.to_s] if plugin_var?(name)) if @cached

        if skills_available? && Reserved.skill_var?(name)
          # $<Skill>.LearningRate/.Ranks/.Percent -> DRSkill (Genie EXPTracker plugin)
          READINGS.record(name.to_s, Reserved.skill_var(name, skills: Lich::DragonRealms::DRSkill).to_s)
        elsif time_available? && Reserved.time_var?(name)
          # $Time.isDay / $Time.is<Moon>Up -> moonwatch (Genie TimeTracker plugin). nil
          # (NOT "0") when moonwatch has no data yet, so global_get falls back to the store.
          READINGS.record(name.to_s, Reserved.time_var(name, visible_moons: moon_visible_names, day: sun_day)&.to_s)
        end
      rescue StandardError
        nil
      end

      private

      # The EXPTracker / TimeTracker plugin namespaces (a name test only, no host read).
      def plugin_var?(name)
        Reserved.skill_var?(name) || Reserved.time_var?(name)
      end

      # DRSkill (the EXPTracker equivalent) exists only in DragonRealms.
      def skills_available?
        XMLData.game.to_s.start_with?('DR') && defined?(Lich::DragonRealms::DRSkill)
      end

      # TimeTracker's day/moon data (moonwatch) is a DragonRealms thing.
      def time_available?
        XMLData.game.to_s.start_with?('DR')
      end

      # Moons currently above the horizon, from moonwatch's UserVars.moons['visible']
      # (the same raw list common-moonmage reads before its 4-min safety filter -- so this
      # is TimeTracker's plain "isUp"). nil = moonwatch has never populated it (its `[]`
      # caller then returns nil and the store wins). An empty [] = ran, no moons up.
      def moon_visible_names
        return nil unless defined?(UserVars) && UserVars.respond_to?(:moons)

        moons = UserVars.moons
        return nil unless moons.is_a?(Hash) && moons['visible']

        Array(moons['visible'])
      rescue StandardError
        nil
      end

      # Daytime flag from moonwatch's UserVars.sun['day']; nil when unpopulated.
      def sun_day
        return nil unless defined?(UserVars) && UserVars.respond_to?(:sun)

        sun = UserVars.sun
        return nil unless sun.is_a?(Hash) && sun.key?('day')

        sun['day']
      rescue StandardError
        nil
      end
    end
  end
end

# Lich load (lich.rbw requires this file once at start-up): the gated game-state tap, so the
# engine starts with the first row of an engine-on session. Lich::Genie.autoinstall is the
# explicit opt-out: the genie spec support turns it off before it loads this file into a process
# with no Lich session (the glue specs drive the taps themselves). A reload (HMR) installs nothing
# new: the feed is kept across a reload of lib/genie.rb and installs once per class.
Lich::Genie::GenieScript.install_at_lich_load! if Lich::Genie.autoinstall
