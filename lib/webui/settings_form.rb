# frozen_string_literal: true

require_relative 'value_helpers'

module Lich
  module WebUI
    # Native setup forms share terminal submission and cancellation, not game
    # logic. go2, ecleanse and ewaggle supply their own fields and normalization.
    # No draft is persisted here; the owning script receives one accepted copy.
    class SettingsForm
      attr_reader :page

      # Formats already prepared choices without changing their values or order.
      # Blank and duplicate choices remain present; callers own coercion, labels
      # that differ from values, and the selected/default value.
      # @param choices [Enumerable] prepared string choices
      # @return [Array<Hash>] records for the existing select/radio contract
      def self.choice_options(choices)
        choices.map { |value| { value: value, label: value } }
      end

      # Prepares a settings editor without displaying it or persisting values.
      # Hashes, arrays and strings in the initial values and fields are copied.
      # The owning script supplies any normalization and persistence policy.
      #
      # @param owner [Object] lifetime identity for the form's page
      # @param id [String] page identifier unique within the owner
      # @param title [String] window title
      # @param values [Hash] initial settings keyed by field key
      # @param fields [Array<Hash>] field definitions with unique :key, component
      #   :type, optional :group and component properties
      # @param normalize [Proc, nil] receives a copied submitted Hash and must
      #   return a Hash; ArgumentError displays validation feedback and keeps
      #   the form open; nil uses the submitted values unchanged
      # @param tabbed [Boolean] whether the default layout puts groups in tabs
      # @param layout [Proc, nil] custom layout called with the tree builder,
      #   a field-rendering callable and a save-button-rendering callable
      # @param props [Hash] page properties overriding the form defaults
      # @raise [ArgumentError] if field keys are duplicated
      def initialize(owner:, id:, title:, values:, fields:, normalize: nil, tabbed: false, layout: nil, props: {})
        @owner, @id, @title = owner, id, title
        @values = copy(values)
        @fields = copy(fields)
        @normalize = normalize || proc { |draft| draft }
        @tabbed = tabbed
        @layout = layout
        @props = { bare: true, density: :compact }.merge(props)
        @input_revision = 0
        @completion = Future.new
        @error = ''
        keys = @fields.map { |field| field.fetch(:key) }
        raise ArgumentError, 'form field keys must be unique' unless keys.uniq == keys
      end

      # Displays a form and waits on the calling script thread for completion.
      # Does not save settings to disk or change the caller's settings object.
      #
      # @param options [Hash] arguments accepted by #initialize
      # @return [Hash, nil] normalized settings on Save, or nil on cancellation
      # @raise [Dispatcher::ReentryError] if called from a WebUI callback
      def self.edit(**options)
        new(**options).show.wait
      end

      # Registers, renders and opens the form without waiting for completion.
      # A refused window launch cancels the form so #wait returns without blocking.
      # @return [SettingsForm] this form, ready for #wait
      # @raise [ArgumentError] if this instance has already been shown
      def show
        raise ArgumentError, 'form is already shown' if @page

        form = self
        @page = WebUI.page(owner: @owner, id: @id, title: @title, props: @props, on: { close: proc { close } }) do |builder|
          form.send(:render, builder)
        end
        WebUI.refresh(@page)
        WebUI.start
        close unless WebUI.open(page: @page)
        self
      rescue StandardError
        close
        raise
      end

      # Called on the owning script thread, never from an event callback.
      # Always closes the page when the wait ends, including interruption.
      #
      # @return [Hash, nil] normalized settings on Save, or nil on cancellation
      # @raise [Dispatcher::ReentryError] if called from a WebUI callback
      def wait
        @completion.await.button
      ensure
        close
      end

      # Cancels an unresolved form and releases its page. A completed Save
      # retains its result; closing again does not change that completion.
      # @return [nil]
      def close
        @completion.cancel
        WebUI.close(@page) if @page
        nil
      end

      private

      # Composes caller-supplied or default layout while retaining the form's submission lifecycle.
      # @return [void]
      def render(builder)
        refs = {}
        if @layout
          # The script supplies native layout only. Field values, submission
          # scope and cancellation stay in this shared form lifecycle.
          @layout.call(builder,
                       ->(parent, key, **overrides) { render_field(parent, @fields.find { |field| field[:key] == key }, refs, **overrides) },
                       ->(parent, **props) { render_save(parent, refs, **props) })
          builder.text(key: 'validation', content: @error, tone: :danger) unless @error.empty?
          return
        end
        form = self
        groups = @fields.group_by { |field| field.fetch(:group, 'Settings') }
        if @tabbed
          builder.tabs(key: 'sections', names: groups.keys, selected: 0, on: { select: proc {} }) do
            form.send(:render_groups, self, groups, refs, tabbed: true)
          end
        else
          render_groups(builder, groups, refs)
        end
        builder.text(key: 'validation', content: @error, tone: :danger)
        render_actions(builder, refs)
        render_save(builder, refs)
        builder.button(key: 'cancel', label: 'Cancel', on: { activate: proc { close } })
      end

      # Domain forms may add an explicit, non-saving action over the same
      # terminal field references (for example Eloot's tipping preview).
      # They reuse field rendering and lifecycle without exposing viewer drafts.
      def render_actions(_builder, _refs); end

      # Binds Save to the collected field references so validation sees one explicit snapshot.
      # @return [TreeBuilder::Draft] save button reference
      def render_save(builder, refs, label: 'Save & Close', **props)
        builder.button(key: 'save', label: label, **props, submit: refs.values,
                       on: { activate: proc { |event| save(event.submission, refs) } })
      end

      # Explicit reset/load actions replace the submitted draft. Fresh input
      # identities prevent a viewer's older dirty value overriding that reset.
      def replace_values(values)
        @values = copy(values)
        @input_revision += 1
      end

      # Large native setup screens retain the same terminal submission across
      # viewer-local tabs; switching a tab neither saves nor shares a draft.
      def render_groups(builder, groups, refs, tabbed: false)
        form = self
        groups.each_with_index do |(label, fields), index|
          builder.group(label: label, key: "section-#{index}", slot: tabbed ? label : nil) do
            fields.each do |field|
              form.send(:render_field, self, field, refs)
            end
          end
        end
      end

      # Maps a field to its current value and preserves caller-owned live-change timing.
      # Exclusive checkbox groups uncheck peers only in the originating viewer.
      # @return [TreeBuilder::Draft, nil] control reference, or nil for an absent field
      def render_field(builder, field, refs, **overrides)
        return unless field # Some original controls are absent outside GS.

        key, type = field.values_at(:key, :type)
        props = field.reject { |name, _| %i[type group exclusive].include?(name) }.merge(overrides)
        props.delete(:label) if props[:label].nil?
        props[:label] = '' if type == :checkbox && !props.key?(:label)
        props[:key] = input_key(key)
        return builder.component(type, **props) if type == :text

        # Script-owned live settings callbacks mirror GtkEntry's changed signal.
        # Forms without one retain the ordinary committed-entry timing.
        props[:change_mode] ||= :input if type == :text_input && props[:on]&.key?(:change)

        props[type == :checkbox ? :checked : :value] = field_value(key, type)
        props.delete(:value) if type == :select && props[:value].nil?
        if field[:exclusive]
          changed = props[:on]&.fetch(:change, nil)
          props[:on] = { change: proc do |event|
            changed&.call(event)
            next unless event.payload[:value]
            @fields.select { |other| other[:exclusive] == field[:exclusive] && other[:key] != key }.each do |other|
              @page.set(refs.fetch(other[:key]).cid, :checked, false, viewer: event.viewer_id)
            end
          end }
        end
        refs[key] = builder.component(type, **props)
      end

      # Adds a revision only when the form needs to replace browser-retained input state.
      # @return [String] stable field identity within the revision
      def input_key(key)
        @input_revision.zero? ? key.to_s : "#{key}--revision-#{@input_revision}"
      end

      # Projects array-backed textarea settings into newline-separated display text.
      # @return [Object] displayed field value
      def field_value(key, type)
        value = @values.fetch(key)
        type == :textarea && value.is_a?(Array) ? value.join("\n") : value
      end

      # Normalizes a copied submission and completes once; validation errors retain the draft.
      # Only successful normalization closes the page and resolves its completion.
      # @return [void]
      def save(submission, refs)
        return if @completion.resolved?

        draft = copy(@values)
        refs.each { |key, ref| draft[key] = submission[ref.cid] }
        result = @normalize.call(copy(draft))
        raise ArgumentError, 'form normalization must return settings' unless result.is_a?(Hash)

        @completion.resolve(button: result)
        WebUI.close(@page)
      rescue ArgumentError => error
        @values = draft if draft
        @error = error.message[0, Contract::BOUNDS[:body_text]]
        WebUI.refresh(@page)
      end

      # Copies nested settings hashes, arrays, and strings so form edits do not mutate caller data.
      # @return [Object] copied setting value
      def copy(value)
        ValueHelpers.deep_copy(value)
      end
    end
  end
end
