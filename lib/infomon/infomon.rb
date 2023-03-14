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

module Infomon
  $infomon_debug = ENV["DEBUG"]
  # use temp dir in ci context
  @root = defined?(DATA_DIR) ? DATA_DIR : Dir.tmpdir
  @file = File.join(@root, "infomon.db")
  @db   = Sequel.sqlite(@file)
  
  def self.file
    @file
  end

  def self.db
    @db
  end

  def self.reset!
    Infomon.db.drop_table?(:state)
    Infomon.setup!
  end

  def self.state
    @_table ||= self.setup!
  end

  def self.setup!
    @db.create_table?(:state) do
      string  :key, primary_key: true
      string :char
      blob :value
    end

    @db[:state]
  end

  def self.get(key)
    result = self.state.first(key: key.to_s.downcase, char: Char.name)
    return nil unless result
    val = result[:value]
    return nil if val.nil?
    return val.to_i if val.to_s =~ /^\d+$/ || val =~ /^-\d+$/
    return val.to_s if val
  end

  def self.set(key, value)
    key = key.to_s.downcase
    raise "Infomon.set(%s, %s) was called with a value that was not Integer|String|NilClass" % [key, value] unless [Integer, String, NilClass].include?(value.class)
    puts "infomon(%s) :set %s -> %s(%s)" % [Char.name, key, value.class.name, value] if $infomon_debug
    self.state
      .insert_conflict(:replace)
      .insert(key: key, value: value, char: Char.name)
  end

  require "infomon/parser"
end
