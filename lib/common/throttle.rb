# frozen_string_literal: true

module Lich
  module Common
    # Minimal monotonic-clock rate limiter: runs a block at most once per
    # +interval+ seconds and skips calls that arrive inside the window.
    #
    # Extracted so the buffers' "sweep dead-thread entries, but not too often"
    # logic lives in one place instead of being hand-rolled per call site.
    #
    # @example
    #   throttle = Lich::Common::Throttle.new(60.0)
    #   throttle.run { expensive_cleanup } # runs now, and again >=60s later
    class Throttle
      # @return [Float] minimum seconds between runs
      attr_reader :interval

      # Monotonic timestamp of the last run. Exposed so callers (and tests) can
      # open the gate (+0.0+) or close it (a recent timestamp) deterministically.
      # @return [Float]
      attr_accessor :last_run_at

      # @param interval [Numeric] minimum seconds between runs
      def initialize(interval)
        @interval    = interval.to_f
        @last_run_at = 0.0
      end

      # Yields (running the guarded work) only when at least +interval+ seconds
      # have elapsed since the last run; the timestamp is stamped first so a run
      # that raises still counts as an attempt.
      #
      # A non-positive +last_run_at+ (the initial/forced-open state) always runs,
      # so the gate does not depend on the absolute value of the monotonic clock.
      # +CLOCK_MONOTONIC+ counts from an arbitrary epoch (often boot), so on a
      # freshly-booted host +now+ can be smaller than +interval+; comparing it
      # against +0.0+ directly would wrongly keep the first call gated.
      #
      # @yield the work to rate-limit
      # @return [Boolean] whether the block ran
      def run
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return false if @last_run_at.positive? && (now - @last_run_at) < @interval

        @last_run_at = now
        yield
        true
      end
    end
  end
end
