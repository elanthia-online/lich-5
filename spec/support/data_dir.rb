# frozen_string_literal: true

# The one definition of DATA_DIR for the spec suite.
#
# Each RSpec process gets its own throwaway directory, so parallel workers (and
# two local runs at once) never share settings databases, map files or caches.
# Specs that load production code which reads DATA_DIR at load time require
# this file before that code, whether or not they also load spec_helper.

require 'tmpdir'
require 'fileutils'

unless defined?(DATA_DIR)
  DATA_DIR = Dir.mktmpdir("lich-spec-data#{ENV.fetch('TEST_ENV_NUMBER', '')}-")
  spec_data_dir_owner = Process.pid
  # Forked children (probes, handoff specs) must not delete the parent's directory.
  at_exit { FileUtils.remove_entry(DATA_DIR, true) if Process.pid == spec_data_dir_owner }
end
