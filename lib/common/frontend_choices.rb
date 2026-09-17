# frozen_string_literal: true

require_relative 'frontend'
require_relative 'frontend_locator'

module Lich
  module Common
    # The frontends a player may pick from, and what is known about each.
    #
    # This is the catalog logic from the GTK frontend selector with the
    # dropdown taken off it. Both launchers need the same answer -- which
    # frontends exist, in what order, and whether each is configured, detected
    # or merely known about -- and only one of them can build a
    # Gtk::ComboBoxText. The WebUI launcher stored `frontend` as a free-form
    # string and never consulted the registry at all, so it could not offer a
    # frontend the player had configured.
    #
    # GUI::FrontendSelector still carries its own copy. It is working, its
    # copy is entangled with tooltips and in-place reload, and rewriting it
    # would put the launcher that people actually use at risk for no gain
    # here. When the GTK launcher is eventually retired this becomes the only
    # copy; until then the two must be changed together, and the behaviour
    # they share is spelled out in frontend_choices_spec.
    #
    # Discovery annotates choices and never removes them: a configurable
    # frontend stays selectable even when its executable cannot be found, so
    # the player can still choose it and fix the path afterwards.
    module FrontendChoices
      Choice = Struct.new(:id, :label, :state, :display_name, keyword_init: true) do
        # Whether the frontend can actually be launched right now.
        def available?
          state != :unavailable
        end

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
        def options(**keywords)
          all(**keywords).map(&:to_h)
        end

        # Whether +frontend_id+ is one the player may select.
        def selectable?(frontend_id, **keywords)
          return false if frontend_id.to_s.strip.empty?

          canonical = Frontend.canonical_name(frontend_id)
          all(**keywords).any? { |choice| choice.id == canonical }
        end

        private

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

        def resolved_ids(refresh:, locator:, frontend:)
          locator.available(gui_selectable: true, refresh: refresh).to_h do |resolution|
            [frontend.canonical_name(resolution.frontend_id), true]
          end
        rescue StandardError
          # Discovery is an annotation, not a gate. A locator that cannot run
          # leaves every frontend selectable rather than emptying the list.
          {}
        end

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
        def state_for(definition, resolved)
          return :configured if configured_custom?(definition)
          return :detected if resolved.key?(definition[:id])

          :unavailable
        end

        def configured_custom?(definition)
          definition.dig(:metadata, :launcher_adapter) == :custom &&
            !definition.dig(:metadata, :launch_command).to_s.strip.empty?
        end
      end
    end
  end
end
