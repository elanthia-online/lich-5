# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'
require_relative 'support/example_timeout'

# A hot reload (HMR: `load` of lib/genie.rb, then of the glue) must not
# install a second game-state tap onto Lich's Script -- every row would be parsed twice. Run in a
# child Ruby process: the lich.rbw load sequence (script.rb, lib/genie.rb, the glue with its
# Lich-load install) and the reload both rebind module state this spec process shares with every
# other genie spec.
module GenieReloadSpec
  LIB = File.expand_path('../../../lib', __dir__)

  CHILD = <<~'RUBY'
    lib, config = ARGV
    $VERBOSE = nil
    require "#{lib}/common/limitedarray"
    require "#{lib}/common/feature_flags"
    require "#{lib}/common/downstreamhook"
    require "#{lib}/common/upstreamhook"
    def respond(*) = nil
    def echo(*) = nil
    LimitedArray = Lich::Common::LimitedArray
    require "#{lib}/common/script"
    require "#{lib}/genie.rb"
    Lich::Genie.config_dir = config
    require "#{lib}/genie/genie_script.rb" # the lich.rbw load: install_at_lich_load!
    module Lich; module Genie; class << self; def engine_active? = true; end; end; end
    fed = 0
    Lich::Genie::GameState.prepend(Module.new { define_method(:feed) { |line| fed += 1; super(line) } })
    feed_before = Lich::Genie.game_state_feed
    Lich::Common::Script.new_downstream_xml("<prompt time=\"1\">&gt;</prompt>\r\n")
    first = fed
    ["#{lib}/genie.rb", "#{lib}/genie/genie_script.rb"].each { |file| load file } # HMR.reload(/genie/)
    module Lich; module Genie; class << self; def engine_active? = true; end; end; end
    fed = 0
    Lich::Common::Script.new_downstream_xml("<prompt time=\"2\">&gt;</prompt>\r\n")
    taps = Lich::Common::Script.singleton_class.ancestors.count { |m| m.equal?(Lich::Genie.game_state_feed.tap) }
    others = Lich::Common::Script.singleton_class.ancestors.count { |m| m.instance_of?(Module) && m.name.nil? }
    puts [first, fed, Lich::Genie.game_state_feed.equal?(feed_before), taps, others, Lich::Genie.autoinstall].inspect
  RUBY

  # The #trigger shut-off report the engine start wires up must reach
  # every registry Lich::Genie.triggers builds -- after a reload of lib/genie.rb and after a
  # config_dir change, both of which drop the registry (ondisabled_probe.rb).
  CHILD_ON_DISABLED = <<~'RUBY'
    lib = ARGV[0]
    $VERBOSE = nil
    require 'tmpdir'
    require "#{lib}/genie.rb"
    Lich::Genie.config_dir = Dir.mktmpdir
    got = []
    Lich::Genie.trigger_disabled_listener = ->(pattern) { got << pattern } # what install_downstream_hook! does once
    registries = [Lich::Genie.triggers]
    Lich::Genie.triggers.on_disabled.call('a')
    load "#{lib}/genie.rb" # HMR reload of lib/genie.rb drops @triggers
    registries << Lich::Genie.triggers
    Lich::Genie.triggers.on_disabled.call('b')
    Lich::Genie.config_dir = Dir.mktmpdir
    registries << Lich::Genie.triggers
    Lich::Genie.triggers.on_disabled.call('c')
    puts [got, registries.uniq(&:object_id).length].inspect
  RUBY
end

RSpec.describe 'Genie engine hot reload (lib/genie.rb + genie_script.rb)' do
  it 'keeps the one feed and its one tap: a row is parsed once before and after the reload' do
    out = Dir.mktmpdir('genie-reload') do |config|
      stdout, status = Open3.capture2e(RbConfig.ruby, '-e', GenieReloadSpec::CHILD, GenieReloadSpec::LIB, config)
      expect(status.success?).to be(true), stdout
      stdout
    end
    # [feeds of the row before, feeds of the row after, same feed object, our tap count,
    #  anonymous modules on Script's singleton (taps of any feed), autoinstall default]
    expect(out.lines.last.strip).to eq('[1, 1, true, 1, 1, true]')
  end

  it 'reports a #trigger shut-off from every rebuilt registry (reload, config_dir change)' do
    stdout, status = Open3.capture2e(RbConfig.ruby, '-e', GenieReloadSpec::CHILD_ON_DISABLED, GenieReloadSpec::LIB)
    expect(status.success?).to be(true), stdout
    expect(stdout.lines.last.strip).to eq('[["a", "b", "c"], 3]')
  end
end
