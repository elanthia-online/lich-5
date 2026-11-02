# frozen_string_literal: true

require_relative '../../../webui'
require_relative 'session'
require_relative 'scheduling'
require_relative 'widgets'
require_relative 'size_group'
require_relative 'adjustment'
require_relative 'layout'
require_relative 'models'
require_relative 'tree_view'
require_relative 'combo_box'
require_relative 'inputs'
require_relative 'list_box'
require_relative 'dialogs'
require_relative 'style'
require_relative 'display_geometry'
require_relative 'displays'
require_relative 'header_bar'
require_relative 'text'
require_relative 'images'
require_relative 'menus'
require_relative 'transfers'
require_relative 'drawing'
require_relative 'builder'
require_relative 'require_boundary'

module Lich
  module Common
    module ScriptScope
      # Availability describes this compatibility surface, never a native load.
      HAVE_GTK = true

      module Gtk
        # Legacy spelling for the existing browser-owned automatic scroll policy.
        POLICY_AUTOMATIC = :automatic
        POLICY_ALWAYS = :always
        POLICY_NEVER = :never

        # Legacy spelling reuses the existing bounded scroller inset policy.
        SHADOW_IN = :in
        SHADOW_ETCHED_IN = :etched_in

        module Align
          START = :start
          CENTER = :center
          const_set(:END, :end)
          FILL = :fill
        end

        # Bounded placement hint; the host retains control of initial placement.
        module WindowPosition
          CENTER = :center
          CENTER_ON_PARENT = :center_on_parent

          # @raise [UnsupportedOperation] for position modes outside this facade
          def self.const_missing(name)
            Gtk.session.refuse(self, name)
          end
        end

        # Legacy nested spelling shares the same bounded host-placement hint.
        Window::Position = WindowPosition
        Window::POS_CENTER = WindowPosition::CENTER

        module WindowType
          TOPLEVEL = :toplevel
        end

        module Version
          MAJOR = 3
          STRING = '3.24.0'.freeze

          # Refuses version constants outside the bounded compatibility surface.
          # @raise [UnsupportedOperation] always
          def self.const_missing(name)
            Gtk.session.refuse(self, name)
          end
        end

        @sessions = {}.compare_by_identity
        # Owners whose death close has begun (1845:RC12). Weak: the marker must
        # not keep a dead Script alive.
        @closed_owners = Lich::WebUI::WeakIdentityMap.new
        @mutex = Mutex.new

        # Checks the advertised compatibility version without loading native GTK.
        # @param required_major [Integer] required unsigned major version
        # @param required_minor [Integer] required unsigned minor version
        # @param required_micro [Integer] required unsigned micro version
        # @return [nil, String] nil if compatible, otherwise a mismatch diagnostic
        # @raise [ArgumentError] for components outside the unsigned GTK range
        def self.check_version(required_major, required_minor, required_micro)
          required = [required_major, required_minor, required_micro]
          unless required.all? { |part| part.is_a?(Integer) && part.between?(0, 0xffff_ffff) }
            raise ArgumentError, 'GTK version components must be unsigned 32-bit integers'
          end

          available = Version::STRING.split('.').map(&:to_i)
          return nil if required_major == Version::MAJOR && (required <=> available) <= 0

          "GTK compatibility version #{Version::STRING} is incompatible with required #{required.join('.')}"
        end

        # Finds or creates the running Script's identity-owned compatibility session.
        # Retains callback attribution on the current thread without loading native GTK.
        # An owner whose death close has begun gets no new session: its pre-terminate
        # hook has already run (or is running) and would never close another, so a
        # session created now, for example by a widget built in a destroy handler,
        # would stay held with a hook that never fires. The same holds for an owner
        # that never used Gtk, whose core pre-terminate hooks have started or run:
        # its first widget, built by a worker unwinding after them, gets no session
        # either (1836:RC22). The hook is registered before the session is created,
        # and the core refusal of a registration for an owner whose hooks have
        # started is what is trusted; a check before registering would leave a
        # window in which the owner starts between the check and the call.
        # Both refuse through the closed-owner error below. An owner that is merely
        # stopping, before its death close, still gets one (1845:RC12).
        # @return [Session]
        # @raise [UnsupportedOperation] when no Script owns the call, or the owner's
        #   death close or pre-terminate hooks have started, and it has no session
        def self.session
          owner = Script.current
          raise UnsupportedOperation, 'script owner is required for Gtk' unless owner

          current = @mutex.synchronize do
            @sessions[owner] ||= begin
              message = "#{owner.name}: Gtk session is closed because the script is past its death close"
              raise UnsupportedOperation, message if @closed_owners.key?(owner)

              begin
                close_on_death(owner)
              rescue Lich::WebUI::Error
                raise UnsupportedOperation, message
              end
              Session.new(owner)
            end
          end
          Thread.current.thread_variable_set(:lich_script_compatibility_session, current)
          current
        end

        # Defers one block onto the existing core owner dispatcher. Shadow-state
        # operations inside the block remain synchronous. During before_dying,
        # the existing session executes cleanup on Script's cleanup thread.
        # No native GTK loop or second shim queue is created.
        # @yield script UI work to execute once, in owner enqueue order
        # @return [Symbol, nil] :queued on admission/cleanup, nil for other late work
        # @raise [UnsupportedOperation] when no script owner/session is available
        # @raise [ArgumentError] when no block is supplied
        # @raise [Lich::WebUI::Error] when the host stopped or its queue is full
        def self.queue(&block)
          raise ArgumentError, 'work block is required' unless block

          owner = Script.current
          if owner.respond_to?(:stopping?) && owner.stopping?
            # Teardown may use an existing session, but must never create a host.
            current = @mutex.synchronize { @sessions[owner] }
            return current&.queue(&block)
          end

          current = owner ? session : Thread.current.thread_variable_get(:lich_script_compatibility_session)
          raise UnsupportedOperation, 'script owner is required for Gtk' unless current

          current.queue(&block)
        end

        # Native main-loop calls report a lifecycle-only compatibility degradation:
        # the core dispatcher already owns the loop and must never be nested.
        def self.main
          session.degrade(:main_loop, 'native main-loop control is replaced by the core dispatcher')
          nil
        end

        # Reports the main-loop degradation without stopping Lich, its game, or the core dispatcher.
        # @return [nil]
        def self.main_quit
          session.degrade(:main_loop, 'native main-loop control is replaced by the core dispatcher')
          nil
        end

        # There is no native GTK queue to pump; the core worker owns dispatch.
        def self.events_pending?
          session.degrade(:main_loop, 'native main-loop control is replaced by the core dispatcher')
          false
        end

        # A nonblocking native iteration has no work; nested blocking dispatch refuses.
        def self.main_iteration_do(blocking)
          session.refuse(self, :main_iteration_do) unless blocking == false
          events_pending?
        end

        # Refuses unsupported GTK constants at the script boundary.
        # @raise [UnsupportedOperation] always
        def self.const_missing(name)
          session.refuse(self, name)
        end

        # Refuses unsupported GTK calls with script and source attribution.
        # @raise [UnsupportedOperation] always
        def self.method_missing(name, *, **, &)
          session.refuse(self, name)
        end

        # Keeps reflection limited to implemented methods; unsupported GTK calls remain explicit refusals.
        # @return [Boolean]
        def self.respond_to_missing?(*args)
          super
        end

        # Closes the dying script's windows through the core's pre-terminate hook,
        # so their destroy handlers run while the owner's pages are still
        # registered; a plain ScriptDeath handler would run after the core
        # retired them (1836:RC20). The hook is registered for this owner only,
        # just before its session is created: the hook runner costs a host thread and a
        # wait on the cleanup thread per hook, and scripts that never used Gtk
        # must not pay it. It runs on a host thread, bounded by
        # Lich::WebUI::BEFORE_TERMINATE_TIMEOUT. The hook marks the owner closed
        # before it drops the session, so no later call recreates one (1845:RC12).
        # It closes whichever session the owner holds then, so it needs no session at
        # registration time.
        # @raise [Lich::WebUI::Error] when the owner's pre-terminate hooks have started
        #   (the owner is dying: the caller must create no session for it)
        # @api private
        def self.close_on_death(owner)
          Lich::WebUI.before_owner_terminate(owner: owner) do |dying|
            session = @mutex.synchronize do
              @closed_owners[dying] = true
              @sessions.delete(dying)
            end
            session&.close_for_owner_death
          end
        end
        private_class_method :close_on_death
      end
    end
  end
end
