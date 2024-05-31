require 'sequel'

module Settings
  settings    = Hash.new
  md5_at_load = Hash.new
  mutex       = Mutex.new
  @@settings = proc { |scope|
    unless (script = Script.current)
      respond '--- error: Settings: unknown calling script'
      next nil
    end
    unless scope =~ /^#{XMLData.game}\:#{XMLData.name}$|^#{XMLData.game}$|^\:$/
      respond '--- error: Settings: invalid scope'
      next nil
    end
    mutex.synchronize {
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
    mutex.synchronize {
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

  def Settings.load()
    # todo: this does nothing.... we should deprecate it, every script under the sun seems to use it :frown:
  end
end

# todo: rename this once we verify behaviors
module SettingsNew
  @file       = File.join(DATA_DIR, "lich.db3")
  @db         = Sequel.sqlite(@file)
  @table_name = :script_auto_settings

  def self.setup!
    @db.create_table?(@table_name) do
      text :script
      text :scope
      blob :hash
    end
    @_table = @db[@table_name]
    @_table
  end

  def self.table
    return @_table if @_table
    self.setup!
  end

  def self.current_script_settings(scope = ":")
    entry = self.table.first(script: Script.current.name, scope: scope)
    return {} if entry.nil?
    binary = entry[:hash]
    Marshal.load(binary)
  end

  def self.[](name)
    self.current_script_settings[name]
  end

  def self.[]=(name, value)
    current = self.current_script_settings
    current[name] = value
    updated = Sequel::SQL::Blob.new(Marshal.dump(current))
    self.table
        .where(script: Script.current.name, scope: ":")
        .update(hash: updated)
  end

  def self.to_h
    self.current_script_settings
  end

  def self.to_hash(scope = ':')
    self.current_script_settings(scope)
  end

  def self.char
    self.current_script_settings("#{XMLData.game}:#{XMLData.name}")
  end

  def self.save
    :noop
  end
end
