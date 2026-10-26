# frozen_string_literal: true

require_relative 'host_thread'

require 'rbconfig'
require 'tmpdir'
require 'fileutils'
require 'cgi/escape'
require 'uri'
require_relative 'errors'
require_relative 'native_host'

module Lich
  module WebUI
    # Opens an authenticated loopback URL in a native helper or a
    # dedicated browser app process. Explicit browser paths remain available
    # for browser comparisons and callers that intentionally choose Chrome.
    module BrowserLauncher
      MACOS_PATHS = [
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        File.join(Dir.home, 'Applications/Google Chrome.app/Contents/MacOS/Google Chrome'),
      ].freeze
      LINUX_PATHS = [
        '/usr/bin/google-chrome',
        '/usr/bin/google-chrome-stable',
        '/opt/google/chrome/google-chrome',
      ].freeze

      module_function

      # Spawns one app host using a private launch file instead of secret argv.
      # Every browser receives an isolated profile, removed after process exit.
      # The start callback runs before the exit monitor is installed, so callers
      # must defer termination until this method returns.
      # @param url [String] authenticated loopback launch URL
      # @param spawn [#call] process creator accepting an argv array and options
      # @param platform [String, nil] discovery override; nil uses the current OS
      # @param browser_path [String, nil] explicit browser, bypassing the native host
      # @param chrome_path [String, nil] legacy alias for browser_path
      # @param geometry [Hash, nil] initial outer dimensions and desktop position
      # @param on_exit [#call, nil] callback after the owned process exits
      # @param on_start [#call, nil] callback receiving the spawned PID
      # @param waitpid [#call] blocking process-exit observer
      # @param thread_factory [#call] factory for the host-owned monitor thread
      # @return [Boolean] whether spawn and monitor setup succeeded
      def open(url, spawn: Process.method(:spawn), platform: nil,
               browser_path: nil, chrome_path: nil, geometry: nil, on_exit: nil,
               on_start: nil, waitpid: Process.method(:waitpid),
               thread_factory: HostThread.method(:start))
        native = native_host(platform, browser_path || chrome_path)
        profile_dir = Dir.mktmpdir('lich-webui-browser-')
        target = launch_file(url, profile_dir, native: native)
        command = command_for(
          target, platform: platform, browser_path: browser_path || chrome_path,
          geometry: geometry, profile_dir: native ? nil : profile_dir
        )
        pid = spawn.call(*command, out: File::NULL, err: File::NULL)
        on_start&.call(pid)
        monitor_process(pid, profile_dir, waitpid: waitpid, thread_factory: thread_factory, on_exit: on_exit)
        true
      rescue StandardError => error
        remove_profile(profile_dir)
        Lich.log("warning: unable to open WebUI browser: #{error.class}") if Lich.respond_to?(:log)
        false
      end

      # Selects native or browser argv without invoking a shell or starting a process.
      # @param url [String] private launch-file path (native) or file URL (browser)
      # @param platform [String, nil] discovery override; nil uses the current OS
      # @param browser_path [String, nil] explicit browser, bypassing native selection
      # @param chrome_path [String, nil] legacy alias for browser_path
      # @param geometry [Hash, nil] initial outer dimensions and desktop position
      # @param profile_dir [String, nil] isolated browser profile directory
      # @return [Array<String>] executable followed by its arguments
      # @raise [Error] if the required native helper or browser is unavailable
      def command_for(url, platform: nil, browser_path: nil, chrome_path: nil, geometry: nil,
                      profile_dir: nil)
        if native_host(platform, browser_path || chrome_path)
          return NativeHost.command_for(url, geometry: geometry)
        end

        platform ||= OS.host_os
        executable = browser_path || chrome_path || app_browser_path(platform: platform)
        unless executable
          requirement = windows?(platform) ? 'Google Chrome or Microsoft Edge' : 'Google Chrome'
          raise Error, "#{requirement} is required to open the WebUI launcher window"
        end

        profile_arguments = if profile_dir
                              ["--user-data-dir=#{profile_dir}", '--no-first-run', '--no-default-browser-check']
                            else
                              []
                            end
        [executable, '--new-window', *profile_arguments, *geometry_arguments(geometry), "--app=#{url}"]
      end

      # An explicit platform is a test/discovery override; normal dispatch uses
      # the os gem rather than guessing from a Ruby build-platform string.
      # @param platform [String, nil] discovery override
      # @param browser_path [String, nil] explicit browser that disables native selection
      # @return [Symbol, nil] native host kind, absent for explicit browsers
      def native_host(platform, browser_path)
        NativeHost.platform(platform) unless browser_path
      end

      # Stores the one-use credential inside the launch directory (0700 on POSIX).
      # Windows also relies on the user's private temporary-directory ACL.
      # @param url [String] authenticated loopback launch URL; never logged
      # @param directory [String] freshly created private launch/profile directory
      # @param native [Symbol, nil] native host kind, or nil for a browser
      # @return [String] native file path or percent-encoded browser file URL
      def launch_file(url, directory, native:)
        path = File.join(directory, native ? 'launch.url' : 'launch.html')
        content = native ? url : %(<meta name="referrer" content="no-referrer"><meta http-equiv="refresh" content="0;url=#{CGI.escapeHTML(url)}">)
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(content) }
        return path if native

        normalized = File.expand_path(path).tr('\\', '/')
        normalized = "/#{normalized}" unless normalized.start_with?('/')
        "file://#{URI::DEFAULT_PARSER.escape(normalized, /[^A-Za-z0-9\-._~\/:]/)}"
      end

      # Reaps the owned host and removes its credential file and browser profile.
      # @param pid [Integer] exact spawned process id
      # @param profile_dir [String] private launch/profile directory
      # @param waitpid [#call] blocking process-exit observer
      # @param thread_factory [#call] factory for a host-owned monitor
      # @param on_exit [#call, nil] optional owner notification
      # @return [Thread] monitor returned by the thread factory
      def monitor_process(pid, profile_dir, waitpid:, thread_factory:, on_exit:)
        thread_factory.call do
          begin
            waitpid.call(pid, 0)
          rescue Errno::ECHILD, Errno::ESRCH
            nil
          ensure
            begin
              on_exit&.call
            ensure
              remove_profile(profile_dir)
            end
          end
        end
      end

      # Removes private launch data after exit or failed startup.
      # @param profile_dir [String, nil] private directory, absent before allocation
      # @return [void]
      def remove_profile(profile_dir)
        FileUtils.remove_entry_secure(profile_dir) if profile_dir && File.directory?(profile_dir)
      rescue StandardError
        nil
      end

      # Builds Chromium size/position arguments only from integer geometry.
      # @return [Array<String>] command-line arguments
      def geometry_arguments(geometry)
        return [] unless geometry.is_a?(Hash)

        width = geometry[:width]
        height = geometry[:height]
        position = geometry[:position]
        return [] unless width.is_a?(Integer) && height.is_a?(Integer)

        arguments = ["--window-size=#{width},#{height}"]
        if position.is_a?(Array) && position.length == 2 && position.all? { |value| value.is_a?(Integer) }
          arguments << "--window-position=#{position.join(',')}"
        end
        arguments
      end

      # Selects the first executable Chrome candidate, then Edge on Windows.
      # Injected platform/environment/probes allow discovery tests without launching a browser.
      # @return [String, nil] executable path
      def app_browser_path(platform: RUBY_PLATFORM, executable: File.method(:executable?), environment: ENV)
        candidates = chrome_candidates(platform: platform, environment: environment)
        candidates += edge_candidates(environment: environment) if windows?(platform)
        candidates.find { |path| executable.call(path) }
      end

      # Finds Chrome specifically for callers that require that browser.
      # @return [String, nil] executable path
      def google_chrome_path(platform: RUBY_PLATFORM, executable: File.method(:executable?))
        chrome_candidates(platform: platform).find { |path| executable.call(path) }
      end

      # Lists conventional installation paths for the requested host platform.
      # @return [Array<String>] ordered discovery candidates
      def chrome_candidates(platform: RUBY_PLATFORM, environment: ENV)
        return MACOS_PATHS if platform.match?(/darwin/i)
        return LINUX_PATHS unless windows?(platform)

        %w[PROGRAMFILES PROGRAMFILES(X86) LOCALAPPDATA].filter_map do |variable|
          root = environment[variable]
          File.join(root, 'Google', 'Chrome', 'Application', 'chrome.exe') unless root.to_s.empty?
        end
      end

      # Lists Windows Edge paths beneath the available installation environment roots.
      # @return [Array<String>] ordered discovery candidates
      def edge_candidates(environment: ENV)
        %w[PROGRAMFILES PROGRAMFILES(X86) LOCALAPPDATA].filter_map do |variable|
          root = environment[variable]
          File.join(root, 'Microsoft', 'Edge', 'Application', 'msedge.exe') unless root.to_s.empty?
        end
      end

      # Recognizes Windows Ruby platform strings for browser executable discovery.
      # @return [Boolean]
      def windows?(platform)
        platform.match?(/mingw|mswin|cygwin/i)
      end
    end
  end
end
