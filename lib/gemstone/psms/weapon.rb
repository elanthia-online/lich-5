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
          :regex      => /You rotate your wrists?, your .+ executing a casual spin to establish your flow as you advance upon .+\!/,
          :assault_rx => /The mesmerizing sway of body and blade glides to its inevitable end with one final twirl of your .+[.!]/,
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
          :regex      => /You rush .+, raising your .+ high to deliver a sound thrashing\!/,
          :buff       => "Forceful Blows"
        },
        "twin_hammerfists" => {
          :short_name => "twinhammer",
          :type       => :setup,
          :cost       => { stamina: 7 },
          :regex      => /You raise your hands high, lace them together and bring them crashing down towards .+\!/,
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
          :regex      => Regexp.union(/With a broad flourish, you sweep your .+ into a whirling display of keen-edged menace\!/,
                                      /With a broad flourish, you weave your .+ into a whirling display of coordination and menace\!/),
          :usage      => "wblade"
        },
        "whirlwind"        => {
          :short_name => "whirlwind",
          :type       => :area_of_effect,
          :cost       => { stamina: 20 },
          :regex      => /Twisting and spinning among your foes, you lash out again and again with the force of a reaping whirlwind\!/
        }
      }

      extend PSMS::Technique
      techniques @@weapon_techniques, type: "Weapon", verb: "weapon"

      # Lines that end any assault besides its own :assault_rx: other assault
      # endings, an interrupted assault, and assault-specific refusals.
      ASSAULT_ENDINGS = Regexp.union(
        /You complete your assault/,
        /With a final, explosive breath/,
        /recentering yourself for the fight/,
        /Upon firing your last (?:arrow|bolt)/,
        /Distracted, you hesitate/,
        /may not be activated within 60 seconds of a Multi-Strike\./,
        /can not be used with attack as the attack type/,
      )

      # @param name [String] the technique name
      # @return [Boolean] whether the technique is an assault (several strikes over several seconds)
      def Weapon.assault?(name)
        technique(name)[:type] == :assault
      end

      # Uses a Weapon technique if it is available. An assault takes no FORCERT
      # and returns when it ends, not when it starts.
      #
      # @see PSMS::Technique#use
      def Weapon.use(name, target = "", ignore_cooldown: false, results_of_interest: nil, forcert_count: 0)
        return super unless assault?(name)
        return unless available?(name, target: target, ignore_cooldown: ignore_cooldown)

        waitrt?
        waitcastrt?
        PSMS.dispatch(command(name, target), results_regex(name, results_of_interest: results_of_interest), timeout: 12)
      end

      # The command {Weapon.use} sends; an assault never takes FORCERT.
      #
      # @see PSMS::Technique#command
      def Weapon.command(name, target = "", forcert_count: 0)
        super(name, target, forcert_count: assault?(name) ? 0 : forcert_count)
      end

      # The lines {Weapon.use} waits on; an assault waits on its ending instead
      # of its opening line and roundtime.
      #
      # @see PSMS::Technique#results_regex
      def Weapon.results_regex(name, results_of_interest: nil)
        return super unless assault?(name)

        PSMS.results_regex(name, technique(name)[:assault_rx], ASSAULT_ENDINGS, results_of_interest: results_of_interest)
      end

      # @api private
      # Area of effect techniques are free under Glorious Momentum.
      def Weapon.free?(psm)
        psm[:type] == :area_of_effect && PSMS.effect_active?(Effects::Buffs, "Glorious Momentum")
      end

      # @api private
      # Glorious Momentum lifts the cooldown on area of effect techniques, and
      # Ardor of the Scourge on assaults.
      def Weapon.cooldown_ignored?(psm, ignore_cooldown)
        super ||
          (psm[:type] == :area_of_effect && PSMS.effect_active?(Effects::Buffs, "Glorious Momentum")) ||
          (psm[:type] == :assault && PSMS.effect_active?(Effects::Buffs, "Ardor of the Scourge"))
      end

      # DEPRECATED: Use {Weapon.buff_active?} instead.
      def Weapon.active?(name)
        Lich.deprecated("Weapon.active?", "Weapon.buff_active?", caller[0], fe_log: false)
        buff_active?(name)
      end
    end
  end
end
