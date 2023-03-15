def respond(first = "", *messages)
  str = ''
  if first.class == Array
    first.flatten.each { |ln| str += sprintf("%s\r\n", ln.to_s.chomp) }
  else
    str += sprintf("%s\r\n", first.to_s.chomp)
  end
  messages.flatten.each { |message| str += sprintf("%s\r\n", message.to_s.chomp) }
  puts str
end

def _respond(first = "", *messages)
  respond(first, messages)
end

require 'tmpdir'
require "hmr"

module HMR
  module Helpers
    Filename = File.join(Dir.tmpdir, "hmr-test.rb")

    First = <<~Ruby
      module HMR
        Test = 1
      end
    Ruby

    Second = <<~Ruby
      module HMR
        Test = 2
      end
    Ruby
  end
end

describe HMR, "#loaded" do
  context "can tell what has been loaded" do
    it "can find itself loaded" do
      expect(HMR.loaded.any?(%r[lich-5/lib/hmr.rb$])).to be_truthy
    end

    it "can tell something has been freshly loaded" do
      expect(HMR.loaded.any?(HMR::Helpers::Filename)).to be_falsy

      File.write(HMR::Helpers::Filename, HMR::Helpers::First)
      require(HMR::Helpers::Filename)

      expect(HMR.loaded.any?(HMR::Helpers::Filename)).to be_truthy
    end
  end
end

describe HMR, "#reload" do
  context "can reload a module" do
    it "can find itself loaded" do
      File.write(HMR::Helpers::Filename, HMR::Helpers::First)
      require(HMR::Helpers::Filename)
      expect(HMR.loaded.any?(HMR::Helpers::Filename)).to be_truthy
      expect(HMR::Test).to eq(1)
      File.write(HMR::Helpers::Filename, HMR::Helpers::Second)
      HMR.reload(HMR::Helpers::Filename)
      expect(HMR::Test).to eq(2)
    end
  end
end
