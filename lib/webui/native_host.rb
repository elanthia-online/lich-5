# frozen_string_literal: true

require 'os'
require 'json'
require 'fileutils'
require_relative 'errors'

module Lich
  module WebUI
    # Selects a native window helper and prepares missing helpers at startup.
    # Windows and Linux continue to use the browser launcher.
    module NativeHost
      EXECUTABLE = File.expand_path('native/macos/build/LichWebUI.app/Contents/MacOS/LichWebUI', __dir__).freeze
      HELPERS = {
        macos: { name: 'macOS', executable: EXECUTABLE,
                 resources: [File.expand_path('native/macos/build/LichWebUI.app/Contents/Info.plist', __dir__),
                             File.expand_path('native/macos/build/LichWebUI.app/Contents/Resources/window.js', __dir__)].freeze,
                 lock: File.expand_path('native/macos/build/prepare.lock', __dir__),
                 notification: ['osascript', '-e'].freeze,
                 build: ['zsh', File.expand_path('native/macos/build.sh', __dir__)].freeze }.freeze,
      }.freeze

      module_function

      # Uses the OS gem to select the macOS native host path.
      # @return [Boolean] whether the current OS uses the AppKit host
      def mac? = OS.mac?

      # Selects the native host by OS; executable availability is checked at launch.
      # @param platform [String, nil] explicit test/discovery override
      # @return [Symbol, nil] native host kind, or nil for a browser host
      def platform(platform = nil)
        return :macos if platform ? platform.match?(/darwin/i) : mac?

        nil
      end

      # Builds a missing helper for the current OS using its existing local build.
      # Serializes concurrent startups and rechecks after locking. Failed builds
      # discard their executable so a later startup retries the complete build.
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

          ready = false
          begin
            File.delete(helper.fetch(:executable)) if File.exist?(helper.fetch(:executable))
            announce_build(helper)
            built = system(*helper.fetch(:build), out: $stderr, err: $stderr)
            ready = built && complete?(helper)
            unless ready
              raise Error, "#{helper.fetch(:name)} WebUI helper build failed; check the debug log and retry"
            end
          ensure
            File.delete(helper.fetch(:executable)) if !ready && File.exist?(helper.fetch(:executable))
          end
        end

        true
      rescue SystemCallError => error
        raise Error, "#{helper.fetch(:name)} WebUI helper preparation failed: #{error.class}"
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
