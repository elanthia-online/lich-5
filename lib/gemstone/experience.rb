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

      def self.until_next
        XMLData.until_next
      end

      # Ascension experience remaining until the next ascension training point.
      # One ATP is earned per 50,000 ascension experience, so at an exact
      # multiple this reports a full 50,000 interval to the next point.
      def self.next_atp
        50_000 - (axp % 50_000)
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

      # fashlonae has three states on the mindState bar: absent (no orb redeemed),
      # 1 (redeemed but not active), and 2 (redeemed and active). fashlonae?
      # reports whether the bonus is active; fashlonae_redeemed? reports whether an
      # orb has been redeemed at all.
      def self.fashlonae?
        XMLData.fashlonae.eql?(2)
      end

      def self.fashlonae_redeemed?
        !XMLData.fashlonae.nil?
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
