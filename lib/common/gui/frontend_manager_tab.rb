# frozen_string_literal: true

require 'shellwords'
require_relative '../frontend'
require_relative '../frontend_locator'
require_relative '../frontend_settings'

module Lich
  module Common
    module GUI
      # GTK editor for built-in frontend launch overrides and custom frontends.
      # Detection is presented as status only; this tab never launches a
      # frontend or changes account/character associations.
      class FrontendManagerTab
        ID_COLUMN = 0
        LABEL_COLUMN = 1
        TYPE_COLUMN = 2
        STATUS_COLUMN = 3
        LAUNCH_COLUMN = 4
        ARGUMENTS_COLUMN = 5
        CAPABILITIES_PER_ROW = 3
        DEFAULT_CATALOG_HEIGHT = 210

        attr_reader :widget

        # Initializes the frontend settings editor and populates its catalog list.
        #
        # @param data_dir [String] Lich data directory containing frontends.yml
        # @param settings [FrontendSettings] persistence and catalog application module
        # @param frontend [Frontend] frontend catalog module
        # @param locator [FrontendLocator] executable discovery module
        # @param on_changed [Proc, nil] zero-argument callback after save/delete/reload
        # @return [FrontendManagerTab]
        def initialize(
          data_dir:,
          settings: FrontendSettings,
          frontend: Frontend,
          locator: FrontendLocator,
          on_changed: nil
        )
          @data_dir = data_dir
          @settings = settings
          @frontend = frontend
          @locator = locator
          @on_changed = on_changed
          @editing_new = false
          @selected_id = nil
          @row_iters = {}

          @widget = build_widget
          populate_list
        end

        # Reloads frontends.yml, refreshes detection, and retains selection when possible.
        # @return [Boolean] true on success
        def reload!
          preferred_id = @selected_id
          @settings.load!(data_dir: @data_dir)
          @locator.refresh!
          populate_list(preferred_id: preferred_id)
          report_status('Frontend configuration reloaded.')
          notify_changed
          true
        rescue StandardError => error
          report_error(error.message)
          false
        end

        private

        # Builds the complete frontend-management tab widget.
        #
        # @return [Gtk::Box] tab root
        # @api private
        def build_widget
          root = Gtk::Box.new(:vertical, 8)
          root.border_width = 10

          content = Gtk::Paned.new(:vertical)
          content.add1(build_frontend_list)
          content.add2(build_editor_scroller)
          content.position = DEFAULT_CATALOG_HEIGHT
          root.pack_start(content, expand: true, fill: true, padding: 0)
          root.pack_start(@status_label, expand: false, fill: true, padding: 0)
          root
        end

        # Builds the frontend catalog list and its selection handler.
        #
        # @return [Gtk::ScrolledWindow] scrollable frontend list
        # @api private
        def build_frontend_list
          @model = Gtk::ListStore.new(String, String, String, String, String, String)
          @tree_view = Gtk::TreeView.new(@model)
          append_text_column('Frontend', LABEL_COLUMN)
          append_text_column('Type', TYPE_COLUMN)
          append_text_column('Status', STATUS_COLUMN)
          append_text_column('Executable / command', LAUNCH_COLUMN)
          append_text_column('Additional arguments', ARGUMENTS_COLUMN)

          @tree_view.selection.signal_connect('changed') do
            iter = @tree_view.selection.selected
            load_selected(iter) if iter
          end

          scroller = Gtk::ScrolledWindow.new
          scroller.set_policy(:automatic, :automatic)
          scroller.add(@tree_view)
          scroller
        end

        # Appends a resizable text column to the frontend list.
        #
        # @param title [String] visible column title
        # @param model_column [Integer] list-store column index
        # @return [void]
        # @api private
        def append_text_column(title, model_column)
          renderer = Gtk::CellRendererText.new
          column = Gtk::TreeViewColumn.new(title, renderer, text: model_column)
          column.resizable = true
          @tree_view.append_column(column)
        end

        # Keeps the editor usable when a previously saved launcher window is
        # smaller than the editor's preferred height.
        #
        # @return [Gtk::ScrolledWindow] vertically scrollable editor
        # @api private
        def build_editor_scroller
          scroller = Gtk::ScrolledWindow.new
          scroller.set_policy(:automatic, :automatic)
          scroller.add(build_editor)
          scroller
        end

        # Builds the editable fields and action controls for a frontend.
        #
        # @return [Gtk::Box] editor widget
        # @api private
        def build_editor
          editor = Gtk::Box.new(:vertical, 6)

          @id_entry = Gtk::Entry.new
          @label_entry = Gtk::Entry.new
          @command_label = Gtk::Label.new('Executable override:')
          @command_entry = Gtk::Entry.new
          @directory_entry = Gtk::Entry.new
          @arguments_entry = Gtk::Entry.new
          @arguments_entry.placeholder_text = 'Arguments use shell quoting, for example: --flag "two words"'

          editor.pack_start(labeled_row(Gtk::Label.new('Stable ID:'), @id_entry), expand: false, fill: true, padding: 0)
          editor.pack_start(labeled_row(Gtk::Label.new('Label:'), @label_entry), expand: false, fill: true, padding: 0)
          editor.pack_start(labeled_row(@command_label, @command_entry), expand: false, fill: true, padding: 0)
          editor.pack_start(labeled_row(Gtk::Label.new('Working directory:'), @directory_entry), expand: false, fill: true, padding: 0)
          editor.pack_start(labeled_row(Gtk::Label.new('Additional arguments:'), @arguments_entry), expand: false, fill: true, padding: 0)

          capabilities = Gtk::Box.new(:vertical, 3)
          @capability_checks = {}
          @frontend.capability_vocabulary.each_slice(CAPABILITIES_PER_ROW).with_index do |row_capabilities, index|
            row = Gtk::Box.new(:horizontal, 5)
            label = Gtk::Label.new(index.zero? ? 'Capabilities:' : '')
            label.set_width_chars(22)
            row.pack_start(label, expand: false, fill: false, padding: 0)
            row_capabilities.each do |capability|
              check = Gtk::CheckButton.new(capability.to_s)
              @capability_checks[capability] = check
              row.pack_start(check, expand: false, fill: false, padding: 0)
            end
            capabilities.pack_start(row, expand: false, fill: true, padding: 0)
          end
          editor.pack_start(capabilities, expand: false, fill: true, padding: 0)

          buttons = Gtk::Box.new(:horizontal, 5)
          add_button = Gtk::Button.new(label: 'Add Custom')
          save_button = Gtk::Button.new(label: 'Save')
          @delete_button = Gtk::Button.new(label: 'Delete Custom')
          reload_button = Gtk::Button.new(label: 'Reload')
          [add_button, save_button, @delete_button, reload_button].each do |button|
            buttons.pack_start(button, expand: false, fill: false, padding: 0)
          end
          editor.pack_start(buttons, expand: false, fill: true, padding: 0)

          @status_label = Gtk::Label.new('')
          add_button.signal_connect('clicked') { begin_new_custom }
          save_button.signal_connect('clicked') { save_current }
          @delete_button.signal_connect('clicked') { delete_current }
          reload_button.signal_connect('clicked') { reload! }

          clear_editor
          editor
        end

        # Wraps a label and input field in a horizontal row.
        #
        # @param label [Gtk::Label] field label
        # @param field [Gtk::Widget] editable field widget
        # @return [Gtk::Box] labeled row
        # @api private
        def labeled_row(label, field)
          label.set_width_chars(22)
          row = Gtk::Box.new(:horizontal, 5)
          row.pack_start(label, expand: false, fill: false, padding: 0)
          row.pack_start(field, expand: true, fill: true, padding: 0)
          row
        end

        # Rebuilds the frontend list and restores a preferred selection when possible.
        #
        # @param preferred_id [String, nil] frontend id to reselect
        # @return [void]
        # @api private
        def populate_list(preferred_id: nil)
          @model.clear
          @row_iters = {}
          @selected_id = nil

          current = @settings.current
          builtins = current.fetch('builtins', {})
          custom = current.fetch('custom', {})

          @frontend.built_in_frontends.each do |frontend_id|
            append_row(
              frontend_id,
              @frontend.display_name(frontend_id),
              'Built-in',
              builtins.fetch(frontend_id, {})
            )
          end
          custom.keys.sort.each do |frontend_id|
            definition = custom.fetch(frontend_id)
            append_row(frontend_id, definition.fetch('label'), 'Custom', definition)
          end

          target = @row_iters[preferred_id] || @row_iters.values.first
          if target
            @tree_view.selection.select_iter(target)
          else
            clear_editor
          end
        end

        # Appends one built-in or custom frontend to the list model.
        #
        # @param frontend_id [String] stable frontend identifier
        # @param label [String] display label
        # @param type [String] visible frontend type
        # @param settings [Hash] persisted launch settings
        # @return [void]
        # @api private
        def append_row(frontend_id, label, type, settings)
          iter = @model.append
          resolution = resolve(frontend_id) unless type == 'Custom'
          iter[ID_COLUMN] = frontend_id
          iter[LABEL_COLUMN] = label
          iter[TYPE_COLUMN] = type
          iter[STATUS_COLUMN] = status_text(type, resolution)
          iter[LAUNCH_COLUMN] = launch_text(type, settings, resolution)
          iter[ARGUMENTS_COLUMN] = format_arguments(settings.fetch('arguments', []))
          @row_iters[frontend_id] = iter
        end

        # Resolves a frontend while treating discovery failures as unavailable status.
        #
        # @param frontend_id [String] stable frontend identifier
        # @return [FrontendLocator::Resolution, nil]
        # @api private
        def resolve(frontend_id)
          @locator.resolve(frontend_id)
        rescue ArgumentError, SystemCallError
          nil
        end

        # Formats the detection status for a frontend list row.
        #
        # @param type [String] visible frontend type
        # @param resolution [FrontendLocator::Resolution, nil] executable resolution
        # @return [String] display status
        # @api private
        def status_text(type, resolution)
          return 'Configured' if type == 'Custom'
          return 'Unavailable' unless resolution
          return 'Configured' if resolution.source == :configured

          'Detected'
        end

        # Selects the configured or detected launch value for a frontend row.
        #
        # @param type [String] visible frontend type
        # @param settings [Hash] persisted launch settings
        # @param resolution [FrontendLocator::Resolution, nil] executable resolution
        # @return [String] executable path or custom command
        # @api private
        def launch_text(type, settings, resolution)
          return settings.fetch('command') if type == 'Custom'

          settings['executable'] || resolution&.executable_path.to_s
        end

        # Loads the selected frontend record into the editor controls.
        #
        # @param iter [Gtk::TreeIter] selected list-store row
        # @return [void]
        # @api private
        def load_selected(iter)
          @editing_new = false
          @selected_id = iter[ID_COLUMN]
          built_in = built_in?(@selected_id)
          settings = @settings.settings_for(@selected_id) || {}
          definition = @frontend.definition_for(@selected_id)

          @id_entry.text = @selected_id
          @label_entry.text = @frontend.display_name(@selected_id)
          @command_entry.text = built_in ? settings.fetch('executable', '') : settings.fetch('command', '')
          @directory_entry.text = built_in ? '' : settings.fetch('directory', '')
          @arguments_entry.text = format_arguments(settings.fetch('arguments', []))
          set_capabilities(definition.fetch(:capabilities))
          configure_editor(built_in: built_in, new_custom: false)
          report_status('')
        rescue ArgumentError => error
          report_error(error.message)
        end

        # Switches the editor to a blank custom-frontend record.
        #
        # @return [void]
        # @api private
        def begin_new_custom
          @tree_view.selection.unselect_all
          @editing_new = true
          @selected_id = nil
          @id_entry.text = ''
          @label_entry.text = ''
          @command_entry.text = ''
          @directory_entry.text = ''
          @arguments_entry.text = ''
          set_capabilities([])
          configure_editor(built_in: false, new_custom: true)
          report_status('Enter a stable ID, label, command, and declared capabilities.')
        end

        # Clears and disables the editor when no frontend is selected.
        #
        # @return [void]
        # @api private
        def clear_editor
          @editing_new = false
          @selected_id = nil
          [@id_entry, @label_entry, @command_entry, @directory_entry, @arguments_entry].each do |entry|
            entry.text = ''
            entry.sensitive = false
          end
          set_capabilities([])
          @capability_checks.each_value { |check| check.sensitive = false }
          @delete_button.sensitive = false
        end

        # Configures editable controls for built-in, existing custom, or new records.
        #
        # @param built_in [Boolean] whether the selected frontend is built in
        # @param new_custom [Boolean] whether a new custom frontend is being created
        # @return [void]
        # @api private
        def configure_editor(built_in:, new_custom:)
          @id_entry.sensitive = new_custom
          @label_entry.sensitive = !built_in
          @command_entry.sensitive = true
          @directory_entry.sensitive = !built_in
          @arguments_entry.sensitive = true
          @capability_checks.each_value { |check| check.sensitive = !built_in }
          @delete_button.sensitive = !built_in && !new_custom
          @command_label.text = built_in ? 'Executable override:' : 'Command:'
        end

        # Applies a frontend's capability set to the capability checkboxes.
        #
        # @param capabilities [Array<String, Symbol>] selected capabilities
        # @return [void]
        # @api private
        def set_capabilities(capabilities)
          selected = capabilities.map(&:to_sym)
          @capability_checks.each do |capability, check|
            check.active = selected.include?(capability)
          end
        end

        # Validates and persists the frontend currently shown in the editor.
        #
        # @return [Boolean] true when the configuration was saved
        # @api private
        def save_current
          raise ArgumentError, 'Select a frontend or choose Add Custom first.' unless @selected_id || @editing_new

          document = @settings.current
          builtins = document.fetch('builtins', {}).dup
          custom = document.fetch('custom', {}).dup

          if @editing_new
            frontend_id = validate_new_id(@id_entry.text)
            custom[frontend_id] = custom_definition
          elsif built_in?(@selected_id)
            frontend_id = @selected_id
            update_builtin(builtins, frontend_id)
          else
            frontend_id = @selected_id
            raise ArgumentError, "Custom frontend no longer exists: #{frontend_id}" unless custom.key?(frontend_id)

            custom[frontend_id] = custom_definition
          end

          replace_configuration(builtins, custom)
          populate_list(preferred_id: frontend_id)
          report_status("Saved #{@frontend.display_name(frontend_id)}.")
          notify_changed
          true
        rescue StandardError => error
          report_error(error.message)
          false
        end

        # Updates or removes persisted launch overrides for a built-in frontend.
        #
        # @param builtins [Hash] mutable built-in settings map
        # @param frontend_id [String] stable built-in frontend identifier
        # @return [void]
        # @api private
        def update_builtin(builtins, frontend_id)
          executable = optional_scalar('Executable override', @command_entry.text)
          arguments = parse_arguments
          if executable.nil? && arguments.empty?
            builtins.delete(frontend_id)
          else
            settings = {}
            settings['executable'] = executable if executable
            settings['arguments'] = arguments unless arguments.empty?
            builtins[frontend_id] = settings
          end
        end

        # Builds a custom frontend definition from the editor controls.
        #
        # @return [Hash] normalized custom frontend fields
        # @api private
        def custom_definition
          {
            'label'        => required_scalar('Label', @label_entry.text),
            'command'      => required_scalar('Command', @command_entry.text),
            'directory'    => optional_scalar('Working directory', @directory_entry.text),
            'arguments'    => parse_arguments,
            'capabilities' => selected_capabilities.map(&:to_s)
          }.compact
        end

        # Validates and normalizes a new custom frontend identifier.
        #
        # @param raw_id [String] candidate frontend identifier
        # @return [String] normalized frontend identifier
        # @raise [ArgumentError] when the identifier is invalid or already registered
        # @api private
        def validate_new_id(raw_id)
          frontend_id = raw_id.to_s.strip.downcase
          unless frontend_id.match?(FrontendSettings::CUSTOM_ID_PATTERN)
            raise ArgumentError, 'Stable ID must use 1-64 lowercase letters, numbers, underscores, or hyphens.'
          end
          if @frontend.registered_frontends.include?(frontend_id)
            raise ArgumentError, "Frontend ID is already in use: #{frontend_id}"
          end

          frontend_id
        end

        # Validates a required printable scalar from the editor.
        #
        # @param name [String] field name used in validation messages
        # @param value [Object] candidate field value
        # @return [String] normalized non-empty scalar
        # @raise [ArgumentError] when the value is missing or invalid
        # @api private
        def required_scalar(name, value)
          value = optional_scalar(name, value)
          raise ArgumentError, "#{name} is required." unless value

          value
        end

        # Validates an optional bounded printable scalar from the editor.
        #
        # @param name [String] field name used in validation messages
        # @param value [Object] candidate field value
        # @return [String, nil] normalized value or nil when blank
        # @raise [ArgumentError] when the value is too long or contains controls
        # @api private
        def optional_scalar(name, value)
          value = value.to_s.strip
          return nil if value.empty?
          if value.bytesize > FrontendSettings::MAX_SCALAR_BYTES
            raise ArgumentError, "#{name} is too long."
          end
          if value.match?(/[\x00-\x1f\x7f]/)
            raise ArgumentError, "#{name} contains unsupported control characters."
          end

          value
        end

        # Parses and validates shell-style additional arguments from the editor.
        #
        # @return [Array<String>] parsed arguments
        # @raise [ArgumentError] when quoting or an argument is invalid
        # @api private
        def parse_arguments
          arguments = Shellwords.split(@arguments_entry.text.to_s)
          FrontendSettings.validate_arguments(arguments)
        rescue ArgumentError => error
          raise error if error.message.start_with?('Additional arguments', 'Argument')

          raise ArgumentError, "Additional arguments are invalid: #{error.message}"
        end

        # Returns the capability names selected in the editor.
        #
        # @return [Array<Symbol>] selected capabilities
        # @api private
        def selected_capabilities
          @capability_checks.filter_map do |capability, check|
            capability if check.active?
          end
        end

        # Persists a complete configuration and invalidates discovery results.
        #
        # @param builtins [Hash] complete built-in settings map
        # @param custom [Hash] complete custom frontend map
        # @return [void]
        # @api private
        def replace_configuration(builtins, custom)
          @settings.replace!(data_dir: @data_dir, builtins: builtins, custom: custom)
          @locator.refresh!
        end

        # Deletes the selected custom frontend and refreshes the editor list.
        #
        # @return [Boolean] true when the frontend was deleted
        # @api private
        def delete_current
          raise ArgumentError, 'Select a custom frontend to delete.' unless @selected_id
          raise ArgumentError, 'Built-in frontends cannot be deleted.' if built_in?(@selected_id)

          frontend_id = @selected_id
          document = @settings.current
          builtins = document.fetch('builtins', {}).dup
          custom = document.fetch('custom', {}).dup
          raise ArgumentError, "Custom frontend no longer exists: #{frontend_id}" unless custom.delete(frontend_id)

          replace_configuration(builtins, custom)
          populate_list
          report_status("Deleted custom frontend #{frontend_id}.")
          notify_changed
          true
        rescue StandardError => error
          report_error(error.message)
          false
        end

        def built_in?(frontend_id)
          @frontend.built_in_frontends.include?(frontend_id)
        end

        def format_arguments(arguments)
          Shellwords.join(Array(arguments))
        end

        def notify_changed
          @on_changed&.call
        end

        def report_status(message)
          @status_label.text = message
        end

        def report_error(message)
          report_status("Error: #{message}")
        end
      end
    end
  end
end
