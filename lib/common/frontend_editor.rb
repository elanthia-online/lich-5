# frozen_string_literal: true

require 'shellwords'
require_relative 'frontend'
require_relative 'frontend_settings'
require_relative 'frontend_locator'

module Lich
  module Common
    # The rules for editing frontend configuration, with no widgets attached.
    #
    # GUI::FrontendManagerTab grew these as private methods around Gtk::Entry
    # instances, so the WebUI launcher could not reach them without either
    # duplicating the validation or instantiating GTK. The shapes a
    # frontends.yml document may hold, what a built-in may override, and what
    # makes an identifier acceptable are properties of the settings file rather
    # than of either toolkit -- so they live here and both launchers call them.
    #
    # Nothing here reads or writes a file. Callers hand in the current document
    # and persist the result, which keeps the reload-before-write decision with
    # the caller that knows whether it is racing another Lich.
    module FrontendEditor
      CONTROL_CHARACTERS = /[\x00-\x1f\x7f]/

      class << self
        # Every registered frontend, built-ins first in catalog order, with the
        # configuration and detection status each currently has.
        def rows(settings: FrontendSettings, frontend: Frontend, locator: FrontendLocator)
          document = settings.current
          builtins = document.fetch('builtins', {})
          custom = document.fetch('custom', {})
          built_in_rows(frontend, builtins, locator) + custom_rows(custom)
        end

        # Whether the id belongs to Lich's own catalog. A built-in may carry
        # launch overrides but cannot be deleted or renamed.
        def built_in?(frontend_id, frontend: Frontend)
          frontend.built_in_frontends.include?(frontend_id.to_s)
        end

        # The persisted settings for one frontend, shaped for an editor.
        def editor_fields(frontend_id, settings: FrontendSettings, frontend: Frontend, locator: FrontendLocator)
          id = frontend_id.to_s
          document = settings.current
          if built_in?(id, frontend: frontend)
            built_in_fields(id, document, frontend, locator)
          else
            custom_fields(id, document)
          end
        end

        # Applies an edit to the document and returns the new builtins/custom
        # pair plus the id touched. Writes nothing.
        #
        # @param fields [Hash] :id, :label, :command, :directory, :arguments
        #   (the raw shell-quoted string), :capabilities
        # @raise [ArgumentError] with a message meant for the player
        def apply(document, fields, creating:, frontend: Frontend)
          builtins = document.fetch('builtins', {}).dup
          custom = document.fetch('custom', {}).dup

          if creating
            id = validate_new_id(fields[:id], frontend: frontend)
            custom[id] = custom_definition(fields)
          elsif built_in?(fields[:id], frontend: frontend)
            id = fields[:id].to_s
            update_builtin(builtins, id, fields)
          else
            id = fields[:id].to_s
            raise ArgumentError, "Custom frontend no longer exists: #{id}" unless custom.key?(id)

            custom[id] = custom_definition(fields)
          end

          [builtins, custom, id]
        end

        # Removes a custom frontend from the document.
        def remove(document, frontend_id, frontend: Frontend)
          id = frontend_id.to_s
          raise ArgumentError, 'Built-in frontends cannot be deleted.' if built_in?(id, frontend: frontend)

          builtins = document.fetch('builtins', {}).dup
          custom = document.fetch('custom', {}).dup
          raise ArgumentError, "Custom frontend no longer exists: #{id}" unless custom.delete(id)

          [builtins, custom]
        end

        # Parses the shell-quoted argument string an editor field carries.
        def parse_arguments(raw)
          FrontendSettings.validate_arguments(Shellwords.split(raw.to_s))
        rescue ArgumentError => error
          raise error if error.message.start_with?('Additional arguments', 'Argument')

          raise ArgumentError, "Additional arguments are invalid: #{error.message}"
        end

        # A bounded printable scalar, or nil when blank.
        def optional_scalar(name, value)
          text = value.to_s.strip
          return nil if text.empty?
          raise ArgumentError, "#{name} is too long." if text.bytesize > FrontendSettings::MAX_SCALAR_BYTES
          raise ArgumentError, "#{name} contains unsupported control characters." if text.match?(CONTROL_CHARACTERS)

          text
        end

        def required_scalar(name, value)
          optional_scalar(name, value) || raise(ArgumentError, "#{name} is required.")
        end

        def validate_new_id(raw_id, frontend: Frontend)
          id = raw_id.to_s.strip.downcase
          unless id.match?(FrontendSettings::CUSTOM_ID_PATTERN)
            raise ArgumentError, 'Stable ID must use 1-64 lowercase letters, numbers, underscores, or hyphens.'
          end
          raise ArgumentError, "Frontend ID is already in use: #{id}" if frontend.registered_frontends.include?(id)

          id
        end

        private

        def built_in_fields(id, document, frontend, locator)
          persisted = document.fetch('builtins', {}).fetch(id, {})
          resolution = resolve(locator, id)
          {
            id: id, label: frontend.display_name(id), built_in: true,
            command: persisted['executable'].to_s,
            detected_command: resolution&.executable_path.to_s,
            directory: '', arguments: join_arguments(persisted['arguments']),
            # A built-in's protocol capabilities are the catalog's, not the
            # player's -- they are shown so the editor says what the frontend
            # speaks, and they are disabled so it cannot be claimed otherwise.
            # Reporting none made every built-in look like it spoke nothing.
            capabilities: built_in_capabilities(id, frontend)
          }
        end

        def built_in_capabilities(id, frontend)
          Array(frontend.definition_for(id)[:capabilities]).map(&:to_s)
        rescue StandardError
          []
        end

        def custom_fields(id, document)
          persisted = document.fetch('custom', {}).fetch(id, {})
          {
            id: id, label: persisted['label'].to_s, built_in: false,
            command: persisted['command'].to_s, detected_command: '',
            directory: persisted['directory'].to_s,
            arguments: join_arguments(persisted['arguments']),
            capabilities: Array(persisted['capabilities']).map(&:to_s)
          }
        end

        def built_in_rows(frontend, builtins, locator)
          frontend.built_in_frontends.map do |id|
            persisted = builtins.fetch(id, {})
            resolution = resolve(locator, id)
            {
              id: id, label: frontend.display_name(id), type: 'Built-in',
              status: built_in_status(resolution),
              launch: persisted['executable'] || resolution&.executable_path.to_s,
              arguments: join_arguments(persisted['arguments'])
            }
          end
        end

        def custom_rows(custom)
          custom.map do |id, definition|
            {
              id: id, label: definition['label'].to_s, type: 'Custom', status: 'Configured',
              launch: definition['command'].to_s, arguments: join_arguments(definition['arguments'])
            }
          end
        end

        def built_in_status(resolution)
          return 'Unavailable' unless resolution
          return 'Configured' if resolution.source == :configured

          'Detected'
        end

        def resolve(locator, frontend_id)
          locator.resolve(frontend_id)
        rescue ArgumentError, SystemCallError
          nil
        end

        def join_arguments(arguments)
          Array(arguments).map(&:to_s).shelljoin
        end

        # A built-in persists only what it overrides, and nothing at all once
        # both fields are cleared -- otherwise frontends.yml accumulates empty
        # entries that shadow the catalog.
        def update_builtin(builtins, frontend_id, fields)
          executable = optional_scalar('Executable override', fields[:command])
          arguments = parse_arguments(fields[:arguments])
          if executable.nil? && arguments.empty?
            builtins.delete(frontend_id)
          else
            settings = {}
            settings['executable'] = executable if executable
            settings['arguments'] = arguments unless arguments.empty?
            builtins[frontend_id] = settings
          end
        end

        def custom_definition(fields)
          {
            'label'        => required_scalar('Label', fields[:label]),
            'command'      => required_scalar('Command', fields[:command]),
            'directory'    => optional_scalar('Working directory', fields[:directory]),
            'arguments'    => parse_arguments(fields[:arguments]),
            'capabilities' => Array(fields[:capabilities]).map(&:to_s)
          }.compact
        end
      end
    end
  end
end
