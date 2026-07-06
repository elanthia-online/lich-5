# lib/gemcheck.rb
require 'bundler'

module Lich
  # Verifies bundled gems are installed at Lich startup and alerts the
  # user via a native OS dialog (with a log-file fallback) when any
  # are missing. Runs once during boot, before scripts load.
  module GemCheck
    WINDOWS_MESSAGE = "You're missing required Ruby gems!\n\n" \
                      "Please update to the latest Ruby version using the\n" \
                      "Ruby4Lich5 installer."
    UNIX_MESSAGE    = "You're missing required Ruby gems!\n\n" \
                      "Please run 'bundle install' from your Lich5 folder."
    TITLE           = 'Lich5: Missing Ruby Gems'
    RELEASE_URL     = 'https://github.com/elanthia-online/lich-5/releases/latest'
    LOG_FILENAME    = 'lich5-missing-gems.log'
    STALE_LOCK_MESSAGE = 'Lich: Gemfile.lock could not be resolved, but every required gem ' \
                         'is installed; continuing boot. Run \'bundle install\' from your ' \
                         'Lich5 folder to refresh the lockfile.'

    module_function

    # Runs Bundler.setup for the given groups; on failure, alerts the
    # user and exits. Two classes of Bundler failure are tolerated instead of
    # being fatal, because in both the gems Lich actually needs are present:
    #
    # 1. Bundler complains about a gem outside the requested groups (which some
    #    Bundler versions do despite `without` settings).
    # 2. Bundler cannot resolve the lockfile, yet our platform-aware detector
    #    confirms every required gem is installed -- typically a stale,
    #    multi-platform Gemfile.lock re-resolved offline after a self-update
    #    replaced Gemfile but not Gemfile.lock. Boot proceeds on plain RubyGems
    #    activation (how Lich loaded before GemCheck adopted Bundler.setup),
    #    with a non-fatal notice pointing at `bundle install`.
    #
    # @param groups [Array<Symbol>] Bundler groups to verify
    # @return [void]
    def verify!(*groups)
      groups = [:default] if groups.empty?
      configure_gemfile!

      missing = missing_gems(groups)
      unless missing.empty?
        alert(missing: missing, groups: groups)
        exit 1
      end

      excluded = (all_groups - groups).map(&:to_s)
      begin
        Bundler.settings.temporary(without: excluded) do
          Bundler.definition(true)
          Bundler.setup(*groups)
        end
      rescue Bundler::BundlerError => e
        if bundler_error_out_of_scope?(e, groups)
          # Bundler is complaining about a gem outside the requested groups.
          # Our detector already confirmed the requested groups are satisfied,
          # so this is a scope-semantics disagreement, not a real failure.
          # Continue boot silently.
        elsif (still_missing = missing_gems(groups)).empty?
          # Every required gem is installed, so the resolution failure is a
          # lockfile artifact rather than a genuinely missing dependency.
          # Warn and continue instead of blocking the user from logging in.
          warn_stale_lock(e, groups)
        else
          alert(missing: still_missing, groups: groups, error: e)
          exit 1
        end
      end
    end

    # Records a tolerated lockfile-resolution failure and surfaces a non-fatal
    # notice. The failure is logged for later inspection and echoed to stderr so
    # it is visible in a terminal launch; boot is not interrupted.
    #
    # @param error [Bundler::BundlerError] the resolution failure being tolerated
    # @param groups [Array<Symbol>] groups being verified, forwarded to the log
    #   so its "Groups checked" diagnostic reflects the actual verify! call
    # @return [void]
    def warn_stale_lock(error, groups = [:default])
      write_log(missing: [], groups: groups, error: error)
      warn STALE_LOCK_MESSAGE
    end

    # Ensures Bundler resolves Lich's Gemfile even when the app is launched
    # from another working directory, such as macOS app launch from /.
    # @return [void]
    def configure_gemfile!
      return if ENV['BUNDLE_GEMFILE'] && !ENV['BUNDLE_GEMFILE'].empty?
      return unless defined?(LICH_DIR)

      gemfile = File.join(LICH_DIR, 'Gemfile')
      ENV['BUNDLE_GEMFILE'] = gemfile if File.file?(gemfile)
    end

    # Names of gems declared in the Gemfile that are not installed at any
    # version satisfying the declared requirement, scoped to the given groups.
    # Relies on installed Gem::Specifications; git/path-sourced gems are not
    # detected here (the current Gemfile has none).
    # @param groups [Array<Symbol>] groups being verified
    # @return [Array<String>] sorted, unique gem names
    def missing_gems(groups = [:default])
      Bundler.definition.current_dependencies.select do |dep|
        (dep.groups & groups).any?
      end.reject do |dep|
        Gem::Specification.find_all_by_name(dep.name, dep.requirement).any?
      end.map(&:name).sort.uniq
    rescue StandardError
      []
    end

    # @return [Array<Symbol>] all groups declared in the Gemfile
    def all_groups
      Bundler.definition.groups
    rescue StandardError
      [:default]
    end

    # @param error [Exception]
    # @param groups [Array<Symbol>]
    # @return [Boolean] true if the error concerns a gem outside the requested groups
    def bundler_error_out_of_scope?(error, groups)
      name = extract_gem_name(error.message)
      return false unless name

      dep = safe_call { Bundler.definition.current_dependencies.find { |d| d.name == name } }
      return false unless dep.respond_to?(:groups)

      (dep.groups & groups).empty?
    end

    # Extracts a gem name from a Bundler error message. Matches:
    #   "Could not find gem 'foo' in ..."
    #   "Could not find 'foo' in ..."
    # @param msg [String]
    # @return [String, nil]
    def extract_gem_name(msg)
      match = msg.match(/Could not find (?:gem )?['"]([^'"]+)['"]/)
      match && match[1]
    end

    # @param missing [Array<String>] gem names identified by our detector
    # @param groups [Array<Symbol>] groups being verified
    # @param error [Exception, nil] the Bundler exception, if any
    # @return [void]
    def alert(missing: [], groups: [:default], error: nil)
      write_log(missing: missing, groups: groups, error: error)
      body = build_alert_body(missing, error)
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then alert_windows(body)
      when /darwin/             then alert_macos(body)
      else                           alert_linux(body)
      end
    end

    # @return [String] the message appropriate for the current platform
    def message
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then WINDOWS_MESSAGE
      else                           UNIX_MESSAGE
      end
    end

    # Composes the alert dialog body: platform message + either a bulleted
    # list of detected missing gems, or the raw Bundler error if our
    # detector came up empty.
    # @param missing [Array<String>]
    # @param error [Exception, nil]
    # @return [String]
    def build_alert_body(missing, error)
      parts = [message]
      if missing.any?
        parts << "Missing gems:\n  - #{missing.join("\n  - ")}"
      elsif error
        parts << "Bundler reported:\n  #{error.message.lines.first.to_s.strip}"
      end
      parts << "See #{File.join(TEMP_DIR, LOG_FILENAME)} for details." if defined?(TEMP_DIR)
      parts.join("\n\n")
    end

    # @param missing [Array<String>]
    # @param groups [Array<Symbol>]
    # @param error [Exception, nil]
    # @return [void]
    def write_log(missing: [], groups: [:default], error: nil)
      log_path = File.join(TEMP_DIR, LOG_FILENAME)
      # verify! can run before init.rb creates TEMP_DIR (fresh install), so
      # ensure the directory exists or the alert would cite a log we never wrote.
      Dir.mkdir(TEMP_DIR) unless File.exist?(TEMP_DIR)
      File.open(log_path, 'a') do |f|
        f.puts "[#{Time.now}] Lich5 GemCheck failure"
        f.puts message.gsub(/^/, '  ')
        f.puts

        f.puts '  Diagnostics:'
        f.puts "    Ruby:            #{RUBY_DESCRIPTION}"
        f.puts "    Bundler:         #{safe_call { Bundler::VERSION }}"
        f.puts "    Gemfile:         #{safe_call { Bundler.default_gemfile }}"
        f.puts "    Lockfile:        #{safe_call { Bundler.default_lockfile }}"
        f.puts "    Working dir:     #{Dir.pwd}"
        f.puts "    Groups checked:  #{groups.inspect}"
        f.puts "    All groups:      #{all_groups.inspect}"
        f.puts

        if missing.any?
          f.puts '  Missing gems (detected):'
          missing.each { |name| f.puts "    - #{name}" }
        else
          f.puts '  Missing gems (detected): none identified by GemCheck'
        end
        f.puts

        if error
          f.puts '  Bundler error:'
          f.puts "    Class:   #{error.class}"
          error.message.each_line { |line| f.puts "    #{line.chomp}" }
          f.puts
        end

        f.puts '  Declared dependencies in requested groups:'
        safe_call { dependency_report(groups) }.to_s.each_line do |line|
          f.puts "    #{line.chomp}"
        end
        f.puts

        f.puts "  Download: #{RELEASE_URL}" if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
        f.puts
      end
    rescue StandardError
      # Filesystem write failed; continue to GUI attempt.
    end

    # Builds a per-dependency status line for every gem in the requested
    # groups: name, requirement, and whether it's installed. This is the
    # single most useful piece of debug output when the detector disagrees
    # with Bundler.
    # @param groups [Array<Symbol>]
    # @return [String]
    def dependency_report(groups)
      deps = Bundler.definition.current_dependencies.select do |dep|
        (dep.groups & groups).any?
      end
      return '(none)' if deps.empty?

      deps.sort_by(&:name).map do |dep|
        installed = Gem::Specification.find_all_by_name(dep.name, dep.requirement)
        status = installed.any? ? "OK (#{installed.map(&:version).join(', ')})" : 'MISSING'
        "#{dep.name.ljust(24)} #{dep.requirement.to_s.ljust(20)} #{status}"
      end.join("\n")
    end

    # Wraps a block, returning its result or a placeholder string on error.
    # @yield the value to compute
    # @return [Object, String]
    def safe_call
      yield
    rescue StandardError => e
      "(unavailable: #{e.class}: #{e.message})"
    end

    # @param body [String]
    # @return [void]
    def alert_windows(body)
      require 'win32ole'
      shell = WIN32OLE.new('WScript.Shell')
      result = shell.Popup("#{body}\n\nClick OK to open the download page.",
                           0, TITLE, 1 + 64) # OK/Cancel + Information icon
      shell.Run(RELEASE_URL) if result == 1
    end

    # @param body [String]
    # @return [void]
    def alert_macos(body)
      as_body = body.split("\n").map(&:inspect).join(' & return & ')
      script = %(display dialog #{as_body} ) +
               %(with title #{TITLE.inspect} ) +
               %(buttons {"OK"} default button "OK" with icon caution)
      IO.popen(['osascript', '-'], 'r+') do |io|
        io.write(script)
        io.close_write
        io.read
      end
    end

    # @param body [String]
    # @return [void]
    def alert_linux(body)
      if cmd_available?('zenity')
        system('zenity', '--info', '--title', TITLE, '--text', body)
      elsif cmd_available?('kdialog')
        system('kdialog', '--title', TITLE, '--msgbox', body)
      elsif cmd_available?('xmessage')
        system('xmessage', '-center', body)
      else
        warn "!!ALERT!! #{body}"
      end
    end

    # @param cmd [String] executable name to probe
    # @return [Boolean]
    def cmd_available?(cmd)
      system('which', cmd, out: File::NULL, err: File::NULL)
    end
  end
end
