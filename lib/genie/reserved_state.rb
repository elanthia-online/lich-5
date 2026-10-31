# frozen_string_literal: true

module Lich
  module Genie
    # Resolves Remix's reserved globals for {Variables} (the `game_state` port), in Remix's
    # exact case (its variable list is a case-sensitive SortedList, Globals.cs:547 R):
    #
    #   1. the value {GameState} captured from the game stream, if any;
    #   2. else the host's value for that name, when it has one: the Lich glue computes
    #      the automapper's $roomid/$zoneid and the script list, and maps a few names to
    #      Lich state for the time before the capture saw them (vitals, hands, ...);
    #   3. else the value Remix starts with (SetDefaultGlobalVars, Globals.cs:825-919 R),
    #      with the host's statics (client, version, connected, ...) layered on top.
    #
    # A name Remix only creates when the game first sends it ($uid, $lefthandid,
    # $healthBarText, ...) is undefined until captured, as in Remix.
    #
    # A host value stands for a Remix writer ($roomid: the automapper on every room update;
    # $zoneid/$zonename: the automapper on a map load; $game: the connect), so it carries
    # that writer's stamp ({GameState#host_stamp}): a copy in variables.cfg or a script's
    # `#var` is overridden by the next such write and not before, as in Remix.
    #
    # The `@x@` defaults ($time, $spelltime, $scriptdir, ...) are returned as the literal
    # special; the substitution's @-pass then expands it ({Specials}), exactly as Remix
    # stores "@time@" and ParseSpecialVariables expands it (Globals.cs:206-244 R).
    # $unixtime is the special until the first prompt, then the per-prompt snapshot
    # (Game.cs:2366-2369 R).
    class ReservedState
      DEFAULTS = {
        'roomname' => '', 'roomdesc' => '', 'roomobjs' => '', 'roomplayers' => '', 'roomexits' => '', 'roomnote' => '',
        'concentration' => '100', 'encumbrance' => '0', 'health' => '100', 'mana' => '100', 'spirit' => '100', 'stamina' => '100',
        'charactername' => '', 'account' => '', 'gamename' => '', 'gamehost' => 'eaccess.play.net', 'gameport' => '7910',
        'roundtime' => '0', 'preparedspell' => 'None', 'lefthand' => 'Empty', 'lefthandnoun' => '', 'righthand' => 'Empty',
        'righthandnoun' => '', 'gametime' => '0', 'connected' => '0',
        'spellstarttime' => '0', 'casttime' => '0', 'monstercount' => '0', 'monsterlist' => '', 'prompt' => '',
        'lastcommand' => '', 'zoneid' => '0', 'zonename' => '0', 'scriptlist' => 'none',
        'repeatregex' => "^\\.\\.\\.wait|^Sorry\\, you may only type ahead|^You are still stunned|^You can\\'t do that while|^You don\\'t seem to be able"
      }.merge(
        GameState::COMPASS.values.to_h { |dir| [dir, '0'] },
        GameState::INDICATORS.values.to_h { |flag| [flag, '0'] },
        %w[scriptdir mapdir plugindir logdir artdir sounddir time time24 militarytime date year month dayofmonth dayofyear
           datetime datetime24 unixtime spelltime spellpreptime casttimeremaining].to_h { |name| [name, "@#{name}@"] }
      ).freeze

      # Remix's own build identity (Globals.cs:890-891 R: Application.Info.ProductName and
      # Version; Genie4.csproj <Product>Genie Remix Client 4</Product>, VersionPrefix 4.2.4).
      CLIENT = 'Genie Remix Client 4'
      VERSION = '4.2.4.0'

      # The host-computed names and the Remix writer each stands for ({GameState#host_stamp}):
      # $roomid the automapper's room update (AutoMapper.cs:851-877 R), $zoneid/$zonename its
      # map load (AutoMapper.cs:1925-1933 R), $game the connect (Game.cs:403, 422 R).
      HOST_STAMPS = { 'roomid' => :room, 'zoneid' => :zone, 'zonename' => :zone, 'game' => :connect }.freeze

      # @param game_state [GameState]
      # @param statics [Hash{String=>String}] fixed overrides of {DEFAULTS}
      # @param host [Hash{String=>#call}] host values (a nil result falls through to the
      #   default)
      # @param host_stamps [Hash{String=>Symbol}] name => {GameState#host_stamp} policy for
      #   the host values that stand for a Remix writer
      def initialize(game_state:, statics: {}, host: {}, host_stamps: {})
        @game_state = game_state
        @defaults = DEFAULTS.merge('client' => CLIENT, 'version' => VERSION).merge(statics).freeze
        @host = host
        @host_stamps = host_stamps
      end

      # @return [GameState]
      attr_reader :game_state

      # @param name [String]
      # @return [String, nil]
      def [](name)
        key = name.to_s
        captured = @game_state[key]
        return captured unless captured.nil?

        value = host_value(key)
        value.nil? ? @defaults[key] : value
      end

      # @param name [String]
      # @return [Boolean]
      def key?(name)
        !self[name].nil?
      end

      # The names Remix's variable list holds as VariableType.Reserved (ListVariables' "(reserved)"
      # section, Command.cs:3041-3051 R): SetDefaultGlobalVars' (Globals.cs:825-919 R), the ones
      # the game has created since ({GameState#names}) and the host-computed ones that have a
      # value now.
      # @return [Array<String>]
      def names
        (@defaults.keys + @game_state.names + @host.keys.reject { |key| host_value(key).nil? }).uniq
      end

      # @param name [String]
      # @return [Integer, nil] when the game (or the Remix writer a host value stands for)
      #   last wrote +name+ (see {WriteClock})
      def stamp(name)
        key = name.to_s
        captured = @game_state.stamp(key)
        return captured unless captured.nil?

        policy = @host_stamps[key]
        policy && @game_state.host_stamp(key, policy, policy == :zone ? host_value(key) : nil)
      end

      # Called before a script writes +name+ (Variables#global_set): a :zone host value
      # notes its current reading then (the other policies read no host value), so a zone change before the write never counts
      # as newer than the write (the change detection is lazy: Lich's map is read on a
      # script thread, never on the parser thread).
      # @param name [String]
      # @return [void]
      def observe(name)
        stamp(name) if @host_stamps[name.to_s] == :zone
      end

      # A runtime `#config key value` ({GameState#apply_setting}).
      # @param key [String]
      # @param value [String]
      # @return [void]
      def apply_setting(key, value)
        @game_state.apply_setting(key, value)
      end

      # @return [GameState::Config] the live settings ({GameState#config}): the ParseCommand
      #   characters and the ParseAction separator are read from here
      def config
        @game_state.config
      end

      # @return [Boolean] see {GameState#roundtime?}
      def roundtime?
        @game_state.roundtime?
      end

      # @return [Time, nil] see {GameState#spell_time_start}
      def spell_time_start
        @game_state.spell_time_start
      end

      private

      # A host lookup that raises (Lich state mid-reset) counts as "no value".
      def host_value(key)
        provider = @host[key]
        provider&.call&.to_s
      rescue StandardError
        nil
      end
    end

    # A reading that keeps its last non-empty value: Remix's automapper keeps its zone while
    # the character is in a room it cannot place (AutoMapper.cs:1925-1928 R, MapForm.cs:
    # 910-923 R), so $zoneid sticks to the last zone seen.
    class StickyValue
      def initialize
        @value = nil
      end

      # @param reading [Object, nil] the current reading (nil/empty = unknown)
      # @return [String, nil] the last known value
      def update(reading)
        @value = reading.to_s unless reading.nil? || reading.to_s.empty?
        @value
      end
    end

    # The last value each host provider returned. The display port ParseGlobalVars a
    # substitute's replacement on Lich's parser thread, inside a game-state row: host code there
    # (Lich's Map, which loads under a lock whose holder prints through the game state) can close a
    # lock cycle with the parser thread. So the live resolvers record their host reads
    # ({#recording}) and the display port's resolver only replays them ({#replaying}): a
    # last-known value, never a host call. One small lock, never held across a provider.
    class HostReadings
      def initialize
        @mutex = Mutex.new
        @values = {}
      end

      # @param providers [Hash{String=>#call}]
      # @return [Hash{String=>Proc}] the same providers, each recording what it returns (a raise
      #   records nothing and propagates)
      def recording(providers)
        providers.to_h { |name, provider| [name, -> { record(name, provider.call) }] }
      end

      # @param names [Array<String>]
      # @return [Hash{String=>Proc}] providers answering the last recorded value (nil before any)
      def replaying(names)
        names.to_h { |name| [name, -> { self[name] }] }
      end

      # @param name [String]
      # @param value [Object, nil]
      # @return [Object, nil] +value+
      def record(name, value)
        @mutex.synchronize { @values[name] = value }
      end

      # @param name [String]
      # @return [Object, nil] the last recorded value
      def [](name)
        @mutex.synchronize { @values[name] }
      end
    end

    # The automapper's $zoneid/$zonename from the zone Lich's map stamps on the current room
    # -- both stick while the room is unmapped ({StickyValue}). Remix writes them when it
    # loads a map (AutoMapper.cs:1925-1933 R), and a map with an empty <zone name> keeps the
    # previous name (MapForm.cs:658-668 R); a zone with no Genie map (festival maps) loads
    # nothing in Remix, so for an id not in the table the previous name stays too.
    class ZoneTracker
      # @param names [Hash{String=>String}] zone id => name ({ZONE_NAMES})
      def initialize(names: ZONE_NAMES)
        @names = names
        @id = StickyValue.new
        @name = StickyValue.new
      end

      # @param reading [String, nil] the current room's zone (nil/empty: unmapped)
      # @return [String, nil] $zoneid (nil before any zone)
      def id(reading)
        @id.update(reading)
      end

      # @param reading [String, nil] as {#id}
      # @return [String, nil] $zonename (nil before any named zone)
      def name(reading)
        @name.update(@names[id(reading)])
      end
    end
  end
end
