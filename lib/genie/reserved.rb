# frozen_string_literal: true

module Lich
  module Genie
    # Pure, game-agnostic helpers for Genie's reserved variables, so the (Lich-coupled)
    # LichGameState resolver stays thin and this logic is unit-testable:
    #   * Remix's reserved-name list ({GENIE_RESERVED_NAMES}, never saved or loaded);
    #   * the EXPTracker ($<Skill>.Ranks ...) and TimeTracker ($Time.is...) plugin
    #     namespaces, bridged to Lich's DRSkill and moonwatch data;
    #   * the Lich status predicate for each indicator flag (the LichGameState fallback
    #     before the game-state capture has seen the indicator).
    #
    # $SpellTimer.* is no longer synthesized here: the SpellTimer plugin port
    # ({SpellTimer}) writes those variables into the store from the game stream.
    module Reserved
      # `$<Skill>.LearningRate` / `.Ranks` / `.Rank` / `.Percent` -- the Genie
      # EXPTracker plugin's per-skill variables. Genie uses underscores for spaces
      # ("Small_Edged"); we map them to the game's spaced names for the skill lookup.
      SKILL_VAR = /\A(?<skill>[A-Za-z][A-Za-z_]*)\.(?<field>learningrate|ranks?|percent)\z/i

      # `$Time.isDay` + `$Time.is<Moon>Up` -- the Genie TimeTracker plugin's day/night
      # and per-moon (Xibar/Yavash/Katamba) above-horizon flags. Bridged to Lich's
      # moonwatch data (UserVars.moons/sun) by LichGameState. These are the only four
      # $Time fields the corpus reads.
      TIME_VAR = /\ATime\.is(?:Day|(?<moon>Xibar|Yavash|Katamba)Up)\z/i

      # Genie flag name => Lich global status predicate. These work for both DR and
      # GS (unlike XMLData.indicator, which DR does not populate).
      INDICATOR_CHECKS = {
        'bleeding'  => :checkbleeding,
        'dead'      => :checkdead,
        'hidden'    => :checkhidden,
        'invisible' => :checkinvisible,
        'kneeling'  => :checkkneeling,
        'prone'     => :checkprone,
        'sitting'   => :checksitting,
        'standing'  => :checkstanding,
        'stunned'   => :checkstunned,
        'webbed'    => :checkwebbed,
        'joined'    => :checkgrouped,
        'poisoned'  => :checkpoison,
        'diseased'  => :checkdisease
      }.freeze

      # Remix's reserved (game-maintained) globals: SetDefaultGlobalVars
      # (Globals.cs:825-919 R) plus the names Game.cs adds as VariableType.Reserved
      # (uid 1517-1518, the *BarText vitals 1854-1888, lefthandid/righthandid
      # 1950-1972 R). Keys are case-sensitive, as in Remix's SortedList: the tester's
      # variables.cfg holds a user `CastTimeRemaining` next to the reserved
      # `casttimeremaining`.
      #
      # Our store never writes these to variables.cfg and never loads them from it
      # (see {GlobalStore}): their values come from live game state, which in Remix
      # overwrites a loaded copy on the next game update (Game.cs Add(..., Reserved)).
      GENIE_RESERVED_NAMES = %w[
        north northeast east southeast south southwest west northwest up down out
        roomname roomdesc roomobjs roomplayers roomexits roomnote
        concentration encumbrance health mana spirit stamina
        charactername account gamename gamehost gameport
        scriptdir mapdir plugindir logdir artdir sounddir
        kneeling prone sitting standing stunned hidden invisible dead joined bleeding webbed
        roundtime preparedspell lefthand lefthandnoun righthand righthandnoun gametime
        poisoned diseased connected client version
        time time24 militarytime date year month dayofmonth dayofyear datetime datetime24
        unixtime spelltime spellpreptime spellstarttime casttime casttimeremaining
        monstercount monsterlist prompt lastcommand zoneid zonename scriptlist repeatregex
        uid lefthandid righthandid
        healthBarText manaBarText spiritBarText staminaBarText concentrationBarText
      ].to_h { |name| [name, true] }.freeze

      module_function

      # @param name [String]
      # @return [Boolean] whether +name+ is one of Remix's reserved globals (exact case)
      def genie_reserved?(name)
        GENIE_RESERVED_NAMES.key?(name.to_s)
      end

      # @param name [String]
      # @return [Boolean] whether +name+ is a $<Skill>.<field> (EXPTracker) reference
      def skill_var?(name)
        name.to_s.match?(SKILL_VAR)
      end

      # Resolve a $<Skill>.LearningRate/.Ranks/.Percent reference (Genie EXPTracker)
      # against a skills provider (e.g. DR's DRSkill: getxp = mindstate/learning rate,
      # getrank = ranks, getpercent = % to next rank). Genie underscores map to spaces.
      #
      # @param name [String] e.g. "Small_Edged.LearningRate"
      # @param skills [#getxp, #getrank, #getpercent]
      # @return [Integer, nil] the value, or nil if +name+ isn't a skill reference
      def skill_var(name, skills:)
        match = name.to_s.match(SKILL_VAR)
        return nil unless match

        skill = match[:skill].tr('_', ' ')
        case match[:field].downcase
        when 'learningrate' then skills.getxp(skill)
        when 'rank', 'ranks' then skills.getrank(skill)
        when 'percent' then skills.getpercent(skill)
        end
      end

      # @param name [String]
      # @return [Boolean] whether +name+ is a $Time.is* (TimeTracker) reference
      def time_var?(name)
        name.to_s.match?(TIME_VAR)
      end

      # Resolve a $Time.isDay / $Time.is<Moon>Up reference (Genie TimeTracker) from
      # moonwatch data. Returns nil when the data is unavailable (moonwatch not run /
      # not DR) so the caller falls back to any stored #var -- some scripts self-populate
      # $Time.* from `observe` output when no plugin/data is present.
      #
      # @param name [String] e.g. "Time.isXibarUp"
      # @param visible_moons [Array<String>, nil] moon names above the horizon
      #   (UserVars.moons['visible']); nil = no data
      # @param day [Boolean, nil] whether it is daytime (UserVars.sun['day']); nil = no data
      # @return [Integer, nil] 1/0, or nil if not a match / data unavailable
      def time_var(name, visible_moons:, day:)
        match = name.to_s.match(TIME_VAR)
        return nil unless match

        if match[:moon]
          return nil if visible_moons.nil?

          Array(visible_moons).map { |moon| moon.to_s.downcase }.include?(match[:moon].downcase) ? 1 : 0
        else
          day.nil? ? nil : (day ? 1 : 0)
        end
      end

      # @param name [String] exact case (Remix's variable names are case-sensitive)
      # @return [Symbol, nil] the Lich status-predicate method for a flag, or nil
      def indicator_check(name)
        INDICATOR_CHECKS[name.to_s]
      end
    end
  end
end
