# frozen_string_literal: true

=begin
  SetupFiles manages YAML configuration file loading, caching, and
  cascading merge for lich scripts.

  Supports:
  - Base YAML files (base.yaml, base-empty.yaml)
  - Character-specific YAML files ({character}-setup.yaml)
  - Include files with recursive resolution and circular dependency protection
  - Automatic caching with modification-time checking
  - Deep-clone protection against in-memory mutation

  @see https://elanthipedia.play.net/Lich_script_development#dependency
=end

require 'monitor'
require 'ostruct'
require 'set' # rubocop:disable Lint/RedundantRequireStatement -- needed for Ruby < 3.2
require 'yaml'

module Lich
  module Common
    CORE_SETUPFILES = true

    class SetupFiles
      include MonitorMixin

      class FileInfo
        attr_reader :path, :name, :mtime

        def initialize(path:, name:, data:, mtime:)
          @path = path
          @name = name
          @data = data
          @mtime = mtime
        end

        # Deep clone of data to prevent scripts from mutating cached settings.
        def data
          Marshal.load(Marshal.dump(@data))
        end

        # Efficient deep clone of a single property.
        def peek(property)
          Marshal.load(Marshal.dump(@data[property.to_sym]))
        end

        def to_s
          File.join(@path, @name)
        end

        def inspect
          "#<SetupFiles::FileInfo @name=#{@name}, @path=#{@path}, @mtime=#{@mtime}>"
        end
      end

      def initialize(debug = false)
        super()
        @files_cache = {}
        @debug = debug
      end

      def safe_load_yaml(filepath)
        OpenStruct.new(YAML.unsafe_load_file(filepath)).to_h
      rescue => e
        Lich::Messaging.msg("bold", "*** ERROR PARSING YAML FILE ***")
        Lich::Messaging.msg("bold", e.message)
        {}
      end

      # Returns your character's settings.
      #
      # @param character_suffixes [Array<String>] additional profile suffixes to load
      # @return [OpenStruct] merged and transformed settings
      def get_settings(character_suffixes = [])
        character_suffixes = ['setup', character_suffixes].flatten.compact.uniq
        character_filenames = character_suffixes_to_filenames(character_suffixes)
        reload_profiles(character_filenames)

        initial_include_suffixes = character_filenames.reduce([]) do |result, filename|
          result + (cache_get_by_filename(filename)&.peek('include') || [])
        end
        initial_include_filenames = initial_include_suffixes.map { |suffix| to_include_filename(suffix) }
        include_filenames = resolve_includes_recursively(initial_include_filenames)
        Lich.log "#{self.class}::#{__callee__} resolved include_filenames=#{include_filenames}" if @debug

        all_files = ['base.yaml', 'base-empty.yaml', include_filenames, character_filenames].flatten

        # Peek pass: collect union_keys from all files (always unioned across files).
        # Keys listed in union_keys get array union instead of overwrite during merge,
        # allowing includes and character files to contribute to shared lists.
        union_keys = all_files.reduce([]) do |keys, filename|
          file_keys = cache_get_by_filename(filename)&.peek('union_keys') || []
          (keys + file_keys).uniq
        end

        # Merge pass: union specified keys, overwrite everything else
        settings = all_files.reduce({}) do |result, filename|
          file_info = cache_get_by_filename(filename)
          result.merge(file_info ? file_info.data : {}) do |key, old_val, new_val|
            if union_keys.include?(key.to_s) && old_val.is_a?(Array) && new_val.is_a?(Array)
              (old_val + new_val).uniq
            else
              new_val
            end
          end
        end

        transform_settings(settings)
      end

      # Returns the config in a 'scripts/data/base-{type}.yaml' file.
      #
      # @param type [String] the data file type (e.g. 'spells', 'town')
      # @return [OpenStruct] data from base-{type}.yaml
      def get_data(type)
        filename = to_base_filename(type)
        reload_data([filename])
        transform_data(cache_get_by_filename(filename)&.data)
      end

      # Reloads cached files that have changed on disk.
      def reload
        reload_profiles(character_suffixes_to_filenames(['setup']))
        reload_data
      end

      private

      # Lazy memoized path.
      def scripts_data_path
        @scripts_data_path ||= File.join(SCRIPT_DIR, 'data')
      end

      # Returns the character name for filename construction.
      # Prefers Account.character (available from authentication, before XML stream)
      # with fallback to checkname (XMLData.name, available after XML stream starts).
      #
      # @return [String] character name
      def character_name
        name = defined?(Lich::Common::Account) && Lich::Common::Account.character
        name || checkname
      end

      # Lazy memoized path -- supports game-instance-specific profile directories.
      def scripts_profiles_path
        @scripts_profiles_path ||= begin
          game = defined?(XMLData) && XMLData.respond_to?(:game) && XMLData.game
          if game && defined?(DATA_DIR) &&
             File.exist?(File.join(DATA_DIR, game, "base.yaml")) &&
             File.exist?(File.join(DATA_DIR, game, "base-empty.yaml")) &&
             File.exist?(File.join(DATA_DIR, game, "#{character_name}-setup.yaml"))
            Lich::Messaging.msg("info", "Detected game instance-specific files. Loading settings from #{File.join(DATA_DIR, game)}")
            File.join(DATA_DIR, game)
          else
            File.join(SCRIPT_DIR, 'profiles')
          end
        end
      end

      def reload_profiles(filenames = [])
        load_files(get_profiles_glob_patterns(filenames))
      end

      def reload_data(filenames = [])
        load_files(get_data_glob_patterns(filenames))
      end

      def get_profiles_glob_patterns(filenames = [])
        get_glob_patterns(scripts_profiles_path, filenames)
      end

      def get_data_glob_patterns(filenames = [])
        get_glob_patterns(scripts_data_path, filenames)
      end

      def get_glob_patterns(basepath = '.', filenames = [])
        filenames = ["base*.yaml", "include*.yaml", filenames].flatten.compact.uniq
        filenames.map { |filename| File.join(basepath, File.basename(filename)) }
      end

      def character_suffixes_to_filenames(character_suffixes)
        character_suffixes.map { |suffix| to_character_filename(suffix) }
      end

      def to_character_filename(suffix)
        "#{character_name}-#{suffix}.yaml"
      end

      def to_base_filename(suffix)
        "base-#{suffix}.yaml"
      end

      def to_include_filename(suffix)
        "include-#{suffix}.yaml"
      end

      # Recursively resolves include files with circular dependency protection.
      #
      # @param filenames [Array<String>] initial include filenames to resolve
      # @param visited [Set] tracks visited files
      # @param include_order [Array<String>] accumulates ordered includes
      # @return [Array<String>] ordered list (deepest dependencies first)
      def resolve_includes_recursively(filenames, visited = Set.new, include_order = [])
        filenames.each do |filename|
          next if visited.include?(filename)

          visited << filename
          reload_profiles([filename])
          file_info = cache_get_by_filename(filename)
          next unless file_info

          nested_suffixes = file_info.peek('include') || []
          Lich.log "#{self.class}::#{__callee__} #{filename} has nested includes: #{nested_suffixes}" if @debug && !nested_suffixes.empty?
          nested_filenames = nested_suffixes.map { |suffix| to_include_filename(suffix) }

          resolve_includes_recursively(nested_filenames, visited, include_order)
          include_order << filename
        end
        include_order
      end

      def load_files(glob_patterns = [])
        synchronize do
          Lich.log "#{self.class}::#{__callee__} glob_patterns=#{glob_patterns}" if @debug
          # Build a map of filename -> filepath for all files currently on disk
          current_files = {}
          glob_patterns.each do |glob_pattern|
            Dir.glob(glob_pattern)
               .select { |filepath| File.file?(filepath) }
               .each { |filepath| current_files[File.basename(filepath)] ||= filepath }
          end

          # Evict cache entries whose backing files no longer exist on disk.
          # Only remove entries whose path matches the directories being scanned
          # AND whose name matches our glob patterns. This prevents a data-dir
          # reload from evicting identically-named profile-dir entries.
          scan_dirs = glob_patterns.map { |p| File.dirname(p) }.uniq
          @files_cache.delete_if do |name, info|
            scan_dirs.include?(info.path) &&
              !current_files.key?(name) &&
              glob_patterns.any? { |p| File.fnmatch(File.basename(p), name) }
          end

          current_files.each do |filename, filepath|
            last_modified_date = File.mtime(filepath)
            cached_file = cache_get_by_filename(filename)
            Lich.log "#{self.class}::#{__callee__} filepath=#{filepath}, last_modified_date=#{last_modified_date}, cached_file=#{cached_file.inspect}" if @debug
            if cached_file.nil? || cached_file.mtime != last_modified_date
              cache_put_by_filepath(filepath)
            end
          end
        end
      end

      def cache_put_by_filepath(filepath)
        synchronize do
          Lich.log "#{self.class}::#{__callee__} filepath=#{filepath}" if @debug
          @files_cache[File.basename(filepath)] = FileInfo.new(
            path: File.dirname(filepath),
            name: File.basename(filepath),
            mtime: File.mtime(filepath),
            data: safe_load_yaml(filepath)
          )
        end
      end

      def cache_get_by_filename(filename)
        Lich.log "#{self.class}::#{__callee__} filename=#{filename}" if @debug
        @files_cache[filename]
      end

      # Delegates to SettingsTransformer with game-specific config if available.
      def transform_settings(settings)
        Lich.log "#{self.class}::#{__callee__}" if @debug
        if defined?(Lich::DragonRealms::SettingsConfig)
          config = Lich::DragonRealms::SettingsConfig::TRANSFORM_CONFIG
          Lich::Common::SettingsTransformer.transform(settings, config, method(:get_data))
        else
          OpenStruct.new(settings)
        end
      end

      def transform_data(original_data)
        Lich.log "#{self.class}::#{__callee__}" if @debug
        data = OpenStruct.new(original_data)
        data
      rescue => e
        Lich::Messaging.msg("bold", "*** ERROR MODIFYING DATA ***")
        Lich::Messaging.msg("bold", e.message)
        e.backtrace.each { |msg| Lich::Messaging.msg("bold", msg) }
        OpenStruct.new
      end
    end
  end
end
