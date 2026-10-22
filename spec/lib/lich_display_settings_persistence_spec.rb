# frozen_string_literal: true

require_relative '../spec_helper'
require 'open3'
require 'rbconfig'
require 'json'

# lib/lich.rb replaces the suite's Lich mock; isolate real accessors in children.
RSpec.describe 'persisted display settings' do
  settings = %w[display_lichid display_uid display_exits display_stringprocs
                display_room_links display_room_mono display_expgains
                hide_uid_flag follow_description_flag display_roomid_location]

  # Runs real Lich settings against SQLite, outside the suite's global mocks.
  # @param body [String] child Ruby ending in a JSON result
  # @param game [String] game used for unresolved defaults
  # @return [Object] the decoded child result
  def real_settings(body, game: 'DR', preload: '', child_timeout: 30)
    source = <<~RUBY
      #{preload}
      require 'sqlite3'
      require 'json'
      require './lib/lich'
      module XMLData; end
      XMLData.define_singleton_method(:game) { #{game.inspect} }
      $frontend = 'wizard'
      db = SQLite3::Database.new(':memory:')
      db.execute('CREATE TABLE lich_settings (name TEXT PRIMARY KEY, value TEXT)')
      Lich.define_singleton_method(:db) { db }
      pauses = []
      Lich.define_singleton_method(:sleep) { |seconds| pauses << seconds }
      def wait_for(queue, label)
        queue.pop(timeout: 5) || raise("timed out waiting for \#{label}")
      end
      def thread_value(thread, label)
        raise "timed out joining \#{label}" unless thread.join(5)
        thread.value
      end
      #{body}
    RUBY
    out = err = status = nil
    Open3.popen3(RbConfig.ruby, '-e', source, chdir: File.expand_path('../..', __dir__)) do |stdin, stdout, stderr, child|
      stdin.close
      readers = [stdout, stderr].map { |stream| Thread.new { stream.read } }
      timed_out = !child.join(child_timeout)
      if timed_out
        %w[TERM KILL].each do |signal|
          begin
            Process.kill(signal, child.pid)
          rescue Errno::ESRCH
            # The child exited between the deadline check and the signal.
          end
          break if child.join(1)
        end
      end
      status = child.value # reap after termination, including on Windows
      out, err = readers.map(&:value)
      raise "display settings child timed out after #{child_timeout}s; stdout: #{out}; stderr: #{err}" if timed_out
    end
    expect(status.success?).to be(true), "child #{status.inspect}: #{err}"
    JSON.parse(out)
  end

  it 'restores nested strict scopes and the original flag after exceptions' do
    result = real_settings(<<~'RUBY')
      states = [Thread.current[:lich_strict_display_reads]]
      begin
        Lich.with_strict_display_reads do
          states << Thread.current[:lich_strict_display_reads]
          Lich.with_strict_display_reads { states << Thread.current[:lich_strict_display_reads] }
          states << Thread.current[:lich_strict_display_reads]
          raise 'read failed'
        end
      rescue RuntimeError
        states << Thread.current[:lich_strict_display_reads]
      end
      Thread.current[:lich_strict_display_reads] = false
      Lich.with_strict_display_reads { nil }
      states << Thread.current[:lich_strict_display_reads]
      puts JSON.generate(states)
    RUBY
    expect(result).to eq([nil, true, true, true, nil, false])
  end

  it 'shares the cold-read cooldown across settings, leaves defaults uncached and recovers at expiry' do
    result = real_settings(<<~'RUBY')
      clock = 100.0
      Process.define_singleton_method(:clock_gettime) { |_| clock }
      reads = 0
      db.define_singleton_method(:get_first_value) do |*|
        reads += 1
        raise SQLite3::BusyException, 'locked'
      end
      during = [Lich.display_uid, Lich.display_expgains, Lich.display_roomid_location]
      clock += 29.99
      during << Lich.display_uid
      uncached = Lich.instance_variable_get(:@display_settings_cache).empty?
      before = reads
      db.define_singleton_method(:get_first_value) { |*| reads += 1; 'true' }
      clock += 0.01
      recovered = Lich.display_uid
      puts JSON.generate([during, uncached, before, reads, recovered])
    RUBY
    expect(result).to eq([[false, true, 'line', false], true, 2, 3, true])
  end

  it 'lets strict reads bypass the cooldown and successful writes clear it for other settings' do
    result = real_settings(<<~'RUBY')
      Process.define_singleton_method(:clock_gettime) { |_| 100.0 }
      reads = 0
      busy = true
      db.define_singleton_method(:get_first_value) do |*|
        reads += 1
        raise SQLite3::BusyException if busy
        'true'
      end
      Lich.display_uid
      error = begin
        Lich.with_strict_display_reads { Lich.display_uid }
      rescue SQLite3::BusyException
        'busy'
      end
      busy = false
      strict = Lich.with_strict_display_reads { Lich.display_uid }
      Lich.display_roomid_location = 'title'
      loaded = Lich.display_lichid
      puts JSON.generate([error, strict, loaded, reads])
    RUBY
    expect(result).to eq(['busy', true, true, 6])
  end

  it 'throttles automatic UID writes and logs, preserves parsing and retries at expiry' do
    result = real_settings(<<~'RUBY', game: 'GSIV')
      LIB_DIR = File.expand_path('lib')
      require './lib/gemstone/xml_delta'
      clock = 100.0
      Process.define_singleton_method(:clock_gettime) { |_| clock }
      messages = []
      Lich.define_singleton_method(:log) { |message| messages << message }
      Lich.display_uid = false
      writes = 0
      busy = true
      db.define_singleton_method(:execute) do |*args|
        writes += 1
        raise SQLite3::BusyException, 'locked' if busy
        super(*args)
      end
      delta = Lich::Gemstone::XMLDelta
      titles = [delta.main_subtitle(' - First - 1', nav_uid_pending: false)]
      clock += 29.99
      titles << delta.main_subtitle(' - Second - 2', nav_uid_pending: false)
      failed = [writes, messages.size, Lich.display_uid, db.get_first_value('SELECT value FROM lich_settings')]
      busy = false
      clock += 0.01
      titles << delta.main_subtitle(' - Third - 3', nav_uid_pending: false)
      puts JSON.generate([titles, failed, writes, messages, Lich.display_uid,
                          db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq([[{ 'room_title' => '[First]' }, { 'room_title' => '[Second]' }, { 'room_title' => '[Third]' }],
                          [2, 1, false, 'false'], 3, ['warning: could not persist automatic display_uid: locked'], true, 'true'])
  end

  it 'allows explicit UID writes during automatic cooldown and clears it on success' do
    result = real_settings(<<~'RUBY')
      Process.define_singleton_method(:clock_gettime) { |_| 100.0 }
      Lich.define_singleton_method(:log) { |_| nil }
      Lich.display_uid = false
      failing = true
      writes = 0
      db.define_singleton_method(:execute) do |*args|
        writes += 1
        raise SQLite3::SQLException, 'write failed' if failing
        super(*args)
      end
      Lich.enable_display_uid_automatically
      Lich.enable_display_uid_automatically
      suppressed = [writes, Lich.instance_variable_get(:@display_settings_cache).key?(:display_uid), Lich.display_uid]
      error = begin
        Lich.display_uid = true
      rescue SQLite3::SQLException => e
        e.message
      end
      failing = false
      Lich.display_uid = false
      Lich.enable_display_uid_automatically
      puts JSON.generate([suppressed, error, writes, Lich.display_uid])
    RUBY
    expect(result).to eq([[1, true, false], 'write failed', 4, true])
  end

  it 'keeps the cached value when automatic UID persistence is already satisfied' do
    result = real_settings(<<~'RUBY')
      Lich.display_uid = true
      db.define_singleton_method(:execute) { |*| raise 'unexpected write' }
      db.define_singleton_method(:get_first_value) { |*| raise 'unexpected cache reload' }
      Lich.enable_display_uid_automatically
      puts JSON.generate(Lich.display_uid)
    RUBY
    expect(result).to be(true)
  end

  it 'keeps parser state after a non-busy automatic UID write failure' do
    result = real_settings(<<~'RUBY', game: 'GSIV', preload: "require './spec/spec_helper'")
      require 'ox'
      require 'common/xmlparser'
      require 'gemstone/xml_delta'
      Lich.display_uid = false
      messages = []
      Lich.define_singleton_method(:log) { |message| messages << message }
      db.define_singleton_method(:execute) { |*| raise SQLite3::SQLException, 'write failed' }
      parser = Lich::Common::XMLParser.new
      parser.instance_variable_set(:@room_id, 123)
      parser.define_singleton_method(:reset) { raise 'unexpected parser reset' }
      Ox.sax_parse(parser, %(<streamWindow id='main' title='Story' subtitle=" - Town Square - 228"/>),
                   convert_special: false, symbolize: false, skip: :skip_none)
      puts JSON.generate([parser.room_title, parser.room_id, Lich.display_uid, messages])
    RUBY
    expect(result).to eq(['[Town Square]', 123, false, ['warning: could not persist automatic display_uid: write failed']])
  end

  [false, true, :busy, :active].each do |saved|
    it "honors saved expgains at DR startup (#{saved}) without starting from a busy fallback" do
      result = real_settings(<<~RUBY, preload: "require './spec/spec_helper'")
        require 'dragonrealms/drinfomon/drexpmonitor'
        monitor = Lich::DragonRealms::DRExpMonitor
        starts = 0
        monitor.define_singleton_method(:start) { starts += 1 }
        monitor.define_singleton_method(:active?) { #{saved == :active} }
        db.execute("INSERT INTO lich_settings VALUES ('display_expgains', '#{saved == true || saved == :active}')")
        messages = []
        Lich.define_singleton_method(:log) { |message| messages << message }
        if #{saved == :busy}
          db.define_singleton_method(:get_first_value) { |*| raise SQLite3::BusyException, 'locked' }
          Lich.display_expgains # establish public cooldown; startup must bypass it
        end
        require 'dragonrealms/drinfomon'
        puts JSON.generate([starts, messages.size, Thread.current[:lich_strict_display_reads]])
      RUBY
      expect(result).to eq([saved == true ? 1 : 0, saved == :busy ? 1 : 0, nil])
    end
  end

  it 'terminates a stuck child and retains its stderr in the timeout diagnostic' do
    expect do
      real_settings("STDERR.sync = true; warn 'child reached wait'; Kernel.sleep(60)", child_timeout: 5)
    end.to raise_error(RuntimeError, /child timed out.*stderr: child reached wait/)
  end

  settings.each do |name|
    it "keeps #{name} cache and storage unchanged after two failed writes" do
      previous = name == 'display_roomid_location' ? 'line' : false
      requested = name == 'display_roomid_location' ? 'both' : true
      result = real_settings(<<~RUBY)
        Lich.public_send(#{"#{name}=".inspect}, #{previous.inspect})
        attempts = 0
        db.define_singleton_method(:execute) do |*|
          attempts += 1
          raise 'unbounded display write' if attempts > 2
          raise SQLite3::BusyException, 'database is locked'
        end
        error = begin
          Lich.public_send(#{"#{name}=".inspect}, #{requested.inspect})
          nil
        rescue SQLite3::BusyException => e
          e.class.name
        end
        puts JSON.generate([error, attempts, pauses, Lich.#{name},
                            db.get_first_value("SELECT value FROM lich_settings WHERE name='#{name}'")])
      RUBY
      expect(result).to eq(['SQLite3::BusyException', 2, [0.1], previous, previous.to_s])
    end

    it "bounds a strict cold #{name} read without caching a failed lookup" do
      saved = name == 'display_roomid_location' ? 'title' : 'true'
      result = real_settings(<<~RUBY)
        Thread.current[:lich_strict_display_reads] = true
        attempts = 0
        db.define_singleton_method(:get_first_value) do |*|
          attempts += 1
          raise 'unbounded display read' if attempts > 2
          raise SQLite3::BusyException, 'database is locked'
        end
        error = begin
          Lich.#{name}
          nil
        rescue SQLite3::BusyException => e
          e.class.name
        end
        unresolved = Lich.instance_variable_get(:@display_settings_cache)[#{name.inspect}.to_sym]
        db.define_singleton_method(:get_first_value) { |*| #{saved.inspect} }
        puts JSON.generate([error, attempts, pauses, unresolved, Lich.#{name}])
      RUBY
      expect(result).to eq(['SQLite3::BusyException', 2, [0.1], nil, saved == 'title' ? 'title' : true])
    end

    it "uses an uncached default for a busy public #{name} read and later recovers" do
      fallback = if name == 'display_roomid_location'
                   'line'
                 else
                   %w[display_room_mono display_expgains].include?(name)
                 end
      saved = name == 'display_roomid_location' ? 'title' : (!fallback).to_s
      result = real_settings(<<~RUBY)
        attempts = 0
        db.define_singleton_method(:get_first_value) do |*|
          attempts += 1
          raise 'unbounded public read' if attempts > 2
          raise SQLite3::BusyException, 'database is locked'
        end
        clock = 100.0
        Process.define_singleton_method(:clock_gettime) { |_| clock }
        fallback = Lich.#{name}
        unresolved = Lich.instance_variable_get(:@display_settings_cache)[#{name.inspect}.to_sym]
        db.define_singleton_method(:get_first_value) { |*| #{saved.inspect} }
        clock += 30.0
        puts JSON.generate([fallback, attempts, pauses, unresolved, Lich.#{name}])
      RUBY
      expect(result).to eq([fallback, 2, [0.1], nil, saved == 'title' ? 'title' : !fallback])
    end
  end

  it 'recovers from transient busy reads and writes without changing normalization' do
    result = real_settings(<<~'RUBY')
      reads = 0
      original_read = db.method(:get_first_value)
      db.define_singleton_method(:get_first_value) do |*|
        reads += 1
        raise SQLite3::BusyException if reads == 1
        'yes'
      end
      loaded = Lich.display_uid
      writes = 0
      db.define_singleton_method(:execute) do |*args|
        writes += 1
        raise SQLite3::BusyException if writes == 1
        super(*args)
      end
      Lich.display_uid = 'off'
      puts JSON.generate([loaded, reads, writes, pauses, Lich.display_uid,
                          original_read.call('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq([true, 2, 2, [0.1, 0.1], false, 'false'])
  end

  it 'preserves boolean substring/case normalization and room placement validation' do
    result = real_settings(<<~RUBY)
      names = #{(settings - ['display_roomid_location']).inspect}
      normalized = names.map do |name|
        ['yes', 'none', 'ON', false].map do |input|
          Lich.public_send("\#{name}=", input)
          Lich.public_send(name)
        end
      end
      Lich.display_roomid_location = :TITLE
      Lich.display_roomid_location = 'invalid'
      puts JSON.generate([normalized, Lich.display_roomid_location])
    RUBY
    expect(result).to eq([Array.new(9) { [true, true, false, false] }, 'title'])
  end

  it 'propagates other database failures without publishing a new cached value' do
    result = real_settings(<<~'RUBY')
      Lich.display_uid = true
      attempts = 0
      db.define_singleton_method(:execute) do |*|
        attempts += 1
        raise SQLite3::SQLException, 'write failed'
      end
      error = begin
        Lich.display_uid = false
        nil
      rescue SQLite3::SQLException => e
        e.message
      end
      retained = Lich.instance_variable_get(:@display_settings_cache).key?(:display_uid)
      puts JSON.generate([error, attempts, pauses, retained, Lich.display_uid,
                          db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq(['write failed', 1, [], true, true, 'true'])
  end

  it 'keeps a real downstream hook registered when its cold display read stays busy' do
    result = real_settings(<<~'RUBY')
      require './lib/common/downstreamhook'
      module Script
        def self.current; nil; end
      end
      messages = []
      Object.send(:define_method, :respond) { |*args| messages << args.join }
      attempts = 0
      db.define_singleton_method(:get_first_value) do |*|
        attempts += 1
        raise 'unbounded hook read' if attempts > 2
        raise SQLite3::BusyException, 'database is locked'
      end
      hooks = Lich::Common::DownstreamHook
      hooks.add('display-busy', ->(line) { "#{line}|#{Lich.display_uid}" }, persist: true)
      clock = 100.0
      Process.define_singleton_method(:clock_gettime) { |_| clock }
      during = hooks.run('room')
      retained = hooks.list.include?('display-busy')
      unresolved = Lich.instance_variable_get(:@display_settings_cache)[:display_uid]
      db.define_singleton_method(:get_first_value) { |*| 'true' }
      clock += 30.0
      after = hooks.run('room')
      puts JSON.generate([during, retained, unresolved, after, messages, attempts])
    RUBY
    expect(result).to eq(['room|false', true, nil, 'room|true', [], 2])
  end

  { 'DR'   => [false, false, false, false, false, true, true, false, false, 'line'],
    'GSIV' => [true, true, false, false, true, false, true, false, false, 'line'],
    ''     => Array.new(10) }.each do |game, expected|
    it "preserves missing-row defaults for game #{game.inspect}" do
      result = real_settings("puts JSON.generate(#{settings.inspect}.map { |name| Lich.public_send(name) })", game: game)
      expect(result).to eq(expected)
    end
  end

  it 'leaves nil defaults unresolved until the game is identified and honors Genie' do
    result = real_settings(<<~RUBY, game: '')
      before = #{settings.inspect}.map { |name| Lich.public_send(name) }
      XMLData.define_singleton_method(:game) { 'DR' }
      $frontend = 'genie'
      after = #{settings.inspect}.map { |name| Lich.public_send(name) }
      puts JSON.generate([before, after])
    RUBY
    expect(result).to eq([Array.new(10), [false, false, false, false, false, true, false, false, false, 'line']])
  end

  it 'releases a real persistent file lock failure without changing cache or storage' do
    result = real_settings(<<~'RUBY')
      require 'tmpdir'
      result = nil
      Dir.mktmpdir('lich-display-locked') do |dir|
        real = SQLite3::Database.new(File.join(dir, 'settings.db3'))
        holder = SQLite3::Database.new(File.join(dir, 'settings.db3'))
        begin
          real.execute('CREATE TABLE lich_settings (name TEXT PRIMARY KEY, value TEXT)')
          Lich.define_singleton_method(:sqlite_busy_timeout_ms) { 25 }
        Lich.configure_sqlite_connection(real)
          Lich.define_singleton_method(:db) { real }
          Lich.display_uid = false
          holder.execute('BEGIN IMMEDIATE')
          attempts = 0
          real.define_singleton_method(:execute) do |*args|
            attempts += 1
            raise 'unbounded locked write' if attempts > 2
            super(*args)
          end
          error = begin
            Lich.display_uid = true
            nil
          rescue SQLite3::BusyException => e
            e.class.name
          end
          holder.execute('ROLLBACK')
          failed = [Lich.display_uid, real.get_first_value('SELECT value FROM lich_settings')]
          attempts = 0
          Lich.display_uid = true
          result = [error, pauses, failed, Lich.display_uid, real.get_first_value('SELECT value FROM lich_settings')]
        ensure
          holder.close
          real.close
        end
      end
      puts JSON.generate(result)
    RUBY
    expect(result).to eq(['SQLite3::BusyException', [0.1], [false, 'false'], true, 'true'])
  end

  it 'serializes competing writes through cache publication in commit order' do
    result = real_settings(<<~'RUBY')
      Lich.display_uid = false
      publication = Queue.new
      resume = Queue.new
      attempted = Queue.new
      lock = Lich.instance_variable_get(:@display_settings_mutex)
      lock.define_singleton_method(:synchronize) do |&block|
        attempted << true if Thread.current[:actor] == :second
        super(&block)
      end
      cache = Lich.instance_variable_get(:@display_settings_cache)
      original = cache.method(:[]=)
      cache.define_singleton_method(:[]=) do |name, value|
        if Thread.current[:actor] == :first
          publication << true
          wait_for(resume, 'resume')
        end
        original.call(name, value)
      end
      first = Thread.new { Thread.current[:actor] = :first; Lich.display_uid = true }
      wait_for(publication, 'publication')
      second = Thread.new { Thread.current[:actor] = :second; Lich.display_uid = false }
      wait_for(attempted, 'attempted')
      before = db.get_first_value('SELECT value FROM lich_settings')
      resume << true
      thread_value(first, 'first writer')
      thread_value(second, 'second writer')
      puts JSON.generate([before, Lich.display_uid, db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq(['true', false, 'false'])
  end

  it 'returns the old cached value during a write and the new value after publication' do
    result = real_settings(<<~'RUBY')
      Lich.display_uid = false
      publication = Queue.new
      resume = Queue.new
      cache = Lich.instance_variable_get(:@display_settings_cache)
      original = cache.method(:[]=)
      cache.define_singleton_method(:[]=) do |name, value|
        publication << true
        wait_for(resume, 'resume publication')
        original.call(name, value)
      end
      writer = Thread.new { Lich.display_uid = true }
      wait_for(publication, 'publication')
      reader = Thread.new { Lich.display_uid }
      during = thread_value(reader, 'warm reader before writer resumes')
      resume << true
      thread_value(writer, 'writer')
      puts JSON.generate([during, Lich.display_uid, db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq([false, true, 'true'])
  end

  it 'prevents a cold read from overwriting a subsequent successful write' do
    result = real_settings(<<~'RUBY')
      db.execute("INSERT INTO lich_settings VALUES ('display_uid', 'false')")
      fetched = Queue.new
      resume = Queue.new
      attempted = Queue.new
      lock = Lich.instance_variable_get(:@display_settings_mutex)
      lock.define_singleton_method(:synchronize) do |&block|
        attempted << true if Thread.current[:writer]
        super(&block)
      end
      db.define_singleton_method(:get_first_value) do |*args|
        value = super(*args)
        if Thread.current[:reader]
          fetched << true
          wait_for(resume, 'resume')
        end
        value
      end
      reader = Thread.new { Thread.current[:reader] = true; Lich.display_uid }
      wait_for(fetched, 'fetched')
      writer = Thread.new { Thread.current[:writer] = true; Lich.display_uid = true }
      wait_for(attempted, 'attempted')
      resume << true
      thread_value(reader, 'cold reader')
      thread_value(writer, 'writer')
      puts JSON.generate([Lich.display_uid, db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq([true, 'true'])
  end

  it 'invalidates only the interrupted setting and reloads its committed value after a thread kill' do
    result = real_settings(<<~'RUBY')
      Lich.configure_sqlite_connection(db)
      Lich.display_uid = false
      Lich.display_exits = true
      original_read = db.method(:get_first_value)
      db.define_singleton_method(:get_first_value) { |*| raise SQLite3::BusyException, 'locked' }
      Lich.display_room_mono # establish a cooldown that must not hide the committed value
      db.define_singleton_method(:get_first_value, original_read)
      committed = Queue.new
      resume = Queue.new
      original_write = db.method(:execute)
      db.define_singleton_method(:execute) do |*args|
        result = original_write.call(*args)
        committed << true
        wait_for(resume, 'resume after commit')
        result
      end
      writer = Thread.new { Lich.display_uid = true }
      wait_for(committed, 'committed write')
      writer.kill
      thread_value(writer, 'killed writer')
      cache = Lich.instance_variable_get(:@display_settings_cache)
      before_read = [cache.key?(:display_uid), cache[:display_exits]]
      puts JSON.generate([before_read, Lich.display_uid,
                          db.get_first_value("SELECT value FROM lich_settings WHERE name='display_uid'")])
    RUBY
    expect(result).to eq([[false, true], true, 'true'])
  end

  it 'publishes a committed value before delivering a raised thread exception' do
    result = real_settings(<<~'RUBY')
      Lich.display_uid = false
      publication = Queue.new
      resume = Queue.new
      cache = Lich.instance_variable_get(:@display_settings_cache)
      original = cache.method(:[]=)
      cache.define_singleton_method(:[]=) do |name, value|
        publication << true
        wait_for(resume, 'resume')
        original.call(name, value)
      end
      writer = Thread.new do
        Thread.current.report_on_exception = false
        Lich.display_uid = true
      end
      wait_for(publication, 'publication')
      writer.raise(RuntimeError, 'interrupted after commit')
      resume << true
      error = begin
        thread_value(writer, 'interrupted writer')
        nil
      rescue RuntimeError => e
        e.message
      end
      puts JSON.generate([error, Lich.display_uid, db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq(['interrupted after commit', true, 'true'])
  end
end
