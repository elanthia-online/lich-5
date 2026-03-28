# frozen_string_literal: true

require 'terminal-table'

module Lich
  module Common
    module CLI
      # Read-only CLI query mode for the Active Sessions API.
      #
      # This CLI intentionally does not attempt to start or enable the service.
      # It only queries an already-running active-sessions owner discovered on
      # the local machine and prints human-readable status output.
      module ActiveSessionsQuery
        # Handles supported active-sessions CLI query options and exits the
        # process once a query has been printed.
        #
        # Supported options:
        # - `--active-sessions`
        # - `--session-info NAME`
        # - `--session-info=NAME`
        #
        # @return [void]
        def self.execute
          return unless query_requested?

          exit run
        end

        # Executes the selected query mode and returns a process exit status.
        #
        # @return [Integer]
        def self.run
          if ARGV.include?('--active-sessions')
            print_snapshot(query_snapshot)
            return 0
          end

          session_name = requested_session_name
          if session_name.nil? || session_name.empty?
            print_session_info_usage
            return 1
          end

          print_session_info(query_snapshot, session_name)
        end

        # Returns whether the current argument set requests an active-sessions
        # CLI query mode.
        #
        # @return [Boolean]
        def self.query_requested?
          ARGV.include?('--active-sessions') || !requested_session_name.nil?
        end

        # Returns the session name requested by `--session-info`, if present.
        #
        # @return [String, nil]
        def self.requested_session_name
          inline_arg = ARGV.find { |arg| arg.start_with?('--session-info=') }
          return inline_arg.split('=', 2).last if inline_arg

          idx = ARGV.index('--session-info')
          return nil unless idx

          ARGV[idx + 1]
        end

        # Queries the active-sessions service using the discovery record
        # without attempting to start a new service owner.
        #
        # @return [Hash]
        def self.query_snapshot
          return unavailable_snapshot unless defined?(Lich::InternalAPI::ActiveSessions)

          Lich::InternalAPI::ActiveSessions.query_snapshot
        end

        # Prints a table of all currently active sessions.
        #
        # @param snapshot [Hash]
        # @return [void]
        def self.print_snapshot(snapshot)
          if snapshot[:error]
            $stdout.puts "No active sessions service available (#{snapshot[:error]})."
            return
          end

          sessions = Array(snapshot[:sessions])
          if sessions.empty?
            $stdout.puts 'No active sessions found.'
            return
          end

          rows = sessions.sort_by { |session| session[:session_name].to_s.downcase }.map do |session|
            [
              session[:session_name] || '(unnamed)',
              session[:pid],
              session[:role] || 'session',
              yes_no(session[:connected]),
              session[:listener] ? yes_no(true) : yes_no(false),
              listener_display(session[:listener]),
              format_uptime(session[:uptime_seconds])
            ]
          end

          table = Terminal::Table.new(
            title: 'Active Sessions',
            headings: ['Session', 'PID', 'Role', 'Connected', 'Detachable', 'Listener', 'Uptime'],
            rows: rows
          )
          $stdout.puts table
        end

        # Prints details for a single queried session.
        #
        # @param snapshot [Hash]
        # @param session_name [String]
        # @return [Integer] process exit code
        def self.print_session_info(snapshot, session_name)
          if snapshot[:error]
            $stdout.puts "No active sessions service available (#{snapshot[:error]})."
            return 1
          end

          session = Array(snapshot[:sessions]).find do |entry|
            entry[:session_name].to_s.casecmp?(session_name)
          end

          unless session
            $stdout.puts "No active session found for #{session_name}."
            return 1
          end

          listener = session[:listener]
          $stdout.puts "Session: #{session[:session_name]}"
          $stdout.puts "PID: #{session[:pid]}"
          $stdout.puts "Role: #{session[:role] || 'session'}"
          $stdout.puts "Connected: #{yes_no(session[:connected])}"
          $stdout.puts "Detachable listener: #{listener_display(listener)}"
          $stdout.puts "Uptime: #{format_uptime(session[:uptime_seconds])}"
          0
        end

        # Prints usage for the single-session query mode.
        #
        # @return [void]
        def self.print_session_info_usage
          lich_script = File.join(LICH_DIR, 'lich.rbw')
          $stdout.puts 'error: Missing session name'
          $stdout.puts "Usage: ruby #{lich_script} --session-info NAME"
          $stdout.puts "   or: ruby #{lich_script} --session-info=NAME"
        end

        # Returns the standardized unavailable snapshot payload used by CLI
        # queries when the service implementation is not loaded.
        #
        # @return [Hash]
        def self.unavailable_snapshot
          {
            source: 'ActiveSessionsAPI',
            total: 0,
            connected: 0,
            detachable: 0,
            sessions: [],
            error: 'active sessions service unavailable'
          }
        end
        private_class_method :unavailable_snapshot

        # Formats the detachable listener endpoint for display.
        #
        # @param listener [Hash, nil]
        # @return [String]
        def self.listener_display(listener)
          return 'none' unless listener

          "#{listener[:host]}:#{listener[:port]}"
        end
        private_class_method :listener_display

        # Formats uptime seconds into a concise human-readable duration.
        #
        # @param uptime_seconds [Integer, nil]
        # @return [String]
        def self.format_uptime(uptime_seconds)
          total = uptime_seconds.to_i
          hours = total / 3600
          minutes = (total % 3600) / 60
          seconds = total % 60
          format('%<hours>02d:%<minutes>02d:%<seconds>02d', hours: hours, minutes: minutes, seconds: seconds)
        end
        private_class_method :format_uptime

        # Formats boolean state for terminal output.
        #
        # @param value [Object]
        # @return [String]
        def self.yes_no(value)
          value ? 'yes' : 'no'
        end
        private_class_method :yes_no
      end
    end
  end
end
