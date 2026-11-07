# frozen_string_literal: true

require 'json'
require 'tmpdir'
require 'fileutils'
require_relative '../../../../lib/genie'

# Headless flow-parity harness: runs OUR real engine (lib/genie) on a .cmd + trace on a
# deterministic virtual clock and compares its observable event stream with a frozen
# Genie4 Remix v4.2.4 genieflow golden (spec/fixtures/genie/flow/expected-remix/*.jsonl).
#
# This is the our-engine half of the genie-port lab's flow-oracle/diff_driver.rb, which
# now loads THIS file, so the lab differential and the rspec ratchet can never drift
# apart. No dotnet needed: the Genie side is the recorded JSONL.
#
# Modelling assumptions (each one is a statement about the Lich glue,
# lib/genie/genie_script.rb, that the harness stands in for):
#   * IN <text>   -> one server string (text + "\r\n") fed to the production GameState, exactly as
#                    the glue's GameStateFeed tap feeds every raw server string: GameState
#                    ports Remix's ParseGameRow (Game.cs:567-889 R) and records every text it prints
#                    with parse (PrintTextWithParse -> PrintTextToWindow -> TriggerParse, Game.cs:
#                    2808-3069 R) as a GameEvents::TextLine -- per segment (a roomDesc preset on its
#                    own, the text before a mid-row stream change, the bold "< "/"> "/"* " combat
#                    split, a thoughts <stream>), each row of an open stream on arrival, Remix's
#                    entity quirks (Utility.TranslateHTMLChar, Game.cs:756-815 R), the window rules
#                    (Room/Inv/Log never parsed; parsegameonly / showlinks / condensed from the config
#                    dir's settings.cfg) and Utility.Trim (CR/LF only). GameState's listener
#                    (game_state_changed) delivers the row's changes, then its events in row order,
#                    each text to the global #triggers and then to the unpaused listed scripts (the
#                    glue does this on its trigger worker, FormMain.cs:138-151 R; here inline). Lich's
#                    strip_xml lines never reach a genie script (the glue's InputBuffer drops what Lich
#                    pushes from its game parser thread); t52-t55, t171-t176 are hard expectations.
#                    A paused script's input drops the lines (the glue's GenieScript::InputBuffer).
#   * Sends       -> every send (a script's, an action's, a #trigger body's, a released queue
#                    command's, typed INPUT) records $lastcommand (GameState#sent) and then, with
#                    triggeroninput (default on), goes through the production ParseDispatch.input:
#                    the #triggers, then the scripts as a game line, nested-dispatch-capped (the glue's
#                    LichGamePort / GenieScript.input_broadcast; a typed command is posted to its
#                    trigger worker).
#   * PROMPT [rt] -> no game text but the prompt's own: the rows feed GameState, whose Row events -- SetRoundTime
#                    (rt) to every script, then the prompt text to the #triggers and TriggerPrompt
#                    + the text to the unpaused scripts -- go out through the production
#                    GameEvents.deliver after the row's changes, like the glue's
#                    GenieScript.game_state_changed (interpreter-spec.md section 12, "Lich
#                    delivery facts"). The fibers read them at the chunk-closing tick (Lich: at once, so
#                    ours may be up to one 10 ms tick earlier in production; Remix resumes on
#                    that tick too).
#   * ROOM        -> no line (a room desc component prints nothing with parse); its room desc is GameEvents::Move
#                    (TriggerMove) for the unpaused scripts; it only extends the open chunk (no
#                    tick), exactly as in genieflow.
#   * Game state: the production GameState is fed every IN row, and the rows PROMPT
#                    (<roundTime value=gt+rt/>, <prompt time=gt>) and ROOM (<streamWindow
#                    id='main'>, <component id='room desc'>) expand to in genieflow
#                    (Program.cs:253, 272-288), BEFORE the script and #triggers get the row
#                    (the glue's GameStateFeed tap runs ahead of Lich's script fan-out). Scripts
#                    read it through ReservedState with the glue's statics ($connected 1)
#                    but none of LichGameState's Lich fallbacks or host values ($roomid,
#                    $zoneid, the skill/Time namespaces): genieflow has no Lich, and starts
#                    from SetDefaultGlobalVars too. Every send goes through GameState#sent
#                    ($lastcommand; $lastinput for INPUT). No SpellTimer plugin (genieflow
#                    loads none). The @-specials and GameState read genieflow's virtual wall
#                    clock (WALL_EPOCH + elapsed). The last-row-was-prompt flag (no "> " rewrite
#                    and no prompt text after a prompt with nothing printed since; Game.cs:2397 R)
#                    is modelled on both sides: genieflow's Host mirrors FormMain.AddText
#                    (FormMain.cs:5084-5122 R), ours is the production GameState, told about every
#                    echo (echo_main) and every line Lich itself would print ("--- Lich: x active."
#                    / "paused." / "unpaused." / "has exited." -- none after an announced abort --,
#                    the trigger-error diagnostic) the
#                    way the glue's feed_script_output does (t156, t157).
#   * Roundtime is Remix's: known at the packet's prompt (Game.cs:2366-2373 R, GameState) and
#     handed to the interpreters as a RoundTimeEnd on their clock; it gates their RESUMES, never
#     a send. (Lich's XMLData.roundtime_end is set at the packet's first row, xmlparser.rb:
#     1057-1058, but nothing reads it any more: LichGamePort has no waitrt?.)
#   * End of a DR packet: the interpreter resumes only between packets -- at the packet's prompt
#     or after Interpreter::CHUNK_IDLE_SECONDS (10 ms) with no further game item. A FLUSH, or
#     the implicit close before a non-chunk directive, is followed by one tick, i.e. exactly that
#     idle time, so a prompt-less chunk resumes on the same tick as in genieflow.
#   * Pause: a `#script pause`d fiber is not resumed (the interpreter's paused port would
#     park it on its input) and its input drops what arrives, except a RoundTimeEnd; it goes on
#     at the first tick after `#script resume` (Remix runs it synchronously inside the resuming
#     command, so a resumer's own rows right after the resume can interleave differently; the
#     glue wakes the parked thread with GameEvents::RESUMED, asynchronously too).
#   * Launches go through the production ScriptLaunch (exact `<name>.cmd` in the case dir,
#     Remix's "File not found" / "Unable to load file" errors) and ScriptList (abortdupescript from
#     the config dir's settings.cfg, default True; the dupe check walks the listed scripts). The
#     child's first run is resumed at once, synchronously inside the launcher's resume (Command.cs:
#     2536-2539, FormMain.cs:4678-4714 R); the glue's launcher thread waits for it the same way
#     (GenieScript.launch, bounded by FIRST_RUN_WAIT_SECONDS). A #trigger body run inside a
#     script's fiber (ParseDispatch.owner) has that script as launcher, as the glue's host_launch.
#     A #trigger body's off any script and a queued launch (no launcher) is synchronous here too;
#     the glue runs those on its trigger / queue worker, which waits for the first run as well.
#     A `#goto` emits nothing here (the mover is a no-op: genieflow
#     loads no AutoMapper plugin; GotoWalk is spec'd on its own).
#   * Script list: the production ScriptList with the glue's deterministic tick end --
#     a script's run end (FiberInput#next_line = LichInputPort#next_line, and the fiber's end),
#     except the end of a first run nested in its launcher's run (flow t170).
#     A child is listed once its own first run and its launcher's run are over and the launcher
#     is listed (a chain of first runs joins together, in launch order); until then it is
#     frozen (its paused port) and gets no game line, #parse, variable change or event; every
#     walker (#script, the dupe check, recipients, $scriptlist) sees the listed scripts only.
#   * INPUT text  -> user typing, modelled on what genieflow Host.UserInput does: Remix
#                    Command.ParseCommand(sText, bSendToGame: true, bUserInput: true)
#                    (FormMain.cs:4216 R) -- run through the PRODUCTION ParseCommand (a
#                    CommandRouter's {#route}): `;`/`bug `/`sing ` rows whole, the SafeSplit,
#                    the `-` quick send, `.name` launches, plain rows ParseGlobalVars'd and
#                    SendTextToGame'd, and each `#` arm expanding `$globals` where Remix does.
#                    The Lich glue does NOT do this: what a Lich user types goes through Lich's
#                    own client path, not the engine. Aliases are not modelled
#                    (no alias is ever defined in a fixture; the engine owns no AliasList).
#   * CommandQueue -> the production CommandQueue on genieflow's virtual wall clock,
#                    drained at the START of every tick, before the scripts resume (FormMain
#                    TimerBgWorker_Tick, FormMain.cs:8313-8339 R), each released command run by
#                    a trigger runner (RunQueueCommand -> ParseCommand, bSendToGame) whose sends
#                    are not user input. Roundtime is GameState#roundtime? (Remix's
#                    RoundTimeEnd, set at the prompt that carries the roundtime) and $webbed /
#                    $stunned are read through the variables, re-read before each poll.
#   * No send is ever RT-waited (typed INPUT, a #trigger body, a script row or an action body):
#     LichGamePort#send_command puts at once, like Remix (t154).
#   * `#parse` -> ParseDispatch.broadcast, called like GenieScript.parse_broadcast does:
#                    the global #triggers fire synchronously (a failing action is a
#                    `trigger-error` event, never compared: the glue's diagnostic line is a
#                    decided divergence, Remix is silent); then the scripts in launch order:
#                    the issuer's interpreter (the fiber's dispatch owner) handles its own
#                    copy, and a nested trigger-body `#parse`, inline at its position unless
#                    it is paused; every other live, unpaused script gets the text pushed on
#                    its input with its nesting depth (parse_broadcast below). So a script that is busy running rows sees it
#                    at its next wait, where Remix offers it only to the state the script is
#                    in at that moment (TriggerParse, Script.cs:1179-1316 R).
#                    A script not listed yet is not a recipient (ScriptList; flow t165).
#   * Variable changes -> the production VariableDispatch.broadcast, called like
#                    GenieScript.variable_broadcast: GameState's listener (after each fed row, on
#                    the root fiber = Lich's parser thread: the eval #triggers fire there, every
#                    script gets a queued Change BEFORE the row's text lines -- the glue's tap
#                    runs ahead of Lich's script fan-out), every send (after it is emitted, like
#                    Game.SendText; on the sending fiber, so its script gets it inline), the
#                    scripts' / trigger runner's / typed `#var|#tvar|#svar|#math`, and the VAR
#                    directive (genieflow notifies FormMain.TriggerVariableChanged too). A nesting-cap
#                    overflow with no owning script is an echo from `#vars`. Like the glue, only
#                    the scripts that can react to a name get it queued, one entry per row/send
#                    (VariableDispatch). The production GameState also raises the
#                    automapper's "$roomid" after the prompt that ends a ROOM; genieflow loads no
#                    AutoMapper, so a case with an eval action or waiteval naming $roomid would
#                    diverge by design (none in tests/; $roomid itself is not modelled here).
#   * $scriptlist = the value ScriptList stored at its last tick end (LichGameState.script_list):
#                    a run end (not of a nested first run) after a script was listed, finished,
#                    aborted, paused or resumed stores it and raises the "scriptlist" change
#                    (FormMain.cs:8345-8351, 4516-4541 R) -- for the run-ending script queued on
#                    its own input too; a `#script` from the root fiber (a #trigger body, typed)
#                    stores it at once.
#   * Errors are recognised by our engine's `[...]` message shapes (OUR_ENGINE_MESSAGE).
#   * .flags: only genieflow options with a known meaning for our side are accepted
#     (SUPPORTED_FLAGS); anything else raises instead of being silently ignored.
#     `--trigger-delivery` selects Remix's delivery model only (ours has one inline delivery:
#     Remix's timing races are not emulated; its value must still be row|chunk|sync), `--no-config` is our default,
#     `--config-dir` loads that dir's variables.cfg and raises if the dir holds any other
#     file genieflow loads (ConfigLoad.cs:62-72: settings presets highlights names macros
#     aliases substitutes gags triggers classes), since ours would silently ignore it.
#   * Hang guard: a script fiber that keeps running inside ONE resume (the virtual clock
#     is frozen there, so the engine's own SCRIPT_TIMEOUT never trips) is stopped after
#     RESUME_CLOCK_BUDGET clock reads (~ one per executed row) with ResumeBudgetExceeded,
#     reported as an engine-exception, so a broken pause/wait fails the example instead
#     of hanging parallel_rspec.
#
# Directive clock = genieflow Runner.RunTrace chunk model (flow-oracle/src/Program.cs:245-344):
# IN/PROMPT/ROOM open a chunk; PROMPT and FLUSH close it with one tick (FLUSH ticks even with
# no open chunk); TICK/WAIT/EXPECT/VAR/INPUT/RUN/IDLE first close an open chunk (one tick only
# if it was open); then VAR adds no tick, TICK n runs exactly n ticks, INPUT/RUN add one.
# The end of the trace closes an open chunk, then the tail runs (Program.cs:343, 386-390).
#
# Virtual clock: integer milliseconds, 10 ms ticks (FormMain.Designer.cs:1409 R timer).
# A float clock that accumulates +0.010 per tick drifts (450 ticks sum to 4.4999...), which
# made every `pause 0.5` resume one tick late. Our interpreter compares float
# deadlines (now + seconds) against the clock, and tick-aligned deadlines can still differ
# from the tick value by a float residue of ~1e-15 s. Real Lich has a continuous clock, so
# the timed pop returns and the clock is past the deadline; to model that, a timed wait
# with less than NEAR_EXPIRY_S left is treated as expired inside the current tick (the
# script's clock is nudged just past it -- the residue + CLOCK_NUDGE_S -- for the rest of that
# resume, reset every tick).
# At most one nudge per tick: a timed resume takes at least one 10 ms tick, as in Remix (the
# interpreter itself never resumes a timed wait sooner than Interpreter::TICK_SECONDS after
# entry; before both, automapper.cmd's `delay 0.001` loop spun inside one tick).
#
# Timing comparison: aligned send/echo pairs more than TIMING_TOLERANCE_MS apart are a
# TIMING divergence; other streams are compared by text only. 60 ms = six ticks, generous
# enough to absorb tick-phase differences, tight enough that RT/pause/wait errors (>= 500
# ms in every known case) are caught. Pairs are aligned by TEXT only, so a wrong-line match
# inside one chunk can hide (before waitfor matched like Remix, t03 `got orc` was timing-OK although ours
# matched an earlier line of the chunk than Remix). The matched line ($0) is not compared.
# Before the end-of-packet resume the MATCHing tests with a delta showed ours one tick (-10 ms)
# EARLIER (t07, t48, t50: Remix resumes waitfor/matchwait only at the buffer end, Script.cs:1551, 1600,
# 2098-2104 R); now those deltas are 0. A case that resumes on a
# `#script resume` lands one tick late (t153, see "Pause").
module GenieSpecSupport
  module Flow
    TICK_MS = 10
    # genieflow VirtualClock.Epoch (flow-oracle/src/ShimsClock.cs:16, DateTimeKind.Local) and
    # Runner.GameTime. The goldens were recorded on a UTC+13 machine (NZDT): Epoch is the instant
    # 1767222000, wall clock 12:00:00. A FIXED +13:00 offset (never Time.local) keeps both the
    # instant ($unixtime, $spellstarttime) and the wall-clock fields (@time@, @date@) identical
    # whatever TZ the spec process runs in; the engine formats/converts only through the
    # injected clock's Time, so its offset is the one used (tz_independence_spec guards this).
    WALL_UTC_OFFSET = '+13:00'
    WALL_EPOCH = Time.new(2026, 1, 1, 12, 0, 0, WALL_UTC_OFFSET)
    GAME_EPOCH = 1_700_000_000
    TIMING_TOLERANCE_MS = 60
    NEAR_EXPIRY_S = 0.001
    CLOCK_NUDGE_S = 1e-9 # past the float residue (~1e-13 s at 1000 s of virtual time), carried into new deadlines
    # genieflow options a fixture's .flags may carry => number of values each takes.
    SUPPORTED_FLAGS = { '--trigger-delivery' => 1, '--no-config' => 0, '--config-dir' => 1 }.freeze
    # genieflow's accepted --trigger-delivery values, case-insensitive (flow-oracle/src/Program.cs:194-199).
    TRIGGER_DELIVERIES = %w[row chunk sync].freeze
    # The files genieflow --config-dir loads (flow-oracle/src/ConfigLoad.cs:62-72). OurRun
    # models variables.cfg, triggers.cfg, settings.cfg (only the keys the production GameState
    # reads: GameState::Config.from_settings) and the engine-owned lists aliases.cfg,
    # substitutes.cfg, gags.cfg, classes.cfg; a .flags config dir holding any other one (the front
    # end's presets, highlights, names, macros) is rejected.
    GENIEFLOW_CONFIG_FILES = %w[settings.cfg presets.cfg variables.cfg highlights.cfg names.cfg macros.cfg
                                aliases.cfg substitutes.cfg gags.cfg triggers.cfg classes.cfg].freeze
    # The global lists too (build_lists): aliases.cfg, substitutes.cfg, gags.cfg, classes.cfg.
    MODELLED_CONFIG_FILES = %w[variables.cfg triggers.cfg settings.cfg aliases.cfg substitutes.cfg gags.cfg classes.cfg].freeze
    # Clock reads allowed inside ONE fiber resume (~ one per executed row; the largest
    # legitimate fixture resume is far below this). See "Hang guard" above.
    RESUME_CLOCK_BUDGET = 200_000

    # Raised inside a script fiber that exceeds RESUME_CLOCK_BUDGET. Deliberately NOT a
    # StandardError: the engine has `rescue StandardError` arms (interpreter.rb add_match,
    # listed_variable_changed), and one around a clock read would swallow it and keep spinning.
    class ResumeBudgetExceeded < Exception; end # rubocop:disable Lint/InheritException

    # Errors a script fiber turns into an `engine-exception` event (anything else, e.g.
    # Interrupt or SystemExit, propagates). SystemStackError: deep trigger recursion.
    FIBER_ERRORS = [StandardError, SystemStackError, ResumeBudgetExceeded].freeze

    Directive = Struct.new(:kw, :rest, :line)

    # One flow test: <name>.cmd plus optional .trace/.args/.flags/.only (README "Extending").
    Case = Struct.new(:name, :cmd, :trace, :args, :flags, :only, :dir) do
      def label = name + (args.empty? ? '' : " #{args.join(' ')}") + (flags.empty? ? '' : " [#{flags.join(' ')}]")
    end

    module_function

    # Validate a .flags word list against SUPPORTED_FLAGS.
    # @param flags [Array<String>]
    # @return [Hash{String=>String,true}] option => value (true for valueless options)
    # @raise [ArgumentError] on an option our side cannot honour or a missing value
    def parse_flags(flags)
      out = {}
      i = 0
      while i < flags.length
        flag = flags[i]
        arity = SUPPORTED_FLAGS.fetch(flag) { raise ArgumentError, "unsupported .flags option #{flag.inspect} (supported: #{SUPPORTED_FLAGS.keys.join(' ')})" }
        raise ArgumentError, ".flags option #{flag} needs a value" if arity == 1 && (flags[i + 1].nil? || flags[i + 1].start_with?('--'))

        out[flag] = arity == 1 ? flags[i + 1] : true
        i += 1 + arity
      end
      delivery = out['--trigger-delivery']
      raise ArgumentError, "--trigger-delivery must be row|chunk|sync (got #{delivery.inspect})" if delivery && !TRIGGER_DELIVERIES.include?(delivery.downcase)

      out
    end

    # A .flags --config-dir must exist (genieflow raises too, ConfigLoad.cs:54) and hold no
    # config file that genieflow loads but OurRun ignores.
    # @param dir [String] absolute config dir
    # @raise [ArgumentError]
    def check_config_dir(dir)
      raise ArgumentError, "--config-dir #{dir} is not a directory" unless File.directory?(dir)

      ignored = (GENIEFLOW_CONFIG_FILES - MODELLED_CONFIG_FILES).select { |f| File.exist?(File.join(dir, f)) }.sort
      raise ArgumentError, "--config-dir #{dir} holds config not modelled on our side: #{ignored.join(' ')}" unless ignored.empty?
    end

    # @param dir [String] directory holding <name>.cmd (+ siblings)
    # @param tree [String] 'remix' or 'upstream'; tests whose .only names another tree are skipped
    # @return [Array<Case>] sorted by name; `_`-prefixed helpers/includes are skipped
    def discover(dir, tree: 'remix')
      Dir.glob(File.join(dir, '*.cmd')).sort.filter_map do |cmd|
        base = cmd.delete_suffix('.cmd')
        name = File.basename(base)
        next if name.start_with?('_')

        only = File.exist?("#{base}.only") ? File.read("#{base}.only").strip : nil
        next if only && only != tree

        Case.new(name, cmd, File.exist?("#{base}.trace") ? "#{base}.trace" : nil,
                 File.exist?("#{base}.args") ? File.read("#{base}.args").split : [],
                 File.exist?("#{base}.flags") ? File.read("#{base}.flags").split : [],
                 only, dir)
      end
    end

    # The trace is split as bytes (a capture row with invalid UTF-8 -- a
    # truncated multi-byte character, a stray 0xFF -- must not raise here); each directive's text is
    # handed on with its bytes untouched, tagged UTF-8, for the engine's own decoding (GameState.decode
    # turns an invalid sequence into U+FFFD, as genieflow's UTF-8 read does).
    # @param path [String, nil]
    # @return [Array<Directive>] blank lines and `#` comments dropped; keyword upcased
    def parse_trace(path)
      return [] unless path && File.exist?(path)

      File.binread(path).split("\n", -1).each_with_index.filter_map do |raw, i|
        l = raw.delete_suffix("\r")
        next if l.strip.empty? || l.lstrip.start_with?('#')

        # genieflow Runner.RunTrace: kw = l.Split(' ')[0]; rest = l.Substring(kw.Length + 1),
        # so only ONE separator space is consumed and further leading spaces stay in rest.
        kw = l.split(/ /, -1).first.to_s
        rest = l.bytesize > kw.bytesize ? l.byteslice((kw.bytesize + 1)..) : +''
        Directive.new(kw.force_encoding(Encoding::UTF_8).upcase, rest.force_encoding(Encoding::UTF_8), i + 1)
      end
    end

    # Load a genieflow JSONL golden. The recorded scriptdir (from the `setup` event) is
    # replaced by the placeholder `<scriptdir>` in every string value so the golden does
    # not depend on where it was recorded (t43 echoes $scriptdir-derived paths).
    # @return [Array<Hash>]
    def load_golden(path)
      events = File.readlines(path, chomp: true).reject(&:empty?).map { |l| JSON.parse(l) }
      setup = events.find { |e| e['ev'] == 'setup' }
      normalize_paths(events, setup && setup['scriptdir'])
    end

    # Replace +dir+ by `<scriptdir>` inside every String value of every event.
    def normalize_paths(events, dir)
      return events if dir.nil? || dir.empty?

      events.map { |e| e.transform_values { |v| v.is_a?(String) ? v.gsub(dir, '<scriptdir>') : v } }
    end

    # Interpreter input port backed by a Fiber: an empty buffer parks the script's fiber
    # until the next tick or fed line.
    class FiberInput
      attr_reader :buffer
      attr_accessor :skew

      # @param on_read [#call, nil] called first on every read: the script's run is over (the
      #   glue's LichInputPort#next_line -> GenieScript#genie_run_ended)
      def initialize(on_read: nil)
        @buffer = []
        @skew = 0.0
        @on_read = on_read
      end

      def next_line(timeout: nil)
        @on_read&.call
        return @buffer.shift unless @buffer.empty?
        # A spent timeout only looks (Lich's LimitedArray#wait_shift(0) returns at once).
        return nil if timeout && !timeout.positive?

        if timeout && timeout < NEAR_EXPIRY_S && @skew.zero?
          # Float residue of a tick-aligned deadline: the real timed pop would already
          # have returned, so expire it now, past the deadline in one step (see "Virtual
          # clock" above). Once per tick (OurRun#tick resets the skew): a timed resume
          # takes at least one tick, so a sub-tick wait re-entered inside the same resume
          # parks instead of spinning.
          @skew = timeout + CLOCK_NUDGE_S
          return nil
        end
        Fiber.yield(:park)
        @buffer.shift # nil => "tick" (interpreter re-checks its deadline)
      end
    end

    # One launched script: a Hash (the run's bookkeeping) that is also a ScriptList handle.
    class Entry < Hash
      # @return [String] Script.FileName (ScriptLaunch.file_name of the launch)
      def genie_file_name = self[:file_name]
    end

    # Runs one trace through our engine. Mirrors genieflow's Runner.RunTrace.
    class OurRun
      attr_reader :events
      attr_accessor :quiet_vars

      def initialize(scriptdir, config_dir: nil)
        @scriptdir = scriptdir
        @now_ms = 0
        @events = []
        @scripts = []
        # The globals genieflow loads from a config dir (VariableList.Load), read by the PRODUCTION
        # loader: GlobalStore.new(file:) as Lich::Genie.global_store builds it (reserved names
        # skipped, every row persistent). The store keeps the file as
        # its save target the way VariableList does (`#var save` writes the file it loaded,
        # flow-oracle README "Write sandbox"), so callers hand OurRun a private copy of the config
        # dir (Flow.run_ours, diff_driver's with_config_copy). No config dir: no backing file.
        @store = Lich::Genie::GlobalStore.new(file: config_dir && File.join(config_dir, 'variables.cfg'))
        run = self
        @store.define_singleton_method(:set) do |name, value, persist: true, server: false|
          super(name, value, persist: persist, server: server).tap { run.emit('var', name: "$#{name}", value: value.to_s, src: 'cmd') unless run.quiet_vars }
        end
        # Reserved game state: the production GameState capture fed the same rows genieflow
        # feeds Game.ParseGameRow (IN, and the rows PROMPT/ROOM expand to), read through
        # ReservedState like the glue's LichGameState minus its Lich fallbacks (genieflow
        # starts from SetDefaultGlobalVars too). No SpellTimer plugin: genieflow loads none.
        # Its config comes from the config dir's settings.cfg the way production builds it
        # (Lich::Genie.build_game_state: SettingsFile.read + Config.from_settings).
        settings = config_dir ? Lich::Genie::SettingsFile.read(File.join(config_dir, 'settings.cfg')) : []
        # The production script lists (m_oScriptList + m_oScriptListNew); abortdupescript and
        # ignorescriptwarnings come from the live config, as the glue reads them
        # (Lich::Genie.abort_dupe_script? / ignore_script_warnings?).
        @list = Lich::Genie::ScriptList.new
        @lists = build_lists(scriptdir, config_dir)
        @game_state = Lich::Genie::GameState.new(config: Lich::Genie::GameState::Config.from_settings(settings), clock: -> { wall_time },
                                                 listener: ->(names) { game_state_changed(names) },
                                                 display: ->(text, target) { @lists.filters.displayed(text, target) },
                                                 globals: @store)
        # $scriptlist like the glue's LichGameState.script_list: the value the list stored at its
        # last tick end (SetScriptListVariable, FormMain.cs:4516-4541 R; ScriptList#value).
        @reserved = Lich::Genie::ReservedState.new(game_state: @game_state, statics: { 'connected' => '1' },
                                                   host: { 'scriptlist' => -> { script_list } })
        @triggers = @lists.triggers
        # The session's CommandQueue on the virtual wall clock (see the CommandQueue assumption).
        @queue = Lich::Genie::CommandQueue.new(clock: -> { wall_time })
        @send_cursor = 0
        @chunk_open = false
        @runner = build_trigger_runner
        @queue_runner = build_trigger_runner(game_port('')) # RunQueueCommand: origin "", not user input
        @input_router = build_input_router
      end

      def emit(ev, **kv) = @events << { 't' => @now_ms, 'ev' => ev }.merge(kv.transform_keys(&:to_s))

      def now_s = @now_ms / 1000.0

      # genieflow's DateTime.Now: VirtualClock.Epoch (2026-01-01 12:00 local) + elapsed.
      def wall_time = WALL_EPOCH + Rational(@now_ms, 1000)

      # genieflow Runner.GameTime: the <prompt time> / <roundTime value> base (Program.cs:253).
      def game_time = GAME_EPOCH + (@now_ms / 1000)

      def live = @scripts.count { |s| s[:fiber].alive? && !s[:dead] }

      def script_list = @list.value

      # The listed scripts still running (the glue's GenieScript.listed_scripts), in list order.
      def listed = @list.listed.select { |s| s[:fiber]&.alive? && !s[:dead] }

      def game_port(label, user: false)
        run = self
        Object.new.tap do |o|
          o.define_singleton_method(:send_command) { |text| run.send_game(text, label, user: user) }
        end
      end

      # LichGamePort#send_command: put, at once (no roundtime wait: Remix gates the
      # script's resumes, never its sends) -- except a mycommandchar text (GameState#my_command?,
      # Game.cs:545 R): echoed, never put, so no `send` (genieflow emits `send` at the socket send).
      def send_game(text, label, user: false)
        emit('send', text: text.to_s, origin: label) unless @game_state.my_command?(text.to_s)
        # LichGamePort#send_command / the glue's upstream hook: Game.SendText's
        # $lastcommand (and $lastinput for typed input, origin ''), raised AFTER the socket
        # send (Game.cs:545-551 R; LichGamePort puts first), so a capped $lastcommand chain
        # (t51) still shows every send it made.
        @game_state.sent(text.to_s, user_input: user)
        input_broadcast(text.to_s)
      end

      # Trigger-on-input, like the glue's GenieScript.input_broadcast: with `triggeroninput`
      # (settings.cfg; default on) the sent text goes through the production ParseDispatch.input --
      # the #triggers, then the scripts as a game line (FormMain.cs:4391-4422 R).
      def input_broadcast(text)
        return unless @game_state.config.trigger_on_input

        Lich::Genie::ParseDispatch.input(text, triggers: @triggers, runner: @runner, recipients: recipients,
                                               on_error: trigger_error, on_overflow: ->(message) { echo_main("[#{message}]", '#input') })
      end

      def hooks
        run = self
        Object.new.tap do |o|
          o.define_singleton_method(:emit) do |op, payload|
            run.emit('hook', op: op, payload: payload)
            # SendTextInputBox (FormMain.cs:4378-4384 R): genieflow's `inputbox` event
            run.emit('inputbox', text: payload['text'].to_s) if op == 'inputbox'
          end
        end
      end

      # The global lists as genieflow's startup loads them (ConfigLoad.cs: aliases.cfg,
      # substitutes.cfg, gags.cfg, triggers.cfg, classes.cfg from --config-dir; FormMain.cs:2327-2343
      # R) through the production loaders; `default` = True even without a classes.cfg (Classes.Load,
      # genieflow Program.cs). The `#trigger|#gag|... load` arms read Config.ConfigDir =
      # <scriptdir>/Config (genieflow roots LocalDirectory.Path at the script dir, Program.cs:187),
      # NOT --config-dir; the save arms write nothing (the fixture tree is read-only).
      def build_lists(scriptdir, config_dir)
        from = ->(name) { config_dir && File.exist?(File.join(config_dir, name)) ? File.join(config_dir, name) : nil }
        triggers = Lich::Genie::Triggers.new
        triggers.load(from.call('triggers.cfg')) if from.call('triggers.cfg')
        classes = Lich::Genie::ClassList.new.tap { |list| list.load(from.call('classes.cfg')) }
        filters = Lich::Genie::StreamFilters.new
        filters.load_gags(from.call('gags.cfg')) if from.call('gags.cfg')
        filters.load_subs(from.call('substitutes.cfg')) if from.call('substitutes.cfg')
        filters.globals = ->(text) { Lich::Genie::Substitution.new(variables: variables).expand_globals(text) }
        aliases = Lich::Genie::AliasList.new
        aliases.load(from.call('aliases.cfg')) if from.call('aliases.cfg')
        Lich::Genie::Lists.new(triggers: triggers, classes: classes, filters: filters, aliases: aliases,
                               config_dir: File.join(scriptdir, 'Config'), writable: false)
      end

      # The glue's LichScriptControl: walks the LISTED scripts (ScriptList), exact names, every
      # match; a status change is stored at the next tick end (ScriptList#tick_end_outside_script:
      # at once from the root fiber, else when the acting script's run ends).
      def script_control
        run = self
        Object.new.tap do |o|
          o.define_singleton_method(:names) { run.listed.map { |s| s[:name] } }
          o.define_singleton_method(:abort) do |n|
            run.listed.each { |s| run.abort_entry(s) if s[:name] == n.to_s }
            run.list_tick_end
          end
          o.define_singleton_method(:pause) { |n| run.set_paused(n) { |_| true } }
          o.define_singleton_method(:resume) { |n| run.set_paused(n) { |_| false } }
          o.define_singleton_method(:pauseorresume) { |n| run.set_paused(n) { |paused| !paused } }
          # Command_ScriptDebugLevel (FormMain.cs:6083 R), like the glue's LichScriptControl#debug.
          o.define_singleton_method(:debug) do |level, n|
            run.listed.each { |s| s[:interp].debug_level = level if s[:name] == n.to_s && s[:interp] }
          end
          o.define_singleton_method(:reload) do |n|
            run.listed.each do |s|
              next unless s[:name] == n.to_s

              run.abort_entry(s)
              run.start_request(Lich::Genie::ScriptLaunch::Request.new(file_name: s[:file_name], args: s[:args]), nil)
            end
            run.list_tick_end
          end
        end
      end

      # GenieScript#genie_abort: the interpreter stops (Interpreter#abort_script prints Remix's
      # "[Script aborted! ...]" line through the print port; a self-abort ends its fiber after the
      # row), the script leaves the list. Lich prints no stop notice for it (silence_lich_notice),
      # except for a script that had already finished (then "has exited", like a normal end).
      def abort_entry(entry)
        return if entry[:dead]

        entry[:dead] = true
        entry[:interp]&.abort_script
        @list.finished(entry)
        lich_line("--- Lich: #{entry[:name]} has exited.") if entry[:interp] && !entry[:interp].abort_announced?
        emit('script-finish', script: entry[:name], aborted: true)
      end

      # ScriptList#tick_end_outside_script + the "scriptlist" change, like the glue's control.
      def list_tick_end
        var_broadcast('scriptlist') if @list.tick_end_outside_script
      end

      # `#script pause|resume|pauseorresume` on the listed matches: each is a status change
      # (Script_EventStatusChanged, FormMain.cs:3481-3483 R; Script.cs:1075, 1105 R).
      def set_paused(name)
        listed.each do |s|
          next unless s[:name] == name.to_s

          paused = yield(s[:paused]) ? true : false
          # Lich's pause/unpause line (Remix: "[Script paused|resumed: ...]", Script.cs:1062, 1087 R)
          lich_line("--- Lich: #{s[:name]} #{paused ? 'paused' : 'unpaused'}.") unless paused == (s[:paused] ? true : false)
          s[:paused] = paused
          @list.changed!
        end
        list_tick_end
      end

      # FormMain.TriggerVariableChanged through the production VariableDispatch.broadcast, as
      # the glue's GenieScript.variable_broadcast calls it: eval #triggers, then every live
      # script -- this fiber's interpreter (the dispatch owner) inline, the others queued with
      # their nesting depth (only the scripts that can use a change; one entry per call). A
      # nested-dispatch-cap overflow on the root fiber (no owner) is echoed as `#vars`.
      def var_broadcast(names, game: false, queue_owner: false)
        Lich::Genie::VariableDispatch.broadcast(
          names, triggers: @triggers, runner: @runner, recipients: recipients, on_error: trigger_error,
                on_overflow: ->(message) { echo_main("[#{message}]", '#vars') }, game: game, queue_owner: queue_owner
        )
        @game_state.plugin_variable_changed(names) unless game # the glue's automapper hook (`#var roomname|prompt`)
      end

      # The listed live scripts as dispatch recipients, in list order.
      def recipients
        listed.map do |s|
          Lich::Genie::ParseDispatch::Recipient.new(interpreter: s[:interp], buffer: s[:input].buffer, paused: -> { s[:paused] })
        end
      end

      # GameState's listener, like the glue's GenieScript.game_state_changed: a fed row's changes
      # (a GameState::Row) go out as a game row's, then its script-timing events (GameEvents:
      # SetRoundTime, TriggerPrompt + the prompt text, TriggerMove) on the interpreters' clock;
      # a send's changes as plain changes.
      def game_state_changed(names)
        return var_broadcast(names) unless names.is_a?(Lich::Genie::GameState::Row)

        var_broadcast(names, game: true)
        Lich::Genie::GameEvents.deliver(names.events, recipients: recipients, clock: -> { now_s }, triggers: @triggers,
                                                      runner: @runner, on_error: trigger_error)
      end

      def variables = Lich::Genie::Variables.new(game_state: @reserved, global_store: @store)

      def globals_adapter(vars)
        Object.new.tap { |g| g.define_singleton_method(:key?) { |n| vars.global_key?(n) } }
      end

      def build_trigger_runner(game = game_port('Trigger'))
        vars = variables
        Lich::Genie::TriggerRunner.new(
          vars: vars, eval: Lich::Genie::Eval.new(globals: globals_adapter(vars)), game: game, queue: @queue,
          # GenieScript.host_launch: the dispatch owner's script is the launcher (a body run inside
          # a script's row), else none
          launch: ->(n, a) { spawn(n, a, launcher: owner_entry) }, hooks: hooks,
          echo: ->(t) { echo_main(t, '#trigger') },
          script_control: script_control, mover: ->(_room) {},
          parse: ->(t) { parse_broadcast(t) }, var_changed: ->(n) { var_broadcast(n) }, lists: @lists
        )
      end

      # GenieScript.dispatch_owner_script: the live entry whose interpreter owns this fiber's
      # dispatch (Thread#[] is fiber-local, so ParseDispatch.owner is the running script's).
      def owner_entry
        owner = Lich::Genie::ParseDispatch.owner
        owner && @scripts.find { |s| s[:interp].equal?(owner) && !s[:dead] }
      end

      # The `#parse` host port: the production ParseDispatch.broadcast, exactly as the glue
      # (GenieScript.parse_broadcast) calls it -- the global #triggers, then every live,
      # unpaused script except this fiber's dispatch owner gets the text pushed onto its
      # input, so a script that is not in a wait sees it at its next wait. The owner
      # gets it inline at its position. A failing trigger action is a `trigger-error`
      # diagnostic and the remaining triggers still fire.
      def parse_broadcast(text)
        Lich::Genie::ParseDispatch.broadcast(
          text, triggers: @triggers, runner: @runner, recipients: recipients,
                on_error: trigger_error
        )
      end

      # A failing #trigger action: the glue prints a `--- Lich: genie trigger error:`
      # diagnostic where Remix is silent (a decided divergence). Recorded as a
      # `trigger-error` event, which no compared stream includes.
      def trigger_error
        lambda do |e|
          emit('trigger-error', message: e.message)
          lich_line("--- Lich: genie trigger error: #{e}") # the glue's respond line
        end
      end

      # The engine's echo port, like the glue's respond_in_chain: the line is printed to the main
      # window, so it clears GameState#last_row_was_prompt (the glue reports every Lich-echoed line,
      # GenieScript.feed_script_output; Remix: AddText, FormMain.cs:5100-5122, 5611-5676 R).
      def echo_main(text, script)
        emit('echo', text: text.to_s, script: script)
        lich_line(text.to_s)
      end

      # A Script.PrintError / PrintText / PrintDebug line (the interpreter's print port): genieflow's
      # `error` / `print` / `debug` event, and main-window text like any script line (Remix's
      # Script_EventPrintText / EventPrintError -> AddText main).
      def print_main(text, kind, script)
        emit({ error: 'error', text: 'print', debug: 'debug' }.fetch(kind), text: text.to_s, script: script)
        lich_line(text.to_s)
      end

      # A line Lich itself echoes (respond) -- not a compared event, but main-window text for
      # GameState#last_row_was_prompt (GenieScript.feed_script_output).
      def lich_line(text) = @game_state.printed(text)

      # User typing: the production ParseCommand (see the INPUT assumption).
      def build_input_router
        vars = variables
        user = game_port('', user: true)
        Lich::Genie::CommandRouter.new(
          vars: vars, eval: Lich::Genie::Eval.new(globals: globals_adapter(vars)),
          echo: ->(t) { echo_main(t, '#input') },
          send: ->(t) { user.send_command(t) }, hooks: hooks,
          mover: ->(_room) {}, script_control: script_control,
          parse: ->(t) { parse_broadcast(t) }, var_changed: ->(n) { var_broadcast(n) },
          launch: ->(n, a) { spawn(n, a) }, queue: @queue, lists: @lists
        )
      end

      # The include loader, like the glue's GenieScript#load_include: exactly the named file under
      # the script dir (ScriptLaunch.locate; AppendFile, Script.cs:3683-3800 R), nil if missing.
      def loader
        lambda do |name|
          path = Lich::Genie::ScriptLaunch.locate(@scriptdir, name)
          path ? File.binread(path) : nil
        end
      end

      # A `.name args` launch, like the glue's GenieScript.launch: ParseArgs + the exact file
      # (ScriptLaunch), the first-run nesting cap, the dupe check (abortdupescript), the start;
      # +launcher+ is the launching script's entry (its own rows, or a #trigger body run in its
      # row), nil for a #trigger body off any script, a queued or typed command. The child's first run is resumed at once, inside the launcher's
      # resume -- the glue's launcher waits for it -- and it joins the list per ScriptList.
      def spawn(name, args = '', launcher: nil)
        begin
          request = Lich::Genie::ScriptLaunch.request(name, args)
        rescue Lich::Genie::Error => e
          emit('host-exception', where: 'RunScript', message: e.message) # FormMain.cs:4716-4720 R
          return
        end
        start_request(request, launcher)
        list_tick_end
      end

      # GenieScript.start_request.
      def start_request(request, launcher)
        if @list.launch_depth(launcher) > Lich::Genie::ScriptList::LIMIT
          return echo_main("[Script error: maximum nested dispatch depth (#{Lich::Genie::ScriptList::LIMIT}) exceeded on: .#{request.file_name}]", '')
        end

        @list.duplicates(request.file_name).each { |dup| abort_entry(dup) } if @game_state.config.abort_dupe_script
        name = request.script_name
        begin
          src = File.read(Lich::Genie::ScriptLaunch.resolve(@scriptdir, request.file_name))
        rescue Lich::Genie::ScriptLaunch::NotLoadable => e
          emit('script-start', script: name, args: request.args.join(' '))
          print_main("[Script error: #{e.message}]", :error, name) # the glue's respond_in_chain (PrintError)
          emit('script-finish', script: name, loadfailed: true)
          return
        end
        start_entry(src, request, launcher)
      end

      def start_entry(src, request, launcher)
        name = request.script_name
        vars = variables
        vars.local_set('scriptname', name)
        run = self
        entry = Entry.new
        entry.merge!(name: name, file_name: request.file_name, args: request.args, clock_reads: 0)
        input = FiberInput.new(on_read: -> { run.run_ended(entry) })
        entry[:input] = input
        emit('script-start', script: name, args: request.args.join(' '))
        begin
          interp = build_interpreter(src, request, vars, entry, input)
        rescue Lich::Genie::Lexer::LoadFailed
          emit('script-finish', script: name, loadfailed: true) # its error lines went out through print
          return
        end
        entry[:interp] = interp
        lich_line("--- Lich: #{name} active.") # Lich's start line (Remix: "[Script loaded: ...]")
        entry[:fiber] = Fiber.new do
          interp.run
          :done
        rescue *FIBER_ERRORS => e
          emit('engine-exception', script: name, message: "#{e.class}: #{e.message} @ #{e.backtrace&.first}")
          :done
        ensure
          script_finished(entry)
        end
        @scripts << entry
        @list.launched(entry, launcher: launcher)
        resume(entry) # the first run, synchronously (ClassCommand_RunScript; the glue's launcher waits)
      end

      # Engine.build like the glue's run_genie_interpreter (ignorescriptwarnings from the live
      # config, the launch's file name, the print port).
      def build_interpreter(src, request, vars, entry, input)
        name = request.script_name
        run = self
        Lich::Genie::Engine.build(
          src, name: name, variables: vars, args: request.args, file_name: request.file_name,
               ignore_warnings: @game_state.config.ignore_script_warnings,
               include_loader: loader, game: game_port(name), input: input,
               echo: ->(t) { run.echo_main(t, name) },
               print: ->(t, kind) { run.print_main(t, kind, name) },
               hooks: hooks, launch: ->(n, a) { spawn(n, a, launcher: entry) }, mover: ->(_r) {},
               script_control: script_control, clock: -> { run.clock_read(entry) },
               wall_clock: -> { run.wall_time },
               broadcast: ->(t) { run.parse_broadcast(t) },
               var_broadcast: ->(n) { run.var_broadcast(n) }, queue: @queue, lists: @lists,
               # the glue's GenieScript#paused? || ScriptList#frozen?
               paused: -> { entry[:paused] || run.frozen?(entry) },
               # HandleGenieException("SendText", ...) -> genieflow's host-exception event
               host_error: ->(section, message) { run.emit('host-exception', where: "Script_#{section}", message: message) }
        )
      end

      # GenieScript#genie_run_ended: the script waits, so its run is over (ScriptList#run_ended).
      def run_ended(entry)
        var_broadcast('scriptlist', queue_owner: true) if @list.run_ended(entry)
      end

      def frozen?(entry) = @list.frozen?(entry)

      # run_genie's ensure: the script leaves the list, then the tick end.
      def script_finished(entry)
        @list.finished(entry)
        var_broadcast('scriptlist') if @list.tick_end
        # Lich's exit line (Remix: "[Script finished ...]"); none after a script-error abort (run_genie's quiet)
        lich_line("--- Lich: #{entry[:name]} has exited.") unless entry[:dead] || entry[:interp]&.abort_announced?
        emit('script-finish', script: entry[:name]) unless entry[:dead]
      end

      def resume(entry)
        return unless entry[:fiber].alive? && !entry[:dead] && !entry[:paused]

        entry[:clock_reads] = 0
        entry[:fiber].resume
      end

      # The script's clock port: virtual time plus its near-expiry skew, metered per resume.
      # @raise [ResumeBudgetExceeded] once one resume reads the clock RESUME_CLOCK_BUDGET times
      def clock_read(entry)
        entry[:clock_reads] += 1
        if entry[:clock_reads] > RESUME_CLOCK_BUDGET
          raise ResumeBudgetExceeded, "#{entry[:name]}: #{RESUME_CLOCK_BUDGET} clock reads in one resume at #{@now_ms} ms (runaway row loop?)"
        end

        now_s + entry[:input].skew
      end

      def resume_all = @scripts.dup.each { |s| resume(s) }

      # FormMain's Poll arguments: HasRoundTime, $webbed == "1", $stunned == "1".
      def queue_state
        vars = variables
        Lich::Genie::CommandQueue::State.new(in_rt: @game_state.roundtime?(wall_time), webbed: vars.global_get('webbed') == '1',
                                             stunned: vars.global_get('stunned') == '1')
      end

      # One timer tick (TimerBgWorker_Tick, FormMain.cs:8313-8351 R): the CommandQueue drain, then
      # the scripts. No AddScripts / SetScriptListVariable here: the glue has no tick, the list's
      # tick ends are the scripts' run ends (ScriptList).
      def tick
        @now_ms += TICK_MS
        @scripts.each { |s| s[:input].skew = 0.0 }
        event = @queue.poll_event # Events.Poll, one per tick, before the CommandQueue (FormMain.cs:8321-8322 R)
        @queue_runner.run_command(event) unless event.empty?
        @queue.drain(-> { queue_state }) { |action| @queue_runner.run_command(action) }
        resume_all
      end

      # One IN row = one server string, fed to the production GameState like the glue's
      # GameStateFeed tap: its listener (game_state_changed) delivers the row's changes, then its
      # events in row order -- each printed text (GameEvents::TextLine) to the #triggers and then
      # to the unpaused listed scripts (each row as Remix parses it; the glue's trigger worker does the same).
      def feed(text)
        @game_state.feed("#{text}\r\n")
        resume_all
      end

      # Trace execution (mirrors genieflow Runner.RunTrace).
      def run(name, args, trace, tail_ms: 2000)
        @root = Fiber.current
        emit('input', text: ".#{name}#{args.empty? ? '' : " #{args.join(' ')}"}")
        spawn(name.downcase, args.join(' ')) # typed `.name`: ParseArgs token 0, lower-cased
        tick
        trace.each { |d| directive(d) }
        close_chunk
        target = @now_ms + tail_ms
        tick while live.positive? && @now_ms < target
        emit('end', live: live)
        self
      end

      # Trace durations (WAIT, IDLE, EXPECT limit) are milliseconds; fractions round.
      def ms(text) = text.to_f.round

      # genieflow CloseChunk: one tick only if a chunk is open.
      def close_chunk
        return unless @chunk_open

        @chunk_open = false
        tick
      end

      def directive(d)
        case d.kw
        when 'IN', 'ROOM', 'PROMPT', 'FLUSH' then chunk_directive(d)
        else
          close_chunk
          clock_directive(d)
        end
      end

      def chunk_directive(d)
        @chunk_open = true
        case d.kw
        when 'IN' then feed(d.rest)
        when 'PROMPT'
          rt = d.rest.strip.to_i
          @game_state.feed("<roundTime value='#{game_time + rt}'/>\r\n") if rt.positive?
          @game_state.feed("<prompt time=\"#{game_time}\">&gt;</prompt>\r\n")
          close_chunk
        when 'ROOM'
          title = d.rest.strip.empty? ? 'Somewhere' : d.rest.strip
          @game_state.feed("<streamWindow id='main' title='Story' subtitle=\" - [#{title}]\" location='center' target='drop'/>\r\n")
          @game_state.feed("<component id='room desc'>You are in #{title}.</component>\r\n")
        when 'FLUSH' then close_chunk
        end
      end

      def clock_directive(d)
        case d.kw
        when 'TICK' then (d.rest.strip.empty? ? 1 : Integer(d.rest.strip, 10)).times { tick }
        when 'WAIT'
          target = @now_ms + ms(d.rest.strip)
          tick while @now_ms < target
        when 'EXPECT' then expect(d)
        when 'VAR'
          name, val = d.rest.split(' ', 2)
          @quiet_vars = true
          @store.set(name, val.to_s)
          @quiet_vars = false
          emit('var', name: "$#{name}", value: val.to_s, src: 'trace')
          var_broadcast("$#{name}") # genieflow VAR notifies FormMain.TriggerVariableChanged
        when 'INPUT'
          emit('input', text: d.rest)
          user_input(d.rest)
          tick
        when 'RUN'
          spawn(*d.rest.split(' ', 2))
          tick
        when 'IDLE'
          target = @now_ms + (d.rest.strip.empty? ? 30_000 : ms(d.rest.strip))
          tick while live.positive? && @now_ms < target
        else raise ArgumentError, "trace line #{d.line}: unknown directive #{d.kw}"
        end
      end

      # Remix Command.ParseCommand(text, bSendToGame: true, bUserInput: true) (FormMain.cs:4216 R)
      # through the production ParseCommand.
      def user_input(text)
        @input_router.route(text)
      end

      def expect(d)
        spec = d.rest.strip
        limit_ms = 30_000
        re = nil
        if spec.start_with?('/')
          last = spec.rindex('/')
          re = Regexp.new(spec[1...last])
          tail = spec[(last + 1)..].strip
          limit_ms = ms(tail) unless tail.empty?
        end
        deadline = @now_ms + limit_ms
        loop do
          sends = @events.select { |e| e['ev'] == 'send' }
          hit = (@send_cursor...sends.length).find { |i| re ? re.match?(sends[i]['text']) : sends[i]['text'] == spec }
          if hit
            @send_cursor = hit + 1
            emit('expect-ok', want: spec, got: sends[hit]['text'])
            return
          end
          if @now_ms >= deadline || live.zero?
            emit('expect-timeout', want: spec, line: d.line)
            return
          end
          tick
        end
      end
    end

    # Genie "print" lines that are engine diagnostics a script user sees as errors.
    GENIE_ERRORISH_PRINT = /\A\[Script (error|timeout)|\ATrace follows/
    # Our engine reports errors through the same echo port; recognise its message shapes.
    # Text-based and one-sided: a script that itself echoes `[Invalid ...` shows up as an
    # error on our side only (false divergence). Tagging diagnostics at the source is better.
    # The script errors, timeouts and the trace come through the print port as genieflow's
    # own `error` / `print` events; what is left on the echo port: the nesting-cap / launch-cap
    # lines ("[Script error: ..."), the evaluator-fault lines, the unsupported-JS notices.
    OUR_ENGINE_MESSAGE = /\A\[(Script error|Genie|Invalid|Length cannot)|infinite loop/

    # The echo stream's comparison key: the text, prefixed by its window when it has one
    # (genieflow's cmdecho `window`; ours: the router's `echo` hook payload -- a windowless echo
    # goes to the echo port). Before, an `#echo >Log x` and an
    # `#echo x` compared equal.
    def echo_key(window, text)
      window = window.to_s
      window.empty? ? text.to_s : "[>#{window}] #{text}"
    end

    # Project an event list onto the six compared streams: [[t_ms, text], ...] each.
    def streams(events, side)
      sends = events.select { |e| e['ev'] == 'send' }.map { |e| [e['t'], e['text'].to_s] }
      echoes = []
      errors = []
      events.each do |e|
        case e['ev']
        when 'echo', 'cmdecho'
          txt = e['text'].to_s
          (side == :ours && txt =~ OUR_ENGINE_MESSAGE ? errors : echoes) << [e['t'], echo_key(e['window'], txt)]
        when 'hook' then echoes << [e['t'], echo_key(e['payload']['window'], e['payload']['text'])] if e['op'] == 'echo' && e['payload'].is_a?(Hash)
        when 'error' then errors << [e['t'], e['text'].to_s]
        when 'print' then errors << [e['t'], e['text'].to_s] if e['text'].to_s =~ GENIE_ERRORISH_PRINT
        when 'engine-exception', 'host-exception', 'genie-exception' then errors << [e['t'], "#{e['ev']}: #{e['message']}"]
        when 'genie-crash' then errors << [e['t'], "genie-crash: #{e['where']}"] # Remix stack overflow (process death)
        end
      end
      vars = events.select { |e| e['ev'] == 'var' && e['src'] != 'trace' && e['src'] != 'game' }
                   .map { |e| [e['t'], "#{e['name'].to_s.sub(/\A\$/, '')}=#{e['value']}"] }
      expects = events.select { |e| e['ev'] == 'expect-timeout' }.map { |e| [e['t'], e['want'].to_s] }
      inputbox = events.select { |e| e['ev'] == 'inputbox' }.map { |e| [e['t'], e['text'].to_s] }
      { 'send' => sends, 'echo' => echoes, 'error' => errors, 'globalvar' => vars,
        'expect-timeout' => expects, 'inputbox' => inputbox }
    end

    # LCS over texts; returns [pairs (aligned), only_a, only_b].
    def align(a, b)
      n = a.length
      m = b.length
      dp = Array.new(n + 1) { Array.new(m + 1, 0) }
      (n - 1).downto(0) { |i| (m - 1).downto(0) { |j| dp[i][j] = a[i][1] == b[j][1] ? dp[i + 1][j + 1] + 1 : [dp[i + 1][j], dp[i][j + 1]].max } }
      i = j = 0
      pairs = []
      oa = []
      ob = []
      while i < n && j < m
        if a[i][1] == b[j][1]
          pairs << [a[i], b[j]]
          i += 1
          j += 1
        elsif dp[i + 1][j] >= dp[i][j + 1]
          oa << a[i]
          i += 1
        else
          ob << b[j]
          j += 1
        end
      end
      oa.concat(a[i..]) if i < n
      ob.concat(b[j..]) if j < m
      [pairs, oa, ob]
    end

    def compare(genie_events, our_events)
      g = streams(genie_events, :genie)
      o = streams(our_events, :ours)
      g.keys.to_h do |k|
        pairs, only_g, only_o = align(g[k], o[k])
        timing = %w[send echo].include?(k) ? pairs.select { |(ga, ob)| (ga[0] - ob[0]).abs > TIMING_TOLERANCE_MS } : []
        [k, { only_genie: only_g, only_ours: only_o, timing: timing }]
      end
    end

    def divergent?(report)
      report.values.any? { |r| !r[:only_genie].empty? || !r[:only_ours].empty? || !r[:timing].empty? }
    end

    def format_report(name, report)
      out = ["### #{name}: #{divergent?(report) ? 'DIVERGENT' : 'MATCH'}"]
      report.each do |k, r|
        next if r[:only_genie].empty? && r[:only_ours].empty? && r[:timing].empty?

        out << "  [#{k}]"
        lines = r[:only_genie].map { |t, s| format('    GENIE-ONLY %8.0fms  %s', t, s.inspect) }
        lines.concat(r[:only_ours].map { |t, s| format('    OURS-ONLY  %8.0fms  %s', t, s.inspect) })
        lines.concat(r[:timing].map { |(ga, ob)| format('    TIMING     genie %6.0fms vs ours %6.0fms  %s', ga[0], ob[0], ga[1].inspect) })
        out.concat(collapse_runs(lines))
      end
      out.join("\n")
    end

    # Identical consecutive report lines (t39/t51: 200 x "ping" at one timestamp) are
    # printed once with a repeat count.
    def collapse_runs(lines)
      lines.chunk_while { |a, b| a == b }.map { |run| run.length > 1 ? "#{run.first}  (x#{run.length})" : run.first }
    end

    # Run our engine on a discovered Case; scripts and includes resolve from the case dir.
    # Paths under the case dir are normalized to `<scriptdir>` like the golden.
    # @return [Array<Hash>] our events
    # .flags are validated (parse_flags); `--config-dir` (relative to the case dir) is used
    # unless +config_dir+ is given, and checked by check_config_dir.
    # @raise [ArgumentError] on an unsupported .flags option or config dir
    def run_ours(flow_case, config_dir: nil)
      opts = parse_flags(flow_case.flags)
      if opts['--config-dir'] && config_dir.nil?
        config_dir = File.expand_path(opts['--config-dir'], flow_case.dir)
        check_config_dir(config_dir)
      end
      events = with_config_copy(config_dir) do |copy|
        OurRun.new(flow_case.dir, config_dir: copy).run(flow_case.name, flow_case.args, parse_trace(flow_case.trace)).events
      end
      normalize_paths(events, File.expand_path(flow_case.dir))
    end

    # Yield a private per-run copy of +dir+'s files (genieflow reads its --config-dir through a
    # per-run sandbox too, src/ShimsIO.cs), so nothing a run saves can reach the fixture tree.
    # @param dir [String, nil]
    # @yieldparam copy [String, nil] nil when +dir+ is nil
    def with_config_copy(dir)
      return yield(nil) unless dir

      Dir.mktmpdir('genie-flow-config') do |tmp|
        Dir.children(dir).each do |f|
          src = File.join(dir, f)
          FileUtils.cp(src, File.join(tmp, f)) if File.file?(src)
        end
        yield tmp
      end
    end
  end
end
