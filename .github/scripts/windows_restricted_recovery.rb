# frozen_string_literal: true

# Live check of Windows gem recovery on a locked-down runner.
#
# Lich 5.24.0-5.24.2 extracted the R4L5 gem bundle by writing a .ps1 and a
# .vbs launcher and running wscript.exe -> powershell.exe -File. On a stock
# Windows client (execution policy Restricted) or with Windows Script Host
# disabled, that fails. GitHub's Windows runners allow scripts, so this driver
# locks the runner down first and then shows, against the live manifest and
# the real published bundles:
#
#   baseline   the old extraction works before the lockdown (harness check)
#   restricted LocalMachine policy Restricted: old extraction fails, the
#              current recovery stages and installs real units
#   wsh        policy restored, Windows Script Host disabled: same again
#
# It uses only the Ruby standard library and never runs a PowerShell script
# file itself. Policy changes go through `powershell.exe -Command`, which
# Restricted still permits (it blocks script files only); the driver proves
# that with a probe and cross-checks the policy in the registry via reg.exe.
#
# Usage:
#   ruby .github/scripts/windows_restricted_recovery.rb             # Windows CI
#   ruby .github/scripts/windows_restricted_recovery.rb --local-check
#     downloads, verifies and extracts the bundles with the current code only
#
# The remaining modes (old-extract, new-extract, new-recover, popup) are child
# processes started by the driver, so the old and new
# Lich::DependencyRecovery never share a process.

require 'digest'
require 'fileutils'
require 'json'
require 'open-uri'
require 'rbconfig'
require 'tmpdir'

module WindowsRestrictedRecovery
  REPO_ROOT = File.expand_path('../..', __dir__)
  SCRIPT = File.expand_path(__FILE__)
  MANIFEST_URL = ENV.fetch(
    'LICH_RESTRICTED_MANIFEST_URL',
    'https://github.com/elanthia-online/Ruby4Lich5/releases/download/' \
    'R4L5-gem-bundle-x64-mingw-ucrt/R4L5-gem-manifest.json'
  )
  STABLE_BUNDLE_URL = 'https://github.com/elanthia-online/Ruby4Lich5/releases/download/' \
                      'R4L5-gem-bundle-x64-mingw-ucrt/R4L5-gem-bundle-x64-mingw-ucrt.zip'
  OLD_TAG = ENV.fetch('LICH_RESTRICTED_OLD_TAG', 'v5.24.2')
  OLD_FILES = %w[lib/dependency_recovery.rb lib/recovery_unit_policy.rb].freeze
  # gtk3 is the reported failure: a native unit from the candidate-tag zip,
  # replaced by the detached rubyw helper. os is a pure-Ruby unit from the
  # stable-tag zip, installed in-process.
  RECOVERY_GEMS = %w[gtk3 os].freeze
  PS_SHELL_ID_KEY = 'HKLM\\SOFTWARE\\Microsoft\\PowerShell\\1\\ShellIds\\Microsoft.PowerShell'
  PS_GPO_KEYS = %w[
    HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell
    HKCU\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell
  ].freeze
  WSH_KEYS = [
    'HKLM\\SOFTWARE\\Microsoft\\Windows Script Host\\Settings',
    'HKCU\\SOFTWARE\\Microsoft\\Windows Script Host\\Settings'
  ].freeze
  # Process-scope policy and parent Ruby/Bundler settings must not reach the
  # PowerShell probes or the code under test.
  SCRUBBED_ENV = %w[
    PSExecutionPolicyPreference RUBYOPT RUBYLIB GEM_HOME GEM_PATH
    BUNDLER_SETUP BUNDLER_VERSION RUBYGEMS_GEMDEPS
  ].freeze
  OLD_ERROR = /Could not extract .+ \(PowerShell exit \d+\)/
  REPORTED_SUFFIX = '(PowerShell exit 1): no diagnostic output'
  HELPER_DEADLINE_SECONDS = 480

  ChildResult = Struct.new(:status, :stdout, :stderr, :timed_out, keyword_init: true) do
    def success?
      !timed_out && status&.success?
    end

    def exit_text
      timed_out ? 'timed out (process tree killed)' : "exit #{status&.exitstatus.inspect}"
    end
  end

  # ---------------------------------------------------------------- helpers

  module Support
    module_function

    def windows?
      Gem.win_platform?
    end

    def ruby
      RbConfig.ruby
    end

    def log(message)
      $stdout.puts(message)
      $stdout.flush
    end

    def group(title)
      log("::group::#{title}")
      yield
    ensure
      log('::endgroup::')
    end

    def sha256(path)
      "sha256:#{Digest::SHA256.file(path).hexdigest}"
    end

    def read_json(path)
      File.file?(path) ? JSON.parse(File.read(path)) : nil
    rescue JSON::ParserError
      nil
    end

    def write_json(path, data)
      File.write(path, JSON.pretty_generate(data))
    end

    def kill_tree(pid)
      if windows?
        system('taskkill', '/PID', pid.to_s, '/T', '/F', out: File::NULL, err: File::NULL)
      else
        Process.kill('KILL', pid)
      end
    rescue SystemCallError
      nil
    end

    # Output goes to files, never pipes: grandchildren (wscript, the rubyw
    # helper, a relaunched script) inherit handles and would hold a pipe open.
    # The directory is never removed: a detached helper may still hold the
    # inherited files, which Windows refuses to delete, and the runner is
    # discarded anyway.
    def run_process(argv, timeout:, chdir: Dir.pwd)
      dir = Dir.mktmpdir('lich-restricted-child-')
      out_path = File.join(dir, 'out.txt')
      err_path = File.join(dir, 'err.txt')
      pid = Process.spawn(*argv, in: File::NULL, out: out_path, err: err_path, chdir: chdir)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      status = nil
      timed_out = false
      loop do
        _, status = Process.waitpid2(pid, Process::WNOHANG)
        break if status

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          timed_out = true
          kill_tree(pid)
          _, status = Process.waitpid2(pid)
          break
        end
        sleep 0.2
      end
      read = ->(path) { File.binread(path).force_encoding(Encoding::UTF_8).scrub }
      ChildResult.new(status: status, stdout: read.call(out_path), stderr: read.call(err_path), timed_out: timed_out)
    end

    def run_ruby_child(mode, *args, timeout:, chdir: Dir.pwd)
      run_process([ruby, SCRIPT, mode, *args], timeout: timeout, chdir: chdir)
    end

    def show(label, result)
      log("#{label}: #{result.exit_text}")
      log("  stdout: #{result.stdout.strip}") unless result.stdout.strip.empty?
      log("  stderr: #{result.stderr.strip}") unless result.stderr.strip.empty?
    end

    def download(url, destination)
      FileUtils.mkdir_p(File.dirname(destination))
      URI.parse(url).open('rb', open_timeout: 30, read_timeout: 300) do |remote|
        File.open(destination, 'wb') { |file| IO.copy_stream(remote, file) }
      end
      destination
    end
  end

  # ------------------------------------------------------------ the driver

  class Driver
    include Support

    def initialize(local_check: false)
      @local_check = local_check
      @failures = []
      @warnings = []
      @summary = []
      @work = File.join(ENV['RUNNER_TEMP'] || Dir.tmpdir, "lich-restricted-recovery-#{Process.pid}")
      FileUtils.mkdir_p(@work)
    end

    def run
      SCRUBBED_ENV.each do |name|
        log("Removing #{name}=#{ENV[name].inspect} from the environment") if ENV.key?(name)
        ENV.delete(name)
      end
      ENV.keys.grep(/\ABUNDLE_/).each { |name| ENV.delete(name) }

      prepare_artifacts
      if @local_check
        local_check
      else
        windows_run
      end
      finish
    ensure
      restore_runner # an unexpected exception must not leave the runner locked down
    end

    private

    def fail!(message)
      log("::error::#{message}")
      @failures << message
    end

    def warn!(message)
      log("::warning::#{message}")
      @warnings << message
    end

    def record(phase, check, outcome)
      @summary << [phase, check, outcome]
      log("[#{phase}] #{check}: #{outcome}")
    end

    def abort!(message)
      fail!(message)
      finish
    end

    def finish
      log('::endgroup::') # an abort can land inside a group; keep the summary visible
      restore_runner
      log('')
      log('Summary')
      @summary.each { |phase, check, outcome| log("  [#{phase}] #{check}: #{outcome}") }
      @warnings.each { |message| log("  warning: #{message}") }
      @failures.each { |message| log("  FAILED: #{message}") }
      write_step_summary
      exit(@failures.empty? ? 0 : 1)
    end

    def write_step_summary
      path = ENV.fetch('GITHUB_STEP_SUMMARY', nil)
      return unless path

      lines = ['## Windows locked-down gem recovery', '', '| Phase | Check | Outcome |', '|---|---|---|']
      @summary.each { |row| lines << "| #{row.map { |cell| cell.to_s.gsub('|', '\\|').gsub("\n", ' ') }.join(' | ')} |" }
      lines << ''
      @warnings.each { |message| lines << "- warning: #{message}" }
      @failures.each { |message| lines << "- **failed:** #{message}" }
      File.write(path, "#{lines.join("\n")}\n", mode: 'a')
    end

    # -- artifacts --------------------------------------------------------

    def prepare_artifacts
      group('Download and verify the live manifest and bundles') do
        manifest_path = download(MANIFEST_URL, File.join(@work, 'manifest', 'R4L5-gem-manifest.json'))
        @manifest = JSON.parse(File.read(manifest_path))
        target = @manifest.fetch('targets').find { |t| t['platform'] == 'x64-mingw-ucrt' && t['ruby_abi'] == '4.0' }
        abort!('live manifest has no Ruby 4.0 x64-mingw-ucrt target') unless target
        @units = target.fetch('units')

        zip_artifacts = @units.map { |unit| unit.fetch('artifact') }.select { |a| a['archive'] == 'zip' }
        @zips = zip_artifacts.group_by { |a| a.fetch('url') }.map do |url, artifacts|
          shas = artifacts.map { |a| a.fetch('sha256') }.uniq
          abort!("manifest lists #{url} with differing sha256 values #{shas}") unless shas.length == 1
          dir = File.join(@work, 'artifacts', Digest::SHA256.hexdigest(url)[0, 12])
          path = download(url, File.join(dir, File.basename(URI.parse(url).path)))
          actual = sha256(path)
          abort!("#{url}: sha256 #{actual} does not match manifest #{shas.first}") unless actual == shas.first
          record('artifacts', File.basename(File.dirname(URI.parse(url).path)), "#{File.size(path)} bytes, #{actual} matches manifest")
          { url: url, path: path, sha256: actual, tag: File.basename(File.dirname(URI.parse(url).path)) }
        end
        abort!("manifest no longer references #{STABLE_BUNDLE_URL}") unless @zips.any? { |zip| zip[:url] == STABLE_BUNDLE_URL }
        RECOVERY_GEMS.each do |name|
          unit = @units.find { |u| u.fetch('members').include?(name) }
          abort!("manifest has no unit for #{name}") unless unit
          log("#{name}: unit #{unit['id']} from #{unit.dig('artifact', 'url')}")
        end
      end
    end

    # Hash every manifest package that names this zip as its artifact.
    def verify_extracted(dir, zip)
      packages = @units.select { |unit| unit.dig('artifact', 'url') == zip[:url] }
                       .flat_map { |unit| unit.fetch('packages') }.uniq { |package| package.fetch('filename') }
      bad = packages.reject do |package|
        path = File.join(dir, package.fetch('filename'))
        File.file?(path) && sha256(path) == package.fetch('sha256')
      end
      [packages.length, bad.map { |package| package.fetch('filename') }]
    end

    def extract_check(phase, mode, lib_dir, zip, expect:)
      dest = File.join(@work, phase, "#{mode}-#{zip[:tag]}", 'packages')
      result_path = File.join(@work, phase, "#{mode}-#{zip[:tag]}.json")
      FileUtils.mkdir_p(File.dirname(dest))
      child = run_ruby_child(mode, lib_dir, zip[:path], dest, result_path, timeout: 180)
      show("#{mode} #{zip[:tag]}", child)
      outcome = read_json(result_path) || {}
      label = "#{mode == 'old-extract' ? "#{OLD_TAG} extract" : 'current extract'} #{zip[:tag]}"
      case expect
      when :success
        if outcome['status'] == 'ok'
          count, bad = verify_extracted(dest, zip)
          if bad.empty?
            record(phase, label, "extracted; #{count} manifest packages match sha256")
          else
            fail!("[#{phase}] #{label}: packages missing or with a wrong sha256: #{bad.join(', ')}")
          end
        else
          fail!("[#{phase}] #{label}: expected success, got #{child.exit_text}: #{outcome['class']}: #{outcome['message']}")
        end
      when :strict_failure
        message = outcome['message'].to_s
        if outcome['status'] == 'raised' && outcome['class'] == 'Lich::DependencyRecovery::Error' && message.match?(OLD_ERROR)
          exact = message.end_with?(REPORTED_SUFFIX) ? 'matches the reported error exactly' : "differs from the reported '#{REPORTED_SUFFIX}'"
          record(phase, label, "failed as expected (#{exact}): #{message}")
        elsif outcome['status'] == 'ok'
          fail!("[#{phase}] #{label}: old extraction SUCCEEDED, so the lockdown does not reproduce the bug")
        else
          fail!("[#{phase}] #{label}: expected Lich::DependencyRecovery::Error matching #{OLD_ERROR.source}, " \
                "got #{child.exit_text}: #{outcome['class']}: #{message}")
        end
      when :any_failure
        message = outcome['message'].to_s
        if child.timed_out
          record(phase, label, 'failed as expected: hung until killed (likely a WSH message box nobody can dismiss)')
        elsif outcome['status'] == 'raised' && message.match?(/Could not extract/)
          record(phase, label, "failed as expected: #{message}")
        elsif outcome['status'] == 'ok'
          fail!("[#{phase}] #{label}: old extraction SUCCEEDED with Windows Script Host disabled")
        else
          fail!("[#{phase}] #{label}: unexpected outcome #{child.exit_text}: #{outcome['class']}: #{message}")
        end
      end
    end

    # -- local -------------------------------------------------------------

    def local_check
      group('Current extraction of each published zip') do
        @zips.each { |zip| extract_check('local', 'new-extract', File.join(REPO_ROOT, 'lib'), zip, expect: :success) }
      end
      old_lib = fetch_old_lib
      record('local', "#{OLD_TAG} sources", "fetched into #{old_lib}")
    end

    # -- windows -----------------------------------------------------------

    def windows_run
      abort!('this check needs Windows; use --local-check elsewhere') unless windows?
      platform = Gem::Platform.local.to_s
      abort!("expected an x64-mingw-ucrt Ruby, got #{platform}") unless platform == 'x64-mingw-ucrt'
      record('setup', 'ruby', "#{RUBY_DESCRIPTION} at #{ruby}")
      record('setup', 'gem dir', Gem.dir)
      @old_lib = fetch_old_lib
      @new_lib = File.join(REPO_ROOT, 'lib')
      @probe_dir = File.join(@work, 'probes')
      FileUtils.mkdir_p(@probe_dir)
      @test_ps1 = File.join(@probe_dir, 'probe.ps1')
      File.write(@test_ps1, "Write-Output 'script-ran'\r\n")
      @test_vbs = File.join(@probe_dir, 'probe.vbs')
      File.write(@test_vbs, "WScript.Echo \"vbs-ran\"\r\n")

      baseline_phase
      restricted_phase
      wsh_phase
    end

    def fetch_old_lib
      dir = File.join(@work, "old-#{OLD_TAG}", 'lib')
      FileUtils.mkdir_p(dir)
      unless system('git', '-C', REPO_ROOT, 'rev-parse', '-q', '--verify', "refs/tags/#{OLD_TAG}", out: File::NULL, err: File::NULL)
        fetched = system('git', '-C', REPO_ROOT, 'fetch', '--no-tags', '--depth=1', 'origin',
                         "+refs/tags/#{OLD_TAG}:refs/tags/#{OLD_TAG}")
        abort!("could not fetch tag #{OLD_TAG}") unless fetched
      end
      OLD_FILES.each do |file|
        content = IO.popen(['git', '-C', REPO_ROOT, 'show', "#{OLD_TAG}:#{file}"], 'rb', &:read)
        abort!("git show #{OLD_TAG}:#{file} failed") unless $?.success? && !content.empty?
        File.binwrite(File.join(dir, File.basename(file)), content)
      end
      old_source = File.read(File.join(dir, 'dependency_recovery.rb'))
      unless old_source.include?('def extract_zip_file') && old_source.include?("'wscript.exe'") && old_source.include?('-File ')
        abort!("#{OLD_TAG}:lib/dependency_recovery.rb does not contain the wscript/PowerShell extractor")
      end
      dir
    end

    # -- PowerShell / registry probes ----------------------------------------

    def powershell(command, timeout: 90)
      run_process(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', command], timeout: timeout)
    end

    def execution_policies
      result = powershell("Get-ExecutionPolicy -List | ForEach-Object { '{0}={1}' -f $_.Scope, $_.ExecutionPolicy }; " \
                          "'Effective={0}' -f (Get-ExecutionPolicy)")
      show('Get-ExecutionPolicy -List', result)
      return nil unless result.success?

      result.stdout.lines.filter_map { |line| line.strip.split('=', 2) if line.include?('=') }.to_h
    end

    def reg_value(key, name)
      result = run_process(['reg.exe', 'query', key, '/v', name], timeout: 30)
      return nil unless result.success?

      line = result.stdout.lines.find { |l| l.strip.start_with?("#{name} ") }
      line&.strip&.split(/\s{2,}|\t/, 3)&.last
    end

    # Puts the runner back however the run ends: the LocalMachine execution
    # policy recorded at baseline, and Windows Script Host re-enabled. Runs
    # once, from finish (every normal or aborted exit) or run's ensure.
    def restore_runner
      return if @restored || !windows? || @initial_local_machine.nil?

      @restored = true
      log('::group::restore: put the runner back')
      policy = powershell("Set-ExecutionPolicy -ExecutionPolicy #{@initial_local_machine} -Scope LocalMachine -Force -ErrorAction Stop")
      show('Set-ExecutionPolicy (restore)', policy)
      fail!("could not restore LocalMachine policy #{@initial_local_machine}") unless policy.success?
      WSH_KEYS.each do |key|
        result = run_process(['reg.exe', 'delete', key, '/v', 'Enabled', '/f'], timeout: 30)
        show("reg delete #{key} Enabled", result) # absent already is fine
      end
      record('restore', 'runner', "LocalMachine=#{@initial_local_machine}; Windows Script Host Enabled values removed")
      log('::endgroup::')
    end

    def reg_set_dword(key, name, value)
      result = run_process(['reg.exe', 'add', key, '/v', name, '/t', 'REG_DWORD', '/d', value.to_s, '/f'], timeout: 30)
      show("reg add #{key} #{name}=#{value}", result)
      result.success?
    end

    def ps1_probe
      result = run_process(['powershell.exe', '-NoProfile', '-NonInteractive', '-File', @test_ps1], timeout: 90)
      show('powershell.exe -File probe.ps1', result)
      [result.success? && result.stdout.include?('script-ran'), result]
    end

    def command_probe
      result = powershell("Write-Output 'command-ran'")
      result.success? && result.stdout.include?('command-ran')
    end

    def vbs_probe
      result = run_process(['cscript.exe', '//nologo', @test_vbs], timeout: 60)
      show('cscript //nologo probe.vbs', result)
      [result.success? && result.stdout.include?('vbs-ran'), result]
    end

    def gpo_policy_overrides
      PS_GPO_KEYS.flat_map do |key|
        %w[EnableScripts ExecutionPolicy].filter_map do |name|
          value = reg_value(key, name)
          "#{key}\\#{name}=#{value}" if value
        end
      end
    end

    # -- phases --------------------------------------------------------------

    def baseline_phase
      group('baseline: permissive runner, before any lockdown') do
        policies = execution_policies
        abort!('Get-ExecutionPolicy -List failed on the unmodified runner') unless policies
        @initial_local_machine = policies.fetch('LocalMachine', 'Undefined')
        record('baseline', 'execution policy', policies.map { |k, v| "#{k}=#{v}" }.join(', '))
        ran, = ps1_probe
        abort!('powershell.exe -File does not run a script even before the lockdown') unless ran
        record('baseline', 'powershell -File probe.ps1', 'runs')
        vbs_ran, = vbs_probe
        abort!('cscript does not run a .vbs before WSH is disabled') unless vbs_ran
        record('baseline', 'cscript probe.vbs', 'runs')
        @zips.each { |zip| extract_check('baseline', 'old-extract', @old_lib, zip, expect: :success) }
        abort!('the old extractor fails before the lockdown, so its later failure would prove nothing') unless @failures.empty?
      end
    end

    def restricted_phase
      group('restricted: LocalMachine execution policy Restricted') do
        set = powershell('Set-ExecutionPolicy -ExecutionPolicy Undefined -Scope CurrentUser -Force -ErrorAction Stop; ' \
                         'Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force -ErrorAction Stop')
        show('Set-ExecutionPolicy', set)
        abort!('Set-ExecutionPolicy Restricted -Scope LocalMachine failed') unless set.success?
        verify_restricted_policy
        @zips.each { |zip| extract_check('restricted', 'old-extract', @old_lib, zip, expect: :strict_failure) }
        RECOVERY_GEMS.each { |name| recovery_check('restricted', name) }
        popup_check('restricted')
      end
    end

    def verify_restricted_policy
      unless command_probe
        abort!('powershell.exe -Command is refused under Restricted; the assumption that only script files are blocked is wrong')
      end
      record('restricted', 'powershell -Command', 'still allowed')
      policies = execution_policies
      abort!('Get-ExecutionPolicy -List failed after the lockdown') unless policies
      record('restricted', 'execution policy', policies.map { |k, v| "#{k}=#{v}" }.join(', '))
      overrides = %w[MachinePolicy UserPolicy Process CurrentUser].reject { |scope| policies.fetch(scope, 'Undefined') == 'Undefined' }
      abort!("execution policy scopes override LocalMachine: #{overrides.map { |s| "#{s}=#{policies[s]}" }.join(', ')}") unless overrides.empty?
      abort!("LocalMachine policy is #{policies['LocalMachine'].inspect}, not Restricted") unless policies['LocalMachine'] == 'Restricted'
      abort!("effective policy is #{policies['Effective'].inspect}, not Restricted") unless policies['Effective'] == 'Restricted'
      registry = reg_value(PS_SHELL_ID_KEY, 'ExecutionPolicy')
      abort!("registry #{PS_SHELL_ID_KEY}\\ExecutionPolicy is #{registry.inspect}, not Restricted") unless registry == 'Restricted'
      gpo = gpo_policy_overrides
      abort!("Group Policy sets the PowerShell execution policy: #{gpo.join(', ')}") unless gpo.empty?
      record('restricted', 'registry', "ShellIds ExecutionPolicy=Restricted; no Group Policy values")
      ran, result = ps1_probe
      abort!('powershell.exe -File still runs a script under Restricted') if ran || result.success?
      disabled = (result.stdout + result.stderr).match?(/running scripts is disabled/i)
      record('restricted', 'powershell -File probe.ps1', "refused (#{result.exit_text}#{', running scripts is disabled' if disabled})")
    end

    def wsh_phase
      group('wsh: execution policy restored, Windows Script Host disabled') do
        restore = powershell("Set-ExecutionPolicy -ExecutionPolicy #{@initial_local_machine} -Scope LocalMachine -Force -ErrorAction Stop")
        show('Set-ExecutionPolicy (restore)', restore)
        abort!("could not restore LocalMachine policy #{@initial_local_machine}") unless restore.success?
        ran, = ps1_probe
        abort!('powershell.exe -File still refuses scripts after restoring the policy; the WSH phase would not isolate WSH') unless ran
        record('wsh', 'execution policy', "LocalMachine=#{@initial_local_machine} restored; powershell -File probe.ps1 runs")
        WSH_KEYS.each { |key| abort!("could not set #{key}\\Enabled=0") unless reg_set_dword(key, 'Enabled', 0) }
        vbs_ran, result = vbs_probe
        abort!('cscript still runs a .vbs with Windows Script Host disabled') if vbs_ran
        record('wsh', 'cscript probe.vbs', "refused (#{result.exit_text}): #{(result.stdout + result.stderr).strip.lines.first&.strip}")
        @zips.each { |zip| extract_check('wsh', 'old-extract', @old_lib, zip, expect: :any_failure) }
        RECOVERY_GEMS.each { |name| recovery_check('wsh', name) }
        popup_check('wsh')
      end
    end

    # -- current recovery --------------------------------------------------------

    def recovery_check(phase, gem_name)
      root = File.join(@work, phase, "recover-#{gem_name}")
      markers = File.join(root, 'markers')
      FileUtils.mkdir_p(markers)
      result_path = File.join(root, 'result.json')
      child = run_ruby_child('new-recover', @new_lib, MANIFEST_URL, gem_name, root, result_path, markers,
                             timeout: 600, chdir: root)
      show("new-recover #{gem_name}", child)
      outcome = read_json(result_path)
      label = "current recovery of #{gem_name}"
      return fail!("[#{phase}] #{label}: no result (#{child.exit_text})") unless outcome
      return fail!("[#{phase}] #{label}: #{outcome['error_kind']} #{outcome['error']}") unless outcome['success']

      bad_hashes = outcome.fetch('staged').reject { |entry| entry['ok'] }
      unless bad_hashes.empty?
        return fail!("[#{phase}] #{label}: staged packages with a wrong sha256: #{bad_hashes.map { |e| e['filename'] }.join(', ')}")
      end

      unit = @units.find { |u| u.fetch('id') == outcome.fetch('unit') }
      packages = unit.fetch('packages')
      staged_names = outcome.fetch('staged').map { |entry| entry['name'] }.sort
      unless staged_names == packages.map { |package| package['name'] }.sort
        return fail!("[#{phase}] #{label}: staged #{staged_names} but unit #{unit['id']} has #{packages.map { |p| p['name'] }.sort}")
      end

      if outcome['restart_required']
        return unless wait_for_helper(phase, label, outcome, root, markers)
      elsif !(packages.map { |p| p['name'] } - outcome.fetch('installed_gems')).empty?
        return fail!("[#{phase}] #{label}: installed #{outcome['installed_gems']}, expected #{packages.map { |p| p['name'] }}")
      end
      load_check(phase, label, packages, gem_name, outcome)
    end

    def wait_for_helper(phase, label, outcome, root, markers)
      restarted = File.join(markers, 'restarted.json')
      failure_log = File.join(outcome.fetch('temp_dir'), 'lich5-missing-gems.log')
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + HELPER_DEADLINE_SECONDS
      until File.file?(restarted) || File.file?(failure_log)
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          kill_tree(outcome['helper_pid']) if outcome['helper_pid']
          fail!("[#{phase}] #{label}: the replacement helper neither restarted the program nor logged a failure " \
                "within #{HELPER_DEADLINE_SECONDS}s (helper pid #{outcome['helper_pid']} killed)")
          return false
        end
        sleep 1
      end
      if File.file?(failure_log)
        sleep 2
        kill_tree(outcome['helper_pid']) if outcome['helper_pid'] # it shows a Popup with no timeout
        fail!("[#{phase}] #{label}: the replacement helper failed: #{File.read(failure_log).strip}")
        return false
      end
      relaunch = read_json(restarted) || {}
      record(phase, "#{label} helper", "replaced the unit after the parent exited and relaunched #{relaunch['program']} (#{relaunch['argv']&.first})")
      leftover = Dir.exist?(outcome.fetch('work_dir'))
      log("  helper workspace #{outcome['work_dir']} #{leftover ? 'still exists' : 'was removed'}")
      true
    ensure
      log("  #{root} contents: #{Dir.glob('**/*', base: root).first(40).join(', ')}") if root && Dir.exist?(root)
    end

    def load_check(phase, label, packages, gem_name, outcome)
      versions = packages.flat_map { |package| [package.fetch('name'), package.fetch('version')] }
      # No double quotes: they would need escaping on the Windows command line.
      script = "entry = ARGV.shift; ARGV.each_slice(2) { |name, version| gem(name, '= ' + version) }; " \
               "require entry; puts Gem.loaded_specs.values.map(&:full_name).sort.join(' ')"
      child = run_process([ruby, '-e', script, gem_name, *versions], timeout: 120)
      show("load #{gem_name}", child)
      if child.success?
        how = outcome['restart_required'] ? 'native helper replacement' : 'in-process install'
        record(phase, label, "#{how}; #{packages.length} packages sha256-verified, installed at manifest versions and #{gem_name} loads")
      else
        fail!("[#{phase}] #{label}: installed gems do not load: #{child.stderr.strip.lines.last(5).join}")
      end
    end

    def popup_check(phase)
      result_path = File.join(@work, phase, 'popup.json')
      child = run_ruby_child('popup', result_path, timeout: 60)
      show('WScript.Shell Popup', child)
      outcome = read_json(result_path) || {}
      if outcome['status'] == 'ok' && outcome['value'] == -1
        record(phase, 'WScript.Shell Popup (1s timeout)', 'returned -1 (timed out as expected)')
      else
        detail = child.timed_out ? 'hung until killed' : "#{outcome['status']}: #{outcome['value'] || outcome['message']}"
        record(phase, 'WScript.Shell Popup (1s timeout)', "did not return -1 (#{detail})")
        warn!("[#{phase}] WScript.Shell Popup did not return -1: #{detail}")
      end
    end
  end

  # ------------------------------------------------------- child processes

  module Children
    extend Support

    module_function

    def capture(result_path)
      yield
    rescue Exception => e # rubocop:disable Lint/RescueException
      write_json(result_path, 'status' => 'raised', 'class' => e.class.name, 'message' => e.message,
                              'backtrace' => Array(e.backtrace).first(8))
      exit 1
    end

    def old_extract(lib_dir, zip, dest, result_path)
      capture(result_path) do
        require File.join(lib_dir, 'dependency_recovery.rb')
        scratch = File.join(File.dirname(dest), 'scratch')
        recovery = Lich::DependencyRecovery.new(gem_home: scratch, temp_dir: scratch, lich_version: '5.24.2')
        recovery.send(:extract_zip_file, zip, dest)
        write_json(result_path, 'status' => 'ok', 'entries' => Dir.children(dest).sort)
      end
    end

    def new_extract(lib_dir, zip, dest, result_path)
      capture(result_path) do
        require File.join(lib_dir, 'dependency_recovery.rb')
        scratch = File.join(File.dirname(dest), 'scratch')
        recovery = Lich::DependencyRecovery.new(gem_home: scratch, temp_dir: scratch, lich_version: lich_version(lib_dir))
        recovery.send(:extract_zip_file, zip, dest)
        write_json(result_path, 'status' => 'ok', 'entries' => Dir.children(dest).sort)
      end
    end

    def lich_version(lib_dir)
      File.read(File.join(lib_dir, 'version.rb'))[/^LICH_VERSION = '([^']+)'/, 1] || raise('LICH_VERSION not found')
    end

    # Runs the real recovery against the live manifest into the runtime's own
    # Gem.dir, as Lich does (the runner is discarded afterwards). The native
    # helper relaunches this script with the same arguments once it has
    # replaced the unit; the marker written before the helper starts turns
    # that relaunch into a no-op that only records it ran.
    def new_recover(lib_dir, manifest_url, gem_name, root, result_path, markers)
      scheduled = File.join(markers, 'scheduled')
      if File.file?(scheduled)
        write_json(File.join(markers, 'restarted.json'),
                   'pid' => Process.pid, 'program' => File.expand_path($PROGRAM_NAME), 'argv' => ARGV, 'ruby' => RbConfig.ruby)
        return
      end

      capture(result_path) do
        require File.join(lib_dir, 'dependency_recovery.rb')
        temp_dir = File.join(root, 'lich', 'temp')
        staged = []
        helper_pid = nil
        work_dir = nil
        recovery = nil
        plan = nil
        check = lambda do |path|
          filename = File.basename(path)
          package = plan.units.flat_map { |unit| unit.fetch('packages') }.find { |p| p.fetch('filename') == filename }
          staged << { 'name' => package&.fetch('name'), 'filename' => filename, 'path' => path,
                      'ok' => !package.nil? && sha256(path) == package.fetch('sha256') }
        end
        launcher = lambda do |payload_path|
          payload = JSON.parse(File.read(payload_path))
          work_dir = payload.fetch('work_dir')
          payload.fetch('packages').each { |package| check.call(package.fetch('path')) }
          File.write(scheduled, payload_path)
          helper_pid = recovery.send(:launch_windows_helper, payload_path)
        end
        installer = lambda do |path, gem_home|
          check.call(path)
          recovery.send(:install_gem_file, path, gem_home)
        end
        recovery = Lich::DependencyRecovery.new(
          manifest_url: manifest_url, gem_home: Gem.dir, temp_dir: temp_dir,
          lich_version: lich_version(lib_dir), helper_launcher: launcher, install_gem: installer
        )
        plan = recovery.recovery_plan([gem_name])
        raise "recovery plan failed: #{plan.error}" unless plan.success?
        raise "expected one unit for #{gem_name}, got #{plan.units.map { |u| u['id'] }}" unless plan.units.length == 1

        result = recovery.recover([gem_name], plan: plan, force: true)
        write_json(result_path,
                   'status' => 'ok', 'success' => result.success?, 'error' => result.error,
                   'error_kind' => result.error_kind, 'restart_required' => result.restart_required,
                   'installed_gems' => result.installed_gems, 'unit' => plan.units.first.fetch('id'),
                   'artifact' => plan.units.first.dig('artifact', 'url'), 'staged' => staged,
                   'helper_pid' => helper_pid, 'work_dir' => work_dir, 'temp_dir' => temp_dir,
                   'gem_dir' => Gem.dir)
      end
    end

    def popup(result_path)
      capture(result_path) do
        require 'win32ole'
        value = WIN32OLE.new('WScript.Shell').Popup('Lich CI popup probe', 1, 'Lich5 CI', 64)
        write_json(result_path, 'status' => 'ok', 'value' => value)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__ || File.expand_path($PROGRAM_NAME) == WindowsRestrictedRecovery::SCRIPT
  mode = ARGV.first
  case mode
  when 'old-extract' then WindowsRestrictedRecovery::Children.old_extract(*ARGV[1, 4])
  when 'new-extract' then WindowsRestrictedRecovery::Children.new_extract(*ARGV[1, 4])
  when 'new-recover' then WindowsRestrictedRecovery::Children.new_recover(*ARGV[1, 6])
  when 'popup' then WindowsRestrictedRecovery::Children.popup(ARGV[1])
  when nil, '--local-check' then WindowsRestrictedRecovery::Driver.new(local_check: mode == '--local-check').run
  else
    warn "unknown mode #{mode.inspect}"
    exit 2
  end
end
