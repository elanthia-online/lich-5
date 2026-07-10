# lib/dependency_recovery.rb
require 'digest'
require 'fileutils'
require 'json'
require 'open-uri'
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
    SAFE_FILENAME = /\A[^\\\/]+\z/
    SAFE_NAME = /\A[a-zA-Z0-9_.-]+\z/

    # @return [String] result of a successful or unsuccessful recovery attempt
    Result = Struct.new(:installed_gems, :error, keyword_init: true) do
      # @return [Boolean] whether recovery completed successfully
      def success?
        error.nil?
      end
    end

    # Raised internally for malformed manifests and rejected artifacts.
    class Error < StandardError; end

    # @param manifest_url [String] HTTPS manifest location
    # @param gem_home [String] runtime-owned installation directory
    # @param http_get [#call, nil] test seam returning binary response content
    # @param install_gem [#call, nil] test seam for local gem installation
    # @param extract_zip [#call, nil] test seam for zip extraction
    def initialize(manifest_url: ENV.fetch('LICH_GEM_MANIFEST_URL', DEFAULT_MANIFEST_URL),
                   gem_home: Gem.dir, http_get: nil, install_gem: nil, extract_zip: nil)
      @manifest_url = manifest_url
      @gem_home = gem_home
      @http_get = http_get
      @install_gem = install_gem || method(:install_gem_file)
      @extract_zip = extract_zip || method(:extract_zip_file)
    end

    # Downloads, verifies, and installs the manifest units covering +gem_names+.
    # Installation always targets +Gem.dir+ (or the injected runtime directory),
    # never a user-controlled GEM_HOME.
    #
    # @param gem_names [Array<String>] approved gem names to restore
    # @param force [Boolean] reinstall even when the manifest version is present
    # @return [Result]
    def recover(gem_names, force: false)
      requested = Array(gem_names).map(&:to_s).reject(&:empty?).uniq
      return Result.new(installed_gems: []) if requested.empty?

      manifest = load_manifest
      units = units_for(manifest, requested)
      installed = with_install_lock do
        Dir.mktmpdir('lich-gem-recovery') do |work_dir|
          units.flat_map { |unit| install_unit(unit, work_dir, force: force) }
        end
      end
      refresh_rubygems!
      Result.new(installed_gems: installed)
    rescue Error, JSON::ParserError, OpenURI::HTTPError, SocketError, SystemCallError => e
      Result.new(installed_gems: [], error: e.message)
    rescue StandardError => e
      # Recovery runs during boot. Keep an unexpected implementation failure
      # from turning into an unhelpful backtrace before GemCheck can report it.
      Result.new(installed_gems: [], error: "#{e.class}: #{e.message}")
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

    # @param unit [Hash]
    # @param work_dir [String]
    # @param force [Boolean]
    # @return [Array<String>] installed package names
    def install_unit(unit, work_dir, force:)
      packages = unit.fetch('packages')
      pending = force ? packages : packages.reject { |package| package_installed?(package) }
      return [] if pending.empty?

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

      packages_by_name = packages.to_h { |package| [package.fetch('name'), package] }
      unit.fetch('install_order').filter_map do |name|
        package = packages_by_name.fetch(name)
        next unless force || pending.include?(package)

        gem_path = artifact.fetch('archive') == 'gem' ? artifact_path : File.join(package_dir, package.fetch('filename'))
        verify_file!(gem_path, package.fetch('sha256'), "#{name} gem")
        @install_gem.call(gem_path, @gem_home)
        name
      end
    end

    # @param package [Hash]
    # @return [Boolean]
    def package_installed?(package)
      requirement = Gem::Requirement.new("= #{package.fetch('version')}")
      Gem::Specification.find_all_by_name(package.fetch('name'), requirement).any?
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
        script = <<~POWERSHELL
          Add-Type -AssemblyName System.IO.Compression.FileSystem
          $archive = $args[0]
          $destination = [IO.Path]::GetFullPath($args[1])
          $zip = [IO.Compression.ZipFile]::OpenRead($archive)
          try {
            foreach ($entry in $zip.Entries) {
              if ([IO.Path]::IsPathRooted($entry.FullName) -or $entry.FullName -match '(^|[\\/])\\.\\.([\\/]|$)') {
                throw "unsafe archive entry: $($entry.FullName)"
              }
            }
          } finally {
            $zip.Dispose()
          }
          [IO.Compression.ZipFile]::ExtractToDirectory($archive, $destination)
        POWERSHELL
        success = system('powershell.exe', '-NoProfile', '-NonInteractive', '-Command', script, zip_path, destination)
      else
        entries = IO.popen(['unzip', '-Z1', zip_path], &:read).lines.map(&:strip)
        raise Error, 'archive contains an unsafe entry' if entries.any? { |entry| unsafe_archive_entry?(entry) }

        success = system('unzip', '-q', zip_path, '-d', destination)
      end
      raise Error, "could not extract #{File.basename(zip_path)}" unless success
    end

    # @param entry [String]
    # @return [Boolean]
    def unsafe_archive_entry?(entry)
      entry.empty? || entry.start_with?('/', '\\') || entry.split(/[\\\/]/).include?('..')
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
