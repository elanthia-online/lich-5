# frozen_string_literal: true

require 'fileutils'
require 'tempfile'
require 'yaml'
require_relative 'frontend'

module Lich
  module Common
    # Owns user-configurable frontend definitions and built-in launch overrides.
    #
    # The persisted schema deliberately lives outside entry.yaml so frontend
    # configuration never enters the credential lifecycle. Callers replace the
    # complete configuration; validation, atomic persistence, catalog cleanup,
    # and immutable process state stay behind this module's small interface.
    module FrontendSettings
      FILE_NAME = 'frontends.yml'
      SCHEMA_VERSION = 1
      CUSTOM_ID_PATTERN = /\A[a-z0-9][a-z0-9_-]{0,63}\z/
      MAX_SCALAR_BYTES = 4096
      MAX_ARGUMENTS = 256
      MUTEX = Mutex.new

      # Raised when saving would overwrite a settings document created by a
      # newer, unsupported schema version.
      class UnsupportedVersionError < StandardError; end

      EMPTY_CONFIGURATION = Lich::Util.deep_freeze(
        {
          'version'  => SCHEMA_VERSION,
          'builtins' => {},
          'custom'   => {}
        }
      )

      @current = EMPTY_CONFIGURATION

      class << self
        # Loads, validates, and applies frontends.yml from a Lich data directory.
        # Missing, unreadable, or malformed files become an empty configuration
        # and restore the pristine built-in catalog. A document from a newer
        # schema is left untouched and the last known-good catalog remains active.
        # Invalid argument lists likewise retain the previous catalog and are logged.
        #
        # @param data_dir [String, nil] Lich data directory; defaults to DATA_DIR
        # @return [Hash] normalized configuration snapshot
        def load!(data_dir: nil)
          directory = resolve_data_dir(data_dir)
          MUTEX.synchronize do
            path = File.join(directory, FILE_NAME)
            raw = read_file(path)
            if unsupported_version?(raw)
              warn_unsupported_file(raw)
              return deep_copy(@current)
            end

            apply_configuration(normalize_configuration(raw))
          rescue ArgumentError => error
            log_warning("could not apply #{FILE_NAME}: #{error.message}")
            deep_copy(@current)
          end
        end

        # Validates, atomically persists, and applies a complete configuration.
        # Replacing the whole document makes deletion explicit and prevents stale
        # custom definitions from accumulating across settings reloads.
        #
        # @param data_dir [String, nil] Lich data directory; defaults to DATA_DIR
        # @param builtins [Hash] built-in executable/argument overrides
        # @param custom [Hash] custom frontend definitions keyed by stable id
        # @return [Hash] normalized configuration snapshot
        def replace!(data_dir: nil, builtins: {}, custom: {})
          directory = resolve_data_dir(data_dir)
          MUTEX.synchronize do
            path = File.join(directory, FILE_NAME)
            refuse_unsupported_overwrite!(path)
            configuration = normalize_configuration(
              'version'  => SCHEMA_VERSION,
              'builtins' => builtins,
              'custom'   => custom
            )
            write_file(path, configuration)
            apply_configuration(configuration)
          end
        end

        # Returns a detached snapshot so callers cannot mutate applied settings.
        # @return [Hash]
        def current
          MUTEX.synchronize { deep_copy(@current) }
        end

        # Returns persisted settings for a built-in or custom frontend identifier.
        # Aliases such as wrayth resolve to their stable built-in id.
        #
        # @param frontend_id [String, Symbol]
        # @return [Hash, nil]
        def settings_for(frontend_id)
          frontend_id = Frontend.canonical_name(frontend_id)
          MUTEX.synchronize do
            settings = @current.fetch('builtins').fetch(frontend_id, nil) ||
                       @current.fetch('custom').fetch(frontend_id, nil)
            settings && deep_copy(settings)
          end
        end

        # Validates literal argv values without trimming or dropping positions.
        #
        # @param value [Array<String>] complete additional argument list
        # @return [Array<String>] detached, unchanged argument values
        # @raise [ArgumentError] when the list exceeds bounds or contains invalid values
        def validate_arguments(value)
          unless value.is_a?(Array) && value.length <= MAX_ARGUMENTS
            raise ArgumentError, "Additional arguments must be an array of at most #{MAX_ARGUMENTS} strings."
          end
          unless value.all? { |argument|
            argument.is_a?(String) && argument.valid_encoding? &&
            argument.bytesize <= MAX_SCALAR_BYTES && !argument.match?(/[\x00-\x1f\x7f]/)
          }
            raise ArgumentError, 'Arguments must be bounded strings without control characters.'
          end

          value.map(&:dup)
        end

        private

        # Resolves the configured or process-default Lich data directory.
        #
        # @param data_dir [String, nil] explicit Lich data directory
        # @return [String] absolute data directory path
        # @raise [ArgumentError] when no data directory is available
        # @api private
        def resolve_data_dir(data_dir)
          directory = data_dir
          directory = DATA_DIR if directory.nil? && defined?(DATA_DIR)
          raise ArgumentError, 'data_dir is required' if directory.to_s.strip.empty?

          File.expand_path(directory.to_s)
        end

        # Reads a YAML settings document, falling back to an empty document when
        # the file is missing, unreadable, or malformed.
        #
        # @param path [String] settings document path
        # @return [Object] parsed YAML value or an empty hash
        # @api private
        def read_file(path)
          return {} unless File.file?(path)

          YAML.safe_load_file(path, permitted_classes: [], permitted_symbols: [], aliases: false)
        rescue Psych::Exception, SystemCallError => error
          log_warning("could not load #{FILE_NAME}: #{error.message}")
          {}
        end

        # Atomically writes a normalized settings document with owner-only access.
        #
        # @param path [String] destination settings path
        # @param configuration [Hash] normalized frontend configuration
        # @return [void]
        # @raise [IOError] when the settings document cannot be saved
        # @api private
        def write_file(path, configuration)
          directory = File.dirname(path)
          FileUtils.mkdir_p(directory)
          Tempfile.create(['frontends', '.yml.tmp'], directory) do |file|
            file.chmod(0o600)
            file.write(configuration.to_yaml)
            file.flush
            file.fsync
            File.rename(file.path, path)
          end
        rescue SystemCallError => error
          raise IOError, "could not save #{FILE_NAME}: #{error.message}"
        end

        # Converts an arbitrary settings document into the supported immutable schema.
        #
        # @param raw [Object] parsed settings document
        # @return [Hash] normalized, deeply frozen configuration
        # @api private
        def normalize_configuration(raw)
          raw = {} unless raw.is_a?(Hash)
          configuration = {
            'version'  => SCHEMA_VERSION,
            'builtins' => normalize_builtins(hash_value(raw, 'builtins')),
            'custom'   => normalize_custom(hash_value(raw, 'custom'))
          }
          Lich::Util.deep_freeze(configuration)
        end

        # Determines whether a settings document uses an unsupported schema version.
        #
        # @param raw [Object] parsed settings document
        # @return [Boolean]
        # @api private
        def unsupported_version?(raw)
          raw.is_a?(Hash) && raw.key?('version') && raw['version'] != SCHEMA_VERSION
        end

        # Logs that a newer settings schema cannot be applied safely.
        #
        # @param raw [Hash] parsed settings document containing a version
        # @return [void]
        # @api private
        def warn_unsupported_file(raw)
          version = raw['version'].inspect
          log_warning(
            "#{FILE_NAME} uses unsupported schema version #{version}; " \
            "supported version is #{SCHEMA_VERSION}. Existing frontend settings were not applied or changed."
          )
        end

        # Prevents replacement of a settings document from a newer schema.
        #
        # @param path [String] settings document path
        # @return [void]
        # @raise [UnsupportedVersionError] when the existing schema is unsupported
        # @api private
        def refuse_unsupported_overwrite!(path)
          return unless File.file?(path)

          raw = read_file(path)
          return unless unsupported_version?(raw)

          warn_unsupported_file(raw)
          raise UnsupportedVersionError,
                "refusing to overwrite #{FILE_NAME} schema version #{raw['version'].inspect}; " \
                "remove or migrate the file before saving version #{SCHEMA_VERSION} settings"
        end

        # Normalizes supported launch overrides for built-in frontends.
        #
        # @param raw [Object] raw built-in settings
        # @return [Hash{String => Hash}] normalized overrides keyed by frontend id
        # @api private
        def normalize_builtins(raw)
          return {} unless raw.is_a?(Hash)

          raw.each_with_object({}) do |(raw_id, raw_settings), normalized|
            next unless raw_settings.is_a?(Hash)

            frontend_id = Frontend.canonical_name(clean_scalar(raw_id))
            next unless Frontend.built_in_frontends.include?(frontend_id)

            settings = {}
            executable = clean_scalar(hash_value(raw_settings, 'executable'))
            arguments = clean_arguments(hash_value(raw_settings, 'arguments'))
            settings['executable'] = executable if executable
            settings['arguments'] = arguments unless arguments.nil?
            normalized[frontend_id] = settings unless settings.empty?
          end
        end

        # Normalizes valid user-defined frontend records.
        #
        # @param raw [Object] raw custom frontend settings
        # @return [Hash{String => Hash}] normalized definitions keyed by frontend id
        # @api private
        def normalize_custom(raw)
          return {} unless raw.is_a?(Hash)

          raw.each_with_object({}) do |(raw_id, raw_definition), normalized|
            next unless raw_definition.is_a?(Hash)

            frontend_id = clean_scalar(raw_id)&.downcase
            next unless frontend_id&.match?(CUSTOM_ID_PATTERN)
            next if Frontend.built_in_frontends.include?(Frontend.canonical_name(frontend_id))
            unless Frontend.user_definition_id_available?(frontend_id)
              log_warning("ignoring custom frontend #{frontend_id.inspect}: identifier is already registered")
              next
            end

            label = clean_scalar(hash_value(raw_definition, 'label'))
            command = clean_scalar(hash_value(raw_definition, 'command'))
            next unless label && command

            definition = {
              'label'   => label,
              'command' => command
            }
            directory = clean_scalar(hash_value(raw_definition, 'directory'))
            definition['directory'] = directory if directory
            definition['arguments'] = clean_arguments(hash_value(raw_definition, 'arguments')) || []
            definition['capabilities'] = clean_capabilities(hash_value(raw_definition, 'capabilities'))
            normalized[frontend_id] = definition
          end
        end

        # Normalizes a bounded printable scalar value.
        #
        # @param value [Object] candidate scalar value
        # @return [String, nil] normalized value or nil when invalid
        # @api private
        def clean_scalar(value)
          return nil unless value.is_a?(String) || value.is_a?(Symbol)

          value = value.to_s.strip
          return nil if value.empty? || value.bytesize > MAX_SCALAR_BYTES
          return nil if value.match?(/[\x00-\x1f\x7f]/)

          value
        end

        # Validates optional literal frontend arguments without changing positions.
        #
        # @param value [Object] candidate argument list
        # @return [Array<String>, nil] unchanged arguments or nil when absent
        # @raise [ArgumentError] when a supplied list is invalid
        # @api private
        def clean_arguments(value)
          return nil if value.nil?

          validate_arguments(value)
        end

        # Filters declared capabilities to the supported public vocabulary.
        #
        # @param value [Object] candidate capability list
        # @return [Array<String>] unique supported capability names
        # @api private
        def clean_capabilities(value)
          return [] unless value.is_a?(Array)

          allowed = Frontend.capability_vocabulary
          value.filter_map do |capability|
            next unless capability.is_a?(String) || capability.is_a?(Symbol)

            capability = capability.to_s.downcase.to_sym
            capability if allowed.include?(capability)
          end.uniq.map(&:to_s)
        end

        # Reads a value from a hash using either a string or symbol key.
        #
        # @param hash [Hash] source hash
        # @param key [String] key to resolve
        # @return [Object, nil] matching value when present
        # @api private
        def hash_value(hash, key)
          hash.key?(key) ? hash[key] : hash[key.to_sym]
        end

        # Applies normalized settings to the frontend catalog and process snapshot.
        #
        # @param configuration [Hash] normalized frontend configuration
        # @return [Hash] detached applied configuration
        # @api private
        def apply_configuration(configuration)
          built_in_overrides = configuration.fetch('builtins').transform_values do |settings|
            {
              executable: settings['executable'],
              arguments: settings['arguments']
            }.compact
          end
          custom_definitions = configuration.fetch('custom').transform_values do |definition|
            {
              label: definition.fetch('label'),
              command: definition.fetch('command'),
              directory: definition['directory'],
              arguments: definition.fetch('arguments'),
              capabilities: definition.fetch('capabilities').map(&:to_sym)
            }
          end

          Frontend.replace_user_configuration!(
            built_in_overrides: built_in_overrides,
            custom_definitions: custom_definitions
          )
          @current = configuration
          deep_copy(configuration)
        end

        # Recursively copies mutable hashes and arrays.
        #
        # @param value [Object] value to copy
        # @return [Object] detached copy
        # @api private
        def deep_copy(value)
          case value
          when Hash
            value.each_with_object({}) { |(key, item), copy| copy[key] = deep_copy(item) }
          when Array
            value.map { |item| deep_copy(item) }
          else
            value.dup
          end
        end

        def log_warning(message)
          Lich.log("warning: #{message}") if Lich.respond_to?(:log)
        end
      end
    end
  end
end
