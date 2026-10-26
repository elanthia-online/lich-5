# frozen_string_literal: true

module Lich
  module WebUI
    class ViewerStore
      # Reads a viewer override, falling back to the delivered component property.
      # @param attachment [Attachment, Snapshot] delivered viewer or captured closing/delivery state
      # @param component [Component] validated delivered component
      # @param name [Symbol] normalized contract property
      # @return [Object] current value
      def property(attachment, component, name)
        @mutex.synchronize { attachment.values.fetch([component.cid, name], component.props[name]) }
      end

      # Stores an already-validated viewer-local override under the store lock.
      # @param attachment [Attachment, Snapshot] delivered viewer or captured closing/delivery state
      # @param component [Component] validated delivered component
      # @param name [Symbol] normalized contract property
      # @param value [Object] already-validated property or input value
      # @return [Object] stored value
      def set_property(attachment, component, name, value)
        @mutex.synchronize do
          select_radio_option!(attachment, component) if component.type == :radio_option && name == :checked && value
          attachment.values[[component.cid, name]] = value
        end
      end

      # Validates and seeds a new control only while its viewer and CID are live.
      # Checking identity, resolving the delivered component and writing under
      # one lock prevents concurrent detach/delivery from reviving stale state.
      # @param attachment [Attachment] exact viewer/page association
      # @param cid [String] page-local delivered component identity
      # @param name [Symbol] normalized contract property
      # @return [Object, nil] stored value, or nil for a departed/undelivered target
      # @yield [component] validate the current target while its identity is protected
      # @yieldparam component [Component] current delivered component
      # @yieldreturn [Object] validated property value to seed
      def seed_property(attachment, cid, name)
        @mutex.synchronize do
          next unless @by_resume[attachment.resume_token].equal?(attachment) && !attachment.expires_at
          component = attachment.render&.tree&.each&.find { |candidate| candidate.cid == cid }
          next unless component

          value = yield component
          select_radio_option!(attachment, component) if component.type == :radio_option && name == :checked && value
          attachment.values[[cid, name]] = value
        end
      end

      # Accepts only the read-only text actually sent to this viewer. A later
      # server write remains authoritative and is never overwritten by submission.
      # This delivery record is protocol evidence, not another editable draft.
      # Browsers normalize textarea line breaks and strip them in single-line
      # inputs. Compare that representation; server text and callbacks stay exact.
      # @param attachment [Attachment] exact viewer/page association
      # @param component [Component] validated delivered component
      # @param value [String] validated text submitted from the browser
      # @return [String] current server value for the terminal callback snapshot
      # @raise [Protocol::Refusal] if the client changed the delivered text
      def read_only_submission(attachment, component, value)
        @mutex.synchronize do
          unless attachment.delivered_read_only.key?(component.cid) &&
                 read_only_browser_value(component.type, attachment.delivered_read_only[component.cid]) == read_only_browser_value(component.type, value)
            raise Protocol::Refusal.new(:payload, 'read-only text cannot be changed by submission')
          end
          attachment.values.fetch([component.cid, :value], component.props[:value])
        end
      end

      # Applies a validated interaction to the corresponding viewer-local control state.
      # Password values are intentionally excluded from this persistent state map.
      # Request IDs acknowledge accepted live text input, never grant routing authority.
      # They are captured with values so an older delivery cannot erase newer typing.
      # @param attachment [Attachment] exact viewer/page association
      # @param component [Component] validated delivered component
      # @param event [Symbol] validated component event name
      # @param payload [Hash] validated event fields
      # @param request [Integer, nil] correlated request acknowledgement
      # @return [void]
      def update(attachment, component, event, payload, request = nil)
        @mutex.synchronize do
          if request && component.type == :text_input && event == :change && !component.props[:sensitive]
            attachment.input_requests[component.cid] = request
          end
          case [component.type, event]
          when [:overlay, :pointer_press], [:overlay, :pointer_motion], [:overlay, :pointer_release]
            if component.props[:pointer_tracking]
              attachment.values[[component.cid, :pointer_position]] = payload.slice(:x, :y, :state).freeze
              # Start the bounded drag lifetime at press, not at an earlier paint.
              if event == :pointer_press && payload[:button] == 1 && (epoch = attachment.release_epochs[component.cid])
                epoch.started_at = @clock.call
              end
            end
          when [:radio_option, :change]
            select_radio_option!(attachment, component) if payload[:value]
            attachment.values[[component.cid, :checked]] = payload[:value]
          when [:toggle, :change], [:checkbox, :change] then attachment.values[[component.cid, :checked]] = payload[:value]
          when [:radio, :change] then attachment.values[[component.cid, :selected]] = payload[:value]
          when [:text_input, :change], [:text_input, :blur], [:textarea, :change], [:textarea, :blur], [:number_input, :change], [:slider, :change], [:select, :change]
            attachment.values[[component.cid, :value]] = payload[:value]
          when [:tabs, :select] then attachment.values[[component.cid, :selected]] = payload[:index]
          when [:group, :dismiss] then attachment.values[[component.cid, :open]] = false
          when [:expander, :toggle] then attachment.values[[component.cid, :open]] = payload[:open]
          when [:split, :move] then attachment.values[[component.cid, :position]] = payload[:position]
          when [:table, :selection_change] then attachment.values[[component.cid, :selected]] = payload[:rows]
          when [:table, :cursor_change]
            attachment.values[[component.cid, :cursor]] = payload.dup.freeze
          when [:table, :sort_change]
            attachment.values[[component.cid, :sort]] = { column: payload[:column], direction: payload[:direction] }.freeze
          when [:table, :row_toggle]
            expanded = attachment.values.fetch([component.cid, :expanded]) { component.props[:rows].select { |row| row[:expanded] }.map { |row| row[:key] } }
            attachment.values[[component.cid, :expanded]] = payload[:expanded] ? expanded | [payload[:row]] : expanded - [payload[:row]]
          end
        end
      end

      # Reads the accepted input before a terminal submission replaces it.
      # @param attachment [Attachment] exact viewer/page association
      # @param component [Component] validated delivered component
      # @return [Object] current viewer-local input value
      def input_value(attachment, component)
        property(attachment, component, input_property(component.type))
      end

      # Maps a validated submission value to the control's supported input property.
      # @param attachment [Attachment] exact viewer/page association
      # @param component [Component] validated delivered component
      # @param value [Object] already-validated property or input value
      # @return [void]
      def set_input(attachment, component, value)
        property = input_property(component.type)
        set_property(attachment, component, property, value) if property
      end

      # Selects one member and returns changed peers followed by the selected member.
      # @param attachment [Attachment] exact viewer/page association
      # @param component [Component] validated delivered component
      # @return [Array<Array(Component, Boolean)>] only actual boolean transitions
      # @raise [Error] before a render has been delivered
      def select_radio_option(attachment, component)
        @mutex.synchronize do
          raise Error, 'viewer has no delivered render' unless attachment.render

          changed = attachment.render.tree.each.filter_map do |peer|
            next unless peer.type == :radio_option && peer.props[:group] == component.props[:group]

            checked = peer.cid == component.cid
            [peer, checked] if attachment.values.fetch([peer.cid, :checked], peer.props[:checked]) != checked
          end
          select_radio_option!(attachment, component)
          changed.sort_by { |_peer, checked| checked ? 1 : 0 }
        end
      end

      private

      # Single-line HTML inputs strip line breaks; textareas normalize them.
      # Compare browser representations without modifying authoritative text.
      # @param type [Symbol] normalized component type
      # @param value [String] validated text to compare in its browser representation
      # @return [String] the validated value's browser representation
      # @api private
      def read_only_browser_value(type, value)
        type == :text_input ? value.delete("\r\n") : normalize_text_line_breaks(value)
      end

      # Nontext values retain their identity; schema validation owns rejection.
      # @param value [Object] already-validated property or input value
      # @return [Object] text with LF line breaks, or the unchanged nontext value
      # @api private
      def normalize_text_line_breaks(value)
        value.is_a?(String) ? ValueHelpers.normalize_text_line_breaks(value) : value
      end

      # Clears only peers in the same delivered page and viewer before selecting a member.
      # Must be called under the store mutex; no synthetic callbacks are dispatched here.
      # @param attachment [Attachment] exact viewer/page association
      # @param component [Component] validated delivered component
      # @return [void]
      # @api private
      def select_radio_option!(attachment, component)
        attachment.render.tree.each do |peer|
          next unless peer.type == :radio_option && peer.props[:group] == component.props[:group]

          attachment.values[[peer.cid, :checked]] = peer.cid == component.cid
        end
      end

      # Maps supported input components to their viewer-local value property.
      # @param type [Symbol] normalized component type
      # @return [Symbol, nil]
      # @api private
      def input_property(type)
        case type
        when :toggle, :checkbox, :radio_option then :checked
        when :radio then :selected
        when :text_input, :textarea, :number_input, :slider, :select then :value
        end
      end
    end
  end
end
