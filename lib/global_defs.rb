# global_defs carveout for lich5
# this needs to be broken up even more - OSXLich-Doug (2022-04-13)
# rubocop changes and DR toplevel command handling (2023-06-28)

def hide_me
  Script.current.hidden = !Script.current.hidden
end

def no_kill_all
  script = Script.current
  script.no_kill_all = !script.no_kill_all
end

def no_pause_all
  script = Script.current
  script.no_pause_all = !script.no_pause_all
end

def toggle_upstream
  unless (script = Script.current) then echo 'toggle_upstream: cannot identify calling script.'; return nil; end
  script.want_upstream = !script.want_upstream
end

def silence_me
  unless (script = Script.current) then echo 'silence_me: cannot identify calling script.'; return nil; end
  if script.safe? then echo("WARNING: 'safe' script attempted to silence itself.  Ignoring the request.")
                       sleep 1
                       return true
  end
  script.silent = !script.silent
end

def toggle_echo
  unless (script = Script.current) then respond('--- toggle_echo: Unable to identify calling script.'); return nil; end
  script.no_echo = !script.no_echo
end

def echo_on
  unless (script = Script.current) then respond('--- echo_on: Unable to identify calling script.'); return nil; end
  script.no_echo = false
end

def echo_off
  unless (script = Script.current) then respond('--- echo_off: Unable to identify calling script.'); return nil; end
  script.no_echo = true
end

def upstream_get
  unless (script = Script.current) then echo 'upstream_get: cannot identify calling script.'; return nil; end
  unless script.want_upstream
    echo("This script wants to listen to the upstream, but it isn't set as receiving the upstream! This will cause a permanent hang, aborting (ask for the upstream with 'toggle_upstream' in the script)")
    sleep 0.3
    return false
  end
  script.upstream_gets
end

def upstream_get?
  unless (script = Script.current) then echo 'upstream_get: cannot identify calling script.'; return nil; end
  unless script.want_upstream
    echo("This script wants to listen to the upstream, but it isn't set as receiving the upstream! This will cause a permanent hang, aborting (ask for the upstream with 'toggle_upstream' in the script)")
    return false
  end
  script.upstream_gets?
end

def echo(*messages)
  respond if messages.empty?
  if (script = Script.current)
    unless script.no_echo
      messages.each { |message| respond("[#{script.name}: #{message.to_s.chomp}]") }
    end
  else
    messages.each { |message| respond("[(unknown script): #{message.to_s.chomp}]") }
  end
  nil
end

def _echo(*messages)
  _respond if messages.empty?
  if (script = Script.current)
    unless script.no_echo
      messages.each { |message| _respond("[#{script.name}: #{message.to_s.chomp}]") }
    end
  else
    messages.each { |message| _respond("[(unknown script): #{message.to_s.chomp}]") }
  end
  nil
end

def goto(label)
  Script.current.jump_label = label.to_s
  raise JUMP
end

def pause_script(*names)
  names.flatten!
  if names.empty?
    Script.current.pause
    Script.current
  else
    names.each { |scr|
      fnd = Script.list.find { |nm| nm.name =~ /^#{scr}/i }
      fnd.pause unless (fnd.paused || fnd.nil?)
    }
  end
end

def unpause_script(*names)
  names.flatten!
  names.each { |scr|
    fnd = Script.list.find { |nm| nm.name =~ /^#{scr}/i }
    fnd.unpause if (fnd.paused and not fnd.nil?)
  }
end

def fix_injury_mode
  unless XMLData.injury_mode == 2
    Game._puts '_injury 2'
    150.times { sleep 0.05; break if XMLData.injury_mode == 2 }
  end
end

def hide_script(*args)
  args.flatten!
  args.each { |name|
    if (script = Script.running.find { |scr| scr.name == name })
      script.hidden = !script.hidden
    end
  }
end

def parse_list(string)
  string.split_as_list
end

def waitrt
  wait_until { (XMLData.roundtime_end.to_f - Time.now.to_f + XMLData.server_time_offset.to_f) > 0 }
  sleep checkrt
end

def waitcastrt
  wait_until { (XMLData.cast_roundtime_end.to_f - Time.now.to_f + XMLData.server_time_offset.to_f) > 0 }
  sleep checkcastrt
end

def checkrt
  [0, XMLData.roundtime_end.to_f - Time.now.to_f + XMLData.server_time_offset.to_f].max
end

def checkcastrt
  [0, XMLData.cast_roundtime_end.to_f - Time.now.to_f + XMLData.server_time_offset.to_f].max
end

def waitrt?
  sleep checkrt
  return true if checkrt > 0.0
  return false if checkrt == 0
end

def waitcastrt?
  #  sleep checkcastrt
  current_castrt = checkcastrt
  if current_castrt.to_f > 0.0
    sleep(current_castrt)
    return true
  else
    return false
  end
end

def checkpoison
  XMLData.indicator['IconPOISONED'] == 'y'
end

def checkdisease
  XMLData.indicator['IconDISEASED'] == 'y'
end

def checksitting
  XMLData.indicator['IconSITTING'] == 'y'
end

def checkkneeling
  XMLData.indicator['IconKNEELING'] == 'y'
end

def checkstunned
  XMLData.indicator['IconSTUNNED'] == 'y'
end

def checkbleeding
  XMLData.indicator['IconBLEEDING'] == 'y'
end

def checkgrouped
  XMLData.indicator['IconJOINED'] == 'y'
end

def checkdead
  XMLData.indicator['IconDEAD'] == 'y'
end

def checkreallybleeding
  checkbleeding and !(Spell[9909].active? or Spell[9905].active?)
end

def muckled?
  # need a better DR solution
  if XMLData.game =~ /GS/
    return Status.muckled?
  else
    return checkdead || checkstunned || checkwebbed
  end
end

def checkhidden
  XMLData.indicator['IconHIDDEN'] == 'y'
end

def checkinvisible
  XMLData.indicator['IconINVISIBLE'] == 'y'
end

def checkwebbed
  XMLData.indicator['IconWEBBED'] == 'y'
end

def checkprone
  XMLData.indicator['IconPRONE'] == 'y'
end

def checknotstanding
  XMLData.indicator['IconSTANDING'] == 'n'
end

def checkstanding
  XMLData.indicator['IconSTANDING'] == 'y'
end

def checkname(*strings)
  strings.flatten!
  if strings.empty?
    XMLData.name
  else
    XMLData.name =~ /^(?:#{strings.join('|')})/i
  end
end

def checkloot
  GameObj.loot.collect { |item| item.noun }
end

def i_stand_alone
  unless (script = Script.current) then echo 'i_stand_alone: cannot identify calling script.'; return nil; end
  script.want_downstream = !script.want_downstream
  return !script.want_downstream
end

def debug(*args)
  if $LICH_DEBUG
    if block_given?
      yield(*args)
    else
      echo(*args)
    end
  end
end

def timetest(*contestants)
  contestants.collect { |code| start = Time.now; 5000.times { code.call }; Time.now - start }
end

def dec2bin(n)
  "0" + [n].pack("N").unpack("B32")[0].sub(/^0+(?=\d)/, '')
end

def bin2dec(n)
  [("0" * 32 + n.to_s)[-32..-1]].pack("B32").unpack("N")[0]
end

def idle?(time = 60)
  Time.now - $_IDLETIMESTAMP_ >= time
end

def selectput(string, success, failure, timeout = nil)
  timeout = timeout.to_f if timeout and !timeout.kind_of?(Numeric)
  success = [success] if success.kind_of? String
  failure = [failure] if failure.kind_of? String
  if !string.kind_of?(String) or !success.kind_of?(Array) or !failure.kind_of?(Array) or timeout && !timeout.kind_of?(Numeric)
    raise ArgumentError, "usage is: selectput(game_command,success_array,failure_array[,timeout_in_secs])"
  end

  success.flatten!
  failure.flatten!
  regex = /#{(success + failure).join('|')}/i
  successre = /#{success.join('|')}/i
  thr = Thread.current

  timethr = Thread.new {
    timeout -= sleep("0.1".to_f) until timeout <= 0
    thr.raise(StandardError)
  } if timeout

  begin
    loop {
      fput(string)
      response = waitforre(regex)
      if successre.match(response.to_s)
        timethr.kill if timethr.alive?
        break(response.string)
      end
      yield(response.string) if block_given?
    }
  rescue
    nil
  end
end

def toggle_unique
  unless (script = Script.current) then echo 'toggle_unique: cannot identify calling script.'; return nil; end
  script.want_downstream = !script.want_downstream
end

def die_with_me(*vals)
  unless (script = Script.current) then echo 'die_with_me: cannot identify calling script.'; return nil; end
  script.die_with.push vals
  script.die_with.flatten!
  echo("The following script(s) will now die when I do: #{script.die_with.join(', ')}") unless script.die_with.empty?
end

def upstream_waitfor(*strings)
  strings.flatten!
  script = Script.current
  unless script.want_upstream then echo("This script wants to listen to the upstream, but it isn't set as receiving the upstream! This will cause a permanent hang, aborting (ask for the upstream with 'toggle_upstream' in the script)"); return false end
  regexpstr = strings.join('|')
  while (line = script.upstream_gets)
    if line =~ /#{regexpstr}/i
      return line
    end
  end
end

def send_to_script(*values)
  values.flatten!
  if (script = Script.list.find { |val| val.name =~ /^#{values.first}/i })
    if script.want_downstream
      values[1..-1].each { |val| script.downstream_buffer.push(val) }
    else
      values[1..-1].each { |val| script.unique_buffer.push(val) }
    end
    echo("Sent to #{script.name} -- '#{values[1..-1].join(' ; ')}'")
    return true
  else
    echo("'#{values.first}' does not match any active scripts!")
    return false
  end
end

def unique_send_to_script(*values)
  values.flatten!
  if (script = Script.list.find { |val| val.name =~ /^#{values.first}/i })
    values[1..-1].each { |val| script.unique_buffer.push(val) }
    echo("sent to #{script}: #{values[1..-1].join(' ; ')}")
    return true
  else
    echo("'#{values.first}' does not match any active scripts!")
    return false
  end
end

def unique_waitfor(*strings)
  unless (script = Script.current) then echo 'unique_waitfor: cannot identify calling script.'; return nil; end
  strings.flatten!
  regexp = /#{strings.join('|')}/
  while true
    str = script.unique_gets
    if str =~ regexp
      return str
    end
  end
end

def unique_get
  unless (script = Script.current) then echo 'unique_get: cannot identify calling script.'; return nil; end
  script.unique_gets
end

def unique_get?
  unless (script = Script.current) then echo 'unique_get: cannot identify calling script.'; return nil; end
  script.unique_gets?
end

def multimove(*dirs)
  dirs.flatten.each { |dir| move(dir) }
end

def n;    'north';     end

def ne;   'northeast'; end

def e;    'east';      end

def se;   'southeast'; end

def s;    'south';     end

def sw;   'southwest'; end

def w;    'west';      end

def nw;   'northwest'; end

def u;    'up';        end

def up;   'up'; end

def down; 'down';      end

def d;    'down';      end

def o;    'out';       end

def out;  'out';       end

def move(dir = 'none', giveup_seconds = 10, giveup_lines = 30)
  # [LNet]-[Private]-Casis: "You begin to make your way up the steep headland pathway.  Before traveling very far, however, you lose your footing on the loose stones.  You struggle in vain to maintain your balance, then find yourself falling to the bay below!"  (20:35:36)
  # [LNet]-[Private]-Casis: "You smack into the water with a splash and sink far below the surface."  (20:35:50)
  # You approach the entrance and identify yourself to the guard.  The guard checks over a long scroll of names and says, "I'm sorry, the Guild is open to invitees only.  Please do return at a later date when we will be open to the public."
  if dir == 'none'
    echo 'move: no direction given'
    return false
  end

  need_full_hands = false
  tried_open = false
  tried_fix_drag = false
  line_count = 0
  room_count = XMLData.room_count
  giveup_time = Time.now.to_i + giveup_seconds.to_i
  save_stream = Array.new

  put_dir = proc {
    if XMLData.room_count > room_count
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return true
    end
    waitrt?
    wait_while { stunned? }
    giveup_time = Time.now.to_i + giveup_seconds.to_i
    line_count = 0
    save_stream.push(clear)
    put dir
  }

  put_dir.call

  loop {
    line = get?
    unless line.nil?
      save_stream.push(line)
      line_count += 1
    end
    if line.nil?
      sleep 0.1
    elsif line =~ /^You realize that would be next to impossible while in combat.|^You can't do that while engaged!|^You are engaged to |^You need to retreat out of combat first!|^You try to move, but you're engaged|^While in combat\?  You'll have better luck if you first retreat/
      # DragonRealms
      fput 'retreat'
      fput 'retreat'
      put_dir.call
    elsif line =~ /^You can't enter .+ and remain hidden or invisible\.|if he can't see you!$|^You can't enter .+ when you can't be seen\.$|^You can't do that without being seen\.$|^How do you intend to get .*? attention\?  After all, no one can see you right now\.$/
      fput 'unhide'
      put_dir.call
    elsif (line =~ /^You (?:take a few steps toward|trudge up to|limp towards|march up to|sashay gracefully up to|skip happily towards|sneak up to|stumble toward) a rusty doorknob/) and (dir =~ /door/)
      which = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eight', 'ninth', 'tenth', 'eleventh', 'twelfth']
      # avoid stomping the room for the entire session due to a transient failure
      dir = dir.to_s
      if dir =~ /\b#{which.join('|')}\b/
        dir.sub!(/\b(#{which.join('|')})\b/) { "#{which[which.index($1) + 1]}" }
      else
        dir.sub!('door', 'second door')
      end
      put_dir.call
    elsif line =~ /^You can't go there|^You can't (?:go|swim) in that direction\.|^Where are you trying to go\?|^What were you referring to\?|^I could not find what you were referring to\.|^How do you plan to do that here\?|^You take a few steps towards|^You cannot do that\.|^You settle yourself on|^You shouldn't annoy|^You can't go to|^That's probably not a very good idea|^Maybe you should look|^You are already(?! as far away as you can get)|^You walk over to|^You step over to|The [\w\s]+ is too far away|You may not pass\.|become impassable\.|prevents you from entering\.|Please leave promptly\.|is too far above you to attempt that\.$|^Uh, yeah\.  Right\.$|^Definitely NOT a good idea\.$|^Your attempt fails|^There doesn't seem to be any way to do that at the moment\.$/
      echo 'move: failed'
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return false
    elsif line =~ /^[A-z\s-] is unable to follow you\.$|^An unseen force prevents you\.$|^Sorry, you aren't allowed to enter here\.|^That looks like someplace only performers should go\.|^As you climb, your grip gives way and you fall down|^The clerk stops you from entering the partition and says, "I'll need to see your ticket!"$|^The guard stops you, saying, "Only members of registered groups may enter the Meeting Hall\.  If you'd like to visit, ask a group officer for a guest pass\."$|^An? .*? reaches over and grasps [A-Z][a-z]+ by the neck preventing (?:him|her) from being dragged anywhere\.$|^You'll have to wait, [A-Z][a-z]+ .* locker|^As you move toward the gate, you carelessly bump into the guard|^You attempt to enter the back of the shop, but a clerk stops you.  "Your reputation precedes you!|you notice that thick beams are placed across the entry with a small sign that reads, "Abandoned\."$|appears to be closed, perhaps you should try again later\?$/
      echo 'move: failed'
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      # return nil instead of false to show the direction shouldn't be removed from the map database
      return nil
    elsif line =~ /^You grab [A-Z][a-z]+ and try to drag h(?:im|er), but s?he (?:is too heavy|doesn't budge)\.$|^Tentatively, you attempt to swim through the nook\.  After only a few feet, you begin to sink!  Your lungs burn from lack of air, and you begin to panic!  You frantically paddle back to safety!$|^Guards(?:wo)?man [A-Z][a-z]+ stops you and says, "(?:Stop\.|Halt!)  You need to make sure you check in|^You step into the root, but can see no way to climb the slippery tendrils inside\.  After a moment, you step back out\.$|^As you start .*? back to safe ground\.$|^You stumble a bit as you try to enter the pool but feel that your persistence will pay off\.$|^A shimmering field of magical crimson and gold energy flows through the area\.$|^You attempt to navigate your way through the fog, but (?:quickly become entangled|get turned around)|^Trying to judge the climb, you peer over the edge\.\s*A wave of dizziness hits you, and you back away from the .*\.$|^You approach the .*, but the steepness is intimidating\.$|^You make your way up the .*\.\s*Partway up, you make the mistake of looking down\. Struck by vertigo, you cling to the .* for a few moments, then slowly climb back down\.$|^You pick your way up the .*, but reach a point where your footing is questionable.\s*Reluctantly, you climb back down.$/
      sleep 1
      waitrt?
      put_dir.call
    elsif line =~ /^Climbing.*(?:plunge|fall)|^Tentatively, you attempt to climb.*(?:fall|slip)|^You start up the .* but slip after a few feet and fall to the ground|^You start.*but quickly realize|^You.*drop back to the ground|^You leap .* fall unceremoniously to the ground in a heap\.$|^You search for a way to make the climb .*? but without success\.$|^You start to climb .* you fall to the ground|^You attempt to climb .* wrong approach|^You run towards .*? slowly retreat back, reassessing the situation\.|^You attempt to climb down the .*, but you can't seem to find purchase\.|^You start down the .*, but you find it hard going.\s*Rather than risking a fall, you make your way back up\./
      sleep 1
      waitrt?
      fput 'stand' unless standing?
      waitrt?
      put_dir.call
    elsif line =~ /^You begin to climb up the silvery thread.* you tumble to the ground/
      sleep 0.5
      waitrt?
      fput 'stand' unless standing?
      waitrt?
      if checkleft or checkright
        need_full_hands = true
        empty_hands
      end
      put_dir.call
    elsif line == 'You are too injured to be doing any climbing!'
      if (resolve = Spell[9704]) and resolve.known?
        wait_until { resolve.affordable? }
        resolve.cast
        put_dir.call
      else
        return nil
      end
    elsif line =~ /^You(?:'re going to| will) have to climb that\./
      dir.gsub!('go', 'climb')
      put_dir.call
    elsif line =~ /^You can't climb that\./
      dir.gsub!('climb', 'go')
      put_dir.call
    elsif line =~ /^You can't drag/
      if tried_fix_drag
        fill_hands if need_full_hands
        Script.current.downstream_buffer.unshift(save_stream)
        Script.current.downstream_buffer.flatten!
        return false
      elsif (dir =~ /^(?:go|climb) .+$/) and (drag_line = reget.reverse.find { |l| l =~ /^You grab .*?(?:'s body)? and drag|^You are now automatically attempting to drag .*? when/ })
        tried_fix_drag = true
        name = (/^You grab (.*?)('s body)? and drag/.match(drag_line).captures.first || /^You are now automatically attempting to drag (.*?) when/.match(drag_line).captures.first)
        target = /^(?:go|climb) (.+)$/.match(dir).captures.first
        fput "drag #{name}"
        dir = "drag #{name} #{target}"
        put_dir.call
      else
        tried_fix_drag = true
        dir.sub!(/^climb /, 'go ')
        put_dir.call
      end
    elsif line =~ /^Maybe if your hands were empty|^You figure freeing up both hands might help\.|^You can't .+ with your hands full\.$|^You'll need empty hands to climb that\.$|^It's a bit too difficult to swim holding|^You will need both hands free for such a difficult task\./
      need_full_hands = true
      empty_hands
      put_dir.call
    elsif line =~ /(?:appears|seems) to be closed\.$|^You cannot quite manage to squeeze between the stone doors\.$/
      if tried_open
        fill_hands if need_full_hands
        Script.current.downstream_buffer.unshift(save_stream)
        Script.current.downstream_buffer.flatten!
        return false
      else
        tried_open = true
        fput dir.sub(/go|climb/, 'open')
        put_dir.call
      end
    elsif line =~ /^(\.\.\.w|W)ait ([0-9]+) sec(onds)?\.$/
      if $2.to_i > 1
        sleep($2.to_i - "0.2".to_f)
      else
        sleep 0.3
      end
      put_dir.call
    elsif line =~ /will have to stand up first|must be standing first|^You'll have to get up first|^But you're already sitting!|^Shouldn't you be standing first|^That would be quite a trick from that position\.  Try standing up\.|^Perhaps you should stand up|^Standing up might help|^You should really stand up first|You can't do that while sitting|You must be standing to do that|You can't do that while lying down/
      fput 'stand'
      waitrt?
      put_dir.call
    elsif line == "You're still recovering from your recent cast."
      sleep 2
      put_dir.call
    elsif line =~ /^The ground approaches you at an alarming rate/
      sleep 1
      fput 'stand' unless standing?
      put_dir.call
    elsif line =~ /You go flying down several feet, landing with a/
      sleep 1
      fput 'stand' unless standing?
      put_dir.call
    elsif line =~ /^Sorry, you may only type ahead/
      sleep 1
      put_dir.call
    elsif line == 'You are still stunned.'
      wait_while { stunned? }
      put_dir.call
    elsif line =~ /you slip (?:on a patch of ice )?and flail uselessly as you land on your rear(?:\.|!)$|You wobble and stumble only for a moment before landing flat on your face!$|^You slip in the mud and fall flat on your back\!$/
      waitrt?
      fput 'stand' unless standing?
      waitrt?
      put_dir.call
    elsif line =~ /^You flick your hand (?:up|down)wards and focus your aura on your disk, but your disk only wobbles briefly\.$/
      put_dir.call
    elsif line =~ /^You dive into the fast-moving river, but the current catches you and whips you back to shore, wet and battered\.$|^Running through the swampy terrain, you notice a wet patch in the bog|^You flounder around in the water.$|^You blunder around in the water, barely able|^You struggle against the swift current to swim|^You slap at the water in a sad failure to swim|^You work against the swift current to swim/
      waitrt?
      put_dir.call
    elsif line =~ /^(You notice .* at your feet, and do not wish to leave it behind|As you prepare to move away, you remember)/
      fput "stow feet"
      sleep 1
      put_dir.call
    elsif line == "You don't seem to be able to move to do that."
      30.times {
        break if clear.include?('You regain control of your senses!')

        sleep 0.1
      }
      put_dir.call
    elsif line =~ /^It's pitch dark and you can't see a thing!/
      echo "You will need a light source to continue your journey"
      return true
    end
    if XMLData.room_count > room_count
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return true
    end
    if Time.now.to_i >= giveup_time
      echo "move: no recognized response in #{giveup_seconds} seconds.  giving up."
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return nil
    end
    if line_count >= giveup_lines
      echo "move: no recognized response after #{line_count} lines.  giving up."
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return nil
    end
  }
end

def watchhealth(value, theproc = nil, &block)
  value = value.to_i
  if block.nil?
    if !theproc.respond_to? :call
      respond "`watchhealth' was not given a block or a proc to execute!"
      return nil
    else
      block = theproc
    end
  end
  Thread.new {
    wait_while { health(value) }
    block.call
  }
end

def wait_until(announce = nil)
  priosave = Thread.current.priority
  Thread.current.priority = 0
  unless announce.nil? or yield
    respond(announce)
  end
  until yield
    sleep 0.25
  end
  Thread.current.priority = priosave
end

def wait_while(announce = nil)
  priosave = Thread.current.priority
  Thread.current.priority = 0
  unless announce.nil? or !yield
    respond(announce)
  end
  while yield
    sleep 0.25
  end
  Thread.current.priority = priosave
end

def checkpaths(dir = "none")
  if dir == "none"
    if XMLData.room_exits.empty?
      return false
    else
      return XMLData.room_exits.collect { |room_exits| SHORTDIR[room_exits] }
    end
  else
    XMLData.room_exits.include?(dir) || XMLData.room_exits.include?(SHORTDIR[dir])
  end
end

def reverse_direction(dir)
  if dir == "n" then 's'
  elsif dir == "ne" then 'sw'
  elsif dir == "e" then 'w'
  elsif dir == "se" then 'nw'
  elsif dir == "s" then 'n'
  elsif dir == "sw" then 'ne'
  elsif dir == "w" then 'e'
  elsif dir == "nw" then 'se'
  elsif dir == "up" then 'down'
  elsif dir == "down" then 'up'
  elsif dir == "out" then 'out'
  elsif dir == 'o' then out
  elsif dir == 'u' then 'down'
  elsif dir == 'd' then up
  elsif dir == n then s
  elsif dir == ne then sw
  elsif dir == e then w
  elsif dir == se then nw
  elsif dir == s then n
  elsif dir == sw then ne
  elsif dir == w then e
  elsif dir == nw then se
  elsif dir == u then d
  elsif dir == d then u
  else
    echo("Cannot recognize direction to properly reverse it!"); false
  end
end

def walk(*boundaries, &block)
  boundaries.flatten!
  unless block.nil?
    until (val = yield)
      walk(*boundaries)
    end
    return val
  end
  if $last_dir and !boundaries.empty? and checkroomdescrip =~ /#{boundaries.join('|')}/i
    move($last_dir)
    $last_dir = reverse_direction($last_dir)
    return checknpcs
  end
  dirs = checkpaths
  return checknpcs if dirs.is_a?(FalseClass)
  dirs.delete($last_dir) unless dirs.length < 2
  this_time = rand(dirs.length)
  $last_dir = reverse_direction(dirs[this_time])
  move(dirs[this_time])
  checknpcs
end

def run
  loop { break unless walk }
end

def check_mind(string = nil)
  if string.nil?
    return XMLData.mind_text
  elsif (string.class == String) and (string.to_i == 0)
    if string =~ /#{XMLData.mind_text}/i
      return true
    else
      return false
    end
  elsif string.to_i.between?(0, 100)
    return string.to_i <= XMLData.mind_value.to_i
  else
    echo("check_mind error! You must provide an integer ranging from 0-100, the common abbreviation of how full your head is, or provide no input to have check_mind return an abbreviation of how filled your head is."); sleep 1
    return false
  end
end

def checkmind(string = nil)
  if string.nil?
    return XMLData.mind_text
  elsif string.class == String and string.to_i == 0
    if string =~ /#{XMLData.mind_text}/i
      return true
    else
      return false
    end
  elsif string.to_i.between?(1, 8)
    mind_state = ['clear as a bell', 'fresh and clear', 'clear', 'muddled', 'becoming numbed', 'numbed', 'must rest', 'saturated']
    if mind_state.index(XMLData.mind_text)
      mind = mind_state.index(XMLData.mind_text) + 1
      return string.to_i <= mind
    else
      echo "Bad string in checkmind: mind_state"
      nil
    end
  else
    echo("Checkmind error! You must provide an integer ranging from 1-8 (7 is fried, 8 is 100% fried), the common abbreviation of how full your head is, or provide no input to have checkmind return an abbreviation of how filled your head is."); sleep 1
    return false
  end
end

def percentmind(num = nil)
  if num.nil?
    XMLData.mind_value
  else
    XMLData.mind_value >= num.to_i
  end
end

def checkfried
  if XMLData.mind_text =~ /must rest|saturated/
    true
  else
    false
  end
end

def checksaturated
  if XMLData.mind_text =~ /saturated/
    true
  else
    false
  end
end

def checkmana(num = nil)
  if num.nil?
    XMLData.mana
  else
    XMLData.mana >= num.to_i
  end
end

def maxmana
  XMLData.max_mana
end

def percentmana(num = nil)
  if XMLData.max_mana == 0
    percent = 100
  else
    percent = ((XMLData.mana.to_f / XMLData.max_mana.to_f) * 100).to_i
  end
  if num.nil?
    percent
  else
    percent >= num.to_i
  end
end

def checkhealth(num = nil)
  if num.nil?
    XMLData.health
  else
    XMLData.health >= num.to_i
  end
end

def maxhealth
  XMLData.max_health
end

def percenthealth(num = nil)
  if num.nil?
    ((XMLData.health.to_f / XMLData.max_health.to_f) * 100).to_i
  else
    ((XMLData.health.to_f / XMLData.max_health.to_f) * 100).to_i >= num.to_i
  end
end

def checkspirit(num = nil)
  if num.nil?
    XMLData.spirit
  else
    XMLData.spirit >= num.to_i
  end
end

def maxspirit
  XMLData.max_spirit
end

def percentspirit(num = nil)
  if num.nil?
    ((XMLData.spirit.to_f / XMLData.max_spirit.to_f) * 100).to_i
  else
    ((XMLData.spirit.to_f / XMLData.max_spirit.to_f) * 100).to_i >= num.to_i
  end
end

def checkstamina(num = nil)
  if num.nil?
    XMLData.stamina
  else
    XMLData.stamina >= num.to_i
  end
end

def maxstamina()
  XMLData.max_stamina
end

def percentstamina(num = nil)
  if XMLData.max_stamina == 0
    percent = 100
  else
    percent = ((XMLData.stamina.to_f / XMLData.max_stamina.to_f) * 100).to_i
  end
  if num.nil?
    percent
  else
    percent >= num.to_i
  end
end

def maxconcentration()
  XMLData.max_concentration
end

def percentconcentration(num = nil)
  if XMLData.max_concentration == 0
    percent == 100
  else
    percent = ((XMLData.concentration.to_f / XMLData.max_concentration.to_f) * 100).to_i
  end
  if num.nil?
    percent
  else
    percent >= num.to_i
  end
end

def checkstance(num = nil)
  if num.nil?
    XMLData.stance_text
  elsif (num.class == String) and (num.to_i == 0)
    if num =~ /off/i
      XMLData.stance_value == 0
    elsif num =~ /adv/i
      XMLData.stance_value.between?(01, 20)
    elsif num =~ /for/i
      XMLData.stance_value.between?(21, 40)
    elsif num =~ /neu/i
      XMLData.stance_value.between?(41, 60)
    elsif num =~ /gua/i
      XMLData.stance_value.between?(61, 80)
    elsif num =~ /def/i
      XMLData.stance_value == 100
    else
      echo "checkstance: invalid argument (#{num}).  Must be off/adv/for/neu/gua/def or 0-100"
      nil
    end
  elsif (num.class == Integer) or (num =~ /^[0-9]+$/ and (num = num.to_i))
    XMLData.stance_value == num.to_i
  else
    echo "checkstance: invalid argument (#{num}).  Must be off/adv/for/neu/gua/def or 0-100"
    nil
  end
end

def percentstance(num = nil)
  if num.nil?
    XMLData.stance_value
  else
    XMLData.stance_value >= num.to_i
  end
end

def checkencumbrance(string = nil)
  if string.nil?
    XMLData.encumbrance_text
  elsif (string.class == Integer) or (string =~ /^[0-9]+$/ and (string = string.to_i))
    string <= XMLData.encumbrance_value
  else
    # fixme
    if string =~ /#{XMLData.encumbrance_text}/i
      true
    else
      false
    end
  end
end

def percentencumbrance(num = nil)
  if num.nil?
    XMLData.encumbrance_value
  else
    num.to_i <= XMLData.encumbrance_value
  end
end

def checkarea(*strings)
  strings.flatten!
  if strings.empty?
    XMLData.room_title.split(',').first.sub('[', '')
  else
    XMLData.room_title.split(',').first =~ /#{strings.join('|')}/i
  end
end

def checkroom(*strings)
  strings.flatten!
  if strings.empty?
    XMLData.room_title.chomp
  else
    XMLData.room_title =~ /#{strings.join('|')}/i
  end
end

def outside?
  if XMLData.room_exits_string =~ /Obvious paths:/
    true
  else
    false
  end
end

def checkfamarea(*strings)
  strings.flatten!
  if strings.empty? then return XMLData.familiar_room_title.split(',').first.sub('[', '') end

  XMLData.familiar_room_title.split(',').first =~ /#{strings.join('|')}/i
end

def checkfampaths(dir = "none")
  if dir == "none"
    if XMLData.familiar_room_exits.empty?
      return false
    else
      return XMLData.familiar_room_exits
    end
  else
    XMLData.familiar_room_exits.include?(dir)
  end
end

def checkfamroom(*strings)
  strings.flatten!; if strings.empty? then return XMLData.familiar_room_title.chomp end

  XMLData.familiar_room_title =~ /#{strings.join('|')}/i
end

def checkfamnpcs(*strings)
  parsed = Array.new
  XMLData.familiar_npcs.each { |val| parsed.push(val.split.last) }
  if strings.empty?
    if parsed.empty?
      return false
    else
      return parsed
    end
  else
    if (mtch = strings.find { |lookfor| parsed.find { |critter| critter =~ /#{lookfor}/ } })
      return mtch
    else
      return false
    end
  end
end

def checkfampcs(*strings)
  familiar_pcs = Array.new
  XMLData.familiar_pcs.to_s.gsub(/Lord |Lady |Great |High |Renowned |Grand |Apprentice |Novice |Journeyman /, '').split(',').each { |line| familiar_pcs.push(line.slice(/[A-Z][a-z]+/)) }
  if familiar_pcs.empty?
    return false
  elsif strings.empty?
    return familiar_pcs
  else
    regexpstr = strings.join('|\b')
    peeps = familiar_pcs.find_all { |val| val =~ /\b#{regexpstr}/i }
    if peeps.empty?
      return false
    else
      return peeps
    end
  end
end

def checkpcs(*strings)
  pcs = GameObj.pcs.collect { |pc| pc.noun }
  if pcs.empty?
    if strings.empty? then return nil else return false end
  end
  strings.flatten!
  if strings.empty?
    pcs
  else
    regexpstr = strings.join(' ')
    pcs.find { |pc| regexpstr =~ /\b#{pc}/i }
  end
end

def checknpcs(*strings)
  npcs = GameObj.npcs.collect { |npc| npc.noun }
  if npcs.empty?
    if strings.empty? then return nil else return false end
  end
  strings.flatten!
  if strings.empty?
    npcs
  else
    regexpstr = strings.join(' ')
    npcs.find { |npc| regexpstr =~ /\b#{npc}/i }
  end
end

def count_npcs
  checknpcs.length
end

def checkright(*hand)
  if GameObj.right_hand.nil? then return nil end

  hand.flatten!
  if GameObj.right_hand.name == "Empty" or GameObj.right_hand.name.empty?
    nil
  elsif hand.empty?
    GameObj.right_hand.noun
  else
    hand.find { |instance| GameObj.right_hand.name =~ /#{instance}/i }
  end
end

def checkleft(*hand)
  if GameObj.left_hand.nil? then return nil end

  hand.flatten!
  if GameObj.left_hand.name == "Empty" or GameObj.left_hand.name.empty?
    nil
  elsif hand.empty?
    GameObj.left_hand.noun
  else
    hand.find { |instance| GameObj.left_hand.name =~ /#{instance}/i }
  end
end

def checkroomdescrip(*val)
  val.flatten!
  if val.empty?
    return XMLData.room_description
  else
    return XMLData.room_description =~ /#{val.join('|')}/i
  end
end

def checkfamroomdescrip(*val)
  val.flatten!
  if val.empty?
    return XMLData.familiar_room_description
  else
    return XMLData.familiar_room_description =~ /#{val.join('|')}/i
  end
end

def checkspell(*spells)
  spells.flatten!
  return false if Spell.active.empty?

  spells.each { |spell| return false unless Spell[spell].active? }
  true
end

def checkprep(spell = nil)
  if spell.nil?
    XMLData.prepared_spell
  elsif spell.class != String
    echo("Checkprep error, spell # not implemented!  You must use the spell name")
    false
  else
    XMLData.prepared_spell =~ /^#{spell}/i
  end
end

def setpriority(val = nil)
  if val.nil? then return Thread.current.priority end

  if val.to_i > 3
    echo("You're trying to set a script's priority as being higher than the send/recv threads (this is telling Lich to run the script before it even gets data to give the script, and is useless); the limit is 3")
    return Thread.current.priority
  else
    Thread.current.group.list.each { |thr| thr.priority = val.to_i }
    return Thread.current.priority
  end
end

def checkbounty
  if XMLData.bounty_task
    return XMLData.bounty_task
  else
    return nil
  end
end

def checksleeping
  return Status.sleeping? if XMLData.game =~ /GS/
  fail "Error: toplevel checksleeping command not enabled in #{XMLData.game}"
end

def sleeping?
  return Status.sleeping? if XMLData.game =~ /GS/
  fail "Error: toplevel sleeping? command not enabled in #{XMLData.game}"
end

def checkbound
  return Status.bound? if XMLData.game =~ /GS/
  fail "Error: toplevel checkbound command not enabled in #{XMLData.game}"
end

def bound?
  return Status.bound? if XMLData.game =~ /GS/
  fail "Error: toplevel bound? command not enabled in #{XMLData.game}"
end

def checksilenced
  return Status.silenced? if XMLData.game =~ /GS/
  fail "Error: toplevel checksilenced command not enabled in #{XMLData.game}"
end

def silenced?
  return Status.silenced? if XMLData.game =~ /GS/
  fail "Error: toplevel silenced command not enabled in #{XMLData.game}"
end

def checkcalmed
  return Status.calmed? if XMLData.game =~ /GS/
  fail "Error: toplevel checkcalmed command not enabled in #{XMLData.game}"
end

def calmed?
  return Status.calmed? if XMLData.game =~ /GS/
  fail "Error: toplevel calmed? command not enabled in #{XMLData.game}"
end

def checkcutthroat
  return Status.cutthroat? if XMLData.game =~ /GS/
  fail "Error: toplevel checkcutthroat command not enabled in #{XMLData.game}"
end

def cutthroat?
  return Status.cutthroat? if XMLData.game =~ /GS/
  fail "Error: toplevel cutthroat? command not enabled in #{XMLData.game}"
end

def variable
  unless (script = Script.current) then echo 'variable: cannot identify calling script.'; return nil; end
  script.vars
end

def pause(num = 1)
  if num.to_s =~ /m/
    sleep((num.sub(/m/, '').to_f * 60))
  elsif num.to_s =~ /h/
    sleep((num.sub(/h/, '').to_f * 3600))
  elsif num.to_s =~ /d/
    sleep((num.sub(/d/, '').to_f * 86400))
  else
    sleep(num.to_f)
  end
end

def cast(spell, target = nil, results_of_interest = nil)
  if spell.class == Spell
    spell.cast(target, results_of_interest)
  elsif ((spell.class == Integer) or (spell.to_s =~ /^[0-9]+$/)) and (find_spell = Spell[spell.to_i])
    find_spell.cast(target, results_of_interest)
  elsif (spell.class == String) and (find_spell = Spell[spell])
    find_spell.cast(target, results_of_interest)
  else
    echo "cast: invalid spell (#{spell})"
    false
  end
end

def clear(_opt = 0)
  unless (script = Script.current) then respond('--- clear: Unable to identify calling script.'); return false; end
  to_return = script.downstream_buffer.dup
  script.downstream_buffer.clear
  to_return
end

def match(label, string)
  strings = [label, string]
  strings.flatten!
  unless (script = Script.current) then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("Error! 'match' was given no strings to look for!"); sleep 1; return false end
  unless strings.length == 2
    while (line_in = script.gets)
      strings.each { |string|
        if line_in =~ /#{string}/ then return $~.to_s end
      }
    end
  else
    if script.respond_to?(:match_stack_add)
      script.match_stack_add(strings.first.to_s, strings.last)
    else
      script.match_stack_labels.push(strings[0].to_s)
      script.match_stack_strings.push(strings[1])
    end
  end
end

def matchtimeout(secs, *strings)
  unless (Script.current) then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  unless (secs.class == Float || secs.class == Integer)
    echo('matchtimeout error! You appear to have given it a string, not a #! Syntax:  matchtimeout(30, "You stand up")')
    return false
  end
  strings.flatten!
  if strings.empty?
    echo("matchtimeout without any strings to wait for!")
    sleep 1
    return false
  end
  regexpstr = strings.join('|')
  end_time = Time.now.to_f + secs
  loop {
    line = get?
    if line.nil?
      sleep 0.1
    elsif line =~ /#{regexpstr}/i
      return line
    end
    if (Time.now.to_f > end_time)
      return false
    end
  }
end

def matchbefore(*strings)
  strings.flatten!
  unless (script = Script.current) then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("matchbefore without any strings to wait for!"); return false end
  regexpstr = strings.join('|')
  loop { if (script.gets) =~ /#{regexpstr}/ then return $`.to_s end }
end

def matchafter(*strings)
  strings.flatten!
  unless (script = Script.current) then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("matchafter without any strings to wait for!"); return end
  regexpstr = strings.join('|')
  loop { if (script.gets) =~ /#{regexpstr}/ then return $'.to_s end }
end

def matchboth(*strings)
  strings.flatten!
  unless (script = Script.current) then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("matchboth without any strings to wait for!"); return end
  regexpstr = strings.join('|')
  loop { if (script.gets) =~ /#{regexpstr}/ then break end }
  return [$`.to_s, $'.to_s]
end

def matchwait(*strings)
  unless (script = Script.current) then respond('--- matchwait: Unable to identify calling script.'); return false; end
  strings.flatten!
  unless strings.empty?
    regexpstr = strings.collect { |str| str.kind_of?(Regexp) ? str.source : str }.join('|')
    regexobj = /#{regexpstr}/
    while (line_in = script.gets)
      return line_in if line_in =~ regexobj
    end
  else
    strings = script.match_stack_strings
    labels = script.match_stack_labels
    regexpstr = /#{strings.join('|')}/i
    while (line_in = script.gets)
      if (mdata = regexpstr.match(line_in))
        jmp = labels[strings.index(mdata.to_s) || strings.index(strings.find { |str| line_in =~ /#{str}/i })]
        script.match_stack_clear
        goto jmp
      end
    end
  end
end

def waitforre(regexp)
  unless (script = Script.current) then respond('--- waitforre: Unable to identify calling script.'); return false; end
  unless regexp.class == Regexp then echo("Script error! You have given 'waitforre' something to wait for, but it isn't a Regular Expression! Use 'waitfor' if you want to wait for a string."); sleep 1; return nil end
  regobj = regexp.match(script.gets) until regobj
end

def waitfor(*strings)
  unless (script = Script.current) then respond('--- waitfor: Unable to identify calling script.'); return false; end
  strings.flatten!
  if (script.class == WizardScript) and (strings.length == 1) and (strings.first.strip == '>')
    return script.gets
  end

  if strings.empty?
    echo 'waitfor: no string to wait for'
    return false
  end
  regexpstr = strings.join('|')
  while true
    line_in = script.gets
    if (line_in =~ /#{regexpstr}/i) then return line_in end
  end
end

def wait
  unless (script = Script.current) then respond('--- wait: unable to identify calling script.'); return false; end
  script.clear
  return script.gets
end

def get
  Script.current.gets
end

def get?
  Script.current.gets?
end

def reget(*lines)
  unless (script = Script.current) then respond('--- reget: Unable to identify calling script.'); return false; end
  lines.flatten!
  if caller.find { |c| c =~ /regetall/ }
    history = ($_SERVERBUFFER_.history + $_SERVERBUFFER_).join("\n")
  else
    history = $_SERVERBUFFER_.dup.join("\n")
  end
  unless script.want_downstream_xml
    history.gsub!(/<pushStream id=["'](?:spellfront|inv|bounty|society)["'][^>]*\/>.*?<popStream[^>]*>/m, '')
    history.gsub!(/<stream id="Spells">.*?<\/stream>/m, '')
    history.gsub!(/<(compDef|inv|component|right|left|spell|prompt)[^>]*>.*?<\/\1>/m, '')
    history.gsub!(/<[^>]+>/, '')
    history.gsub!('&gt;', '>')
    history.gsub!('&lt;', '<')
  end
  history = history.split("\n").delete_if { |line| line.nil? or line.empty? or line =~ /^[\r\n\s\t]*$/ }
  if lines.first.kind_of?(Numeric) or lines.first.to_i.nonzero?
    history = history[-([lines.shift.to_i, history.length].min)..-1]
  end
  unless lines.empty? or lines.nil?
    regex = /#{lines.join('|')}/i
    history = history.find_all { |line| line =~ regex }
  end
  if history.empty?
    nil
  else
    history
  end
end

def regetall(*lines)
  reget(*lines)
end

def multifput(*cmds)
  cmds.flatten.compact.each { |cmd| fput(cmd) }
end

def fput(message, *waitingfor)
  unless (script = Script.current) then respond('--- waitfor: Unable to identify calling script.'); return false; end
  waitingfor.flatten!
  clear
  put(message)

  while (string = get)
    if string =~ /(?:\.\.\.wait |Wait )[0-9]+/
      hold_up = string.slice(/[0-9]+/).to_i
      sleep(hold_up) unless hold_up.nil?
      clear
      put(message)
      next
    elsif string =~ /^You.+struggle.+stand/
      clear
      fput 'stand'
      next
    elsif string =~ /stunned|can't do that while|cannot seem|^(?!You rummage).*can't seem|don't seem|Sorry, you may only type ahead/
      if dead?
        echo "You're dead...! You can't do that!"
        sleep 1
        script.downstream_buffer.unshift(string)
        return false
      elsif checkstunned
        while checkstunned
          sleep("0.25".to_f)
        end
      elsif checkwebbed
        while checkwebbed
          sleep("0.25".to_f)
        end
      elsif string =~ /Sorry, you may only type ahead/
        sleep 1
      else
        sleep 0.1
        script.downstream_buffer.unshift(string)
        return false
      end
      clear
      put(message)
      next
    else
      if waitingfor.empty?
        script.downstream_buffer.unshift(string)
        return string
      else
        if (foundit = waitingfor.find { |val| string =~ /#{val}/i })
          script.downstream_buffer.unshift(string)
          return foundit
        end
        sleep 1
        clear
        put(message)
        next
      end
    end
  end
end

def put(*messages)
  messages.each { |message| Game.puts(message) }
end

def quiet_exit
  script = Script.current
  script.quiet = !(script.quiet)
end

def matchfindexact(*strings)
  strings.flatten!
  unless (script = Script.current) then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("error! 'matchfind' with no strings to look for!"); sleep 1; return false end
  looking = Array.new
  strings.each { |str| looking.push(str.gsub('?', '(\b.+\b)')) }
  if looking.empty? then echo("matchfind without any strings to wait for!"); return false end
  regexpstr = looking.join('|')
  while (line_in = script.gets)
    if (gotit = line_in.slice(/#{regexpstr}/))
      matches = Array.new
      looking.each_with_index { |str, idx|
        if gotit =~ /#{str}/i
          strings[idx].count('?').times { |n| matches.push(eval("$#{n + 1}")) }
        end
      }
      break
    end
  end
  if matches.length == 1
    return matches.first
  else
    return matches.compact
  end
end

def matchfind(*strings)
  regex = /#{strings.flatten.join('|').gsub('?', '(.+)')}/i
  unless (script = Script.current)
    respond "Unknown script is asking to use matchfind!  Cannot process request without identifying the calling script; killing this thread."
    Thread.current.kill
  end
  while true
    if (reobj = regex.match(script.gets))
      ret = reobj.captures.compact
      if ret.length < 2
        return ret.first
      else
        return ret
      end
    end
  end
end

def matchfindword(*strings)
  regex = /#{strings.flatten.join('|').gsub('?', '([\w\d]+)')}/i
  unless (script = Script.current)
    respond "Unknown script is asking to use matchfindword!  Cannot process request without identifying the calling script; killing this thread."
    Thread.current.kill
  end
  while true
    if (reobj = regex.match(script.gets))
      ret = reobj.captures.compact
      if ret.length < 2
        return ret.first
      else
        return ret
      end
    end
  end
end

def send_scripts(*messages)
  messages.flatten!
  messages.each { |message|
    Script.new_downstream(message)
  }
  true
end

def status_tags(onoff = "none")
  script = Script.current
  if onoff == "on"
    script.want_downstream = false
    script.want_downstream_xml = true
    echo("Status tags will be sent to this script.")
  elsif onoff == "off"
    script.want_downstream = true
    script.want_downstream_xml = false
    echo("Status tags will no longer be sent to this script.")
  elsif script.want_downstream_xml
    script.want_downstream = true
    script.want_downstream_xml = false
  else
    script.want_downstream = false
    script.want_downstream_xml = true
  end
end

def respond(first = "", *messages)
  str = ''
  begin
    if first.class == Array
      first.flatten.each { |ln| str += sprintf("%s\r\n", ln.to_s.chomp) }
    else
      str += sprintf("%s\r\n", first.to_s.chomp)
    end
    messages.flatten.each { |message| str += sprintf("%s\r\n", message.to_s.chomp) }
    str.split(/\r?\n/).each { |line| Script.new_script_output(line); Buffer.update(line, Buffer::SCRIPT_OUTPUT) }
    # str.gsub!(/\r?\n/, "\r\n") if $frontend == 'genie'
    if $frontend == 'stormfront' || $frontend == 'genie'
      str = "<output class=\"mono\"/>\r\n#{str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')}<output class=\"\"/>\r\n"
    elsif $frontend == 'profanity'
      str = str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end
    # Double-checked locking to avoid interrupting a stream and crashing the client
    str_sent = false
    if $_CLIENT_
      until str_sent
        wait_while { !XMLData.safe_to_respond? }
        str_sent = $_CLIENT_.puts_if(str) { XMLData.safe_to_respond? }
      end
    end
    if $_DETACHABLE_CLIENT_
      str_sent = false
      until str_sent
        wait_while { !XMLData.safe_to_respond? }
        begin
          str_sent = $_DETACHABLE_CLIENT_.puts_if(str) { XMLData.safe_to_respond? }
        rescue
          break
        end
      end
    end
  rescue
    puts $!
    puts $!.backtrace.first
  end
end

def _respond(first = "", *messages)
  str = ''
  begin
    if first.class == Array
      first.flatten.each { |ln| str += sprintf("%s\r\n", ln.to_s.chomp) }
    else
      str += sprintf("%s\r\n", first.to_s.chomp)
    end
    # str.gsub!(/\r?\n/, "\r\n") if $frontend == 'genie'
    messages.flatten.each { |message| str += sprintf("%s\r\n", message.to_s.chomp) }
    str.split(/\r?\n/).each { |line| Script.new_script_output(line); Buffer.update(line, Buffer::SCRIPT_OUTPUT) } # fixme: strip/separate script output?
    str_sent = false
    if $_CLIENT_
      until str_sent
        wait_while { !XMLData.safe_to_respond? }
        str_sent = $_CLIENT_.puts_if(str) { XMLData.safe_to_respond? }
      end
    end
    if $_DETACHABLE_CLIENT_
      str_sent = false
      until str_sent
        wait_while { !XMLData.safe_to_respond? }
        begin
          str_sent = $_DETACHABLE_CLIENT_.puts_if(str) { XMLData.safe_to_respond? }
        rescue
          break
        end
      end
    end
  rescue
    puts $!
    puts $!.backtrace.first
  end
end

def noded_pulse
  unless XMLData.game =~ /DR/
    if Stats.prof =~ /warrior|rogue|sorcerer/i
      stats = [Skills.smc.to_i, Skills.emc.to_i]
    elsif Stats.prof =~ /empath|bard/i
      stats = [Skills.smc.to_i, Skills.mmc.to_i]
    elsif Stats.prof =~ /wizard/i
      stats = [Skills.emc.to_i, 0]
    elsif Stats.prof =~ /paladin|cleric|ranger/i
      stats = [Skills.smc.to_i, 0]
    else
      stats = [0, 0]
    end
    return (maxmana * 25 / 100) + (stats.max / 10) + (stats.min / 20)
  else
    return 0 # this method is not used by DR
  end
end

def unnoded_pulse
  unless XMLData.game =~ /DR/
    if Stats.prof =~ /warrior|rogue|sorcerer/i
      stats = [Skills.smc.to_i, Skills.emc.to_i]
    elsif Stats.prof =~ /empath|bard/i
      stats = [Skills.smc.to_i, Skills.mmc.to_i]
    elsif Stats.prof =~ /wizard/i
      stats = [Skills.emc.to_i, 0]
    elsif Stats.prof =~ /paladin|cleric|ranger/i
      stats = [Skills.smc.to_i, 0]
    else
      stats = [0, 0]
    end
    return (maxmana * 15 / 100) + (stats.max / 10) + (stats.min / 20)
  else
    return 0 # this method is not used by DR
  end
end

require './lib/stash.rb'

def empty_hands
  waitrt?
  Lich::Stash::stash_hands(both: true)
end

def empty_hand
  right_hand = GameObj.right_hand
  left_hand = GameObj.left_hand

  unless (right_hand.id.nil? and ([Wounds.rightArm, Wounds.rightHand, Scars.rightArm, Scars.rightHand].max < 3)) or (left_hand.id.nil? and ([Wounds.leftArm, Wounds.leftHand, Scars.leftArm, Scars.leftHand].max < 3))
    if right_hand.id and ([Wounds.rightArm, Wounds.rightHand, Scars.rightArm, Scars.rightHand].max < 3 or [Wounds.leftArm, Wounds.leftHand, Scars.leftArm, Scars.leftHand].max == 3)
      waitrt?
      Lich::Stash::stash_hands(right: true)
    else
      waitrt?
      Lich::Stash::stash_hands(left: true)
    end
  end
end

def empty_right_hand
  waitrt?
  Lich::Stash::stash_hands(right: true)
end

def empty_left_hand
  waitrt?
  Lich::Stash::stash_hands(left: true)
end

def fill_hands
  waitrt?
  Lich::Stash::equip_hands(both: true)
end

def fill_hand
  waitrt?
  Lich::Stash::equip_hands()
end

def fill_right_hand
  waitrt?
  Lich::Stash::equip_hands(right: true)
end

def fill_left_hand
  waitrt?
  Lich::Stash::equip_hands(left: true)
end

def dothis(action, success_line)
  loop {
    Script.current.clear
    put action
    loop {
      line = get
      if line =~ success_line
        return line
      elsif line =~ /^(\.\.\.w|W)ait ([0-9]+) sec(onds)?\.$/
        if $2.to_i > 1
          sleep($2.to_i - "0.5".to_f)
        else
          sleep 0.3
        end
        break
      elsif line == 'Sorry, you may only type ahead 1 command.'
        sleep 1
        break
      elsif line == 'You are still stunned.'
        wait_while { stunned? }
        break
      elsif line == 'That is impossible to do while unconscious!'
        100.times {
          unless (line = get?)
            sleep 0.1
          else
            break if line =~ /Your thoughts slowly come back to you as you find yourself lying on the ground\.  You must have been sleeping\.$|^You wake up from your slumber\.$/
          end
        }
        break
      elsif line == "You don't seem to be able to move to do that."
        100.times {
          unless (line = get?)
            sleep 0.1
          else
            break if line == 'The restricting force that envelops you dissolves away.'
          end
        }
        break
      elsif line == "You can't do that while entangled in a web."
        wait_while { checkwebbed }
        break
      elsif line == 'You find that impossible under the effects of the lullabye.'
        100.times {
          unless (line = get?)
            sleep 0.1
          else
            # fixme
            break if line == 'You shake off the effects of the lullabye.'
          end
        }
        break
      end
    }
  }
end

def dothistimeout(action, timeout, success_line)
  end_time = Time.now.to_f + timeout
  line = nil
  loop {
    Script.current.clear
    put action unless action.nil?
    loop {
      line = get?
      if line.nil?
        sleep 0.1
      elsif line =~ success_line
        return line
      elsif line =~ /^(\.\.\.w|W)ait ([0-9]+) sec(onds)?\.$/
        if $2.to_i > 1
          sleep($2.to_i - "0.5".to_f)
        else
          sleep 0.3
        end
        end_time = Time.now.to_f + timeout
        break
      elsif line == 'Sorry, you may only type ahead 1 command.'
        sleep 1
        end_time = Time.now.to_f + timeout
        break
      elsif line == 'You are still stunned.'
        wait_while { stunned? }
        end_time = Time.now.to_f + timeout
        break
      elsif line == 'That is impossible to do while unconscious!'
        100.times {
          unless (line = get?)
            sleep 0.1
          else
            break if line =~ /Your thoughts slowly come back to you as you find yourself lying on the ground\.  You must have been sleeping\.$|^You wake up from your slumber\.$/
          end
        }
        break
      elsif line == "You don't seem to be able to move to do that."
        100.times {
          unless (line = get?)
            sleep 0.1
          else
            break if line == 'The restricting force that envelops you dissolves away.'
          end
        }
        break
      elsif line == "You can't do that while entangled in a web."
        wait_while { checkwebbed }
        break
      elsif line == 'You find that impossible under the effects of the lullabye.'
        100.times {
          unless (line = get?)
            sleep 0.1
          else
            # fixme
            break if line == 'You shake off the effects of the lullabye.'
          end
        }
        break
      end
      if Time.now.to_f >= end_time
        return nil
      end
    }
  }
end

$link_highlight_start = ''
$link_highlight_end = ''
$speech_highlight_start = ''
$speech_highlight_end = ''

def fb_to_sf(line)
  begin
    return line if line == "\r\n"

    line = line.gsub(/<c>/, "")
    return nil if line.gsub("\r\n", '').length < 1

    return line
  rescue
    $_CLIENT_.puts "--- Error: fb_to_sf: #{$!}"
    $_CLIENT_.puts '$_SERVERSTRING_: ' + $_SERVERSTRING_.to_s
  end
end

def sf_to_wiz(line)
  begin
    return line if line == "\r\n"

    if $sftowiz_multiline
      $sftowiz_multiline = $sftowiz_multiline + line
      line = $sftowiz_multiline
    end
    if (line.scan(/<pushStream[^>]*\/>/).length > line.scan(/<popStream[^>]*\/>/).length)
      $sftowiz_multiline = line
      return nil
    end
    if (line.scan(/<style id="\w+"[^>]*\/>/).length > line.scan(/<style id=""[^>]*\/>/).length)
      $sftowiz_multiline = line
      return nil
    end
    $sftowiz_multiline = nil
    if line =~ /<LaunchURL src="(.*?)" \/>/
      $_CLIENT_.puts "\034GSw00005\r\nhttps://www.play.net#{$1}\r\n"
    end
    if line =~ /<preset id='speech'>(.*?)<\/preset>/m
      line = line.sub(/<preset id='speech'>.*?<\/preset>/m, "#{$speech_highlight_start}#{$1}#{$speech_highlight_end}")
    end
    if line =~ /<pushStream id="thoughts"[^>]*>\[([^\\]+?)\]\s*(.*?)<popStream\/>/m
      thought_channel = $1
      msg = $2
      thought_channel.gsub!(' ', '-')
      msg.gsub!('<pushBold/>', '')
      msg.gsub!('<popBold/>', '')
      line = line.sub(/<pushStream id="thoughts".*<popStream\/>/m, "You hear the faint thoughts of [#{thought_channel}]-ESP echo in your mind:\r\n#{msg}")
    end
    if line =~ /<pushStream id="voln"[^>]*>\[Voln \- (?:<a[^>]*>)?([A-Z][a-z]+)(?:<\/a>)?\]\s*(".*")[\r\n]*<popStream\/>/m
      line = line.sub(/<pushStream id="voln"[^>]*>\[Voln \- (?:<a[^>]*>)?([A-Z][a-z]+)(?:<\/a>)?\]\s*(".*")[\r\n]*<popStream\/>/m, "The Symbol of Thought begins to burn in your mind and you hear #{$1} thinking, #{$2}\r\n")
    end
    if line =~ /<stream id="thoughts"[^>]*>([^:]+): (.*?)<\/stream>/m
      line = line.sub(/<stream id="thoughts"[^>]*>.*?<\/stream>/m, "You hear the faint thoughts of #{$1} echo in your mind:\r\n#{$2}")
    end
    if line =~ /<pushStream id="familiar"[^>]*>(.*)<popStream\/>/m
      line = line.sub(/<pushStream id="familiar"[^>]*>.*<popStream\/>/m, "\034GSe\r\n#{$1}\034GSf\r\n")
    end
    if line =~ /<pushStream id="death"\/>(.*?)<popStream\/>/m
      line = line.sub(/<pushStream id="death"\/>.*?<popStream\/>/m, "\034GSw00003\r\n#{$1}\034GSw00004\r\n")
    end
    if line =~ /<style id="roomName" \/>(.*?)<style id=""\/>/m
      line = line.sub(/<style id="roomName" \/>.*?<style id=""\/>/m, "\034GSo\r\n#{$1}\034GSp\r\n")
    end
    line.gsub!(/<style id="roomDesc"\/><style id=""\/>\r?\n/, '')
    if line =~ /<style id="roomDesc"\/>(.*?)<style id=""\/>/m
      desc = $1.gsub(/<a[^>]*>/, $link_highlight_start).gsub("</a>", $link_highlight_end)
      line = line.sub(/<style id="roomDesc"\/>.*?<style id=""\/>/m, "\034GSH\r\n#{desc}\034GSI\r\n")
    end
    line = line.gsub("</prompt>\r\n", "</prompt>")
    line = line.gsub("<pushBold/>", "\034GSL\r\n")
    line = line.gsub("<popBold/>", "\034GSM\r\n")
    line = line.gsub(/<pushStream id=["'](?:spellfront|inv|bounty|society|speech|talk)["'][^>]*\/>.*?<popStream[^>]*>/m, '')
    line = line.gsub(/<stream id="Spells">.*?<\/stream>/m, '')
    line = line.gsub(/<(compDef|inv|component|right|left|spell|prompt)[^>]*>.*?<\/\1>/m, '')
    line = line.gsub(/<[^>]+>/, '')
    line = line.gsub('&gt;', '>')
    line = line.gsub('&lt;', '<')
    line = line.gsub('&amp;', '&')
    return nil if line.gsub("\r\n", '').length < 1

    return line
  rescue
    $_CLIENT_.puts "--- Error: sf_to_wiz: #{$!}"
    $_CLIENT_.puts '$_SERVERSTRING_: ' + $_SERVERSTRING_.to_s
  end
end

def strip_xml(line)
  return line if line == "\r\n"

  if $strip_xml_multiline
    $strip_xml_multiline = $strip_xml_multiline + line
    line = $strip_xml_multiline
  end
  if (line.scan(/<pushStream[^>]*\/>/).length > line.scan(/<popStream[^>]*\/>/).length)
    $strip_xml_multiline = line
    return nil
  end
  $strip_xml_multiline = nil

  line = line.gsub(/<pushStream id=["'](?:spellfront|inv|bounty|society|speech|talk)["'][^>]*\/>.*?<popStream[^>]*>/m, '')
  line = line.gsub(/<stream id="Spells">.*?<\/stream>/m, '')
  line = line.gsub(/<(compDef|inv|component|right|left|spell|prompt)[^>]*>.*?<\/\1>/m, '')
  line = line.gsub(/<[^>]+>/, '')
  line = line.gsub('&gt;', '>')
  line = line.gsub('&lt;', '<')

  return nil if line.gsub("\n", '').gsub("\r", '').gsub(' ', '').length < 1

  return line
end

def monsterbold_start
  if $frontend =~ /^(?:wizard|avalon)$/
    "\034GSL\r\n"
  elsif $frontend =~ /^(?:stormfront|frostbite)$/
    '<pushBold/>'
  elsif $frontend == 'profanity'
    '<b>'
  else
    ''
  end
end

def monsterbold_end
  if $frontend =~ /^(?:wizard|avalon)$/
    "\034GSM\r\n"
  elsif $frontend =~ /^(?:stormfront|frostbite)$/
    '<popBold/>'
  elsif $frontend == 'profanity'
    '</b>'
  else
    ''
  end
end

def do_client(client_string)
  client_string.strip!
  #   Buffer.update(client_string, Buffer::UPSTREAM)
  client_string = UpstreamHook.run(client_string)
  #   Buffer.update(client_string, Buffer::UPSTREAM_MOD)
  return nil if client_string.nil?

  if client_string =~ /^(?:<c>)?#{$lich_char_regex}(.+)$/
    cmd = $1
    if cmd =~ /^k$|^kill$|^stop$/
      if Script.running.empty?
        respond '--- Lich: no scripts to kill'
      else
        Script.running.last.kill
      end
    elsif cmd =~ /^p$|^pause$/
      if (s = Script.running.reverse.find { |s_check| not s_check.paused? })
        s.pause
      else
        respond '--- Lich: no scripts to pause'
      end
      nil
    elsif cmd =~ /^u$|^unpause$/
      if (s = Script.running.reverse.find { |s_check| s_check.paused? })
        s.unpause
      else
        respond '--- Lich: no scripts to unpause'
      end
      nil
    elsif cmd =~ /^ka$|^kill\s?all$|^stop\s?all$/
      did_something = false
      Script.running.find_all { |s_check| not s_check.no_kill_all }.each { |s_check| s_check.kill; did_something = true }
      respond('--- Lich: no scripts to kill') unless did_something
    elsif cmd =~ /^pa$|^pause\s?all$/
      did_something = false
      Script.running.find_all { |s_check| not s_check.paused? and not s_check.no_pause_all }.each { |s_check| s_check.pause; did_something = true }
      respond('--- Lich: no scripts to pause') unless did_something
    elsif cmd =~ /^ua$|^unpause\s?all$/
      did_something = false
      Script.running.find_all { |s_check| s_check.paused? and not s_check.no_pause_all }.each { |s_check| s_check.unpause; did_something = true }
      respond('--- Lich: no scripts to unpause') unless did_something
    elsif cmd =~ /^(k|kill|stop|p|pause|u|unpause)\s(.+)/
      action = $1
      target = $2
      script = Script.running.find { |s_running| s_running.name == target } || Script.hidden.find { |s_hidden| s_hidden.name == target } || Script.running.find { |s_running| s_running.name =~ /^#{target}/i } || Script.hidden.find { |s_hidden| s_hidden.name =~ /^#{target}/i }
      if script.nil?
        respond "--- Lich: #{target} does not appear to be running! Use ';list' or ';listall' to see what's active."
      elsif action =~ /^(?:k|kill|stop)$/
        script.kill
      elsif action =~ /^(?:p|pause)$/
        script.pause
      elsif action =~ /^(?:u|unpause)$/
        script.unpause
      end
      target = nil
    elsif cmd =~ /^list\s?(?:all)?$|^l(?:a)?$/i
      if cmd =~ /a(?:ll)?/i
        list = Script.running + Script.hidden
      else
        list = Script.running
      end
      if list.empty?
        respond '--- Lich: no active scripts'
      else
        respond "--- Lich: #{list.collect { |active| active.paused? ? "#{active.name} (paused)" : active.name }.join(", ")}"
      end
      nil
    elsif cmd =~ /^force\s+[^\s]+/
      if cmd =~ /^force\s+([^\s]+)\s+(.+)$/
        Script.start($1, $2, :force => true)
      elsif cmd =~ /^force\s+([^\s]+)/
        Script.start($1, :force => true)
      end
    elsif cmd =~ /^send |^s /
      if cmd.split[1] == "to"
        script = (Script.running + Script.hidden).find { |scr| scr.name == cmd.split[2].chomp.strip } || script = (Script.running + Script.hidden).find { |scr| scr.name =~ /^#{cmd.split[2].chomp.strip}/i }
        if script
          msg = cmd.split[3..-1].join(' ').chomp
          if script.want_downstream
            script.downstream_buffer.push(msg)
          else
            script.unique_buffer.push(msg)
          end
          respond "--- sent to '#{script.name}': #{msg}"
        else
          respond "--- Lich: '#{cmd.split[2].chomp.strip}' does not match any active script!"
        end
        nil
      else
        if Script.running.empty? and Script.hidden.empty?
          respond('--- Lich: no active scripts to send to.')
        else
          msg = cmd.split[1..-1].join(' ').chomp
          respond("--- sent: #{msg}")
          Script.new_downstream(msg)
        end
      end
    elsif cmd =~ /^(?:exec|e)(q)? (.+)$/
      cmd_data = $2
      ExecScript.start(cmd_data, { :quiet => $1 })
    elsif cmd =~ /^(?:execname|en) ([\w\d-]+) (.+)$/
      execname = $1
      cmd_data = $2
      ExecScript.start(cmd_data, { :name => execname })
    elsif cmd =~ /^trust\s+(.*)/i
      script_name = $1
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
    elsif cmd =~ /^(?:dis|un)trust\s+(.*)/i
      script_name = $1
      if RUBY_VERSION =~ /^2\.[012]\./
        if Script.distrust(script_name)
          respond "--- Lich: '#{script_name}' is no longer a trusted script."
        else
          respond "--- Lich: '#{script_name}' was not found in the trusted script list."
        end
      else
        respond "--- Lich: this feature isn't available in this version of Ruby "
      end
    elsif cmd =~ /^list\s?(?:un)?trust(?:ed)?$|^lt$/i
      if RUBY_VERSION =~ /^2\.[012]\./
        list = Script.list_trusted
        if list.empty?
          respond "--- Lich: no scripts are trusted"
        else
          respond "--- Lich: trusted scripts: #{list.join(', ')}"
        end
        nil
      else
        respond "--- Lich: this feature isn't available in this version of Ruby "
      end
    elsif cmd =~ /^set\s(.+)\s(on|off)/
      toggle_var = $1
      set_state = $2
      did_something = false
      begin
        Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) values(?,?);", toggle_var.to_s.encode('UTF-8'), set_state.to_s.encode('UTF-8'))
        did_something = true
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
      respond("--- Lich: toggle #{toggle_var} set #{set_state}") if did_something
      did_something = false
      nil
    elsif cmd =~ /^hmr\s+(?<pattern>.*)/i
      require "lib/hmr"
      HMR.reload %r{#{Regexp.last_match[:pattern]}}
    elsif XMLData.game =~ /^GS/ && cmd =~ /^infomon sync/i
      ExecScript.start("Infomon.sync", { :quiet => true })
    elsif XMLData.game =~ /^GS/ && cmd =~ /^infomon (?:reset|redo)!?/i
      ExecScript.start("Infomon.redo!", { :quiet => true })
    elsif XMLData.game =~ /^GS/ && cmd =~ /^display lichid(?: (true|false))?/i
      new_value = !(Lich.display_lichid)
      case Regexp.last_match(1)
      when 'true'
        new_value = true
      when 'false'
        new_value = false
      end
      respond "Changing Lich's Room title display for Lich ID#s to #{new_value}"
      Lich.display_lichid = new_value
    elsif XMLData.game =~ /^GS/ && cmd =~ /^display uid(?: (true|false))?/i
      new_value = !(Lich.display_uid)
      case Regexp.last_match(1)
      when 'true'
        new_value = true
      when 'false'
        new_value = false
      end
      respond "Changing Lich's Room title display for RealID#s to #{new_value}"
      Lich.display_uid = new_value
    elsif cmd =~ /^(?:lich5-update|l5u)\s+(.*)/i
      update_parameter = $1.dup
      Lich::Util::Update.request("#{update_parameter}")
    elsif cmd =~ /^(?:lich5-update|l5u)/i
      Lich::Util::Update.request("--help")
    elsif cmd =~ /^banks$/ && XMLData.game =~ /^GS/
      Game._puts "<c>bank account"
      $_CLIENTBUFFER_.push "<c>bank account"
    elsif cmd =~ /^magic$/ && XMLData.game =~ /^GS/
      Effects.display
    elsif cmd =~ /^help$/i
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
      respond "   #{$clean_lich_char}lich5-update --<command>  Lich5 ecosystem management "
      respond "                              see #{$clean_lich_char}lich5-update --help"
      if XMLData.game =~ /^GS/
        respond
        respond "   #{$clean_lich_char}infomon sync              sends all the various commands to resync character data for infomon (fixskill)"
        respond "   #{$clean_lich_char}infomon reset             resets entire character infomon db table and then syncs data (fixprof)"
        respond "   #{$clean_lich_char}display lichid            toggle display of Lich Map# in Room Title"
        respond "   #{$clean_lich_char}display uid               toggle display of RealID Map# in Room Title"
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
    else
      if cmd =~ /^([^\s]+)\s+(.+)/
        Script.start($1, $2)
      else
        Script.start(cmd)
      end
    end
  else
    if $offline_mode
      respond "--- Lich: offline mode: ignoring #{client_string}"
    else
      client_string = "#{$cmd_prefix}bbs" if ($frontend =~ /^(?:wizard|avalon)$/) and (client_string == "#{$cmd_prefix}\egbbk\n") # launch forum
      Game._puts client_string
    end
    $_CLIENTBUFFER_.push client_string
  end
  Script.new_upstream(client_string)
end

def report_errors(&block)
  begin
    block.call
  rescue
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue SyntaxError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue SystemExit
    nil
  rescue SecurityError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue ThreadError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue SystemStackError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue StandardError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  #  rescue ScriptError
  #    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
  #    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue LoadError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue NoMemoryError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  end
end
