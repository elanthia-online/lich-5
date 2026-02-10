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

      @@reporter_thread = nil
      @@running = false
      @@report_interval = 1 # Hard-coded 1 second for real-time reporting
      @@inline_display = nil # Lazy-loaded from DB, defaults to true

      # Start the background reporter thread
      def self.start
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

        @@running = true

        @@reporter_thread = Thread.new do
          begin
            loop do
              break unless @@running

              begin
                report_skill_gains
                sleep @@report_interval
              rescue StandardError => e
                Lich::Messaging.msg('error', "DRExpMonitor: Error: #{e.message}") if $DREXPMONITOR_DEBUG
                Lich.log "DRExpMonitor error: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
                sleep @@report_interval
              end
            end
          ensure
            @@running = false
          end
        end
      end

      # Stop the background reporter thread
      def self.stop
        unless @@running
          Lich::Messaging.msg('info', 'DRExpMonitor: Experience gain reporting is already inactive')
          return
        end

        @@running = false
        @@reporter_thread&.kill
        @@reporter_thread = nil
      end

      # Check if reporter is running
      def self.active?
        @@running
      end

      # Reset state (for testing)
      def self.reset!
        @@inline_display = nil
        @@running = false
        @@reporter_thread = nil
      end

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

      # Format skill gains array to display strings
      def self.format_gains(gains_array)
        # Aggregate multiple pulses of same skill
        aggregated = gains_array.reduce(Hash.new(0)) do |result, gain|
          result[gain[:skill]] += gain[:change]
          result
        end

        # Format as "Skill(+N)" strings
        aggregated.keys.sort.map { |skill| "#{skill}(+#{aggregated[skill]})" }
      end

      # Report aggregated skill gains
      def self.report_skill_gains
        # Drain the gained_skills array
        new_skills = DRSkill.gained_skills.shift(DRSkill.gained_skills.size)
        return if new_skills.empty?

        # Format and display
        formatted_gains = format_gains(new_skills)
        Lich::Messaging.msg('info', "DRExpMonitor: Gained: #{formatted_gains.join(', ')}")
      end
    end
  end
end

# Register cleanup on exit (handles disconnect and normal exit)
at_exit do
  Lich::DragonRealms::DRExpMonitor.stop if defined?(Lich::DragonRealms::DRExpMonitor)
end
