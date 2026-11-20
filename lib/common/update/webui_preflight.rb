# frozen_string_literal: true

=begin
  Checks, before a beta is installed, that this computer can open the beta's
  windows.

  The beta draws its launcher and its script windows through the WebUI, in a
  native helper or a Chromium-based browser. Without one it cannot open a
  window, and on macOS it does not start at all. The check applies the beta's
  startup rules to the running system, so a user who cannot run the beta is
  told before the install instead of after it. It only reads: nothing is
  built, launched or written.

  The rules, in the order the beta applies them:

    - A session started with --no-gui (or --no-gtk) opens no windows and
      needs nothing.
    - LICH_WEBUI_BROWSER, when set, is the browser. It must name an
      executable file that is not snap-packaged Chromium; on macOS it may
      name an application bundle (.app) instead.
    - macOS builds its window helper the first time the beta starts, which
      needs the Swift compiler. When that fails it uses Google Chrome or
      Chromium.
    - Windows uses Google Chrome or Microsoft Edge. Linux uses Google Chrome
      or Chromium that is not a snap package. On both, a browser saved in
      the launcher's settings also opens the launcher.

  Lich::WebUI::BrowserLauncher, which this Lich already ships, does the
  discovery and words most refusals. It is loaded on first use, so a session
  that never asks for a beta does not load WebUI code.

  Three of the beta's rules are not in this Lich's BrowserLauncher and are
  written out here: an application bundle as LICH_WEBUI_BROWSER
  (.resolve_bundle), Chromium on macOS (MACOS_CHROMIUM_PATHS), and building
  the macOS helper at startup (.swift_toolchain?). Remove them, and call
  BrowserLauncher for all of it, once lib/webui/browser_launcher.rb on the
  stable branch defines resolve_browser_path, which is when stable starts the
  WebUI the way the beta does.
=end

require 'open3'
require 'os'
require 'rexml/document'

module Lich
  module Util
    module Update
      module WebUIPreflight
        # Environment variable naming the browser for every WebUI window.
        # The same name as Lich::WebUI::BrowserLauncher::ENVIRONMENT_VARIABLE,
        # repeated so messages can name it without loading WebUI code.
        BROWSER_VARIABLE = 'LICH_WEBUI_BROWSER'

        # Launch option that turns window presentation off; the beta's
        # startup reads the same two spellings.
        NO_GUI_OPTION = /\A--no-(?:gui|gtk)\z/i

        # Where the beta looks for Chromium on macOS, after Google Chrome.
        MACOS_CHROMIUM_PATHS = [
          '/Applications/Chromium.app/Contents/MacOS/Chromium',
          File.join(Dir.home, 'Applications/Chromium.app/Contents/MacOS/Chromium')
        ].freeze

        # The Swift compiler, relative to the active developer directory:
        # first as the Command Line Tools lay it out, then as Xcode does.
        SWIFTC_PATHS = ['usr/bin/swiftc', 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'].freeze

        # lich_settings row holding the browser chosen in the launcher's
        # settings; the launcher itself reads and writes it under this name.
        SAVED_BROWSER_SETTING = 'webui_launcher_browser_path'

        module_function

        # Says why the beta could not open a window on this computer.
        #
        # @param platform [String, nil] host OS string to check as; nil uses
        #   the running one
        # @param environment [#[]] environment holding LICH_WEBUI_BROWSER and
        #   the directories browsers are looked for in
        # @param argv [Array<String>] the options Lich was started with
        # @return [String, nil] the reason, a clause without a final period;
        #   nil when the beta can open a window, or needs none
        def refusal(platform: nil, environment: ENV, argv: ARGV)
          return nil if argv.any? { |argument| argument.to_s.match?(NO_GUI_OPTION) }

          platform ||= OS.host_os
          macos = platform.match?(/darwin/i)
          explicit, origin = launcher.browser_override(nil, environment)
          if explicit
            launcher.verify_browser_path(macos ? resolve_bundle(explicit) : explicit, origin: origin)
            return nil
          end
          return macos_refusal(environment) if macos
          return nil if usable_browser?(saved_browser_path)

          launcher.command_for('', platform: platform, environment: environment)
          nil
        rescue Lich::WebUI::Error => error
          error.message
        end

        # Applies the beta's macOS startup rule when no browser is named: the
        # helper can be built, or Google Chrome or Chromium stands in for it.
        # A helper built for the running Lich does not count, because an
        # update replaces lib/, where it lives.
        #
        # @param environment [#[]] environment source for browser discovery
        # @return [String, nil] the reason no window can open, or nil
        # @api private
        def macos_refusal(environment)
          return nil if swift_toolchain?
          return nil if launcher.app_browser_path(platform: 'darwin', environment: environment)
          return nil if MACOS_CHROMIUM_PATHS.any? { |path| usable_browser?(path) }

          'the beta builds its macOS window helper when it first starts, which needs the Swift compiler ' \
            '(install the Xcode Command Line Tools: xcode-select --install), and otherwise uses Google Chrome ' \
            'or Chromium; neither the compiler nor one of those browsers was found'
        end

        # Whether the Swift compiler the helper build runs is installed.
        # Asks xcode-select for the active developer directory, which only
        # prints it; running the compiler stub itself on a Mac without
        # developer tools would bring up Apple's install prompt.
        #
        # @return [Boolean]
        # @api private
        def swift_toolchain?
          output, status = Open3.capture2e('/usr/bin/xcode-select', '-p')
          return false unless status.success?

          directory = output.strip
          SWIFTC_PATHS.any? { |path| launcher.executable_file?(File.join(directory, path)) }
        rescue SystemCallError
          false
        end

        # Turns a macOS application bundle named by LICH_WEBUI_BROWSER into
        # the executable inside it, as the beta does. Any other path is
        # returned as it is.
        #
        # @param path [String] the value of LICH_WEBUI_BROWSER
        # @return [String] executable path, or +path+ when it is not a bundle
        # @raise [Lich::WebUI::Error] if the bundle names no executable file
        # @api private
        def resolve_bundle(path)
          bundle = path.sub(%r{/+\z}, '')
          return path unless File.extname(bundle).casecmp?('.app')

          name = bundle_executable(bundle)
          if name && !name.empty? && File.basename(name) == name && !%w[. ..].include?(name)
            executable = File.join(bundle, 'Contents', 'MacOS', name)
            return executable if launcher.executable_file?(executable)
          end

          shown = path.gsub(/[[:cntrl:]]/, '?')
          raise Lich::WebUI::Error, "#{BROWSER_VARIABLE} names '#{shown}', which has no executable; fix or unset #{BROWSER_VARIABLE}"
        end

        # Reads an application's executable name from its Info.plist, which
        # is XML or, in most installed applications, a binary property list
        # that plutil prints from without changing the file.
        #
        # @param bundle [String] macOS application bundle path
        # @return [String, nil] CFBundleExecutable, or nil for an invalid bundle
        # @api private
        def bundle_executable(bundle)
          plist = File.join(bundle, 'Contents', 'Info.plist')
          document = REXML::Document.new(File.read(plist))
          key = document.elements.to_a('plist/dict/key').find { |element| element.text == 'CFBundleExecutable' }
          value = key&.next_element
          value.text if value&.name == 'string'
        rescue REXML::ParseException
          begin
            output, _error, status = Open3.capture3('/usr/bin/plutil', '-extract', 'CFBundleExecutable', 'raw', '--', plist)
            status.success? ? output.strip : nil
          rescue SystemCallError
            nil
          end
        rescue SystemCallError
          nil
        end

        # @param path [String, nil] a browser path
        # @return [Boolean] whether it is an executable file the beta would
        #   use: not missing, not a directory, not snap-packaged Chromium
        # @api private
        def usable_browser?(path)
          !path.nil? && launcher.executable_file?(path) && !launcher.snap_browser?(path)
        end

        # @return [String, nil] the browser saved in the launcher's settings,
        #   or nil when none is saved or the settings cannot be read
        # @api private
        def saved_browser_path
          value = Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='#{SAVED_BROWSER_SETTING}';").to_s.strip
          value.empty? ? nil : value
        rescue StandardError
          nil
        end

        # @return [Module] Lich::WebUI::BrowserLauncher, loaded on first use
        # @api private
        def launcher
          require_relative '../../webui/browser_launcher'
          Lich::WebUI::BrowserLauncher
        end
      end
    end
  end
end
