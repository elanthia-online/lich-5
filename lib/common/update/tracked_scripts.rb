# frozen_string_literal: true

=begin
  Manages user-tracked script lists for :explicit tracking mode repos.

  Combines default_tracked scripts from config with user-added scripts from
  UserVars. Provides CLI for adding/removing tracked scripts.
  Supports both built-in SCRIPT_REPOS and user-registered custom repos.
=end

module Lich
  module Util
    module Update
      class TrackedScripts
        # @param client [GitHubClient, nil] used to read an :all-mode repo's
        #   file list when checking a built-in --track for a clash; built on
        #   first use when not given
        def initialize(client = nil)
          @client = client
        end

        # Returns all tracked scripts for a repository config.
        #
        # @param config [Hash] repository config from SCRIPT_REPOS or custom repo
        # @param repo_key [String, nil] explicit repo key (avoids config-equality lookup)
        # @return [Array<String>] list of tracked script filenames
        def tracked_scripts(config, repo_key: nil)
          defaults = config[:default_tracked] || []
          repo_key ||= SCRIPT_REPOS.key(config)
          user_additions = UserVars.tracked_scripts&.dig(repo_key) || [] rescue []
          (defaults + user_additions).uniq
        end

        # Resolves a repo_key to its config, checking both SCRIPT_REPOS and custom repos.
        #
        # @param repo_key [String] repository key
        # @return [Hash, nil] config hash or nil
        def resolve_config(repo_key)
          config = SCRIPT_REPOS[repo_key]
          return config if config

          reg = CustomRepos.all[repo_key]
          return CustomRepos.build_config(repo_key, reg) if reg

          nil
        end

        # Checks for filename collisions across all repos.
        #
        # A custom repo installs into scripts/custom/<owner-repo>/, which Lich
        # searches before scripts/, so any script already in scripts/ would be
        # shadowed whatever repo it came from. A built-in repo installs into
        # scripts/ itself, so the only clash with an :all-mode repo is a file
        # that repo really ships: both syncs would then write the same path.
        # That is read from the :all repo's GitHub file list. A built-in repo
        # that does not sync for the current game installs nothing here, so
        # it cannot clash and is skipped.
        #
        # @param script_name [String] script filename to check
        # @param exclude_repo [String] repo key to exclude from check (the target repo)
        # @return [String, nil] error message if collision found, nil otherwise
        def check_collision(script_name, exclude_repo)
          custom_target = !SCRIPT_REPOS.key?(exclude_repo)
          if custom_target && File.exist?(File.join(SCRIPT_DIR, script_name))
            return "Error: '#{script_name}' is already installed in scripts/. The custom version would shadow it at runtime."
          end

          # Check built-in repos
          SCRIPT_REPOS.each do |key, config|
            next if key == exclude_repo
            next unless syncs_for_this_game?(config)

            if config[:tracking_mode] == :all
              next if custom_target

              clash = all_mode_clash(config, script_name)
              return clash if clash

              next
            end

            tracked = tracked_scripts(config)
            if tracked.include?(script_name)
              return "Error: '#{script_name}' is already tracked in #{config[:display_name]}."
            end
          end

          # Check custom repos
          CustomRepos.all.each do |key, _reg|
            next if key == exclude_repo

            tracked = UserVars.tracked_scripts&.dig(key) || []
            if tracked.include?(script_name)
              return "Error: '#{script_name}' is already tracked in Custom: #{key}."
            end
          end

          nil
        end

        # Adds a script to user's tracked list for a repository.
        #
        # @param repo_key [String] repository key (built-in or custom)
        # @param script_name [String] script filename
        # @return [void]
        def track_script(repo_key, script_name)
          config = resolve_config(repo_key)
          unless config
            respond "[lich5-update: Unknown repository '#{repo_key}'.]"
            return
          end
          name = config[:display_name] || repo_key
          UserVars.tracked_scripts ||= {}
          UserVars.tracked_scripts[repo_key] ||= []
          if tracked_scripts(config, repo_key: repo_key).include?(script_name)
            StatusReporter.respond_mono("[lich5-update: '#{script_name}' is already tracked in #{name}.]")
          else
            collision = check_collision(script_name, repo_key)
            if collision
              StatusReporter.respond_mono("[lich5-update: #{collision}]")
              return
            end
            UserVars.tracked_scripts[repo_key].push(script_name)
            Vars.save
            StatusReporter.respond_mono("[lich5-update: Added '#{script_name}' to #{name} tracked list.]")
          end
        end

        # Removes a script from user's tracked list for a repository.
        #
        # @param repo_key [String] repository key (built-in or custom)
        # @param script_name [String] script filename
        # @return [void]
        def untrack_script(repo_key, script_name)
          config = resolve_config(repo_key)
          unless config
            respond "[lich5-update: Unknown repository '#{repo_key}'.]"
            return
          end
          name = config[:display_name] || repo_key
          if (config[:default_tracked] || []).include?(script_name)
            StatusReporter.respond_mono("[lich5-update: '#{script_name}' is a default script and cannot be removed.]")
            return
          end
          if UserVars.tracked_scripts&.dig(repo_key)&.delete(script_name)
            Vars.save
            StatusReporter.respond_mono("[lich5-update: Removed '#{script_name}' from #{name} tracked list.]")

            # Check the appropriate directory for the installed file
            if config[:custom]
              install_path = File.join(config[:dest_dir], script_name)
            else
              install_path = File.join(SCRIPT_DIR, script_name)
            end
            if File.exist?(install_path)
              StatusReporter.respond_mono("[lich5-update: Note: #{script_name} is still installed. Delete manually if no longer needed.]")
            end
          else
            StatusReporter.respond_mono("[lich5-update: '#{script_name}' was not in your #{name} tracked list.]")
          end
        end

        # Displays Terminal::Table of tracked scripts for one or all repos.
        #
        # @param repo_key [String, nil] repository key or nil for all repos
        # @return [void]
        def show_tracked(repo_key = nil)
          table_rows = []

          # Built-in repos
          builtin_repos = repo_key ? {} : SCRIPT_REPOS
          if repo_key && SCRIPT_REPOS[repo_key]
            builtin_repos = { repo_key => SCRIPT_REPOS[repo_key] }
          end

          builtin_repos.each do |key, config|
            name = config[:display_name] || key
            table_rows << :separator unless table_rows.empty?
            table_rows << [{ value: "#{name} (#{key})", colspan: 3, alignment: :center }]
            table_rows << :separator

            if config[:tracking_mode] == :all
              table_rows << [{ value: "All .lic files synced automatically", colspan: 3 }]
            else
              table_rows << ['Script', 'Type', 'Status']
              table_rows << :separator
              scripts = tracked_scripts(config)
              defaults = config[:default_tracked] || []
              scripts.sort.each do |s|
                type = defaults.include?(s) ? 'default' : 'user-added'
                exists = File.exist?(File.join(SCRIPT_DIR, s))
                status = exists ? 'installed' : 'not installed'
                table_rows << [s, type, status]
              end
            end
          end

          # Custom repos
          custom_repos = CustomRepos.all
          if repo_key
            if custom_repos[repo_key]
              custom_repos = { repo_key => custom_repos[repo_key] }
            elsif builtin_repos.empty?
              respond "[lich5-update: Unknown repository '#{repo_key}'.]"
              return
            else
              custom_repos = {}
            end
          end

          custom_repos.each do |key, reg|
            config = CustomRepos.build_config(key, reg)
            name = config[:display_name]
            table_rows << :separator unless table_rows.empty?
            table_rows << [{ value: name, colspan: 3, alignment: :center }]
            table_rows << :separator
            table_rows << ['Script', 'Type', 'Status']
            table_rows << :separator

            scripts = UserVars.tracked_scripts&.dig(key) || []
            dest = config[:dest_dir]
            scripts.sort.each do |s|
              exists = File.exist?(File.join(dest, s))
              status = exists ? 'installed' : 'not installed'
              table_rows << [s, 'user-added', status]
            end

            if scripts.empty?
              table_rows << [{ value: "No scripts tracked. Use --track=#{key}:script.lic to add.", colspan: 3 }]
            end
          end

          if table_rows.empty?
            respond "[lich5-update: No repositories to display.]"
            return
          end

          table = Terminal::Table.new(rows: table_rows, title: 'Tracked Scripts')
          StatusReporter.respond_mono(table.to_s)
        end

        private

        # @param config [Hash] repository config
        # @return [Boolean] whether the sync installs this repo for the current game
        def syncs_for_this_game?(config)
          filter = config[:game_filter]
          filter.nil? || filter.match?(XMLData.game.to_s)
        end

        # Reports whether an :all-mode repo ships +script_name+, which would
        # make it and a built-in tracked copy overwrite each other in scripts/.
        #
        # @param config [Hash] the :all-mode repo's config
        # @param script_name [String] script filename
        # @return [String, nil] error message, or nil when there is no clash
        def all_mode_clash(config, script_name)
          name = config[:display_name]
          tree_data = client.fetch_github_json(config[:api_url])
          unless tree_data && tree_data['tree']
            consequence = "Could not check whether #{name} also contains '#{script_name}', so nothing was added."
            return StatusReporter.github_failure_message(client.last_error, consequence, subject: name, retried_by: :user)
          end

          synced = ScriptSync.new(client).filter_syncable_scripts(tree_data['tree'], config)
          return nil unless synced.any? { |entry| File.basename(entry['path']) == script_name }

          "Error: '#{script_name}' is also in #{name}, which syncs it automatically. Tracking it here would make the two overwrite each other."
        end

        # @return [GitHubClient]
        def client
          @client ||= GitHubClient.new
        end
      end
    end
  end
end
