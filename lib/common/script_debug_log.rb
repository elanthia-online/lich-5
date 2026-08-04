# frozen_string_literal: true

require 'fileutils'
require_relative 'script_death'

module Lich
  module Common
    # Per-script debug log writer.
    #
    # Scripts opt in with +Script.current.debug_log = true+ and push their own
    # breadcrumbs with +Script.current.debug_msg("...")+. While a log is open the
    # script's file also receives the four data channels Script already fans out
    # (see {Script.new_downstream_xml}, {Script.new_downstream},
    # {Script.new_upstream} and {Script.new_script_output}), so a script no longer
    # needs to register its own Up/DownstreamHooks or run capture threads to get
    # a transcript.
    #
    # Files land at:
    #   LOG_DIR/debug/<game>-<character>/<script>/<YYYYmmdd-HHMMSS>.log
    #
    # One file per run, so runs are never concatenated. Old files are pruned on
    # open to {DEFAULT_RETAINED_RUNS}. Retention here is script-level and
    # self-contained: Lich's own debug logging and its retention preference are
    # a separate concern and are not involved.
    #
    # There is deliberately no writer thread. Writes go to a buffered append
    # handle, which makes the common case a userspace copy rather than a
    # syscall, and means the kill path (which reaps a script's worker threads
    # before its at_exit handlers run) has nothing to reap and no queued tail to
    # lose. Stream channels are flushed on a line/time threshold; a script's own
    # {#write} messages are flushed immediately, since those are the breadcrumbs
    # someone is usually tailing the file to read.
    class ScriptDebugLog
      # Fixed-width channel tags, so a merged file stays greppable and columns
      # line up. MSG is a script's own debug_msg output.
      CHANNELS = {
        :downstream_xml => 'XML ',
        :downstream     => 'GAME',
        :upstream       => 'YOU ',
        :script_output  => 'OUT ',
        :message        => 'MSG '
      }.freeze

      # Buffered stream lines are flushed once this many are pending.
      FLUSH_LINE_THRESHOLD = 64

      # ...or once this many seconds have passed since the last flush.
      FLUSH_IDLE_SECONDS = 1.0

      # Per-run files kept per script directory, unless overridden via
      # ScriptDebugLog.retained_runs=. Script-level retention only; Lich's own
      # debug log retention is a separate concern and is not consulted.
      DEFAULT_RETAINED_RUNS = 20

      # Keyed by identity: the registry is scoped to specific live Script
      # objects, and compare_by_identity says so without hashing object_ids.
      @registry = {}.compare_by_identity
      @snapshot = [].freeze
      @registry_mutex = Mutex.new

      class << self
        # Whether any script currently has a debug log open. Read without a lock
        # so the fan-out call sites pay a single comparison when nobody is
        # debugging, which is the overwhelmingly common case.
        #
        # @return [Boolean]
        def active?
          !@snapshot.empty?
        end

        # Opens a log for +script+, or returns the one already open. Idempotent,
        # so a script may set +debug_log = true+ more than once harmlessly.
        #
        # @param script [Script] the script to log for
        # @return [ScriptDebugLog, nil] the writer, or nil if it could not open
        def open_for(script)
          return nil unless script

          existing = @registry_mutex.synchronize { @registry[script] }
          return existing if existing

          begin
            writer = new(script)
          rescue StandardError => e
            __report("could not open debug log for #{script.name}: #{e}")
            return nil
          end

          @registry_mutex.synchronize do
            if @registry.key?(script)
              writer.close
              @registry[script]
            else
              @registry[script] = writer
              __refresh_snapshot_locked
              writer
            end
          end
        end

        # Flushes, closes and deregisters +script+'s log, if it has one.
        #
        # @param script [Script] the script whose log should be closed
        # @return [ScriptDebugLog, nil] the closed writer, if there was one
        def close_for(script)
          return nil unless script

          writer = @registry_mutex.synchronize do
            removed = @registry.delete(script)
            __refresh_snapshot_locked if removed
            removed
          end
          writer&.close
          writer
        end

        # The open writer for +script+, if any.
        #
        # @param script [Script]
        # @return [ScriptDebugLog, nil]
        def for(script)
          return nil unless script

          @registry_mutex.synchronize { @registry[script] }
        end

        # Writes +line+ to every open log. Called from the Script fan-out
        # methods, already guarded by {active?}.
        #
        # @param channel [Symbol] a key of {CHANNELS}
        # @param line [String] the payload
        # @return [void]
        def broadcast(channel, line)
          @snapshot.each { |writer| writer.write(channel, line) }
          nil
        end

        # Closes every open log. Used by specs and process shutdown.
        #
        # @return [void]
        def close_all
          writers = @registry_mutex.synchronize do
            open_writers = @registry.values
            @registry = {}.compare_by_identity
            __refresh_snapshot_locked
            open_writers
          end
          writers.each(&:close)
          nil
        end

        # The directory this script's logs are written to, whether or not one is
        # currently open. Lets a script tell the user where transcripts will land
        # without having to know the layout itself.
        #
        # @param script [Script]
        # @return [String, nil] the directory, or nil without a script
        def directory_for(script)
          return nil unless script

          __directory_for(script.name.to_s)
        end

        # Number of per-run files to keep per script directory.
        #
        # Deliberately independent of Lich's own debug log retention: that
        # setting governs Lich's internal/API logging, and a user tuning it
        # should not silently change how many script transcripts are kept.
        #
        # @return [Integer]
        def retained_runs
          limit = (@retained_runs || DEFAULT_RETAINED_RUNS).to_i
          limit > 0 ? limit : DEFAULT_RETAINED_RUNS
        end

        # Overrides how many per-run files to keep per script directory, for the
        # life of this process. Not persisted; nil restores {DEFAULT_RETAINED_RUNS}.
        #
        # @param limit [Integer, nil] runs to keep, or nil for the default
        # @return [Integer, nil] the value assigned (Ruby setter semantics)
        def retained_runs=(limit)
          @retained_runs = limit.nil? ? nil : limit.to_i
        end

        # Rebuilds the lock-free read snapshot. Caller must hold the mutex.
        #
        # @return [void]
        def __refresh_snapshot_locked
          @snapshot = @registry.values.freeze
          nil
        end
        private :__refresh_snapshot_locked

        # Surfaces a writer problem without raising into the game stream.
        #
        # @param message [String]
        # @return [void]
        def __report(message)
          text = "--- Lich: ScriptDebugLog: #{message}"
          Lich.log(text) if defined?(Lich) && Lich.respond_to?(:log)
          respond(text) if respond_to?(:respond, true)
          nil
        rescue StandardError
          nil
        end
      end

      # @return [String] absolute path of the file being written
      attr_reader :path

      # @return [String] the owning script's name
      attr_reader :script_name

      # @param script [Script] the script this log belongs to
      def initialize(script)
        @script_name = script.name.to_s
        @mutex = Mutex.new
        @pending = 0
        @last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        directory = self.class.__send__(:__directory_for, @script_name)
        FileUtils.mkdir_p(directory)
        self.class.__send__(:__prune, directory)

        @path = File.join(directory, "#{Time.now.strftime('%Y%m%d-%H%M%S')}.log")
        @io = File.open(@path, 'a')
        __write_header(script)
      end

      # Appends one line. Never raises into the caller; an IO failure closes the
      # log and reports once.
      #
      # @param channel [Symbol] a key of {CHANNELS}
      # @param line [String] the payload
      # @return [void]
      def write(channel, line)
        return if line.nil?

        text = line.to_s.sub(/[\r\n]+\z/, '')
        return if text.empty?

        tag = CHANNELS.fetch(channel, CHANNELS[:message])
        stamp = Time.now.strftime('%Y-%m-%d %H:%M:%S.%L')

        @mutex.synchronize do
          next if @io.nil?

          @io.puts("[#{stamp}] #{tag} #{text}")
          @pending += 1
          if channel == :message
            @io.flush
            @pending = 0
            @last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          else
            __flush_if_due
          end
        end
        nil
      rescue StandardError => e
        __disable(e)
      end

      # Whether this writer still has an open handle.
      #
      # @return [Boolean]
      def open?
        @mutex.synchronize { !@io.nil? }
      end

      # Forces buffered stream lines to disk. {#write} already flushes +:message+
      # entries immediately; this is for callers that want the batched channels
      # on disk at a known point.
      #
      # @return [void]
      def flush
        @mutex.synchronize do
          next if @io.nil?

          @io.flush
          @pending = 0
          @last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
        nil
      rescue StandardError => e
        __disable(e)
      end

      # Flushes and closes. Safe to call more than once.
      #
      # @return [void]
      def close
        @mutex.synchronize do
          next if @io.nil?

          begin
            @io.puts("[#{Time.now.strftime('%Y-%m-%d %H:%M:%S.%L')}] #{CHANNELS[:message]} debug log closed")
            @io.flush
          rescue StandardError
            nil
          ensure
            begin
              @io.close
            rescue StandardError
              nil
            end
            @io = nil
            @pending = 0
          end
        end
        nil
      end

      private

      # Writes the run header. Values are looked up defensively so an early
      # open (or a spec) cannot fail the whole log.
      #
      # @param script [Script]
      # @return [void]
      def __write_header(script)
        details = []
        details << "script: #{@script_name}"
        details << "version: #{LICH_VERSION}" if defined?(LICH_VERSION)
        details << "game: #{XMLData.game}" if defined?(XMLData) && XMLData.respond_to?(:game)
        details << "character: #{XMLData.name}" if defined?(XMLData) && XMLData.respond_to?(:name)
        args = script.vars[0] if script.respond_to?(:vars) && script.vars.is_a?(Array)
        details << "args: #{args}" unless args.nil? || args.to_s.empty?
        write(:message, "debug log opened (#{details.join(' | ')})")
      rescue StandardError
        nil
      end

      # Flushes when the pending-line or elapsed-time threshold is reached.
      # Caller must hold the mutex.
      #
      # @return [void]
      def __flush_if_due
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return if @pending < FLUSH_LINE_THRESHOLD && (now - @last_flush) < FLUSH_IDLE_SECONDS

        @io.flush
        @pending = 0
        @last_flush = now
        nil
      end

      # Closes the handle after a write failure so one bad file cannot spam the
      # game stream on every subsequent line.
      #
      # @param error [StandardError]
      # @return [void]
      def __disable(error)
        @mutex.synchronize do
          begin
            @io&.close
          rescue StandardError
            nil
          end
          @io = nil
        end
        self.class.__send__(:__report, "write failed for #{@script_name}, log closed: #{error}")
        nil
      end

      class << self
        private

        # Builds the per-script directory, sanitising the script name the same
        # way Script.db/Script.open_file do for path segments.
        #
        # @param script_name [String]
        # @return [String]
        def __directory_for(script_name)
          character = if defined?(XMLData) && XMLData.respond_to?(:game) && XMLData.respond_to?(:name)
                        "#{XMLData.game}-#{XMLData.name}"
                      else
                        'unknown'
                      end
          File.join(LOG_DIR, 'debug', __safe_segment(character), __safe_segment(script_name))
        end

        # @param value [String]
        # @return [String] a single path segment safe on all platforms
        def __safe_segment(value)
          segment = value.to_s.gsub(%r{[/\\:*?"<>|\s]+}, '_')
          segment.empty? ? 'unknown' : segment
        end

        # Keeps the newest {retained_runs} logs in +directory+. Filenames encode a
        # timestamp, so a lexicographic sort is newest-last.
        #
        # @param directory [String]
        # @return [void]
        def __prune(directory)
          limit = retained_runs
          existing = Dir.children(directory).select { |name| name.match?(/\A\d{8}-\d{6}\.log\z/) }
          return if existing.length < limit

          existing.sort.reverse[(limit - 1)..-1].to_a.each do |name|
            File.delete(File.join(directory, name))
          rescue StandardError
            nil
          end
          nil
        rescue StandardError
          nil
        end
      end

      # Close a script's log as part of normal script teardown. Registered here
      # rather than in Script#kill, mirroring how the hook registries attach
      # their own cleanup (see UpstreamHook). ScriptDeath handlers run after a
      # script's at_exit procs, so anything a before_dying block logs is still
      # captured before the flush.
      ScriptDeath.on_death { |script| close_for(script) }
    end
  end
end
