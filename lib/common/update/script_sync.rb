# frozen_string_literal: true

=begin
  Bulk SHA-based repository sync for script repositories.

  Downloads scripts and data files from configured SCRIPT_REPOS and
  user-registered custom repos, skipping files that match local SHA1.
  Supports both :all (auto-sync all .lic) and :explicit (tracked list) modes.
=end

module Lich
  module Util
    module Update
      class ScriptSync
        # @param client [GitHubClient] GitHub API client instance
        def initialize(client)
          @client = client
        end

        # Syncs all registered repositories (built-in + custom) for current game.
        # Stops at the first GitHub-wide failure: the remaining repos would
        # fail the same way, and one message is enough.
        #
        # @return [void]
        def sync_all_repos
          synced = false
          (SCRIPT_REPOS.keys + CustomRepos.all.keys).each do |repo_key|
            result = sync_repo(repo_key, after_synced_repo: synced)
            break if result == :github_unavailable

            synced ||= result == :synced
          end
        end

        # Syncs a single repository by key (built-in or custom).
        #
        # @param repo_key [String] repository key from SCRIPT_REPOS or custom repo
        # @param force [Boolean] skip SHA check and download all (default: false)
        # @param after_synced_repo [Boolean] an earlier repo already synced this run,
        #   so a GitHub failure must not claim nothing was updated (default: false)
        # @return [Symbol, nil] :synced, :github_unavailable when GitHub itself
        #   failed, or nil when the repo was skipped
        def sync_repo(repo_key, force: false, after_synced_repo: false)
          config = SCRIPT_REPOS[repo_key]
          unless config
            # Check custom repos
            reg = CustomRepos.all[repo_key]
            if reg
              config = CustomRepos.build_config(repo_key, reg)
            else
              known = (SCRIPT_REPOS.keys + CustomRepos.all.keys).join(', ')
              respond "[lich5-update: Unknown repository '#{repo_key}'. Known: #{known}]"
              return
            end
          end

          if config[:game_filter] && XMLData.game !~ config[:game_filter]
            return
          end

          name = config[:display_name] || repo_key
          tree_data = @client.fetch_github_json(config[:api_url])
          unless tree_data && tree_data['tree']
            error = @client.last_error
            if error && !error.global?
              StatusReporter.respond_github_failure(error, "No scripts were updated from #{name}.", subject: name)
              return nil
            end
            consequence = after_synced_repo ? 'No further scripts have been updated this run.' : 'No scripts have been updated this run.'
            StatusReporter.respond_github_failure(error, consequence)
            return :github_unavailable
          end
          tree = tree_data['tree']

          syncable = filter_syncable_scripts(tree, config, repo_key)
          missing = missing_tracked(tree, config, repo_key)
          StatusReporter.respond_mono("[lich5-update: Syncing #{name} (#{syncable.length} scripts)...]")

          # Custom repos write to their per-repo subdir; built-in repos to SCRIPT_DIR
          dest = config[:dest_dir] || SCRIPT_DIR
          FileUtils.mkdir_p(dest) if config[:custom]

          local_shas = FileWriter.build_local_sha_map(dest)
          downloaded_scripts = []
          failed_scripts = []
          held_scripts = []
          syncable.each do |entry|
            filename = File.basename(entry['path'])
            next if !force && local_shas[filename] == entry['sha']

            content = @client.http_get("#{config[:raw_base_url]}/#{entry['path']}", auth: false)
            unless content
              failed_scripts << filename
              next
            end

            if config[:check_lich_requirement]
              required = Lich::Common::Script.required_lich_version_in(content)
              unless Lich::Common::Script.lich_version_satisfied?(required)
                held_scripts << [filename, required]
                next
              end
            end

            begin
              FileWriter.safe_write(File.join(dest, filename), content)
              downloaded_scripts << filename
            rescue StandardError => e
              respond "[lich5-update: write failed for #{filename}: #{e.message}]"
              failed_scripts << filename
            end
          end

          downloaded_other = {}
          failed_other = {}
          (config[:subdirs] || {}).each do |subdir_name, subconfig|
            files, failures = sync_subdir(tree, config, subdir_name, subconfig)
            downloaded_other[subdir_name] = files unless files.empty?
            failed_other[subdir_name] = failures unless failures.empty?
          end

          StatusReporter.render_sync_summary(name, syncable.length, downloaded_scripts, downloaded_other, config[:subdirs]&.keys || [], failed_scripts, failed_other, held_scripts,
                                             missing_tracked: missing)
          :synced
        end

        # Syncs a subdirectory (profiles, data) from repository.
        #
        # @param tree [Array<Hash>] GitHub tree API response
        # @param config [Hash] repository config from SCRIPT_REPOS
        # @param _subdir_name [String] subdirectory name (unused)
        # @param subconfig [Hash] subdirectory config (pattern, dest, glob)
        # @return [Array<Array<String>>] [downloaded_files, failed_files]
        def sync_subdir(tree, config, _subdir_name, subconfig)
          pattern = subconfig[:pattern]
          dest = subconfig[:dest]
          return [[], []] unless pattern && dest

          FileUtils.mkdir_p(dest)
          entries = tree.select { |e| e['path'] =~ pattern && e['type'] == 'blob' }
          return [[], []] if entries.empty?

          local_shas = FileWriter.build_local_sha_map(dest, subconfig[:glob] || '*.yaml')
          downloaded = []
          failed = []
          entries.each do |entry|
            filename = File.basename(entry['path'])
            next if local_shas[filename] == entry['sha']

            content = @client.http_get("#{config[:raw_base_url]}/#{entry['path']}", auth: false)
            unless content
              failed << filename
              next
            end

            begin
              FileWriter.safe_write(File.join(dest, filename), content)
              downloaded << filename
            rescue StandardError => e
              respond "[lich5-update: write failed for #{filename}: #{e.message}]"
              failed << filename
            end
          end
          [downloaded, failed]
        end

        # Tree entries that are scripts of this repo, before any tracking
        # filter: the files a --track for this repo may name.
        #
        # @param tree [Array<Hash>] GitHub tree API response
        # @param config [Hash] repository config from SCRIPT_REPOS or custom repo
        # @return [Array<Hash>] script blob entries
        def self.script_entries(tree, config)
          tree.select { |e| e['path'] =~ config[:script_pattern] && e['type'] == 'blob' }
        end

        # Tree entries an :all-mode repo's sync installs: every script except
        # -setup files.
        #
        # @param tree [Array<Hash>] GitHub tree API response
        # @param config [Hash] the :all-mode repo's config
        # @return [Array<Hash>] script blob entries
        def self.auto_synced_entries(tree, config)
          script_entries(tree, config).reject { |e| File.basename(e['path']).include?('-setup') }
        end

        # Tracked names of an :explicit repo that its file list does not
        # contain, so the sync can never install them: entries stored before
        # --track checked the repo, and scripts later renamed or removed
        # upstream. Each comes with the status line the summary shows.
        #
        # The status says the script is not synced rather than never installed,
        # since a script removed upstream may still be on disk from an earlier
        # sync. An entry that differs from a repo file only in case or the .lic
        # suffix also names that file.
        #
        # @param tree [Array<Hash>] GitHub tree API response
        # @param config [Hash] repository config from SCRIPT_REPOS or custom repo
        # @param repo_key [String] repository key, used in the --untrack hint
        # @return [Array<Array(String, String)>] [filename, status] pairs
        def missing_tracked(tree, config, repo_key)
          return [] unless config[:tracking_mode] == :explicit

          names = self.class.script_entries(tree, config).map { |e| File.basename(e['path']) }
          defaults = config[:default_tracked] || []
          TrackedScripts.new.tracked_scripts(config, repo_key: repo_key).reject { |f| names.include?(f) }.map do |f|
            how = defaults.include?(f) ? 'default script' : "remove with #{$clean_lich_char}lich5-update --untrack=#{repo_key}:#{f}"
            guess = names.find { |n| n.casecmp?(f) || n.casecmp?("#{f}.lic") }
            how = "the repo has '#{guess}'; #{how}" if guess
            [f, "not in repo, not synced (#{how})"]
          end
        end

        # Filters tree entries to syncable scripts based on tracking mode.
        #
        # @param tree [Array<Hash>] GitHub tree API response
        # @param config [Hash] repository config from SCRIPT_REPOS or custom repo
        # @param repo_key [String, nil] repository key for tracked script lookup
        # @return [Array<Hash>] filtered tree entries
        def filter_syncable_scripts(tree, config, repo_key = nil)
          candidates = self.class.script_entries(tree, config)

          case config[:tracking_mode]
          when :all
            self.class.auto_synced_entries(tree, config)
          when :explicit
            tracked = TrackedScripts.new.tracked_scripts(config, repo_key: repo_key)
            candidates.select { |e| tracked.include?(File.basename(e['path'])) }
          else
            candidates
          end
        end
      end
    end
  end
end
