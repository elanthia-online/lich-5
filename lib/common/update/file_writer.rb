# frozen_string_literal: true

=begin
  Atomic file writing utilities for the update system.

  Provides safe_write (tmp-rename-delete pattern) and SHA map building
  for detecting file changes.
=end

module Lich
  module Util
    module Update
      module FileWriter
        # Atomically writes content to file with rollback on error.
        #
        # @param path [String] target file path
        # @param content [String] file content to write
        # @return [void]
        # @raise [StandardError] if write fails (original file restored)
        def self.safe_write(path, content)
          tmp = "#{path}.tmp"
          old = "#{path}.old"
          File.rename(path, old) if File.exist?(path)
          begin
            File.binwrite(tmp, content)
            File.rename(tmp, path)
          rescue StandardError
            File.rename(old, path) if File.exist?(old)
            File.delete(tmp) if File.exist?(tmp)
            raise
          end
          File.delete(old) if File.exist?(old)
        end

        # Builds filename => git-SHA map for files in directory.
        #
        # @param dir [String] directory path
        # @param pattern [String] glob pattern (default: '*.lic')
        # @return [Hash<String, String>] filename => SHA1 hash
        def self.build_local_sha_map(dir, pattern = '*.lic')
          Dir[File.join(dir, pattern)].each_with_object({}) do |path, map|
            body = File.binread(path)
            map[File.basename(path)] = Digest::SHA1.hexdigest("blob #{body.size}\0#{body}")
          end
        end
      end
    end
  end
end
