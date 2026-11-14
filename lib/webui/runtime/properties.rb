# frozen_string_literal: true

module Lich
  module WebUI
    class Runtime
      # Reads a shared property or the explicit/current callback viewer's value.
      # Viewer-local reads require an unambiguous attachment; secrets cannot be read here.
      # @param page [Page] exact owner-scoped page
      # @param cid [String] page-local component identity
      # @param property [Symbol, String] requested contract property
      # @param viewer [String, #viewer_id, nil] explicit viewer or callback identity resolver
      # @return [Object] current property value
      # @raise [SensitiveReadError] for sensitive write-only fields
      # @raise [UnknownPropertyError] for an unknown property
      def read(page, cid, property, viewer: nil)
        component = page_component(page, cid)
        name = component_property(component, property)
        scope = property_scope(component, name)
        case scope
        when :sensitive_write_only
          raise SensitiveReadError.new(
            'sensitive values are write-only', owner: owner_label(page.owner), page_id: page.id,
            cid: component.cid, field: name
          )
        when :viewer
          attachment = contextual_attachment(page, component, viewer)
          @viewers.property(attachment, component, name)
        else
          page.fetch_shared_value(component.cid, name, component.props[name])
        end
      rescue KeyError
        raise UnknownPropertyError.new(
          "unknown property #{property.inspect}", owner: owner_label(page.owner), page_id: page.id,
          cid: cid, field: property
        )
      end

      # Validates a scoped property update, then schedules a page refresh.
      # Sensitive/ephemeral state must use its dedicated submission path instead.
      # @param page [Page] exact owner-scoped page
      # @param cid [String] page-local component identity
      # @param property [Symbol, String] requested contract property
      # @param value [Object] proposed property value
      # @param viewer [String, #viewer_id, nil] explicit viewer or callback identity resolver
      # @return [nil]
      # @raise [SensitiveReadError] for sensitive or ephemeral fields
      # @raise [UnknownPropertyError] for an unknown property
      def write(page, cid, property, value, viewer: nil)
        component = page_component(page, cid)
        name = component_property(component, property)
        scope = property_scope(component, name)
        if %i[sensitive_write_only ephemeral_client].include?(scope)
          raise SensitiveReadError.new(
            'sensitive and ephemeral values cannot be set through bulk state',
            owner: owner_label(page.owner), page_id: page.id, cid: component.cid, field: name
          )
        end
        validated = @validator.validate_property!(
          component.type, name, value, props: component.props,
          owner: owner_label(page.owner), page_id: page.id, cid: component.cid
        )
        if scope == :viewer
          attachment = contextual_attachment(page, component, viewer)
          @viewers.set_property(attachment, component, name, validated)
        else
          page.write_shared_value(component.cid, name, validated)
        end
        schedule_refresh(page)
        nil
      rescue KeyError
        raise UnknownPropertyError.new(
          "unknown property #{property.inspect}", owner: owner_label(page.owner), page_id: page.id,
          cid: cid, field: property
        )
      end

      # Applies writes made while new controls were awaiting their first delivery.
      # Identity is captured at write time; departed viewers are never recreated.
      # Stale targets are discarded; invalid writes are reported individually so
      # a single rejected value cannot discard later valid writes in the batch.
      # @param page [Page] exact owner-scoped page receiving the writes
      # @param changes [Array<Array>] viewer ID, CID, property, validated value
      # @return [Object] refresh scheduling result
      # @api private
      def seed_viewer_properties(page, changes)
        attachments = @viewers.attachments_for(page).to_h { |attachment| [attachment.viewer_id, attachment] }
        changes.each do |viewer, cid, name, value|
          attachment = attachments[viewer]
          next unless attachment

          @viewers.seed_property(attachment, cid, name) do |component|
            raise Error, 'initial property must be viewer-scoped' unless property_scope(component, name) == :viewer
            @validator.validate_property!(component.type, name, value, props: component.props,
                                          owner: owner_label(page.owner), page_id: page.id, cid: cid)
          end
        rescue Error, KeyError => error
          log(:warning, "WebUI initial property refused owner=#{owner_label(page.owner)} page=#{page.id} cid=#{cid} field=#{name} error=#{error.class}")
        end
        schedule_refresh(page)
      end

      private

      # Finds a component in the closing viewer's snapshot or the current page render.
      # @param page [Page] owning page
      # @param cid [String] component identifier
      # @return [Component] matching component
      # @api private
      def page_component(page, cid)
        render = lifecycle_snapshot(page)&.render || page.last_render || page.render
        component = render.tree.each.find { |candidate| candidate.cid == cid.to_s }
        return component if component

        raise Error.new('component is not registered', owner: owner_label(page.owner), page_id: page.id, cid: cid)
      end

      # Maps generic value access onto checkbox/toggle checked or radio selected state.
      # @param component [Component] current tree component
      # @param property [Symbol, String] requested contract property
      # @return [Symbol] concrete contract property
      # @api private
      def component_property(component, property)
        key = property.to_sym
        return key unless key == :value

        case component.type
        when :toggle, :checkbox, :radio_option then :checked
        when :radio then :selected
        else :value
        end
      end

      # Resolves ownership while giving sensitive value classification precedence.
      # @param component [Component] current tree component
      # @param name [Symbol] normalized contract property
      # @return [Symbol] property scope
      # @raise [KeyError] for an unknown property
      # @api private
      def property_scope(component, name)
        schema = Contract.schema(component.type)
        return :sensitive_write_only if name == :value && sensitive?(component)

        definition = schema.fetch(:properties)[name]
        return definition[:scope] if definition
        return schema[:value_scope] if name == :value && schema[:value]

        raise KeyError, name
      end

      # Resolves callback-scoped closing state before looking up a live viewer.
      # @param page [Page] owning page
      # @param component [Component] component being accessed
      # @param viewer [Object, String, nil] explicit viewer outside callbacks
      # @return [ViewerStore::Attachment, ViewerStore::Snapshot] viewer-local state
      # @api private
      def contextual_attachment(page, component, viewer)
        snapshot = lifecycle_snapshot(page)
        return snapshot if snapshot

        selected = @dispatcher.current_context&.viewer_id || viewer
        viewer_id = ValueHelpers.viewer_id(selected)
        unless viewer_id
          raise AmbiguousViewerError.new(
            'viewer-local access requires callback context or an explicit viewer',
            owner: owner_label(page.owner), page_id: page.id, cid: component.cid
          )
        end

        @viewers.attachment_for_viewer(page, viewer_id.to_s)
      end

      # Limits detached state access to this runtime's current lifecycle callback.
      # @param page [Page] page whose closing state is requested
      # @return [ViewerStore::Snapshot, nil] matching callback snapshot
      # @api private
      def lifecycle_snapshot(page)
        runtime, snapshot = Thread.current.thread_variable_get(LIFECYCLE_SNAPSHOT_KEY)
        snapshot if runtime.equal?(self) && snapshot&.page.equal?(page)
      end

      # Classifies sensitive input values through the shared contract helper.
      # @param component [Component] current tree component
      # @return [Boolean]
      # @api private
      def sensitive?(component)
        ValueHelpers.sensitive_value?(component)
      end
    end
  end
end
