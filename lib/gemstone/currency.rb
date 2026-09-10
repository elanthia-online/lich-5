module Lich
  module Gemstone
    module Currency
      # Silver carried, as Infomon last saw it. Infomon updates it whenever a
      # WEALTH or INFO response goes by, so the value is only as fresh as the
      # last of those; pass +refresh: true+ to send WEALTH QUIET first.
      #
      # @param refresh [Boolean]
      # @return [Integer, nil]
      def self.silver(refresh: false)
        self.refresh if refresh
        Lich::Gemstone::Infomon.get('currency.silver')
      end

      # Send WEALTH QUIET so Infomon re-reads the silver carried. The response
      # is parsed on the game thread before hooks run, so hiding it from the
      # front end does not hide it from Infomon.
      #
      # @return [Integer, nil] the refreshed silver
      def self.refresh
        Lich::Util.issue_command('wealth quiet', Lich::Gemstone::Infomon::Parser::Pattern::WealthSilver, silent: true, quiet: true)
        Lich::Gemstone::Infomon.get('currency.silver')
      end

      def self.silver_container
        Lich::Gemstone::Infomon.get('currency.silver_container')
      end

      def self.redsteel_marks
        Lich::Gemstone::Infomon.get('currency.redsteel_marks')
      end

      def self.tickets
        Lich::Gemstone::Infomon.get('currency.tickets')
      end

      def self.blackscrip
        Lich::Gemstone::Infomon.get('currency.blackscrip')
      end

      def self.bloodscrip
        Lich::Gemstone::Infomon.get('currency.bloodscrip')
      end

      def self.ethereal_scrip
        Lich::Gemstone::Infomon.get('currency.ethereal_scrip')
      end

      def self.raikhen
        Lich::Gemstone::Infomon.get('currency.raikhen')
      end

      def self.elans
        Lich::Gemstone::Infomon.get('currency.elans')
      end

      def self.soul_shards
        Lich::Gemstone::Infomon.get('currency.soul_shards')
      end

      def self.aevit
        Lich::Gemstone::Infomon.get('currency.aevit')
      end

      def self.gold
        Lich::Gemstone::Infomon.get('currency.gold')
      end

      def self.gigas_artifact_fragments
        Lich::Gemstone::Infomon.get('currency.gigas_artifact_fragments')
      end

      def self.gemstone_dust
        Lich::Gemstone::Infomon.get('currency.gemstone_dust')
      end
    end
  end
end
