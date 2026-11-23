# frozen_string_literal: true

=begin
  SetupFiles manages YAML configuration file loading, caching, and
  cascading merge for lich scripts.

  Supports:
  - Base YAML files (base.yaml, base-empty.yaml)
  - Character-specific YAML files ({character}-setup.yaml)
  - Include files with recursive resolution and circular dependency protection
  - Automatic caching with content-hash freshness checking
  - Deep-clone protection against in-memory mutation

  @see https://elanthipedia.play.net/Lich_script_development#dependency
=end

require 'digest'
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
        # Attempts at a deep clone before a transient iteration error propagates.
        DEEP_COPY_ATTEMPTS = 3

        attr_reader :path, :name, :mtime, :digest

        def initialize(path:, name:, data:, mtime:, digest: nil)
          @path = path
          @name = name
          @data = data
          @mtime = mtime
          @digest = digest
        end

        # Deep clone of data to prevent scripts from mutating cached settings.
        def data
          deep_copy(@data)
        end

        # Efficient deep clone of a single property.
        def peek(property)
          deep_copy(@data[property.to_sym])
        end

        def to_s
          File.join(@path, @name)
        end

        def inspect
          "#<SetupFiles::FileInfo @name=#{@name}, @path=#{@path}, @mtime=#{@mtime}, @digest=#{@digest}>"
        end

        private

        # Marshal.dump walks every Hash it serializes. Ruby raises RuntimeError
        # ("... during iteration") if a Hash changes mid-walk. A user hit
        # "hash representation was changed during iteration" here on Ruby 4.0.0;
        # what changed the Hash is unknown, as nothing writes @data after load.
        # This is a permanent defense, not tied to a Ruby version. The copy only
        # reads @data, so retrying is safe; unrelated errors propagate unchanged.
        def deep_copy(obj)
          attempts = 0
          begin
            Marshal.load(Marshal.dump(obj))
          rescue RuntimeError => e
            raise unless e.message.include?('during iteration')

            attempts += 1
            raise if attempts >= DEEP_COPY_ATTEMPTS

            SetupFiles.safe_log("SetupFiles: retrying deep copy of #{self} (attempt #{attempts}): #{e.message}")
            # Let any thread mid-operation on the Hash finish before retrying.
            Thread.pass
            retry
          end
        end
      end

      def initialize(debug = false)
        super()
        @files_cache = {}
        @load_errors = {}
        @debug = debug
      end

      # Loads one YAML file as a Hash. The file must be trusted: it is parsed
      # with YAML.unsafe_load, which can instantiate arbitrary Ruby objects.
      # A file that cannot be read or parsed, or whose top level is a sequence
      # or a scalar other than null or false, is reported to the client as
      # "*** ERROR PARSING YAML FILE ***" plus the error message, and loads as
      # an empty Hash. An empty document, or one whose top level is null or
      # false, loads as an empty Hash without a report.
      #
      # @param filepath [String] path to the YAML file
      # @return [Hash{Symbol => Object}] the top-level mapping with Symbol keys,
      #   or {} after reporting a load error
      def safe_load_yaml(filepath)
        parse_yaml_file(filepath)
      rescue => e
        report_load_error(e)
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
        safe_log "#{self.class}::#{__callee__} resolved include_filenames=#{include_filenames}" if @debug

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
      #
      # @return [Hash{String => String}] basename => path of every data file
      #   found by the data-directory scan (see #load_files)
      def reload
        reload_profiles(character_suffixes_to_filenames(['setup']))
        reload_data
      end

      # Guarded logging -- safe to call before Lich.log is defined. Public and
      # class-level so FileInfo can share it.
      #
      # @param text [String] log message
      # @return [void]
      def self.safe_log(text)
        if defined?(Lich) && Lich.respond_to?(:log)
          Lich.log(text)
        else
          $stderr.puts(text)
        end
      end

      private

      # Lazy memoized path.
      def scripts_data_path
        @scripts_data_path ||= File.join(SCRIPT_DIR, 'data')
      end

      # Lazy memoized path -- user-supplied data files that take precedence
      # over the shipped base data files, mirroring how scripts/custom takes
      # precedence over scripts/ when loading scripts.
      def scripts_data_custom_path
        @scripts_data_custom_path ||= File.join(scripts_data_path, 'custom')
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
            safe_message("info", "Detected game instance-specific files. Loading settings from #{File.join(DATA_DIR, game)}")
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
        # Scan scripts/data/custom before scripts/data so a user's custom data
        # file wins by basename in load_files (first match wins via ||=).
        get_glob_patterns(scripts_data_custom_path, filenames) +
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
          safe_log "#{self.class}::#{__callee__} #{filename} has nested includes: #{nested_suffixes}" if @debug && !nested_suffixes.empty?
          nested_filenames = nested_suffixes.map { |suffix| to_include_filename(suffix) }

          resolve_includes_recursively(nested_filenames, visited, include_order)
          include_order << filename
        end
        include_order
      end

      # Scans the given glob patterns and refreshes the cache to match disk:
      # evicts entries whose file is gone, then loads new and changed files.
      #
      # Pattern precedence: patterns are scanned in order and the first file
      # found for a basename wins, so earlier patterns (scripts/data/custom
      # before scripts/data, see #get_data_glob_patterns) override later ones.
      # Eviction only touches entries from the scanned directories whose names
      # match one of the patterns.
      #
      # Interrupt deferral: each descriptor-opening call (Dir.glob here,
      # File.read in #read_yaml_file, Digest in #file_digest) runs inside
      # #without_interrupts, so a Thread#kill or Thread#raise that arrives
      # mid-call is delivered as soon as that call returns. Everything else
      # (logging, YAML parsing, error messages) runs with interrupts as the
      # caller had them.
      #
      # @param glob_patterns [Array<String>] glob patterns, highest precedence first
      # @return [Hash{String => String}] basename => winning path for every file found
      # @api private
      def load_files(glob_patterns = [])
        synchronize do
          safe_log "#{self.class}::#{__callee__} glob_patterns=#{glob_patterns}" if @debug
          # Build a map of filename -> filepath for all files currently on disk
          current_files = {}
          glob_patterns.each do |glob_pattern|
            without_interrupts { Dir.glob(glob_pattern) }
              .select { |filepath| File.file?(filepath) }
              .each { |filepath| current_files[File.basename(filepath)] ||= filepath }
          end

          # Evict cache entries whose backing files no longer exist on disk.
          # Only remove entries whose path matches the directories being scanned
          # AND whose name matches our glob patterns. This prevents a data-dir
          # reload from evicting identically-named profile-dir entries.
          scan_dirs = glob_patterns.map { |p| File.dirname(p) }.uniq
          @files_cache.delete_if do |name, info|
            evict = scan_dirs.include?(info.path) &&
                    !current_files.key?(name) &&
                    glob_patterns.any? { |p| File.fnmatch(File.basename(p), name) }
            # A removed file's load error is forgotten, so restoring it reports again.
            @load_errors.delete(info.to_s) if evict
            evict
          end

          current_files.each do |filename, filepath|
            # Freshness is decided by file content (SHA256), not mtime. mtime is
            # unreliable: two writes within one filesystem timestamp tick share
            # an mtime, so an mtime-only check serves stale data after a fast
            # rewrite (see issue #1596). We also reload when the winning source
            # path changes (e.g. a scripts/data/custom override is removed and
            # the same basename now resolves to scripts/data), which an
            # mtime-only check masks when the two files share an mtime.
            current_digest = file_digest(filepath)
            cached_file = cache_get_by_filename(filename)
            safe_log "#{self.class}::#{__callee__} filepath=#{filepath}, current_digest=#{current_digest}, cached_file=#{cached_file.inspect}" if @debug
            # A load that failed was cached with a nil digest (see
            # #cache_put_by_filepath), which differs from any readable file's
            # digest, so it is retried here.
            if cached_file.nil? ||
               cached_file.path != File.dirname(filepath) ||
               cached_file.digest != current_digest
              cache_put_by_filepath(filepath, digest: current_digest)
            end
          end
          current_files
        end
      end

      # Runs the block with Thread#kill and Thread#raise deferred until it
      # returns. Use it only around a single call that opens and closes a
      # descriptor. A thread killed inside Dir.glob or File.open can leak the
      # descriptor: no Ruby object owns it yet, so GC never closes it. Script#kill
      # stops script threads with Thread#kill, so a script stopped while loading
      # settings leaked a scripts/profiles handle on every stop until the process
      # hit its open-files limit.
      #
      # Keep the block to that one call. Threads inherit the mask of the thread
      # that creates them, so anything that can start a thread inside the block
      # (an error message reaching the client socket starts its writer) creates
      # a thread that Thread#kill can never stop.
      #
      # Object, not Exception: the kill signal is not an Exception, so
      # Exception => :never does not defer it. Called inside synchronize, so a
      # thread still waiting for the monitor stays killable.
      #
      # @yield the descriptor-opening call
      # @return [Object] the block's result
      # @api private
      def without_interrupts(&block)
        Thread.handle_interrupt(Object => :never, &block)
      end

      # Loads a file into the cache. A load that fails is cached as {} with a
      # nil digest, so the next scan that can read the file retries it instead
      # of serving {} until the file changes. The failure may be transient: a read error such as
      # Errno::EMFILE, or an exception another thread delivered with
      # Thread#raise while the file was being parsed.
      #
      # @param filepath [String] path to the file
      # @param digest [String, nil] its content digest, if already computed
      # @return [FileInfo] the new cache entry
      # @api private
      def cache_put_by_filepath(filepath, digest: nil)
        synchronize do
          safe_log "#{self.class}::#{__callee__} filepath=#{filepath}" if @debug
          mtime = File.mtime(filepath)
          digest ||= file_digest(filepath)
          data = load_for_cache(filepath, digest)
          @files_cache[File.basename(filepath)] = FileInfo.new(
            path: File.dirname(filepath),
            name: File.basename(filepath),
            mtime: mtime,
            digest: data ? digest : nil,
            data: data || {}
          )
        end
      end

      # Parses a file for the cache. Because a failed load is retried on every
      # scan, its error is reported once per file content and error, not on
      # every retry: a file that stays malformed is reported once until it is
      # edited, removed, or loads successfully.
      #
      # @param filepath [String] path to the file
      # @param digest [String, nil] its content digest
      # @return [Hash{Symbol => Object}, nil] the loaded mapping, or nil if loading failed
      # @api private
      def load_for_cache(filepath, digest)
        data = parse_yaml_file(filepath)
        @load_errors.delete(filepath)
        data
      rescue => e
        failure = [digest, e.class, e.message]
        report_load_error(e) unless @load_errors[filepath] == failure
        @load_errors[filepath] = failure
        nil
      end

      # Parses a YAML file into a Symbol-keyed Hash (see #safe_load_yaml).
      #
      # @param filepath [String] path to the YAML file
      # @return [Hash{Symbol => Object}] the top-level mapping
      # @raise [StandardError] if the file cannot be read or parsed, or its
      #   top level is a sequence or a scalar other than null or false
      # @api private
      def parse_yaml_file(filepath)
        OpenStruct.new(YAML.unsafe_load(read_yaml_file(filepath), filename: filepath)).to_h
      end

      # Reports a YAML load failure to the client.
      #
      # @param error [StandardError] the load failure
      # @return [void]
      # @api private
      def report_load_error(error)
        safe_message("bold", "*** ERROR PARSING YAML FILE ***")
        safe_message("bold", error.message)
      end

      # Reads a YAML file the way YAML.unsafe_load_file opens it (BOM-aware
      # UTF-8). Only the read is guarded (see #without_interrupts); parsing and
      # any parse-error message run outside the guard.
      #
      # @param filepath [String] path to the YAML file
      # @return [String] file contents
      # @api private
      def read_yaml_file(filepath)
        without_interrupts { File.read(filepath, mode: 'r:bom|utf-8') }
      end

      # Content hash used as the cache freshness signal. Returns nil when the
      # file cannot be read (e.g. it vanished between the glob and here). An
      # entry stored with a nil digest is reloaded on the first pass that can
      # read the file again (see #load_files). The read is guarded (see #without_interrupts).
      #
      # @param filepath [String] path to the file
      # @return [String, nil] hex SHA256 of the contents, or nil if unreadable
      # @api private
      def file_digest(filepath)
        without_interrupts { Digest::SHA256.file(filepath) }.hexdigest
      rescue => e
        safe_log "#{self.class}::#{__callee__} could not hash #{filepath}: #{e.message}" if @debug
        nil
      end

      def cache_get_by_filename(filename)
        safe_log "#{self.class}::#{__callee__} filename=#{filename}" if @debug
        @files_cache[filename]
      end

      # Delegates to SettingsTransformer with game-specific config if available.
      def transform_settings(settings)
        safe_log "#{self.class}::#{__callee__}" if @debug
        if defined?(Lich::DragonRealms::SettingsConfig)
          config = Lich::DragonRealms::SettingsConfig::TRANSFORM_CONFIG
          Lich::Common::SettingsTransformer.transform(settings, config, method(:get_data))
        else
          OpenStruct.new(settings)
        end
      end

      def transform_data(original_data)
        safe_log "#{self.class}::#{__callee__}" if @debug
        data = OpenStruct.new(original_data)
        data
      rescue => e
        safe_message("bold", "*** ERROR MODIFYING DATA ***")
        safe_message("bold", e.message)
        e.backtrace.each { |line| safe_message("bold", line) }
        OpenStruct.new
      end

      # Guarded messaging -- safe to call before Lich::Messaging is initialized.
      #
      # @param type [String] message type (e.g. 'bold', 'info', 'error')
      # @param text [String] message text
      # @return [void]
      def safe_message(type, text)
        if defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:msg)
          Lich::Messaging.msg(type, text)
        else
          safe_log(text)
        end
      end

      # Guarded logging -- safe to call before Lich.log is defined.
      #
      # @param text [String] log message
      # @return [void]
      # @see SetupFiles.safe_log
      def safe_log(text)
        self.class.safe_log(text)
      end
    end
  end
end
