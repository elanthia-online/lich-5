# frozen_string_literal: true

require 'securerandom'
require_relative 'component'

module Lich
  module WebUI
    # Per-page viewer attachments and viewer-local state.
    class ViewerStore
      RECONNECT_WINDOW = 60

      class Attachment
        attr_accessor :connection_id, :render, :delivered_generation, :expires_at
        attr_reader :viewer_id, :resume_token, :address, :page, :values

        def initialize(connection_id:, address:, page:)
          @connection_id = connection_id
          @viewer_id = "attachment-#{SecureRandom.hex(16)}".freeze
          @resume_token = "resume-#{SecureRandom.hex(16)}".freeze
          @address = address.freeze
          @page = page
          @values = {}
          @render = nil
          @delivered_generation = nil
          @expires_at = nil
        end
      end

      def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        @clock = clock
        @by_connection = {}
        @by_resume = {}
        @mutex = Mutex.new
      end

      def attach(connection_id:, address:, page:, resume_token: nil)
        @mutex.synchronize do
          expire_locked!
          attachment = resume_token && @by_resume[resume_token]
          if attachment
            raise Error, 'resume token belongs to another page' unless attachment.address == address
            raise Error, 'viewer is already attached' unless attachment.expires_at

            remove_connection_mapping!(attachment)
            attachment.connection_id = connection_id
            attachment.expires_at = nil
          else
            attachment = Attachment.new(connection_id: connection_id, address: address, page: page)
            @by_resume[attachment.resume_token] = attachment
          end
          @by_connection[[connection_id, address]] = attachment
          attachment
        end
      end

      def fetch(connection_id:, address:)
        @mutex.synchronize do
          expire_locked!
          @by_connection.fetch([connection_id, address])
        end
      rescue KeyError
        raise Error, 'viewer is not attached to page'
      end

      def transient_disconnect(connection_id)
        @mutex.synchronize do
          attachments = @by_connection.each_value.select { |attachment| attachment.connection_id == connection_id }.uniq
          attachments.each do |attachment|
            attachment.expires_at = @clock.call + RECONNECT_WINDOW
          end
          @by_connection.delete_if { |(candidate, _address), _attachment| candidate == connection_id }
          attachments
        end
      end

      def close(connection_id:, address:)
        @mutex.synchronize do
          attachment = @by_connection.delete([connection_id, address])
          destroy_locked!(attachment) if attachment
          attachment
        end
      end

      def destroy_page(page)
        @mutex.synchronize do
          @by_resume.values.select { |attachment| attachment.page.equal?(page) }.uniq.each do |attachment|
            destroy_locked!(attachment)
          end
        end
      end

      def attachments_for(page)
        @mutex.synchronize do
          expire_locked!
          @by_resume.values.select { |attachment| attachment.page.equal?(page) && !attachment.expires_at }.uniq
        end
      end

      def attachment_for_viewer(page, viewer_id)
        @mutex.synchronize do
          expire_locked!
          @by_resume.values.find do |attachment|
            attachment.page.equal?(page) && attachment.viewer_id == viewer_id && !attachment.expires_at
          end
        end || raise(Error.new('viewer is not attached to page', page_id: page.id))
      end

      def property(attachment, component, name)
        @mutex.synchronize { attachment.values.fetch([component.cid, name], component.props[name]) }
      end

      def set_property(attachment, component, name, value)
        @mutex.synchronize { attachment.values[[component.cid, name]] = value }
      end

      def deliver(attachment, render)
        @mutex.synchronize do
          attachment.render = render
          attachment.delivered_generation = render.generation
          seed_values!(attachment, render.tree)
        end
      end

      # Every event that changes a viewer's own copy of a property, in one
      # place: which property the overlay records, what it takes from the
      # payload, and whether the owner is re-rendered afterwards. The runtime
      # used to keep its own list of these for the refresh decision, so an
      # event could update the overlay and forget the refresh, or the other
      # way round; both now read this table.
      #
      # `refresh: false` is for an event whose effect the client already
      # showed and the owner has nothing to answer (a menu closing).
      VIEWER_STATE_EVENTS = {
        [:toggle, :change]          => { property: :checked,  value: ->(payload) { payload[:value] } },
        [:checkbox, :change]        => { property: :checked,  value: ->(payload) { payload[:value] } },
        [:radio, :change]           => { property: :selected, value: ->(payload) { payload[:value] } },
        [:text_input, :change]      => { property: :value,    value: ->(payload) { payload[:value] } },
        [:textarea, :change]        => { property: :value,    value: ->(payload) { payload[:value] } },
        [:number_input, :change]    => { property: :value,    value: ->(payload) { payload[:value] } },
        [:slider, :change]          => { property: :value,    value: ->(payload) { payload[:value] } },
        [:select, :change]          => { property: :value,    value: ->(payload) { payload[:value] } },
        [:tabs, :select]            => { property: :selected, value: ->(payload) { payload[:index] } },
        [:expander, :toggle]        => { property: :open,     value: ->(payload) { payload[:open] } },
        [:split, :move]             => { property: :position, value: ->(payload) { payload[:position] } },
        [:table, :selection_change] => { property: :selected, value: ->(payload) { payload[:rows] } },
        [:table, :sort_change]      => { property: :sort,
                                         value: ->(payload) { { column: payload[:column], direction: payload[:direction] }.freeze } },
        [:table, :row_toggle]       => { property: ->(payload) { "expanded:#{payload[:row]}" },
                                         value: ->(payload) { payload[:expanded] } },
        # A check menu item's `active` is viewer-scoped like the rest, and the
        # viewer's overlay copy shadows the shared prop from the first render
        # on. Without a refresh the owner's answer -- including a script that
        # refuses the change and sets it back -- never reaches the screen.
        [:menu_item, :change]       => { property: :active,   value: ->(payload) { payload[:value] } },
        [:menu, :close]             => { property: :open,     value: ->(_payload) { false }, refresh: false },
      }.freeze

      # @return [Boolean] whether this event updates the viewer's overlay
      def self.viewer_state_event?(type, event)
        VIEWER_STATE_EVENTS.key?([type, event])
      end

      # @return [Boolean] whether the owner is re-rendered after this event
      def self.refresh_after?(type, event)
        entry = VIEWER_STATE_EVENTS[[type, event]]
        !entry.nil? && entry.fetch(:refresh, true)
      end

      def update(attachment, component, event, payload)
        entry = VIEWER_STATE_EVENTS[[component.type, event]]
        return unless entry

        property = entry[:property]
        property = property.call(payload) if property.respond_to?(:call)
        @mutex.synchronize { attachment.values[[component.cid, property]] = entry[:value].call(payload) }
      end

      def set_input(attachment, component, value)
        property = input_property(component.type)
        @mutex.synchronize { attachment.values[[component.cid, property]] = value } if property
      end

      def serialize(attachment)
        @mutex.synchronize do
          render = attachment.render
          raise Error, 'viewer has no delivered render' unless render

          serialize_component(render.tree, attachment.values)
        end
      end

      private

      def seed_values!(attachment, component)
        schema = Contract.schema(component.type)
        schema[:properties].each do |name, definition|
          next unless definition[:scope] == :viewer && component.props.key?(name)

          key = [component.cid, name]
          attachment.values[key] = component.props[name] unless attachment.values.key?(key)
        end
        component.children.each { |child| seed_values!(attachment, child) }
      end

      def serialize_component(component, values)
        props = component.props.each_with_object({}) do |(name, value), result|
          definition = Contract.schema(component.type)[:properties][name]
          next if definition && %i[sensitive_write_only ephemeral_client].include?(definition[:scope])
          next if name == :value && (component.type == :password_input || component.props[:sensitive] == true)

          result[name] = definition && definition[:scope] == :viewer ? values.fetch([component.cid, name], value) : value
        end
        if component.type == :table
          props[:rows] = props[:rows].map do |row|
            expanded = values.fetch([component.cid, "expanded:#{row[:key]}"], row[:expanded])
            row.merge(expanded: expanded)
          end
        end
        result = { type: component.type.to_s, cid: component.cid, props: props, children: component.children.map { |child| serialize_component(child, values) } }
        result[:slot] = component.slot if component.slot
        result[:placement] = component.placement unless component.placement.empty?
        result
      end

      def input_property(type)
        case type
        when :toggle, :checkbox then :checked
        when :radio then :selected
        when :text_input, :textarea, :number_input, :slider, :select then :value
        end
      end

      def expire_locked!
        now = @clock.call
        @by_resume.values.select { |attachment| attachment.expires_at && attachment.expires_at <= now }.uniq.each do |attachment|
          destroy_locked!(attachment)
        end
      end

      def destroy_locked!(attachment)
        return unless attachment

        remove_connection_mapping!(attachment)
        @by_resume.delete(attachment.resume_token)
        attachment.values.clear
        attachment.render = nil
        attachment.delivered_generation = nil
      end

      def remove_connection_mapping!(attachment)
        @by_connection.delete_if { |_key, candidate| candidate.equal?(attachment) }
      end
    end
  end
end
