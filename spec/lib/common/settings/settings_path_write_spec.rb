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

  it "creates missing containers on the way as Hashes, an Integer segment included" do
    settings[:top] = 0

    write_under([:list, 0], :k, 1)

    expect(stored).to eq(top: 0, list: { 0 => { k: 1 } })
    expect(@errors).to be_empty
  end

  it "keeps a room-id style Integer key a Hash key, without padding, and lets a Symbol key join it" do
    write_under([:rooms], 12_345, 'x')
    write_under([:rooms], :note, 'y')
    write_under([:by_room, 54_321], :seen, true)

    expect(stored).to eq(rooms: { 12_345 => 'x', note: 'y' }, by_room: { 54_321 => { seen: true } })
    blob = SQLite3::Database.new(db_file).then { |db| db.get_first_value('SELECT LENGTH(hash) FROM script_auto_settings').tap { db.close } }
    expect(blob).to be < 200
    expect(@errors).to be_empty
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

  [
    [{ s: 'foobar' }, [:s], 'foo', 'X'],  # String#[]= would replace the substring
    [{ s: 'abc' }, [:s], 0, 'Z'],         # ... or the character at a position
    [{ s: 'text' }, [:s], :k, 1],         # TypeError
    [{ s: 'text' }, [:s], 'zz', 1],       # IndexError (no such substring)
    [{ n: 5 }, [:n], :k, 1],              # NoMethodError
    [{ f: false }, [:f], :k, 1],          # NoMethodError
    [{ y: :sym }, [:y], :k, 1],           # NoMethodError
    [{ deep: { s: 'abc' } }, [:deep, :s], 1, 'Z']
  ].each do |row, path, name, value|
    it "refuses #{row.inspect} with #{name.inspect} written under #{path.inspect}, whose last segment holds a value that is not a container" do
      their_write(row)

      result = :unset
      expect { result = write_under(path, name, value) }.not_to raise_error

      expect(result).to be_nil
      expect(stored).to eq(row)
      expect(settings.to_hash).to eq(row)
      expect(@errors).to include(a_string_including("not saved", "#{path.inspect} does not lead to a container"))
      expect(navigator_path).to be_empty
    end
  end

  it "creates a missing container at the last segment as a Hash, whatever the key written into it" do
    settings[:top] = 0

    write_under([:list], 0, 'x')
    write_under([:nested, :list], 0, 'y')
    write_under([:hash], :k, 1)

    expect(stored).to eq(top: 0, list: { 0 => 'x' }, nested: { list: { 0 => 'y' } }, hash: { k: 1 })
    expect(@errors).to be_empty
  end

  it "replaces a nil on the path with a Hash" do
    their_write(a: nil, b: nil, c: [nil])

    write_under([:a], 0, 'x')
    write_under([:b], :k, 1)
    write_under([:c, 0], 1, 'z')

    expect(stored).to eq(a: { 0 => 'x' }, b: { k: 1 }, c: [{ 1 => 'z' }])
  end

  it "writes at a position past the end of an Array, padding it with nil as Array#[]= does" do
    settings[:list] = [1]

    write_under([:list], 3, 'x')

    expect(stored).to eq(list: [1, nil, nil, 'x'])
    expect(@errors).to be_empty
  end

  it "clears the path before the database write, so another script's top-level write meanwhile stays top-level" do
    their_write(x: {}, top: 0)
    writer = nil
    paused = Queue.new
    go = Queue.new
    allow(@adapter).to receive(:update_settings).and_wrap_original do |original, *args, **opts, &block|
      if Thread.current.equal?(writer)
        paused << true
        go.pop
      end
      original.call(*args, **opts, &block)
    end

    writer = Thread.new { write_under([:x], :k, 1) }
    other = nil
    begin
      expect(paused.pop(timeout: 5)).to be(true) # the path write is inside the database write
      other = Thread.new { settings[:t] = 2 } # another script's top-level write
      # The other write takes the row's cache lock, which the path write
      # holds; it must not be sent under [:x] whichever way it ends up waiting.
      # Wait until it is blocked on that lock, so it is inside []= before the
      # path write goes on.
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      until other.status == 'sleep' && other.backtrace.to_a.any? { |frame| frame.include?('with_cache_lock') }
        raise 'the other write never waited on the cache lock' if !other.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.005
      end
    ensure
      go << true
      [writer, other].compact.each { |t| t.join(10) }
    end

    expect(stored).to eq(x: { k: 1 }, top: 0, t: 2)
    expect(navigator_path).to be_empty
  end

  # store_if_unchanged already makes a losing writer retry, so the cache lock
  # isn't what keeps a key in the stored row here. It orders the cache
  # updates: without it, another thread's store and cache update could land
  # between this write's store and its on_stored, which would then put the
  # older row over the newer one, and reads would be served it whenever the
  # version can't be read.
  it "keeps another thread's newer row in the cache when its write starts between this write's store and its cache update" do
    their_write(x: {}, top: 0)
    settings.to_hash # cache the row
    writer = nil
    paused = Queue.new
    go = Queue.new
    allow(@adapter).to receive(:update_settings).and_wrap_original do |original, *args, on_stored: nil, **opts, &block|
      if Thread.current.equal?(writer)
        inner = on_stored
        on_stored = lambda do |row|
          paused << true
          go.pop
          inner.call(row)
        end
      end
      original.call(*args, on_stored: on_stored, **opts, &block)
    end

    writer = Thread.new { write_under([:x], :k, 1) }
    other = nil
    begin
      expect(paused.pop(timeout: 5)).to be(true) # stored, cache not yet updated
      other = Thread.new { settings[:t] = 2 }
      # The other write either waits on the cache lock the path write holds,
      # or, with no lock, stores and caches its newer row before the path
      # write's cache update.
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      until !other.alive? || (other.status == 'sleep' && other.backtrace.to_a.any? { |frame| frame.include?('with_cache_lock') })
        raise 'the other write neither finished nor waited on the cache lock' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.005
      end
    ensure
      go << true
      [writer, other].compact.each { |t| t.join(10) }
    end

    expect(stored).to eq(x: { k: 1 }, top: 0, t: 2)
    # While another session holds the lock, the version can't be read and
    # reads answer from the cache, which must hold the newer row.
    locker = SQLite3::Database.new(db_file)
    begin
      locker.execute('BEGIN EXCLUSIVE')
      expect(@adapter.data_version).to be_nil
      expect(settings.to_hash).to eq(x: { k: 1 }, top: 0, t: 2)
    ensure
      locker.rollback if locker.transaction_active?
      locker.close
    end
  end

  it "refuses an Array indexed by a negative position on the way, tells the user, and clears the path" do
    their_write(list: [{ a: 1 }], empty: [])

    results = []
    expect do
      results << write_under([:list, -1], :k, 1) # would land in the last element
      results << write_under([:empty, -1], :k, 1) # would raise IndexError
    end.not_to raise_error

    expect(results).to eq([nil, nil])
    expect(stored).to eq(list: [{ a: 1 }], empty: [])
    expect(settings.to_hash).to eq(list: [{ a: 1 }], empty: [])
    expect(@errors).to include(a_string_including("not saved", "[:list, -1] does not lead to a container"),
                               a_string_including("not saved", "[:empty, -1] does not lead to a container"))
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

  it "stores nothing, and tells the user, for a value that refers to itself" do
    settings[:nested] = { a: 1 }
    looped = {}
    looped[:self] = looped

    result = nil
    expect { result = write_under([:nested], :k, looped) }.not_to raise_error

    expect(result).to be_nil
    expect(stored).to eq(nested: { a: 1 })
    expect(settings.to_hash).to eq(nested: { a: 1 })
    expect(@errors).to include(a_string_including("not saved", "can't be stored", "Circular reference"))
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

  it "leaves the cache holding the stored row when the writing thread is killed right after the store" do
    settings[:n] = { a: 1 }
    expect(settings.to_hash).to eq(n: { a: 1 }) # this session caches the row
    # Script#kill is Thread#kill; here it lands as soon as the adapter returns.
    allow(@adapter).to receive(:update_settings).and_wrap_original do |original, *args, **opts, &block|
      original.call(*args, **opts, &block)
      Thread.current.kill
    end

    writer = Thread.new { write_under([:n], :k, 1) }
    expect(writer.join(5)).to eq(writer)
    # Had the kill skipped the cache update, the cached row would be older
    # than the database, so the next read would re-read it; a locked database
    # makes that re-read fall back to the cached row without the key.
    allow(@adapter).to receive(:get_settings).and_raise(Sequel::DatabaseError, 'database is locked')

    expect(stored).to eq(n: { a: 1, k: 1 })
    expect(settings.to_hash).to eq(n: { a: 1, k: 1 })
  end

  it "clears the path when the write raises" do
    allow(@adapter).to receive(:update_settings).and_raise(ArgumentError, 'marshal data too short')
    allow(@adapter).to receive(:save_settings).and_raise(ArgumentError, 'marshal data too short')

    expect { write_under([:nested], :k, 1) }.to raise_error(ArgumentError)

    expect(navigator_path).to be_empty
  end
end
