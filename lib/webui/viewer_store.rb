# frozen_string_literal: true

require 'securerandom'
require_relative 'component'

module Lich
  module WebUI
    # Per-page viewer attachments and viewer-local state.
    #
    # Each browser that opens a page gets an {Attachment}: a viewer id, a
    # resume token that survives a dropped socket for {RECONNECT_WINDOW}
    # seconds, the render it was last sent, and an overlay of the
    # viewer-scoped property values it has changed. {#serialize} merges that
    # overlay into the page's tree so each viewer sees its own inputs.
    class ViewerStore
      # Seconds a dropped viewer may reconnect with its resume token before its state is destroyed.
      RECONNECT_WINDOW = 60

      # One viewer's connection to one page.
      class Attachment
        # @!attribute connection_id
        #   @return [String] the WebSocket connection currently carrying this viewer
        # @!attribute render
        #   @return [Page::Render, nil] the render last delivered to this viewer
        # @!attribute delivered_generation
        #   @return [Integer, nil] the generation of that render
        # @!attribute expires_at
        #   @return [Float, nil] monotonic time the attachment expires, while its socket is dropped
        attr_accessor :connection_id, :render, :delivered_generation, :expires_at
        # @!attribute [r] viewer_id
        #   @return [String] the viewer's id on this page
        # @!attribute [r] resume_token
        #   @return [String] the secret a reconnecting client presents to resume
        # @!attribute [r] address
        #   @return [String] the page's wire address
        # @!attribute [r] page
        #   @return [Page] the page
        # @!attribute [r] values
        #   @return [Hash{Array(String, Symbol, String) => Object}] viewer-local values keyed by `[cid, property]`
        attr_reader :viewer_id, :resume_token, :address, :page, :values

        # Builds an attachment with fresh viewer and resume ids.
        #
        # @param connection_id [String] the connection carrying the viewer
        # @param address [String] the page's wire address
        # @param page [Page] the page
        # @return [Attachment]
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

      # Builds an empty store.
      #
      # @param clock [#call] answers monotonic seconds; injectable for specs
      # @return [ViewerStore]
      def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        @clock = clock
        @by_connection = {}
        @by_resume = {}
        @mutex = Mutex.new
      end

      # Attaches a connection to a page, resuming a dropped attachment when a valid token is given.
      #
      # @param connection_id [String] the connection
      # @param address [String] the page's wire address
      # @param page [Page] the page
      # @param resume_token [String, nil] a token from an earlier attachment
      # @return [Attachment] the new or resumed attachment
      # @raise [Error] when the token belongs to another page or to an attachment still connected
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

      # The attachment a connection has on a page.
      #
      # @param connection_id [String] the connection
      # @param address [String] the page's wire address
      # @return [Attachment]
      # @raise [Error] when the connection is not attached to that page
      def fetch(connection_id:, address:)
        @mutex.synchronize do
          expire_locked!
          @by_connection.fetch([connection_id, address])
        end
      rescue KeyError
        raise Error, 'viewer is not attached to page'
      end

      # A connection dropped: its attachments start their reconnect window.
      #
      # @param connection_id [String] the connection
      # @return [Array<Attachment>] the attachments now awaiting a resume
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

      # A viewer explicitly left a page: its attachment is destroyed at once.
      #
      # @param connection_id [String] the connection
      # @param address [String] the page's wire address
      # @return [Attachment, nil] the destroyed attachment, or nil when there was none
      def close(connection_id:, address:)
        @mutex.synchronize do
          attachment = @by_connection.delete([connection_id, address])
          destroy_locked!(attachment) if attachment
          attachment
        end
      end

      # Destroys every attachment to a page.
      #
      # @param page [Page] the page
      # @return [void]
      def destroy_page(page)
        @mutex.synchronize do
          @by_resume.values.select { |attachment| attachment.page.equal?(page) }.uniq.each do |attachment|
            destroy_locked!(attachment)
          end
        end
      end

      # Every live (connected) attachment to a page.
      #
      # @param page [Page] the page
      # @return [Array<Attachment>]
      def attachments_for(page)
        @mutex.synchronize do
          expire_locked!
          @by_resume.values.select { |attachment| attachment.page.equal?(page) && !attachment.expires_at }.uniq
        end
      end

      # The live attachment of one viewer to a page.
      #
      # @param page [Page] the page
      # @param viewer_id [String] the viewer
      # @return [Attachment]
      # @raise [Error] when that viewer is not attached to the page
      def attachment_for_viewer(page, viewer_id)
        @mutex.synchronize do
          expire_locked!
          @by_resume.values.find do |attachment|
            attachment.page.equal?(page) && attachment.viewer_id == viewer_id && !attachment.expires_at
          end
        end || raise(Error.new('viewer is not attached to page', page_id: page.id))
      end

      # A viewer's copy of a property, or the component's own value when the viewer has not changed it.
      #
      # @param attachment [Attachment] the viewer
      # @param component [Component] the component
      # @param name [Symbol] the property name
      # @return [Object] the value
      def property(attachment, component, name)
        @mutex.synchronize { attachment.values.fetch([component.cid, name], component.props[name]) }
      end

      # Overwrites a viewer's copy of a property.
      #
      # @param attachment [Attachment] the viewer
      # @param component [Component] the component
      # @param name [Symbol] the property name
      # @param value [Object] the new value
      # @return [Object] the value
      def set_property(attachment, component, name, value)
        @mutex.synchronize { attachment.values[[component.cid, name]] = value }
      end

      # Records that a render was sent to a viewer and seeds its overlay from the tree.
      #
      # @param attachment [Attachment] the viewer
      # @param render [Page::Render] the render delivered
      # @return [void]
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

      # Whether an event updates the viewer's overlay.
      #
      # @param type [Symbol] the component type
      # @param event [Symbol] the event name
      # @return [Boolean] whether this event updates the viewer's overlay
      def self.viewer_state_event?(type, event)
        VIEWER_STATE_EVENTS.key?([type, event])
      end

      # Whether the owner is re-rendered after an event.
      #
      # @param type [Symbol] the component type
      # @param event [Symbol] the event name
      # @return [Boolean] whether the owner is re-rendered after this event
      def self.refresh_after?(type, event)
        entry = VIEWER_STATE_EVENTS[[type, event]]
        !entry.nil? && entry.fetch(:refresh, true)
      end

      # Applies a viewer-state event's payload to the viewer's overlay; see {VIEWER_STATE_EVENTS}.
      #
      # @param attachment [Attachment] the viewer
      # @param component [Component] the component the event came from
      # @param event [Symbol] the event name
      # @param payload [Hash{Symbol => Object}] the event payload
      # @return [Object, nil] the value recorded, or nil when the event is not a viewer-state event
      def update(attachment, component, event, payload)
        entry = VIEWER_STATE_EVENTS[[component.type, event]]
        return unless entry

        property = entry[:property]
        property = property.call(payload) if property.respond_to?(:call)
        @mutex.synchronize { attachment.values[[component.cid, property]] = entry[:value].call(payload) }
      end

      # Sets an input component's viewer-local value under whichever property that type uses.
      #
      # @param attachment [Attachment] the viewer
      # @param component [Component] an input component
      # @param value [Object] the new value
      # @return [Object, nil] the value, or nil when the component type has no input property
      def set_input(attachment, component, value)
        property = input_property(component.type)
        @mutex.synchronize { attachment.values[[component.cid, property]] = value } if property
      end

      # The viewer's delivered tree in wire form, with its overlay merged in and secrets left out.
      #
      # @param attachment [Attachment] the viewer
      # @return [Hash{Symbol => Object}] the serialized root component
      # @raise [Error] when no render has been delivered to the viewer
      def serialize(attachment)
        @mutex.synchronize do
          render = attachment.render
          raise Error, 'viewer has no delivered render' unless render

          serialize_component(render.tree, attachment.values)
        end
      end

      private

      # Copies each viewer-scoped prop into the overlay, unless the viewer already has a value.
      # @api private
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
