# frozen_string_literal: true

=begin
  Bulk SHA-based repository sync for script repositories.

  Downloads scripts and data files from configured SCRIPT_REPOS and
  user-registered custom repos, skipping files that match local SHA1.
  Supports both :all (auto-sync all .lic) and :explicit (tracked list) modes.
  A repo that checks Lich version floors installs, for a script whose newest
  version needs a newer Lich, the newest version the running Lich can run.
=end

module Lich
  module Util
    module Update
      class ScriptSync
        # @param client [GitHubClient] GitHub API client instance
        def initialize(client)
          @client = client
          @floor = ScriptFloor.new(client)
          @held = HeldScripts.new
        end

        # Syncs all registered repositories (built-in + custom) for current game.
        # Stops at the first GitHub-wide failure: the remaining repos would
        # fail the same way, and one message is enough.
        #
        # @return [Symbol, nil] :github_unavailable when the sync stopped on a
        #   GitHub-wide failure, else nil
        def sync_all_repos
          synced = false
          (SCRIPT_REPOS.keys + CustomRepos.all.keys).each do |repo_key|
            result = sync_repo(repo_key, after_synced_repo: synced)
            return :github_unavailable if result == :github_unavailable

            synced ||= result == :synced
          end
          nil
        end

        # Syncs a single repository by key (built-in or custom).
        #
        # In a repo that checks Lich version floors, a script whose newest
        # version needs a newer Lich is never installed at that version. A
        # local copy that runs on this Lich is kept; otherwise the newest
        # version this Lich can run is installed from the file's history
        # (see #resolve_unmet_floor), including over an installed copy of
        # the newest version. The decision is remembered (HeldScripts), so
        # later syncs repeat neither the download nor the history search
        # until the repository's version, the running Lich or the local copy
        # changes. +force+ ignores what was remembered.
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
          history_error = nil
          syncable.each do |entry|
            filename = File.basename(entry['path'])
            local_sha = local_shas[filename]
            content = nil
            if !force && local_sha == entry['sha']
              # The repository's newest version is installed. It stays unless
              # the repo checks floors and the running Lich does not meet this
              # one, as after Lich itself went back to an older release.
              next unless config[:check_lich_requirement]

              content = read_local(dest, filename)
              if content.nil? || ScriptFloor.unmet(content).nil?
                @held.forget(repo_key, filename)
                next
              end
            end

            if config[:check_lich_requirement] && !force
              known = @held.lookup(repo_key, filename, remote_sha: entry['sha'], local_sha: local_sha)
              if known
                held_scripts << remembered_row(filename, known)
                next
              end
            end

            content ||= @client.http_get("#{config[:raw_base_url]}/#{entry['path']}", auth: false)
            unless content
              failed_scripts << filename
              next
            end

            fallback = nil
            if config[:check_lich_requirement]
              required = ScriptFloor.unmet(content)
              if required
                row, result = resolve_unmet_floor(entry, config, repo_key, dest, local_sha, required)
                unless result&.status == :found
                  history_error ||= result if result&.status == :failed
                  held_scripts << row
                  next
                end
                fallback = { row: row, required: required, commit: result.commit }
                content = result.content
              else
                @held.forget(repo_key, filename)
              end
            end

            begin
              FileWriter.safe_write(File.join(dest, filename), content)
              if fallback
                held_scripts << fallback[:row]
                @held.remember(repo_key, filename, remote_sha: entry['sha'], local_sha: FileWriter.blob_sha(content),
                                                   required: fallback[:required], outcome: 'installed', commit: fallback[:commit])
              else
                downloaded_scripts << filename
              end
            rescue StandardError => e
              respond "[lich5-update: write failed for #{filename}: #{e.message}]"
              failed_scripts << filename
            end
          end

          if config[:check_lich_requirement]
            @held.prune(repo_key, syncable.map { |entry| File.basename(entry['path']) })
            @held.save
          end
          if history_error
            StatusReporter.respond_github_failure(history_error.error, "Older versions of scripts in #{name} that need a newer Lich could not be checked.")
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

        # Decides what the sync does with a script whose newest version
        # needs a newer Lich than the one running.
        #
        # A local copy that runs on this Lich is kept. Without one (the
        # script is not installed, or the installed copy has an unmet floor
        # of its own), the file's history is searched for the newest version
        # this Lich can run. Decisions that leave the files as they are get
        # remembered here; the caller remembers an install once it is written.
        #
        # @param entry [Hash] the script's GitHub tree entry
        # @param config [Hash] repository config
        # @param repo_key [String] repository key
        # @param dest [String] directory the repository installs into
        # @param local_sha [String, nil] blob SHA of the local copy, nil if absent
        # @param required [String] the floor of the repository's newest version
        # @return [Array(Array, ScriptFloor::Result)] the summary row for the
        #   script, and the history search's result (nil when a local copy
        #   was kept without searching). A :found result is the version to
        #   install; the row then reports it as installed.
        # @api private
        def resolve_unmet_floor(entry, config, repo_key, dest, local_sha, required)
          filename = File.basename(entry['path'])
          if local_sha && local_sha != entry['sha']
            local = read_local(dest, filename)
            if local && ScriptFloor.unmet(local).nil?
              @held.remember(repo_key, filename, remote_sha: entry['sha'], local_sha: local_sha, required: required, outcome: 'held')
              return [[filename, required], nil]
            end
          end

          result = @floor.newest_compatible(ScriptFloor.source_for(config), entry['path'])
          case result.status
          when :found
            [[filename, required, :installed_compatible], result]
          when :none
            @held.remember(repo_key, filename, remote_sha: entry['sha'], local_sha: local_sha, required: required, outcome: 'none')
            [[filename, required, :none_compatible], result]
          else
            [[filename, required, :history_unavailable], result]
          end
        end

        # The summary row for a script whose remembered decision still
        # stands. A script with no version this Lich can run says so; the
        # others read as any script kept back for a newer Lich.
        #
        # @param filename [String] script filename
        # @param known [Hash] the entry HeldScripts#lookup returned
        # @return [Array] [file, required Lich version] with an outcome when
        #   there is one, as StatusReporter.render_sync_summary takes them
        # @api private
        def remembered_row(filename, known)
          row = [filename, known['required']]
          row << :none_compatible if known['outcome'] == 'none'
          row
        end

        # @param dest [String] directory the repository installs into
        # @param filename [String] script filename
        # @return [String, nil] the local copy's bytes, or nil when it cannot be read
        # @api private
        def read_local(dest, filename)
          File.binread(File.join(dest, filename))
        rescue SystemCallError
          nil
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
