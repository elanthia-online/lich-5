# frozen_string_literal: true

require_relative 'shutdown_log'

module Lich
  module Common
    # Tracks script teardown during process shutdown.
    #
    # This helper keeps the shutdown orchestration in `main.rb` readable while
    # making the slow-script accounting independently testable.
    module ShutdownScriptDrain
      DEFAULT_DRAIN_ATTEMPTS = 200
      DEFAULT_DRAIN_INTERVAL = 0.1

      Result = Struct.new(
        :scripts_started,
        :slow_script_threshold,
        :slow_scripts,
        :scripts_remaining,
        :remaining_scripts,
        keyword_init: true
      ) do
        # Formats the shutdown drain result for the existing shutdown trace log.
        #
        # @return [String]
        def details
          "scripts_started=#{scripts_started} " \
            "slow_script_threshold=#{format('%.3f', slow_script_threshold)}s " \
            "slow_scripts=#{slow_scripts.inspect} " \
            "scripts_remaining=#{scripts_remaining} " \
            "remaining_scripts=#{remaining_scripts.inspect}"
        end
      end

      # Kills each supplied script with shutdown context and watches the existing
      # bounded drain loop for scripts that exit slowly or not at all.
      #
      # @param initial_scripts [Array<#kill,#name>] scripts present at shutdown start
      # @param remaining_scripts [#call] returns scripts still registered as alive
      # @param slow_threshold [Float] seconds before a script is reported as slow
      # @param drain_attempts [Integer] maximum drain polling attempts
      # @param drain_interval [Float] seconds slept between drain polls
      # @param clock [#call] monotonic clock returning seconds
      # @param sleeper [#call] sleep adapter
      # @return [Result]
      def self.run(initial_scripts:, remaining_scripts:, slow_threshold:, drain_attempts: DEFAULT_DRAIN_ATTEMPTS, drain_interval: DEFAULT_DRAIN_INTERVAL, clock: nil, sleeper: nil)
        clock ||= proc { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        sleeper ||= proc { |duration| sleep duration }

        scripts = initial_scripts.uniq
        started_at = clock.call
        finished_at_by_script = {}
        remaining = []

        scripts.each { |script| kill_script(script) }

        drain_attempts.times do
          remaining = remaining_scripts.call.uniq
          now = clock.call

          scripts.each do |script|
            next if finished_at_by_script.key?(script)
            next if remaining.include?(script)

            finished_at_by_script[script] = now
          end

          break if remaining.empty?

          sleeper.call(drain_interval)
        end

        finished_at = clock.call
        remaining = remaining_scripts.call.uniq

        Result.new(
          scripts_started: scripts.length,
          slow_script_threshold: slow_threshold,
          slow_scripts: slow_script_names(scripts, finished_at_by_script, started_at, finished_at, slow_threshold),
          scripts_remaining: remaining.length,
          remaining_scripts: script_names(remaining)
        )
      end

      # Attempts shutdown kill for a script and logs failures without stopping
      # the remaining shutdown drain.
      #
      # @param script [#kill,#name] script to stop
      # @return [void]
      def self.kill_script(script)
        script.kill(context: :shutdown)
      rescue StandardError => e
        log_kill_error(script, e)
      end
      private_class_method :kill_script

      # Logs a script shutdown kill failure.
      #
      # @param script [Object] script-like object whose kill failed
      # @param error [StandardError] raised kill error
      # @return [void]
      def self.log_kill_error(script, error)
        ShutdownLog.warning("shutdown script kill failed for #{script_name(script)}: #{error.class}: #{error.message}")
      end
      private_class_method :log_kill_error

      # Returns formatted slow-script entries sorted by script name.
      #
      # @param scripts [Array<#name>] scripts observed during shutdown
      # @param finished_at_by_script [Hash{Object=>Float}] observed completion times
      # @param started_at [Float] drain start time
      # @param finished_at [Float] final drain time
      # @param slow_threshold [Float] minimum elapsed seconds for reporting
      # @return [Array<String>]
      def self.slow_script_names(scripts, finished_at_by_script, started_at, finished_at, slow_threshold)
        scripts.filter_map do |script|
          elapsed = (finished_at_by_script[script] || finished_at) - started_at
          next unless elapsed >= slow_threshold

          "#{script_name(script)}=#{format('%.3f', elapsed)}s"
        end.sort
      end
      private_class_method :slow_script_names

      # Returns sorted display names for scripts still registered after drain.
      #
      # @param scripts [Array<#name>] remaining script objects
      # @return [Array<String>]
      def self.script_names(scripts)
        scripts.map { |script| script_name(script) }.sort
      end
      private_class_method :script_names

      # Returns a stable display name for a script-like object.
      #
      # @param script [Object]
      # @return [String]
      def self.script_name(script)
        script.respond_to?(:name) ? script.name.to_s : script.to_s
      end
      private_class_method :script_name
    end
  end
end
