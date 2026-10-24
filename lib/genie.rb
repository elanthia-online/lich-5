# frozen_string_literal: true

require 'tmpdir'

module Lich
  # The Genie scripting engine: a clean-room Ruby port of the Genie4 (C#) script
  # interpreter, so Genie scripts run natively under Lich. See the design and the
  # behavior specs under docs/genie-engine-port.md and docs/genie-engine/.
  #
  # Enable with Lich::Genie.enabled = true. When enabled, `.cmd` scripts route to
  # this engine and `.wiz` handling is disabled; when disabled (the default),
  # WizardScript continues to handle `.cmd`/`.wiz`.
  #
  # Persistence uses Genie's own config-file model (no Lich DB): a Genie-style
  # `Config/` tree under {config_dir}. See docs Decision 7.
  module Genie
    # Engine build id. BUMP THIS on every shipped change so a tester can confirm they
    # actually picked up a branch update: `;eq echo Lich::Genie::VERSION`. The deploy
    # path (`;lich5-update --branch=...`) overwrites files from a tarball WITHOUT moving
    # git HEAD, so `git log`/commit hashes are not a reliable "which version am I on"
    # signal -- this constant is. Format: MAJOR.MINOR.PATCH (YYYY-MM-DD).
    VERSION = '0.26.10 (2026-10-22)'

    # Raised for any Genie-engine evaluation/parse error. Callers that mirror
    # Genie's "swallow and default" behavior (e.g. `evalmath`) rescue this.
    class Error < StandardError; end

    @enabled_by_key = nil
    @config_dir = nil
    @global_store = nil
    @triggers = nil
    @class_list = nil
    @alias_list = nil
    @name_list = nil
    @stream_filters = nil
    @lists = nil
    @game_state = nil
    # Not reset by a reload either: the feed's tap module is prepended
    # onto Lich's Script once; a new feed would prepend a second tap and parse every row twice.
    @game_state_feed = nil unless instance_variable_defined?(:@game_state_feed)
    @command_queue = nil
    # Not reset by a reload of this file: the running scripts keep their list membership.
    @script_list = nil unless instance_variable_defined?(:@script_list)
    # Nor the trigger worker: its thread lives on with the queued game rows.
    @trigger_worker = nil unless instance_variable_defined?(:@trigger_worker)
    # Whether loading the glue (genie_script.rb, required by lich.rbw) installs the game-state tap
    # at once ({GenieScript.install_at_lich_load!}). The genie spec support sets it false before it
    # loads the glue into a process with no Lich session (the glue specs drive the taps
    # themselves); kept across a reload of this file like the flags above.
    @autoinstall = true unless instance_variable_defined?(:@autoinstall)
    # Thread-local set while the engine prints its own output (echo, `#echo`, diagnostics): the
    # glue's script-output feed skips such a line -- Genie never parses its own echo (
    # ClassCommand_EchoText only AddText, FormMain.cs:4229-4276, 5611-5618 R).
    ENGINE_OUTPUT_KEY = :lich_genie_engine_output
    # Guards the first build of the process-wide store/registry: two scripts starting at
    # once (or a script and the trigger thread) must not each read the cfg into their own
    # instance -- with no disk write-through there is nothing to reconcile them later.
    @singleton_mutex = Mutex.new
    # Engine notices about a list file read before the glue can print them (the side file of
    # triggers.cfg / aliases.cfg at engine start, {DefinitionTrust}): held until
    # {definition_notice_listener} is set. Kept across a reload, like the listener.
    @pending_notices = [] unless instance_variable_defined?(:@pending_notices)
    NOTICE_MUTEX = Mutex.new unless const_defined?(:NOTICE_MUTEX, false)

    class << self
      # Whether the Genie engine is active for `.cmd` scripts. Persisted
      # PER-CHARACTER in lich.db3 (survives relogin and reset-to-branch; other
      # characters are unaffected, so their WizardScript `.cmd`/`.wiz` keep working).
      #
      # The per-character key (`genie_enabled:<game>:<char>`) is derived from live
      # XMLData, which is EMPTY until the character stream arrives. So we cache per
      # resolved key and, crucially, do NOT cache a lookup made before login (empty
      # game/char) -- otherwise a premature check would memoize a false "off" that
      # never re-reads, and the toggle would appear not to persist across relogs.
      # @return [Boolean]
      def enabled?
        character_flag?(settings_key)
      end

      # @return [Boolean]
      def enabled
        enabled?
      end

      # @param value [Object] truthy value (true/on/yes/1) enables the engine
      def enabled=(value)
        on = truthy?(value)
        (@enabled_by_key ||= {})[settings_key] = on
        write_enabled(settings_key, on)
      end

      # Whether the engine writes `<genieHook>` tags (docs/genie-engine/hook-protocol.md) to the
      # front end for a script's front-end effects (`#highlight`, `#window`, `#echo >window`, ...).
      # Off by default: no shipped front end reads them, and a Wizard (non-XML) front end shows the
      # raw tag as text. Off, the effects that carry text reach every front end through Lich's own
      # messaging instead (`#echo >window text` and `#link` text: the window where Lich's front end
      # has it, else the main window; an input-box text: the main window) and the others do
      # nothing. Persisted per character like {enabled?}; for a hook-aware front end.
      # @return [Boolean]
      def hooks_enabled?
        character_flag?(hooks_key)
      end

      # @param value [Object] truthy value (true/on/yes/1) turns the tags on for this character
      def hooks_enabled=(value)
        on = truthy?(value)
        (@enabled_by_key ||= {})[hooks_key] = on
        write_enabled(hooks_key, on)
      end

      # Drop the per-character setting cache -- the engine and hook toggles (test/administrative).
      # @return [void]
      def reset_enabled_cache!
        @enabled_by_key = nil
      end

      # Root of OUR Genie config tree (mirrors Genie's layout; not native Genie's). Defaults to
      # <SCRIPT_DIR>/GenieProfiles under Lich, or a temp dir when running headless.
      # @return [String]
      def config_dir
        @config_dir ||= File.join(defined?(SCRIPT_DIR) ? SCRIPT_DIR : Dir.tmpdir, 'GenieProfiles')
      end

      # Administrative: point the engine at another config tree. The next access to
      # {global_store} / {triggers} reads that tree's cfg files (anything unsaved in the
      # current ones is dropped).
      # @param path [String]
      def config_dir=(path)
        @singleton_mutex.synchronize do # never interleave with a first build
          @config_dir = path
          @global_store = nil # rebuild against the new location
          @triggers = nil
          @class_list = nil
          @alias_list = nil
          @name_list = nil
          @stream_filters = nil
          @game_state = nil
        end
      end

      # Our own Genie Config dir (<config_dir>/Config), never native Genie's (a decided divergence).
      # @return [String]
      def variables_file
        File.join(config_dir, 'Config', 'variables.cfg')
      end

      # `triggers.cfg` beside variables.cfg (Remix: Config.ConfigDir + "\triggers.cfg",
      # FormMain.cs:2339, Command.cs:1383-1390 R).
      # @return [String]
      def triggers_file
        File.join(config_dir, 'Config', 'triggers.cfg')
      end

      # Our Config dir: Remix's Config.ConfigDir, where the list files live (triggers.cfg,
      # classes.cfg, gags.cfg, substitutes.cfg, aliases.cfg, Profiles/).
      # @return [String]
      def list_dir
        File.join(config_dir, 'Config')
      end

      # `settings.cfg` beside variables.cfg (Remix Config.Load, Config.cs:531-565 R).
      # @return [String]
      def settings_file
        File.join(config_dir, 'Config', 'settings.cfg')
      end

      # What `$scriptdir`/`@scriptdir@` and the other Remix directory variables
      # (Globals.cs:237-242, 858-864 R) expand to: the directory our engine runs .cmd
      # scripts from, and the Remix-named folders under our own config tree.
      # @return [Hash{String=>String}]
      def directories
        script_dir = defined?(SCRIPT_DIR) ? SCRIPT_DIR : Dir.tmpdir
        {
          'scriptdir' => script_dir, 'mapdir' => File.join(config_dir, 'Maps'),
          'plugindir' => File.join(config_dir, 'Plugins'), 'artdir' => File.join(config_dir, 'Art'),
          'logdir' => File.join(config_dir, 'Logs'), 'sounddir' => File.join(config_dir, 'Sounds')
        }
      end

      # Process-wide capture of the game stream's reserved variables (Remix Game.cs), fed
      # by the glue with every raw server string and read by every script. Built on first
      # use with settings.cfg's prompt / promptforce / monstercountignorelist /
      # roundtimeoffset, and with the SpellTimer plugin port writing into {global_store}.
      # @return [GameState]
      def game_state
        @game_state || @singleton_mutex.synchronize { @game_state ||= build_game_state }
      end

      # The glue's live feed of the raw server strings into {game_state}, its start-up replay
      # and the typed-command tap ({GameStateFeed}), with rate-limited error lines of their
      # own. Kept here, not in the glue, so reloading genie_script.rb keeps the one tap
      # module (re-prepending it is a no-op).
      # @return [GameStateFeed]
      def game_state_feed
        @game_state_feed || @singleton_mutex.synchronize do
          @game_state_feed ||= GameStateFeed.new(
            game_state: -> { game_state },
            report: ErrorReport.new('game-state feed', emit: ->(text) { engine_output { respond(text) } }),
            upstream_report: ErrorReport.new('typed-command tap', emit: ->(text) { engine_output { respond(text) } })
          )
        end
      end

      # The process-wide trigger worker (Remix's trigger-Channel consumer, {TriggerWorker}): every
      # game row's dispatch runs on it. Kept here, not in the glue, so a reload of genie_script.rb
      # keeps the one worker.
      # @return [TriggerWorker]
      def trigger_worker
        @trigger_worker || @singleton_mutex.synchronize do
          @trigger_worker ||= TriggerWorker.new(report: ->(e) { engine_output { respond("--- Lich: genie trigger worker error: #{e}") } })
        end
      end

      # Run the block (a respond of the engine's own text) marked as engine output.
      # @return [Object] the block's value
      def engine_output
        previous = Thread.current[ENGINE_OUTPUT_KEY]
        Thread.current[ENGINE_OUTPUT_KEY] = true
        yield
      ensure
        Thread.current[ENGINE_OUTPUT_KEY] = previous
      end

      # @return [Boolean] whether the calling thread is printing engine output ({engine_output})
      def engine_output?
        Thread.current[ENGINE_OUTPUT_KEY] ? true : false
      end

      # Whether the engine is on for the logged-in character: the gate of the game-state tap
      # installed at Lich load. False before login (no character-scoped setting to read, and
      # no database read per row) -- the tap's first open row replays Lich's server buffer.
      # @return [Boolean]
      def engine_active?
        character_scoped? && enabled?
      end

      # Process-wide global store (one character per Lich process), shared by every
      # Genie script and the trigger thread. Built on first use -- engine start -- which
      # reads variables.cfg once (FormMain.cs:2311 R); after that it is memory-only
      # until `#var save` / `#save vars|all` (see {GlobalStore}).
      # @return [GlobalStore]
      def global_store
        @global_store || @singleton_mutex.synchronize { @global_store ||= GlobalStore.new(file: variables_file) }
      end

      # Test/administrative hook to drop the memoized store.
      # @return [void]
      def reset_global_store!
        @global_store = nil
        @game_state = nil # its SpellTimer writes into the dropped store
      end

      # The session's timed CommandQueue (Remix Globals.CommandQueue): `send N`, `#send`, `#do`,
      # `#queue` and the `-` quick send of every genie script, #trigger body and typed command
      # fill it; the glue's {CommandQueue::Worker} drains it off Lich's hook thread.
      # @return [CommandQueue]
      def command_queue
        @command_queue || @singleton_mutex.synchronize { @command_queue ||= CommandQueue.new }
      end

      # The session's script lists (Remix m_oScriptList + m_oScriptListNew, {ScriptList}): every
      # genie script, the `#script` walks, the dupe check and $scriptlist.
      # @return [ScriptList]
      def script_list
        @script_list || @singleton_mutex.synchronize { @script_list ||= ScriptList.new }
      end

      # Config.bAbortDupeScript (Config.cs:39, 1113-1131 R; the tester's: True): settings.cfg's
      # abortdupescript as the live {game_state} config holds it, so a runtime `#config
      # abortdupescript` applies to the next launch.
      # @return [Boolean]
      def abort_dupe_script?
        game_state.config.abort_dupe_script ? true : false
      end

      # Config.bIgnoreScriptWarnings (Config.cs:32, 995-1013 R; Remix default False, the
      # tester's False): whether a script with an unknown command or a duplicate label still loads
      # silently (Script.cs:4070-4078, 4322-4336 R). Read at each load.
      # @return [Boolean]
      def ignore_script_warnings?
        game_state.config.ignore_script_warnings ? true : false
      end

      # Process-wide gag/substitute lists (Model A, Decision 6), shared across all Genie scripts
      # and applied on the client-bound downstream stream. Built on first use -- engine start --
      # with gags.cfg and substitutes.cfg (FormMain.cs:2331, 2335 R); a substitute's replacement
      # is ParseGlobalVars'd at display time against the process-wide globals.
      # @return [StreamFilters]
      def stream_filters
        @stream_filters || @singleton_mutex.synchronize { @stream_filters ||= build_stream_filters }
      end

      # Process-wide class list (Remix Globals.ClassList, {ClassList}): `default` = True plus
      # classes.cfg, read at engine start (FormMain.cs:2343 R).
      # @return [ClassList]
      def class_list
        @class_list || @singleton_mutex.synchronize do
          @class_list ||= ClassList.new.tap { |list| list.load(File.join(list_dir, 'classes.cfg')) }
        end
      end

      # Process-wide alias list (Remix Globals.AliasList, {AliasList}): aliases.cfg, read at engine
      # start (FormMain.cs:2327 R). A script's `put` expands it ({ParseCommand}).
      # @return [AliasList]
      def alias_list
        @alias_list || with_notices do |notices|
          @singleton_mutex.synchronize do
            @alias_list ||= AliasList.new.tap { |list| list.load(File.join(list_dir, 'aliases.cfg'), notice: notices.method(:<<)) }
          end
        end
      end

      # Process-wide name-list keys (Remix Globals.NameList, {NameList}): names.cfg, read at engine
      # start (FormMain.cs:2319 R). A key that breaks RebuildIndex there stays listed (Remix's startup
      # Load throws after adding it), so every later `#name` faults until it is removed.
      # @return [NameList]
      def name_list
        @name_list || @singleton_mutex.synchronize do
          @name_list ||= NameList.new.tap do |list|
            list.load(File.join(list_dir, 'names.cfg'))
          rescue Error
            nil
          end
        end
      end

      # The session's global lists for the `#command` arms ({Lists}): the registries above, read
      # through callables so a rebuilt one (config_dir change, reload) is followed.
      # @return [Lists]
      def lists
        @lists ||= Lists.new(triggers: -> { triggers }, classes: -> { class_list }, filters: -> { stream_filters },
                             aliases: -> { alias_list }, names: -> { name_list }, config_dir: -> { list_dir })
      end

      # Process-wide trigger registry (Genie #trigger), shared across all Genie
      # scripts. Triggers fire commands on matching game lines (automation). Built on
      # first use -- engine start -- with the rows of triggers.cfg (FormMain.cs:2339 R);
      # never re-read from disk except by `#trigger load` / `#load triggers|all`.
      # @return [Triggers]
      def triggers
        @triggers || with_notices { |notices| @singleton_mutex.synchronize { @triggers ||= build_triggers(notices) } }
      end

      # Where an engine notice about a list file goes ({definition_notice}): the glue sets it once
      # the engine runs; the notices made before are handed to it then.
      # @return [#call, nil] callable(text)
      attr_reader :definition_notice_listener

      # @param callable [#call, nil]
      def definition_notice_listener=(callable)
        held = NOTICE_MUTEX.synchronize do
          @definition_notice_listener = callable
          callable ? @pending_notices.slice!(0..) : []
        end
        held.each { |text| callable.call(text) }
      end

      # One engine notice about a list file (a side file of triggers.cfg / aliases.cfg that cannot
      # be read, {DefinitionTrust}): to {definition_notice_listener}, or held until it is set.
      # @param text [String]
      # @return [void]
      def definition_notice(text)
        listener = NOTICE_MUTEX.synchronize do
          @pending_notices << text unless @definition_notice_listener
          @definition_notice_listener
        end
        listener&.call(text)
      end

      # Where a registry's #trigger shut-off goes ({Triggers#on_disabled}: a pattern whose match
      # timed out {Triggers::TIMEOUT_LIMIT} times in a row): the glue sets it once at the engine
      # start. Every registry {triggers} builds reads it per report, so a rebuilt registry -- a
      # config_dir change, a reload of this file -- keeps it.
      # @return [#call, nil] callable(pattern)
      attr_accessor :trigger_disabled_listener

      # Where a gag's or substitute's shut-off goes ({StreamFilters#on_disabled}: its match timed
      # out {StreamFilters::TIMEOUT_LIMIT} times in a row), read per report like
      # {trigger_disabled_listener}. Called on the matching thread -- Lich's parser thread, maybe
      # inside the game state's row -- so the glue's listener only posts the warning elsewhere.
      # @return [#call, nil] callable(kind, text)
      attr_accessor :filter_disabled_listener

      # Where {game_state}'s variable changes go (Remix ClassCommand_EventVariableChanged ->
      # TriggerVariableChanged, FormMain.cs:5045-5050 R): the glue sets it to its
      # VariableDispatch.broadcast. Read per row, so a rebuilt game state keeps it.
      # @return [#call, nil] callable(names): one row's (or send's) changes, in order
      attr_accessor :variable_listener

      # The engine's intake for game text Lich produces outside the row parser (the opt-in
      # assess-ids shim's enriched lines, {AssessIds.deliver}, only while the engine is on): the
      # glue sets it once the engine runs, and hands each batch to its #triggers and scripts as
      # game lines from the trigger worker. Lich scripts never get these lines.
      # @return [#call, nil] callable(lines)
      attr_accessor :text_listener

      # The display-time ParseGlobalVars of a substitute's replacement ({StreamFilters#globals}):
      # the glue sets it to its own globals (LichGameState's reserved values); nil = the bare
      # capture's.
      # @return [#call, nil] callable(text) => text
      attr_accessor :display_globals

      # Diagnostic: when true, the downstream hook echoes each (XML-stripped) line it
      # checks and each trigger that fires -- so a tester can see whether the stream is
      # reaching the trigger matcher live. Toggle with `;e Lich::Genie.trace_triggers = true`.
      attr_accessor :trace_triggers

      # @return [Boolean] whether loading genie_script.rb installs the gated game-state tap (default
      #   true; the genie spec support turns it off)
      attr_accessor :autoinstall

      private

      # Called under @singleton_mutex: triggers.cfg's rows, with the shut-off report wired; a
      # notice the load makes goes to +notices+.
      def build_triggers(notices)
        Triggers.new.tap do |registry|
          registry.on_disabled = ->(pattern) { Lich::Genie.trigger_disabled_listener&.call(pattern) }
          registry.load(triggers_file, notice: notices.method(:<<))
        end
      end

      # The block's value; the notices it collected go out after it, outside @singleton_mutex.
      def with_notices
        notices = []
        yield(notices)
      ensure
        notices.each { |text| definition_notice(text) }
      end

      # Called under @singleton_mutex: the two list files, and the display-time ParseGlobalVars over
      # the process-wide store and game state (read through the public readers at display time:
      # never under this mutex).
      def build_stream_filters
        StreamFilters.new.tap do |filters|
          filters.load_gags(File.join(list_dir, 'gags.cfg'))
          filters.load_subs(File.join(list_dir, 'substitutes.cfg'))
          filters.on_disabled = ->(kind, text) { Lich::Genie.filter_disabled_listener&.call(kind, text) }
          filters.globals = lambda do |text|
            expander = Lich::Genie.display_globals
            next expander.call(text) if expander

            vars = Variables.new(game_state: ReservedState.new(game_state: Lich::Genie.game_state), global_store: Lich::Genie.global_store)
            Substitution.new(variables: vars).expand_globals(text)
          end
        end
      end

      # Called under @singleton_mutex: must not call {global_store} (same mutex).
      def build_game_state
        store = @global_store ||= GlobalStore.new(file: variables_file)
        GameState.new(config: GameState::Config.from_settings(SettingsFile.read(settings_file)),
                      spell_timer: SpellTimer.new(store: store),
                      listener: ->(names) { Lich::Genie.variable_listener&.call(names) },
                      display: ->(text, target) { Lich::Genie.stream_filters.displayed(text, target) },
                      globals: store)
      end

      def truthy?(value)
        value.to_s =~ /\A(1|on|true|yes)\z/i ? true : false
      end

      # Per-character key so enabling on one character never affects others.
      def settings_key
        "genie_enabled:#{safe_xml(:game)}:#{safe_xml(:name)}"
      end

      # Per-character key of {hooks_enabled?}.
      def hooks_key
        "genie_hooks:#{safe_xml(:game)}:#{safe_xml(:name)}"
      end

      # A per-character on/off setting under +key+, cached per resolved key once logged in.
      def character_flag?(key)
        return read_enabled(key) unless character_scoped? # pre-login: read live, never cache

        @enabled_by_key ||= {}
        @enabled_by_key[key] = read_enabled(key) unless @enabled_by_key.key?(key)
        @enabled_by_key[key] == true
      end

      # True once the character stream has populated both game and name, so the
      # per-character key actually identifies a character (not `genie_enabled::`).
      def character_scoped?
        !safe_xml(:game).empty? && !safe_xml(:name).empty?
      end

      def safe_xml(attribute)
        return '' unless defined?(XMLData) && XMLData.respond_to?(attribute)

        XMLData.public_send(attribute).to_s
      rescue StandardError
        ''
      end

      def persistence_available?
        defined?(Lich) && Lich.respond_to?(:db) && Lich.db
      rescue StandardError
        false
      end

      def read_enabled(key)
        return false unless persistence_available?

        truthy?(Lich.db.get_first_value('SELECT value FROM lich_settings WHERE name=?;', [key]))
      rescue StandardError
        false
      end

      def write_enabled(key, value)
        return unless persistence_available?

        Lich.db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
        Lich.db.execute('INSERT OR REPLACE INTO lich_settings(name,value) values(?,?);', [key, value.to_s])
      rescue StandardError
        nil
      end
    end
  end
end

require_relative 'genie/numeric'
require_relative 'genie/vb_conversions'
require_relative 'genie/text'
require_relative 'genie/authored_command'
require_relative 'genie/net_regex'
require_relative 'genie/net_replace'
require_relative 'genie/dispatch_depth'
require_relative 'genie/parse_dispatch'
require_relative 'genie/variable_dispatch'
require_relative 'genie/game_events'
require_relative 'genie/math_calc'
require_relative 'genie/math_eval'
require_relative 'genie/eval'
require_relative 'genie/reserved'
require_relative 'genie/write_clock'
require_relative 'genie/assess_ids'
require_relative 'genie/collation'
require_relative 'genie/config_file'
require_relative 'genie/definition_trust'
require_relative 'genie/variable_file'
require_relative 'genie/trigger_file'
require_relative 'genie/class_list'
require_relative 'genie/alias_list'
require_relative 'genie/name_list'
require_relative 'genie/config_setting'
require_relative 'genie/log_file'
require_relative 'genie/action_list'
require_relative 'genie/global_store'
require_relative 'genie/settings_file'
require_relative 'genie/game_row'
require_relative 'genie/spell_timer'
require_relative 'genie/game_state'
require_relative 'genie/reserved_state'
require_relative 'genie/game_state_feed'
require_relative 'genie/zone_names'
require_relative 'genie/stream_filters'
require_relative 'genie/triggers'
require_relative 'genie/lists'
require_relative 'genie/variables'
require_relative 'genie/specials'
require_relative 'genie/substitution'
require_relative 'genie/call_stack'
require_relative 'genie/script_args'
require_relative 'genie/script_launch'
require_relative 'genie/script_list'
require_relative 'genie/js_value'
require_relative 'genie/js_parser'
require_relative 'genie/js_source'
require_relative 'genie/js_runtime'
require_relative 'genie/js_arrays'
require_relative 'genie/command_queue'
require_relative 'genie/trigger_worker'
require_relative 'genie/goto_walk'
require_relative 'genie/color_code'
require_relative 'genie/parse_command'
require_relative 'genie/command_router'
require_relative 'genie/trigger_runner'
require_relative 'genie/lexer'
require_relative 'genie/trace'
require_relative 'genie/net_date'
require_relative 'genie/interpreter'
require_relative 'genie/engine'
