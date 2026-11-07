# frozen_string_literal: true

module Lich
  module Genie
    # Port of Remix's timed CommandQueue (Lists/CommandQueue.cs R): one FIFO per session (Remix:
    # Globals.CommandQueue) holding the commands `send N cmd`, `#send N cmd`, `#do N cmd`,
    # `#queue N cmd` and the `-` quick send put there. FormMain's 10 ms timer drains it
    # ({#drain}, TimerBgWorker_Tick FormMain.cs:8313-8339 R) BEFORE it ticks the scripts, and runs
    # every released command through Command.ParseCommand(cmd, bSendToGame: true)
    # (RunQueueCommand, FormMain.cs:3857-3870 R), so a queued `.name` launches and a queued
    # `#var` sets.
    #
    # Timing is relative and sequential (CommandQueue.cs:66-160 R): adding to an EMPTY queue
    # sets the next-release time to now + that item's delay; adding behind other items changes
    # nothing; releasing the head sets the next time to now + the NEW head's delay. So `send 2
    # look` then `send 1 smile` releases look at 2 s and smile at 3 s, and `#send clear`
    # (which keeps the stale time) followed by an add starts a fresh countdown. A head whose
    # restrictions hold (roundtime / webbed / stunned, per item) blocks the whole queue
    # (head-of-line), even an unrestricted `#queue` item behind it.
    #
    # Thread model: added to from script threads, Lich's parser thread (trigger bodies) and the
    # client thread (typed commands); drained on the {Worker} thread. One mutex; the
    # ConditionVariable lets the worker sleep while the queue is empty.
    class CommandQueue
      # One queued command (CommandQueue.Queue.EventItem, CommandQueue.cs:23-45 R). +owner+ is
      # ours, not Remix's: the host's opaque handle on the script that queued it (nil for a
      # #trigger body or a typed command), handed back with the action on release so the host
      # can send (and echo) it as that script. +route+ is ours too (only author-written text may
      # issue a Lich command): the author-marked text ({AuthoredCommand}) a `send ,go2 x` row
      # queued, nil for any other item; the release runs it, the listing shows +action+ (the
      # clean text).
      Item = Struct.new(:delay, :action, :wait_rt, :wait_webbed, :wait_stunned, :owner, :route, keyword_init: true) do
        # What a release runs: the author-marked text when there is one, else the action.
        # @return [String]
        def release_text
          route || action
        end

        # The item as text without the author marks (a mark is never printable; Struct's own
        # inspect would show +route+ with them).
        # @return [String]
        def inspect
          fields = to_h.merge(route: route && AuthoredCommand.strip(route))
          "#<struct #{self.class.name} #{fields.map { |name, value| "#{name}=#{value.inspect}" }.join(', ')}>"
        end
        alias_method :to_s, :inspect

        # pp's view: {#inspect}.
        def pretty_print(printer)
          printer.text(inspect)
        end

        # EventItem.IsRestricted (CommandQueue.cs:38-44 R).
        # @return [Boolean]
        def restricted?(in_rt, webbed, stunned)
          (wait_rt && in_rt) || (wait_webbed && webbed) || (wait_stunned && stunned) ? true : false
        end
      end

      # The state FormMain's tick hands Poll each time (HasRoundTime, $webbed == "1",
      # $stunned == "1"; FormMain.cs:8324, 8335 R).
      State = Struct.new(:in_rt, :webbed, :stunned, keyword_init: true)
      FREE = State.new(in_rt: false, webbed: false, stunned: false).freeze

      # DateTime.AddSeconds' bound (MaxTicks / TicksPerSecond, .NET 10 = Remix's target): a
      # larger |delay| throws ArgumentOutOfRangeException before any arithmetic.
      MAX_SECONDS = 315_537_897_599
      # The two .NET messages (never shown: the fault ends that ParseCommand, see {#add}).
      OUT_OF_RANGE = Numeric::ADD_OUT_OF_RANGE
      UNREPRESENTABLE = Numeric::ADD_UNREPRESENTABLE

      # A host's queue argument as a callable returning the queue: a callable as given (looked up
      # at each use, so a rebuilt Lich::Genie.command_queue is followed), a queue wrapped, nil =
      # a fresh private queue nobody drains (headless).
      # @param queue [CommandQueue, #call, nil]
      # @return [#call]
      def self.source(queue)
        return queue if queue.respond_to?(:call)

        queue ||= new
        -> { queue }
      end

      # One `#event` (Events.Queue.EventItem, Lists/Events.cs:13-24 R): due at an absolute time.
      EventItem = Struct.new(:due, :action, keyword_init: true)

      # @param clock [#call] wall clock (Time), Remix's DateTime.Now
      def initialize(clock: -> { Time.now })
        @clock = clock
        @items = []
        @events = [] # Globals.Events.EventList, kept sorted by due time
        @next_time = nil # m_oNextTime
        @mutex = Mutex.new
        @ready = ConditionVariable.new
      end

      # AddToQueue (CommandQueue.cs:66-95 R). The action may be empty: Remix queues it too
      # (`send 2` alone), and its release ends that tick's drain, so it acts as a pause.
      # The item is appended BEFORE SetNextTime, so a delay DateTime.AddSeconds rejects
      # (non-finite, past year 9999: `#queue 1e400 x`, `#send <20 digits> x`) raises AFTER the
      # append and leaves the stale next time -- the item then goes out on the next tick
      # (genieflow: "Value to add was out of range", swallowed with that ParseCommand).
      # @param delay [Numeric] seconds
      # @param action [String]
      # @param owner [Object, nil] the queuing script's host handle (see {Item}); never read here
      # @param route [String, nil] the author-marked text the release runs instead of +action+ ({Item})
      # @return [void]
      # @raise [Error] the AddSeconds fault (the item stays queued)
      def add(delay, action, wait_rt:, wait_webbed: false, wait_stunned: false, owner: nil, route: nil)
        @mutex.synchronize do
          @items << Item.new(delay: delay, action: action.to_s, wait_rt: wait_rt, wait_webbed: wait_webbed,
                             wait_stunned: wait_stunned, owner: owner, route: route)
          @ready.broadcast
          @next_time = next_time_after(delay) if @items.length == 1 # "Only item in list. Set the timer!"
        end
      end

      # Clear (CommandQueue.cs:96-112 R): `#send clear`, `#do clear`, `#queue clear`. The next
      # time is left as it was; the next add to the now empty queue resets it.
      # @return [void]
      def clear
        @mutex.synchronize { @items.clear }
      end

      # Poll (CommandQueue.cs:114-158 R): the head's action when its time has come and it is not
      # restricted (then it is removed and the next head's delay starts counting), else "".
      # @param state [State]
      # @return [String] the released action ({Item#release_text}), or "" (nothing released -- or an
      #   empty action)
      def poll(state = FREE)
        take(state)&.release_text || ''
      end

      # TimerBgWorker_Tick's drain (FormMain.cs:8324-8339 R): poll until "" (nothing ready, or an
      # empty action, which ends the drain like Remix's `while (sCommandQueue.Length > 0)`), with
      # the state re-read before each poll; each released action goes to the block.
      # @param state [#call] callable => {State}
      # @yieldparam action [String]
      # @yieldparam owner [Object, nil] the item's {Item#owner}
      # @return [Integer] how many actions were run
      def drain(state)
        count = 0
        loop do
          item = take(state.call)
          break if item.nil? || item.action.empty?

          count += 1
          yield item.release_text, item.owner
        end
        count
      end

      # Events.AddToQueue (Lists/Events.cs:26-60 R; `#event <seconds> <action>`, Command.cs:1103-1132
      # R): due at now + Utility.EvalDoubleTime(seconds, 0) -- seconds * 1000 ms when positive,
      # else at once (StringToDouble's -1 for a bad number included) -- and the list re-sorted by
      # due time (an equal time keeps add order: .NET's insertion sort for the short lists
      # involved).
      # @param seconds [Float]
      # @param action [String]
      # @return [void]
      # @raise [Error] DateTime.AddMilliseconds' fault (an infinite delay): nothing is added
      def add_event(seconds, action)
        ms = seconds.is_a?(Float) && seconds.nan? ? 0.0 : (seconds.to_f.positive? ? seconds.to_f * 1000 : 0.0)
        @mutex.synchronize do
          fault = Numeric.add_milliseconds_fault(ms, now: @clock.call)
          raise Error, fault if fault

          item = EventItem.new(due: @clock.call + (ms / 1000.0), action: action.to_s)
          index = @events.index { |event| event.due > item.due } || @events.length
          @events.insert(index, item)
          @ready.broadcast
        end
      end

      # `#event clear` (Command.cs:1117-1120 R).
      # @return [void]
      def clear_events
        @mutex.synchronize { @events.clear }
      end

      # The `#event` listing's view (ListEvents, Command.cs:3548-3586 R).
      # @return [Array<EventItem>] head first
      def events
        @mutex.synchronize { @events.map(&:dup) }
      end

      # Events.Poll (Lists/Events.cs:62-95 R): the head's action when it is due (removed), else "".
      # One per timer tick (FormMain.cs:8321-8322 R).
      # @return [String]
      def poll_event
        @mutex.synchronize do
          head = @events.first
          return '' if head.nil? || @clock.call < head.due

          @events.shift.action
        end
      end

      # The `#queue` listing's view (ListCommandQueue, Command.cs:3588-3626 R).
      # @return [Array<Item>] a snapshot, head first
      def items
        @mutex.synchronize { @items.map(&:dup) }
      end

      # @return [Boolean]
      def empty?
        @mutex.synchronize { @items.empty? }
      end

      # Block the calling thread while the queue and the event list are empty (the {Worker}'s
      # idle state).
      # @param timeout [Numeric, nil] give up after this many seconds (nil = wait for an add)
      # @return [Boolean] whether either holds an item now
      def wait_for_items(timeout = nil)
        @mutex.synchronize do
          @ready.wait(@mutex, timeout) if @items.empty? && @events.empty?
          !(@items.empty? && @events.empty?)
        end
      end

      private

      # Poll's body: the released head {Item}, or nil when nothing is due.
      def take(state)
        @mutex.synchronize do
          head = @items.first
          return nil if head.nil? || (@next_time && @clock.call < @next_time) # nil = default(DateTime)
          return nil if head.restricted?(state.in_rt, state.webbed, state.stunned)

          @items.shift
          release_next_time unless @items.empty?
          head
        end
      end

      # SetNextTime's DateTime.Now.AddSeconds(delay) (CommandQueue.cs:160-174 R), under the
      # lock: NaN saturates to 0 ticks (.NET 9+ double -> long), |delay| > MAX_SECONDS and a
      # result outside years 1..9999 raise like AddUnits / AddTicks. The caller keeps the old
      # time on a raise.
      # @return [Object] the clock's now + delay
      # @raise [Error]
      def next_time_after(delay)
        delay = 0 if delay.is_a?(Float) && delay.nan?
        raise Error, OUT_OF_RANGE if delay.abs > MAX_SECONDS

        time = @clock.call + delay
        raise Error, UNREPRESENTABLE if time.is_a?(Time) && !time.year.between?(1, 9999)

        time
      end

      # Poll's SetNextTime for the new head (CommandQueue.cs:141 R). Remix's throw there escapes
      # Poll after RemoveAt and the un-caught timer tick crashes the client (genieflow
      # driver-exception); ours keeps the stale time so the head goes out on the next poll and
      # the worker lives (kept divergence, docs/genie-engine/open-items.md K3; 0 corpus).
      def release_next_time
        @next_time = next_time_after(@items.first.delay)
      rescue Error
        nil
      end

      # The thread that stands in for FormMain's 10 ms TimerBgWorker as far as the queue goes:
      # while the queue holds items it drains it once per tick (RT/webbed/stunned re-read before
      # each poll) and hands each released action to +run+ (RunQueueCommand -> ParseCommand);
      # while it is empty it sleeps on the queue's ConditionVariable. Off Lich's parser (hook)
      # thread: a released command's `#parse` or `#var` dispatch runs script code (its game send
      # no longer waits out roundtime, so an RT-exempt `#queue` item goes out on time). Remix discards a faulted ParseCommand Task
      # (FormMain.cs:3861 R, not awaited); +run+ swallows those, anything else that escapes goes
      # to +report+ and the worker keeps going.
      #
      # Lifetime: the first start happens on a Lich SCRIPT
      # thread, whose ThreadGroup Lich kills with the script (script.rb:2212-2214, 2747-2753),
      # so {#start} moves the thread to ThreadGroup::Default (Lich's own pattern, script.rb:
      # 1982). The loop survives StandardError, ScriptError and SystemStackError (reported; a
      # fault outside a command -- the state read -- then backs off one idle wait); anything
      # else (SignalException, SystemExit, NoMemoryError) ends the thread and the glue's next
      # {#start} (every genie script start and every downstream line) replaces it.
      # +queue+ may be a callable, read on every pass, so a hot reload that rebuilds
      # Lich::Genie.command_queue does not strand the worker on the old one. The thread is named
      # {THREAD_NAME} so it can be told apart in a thread dump.
      class Worker
        # One Remix timer tick (TimerBgWorker.Interval = 10, FormMain.Designer.cs:1409 R).
        TICK_SECONDS = 0.01
        # Thread#name of the worker thread.
        THREAD_NAME = 'genie-command-queue'
        # How long an idle wait lasts before the queue is looked up again (a replaced queue's
        # adds never signal the old one's ConditionVariable).
        IDLE_TIMEOUT = 1.0
        # What the loop reports and survives: everything a released command or a state read can
        # raise short of a signal, an exit or memory exhaustion.
        SURVIVABLE = [StandardError, ScriptError, SystemStackError].freeze

        # @param queue [CommandQueue, #call] the queue, or a callable returning the current one
        # @param state [#call] callable => {State} (HasRoundTime, $webbed, $stunned)
        # @param run [#call] callable(action, owner): RunQueueCommand (owner = {Item#owner})
        # @param report [#call] callable(exception) for a fault +run+ let through
        # @param sleeper [#call] callable(seconds) between ticks (Kernel#sleep)
        # @param idle_timeout [Numeric] seconds per idle wait before the queue is re-read
        def initialize(queue:, state:, run:, report:, sleeper: ->(seconds) { sleep(seconds) }, idle_timeout: IDLE_TIMEOUT)
          @queue_source = CommandQueue.source(queue)
          @state = state
          @run = run
          @report = report
          @sleeper = sleeper
          @idle_timeout = idle_timeout
          @thread = nil
          @start_mutex = Mutex.new
        end

        # One tick's queue work (FormMain.cs:8321-8339 R): the one due `#event` (RunQueueCommand of
        # Events.Poll, ownerless), then the CommandQueue drain.
        # @return [Integer] how many actions were run
        def tick
          queue = @queue_source.call
          event = queue.poll_event
          ran = event.empty? ? 0 : run_one(event, nil)
          ran + queue.drain(@state) { |action, owner| run_one(action, owner) }
        end

        # Start the thread unless it is already running (a dead one is replaced). Cheap when it
        # is alive, so the glue calls it on every script start and downstream line.
        # @return [Thread]
        def start
          @start_mutex.synchronize do
            @thread = nil unless @thread&.alive?
            @thread ||= Thread.new { run_loop }.tap do |thread|
              thread.name = THREAD_NAME
              detach_from_starter(thread)
            end
          end
        end

        # @return [Boolean]
        def alive?
          @thread&.alive? ? true : false
        end

        private

        def run_one(action, owner)
          @run.call(action, owner)
          1
        rescue *SURVIVABLE => e
          report(e)
          1
        end

        # ThreadGroup::Default.add (script.rb:1982 pattern). An enclosed starter group refuses
        # the move (ThreadError): the thread stays there and the next {#start} after that
        # group's death replaces it.
        def detach_from_starter(thread)
          ThreadGroup::Default.add(thread)
        rescue ThreadError
          nil
        end

        def run_loop
          loop do
            queue = @queue_source.call
            next unless queue.wait_for_items(@idle_timeout)

            @sleeper.call(TICK_SECONDS)
            tick
          rescue *SURVIVABLE => e
            report(e)
            @sleeper.call(@idle_timeout) # a fault that repeats every tick reports once per idle wait, not 100/s
          end
        end

        # +report+ itself must not take the loop down.
        def report(error)
          @report.call(error)
        rescue *SURVIVABLE
          nil
        end
      end
    end
  end
end
