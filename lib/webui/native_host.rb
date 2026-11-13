# frozen_string_literal: true

require 'os'
require 'json'
require 'fileutils'
require 'digest'
require 'time'
require 'open3'
require_relative 'errors'

module Lich
  module WebUI
    # Selects a native window helper and prepares missing helpers at startup.
    # Windows and Linux continue to use the browser launcher.
    module NativeHost
      EXECUTABLE = File.expand_path('native/macos/build/LichWebUI.app/Contents/MacOS/LichWebUI', __dir__).freeze
      SOURCES = %w[Host.swift ExternalLinks.swift Info.plist window.js build.sh].map do |name|
        File.expand_path("native/macos/#{name}", __dir__)
      end.freeze
      HELPERS = {
        macos: { name: 'macOS', executable: EXECUTABLE,
                 sources: SOURCES,
                 resources: [File.expand_path('native/macos/build/LichWebUI.app/Contents/Info.plist', __dir__),
                             File.expand_path('native/macos/build/LichWebUI.app/Contents/Resources/window.js', __dir__)].freeze,
                 lock: File.expand_path('native/macos/build/prepare.lock', __dir__),
                 notification: ['osascript', '-e'].freeze,
                 build: ['zsh', File.expand_path('native/macos/build.sh', __dir__)].freeze }.freeze,
      }.freeze

      # Distinguishes a remembered build failure from a newly attempted build.
      class BuildFailure < Error
        attr_reader :skipped

        # Carries safe failure text and whether this startup skipped the build.
        # @param message [String] authored build-failure message
        # @param skipped [Boolean] whether unchanged sources and toolchain already failed
        # @return [BuildFailure] initialized failure
        def initialize(message, skipped: false)
          super(message)
          @skipped = skipped
        end
      end

      module_function

      # Uses the OS gem to select the macOS native host path.
      # @return [Boolean] whether the current OS uses the AppKit host
      def mac? = OS.mac?

      # Selects the native host by OS and session availability; executable
      # availability is checked at launch. Browser fallback also disables native
      # capabilities for every runtime in this process.
      # @param platform [String, nil] explicit test/discovery override
      # @return [Symbol, nil] native host kind, or nil for a browser host
      def platform(platform = nil)
        return if @unavailable
        return :macos if platform ? platform.match?(/darwin/i) : mac?

        nil
      end

      # Sets the process-wide native availability used by dispatch and capabilities.
      # @param unavailable [Boolean] whether native preparation failed this session
      # @return [Boolean] assigned session state
      def unavailable=(unavailable)
        @unavailable = unavailable
      end

      # Builds a missing helper for the current OS using its existing local build.
      # Serializes concurrent startups and rechecks after locking. Failed builds
      # discard their executable and remember source and toolchain fingerprints
      # in DATA_DIR. Toolchain discovery runs after failures and before skips,
      # never for a normal successful build or a complete installed helper.
      # A remembered fingerprint skips the build unless the caller asks to retry;
      # changed sources or toolchain, or deleting the marker, permits another attempt.
      # Incomplete installed executables are removed before rebuilding resources.
      # Complete installed helpers need no writable lock. Builders publish their
      # executable last, after supplying all resources. Browser-only platforms
      # do no build work. Announces builds before they run and sends both build
      # output streams to the startup debug log through redirected stderr.
      # @param platform [String, nil] explicit test/discovery override
      # @param retry_failed [Boolean] attempt the build even when these sources
      #   already failed; startup passes true when no browser fallback exists
      # @return [Boolean] whether a native helper is available for this platform
      # @raise [Error] if preparation fails or leaves no executable helper
      def prepare!(platform: nil, retry_failed: false)
        helper = HELPERS[self.platform(platform)]
        return false unless helper
        if complete?(helper)
          clear_failure
          return true
        end

        FileUtils.mkdir_p(File.dirname(helper.fetch(:lock)))
        File.open(helper.fetch(:lock), File::RDWR | File::CREAT, 0o600) do |lock|
          lock.flock(File::LOCK_EX)
          if complete?(helper)
            clear_failure
            return true
          end

          source = source_fingerprint(helper)
          fingerprint = nil
          if !retry_failed && (previous = failed_fingerprint(source))
            fingerprint = failure_fingerprint(source)
            if previous == fingerprint
              Lich.log 'macOS WebUI helper build skipped: unchanged sources and toolchain previously failed; using browser degraded mode if available.'
              raise BuildFailure.new('macOS WebUI helper build previously failed', skipped: true)
            end
          end

          ready = false
          begin
            File.delete(helper.fetch(:executable)) if File.exist?(helper.fetch(:executable))
            announce_build(helper)
            built = system(*helper.fetch(:build), out: $stderr, err: $stderr)
            status = $?&.exitstatus
            ready = built && complete?(helper)
            unless ready
              record_failure(source, fingerprint || failure_fingerprint(source), status)
              raise BuildFailure, "#{helper.fetch(:name)} WebUI helper build failed"
            end
            clear_failure
          ensure
            File.delete(helper.fetch(:executable)) if !ready && File.exist?(helper.fetch(:executable))
          end
        end

        true
      rescue SystemCallError => error
        raise Error, "#{helper.fetch(:name)} WebUI helper preparation failed: #{error.class}"
      end

      # Identifies all helper inputs by name, byte length and contents in order.
      # @param helper [Hash] helper metadata containing its source file paths
      # @return [String] SHA-256 fingerprint of the build sources
      # @api private
      def source_fingerprint(helper)
        digest = Digest::SHA256.new
        helper.fetch(:sources).each do |path|
          contents = File.binread(path)
          digest << File.basename(path) << "\0" << contents.bytesize.to_s << "\0" << contents
        end
        digest.hexdigest
      end

      # Locates the user-writable failure marker, separate from installed sources.
      # @return [String] marker path in DATA_DIR
      # @api private
      def failure_marker
        File.join(DATA_DIR, 'webui-helper-build-failed.json')
      end

      # Clears remembered failure even if another startup already removed it.
      # @return [void]
      # @api private
      def clear_failure
        File.delete(failure_marker)
      rescue Errno::ENOENT
        nil
      end

      # Combines the source digest with compiler identity or command failure text.
      # @param source [String] current build-source fingerprint
      # @return [String] SHA-256 fingerprint of sources and toolchain identity
      # @api private
      def failure_fingerprint(source)
        identity = begin
          Open3.capture2e('xcrun', 'swiftc', '--version').first
        rescue SystemCallError => error
          error.message
        end
        Digest::SHA256.hexdigest("#{source}\0#{identity}")
      end

      # Reads a matching source record while the preparation lock is held.
      # Legacy source-only markers are returned so their next attempt migrates.
      # @param source [String] current build-source fingerprint
      # @return [String, nil] stored fingerprint, absent for new or changed sources
      # @api private
      def failed_fingerprint(source)
        record = JSON.parse(File.read(failure_marker))
        return unless record.is_a?(Hash)
        return unless record['source_fingerprint'] == source || record['fingerprint'] == source

        record['fingerprint']
      rescue Errno::ENOENT, JSON::ParserError
        nil
      end

      # Remembers a failed attempt while the preparation lock is held.
      # @param source [String] attempted build-source fingerprint
      # @param fingerprint [String] combined source and toolchain fingerprint
      # @param status [Integer, nil] build exit status, absent if no process exited
      # @return [void]
      # @api private
      def record_failure(source, fingerprint, status)
        record = { source_fingerprint: source, fingerprint: fingerprint, time: Time.now.utc.iso8601,
                   build_exit_status: status, debug_log_path: debug_log_path }
        File.open(failure_marker, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
          file.write(JSON.generate(record))
        end
      end

      # Names the exact startup debug log after stderr has been redirected.
      # @return [String, nil] current debug filename, absent before initialization
      def debug_log_path
        $stderr.path if $stderr.respond_to?(:path)
      end

      # Logs build progress and posts a detached macOS desktop notification.
      # Notification availability does not determine whether the helper builds.
      # @param helper [Hash] OS-specific helper metadata
      # @return [Process::Waiter, nil] detached notification waiter, if started
      # @api private
      def announce_build(helper)
        message = "Building the #{helper.fetch(:name)} WebUI helper for the first start after install or update; this may take a minute or two."
        Lich.log message
        begin
          pid = Process.spawn(*helper.fetch(:notification), "display notification #{message.dump} with title \"Lich WebUI\"",
                              out: $stderr, err: $stderr)
          Process.detach(pid)
        rescue SystemCallError
          # A desktop notification is optional; startup still needs the build.
          nil
        end
      end

      # Checks the executable and required resources without modifying the install.
      # Checks the executable last, matching the builder's publication order.
      # @param helper [Hash] OS-specific executable and required resource paths
      # @return [Boolean] whether the installed helper is complete and readable
      # @api private
      def complete?(helper)
        helper.fetch(:resources).all? { |path| File.file?(path) && File.readable?(path) } &&
          File.file?(helper.fetch(:executable)) && File.executable?(helper.fetch(:executable))
      end

      # Builds argv for an isolated native window. Never invokes a shell.
      # @param launch_file [String] private file containing the loopback launch URL
      # @param geometry [Hash, nil] initial outer size and desktop position
      # @return [Array<String>] executable and arguments
      # @raise [Error] if the helper has not been built or supplied
      def command_for(launch_file, geometry: nil)
        unless File.executable?(EXECUTABLE)
          raise Error, 'macOS WebUI helper is missing; run lib/webui/native/macos/build.sh, supply the prebuilt helper, or restart Lich to rebuild it'
        end

        [EXECUTABLE, launch_file, JSON.generate(geometry || {})]
      end
    end
  end
end
