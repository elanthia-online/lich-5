# frozen_string_literal: true

module Lich
  module WebUI
    module Contract
      module_function

      # Assembles and recursively freezes the bounded control/facility contract once.
      # Shared property families are added here so native and shim consumers agree.
      # @return [Hash] cached schemas keyed by type
      def schemas
        @schemas ||= begin
          schemas = {}
          TYPES.each do |type|
            base = deep_dup(BASE_SCHEMAS.fetch(type))
            base[:properties][:cursor_hint] = property(enum(:default, :pointer, :cell, :copy))
            base[:events].merge!(deep_dup(PAGE_LIFECYCLE_EVENTS)) if type == :page
            base[:properties].merge!(TABLE_PROPERTIES) if type == :table
            base[:events].merge!(TABLE_EVENTS) if type == :table
            ATTRIBUTE_APPLICABILITY.fetch(type).each do |attribute|
              next if base[:properties].key?(attribute)

              base[:properties][attribute] = deep_dup(ATTRIBUTE_SCHEMAS.fetch(attribute))
            end
            base[:properties][:content_align] = property(enum(:start, :center, :end, :stretch)) if type == :stack
            if %i[stack grid group expander scroll].include?(type)
              base[:properties][:drag_source] = property(IDENT)
              base[:properties][:drag_destination] = property(BOOL, default: false)
              base[:events][:widget_drop] = event(record(
                                                    source: property(CID, required: true), x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
                                                    allocations: property(array(record(cid: property(CID, required: true),
                                                                                       y: property(GEOMETRY, required: true), height: property(integer(min: 0, max: 65_536), required: true)), max: BOUNDS[:children]), required: true)
                                                  ), terminal: true)
            end
            if %i[page text image group progress table stack button overlay].include?(type)
              base[:properties][:pointer_events] = property(BOOL, default: false)
              base[:events][:pointer_press] = deep_dup(POINTER_EVENT)
              base[:events][:pointer_release] = event(deep_dup(POINTER_EVENT[:payload]), ordered: true)
            end
            if type == :overlay
              base[:properties][:pointer_tracking] = property(BOOL, default: false)
              base[:properties][:pointer_position] = property(record(
                                                                x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
                                                                state: property(integer(min: 0, max: 13), required: true)
                                                              ), scope: :viewer)
              base[:events][:pointer_motion] = event(record(
                                                       x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
                                                       state: property(integer(min: 0, max: 13), required: true)
                                                     ))
            end
            if %i[overlay select number_input group].include?(type)
              base[:events][:scroll] = event(record(
                                               delta_x: property(integer(min: -65_536, max: 65_536), required: true),
                                               delta_y: property(integer(min: -65_536, max: 65_536), required: true),
                                               state: property(integer(min: 0, max: 13), required: true),
                                               x: property(GEOMETRY), y: property(GEOMETRY)
                                             ), ordered: true)
              # Cumulative viewer-local deltas survive coalesced redraw delivery.
              base[:properties][:scroll_request] = property(record(
                                                              x: property(integer(min: -2_147_483_647, max: 2_147_483_647), required: true),
                                                              y: property(integer(min: -2_147_483_647, max: 2_147_483_647), required: true)
                                                            ), scope: :viewer)
            end
            if %i[number_input group button].include?(type)
              base[:events][:pointer_enter] = event(nil, ordered: true)
            end
            if type == :stack
              base[:events][:pointer_enter] = event(nil, ordered: true)
            end
            if %i[group number_input stack button].include?(type)
              base[:events][:pointer_leave] = event(nil, ordered: true)
            end
            if type == :tabs
              base[:properties][:headers] = property(array(record(
                                                             key: property(IDENT, required: true), foreground: property(RGBA),
                                                             pointer_events: property(BOOL, default: false), disabled: property(BOOL, default: false), hidden: property(BOOL, default: false)
                                                           ), max: BOUNDS[:collection]))
              pointer = deep_dup(POINTER_EVENT)
              pointer[:payload][:fields][:tab] = property(IDENT, required: true)
              base[:events][:tab_pointer] = pointer
            end
            if type == :group
              base[:events][:dismiss] = event(nil, lifecycle: true)
            end
            # A layout request is a minimum, not a fixed allocation. Native
            # conversions opt in without changing existing width semantics.
            base[:properties][:min_width] = property(integer(min: 0, max: 65_536)) if ATTRIBUTE_APPLICABILITY.fetch(type).include?(:width)
            if %i[log textarea].include?(type)
              base[:properties].merge!(padding_left: property(integer(min: 0, max: 64)), padding_right: property(integer(min: 0, max: 64)))
            end
            base[:properties].merge!(COMPOSITE_PROPERTIES) if type == :composite
            # Grid-child allocation is distinct from text alignment. Single-child
            # frames use their existing content_align property instead.
            base[:properties][:vertical_align] = property(enum(:start, :center, :end, :stretch)) unless type == :page
            base[:properties].merge!(FONT_STYLE_PROPERTIES) if %i[button text_input].include?(type)
            base[:properties][:emphasis] = property(enum(*EMPHASES)) if type == :text_input
            if type == :text
              base[:properties].merge!(TEXT_STYLE_PROPERTIES)
              base[:properties][:fragments] = property(array(union(BODY, TEXT_FRAGMENT), max: BOUNDS[:collection]))
              base[:properties].merge!(padding_x: property(integer(min: 0, max: 64)), padding_y: property(integer(min: 0, max: 64)),
                                       content_vertical_align: property(enum(:start, :center, :end)),
                                       line_justify: property(enum(:left, :center, :right)),
                                       rotation: property(enum(0, 90, 180, 270)))
            end
            base[:properties][:fill] = property(BOOL, default: false) if %i[stack columns table split group].include?(type)
            if type == :group
              base[:properties].merge!(padding: property(integer(min: 0, max: 64)),
                                       border_width: property(integer(min: 0, max: 8)), radius: property(integer(min: 0, max: 32)),
                                       content_align: property(enum(:start, :center, :end)),
                                       border_color: property(RGBA), background: property(RGBA),
                                       surface_events: property(BOOL, default: false), context_menu: property(IDENT))
              base[:events][:surface_activate] = COMPOSITE_EVENTS.fetch(:surface_activate)
            end
            if %i[text text_input select].include?(type)
              base[:properties][:min_width_chars] = property(integer(min: 1, max: 1024))
            end
            if %i[text_input select].include?(type)
              base[:properties][:max_width_chars] = property(integer(min: 1, max: 1024))
            end
            if %i[text_input select].include?(type)
              base[:properties][:control_width_chars] = property(integer(min: 1, max: 1024))
            end
            base[:properties][:control_margin] = deep_dup(ATTRIBUTE_SCHEMAS.fetch(:margin)) if type == :select
            if %i[text_input number_input select].include?(type)
              base[:properties].merge!(inline: property(BOOL, default: false),
                                       control_width: property(integer(min: 1, max: 1024)))
            end
            base[:properties][:fill_color] = property(RGBA) if type == :progress
            base[:events].merge!(COMPOSITE_EVENTS) if type == :composite
            base[:properties].merge!(deep_dup(ACCESSIBILITY_SCHEMAS))
            if PRESENTATION_ROLES.key?(type)
              base[:properties][:presentation_role] = property(enum(*PRESENTATION_ROLES.fetch(type)))
            end
            # Page-local opaque groups equalize widget width requests across separate rows.
            base[:properties][:width_groups] = property(array(IDENT, max: 8)) unless type == :page
            if type == :password_input
              base[:properties][:sensitive][:forced] = true
              base[:properties][:sensitive][:default] = true
            end
            schemas[type] = base
          end
          deep_freeze(schemas)
        end
      end
    end
  end
end
