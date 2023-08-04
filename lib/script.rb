# Generated during infomon separation 230305
# script bindings are convoluted, but don't change them without testing if:
#    class methods such as Script.start and ExecScript.start become accessible without specifying the class name (which is just a syptom of a problem that will break scripts)
#    local variables become shared between scripts
#    local variable 'file' is shared between scripts, even though other local variables aren't
#    defined methods are instantly inaccessible
# also, don't put 'untrusted' in the name of the untrusted binding; it shows up in error messages and makes people think the error is caused by not trusting the script
#
class Scripting
  def script
    Proc.new {}.binding
  end
end
def _script
  Proc.new {}.binding
end

TRUSTED_SCRIPT_BINDING = proc { _script }

class Script
  @@elevated_script_start = proc { |args|
    if args.empty?
      # fixme: error
      next nil
    elsif args[0].class == String
      script_name = args[0]
      if args[1]
        if args[1].class == String
          script_args = args[1]
          if args[2]
            if args[2].class == Hash
              options = args[2]
            else
              # fixme: error
              next nil
            end
          end
        elsif args[1].class == Hash
          options = args[1]
          script_args = (options[:args] || String.new)
        else
          # fixme: error
          next nil
        end
      else
        options = Hash.new
      end
    elsif args[0].class == Hash
      options = args[0]
      if options[:name]
        script_name = options[:name]
      else
        # fixme: error
        next nil
      end
      script_args = (options[:args] || String.new)
    end

    # fixme: look in wizard script directory
    # fixme: allow subdirectories?
    file_list = Dir.children(File.join(SCRIPT_DIR, "custom")).sort_by{ |fn| fn.sub(/[.](lic|rb|cmd|wiz)$/, '') }.map{ |s| s.prepend("/custom/") } + Dir.children(SCRIPT_DIR).sort_by{|fn| fn.sub(/[.](lic|rb|cmd|wiz)$/, '')}
    if file_name = (file_list.find { |val| val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/ || val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i } || file_list.find { |val| val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}[^.]+\.(?i:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/ } || file_list.find { |val| val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}[^.]+\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i })
      script_name = file_name.sub(/\..{1,3}$/, '')
    end
    file_list = nil
    if file_name.nil?
      respond "--- Lich: could not find script '#{script_name}' in directory #{SCRIPT_DIR} or #{SCRIPT_DIR}/custom"
      next nil
    end
    if (options[:force] != true) and (Script.running + Script.hidden).find { |s| s.name =~ /^#{Regexp.escape(script_name.sub('/custom/', ''))}$/i }
      respond "--- Lich: #{script_name} is already running (use #{$clean_lich_char}force [scriptname] if desired)."
      next nil
    end
    begin
      if file_name =~ /\.(?:cmd|wiz)(?:\.gz)?$/i
        trusted = false
        script_obj = WizardScript.new("#{SCRIPT_DIR}/#{file_name}", script_args)
      else
        if script_obj.labels.length > 1
          trusted = false
        else
          trusted = true
        end
        script_obj = Script.new(:file => "#{SCRIPT_DIR}/#{file_name}", :args => script_args, :quiet => options[:quiet])
      end
      if trusted
        script_binding = TRUSTED_SCRIPT_BINDING.call
      else
        script_binding = Scripting.new.script
      end
    rescue
      respond "--- Lich: error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      next nil
    end
    unless script_obj
      respond "--- Lich: error: failed to start script (#{script_name})"
      next nil
    end
    script_obj.quiet = true if options[:quiet]
    new_thread = Thread.new {
      100.times { break if Script.current == script_obj; sleep 0.01 }

      if script = Script.current
        eval('script = Script.current', script_binding, script.name)
        Thread.current.priority = 1
        respond("--- Lich: #{script.name} active.") unless script.quiet
        if trusted
          begin
            eval(script.labels[script.current_label].to_s, script_binding, script.name)
          rescue SystemExit
            nil
          rescue SyntaxError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue ScriptError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue NoMemoryError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue LoadError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue SecurityError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue ThreadError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue SystemStackError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue Exception
            if $! == JUMP
              retry if Script.current.get_next_label != JUMP_ERROR
              respond "--- label error: `#{Script.current.jump_label}' was not found, and no `LabelError' label was found!"
              respond $!.backtrace.first
              Lich.log "label error: `#{Script.current.jump_label}' was not found, and no `LabelError' label was found!\n\t#{$!.backtrace.join("\n\t")}"
              Script.current.kill
            else
              respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
              Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            end
          rescue
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          ensure
            Script.current.kill
          end
        else
          begin
            while (script = Script.current) and script.current_label
              proc { foo = script.labels[script.current_label]; eval(foo, script_binding, script.name, 1) }.call
              Script.current.get_next_label
            end
          rescue SystemExit
            nil
          rescue SyntaxError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue ScriptError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue NoMemoryError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue LoadError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue SecurityError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            if name = Script.current.name
              respond "--- Lich: review this script (#{name}) to make sure it isn't malicious, and type #{$clean_lich_char}trust #{name}"
            end
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue ThreadError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue SystemStackError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue Exception
            if $! == JUMP
              retry if Script.current.get_next_label != JUMP_ERROR
              respond "--- label error: `#{Script.current.jump_label}' was not found, and no `LabelError' label was found!"
              respond $!.backtrace.first
              Lich.log "label error: `#{Script.current.jump_label}' was not found, and no `LabelError' label was found!\n\t#{$!.backtrace.join("\n\t")}"
              Script.current.kill
            else
              respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
              Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            end
          rescue
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          ensure
            Script.current.kill
          end
        end
      else
        respond '--- error: out of cheese'
      end
    }
    script_obj.thread_group.add(new_thread)
    script_obj
  }
  @@elevated_exists = proc { |script_name|
    if script_name =~ /\\|\//
      nil
    elsif script_name =~ /\.(?:lic|lich|rb|cmd|wiz)(?:\.gz)?$/i
      File.exist?("#{SCRIPT_DIR}/#{script_name}") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}")
    else
      File.exist?("#{SCRIPT_DIR}/#{script_name}.lic") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}.lic") ||
      File.exist?("#{SCRIPT_DIR}/#{script_name}.lich") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}.lich") ||
      File.exist?("#{SCRIPT_DIR}/#{script_name}.rb") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}.rb") ||
      File.exist?("#{SCRIPT_DIR}/#{script_name}.cmd") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}.cmd") ||
      File.exist?("#{SCRIPT_DIR}/#{script_name}.wiz") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}.wiz") ||
      File.exist?("#{SCRIPT_DIR}/#{script_name}.lic.gz") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}.lic.gz") ||
      File.exist?("#{SCRIPT_DIR}/#{script_name}.rb.gz") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}.rb.gz") ||
      File.exist?("#{SCRIPT_DIR}/#{script_name}.cmd.gz") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}.cmd.gz") ||
      File.exist?("#{SCRIPT_DIR}/#{script_name}.wiz.gz") || File.exist?("#{SCRIPT_DIR}/custom/#{script_name}.wiz.gz")
    end
  }
  @@elevated_log = proc { |data|
    if script = Script.current
      if script.name =~ /\\|\//
        nil
      else
        begin
          Dir.mkdir("#{LICH_DIR}/logs") unless File.exist?("#{LICH_DIR}/logs")
          File.open("#{LICH_DIR}/logs/#{script.name}.log", 'a') { |f| f.puts data }
          true
        rescue
          respond "--- Lich: error: Script.log: #{$!}"
          false
        end
      end
    else
      respond '--- error: Script.log: unable to identify calling script'
      false
    end
  }
  @@elevated_db = proc {
    if script = Script.current
      if script.name =~ /^lich$/i
        respond '--- error: Script.db cannot be used by a script named lich'
        nil
      elsif script.class == ExecScript
        respond '--- error: Script.db cannot be used by exec scripts'
        nil
      else
        SQLite3::Database.new("#{DATA_DIR}/#{script.name.gsub(/\/|\\/, '_')}.db3")
      end
    else
      respond '--- error: Script.db called by an unknown script'
      nil
    end
  }
  @@elevated_open_file = proc { |ext, mode, block|
    if script = Script.current
      if script.name =~ /^lich$/i
        respond '--- error: Script.open_file cannot be used by a script named lich'
        nil
      elsif script.name =~ /^entry$/i
        respond '--- error: Script.open_file cannot be used by a script named entry'
        nil
      elsif script.class == ExecScript
        respond '--- error: Script.open_file cannot be used by exec scripts'
        nil
      elsif ext.downcase == 'db3'
        SQLite3::Database.new("#{DATA_DIR}/#{script.name.gsub(/\/|\\/, '_')}.db3")
        # fixme: block gets elevated... why?
        #         elsif block
        #            File.open("#{DATA_DIR}/#{script.name.gsub(/\/|\\/, '_')}.#{ext.gsub(/\/|\\/, '_')}", mode, &block)
      else
        File.open("#{DATA_DIR}/#{script.name.gsub(/\/|\\/, '_')}.#{ext.gsub(/\/|\\/, '_')}", mode)
      end
    else
      respond '--- error: Script.open_file called by an unknown script'
      nil
    end
  }
  @@running = Array.new

  attr_reader :name, :vars, :safe, :file_name, :label_order, :at_exit_procs
  attr_accessor :quiet, :no_echo, :jump_label, :current_label, :want_downstream, :want_downstream_xml, :want_upstream, :want_script_output, :hidden, :paused, :silent, :no_pause_all, :no_kill_all, :downstream_buffer, :upstream_buffer, :unique_buffer, :die_with, :match_stack_labels, :match_stack_strings, :watchfor, :command_line, :ignore_pause

  def Script.version(script_name, script_version_required = nil)
    script_name = script_name.sub(/[.](lic|rb|cmd|wiz)$/, '')
    file_list = Dir.children(File.join(SCRIPT_DIR, "custom")).sort_by{ |fn| fn.sub(/[.](lic|rb|cmd|wiz)$/, '') }.map{ |s| s.prepend("/custom/") } + Dir.children(SCRIPT_DIR).sort_by{|fn| fn.sub(/[.](lic|rb|cmd|wiz)$/, '')}
    if file_name = (file_list.find { |val| val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/ || val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i } || file_list.find { |val| val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}[^.]+\.(?i:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/ } || file_list.find { |val| val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}[^.]+\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i })
      script_name = file_name.sub(/\..{1,3}$/, '')
    end
    file_list = nil
    if file_name.nil?
      respond "--- Lich: could not find script '#{script_name}' in directory #{SCRIPT_DIR}"
      return nil
    end

    script_version = '0.0.0'
    script_data = open("#{SCRIPT_DIR}/#{file_name}", 'r').read
    if script_data =~ /^=begin\r?\n?(.+?)^=end/m
      comments = $1.split("\n")
    else
      comments = []
      script_data.split("\n").each {|line|
        if line =~ /^[\t\s]*#/
          comments.push(line)
        elsif line !~ /^[\t\s]*$/
          break
        end
      }
    end
    for line in comments
      if line =~ /^[\s\t#]*version:[\s\t]*([\w,\s\.\d]+)/i
        script_version = $1.sub(/\s\(.*?\)/, '').strip
      end
    end
    if script_version_required
      Gem::Version.new(script_version) < Gem::Version.new(script_version_required)
    else
      Gem::Version.new(script_version)
    end
  end

  def Script.list
    @@running.dup
  end

  def Script.current
    if script = @@running.find { |s| s.has_thread?(Thread.current) }
      sleep 0.2 while script.paused? and not script.ignore_pause
      script
    else
      nil
    end
  end

  def Script.start(*args)
    @@elevated_script_start.call(args)
  end

  def Script.run(*args)
    if s = @@elevated_script_start.call(args)
      sleep 0.1 while @@running.include?(s)
    end
  end

  def Script.running?(name)
    @@running.any? { |i| (i.name =~ /^#{name}$/i) }
  end

  def Script.pause(name = nil)
    if name.nil?
      Script.current.pause
      Script.current
    else
      if s = (@@running.find { |i| (i.name == name) and not i.paused? }) || (@@running.find { |i| (i.name =~ /^#{name}$/i) and not i.paused? })
        s.pause
        true
      else
        false
      end
    end
  end

  def Script.unpause(name)
    if s = (@@running.find { |i| (i.name == name) and i.paused? }) || (@@running.find { |i| (i.name =~ /^#{name}$/i) and i.paused? })
      s.unpause
      true
    else
      false
    end
  end

  def Script.kill(name)
    if s = (@@running.find { |i| i.name == name }) || (@@running.find { |i| i.name =~ /^#{name}$/i })
      s.kill
      true
    else
      false
    end
  end

  def Script.paused?(name)
    if s = (@@running.find { |i| i.name == name }) || (@@running.find { |i| i.name =~ /^#{name}$/i })
      s.paused?
    else
      nil
    end
  end

  def Script.exists?(script_name)
    @@elevated_exists.call(script_name)
  end

  def Script.new_downstream_xml(line)
    for script in @@running
      script.downstream_buffer.push(line.chomp) if script.want_downstream_xml
    end
  end

  def Script.new_upstream(line)
    for script in @@running
      script.upstream_buffer.push(line.chomp) if script.want_upstream
    end
  end

  def Script.new_downstream(line)
    @@running.each { |script|
      script.downstream_buffer.push(line.chomp) if script.want_downstream
      unless script.watchfor.empty?
        script.watchfor.each_pair { |trigger, action|
          if line =~ trigger
            new_thread = Thread.new {
              sleep 0.011 until Script.current
              begin
                action.call
              rescue
                echo "watchfor error: #{$!}"
              end
            }
            script.thread_group.add(new_thread)
          end
        }
      end
    }
  end

  def Script.new_script_output(line)
    for script in @@running
      script.downstream_buffer.push(line.chomp) if script.want_script_output
    end
  end

  def Script.log(data)
    @@elevated_log.call(data)
  end

  def Script.db
    @@elevated_db.call
  end

  def Script.open_file(ext, mode = 'r', &block)
    @@elevated_open_file.call(ext, mode, block)
  end

  def Script.at_exit(&block)
    if script = Script.current
      script.at_exit(&block)
    else
      respond "--- Lich: error: Script.at_exit: can't identify calling script"
      return false
    end
  end

  def Script.clear_exit_procs
    if script = Script.current
      script.clear_exit_procs
    else
      respond "--- Lich: error: Script.clear_exit_procs: can't identify calling script"
      return false
    end
  end

  def Script.exit!
    if script = Script.current
      script.exit!
    else
      respond "--- Lich: error: Script.exit!: can't identify calling script"
      return false
    end
  end
  if (RUBY_VERSION =~ /^2\.[012]\./)
    def Script.trust(script_name)
      # fixme: case sensitive blah blah
      if not caller.any? { |c| c =~ /eval|run/ }
        begin
          Lich.db.execute('INSERT OR REPLACE INTO trusted_scripts(name) values(?);', script_name.encode('UTF-8'))
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
        true
      else
        respond '--- error: scripts may not trust scripts'
        false
      end
    end

    def Script.distrust(script_name)
      begin
        there = Lich.db.get_first_value('SELECT name FROM trusted_scripts WHERE name=?;', script_name.encode('UTF-8'))
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
      if there
        begin
          Lich.db.execute('DELETE FROM trusted_scripts WHERE name=?;', script_name.encode('UTF-8'))
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
        true
      else
        false
      end
    end

    def Script.list_trusted
      list = Array.new
      begin
        Lich.db.execute('SELECT name FROM trusted_scripts;').each { |name| list.push(name[0]) }
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
      list
    end
  else
    def Script.trust(script_name)
      true
    end

    def Script.distrust(script_name)
      false
    end

    def Script.list_trusted
      []
    end
  end
  def initialize(args)
    @file_name = args[:file]
    @name = /.*[\/\\]+([^\.]+)\./.match(@file_name).captures.first
    if args[:args].class == String
      if args[:args].empty?
        @vars = Array.new
      else
        @vars = [args[:args]]
        @vars.concat args[:args].scan(/[^\s"]*(?<!\\)"(?:\\"|[^"])+(?<!\\)"[^\s]*|(?:\\"|[^"\s])+/).collect { |s| s.gsub(/(?<!\\)"/, '').gsub('\\"', '"') }
      end
    elsif args[:args].class == Array
      unless (args[:args].nil? || args[:args].empty?)
        @vars = [ args[:args].join(" ") ]
        @vars.concat args[:args]
      else
        @vars = Array.new
      end
    else
      @vars = Array.new
    end
    @quiet = (args[:quiet] ? true : false)
    @downstream_buffer = LimitedArray.new
    @want_downstream = true
    @want_downstream_xml = false
    @want_script_output = false
    @upstream_buffer = LimitedArray.new
    @want_upstream = false
    @unique_buffer = LimitedArray.new
    @watchfor = Hash.new
    @at_exit_procs = Array.new
    @die_with = Array.new
    @paused = false
    @hidden = false
    @no_pause_all = false
    @no_kill_all = false
    @silent = false
    @safe = false
    @no_echo = false
    @match_stack_labels = Array.new
    @match_stack_strings = Array.new
    @label_order = Array.new
    @labels = Hash.new
    @killer_mutex = Mutex.new
    @ignore_pause = false
    data = nil
    if @file_name =~ /\.gz$/i
      begin
        Zlib::GzipReader.open(@file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
      rescue
        respond "--- Lich: error reading script file (#{@file_name}): #{$!}"
        return nil
      end
    else
      begin
        File.open(@file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
      rescue
        respond "--- Lich: error reading script file (#{@file_name}): #{$!}"
        return nil
      end
    end
    @quiet = true if data[0] =~ /^[\t\s]*#?[\t\s]*(?:quiet|hush)$/i
    @current_label = '~start'
    @labels[@current_label] = String.new
    @label_order.push(@current_label)
    for line in data
      if line =~ /^([\d_\w]+):$/
        @current_label = $1
        @label_order.push(@current_label)
        @labels[@current_label] = String.new
      else
        @labels[@current_label].concat "#{line}\n"
      end
    end
    data = nil
    @current_label = @label_order[0]
    @thread_group = ThreadGroup.new
    @@running.push(self)
    return self
  end

  def kill
    Thread.new {
      @killer_mutex.synchronize {
        if @@running.include?(self)
          begin
            @thread_group.list.dup.each { |t|
              unless t == Thread.current
                t.kill rescue nil
              end
            }
            @thread_group.add(Thread.current)
            @die_with.each { |script_name| Script.kill(script_name) }
            @paused = false
            @at_exit_procs.each { |p| report_errors { p.call } }
            @die_with = @at_exit_procs = @downstream_buffer = @upstream_buffer = @match_stack_labels = @match_stack_strings = nil
            @@running.delete(self)
            respond("--- Lich: #{@name} has exited.") unless @quiet
            GC.start
          rescue
            respond "--- Lich: error: #{$!}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          end
        end
      }
    }
    @name
  end

  def at_exit(&block)
    if block
      @at_exit_procs.push(block)
      return true
    else
      respond '--- warning: Script.at_exit called with no code block'
      return false
    end
  end

  def clear_exit_procs
    @at_exit_procs.clear
    true
  end

  def exit
    kill
  end

  def exit!
    @at_exit_procs.clear
    kill
  end

  def instance_variable_get(*a); nil; end

  def instance_eval(*a);         nil; end

  def labels
    @labels
  end

  def thread_group
    @thread_group
  end

  def has_thread?(t)
    @thread_group.list.include?(t)
  end

  def pause
    respond "--- Lich: #{@name} paused."
    @paused = true
  end

  def unpause
    respond "--- Lich: #{@name} unpaused."
    @paused = false
  end

  def paused?
    @paused
  end

  def get_next_label
    if !@jump_label
      @current_label = @label_order[@label_order.index(@current_label) + 1]
    else
      if label = @labels.keys.find { |val| val =~ /^#{@jump_label}$/ }
        @current_label = label
      elsif label = @labels.keys.find { |val| val =~ /^#{@jump_label}$/i }
        @current_label = label
      elsif label = @labels.keys.find { |val| val =~ /^labelerror$/i }
        @current_label = label
      else
        @current_label = nil
        return JUMP_ERROR
      end
      @jump_label = nil
      @current_label
    end
  end

  def clear
    to_return = @downstream_buffer.dup
    @downstream_buffer.clear
    to_return
  end

  def to_s
    @name
  end

  def gets
    # fixme: no xml gets
    if @want_downstream or @want_downstream_xml or @want_script_output
      sleep 0.05 while @downstream_buffer.empty?
      @downstream_buffer.shift
    else
      echo 'this script is set as unique but is waiting for game data...'
      sleep 2
      false
    end
  end

  def gets?
    if @want_downstream or @want_downstream_xml or @want_script_output
      if @downstream_buffer.empty?
        nil
      else
        @downstream_buffer.shift
      end
    else
      echo 'this script is set as unique but is waiting for game data...'
      sleep 2
      false
    end
  end

  def upstream_gets
    sleep 0.05 while @upstream_buffer.empty?
    @upstream_buffer.shift
  end

  def upstream_gets?
    if @upstream_buffer.empty?
      nil
    else
      @upstream_buffer.shift
    end
  end

  def unique_gets
    sleep 0.05 while @unique_buffer.empty?
    @unique_buffer.shift
  end

  def unique_gets?
    if @unique_buffer.empty?
      nil
    else
      @unique_buffer.shift
    end
  end

  def safe?
    @safe
  end

  def feedme_upstream
    @want_upstream = !@want_upstream
  end

  def match_stack_add(label, string)
    @match_stack_labels.push(label)
    @match_stack_strings.push(string)
  end

  def match_stack_clear
    @match_stack_labels.clear
    @match_stack_strings.clear
  end
end

class ExecScript < Script
  @@name_exec_mutex = Mutex.new
  attr_reader :cmd_data

  def ExecScript.start(cmd_data, options = {})
    options = { :quiet => true } if options == true
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

class WizardScript < Script
  def initialize(file_name, cli_vars = [])
    @name = /.*[\/\\]+([^\.]+)\./.match(file_name).captures.first
    @file_name = file_name
    @vars = Array.new
    @killer_mutex = Mutex.new
    unless cli_vars.empty?
      if cli_vars.is_a?(String)
        cli_vars = cli_vars.split(' ')
      end
      cli_vars.each_index { |idx| @vars[idx + 1] = cli_vars[idx] }
      @vars[0] = @vars[1..-1].join(' ')
      cli_vars = nil
    end
    if @vars.first =~ /^quiet$/i
      @quiet = true
      @vars.shift
    else
      @quiet = false
    end
    @downstream_buffer = LimitedArray.new
    @want_downstream = true
    @want_downstream_xml = false
    @upstream_buffer = LimitedArray.new
    @want_upstream = false
    @unique_buffer = LimitedArray.new
    @at_exit_procs = Array.new
    @patchfor = Hash.new
    @die_with = Array.new
    @paused = false
    @hidden = false
    @no_pause_all = false
    @no_kill_all = false
    @silent = false
    @safe = false
    @no_echo = false
    @match_stack_labels = Array.new
    @match_stack_strings = Array.new
    @label_order = Array.new
    @labels = Hash.new
    data = nil
    begin
      Zlib::GzipReader.open(file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
    rescue
      begin
        File.open(file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
      rescue
        respond "--- Lich: error reading script file (#{file_name}): #{$!}"
        return nil
      end
    end
    @quiet = true if data[0] =~ /^[\t\s]*#?[\t\s]*(?:quiet|hush)$/i

    counter_action = {
      'add' => '+',
      'sub' => '-',
      'subtract' => '-',
      'multiply' => '*',
      'divide' => '/',
      'set' => ''
    }

    setvars = Array.new
    data.each { |line| setvars.push($1) if line =~ /[\s\t]*setvariable\s+([^\s\t]+)[\s\t]/i and not setvars.include?($1) }
    has_counter = data.find { |line| line =~ /%c/i }
    has_save = data.find { |line| line =~ /%s/i }
    has_nextroom = data.find { |line| line =~ /nextroom/i }

    fixstring = proc { |str|
      while not setvars.empty? and str =~ /%(#{setvars.join('|')})%/io
        str.gsub!('%' + $1 + '%', '#{' + $1.downcase + '}')
      end
      str.gsub!(/%c(?:%)?/i, '#{c}')
      str.gsub!(/%s(?:%)?/i, '#{sav}')
      while str =~ /%([0-9])(?:%)?/
        str.gsub!(/%#{$1}(?:%)?/, '#{script.vars[' + $1 + ']}')
      end
      str
    }

    fixline = proc { |line|
      if line =~ /^[\s\t]*[A-Za-z0-9_\-']+:/i
        line = line.downcase.strip
      elsif line =~ /^([\s\t]*)counter\s+(add|sub|subtract|divide|multiply|set)\s+([0-9]+)/i
        line = "#{$1}c #{counter_action[$2]}= #{$3}"
      elsif line =~ /^([\s\t]*)counter\s+(add|sub|subtract|divide|multiply|set)\s+(.*)/i
        indent, action, arg = $1, $2, $3
        line = "#{indent}c #{counter_action[action]}= #{fixstring.call(arg.inspect)}.to_i"
      elsif line =~ /^([\s\t]*)save[\s\t]+"?(.*?)"?[\s\t]*$/i
        indent, arg = $1, $2
        line = "#{indent}sav = #{fixstring.call(arg.inspect)}"
      elsif line =~ /^([\s\t]*)echo[\s\t]+(.+)/i
        indent, arg = $1, $2
        line = "#{indent}echo #{fixstring.call(arg.inspect)}"
      elsif line =~ /^([\s\t]*)waitfor[\s\t]+(.+)/i
        indent, arg = $1, $2
        line = "#{indent}waitfor #{fixstring.call(Regexp.escape(arg).inspect.gsub("\\\\ ", ' '))}"
      elsif line =~ /^([\s\t]*)put[\s\t]+\.(.+)$/i
        indent, arg = $1, $2
        if arg.include?(' ')
          line = "#{indent}start_script(#{Regexp.escape(fixstring.call(arg.split[0].inspect))}, #{fixstring.call(arg.split[1..-1].join(' ').scan(/"[^"]+"|[^"\s]+/).inspect)})\n#{indent}exit"
        else
          line = "#{indent}start_script(#{Regexp.escape(fixstring.call(arg.inspect))})\n#{indent}exit"
        end
      elsif line =~ /^([\s\t]*)put[\s\t]+;(.+)$/i
        indent, arg = $1, $2
        if arg.include?(' ')
          line = "#{indent}start_script(#{Regexp.escape(fixstring.call(arg.split[0].inspect))}, #{fixstring.call(arg.split[1..-1].join(' ').scan(/"[^"]+"|[^"\s]+/).inspect)})"
        else
          line = "#{indent}start_script(#{Regexp.escape(fixstring.call(arg.inspect))})"
        end
      elsif line =~ /^([\s\t]*)(put|move)[\s\t]+(.+)/i
        indent, cmd, arg = $1, $2, $3
        line = "#{indent}waitrt?\n#{indent}clear\n#{indent}#{cmd.downcase} #{fixstring.call(arg.inspect)}"
      elsif line =~ /^([\s\t]*)goto[\s\t]+(.+)/i
        indent, arg = $1, $2
        line = "#{indent}goto #{fixstring.call(arg.inspect).downcase}"
      elsif line =~ /^([\s\t]*)waitforre[\s\t]+(.+)/i
        indent, arg = $1, $2
        line = "#{indent}waitforre #{arg}"
      elsif line =~ /^([\s\t]*)pause[\s\t]*(.*)/i
        indent, arg = $1, $2
        arg = '1' if arg.empty?
        arg = '0' + arg.strip if arg.strip =~ /^\.[0-9]+$/
        line = "#{indent}pause #{arg}"
      elsif line =~ /^([\s\t]*)match[\s\t]+([^\s\t]+)[\s\t]+(.+)/i
        indent, label, arg = $1, $2, $3
        line = "#{indent}match #{fixstring.call(label.inspect).downcase}, #{fixstring.call(Regexp.escape(arg).inspect.gsub("\\\\ ", ' '))}"
      elsif line =~ /^([\s\t]*)matchre[\s\t]+([^\s\t]+)[\s\t]+(.+)/i
        indent, label, regex = $1, $2, $3
        line = "#{indent}matchre #{fixstring.call(label.inspect).downcase}, #{regex}"
      elsif line =~ /^([\s\t]*)setvariable[\s\t]+([^\s\t]+)[\s\t]+(.+)/i
        indent, var, arg = $1, $2, $3
        line = "#{indent}#{var.downcase} = #{fixstring.call(arg.inspect)}"
      elsif line =~ /^([\s\t]*)deletevariable[\s\t]+(.+)/i
        line = "#{$1}#{$2.downcase} = nil"
      elsif line =~ /^([\s\t]*)(wait|nextroom|exit|echo)\b/i
        line = "#{$1}#{$2.downcase}"
      elsif line =~ /^([\s\t]*)matchwait\b/i
        line = "#{$1}matchwait"
      elsif line =~ /^([\s\t]*)if_([0-9])[\s\t]+(.*)/i
        indent, num, stuff = $1, $2, $3
        line = "#{indent}if script.vars[#{num}]\n#{indent}\t#{fixline.call($3)}\n#{indent}end"
      elsif line =~ /^([\s\t]*)shift\b/i
        line = "#{$1}script.vars.shift"
      else
        respond "--- Lich: unknown line: #{line}"
        line = '#' + line
      end
    }

    lich_block = false

    data.each_index { |idx|
      if lich_block
        if data[idx] =~ /\}[\s\t]*LICH[\s\t]*$/
          data[idx] = data[idx].sub(/\}[\s\t]*LICH[\s\t]*$/, '')
          lich_block = false
        else
          next
        end
      elsif data[idx] =~ /^[\s\t]*#|^[\s\t]*$/
        next
      elsif data[idx] =~ /^[\s\t]*LICH[\s\t]*\{/
        data[idx] = data[idx].sub(/LICH[\s\t]*\{/, '')
        if data[idx] =~ /\}[\s\t]*LICH[\s\t]*$/
          data[idx] = data[idx].sub(/\}[\s\t]*LICH[\s\t]*$/, '')
        else
          lich_block = true
        end
      else
        data[idx] = fixline.call(data[idx])
      end
    }

    if has_counter or has_save or has_nextroom
      data.each_index { |idx|
        next if data[idx] =~ /^[\s\t]*#/

        data.insert(idx, '')
        data.insert(idx, 'c = 0') if has_counter
        data.insert(idx, "sav = Settings['sav'] || String.new\nbefore_dying { Settings['sav'] = sav }") if has_save
        data.insert(idx, "def nextroom\n\troom_count = XMLData.room_count\n\twait_while { room_count == XMLData.room_count }\nend") if has_nextroom
        data.insert(idx, '')
        break
      }
    end

    @current_label = '~start'
    @labels[@current_label] = String.new
    @label_order.push(@current_label)
    for line in data
      if line =~ /^([\d_\w]+):$/
        @current_label = $1
        @label_order.push(@current_label)
        @labels[@current_label] = String.new
      else
        @labels[@current_label] += "#{line}\n"
      end
    end
    data = nil
    @current_label = @label_order[0]
    @thread_group = ThreadGroup.new
    @@running.push(self)
    return self
  end
end
