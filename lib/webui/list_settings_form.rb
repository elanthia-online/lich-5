# frozen_string_literal: true

require_relative 'settings_form'

module Lich
  module WebUI
    # Presentation for the Add/Entry/Delete tables used by native setup windows.
    # Scripts own rows, mutations and submitted values. This class supplies
    # identities and selection only; it never normalizes list contents.
    class ListSettingsForm < SettingsForm
      # Describes a single text column using caller-owned values and mutations.
      # Reads remain lazy so replaced arrays are reflected on the next render.
      # Add/Delete callbacks are passed through without validation or normalization.
      # @param value [#call] returns the current text list
      # @param add [#call] existing callback receiving entered text
      # @param delete [#call] existing callback receiving the selected row index
      # @param label [String] original column label, including an empty label
      # @param clear_after_add [Boolean] caller's existing entry-clearing policy
      # @return [Hash] definition accepted by ListSettingsForm's lists argument
      def self.text_list_spec(value:, add:, delete:, label: '', clear_after_add: false)
        { columns: [{ key: 'text', label: label }],
          rows: proc { value.call.map { |text| { 'text' => text } } },
          value: value, add: add, delete: delete, clear_after_add: clear_after_add }
      end

      # Adds table/entry/action fields for caller-owned lists to a settings form.
      # @param lists [Hash] list keys mapped to columns and read/add/delete callbacks
      # @param options [Hash] SettingsForm options including ordinary fields
      def initialize(lists:, **options)
        @lists = lists
        @selection = {}
        @entries = {}
        @list_revision = Hash.new(0)
        fields = options.fetch(:fields).reject { |field| lists.key?(field[:key]) }
        lists.each_key do |key|
          fields += [key, :"#{key}_entry", :"#{key}_add", :"#{key}_delete"].map { |name| { key: name, type: :table } }
        end
        super(**options.merge(fields: fields))
      end

      private

      # Renders list rows or their entry/action controls with an explicit submission scope.
      # Ordinary fields keep the base settings-form renderer.
      # @return [Object] rendered field reference, when applicable
      def render_field(tree, field, refs, **overrides)
        return unless field
        key = field[:key]
        if @lists.key?(key)
          overrides.delete(:label)
          definition = @lists.fetch(key)
          rows = definition.fetch(:rows).call.each_with_index.map do |cells, index|
            { key: "row-#{index}", cells: cells }
          end
          tree.table(key: key.to_s, columns: definition.fetch(:columns), rows: rows,
                     selection: :single, selected: @selection[key] ? [@selection[key]] : [], **overrides,
                     on: { selection_change: proc { |event| @selection[key] = event.payload[:rows].first } })
        elsif (match = /\A(.+)_(entry|add|delete)\z/.match(key.to_s)) && @lists.key?(match[1].to_sym)
          overrides.delete(:label) if overrides[:label].nil?
          list, action = match[1].to_sym, match[2]
          if action == 'entry'
            @entries[list] = tree.text_input(key: "#{key}-#{@list_revision[list]}", value: '', **overrides)
          else
            scope = action == 'add' ? [@entries.fetch(list)] : []
            tree.button(key: key.to_s, **overrides, submit: scope,
                        on: { activate: proc { |event| change_list(list, action, event) } })
          end
        else
          super
        end
      end

      # Invokes the caller's list mutation and refreshes; never normalizes list contents.
      # A revision changes entry identity only when the caller requests clearing after Add.
      # @return [void]
      def change_list(key, action, event)
        definition = @lists.fetch(key)
        if action == 'add'
          text = event.submission[@entries.fetch(key).cid]
          definition.fetch(:add).call(text)
          @selection.delete(key)
          @list_revision[key] += 1 if definition[:clear_after_add]
        elsif @selection[key]
          definition.fetch(:delete).call(@selection[key].delete_prefix('row-').to_i)
          @selection.delete(key)
        end
        @values[key] = definition.fetch(:value).call
        WebUI.refresh(@page)
      end

      # Reads current caller-owned lists before delegating ordinary field persistence.
      # @return [void]
      def save(submission, refs)
        @lists.each { |key, definition| @values[key] = definition.fetch(:value).call }
        super
      end
    end
  end
end
