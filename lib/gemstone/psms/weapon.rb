# Root module for Lich scripting components.
module Lich
  # Namespace for GemStone IV-specific modules.
  module Gemstone
    # Provides logic for using weapon-based PSM techniques.
    #
    # The Weapon module includes metadata about known weapon techniques (cost, result patterns, buff effect, etc.)
    # and provides methods to:
    # - Check whether a technique is known, affordable, or available
    # - Execute techniques with optional FORCERT or specific targets
    # - Detect buff activation for some techniques
    #
    # Dynamic methods are generated for each weapon technique using its short and long name.
    module Weapon
      # Internal registry of weapon techniques.
      #
      # @return [Hash<String, Hash>] Mapping of technique names to their metadata, including:
      #   - `:short_name` [String]
      #   - `:cost` [Integer]
      #   - `:regex` [Regexp] expected combat log output
      #   - `:assault_rx` [Regexp, optional] alternate result pattern for assault-style moves
      #   - `:buff` [String, optional] buff name to check via Effects::Buffs
      #   - `:usage` [String, optional] override for default usage command
      @@weapon_techniques = {
        "barrage"          => {
          :short_name => "barrage",
          :type       => :assault,
          :cost       => { stamina: 15 },
          :regex      => /Drawing several (?:arrows|bolts) from your .+, you grip them loosely between your fingers in preparation for a rapid barrage\./,
          :assault_rx => /Your satisfying display of dexterity bolsters you and inspires those around you\!/,
          :buff       => "Enh. Dexterity (+10)"
        },
        "charge"           => {
          :short_name => "charge",
          :type       => :setup,
          :cost       => { stamina: 14 },
          :regex      => /You rush forward at .+ with your .+ and attempt a charge\!/
        },
        "clash"            => {
          :short_name => "clash",
          :type       => :area_of_effect,
          :cost       => { stamina: 20 },
          :regex      => /Steeling yourself for a brawl, you plunge into the fray\!/
        },
        "clobber"          => {
          :short_name => "clobber",
          :type       => :reaction,
          :cost       => { stamina: 0 },
          :regex      => /You redirect the momentum of your parry, hauling your .+ around to clobber .+\!/
        },
        "cripple"          => {
          :short_name => "cripple",
          :type       => :setup,
          :cost       => { stamina: 7 },
          :regex      => /You reverse your grip on your .+ and dart toward .+ at an angle\!/
        },
        "cyclone"          => {
          :short_name => "cyclone",
          :type       => :area_of_effect,
          :cost       => { stamina: 20 },
          :regex      => /You weave your .+ in an under arm spin, swiftly picking up speed until it becomes a blurred cyclone of .+\!/
        },
        "dizzying_swing"   => {
          :short_name => "dizzyingswing",
          :type       => :setup,
          :cost       => { stamina: 7 },
          :regex      => /You heft your .+ and, looping it once to build momentum, lash out in a strike at .+ head\!/,
          :usage      => "dizzyingswing"
        },
        "flurry"           => {
          :short_name => "flurry",
          :type       => :assault,
          :cost       => { stamina: 15 },
          :regex      => /You rotate your wrist, your .+ executing a casual spin to establish your flow as you advance upon .+\!/,
          :assault_rx => /The mesmerizing sway of body and blade glides to its inevitable end with one final twirl of your .+\!/,
          :buff       => "Slashing Strikes"
        },
        "fury"             => {
          :short_name => "fury",
          :type       => :assault,
          :cost       => { stamina: 15 },
          :regex      => /With a percussive snap, you shake out your arms in quick succession and bear down on .+ in a fury\!/,
          :assault_rx => /Your furious assault bolsters you and inspires those around you\!/,
          :buff       => "Enh. Constitution (+10)"
        },
        "guardant_thrusts" => {
          :short_name => "gthrusts",
          :type       => :assault,
          :cost       => { stamina: 15 },
          :regex      => /Retaining a defensive profile, you raise your .+ in a hanging guard and prepare to unleash a barrage of guardant thrusts upon .+\!/,
          :usage      => "gthrusts"
        },
        "overpower"        => {
          :short_name => "overpower",
          :type       => :reaction,
          :cost       => { stamina: 0 },
          :regex      => /On the heels of .+ parry, you erupt into motion, determined to overpower .+ defenses\!/
        },
        "pin_down"         => {
          :short_name => "pindown",
          :type       => :area_of_effect,
          :cost       => { stamina: 14 },
          :regex      => /You take quick assessment and raise your .+, several (?:arrows|bolts) nocked to your string in parallel\./,
          :usage      => "pindown"
        },
        "pulverize"        => {
          :short_name => "pulverize",
          :type       => :area_of_effect,
          :cost       => { stamina: 20 },
          :regex      => /You wheel your .+ overhead before slamming it around in a wide arc to pulverize your foes\!/
        },
        "pummel"           => {
          :short_name => "pummel",
          :type       => :assault,
          :cost       => { stamina: 15 },
          :regex      => /You take a menacing step toward .+, sweeping your .+ out low to your side in your advance\./,
          :assault_rx => /With a final snap of your wrist, you sweep your .+ back to the ready, your assault complete\./,
          :buff       => "Concussive Blows"
        },
        "radial_sweep"     => {
          :short_name => "radialsweep",
          :type       => :reaction,
          :cost       => { stamina: 0 },
          :regex      => /Crouching low, you sweep your .+ in a broad arc\!/,
          :usage      => "radialsweep"
        },
        "reactive_shot"    => {
          :short_name => "reactiveshot",
          :type       => :reaction,
          :cost       => { stamina: 0 },
          :regex      => /You fire off a quick shot at the .+, then make a hasty retreat\!/,
          :usage      => "reactiveshot"
        },
        "reverse_strike"   => {
          :short_name => "reversestrike",
          :type       => :reaction,
          :cost       => { stamina: 0 },
          :regex      => /Spotting an opening in .+ defenses, you quickly reverse the direction of your .+ and strike from a different angle\!/,
          :usage      => "reversestrike"
        },
        "riposte"          => {
          :short_name => "riposte",
          :type       => :reaction,
          :cost       => { stamina: 0 },
          :regex      => /Before .+ can recover, you smoothly segue from parry to riposte\!/
        },
        "spin_kick"        => {
          :short_name => "spinkick",
          :type       => :reaction,
          :cost       => { stamina: 0 },
          :regex      => /Stepping with deliberation, you wheel into a leaping spin\!/,
          :usage      => "spinkick"
        },
        "thrash"           => {
          :short_name => "thrash",
          :type       => :assault,
          :cost       => { stamina: 15 },
          :regex      => /You rush .+, raising your .+ high to deliver a sound thrashing\!/
        },
        "twin_hammerfists" => {
          :short_name => "twinhammer",
          :type       => :setup,
          :cost       => { stamina: 7 },
          :regex      => /You raise your hands high, lace them together and bring them crashing down towards the .+\!/,
          :usage      => "twinhammer"
        },
        "volley"           => {
          :short_name => "volley",
          :type       => :area_of_effect,
          :cost       => { stamina: 20 },
          :regex      => /Raising your .+ high, you loose (?:arrow|bolt) after (?:arrow|bolt) as fast as you can, filling the sky with a volley of deadly projectiles\!/
        },
        "whirling_blade"   => {
          :short_name => "wblade",
          :type       => :area_of_effect,
          :cost       => { stamina: 20 },
          :regex      => /With a broad flourish, you sweep your .+ into a whirling display of keen-edged menace\!/,
          :usage      => "wblade"
        },
        "whirlwind"        => {
          :short_name => "whirlwind",
          :type       => :area_of_effect,
          :cost       => { stamina: 20 },
          :regex      => /Twisting and spinning among your foes, you lash out again and again with the force of a reaping whirlwind\!/
        }
      }

      # Returns a summary array of weapon techniques and metadata.
      #
      # @return [Array<Hash>] Each hash contains :long_name, :short_name, :cost
      def self.weapon_lookups
        @@weapon_techniques.map do |long_name, psm|
          {
            long_name: long_name,
            short_name: psm[:short_name],
            cost: psm[:cost]
          }
        end
      end

      # Looks up the rank known of a weapon technique.
      #
      # @param name [String] The name of the weapon technique
      # @return [Integer] The rank of the technique, or 0 if unknown
      # @example
      #   Weapon["volley"] => 2
      #   Weapon["volley"] => 0 # if not known
      def Weapon.[](name)
        return PSMS.assess(name, 'Weapon')
      end

      # Determines if the character knows an weapon technique at all, and
      # optionally if the character knows it at the specified rank.
      #
      # @param name [String] The name of the weapon technique
      # @param min_rank [Integer] Optionally, the minimum rank to test against (default: 1, so known)
      # @return [Boolean] True if the technique is known at or above the given rank
      # @example
      #   Weapon.known?("volley") => true # if any number of ranks is known
      #   Weapon.known?("volley", min_rank: 2) => false # if only rank 1 is known
      def Weapon.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Weapon[name] >= min_rank
      end

      # Determines if an Weapon technique is affordable, and optionally tests
      # affordability with a given number of FORCERTs having been used (including the current one).
      #
      # @param name [String] The name of the Weapon technique
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used, including for this execution (default: 0)
      # @return [Boolean] True if the technique can be used with available FORCERTs
      # @example
      #   Weapon.affordable?("Weapon_blessing") => true # if enough skill and stamina
      #   Weapon.affordable?("Weapon_blessing", forcert_count: 1) => false  # if not enough skill or stamina
      def Weapon.affordable?(name, forcert_count: 0)
        return true if @@weapon_techniques.fetch(PSMS.find_name(name, "Weapon")[:long_name])[:type] == :area_of_effect && Effects::Buffs.active?("Glorious Momentum")
        return PSMS.assess(name, 'Weapon', true, forcert_count: forcert_count)
      end

      # Determines if an Weapon technique is available to use right now by testing:
      # - if the technique is known
      # - if the technique is affordable
      # - if the technique is not on cooldown
      # - if the character is not overexerted
      # - if the character is capable of performing the number of FORCERTs specified
      #
      # @param name [String] The name of the Weapon technique
      # @param min_rank [Integer] Optionally, the minimum rank to check (default: 1)
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used (default: 0)
      # @return [Boolean] True if the technique is known, affordable, and not on cooldown or
      # blocked by overexertion
      # @example
      #   Weapon.available?("Weapon_blessing") => true # if known, affordable, not on cooldown, and not overexerted
      def Weapon.available?(name, min_rank: 1, forcert_count: 0)
        return false unless Weapon.known?(name, min_rank: min_rank)
        return false unless Weapon.affordable?(name, forcert_count: forcert_count)
        if @@weapon_techniques.fetch(PSMS.find_name(name, "Weapon")[:long_name])[:type] == :area_of_effect && Effects::Buffs.active?("Glorious Momentum")
          return false unless PSMS.available?(name, true)
        elsif @@weapon_techniques.fetch(PSMS.find_name(name, "Weapon")[:long_name])[:type] == :assault && Effects::Buffs.active?("Ardor of the Scourge")
          return false unless PSMS.available?(name, true)
        else
          return false unless PSMS.available?(name)
        end
        return true
      end

      # DEPRECATED: Use {#buff_active?} instead.
      # Checks whether a technique's buff is currently active.
      #
      # @param name [String] Technique name
      # @return [Boolean] True if the buff is active
      def Weapon.active?(name)
        ## DEPRECATED ##
        Lich.deprecated("Weapon.active?", "Weapon.buff_active?", caller[0], fe_log: false)
        buff_active?(name)
      end

      # Checks whether the technique's buff is currently active.
      #
      # @param name [String] The technique's name
      # @return [Boolean] True if buff is already active
      def Weapon.buff_active?(name)
        buff = @@weapon_techniques.fetch(PSMS.find_name(name, "Weapon")[:long_name])[:buff]
        return false if buff.nil?
        Effects::Buffs.active?(@@weapon_techniques.fetch(PSMS.find_name(name, "Weapon")[:long_name])[:buff])
      end

      # Attempts to use a Weapon technique, optionally on a target.
      #
      # @param name [String] The name of the Weapon technique
      # @param target [String, Integer, GameObj] The target of the technique (optional).  If unspecified, the technique will be used on the character.
      # @param results_of_interest [Regexp, nil] Additional regex to capture from result (optional)
      # @param forcert_count [Integer] Number of FORCERTs to use (default: 0)
      # @return [String, nil] The result of the regex match, or nil if unavailable
      # @example
      #   Weapon.use("Weapon_blessing") # attempt to use Weapon blessing on self
      #   Weapon.use("Weapon_blessing", "Dissonance") # attempt to use Weapon blessing on Dissonance
      def Weapon.use(name, target = "", results_of_interest: nil, forcert_count: 0)
        return unless Weapon.available?(name, forcert_count: forcert_count)

        name_normalized = PSMS.name_normal(name)
        technique = @@weapon_techniques.fetch(PSMS.find_name(name_normalized, "Weapon")[:long_name])
        usage = technique.key?(:usage) ? technique[:usage] : name_normalized
        return if usage.nil?

        in_cooldown_regex = /^#{name} is still in cooldown\./i

        results_regex = Regexp.union(
          PSMS::FAILURES_REGEXES,
          /^#{name} what\?$/i,
          in_cooldown_regex
        )

        results_regex = Regexp.union(results_regex, results_of_interest) if results_of_interest

        usage_cmd = "weapon #{usage}"
        if target.is_a?(GameObj)
          usage_cmd += " ##{target.id}"
        elsif target.is_a?(Integer)
          usage_cmd += " ##{target}"
        elsif target != ""
          usage_cmd += " #{target}"
        end

        usage_result = nil
        if (technique.key?(:assault_rx))
          results_regex = Regexp.union(results_regex, technique[:assault_rx])
          break_out = Time.now() + 12
          loop {
            usage_result = dothistimeout(usage_cmd, 10, results_regex)
            if usage_result =~ /\.\.\.wait/i
              waitrt?
              next
            end
            break if usage_result.eql?(false)
            break if usage_result =~ technique[:assault_rx]
            break if usage_result =~ /^#{name} what\?$/i
            break if usage_result =~ in_cooldown_regex
            break if Time.now() > break_out
            sleep 0.25
          }
        else
          results_regex = Regexp.union(results_regex, technique[:regex], /^Roundtime: [0-9]+ sec\.$/)

          if forcert_count > 0
            usage_cmd += " forcert"
          else # if we're using forcert, we don't want to wait for rt, but we need to otherwise
            waitrt?
            waitcastrt?
          end

          usage_result = dothistimeout(usage_cmd, 5, results_regex)
          if usage_result == "You don't seem to be able to move to do that."
            100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
            usage_result = dothistimeout(usage_cmd, 5, results_regex)
          end
        end

        usage_result
      end

      # Returns the "success" regex associated with a given Weapon technique name.
      # This regex is used to match the expected output when the technique is successfully *attempted*.
      # It does not necessarily indicate that the technique was successful in its effect, or even
      # that the technique was executed at all.
      #
      # @param name [String] The technique name
      # @return [Regexp] The regex used to match technique success or effects
      # @example
      #   Weapon.regexp("Weapon_blessing") => /As \w+ prays? over \w+(?:'s)? [\w\s]+, you sense that (?:the Arkati's|a) blessing will be granted against magical attacks\./i
      def Weapon.regexp(name)
        @@weapon_techniques.fetch(PSMS.find_name(name, "Weapon")[:long_name])[:regex]
      end

      # Defines dynamic getter methods for both long and short names of each Weapon technique.
      #
      # @note This block dynamically defines methods like `Weapon.blessing` and `Weapon.Weapon_blessing`
      # @example
      #   Weapon.blessing # returns the rank of Weapon_blessing based on the short name
      #   Weapon.Weapon_blessing # returns the rank of Weapon_blessing based on the long name
      Weapon.weapon_lookups.each { |weapon|
        self.define_singleton_method(weapon[:short_name]) do
          Weapon[weapon[:short_name]]
        end

        self.define_singleton_method(weapon[:long_name]) do
          Weapon[weapon[:short_name]]
        end
      }
    end
  end
end
