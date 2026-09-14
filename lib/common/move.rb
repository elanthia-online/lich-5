# frozen_string_literal: true

module Lich
  module Common
    # The movement primitive. Scripts call the top-level +move+ shim in
    # lib/global_defs.rb; the implementation is {Move.move} here, along with
    # the retry budgets that keep its "fix the obstacle and re-send" branches
    # from looping forever, and a record of why the last move failed that
    # callers can act on without re-parsing game text.
    #
    # move's return value is tri-state: true (moved),
    # false (the exit is wrong - callers may drop it from the map), nil
    # (blocked for now - keep the exit). What is new is {last_failure}: after
    # a false or nil return it names the direction sent, the game line that
    # ended the attempt, and a small +cause+ symbol chosen from {CAUSES} so a
    # supervising script can switch on it instead of matching text:
    #
    #   :injured     too wounded to do it (agony, too injured to climb, a
    #                stand that keeps failing with limb wounds)
    #   :encumbered  a stand that keeps failing while overburdened
    #   :engaged     in combat and cannot leave
    #   :position    not standing and could not get up
    #   :hidden      must be visible to go that way
    #   :hands       needs empty hands
    #   :closed      a door or gate that would not open
    #   :map         the game does not know this exit from here (bad wayto,
    #                or the character is not where the map thinks)
    #   :denied      an NPC or rule refused entry (guards, tickets, guild)
    #   :climb       the climb kept failing (skill roll; not a wound)
    #   :swim        the swim kept failing
    #   :drag        the body being dragged would not come
    #   :roundtime   still waiting on roundtime when we gave up
    #   :unknown     none of the above - read +line+
    #
    # The record is per thread: scripts run on their own threads and several
    # may be moving one character at once (go2 and a follower, say), so a
    # single shared slot could be overwritten between a script's move
    # returning and its read of {last_failure}. Read it from the thread that
    # called move.
    #
    # When Lich::Common::Events is present the same record is emitted as
    # 'move.failed', payload the frozen Failure, so a supervisor can hear it.
    module Move
      Failure = Struct.new(:dir, :line, :cause, :attempts, keyword_init: true)

      # A remedy that should work first time (stand, unhide, empty hands,
      # retreat, open, stow) is retried this many times before move gives
      # up. Past this, the remedy is not working and no number of repeats
      # will change that.
      MAX_REMEDIES = 3

      # A skill roll (climb, swim) legitimately fails several times before
      # succeeding, so it gets a much longer leash. Past this it is either
      # an unpassable exit for this character or the character is stuck.
      MAX_ROLLS = 20

      # Ordered: the first pattern to match a line wins, so the specific
      # causes sit above the broad "You can't" ones. Every pattern is text
      # move itself already matches, or a line captured in play; nothing is
      # invented here.
      CAUSES = [
        [:injured,    /far too much agony|too injured to be doing/i],
        [:encumbered, /overburdened/i],
        [:engaged,    /engaged|retreat out of combat|while in combat|next to impossible while in combat/i],
        [:hidden,     /remain hidden or invisible|can't be seen|without being seen|no one can see you|can't see you/i],
        [:hands,      /hands were empty|hands full|both hands (?:free|might help)|empty hands/i],
        [:position,   /stand(?:ing)? ?(?:up )?first|must be standing|while (?:sitting|lying down)|from that position|already sitting|should stand up|standing up might help|get up first/i],
        [:closed,     /(?:appears|seems) to be closed|squeeze between the stone doors/i],
        [:swim,       /attempt to swim|begin to sink|paddle back to safety|around in the water|swift current|failure to swim|current catches you/i],
        [:drag,       /try to drag/i],
        [:denied,     /may not pass|unseen force prevents|aren't allowed to enter|only performers|see your ticket|registered groups|reputation precedes|"Abandoned\."|leave promptly|open to invitees|unable to follow you|check in/i],
        [:map,        /can't go there|can't (?:go|swim) in that direction|could not find what you were referring|what were you referring|where are you trying to go|plan to do that here|can't go to|become impassable|too far away|too far above/i],
        [:roundtime,  /^\.{3}wait \d|^wait \d/i]
      ].freeze

      LAST_FAILURE_KEY = :lich_move_last_failure

      class << self
        # The most recent failed move on this thread, or nil after a
        # successful one.
        # @return [Failure, nil]
        def last_failure
          Thread.current[LAST_FAILURE_KEY]
        end

        # @param line [String, nil]
        # @return [Symbol] one of the CAUSES keys, or :unknown
        def classify(line)
          return :unknown if line.nil?

          CAUSES.each { |cause, pattern| return cause if line =~ pattern }
          :unknown
        end

        # The cause for a line from the shared skill-roll branch: swim, drag
        # and guard lines are named for what they are; anything else there is
        # a climb.
        # @param line [String]
        # @return [Symbol]
        def roll_cause(line)
          c = classify(line)
          %i[swim drag denied].include?(c) ? c : :climb
        end

        # Why did a stand keep failing? "You struggle, but fail to stand" is
        # the same text for a heavy pack and for leg wounds, so look at the
        # character rather than the line. Falls back to :position.
        # @return [Symbol]
        def stand_failure_cause
          if defined?(XMLData) && XMLData.respond_to?(:encumbrance_text) && XMLData.encumbrance_text.to_s =~ /overburdened/i
            :encumbered
          elsif defined?(Lich::Gemstone::Wounds) && Lich::Gemstone::Wounds.respond_to?(:limbs) && limb_wounds? && Lich::Gemstone::Wounds.limbs.to_i > 0
            :injured
          else
            :position
          end
        rescue StandardError
          :position
        end

        # Record (and announce) a failed move. Called by move on every false
        # or nil return; +cause+ defaults to classifying the line.
        #
        # @param dir [String] the direction as last sent
        # @param line [String, nil] the game line that ended the attempt
        # @param cause [Symbol, nil]
        # @param attempts [Integer] how many times the direction was sent
        # @return [Failure] the frozen record
        def record_failure(dir, line, cause: nil, attempts: 1)
          failure = Failure.new(dir: dir.to_s.dup, line: line&.to_s&.dup, cause: (cause || classify(line)), attempts: attempts).freeze
          Thread.current[LAST_FAILURE_KEY] = failure
          if defined?(Lich::Common::Events)
            begin
              Lich::Common::Events.emit('move.failed', failure)
            rescue StandardError => e
              Lich.log("move: Events.emit failed: #{e.class}: #{e.message}") if defined?(Lich) && Lich.respond_to?(:log)
            end
          end
          failure
        end

        # Forget the last failure (move calls this on success).
        # @return [void]
        def clear_failure
          Thread.current[LAST_FAILURE_KEY] = nil
        end

        # The movement primitive behind the top-level +move+. Sends +dir+
        # and reads the stream until the room changes, a known failure line
        # arrives, or nothing recognizable comes back for +giveup_seconds+ /
        # +giveup_lines+. Every "fix the obstacle and re-send" branch has a
        # budget ({MAX_REMEDIES} or {MAX_ROLLS}) so a remedy that is not
        # working cannot keep this loop alive forever.
        #
        # Relies on the script-context primitives (get?, put, fput, waitrt?,
        # wait_while, standing?, ...) that lib/global_defs.rb defines at top
        # level, so it must run on a script thread like its callers always have.
        # Needs the bounded fput (max_resends:, failures: :symbol); on an fput
        # without those options the stand remedy would recurse without limit.
        #
        # @param dir [String] the exit as the map spells it ('north', 'go door')
        # @param giveup_seconds [Integer] quiet time before giving up
        # @param giveup_lines [Integer] unrecognized lines before giving up
        # @return [true, false, nil] true moved; false this exit is wrong
        #   (callers may drop it from the map); nil blocked for now (keep the
        #   exit). After false/nil, {last_failure} says why.
        def move(dir = 'none', giveup_seconds = 10, giveup_lines = 30)
          # [LNet]-[Private]-Casis: "You begin to make your way up the steep headland pathway.  Before traveling very far, however, you lose your footing on the loose stones.  You struggle in vain to maintain your balance, then find yourself falling to the bay below!"  (20:35:36)
          # [LNet]-[Private]-Casis: "You smack into the water with a splash and sink far below the surface."  (20:35:50)
          # You approach the entrance and identify yourself to the guard.  The guard checks over a long scroll of names and says, "I'm sorry, the Guild is open to invitees only.  Please do return at a later date when we will be open to the public."
          #
          if dir == 'none'
            echo 'move: no direction given'
            return false
          end

          # Own the string: several branches rewrite it (climb<->go, door numbering),
          # and the argument is often a wayto string straight from the map database.
          dir = dir.to_s.dup
          need_full_hands = false
          tried_open = false
          tried_fix_drag = false
          line_count = 0
          room_count = XMLData.room_count
          giveup_time = Time.now.to_i + giveup_seconds.to_i
          save_stream = Array.new
          sends = 0
          remedies = Hash.new(0)
          last_line = nil
          remedy_replies = {} # what the game said to each kind of remedy
          current_kind = nil

          # Every exit goes through here: restore hands and the buffer, record the
          # failure (with its cause) unless we moved, return the tri-state value.
          finish = proc { |value, cause = nil|
            fill_hands if need_full_hands
            Script.current.downstream_buffer.unshift(*save_stream.flatten)
            if value
              clear_failure
            else
              record_failure(dir, last_line, cause: cause, attempts: sends)
            end
            return value
          }

          put_dir = proc {
            if XMLData.room_count > room_count
              finish.call(true)
            end
            waitrt?
            wait_while { stunned? }
            giveup_time = Time.now.to_i + giveup_seconds.to_i
            line_count = 0
            save_stream.push(clear)
            sends += 1
            put dir
          }

          # Send one remedy command (stand, unhide, retreat, ...) through the
          # bounded fput: one refusal-driven resend (a "...wait N", or the
          # in-frame stand fput does on "You struggle, but fail to stand."),
          # then a failure symbol instead of the unbounded ladder the old fput
          # ran, which is what kept the stand loop alive. The reply string is
          # kept per remedy kind so an exhausted remedy can report what the
          # game actually said to it. Inside a remedy block the kind is the
          # remedy's own; the one-shot fixes (drag, open, trap) name theirs so
          # their reply cannot land on whichever remedy ran last.
          command = proc { |cmd, kind = current_kind|
            reply = fput(cmd, timeout: 3, max_resends: 1, failures: :symbol)
            if reply.is_a?(String)
              remedy_replies[kind] = reply
              last_line = reply
            end
            reply
          }

          # Apply a remedy and re-send, unless this remedy has already been tried
          # +budget+ times without the move succeeding - then give up with +cause+.
          # nil (keep the exit): the obstacle is about the character, not the map.
          remedy = proc { |kind, budget, cause, &fix|
            remedies[kind] += 1
            if remedies[kind] > budget
              echo "move: #{kind} did not help after #{budget} tries.  giving up."
              # what the game said to THIS remedy ("You are overburdened and
              # cannot manage to stand.") explains more than the move's own
              # refusal; a reply to some other remedy that later succeeded
              # must not be mistaken for it
              last_line = remedy_replies[kind] if remedy_replies[kind]
              finish.call(nil, cause)
            end
            current_kind = kind
            fix.call
            put_dir.call
          }

          put_dir.call

          loop {
            line = get?
            unless line.nil?
              save_stream.push(line)
              line_count += 1
              last_line = line
            end
            if line.nil?
              sleep 0.1
            elsif line =~ /^You realize that would be next to impossible while in combat.|^You can't do that while engaged!|^You are engaged to |^You need to retreat out of combat first!|^You try to move, but you're engaged|^While in combat\?  You'll have better luck if you first retreat/
              # DragonRealms
              remedy.call(:retreat, MAX_REMEDIES, :engaged) {
                command.call('retreat')
                command.call('retreat')
              }
            elsif line =~ /^You can't enter .+ and remain hidden or invisible\.|if he can't see you!$|^You can't enter .+ when you can't be seen\.$|^You can't do that without being seen\.$|^How do you intend to get .*? attention\?  After all, no one can see you right now\.$/
              remedy.call(:unhide, MAX_REMEDIES, :hidden) { command.call('unhide') }
            elsif (line =~ /^You (?:take a few steps toward|trudge up to|limp towards|march up to|sashay gracefully up to|skip happily towards|sneak up to|stumble toward) a rusty doorknob/) and (dir =~ /door/)
              which = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eight', 'ninth', 'tenth', 'eleventh', 'twelfth']
              remedy.call(:door, which.length, :map) {
                if dir =~ /\b#{which.join('|')}\b/
                  dir.sub!(/\b(#{which.join('|')})\b/) { "#{which[which.index($1) + 1]}" }
                else
                  dir.sub!('door', 'second door')
                end
              }
            elsif line =~ /^You can't go there|^You can't (?:go|swim) in that direction\.|^Where are you trying to go\?|^What were you referring to\?|^I could not find what you were referring to\.|^How do you plan to do that here\?|^You take a few steps towards|^You cannot do that\.|^You settle yourself on|^You shouldn't annoy|^You can't go to|^That's probably not a very good idea|^Maybe you should look|^You are already(?! as far away as you can get)|^You walk over to|^You step over to|The [\w\s]+ is too far away|You may not pass\.|become impassable\.|prevents you from entering\.|Please leave promptly\.|is too far above you to attempt that\.$|^Uh, yeah\.  Right\.$|^Definitely NOT a good idea\.$|^Your attempt fails|^There doesn't seem to be any way to do that at the moment\.$/
              # this exit is wrong for the map, whatever the phrasing; say so
              # rather than letting classify guess from the text ("You may
              # not pass." would read as :denied, the keep-the-exit cause)
              echo 'move: failed'
              finish.call(false, :map)
            elsif line =~ /^[A-z\s-] is unable to follow you\.$|^An unseen force prevents you\.$|^Sorry, you aren't allowed to enter here\.|^That looks like someplace only performers should go\.|^As you climb, your grip gives way and you fall down|^The clerk stops you from entering the partition and says, "I'll need to see your ticket!"$|^The guard stops you, saying, "Only members of registered groups may enter the Meeting Hall\.  If you'd like to visit, ask a group officer for a guest pass\."$|^An? .*? reaches over and grasps [A-Z][a-z]+ by the neck preventing (?:him|her) from being dragged anywhere\.$|^You'll have to wait, [A-Z][a-z]+ .* locker|^As you move toward the gate, you carelessly bump into the guard|^You attempt to enter the back of the shop, but a clerk stops you.  "Your reputation precedes you!|you notice that thick beams are placed across the entry with a small sign that reads, "Abandoned\."$|appears to be closed, perhaps you should try again later\?$/
              echo 'move: failed'
              # return nil instead of false to show the direction shouldn't be removed from the map database
              finish.call(nil)
            elsif line =~ /^You grab [A-Z][a-z]+ and try to drag h(?:im|er), but s?he (?:is too heavy|doesn't budge)\.$|^Tentatively, you attempt to swim through the nook\.  After only a few feet, you begin to sink!  Your lungs burn from lack of air, and you begin to panic!  You frantically paddle back to safety!$|^Guards(?:wo)?man [A-Z][a-z]+ stops you and says, "(?:Stop\.|Halt!)  You need to make sure you check in|^You step into the root, but can see no way to climb the slippery tendrils inside\.  After a moment, you step back out\.$|^As you start .*? back to safe ground\.$|^You stumble a bit as you try to enter the pool but feel that your persistence will pay off\.$|^A shimmering field of magical crimson and gold energy flows through the area\.$|^You attempt to navigate your way through the fog, but (?:quickly become entangled|get turned around)|^Trying to judge the climb, you peer over the edge\.\s*A wave of dizziness hits you, and you back away from the .*\.$|^You approach the .*, but the steepness is intimidating\.$|^You make your way (?:up|down) the .*\.\s*Partway (?:up|down), you make the mistake of looking down\. Struck by vertigo, you cling to the .* for a few moments, then slowly climb back (?:up|down)\.$|^You pick your way up the .*, but reach a point where your footing is questionable.\s*Reluctantly, you climb back down.$/
              # swim, drag and guard lines share this branch with climb lines;
              # name the cause from the line rather than assuming a climb
              remedy.call(:roll, MAX_ROLLS, roll_cause(line)) {
                sleep 1
                waitrt?
              }
            elsif line =~ /^Climbing.*(?:plunge|fall)|^Tentatively, you attempt to climb.*(?:fall|slip)|^You start up the .* but slip after a few feet and fall to the ground|^You start.*but quickly realize|^You.*drop back to the ground|^You leap .* fall unceremoniously to the ground in a heap\.$|^You search for a way to make the climb .*? but without success\.$|^You start to climb .* you fall to the ground|^You attempt to climb .* wrong approach|^You run towards .*? slowly retreat back, reassessing the situation\.|^You attempt to climb down the .*, but you can't seem to find purchase\.|^You start down the .*, but you find it hard going.\s*Rather than risking a fall, you make your way back up\./
              remedy.call(:roll, MAX_ROLLS, :climb) {
                sleep 1
                waitrt?
                command.call('stand') unless standing?
                waitrt?
              }
            elsif line =~ /^(?:You swim .*, (?:cutting through|navigating)|You swim .*, struggling against|Your lungs burn and your muscles ache)/
              # swims in Sailor's Grief
              finish.call(true)
            elsif line =~ /^You begin to climb up the silvery thread.* you tumble to the ground/
              remedy.call(:roll, MAX_ROLLS, :climb) {
                sleep 0.5
                waitrt?
                command.call('stand') unless standing?
                waitrt?
                if checkleft or checkright
                  need_full_hands = true
                  empty_hands
                end
              }
            elsif line == 'You are too injured to be doing any climbing!'
              if (resolve = Spell[9704]) and resolve.known?
                remedy.call(:resolve, MAX_REMEDIES, :injured) {
                  wait_until { resolve.affordable? }
                  resolve.cast
                }
              else
                finish.call(nil, :injured)
              end
            elsif line =~ /^You(?:'re going to| will) have to climb that\./
              remedy.call(:verb, MAX_REMEDIES, :map) { dir.gsub!('go', 'climb') }
            elsif line =~ /^You can't climb that\./
              remedy.call(:verb, MAX_REMEDIES, :map) { dir.gsub!('climb', 'go') }
            elsif line =~ /^You can't drag/
              if tried_fix_drag
                finish.call(false, :drag)
              elsif (dir =~ /^(?:go|climb) .+$/) and (drag_line = reget.reverse.find { |l| l =~ /^You grab .*?(?:'s body)? and drag|^You are now automatically attempting to drag .*? when/ })
                tried_fix_drag = true
                name = (/^You grab (.*?)('s body)? and drag/.match(drag_line).captures.first || /^You are now automatically attempting to drag (.*?) when/.match(drag_line).captures.first)
                target = /^(?:go|climb) (.+)$/.match(dir).captures.first
                command.call("drag #{name}", :drag)
                dir = "drag #{name} #{target}"
                put_dir.call
              else
                tried_fix_drag = true
                dir.sub!(/^climb /, 'go ')
                put_dir.call
              end
            elsif line =~ /^Maybe if your hands were empty|^You figure freeing up both hands might help\.|^You can't .+ with your hands full\.$|^You'll need empty hands to climb that\.$|^It's a bit too difficult to swim holding|^You will need both hands free for such a difficult task\./
              remedy.call(:hands, MAX_REMEDIES, :hands) {
                need_full_hands = true
                empty_hands
              }
            elsif line =~ /(?:appears|seems) to be closed\.$|^You cannot quite manage to squeeze between the stone doors\.$/
              if tried_open
                finish.call(false, :closed)
              else
                tried_open = true
                command.call(dir.sub(/go|climb/, 'open'), :open)
                put_dir.call
              end
            elsif line =~ /^(\.\.\.w|W)ait ([0-9]+) sec(onds)?\.$/
              # Waiting is not a remedy that can fail; roundtime always ends.
              if $2.to_i > 1
                sleep($2.to_i - "0.2".to_f)
              else
                sleep 0.3
              end
              put_dir.call
            elsif line =~ /will have to stand up first|must be standing first|^You'll have to get up first|^But you're already sitting!|^Shouldn't you be standing first|^That would be quite a trick from that position\.  Try standing up\.|^Perhaps you should stand up|^Standing up might help|^You should really stand up first|You can't do that while sitting|You must be standing to do that|You can't do that while lying down|^You must be standing|^You can't do that from that position/
              # A stand that keeps failing (wounds, encumbrance) used to loop here
              # forever, 10s of roundtime per try. Bounded now; the cause comes
              # from the character's state since the failure text is the same
              # for a heavy pack and for leg wounds.
              remedy.call(:stand, MAX_REMEDIES, stand_failure_cause) {
                command.call('stand')
                waitrt?
              }
            elsif line =~ /^You're still recovering from your recent/
              remedy.call(:recover, MAX_ROLLS, :roundtime) { sleep 2 }
            elsif line =~ /^The ground approaches you at an alarming rate/
              remedy.call(:fell, MAX_ROLLS, :climb) {
                sleep 1
                command.call('stand') unless standing?
              }
            elsif line =~ /You go flying down several feet, landing with a/
              remedy.call(:fell, MAX_ROLLS, :climb) {
                sleep 1
                command.call('stand') unless standing?
              }
            elsif line =~ /^Sorry, you may only type ahead/
              # clears on its own once the queue drains, but bounded all the same
              remedy.call(:typeahead, MAX_ROLLS, :roundtime) { sleep 1 }
            elsif line == 'You are still stunned.'
              wait_while { stunned? }
              put_dir.call
            elsif line =~ /you slip (?:on a patch of ice )?and flail uselessly as you land on your rear(?:\.|!)$|You wobble and stumble only for a moment before landing flat on your face!$|^You slip in the mud and fall flat on your back\!$/
              remedy.call(:fell, MAX_ROLLS, :climb) {
                waitrt?
                command.call('stand') unless standing?
                waitrt?
              }
            elsif line =~ /^You flick your hand (?:up|down)wards and focus your aura on your disk, but your disk only wobbles briefly\.$/
              remedy.call(:disk, MAX_REMEDIES, :unknown) { nil }
            elsif line =~ /^You dive into the fast-moving river, but the current catches you and whips you back to shore, wet and battered\.$|^Running through the swampy terrain, you notice a wet patch in the bog|^You flounder around in the water.$|^You blunder around in the water, barely able|^You struggle against the swift current to swim|^You slap at the water in a sad failure to swim|^You work against the swift current to swim/
              remedy.call(:roll, MAX_ROLLS, :swim) { waitrt? }
            elsif line =~ /^(You notice .* at your feet, and do not wish to leave it behind|As you prepare to move away, you remember)/
              remedy.call(:feet, MAX_REMEDIES, :unknown) {
                command.call('stow feet')
                sleep 1
              }
            elsif line =~ /The electricity courses through you in a raging torrent, its power singing in your veins!  Spent, the boltstone apparatus shatters into glinting fragments\.|The lightning strikes you in an agonizing eruption of liquid radiance!/
              # the boltstone shatters as it fires, so this should not recur;
              # bounded anyway rather than trusting that
              remedy.call(:trap, MAX_REMEDIES, :unknown) {
                sleep(0.5)
                wait_while { stunned? }
                waitrt?
                command.call('stand', :trap) unless standing?
                waitrt?
              }
            elsif line == "You don't seem to be able to move to do that."
              remedy.call(:held, MAX_REMEDIES, :unknown) {
                30.times {
                  break if clear.include?('You regain control of your senses!')

                  sleep 0.1
                }
              }
            elsif line =~ /^It's pitch dark and you can't see a thing!/
              echo "You will need a light source to continue your journey"
              finish.call(true)
            end
            if XMLData.room_count > room_count
              finish.call(true)
            end
            if Time.now.to_i >= giveup_time
              echo "move: no recognized response in #{giveup_seconds} seconds.  giving up."
              finish.call(nil, :unknown)
            end
            if line_count >= giveup_lines
              echo "move: no recognized response after #{line_count} lines.  giving up."
              finish.call(nil, :unknown)
            end
          }
        end

        private

        # Wounds.limbs reads XMLData.injuries; only ask when that hash is there.
        def limb_wounds?
          defined?(XMLData) && XMLData.respond_to?(:injuries) && XMLData.injuries.is_a?(Hash) && !XMLData.injuries.empty?
        end
      end
    end
  end
end
