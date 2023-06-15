# frozen_string_literal: true

# Replacement for the venerable infomon.lic script used in Lich4 and Lich5 (03/01/23)
# Supports Ruby 3.X builds
#
#     maintainer: elanthia-online
#   contributors: Tillmen, Shaelun, Athias
#           game: Gemstone
#           tags: core
#       required: Lich > 5.6.2
#        version: 2.0
#         Source: https://github.com/elanthia-online/scripts

require 'sequel'
require 'tmpdir'
require 'logger'
require_relative './cache'

module Infomon
  $infomon_debug = ENV["DEBUG"]
  # use temp dir in ci context
  @root = defined?(DATA_DIR) ? DATA_DIR : Dir.tmpdir
  @file = File.join(@root, "infomon.db")
  @db   = Sequel.sqlite(@file)
  @cache = Infomon::Cache.new
  @db.loggers << Logger.new($stdout) if ENV["DEBUG"]
  @sql_queue = Queue.new
  @sql_mutex = Mutex.new

  def self.cache
    @cache
  end

  def self.file
    @file
  end

  def self.db
    @db
  end

  def self.mutex
    @sql_mutex
  end
  
  def self.queue
    @sql_queue
  end

  def self.context!
    return unless XMLData.name.empty? or XMLData.name.nil?

    puts Exception.new.backtrace
    fail "cannot access Infomon before XMLData.name is loaded"
  end

  def self.table_name
    self.context!
    ("%s.%s" % [XMLData.game, XMLData.name]).to_sym
  end

  def self.reset!
    Infomon.db.drop_table?(self.table_name)
    Infomon.setup!
  end

  def self.table
    @_table ||= self.setup!
  end

  def self.setup!
    @db.create_table?(self.table_name) do
      string :key, primary_key: true
      string :value
      index :key, unique: true
    end

    @_table ||= @db[self.table_name]
  end

  def self._key(key)
    key = key.to_s.downcase
    key.gsub!(' ', '_').gsub!('_-_', '_').gsub!('-', '_') if key =~ /\s|-/
    return key
  end

  AllowedTypes = [Integer, String, NilClass, FalseClass, TrueClass]
  def self._validate!(key, value)
    return value if AllowedTypes.include?(value.class)
    raise "infomon:insert(%s) was called with %s\nmust be %s\nvalue=%s" % [key, value.class, AllowedTypes.map(&:name).join("|"), value]
  end

  def self.get(key)
    key = self._key(key)
    val = self.cache.get(key) { |k| 
      self.mutex.synchronize do
        db_result = self.table[key: k]
        if db_result
          db_result[:value]
        else
          nil
        end
      end
    }
    return true if val.to_s == "true"
    return false if val.to_s == "false"
    return val
  end

  def self.upsert(*args)
    self.table
        .insert_conflict(:replace)
        .insert(*args)
  end

  def self.set(key, value)
    key = self._key(key)
    value = self._validate!(key, value)
    self.cache.put(key, value)
    self.queue << "INSERT OR REPLACE INTO %s (`key`, `value`) VALUES (%s, %s)
      on conflict(`key`) do update set value = excluded.value;" % [self.db.literal(self.table_name), self.db.literal(key), self.db.literal(value)]
  end

  def self.upsert_batch(*blob)
    upserts = blob.map { |pairs|
      pairs.map { |key, value|
        (value.is_a?(Integer) or value.is_a?(String)) or fail "upsert_batch only works with Integer or String types"
        key = self._key(key)
        # add the value to the cache
        self.cache.put(key, value)
        # return a part of an sql statement to run async
        %[INSERT OR REPLACE INTO %s (`key`, `value`) VALUES (%s, %s);] % [
          self.db.literal(self.table_name),
          self.db.literal(key),
          self.db.literal(value)
        ]
      }
    }.join("\n")

    self.queue << <<~Sql
      BEGIN TRANSACTION;
      #{upserts}
      COMMIT
    Sql
  end
  
  Thread.new do
    loop do
      sql_statement = Infomon.queue.pop
      Infomon.mutex.synchronize do
        begin
          Infomon.db.run(sql_statement)
        rescue StandardError => e
          pp(e)
        end
      end
      sleep 0.1
    end
  end

  require_relative "parser"
  require_relative "cli"
end
