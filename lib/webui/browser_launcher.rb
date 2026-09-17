# frozen_string_literal: true

require 'rbconfig'
require 'tmpdir'
require 'fileutils'
require_relative 'errors'

module Lich
  module WebUI
    # Opens an authenticated loopback URL in a dedicated Google Chrome app
    # window. App mode provides an OS title bar without browser tabs, location
    # controls, or bookmark chrome.
    module BrowserLauncher
      # Where Google Chrome is installed on macOS.
      MACOS_PATHS = [
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        File.join(Dir.home, 'Applications/Google Chrome.app/Contents/MacOS/Google Chrome'),
      ].freeze
      # Where Google Chrome is installed on Linux.
      LINUX_PATHS = [
        '/usr/bin/google-chrome',
        '/usr/bin/google-chrome-stable',
        '/opt/google/chrome/google-chrome',
      ].freeze

      # Set by the spec helper. A spec that shows a shim window without
      # stubbing the opener used to spawn a real Chrome on the developer's
      # desktop, pointed at 127.0.0.1/auth; every spec file had the stub, and
      # one new describe block without it was enough. With this set, only an
      # injected +spawn+ (a test double) may run; the real one is refused.
      NO_BROWSER_ENV = 'LICH_WEBUI_NO_BROWSER'

      module_function

      # Spawns a browser app window on +url+.
      #
      # With +on_exit+ the browser gets a private profile directory, its
      # process is watched, and the callback runs when it exits; without,
      # the process is detached and shares the player's profile.
      #
      # @param url [String] the launch URL
      # @param spawn [#call] spawns the process; `Process.spawn` unless a test injects a double
      # @param detach [#call] detaches a process not being watched
      # @param platform [String] the platform string, `RUBY_PLATFORM` by default
      # @param browser_path [String, nil] an explicit browser executable
      # @param chrome_path [String, nil] older name for +browser_path+
      # @param geometry [Hash{Symbol => Object}, nil] `width:`, `height:` and optional `position:`
      # @param on_exit [#call, nil] called when the watched browser process exits
      # @param on_start [#call, nil] called with the pid as soon as the process is spawned
      # @param waitpid [#call] waits on the watched process
      # @param thread_factory [#call] builds the watching thread from a block
      # @return [Boolean] whether a browser was spawned; false when refused or when spawning failed
      def open(url, spawn: Process.method(:spawn), detach: Process.method(:detach), platform: RUBY_PLATFORM,
               browser_path: nil, chrome_path: nil, geometry: nil, on_exit: nil,
               on_start: nil, waitpid: Process.method(:waitpid),
               thread_factory: ->(&block) { Thread.new(&block) })
        return false if browser_refused?(spawn)

        profile_dir = Dir.mktmpdir('lich-webui-browser-') if on_exit
        command = command_for(
          url, platform: platform, browser_path: browser_path || chrome_path,
          geometry: geometry, profile_dir: profile_dir
        )
        pid = spawn.call(*command, out: File::NULL, err: File::NULL)
        on_start&.call(pid)
        if on_exit
          monitor_process(pid, profile_dir, waitpid: waitpid, thread_factory: thread_factory, on_exit: on_exit)
        else
          detach.call(pid)
        end
        true
      rescue StandardError => error
        remove_profile(profile_dir)
        Lich.log("warning: unable to open WebUI browser: #{error.class}: #{error.message}") if Lich.respond_to?(:log)
        false
      end

      # True when a real process spawn is about to happen inside a run that
      # forbade it. A test double for +spawn+ is always allowed through.
      #
      # @param spawn [#call] the spawner {.open} was given
      # @return [Boolean]
      def browser_refused?(spawn)
        return false if ENV[NO_BROWSER_ENV].to_s.empty?

        spawn == Process.method(:spawn)
      end

      # The command line that opens +url+ as an app window.
      #
      # @param url [String] the launch URL
      # @param platform [String] the platform string
      # @param browser_path [String, nil] an explicit browser executable
      # @param chrome_path [String, nil] older name for +browser_path+
      # @param geometry [Hash{Symbol => Object}, nil] `width:`, `height:` and optional `position:`
      # @param profile_dir [String, nil] a private profile directory, when the process is to be watched
      # @return [Array<String>] the executable and its arguments
      # @raise [Error] when no supported browser is installed
      def command_for(url, platform: RUBY_PLATFORM, browser_path: nil, chrome_path: nil, geometry: nil,
                      profile_dir: nil)
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
        # The launch token rides in the command line, so for its single-use
        # 60-second life it is readable by any other local user who can list
        # processes (ps, /proc/<pid>/cmdline, the Windows process table).
        # A shared multi-user desktop is outside the threat model; the
        # token is one-shot and expires, and the session cookie it redeems
        # never appears in argv.
        [executable, '--new-window', *profile_arguments, *geometry_arguments(geometry), "--app=#{url}"]
      end

      # Waits for the browser process on its own thread, then runs +on_exit+ and removes the profile.
      #
      # @param pid [Integer] the browser's process id
      # @param profile_dir [String, nil] the private profile directory to remove afterwards
      # @param waitpid [#call] waits on the process
      # @param thread_factory [#call] builds the watching thread from a block
      # @param on_exit [#call] called when the process exits
      # @return [Thread] the watching thread
      def monitor_process(pid, profile_dir, waitpid:, thread_factory:, on_exit:)
        thread_factory.call do
          begin
            waitpid.call(pid, 0)
          rescue Errno::ECHILD, Errno::ESRCH
            nil
          ensure
            begin
              on_exit.call
            ensure
              remove_profile(profile_dir)
            end
          end
        end
      end

      # Deletes a private profile directory, ignoring any failure.
      #
      # @param profile_dir [String, nil] the directory
      # @return [void]
      def remove_profile(profile_dir)
        FileUtils.remove_entry_secure(profile_dir) if profile_dir && File.directory?(profile_dir)
      rescue StandardError
        nil
      end

      # The window size and position flags for a geometry, or none when it is incomplete.
      #
      # @param geometry [Hash{Symbol => Object}, nil] `width:`, `height:` Integers and optional `position:` pair
      # @return [Array<String>] the flags
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

      # The first installed browser able to open an app window: Chrome, or Edge on Windows.
      #
      # @param platform [String] the platform string
      # @param executable [#call] tests whether a path is executable
      # @param environment [Hash, ENV] where the Windows install roots are read from
      # @return [String, nil] the executable path, or nil when none is installed
      def app_browser_path(platform: RUBY_PLATFORM, executable: File.method(:executable?), environment: ENV)
        candidates = chrome_candidates(platform: platform, environment: environment)
        candidates += edge_candidates(environment: environment) if windows?(platform)
        candidates.find { |path| executable.call(path) }
      end

      # The installed Google Chrome, if any.
      #
      # @param platform [String] the platform string
      # @param executable [#call] tests whether a path is executable
      # @return [String, nil] the executable path, or nil when Chrome is not installed
      def google_chrome_path(platform: RUBY_PLATFORM, executable: File.method(:executable?))
        chrome_candidates(platform: platform).find { |path| executable.call(path) }
      end

      # Where Google Chrome might be installed on this platform.
      #
      # @param platform [String] the platform string
      # @param environment [Hash, ENV] where the Windows install roots are read from
      # @return [Array<String>] candidate paths
      def chrome_candidates(platform: RUBY_PLATFORM, environment: ENV)
        return MACOS_PATHS if platform.match?(/darwin/i)
        return LINUX_PATHS unless windows?(platform)

        %w[PROGRAMFILES PROGRAMFILES(X86) LOCALAPPDATA].filter_map do |variable|
          root = environment[variable]
          File.join(root, 'Google', 'Chrome', 'Application', 'chrome.exe') unless root.to_s.empty?
        end
      end

      # Where Microsoft Edge might be installed on Windows.
      #
      # @param environment [Hash, ENV] where the install roots are read from
      # @return [Array<String>] candidate paths
      def edge_candidates(environment: ENV)
        %w[PROGRAMFILES PROGRAMFILES(X86) LOCALAPPDATA].filter_map do |variable|
          root = environment[variable]
          File.join(root, 'Microsoft', 'Edge', 'Application', 'msedge.exe') unless root.to_s.empty?
        end
      end

      # Whether a platform string names Windows.
      #
      # @param platform [String] the platform string
      # @return [Boolean]
      def windows?(platform)
        platform.match?(/mingw|mswin|cygwin/i)
      end
    end
  end
end
