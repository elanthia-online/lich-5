# frozen_string_literal: true

require_relative '../spec_helper'
require 'rbconfig'
require 'shellwords'

RSpec.describe 'Lich.seek frontend locator compatibility' do
  def run_lich(script)
    lib_path = File.expand_path('../../lib', __dir__)
    source = "$LOAD_PATH.unshift(#{lib_path.inspect}); require 'lich'; #{script}"
    `#{Shellwords.escape(RbConfig.ruby)} -e #{Shellwords.escape(source)}`
  end

  it 'delegates to FrontendLocator when the locator is loaded' do
    output = run_lich(<<~RUBY)
      module Lich::Common; end
      module Lich::Common::FrontendLocator
        def self.compatibility_location(frontend_id)
          "/located/\#{frontend_id}"
        end
      end
      print Lich.seek('stormfront')
    RUBY

    expect(output).to eq('/located/stormfront')
  end

  it 'retains the legacy global fallback before the locator is loaded' do
    output = run_lich(<<~RUBY)
      $wiz_fe_loc = '/legacy/wizard'
      $sf_fe_loc = '/legacy/stormfront'
      print [Lich.seek('wizard'), Lich.seek('stormfront')].join('|')
    RUBY

    expect(output).to eq('/legacy/wizard|/legacy/stormfront')
  end
end
