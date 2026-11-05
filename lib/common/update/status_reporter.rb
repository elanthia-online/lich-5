# frozen_string_literal: true

=begin
  Utilities for rendering update status messages and tables.

  Provides monospace-aware respond wrapper and Terminal::Table formatting
  for sync summaries.
=end

module Lich
  module Util
    module Update
      module StatusReporter
        # Outputs text with monospace formatting if available.
        #
        # @param text [String] text to display
        # @return [void]
        def self.respond_mono(text)
          if defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:mono)
            Lich::Messaging.mono(text)
          else
            # respond is a top-level method (private on Object). Bare `respond`
            # can't be called from a module class method without send.
            send(:respond, text)
          end
        end

        # Reports a failed GitHub request as one message stating what was not
        # done and whether the user needs to act.
        #
        # @param error [FetchError, nil] the client's last_error (nil = unclassified)
        # @param consequence [String] what did not happen, e.g. "No scripts have been updated this run."
        # @param subject [String, nil] what was being fetched, named in the not-found message
        # @return [void]
        def self.respond_github_failure(error, consequence, subject: nil)
          respond_mono("[lich5-update: #{github_failure_message(error, consequence, subject: subject)}]")
        end

        # Builds the text #respond_github_failure prints, for callers that
        # hand the message on instead of printing it themselves.
        #
        # A refused command is not retried at login the way the login sync
        # is, so +retried_by: :user+ tells the user to run it again instead.
        #
        # @param error [FetchError, nil] the client's last_error (nil = unclassified)
        # @param consequence [String] what did not happen
        # @param subject [String, nil] what was being fetched, named in the not-found message
        # @param retried_by [Symbol] :login (the next login sync retries it) or :user (the user re-runs the command)
        # @return [String]
        def self.github_failure_message(error, consequence, subject: nil, retried_by: :login)
          command = retried_by == :user
          case error&.kind
          when :rate_limited
            reset = error.reset_at ? ", resets at #{error.reset_at.strftime('%H:%M')}" : ''
            tail = command ? 'Run the command again once the limit resets.' : 'This is temporary and will clear once the limit resets.'
            "GitHub check failed (rate limit reached#{reset}). #{consequence} #{tail}"
          when :not_found
            "GitHub check failed (#{subject || 'repository'} not found). #{consequence} Check that the repository and branch exist."
          when :rejected
            "GitHub check failed (GitHub refused access to #{subject || 'the repository'}). #{consequence} Check that the repository and branch exist and are public."
          else
            tail = command ? 'This is usually temporary; run the command again in a few minutes.' : 'This is a temporary error that should resolve itself by your next login.'
            "GitHub check failed. #{consequence} #{tail}"
          end
        end

        # Renders sync results as Terminal::Table.
        #
        # @param repo_name [String] repository display name
        # @param script_count [Integer] total scripts checked
        # @param downloaded_scripts [Array<String>] scripts downloaded
        # @param downloaded_other [Hash<String, Array<String>>] subdir => files
        # @param subdir_names [Array<String>] subdirectory names
        # @param failed_scripts [Array<String>] scripts that failed (default: [])
        # @param failed_other [Hash<String, Array<String>>] subdir => failed files (default: {})
        # @param held_scripts [Array<Array(String, String)>] [file, required Lich version] pairs
        #   not installed because the running Lich is too old (default: [])
        # @param missing_tracked [Array<Array(String, String)>] [file, status] pairs for
        #   tracked names the repo does not contain, so the sync does not update them (default: [])
        # @return [void]
        def self.render_sync_summary(repo_name, script_count, downloaded_scripts, downloaded_other, subdir_names, failed_scripts = [], failed_other = {}, held_scripts = [],
                                     missing_tracked: [])
          total_downloaded = downloaded_scripts.length + downloaded_other.values.flatten.length
          total_failed = failed_scripts.length + failed_other.values.flatten.length

          if total_downloaded == 0 && total_failed == 0 && held_scripts.empty? && missing_tracked.empty?
            table = Terminal::Table.new(
              title: "#{repo_name} Sync",
              rows: [
                ['Scripts', "#{script_count} checked, all up to date"],
                *subdir_names.map { |s| [s.capitalize, 'up to date'] }
              ]
            )
            respond_mono(table.to_s)
            return
          end

          table_rows = []
          table_rows << ['Category', 'File', 'Status']
          table_rows << :separator

          downloaded_scripts.each { |f| table_rows << ['script', f, 'downloaded'] }
          failed_scripts.each { |f| table_rows << ['script', f, 'FAILED (will retry next login)'] }
          held_scripts.each { |f, required| table_rows << ['script', f, "needs Lich #{required}+ (not updated)"] }
          missing_tracked.each { |f, status| table_rows << ['script', f, status] }

          downloaded_other.each do |subdir, files|
            files.each { |f| table_rows << [subdir, f, 'downloaded'] }
          end

          failed_other.each do |subdir, files|
            files.each { |f| table_rows << [subdir, f, 'FAILED (will retry next login)'] }
          end

          subdir_names.each do |s|
            next if downloaded_other.key?(s) || failed_other.key?(s)

            table_rows << [s, '--', 'up to date']
          end

          if downloaded_scripts.empty? && failed_scripts.empty? && held_scripts.empty?
            checked = missing_tracked.empty? ? "#{script_count} checked, all up to date" : "#{script_count} found, up to date"
            table_rows << ['scripts', '--', checked]
          end

          table_rows << :separator
          summary = "Total: #{total_downloaded} updated"
          summary += ", #{total_failed} failed" if total_failed > 0
          summary += ", #{held_scripts.length} need newer Lich" unless held_scripts.empty?
          summary += ", #{missing_tracked.length} tracked but not in repo" unless missing_tracked.empty?
          table_rows << [{ value: summary, colspan: 3 }]

          table = Terminal::Table.new(title: "#{repo_name} Sync", rows: table_rows)
          respond_mono(table.to_s)
        end
      end
    end
  end
end
