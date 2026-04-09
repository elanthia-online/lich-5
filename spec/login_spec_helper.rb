# frozen_string_literal: true

require 'yaml'
require 'fileutils'

# login_spec_helper.rb - GUI and authentication test support
#
# Provides mocks for Gtk, Gdk, and login-related Lich infrastructure that
# cannot run without a display/OS GUI. Required by specs under:
#   spec/lib/common/gui/          - GUI component specs
#   spec/lib/common/authentication/ - login flow specs
#   spec/lib/common/gui_login_spec.rb
#
# Always require AFTER spec_helper so that spec_helper's RSpec.configure
# (which enables random ordering and global state resets) takes precedence.
#
# NOTE: This file intentionally does NOT define an RSpec.configure block.
# All RSpec configuration lives in spec/spec_helper.rb.

# Lich stubs for GUI/auth specs. Each method is individually guarded so this
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
      require 'os'
      require 'ffi'
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

# Gtk/Gdk stubs — empty implementations satisfy constant lookups and method calls
# made by production GUI code at load time and during tests.
module Gtk
  def self.queue; yield if block_given?; end
  def self.main_quit; end
  def self.lich_main_quit; end

  class Window
    def initialize(_type); end
    def set_icon(_icon); end
    def title=(_title); end
    def border_width=(_width); end
    def add(_widget); end
    def signal_connect(_signal, &_block); end
    def default_width=(_width); end
    def default_height=(_height); end
    def override_background_color(_state, _color); end
    def show_all; end
    def destroy; end
  end

  class Notebook
    def initialize; end
    def override_background_color(_state, _color); end
    def append_page(_widget, _label); end
    def set_tab_pos(_position); end
    def set_page(_page); end
  end

  class Label
    def initialize(_text); end
  end

  class Box
    def initialize(_orientation, _spacing); end
    def border_width=(_width); end
    def pack_start(_widget, _options = {}); end
  end

  class Button
    def initialize(_label = nil); end
    def override_background_color(_state, _color); end
  end
end

module Gdk
  class RGBA
    def self.parse(_color_string)
      new
    end
  end
end

# spec_helper already adds LIB_DIR to $LOAD_PATH. These guards ensure this file
# also works when loaded standalone (e.g. without spec_helper, for auth-only runs).
$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__)) unless $LOAD_PATH.include?(File.expand_path('../lib', __FILE__))
LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib') unless defined?(LIB_DIR)

# Load production code AFTER Gtk/Gdk mocks are defined above.
# These files reference Gtk:: constants at load time; loading them before the mocks
# exist causes NameError. Individual specs must NOT require these files themselves —
# they must rely on this ordered load to ensure the mock environment is in place.
require 'common/gui_login'
require 'common/gui/account_manager'
require 'common/authentication/entry_store'
require 'common/authentication/authenticator'
require 'common/authentication/launch_data'
