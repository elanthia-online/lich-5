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