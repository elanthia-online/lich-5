# frozen_string_literal: true

# bench/lich_env.rb -- boots the *real* Lich subsystems headlessly so memory
# can be measured against production code paths, without the login / GTK /
# network orchestration.
#
# It mirrors the require order in lich.rbw up to the point the downstream
# parse/script/hook pipeline needs, then stops. Crucially it does NOT require
# lib/main/main.rb, because that file spawns the live @main_thread at require
# time (it blocks on a client socket, performs eaccess login, and calls exit
# on teardown) -- none of which is relevant to measuring memory and all of
# which would derail a headless run.
#
# Directory constants are pointed at a fresh temp dir so a profiling run never
# touches a real character's data/logs/db.

require 'fileutils'
require 'tmpdir'

module Bench
  module LichEnv
    SANDBOX = File.join(Dir.tmpdir, "lich-membench-#{Process.pid}")

    def self.boot!
      return if @booted

      setup_constants
      setup_globals
      require_core
      @booted = true
    end

    # Load the GS state trackers (infomon, effects, critranks, combat tracker,
    # etc.) the way GameLoader.gemstone does on login. This is where the large
    # static tables are paid for, so we keep it as an explicit, separately
    # measurable step.
    def self.load_gemstone!
      require File.join(LIB_DIR, 'common', 'gameloader')
      Lich::Common::GameLoader.gemstone
    end

    def self.setup_constants
      root = File.expand_path('..', __dir__)
      # LICH_DIR drives the others; constants.rb uses ||= so predefining wins.
      Object.const_set(:LICH_DIR, root) unless defined?(LICH_DIR)
      Object.const_set(:LIB_DIR, File.join(root, 'lib')) unless defined?(LIB_DIR)
      FileUtils.mkdir_p(SANDBOX)
      %i[TEMP_DIR DATA_DIR LOG_DIR BACKUP_DIR MAP_DIR].each do |c|
        dir = File.join(SANDBOX, c.to_s.sub('_DIR', '').downcase)
        FileUtils.mkdir_p(dir)
        # const_defined?(c), not defined?(c): c is a block local (always
        # defined), so defined?(c) would always skip and leave these pointing
        # at the repo dirs via constants.rb's ||=, defeating the sandbox.
        Object.const_set(c, dir) unless Object.const_defined?(c)
      end
      # SCRIPT_DIR points into the sandbox so the thread-churn phase can drop a
      # throwaway .lic for Script.start without polluting the repo's scripts/.
      script_dir = File.join(SANDBOX, 'scripts')
      FileUtils.mkdir_p(File.join(script_dir, 'custom'))
      Object.const_set(:SCRIPT_DIR, script_dir) unless defined?(SCRIPT_DIR)
      $LOAD_PATH.unshift(LIB_DIR) unless $LOAD_PATH.include?(LIB_DIR)
      require File.join(LIB_DIR, 'constants')

      # Seed the effect list from the repo's test fixture so a profiling run is
      # offline/reproducible (effects.rb otherwise fetches it from GitHub).
      fixture = File.join(root, 'spec', 'fixtures', 'effect-list.xml')
      dest = File.join(DATA_DIR, 'effect-list.xml')
      FileUtils.cp(fixture, dest) if File.exist?(fixture) && !File.exist?(dest)
    end

    def self.setup_globals
      # A sink that stands in for the front-end client socket. process_*_hooks
      # write cleaned output here via send_to_client; we just discard it.
      $_CLIENT_ = NullClient.new
      $_DETACHABLE_CLIENT_ = nil
      $frontend = 'wrayth'
      $SEND_CHARACTER = '>'
      $cmd_prefix = '<c>'
      $clean_lich_char = ';'
      $lich_char = ';'
      $infomon_debug = false
    end

    def self.require_core
      req = ->(*parts) { require File.join(LIB_DIR, *parts) }

      # stdlib deps lich.rbw requires before any lib file
      %w[base64 digest/md5 digest/sha1 drb/drb json monitor net/http ostruct
         resolv rexml/document rexml/streamlistener socket stringio
         terminal-table time yaml zlib].each { |dep| require dep }

      # Third-party deps that init.rb would normally pull in.
      require 'sequel'
      require 'sqlite3'

      req.call('version')
      req.call('lich')

      # class extensions used pervasively
      %w[hash matchdata nilclass numeric string stringproc synchronizedsocket].each do |ext|
        req.call('common', 'class_exts', ext)
      end

      req.call('common', 'limitedarray')
      req.call('common', 'xmlparser')
      req.call('common', 'front-end')
      req.call('common', 'upstreamhook')
      req.call('common', 'downstreamhook')
      req.call('common', 'settings')
      req.call('common', 'feature_flags')
      req.call('common', 'settings', 'gamesettings')
      req.call('common', 'settings', 'charsettings')
      req.call('common', 'vars')
      req.call('sessionvars')
      req.call('common', 'script')
      req.call('common', 'watchfor')
      req.call('util', 'util')
      req.call('util', 'opts')
      req.call('util', 'memoryreleaser')
      req.call('messaging')
      req.call('global_defs')
      req.call('common', 'buffer')
      req.call('common', 'sharedbuffer')
      req.call('gemstone', 'spellranks')
      req.call('common', 'socketconfigurator')
      req.call('games')
      req.call('common', 'gameobj')

      # The real parser instance lich.rbw assigns to the XMLData global.
      Object.const_set(:XMLData, Lich::Common::XMLParser.new) unless defined?(XMLData)
      Lich::GameBase::Game.initialize_buffers

      # lich.rbw (include Lich::Common) and main.rb (include Lich::Gemstone /
      # DragonRealms) mix these into the top-level object so production code can
      # reference bare constants like `Effects::Cooldowns`. main.rb is skipped
      # here, so replicate those includes or gemstone trackers fail to load.
      Lich.const_set(:Gemstone, Module.new) unless Lich.const_defined?(:Gemstone)
      Lich.const_set(:DragonRealms, Module.new) unless Lich.const_defined?(:DragonRealms)
      Object.include(Lich::Common, Lich::Gemstone, Lich::DragonRealms)
    end

    # Minimal stand-in for SynchronizedSocket($_CLIENT_): swallows everything
    # the downstream pipeline / respond() tries to send to the front end.
    class NullClient
      def alive?; true; end
      def closed?; false; end
      # respond() loops until puts_if returns truthy, so it must succeed.
      def puts_if(*); true; end
      def method_missing(*); nil; end
      def respond_to_missing?(*); true; end
    end
  end
end
