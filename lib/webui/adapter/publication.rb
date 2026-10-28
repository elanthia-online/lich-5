# frozen_string_literal: true

module Lich
  module WebUI
    class Adapter
      # Requests an owned window after pending state is published on the owner worker.
      # Reuses the page and its handles; the host reuses a live window or opens a new one.
      # @param handle [Handle] live page root belonging to this adapter
      # @return [nil]
      # @raise [Error] for foreign, non-page, destroyed or terminated handles
      def present(handle)
        @service.registry.ensure_active!(@owner)
        @mutex.synchronize do
          root = node!(handle)
          raise attributed_error('presentation requires a page root', handle, :present) unless root.type == :page && !root.parent

          root.present_requested = true
          dirty!(root)
        end
        nil
      end

      # Retains a revisioned focus request for a focusable descendant of one owned page.
      # @param root_handle [Handle] owned page root
      # @param target_handle [Handle] focusable descendant
      # @return [nil]
      # @raise [Error] for foreign, detached, non-focusable or retired targets
      def focus(root_handle, target_handle)
        @mutex.synchronize do
          root, target = node!(root_handle), node!(target_handle)
          valid = root.type == :page && root_for(target).equal?(root) && TreeBuilder::FOCUSABLE_TYPES.include?(target.type)
          raise attributed_error('focus requires a focusable page descendant', target_handle, :focus) unless valid
          raise attributed_error('focus revision exhausted', root_handle, :focus) if @focus_sequence >= 2_147_483_647

          root.focus = [WeakRef.new(target_handle), @focus_sequence += 1]
          dirty!(root)
        end
        nil
      end

      private

      # Snapshots dirty roots by identity, then publishes each one outside the adapter monitor.
      # Avoids lock inversion with Page rendering; explicit presentation follows publication.
      # A root that fails is marked dirty again for the next flush while later roots
      # still publish; the first failure is re-raised after every root was tried.
      # @return [nil]
      # @api private
      def flush!
        roots = @mutex.synchronize do
          selected = @dirty_roots.keys.filter_map do |candidate|
            root_for(candidate) if handle_for(candidate)
          end.uniq(&:object_id)
          @dirty_roots.clear
          selected
        end
        failure = nil
        roots.each do |root|
          publish_root(root)
        rescue StandardError => error
          @mutex.synchronize { @dirty_roots[root] = true if handle_for(root) }
          failure ||= error
        end
        raise failure if failure

        nil
      end

      # Registers, refreshes and, when due, presents one root.
      # First presentation is recorded only after the host accepted the request
      # (on_publish returned). A false result means the host already closed the
      # window and dispatched the page's close lifecycle; it is not retried on
      # every later change. A raised request leaves the root unpresented.
      # @param root [Node] live page root
      # @return [void]
      # @api private
      def publish_root(root)
        page = @mutex.synchronize do
          next unless handle_for(root)

          ensure_page!(root)
          root.page.refresh_definition(
            title: root.props.fetch(:title), props: root.props.except(:title), on: callbacks_for(root)
          )
          root.page
        end
        return unless page

        # Page rendering calls back into the adapter to snapshot its tree. Never
        # hold the adapter monitor while waiting for a page's render mutex.
        @service.refresh(page)
        delivered = page.last_render.tree.each.to_h { |component| [component.cid, true] }
        @mutex.synchronize do
          changes = []
          @nodes.each_value do |child|
            next unless root_for(child).equal?(root) && delivered.key?(child.cid)

            child.viewer_values.delete_if do |(viewer, name), value|
              changes << [viewer, child.cid, name, value]
              true
            end
          end
          # Seed before allowing live writes through Page#set. Otherwise a
          # newer write can be overwritten by this older unpublished value.
          # Seeding only locks viewer state and schedules work; it never renders.
          @service.runtime.seed_viewer_properties(page, changes) unless changes.empty?
          @nodes.each_value { |child| child.published = true if !child.equal?(root) && root_for(child).equal?(root) && delivered.key?(child.cid) }
        end
        publish = @mutex.synchronize do
          next false unless handle_for(root)

          !root.published || (root.present_requested && !root.props.dig(:presentation, :hidden))
        end
        @on_publish&.call(page) if publish
        @mutex.synchronize do
          root.published = true
          root.present_requested = false
        end
      end

      # Registers and binds one page for a root while preserving its handle-derived identity.
      # @param root [Node] owned page root under the adapter monitor
      # @return [Page] root page
      # @raise [Error] for non-page roots
      # @api private
      def ensure_page!(root)
        return root.page if root.page
        raise attributed_error('only page roots can be rendered') unless root.type == :page

        adapter = self
        page = Page.new(
          owner: @owner, id: adapter_page_id(root), title: root.props.fetch(:title),
          props: root.props.except(:title), on: callbacks_for(root)
        ) do |builder|
          adapter.send(:render_children, builder, root)
        end
        @service.registry.register(page)
        page.bind_runtime(@service.runtime)
        root.page = page
      end

      # Coalesces adapter publication work through the core runtime for a page root.
      # @param root [Node] root whose next publication is coalesced
      # @return [void]
      # @api private
      def dirty!(root)
        return unless root.type == :page

        @dirty_roots[root] = true
        return if @publication_pending

        @publication_pending = true
        @service.runtime.schedule_render(self, owner: @owner) do
          # Publish after queued construction and callbacks, never in the middle
          # of their model/default updates. Keep a single pending owner task even
          # when a long callback spans several render-coalescing intervals.
          begin
            @service.runtime.dispatch(owner: @owner) do
              @mutex.synchronize { @publication_pending = false }
              flush!
            end
          rescue StandardError
            @mutex.synchronize { @publication_pending = false }
            raise
          end
        end
      rescue StandardError
        @publication_pending = false
        raise
      end

      # Closes one published page through its existing runtime lifecycle owner.
      # @param page [Page] registered page to close
      # @return [void]
      # @api private
      def close_page(page)
        @service.runtime.close_page(page, reason: :owner)
      end
    end
  end
end
