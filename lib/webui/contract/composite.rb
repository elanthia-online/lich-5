# frozen_string_literal: true

module Lich
  module WebUI
    module Contract
      TINT = union(record(tone: property(enum(*TONES), required: true)), RGBA).freeze
      POINT_FIELDS = {
        x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
      }.freeze
      COMPOSITE_LAYER = union(
        record(
          kind: property(enum(:rectangle), required: true), mode: property(enum(:fill, :stroke), required: true),
          x: property(number(min: -65_536, max: 65_536), required: true), y: property(number(min: -65_536, max: 65_536), required: true),
          w: property(number(min: 0, max: 65_536), required: true), h: property(number(min: 0, max: 65_536), required: true),
          color: property(RGBA, required: true), line_width: property(number(min: 1, max: 16), default: 2)
        ),
        # Map's original hollow room ring and tag/location crosses. This is a
        # bounded native drawing primitive, not GTK/Cairo or executable markup.
        record({
          kind: property(enum(:marker), required: true), **POINT_FIELDS,
          shape: property(enum(:ring, :cross), required: true),
          w: property(GEOMETRY, required: true), h: property(GEOMETRY, required: true),
          line_width: property(number(min: 1, max: 16), default: 2), color: property(RGBA, required: true),
        }),
        record({
          kind: property(enum(:image), required: true), src: property(string(:body_text), required: true),
          **POINT_FIELDS, w: property(GEOMETRY), h: property(GEOMETRY),
          # Wound assets may intentionally extend beyond the silhouette edge.
          x: property(integer(min: -65_536, max: 65_536), required: true),
          y: property(integer(min: -65_536, max: 65_536), required: true),
          opacity: property(number(min: 0.0, max: 1.0), default: 1.0),
          tint: property(TINT), mask: property(string(:body_text)),
        }),
        record({
          kind: property(enum(:bar), required: true), **POINT_FIELDS,
          w: property(GEOMETRY, required: true), h: property(GEOMETRY, required: true),
          value: property(number(min: 0.0, max: 1.0), required: true),
          tone: property(union(enum(*TONES), RGBA), default: 'neutral'),
          orientation: property(enum(:horizontal, :vertical), default: 'horizontal'),
        }),
        record({
          kind: property(enum(:label), required: true), **POINT_FIELDS,
          w: property(GEOMETRY), h: property(GEOMETRY), font_unit: property(enum(:pt, :px), default: 'pt'),
          text: property(SHORT, required: true), emphasis: property(enum(*EMPHASES), default: 'normal'),
          tone: property(enum(*TONES), default: 'neutral'),
          align: property(enum(:start, :center, :end), default: 'start'),
          **TEXT_STYLE_PROPERTIES,
        }),
        record(
          kind: property(enum(:region), required: true), key: property(IDENT, required: true),
          x1: property(GEOMETRY, required: true), y1: property(GEOMETRY, required: true),
          x2: property(GEOMETRY, required: true), y2: property(GEOMETRY, required: true),
          label: property(SHORT), activates: property(BOOL, default: false)
        )
      ).freeze

      COMPOSITE_PROPERTIES = {
        clip_layers: property(BOOL),
        width: property(GEOMETRY, required: true), height: property(GEOMETRY, required: true),
        scale: property(number(min: 0.1, max: 8.0), default: 1.0),
        scroll_to: property(IDENT, scope: :viewer),
        popup: property(record(
                          page: property(IDENT, required: true), size: property(array(GEOMETRY, min: 2, max: 2))
                        )),
        surface_events: property(BOOL, default: false),
        context_menu: property(IDENT),
        scroll_origin: property(array(GEOMETRY, min: 2, max: 2)),
        layers: property(array(COMPOSITE_LAYER, max: BOUNDS[:collection]), required: true),
      }.freeze

      COMPOSITE_EVENTS = {
        zoom: event(record(direction: property(enum(:in, :out), required: true))),
        region_activate: event(record(region: property(IDENT, required: true)), terminal: true),
        surface_activate: event(record(
                                  x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
                                  button: property(enum(:primary, :secondary), required: true),
                                  modifiers: property(array(enum(:ctrl, :shift, :alt), max: 3), required: true),
                                  region: property(IDENT)
                                ), terminal: true),
      }.freeze
    end
  end
end
