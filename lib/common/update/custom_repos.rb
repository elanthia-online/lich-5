# frozen_string_literal: true

=begin
  Manages user-registered custom (3rd-party) script repositories.

  Users can register arbitrary GitHub repos and track individual .lic files
  from them. Custom repo scripts are synced into per-repo subdirectories
  under SCRIPT_DIR/custom/.
=end

module Lich
  module Util
    module Update
      class CustomRepos
        # Converts owner/repo to a filesystem-safe directory name.
        #
        # @param owner_repo [String] e.g. "MahtraDR/dr-scripts"
        # @return [String] e.g. "MahtraDR-dr-scripts"
        def self.repo_dir_name(owner_repo)
          owner_repo.gsub('/', '-')
        end

        # Returns the destination directory for a custom repo's scripts.
        #
        # @param owner_repo [String] e.g. "MahtraDR/dr-scripts"
        # @return [String] absolute path
        def self.dest_dir(owner_repo)
          File.join(SCRIPT_DIR, 'custom', repo_dir_name(owner_repo))
        end

        # Builds a SCRIPT_REPOS-compatible config hash for a custom repo.
        #
        # @param owner_repo [String] e.g. "MahtraDR/dr-scripts"
        # @param registration [Hash] stored registration with :branch key
        # @return [Hash] config hash matching SCRIPT_REPOS entry shape
        def self.build_config(owner_repo, registration)
          branch = registration[:branch] || registration['branch'] || 'main'
          {
            display_name: "Custom: #{owner_repo}",
            api_url: "https://api.github.com/repos/#{owner_repo}/git/trees/#{branch}?recursive=1",
            raw_base_url: "https://raw.githubusercontent.com/#{owner_repo}/#{branch}",
            tracking_mode: :explicit,
            script_pattern: /^[^\/]+\.lic$/,
            game_filter: nil,
            default_tracked: [],
            subdirs: {},
            custom: true,
            dest_dir: dest_dir(owner_repo)
          }
        end

        # Returns all registered custom repos from UserVars.
        #
        # @return [Hash] owner_repo => registration hash
        def self.all
          UserVars.custom_repos || {}
        end

        # Registers a custom repository.
        #
        # @param owner_repo [String] "owner/repo" format
        # @param branch [String, nil] branch name (default: "main")
        # @return [void]
        def add_custom_repo(owner_repo, branch = nil)
          unless owner_repo =~ %r{^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$}
            StatusReporter.respond_mono("[lich5-update: Invalid format '#{owner_repo}'. Use owner/repo (e.g. MahtraDR/dr-scripts).]")
            return
          end

          UserVars.custom_repos ||= {}
          if UserVars.custom_repos[owner_repo]
            StatusReporter.respond_mono("[lich5-update: '#{owner_repo}' is already registered.]")
            return
          end

          UserVars.custom_repos[owner_repo] = {
            'branch'   => branch || 'main',
            'added_at' => Time.now.strftime('%Y-%m-%d')
          }
          Vars.save
          StatusReporter.respond_mono("[lich5-update: Registered custom repo '#{owner_repo}' (branch: #{branch || 'main'}).]")
        end

        # Unregisters a custom repository.
        #
        # @param owner_repo [String] "owner/repo" format
        # @return [void]
        def remove_custom_repo(owner_repo)
          UserVars.custom_repos ||= {}
          unless UserVars.custom_repos.delete(owner_repo)
            StatusReporter.respond_mono("[lich5-update: '#{owner_repo}' is not a registered custom repo.]")
            return
          end

          # Clean up tracked scripts for this repo
          UserVars.tracked_scripts&.delete(owner_repo)
          Vars.save

          dest = self.class.dest_dir(owner_repo)
          if File.directory?(dest)
            files = Dir.children(dest).select { |f| f.end_with?('.lic') }
            if files.any?
              StatusReporter.respond_mono("[lich5-update: Note: #{files.length} script(s) still installed in #{dest}. Delete manually if no longer needed.]")
            end
          end

          StatusReporter.respond_mono("[lich5-update: Removed custom repo '#{owner_repo}'.]")
        end

        # Displays registered custom repos in a table.
        #
        # @return [void]
        def list_custom_repos
          repos = self.class.all
          if repos.empty?
            StatusReporter.respond_mono("[lich5-update: No custom repos registered. Use --add-custom=owner/repo to add one.]")
            return
          end

          table_rows = []
          table_rows << ['Repository', 'Branch', 'Added', 'Scripts']
          table_rows << :separator

          repos.each do |owner_repo, reg|
            branch = reg[:branch] || reg['branch'] || 'main'
            added = reg[:added_at] || reg['added_at'] || '?'
            tracked = (UserVars.tracked_scripts&.dig(owner_repo) || []).length
            dest = self.class.dest_dir(owner_repo)
            installed = File.directory?(dest) ? Dir.children(dest).count { |f| f.end_with?('.lic') } : 0
            table_rows << [owner_repo, branch, added, "#{tracked} tracked, #{installed} installed"]
          end

          table = Terminal::Table.new(title: 'Custom Repositories', rows: table_rows)
          StatusReporter.respond_mono(table.to_s)
        end
      end
    end
  end
end
