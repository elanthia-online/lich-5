# frozen_string_literal: true

require_relative '../frontend'
require_relative '../frontend_launcher'
require_relative '../frontend_locator'

module Lich
  module Common
    module GUI
      # Shared GTK frontend selector backed by the frontend catalog.
      # Discovery annotates choices but never removes configurable frontends.
      class FrontendSelector
        attr_reader :widget, :resolutions

        # Initializes a catalog-backed frontend dropdown.
        #
        # @param selected_id [String, nil] preferred frontend identifier
        # @param refresh [Boolean] refresh executable discovery first
        # @param locator [FrontendLocator] injectable locator API
        # @param frontend [Frontend] injectable frontend catalog API
        # @return [FrontendSelector]
        def initialize(selected_id: nil, refresh: true, locator: FrontendLocator, frontend: Frontend)
          @locator = locator
          @frontend = frontend
          refresh_catalog(refresh: refresh)
          @widget = build_widget(selected_id)
        end

        # Reloads configured definitions and executable status in-place so
        # callers do not need to replace widgets after the Frontends tab saves.
        # The current stable frontend id is retained when it remains selectable.
        #
        # @param refresh [Boolean] refresh executable discovery first
        # @return [FrontendSelector]
        def reload!(refresh: true)
          selected_id = self.selected_id
          refresh_catalog(refresh: refresh)
          @widget.remove_all
          @definitions.each do |definition|
            @widget.append(definition[:id], option_label(definition))
          end
          @widget.active_id = preferred_id(selected_id)
          update_tooltip(@widget)
          self
        end

        # Returns the selected stable frontend identifier.
        #
        # @return [String, nil]
        def selected_id
          @widget.active_id
        end

        # Returns whether the selected frontend disallows custom launch.
        #
        # @return [Boolean]
        def native_launch_only?
          return false unless selected_id

          @frontend.definition_for(selected_id).dig(:metadata, :native_launch_only) == true
        end

        # Registers a callback for changes to the selected frontend option.
        # @yield [FrontendSelector]
        # @return [void]
        def on_change(&callback)
          @widget.signal_connect('changed') { callback.call(self) }
          nil
        end

        # Revalidates the selected executable immediately before launch.
        # @param refresh [Boolean] bypass cached discovery when true
        # @return [FrontendLocator::Resolution, nil]
        def resolve_selected(refresh: true)
          return nil unless selected_id

          @locator.resolve(selected_id, refresh: refresh)
        end

        # Returns whether the selected frontend has enough configuration to
        # attempt a launch. Custom commands may resolve through PATH or a shell,
        # so executable discovery is intentionally limited to native adapters.
        #
        # @param refresh [Boolean] bypass cached discovery when true
        # @return [Boolean]
        def launchable?(refresh: true)
          return false unless selected_id

          FrontendLauncher.launchable?(
            selected_id,
            locator: @locator,
            frontend: @frontend,
            refresh: refresh
          )
        end

        # Returns whether the frontend catalog has no selectable definitions.
        #
        # @return [Boolean]
        def empty?
          @definitions.empty?
        end

        # Stable ids and annotated labels shared by form and inline selectors.
        # @return [Array<Array<String>>] frontend choices
        def choices
          @definitions.map { |definition| [definition[:id], option_label(definition)] }
        end

        private

        # Refreshes executable resolutions and platform-compatible definitions.
        #
        # @param refresh [Boolean] refresh executable discovery first
        # @return [void]
        # @api private
        def refresh_catalog(refresh:)
          @resolutions = @locator.available(gui_selectable: true, refresh: refresh)
          @resolution_by_id = @resolutions.to_h do |resolution|
            [@frontend.canonical_name(resolution.frontend_id), resolution]
          end
          @definitions = configurable_definitions
        end

        # Builds the frontend dropdown and applies its initial selection.
        #
        # @param selected_id [String, nil] preferred frontend identifier
        # @return [Gtk::ComboBoxText] configured dropdown
        # @api private
        def build_widget(selected_id)
          combo = Gtk::ComboBoxText.new
          @definitions.each do |definition|
            combo.append(definition[:id], option_label(definition))
          end

          preferred = preferred_id(selected_id)
          combo.active_id = preferred if preferred
          combo.signal_connect('changed') { update_tooltip(combo) }
          update_tooltip(combo)
          combo
        end

        # Chooses the requested, historical default, or first available frontend.
        #
        # @param selected_id [String, nil] requested frontend identifier
        # @return [String, nil] selectable frontend identifier
        # @api private
        def preferred_id(selected_id)
          ids = @definitions.map { |definition| definition[:id] }
          requested = @frontend.canonical_name(selected_id)
          return requested if ids.include?(requested)
          return 'stormfront' if ids.include?('stormfront')

          ids.first
        end

        # Returns GUI-selectable frontend definitions supported on this platform.
        #
        # @return [Array<Hash>] ordered frontend definitions
        # @api private
        def configurable_definitions
          definitions = @frontend.definitions(gui_selectable: true).select do |definition|
            platforms = definition.dig(:metadata, :gui_platforms)
            platforms.nil? || platforms.include?(@frontend.platform_key)
          end

          # Preserve catalog order while pinning the historical GUI default first.
          stormfront, others = definitions.partition { |definition| definition[:id] == 'stormfront' }
          stormfront + others
        end

        # Formats a frontend option with its current discovery state.
        #
        # @param definition [Hash] immutable frontend definition
        # @return [String] dropdown label
        # @api private
        def option_label(definition)
          label = definition.dig(:metadata, :display_name) || definition[:id].capitalize
          state = if configured_custom?(definition)
                    'configured'
                  elsif @resolution_by_id.key?(definition[:id])
                    'detected'
                  else
                    'unavailable'
                  end
          "#{label} (#{state})"
        end

        # Updates the dropdown tooltip for its active frontend.
        #
        # @param combo [Gtk::ComboBoxText] frontend dropdown
        # @return [void]
        # @api private
        def update_tooltip(combo)
          frontend_id = combo.active_id
          return combo.tooltip_text = nil unless frontend_id

          definition = @frontend.definition_for(frontend_id)
          resolution = @resolution_by_id[frontend_id]
          status = if configured_custom?(definition)
                     definition.dig(:metadata, :launch_command)
                   elsif resolution
                     resolution.executable_path
                   else
                     "#{@frontend.display_name(frontend_id)} is not currently detected"
                   end
          launch_notice = definition.dig(:metadata, :launch_notice)
          combo.tooltip_text = [status, launch_notice].compact.join("\n")

          nil
        end

        # Returns whether a definition has a usable custom launch command.
        #
        # @param definition [Hash] immutable frontend definition
        # @return [Boolean]
        # @api private
        def configured_custom?(definition)
          definition.dig(:metadata, :launcher_adapter) == :custom &&
            !definition.dig(:metadata, :launch_command).to_s.strip.empty?
        end
      end
    end
  end
end
