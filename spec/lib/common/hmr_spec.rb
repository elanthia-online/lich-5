# frozen_string_literal: true

require_relative '../../spec_helper'

# Load production code
require "common/hmr"

module HMR
  module Helpers
    Filename = File.join(Dir.tmpdir, "hmr-test.rb")

    First = <<~RUBY
      module HMR
        Test = 1
      end
    RUBY

    Second = <<~RUBY
      module HMR
        Test = 2
      end
    RUBY
  end
end

RSpec.describe HMR, "#loaded" do
  context "can tell what has been loaded" do
    it "can find itself loaded" do
      expect(Lich::Common::HMR.loaded.any?(%r{lich-5/lib/common/hmr.rb$})).to be_truthy
    end

    it "can tell something has been freshly loaded" do
      expect(Lich::Common::HMR.loaded.any?(HMR::Helpers::Filename)).to be_falsy

      File.write(HMR::Helpers::Filename, HMR::Helpers::First)
      require(HMR::Helpers::Filename)

      expect(Lich::Common::HMR.loaded.any?(HMR::Helpers::Filename)).to be_truthy
    end
  end
end

RSpec.describe HMR, "#reload" do
  context "can reload a module" do
    it "can find itself loaded" do
      File.write(HMR::Helpers::Filename, HMR::Helpers::First)
      require(HMR::Helpers::Filename)
      expect(Lich::Common::HMR.loaded.any?(HMR::Helpers::Filename)).to be_truthy
      expect(HMR::Test).to eq(1)
      File.write(HMR::Helpers::Filename, HMR::Helpers::Second)
      Lich::Common::HMR.reload(HMR::Helpers::Filename)
      expect(HMR::Test).to eq(2)
    end
  end
end
