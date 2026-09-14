# frozen_string_literal: true

require_relative '../frontend'
require_relative '../frontend_launcher'
require_relative '../frontend_locator'

module Lich
  module Common
    module GUI
      # Manual Login offers detected clients and an explicit custom-command path.
      # Configuration surfaces use FrontendSelector to include unavailable clients.
      class ManualFrontendSelector
        CUSTOM_ID = '__custom__'

        attr_reader :widget

        # @param selected_id [String, nil] preferred frontend identity
        # @param refresh [Boolean] refresh executable discovery
        # @param locator [FrontendLocator] discovery API
        # @return [ManualFrontendSelector]
        def initialize(selected_id: nil, refresh: true, locator: FrontendLocator)
          @locator = locator
          @callbacks = []
          @widget = Gtk::Box.new(:horizontal, 10)
          rebuild(selected_id, refresh: refresh)
        end

        # Custom uses Wrayth's protocol identity, not its executable.
        # @return [String] stable frontend identity for authentication and storage
        def selected_id
          custom? ? 'stormfront' : @selection
        end

        # @return [Boolean] whether an explicit custom command is required
        def custom?
          @selection == CUSTOM_ID
        end

        # @return [Boolean] whether custom launch is unsupported for this client
        def native_launch_only?
          !custom? && Frontend.definition_for(selected_id).dig(:metadata, :native_launch_only) == true
        end

        # @param refresh [Boolean] refresh executable discovery
        # @return [Boolean] whether the native selection can launch
        def launchable?(refresh: true)
          !custom? && FrontendLauncher.launchable?(selected_id, locator: @locator, refresh: refresh)
        end

        # @yield [ManualFrontendSelector] updated selector
        # @return [void]
        def on_change(&callback)
          @callbacks << callback
          nil
        end

        # Retains the chosen client, or selects Custom if it disappears.
        # @param refresh [Boolean] refresh executable discovery
        # @return [ManualFrontendSelector]
        def reload!(refresh: true)
          rebuild(@selection, refresh: refresh)
          @callbacks.each { |callback| callback.call(self) }
          self
        end

        private

        # @param preferred [String, nil] requested radio choice
        # @param refresh [Boolean] refresh executable discovery
        # @return [void]
        # @api private
        def rebuild(preferred, refresh:)
          resolutions = @locator.available(gui_selectable: true, refresh: refresh)
          @rebuilding = true
          @widget.children.each(&:destroy)
          @buttons = {}
          resolutions.each do |resolution|
            id = Frontend.canonical_name(resolution.frontend_id)
            notice = Frontend.definition_for(id).dig(:metadata, :launch_notice)
            add_button(id, Frontend.display_name(id), [resolution.executable_path, notice].compact.join("\n"))
          end
          add_button(CUSTOM_ID, 'Custom', 'Use a custom launch command with Wrayth-compatible protocol.')
          requested = preferred == CUSTOM_ID ? CUSTOM_ID : Frontend.canonical_name(preferred)
          @selection = if @buttons.key?(requested)
                         requested
                       elsif preferred
                         CUSTOM_ID
                       elsif @buttons.key?('stormfront')
                         'stormfront'
                       else
                         @buttons.keys.first
                       end
          @buttons.fetch(@selection).active = true
          @widget.show_all
          @rebuilding = false
        end

        # @param id [String] radio identity
        # @param label [String] visible label
        # @param tooltip [String, nil] executable or custom launch explanation
        # @return [void]
        # @api private
        def add_button(id, label, tooltip)
          leader = @buttons.values.first
          button = leader ? Gtk::RadioButton.new(label: label, member: leader) : Gtk::RadioButton.new(label: label)
          button.tooltip_text = tooltip
          @buttons[id] = button
          button.signal_connect('toggled') do
            next unless button.active?

            @selection = id
            @callbacks.each { |callback| callback.call(self) } unless @rebuilding
          end
          @widget.pack_start(button, expand: false, fill: false, padding: 0)
        end
      end
    end
  end
end
