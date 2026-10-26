# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        module SelectionMode
          NONE = :none
          SINGLE = :single
          BROWSE = :browse
          MULTIPLE = :multiple
        end

        module SortType
          ASCENDING = :ascending
          DESCENDING = :descending
        end

        SELECTION_NONE = SelectionMode::NONE
        SELECTION_SINGLE = SelectionMode::SINGLE

        # Legacy spelling uses the same validated model sorting implementation.
        SORT_ASCENDING = SortType::ASCENDING
      end
    end
  end
end

# Keep the legacy entry path and definition order; boot loads later class extensions.
require_relative 'tree_view/renderers'
require_relative 'tree_view/column'
require_relative 'tree_view/selection'
require_relative 'tree_view/view'
