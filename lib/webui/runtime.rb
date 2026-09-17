# frozen_string_literal: true

require_relative 'dispatcher'
require_relative 'protocol'
require_relative 'submission'
require_relative 'viewer_store'

module Lich
  module WebUI
    # Server-routed page attachment, viewer state, submission, and callback runtime.
    class Runtime
      EventContext = Data.define(:viewer_id, :page, :component, :event, :payload, :submission)
      # What a browser page can do on its own. always_on_top and borderless
      # belong to the window manager, not the page, and a CSS fade cannot make
      # a window translucent -- what shows through is the browser's own
      # background. On a host that can reach the real window (native Windows,
      # through WindowPresentation) the first and third become true; the key
      # set never changes, only the values, because the degradation walk reads
      # every requested property out of this table.
      PRESENTATION_SUPPORT = {
        always_on_top: false, borderless: false, opacity: true, scrollbars: true,
      }.freeze

      def initialize(registry:, dispatcher: Dispatcher.new, viewers: ViewerStore.new,
                     validator: Validator.new, file_service: nil, logger: nil)
        @registry = registry
        @dispatcher = dispatcher
        @viewers = viewers
        @validator = validator
        @file_service = file_service
        @logger = logger || proc { |_level, _message| }
        @connections = {}
        @connections_mutex = Mutex.new
        @refresh_mutex = Mutex.new
        @refresh_state = {}.compare_by_identity
        @degradation_mutex = Mutex.new
        @degradations = {}.compare_by_identity
      end

      # Memoised: the host's contribution is fixed for the life of the
      # process, and this is read on every render. Two threads racing the
      # first call build two equal frozen hashes and one wins; harmless.
      def presentation_support(_page = nil)
        @presentation_support ||= begin
          host = WindowPresentation.support
          host.empty? ? PRESENTATION_SUPPORT : PRESENTATION_SUPPORT.merge(host).freeze
        end
      end

      def degradations(page)
        @degradation_mutex.synchronize { Array(@degradations[page]).map(&:dup).freeze }
      end

      # Empties a sensitive input in every browser attached to the page. A
      # password's value is write-only by contract, so a script's
      # `entry.text = ""` has no property to push and the viewer kept seeing
      # the rejected text it had typed; this is the only channel by which
      # the field on screen can be made to match.
      def clear_sensitive(page, cid)
        @viewers.attachments_for(page).each do |attachment|
          connection = @connections_mutex.synchronize { @connections[attachment.connection_id] }
          next unless connection&.alive?

          connection.send_text(JSON.generate(type: 'clear_sensitive', cids: [cid.to_s]))
        end
        nil
      end

      # Raised by stale! once it has already sent both halves of its answer,
      # so handle does not send a second refusal on top.
      class StaleGeneration < Protocol::Refusal; end

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

      def disconnect(connection)
        @connections_mutex.synchronize { @connections.delete(connection.viewer_id) }
        @viewers.transient_disconnect(connection.viewer_id).each do |attachment|
          enqueue_lifecycle(attachment, :detach)
        end
      end

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

      # Serialised per page. A refresh_loop thread and a direct refresh from
      # the script's commit could both run for the same page; renders are
      # ordered by Page#render's own lock, but delivery was not, so an older
      # render could go out after a newer one and the viewer kept the stale
      # tree.
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

      def page_refresh_lock(page)
        @refresh_mutex.synchronize { (@page_locks ||= {}.compare_by_identity)[page] ||= Mutex.new }
      end

      # A page's refresh lock outlives nothing: @refresh_state is already
      # dropped when a page goes quiet, but the lock was kept for the life of
      # the process, so every page a long session ever opened stayed reachable
      # through it. Released where the page's other per-page state is.
      def release_page_refresh_lock(page)
        @refresh_mutex.synchronize { @page_locks&.delete(page) }
      end

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
      SHUTDOWN_BUDGET = 5.0

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

      def detach(connection, message)
        attachment = fetch_attachment(connection, message[:page])
        stale!(connection, attachment, message) unless message[:generation] == attachment.delivered_generation
        enqueue_lifecycle(attachment, :close, reason: :user)
        enqueue_lifecycle(attachment, :detach)
        @viewers.close(connection_id: connection.viewer_id, address: message[:page])
        :detached
      end

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

      def find_component!(attachment, cid)
        component = attachment.render.tree.each.find { |candidate| candidate.cid == cid }
        return component if component

        raise Protocol::Refusal.new(:component_id, 'component is not registered for delivered page')
      end

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

      def sensitive?(component)
        component.type == :password_input || component.props[:sensitive] == true
      end

      # A lifecycle-flagged event a browser may originate on the page root
      # (2.14: key). attach/detach/close are lifecycle too but the server
      # raises them itself; a client-sent one that is lifecycle-flagged and
      # aimed at a page is an input event routed through lifecycle_bindings.
      def page_input_event?(component, event)
        return false unless component.type == :page

        schema = Contract.schema(:page)[:events][event]
        schema && schema[:lifecycle] && !schema[:terminal]
      end

      def owner_label(owner)
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end

      def page_component(page, cid)
        render = page.last_render || page.render
        component = render.tree.each.find { |candidate| candidate.cid == cid.to_s }
        return component if component

        raise Error.new('component is not registered', owner: owner_label(page.owner), page_id: page.id, cid: cid)
      end

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

      def fetch_page(address)
        @registry.fetch_address(address)
      rescue Error
        raise Protocol::Refusal.new(:page_gone, 'page is no longer registered', page_id: address)
      end

      def fetch_attachment(connection, address)
        fetch_page(address)
        @viewers.fetch(connection_id: connection.viewer_id, address: address)
      rescue Protocol::Refusal
        raise
      rescue Error
        raise Protocol::Refusal.new(:viewer_gone, 'viewer is no longer attached', page_id: address)
      end

      def enqueue_lifecycle(attachment, event, payload = {})
        callback = attachment.page.lifecycle_bindings[event]
        return unless callback

        component = attachment.render.tree
        context = EventContext.new(
          attachment.viewer_id, attachment.page, component, event, payload.freeze, nil
        )
        @dispatcher.enqueue(
          owner: attachment.page.owner, page_id: attachment.page.id,
          viewer_id: attachment.viewer_id, cid: component.cid, event: event, coalescable: false
        ) { callback.call(context) }
      end

      def component_property(component, property)
        key = property.to_sym
        return key unless key == :value

        case component.type
        when :toggle, :checkbox then :checked
        when :radio then :selected
        else :value
        end
      end

      def property_scope(component, name)
        schema = Contract.schema(component.type)
        return :sensitive_write_only if name == :value && sensitive?(component)

        definition = schema.fetch(:properties)[name]
        return definition[:scope] if definition
        return schema[:value_scope] if name == :value && schema[:value]

        raise KeyError, name
      end

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

      def log(level, message)
        @logger.call(level, message)
      rescue StandardError
        nil
      end
    end
  end
end
