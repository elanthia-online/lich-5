# frozen_string_literal: true

require_relative '../front-end'
require_relative '../frontend_locator'

module Lich
  module Common
    module GUI
      # Shared GTK frontend selector backed by the non-GTK frontend locator.
      # Every GUI surface receives the same discovered, catalog-defined set.
      class FrontendSelector
        attr_reader :widget, :resolutions

        # @param selected_id [String, nil] preferred frontend identifier
        # @param refresh [Boolean] refresh executable discovery first
        # @param locator [FrontendLocator] injectable locator API
        def initialize(selected_id: nil, refresh: true, locator: FrontendLocator)
          @locator = locator
          @resolutions = locator.available(gui_selectable: true, refresh: refresh)
          @buttons = {}
          @widget = build_widget(selected_id)
        end

        # @return [String, nil] selected stable frontend identifier
        def selected_id
          pair = @buttons.find { |_frontend_id, button| button.active? }
          pair && pair.first
        end

        # @return [Boolean] whether the selected frontend disallows custom launch
        def native_launch_only?
          return false unless selected_id

          Frontend.definition_for(selected_id).dig(:metadata, :native_launch_only) == true
        end

        # Registers a callback for changes to any generated frontend option.
        # @yield [FrontendSelector]
        # @return [void]
        def on_change(&callback)
          @buttons.each_value do |button|
            button.signal_connect('toggled') { callback.call(self) if button.active? }
          end
          nil
        end

        # Revalidates the selected executable immediately before launch.
        # @param refresh [Boolean] bypass cached discovery when true
        # @return [FrontendLocator::Resolution, nil]
        def resolve_selected(refresh: true)
          return nil unless selected_id

          @locator.resolve(selected_id, refresh: refresh)
        end

        def empty?
          @buttons.empty?
        end

        private

        def build_widget(selected_id)
          box = Gtk::Box.new(:horizontal, 10)
          if @resolutions.empty?
            box.pack_start(
              Gtk::Label.new('No supported frontend detected'),
              expand: false,
              fill: false,
              padding: 0
            )
            return box
          end

          leader = nil
          @resolutions.each do |resolution|
            definition = Frontend.definition_for(resolution.frontend_id)
            label = definition.dig(:metadata, :display_name) || resolution.frontend_id.capitalize
            button = if leader
                       Gtk::RadioButton.new(label: label, member: leader)
                     else
                       Gtk::RadioButton.new(label: label)
                     end
            leader ||= button
            launch_notice = definition.dig(:metadata, :launch_notice)
            button.tooltip_text = [resolution.executable_path, launch_notice].compact.join("\n")
            @buttons[resolution.frontend_id] = button
            box.pack_start(button, expand: false, fill: false, padding: 0)
          end

          preferred = preferred_id(selected_id)
          @buttons.fetch(preferred).active = true
          box
        end

        def preferred_id(selected_id)
          requested = Frontend.canonical_name(selected_id)
          return requested if @buttons.key?(requested)
          return 'stormfront' if @buttons.key?('stormfront')

          @buttons.keys.first
        end
      end
    end
  end
end
