# frozen_string_literal: true

# lib/dragonrealms/drinfomon/drexpmonitor.rb
=begin
  DragonRealms experience monitoring module

  Provides real-time experience gain tracking and reporting.

  Usage:
    ;display expgains          # Toggle on/off
    ;display expgains on       # Turn on
    ;display expgains off      # Turn off

  Note: Cannot run simultaneously with exp-monitor.lic script.
        Use ";kill exp-monitor" first if needed.

  Public API:
    DRExpMonitor.start              # Start the background reporter
    DRExpMonitor.stop               # Stop the background reporter
    DRExpMonitor.active?            # Check if reporter is running
    DRExpMonitor.inline_display?    # Check if inline exp display is enabled
    DRExpMonitor.inline_display=    # Enable/disable inline exp display
    DRExpMonitor.format_briefexp_on(line, skill)   # Format BRIEFEXP ON line with gained exp
    DRExpMonitor.format_briefexp_off(line, skill, rate_word)  # Format BRIEFEXP OFF line with gained exp
=end

module Lich
  module DragonRealms
    module DRExpMonitor
      # Maximum SQLite retry attempts before giving up (prevents infinite loops)
      MAX_SQLITE_RETRIES = 10

      # Stricter boolean matching pattern - anchored to avoid partial matches
      BOOLEAN_TRUE_PATTERN = /\A(on|true|yes)\z/i.freeze

      # Reporter state. `;hmr drinfomon` re-runs this file, so these keep
      # their values across a reload: resetting them would orphan a running
      # reporter, and the autostart that follows would add a second one.
      @@reporter_thread = nil unless defined?(@@reporter_thread)
      @@running = false unless defined?(@@running)
      # Bumped whenever start launches a reporter, stop retires one, or
      # reset! runs. A reporter thread only acts while the generation it was
      # started with is still current, so a stopped thread cannot clear or
      # outlive the state of its replacement.
      @@generation = 0 unless defined?(@@generation)
      @@mutex = Mutex.new unless defined?(@@mutex) # Thread safety for start/stop operations
      @@report_interval = 1 # Hard-coded 1 second for real-time reporting
      @@inline_display = nil # Lazy-loaded from DB, defaults to false

      # Start the background reporter thread
      # Thread-safe: uses mutex to prevent race conditions
      def self.start
        @@mutex.synchronize do
          if @@running
            Lich::Messaging.msg('info', 'DRExpMonitor: Experience gain reporting is already active')
            return
          end

          # Check for exp-monitor.lic conflict
          if Script.running?('exp-monitor')
            Lich::Messaging.msg('error', 'DRExpMonitor: Cannot start: exp-monitor.lic script is running')
            Lich::Messaging.msg('error', "DRExpMonitor: Stop it first with: #{$clean_lich_char}kill exp-monitor")
            return
          end

          generation = (@@generation += 1)
          @@running = true
          @@reporter_thread = Thread.new(generation) { |owned| run_reporter(owned) }
        end
      end

      # Stop the background reporter thread
      # Thread-safe: uses mutex to prevent race conditions
      #
      # Does not wait for the thread to finish. The thread's ensure takes
      # @@mutex, so joining here would deadlock; the generation bump already
      # keeps the dying thread from touching a later start's state.
      def self.stop
        @@mutex.synchronize do
          unless @@running
            Lich::Messaging.msg('info', 'DRExpMonitor: Experience gain reporting is already inactive')
            return
          end

          retire_reporter
        end
      end

      # Check if reporter is running
      def self.active?
        @@running
      end

      # Reset state (for testing)
      # Thread-safe: uses mutex to prevent race conditions
      def self.reset!
        @@mutex.synchronize do
          @@inline_display = nil
          retire_reporter
        end
      end

      # Body of the reporter thread. Loops while +generation+ is current and
      # gives up ownership on the way out, whatever ends it.
      # @param generation [Integer] the generation start assigned this thread
      # @return [void]
      def self.run_reporter(generation)
        while @@generation == generation
          begin
            report_skill_gains
          rescue StandardError => e
            Lich::Messaging.msg('error', "DRExpMonitor: Error: #{e.message}") if $DREXPMONITOR_DEBUG
            Lich.log "DRExpMonitor error: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
          end
          sleep @@report_interval
        end
      ensure
        # A thread that dies on its own (a non-StandardError exception) is
        # still current and marks reporting off. A stopped or replaced thread
        # is not, and must leave the newer state alone.
        @@mutex.synchronize do
          if @@generation == generation
            @@running = false
            @@reporter_thread = nil
          end
        end
      end

      # Ends the current generation and kills its thread without waiting.
      # Caller must hold @@mutex.
      # @return [void]
      def self.retire_reporter
        @@generation += 1
        @@running = false
        @@reporter_thread&.kill
        @@reporter_thread = nil
      end
      private_class_method :run_reporter, :retire_reporter

      # Check if inline display is enabled (lazy-loaded from DB, defaults to false)
      # BUG FIX: Added max retry count to prevent infinite loop on persistent SQLite lock
      def self.inline_display?
        if @@inline_display.nil?
          retries = 0
          begin
            val = Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='display_inline_exp';")
          rescue SQLite3::BusyException
            retries += 1
            if retries >= MAX_SQLITE_RETRIES
              Lich::Messaging.msg('error', "DRExpMonitor: SQLite busy after #{MAX_SQLITE_RETRIES} retries, defaulting inline_display to false")
              @@inline_display = false
              return @@inline_display
            end
            sleep 0.1
            retry
          end
          # Default to false - inline display must be explicitly enabled
          # Once enabled, the persisted value takes precedence
          # BUG FIX: Use anchored pattern to avoid matching partial strings like "money" or "trust"
          @@inline_display = val.nil? ? false : BOOLEAN_TRUE_PATTERN.match?(val.to_s)
        end
        @@inline_display
      end

      # Enable/disable inline display (persisted to DB)
      # BUG FIX: Added max retry count to prevent infinite loop on persistent SQLite lock
      def self.inline_display=(value)
        @@inline_display = BOOLEAN_TRUE_PATTERN.match?(value.to_s)
        retries = 0
        begin
          Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) values('display_inline_exp',?);", [@@inline_display.to_s.encode('UTF-8')])
        rescue SQLite3::BusyException
          retries += 1
          if retries >= MAX_SQLITE_RETRIES
            Lich::Messaging.msg('error', "DRExpMonitor: SQLite busy after #{MAX_SQLITE_RETRIES} retries, inline_display setting may not be persisted")
            return
          end
          sleep 0.1
          retry
        end
      end

      # Format BRIEFEXP ON line to include cumulative gained experience
      # Original format: "     Aug:  565 39%  [ 2/34]"
      # Modified format: "     Aug:  565 39%  [ 2/34] 0.12"
      def self.format_briefexp_on(line, skill)
        return line unless @@inline_display

        gained = DRSkill.gained_exp(skill) || 0.00
        line.sub(%r{(/34\])}, "\\1 #{format('%0.2f', gained)}")
      end

      # Format BRIEFEXP OFF line to include cumulative gained experience
      # Original format: "    Augmentation:  565 39% learning     "
      # Modified format: "    Augmentation:  565 39% learning      0.12"
      def self.format_briefexp_off(line, skill, rate_word)
        return line unless @@inline_display

        gained = DRSkill.gained_exp(skill) || 0.00
        padded_rate = rate_word.ljust(DR_LONGEST_LEARNING_RATE_LENGTH)
        line.sub(/(%\s+)(#{Regexp.escape(rate_word)})/, "\\1#{padded_rate} #{format('%0.2f', gained)}")
      end

      # Aggregates and formats skill gains for display.
      # Combines multiple pulses of the same skill into single entries.
      # @param gains_array [Array<Hash>] Array of { skill:, change: } hashes
      # @return [Array<String>] Array of "Skill(+N)" formatted strings
      def self.format_gains(gains_array)
        # Aggregate multiple pulses of same skill
        aggregated = gains_array.reduce(Hash.new(0)) do |result, gain|
          result[gain[:skill]] += gain[:change]
          result
        end

        # Format as "Skill(+N)" strings
        aggregated.keys.sort.map { |skill| "#{skill}(+#{aggregated[skill]})" }
      end

      # Reports aggregated skill gains to the user.
      # Drains the DRSkill.gained_skills array and displays formatted gains.
      # @return [void]
      def self.report_skill_gains
        # Drain the gained_skills array
        new_skills = DRSkill.gained_skills.shift(DRSkill.gained_skills.size)
        return if new_skills.empty?

        # Format and display
        formatted_gains = format_gains(new_skills)
        Lich::Messaging.msg('info', "DRExpMonitor: #{formatted_gains.join(', ')}")
      end
    end
  end
end

# Register cleanup on exit (handles disconnect and normal exit)
at_exit do
  # Only when running: a reload registers this hook again, and an extra stop
  # would print "already inactive" on the way out.
  Lich::DragonRealms::DRExpMonitor.stop if defined?(Lich::DragonRealms::DRExpMonitor) && Lich::DragonRealms::DRExpMonitor.active?
end
