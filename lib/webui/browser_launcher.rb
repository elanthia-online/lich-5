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

      def open(url, spawn: Process.method(:spawn), detach: Process.method(:detach), platform: RUBY_PLATFORM,
               browser_path: nil, chrome_path: nil, geometry: nil, on_exit: nil,
               on_start: nil, waitpid: Process.method(:waitpid),
               thread_factory: ->(&block) { Thread.new(&block) })
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
        [executable, '--new-window', *profile_arguments, *geometry_arguments(geometry), "--app=#{url}"]
      end

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

      def remove_profile(profile_dir)
        FileUtils.remove_entry_secure(profile_dir) if profile_dir && File.directory?(profile_dir)
      rescue StandardError
        nil
      end

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

      def app_browser_path(platform: RUBY_PLATFORM, executable: File.method(:executable?), environment: ENV)
        candidates = chrome_candidates(platform: platform, environment: environment)
        candidates += edge_candidates(environment: environment) if windows?(platform)
        candidates.find { |path| executable.call(path) }
      end

      def google_chrome_path(platform: RUBY_PLATFORM, executable: File.method(:executable?))
        chrome_candidates(platform: platform).find { |path| executable.call(path) }
      end

      def chrome_candidates(platform: RUBY_PLATFORM, environment: ENV)
        return MACOS_PATHS if platform.match?(/darwin/i)
        return LINUX_PATHS unless windows?(platform)

        %w[PROGRAMFILES PROGRAMFILES(X86) LOCALAPPDATA].filter_map do |variable|
          root = environment[variable]
          File.join(root, 'Google', 'Chrome', 'Application', 'chrome.exe') unless root.to_s.empty?
        end
      end

      def edge_candidates(environment: ENV)
        %w[PROGRAMFILES PROGRAMFILES(X86) LOCALAPPDATA].filter_map do |variable|
          root = environment[variable]
          File.join(root, 'Microsoft', 'Edge', 'Application', 'msedge.exe') unless root.to_s.empty?
        end
      end

      def windows?(platform)
        platform.match?(/mingw|mswin|cygwin/i)
      end
    end
  end
end
