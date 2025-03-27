module Lich
  module Currency
    def self.silver
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

    def self.gigas_artifact_fragments
      Lich::Gemstone::Infomon.get('currency.gigas_artifact_fragments')
    end

    def self.gemstone_dust
      Lich::Gemstone::Infomon.get('currency.gemstone_dust')
    end
  end
end
