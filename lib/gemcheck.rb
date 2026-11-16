# lib/gemcheck.rb
require 'timeout'
require_relative 'bundler_recovery'
require_relative 'common/cli/one_shot_commands'
require_relative 'dependency_recovery'
require_relative 'accepted_gem_policy'
require_relative 'runtime_gem_contract'

module Lich
  # Verifies runtime dependencies at startup, including accepted Windows
  # versions, before application scripts load. Native dialogs have log fallback.
  module GemCheck
    WINDOWS_MESSAGE = "You're missing required Ruby gems!\n\n" \
                      "Please update to the latest Ruby version using the\n" \
                      "Ruby4Lich5 installer."
    UNIX_MESSAGE    = "You're missing required Ruby gems!\n\n" \
                      "Please run 'bundle install' from your Lich5 folder."
    TITLE           = 'Lich5: Ruby Gem Check'
    RELEASE_URL     = 'https://github.com/elanthia-online/lich-5/releases/latest'
    LOG_FILENAME    = 'lich5-missing-gems.log'
    RECOMMENDED_HEADING = 'Lich5 GemCheck recommended update'
    CONSENT_TIMEOUT_SECONDS = 120
    BUNDLER_RECOVERY_TIMEOUT_SECONDS = 120
    ALERT_TIMEOUT_SECONDS = 120

    # Records why a recovery did not run without treating that decision as a
    # manifest or Bundler failure.
    class ConsentError < StandardError; end
    class DeclarationError < DependencyRecovery::Error; end

    module_function

    # Verifies every gem required by the requested Bundler groups is installed,
    # alerting the user (native OS dialog, with a log-file fallback) and exiting
    # when any remain missing after one manifest-backed recovery attempt. This
    # enforces accepted manifest versions on Windows and retains the existing
    # non-Windows recovery boundaries. It does not call Bundler.setup; scripts
    # remain free to require their own additional gems. Unreadable required
    # declarations stop startup on every platform.
    # @param groups [Array<Symbol>] Bundler groups to verify
    # @return [void]
    def verify!(*groups)
      groups = [:default] if groups.empty?
      configure_gemfile!

      return verify_windows!(groups) if self_healing_supported?

      missing = missing_gems(groups)
      return if missing.empty?

      if bundler_recovery_supported?(groups)
        result = recover_with_bundler_consent!(missing, groups: groups)
        exit 1 unless result

        if result.success?
          write_bundler_recovery_log(missing: missing, groups: groups, result: result)
          exit_after_scheduled_repair! if result.restart_required
          exit 1
        end

        alert(missing: missing, groups: groups, error: DependencyRecovery::Error.new(result.error))
        exit 1
      else
        alert(missing: missing, groups: groups)
        exit 1
      end
    rescue StandardError, Gem::LoadError => error
      alert(missing: [], groups: groups, error: error)
      exit 1
    end

    # Accepted manifest versions apply before any application dependency loads.
    # Repair always finishes after this process exits (relaunching a session,
    # not a one-shot command); already-loaded native or pure code cannot be
    # safely replaced by changing the installed-spec registry in this process.
    def verify_windows!(groups)
      recovery = DependencyRecovery.new(relaunch: relaunch_after_repair?)
      policy = AcceptedGemPolicy.new(recovery: recovery)
      begin
        check = policy.check(required_dependencies(groups))
      rescue AcceptedGemPolicy::UnsupportedRuntimeError => e
        return verify_unsupported_windows_runtime!(groups, e)
      end
      if check.needed.empty?
        write_recommended_log(check) unless Array(check.recommended).empty?
        return policy.activate!(check)
      end
      exit 1 unless recovery_units_approved?(check.plan.units, groups)

      write_recovery_log(missing: check.needed, groups: groups, units: check.plan.units)
      result = recovery.recover(check.needed, force: true, plan: check.plan, restart: true, preserve_newer: true)
      raise recovery_error(result) unless result.success?
      raise DependencyRecovery::Error, 'accepted-version repair did not schedule its required restart' unless result.restart_required
      exit_after_scheduled_repair!
    end

    # The one place that decides whether a gem repair that finishes after this
    # process exits relaunches Lich. A session is relaunched with its original
    # arguments. A one-shot command (Lich::Common::CLI::OneShotCommands) is
    # not: the relaunch would discard its output, and its arguments can carry
    # passwords that would otherwise be written into the helper's payload.
    # The recovery objects, the consent prompt and the exit status all follow
    # this answer.
    #
    # @return [Boolean] true when the repair helper should relaunch Lich
    def relaunch_after_repair?
      !Lich::Common::CLI::OneShotCommands.present?(ARGV)
    end

    # Exits once a gem repair has been scheduled to finish after this process
    # is gone. A session exits 0 and is relaunched by the repair helper. A
    # one-shot command is not relaunched, so the user is told to run it again,
    # and the exit status says it did not run.
    #
    # @return [void] never returns
    def exit_after_scheduled_repair!
      return exit(0) if relaunch_after_repair?

      $stdout.puts one_shot_rerun_message
      exit 1
    end

    # Shown when a gem repair finishes after this process exits and the
    # one-shot command that triggered it is not relaunched. Success is silent,
    # so it names the log a failed background repair writes to.
    #
    # @return [String]
    def one_shot_rerun_message
      log_name = BundlerRecovery.supported? ? BundlerRecovery::LOG_FILENAME : LOG_FILENAME
      log_path = defined?(TEMP_DIR) ? File.join(TEMP_DIR, log_name) : log_name
      "Lich is finishing a repair of its Ruby gems in the background.\n" \
        "Your command did not run. Give the repair a minute, then run your command again.\n" \
        "If Lich asks to install the gems again, the background repair failed; see #{log_path}."
    end

    # The accepted manifest publishes no target for this Windows Ruby (for
    # example native ARM64 RubyInstaller, while Ruby4Lich5 ships only x64), so
    # there are no accepted versions to enforce and nothing to repair from.
    # Apply the plain missing-gem check instead of refusing to start; a
    # malformed or unreachable manifest still fails closed in verify_windows!.
    # @param groups [Array<Symbol>]
    # @param error [AcceptedGemPolicy::UnsupportedRuntimeError]
    # @return [void]
    def verify_unsupported_windows_runtime!(groups, error)
      missing = missing_gems(groups)
      return if missing.empty?

      alert(missing: missing, groups: groups, error: error)
      exit 1
    end

    def recovery_error(result)
      type = case result.error_kind
             when :timeout then DependencyRecovery::StagingTimeoutError
             when :gem_home_not_writable then DependencyRecovery::GemHomeNotWritableError
             else DependencyRecovery::Error
             end
      type.new(result.error)
    end

    # Load Bundler only for non-Windows declaration/recovery operations. The
    # Windows policy reader and its diagnostics do not evaluate Gemfile plugins.
    def bundler
      require 'bundler'
      Bundler
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

    # The initial non-Windows recovery is deliberately macOS-only and only
    # covers default runtime gems. GTK remains outside this Bundler path.
    # @param groups [Array<Symbol>]
    # @return [Boolean]
    def bundler_recovery_supported?(groups)
      BundlerRecovery.supported? && Array(groups).map(&:to_sym) == [:default]
    end

    # Chooses the dependency groups that must be present before normal startup.
    # Only Windows verifies GTK here, because Ruby4Lich5 publishes a Windows
    # recovery unit for it. On every platform, init.rb treats GTK as required
    # unless the user explicitly passes --no-gtk or --no-gui.
    #
    # @param argv [Array<String>] command-line arguments
    # @return [Array<Symbol>]
    def startup_groups(argv = ARGV)
      groups = [:default]
      groups << :gtk if self_healing_supported? && !Array(argv).any? { |arg| arg.match?(/^--no-(?:gtk|gui)$/i) }
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
      recovery = DependencyRecovery.new(relaunch: relaunch_after_repair?)
      plan = recovery.recovery_plan(gem_names)
      return DependencyRecovery::Result.new(installed_gems: [], error: plan.error) unless plan.success?
      return nil unless recovery_units_approved?(plan.units, groups)

      write_recovery_log(missing: gem_names, groups: groups, units: plan.units)
      recovery.recover(gem_names, force: force, plan: plan)
    end

    # Runs a consented Bundler repair for the default non-GTK runtime gems on
    # macOS. The recovery object uses a shipped lockfile when present, or
    # resolves only within staging before making the private RubyGems home
    # active.
    # @param gem_names [Array<String>]
    # @param groups [Array<Symbol>]
    # @return [BundlerRecovery::Result, nil]
    def recover_with_bundler_consent!(gem_names, groups: [:default])
      recovery = BundlerRecovery.new(lich_dir: LICH_DIR, relaunch: relaunch_after_repair?)
      if (reason = recovery.preflight(gem_names))
        return BundlerRecovery::Result.new(error: reason)
      end

      decision = confirm_bundler_recovery(gem_names)
      unless decision == :approved
        report_bundler_consent_failure(gem_names, groups, consent_failure_reason(decision))
        return nil
      end

      recovery.recover(gem_names)
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

    # @param gem_names [Array<String>]
    # @return [Symbol] :approved, :declined, :timed_out, or :unavailable
    def confirm_bundler_recovery(gem_names)
      return :unavailable unless BundlerRecovery.supported?

      body = "Required Ruby gems are not installed:\n#{Array(gem_names).map { |name| "  - #{name}" }.join("\n")}\n\n" \
             "Lich can install the non-GTK runtime bundle to its private directory now.\n" \
             "Your Gemfile and Gemfile.lock will not be changed.\n\nInstall now?"
      script = %(display dialog #{macos_dialog_body(body)} with title #{TITLE.inspect} ) +
               %(buttons {"Install", "Cancel"} default button "Install" with icon caution ) +
               "giving up after #{BUNDLER_RECOVERY_TIMEOUT_SECONDS}"
      output = IO.popen(['osascript', '-'], 'r+') do |io|
        io.write(script)
        io.close_write
        io.read
      end
      return :timed_out if output.include?('gave up:true')
      return :approved if output.include?('button returned:Install')

      :declined
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
      "Required Ruby gems are missing or need repair:\n#{listed_units.join("\n")}\n\n" \
        "Close all other Lich instances before continuing; they may hold native DLLs needed by this repair.\n" \
        "Lich can download and install the approved, hash-verified packages now.\n#{restart_notice}\n\n" \
        'Install now?'
    end

    # @return [String] what happens to the current command after a required repair
    def restart_notice
      return 'A required version repair restarts Lich before continuing.' if relaunch_after_repair?

      'A required version repair exits Lich; run your command again when it finishes.'
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

    # @param missing [Array<String>]
    # @param groups [Array<Symbol>]
    # @param reason [String]
    # @return [void]
    def report_bundler_consent_failure(missing, groups, reason)
      write_log(missing: missing, groups: groups, error: ConsentError.new(reason))
      show_notice("Required gem#{'s' if missing.length != 1} #{missing.join(', ')} not installed. Exiting.")
    end

    # Reads required declarations without evaluating Windows Gemfile plugins.
    # @param groups [Array<Symbol>] groups being verified
    # @return [Array<Gem::Dependency>]
    def required_dependencies(groups)
      if self_healing_supported?
        path = ENV['BUNDLE_GEMFILE'] || File.expand_path('../Gemfile', __dir__)
        reader = RuntimeGemContract.new(gemfile: File.binread(path), groups: groups)
        return reader.roots.map { |name, requirements| Gem::Dependency.new(name, *requirements) }
      end
      bundler.definition.current_dependencies.select { |dep| (dep.groups & groups).any? }
    rescue StandardError, LoadError, SyntaxError => error
      raise DeclarationError, "could not read required gem declarations: #{error.message}"
    end

    # @return [Array<String>] missing names satisfying no installed version
    def missing_gems(groups = [:default])
      required_dependencies(groups).reject do |dep|
        Gem::Specification.find_all_by_name(dep.name, dep.requirement).any?
      end.map(&:name).sort.uniq
    end

    # @return [Array<Symbol>] all groups declared in the Gemfile
    def all_groups
      bundler.definition.groups
    rescue StandardError
      [:default]
    end

    # @param missing [Array<String>] gem names identified by our detector
    # @param groups [Array<Symbol>] groups being verified
    # @param error [Exception, nil] the Bundler or require exception, if any
    # @return [void]
    def alert(missing: [], groups: [:default], error: nil)
      write_log(missing: missing, groups: groups, error: error)
      body = build_alert_body(missing, error)
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then alert_windows(body, download: !policy_failure?(error))
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

    # Composes the alert dialog body: platform message + a bulleted list of
    # detected missing gems, plus the underlying error when one was captured.
    # The error is always shown when present: a failed `require 'gtk3'` may
    # mean a native DLL failed to load even though every gem is installed, so
    # hiding the message behind the missing-gems list misdiagnoses the fault.
    # @param missing [Array<String>]
    # @param error [Exception, nil]
    # @return [String]
    def build_alert_body(missing, error)
      parts = [failure_message(error)]
      if missing.any?
        parts << "Missing gems:\n  - #{missing.join("\n  - ")}"
      end
      if error
        parts << "Underlying error:\n  #{error.message.lines.first.to_s.strip}"
      end
      parts << "See #{File.join(TEMP_DIR, LOG_FILENAME)} for details." if defined?(TEMP_DIR)
      parts.join("\n\n")
    end

    def policy_failure?(error)
      error.is_a?(AcceptedGemPolicy::PolicyError) || error.is_a?(DeclarationError) || error.is_a?(DependencyRecovery::StagingTimeoutError) ||
        error.is_a?(DependencyRecovery::GemHomeNotWritableError)
    end

    def failure_message(error)
      case error
      when DependencyRecovery::GemHomeNotWritableError
        "Lich cannot write to its Ruby gem folder, so it cannot install the gems it needs.\nFix the folder named below, then start Lich again."
      when DependencyRecovery::StagingTimeoutError
        "The runtime recovery download timed out.\nCheck your connection and retry. If it repeats, use a faster connection or contact the release maintainer."
      when AcceptedGemPolicy::AcquisitionError
        "Lich could not retrieve the accepted runtime policy.\nCheck your network connection and retry. Startup requires reachable policy."
      when AcceptedGemPolicy::UnsupportedRuntimeError
        "Automatic gem repair is not available for Ruby #{RUBY_VERSION} on #{Gem::Platform.local}.\n" \
          "Install the missing gems with 'gem install', or install Ruby with the Ruby4Lich5 installer (on ARM64, Windows 11 only)."
      when AcceptedGemPolicy::CoverageError
        "The accepted runtime policy does not cover this Lich installation.\nAsk the release maintainer to restore supported-client coverage; reinstalling Ruby will not fix missing policy coverage."
      when AcceptedGemPolicy::InvalidPolicyError
        "The accepted runtime policy is invalid or incompatible with this runtime.\nAsk the release maintainer to check the published policy."
      when AcceptedGemPolicy::LocalInstallationError
        "This Ruby installation has a missing gem dependency.\nRepair or reinstall Ruby4Lich5, then retry."
      when AcceptedGemPolicy::PolicyError
        "Installed gems cannot satisfy the accepted runtime policy and declared dependencies.\nAsk the release maintainer to check compatibility for this Lich version."
      when DeclarationError
        "Lich could not read its required gem declarations.\nRestore the Gemfile or correct its permissions, then retry."
      else message
      end
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

    # Installed gems at or above a package's minimum but below its accepted
    # version start Lich as they are: no dialog, wait or repair. The accepted
    # versions install with the next required repair of their unit. A player
    # can stay in this state for many starts, so the entry is written only
    # when its content differs from the last recommended entry in the log.
    # @param check [AcceptedGemPolicy::Check]
    # @return [void]
    def write_recommended_log(check)
      found = check.plan.units.flat_map { |unit| unit.fetch('packages').map { |package| [package.fetch('name'), [unit, package]] } }.to_h
      selected = Array(check.specs).to_h { |spec| [spec.name, spec] }
      body = [
        '  Started on installed gems older than the accepted version but at or above its minimum.',
        '  The accepted versions are installed by the next gem repair; nothing is required now.'
      ]
      Array(check.recommended).each do |name|
        unit, package = found[name]
        installed = selected[name] ? selected[name].version : 'unknown'
        accepted = package ? "#{package.fetch('version')} (minimum #{RecoveryUnitPolicy.package_minimum(package)})" : 'unknown'
        body << "    - #{name}: installed #{installed}, accepted #{accepted}, #{unit ? recovery_unit_label(unit) : 'unknown unit'}"
      end
      log_path = File.join(TEMP_DIR, LOG_FILENAME)
      return if last_recommended_body(log_path) == body

      Dir.mkdir(TEMP_DIR) unless File.exist?(TEMP_DIR)
      File.open(log_path, 'a') do |f|
        f.puts "[#{Time.now}] #{RECOMMENDED_HEADING}"
        body.each { |line| f.puts line }
        f.puts
      end
    rescue StandardError
      # Filesystem write failed; startup continues on the installed versions.
    end

    # Body lines of the last recommended entry, without its timestamped
    # heading, or nil when there is none or the log cannot be read; an
    # unreadable log must not stop the entry from being written.
    # @param log_path [String]
    # @return [Array<String>, nil]
    def last_recommended_body(log_path)
      return nil unless File.exist?(log_path)

      last = nil
      current = nil
      File.foreach(log_path) do |line|
        line = line.chomp
        if line.start_with?('[') && line.end_with?("] #{RECOMMENDED_HEADING}")
          current = []
          last = current
        elsif line.empty? || line.start_with?('[')
          current = nil
        elsif current
          current << line
        end
      end
      last
    rescue StandardError
      nil
    end

    # @param missing [Array<String>]
    # @param groups [Array<Symbol>]
    # @param result [BundlerRecovery::Result]
    # @return [void]
    def write_bundler_recovery_log(missing:, groups:, result:)
      write_log(missing: missing, groups: groups, event: 'Bundler recovery',
                recovery_note: "Private non-GTK bundle staged and activated. Details: #{result.log_path}")
    end

    # @param missing [Array<String>]
    # @param groups [Array<Symbol>]
    # @param error [Exception, nil]
    # @param event [String] log event name
    # @param recovery_units [Array<Hash>, nil] approved manifest units
    # @param recovery_note [String, nil] additional approved recovery detail
    # @return [void]
    def write_log(missing: [], groups: [:default], error: nil, event: 'failure', recovery_units: nil, recovery_note: nil)
      log_path = File.join(TEMP_DIR, LOG_FILENAME)
      # verify! can run before init.rb creates TEMP_DIR (fresh install), so
      # ensure the directory exists or the alert would cite a log we never wrote.
      Dir.mkdir(TEMP_DIR) unless File.exist?(TEMP_DIR)
      File.open(log_path, 'a') do |f|
        f.puts "[#{Time.now}] Lich5 GemCheck #{event}"
        f.puts failure_message(error).gsub(/^/, '  ') if event == 'failure'
        f.puts

        if recovery_units
          f.puts '  Approved manifest recovery units:'
          recovery_units.each do |unit|
            f.puts "    - #{recovery_unit_label(unit)}: #{Array(unit['members']).join(', ')}"
          end
          f.puts
        end

        if recovery_note
          f.puts "  Recovery: #{recovery_note}"
          f.puts
        end

        f.puts '  Diagnostics:'
        f.puts "    Ruby:            #{RUBY_DESCRIPTION}"
        f.puts "    Bundler:         #{self_healing_supported? ? 'not used by Windows startup policy' : safe_call { bundler::VERSION }}"
        f.puts "    Gemfile:         #{self_healing_supported? ? ENV.fetch('BUNDLE_GEMFILE', File.expand_path('../Gemfile', __dir__)) : safe_call { bundler.default_gemfile }}"
        f.puts "    Lockfile:        #{self_healing_supported? ? 'not used by Windows startup policy' : safe_call { bundler.default_lockfile }}"
        f.puts "    Working dir:     #{Dir.pwd}"
        f.puts "    Groups checked:  #{groups.inspect}"
        f.puts "    All groups:      #{self_healing_supported? ? 'not evaluated by Windows version policy' : all_groups.inspect}"
        f.puts

        if missing.any?
          f.puts '  Missing gems (detected):'
          missing.each { |name| f.puts "    - #{name}" }
        else
          f.puts '  Missing gems (detected): none identified by GemCheck'
        end
        f.puts

        if error
          f.puts '  Underlying error:'
          f.puts "    Class:   #{error.class}"
          error.message.each_line { |line| f.puts "    #{line.chomp}" }
          f.puts
        end

        f.puts '  Declared dependencies in requested groups:'
        safe_call { dependency_report(groups) }.to_s.each_line do |line|
          f.puts "    #{line.chomp}"
        end
        f.puts

        f.puts "  Download: #{RELEASE_URL}" if event == 'failure' && !policy_failure?(error) && RUBY_PLATFORM =~ /mswin|mingw|cygwin/
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
      deps = required_dependencies(groups)
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
      when /darwin/             then alert_macos(body)
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
    def alert_windows(body, download: true)
      require 'win32ole'
      shell = WIN32OLE.new('WScript.Shell')
      suffix = download ? "\nClick OK to open the download page." : ''
      result = shell.Popup("#{body}#{suffix}", ALERT_TIMEOUT_SECONDS, TITLE, download ? 1 + 64 : 64)
      shell.Run(RELEASE_URL) if download && result == 1
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

    # Reports missing gems on stderr, and additionally in a GUI dialog when
    # there is no terminal that report could have reached.
    #
    # The dialog is only ever *waited on*, never merely shown: a launcher start
    # has no other channel, so {run_with_timeout} keeps the process alive long
    # enough for the dialog to be read. From a terminal that wait is what makes
    # the failure look like a hang -- the dialog is easily missed (another
    # workspace, behind other windows, or not rendering at all), it blocks for
    # {ALERT_TIMEOUT_SECONDS}, and the child's output is discarded, so the user
    # waits two minutes and never learns why. Worst for the early-exit CLI
    # commands (`--help`, `--version`, `--active-sessions`, ...): they are
    # dispatched well after this check runs, so while it blocks they cannot be
    # reached at all.
    #
    # Both streams are probed because a terminal launch may redirect either
    # one.
    #
    # @param body [String]
    # @return [void]
    def alert_linux(body)
      # Always say it on stderr, whether or not a dialog follows. It costs
      # nothing, it is the whole message rather than a pointer to it, and when
      # stderr is captured (a launcher's output, a service log) it is the only
      # record that survives -- the dialog text goes nowhere else.
      warn("!!ALERT!! #{body}")

      # Only wait on a dialog when there was no terminal to have said it in.
      return if $stdout.isatty || $stderr.isatty

      if cmd_available?('zenity')
        run_with_timeout(['zenity', '--info', '--title', TITLE, '--text', body], ALERT_TIMEOUT_SECONDS)
      elsif cmd_available?('kdialog')
        run_with_timeout(['kdialog', '--title', TITLE, '--msgbox', body], ALERT_TIMEOUT_SECONDS)
      elsif cmd_available?('xmessage')
        run_with_timeout(['xmessage', '-center', body], ALERT_TIMEOUT_SECONDS)
      end
      # No dialog tool available needs no fallback branch any more -- the
      # unconditional warn above is the fallback.
    end

    # @param cmd [String] executable name to probe
    # @return [Boolean]
    def cmd_available?(cmd)
      system('which', cmd, out: File::NULL, err: File::NULL)
    end

    # Runs an external command that would otherwise block indefinitely (a
    # GUI dialog with no one present to dismiss it, e.g. a dead or forwarded
    # X display) and forcibly reclaims control once the timeout elapses.
    # Wrapping a blocking Kernel#system call in Timeout can't do this safely,
    # since the spawned child keeps running as an orphan; spawning it
    # ourselves lets us kill it directly.
    #
    # Windows Ruby rejects TERM with Errno::EINVAL, so the child is ended
    # with KILL there; elsewhere TERM gives the dialog a normal shutdown.
    # @param cmd [Array<String>] command and arguments for Process.spawn
    # @param timeout [Integer] seconds to wait before killing the process
    # @return [Boolean] whether the command exited on its own within the timeout
    def run_with_timeout(cmd, timeout)
      pid = Process.spawn(*cmd, out: File::NULL, err: File::NULL)
      Timeout.timeout(timeout) { Process.wait(pid) }
      true
    rescue Timeout::Error
      Process.kill(Gem.win_platform? ? 'KILL' : 'TERM', pid)
      Process.wait(pid)
      false
    end
  end
end
