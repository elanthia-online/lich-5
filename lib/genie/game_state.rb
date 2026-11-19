# frozen_string_literal: true

module Lich
  module Genie
    # The reserved globals Remix's Game.cs keeps from the game stream, computed from the
    # same raw server strings (the Lich glue feeds every one through {GameStateFeed}).
    # Remix updates these while it parses a row (Game.cs ProcessXMLNodeElement R); Lich's
    # own parsers keep different shapes (DRRoom's object lists, a live-decaying roundtime,
    # ...), so the values a .cmd script reads come from here instead:
    #
    #   room desc/objs/players/exits components -> $roomdesc $roomobjs $roomplayers
    #     $roomexits $monstercount $monsterlist (InnerText, '"' removed; Game.cs:1763-1823,
    #     2656-2718 R); <streamWindow id='room'> -> $roomname $uid (Game.cs:1485-1521 R);
    #   <left>/<right> -> $lefthand $lefthandnoun $lefthandid ... (Game.cs:1940-1977 R);
    #   <spell> -> $preparedspell and the spell timer (Game.cs:1914-1938 R; FormMain.cs:
    #     6697-6707 R); <castTime>, <spelltime> (Game.cs:2199-2234 R);
    #   <prompt> -> $gametime $unixtime $roundtime $prompt (Game.cs:2236-2416 R);
    #   <progressBar> -> vitals + *BarText (Game.cs:1835-1909 R); <indicator> -> the
    #     posture/status flags (Game.cs:2014-2167 R); <compass>/<dir> -> $north..$out
    #     (Game.cs:2425-2590 R); <app> -> $charactername $gamename (Game.cs:1983-2010 R);
    #   game sends -> $lastcommand (Game.cs:545-551 R, via {#sent}); a typed one also sets the
    #     $lastinput GLOBAL ({GlobalStore#assign}: Remix's VariableList indexer, a SaveToFile
    #     variable unless it exists, Game.cs:529 R; Globals.cs:665-690 R -- not a reserved name).
    #
    # Each captured value carries a {WriteClock} stamp so a script's `#var` of the same
    # name is overridden by the next game update and not before. Values never seen
    # stay uncaptured ({#[]} nil): the caller decides the fallback (Remix's
    # SetDefaultGlobalVars default, or Lich state; see {ReservedState}). The names a host
    # computes ($roomid, $zoneid, $zonename, $game) get their write stamps from here too
    # ({#host_stamp}): the capture start (Remix's connect) and every automapper room
    # update (the first prompt after a room title, AutoMapper.cs:269-278, 361-394 R).
    #
    # Variable changes: every place Game.cs raises VariableChanged while it parses
    # a row (or Game.SendText while it sends) records that name -- "$health", "monsterlist",
    # "lastcommand", ... exactly as Remix spells it, in Remix's order -- and the +listener+ gets
    # them as ONE list per row (or send) AFTER it, outside the lock (the listener runs script code: eval
    # #triggers, `#parse`, reads of these very values; under the lock that would deadlock the
    # non-reentrant mutex and stall Lich's parser loop). Remix dispatches each one synchronously
    # in the middle of the row instead, so an eval reading a later name of the SAME row sees
    # its old value there and its new one here (open-items.md Q7; Remix's timing races are not emulated). The
    # replay of {#seed} raises nothing: Remix never re-parses old rows. The automapper plugin's
    # "$roomid" follows "$prompt" on every room update ({#mapper_room_update}); its other
    # SetRoomVariables names are not modelled.
    #
    # Script-timing events ({GameEvents}): a `room desc` component (TriggerMove), a prompt
    # with a roundtime (SetRoundTime) and every prompt (TriggerPrompt + the prompt text Game.cs
    # prints with parse) are recorded per row too; a FED row's listener batch is a {Row}, which
    # carries them ({Row#events}) so the host can deliver them after the row's variable changes.
    #
    # Thread model: fed on Lich's parser thread, read from script threads. Two locks: every
    # WRITER (a row, the replay, a send, a setting, the automapper hook) holds
    # @write_mutex for its whole critical section, so a row is still applied atomically with
    # respect to every other write; the state itself is under @mutex, which a row releases while
    # the +display+ port matches the gags/substitutes ({#displayed_main}) -- a reader (a script's
    # `$roomobjs`, the queue's roundtime test) never waits on a regex, though it may see the row
    # half applied then, as Remix's lock-free reads always can. A host
    # line ({#printed}) takes @mutex only, so it may land while a row is in the port;
    # the port itself must call no host code that can wait on another thread's lock (the glue's
    # display-time globals read cached host values, never Lich's Map).
    class GameState
      # One fed row's variable-change names (an Array, like the batch of a send) plus the row's
      # {GameEvents} in Remix's order ({Row#events}); the host tells a game row from a send by
      # this class.
      class Row < Array
        # @return [Array<GameEvents::RoundTime, GameEvents::Prompt, GameEvents::Move>]
        attr_reader :events

        # @param changes [Array<String>]
        # @param events [Array]
        def initialize(changes, events)
          super(changes)
          @events = events.freeze
        end
      end

      # The Remix settings the engine reads (Config.cs:12-15, 25-26, 47, 66 R defaults): the four
      # Game.cs reads here, and the three characters Command.ParseCommand / Script.ParseAction
      # split and dispatch on (separatorchar, commandchar, scriptchar; Command.cs:235-256, 2536 R,
      # Script.cs:2135 R). Remix has no setting for the quick-send char (cQuickSendChar '-',
      # Config.cs:15 R), so it is a constant ({ParseCommand::QUICK_SEND_CHAR}).
      #
      # The script engine's own keys (Config.cs:27, 29, 32, 39, 743-750, 905-912, 995-1013,
      # 1113-1131 R): scripttimeout (ms), maxgosubdepth, ignorescriptwarnings, abortdupescript --
      # read live, so a runtime `#config` takes effect at the script's next check.
      #
      # mycommandchar (Config.cs:17, 638-645 R; default '/'): Game.SendText echoes a text that starts
      # with it but never sends it to the game nor records it as $lastcommand/$lastinput (Game.cs:467,
      # 527, 545 R; {#my_command?}) -- "parsed but not sent" (it is meant for plugins).
      Config = Struct.new(:prompt, :prompt_force, :ignore_monster_list, :rt_offset, :separator_char, :command_char,
                          :script_char, :condensed, :parse_game_only, :show_links, :trigger_on_input,
                          :script_timeout, :max_gosub_depth, :ignore_script_warnings, :abort_dupe_script,
                          :my_command_char, keyword_init: true) do
        # Fold settings.cfg rows (or a runtime `#config key value`) through Remix's
        # SetSetting rules for these keys (Config.cs:579-586, 618-636, 803-831, 854-869, 895-903,
        # 915-922 R); every other key is not ours and leaves the config as it is.
        # @param pairs [Array<Array(String, String)>] {SettingsFile.read} output
        # @param base [Config] the config the rows change (Remix's live Config object)
        # @return [Config] a new config
        def self.from_settings(pairs, base: DEFAULT_CONFIG)
          config = base.dup
          pairs.each do |key, value|
            case key.downcase
            when 'prompt'
              config.prompt = case value.downcase
                              when 'on', 'true', '1' then '> '
                              when 'off', 'false', '0' then ''
                              else value
                              end
            when 'promptforce' then config.prompt_force = %w[on true 1].include?(value.downcase)
            when 'monstercountignorelist' then config.ignore_monster_list = value unless value.empty?
            when 'roundtimeoffset' then config.rt_offset = Numeric.string_to_double(value) unless value.empty?
            # Conversions.ToChar(sValue.ToCharArray().GetValue(0)): the first char of a non-empty value.
            when 'separatorchar' then config.separator_char = value[0] unless value.empty?
            when 'commandchar' then config.command_char = value[0] unless value.empty?
            when 'scriptchar' then config.script_char = value[0] unless value.empty?
            when 'mycommandchar' then config.my_command_char = value[0] unless value.empty?
            # on/true/1 -> true, anything else false (Config.cs:596-613, 874-891, 1136-1153, 1318-1335 R)
            when 'condensed' then config.condensed = truthy_setting?(value)
            when 'parsegameonly' then config.parse_game_only = truthy_setting?(value)
            when 'showlinks' then config.show_links = truthy_setting?(value)
            when 'triggeroninput' then config.trigger_on_input = truthy_setting?(value)
            when 'scripttimeout', 'maxgosubdepth' then engine_number(config, key.downcase, value)
            when 'ignorescriptwarnings' then config.ignore_script_warnings = truthy_setting?(value)
            when 'abortdupescript' then config.abort_dupe_script = truthy_setting?(value)
            end
          end
          config
        end

        # scripttimeout = Conversions.ToInteger(Utility.StringToDouble(value)), maxgosubdepth =
        # Conversions.ToInteger(value), each only for a non-empty value (Config.cs:743-750,
        # 905-912 R). A value VB cannot convert throws: Config.Load drops that row and a runtime
        # SetSetting fails (Config.cs:547-554 R; the `#config` echo is CommandRouter's), so the old value stays.
        def self.engine_number(config, key, value)
          return if value.empty?

          if key == 'scripttimeout'
            config.script_timeout = VbConversions.double_to_integer(Numeric.string_to_double(value))
          else
            config.max_gosub_depth = VbConversions.to_integer(value)
          end
        rescue Error
          nil
        end

        # @param value [String]
        # @return [Boolean]
        def self.truthy_setting?(value)
          %w[on true 1].include?(value.downcase)
        end
      end
      # Config.cs:12-15, 17, 19, 25-27, 29, 32, 39-40, 47, 54, 66-67 R defaults.
      DEFAULT_CONFIG = Config.new(prompt: '> ', prompt_force: true, ignore_monster_list: 'appears dead|(dead)', rt_offset: 0.0,
                                  separator_char: ';', command_char: '#', script_char: '.', condensed: false,
                                  parse_game_only: false, show_links: false, trigger_on_input: true,
                                  script_timeout: 5000, max_gosub_depth: 50, ignore_script_warnings: false,
                                  abort_dupe_script: true, my_command_char: '/').freeze

      # <indicator id> => [variable, prompt letter or nil] (Game.cs:2025-2163 R; the
      # letters and their order: Game.cs:2280-2330 R). Poisoned/diseased have a variable
      # but no indicator-hash entry, so no letter.
      INDICATORS = {
        'IconKNEELING' => 'kneeling', 'IconPRONE' => 'prone', 'IconSITTING' => 'sitting',
        'IconSTANDING' => 'standing', 'IconSTUNNED' => 'stunned', 'IconHIDDEN' => 'hidden',
        'IconINVISIBLE' => 'invisible', 'IconDEAD' => 'dead', 'IconWEBBED' => 'webbed',
        'IconJOINED' => 'joined', 'IconBLEEDING' => 'bleeding', 'IconPOISONED' => 'poisoned',
        'IconDISEASED' => 'diseased'
      }.freeze
      PROMPT_LETTERS = [%w[kneeling K], %w[sitting s], %w[prone P], %w[stunned S], %w[hidden H],
                        %w[invisible I], %w[webbed W], %w[bleeding !], %w[joined J]].freeze
      INDICATOR_HASH = %w[kneeling prone sitting standing stunned hidden invisible dead webbed joined bleeding].freeze

      COMPASS = {
        'n' => 'north', 'ne' => 'northeast', 'e' => 'east', 'se' => 'southeast', 's' => 'south',
        'sw' => 'southwest', 'w' => 'west', 'nw' => 'northwest', 'up' => 'up', 'down' => 'down', 'out' => 'out'
      }.freeze

      # <progressBar id> => [value variable, bar-text variable or nil] (Game.cs:1849-1906 R).
      BARS = {
        'health' => %w[health healthBarText], 'mana' => %w[mana manaBarText],
        'spirit' => %w[spirit spiritBarText], 'stamina' => %w[stamina staminaBarText],
        'conclevel' => %w[concentration concentrationBarText], 'concentration' => %w[concentration concentrationBarText],
        'encumlevel' => ['encumbrance', nil], 'encumblevel' => ['encumbrance', nil], 'encumbrance' => ['encumbrance', nil]
      }.freeze

      # RoomNameRegex (Game.cs:2662 R).
      ROOM_NAME = /\[(?<roomname>[^\]]+)\](?: \((?<roomuid>\d+)\))?/.freeze
      # MonsterRegex (Game.cs:2656 R) on InnerXml.
      MONSTER = %r{<pushBold />([^<]*)<popBold />([^,.]*)}.freeze
      # Only buffers naming one of these elements can change a value here, so the rest
      # are never parsed while no m_bIgnoreXMLDepth is pending (a performance filter;
      # Remix parses every buffer).
      # (a, b, d, preset, stream: display text; pushBold/popBold: the combat-row split's bold flag.)
      INTEREST = %r{<(?:streamWindow|component|compDef|progressBar|spell|left|right|app|indicator|roundTime|castTime|spelltime|
                     prompt|compass|dir|pushStream|popStream|a|b|d|preset|stream|pushBold|popBold)[\s>/]}x.freeze

      # @param config [Config]
      # @param clock [#call] wall clock (Time) for $unixtime and the spell timer
      # @param write_clock [WriteClock]
      # @param spell_timer [SpellTimer, nil] gets the active-spells window lines
      # @param listener [#call, nil] callable(names) with the variable changes of one row or send,
      #   in order, never empty (see the class comment); also settable later ({#listener=})
      # @param display [#call, nil] callable(text, target) => what the window shows: nil when a gag
      #   hides it, else the substituted text ({StreamFilters#displayed}; Game.cs:3075-3103 R) --
      #   the main window's {#last_row_was_prompt} only sees what is shown; nil = shown as it is.
      #   Called with @mutex released (it may read these values back, and must not stall readers)
      # @param globals [GlobalStore, nil] where a typed send's $lastinput goes ({#sent})
      def initialize(config: DEFAULT_CONFIG, clock: -> { Time.now }, write_clock: WriteClock::SHARED, spell_timer: nil,
                     listener: nil, display: nil, globals: nil)
        @config = config
        @listener = listener
        @display = display
        @globals = globals
        @changes = [] # VariableChanged names of the critical section in progress
        @events = [] # the GameEvents of the row in progress
        @clock = clock
        @write_clock = write_clock
        @spell_timer = spell_timer
        @mutex = Mutex.new
        @write_mutex = Mutex.new # serializes the writers (see the class comment)
        @values = {}
        @stamps = {}
        @indicators = Hash.new(false) # m_oIndicatorHash (ResetIndicators: all false)
        @round_time = 0 # m_iRoundTime
        @round_time_end = nil # FormMain's Globals.RoundTimeEnd (nil = DateTime default, long past)
        @status_prompt = false # m_bStatusPromptEnabled
        @spell_time_start = nil # Globals.SpellTimeStart (nil = m_oBlankTimer)
        @target = :main # m_oTargetWindow; a String for WindowTarget.Other's name
        @bold = false # m_bBold: a field, so it outlives the row
        @familiar_line = false # m_bFamiliarLineParse
        @ignore_xml_depth = false # m_bIgnoreXMLDepth: a field, so it outlives the row
        @scanner = GameRow::Scanner.new
        @replayed = nil # identities of the rows {#seed} replayed, until the first live row
        @room_updated = false # AutoMapper m_RoomUpdated
        @last_row_was_prompt = false # m_bLastRowWasPrompt ({#last_row_was_prompt})
        # The capture start: Remix sets $game at connect (Game.cs:403, 422 R), after
        # variables.cfg was loaded at start-up, so a stored copy never shadows it.
        @start_stamp = @write_clock.tick
        @mapper_stamp = nil # the last automapper room update
        @host_readings = {} # name => [reading, stamp] for the :zone policy
        @host_pending = {} # name => a changed :zone reading awaiting the next room update
      end

      # @return [Config]
      attr_reader :config

      # Remix's socket text: the bytes decoded as UTF-8 (Encoding.Default in .NET 8, Connection.
      # cs:517, 882 R), an invalid sequence becoming U+FFFD -- so no game text handed to a
      # script or a #trigger makes Regexp#match raise on an invalid byte sequence.
      # @param row [String]
      # @return [String] +row+ itself when it already is valid UTF-8
      def self.decode(row)
        return row if row.encoding == Encoding::UTF_8 && row.valid_encoding?

        text = row.dup.force_encoding(Encoding::UTF_8)
        text.valid_encoding? ? text : text.scrub(REPLACEMENT_CHARACTER)
      end

      # U+FFFD (ASCII-only source).
      REPLACEMENT_CHARACTER = [0xFFFD].pack('U').freeze

      # FormMain.HasRoundTime (`DateTime.Now < Globals.RoundTimeEnd`, FormMain.cs:6918-6924 R): the
      # end is set when a prompt carries a roundtime (Game.cs:2369-2373 R) and never cleared, so
      # it simply lies in the past once the roundtime is over. The CommandQueue's RT gate.
      # @param now [Time] the wall clock reading to compare (default: this capture's clock)
      # @return [Boolean]
      def roundtime?(now = @clock.call)
        ends = @mutex.synchronize { @round_time_end }
        !ends.nil? && now < ends
      end

      # @return [#call, nil] gets each row's variable changes (an Array of names), outside the lock
      attr_accessor :listener

      # Feed one raw server string (one socket row, CRLF included). After a {#seed}, the
      # first live row skips itself if the replay already applied that very String (see
      # {#seed}); either way the replay's row list is dropped then.
      # @param row [String]
      # @return [void]
      def feed(row)
        changes = writing do
          replayed = @replayed
          @replayed = nil
          feed_row(row) unless replayed&.key?(row)
          Row.new(take_changes, take_events)
        end
        notify(changes)
      end

      # The glue's start-up: run the block (which installs the live feed and returns the
      # snapshot of Lich's server buffer) and replay the snapshot, all in ONE critical
      # section. A live row parsed meanwhile waits on the lock and lands after the replay,
      # never before it (where the older replay would overwrite it). Lich pushes a row
      # into its buffer before it hands that same String to the live feed (games.rb:1001,
      # 1136), and its one parser thread finishes a row before reading the next, so only
      # the snapshot's last row can still be on its way to the live feed: {#feed} skips
      # it by identity (String#equal?), so no row is applied twice.
      # @yieldreturn [Array<String>, nil] the snapshot, oldest first
      # @return [void]
      def seed
        writing do
          rows = Array(yield).grep(String)
          # compare_by_identity BEFORE the inserts: a content-keyed hash would keep only the
          # first of two equal rows, losing the identity of the one in flight.
          @replayed = {}.compare_by_identity
          rows.each { |row| @replayed[row] = true }
          rows.each { |row| feed_row(row) }
          take_changes # a replay raises no variable change
          take_events # nor a script-timing event
        end
      end

      # A runtime `#config key value` (Command.cs:1510-1524 R): Remix's Config changes at
      # once (Config.cs:895-922 R), so the next room objs/prompt reads the new value.
      # @param key [String]
      # @param value [String]
      # @return [Config]
      def apply_setting(key, value)
        writing { @config = Config.from_settings([[key.to_s, value.to_s]], base: @config) }
      end

      # The write stamp of a name the host computes, by the Remix writer it stands for:
      #   :connect -> $game, written at connect only (the capture start);
      #   :room    -> $roomid, written by the automapper on every room update
      #               (SetRoomVariables, AutoMapper.cs:851-877 R);
      #   :zone    -> $zoneid/$zonename, written when the automapper loads another map
      #               (AutoMapper.cs:1925-1933 R): the stamp of the room update at or before
      #               which +reading+ was first seen with its current value. Lich's map
      #               places the new room as soon as its title arrives, but Remix loads the
      #               map at the room update on the next prompt: a changed reading first
      #               seen in between keeps the old stamp until that room update, then takes
      #               its stamp ({#mapper_room_update}); one that reverts first is dropped.
      # @param name [String]
      # @param policy [Symbol]
      # @param reading [String, nil] the host's current value (for :zone)
      # @return [Integer, nil]
      def host_stamp(name, policy, reading = nil)
        @mutex.synchronize do
          room = @mapper_stamp || @start_stamp
          case policy
          when :connect then @start_stamp
          when :room then room
          when :zone then zone_stamp(name, reading, room)
          end
        end
      end

      # A command through Game.SendText (Game.cs:461-552 R): sets $lastcommand (and the $lastinput
      # global when the user typed it); "set !statusprompt" turns the status prompt off (Game.cs:477-480
      # R). Only a send whose "[origin]: text" echo is shown clears {#last_row_was_prompt}: a gag
      # matching the origin hides it (bHideOutput), and with it the whole PrintInputText block
      # (Game.cs:481-542 R). A {#my_command?} text is echoed only: no socket send,
      # no $lastinput, no $lastcommand (Game.cs:527, 545 R) -- the caller must not send it either.
      # @param text [String]
      # @param user_input [Boolean]
      # @param echoed [Boolean] false when a gag hid the send's echo ({StreamFilters#hides_echo_of?})
      # @return [void]
      def sent(text, user_input: false, echoed: true)
        changes = writing do
          mine = my_command?(text)
          @status_prompt = false if text.downcase == 'set !statusprompt'
          if echoed
            main_text(text) # its input echo (PrintInputText -> AddText bInput, Game.cs:541-542, 3227-3241 R)
            if user_input && !mine # VariableList["lastinput"] = sText, then "lastinput" -- no "$" (Game.cs:526-531 R)
              @globals&.assign('lastinput', text)
              changed('lastinput')
            end
          end
          put_changed('lastcommand', text, event: 'lastcommand') unless mine # no "$" (Game.cs:545-551 R)
          take_changes
        end
        notify(changes)
      end

      # Whether Game.SendText keeps +text+ off the socket: it starts with the mycommandchar
      # (sText.StartsWith(cMyCommandChar), Game.cs:467, 527, 545 R; '/' by default) -- the raw text,
      # no trim, so " /x" is a game command.
      # @param text [String]
      # @return [Boolean]
      def my_command?(text)
        char = @config.my_command_char.to_s
        !char.empty? && text.to_s.start_with?(char)
      end

      # A line the host printed to the main window outside the game stream -- a script's echo,
      # `#echo` with no window, an engine message (Remix: Script_EventPrintText / PrintError /
      # ClassCommand_EchoText -> AddText, FormMain.cs:4229-4270, 5611-5676 R). Only its effect on
      # {#last_row_was_prompt} is kept. The glue reports every line Lich echoes (respond), which
      # also covers Lich's own "--- Lich: x active." lines (Remix: "[Script loaded: ...]").
      # Takes the state lock only, never the writers' lock: Lich prints from threads
      # that hold locks of their own (Map's synchronize_load around `respond map_loaded_message`),
      # and a row holds the writers' lock across the display port, so waiting for it here could
      # close a lock cycle with the parser thread. The state lock is free while the port runs, and
      # a writer on this very thread (a plugin port) already holds it.
      # @param text [String]
      # @return [void]
      def printed(text)
        return main_text(text) if @mutex.owned? # from inside a writer (a plugin port) on this thread

        @mutex.synchronize { main_text(text) }
      end

      # The automapper plugin's VariableChanged for a change that did not come from the game
      # stream -- a script's or a #trigger body's `#var roomname x` / `#var prompt x`
      # (ClassCommand_EventVariableChanged -> SafeParsePluginVariable -> AutoMapper.VariableChanged,
      # FormMain.cs:5045-5050, 1455-1478 R; AutoMapper.cs:269-289 R): "roomname" arms the room
      # update, "prompt" runs it when armed ({#mapper_room_update}: "$roomid" raised). The game
      # rows' own "$roomname" / "$prompt" do the same inside {#feed}.
      # @param names [String, Array<String>] the raised names ("$roomname", "prompt", ...)
      # @return [void]
      def plugin_variable_changed(names)
        changes = writing do
          Array(names).each do |name|
            case name.to_s.delete_prefix('$')
            when 'roomname' then @room_updated = true
            when 'prompt' then mapper_room_update if @room_updated
            end
          end
          take_changes
        end
        notify(changes)
      end

      # m_bLastRowWasPrompt (Game.cs:196, 2397 R): whether the last row printed to the main window
      # was a prompt. FormMain.AddText sets it when a prompt is printed to main and clears it on
      # any other main text that is not blank (FormMain.cs:5100-5122 R): game text printed to the
      # main window, the echo of every send ({#sent}) and the host's own lines ({#printed}).
      # Fidelity: a display state, approximated -- the main window is the `main` target only (a
      # CLOSED window's text can fall back to main via its IfClosed setting, FormMain.cs:5231-5235
      # R, layout-dependent). A gagged line, or one substituted to blank, leaves it alone (the
      # +display+ port; Game.cs:3075-3103 R). Mirrored by genieflow's Host.
      # @return [Boolean]
      def last_row_was_prompt
        @mutex.synchronize { @last_row_was_prompt }
      end

      # @param name [String] exact case (Remix's variable list is case-sensitive)
      # @return [String, nil] the captured value, nil if the game never set it
      def [](name)
        @mutex.synchronize { @values[name] }
      end

      # @return [Array<String>] every name the capture has set (the game rows' VariableList.Add
      #   of a Reserved name -- incl. the ones Remix only creates when the game sends them,
      #   $uid, $lefthandid, $healthBarText ...)
      def names
        @mutex.synchronize { @values.keys }
      end

      # @param name [String]
      # @return [Integer, nil] the {WriteClock} stamp of the last game update of +name+
      def stamp(name)
        @mutex.synchronize { @stamps[name] }
      end

      # @return [Time, nil] Globals.SpellTimeStart: when the prepared spell was last
      #   (re)announced, nil when no spell is prepared
      def spell_time_start
        @mutex.synchronize { @spell_time_start }
      end

      private

      def put(name, value)
        @values[name] = value.to_s
        @stamps[name] = @write_clock.tick
      end

      # Record one VariableChanged (under the lock).
      def changed(name)
        @changes << name
      end

      # The common Game.cs shape: set a reserved variable, then raise "$name".
      def put_changed(name, value, event: "$#{name}")
        put(name, value)
        changed(event)
      end

      def take_changes
        changes = @changes
        @changes = []
        changes
      end

      def take_events
        events = @events
        @events = []
        events
      end

      # Hand the changes of one critical section to the listener as one batch (outside the lock;
      # one batch = one queued entry per script, VariableDispatch). A {Row} with events but no
      # change is handed over too (no Remix row raises one without the other today: a prompt
      # sets $gametime, a room desc $roomdesc).
      def notify(changes)
        listener = @listener
        return if listener.nil? || (changes.empty? && !(changes.is_a?(Row) && !changes.events.empty?))

        listener.call(changes)
      end

      def value(name, default)
        @values.fetch(name, default)
      end

      # ParseGameRow (Game.cs:567-889 R) for one row, decoded first like Remix's socket text
      # ({GameState.decode}).
      def feed_row(row)
        @row_text = +'' # sTextBuffer
        @row_aborted = false
        @combat_row = false # bCombatRow (Game.cs:579 R)
        has_xml = @scanner.scan(GameState.decode(row)) do |kind, payload|
          next if @row_aborted

          case kind
          when :xml then row_buffer(payload)
          when :xml_end then append_row_text(process_buffer(payload))
          else @row_text << payload
          end
        end
        row_end(has_xml) unless @row_aborted
      end

      # The work after one complete XML buffer (Game.cs:620-724 R): ProcessXML (sTmp), then the
      # text buffered before the buffer is flushed to the stream it arrived in when the buffer
      # changed the target (FlushRowTextTo), a roomDesc preset's text is printed on its own
      # (Game.cs:661-693 R), and bold text starting "< " / "> " / "* " is printed on its own
      # before the buffer's text joins the row (the combat-row split, Game.cs:705-719 R).
      def row_buffer(buffer)
        before = @target
        text = process_buffer(buffer)
        return if @row_aborted

        if !@row_text.empty? && @target != before
          print_text(@row_text, before)
          @row_text = +''
        end
        if buffer.end_with?('</preset>') && preset_label(buffer) == 'roomdesc'
          print_text(text, @target)
          text = ''
        end
        if @bold && !@config.condensed && @row_text.start_with?('< ', '> ', '* ')
          print_text("#{@row_text}\r\n", @target)
          @row_text = +''
          @combat_row = true
        end
        append_row_text(text)
      end

      # @param text [String, nil] a buffer's ProcessXML text (nil when it threw)
      def append_row_text(text)
        @row_text << text if text
      end

      # The preset id ParseGameRow reads with an XmlReader (the first <preset> element of the
      # buffer, lowercased; "whisper"/"thought" renamed, which never equals "roomdesc").
      def preset_label(buffer)
        match = buffer.match(PRESET_ID)
        match ? (match[1] || match[2]).downcase : ''
      end

      # The id attribute of a buffer's first <preset> element.
      PRESET_ID = /<preset\s(?:[^>]*?\s)?id\s*=\s*(?:'([^']*)'|"([^"]*)")/.freeze

      # Row end (Game.cs:852-889 R): the familiar-stream fix-up, then the row's text printed
      # to the current target (a lone CRLF after markup is not).
      def row_end(has_xml)
        return if @row_text.empty?

        if @familiar_line
          if @target.is_a?(String) # WindowTarget.Other
            @row_text = +''
          else
            @target = :familiar if @target == :main
            @familiar_line = false
          end
        end
        print_text(@row_text, @target) unless @row_text == "\r\n" && has_xml
        # a combat-split row leaves the bold flag off (Game.cs:856-859, 893-896 R: m_bBold true for
        # the row's own print, then false) -- a later row is not split on a bold
        # its own text never opened
        @bold = false if @combat_row
      end

      # ProcessXML (Game.cs:899-967 R) for one buffer. A .NET exception inside it (int.Parse
      # of a bad progressBar/roundTime value, String.Replace("") with a blank prompt
      # setting) leaves ParseGameRow, so the rest of the row is not parsed; what the
      # element set before the throw stays set. (Remix never clears m_oXMLBuffer after the
      # throw, Game.cs:625-726 R, so its parser stays frozen for the session; decided: not
      # emulated.)
      def process_buffer(buffer)
        # EventParseXML follows ProcessXMLData and needs a parsable buffer; the only
        # buffer the SpellTimer reacts to (an exact percWindow clear) is both, and changes
        # no state here, so handing it over first is equivalent.
        plugin { |timer| timer.parse_xml(buffer) }
        # A pending m_bIgnoreXMLDepth is cleared by any buffer's first node with children.
        return unless @ignore_xml_depth || buffer.match?(INTEREST)

        root = GameRow::Fragment.parse(buffer)
        root ? process_children(root) : ''
      rescue ArgumentError, RangeError
        @row_aborted = true
        nil
      end

      # ProcessXMLData (Game.cs:2746-2785 R): each element, then its children -- unless it
      # is a <stream>, or m_bIgnoreXMLDepth is set: an unknown component sets it (Game.cs:
      # 1829 R) and the NEXT node with children clears it instead of descending. When the
      # unknown component itself is empty, that is a later element, even one in a later
      # row (`<component id='exp X'></component>` then `<compass><dir .../></compass>`:
      # the compass is reset and its dirs are skipped). Text nodes never have children.
      #
      # Returns the text it collects (sReturn): each element's own text ({#process_element}),
      # then its children's -- so the text of a text-bearing element nested in another one is
      # collected twice (`<preset id='x'>A <a>B</a></preset>` -> "A BB"), as in Remix.
      # @return [String]
      def process_children(node)
        text = +''
        node.elements.each do |element|
          text << process_element(element)
          next if element.name == 'stream' || element.children.empty?

          if @ignore_xml_depth
            @ignore_xml_depth = false
          else
            text << process_children(element)
          end
        end
        text
      end

      # ProcessXMLNodeElement (Game.cs:1341-2643 R).
      # @return [String] the element's display text: an <a>, <b> or <preset>'s InnerText, a
      #   <d>'s outside a component (`{text:cmd}` with `showlinks`); "" for every other element
      def process_element(node)
        case node.name
        when 'a', 'b', 'preset' then return node.inner_text
        when 'd' then return link_text(node)
        when 'pushBold' then @bold = true
        when 'popBold' then @bold = false
        when 'stream'
          # a thoughts <stream> prints its text to the thoughts window at once (Game.cs:1677-1685 R)
          print_text("#{node.inner_text}\r\n", :thoughts) if node.attr('id') == 'thoughts'
        when 'streamWindow' then room_title(node) if node.attr('id') == 'room'
        when 'component', 'compDef' then component(node)
        when 'progressBar' then progress_bar(node)
        when 'spell' then spell(node)
        when 'left', 'right' then hand(node)
        when 'app' then app(node)
        when 'indicator' then indicator(node)
        when 'roundTime' then @round_time = net_int(node.attr('value'))
        when 'castTime' then put_changed('casttime', node.attr('value'))
        when 'spelltime' then spell_start_time(node)
        when 'prompt' then prompt(node)
        when 'compass' then compass
        when 'dir' then compass_dir(node) if node.parent&.name == 'compass'
        when 'pushStream' then push_stream(node.attr('id'))
        when 'popStream' then @target = :main
        end
        ''
      end

      # <d> (Game.cs:1362-1381 R): nothing inside a component (room exits), else its text.
      def link_text(node)
        return '' if node.parent&.name == 'component'

        text = node.inner_text
        return text unless @config.show_links

        cmd = node.attr('cmd')
        "{#{text}:#{cmd.empty? ? text : cmd}}"
      end

      # pushStream (Game.cs:1563-1638 R): the new target; the familiar stream also arms the
      # familiar-line fix-up of the row end (m_bFamiliarLineParse).
      def push_stream(id)
        @target = stream_target(id)
        @familiar_line = true if id == 'familiar'
      end

      # <compass>: every direction cleared, then "compass" (Game.cs:2425-2473 R).
      def compass
        COMPASS.each_value { |dir| put(dir, '0') }
        changed('compass')
      end

      # <dir> inside <compass>: a known value sets its direction; "compass" is raised for any
      # value (Game.cs:2476-2591 R). FormMain drops "compass" before any dispatch
      # (VariableDispatch::BLOCKED).
      def compass_dir(node)
        value = node.attr('value')
        put(COMPASS[value], '1') if COMPASS.key?(value)
        changed('compass')
      end

      # Game.cs:1485-1521 R.
      def room_title(node)
        title = node.attr('subtitle')
        uid = '0'
        if (match = title.match(ROOM_NAME))
          title = match[:roomname]
          uid = match[:roomuid] || '0'
        else
          title = title[3..] if title.start_with?(' - ')
          title = title[1, title.length - 2] if title.start_with?('[')
          title = Text.net_trim(title)
        end
        put('roomname', title)
        changed('$roomname')
        put('uid', uid)
        changed('$uid')
        @room_updated = true # the automapper's VariableChanged("roomname")
      end

      # Game.cs:1757-1831 R.
      def component(node)
        case node.attr('id')
        when 'room desc'
          @events << GameEvents::MOVE # EventTriggerMove, before $roomdesc (Game.cs:1765 R)
          put('roomdesc', node.inner_text.delete('"'))
          changed('$roomdesc')
          %w[roomobjs roomplayers roomexits].each { |name| put(name, '') } # silently (Game.cs:1772-1780 R)
        when 'room objs'
          objects = Text.net_trim_start(node.inner_text)
          put('monstercount', count_monsters(node).to_s)
          changed('$monstercount')
          put('roomobjs', Text.net_trim_start(objects.delete('"')))
          changed('$roomobjs')
        when 'room players' then put_changed('roomplayers', node.inner_text.delete('"'))
        when 'room exits' then put_changed('roomexits', node.inner_text.delete('"'))
        else @ignore_xml_depth = true # skip any elements inside an unknown component
        end
      end

      # CountMonsters (Game.cs:2675-2718 R): bold names (+ the text up to the next ',' or
      # '.') from InnerXml with " and " read as ", "; the count skips names containing an
      # entry of the ignore list (an empty entry matches everything, like
      # String.Contains("")); $monsterlist lists the counted ones, ", "-joined and trimmed.
      def count_monsters(node)
        xml = node.inner_xml.gsub(' and ', ', ').gsub(' and <pushBold />', ', <pushBold />')
        ignore = @config.ignore_monster_list.split('|', -1)
        counted = xml.scan(MONSTER).map(&:join).reject { |name| ignore.any? { |entry| name.include?(entry) } }
        put('monsterlist', counted.map { |name| Text.net_trim(name) }.join(', '))
        changed('monsterlist') # no "$" (Game.cs:2715-2716 R)
        counted.length
      end

      # Game.cs:1835-1909 R: int.Parse(value); the text capitalized after every space.
      def progress_bar(node)
        value_name, text_name = BARS[node.attr('id')]
        return unless value_name

        put(value_name, net_int(node.attr('value')).to_s)
        put(text_name, bar_text(node.attr('text'))) if text_name
        changed("$#{value_name}")
      end

      def bar_text(text)
        previous = ' '
        text.each_char.map { |c| (previous == ' ' ? c.upcase : c).tap { previous = c } }.join
      end

      # Game.cs:1914-1938 R, FormMain.cs:6697-6707 R: a non-None spell (re)starts the timer
      # and stamps $spellstarttime with the local Unix time; None clears the timer.
      def spell(node)
        name = node.inner_text
        name = 'Unknown' if name == 'ScriptNumber'
        if name == 'None'
          @spell_time_start = nil
        else
          now = @clock.call
          @spell_time_start = now
          put('spellstarttime', now.to_i.to_s) # FormMain.SetSpellTime raises nothing (FormMain.cs:6697-6701 R)
        end
        put_changed('preparedspell', name)
      end

      # Game.cs:1940-1977 R: InnerText, noun and exist attributes ("" when absent).
      def hand(node)
        side = node.name == 'left' ? 'left' : 'right'
        put("#{side}hand", node.inner_text)
        put("#{side}handnoun", node.attr('noun'))
        put("#{side}handid", node.attr('exist'))
        %w[hand handnoun handid].each { |suffix| changed("$#{side}#{suffix}") }
      end

      # Game.cs:1983-2010 R.
      def app(node)
        character = node.attr('char')
        return if character.empty?

        put_changed('charactername', character)
        put_changed('gamename', node.attr('game').delete(': '))
      end

      # Game.cs:2014-2167 R.
      def indicator(node)
        name = INDICATORS[node.attr('id')]
        return unless name

        active = node.attr('visible') == 'y'
        @indicators[name] = active if INDICATOR_HASH.include?(name)
        put_changed(name, active ? '1' : '0')
      end

      # Game.cs:2213-2234 R.
      def spell_start_time(node)
        spell = value('preparedspell', 'None')
        put_changed('spellstarttime', spell == 'None' ? '0' : node.attr('value'))
      end

      # The prompt is printed to the current target (its WindowTarget is Unknown, Game.cs:2402-
      # 2404, 2929-2932 R), so it reaches TriggerParse unless that is Room/Inv (UNPARSED_TARGETS)
      # or, with `parsegameonly` (Config.cs:40 R), not Main.

      # Game.cs:2236-2416 R. The "> " rewrite and the prompt text printed with parse happen only
      # while the last row printed to the main window was not itself a prompt (Game.cs:2397 R,
      # {#last_row_was_prompt}); otherwise $prompt keeps the raw text and nothing is offered to
      # the #triggers and scripts -- TriggerPrompt still fires.
      def prompt(node)
        text = node.inner_text
        if @status_prompt
          joined_bleeding_fix(text)
        elsif text != '>'
          @status_prompt = true
          joined_bleeding_fix(text)
        elsif @indicators['dead']
          text += 'DEAD'
        elsif @config.prompt_force
          PROMPT_LETTERS.each { |name, letter| text += letter if @indicators[name] }
        end
        time = net_try_int(node.attr('time'))
        return if time.nil?

        put_changed('gametime', time.to_s)
        put_changed('unixtime', @clock.call.to_i.to_s)
        rt = @round_time - time
        if rt.positive?
          round_time_end(rt + @config.rt_offset)
          text += 'R' if !@status_prompt && @config.prompt_force
          put('roundtime', (((rt + rt_offset_int32 + (2**31)) % (2**32)) - (2**31)).to_s) # `rt +=`: unchecked Int32
          @round_time = 0
        else
          put('roundtime', '0')
        end
        changed('$roundtime')
        printed = nil
        if !@config.prompt.empty? && !@last_row_was_prompt
          marker = Text.net_trim(@config.prompt)
          raise ArgumentError, 'String cannot be of zero length.' if marker.empty? # String.Replace("")

          text = text.gsub(marker, '') + @config.prompt
          printed = text if prompt_parsed? # PrintTextWithParse (Game.cs:2404 R)
          @last_row_was_prompt = true if @target == :main # AddText(bPrompt) on the main window
        end
        put_changed('prompt', text)
        mapper_room_update if @room_updated
        @events << GameEvents::Prompt.new(printed) # EventTriggerPrompt (Game.cs:2411 R), its text after
      end

      # Game.SetRoundTime -> FormMain.SetRoundTime (FormMain.cs:6927-6954 R): every listed
      # script's SetRoundTime, then RoundTimeEnd = Now + rt + RTOffset (the double offset, not the
      # $roundtime Int32 one), each DateTime.Now.AddMilliseconds(+seconds+ * 1000) (Script.cs:1007,
      # FormMain.cs:6953 R). Where that throws (an infinite / huge offset; 0 corpus) the first
      # one does, Game_EventRoundtime's catch shows an exception dialog (FormMain.cs:6739-6742 R;
      # not ported) and no end changes; a NaN is 0 ticks, so the end is now. Both read the one
      # injected wall clock (never a Time.now of its own), as both read Remix's DateTime.Now.
      # @param seconds [Float]
      # @return [void]
      def round_time_end(seconds)
        now = @clock.call
        return if Numeric.add_milliseconds_fault(seconds * 1000, now: now)

        seconds = 0.0 if seconds.nan?
        @round_time_end = now + seconds
        @events << GameEvents::RoundTime.new(seconds)
      end

      # Convert.ToInt32(Config.dRTOffset) (Game.cs:2376 R): half-to-even, and an OverflowException
      # for NaN, an infinity or a value past Int32 -- which ends the row ({#process_buffer}).
      # @return [Integer]
      # @raise [RangeError]
      def rt_offset_int32
        VbConversions.double_to_integer(@config.rt_offset.to_f)
      rescue Error => e
        raise RangeError, e.message
      end

      # @return [Boolean] whether text printed to the current target reaches TriggerParse
      def prompt_parsed?
        !UNPARSED_TARGETS.include?(@target) && (!@config.parse_game_only || @target == :main)
      end

      # The automapper's room update on the first prompt after a room title
      # (AutoMapper.cs:269-278, 361-394 R): it rewrites $roomid there and raises "$roomid" --
      # ClassCommand_EventVariableChanged runs TriggerVariableChanged("$prompt") and THEN the
      # plugins (SafeParsePluginVariable, FormMain.cs:5045-5050 R) -> AutoMapper.VariableChanged
      # -> UpdateCurrentRoom -> SetRoomVariables' set_GlobalVariable("roomid") (AutoMapper.cs:
      # 851-888, 2003-2009 R), found or not ("0"), so right after "$prompt". Its "$roomnote",
      # "$roomcolor", "$<dir>id" and "$roomportals" are not raised: the engine does not model
      # those variables.
      def mapper_room_update
        changed('$roomid')
        @room_updated = false
        @mapper_stamp = @write_clock.tick
        @host_pending.each { |name, reading| @host_readings[name] = [reading, @mapper_stamp] }
        @host_pending.clear
      end

      # The :zone policy of {#host_stamp} (under the lock).
      def zone_stamp(name, reading, room)
        entry = @host_readings[name]
        if entry.nil? || (entry[0] != reading && !@room_updated)
          @host_pending.delete(name)
          entry = @host_readings[name] = [reading, room]
        elsif entry[0] == reading
          @host_pending.delete(name)
        else
          @host_pending[name] = reading # the map load happens at the room update
        end
        entry[1]
      end

      # "Fix for Joined and Bleeding" (Game.cs:2250-2272, 2329-2353 R).
      def joined_bleeding_fix(text)
        put_changed('joined', '0') if !text.include?('J') && @values['joined'] == '1'
        put_changed('bleeding', '0') if !text.include?('!') && @values['bleeding'] == '1'
      end

      # pushStream (Game.cs:1563-1638 R): the WindowTarget a stream id selects.
      def stream_target(id)
        case id
        when 'combat', 'main', 'inv', 'familiar', 'thoughts', 'logons', 'death', 'room', 'debug' then id.to_sym
        when 'percWindow' then :percwindow
        else id
        end
      end

      # PrintTextWithParse -> PrintTextToWindow (Game.cs:2808-2933, 2961-3069 R) for what the
      # engine keeps of it: nothing for a Trim()-blank text (so `condensed`'s blank-line skip,
      # Game.cs:2963 R, never matters here); a room look's "  You also see" row TrimStart()ed;
      # the main-window bookkeeping ({#main_text}); the plugin hand-off (the window name the
      # plugin sees; only the active-spells window matters to the plugins we port); and the
      # TriggerParse line ({GameEvents::TextLine}): Utility.Trim(text) when the target is not
      # Room/Inv/Log (no stream selects Log) and, with `parsegameonly`, is Main.
      def print_text(text, target)
        return if Text.net_trim(text).empty? # PrintTextWithParse prints nothing blank (Game.cs:2811 R)

        # the "  You also see" row of a room look: a blank line printed first, then the text
        # TrimStart()ed (Game.cs:2813-2817 R)
        text = Text.net_trim_start(text) if text.start_with?('  You also see')
        displayed_main(text) if target == :main

        window = target.is_a?(String) ? target.downcase : target.to_s
        plugin { |timer| timer.parse_text(text, window) }
        return if UNPARSED_TARGETS.include?(target)
        return if @config.parse_game_only && target != :main

        @events << GameEvents::TextLine.new(Text.trim_crlf(text))
      end

      # The windows whose text never reaches TriggerParse (Game.cs:3062-3069 R).
      UNPARSED_TARGETS = %i[room inv].freeze

      # The main window's share of PrintTextToWindow after TriggerParse (Game.cs:3075-3103 R): a
      # gagged text never reaches AddText, a substituted one reaches it as substituted ({#main_text}).
      def displayed_main(text)
        shown = @display ? unlocked { @display.call(text, :main) } : text
        main_text(shown) unless shown.nil?
      rescue StandardError # a display filter fault must not break the row's capture
        main_text(text)
      end

      # A writer's critical section: @write_mutex, then @mutex (see the class comment). Re-entered
      # on the same thread -- only possible from inside the display port, which runs between the
      # row's steps -- it runs without taking @write_mutex again rather than raising on Lich's
      # parser thread.
      def writing(&)
        return @mutex.synchronize(&) if @write_mutex.owned?

        @write_mutex.synchronize { @mutex.synchronize(&) }
      end

      # Run the block with @mutex released (taken again after, also on an exception). Only
      # called inside a writer, so @write_mutex keeps every other writer out meanwhile.
      def unlocked
        return yield unless @mutex.owned?

        @mutex.unlock
        begin
          yield
        ensure
          @mutex.lock
        end
      end

      # FormMain.AddText's main-window bookkeeping (FormMain.cs:5100-5122 R): any non-prompt text
      # that is not blank after Trim clears {#last_row_was_prompt} (under the lock).
      def main_text(text)
        @last_row_was_prompt = false unless Text.net_trim(text.to_s).empty?
      end

      # A plugin that throws is disabled for the rest of the session (ParsePluginText's
      # catch sets Enabled = false, Game.cs:3396-3400 R). The plugin's `#var`s raise
      # "$<name>" each (its SendText -> Command `#var` -> VariableChanged, Command.cs:931-933
      # R), recorded with the row's other changes.
      def plugin
        return unless @spell_timer

        begin
          yield @spell_timer
        ensure
          @spell_timer.take_changes.each { |name| changed("$#{name}") } if @spell_timer.respond_to?(:take_changes)
        end
      rescue StandardError
        @spell_timer = nil
      end

      # int.Parse: raises like .NET on anything that is not an Int32.
      def net_int(text)
        net_try_int(text) || raise(ArgumentError, "Input string was not in a correct format: #{text.inspect}")
      end

      # int.TryParse (NumberStyles.Integer, en-US).
      def net_try_int(text)
        Numeric.net_int32(text)
      end
    end
  end
end
