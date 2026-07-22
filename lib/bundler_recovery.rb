# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'rubygems/installer'
require 'tmpdir'

module Lich
  # Recovers missing non-GTK runtime gems on macOS. Bundler resolves and builds
  # in Lich's temporary directory first. A detached helper then promotes only
  # the missing gems and their unavailable runtime dependencies into Gem.dir,
  # rolling back every touched gem if validation fails.
  class BundlerRecovery
    LOG_FILENAME = 'lich5-bundler-recovery.log'
    LOCK_FILENAME = '.lich-bundler-recovery.lock'
    EXCLUDED_GROUPS = %w[gtk development vscode profanity].freeze
    NATIVE_DEFAULT_GEMS = %w[ox sqlite3].freeze

    Result = Struct.new(:error, :log_path, :restart_required, keyword_init: true) do
      def success?
        error.nil?
      end
    end

    class << self
      def supported?
        RUBY_PLATFORM.match?(/darwin/)
      end

      # Runs after the Lich process exits. The helper owns promotion, rollback,
      # cleanup, and restart so the running Ruby never changes its own gems.
      def run_macos_replacement(payload_path)
        payload = nil
        payload = JSON.parse(File.read(payload_path))
        new(lich_dir: payload.fetch('lich_dir'), gem_home: payload.fetch('gem_home'))
          .send(:run_macos_replacement!, payload, payload_path: payload_path)
        true
      rescue StandardError => e
        log_helper_failure(payload || payload_path, e)
        false
      end

      def log_helper_failure(payload_or_path, error)
        payload = helper_payload(payload_or_path)
        path = File.join(payload.fetch('temp_dir', helper_temp_dir(payload_or_path)), LOG_FILENAME)
        File.open(path, 'a') { |file| file.puts("[#{Time.now}] macOS gem promotion failed\n  #{error.class}: #{error.message}\n") }
      rescue StandardError
        nil
      end

      private

      def helper_payload(payload_or_path)
        return payload_or_path if payload_or_path.is_a?(Hash)

        JSON.parse(File.read(payload_or_path))
      rescue StandardError
        {}
      end

      def helper_temp_dir(payload_or_path)
        return Dir.tmpdir unless payload_or_path.is_a?(String)

        File.dirname(File.dirname(File.expand_path(payload_or_path)))
      rescue StandardError
        Dir.tmpdir
      end
    end

    def initialize(lich_dir:, gem_home: Gem.dir, helper_launcher: nil, installer: nil)
      @lich_dir = File.expand_path(lich_dir)
      @gem_home = File.expand_path(gem_home)
      @helper_launcher = helper_launcher || method(:launch_macos_helper)
      @installer = installer || method(:install_gem)
    end

    def preflight(missing)
      return 'macOS Bundler recovery is not supported by this Ruby runtime' unless self.class.supported?
      return "Gemfile not found at #{gemfile}" unless File.file?(gemfile)
      return "Ruby executable is not available at #{Gem.ruby}" unless File.executable?(Gem.ruby)
      return 'Bundler is not available from this Ruby runtime' unless command_available?(Gem.ruby, '-S', 'bundle', '--version')
      return nil unless (Array(missing) & NATIVE_DEFAULT_GEMS).any?

      return "Ruby development headers are not available at #{ruby_headers}" unless File.directory?(ruby_headers)
      return 'Xcode Command Line Tools are required to build native Ruby gems' unless command_available?('xcrun', '--find', 'clang')
      return 'make is required to build native Ruby gems' unless command_available?('make', '--version')

      nil
    end

    # Stages a complete resolver result, but promotes only the requested gems
    # and runtime dependencies not already satisfiable in the real Gem.dir.
    def recover(missing)
      reason = preflight(missing)
      return failure(reason) if reason

      FileUtils.mkdir_p(temp_dir)
      work_dir = Dir.mktmpdir('lich-bundler-recovery-', temp_dir)
      staging_path = File.join(work_dir, 'staging')
      staged_gemfile, frozen = stage_gemfile_files(staging_path)
      stdout, stderr, status = Open3.capture3(bundler_environment(staging_path, staged_gemfile, frozen: frozen),
                                              Gem.ruby, '-S', 'bundle', 'install', chdir: @lich_dir)
      transcript = "#{stdout}#{stderr}"
      write_transcript(transcript, status.success?)
      return failure("Bundler install failed (see #{log_path})") unless status.success?

      packages = promotion_packages(missing, staging_path)
      payload_path = File.join(work_dir, 'macos-gem-promotion.json')
      File.write(payload_path, JSON.generate(promotion_payload(work_dir, packages)))
      @helper_launcher.call(payload_path)
      work_dir = nil # The helper cleans its verified staging data after promotion.
      Result.new(log_path: log_path, restart_required: true)
    rescue StandardError => e
      failure("#{e.class}: #{e.message}")
    ensure
      FileUtils.rm_rf(work_dir) if defined?(work_dir) && work_dir && Dir.exist?(work_dir)
    end

    private

    def gemfile = File.join(@lich_dir, 'Gemfile')
    def lockfile = File.join(@lich_dir, 'Gemfile.lock')
    def temp_dir = defined?(TEMP_DIR) ? TEMP_DIR : File.join(@lich_dir, 'temp')
    def log_path = File.join(temp_dir, LOG_FILENAME)
    def ruby_headers = RbConfig::CONFIG.fetch('rubyhdrdir')
    def ruby_api = RbConfig::CONFIG.fetch('ruby_version')
    def staged_home(staging_path) = File.join(staging_path, 'ruby', ruby_api)
    def staged_lockfile(staging_path) = File.join(staging_path, 'Gemfile.lock')

    def command_available?(command, *arguments)
      _stdout, _stderr, status = Open3.capture3(command, *arguments)
      status.success?
    rescue StandardError
      false
    end

    def stage_gemfile_files(staging_path)
      FileUtils.mkdir_p(staging_path)
      staged_gemfile = File.join(staging_path, 'Gemfile')
      FileUtils.cp(gemfile, staged_gemfile)
      frozen = File.file?(lockfile)
      FileUtils.cp(lockfile, staged_lockfile(staging_path)) if frozen
      [staged_gemfile, frozen]
    end

    def bundler_environment(staging_path, staged_gemfile, frozen:)
      existing_without = ENV.fetch('BUNDLE_WITHOUT', '').split(/[:\s]+/)
      {
        'BUNDLE_FROZEN' => frozen ? 'true' : 'false', 'BUNDLE_GEMFILE' => staged_gemfile,
        'BUNDLE_PATH' => staging_path, 'BUNDLE_WITH' => nil,
        'BUNDLE_WITHOUT' => (existing_without + EXCLUDED_GROUPS).reject(&:empty?).uniq.join(':'),
        'BUNDLE_DEPLOYMENT' => 'false'
      }
    end

    def promotion_packages(missing, staging_path)
      home = staged_home(staging_path)
      raise 'Bundler did not create its staged gem home' unless File.directory?(home)

      specs = Dir.glob(File.join(home, 'specifications', '*.gemspec')).filter_map { |path| Gem::Specification.load(path) }
      by_name = specs.group_by(&:name)
      selected = Array(missing).uniq.map { |name| select_staged_spec(by_name, name, Gem::Requirement.default) }
      queue = selected.dup
      until queue.empty?
        spec = queue.shift
        spec.runtime_dependencies.each do |dependency|
          next if runtime_specs(dependency.name).any? { |installed| dependency.match?(installed) }

          candidate = select_staged_spec(by_name, dependency.name, dependency.requirement)
          next if selected.any? { |chosen| chosen.full_name == candidate.full_name }

          selected << candidate
          queue << candidate
        end
      end
      selected.map do |spec|
        archive = File.join(home, 'cache', spec.file_name)
        raise "Bundler did not cache #{spec.full_name}" unless File.file?(archive)

        { 'name' => spec.name, 'version' => spec.version.to_s, 'full_name' => spec.full_name, 'path' => archive }
      end
    end

    def select_staged_spec(by_name, name, requirement)
      spec = Array(by_name[name]).find { |candidate| requirement.satisfied_by?(candidate.version) }
      raise "Bundler did not stage a compatible #{name} gem" unless spec

      spec
    end

    # Limits the closure decision to the Ruby that runs Lich, never GEM_PATH.
    def canonical_specs(name)
      Dir.glob(File.join(@gem_home, 'specifications', "#{name}-*.gemspec")).filter_map { |path| Gem::Specification.load(path) }
    end

    # Bundled/default gems can reside outside Gem.dir when GEM_HOME is set.
    # They are valid runtime dependencies, but never promotion targets: the
    # helper only writes, backs up, and validates packages under @gem_home.
    def runtime_specs(name)
      [@gem_home, Gem.default_dir].uniq.flat_map do |root|
        Dir.glob(File.join(root, 'specifications', "#{name}-*.gemspec")).filter_map { |path| Gem::Specification.load(path) }
      end
    end

    def promotion_payload(work_dir, packages)
      {
        'schema' => 1, 'parent_pid' => Process.pid, 'lich_dir' => @lich_dir,
        'gem_home' => @gem_home, 'temp_dir' => temp_dir, 'work_dir' => work_dir,
        'packages' => packages, 'restart' => { 'program' => File.join(@lich_dir, 'lich.rbw'), 'argv' => ARGV, 'chdir' => @lich_dir }
      }
    end

    def launch_macos_helper(payload_path)
      helper_path = File.join(File.dirname(payload_path), 'run-macos-gem-promotion.rb')
      File.write(helper_path, "require #{File.expand_path(__FILE__).inspect}\nexit(Lich::BundlerRecovery.run_macos_replacement(ARGV.fetch(0)) ? 0 : 1)\n")
      File.open(log_path, 'a') do |log|
        Process.spawn(Gem.ruby, helper_path, payload_path, chdir: @lich_dir, out: File::NULL, err: log)
      end
    end

    def run_macos_replacement!(payload, payload_path:)
      cleanup_target = validate_payload!(payload, payload_path)
      wait_for_parent_exit(payload.fetch('parent_pid'))
      with_install_lock do
        rollback = File.join(cleanup_target, 'rollback')
        begin
          backup_existing_packages(payload.fetch('packages'), rollback)
        rescue StandardError
          begin
            restore_backup(rollback)
          rescue StandardError
            # Preserve the backup failure as the actionable recovery error.
          end
          raise
        end
        begin
          payload.fetch('packages').each { |package| @installer.call(package.fetch('path')) }
          verify_packages!(payload.fetch('packages'))
        rescue StandardError
          remove_packages(payload.fetch('packages'))
          restore_backup(rollback)
          raise
        end
      end
      restart_lich(payload.fetch('restart'))
    ensure
      FileUtils.rm_rf(cleanup_target) if defined?(cleanup_target) && cleanup_target
    end

    def validate_payload!(payload, payload_path)
      required = %w[parent_pid lich_dir gem_home temp_dir work_dir packages restart]
      raise 'invalid macOS gem promotion payload' unless payload.is_a?(Hash) && payload['schema'] == 1 && required.all? { |key| payload.key?(key) }
      raise 'invalid macOS gem promotion package list' unless payload['packages'].is_a?(Array) && !payload['packages'].empty?
      workspace = File.dirname(File.expand_path(payload_path))
      raise 'invalid macOS gem promotion workspace' unless File.expand_path(payload.fetch('work_dir')) == workspace
      payload['packages'].each do |package|
        %w[name version full_name path].each { |key| package.fetch(key) }
        path = File.expand_path(package.fetch('path'))
        raise 'unsafe staged gem package' unless File.file?(path) && path.start_with?("#{workspace}/")
      end
      workspace
    end

    def wait_for_parent_exit(pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 120
      loop do
        Process.kill(0, Integer(pid))
        raise 'timed out waiting for Lich to exit before gem promotion' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.1
      rescue Errno::ESRCH
        return
      end
    end

    def with_install_lock
      FileUtils.mkdir_p(@gem_home)
      File.open(File.join(@gem_home, LOCK_FILENAME), File::RDWR | File::CREAT, 0o600) { |lock| lock.flock(File::LOCK_EX); yield }
    end

    def install_gem(path)
      Gem::Installer.at(path, install_dir: @gem_home, ignore_dependencies: true, wrappers: false).install
    end

    def backup_existing_packages(packages, rollback)
      exact_specs(packages).each do |spec|
        package_paths(spec).each { |path| move_to_backup(path, rollback) }
      end
    end

    def package_paths(spec)
      [spec.full_gem_path, spec.loaded_from, spec.extension_dir, File.join(@gem_home, 'cache', spec.file_name)]
        .select { |path| File.exist?(path) && path.start_with?("#{@gem_home}/") }
    end

    def move_to_backup(path, rollback)
      relative = path.delete_prefix("#{@gem_home}/")
      destination = File.join(rollback, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.mv(path, destination)
    end

    def remove_packages(packages)
      exact_specs(packages).each do |spec|
        package_paths(spec).each { |path| FileUtils.rm_rf(path) }
      end
    end

    def restore_backup(rollback)
      Dir.glob(File.join(rollback, '**', '*'), File::FNM_DOTMATCH).sort_by(&:length).reverse_each do |path|
        next if File.directory?(path)

        relative = path.delete_prefix("#{rollback}/")
        destination = File.join(@gem_home, relative)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.mv(path, destination)
      end
    end

    def verify_packages!(packages)
      Gem::Specification.reset
      Gem.use_paths(@gem_home, [@gem_home, Gem.default_dir].uniq)
      packages.each do |package|
        requirement = Gem::Requirement.new("= #{package.fetch('version')}")
        installed = canonical_specs(package.fetch('name'))
        exact = installed.find { |spec| spec.full_name == package.fetch('full_name') && requirement.satisfied_by?(spec.version) }
        raise "#{package.fetch('full_name')} was not installed" unless exact
      end
      packages.select { |package| NATIVE_DEFAULT_GEMS.include?(package.fetch('name')) }.each { |package| require package.fetch('name') }
    end

    def exact_specs(packages)
      packages.flat_map do |package|
        canonical_specs(package.fetch('name')).select { |spec| spec.full_name == package.fetch('full_name') }
      end.uniq(&:loaded_from)
    end

    def restart_lich(restart)
      raise 'invalid Lich restart program' unless File.file?(restart.fetch('program'))

      Process.spawn(Gem.ruby, restart.fetch('program'), *restart.fetch('argv'), chdir: restart.fetch('chdir'), out: File::NULL, err: File::NULL)
    end

    def write_transcript(transcript, success)
      FileUtils.mkdir_p(File.dirname(log_path))
      File.open(log_path, 'a') do |file|
        file.puts "[#{Time.now}] macOS Bundler recovery #{success ? 'staged' : 'failed'}"
        file.puts "  Gemfile: #{gemfile}"
        file.puts "  Lockfile: #{File.file?(lockfile) ? 'staged from release' : 'resolved in staging'}"
        file.puts "  Excluded groups: #{EXCLUDED_GROUPS.join(', ')}"
        file.puts transcript
        file.puts
      end
    rescue StandardError
      nil
    end

    def failure(message)
      write_transcript(message, false)
      Result.new(error: message, log_path: log_path)
    end
  end
end
