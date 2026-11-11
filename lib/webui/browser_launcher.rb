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
    # dedicated browser app process. Automatic discovery finds Chrome (plus Edge
    # on Windows and distro Chromium on Linux). Any other Chromium-based browser
    # is chosen at the user's risk by an explicit path: the launcher Settings
    # "Browser path", or LICH_WEBUI_BROWSER, which is read before any window
    # exists so a host without Chrome can still reach one. Precedence: explicit
    # argument, then LICH_WEBUI_BROWSER, then automatic discovery. Snap-packaged
    # Chromium is never used: snap confinement gives it a private /tmp, so it
    # cannot open the launch file. Discovery skips it, and an explicit path or
    # LICH_WEBUI_BROWSER naming it is refused with a message asking for a
    # non-snap Chrome or Chromium.
    module BrowserLauncher
      # Environment variable naming a browser executable for every window.
      ENVIRONMENT_VARIABLE = 'LICH_WEBUI_BROWSER'
      SETTING_HINT = 'set the Browser path in the launcher Settings'
      ROUTES_HINT = "#{SETTING_HINT} or the #{ENVIRONMENT_VARIABLE} environment variable".freeze
      private_constant :SETTING_HINT, :ROUTES_HINT

      MACOS_PATHS = [
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        File.join(Dir.home, 'Applications/Google Chrome.app/Contents/MacOS/Google Chrome'),
      ].freeze
      LINUX_PATHS = [
        '/usr/bin/google-chrome',
        '/usr/bin/google-chrome-stable',
        '/opt/google/chrome/google-chrome',
      ].freeze
      # Distro Chromium, tried only after every Chrome path. On Ubuntu
      # /usr/bin/chromium-browser is a script that execs snap Chromium; the
      # snap test below skips it.
      LINUX_CHROMIUM_PATHS = %w[/usr/bin/chromium /usr/bin/chromium-browser].freeze
      LINUX_CHROMIUM_NAMES = %w[chromium chromium-browser].freeze
      # Snap installs its applications under this root.
      SNAP_ROOT = '/snap/'
      # Every snap application command is a link to this launcher.
      SNAP_LAUNCHER = '/usr/bin/snap'
      # A wrapper script larger than this is not read when looking for snap.
      SNAP_WRAPPER_LIMIT = 4096

      module_function

      # Spawns one app host using a private launch file instead of secret argv.
      # Every browser receives an isolated profile, removed after process exit.
      # The start callback runs before the exit monitor is installed, so callers
      # must defer termination until this method returns.
      # @param url [String] authenticated loopback launch URL
      # @param spawn [#call] process creator accepting an argv array and options
      # @param platform [String, nil] discovery override; nil uses the current OS
      # @param browser_path [String, nil] explicit browser, bypassing the native host;
      #   when absent a non-empty LICH_WEBUI_BROWSER takes its place
      # @param chrome_path [String, nil] legacy alias for browser_path
      # @param environment [#[]] environment source for LICH_WEBUI_BROWSER
      # @param geometry [Hash, nil] initial outer dimensions and desktop position
      # @param on_exit [#call, nil] callback after the owned process exits
      # @param on_start [#call, nil] callback receiving the spawned PID
      # @param on_failure [#call, nil] receives a safe, actionable message when the
      #   host could not start; on_exit instead reports a host that started and ended
      # @param waitpid [#call] blocking process-exit observer
      # @param thread_factory [#call] factory for the host-owned monitor thread
      # @return [Boolean] whether spawn and monitor setup succeeded
      def open(url, spawn: Process.method(:spawn), platform: nil,
               browser_path: nil, chrome_path: nil, environment: ENV, geometry: nil, on_exit: nil,
               on_start: nil, on_failure: nil, waitpid: Process.method(:waitpid),
               thread_factory: HostThread.method(:start))
        chosen, origin = browser_override(browser_path || chrome_path, environment)
        verify_browser_path(chosen, origin: origin)
        native = native_host(platform, chosen)
        profile_dir = Dir.mktmpdir('lich-webui-browser-')
        target = launch_file(url, profile_dir, native: native)
        command = command_for(
          target, platform: platform, browser_path: chosen, environment: environment,
          geometry: geometry, profile_dir: native ? nil : profile_dir
        )
        pid = spawn.call(*command, out: File::NULL, err: File::NULL)
        on_start&.call(pid)
        monitor_process(pid, profile_dir, waitpid: waitpid, thread_factory: thread_factory, on_exit: on_exit)
        true
      rescue StandardError => error
        remove_profile(profile_dir)
        message = failure_message(error)
        Lich.log("warning: #{message}") if Lich.respond_to?(:log)
        begin
          on_failure&.call(message)
        rescue StandardError
          nil # A failing observer cannot turn a reported launch failure into a raise.
        end
        false
      end

      # Describes a launch failure without echoing arbitrary exception text,
      # which could include the launch URL or other credential-bearing data.
      # WebUI errors carry authored requirement text (for example a missing
      # browser or helper) and are reported as written.
      # @param error [StandardError] launch failure
      # @return [String] safe diagnostic naming the requirement or failure class
      def failure_message(error)
        detail = error.is_a?(Error) ? error.message : "the window host could not be started (#{error.class})"
        "unable to open WebUI window: #{detail}"
      end

      # Selects native or browser argv without invoking a shell or starting a process.
      # Failed automatic Linux discovery names any skipped snap browser so the
      # recovery message can direct the user to a non-snap installation.
      # @param url [String] private launch-file path (native) or file URL (browser)
      # @param platform [String, nil] discovery override; nil uses the current OS
      # @param browser_path [String, nil] explicit browser, bypassing native selection
      # @param chrome_path [String, nil] legacy alias for browser_path
      # @param environment [#[]] environment source for browser overrides and discovery
      # @param geometry [Hash, nil] initial outer dimensions and desktop position
      # @param profile_dir [String, nil] isolated browser profile directory
      # @return [Array<String>] executable followed by its arguments
      # @raise [Error] if the required native helper or browser is unavailable
      def command_for(url, platform: nil, browser_path: nil, chrome_path: nil, environment: ENV,
                      geometry: nil, profile_dir: nil)
        override, = browser_override(browser_path || chrome_path, environment)
        return NativeHost.command_for(url, geometry: geometry) if native_host(platform, override)

        platform ||= OS.host_os
        executable = override || app_browser_path(platform: platform, environment: environment)
        unless executable
          if platform.match?(/linux/i)
            candidates = chrome_candidates(platform: platform, environment: environment) +
                         chromium_candidates(platform: platform, environment: environment)
            snap = candidates.find { |path| executable_file?(path) && snap_browser?(path) }
            if snap
              shown = snap.gsub(/[[:cntrl:]]/, '?')
              raise Error, "the discovered browser '#{shown}' is unusable: " \
                           'snap-packaged Chromium cannot open the WebUI launch files; ' \
                           "#{ROUTES_HINT} to a non-snap Chrome or Chromium"
            end
          end
          requirement = if windows?(platform)
                          'Google Chrome or Microsoft Edge'
                        elsif platform.match?(/darwin/i)
                          'Google Chrome'
                        else
                          'Google Chrome or Chromium'
                        end
          raise Error, "#{requirement} is required to open the WebUI launcher window; install it, " \
                       "or #{ROUTES_HINT} to another browser"
        end

        profile_arguments = if profile_dir
                              ["--user-data-dir=#{profile_dir}", '--no-first-run', '--no-default-browser-check']
                            else
                              []
                            end
        [executable, '--new-window', *profile_arguments, *geometry_arguments(geometry), "--app=#{url}"]
      end

      # Picks the explicit browser: the argument, else a non-empty LICH_WEBUI_BROWSER.
      # @param argument [String, nil] explicit browser path (setting or caller)
      # @param environment [#[]] environment source
      # @return [Array(String, Symbol), Array(nil, nil)] path and :argument or
      #   :environment; both nil means automatic discovery
      def browser_override(argument, environment)
        return [argument, :argument] unless argument.nil?

        value = environment[ENVIRONMENT_VARIABLE].to_s.strip
        value.empty? ? [nil, nil] : [value, :environment]
      end

      # Refuses an explicit browser that is not an executable file, so a stale or
      # mistyped setting or variable fails with a message naming it instead of a
      # generic launch error. File tests only: Windows decides executability by extension.
      # @param path [String, nil] explicit browser path; nil means automatic discovery
      # @param origin [Symbol, nil] :argument (setting) or :environment (LICH_WEBUI_BROWSER)
      # @return [void]
      # @raise [Error] if the path does not exist, is not an executable file, or
      #   is snap-packaged Chromium
      def verify_browser_path(path, origin: :argument)
        return if path.nil?

        shown = path.to_s.gsub(/[[:cntrl:]]/, '?')
        snap = 'snap-packaged Chromium cannot open the WebUI launch files'
        if origin == :environment
          fix = "fix or unset #{ENVIRONMENT_VARIABLE}"
          raise Error, "#{ENVIRONMENT_VARIABLE} names '#{shown}', which does not exist; #{fix}" unless File.exist?(path)
          raise Error, "#{ENVIRONMENT_VARIABLE} names '#{shown}', which is not an executable file; #{fix}" unless executable_file?(path)
          return unless snap_browser?(path)

          raise Error, "#{ENVIRONMENT_VARIABLE} names '#{shown}', but #{snap}; " \
                       "point #{ENVIRONMENT_VARIABLE} at a non-snap Chrome or Chromium"
        end

        raise Error, "the configured browser '#{shown}' does not exist; #{SETTING_HINT} or clear it" unless File.exist?(path)
        raise Error, "the configured browser '#{shown}' is not an executable file; #{SETTING_HINT} or clear it" unless executable_file?(path)
        return unless snap_browser?(path)

        raise Error, "the configured browser '#{shown}' is unusable: #{snap}; #{SETTING_HINT} to a non-snap " \
                     "Chrome or Chromium, or clear it and point #{ENVIRONMENT_VARIABLE} at one"
      end

      # Admits only an executable regular file; File.executable? alone is true
      # for a searchable directory.
      # @param path [String] candidate browser path
      # @return [Boolean]
      def executable_file?(path)
        File.file?(path) && File.executable?(path)
      end

      # Recognizes snap-packaged Chromium: a path under /snap/, one resolving
      # there or to the snap launcher, or a small script (such as Ubuntu's
      # /usr/bin/chromium-browser) that execs a /snap/ path. Snap confinement
      # gives the browser a private /tmp, so it cannot read the launch file.
      # @param path [String] candidate browser path
      # @param realpath [#call] resolves symbolic links; raises SystemCallError if absent
      # @param read_wrapper [#call] returns a small regular file's bytes, or nil
      # @return [Boolean]
      def snap_browser?(path, realpath: File.method(:realpath), read_wrapper: method(:wrapper_text))
        return true if path.to_s.start_with?(SNAP_ROOT)

        resolved = begin
          realpath.call(path)
        rescue SystemCallError
          nil
        end
        return true if resolved && (resolved.start_with?(SNAP_ROOT) || resolved == SNAP_LAUNCHER)

        text = read_wrapper.call(path)
        !text.nil? && text.start_with?('#!') && text.include?(SNAP_ROOT)
      rescue SystemCallError
        false
      end

      # Reads a regular file smaller than SNAP_WRAPPER_LIMIT, the size of a
      # launcher script; a browser binary is never read.
      # @param path [String] candidate browser path
      # @return [String, nil] file bytes, or nil for anything else
      def wrapper_text(path)
        return nil unless File.file?(path) && File.size(path) < SNAP_WRAPPER_LIMIT

        File.binread(path)
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

      # Removes private launch data after exit or failed startup. A failure is
      # logged with the error class and the directory to remove by hand, never
      # the launch file contents; it is not raised into launch or exit handling.
      # @param profile_dir [String, nil] private directory, absent before allocation
      # @return [void]
      def remove_profile(profile_dir)
        FileUtils.remove_entry_secure(profile_dir) if profile_dir && File.directory?(profile_dir)
      rescue StandardError => error
        begin
          if Lich.respond_to?(:log)
            Lich.log("warning: WebUI launch profile cleanup failed (#{error.class}); " \
                     "remove #{profile_dir} manually")
          end
        rescue StandardError
          nil # A failing diagnostic sink must not turn cleanup into a raise.
        end
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

      # Selects the first executable Chrome candidate, then Edge on Windows or
      # distro Chromium on Linux, skipping snap-packaged Chromium. Injected
      # platform/environment/probes allow discovery tests without launching a browser.
      # @param platform [String] Ruby platform string selecting the candidate lists
      # @param executable [#call] admits a candidate; defaults to an executable regular file
      # @param environment [#[]] environment source for install roots and PATH
      # @param snap [#call] flags a snap-packaged candidate to skip
      # @return [String, nil] executable path
      def app_browser_path(platform: RUBY_PLATFORM, executable: method(:executable_file?), environment: ENV,
                           snap: method(:snap_browser?))
        candidates = chrome_candidates(platform: platform, environment: environment)
        candidates += edge_candidates(environment: environment) if windows?(platform)
        candidates += chromium_candidates(platform: platform, environment: environment)
        candidates.find { |path| executable.call(path) && !snap.call(path) }
      end

      # Finds Chrome specifically for callers that require that browser.
      # @return [String, nil] executable path
      def google_chrome_path(platform: RUBY_PLATFORM, executable: method(:executable_file?))
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

      # Lists Linux distro Chromium paths, then absolute PATH entries; none on
      # macOS or Windows. Relative PATH entries are skipped so the working
      # directory can never supply the browser.
      # @param platform [String] Ruby platform string; only Linux yields candidates
      # @param environment [#[]] environment source for PATH
      # @return [Array<String>] ordered discovery candidates
      def chromium_candidates(platform: RUBY_PLATFORM, environment: ENV)
        return [] if platform.match?(/darwin/i) || windows?(platform)

        directories = environment['PATH'].to_s.split(File::PATH_SEPARATOR).select do |directory|
          directory.start_with?('/')
        end
        LINUX_CHROMIUM_PATHS + directories.product(LINUX_CHROMIUM_NAMES).map { |pair| File.join(*pair) }
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
