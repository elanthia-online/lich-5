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
          name = safe_name(name)
          tarball_path = File.join(TEMP_DIR, "#{name}.tar.gz")
          extract_dir = File.join(TEMP_DIR, name)
          remove(extract_dir, tarball_path)
          download(url, tarball_path)
          yield Lich::Archive.extract_tar_gz_root(tarball_path, extract_dir)
        ensure
          remove(extract_dir, tarball_path) if tarball_path
        end

        # The base name for TEMP_DIR entries, which are deleted before the
        # download. The name comes from what the player typed (a branch name
        # for --branch), so anything but letters, digits, ".", "_" and "-"
        # becomes "-": on Windows x\..\..\data would otherwise resolve
        # to Lich's data directory and be deleted. Trailing dots become "-"
        # as well, since Windows drops them (TEMP_DIR/... is TEMP_DIR), and a
        # Windows device name gets a prefix.
        # @param name [String]
        # @return [String] a single path segment that names an entry strictly
        #   inside TEMP_DIR
        # @raise [ArgumentError] when nothing usable is left
        def safe_name(name)
          safe = name.to_s.gsub(/[^A-Za-z0-9._-]/, '-').sub(/\.+\z/) { |dots| '-' * dots.length }
          raise ArgumentError, "unusable name for the update download: #{name.inspect}" if safe.empty?

          safe = "lich5-#{safe}" if Lich::Archive.unsafe_segment?(safe)
          root = File.expand_path(TEMP_DIR)
          unless File.dirname(File.expand_path(safe, root)) == root
            raise ArgumentError, "unusable name for the update download: #{name.inspect}"
          end

          safe
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
