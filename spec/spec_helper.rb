# frozen_string_literal: true

# RSpec configuration for Lich 5 test suite
# Provides common setup, mocks, and helpers for all spec files

# Add lib directory to load path
$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))

# Require core Lich modules
require 'os'

# Configure RSpec
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = 'spec/.rspec_status'

  # Use documentation formatter
  config.formatter = :documentation

  # Disable monkey patching to keep tests clean
  # config.disable_monkey_patching!

  # Seed global randomization in this process using the --seed CLI option
  Kernel.srand config.seed

  # Clean up after each test
  config.after(:each) do
    # Reset mocks and stubs
  end
end

# Mock Lich module for testing
module Lich
  # Logging mock - captures log messages for testing
  @log_messages = []

  def self.log(message)
    @log_messages << message
  end

  def self.clear_logs
    @log_messages = []
  end

  def self.log_messages
    @log_messages
  end

  def self.track_autosort_state
    false
  end

  def self.track_layout_state
    false
  end

  def self.track_dark_mode
    false
  end

  def self.mutex_lock
    yield if block_given?
  end

  def self.mutex_unlock; end
end

# OS module is already loaded from the 'os' gem
# Tests use allow(OS).to receive(:windows?) to mock platform-specific behavior
