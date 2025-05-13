## breakout for Armor released with PSM3
## updated for Ruby 3.2.1 and new Infomon module

module Lich
  module Gemstone
    module Armor
      @@armor_techniques = {
        "armor_blessing"      => {
          "short_name" => "blessing",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /As \w+ prays? over \w+(?:'s)? [\w\s]+, you sense that (?:the Arkati's|a) blessing will be granted against magical attacks\./i,
          "usage"      => "blessing"
        },
        "armor_reinforcement" => {
          "short_name" => "reinforcement",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, reinforcing weak spots\./i,
          "usage"      => "reinforcement"
        },
        "armor_spike_mastery" => {
          "short_name" => "spikemastery",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Armor Spike Mastery is passive and always active once learned\./i,
          "usage"      => "spikemastery"
        },
        "armor_support"       => {
          "short_name" => "support",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its ability to support the weight of \w+ gear\./i,
          "usage"      => "support"
        },
        "armored_casting"     => {
          "short_name" => "casting",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to recover from failed spell casting\./i,
          "usage"      => "casting"
        },
        "armored_evasion"     => {
          "short_name" => "evasion",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its comfort and maneuverability\./i,
          "usage"      => "evasion"
        },
        "armored_fluidity"    => {
          "short_name" => "fluidity",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to cast spells\./i,
          "usage"      => "fluidity"
        },
        "armored_stealth"     => {
          "short_name" => "stealth",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /\w+ adjusts? \w+(?:'s)? [\w\s]+ to cushion \w+ movements\./i,
          "usage"      => "stealth"
        },
        "crush_protection"    => {
          "short_name" => "crush",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => Regexp.union(
            /You adjust \w+(?:'s)? [\w\s]+ with your (?:cloth|leather|scale|chain|plate|accessory) armor fittings, rearranging and reinforcing the armor to better protect against (?:punctur|crush|slash)ing damage\./i,
            /You must specify an armor slot\./,
            /You don't seem to have the necessary armor fittings in hand\./
          ),
          "usage"      => "crush"
        },
        "puncture_protection" => {
          "short_name" => "puncture",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => Regexp.union(
            /You adjust \w+(?:'s)? [\w\s]+ with your (?:cloth|leather|scale|chain|plate|accessory) armor fittings, rearranging and reinforcing the armor to better protect against (?:punctur|crush|slash)ing damage\./i,
            /You must specify an armor slot\./,
            /You don't seem to have the necessary armor fittings in hand\./
          ),
          "usage"      => "puncture"
        },
        "slash_protection"    => {
          "short_name" => "slash",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => Regexp.union(
            /You adjust \w+(?:'s)? [\w\s]+ with your (?:cloth|leather|scale|chain|plate|accessory) armor fittings, rearranging and reinforcing the armor to better protect against (?:punctur|crush|slash)ing damage\./i,
            /You must specify an armor slot\./,
            /You don't seem to have the necessary armor fittings in hand\./
          ),
          "usage"      => "slash"
        }
      }

      def self.armor_lookups
        @@armor_techniques.map do |long_name, psm|
          {
            long_name: long_name,
            short_name: psm[:short_name],
            cost: psm[:cost]
          }
        end
      end

      def Armor.[](name)
        return PSMS.assess(name, 'Armor')
      end

      def Armor.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Armor[name] >= min_rank
      end

      def Armor.affordable?(name, forcert_count: 0)
        return PSMS.assess(name, 'Armor', true, forcert_count: forcert_count)
      end

      def Armor.available?(name, min_rank: 1, forcert_count: 0)
        Armor.known?(name, min_rank: min_rank) and Armor.affordable?(name, forcert_count: forcert_count) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
      end

      def Armor.use(name, target = "", results_of_interest: nil, forcert_count: 0)
        return unless Armor.available?(name, forcert_count: forcert_count)
        name_normalized = PSMS.name_normal(name)
        technique = @@armor_techniques.fetch(name_normalized)
        usage = technique[:usage]
        return if usage.nil?

        in_cooldown_regex = /^#{name} is still in cooldown\./i

        results_regex = Regexp.union(
          PSMS::FAILURES_REGEXES,
          /^#{name} what\?$/i,
          in_cooldown_regex,
          technique[:regex],
          /^Roundtime: [0-9]+ sec\.$/,
          /^\w+ [a-z]+ not wearing any armor that you can work with\.$/
        )

        if results_of_interest.is_a?(Regexp)
          results_regex = Regexp.union(results_regex, results_of_interest)
        end

        usage_cmd = "armor #{usage}"
        if target.is_a?(GameObj)
          usage_cmd += " ##{target.id}"
        elsif target.is_a?(Integer)
          usage_cmd += " ##{target}"
        elsif target != ""
          usage_cmd += " #{target}"
        end

        if forcert_count > 0
          usage_cmd += " forcert"
        else # if we're using forcert, we don't want to wait for rt, but we need to otherwise
          waitrt?
          waitcastrt?
        end

        usage_result = dothistimeout usage_cmd, 5, results_regex
        if usage_result == "You don't seem to be able to move to do that."
          100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
          usage_result = dothistimeout usage_cmd, 5, results_regex
        end
        usage_result
      end

      def Armor.regexp(name)
        @@armor_techniques.fetch(PSMS.name_normal(name))[:regex]
      end

      Armor.armor_lookups.each { |armor|
        self.define_singleton_method(armor[:short_name]) do
          Armor[armor[:short_name]]
        end

        self.define_singleton_method(armor[:long_name]) do
          Armor[armor[:short_name]]
        end
      }
    end
  end
end
