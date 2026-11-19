# frozen_string_literal: true

module Lich
  module Genie
    # `#goto <room>`: Remix's AutoMapper goto arm (AutoMapper.cs:1140-1205, 1595-1609 R),
    # with the walk itself done by the host (the Lich glue: DRCT.walk_to, go2 under the hood, in a
    # hidden Lich script of its own) in place of the automapper.cmd script Remix launches
    # (`.automapper <path>`). So, as in Remix:
    #
    #   * the command returns at once -- the script goes on with its next row; no walk holds it
    #     (no runaway kill after 5 s, its actions keep firing, a queued `send #goto` no longer
    #     blocks the command queue);
    #   * "#goto <arg>" is echoed, $destination is set ("$destination" raised) and "DESTINATION
    #     FOUND" is `#parse`d -- or, for a room it cannot find, Remix's not-found echo,
    #     $destination 0 and "DESTINATION NOT FOUND";
    #   * a walk starts only when the current room is known and is not the destination
    #     (WalkToNode: no m_LastNode, or an empty path, launches nothing);
    #   * while it walks, "automapper" is in the script list ($scriptlist; a `#goto` launched in a
    #     script's row is listed at that run's end, like the automapper.cmd that row launches),
    #     and another `#goto` replaces it (abortdupescript); `#script abort automapper|all`
    #     stops it;
    #   * at its end it `#parse`s automapper.cmd's result lines (automapper.cmd DEAD.DONE /
    #     MOVE.FAILED): "YOU HAVE ARRIVED!" then "AUTOMAPPER: YOU HAVE ARRIVED!", or "MOVE
    #     FAILED" then "AUTOMAPPER: MOVEMENT FAILED!" -- to the #triggers and every listed
    #     script -- and leaves the list ("scriptlist" raised at that tick end).
    #
    # Not modelled (open-items.md U5, L5): Genie's note names (`#goto bank`: the Lich map has no
    # Genie notes, so a non-numeric room is "not found"), automapper.cmd's own retries and
    # `#mapper reset` / `#goto $destination` restart after three failures, and pausing the walk.
    module GotoWalk
      # automapper.cmd's Script.FileName (the $scriptlist name and the dupe-check key).
      FILE_NAME = 'automapper.cmd'
      # The plugin's Name (AutoMapper.cs:94-100 R), in its echo lines.
      NAME = 'AutoMapper'
      ARRIVED = ['YOU HAVE ARRIVED!', 'AUTOMAPPER: YOU HAVE ARRIVED!'].freeze
      FAILED = ['MOVE FAILED', 'AUTOMAPPER: MOVEMENT FAILED!'].freeze

      # A walk in progress as a {ScriptList} handle (the automapper.cmd it stands for). The host's
      # runner (what +spawn+ returned) is attached once it exists; an abort that comes first stops
      # it as soon as it is attached, and the walk body checks {#aborted?} before it starts
      # (so no abort is lost in the start window).
      class Handle
        # @return [String]
        attr_reader :genie_file_name

        # @param stop [#call] callable(runner) stops the walk (the host's runner and what it started)
        def initialize(stop)
          @genie_file_name = FILE_NAME
          @stop = stop
          @aborted = false
          @runner = nil
          @mutex = Mutex.new
        end

        # @return [String] ScriptName ("automapper"), what `#script abort <name>` matches
        def name
          ScriptLaunch.script_name(@genie_file_name)
        end

        # Script.AbortScript: the walk stops, without a result line.
        # @return [void]
        def genie_abort
          runner = @mutex.synchronize do
            @aborted = true
            @runner
          end
          @stop.call(runner) if runner
        end

        # The host's runner of this walk, once started; stopped at once when the walk was aborted
        # before it.
        # @param runner [Object]
        # @return [void]
        def attach(runner)
          aborted = @mutex.synchronize do
            @runner = runner
            @aborted
          end
          @stop.call(runner) if aborted
        end

        # @return [Boolean]
        def aborted?
          @mutex.synchronize { @aborted }
        end
      end

      # The host's side of a walk.
      #   resolve: callable(arg) => the walk target for a Genie room id, nil when not found
      #   here:    callable => the current room's target, nil when the location is unknown
      #   walk:    callable(target) => true when it arrived (blocking; run inside +spawn+)
      #   spawn:   callable(&block) => starts the block as the walk's runner (in the glue a hidden
      #            Lich script, so the walk has a Script.current), returns the runner, nil when it
      #            could not start
      #   stop:    callable(runner) -- stops the runner and what it started (never the caller's own
      #            runner: a #trigger on a result line that runs `#goto` runs on the walk's thread)
      #   echo:    callable(text) -- the plugin's EchoText (main window, never parsed)
      #   set_var: callable(name, value) -- set_GlobalVariable (stores and raises "$name")
      #   parse:   callable(text) -- ParseText (ParseTriggers(text, false): #triggers + scripts)
      #   list:    the {ScriptList}; abort_dupe: abortdupescript;
      #   changed: callable -- the "scriptlist" change of a tick end ({ScriptList#tick_end})
      Host = Struct.new(:resolve, :here, :walk, :spawn, :stop, :echo, :set_var, :parse, :list, :abort_dupe, :changed,
                        keyword_init: true)

      module_function

      # The goto arm for +arg+.
      # @param arg [String] sArg: the room argument as typed after the keyword's first space, inner
      #   spaces kept (AutoMapper.cs:955-965 R; echoed as "#goto " + sArg, AutoMapper.cs:1182 R)
      # @param host [Host]
      # @param launcher [Object, nil] the script whose row ran `#goto` (nil: a #trigger body off
      #   any script, a queued or typed command)
      # @return [Handle, nil] the walk started, if any
      def go(arg, host:, launcher: nil)
        arg = arg.to_s
        if arg.empty?
          host.echo.call("[#{NAME}] Goto - please specify a room id to travel to.")
          host.set_var.call('destination', '0')
          return nil
        end

        id = node_id(arg)
        # m_Nodes.Find(iNodeID): the PARSED id ("012", "+12", " 12" find node 12)
        target = id.positive? ? host.resolve.call(id.to_s) : nil
        return not_found(arg, id, host) if target.nil?

        host.echo.call("#goto #{arg}")
        host.set_var.call('destination', id.to_s)
        host.parse.call('DESTINATION FOUND')
        walk_to_node(target, host, launcher)
      end

      # The node id the goto arm reads: int.TryParse of an argument of at most 5 characters
      # (AutoMapper.cs:1149-1159 R), else 0 (Genie would then look the argument up as a note).
      # @param arg [String]
      # @return [Integer]
      def node_id(arg)
        return 0 if arg.length > 5

        Numeric.net_int32(arg) || 0
      end

      # AutoMapper.cs:1186-1199 R.
      def not_found(arg, id, host)
        host.echo.call(if id.positive?
                         "[#{NAME}] Destination ID ##{id} not found - your current location is unknown."
                       else
                         "[#{NAME}] Destination ID \"#{arg}\" not found."
                       end)
        host.set_var.call('destination', '0')
        host.parse.call('DESTINATION NOT FOUND')
        nil
      end
      private_class_method :not_found

      # WalkToNode (AutoMapper.cs:1595-1609 R): nothing when the location is unknown or the path
      # is empty (already there); else the walk, as the `.automapper` launch.
      # @return [Handle, nil]
      def walk_to_node(target, host, launcher)
        here = host.here.call
        return nil if here.nil? || here == target

        host.list.duplicates(FILE_NAME).each(&:genie_abort) if host.abort_dupe
        handle = Handle.new(host.stop)
        host.list.launched(handle, launcher: launcher)
        host.changed.call if host.list.run_ended(handle) # its first run is over at once
        runner = host.spawn.call { walk(target, handle, host) }
        runner ? handle.attach(runner) : finish(handle, host) # a runner that never started
        handle
      end
      private_class_method :walk_to_node

      # The walk's body (on the host's runner): nothing when the walk was aborted before it began
      # else the host's walk, then automapper.cmd's result lines -- each only while the walk
      # is not aborted (a #trigger on "YOU HAVE ARRIVED!" that runs `#goto` aborts it: the second
      # line is not parsed, as the next row of an aborted automapper.cmd never runs) --, then the
      # script list's tick end.
      def walk(target, handle, host)
        return if handle.aborted?

        lines = host.walk.call(target) ? ARRIVED : FAILED
        lines.each do |line|
          break if handle.aborted?

          host.parse.call(line)
        end
      ensure
        finish(handle, host)
      end

      # The walk leaves the list; "scriptlist" at that tick end.
      def finish(handle, host)
        host.list.finished(handle)
        host.changed.call if host.list.tick_end
      end
      private_class_method :finish
    end
  end
end
