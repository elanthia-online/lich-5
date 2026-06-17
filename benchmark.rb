#!/usr/bin/env ruby
# frozen_string_literal: true

######
# benchmark.rb - throughput benchmark for Lich's server-data pipeline, driven
# entirely through --pipe mode. Self-contained: it does NOT require or modify
# anything under lib/. It exercises the real binary the same way a front-end
# would, so the numbers reflect the production code path:
#
#   loopback server  --(canned server XML)-->  lich.rbw --pipe  --(stdout)-->  here
#
# A single Lich process is booted once per fixture. The loopback server first
# sends the fixture's header section once (the real server handshake, incl.
# settingsInfo so Lich initializes as the right game), then performs N timed
# runs: each run floods the fixture's body block(s) followed by a sentinel, and
# the elapsed time from "flood begins" to "sentinel seen on stdout" is recorded.
# Booting Lich once per fixture keeps many runs cheap and excludes boot cost
# from every sample.
#
# Fixture format: an optional header section, then a line containing the marker
#   ### benchmark:body-repeats-below ###
# then the body block that gets repeated. With no marker, the whole file is the
# (repeated) body and no header is sent.
#
# Each timed run floods enough body repeats to process about --target-lines
# lines (default 5000). Tiny fixtures otherwise finish in a few milliseconds,
# where fixed per-run latency (TCP handshake, scheduler jitter, the sentinel
# round-trip) dominates the timing and throughput swings wildly run to run.
# Sizing every run to the same line budget amortizes that overhead, so the
# numbers are steady and comparable across fixtures. Pass -i to override.
#
# Usage:
#   ruby benchmark.rb [options]
#     -i, --iterations N    body-block repeats per run (default: auto from --target-lines)
#     -t, --target-lines N  approx lines processed per run when auto-sizing (default 5000)
#     -r, --runs R          timed runs (default 10)
#     -w, --warmup W        untimed warmup runs (default 2)
#     -f, --fixture PATH    server-stream fixture (default: every *.xml in benchmark/fixtures/)
#         --keep            keep the temp dir for inspection
######

require 'socket'
require 'open3'
require 'fileutils'
require 'optparse'
require 'timeout'
require 'tmpdir'

REPO = File.expand_path(__dir__)
FIXTURE_DIR = File.join(REPO, 'benchmark', 'fixtures')
MARKER = '### benchmark:body-repeats-below ###'
SENTINEL = 'LICH_BENCH_SENTINEL_END'
CLOCK = Process::CLOCK_MONOTONIC

options = {
  iterations: nil, # nil => auto-size from :target_lines
  target_lines: 5000,
  runs: 10,
  warmup: 2,
  fixture: nil, # nil => run every fixture in FIXTURE_DIR
  keep: false
}

OptionParser.new do |o|
  o.banner = 'Usage: ruby benchmark.rb [options]'
  o.on('-i', '--iterations N', Integer)    { |v| options[:iterations] = v }
  o.on('-t', '--target-lines N', Integer)  { |v| options[:target_lines] = v }
  o.on('-r', '--runs R', Integer)          { |v| options[:runs] = v }
  o.on('-w', '--warmup W', Integer)        { |v| options[:warmup] = v }
  o.on('-f', '--fixture PATH')             { |v| options[:fixture] = v }
  o.on('--keep')                           { options[:keep] = true }
end.parse!

# Parse one fixture into the per-run shape the benchmark needs: split off the
# optional header, count body lines, auto-size the body repeats to the target
# line budget (unless -i was given), and detect the game from settingsInfo.
def load_fixture(path, options)
  raw = File.read(path)
  header, body = raw.include?(MARKER) ? raw.split("#{MARKER}\n", 2) : ['', raw]
  body_lines = body.count("\n")
  # Auto-size body repeats to the target line budget unless -i was given, so each
  # run does enough work to swamp fixed per-run latency (see header note).
  auto_sized = options[:iterations].nil?
  iterations = auto_sized ? [(options[:target_lines].to_f / [body_lines, 1].max).round, 1].max : options[:iterations]
  # Detect the game from the fixture's settingsInfo. Lich loads game-specific
  # modules via the launch GAMECODE (which drives `include Lich::Gemstone` /
  # `DragonRealms` in main.rb); without the matching include, GameLoader can't
  # resolve that game's constants (e.g. DRInfomon).
  game_code = (header + body) =~ /instance=['"]DR/ ? 'DR' : 'GS'
  {
    path: path, header: header, body: body, body_lines: body_lines,
    auto_sized: auto_sized, iterations: iterations, game_code: game_code
  }
end

def fmt(secs)
  format('%.3fs', secs)
end

def percentile(sorted, pct)
  sorted[[(sorted.length * pct).ceil - 1, 0].max]
end

# Run the whole benchmark for one fixture in a single Lich process. Returns an
# array of per-run measurement hashes (warmup runs excluded).
def benchmark(fx, opts)
  tmp = File.join(Dir.tmpdir, "lich_bench_#{Process.pid}")
  FileUtils.rm_rf(tmp)
  %w[data scripts logs maps backup temp].each { |d| FileUtils.mkdir_p(File.join(tmp, d)) }

  body_payload = fx[:body] * fx[:iterations]
  body_bytes   = body_payload.bytesize
  body_lines   = fx[:body_lines] * fx[:iterations]

  server  = TCPServer.new('127.0.0.1', 0)
  port    = server.addr[1]
  trigger = Queue.new # main -> server: :go / :stop
  starts  = Queue.new # server -> main: t_start per run
  dones   = Queue.new # reader -> main: [t_end, bytes, lines] per run

  srv = Thread.new do
    conn = server.accept
    # Disable Nagle so body/sentinel writes hit the wire immediately instead of
    # being coalesced on a timer -- coalescing adds variable latency that shows
    # up as timing noise, especially on the small per-write bursts.
    conn.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
    conn.gets # login key
    # Drain client->server bytes so the eventual close is a clean FIN, not RST.
    drain = Thread.new do
      loop { break unless conn.readpartial(4096) }
    rescue StandardError
      nil
    end
    conn.write(fx[:header]) unless fx[:header].empty? # header once
    conn.flush
    loop do
      break if trigger.pop == :stop
      starts.push(Process.clock_gettime(CLOCK))
      conn.write(body_payload)
      conn.write("#{SENTINEL}\r\n")
      conn.flush
    end
    conn.close_write
    drain.join(5)
    conn.close
  rescue StandardError => e
    warn "server error: #{e.class}: #{e.message}"
  ensure
    server.close rescue nil
  end

  # The loopback host can't be sniffed for the game, so pass an explicit game
  # flag (--dragonrealms / --gemstone) to load the right module under --pipe.
  game_flag = fx[:game_code] == 'DR' ? '--dragonrealms' : '--gemstone'

  args = [
    'bundle', 'exec', 'ruby', 'lich.rbw',
    "--data=#{tmp}/data", "--temp=#{tmp}/temp", "--logs=#{tmp}/logs",
    "--scripts=#{tmp}/scripts", "--maps=#{tmp}/maps", "--backup=#{tmp}/backup",
    '-g', "127.0.0.1:#{port}", '--pipe', '--no-gtk', game_flag
  ]
  env = { 'BUNDLE_WITHOUT' => 'gtk:vscode:profanity' }

  results = []
  Open3.popen2e(env, *args, chdir: REPO) do |stdin, stdout_err, wait_thr|
    Thread.new do
      bytes = 0
      lines = 0
      buf = +''
      loop do
        begin
          chunk = stdout_err.readpartial(65_536)
        rescue EOFError
          break
        end
        bytes += chunk.bytesize
        lines += chunk.count("\n")
        buf << chunk
        while (idx = buf.index(SENTINEL))
          # Output after the sentinel belongs to the next run, not this one;
          # subtract the trailing bytes/lines and carry them forward so a
          # sentinel that shares a chunk with later output is accounted right.
          tail = buf[(idx + SENTINEL.length)..] || +''
          dones.push([Process.clock_gettime(CLOCK), bytes - tail.bytesize, lines - tail.count("\n")])
          bytes = tail.bytesize
          lines = tail.count("\n")
          buf = tail
        end
        buf = buf[-4096..] if buf.bytesize > 4096 # sentinel is short; bound memory
      end
    end

    stdin.puts('LICH_BENCH_KEY') rescue Errno::EPIPE
    stdin.puts('/FE:STORMFRONT /VERSION:1.0 /P:BENCH /XML') rescue Errno::EPIPE

    total = opts[:warmup] + opts[:runs]
    (1..total).each do |r|
      trigger.push(:go)
      t0 = starts.pop
      t_end, bytes, _ = Timeout.timeout(120) { dones.pop }
      next if r <= opts[:warmup]
      elapsed = t_end - t0
      results << {
        elapsed: elapsed,
        in_mb_s: (body_bytes / 1_048_576.0) / elapsed,
        out_mb_s: (bytes / 1_048_576.0) / elapsed,
        lines_s: body_lines / elapsed,
        out_in: bytes.to_f / body_bytes
      }
      print "\r  run #{r - opts[:warmup]}/#{opts[:runs]}  #{fmt(elapsed)}      " if $stdout.tty? && (r % 5).zero?
    end
    print "\r#{' ' * 40}\r" if $stdout.tty?

    trigger.push(:stop)
    stdin.close rescue nil
    wait_thr.join(10) || (Process.kill('TERM', wait_thr.pid) rescue nil)
  end

  srv.join(2)
  FileUtils.rm_rf(tmp) unless opts[:keep]
  results
end

# Print the per-run summary block for one fixture's results.
def report(results)
  if results.empty?
    warn '  no successful runs'
    return false
  end
  times  = results.map { |r| r[:elapsed] }.sort
  lines  = results.map { |r| r[:lines_s] }.sort
  median = percentile(lines, 0.5)
  mean   = lines.sum / lines.length
  stddev = Math.sqrt(lines.sum { |x| (x - mean)**2 } / lines.length)
  cv     = mean.zero? ? 0.0 : (stddev / mean * 100)
  best   = results.max_by { |r| r[:lines_s] }

  puts "  Summary (#{results.length} runs):"
  puts "    elapsed   min #{fmt(times.first)}  median #{fmt(percentile(times, 0.5))}  p95 #{fmt(percentile(times, 0.95))}  max #{fmt(times.last)}"
  puts "    lines/s   median #{median.round}  (min #{lines.first.round}, max #{lines.last.round})"
  puts "    noise     CV #{cv.round(1)}%  (stddev #{stddev.round} lines/s; lower is steadier)"
  puts "    peak      #{best[:lines_s].round} lines/s  in #{best[:in_mb_s].round(2)} MB/s  out #{best[:out_mb_s].round(2)} MB/s"
  puts "    out/in    #{(results.map { |r| r[:out_in] }.max * 100).round}% of body bytes reached stdout"
  warn '    WARNING: CV above 10% - results still noisy; raise --target-lines or close background load' if cv > 10
  warn '    WARNING: low out/in ratio - stream may be dropped/buffered; check the fixture' if results.map { |r| r[:out_in] }.max < 0.5
  true
end

# An explicit -f runs just that fixture; otherwise run every fixture in the dir.
fixtures = options[:fixture] ? [options[:fixture]] : Dir[File.join(FIXTURE_DIR, '*.xml')].sort
abort "no fixtures found in #{FIXTURE_DIR}" if fixtures.empty?

puts 'Lich --pipe throughput benchmark'
puts "  ruby:       #{RUBY_DESCRIPTION}"
puts "  warmup:     #{options[:warmup]}, timed runs: #{options[:runs]} per fixture"
puts "  fixtures:   #{fixtures.length}"

ran_any = false
fixtures.each do |path|
  fx = load_fixture(path, options)
  puts
  puts "fixture: #{File.basename(path)} (#{fx[:game_code]})"
  puts "  header:     #{fx[:header].empty? ? '(none)' : "#{fx[:header].count("\n")} lines, sent once"}"
  puts "  body:       #{fx[:body_lines]} lines/block x #{fx[:iterations]} = #{fx[:body_lines] * fx[:iterations]} lines/run#{fx[:auto_sized] ? " (auto-sized to ~#{options[:target_lines]})" : ''}"
  ran_any |= report(benchmark(fx, options))
end

abort 'no successful runs' unless ran_any
