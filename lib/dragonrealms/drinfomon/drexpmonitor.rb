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
    DRExpMonitor.start         # Start the background reporter
    DRExpMonitor.stop          # Stop the background reporter
    DRExpMonitor.active?       # Check if reporter is running
=end

module Lich
  module DragonRealms
    module DRExpMonitor
      @@reporter_thread = nil
      @@running = false
      @@report_interval = 1 # Hard-coded 1 second for real-time reporting

      # Start the background reporter thread
      def self.start
        if @@running
          Lich::Messaging.msg("info", "Experience gain reporting is already active")
          return
        end

        # Check for exp-monitor.lic conflict
        if Script.running?('exp-monitor')
          Lich::Messaging.msg("error", "Cannot start: exp-monitor.lic script is running")
          Lich::Messaging.msg("error", "Stop it first with: #{$clean_lich_char}kill exp-monitor")
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
              rescue => e
                Lich::Messaging.msg("error", "DRExpMonitor error: #{e.message}") if $DREXPMONITOR_DEBUG
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
          Lich::Messaging.msg("info", "Experience gain reporting is already inactive")
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
        Lich::Messaging.msg("info", "Gained: #{formatted_gains.join(', ')}")
      end
    end
  end
end

# Register cleanup on exit (handles disconnect and normal exit)
at_exit do
  Lich::DragonRealms::DRExpMonitor.stop if defined?(Lich::DragonRealms::DRExpMonitor)
end
