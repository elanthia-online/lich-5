# frozen_string_literal: true

require_relative '../../spec_helper'
require 'securerandom'

# Load production code
require "common/hmr"

module HMR
  module Helpers
    # Use unique filenames per test to avoid $LOADED_FEATURES pollution
    def self.unique_filename(suffix)
      File.join(Dir.tmpdir, "hmr-test-#{suffix}-#{::SecureRandom.hex(4)}.rb")
    end

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
      filename = HMR::Helpers.unique_filename("freshly-loaded")
      expect(Lich::Common::HMR.loaded.any?(filename)).to be_falsy

      File.write(filename, HMR::Helpers::First)
      require(filename)

      expect(Lich::Common::HMR.loaded.any?(filename)).to be_truthy
    end
  end
end

RSpec.describe HMR, "#reload" do
  context "can reload a module" do
    it "can find itself loaded" do
      filename = HMR::Helpers.unique_filename("reload")
      File.write(filename, HMR::Helpers::First)
      require(filename)
      expect(Lich::Common::HMR.loaded.any?(filename)).to be_truthy
      expect(HMR::Test).to eq(1)
      File.write(filename, HMR::Helpers::Second)
      Lich::Common::HMR.reload(filename)
      expect(HMR::Test).to eq(2)
    end
  end
end
