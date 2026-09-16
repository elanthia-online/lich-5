# frozen_string_literal: true

module Lich
  module Common
    # The built-in +;command+ table.
    #
    # Lifted out of do_client in global_defs.rb, which had grown to 462 lines
    # of one if/elsif chain. Each branch is now a registered entry: a pattern,
    # an optional game gate, and a handler that receives the MatchData.
    #
    # == Order is load-bearing
    #
    # Registration order IS match order, and the first match wins. This is not
    # a hash lookup and must not become one: several patterns overlap, and the
    # only reason the narrower one is reachable is that it is registered
    # first. The pairs that matter:
    #
    #   ;debuglogs          exact, before the \b invalid-argument catch
    #   ;l5u <args>         before the bare ;l5u that answers --help
    #   ;force <name> <a>   before ;force <name>, which would drop the args
    #
    # Those three are the whole list. ;execname/;en and ;lt look like they
    # belong here and do not: the ;exec pattern requires a space (or "q" then
    # a space) straight after e/exec so it cannot match "en job ..." at all,
    # and the ;list pattern cannot match "lt". Both route correctly wherever
    # they sit. Noted so the real constraints are not diluted by imagined
    # ones.
    #
    # and every entry here comes before do_client's fallback, which treats an
    # unmatched command as a script name. Adding an entry to the end is safe;
    # reordering is not. spec/lib/do_client_spec.rb pins these overlaps.
    #
    # == Handlers take their MatchData
    #
    # A handler is passed the MatchData for its own pattern rather than
    # reading $1/$2. Those globals are reset by any later match -- including
    # one run inside an innocuous-looking call such as String#gsub -- which
    # makes them a standing hazard in a file this size. Passing the match
    # explicitly removes the class of bug rather than avoiding it case by
    # case.
    module ClientCommands
      # One registered command.
      #
      # @!attribute pattern
      #   @return [Regexp] matched against the command text (the +;+ stripped)
      # @!attribute game
      #   @return [Symbol, nil] +:gs+ or +:dr+ to gate on the current game,
      #     nil to run for any game
      # @!attribute handler
      #   @return [Proc] called with the MatchData
      Command = Struct.new(:pattern, :game, :handler)

      # Serializes {ClientCommands.define}. Registration mutates one shared
      # staging slot; dispatch only reads the frozen published array and so
      # needs no lock.
      LOCK = Mutex.new

      # The uniform display toggles: read the current value, negate it, let an
      # explicit true/false argument override, report, write back. Six
      # branches that differed only in accessor and message, so they are a
      # table rather than six near-identical bodies.
      #
      # Ordering note: these are registered in the same relative order the
      # if/elsif chain had them. None of the six overlap each other, but
      # ;display roomid (DR) sits between uid and exits in the original and is
      # registered separately below to keep that position.
      DISPLAY_TOGGLES = [
        ['lichid',      :display_lichid,      'Lich ID#s'],
        ['uid',         :display_uid,         'RealID#s'],
        ['exits?',      :display_exits,       'Room Exits of non-StringProc/Obvious exits'],
        ['stringprocs?', :display_stringprocs, 'Room Exits of StringProcs'],
        ['roomlinks?',  :display_room_links,  'room exits as clickable command links'],
        ['roommono',    :display_room_mono,   'room information in monospace font']
      ].freeze

      class << self
        # Every registered command, in match order.
        #
        # This is the PUBLISHED table. define replaces it wholesale; nothing
        # else mutates it, so a dispatch never sees a half-built table and a
        # reload never leaves stale handlers in front of new ones.
        #
        # @return [Array<Command>]
        def commands
          @commands ||= [].freeze
        end

        # Registers a table of commands, replacing whatever was published
        # before.
        #
        # Built-ins are registered inside one of these blocks so that
        # re-running the file -- which is exactly what +;hmr client_commands+
        # does, since HMR calls load() and load() re-executes the body --
        # rebuilds the table instead of appending a second copy behind the
        # first. Appending was the original behavior and it silently kept the
        # OLD handlers live: they matched first, so an edited built-in was
        # loaded, doubled the table, and never ran.
        #
        # The new table is published only once the block finishes. A raise
        # part-way through leaves the previous table in place rather than a
        # truncated one.
        #
        # Serialized, because @staging is one class-level slot and command
        # re-reads it on every call. Two threads registering at once -- two
        # frontends each running ";hmr client_commands", since main.rb runs
        # a thread per attached detachable client -- would otherwise have
        # the second define's @staging = [] redirect BOTH threads' command
        # calls onto its array, and the later publish would drop the other
        # thread's registrations with no exception raised. Worse, one
        # interleaving publishes an EMPTY table: the inner ensure restores
        # @staging before the outer thread reads it, so every ";" command
        # then falls through to Script.start as a script name until the next
        # reload. Both reproduced; DetachableClientRegistry next door guards
        # the same threading model the same way.
        #
        # Reentrant by hand rather than with a plain Mutex: define nests
        # (that is what +previous+ is for), and Ruby's Mutex is not
        # reentrant, so a nested define on one thread would deadlock.
        #
        # @yield registers commands with +command+
        # @return [void]
        def define(&block)
          return define_unlocked(&block) if @define_owner == Thread.current

          LOCK.synchronize do
            @define_owner = Thread.current
            begin
              define_unlocked(&block)
            ensure
              @define_owner = nil
            end
          end
        end

        # Registers one command. Order of registration is order of matching.
        #
        # @param pattern [Regexp]
        # @param game [Symbol, nil] :gs or :dr to gate on the current game
        # @yieldparam match [MatchData] the match for this pattern
        # @yieldparam cmd [String] the whole command text. Needed by the
        #   handlers whose pattern is only a prefix test (;force, ;send):
        #   match[0] is the matched span alone, so "force foo bar" matches
        #   only "force foo" and the arguments are not in the MatchData.
        # @return [void]
        # @raise [RuntimeError] when called outside a {define} block
        #
        # Callable only from the thread inside {define}: {command} appends to
        # the staging array that define set up, and define holds {LOCK} for
        # the duration, so no other thread is staging at the same time.
        def command(pattern, game: nil, &handler)
          raise 'ClientCommands.command must be called inside ClientCommands.define' if @staging.nil?

          @staging << Command.new(pattern, game, handler).freeze
        end

        # Runs the first command whose pattern matches and whose game gate
        # passes.
        #
        # @param cmd [String] the command text, with the lich char stripped
        # @return [Boolean] true when a command handled it, false when the
        #   caller should fall back to starting a script
        def dispatch(cmd)
          commands.each do |c|
            next unless game_matches?(c.game)
            next unless (match = c.pattern.match(cmd))

            c.handler.call(match, cmd)
            return true
          end
          false
        end

        # The staging/publish half of {define}, with the lock already held.
        #
        # @yield registers commands with +command+
        # @return [void]
        def define_unlocked
          previous = @staging
          @staging = []
          yield
          @commands = @staging.freeze
        ensure
          @staging = previous
        end
        private :define_unlocked

        # @param gate [Symbol, nil]
        # @return [Boolean]
        def game_matches?(gate)
          case gate
          when nil then true
          when :gs then XMLData.game.to_s.start_with?('GS')
          when :dr then XMLData.game.to_s.start_with?('DR')
          else false
          end
        end

        # The built-in help listing. Long, but it is one flat sequence of
        # respond calls with two game-dependent sections; leaving it inline
        # in a handler would have buried the rest of the table.
        def help
          respond
          respond "Lich v#{LICH_VERSION}"
          respond
          respond 'built-in commands:'
          respond "   #{$clean_lich_char}<script name>             start a script"
          respond "   #{$clean_lich_char}force <script name>       start a script even if it's already running"
          respond "   #{$clean_lich_char}pause <script name>       pause a script"
          respond "   #{$clean_lich_char}p <script name>           ''"
          respond "   #{$clean_lich_char}unpause <script name>     unpause a script"
          respond "   #{$clean_lich_char}u <script name>           ''"
          respond "   #{$clean_lich_char}kill <script name>        kill a script"
          respond "   #{$clean_lich_char}k <script name>           ''"
          respond "   #{$clean_lich_char}pause                     pause the most recently started script that isn't aready paused"
          respond "   #{$clean_lich_char}p                         ''"
          respond "   #{$clean_lich_char}unpause                   unpause the most recently started script that is paused"
          respond "   #{$clean_lich_char}u                         ''"
          respond "   #{$clean_lich_char}kill                      kill the most recently started script"
          respond "   #{$clean_lich_char}k                         ''"
          respond "   #{$clean_lich_char}list                      show running scripts (except hidden ones)"
          respond "   #{$clean_lich_char}l                         ''"
          respond "   #{$clean_lich_char}pause all                 pause all scripts"
          respond "   #{$clean_lich_char}pa                        ''"
          respond "   #{$clean_lich_char}unpause all               unpause all scripts"
          respond "   #{$clean_lich_char}ua                        ''"
          respond "   #{$clean_lich_char}kill all                  kill all scripts"
          respond "   #{$clean_lich_char}ka                        ''"
          respond "   #{$clean_lich_char}kd                        kill all scripts, including protected and hidden scripts"
          respond "   #{$clean_lich_char}list all                  show all running scripts"
          respond "   #{$clean_lich_char}la                        ''"
          respond
          respond "   #{$clean_lich_char}exec <code>               executes the code as if it was in a script"
          respond "   #{$clean_lich_char}e <code>                  ''"
          respond "   #{$clean_lich_char}execq <code>              same as #{$clean_lich_char}exec but without the script active and exited messages"
          respond "   #{$clean_lich_char}eq <code>                 ''"
          respond "   #{$clean_lich_char}execname <name> <code>    creates named exec (name#) and then executes the code as if it was in a script"
          respond
          if (RUBY_VERSION =~ /^2\.[012]\./)
            respond "   #{$clean_lich_char}trust <script name>       let the script do whatever it wants"
            respond "   #{$clean_lich_char}distrust <script name>    restrict the script from doing things that might harm your computer"
            respond "   #{$clean_lich_char}list trusted              show what scripts are trusted"
            respond "   #{$clean_lich_char}lt                        ''"
            respond
          end
          respond "   #{$clean_lich_char}send <line>               send a line to all scripts as if it came from the game"
          respond "   #{$clean_lich_char}send to <script> <line>   send a line to a specific script"
          respond
          respond "   #{$clean_lich_char}set <variable> [on|off]   set a global toggle variable on or off"
          respond "   #{$clean_lich_char}debuglogs                 show debug log retention setting"
          respond "   #{$clean_lich_char}debuglogs <number>        set how many debug logs to keep (default: #{Lich::MAX_DEBUG_LOGS_DEFAULT})"
          respond
          respond "   #{$clean_lich_char}lich5-update --<command>  Lich5 ecosystem management "
          respond "                              see #{$clean_lich_char}lich5-update --help"
          respond "   #{$clean_lich_char}hmr <regex filepath>      Hot module reload a Ruby or Lich5 file without relogging, uses Regular Expression matching"
          if XMLData.game =~ /^GS/
            respond
            respond "   #{$clean_lich_char}infomon sync              sends all the various commands to resync character data for infomon (fixskill)"
            respond "   #{$clean_lich_char}infomon reset             resets entire character infomon db table and then syncs data (fixprof)"
            respond "   #{$clean_lich_char}infomon effects           toggle display of effect durations"
            respond "   #{$clean_lich_char}infomon show              shows current Infomon values for character"
            respond "   #{$clean_lich_char}infomon show full         same, including values that are zero"
            respond "   #{$clean_lich_char}sk help                   show information on modifying self-knowledge spells to be known"
          elsif XMLData.game =~ /^DR/
            respond "   #{$clean_lich_char}display flaguid           toggle hiding the game's inline RealID in the Room Title (now optional; UIDs come from <nav>)"
            respond "   #{$clean_lich_char}display roomid <where>    where to show room id/RealID: title (room name line), line (below-room line), or both"
          end
          respond "   #{$clean_lich_char}display lichid            toggle display of Lich Map# when displaying room information"
          respond "   #{$clean_lich_char}display uid               toggle display of RealID Map# when displaying room information"
          respond "   #{$clean_lich_char}display exits             toggle display of non-StringProc/Obvious exits known for room in mapdb"
          respond "   #{$clean_lich_char}display stringprocs       toggle display of StringProc exits known for room in mapdb if timeto is valid"
          respond "   #{$clean_lich_char}display roomlinks         toggle rendering of room exits as clickable command links vs plain text"
          respond "   #{$clean_lich_char}display roommono          toggle rendering of Lich room information in monospace font vs game font"
          if XMLData.game =~ /^DR/
            respond "   #{$clean_lich_char}display expgains          toggle real-time experience gain reporting (DragonRealms only)"
            respond "   #{$clean_lich_char}display inlineexp         toggle inline exp display in EXP window (DragonRealms only)"
            respond "   #{$clean_lich_char}display exp-status        show experience monitor status (DragonRealms only)"
            respond "   #{$clean_lich_char}banks                     show your bank balances (DragonRealms only)"
            respond "   #{$clean_lich_char}banks all                 show bank balances for all characters (DragonRealms only)"
            respond "   #{$clean_lich_char}banks reset               clear your bank data (DragonRealms only)"
            respond "   #{$clean_lich_char}banks reset all           clear all characters' bank data (DragonRealms only)"
          end
          respond
          respond 'If you liked this help message, you might also enjoy:'
          respond "   #{$clean_lich_char}lnet help" if defined?(LNet)
          respond "   #{$clean_lich_char}go2 help"
          respond "   #{$clean_lich_char}repository help"
          respond "   #{$clean_lich_char}alias help"
          respond "   #{$clean_lich_char}vars help"
          respond "   #{$clean_lich_char}autostart help"
          respond
        end

        # Reads a toggle's next value: the negation of its current value,
        # unless an explicit true/false argument overrides it.
        #
        # The comparison is case-INSENSITIVE, which the original branches
        # were not. Their patterns carry /i, so an uppercase argument was
        # captured and then matched none of the lowercase literals, falling
        # through to the negation: ";display lichid TRUE" turned the flag
        # OFF when it was already on. An explicit argument now means what it
        # says whatever its case.
        #
        # @param current [Boolean] the toggle's present value
        # @param argument [String, nil] "true", "false", "on", "off" or nil
        # @return [Boolean]
        def toggle_value(current, argument)
          case argument&.downcase
          when 'true', 'on' then true
          when 'false', 'off' then false
          else !current
          end
        end
      end
    end
  end
end
