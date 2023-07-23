module Lich
  module Currency
    def self.silver
      Infomon.get('currency.silver')
    end

    def self.silver_container
      Infomon.get('currency.silver_container')
    end

    def self.redsteel_marks
      Infomon.get('currency.redsteel_marks')
    end

    def self.tickets
      Infomon.get('currency.tickets')
    end

    def self.blackscrip
      Infomon.get('currency.blackscrip')
    end

    def self.bloodscrip
      Infomon.get('currency.bloodscrip')
    end

    def self.ethereal_scrip
      Infomon.get('currency.ethereal_scrip')
    end

    def self.raikhen
      Infomon.get('currency.raikhen')
    end

    def self.elans
      Infomon.get('currency.elans')
    end

    def self.soul_shards
      Infomon.get('currency.soul_shards')
    end

    def self.gigas_artifact_fragments
      Infomon.get('currency.gigas_artifact_fragments')
    end
  end
end
