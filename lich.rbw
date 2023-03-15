#!/usr/bin/env ruby
# encoding: US-ASCII

#####
# Copyright (C) 2005-2006 Murray Miron
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#   Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
#   Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
#   Neither the name of the organization nor the names of its contributors
# may be used to endorse or promote products derived from this software
# without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#####

# Lich is maintained by Matt Lowe (tillmen@lichproject.org)
# Lich version 5 and higher maintained by Elanthia Online and only supports GTK3 Ruby

require 'time'
require 'socket'
require 'rexml/document'
require 'rexml/streamlistener'
require 'stringio'
require 'zlib'
require 'drb'
require 'resolv'
require 'digest/md5'
require 'json'
require 'terminal-table'

# TODO: Move all local requires to top of file
require_relative('./lib/constants')
require 'lib/version'

require 'lib/lich'
require 'lib/init'
require 'lib/front-end'

# TODO: Need to split out initiatilzation functions to move require to top of file
require 'lib/gtk'
require 'lib/gui-login'
require 'lib/db_store'
class NilClass
  def dup
    nil
  end

  def method_missing(*args)
    nil
  end

  def split(*val)
    Array.new
  end

  def to_s
    ""
  end

  def strip
    ""
  end

  def +(val)
    val
  end

  def closed?
    true
  end
end

class Numeric
  def as_time
    sprintf("%d:%02d:%02d", (self / 60).truncate, self.truncate % 60, ((self % 1) * 60).truncate)
  end

  def with_commas
    self.to_s.reverse.scan(/(?:\d*\.)?\d{1,3}-?/).join(',').reverse
  end
end

class String
  def to_s
    self.dup
  end

  def stream
    @stream
  end

  def stream=(val)
    @stream ||= val
  end
end

class StringProc
  def initialize(string)
    @string = string
  end

  def kind_of?(type)
    Proc.new {}.kind_of? type
  end

  def class
    Proc
  end

  def call(*a)
    proc { eval(@string) }.call
  end

  def _dump(d = nil)
    @string
  end

  def inspect
    "StringProc.new(#{@string.inspect})"
  end

  def to_json(*args)
    ";e #{_dump}".to_json(args)
  end
end

class SynchronizedSocket
  def initialize(o)
    @delegate = o
    @mutex = Mutex.new
    self
  end

  def puts(*args, &block)
    @mutex.synchronize {
      @delegate.puts *args, &block
    }
  end
  def puts_if(*args)
    @mutex.synchronize {
      if yield
         @delegate.puts *args
         return true
       else
          return false
       end
      }
  end
  def write(*args, &block)
    @mutex.synchronize {
      @delegate.write *args, &block
    }
  end

  def method_missing(method, *args, &block)
    @delegate.__send__ method, *args, &block
  end
end

class LimitedArray < Array
  attr_accessor :max_size

  def initialize(size = 0, obj = nil)
    @max_size = 200
    super
  end

  def push(line)
    self.shift while self.length >= @max_size
    super
  end

  def shove(line)
    push(line)
  end

  def history
    Array.new
  end
end

require_relative("./lib/xmlparser.rb")

class UpstreamHook
  @@upstream_hooks ||= Hash.new
  def UpstreamHook.add(name, action)
    unless action.class == Proc
      echo "UpstreamHook: not a Proc (#{action})"
      return false
    end
    @@upstream_hooks[name] = action
  end

  def UpstreamHook.run(client_string)
    for key in @@upstream_hooks.keys
      begin
        client_string = @@upstream_hooks[key].call(client_string)
      rescue
        @@upstream_hooks.delete(key)
        respond "--- Lich: UpstreamHook: #{$!}"
        respond $!.backtrace.first
      end
      return nil if client_string.nil?
    end
    return client_string
  end

  def UpstreamHook.remove(name)
    @@upstream_hooks.delete(name)
  end

  def UpstreamHook.list
    @@upstream_hooks.keys.dup
  end
end

class DownstreamHook
  @@downstream_hooks ||= Hash.new
  def DownstreamHook.add(name, action)
    unless action.class == Proc
      echo "DownstreamHook: not a Proc (#{action})"
      return false
    end
    @@downstream_hooks[name] = action
  end

  def DownstreamHook.run(server_string)
    for key in @@downstream_hooks.keys
      return nil if server_string.nil?
      begin
        server_string = @@downstream_hooks[key].call(server_string.dup) if server_string.is_a?(String)
      rescue
        @@downstream_hooks.delete(key)
        respond "--- Lich: DownstreamHook: #{$!}"
        respond $!.backtrace.first
      end
    end
    return server_string
  end

  def DownstreamHook.remove(name)
    @@downstream_hooks.delete(name)
  end

  def DownstreamHook.list
    @@downstream_hooks.keys.dup
  end
end

module Setting
  @@load = proc { |args|
    unless script = Script.current
      respond '--- error: Setting.load: calling script is unknown'
      respond $!.backtrace[0..2]
      next nil
    end
    if script.class == ExecScript
      respond "--- Lich: error: Setting.load: exec scripts can't have settings"
      respond $!.backtrace[0..2]
      exit
    end
    if args.empty?
      respond '--- error: Setting.load: no setting specified'
      respond $!.backtrace[0..2]
      exit
    end
    if args.any? { |a| a.class != String }
      respond "--- Lich: error: Setting.load: non-string given as setting name"
      respond $!.backtrace[0..2]
      exit
    end
    values = Array.new
    for setting in args
      begin
        v = Lich.db.get_first_value('SELECT value FROM script_setting WHERE script=? AND name=?;', script.name.encode('UTF-8'), setting.encode('UTF-8'))
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
      if v.nil?
        values.push(v)
      else
        begin
          values.push(Marshal.load(v))
        rescue
          respond "--- Lich: error: Setting.load: #{$!}"
          respond $!.backtrace[0..2]
          exit
        end
      end
    end
    if args.length == 1
      next values[0]
    else
      next values
    end
  }
  @@save = proc { |hash|
    unless script = Script.current
      respond '--- error: Setting.save: calling script is unknown'
      respond $!.backtrace[0..2]
      next nil
    end
    if script.class == ExecScript
      respond "--- Lich: error: Setting.load: exec scripts can't have settings"
      respond $!.backtrace[0..2]
      exit
    end
    if hash.class != Hash
      respond "--- Lich: error: Setting.save: invalid arguments: use Setting.save('setting1' => 'value1', 'setting2' => 'value2')"
      respond $!.backtrace[0..2]
      exit
    end
    if hash.empty?
      next nil
    end

    if hash.keys.any? { |k| k.class != String }
      respond "--- Lich: error: Setting.save: non-string given as a setting name"
      respond $!.backtrace[0..2]
      exit
    end
    if hash.length > 1
      begin
        Lich.db.execute('BEGIN')
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
    end
    hash.each { |setting, value|
      begin
        if value.nil?
          begin
            Lich.db.execute('DELETE FROM script_setting WHERE script=? AND name=?;', script.name.encode('UTF-8'), setting.encode('UTF-8'))
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
        else
          v = SQLite3::Blob.new(Marshal.dump(value))
          begin
            Lich.db.execute('INSERT OR REPLACE INTO script_setting(script,name,value) VALUES(?,?,?);', script.name.encode('UTF-8'), setting.encode('UTF-8'), v)
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
        end
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
    }
    if hash.length > 1
      begin
        Lich.db.execute('END')
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
    end
    true
  }
  @@list = proc {
    unless script = Script.current
      respond '--- error: Setting: unknown calling script'
      next nil
    end
    if script.class == ExecScript
      respond "--- Lich: error: Setting.load: exec scripts can't have settings"
      respond $!.backtrace[0..2]
      exit
    end
    begin
      rows = Lich.db.execute('SELECT name FROM script_setting WHERE script=?;', script.name.encode('UTF-8'))
    rescue SQLite3::BusyException
      sleep 0.1
      retry
    end
    if rows
      # fixme
      next rows.inspect
    else
      next nil
    end
  }
  def Setting.load(*args)
    @@load.call(args)
  end

  def Setting.save(hash)
    @@save.call(hash)
  end

  def Setting.list
    @@list.call
  end
end

module GameSetting
  def GameSetting.load(*args)
    Setting.load(args.collect { |a| "#{XMLData.game}:#{a}" })
  end

  def GameSetting.save(hash)
    game_hash = Hash.new
    hash.each_pair { |k, v| game_hash["#{XMLData.game}:#{k}"] = v }
    Setting.save(game_hash)
  end
end

module CharSetting
  def CharSetting.load(*args)
    Setting.load(args.collect { |a| "#{XMLData.game}:#{XMLData.name}:#{a}" })
  end

  def CharSetting.save(hash)
    game_hash = Hash.new
    hash.each_pair { |k, v| game_hash["#{XMLData.game}:#{XMLData.name}:#{k}"] = v }
    Setting.save(game_hash)
  end
end

module Settings
  settings    = Hash.new
  md5_at_load = Hash.new
  mutex       = Mutex.new
  @@settings = proc { |scope|
    unless script = Script.current
      respond '--- error: Settings: unknown calling script'
      next nil
    end
    unless scope =~ /^#{XMLData.game}\:#{XMLData.name}$|^#{XMLData.game}$|^\:$/
      respond '--- error: Settings: invalid scope'
      next nil
    end
    mutex.synchronize {
      unless settings[script.name] and settings[script.name][scope]
        begin
          _hash = Lich.db.get_first_value('SELECT hash FROM script_auto_settings WHERE script=? AND scope=?;', script.name.encode('UTF-8'), scope.encode('UTF-8'))
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
        settings[script.name] ||= Hash.new
        if _hash.nil?
          settings[script.name][scope] = Hash.new
        else
          begin
            hash = Marshal.load(_hash)
          rescue
            respond "--- Lich: error: #{$!}"
            respond $!.backtrace[0..1]
            exit
          end
          settings[script.name][scope] = hash
        end
        md5_at_load[script.name] ||= Hash.new
        md5_at_load[script.name][scope] = Digest::MD5.hexdigest(settings[script.name][scope].to_s)
      end
    }
    settings[script.name][scope]
  }
  @@save = proc {
    mutex.synchronize {
      sql_began = false
      settings.each_pair { |script_name, scopedata|
        scopedata.each_pair { |scope, data|
          if Digest::MD5.hexdigest(data.to_s) != md5_at_load[script_name][scope]
            unless sql_began
              begin
                Lich.db.execute('BEGIN')
              rescue SQLite3::BusyException
                sleep 0.1
                retry
              end
              sql_began = true
            end
            blob = SQLite3::Blob.new(Marshal.dump(data))
            begin
              Lich.db.execute('INSERT OR REPLACE INTO script_auto_settings(script,scope,hash) VALUES(?,?,?);', script_name.encode('UTF-8'), scope.encode('UTF-8'), blob)
            rescue SQLite3::BusyException
              sleep 0.1
              retry
            rescue
              respond "--- Lich: error: #{$!}"
              respond $!.backtrace[0..1]
              next
            end
          end
        }
        unless Script.running?(script_name)
          settings.delete(script_name)
          md5_at_load.delete(script_name)
        end
      }
      if sql_began
        begin
          Lich.db.execute('END')
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
      end
    }
  }
  Thread.new {
    loop {
      sleep 300
      begin
        @@save.call
      rescue
        Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
      end
    }
  }
  def Settings.[](name)
    @@settings.call(':')[name]
  end

  def Settings.[]=(name, value)
    @@settings.call(':')[name] = value
  end

  def Settings.to_hash(scope = ':')
    @@settings.call(scope)
  end

  def Settings.char
    @@settings.call("#{XMLData.game}:#{XMLData.name}")
  end

  def Settings.save
    @@save.call
  end
end

module GameSettings
  def GameSettings.[](name)
    Settings.to_hash(XMLData.game)[name]
  end

  def GameSettings.[]=(name, value)
    Settings.to_hash(XMLData.game)[name] = value
  end

  def GameSettings.to_hash
    Settings.to_hash(XMLData.game)
  end
end

module CharSettings
  def CharSettings.[](name)
    Settings.to_hash("#{XMLData.game}:#{XMLData.name}")[name]
  end

  def CharSettings.[]=(name, value)
    Settings.to_hash("#{XMLData.game}:#{XMLData.name}")[name] = value
  end

  def CharSettings.to_hash
    Settings.to_hash("#{XMLData.game}:#{XMLData.name}")
  end
end

module Vars
  @@vars   = Hash.new
  md5      = nil
  mutex    = Mutex.new
  @@loaded = false
  @@load = proc {
    mutex.synchronize {
      unless @@loaded
        begin
          h = Lich.db.get_first_value('SELECT hash FROM uservars WHERE scope=?;', "#{XMLData.game}:#{XMLData.name}".encode('UTF-8'))
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
        if h
          begin
            hash = Marshal.load(h)
            hash.each { |k, v| @@vars[k] = v }
            md5 = Digest::MD5.hexdigest(hash.to_s)
          rescue
            respond "--- Lich: error: #{$!}"
            respond $!.backtrace[0..2]
          end
        end
        @@loaded = true
      end
    }
    nil
  }
  @@save = proc {
    mutex.synchronize {
      if @@loaded
        if Digest::MD5.hexdigest(@@vars.to_s) != md5
          md5 = Digest::MD5.hexdigest(@@vars.to_s)
          blob = SQLite3::Blob.new(Marshal.dump(@@vars))
          begin
            Lich.db.execute('INSERT OR REPLACE INTO uservars(scope,hash) VALUES(?,?);', "#{XMLData.game}:#{XMLData.name}".encode('UTF-8'), blob)
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
        end
      end
    }
    nil
  }
  Thread.new {
    loop {
      sleep 300
      begin
        @@save.call
      rescue
        Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
      end
    }
  }
  def Vars.[](name)
    @@load.call unless @@loaded
    @@vars[name]
  end

  def Vars.[]=(name, val)
    @@load.call unless @@loaded
    if val.nil?
      @@vars.delete(name)
    else
      @@vars[name] = val
    end
  end

  def Vars.list
    @@load.call unless @@loaded
    @@vars.dup
  end

  def Vars.save
    @@save.call
  end

  def Vars.method_missing(arg1, arg2 = '')
    @@load.call unless @@loaded
    if arg1[-1, 1] == '='
      if arg2.nil?
        @@vars.delete(arg1.to_s.chop)
      else
        @@vars[arg1.to_s.chop] = arg2
      end
    else
      @@vars[arg1.to_s]
    end
  end
end

# Script classes move to lib 230305
require_relative('./lib/script.rb')

class Watchfor
  def initialize(line, theproc = nil, &block)
    return nil unless script = Script.current

    if line.class == String
      line = Regexp.new(Regexp.escape(line))
    elsif line.class != Regexp
      echo 'watchfor: no string or regexp given'
      return nil
    end
    if block.nil?
      if theproc.respond_to? :call
        block = theproc
      else
        echo 'watchfor: no block or proc given'
        return nil
      end
    end
    script.watchfor[line] = block
  end

  def Watchfor.clear
    script.watchfor = Hash.new
  end
end

## adding util to the list of defs

require 'lib/util.rb'
require 'lib/messaging.rb'
require 'lib/global_defs.rb'

module Buffer
  DOWNSTREAM_STRIPPED = 1
  DOWNSTREAM_RAW      = 2
  DOWNSTREAM_MOD      = 4
  UPSTREAM            = 8
  UPSTREAM_MOD        = 16
  SCRIPT_OUTPUT       = 32
  @@index             = Hash.new
  @@streams           = Hash.new
  @@mutex             = Mutex.new
  @@offset            = 0
  @@buffer            = Array.new
  @@max_size          = 3000
  def Buffer.gets
    thread_id = Thread.current.object_id
    if @@index[thread_id].nil?
      @@mutex.synchronize {
        @@index[thread_id] = (@@offset + @@buffer.length)
        @@streams[thread_id] ||= DOWNSTREAM_STRIPPED
      }
    end
    line = nil
    loop {
      if (@@index[thread_id] - @@offset) >= @@buffer.length
        sleep 0.05 while ((@@index[thread_id] - @@offset) >= @@buffer.length)
      end
      @@mutex.synchronize {
        if @@index[thread_id] < @@offset
          @@index[thread_id] = @@offset
        end
        line = @@buffer[@@index[thread_id] - @@offset]
      }
      @@index[thread_id] += 1
      break if ((line.stream & @@streams[thread_id]) != 0)
    }
    return line
  end

  def Buffer.gets?
    thread_id = Thread.current.object_id
    if @@index[thread_id].nil?
      @@mutex.synchronize {
        @@index[thread_id] = (@@offset + @@buffer.length)
        @@streams[thread_id] ||= DOWNSTREAM_STRIPPED
      }
    end
    line = nil
    loop {
      if (@@index[thread_id] - @@offset) >= @@buffer.length
        return nil
      end

      @@mutex.synchronize {
        if @@index[thread_id] < @@offset
          @@index[thread_id] = @@offset
        end
        line = @@buffer[@@index[thread_id] - @@offset]
      }
      @@index[thread_id] += 1
      break if ((line.stream & @@streams[thread_id]) != 0)
    }
    return line
  end

  def Buffer.rewind
    thread_id = Thread.current.object_id
    @@index[thread_id] = @@offset
    @@streams[thread_id] ||= DOWNSTREAM_STRIPPED
    return self
  end

  def Buffer.clear
    thread_id = Thread.current.object_id
    if @@index[thread_id].nil?
      @@mutex.synchronize {
        @@index[thread_id] = (@@offset + @@buffer.length)
        @@streams[thread_id] ||= DOWNSTREAM_STRIPPED
      }
    end
    lines = Array.new
    loop {
      if (@@index[thread_id] - @@offset) >= @@buffer.length
        return lines
      end

      line = nil
      @@mutex.synchronize {
        if @@index[thread_id] < @@offset
          @@index[thread_id] = @@offset
        end
        line = @@buffer[@@index[thread_id] - @@offset]
      }
      @@index[thread_id] += 1
      lines.push(line) if ((line.stream & @@streams[thread_id]) != 0)
    }
    return lines
  end

  def Buffer.update(line, stream = nil)
    @@mutex.synchronize {
      frozen_line = line.dup
      unless stream.nil?
        frozen_line.stream = stream
      end
      frozen_line.freeze
      @@buffer.push(frozen_line)
      while (@@buffer.length > @@max_size)
        @@buffer.shift
        @@offset += 1
      end
    }
    return self
  end

  def Buffer.streams
    @@streams[Thread.current.object_id]
  end

  def Buffer.streams=(val)
    if (val.class != Integer) or ((val & 63) == 0)
      respond "--- Lich: error: invalid streams value\n\t#{$!.caller[0..2].join("\n\t")}"
      return nil
    end
    @@streams[Thread.current.object_id] = val
  end

  def Buffer.cleanup
    @@index.delete_if { |k, v| not Thread.list.any? { |t| t.object_id == k } }
    @@streams.delete_if { |k, v| not Thread.list.any? { |t| t.object_id == k } }
    return self
  end
end

class SharedBuffer
  attr_accessor :max_size

  def initialize(args = {})
    @buffer = Array.new
    @buffer_offset = 0
    @buffer_index = Hash.new
    @buffer_mutex = Mutex.new
    @max_size = args[:max_size] || 500
    return self
  end

  def gets
    thread_id = Thread.current.object_id
    if @buffer_index[thread_id].nil?
      @buffer_mutex.synchronize { @buffer_index[thread_id] = (@buffer_offset + @buffer.length) }
    end
    if (@buffer_index[thread_id] - @buffer_offset) >= @buffer.length
      sleep 0.05 while ((@buffer_index[thread_id] - @buffer_offset) >= @buffer.length)
    end
    line = nil
    @buffer_mutex.synchronize {
      if @buffer_index[thread_id] < @buffer_offset
        @buffer_index[thread_id] = @buffer_offset
      end
      line = @buffer[@buffer_index[thread_id] - @buffer_offset]
    }
    @buffer_index[thread_id] += 1
    return line
  end

  def gets?
    thread_id = Thread.current.object_id
    if @buffer_index[thread_id].nil?
      @buffer_mutex.synchronize { @buffer_index[thread_id] = (@buffer_offset + @buffer.length) }
    end
    if (@buffer_index[thread_id] - @buffer_offset) >= @buffer.length
      return nil
    end

    line = nil
    @buffer_mutex.synchronize {
      if @buffer_index[thread_id] < @buffer_offset
        @buffer_index[thread_id] = @buffer_offset
      end
      line = @buffer[@buffer_index[thread_id] - @buffer_offset]
    }
    @buffer_index[thread_id] += 1
    return line
  end

  def clear
    thread_id = Thread.current.object_id
    if @buffer_index[thread_id].nil?
      @buffer_mutex.synchronize { @buffer_index[thread_id] = (@buffer_offset + @buffer.length) }
      return Array.new
    end
    if (@buffer_index[thread_id] - @buffer_offset) >= @buffer.length
      return Array.new
    end

    lines = Array.new
    @buffer_mutex.synchronize {
      if @buffer_index[thread_id] < @buffer_offset
        @buffer_index[thread_id] = @buffer_offset
      end
      lines = @buffer[(@buffer_index[thread_id] - @buffer_offset)..-1]
      @buffer_index[thread_id] = (@buffer_offset + @buffer.length)
    }
    return lines
  end

  def rewind
    @buffer_index[Thread.current.object_id] = @buffer_offset
    return self
  end

  def update(line)
    @buffer_mutex.synchronize {
      fline = line.dup
      fline.freeze
      @buffer.push(fline)
      while (@buffer.length > @max_size)
        @buffer.shift
        @buffer_offset += 1
      end
    }
    return self
  end

  def cleanup_threads
    @buffer_index.delete_if { |k, v| not Thread.list.any? { |t| t.object_id == k } }
    return self
  end
end

class SpellRanks
  @@list      ||= Array.new
  @@timestamp ||= 0
  @@loaded    ||= false
  attr_reader :name
  attr_accessor :minorspiritual, :majorspiritual, :cleric, :minorelemental, :majorelemental, :minormental, :ranger, :sorcerer, :wizard, :bard, :empath, :paladin, :arcanesymbols, :magicitemuse, :monk

  def SpellRanks.load
    if File.exist?("#{DATA_DIR}/#{XMLData.game}/spell-ranks.dat")
      begin
        File.open("#{DATA_DIR}/#{XMLData.game}/spell-ranks.dat", 'rb') { |f|
          @@timestamp, @@list = Marshal.load(f.read)
        }
        # minor mental circle added 2012-07-18; old data files will have @minormental as nil
        @@list.each { |rank_info| rank_info.minormental ||= 0 }
        # monk circle added 2013-01-15; old data files will have @minormental as nil
        @@list.each { |rank_info| rank_info.monk ||= 0 }
        @@loaded = true
      rescue
        respond "--- Lich: error: SpellRanks.load: #{$!}"
        Lich.log "error: SpellRanks.load: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        @@list      = Array.new
        @@timestamp = 0
        @@loaded = true
      end
    else
      @@loaded = true
    end
  end

  def SpellRanks.save
    begin
      File.open("#{DATA_DIR}/#{XMLData.game}/spell-ranks.dat", 'wb') { |f|
        f.write(Marshal.dump([@@timestamp, @@list]))
      }
    rescue
      respond "--- Lich: error: SpellRanks.save: #{$!}"
      Lich.log "error: SpellRanks.save: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
    end
  end

  def SpellRanks.timestamp
    SpellRanks.load unless @@loaded
    @@timestamp
  end

  def SpellRanks.timestamp=(val)
    SpellRanks.load unless @@loaded
    @@timestamp = val
  end

  def SpellRanks.[](name)
    SpellRanks.load unless @@loaded
    @@list.find { |n| n.name == name }
  end

  def SpellRanks.list
    SpellRanks.load unless @@loaded
    @@list
  end

  def SpellRanks.method_missing(arg = nil)
    echo "error: unknown method #{arg} for class SpellRanks"
    respond caller[0..1]
  end

  def initialize(name)
    SpellRanks.load unless @@loaded
    @name = name
    @minorspiritual, @majorspiritual, @cleric, @minorelemental, @majorelemental, @ranger, @sorcerer, @wizard, @bard, @empath, @paladin, @minormental, @arcanesymbols, @magicitemuse = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    @@list.push(self)
  end
end

module Games
  module Unknown
    module Game
    end
  end
  module Gemstone
    module Game
      @@socket    = nil
      @@mutex     = Mutex.new
      @@last_recv = nil
      @@thread    = nil
      @@buffer    = SharedBuffer.new
      @@_buffer   = SharedBuffer.new
      @@_buffer.max_size = 1000
      @@autostarted = false
      @@cli_scripts = false
      def Game.open(host, port)
        @@socket = TCPSocket.open(host, port)
        begin
          @@socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
        rescue
          Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue Exception
          Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        end
        @@socket.sync = true

        # Add check to determine if the game server hung at initial response
        
        @@wrap_thread = Thread.new {
          @last_recv = Time.now
          while !@@autostarted && (Time.now - @last_recv < 6)
            break if @@autostarted
            sleep 0.2
          end

          puts 'look' if !@@autostarted
        }

        @@thread = Thread.new {
          begin
            atmospherics = false
            combat_count = 0
            end_combat_tags = [ "<prompt", "<clearStream", "<component", "<pushStream id=\"percWindow" ]
            while $_SERVERSTRING_ = @@socket.gets
              @@last_recv = Time.now
              @@_buffer.update($_SERVERSTRING_) if TESTING
              begin
                $cmd_prefix = String.new if $_SERVERSTRING_ =~ /^\034GSw/
                ## Clear out superfluous tags
                $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" /><popStream id=\"combat\" />","")
                $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<popStream id=\"combat\" /><pushStream id=\"combat\" />","")

                ## Fix combat wrapping components - Why, DR, Why?
                $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" /><component id=","<component id=")
                # $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" /><prompt ","<prompt ")

                ## Fix for nested/non-solo nav tags.
                ## DR needs the <nav/> tag to be in its own line to properly detect movement
                ## These two fixes make it so room movement can be detected reliably
                if $_SERVERSTRING_ =~ /^<nav\/>/
                  unless $_SERVERSTRING_.chomp == "<nav\/>"
                    Lich.log "NAV tag detected in nested line: #{$_SERVERSTRING_.inspect}"
                    $_SERVERSTRING_.gsub!("<nav\/>", "<nav\/>\n").chomp!
                    Lich.log "NAV tag fixed to: #{$_SERVERSTRING_.inspect}"
                  end
                end

                if $_SERVERSTRING_ =~ /(?!^)<nav\/>/
                  Lich.log "NAV tag detected not at start of line: #{$_SERVERSTRING_.inspect}"
                  $_SERVERSTRING_.gsub!("<nav\/>", "\n<nav\/>").chomp!
                  Lich.log "NAV tag fixed to: #{$_SERVERSTRING_.inspect}"
                end

                # Fixes xml with \r\n in the middle of it like:
                # <component id='room exits'>Obvious paths: clockwise, widdershins.\r\n
                # <compass></compass></component>\r\n
                # We close the first line and in the next segment, we remove the trailing bits
                # Because we can only match line by line, this couldn't be fixed in one matching block...
                if $_SERVERSTRING_ == "<component id='room exits'>Obvious paths: clockwise, widdershins.\r\n"
                  Lich.log "Unclosed component tag detected: #{$_SERVERSTRING_.inspect}"
                  $_SERVERSTRING_ = "<component id='room exits'>Obvious paths: <d>clockwise</d>, <d>widdershins</d>.<compass></compass></component>"
                  Lich.log "Unclosed component tag fixed to: #{$_SERVERSTRING_.inspect}"
                  # retry
                end
                # This is an actual DR line "<compass></compass></component>\r\n" which happens when the above is sent... subbing it out since we fix the tag above.
                if $_SERVERSTRING_ == "<compass></compass></component>\r\n"
                  Lich.log "Extraneous closed tag detected: #{$_SERVERSTRING_.inspect}"
                  $_SERVERSTRING_ = ""
                  Lich.log "Extraneous closed tag fixed: #{$_SERVERSTRING_.inspect}"
                end

                # "<component id='room objs'>  You also see a granite altar with several candles and a water jug on it, and a granite font.\r\n"
                # "<component id='room extra'>Placed around the interior, you see: some furniture and other bits of interest.\r\n
                # Followed by in a new line.
                # "</component>\r\n"
                if $_SERVERSTRING_ =~ /^<component id='room (?:objs|extra)'>[^<]*(?!<\/component>)\r\n/
                  Lich.log "Open-ended room objects component id tag: #{$_SERVERSTRING_.inspect}"
                  $_SERVERSTRING_.gsub!("\r\n", "</component>")
                  Lich.log "Open-ended room objects component id tag fixed to: #{$_SERVERSTRING_.inspect}"
                end
                # "</component>\r\n"
                if $_SERVERSTRING_ == "</component>\r\n"
                  Lich.log "Extraneous closing tag detected and deleted: #{$_SERVERSTRING_.inspect}"
                  $_SERVERSTRING_ = ""
                end

                ## Fix duplicate pushStrings
                while $_SERVERSTRING_.include?("<pushStream id=\"combat\" /><pushStream id=\"combat\" />")
                  $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" /><pushStream id=\"combat\" />","<pushStream id=\"combat\" />")
                end

                if combat_count >0
                  end_combat_tags.each do | tag |
                    # $_SERVERSTRING_ = "<!-- looking for tag: #{tag}" + $_SERVERSTRING_
                    if $_SERVERSTRING_.include?(tag)
                      $_SERVERSTRING_ = $_SERVERSTRING_.gsub(tag,"<popStream id=\"combat\" />" + tag) unless $_SERVERSTRING_.include?("<popStream id=\"combat\" />")
                      combat_count -= 1
                    end
                    if $_SERVERSTRING_.include?("<pushStream id=\"combat\" />")
                      $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" />","")
                    end
                  end
                end

                combat_count += $_SERVERSTRING_.scan("<pushStream id=\"combat\" />").length
                combat_count -= $_SERVERSTRING_.scan("<popStream id=\"combat\" />").length
                combat_count = 0 if combat_count < 0
                # The Rift, Scatter is broken...
                if $_SERVERSTRING_ =~ /<compDef id='room text'><\/compDef>/
                  $_SERVERSTRING_.sub!(/(.*)\s\s<compDef id='room text'><\/compDef>/) { "<compDef id='room desc'>#{$1}</compDef>" }
                end
                if atmospherics
                  atmospherics = false
                  $_SERVERSTRING.prepend('<popStream id="atmospherics" \/>') unless $_SERVERSTRING =~ /<popStream id="atmospherics" \/>/
                end
                if $_SERVERSTRING_ =~ /<pushStream id="familiar" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # Cry For Help spell is broken...
                  $_SERVERSTRING_.sub!('<pushStream id="familiar" />', '')
                elsif $_SERVERSTRING_ =~ /<pushStream id="atmospherics" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # pet pigs in DragonRealms are broken...
                  $_SERVERSTRING_.sub!('<pushStream id="atmospherics" />', '')
                elsif ($_SERVERSTRING_ =~ /<pushStream id="atmospherics" \/>/)
                  atmospherics = true
                end
                $_SERVERBUFFER_.push($_SERVERSTRING_)

                if !@@autostarted and $_SERVERSTRING_ =~ /<app char/
                  require 'lib/game-loader'
                  GameLoader.load!
                  Script.start('autostart') if Script.exists?('autostart')
                  @@autostarted = true
                end

                if @@autostarted and $_SERVERSTRING_ =~ /roomDesc/ and !@@cli_scripts
                  if arg = ARGV.find { |a| a =~ /^\-\-start\-scripts=/ }
                    for script_name in arg.sub('--start-scripts=', '').split(',')
                      Script.start(script_name)
                    end
                  end
                  @@cli_scripts = true
                end

                if alt_string = DownstreamHook.run($_SERVERSTRING_)
                  #                           Buffer.update(alt_string, Buffer::DOWNSTREAM_MOD)
                  if (Lich.display_lichid == true or Lich.display_uid == true) and XMLData.game =~ /^GS/ and alt_string =~ /<resource picture=.*roomName/
                    if (Lich.display_lichid == true and Lich.display_uid == true)
                      alt_string.sub!(']') {" - #{Map.current.id}] (u#{XMLData.room_id})"}
                    elsif Lich.display_lichid == true
                      alt_string.sub!(']') {" - #{Map.current.id}]"}
                    elsif Lich.display_uid == true
                      alt_string.sub!(']') {"] (u#{XMLData.room_id})"}
                      end
                    end
                  if $frontend =~ /^(?:wizard|avalon)$/
                    alt_string = sf_to_wiz(alt_string)
                  end
                  if $_DETACHABLE_CLIENT_
                    begin
                      $_DETACHABLE_CLIENT_.write(alt_string)
                    rescue
                      $_DETACHABLE_CLIENT_.close rescue nil
                      $_DETACHABLE_CLIENT_ = nil
                      respond "--- Lich: error: client_thread: #{$!}"
                      respond $!.backtrace.first
                      Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                    end
                  else
                    $_CLIENT_.write(alt_string)
                  end
                end
                unless $_SERVERSTRING_ =~ /^<settings /
                  # Fixed invalid xml such as:
                  # <mode id="GAME"/><settingsInfo  space not found crc='0' instance='DR'/>
                  # <settingsInfo  space not found crc='0' instance='DR'/>
                  if $_SERVERSTRING_ =~ /<settingsInfo .*?space not found /
                    Lich.log "Invalid settingsInfo XML tags detected: #{$_SERVERSTRING_.inspect}"
                    $_SERVERSTRING_.sub!('space not found', '')
                    Lich.log "Invalid settingsInfo XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                  end
                  begin
                    pp $_SERVERSTRING_ if $deep_debug
                    REXML::Document.parse_stream($_SERVERSTRING_, XMLData)
                    # XMLData.parse($_SERVERSTRING_)
                  rescue
                    unless $!.to_s =~ /invalid byte sequence/
                      # Fixes invalid XML with nested single quotes in it such as:
                      # From DR intro tips
                      # <link id='2' value='Ever wondered about the time you've spent in Elanthia?  Check the PLAYED verb!' cmd='played' echo='played' />
                      # From GS
                      # <d cmd='forage Imaera's Lace'>Imaera's Lace</d>, <d cmd='forage stalk burdock'>stalk of burdock</d>
                      while data = $_SERVERSTRING_.match(/'([^=>]*'[^=>]*)'/)
                        Lich.log "Invalid nested single quotes XML tags detected: #{$_SERVERSTRING_.inspect}"
                        $_SERVERSTRING_.gsub!(data[1], data[1].gsub!(/'/, '&apos;'))
                        Lich.log "Invalid nested single quotes XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                        retry
                      end
                      # Fixes invalid XML with nested double quotes in it such as:
                      # <subtitle=" - [Avlea's Bows, "The Straight and Arrow"]">
                      while data = $_SERVERSTRING_.match(/"([^=]*"[^=]*)"/)
                        Lich.log "Invalid nested double quotes XML tags detected: #{$_SERVERSTRING_.inspect}"
                        $_SERVERSTRING_.gsub!(data[1], data[1].gsub!(/"/, '&quot;'))
                        Lich.log "Invalid nested double quotes XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                        retry
                      end
                      $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                      Lich.log "Invalid XML detected - please report this: #{$_SERVERSTRING_.inspect}"
                      Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                    end
                    XMLData.reset
                  end
                  Script.new_downstream_xml($_SERVERSTRING_)
                  stripped_server = strip_xml($_SERVERSTRING_)
                  stripped_server.split("\r\n").each { |line|
                    @@buffer.update(line) if TESTING
                    if defined?(Map) and Map.method_defined?(:last_seen_objects) and !Map.last_seen_objects and line =~ /(You also see .*)$/
                      Map.last_seen_objects = $1  # DR only: copy loot line to Map.last_seen_objects
                    end
                    unless line =~ /^\s\*\s[A-Z][a-z]+ (?:returns home from a hard day of adventuring\.|joins the adventure\.|(?:is off to a rough start!  (?:H|She) )?just bit the dust!|was just incinerated!|was just vaporized!|has been vaporized!|has disconnected\.)$|^ \* The death cry of [A-Z][a-z]+ echoes in your mind!$|^\r*\n*$/
                      unless line.empty?
                        Infomon::Parser.parse(line.dup)
                        Script.new_downstream(line)
                      end
                    end
                  }
                end
              rescue
                $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              end
            end
          rescue Exception
            Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.slice(0..10).join("\n\t")}"
            sleep 0.2
            retry unless $_CLIENT_.closed? or @@socket.closed? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed|An established connection was aborted by the software in your host machine./i)
          rescue
            Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace..slice(0..10).join("\n\t")}"
            sleep 0.2
            retry unless $_CLIENT_.closed? or @@socket.closed? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed|An established connection was aborted by the software in your host machine./i)
          end
        }
        @@thread.priority = 4
        $_SERVER_ = @@socket # deprecated
      end

      def Game.thread
        @@thread
      end

      def Game.closed?
        if @@socket.nil?
          true
        else
          @@socket.closed?
        end
      end

      def Game.close
        if @@socket
          @@socket.close rescue nil
          @@thread.kill rescue nil
        end
      end

      def Game._puts(str)
        @@mutex.synchronize {
          @@socket.puts(str)
        }
      end

      def Game.puts(str)
        $_SCRIPTIDLETIMESTAMP_ = Time.now
        if script = Script.current
          script_name = script.name
        else
          script_name = '(unknown script)'
        end
        $_CLIENTBUFFER_.push "[#{script_name}]#{$SEND_CHARACTER}#{$cmd_prefix}#{str}\r\n"
        if script.nil? or not script.silent
          respond "[#{script_name}]#{$SEND_CHARACTER}#{str}\r\n"
        end
        Game._puts "#{$cmd_prefix}#{str}"
        $_LASTUPSTREAM_ = "[#{script_name}]#{$SEND_CHARACTER}#{str}"
      end

      def Game.gets
        @@buffer.gets
      end

      def Game.buffer
        @@buffer
      end

      def Game._gets
        @@_buffer.gets
      end

      def Game._buffer
        @@_buffer
      end
    end
    class Char
      @@name ||= nil
      @@citizenship ||= nil
      private_class_method :new
      def Char.init(blah)
        echo 'Char.init is no longer used.  Update or fix your script.'
      end

      def Char.name
        XMLData.name
      end

      def Char.name=(name)
        nil
      end

      def Char.health(*args)
        health(*args)
      end

      def Char.mana(*args)
        checkmana(*args)
      end

      def Char.spirit(*args)
        checkspirit(*args)
      end

      def Char.maxhealth
        Object.module_eval { maxhealth }
      end

      def Char.maxmana
        Object.module_eval { maxmana }
      end

      def Char.maxspirit
        Object.module_eval { maxspirit }
      end

      def Char.stamina(*args)
        checkstamina(*args)
      end

      def Char.maxstamina
        Object.module_eval { maxstamina }
      end

      def Char.cha(val = nil)
        nil
      end

      def Char.dump_info
        Marshal.dump([
                       Spell.detailed?,
                       Spell.serialize,
                       Spellsong.serialize,
                       Stats.serialize,
                       Skills.serialize,
                       Spells.serialize,
                       Gift.serialize,
                       Society.serialize,
                     ])
      end

      def Char.load_info(string)
        save = Char.dump_info
        begin
          Spell.load_detailed,
            Spell.load_active,
            Spellsong.load_serialized,
            Stats.load_serialized,
            Skills.load_serialized,
            Spells.load_serialized,
            Gift.load_serialized,
            Society.load_serialized = Marshal.load(string)
        rescue
          raise $! if string == save

          string = save
          retry
        end
      end

      def Char.method_missing(meth, *args)
        [Stats, Skills, Spellsong, Society].each { |klass|
          begin
            result = klass.__send__(meth, *args)
            return result
          rescue
          end
        }
        respond 'missing method: ' + meth
        raise NoMethodError
      end

      def Char.info
        ary = []
        ary.push sprintf("Name: %s  Race: %s  Profession: %s", XMLData.name, Stats.race, Stats.prof)
        ary.push sprintf("Gender: %s    Age: %d    Expr: %d    Level: %d", Stats.gender, Stats.age, Stats.exp, Stats.level)
        ary.push sprintf("%017.17s Normal (Bonus)  ...  Enhanced (Bonus)", "")
        %w[Strength Constitution Dexterity Agility Discipline Aura Logic Intuition Wisdom Influence].each { |stat|
          val, bon = Stats.send(stat[0..2].downcase)
          enh_val, enh_bon = Stats.send("enhanced_#{stat[0..2].downcase}")
          spc = " " * (4 - bon.to_s.length)
          ary.push sprintf("%012s (%s): %05s (%d) %s ... %05s (%d)", stat, stat[0..2].upcase, val, bon, spc, enh_val, enh_bon)
        }
        ary.push sprintf("Mana: %04s", mana)
        ary
      end

      def Char.skills
        ary = []
        ary.push sprintf("%s (at level %d), your current skill bonuses and ranks (including all modifiers) are:", XMLData.name, Stats.level)
        ary.push sprintf("  %-035s| Current Current", 'Skill Name')
        ary.push sprintf("  %-035s|%08s%08s", '', 'Bonus', 'Ranks')
        fmt = [['Two Weapon Combat', 'Armor Use', 'Shield Use', 'Combat Maneuvers', 'Edged Weapons', 'Blunt Weapons', 'Two-Handed Weapons', 'Ranged Weapons', 'Thrown Weapons', 'Polearm Weapons', 'Brawling', 'Ambush', 'Multi Opponent Combat', 'Combat Leadership', 'Physical Fitness', 'Dodging', 'Arcane Symbols', 'Magic Item Use', 'Spell Aiming', 'Harness Power', 'Elemental Mana Control', 'Mental Mana Control', 'Spirit Mana Control', 'Elemental Lore - Air', 'Elemental Lore - Earth', 'Elemental Lore - Fire', 'Elemental Lore - Water', 'Spiritual Lore - Blessings', 'Spiritual Lore - Religion', 'Spiritual Lore - Summoning', 'Sorcerous Lore - Demonology', 'Sorcerous Lore - Necromancy', 'Mental Lore - Divination', 'Mental Lore - Manipulation', 'Mental Lore - Telepathy', 'Mental Lore - Transference', 'Mental Lore - Transformation', 'Survival', 'Disarming Traps', 'Picking Locks', 'Stalking and Hiding', 'Perception', 'Climbing', 'Swimming', 'First Aid', 'Trading', 'Pickpocketing'], ['twoweaponcombat', 'armoruse', 'shielduse', 'combatmaneuvers', 'edgedweapons', 'bluntweapons', 'twohandedweapons', 'rangedweapons', 'thrownweapons', 'polearmweapons', 'brawling', 'ambush', 'multiopponentcombat', 'combatleadership', 'physicalfitness', 'dodging', 'arcanesymbols', 'magicitemuse', 'spellaiming', 'harnesspower', 'emc', 'mmc', 'smc', 'elair', 'elearth', 'elfire', 'elwater', 'slblessings', 'slreligion', 'slsummoning', 'sldemonology', 'slnecromancy', 'mldivination', 'mlmanipulation', 'mltelepathy', 'mltransference', 'mltransformation', 'survival', 'disarmingtraps', 'pickinglocks', 'stalkingandhiding', 'perception', 'climbing', 'swimming', 'firstaid', 'trading', 'pickpocketing']]
        0.upto(fmt.first.length - 1) { |n|
          dots = '.' * (35 - fmt[0][n].length)
          rnk = Skills.send(fmt[1][n])
          ary.push sprintf("  %s%s|%08s%08s", fmt[0][n], dots, Skills.to_bonus(rnk), rnk) unless rnk.zero?
        }
        %[Minor Elemental,Major Elemental,Minor Spirit,Major Spirit,Minor Mental,Bard,Cleric,Empath,Paladin,Ranger,Sorcerer,Wizard].split(',').each { |circ|
          rnk = Spells.send(circ.gsub(" ", '').downcase)
          if rnk.nonzero?
            ary.push ''
            ary.push "Spell Lists"
            dots = '.' * (35 - circ.length)
            ary.push sprintf("  %s%s|%016s", circ, dots, rnk)
          end
        }
        ary
      end

      def Char.citizenship
        @@citizenship
      end

      def Char.citizenship=(val)
        @@citizenship = val.to_s
      end
    end

    class Society
      @@status ||= String.new
      @@rank ||= 0
      def Society.serialize
        [@@status, @@rank]
      end

      def Society.load_serialized=(val)
        @@status, @@rank = val
      end

      def Society.status=(val)
        @@status = val
      end

      def Society.status
        @@status.dup
      end

      def Society.rank=(val)
        if val =~ /Master/
          if @@status =~ /Voln/
            @@rank = 26
          elsif @@status =~ /Council of Light|Guardians of Sunfist/
            @@rank = 20
          else
            @@rank = val.to_i
          end
        else
          @@rank = val.slice(/[0-9]+/).to_i
        end
      end

      def Society.step
        @@rank
      end

      def Society.member
        @@status.dup
      end

      def Society.rank
        @@rank
      end

      def Society.task
        XMLData.society_task
      end
    end

    class Spellsong
      @@renewed ||= Time.at(Time.now.to_i - 1200)
      def Spellsong.renewed
        @@renewed = Time.now
      end

      def Spellsong.renewed=(val)
        @@renewed = val
      end

      def Spellsong.renewed_at
        @@renewed
      end

      def Spellsong.timeleft
        (Spellsong.duration - ((Time.now - @@renewed) % Spellsong.duration)) / 60.to_f
      end

      def Spellsong.serialize
        Spellsong.timeleft
      end

      def Spellsong.load_serialized=(old)
        Thread.new {
          n = 0
          while Stats.level == 0
            sleep 0.25
            n += 1
            break if n >= 4
          end
          unless n >= 4
            @@renewed = Time.at(Time.now.to_f - (Spellsong.duration - old * 60.to_f))
          else
            @@renewed = Time.now
          end
        }
        nil
      end

      def Spellsong.duration
        total = 120
        1.upto(Stats.level.to_i) { |n|
          if n < 26
            total += 4
          elsif n < 51
            total += 3
          elsif n < 76
            total += 2
          else
            total += 1
          end
        }
        total + Stats.log[1].to_i + (Stats.inf[1].to_i * 3) + (Skills.mltelepathy.to_i * 2)
      end

      def Spellsong.renew_cost
        # fixme: multi-spell penalty?
        total = num_active = 0
        [1003, 1006, 1009, 1010, 1012, 1014, 1018, 1019, 1025].each { |song_num|
          if song = Spell[song_num]
            if song.active?
              total += song.renew_cost
              num_active += 1
            end
          else
            echo "Spellsong.renew_cost: warning: can't find song number #{song_num}"
          end
        }
        return total
      end

      def Spellsong.sonicarmordurability
        210 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
      end

      def Spellsong.sonicbladedurability
        160 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
      end

      def Spellsong.sonicweapondurability
        Spellsong.sonicbladedurability
      end

      def Spellsong.sonicshielddurability
        125 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
      end

      def Spellsong.tonishastebonus
        bonus = -1
        thresholds = [30, 75]
        thresholds.each { |val| if Skills.elair >= val then bonus -= 1 end }
        bonus
      end

      def Spellsong.depressionpushdown
        20 + Skills.mltelepathy
      end

      def Spellsong.depressionslow
        thresholds = [10, 25, 45, 70, 100]
        bonus = -2
        thresholds.each { |val| if Skills.mltelepathy >= val then bonus -= 1 end }
        bonus
      end

      def Spellsong.holdingtargets
        1 + ((Spells.bard - 1) / 7).truncate
      end
      
      def Spellsong.cost
        Spellsong.renew_cost
      end

      def Spellsong.tonisdodgebonus
        thresholds = [1, 2, 3, 5, 8, 10, 14, 17, 21, 26, 31, 36, 42, 49, 55, 63, 70, 78, 87, 96]
        bonus = 20
        thresholds.each { |val| if Skills.elair >= val then bonus += 1 end }
        bonus
      end

      def Spellsong.mirrorsdodgebonus
        20 + ((Spells.bard - 19) / 2).round
      end

      def Spellsong.mirrorscost
        [19 + ((Spells.bard - 19) / 5).truncate, 8 + ((Spells.bard - 19) / 10).truncate]
      end

      def Spellsong.sonicbonus
        (Spells.bard / 2).round
      end

      def Spellsong.sonicarmorbonus
        Spellsong.sonicbonus + 15
      end

      def Spellsong.sonicbladebonus
        Spellsong.sonicbonus + 10
      end

      def Spellsong.sonicweaponbonus
        Spellsong.sonicbladebonus
      end

      def Spellsong.sonicshieldbonus
        Spellsong.sonicbonus + 10
      end

      def Spellsong.valorbonus
        10 + (([Spells.bard, Stats.level].min - 10) / 2).round
      end

      def Spellsong.valorcost
        [10 + (Spellsong.valorbonus / 2), 3 + (Spellsong.valorbonus / 5)]
      end

      def Spellsong.luckcost
        [6 + ((Spells.bard - 6) / 4), (6 + ((Spells.bard - 6) / 4) / 2).round]
      end

      def Spellsong.manacost
        [18, 15]
      end

      def Spellsong.fortcost
        [3, 1]
      end

      def Spellsong.shieldcost
        [9, 4]
      end

      def Spellsong.weaponcost
        [12, 4]
      end

      def Spellsong.armorcost
        [14, 5]
      end

      def Spellsong.swordcost
        [25, 15]
      end
    end

    class Skills
      @@twoweaponcombat ||= 0
      @@armoruse ||= 0
      @@shielduse ||= 0
      @@combatmaneuvers ||= 0
      @@edgedweapons ||= 0
      @@bluntweapons ||= 0
      @@twohandedweapons ||= 0
      @@rangedweapons ||= 0
      @@thrownweapons ||= 0
      @@polearmweapons ||= 0
      @@brawling ||= 0
      @@ambush ||= 0
      @@multiopponentcombat ||= 0
      @@combatleadership ||= 0
      @@physicalfitness ||= 0
      @@dodging ||= 0
      @@arcanesymbols ||= 0
      @@magicitemuse ||= 0
      @@spellaiming ||= 0
      @@harnesspower ||= 0
      @@emc ||= 0
      @@mmc ||= 0
      @@smc ||= 0
      @@elair ||= 0
      @@elearth ||= 0
      @@elfire ||= 0
      @@elwater ||= 0
      @@slblessings ||= 0
      @@slreligion ||= 0
      @@slsummoning ||= 0
      @@sldemonology ||= 0
      @@slnecromancy ||= 0
      @@mldivination ||= 0
      @@mlmanipulation ||= 0
      @@mltelepathy ||= 0
      @@mltransference ||= 0
      @@mltransformation ||= 0
      @@survival ||= 0
      @@disarmingtraps ||= 0
      @@pickinglocks ||= 0
      @@stalkingandhiding ||= 0
      @@perception ||= 0
      @@climbing ||= 0
      @@swimming ||= 0
      @@firstaid ||= 0
      @@trading ||= 0
      @@pickpocketing ||= 0

      def Skills.twoweaponcombat;           @@twoweaponcombat; end

      def Skills.twoweaponcombat=(val);     @@twoweaponcombat = val; end

      def Skills.armoruse;                  @@armoruse; end

      def Skills.armoruse=(val);            @@armoruse = val; end

      def Skills.shielduse;                 @@shielduse; end

      def Skills.shielduse=(val);           @@shielduse = val; end

      def Skills.combatmaneuvers;           @@combatmaneuvers; end

      def Skills.combatmaneuvers=(val);     @@combatmaneuvers = val; end

      def Skills.edgedweapons;              @@edgedweapons; end

      def Skills.edgedweapons=(val);        @@edgedweapons = val; end

      def Skills.bluntweapons;              @@bluntweapons; end

      def Skills.bluntweapons=(val);        @@bluntweapons = val; end

      def Skills.twohandedweapons;          @@twohandedweapons; end

      def Skills.twohandedweapons=(val);    @@twohandedweapons = val; end

      def Skills.rangedweapons;             @@rangedweapons; end

      def Skills.rangedweapons=(val);       @@rangedweapons = val; end

      def Skills.thrownweapons;             @@thrownweapons; end

      def Skills.thrownweapons=(val);       @@thrownweapons = val; end

      def Skills.polearmweapons;            @@polearmweapons; end

      def Skills.polearmweapons=(val);      @@polearmweapons = val; end

      def Skills.brawling;                  @@brawling; end

      def Skills.brawling=(val);            @@brawling = val; end

      def Skills.ambush;                    @@ambush; end

      def Skills.ambush=(val);              @@ambush = val; end

      def Skills.multiopponentcombat;       @@multiopponentcombat; end

      def Skills.multiopponentcombat=(val); @@multiopponentcombat = val; end

      def Skills.combatleadership;          @@combatleadership; end

      def Skills.combatleadership=(val);    @@combatleadership = val; end

      def Skills.physicalfitness;           @@physicalfitness; end

      def Skills.physicalfitness=(val);     @@physicalfitness = val; end

      def Skills.dodging;                   @@dodging; end

      def Skills.dodging=(val);             @@dodging = val; end

      def Skills.arcanesymbols;             @@arcanesymbols; end

      def Skills.arcanesymbols=(val);       @@arcanesymbols = val; end

      def Skills.magicitemuse;              @@magicitemuse; end

      def Skills.magicitemuse=(val);        @@magicitemuse = val; end

      def Skills.spellaiming;               @@spellaiming; end

      def Skills.spellaiming=(val);         @@spellaiming = val; end

      def Skills.harnesspower;              @@harnesspower; end

      def Skills.harnesspower=(val);        @@harnesspower = val; end

      def Skills.emc;                       @@emc; end

      def Skills.emc=(val);                 @@emc = val; end

      def Skills.mmc;                       @@mmc; end

      def Skills.mmc=(val);                 @@mmc = val; end

      def Skills.smc;                       @@smc; end

      def Skills.smc=(val);                 @@smc = val; end

      def Skills.elair;                     @@elair; end

      def Skills.elair=(val);               @@elair = val; end

      def Skills.elearth;                   @@elearth; end

      def Skills.elearth=(val);             @@elearth = val; end

      def Skills.elfire;                    @@elfire; end

      def Skills.elfire=(val);              @@elfire = val; end

      def Skills.elwater;                   @@elwater; end

      def Skills.elwater=(val);             @@elwater = val; end

      def Skills.slblessings;               @@slblessings; end

      def Skills.slblessings=(val);         @@slblessings = val; end

      def Skills.slreligion;                @@slreligion; end

      def Skills.slreligion=(val);          @@slreligion = val; end

      def Skills.slsummoning;               @@slsummoning; end

      def Skills.slsummoning=(val);         @@slsummoning = val; end

      def Skills.sldemonology;              @@sldemonology; end

      def Skills.sldemonology=(val);        @@sldemonology = val; end

      def Skills.slnecromancy;              @@slnecromancy; end

      def Skills.slnecromancy=(val);        @@slnecromancy = val; end

      def Skills.mldivination;              @@mldivination; end

      def Skills.mldivination=(val);        @@mldivination = val; end

      def Skills.mlmanipulation;            @@mlmanipulation; end

      def Skills.mlmanipulation=(val);      @@mlmanipulation = val; end

      def Skills.mltelepathy;               @@mltelepathy; end

      def Skills.mltelepathy=(val);         @@mltelepathy = val; end

      def Skills.mltransference;            @@mltransference; end

      def Skills.mltransference=(val);      @@mltransference = val; end

      def Skills.mltransformation;          @@mltransformation; end

      def Skills.mltransformation=(val);    @@mltransformation = val; end

      def Skills.survival;                  @@survival; end

      def Skills.survival=(val);            @@survival = val; end

      def Skills.disarmingtraps;            @@disarmingtraps; end

      def Skills.disarmingtraps=(val);      @@disarmingtraps = val; end

      def Skills.pickinglocks;              @@pickinglocks; end

      def Skills.pickinglocks=(val);        @@pickinglocks = val; end

      def Skills.stalkingandhiding;         @@stalkingandhiding; end

      def Skills.stalkingandhiding=(val);   @@stalkingandhiding = val; end

      def Skills.perception;                @@perception; end

      def Skills.perception=(val);          @@perception = val; end

      def Skills.climbing;                  @@climbing; end

      def Skills.climbing=(val);            @@climbing = val; end

      def Skills.swimming;                  @@swimming; end

      def Skills.swimming=(val);            @@swimming = val; end

      def Skills.firstaid;                  @@firstaid; end

      def Skills.firstaid=(val);            @@firstaid = val; end

      def Skills.trading;                   @@trading; end

      def Skills.trading=(val);             @@trading = val; end

      def Skills.pickpocketing;             @@pickpocketing; end

      def Skills.pickpocketing=(val);       @@pickpocketing = val; end

      def Skills.serialize
        [@@twoweaponcombat, @@armoruse, @@shielduse, @@combatmaneuvers, @@edgedweapons, @@bluntweapons, @@twohandedweapons, @@rangedweapons, @@thrownweapons, @@polearmweapons, @@brawling, @@ambush, @@multiopponentcombat, @@combatleadership, @@physicalfitness, @@dodging, @@arcanesymbols, @@magicitemuse, @@spellaiming, @@harnesspower, @@emc, @@mmc, @@smc, @@elair, @@elearth, @@elfire, @@elwater, @@slblessings, @@slreligion, @@slsummoning, @@sldemonology, @@slnecromancy, @@mldivination, @@mlmanipulation, @@mltelepathy, @@mltransference, @@mltransformation, @@survival, @@disarmingtraps, @@pickinglocks, @@stalkingandhiding, @@perception, @@climbing, @@swimming, @@firstaid, @@trading, @@pickpocketing]
      end

      def Skills.load_serialized=(array)
        @@twoweaponcombat, @@armoruse, @@shielduse, @@combatmaneuvers, @@edgedweapons, @@bluntweapons, @@twohandedweapons, @@rangedweapons, @@thrownweapons, @@polearmweapons, @@brawling, @@ambush, @@multiopponentcombat, @@combatleadership, @@physicalfitness, @@dodging, @@arcanesymbols, @@magicitemuse, @@spellaiming, @@harnesspower, @@emc, @@mmc, @@smc, @@elair, @@elearth, @@elfire, @@elwater, @@slblessings, @@slreligion, @@slsummoning, @@sldemonology, @@slnecromancy, @@mldivination, @@mlmanipulation, @@mltelepathy, @@mltransference, @@mltransformation, @@survival, @@disarmingtraps, @@pickinglocks, @@stalkingandhiding, @@perception, @@climbing, @@swimming, @@firstaid, @@trading, @@pickpocketing = array
      end

      def Skills.to_bonus(ranks)
        bonus = 0
        while ranks > 0
          if ranks > 40
            bonus += (ranks - 40)
            ranks = 40
          elsif ranks > 30
            bonus += (ranks - 30) * 2
            ranks = 30
          elsif ranks > 20
            bonus += (ranks - 20) * 3
            ranks = 20
          elsif ranks > 10
            bonus += (ranks - 10) * 4
            ranks = 10
          else
            bonus += (ranks * 5)
            ranks = 0
          end
        end
        bonus
      end
    end

    class Spells
      @@minorelemental ||= 0
      @@minormental    ||= 0
      @@majorelemental ||= 0
      @@minorspiritual ||= 0
      @@majorspiritual ||= 0
      @@wizard         ||= 0
      @@sorcerer       ||= 0
      @@ranger         ||= 0
      @@paladin        ||= 0
      @@empath         ||= 0
      @@cleric         ||= 0
      @@bard           ||= 0
      def Spells.minorelemental=(val); @@minorelemental = val; end

      def Spells.minorelemental;       @@minorelemental;       end

      def Spells.minormental=(val);    @@minormental = val;    end

      def Spells.minormental;          @@minormental;          end

      def Spells.majorelemental=(val); @@majorelemental = val; end

      def Spells.majorelemental;       @@majorelemental;       end

      def Spells.minorspiritual=(val); @@minorspiritual = val; end

      def Spells.minorspiritual;       @@minorspiritual;       end

      def Spells.minorspirit=(val);    @@minorspiritual = val; end

      def Spells.minorspirit;          @@minorspiritual;       end

      def Spells.majorspiritual=(val); @@majorspiritual = val; end

      def Spells.majorspiritual;       @@majorspiritual;       end

      def Spells.majorspirit=(val);    @@majorspiritual = val; end

      def Spells.majorspirit;          @@majorspiritual;       end

      def Spells.wizard=(val);         @@wizard = val;         end

      def Spells.wizard;               @@wizard;               end

      def Spells.sorcerer=(val);       @@sorcerer = val;       end

      def Spells.sorcerer;             @@sorcerer;             end

      def Spells.ranger=(val);         @@ranger = val;         end

      def Spells.ranger;               @@ranger;               end

      def Spells.paladin=(val);        @@paladin = val;        end

      def Spells.paladin;              @@paladin;              end

      def Spells.empath=(val);         @@empath = val;         end

      def Spells.empath;               @@empath;               end

      def Spells.cleric=(val);         @@cleric = val;         end

      def Spells.cleric;               @@cleric;               end

      def Spells.bard=(val);           @@bard = val;           end

      def Spells.bard;                 @@bard;                 end

      def Spells.get_circle_name(num)
        val = num.to_s
        if val == '1'
          'Minor Spirit'
        elsif val == '2'
          'Major Spirit'
        elsif val == '3'
          'Cleric'
        elsif val == '4'
          'Minor Elemental'
        elsif val == '5'
          'Major Elemental'
        elsif val == '6'
          'Ranger'
        elsif val == '7'
          'Sorcerer'
        elsif val == '9'
          'Wizard'
        elsif val == '10'
          'Bard'
        elsif val == '11'
          'Empath'
        elsif val == '12'
          'Minor Mental'
        elsif val == '16'
          'Paladin'
        elsif val == '17'
          'Arcane'
        elsif val == '66'
          'Death'
        elsif val == '65'
          'Imbedded Enchantment'
        elsif val == '90'
          'Miscellaneous'
        elsif val == '95'
          'Armor Specialization'
        elsif val == '96'
          'Combat Maneuvers'
        elsif val == '97'
          'Guardians of Sunfist'
        elsif val == '98'
          'Order of Voln'
        elsif val == '99'
          'Council of Light'
        else
          'Unknown Circle'
        end
      end

      def Spells.active
        Spell.active
      end

      def Spells.known
        known_spells = Array.new
        Spell.list.each { |spell| known_spells.push(spell) if spell.known? }
        return known_spells
      end

      def Spells.serialize
        [@@minorelemental, @@majorelemental, @@minorspiritual, @@majorspiritual, @@wizard, @@sorcerer, @@ranger, @@paladin, @@empath, @@cleric, @@bard, @@minormental]
      end

      def Spells.load_serialized=(val)
        @@minorelemental, @@majorelemental, @@minorspiritual, @@majorspiritual, @@wizard, @@sorcerer, @@ranger, @@paladin, @@empath, @@cleric, @@bard, @@minormental = val
        # new spell circle added 2012-07-18; old data files will make @@minormental nil
        @@minormental ||= 0
      end
    end

    require_relative("./lib/spell.rb")
    require_relative("./lib/bounty.rb")

    # #updating PSM3 abilities via breakout - 20210801
    require_relative("./lib/armor.rb")
    require_relative("./lib/cman.rb")
    require_relative("./lib/feat.rb")
    require_relative("./lib/gameobj.rb")
    require_relative("./lib/shield.rb")
    require_relative("./lib/weapon.rb")
    require_relative("./lib/infomon/infomon.rb")
    require_relative("./lib/stats/stats.rb")


    class Gift
      @@gift_start ||= Time.now
      @@pulse_count ||= 0
      def Gift.started
        @@gift_start = Time.now
        @@pulse_count = 0
      end

      def Gift.pulse
        @@pulse_count += 1
      end

      def Gift.remaining
        ([360 - @@pulse_count, 0].max * 60).to_f
      end

      def Gift.restarts_on
        @@gift_start + 594000
      end

      def Gift.serialize
        [@@gift_start, @@pulse_count]
      end

      def Gift.load_serialized=(array)
        @@gift_start = array[0]
        @@pulse_count = array[1].to_i
      end

      def Gift.ended
        @@pulse_count = 360
      end

      def Gift.stopwatch
        nil
      end
    end

    module Effects
      class Registry
        include Enumerable

        def initialize(dialog)
          @dialog = dialog
        end

        def to_h
          XMLData.dialogs.fetch(@dialog, {})
        end

        def each()
          to_h.each { |k, v| yield(k, v) }
        end

        def active?(effect)
          expiry = to_h.fetch(effect, 0)
          expiry.to_f > Time.now.to_f
        end

        def time_left(effect)
          expiry = to_h.fetch(effect, 0)
          if to_h.fetch(effect, 0) != 0
            ((expiry - Time.now) / 60.to_f)
          else
            expiry
          end
        end
      end

      Spells    = Registry.new("Active Spells")
      Buffs     = Registry.new("Buffs")
      Debuffs   = Registry.new("Debuffs")
      Cooldowns = Registry.new("Cooldowns")

      def self.display
        effect_out = Terminal::Table.new :headings => ["ID", "Type", "Name", "Duration"]
        titles = ["Spells", "Cooldowns", "Buffs", "Debuffs"]
        circle = nil
        [Effects::Spells, Effects::Cooldowns, Effects::Buffs, Effects::Debuffs].each { |effect|
          title = titles.shift
          id_effects = effect.to_h.select { |k,v| k.is_a?(Integer) }
          text_effects = effect.to_h.reject { |k,v| k.is_a?(Integer) }
          if id_effects.length != text_effects.length
            # has spell names disabled
            text_effects = id_effects
          end
          if id_effects.length == 0
            effect_out.add_row ["", title, "No #{title.downcase} found!", ""]
          else
            id_effects.each { |sn, end_time|
              stext = text_effects.shift[0]
              duration = ((end_time - Time.now) / 60.to_f)
              if duration < 0
                next
              elsif duration > 86400
                duration = "Indefinite"
              else
                duration = duration.as_time
              end
              if Spell[sn].circlename && circle != Spell[sn].circlename && title == 'Spells'
                circle = Spell[sn].circlename
              end
              effect_out.add_row [sn, title, stext, duration]
            }
          end
          effect_out.add_separator unless title == 'Debuffs'
        }
        _respond "<output class=\"mono\"/>\n" + effect_out.to_s + "\n<output class=\"\"/>"
      end
    end

    class Wounds
      def Wounds.leftEye;   fix_injury_mode; XMLData.injuries['leftEye']['wound'];   end

      def Wounds.leye;      fix_injury_mode; XMLData.injuries['leftEye']['wound'];   end

      def Wounds.rightEye;  fix_injury_mode; XMLData.injuries['rightEye']['wound'];  end

      def Wounds.reye;      fix_injury_mode; XMLData.injuries['rightEye']['wound'];  end

      def Wounds.head;      fix_injury_mode; XMLData.injuries['head']['wound'];      end

      def Wounds.neck;      fix_injury_mode; XMLData.injuries['neck']['wound'];      end

      def Wounds.back;      fix_injury_mode; XMLData.injuries['back']['wound'];      end

      def Wounds.chest;     fix_injury_mode; XMLData.injuries['chest']['wound'];     end

      def Wounds.abdomen;   fix_injury_mode; XMLData.injuries['abdomen']['wound'];   end

      def Wounds.abs;       fix_injury_mode; XMLData.injuries['abdomen']['wound'];   end

      def Wounds.leftArm;   fix_injury_mode; XMLData.injuries['leftArm']['wound'];   end

      def Wounds.larm;      fix_injury_mode; XMLData.injuries['leftArm']['wound'];   end

      def Wounds.rightArm;  fix_injury_mode; XMLData.injuries['rightArm']['wound'];  end

      def Wounds.rarm;      fix_injury_mode; XMLData.injuries['rightArm']['wound'];  end

      def Wounds.rightHand; fix_injury_mode; XMLData.injuries['rightHand']['wound']; end

      def Wounds.rhand;     fix_injury_mode; XMLData.injuries['rightHand']['wound']; end

      def Wounds.leftHand;  fix_injury_mode; XMLData.injuries['leftHand']['wound'];  end

      def Wounds.lhand;     fix_injury_mode; XMLData.injuries['leftHand']['wound'];  end

      def Wounds.leftLeg;   fix_injury_mode; XMLData.injuries['leftLeg']['wound'];   end

      def Wounds.lleg;      fix_injury_mode; XMLData.injuries['leftLeg']['wound'];   end

      def Wounds.rightLeg;  fix_injury_mode; XMLData.injuries['rightLeg']['wound'];  end

      def Wounds.rleg;      fix_injury_mode; XMLData.injuries['rightLeg']['wound'];  end

      def Wounds.leftFoot;  fix_injury_mode; XMLData.injuries['leftFoot']['wound'];  end

      def Wounds.rightFoot; fix_injury_mode; XMLData.injuries['rightFoot']['wound']; end

      def Wounds.nsys;      fix_injury_mode; XMLData.injuries['nsys']['wound'];      end

      def Wounds.nerves;    fix_injury_mode; XMLData.injuries['nsys']['wound'];      end

      def Wounds.arms
        fix_injury_mode
        [XMLData.injuries['leftArm']['wound'], XMLData.injuries['rightArm']['wound'], XMLData.injuries['leftHand']['wound'], XMLData.injuries['rightHand']['wound']].max
      end

      def Wounds.limbs
        fix_injury_mode
        [XMLData.injuries['leftArm']['wound'], XMLData.injuries['rightArm']['wound'], XMLData.injuries['leftHand']['wound'], XMLData.injuries['rightHand']['wound'], XMLData.injuries['leftLeg']['wound'], XMLData.injuries['rightLeg']['wound']].max
      end

      def Wounds.torso
        fix_injury_mode
        [XMLData.injuries['rightEye']['wound'], XMLData.injuries['leftEye']['wound'], XMLData.injuries['chest']['wound'], XMLData.injuries['abdomen']['wound'], XMLData.injuries['back']['wound']].max
      end

      def Wounds.method_missing(arg = nil)
        echo "Wounds: Invalid area, try one of these: arms, limbs, torso, #{XMLData.injuries.keys.join(', ')}"
        nil
      end
    end

    class Scars
      def Scars.leftEye;   fix_injury_mode; XMLData.injuries['leftEye']['scar'];   end

      def Scars.leye;      fix_injury_mode; XMLData.injuries['leftEye']['scar'];   end

      def Scars.rightEye;  fix_injury_mode; XMLData.injuries['rightEye']['scar'];  end

      def Scars.reye;      fix_injury_mode; XMLData.injuries['rightEye']['scar'];  end

      def Scars.head;      fix_injury_mode; XMLData.injuries['head']['scar'];      end

      def Scars.neck;      fix_injury_mode; XMLData.injuries['neck']['scar'];      end

      def Scars.back;      fix_injury_mode; XMLData.injuries['back']['scar'];      end

      def Scars.chest;     fix_injury_mode; XMLData.injuries['chest']['scar'];     end

      def Scars.abdomen;   fix_injury_mode; XMLData.injuries['abdomen']['scar'];   end

      def Scars.abs;       fix_injury_mode; XMLData.injuries['abdomen']['scar'];   end

      def Scars.leftArm;   fix_injury_mode; XMLData.injuries['leftArm']['scar'];   end

      def Scars.larm;      fix_injury_mode; XMLData.injuries['leftArm']['scar'];   end

      def Scars.rightArm;  fix_injury_mode; XMLData.injuries['rightArm']['scar'];  end

      def Scars.rarm;      fix_injury_mode; XMLData.injuries['rightArm']['scar'];  end

      def Scars.rightHand; fix_injury_mode; XMLData.injuries['rightHand']['scar']; end

      def Scars.rhand;     fix_injury_mode; XMLData.injuries['rightHand']['scar']; end

      def Scars.leftHand;  fix_injury_mode; XMLData.injuries['leftHand']['scar'];  end

      def Scars.lhand;     fix_injury_mode; XMLData.injuries['leftHand']['scar'];  end

      def Scars.leftLeg;   fix_injury_mode; XMLData.injuries['leftLeg']['scar'];   end

      def Scars.lleg;      fix_injury_mode; XMLData.injuries['leftLeg']['scar'];   end

      def Scars.rightLeg;  fix_injury_mode; XMLData.injuries['rightLeg']['scar'];  end

      def Scars.rleg;      fix_injury_mode; XMLData.injuries['rightLeg']['scar'];  end

      def Scars.leftFoot;  fix_injury_mode; XMLData.injuries['leftFoot']['scar'];  end

      def Scars.rightFoot; fix_injury_mode; XMLData.injuries['rightFoot']['scar']; end

      def Scars.nsys;      fix_injury_mode; XMLData.injuries['nsys']['scar'];      end

      def Scars.nerves;    fix_injury_mode; XMLData.injuries['nsys']['scar'];      end

      def Scars.arms
        fix_injury_mode
        [XMLData.injuries['leftArm']['scar'], XMLData.injuries['rightArm']['scar'], XMLData.injuries['leftHand']['scar'], XMLData.injuries['rightHand']['scar']].max
      end

      def Scars.limbs
        fix_injury_mode
        [XMLData.injuries['leftArm']['scar'], XMLData.injuries['rightArm']['scar'], XMLData.injuries['leftHand']['scar'], XMLData.injuries['rightHand']['scar'], XMLData.injuries['leftLeg']['scar'], XMLData.injuries['rightLeg']['scar']].max
      end

      def Scars.torso
        fix_injury_mode
        [XMLData.injuries['rightEye']['scar'], XMLData.injuries['leftEye']['scar'], XMLData.injuries['chest']['scar'], XMLData.injuries['abdomen']['scar'], XMLData.injuries['back']['scar']].max
      end

      def Scars.method_missing(arg = nil)
        echo "Scars: Invalid area, try one of these: arms, limbs, torso, #{XMLData.injuries.keys.join(', ')}"
        nil
      end
    end
  end
  module DragonRealms
    # fixme
  end
end

include Games::Gemstone

JUMP = Exception.exception('JUMP')
JUMP_ERROR = Exception.exception('JUMP_ERROR')

DIRMAP = {
  'out' => 'K',
  'ne' => 'B',
  'se' => 'D',
  'sw' => 'F',
  'nw' => 'H',
  'up' => 'I',
  'down' => 'J',
  'n' => 'A',
  'e' => 'C',
  's' => 'E',
  'w' => 'G',
}
SHORTDIR = {
  'out' => 'out',
  'northeast' => 'ne',
  'southeast' => 'se',
  'southwest' => 'sw',
  'northwest' => 'nw',
  'up' => 'up',
  'down' => 'down',
  'north' => 'n',
  'east' => 'e',
  'south' => 's',
  'west' => 'w',
}
LONGDIR = {
  'out' => 'out',
  'ne' => 'northeast',
  'se' => 'southeast',
  'sw' => 'southwest',
  'nw' => 'northwest',
  'up' => 'up',
  'down' => 'down',
  'n' => 'north',
  'e' => 'east',
  's' => 'south',
  'w' => 'west',
}
MINDMAP = {
  'clear as a bell' => 'A',
  'fresh and clear' => 'B',
  'clear' => 'C',
  'muddled' => 'D',
  'becoming numbed' => 'E',
  'numbed' => 'F',
  'must rest' => 'G',
  'saturated' => 'H',
}
ICONMAP = {
  'IconKNEELING' => 'GH',
  'IconPRONE' => 'G',
  'IconSITTING' => 'H',
  'IconSTANDING' => 'T',
  'IconSTUNNED' => 'I',
  'IconHIDDEN' => 'N',
  'IconINVISIBLE' => 'D',
  'IconDEAD' => 'B',
  'IconWEBBED' => 'C',
  'IconJOINED' => 'P',
  'IconBLEEDING' => 'O',
}

XMLData = XMLParser.new

reconnect_if_wanted = proc {
  if ARGV.include?('--reconnect') and ARGV.include?('--login') and not $_CLIENTBUFFER_.any? { |cmd| cmd =~ /^(?:\[.*?\])?(?:<c>)?(?:quit|exit)/i }
    if reconnect_arg = ARGV.find { |arg| arg =~ /^\-\-reconnect\-delay=[0-9]+(?:\+[0-9]+)?$/ }
      reconnect_arg =~ /^\-\-reconnect\-delay=([0-9]+)(\+[0-9]+)?/
      reconnect_delay = $1.to_i
      reconnect_step = $2.to_i
    else
      reconnect_delay = 60
      reconnect_step = 0
    end
    Lich.log "info: waiting #{reconnect_delay} seconds to reconnect..."
    sleep reconnect_delay
    Lich.log 'info: reconnecting...'
    if (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
      if $frontend == 'stormfront'
        system 'taskkill /FI "WINDOWTITLE eq [GSIV: ' + Char.name + '*"' # fixme: window title changing to Gemstone IV: Char.name # name optional
      end
      args = ['start rubyw.exe']
    else
      args = ['ruby']
    end
    args.push $PROGRAM_NAME.slice(/[^\\\/]+$/)
    args.concat ARGV
    args.push '--reconnected' unless args.include?('--reconnected')
    if reconnect_step > 0
      args.delete(reconnect_arg)
      args.concat ["--reconnect-delay=#{reconnect_delay + reconnect_step}+#{reconnect_step}"]
    end
    Lich.log "exec args.join(' '): exec #{args.join(' ')}"
    exec args.join(' ')
  end
}

#
# Start deprecated stuff
#

$version = LICH_VERSION
$room_count = 0
$psinet = false
$stormfront = true

class Script
  def Script.self
    Script.current
  end

  def Script.running
    list = Array.new
    for script in @@running
      list.push(script) unless script.hidden
    end
    return list
  end

  def Script.index
    Script.running
  end

  def Script.hidden
    list = Array.new
    for script in @@running
      list.push(script) if script.hidden
    end
    return list
  end

  def Script.namescript_incoming(line)
    Script.new_downstream(line)
  end
end

def start_script(script_name, cli_vars = [], flags = Hash.new)
  if flags == true
    flags = { :quiet => true }
  end
  Script.start(script_name, cli_vars.join(' '), flags)
end

def start_scripts(*script_names)
  script_names.flatten.each { |script_name|
    start_script(script_name)
    sleep 0.02
  }
end

def force_start_script(script_name, cli_vars = [], flags = {})
  flags = Hash.new unless flags.class == Hash
  flags[:force] = true
  start_script(script_name, cli_vars, flags)
end

def survivepoison?
  echo 'survivepoison? called, but there is no XML for poison rate'
  return true
end

def survivedisease?
  echo 'survivepoison? called, but there is no XML for disease rate'
  return true
end

def before_dying(&code)
  Script.at_exit(&code)
end

def undo_before_dying
  Script.clear_exit_procs
end

def abort!
  Script.exit!
end

def fetchloot(userbagchoice = UserVars.lootsack)
  if GameObj.loot.empty?
    return false
  end

  if UserVars.excludeloot.empty?
    regexpstr = nil
  else
    regexpstr = UserVars.excludeloot.split(', ').join('|')
  end
  if checkright and checkleft
    stowed = GameObj.right_hand.noun
    fput "put my #{stowed} in my #{UserVars.lootsack}"
  else
    stowed = nil
  end
  GameObj.loot.each { |loot|
    unless not regexpstr.nil? and loot.name =~ /#{regexpstr}/
      fput "get #{loot.noun}"
      fput("put my #{loot.noun} in my #{userbagchoice}") if (checkright || checkleft)
    end
  }
  if stowed
    fput "take my #{stowed} from my #{UserVars.lootsack}"
  end
end

def take(*items)
  items.flatten!
  if (righthand? && lefthand?)
    weap = checkright
    fput "put my #{checkright} in my #{UserVars.lootsack}"
    unsh = true
  else
    unsh = false
  end
  items.each { |trinket|
    fput "take #{trinket}"
    fput("put my #{trinket} in my #{UserVars.lootsack}") if (righthand? || lefthand?)
  }
  if unsh then fput("take my #{weap} from my #{UserVars.lootsack}") end
end

def stop_script(*target_names)
  numkilled = 0
  target_names.each { |target_name|
    condemned = Script.list.find { |s_sock| s_sock.name =~ /^#{target_name}/i }
    if condemned.nil?
      respond("--- Lich: '#{Script.current}' tried to stop '#{target_name}', but it isn't running!")
    else
      if condemned.name =~ /^#{Script.current.name}$/i
        exit
      end
      condemned.kill
      respond("--- Lich: '#{condemned}' has been stopped by #{Script.current}.")
      numkilled += 1
    end
  }
  if numkilled == 0
    return false
  else
    return numkilled
  end
end

def running?(*snames)
  snames.each { |checking| (return false) unless (Script.running.find { |lscr| lscr.name =~ /^#{checking}$/i } || Script.running.find { |lscr| lscr.name =~ /^#{checking}/i } || Script.hidden.find { |lscr| lscr.name =~ /^#{checking}$/i } || Script.hidden.find { |lscr| lscr.name =~ /^#{checking}/i }) }
  true
end

module Settings
  def Settings.load; end

  def Settings.save_all; end

  def Settings.clear; end

  def Settings.auto=(val); end

  def Settings.auto; end

  def Settings.autoload; end
end

module GameSettings
  def GameSettings.load; end

  def GameSettings.save; end

  def GameSettings.save_all; end

  def GameSettings.clear; end

  def GameSettings.auto=(val); end

  def GameSettings.auto; end

  def GameSettings.autoload; end
end

module CharSettings
  def CharSettings.load; end

  def CharSettings.save; end

  def CharSettings.save_all; end

  def CharSettings.clear; end

  def CharSettings.auto=(val); end

  def CharSettings.auto; end

  def CharSettings.autoload; end
end

module UserVars
  def UserVars.list
    Vars.list
  end

  def UserVars.method_missing(arg1, arg2 = '')
    Vars.method_missing(arg1, arg2)
  end

  def UserVars.change(var_name, value, t = nil)
    Vars[var_name] = value
  end

  def UserVars.add(var_name, value, t = nil)
    Vars[var_name] = Vars[var_name].split(', ').push(value).join(', ')
  end

  def UserVars.delete(var_name, t = nil)
    Vars[var_name] = nil
  end

  def UserVars.list_global
    Array.new
  end

  def UserVars.list_char
    Vars.list
  end
end

def start_exec_script(cmd_data, options = Hash.new)
  ExecScript.start(cmd_data, options)
end

module Setting
  def Setting.[](name)
    Settings[name]
  end

  def Setting.[]=(name, value)
    Settings[name] = value
  end

  def Setting.to_hash(scope = ':')
    Settings.to_hash
  end
end
module GameSetting
  def GameSetting.[](name)
    GameSettings[name]
  end

  def GameSetting.[]=(name, value)
    GameSettings[name] = value
  end

  def GameSetting.to_hash(scope = ':')
    GameSettings.to_hash
  end
end
module CharSetting
  def CharSetting.[](name)
    CharSettings[name]
  end

  def CharSetting.[]=(name, value)
    CharSettings[name] = value
  end

  def CharSetting.to_hash(scope = ':')
    CharSettings.to_hash
  end
end
class StringProc
  def StringProc._load(string)
    StringProc.new(string)
  end
end
class String
  def to_a # for compatibility with Ruby 1.8
    [self]
  end

  def silent
    false
  end

  def split_as_list
    string = self
    string.sub!(/^You (?:also see|notice) |^In the .+ you see /, ',')
    string.sub('.', '').sub(/ and (an?|some|the)/, ', \1').split(',').reject { |str| str.strip.empty? }.collect { |str| str.lstrip }
  end
end
#
# End deprecated stuff
#

undef :abort
alias :mana :checkmana
alias :mana? :checkmana
alias :max_mana :maxmana
alias :health :checkhealth
alias :health? :checkhealth
alias :spirit :checkspirit
alias :spirit? :checkspirit
alias :stamina :checkstamina
alias :stamina? :checkstamina
alias :stunned? :checkstunned
alias :bleeding? :checkbleeding
alias :reallybleeding? :checkreallybleeding
alias :poisoned? :checkpoison
alias :diseased? :checkdisease
alias :dead? :checkdead
alias :hiding? :checkhidden
alias :hidden? :checkhidden
alias :hidden :checkhidden
alias :checkhiding :checkhidden
alias :invisible? :checkinvisible
alias :standing? :checkstanding
alias :kneeling? :checkkneeling
alias :sitting? :checksitting
alias :stance? :checkstance
alias :stance :checkstance
alias :joined? :checkgrouped
alias :checkjoined :checkgrouped
alias :group? :checkgrouped
alias :myname? :checkname
alias :active? :checkspell
alias :righthand? :checkright
alias :lefthand? :checkleft
alias :righthand :checkright
alias :lefthand :checkleft
alias :mind? :checkmind
alias :checkactive :checkspell
alias :forceput :fput
alias :send_script :send_scripts
alias :stop_scripts :stop_script
alias :kill_scripts :stop_script
alias :kill_script :stop_script
alias :fried? :checkfried
alias :saturated? :checksaturated
alias :webbed? :checkwebbed
alias :pause_scripts :pause_script
alias :roomdescription? :checkroomdescrip
alias :prepped? :checkprep
alias :checkprepared :checkprep
alias :unpause_scripts :unpause_script
alias :priority? :setpriority
alias :checkoutside :outside?
alias :toggle_status :status_tags
alias :encumbrance? :checkencumbrance
alias :bounty? :checkbounty

#
# Program start
#

ARGV.delete_if { |arg| arg =~ /launcher\.exe/i } # added by Simutronics Game Entry

argv_options = Hash.new
bad_args = Array.new

for arg in ARGV
  if (arg == '-h') or (arg == '--help')
    puts 'Usage:  lich [OPTION]'
    puts ''
    puts 'Options are:'
    puts '  -h, --help          Display this list.'
    puts '  -V, --version       Display the program version number and credits.'
    puts ''
    puts '  -d, --directory     Set the main Lich program directory.'
    puts '      --script-dir    Set the directoy where Lich looks for scripts.'
    puts '      --data-dir      Set the directory where Lich will store script data.'
    puts '      --temp-dir      Set the directory where Lich will store temporary files.'
    puts ''
    puts '  -w, --wizard        Run in Wizard mode (default)'
    puts '  -s, --stormfront    Run in StormFront mode.'
    puts '      --avalon        Run in Avalon mode.'
    puts '      --frostbite     Run in Frosbite mode.'
    puts ''
    puts '      --gemstone      Connect to the Gemstone IV Prime server (default).'
    puts '      --dragonrealms  Connect to the DragonRealms server.'
    puts '      --platinum      Connect to the Gemstone IV/DragonRealms Platinum server.'
    puts '      --test          Connect to the test instance of the selected game server.'
    puts '  -g, --game          Set the IP address and port of the game.  See example below.'
    puts ''
    puts '      --install       Edits the Windows/WINE registry so that Lich is started when logging in using the website or SGE.'
    puts '      --uninstall     Removes Lich from the registry.'
    puts ''
    puts 'The majority of Lich\'s built-in functionality was designed and implemented with Simutronics MUDs in mind (primarily Gemstone IV): as such, many options/features provided by Lich may not be applicable when it is used with a non-Simutronics MUD.  In nearly every aspect of the program, users who are not playing a Simutronics game should be aware that if the description of a feature/option does not sound applicable and/or compatible with the current game, it should be assumed that the feature/option is not.  This particularly applies to in-script methods (commands) that depend heavily on the data received from the game conforming to specific patterns (for instance, it\'s extremely unlikely Lich will know how much "health" your character has left in a non-Simutronics game, and so the "health" script command will most likely return a value of 0).'
    puts ''
    puts 'The level of increase in efficiency when Lich is run in "bare-bones mode" (i.e. started with the --bare argument) depends on the data stream received from a given game, but on average results in a moderate improvement and it\'s recommended that Lich be run this way for any game that does not send "status information" in a format consistent with Simutronics\' GSL or XML encoding schemas.'
    puts ''
    puts ''
    puts 'Examples:'
    puts '  lich -w -d /usr/bin/lich/          (run Lich in Wizard mode using the dir \'/usr/bin/lich/\' as the program\'s home)'
    puts '  lich -g gs3.simutronics.net:4000   (run Lich using the IP address \'gs3.simutronics.net\' and the port number \'4000\')'
    puts '  lich --dragonrealms --test --genie (run Lich connected to DragonRealms Test server for the Genie frontend)'
    puts '  lich --script-dir /mydir/scripts   (run Lich with its script directory set to \'/mydir/scripts\')'
    puts '  lich --bare -g skotos.net:5555     (run in bare-bones mode with the IP address and port of the game set to \'skotos.net:5555\')'
    puts ''
    exit
  elsif (arg == '-v') or (arg == '--version')
    puts "The Lich, version #{LICH_VERSION}"
    puts ' (an implementation of the Ruby interpreter by Yukihiro Matsumoto designed to be a \'script engine\' for text-based MUDs)'
    puts ''
    puts '- The Lich program and all material collectively referred to as "The Lich project" is copyright (C) 2005-2006 Murray Miron.'
    puts '- The Gemstone IV and DragonRealms games are copyright (C) Simutronics Corporation.'
    puts '- The Wizard front-end and the StormFront front-end are also copyrighted by the Simutronics Corporation.'
    puts '- Ruby is (C) Yukihiro \'Matz\' Matsumoto.'
    puts ''
    puts 'Thanks to all those who\'ve reported bugs and helped me track down problems on both Windows and Linux.'
    exit
  elsif arg == '--link-to-sge'
    result = Lich.link_to_sge
    if $stdout.isatty
      if result
        $stdout.puts "Successfully linked to SGE."
      else
        $stdout.puts "Failed to link to SGE."
      end
    end
    exit
  elsif arg == '--unlink-from-sge'
    result = Lich.unlink_from_sge
    if $stdout.isatty
      if result
        $stdout.puts "Successfully unlinked from SGE."
      else
        $stdout.puts "Failed to unlink from SGE."
      end
    end
    exit
  elsif arg == '--link-to-sal'
    result = Lich.link_to_sal
    if $stdout.isatty
      if result
        $stdout.puts "Successfully linked to SAL files."
      else
        $stdout.puts "Failed to link to SAL files."
      end
    end
    exit
  elsif arg == '--unlink-from-sal'
    result = Lich.unlink_from_sal
    if $stdout.isatty
      if result
        $stdout.puts "Successfully unlinked from SAL files."
      else
        $stdout.puts "Failed to unlink from SAL files."
      end
    end
    exit
  elsif arg == '--install' # deprecated
    if Lich.link_to_sge and Lich.link_to_sal
      $stdout.puts 'Install was successful.'
      Lich.log 'Install was successful.'
    else
      $stdout.puts 'Install failed.'
      Lich.log 'Install failed.'
    end
    exit
  elsif arg == '--uninstall' # deprecated
    if Lich.unlink_from_sge and Lich.unlink_from_sal
      $stdout.puts 'Uninstall was successful.'
      Lich.log 'Uninstall was successful.'
    else
      $stdout.puts 'Uninstall failed.'
      Lich.log 'Uninstall failed.'
    end
    exit
  elsif arg =~ /^--(?:home)=(.+)$/i
    LICH_DIR = $1.sub(/[\\\/]$/, '')
  elsif arg =~ /^--temp=(.+)$/i
    TEMP_DIR = $1.sub(/[\\\/]$/, '')
  elsif arg =~ /^--scripts=(.+)$/i
    SCRIPT_DIR = $1.sub(/[\\\/]$/, '')
  elsif arg =~ /^--maps=(.+)$/i
    MAP_DIR = $1.sub(/[\\\/]$/, '')
  elsif arg =~ /^--logs=(.+)$/i
    LOG_DIR = $1.sub(/[\\\/]$/, '')
  elsif arg =~ /^--backup=(.+)$/i
    BACKUP_DIR = $1.sub(/[\\\/]$/, '')
  elsif arg =~ /^--data=(.+)$/i
    DATA_DIR = $1.sub(/[\\\/]$/, '')
  elsif arg =~ /^--start-scripts=(.+)$/i
    argv_options[:start_scripts] = $1
  elsif arg =~ /^--reconnect$/i
    argv_options[:reconnect] = true
  elsif arg =~ /^--reconnect-delay=(.+)$/i
    argv_options[:reconnect_delay] = $1
  elsif arg =~ /^--host=(.+):(.+)$/
    argv_options[:host] = { :domain => $1, :port => $2.to_i }
  elsif arg =~ /^--hosts-file=(.+)$/i
    argv_options[:hosts_file] = $1
  elsif arg =~ /^--no-gui$/i
    argv_options[:gui] = false
  elsif arg =~ /^--gui$/i
    argv_options[:gui] = true
  elsif arg =~ /^--game=(.+)$/i
    argv_options[:game] = $1
  elsif arg =~ /^--account=(.+)$/i
    argv_options[:account] = $1
  elsif arg =~ /^--password=(.+)$/i
    argv_options[:password] = $1
  elsif arg =~ /^--character=(.+)$/i
    argv_options[:character] = $1
  elsif arg =~ /^--frontend=(.+)$/i
    argv_options[:frontend] = $1
  elsif arg =~ /^--frontend-command=(.+)$/i
    argv_options[:frontend_command] = $1
  elsif arg =~ /^--save$/i
    argv_options[:save] = true
  elsif arg =~ /^--wine(?:\-prefix)?=.+$/i
    nil # already used when defining the Wine module
  elsif arg =~ /\.sal$|Gse\.~xt$/i
    argv_options[:sal] = arg
    unless File.exist?(argv_options[:sal])
      if ARGV.join(' ') =~ /([A-Z]:\\.+?\.(?:sal|~xt))/i
        argv_options[:sal] = $1
      end
    end
    unless File.exist?(argv_options[:sal])
      if defined?(Wine)
        argv_options[:sal] = "#{Wine::PREFIX}/drive_c/#{argv_options[:sal][3..-1].split('\\').join('/')}"
      end
    end
    bad_args.clear
  else
    bad_args.push(arg)
  end
end

if arg = ARGV.find { |a| a == '--hosts-dir' }
  i = ARGV.index(arg)
  ARGV.delete_at(i)
  hosts_dir = ARGV[i]
  ARGV.delete_at(i)
  if hosts_dir and File.exist?(hosts_dir)
    hosts_dir = hosts_dir.tr('\\', '/')
    hosts_dir += '/' unless hosts_dir[-1..-1] == '/'
  else
    $stdout.puts "warning: given hosts directory does not exist: #{hosts_dir}"
    hosts_dir = nil
  end
else
  hosts_dir = nil
end

detachable_client_port = nil
if arg = ARGV.find { |a| a =~ /^\-\-detachable\-client=[0-9]+$/ }
  detachable_client_port = /^\-\-detachable\-client=([0-9]+)$/.match(arg).captures.first
end

if argv_options[:sal]
  unless File.exist?(argv_options[:sal])
    Lich.log "error: launch file does not exist: #{argv_options[:sal]}"
    Lich.msgbox "error: launch file does not exist: #{argv_options[:sal]}"
    exit
  end
  Lich.log "info: launch file: #{argv_options[:sal]}"
  if argv_options[:sal] =~ /SGE\.sal/i
    unless launcher_cmd = Lich.get_simu_launcher
      $stdout.puts 'error: failed to find the Simutronics launcher'
      Lich.log 'error: failed to find the Simutronics launcher'
      exit
    end
    launcher_cmd.sub!('%1', argv_options[:sal])
    Lich.log "info: launcher_cmd: #{launcher_cmd}"
    if defined?(Win32) and launcher_cmd =~ /^"(.*?)"\s*(.*)$/
      dir_file = $1
      param = $2
      dir = dir_file.slice(/^.*[\\\/]/)
      file = dir_file.sub(/^.*[\\\/]/, '')
      operation = (Win32.isXP? ? 'open' : 'runas')
      Win32.ShellExecute(:lpOperation => operation, :lpFile => file, :lpDirectory => dir, :lpParameters => param)
      if r < 33
        Lich.log "error: Win32.ShellExecute returned #{r}; Win32.GetLastError: #{Win32.GetLastError}"
      end
    elsif defined?(Wine)
      system("#{Wine::BIN} #{launcher_cmd}")
    else
      system(launcher_cmd)
    end
    exit
  end
end

if arg = ARGV.find { |a| (a == '-g') or (a == '--game') }
  game_host, game_port = ARGV[ARGV.index(arg) + 1].split(':')
  game_port = game_port.to_i
  if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
    $frontend = 'stormfront'
  elsif ARGV.any? { |arg| (arg == '-w') or (arg == '--wizard') }
    $frontend = 'wizard'
  elsif ARGV.any? { |arg| arg == '--avalon' }
    $frontend = 'avalon'
  elsif ARGV.any? { |arg| arg == '--frostbite' }
    $frontend = 'frostbite'
  else
    $frontend = 'unknown'
  end
elsif ARGV.include?('--gemstone')
  if ARGV.include?('--platinum')
    $platinum = true
    if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
      game_host = 'storm.gs4.game.play.net'
      game_port = 10124
      $frontend = 'stormfront'
    else
      game_host = 'gs-plat.simutronics.net'
      game_port = 10121
      if ARGV.any? { |arg| arg == '--avalon' }
        $frontend = 'avalon'
      else
        $frontend = 'wizard'
      end
    end
  else
    $platinum = false
    if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
      game_host = 'storm.gs4.game.play.net'
      game_port = 10024
      $frontend = 'stormfront'
    else
      game_host = 'gs3.simutronics.net'
      game_port = 4900
      if ARGV.any? { |arg| arg == '--avalon' }
        $frontend = 'avalon'
      else
        $frontend = 'wizard'
      end
    end
  end
elsif ARGV.include?('--shattered')
  $platinum = false
  if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
    game_host = 'storm.gs4.game.play.net'
    game_port = 10324
    $frontend = 'stormfront'
  else
    game_host = 'gs4.simutronics.net'
    game_port = 10321
    if ARGV.any? { |arg| arg == '--avalon' }
      $frontend = 'avalon'
    else
      $frontend = 'wizard'
    end
  end
elsif ARGV.include?('--fallen')
  $platinum = false
  # Not sure what the port info is for anything else but Genie :(
  if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
    $frontend = 'stormfront'
    $stdout.puts "fixme"
    Lich.log "fixme"
    exit
  elsif ARGV.grep(/--genie/).any?
    game_host = 'dr.simutronics.net'
    game_port = 11324
    $frontend = 'genie'
  else
    $stdout.puts "fixme"
    Lich.log "fixme"
    exit
  end
elsif ARGV.include?('--dragonrealms')
  if ARGV.include?('--platinum')
    $platinum = true
    if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
      $stdout.puts "fixme"
      Lich.log "fixme"
      exit
      $frontend = 'stormfront'
    elsif ARGV.grep(/--genie/).any?
      game_host = 'dr.simutronics.net'
      game_port = 11124
      $frontend = 'genie'
    elsif ARGV.grep(/--frostbite/).any?
      game_host = 'dr.simutronics.net'
      game_port = 11124
      $frontend = 'frostbite'
    else
      $stdout.puts "fixme"
      Lich.log "fixme"
      exit
      $frontend = 'wizard'
    end
  else
    $platinum = false
    if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
      $frontend = 'stormfront'
      $stdout.puts "fixme"
      Lich.log "fixme"
      exit
    elsif ARGV.grep(/--genie/).any?
      game_host = 'dr.simutronics.net'
      game_port = ARGV.include?('--test') ? 11624 : 11024
      $frontend = 'genie'
    else
      game_host = 'dr.simutronics.net'
      game_port = ARGV.include?('--test') ? 11624 : 11024
      if ARGV.any? { |arg| arg == '--avalon' }
        $frontend = 'avalon'
      elsif ARGV.any? { |arg| arg == '--frostbite' }
        $frontend = 'frostbite'
      else
        $frontend = 'wizard'
      end
    end
  end
else
  game_host, game_port = nil, nil
  Lich.log "info: no force-mode info given"
end

main_thread = Thread.new {
  test_mode = false
  $SEND_CHARACTER = '>'
  $cmd_prefix = '<c>'
  $clean_lich_char = $frontend == 'genie' ? ',' : ';'
  $lich_char = Regexp.escape($clean_lich_char)
  $lich_char_regex = Regexp.union(',', ';')

  @launch_data = nil
  require_relative("./lib/eaccess.rb")

  if ARGV.include?('--login')
    if File.exist?("#{DATA_DIR}/entry.dat")
      entry_data = File.open("#{DATA_DIR}/entry.dat", 'r') { |file|
        begin
          Marshal.load(file.read.unpack('m').first)
        rescue
          Array.new
        end
      }
    else
      entry_data = Array.new
    end
    char_name = ARGV[ARGV.index('--login') + 1].capitalize
    if ARGV.include?('--gemstone')
      if ARGV.include?('--platinum')
        data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'GSX') }
      elsif ARGV.include?('--shattered')
        data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'GSF') }
      elsif ARGV.include?('--test')
        data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'GST') }
      else
        data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'GS3') }
      end
    elsif ARGV.include?('--shattered')
      data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'GSF') }
    elsif ARGV.include?('--dragonrealms')
      if ARGV.include?('--platinum')
        data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'DRX') }
      elsif ARGV.include?('--fallen')
        data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'DRF') }
      elsif ARGV.include?('--test')
        data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'DRT') }
      else
        data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'DR') }
      end
    elsif ARGV.include?('--fallen')
      data = entry_data.find { |d| (d[:char_name] == char_name) and (d[:game_code] == 'DRF') }
    else
      data = entry_data.find { |d| (d[:char_name] == char_name) }
    end
    if data
      Lich.log "info: using quick game entry settings for #{char_name}"
      msgbox = proc { |msg|
        if defined?(Gtk)
          done = false
          Gtk.queue {
            dialog = Gtk::MessageDialog.new(nil, Gtk::Dialog::DESTROY_WITH_PARENT, Gtk::MessageDialog::QUESTION, Gtk::MessageDialog::BUTTONS_CLOSE, msg)
            dialog.run
            dialog.destroy
            done = true
          }
          sleep 0.1 until done
        else
          $stdout.puts(msg)
          Lich.log(msg)
        end
      }

      if ARGV.include?('--gst')
        data[:game_code] = 'GST'
      elsif ARGV.include?('--drt')
        data[:game_code] = 'DRT'
      end

      launch_data_hash = EAccess.auth(
        account: data[:user_id],
        password: data[:password],
        character: data[:char_name],
        game_code: data[:game_code]
      )

      @launch_data = launch_data_hash.map { |k, v| "#{k.upcase}=#{v}" }
      if data[:frontend] == 'wizard'
        @launch_data.collect! { |line| line.sub(/GAMEFILE=.+/, 'GAMEFILE=WIZARD.EXE').sub(/GAME=.+/, 'GAME=WIZ').sub(/FULLGAMENAME=.+/, 'FULLGAMENAME=Wizard Front End') }
      elsif data[:frontend] == 'avalon'
        @launch_data.collect! { |line| line.sub(/GAME=.+/, 'GAME=AVALON') }
      end
      if data[:custom_launch]
        @launch_data.push "CUSTOMLAUNCH=#{data[:custom_launch]}"
        if data[:custom_launch_dir]
          @launch_data.push "CUSTOMLAUNCHDIR=#{data[:custom_launch_dir]}"
        end
      end
    else
      $stdout.puts "error: failed to find login data for #{char_name}"
      Lich.log "error: failed to find login data for #{char_name}"
    end

  ## GUI starts here

  elsif defined?(Gtk) and (ARGV.empty? or argv_options[:gui])
    gui_login
  end

  #
  # open the client and have it connect to us
  #

  $_SERVERBUFFER_ = LimitedArray.new
  $_SERVERBUFFER_.max_size = 400
  $_CLIENTBUFFER_ = LimitedArray.new
  $_CLIENTBUFFER_.max_size = 100

  Socket.do_not_reverse_lookup = true

  if argv_options[:sal]
    begin
      @launch_data = File.open(argv_options[:sal]) { |file| file.readlines }.collect { |line| line.chomp }
    rescue
      $stdout.puts "error: failed to read launch_file: #{$!}"
      Lich.log "info: launch_file: #{argv_options[:sal]}"
      Lich.log "error: failed to read launch_file: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      exit
    end
  end

  if @launch_data
    if @launch_data.find { |opt| opt =~ /GAMECODE=DR/ }
      gamecodeshort = "DR"
    else
      gamecodeshort = "GS"
    end
    unless gamecode = @launch_data.find { |line| line =~ /GAMECODE=/ }
      $stdout.puts "error: launch_data contains no GAMECODE info"
      Lich.log "error: launch_data contains no GAMECODE info"
      exit(1)
    end
    unless gameport = @launch_data.find { |line| line =~ /GAMEPORT=/ }
      $stdout.puts "error: launch_data contains no GAMEPORT info"
      Lich.log "error: launch_data contains no GAMEPORT info"
      exit(1)
    end
    unless gamehost = @launch_data.find { |opt| opt =~ /GAMEHOST=/ }
      $stdout.puts "error: launch_data contains no GAMEHOST info"
      Lich.log "error: launch_data contains no GAMEHOST info"
      exit(1)
    end
    unless game = @launch_data.find { |opt| opt =~ /GAME=/ }
      $stdout.puts "error: launch_data contains no GAME info"
      Lich.log "error: launch_data contains no GAME info"
      exit(1)
    end
    if custom_launch = @launch_data.find { |opt| opt =~ /CUSTOMLAUNCH=/ }
      custom_launch.sub!(/^.*?\=/, '')
      Lich.log "info: using custom launch command: #{custom_launch}"
    elsif (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
      Lich.log("info: Working against a Windows Platform for FE Executable")
      if @launch_data.find { |opt| opt =~ /GAME=WIZ/ }
        custom_launch = "Wizard.Exe /G#{gamecodeshort}/H127.0.0.1 /P%port% /K%key%"
      elsif @launch_data.find { |opt| opt =~ /GAME=STORM/ }
        custom_launch = "Wrayth.exe /G#{gamecodeshort}/Hlocalhost/P%port%/K%key%" if $sf_fe_loc =~ /Wrayth/
        custom_launch = "Stormfront.exe /G#{gamecodeshort}/Hlocalhost/P%port%/K%key%" if $sf_fe_loc =~ /STORM/
      end
    elsif defined?(Wine)
      Lich.log("info: Working against a Linux | WINE Platform")
      if @launch_data.find { |opt| opt =~ /GAME=WIZ/ }
        custom_launch = "Wizard.Exe /G#{gamecodeshort}/H127.0.0.1 /P%port% /K%key%"
      elsif @launch_data.find { |opt| opt =~ /GAME=STORM/ }
        custom_launch = "Wrayth.exe /G#{gamecodeshort}/Hlocalhost/P%port%/K%key%" if $sf_fe_loc =~ /Wrayth/
        custom_launch = "Stormfront.exe /G#{gamecodeshort}/Hlocalhost/P%port%/K%key%" if $sf_fe_loc =~ /STORM/
      end
    end
    if custom_launch_dir = @launch_data.find { |opt| opt =~ /CUSTOMLAUNCHDIR=/ }
      custom_launch_dir.sub!(/^.*?\=/, '')
      Lich.log "info: using working directory for custom launch command: #{custom_launch_dir}"
    elsif (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
      Lich.log "info: Working against a Windows Platform for FE Location"
      if @launch_data.find { |opt| opt =~ /GAME=WIZ/ }
        custom_launch_dir = Lich.seek('wizard') # #HERE I AM
      elsif @launch_data.find { |opt| opt =~ /GAME=STORM/ }
        custom_launch_dir = Lich.seek('stormfront') # #HERE I AM
      end
      Lich.log "info: Current Windows working directory is #{custom_launch_dir}"
    elsif defined?(Wine)
      Lich.log "Info: Working against a Linux | WINE Platform for FE location"
      if @launch_data.find { |opt| opt =~ /GAME=WIZ/ }
        custom_launch_dir_temp = Lich.seek('wizard') # #HERE I AM
        custom_launch_dir = custom_launch_dir_temp.gsub('\\', '/').gsub('C:', Wine::PREFIX + '/drive_c')
      elsif @launch_data.find { |opt| opt =~ /GAME=STORM/ }
        custom_launch_dir_temp = Lich.seek('stormfront') # #HERE I AM
        custom_launch_dir = custom_launch_dir_temp.gsub('\\', '/').gsub('C:', Wine::PREFIX + '/drive_c')
      end
      Lich.log "info: Current WINE working directory is #{custom_launch_dir}"
    end
    if ARGV.include?('--without-frontend')
      $frontend = 'unknown'
      unless (game_key = @launch_data.find { |opt| opt =~ /KEY=/ }) && (game_key = game_key.split('=').last.chomp)
        $stdout.puts "error: launch_data contains no KEY info"
        Lich.log "error: launch_data contains no KEY info"
        exit(1)
      end
    elsif game =~ /SUKS/i
      $frontend = 'suks'
      unless (game_key = @launch_data.find { |opt| opt =~ /KEY=/ }) && (game_key = game_key.split('=').last.chomp)
        $stdout.puts "error: launch_data contains no KEY info"
        Lich.log "error: launch_data contains no KEY info"
        exit(1)
      end
    elsif game =~ /AVALON/i
      # Simu strikes again
      launcher_cmd = "open -n -b SimutronicsAvalon \"%1\""
    elsif custom_launch
      unless (game_key = @launch_data.find { |opt| opt =~ /KEY=/ }) && (game_key = game_key.split('=').last.chomp)
        $stdout.puts "error: launch_data contains no KEY info"
        Lich.log "error: launch_data contains no KEY info"
        exit(1)
      end
    else
      unless launcher_cmd = Lich.get_simu_launcher
        $stdout.puts 'error: failed to find the Simutronics launcher'
        Lich.log 'error: failed to find the Simutronics launcher'
        exit(1)
      end
    end
    gamecode = gamecode.split('=').last
    gameport = gameport.split('=').last
    gamehost = gamehost.split('=').last
    game     = game.split('=').last

    if (gameport == '10121') or (gameport == '10124')
      $platinum = true
    else
      $platinum = false
    end
    Lich.log "info: gamehost: #{gamehost}"
    Lich.log "info: gameport: #{gameport}"
    Lich.log "info: game: #{game}"
    if ARGV.include?('--without-frontend')
      $_CLIENT_ = nil
    elsif $frontend == 'suks'
      nil
    else
      if game =~ /WIZ/i
        $frontend = 'wizard'
      elsif game =~ /STORM/i
        $frontend = 'stormfront'
      elsif game =~ /AVALON/i
        $frontend = 'avalon'
      else
        $frontend = 'unknown'
      end
      begin
        listener = TCPServer.new('127.0.0.1', nil)
      rescue
        $stdout.puts "--- error: cannot bind listen socket to local port: #{$!}"
        Lich.log "error: cannot bind listen socket to local port: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        exit(1)
      end
      accept_thread = Thread.new { $_CLIENT_ = SynchronizedSocket.new(listener.accept) }
      localport = listener.addr[1]
      if custom_launch
        sal_filename = nil
        launcher_cmd = custom_launch.sub(/\%port\%/, localport.to_s).sub(/\%key\%/, game_key.to_s)
        scrubbed_launcher_cmd = custom_launch.sub(/\%port\%/, localport.to_s).sub(/\%key\%/, '[scrubbed key]')
        Lich.log "info: launcher_cmd: #{scrubbed_launcher_cmd}"
      else
        if RUBY_PLATFORM =~ /darwin/i
          localhost = "127.0.0.1"
        else
          localhost = "localhost"
        end
        @launch_data.collect! { |line| line.sub(/GAMEPORT=.+/, "GAMEPORT=#{localport}").sub(/GAMEHOST=.+/, "GAMEHOST=#{localhost}") }
        sal_filename = "#{TEMP_DIR}/lich#{rand(10000)}.sal"
        while File.exist?(sal_filename)
          sal_filename = "#{TEMP_DIR}/lich#{rand(10000)}.sal"
        end
        File.open(sal_filename, 'w') { |f| f.puts @launch_data }
        launcher_cmd = launcher_cmd.sub('%1', sal_filename)
        launcher_cmd = launcher_cmd.tr('/', "\\") if (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
      end
      begin
        if custom_launch_dir
          Dir.chdir(custom_launch_dir)
        end

        if defined?(Wine) and (game != 'AVALON') # Wine on linux
          spawn "#{Wine::BIN} #{launcher_cmd}"
        else # All other OS divert here for 3.2.1
          spawn launcher_cmd
        end
      rescue
        Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        Lich.msgbox(:message => "error: #{$!}", :icon => :error)
      end
      Lich.log 'info: waiting for client to connect...'
      300.times { sleep 0.1; break unless accept_thread.status }
      accept_thread.kill if accept_thread.status
      Dir.chdir(LICH_DIR)
      unless $_CLIENT_
        Lich.log "error: timeout waiting for client to connect"
        #        if defined?(Win32)
        #          Lich.msgbox(:message => "error: launch method #{method_num + 1} timed out waiting for the client to connect\n\nTry again and another method will be used.", :icon => :error)
        #        else
        Lich.msgbox(:message => "error: timeout waiting for client to connect", :icon => :error)
        #        end
        if sal_filename
          File.delete(sal_filename) rescue()
        end
        listener.close rescue()
        $_CLIENT_.close rescue()
        reconnect_if_wanted.call
        Lich.log "info: exiting..."
        Gtk.queue { Gtk.main_quit } if defined?(Gtk)
        exit
      end
      #      if defined?(Win32)
      #        Lich.win32_launch_method = "#{method_num}:success"
      #      end
      Lich.log 'info: connected'
      listener.close rescue nil
      if sal_filename
        File.delete(sal_filename) rescue nil
      end
    end
    gamehost, gameport = Lich.fix_game_host_port(gamehost, gameport)
    Lich.log "info: connecting to game server (#{gamehost}:#{gameport})"
    begin
      connect_thread = Thread.new {
        Game.open(gamehost, gameport)
      }
      300.times {
        sleep 0.1
        break unless connect_thread.status
      }
      if connect_thread.status
        connect_thread.kill rescue nil
        raise "error: timed out connecting to #{gamehost}:#{gameport}"
      end
    rescue
      Lich.log "error: #{$!}"
      gamehost, gameport = Lich.break_game_host_port(gamehost, gameport)
      Lich.log "info: connecting to game server (#{gamehost}:#{gameport})"
      begin
        connect_thread = Thread.new {
          Game.open(gamehost, gameport)
        }
        300.times {
          sleep 0.1
          break unless connect_thread.status
        }
        if connect_thread.status
          connect_thread.kill rescue nil
          raise "error: timed out connecting to #{gamehost}:#{gameport}"
        end
      rescue
        Lich.log "error: #{$!}"
        $_CLIENT_.close rescue nil
        reconnect_if_wanted.call
        Lich.log "info: exiting..."
        Gtk.queue { Gtk.main_quit } if defined?(Gtk)
        exit
      end
    end
    Lich.log 'info: connected'
  elsif game_host and game_port
    unless Lich.hosts_file
      Lich.log "error: cannot find hosts file"
      $stdout.puts "error: cannot find hosts file"
      exit
    end
    game_quad_ip = IPSocket.getaddress(game_host)
    error_count = 0
    begin
      listener = TCPServer.new('127.0.0.1', game_port)
      begin
        listener.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
      rescue
        Lich.log "warning: setsockopt with SO_REUSEADDR failed: #{$!}"
      end
    rescue
      sleep 1
      if (error_count += 1) >= 30
        $stdout.puts 'error: failed to bind to the proper port'
        Lich.log 'error: failed to bind to the proper port'
        exit!
      else
        retry
      end
    end
    Lich.modify_hosts(game_host)

    $stdout.puts "Pretending to be #{game_host}"
    $stdout.puts "Listening on port #{game_port}"
    $stdout.puts "Waiting for the client to connect..."
    Lich.log "info: pretending to be #{game_host}"
    Lich.log "info: listening on port #{game_port}"
    Lich.log "info: waiting for the client to connect..."

    timeout_thread = Thread.new {
      sleep 120
      listener.close rescue nil
      $stdout.puts 'error: timed out waiting for client to connect'
      Lich.log 'error: timed out waiting for client to connect'
      Lich.restore_hosts
      exit
    }
    #      $_CLIENT_ = listener.accept
    $_CLIENT_ = SynchronizedSocket.new(listener.accept)
    listener.close rescue nil
    timeout_thread.kill
    $stdout.puts "Connection with the local game client is open."
    Lich.log "info: connection with the game client is open"
    Lich.restore_hosts
    if test_mode
      $_SERVER_ = $stdin # fixme
      $_CLIENT_.puts "Running in test mode: host socket set to stdin."
    else
      Lich.log 'info: connecting to the real game host...'
      game_host, game_port = Lich.fix_game_host_port(game_host, game_port)
      begin
        timeout_thread = Thread.new {
          sleep 30
          Lich.log "error: timed out connecting to #{game_host}:#{game_port}"
          $stdout.puts "error: timed out connecting to #{game_host}:#{game_port}"
          exit
        }
        begin
          Game.open(game_host, game_port)
        rescue
          Lich.log "error: #{$!}"
          $stdout.puts "error: #{$!}"
          exit
        end
        timeout_thread.kill rescue nil
        Lich.log 'info: connection with the game host is open'
      end
    end
  else
    # offline mode removed
    Lich.log "error: don't know what to do"
    exit
  end

  listener = timeout_thr = nil

  # backward compatibility
  if $frontend =~ /^(?:wizard|avalon)$/
    $fake_stormfront = true
  else
    $fake_stormfront = false
  end

  undef :exit!

  if ARGV.include?('--without-frontend')
    Thread.new {
      client_thread = nil
      #
      # send the login key
      #
      Game._puts(game_key)
      game_key = nil
      #
      # send version string
      #
      client_string = "/FE:WIZARD /VERSION:1.0.1.22 /P:#{RUBY_PLATFORM} /XML"
      $_CLIENTBUFFER_.push(client_string.dup)
      Game._puts(client_string)
      #
      # tell the server we're ready
      #
      2.times {
        sleep 0.3
        $_CLIENTBUFFER_.push("<c>\r\n")
        Game._puts("<c>")
      }
      $login_time = Time.now
    }
  else
    #
    # shutdown listening socket
    #
    error_count = 0
    begin
      # Somehow... for some ridiculous reason... Windows doesn't let us close the socket if we shut it down first...
      # listener.shutdown
      listener.close unless listener.closed?
    rescue
      Lich.log "warning: failed to close listener socket: #{$!}"
      if (error_count += 1) > 20
        Lich.log 'warning: giving up...'
      else
        sleep 0.05
        retry
      end
    end

    $stdout = $_CLIENT_
    $_CLIENT_.sync = true

    client_thread = Thread.new {
      $login_time = Time.now

      if $offline_mode
        nil
      elsif $frontend =~ /^(?:wizard|avalon)$/
        #
        # send the login key
        #
        client_string = $_CLIENT_.gets
        Game._puts(client_string)
        #
        # take the version string from the client, ignore it, and ask the server for xml
        #
        $_CLIENT_.gets
        client_string = "/FE:STORMFRONT /VERSION:1.0.1.26 /P:#{RUBY_PLATFORM} /XML"
        $_CLIENTBUFFER_.push(client_string.dup)
        Game._puts(client_string)
        #
        # tell the server we're ready
        #
        2.times {
          sleep 0.3
          $_CLIENTBUFFER_.push("#{$cmd_prefix}\r\n")
          Game._puts($cmd_prefix)
        }
        #
        # set up some stuff
        #
        for client_string in ["#{$cmd_prefix}_injury 2", "#{$cmd_prefix}_flag Display Inventory Boxes 1", "#{$cmd_prefix}_flag Display Dialog Boxes 0"]
          $_CLIENTBUFFER_.push(client_string)
          Game._puts(client_string)
        end
        #
        # client wants to send "GOOD", xml server won't recognize it
        # Avalon requires 2 gets to clear
        2.times { $_CLIENT_.gets }
      elsif $frontend =~ /^(?:frostbite)$/
        #
        # send the login key
        #
        client_string = $_CLIENT_.gets
        client_string = fb_to_sf(client_string)
        Game._puts(client_string)
        #
        # take the version string from the client, ignore it, and ask the server for xml
        #
        $_CLIENT_.gets
        client_string = "/FE:STORMFRONT /VERSION:1.0.1.26 /P:#{RUBY_PLATFORM} /XML"
        $_CLIENTBUFFER_.push(client_string.dup)
        Game._puts(client_string)
        #
        # tell the server we're ready
        #
        2.times {
          sleep 0.3
          $_CLIENTBUFFER_.push("#{$cmd_prefix}\r\n")
          Game._puts($cmd_prefix)
        }
        #
        # set up some stuff
        #
        for client_string in [ "#{$cmd_prefix}_injury 2", "#{$cmd_prefix}_flag Display Inventory Boxes 1", "#{$cmd_prefix}_flag Display Dialog Boxes 0" ]
          $_CLIENTBUFFER_.push(client_string)
          Game._puts(client_string)
        end
      else
        inv_off_proc = proc { |server_string|
          if server_string =~ /^<(?:container|clearContainer|exposeContainer)/
            server_string.gsub!(/<(?:container|clearContainer|exposeContainer)[^>]*>|<inv.+\/inv>/, '')
            if server_string.empty?
              nil
            else
              server_string
            end
          elsif server_string =~ /^<flag id="Display Inventory Boxes" status='on' desc="Display all inventory and container windows."\/>/
            server_string.sub("status='on'", "status='off'")
          elsif server_string =~ /^\s*<d cmd="flag Inventory off">Inventory<\/d>\s+ON/
            server_string.sub("flag Inventory off", "flag Inventory on").sub('ON ', 'OFF')
          else
            server_string
          end
        }
        DownstreamHook.add('inventory_boxes_off', inv_off_proc)
        inv_toggle_proc = proc { |client_string|
          if client_string =~ /^(?:<c>)?_flag Display Inventory Boxes ([01])/
            if $1 == '1'
              DownstreamHook.remove('inventory_boxes_off')
              Lich.set_inventory_boxes(XMLData.player_id, true)
            else
              DownstreamHook.add('inventory_boxes_off', inv_off_proc)
              Lich.set_inventory_boxes(XMLData.player_id, false)
            end
            nil
          elsif client_string =~ /^(?:<c>)?\s*(?:set|flag)\s+inv(?:e|en|ent|ento|entor|entory)?\s+(on|off)/i
            if $1.downcase == 'on'
              DownstreamHook.remove('inventory_boxes_off')
              respond 'You have enabled viewing of inventory and container windows.'
              Lich.set_inventory_boxes(XMLData.player_id, true)
            else
              DownstreamHook.add('inventory_boxes_off', inv_off_proc)
              respond 'You have disabled viewing of inventory and container windows.'
              Lich.set_inventory_boxes(XMLData.player_id, false)
            end
            nil
          else
            client_string
          end
        }
        UpstreamHook.add('inventory_boxes_toggle', inv_toggle_proc)

        unless $offline_mode
          client_string = $_CLIENT_.gets
          Game._puts(client_string)
          client_string = $_CLIENT_.gets
          $_CLIENTBUFFER_.push(client_string.dup)
          Game._puts(client_string)
        end
      end

      begin
        while client_string = $_CLIENT_.gets
          if $frontend =~ /^(?:wizard|avalon)$/
            client_string = "#{$cmd_prefix}#{client_string}"
          elsif $frontend =~ /^(?:frostbite)$/
            client_string = fb_to_sf(client_string)
          end
          #Lich.log(client_string)
          begin
            $_IDLETIMESTAMP_ = Time.now
            do_client(client_string)
          rescue
            respond "--- Lich: error: client_thread: #{$!}"
            respond $!.backtrace.first
            Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          end
        end
      rescue
        respond "--- Lich: error: client_thread: #{$!}"
        respond $!.backtrace.first
        Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        sleep 0.2
        retry unless $_CLIENT_.closed? or Game.closed? or !Game.thread.alive? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed/i)
      end
      Game.close
    }
  end

  if detachable_client_port
    detachable_client_thread = Thread.new {
      loop {
        begin
          server = TCPServer.new('127.0.0.1', detachable_client_port)
          char_name = ARGV[ARGV.index('--login')+1].capitalize
          Frontend.create_session_file(char_name, server.addr[2], server.addr[1])

          $_DETACHABLE_CLIENT_ = SynchronizedSocket.new(server.accept)
          $_DETACHABLE_CLIENT_.sync = true
        rescue
          Lich.log "#{$!}\n\t#{$!.backtrace.join("\n\t")}"
          server.close rescue nil
          $_DETACHABLE_CLIENT_.close rescue nil
          $_DETACHABLE_CLIENT_ = nil
          sleep 5
          next
        ensure
          server.close rescue nil
          Frontend.cleanup_session_file
        end
        if $_DETACHABLE_CLIENT_
          begin
            unless ARGV.include?('--genie')
              $frontend = 'profanity'
              Thread.new {
                100.times { sleep 0.1; break if XMLData.indicator['IconJOINED'] }
                init_str = "<progressBar id='mana' value='0' text='mana #{XMLData.mana}/#{XMLData.max_mana}'/>"
                init_str.concat "<progressBar id='health' value='0' text='health #{XMLData.health}/#{XMLData.max_health}'/>"
                init_str.concat "<progressBar id='spirit' value='0' text='spirit #{XMLData.spirit}/#{XMLData.max_spirit}'/>"
                init_str.concat "<progressBar id='stamina' value='0' text='stamina #{XMLData.stamina}/#{XMLData.max_stamina}'/>"
                init_str.concat "<progressBar id='encumlevel' value='#{XMLData.encumbrance_value}' text='#{XMLData.encumbrance_text}'/>"
                init_str.concat "<progressBar id='pbarStance' value='#{XMLData.stance_value}'/>"
                init_str.concat "<progressBar id='mindState' value='#{XMLData.mind_value}' text='#{XMLData.mind_text}'/>"
                init_str.concat "<spell>#{XMLData.prepared_spell}</spell>"
                init_str.concat "<right>#{GameObj.right_hand.name}</right>"
                init_str.concat "<left>#{GameObj.left_hand.name}</left>"
                for indicator in ['IconBLEEDING', 'IconPOISONED', 'IconDISEASED', 'IconSTANDING', 'IconKNEELING', 'IconSITTING', 'IconPRONE']
                  init_str.concat "<indicator id='#{indicator}' visible='#{XMLData.indicator[indicator]}'/>"
                end
                for area in ['back', 'leftHand', 'rightHand', 'head', 'rightArm', 'abdomen', 'leftEye', 'leftArm', 'chest', 'rightLeg', 'neck', 'leftLeg', 'nsys', 'rightEye']
                  if Wounds.send(area) > 0
                    init_str.concat "<image id=\"#{area}\" name=\"Injury#{Wounds.send(area)}\"/>"
                  elsif Scars.send(area) > 0
                    init_str.concat "<image id=\"#{area}\" name=\"Scar#{Scars.send(area)}\"/>"
                  end
                end
                init_str.concat '<compass>'
                shorten_dir = { 'north' => 'n', 'northeast' => 'ne', 'east' => 'e', 'southeast' => 'se', 'south' => 's', 'southwest' => 'sw', 'west' => 'w', 'northwest' => 'nw', 'up' => 'up', 'down' => 'down', 'out' => 'out' }
                for dir in XMLData.room_exits
                  if short_dir = shorten_dir[dir]
                    init_str.concat "<dir value='#{short_dir}'/>"
                  end
                end
                init_str.concat '</compass>'
                $_DETACHABLE_CLIENT_.puts init_str
                init_str = nil
              }
            end
            while client_string = $_DETACHABLE_CLIENT_.gets
              client_string = "#{$cmd_prefix}#{client_string}" # if $frontend =~ /^(?:wizard|avalon)$/
              begin
                $_IDLETIMESTAMP_ = Time.now
                do_client(client_string)
              rescue
                respond "--- Lich: error: client_thread: #{$!}"
                respond $!.backtrace.first
                Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              end
            end
          rescue
            respond "--- Lich: error: client_thread: #{$!}"
            respond $!.backtrace.first
            Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $_DETACHABLE_CLIENT_.close rescue nil
            $_DETACHABLE_CLIENT_ = nil
          ensure
            $_DETACHABLE_CLIENT_.close rescue nil
            $_DETACHABLE_CLIENT_ = nil
          end
        end
        sleep 0.1
      }
    }
  else
    detachable_client_thread = nil
  end

  wait_while { $offline_mode }

  if $frontend == 'wizard'
    $link_highlight_start = "\207"
    $link_highlight_end = "\240"
    $speech_highlight_start = "\212"
    $speech_highlight_end = "\240"
  end

  client_thread.priority = 3

  $_CLIENT_.puts "\n--- Lich v#{LICH_VERSION} is active.  Type #{$clean_lich_char}help for usage info.\n\n"
  
  Game.thread.join
  client_thread.kill rescue nil
  detachable_client_thread.kill rescue nil

  Lich.log 'info: stopping scripts...'
  Script.running.each { |script| script.kill }
  Script.hidden.each { |script| script.kill }
  200.times { sleep 0.1; break if Script.running.empty? and Script.hidden.empty? }
  Lich.log 'info: saving script settings...'
  Infomon::Monitor.save_proc if defined?(Infomon::Monitor)
  Settings.save
  Vars.save
  Lich.log 'info: closing connections...'
  Game.close
  200.times { sleep 0.1; break if Game.closed? }
  pause 0.5
  $_CLIENT_.close
  200.times { sleep 0.1; break if $_CLIENT_.closed? }
  Lich.db.close
  200.times { sleep 0.1; break if Lich.db.closed? }
  reconnect_if_wanted.call
  Lich.log "info: exiting..."
  Gtk.queue { Gtk.main_quit } if defined?(Gtk)
  exit
}

if defined?(Gtk)
  Thread.current.priority = -10
  Gtk.main
else
  main_thread.join
end
exit

# Webhook Test No.2
