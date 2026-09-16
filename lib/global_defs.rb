# global_defs carveout for lich5
# this needs to be broken up even more - OSXLich-Doug (2022-04-13)
# rubocop changes and DR toplevel command handling (2023-06-28)
# sadly adding global level script methods (2024-06-12)

require_relative 'common/move'

# Sentinel constants for dependency.lic gating.
# When these are defined, dependency.lic skips its inline versions.
module Lich
  module Common
    CORE_GET_SETTINGS = true
    CORE_SCRIPT_LOADER = true
    CORE_PARSE_ARGS = true
    CORE_AUTOSTART = true
  end
end

# added 2024

def start_script(script_name, cli_vars = [], flags = Hash.new)
  if flags == true
    flags = { :quiet => true }
  end
  Script.start(script_name, cli_vars.join(' '), flags)
end

def start_scripts(*script_names)
  script_names.flatten.each { |script_name|
    start_script(script_name)
    sleep 0.02
  }
end

def force_start_script(script_name, cli_vars = [], flags = {})
  flags = Hash.new unless flags.is_a?(Hash)
  flags[:force] = true
  start_script(script_name, cli_vars, flags)
end

# Starts scripts that exist and aren't already running.
# Waits briefly for each script to initialize before continuing.
# Replaces dependency.lic's custom_require lambda.
#
# @param script_names [String, Array<String>] script name(s) to start
# @return [void]
def start_scripts_if_available(script_names)
  script_names = [script_names].flatten.compact
  return if script_names.empty?

  script_names.each do |script_name|
    next if Script.running?(script_name)
    next unless Script.exists?(script_name)

    start_script(script_name)
    pause 0.05
    snapshot = Time.now
    until !Script.running?(script_name) || Time.now - snapshot > 0.25
      pause 0.05
    end
  end
end

# Returns character settings from YAML profiles.
# Lazy-initializes $setupfiles on first call.
#
# @param character_suffixes [Array<String>] additional profile suffixes to load
# @return [OpenStruct] merged and transformed settings
def get_settings(character_suffixes = [])
  $setupfiles ||= Lich::Common::SetupFiles.new
  $setupfiles.get_settings(character_suffixes)
end

# Returns data from a base-{type}.yaml file (e.g. 'spells', 'town', 'items').
# Lazy-initializes $setupfiles on first call.
#
# @param type [String] the data file type (e.g. 'spells', 'town', 'items')
# @return [OpenStruct] data from base-{type}.yaml
def get_data(type)
  $setupfiles ||= Lich::Common::SetupFiles.new
  $setupfiles.get_data(type)
end

# Parses script arguments against definition patterns.
# Delegates to Lich::Common::ArgParser.
#
# @param defn [Array<Array<Hash>>] argument definition sets
# @param flex_args [Boolean] whether to allow unmatched args
# @return [OpenStruct] matched arguments, or exits with help
def parse_args(defn, flex_args = false)
  Lich::Common::ArgParser.new.parse_args(defn, flex_args)
end

# Displays help/usage information for a script's arguments.
# Delegates to Lich::Common::ArgParser.
#
# @param defn [Array<Array<Hash>>] argument definition sets
def display_args(defn)
  Lich::Common::ArgParser.new.display_args(defn)
end

def before_dying(&code)
  Script.at_exit(&code)
end

def undo_before_dying
  Script.clear_exit_procs
end

def abort!
  Script.exit!
end

def stop_script(*target_names)
  numkilled = 0
  target_names.each { |target_name|
    condemned = Script.list.find { |s_sock| s_sock.name =~ /^#{target_name}/i }
    if condemned.nil?
      respond("--- Lich: '#{Script.current}' tried to stop '#{target_name}', but it isn't running!")
    else
      if condemned.name =~ /^#{Script.current.name}$/i
        exit
      end
      condemned.kill
      respond("--- Lich: '#{condemned}' has been stopped by #{Script.current}.")
      numkilled += 1
    end
  }
  if numkilled == 0
    return false
  else
    return numkilled
  end
end

def running?(*snames, exact_match: false)
  if exact_match
    snames.each { |checking| (return false) unless (Script.running.find { |lscr| lscr.name =~ /^#{checking}$/i } || Script.hidden.find { |lscr| lscr.name =~ /^#{checking}$/i }) }
  else
    snames.each { |checking| (return false) unless (Script.running.find { |lscr| lscr.name =~ /^#{checking}$/i } || Script.running.find { |lscr| lscr.name =~ /^#{checking}/i } || Script.hidden.find { |lscr| lscr.name =~ /^#{checking}$/i } || Script.hidden.find { |lscr| lscr.name =~ /^#{checking}/i }) }
  end
  true
end

def start_exec_script(cmd_data, options = Hash.new)
  ExecScript.start(cmd_data, options)
end

# prior to 2024
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
      messages.each { |message| respond("[#{script.custom? ? 'custom/' : ''}#{script.name}: #{message.to_s.chomp}]") }
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
      messages.each { |message| _respond("[#{script.custom? ? 'custom/' : ''}#{script.name}: #{message.to_s.chomp}]") }
    end
  else
    messages.each { |message| _respond("[(unknown script): #{message.to_s.chomp}]") }
  end
  nil
end

def goto(label)
  Script.current.jump_label = label.to_s
  raise Lich::Common::Script::JUMP
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

# Waits out hard roundtime.
#
# With no options this is the legacy call, unchanged for every existing
# caller: one sleep, then report whether roundtime REMAINS. Passing an
# option opts into the bounded contract: poll in tenth-of-a-second slices,
# stop early on +interrupt+ or +cap+, and report whether there was
# roundtime to wait out when the call began.
#
# @param interrupt [#call, nil] checked each slice; true ends the wait early
# @param cap [Numeric, nil] the longest wait allowed, in seconds
# @return [Boolean] bounded: whether there was roundtime to wait out;
#   legacy (no options): whether roundtime remains after the sleep
def waitrt?(interrupt: nil, cap: nil)
  if interrupt.nil? && cap.nil?
    sleep checkrt
    return checkrt > 0.0
  end

  had_rt = checkrt > 0.0
  stop_at = cap ? Time.now + cap : nil
  while checkrt > 0.0
    return had_rt if interrupt && interrupt.call
    return had_rt if stop_at && Time.now >= stop_at

    sleep([checkrt, 0.1].min)
  end
  had_rt
end

# Waits out cast (soft) roundtime; see {waitrt?} for the two contracts.
#
# @param interrupt [#call, nil] checked each slice; true ends the wait early
# @param cap [Numeric, nil] the longest wait allowed, in seconds
# @return [Boolean] bounded: whether there was cast roundtime to wait out;
#   legacy (no options): whether there was cast roundtime to sleep on
def waitcastrt?(interrupt: nil, cap: nil)
  if interrupt.nil? && cap.nil?
    current_castrt = checkcastrt
    if current_castrt.to_f > 0.0
      sleep(current_castrt)
      return true
    else
      return false
    end
  end

  had_rt = checkcastrt.to_f > 0.0
  stop_at = cap ? Time.now + cap : nil
  while checkcastrt.to_f > 0.0
    return had_rt if interrupt && interrupt.call
    return had_rt if stop_at && Time.now >= stop_at

    sleep([checkcastrt.to_f, 0.1].min)
  end
  had_rt
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

# Moves one exit. Implementation lives in Lich::Common::Move (lib/common/move.rb);
# this shim keeps the top-level name every script calls.
#
# @return [true, false, nil] true moved; false this exit is wrong (callers
#   may drop it from the map); nil blocked for now (keep the exit). After a
#   false or nil, Lich::Common::Move.last_failure names the line and cause.
def move(dir = 'none', giveup_seconds = 10, giveup_lines = 30)
  Lich::Common::Move.move(dir, giveup_seconds, giveup_lines)
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

# Blocks until the given block returns truthy.
#
# @param announce [String, nil] message to respond with if the condition is
#   not already true on entry
# @yieldreturn [Boolean] the condition being waited on
# @return [void]
# @note Blocks the calling thread while it is itself paused (unless exempt
#   via +ignore_pause+), both between polls and after the condition becomes
#   true, before returning control -- so a caller cannot resume past an
#   active pause here.
def wait_until(announce = nil)
  priosave = Thread.current.priority
  Thread.current.priority = 0
  script = Script.current
  unless announce.nil? or yield
    respond(announce)
  end
  loop do
    script&.wait_while_paused!
    if yield
      # The predicate may have blocked or yielded control for a while (e.g.
      # waiting on another thread); re-check pause before honoring its
      # result and returning to the caller, without re-invoking a
      # potentially stateful predicate a second time.
      script&.wait_while_paused!
      break
    end
    sleep 0.25
  end
  Thread.current.priority = priosave
end

# Blocks while the given block returns truthy.
#
# @param announce [String, nil] message to respond with if the condition is
#   already false on entry
# @yieldreturn [Boolean] the condition being waited on
# @return [void]
# @note Blocks the calling thread while it is itself paused (unless exempt
#   via +ignore_pause+), both between polls and after the condition becomes
#   false, before returning control -- so a caller cannot resume past an
#   active pause here.
def wait_while(announce = nil)
  priosave = Thread.current.priority
  Thread.current.priority = 0
  script = Script.current
  unless announce.nil? or !yield
    respond(announce)
  end
  loop do
    script&.wait_while_paused!
    unless yield
      # See wait_until: re-check pause after the predicate resolves, before
      # returning control, without re-invoking the predicate.
      script&.wait_while_paused!
      break
    end
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
  elsif (string.is_a?(String)) and (string.to_i == 0)
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
  elsif string.is_a?(String) and string.to_i == 0
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
  Lich.deprecated('checkmana', 'Char.mana', caller[0])
  if num.nil?
    XMLData.mana
  else
    XMLData.mana >= num.to_i
  end
end

def maxmana
  Lich.deprecated('maxmana', 'Char.maxmana', caller[0])
  XMLData.max_mana
end

def percentmana(num = nil)
  Lich.deprecated('percentmana', 'Char.percent_mana', caller[0])
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
  Lich.deprecated('checkhealth', 'Char.health', caller[0])
  if num.nil?
    XMLData.health
  else
    XMLData.health >= num.to_i
  end
end

def maxhealth
  Lich.deprecated('maxhealth', 'Char.max_health', caller[0])
  XMLData.max_health
end

def percenthealth(num = nil)
  Lich.deprecated('percenthealth', 'Char.percent_health', caller[0])
  if num.nil?
    ((XMLData.health.to_f / XMLData.max_health.to_f) * 100).to_i
  else
    ((XMLData.health.to_f / XMLData.max_health.to_f) * 100).to_i >= num.to_i
  end
end

def checkspirit(num = nil)
  Lich.deprecated('checkspirit', 'Char.spirit', caller[0])
  if num.nil?
    XMLData.spirit
  else
    XMLData.spirit >= num.to_i
  end
end

def maxspirit
  Lich.deprecated('maxspirit', 'Char.max_spirit', caller[0])
  XMLData.max_spirit
end

def percentspirit(num = nil)
  Lich.deprecated('percentspirit', 'Char.percent_spirit', caller[0])
  if num.nil?
    ((XMLData.spirit.to_f / XMLData.max_spirit.to_f) * 100).to_i
  else
    ((XMLData.spirit.to_f / XMLData.max_spirit.to_f) * 100).to_i >= num.to_i
  end
end

def checkstamina(num = nil)
  Lich.deprecated('checkstamina', 'Char.stamina', caller[0])
  if num.nil?
    XMLData.stamina
  else
    XMLData.stamina >= num.to_i
  end
end

def maxstamina()
  Lich.deprecated('maxstamina', 'Char.max_stamina', caller[0])
  XMLData.max_stamina
end

def percentstamina(num = nil)
  Lich.deprecated('percentstamina', 'Char.percent_stamina', caller[0])
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
    percent = 100
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
  Lich.deprecated('checkstance', 'Char.stance', caller[0])
  if num.nil?
    XMLData.stance_text
  elsif (num.is_a?(String)) and (num.to_i == 0)
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
  elsif (num.is_a?(Integer)) or (num =~ /^[0-9]+$/ and (num = num.to_i))
    XMLData.stance_value == num.to_i
  else
    echo "checkstance: invalid argument (#{num}).  Must be off/adv/for/neu/gua/def or 0-100"
    nil
  end
end

def percentstance(num = nil)
  Lich.deprecated('percentstance', 'Char.percent_stance', caller[0])
  if num.nil?
    XMLData.stance_value
  else
    XMLData.stance_value >= num.to_i
  end
end

def checkencumbrance(string = nil)
  Lich.deprecated('checkencumbrance', 'Char.encumbrance', caller[0])
  if string.nil?
    XMLData.encumbrance_text
  elsif (string.is_a?(Integer)) or (string =~ /^[0-9]+$/ and (string = string.to_i))
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
  Lich.deprecated('percentencumbrance', 'Char.percent_encumbrance', caller[0])
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
  elsif !spell.is_a?(String)
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
  if spell.is_a?(Spell)
    spell.cast(target, results_of_interest)
  elsif ((spell.is_a?(Integer)) or (spell.to_s =~ /^[0-9]+$/)) and (find_spell = Spell[spell.to_i])
    find_spell.cast(target, results_of_interest)
  elsif (spell.is_a?(String)) and (find_spell = Spell[spell])
    find_spell.cast(target, results_of_interest)
  else
    echo "cast: invalid spell (#{spell})"
    false
  end
end

def clear(_opt = 0)
  unless (script = Script.current) then respond('--- clear: Unable to identify calling script.'); return false; end
  script.clear
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
  unless (secs.is_a?(Float) || secs.is_a?(Integer))
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
  unless regexp.is_a?(Regexp) then echo("Script error! You have given 'waitforre' something to wait for, but it isn't a Regular Expression! Use 'waitfor' if you want to wait for a string."); sleep 1; return nil end
  regobj = regexp.match(script.gets) until regobj
end

def waitfor(*strings)
  unless (script = Script.current) then respond('--- waitfor: Unable to identify calling script.'); return false; end
  strings.flatten!
  if (script.is_a?(WizardScript)) and (strings.length == 1) and (strings.first.strip == '>')
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

def reget(*lines, core: false)
  unless (script = Script.current) || core.eql?(true)
    respond('--- reget: Unable to identify calling script.')
    return false
  end
  lines.flatten!
  if caller.find { |c| c =~ /regetall/ }
    history = ($_SERVERBUFFER_.history + $_SERVERBUFFER_).join("\n")
  else
    history = $_SERVERBUFFER_.dup.join("\n")
  end
  unless script&.want_downstream_xml || core.eql?(true)
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

  # Options via a trailing Hash argument: fput('cmd', 'pattern', timeout: 30)
  #   timeout:          seconds with no game response before giving up (60;
  #                     0 disables, the original behavior)
  #   max_resends:      how many times a refusal ("...wait 3", "struggle to
  #                     stand", stunned) may trigger a resend before giving
  #                     up (nil, the original: unbounded)
  #   interrupt:        a callable checked on every wait and before every
  #                     resend; true ends the send at once (nil: never)
  #   resend_transient: on a transient refusal that is not a stun or a
  #                     web (a "can't seem", "don't seem"), resend after a
  #                     quarter second instead of giving up (false, the
  #                     original; bigshot's bs_put resends)
  #   failures:         :false (the original: every failure returns false)
  #                     or :symbol - :no_response, :too_many_resends,
  #                     :interrupted, :dead, :refused - so a caller can
  #                     tell them apart
  options = (waitingfor.pop if waitingfor.last.is_a?(Hash)) || {}
  option = ->(key) { options[key] || options[key.to_s] }
  timeout = option.call(:timeout) || 60
  max_resends = option.call(:max_resends)
  interrupt = option.call(:interrupt)
  unless interrupt.nil? || interrupt.respond_to?(:call)
    raise ArgumentError, "fput: interrupt: must respond to call"
  end
  resend_transient = option.call(:resend_transient) ? true : false
  symbols = option.call(:failures) == :symbol
  fail_with = ->(reason) { symbols ? reason : false }
  interrupted = -> { interrupt && interrupt.call ? true : false }
  # With an interrupt, sleep in slices so it lands within a tenth of a
  # second; without one, the plain sleep of before. True when interrupted.
  wait = lambda do |seconds|
    if interrupt.nil?
      sleep(seconds)
      return false
    end
    slices = (seconds / 0.1).ceil
    slices.times do
      return true if interrupted.call

      sleep(0.1)
    end
    false
  end
  resends = 0
  # true after 'stand' went out and before its reply came back; the reply
  # is not the answer to message, so message goes out again on top of it
  standing = false
  # a refusal that asks for a resend: false when the cap allows it
  over_cap = lambda do
    resends += 1
    !max_resends.nil? && resends > max_resends
  end

  clear
  put(message)

  timer = Time.now
  loop do
    string = get?

    if string.nil?
      return fail_with.call(:interrupted) if interrupted.call

      if timeout > 0 && (Time.now - timer > timeout)
        echo "fput: No game response for #{timeout}s to '#{message}'"
        return fail_with.call(:no_response)
      end
      pause 0.1
      next
    end

    timer = Time.now # Reset timeout on any game response

    if string =~ /(?:\.\.\.wait |Wait )(?<wait_time>[0-9]+)/
      return fail_with.call(:too_many_resends) if over_cap.call

      hold_up = Regexp.last_match[:wait_time].to_i
      return fail_with.call(:interrupted) if wait.call(hold_up)

      standing = false
      clear
      put(message)
      next
    elsif string =~ /^You.+struggle.+stand/
      # stand in this frame, under the same cap and interrupt, instead of
      # a nested fput('stand') that started its own count and could not
      # be interrupted; a persistent struggle recursed until the stack
      # gave out
      return fail_with.call(:too_many_resends) if over_cap.call
      return fail_with.call(:interrupted) if interrupted.call

      standing = true
      clear
      put('stand')
      next
    elsif string =~ /stunned|can't do that while|cannot seem|^(?!You rummage).*can't seem|don't seem|Sorry, you may only type ahead/
      if dead?
        echo "You're dead...! You can't do that!"
        sleep 1
        script.downstream_buffer.unshift(string)
        return fail_with.call(:dead)
      elsif checkstunned
        while checkstunned
          return fail_with.call(:interrupted) if interrupted.call

          sleep("0.25".to_f)
        end
      elsif checkwebbed
        while checkwebbed
          return fail_with.call(:interrupted) if interrupted.call

          sleep("0.25".to_f)
        end
      elsif string =~ /Sorry, you may only type ahead/
        return fail_with.call(:interrupted) if wait.call(1)
      elsif resend_transient
        return fail_with.call(:interrupted) if wait.call(0.25)
      else
        sleep 0.1
        script.downstream_buffer.unshift(string)
        return fail_with.call(:refused)
      end
      if over_cap.call
        script.downstream_buffer.unshift(string)
        return fail_with.call(:too_many_resends)
      end

      standing = false
      clear
      put(message)
      next
    elsif standing
      # the reply to 'stand' ("You stand back up.", "You are already
      # standing"): message went unanswered, send it again
      standing = false
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
        return fail_with.call(:too_many_resends) if over_cap.call
        return fail_with.call(:interrupted) if wait.call(1)

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

# Requests an orderly Lich shutdown from a running script.
#
# This follows the explicit user-exit shutdown path and requests a game-server
# exit after local script teardown. The calling script is excluded from the
# script drain so it can finish the shutdown request.
#
# @return [Lich::Common::OrderlyShutdown::Result] shutdown result
def lich_shutdown
  current_script = Script.current
  source = current_script ? "script:#{current_script.name}" : :script

  Lich::Common::OrderlyShutdown.request_user_exit(
    source: source,
    current_script: current_script,
    server_exit_command: "#{$cmd_prefix}exit",
    active_sessions_lifecycle: (Lich::InternalAPI::ActiveSessions::Lifecycle if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle))
  )
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
    if first.is_a?(Array)
      first.flatten.each { |ln| str += sprintf("%s\r\n", ln.to_s.chomp) }
    else
      str += sprintf("%s\r\n", first.to_s.chomp)
    end
    messages.flatten.each { |message| str += sprintf("%s\r\n", message.to_s.chomp) }
    str.split(/\r?\n/).each { |line| Script.new_script_output(line); Buffer.update(line, Buffer::SCRIPT_OUTPUT) }
    # str.gsub!(/\r?\n/, "\r\n") if $frontend == 'genie'
    if Frontend.supports_mono?
      str = "<output class=\"mono\"/>\r\n#{Lich::Common::XmlEntities.encode(str)}<output class=\"\"/>\r\n"
    elsif Frontend.client.eql?('profanity')
      str = Lich::Common::XmlEntities.encode(str)
    end
    $_CLIENT_.puts_main_stream(str) if $_CLIENT_&.alive?
    detachable_clients_respond(str)
  rescue => e
    Lich.log "error: respond: #{e}\n\t#{e.backtrace.first}"
  end
end

def _respond(first = "", *messages)
  str = ''
  begin
    if first.is_a?(Array)
      first.flatten.each { |ln| str += sprintf("%s\r\n", ln.to_s.chomp) }
    else
      str += sprintf("%s\r\n", first.to_s.chomp)
    end
    # str.gsub!(/\r?\n/, "\r\n") if $frontend == 'genie'
    messages.flatten.each { |message| str += sprintf("%s\r\n", message.to_s.chomp) }
    str.split(/\r?\n/).each { |line| Script.new_script_output(line); Buffer.update(line, Buffer::SCRIPT_OUTPUT) }
    $_CLIENT_.puts_main_stream(str) if $_CLIENT_&.alive?
    detachable_clients_respond(str)
  rescue => e
    Lich.log "error: _respond: #{e}\n\t#{e.backtrace.first}"
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
    return (XMLData.max_mana * 25 / 100) + (stats.max / 10) + (stats.min / 20)
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
    return (XMLData.max_mana * 15 / 100) + (stats.max / 10) + (stats.min / 20)
  else
    return 0 # this method is not used by DR
  end
end

require_relative File.join(LIB_DIR, "stash.rb")
require File.join(LIB_DIR, 'common', 'xml_entities.rb')

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

# @param interrupt [#call, nil] checked on every read; true ends the wait
#   at once and returns nil, the way a timeout does
def dothistimeout(action, timeout, success_line, interrupt: nil)
  end_time = Time.now.to_f + timeout
  line = nil
  loop {
    Script.current.clear
    put action unless action.nil?
    loop {
      return nil if interrupt && interrupt.call

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

require File.join(LIB_DIR, 'common', 'markup.rb')

# Frontend markup translation lives in Lich::Common::Markup. These six names
# stay global because scripts in the wild call them unqualified.

def fb_to_sf(line)
  Lich::Common::Markup.fb_to_sf(line)
end

def sf_to_wiz(line, bypass_multiline: false)
  Lich::Common::Markup.sf_to_wiz(line, bypass_multiline: bypass_multiline)
end

# See Lich::Common::Markup.strip_xml for the multiline contract.
#
# @note nil is a normal return, not an error. Callers commonly feed the
#   result straight to String#split; that is safe because NilClass#split is
#   patched to return [] (see lib/common/class_exts/nilclass.rb).
def strip_xml(line, type: nil)
  Lich::Common::Markup.strip_xml(line, type: type)
end

# .dup because markup.rb is frozen_string_literal and global_defs.rb never
# was: these returned mutable strings before the extraction, and a wild
# script appending to the result in place would now raise FrozenError. The
# copy keeps the global contract byte-identical *and* mutable.
def monsterbold_start
  Lich::Common::Markup.monsterbold_start.dup
end

def monsterbold_end
  Lich::Common::Markup.monsterbold_end.dup
end

# Multiple frontends may attach to one persistent detachable listener. The
# legacy globals remain synchronized for scripts that inspect the primary or
# the current client list directly.
$_DETACHABLE_CLIENT_REGISTRY_ ||= Lich::Common::DetachableClientRegistry.new
$_DETACHABLE_CLIENTS_ ||= []
$_DETACHABLE_CLIENT_ ||= nil

def sync_detachable_client_globals
  $_DETACHABLE_CLIENTS_ = $_DETACHABLE_CLIENT_REGISTRY_.snapshot
  $_DETACHABLE_CLIENT_ = $_DETACHABLE_CLIENT_REGISTRY_.primary
end

def detachable_clients_snapshot
  $_DETACHABLE_CLIENT_REGISTRY_.snapshot
end

def detachable_client_count
  $_DETACHABLE_CLIENT_REGISTRY_.count
end

def detachable_client_primary?(client)
  $_DETACHABLE_CLIENT_REGISTRY_.primary?(client)
end

def detachable_listener_connected(connected)
  return unless $_DETACHABLE_LISTENER_

  Lich::InternalAPI::ActiveSessions::Lifecycle.update_listener(
    host: $_DETACHABLE_LISTENER_[:host],
    port: $_DETACHABLE_LISTENER_[:port],
    connected: connected
  )
rescue StandardError => e
  Lich.log "warning: detachable update_listener(#{connected}): #{e}"
end

def detachable_client_register(client)
  became_nonempty = $_DETACHABLE_CLIENT_REGISTRY_.register(client)
  sync_detachable_client_globals
  detachable_listener_connected(true) if became_nonempty
  client
end

def detachable_client_unregister(client)
  removed, became_empty = $_DETACHABLE_CLIENT_REGISTRY_.unregister(client)
  sync_detachable_client_globals
  detachable_listener_connected(false) if removed && became_empty
  removed
end

def detachable_clients_respond(string)
  detachable_clients_snapshot.each do |client|
    unless client.alive?
      detachable_client_unregister(client)
      next
    end

    # Isolate per-client failures: a raise from one client's socket must not
    # abort the loop and starve the remaining attached clients of this output.
    # Mirrors the per-client rescue in detachable_clients_close.
    begin
      client.puts_main_stream(string)
    rescue StandardError => e
      Lich.log "warning: detachable_clients_respond: #{e}"
    end
    detachable_client_unregister(client) unless client.alive?
  end
end

def detachable_clients_close
  clients = $_DETACHABLE_CLIENT_REGISTRY_.remove_all
  sync_detachable_client_globals
  clients.each { |client| client.close rescue nil }
  detachable_listener_connected(false) unless clients.empty?
  clients.length
end

# Send one newly attached frontend the game state it missed before attaching.
def detachable_client_send_init(client)
  100.times { sleep 0.1; break if XMLData.indicator['IconJOINED'] }
  init_str = "<progressBar id='mana' value='0' text='mana #{XMLData.mana}/#{XMLData.max_mana}'/>"
  init_str.concat "<progressBar id='health' value='0' text='health #{XMLData.health}/#{XMLData.max_health}'/>"
  init_str.concat "<progressBar id='spirit' value='0' text='spirit #{XMLData.spirit}/#{XMLData.max_spirit}'/>"
  init_str.concat "<progressBar id='stamina' value='0' text='stamina #{XMLData.stamina}/#{XMLData.max_stamina}'/>"
  init_str.concat "<spell>#{Lich::Common::XmlEntities.encode(XMLData.prepared_spell)}</spell>"
  %w[IconBLEEDING IconPOISONED IconDISEASED IconSTANDING IconKNEELING IconSITTING IconPRONE].each do |indicator|
    init_str.concat "<indicator id='#{indicator}' visible='#{XMLData.indicator[indicator]}'/>"
  end
  if XMLData.game.to_s.match?(/GS/)
    init_str.concat "<progressBar id='pbarStance' value='#{XMLData.stance_value}'/>"
    init_str.concat "<progressBar id='mindState' value='#{XMLData.mind_value}' text='#{Lich::Common::XmlEntities.encode(XMLData.mind_text)}'/>"
    init_str.concat "<progressBar id='encumlevel' value='#{XMLData.encumbrance_value}' text='#{Lich::Common::XmlEntities.encode(XMLData.encumbrance_text)}'/>"
    init_str.concat "<right>#{Lich::Common::XmlEntities.encode(GameObj.right_hand.name)}</right>"
    init_str.concat "<left>#{Lich::Common::XmlEntities.encode(GameObj.left_hand.name)}</left>"
    %w[back leftHand rightHand head rightArm abdomen leftEye leftArm chest rightLeg neck leftLeg nsys rightEye].each do |area|
      if Wounds.send(area) > 0
        init_str.concat "<image id=\"#{area}\" name=\"Injury#{Wounds.send(area)}\"/>"
      elsif Scars.send(area) > 0
        init_str.concat "<image id=\"#{area}\" name=\"Scar#{Scars.send(area)}\"/>"
      end
    end
  end
  init_str.concat '<compass>'
  short_dirs = {
    'north' => 'n', 'northeast' => 'ne', 'east' => 'e', 'southeast' => 'se',
    'south' => 's', 'southwest' => 'sw', 'west' => 'w', 'northwest' => 'nw',
    'up' => 'up', 'down' => 'down', 'out' => 'out'
  }
  XMLData.room_exits.each do |direction|
    init_str.concat "<dir value='#{short_dirs[direction]}'/>" if short_dirs.key?(direction)
  end
  init_str.concat '</compass>'
  client.puts_main_stream(init_str)
rescue StandardError => e
  Lich.log "error: detachable_client_send_init: #{e}\n\t#{e.backtrace.first}"
end

def detachable_client_send_player_id(client)
  tag = nil
  100.times do
    break if (tag = Frontend.player_id_tag(XMLData.player_id))

    sleep 0.1
  end
  client.puts_main_stream(tag) if tag && client.alive?
rescue StandardError => e
  Lich.log "error: detachable_client_send_player_id: #{e}\n\t#{e.backtrace.first}"
end

def handle_detachable_client(client)
  unless ARGV.any? { |argument| argument.match?(/^--(?:genie|saga)$/i) }
    Thread.new { detachable_client_send_init(client) }
  end
  Thread.new { detachable_client_send_player_id(client) } if ARGV.any? { |argument| argument.match?(/^--saga$/i) }

  while (client_string = client.gets)
    if client_string.match?(/^SET_FRONTEND_PID\s+(\d+)\s*$/)
      Frontend.set_from_client(Regexp.last_match(1).to_i) if defined?(Frontend) && detachable_client_primary?(client)
      next
    end

    # Detachable exits run script shutdown inline, so the watchdog must be armed
    # before that potentially blocking path. Route through the shared dispatch so
    # the primary and detachable frontend exit paths stay identical; it applies
    # the same $cmd_prefix prefixing before matching.
    if Lich::Main::UserExitDispatch.dispatch_detachable_client(client_string, cmd_prefix: $cmd_prefix)
      break
    end
    client_string = "#{$cmd_prefix}#{client_string}"

    begin
      dispatch_client_input(client_string)
    rescue StandardError => e
      respond "--- Lich: error: client_thread: #{e}"
      respond e.backtrace.first
      Lich.log "error: client_thread: #{e}\n\t#{e.backtrace.join("\n\t")}"
    end
  end
  Lich::Common::ShutdownLog.info('detachable client disconnected')
rescue StandardError => e
  _respond "--- Lich: error: detachable client: #{e}"
  Lich.log "error: detachable_client_handler: #{e}\n\t#{e.backtrace.join("\n\t")}"
ensure
  client.close rescue nil
  detachable_client_unregister(client)
  # Mirror the connect-side "listening on" line so an operator sharing the
  # controlling terminal (for example a wrapper script that exec's a frontend)
  # sees which session dropped and from where. Emitted after unregister so the
  # attached count reflects the clients that remain.
  if $_DETACHABLE_LISTENER_
    session_name = Lich::Common::SessionLifecycle.resolve_session_name(
      argv: ARGV, account_character: (Lich::Common::Account.character rescue nil)
    )
    $stdout.puts Lich::Main::DetachableClientNotice.disconnected(
      name: session_name,
      host: $_DETACHABLE_LISTENER_[:host],
      port: $_DETACHABLE_LISTENER_[:port],
      attached: detachable_client_count
    ) rescue nil
  end
  Lich::Common::ShutdownLog.info("detachable client cleaned up (#{detachable_client_count} attached)")
end

def dispatch_client_input(client_string)
  Lich::Common::ClientInputDispatcher.dispatch(client_string) do |serialized_string|
    $_IDLETIMESTAMP_ = Time.now
    do_client(serialized_string)
  end
end

require File.join(LIB_DIR, 'common', 'client_commands', 'builtins.rb')

def do_client(client_string)
  client_string.strip!
  #   Buffer.update(client_string, Buffer::UPSTREAM)
  client_string = UpstreamHook.run(client_string)
  #   Buffer.update(client_string, Buffer::UPSTREAM_MOD)
  return nil if client_string.nil?

  if client_string =~ /^(?:<c>)?#{$lich_char_regex}(.+)$/
    cmd = $1
    # Built-in ;commands live in Lich::Common::ClientCommands, which matches
    # them in registration order and runs the first hit. Anything it does not
    # claim is a script name.
    unless Lich::Common::ClientCommands.dispatch(cmd)
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
      client_string = "#{$cmd_prefix}bbs" if Frontend.supports_gsl? and (client_string == "#{$cmd_prefix}\egbbk\n") # launch forum
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

def alias_deprecated
  # todo: add command reference, possibly add calling script
  echo "The alias command you're attempting to use is deprecated.  Fix your script."
end

## Alias block from Lich (needs further cleanup)

undef :abort if respond_to?(:abort)
alias :mana :checkmana
alias :mana? :checkmana
alias :max_mana :maxmana
alias :health :checkhealth
alias :health? :checkhealth
alias :spirit :checkspirit
alias :spirit? :checkspirit
alias :stamina :checkstamina
alias :stamina? :checkstamina
alias :stunned? :checkstunned
alias :bleeding? :checkbleeding
alias :reallybleeding? :alias_deprecated
alias :poisoned? :checkpoison
alias :diseased? :checkdisease
alias :dead? :checkdead
alias :hiding? :checkhidden
alias :hidden? :checkhidden
alias :hidden :checkhidden
alias :checkhiding :checkhidden
alias :invisible? :checkinvisible
alias :standing? :checkstanding
alias :kneeling? :checkkneeling
alias :sitting? :checksitting
alias :stance? :checkstance
alias :stance :checkstance
alias :joined? :checkgrouped
alias :checkjoined :checkgrouped
alias :group? :checkgrouped
alias :myname? :checkname
alias :active? :checkspell
alias :righthand? :checkright
alias :lefthand? :checkleft
alias :righthand :checkright
alias :lefthand :checkleft
alias :mind? :checkmind
alias :checkactive :checkspell
alias :forceput :fput
alias :send_script :send_scripts
alias :stop_scripts :stop_script
alias :kill_scripts :stop_script
alias :kill_script :stop_script
alias :fried? :checkfried
alias :saturated? :checksaturated
alias :webbed? :checkwebbed
alias :pause_scripts :pause_script
alias :roomdescription? :checkroomdescrip
alias :prepped? :checkprep
alias :checkprepared :checkprep
alias :unpause_scripts :unpause_script
alias :priority? :setpriority
alias :checkoutside :outside?
alias :toggle_status :status_tags
alias :encumbrance? :checkencumbrance
alias :bounty? :checkbounty
