# frozen_string_literal: true

#
# Async Combat Processor - single ordered worker thread fed by a Queue
#
# The downstream hook calls process_async from the game-stream thread, so
# enqueueing must never block. A single consumer thread guarantees chunks are
# processed in arrival order (status add/remove, UCS updates and damage all
# depend on ordering) and means creature instances are only ever mutated from
# one thread - no synchronization needed in Creature/CreatureInstance.
#

require_relative '../../util/gtk_compaction'

module Lich
  module Gemstone
    module Combat
      class AsyncProcessor
        # max_threads retained for call-site compatibility; processing is
        # intentionally single-threaded to preserve event ordering.
        def initialize(_max_threads = 1)
          @queue = Queue.new
          @processing = false
          @chunks_processed = 0
          @spawn_mutex = Mutex.new
          ensure_worker
        end

        # Enqueue a chunk; O(1), never blocks the game stream.
        #
        # Also revives the worker if it died: a worker spawned from a script
        # context (enable! via autostart/;e) belongs to that script's thread
        # group and is killed when the script exits. process_async runs on
        # the downstream-hook (game) thread, so a worker respawned here
        # survives script death.
        # @param chunk [Array<String>] game lines to process in arrival order
        # @param source [Hash, nil] optional ingestion context; permitted scalar
        #   fields are copied before queueing and validated by Processor
        # @return [nil] after enqueueing, or when the chunk is empty
        def process_async(chunk, source: nil)
          return if chunk.empty?
          if source.is_a?(Hash)
            source = source.slice(:connection_id, :game, :character, :room_epoch, :sequence, :received_at)
                           .transform_values { |value| value.is_a?(String) ? value.dup.freeze : value }.freeze
          else
            source = nil
          end
          @queue.push([chunk, source])
          ensure_worker
          nil
        end

        # Drain remaining work and stop the worker.
        def shutdown
          respond "[Combat] Waiting for #{@queue.size} queued chunks..." if Tracker.debug?(:verbose)
          @queue.push(:shutdown)
          @worker.join

          # Force GC after shutdown to help with memory fragmentation.
          # Compaction is routed through Lich::Util::GtkCompaction, which
          # keeps it safe to use alongside gtk3.
          GC.start
          Lich::Util::GtkCompaction.safe_compact!
        end

        def stats
          {
            active: @processing ? 1 : 0,
            queued: @queue.size,
            total: @chunks_processed,
            worker_alive: !@worker.nil? && @worker.alive?
          }
        end

        private

        def ensure_worker
          return if @worker&.alive?

          @spawn_mutex.synchronize do
            next if @worker&.alive?

            respond '[Combat] Worker thread dead - respawning' if @worker && Tracker.debug?
            @worker = Thread.new { run_loop }
          end
        end

        def run_loop
          loop do
            work = @queue.pop
            break if work == :shutdown
            chunk, source = work

            @processing = true
            started = Time.now
            begin
              source ? Processor.process(chunk, source: source) : Processor.process(chunk)

              elapsed = Time.now - started
              if elapsed > 0.5 && Tracker.debug?
                respond "[Combat] Processed #{chunk.size} lines in #{elapsed.round(3)}s"
              end
            rescue => e
              respond "[Combat] Processing error: #{e.message}" if Tracker.debug?(:verbose)
              respond e.backtrace.first(3) if Tracker.debug?(:verbose)
            ensure
              @processing = false
              @chunks_processed += 1
            end
          end
        end
      end
    end
  end
end
