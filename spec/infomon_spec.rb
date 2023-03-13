require "infomon"

describe Infomon, ".setup!" do
  context "can set itself up" do
    it "creates a db" do
      Infomon.setup!
      File.exist?(Infomon.file) or fail "infomon sqlite db was not created"
    end
  end

  context "can manipulate data" do
    it "upserts a new key/value pair" do
      k = "stats.influence"
      # handles when value doesn't exist
      Infomon.set(k, 30)
      expect(Infomon.get(k)).to eq(30)
      Infomon.set(k, 40)
      # handles upsert on already existing values
      expect(Infomon.get(k)).to eq(40)
    end
  end
end

describe Infomon::Parser, ".parse" do
  context "citizenship" do
    it "handles citizenship in a town" do
      Infomon::Parser.parse %[You currently have full citizenship in Wehnimer's Landing.]
      citizenship = Infomon.get("citizenship")
      expect(citizenship).to eq(%[Wehnimer's Landing])
    end

    it "handles no citizenship" do
      Infomon::Parser.parse %[You don't seem to have citizenship.]
      expect(Infomon.get("citizenship")).to eq(nil)
    end

    it "handles stats" do
      stats = <<~Stats
            Strength (STR):   110 (30)    ...  110 (30)
      Constitution (CON):   104 (22)    ...  104 (22)
        Dexterity (DEX):   100 (35)    ...  100 (35)
          Agility (AGI):   100 (30)    ...  100 (30)
        Discipline (DIS):   110 (20)    ...  110 (20)
              Aura (AUR):   100 (-35)    ...  100 (35)
            Logic (LOG):   108 (29)    ...  118 (34)
        Intuition (INT):    99 (29)    ...   99 (29)
            Wisdom (WIS):    84 (22)    ...   84 (22)
        Influence (INF):   100 (20)    ...  108 (24)
      Stats
      stats.split("\n").each {|line| Infomon::Parser.parse(line)}

      expect(Infomon.get("stat.aura")).to eq(100)
      expect(Infomon.get("stat.aura.bonus")).to eq(-35)
      expect(Infomon.get("stat.logic.enhanced")).to eq(118)
      expect(Infomon.get("stat.logic.enhanced_bonus")).to eq(34)
    end
  end
end