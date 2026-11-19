# frozen_string_literal: true

=begin
  Handles installation of Lich5 from arbitrary GitHub branches.

  Supports main repository branches, fork branches via owner:branch_name
  syntax, and other repositories under an allowlisted owner via
  owner/repo:branch_name syntax. Downloads tarball archives, validates
  structure, and delegates to ReleaseInstaller for actual installation.
=end

module Lich
  module Util
    module Update
      class BranchInstaller
        # Owners whose repositories may be named with owner/repo:branch_name.
        # Any repository under these owners is accepted, so a successor
        # project (e.g. elanthia-online/lich-6) can be installed by opt-in.
        # Compared case-insensitively, as GitHub owner names are. Kept apart
        # from GemPackages::TRUSTED_OWNERS: that list grants unattended
        # installs of script gems, this one an opt-in replacement of lib/.
        # Repositories that are not Lich installations (e.g. scripts) pass
        # this check and are refused by validate_lich_structure before
        # anything is installed.
        REPO_OWNER_ALLOWLIST = %w[elanthia-online].freeze
        # GitHub owner and repository name characters.
        REPO_SPEC_PATTERN = %r{\A(?<owner>[A-Za-z0-9-]+)/(?<repo>[A-Za-z0-9._-]+)\z}.freeze

        # @param snapshot_manager [SnapshotManager] snapshot management instance
        # @param release_installer [ReleaseInstaller] installer for performing updates
        def initialize(snapshot_manager, release_installer)
          @snapshot_manager = snapshot_manager
          @release_installer = release_installer
        end

        # Downloads and installs from a GitHub branch.
        #
        # @param branch_spec [String] 'branch_name', 'owner:branch_name' (a
        #   lich-5 fork) or 'owner/repo:branch_name' (owner must be in
        #   REPO_OWNER_ALLOWLIST)
        # @return [void]
        def download_branch_update(branch_spec)
          source = resolve_branch_source(branch_spec.strip)
          return unless source

          repo, branch_name = source

          respond
          respond "Attempting to update to branch: #{branch_name}"
          respond "Repository: #{repo}" unless repo == GITHUB_REPO
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
              respond "                 from repository '#{repo}'" unless repo == GITHUB_REPO
              respond "You should exit the game, then log back in to use the updated version."
              respond
              respond "To check your current branch status, run: #{$clean_lich_char}lich5-update --status"
              respond "Enjoy!"
            rescue OpenURI::HTTPError => e
              respond
              respond "Error: Could not download branch '#{branch_name}'"
              respond "HTTP Error: #{e.message}"
              respond "Please verify that repository '#{repo}' and its branch '#{branch_name}' exist on GitHub."
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

        private

        # Splits a branch spec into the repository and branch to download.
        # Git ref names cannot contain ':', so the first ':' separates the
        # source from the branch, and a branch may itself contain '/'.
        #
        # @param branch_spec [String] stripped branch spec
        # @return [Array(String, String), nil] [owner/repo, branch_name], or
        #   nil after telling the user why the spec was refused
        def resolve_branch_source(branch_spec)
          source, separator, branch_name = branch_spec.partition(':')
          return incomplete_spec(branch_spec) if source.empty?
          return [GITHUB_REPO, source] if separator.empty?

          source = source.strip
          branch_name = branch_name.strip
          return incomplete_spec(branch_spec) if source.empty? || branch_name.empty?

          return ["#{source}/lich-5", branch_name] unless source.include?('/')

          match = REPO_SPEC_PATTERN.match(source)
          if match.nil? || %w[. ..].include?(match[:repo])
            respond_usage("Error: '#{source}' is not a valid owner/repo.")
            return nil
          end

          unless REPO_OWNER_ALLOWLIST.any? { |allowed| allowed.casecmp?(match[:owner]) }
            respond_usage("Error: Repositories other than lich-5 can only be installed from: #{REPO_OWNER_ALLOWLIST.join(', ')}.")
            return nil
          end

          [source, branch_name]
        end

        # @param branch_spec [String] spec missing its source or branch
        # @return [nil]
        def incomplete_spec(branch_spec)
          respond_usage("Error: Branch specification is incomplete: '#{branch_spec}'.")
          nil
        end

        # @param error [String] reason the spec was refused
        # @return [void]
        def respond_usage(error)
          respond
          respond error
          respond "Usage: #{$clean_lich_char}lich5-update --branch=<branch_name>"
          respond "   Or: #{$clean_lich_char}lich5-update --branch=<owner>:<branch_name>"
          respond "   Or: #{$clean_lich_char}lich5-update --branch=<owner>/<repo>:<branch_name>  (owner: #{REPO_OWNER_ALLOWLIST.join(', ')})"
          respond
        end
      end
    end
  end
end
