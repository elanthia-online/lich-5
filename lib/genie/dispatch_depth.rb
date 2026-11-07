# frozen_string_literal: true

module Lich
  module Genie
    # The nested-dispatch recursion cap (a user decision): nested
    # trigger/#parse dispatch stops at LIMIT levels with a script error, where Remix has no
    # guard at all (ParseTriggers FormMain.cs:4425 R, ParseCommand Command.cs:219 R) and
    # recurses until the client's stack overflows (flow-oracle `genie-crash`). Decided
    # divergence.
    #
    # The depth is counted per fiber (Thread#[] storage): a nested dispatch is synchronous
    # on the caller's own thread -- a script's `#parse` runs its own actions, the global
    # #triggers and (through them) more `#parse`s inline. Other scripts get the text queued
    # on their input (ParseDispatch), stamped with the depth it was issued at; the receiving
    # script continues the count from there ({.resume_at}), so a chain that hops between
    # script threads is capped like the single synchronous Remix recursion it models.
    module DispatchDepth
      LIMIT = 20
      KEY = :lich_genie_dispatch_depth
      PENDING_KEY = :lich_genie_dispatch_overflow

      # Raised one level past {LIMIT}; carries the message the outermost caller prints.
      class Exceeded < Error; end

      module_function

      # @return [Integer] nesting depth of the current fiber
      def current
        Thread.current[KEY] || 0
      end

      # Run the block one dispatch level deeper. The OUTERMOST call (depth 0 on entry)
      # rescues {Exceeded} and hands its message to +on_overflow+; inner calls let it
      # unwind so the whole chain stops, nothing after the cap runs. An overflow handed to
      # {.defer} is raised here too: before a new level starts and when the block ends.
      #
      # @param label [String] what is being dispatched (for the message), e.g. "#parse foo"
      # @param on_overflow [#call] callable(message) run once, at the outermost level
      # @return [Object] the block's value, or on_overflow's when the cap was hit
      def nest(label, on_overflow:)
        outermost = current.zero?
        raise_pending!
        depth = current + 1
        raise Exceeded, "Script error: maximum nested dispatch depth (#{LIMIT}) exceeded on: #{label}" if depth > LIMIT

        Thread.current[KEY] = depth
        begin
          value = yield
          raise_pending!
          value
        ensure
          Thread.current[KEY] = depth - 1
          Thread.current[PENDING_KEY] = nil if outermost
        end
      rescue Exceeded => e
        raise unless outermost

        on_overflow.call(e.message)
      end

      # Run the block with the count continued from +depth+ -- the depth a queued `#parse`
      # line was issued at on another thread (ParseDispatch::Line) -- and restore it after.
      # A deeper running count is never lowered. When this thread was at depth 0 on entry
      # this is its outermost level: an {Exceeded} from inside goes to +on_overflow+.
      #
      # @param depth [Integer]
      # @param on_overflow [#call] callable(message)
      # @return [Object] the block's value, or on_overflow's when the cap was hit
      def resume_at(depth, on_overflow:)
        previous = current
        Thread.current[KEY] = [depth, previous].max
        begin
          value = yield
          raise_pending!
          value
        ensure
          Thread.current[KEY] = previous
          Thread.current[PENDING_KEY] = nil if previous.zero?
        end
      rescue Exceeded => e
        raise unless previous.zero?

        on_overflow.call(e.message)
      end

      # Keep an {Exceeded} that a host callback cannot let propagate -- the Lich glue's
      # script-output feed runs inside Lich's respond/_respond, whose `rescue => e`
      # (lib/global_defs.rb:1761-1798) would swallow it and let the chain run on. The
      # enclosing {.nest}/{.resume_at} of this thread re-raises it ({.raise_pending!}); the
      # first one deferred wins. Outside any chain there is no frame to re-raise it: nothing
      # is kept and the caller reports it itself.
      #
      # @param error [Exceeded]
      # @return [Boolean] true when an enclosing dispatch level will re-raise it
      def defer(error)
        return false if current.zero?

        Thread.current[PENDING_KEY] ||= error
        true
      end

      # The echo port of the genie interpreters and the trigger runner: print +text+ through
      # the host's +respond+, then {.raise_pending!} -- an overflow the script-output feed
      # deferred inside that respond (ParseDispatch.feed_output) stops the chain right here,
      # before the next command of the echoing script or trigger body runs.
      #
      # @param respond [#call] callable(text), e.g. Lich's respond
      # @param text [String]
      # @return [void]
      def respond_in_chain(respond, text)
        respond.call(text)
        raise_pending!
      end

      # Run a host call that must not raise into its caller: any error goes to +on_error+,
      # except an {Exceeded}, which propagates to the enclosing {.nest}/{.resume_at} so the
      # chain stops (GenieScript.script_list_changed once swallowed it).
      #
      # @param on_error [#call] callable(exception)
      # @return [Object, nil] the block's value, or nil after an error
      def contain(on_error)
        yield
      rescue Exceeded
        raise
      rescue StandardError => e
        on_error.call(e)
        nil
      end

      # Raise the overflow handed to {.defer} on this thread, if any (cleared first). Host
      # ports call it right after a respond so nothing more of the chain runs.
      # @return [void]
      def raise_pending!
        pending = Thread.current[PENDING_KEY]
        return unless pending

        Thread.current[PENDING_KEY] = nil
        raise pending
      end
    end
  end
end
