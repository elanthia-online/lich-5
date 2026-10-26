# frozen_string_literal: true

module Lich
  module WebUI
    class Runtime
      private

      # Validates and transfers a submission to the dispatcher with explicit disposal.
      # @param connection [Object] authenticated viewer connection
      # @param message [Hash] decoded event and submission values
      # @return [Symbol] :queued after dispatch accepts ownership
      # @raise [Protocol::Refusal] for invalid events or queue overflow
      # @api private
      def event(connection, message)
        attachment = fetch_attachment(connection, message[:page])
        @viewers.admit_event(attachment, message) do |admission|
          dispatch_event(connection, attachment, message, admission)
        end
      end

      # Validates and enqueues against the render protected by ViewerStore admission.
      # Script callbacks run only on the dispatcher, outside the store monitor.
      # @param connection [Object] authenticated transport receiving any refusal
      # @param attachment [ViewerStore::Attachment] coherently admitted viewer
      # @param message [Hash] event envelope with validated protocol fields
      # @param admission [Object] captured render and bounded gesture authority
      # @return [Symbol] :queued after validation and dispatcher submission
      # @api private
      def dispatch_event(connection, attachment, message, admission)
        component = find_component!(attachment, message[:cid])
        payload = @validator.validate_event!(
          component.type, message[:event], message[:payload] || {}, props: component.props,
          owner: owner_label(attachment.page.owner), page_id: attachment.page.id, cid: component.cid
        )
        callback = attachment.render.bindings[[component.cid, message[:event].to_sym]]
        raise Protocol::Refusal.new(:unbound, 'component event has no server binding') unless callback

        if message[:event].to_sym == :pointer_motion && !component.props[:pointer_tracking]
          raise Protocol::Refusal.new(:payload, 'pointer measurement requires tracking opt-in')
        end

        if component.type == :table && message[:event].to_sym == :row_drop
          source = find_component!(attachment, payload[:source])
          unless source.type == :table && component.props[:transfer_group] &&
                 source.props[:transfer_group] == component.props[:transfer_group] &&
                 source.props[:rows].any? { |row| row[:key] == payload[:row] }
            raise Protocol::Refusal.new(:payload, 'row transfer is outside its declared table group')
          end
        end

        if message[:event].to_sym == :widget_drop
          source = find_component!(attachment, payload[:source])
          valid = component.props[:drag_destination] && source.props[:drag_source] &&
                  widget_transfer_available?(attachment.render.tree, component.cid) &&
                  widget_transfer_available?(attachment.render.tree, source.cid) &&
                  payload[:allocations].map { |item| item[:cid] } == component.children.map(&:cid)
          raise Protocol::Refusal.new(:payload, 'widget transfer requires live enabled peers and matching children') unless valid
        end

        if message[:event].to_sym == :pointer_release && !widget_transfer_available?(attachment.render.tree, component.cid)
          raise Protocol::Refusal.new(:payload, 'pointer release target is hidden or disabled')
        end

        event_schema = Contract.schema(component.type)[:events].fetch(message[:event].to_sym)
        unless event_schema[:lifecycle]
          presentation = (attachment.render.tree.props[:presentation] || {}).merge(attachment.render.facilities[:presentation] || {})
          if presentation[:hidden] || interaction_disabled?(attachment.render.tree, component.cid)
            raise Protocol::Refusal.new(:payload, 'component interaction is disabled or its window is hidden')
          end
        end
        # A select notification represents a transition, including when a client
        # resubmits its already selected tab before the next render arrives.
        if component.type == :tabs && message[:event].to_sym == :select &&
           @viewers.property(attachment, component, :selected) == payload[:index]
          return :queued
        end
        snapshot = build_submission(attachment, component, message)
        return dispatch_radio_change(attachment, component) if component.type == :radio_option && message[:event].to_sym == :change
        if component.type == :table && message[:event].to_sym == :selection_change && callback.respond_to?(:prepare_selection)
          return dispatch_guarded_selection(attachment, component.cid, payload)
        end

        attachment.page.observe_window_geometry(payload) if component.type == :page && message[:event].to_sym == :configure
        if component.type == :page && message[:event].to_sym == :configure && payload[:monitors]
          attachment.page.observe_monitors(attachment.viewer_id, payload[:monitors])
        end
        @viewers.update(attachment, component, message[:event].to_sym, payload, message[:request])
        context = EventContext.new(
          attachment.viewer_id, attachment.page, component, message[:event].to_sym, payload, snapshot, admission.render
        )
        @dispatcher.enqueue(
          owner: attachment.page.owner, page_id: attachment.page.id,
          viewer_id: attachment.viewer_id, cid: component.cid, event: context.event,
          coalescable: !event_schema[:terminal] && !event_schema[:lifecycle] && !event_schema[:ordered],
          cleanup: -> { snapshot&.discard_sensitive! }
        ) do
          if %i[widget_drop pointer_release].include?(context.event)
            run_bounded_gesture(attachment, admission, message, callback, context)
          else
            callback.call(context)
          end
        end
        dispatched = true
        if %i[widget_drop pointer_release].include?(context.event)
          log(:debug, "WebUI #{context.event} phase=queued request=#{message[:request]} generation=#{message[:generation]} admitted_generation=#{admission.render.generation}")
        end
        # A control already displays its own draft. Redrawing on blur needlessly
        # changes generation before the following Save arrives. Structural
        # choices still need a render; callbacks schedule their own other edits.
        schedule_refresh(attachment.page) if event_schema[:structural]
        clear_sensitive_client(connection, snapshot)
        :queued
      rescue Dispatcher::OverflowError
        @viewers.close(connection_id: connection.viewer_id, address: message[:page])
        connection.close
        raise Protocol::Refusal.new(:overflow, 'viewer event queue overflow')
      ensure
        snapshot&.discard_sensitive! unless dispatched
      end

      # Retires obsolete queued gestures and records callback completion separately
      # from native browser delivery. No store monitor is held while user code runs.
      # @param attachment [ViewerStore::Attachment] viewer that admitted the gesture
      # @param admission [Object] captured render and bounded epoch identity
      # @param message [Hash] request metadata used for phase diagnostics
      # @param callback [#call] captured server binding, never a replacement binding
      # @param context [EventContext] validated component, payload and render
      # @return [void]
      # @raise [StandardError] callback failure, logged and propagated to dispatcher
      # @api private
      def run_bounded_gesture(attachment, admission, message, callback, context)
        current = if context.event == :pointer_release
                    @viewers.release_admission_current?(attachment, admission)
                  else
                    @viewers.widget_admission_current?(attachment, admission)
                  end
        unless current
          log(:debug, "WebUI #{context.event} phase=retired request=#{message[:request]}")
          return
        end
        callback.call(context)
        log(:debug, "WebUI #{context.event} phase=completed request=#{message[:request]}")
      rescue StandardError => error
        log(:error, "WebUI #{context.event} phase=failed request=#{message[:request]} error=#{error.class}")
        raise
      end

      # Evaluate guarded proposals in owner order against current live selection.
      # Rejection/failure never commits a proposed value. Refresh also restores
      # optimistic browser selection after a veto; no second draft store exists.
      # @param attachment [ViewerStore::Attachment] exact admitted viewer/page association
      # @param cid [String] page-local component identity
      # @param payload [Hash] validated event fields
      # @return [Symbol]
      # @api private
      def dispatch_guarded_selection(attachment, cid, payload)
        @dispatcher.enqueue(owner: attachment.page.owner, page_id: attachment.page.id,
                            viewer_id: attachment.viewer_id, cid: cid, event: :selection_change, coalescable: true) do
          live = begin
            @viewers.attachment_for_viewer(attachment.page, attachment.viewer_id)
          rescue Error
            nil
          end
          next unless live.equal?(attachment)
          component = attachment.render.tree.find(cid)
          callback = attachment.render.bindings[[cid, :selection_change]]
          next unless component && callback.respond_to?(:prepare_selection)

          context = EventContext.new(attachment.viewer_id, attachment.page, component, :selection_change, payload, nil)
          previous = @viewers.property(attachment, component, :selected) || []
          restore = true
          begin
            proposed = callback.prepare_selection(context)
            accepted = @validator.validate_event!(:table, :selection_change, proposed, props: component.props,
                                                  owner: owner_label(attachment.page.owner), page_id: attachment.page.id, cid: cid)
            @viewers.update(attachment, component, :selection_change, accepted)
            callback.call(context.with(payload: accepted)) unless accepted[:rows] == previous
            # Keep the failure default until the changed callback also succeeds.
            # Accepted browser state needs no restoration paint when it matches.
            restore = accepted[:rows] != payload[:rows]
          ensure
            schedule_refresh(attachment.page) if restore
          end
        end
        :queued
      end

      # Selects a radio member atomically and dispatches deselection before selection.
      # The viewer store owns all group state; no adapter keeps a parallel draft map.
      # @param attachment [ViewerStore::Attachment] exact admitted viewer/page association
      # @param component [Component] current tree component
      # @return [Symbol] :queued, including an unchanged selection with no callbacks
      # @api private
      def dispatch_radio_change(attachment, component)
        changed = @viewers.select_radio_option(attachment, component)
        callbacks = changed.filter_map do |member, checked|
          callback = attachment.render.bindings[[member.cid, :change]]
          [callback, EventContext.new(attachment.viewer_id, attachment.page, member, :change, { value: checked }.freeze, nil)] if callback
        end
        return :queued if callbacks.empty?

        @dispatcher.enqueue(owner: attachment.page.owner, page_id: attachment.page.id,
                            viewer_id: attachment.viewer_id, cid: component.cid, event: :change, coalescable: false) do
          callbacks.each { |callback, context| callback.call(context) }
        end
        :queued
      end

      # Resolves ancestor disabled state in the delivered tree without changing local properties.
      # @param component [Component] current subtree
      # @param cid [String] target identity
      # @param inherited [Boolean] disabled state of ancestors
      # @return [Boolean, nil] effective state, or nil when absent from this subtree
      # @api private
      def interaction_disabled?(component, cid, inherited = false)
        disabled = inherited || component.props[:disabled] == true
        return disabled if component.cid == cid

        component.children.each do |child|
          result = interaction_disabled?(child, cid, disabled)
          return result unless result.nil?
        end
        nil
      end

      # Widget transfers cannot originate in a hidden or disabled ancestor.
      # @param component [Component] current tree component
      # @param cid [String] page-local component identity
      # @param unavailable [Boolean] hidden or disabled ancestor state
      # @return [Boolean, nil] availability, or nil when absent from this subtree
      # @api private
      def widget_transfer_available?(component, cid, unavailable = false)
        unavailable ||= component.props[:disabled] == true || component.props[:hidden] == true
        return !unavailable if component.cid == cid

        component.children.each do |child|
          result = widget_transfer_available?(child, cid, unavailable)
          return result unless result.nil?
        end
        nil
      end

      # Resolves a component within the viewer's delivered tree, not an arbitrary newer render.
      # @param attachment [ViewerStore::Attachment] exact admitted viewer/page association
      # @param cid [String] page-local component identity
      # @return [Component]
      # @raise [Protocol::Refusal] for an unknown delivered identity
      # @api private
      def find_component!(attachment, cid)
        component = attachment.render.tree.find(cid)
        return component if component

        raise Protocol::Refusal.new(:component_id, 'component is not registered for delivered page')
      end

      # Refuses a stale delivered generation before any callback or value is accepted.
      # @param _connection [Object] refused transport
      # @param _attachment [ViewerStore::Attachment] refused viewer association
      # @return [void]
      # @api private
      def stale!(_connection, _attachment)
        raise Protocol::Refusal.new(:stale_generation, 'stale generation')
      end
    end
  end
end
