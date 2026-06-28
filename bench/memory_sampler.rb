# frozen_string_literal: true

require 'objspace'

module Bench
  # MemorySampler -- lightweight, dependency-free memory accounting for
  # profiling the long-running Lich process.
  #
  # It records, at named checkpoints, the process RSS plus a handful of Ruby
  # GC / heap statistics, and prints a delta report. The goal is to answer two
  # questions the leak investigation raised:
  #   1. How much does the static footprint cost (e.g. the ~46k-line critrank
  #      tables loaded by GameLoader)?
  #   2. Does memory climb over a steady-state run, and if so, in what phase?
  #
  # It is intentionally self-contained (only stdlib + objspace) so it can be
  # dropped into any boot path without pulling in Lich internals.
  class MemorySampler
    Sample = Struct.new(
      :label, :rss_kb, :heap_live, :total_alloc, :live_objects, :memsize, :elapsed
    )

    def initialize
      @samples = []
      @start = monotonic
    end

    # Record a checkpoint.
    #
    # @param label [String] human-readable phase name
    # @param gc [Boolean] run a full GC before sampling (use to distinguish
    #   "retained" memory from transient allocation between phases)
    def sample(label, gc: false)
      GC.start(full_mark: true, immediate_sweep: true) if gc
      counts = ObjectSpace.count_objects
      s = Sample.new(
        label,
        rss_kb,
        GC.stat(:heap_live_slots),
        GC.stat(:total_allocated_objects),
        counts[:TOTAL] - counts[:FREE],
        ObjectSpace.memsize_of_all,
        monotonic - @start
      )
      @samples << s
      s
    end

    # Resident set size in KiB. Linux reads /proc; otherwise falls back to ps.
    def rss_kb
      if File.readable?('/proc/self/status')
        line = File.foreach('/proc/self/status').find { |l| l.start_with?('VmRSS:') }
        return line.split[1].to_i if line
      end
      `ps -o rss= -p #{Process.pid}`.to_i
    rescue StandardError
      0
    end

    # Snapshot the top object classes by instance count. Walking ObjectSpace is
    # relatively expensive, so this is only called at phase boundaries when
    # requested (CENSUS=1), not on every per-iteration sample.
    def class_census(top = 25)
      tally = Hash.new(0)
      ObjectSpace.each_object(Object) do |o|
        tally[o.class] += 1
      rescue StandardError
        # some objects raise on #class (e.g. BasicObject subclasses); skip them
        next
      end
      tally.sort_by { |_k, v| -v }.first(top).to_h
    end

    def report(io = $stdout)
      base = @samples.first
      return if base.nil?

      io.puts
      io.puts '=' * 100
      io.puts 'MEMORY REPORT  (RSS in MiB; objects in thousands; d = delta vs baseline)'
      io.puts '=' * 100
      fmt = '%-36s %9s %9s %11s %11s %9s'
      io.puts format(fmt, 'phase', 'RSS', 'dRSS', 'live(k)', 'dlive(k)', 't(s)')
      io.puts '-' * 100
      @samples.each do |s|
        io.puts format(
          fmt,
          truncate(s.label, 36),
          mib(s.rss_kb),
          signed_mib(s.rss_kb - base.rss_kb),
          k(s.live_objects),
          signed_k(s.live_objects - base.live_objects),
          format('%.1f', s.elapsed)
        )
      end
      io.puts '-' * 100
      last = @samples.last
      io.puts format(
        'TOTAL: RSS %s -> %s (%s) | live objects %s -> %s (%s) | memsize %s -> %s (%s)',
        mib(base.rss_kb), mib(last.rss_kb), signed_mib(last.rss_kb - base.rss_kb),
        k(base.live_objects), k(last.live_objects), signed_k(last.live_objects - base.live_objects),
        mib(base.memsize / 1024), mib(last.memsize / 1024), signed_mib((last.memsize - base.memsize) / 1024)
      )
      io.puts '=' * 100
    end

    # Print a diff of two class_census snapshots (top growers).
    def report_census(before, after, io = $stdout, top = 20)
      keys = (before.keys | after.keys)
      diffs = keys.map { |k| [k, after.fetch(k, 0) - before.fetch(k, 0)] }
      growers = diffs.reject { |_k, d| d.zero? }.sort_by { |_k, d| -d }.first(top)
      return if growers.empty?

      io.puts
      io.puts 'TOP OBJECT-COUNT GROWERS (by class, run start -> run end):'
      growers.each do |klass, delta|
        io.puts format('  %+9d  %s', delta, klass)
      end
    end

    private

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def mib(kb)
      format('%.1f', kb / 1024.0)
    end

    def signed_mib(kb)
      format('%+.1f', kb / 1024.0)
    end

    def k(n)
      format('%.1f', n / 1000.0)
    end

    def signed_k(n)
      format('%+.1f', n / 1000.0)
    end

    def truncate(str, len)
      str.length > len ? "#{str[0, len - 1]}~" : str
    end
  end
end
