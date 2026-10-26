# frozen_string_literal: true

module Lich
  module WebUI
    class ViewerStore
      # Records the newest render accepted for one viewer and seeds its values.
      # Refresh and attach can finish out of order. An older render must not
      # replace the tree, lower the event generation, or invalidate selections.
      # Equal generations may be redelivered; existing viewer values survive.
      #
      # @param attachment [Attachment] viewer receiving the page render
      # @param render [Page::Render] validated render for the attachment's page
      # @return [void]
      def deliver(attachment, render)
        @mutex.synchronize do
          current = attachment.delivered_generation
          next if current && render.generation < current

          signature = widget_signature(render)
          now = @clock.call
          update_release_epochs(attachment, render, now)
          changed = signature != attachment.widget_signature
          if changed || !attachment.widget_started_at || now - attachment.widget_started_at >= WIDGET_ADMISSION_WINDOW
            attachment.widget_revision += 1 if changed
            attachment.widget_signature = signature
            attachment.widget_generation = signature && render.generation
            attachment.widget_started_at = now
          end
          previous_components = attachment.render ? attachment.render.tree.each.to_h { |node| [node.cid, node] } : {}
          attachment.render = render
          attachment.delivered_generation = render.generation
          previous = attachment.values.select { |(_cid, property), value| property == :checked && value }.keys
          seed_values!(attachment, render.tree, previous_components)
          live_inputs = render.tree.each.select { |node| node.type == :text_input && !node.props[:sensitive] }.to_h { |node| [node.cid, true] }
          attachment.input_requests.keep_if { |cid, _request| live_inputs.key?(cid) }
          render.tree.each.select { |node| node.type == :radio_option }.group_by { |node| node.props[:group] }.each_value do |members|
            selected = members.select { |node| attachment.values[[node.cid, :checked]] }
            next if selected.length < 2

            retained = selected.find { |node| previous.include?([node.cid, :checked]) } || selected.first
            select_radio_option!(attachment, retained)
          end
        end
      end

      private

      # Seeds only absent viewer fields and repairs removed select choices without fabricating events.
      # Requires the store mutex; existing unrelated viewer edits remain intact.
      # @param attachment [Attachment] exact viewer/page association
      # @param component [Component] validated delivered component
      # @param previous_components [Hash{String => Component}] previously delivered components keyed by identity
      # @return [void]
      # @api private
      def seed_values!(attachment, component, previous_components = {})
        schema = Contract.schema(component.type)
        schema[:properties].each do |name, definition|
          next unless definition[:scope] == :viewer && component.props.key?(name)

          key = [component.cid, name]
          attachment.values[key] = component.props[name] unless attachment.values.key?(key)
          # Option removal invalidates only viewers selecting the removed item.
          # Other viewers retain their own choice; no callback is fabricated.
          if component.type == :select && name == :value
            old_options = previous_components[component.cid]&.props&.fetch(:options, []) || []
            was_option = old_options.any? { |option| option[:value] == attachment.values[key] }
            if (!component.props[:editable] || was_option) && component.props[:options].none? { |option| option[:value] == attachment.values[key] }
              attachment.values[key] = component.props[:empty_value] || component.props[name]
            end
          end
        end
        reconcile_table!(attachment.values, component, previous_components[component.cid]) if component.type == :table
        reconcile_tabs!(attachment.values, component, previous_components[component.cid]) if component.type == :tabs
        component.children.each { |child| seed_values!(attachment, child, previous_components) }
      end

      # Preserve each viewer's selected tab identity when preceding pages retire.
      # Removing the selected page chooses the next page, or the previous last page.
      # @param values [Hash] this viewer's property overrides under the store monitor
      # @param component [Component] validated delivered component
      # @param previous [Component, nil] previously delivered component with the same identity
      # @return [void]
      # @api private
      def reconcile_tabs!(values, component, previous)
        return unless component.props[:headers]

        field = [component.cid, :selected]
        index = values.fetch(field, component.props[:selected] || 0)
        values[field] = Contract.remap_tab_index(previous&.props&.[](:headers), component.props[:headers], index, component.props[:names].length)
      end

      # Removes only identities retired from this table; another viewer's choices are untouched.
      # @param values [Hash] this attachment's overrides, under the store lock
      # @param component [Component] replacement table
      # @param previous [Component, nil] previously delivered table, for new-row defaults
      # @return [void]
      # @api private
      def reconcile_table!(values, component, previous)
        props, cid = component.props, component.cid
        keys = props[:rows].map { |row| row[:key] }
        selected = values.fetch([cid, :selected], props[:selected] || []) & keys
        selected = [] if props[:selection] == 'none'
        selected = selected.first(1) unless props[:selection] == 'multi'
        selected = keys.first(1) if props[:selection] == 'browse' && selected.empty?
        values[[cid, :selected]] = selected
        initial = props[:expanded] || props[:rows].select { |row| row[:expanded] }.map { |row| row[:key] }
        previous_keys = previous&.props&.fetch(:rows, [])&.map { |row| row[:key] } || []
        # New identities receive their defaults; retained rows keep the viewer's choice.
        values[[cid, :expanded]] = (values.fetch([cid, :expanded], initial) & keys) | (initial & (keys - previous_keys))
        cursor = values.fetch([cid, :cursor], props[:cursor] || {})
        cursor = {} unless keys.include?(cursor[:row])
        columns = props[:columns].map { |column| column[:key] }
        cursor = cursor.reject { |name, value| name == :column && !columns.include?(value) }
        values[[cid, :cursor]] = cursor
      end
    end
  end
end
