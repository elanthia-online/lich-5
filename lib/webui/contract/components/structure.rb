# frozen_string_literal: true

module Lich
  module WebUI
    module Contract
      class << self
        private

        # Supplies the structure component declarations to the Contract facade.
        # @return [Hash] base schemas in declaration order
        def structure_schemas
          {
            page: {
              properties: {
                title: property(SHORT, required: true), bare: property(BOOL, default: false),
                theme: property(enum(:light, :dark)), density: property(enum(:compact, :normal)),
                viewport: property(BOOL, default: false),
                presentation: property(PRESENTATION),
                size: property(array(GEOMETRY, min: 2, max: 2)),
                resize_request: property(record(id: property(IDENT, required: true),
                                                size: property(array(integer(min: 1, max: BOUNDS[:geometry].end), min: 2, max: 2), required: true))),
                position: property(array(integer(min: -65_536, max: 65_536), min: 2, max: 2)),
              }, children: :many, events: {}, value: nil,
            },
            group: {
              # Omission means no label widget; an empty string retains the blank label requisition.
              properties: { label: property(SHORT), collapsible: property(BOOL, default: false),
                            menu: property(enum(:context, :submenu, :popover)),
                            menu_position: property(enum(:top, :bottom, :left, :right)), menu_icon: property(BOOL),
                            open: property(BOOL, scope: :viewer),
                            popup_position: property(array(GEOMETRY, min: 2, max: 2), scope: :viewer), constrain_width: property(BOOL, default: false) },
              children: :many, events: {}, value: nil,
            },
            stack: {
              properties: { gap: property(integer(min: 0, max: 64), default: 8),
                            orientation: property(enum(:vertical, :horizontal), default: 'vertical') },
              children: :many, events: {}, value: nil,
            },
            columns: {
              properties: {
                count: property(integer(min: 1, max: 12), required: true),
                weights: property(array(integer(min: 0), max: 12)), compact: property(BOOL, default: false),
                row_align: property(enum(:start, :center, :end, :stretch)),
                gap: property(integer(min: 0, max: 64), default: 8),
              }, children: { kind: :named_dynamic, count_property: :count }, events: {}, value: nil,
            },
            grid: {
              properties: {
                flow: property(BOOL),
                cols: property(integer(min: 1, max: 24), required: true),
                homogeneous: property(BOOL, default: true), equal_rows: property(BOOL, default: false),
                expand_columns: property(array(integer(min: 1, max: 24), max: 24)),
                row_sizing: property(enum(:auto, :spread), default: :auto),
                cells: property(integer(min: 0, max: BOUNDS[:children])),
                gap: property(integer(min: 0, max: 64), default: 8),
                row_gap: property(integer(min: 0, max: 64)), column_gap: property(integer(min: 0, max: 64)),
              }, children: :many, child_properties: {
                column: property(integer(min: 1, max_property: :cols)),
                row: property(integer(min: 1, max: BOUNDS[:children])),
                span: property(integer(min: 1, max_property: :cols)),
                row_span: property(integer(min: 1, max: BOUNDS[:children])),
              }, events: {}, value: nil,
            },
            tabs: {
              properties: {
                names: property(array(SHORT, max: BOUNDS[:collection]), required: true),
                vertical: property(BOOL, default: false), selected: property(integer(min: 0), scope: :viewer),
                size_to_all: property(BOOL, default: false),
                show_tabs: property(BOOL, default: true),
              }, children: { kind: :named_from_property, property: :names },
              child_properties: { tab_action: property(enum(:start, :end)) },
              events: { select: event(record(index: property(integer(min: 0), required: true), tab: property(IDENT)), structural: true) }, value: nil,
            },
            expander: {
              properties: { label: property(SHORT, required: true), open: property(BOOL, default: false, scope: :viewer) },
              children: :many, events: { toggle: event(record(open: property(BOOL, required: true)), structural: true) }, value: nil,
            },
            split: {
              properties: {
                orientation: property(enum(:horizontal, :vertical), required: true),
                position: property(integer(min: 0, max: 100), scope: :viewer),
                position_pixels: property(integer(min: 0, max: 65_536)),
                resize_side: property(enum(:first)),
              }, children: { kind: :named, slots: %w[first second] },
              events: { move: event(record(position: property(integer(min: 0, max: 100), required: true))) }, value: nil,
            },
            overlay: {
              properties: { positioned: property(BOOL, default: false), clip_children: property(BOOL, default: false) }, children: :many,
              child_properties: { z: property(integer(min: 0, max: 99)), pass_through: property(BOOL),
                                  x: property(GEOMETRY), y: property(GEOMETRY) }, events: {}, value: nil,
            },
            scroll: {
              properties: {
                max_height: property(GEOMETRY), scroll_to: property(IDENT, scope: :viewer),
                fill: property(BOOL, default: false), scrollbars: property(BOOL, default: true),
                scroll_position: property(SCROLL_PIXELS, scope: :viewer),
                scroll_position_x: property(SCROLL_PIXELS, scope: :viewer),
                scroll_revision: property(integer(min: 0, max: 2_147_483_647), scope: :viewer),
                scroll_revision_x: property(integer(min: 0, max: 2_147_483_647), scope: :viewer),
                initial_scroll: property(record(x: property(SCROLL_PIXELS, required: true), y: property(SCROLL_PIXELS, required: true))),
              },
              children: :many,
              events: { scrolled: event(record(
                                          position: property(SCROLL_PIXELS, required: true),
                                          upper: property(SCROLL_PIXELS),
                                          page_size: property(SCROLL_PIXELS),
                                          position_x: property(SCROLL_PIXELS), upper_x: property(SCROLL_PIXELS),
                                          page_size_x: property(SCROLL_PIXELS)
                                        )) }, value: nil,
            },
            divider: { properties: { label: property(SHORT) }, children: :none, events: {}, value: nil },
          }
        end
      end
    end
  end
end
