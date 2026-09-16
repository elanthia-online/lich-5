# frozen_string_literal: true

require 'securerandom'
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

          def render_children(builder, node)
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
              @browsers.delete(window)
            end
            if handle
              page = adapter.page_for(handle)
              @viewers.delete(page) if page
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
            if service.server.connection_count.zero?
              page = service.registry.fetch(@owner, id)
              open_browser(page, geometry: { width: 460, height: 240 }) { future.cancel(reason: :closed) }
            end
            future
          end

          # ---- teardown ----------------------------------------------------

          def shutdown
            return if @closed

            @closed = true
            windows = @mutex.synchronize { @windows.dup }
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
              rescue StandardError, ScriptError => error
                report(error)
              end
              commit unless @closed
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
            message = "error in Gtk.queue: #{error.message}\n\t#{Array(error.backtrace).first(8).join("\n\t")}"
            respond("error in Gtk.queue: #{error.message}") if respond_to?(:respond, true)
            log(:error, message)
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
