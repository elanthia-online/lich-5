# frozen_string_literal: true

# Recreating / bridging the design for CharSettings to lift in scripts into lib
# as with infomon rewrite
# Also tuning slightly, to improve / reduce db calls made by CharSettings

require 'English'
module DB_Store
  def self.read(scope = "#{XMLData.game}:#{XMLData.name}", script)
    get_data(scope, script)
  end

  def self.save(scope = "#{XMLData.game}:#{XMLData.name}", script, val)
    store_data(scope, script, val)
  end

  def self.get_data(scope = "#{XMLData.game}:#{XMLData.name}", script)
    hash = Lich.db.get_first_value(
      'SELECT hash FROM script_auto_settings WHERE script=? AND scope=?;',
      script.encode('UTF-8'),
      scope.encode('UTF-8')
    )

    return {} unless hash

    Marshal.load(hash)
  end

  def self.store_data(scope = "#{XMLData.game}:#{XMLData.name}", script, val)
    blob = SQLite3::Blob.new(Marshal.dump(val))
    return 'Error: No data to store.' unless blob

    begin
      Lich.db.execute('INSERT OR REPLACE INTO script_auto_settings(script,scope,hash) VALUES(?,?,?);',
                      script.encode('UTF-8'), scope.encode('UTF-8'), blob)
    rescue SQLite3::BusyException
      sleep 0.05
      retry
    rescue StandardError
      respond "--- Lich: error: #{$ERROR_INFO}"
      respond $ERROR_INFO.backtrace[0..1]
    end
  end
end
