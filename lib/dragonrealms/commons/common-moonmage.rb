# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRCMM
      module_function

      # Moon weapon detection regex. Matches summoned moon weapons in hand.
      # Colors: black (Katamba), red-hot (Yavash), blue-white (Xibar).
      MOON_WEAPON_REGEX = /^(?:black|red-hot|blue-white) moon(?:blade|staff)$/i.freeze

      # Canonical moon weapon base names for glance/hold operations.
      MOON_WEAPON_NAMES = ['moonblade', 'moonstaff'].freeze

      # Expected game messages when wearing a summoned moon weapon.
      MOON_WEAR_MESSAGES = ["You're already", "You can't wear", "Wear what", "telekinetic"].freeze

      # Expected game messages when dropping a summoned moon weapon.
      MOON_DROP_MESSAGES = ["As you open your hand", "What were you referring to"].freeze

      # Maps moon weapon color adjective to moon name.
      MOON_COLOR_TO_NAME = {
        'black'      => 'katamba',
        'red-hot'    => 'yavash',
        'blue-white' => 'xibar'
      }.freeze

      # Regex for extracting moon color from glance output.
      MOON_GLANCE_REGEX = /You glance at a .* (?<color>black|red-hot|blue-white) moon(?:blade|staff)/i.freeze

      # Regex for extracting the spelled-out remaining duration from FOCUSing a
      # moon weapon, e.g. "You judge that the moonblade will last for roughly
      # twenty-nine roisaen." The count is captured as words (a compound like
      # "twenty-nine" or a single word like "five"). The unit is "roisaen"
      # (plural) or "roisan" (singular, i.e. one); one roisaen == 60 seconds.
      MOON_FOCUS_DURATION_REGEX = /will last for roughly (?<count>[a-z][a-z-]*) roisae?n/i.freeze

      # Near expiry (under one roisaen remaining) FOCUS drops the "roughly <count>"
      # form entirely and reports "will last for less than one roisan" -- no
      # spelled count. moon_weapon_duration treats this as 0 roisaen (expiring now).
      MOON_FOCUS_EXPIRING_REGEX = /will last for less than one roisae?n/i.freeze

      # Maps divination tool keywords to their use verb.
      DIV_TOOL_VERBS = {
        'charts' => 'review',
        'bones'  => 'roll',
        'mirror' => 'gaze',
        'bowl'   => 'gaze',
        'prism'  => 'raise'
      }.freeze

      # Minimum minutes remaining before a celestial body sets to be considered "visible."
      MOON_VISIBILITY_TIMER_THRESHOLD = 4

      # The moons moonwatch publishes in UserVars.moons, each with a 'timer'.
      MOON_NAMES = %w[katamba yavash xibar].freeze

      # Seconds check_moonwatch waits, after starting moonwatch, for it to
      # publish real moon data (and, separately, for another caller's start of
      # moonwatch to finish).
      MOONWATCH_READY_TIMEOUT = 10

      # Seconds between polls while check_moonwatch waits for moonwatch.
      MOONWATCH_POLL_INTERVAL = 0.1

      # Serializes check_moonwatch's not-running -> reset -> start sequence so two
      # callers never both start moonwatch, and a late caller never wipes data a
      # freshly started moonwatch has already published.
      MOONWATCH_START_LOCK = Mutex.new

      # Set when check_moonwatch gave up waiting for a running moonwatch's data
      # (see await_running_moonwatch).
      @moonwatch_data_stalled = false

      # Expected game responses when centering a telescope on a target.
      CENTER_TELESCOPE_MESSAGES = [
        'Center what',
        'You put your eye',
        'open it to make any use of it',
        'The pain is too much',
        "That's a bit tough to do when you can't see the sky",
        "You would probably need a periscope to do that",
        'Your search for',
        'Your vision is too fuzzy',
        "You'll need to open it to make any use of it",
        'You must have both hands free'
      ].freeze

      # Expected game responses when observing celestial bodies.
      # Used by `observe` method to match bput responses.
      # Patterns validated via in-game testing with test_observe_comprehensive.lic
      # Note: Roundtime is intentionally NOT included - every observation that produces
      # a Roundtime also produces a more specific pattern that matches first.
      OBSERVE_MESSAGES = [
        'Your search for',                           # Covers: fruitless, foiled by daylight/darkness
        'You see nothing regarding the future',      # No vision available
        'Clouds obscure',                            # Weather blocking
        'The following heavenly bodies are visible:', # Observe heavens listing
        "That's a bit hard to do while inside",      # Indoor blocking
        'too close to the sun',                      # Planet visibility (solar conjunction)
        'too faint for you to pick out',             # Requires telescope
        'You learn nothing of the future',           # Circle too low for body
        'below the horizon',                         # Body not visible
        'You have not pondered',                     # Observation cooldown
        'You are unable to make use',                # Cooldown followup
        'While the sighting',                        # Partial success
        'You learned something useful'               # Full success
      ].freeze

      def observe(thing)
        output = "observe #{thing} in heavens"
        output = 'observe heavens' if thing.eql?('heavens')
        DRC.bput(output.to_s, *OBSERVE_MESSAGES)
      end

      def predict(thing)
        output = "predict #{thing}"
        output = 'predict state all' if thing.eql?('all')
        DRC.bput(output.to_s, 'You predict that', 'You are far too', 'you lack the skill to grasp them fully', /(R|r)oundtime/i, 'You focus inwardly')
      end

      def study_sky
        DRC.bput('study sky', 'You feel a lingering sense', 'You feel it is too soon', 'Roundtime', 'You are unable to sense additional information', 'detect any portents')
      end

      def get_telescope?(telescope_name = 'telescope', storage)
        return true if DRCI.in_hands?(telescope_name)

        if storage['tied']
          DRCI.untie_item?(telescope_name, storage['tied'])
        elsif storage['container']
          unless DRCI.get_item?(telescope_name, storage['container'])
            Lich::Messaging.msg("plain", "DRCMM: Telescope not found in container. Trying to get it from anywhere we can.")
            return DRCI.get_item?(telescope_name)
          end
          true
        else
          DRCI.get_item?(telescope_name)
        end
      end

      def store_telescope?(telescope_name = "telescope", storage)
        return true unless DRCI.in_hands?(telescope_name)

        if storage['tied']
          DRCI.tie_item?(telescope_name, storage['tied'])
        elsif storage['container']
          DRCI.put_away_item?(telescope_name, storage['container'])
        else
          DRCI.put_away_item?(telescope_name)
        end
      end

      # @deprecated Use get_telescope? instead
      def get_telescope(storage)
        return if get_telescope?('telescope', storage)

        Lich::Messaging.msg('bold', 'DRCMM: Failed to get telescope.')
      end

      # @deprecated Use store_telescope? instead
      def store_telescope(storage)
        return if store_telescope?('telescope', storage)

        Lich::Messaging.msg('bold', 'DRCMM: Failed to store telescope.')
      end

      def peer_telescope
        telescope_regex_patterns = Regexp.union(
          /The pain is too much/,
          /You see nothing regarding the future/,
          /You believe you've learned all that you can about/,
          Regexp.union(get_data('constellations').observe_finished_messages),
          /open it/,
          /Your vision is too fuzzy/,
        )
        Lich::Util.issue_command("peer my telescope", telescope_regex_patterns, /Roundtime: /, usexml: false)
      end

      def center_telescope(target)
        case DRC.bput("center telescope on #{target}", *CENTER_TELESCOPE_MESSAGES)
        when 'The pain is too much', "That's a bit tough to do when you can't see the sky"
          Lich::Messaging.msg("bold", "DRCMM: Planet #{target} not visible. Are you indoors perhaps?")
        when "You'll need to open it to make any use of it"
          fput("open my telescope")
          fput("center telescope on #{target}")
        end
      end

      def align(skill)
        DRC.bput("align #{skill}", 'You focus internally')
      end

      def get_bones?(storage)
        if storage['tied']
          DRCI.untie_item?("bones", storage['tied'])
        elsif storage['container']
          DRCI.get_item?("bones", storage['container'])
        else
          DRCI.get_item?("bones")
        end
      end

      def store_bones?(storage)
        if storage['tied']
          DRCI.tie_item?("bones", storage['tied'])
        elsif storage['container']
          DRCI.put_away_item?("bones", storage['container'])
        else
          DRCI.put_away_item?("bones")
        end
      end

      # @deprecated Use get_bones? instead
      def get_bones(storage)
        return if get_bones?(storage)

        Lich::Messaging.msg('bold', 'DRCMM: Failed to get bones.')
      end

      # @deprecated Use store_bones? instead
      def store_bones(storage)
        return if store_bones?(storage)

        Lich::Messaging.msg('bold', 'DRCMM: Failed to store bones.')
      end

      def roll_bones(storage)
        unless get_bones?(storage)
          Lich::Messaging.msg('bold', 'DRCMM: Failed to get bones, aborting roll_bones.')
          return
        end

        DRC.bput('roll my bones', 'roundtime')
        waitrt?

        Lich::Messaging.msg('bold', 'DRCMM: Failed to store bones after rolling.') unless store_bones?(storage)
      end

      def get_div_tool?(tool)
        if tool['tied']
          DRCI.untie_item?(tool['name'], tool['container'])
        elsif tool['worn']
          DRCI.remove_item?(tool['name'])
        else
          DRCI.get_item?(tool['name'], tool['container'])
        end
      end

      def store_div_tool?(tool)
        if tool['tied']
          DRCI.tie_item?(tool['name'], tool['container'])
        elsif tool['worn']
          DRCI.wear_item?(tool['name'])
        else
          DRCI.put_away_item?(tool['name'], tool['container'])
        end
      end

      # @deprecated Use get_div_tool? instead
      def get_div_tool(tool)
        return if get_div_tool?(tool)

        Lich::Messaging.msg('bold', "DRCMM: Failed to get divination tool '#{tool['name']}'.")
      end

      # @deprecated Use store_div_tool? instead
      def store_div_tool(tool)
        return if store_div_tool?(tool)

        Lich::Messaging.msg('bold', "DRCMM: Failed to store divination tool '#{tool['name']}'.")
      end

      def use_div_tool(tool_storage)
        unless get_div_tool?(tool_storage)
          Lich::Messaging.msg('bold', "DRCMM: Failed to get divination tool '#{tool_storage['name']}', aborting use_div_tool.")
          return
        end

        DIV_TOOL_VERBS
          .select { |tool, _| tool_storage['name'].include?(tool) }
          .each   { |tool, verb| DRC.bput("#{verb} my #{tool}", 'roundtime'); waitrt? }

        unless store_div_tool?(tool_storage)
          Lich::Messaging.msg('bold', "DRCMM: Failed to store divination tool '#{tool_storage['name']}'.")
        end
      end

      # There are many variants of a summoned moon weapon (blade, staff, sword, etc)
      # This function checks if you're holding one then tries to wear it.
      # Returns true if what is in your hands is a summoned moon weapon that becomes worn.
      # Returns false if you're not holding a moon weapon, or you are but can't wear it.
      # https://elanthipedia.play.net/Shape_Moonblade
      def wear_moon_weapon?
        wore_it = false
        if is_moon_weapon?(DRC.left_hand)
          wore_it = wore_it || DRC.bput("wear #{DRC.left_hand}", *MOON_WEAR_MESSAGES) == "telekinetic"
        end
        if is_moon_weapon?(DRC.right_hand)
          wore_it = wore_it || DRC.bput("wear #{DRC.right_hand}", *MOON_WEAR_MESSAGES) == "telekinetic"
        end
        wore_it
      end

      # Drops the moon weapon in your hands, if any.
      # Returns true if dropped something, false otherwise.
      def drop_moon_weapon?
        dropped_it = false
        if is_moon_weapon?(DRC.left_hand)
          dropped_it = dropped_it || DRC.bput("drop #{DRC.left_hand}", *MOON_DROP_MESSAGES) == "As you open your hand"
        end
        if is_moon_weapon?(DRC.right_hand)
          dropped_it = dropped_it || DRC.bput("drop #{DRC.right_hand}", *MOON_DROP_MESSAGES) == "As you open your hand"
        end
        dropped_it
      end

      # Is a moon weapon in your hands?
      def holding_moon_weapon?
        is_moon_weapon?(DRC.left_hand) || is_moon_weapon?(DRC.right_hand)
      end

      # Try to hold a moon weapon.
      # If you end up not holding a moon weapon then returns false.
      def hold_moon_weapon?
        return true if holding_moon_weapon?
        return false if [DRC.left_hand, DRC.right_hand].compact.length >= 2

        MOON_WEAPON_NAMES.each do |weapon|
          glance = DRC.bput("glance my #{weapon}", "You glance at a .* #{weapon}", "I could not find")
          case glance
          when /You glance/
            return DRC.bput("hold my #{weapon}", "You grab", "You aren't wearing", "Hold hands with whom?", "You need a free hand") == "You grab"
          end
        end
        false
      end

      # Does the item appear to be a moon weapon?
      def is_moon_weapon?(item)
        return false unless item

        MOON_WEAPON_REGEX.match?(item)
      end

      def moon_used_to_summon_weapon
        # Note, if you have more than one weapon summoned at a time
        # then the results of this method are non-deterministic.
        # For example, if you have 2+ moonblades/staffs cast on different moons.
        MOON_WEAPON_NAMES.each do |weapon|
          glance = DRC.bput("glance my #{weapon}", MOON_GLANCE_REGEX, "I could not find")
          match = glance&.match(MOON_GLANCE_REGEX)
          return MOON_COLOR_TO_NAME[match[:color]] if match
        end
        nil
      end

      # Focuses the summoned moon weapon (moonblade/moonstaff) you are holding or
      # wearing and returns how many roisaen it will last: a positive Integer for
      # the "roughly <count> roisaen" form, 0 for the near-expiry "less than one
      # roisan" form, or nil if you have no moon weapon or the phrase could not be
      # parsed. One roisaen == 60 seconds; moonblade duration ranges 12-41 minutes.
      # https://elanthipedia.play.net/Moonblade
      #
      # NOTE: FOCUS incurs roundtime, so callers should not poll this every tick.
      def moon_weapon_duration
        MOON_WEAPON_NAMES.each do |weapon|
          result = DRC.bput("focus my #{weapon}", MOON_FOCUS_DURATION_REGEX, MOON_FOCUS_EXPIRING_REGEX, "I could not find", "Focus on what")

          # Near expiry FOCUS reports "less than one roisan" with no count; treat
          # as 0 roisaen (expiring now) so callers can refresh immediately.
          if result&.match?(MOON_FOCUS_EXPIRING_REGEX)
            waitrt?
            return 0
          end

          match = result&.match(MOON_FOCUS_DURATION_REGEX)
          next unless match

          waitrt?
          return parse_roisaen(match[:count])
        end
        nil
      end

      # Converts a spelled-out roisaen count (as reported by FOCUS, e.g. "five",
      # "twenty", "twenty-nine", "forty-one") into an Integer, or nil if any word
      # is not a recognized number. Compounds may be hyphen- or space-separated
      # and are summed ("forty-one" -> 41). Case-insensitive.
      #
      # Uses the global $NUM_MAP published by drinfomon/drvariables.rb (the same
      # number word map DRC.text2num uses) rather than the Lich::DragonRealms
      # constant, to avoid any namespace-resolution surface.
      def parse_roisaen(text)
        return nil if text.nil?
        return nil if $NUM_MAP.nil?

        words = text.downcase.tr('-', ' ').split
        return nil if words.empty?
        return nil unless words.all? { |word| $NUM_MAP.key?(word) }

        words.sum { |word| $NUM_MAP[word] }
      end

      def update_astral_data(data, settings = nil)
        if data['moon']
          data = set_moon_data(data)
        elsif data['stats']
          data = set_planet_data(data, settings)
        end
        data
      end

      def find_visible_planets(planets, settings = nil)
        unless get_telescope?(settings.telescope_name, settings.telescope_storage)
          Lich::Messaging.msg("bold", "DRCMM: Could not get telescope to find visible planets.")
          return
        end

        Flags.add('planet-not-visible', 'turns up fruitless')
        observed_planets = []

        begin
          planets.each do |planet|
            center_telescope(planet)
            observed_planets << planet unless Flags['planet-not-visible']
            Flags.reset('planet-not-visible')
          end
        ensure
          Flags.delete('planet-not-visible')
        end

        Lich::Messaging.msg("bold", "DRCMM: Could not store telescope after finding visible planets.") unless store_telescope?(settings.telescope_name, settings.telescope_storage)
        observed_planets
      end

      def set_planet_data(data, settings = nil)
        return data unless data['stats']

        planets = get_data('constellations')[:constellations].select { |planet| planet['stats'] }
        planet_names = planets.map { |planet| planet['name'] }
        visible_planets = find_visible_planets(planet_names, settings)
        data['stats'].each do |stat|
          cast_on = planets.map { |planet| planet['name'] if planet['stats'].include?(stat) && visible_planets.include?(planet['name']) }.compact.first
          next unless cast_on

          data['cast'] = "cast #{cast_on}"
          return data
        end
        Lich::Messaging.msg("bold", "DRCMM: Could not set planet data. Cannot cast #{data['abbrev']}.")
      end

      def set_moon_data(data)
        return data unless data['moon']

        moon = visible_moons.first
        if moon
          data['cast'] = "cast #{moon}"
        elsif data['name'].downcase == 'cage of light'
          data['cast'] = "cast ambient"
        else
          Lich::Messaging.msg("bold", "DRCMM: No moon available to cast #{data['name']}.")
          data = nil
        end
        data
      end

      # returns true if at least one bright moon (yavash, xibar) or the sun are
      #  above the horizon and won't set for at least another ~4 minutes.
      def bright_celestial_object?
        check_moonwatch
        (UserVars.sun['day'] && UserVars.sun['timer'] >= MOON_VISIBILITY_TIMER_THRESHOLD) || moon_visible?('xibar') || moon_visible?('yavash')
      end

      # returns true if at least one moon (katamba, yavash, xibar) or the sun are
      #  above the horizon and won't set for at least another ~4 minutes.
      def any_celestial_object?
        check_moonwatch
        (UserVars.sun['day'] && UserVars.sun['timer'] >= MOON_VISIBILITY_TIMER_THRESHOLD) || moons_visible?
      end

      # Returns true if at least one moon (e.g. katamba, yavash, xibar)
      # is above the horizon and won't set for at least another ~4 minutes.
      def moons_visible?
        !visible_moons.empty?
      end

      # Returns true if the moon is above the horizon and won't set for at least another ~4 minutes.
      def moon_visible?(moon_name)
        visible_moons.include?(moon_name)
      end

      # Returns list of moon names (e.g. katamba, yavash, xibar)
      # that are above the horizon and won't set for at least another ~4 minutes.
      def visible_moons
        check_moonwatch
        UserVars.moons.select { |moon_name, moon_data| UserVars.moons['visible'].include?(moon_name) && moon_data['timer'] >= MOON_VISIBILITY_TIMER_THRESHOLD }
                      .map { |moon_name, _moon_data| moon_name }
      end

      # Whether UserVars.moons holds real moon data: every moon has a numeric
      # 'timer' and 'visible' is a list. moonwatch first writes an empty
      # skeleton ({'katamba' => {}, ..., 'visible' => []}) and fills in the
      # timers afterwards, so the skeleton does not count as ready.
      #
      # moonwatch sets 'running' to false when it exits. UserVars persist
      # between sessions, so data marked that way is left over from a
      # moonwatch that has stopped and does not count as ready either. Data
      # without a 'running' key (older moonwatch versions) is judged by the
      # timers alone.
      #
      # @return [Boolean]
      def moon_data_ready?
        moons = UserVars.moons
        return false unless moons.is_a?(Hash) && moons['visible'].is_a?(Array)
        return false if moons['running'] == false

        MOON_NAMES.all? { |moon| moons[moon].is_a?(Hash) && moons[moon]['timer'].is_a?(Numeric) }
      end

      # Makes sure moonwatch is running, starting it if needed, and waits a
      # bounded time for it to publish real moon data (see moon_data_ready?).
      #
      # When moonwatch is running and the data is ready, this returns at once.
      # When moonwatch is running but the data is not ready yet (it was
      # started elsewhere, for example by autostart, and is still starting
      # up), this waits for the data. If that wait times out while moonwatch
      # keeps running, later calls return false at once instead of waiting
      # again, until the data becomes ready or moonwatch is seen stopped.
      # When another caller's start is in progress, it waits for that start
      # to finish (returning as soon as the data is ready). Otherwise it
      # clears the saved UserVars.moons (they may be stale), starts moonwatch
      # and waits until moon_data_ready? is true. The wait ends early, with a message,
      # when moonwatch cannot be found or stops before publishing, and ends
      # at the deadline when it never starts or never publishes. The saved
      # data is never restored on failure, so moon checks see no moon rather
      # than stale timers.
      #
      # A nil from start_script is not treated as a failure unless moonwatch
      # cannot be found (see moonwatch_findable?): Lich also returns nil while
      # another start of moonwatch is still in progress, so in that case this
      # waits (up to the deadline) for that start to finish.
      #
      # @param timeout [Numeric] seconds to wait for another caller's start to
      #   finish, and again for moonwatch to publish (after starting it, or
      #   when it is already running)
      # @return [Boolean] true when moonwatch is running and has published
      #   real moon data; false when moon data is unavailable
      def check_moonwatch(timeout: MOONWATCH_READY_TIMEOUT)
        if Script.running?('moonwatch')
          if moon_data_ready?
            @moonwatch_data_stalled = false
            return true
          end
          return await_running_moonwatch(timeout) unless MOONWATCH_START_LOCK.locked?
        else
          @moonwatch_data_stalled = false
        end

        lock_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        until MOONWATCH_START_LOCK.try_lock
          # The other start may publish while the lock is still held (its
          # holder can be paused or slow to return), so keep checking.
          return true if Script.running?('moonwatch') && moon_data_ready?
          if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= lock_deadline
            Lich::Messaging.msg("bold", "DRCMM: Timed out waiting for another start of moonwatch to finish. Moon data is unavailable.")
            return false
          end
          pause MOONWATCH_POLL_INTERVAL
        end

        begin
          seen_running = Script.running?('moonwatch')
          unless seen_running
            Lich::Messaging.msg("bold", "DRCMM: moonwatch is not running. Starting it now.")
            UserVars.moons = {}
            if start_script('moonwatch')
              seen_running = true
              Lich::Messaging.msg("plain", "DRCMM: Run `#{$clean_lich_char}e autostart('moonwatch')` to avoid this in the future.")
            elsif !Script.running?('moonwatch') && !moonwatch_findable?
              Lich::Messaging.msg("bold", "DRCMM: moonwatch could not be found. Moon data is unavailable.")
              return false
            end
          end
          await_moonwatch_data(seen_running, timeout)
        ensure
          MOONWATCH_START_LOCK.unlock if MOONWATCH_START_LOCK.owned?
        end
      end

      # Waits for an already-running moonwatch (started outside check_moonwatch,
      # for example by autostart) to publish real moon data. After one wait
      # times out with moonwatch still running, later calls return false at
      # once rather than stalling every caller for the full timeout; that
      # latch clears when the data becomes ready or moonwatch is seen stopped.
      #
      # @param timeout [Numeric] seconds to wait
      # @return [Boolean] true when moon data is ready
      def await_running_moonwatch(timeout)
        return false if @moonwatch_data_stalled

        return true if await_moonwatch_data(true, timeout)

        if Script.running?('moonwatch')
          @moonwatch_data_stalled = true
          Lich::Messaging.msg("plain", "DRCMM: Not waiting for moonwatch's moon data again until it publishes the data or stops.")
        end
        false
      end

      # Whether Lich can find a moonwatch script file. Script.exists? does not
      # look in custom/<subdir>/, which Script.start does, so when it says no
      # this asks Script.version, which resolves names the same way
      # Script.start does and returns nil when no file matches.
      #
      # @return [Boolean]
      def moonwatch_findable?
        return true if Script.exists?('moonwatch')

        !Script.version('moonwatch').nil?
      rescue ArgumentError
        true # the file was found, but its version header is malformed
      end

      # Polls until moonwatch is running with real moon data, moonwatch stops
      # after having been seen running, or the deadline passes.
      #
      # @param seen_running [Boolean] whether moonwatch is known to have started;
      #   until it has, only the deadline ends the wait
      # @param timeout [Numeric] seconds to wait
      # @return [Boolean] true when moon data is ready
      def await_moonwatch_data(seen_running, timeout)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        loop do
          running = Script.running?('moonwatch')
          return true if running && moon_data_ready?

          if running
            seen_running = true
          elsif seen_running
            Lich::Messaging.msg("bold", "DRCMM: moonwatch stopped before it published moon data. Moon data is unavailable.")
            return false
          end

          if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            if seen_running
              Lich::Messaging.msg("bold", "DRCMM: moonwatch did not publish moon data within #{timeout} seconds. Moon data is unavailable.")
            else
              Lich::Messaging.msg("bold", "DRCMM: moonwatch did not start within #{timeout} seconds. Moon data is unavailable.")
            end
            return false
          end

          pause MOONWATCH_POLL_INTERVAL
        end
      end
    end
  end
end
