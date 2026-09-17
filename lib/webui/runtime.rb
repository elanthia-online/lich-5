# frozen_string_literal: true

require_relative 'dispatcher'
require_relative 'protocol'
require_relative 'submission'
require_relative 'viewer_store'

module Lich
  module WebUI
    # Server-routed page attachment, viewer state, submission, and callback runtime.
    #
    # The runtime sits between the {Server} (browser connections and parsed protocol
    # messages) and the script side ({Page}, its callbacks and the {Dispatcher} that runs
    # them). It attaches viewers to pages, delivers renders, validates and routes events
    # into callbacks, holds the per-viewer state through {ViewerStore}, answers property
    # reads and writes on a page's behalf, and tears everything down when an owner or a
    # page goes away.
    class Runtime
      # What a callback receives: the viewer that acted, the page, the component, the event
      # name, its validated payload and, for terminal events, the {Submission} snapshot.
      EventContext = Data.define(:viewer_id, :page, :component, :event, :payload, :submission)
      # What a browser page can do on its own. always_on_top and borderless
      # belong to the window manager, not the page, and a CSS fade cannot make
      # a window translucent -- what shows through is the browser's own
      # background. On a host that can reach the real window (native Windows,
      # through WindowPresentation) the first and third become true; the key
      # set never changes, only the values, because the degradation walk reads
      # every requested property out of this table.
      #
      # @return [Hash{Symbol => Boolean}] presentation property to whether a bare browser page supports it
      PRESENTATION_SUPPORT = {
        always_on_top: false, borderless: false, opacity: true, scrollbars: true,
      }.freeze

      # Creates a runtime over a page registry and its collaborators.
      #
      # +dispatcher+ defaults to one that logs where the runtime does; a
      # Dispatcher.new default here had no logger, so what its owner threads
      # rescued went nowhere whatever the service was given.
      #
      # @param registry [Registry] where pages and their addresses are looked up
      # @param dispatcher [Dispatcher, nil] runs callbacks on per-owner threads; nil builds one sharing +logger+
      # @param viewers [ViewerStore] holds attachments and viewer-scoped state
      # @param validator [Validator] checks event payloads, submissions and property writes
      # @param file_service [FileService, nil] resolves image sources to served files; nil refuses all
      #   non-inline sources
      # @param logger [#call, nil] receives `(level, message)`; nil discards
      # @return [Runtime] the new runtime
      def initialize(registry:, dispatcher: nil, viewers: ViewerStore.new,
                     validator: Validator.new, file_service: nil, logger: nil)
        @registry = registry
        @logger = logger || proc { |_level, _message| }
        @dispatcher = dispatcher || Dispatcher.new(logger: @logger)
        @viewers = viewers
        @validator = validator
        @file_service = file_service
        @connections = {}
        @connections_mutex = Mutex.new
        @refresh_mutex = Mutex.new
        @refresh_state = {}.compare_by_identity
        @degradation_mutex = Mutex.new
        @degradations = {}.compare_by_identity
      end

      # Reports which presentation facility properties this host can honour.
      #
      # Memoised: the host's contribution is fixed for the life of the
      # process, and this is read on every render. Two threads racing the
      # first call build two equal frozen hashes and one wins; harmless.
      #
      # @param _page [Page, nil] accepted for interface symmetry; support is per host, not per page
      # @return [Hash{Symbol => Boolean}] {PRESENTATION_SUPPORT} overlaid with what
      #   {WindowPresentation.support} reports
      def presentation_support(_page = nil)
        @presentation_support ||= begin
          host = WindowPresentation.support
          host.empty? ? PRESENTATION_SUPPORT : PRESENTATION_SUPPORT.merge(host).freeze
        end
      end

      # Lists the presentation properties the page asked for that the host refused at its last render.
      #
      # @param page [Page] the page whose degradations were recorded
      # @return [Array<Hash{Symbol => Symbol}>] frozen entries of `facility:`, `property:` and `reason:`;
      #   empty when nothing was refused or the page has not rendered
      def degradations(page)
        @degradation_mutex.synchronize { Array(@degradations[page]).map(&:dup).freeze }
      end

      # Empties a sensitive input in every browser attached to the page.
      #
      # A password's value is write-only by contract, so a script's
      # `entry.text = ""` has no property to push and the viewer kept seeing
      # the rejected text it had typed; this is the only channel by which
      # the field on screen can be made to match.
      #
      # @param page [Page] the page the input is on
      # @param cid [String, #to_s] the input's component id
      # @return [nil]
      def clear_sensitive(page, cid)
        @viewers.attachments_for(page).each do |attachment|
          connection = @connections_mutex.synchronize { @connections[attachment.connection_id] }
          next unless connection&.alive?

          connection.send_text(JSON.generate(type: 'clear_sensitive', cids: [cid.to_s]))
        end
        nil
      end

      # Refusal of a message whose generation is behind the delivered render.
      #
      # Raised by stale! once it has already sent both halves of its answer,
      # so handle does not send a second refusal on top.
      class StaleGeneration < Protocol::Refusal; end

      # Routes one parsed client message (attach, detach or event) and answers refusals on the wire.
      #
      # @param connection [Server::Connection] the browser connection the message arrived on
      # @param message [Hash{Symbol => Object}] a message from {Protocol.parse_client_message}
      # @return [Symbol, nil] `:attached`, `:detached` or `:queued` on success, `:refused` when a
      #   refusal was sent, nil for a type the runtime does not handle
      def handle(connection, message)
        case message[:type]
        when 'attach' then attach(connection, message)
        when 'detach' then detach(connection, message)
        when 'event' then event(connection, message)
        end
      rescue StaleGeneration => error
        log(:warning, "WebUI event refusal=#{error.reason}")
        :refused
      rescue Protocol::Refusal => error
        log(:warning, "WebUI event refusal=#{error.reason}")
        connection.send_text(
          Protocol.refusal(
            reason: error.reason, message: 'Message refused',
            page: message[:page], cid: message[:cid], event: message[:event], request: message[:request]
          )
        )
        :refused
      rescue Error => error
        log(:warning, "WebUI event refusal=#{error.class}")
        connection.send_text(
          Protocol.refusal(
            reason: :contract, message: 'Message refused',
            page: message[:page], cid: message[:cid], event: message[:event], request: message[:request]
          )
        )
        :refused
      end

      # Forgets a closed connection and fires `detach` for each attachment it held.
      #
      # The attachments themselves stay in the {ViewerStore} for the reconnect window, so a
      # browser that comes back with its resume token picks up where it was.
      #
      # @param connection [Server::Connection] the connection that closed
      # @return [Array<ViewerStore::Attachment>] the attachments the connection had
      def disconnect(connection)
        @connections_mutex.synchronize { @connections.delete(connection.viewer_id) }
        @viewers.transient_disconnect(connection.viewer_id).each do |attachment|
          enqueue_lifecycle(attachment, :detach)
        end
      end

      # Reads a component property on a page, resolving viewer-scoped values against a viewer.
      #
      # `:value` is mapped to the type's input property (`checked` for toggles and checkboxes,
      # `selected` for radios). Shared values come from the page's shared store, falling back
      # to the rendered props.
      #
      # @param page [Page] the page the component is on
      # @param cid [String, #to_s] the component's id
      # @param property [Symbol, String] the property name, or `:value` for the input value
      # @param viewer [String, #viewer_id, nil] the viewer whose value to read; defaults to the
      #   viewer of the callback currently running
      # @return [Object] the property's value
      # @raise [SensitiveReadError] when the property is write-only (a password's value)
      # @raise [AmbiguousViewerError] when a viewer-scoped read has no viewer to resolve against
      # @raise [UnknownPropertyError] when the component has no such property
      # @raise [Error] when the cid is not in the page's render
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

      # Validates and writes a component property on a page, then schedules a refresh.
      #
      # A table's `expanded:<row>` pseudo-property sets that row's expansion for the viewer.
      # Viewer-scoped properties go to the viewer's store; shared ones to the page's shared store.
      #
      # @param page [Page] the page the component is on
      # @param cid [String, #to_s] the component's id
      # @param property [Symbol, String] the property name, `:value`, or `expanded:<row>` on a table
      # @param value [Object] the new value; validated against the property's shape
      # @param viewer [String, #viewer_id, nil] the viewer for a viewer-scoped write; defaults to the
      #   viewer of the callback currently running
      # @return [nil]
      # @raise [SensitiveReadError] when the property is sensitive or ephemeral and cannot be set here
      # @raise [SchemaViolationError] when the value fails validation
      # @raise [AmbiguousViewerError] when a viewer-scoped write has no viewer to resolve against
      # @raise [UnknownPropertyError] when the component has no such property or row
      # @raise [Error] when the cid is not in the page's render
      def write(page, cid, property, value, viewer: nil)
        component = page_component(page, cid)
        return write_row_expansion(page, component, property, value, viewer) if row_expansion?(component, property)

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

      # Serialised per page. A refresh_loop thread and a direct refresh from
      # the script's commit could both run for the same page; renders are
      # ordered by Page#render's own lock, but delivery was not, so an older
      # render could go out after a newer one and the viewer kept the stale
      # tree.
      # The viewer ids of every live attachment to +page+, in attach order.
      #
      # @param page [Page] the page whose viewers to list
      # @return [Array<String>] the attachment viewer ids
      def viewer_ids(page)
        @viewers.attachments_for(page).map(&:viewer_id)
      end

      # Closes one viewer's attachment to +page+, telling that viewer why
      # with page_closed. The page itself stays registered and every other
      # viewer keeps its attachment; this is how an owner declines a viewer
      # it will not serve (a shim page refusing a second viewer, D26).
      # Returns false when the viewer was not attached.
      #
      # @param page [Page] the page to detach the viewer from
      # @param viewer_id [String] the attachment's viewer id (as in {#viewer_ids})
      # @param reason [Symbol] the `page_closed` reason sent to the viewer
      # @return [Boolean] true when an attachment was closed, false when the viewer was not attached
      def close_attachment(page, viewer_id, reason:)
        attachment = @viewers.attachment_for_viewer(page, viewer_id)
        connection = @connections_mutex.synchronize { @connections[attachment.connection_id] }
        connection&.send_text(Protocol.page_closed(address: attachment.address, reason: reason))
        @viewers.close(connection_id: attachment.connection_id, address: attachment.address)
        true
      rescue Error
        false
      end

      # Re-renders a page and delivers the new render to every live attachment.
      #
      # Runs under the page's refresh lock so deliveries cannot go out of generation order.
      #
      # @param page [Page] the page to re-render
      # @return [Integer] the generation of the render that was delivered
      # @raise [Error] when the render references an image source that is not served, or a popup
      #   page that is not registered
      def refresh(page)
        page_refresh_lock(page).synchronize do
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
      end

      # Returns the mutex that serialises renders and deliveries for one page, creating it on first use.
      #
      # @param page [Page] the page the lock belongs to
      # @return [Mutex] the page's refresh lock
      def page_refresh_lock(page)
        @refresh_mutex.synchronize { (@page_locks ||= {}.compare_by_identity)[page] ||= Mutex.new }
      end

      # Drops a page's refresh lock once the page is gone.
      #
      # A page's refresh lock outlives nothing: @refresh_state is already
      # dropped when a page goes quiet, but the lock was kept for the life of
      # the process, so every page a long session ever opened stayed reachable
      # through it. Released where the page's other per-page state is.
      #
      # @param page [Page] the page whose lock to release
      # @return [Mutex, nil] the removed lock, or nil when none existed
      def release_page_refresh_lock(page)
        @refresh_mutex.synchronize { @page_locks&.delete(page) }
      end

      # Tears down everything an owner holds: its callback queue, its pages, and their viewers.
      #
      # Every attached viewer is told `page_closed` with reason `:owner`.
      #
      # @param owner [Object] the owning script or object whose pages were registered
      # @return [Array<Page>] the pages that were closed
      def terminate_owner(owner)
        pages = @registry.pages_for(owner)
        @dispatcher.shutdown_owner(owner)
        pages.each do |page|
          @viewers.attachments_for(page).each do |attachment|
            connection = @connections_mutex.synchronize { @connections[attachment.connection_id] }
            connection&.send_text(Protocol.page_closed(address: attachment.address, reason: :owner))
          end
          @viewers.destroy_page(page)
        end
        @registry.unregister_owner(owner)
        @degradation_mutex.synchronize { pages.each { |page| @degradations.delete(page) } }
        pages.each { |page| release_page_refresh_lock(page) }
        pages
      end

      # Unregisters one page, closing every viewer's attachment to it.
      #
      # @param page [Page] the page to close
      # @param reason [Symbol] the `page_closed` reason sent to its viewers
      # @return [Page, nil] the page, or nil when it was not registered
      def close_page(page, reason: :owner)
        address = @registry.address_for(page)
        @viewers.attachments_for(page).each do |attachment|
          connection = @connections_mutex.synchronize { @connections[attachment.connection_id] }
          connection&.send_text(Protocol.page_closed(address: address, reason: reason))
        end
        @viewers.destroy_page(page)
        @registry.unregister(page.owner, page.id)
        @degradation_mutex.synchronize { @degradations.delete(page) }
        release_page_refresh_lock(page)
        page
      rescue Error
        nil
      end

      # How long shutdown waits for the refresh threads, all together. A
      # refresh thread blocked in a socket write to a browser that stopped
      # reading used to hold shutdown for as long as the write did; the
      # write is bounded now (Server::Connection::WRITE_TIMEOUT) and so is
      # this, in case anything else ever parks one.
      #
      # @return [Float] seconds {#shutdown} waits for all refresh threads together
      SHUTDOWN_BUDGET = 5.0

      # Stops the dispatcher and joins or kills every outstanding refresh thread within the budget.
      #
      # @param budget [Numeric] seconds to wait for the refresh threads, all together
      # @return [Array<Thread>] the refresh threads that were outstanding
      def shutdown(budget: SHUTDOWN_BUDGET)
        @dispatcher.shutdown
        threads = @refresh_mutex.synchronize { @refresh_state.values.filter_map { |state| state[:thread] } }
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + budget
        threads.each do |thread|
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          thread.join([remaining, 0].max)
          thread.kill if thread.alive?
        end
      end

      private

      # Attaches the connection to the addressed page and delivers its first render under the page lock.
      # @api private
      def attach(connection, message)
        @connections_mutex.synchronize { @connections[connection.viewer_id] = connection }
        page = fetch_page(message[:page])
        page.bind_runtime(self)
        # Under the same per-page lock as refresh. The attachment becomes
        # visible in ViewerStore before its first render has been delivered,
        # so a refresh running concurrently could deliver generation 2 and
        # then this thread would overwrite it with generation 1 -- stale
        # controls right after opening or reconnecting a page, and nothing
        # downstream rejects a generation that goes backwards.
        attachment = nil
        page_refresh_lock(page).synchronize do
          attachment = @viewers.attach(
            connection_id: connection.viewer_id, address: message[:page], page: page,
            resume_token: message[:resume]
          )
          render = validated_render(page)
          @viewers.deliver(attachment, render)
          send_render(connection, attachment)
        end
        enqueue_lifecycle(attachment, :attach)
        :attached
      end

      # Fires close (reason user) and detach for the attachment, then drops it.
      # @api private
      def detach(connection, message)
        attachment = fetch_attachment(connection, message[:page])
        stale!(connection, attachment, message) unless message[:generation] == attachment.delivered_generation
        # Both contexts are built before either callback can run. The close
        # callback may resolve a modal, whose completion closes the page and
        # clears this attachment's render; a detach context built after that
        # read the render of nothing and the detach callback was lost
        # (review 2026-09-17 (b), F3).
        jobs = [lifecycle_job(attachment, :close, reason: :user), lifecycle_job(attachment, :detach)]
        jobs.each { |job| job&.call }
        @viewers.close(connection_id: connection.viewer_id, address: message[:page])
        :detached
      end

      # Validates a component event, snapshots its submission, and enqueues the bound callback.
      # @api private
      def event(connection, message)
        attachment = fetch_attachment(connection, message[:page])
        stale!(connection, attachment, message) unless message[:generation] == attachment.delivered_generation
        component = find_component!(attachment, message[:cid])
        payload = @validator.validate_event!(
          component.type, message[:event], message[:payload] || {}, props: component.props,
          owner: owner_label(attachment.page.owner), page_id: attachment.page.id, cid: component.cid
        )
        # A page root has no per-cid binding channel: its bindings are routed
        # to page.lifecycle_bindings, never to render.bindings. A key event
        # aimed at the window (2.14) therefore resolves there, and rides the
        # same non-coalescable lifecycle dispatch as attach/detach/close so
        # distinct keys pressed in quick succession are never folded into one.
        event_key = message[:event].to_sym
        callback = attachment.render.bindings[[component.cid, event_key]]
        unless callback
          if page_input_event?(component, event_key) && attachment.page.lifecycle_bindings[event_key]
            enqueue_lifecycle(attachment, event_key, payload)
            return :queued
          end
          raise Protocol::Refusal.new(:unbound, 'component event has no server binding')
        end

        snapshot = build_submission(attachment, component, message)
        @viewers.update(attachment, component, message[:event].to_sym, payload)
        event_schema = Contract.schema(component.type)[:events].fetch(message[:event].to_sym)
        context = EventContext.new(
          attachment.viewer_id, attachment.page, component, message[:event].to_sym, payload, snapshot
        )
        @dispatcher.enqueue(
          owner: attachment.page.owner, page_id: attachment.page.id,
          viewer_id: attachment.viewer_id, cid: component.cid, event: context.event,
          coalescable: !event_schema[:terminal] && !event_schema[:lifecycle]
        ) do
          callback.call(context)
        ensure
          snapshot&.discard_sensitive!
        end
        # The overlay update and the refresh decision read one table
        # (ViewerStore::VIEWER_STATE_EVENTS), so neither can be forgotten.
        schedule_refresh(attachment.page) if ViewerStore.refresh_after?(component.type, context.event)
        # 2.18 (D17): a submission no longer empties the field it was taken
        # from. The carrier above is consumed once and zeroed, but what the
        # viewer typed stays on screen until the script says otherwise
        # through clear_sensitive -- so a wrong password re-prompts with the
        # text still there instead of an empty field.
        :queued
      rescue Dispatcher::TerminatedError
        # The owner is gone and its pages are being closed; the viewer will
        # hear page_closed. Nothing to enqueue, nothing to keep.
        snapshot&.discard_sensitive!
        raise Protocol::Refusal.new(:viewer_gone, 'page owner has shut down')
      rescue Dispatcher::OverflowError
        # The block's own `ensure` discards the snapshot's sensitive carriers
        # -- but only once the block runs. An enqueue that overflows raises
        # before it ever stores the block, so a typed password was left
        # un-zeroed on the heap until the GC found it.
        snapshot&.discard_sensitive!
        @viewers.close(connection_id: connection.viewer_id, address: message[:page])
        connection.close
        raise Protocol::Refusal.new(:overflow, 'viewer event queue overflow')
      end

      # Validates the submitted values in the terminal component's scope and wraps them as a Submission.
      # @api private
      def build_submission(attachment, terminal, message)
        scope = attachment.render.submissions.fetch(terminal.cid, [])
        raw_values = message.fetch(:submission, [])
        unless raw_values.length == scope.length
          raise Protocol::Refusal.new(:submission_scope, 'submission value count does not match server scope')
        end

        components = scope.map { |cid| find_component!(attachment, cid) }
        validated = components.each_with_index.map do |component, index|
          value = @validator.validate_input_value!(
            component.type, raw_values[index], props: component.props,
            owner: owner_label(attachment.page.owner), page_id: attachment.page.id, cid: component.cid
          )
          [component, value]
        end
        values = validated.to_h do |component, value|
          if sensitive?(component)
            [component.cid, SensitiveValue.viewer(value)]
          else
            @viewers.set_input(attachment, component, value)
            [component.cid, value]
          end
        end
        Submission.new(viewer_id: attachment.viewer_id, values: values)
      ensure
        scrub_sensitive_raw!(components, raw_values) if defined?(components) && components
      end

      # Zeroes the raw strings of sensitive submissions once they have been copied out.
      # @api private
      def scrub_sensitive_raw!(components, raw_values)
        components.each_with_index do |component, index|
          next unless sensitive?(component)
          next unless raw_values[index].is_a?(String) && !raw_values[index].frozen?

          raw_values[index].replace("\0" * raw_values[index].bytesize)
          raw_values[index].clear
        end
      end

      # A stale event is answered in two parts, in this order: the refusal,
      # naming the event, and then the render that superseded it. The client
      # keeps a record per event it sent; the refusal tells it which record
      # to replay and the render is the state to replay against. It used to
      # be the other way round, and a render makes the client forget every
      # record for its page -- so the record was gone before the refusal
      # that would have replayed it arrived, and a click landing during a
      # refresh was lost with a generic warning instead of recovered.
      # @api private
      def stale!(connection, attachment, message)
        connection.send_text(
          Protocol.refusal(
            reason: :stale_generation, message: 'Message refused',
            page: message[:page], cid: message[:cid], event: message[:event], request: message[:request]
          )
        )
        send_render(connection, attachment)
        raise StaleGeneration.new(:stale_generation, 'stale generation')
      end

      # Sends the attachment's delivered render, with its bindings and submission scopes, to the connection.
      # @api private
      def send_render(connection, attachment)
        bindings = attachment.render.bindings.keys.group_by(&:first).transform_values do |pairs|
          pairs.map(&:last).map(&:to_s)
        end
        connection.send_text(
          Protocol.render(
            address: attachment.address, generation: attachment.delivered_generation,
            tree: serialize_for_client(attachment), facilities: attachment.render.facilities,
            bindings: bindings, submissions: attachment.render.submissions,
            resume: attachment.resume_token
          )
        )
      end

      # The component with that cid in the attachment's delivered render, or a component_id refusal.
      # @api private
      def find_component!(attachment, cid)
        component = attachment.render.tree.each.find { |candidate| candidate.cid == cid }
        return component if component

        raise Protocol::Refusal.new(:component_id, 'component is not registered for delivered page')
      end

      # The viewer's serialised tree, with composite popup page ids rewritten to server addresses.
      # @api private
      def serialize_for_client(attachment)
        tree = @viewers.serialize(attachment)
        rewrite_popup_addresses(tree, attachment.page.owner)
      end

      def rewrite_popup_addresses(component, owner)
        if component[:type] == 'composite' && component.dig(:props, :popup)
          popup = component[:props][:popup]
          target = @registry.fetch(owner, popup[:page])
          component[:props] = component[:props].merge(popup: popup.merge(page: @registry.address_for(target)))
        end
        component[:children].each { |child| rewrite_popup_addresses(child, owner) }
        component
      end

      # Whether a component's value must never leave the browser except through a submission.
      # @api private
      def sensitive?(component)
        component.type == :password_input || component.props[:sensitive] == true
      end

      # A lifecycle-flagged event a browser may originate on the page root
      # (2.14: key). attach/detach/close are lifecycle too but the server
      # raises them itself; a client-sent one that is lifecycle-flagged and
      # aimed at a page is an input event routed through lifecycle_bindings.
      # @api private
      def page_input_event?(component, event)
        return false unless component.type == :page

        schema = Contract.schema(:page)[:events][event]
        schema && schema[:lifecycle] && !schema[:terminal]
      end

      # A printable name for an owner, for error attribution and logs.
      # @api private
      def owner_label(owner)
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end

      # The component with that cid in the page's last (or a fresh) render.
      # @api private
      def page_component(page, cid)
        render = page.last_render || page.render
        component = render.tree.each.find { |candidate| candidate.cid == cid.to_s }
        return component if component

        raise Error.new('component is not registered', owner: owner_label(page.owner), page_id: page.id, cid: cid)
      end

      # Renders the page and refuses image sources that are neither inline nor served, and unregistered popups.
      # @api private
      def validated_render(page)
        render = page.render
        record_presentation_degradations(page, render)
        render.tree.each do |component|
          sources = case component.type
                    when :image then [component.props[:src]]
                    when :composite
                      component.props[:layers].filter_map do |layer|
                        [layer[:src], layer[:mask]] if layer[:kind] == 'image'
                      end.flatten.compact
                    else []
                    end
          sources.each do |source|
            # An empty src is an image with nothing to show yet -- a bare
            # Gtk::Image.new, a cleared one, or a file that produced no
            # source. It references nothing, so there is nothing to check;
            # refusing it took the whole page down for one blank widget.
            next if source.empty?
            next if inline_image_source?(source)
            next if @file_service&.resolve_url(source)

            raise Error.new(
              'image source is not a registered served file', owner: owner_label(page.owner),
              page_id: page.id, cid: component.cid, field: :src
            )
          end
          next unless component.type == :composite && component.props[:popup]

          @registry.fetch(page.owner, component.props[:popup][:page])
        end
        render
      end

      # A base64 data: image is self-contained -- it references no server
      # resource to register -- and the page's CSP already allows it
      # (img-src 'self' data:). The shim builds these from Cairo surfaces
      # that have no file: map's room marker, tag markers and note pins.
      # Matched strictly so nothing but an inline PNG/JPEG/GIF/WebP passes:
      # a base64 image media type, then a base64 body -- whole quads, then
      # at most one padded tail, so the length is always a multiple of four.
      # Anchored and linear: each quad is fixed-width, so there is nothing
      # for the engine to backtrack over.
      INLINE_IMAGE = %r{
        \Adata:image/(?:png|jpeg|gif|webp);base64,
        (?:[A-Za-z0-9+/]{4})*
        (?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?\z
      }x

      def inline_image_source?(source)
        source.is_a?(String) && INLINE_IMAGE.match?(source)
      end

      # Records which requested presentation properties the host cannot honour, for degradations.
      # @api private
      def record_presentation_degradations(page, render)
        requested = render.facilities[:presentation] || {}
        supported = presentation_support(page)
        refusals = requested.each_key.filter_map do |property|
          # A property this table has never heard of is not a refusal: a bare
          # fetch here would raise out of validated_render, which runs on both
          # attach and refresh, and take down every page carrying a
          # presentation facility on every platform.
          next if supported.fetch(property, true)

          {
            facility: :presentation, property: property,
            reason: :unsupported_by_browser_host,
          }.freeze
        end
        @degradation_mutex.synchronize { @degradations[page] = refusals.freeze }
      end

      # The registered page at a server address, or a page_gone refusal.
      # @api private
      def fetch_page(address)
        @registry.fetch_address(address)
      rescue Error
        raise Protocol::Refusal.new(:page_gone, 'page is no longer registered', page_id: address)
      end

      # The connection's attachment to the addressed page, or a page_gone / viewer_gone refusal.
      # @api private
      def fetch_attachment(connection, address)
        fetch_page(address)
        @viewers.fetch(connection_id: connection.viewer_id, address: address)
      rescue Protocol::Refusal
        raise
      rescue Error
        raise Protocol::Refusal.new(:viewer_gone, 'viewer is no longer attached', page_id: address)
      end

      # Enqueues the page's lifecycle callback for the event, if one is bound.
      # @api private
      def enqueue_lifecycle(attachment, event, payload = {})
        lifecycle_job(attachment, event, payload)&.call
      end

      # The enqueue of a lifecycle callback, with its context captured now
      # and the dispatch deferred to the call: a caller that queues two
      # callbacks captures both before running either.
      # @api private
      def lifecycle_job(attachment, event, payload = {})
        callback = attachment.page.lifecycle_bindings[event]
        render = attachment.render
        return unless callback && render

        component = render.tree
        context = EventContext.new(
          attachment.viewer_id, attachment.page, component, event, payload.freeze, nil
        )
        page = attachment.page
        viewer_id = attachment.viewer_id
        lambda do
          @dispatcher.enqueue(
            owner: page.owner, page_id: page.id, viewer_id: viewer_id,
            cid: component.cid, event: event, coalescable: false
          ) { callback.call(context) }
        end
      end

      # Maps `:value` to the type's input property name; other names pass through as symbols.
      # @api private
      def component_property(component, property)
        key = property.to_sym
        return key unless key == :value

        case component.type
        when :toggle, :checkbox then :checked
        when :radio then :selected
        else :value
        end
      end

      # A table row's expansion is the viewer's own, kept as the row_toggle
      # event keeps it ("expanded:<row>" in the viewer store), and a script
      # may set it too: TreeView#expand_row under the shim, or any page that
      # opens a branch for the viewer (review 2026-09-17 (b), F4). The name
      # is not a contract property, so it is checked here: a boolean, for a
      # row the table has.
      # @api private
      def row_expansion?(component, property)
        component.type == :table && property.to_s.start_with?('expanded:')
      end

      # Sets a table row's expansion for the viewer; the row must exist.
      # @api private
      def write_row_expansion(page, component, property, value, viewer)
        name = property.to_s
        row = name.delete_prefix('expanded:')
        unless Array(component.props[:rows]).any? { |candidate| candidate[:key].to_s == row }
          raise UnknownPropertyError.new(
            "no row #{row.inspect} to expand", owner: owner_label(page.owner), page_id: page.id,
            cid: component.cid, field: name
          )
        end

        attachment = contextual_attachment(page, component, viewer)
        @viewers.set_property(attachment, component, name, value ? true : false)
        schedule_refresh(page)
        nil
      end

      # The scope a property is held in, from the schema; KeyError for a name the type lacks.
      # @api private
      def property_scope(component, name)
        schema = Contract.schema(component.type)
        return :sensitive_write_only if name == :value && sensitive?(component)

        definition = schema.fetch(:properties)[name]
        return definition[:scope] if definition
        return schema[:value_scope] if name == :value && schema[:value]

        raise KeyError, name
      end

      # The attachment for an explicit viewer, or the viewer of the running callback.
      # @api private
      def contextual_attachment(page, component, viewer)
        viewer_id = viewer || @dispatcher.current_context&.viewer_id
        unless viewer_id
          raise AmbiguousViewerError.new(
            'viewer-local access requires callback context or an explicit viewer',
            owner: owner_label(page.owner), page_id: page.id, cid: component.cid
          )
        end

        @viewers.attachment_for_viewer(page, viewer_id.respond_to?(:viewer_id) ? viewer_id.viewer_id : viewer_id.to_s)
      end

      # Starts a refresh thread for the page, or marks the running one dirty so it goes round again.
      # @api private
      def schedule_refresh(page)
        @refresh_mutex.synchronize do
          state = (@refresh_state[page] ||= { dirty: false, thread: nil })
          if state[:thread]&.alive?
            state[:dirty] = true
            return
          end
          state[:thread] = Thread.new { refresh_loop(page, state) }
        end
      end

      # Refreshes the page until no write has marked it dirty during the last pass.
      # @api private
      def refresh_loop(page, state)
        loop do
          refresh(page)
          repeat = @refresh_mutex.synchronize do
            dirty = state[:dirty]
            state[:dirty] = false
            @refresh_state.delete(page) unless dirty
            dirty
          end
          break unless repeat
        end
      rescue StandardError => error
        log(:error, "WebUI refresh failed owner=#{owner_label(page.owner)} error=#{error.class}")
        @refresh_mutex.synchronize { @refresh_state.delete(page) }
      end

      # Hands a line to the logger; a logger that raises is ignored.
      # @api private
      def log(level, message)
        @logger.call(level, message)
      rescue StandardError
        nil
      end
    end
  end
end
