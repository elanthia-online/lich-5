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
  end
end