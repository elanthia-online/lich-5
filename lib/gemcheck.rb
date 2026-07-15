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
    CONSENT_TIMEOUT_SECONDS = 120

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
      exit 0 if result.restart_required

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

    # Chooses the dependency groups that must be present before normal startup.
    # Only Windows verifies GTK here, because Ruby4Lich5 publishes a Windows
    # recovery unit for it. Non-Windows GTK startup remains governed by
    # init.rb's existing DISPLAY and terminal behavior.
    #
    # @param argv [Array<String>] command-line arguments
    # @return [Array<Symbol>]
    def startup_groups(argv = ARGV)
      groups = [:default]
      groups << :gtk if self_healing_supported? && !Array(argv).grep(/^--no-(?:gtk|gui)$/i).any?
      groups
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

      write_recovery_log(missing: gem_names, groups: groups, units: plan.units)
      recovery.recover(gem_names, force: force, plan: plan)
    end

    # Requests one consent decision for every affected unit before any artifact
    # download or installation begins. This prevents a declined bundle from
    # leaving an earlier approved unit partially installed.
    #
    # @param units [Array<Hash>] validated manifest units
    # @param groups [Array<Symbol>] dependency groups being recovered
    # @return [Boolean]
    def recovery_units_approved?(units, groups)
      decision = confirm_recovery_units(units)
      return true if decision == :approved

      reason = consent_failure_reason(decision)
      report_consent_failure(units, groups, reason)
      false
    end

    # @param decision [Symbol] consent dialog outcome
    # @return [String] loggable reason for not installing
    def consent_failure_reason(decision)
      return 'user consent not available' if decision == :unavailable
      return 'user consent timed out' if decision == :timed_out

      'user declined installation'
    end

    # @param units [Array<Hash>] validated manifest recovery units
    # @return [Symbol] :approved, :declined, or :unavailable
    def confirm_recovery_units(units)
      return :unavailable unless self_healing_supported?

      body = build_recovery_prompt(units)
      confirm_windows(body)
    rescue StandardError
      :unavailable
    end

    # @param units [Array<Hash>] validated manifest recovery units
    # @return [String]
    def build_recovery_prompt(units)
      listed_units = Array(units).map do |unit|
        members = Array(unit['members'])
        details = members.length > 1 ? ": #{members.join(', ')}" : ''
        "  - #{recovery_unit_label(unit)}#{details}"
      end
      "Required Ruby gems are not installed:\n#{listed_units.join("\n")}\n\n" \
        "Lich can download and install the approved, hash-verified packages now.\n\n" \
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

    # @param units [Array<Hash>] recovery units the user did not approve
    # @param groups [Array<Symbol>] dependency groups being recovered
    # @param reason [String] user-decision or UI-availability reason
    # @return [void]
    def report_consent_failure(units, groups, reason)
      error = ConsentError.new(reason)
      missing = units.flat_map { |unit| Array(unit['members']) }.uniq
      write_log(missing: missing, groups: groups, error: error)
      show_notice("Required gem#{'s' if missing.length != 1} #{missing.join(', ')} not installed. Exiting.")
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

    # Records a successful user-approved recovery attempt so self-healing is
    # observable even when Lich subsequently starts without an error dialog.
    # @param missing [Array<String>]
    # @param groups [Array<Symbol>]
    # @param units [Array<Hash>]
    # @return [void]
    def write_recovery_log(missing:, groups:, units:)
      write_log(missing: missing, groups: groups, event: 'recovery', recovery_units: units)
    end

    # @param missing [Array<String>]
    # @param groups [Array<Symbol>]
    # @param error [Exception, nil]
    # @param event [String] log event name
    # @param recovery_units [Array<Hash>, nil] approved manifest units
    # @return [void]
    def write_log(missing: [], groups: [:default], error: nil, event: 'failure', recovery_units: nil)
      log_path = File.join(TEMP_DIR, LOG_FILENAME)
      # verify! can run before init.rb creates TEMP_DIR (fresh install), so
      # ensure the directory exists or the alert would cite a log we never wrote.
      Dir.mkdir(TEMP_DIR) unless File.exist?(TEMP_DIR)
      File.open(log_path, 'a') do |f|
        f.puts "[#{Time.now}] Lich5 GemCheck #{event}"
        f.puts message.gsub(/^/, '  ') if event == 'failure'
        f.puts

        if recovery_units
          f.puts '  Approved manifest recovery units:'
          recovery_units.each do |unit|
            f.puts "    - #{recovery_unit_label(unit)}: #{Array(unit['members']).join(', ')}"
          end
          f.puts
        end

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

        f.puts "  Download: #{RELEASE_URL}" if event == 'failure' && RUBY_PLATFORM =~ /mswin|mingw|cygwin/
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
    # @return [Symbol] :approved, :declined, or :timed_out
    def confirm_windows(body)
      result = windows_popup(body, 4 + 32) # Yes/No buttons + question icon
      return :approved if result == 6 # Yes
      return :timed_out if result == -1 # WScript Popup timeout

      :declined
    end

    # @param body [String]
    # @param flags [Integer] WScript Popup button and icon flags
    # @return [Integer] WScript Popup result code
    def windows_popup(body, flags)
      require 'win32ole'
      shell = WIN32OLE.new('WScript.Shell')
      shell.Popup(body, CONSENT_TIMEOUT_SECONDS, TITLE, flags)
    end

    # Shows an error without the normal missing-gem alert's release-page link.
    # @param body [String]
    # @return [void]
    def show_notice(body)
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then notice_windows(body)
      else                           alert_linux(body)
      end
    rescue StandardError
      warn "!!ALERT!! #{body}"
    end

    # @param body [String]
    # @return [void]
    def notice_windows(body)
      require 'win32ole'
      WIN32OLE.new('WScript.Shell').Popup(body, CONSENT_TIMEOUT_SECONDS, TITLE, 64) # OK + information icon
    end

    # @param body [String]
    # @return [void]
    def alert_windows(body)
      require 'win32ole'
      shell = WIN32OLE.new('WScript.Shell')
      result = shell.Popup("#{body}\nClick OK to open the download page.",
                           0, TITLE, 1 + 64) # OK/Cancel + Information icon
      shell.Run(RELEASE_URL) if result == 1
    end

    # @param body [String]
    # @return [void]
    def alert_macos(body)
      script = %(display dialog #{macos_dialog_body(body)} ) +
               %(with title #{TITLE.inspect} ) +
               %(buttons {"OK"} default button "OK" with icon caution)
      IO.popen(['osascript', '-'], 'r+') do |io|
        io.write(script)
        io.close_write
        io.read
      end
    end

    # @param body [String]
    # @return [String] AppleScript expression retaining each line break
    def macos_dialog_body(body)
      body.split("\n").map(&:inspect).join(' & return & ')
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
