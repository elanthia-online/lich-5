require "infomon"

describe Infomon, ".setup!" do
  context "can set itself up" do
    it "creates a db" do
      Infomon.setup!
      File.exist?(Infomon.file) or fail "infomon sqlite db was not created"
    end
  end
end