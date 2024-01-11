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
  @cache ||= Infomon::Cache.new
  @cache_loaded = false
  @db.loggers << Logger.new($stdout) if ENV["DEBUG"]
  @sql_queue ||= Queue.new
  @sql_mutex ||= Mutex.new

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

  def self.mutex_lock
    begin
      self.mutex.lock unless self.mutex.owned?
    rescue StandardError
      respond "--- Lich: error: mutex_lock: #{$!}"
      Lich.log "error: mutex_lock: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
    end
  end

  def self.mutex_unlock
    begin
      self.mutex.unlock if self.mutex.owned?
    rescue StandardError
      respond "--- Lich: error: mutex_ulock: #{$!}"
      Lich.log "error: mutex_ulock: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
    end
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
    ("%s_%s" % [XMLData.game, XMLData.name]).to_sym
  end

  def self.reset!
    self.mutex_lock
    Infomon.db.drop_table?(self.table_name)
    self.cache.clear
    @cache_loaded = false
    Infomon.setup!
  end

  def self.table
    @_table ||= self.setup!
  end

  def self.setup!
    self.mutex_lock
    @db.create_table?(self.table_name) do
      text :key, primary_key: true
      any :value
    end
    self.mutex_unlock
    @_table = @db[self.table_name]
  end

  def self.cache_load
    sleep(0.01) if XMLData.name.empty?
    dataset = Infomon.table
    h = Hash[dataset.map(:key).zip(dataset.map(:value))]
    self.cache.merge!(h)
    @cache_loaded = true
  end

  def self._key(key)
    key = key.to_s.downcase
    key.tr!(' ', '_').gsub!('_-_', '_').tr!('-', '_') if /\s|-/.match?(key)
    return key
  end

  def self._value(val)
    return true if val.to_s == "true"
    return false if val.to_s == "false"
    return val
  end

  AllowedTypes = [Integer, String, NilClass, FalseClass, TrueClass]
  def self._validate!(key, value)
    return self._value(value) if AllowedTypes.include?(value.class)
    raise "infomon:insert(%s) was called with %s\nmust be %s\nvalue=%s" % [key, value.class, AllowedTypes.map(&:name).join("|"), value]
  end

  def self.get(key)
    self.cache_load if !@cache_loaded
    key = self._key(key)
    val = self.cache.get(key) {
      sleep 0.01 until self.queue.empty?
      begin
        self.mutex.synchronize do
          begin
            db_result = self.table[key: key]
            if db_result
              db_result[:value]
            else
              nil
            end
          rescue => exception
            pp(exception)
            nil
          end
        end
      rescue StandardError
        respond "--- Lich: error: self.get(#{key}): #{$!}"
        Lich.log "error: self.get(#{key}): #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      end
    }
    return self._value(val)
  end

  def self.get_bool(key)
    value = Infomon.get(key)
    if value.is_a?(TrueClass) || value.is_a?(FalseClass)
      return value
    elsif value == 1
      return true
    else
      return false
    end
  end

  def self.upsert(*args)
    self.table
        .insert_conflict(:replace)
        .insert(*args)
  end

  def self.set(key, value)
    key = self._key(key)
    value = self._validate!(key, value)
    return :noop if self.cache.get(key) == value
    self.cache.put(key, value)
    self.queue << "INSERT OR REPLACE INTO %s (`key`, `value`) VALUES (%s, %s)
      on conflict(`key`) do update set value = excluded.value;" % [self.db.literal(self.table_name), self.db.literal(key), self.db.literal(value)]
  end

  def self.delete!(key)
    key = self._key(key)
    self.cache.delete(key)
    self.queue << "DELETE FROM %s WHERE key = (%s);" % [self.db.literal(self.table_name), self.db.literal(key)]
  end

  def self.upsert_batch(*blob)
    updated = (blob.first.map { |k, v| [self._key(k), self._validate!(k, v)] } - self.cache.to_a)
    return :noop if updated.empty?
    pairs = updated.map { |key, value|
      (value.is_a?(Integer) or value.is_a?(String)) or fail "upsert_batch only works with Integer or String types"
      # add the value to the cache
      self.cache.put(key, value)
      %[(%s, %s)] % [self.db.literal(key), self.db.literal(value)]
    }.join(", ")
    # queue sql statement to run async
    self.queue << "INSERT OR REPLACE INTO %s (`key`, `value`) VALUES %s
      on conflict(`key`) do update set value = excluded.value;" % [self.db.literal(self.table_name), pairs]
  end

  Thread.new do
    loop do
      sql_statement = Infomon.queue.pop
      begin
        Infomon.mutex.synchronize do
          begin
            Infomon.db.run(sql_statement)
          rescue StandardError => e
            pp(e)
          end
        end
      rescue StandardError
        respond "--- Lich: error: ThreadQueue: #{$!}"
        Lich.log "error: ThreadQueue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      end
    end
  end

  require_relative "parser"
  require_relative "xmlparser"
  require_relative "cli"
end
