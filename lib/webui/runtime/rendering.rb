# frozen_string_literal: true

module Lich
  module WebUI
    class Runtime
      # Renders and delivers a registered page only while its owner accepts work.
      # @param page [Page] page to refresh
      # @return [Integer] evaluated render generation
      # @raise [Error] if the page closed, its owner terminated or the host stopped
      def refresh(page)
        @registry.ensure_active!(page.owner)
        @registry.address_for(page)
        page.bind_runtime(self)
        render = validated_render(page)
        @viewers.attachments_for(page).each do |attachment|
          connection = @connections_mutex.synchronize { @connections[attachment.connection_id] }
          next unless connection&.alive?

          @viewers.deliver(attachment, render)
          send_render(connection, attachment)
        end
        render.generation
      end

      private

      # Sends the delivered tree, event bindings and native-presentation ownership.
      # @param connection [#send_text] authenticated viewer connection
      # @param attachment [ViewerStore::Attachment] current viewer/page association
      # @return [Object] transport send result
      # @api private
      def send_render(connection, attachment)
        snapshot = @viewers.snapshot(attachment, for_delivery: true)
        render = snapshot.render
        bindings = render.bindings.keys.group_by(&:first).transform_values do |pairs|
          pairs.map(&:last).map(&:to_s)
        end
        connection.send_text(
          Protocol.render(
            address: attachment.address, generation: render.generation,
            tree: serialize_for_client(snapshot), facilities: render.facilities,
            bindings: bindings, submissions: render.submissions,
            input_requests: snapshot.input_requests,
            resume: attachment.resume_token,
            window_presentation: @window_host&.call(attachment.page)&.presentation_support || {}
          )
        )
      end

      # Serializes a coherent viewer snapshot and resolves logical popup addresses.
      # @param snapshot [ViewerStore::Snapshot] state captured before transport writes
      # @return [Hash] client component tree
      # @api private
      def serialize_for_client(snapshot)
        tree = @viewers.serialize(snapshot)
        rewrite_popup_addresses(tree, snapshot.page.owner)
      end

      # Replaces owner-local popup IDs with registered opaque addresses recursively.
      # Popup resolution cannot select another owner's page by its local ID.
      # @param component [Hash] serialized component subtree to rewrite in place
      # @param owner [Object] server-owned lifecycle identity
      # @return [Hash] updated component tree
      # @api private
      def rewrite_popup_addresses(component, owner)
        if component[:type] == 'composite' && component.dig(:props, :popup)
          popup = component[:props][:popup]
          target = @registry.fetch(owner, popup[:page])
          component[:props] = component[:props].merge(popup: popup.merge(page: @registry.address_for(target)))
        end
        component[:children].each { |child| rewrite_popup_addresses(child, owner) }
        component
      end

      # Validates served images and popup ownership before applying native presentation.
      # @param page [Page] page whose authored render is evaluated
      # @return [Page::Render] render accepted for delivery
      # @raise [Error] if an image route or popup page is unavailable
      # @api private
      def validated_render(page)
        render = page.render
        record_presentation_degradations(page, render)
        render.tree.each do |component|
          sources = case component.type
                    when :image then component.props[:src] == '' ? [] : [component.props[:src]]
                    when :composite
                      component.props[:layers].filter_map do |layer|
                        [layer[:src], layer[:mask]] if layer[:kind] == 'image'
                      end.flatten.compact
                    else []
                    end
          sources.each do |source|
            next if @file_service&.resolve_url(source)

            raise Error.new(
              'image source is not a registered served file', owner: owner_label(page.owner),
              page_id: page.id, cid: component.cid, field: :src
            )
          end
          next unless component.type == :composite && component.props[:popup]

          @registry.fetch(page.owner, component.props[:popup][:page])
        end
        @window_host&.call(page)&.present(render)
        render
      end

      # Records unsupported presentation requests after facility overrides are applied.
      # @param page [Page] owner of the diagnostic record
      # @param render [Page::Render] evaluated page properties and facilities
      # @return [void]
      # @api private
      def record_presentation_degradations(page, render)
        requested = (render.tree.props[:presentation] || {}).merge(render.facilities[:presentation] || {})
        refusals = requested.each_key.filter_map do |property|
          next if presentation_support(page).fetch(property)

          {
            facility: :presentation, property: property,
            reason: :unsupported_by_browser_host,
          }.freeze
        end
        @degradation_mutex.synchronize do
          # Close unregisters before taking this lock. A late render therefore
          # cannot restore a strong reference after close removes the record.
          @registry.address_for(page)
          @degradations[page] = refusals.freeze
        end
      end

      # Queues refresh for this exact page and suppresses only its retirement failure.
      # @param page [Page] exact owner-scoped page
      # @return [nil]
      # @api private
      def schedule_refresh(page)
        schedule_render(page, owner: page.owner, delay: 0) do
          refresh(page)
        rescue Error
          # Closure may retire this exact page after the refresh was queued or
          # admitted. Discard that obsolete work without joining a render thread
          # from inside a close callback. Live-page errors still reach the logger;
          # a replacement with the same owner/id never revives the retired page.
          raise if @registry.pages_for(page.owner).any? { |registered| registered.equal?(page) }
        end
      end
    end
  end
end
