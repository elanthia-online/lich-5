# frozen_string_literal: true

#
# Async Combat Processor - Thread-safe combat processing for performance
#

require 'concurrent'

module Lich
  module Gemstone
    module Combat
      class AsyncProcessor
        def initialize(max_threads = 2)
          @max_threads = max_threads
          @active_count = Concurrent::AtomicFixnum.new(0)
          @thread_pool = []
          @last_cleanup = Time.now
          @last_compact = Time.now
        end

        def process_async(chunk)
          return if chunk.empty?

          # Periodic cleanup of dead threads (safety net)
          cleanup_dead_threads if Time.now - @last_cleanup > 30

          # Wait if at capacity
          while @active_count.value >= @max_threads
            sleep(0.01)
          end

          @active_count.increment

          # Create thread and store reference for self-cleanup
          thread = Thread.new do
            begin
              Thread.current[:start_time] = Time.now
              Thread.current[:line_count] = chunk.size

              Processor.process(chunk)

              elapsed = Time.now - Thread.current[:start_time]
              if elapsed > 0.5 && Tracker.debug?
                puts "[Combat] Processed #{chunk.size} lines in #{elapsed.round(3)}s"
              end
            rescue => e
              puts "[Combat] Processing error: #{e.message}" if Tracker.debug?
              puts e.backtrace.first(3) if Tracker.debug?
            ensure
              @active_count.decrement
              # Thread cleans itself up from pool when done (use Thread.current to avoid race)
              @thread_pool.delete(Thread.current)
            end
          end

          @thread_pool << thread
          thread
        end

        def shutdown
          puts "[Combat] Waiting for #{@thread_pool.count(&:alive?)} threads..." if Tracker.debug?
          @thread_pool.each(&:join)
          @thread_pool.clear

          # Force GC after shutdown to help with memory fragmentation
          GC.start
          GC.compact if GC.respond_to?(:compact)  # Ruby 2.7+
        end

        def stats
          {
            active: @active_count.value,
            total_alive: @thread_pool.count(&:alive?),
            pool_size: @thread_pool.size,  # ACTUAL array size (includes dead threads if not cleaned)
            dead_threads: @thread_pool.count { |t| !t.alive? },  # Count dead threads still in pool
            max_threads: @max_threads,
            processing: @thread_pool.select(&:alive?).map do |thread|
              {
                lines: thread[:line_count] || 0,
                elapsed: thread[:start_time] ? (Time.now - thread[:start_time]).round(2) : 0
              }
            end
          }
        end

        private

        # Periodic cleanup of any dead threads (safety net only, threads should self-cleanup)
        def cleanup_dead_threads
          dead_count = @thread_pool.count { |t| !t.alive? }
          # Keep only alive threads (remove dead ones)
          @thread_pool.select!(&:alive?)

          # If we cleaned up dead threads, suggest GC to help with fragmentation
          if dead_count > 10
            GC.start
            puts "[Combat] Cleaned #{dead_count} dead threads, triggered GC" if Tracker.debug?
          end

          # Periodic heap compaction to reduce fragmentation (every hour)
          if GC.respond_to?(:compact) && (Time.now - @last_compact) > 3600
            GC.start
            GC.compact
            @last_compact = Time.now
            puts "[Combat] Triggered hourly GC compaction" if Tracker.debug?
          end

          @last_cleanup = Time.now
        end
      end
    end
  end
end
