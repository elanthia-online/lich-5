## breakout for Warcries

module Lich
  module Gemstone
    class Warcry
      def self.warcry_lookups
        [{ long_name: 'bertrandts_bellow',        short_name: 'bellow',         cost: 20 }, # @todo only 10 for single
         { long_name: 'carns_cry',                short_name: 'cry',            cost: 20 },
         { long_name: 'gerrelles_growl',          short_name: 'growl',          cost: 14 }, # @todo only 7 for single
         { long_name: 'horlands_holler',          short_name: 'holler',         cost: 20 },
         { long_name: 'seanettes_shout',          short_name: 'shout',          cost: 20 },
         { long_name: 'yerties_yowlp',            short_name: 'yowlp',          cost: 10 }]
      end

      @@warcries = {
        "bellow" => {
          :regex => /You glare at .+ and let out a nerve-shattering bellow!/,
        },
        "yowlp"  => {
          :regex => /You throw back your shoulders and let out a resounding yowlp!/,
          :buff  => "Yertie's Yowlp",
        },
        "growl"  => {
          :regex => /Your face contorts as you unleash a guttural, deep-throated growl at .+!/,
        },
        "shout"  => {
          :regex => /You let loose an echoing shout!/,
          :buff  => 'Empowered (+20)',
        },
        "cry"    => {
          :regex => /You stare down .+ and let out an eerie, modulating cry!/,
        },
        "holler" => {
          :regex => /You throw back your head and let out a thundering holler!/,
          :buff  => 'Enh. Health (+20)',
        },
      }

      def Warcry.[](name)
        return PSMS.assess(name, 'Warcry')
      end

      def Warcry.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Warcry[name] >= min_rank
      end

      def Warcry.affordable?(name)
        return PSMS.assess(name, 'Warcry', true)
      end

      def Warcry.available?(name, min_rank: 1)
        Warcry.known?(name, min_rank: min_rank) and Warcry.affordable?(name) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
      end

      def Warcry.buffActive?(name)
        buff = @@warcries.fetch(PSMS.name_normal(name))[:buff]
        return false if buff.nil?
        Lich::Util.normalize_lookup('Buffs', buff)
      end

      def Warcry.use(name, target = "", results_of_interest: nil)
        return unless Warcry.available?(name)
        return if Warcry.buffActive?(name)
        name_normalized = PSMS.name_normal(name)
        technique = @@warcries.fetch(name_normalized)
        usage = name_normalized
        return if usage.nil?

        in_cooldown_regex = /^#{name} is still in cooldown\./i

        results_regex = Regexp.union(
          PSMS::FAILURES_REGEXES,
          /^#{name} what\?$/i,
          in_cooldown_regex,
          technique[:regex],
          /^Roundtime: [0-9]+ sec\.$/,
        )

        if results_of_interest.is_a?(Regexp)
          results_regex = Regexp.union(results_regex, results_of_interest)
        end

        usage_cmd = "warcry #{usage}"
        if target.class == GameObj
          usage_cmd += " ##{target.id}"
        elsif target.class == Integer
          usage_cmd += " ##{target}"
        elsif target != ""
          usage_cmd += " #{target}"
        end
        waitrt?
        waitcastrt?
        usage_result = dothistimeout(usage_cmd, 5, results_regex)
        if usage_result == "You don't seem to be able to move to do that."
          100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
          usage_result = dothistimeout(usage_cmd, 5, results_regex)
        end
        usage_result
      end

      def Warcry.regexp(name)
        @@warcries.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:regex]
      end

      Warcry.warcry_lookups.each { |warcry|
        self.define_singleton_method(warcry[:short_name]) do
          Warcry[warcry[:short_name]]
        end

        self.define_singleton_method(warcry[:long_name]) do
          Warcry[warcry[:short_name]]
        end
      }
    end
  end
end
