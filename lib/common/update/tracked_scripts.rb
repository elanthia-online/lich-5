# frozen_string_literal: true

=begin
  Manages user-tracked script lists for :explicit tracking mode repos.

  Combines default_tracked scripts from config with user-added scripts from
  UserVars. Provides CLI for adding/removing tracked scripts.
  Supports both built-in SCRIPT_REPOS and user-registered custom repos.

  Before adding a script, --track checks it against the other repos: files
  already in scripts/, other tracked lists, and the GitHub file list of an
  :all-mode repo (DR Scripts) that syncs for the current game. Those reads
  go through the shared GitHubClient and its short cache.

  It also cleans up after the older --track, which accepted entries the
  sync never reads: --untrack removes a leftover entry stored under an
  :all-mode repo, and --tracked lists such leftovers.
=end

module Lich
  module Util
    module Update
      class TrackedScripts
        # @param client [GitHubClient, nil] reads GitHub file lists for the
        #   checks --track runs (an :all-mode repo's list for a clash, and the
        #   same checks behind a refused track's suggestion); built on first
        #   use when not given
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
        # searches before scripts/, so it would shadow any script in scripts/:
        # one already there, whatever repo it came from, or one an :all-mode
        # repo will install at its next sync. A built-in repo installs into
        # scripts/ itself, so its only clash with an :all-mode repo is a file
        # that repo really ships: both syncs would then write the same path.
        # What an :all-mode repo ships is read from its GitHub file list. A
        # built-in repo that does not sync for the current game installs
        # nothing here, so it cannot clash and is skipped.
        #
        # @param script_name [String] script filename to check
        # @param exclude_repo [String] repo key to exclude from check (the target repo)
        # @return [String, nil] a refusal, or nil when the name can be added.
        #   A refusal is either an "Error: ..." collision message or, when an
        #   :all-mode repo's file list could not be read, a GitHub-failure
        #   sentence (StatusReporter.github_failure_message). Callers that
        #   need to tell the two apart check for the "Error: " prefix.
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
              clash = all_mode_clash(config, script_name, custom_target: custom_target)
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
          refusal = never_installs_here(config, repo_key, script_name) || install_refusal(config, repo_key, script_name)
          if refusal
            StatusReporter.respond_mono("[lich5-update: #{refusal}]")
            return
          end
          # Created only now: the autosave thread would otherwise persist an
          # empty list for a refused track.
          UserVars.tracked_scripts ||= {}
          UserVars.tracked_scripts[repo_key] ||= []
          UserVars.tracked_scripts[repo_key].push(script_name)
          Vars.save
          StatusReporter.respond_mono("[lich5-update: Added '#{script_name}' to #{name} tracked list.#{replaces_local_note(config, script_name)}]")
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
          if config[:tracking_mode] == :all
            untrack_leftover(config, repo_key, script_name)
            return
          end
          if (config[:default_tracked] || []).include?(script_name)
            StatusReporter.respond_mono("[lich5-update: '#{script_name}' is a default script and cannot be removed.]")
            return
          end
          if UserVars.tracked_scripts&.dig(repo_key)&.delete(script_name)
            Vars.save
            StatusReporter.respond_mono("[lich5-update: Removed '#{script_name}' from #{name} tracked list.]")
            note = installed_file_note(config, repo_key, script_name)
            StatusReporter.respond_mono("[lich5-update: #{note}]") if note
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

            not_synced = [{ value: "Not synced for #{game_label}", colspan: 3 }] unless syncs_for_this_game?(config)
            if config[:tracking_mode] == :all
              table_rows << (not_synced || [{ value: "Scripts synced automatically (all except -setup files)", colspan: 3 }])
              leftover = (UserVars.tracked_scripts&.dig(key) || [] rescue [])
              unless leftover.empty?
                table_rows << [{ value: "Ignored leftover entries: #{leftover.sort.join(', ')}", colspan: 3 }]
                table_rows << [{ value: "Remove with --untrack=#{key}:<script>", colspan: 3 }]
              end
            else
              table_rows << not_synced if not_synced
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

        # Explains why a track into this repo could never install anything
        # on this character: a repo whose game filter does not match is
        # never synced here (vars are kept per game and character, so another
        # game never reads the entry), and an :all-mode repo ignores a
        # tracked list.
        #
        # @param config [Hash] config of the repo being tracked from
        # @param repo_key [String] its key
        # @param script_name [String] script filename
        # @return [String, nil] refusal message, or nil when the track can work
        # @api private
        def never_installs_here(config, repo_key, script_name)
          name = config[:display_name] || repo_key
          unless syncs_for_this_game?(config)
            hint = sibling_hint(config, repo_key, script_name)
            return "#{name} is not synced for #{game_label}, so tracking it here would never install anything. Nothing was added.#{hint}"
          end
          if config[:tracking_mode] == :all
            return "#{name} syncs its scripts automatically (all except -setup files), so it has no tracked list. Nothing was added."
          end

          nil
        end

        # Why a repo that does install tracked scripts here cannot take this
        # one: it is already tracked, the repo does not contain it, or it
        # collides with another repo. The repo's own file list is checked
        # before the collision check, so a name the repo lacks is reported
        # as missing, not as a clash it could never cause.
        #
        # @param config [Hash] config of the repo being tracked from
        # @param repo_key [String] its key
        # @param script_name [String] script filename
        # @return [String, nil] nil when the script can be added; otherwise one
        #   of: the "already tracked" sentence, an "Error: ..." refusal from
        #   check_collision, or a GitHub-failure sentence when a file list
        #   could not be read. Only "Error: ..." refusals start with "Error: ".
        # @api private
        def install_refusal(config, repo_key, script_name)
          name = config[:display_name] || repo_key
          return "'#{script_name}' is already tracked in #{name}." if tracked_scripts(config, repo_key: repo_key).include?(script_name)

          missing_from_repo(config, repo_key, script_name) || check_collision(script_name, repo_key)
        end

        # Points a refused track at a built-in repo that syncs here and reads
        # the same GitHub repository, but only says to track it there when
        # that command would be accepted.
        #
        # @param config [Hash] config of the repo that was refused
        # @param repo_key [String] its key
        # @param script_name [String] script filename
        # @return [String] text to append to the refusal, possibly empty
        # @api private
        def sibling_hint(config, repo_key, script_name)
          sibling = SCRIPT_REPOS.find do |key, other|
            key != repo_key && other[:api_url] == config[:api_url] &&
              other[:tracking_mode] == :explicit && syncs_for_this_game?(other)
          end&.first
          return '' unless sibling

          other = SCRIPT_REPOS[sibling]
          other_name = other[:display_name]
          refusal = install_refusal(other, sibling, script_name)
          if refusal.nil?
            " To track it from the same repository, use #{$clean_lich_char}lich5-update --track=#{sibling}:#{script_name}"
          elsif tracked_scripts(other, repo_key: sibling).include?(script_name)
            " #{other_name}, which reads the same repository, already tracks '#{script_name}' on this character."
          elsif refusal.start_with?('Error: ')
            " #{other_name}, which reads the same repository, cannot track it either: #{refusal.delete_prefix('Error: ')}"
          else
            " Could not check whether #{other_name}, which reads the same repository, can track it instead."
          end
        end

        # Removes an entry stored under an :all-mode repo before --track
        # refused them. The sync never read it.
        #
        # @param config [Hash] the :all-mode repo's config
        # @param repo_key [String] its key
        # @param script_name [String] script filename
        # @return [void]
        # @api private
        def untrack_leftover(config, repo_key, script_name)
          name = config[:display_name] || repo_key
          if UserVars.tracked_scripts&.dig(repo_key)&.delete(script_name)
            Vars.save
            why = syncs_for_this_game?(config) ? "#{name} syncs its scripts automatically" : "#{name} is not synced for #{game_label}"
            StatusReporter.respond_mono("[lich5-update: Removed the leftover '#{script_name}' entry from #{name}. #{why}, so the entry did nothing.]")
          else
            StatusReporter.respond_mono("[lich5-update: #{name} has no tracked list, and '#{script_name}' was not a leftover entry there.]")
          end
        end

        # What to say about the file after its entry is removed. Telling the
        # user to delete it by hand is only right when nothing else installs
        # it here. Another built-in repo that tracks it is known locally. An
        # :all-mode repo that syncs here might also ship it; that would need
        # its GitHub file list, so --untrack stays offline and says so instead.
        #
        # @param config [Hash] config of the repo the entry was removed from
        # @param repo_key [String] its key
        # @param script_name [String] script filename
        # @return [String, nil] note to print, or nil for none
        # @api private
        def installed_file_note(config, repo_key, script_name)
          name = config[:display_name] || repo_key
          delete_note = "Note: #{script_name} is still installed. Delete manually if no longer needed."
          if config[:custom]
            return File.exist?(File.join(config[:dest_dir], script_name)) ? delete_note : nil
          end
          return "#{name} is not synced for #{game_label}, so that entry never installed anything here." unless syncs_for_this_game?(config)
          return nil unless File.exist?(File.join(SCRIPT_DIR, script_name))

          owner = other_builtin_owner(repo_key, script_name)
          return "#{script_name} stays installed, because #{owner} still tracks it." if owner

          auto = SCRIPT_REPOS.values.find { |other| other[:tracking_mode] == :all && syncs_for_this_game?(other) }
          return delete_note unless auto

          "Note: #{script_name} is still installed. If #{auto[:display_name]} also ships it, its next sync keeps it; otherwise delete it by hand if it is no longer needed."
        end

        # A built-in :explicit repo, other than +repo_key+, that syncs for
        # this game and tracks +script_name+, so it keeps the file in scripts/.
        #
        # @param repo_key [String] key of the repo the entry was removed from
        # @param script_name [String] script filename
        # @return [String, nil] its display name
        # @api private
        def other_builtin_owner(repo_key, script_name)
          SCRIPT_REPOS.each do |key, config|
            next if key == repo_key || config[:tracking_mode] != :explicit || !syncs_for_this_game?(config)
            return config[:display_name] if tracked_scripts(config, repo_key: key).include?(script_name)
          end
          nil
        end

        # @return [String] the current game for messages, e.g. "DR characters"
        # @api private
        def game_label
          game = XMLData.game.to_s
          game.empty? ? 'this game' : "#{game} characters"
        end

        # @param config [Hash] repository config
        # @return [Boolean] whether the sync installs this repo for the current game
        # @api private
        def syncs_for_this_game?(config)
          filter = config[:game_filter]
          filter.nil? || filter.match?(XMLData.game.to_s)
        end

        # Tells the user that a built-in track replaces a file already in
        # scripts/: the sync overwrites any local copy whose content differs.
        #
        # @param config [Hash] config of the repo tracked from
        # @param script_name [String] script filename
        # @return [String] text to append to the Added message, possibly empty
        # @api private
        def replaces_local_note(config, script_name)
          return '' if config[:custom] || !File.exist?(File.join(SCRIPT_DIR, script_name))

          " scripts/#{script_name} already exists; the next sync replaces it with the #{config[:display_name]} copy if they differ."
        end

        # Reports whether an :all-mode repo ships +script_name+. For a built-in
        # target both syncs would write the same file in scripts/; for a custom
        # target the custom copy would shadow the synced one.
        #
        # @param config [Hash] the :all-mode repo's config
        # @param script_name [String] script filename
        # @param custom_target [Boolean] whether the track is for a custom repo
        # @return [String, nil] "Error: ..." when it ships the script, a
        #   GitHub-failure sentence when its file list could not be read, or nil
        # @api private
        def all_mode_clash(config, script_name, custom_target:)
          name = config[:display_name]
          case all_mode_ships?(config, script_name)
          when nil
            consequence = "Could not check whether #{name} also contains '#{script_name}', so nothing was added."
            StatusReporter.github_failure_message(client.last_error, consequence, subject: name, retried_by: :user)
          when true
            consequence = custom_target ? 'The custom version would shadow it at runtime.' : 'Tracking it here would make the two overwrite each other.'
            "Error: '#{script_name}' is also in #{name}, which syncs it automatically. #{consequence}"
          end
        end

        # @param config [Hash] an :all-mode repo's config
        # @param script_name [String] script filename
        # @return [Boolean, nil] whether its sync installs +script_name+; nil
        #   when its GitHub file list could not be read
        # @api private
        def all_mode_ships?(config, script_name)
          tree_data = client.fetch_github_json(config[:api_url])
          return nil unless tree_data && tree_data['tree']

          synced = ScriptSync.auto_synced_entries(tree_data['tree'], config)
          synced.any? { |entry| File.basename(entry['path']) == script_name }
        end

        # Reports a script the repo being tracked from does not contain.
        # The sync only installs tracked names it finds in the repo, so a
        # misspelt or missing name would otherwise be kept and never installed.
        #
        # @param config [Hash] config of the repo being tracked from
        # @param repo_key [String] its key
        # @param script_name [String] script filename
        # @return [String, nil] nil when the repo has the script; otherwise an
        #   "Error: ..." refusal, or a GitHub-failure sentence when the file
        #   list could not be read
        # @api private
        def missing_from_repo(config, repo_key, script_name)
          name = config[:display_name] || repo_key
          tree_data = client.fetch_github_json(config[:api_url])
          unless tree_data && tree_data['tree']
            consequence = "Could not check that #{name} contains '#{script_name}', so nothing was added."
            return StatusReporter.github_failure_message(client.last_error, consequence, subject: name, retried_by: :user)
          end

          names = ScriptSync.script_entries(tree_data['tree'], config).map { |entry| File.basename(entry['path']) }
          return nil if names.include?(script_name)

          guess = names.find { |n| n.casecmp?(script_name) || n.casecmp?("#{script_name}.lic") }
          advice = guess ? " #{guess_advice(config, repo_key, guess)}" : ''
          layout = config[:custom] ? ' Only .lic files at the top level of a custom repo can be tracked.' : ''
          "Error: '#{script_name}' is not in #{name}.#{advice}#{layout}"
        end

        # What to tell the user about the repo's file whose name differs from
        # the one typed only in case or the .lic suffix. Suggesting it is only
        # useful when tracking it would be accepted.
        #
        # @param config [Hash] config of the repo being tracked from
        # @param repo_key [String] its key
        # @param guess [String] the repo's filename
        # @return [String]
        # @api private
        def guess_advice(config, repo_key, guess)
          refusal = install_refusal(config, repo_key, guess)
          return "Did you mean '#{guess}'?" if refusal.nil?
          return "It has '#{guess}', which is already tracked there." if tracked_scripts(config, repo_key: repo_key).include?(guess)
          return "It has '#{guess}', but that cannot be tracked either: #{refusal.delete_prefix('Error: ')}" if refusal.start_with?('Error: ')

          "Did you mean '#{guess}'?"
        end

        # Built on first use when none was given: ScriptSync builds a
        # TrackedScripts without one to read tracked lists, which never fetch.
        #
        # @return [GitHubClient]
        # @api private
        def client
          @client ||= GitHubClient.new
        end
      end
    end
  end
end
