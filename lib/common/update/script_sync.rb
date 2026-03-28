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
        #
        # @return [void]
        def sync_all_repos
          SCRIPT_REPOS.each_key { |repo_key| sync_repo(repo_key) }
          CustomRepos.all.each_key { |repo_key| sync_repo(repo_key) }
        end

        # Syncs a single repository by key (built-in or custom).
        #
        # @param repo_key [String] repository key from SCRIPT_REPOS or custom repo
        # @param force [Boolean] skip SHA check and download all (default: false)
        # @return [void]
        def sync_repo(repo_key, force: false)
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

          tree_data = @client.fetch_github_json(config[:api_url])
          unless tree_data && tree_data['tree']
            respond "[lich5-update: Failed to fetch tree for #{repo_key}.]"
            return
          end
          tree = tree_data['tree']

          name = config[:display_name] || repo_key
          syncable = filter_syncable_scripts(tree, config)
          StatusReporter.respond_mono("[lich5-update: Syncing #{name} (#{syncable.length} scripts)...]")

          # Custom repos write to their per-repo subdir; built-in repos to SCRIPT_DIR
          dest = config[:dest_dir] || SCRIPT_DIR
          FileUtils.mkdir_p(dest) if config[:custom]

          local_shas = FileWriter.build_local_sha_map(dest)
          downloaded_scripts = []
          failed_scripts = []
          syncable.each do |entry|
            filename = File.basename(entry['path'])
            next if !force && local_shas[filename] == entry['sha']

            content = @client.http_get("#{config[:raw_base_url]}/#{entry['path']}", auth: false)
            unless content
              failed_scripts << filename
              next
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

          StatusReporter.render_sync_summary(name, syncable.length, downloaded_scripts, downloaded_other, config[:subdirs]&.keys || [], failed_scripts, failed_other)
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

        # Filters tree entries to syncable scripts based on tracking mode.
        #
        # @param tree [Array<Hash>] GitHub tree API response
        # @param config [Hash] repository config from SCRIPT_REPOS or custom repo
        # @return [Array<Hash>] filtered tree entries
        def filter_syncable_scripts(tree, config)
          candidates = tree.select { |e| e['path'] =~ config[:script_pattern] && e['type'] == 'blob' }

          case config[:tracking_mode]
          when :all
            candidates.reject { |e| File.basename(e['path']).include?('-setup') }
          when :explicit
            tracked = TrackedScripts.new.tracked_scripts(config)
            candidates.select { |e| tracked.include?(File.basename(e['path'])) }
          else
            candidates
          end
        end
      end
    end
  end
end
