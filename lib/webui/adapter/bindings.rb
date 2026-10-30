# frozen_string_literal: true

module Lich
  module WebUI
    class Adapter
      # Registers one allowed callback, replacing the previous binding for that event.
      # @param handle [Handle] owned component
      # @param event [Symbol, String] allowed event name
      # @param callable [#call] callback receiving the runtime event context
      # @return [String] opaque binding ID usable with #unbind
      # @raise [UnknownEventError] for events outside the component allowlist
      def bind(handle, event, callable)
        raise ArgumentError, 'callback must respond to call' unless callable.respond_to?(:call)

        @mutex.synchronize do
          node = node!(handle)
          name = normalize_name(event)
          allowed_events = if node.type == :page
                             Contract::PAGE_LIFECYCLE_EVENTS
                           else
                             Contract.schema(node.type)[:events]
                           end
          unless allowed_events.key?(name)
            raise UnknownEventError.new(
              'event is not in the component allowlist', owner: owner_label,
              page_id: adapter_page_id, cid: handle_label(handle), field: name
            )
          end
          binding_id = "binding-#{SecureRandom.hex(16)}".freeze
          node.callbacks.delete(node.bindings[name])
          @bindings.delete(node.bindings[name])
          callback = proc do |context|
            reconcile_submission(context) if context.submission
            callable.call(context)
          end
          # A server-only selection guard evaluates an owner proposal before
          # Runtime commits viewer state. It is never a wire event or property.
          if node.type == :table && name == :selection_change && callable.respond_to?(:prepare_selection)
            callback.define_singleton_method(:prepare_selection) { |context| callable.prepare_selection(context) }
          end
          record = [handle, name, callback]
          node.callbacks[binding_id] = record
          @bindings[binding_id] = WeakRef.new(record)
          @binding_operations += 1
          prune_bindings! if (@binding_operations % 64).zero?
          node.bindings[name] = binding_id
          dirty!(root_for(node))
          binding_id
        end
      end

      # Removes a binding and marks its root dirty for publication.
      # @param binding_id [String] ID returned by #bind
      # @return [nil]
      def unbind(binding_id)
        @mutex.synchronize do
          record = binding_record(binding_id.to_s)
          @bindings.delete(binding_id.to_s)
          handle, event, = record || raise(
            attributed_error('unknown binding', nil, binding_id)
          )
          node = node!(handle)
          node.bindings.delete(event)
          node.callbacks.delete(binding_id.to_s)
          dirty!(root_for(node))
        end
        nil
      end

      private

      # Legacy forms commonly save a hash maintained by change handlers instead
      # of reading widgets on Close. Reconcile only inputs changed by the final
      # snapshot; already accepted change events must not fire a second time.
      # Call outside the adapter monitor, in the same viewer/dispatcher turn.
      # @param context [Runtime::EventContext] terminal event with an accepted submission
      # @return [void]
      # @api private
      def reconcile_submission(context)
        handles = @mutex.synchronize { @nodes.values.to_h { |node| [node.cid, node.handle] } }
        context.submission.input_changes.each do |component|
          callback = @mutex.synchronize do
            node = @nodes[handles[component.cid]]
            next unless node && root_for(node).page.equal?(context.page)

            binding = node&.bindings&.[](:change)
            node.callbacks[binding]&.last if binding
          end
          next unless callback

          callback.call(context.with(component: component, event: :change,
                                     payload: { value: context.submission[component.cid] }.freeze, submission: nil))
        end
      end

      # Resolves weak binding discovery while a live node owns the record.
      # Missing or collected IDs never route to a replacement binding.
      # @param id [String] opaque binding lookup ID
      # @return [Array, nil] live handle/event/callback record, or nil after collection
      # @api private
      def binding_record(id)
        record = weak_value(@bindings[id])
        @bindings.delete(id) unless record
        record
      end

      # Strong locals pin weak payloads through each operation/snapshot.
      # @param reference [WeakRef, nil] non-owning payload discovery
      # @return [Object, nil] strongly pinned live payload, or nil after collection
      # @api private
      def weak_value(reference)
        reference&.__getobj__
      rescue WeakRef::RefError
        nil
      end

      # Bound metadata churn without forcing GC or running script finalizers.
      # @return [void]
      # @api private
      def prune_bindings!
        @bindings.delete_if { |_id, reference| !reference.weakref_alive? }
      end

      # Captures the currently retained callback for each bound event.
      # @param node [Node] live node owning the binding records
      # @return [Hash{Symbol => Proc}] event callbacks for one render
      # @api private
      def callbacks_for(node)
        node.bindings.to_h { |event, binding_id| [event, node.callbacks.fetch(binding_id).last] }
      end
    end
  end
end
