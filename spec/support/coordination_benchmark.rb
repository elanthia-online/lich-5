# frozen_string_literal: true

# Offline only: independent synthetic owners, no game runtime or credentials.
# Run with Ruby directly; prints summaries, never endpoint tokens.
require 'json'
require 'securerandom'
require_relative '../../lib/internal_api/coordination'

module CoordinationBenchmark
  Core = Lich::InternalAPI::Coordination

  def self.now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.cpu
    times = Process.times
    times.utime + times.stime
  end

  def self.rss_kib
    match = File.read('/proc/self/status').match(/^VmRSS:\s+(\d+)/)
    match && match[1].to_i
  end

  def self.receive(io)
    raise 'benchmark child deadline exceeded' unless IO.select([io], nil, nil, 5)

    JSON.parse(io.gets || raise('benchmark child exited'), symbolize_names: true)
  end

  def self.child(input, output, token, index)
    output.sync = true
    before = rss_kib
    session = Core::Session.new(game: 'SYNTHETIC', character: "fixture-#{index}",
                                run_id: 'benchmark', read_token: token, enabled: true)
    raise 'endpoint failed' unless session.start

    started_cpu = cpu
    ticks = 0
    loop do
      ticks += 1
      source = { version: ticks, age: 0.0, room_epoch: 1, connection_generation: 0 }
      raise 'publication failed' unless session.publish(
        identity: session.identity, sequence: ticks, owner_tick: ticks, connected: true,
        room: { id: 1, epoch: 1 }, readiness: { ready: true, coherence: 'coherent' },
        sources: { room: source, readiness: source }
      )
      output.puts(JSON.generate(descriptor: session.descriptor)) if ticks == 1
      next unless IO.select([input], nil, nil, 0.05)
      break unless input.gets == "continue\n"
    end
    session.close
    output.puts(JSON.generate(cpu_seconds: cpu - started_cpu, rss_delta_kib: rss_kib - before, ticks: ticks))
  ensure
    session&.close
  end

  def self.run(count, rounds: 200)
    token = SecureRandom.hex(32)
    children = []
    count.times do |index|
      input, writer = IO.pipe
      reader, output = IO.pipe
      pid = fork do
        children.each { |entry| entry[:writer].close; entry[:reader].close }
        writer.close
        reader.close
        begin
          child(input, output, token, index)
          exit! 0
        rescue StandardError => e
          warn "benchmark child failed: #{e.class}"
          exit! 1
        end
      end
      input.close
      output.close
      entry = { pid: pid, writer: writer, reader: reader }
      children << entry
      entry[:client] = Core::Client.new(descriptor: receive(reader)[:descriptor], read_token: token, max_age: 1.0)
    end
    # Warm up independently of the reported interval.
    children.each { |entry| raise 'warmup failed' unless entry[:client].snapshot[:ok] }
    started = now
    started_cpu = cpu
    workers = children.map do |entry|
      Thread.new do
        Array.new(rounds) do
          sent = now
          answer = entry[:client].snapshot
          raise 'invalid benchmark response' unless answer[:ok] && answer[:payload][:ready]

          (now - sent) * 1000
        end
      end
    end
    samples = workers.flat_map(&:value).sort
    elapsed = now - started
    parent_cpu = cpu - started_cpu
    children.each { |entry| entry[:writer].puts('stop') }
    owners = children.map { |entry| receive(entry[:reader]) }
    { sessions: count, requests: samples.size, elapsed_seconds: elapsed.round(4),
      requests_per_second: (samples.size / elapsed).round,
      latency_ms: [50, 95, 99].to_h { |p| ["p#{p}", samples[((samples.size - 1) * p / 100.0).ceil].round(3)] },
      parent_cpu_seconds: parent_cpu.round(4), owner_cpu_seconds: owners.sum { |entry| entry[:cpu_seconds] }.round(4),
      owner_rss_delta_kib: owners.map { |entry| entry[:rss_delta_kib] },
      owner_ticks: owners.map { |entry| entry[:ticks] } }
  ensure
    children&.each do |entry|
      entry[:writer].close unless entry[:writer].closed?
      entry[:reader].close unless entry[:reader].closed?
      deadline = now + 2
      until Process.waitpid(entry[:pid], Process::WNOHANG)
        if now >= deadline
          Process.kill('KILL', entry[:pid])
          Process.waitpid(entry[:pid])
          break
        end
        sleep 0.01
      end
    rescue Errno::ECHILD, Errno::ESRCH
      nil
    end
  end
end

if $PROGRAM_NAME == __FILE__
  [2, 5, 10].each { |count| puts JSON.generate(CoordinationBenchmark.run(count)) }
end
