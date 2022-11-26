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
