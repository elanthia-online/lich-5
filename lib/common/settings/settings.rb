# Carve out from Lich5 for the module Settings
# 2024-06-13
module Lich
  module Common
    module Settings
      settings    = Hash.new
      md5_at_load = Hash.new
      @@settings = proc { |scope|
        unless (script = Script.current)
          respond '--- error: Settings: unknown calling script'
          next nil
        end
        unless scope =~ /^#{XMLData.game}\:#{XMLData.name}$|^#{XMLData.game}$|^\:$/
          respond '--- error: Settings: invalid scope'
          next nil
        end
        Lich.db_mutex.synchronize {
          unless settings[script.name] and settings[script.name][scope]
            begin
              marshal_hash = Lich.db.get_first_value('SELECT hash FROM script_auto_settings WHERE script=? AND scope=?;', [script.name.encode('UTF-8'), scope.encode('UTF-8')])
            rescue SQLite3::BusyException
              sleep 0.1
              retry
            end
            settings[script.name] ||= Hash.new
            if marshal_hash.nil?
              settings[script.name][scope] = Hash.new
            else
              begin
                hash = Marshal.load(marshal_hash)
              rescue
                respond "--- Lich: error: #{$!}"
                respond $!.backtrace[0..1]
                exit
              end
              settings[script.name][scope] = hash
            end
            md5_at_load[script.name] ||= Hash.new
            md5_at_load[script.name][scope] = Digest::MD5.hexdigest(settings[script.name][scope].to_s)
          end
        }
        settings[script.name][scope]
      }
      @@save = proc {
        Lich.db_mutex.synchronize {
          sql_began = false
          settings.each_pair { |script_name, scopedata|
            scopedata.each_pair { |scope, data|
              if Digest::MD5.hexdigest(data.to_s) != md5_at_load[script_name][scope]
                unless sql_began
                  begin
                    Lich.db.execute('BEGIN')
                  rescue SQLite3::BusyException
                    sleep 0.1
                    retry
                  end
                  sql_began = true
                end
                blob = SQLite3::Blob.new(Marshal.dump(data))
                begin
                  Lich.db.execute('INSERT OR REPLACE INTO script_auto_settings(script,scope,hash) VALUES(?,?,?);', [script_name.encode('UTF-8'), scope.encode('UTF-8'), blob])
                rescue SQLite3::BusyException
                  sleep 0.1
                  retry
                rescue
                  respond "--- Lich: error: #{$!}"
                  respond $!.backtrace[0..1]
                  next
                end
              end
            }
            unless Script.running?(script_name)
              settings.delete(script_name)
              md5_at_load.delete(script_name)
            end
          }
          if sql_began
            begin
              Lich.db.execute('END')
            rescue SQLite3::BusyException
              sleep 0.1
              retry
            end
          end
        }
      }
      Thread.new {
        loop {
          sleep 300
          begin
            @@save.call
          rescue
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
          end
        }
      }
      def Settings.[](name)
        @@settings.call(':')[name]
      end

      def Settings.[]=(name, value)
        @@settings.call(':')[name] = value
      end

      def Settings.to_hash(scope = ':')
        @@settings.call(scope)
      end

      def Settings.char
        @@settings.call("#{XMLData.game}:#{XMLData.name}")
      end

      def Settings.save
        @@save.call
      end

      # deprecated calls
      def Settings.load; Lich.deprecated('Settings.load', 'not using, not applicable,', caller[0]); end

      def Settings.save_all; Lich.deprecated('Settings.save_all', 'not using, not applicable,', caller[0]); end

      def Settings.clear; Lich.deprecated('Settings.clear', 'not using, not applicable,', caller[0]); end

      def Settings.auto=(_val); Lich.deprecated('Settings.auto=(val)', 'not using, not applicable,', caller[0]); end

      def Settings.auto; Lich.deprecated('Settings.auto', 'not using, not applicable,', caller[0]); end

      def Settings.autoload; Lich.deprecated('Settings.autoload', 'not using, not applicable,', caller[0]); end
    end
  end
end
