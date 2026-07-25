# Generated during infomon separation 230305
# script bindings are convoluted, but don't change them without testing if:
#    class methods such as Script.start and ExecScript.start become accessible without specifying the class name (which is just a syptom of a problem that will break scripts)
#    local variables become shared between scripts
#    local variable 'file' is shared between scripts, even though other local variables aren't
#    defined methods are instantly inaccessible
# also, don't put 'untrusted' in the name of the untrusted binding; it shows up in error messages and makes people think the error is caused by not trusting the script
#

require_relative 'script_death'

module Lich
  module Common
    # module Gemstone
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
      VALID_KILL_CONTEXTS = [:runtime, :shutdown].freeze

      @@elevated_script_start = proc { |args|
        if args.empty?
          # fixme: error
          next nil
        elsif args[0].is_a?(String)
          script_name = args[0]
          if args[1]
            if args[1].is_a?(String)
              script_args = args[1]
              if args[2]
                if args[2].is_a?(Hash)
                  options = args[2]
                else
                  # fixme: error
                  next nil
                end
              end
            elsif args[1].is_a?(Hash)
              options = args[1]
              script_args = (options[:args] || String.new)
            else
              # fixme: error
              next nil
            end
          else
            options = Hash.new
          end
        elsif args[0].is_a?(Hash)
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
        # Resolve via the shared resolver so script discovery stays identical
        # everywhere (custom/ root, custom/<subdir>/, then SCRIPT_DIR root).
        file_name = __find_script_file(script_name)
        script_name = file_name.sub(/\..{1,3}$/, '') if file_name
        if file_name.nil?
          respond "--- Lich: could not find script '#{script_name}' in directory #{SCRIPT_DIR} or #{SCRIPT_DIR}/custom"
          next nil
        end
        if (options[:force] != true) and (Script.running + Script.hidden).find { |s| s.name =~ /^#{Regexp.escape(script_name.sub(%r{/custom/([^/]+/)?}, ''))}$/i }
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

          if (script = Script.current)
            eval('script = Script.current', script_binding, script.name)
            Thread.current.priority = 1
            respond("--- Lich: #{script.custom? ? 'custom/' : ''}#{script.name} active.") unless script.quiet
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
              rescue JumpError
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
              rescue StandardError
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
                if (name = Script.current.name)
                  respond "--- Lich: review this script (#{name}) to make sure it isn't malicious, and type #{$clean_lich_char}trust #{name}"
                end
                Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              rescue ThreadError
                respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
                Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              rescue SystemStackError
                respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
                Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              rescue JumpError
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
              rescue StandardError
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
        if (script = Script.current)
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
        if (script = Script.current)
          if script.name =~ /^lich$/i
            respond '--- error: Script.db cannot be used by a script named lich'
            nil
          elsif script.is_a?(ExecScript)
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
      @@elevated_open_file = proc { |ext, mode, _block|
        if (script = Script.current)
          if script.name =~ /^lich$/i
            respond '--- error: Script.open_file cannot be used by a script named lich'
            nil
          elsif script.name =~ /^entry$/i
            respond '--- error: Script.open_file cannot be used by a script named entry'
            nil
          elsif script.is_a?(ExecScript)
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
      @@kill_metrics_mutex = Mutex.new
      @@kill_metrics = {
        :minute            => nil,
        :runtime_stops     => 0,
        :duration_total_ms => 0.0,
        :duration_max_ms   => 0.0,
        :failures          => 0
      }

      attr_reader :name, :vars, :safe, :file_name, :label_order, :at_exit_procs
      attr_accessor :quiet, :no_echo, :jump_label, :current_label, :want_downstream, :want_downstream_xml, :want_upstream, :want_script_output, :hidden, :paused, :silent, :no_pause_all, :no_kill_all, :downstream_buffer, :upstream_buffer, :unique_buffer, :die_with, :match_stack_labels, :match_stack_strings, :watchfor, :command_line, :ignore_pause, :killed_externally, :kill_source

      KILL_METRICS_FEATURE_FLAG = :script_kill_metrics

      class JumpError < StandardError; end
      JUMP = JumpError.exception('JUMP')
      JUMP_ERROR = JumpError.exception('JUMP_ERROR')

      # Resolves a script name to the on-disk filename that backs it.
      #
      # This is the single resolver shared by {Script.start}, {Script.version},
      # and {Script.required_lich_version} so they can never diverge in which
      # files they can see. It searches the +custom/+ root, then each
      # +custom/<subdir>/+, then +SCRIPT_DIR+, matching (in order of
      # preference) an exact name match, a case-sensitive prefix match, then a
      # case-insensitive prefix match. Any supported extension (lic/rb/cmd/wiz),
      # optionally gzip/compress suffixed, is accepted. A leading
      # +/custom/...+ marker is retained on the returned value to signal where
      # the file lives relative to +SCRIPT_DIR+.
      #
      # The script name is matched literally; callers that want extensionless
      # matching (e.g. {Script.version}) strip the extension before calling.
      #
      # @param script_name [String] the script name to resolve
      # @return [String, nil] the resolved filename (possibly +/custom/<subdir>/+-prefixed), or nil when no file matches
      def Script.__find_script_file(script_name)
        escaped = Regexp.escape(script_name)
        custom_base = File.join(SCRIPT_DIR, "custom")
        custom_dirs = []
        if File.directory?(custom_base)
          custom_dirs << custom_base
          # Dir.glob with a trailing '/' matches directories only (via readdir
          # d_type), avoiding a File.directory? stat() per entry. Critical on
          # slower filesystems where each stat() costs ~5-10ms.
          custom_dirs.concat(Dir.glob(File.join(custom_base, "*/")).map { |p| p.chomp("/") }.sort)
        end
        file_list = custom_dirs.flat_map { |dir|
          prefix = dir.sub(SCRIPT_DIR, '')
          Dir.children(dir)
             .select { |f| f =~ /\.(lic|rb|cmd|wiz)(\.(gz|Z))?$/i }
             .sort_by { |fn| fn.sub(/\.[^.]+$/, '') }
             .map { |s| "#{prefix}/#{s}" }
        } + Dir.children(SCRIPT_DIR).sort_by { |fn| fn.sub(/[.](lic|rb|cmd|wiz)$/, '') }
        file_list.find { |val| val =~ /^(?:\/custom\/(?:[^\/]+\/)?)?#{escaped}\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i } ||
          file_list.find { |val| val =~ /^(?:\/custom\/(?:[^\/]+\/)?)?#{escaped}[^.]+\.(?i:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/ } ||
          file_list.find { |val| val =~ /^(?:\/custom\/(?:[^\/]+\/)?)?#{escaped}[^.]+\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i }
      end
      private_class_method :__find_script_file

      # Extracts the leading header-comment lines from raw script source.
      #
      # A +=begin+/+=end+ block is preferred; absent that, the run of leading
      # +#+ comment lines (up to the first non-blank, non-comment line) is used.
      # This is the single source of truth for "the script's header" relied on
      # by {Script.version} and {Script.required_lich_version}.
      #
      # @param script_data [String] the full text of a script file
      # @return [Array<String>] the header comment lines (empty when none)
      def Script.__extract_header_comments(script_data)
        if script_data =~ /^=begin\r?\n?(.+?)^=end/m
          $1.split("\n")
        else
          comments = []
          script_data.split("\n").each { |line|
            if line =~ /^[\t\s]*#/
              comments.push(line)
            elsif line !~ /^[\t\s]*$/
              break
            end
          }
          comments
        end
      end
      private_class_method :__extract_header_comments

      # Reads a script file and returns its header comment lines, failing soft.
      #
      # Gzip-compressed scripts (.gz) are decompressed first, mirroring how
      # Script#initialize loads them; reading their bytes as text would
      # otherwise raise on the binary content. Header parsing must never raise
      # out of a startup version check, so a missing, unreadable, corrupt, or
      # non-text file is treated as "no header" (an empty list) rather than
      # propagating the error.
      #
      # @param file_path [String] absolute path to the script file
      # @return [Array<String>] the header comment lines, or [] when the file cannot be read or parsed
      def Script.__read_header_comments(file_path)
        data =
          if file_path =~ /\.gz$/i
            Zlib::GzipReader.open(file_path) { |f| f.read }
          else
            File.read(file_path)
          end
        __extract_header_comments(data)
      rescue SystemCallError, IOError, Zlib::Error, ArgumentError
        []
      end
      private_class_method :__read_header_comments

      # Resolves a script name to its header comment lines, or nil when not found.
      #
      # Centralizes the name -> file -> read sequence shared by {Script.version}
      # and {Script.required_lich_version}. Reading is fail-soft via
      # {Script.__read_header_comments}; a name that resolves to no file returns
      # nil, distinct from a found-but-headerless script, which returns [].
      #
      # @param script_name [String] the script name (with or without extension)
      # @return [Array<String>, nil] the header comment lines, or nil when no file matches
      def Script.__header_lines_for(script_name)
        file_name = __find_script_file(script_name.sub(/[.](lic|rb|cmd|wiz)$/, ''))
        file_name && __read_header_comments("#{SCRIPT_DIR}/#{file_name}")
      end
      private_class_method :__header_lines_for

      # Reads a script's declared +version:+ header.
      #
      # @param script_name [String] the script name (with or without extension)
      # @param script_version_required [String, nil] when given, a version to compare against
      # @return [Boolean] when +script_version_required+ is given, true if the script's version is *older* than required
      # @return [Gem::Version] when no required version is given, the script's parsed version (defaults to 0.0.0)
      # @return [nil] when the script file cannot be found
      def Script.version(script_name, script_version_required = nil)
        script_name = script_name.sub(/[.](lic|rb|cmd|wiz)$/, '')
        lines = __header_lines_for(script_name)
        if lines.nil?
          respond "--- Lich: could not find script '#{script_name}' in directory #{SCRIPT_DIR}"
          return nil
        end

        script_version = '0.0.0'
        lines.each do |line|
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

      # Reads the minimum Lich version a script declares it needs.
      #
      # Scripts advertise their floor with a +required: Lich <op> X.Y.Z+ line in
      # their header comments. All three operator forms found in the wild are
      # treated as the same "minimum version" floor:
      #
      #   required: Lich >= 5.15.0   # explicit minimum
      #   required: Lich > 5.0.1     # bare '>' (treated as a minimum, not strict)
      #   required: Lich 4.3.12      # no operator (older style)
      #
      # Only the dotted-numeric run is captured, so a stray suffix (e.g.
      # +5.0x+) yields +5.0+ rather than an unparseable string. This is the
      # single, canonical reader for the declaration, replacing the ad-hoc
      # +Script.list.find { ... }.inspect[...]+ idiom scripts have copy-pasted
      # (which only ever recognized the +>=+ form).
      #
      # When inspecting the calling script (the +script_name+ default), the
      # header is read straight from the running script's own +file_name+. This
      # avoids a lossy name->file round-trip: a running script stores only its
      # basename in +@name+, so a +custom/<subdir>/+ script could not otherwise
      # locate its own header - which would make the version guard fail open.
      #
      # @param script_name [String, nil] the script to inspect; when nil (the default), the currently running script is read directly
      # @return [String, nil] the declared minimum version (e.g. "5.15.0"), or nil when the script declares none or cannot be found
      def Script.required_lich_version(script_name = nil)
        lines =
          if script_name
            __header_lines_for(script_name)
          elsif (file_path = Script.current&.file_name)
            __read_header_comments(file_path)
          end
        return nil if lines.nil?

        required = nil
        lines.each do |line|
          required = $1.strip if line =~ /^[\s\t#]*required:[\s\t]*Lich[\s\t]*(?:>=?[\s\t]*)?([\d.]+)/i
        end
        required
      end

      # Safely parses a version string into a Gem::Version.
      #
      # Header data is author-supplied and may be malformed; a bad value must
      # never raise out of a version check and crash a script at startup.
      #
      # @param value [String, nil] the version string to parse
      # @return [Gem::Version, nil] the parsed version, or nil when the value is blank or unparseable
      def Script.__to_gem_version(value)
        value = value.to_s.strip
        return nil if value.empty?
        Gem::Version.new(value)
      rescue ArgumentError
        nil
      end
      private_class_method :__to_gem_version

      # Tests whether the running Lich satisfies a minimum version.
      #
      # A missing, blank, or unparseable minimum is treated as "no requirement"
      # and passes, so a malformed +required:+ header can never block a script.
      #
      # @param minimum [String, nil] the minimum version to require; defaults to the calling script's declared +required:+ floor
      # @return [Boolean] true if +LICH_VERSION+ is at least +minimum+, or if no usable minimum is declared/given
      def Script.lich_version_satisfied?(minimum = required_lich_version)
        required = __to_gem_version(minimum)
        return true if required.nil?
        Gem::Version.new(LICH_VERSION) >= required
      end

      # Enforces a script's minimum Lich version, terminating it if unmet.
      #
      # When the running Lich is too old, emits a frontend-aware notice (via
      # {Lich::Messaging}, which routes correctly for xml/gsl/plain clients) and
      # then stops the calling script. Intended as the one-liner scripts call at
      # startup: +Script.require_lich_version!+.
      #
      # @param minimum [String, nil] the minimum version to require; defaults to the calling script's declared +required:+ floor
      # @return [Boolean] true when the version is satisfied; otherwise false (after the script has been told to exit)
      def Script.require_lich_version!(minimum = required_lich_version)
        return true if lich_version_satisfied?(minimum)
        current = Script.current
        __warn_lich_too_old(current&.name || 'script', minimum)
        current&.exit
        false
      end

      # Emits the standard "your Lich is too old" notice.
      #
      # Output is routed through {Lich::Messaging} so it renders correctly on
      # every frontend (it resolves xml/gsl/plain via Frontend's capability
      # checks rather than poking +$frontend+ directly).
      #
      # @param script_name [String] the script reporting the requirement
      # @param minimum [String] the minimum Lich version the script needs
      # @return [void]
      def Script.__warn_lich_too_old(script_name, minimum)
        Lich::Messaging.msg('bold', '########################################')
        Lich::Messaging.msg('warn', "Script: #{script_name} now requires a newer version of Lich (#{minimum}+) to run.")
        Lich::Messaging.msg('warn', 'Please update to a newer version.')
        Lich::Messaging.msg('warn', "Currently running Lich version: #{LICH_VERSION}")
        Lich::Messaging.msg('warn', 'For help updating visit: https://gswiki.play.net/Lich_(software)/Installation')
        Lich::Messaging.msg('bold', '########################################')
      end
      private_class_method :__warn_lich_too_old

      def Script.list
        @@running.dup
      end

      def Script.current
        if (script = @@running.find { |s| s.has_thread?(Thread.current) })
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
        if (s = @@elevated_script_start.call(args))
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
          if (s = (@@running.find { |i| (i.name == name) and not i.paused? }) || (@@running.find { |i| (i.name =~ /^#{name}$/i) and not i.paused? }))
            s.pause
            true
          else
            false
          end
        end
      end

      def Script.unpause(name)
        if (s = (@@running.find { |i| (i.name == name) and i.paused? }) || (@@running.find { |i| (i.name =~ /^#{name}$/i) and i.paused? }))
          s.unpause
          true
        else
          false
        end
      end

      # Stops a running script by name.
      #
      # Used for ordinary runtime stops and, with +context: :shutdown+, by
      # shutdown teardown and +die_with+ propagation. The context is forwarded to
      # {Script#kill} so shutdown kills stay inline (avoiding a cleanup thread per
      # script) rather than reintroducing the thread burst inline teardown removes.
      #
      # @param name [String] script name (exact match, then case-insensitive)
      # @param context [Symbol] kill context forwarded to {Script#kill}
      #   (:runtime or :shutdown)
      # @return [Boolean] true when a matching running script was found and stopped
      def Script.kill(name, context: :runtime)
        unless VALID_KILL_CONTEXTS.include?(context)
          raise ArgumentError, "invalid script kill context: #{context.inspect}"
        end

        if (s = (@@running.find { |i| i.name == name }) || (@@running.find { |i| i.name =~ /^#{name}$/i }))
          s.killed_externally = true
          s.kill_source = caller[0..2]
          s.kill(context: context)
          true
        else
          false
        end
      end

      def Script.paused?(name)
        if (s = (@@running.find { |i| i.name == name }) || (@@running.find { |i| i.name =~ /^#{name}$/i }))
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
        if (script = Script.current)
          script.at_exit(&block)
        else
          respond "--- Lich: error: Script.at_exit: can't identify calling script"
          return false
        end
      end

      def Script.clear_exit_procs
        if (script = Script.current)
          script.clear_exit_procs
        else
          respond "--- Lich: error: Script.clear_exit_procs: can't identify calling script"
          return false
        end
      end

      def Script.exit!
        if (script = Script.current)
          script.exit!
        else
          respond "--- Lich: error: Script.exit!: can't identify calling script"
          return false
        end
      end

      # moved from lich.rbw 2024
      def Script.self
        Script.current
      end

      def Script.running
        list = Array.new
        for script in @@running
          list.push(script) unless script.hidden
        end
        return list
      end

      def Script.index
        Script.running
      end

      def Script.hidden
        list = Array.new
        for script in @@running
          list.push(script) if script.hidden
        end
        return list
      end

      def Script.namescript_incoming(line)
        Script.new_downstream(line)
      end

      if (RUBY_VERSION =~ /^2\.[012]\./)
        def Script.trust(script_name)
          # fixme: case sensitive blah blah
          if not caller.any? { |c| c =~ /eval|run/ }
            begin
              Lich.db.execute('INSERT OR REPLACE INTO trusted_scripts(name) values(?);', [script_name.encode('UTF-8')])
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
            there = Lich.db.get_first_value('SELECT name FROM trusted_scripts WHERE name=?;', [script_name.encode('UTF-8')])
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
          if there
            begin
              Lich.db.execute('DELETE FROM trusted_scripts WHERE name=?;', [script_name.encode('UTF-8')])
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
        def Script.trust(_script_name)
          true
        end

        def Script.distrust(_script_name)
          false
        end

        def Script.list_trusted
          []
        end
      end

      class << self
        private

        # Returns whether script-kill aggregate metrics should be collected.
        #
        # The feature flag defaults off. Keeping the check behind this helper
        # gives later runtime-facade work one narrow place to replace the flag
        # lookup with a cached runtime mode or diagnostics service.
        #
        # @return [Boolean]
        def __script_kill_metrics_enabled?
          return false unless defined?(Lich::Common::FeatureFlags)

          Lich::Common::FeatureFlags.enabled?(KILL_METRICS_FEATURE_FLAG)
        rescue StandardError => e
          Lich.log("warning: script kill metrics flag check failed: #{e.class}: #{e.message}") if defined?(Lich) && Lich.respond_to?(:log)
          false
        end

        # Records one non-shutdown script kill and logs the completed previous
        # minute when the current event rolls into a new minute bucket.
        #
        # This intentionally stores process-local, aggregate-only telemetry.
        # It does not persist script names, emit per-kill logs, or count process
        # shutdown stops. The goal is low-noise lifecycle diagnostics for
        # release validation, not user-visible runtime reporting.
        #
        # @param duration_ms [Float] elapsed kill processing time in milliseconds
        # @param failed [Boolean] whether the kill cleanup path raised
        # @return [void]
        # @api private
        def __record_kill_metric(duration_ms:, failed:)
          current_minute = Time.now.to_i / 60
          summary = nil

          @@kill_metrics_mutex.synchronize {
            if @@kill_metrics[:minute] && @@kill_metrics[:minute] != current_minute
              summary = @@kill_metrics.dup
              __reset_kill_metrics_bucket
            end

            @@kill_metrics[:minute] = current_minute
            @@kill_metrics[:runtime_stops] += 1
            @@kill_metrics[:duration_total_ms] += duration_ms
            @@kill_metrics[:duration_max_ms] = [@@kill_metrics[:duration_max_ms], duration_ms].max
            @@kill_metrics[:failures] += 1 if failed
          }

          __log_kill_metric_summary(summary) if summary
        end

        # Clears the current script-kill metric bucket while preserving the
        # mutex and hash identity used by tests and future runtime adapters.
        #
        # @return [void]
        # @api private
        def __reset_kill_metrics_bucket
          @@kill_metrics[:runtime_stops] = 0
          @@kill_metrics[:duration_total_ms] = 0.0
          @@kill_metrics[:duration_max_ms] = 0.0
          @@kill_metrics[:failures] = 0
        end

        # Emits a compact aggregate summary for a completed minute bucket.
        #
        # Callers only reach this method when the kill metrics feature flag is
        # enabled and a minute rollover has occurred. The message is deliberately
        # aggregate-only to avoid noisy per-script diagnostics in normal play.
        #
        # @param summary [Hash] completed metric bucket
        # @return [void]
        # @api private
        def __log_kill_metric_summary(summary)
          return unless summary[:runtime_stops].positive?

          avg_ms = summary[:duration_total_ms] / summary[:runtime_stops]
          Lich.log(
            "debug: script kill metrics runtime_stops_last_minute=#{summary[:runtime_stops]} " \
            "avg_ms=#{format('%.2f', avg_ms)} max_ms=#{format('%.2f', summary[:duration_max_ms])} " \
            "failures=#{summary[:failures]}"
          )
        end
      end

      def initialize(args)
        @file_name = args[:file]
        @name = /.*[\/\\]+([^\.]+)\./.match(@file_name).captures.first
        @custom = (/.*[\/\\]+(custom)[\/\\]+[^\.]+\./.match(@file_name).captures.nil? ? false : true)
        if args[:args].is_a?(String)
          if args[:args].empty?
            @vars = Array.new
          else
            @vars = [args[:args]]
            @vars.concat(args[:args].scan(/[^\s"]*(?<!\\)"(?:\\"|[^"])+(?<!\\)"[^\s]*|(?:\\"|[^"\s])+/).collect { |s| s.gsub(/(?<!\\)"/, '').gsub('\\"', '"') })
          end
        elsif args[:args].is_a?(Array)
          unless (args[:args].nil? || args[:args].empty?)
            @vars = [args[:args].join(" ")]
            @vars.concat args[:args]
          else
            @vars = Array.new
          end
        else
          @vars = Array.new
        end
        @quiet = (args[:quiet] ? true : false)
        @downstream_buffer = LimitedArray.new
        @downstream_buffer.max_size = 400
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
        @killed_externally = false
        @kill_source = nil
        @ignore_pause = false
        data = nil
        if @file_name =~ /\.gz$/i
          begin
            Zlib::GzipReader.open(@file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
          rescue
            respond "--- Lich: error reading script file (#{@file_name}): #{$!}"
            # return nil
          end
        else
          begin
            File.open(@file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
          rescue
            respond "--- Lich: error reading script file (#{@file_name}): #{$!}"
            # return nil
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
        # return self
      end

      # Stops this script and runs its before_dying/at_exit handlers.
      #
      # Runtime kills can optionally feed aggregate lifecycle metrics. Shutdown
      # kills still run normal script cleanup, but are ignored by those metrics
      # because process exit can stop many scripts for reasons unrelated to
      # ordinary script churn.
      #
      # Runtime kills run cleanup in a dedicated thread so the caller is not
      # blocked. Shutdown kills run cleanup inline instead: the shutdown drain
      # (see shutdown_script_drain.rb) kills every script in a tight loop, and on
      # long sessions spawning one cleanup thread per script there pushes the
      # process past the OS thread ceiling ("can't alloc thread"). Inline
      # teardown at shutdown is also the order we want -- sequential, not a
      # concurrent burst.
      #
      # @param context [Symbol] :runtime for ordinary script stops, :shutdown
      #   when the owning Lich process is closing
      # @return [String] script name
      def kill(context: :runtime)
        unless VALID_KILL_CONTEXTS.include?(context)
          raise ArgumentError, "invalid script kill context: #{context.inspect}"
        end

        source = @kill_source || caller[0..2]

        if context == :shutdown
          __run_kill_cleanup(source: source, context: context, record_metrics: false)
        else
          begin
            Thread.new { __run_kill_cleanup(source: source, context: context, record_metrics: true) }
          rescue ThreadError => e
            __log_kill_thread_fallback(e)
            __run_kill_cleanup(source: source, context: context, record_metrics: false)
          end
        end

        @name
      end

      # Runs the script cleanup body used by {#kill}.
      #
      # The normal lifecycle path runs this body in a separate cleanup thread,
      # preserving existing return/timing behavior. If Ruby cannot allocate that
      # thread, {#kill} calls this method inline as a degraded fallback so the
      # script is still removed from the registry and at-exit handlers still get
      # a chance to run.
      #
      # Inline fallback cleanup does not record runtime metrics. Thread
      # allocation failure is usually exit pressure or resource exhaustion, not
      # ordinary script churn, and should not pollute the runtime stop bucket.
      #
      # @param source [Array<String>] caller lines used for external-kill logging
      # @param context [Symbol] kill context, such as :runtime or :shutdown
      # @param record_metrics [Boolean] whether this cleanup can feed runtime metrics
      # @return [void]
      # @api private
      def __run_kill_cleanup(source:, context:, record_metrics:)
        # Re-entrancy guard. A die_with cycle (A die_with B and B die_with A, or
        # a self-reference) reached on the inline cleanup path routes Script.kill
        # back to this same instance on the same thread while the outer call
        # still holds @killer_mutex. Re-entering @killer_mutex.synchronize there
        # raises "deadlock; recursive locking" because it is a plain,
        # non-reentrant Mutex. The outer call is already mid-teardown and will
        # finish this script, so the re-entrant request has nothing to do.
        # (Note: we do not swap in a reentrant Monitor -- that would *run* the
        # cleanup body twice over already-nilled state, not skip it.)
        return if @killer_mutex.owned?

        @killer_mutex.synchronize {
          if @@running.include?(self)
            instrument_kill = record_metrics && (context != :shutdown) && Script.__send__(:__script_kill_metrics_enabled?)
            started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) if instrument_kill
            failed = false
            begin
              @thread_group.list.dup.each { |t|
                unless t == Thread.current
                  t.kill rescue nil
                end
              }
              @thread_group.add(Thread.current)
              # Forward the kill context so die_with dependents torn down during
              # shutdown also run inline -- otherwise they route back through the
              # default :runtime path and re-spawn the thread-per-kill burst that
              # inline shutdown teardown exists to avoid.
              @die_with.each { |script_name| Script.kill(script_name, context: context) }
              @paused = false
              @at_exit_procs.each { |p| report_errors { p.call } }
              # Let each per-script-state subsystem (the hook registries, etc.)
              # apply its own death policy for what this script registered.
              # Subsystems register with ScriptDeath, so kill does not name them;
              # cleanup keys on this instance (not its name), so a force: true
              # sibling sharing our name is unaffected. Hooks persist by default
              # (so register-and-exit patterns like ;alias keep working); a hook
              # is only removed if it opted in with persist: false.
              ScriptDeath.run(self)
              # Release per-script watchfor procs (and the bindings they
              # capture). The script is removed from @@running below, so they can
              # never fire again; cleared to {} rather than nil so a concurrent
              # new_downstream sweep still sees a safe, empty collection.
              @watchfor = {}
              # Same reasoning for the stream buffers: Script.new_downstream,
              # new_downstream_xml and new_upstream run on the parser thread and
              # push to these without a nil guard, and can fire in the window
              # before the @@running.delete below. Reset to fresh empty buffers
              # ("no pending lines") rather than nil so a concurrent push cannot
              # raise NoMethodError. Distinct arrays - never the same object.
              @downstream_buffer = LimitedArray.new
              @upstream_buffer = LimitedArray.new
              @die_with = @at_exit_procs = @match_stack_labels = @match_stack_strings = nil
              @@running.delete(self)
              unless @quiet
                if @killed_externally
                  respond("--- Lich: #{@custom ? 'custom/' : ''}#{@name} was killed. (#{source.first})")
                else
                  respond("--- Lich: #{@custom ? 'custom/' : ''}#{@name} has exited.")
                end
              end
            rescue
              failed = true
              respond "--- Lich: error: #{$!}"
              Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            ensure
              if instrument_kill
                finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                Script.__send__(
                  :__record_kill_metric,
                  :duration_ms => (finished_at - started_at) * 1000.0,
                  :failed      => failed
                )
              end
            end
          end
        }
      end
      private :__run_kill_cleanup

      # Logs when {#kill} cannot allocate its normal cleanup thread.
      #
      # @param error [ThreadError] allocation failure from `Thread.new`
      # @return [void]
      # @api private
      def __log_kill_thread_fallback(error)
        return unless defined?(Lich) && Lich.respond_to?(:log)

        Lich.log("warning: Script#kill cleanup thread unavailable for #{@name}: #{error.class}: #{error.message}; running cleanup inline")
      end
      private :__log_kill_thread_fallback

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

      def instance_variable_get(*_a); nil; end

      def instance_eval(*_a);         nil; end

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
        if @paused == true
          respond "--- Lich: #{@name} is already paused."
        else
          respond "--- Lich: #{@name} paused."
          @paused = true
        end
      end

      def unpause
        if @paused == true
          respond "--- Lich: #{@name} unpaused."
          @paused = false
        else
          respond "--- Lich: #{@name} is not paused."
        end
      end

      def paused?
        @paused
      end

      def get_next_label
        if !@jump_label
          @current_label = @label_order[@label_order.index(@current_label) + 1]
        else
          if (label = @labels.keys.find { |val| val =~ /^#{@jump_label}$/ })
            @current_label = label
          elsif (label = @labels.keys.find { |val| val =~ /^#{@jump_label}$/i })
            @current_label = label
          elsif (label = @labels.keys.find { |val| val =~ /^labelerror$/i })
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
        @downstream_buffer.clear_snapshot
      end

      def to_s
        @name
      end

      def gets(timeout = nil)
        # fixme: no xml gets
        if @want_downstream or @want_downstream_xml or @want_script_output
          @downstream_buffer.wait_shift(timeout)
        else
          echo 'this script is set as unique but is waiting for game data...'
          sleep 2
          false
        end
      end

      def gets?
        if @want_downstream or @want_downstream_xml or @want_script_output
          @downstream_buffer.try_shift
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

      def custom?
        @custom
      end
    end

    class ExecScript < Script
      @@name_exec_mutex = Mutex.new
      attr_reader :cmd_data

      def ExecScript.start(cmd_data, options = {})
        options = { :quiet => true } if options == true
        unless (new_script = ExecScript.new(cmd_data, options))
          respond '--- Lich: failed to start exec script'
          return false
        end
        new_thread = Thread.new {
          100.times { break if Script.current == new_script; sleep 0.01 }

          if (script = Script.current)
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
            rescue StandardError
              respond "--- Lich error: #{$!}"
              respond $!.backtrace.first
              Lich.log "Exception: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              Script.current.kill
            end
          else
            respond 'start_exec_script screwed up...'
          end
        }
        new_script.thread_group.add(new_thread)
        new_script
      end

      # FIXME: when modernized, ensure proper use of variables and init of parent class
      # rubocop:disable Lint/MissingSuper
      def initialize(cmd_data, flags = Hash.new)
        @cmd_data = cmd_data
        @custom = false
        @vars = Array.new
        @downstream_buffer = LimitedArray.new
        @downstream_buffer.max_size = 400
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
        if flags[:name].nil?
          num = '1'; num.succ! while @@running.any? { |s| s.name == "exec#{num}" }
          @name = "exec#{num}"
        else
          num = '1'; num.succ! while @@running.any? { |s| s.name == "#{flags[:name]}#{num}" }
          @name = "#{flags[:name]}#{num}"
        end
        @@running.push(self)
      end
      # rubocop:enable Lint/MissingSuper

      def get_next_label
        echo 'goto labels are not available in exec scripts.'
        nil
      end
    end

    class WizardScript < Script
      # FIXME: when modernized, ensure proper use of variables and init of parent class
      # rubocop:disable Lint/MissingSuper
      # rubocop:disable Lint/UselessAssignment
      # rubocop:disable Lint/InterpolationCheck
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
        @downstream_buffer.max_size = 400
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
            # return nil
          end
        end
        @quiet = true if data[0] =~ /^[\t\s]*#?[\t\s]*(?:quiet|hush)$/i

        counter_action = {
          'add'      => '+',
          'sub'      => '-',
          'subtract' => '-',
          'multiply' => '*',
          'divide'   => '/',
          'set'      => ''
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
            indent, num, _stuff = $1, $2, $3
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
        # return self
      end
      # rubocop:enable Lint/InterpolationCheck
      # rubocop:enable Lint/UselessAssignment
      # rubocop:enable Lint/MissingSuper
    end
  end
end
