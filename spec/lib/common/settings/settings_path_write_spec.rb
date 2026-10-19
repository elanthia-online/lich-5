# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative File.join(SPEC_ROOT, 'mock_database_adapter.rb')

require 'common/settings'
require 'tmpdir'
require 'fileutils'

# Settings[k] = v while a navigation path is left on the shared navigator
# (Settings.set_path reaches it through method_missing), through the public
# API and the real DatabaseAdapter (Sequel on a throwaway SQLite file).
# "Stored" is the row as a second connection reads it from the file.
RSpec.describe Lich::Common::Settings, "Settings[]= under a navigation path, through the real DatabaseAdapter" do
  let(:settings) { Lich::Common::Settings }
  let(:tmp_dir) { Dir.mktmpdir('settings-path-write-spec') }
  let(:db_file) { File.join(tmp_dir, 'lich.db3') }

  before do
    stub_const("Script", Lich::Common::MockScript)
    stub_const("XMLData", Lich::Common::MockXMLData)
    Lich::Common::MockScript.current_name = "test_script"
    Lich::Common::MockXMLData.game = "GSIV"
    Lich::Common::MockXMLData.name = "TestCharacter"
    allow(Lich).to receive(:log)
    @errors = []
    allow(Lich::Messaging).to receive(:msg) { |kind, text| @errors << text if kind == "error" }
    SQLite3::Database.new(db_file).tap do |db|
      db.execute('CREATE TABLE script_auto_settings (script TEXT NOT NULL, scope TEXT, hash BLOB, PRIMARY KEY(script, scope));')
    end.close
    @saved_adapter = settings.instance_variable_get(:@db_adapter)
    @saved_navigator = settings.instance_variable_get(:@path_navigator)
    use_adapter(Lich::Common::DatabaseAdapter.new(tmp_dir, :script_auto_settings))
  end

  after do
    settings.instance_variable_set(:@db_adapter, @saved_adapter)
    settings.instance_variable_set(:@path_navigator, @saved_navigator)
    settings.instance_variable_set(:@settings_cache, {})
    settings.instance_variable_set(:@cache_versions, {})
    @adapter.instance_variable_get(:@db)&.disconnect
    @adapter.instance_variable_get(:@version_db)&.close
    FileUtils.remove_entry(tmp_dir)
  end

  def use_adapter(adapter)
    @adapter = adapter
    settings.instance_variable_set(:@db_adapter, adapter)
    settings.instance_variable_set(:@path_navigator, Lich::Common::PathNavigator.new(adapter))
    settings.instance_variable_set(:@settings_cache, {})
    settings.instance_variable_set(:@cache_versions, {})
  end

  # The row another process would read, straight from the file.
  def stored(script = 'test_script', scope = ':')
    db = SQLite3::Database.new(db_file)
    blob = db.get_first_value('SELECT hash FROM script_auto_settings WHERE script = ? AND scope = ?', [script, scope])
    blob ? Marshal.load(blob) : nil
  ensure
    db&.close
  end

  # Another session's commit, made on a connection of its own.
  def their_write(row, script = 'test_script', scope = ':')
    db = SQLite3::Database.new(db_file)
    db.execute('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)',
               [script, scope, SQLite3::Blob.new(Marshal.dump(row))])
  ensure
    db&.close
  end

  def navigator_path
    settings.instance_variable_get(:@path_navigator).path
  end

  # Settings[name] = value with +path+ left on the navigator. Returns what
  # Settings.[]= returned.
  def write_under(path, name, value)
    settings.set_path(path)
    settings.public_send(:[]=, name, value)
  end

  it "writes the key into the container at the path, keeps the rest of the row and clears the path" do
    settings[:top] = 0
    settings[:nested] = { deeper: { a: 1 } }

    expect(write_under([:nested, :deeper], :k, 1)).to eq(1)

    expect(stored).to eq(top: 0, nested: { deeper: { a: 1, k: 1 } })
    expect(navigator_path).to be_empty
    expect(settings.to_hash).to eq(top: 0, nested: { deeper: { a: 1, k: 1 } })
    expect(@errors).to be_empty
  end

  it "creates missing containers on the way, an Array where the next segment is an Integer" do
    settings[:top] = 0

    write_under([:list, 0], :k, 1)

    expect(stored).to eq(top: 0, list: [{ k: 1 }])
  end

  it "writes into an element of an Array and at a position of an Array" do
    settings[:list] = [{ a: 1 }]

    write_under([:list, 0], :b, 2)
    write_under([:list], 1, 'x')

    expect(stored).to eq(list: [{ a: 1, b: 2 }, 'x'])
  end

  it "keeps a key another session committed after this session read the row and before it stored" do
    settings[:top] = 0
    settings[:nested] = { a: 1 }
    expect(settings.to_hash).to eq(top: 0, nested: { a: 1 }) # this session has read the row
    injected = false
    inject = lambda do
      next if injected

      injected = true
      their_write(stored.merge(theirs: 1)) # another session commits
    end
    # Whichever way the write reads and stores the row, the other session
    # commits once, after the read and before the store.
    allow(@adapter).to receive(:save_settings).and_wrap_original do |original, *args|
      inject.call
      original.call(*args)
    end
    allow(@adapter).to receive(:update_settings).and_wrap_original do |original, *args, **opts, &block|
      original.call(*args, **opts) do |fresh|
        row = block.call(fresh)
        inject.call
        row
      end
    end

    write_under([:nested], :k, 1)

    expect(injected).to be(true)
    expect(stored).to eq(top: 0, theirs: 1, nested: { a: 1, k: 1 })
    expect(settings.to_hash).to eq(top: 0, theirs: 1, nested: { a: 1, k: 1 })
  end

  it "does not show the key when it could not be stored while another session holds the lock" do
    allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(200)
    @adapter.instance_variable_get(:@db)&.disconnect
    @adapter.instance_variable_get(:@version_db)&.close
    use_adapter(Lich::Common::DatabaseAdapter.new(tmp_dir, :script_auto_settings))
    settings[:nested] = { a: 1 }
    expect(settings.to_hash).to eq(nested: { a: 1 })

    locker = SQLite3::Database.new(db_file)
    begin
      locker.execute('BEGIN EXCLUSIVE') # another session holds the lock
      write_under([:nested], :k, 1)
      expect(@errors).to include(a_string_including("Database error while saving settings"))

      # The version can't be read while the lock is held, so reads answer
      # from this session's cached row; it must not hold what wasn't stored.
      expect(@adapter.data_version).to be_nil
      expect(settings.to_hash).to eq(nested: { a: 1 })
    ensure
      locker.rollback if locker.transaction_active?
      locker.close
    end
    expect(stored).to eq(nested: { a: 1 })
    expect(settings.to_hash).to eq(nested: { a: 1 })
    expect(navigator_path).to be_empty
  end

  it "refuses a key that can't index the Array at the path, tells the user, and clears the path" do
    settings[:list] = [1, 2]

    result = nil
    expect { result = write_under([:list], :k, 1) }.not_to raise_error

    expect(result).to be_nil
    expect(stored).to eq(list: [1, 2])
    expect(@errors).to include(a_string_including("not saved", ":k under [:list]", "Array"))
    expect(navigator_path).to be_empty
    settings[:after] = 1 # goes to the top level, not under the old path
    expect(stored).to eq(list: [1, 2], after: 1)
  end

  it "refuses a negative position, which another session's change could move" do
    settings[:list] = [1, 2]

    expect(write_under([:list], -1, 'x')).to be_nil

    expect(stored).to eq(list: [1, 2])
    expect(@errors).to include(a_string_including("not saved"))
  end

  it "refuses a path through a value that is not a container, and tells the user" do
    settings[:s] = 'text'

    expect(write_under([:s, :t], :k, 1)).to be_nil

    expect(stored).to eq(s: 'text')
    expect(@errors).to include(a_string_including("not saved", "[:s, :t] does not lead to a container"))
    expect(navigator_path).to be_empty
  end

  it "refuses an Array indexed by a non-Integer on the way, creating nothing" do
    settings[:list] = [{ a: 1 }]

    expect(write_under([:list, :x], :k, 1)).to be_nil

    expect(stored).to eq(list: [{ a: 1 }])
    expect(settings.to_hash).to eq(list: [{ a: 1 }])
  end

  it "leaves a stored row that is not a Hash alone and tells the user" do
    their_write([1, 2])

    expect(write_under([:nested], :k, 1)).to be_nil

    expect(stored).to eq([1, 2])
    expect(@errors).to include(a_string_including("stored as Array, not a Hash"))
  end

  it "stores nothing, and tells the user, for a value that can't be stored" do
    settings[:nested] = { a: 1 }

    expect { write_under([:nested], :k, proc { 1 }) }.not_to raise_error

    expect(stored).to eq(nested: { a: 1 })
    expect(settings.to_hash).to eq(nested: { a: 1 })
    expect(@errors).to include(a_string_including("not saved", "can't be stored"))
    expect(navigator_path).to be_empty
  end

  it "stores a copy, so later changes to the caller's value are not saved or shown" do
    value = { 'a' => 1 }
    write_under([:nested], :h, value)
    value['b'] = 2

    expect(stored).to eq(nested: { h: { 'a' => 1 } })
    expect(settings.to_hash).to eq(nested: { h: { 'a' => 1 } })
  end

  it "stores the value a proxy holds" do
    settings[:src] = { 'x' => [1, 2] }

    write_under([:nested], :copy, settings[:src])

    expect(stored[:nested][:copy]).to eq('x' => [1, 2])
    expect(stored[:nested][:copy]).to be_a(Hash)
  end

  it "writes nothing without a script name, and clears the path" do
    Lich::Common::MockScript.current_name = nil

    expect { write_under([:nested], :k, 1) }.not_to raise_error

    rows = SQLite3::Database.new(db_file).then { |db| db.get_first_value('SELECT COUNT(*) FROM script_auto_settings').tap { db.close } }
    expect(rows).to eq(0)
    expect(navigator_path).to be_empty
  end

  it "clears the path when the write raises" do
    allow(@adapter).to receive(:update_settings).and_raise(ArgumentError, 'marshal data too short')
    allow(@adapter).to receive(:save_settings).and_raise(ArgumentError, 'marshal data too short')

    expect { write_under([:nested], :k, 1) }.to raise_error(ArgumentError)

    expect(navigator_path).to be_empty
  end
end
