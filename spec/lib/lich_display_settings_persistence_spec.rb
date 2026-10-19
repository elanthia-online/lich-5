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
  def real_settings(body, game: 'DR')
    source = <<~RUBY
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
      #{body}
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, '-e', source, chdir: File.expand_path('../..', __dir__))
    expect(status.success?).to be(true), err
    JSON.parse(out)
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
        fallback = Lich.#{name}
        unresolved = Lich.instance_variable_get(:@display_settings_cache)[#{name.inspect}.to_sym]
        db.define_singleton_method(:get_first_value) { |*| #{saved.inspect} }
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
      puts JSON.generate([error, attempts, pauses, Lich.display_uid,
                          db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq(['write failed', 1, [], true, 'true'])
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
      during = hooks.run('room')
      retained = hooks.list.include?('display-busy')
      unresolved = Lich.instance_variable_get(:@display_settings_cache)[:display_uid]
      db.define_singleton_method(:get_first_value) { |*| 'true' }
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
          real.busy_timeout(25)
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
          resume.pop
        end
        original.call(name, value)
      end
      first = Thread.new { Thread.current[:actor] = :first; Lich.display_uid = true }
      publication.pop
      second = Thread.new { Thread.current[:actor] = :second; Lich.display_uid = false }
      attempted.pop
      before = db.get_first_value('SELECT value FROM lich_settings')
      resume << true
      [first, second].each(&:value)
      puts JSON.generate([before, Lich.display_uid, db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq(['true', false, 'false'])
  end

  it 'serializes an ordinary cached getter with an in-flight write publication' do
    result = real_settings(<<~'RUBY')
      Lich.display_uid = false
      publication = Queue.new
      resume = Queue.new
      attempted = Queue.new
      lock = Lich.instance_variable_get(:@display_settings_mutex)
      lock.define_singleton_method(:synchronize) do |&block|
        attempted << true if Thread.current[:reader]
        super(&block)
      end
      cache = Lich.instance_variable_get(:@display_settings_cache)
      original = cache.method(:[]=)
      cache.define_singleton_method(:[]=) do |name, value|
        publication << true
        resume.pop
        original.call(name, value)
      end
      writer = Thread.new { Lich.display_uid = true }
      publication.pop
      reader = Thread.new { Thread.current[:reader] = true; Lich.display_uid }
      attempted.pop
      resume << true
      writer.value
      puts JSON.generate([reader.value, db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq([true, 'true'])
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
          resume.pop
        end
        value
      end
      reader = Thread.new { Thread.current[:reader] = true; Lich.display_uid }
      fetched.pop
      writer = Thread.new { Thread.current[:writer] = true; Lich.display_uid = true }
      attempted.pop
      resume << true
      [reader, writer].each(&:value)
      puts JSON.generate([Lich.display_uid, db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq([true, 'true'])
  end

  it 'publishes a committed value before delivering a thread interrupt' do
    result = real_settings(<<~'RUBY')
      Lich.display_uid = false
      publication = Queue.new
      resume = Queue.new
      cache = Lich.instance_variable_get(:@display_settings_cache)
      original = cache.method(:[]=)
      cache.define_singleton_method(:[]=) do |name, value|
        publication << true
        resume.pop
        original.call(name, value)
      end
      writer = Thread.new do
        Thread.current.report_on_exception = false
        Lich.display_uid = true
      end
      publication.pop
      writer.raise(RuntimeError, 'interrupted after commit')
      resume << true
      error = begin
        writer.value
        nil
      rescue RuntimeError => e
        e.message
      end
      puts JSON.generate([error, Lich.display_uid, db.get_first_value('SELECT value FROM lich_settings')])
    RUBY
    expect(result).to eq(['interrupted after commit', true, 'true'])
  end
end
