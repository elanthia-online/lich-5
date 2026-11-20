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
        # Owners under which owner/repo:branch_name may name a repository
        # other than lich-5, so a successor project (e.g.
        # elanthia-online/lich-6) can be installed by opt-in. Any repository
        # under these owners is accepted. Compared case-insensitively, as
        # GitHub owner names are.
        #
        # This limits which repository names are accepted; it is not what
        # decides who may replace lib/. Any owner's lich-5 fork can already
        # be installed with owner:branch_name (or owner/lich-5:branch_name).
        # Kept apart from GemPackages::TRUSTED_OWNERS, which grants
        # unattended installs of script gems. A repository that is not a
        # Lich installation (e.g. scripts) passes this check and is refused
        # before anything is installed unless it has every entry
        # ReleaseInstaller#validate_lich_structure asks for and a
        # lib/version.rb.
        REPO_OWNER_ALLOWLIST = %w[elanthia-online].freeze
        # GitHub owner name characters.
        OWNER_PATTERN = /\A[A-Za-z0-9-]+\z/.freeze
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
        # @param branch_spec [String] 'branch_name', 'owner:branch_name' or
        #   'owner/lich-5:branch_name' (any owner's lich-5 fork), or
        #   'owner/repo:branch_name' for another repository (owner must be in
        #   REPO_OWNER_ALLOWLIST)
        # @return [void]
        def download_branch_update(branch_spec)
          source = resolve_branch_source(branch_spec.strip)
          return unless source

          repo, branch_name = source

          respond
          respond "Attempting to update to branch: #{branch_name}"
          respond "Repository: #{repo}" unless repo.casecmp?(GITHUB_REPO)
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
            # Set once perform_update starts replacing lib/, after which a
            # failure can no longer claim the installation is unchanged.
            installing = false

            begin
              respond
              respond "Downloading branch '#{branch_name}' from GitHub..."
              respond
              extracted_version = Tarball.with_extracted(tarball_url, filename) do |source_dir|
                unless @release_installer.validate_lich_structure(source_dir)
                  raise StandardError, "Downloaded branch does not appear to be a valid Lich installation"
                end

                version_file_path = File.join(source_dir, "lib", "version.rb")
                # Branch tracking is written into it, and #revert refuses a
                # snapshot without it, so a tree without one would leave an
                # install that later updates cannot snapshot and revert.
                unless File.file?(version_file_path)
                  raise StandardError, "Downloaded branch has no lib/version.rb, which this updater needs to track and revert it"
                end

                version = @release_installer.extract_version_from_file(version_file_path)
                # #revert reads a snapshot's version the same way, without
                # running it, and refuses one it cannot read, so falling back
                # to the current version would install a tree whose next
                # snapshot cannot be reverted. The version is also stored and
                # compared with Gem::Version at login, which raises on one
                # like 'v6.0.0', and store_branch_tracking reads the file as
                # text, which fails part way through the install unless it is
                # valid UTF-8.
                utf8 = File.binread(version_file_path).force_encoding(Encoding::UTF_8).valid_encoding?
                unless utf8 && version && Gem::Version.correct?(version)
                  raise StandardError, "Downloaded branch's lib/version.rb must be UTF-8 and assign LICH_VERSION a version number in quotes (e.g. '6.0.0'), which this updater needs to install and revert it"
                end

                respond
                respond "Detected version from branch: #{version}"

                installing = true
                @release_installer.perform_update(source_dir, version, snapshot_dir)

                Lich::Util::Update.store_branch_tracking(branch_name, repo, version)
                version
              end

              respond
              respond "Successfully updated to branch: #{branch_name} (version #{extracted_version})"
              respond "Branch tracking: This installation is now tracking branch '#{branch_name}'"
              respond "                 from repository '#{repo}'" unless repo.casecmp?(GITHUB_REPO)
              respond
              respond_recovery_steps(snapshot_dir)
              respond
              respond "You should exit the game, then log back in to use the updated version."
              respond
              respond "To check your current branch status, run: #{$clean_lich_char}lich5-update --status"
              respond "Enjoy!"
            rescue OpenURI::HTTPError => e
              respond
              respond "Error: Could not download branch '#{branch_name}'"
              respond "HTTP Error: #{e.message}"
              if e.message.start_with?('404')
                respond "Please verify that repository '#{repo}' and its branch '#{branch_name}' exist on GitHub."
                if repo.casecmp?(GITHUB_REPO) && branch_name.include?('/')
                  respond "To install from another repository, use --branch=<owner>/<repo>:<branch_name>."
                end
              end
              respond
            rescue StandardError => e
              respond
              respond "Error during branch update: #{e.message}"
              if installing
                respond "The update failed after it had started replacing your installation."
                respond_recovery_steps(snapshot_dir)
              else
                respond "Your installation has been preserved."
                respond "You may want to run '#{$clean_lich_char}lich5-update --revert' if needed."
              end
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
        # @api private
        def resolve_branch_source(branch_spec)
          source, separator, branch_name = branch_spec.partition(':')
          return incomplete_spec(branch_spec) if source.empty?
          return [GITHUB_REPO, source] if separator.empty?

          source = source.strip
          branch_name = branch_name.strip
          return incomplete_spec(branch_spec) if source.empty? || branch_name.empty?

          unless source.include?('/')
            return [fork_repo(source), branch_name] if OWNER_PATTERN.match?(source)

            respond_usage("Error: '#{source}' is not a valid GitHub owner.")
            return nil
          end

          match = REPO_SPEC_PATTERN.match(source)
          # A clone URL's '.git' is not part of the repository name.
          repo_name = match && match[:repo].sub(/\.git\z/i, '')
          if match.nil? || ['', '.', '..'].include?(repo_name)
            respond_usage("Error: '#{source}' is not a valid owner/repo.")
            return nil
          end

          owner = match[:owner]
          # owner/lich-5 is how GitHub names a fork, so treat it as owner:branch.
          return [fork_repo(owner), branch_name] if repo_name.casecmp?('lich-5')

          unless REPO_OWNER_ALLOWLIST.any? { |allowed| allowed.casecmp?(owner) }
            respond_usage("Error: Repositories other than lich-5 can only be installed from: #{REPO_OWNER_ALLOWLIST.join(', ')}.")
            return nil
          end

          ["#{owner}/#{repo_name}", branch_name]
        end

        # Tells the user where the snapshot taken before this update is, what
        # --revert restores from it and how to put everything back by hand.
        # --revert does not restore the top-level files, and after a restart
        # it runs the installed tree's code, so these steps are the only way
        # back that always works. Each live directory is named on its own, as
        # --lib-dir and --script-dir can move them out of LICH_DIR.
        #
        # @param snapshot_dir [String] snapshot taken before this update
        # @return [void]
        # @api private
        def respond_recovery_steps(snapshot_dir)
          launcher = File.basename($PROGRAM_NAME)
          respond "Your previous installation is saved in: #{snapshot_dir}"
          respond "'#{$clean_lich_char}lich5-update --revert' puts back its lib/, #{launcher} and core scripts, but it"
          respond "may not put back Gemfile, Gemfile.lock and LICENSE; for those, do the last two"
          respond "steps below. If Lich will not start, do all of them, from that folder:"
          respond "  1. Delete #{LIB_DIR}, then copy the folder's lib/ in its place (do not merge)."
          respond "  2. Copy the scripts in the folder's scripts/ into #{SCRIPT_DIR}."
          respond "  3. Copy the folder's #{launcher} and any Gemfile, Gemfile.lock and LICENSE it has into #{LICH_DIR}."
          respond "  4. If the folder has no Gemfile.lock, delete the one in #{LICH_DIR}."
        end

        # Names the lich-5 repository of +owner+.
        #
        # @param owner [String] GitHub owner of a lich-5 fork
        # @return [String] owner/lich-5, spelled as GITHUB_REPO when it is
        #   the main repository, so branch tracking records one spelling
        # @api private
        def fork_repo(owner)
          repo = "#{owner}/lich-5"
          repo.casecmp?(GITHUB_REPO) ? GITHUB_REPO : repo
        end

        # Refuses a spec missing its source or its branch.
        #
        # @param branch_spec [String] spec missing its source or branch
        # @return [nil]
        # @api private
        def incomplete_spec(branch_spec)
          respond_usage("Error: Branch specification is incomplete: '#{branch_spec}'.")
          nil
        end

        # Tells the user why a spec was refused and which forms are accepted.
        #
        # @param error [String] reason the spec was refused
        # @return [void]
        # @api private
        def respond_usage(error)
          respond
          respond error
          respond "Usage: #{$clean_lich_char}lich5-update --branch=<branch_name>"
          respond "   Or: #{$clean_lich_char}lich5-update --branch=<owner>:<branch_name>"
          respond "   Or: #{$clean_lich_char}lich5-update --branch=<owner>/lich-5:<branch_name>"
          respond "   Or: #{$clean_lich_char}lich5-update --branch=<owner>/<repo>:<branch_name>  (other repos; owner: #{REPO_OWNER_ALLOWLIST.join(', ')})"
          respond
        end
      end
    end
  end
end
