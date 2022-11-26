module Setting
  @@load = proc { |args|
    unless script = Script.current
      respond '--- error: Setting.load: calling script is unknown'
      respond $!.backtrace[0..2]
      next nil
    end
    if script.class == ExecScript
      respond "--- Lich: error: Setting.load: exec scripts can't have settings"
      respond $!.backtrace[0..2]
      exit
    end
    if args.empty?
      respond '--- error: Setting.load: no setting specified'
      respond $!.backtrace[0..2]
      exit
    end
    if args.any? { |a| a.class != String }
      respond "--- Lich: error: Setting.load: non-string given as setting name"
      respond $!.backtrace[0..2]
      exit
    end
    values = Array.new
    for setting in args
      begin
        v = Lich.db.get_first_value('SELECT value FROM script_setting WHERE script=? AND name=?;', script.name.encode('UTF-8'), setting.encode('UTF-8'))
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
      if v.nil?
        values.push(v)
      else
        begin
          values.push(Marshal.load(v))
        rescue
          respond "--- Lich: error: Setting.load: #{$!}"
          respond $!.backtrace[0..2]
          exit
        end
      end
    end
    if args.length == 1
      next values[0]
    else
      next values
    end
  }
  @@save = proc { |hash|
    unless script = Script.current
      respond '--- error: Setting.save: calling script is unknown'
      respond $!.backtrace[0..2]
      next nil
    end
    if script.class == ExecScript
      respond "--- Lich: error: Setting.load: exec scripts can't have settings"
      respond $!.backtrace[0..2]
      exit
    end
    if hash.class != Hash
      respond "--- Lich: error: Setting.save: invalid arguments: use Setting.save('setting1' => 'value1', 'setting2' => 'value2')"
      respond $!.backtrace[0..2]
      exit
    end
    if hash.empty?
      next nil
    end

    if hash.keys.any? { |k| k.class != String }
      respond "--- Lich: error: Setting.save: non-string given as a setting name"
      respond $!.backtrace[0..2]
      exit
    end
    if hash.length > 1
      begin
        Lich.db.execute('BEGIN')
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
    end
    hash.each { |setting, value|
      begin
        if value.nil?
          begin
            Lich.db.execute('DELETE FROM script_setting WHERE script=? AND name=?;', script.name.encode('UTF-8'), setting.encode('UTF-8'))
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
        else
          v = SQLite3::Blob.new(Marshal.dump(value))
          begin
            Lich.db.execute('INSERT OR REPLACE INTO script_setting(script,name,value) VALUES(?,?,?);', script.name.encode('UTF-8'), setting.encode('UTF-8'), v)
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
        end
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
    }
    if hash.length > 1
      begin
        Lich.db.execute('END')
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
    end
    true
  }
  @@list = proc {
    unless script = Script.current
      respond '--- error: Setting: unknown calling script'
      next nil
    end
    if script.class == ExecScript
      respond "--- Lich: error: Setting.load: exec scripts can't have settings"
      respond $!.backtrace[0..2]
      exit
    end
    begin
      rows = Lich.db.execute('SELECT name FROM script_setting WHERE script=?;', script.name.encode('UTF-8'))
    rescue SQLite3::BusyException
      sleep 0.1
      retry
    end
    if rows
      # fixme
      next rows.inspect
    else
      next nil
    end
  }
  def Setting.load(*args)
    @@load.call(args)
  end

  def Setting.save(hash)
    @@save.call(hash)
  end

  def Setting.list
    @@list.call
  end
end
