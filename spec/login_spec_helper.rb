require 'yaml'
require 'fileutils'

# This file is copied to spec/ when you run 'rspec' from the command line.
# It loads the code needed for testing and configures RSpec.

# Configure RSpec
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = "spec/.rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  # This is a desirable configuration, but requires updating prior specs
  # to operate correctly since our early efforts basically did exactly this
  # config.disable_monkey_patching!

  # Use the specified formatter
  config.formatter = :documentation

  # Run specs in random order to surface order dependencies
  # This is a desirable configuration, but requires updating prior specs
  # to operate correctly since order dependencies do exist in some tests
  # config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option
  Kernel.srand config.seed

  # Add specific stubs that may be required during testing
  config.before(:each) do
    # Ensure that the FFI::Library module is available for extension.
    # If the real FFI gem is loaded, this block does nothing.
    # If not, our dummy FFI::Library is used.

    # Stub the `extend` method on the module under test to control what happens
    # when it tries to extend FFI::Library.
    allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:extend).and_wrap_original do |original_method, *args|
      if args.include?(FFI::Library)
        # When FFI::Library is extended, we can specifically mock its methods.
        # Here, we ensure ffi_lib and attach_function are available for mocking.
        # This is where you would define specific test doubles for these methods.
        allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:ffi_lib)
        allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:attach_function)
        # You can also allow the original extend call to happen if you want the dummy methods to be added.
        original_method.call(*args)
      else
        original_method.call(*args)
      end
    end
  end

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

  module Util
    def self.install_gem_requirements(*)
      # Mock implementation for testing
      true
    end
  end
end

# Override EAccess mock in the correct namespace after requires
module Lich
  module Common
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

# This block ensures that FFI and FFI::Library are defined, even if the ffi gem is not loaded.
# This prevents NameError when `extend FFI::Library` is called in a test environment
# where the gem might not be available.
unless defined?(FFI)
  module FFI
    module Library
      # Define dummy methods that FFI::Library would normally provide.
      # These methods can then be stubbed or mocked by RSpec as needed.
      def ffi_lib(*_args)
        # In a test, you might want to return a mock object or simply do nothing.
        # For now, we'll just return self to allow chaining if necessary.
        self
      end

      def attach_function(*_args)
        # Similarly, return a mock or do nothing.
        # This allows RSpec to expect calls to attach_function.
        nil
      end

      # Add other commonly used FFI::Library methods here if your code uses them,
      # e.g., typedef, callback, attach_variable, etc.
      def typedef(*_args); end
      def callback(*_args); end
      def attach_variable(*_args); end
    end
  end
end

# Add lib directory to load path
$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))

# Define LIB_DIR for code that references it
LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib')

# Require the code to be tested
require 'common/gui-login'
require 'common/gui/account_manager'
require 'common/gui/yaml_state'
require 'common/gui/authentication'
