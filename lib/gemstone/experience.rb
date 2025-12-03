require "ostruct"

module Lich
  module Gemstone
    module Experience
      def self.fame
        Infomon.get("experience.fame")
      end

      def self.fxp_current
        Infomon.get("experience.field_experience_current")
      end

      def self.fxp_max
        Infomon.get("experience.field_experience_max")
      end

      def self.exp
        Stats.exp
      end

      def self.axp
        Infomon.get("experience.ascension_experience")
      end

      def self.txp
        Infomon.get("experience.total_experience")
      end

      def self.percent_fxp
        (fxp_current.to_f / fxp_max.to_f) * 100
      end

      def self.percent_axp
        (axp.to_f / txp.to_f) * 100
      end

      def self.percent_exp
        (exp.to_f / txp.to_f) * 100
      end

      def self.lte
        Infomon.get("experience.long_term_experience")
      end

      def self.deeds
        Infomon.get("experience.deeds")
      end

      def self.deaths_sting
        Infomon.get("experience.deaths_sting")
      end

      def self.updated_at
        timestamp = Infomon.get_updated_at("experience.total_experience")
        timestamp ? Time.at(timestamp) : nil
      end

      def self.stale?(threshold: 24.hours)
        return true unless updated_at
        updated_at < threshold.ago
      end

      def self.recently_updated?(threshold: 5.minutes)
        return false unless updated_at
        updated_at >= threshold.ago
      end
    end
  end
end
