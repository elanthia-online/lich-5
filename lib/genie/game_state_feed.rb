# frozen_string_literal: true

module Lich
  module Genie
    # A rate-limited error line for a path that runs on every row (Lich's parser thread,
    # the client-input path): the first few errors are shown, then every Nth with its count,
    # so a persistent failure cannot flood the client.
    class ErrorReport
      # @param label [String] what failed, e.g. "game-state feed"
      # @param emit [#call] gets the text (Lich's respond in the glue)
      # @param first [Integer] errors shown one by one
      # @param every [Integer] after those, every Nth error is shown
      def initialize(label, emit:, first: 3, every: 100)
        @label = label
        @emit = emit
        @first = first
        @every = every
        @count = 0
        @mutex = Mutex.new
      end

      # @return [Integer] errors reported so far (shown or not)
      def count
        @mutex.synchronize { @count }
      end

      # @param error [Exception]
      # @return [void]
      def call(error)
        count = @mutex.synchronize { @count += 1 }
        return unless count <= @first || (count % @every).zero?

        note = if count == @first then " (further #{@label} errors: every #{@every}th shown)"
               elsif count > @first then " (#{count} #{@label} errors so far)"
               else ''
               end
        @emit.call("--- Lich: genie #{@label} error: #{error.message}#{note}")
      rescue StandardError
        nil # the reporter never raises into the path it guards
      end
    end

    # The glue's game-state plumbing, Lich-free so it is spec'd headless: the live feed of
    # every raw server string into {GameState} (a module prepended onto Lich's
    # Script.new_downstream_xml), its start-up replay of Lich's server buffer, and the
    # typed-command tap ($lastcommand/$lastinput for what the user types).
    #
    # Lich calls Script.new_downstream_xml once per raw server string from its parser thread,
    # BEFORE it hands the string's text lines to scripts (games.rb:1136) and before any
    # DownstreamHook runs -- the same point in a row where Remix updates a reserved variable
    # (while it parses the row, ahead of the row's text reaching scripts and #triggers). An
    # exception escaping there would end Lich's parser loop, so the feed contains every
    # StandardError (reported through {ErrorReport}) and always calls on to Lich.
    class GameStateFeed
      # @param game_state [#call] returns the {GameState} to feed (looked up per row: the
      #   process-wide one is rebuilt when the config dir changes)
      # Thread-local set on Lich's game parser thread by the tap (the thread that calls
      # Script.new_downstream_xml): what Lich pushes into a genie script's buffer from that
      # thread is its own strip_xml line of a game row (games.rb:1139-1141), which the engine
      # replaces with Remix's routing (GameState's printed texts).
      READER_KEY = :lich_genie_game_reader
      # Thread-local set while the engine itself hands a Lich command to do_client (a script's
      # `put ,go2 ...`): the typed-command tap must not take it for user input.
      ENGINE_CLIENT_KEY = :lich_genie_engine_client

      # @param report [#call] gets each error the feed and the replay contain
      # @param upstream_report [#call] gets each error the typed-command tap contains
      def initialize(game_state:, report:, upstream_report: report)
        @game_state = game_state
        @report = report
        @upstream_report = upstream_report
        @tap = build_tap
        @installed = {}.compare_by_identity # script classes the tap is prepended onto
        @install_mutex = Mutex.new
        @gate = nil # a gated install's open test ({#install})
        @opened = true
      end

      # The module prepended onto Lich::Common::Script's singleton class (one per feed, so
      # re-prepending it is a no-op).
      # @return [Module]
      attr_reader :tap

      # Feed one raw server string. Never raises.
      # @param line [Object] a String (anything else is ignored)
      # @return [void]
      def feed(line)
        return unless line.is_a?(String) && open?(line)

        @game_state.call.feed(line)
        @last_fed = line # the re-open's replay starts after it ({#unapplied})
      rescue StandardError => e
        @report.call(e)
      end

      # Prepend the live feed onto +script_class+ and replay +buffer+'s snapshot, in ONE
      # critical section of the game state ({GameState#seed}): a row Lich parses meanwhile
      # lands after the replay, and the one row that may be both in the snapshot and on its
      # way to the live feed is applied once. Never raises.
      #
      # Once per class: the feed lives in Lich::Genie, so reloading genie_script.rb (which
      # resets the glue's own flags) does not replay the older buffer over the live state.
      # An install whose replay failed still counts (the tap is in and feeding).
      # @param script_class [Class] Lich::Common::Script
      # @param buffer [#call] returns Lich's server buffer ($_SERVERBUFFER_), oldest first
      # @return [void]
      #
      # Gated (+gate+ given; the glue at Lich load, independent of the first script): the tap goes
      # in at once but feeds nothing while +gate+ is false; on the first row it is true (the engine
      # is on for the logged-in character) the snapshot is replayed then -- the row in flight is
      # in it and applied once -- and +on_open+ runs (the engine start), all on Lich's parser
      # thread. A later ungated install of the same class is a no-op.
      # @param gate [#call, nil] => whether the feed is open
      # @param on_open [#call, nil] run once, right after the gated replay
      def install(script_class, buffer:, gate: nil, on_open: nil)
        @install_mutex.synchronize do
          next if @installed.key?(script_class)

          if gate
            @buffer = buffer
            @on_open = on_open
            @opened = false
            @gate = gate
            script_class.singleton_class.prepend(@tap)
            @installed[script_class] = true
            next
          end
          seed_and_prepend(script_class, buffer)
        end
      end

      # @return [Boolean] whether the feed is open: an ungated install always is; a gated one
      #   opens (replaying the snapshot, then +on_open+) on the first row its gate allows, and is
      #   asked again on every row: a row the gate refuses -- the engine turned off mid-session --
      #   closes it, and the next row it allows opens it again the same way (the replay brings the
      #   capture up to date with the rows Lich parsed while it was closed -- only those: a row the
      #   capture applied before it closed is not applied twice, {#unapplied}). The row being fed
      #   (+line+, already in Lich's buffer) is left out of the replay: it is a row of the open
      #   session, fed live with its changes and texts -- the first #trigger match after a turn-on.
      # @param line [String, nil] the row the parser thread is feeding now
      def open?(line = nil)
        return true if @gate.nil?

        unless @gate.call
          @opened = false # only Lich's parser thread feeds; the next allowed row re-opens
          return false
        end
        return true if @opened

        opened_now = @install_mutex.synchronize do
          next false if @opened

          @opened = true
          replay(@buffer, except: line)
          true
        end
        @on_open&.call if opened_now
        @opened
      rescue StandardError => e
        @report.call(e)
        @opened
      end

      # @param script_class [Class]
      # @return [Boolean] whether {#install} put the tap onto +script_class+
      def installed?(script_class)
        @install_mutex.synchronize { @installed.key?(script_class) }
      end

      # The command the user typed, as Remix's SendText gets it: the client input without its
      # `<c>` prefix and trailing newline; nil for blank input. A Lich command (`,go2 123`,
      # `;kill sc`) counts too: Remix behind Lich does not know it is one -- the user's
      # text goes through its SendText like any command (Game.cs:521-552 R) and only Lich,
      # downstream of it, intercepts it (do_client, global_defs.rb:2256-2274).
      # @param client_string [String] the client input as UpstreamHook hooks see it (do_client
      #   has stripped it)
      # @return [String, nil]
      def self.typed_command(client_string)
        text = client_string.to_s.sub(/\A<c>/, '').chomp
        text.strip.empty? ? nil : text
      end

      # The UpstreamHook body: a typed command is a Remix user-input SendText (Game.cs:521-552
      # R): $lastcommand and $lastinput, then +on_input+ (the glue's trigger-on-input). Skipped
      # for a Lich command the engine itself hands to do_client (ENGINE_CLIENT_KEY: a script's
      # send, recorded by the sender). Returns the input unchanged and never raises
      # (UpstreamHook.run removes a hook that raises).
      #
      # With +post+ (the glue: its trigger worker) that work is handed off, in order with the game
      # rows, instead of running on Lich's client thread: the variable change it raises fires the
      # eval #triggers and its trigger-on-input fires the #triggers, and no #trigger body runs on
      # the client thread. Its faults go to the same report.
      # @param client_string [String]
      # @param on_input [#call, nil] callable(text) for a typed command
      # @param post [#call, nil] callable(&job) running the job elsewhere
      # @return [String] +client_string+
      def upstream(client_string, on_input: nil, post: nil)
        return client_string if Thread.current[ENGINE_CLIENT_KEY]

        text = self.class.typed_command(client_string)
        if text
          job = -> { typed(text, on_input) }
          post ? post.call(&job) : job.call
        end
        client_string
      rescue StandardError => e
        @upstream_report.call(e)
        client_string
      end

      private

      # {#upstream}'s work for one typed command. Never raises.
      def typed(text, on_input)
        @game_state.call.sent(text, user_input: true)
        on_input&.call(text)
      rescue StandardError => e
        @upstream_report.call(e)
      end

      # The ungated install: prepend and replay in one critical section of the game state.
      def seed_and_prepend(script_class, buffer)
        tap = @tap
        installed = @installed
        @game_state.call.seed do
          script_class.singleton_class.prepend(tap)
          installed[script_class] = true
          Array(buffer.call&.dup)
        end
      rescue StandardError => e
        @report.call(e)
      end

      # The gated install's replay, on Lich's parser thread inside the feed of row +except+ (the
      # tap is in already): the buffer's rows the capture has not applied ({#unapplied}) but that
      # one, which the feed applies live next.
      def replay(buffer, except: nil)
        @game_state.call.seed do
          rows = unapplied(Array(buffer.call&.dup)).reject { |row| row.equal?(except) }
          @last_fed = rows.last unless rows.empty?
          rows
        end
      rescue StandardError => e
        @report.call(e)
      end

      # The rows of +rows+ (Lich's buffer, oldest first) the capture has not applied: those after
      # the last row it applied (by identity -- Lich pushes into its buffer the very String it
      # feeds, games.rb:1001, 1136), or all of them when that row is not among them: the first open,
      # or a buffer that has dropped it since (every row left is newer). So a re-open after a
      # turn-off applies just the rows Lich parsed while the feed was closed.
      def unapplied(rows)
        last = @last_fed
        at = last && rows.rindex { |row| row.equal?(last) }
        at ? rows[(at + 1)..] : rows
      end

      def build_tap
        feed = self
        Module.new do
          define_method(:new_downstream_xml) do |line|
            Thread.current[GameStateFeed::READER_KEY] = true
            feed.feed(line)
            super(line)
          end
        end
      end
    end
  end
end
