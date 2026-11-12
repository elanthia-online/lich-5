# frozen_string_literal: true

require 'fileutils'
require 'open-uri'
require_relative '../../archive'

module Lich
  module Util
    module Update
      # Downloads a GitHub release or branch tarball into TEMP_DIR and
      # extracts it with Lich::Archive, for ReleaseInstaller and
      # BranchInstaller alike.
      module Tarball
        module_function

        # Yields the extracted archive's top-level directory, then removes the
        # tarball and the extraction directory however the block ends.
        # Leftovers from an interrupted earlier run under the same +name+ are
        # removed first, so they cannot mix with this download.
        #
        # @param url [String] tarball URL
        # @param name [String] base name for the files under TEMP_DIR
        # @yieldparam source_dir [String] the archive's top-level directory
        # @return [Object] the block's value
        # @raise [Lich::Archive::Error] when the archive is corrupt or unsafe
        # @raise [OpenURI::HTTPError, SocketError, SystemCallError] when the
        #   download fails
        def with_extracted(url, name)
          tarball_path = File.join(TEMP_DIR, "#{name}.tar.gz")
          extract_dir = File.join(TEMP_DIR, name)
          remove(extract_dir, tarball_path)
          download(url, tarball_path)
          yield Lich::Archive.extract_tar_gz_root(tarball_path, extract_dir)
        ensure
          remove(extract_dir, tarball_path) if tarball_path
        end

        # @param url [String]
        # @param path [String]
        # @return [void]
        def download(url, path)
          remote = URI.parse(url).open(**GitHubClient.open_uri_timeouts)
          File.open(path, 'wb') { |file| IO.copy_stream(remote, file) }
        ensure
          remote.close if remote.respond_to?(:close) && !(remote.respond_to?(:closed?) && remote.closed?)
        end

        # Best effort (rm_rf ignores failures): a file Windows still holds
        # open is removed by the next run's pre-download cleanup instead of
        # failing this update.
        # @param paths [Array<String>]
        # @return [void]
        def remove(*paths)
          FileUtils.rm_rf(paths)
        end
      end
    end
  end
end
