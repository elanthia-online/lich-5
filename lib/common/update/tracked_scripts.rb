# frozen_string_literal: true

=begin
  Manages user-tracked script lists for :explicit tracking mode repos.

  Combines default_tracked scripts from config with user-added scripts from
  UserVars. Provides CLI for adding/removing tracked scripts.
=end

module Lich
  module Util
    module Update
      class TrackedScripts
        # Returns all tracked scripts for a repository config.
        #
        # @param config [Hash] repository config from SCRIPT_REPOS
        # @return [Array<String>] list of tracked script filenames
        def tracked_scripts(config)
          defaults = config[:default_tracked] || []
          repo_key = SCRIPT_REPOS.key(config)
          user_additions = UserVars.tracked_scripts&.dig(repo_key) || [] rescue []
          (defaults + user_additions).uniq
        end

        # Adds a script to user's tracked list for a repository.
        #
        # @param repo_key [String] repository key from SCRIPT_REPOS
        # @param script_name [String] script filename
        # @return [void]
        def track_script(repo_key, script_name)
          config = SCRIPT_REPOS[repo_key]
          unless config
            respond "[lich5-update: Unknown repository '#{repo_key}'.]"
            return
          end
          UserVars.tracked_scripts ||= {}
          UserVars.tracked_scripts[repo_key] ||= []
          name = config[:display_name] || repo_key
          if UserVars.tracked_scripts[repo_key].include?(script_name)
            StatusReporter.respond_mono("[lich5-update: '#{script_name}' is already tracked in #{name}.]")
          else
            UserVars.tracked_scripts[repo_key].push(script_name)
            Vars.save
            StatusReporter.respond_mono("[lich5-update: Added '#{script_name}' to #{name} tracked list.]")
          end
        end

        # Removes a script from user's tracked list for a repository.
        #
        # @param repo_key [String] repository key from SCRIPT_REPOS
        # @param script_name [String] script filename
        # @return [void]
        def untrack_script(repo_key, script_name)
          config = SCRIPT_REPOS[repo_key]
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
            if File.exist?(File.join(SCRIPT_DIR, script_name))
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
          repos = repo_key ? { repo_key => SCRIPT_REPOS[repo_key] } : SCRIPT_REPOS
          table_rows = []

          repos.each do |key, config|
            unless config
              respond "[lich5-update: Unknown repository '#{key}'.]"
              next
            end

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

          table = Terminal::Table.new(rows: table_rows, title: 'Tracked Scripts')
          StatusReporter.respond_mono(table.to_s)
        end
      end
    end
  end
end
