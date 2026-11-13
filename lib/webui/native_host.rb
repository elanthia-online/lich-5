# frozen_string_literal: true

require 'os'
require 'json'
require 'fileutils'
require 'digest'
require 'time'
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
        # @param skipped [Boolean] whether unchanged sources already failed
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
      # discard their executable and remember the source fingerprint in DATA_DIR.
      # A changed source fingerprint or deleting the marker permits another attempt.
      # Incomplete installed executables are removed before rebuilding resources.
      # Complete installed helpers need no writable lock. Builders publish their
      # executable last, after supplying all resources. Browser-only platforms
      # do no build work. Announces builds before they run and sends both build
      # output streams to the startup debug log through redirected stderr.
      # @param platform [String, nil] explicit test/discovery override
      # @return [Boolean] whether a native helper is available for this platform
      # @raise [Error] if preparation fails or leaves no executable helper
      def prepare!(platform: nil)
        helper = HELPERS[self.platform(platform)]
        return false unless helper
        return true if complete?(helper)

        FileUtils.mkdir_p(File.dirname(helper.fetch(:lock)))
        File.open(helper.fetch(:lock), File::RDWR | File::CREAT, 0o600) do |lock|
          lock.flock(File::LOCK_EX)
          return true if complete?(helper)

          fingerprint = source_fingerprint(helper)
          if failed_fingerprint?(fingerprint)
            Lich.log 'macOS WebUI helper build skipped: unchanged sources previously failed; using browser degraded mode if available.'
            raise BuildFailure.new('macOS WebUI helper build previously failed', skipped: true)
          end

          ready = false
          begin
            File.delete(helper.fetch(:executable)) if File.exist?(helper.fetch(:executable))
            announce_build(helper)
            built = system(*helper.fetch(:build), out: $stderr, err: $stderr)
            status = $?&.exitstatus
            ready = built && complete?(helper)
            unless ready
              record_failure(fingerprint, status)
              raise BuildFailure, "#{helper.fetch(:name)} WebUI helper build failed"
            end
            File.delete(failure_marker) if File.exist?(failure_marker)
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

      # Reads a remembered failure while the preparation lock is held.
      # An absent or incomplete marker permits a fresh attempt.
      # @param fingerprint [String] current build-source fingerprint
      # @return [Boolean] whether these sources already failed to build
      # @api private
      def failed_fingerprint?(fingerprint)
        record = JSON.parse(File.read(failure_marker))
        record.is_a?(Hash) && record['fingerprint'] == fingerprint
      rescue Errno::ENOENT, JSON::ParserError
        false
      end

      # Remembers a failed attempt while the preparation lock is held.
      # @param fingerprint [String] attempted build-source fingerprint
      # @param status [Integer, nil] build exit status, absent if no process exited
      # @return [void]
      # @api private
      def record_failure(fingerprint, status)
        record = { fingerprint: fingerprint, time: Time.now.utc.iso8601,
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
