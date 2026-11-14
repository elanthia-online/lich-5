# frozen_string_literal: true

require 'yaml'
require 'fileutils'
# Load shared runtime prerequisites independently of per-spec install stubs.
require 'os'
require 'ffi'

# Authentication test support; no global graphical toolkit constants.
# Lich stubs for authentication specs. Each method is individually guarded so this
# file is safe to load before OR after spec_helper without clobbering methods
# that spec_helper defines (e.g. the debug-logging Lich.log).
module Lich
  def self.log(_message); end unless respond_to?(:log)
  def self.track_autosort_state; false; end unless respond_to?(:track_autosort_state)
  def self.track_layout_state; false; end unless respond_to?(:track_layout_state)
  def self.track_dark_mode; false; end unless respond_to?(:track_dark_mode)

  def self.track_persistent_launcher_mode
    # Default launcher mode state for tests: preserve existing single-launch behavior
    # unless a spec explicitly overrides this to exercise persistent mode.
    false
  end

  module Util
    def self.install_gem_requirements(*)
      true
    end unless respond_to?(:install_gem_requirements)
  end
end

# Override EAccess mock in the correct namespace after requires
# Only define stub auth if EAccess doesn't have a real auth method yet
module Lich
  module Common
    module Authentication
      module EAccess
        def self.auth(_options = {})
          {
            "key"          => "test_key",
            "server"       => "test.example.com",
            "port"         => "8080",
            "gamefile"     => "STORM.EXE",
            "game"         => "STORM",
            "fullgamename" => "StormFront"
          }
        end unless respond_to?(:auth)
      end
    end
  end
end

# spec_helper already adds LIB_DIR to $LOAD_PATH. These guards ensure this file
# also works when loaded standalone (e.g. without spec_helper, for auth-only runs).
$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__)) unless $LOAD_PATH.include?(File.expand_path('../lib', __FILE__))
LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib') unless defined?(LIB_DIR)

# ::Frontend must be the spec mock before account_manager loads the real
# frontend.rb, or the real one takes the top-level name for the whole process.
require_relative 'support/frontend_mock'

# Load toolkit-independent authentication and persistence code. AccountManager
# and EntryStore call GUI::Utilities without requiring it; production loads it
# earlier, so load it here for specs that run without another file first.
require 'common/gui/utilities'
require 'common/gui/account_manager'
require 'common/authentication/entry_store'
require 'common/authentication/authenticator'
require 'common/authentication/launch_data'
