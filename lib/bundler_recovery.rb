# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'securerandom'

module Lich
  # Stages a frozen, non-GTK Bundler install on macOS and activates it only
  # after the complete bundle was installed successfully. The active bundle is
  # stored below Lich's own directory, never in the system or user GEM_HOME.
  class BundlerRecovery
    STORE_DIRNAME = '.lich-bundler-gems'
    ACTIVE_FILENAME = 'active.json'
    LOG_FILENAME = 'lich5-bundler-recovery.log'
    EXCLUDED_GROUPS = %w[gtk development vscode profanity].freeze
    NATIVE_DEFAULT_GEMS = %w[ox sqlite3].freeze

    # Result of staging and activating a Bundler recovery bundle.
    Result = Struct.new(:error, :log_path, keyword_init: true) do
      # @return [Boolean]
      def success?
        error.nil?
      end
    end

    class << self
      # @return [Boolean] whether the deliberately narrow initial recovery
      #   implementation is supported by the current runtime.
      def supported?
        RUBY_PLATFORM.match?(/darwin/)
      end

      # Activates the previously promoted private bundle, if it matches this
      # Ruby runtime. Invalid or incomplete records are ignored fail-closed.
      # @param lich_dir [String]
      # @return [Boolean]
      def activate!(lich_dir:)
        return false unless supported?

        new(lich_dir:).activate!
      end
    end

    # @param lich_dir [String] absolute Lich installation directory
    def initialize(lich_dir:)
      @lich_dir = File.expand_path(lich_dir)
    end

    # Performs non-mutating checks required to build a frozen bundle.
    # @param missing [Array<String>]
    # @return [String, nil] a user-actionable failure reason, if any
    def preflight(missing)
      return 'macOS Bundler recovery is not supported by this Ruby runtime' unless self.class.supported?
      return "Gemfile not found at #{gemfile}" unless File.file?(gemfile)
      return "Gemfile.lock not found at #{lockfile}" unless File.file?(lockfile)
      return "Ruby executable is not available at #{Gem.ruby}" unless File.executable?(Gem.ruby)
      return 'Bundler is not available from this Ruby runtime' unless command_available?(Gem.ruby, '-S', 'bundle', '--version')
      return nil unless native_default_gem_missing?(missing)

      return "Ruby development headers are not available at #{ruby_headers}" unless File.directory?(ruby_headers)
      return 'Xcode Command Line Tools are required to build native Ruby gems' unless command_available?('xcrun', '--find', 'clang')
      return 'make is required to build native Ruby gems' unless command_available?('make', '--version')

      nil
    end

    # Installs every non-excluded locked dependency into a private staging
    # bundle, then atomically promotes that bundle and activation record.
    # A failed download or native build never changes the active RubyGems path.
    # @param missing [Array<String>]
    # @return [Result]
    def recover(missing)
      if (reason = preflight(missing))
        return failure(reason)
      end

      FileUtils.mkdir_p(store_root)
      staging_path = File.join(store_root, ".staging-#{Process.pid}-#{SecureRandom.hex(8)}")
      target_id = bundle_id
      target_path = File.join(store_root, target_id)
      environment = bundler_environment(staging_path)

      stdout, stderr, status = Open3.capture3(
        environment, Gem.ruby, '-S', 'bundle', 'install', chdir: @lich_dir
      )
      transcript = "#{stdout}#{stderr}"
      write_transcript(transcript, status.success?)

      return failure("Bundler install failed (see #{log_path})") unless status.success?
      return failure("Bundler did not create its staged gem home (see #{log_path})") unless File.directory?(gem_home(staging_path))

      File.rename(staging_path, target_path)
      write_active_record(target_id)
      Result.new(log_path: log_path)
    rescue StandardError => e
      failure("#{e.class}: #{e.message}")
    ensure
      FileUtils.rm_rf(staging_path) if defined?(staging_path) && File.exist?(staging_path)
    end

    # Activates a prior bundle for the current process without calling
    # Bundler.setup. RubyGems discovers specifications in the private bundle
    # just as it does from the runtime's normal gem paths.
    # @return [Boolean]
    def activate!
      record = read_active_record
      return false unless compatible_record?(record)

      home = gem_home(File.join(store_root, record.fetch('bundle_id')))
      return false unless File.directory?(home)

      original_home = Gem.dir
      Gem.use_paths(original_home, [original_home, home, *Gem.path].uniq)
      Gem::Specification.reset
      true
    rescue StandardError
      false
    end

    private

    # @return [String]
    def gemfile
      File.join(@lich_dir, 'Gemfile')
    end

    # @return [String]
    def lockfile
      File.join(@lich_dir, 'Gemfile.lock')
    end

    # @return [String]
    def store_root
      File.join(@lich_dir, STORE_DIRNAME)
    end

    # @return [String]
    def active_record_path
      File.join(store_root, ACTIVE_FILENAME)
    end

    # @return [String]
    def log_path
      temp_dir = defined?(TEMP_DIR) ? TEMP_DIR : File.join(@lich_dir, 'temp')
      File.join(temp_dir, LOG_FILENAME)
    end

    # @return [String]
    def ruby_api
      RbConfig::CONFIG.fetch('ruby_version')
    end

    # @param bundle_path [String]
    # @return [String]
    def gem_home(bundle_path)
      File.join(bundle_path, 'ruby', ruby_api)
    end

    # @return [String]
    def bundle_id
      runtime = "#{RUBY_ENGINE}-#{ruby_api}-#{RUBY_PLATFORM}".gsub(/[^A-Za-z0-9._-]/, '_')
      digest = Digest::SHA256.file(lockfile).hexdigest[0, 16]
      "#{runtime}-#{digest}-#{SecureRandom.hex(4)}"
    end

    # @param missing [Array<String>]
    # @return [Boolean]
    def native_default_gem_missing?(missing)
      (Array(missing) & NATIVE_DEFAULT_GEMS).any?
    end

    # @return [String]
    def ruby_headers
      RbConfig::CONFIG.fetch('rubyhdrdir')
    end

    # @param command [String]
    # @param arguments [Array<String>]
    # @return [Boolean]
    def command_available?(command, *arguments)
      _stdout, _stderr, status = Open3.capture3(command, *arguments)
      status.success?
    rescue StandardError
      false
    end

    # @param staging_path [String]
    # @return [Hash<String, String, nil>]
    def bundler_environment(staging_path)
      existing_without = ENV.fetch('BUNDLE_WITHOUT', '').split(/[:\s]+/)
      {
        'BUNDLE_FROZEN'     => 'true',
        'BUNDLE_GEMFILE'    => gemfile,
        'BUNDLE_PATH'       => staging_path,
        'BUNDLE_WITH'       => nil,
        'BUNDLE_WITHOUT'    => (existing_without + EXCLUDED_GROUPS).reject(&:empty?).uniq.join(':'),
        'BUNDLE_DEPLOYMENT' => nil
      }
    end

    # @param target_id [String]
    # @return [void]
    def write_active_record(target_id)
      record = {
        'schema'      => 1,
        'bundle_id'   => target_id,
        'ruby_api'    => ruby_api,
        'ruby_engine' => RUBY_ENGINE,
        'platform'    => RUBY_PLATFORM
      }
      temporary_path = "#{active_record_path}.tmp-#{Process.pid}-#{SecureRandom.hex(4)}"
      File.write(temporary_path, JSON.generate(record))
      File.rename(temporary_path, active_record_path)
    ensure
      FileUtils.rm_f(temporary_path) if defined?(temporary_path)
    end

    # @return [Hash, nil]
    def read_active_record
      return unless File.file?(active_record_path)

      JSON.parse(File.read(active_record_path))
    rescue JSON::ParserError
      nil
    end

    # @param record [Hash, nil]
    # @return [Boolean]
    def compatible_record?(record)
      return false unless record.is_a?(Hash)
      return false unless record['schema'] == 1
      return false unless record['ruby_api'] == ruby_api && record['ruby_engine'] == RUBY_ENGINE
      return false unless record['platform'] == RUBY_PLATFORM

      record['bundle_id'].is_a?(String) && record['bundle_id'].match?(/\A[A-Za-z0-9._-]+\z/)
    end

    # @param transcript [String]
    # @param success [Boolean]
    # @return [void]
    def write_transcript(transcript, success)
      FileUtils.mkdir_p(File.dirname(log_path))
      File.open(log_path, 'a') do |file|
        file.puts "[#{Time.now}] macOS Bundler recovery #{success ? 'succeeded' : 'failed'}"
        file.puts "  Gemfile: #{gemfile}"
        file.puts "  Lockfile: #{lockfile}"
        file.puts "  Excluded groups: #{EXCLUDED_GROUPS.join(', ')}"
        file.puts transcript
        file.puts
      end
    rescue StandardError
      nil
    end

    # @param message [String]
    # @return [Result]
    def failure(message)
      write_transcript(message, false)
      Result.new(error: message, log_path: log_path)
    end
  end
end
