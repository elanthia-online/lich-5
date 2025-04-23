##
## contextual logging
##

module Lich
  module Common
    module Log
      @@log_enabled = nil
      @@log_filter  = nil

      def self.on(filter = //)
        @@log_enabled = true
        @@log_filter = filter
        begin
          Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) values('log_enabled',?);", [@@log_enabled.to_s.encode('UTF-8')])
          Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) values('log_filter',?);", [@@log_filter.to_s.encode('UTF-8')])
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
        return nil
      end

      def self.off
        @@log_enabled = false
        @@log_filter = //
        begin
          Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) values('log_enabled',?);", [@@log_enabled.to_s.encode('UTF-8')])
          Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) values('log_filter',?);", [@@log_filter.to_s.encode('UTF-8')])
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
        return nil
      end

      def self.on?
        if @@log_enabled.nil?
          begin
            val = Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='log_enabled';")
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
          val = false if val.nil?
          @@log_enabled = (val.to_s =~ /on|true|yes/ ? true : false) if !val.nil?
        end
        return @@log_enabled
      end

      def self.filter
        if @@log_filter.nil?
          begin
            val = Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='log_filter';")
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
          val = // if val.nil?
          @@log_filter = Regexp.new(val)
        end
        return @@log_filter
      end

      def self.out(msg, label: :debug)
        return unless Script.current.vars.include?("--debug") || Log.on?
        return if msg.to_s !~ Log.filter
        if msg.is_a?(Exception)
          ## pretty-print exception
          _write _view(msg.message, label)
          msg.backtrace.to_a.slice(0..5).each do |frame| _write _view(frame, label) end
        else
          self._write _view(msg, label) # if Script.current.vars.include?("--debug")
        end
      end

      def self._write(line)
        if Script.current.vars.include?("--headless") or not defined?(:_respond)
          $stdout.write(line + "\n")
        elsif line.include?("<") and line.include?(">")
          respond(line)
        else
          _respond Preset.as(:debug, line)
        end
      end

      def self._view(msg, label)
        label = [Script.current.name, label].flatten.compact.join(".")
        safe = msg.inspect
        # safe = safe.gsub("<", "&lt;").gsub(">", "&gt;") if safe.include?("<") and safe.include?(">")
        "[#{label}] #{safe}"
      end

      def self.pp(msg, label = :debug)
        respond _view(msg, label)
      end

      def self.dump(*args)
        pp(*args)
      end

      module Preset
        def self.as(kind, body)
          %[<preset id="#{kind}">#{body}</preset>]
        end
      end
    end
  end
end
