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
        end

        def process_async(chunk)
          return if chunk.empty?

          # Clean up dead threads
          @thread_pool.reject!(&:alive?)

          # Wait if at capacity
          while @active_count.value >= @max_threads
            sleep(0.01)
          end

          @active_count.increment

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
            end
          end

          @thread_pool << thread
          thread
        end

        def shutdown
          puts "[Combat] Waiting for #{@thread_pool.count(&:alive?)} threads..." if Tracker.debug?
          @thread_pool.each(&:join)
          @thread_pool.clear
        end

        def stats
          {
            active: @active_count.value,
            total: @thread_pool.count(&:alive?),
            max_threads: @max_threads,
            processing: @thread_pool.select(&:alive?).map do |thread|
              {
                lines: thread[:line_count] || 0,
                elapsed: thread[:start_time] ? (Time.now - thread[:start_time]).round(2) : 0
              }
            end
          }
        end
      end
    end
  end
end
