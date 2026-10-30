# frozen_string_literal: true

require_relative '../../script_death'
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
        # @return [Session]
        # @raise [UnsupportedOperation] when no Script owns the call
        def self.session
          owner = Script.current
          raise UnsupportedOperation, 'script owner is required for Gtk' unless owner

          current = @mutex.synchronize { @sessions[owner] ||= Session.new(owner) }
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

        ScriptDeath.on_death do |owner|
          current = @mutex.synchronize { @sessions.delete(owner) }
          current&.close
        end
      end
    end
  end
end
