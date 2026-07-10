# lib/gemcheck.rb
require 'bundler'
require_relative 'dependency_recovery'

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

    # Records why a recovery did not run without treating that decision as a
    # manifest or Bundler failure.
    class ConsentError < StandardError; end

    module_function

    # Verifies every gem required by the requested Bundler groups is installed,
    # alerting the user (native OS dialog, with a log-file fallback) and exiting
    # when any remain missing after one manifest-backed recovery attempt. This
    # remains a presence check only: it does not call Bundler.setup or lock the
    # load path, leaving scripts free to require gems they install at runtime.
    # @param groups [Array<Symbol>] Bundler groups to verify
    # @return [void]
    def verify!(*groups)
      groups = [:default] if groups.empty?
      configure_gemfile!

      missing = missing_gems(groups)
      return if missing.empty?

      unless self_healing_supported?
        alert(missing: missing, groups: groups)
        exit 1
      end

      result = recover_with_consent!(missing, groups: groups)
      exit 1 unless result

      if result.success?
        missing = missing_gems(groups)
        return if missing.empty?

        alert(missing: missing, groups: groups)
      else
        alert(missing: missing, groups: groups,
              error: DependencyRecovery::Error.new(result.error))
      end
      exit 1
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

    # Ruby4Lich5 currently publishes and validates recovery artifacts only for
    # the Windows runtime. Other platforms retain the ordinary missing-gem
    # warning and never fetch the recovery manifest.
    # @return [Boolean]
    def self_healing_supported?
      Gem.win_platform?
    end

    # Fetches and validates the manifest, requests consent for each affected
    # recovery unit, then performs the download and installation only after all
    # units were approved. Returns nil when consent was declined or unavailable;
    # that case is already logged and presented to the user.
    #
    # @param gem_names [Array<String>] names to recover
    # @param force [Boolean] reinstall an already registered manifest package
    # @param groups [Array<Symbol>] dependency groups being recovered
    # @return [DependencyRecovery::Result, nil]
    def recover_with_consent!(gem_names, force: false, groups: [:default])
      recovery = DependencyRecovery.new
      plan = recovery.recovery_plan(gem_names)
      return DependencyRecovery::Result.new(installed_gems: [], error: plan.error) unless plan.success?
      return nil unless recovery_units_approved?(plan.units, groups)

      recovery.recover(gem_names, force: force, plan: plan)
    end

    # Requests consent for every affected unit before any artifact download or
    # installation begins. This prevents a later declined bundle from leaving
    # earlier approved units partially installed.
    #
    # @param units [Array<Hash>] validated manifest units
    # @param groups [Array<Symbol>] dependency groups being recovered
    # @return [Boolean]
    def recovery_units_approved?(units, groups)
      units.each do |unit|
        decision = confirm_recovery_unit(unit)
        next if decision == :approved

        reason = decision == :unavailable ? 'user consent not available' : 'user declined installation'
        report_consent_failure(unit, groups, reason)
        return false
      end
      true
    end

    # @param unit [Hash] validated manifest recovery unit
    # @return [Symbol] :approved, :declined, or :unavailable
    def confirm_recovery_unit(unit)
      body = build_recovery_prompt(unit)
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then confirm_windows(body)
      when /darwin/             then confirm_macos(body)
      else                           confirm_linux(body)
      end
    rescue StandardError
      :unavailable
    end

    # @param unit [Hash] validated manifest recovery unit
    # @return [String]
    def build_recovery_prompt(unit)
      label = recovery_unit_label(unit)
      members = Array(unit['members'])
      details = members.length > 1 ? "\n\nThis bundle contains: #{members.join(', ')}." : ''
      "Required #{label} is not installed.\n\n" \
        "Lich can download and install the approved, hash-verified package now.#{details}\n\n" \
        'Install now?'
    end

    # @param unit [Hash] validated manifest recovery unit
    # @return [String]
    def recovery_unit_label(unit)
      members = Array(unit['members'])
      return "#{members.first} gem" if members.length == 1
      return 'GTK3 runtime bundle' if unit['id'] == 'gtk3-runtime'

      "#{unit.fetch('id').tr('-', ' ')} bundle"
    end

    # @param unit [Hash] recovery unit the user did not approve
    # @param groups [Array<Symbol>] dependency groups being recovered
    # @param reason [String] user-decision or UI-availability reason
    # @return [void]
    def report_consent_failure(unit, groups, reason)
      error = ConsentError.new(reason)
      write_log(missing: Array(unit['members']), groups: groups, error: error)
      show_notice("Required #{recovery_unit_label(unit)} not installed. Exiting.")
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
    # @return [Symbol] :approved or :declined
    def confirm_windows(body)
      require 'win32ole'
      shell = WIN32OLE.new('WScript.Shell')
      # Yes/No buttons + question icon. WScript returns 6 for Yes.
      shell.Popup(body, 0, TITLE, 4 + 32) == 6 ? :approved : :declined
    end

    # @param body [String]
    # @return [Symbol] :approved or :declined
    def confirm_macos(body)
      script = %(display dialog #{body.inspect} with title #{TITLE.inspect} ) +
               %(buttons {"Install", "Cancel"} default button "Install" with icon caution)
      output = IO.popen(['osascript', '-'], 'r+') do |io|
        io.write(script)
        io.close_write
        io.read
      end
      output.include?('button returned:Install') ? :approved : :declined
    end

    # @param body [String]
    # @return [Symbol] :approved, :declined, or :unavailable
    def confirm_linux(body)
      if cmd_available?('zenity')
        system('zenity', '--question', '--title', TITLE, '--text', body) ? :approved : :declined
      elsif cmd_available?('kdialog')
        system('kdialog', '--title', TITLE, '--yesno', body) ? :approved : :declined
      elsif cmd_available?('xmessage')
        system('xmessage', '-center', '-buttons', 'Install:0,Cancel:1', body) ? :approved : :declined
      else
        :unavailable
      end
    end

    # Shows an error without the normal missing-gem alert's release-page link.
    # @param body [String]
    # @return [void]
    def show_notice(body)
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then notice_windows(body)
      when /darwin/             then notice_macos(body)
      else                           alert_linux(body)
      end
    rescue StandardError
      warn "!!ALERT!! #{body}"
    end

    # @param body [String]
    # @return [void]
    def notice_windows(body)
      require 'win32ole'
      WIN32OLE.new('WScript.Shell').Popup(body, 0, TITLE, 64) # OK + information icon
    end

    # @param body [String]
    # @return [void]
    def notice_macos(body)
      script = %(display dialog #{body.inspect} with title #{TITLE.inspect} ) +
               %(buttons {"OK"} default button "OK" with icon caution)
      IO.popen(['osascript', '-'], 'r+') do |io|
        io.write(script)
        io.close_write
        io.read
      end
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
