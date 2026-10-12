# frozen_string_literal: true

# Shared stubs for Lich runtime dependencies needed by update system specs.
# Required by all spec files under spec/lib/common/update/.

require 'digest'
require 'fileutils'
require 'tmpdir'
require 'terminal-table'

LICH_VERSION = '5.15.1' unless defined?(LICH_VERSION)
SCRIPT_DIR = Dir.mktmpdir('lich-scripts') unless defined?(SCRIPT_DIR)
require_relative '../../../support/data_dir'
BACKUP_DIR = Dir.mktmpdir('lich-backup') unless defined?(BACKUP_DIR)
LICH_DIR = Dir.mktmpdir('lich-root') unless defined?(LICH_DIR)
TEMP_DIR = Dir.mktmpdir('lich-temp') unless defined?(TEMP_DIR)
# LIB_DIR is shared with spec_helper, where it is the real lib/ directory that
# other specs load source from, so this file must not redefine it for the
# whole process. The update code copies into and deletes from LIB_DIR, so
# each update example gets its own throwaway LIB_DIR instead.
LIB_DIR = File.expand_path('../../../../lib', __dir__) unless defined?(LIB_DIR)

RSpec.configure do |config|
  config.before(:each, file_path: %r{/spec/lib/common/update/}) do
    @update_spec_lib_dir = Dir.mktmpdir('lich-lib')
    stub_const('LIB_DIR', @update_spec_lib_dir)
  end

  config.after(:each, file_path: %r{/spec/lib/common/update/}) do
    FileUtils.remove_entry(@update_spec_lib_dir, true) if @update_spec_lib_dir
  end
end

unless defined?(UserVars)
  module UserVars
    @store = {}

    def self.method_missing(name, *args)
      if name.to_s.end_with?('=')
        @store[name.to_s.chomp('=')] = args.first
      else
        @store[name.to_s]
      end
    end

    def self.respond_to_missing?(*)
      true
    end
  end
end

unless defined?(Vars)
  module Vars
    def self.save; end
  end
end

unless defined?(XMLData)
  module XMLData
    @game = 'DR'

    def self.game
      @game
    end

    def self.game=(val)
      @game = val
    end
  end
end

def respond(msg = ''); end unless defined?(respond)

require_relative '../../../../lib/update'

module UpdateSpecHelpers
  def git_blob_sha(content)
    Digest::SHA1.hexdigest("blob #{content.bytesize}\0#{content}")
  end
end

RSpec.configure do |config|
  config.include UpdateSpecHelpers
end
