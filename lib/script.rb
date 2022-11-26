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
        elsif proc { begin; $SAFE = 3; true; rescue; false; end }.call
          begin
            trusted = Lich.db.get_first_value('SELECT name FROM trusted_scripts WHERE name=?;', script_name.encode('UTF-8'))
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
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
              proc { foo = script.labels[script.current_label]; foo.untaint; begin; $SAFE = 3; rescue; nil; end; eval(foo, script_binding, script.name, 1) }.call
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
      File.exists?("#{SCRIPT_DIR}/#{script_name}") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}")
    else
      File.exists?("#{SCRIPT_DIR}/#{script_name}.lic") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.lic") ||
        File.exists?("#{SCRIPT_DIR}/#{script_name}.lich") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.lich") ||
        File.exists?("#{SCRIPT_DIR}/#{script_name}.rb") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.rb") ||
        File.exists?("#{SCRIPT_DIR}/#{script_name}.cmd") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.cmd") ||
        File.exists?("#{SCRIPT_DIR}/#{script_name}.wiz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.wiz") ||
        File.exists?("#{SCRIPT_DIR}/#{script_name}.lic.gz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.lic.gz") ||
        File.exists?("#{SCRIPT_DIR}/#{script_name}.rb.gz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.rb.gz") ||
        File.exists?("#{SCRIPT_DIR}/#{script_name}.cmd.gz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.cmd.gz") ||
        File.exists?("#{SCRIPT_DIR}/#{script_name}.wiz.gz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.wiz.gz")
    end
  }
  @@elevated_log = proc { |data|
    if script = Script.current
      if script.name =~ /\\|\//
        nil
      else
        begin
          Dir.mkdir("#{LICH_DIR}/logs") unless File.exists?("#{LICH_DIR}/logs")
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
      if ($SAFE == 0) and not caller.any? { |c| c =~ /eval|run/ }
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
    ($SAFE == 0) ? @labels : nil
  end

  def thread_group
    ($SAFE == 0) ? @thread_group : nil
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
