# frozen_string_literal: true

require 'socket'
require 'open3'
require 'fileutils'
require 'json'
require 'timeout'
require 'tmpdir'

module StreamReplay
  # Replays a captured server stream through a real `lich.rbw --pipe` process
  # and returns the parsed-state snapshot taken after every prompt.
  #
  #   loopback game server --(fixture lines)--> lich.rbw --pipe --(stdout)--> here
  #                                                  |
  #                                         replay_probe.lic (DownstreamHook)
  #                                                  |
  #                                         snapshots.jsonl (one per prompt)
  #
  # Unlike benchmark.rb this sends the stream paced, one prompt at a time: after
  # each line containing a <prompt>, it waits until the probe has written that
  # prompt's snapshot. That keeps the run deterministic and keeps Lich's bounded
  # parser queue (Game::SERVER_QUEUE_CAPACITY) from overflowing.
  #
  # Self-contained like benchmark.rb: nothing under lib/ is loaded in this
  # process; the production code runs only inside the child Lich process.
  class Driver
    REPO = File.expand_path('../../..', __dir__)
    PROBE = File.join(__dir__, 'replay_probe.lic')
    OFFLINE_PRELOAD = File.join(__dir__, 'offline_preload.rb')
    WARMUP_PROMPT = '<prompt time="0">&gt;</prompt>'
    READY_TIMEOUT = 60
    PROMPT_TIMEOUT = 10

    Result = Struct.new(:snapshots, :stdout, :warnings, keyword_init: true)

    # @param fixture [StreamReplay::Fixture] the stream to replay
    # @param frontend [String, nil] value for --frontend= (nil: pipe default)
    # @param settings [Hash{String=>String}] lich_settings rows the child
    #   starts with (e.g. a ;display toggle), seeded into its lich.db3
    def initialize(fixture, frontend: nil, settings: {})
      @fixture = fixture
      @frontend = frontend
      @settings = settings
      @warnings = []
    end

    # @return [Result]
    def run
      Dir.mktmpdir('lich_replay') do |tmp|
        %w[data scripts logs maps backup temp].each { |d| FileUtils.mkdir_p(File.join(tmp, d)) }
        FileUtils.cp(PROBE, File.join(tmp, 'scripts', 'replay_probe.lic'))
        seed_settings(File.join(tmp, 'data', 'lich.db3')) unless @settings.empty?
        snapshot_path = File.join(tmp, 'snapshots.jsonl')
        server = TCPServer.new('127.0.0.1', 0)
        stdout = +''
        begin
          Open3.popen2e(child_env(snapshot_path), *child_args(tmp, server.addr[1]), chdir: REPO) do |stdin, out, wait_thr|
            reader = Thread.new do
              loop { stdout << out.readpartial(65_536) }
            rescue IOError # includes EOFError
              nil
            end
            stdin.puts('LICH_REPLAY_KEY')
            stdin.puts('/FE:STORMFRONT /VERSION:1.0 /P:REPLAY /XML')
            stdin.flush
            conn = Timeout.timeout(30) { server.accept }
            conn.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
            conn.gets # login key
            drain = Thread.new do
              loop { break unless conn.readpartial(4096) }
            rescue StandardError
              nil
            end
            feed(conn, snapshot_path)
            conn.close_write
            drain.join(5)
            conn.close
            stdin.close
            wait_thr.join(15) || (Process.kill('TERM', wait_thr.pid) rescue nil)
            reader.join(5)
          end
        ensure
          server.close rescue nil
        end
        Result.new(snapshots: read_snapshots(snapshot_path), stdout: stdout, warnings: @warnings)
      end
    end

    private

    # Lich creates its tables only if they are missing, so a row seeded here
    # is what the child reads, as a setting a player had stored.
    def seed_settings(db_path)
      require 'sqlite3'
      db = SQLite3::Database.new(db_path)
      db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
      @settings.each { |name, value| db.execute('INSERT OR REPLACE INTO lich_settings(name,value) values(?,?);', [name.to_s, value.to_s]) }
    ensure
      db&.close
    end

    def child_env(snapshot_path)
      { 'BUNDLE_WITHOUT' => 'gtk:vscode:profanity', 'LICH_REPLAY_SNAPSHOTS' => snapshot_path }
    end

    def child_args(tmp, port)
      args = [
        'bundle', 'exec', 'ruby', '-r', OFFLINE_PRELOAD, 'lich.rbw',
        "--data=#{tmp}/data", "--temp=#{tmp}/temp", "--logs=#{tmp}/logs",
        "--scripts=#{tmp}/scripts", "--maps=#{tmp}/maps", "--backup=#{tmp}/backup",
        '-g', "127.0.0.1:#{port}", '--pipe', '--no-gtk',
        @fixture.game == 'DR' ? '--dragonrealms' : '--gemstone',
        '--start-scripts=replay_probe'
      ]
      args << "--frontend=#{@frontend}" if @frontend
      args
    end

    def feed(conn, snapshot_path)
      @snapshot_bytes = 0
      @snapshot_lines = 0
      @fixture.header_lines.each { |line| write_line(conn, line) }
      wait_until(READY_TIMEOUT, 'probe ready') { File.exist?(snapshot_path) && File.read(snapshot_path).include?("\n") }
      verify_offline!(snapshot_path)
      # Warm-up prompt: header strings may still be queued when the probe starts,
      # so whatever they leave behind (stripped lines, state) is absorbed by this
      # snapshot, which read_snapshots discards. Body snapshots are deterministic.
      write_line(conn, WARMUP_PROMPT)
      wait_until(PROMPT_TIMEOUT, 'warm-up snapshot') { snapshot_count(snapshot_path) >= 1 }
      expected = 1
      @fixture.body_lines.each do |line|
        write_line(conn, line)
        next unless line.include?('<prompt')

        expected += 1
        reached = wait_until(PROMPT_TIMEOUT, "snapshot #{expected}", raise_on_timeout: false) do
          snapshot_count(snapshot_path) >= expected
        end
        next if reached

        # A prompt-bearing line can legitimately produce no snapshot (e.g. it was
        # buffered by clean_serverstring). Resynchronise instead of stalling.
        actual = snapshot_count(snapshot_path)
        @warnings << "no snapshot for prompt line #{expected} (have #{actual}): #{line[0, 120].inspect}"
        expected = actual
      end
    end

    # The ready marker (line 1) carries the offline preload's self-check. A
    # replay that may reach the network is refused rather than allowed to pass.
    def verify_offline!(snapshot_path)
      marker = JSON.parse(File.foreach(snapshot_path).first)
      problems = marker.fetch('offline_problems', ['ready marker has no offline_problems'])
      return if problems.empty?

      raise "stream replay: the child is not offline (spec/support/stream_replay/offline_update.rb): #{problems.join('; ')}"
    end

    def write_line(conn, line)
      conn.write("#{line.chomp}\r\n")
      conn.flush
    end

    # Polled every few ms, so it reads only what the probe appended since the
    # last call instead of re-reading the whole file. Counts complete lines.
    def snapshot_count(path)
      return 0 unless File.exist?(path)

      File.open(path, 'rb') do |f|
        f.seek(@snapshot_bytes)
        appended = f.read
        @snapshot_bytes += appended.bytesize
        @snapshot_lines += appended.count("\n")
      end
      @snapshot_lines - 1 # first line is the ready marker
    end

    def wait_until(timeout, what, raise_on_timeout: true)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      until yield
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          raise Timeout::Error, "stream replay: timed out waiting for #{what}" if raise_on_timeout

          return false
        end
        sleep 0.002
      end
      true
    end

    def read_snapshots(path)
      return [] unless File.exist?(path)

      # Line 1 is the ready marker, line 2 the warm-up snapshot.
      File.foreach(path).drop(2).map { |l| JSON.parse(l) }
    end
  end
end
