# lib/dependency_recovery.rb
require 'digest'
require 'fileutils'
require 'json'
require 'open-uri'
require 'open3'
require 'rbconfig'
require 'rubygems/installer'
require 'tmpdir'
require 'uri'

module Lich
  # Restores approved runtime gems from the Ruby4Lich5 manifest when an
  # installed runtime is incomplete or a native extension cannot load. The
  # manifest is deliberately an allow-list: a gem name is never turned into a
  # URL, shell command, or RubyGems request by this class.
  #
  # A manifest is a release asset controlled by the same human-reviewed
  # promotion as the gem bundle. Its SHA-256 values protect against accidental
  # corruption and mismatched assets; they are not a substitute for signing,
  # because the manifest and assets currently share a publisher.
  class DependencyRecovery
    DEFAULT_MANIFEST_URL = 'https://github.com/Lich5/Ruby4Lich5/releases/download/' \
                           'R4L5-gem-bundle-x64-mingw-ucrt/R4L5-gem-manifest.json'
    LOCK_FILENAME = '.lich-dependency-recovery.lock'
    SHA256_PATTERN = /\Asha256:[0-9a-f]{64}\z/
    SAFE_FILENAME = /\A(?!\.+\z)[^\\\/]+\z/
    SAFE_NAME = /\A[a-zA-Z0-9_.-]+\z/

    # @return [String] result of a successful or unsuccessful recovery attempt
    Result = Struct.new(:installed_gems, :error, :restart_required, keyword_init: true) do
      # @return [Boolean] whether recovery completed successfully
      def success?
        error.nil?
      end
    end

    # A validated, manifest-derived set of units. Planning intentionally
    # fetches no gem artifacts, so callers can obtain user consent before an
    # installation changes the runtime.
    Plan = Struct.new(:units, :error, keyword_init: true) do
      # @return [Boolean] whether the requested units are approved and valid
      def success?
        error.nil?
      end
    end

    # Raised internally for malformed manifests and rejected artifacts.
    class Error < StandardError; end

    # @param manifest_url [String] HTTPS manifest location
    # @param gem_home [String] runtime-owned installation directory
    # @param temp_dir [String] Lich-owned directory for transient recovery files
    # @param http_get [#call, nil] test seam returning binary response content
    # @param install_gem [#call, nil] test seam for local gem installation
    # @param extract_zip [#call, nil] test seam for zip extraction
    # @param powershell_runner [#call, nil] test seam for the Windows extractor
    def initialize(manifest_url: ENV.fetch('LICH_GEM_MANIFEST_URL', DEFAULT_MANIFEST_URL),
                   gem_home: Gem.dir, temp_dir: (defined?(TEMP_DIR) ? TEMP_DIR : Dir.tmpdir),
                   http_get: nil, install_gem: nil, extract_zip: nil, powershell_runner: nil,
                   helper_launcher: nil)
      @manifest_url = manifest_url
      @gem_home = gem_home
      @temp_dir = temp_dir
      @http_get = http_get
      @install_gem = install_gem || method(:install_gem_file)
      @extract_zip = extract_zip || method(:extract_zip_file)
      @powershell_runner = powershell_runner || Open3.method(:capture3)
      @helper_launcher = helper_launcher || method(:launch_windows_helper)
    end

    # Loads and validates the manifest units covering +gem_names+, without
    # downloading gem artifacts. Callers use this to request consent first.
    #
    # @param gem_names [Array<String>] approved gem names to restore
    # @return [Plan]
    def recovery_plan(gem_names)
      requested = Array(gem_names).map(&:to_s).reject(&:empty?).uniq
      return Plan.new(units: []) if requested.empty?

      Plan.new(units: units_for(load_manifest, requested))
    rescue Error, JSON::ParserError, OpenURI::HTTPError, SocketError, SystemCallError => e
      Plan.new(units: [], error: e.message)
    rescue StandardError => e
      Plan.new(units: [], error: "#{e.class}: #{e.message}")
    end

    # Downloads, verifies, and installs a previously approved manifest plan.
    # Installation always targets +Gem.dir+ (or the injected runtime directory),
    # never a user-controlled GEM_HOME.
    #
    # @param gem_names [Array<String>] approved gem names to restore
    # @param force [Boolean] reinstall even when the manifest version is present
    # @param plan [Plan, nil] plan obtained before user consent
    # @return [Result]
    def recover(gem_names, force: false, plan: nil)
      planned = plan || recovery_plan(gem_names)
      return Result.new(installed_gems: [], error: planned.error) unless planned.success?

      result = with_install_lock do
        with_recovery_workspace do |work_dir|
          staged_units = planned.units.map { |unit| stage_unit(unit, work_dir) }
          replacement, direct = staged_units.partition { |staged| native_runtime_unit?(staged.fetch(:unit)) }
          installed = direct.flat_map { |staged| install_staged_unit(staged, force: force) }

          if replacement.empty?
            Result.new(installed_gems: installed)
          elsif replacement.length == 1
            schedule_runtime_replacement(replacement.first, work_dir)
            Result.new(installed_gems: installed, restart_required: true)
          else
            raise Error, 'multiple native runtime replacement units are not supported in one recovery'
          end
        end
      end
      refresh_rubygems! unless result.restart_required
      result
    rescue Error, JSON::ParserError, OpenURI::HTTPError, SocketError, SystemCallError => e
      Result.new(installed_gems: [], error: e.message)
    rescue StandardError => e
      # Recovery runs during boot. Keep an unexpected implementation failure
      # from turning into an unhelpful backtrace before GemCheck can report it.
      Result.new(installed_gems: [], error: "#{e.class}: #{e.message}")
    end

    # Runs in a detached Ruby process after the original Lich process exits.
    # The payload contains only already-hash-verified package paths and the
    # original Lich invocation; artifacts are re-verified before replacement.
    #
    # @param payload_path [String] JSON transaction description
    # @return [Boolean] whether the replacement and restart succeeded
    def self.run_windows_replacement(payload_path)
      payload = JSON.parse(File.read(payload_path))
      recovery = new(gem_home: payload.fetch('gem_home'), temp_dir: payload.fetch('temp_dir'))
      recovery.send(:run_windows_replacement!, payload)
      true
    rescue StandardError => e
      log_helper_failure(payload_path, e)
      false
    end

    # @param payload_path [String]
    # @param error [Exception]
    # @return [void]
    def self.log_helper_failure(payload_path, error)
      payload = JSON.parse(File.read(payload_path)) rescue {}
      log_path = File.join(payload.fetch('temp_dir', Dir.tmpdir), 'lich5-missing-gems.log')
      File.open(log_path, 'a') do |file|
        file.puts "[#{Time.now}] Lich5 native gem replacement failure"
        file.puts "  #{error.class}: #{error.message}"
        file.puts
      end
      return unless Gem.win_platform?

      require 'win32ole'
      WIN32OLE.new('WScript.Shell').Popup(
        "Lich could not update the GTK runtime. See #{log_path} for details.",
        0, 'Lich5: Ruby Gem Recovery', 16
      )
    rescue StandardError
      nil
    end

    private

    # @return [Hash] validated manifest document
    def load_manifest
      document = JSON.parse(fetch(@manifest_url))
      raise Error, 'manifest must be a JSON object' unless document.is_a?(Hash)
      raise Error, "unsupported manifest schema #{document['schema'].inspect}" unless document['schema'] == 1
      raise Error, 'manifest targets must be an array' unless document['targets'].is_a?(Array)

      document
    end

    # Selects units only from the exact Ruby ABI and platform that are running.
    # @param manifest [Hash]
    # @param requested [Array<String>]
    # @return [Array<Hash>]
    def units_for(manifest, requested)
      target = manifest.fetch('targets').find do |candidate|
        candidate.is_a?(Hash) &&
          candidate['ruby_abi'] == ruby_abi &&
          candidate['platform'] == Gem::Platform.local.to_s
      end
      raise Error, "manifest has no target for Ruby #{ruby_abi} on #{Gem::Platform.local}" unless target

      units = target['units']
      raise Error, 'manifest target units must be an array' unless units.is_a?(Array)

      selected = requested.map do |name|
        unit = units.find { |candidate| unit_members(candidate).include?(name) }
        raise Error, "manifest does not approve recovery for #{name.inspect}" unless unit

        validate_unit!(unit)
        unit
      end
      selected.uniq { |unit| unit.fetch('id') }
    end

    # @param unit [Hash]
    # @return [Array<String>]
    def unit_members(unit)
      unit.is_a?(Hash) && unit['members'].is_a?(Array) ? unit['members'] : []
    end

    # @param unit [Hash]
    # @return [void]
    def validate_unit!(unit)
      raise Error, 'unit id is missing or unsafe' unless unit['id'].is_a?(String) && unit['id'].match?(SAFE_NAME)
      raise Error, "unit #{unit['id']} has no members" if unit_members(unit).empty?
      raise Error, "unit #{unit['id']} has unsafe member names" unless unit_members(unit).all? { |name| name.is_a?(String) && name.match?(SAFE_NAME) }

      artifact = unit['artifact']
      raise Error, "unit #{unit['id']} has no artifact object" unless artifact.is_a?(Hash)
      parse_https_uri!(artifact['url'], "unit #{unit['id']} artifact URL")
      require_sha256!(artifact['sha256'], "unit #{unit['id']} artifact")
      require_filename!(artifact['filename'], "unit #{unit['id']} artifact")
      raise Error, "unit #{unit['id']} has unsupported archive type" unless %w[gem zip].include?(artifact['archive'])

      packages = unit['packages']
      order = unit['install_order']
      raise Error, "unit #{unit['id']} packages must be an array" unless packages.is_a?(Array) && !packages.empty?
      raise Error, "unit #{unit['id']} install_order must be an array" unless order.is_a?(Array)
      packages.each { |package| validate_package!(package, unit['id']) }

      names = packages.map { |package| package.fetch('name') }
      unless names.uniq.length == names.length && order.sort == names.sort
        raise Error, "unit #{unit['id']} install_order must name each package exactly once"
      end
      if artifact['archive'] == 'gem' && (packages.length != 1 || packages.first['filename'] != artifact['filename'])
        raise Error, "gem unit #{unit['id']} must contain its one artifact package"
      end
    end

    # @param package [Hash]
    # @param unit_id [String]
    # @return [void]
    def validate_package!(package, unit_id)
      raise Error, "unit #{unit_id} contains an invalid package" unless package.is_a?(Hash)
      %w[name version filename sha256].each do |key|
        raise Error, "unit #{unit_id} package is missing #{key}" unless package[key].is_a?(String)
      end
      raise Error, "unit #{unit_id} package name is unsafe" unless package['name'].match?(SAFE_NAME)
      raise Error, "unit #{unit_id} package version is invalid" unless Gem::Version.correct?(package['version'])
      require_filename!(package['filename'], "unit #{unit_id} package")
      raise Error, "unit #{unit_id} package filename must end in .gem" unless package['filename'].end_with?('.gem')
      require_sha256!(package['sha256'], "unit #{unit_id} package")
    end

    # Downloads and verifies an entire unit before any runtime package is
    # changed. Native units are later handed to a detached replacement helper.
    # @param unit [Hash]
    # @param work_dir [String]
    # @return [Hash]
    def stage_unit(unit, work_dir)
      artifact = unit.fetch('artifact')
      artifact_path = File.join(work_dir, artifact.fetch('filename'))
      download_to(artifact.fetch('url'), artifact_path)
      verify_file!(artifact_path, artifact.fetch('sha256'), "unit #{unit.fetch('id')} artifact")

      package_dir = artifact_path
      if artifact.fetch('archive') == 'zip'
        package_dir = File.join(work_dir, "#{unit.fetch('id')}-packages")
        FileUtils.mkdir_p(package_dir)
        @extract_zip.call(artifact_path, package_dir)
      end

      package_paths = unit.fetch('packages').to_h do |package|
        path = artifact.fetch('archive') == 'gem' ? artifact_path : File.join(package_dir, package.fetch('filename'))
        verify_file!(path, package.fetch('sha256'), "#{package.fetch('name')} gem")
        [package.fetch('name'), path]
      end
      { unit: unit, package_paths: package_paths }
    end

    # @param staged [Hash]
    # @param force [Boolean]
    # @return [Array<String>] installed package names
    def install_staged_unit(staged, force:)
      unit = staged.fetch(:unit)
      packages = unit.fetch('packages')
      pending = force ? packages : packages.reject { |package| package_installed?(package) }
      return [] if pending.empty?

      packages_by_name = packages.to_h { |package| [package.fetch('name'), package] }
      unit.fetch('install_order').filter_map do |name|
        package = packages_by_name.fetch(name)
        next unless pending.include?(package)

        @install_gem.call(staged.fetch(:package_paths).fetch(name), @gem_home)
        name
      end
    end

    # A ZIP unit containing native gems cannot safely be overwritten while the
    # Lich Ruby process is alive. It is replaced as one coherent suite after
    # this process exits, rather than mixing old and new native components.
    # @param unit [Hash]
    # @return [Boolean]
    def native_runtime_unit?(unit)
      Gem.win_platform? && unit.fetch('packages').any? do |package|
        package.fetch('filename').end_with?("-#{Gem::Platform.local}.gem")
      end
    end

    # @param staged [Hash]
    # @param work_dir [String]
    # @return [void]
    def schedule_runtime_replacement(staged, work_dir)
      payload_path = File.join(work_dir, 'native-runtime-replacement.json')
      payload = {
        'schema'     => 1,
        'parent_pid' => Process.pid,
        'gem_home'   => @gem_home,
        'temp_dir'   => @temp_dir,
        'work_dir'   => work_dir,
        'packages'   => staged.fetch(:unit).fetch('packages').map do |package|
          package.merge('path' => staged.fetch(:package_paths).fetch(package.fetch('name')))
        end,
        'restart'    => {
          'program' => File.expand_path($PROGRAM_NAME),
          'argv'    => ARGV,
          'chdir'   => Dir.pwd
        }
      }
      File.write(payload_path, JSON.generate(payload))
      @helper_launcher.call(payload_path)
    rescue SystemCallError => e
      raise Error, "Could not start the hidden native gem replacement helper: #{e.message}"
    end

    # @param payload_path [String]
    # @return [Integer] helper process id
    def launch_windows_helper(payload_path)
      raise Error, 'native runtime replacement is only supported on Windows' unless Gem.win_platform?

      helper_path = File.join(File.dirname(payload_path), 'run-native-runtime-replacement.rb')
      File.write(helper_path, <<~RUBY)
        require #{File.expand_path(__FILE__).inspect}
        exit(Lich::DependencyRecovery.run_windows_replacement(ARGV.fetch(0)) ? 0 : 1)
      RUBY
      Process.spawn(
        rubyw_binary, helper_path, payload_path,
        chdir: Dir.pwd, out: File::NULL, err: File::NULL
      )
    end

    # @return [String] no-console Ruby executable on Windows
    def rubyw_binary
      candidate = RbConfig.ruby.sub(/ruby(?:\.exe)?\z/i, 'rubyw.exe')
      File.file?(candidate) ? candidate : RbConfig.ruby
    end

    # @param package [Hash]
    # @return [Boolean]
    def package_installed?(package)
      requirement = Gem::Requirement.new("= #{package.fetch('version')}")
      Gem::Specification.find_all_by_name(package.fetch('name'), requirement).any?
    end

    # Performs the destructive portion only after the original Ruby process is
    # gone. Every old package is moved, not deleted, until the complete new suite
    # is installed and its exact manifest versions are registered.
    # @param payload [Hash]
    # @return [void]
    def run_windows_replacement!(payload)
      validate_replacement_payload!(payload)
      wait_for_parent_exit(payload.fetch('parent_pid'))
      with_install_lock do
        rollback_dir = File.join(payload.fetch('work_dir'), 'previous-runtime')
        moved = []
        begin
          moved = backup_existing_packages(payload.fetch('packages'), rollback_dir)
          refresh_rubygems!
          payload.fetch('packages').each do |package|
            verify_file!(package.fetch('path'), package.fetch('sha256'), "#{package.fetch('name')} gem")
            @install_gem.call(package.fetch('path'), @gem_home)
          end
          verify_replacement!(payload.fetch('packages'))
          FileUtils.remove_entry(rollback_dir) if Dir.exist?(rollback_dir)
        rescue StandardError
          remove_replacement_packages(payload.fetch('packages'))
          restore_backup(moved)
          raise
        end
      end
      restart_lich(payload.fetch('restart'))
    end

    # @param payload [Hash]
    # @return [void]
    def validate_replacement_payload!(payload)
      raise Error, 'invalid native runtime replacement payload' unless payload.is_a?(Hash) && payload['schema'] == 1
      %w[parent_pid gem_home temp_dir work_dir packages restart].each do |key|
        raise Error, "native runtime replacement payload is missing #{key}" unless payload.key?(key)
      end
      raise Error, 'native runtime replacement packages must be an array' unless payload['packages'].is_a?(Array) && !payload['packages'].empty?
      raise Error, 'native runtime replacement restart data must be an object' unless payload['restart'].is_a?(Hash)
      raise Error, 'native runtime replacement restart arguments must be an array' unless payload['restart']['argv'].is_a?(Array)
      raise Error, 'native runtime replacement program is invalid' unless File.file?(payload['restart']['program'])
      raise Error, 'native runtime replacement working directory is invalid' unless Dir.exist?(payload['restart']['chdir'])
      payload['packages'].each { |package| validate_package!(package, 'native runtime replacement') }
      unless payload['packages'].all? { |package| File.file?(package['path']) && path_within?(package['path'], payload['work_dir']) }
        raise Error, 'native runtime replacement package path is unsafe'
      end
    end

    # @param pid [Integer]
    # @return [void]
    def wait_for_parent_exit(pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 120
      loop do
        Process.kill(0, Integer(pid))
        raise Error, 'timed out waiting for Lich to exit before native gem replacement' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.1
      rescue Errno::ESRCH
        return
      end
    end

    # @param packages [Array<Hash>]
    # @param rollback_dir [String]
    # @return [Array<Array<String>>] original and temporary paths
    def backup_existing_packages(packages, rollback_dir)
      names = packages.map { |package| package.fetch('name') }.uniq
      specs = names.flat_map { |name| Gem::Specification.find_all_by_name(name) }.uniq(&:loaded_from)
      specs.flat_map do |spec|
        [spec.full_gem_path, spec.loaded_from, spec.extension_dir].filter_map do |path|
          next unless File.exist?(path)
          raise Error, "installed gem path is outside Ruby runtime: #{path}" unless path_within?(path, @gem_home)

          destination = File.join(rollback_dir, path.delete_prefix(File.expand_path(@gem_home)).sub(%r{\A[\\/]}, ''))
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.mv(path, destination)
          [path, destination]
        end
      end
    end

    # @param moved [Array<Array<String>>]
    # @return [void]
    def restore_backup(moved)
      moved.reverse_each do |original, temporary|
        next unless File.exist?(temporary)

        FileUtils.mkdir_p(File.dirname(original))
        FileUtils.mv(temporary, original)
      end
      refresh_rubygems!
    end

    # @param packages [Array<Hash>]
    # @return [void]
    def remove_replacement_packages(packages)
      names = packages.map { |package| package.fetch('name') }.uniq
      names.flat_map { |name| Gem::Specification.find_all_by_name(name) }.uniq(&:loaded_from).each do |spec|
        [spec.full_gem_path, spec.loaded_from, spec.extension_dir].each do |path|
          FileUtils.remove_entry(path) if File.exist?(path) && path_within?(path, @gem_home)
        end
      end
      refresh_rubygems!
    end

    # @param packages [Array<Hash>]
    # @return [void]
    def verify_replacement!(packages)
      refresh_rubygems!
      packages.each do |package|
        requirement = Gem::Requirement.new("= #{package.fetch('version')}")
        installed = Gem::Specification.find_all_by_name(package.fetch('name'), requirement)
        raise Error, "#{package.fetch('name')} was not installed during native runtime replacement" if installed.empty?
      end
    end

    # @param restart [Hash]
    # @return [Integer]
    def restart_lich(restart)
      Process.spawn(
        rubyw_binary, restart.fetch('program'), *restart.fetch('argv'),
        chdir: restart.fetch('chdir'), out: File::NULL, err: File::NULL
      )
    rescue SystemCallError => e
      raise Error, "Could not restart Lich after native gem replacement: #{e.message}"
    end

    # @param path [String]
    # @param root [String]
    # @return [Boolean]
    def path_within?(path, root)
      expanded_path = File.expand_path(path)
      expanded_root = File.expand_path(root)
      expanded_path == expanded_root || expanded_path.start_with?("#{expanded_root}#{File::SEPARATOR}")
    end

    # @param url [String]
    # @param destination [String]
    # @return [void]
    def download_to(url, destination)
      uri = parse_https_uri!(url, 'artifact URL')
      if @http_get
        File.binwrite(destination, @http_get.call(url))
        return
      end

      uri.open('User-Agent' => 'Lich5 dependency recovery') do |remote|
        final_uri = remote.base_uri
        parse_https_uri!(final_uri.to_s, 'redirected artifact URL') if final_uri
        File.open(destination, 'wb') { |file| IO.copy_stream(remote, file) }
      end
    rescue Errno::EACCES, Errno::EROFS => e
      raise Error, "Cannot write downloaded artifact to #{destination}: #{e.message}"
    end

    # @param url [String]
    # @return [String]
    def fetch(url)
      uri = parse_https_uri!(url, 'manifest URL')
      return @http_get.call(url) if @http_get

      uri.open('User-Agent' => 'Lich5 dependency recovery') do |remote|
        final_uri = remote.base_uri
        parse_https_uri!(final_uri.to_s, 'redirected manifest URL') if final_uri
        remote.read
      end
    end

    # Installs from a verified local file. No resolver is invoked here: all
    # dependencies must appear in the manifest unit's explicit install order.
    # @param gem_path [String]
    # @param gem_home [String]
    # @return [void]
    def install_gem_file(gem_path, gem_home)
      Gem::Installer.at(gem_path, install_dir: gem_home, ignore_dependencies: true,
                        wrappers: false, force: true).install
    rescue Errno::EACCES, Errno::EROFS => e
      raise Error, "Cannot install #{File.basename(gem_path)} into #{gem_home}: #{e.message}"
    end

    # Extracts a ZIP after the outer archive was hashed. The bundle producer
    # must place declared .gem files at its archive root; package filenames are
    # constrained to prevent manifest-controlled path traversal.
    # @param zip_path [String]
    # @param destination [String]
    # @return [void]
    def extract_zip_file(zip_path, destination)
      FileUtils.mkdir_p(destination)
      if Gem.win_platform?
        script_path = File.join(File.dirname(destination), 'extract-r4l5-bundle.ps1')
        error_path = File.join(File.dirname(destination), 'extract-r4l5-bundle-error.txt')
        launcher_path = File.join(File.dirname(destination), 'extract-r4l5-bundle.vbs')
        File.write(script_path, windows_extraction_script)
        File.write(launcher_path, windows_hidden_launcher(script_path, zip_path, destination, error_path))
        stdout, stderr, status = @powershell_runner.call('wscript.exe', '//nologo', launcher_path)
        unless status.success?
          details = [(File.read(error_path) if File.file?(error_path)), stderr, stdout]
                    .compact.reject { |text| text.to_s.strip.empty? }.join("\n").strip
          details = 'no diagnostic output' if details.empty?
          raise Error, "Could not extract #{File.basename(zip_path)} into #{destination} " \
                       "(PowerShell exit #{status.exitstatus}): #{details}"
        end
      else
        entries = IO.popen(['unzip', '-Z1', zip_path], &:read).lines.map(&:strip)
        raise Error, 'archive contains an unsafe entry' if entries.any? { |entry| unsafe_archive_entry?(entry) }

        success = system('unzip', '-q', zip_path, '-d', destination)
        raise Error, "could not extract #{File.basename(zip_path)} into #{destination}" unless success
      end
    rescue Errno::EACCES, Errno::EROFS => e
      raise Error, "Cannot extract #{File.basename(zip_path)} into #{destination}: #{e.message}"
    end

    # Uses named script parameters rather than appending values after
    # PowerShell's -Command argument, where they would be parsed as command
    # text instead of reliably reaching $args. A hidden WScript launcher starts
    # PowerShell without the console flash produced by powershell.exe itself.
    # @return [String] PowerShell extraction script
    def windows_extraction_script
      <<~POWERSHELL
        param(
          [Parameter(Mandatory = $true)][string]$Archive,
          [Parameter(Mandatory = $true)][string]$Destination,
          [Parameter(Mandatory = $true)][string]$ErrorPath
        )

        try {
          $ErrorActionPreference = 'Stop'
          Add-Type -AssemblyName System.IO.Compression.FileSystem
          $archivePath = [IO.Path]::GetFullPath($Archive)
          $destinationPath = [IO.Path]::GetFullPath($Destination)
          $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
          try {
            foreach ($entry in $zip.Entries) {
              if ([IO.Path]::IsPathRooted($entry.FullName) -or $entry.FullName -match '(^|[\\/])\\.\\.([\\/]|$)') {
                throw "unsafe archive entry: $($entry.FullName)"
              }
            }
          } finally {
            $zip.Dispose()
          }
          [IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $destinationPath)
        } catch {
          $_ | Out-String | Set-Content -LiteralPath $ErrorPath
          exit 1
        }
      POWERSHELL
    end

    # @param script_path [String]
    # @param zip_path [String]
    # @param destination [String]
    # @param error_path [String]
    # @return [String]
    def windows_hidden_launcher(script_path, zip_path, destination, error_path)
      <<~VBSCRIPT
        Function Quote(value)
          Quote = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
        End Function
        Set shell = CreateObject("WScript.Shell")
        command = Quote("powershell.exe") & " -NoProfile -NonInteractive -WindowStyle Hidden -File " & Quote(#{script_path.inspect}) & " -Archive " & Quote(#{zip_path.inspect}) & " -Destination " & Quote(#{destination.inspect}) & " -ErrorPath " & Quote(#{error_path.inspect})
        WScript.Quit shell.Run(command, 0, True)
      VBSCRIPT
    end

    # @param entry [String]
    # @return [Boolean]
    def unsafe_archive_entry?(entry)
      entry.empty? || entry.start_with?('/', '\\') || entry.match?(/\A[A-Za-z]:[\\\/]/) ||
        entry.split(/[\\\/]/).include?('..')
    end

    # @param path [String]
    # @param expected [String]
    # @param label [String]
    # @return [void]
    def verify_file!(path, expected, label)
      raise Error, "#{label} is missing" unless File.file?(path)

      actual = "sha256:#{Digest::SHA256.file(path).hexdigest}"
      raise Error, "#{label} SHA-256 does not match its manifest" unless actual == expected
    end

    # @param value [Object]
    # @param label [String]
    # @return [void]
    def require_sha256!(value, label)
      raise Error, "#{label} SHA-256 is invalid" unless value.is_a?(String) && value.match?(SHA256_PATTERN)
    end

    # @param value [Object]
    # @param label [String]
    # @return [void]
    def require_filename!(value, label)
      unless value.is_a?(String) && value.match?(SAFE_FILENAME) && !value.empty?
        raise Error, "#{label} filename is unsafe"
      end
    end

    # @param value [Object]
    # @param label [String]
    # @return [URI::HTTPS] parsed, absolute HTTPS URI
    def parse_https_uri!(value, label)
      uri = URI.parse(value.to_s)
      raise Error, "#{label} must use HTTPS" unless uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty?

      uri
    rescue URI::InvalidURIError
      raise Error, "#{label} must be a valid HTTPS URL"
    end

    # @return [String] running Ruby major.minor version
    def ruby_abi
      RUBY_VERSION.split('.').first(2).join('.')
    end

    # Serializes writes across simultaneously started Lich processes.
    # @yield installation work
    # @return [Object]
    def with_install_lock
      FileUtils.mkdir_p(@gem_home)
      lock_path = File.join(@gem_home, LOCK_FILENAME)
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      ensure
        lock.flock(File::LOCK_UN) if lock
      end
    rescue Errno::EACCES, Errno::EROFS => e
      raise Error, "Cannot write Ruby runtime gem directory #{@gem_home}: #{e.message}"
    end

    # Uses Lich's own temp directory rather than the platform AppData/system
    # temp area. Cleanup is intentionally disabled while the Windows extractor
    # is being diagnosed; restore block-form Dir.mktmpdir cleanup afterward.
    # @yieldparam work_dir [String] per-recovery temporary workspace
    # @return [Object]
    def with_recovery_workspace
      if File.exist?(@temp_dir)
        raise Error, "Recovery workspace path is not a directory: #{@temp_dir}" unless Dir.exist?(@temp_dir)
      else
        FileUtils.mkdir_p(@temp_dir)
      end
      work_dir = Dir.mktmpdir('lich-gem-recovery-', @temp_dir)
      warn "Lich dependency recovery workspace retained at #{work_dir}"
      yield work_dir
    rescue Errno::EACCES, Errno::EROFS => e
      raise Error, "Cannot create recovery workspace in #{@temp_dir}: #{e.message}"
    end

    # Makes a successful local installation visible to Bundler and RubyGems in
    # this process. A restart is still the cleanest recovery for extensions
    # already partially loaded by a third-party require.
    # @return [void]
    def refresh_rubygems!
      Gem::Specification.reset
      Gem.clear_paths
      Bundler.reset! if defined?(Bundler)
    end
  end
end
