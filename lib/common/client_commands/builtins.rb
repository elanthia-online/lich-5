# frozen_string_literal: true

require File.join(LIB_DIR, 'common', 'client_commands.rb')

# The built-in ;command table, registered in match order.
#
# REGISTRATION ORDER IS MATCH ORDER. Several patterns overlap and the narrower
# one is only reachable because it is registered first; the module doc in
# client_commands.rb lists the pairs, and spec/lib/do_client_spec.rb pins them.
# Append freely, reorder only with a reason.
#
# Each body is a transcription of the corresponding branch of the if/elsif
# chain that used to live in do_client, with two mechanical changes: captures
# come from the handler's MatchData argument rather than $1/$2, and the six
# uniform display toggles are driven from a table instead of six near-identical
# bodies.
module Lich
  module Common
    module ClientCommands
      define do
        # ---- script control ---------------------------------------------

        command(/^k$|^kill$|^stop$/) do
          if Script.running.empty?
            respond '--- Lich: no scripts to kill'
          else
            Script.running.last.kill
          end
        end

        command(/^p$|^pause$/) do
          if (s = Script.running.reverse.find { |s_check| !s_check.paused? })
            s.pause
          else
            respond '--- Lich: no scripts to pause'
          end
        end

        command(/^u$|^unpause$/) do
          if (s = Script.running.reverse.find(&:paused?))
            s.unpause
          else
            respond '--- Lich: no scripts to unpause'
          end
        end

        command(/^ka$|^kill\s?all$|^stop\s?all$/) do
          respond('--- Lich: no scripts to kill') if Script.kill_all.zero?
        end

        command(/^kd$/) do
          respond('--- Lich: no scripts to kill') if Script.kill_all(:force => true).zero?
        end

        command(/^pa$|^pause\s?all$/) do
          targets = Script.running.find_all { |s| !s.paused? && !s.no_pause_all }
          targets.each(&:pause)
          respond('--- Lich: no scripts to pause') if targets.empty?
        end

        command(/^ua$|^unpause\s?all$/) do
          targets = Script.running.find_all { |s| s.paused? && !s.no_pause_all }
          targets.each(&:unpause)
          respond('--- Lich: no scripts to unpause') if targets.empty?
        end

        # ;kill/;pause/;unpause <name>. Resolution order is exact-then-prefix,
        # each across running before hidden, which is what lets ";kill alpha"
        # find a running "alphabet".
        command(/^(k|kill|stop|p|pause|u|unpause)\s(.+)/) do |m|
          action = m[1]
          target = m[2]
          script = Script.running.find { |s| s.name == target } ||
                   Script.hidden.find { |s| s.name == target } ||
                   Script.running.find { |s| s.name =~ /^#{target}/i } ||
                   Script.hidden.find { |s| s.name =~ /^#{target}/i }
          if script.nil?
            respond "--- Lich: #{target} does not appear to be running! " \
                    "Use '#{$clean_lich_char}list' or '#{$clean_lich_char}listall' to see what's active."
          elsif action =~ /^(?:k|kill|stop)$/
            script.kill
          elsif action =~ /^(?:p|pause)$/
            script.pause
          elsif action =~ /^(?:u|unpause)$/
            script.unpause
          end
        end

        # ---- listing ----------------------------------------------------

        command(/^list\s?(?:all)?$|^l(?:a)?$/i) do |m|
          list = m[0] =~ /a(?:ll)?/i ? Script.running + Script.hidden : Script.running
          if list.empty?
            respond '--- Lich: no active scripts'
          else
            respond "--- Lich: #{list.collect { |a| a.paused? ? "#{a.name} (paused)" : a.name }.join(', ')}"
          end
        end

        # ---- starting scripts -------------------------------------------

        # One entry, not two: the args form is tried inside the handler, which
        # is how the original nested it. Splitting it into two registrations
        # would work only while the args form stayed registered first.
        command(/^force\s+[^\s]+/) do |_m, cmd|
          if (with_args = cmd.match(/^force\s+([^\s]+)\s+(.+)$/))
            Script.start(with_args[1], with_args[2], :force => true)
          elsif (bare = cmd.match(/^force\s+([^\s]+)/))
            Script.start(bare[1], :force => true)
          end
        end

        # ---- sending to scripts -----------------------------------------

        command(/^send |^s /) do |_m, cmd|
          if cmd.split[1] == 'to'
            name = cmd.split[2].chomp.strip
            pool = Script.running + Script.hidden
            script = pool.find { |scr| scr.name == name } || pool.find { |scr| scr.name =~ /^#{name}/i }
            if script
              msg = cmd.split[3..-1].join(' ').chomp
              if script.want_downstream
                script.downstream_buffer.push(msg)
              else
                script.unique_buffer.push(msg)
              end
              respond "--- sent to '#{script.name}': #{msg}"
            else
              respond "--- Lich: '#{name}' does not match any active script!"
            end
          elsif Script.running.empty? && Script.hidden.empty?
            respond('--- Lich: no active scripts to send to.')
          else
            msg = cmd.split[1..-1].join(' ').chomp
            respond("--- sent: #{msg}")
            Script.new_downstream(msg)
          end
        end

        # ---- exec -------------------------------------------------------

        # Registered in the original chain's order. These two do NOT overlap:
        # the exec pattern needs a space (or "q" then a space) right after
        # e/exec, so "en job code" and "execname job code" miss it entirely.
        # Either order works; keeping the original avoids implying a
        # constraint that is not there.
        command(/^(?:exec|e)(q)? (.+)$/) do |m|
          ExecScript.start(m[2], { :quiet => m[1] })
        end

        command(/^(?:execname|en) ([\w\d-]+) (.+)$/) do |m|
          ExecScript.start(m[2], { :name => m[1] })
        end

        # ---- trust ------------------------------------------------------

        # Trust only ever worked on the Ruby 2.0-2.2 $SAFE model; every
        # supported Ruby answers with the unavailable message. Kept verbatim.
        command(/^trust\s+(.*)/i) do |m|
          script_name = m[1]
          if RUBY_VERSION =~ /^2\.[012]\./
            if File.exist?("#{SCRIPT_DIR}/#{script_name}.lic")
              if Script.trust(script_name)
                respond "--- Lich: '#{script_name}' is now a trusted script."
              else
                respond "--- Lich: '#{script_name}' is already trusted."
              end
            else
              respond "--- Lich: could not find script: #{script_name}"
            end
          else
            respond "--- Lich: this feature isn't available in this version of Ruby "
          end
        end

        command(/^(?:dis|un)trust\s+(.*)/i) do |m|
          script_name = m[1]
          if RUBY_VERSION =~ /^2\.[012]\./
            if Script.distrust(script_name)
              respond "--- Lich: '#{script_name}' is no longer a trusted script."
            else
              respond "--- Lich: '#{script_name}' was not found in the trusted script list."
            end
          else
            respond "--- Lich: this feature isn't available in this version of Ruby "
          end
        end

        # Position matches the original chain. Not an ordering constraint:
        # /^list\s?(?:all)?$|^l(?:a)?$/ matches neither "lt" nor "list
        # trusted", so this is reachable wherever it sits.
        command(/^list\s?(?:un)?trust(?:ed)?$|^lt$/i) do
          if RUBY_VERSION =~ /^2\.[012]\./
            list = Script.list_trusted
            if list.empty?
              respond '--- Lich: no scripts are trusted'
            else
              respond "--- Lich: trusted scripts: #{list.join(', ')}"
            end
          else
            respond "--- Lich: this feature isn't available in this version of Ruby "
          end
        end

        # ---- settings ---------------------------------------------------

        command(/^set\s(.+)\s(on|off)/) do |m|
          toggle_var = m[1]
          set_state = m[2]
          did_something = false
          begin
            Lich.db.execute('INSERT OR REPLACE INTO lich_settings(name,value) values(?,?);',
                            [toggle_var.to_s.encode('UTF-8'), set_state.to_s.encode('UTF-8')])
            did_something = true
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
          respond("--- Lich: toggle #{toggle_var} set #{set_state}") if did_something
        end

        command(/^hmr\s+(?<pattern>.*)/i) do |m, cmd|
          HMR.reload(/#{m[:pattern]}/)
        rescue ArgumentError
          if $!.to_s == 'invalid Unicode escape'
            respond '--- Lich: error: invalid Unicode escape'
            respond "--- Lich:   cmd: #{cmd}"
            respond '--- Lich: \\u is unicode escape, did you mean to use a / instead?'
          else
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          end
        end

        # ---- infomon (GemStone) -----------------------------------------

        command(/^infomon sync/i, game: :gs) do
          ExecScript.start('Infomon.sync', { :quiet => true })
        end

        command(/^infomon (?:reset|redo)!?/i, game: :gs) do
          ExecScript.start('Infomon.redo!', { :quiet => true })
        end

        # The capture is moved inside the group so it no longer includes the
        # leading space. The old pattern captured " full" and compared it
        # against 'full', so ";infomon show full" always printed the filtered
        # listing instead of the complete one (Infomon.show(full) keeps the
        # zero-valued rows). Fixed here rather than carried over: a one-token
        # typo, and preserving it would have meant preserving a command that
        # silently ignored its only argument.
        # Downcased because the pattern is case-insensitive: without it
        # ";infomon show FULL" would match and then fail the comparison,
        # which is the same shape of bug one level down.
        command(/^infomon show(?: (full))?/i, game: :gs) do |m|
          Infomon.show(m[1]&.downcase == 'full')
        end

        command(/^infomon effects?(?: (true|false))?/i, game: :gs) do |m|
          new_value = ClientCommands.toggle_value(Infomon.get_bool('infomon.show_durations'), m[1])
          respond "Changing Infomon's effect duration showing to #{new_value}"
          Infomon.set('infomon.show_durations', new_value)
        end

        command(/^sk\b(?: (add|rm|list|help)(?: ([\d\s]+))?)?/i, game: :gs) do |m|
          SK.main(m[1], m[2])
        end

        # ---- display ----------------------------------------------------

        command(/^display flaguid(?: (true|false))?/i, game: :dr) do |m|
          new_value = ClientCommands.toggle_value(Lich.hide_uid_flag, m[1])
          respond "Changing Lich to NOT display Room Title RealIDs while FLAG ShowRoomID ON to #{new_value}"
          Lich.hide_uid_flag = new_value
          respond 'Note: this toggle is largely unnecessary now that room UIDs come from the <nav> tag. ' \
                  "To hide the game's inline RealIDs, you can simply 'flag showroomid off'."
        end

        # The uniform six, in the positions the chain had them. ;display roomid
        # (DR) is registered between uid and exits to keep its original place.
        DISPLAY_TOGGLES.each_with_index do |(word, accessor, description), index|
          command(/^display #{word}(?: (true|false))?/i) do |m|
            new_value = ClientCommands.toggle_value(Lich.public_send(accessor), m[1])
            respond "Changing Lich to display #{description} to #{new_value}"
            Lich.public_send("#{accessor}=", new_value)
          end

          next unless index == 1 # after uid, before exits

          command(/^display roomid(?:\s+(title|line|both))?/i, game: :dr) do |m|
            requested = m[1]&.downcase
            if requested.nil?
              respond "DragonRealms room id / RealID display placement is currently: #{Lich.display_roomid_location}"
              respond 'Usage: ;display roomid <title|line|both>  (title = in the room name line, ' \
                      'line = a Room Number line below the room, both = both places)'
            else
              Lich.display_roomid_location = requested
              respond "Changing DragonRealms room id / RealID display placement to #{Lich.display_roomid_location}"
            end
          end
        end

        command(/^display expgains?(?: (?<toggle>true|false|on|off))?$/i, game: :dr) do |m|
          if running?('exp-monitor')
            respond 'Error: exp-monitor.lic script is currently running'
            respond "Stop it first with: #{$clean_lich_char}kill exp-monitor"
          else
            new_value = ClientCommands.toggle_value(Lich.display_expgains, m[:toggle])
            Lich.display_expgains = new_value
            if new_value
              respond 'Enabling real-time experience gain reporting'
              DRExpMonitor.start
            else
              respond 'Disabling real-time experience gain reporting'
              DRExpMonitor.stop
            end
          end
        end

        command(/^display inlineexp(?: (?<toggle>true|false|on|off))?$/i, game: :dr) do |m|
          new_value = ClientCommands.toggle_value(DRExpMonitor.inline_display?, m[:toggle])
          DRExpMonitor.inline_display = new_value
          if new_value
            respond 'Enabling inline experience display (gained ranks shown in exp window)'
          else
            respond 'Disabling inline experience display'
          end
        end

        command(/^display exp-status$/i, game: :dr) do
          respond
          respond 'DragonRealms Experience Monitor Status:'
          respond "  expgains:   #{Lich.display_expgains ? 'ON' : 'OFF'}  (real-time gain messages)"
          respond "  inlineexp:  #{DRExpMonitor.inline_display? ? 'ON' : 'OFF'}  (cumulative gains in EXP window)"
          respond "  reporter:   #{DRExpMonitor.active? ? 'RUNNING' : 'STOPPED'}"
          respond
          respond 'Commands:'
          respond "  #{$clean_lich_char}display expgains [on|off]    toggle gain messages"
          respond "  #{$clean_lich_char}display inlineexp [on|off]   toggle inline display"
          respond
        end

        # ---- debug logs -------------------------------------------------

        # These three MUST keep this order: numeric form, then exact bare form,
        # then the \b catch that reports anything else as an invalid argument.
        command(/^debuglogs?\s+(?<val>\d+)$/i) do |m|
          Lich.max_debug_logs = m[:val].to_i
          respond "--- Lich: debug log retention set to #{Lich.max_debug_logs} files"
        end

        command(/^debuglogs?$/i) do
          respond
          respond '--- Lich: Debug Log Retention ---'
          respond "  Current limit:  #{Lich.max_debug_logs} files"
          respond "  Default:        #{Lich::MAX_DEBUG_LOGS_DEFAULT} files"
          respond
          respond 'Usage:'
          respond "  #{$clean_lich_char}debuglogs            show current setting"
          respond "  #{$clean_lich_char}debuglogs <number>   set retention limit"
          respond
        end

        command(/^debuglogs?\b/i) do
          respond "--- Lich: invalid argument. Usage: #{$clean_lich_char}debuglogs [number]"
        end

        # ---- update -----------------------------------------------------

        # The argument form MUST stay ahead of the bare form, which answers
        # --help and would otherwise swallow every argument.
        command(/^(?:lich5-update|l5u)\s+(.*)/i) do |m|
          Lich::Util::Update.request(m[1].dup)
        end

        command(/^(?:lich5-update|l5u)/i) do
          Lich::Util::Update.request('--help')
        end

        # ---- banks ------------------------------------------------------

        command(/^banks$/, game: :gs) do
          Game._puts '<c>bank account'
          $_CLIENTBUFFER_.push '<c>bank account'
        end

        command(/^banks(?: (all|reset|reset all))?$/i, game: :dr) do |m|
          case m[1]&.downcase
          when 'all'       then Lich::DragonRealms::DRBanking.display_banks_all
          when 'reset'     then Lich::DragonRealms::DRBanking.reset_character!
          when 'reset all' then Lich::DragonRealms::DRBanking.reset_all!
          else                  Lich::DragonRealms::DRBanking.display_banks
          end
        end

        command(/^magic$/, game: :gs) { Effects.display }

        # ---- help -------------------------------------------------------

        command(/^help$/i) { ClientCommands.help }
      end
    end
  end
end
