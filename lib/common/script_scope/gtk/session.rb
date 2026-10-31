# frozen_string_literal: true

require 'monitor'

module Lich
  module Common
    module ScriptScope
      module Gtk
        class UnsupportedOperation < StandardError; end

        # One compatibility owner and shadow-state lock per running script.
        # Browser callbacks still execute on the core's bounded owner dispatcher.
        class Session
          attr_reader :port

          # Binds the script's shadow state and callback submissions to one host.
          # @param owner [Script] script whose lifetime governs all shim work
          def initialize(owner)
            @owner = owner
            @port = Lich::WebUI.adapter(owner: owner, viewer: self)
            @dispatch = Lich::WebUI.callback_queue(owner: owner)
            @mutex = Monitor.new
            @closed = false
            @windows = []
            @degradations = {}
            @window_viewers = {}.compare_by_identity
            notice = "#{owner.name}: legacy GTK compatibility is deprecated; convert this script to native WebUI."
            respond(notice)
            Lich.log(notice)
          end

          # Runs shadow-state work under the reentrant session monitor.
          # @yield operation requiring consistent widget state
          # @return [Object] block result
          def synchronize(&block)
            @mutex.synchronize(&block)
          end

          # Serializes mutable style state on the existing owner monitor.
          # @raise [UnsupportedOperation] after teardown or for another script
          # @api private
          def style_operation(receiver, operation)
            synchronize do
              refuse(receiver, operation) if @closed || !Script.current.equal?(@owner)
              yield
            end
          end

          # Retains only live contexts, including widgets not attached to windows.
          # @api private
          def register_style_context(context)
            style_operation(context, :style_context) do
              @style_contexts ||= Lich::WebUI::WeakIdentityMap.new
              refuse(context, :style_context) if @style_contexts.size >= Lich::WebUI::Contract::BOUNDS[:components]
              @style_contexts[context] = true
            end
          end

          # Releases a retired context immediately rather than waiting for owner death.
          # @api private
          def forget_style_context(context)
            @style_contexts&.delete(context)
          end

          # Runs bounded screen-provider bookkeeping under the existing owner monitor.
          # Screen tokens from this session all denote the same nominal screen.
          # @api private
          def screen_style_operation(receiver, operation, screen, provider)
            style_operation(receiver, operation) do
              # Later-layer constants (Gdk::Screen and CssProvider; defined at P13 or P14) are absent from
              # P12 and P13 trees; resolve them at call time. An absent class has no instances.
              # Retirement: replace these guards with plain constant references once this
              # file is no longer shipped or tested without the later layers.
              valid = defined?(Gdk::Screen) && screen.is_a?(Gdk::Screen) && screen.session.equal?(self) &&
                      defined?(CssProvider) && provider.is_a?(CssProvider) && provider.session.equal?(self)
              refuse(receiver, operation) unless valid
              @screen_style_providers ||= {}.compare_by_identity
              yield @screen_style_providers
            end
          end

          # Allocates the next SizeGroup identity for this script session. The
          # count only grows: the bound limits creations over the session's life.
          # @param receiver [SizeGroup] group being created
          # @param limit [Integer] lifetime creation bound
          # @return [Integer] new sequence number
          # @raise [UnsupportedOperation] past the bound
          # @api private
          def next_size_group_sequence(receiver, limit)
            synchronize do
              sequence = @size_group_sequence.to_i + 1
              refuse(receiver, :new) if sequence > limit
              @size_group_sequence = sequence
            end
          end

          # Screen providers are session-local; callers receive an independent map.
          # @api private
          def screen_style_providers = (@screen_style_providers || {}).dup

          # Re-evaluates bounded label cues after provider or ancestor changes.
          # @api private
          def refresh_label_styles
            synchronize { @style_contexts&.each_key { |context| context.send(:refresh) } }
          end

          # Consolidates all CSS omissions without retaining or logging source CSS.
          # @api private
          def omit_css(receiver)
            degrade(:css_decoration, 'CSS decoration omitted; supported controls use the WebUI theme', receiver: receiver)
          end

          # Reuses one owner-scoped authenticated route per accepted image directory.
          # @param path [String] canonical file path, never a URL or native pixel object
          # @return [String] encoded relative file URL
          def image_source(path)
            synchronize do
              @image_roots ||= {}
              directory = File.dirname(path)
              script_root = File.dirname(@owner.file_name) if @owner.respond_to?(:file_name) && @owner.file_name
              prefix = @image_roots[directory] ||= Lich::WebUI.service.register_files(
                "shim-#{SecureRandom.hex(12)}", directory, owner: @owner, script_root: script_root
              )
              prefix + CGI.escape(File.basename(path)).gsub('+', '%20')
            end
          end

          # Defers script UI work without holding the shadow-state lock on admission.
          # The core worker supplies FIFO ordering and bounded cancellation; this
          # wrapper supplies Script ownership and the legacy queue error boundary.
          # Work queued by a signal retains its viewer and window for input reads
          # and writes. Unrelated threads must not inherit the active signal's viewer.
          # Exit handlers (before_dying procs) run inline on the owner's cleanup
          # thread because its ordinary workers have already been stopped. This
          # also permits their existing queue-then-wait cleanup pattern, including
          # the destroys they trigger, without reviving dispatch. The stopping
          # owner's own threads (a killed worker's ensure block) run inline the
          # same way, so a queue-then-wait there completes instead of hanging the
          # stop (1843:RC18, legacy parity); the wait needs no timeout. Other
          # threads get nil while the owner is stopping. Destroy handlers run by
          # the owner-death close, and any later call, get nil: that work is
          # skipped, not deferred.
          # @yield one-shot callback; must not wait for another callback on this owner
          # @return [Symbol, nil] :queued when admitted/cleaned up, nil for late work
          # @raise [ArgumentError] when no block is supplied
          # @raise [Lich::WebUI::Error] for a stopped host or queue overflow
          def queue(&block)
            raise ArgumentError, 'work block is required' unless block
            return if @closed
            if owner_stopping_thread?
              run_queue_block(:queue, inline: true) { synchronize { model_batch { block.call unless @closed } } }
              return :queued
            end
            return if stopping?

            context = @callback_context
            context = nil unless context&.first.equal?(Thread.current)
            @dispatch.call do
              execute_callback(context, &block)
            end
          end

          # Captures script/viewer attribution before handing timing to the core.
          # @return [Integer] cancellable source ID; false/nil or callback failure stops repetition
          # @raise [UnsupportedOperation] for unsupported intervals, missing blocks or late registration
          def schedule(receiver, operation, interval_ms, &block)
            style_operation(receiver, operation) do
              valid = block && interval_ms.is_a?(Integer) && interval_ms.between?(0, Lich::WebUI::Scheduler::MAX_INTERVAL_MS)
              refuse(receiver, operation) unless valid && !stopping?
              context = @callback_context
              context = nil unless context&.first.equal?(Thread.current)
              @scheduler ||= Lich::WebUI.callback_scheduler(owner: @owner)
              @scheduler.schedule(interval_ms) do
                execute_callback(context, &block)
              end
            end
          end

          # Removes only an owner-authorized source; foreign IDs get the standing refusal.
          # @return [Boolean] whether the source was still live
          def remove_source(receiver, id)
            style_operation(receiver, :remove) do
              refuse(receiver, :remove) unless id.is_a?(Integer) && id.positive?
              @scheduler ||= Lich::WebUI.callback_scheduler(owner: @owner)
              @scheduler.cancel(id)
            rescue Lich::WebUI::Error
              refuse(receiver, :remove)
            end
          end

          # Widget teardown cancels only IDs retained from this session, including
          # owner close after registration has already been disabled.
          def cancel_widget_source(id)
            synchronize { @scheduler&.cancel(id) }
          end

          # Retains a top-level window for owner-death cleanup.
          # @return [void]
          def register(window)
            @windows << window
          end

          # The submitting viewer is an explicit target for script-thread writes
          # after Save. The core still owns attachment liveness and refuses a
          # closed viewer; this object contains no transport or draft state.
          def viewer_id
            viewer, root = @callback_context&.drop(1)
            return viewer unless @access_root && !@access_root.equal?(root)

            pointer = @access_root.pointer_viewer if @access_root.is_a?(Window)
            pointer || @window_viewers[@access_root]
          end

          # One script may own multiple windows with different attachments.
          # Resolve a port read/write against its own window's originating viewer.
          def with_widget(widget)
            synchronize do
              previous = @access_root
              @access_root = root_for(widget)
              yield
            ensure
              @access_root = previous
            end
          end

          # Removes a destroyed window from cleanup and viewer-attribution indexes.
          # @return [void]
          def forget(window)
            @window_viewers.delete(window)
            @windows.delete(window)
          end

          # Reports whether the session is currently executing a viewer-attributed callback.
          # @return [Boolean]
          def in_callback? = !@callback_context.nil?

          # Keeps a pointer's window and coordinates only for its synchronous callback.
          # A later callback cannot accidentally open a popup in another viewer.
          # @api private
          def with_pointer(widget, event)
            previous = @pointer_context
            @pointer_context = [widget, event]
            yield
          ensure
            @pointer_context = previous
          end

          # @return [Array(Widget, PointerEvent), nil] active pointer callback
          def pointer_context = @pointer_context

          # Adopts script ownership and viewer context while executing a mapped GTK signal.
          # Terminal actions commit input shadow state before the handler; context clears on exit.
          # Signal handlers share the queue error boundary: script failures are
          # contained and attributed here, and SystemExit reaches the dispatcher.
          # @param event [Lich::WebUI::Runtime::EventContext] validated core event
          # @param terminal [Boolean] whether to capture current inputs before the handler
          # @param widget [Widget, nil] source used to select its own window
          # @yield legacy signal handler
          # @return [Object, nil] handler result, or nil after a reported failure
          def callback(event, terminal: false, widget: nil)
            @owner.thread_group.add(Thread.current) unless Script.current.equal?(@owner)
            run_queue_block(:signal) do
              synchronize do
                root = root_for(widget) if widget
                @window_viewers[root] = event.viewer_id if root
                with_callback_context(event.viewer_id, root) do
                  root.commit_inputs if terminal && root
                  model_batch { yield }
                end
              end
            end
          end

          # Enlists a model lazily in the current dispatcher callback. Calls
          # outside a callback validate at once; see coalesce_model? for when
          # their publication is coalesced.
          # @return [Boolean] whether this callback defers the model's publication
          # @api private
          def defer_model(model)
            return false unless @model_batch
            unless @model_batch.key?(model)
              model.begin_batch!
              @model_batch[model] = true
            end
            true
          end

          # A write outside a callback publishes at once and fences its model.
          # Until the one queued fence job runs, later writes to that model check
          # only their own rows and publish together at the next barrier: the
          # fence job's callback flush, or an earlier widget read, write or
          # callback flush. No timer is involved (1844:RC4).
          # @param model [ListStore] model being mutated outside a callback
          # @return [Boolean] whether the mutation may defer its publication
          # @api private
          def coalesce_model?(model) = !stopping? && @model_fences&.key?(model) == true

          # Records an immediate publication and, for coalescing observers, fences later writes.
          # @param model [ListStore] model just published outside a callback
          # @param fence [Boolean] whether any observer can defer its publication
          # @return [void]
          # @api private
          def model_published(model, fence:)
            @script_models&.delete(model)
            return unless fence && !stopping?

            (@model_fences ||= {}.compare_by_identity)[model] = true
            return if @model_fence_queued

            @model_fence_queued = true
            # The job runs on the owner's dispatcher, ahead of the adapter's own
            # publication of the first write, so the browser render carries the batch.
            release_model_fences unless queue { release_model_fences }
          rescue Lich::WebUI::Error
            # Without a fence job, later writes keep publishing at once.
            release_model_fences
          end

          # Holds a fenced model's validated change for the next barrier.
          # @param model [ListStore] model whose observers deferred publication
          # @return [void]
          # @api private
          def defer_model_publication(model)
            (@script_models ||= {}.compare_by_identity)[model] = true
          end

          # Validates all candidates before publishing any model. Widget operations
          # use this barrier to retain synchronous script-visible UI behavior.
          # Coalesced writes from outside a callback publish here first.
          # @api private
          def flush_models!
            synchronize do
              publish_script_models!
              return if !@model_batch || @model_batch.empty? || @flushing_models
              @flushing_models = true
              models = @model_batch.keys
              begin
                models.each(&:validate_batch!)
                models.each(&:publish_batch!)
                # A published batch carries any coalesced change to the same model.
                models.each { |model| @script_models&.delete(model) }
                models.each(&:finish_batch!)
                @model_batch.clear
              ensure
                models.each(&:rollback_batch!)
                @model_batch.clear
                @flushing_models = false
              end
            end
          end

          # Logs each unsupported presentation approximation once per session.
          # @param receiver [Object, nil] include source attribution when supplied
          # @return [void]
          def degrade(operation, reason, receiver: nil)
            return if @degradations[operation]

            @degradations[operation] = true
            source = receiver ? attribution(receiver, operation) : "#{@owner.name}: compatibility #{operation}"
            Lich.log("#{source}: #{reason}")
          end

          # Fails loudly with script, receiver, operation, and source-call attribution.
          # @raise [UnsupportedOperation] always
          def refuse(receiver, operation, error_class: UnsupportedOperation, **details)
            raise error_class.new(attribution(receiver, operation), **details)
          end

          # Invalid source calls that preserve the existing widget tree remain
          # visible to maintainers, including their script and call location.
          def source_warning(receiver, operation, message)
            Lich.log("#{attribution(receiver, operation)}: #{message}")
          end

          # Isolates script cleanup failures so later handlers/windows still close.
          # Uses the core dispatcher's contained set; fatal VM failures outside
          # it are not treated as recoverable script errors. SystemExit is
          # contained only once this session is closed or its owner is already
          # stopping. A destroy handler that exits while the owner is live (a
          # window closed from a signal, or an explicit destroy) is an owner-stop
          # request like any other callback exit (1843:RC3): it propagates to the
          # dispatcher or the script thread, and the remaining handlers of that
          # destroy are skipped because the owner is being stopped.
          # @param receiver [Widget] object whose cleanup is running
          # @yield cleanup action
          # @return [Object, nil] cleanup result, or nil after a reported failure
          # @raise [SystemExit] from a destroy handler while the owner is live
          def cleanup(receiver)
            yield
          rescue SystemExit, *Lich::WebUI::Dispatcher::CONTAINED_EXCEPTIONS => error
            raise if error.is_a?(SystemExit) && !stopping?

            source_warning(receiver, :destroy, "cleanup failed error=#{error.class} at=#{error.backtrace&.first}")
            nil
          end

          # Attempts every remaining window even if one script callback fails.
          # @return [void]
          def close
            @closed = true
            synchronize do
              @scheduler&.cancel_all
              @style_contexts&.keys&.each { |context| context.send(:close) }
              @screen_style_providers&.clear
              @windows.dup.each { |window| cleanup(window) { window.destroy } }
            end
          end

          # Closes the session from the core's pre-terminate hook thread. That thread
          # is a host thread, so Script.current is nil on it; it stands in for the
          # owner's cleanup thread (blocked on the hook) and carries the same
          # cleanup identity for the close, so destroy handlers keep resolving the
          # dying script as they did when the close ran on the cleanup thread.
          # Retire this borrowed identity once the core hook runner supplies the
          # owner's cleanup identity to hooks itself.
          # @return [void]
          # @api private
          def close_for_owner_death
            key = Script::CLEANUP_SCRIPT_THREAD_KEY if Script.const_defined?(:CLEANUP_SCRIPT_THREAD_KEY, false)
            return close unless key

            previous = Thread.current.thread_variable_get(key)
            Thread.current.thread_variable_set(key, @owner)
            begin
              close
            ensure
              Thread.current.thread_variable_set(key, previous)
            end
          end

          private

          # Runs admitted queue/timer work with the captured viewer and window.
          # Admission, scheduling and cleanup-thread execution stay in their callers.
          # @param context [Array, nil] immutable registering thread/viewer/window snapshot
          # @yield owner callback, batched under the session monitor
          # @return [Object, nil] callback result, or nil after stopping/failure
          def execute_callback(context, &block)
            run_queue_block do
              next if stopping?

              @owner.thread_group.add(Thread.current) unless Script.current.equal?(@owner)
              Script.current # Honor pause after adopting the initially unowned worker.
              synchronize do
                with_callback_context(context&.[](1), context&.[](2)) { model_batch { block.call unless stopping? } }
              end
            end
          end

          # One rollback snapshot per model per callback or widget barrier. Nested
          # signals share this batch under the existing owner/session monitor.
          def model_batch
            return yield if @model_batch
            @model_batch = {}.compare_by_identity
            begin
              result = yield
              flush_models!
              result
            ensure
              @model_batch.each_key(&:rollback_batch!)
              @model_batch = nil
            end
          end

          # Publishes coalesced script-thread changes once each. A model staged in
          # the current callback waits: its candidate is not validated yet, and a
          # rollback leaves its coalesced change for a later barrier. Each entry is
          # removed before its publication, so a failure is raised once, not retried.
          # @return [void]
          def publish_script_models!
            return if @publishing_script_models || !@script_models || @script_models.empty?

            models = @script_models.keys.reject { |model| @model_batch&.key?(model) }
            return if models.empty?

            @publishing_script_models = true
            begin
              models.each do |model|
                @script_models.delete(model)
                model.publish_script_changes!
              end
            ensure
              @publishing_script_models = false
            end
          end

          # Ends the current coalescing window; the caller's barrier publishes what it held.
          # @return [void]
          def release_model_fences
            @model_fences = nil
            @model_fence_queued = false
          end

          # Restore nested attribution even when a handler raises. The immutable
          # snapshot lets queue admission inspect thread ownership without waiting
          # for the monitor held by another callback.
          def with_callback_context(viewer, root)
            previous = @callback_context
            @callback_context = viewer ? [Thread.current, viewer, root].freeze : nil
            yield
          ensure
            @callback_context = previous
          end

          # Recognizes only Script's active cleanup executor for this stopped owner.
          # @return [Boolean] whether queue work may run inline during exit cleanup
          def cleanup_thread?
            @owner.respond_to?(:stopping?) && @owner.stopping? &&
              Script.const_defined?(:CLEANUP_SCRIPT_THREAD_KEY, false) &&
              Thread.current.thread_variable_get(Script::CLEANUP_SCRIPT_THREAD_KEY).equal?(@owner)
          end

          # Recognizes the stopping owner's own threads: Script's cleanup executor,
          # or a thread in the owner's worker groups (a killed worker still running
          # its ensure block). Membership is tested on Thread.current itself, so
          # the block can only run inline on a thread that is already this owner's;
          # Script.current is not used because it waits out a pause and resolves
          # nothing once the owner has left the running registry.
          # @return [Boolean] whether queue work may run inline during owner stop
          def owner_stopping_thread?
            return true if cleanup_thread?

            @owner.respond_to?(:stopping?) && @owner.stopping? &&
              @owner.respond_to?(:has_thread?) && @owner.has_thread?(Thread.current)
          end

          # Applies the legacy error boundary to queue, timer, signal and exit-handler work.
          # Script failures use the core dispatcher's contained set. SystemExit
          # is re-raised so the dispatcher stops this owner through its owner_exit
          # hook (never Lich); only an already-stopping owner's cleanup thread,
          # or its own thread running a queue inline, contains it here.
          # Only shim class/operation tokens are retained from exception messages;
          # arbitrary script messages may contain sensitive input.
          # @param operation [Symbol] :queue for queued/timer work, :signal for handlers
          # @param inline [Boolean] whether the block runs on a stopping owner's own thread
          # @yield queued script operation
          # @return [Object, nil] callback result, or nil after a reported failure
          # @raise [SystemExit] from a dispatched callback, for the owner-stop path
          def run_queue_block(operation = :queue, inline: false)
            yield
          rescue SystemExit, *Lich::WebUI::Dispatcher::CONTAINED_EXCEPTIONS => error
            raise if error.is_a?(SystemExit) && !inline && !cleanup_thread?

            source = Array(error.backtrace).find { |frame| frame.start_with?("#{@owner.name}:") || frame.include?('.lic:') }
            detail = error.message[/\b(?:class=[\w:]+ )?operation=[\w?!=]+/] if error.is_a?(UnsupportedOperation)
            # Builder failures carry structural diagnostics, not raw XML/property text.
            # Preserve these through the queue boundary so a refused form is actionable.
            detail = "#{detail} #{error.diagnostic}" if defined?(BuilderError) && error.is_a?(BuilderError)
            detail = "#{detail} #{error.diagnostic}" if defined?(ModelValueError) && error.is_a?(ModelValueError)
            source_warning(self, operation, "callback failed error=#{error.class} at=#{source || error.backtrace&.first}#{" rejected=#{detail}" if detail}")
            respond "error in #{operation == :signal ? 'GTK signal handler' : 'Gtk.queue'} (#{@owner.name}): #{error.class}; see debug log"
            # An unhandled Builder failure can leave an allocated form without
            # its Close/destroy handlers. Retire this owner's UI and use Script's
            # existing asynchronous stop path; never leave a partial form running.
            # Direct Builder calls rescued by the script retain their normal
            # transactional behavior and do not reach this queue boundary.
            if defined?(BuilderError) && error.is_a?(BuilderError)
              close
              @owner.kill(async: true) if @owner.respond_to?(:kill)
            end
            nil
          end

          # Prevents teardown and retained sessions from admitting fresh UI work.
          # @return [Boolean] whether new or pending callbacks must be discarded
          def stopping?
            @closed || (@owner.respond_to?(:stopping?) && @owner.stopping?)
          end

          def root_for(widget)
            widget = widget.parent while widget.parent
            widget
          end

          def attribution(receiver, operation)
            location = caller_locations.find { |frame| frame.path == @owner.name || frame.path.end_with?('.lic') }
            name = receiver.is_a?(Module) ? receiver.name : receiver.class.name
            "script=#{@owner.name} class=#{name} operation=#{operation} source=#{location || 'unknown'}"
          end
        end
      end
    end
  end
end
