# frozen_string_literal: true

require 'securerandom'
require_relative '../../../webui'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # A runtime event context wrapped with the sensitive values it carried, delegating everything else
        # to the wrapped context.
        #
        # An event context plus the plaintext taken from its submission scope
        # before the runtime discarded it. Everything else is the runtime's own
        # context, so a widget that does not care about submitted values reads
        # it exactly as before.
        class CarriedEvent
          # @return [Hash{String => Object}] plaintext by cid, taken from the submission scope
          attr_reader :submitted

          # Wraps a context with its carried values.
          #
          # @param context [Object] the runtime event context
          # @param submitted [Hash{String => Object}] plaintext by cid
          # @return [CarriedEvent] a new wrapper
          def initialize(context, submitted)
            @context = context
            @submitted = submitted
          end

          # Answers for whatever the wrapped context answers.
          #
          # @param name [Symbol] method name
          # @param include_private [Boolean] passed through
          # @return [Boolean]
          def respond_to_missing?(name, include_private = false)
            @context.respond_to?(name, include_private) || super
          end

          # Forwards to the wrapped context.
          #
          # @param name [Symbol] method name
          # @return [Object] the context's answer
          # @raise [NoMethodError] when the context does not answer it either
          def method_missing(name, ...)
            return @context.public_send(name, ...) if @context.respond_to?(name)

            super
          end
        end

        # The WebUI adapter the GTK shim renders through.
        #
        # Adapter with the two extensions the shim needs: an explicit commit,
        # and viewer-scoped properties written as shared state. The shim
        # widget is the single source of truth for a value; per-viewer
        # divergence is pushed to attached viewers by Session#viewer_write.
        class ShimAdapter < Lich::WebUI::Adapter
          # Creates the adapter with empty placement, presentation and submission tables.
          #
          # @return [ShimAdapter] a new adapter
          def initialize(...)
            super
            @placements = {}.compare_by_identity
            @presentation_sources = {}.compare_by_identity
            @submissions = {}.compare_by_identity
          end

          # Registers a page root's presentation reader.
          #
          # Registers the block that reports a page root's facilities
          # (presentation, geometry) as a Hash of facility name => value.
          # Keyed by the opaque handle, since that is the only identity the
          # adapter and the widget share.
          #
          # @param handle [Object] the page root's opaque node handle
          # @yieldreturn [Hash{Symbol => Object}, nil] facility name => value
          # @return [nil]
          def presentation_source(handle, &block)
            @mutex.synchronize { @presentation_sources[handle] = block }
            nil
          end

          # Marks a node's page dirty so a presentation change is rendered.
          #
          # Facilities live beside the tree rather than on a node, so a
          # presentation change alters no props and would otherwise never
          # mark the page dirty.
          #
          # @param handle [Object] any node handle on the page; an unknown handle is ignored
          # @return [nil]
          def refresh_facilities(handle)
            @mutex.synchronize do
              node = @nodes[handle]
              dirty!(root_for(node)) if node
            end
            nil
          end

          # Renders every dirty page now.
          #
          # @return [Array<Lich::WebUI::Page>] the pages refreshed
          def commit
            flush!
          end

          # The page a node belongs to.
          #
          # @param handle [Object] node handle
          # @return [Lich::WebUI::Page, nil] nil for an unknown handle or a node not yet on a page
          def page_for(handle)
            @mutex.synchronize { @nodes[handle]&.page }
          end

          # Applies several property changes to a node as one validated update.
          #
          # Applies several property changes as one validated update. A nil
          # value removes the property. Needed because the contract validates
          # properties against each other (a select's value must be one of
          # its options), so changing them one at a time can never pass.
          #
          # @param handle [Object] node handle
          # @param changes [Hash{Symbol, String => Object, nil}] property => new value, nil to remove
          # @return [nil]
          # @raise [Lich::WebUI::SchemaViolationError] when the merged props fail the contract, attributed to the handle
          def update(handle, changes)
            @mutex.synchronize do
              node = node!(handle)
              merged = node.props.dup
              changes.each { |name, value| value.nil? ? merged.delete(name.to_sym) : merged[name.to_sym] = value }
              node.props = @validator.validate_component!(
                node.type, merged, owner: owner_label, page_id: adapter_page_id, cid: handle_label(handle)
              )
              assign_child_slots!(node) if named_children?(node)
              dirty!(root_for(node))
            end
            nil
          rescue Lich::WebUI::SchemaViolationError => error
            raise attributed(error, handle)
          end

          # Records a child's placement in its parent's node.
          #
          # Child placement (grid span/row_span) travels beside the node; the
          # base adapter has no slot for it.
          #
          # @param handle [Object] node handle
          # @param placement [Hash, #to_h] placement keys such as `span` and `row_span`
          # @return [nil]
          def set_placement(handle, placement)
            @mutex.synchronize do
              node = node!(handle)
              @placements[handle] = placement.to_h.transform_keys(&:to_sym)
              dirty!(root_for(node))
            end
            nil
          end

          # Declares the inputs whose values a terminal's event must carry.
          #
          # The inputs whose values a terminal's event must carry. A password's
          # value is sensitive and write-only, so it never travels as a
          # property or an event payload -- the contract's only channel for it
          # is the submission scope, which names inputs by cid. The adapter
          # holds opaque handles and cids are minted by the tree builder, so
          # the scope is stored as handles here and resolved during the render
          # pass that knows both.
          #
          # @param handle [Object] the terminal's node handle
          # @param input_handles [Array<Object>, Object] handles of the inputs in scope
          # @return [nil]
          def set_submission(handle, input_handles)
            @mutex.synchronize do
              node = node!(handle)
              @submissions[handle] = Array(input_handles)
              dirty!(root_for(node))
            end
            nil
          end

          # Sets one property; a viewer-scoped property is written into the shared props (validated in place) rather
          # than through the base adapter, and an unknown node or a shared property falls through to it.
          #
          # @param handle [Object] node handle
          # @param property [Symbol, String] property name
          # @param value [Object] new value
          # @return [nil]
          # @raise [Lich::WebUI::SchemaViolationError] when the value fails the contract
          def set(handle, property, value)
            node = @mutex.synchronize { @nodes[handle] }
            return super unless node

            schema = Lich::WebUI::Contract.schema(node.type)
            name = property.to_sym
            definition = schema[:properties][name]
            definition ||= { scope: schema[:value_scope] } if name == :value && schema[:value]
            return super unless definition && definition[:scope] == :viewer

            @mutex.synchronize do
              node.props = @validator.validate_component!(
                node.type, node.props.merge(name => value), owner: owner_label,
                page_id: adapter_page_id, cid: handle_label(handle)
              )
              dirty!(root_for(node))
            end
            nil
          end

          private

          # The base adapter owns the traversal (D13); the shim supplies what
          # it carries beside each node through the three hooks it calls.

          # A window's presentation properties belong to the page, not to any
          # component, so they are declared once as the page root renders.
          # The runtime refuses what a browser host cannot do and records the
          # refusal, which is why these are declared even though a Chromium
          # --app window honors almost none of them today.
          #
          # Handles are opaque by design, so the adapter cannot walk back to
          # the widget; the window supplies its own presentation through
          # +presentation_source+, which Session sets when it renders.
          # @api private
          def declare_facilities(builder, node)
            return unless node.type == :page

            facilities = @presentation_sources[handle_for(node)]&.call
            return unless facilities

            facilities.each { |name, value| builder.facility(name, value) if value }
          end

          def child_placement(handle)
            @placements[handle] || {}
          end

          # Installs every declared submission scope now that each handle's
          # cid is known: a scope names cids, and a cid is only minted as its
          # component renders, so the terminal may be rendered before the
          # inputs it names. A scope naming an input that did not render --
          # a widget destroyed or detached since the declaration -- drops
          # that input rather than failing the whole page on a cid the
          # builder never saw.
          # @api private
          def render_completed(builder, drafts)
            @submissions.each do |handle, input_handles|
              terminal = drafts[handle]
              next unless terminal

              cids = input_handles.filter_map { |input| drafts[input]&.cid }
              next if cids.empty?

              builder.submissions[terminal.cid] = cids.freeze
            end
          end

          def destroy_node!(handle)
            @placements.delete(handle)
            @submissions.delete(handle)
            @submissions.each_value { |inputs| inputs.delete(handle) }
            # A presentation reader is a closure over its window, registered
            # by root handle and never dropped: every window ever opened
            # stayed reachable through it after destroy.
            @presentation_sources.delete(handle)
            super
          end
        end

        # The per-script session behind the shim; it stands in for the GTK main loop and main thread.
        #
        # One per owning script: the emulated GTK main thread, the adapter
        # that renders its widgets, the viewers looking at its pages, and the
        # browser windows it opened.
        #
        # Threading: every script signal handler, every Gtk.queue block, and
        # every timer callback runs on this session's single thread, in order.
        # That is the concurrency model GTK scripts were written against.
        # WebUI dispatcher callbacks only enqueue here and return.
        class Session
          # Thread-local key naming the session a thread belongs to.
          THREAD_KEY = :lich_webui_gtk_shim_session
          # Seconds a contract modal waits for an answer before it times out.
          MODAL_TIMEOUT = 3600
          # Browser window geometry used when a window asks for none.
          DEFAULT_WINDOW = { width: 640, height: 480 }.freeze

          # Owner of the shared session used by widgets created outside any script; it has no exit hook.
          NullOwner = Struct.new(:name) do
            def at_exit(&_block)
              false
            end
          end

          @sessions = {}.compare_by_identity
          @registry_mutex = Mutex.new
          @browser_open = nil

          class << self
            # Test seam: replace the browser launcher.
            #
            # @return [#call, nil] a launcher taking `(url, geometry:, on_start:)`, or nil for the default
            attr_accessor :browser_open

            # Default detach grace in seconds.
            #
            # How long a detached viewer has to come back before its window
            # counts as closed: the client dials back on a 250ms backoff
            # capped at 5s, so a live browser is back well inside it.
            DETACH_GRACE = 5.0
            # @return [Float] detach grace in seconds (test seam)
            attr_writer :detach_grace

            # Seconds a detached viewer has to come back before its window counts as closed.
            #
            # @return [Float]
            def detach_grace
              @detach_grace || DETACH_GRACE
            end

            # The session for the calling context.
            #
            # Session for the calling context: the one whose thread we are on,
            # else the one owned by the current script, else a shared session
            # for widgets created outside any script.
            #
            # @return [Session]
            def current
              Thread.current[THREAD_KEY] || self.for(current_script)
            end

            # The session owned by a script, created on first use; nil selects the shared session.
            #
            # @param owner [Object, nil] the owning script (anything with `name` and `at_exit`), or nil
            # @return [Session]
            def for(owner)
              @registry_mutex.synchronize do
                # The shared owner is memoised under the same lock that makes
                # the session lookup a safe check-then-act: memoised outside
                # it, two concurrent callers with no script could each build
                # their own NullOwner and register two "shared" sessions.
                owner ||= (@null_owner ||= NullOwner.new('gtk-shim'))
                @sessions[owner] ||= new(owner).tap { |session| session.send(:hook_owner_exit) }
              end
            end

            # Forgets the session owned by a script.
            #
            # @param owner [Object] the owning script
            # @return [Session, nil] the session forgotten, if any
            def release(owner)
              @registry_mutex.synchronize { @sessions.delete(owner) }
            end

            # Every registered session.
            #
            # @return [Array<Session>]
            def sessions
              @registry_mutex.synchronize { @sessions.values.dup }
            end

            # The running Lich script, when there is one.
            #
            # @return [Object, nil] `Script.current`, or nil outside Lich or on error
            def current_script
              return nil unless defined?(::Script) && ::Script.respond_to?(:current)

              ::Script.current
            rescue StandardError
              nil
            end

            # Starts the WebUI service if it is not running.
            #
            # Starts the WebUI service from a thread in the default group.
            #
            # A session thread belongs to its script's thread group, and Lich
            # kills that whole group when the script exits. Threads the server
            # creates inherit the group of whoever called +start+, so a server
            # started from a session thread would lose its accept loop with the
            # first script to use it and could never rebind its port.
            #
            # @param service [Lich::WebUI::Service] the service
            # @return [Lich::WebUI::Service] the service
            # @raise [Exception] whatever `service.start` raised on the starting thread
            def start_service(service)
              return service if service.server.running?
              return service.start if Thread.current.group.equal?(ThreadGroup::Default)

              gate = Queue.new
              result = Queue.new
              thread = Thread.new do
                gate.pop
                result << [:ok, service.start]
              rescue Exception => error # rubocop:disable Lint/RescueException
                result << [:error, error]
              end
              begin
                ThreadGroup::Default.add(thread)
              rescue ThreadError
                nil # an enclosed group keeps its threads; start anyway
              end
              gate << true
              status, value = result.pop
              raise value if status == :error

              value
            end
          end

          # @return [Object] the owning script, or a {NullOwner} for the shared session
          attr_reader :owner

          # Creates a session; its thread starts with the first job.
          #
          # @param owner [Object] the owning script
          # @param service [Lich::WebUI::Service, nil] the service to render through, defaulting to
          #   `Lich::WebUI.service`
          # @return [Session] a new session
          def initialize(owner, service: nil)
            @owner = owner
            @service = service
            @adapter = nil
            @queue = Queue.new
            @thread = nil
            @thread_mutex = Mutex.new
            @windows = []
            # page => { viewer_id => true }. A plain Hash: a default proc made
            # every read insert, so each page ever asked about stayed alive
            # here until close_window happened to delete it.
            @viewers = {}
            @detached = {} # page => { viewer_id => grace token }
            @browsers = {} # window => pid
            @window_handles = {} # window => OS window handle, once found
            @mutex = Mutex.new
            @pending_viewer_writes = []
            @reported_degradations = Set.new # [page, facility, property], each reported once (D16)
            @pending_answers = [] # Futures a Dialog or MessageDialog run is parked on (D15)
            @closed = false
          end

          # The WebUI service, resolved on first use.
          #
          # @return [Lich::WebUI::Service]
          def service
            @service ||= Lich::WebUI.service
          end

          # The adapter this session renders through, created on first use.
          #
          # @return [ShimAdapter]
          def adapter
            @adapter ||= ShimAdapter.new(owner: @owner, service: service)
          end

          # A name for the owner, for logs and the ledger.
          #
          # @return [String] the owner's name, else its class and object id
          def owner_label
            return @owner.name if @owner.respond_to?(:name) && @owner.name

            "#{@owner.class}:#{@owner.object_id}"
          end

          # ---- the emulated GTK thread ------------------------------------

          # Queues a job for the session thread, starting the thread if needed.
          #
          # Queues +block+ for the session thread. True when it was taken;
          # nil for a closed session, which takes no more work: timers and
          # lifecycle callbacks fire after shutdown, and ensure_thread would
          # start a fresh session thread just to run them -- a callback
          # executing with the session closed and every window already gone.
          #
          # @param job [#call, nil] the job; taken from the block when nil
          # @yield the job body, run on the session thread
          # @return [true, nil] true when queued, nil for a closed session
          # @raise [ArgumentError] when neither a job nor a block is given
          def enqueue(job = nil, &block)
            job ||= block
            raise ArgumentError, 'block required' unless job

            # The closed check, the push and the thread start are one step
            # under the lock shutdown takes to close: read `@closed` first
            # and push after, and a shutdown between the two queued a job
            # behind a :stop the thread had already drained past (review
            # 2026-09-17 (c), Major 1). Taken means the thread will run it
            # or refuse it; nothing else.
            @thread_mutex.synchronize do
              return nil if @closed

              @queue << job
              ensure_thread_locked
            end
            true
          end

          # A job that answers its caller through a queue.
          #
          # A synchronous job: the caller waits on +done+ for its answer,
          # so it must always get one. The session thread answers it by
          # running it; a session thread that ends with it still queued
          # answers it with a refusal (review 2026-09-17 (b), F1).
          class SyncJob
            # Creates a job.
            #
            # @param block [#call] the work
            # @param done [Queue] receives `[:ok, value]` or `[:error, exception]`
            # @return [SyncJob] a new job
            def initialize(block, done)
              @block = block
              @done = done
            end

            # Runs the work and answers with its value or its exception.
            #
            # @return [void]
            def call
              @done << [:ok, @block.call]
            rescue Exception => error # rubocop:disable Lint/RescueException
              @done << [:error, error]
            end

            # Answers with an error without running the work.
            #
            # @param error [Exception] the refusal
            # @return [void]
            def reject(error)
              @done << [:error, error]
            end
          end

          # Runs a block on the session thread and returns its value.
          #
          # Runs +block+ on the session thread and waits for it. Never call
          # from the session thread itself (that would deadlock); it is for
          # specs and for script threads that need a synchronous round trip.
          #
          # @yield the work, run on the session thread
          # @return [Object] the block's value
          # @raise [Lich::WebUI::Error] when the session has been shut down
          # @raise [Exception] whatever the block raised
          def sync(&block)
            return block.call if on_session_thread?

            done = Queue.new
            job = SyncJob.new(block, done)
            # The closed check and the enqueue used to be two steps, and a
            # shutdown between them queued a job nobody would ever run.
            raise Lich::WebUI::Error, 'session has been shut down' unless enqueue(job)

            status, value = done.pop
            raise value if status == :error

            value
          end

          # Whether the calling thread is this session's thread.
          #
          # @return [Boolean]
          def on_session_thread?
            Thread.current[THREAD_KEY].equal?(self)
          end

          # Runs one batch of queued jobs from a nested loop.
          #
          # Runs the queued jobs as one batch, then commits once. This is a
          # nested main loop: GTK's gtk_dialog_run blocks its caller on the
          # main thread while still servicing events, and Dialog#run does the
          # same by pumping this queue until its response arrives. Returns
          # false when nothing was waiting within +timeout+ seconds, so the
          # caller can re-check its own exit condition. A :stop is put back
          # for run_loop.
          #
          # @param timeout [Numeric] seconds to wait for a job
          # @return [Boolean] true when a batch ran, false on timeout or a pending :stop
          def pump(timeout = 0.05)
            job = @queue.pop(timeout: timeout)
            return false if job.nil?

            if job == :stop
              @queue << :stop
              return false
            end
            run_batch(job)
            true
          end

          # Asks for a render after the current batch.
          #
          # Asks for a render after the current batch (D3). A script thread
          # that pokes a widget used to enqueue a full commit per write, and
          # every job ended in another; twenty label writes re-rendered every
          # window forty times. The job here does nothing -- the batch it
          # joins commits once when it is drained.
          #
          # @return [true, nil] nil for a closed session
          def request_commit
            enqueue { nil }
          end

          # Upper bound on jobs per batch.
          #
          # How many jobs one batch may take before it commits. A flood of
          # events (a held key, a busy timer) still renders between batches
          # rather than starving the viewer until the queue is empty.
          BATCH_LIMIT = 64

          # Runs +first+ and every job already queued behind it, up to
          # BATCH_LIMIT, then commits once (D3). A :stop found mid-batch is
          # put back for run_loop to see after the commit.
          # @api private
          def run_batch(first)
            job = first
            count = 0
            loop do
              begin
                job.call
              rescue StandardError, ScriptError => error
                report(error)
              end
              count += 1
              break if count >= BATCH_LIMIT

              job = @queue.pop(timeout: 0)
              break if job.nil?

              if job == :stop
                @queue << :stop
                break
              end
            end
            # Inside the same boundary as the jobs. commit rescues only WebUI
            # errors; a NoMethodError inside a widget's materialize! or
            # node_props escaped the batch and ended the session thread,
            # taking every window with it and leaving a sync queued behind
            # the crash waiting for ever (review 2026-09-17 (b), F1).
            begin
              commit unless @closed
            rescue StandardError, ScriptError => error
              report(error)
            end
          end
          private :run_batch

          # ---- windows ------------------------------------------------------

          # Adds a window to the session's list, once.
          #
          # @param window [Window] the window
          # @return [void]
          def register_window(window)
            @mutex.synchronize { @windows << window unless @windows.include?(window) }
          end

          # Materializes a window, renders it, binds its lifecycle and opens a browser on its page.
          #
          # @param window [Window] the window
          # @return [Object, nil] the browser launcher's answer, or nil when the window has no page
          def show_window(window)
            register_window(window)
            window.materialize!(adapter)
            commit
            page = adapter.page_for(window.handle)
            return unless page

            bind_lifecycle(window, page)
            open_browser(page, window: window, geometry: window.browser_geometry)
          end

          # Forgets a window and destroys its adapter node.
          #
          # Closes the page. The browser window is not ours to kill (D1): it
          # is an app window of the user's ordinary browser, and the client
          # drops the page when it hears page_closed.
          #
          # @param window [Window] the window
          # @return [void]
          def close_window(window)
            handle = window.handle
            @mutex.synchronize do
              @windows.delete(window)
              @window_handles.delete(window)
              @browsers.delete(window)
            end
            return unless handle

            page = adapter.page_for(handle)
            @mutex.synchronize { @viewers.delete(page) } if page
            begin
              adapter.destroy(handle)
            rescue Lich::WebUI::Error => error
              log(:warning, "destroy failed: #{error.message}")
            end
          end

          # ---- rendering ---------------------------------------------------

          # Materializes every window, renders, applies queued viewer writes and reports refused presentation.
          #
          # @return [void]
          def commit
            windows = @mutex.synchronize { @windows.dup }
            windows.each { |window| window.materialize!(adapter) if window.handle }
            adapter.commit
            flush_viewer_writes
            report_degradations(windows)
          rescue Lich::WebUI::Error => error
            log(:error, "commit failed: #{error.message}")
          end

          # What the runtime refused of a window's presentation (keep_above
          # on a host that cannot reach the OS window, say) is recorded on
          # the page and shown to nobody. Each refusal is reported once per
          # window through the ledger (D16), so it lands in the per-script
          # summary beside every other gap. The render that records it is
          # the one adapter.commit just delivered, so this reads the current
          # answer, not a stale one.
          # @api private
          def report_degradations(windows)
            windows.each do |window|
              next unless window.handle

              page = adapter.page_for(window.handle)
              next unless page

              page.degradations.each do |refusal|
                key = [page, refusal[:facility], refusal[:property]]
                next unless @mutex.synchronize { @reported_degradations.add?(key) }

                Gtk.log_unsupported('Gtk::Window', "#{refusal[:facility]} #{refusal[:property]}", note: refusal[:reason].to_s)
              end
            end
          end
          private :report_degradations

          # Queues a viewer-scoped write for the next commit.
          #
          # Pushes a viewer-scoped value (entry text, checkbox state) to every
          # viewer currently attached to the widget's page, so the browser's
          # own copy of the control does not shadow the script's write.
          #
          # Queued, and applied by the commit that follows -- never at once.
          # A write is validated against the page's last render, and a script
          # that appends an option and selects it in one job pushed the
          # selection while that render still knew only the old options. The
          # write was refused, the structural render then carried both
          # options, and the viewer's retained copy still said the old one:
          # Ruby and the browser disagreeing about what was chosen. Applied
          # after the structure it depends on has rendered, it passes.
          #
          # @param window [Window, nil] the widget's window
          # @param widget [Widget] the widget
          # @param name [Symbol, String] property name
          # @param value [Object] the value
          # @return [nil]
          def viewer_write(window, widget, name, value)
            @mutex.synchronize { @pending_viewer_writes << [window, widget, name, value] }
            nil
          end

          # Applies every queued viewer write.
          #
          # @return [nil]
          def flush_viewer_writes
            writes = @mutex.synchronize do
              pending = @pending_viewer_writes
              @pending_viewer_writes = []
              pending
            end
            writes.each { |window, widget, name, value| apply_viewer_write(window, widget, name, value) }
            nil
          end

          # Empties a sensitive input on every viewer.
          #
          # A programmatic write to a password entry: there is no value to
          # push, so the viewer's field is emptied instead.
          #
          # @param window [Window, nil] the widget's window
          # @param widget [Widget] the sensitive input
          # @return [nil]
          def viewer_clear_sensitive(window, widget)
            return unless window&.handle

            page = adapter.page_for(window.handle)
            return unless page&.last_render

            component = page.last_render.tree.each.find { |candidate| candidate.props[:key] == widget.key }
            service.runtime.clear_sensitive(page, component.cid) if component
            nil
          end

          # Pushes a viewer-scoped value to every viewer attached to the widget's page; a refused value is reported
          # through the ledger and a lost viewer is forgotten.
          #
          # @param window [Window, nil] the widget's window
          # @param widget [Widget] the widget
          # @param name [Symbol, String] property name
          # @param value [Object] the value
          # @return [void]
          def apply_viewer_write(window, widget, name, value)
            return unless window&.handle

            page = adapter.page_for(window.handle)
            return unless page&.last_render

            component = page.last_render.tree.each.find { |candidate| candidate.props[:key] == widget.key }
            return unless component

            viewers_for(page).each do |viewer_id|
              page.set(component.cid, name, value, viewer: viewer_id)
            rescue Lich::WebUI::SchemaViolationError => error
              # A value the contract refuses is a bug in what the script
              # asked for, not evidence the viewer left. Forgetting it here
              # dropped a viewer whose attachment was still live, so every
              # later programmatic update silently missed that browser until
              # some event happened to register it again.
              Gtk.log_unsupported(widget.short_class_name, "viewer write of #{name}", note: error.message)
            rescue Lich::WebUI::Error
              forget_viewer(page, viewer_id)
            end
          end

          # Queue depth at which the dispatcher hop waits for room.
          #
          # The dispatcher's queue is bounded and coalesces, but this hop used
          # to move every event straight onto the session's own unbounded
          # queue, so a slow handler left the dispatcher free to drain into it
          # and its bound protected nothing: with the session thread blocked,
          # a thousand events were accepted and kept. The hop now waits for
          # room. The dispatcher thread parks until the session has drained
          # below the limit, its own queue fills behind it, and the runtime
          # refuses further events as an overflow -- the protection that was
          # promised, one hop later. A hop that gets no room within HOP_WAIT
          # drops its event and says so, rather than growing without bound.
          HOP_LIMIT = 256
          # Seconds the dispatcher hop waits for room before dropping an event.
          HOP_WAIT = 5.0

          def await_capacity
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + HOP_WAIT
            while @queue.size >= HOP_LIMIT
              return false if @closed || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

              sleep 0.005
            end
            true
          end
          private :await_capacity

          # Builds the callback the WebUI dispatcher calls for a window's events.
          #
          # Wraps a script-facing callback for the WebUI dispatcher: note the
          # viewer, hop onto the session thread, and return immediately.
          #
          # @param window [Window] the window the events belong to
          # @yieldparam context [Object, CarriedEvent] the event context, run on the session thread
          # @return [Proc] the dispatcher callback
          # @raise [ArgumentError] when no handler block is given
          def dispatch_proc(window, &handler)
            raise ArgumentError, 'handler block required' unless handler

            proc do |context|
              unless await_capacity
                log(:warning, "webui-gtk-shim: session queue full; dropped #{context.respond_to?(:event) ? context.event : 'event'}")
                next
              end
              page = adapter.page_for(window.handle) if window.handle
              note_viewer(page, context.viewer_id) if page && context.respond_to?(:viewer_id)
              # The runtime zeroes a sensitive carrier as soon as this proc
              # returns, and this proc only queues the work. Taking the
              # plaintext here, on the dispatcher's own thread, is the only
              # point at which it is still readable. It has to survive the hop
              # as an ordinary String because that is what a GTK script reads:
              # the login GUI does `pass_entry.text` from a *button's* handler,
              # and the master-password dialog reads three entries after a
              # blocking `run` -- reads that happen long after any carrier the
              # runtime owns has been discarded.
              carried = carried_values(context)
              delivered = carried ? CarriedEvent.new(context, carried) : context
              enqueue do
                # The scope belongs to the terminal, but the values belong to
                # the inputs: the login GUI's Connect button reads
                # `pass_entry.text`, and the master-password dialog reads three
                # entries from one response. So every input in the scope takes
                # its own value before the terminal's handler runs and reads
                # them back.
                window.distribute_submitted(carried) if carried && window.respond_to?(:distribute_submitted)
                handler.call(delivered)
              end
            end
          end

          # Takes the submission scope's values out of an event context.
          #
          # Plaintext for every sensitive input in the event's submission
          # scope, keyed by cid. Returns nil when there is nothing sensitive to
          # carry, which is the ordinary case.
          #
          # @param context [Object] the runtime event context
          # @return [Hash{String => Object}, nil] plaintext by cid, or nil when there is no submission
          def carried_values(context)
            return nil unless context.respond_to?(:submission)

            submission = context.submission
            return nil unless submission

            submission.cids.each_with_object({}) do |cid, carried|
              value = submission[cid]
              if value.is_a?(Lich::WebUI::SensitiveValue)
                value.consume { |plaintext| carried[cid] = plaintext.dup }
              else
                carried[cid] = value
              end
            end
          rescue Lich::WebUI::Error => error
            log(:warning, "sensitive submission unavailable: #{error.message}")
            nil
          end

          # ---- modals ------------------------------------------------------

          # Opens a contract modal for this owner.
          #
          # Opens a contract dialog and returns its Future. The caller awaits
          # it; that is the blocking Gtk::MessageDialog#run.
          #
          # @param title [String] modal title
          # @param buttons [Array] the buttons, in contract form
          # @param body [String, nil] body text
          # @param default_button [String, nil] id of the default button
          # @return [Lich::WebUI::Future] resolves with the answer
          def modal(title:, buttons:, body: nil, default_button: nil)
            id = "modal-#{SecureRandom.hex(6)}"
            future = service.modal(
              owner: @owner, id: id, title: title, body: body, buttons: buttons,
              no_viewer: 'wait', default_button: default_button, timeout: MODAL_TIMEOUT
            )
            # A connected viewer is not the same as a viewer that will show
            # this: every script window is opened scoped to its own page, so
            # a modal used to be raised on a page nobody was watching while
            # the script sat blocked on the answer. The client now attaches
            # to a sibling modal from the same owner, so a window of ours is
            # enough; with none, open one for the dialog itself.
            open_modal_window(id, future) unless windows_open?
            await_answer(future)
          end

          # Tracks a Future until it resolves so shutdown can cancel it.
          #
          # The one place a blocking answer is waited for (D15). A
          # MessageDialog's Future comes from the ModalCoordinator; a
          # Dialog#run makes its own. Both are tracked here until they
          # resolve, so shutdown cancels every parked run through the same
          # path -- the shutdown gap (F4) happened because only one of the
          # two waiters was released.
          #
          # @param future [Lich::WebUI::Future] the Future to track; a fresh one by default
          # @return [Lich::WebUI::Future] the same Future
          def await_answer(future = Lich::WebUI::Future.new)
            @mutex.synchronize { @pending_answers << future }
            future.then { @mutex.synchronize { @pending_answers.delete(future) } }
            future
          end

          # Number of blocking answers still awaited.
          #
          # @return [Integer]
          def pending_answers
            @mutex.synchronize { @pending_answers.length }
          end

          def cancel_pending_answers(reason)
            futures = @mutex.synchronize { @pending_answers.dup }
            futures.each { |future| future.cancel(reason: reason) }
            nil
          end
          private :cancel_pending_answers

          # Whether a browser window of this script's own is open.
          #
          # A window of this script's own is open, so a modal raised now
          # will be shown in it: the client attaches to a sibling modal from
          # the same owner even when the window is scoped to one page.
          #
          # @return [Boolean]
          def windows_open?
            return false if service.server.connection_count.zero?

            @mutex.synchronize { @browsers.any? }
          end

          # Opens a browser window on a modal's page.
          #
          # A modal with no window of the script's own to show in gets one.
          # It opens like every other shim window (D1): nothing watches its
          # process, so a modal whose window is closed unanswered waits for
          # its timeout or for the owner to terminate, exactly as a modal
          # raised in an existing window does.
          #
          # @param id [String] the modal id
          # @param _future [Lich::WebUI::Future] unused
          # @return [Object, nil] the browser launcher's answer, or nil when the page could not be opened
          def open_modal_window(id, _future)
            page = service.registry.fetch(@owner, id)
            open_browser(page, geometry: { width: 460, height: 240 })
          rescue Lich::WebUI::Error => error
            log(:warning, "modal window failed to open: #{error.message}")
          end

          # ---- teardown ----------------------------------------------------

          # Ends the session: cancels waiting answers, closes windows, stops the thread and summarises the ledger.
          #
          # @return [void]
          def shutdown
            @thread_mutex.synchronize do
              return if @closed

              @closed = true
            end
            windows = @mutex.synchronize { @windows.dup }
            # Session teardown is a cancellation, not just a cleanup. A run
            # parked on its Future is not waiting for the browser -- it is
            # waiting for an answer that is never coming now, and
            # close_window only removes adapter and browser state. Every
            # pending answer, Dialog or MessageDialog, is cancelled through
            # the one path (D15).
            cancel_pending_answers(:terminated)
            windows.each { |window| close_window(window) }
            begin
              service.terminate_owner(@owner)
            rescue StandardError => error
              log(:warning, "terminate_owner failed: #{error.class}")
            end
            @queue << :stop
            self.class.release(@owner)
            # What this script asked the shim for and did not get, in one line
            # at the end, so a season of previews leaves a record of the real
            # surface rather than a first-hit warning per API per process.
            summary = Gtk.unsupported_summary(owner_label)
            log(:warning, summary) if summary
            # Summarised, the entries have served: the next run of this
            # script is a new session and gets its first-hit notices again.
            Gtk.forget_unsupported(owner_label)
          end

          private

          def ensure_thread
            @thread_mutex.synchronize { ensure_thread_locked }
          end

          # Under @thread_mutex: starts the session thread unless one is
          # alive or the session is closed.
          # @api private
          def ensure_thread_locked
            return if @closed || @thread&.alive?

            session = self
            @thread = Thread.new do
              Thread.current[THREAD_KEY] = session
              Thread.current.name = "webui-gtk:#{owner_label}" if Thread.current.respond_to?(:name=)
              session.send(:run_loop)
            end
          end

          # The session thread's whole life. Nothing a job or a commit raises
          # ends it: a script's error is reported, as GTK's main loop reports
          # one raised in a callback, and the loop goes on. It ends at :stop,
          # and then answers every synchronous job still queued with a
          # refusal, so no caller is left waiting on a thread that is gone.
          # @api private
          def run_loop
            loop do
              job = @queue.pop
              break if job == :stop

              begin
                run_batch(job)
              rescue Exception => error # rubocop:disable Lint/RescueException
                report(error)
              end
            end
          ensure
            reject_queued_jobs
          end

          def reject_queued_jobs
            refusal = Lich::WebUI::Error.new('session has been shut down')
            loop do
              job = @queue.pop(timeout: 0)
              break if job.nil?
              job.reject(refusal) if job.respond_to?(:reject)
            end
          rescue StandardError
            nil
          end

          def hook_owner_exit
            return unless @owner.respond_to?(:at_exit)

            session = self
            @owner.at_exit { session.shutdown }
          rescue StandardError
            nil
          end

          def bind_lifecycle(window, page)
            handle = window.handle
            return if window.lifecycle_bound?

            adapter.bind(handle, :attach, proc { |context| admit_viewer(page, context.viewer_id) })
            adapter.bind(handle, :detach, proc { |context| viewer_detached(window, page, context.viewer_id) })
            adapter.bind(handle, :close, proc { |_context| enqueue { window.viewer_closed } })
            # 2.14: a window that connected key-press-event receives keys on the
            # page root. Bound here beside the other window signals because the
            # page has no per-cid binding channel; a handler connected after the
            # window was first shown is not picked up -- the same limitation the
            # other lifecycle bindings have.
            if window.key_wanted?
              adapter.bind(handle, :key, proc { |context| enqueue { window.receive_key(context) } })
            end
            window.lifecycle_bound!
            adapter.commit
          end

          # Opens the page the way lich-6 opens a script page (D1): an app
          # window in the user's ordinary browser, with no private profile
          # and no process monitor -- so no on_exit. A window the viewer
          # closes is noticed through the page's detach/close lifecycle,
          # which bind_lifecycle routes to Window#viewer_closed. on_start
          # still yields the launcher's pid, which is what the Windows
          # presentation lookup (keep_above, opacity) needs to find the
          # window; where the pid is not the window's, that lookup finds
          # nothing and the presentation degrades through the ledger.
          # @api private
          def open_browser(page, window: nil, geometry: nil)
            self.class.start_service(service)
            url = service.launch_url(page: page)
            unless Lich::WebUI.open_browser?
              announce_launch_url(page, url)
              return true
            end

            opener = self.class.browser_open || method(:default_browser_open)
            session = self
            opened = opener.call(
              url,
              geometry: geometry,
              on_start: proc { |pid| session.send(:remember_browser, window, pid) if window }
            )
            log(:warning, 'browser window failed to open; page is available at the launch URL') if opened == false
            opened
          end

          # Under --webui-no-browser a script window is a URL the player
          # opens where their browser is. It goes to the game window through
          # Messaging when a session has one, and always to the log.
          # @api private
          def announce_launch_url(page, url)
            title = page.respond_to?(:title) ? page.title : page.to_s
            message = "WebUI window #{title.inspect} is ready; open it at #{url}"
            log(:info, message)
            Lich::Messaging.msg('info', message) if defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:msg)
          rescue StandardError
            nil
          end

          def default_browser_open(url, geometry:, on_start:)
            Lich::WebUI::BrowserLauncher.open(url, geometry: geometry, on_start: on_start)
          end

          def remember_browser(window, pid)
            @mutex.synchronize { @browsers[window] = pid }
            watch_window_presentation(window, pid)
          end

          # A script's keep-above and opacity belong to the real OS window, not
          # to the page, so once the browser has one we find it and apply them.
          # The search runs on its own thread: it takes about a quarter of a
          # second, and the session thread is the one every script handler and
          # timer runs on.
          # @api private
          def watch_window_presentation(window, pid)
            return unless Lich::WebUI::WindowPresentation.available?

            session = self
            Lich::WebUI::WindowPresentation.discover(pid) do |hwnd|
              next unless hwnd

              session.enqueue { session.send(:adopt_window_handle, window, pid, hwnd) }
            end
          end

          def adopt_window_handle(window, pid, hwnd)
            # The window may have been closed while we were looking, and its
            # pid killed; applying to a stale or recycled handle would dress
            # up somebody else's window.
            return unless @mutex.synchronize { @browsers[window] } == pid

            @mutex.synchronize { @window_handles[window] = hwnd }
            apply_window_presentation(window)
          end

          # Applies a window's presentation (keep-above, opacity, borderless) to its OS window, once known.
          #
          # Applies the window's presentation, resolving what the facility
          # leaves unsaid. Window#presentation omits a property that is false
          # and returns nil once nothing is set, so a script turning keep-above
          # off never arrives as a value -- only as an absence. The defaults
          # here are what absence means, which is what makes a toggle revert.
          # Public: a Window calls this when its presentation changes, which
          # can happen long after the window opened (map's opacity menu).
          #
          # @param window [Window] the window
          # @return [void]
          public def apply_window_presentation(window)
            hwnd = @mutex.synchronize { @window_handles[window] }
            return unless hwnd

            requested = window.presentation || {}
            Lich::WebUI::WindowPresentation.apply(
              hwnd,
              always_on_top: requested[:always_on_top] ? true : false,
              opacity: requested[:opacity] || 1.0,
              borderless: requested[:borderless] ? true : false
            )
          end

          # A shim window is single-viewer (D26): ScrolledWindow keeps one
          # scroll extent per widget, written by whichever viewer reported
          # last, so two browsers on one page would overwrite each other.
          # The newcomer is the one refused -- the first viewer is the window
          # the script opened -- and it is told why with page_closed. A
          # viewer that has detached (or whose reconnect window has lapsed)
          # no longer counts, so reopening a closed window is admitted.
          #
          # Decided by attach order, not by who asked first: the attach
          # callbacks arrive through the dispatcher and two viewers' can run
          # in either order, so each one asks whether it is the earliest
          # live attachment rather than whether anyone else is there.
          # @api private
          def admit_viewer(page, viewer_id)
            return unless page && viewer_id

            @mutex.synchronize { @detached[page]&.delete(viewer_id.to_s) }
            live = service.runtime.viewer_ids(page)
            if live.empty? || live.first == viewer_id.to_s
              note_viewer(page, viewer_id)
            else
              service.runtime.close_attachment(page, viewer_id.to_s, reason: :refused)
              log(:warning, "webui-gtk-shim: refused a second viewer on #{page.id}; a shim window is single-viewer")
            end
          end

          def note_viewer(page, viewer_id)
            return unless page && viewer_id

            @mutex.synchronize { (@viewers[page] ||= {})[viewer_id.to_s] = true }
          end

          def forget_viewer(page, viewer_id)
            @mutex.synchronize { @viewers[page]&.delete(viewer_id.to_s) }
          end

          # A viewer's socket going away arrives as `detach`, which the
          # runtime also emits for a transient loss the client dials back
          # from. With no process of ours to watch (D1), closing the browser
          # window is only ever a detach -- and a script whose window was
          # closed used to run on, never told. The window counts as closed
          # when no viewer has come back within the grace (the client's
          # maximum reconnect backoff), the same rule the launcher applies.
          # @api private
          def viewer_detached(window, page, viewer_id)
            forget_viewer(page, viewer_id)
            token = Object.new
            @mutex.synchronize { (@detached[page] ||= {})[viewer_id.to_s] = token }
            grace = self.class.detach_grace
            Thread.new do
              sleep(grace)
              expired = @mutex.synchronize do
                @detached[page]&.[](viewer_id.to_s).equal?(token) && @detached[page].delete(viewer_id.to_s)
              end
              enqueue { window.viewer_closed } if expired && !@closed && viewers_for(page).empty?
            end
            nil
          end

          def viewers_for(page)
            @mutex.synchronize { @viewers.fetch(page, {}).keys }
          end

          def report(error)
            backtrace = Array(error.backtrace)
            message = "error in Gtk.queue: #{error.message}\n\t#{backtrace.first(8).join("\n\t")}"
            # The frame inside the script is the one worth showing: the shim's
            # own frames say where the error surfaced, not which line of the
            # script asked for it.
            #
            # Lich evals a script under its bare name, so its frames read
            # "map:2466", not ".../map.lic:2466". Matching only ".lic:" found
            # nothing and the location was silently dropped, which is how
            # "coerce must return [x, y]" went three rounds without ever
            # naming center_viewport_on.
            origin = script_origin(backtrace)
            detail = origin ? "#{error.message} at #{script_frame(origin)}" : error.message
            respond("error in Gtk.queue: #{detail}") if respond_to?(:respond, true)
            log(:error, message)
          end

          # The first frame belonging to the script rather than to the shim
          # or the Ruby core. Prefers the running script's own name, which is
          # how Lich labels evaled frames, and still accepts a real ".lic"
          # path for a script loaded from disk.
          # @api private
          def script_origin(backtrace)
            name = owner_label.to_s
            unless name.empty?
              named = backtrace.find { |frame| frame.match?(/(\A|[\\\/])#{Regexp.escape(name)}(\.lic)?:\d+/) }
              return named if named
            end
            backtrace.find { |frame| frame.include?('.lic:') }
          end

          # ".../scripts/map.lic:2462:in 'block'" -> "map.lic:2462".
          # @api private
          def script_frame(frame)
            file, line, = frame.split(':in ').first.to_s.rpartition(':').values_at(0, 2)
            base = file.to_s.split(%r{[\\/]}).last
            base && line ? "#{base}:#{line}" : frame
          end

          def log(level, message)
            Lich.log("#{level}: webui-gtk-shim(#{owner_label}): #{message}") if defined?(Lich) && Lich.respond_to?(:log)
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
