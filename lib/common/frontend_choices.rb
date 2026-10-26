# frozen_string_literal: true

require_relative 'frontend'
require_relative 'frontend_locator'

module Lich
  module Common
    # The frontends a player may pick from, and what is known about each.
    #
    # Extracted from the retired GTK frontend selector. Native launcher
    # pickers share its catalog ordering and configured/detected/unavailable
    # annotations, including frontends supplied by the player's settings.
    #
    # Discovery annotates choices and never removes them: a configurable
    # frontend stays selectable even when its executable cannot be found, so
    # the player can still choose it and fix the path afterwards.
    module FrontendChoices
      # One selectable frontend: its canonical id, the label shown in a picker
      # (display name plus state), its discovery state (:configured, :detected
      # or :unavailable) and the bare display name.
      Choice = Struct.new(:id, :label, :state, :display_name, keyword_init: true) do
        # Whether the frontend can actually be launched right now.
        #
        # @return [Boolean] false only when the state is :unavailable
        def available?
          state != :unavailable
        end

        # The choice as a plain hash with the state stringified, for a contract payload.
        #
        # @return [Hash{Symbol => String}] :id, :label, :state and :display_name
        def to_h
          { id: id, label: label, state: state.to_s, display_name: display_name }
        end
      end

      class << self
        # Every frontend the player may select, catalog order, with the
        # historical GUI default first.
        #
        # @param refresh [Boolean] re-run executable discovery first
        # @param locator [#available] injectable discovery API
        # @param frontend [#definitions] injectable catalog API
        # @return [Array<Choice>]
        def all(refresh: true, locator: FrontendLocator, frontend: Frontend)
          resolved = resolved_ids(refresh: refresh, locator: locator, frontend: frontend)
          definitions(frontend).map { |definition| choice_for(definition, resolved) }
        end

        # The same list as plain hashes, for a contract that carries options.
        #
        # @param keywords [Hash] passed through to {.all} (refresh:, locator:, frontend:)
        # @return [Array<Hash{Symbol => String}>] one {Choice#to_h} per choice
        def options(**keywords)
          all(**keywords).map(&:to_h)
        end

        # Whether +frontend_id+ is one the player may select.
        #
        # The id is canonicalised through the supplied frontend catalog first, so an alias
        # of a selectable frontend is selectable too.
        #
        # @param frontend_id [String, Symbol, nil] frontend identifier or alias
        # @param keywords [Hash] passed through to {.all} (refresh:, locator:, frontend:)
        # @return [Boolean] false for a blank id or one not in the catalog
        def selectable?(frontend_id, **keywords)
          return false if frontend_id.to_s.strip.empty?

          canonical = keywords.fetch(:frontend, Frontend).canonical_name(frontend_id)
          all(**keywords).any? { |choice| choice.id == canonical }
        end

        private

        # Filters GUI choices for the platform and retains catalog order after the default frontend.
        # @return [Array<Hash>] selectable definitions
        def definitions(frontend)
          selectable = frontend.definitions(gui_selectable: true).select do |definition|
            platforms = definition.dig(:metadata, :gui_platforms)
            platforms.nil? || platforms.include?(frontend.platform_key)
          end
          # Catalog order is preserved; stormfront is pinned first because it
          # has always been the default the GUI opens on.
          stormfront, others = selectable.partition { |definition| definition[:id] == 'stormfront' }
          stormfront + others
        end

        # Builds an advisory availability index; failed discovery does not remove choices.
        # @return [Hash] canonical frontend IDs found by the locator
        def resolved_ids(refresh:, locator:, frontend:)
          locator.available(gui_selectable: true, refresh: refresh).to_h do |resolution|
            [frontend.canonical_name(resolution.frontend_id), true]
          end
        rescue StandardError
          # Discovery is an annotation, not a gate. A locator that cannot run
          # leaves every frontend selectable rather than emptying the list.
          {}
        end

        # Annotates a frontend choice with its display name and discovery/configuration state.
        # @return [Choice]
        def choice_for(definition, resolved)
          display = definition.dig(:metadata, :display_name) || definition[:id].capitalize
          state = state_for(definition, resolved)
          Choice.new(
            id: definition[:id], display_name: display,
            label: "#{display} (#{state})", state: state
          )
        end

        # A custom frontend the player has given a launch command to is
        # configured whether or not discovery found anything; a built-in is
        # detected only when its executable was actually located.
        # @api private
        def state_for(definition, resolved)
          return :configured if configured_custom?(definition)
          return :detected if resolved.key?(definition[:id])

          :unavailable
        end

        # Recognizes a custom adapter with a nonblank configured launch command.
        # @return [Boolean]
        def configured_custom?(definition)
          definition.dig(:metadata, :launcher_adapter) == :custom &&
            !definition.dig(:metadata, :launch_command).to_s.strip.empty?
        end
      end
    end
  end
end
