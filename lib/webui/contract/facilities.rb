# frozen_string_literal: true

module Lich
  module WebUI
    module Contract
      FACILITIES = {
        accelerators: {
          shape: array(record(
                         keys: property(SHORT, required: true), target: property(CID, required: true),
                         event: property(IDENT, required: true)
                       ), max: BOUNDS[:collection]), scope: :shared,
        },
        geometry: {
          shape: record(
            width: property(GEOMETRY), height: property(GEOMETRY),
            x: property(GEOMETRY), y: property(GEOMETRY)
          ), scope: :viewer,
        },
        notify: {
          shape: record(
            text: property(BODY, required: true), level: property(enum(:info, :warn, :error), required: true)
          ), scope: :transient,
        },
        focus: { shape: CID, scope: :viewer },
        focus_revision: { shape: integer(min: 1, max: 2_147_483_647), scope: :viewer },
        announce: {
          shape: record(
            text: property(BODY, required: true),
            politeness: property(enum(:polite, :assertive), required: true)
          ), scope: :viewer,
        },
        presentation: {
          shape: PRESENTATION, scope: :viewer,
        },
      }.freeze

      POINTER_EVENT = event(record(
                              x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
                              button: property(integer(min: 1, max: 3), required: true),
                              time: property(integer(min: 0), required: true),
                              state: property(integer(min: 0, max: 13), required: true),
                              click_count: property(integer(min: 1, max: 2))
                            ), lifecycle: true).freeze

      PAGE_LIFECYCLE_EVENTS = {
        pointer_press: POINTER_EVENT,
        key_press: event(record(keyval: property(integer(min: 0, max: 0x10ffff), required: true),
                                state: property(integer(min: 0, max: 13), required: true)), ordered: true),
        key_release: event(record(keyval: property(integer(min: 0, max: 0x10ffff), required: true),
                                  state: property(integer(min: 0, max: 13), required: true)), ordered: true),
        window_state: event(record(minimized: property(BOOL, required: true)), lifecycle: true),
        # Measured host geometry is notification data, not a form submission.
        configure: event(record(
                           width: property(integer(min: 0, max: 65_536), required: true),
                           height: property(integer(min: 0, max: 65_536), required: true),
                           position: property(array(integer(min: -65_536, max: 65_536), min: 2, max: 2), required: true),
                           monitors: property(record(
                                                source: property(enum(:native, :browser, :unavailable), required: true),
                                                screens: property(array(record(
                                                                          x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
                                                                          width: property(integer(min: 1, max: 65_536), required: true),
                                                                          height: property(integer(min: 1, max: 65_536), required: true),
                                                                          primary: property(BOOL, required: true), active: property(BOOL, required: true)
                                                                        ), max: 32), required: true)
                                              ))
                         )),
        close: event(record(reason: property(enum(:user, :owner, :timeout), required: true)), terminal: true, lifecycle: true),
        attach: event(nil, lifecycle: true),
        detach: event(nil, lifecycle: true),
      }.freeze
    end
  end
end
