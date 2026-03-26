# frozen_string_literal: true

# Shared stubs for Lich runtime dependencies needed by update system specs.
# Required by all spec files under spec/lib/common/update/.

require 'digest'
require 'fileutils'
require 'tmpdir'

LICH_VERSION = '5.15.1' unless defined?(LICH_VERSION)
SCRIPT_DIR = Dir.mktmpdir('lich-scripts') unless defined?(SCRIPT_DIR)
DATA_DIR = Dir.mktmpdir('lich-data') unless defined?(DATA_DIR)
BACKUP_DIR = Dir.mktmpdir('lich-backup') unless defined?(BACKUP_DIR)
LICH_DIR = Dir.mktmpdir('lich-root') unless defined?(LICH_DIR)
TEMP_DIR = Dir.mktmpdir('lich-temp') unless defined?(TEMP_DIR)
LIB_DIR = Dir.mktmpdir('lich-lib') unless defined?(LIB_DIR)

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
