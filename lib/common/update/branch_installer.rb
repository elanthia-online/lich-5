# frozen_string_literal: true

=begin
  Handles installation of Lich5 from arbitrary GitHub branches.

  Supports both main repository branches and fork branches via
  owner:branch_name syntax. Downloads tarball archives, validates
  structure, and delegates to ReleaseInstaller for actual installation.
=end

module Lich
  module Util
    module Update
      class BranchInstaller
        # @param snapshot_manager [SnapshotManager] snapshot management instance
        # @param release_installer [ReleaseInstaller] installer for performing updates
        def initialize(snapshot_manager, release_installer)
          @snapshot_manager = snapshot_manager
          @release_installer = release_installer
        end

        # Downloads and installs from a GitHub branch.
        #
        # @param branch_spec [String] branch name or 'owner:branch_name'
        # @return [void]
        def download_branch_update(branch_spec)
          branch_spec = branch_spec.strip
          if branch_spec.empty?
            respond
            respond "Error: Branch specification cannot be empty."
            respond "Usage: #{$clean_lich_char}lich5-update --branch=<branch_name>"
            respond "   Or: #{$clean_lich_char}lich5-update --branch=<owner>:<branch_name>"
            respond
            return
          end

          if branch_spec.include?(':')
            owner, branch_name = branch_spec.split(':', 2)
            repo = "#{owner}/lich-5"
          else
            owner = nil
            branch_name = branch_spec
            repo = GITHUB_REPO
          end

          respond
          respond "Attempting to update to branch: #{branch_name}"
          respond "Repository: #{repo}" if owner
          respond "This will download from GitHub and extract over your current installation."
          respond

          # The snapshot holds the revert lock until the block returns, so a
          # revert in another session cannot swap lib/ during the download or
          # the install.
          @snapshot_manager.snapshot do |snapshot_dir|
            require 'erb'
            encoded_branch_name = ERB::Util.url_encode(branch_name)
            tarball_url = "https://github.com/#{repo}/archive/refs/heads/#{encoded_branch_name}.tar.gz"

            sanitized_branch = branch_name.gsub('/', '-')
            filename = "lich5-branch-#{sanitized_branch}"

            begin
              respond
              respond "Downloading branch '#{branch_name}' from GitHub..."
              respond
              extracted_version = Tarball.with_extracted(tarball_url, filename) do |source_dir|
                unless @release_installer.validate_lich_structure(source_dir)
                  raise StandardError, "Downloaded branch does not appear to be a valid Lich installation"
                end

                version_file_path = File.join(source_dir, "lib", "version.rb")
                version = @release_installer.extract_version_from_file(version_file_path)

                if version.nil?
                  respond
                  respond "Warning: Could not extract version from branch's version.rb file."
                  respond "Using existing Lich version identifier: #{LICH_VERSION}"
                  version = LICH_VERSION
                else
                  respond
                  respond "Detected version from branch: #{version}"
                end

                @release_installer.perform_update(source_dir, version, snapshot_dir)

                Lich::Util::Update.store_branch_tracking(branch_name, repo, version)
                version
              end

              respond
              respond "Successfully updated to branch: #{branch_name} (version #{extracted_version})"
              respond "Branch tracking: This installation is now tracking branch '#{branch_name}'"
              respond "                 from repository '#{repo}'" if owner
              respond "You should exit the game, then log back in to use the updated version."
              respond
              respond "To check your current branch status, run: #{$clean_lich_char}lich5-update --status"
              respond "Enjoy!"
            rescue OpenURI::HTTPError => e
              respond
              respond "Error: Could not download branch '#{branch_name}'"
              respond "HTTP Error: #{e.message}"
              respond "Please verify the branch name exists on GitHub."
              respond
            rescue StandardError => e
              respond
              respond "Error during branch update: #{e.message}"
              respond "Your installation has been preserved."
              respond "You may want to run '#{$clean_lich_char}lich5-update --revert' if needed."
              respond
            end
          end
        end
      end
    end
  end
end
