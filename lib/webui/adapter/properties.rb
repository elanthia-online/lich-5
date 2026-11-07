# frozen_string_literal: true

module Lich
  module WebUI
    class Adapter
      # Reads validated shadow state without holding the adapter lock across rendering.
      # @param handle [Object] opaque component handle
      # @param property [Symbol, String] contract property
      # @return [Object] a copy of the current property value
      def get(handle, property)
        target = nil
        @mutex.synchronize do
          node = node!(handle)
          name, definition = property!(node, handle, property)
          if sensitive_property?(node, name, definition)
            raise SensitiveReadError.new(
              'sensitive-write-only property cannot be read', owner: owner_label,
              page_id: adapter_page_id, cid: handle_label(handle), field: name
            )
          end
          if definition[:scope] == :viewer
            selected = ValueHelpers.viewer_id(@viewer)
            pending = [selected.to_s, name] if selected
            return deep_copy(node.viewer_values[pending]) if pending && node.viewer_values.key?(pending)
            if (page = root_for(node).page) && node.cid && node.published
              target = [page, node.cid, name]
              next
            end
            return deep_copy(node.viewer_values.fetch([viewer!, name], node.props[name]))
          end

          # Window measurements are captured before callback dispatch. Exit
          # cleanup can therefore read the latest size even if a script is
          # killed while its configure callback is still queued.
          if node.type == :page && (geometry = node.page&.window_geometry)
            return geometry.values_at(:width, :height) if name == :size
            return geometry[:position].dup if name == :position
          end

          return deep_copy(node.props[name])
        end
        page, cid, name = target
        deep_copy(page.get(cid, name, viewer: @viewer))
      end

      # Updates a property, releasing the adapter lock before viewer-state dispatch.
      # @param handle [Object] opaque component handle
      # @param property [Symbol, String] contract property
      # @param value [Object] candidate value, or UNSET to reset an optional shared property
      # @return [nil]
      def set(handle, property, value)
        target = nil
        @mutex.synchronize do
          node = node!(handle)
          name, definition = property!(node, handle, property)
          if value.equal?(UNSET) && (definition[:required] || definition[:scope] != :shared)
            raise SchemaViolationError.new(
              'only optional shared properties can be unset', owner: owner_label,
              page_id: adapter_page_id, cid: handle_label(handle), field: name
            )
          end
          if sensitive_property?(node, name, definition)
            raise SchemaViolationError.new(
              'sensitive-write-only property cannot be set through server-held adapter state',
              owner: owner_label, page_id: adapter_page_id, cid: handle_label(handle), field: name
            )
          end
          if definition[:scope] == :ephemeral_client || definition[:scope] == :sensitive_write_only
            raise SchemaViolationError.new(
              'property cannot be set through server-held adapter state', owner: owner_label,
              page_id: adapter_page_id, cid: handle_label(handle), field: name
            )
          end
          if definition[:scope] == :viewer
            if (page = root_for(node).page) && node.cid && node.published && !(%i[tabs select].include?(node.type) && @viewer && @dirty_roots[root_for(node)])
              target = [page, node.cid, name]
              next
            end
            validated = validate_property(node, handle, name, value)
            selected = ValueHelpers.viewer_id(@viewer)
            if selected.nil? && !node.published
              # A handle can exist before its first render. Initialization queued
              # after construction still sets the authored default, not a draft.
              # Once published, the normal explicit-viewer rule above applies.
              node.props = node.props.merge(name => validated).freeze
            else
              node.viewer_values[[viewer!, name]] = validated
            end
          else
            candidate = value.equal?(UNSET) ? node.props.except(name) : node.props.merge(name => value)
            # Model mutation retires identities atomically with its row snapshot.
            # Defaults must remain valid before per-viewer reconciliation runs.
            if node.type == :table && name == :rows && value.is_a?(Array)
              keys = value.filter_map { |row| row[:key] || row['key'] if row.is_a?(Hash) }
              candidate[:selected] = (candidate[:selected] || []) & keys
              candidate[:expanded] = candidate[:expanded] & keys if candidate.key?(:expanded)
              candidate[:cursor] = {} unless keys.include?(candidate.dig(:cursor, :row))
            end
            if node.type == :table && name == :selection
              candidate[:selected] = [] if value.to_s == 'none'
              candidate[:selected] = (candidate[:selected] || []).first(1) if %w[single browse].include?(value.to_s)
            end
            # Browse requires a selection when rows exist. Match viewer reconciliation
            # here so reads before publication see the same first-row fallback.
            if node.type == :table && %i[rows selection].include?(name) && candidate[:selection].to_s == 'browse' && (candidate[:selected] || []).empty?
              first = candidate[:rows].first if candidate[:rows].is_a?(Array)
              key = first[:key] || first['key'] if first.is_a?(Hash)
              candidate[:selected] = [key] if key
            end
            # A select's option list and default must remain one valid schema.
            # sbounty replaces its choices; use the first declared choice only
            # when the old default was removed, after validating the list.
            if node.type == :select && name == :options
              candidate[:options] = @validator.validate_component!(
                :select, { options: value }, owner: owner_label,
                page_id: adapter_page_id, cid: handle_label(handle)
              ).fetch(:options)
              was_option = node.props[:options].any? { |option| option[:value] == candidate[:value] }
              if (!candidate[:editable] || was_option) && candidate[:options].none? { |option| option[:value] == candidate[:value] }
                candidate[:value] = candidate[:empty_value] || candidate[:options].first&.fetch(:value)
              end
            end
            validated = @validator.validate_component!(
              node.type, candidate, owner: owner_label,
              page_id: adapter_page_id, cid: handle_label(handle)
            )
            # Parent geometry and existing child placements are one mutation.
            # Reject a narrowed grid before publishing any invalid shadow tree.
            proposed = node.dup
            proposed.props = validated
            node.children.each { |child| validate_placement!(proposed, node!(child), child) }
            if node.type == :select && name == :options
              # A second rebuild can retire a choice staged before delivery.
              # Reconcile pending drafts with the same empty fallback as defaults.
              retired = node.props[:options].map { |option| option[:value] } - validated[:options].map { |option| option[:value] }
              node.viewer_values.each do |(viewer, property), pending_value|
                next unless property == :value && retired.include?(pending_value)

                node.viewer_values[[viewer, property]] = validated[:empty_value] || validated[:options].first&.fetch(:value)
              end
            end
            node.props = validated
            assign_child_slots!(node) if named_children?(node)
          end
          dirty!(root_for(node))
        end
        if target
          page, cid, name = target
          page.set(cid, name, value, viewer: @viewer)
        end
        nil
      rescue SchemaViolationError => error
        raise attributed(error, handle, property)
      end

      private

      # Revalidates the complete candidate before accepting one viewer property.
      # @param node [Node] current component
      # @param handle [Handle] component identity for errors
      # @param name [Symbol] normalized property name
      # @param value [Object] proposed property value
      # @return [Object] normalized requested value
      # @api private
      def validate_property(node, handle, name, value)
        @validator.validate_component!(
          node.type, node.props.merge(name => value), owner: owner_label,
          page_id: adapter_page_id, cid: handle_label(handle)
        ).fetch(name)
      end

      # Resolves declared or value-only properties with adapter attribution on refusal.
      # @param node [Node] current component
      # @param handle [Handle] component identity for errors
      # @param property [Symbol, String] requested property name
      # @return [Array] normalized name and property definition
      # @api private
      def property!(node, handle, property)
        name = normalize_name(property)
        component_schema = Contract.schema(node.type)
        definition = component_schema[:properties][name]
        if !definition && name == :value && component_schema[:value]
          definition = { shape: component_schema[:value], scope: component_schema[:value_scope] }
        end
        return [name, definition] if definition

        raise UnknownPropertyError.new(
          'unknown property', owner: owner_label, page_id: adapter_page_id,
          cid: handle_label(handle), field: name
        )
      end

      # Recognizes sensitive value fields even when sensitivity is set per component.
      # @param node [Node] current component
      # @param name [Symbol] normalized property name
      # @param definition [Hash] resolved property declaration
      # @return [Boolean]
      # @api private
      def sensitive_property?(node, name, definition)
        definition[:scope] == :sensitive_write_only ||
          (name == :value && ValueHelpers.sensitive_value?(node))
      end

      # Requires explicit viewer attribution for viewer-scoped adapter access.
      # @return [String] viewer identity captured before leaving the callback
      # @raise [AmbiguousViewerError] when no viewer was supplied
      # @api private
      def viewer!
        selected = ValueHelpers.viewer_id(@viewer)
        return selected.to_s if selected

        message = 'viewer-scoped adapter state requires an explicit viewer'
        raise AmbiguousViewerError.new(message, owner: owner_label, page_id: adapter_page_id)
      end

      # Copies mutable property containers and text through the shared value helper.
      # @param value [Object] property value to copy
      # @return [Object] detached value for the caller
      # @api private
      def deep_copy(value)
        ValueHelpers.deep_copy(value)
      end
    end
  end
end
