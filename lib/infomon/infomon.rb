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
require 'concurrent'

module Infomon
  $infomon_debug = ENV["DEBUG"]
  # use temp dir in ci context
  @root = defined?(DATA_DIR) ? DATA_DIR : Dir.tmpdir
  @file = File.join(@root, "infomon.db")
  @db   = Sequel.sqlite(@file)
  @db.loggers << Logger.new($stdout) if ENV["DEBUG"]
  @sql_pool = Concurrent::FixedThreadPool.new(1)
  @sql_mutex = Mutex.new

  def self.file
    @file
  end

  def self.db
    @db
  end

  def self.mutex
    @sql_mutex
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

      blob :value
      index :key, unique: true
    end

    @_table ||= @db[self.table_name]
  end

  def self._key(key)
    key = key.to_s.downcase
    key.gsub!(' ', '_').gsub!('_-_', '_').gsub!('-', '_') if key =~ /\s|-/
    return key
  end

  def self._validate!(key, value)
    return value if [Integer, String, NilClass, FalseClass, TrueClass].include?(value.class)

    raise "infomon:insert(%s) was called with non-Integer|String|NilClass\nvalue=%s\ntype=%s" % [key, value,
                                                                                                 value.class]
  end

  def self.get(key)
    result = Infomon.mutex.synchronize { self.table[key: self._key(key)] }
    return nil unless result

    val = result[:value]
    return nil if val.nil?
    return true if val.to_s == "true"
    return false if val.to_s == "false"
    return val.to_i if val.to_s =~ /^\d+$/ || val =~ /^-\d+$/
    return "#{val}" if val
  end

  def self.upsert(*args)
    self.table
        .insert_conflict(:replace)
        .insert(*args)
  end

  def self.set(key, value)
    Infomon.mutex.synchronize do
      @sql_pool.post do
        self.upsert(key: self._key(key), value: self._validate!(key, value))
      end
    end
  end

  def self.upsert_batch(*blob)
    upserts = blob.map { |pairs|
      pairs.map { |key, value|
        (value.is_a?(Integer) or value.is_a?(String)) or fail "upsert_batch only works with Integer or String types"
        %[INSERT OR REPLACE INTO %s (`key`, `value`) VALUES (%s, %s);] % [
          self.db.literal(self.table_name),
          self.db.literal(self._key(key)),
          self.db.literal(value)
        ]
      }
    }.join("\n")
    self.db.run <<~Sql
      BEGIN TRANSACTION;
      #{upserts}
      COMMIT
    Sql
  end

  require_relative "parser"
  require_relative "cli"
end
