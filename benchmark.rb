#!/usr/bin/env ruby
# frozen_string_literal: true

######
# benchmark.rb - throughput benchmark for Lich's server-data pipeline, driven
# entirely through --pipe mode. This is intentionally self-contained: it does
# NOT require or modify anything under lib/. It exercises the real binary the
# same way a front-end would, so the numbers reflect the production code path:
#
#   loopback server  --(canned server XML)-->  lich.rbw --pipe  --(stdout)-->  here
#
# What is measured: the wall-clock time for Lich to read a fixed volume of
# server protocol data off the (loopback) game socket, run it through
# clean_serverstring -> XML parse -> downstream hooks, and emit the processed
# result on stdout. Lich boot time is excluded: the clock starts only once the
# loopback server has accepted the client and begins flooding data.
#
# Usage:
#   ruby benchmark.rb [options]
#     -i, --iterations N   repeats of the fixture block per run (default 3000)
#     -r, --runs R         timed runs (default 3)
#     -w, --warmup W       untimed warmup runs (default 1)
#     -f, --fixture PATH   server-stream fixture (default benchmark/fixtures/gs_sample.xml)
#         --keep           keep the per-run temp dir for inspection
######

require 'socket'
require 'open3'
require 'fileutils'
require 'optparse'

REPO = File.expand_path(__dir__)

options = {
  iterations: 3000,
  runs: 3,
  warmup: 1,
  fixture: File.join(REPO, 'benchmark', 'fixtures', 'gs_sample.xml'),
  keep: false
}

OptionParser.new do |o|
  o.banner = 'Usage: ruby benchmark.rb [options]'
  o.on('-i', '--iterations N', Integer) { |v| options[:iterations] = v }
  o.on('-r', '--runs R', Integer)       { |v| options[:runs] = v }
  o.on('-w', '--warmup W', Integer)     { |v| options[:warmup] = v }
  o.on('-f', '--fixture PATH')          { |v| options[:fixture] = v }
  o.on('--keep')                        { options[:keep] = true }
end.parse!

FIXTURE = File.read(options[:fixture])
SENTINEL = 'LICH_BENCH_SENTINEL_END'
CLOCK = Process::CLOCK_MONOTONIC

# One benchmark run. Returns a hash of measurements (or nil on failure).
def run_once(label, iterations, keep)
  tmp = "/tmp/lich_bench_#{Process.pid}_#{label}"
  FileUtils.rm_rf(tmp)
  %w[data scripts logs maps backup temp].each { |d| FileUtils.mkdir_p(File.join(tmp, d)) }

  payload = FIXTURE * iterations
  input_bytes = payload.bytesize

  # Loopback "game server": accept, read the login key, then flood the payload
  # and a sentinel line. t_start is stamped the moment flooding begins so Lich
  # boot/connect time is excluded from the measurement.
  server  = TCPServer.new('127.0.0.1', 0)
  port    = server.addr[1]
  t_start = nil
  got_key = nil
  srv = Thread.new do
    conn = server.accept
    got_key = conn.gets
    t_start = Process.clock_gettime(CLOCK)
    conn.write(payload)
    conn.write("#{SENTINEL}\r\n")
    conn.flush
    # Hold the link open until the consumer has seen the sentinel echoed back.
    sleep 5
    conn.close rescue nil
  rescue StandardError => e
    warn "[#{label}] server error: #{e.class}: #{e.message}"
  end

  args = [
    'bundle', 'exec', 'ruby', 'lich.rbw',
    "--data=#{tmp}/data", "--temp=#{tmp}/temp", "--logs=#{tmp}/logs",
    "--scripts=#{tmp}/scripts", "--maps=#{tmp}/maps", "--backup=#{tmp}/backup",
    '-g', "127.0.0.1:#{port}", '--pipe', '--no-gtk'
  ]
  env = { 'BUNDLE_WITHOUT' => 'gtk:vscode:profanity' }

  out_bytes = 0
  t_end     = nil
  Open3.popen2e(env, *args, chdir: REPO) do |stdin, stdout_err, wait_thr|
    reader = Thread.new do
      buf = +''
      until t_end
        begin
          chunk = stdout_err.readpartial(65_536)
        rescue EOFError
          break
        end
        out_bytes += chunk.bytesize
        buf << chunk
        if buf.include?(SENTINEL)
          t_end = Process.clock_gettime(CLOCK)
        elsif buf.bytesize > 1_000_000
          buf = buf[-4096..] # bound memory; sentinel is short
        end
      end
    end

    # Front-end handshake: login key, then version string.
    stdin.puts('LICH_BENCH_KEY') rescue Errno::EPIPE
    stdin.puts('/FE:STORMFRONT /VERSION:1.0 /P:BENCH /XML') rescue Errno::EPIPE

    reader.join(60)
    stdin.close rescue nil
    wait_thr.join(10) || (Process.kill('TERM', wait_thr.pid) rescue nil)
  end

  srv.join(2)
  FileUtils.rm_rf(tmp) unless keep

  unless t_start && t_end
    warn "[#{label}] FAILED: sentinel not observed (key=#{got_key.inspect})"
    return nil
  end

  elapsed = t_end - t_start
  {
    elapsed: elapsed,
    input_bytes: input_bytes,
    out_bytes: out_bytes,
    in_mb_s: (input_bytes / 1_048_576.0) / elapsed,
    out_mb_s: (out_bytes / 1_048_576.0) / elapsed
  }
end

def fmt(secs)
  format('%.3fs', secs)
end

puts "Lich --pipe throughput benchmark"
puts "  fixture:    #{options[:fixture]} (#{FIXTURE.bytesize} bytes/block)"
puts "  iterations: #{options[:iterations]} blocks/run (~#{(FIXTURE.bytesize * options[:iterations] / 1_048_576.0).round(1)} MB input)"
puts "  warmup:     #{options[:warmup]}, timed runs: #{options[:runs]}"
puts

options[:warmup].times do |i|
  print "warmup #{i + 1}/#{options[:warmup]}... "
  r = run_once("warm#{i}", options[:iterations], false)
  puts r ? "#{fmt(r[:elapsed])}" : 'FAILED'
end

results = []
options[:runs].times do |i|
  print "run #{i + 1}/#{options[:runs]}... "
  r = run_once("run#{i}", options[:iterations], options[:keep])
  if r
    results << r
    puts "#{fmt(r[:elapsed])}  in=#{r[:in_mb_s].round(1)} MB/s  out=#{r[:out_mb_s].round(1)} MB/s"
  else
    puts 'FAILED'
  end
end

abort 'no successful runs' if results.empty?

times = results.map { |r| r[:elapsed] }.sort
median = times[times.length / 2]
mean   = times.sum / times.length
best   = results.min_by { |r| r[:elapsed] }

puts
puts "Summary (#{results.length} runs):"
puts "  elapsed   min #{fmt(times.first)}  median #{fmt(median)}  mean #{fmt(mean)}  max #{fmt(times.last)}"
puts "  best run  input #{best[:in_mb_s].round(1)} MB/s   output #{best[:out_mb_s].round(1)} MB/s"
puts "  processed #{(best[:input_bytes] / 1_048_576.0).round(1)} MB input -> #{(best[:out_bytes] / 1_048_576.0).round(1)} MB output per run"
