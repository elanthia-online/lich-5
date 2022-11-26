class ExecScript < Script
  @@name_exec_mutex = Mutex.new
  @@elevated_start = proc { |cmd_data, options|
    options[:trusted] = false
    unless new_script = ExecScript.new(cmd_data, options)
      respond '--- Lich: failed to start exec script'
      return false
    end
    new_thread = Thread.new {
      100.times { break if Script.current == new_script; sleep 0.01 }

      if script = Script.current
        Thread.current.priority = 1
        respond("--- Lich: #{script.name} active.") unless script.quiet
        begin
          script_binding = Scripting.new.script
          eval('script = Script.current', script_binding, script.name.to_s)
          proc { cmd_data.untaint; $SAFE = 3; eval(cmd_data, script_binding, script.name.to_s) }.call
          Script.current.kill
        rescue SystemExit
          Script.current.kill
        rescue SyntaxError
          respond "--- SyntaxError: #{$!}"
          respond $!.backtrace.first
          Lich.log "SyntaxError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue ScriptError
          respond "--- ScriptError: #{$!}"
          respond $!.backtrace.first
          Lich.log "ScriptError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue NoMemoryError
          respond "--- NoMemoryError: #{$!}"
          respond $!.backtrace.first
          Lich.log "NoMemoryError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue LoadError
          respond("--- LoadError: #{$!}")
          respond "--- LoadError: #{$!}"
          respond $!.backtrace.first
          Lich.log "LoadError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue SecurityError
          respond "--- SecurityError: #{$!}"
          respond $!.backtrace[0..1]
          Lich.log "SecurityError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue ThreadError
          respond "--- ThreadError: #{$!}"
          respond $!.backtrace.first
          Lich.log "ThreadError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue SystemStackError
          respond "--- SystemStackError: #{$!}"
          respond $!.backtrace.first
          Lich.log "SystemStackError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue Exception
          respond "--- Exception: #{$!}"
          respond $!.backtrace.first
          Lich.log "Exception: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue
          respond "--- Lich: error: #{$!}"
          respond $!.backtrace.first
          Lich.log "Error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        end
      else
        respond '--- Lich: error: ExecScript.start: out of cheese'
      end
    }
    new_script.thread_group.add(new_thread)
    new_script
  }
  attr_reader :cmd_data

  def ExecScript.start(cmd_data, options = {})
    options = { :quiet => true } if options == true
    if ($SAFE < 2) and (options[:trusted] or (RUBY_VERSION !~ /^2\.[012]\./))
      unless new_script = ExecScript.new(cmd_data, options)
        respond '--- Lich: failed to start exec script'
        return false
      end
      new_thread = Thread.new {
        100.times { break if Script.current == new_script; sleep 0.01 }

        if script = Script.current
          Thread.current.priority = 1
          respond("--- Lich: #{script.name} active.") unless script.quiet
          begin
            script_binding = TRUSTED_SCRIPT_BINDING.call
            eval('script = Script.current', script_binding, script.name.to_s)
            eval(cmd_data, script_binding, script.name.to_s)
            Script.current.kill
          rescue SystemExit
            Script.current.kill
          rescue SyntaxError
            respond "--- SyntaxError: #{$!}"
            respond $!.backtrace.first
            Lich.log "SyntaxError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue ScriptError
            respond "--- ScriptError: #{$!}"
            respond $!.backtrace.first
            Lich.log "ScriptError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue NoMemoryError
            respond "--- NoMemoryError: #{$!}"
            respond $!.backtrace.first
            Lich.log "NoMemoryError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue LoadError
            respond("--- LoadError: #{$!}")
            respond "--- LoadError: #{$!}"
            respond $!.backtrace.first
            Lich.log "LoadError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue SecurityError
            respond "--- SecurityError: #{$!}"
            respond $!.backtrace[0..1]
            Lich.log "SecurityError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue ThreadError
            respond "--- ThreadError: #{$!}"
            respond $!.backtrace.first
            Lich.log "ThreadError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue SystemStackError
            respond "--- SystemStackError: #{$!}"
            respond $!.backtrace.first
            Lich.log "SystemStackError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue Exception
            respond "--- Exception: #{$!}"
            respond $!.backtrace.first
            Lich.log "Exception: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue
            respond "--- Lich: error: #{$!}"
            respond $!.backtrace.first
            Lich.log "Error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          end
        else
          respond 'start_exec_script screwed up...'
        end
      }
      new_script.thread_group.add(new_thread)
      new_script
    else
      @@elevated_start.call(cmd_data, options)
    end
  end

  def initialize(cmd_data, flags = Hash.new)
    @cmd_data = cmd_data
    @vars = Array.new
    @downstream_buffer = LimitedArray.new
    @killer_mutex = Mutex.new
    @want_downstream = true
    @want_downstream_xml = false
    @upstream_buffer = LimitedArray.new
    @want_upstream = false
    @at_exit_procs = Array.new
    @watchfor = Hash.new
    @hidden = false
    @paused = false
    @silent = false
    if flags[:quiet].nil?
      @quiet = false
    else
      @quiet = flags[:quiet]
    end
    @safe = false
    @no_echo = false
    @thread_group = ThreadGroup.new
    @unique_buffer = LimitedArray.new
    @die_with = Array.new
    @no_pause_all = false
    @no_kill_all = false
    @match_stack_labels = Array.new
    @match_stack_strings = Array.new
    num = '1'; num.succ! while @@running.any? { |s| s.name == "exec#{num}" }
    @name = "exec#{num}"
    @@running.push(self)
    self
  end

  def get_next_label
    echo 'goto labels are not available in exec scripts.'
    nil
  end
end
