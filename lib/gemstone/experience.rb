require "ostruct"

module Lich
  module Gemstone
    module Experience
      def self.fame
        Infomon.get("experience.fame")
      end

      def self.fxp_current
        XMLData.field_exp
      end

      def self.fxp_max
        XMLData.max_field_exp
      end

      def self.exp
        XMLData.exp
      end

      def self.axp
        XMLData.ascension_exp
      end

      def self.txp
        XMLData.exp + XMLData.ascension_exp
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

      def self.rpa?
        !XMLData.rpa.nil?
      end

      def self.rpa
        XMLData.rpa
      end

      def self.lumnis?
        !XMLData.lumnis.nil?
      end

      def self.lumnis
        XMLData.lumnis
      end

      def self.fashlonae?
        !XMLData.fashlonae.nil?
      end

      def self.updated_at
        timestamp = Infomon.get_updated_at("experience.fame")
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
