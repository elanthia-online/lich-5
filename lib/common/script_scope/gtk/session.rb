# frozen_string_literal: true

require 'securerandom'
require_relative '../../../webui'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # An event context plus the plaintext taken from its submission scope
        # before the runtime discarded it. Everything else is the runtime's own
        # context, so a widget that does not care about submitted values reads
        # it exactly as before.
        class CarriedEvent
          attr_reader :submitted

          def initialize(context, submitted)
            @context = context
            @submitted = submitted
          end

          def respond_to_missing?(name, include_private = false)
            @context.respond_to?(name, include_private) || super
          end

          def method_missing(name, ...)
            return @context.public_send(name, ...) if @context.respond_to?(name)

            super
          end
        end

        # Adapter with the two extensions the shim needs: an explicit commit,
        # and viewer-scoped properties written as shared state. The shim
        # widget is the single source of truth for a value; per-viewer
        # divergence is pushed to attached viewers by Session#viewer_write.
        class ShimAdapter < Lich::WebUI::Adapter
          def initialize(...)
            super
            @placements = {}.compare_by_identity
            @presentation_sources = {}.compare_by_identity
            @submissions = {}.compare_by_identity
          end

          # Registers the block that reports a page root's presentation
          # facility. Keyed by the opaque handle, since that is the only
          # identity the adapter and the widget share.
          def presentation_source(handle, &block)
            @mutex.synchronize { @presentation_sources[handle] = block }
            nil
          end

          # Facilities live beside the tree rather than on a node, so a
          # presentation change alters no props and would otherwise never
          # mark the page dirty.
          def refresh_facilities(handle)
            @mutex.synchronize do
              node = @nodes[handle]
              dirty!(root_for(node)) if node
            end
            nil
          end

          def commit
            flush!
          end

          def page_for(handle)
            @mutex.synchronize { @nodes[handle]&.page }
          end

          # Applies several property changes as one validated update. A nil
          # value removes the property. Needed because the contract validates
          # properties against each other (a select's value must be one of
          # its options), so changing them one at a time can never pass.
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

          # Child placement (grid span/row_span) travels beside the node; the
          # base adapter has no slot for it.
          def set_placement(handle, placement)
            @mutex.synchronize do
              node = node!(handle)
              @placements[handle] = placement.to_h.transform_keys(&:to_sym)
              dirty!(root_for(node))
            end
            nil
          end

          # The inputs whose values a terminal's event must carry. A password's
          # value is sensitive and write-only, so it never travels as a
          # property or an event payload -- the contract's only channel for it
          # is the submission scope, which names inputs by cid. The adapter
          # holds opaque handles and cids are minted by the tree builder, so
          # the scope is stored as handles here and resolved during the render
          # pass that knows both.
          def set_submission(handle, input_handles)
            @mutex.synchronize do
              node = node!(handle)
              @submissions[handle] = Array(input_handles)
              dirty!(root_for(node))
            end
            nil
          end

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

          # A window's presentation properties belong to the page, not to any
          # component, so they are declared once as the page root renders.
          # The runtime refuses what a browser host cannot do and records the
          # refusal, which is why these are declared even though a Chromium
          # --app window honors almost none of them today.
          #
          # Handles are opaque by design, so the adapter cannot walk back to
          # the widget; the window supplies its own presentation through
          # +presentation_source+, which Session sets when it renders.
          def declare_presentation(builder, node)
            return unless node.type == :page

            handle = @mutex.synchronize { handle_for(node) }
            presentation = @presentation_sources&.[](handle)&.call
            builder.facility(:presentation, presentation) if presentation
          end

          def render_children(builder, node)
            declare_presentation(builder, node)
            # A submission scope names cids, and a cid is only known once the
            # tree builder has minted it. Collect handle => draft across the
            # whole pass, then install the scopes: the terminal may be
            # rendered before the inputs it names, and validate_submissions!
            # runs at build, after every draft exists.
            drafts = {}.compare_by_identity
            render_child_components(builder, node, drafts)
            install_submissions!(builder, drafts)
          end

          def render_child_components(builder, node, drafts)
            @mutex.synchronize { render_child_components!(builder, node, drafts) }
          end

          # Caller holds @mutex: the recursion must not retake it, because a
          # Ruby Mutex is not reentrant and every level of the tree passes
          # through here.
          def render_child_components!(builder, node, drafts)
            adapter = self
            node.children.each do |child_handle|
              child = @nodes.fetch(child_handle)
              props = effective_props(child, child_handle)
              bindings = child.bindings.to_h do |event, binding_id|
                [event, @bindings.fetch(binding_id).last]
              end
              placement = @placements[child_handle] || {}
              drafts[child_handle] =
                builder.component(child.type, slot: child.slot, on: bindings, placement: placement, **props) do
                  adapter.send(:render_child_components!, self, child, drafts)
                end
            end
          end

          # Installs every declared scope now that each handle's cid is known.
          # A scope naming an input that did not render -- a widget destroyed
          # or detached since the declaration -- drops that input rather than
          # failing the whole page on a cid the builder never saw.
          def install_submissions!(builder, drafts)
            scopes = @mutex.synchronize { @submissions.to_a }
            scopes.each do |handle, input_handles|
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

        # One per owning script: the emulated GTK main thread, the adapter
        # that renders its widgets, the viewers looking at its pages, and the
        # browser windows it opened.
        #
        # Threading: every script signal handler, every Gtk.queue block, and
        # every timer callback runs on this session's single thread, in order.
        # That is the concurrency model GTK scripts were written against.
        # WebUI dispatcher callbacks only enqueue here and return.
        class Session
          THREAD_KEY = :lich_webui_gtk_shim_session
          MODAL_TIMEOUT = 3600
          DEFAULT_WINDOW = { width: 640, height: 480 }.freeze

          NullOwner = Struct.new(:name) do
            def at_exit(&_block)
              false
            end
          end

          @sessions = {}.compare_by_identity
          @registry_mutex = Mutex.new
          @browser_open = nil
          @browser_kill = nil

          class << self
            # Test seams: replace the browser process launcher/killer.
            attr_accessor :browser_open, :browser_kill

            # Session for the calling context: the one whose thread we are on,
            # else the one owned by the current script, else a shared session
            # for widgets created outside any script.
            def current
              Thread.current[THREAD_KEY] || self.for(current_script)
            end

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

            def release(owner)
              @registry_mutex.synchronize { @sessions.delete(owner) }
            end

            def sessions
              @registry_mutex.synchronize { @sessions.values.dup }
            end

            def current_script
              return nil unless defined?(::Script) && ::Script.respond_to?(:current)

              ::Script.current
            rescue StandardError
              nil
            end

            # Starts the WebUI service from a thread in the default group.
            #
            # A session thread belongs to its script's thread group, and Lich
            # kills that whole group when the script exits. Threads the server
            # creates inherit the group of whoever called +start+, so a server
            # started from a session thread would lose its accept loop with the
            # first script to use it and could never rebind its port.
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

          attr_reader :owner

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
            @browsers = {} # window => pid
            @window_handles = {} # window => OS window handle, once found
            @mutex = Mutex.new
            @pending_viewer_writes = []
            @closed = false
          end

          def service
            @service ||= Lich::WebUI.service
          end

          def adapter
            @adapter ||= ShimAdapter.new(owner: @owner, service: service)
          end

          def owner_label
            return @owner.name if @owner.respond_to?(:name) && @owner.name

            "#{@owner.class}:#{@owner.object_id}"
          end

          # ---- the emulated GTK thread ------------------------------------

          def enqueue(&block)
            raise ArgumentError, 'block required' unless block
            # A closed session takes no more work. Timers and browser-exit
            # callbacks fire after shutdown, and ensure_thread would start a
            # fresh session thread just to run them -- a callback executing
            # with the session closed and every window already gone.
            return nil if @closed

            @queue << block
            ensure_thread
            nil
          end

          # Runs +block+ on the session thread and waits for it. Never call
          # from the session thread itself (that would deadlock); it is for
          # specs and for script threads that need a synchronous round trip.
          def sync(&block)
            return block.call if on_session_thread?
            raise Lich::WebUI::Error, 'session has been shut down' if @closed

            done = Queue.new
            enqueue do
              done << [:ok, block.call]
            rescue Exception => error # rubocop:disable Lint/RescueException
              done << [:error, error]
            end
            status, value = done.pop
            raise value if status == :error

            value
          end

          def on_session_thread?
            Thread.current[THREAD_KEY].equal?(self)
          end

          # Runs at most one queued job, then commits. This is a nested main
          # loop: GTK's gtk_dialog_run blocks its caller on the main thread
          # while still servicing events, and Dialog#run does the same by
          # pumping this queue until its response arrives. Returns false when
          # nothing was waiting within +timeout+ seconds, so the caller can
          # re-check its own exit condition. A :stop is put back for run_loop.
          def pump(timeout = 0.05)
            job = @queue.pop(timeout: timeout)
            return false if job.nil?

            if job == :stop
              @queue << :stop
              return false
            end
            begin
              job.call
              commit unless @closed
            rescue StandardError, ScriptError => error
              report(error)
            end
            true
          end

          # ---- windows ------------------------------------------------------

          def register_window(window)
            @mutex.synchronize { @windows << window unless @windows.include?(window) }
          end

          def show_window(window)
            register_window(window)
            window.materialize!(adapter)
            commit
            page = adapter.page_for(window.handle)
            return unless page

            bind_lifecycle(window, page)
            open_browser(page, window: window, geometry: window.browser_geometry)
          end

          def close_window(window)
            handle = window.handle
            pid = @mutex.synchronize do
              @windows.delete(window)
              @window_handles.delete(window)
              @browsers.delete(window)
            end
            if handle
              page = adapter.page_for(handle)
              @mutex.synchronize { @viewers.delete(page) } if page
              begin
                adapter.destroy(handle)
              rescue Lich::WebUI::Error => error
                log(:warning, "destroy failed: #{error.message}")
              end
            end
            kill_browser(pid) if pid
          end

          # ---- rendering ---------------------------------------------------

          def commit
            windows = @mutex.synchronize { @windows.dup }
            windows.each { |window| window.materialize!(adapter) if window.handle }
            adapter.commit
            flush_viewer_writes
          rescue Lich::WebUI::Error => error
            log(:error, "commit failed: #{error.message}")
          end

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
          def viewer_write(window, widget, name, value)
            @mutex.synchronize { @pending_viewer_writes << [window, widget, name, value] }
            nil
          end

          def flush_viewer_writes
            writes = @mutex.synchronize do
              pending = @pending_viewer_writes
              @pending_viewer_writes = []
              pending
            end
            writes.each { |window, widget, name, value| apply_viewer_write(window, widget, name, value) }
            nil
          end

          # A programmatic write to a password entry: there is no value to
          # push, so the viewer's field is emptied instead.
          def viewer_clear_sensitive(window, widget)
            return unless window&.handle

            page = adapter.page_for(window.handle)
            return unless page&.last_render

            component = page.last_render.tree.each.find { |candidate| candidate.props[:key] == widget.key }
            service.runtime.clear_sensitive(page, component.cid) if component
            nil
          end

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

          # Wraps a script-facing callback for the WebUI dispatcher: note the
          # viewer, hop onto the session thread, and return immediately.
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
                # Tested on the class: a shim widget answers respond_to? for
                # every name so it can swallow unimplemented GTK API.
                window.distribute_submitted(carried) if carried && window.class.method_defined?(:distribute_submitted)
                handler.call(delivered)
              end
            end
          end

          # Plaintext for every sensitive input in the event's submission
          # scope, keyed by cid. Returns nil when there is nothing sensitive to
          # carry, which is the ordinary case.
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

          # Opens a contract dialog and returns its Future. The caller awaits
          # it on the session thread; that is the blocking Gtk::Dialog#run.
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
            future
          end

          # A window of this script's own is open, so a modal raised now
          # will be shown in it: the client attaches to a sibling modal from
          # the same owner even when the window is scoped to one page.
          def windows_open?
            return false if service.server.connection_count.zero?

            @mutex.synchronize { @browsers.any? }
          end

          def open_modal_window(id, future)
            page = service.registry.fetch(@owner, id)
            open_browser(page, geometry: { width: 460, height: 240 }) { future.cancel(reason: :closed) }
          rescue Lich::WebUI::Error => error
            log(:warning, "modal window failed to open: #{error.message}")
          end

          # ---- teardown ----------------------------------------------------

          def shutdown
            return if @closed

            @closed = true
            windows = @mutex.synchronize { @windows.dup }
            # Session teardown is a cancellation, not just a cleanup. A
            # Dialog#run parked on its queue is not waiting for the browser --
            # it is waiting for an answer that is never coming now, and
            # close_window only removes adapter and browser state. Without
            # this an off-thread run stayed blocked for the life of the
            # process and the dialog never reported itself destroyed.
            windows.each do |window|
              window.session_terminated if window.respond_to?(:session_terminated)
            end
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
            @thread_mutex.synchronize do
              return if @closed || @thread&.alive?

              session = self
              @thread = Thread.new do
                Thread.current[THREAD_KEY] = session
                Thread.current.name = "webui-gtk:#{owner_label}" if Thread.current.respond_to?(:name=)
                session.send(:run_loop)
              end
            end
          end

          def run_loop
            loop do
              job = @queue.pop
              break if job == :stop

              begin
                job.call
                commit unless @closed
              rescue StandardError, ScriptError => error
                # commit rescues only WebUI errors; a NoMethodError inside a
                # widget's node_props used to escape here and end the
                # session thread, taking every window with it.
                report(error)
              end
            end
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

            adapter.bind(handle, :attach, proc { |context| note_viewer(page, context.viewer_id) })
            adapter.bind(handle, :detach, proc { |context| forget_viewer(page, context.viewer_id) })
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

          def open_browser(page, window: nil, geometry: nil, &on_exit)
            self.class.start_service(service)
            url = service.launch_url(page: page)
            opener = self.class.browser_open || method(:default_browser_open)
            session = self
            opened = opener.call(
              url,
              geometry: geometry,
              on_start: proc { |pid| session.send(:remember_browser, window, pid) if window },
              on_exit: on_exit || proc { enqueue { window.browser_exited } if window }
            )
            log(:warning, 'browser window failed to open; page is available at the launch URL') if opened == false
            opened
          end

          def default_browser_open(url, geometry:, on_start:, on_exit:)
            Lich::WebUI::BrowserLauncher.open(url, geometry: geometry, on_start: on_start, on_exit: on_exit)
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

          # Applies the window's presentation, resolving what the facility
          # leaves unsaid. Window#presentation omits a property that is false
          # and returns nil once nothing is set, so a script turning keep-above
          # off never arrives as a value -- only as an absence. The defaults
          # here are what absence means, which is what makes a toggle revert.
          # Public: a Window calls this when its presentation changes, which
          # can happen long after the window opened (map's opacity menu).
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

          def kill_browser(pid)
            killer = self.class.browser_kill || proc { |target| Process.kill('KILL', target) }
            killer.call(pid)
          rescue StandardError
            nil
          end

          def note_viewer(page, viewer_id)
            return unless page && viewer_id

            @mutex.synchronize { (@viewers[page] ||= {})[viewer_id.to_s] = true }
          end

          def forget_viewer(page, viewer_id)
            @mutex.synchronize { @viewers[page]&.delete(viewer_id.to_s) }
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
          def script_origin(backtrace)
            name = owner_label.to_s
            unless name.empty?
              named = backtrace.find { |frame| frame.match?(/(\A|[\\\/])#{Regexp.escape(name)}(\.lic)?:\d+/) }
              return named if named
            end
            backtrace.find { |frame| frame.include?('.lic:') }
          end

          # ".../scripts/map.lic:2462:in 'block'" -> "map.lic:2462".
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
