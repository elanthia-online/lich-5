=begin
util.rb: Core lich file for collection of utilities to extend Lich capabilities.
Entries added here should always be accessible from Lich::Util.feature namespace.

    Maintainer: Elanthia-Online
    Original Author: LostRanger, Ondreian, various others
    game: Gemstone
    tags: CORE, util, utilities
    required: Lich > 5.0.19
    version: 1.1.0

  changelog:
    v1.2.0 (2022-03-16)
     * Add Lich::Util.quiet_command to mimic XML version
    v1.1.0 (2022-03-09)
     * Fix silver_count forcing downstream_xml on
    v1.0.0 (2022-03-08)
     * Initial release

=end



module Lich
  module Util
    include Enumerable

    def self.normalize_lookup(effect, val)
      caller_type = "Effects::#{effect}"
      case val
      when String
        (eval caller_type).to_h.transform_keys(&:to_s).transform_keys(&:downcase).include?(val.downcase)
      when Integer
        #      seek = mappings.fetch(val, nil)
        (eval caller_type).active?(val)
      when Symbol
        (eval caller_type).to_h.transform_keys(&:to_s).transform_keys(&:downcase).include?(val.to_s.downcase.gsub('_', ' '))
      else
        fail "invalid lookup case #{val.class.name}"
      end
    end

    ## Lifted from LR foreach.lic

    def self.anon_hook(prefix = '')
      now = Time.now
      "Util::#{prefix}-#{now}-#{Random.rand(10000)}"
    end

    def self.quiet_command_xml(command, start_pattern, end_pattern = /<prompt/, include_end = true, timeout = 5, silent = true)
      result = []
      name = self.anon_hook
      filter = false
      if silent
        save_script_silent = Script.current.silent
        Script.current.silent = true
      end
      save_want_downstream = Script.current.want_downstream
      save_want_downstream_xml = Script.current.want_downstream_xml
      Script.current.want_downstream = false
      Script.current.want_downstream_xml = true

      begin
        Timeout::timeout(timeout, Interrupt) {
          DownstreamHook.add(name, proc { |xml|
            if filter
              if xml =~ end_pattern
                DownstreamHook.remove(name)
                filter = false
              else
                next(nil)
              end
            elsif xml =~ start_pattern
              filter = true
              next(nil)
            else
              xml
            end
          })
          fput command

          until (xml = get) =~ start_pattern; end
          result << xml.rstrip
          until (xml = get) =~ end_pattern
            result << xml.rstrip
          end
          if include_end
            result << xml.rstrip
          end
        }
      rescue Interrupt
        nil
      ensure
        DownstreamHook.remove(name)
        Script.current.want_downstream_xml = save_want_downstream_xml
        Script.current.want_downstream = save_want_downstream
        Script.current.silent = save_script_silent if silent
      end
      return result
    end
    
    def self.quiet_command(command, start_pattern, end_pattern, include_end = true, timeout = 5, silent = true)
      result = []
      name = self.anon_hook
      filter = false
      if silent
        save_script_silent = Script.current.silent
        Script.current.silent = true
      end
      save_want_downstream = Script.current.want_downstream
      save_want_downstream_xml = Script.current.want_downstream_xml
      Script.current.want_downstream = true
      Script.current.want_downstream_xml = false

      begin
        Timeout::timeout(timeout, Interrupt) {
          DownstreamHook.add(name, proc { |line|
            if filter
              if line =~ end_pattern
                DownstreamHook.remove(name)
                filter = false
              else
                next(nil)
              end
            elsif line =~ start_pattern
              filter = true
              next(nil)
            else
              line
            end
          })
          fput command

          until (line = get) =~ start_pattern; end
          result << line.rstrip
          until (line = get) =~ end_pattern
            result << line.rstrip
          end
          if include_end
            result << line.rstrip
          end
        }
      rescue Interrupt
        nil
      ensure
        DownstreamHook.remove(name)
        Script.current.want_downstream_xml = save_want_downstream_xml
        Script.current.want_downstream = save_want_downstream
        Script.current.silent = save_script_silent if silent
      end
      return result
    end

    def self.silver_count(timeout = 3)
      silence_me unless undo_silence = silence_me
      result = ''
      name = self.anon_hook
      filter = false

      start_pattern = /^\s*Name\:/
      end_pattern = /^\s*Mana\:\s+\-?[0-9]+\s+Silver\:\s+([0-9,]+)/
      ttl = Time.now + timeout
      begin
        # main thread
        DownstreamHook.add(name, proc { |line|
          if filter
            if line =~ end_pattern
              result = $1.dup
              DownstreamHook.remove(name)
              filter = false
            else
              next(nil)
            end
          elsif line =~ start_pattern
            filter = true
            next(nil)
          else
            line
          end
        })
        # script thread
        fput 'info'
        loop {
          # non-blocking check, this allows us to
          # check the time even when the buffer is empty
          line = get?
          break if line && line =~ start_pattern
          break if Time.now > ttl
          sleep 0.1 # prevent a tight-loop
        }

      ensure
        DownstreamHook.remove(name)
        silence_me if undo_silence
      end
      return result.gsub(',', '').to_i
    end

  end
end
