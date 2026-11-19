# frozen_string_literal: true

module Lich
  module Genie
    # Remix's trigger consumer (FormMain.cs:138-151, 343, 6592-6597 R): the game thread writes
    # every line it parses into an unbounded single-reader Channel, and ONE consumer task runs
    # ParseTriggers on each in order -- the global #triggers, then every script's TriggerParse
    # (FormMain.cs:4425-4512 R). The glue's equivalent: Lich's
    # parser thread only feeds GameState and posts each game row's work (its variable changes,
    # its events, its printed texts; GenieScript.game_state_changed) here; this one thread runs
    # the jobs in order. So a #trigger fires before any script sees its line, a trigger body's
    # game send or script launch never runs on Lich's parser thread, and the shared trigger
    # runner gets the game lines from one thread.
    #
    # Pure (no Lich): the glue builds one per process (GenieScript.trigger_worker).
    class TriggerWorker
      # Thread#name of the worker thread.
      THREAD_NAME = 'genie-trigger-worker'
      # Thread-local set on the worker thread (and by the glue on the command-queue worker): an
      # engine-owned host thread, which may wait for a launched script's first run where
      # Lich's own threads must not.
      HOST_THREAD_KEY = :genie_host_worker
      # What a job may raise and the worker survives (as CommandQueue::Worker).
      SURVIVABLE = [StandardError, ScriptError, SystemStackError].freeze

      # @param report [#call] callable(exception) for a job that raised
      def initialize(report:)
        @report = report
        @jobs = Thread::Queue.new
        @thread = nil
        @start_mutex = Mutex.new
        @count_mutex = Mutex.new
        @outstanding = 0 # posted and not finished
      end

      # Queue +job+ (FIFO) and make sure the thread runs.
      # @yield the job, run on the worker thread
      # @return [void]
      def post(&job)
        raise ArgumentError, 'no job' unless job

        @count_mutex.synchronize { @outstanding += 1 }
        @jobs << job
        start
      end

      # Start the thread unless it is running (a dead one is replaced; its queued jobs stay
      # queued for the new one). It leaves the starter's ThreadGroup, which Lich kills with the
      # script that started it (script.rb:1982 pattern, as CommandQueue::Worker).
      # @return [Thread]
      def start
        @start_mutex.synchronize do
          @thread = nil unless @thread&.alive?
          @thread ||= Thread.new { run_loop }.tap do |thread|
            thread.name = THREAD_NAME
            begin
              ThreadGroup::Default.add(thread)
            rescue ThreadError
              nil # an enclosed starter group: the next start after its death replaces it
            end
          end
        end
      end

      # @return [Boolean] whether the calling thread is this worker's
      def on_worker?
        Thread.current.equal?(@thread)
      end

      # @return [Boolean]
      def alive?
        @thread&.alive? ? true : false
      end

      # @return [Boolean] whether every posted job has finished
      def idle?
        @count_mutex.synchronize { @outstanding.zero? }
      end

      private

      def run_loop
        Thread.current[HOST_THREAD_KEY] = true
        loop do
          job = @jobs.pop
          begin
            job.call
          rescue *SURVIVABLE => e
            report(e)
          ensure
            @count_mutex.synchronize { @outstanding -= 1 }
          end
        end
      end

      def report(error)
        @report.call(error)
      rescue StandardError
        nil # the reporter never stops the worker
      end
    end
  end
end
