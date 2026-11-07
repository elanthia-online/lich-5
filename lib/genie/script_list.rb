# frozen_string_literal: true

module Lich
  module Genie
    # Remix's two script lists (FormMain.cs:3182-3183 R): m_oScriptList, the scripts every walker
    # sees -- `#script abort|pause|resume|pauseorresume|reload` (FormMain.cs:5783-6080 R), the
    # dupe check (LoadScript, FormMain.cs:3401-3426 R), ParseTriggers, TriggerVariableChanged,
    # TriggerPrompt / TriggerMove / SetRoundTime, TickScripts and SetScriptListVariable -- and
    # m_oScriptListNew, where ClassCommand_RunScript puts a launched script before running its
    # first rows synchronously (FormMain.cs:4678-4714 R). The timer's AddScripts moves the new
    # ones into the list at the END of the tick (FormMain.cs:3809-3835, 8345 R), so a script's
    # first rows -- and the rest of its launcher's run -- happen while it is not listed: its own
    # `put #script abort all except <other>` (>= 12 tester openers) or `#script pause <self>` find
    # nothing to act on, a `#parse` or game line misses it, and $scriptlist does not name it yet.
    #
    # Lich has no tick. The end of a tick is modelled deterministically as the end of a script's
    # RUN (its first wait, or its end; {#run_ended}) -- but not of a first run nested in its
    # launcher's run, which Remix runs inside the launcher's row (flow t170): a launched script
    # is listed once its own first run is over AND the run of the script that launched it is
    # over AND that launcher is listed itself (no launcher -- a typed command, a queued command,
    # a #trigger body off a script thread; a #trigger body on a script's thread has that script
    # as its launcher -- once its own first run is over). So every script launched inside one
    # synchronous chain of first runs is listed together, in launch order, when the outermost
    # run ends, as Remix's AddScripts lists all of m_oScriptListNew at once: a grandchild is
    # never listed before its ancestors (flow t166). A pending launcher that
    # finishes hands its pending children to its own launcher. Until then the host freezes a
    # script ({#frozen?}: a TickScript never comes for an unlisted script) and drops what arrives
    # for it. The same run ends store $scriptlist ({#value}, SetScriptListVariable,
    # FormMain.cs:4516-4541, 8349-8351 R) when the list changed since (m_bScriptListUpdated: a
    # script listed, finished or aborted, paused or resumed), so a script that aborts another
    # reads the old value until its own run ends (flow t163).
    #
    # Host-agnostic and thread-safe (one mutex): the glue's handles are GenieScripts, the flow
    # harness's its own entries. A handle answers #genie_file_name (Script.FileName: the
    # lowercased launch name with its ".cmd", the dupe-check key and the $scriptlist name,
    # {ScriptLaunch.list_name}) and may answer #genie_listed (told after it is listed, outside
    # the lock).
    class ScriptList
      # One m_oScriptListNew entry. +ran+: its first run is over; +released+: its launcher's run
      # is over and the launcher is listed (or it has none); +depth+: how many synchronous first
      # runs it is nested in.
      Pending = Struct.new(:script, :launcher, :ran, :released, :depth, keyword_init: true)

      # A first run nested this deep inside other first runs is refused ({#launch_depth}): Remix
      # recurses until its stack overflows (a script relaunching itself before its first wait is
      # never listed, so the dupe check never aborts it). Shares the nested-dispatch cap's limit
      # (DispatchDepth::LIMIT; a decided divergence).
      LIMIT = DispatchDepth::LIMIT

      def initialize
        @mutex = Mutex.new
        @signal = ConditionVariable.new # wakes {#wait_first_run}
        @listed = [] # m_oScriptList, in AddScripts order
        @pending = [] # m_oScriptListNew
        @updated = false # m_bScriptListUpdated
        @value = 'none' # the stored $scriptlist ("none" before any tick end, as SetScriptListVariable's empty case)
      end

      # ClassCommand_RunScript's m_oScriptListNew.Add (FormMain.cs:4691-4699 R). A script already
      # pending or listed is left as it is.
      # @param script [Object] the host handle
      # @param launcher [Object, nil] the handle of the script whose row launched it
      # @return [void]
      def launched(script, launcher: nil)
        @mutex.synchronize do
          next if listed_locked?(script) || pending_entry(script)

          @pending << Pending.new(script: script, launcher: launcher, ran: false, released: launcher.nil?,
                                  depth: depth_under(launcher) + 1)
        end
      end

      # @param launcher [Object, nil]
      # @return [Integer] the first-run nesting a script launched by +launcher+ now would get (1 =
      #   not nested); above {LIMIT} the host refuses the launch
      def launch_depth(launcher)
        @mutex.synchronize { depth_under(launcher) + 1 }
      end

      # The end of +script+'s run -- it is about to wait, or it ended -- which is a tick end here:
      # its first run is over (waking {#wait_first_run}), the scripts it launched are released if
      # it is listed (a pending script's are released when it is listed itself), the ready ones
      # are listed (AddScripts), and $scriptlist is stored if the list changed
      # (SetScriptListVariable). Not a tick end, though, for a first run nested in its launcher's
      # run (not released yet): that run happens inside the launcher's row in Remix, so nothing is
      # stored before the launcher's own run ends (flow t170). Newly listed
      # handles get #genie_listed.
      # @param script [Object]
      # @return [Boolean] whether the "scriptlist" variable change is due (the host raises it)
      def run_ended(script)
        listed_now, due = @mutex.synchronize do
          entry = pending_entry(script)
          if entry && !entry.ran
            entry.ran = true
            @signal.broadcast
          end
          release_children(script) unless entry
          # a first run nested in its launcher's still-running run is not a tick end: Remix runs
          # it inside the launcher's row, SetScriptListVariable waits for the tick (flow t170)
          inner = entry && !entry.released
          [commit_ready, inner ? false : tick_end_locked]
        end
        notify_listed(listed_now)
        due
      end

      # AbortScript / the script's end (ScriptDone + EventStatusChanged(finished), Script.cs:
      # 1137-1176, 1760-1767 R): gone from both lists (walkers skip a done script; RemoveExited-
      # Scripts, FormMain.cs:3229-3270 R), the list changed, a first-run waiter woken. The scripts
      # it launched are released if it was listed; a pending script's pending children go to its
      # own launcher instead (in Remix they are listed with it at the tick end). Idempotent. Does
      # NOT store $scriptlist: that waits for a tick end.
      # @param script [Object]
      # @return [void]
      def finished(script)
        listed_now = @mutex.synchronize do
          gone = pending_entry(script)
          known = @listed.reject! { |listed| listed.equal?(script) } || @pending.reject! { |entry| entry.script.equal?(script) }
          @updated = true if known
          @signal.broadcast
          gone ? adopt_children(gone) : release_children(script)
          commit_ready
        end
        notify_listed(listed_now)
      end

      # Script_EventStatusChanged for a pause or resume (FormMain.cs:3481-3483 R).
      # @return [void]
      def changed!
        @mutex.synchronize { @updated = true }
      end

      # A tick end with no script run ending (a #trigger body's or a typed `#script`): store
      # $scriptlist if the list changed.
      # @return [Boolean] whether the "scriptlist" variable change is due
      def tick_end
        @mutex.synchronize { tick_end_locked }
      end

      # The tick end after a change made by +#script+ or a launch: at once on a thread that runs no
      # script (Lich's parser thread, the queue worker, the client), else at the end of the run of
      # the script whose thread made it ({#run_ended}; ParseDispatch.owner).
      # @return [Boolean] whether the "scriptlist" variable change is due now
      def tick_end_outside_script
        ParseDispatch.owner ? false : tick_end
      end

      # @return [String] the stored $scriptlist
      def value
        @mutex.synchronize { @value }
      end

      # @return [Array<Object>] m_oScriptList, in order (a copy)
      def listed
        @mutex.synchronize { @listed.dup }
      end

      # @return [Boolean]
      def listed?(script)
        @mutex.synchronize { listed_locked?(script) }
      end

      # @return [Boolean] whether +script+'s first run is over but it is not listed yet: no tick
      #   reaches it (TickScripts walks the list, FormMain.cs:3185-3203 R), so it resumes nothing
      def frozen?(script)
        @mutex.synchronize { pending_entry(script)&.ran ? true : false }
      end

      # LoadScript's dupe check (FormMain.cs:3401-3426 R): the LISTED scripts whose FileName equals
      # +file_name+ (ordinal; a pending copy is not walked, so two launches in one run both start).
      # @param file_name [String]
      # @return [Array<Object>]
      def duplicates(file_name)
        @mutex.synchronize { @listed.select { |script| script.genie_file_name == file_name } }
      end

      # Block until +script+'s first run is over (or it finished, or it is not pending), at most
      # +timeout+ seconds: the launcher side of the synchronous first run
      # (ClassCommand_RunScript -> oScript.RunScript(), FormMain.cs:4710-4713 R).
      # @param script [Object]
      # @param timeout [Numeric]
      # @return [Boolean] false when the timeout ran out first
      def wait_first_run(script, timeout:)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        @mutex.synchronize do
          loop do
            entry = pending_entry(script)
            return true if entry.nil? || entry.ran

            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            return false unless remaining.positive?

            @signal.wait(@mutex, remaining)
          end
        end
      end

      private

      # Handles compare by identity (a host handle may define == by value).
      def listed_locked?(script)
        @listed.any? { |listed| listed.equal?(script) }
      end

      def pending_entry(script)
        @pending.find { |entry| entry.script.equal?(script) }
      end

      # The nesting of a script launched by +launcher+: one under the launcher's when the launcher
      # is itself still in its first run, else none.
      def depth_under(launcher)
        entry = launcher && pending_entry(launcher)
        entry && !entry.ran ? entry.depth : 0
      end

      def release_children(script)
        @pending.each { |entry| entry.released = true if entry.launcher.equal?(script) }
      end

      # The pending children of +gone+ (a pending entry just removed) now wait for its launcher.
      def adopt_children(gone)
        @pending.each do |entry|
          next unless entry.launcher.equal?(gone.script)

          entry.launcher = gone.launcher
          entry.released = gone.released
        end
      end

      # AddScripts: the ready entries, in m_oScriptListNew order, in one pass -- listing an entry
      # releases its children, which come after it, so a whole ready chain is listed together.
      # @return [Array<Object>] listed now
      def commit_ready
        ready = []
        @pending.each do |entry|
          next unless entry.ran && entry.released

          ready << entry
          release_children(entry.script)
        end
        return [] if ready.empty?

        @pending.reject! { |entry| ready.any? { |done| done.equal?(entry) } }
        scripts = ready.map(&:script)
        @listed.concat(scripts)
        @updated = true
        scripts
      end

      # SetScriptListVariable (FormMain.cs:4516-4541 R), only when the list changed.
      def tick_end_locked
        return false unless @updated

        names = @listed.map { |script| ScriptLaunch.list_name(script.genie_file_name) }
        @value = names.empty? ? 'none' : names.join('|')
        @updated = false
        true
      end

      def notify_listed(scripts)
        scripts.each { |script| script.genie_listed if script.respond_to?(:genie_listed) }
      end
    end
  end
end
