# frozen_string_literal: true

# Replacement for the veneable infomon.lic script used in Lich4 and Lich5 (03/01/23)
# Supports Ruby 3.X builds
#
#     maintainer: elanthia-online
#   contributers: Tillmen, Shaelun, Athias
#           game: Gemstone
#           tags: core
#       required: Lich > 5.6.2
#        version: 2.0
#         Source: https://github.com/elanthia-online/scripts


require 'English'
require 'sequel'
require 'tmpdir'
require 'logger'

module Infomon
  $infomon_debug = ENV["DEBUG"]
  # use temp dir in ci context
  @root = defined?(DATA_DIR) ? DATA_DIR : Dir.tmpdir
  @file = File.join(@root, "infomon.db")
  @db   = Sequel.sqlite(@file)
  @db.loggers << Logger.new($stdout) if ENV["DEBUG"]
  @table_name = :infomon
  
  def self.file
    @file
  end

  def self.db
    @db
  end

  def self.reset!
    Infomon.db.drop_table?(@table_name)
    Infomon.setup!
  end

  def self.table
    @_table ||= self.setup!
  end

  def self.setup!
    @db.create_table?(@table_name) do
      string :key, primary_key: true
      blob :value
      index :key, unique: true
    end

    @_table ||= @db[@table_name]
  end

  def self._key(key)
    "%s.%s" % [Char.name, key.to_s.downcase]
  end

  def self._validate!(key, value)
    return value if [Integer, String, NilClass, FalseClass, TrueClass].include?(value.class)
    raise "infomon:insert(%s) was called with a value that was not Integer|String|NilClass\nvalue=%s\ntype=%s" % [key, value, value.class] 
  end

  def self.get(key)
    result = self.table[key: self._key(key)]
    return nil unless result
    val = result[:value]
    return nil if val.nil?
    return true if val.to_s == "true"
    return false if val.to_s == "false"
    return val.to_i if val.to_s =~ /^\d+$/ || val =~ /^-\d+$/
    return val.to_s if val
  end

  def self.upsert(*args)
    self.table
      .insert_conflict(:replace)
      .insert(*args)
  end

  def self.set(key, value)
    self.upsert(key: self._key(key), value: self._validate!(key, value))
  end

  def self.batch_set(*pairs)
    pairs
      .map {|key, value| {key: self._key(key), value: self._validate!(key, value)}}
      .each {|record| self.upsert(record)}

  end

  require_relative "parser"
end
