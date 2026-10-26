# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Viewer-local selection facade; script callbacks observe the originating viewer.
        class TreeSelection < ModelObject
          attr_reader :mode

          # Creates a single-selection facade using its owning view session.
          # @param view [TreeView] owning table
          def initialize(view)
            super(session: view.session)
            @session, @view, @mode, @handlers = view.session, view, :single, []
          end

          # Selects the supported selection policy and reconciles existing choices.
          # @param mode [Symbol] :none, :single, :browse or :multiple
          # @return [Symbol]
          def mode=(mode)
            session.refuse(self, :mode=) unless %i[none single browse multiple].include?(mode)
            @view.selection_mode_changed(mode)
            @mode = mode
          end
          alias set_mode mode=

          # GTK passes selection, model, current path and prior membership.
          # Ruby blocks may ignore unused arguments, as container-window does.
          # @param predicate [Proc] selection filter receiving selection, model, path and prior membership
          # @return [TreeSelection] self
          def set_select_function(&predicate)
            session.refuse(self, :set_select_function) unless predicate
            @select_function = predicate
            self
          end

          # Filter transitions without mutating accepted selection. Core remains
          # the only viewer-state authority for browser and programmatic paths.
          # @param previous [Array<String>] previous stable selected row identities
          # @param requested [Array<String>] requested stable row identities
          # @return [Array<String>] accepted surviving row identities
          def filter_keys(previous, requested)
            model = @view.model
            live = model ? model.rows.map(&:key) : []
            previous = previous & live
            requested = requested & live
            return requested unless @select_function

            session.refuse(self, :select_function_recursion) if @filtering
            @filtering = entered = true
            accepted = previous.dup
            (previous - requested).each do |key|
              accepted.delete(key) if permits?(model, key, true)
            end
            (requested - previous).each do |key|
              next if mode != :multiple && !accepted.empty?
              accepted << key if permits?(model, key, false)
            end
            retain = mode == :browse || (mode == :single && !requested.empty?)
            accepted = previous if retain && accepted.empty? && !previous.empty?
            accepted
          ensure
            @filtering = false if entered
          end

          # Validates a selection predicate result against the unchanged model revision.
          # @param model [ListStore, TreeStore] same-session backing model
          # @param key [String] stable row identity
          # @param selected [Boolean] whether the row was previously selected
          # @api private
          def permits?(model, key, selected)
            revision = model.revision
            result = @select_function.call(self, model, model.find_key(key).path, selected)
            session.refuse(self, :select_function_result) unless [true, false].include?(result) && revision == model.revision
            result
          end
          private :permits?

          # Reads the originating viewer's single selection; multiple mode requires iteration.
          # @return [TreeIter, nil] selected row; multiple mode requires selected_rows/selected_each
          def selected
            session.refuse(self, :selected) if mode == :multiple
            @view.selected_iters.first
          end

          # Returns paths before the model, matching the GTK3 Ruby binding's out-parameter order.
          # @return [Array(Array<TreePath>, ListStore)] selected paths and their model
          def selected_rows = [@view.selected_iters.map(&:path), @view.model]
          # Counts surviving rows selected by the originating viewer.
          # @return [Integer] number of selected surviving rows
          def count_selected_rows = @view.selected_iters.length
          # Checks membership in the originating viewer selection.
          # @param iter [TreeIter] live row in the owning view model
          def iter_is_selected?(iter) = @view.selected_iters.include?(iter)
          # Resolves a current model path before checking selection membership.
          # @param path [TreePath, String, Array<Integer>] current model path
          def path_is_selected?(path) = iter_is_selected?(@view.model&.get_iter(path))

          # Yields independent row handles in current model order.
          # @yieldparam model [ListStore] current model
          # @yieldparam path [TreePath] current path
          # @yieldparam iter [TreeIter] independent selected row
          # @return [Enumerator, Array<TreeIter>]
          def selected_each
            return enum_for(:selected_each) unless block_given?
            @view.selected_iters.each { |iter| yield @view.model, iter.path, iter }
          end

          # Selects a live model row, adding to the set only in multiple mode.
          # @param iter [TreeIter] live row in this view's model
          # @return [TreeSelection] self
          def select_iter(iter)
            session.refuse(self, :select_iter) unless @view.model&.iter_is_valid?(iter)
            keys = mode == :multiple ? @view.selected_iters.map(&:key) | [iter.key] : [iter.key]
            @view.select_keys(keys)
            self
          end

          # Selects the current row identified by a model path.
          # @param path [TreePath, String, Array<Integer>] current model path
          # @return [TreeSelection] self
          def select_path(path) = select_iter(@view.model&.get_iter(path))

          # Removes a selected row while respecting browse mode's required selection.
          # @param iter [TreeIter] live row to deselect
          # @return [TreeSelection] self
          def unselect_iter(iter)
            session.refuse(self, :unselect_iter) unless @view.model&.iter_is_valid?(iter)
            @view.select_keys(@view.selected_iters.map(&:key) - [iter.key])
            self
          end

          # Deselects the current row while respecting browse selection policy.
          # @param path [TreePath, String, Array<Integer>] current model path
          # @return [TreeSelection] self
          def unselect_path(path) = unselect_iter(@view.model&.get_iter(path))
          # Requests an empty selection through the owning view policy.
          # @return [TreeView] owning view after its selection policy runs
          def unselect_all = @view.select_keys([])

          # Selects every current model row in multiple mode.
          # @return [TreeView] selects all rows only in multiple mode
          def select_all
            session.refuse(self, :select_all) unless mode == :multiple
            @view.select_keys(@view.model ? @view.model.rows.map(&:key) : [])
          end

          # Registers only the signal supported by this compatibility object.
          # @param name [String, Symbol] changed
          # @param handler [Proc] callback invoked with this object and its signal arguments
          # @yieldparam selection [TreeSelection] this facade
          # @return [Integer] connection count
          def signal_connect(name, &handler)
            session.refuse(self, :signal_connect) unless name.to_s == 'changed' && handler
            @handlers << handler
            @handlers.length
          end

          # Invokes a snapshot of selection-change listeners.
          # @return [void] result is not part of the supported script contract
          def changed! = @handlers.dup.each { |handler| handler.call(self) }
        end
      end
    end
  end
end
