# frozen_string_literal: true

require 'securerandom'
require 'uri'
require_relative '../../../webui'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Adapter with the two extensions the shim needs: an explicit commit,
        # and viewer-scoped properties written as shared state. The shim
        # widget is the single source of truth for a value; per-viewer
        # divergence is pushed to attached viewers by Session#viewer_write.
        class ShimAdapter < Lich::WebUI::Adapter
          def initialize(...)
            super
            @placements = {}.compare_by_identity
            @presentation_sources = {}.compare_by_identity
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
            @mutex.synchronize do
              adapter = self
              node.children.each do |child_handle|
                child = @nodes.fetch(child_handle)
                props = effective_props(child, child_handle)
                bindings = child.bindings.to_h do |event, binding_id|
                  [event, @bindings.fetch(binding_id).last]
                end
                placement = @placements[child_handle] || {}
                builder.component(child.type, slot: child.slot, on: bindings, placement: placement, **props) do
                  adapter.send(:render_children, self, child)
                end
              end
            end
          end

          def destroy_node!(handle)
            @placements.delete(handle)
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
              owner ||= (@null_owner ||= NullOwner.new('gtk-shim'))
              @registry_mutex.synchronize do
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
            @viewers = Hash.new { |hash, key| hash[key] = {} } # page => { viewer_id => true }
            @browsers = {} # window => pid
            @window_handles = {} # window => OS window handle, once found
            @pointer_window = nil
            @mutex = Mutex.new
            @closed = false
          end

          def service
            @service ||= Lich::WebUI.service
          end

          def adapter
            @adapter ||= ShimAdapter.new(owner: @owner, service: service)
          end

          # The URL a browser can fetch a local file from. The FileService
          # serves whole directories, so one registration covers every image
          # beside the first -- a map directory is registered once, not once
          # per map.
          #
          # Returns nil when the directory is outside the roots the
          # FileService allows; the caller renders an empty image rather
          # than leaking a path the server would refuse anyway.
          def serve_file(path)
            full = File.expand_path(path.to_s)
            return nil unless File.file?(full)

            directory = File.dirname(full)
            @file_roots ||= {}
            base = @file_roots[directory] ||= register_file_root(directory)
            return nil unless base

            "#{base}#{URI::DEFAULT_PARSER.escape(File.basename(full))}"
          end

          # The FileService allows only its own asset root by default, so a
          # script's images have to name the root they live under. Lich's
          # own directories are the honest answer: a script may serve what
          # ships with Lich (maps) or what it installed beside itself, and
          # nothing else. A directory outside them is refused by the
          # FileService, which is the behaviour we want -- the shim does not
          # widen the allowlist, it just names the roots that already exist.
          SERVABLE_ROOTS = %w[MAP_DIR SCRIPT_DIR DATA_DIR LICH_DIR].freeze

          def register_file_root(directory)
            root = servable_root_for(directory)
            return nil unless root

            alias_name = "gtk-#{owner_label.to_s.downcase.gsub(/[^a-z0-9]+/, '-')}-#{@file_roots.size}"
            service.register_files(alias_name, directory, owner: @owner, script_root: root)
          rescue StandardError => error
            log(:warning, "webui-gtk-shim: cannot serve #{directory}: #{error.message}")
            nil
          end
          private :register_file_root

          # The narrowest Lich directory that contains this one, so a script
          # serving maps does not thereby get to serve the whole install.
          def servable_root_for(directory)
            full = File.expand_path(directory)
            candidates = SERVABLE_ROOTS.filter_map do |name|
              next unless Object.const_defined?(name)

              File.expand_path(Object.const_get(name).to_s)
            end
            candidates.select { |root| full == root || full.start_with?("#{root}/") }
                      .max_by(&:length)
          end
          private :servable_root_for

          def owner_label
            return @owner.name if @owner.respond_to?(:name) && @owner.name

            "#{@owner.class}:#{@owner.object_id}"
          end

          # ---- the emulated GTK thread ------------------------------------

          def enqueue(&block)
            raise ArgumentError, 'block required' unless block

            @queue << block
            ensure_thread
            nil
          end

          # Runs +block+ on the session thread and waits for it. Never call
          # from the session thread itself (that would deadlock); it is for
          # specs and for script threads that need a synchronous round trip.
          def sync(&block)
            return block.call if on_session_thread?

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
          rescue Lich::WebUI::Error => error
            log(:error, "commit failed: #{error.message}")
          end

          # Pushes a viewer-scoped value (entry text, checkbox state) to every
          # viewer currently attached to the widget's page, so the browser's
          # own copy of the control does not shadow the script's write.
          def viewer_write(window, widget, name, value)
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

          # The window that last saw a pointer gesture: where a popup menu
          # opened from a button-press handler belongs.
          def note_pointer(window)
            @mutex.synchronize { @pointer_window = window } if window
          end

          def popup_window
            @mutex.synchronize { @pointer_window || @windows.find(&:handle) || @windows.first }
          end

          # Wraps a script-facing callback for the WebUI dispatcher: note the
          # viewer, hop onto the session thread, and return immediately.
          def dispatch_proc(window, &handler)
            raise ArgumentError, 'handler block required' unless handler

            proc do |context|
              page = adapter.page_for(window.handle) if window.handle
              note_viewer(page, context.viewer_id) if page && context.respond_to?(:viewer_id)
              enqueue { handler.call(context) }
            end
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
          end

          private

          def ensure_thread
            @thread_mutex.synchronize do
              return if @thread&.alive?

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

            @mutex.synchronize { @viewers[page][viewer_id.to_s] = true }
          end

          def forget_viewer(page, viewer_id)
            @mutex.synchronize { @viewers[page].delete(viewer_id.to_s) }
          end

          def viewers_for(page)
            @mutex.synchronize { @viewers[page].keys }
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
