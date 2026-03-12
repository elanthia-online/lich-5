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

# Mock classes and modules needed for testing
module Lich
  def self.log(message)
    # Mock implementation for testing
  end

  def self.track_autosort_state
    # Mock implementation for testing
    false
  end

  def self.track_layout_state
    # Mock implementation for testing
    false
  end

  def self.track_dark_mode
    # Mock implementation for testing
    false
  end

  module Util
    def self.install_gem_requirements(*)
      # Mock implementation for testing (for login = 'os' and 'ffi'
      require 'os' # included in Lich-5 EO worker gemspec
      require 'ffi' # included in Lich-5 EO worker gemspec
      true
    end
  end
end

# Override EAccess mock in the correct namespace after requires
# Only define stub auth if EAccess doesn't have a real auth method yet
module Lich
  module Common
    module Authentication
      module EAccess
        # Only define stub if auth method doesn't exist or doesn't have keyword params
        unless respond_to?(:auth) && method(:auth).parameters.any? { |type, _| type == :keyreq }
          def self.auth(_options = {})
            # Mock implementation for testing
            {
              "key"          => "test_key",
              "server"       => "test.example.com",
              "port"         => "8080",
              "gamefile"     => "STORM.EXE",
              "game"         => "STORM",
              "fullgamename" => "StormFront"
            }
          end
        end
      end
    end
  end
end

# Mock Gtk module for GUI testing
module Gtk
  def self.queue
    # Mock implementation for testing
    yield if block_given?
  end

  def self.main_quit
    # Mock implementation for testing
  end

  class Window
    def initialize(type)
      # Mock implementation for testing
    end

    def set_icon(icon)
      # Mock implementation for testing
    end

    def title=(title)
      # Mock implementation for testing
    end

    def border_width=(width)
      # Mock implementation for testing
    end

    def add(widget)
      # Mock implementation for testing
    end

    def signal_connect(signal, &block)
      # Mock implementation for testing
    end

    def default_width=(width)
      # Mock implementation for testing
    end

    def default_height=(height)
      # Mock implementation for testing
    end

    def override_background_color(state, color)
      # Mock implementation for testing
    end

    def show_all
      # Mock implementation for testing
    end

    def destroy
      # Mock implementation for testing
    end
  end

  class Notebook
    def initialize
      # Mock implementation for testing
    end

    def override_background_color(state, color)
      # Mock implementation for testing
    end

    def append_page(widget, label)
      # Mock implementation for testing
    end

    def set_tab_pos(position)
      # Mock implementation for testing
    end

    def set_page(page)
      # Mock implementation for testing
    end
  end

  class Label
    def initialize(text)
      # Mock implementation for testing
    end
  end

  class Box
    def initialize(orientation, spacing)
      # Mock implementation for testing
    end

    def border_width=(width)
      # Mock implementation for testing
    end

    def pack_start(widget, options = {})
      # Mock implementation for testing
    end
  end

  class Button
    def initialize(label = nil)
      # Mock implementation for testing
    end

    def override_background_color(state, color)
      # Mock implementation for testing
    end
  end
end

# Mock Gdk module for GUI testing
module Gdk
  class RGBA
    def self.parse(_color_string)
      # Mock implementation for testing
      new
    end
  end
end

# Add lib directory to load path
$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))

# Define LIB_DIR for code that references it
LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib') unless defined?(LIB_DIR)

# Require the code to be tested
require 'common/gui_login'
require 'common/gui/account_manager'
require 'common/authentication/entry_store'
require 'common/authentication/authenticator'
require 'common/authentication/launch_data'
