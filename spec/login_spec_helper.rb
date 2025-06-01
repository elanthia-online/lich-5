require 'yaml'
require 'fileutils'

# This file is copied to spec/ when you run 'rspec' from the command line.
# It loads the code needed for testing and configures RSpec.

# Add lib directory to load path
$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))

# Require the code to be tested
require 'common/gui-login'
require 'common/gui/account_manager'
require 'common/gui/yaml_state'
require 'common/gui/authentication'

# Configure RSpec
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Use the specified formatter
  config.formatter = :documentation

  # Run specs in random order to surface order dependencies
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option
  Kernel.srand config.seed

  # Clean up test directories after each test
  config.after(:each) do
    # Add any cleanup code here if needed
  end
end

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
end

# Mock EAccess module for authentication testing
module EAccess
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
