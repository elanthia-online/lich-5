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

# TODO: Move all local requires to top of file
require_relative('./lib/constants')
require 'lib/version'

require 'lib/lich'
require 'lib/init'

# TODO: Need to split out initiatilzation functions to move require to top of file
require 'lib/gtk'
require 'lib/gui-login'

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
  @@elevated_untaint = proc { |what| what.orig_untaint }
  alias :orig_untaint :untaint
  def untaint
    @@elevated_untaint.call(self)
  end

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
    @string.untaint
  end

  def kind_of?(type)
    Proc.new {}.kind_of? type
  end

  def class
    Proc
  end

  def call(*a)
    proc { begin; $SAFE = 3; rescue; nil; end; eval(@string) }.call
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
      begin
        server_string = @@downstream_hooks[key].call(server_string.dup)
      rescue
        @@downstream_hooks.delete(key)
        respond "--- Lich: DownstreamHook: #{$!}"
        respond $!.backtrace.first
      end
      return nil if server_string.nil?
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

#
# script bindings are convoluted, but don't change them without testing if:
#    class methods such as Script.start and ExecScript.start become accessible without specifying the class name (which is just a syptom of a problem that will break scripts)
#    local variables become shared between scripts
#    local variable 'file' is shared between scripts, even though other local variables aren't
#    defined methods are instantly inaccessible
# also, don't put 'untrusted' in the name of the untrusted binding; it shows up in error messages and makes people think the error is caused by not trusting the script
#
class Scripting
  def script
    Proc.new {}.binding
  end
end
def _script
  Proc.new {}.binding
end

TRUSTED_SCRIPT_BINDING = proc { _script }

class Script
  @@elevated_script_start = proc { |args|
    if args.empty?
      # fixme: error
      next nil
    elsif args[0].class == String
      script_name = args[0]
      if args[1]
        if args[1].class == String
          script_args = args[1]
          if args[2]
            if args[2].class == Hash
              options = args[2]
            else
              # fixme: error
              next nil
            end
          end
        elsif args[1].class == Hash
          options = args[1]
          script_args = (options[:args] || String.new)
        else
          # fixme: error
          next nil
        end
      else
        options = Hash.new
      end
    elsif args[0].class == Hash
      options = args[0]
      if options[:name]
        script_name = options[:name]
      else
        # fixme: error
        next nil
      end
      script_args = (options[:args] || String.new)
    end

    # fixme: look in wizard script directory
    # fixme: allow subdirectories?
    file_list = Dir.children(File.join(SCRIPT_DIR, "custom")).sort.map{ |s| s.prepend("/custom/") } + Dir.children(SCRIPT_DIR).sort
    if file_name = (file_list.find { |val| val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/ || val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i } || file_list.find { |val| val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}[^.]+\.(?i:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/ } || file_list.find { |val| val =~ /^(?:\/custom\/)?#{Regexp.escape(script_name)}[^.]+\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i })
      script_name = file_name.sub(/\..{1,3}$/, '')
    end
    file_list = nil
    if file_name.nil?
      respond "--- Lich: could not find script '#{script_name}' in directory #{SCRIPT_DIR} or #{SCRIPT_DIR}/custom"
      next nil
    end
    if (options[:force] != true) and (Script.running + Script.hidden).find { |s| s.name =~ /^#{Regexp.escape(script_name.sub('/custom/', ''))}$/i }
      respond "--- Lich: #{script_name} is already running (use #{$clean_lich_char}force [scriptname] if desired)."
      next nil
    end
    begin
      if file_name =~ /\.(?:cmd|wiz)(?:\.gz)?$/i
        trusted = false
        script_obj = WizardScript.new("#{SCRIPT_DIR}/#{file_name}", script_args)
      else
        if script_obj.labels.length > 1
          trusted = false
        elsif proc { begin; $SAFE = 3; true; rescue; false; end }.call
          begin
            trusted = Lich.db.get_first_value('SELECT name FROM trusted_scripts WHERE name=?;', script_name.encode('UTF-8'))
          rescue SQLite3::BusyException
            sleep 0.1
            retry
          end
        else
          trusted = true
        end
        script_obj = Script.new(:file => "#{SCRIPT_DIR}/#{file_name}", :args => script_args, :quiet => options[:quiet])
      end
      if trusted
        script_binding = TRUSTED_SCRIPT_BINDING.call
      else
        script_binding = Scripting.new.script
      end
    rescue
      respond "--- Lich: error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      next nil
    end
    unless script_obj
      respond "--- Lich: error: failed to start script (#{script_name})"
      next nil
    end
    script_obj.quiet = true if options[:quiet]
    new_thread = Thread.new {
      100.times { break if Script.current == script_obj; sleep 0.01 }

      if script = Script.current
        eval('script = Script.current', script_binding, script.name)
        Thread.current.priority = 1
        respond("--- Lich: #{script.name} active.") unless script.quiet
        if trusted
          begin
            eval(script.labels[script.current_label].to_s, script_binding, script.name)
          rescue SystemExit
            nil
          rescue SyntaxError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue ScriptError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue NoMemoryError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue LoadError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue SecurityError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue ThreadError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue SystemStackError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue Exception
            if $! == JUMP
              retry if Script.current.get_next_label != JUMP_ERROR
              respond "--- label error: `#{Script.current.jump_label}' was not found, and no `LabelError' label was found!"
              respond $!.backtrace.first
              Lich.log "label error: `#{Script.current.jump_label}' was not found, and no `LabelError' label was found!\n\t#{$!.backtrace.join("\n\t")}"
              Script.current.kill
            else
              respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
              Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            end
          rescue
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          ensure
            Script.current.kill
          end
        else
          begin
            while (script = Script.current) and script.current_label
              proc { foo = script.labels[script.current_label]; foo.untaint; begin; $SAFE = 3; rescue; nil; end; eval(foo, script_binding, script.name, 1) }.call
              Script.current.get_next_label
            end
          rescue SystemExit
            nil
          rescue SyntaxError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue ScriptError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue NoMemoryError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue LoadError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue SecurityError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            if name = Script.current.name
              respond "--- Lich: review this script (#{name}) to make sure it isn't malicious, and type #{$clean_lich_char}trust #{name}"
            end
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue ThreadError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue SystemStackError
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          rescue Exception
            if $! == JUMP
              retry if Script.current.get_next_label != JUMP_ERROR
              respond "--- label error: `#{Script.current.jump_label}' was not found, and no `LabelError' label was found!"
              respond $!.backtrace.first
              Lich.log "label error: `#{Script.current.jump_label}' was not found, and no `LabelError' label was found!\n\t#{$!.backtrace.join("\n\t")}"
              Script.current.kill
            else
              respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
              Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            end
          rescue
            respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          ensure
            Script.current.kill
          end
        end
      else
        respond '--- error: out of cheese'
      end
    }
    script_obj.thread_group.add(new_thread)
    script_obj
  }
  @@elevated_exists = proc { |script_name|
    if script_name =~ /\\|\//
      nil
    elsif script_name =~ /\.(?:lic|lich|rb|cmd|wiz)(?:\.gz)?$/i
      File.exists?("#{SCRIPT_DIR}/#{script_name}") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}")
    else
      File.exists?("#{SCRIPT_DIR}/#{script_name}.lic") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.lic") ||
      File.exists?("#{SCRIPT_DIR}/#{script_name}.lich") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.lich") ||
      File.exists?("#{SCRIPT_DIR}/#{script_name}.rb") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.rb") ||
      File.exists?("#{SCRIPT_DIR}/#{script_name}.cmd") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.cmd") ||
      File.exists?("#{SCRIPT_DIR}/#{script_name}.wiz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.wiz") ||
      File.exists?("#{SCRIPT_DIR}/#{script_name}.lic.gz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.lic.gz") ||
      File.exists?("#{SCRIPT_DIR}/#{script_name}.rb.gz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.rb.gz") ||
      File.exists?("#{SCRIPT_DIR}/#{script_name}.cmd.gz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.cmd.gz") ||
      File.exists?("#{SCRIPT_DIR}/#{script_name}.wiz.gz") || File.exists?("#{SCRIPT_DIR}/custom/#{script_name}.wiz.gz")
    end
  }
  @@elevated_log = proc { |data|
    if script = Script.current
      if script.name =~ /\\|\//
        nil
      else
        begin
          Dir.mkdir("#{LICH_DIR}/logs") unless File.exists?("#{LICH_DIR}/logs")
          File.open("#{LICH_DIR}/logs/#{script.name}.log", 'a') { |f| f.puts data }
          true
        rescue
          respond "--- Lich: error: Script.log: #{$!}"
          false
        end
      end
    else
      respond '--- error: Script.log: unable to identify calling script'
      false
    end
  }
  @@elevated_db = proc {
    if script = Script.current
      if script.name =~ /^lich$/i
        respond '--- error: Script.db cannot be used by a script named lich'
        nil
      elsif script.class == ExecScript
        respond '--- error: Script.db cannot be used by exec scripts'
        nil
      else
        SQLite3::Database.new("#{DATA_DIR}/#{script.name.gsub(/\/|\\/, '_')}.db3")
      end
    else
      respond '--- error: Script.db called by an unknown script'
      nil
    end
  }
  @@elevated_open_file = proc { |ext, mode, block|
    if script = Script.current
      if script.name =~ /^lich$/i
        respond '--- error: Script.open_file cannot be used by a script named lich'
        nil
      elsif script.name =~ /^entry$/i
        respond '--- error: Script.open_file cannot be used by a script named entry'
        nil
      elsif script.class == ExecScript
        respond '--- error: Script.open_file cannot be used by exec scripts'
        nil
      elsif ext.downcase == 'db3'
        SQLite3::Database.new("#{DATA_DIR}/#{script.name.gsub(/\/|\\/, '_')}.db3")
        # fixme: block gets elevated... why?
        #         elsif block
        #            File.open("#{DATA_DIR}/#{script.name.gsub(/\/|\\/, '_')}.#{ext.gsub(/\/|\\/, '_')}", mode, &block)
      else
        File.open("#{DATA_DIR}/#{script.name.gsub(/\/|\\/, '_')}.#{ext.gsub(/\/|\\/, '_')}", mode)
      end
    else
      respond '--- error: Script.open_file called by an unknown script'
      nil
    end
  }
  @@running = Array.new

  attr_reader :name, :vars, :safe, :file_name, :label_order, :at_exit_procs
  attr_accessor :quiet, :no_echo, :jump_label, :current_label, :want_downstream, :want_downstream_xml, :want_upstream, :want_script_output, :hidden, :paused, :silent, :no_pause_all, :no_kill_all, :downstream_buffer, :upstream_buffer, :unique_buffer, :die_with, :match_stack_labels, :match_stack_strings, :watchfor, :command_line, :ignore_pause

  def Script.version(script_name, script_version_required = nil)
    script_name = script_name.sub(/[.](lic|rb|cmd|wiz)$/, '')
    file_list = Dir.entries(SCRIPT_DIR).delete_if { |fn| (fn == '.') or (fn == '..') }
    file_list = file_list.sort_by { |fn| fn.sub(/[.](lic|rb|cmd|wiz)$/, '') }
    if file_name = (file_list.find { |val| val =~ /^#{Regexp.escape(script_name)}\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/ || val =~ /^#{Regexp.escape(script_name)}\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i } || file_list.find { |val| val =~ /^#{Regexp.escape(script_name)}[^.]+\.(?i:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/ } || file_list.find { |val| val =~ /^#{Regexp.escape(script_name)}[^.]+\.(?:lic|rb|cmd|wiz)(?:\.gz|\.Z)?$/i })
      script_name = file_name.sub(/\..{1,3}$/, '')
    end
    file_list = nil
    if file_name.nil?
      respond "--- Lich: could not find script '#{script_name}' in directory #{SCRIPT_DIR}"
      return nil
    end
   
    script_version = '0.0.0'
    script_data = open("#{SCRIPT_DIR}/#{file_name}", 'r').read
    if script_data =~ /^=begin\r?\n?(.+?)^=end/m
      comments = $1.split("\n")
    else
      comments = []
      script_data.split("\n").each {|line|
        if line =~ /^[\t\s]*#/
          comments.push(line)
        elsif line !~ /^[\t\s]*$/
          break
        end
      }
    end
    for line in comments
      if line =~ /^[\s\t#]*version:[\s\t]*([\w,\s\.\d]+)/i
        script_version = $1.sub(/\s\(.*?\)/, '').strip
      end
    end
    if script_version_required
      Gem::Version.new(script_version) < Gem::Version.new(script_version_required)
    else
      Gem::Version.new(script_version)
    end
  end
    
  def Script.list
    @@running.dup
  end

  def Script.current
    if script = @@running.find { |s| s.has_thread?(Thread.current) }
      sleep 0.2 while script.paused? and not script.ignore_pause
      script
    else
      nil
    end
  end

  def Script.start(*args)
    @@elevated_script_start.call(args)
  end

  def Script.run(*args)
    if s = @@elevated_script_start.call(args)
      sleep 0.1 while @@running.include?(s)
    end
  end

  def Script.running?(name)
    @@running.any? { |i| (i.name =~ /^#{name}$/i) }
  end

  def Script.pause(name = nil)
    if name.nil?
      Script.current.pause
      Script.current
    else
      if s = (@@running.find { |i| (i.name == name) and not i.paused? }) || (@@running.find { |i| (i.name =~ /^#{name}$/i) and not i.paused? })
        s.pause
        true
      else
        false
      end
    end
  end

  def Script.unpause(name)
    if s = (@@running.find { |i| (i.name == name) and i.paused? }) || (@@running.find { |i| (i.name =~ /^#{name}$/i) and i.paused? })
      s.unpause
      true
    else
      false
    end
  end

  def Script.kill(name)
    if s = (@@running.find { |i| i.name == name }) || (@@running.find { |i| i.name =~ /^#{name}$/i })
      s.kill
      true
    else
      false
    end
  end

  def Script.paused?(name)
    if s = (@@running.find { |i| i.name == name }) || (@@running.find { |i| i.name =~ /^#{name}$/i })
      s.paused?
    else
      nil
    end
  end

  def Script.exists?(script_name)
    @@elevated_exists.call(script_name)
  end

  def Script.new_downstream_xml(line)
    for script in @@running
      script.downstream_buffer.push(line.chomp) if script.want_downstream_xml
    end
  end

  def Script.new_upstream(line)
    for script in @@running
      script.upstream_buffer.push(line.chomp) if script.want_upstream
    end
  end

  def Script.new_downstream(line)
    @@running.each { |script|
      script.downstream_buffer.push(line.chomp) if script.want_downstream
      unless script.watchfor.empty?
        script.watchfor.each_pair { |trigger, action|
          if line =~ trigger
            new_thread = Thread.new {
              sleep 0.011 until Script.current
              begin
                action.call
              rescue
                echo "watchfor error: #{$!}"
              end
            }
            script.thread_group.add(new_thread)
          end
        }
      end
    }
  end

  def Script.new_script_output(line)
    for script in @@running
      script.downstream_buffer.push(line.chomp) if script.want_script_output
    end
  end

  def Script.log(data)
    @@elevated_log.call(data)
  end

  def Script.db
    @@elevated_db.call
  end

  def Script.open_file(ext, mode = 'r', &block)
    @@elevated_open_file.call(ext, mode, block)
  end

  def Script.at_exit(&block)
    if script = Script.current
      script.at_exit(&block)
    else
      respond "--- Lich: error: Script.at_exit: can't identify calling script"
      return false
    end
  end

  def Script.clear_exit_procs
    if script = Script.current
      script.clear_exit_procs
    else
      respond "--- Lich: error: Script.clear_exit_procs: can't identify calling script"
      return false
    end
  end

  def Script.exit!
    if script = Script.current
      script.exit!
    else
      respond "--- Lich: error: Script.exit!: can't identify calling script"
      return false
    end
  end
  if (RUBY_VERSION =~ /^2\.[012]\./)
    def Script.trust(script_name)
      # fixme: case sensitive blah blah
      if ($SAFE == 0) and not caller.any? { |c| c =~ /eval|run/ }
        begin
          Lich.db.execute('INSERT OR REPLACE INTO trusted_scripts(name) values(?);', script_name.encode('UTF-8'))
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
        true
      else
        respond '--- error: scripts may not trust scripts'
        false
      end
    end

    def Script.distrust(script_name)
      begin
        there = Lich.db.get_first_value('SELECT name FROM trusted_scripts WHERE name=?;', script_name.encode('UTF-8'))
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
      if there
        begin
          Lich.db.execute('DELETE FROM trusted_scripts WHERE name=?;', script_name.encode('UTF-8'))
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
        true
      else
        false
      end
    end

    def Script.list_trusted
      list = Array.new
      begin
        Lich.db.execute('SELECT name FROM trusted_scripts;').each { |name| list.push(name[0]) }
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
      list
    end
  else
    def Script.trust(script_name)
      true
    end

    def Script.distrust(script_name)
      false
    end

    def Script.list_trusted
      []
    end
  end
  def initialize(args)
    @file_name = args[:file]
    @name = /.*[\/\\]+([^\.]+)\./.match(@file_name).captures.first
    if args[:args].class == String
      if args[:args].empty?
        @vars = Array.new
      else
        @vars = [args[:args]]
        @vars.concat args[:args].scan(/[^\s"]*(?<!\\)"(?:\\"|[^"])+(?<!\\)"[^\s]*|(?:\\"|[^"\s])+/).collect { |s| s.gsub(/(?<!\\)"/, '').gsub('\\"', '"') }
      end
    elsif args[:args].class == Array
      @vars = [ args[:args].join(" ") ]
      @vars.concat args[:args]
    else
      @vars = Array.new
    end
    @quiet = (args[:quiet] ? true : false)
    @downstream_buffer = LimitedArray.new
    @want_downstream = true
    @want_downstream_xml = false
    @want_script_output = false
    @upstream_buffer = LimitedArray.new
    @want_upstream = false
    @unique_buffer = LimitedArray.new
    @watchfor = Hash.new
    @at_exit_procs = Array.new
    @die_with = Array.new
    @paused = false
    @hidden = false
    @no_pause_all = false
    @no_kill_all = false
    @silent = false
    @safe = false
    @no_echo = false
    @match_stack_labels = Array.new
    @match_stack_strings = Array.new
    @label_order = Array.new
    @labels = Hash.new
    @killer_mutex = Mutex.new
    @ignore_pause = false
    data = nil
    if @file_name =~ /\.gz$/i
      begin
        Zlib::GzipReader.open(@file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
      rescue
        respond "--- Lich: error reading script file (#{@file_name}): #{$!}"
        return nil
      end
    else
      begin
        File.open(@file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
      rescue
        respond "--- Lich: error reading script file (#{@file_name}): #{$!}"
        return nil
      end
    end
    @quiet = true if data[0] =~ /^[\t\s]*#?[\t\s]*(?:quiet|hush)$/i
    @current_label = '~start'
    @labels[@current_label] = String.new
    @label_order.push(@current_label)
    for line in data
      if line =~ /^([\d_\w]+):$/
        @current_label = $1
        @label_order.push(@current_label)
        @labels[@current_label] = String.new
      else
        @labels[@current_label].concat "#{line}\n"
      end
    end
    data = nil
    @current_label = @label_order[0]
    @thread_group = ThreadGroup.new
    @@running.push(self)
    return self
  end

  def kill
    Thread.new {
      @killer_mutex.synchronize {
        if @@running.include?(self)
          begin
            @thread_group.list.dup.each { |t|
              unless t == Thread.current
                t.kill rescue nil
              end
            }
            @thread_group.add(Thread.current)
            @die_with.each { |script_name| Script.kill(script_name) }
            @paused = false
            @at_exit_procs.each { |p| report_errors { p.call } }
            @die_with = @at_exit_procs = @downstream_buffer = @upstream_buffer = @match_stack_labels = @match_stack_strings = nil
            @@running.delete(self)
            respond("--- Lich: #{@name} has exited.") unless @quiet
            GC.start
          rescue
            respond "--- Lich: error: #{$!}"
            Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          end
        end
      }
    }
    @name
  end

  def at_exit(&block)
    if block
      @at_exit_procs.push(block)
      return true
    else
      respond '--- warning: Script.at_exit called with no code block'
      return false
    end
  end

  def clear_exit_procs
    @at_exit_procs.clear
    true
  end

  def exit
    kill
  end

  def exit!
    @at_exit_procs.clear
    kill
  end

  def instance_variable_get(*a); nil; end

  def instance_eval(*a);         nil; end

  def labels
    ($SAFE == 0) ? @labels : nil
  end

  def thread_group
    ($SAFE == 0) ? @thread_group : nil
  end

  def has_thread?(t)
    @thread_group.list.include?(t)
  end

  def pause
    respond "--- Lich: #{@name} paused."
    @paused = true
  end

  def unpause
    respond "--- Lich: #{@name} unpaused."
    @paused = false
  end

  def paused?
    @paused
  end

  def get_next_label
    if !@jump_label
      @current_label = @label_order[@label_order.index(@current_label) + 1]
    else
      if label = @labels.keys.find { |val| val =~ /^#{@jump_label}$/ }
        @current_label = label
      elsif label = @labels.keys.find { |val| val =~ /^#{@jump_label}$/i }
        @current_label = label
      elsif label = @labels.keys.find { |val| val =~ /^labelerror$/i }
        @current_label = label
      else
        @current_label = nil
        return JUMP_ERROR
      end
      @jump_label = nil
      @current_label
    end
  end

  def clear
    to_return = @downstream_buffer.dup
    @downstream_buffer.clear
    to_return
  end

  def to_s
    @name
  end

  def gets
    # fixme: no xml gets
    if @want_downstream or @want_downstream_xml or @want_script_output
      sleep 0.05 while @downstream_buffer.empty?
      @downstream_buffer.shift
    else
      echo 'this script is set as unique but is waiting for game data...'
      sleep 2
      false
    end
  end

  def gets?
    if @want_downstream or @want_downstream_xml or @want_script_output
      if @downstream_buffer.empty?
        nil
      else
        @downstream_buffer.shift
      end
    else
      echo 'this script is set as unique but is waiting for game data...'
      sleep 2
      false
    end
  end

  def upstream_gets
    sleep 0.05 while @upstream_buffer.empty?
    @upstream_buffer.shift
  end

  def upstream_gets?
    if @upstream_buffer.empty?
      nil
    else
      @upstream_buffer.shift
    end
  end

  def unique_gets
    sleep 0.05 while @unique_buffer.empty?
    @unique_buffer.shift
  end

  def unique_gets?
    if @unique_buffer.empty?
      nil
    else
      @unique_buffer.shift
    end
  end

  def safe?
    @safe
  end

  def feedme_upstream
    @want_upstream = !@want_upstream
  end

  def match_stack_add(label, string)
    @match_stack_labels.push(label)
    @match_stack_strings.push(string)
  end

  def match_stack_clear
    @match_stack_labels.clear
    @match_stack_strings.clear
  end
end

class ExecScript < Script
  @@name_exec_mutex = Mutex.new
  @@elevated_start = proc { |cmd_data, options|
    options[:trusted] = false
    unless new_script = ExecScript.new(cmd_data, options)
      respond '--- Lich: failed to start exec script'
      return false
    end
    new_thread = Thread.new {
      100.times { break if Script.current == new_script; sleep 0.01 }

      if script = Script.current
        Thread.current.priority = 1
        respond("--- Lich: #{script.name} active.") unless script.quiet
        begin
          script_binding = Scripting.new.script
          eval('script = Script.current', script_binding, script.name.to_s)
          proc { cmd_data.untaint; $SAFE = 3; eval(cmd_data, script_binding, script.name.to_s) }.call
          Script.current.kill
        rescue SystemExit
          Script.current.kill
        rescue SyntaxError
          respond "--- SyntaxError: #{$!}"
          respond $!.backtrace.first
          Lich.log "SyntaxError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue ScriptError
          respond "--- ScriptError: #{$!}"
          respond $!.backtrace.first
          Lich.log "ScriptError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue NoMemoryError
          respond "--- NoMemoryError: #{$!}"
          respond $!.backtrace.first
          Lich.log "NoMemoryError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue LoadError
          respond("--- LoadError: #{$!}")
          respond "--- LoadError: #{$!}"
          respond $!.backtrace.first
          Lich.log "LoadError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue SecurityError
          respond "--- SecurityError: #{$!}"
          respond $!.backtrace[0..1]
          Lich.log "SecurityError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue ThreadError
          respond "--- ThreadError: #{$!}"
          respond $!.backtrace.first
          Lich.log "ThreadError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue SystemStackError
          respond "--- SystemStackError: #{$!}"
          respond $!.backtrace.first
          Lich.log "SystemStackError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue Exception
          respond "--- Exception: #{$!}"
          respond $!.backtrace.first
          Lich.log "Exception: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        rescue
          respond "--- Lich: error: #{$!}"
          respond $!.backtrace.first
          Lich.log "Error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Script.current.kill
        end
      else
        respond '--- Lich: error: ExecScript.start: out of cheese'
      end
    }
    new_script.thread_group.add(new_thread)
    new_script
  }
  attr_reader :cmd_data

  def ExecScript.start(cmd_data, options = {})
    options = { :quiet => true } if options == true
    if ($SAFE < 2) and (options[:trusted] or (RUBY_VERSION !~ /^2\.[012]\./))
      unless new_script = ExecScript.new(cmd_data, options)
        respond '--- Lich: failed to start exec script'
        return false
      end
      new_thread = Thread.new {
        100.times { break if Script.current == new_script; sleep 0.01 }

        if script = Script.current
          Thread.current.priority = 1
          respond("--- Lich: #{script.name} active.") unless script.quiet
          begin
            script_binding = TRUSTED_SCRIPT_BINDING.call
            eval('script = Script.current', script_binding, script.name.to_s)
            eval(cmd_data, script_binding, script.name.to_s)
            Script.current.kill
          rescue SystemExit
            Script.current.kill
          rescue SyntaxError
            respond "--- SyntaxError: #{$!}"
            respond $!.backtrace.first
            Lich.log "SyntaxError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue ScriptError
            respond "--- ScriptError: #{$!}"
            respond $!.backtrace.first
            Lich.log "ScriptError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue NoMemoryError
            respond "--- NoMemoryError: #{$!}"
            respond $!.backtrace.first
            Lich.log "NoMemoryError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue LoadError
            respond("--- LoadError: #{$!}")
            respond "--- LoadError: #{$!}"
            respond $!.backtrace.first
            Lich.log "LoadError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue SecurityError
            respond "--- SecurityError: #{$!}"
            respond $!.backtrace[0..1]
            Lich.log "SecurityError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue ThreadError
            respond "--- ThreadError: #{$!}"
            respond $!.backtrace.first
            Lich.log "ThreadError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue SystemStackError
            respond "--- SystemStackError: #{$!}"
            respond $!.backtrace.first
            Lich.log "SystemStackError: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue Exception
            respond "--- Exception: #{$!}"
            respond $!.backtrace.first
            Lich.log "Exception: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          rescue
            respond "--- Lich: error: #{$!}"
            respond $!.backtrace.first
            Lich.log "Error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Script.current.kill
          end
        else
          respond 'start_exec_script screwed up...'
        end
      }
      new_script.thread_group.add(new_thread)
      new_script
    else
      @@elevated_start.call(cmd_data, options)
    end
  end

  def initialize(cmd_data, flags = Hash.new)
    @cmd_data = cmd_data
    @vars = Array.new
    @downstream_buffer = LimitedArray.new
    @killer_mutex = Mutex.new
    @want_downstream = true
    @want_downstream_xml = false
    @upstream_buffer = LimitedArray.new
    @want_upstream = false
    @at_exit_procs = Array.new
    @watchfor = Hash.new
    @hidden = false
    @paused = false
    @silent = false
    if flags[:quiet].nil?
      @quiet = false
    else
      @quiet = flags[:quiet]
    end
    @safe = false
    @no_echo = false
    @thread_group = ThreadGroup.new
    @unique_buffer = LimitedArray.new
    @die_with = Array.new
    @no_pause_all = false
    @no_kill_all = false
    @match_stack_labels = Array.new
    @match_stack_strings = Array.new
    num = '1'; num.succ! while @@running.any? { |s| s.name == "exec#{num}" }
    @name = "exec#{num}"
    @@running.push(self)
    self
  end

  def get_next_label
    echo 'goto labels are not available in exec scripts.'
    nil
  end
end

class WizardScript < Script
  def initialize(file_name, cli_vars = [])
    @name = /.*[\/\\]+([^\.]+)\./.match(file_name).captures.first
    @file_name = file_name
    @vars = Array.new
    @killer_mutex = Mutex.new
    unless cli_vars.empty?
      if cli_vars.is_a?(String)
        cli_vars = cli_vars.split(' ')
      end
      cli_vars.each_index { |idx| @vars[idx + 1] = cli_vars[idx] }
      @vars[0] = @vars[1..-1].join(' ')
      cli_vars = nil
    end
    if @vars.first =~ /^quiet$/i
      @quiet = true
      @vars.shift
    else
      @quiet = false
    end
    @downstream_buffer = LimitedArray.new
    @want_downstream = true
    @want_downstream_xml = false
    @upstream_buffer = LimitedArray.new
    @want_upstream = false
    @unique_buffer = LimitedArray.new
    @at_exit_procs = Array.new
    @patchfor = Hash.new
    @die_with = Array.new
    @paused = false
    @hidden = false
    @no_pause_all = false
    @no_kill_all = false
    @silent = false
    @safe = false
    @no_echo = false
    @match_stack_labels = Array.new
    @match_stack_strings = Array.new
    @label_order = Array.new
    @labels = Hash.new
    data = nil
    begin
      Zlib::GzipReader.open(file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
    rescue
      begin
        File.open(file_name) { |f| data = f.readlines.collect { |line| line.chomp } }
      rescue
        respond "--- Lich: error reading script file (#{file_name}): #{$!}"
        return nil
      end
    end
    @quiet = true if data[0] =~ /^[\t\s]*#?[\t\s]*(?:quiet|hush)$/i

    counter_action = {
      'add' => '+',
      'sub' => '-',
      'subtract' => '-',
      'multiply' => '*',
      'divide' => '/',
      'set' => ''
    }

    setvars = Array.new
    data.each { |line| setvars.push($1) if line =~ /[\s\t]*setvariable\s+([^\s\t]+)[\s\t]/i and not setvars.include?($1) }
    has_counter = data.find { |line| line =~ /%c/i }
    has_save = data.find { |line| line =~ /%s/i }
    has_nextroom = data.find { |line| line =~ /nextroom/i }

    fixstring = proc { |str|
      while not setvars.empty? and str =~ /%(#{setvars.join('|')})%/io
        str.gsub!('%' + $1 + '%', '#{' + $1.downcase + '}')
      end
      str.gsub!(/%c(?:%)?/i, '#{c}')
      str.gsub!(/%s(?:%)?/i, '#{sav}')
      while str =~ /%([0-9])(?:%)?/
        str.gsub!(/%#{$1}(?:%)?/, '#{script.vars[' + $1 + ']}')
      end
      str
    }

    fixline = proc { |line|
      if line =~ /^[\s\t]*[A-Za-z0-9_\-']+:/i
        line = line.downcase.strip
      elsif line =~ /^([\s\t]*)counter\s+(add|sub|subtract|divide|multiply|set)\s+([0-9]+)/i
        line = "#{$1}c #{counter_action[$2]}= #{$3}"
      elsif line =~ /^([\s\t]*)counter\s+(add|sub|subtract|divide|multiply|set)\s+(.*)/i
        indent, action, arg = $1, $2, $3
        line = "#{indent}c #{counter_action[action]}= #{fixstring.call(arg.inspect)}.to_i"
      elsif line =~ /^([\s\t]*)save[\s\t]+"?(.*?)"?[\s\t]*$/i
        indent, arg = $1, $2
        line = "#{indent}sav = #{fixstring.call(arg.inspect)}"
      elsif line =~ /^([\s\t]*)echo[\s\t]+(.+)/i
        indent, arg = $1, $2
        line = "#{indent}echo #{fixstring.call(arg.inspect)}"
      elsif line =~ /^([\s\t]*)waitfor[\s\t]+(.+)/i
        indent, arg = $1, $2
        line = "#{indent}waitfor #{fixstring.call(Regexp.escape(arg).inspect.gsub("\\\\ ", ' '))}"
      elsif line =~ /^([\s\t]*)put[\s\t]+\.(.+)$/i
        indent, arg = $1, $2
        if arg.include?(' ')
          line = "#{indent}start_script(#{Regexp.escape(fixstring.call(arg.split[0].inspect))}, #{fixstring.call(arg.split[1..-1].join(' ').scan(/"[^"]+"|[^"\s]+/).inspect)})\n#{indent}exit"
        else
          line = "#{indent}start_script(#{Regexp.escape(fixstring.call(arg.inspect))})\n#{indent}exit"
        end
      elsif line =~ /^([\s\t]*)put[\s\t]+;(.+)$/i
        indent, arg = $1, $2
        if arg.include?(' ')
          line = "#{indent}start_script(#{Regexp.escape(fixstring.call(arg.split[0].inspect))}, #{fixstring.call(arg.split[1..-1].join(' ').scan(/"[^"]+"|[^"\s]+/).inspect)})"
        else
          line = "#{indent}start_script(#{Regexp.escape(fixstring.call(arg.inspect))})"
        end
      elsif line =~ /^([\s\t]*)(put|move)[\s\t]+(.+)/i
        indent, cmd, arg = $1, $2, $3
        line = "#{indent}waitrt?\n#{indent}clear\n#{indent}#{cmd.downcase} #{fixstring.call(arg.inspect)}"
      elsif line =~ /^([\s\t]*)goto[\s\t]+(.+)/i
        indent, arg = $1, $2
        line = "#{indent}goto #{fixstring.call(arg.inspect).downcase}"
      elsif line =~ /^([\s\t]*)waitforre[\s\t]+(.+)/i
        indent, arg = $1, $2
        line = "#{indent}waitforre #{arg}"
      elsif line =~ /^([\s\t]*)pause[\s\t]*(.*)/i
        indent, arg = $1, $2
        arg = '1' if arg.empty?
        arg = '0' + arg.strip if arg.strip =~ /^\.[0-9]+$/
        line = "#{indent}pause #{arg}"
      elsif line =~ /^([\s\t]*)match[\s\t]+([^\s\t]+)[\s\t]+(.+)/i
        indent, label, arg = $1, $2, $3
        line = "#{indent}match #{fixstring.call(label.inspect).downcase}, #{fixstring.call(Regexp.escape(arg).inspect.gsub("\\\\ ", ' '))}"
      elsif line =~ /^([\s\t]*)matchre[\s\t]+([^\s\t]+)[\s\t]+(.+)/i
        indent, label, regex = $1, $2, $3
        line = "#{indent}matchre #{fixstring.call(label.inspect).downcase}, #{regex}"
      elsif line =~ /^([\s\t]*)setvariable[\s\t]+([^\s\t]+)[\s\t]+(.+)/i
        indent, var, arg = $1, $2, $3
        line = "#{indent}#{var.downcase} = #{fixstring.call(arg.inspect)}"
      elsif line =~ /^([\s\t]*)deletevariable[\s\t]+(.+)/i
        line = "#{$1}#{$2.downcase} = nil"
      elsif line =~ /^([\s\t]*)(wait|nextroom|exit|echo)\b/i
        line = "#{$1}#{$2.downcase}"
      elsif line =~ /^([\s\t]*)matchwait\b/i
        line = "#{$1}matchwait"
      elsif line =~ /^([\s\t]*)if_([0-9])[\s\t]+(.*)/i
        indent, num, stuff = $1, $2, $3
        line = "#{indent}if script.vars[#{num}]\n#{indent}\t#{fixline.call($3)}\n#{indent}end"
      elsif line =~ /^([\s\t]*)shift\b/i
        line = "#{$1}script.vars.shift"
      else
        respond "--- Lich: unknown line: #{line}"
        line = '#' + line
      end
    }

    lich_block = false

    data.each_index { |idx|
      if lich_block
        if data[idx] =~ /\}[\s\t]*LICH[\s\t]*$/
          data[idx] = data[idx].sub(/\}[\s\t]*LICH[\s\t]*$/, '')
          lich_block = false
        else
          next
        end
      elsif data[idx] =~ /^[\s\t]*#|^[\s\t]*$/
        next
      elsif data[idx] =~ /^[\s\t]*LICH[\s\t]*\{/
        data[idx] = data[idx].sub(/LICH[\s\t]*\{/, '')
        if data[idx] =~ /\}[\s\t]*LICH[\s\t]*$/
          data[idx] = data[idx].sub(/\}[\s\t]*LICH[\s\t]*$/, '')
        else
          lich_block = true
        end
      else
        data[idx] = fixline.call(data[idx])
      end
    }

    if has_counter or has_save or has_nextroom
      data.each_index { |idx|
        next if data[idx] =~ /^[\s\t]*#/

        data.insert(idx, '')
        data.insert(idx, 'c = 0') if has_counter
        data.insert(idx, "sav = Settings['sav'] || String.new\nbefore_dying { Settings['sav'] = sav }") if has_save
        data.insert(idx, "def nextroom\n\troom_count = XMLData.room_count\n\twait_while { room_count == XMLData.room_count }\nend") if has_nextroom
        data.insert(idx, '')
        break
      }
    end

    @current_label = '~start'
    @labels[@current_label] = String.new
    @label_order.push(@current_label)
    for line in data
      if line =~ /^([\d_\w]+):$/
        @current_label = $1
        @label_order.push(@current_label)
        @labels[@current_label] = String.new
      else
        @labels[@current_label] += "#{line}\n"
      end
    end
    data = nil
    @current_label = @label_order[0]
    @thread_group = ThreadGroup.new
    @@running.push(self)
    return self
  end
end

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

require_relative("./lib/map.rb")

## adding util to the list of defs

require_relative("./lib/util.rb")

def hide_me
  Script.current.hidden = !Script.current.hidden
end

def no_kill_all
  script = Script.current
  script.no_kill_all = !script.no_kill_all
end

def no_pause_all
  script = Script.current
  script.no_pause_all = !script.no_pause_all
end

def toggle_upstream
  unless script = Script.current then echo 'toggle_upstream: cannot identify calling script.'; return nil; end
  script.want_upstream = !script.want_upstream
end

def silence_me
  unless script = Script.current then echo 'silence_me: cannot identify calling script.'; return nil; end
  if script.safe? then echo("WARNING: 'safe' script attempted to silence itself.  Ignoring the request.")
                       sleep 1
                       return true
  end
  script.silent = !script.silent
end

def toggle_echo
  unless script = Script.current then respond('--- toggle_echo: Unable to identify calling script.'); return nil; end
  script.no_echo = !script.no_echo
end

def echo_on
  unless script = Script.current then respond('--- echo_on: Unable to identify calling script.'); return nil; end
  script.no_echo = false
end

def echo_off
  unless script = Script.current then respond('--- echo_off: Unable to identify calling script.'); return nil; end
  script.no_echo = true
end

def upstream_get
  unless script = Script.current then echo 'upstream_get: cannot identify calling script.'; return nil; end
  unless script.want_upstream
    echo("This script wants to listen to the upstream, but it isn't set as receiving the upstream! This will cause a permanent hang, aborting (ask for the upstream with 'toggle_upstream' in the script)")
    sleep 0.3
    return false
  end
  script.upstream_gets
end

def upstream_get?
  unless script = Script.current then echo 'upstream_get: cannot identify calling script.'; return nil; end
  unless script.want_upstream
    echo("This script wants to listen to the upstream, but it isn't set as receiving the upstream! This will cause a permanent hang, aborting (ask for the upstream with 'toggle_upstream' in the script)")
    return false
  end
  script.upstream_gets?
end

def echo(*messages)
  respond if messages.empty?
  if script = Script.current
    unless script.no_echo
      messages.each { |message| respond("[#{script.name}: #{message.to_s.chomp}]") }
    end
  else
    messages.each { |message| respond("[(unknown script): #{message.to_s.chomp}]") }
  end
  nil
end

def _echo(*messages)
  _respond if messages.empty?
  if script = Script.current
    unless script.no_echo
      messages.each { |message| _respond("[#{script.name}: #{message.to_s.chomp}]") }
    end
  else
    messages.each { |message| _respond("[(unknown script): #{message.to_s.chomp}]") }
  end
  nil
end

def goto(label)
  Script.current.jump_label = label.to_s
  raise JUMP
end

def pause_script(*names)
  names.flatten!
  if names.empty?
    Script.current.pause
    Script.current
  else
    names.each { |scr|
      fnd = Script.list.find { |nm| nm.name =~ /^#{scr}/i }
      fnd.pause unless (fnd.paused || fnd.nil?)
    }
  end
end

def unpause_script(*names)
  names.flatten!
  names.each { |scr|
    fnd = Script.list.find { |nm| nm.name =~ /^#{scr}/i }
    fnd.unpause if (fnd.paused and not fnd.nil?)
  }
end

def fix_injury_mode
  unless XMLData.injury_mode == 2
    Game._puts '_injury 2'
    150.times { sleep 0.05; break if XMLData.injury_mode == 2 }
  end
end

def hide_script(*args)
  args.flatten!
  args.each { |name|
    if script = Script.running.find { |scr| scr.name == name }
      script.hidden = !script.hidden
    end
  }
end

def parse_list(string)
  string.split_as_list
end

def waitrt
  wait_until { (XMLData.roundtime_end.to_f - Time.now.to_f + XMLData.server_time_offset.to_f) > 0 }
  sleep checkrt
end

def waitcastrt
  wait_until { (XMLData.cast_roundtime_end.to_f - Time.now.to_f + XMLData.server_time_offset.to_f) > 0 }
  sleep checkcastrt
end

def checkrt
  [0, XMLData.roundtime_end.to_f - Time.now.to_f + XMLData.server_time_offset.to_f].max
end

def checkcastrt
  [0, XMLData.cast_roundtime_end.to_f - Time.now.to_f + XMLData.server_time_offset.to_f].max
end

def waitrt?
  sleep checkrt
  return true if checkrt > 0.0
  return false if checkrt == 0
end

def waitcastrt?
#  sleep checkcastrt
  current_castrt = checkcastrt
  if current_castrt.to_f > 0.0
    sleep(current_castrt)
    return true
  else
    return false
  end
end

def checkpoison
  XMLData.indicator['IconPOISONED'] == 'y'
end

def checkdisease
  XMLData.indicator['IconDISEASED'] == 'y'
end

def checksitting
  XMLData.indicator['IconSITTING'] == 'y'
end

def checkkneeling
  XMLData.indicator['IconKNEELING'] == 'y'
end

def checkstunned
  XMLData.indicator['IconSTUNNED'] == 'y'
end

def checkbleeding
  XMLData.indicator['IconBLEEDING'] == 'y'
end

def checkgrouped
  XMLData.indicator['IconJOINED'] == 'y'
end

def checkdead
  XMLData.indicator['IconDEAD'] == 'y'
end

def checkreallybleeding
  checkbleeding and !(Spell[9909].active? or Spell[9905].active?)
end

def muckled?
  muckled = checkwebbed || checkdead || checkstunned
  if defined?(checksleeping)
    muckled = muckled || checksleeping
  end
  if defined?(checkbound)
    muckled = muckled || checkbound
  end
  return muckled
end

def checkhidden
  XMLData.indicator['IconHIDDEN'] == 'y'
end

def checkinvisible
  XMLData.indicator['IconINVISIBLE'] == 'y'
end

def checkwebbed
  XMLData.indicator['IconWEBBED'] == 'y'
end

def checkprone
  XMLData.indicator['IconPRONE'] == 'y'
end

def checknotstanding
  XMLData.indicator['IconSTANDING'] == 'n'
end

def checkstanding
  XMLData.indicator['IconSTANDING'] == 'y'
end

def checkname(*strings)
  strings.flatten!
  if strings.empty?
    XMLData.name
  else
    XMLData.name =~ /^(?:#{strings.join('|')})/i
  end
end

def checkloot
  GameObj.loot.collect { |item| item.noun }
end

def i_stand_alone
  unless script = Script.current then echo 'i_stand_alone: cannot identify calling script.'; return nil; end
  script.want_downstream = !script.want_downstream
  return !script.want_downstream
end

def debug(*args)
  if $LICH_DEBUG
    if block_given?
      yield(*args)
    else
      echo(*args)
    end
  end
end

def timetest(*contestants)
  contestants.collect { |code| start = Time.now; 5000.times { code.call }; Time.now - start }
end

def dec2bin(n)
  "0" + [n].pack("N").unpack("B32")[0].sub(/^0+(?=\d)/, '')
end

def bin2dec(n)
  [("0" * 32 + n.to_s)[-32..-1]].pack("B32").unpack("N")[0]
end

def idle?(time = 60)
  Time.now - $_IDLETIMESTAMP_ >= time
end

def selectput(string, success, failure, timeout = nil)
  timeout = timeout.to_f if timeout and !timeout.kind_of?(Numeric)
  success = [success] if success.kind_of? String
  failure = [failure] if failure.kind_of? String
  if !string.kind_of?(String) or !success.kind_of?(Array) or !failure.kind_of?(Array) or timeout && !timeout.kind_of?(Numeric)
    raise ArgumentError, "usage is: selectput(game_command,success_array,failure_array[,timeout_in_secs])"
  end

  success.flatten!
  failure.flatten!
  regex = /#{(success + failure).join('|')}/i
  successre = /#{success.join('|')}/i
  failurere = /#{failure.join('|')}/i
  thr = Thread.current

  timethr = Thread.new {
    timeout -= sleep("0.1".to_f) until timeout <= 0
    thr.raise(StandardError)
  } if timeout

  begin
    loop {
      fput(string)
      response = waitforre(regex)
      if successre.match(response.to_s)
        timethr.kill if timethr.alive?
        break(response.string)
      end
      yield(response.string) if block_given?
    }
  rescue
    nil
  end
end

def toggle_unique
  unless script = Script.current then echo 'toggle_unique: cannot identify calling script.'; return nil; end
  script.want_downstream = !script.want_downstream
end

def die_with_me(*vals)
  unless script = Script.current then echo 'die_with_me: cannot identify calling script.'; return nil; end
  script.die_with.push vals
  script.die_with.flatten!
  echo("The following script(s) will now die when I do: #{script.die_with.join(', ')}") unless script.die_with.empty?
end

def upstream_waitfor(*strings)
  strings.flatten!
  script = Script.current
  unless script.want_upstream then echo("This script wants to listen to the upstream, but it isn't set as receiving the upstream! This will cause a permanent hang, aborting (ask for the upstream with 'toggle_upstream' in the script)"); return false end
  regexpstr = strings.join('|')
  while line = script.upstream_gets
    if line =~ /#{regexpstr}/i
      return line
    end
  end
end

def send_to_script(*values)
  values.flatten!
  if script = Script.list.find { |val| val.name =~ /^#{values.first}/i }
    if script.want_downstream
      values[1..-1].each { |val| script.downstream_buffer.push(val) }
    else
      values[1..-1].each { |val| script.unique_buffer.push(val) }
    end
    echo("Sent to #{script.name} -- '#{values[1..-1].join(' ; ')}'")
    return true
  else
    echo("'#{values.first}' does not match any active scripts!")
    return false
  end
end

def unique_send_to_script(*values)
  values.flatten!
  if script = Script.list.find { |val| val.name =~ /^#{values.first}/i }
    values[1..-1].each { |val| script.unique_buffer.push(val) }
    echo("sent to #{script}: #{values[1..-1].join(' ; ')}")
    return true
  else
    echo("'#{values.first}' does not match any active scripts!")
    return false
  end
end

def unique_waitfor(*strings)
  unless script = Script.current then echo 'unique_waitfor: cannot identify calling script.'; return nil; end
  strings.flatten!
  regexp = /#{strings.join('|')}/
  while true
    str = script.unique_gets
    if str =~ regexp
      return str
    end
  end
end

def unique_get
  unless script = Script.current then echo 'unique_get: cannot identify calling script.'; return nil; end
  script.unique_gets
end

def unique_get?
  unless script = Script.current then echo 'unique_get: cannot identify calling script.'; return nil; end
  script.unique_gets?
end

def multimove(*dirs)
  dirs.flatten.each { |dir| move(dir) }
end

def n;    'north';     end

def ne;   'northeast'; end

def e;    'east';      end

def se;   'southeast'; end

def s;    'south';     end

def sw;   'southwest'; end

def w;    'west';      end

def nw;   'northwest'; end

def u;    'up';        end

def up;   'up'; end

def down; 'down';      end

def d;    'down';      end

def o;    'out';       end

def out;  'out';       end

def move(dir = 'none', giveup_seconds = 10, giveup_lines = 30)
  # [LNet]-[Private]-Casis: "You begin to make your way up the steep headland pathway.  Before traveling very far, however, you lose your footing on the loose stones.  You struggle in vain to maintain your balance, then find yourself falling to the bay below!"  (20:35:36)
  # [LNet]-[Private]-Casis: "You smack into the water with a splash and sink far below the surface."  (20:35:50)
  # You approach the entrance and identify yourself to the guard.  The guard checks over a long scroll of names and says, "I'm sorry, the Guild is open to invitees only.  Please do return at a later date when we will be open to the public."
  if dir == 'none'
    echo 'move: no direction given'
    return false
  end

  need_full_hands = false
  tried_open = false
  tried_fix_drag = false
  line_count = 0
  room_count = XMLData.room_count
  giveup_time = Time.now.to_i + giveup_seconds.to_i
  save_stream = Array.new

  put_dir = proc {
    if XMLData.room_count > room_count
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return true
    end
    waitrt?
    wait_while { stunned? }
    giveup_time = Time.now.to_i + giveup_seconds.to_i
    line_count = 0
    save_stream.push(clear)
    put dir
  }

  put_dir.call

  loop {
    line = get?
    unless line.nil?
      save_stream.push(line)
      line_count += 1
    end
    if line.nil?
      sleep 0.1
    elsif line =~ /^You realize that would be next to impossible while in combat.|^You can't do that while engaged!|^You are engaged to |^You need to retreat out of combat first!|^You try to move, but you're engaged|^While in combat\?  You'll have better luck if you first retreat/
      # DragonRealms
      fput 'retreat'
      fput 'retreat'
      put_dir.call
    elsif line =~ /^You can't enter .+ and remain hidden or invisible\.|if he can't see you!$|^You can't enter .+ when you can't be seen\.$|^You can't do that without being seen\.$|^How do you intend to get .*? attention\?  After all, no one can see you right now\.$/
      fput 'unhide'
      put_dir.call
    elsif (line =~ /^You (?:take a few steps toward|trudge up to|limp towards|march up to|sashay gracefully up to|skip happily towards|sneak up to|stumble toward) a rusty doorknob/) and (dir =~ /door/)
      which = [ 'first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eight', 'ninth', 'tenth', 'eleventh', 'twelfth' ]
      # avoid stomping the room for the entire session due to a transient failure
      dir = dir.to_s
      if dir =~ /\b#{which.join('|')}\b/
        dir.sub!(/\b(#{which.join('|')})\b/) { "#{which[which.index($1) + 1]}" }
      else
        dir.sub!('door', 'second door')
      end
      put_dir.call
    elsif line =~ /^You can't go there|^You can't (?:go|swim) in that direction\.|^Where are you trying to go\?|^What were you referring to\?|^I could not find what you were referring to\.|^How do you plan to do that here\?|^You take a few steps towards|^You cannot do that\.|^You settle yourself on|^You shouldn't annoy|^You can't go to|^That's probably not a very good idea|^Maybe you should look|^You are already(?! as far away as you can get)|^You walk over to|^You step over to|The [\w\s]+ is too far away|You may not pass\.|become impassable\.|prevents you from entering\.|Please leave promptly\.|is too far above you to attempt that\.$|^Uh, yeah\.  Right\.$|^Definitely NOT a good idea\.$|^Your attempt fails|^There doesn't seem to be any way to do that at the moment\.$/
      echo 'move: failed'
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return false
    elsif line =~ /^[A-z\s-] is unable to follow you\.$|^An unseen force prevents you\.$|^Sorry, you aren't allowed to enter here\.|^That looks like someplace only performers should go\.|^As you climb, your grip gives way and you fall down|^The clerk stops you from entering the partition and says, "I'll need to see your ticket!"$|^The guard stops you, saying, "Only members of registered groups may enter the Meeting Hall\.  If you'd like to visit, ask a group officer for a guest pass\."$|^An? .*? reaches over and grasps [A-Z][a-z]+ by the neck preventing (?:him|her) from being dragged anywhere\.$|^You'll have to wait, [A-Z][a-z]+ .* locker|^As you move toward the gate, you carelessly bump into the guard|^You attempt to enter the back of the shop, but a clerk stops you.  "Your reputation precedes you!|you notice that thick beams are placed across the entry with a small sign that reads, "Abandoned\."$|appears to be closed, perhaps you should try again later\?$/
      echo 'move: failed'
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      # return nil instead of false to show the direction shouldn't be removed from the map database
      return nil
    elsif line =~ /^You grab [A-Z][a-z]+ and try to drag h(?:im|er), but s?he (?:is too heavy|doesn't budge)\.$|^Tentatively, you attempt to swim through the nook\.  After only a few feet, you begin to sink!  Your lungs burn from lack of air, and you begin to panic!  You frantically paddle back to safety!$|^Guards(?:wo)?man [A-Z][a-z]+ stops you and says, "(?:Stop\.|Halt!)  You need to make sure you check in|^You step into the root, but can see no way to climb the slippery tendrils inside\.  After a moment, you step back out\.$|^As you start .*? back to safe ground\.$|^You stumble a bit as you try to enter the pool but feel that your persistence will pay off\.$|^A shimmering field of magical crimson and gold energy flows through the area\.$|^You attempt to navigate your way through the fog, but (?:quickly become entangled|get turned around)|^Trying to judge the climb, you peer over the edge\.\s*A wave of dizziness hits you, and you back away from the .*\.$|^You approach the .*, but the steepness is intimidating\.$|^You make your way up the .*\.\s*Partway up, you make the mistake of looking down\. Struck by vertigo, you cling to the .* for a few moments, then slowly climb back down\.$|^You pick your way up the .*, but reach a point where your footing is questionable.\s*Reluctantly, you climb back down.$/
      sleep 1
      waitrt?
      put_dir.call
    elsif line =~ /^Climbing.*(?:plunge|fall)|^Tentatively, you attempt to climb.*(?:fall|slip)|^You start up the .* but slip after a few feet and fall to the ground|^You start.*but quickly realize|^You.*drop back to the ground|^You leap .* fall unceremoniously to the ground in a heap\.$|^You search for a way to make the climb .*? but without success\.$|^You start to climb .* you fall to the ground|^You attempt to climb .* wrong approach|^You run towards .*? slowly retreat back, reassessing the situation\.|^You attempt to climb down the .*, but you can't seem to find purchase\.|^You start down the .*, but you find it hard going.\s*Rather than risking a fall, you make your way back up\./
      sleep 1
      waitrt?
      fput 'stand' unless standing?
      waitrt?
      put_dir.call
    elsif line =~ /^You begin to climb up the silvery thread.* you tumble to the ground/
      sleep 0.5
      waitrt?
      fput 'stand' unless standing?
      waitrt?
      if checkleft or checkright
        need_full_hands = true
        empty_hands
      end
      put_dir.call
    elsif line == 'You are too injured to be doing any climbing!'
      if (resolve = Spell[9704]) and resolve.known?
        wait_until { resolve.affordable? }
        resolve.cast
        put_dir.call
      else
        return nil
      end
    elsif line =~ /^You(?:'re going to| will) have to climb that\./
      dir.gsub!('go', 'climb')
      put_dir.call
    elsif line =~ /^You can't climb that\./
      dir.gsub!('climb', 'go')
      put_dir.call
    elsif line =~ /^You can't drag/
      if tried_fix_drag
        fill_hands if need_full_hands
        Script.current.downstream_buffer.unshift(save_stream)
        Script.current.downstream_buffer.flatten!
        return false
      elsif (dir =~ /^(?:go|climb) .+$/) and (drag_line = reget.reverse.find { |l| l =~ /^You grab .*?(?:'s body)? and drag|^You are now automatically attempting to drag .*? when/ })
        tried_fix_drag = true
        name = (/^You grab (.*?)('s body)? and drag/.match(drag_line).captures.first || /^You are now automatically attempting to drag (.*?) when/.match(drag_line).captures.first)
        target = /^(?:go|climb) (.+)$/.match(dir).captures.first
        fput "drag #{name}"
        dir = "drag #{name} #{target}"
        put_dir.call
      else
        tried_fix_drag = true
        dir.sub!(/^climb /, 'go ')
        put_dir.call
      end
    elsif line =~ /^Maybe if your hands were empty|^You figure freeing up both hands might help\.|^You can't .+ with your hands full\.$|^You'll need empty hands to climb that\.$|^It's a bit too difficult to swim holding|^You will need both hands free for such a difficult task\./
      need_full_hands = true
      empty_hands
      put_dir.call
    elsif line =~ /(?:appears|seems) to be closed\.$|^You cannot quite manage to squeeze between the stone doors\.$/
      if tried_open
        fill_hands if need_full_hands
        Script.current.downstream_buffer.unshift(save_stream)
        Script.current.downstream_buffer.flatten!
        return false
      else
        tried_open = true
        fput dir.sub(/go|climb/, 'open')
        put_dir.call
      end
    elsif line =~ /^(\.\.\.w|W)ait ([0-9]+) sec(onds)?\.$/
      if $2.to_i > 1
        sleep ($2.to_i - "0.2".to_f)
      else
        sleep 0.3
      end
      put_dir.call
    elsif line =~ /will have to stand up first|must be standing first|^You'll have to get up first|^But you're already sitting!|^Shouldn't you be standing first|^Try standing up|^Perhaps you should stand up|^Standing up might help|^You should really stand up first|You can't do that while sitting|You must be standing to do that|You can't do that while lying down/
      fput 'stand'
      waitrt?
      put_dir.call
    elsif line == "You're still recovering from your recent cast."
      sleep 2
      put_dir.call
    elsif line =~ /^The ground approaches you at an alarming rate/
      sleep 1
      fput 'stand' unless standing?
      put_dir.call
    elsif line =~ /You go flying down several feet, landing with a/
      sleep 1
      fput 'stand' unless standing?
      put_dir.call
    elsif line =~ /^Sorry, you may only type ahead/
      sleep 1
      put_dir.call
    elsif line == 'You are still stunned.'
      wait_while { stunned? }
      put_dir.call
    elsif line =~ /you slip (?:on a patch of ice )?and flail uselessly as you land on your rear(?:\.|!)$|You wobble and stumble only for a moment before landing flat on your face!$/
      waitrt?
      fput 'stand' unless standing?
      waitrt?
      put_dir.call
    elsif line =~ /^You flick your hand (?:up|down)wards and focus your aura on your disk, but your disk only wobbles briefly\.$/
      put_dir.call
    elsif line =~ /^You dive into the fast-moving river, but the current catches you and whips you back to shore, wet and battered\.$|^Running through the swampy terrain, you notice a wet patch in the bog|^You flounder around in the water.$|^You blunder around in the water, barely able|^You struggle against the swift current to swim|^You slap at the water in a sad failure to swim|^You work against the swift current to swim/
      waitrt?
      put_dir.call
    elsif line == "You don't seem to be able to move to do that."
      30.times {
        break if clear.include?('You regain control of your senses!')

        sleep 0.1
      }
      put_dir.call
    elsif line =~ /^It's pitch dark and you can't see a thing!/
      echo "You will need a light source to continue your journey"
      return true
    end
    if XMLData.room_count > room_count
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return true
    end
    if Time.now.to_i >= giveup_time
      echo "move: no recognized response in #{giveup_seconds} seconds.  giving up."
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return nil
    end
    if line_count >= giveup_lines
      echo "move: no recognized response after #{line_count} lines.  giving up."
      fill_hands if need_full_hands
      Script.current.downstream_buffer.unshift(save_stream)
      Script.current.downstream_buffer.flatten!
      return nil
    end
  }
end

def watchhealth(value, theproc = nil, &block)
  value = value.to_i
  if block.nil?
    if !theproc.respond_to? :call
      respond "`watchhealth' was not given a block or a proc to execute!"
      return nil
    else
      block = theproc
    end
  end
  Thread.new {
    wait_while { health(value) }
    block.call
  }
end

def wait_until(announce = nil)
  priosave = Thread.current.priority
  Thread.current.priority = 0
  unless announce.nil? or yield
    respond(announce)
  end
  until yield
    sleep 0.25
  end
  Thread.current.priority = priosave
end

def wait_while(announce = nil)
  priosave = Thread.current.priority
  Thread.current.priority = 0
  unless announce.nil? or !yield
    respond(announce)
  end
  while yield
    sleep 0.25
  end
  Thread.current.priority = priosave
end

def checkpaths(dir = "none")
  if dir == "none"
    if XMLData.room_exits.empty?
      return false
    else
      return XMLData.room_exits.collect { |dir| dir = SHORTDIR[dir] }
    end
  else
    XMLData.room_exits.include?(dir) || XMLData.room_exits.include?(SHORTDIR[dir])
  end
end

def reverse_direction(dir)
  if dir == "n" then 's'
  elsif dir == "ne" then 'sw'
  elsif dir == "e" then 'w'
  elsif dir == "se" then 'nw'
  elsif dir == "s" then 'n'
  elsif dir == "sw" then 'ne'
  elsif dir == "w" then 'e'
  elsif dir == "nw" then 'se'
  elsif dir == "up" then 'down'
  elsif dir == "down" then 'up'
  elsif dir == "out" then 'out'
  elsif dir == 'o' then out
  elsif dir == 'u' then 'down'
  elsif dir == 'd' then up
  elsif dir == n then s
  elsif dir == ne then sw
  elsif dir == e then w
  elsif dir == se then nw
  elsif dir == s then n
  elsif dir == sw then ne
  elsif dir == w then e
  elsif dir == nw then se
  elsif dir == u then d
  elsif dir == d then u
  else echo("Cannot recognize direction to properly reverse it!"); false
  end
end

def walk(*boundaries, &block)
  boundaries.flatten!
  unless block.nil?
    until val = yield
      walk(*boundaries)
    end
    return val
  end
  if $last_dir and !boundaries.empty? and checkroomdescrip =~ /#{boundaries.join('|')}/i
    move($last_dir)
    $last_dir = reverse_direction($last_dir)
    return checknpcs
  end
  dirs = checkpaths
  dirs.delete($last_dir) unless dirs.length < 2
  this_time = rand(dirs.length)
  $last_dir = reverse_direction(dirs[this_time])
  move(dirs[this_time])
  checknpcs
end

def run
  loop { break unless walk }
end

def check_mind(string = nil)
  if string.nil?
    return XMLData.mind_text
  elsif (string.class == String) and (string.to_i == 0)
    if string =~ /#{XMLData.mind_text}/i
      return true
    else
      return false
    end
  elsif string.to_i.between?(0, 100)
    return string.to_i <= XMLData.mind_value.to_i
  else
    echo("check_mind error! You must provide an integer ranging from 0-100, the common abbreviation of how full your head is, or provide no input to have check_mind return an abbreviation of how filled your head is."); sleep 1
    return false
  end
end

def checkmind(string = nil)
  if string.nil?
    return XMLData.mind_text
  elsif string.class == String and string.to_i == 0
    if string =~ /#{XMLData.mind_text}/i
      return true
    else
      return false
    end
  elsif string.to_i.between?(1, 8)
    mind_state = ['clear as a bell', 'fresh and clear', 'clear', 'muddled', 'becoming numbed', 'numbed', 'must rest', 'saturated']
    if mind_state.index(XMLData.mind_text)
      mind = mind_state.index(XMLData.mind_text) + 1
      return string.to_i <= mind
    else
      echo "Bad string in checkmind: mind_state"
      nil
    end
  else
    echo("Checkmind error! You must provide an integer ranging from 1-8 (7 is fried, 8 is 100% fried), the common abbreviation of how full your head is, or provide no input to have checkmind return an abbreviation of how filled your head is."); sleep 1
    return false
  end
end

def percentmind(num = nil)
  if num.nil?
    XMLData.mind_value
  else
    XMLData.mind_value >= num.to_i
  end
end

def checkfried
  if XMLData.mind_text =~ /must rest|saturated/
    true
  else
    false
  end
end

def checksaturated
  if XMLData.mind_text =~ /saturated/
    true
  else
    false
  end
end

def checkmana(num = nil)
  if num.nil?
    XMLData.mana
  else
    XMLData.mana >= num.to_i
  end
end

def maxmana
  XMLData.max_mana
end

def percentmana(num = nil)
  if XMLData.max_mana == 0
    percent = 100
  else
    percent = ((XMLData.mana.to_f / XMLData.max_mana.to_f) * 100).to_i
  end
  if num.nil?
    percent
  else
    percent >= num.to_i
  end
end

def checkhealth(num = nil)
  if num.nil?
    XMLData.health
  else
    XMLData.health >= num.to_i
  end
end

def maxhealth
  XMLData.max_health
end

def percenthealth(num = nil)
  if num.nil?
    ((XMLData.health.to_f / XMLData.max_health.to_f) * 100).to_i
  else
    ((XMLData.health.to_f / XMLData.max_health.to_f) * 100).to_i >= num.to_i
  end
end

def checkspirit(num = nil)
  if num.nil?
    XMLData.spirit
  else
    XMLData.spirit >= num.to_i
  end
end

def maxspirit
  XMLData.max_spirit
end

def percentspirit(num = nil)
  if num.nil?
    ((XMLData.spirit.to_f / XMLData.max_spirit.to_f) * 100).to_i
  else
    ((XMLData.spirit.to_f / XMLData.max_spirit.to_f) * 100).to_i >= num.to_i
  end
end

def checkstamina(num = nil)
  if num.nil?
    XMLData.stamina
  else
    XMLData.stamina >= num.to_i
  end
end

def maxstamina()
  XMLData.max_stamina
end

def percentstamina(num = nil)
  if XMLData.max_stamina == 0
    percent = 100
  else
    percent = ((XMLData.stamina.to_f / XMLData.max_stamina.to_f) * 100).to_i
  end
  if num.nil?
    percent
  else
    percent >= num.to_i
  end
end

def maxconcentration()
   XMLData.max_concentration
end
def percentconcentration(num=nil)
   if XMLData.max_concentration == 0
      percent == 100
   else
      percent = ((XMLData.concentration.to_f / XMLData.max_concentration.to_f) * 100).to_i
   end
   if num.nil?
      percent
   else
      percent >= num.to_i
   end
end
def checkstance(num = nil)
  if num.nil?
    XMLData.stance_text
  elsif (num.class == String) and (num.to_i == 0)
    if num =~ /off/i
      XMLData.stance_value == 0
    elsif num =~ /adv/i
      XMLData.stance_value.between?(01, 20)
    elsif num =~ /for/i
      XMLData.stance_value.between?(21, 40)
    elsif num =~ /neu/i
      XMLData.stance_value.between?(41, 60)
    elsif num =~ /gua/i
      XMLData.stance_value.between?(61, 80)
    elsif num =~ /def/i
      XMLData.stance_value == 100
    else
      echo "checkstance: invalid argument (#{num}).  Must be off/adv/for/neu/gua/def or 0-100"
      nil
    end
  elsif (num.class == Integer) or (num =~ /^[0-9]+$/ and num = num.to_i)
    XMLData.stance_value == num.to_i
  else
    echo "checkstance: invalid argument (#{num}).  Must be off/adv/for/neu/gua/def or 0-100"
    nil
  end
end

def percentstance(num = nil)
  if num.nil?
    XMLData.stance_value
  else
    XMLData.stance_value >= num.to_i
  end
end

def checkencumbrance(string = nil)
  if string.nil?
    XMLData.encumbrance_text
  elsif (string.class == Integer) or (string =~ /^[0-9]+$/ and string = string.to_i)
    string <= XMLData.encumbrance_value
  else
    # fixme
    if string =~ /#{XMLData.encumbrance_text}/i
      true
    else
      false
    end
  end
end

def percentencumbrance(num = nil)
  if num.nil?
    XMLData.encumbrance_value
  else
    num.to_i <= XMLData.encumbrance_value
  end
end

def checkarea(*strings)
  strings.flatten!
  if strings.empty?
    XMLData.room_title.split(',').first.sub('[', '')
  else
    XMLData.room_title.split(',').first =~ /#{strings.join('|')}/i
  end
end

def checkroom(*strings)
  strings.flatten!
  if strings.empty?
    XMLData.room_title.chomp
  else
    XMLData.room_title =~ /#{strings.join('|')}/i
  end
end

def outside?
  if XMLData.room_exits_string =~ /Obvious paths:/
    true
  else
    false
  end
end

def checkfamarea(*strings)
  strings.flatten!
  if strings.empty? then return XMLData.familiar_room_title.split(',').first.sub('[', '') end

  XMLData.familiar_room_title.split(',').first =~ /#{strings.join('|')}/i
end

def checkfampaths(dir = "none")
  if dir == "none"
    if XMLData.familiar_room_exits.empty?
      return false
    else
      return XMLData.familiar_room_exits
    end
  else
    XMLData.familiar_room_exits.include?(dir)
  end
end

def checkfamroom(*strings)
  strings.flatten!; if strings.empty? then return XMLData.familiar_room_title.chomp end

  XMLData.familiar_room_title =~ /#{strings.join('|')}/i
end

def checkfamnpcs(*strings)
  parsed = Array.new
  XMLData.familiar_npcs.each { |val| parsed.push(val.split.last) }
  if strings.empty?
    if parsed.empty?
      return false
    else
      return parsed
    end
  else
    if mtch = strings.find { |lookfor| parsed.find { |critter| critter =~ /#{lookfor}/ } }
      return mtch
    else
      return false
    end
  end
end

def checkfampcs(*strings)
  familiar_pcs = Array.new
  XMLData.familiar_pcs.to_s.gsub(/Lord |Lady |Great |High |Renowned |Grand |Apprentice |Novice |Journeyman /, '').split(',').each { |line| familiar_pcs.push(line.slice(/[A-Z][a-z]+/)) }
  if familiar_pcs.empty?
    return false
  elsif strings.empty?
    return familiar_pcs
  else
    regexpstr = strings.join('|\b')
    peeps = familiar_pcs.find_all { |val| val =~ /\b#{regexpstr}/i }
    if peeps.empty?
      return false
    else
      return peeps
    end
  end
end

def checkpcs(*strings)
  pcs = GameObj.pcs.collect { |pc| pc.noun }
  if pcs.empty?
    if strings.empty? then return nil else return false end
  end
  strings.flatten!
  if strings.empty?
    pcs
  else
    regexpstr = strings.join(' ')
    pcs.find { |pc| regexpstr =~ /\b#{pc}/i }
  end
end

def checknpcs(*strings)
  npcs = GameObj.npcs.collect { |npc| npc.noun }
  if npcs.empty?
    if strings.empty? then return nil else return false end
  end
  strings.flatten!
  if strings.empty?
    npcs
  else
    regexpstr = strings.join(' ')
    npcs.find { |npc| regexpstr =~ /\b#{npc}/i }
  end
end

def count_npcs
  checknpcs.length
end

def checkright(*hand)
  if GameObj.right_hand.nil? then return nil end

  hand.flatten!
  if GameObj.right_hand.name == "Empty" or GameObj.right_hand.name.empty?
    nil
  elsif hand.empty?
    GameObj.right_hand.noun
  else
    hand.find { |instance| GameObj.right_hand.name =~ /#{instance}/i }
  end
end

def checkleft(*hand)
  if GameObj.left_hand.nil? then return nil end

  hand.flatten!
  if GameObj.left_hand.name == "Empty" or GameObj.left_hand.name.empty?
    nil
  elsif hand.empty?
    GameObj.left_hand.noun
  else
    hand.find { |instance| GameObj.left_hand.name =~ /#{instance}/i }
  end
end

def checkroomdescrip(*val)
  val.flatten!
  if val.empty?
    return XMLData.room_description
  else
    return XMLData.room_description =~ /#{val.join('|')}/i
  end
end

def checkfamroomdescrip(*val)
  val.flatten!
  if val.empty?
    return XMLData.familiar_room_description
  else
    return XMLData.familiar_room_description =~ /#{val.join('|')}/i
  end
end

def checkspell(*spells)
  spells.flatten!
  return false if Spell.active.empty?

  spells.each { |spell| return false unless Spell[spell].active? }
  true
end

def checkprep(spell = nil)
  if spell.nil?
    XMLData.prepared_spell
  elsif spell.class != String
    echo("Checkprep error, spell # not implemented!  You must use the spell name")
    false
  else
    XMLData.prepared_spell =~ /^#{spell}/i
  end
end

def setpriority(val = nil)
  if val.nil? then return Thread.current.priority end

  if val.to_i > 3
    echo("You're trying to set a script's priority as being higher than the send/recv threads (this is telling Lich to run the script before it even gets data to give the script, and is useless); the limit is 3")
    return Thread.current.priority
  else
    Thread.current.group.list.each { |thr| thr.priority = val.to_i }
    return Thread.current.priority
  end
end

def checkbounty
  if XMLData.bounty_task
    return XMLData.bounty_task
  else
    return nil
  end
end

def checksleeping
  return $infomon_sleeping
end

def sleeping?
  return $infomon_sleeping
end

def checkbound
  return $infomon_bound
end

def bound?
  return $infomon_bound
end

def checksilenced
  $infomon_silenced
end

def silenced?
  $infomon_silenced
end

def checkcalmed
  $infomon_calmed
end

def calmed?
  $infomon_calmed
end

def checkcutthroat
  $infomon_cutthroat
end

def cutthroat?
  $infomon_cutthroat
end

def variable
  unless script = Script.current then echo 'variable: cannot identify calling script.'; return nil; end
  script.vars
end

def pause(num = 1)
  if num =~ /m/
    sleep((num.sub(/m/, '').to_f * 60))
  elsif num =~ /h/
    sleep((num.sub(/h/, '').to_f * 3600))
  elsif num =~ /d/
    sleep((num.sub(/d/, '').to_f * 86400))
  else
    sleep(num.to_f)
  end
end

def cast(spell, target = nil, results_of_interest = nil)
  if spell.class == Spell
    spell.cast(target, results_of_interest)
  elsif ((spell.class == Integer) or (spell.to_s =~ /^[0-9]+$/)) and (find_spell = Spell[spell.to_i])
    find_spell.cast(target, results_of_interest)
  elsif (spell.class == String) and (find_spell = Spell[spell])
    find_spell.cast(target, results_of_interest)
  else
    echo "cast: invalid spell (#{spell})"
    false
  end
end

def clear(opt = 0)
  unless script = Script.current then respond('--- clear: Unable to identify calling script.'); return false; end
  to_return = script.downstream_buffer.dup
  script.downstream_buffer.clear
  to_return
end

def match(label, string)
  strings = [label, string]
  strings.flatten!
  unless script = Script.current then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("Error! 'match' was given no strings to look for!"); sleep 1; return false end
  unless strings.length == 2
    while line_in = script.gets
      strings.each { |string|
        if line_in =~ /#{string}/ then return $~.to_s end
      }
    end
  else
    if script.respond_to?(:match_stack_add)
      script.match_stack_add(strings.first.to_s, strings.last)
    else
      script.match_stack_labels.push(strings[0].to_s)
      script.match_stack_strings.push(strings[1])
    end
  end
end

def matchtimeout(secs, *strings)
  unless script = Script.current then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  unless (secs.class == Float || secs.class == Integer)
    echo('matchtimeout error! You appear to have given it a string, not a #! Syntax:  matchtimeout(30, "You stand up")')
    return false
  end
  strings.flatten!
  if strings.empty?
    echo("matchtimeout without any strings to wait for!")
    sleep 1
    return false
  end
  regexpstr = strings.join('|')
  end_time = Time.now.to_f + secs
  loop {
    line = get?
    if line.nil?
      sleep 0.1
    elsif line =~ /#{regexpstr}/i
      return line
    end
    if (Time.now.to_f > end_time)
      return false
    end
  }
end

def matchbefore(*strings)
  strings.flatten!
  unless script = Script.current then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("matchbefore without any strings to wait for!"); return false end
  regexpstr = strings.join('|')
  loop { if (line_in = script.gets) =~ /#{regexpstr}/ then return $`.to_s end }
end

def matchafter(*strings)
  strings.flatten!
  unless script = Script.current then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("matchafter without any strings to wait for!"); return end
  regexpstr = strings.join('|')
  loop { if (line_in = script.gets) =~ /#{regexpstr}/ then return $'.to_s end }
end

def matchboth(*strings)
  strings.flatten!
  unless script = Script.current then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("matchboth without any strings to wait for!"); return end
  regexpstr = strings.join('|')
  loop { if (line_in = script.gets) =~ /#{regexpstr}/ then break end }
  return [$`.to_s, $'.to_s]
end

def matchwait(*strings)
  unless script = Script.current then respond('--- matchwait: Unable to identify calling script.'); return false; end
  strings.flatten!
  unless strings.empty?
    regexpstr = strings.collect { |str| str.kind_of?(Regexp) ? str.source : str }.join('|')
    regexobj = /#{regexpstr}/
    while line_in = script.gets
      return line_in if line_in =~ regexobj
    end
  else
    strings = script.match_stack_strings
    labels = script.match_stack_labels
    regexpstr = /#{strings.join('|')}/i
    while line_in = script.gets
      if mdata = regexpstr.match(line_in)
        jmp = labels[strings.index(mdata.to_s) || strings.index(strings.find { |str| line_in =~ /#{str}/i })]
        script.match_stack_clear
        goto jmp
      end
    end
  end
end

def waitforre(regexp)
  unless script = Script.current then respond('--- waitforre: Unable to identify calling script.'); return false; end
  unless regexp.class == Regexp then echo("Script error! You have given 'waitforre' something to wait for, but it isn't a Regular Expression! Use 'waitfor' if you want to wait for a string."); sleep 1; return nil end
  regobj = regexp.match(script.gets) until regobj
end

def waitfor(*strings)
  unless script = Script.current then respond('--- waitfor: Unable to identify calling script.'); return false; end
  strings.flatten!
  if (script.class == WizardScript) and (strings.length == 1) and (strings.first.strip == '>')
    return script.gets
  end

  if strings.empty?
    echo 'waitfor: no string to wait for'
    return false
  end
  regexpstr = strings.join('|')
  while true
    line_in = script.gets
    if (line_in =~ /#{regexpstr}/i) then return line_in end
  end
end

def wait
  unless script = Script.current then respond('--- wait: unable to identify calling script.'); return false; end
  script.clear
  return script.gets
end

def get
  Script.current.gets
end

def get?
  Script.current.gets?
end

def reget(*lines)
  unless script = Script.current then respond('--- reget: Unable to identify calling script.'); return false; end
  lines.flatten!
  if caller.find { |c| c =~ /regetall/ }
    history = ($_SERVERBUFFER_.history + $_SERVERBUFFER_).join("\n")
  else
    history = $_SERVERBUFFER_.dup.join("\n")
  end
  unless script.want_downstream_xml
    history.gsub!(/<pushStream id=["'](?:spellfront|inv|bounty|society)["'][^>]*\/>.*?<popStream[^>]*>/m, '')
    history.gsub!(/<stream id="Spells">.*?<\/stream>/m, '')
    history.gsub!(/<(compDef|inv|component|right|left|spell|prompt)[^>]*>.*?<\/\1>/m, '')
    history.gsub!(/<[^>]+>/, '')
    history.gsub!('&gt;', '>')
    history.gsub!('&lt;', '<')
  end
  history = history.split("\n").delete_if { |line| line.nil? or line.empty? or line =~ /^[\r\n\s\t]*$/ }
  if lines.first.kind_of?(Numeric) or lines.first.to_i.nonzero?
    history = history[-([lines.shift.to_i, history.length].min)..-1]
  end
  unless lines.empty? or lines.nil?
    regex = /#{lines.join('|')}/i
    history = history.find_all { |line| line =~ regex }
  end
  if history.empty?
    nil
  else
    history
  end
end

def regetall(*lines)
  reget(*lines)
end

def multifput(*cmds)
  cmds.flatten.compact.each { |cmd| fput(cmd) }
end

def fput(message, *waitingfor)
  unless script = Script.current then respond('--- waitfor: Unable to identify calling script.'); return false; end
  waitingfor.flatten!
  clear
  put(message)

  while string = get
    if string =~ /(?:\.\.\.wait |Wait )[0-9]+/
      hold_up = string.slice(/[0-9]+/).to_i
      sleep(hold_up) unless hold_up.nil?
      clear
      put(message)
      next
    elsif string =~ /^You.+struggle.+stand/
      clear
      fput 'stand'
      next
    elsif string =~ /stunned|can't do that while|cannot seem|^(?!You rummage).*can't seem|don't seem|Sorry, you may only type ahead/
      if dead?
        echo "You're dead...! You can't do that!"
        sleep 1
        script.downstream_buffer.unshift(string)
        return false
      elsif checkstunned
        while checkstunned
          sleep("0.25".to_f)
        end
      elsif checkwebbed
        while checkwebbed
          sleep("0.25".to_f)
        end
      elsif string =~ /Sorry, you may only type ahead/
        sleep 1
      else
        sleep 0.1
        script.downstream_buffer.unshift(string)
        return false
      end
      clear
      put(message)
      next
    else
      if waitingfor.empty?
        script.downstream_buffer.unshift(string)
        return string
      else
        if foundit = waitingfor.find { |val| string =~ /#{val}/i }
          script.downstream_buffer.unshift(string)
          return foundit
        end
        sleep 1
        clear
        put(message)
        next
      end
    end
  end
end

def put(*messages)
  messages.each { |message| Game.puts(message) }
end

def quiet_exit
  script = Script.current
  script.quiet = !(script.quiet)
end

def matchfindexact(*strings)
  strings.flatten!
  unless script = Script.current then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return false end
  if strings.empty? then echo("error! 'matchfind' with no strings to look for!"); sleep 1; return false end
  looking = Array.new
  strings.each { |str| looking.push(str.gsub('?', '(\b.+\b)')) }
  if looking.empty? then echo("matchfind without any strings to wait for!"); return false end
  regexpstr = looking.join('|')
  while line_in = script.gets
    if gotit = line_in.slice(/#{regexpstr}/)
      matches = Array.new
      looking.each_with_index { |str, idx|
        if gotit =~ /#{str}/i
          strings[idx].count('?').times { |n| matches.push(eval("$#{n + 1}")) }
        end
      }
      break
    end
  end
  if matches.length == 1
    return matches.first
  else
    return matches.compact
  end
end

def matchfind(*strings)
  regex = /#{strings.flatten.join('|').gsub('?', '(.+)')}/i
  unless script = Script.current
    respond "Unknown script is asking to use matchfind!  Cannot process request without identifying the calling script; killing this thread."
    Thread.current.kill
  end
  while true
    if reobj = regex.match(script.gets)
      ret = reobj.captures.compact
      if ret.length < 2
        return ret.first
      else
        return ret
      end
    end
  end
end

def matchfindword(*strings)
  regex = /#{strings.flatten.join('|').gsub('?', '([\w\d]+)')}/i
  unless script = Script.current
    respond "Unknown script is asking to use matchfindword!  Cannot process request without identifying the calling script; killing this thread."
    Thread.current.kill
  end
  while true
    if reobj = regex.match(script.gets)
      ret = reobj.captures.compact
      if ret.length < 2
        return ret.first
      else
        return ret
      end
    end
  end
end

def send_scripts(*messages)
  messages.flatten!
  messages.each { |message|
    Script.new_downstream(message)
  }
  true
end

def status_tags(onoff = "none")
  script = Script.current
  if onoff == "on"
    script.want_downstream = false
    script.want_downstream_xml = true
    echo("Status tags will be sent to this script.")
  elsif onoff == "off"
    script.want_downstream = true
    script.want_downstream_xml = false
    echo("Status tags will no longer be sent to this script.")
  elsif script.want_downstream_xml
    script.want_downstream = true
    script.want_downstream_xml = false
  else
    script.want_downstream = false
    script.want_downstream_xml = true
  end
end

def respond(first = "", *messages)
  str = ''
  begin
    if first.class == Array
      first.flatten.each { |ln| str += sprintf("%s\r\n", ln.to_s.chomp) }
    else
      str += sprintf("%s\r\n", first.to_s.chomp)
    end
    messages.flatten.each { |message| str += sprintf("%s\r\n", message.to_s.chomp) }
    str.split(/\r?\n/).each { |line| Script.new_script_output(line); Buffer.update(line, Buffer::SCRIPT_OUTPUT) }
    str.gsub!(/\r?\n/, "\r\n") if $frontend == 'genie'
    if $frontend == 'stormfront' || $frontend == 'genie'
      str = "<output class=\"mono\"/>\r\n#{str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')}<output class=\"\"/>\r\n"
    elsif $frontend == 'profanity'
      str = str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end
    # Double-checked locking to avoid interrupting a stream and crashing the client
    str_sent = false
    if $_CLIENT_
      until str_sent
        wait_while { !XMLData.safe_to_respond? }
        str_sent = $_CLIENT_.puts_if(str) { XMLData.safe_to_respond? }
      end
    end
    if $_DETACHABLE_CLIENT_
      str_sent = false
      until str_sent
        wait_while { !XMLData.safe_to_respond? }
        begin
          str_sent = $_DETACHABLE_CLIENT_.puts_if(str) { XMLData.safe_to_respond? }
        rescue
          break
        end
      end
    end
  rescue
    puts $!
    puts $!.backtrace.first
  end
end

def _respond(first = "", *messages)
  str = ''
  begin
    if first.class == Array
      first.flatten.each { |ln| str += sprintf("%s\r\n", ln.to_s.chomp) }
    else
      str += sprintf("%s\r\n", first.to_s.chomp)
    end
    str.gsub!(/\r?\n/, "\r\n") if $frontend == 'genie'
    messages.flatten.each { |message| str += sprintf("%s\r\n", message.to_s.chomp) }
    str.split(/\r?\n/).each { |line| Script.new_script_output(line); Buffer.update(line, Buffer::SCRIPT_OUTPUT) } # fixme: strip/separate script output?
    str_sent = false
    if $_CLIENT_
      until str_sent
        wait_while { !XMLData.safe_to_respond? }
        str_sent = $_CLIENT_.puts_if(str) { XMLData.safe_to_respond? }
      end
    end
    if $_DETACHABLE_CLIENT_
      str_sent = false
      until str_sent
        wait_while { !XMLData.safe_to_respond? }
        begin
          str_sent = $_DETACHABLE_CLIENT_.puts_if(str) { XMLData.safe_to_respond? }
        rescue
          break
        end
      end
    end
  rescue
    puts $!
    puts $!.backtrace.first
  end
end

def noded_pulse
  if Stats.prof =~ /warrior|rogue|sorcerer/i
    stats = [Skills.smc.to_i, Skills.emc.to_i]
  elsif Stats.prof =~ /empath|bard/i
    stats = [Skills.smc.to_i, Skills.mmc.to_i]
  elsif Stats.prof =~ /wizard/i
    stats = [Skills.emc.to_i, 0]
  elsif Stats.prof =~ /paladin|cleric|ranger/i
    stats = [Skills.smc.to_i, 0]
  else
    stats = [0, 0]
  end
  return (maxmana * 25 / 100) + (stats.max / 10) + (stats.min / 20)
end

def unnoded_pulse
  if Stats.prof =~ /warrior|rogue|sorcerer/i
    stats = [Skills.smc.to_i, Skills.emc.to_i]
  elsif Stats.prof =~ /empath|bard/i
    stats = [Skills.smc.to_i, Skills.mmc.to_i]
  elsif Stats.prof =~ /wizard/i
    stats = [Skills.emc.to_i, 0]
  elsif Stats.prof =~ /paladin|cleric|ranger/i
    stats = [Skills.smc.to_i, 0]
  else
    stats = [0, 0]
  end
  return (maxmana * 15 / 100) + (stats.max / 10) + (stats.min / 20)
end

require_relative("./lib/stash.rb")

def empty_hands
  waitrt?
  Lich::Stash::stash_hands(both: true)
end

def empty_hand
  right_hand = GameObj.right_hand
  left_hand = GameObj.left_hand

  unless (right_hand.id.nil? and ([Wounds.rightArm, Wounds.rightHand, Scars.rightArm, Scars.rightHand].max < 3)) or (left_hand.id.nil? and ([Wounds.leftArm, Wounds.leftHand, Scars.leftArm, Scars.leftHand].max < 3))
    if right_hand.id and ([Wounds.rightArm, Wounds.rightHand, Scars.rightArm, Scars.rightHand].max < 3 or [Wounds.leftArm, Wounds.leftHand, Scars.leftArm, Scars.leftHand].max = 3)
      waitrt?
      Lich::Stash::stash_hands(right: true)
    else
      waitrt?
      Lich::Stash::stash_hands(left: true)
    end
  end
end

def empty_right_hand
  waitrt?
  Lich::Stash::stash_hands(right: true)
end

def empty_left_hand
  waitrt?
  Lich::Stash::stash_hands(left: true)
end

def fill_hands
  waitrt?
  Lich::Stash::equip_hands(both: true)
end

def fill_hand
  waitrt?
  Lich::Stash::equip_hands()
end

def fill_right_hand
  waitrt?
  Lich::Stash::equip_hands(right: true)
end

def fill_left_hand
  waitrt?
  Lich::Stash::equip_hands(left: true)
end

def dothis(action, success_line)
  loop {
    Script.current.clear
    put action
    loop {
      line = get
      if line =~ success_line
        return line
      elsif line =~ /^(\.\.\.w|W)ait ([0-9]+) sec(onds)?\.$/
        if $2.to_i > 1
          sleep ($2.to_i - "0.5".to_f)
        else
          sleep 0.3
        end
        break
      elsif line == 'Sorry, you may only type ahead 1 command.'
        sleep 1
        break
      elsif line == 'You are still stunned.'
        wait_while { stunned? }
        break
      elsif line == 'That is impossible to do while unconscious!'
        100.times {
          unless line = get?
            sleep 0.1
          else
            break if line =~ /Your thoughts slowly come back to you as you find yourself lying on the ground\.  You must have been sleeping\.$|^You wake up from your slumber\.$/
          end
        }
        break
      elsif line == "You don't seem to be able to move to do that."
        100.times {
          unless line = get?
            sleep 0.1
          else
            break if line == 'The restricting force that envelops you dissolves away.'
          end
        }
        break
      elsif line == "You can't do that while entangled in a web."
        wait_while { checkwebbed }
        break
      elsif line == 'You find that impossible under the effects of the lullabye.'
        100.times {
          unless line = get?
            sleep 0.1
          else
            # fixme
            break if line == 'You shake off the effects of the lullabye.'
          end
        }
        break
      end
    }
  }
end

def dothistimeout(action, timeout, success_line)
  end_time = Time.now.to_f + timeout
  line = nil
  loop {
    Script.current.clear
    put action unless action.nil?
    loop {
      line = get?
      if line.nil?
        sleep 0.1
      elsif line =~ success_line
        return line
      elsif line =~ /^(\.\.\.w|W)ait ([0-9]+) sec(onds)?\.$/
        if $2.to_i > 1
          sleep ($2.to_i - "0.5".to_f)
        else
          sleep 0.3
        end
        end_time = Time.now.to_f + timeout
        break
      elsif line == 'Sorry, you may only type ahead 1 command.'
        sleep 1
        end_time = Time.now.to_f + timeout
        break
      elsif line == 'You are still stunned.'
        wait_while { stunned? }
        end_time = Time.now.to_f + timeout
        break
      elsif line == 'That is impossible to do while unconscious!'
        100.times {
          unless line = get?
            sleep 0.1
          else
            break if line =~ /Your thoughts slowly come back to you as you find yourself lying on the ground\.  You must have been sleeping\.$|^You wake up from your slumber\.$/
          end
        }
        break
      elsif line == "You don't seem to be able to move to do that."
        100.times {
          unless line = get?
            sleep 0.1
          else
            break if line == 'The restricting force that envelops you dissolves away.'
          end
        }
        break
      elsif line == "You can't do that while entangled in a web."
        wait_while { checkwebbed }
        break
      elsif line == 'You find that impossible under the effects of the lullabye.'
        100.times {
          unless line = get?
            sleep 0.1
          else
            # fixme
            break if line == 'You shake off the effects of the lullabye.'
          end
        }
        break
      end
      if Time.now.to_f >= end_time
        return nil
      end
    }
  }
end

$link_highlight_start = ''
$link_highlight_end = ''
$speech_highlight_start = ''
$speech_highlight_end = ''

def fb_to_sf(line)
  begin
    return line if line == "\r\n"

    line = line.gsub(/<c>/, "")
    return nil if line.gsub("\r\n", '').length < 1
    return line
  rescue
    $_CLIENT_.puts "--- Error: fb_to_sf: #{$!}"
    $_CLIENT_.puts '$_SERVERSTRING_: ' + $_SERVERSTRING_.to_s
  end
end
def sf_to_wiz(line)
  begin
    return line if line == "\r\n"

    if $sftowiz_multiline
      $sftowiz_multiline = $sftowiz_multiline + line
      line = $sftowiz_multiline
    end
    if (line.scan(/<pushStream[^>]*\/>/).length > line.scan(/<popStream[^>]*\/>/).length)
      $sftowiz_multiline = line
      return nil
    end
    if (line.scan(/<style id="\w+"[^>]*\/>/).length > line.scan(/<style id=""[^>]*\/>/).length)
      $sftowiz_multiline = line
      return nil
    end
    $sftowiz_multiline = nil
    if line =~ /<LaunchURL src="(.*?)" \/>/
      $_CLIENT_.puts "\034GSw00005\r\nhttps://www.play.net#{$1}\r\n"
    end
    if line =~ /<preset id='speech'>(.*?)<\/preset>/m
      line = line.sub(/<preset id='speech'>.*?<\/preset>/m, "#{$speech_highlight_start}#{$1}#{$speech_highlight_end}")
    end
    if line =~ /<pushStream id="thoughts"[^>]*>\[([^\\]+?)\]\s*(.*?)<popStream\/>/m
      thought_channel = $1
      msg = $2
      thought_channel.gsub!(' ', '-')
      msg.gsub!('<pushBold/>', '')
      msg.gsub!('<popBold/>', '')
      line = line.sub(/<pushStream id="thoughts".*<popStream\/>/m, "You hear the faint thoughts of [#{thought_channel}]-ESP echo in your mind:\r\n#{msg}")
    end
    if line =~ /<pushStream id="voln"[^>]*>\[Voln \- (?:<a[^>]*>)?([A-Z][a-z]+)(?:<\/a>)?\]\s*(".*")[\r\n]*<popStream\/>/m
      line = line.sub(/<pushStream id="voln"[^>]*>\[Voln \- (?:<a[^>]*>)?([A-Z][a-z]+)(?:<\/a>)?\]\s*(".*")[\r\n]*<popStream\/>/m, "The Symbol of Thought begins to burn in your mind and you hear #{$1} thinking, #{$2}\r\n")
    end
    if line =~ /<stream id="thoughts"[^>]*>([^:]+): (.*?)<\/stream>/m
      line = line.sub(/<stream id="thoughts"[^>]*>.*?<\/stream>/m, "You hear the faint thoughts of #{$1} echo in your mind:\r\n#{$2}")
    end
    if line =~ /<pushStream id="familiar"[^>]*>(.*)<popStream\/>/m
      line = line.sub(/<pushStream id="familiar"[^>]*>.*<popStream\/>/m, "\034GSe\r\n#{$1}\034GSf\r\n")
    end
    if line =~ /<pushStream id="death"\/>(.*?)<popStream\/>/m
      line = line.sub(/<pushStream id="death"\/>.*?<popStream\/>/m, "\034GSw00003\r\n#{$1}\034GSw00004\r\n")
    end
    if line =~ /<style id="roomName" \/>(.*?)<style id=""\/>/m
      line = line.sub(/<style id="roomName" \/>.*?<style id=""\/>/m, "\034GSo\r\n#{$1}\034GSp\r\n")
    end
    line.gsub!(/<style id="roomDesc"\/><style id=""\/>\r?\n/, '')
    if line =~ /<style id="roomDesc"\/>(.*?)<style id=""\/>/m
      desc = $1.gsub(/<a[^>]*>/, $link_highlight_start).gsub("</a>", $link_highlight_end)
      line = line.sub(/<style id="roomDesc"\/>.*?<style id=""\/>/m, "\034GSH\r\n#{desc}\034GSI\r\n")
    end
    line = line.gsub("</prompt>\r\n", "</prompt>")
    line = line.gsub("<pushBold/>", "\034GSL\r\n")
    line = line.gsub("<popBold/>", "\034GSM\r\n")
    line = line.gsub(/<pushStream id=["'](?:spellfront|inv|bounty|society|speech|talk)["'][^>]*\/>.*?<popStream[^>]*>/m, '')
    line = line.gsub(/<stream id="Spells">.*?<\/stream>/m, '')
    line = line.gsub(/<(compDef|inv|component|right|left|spell|prompt)[^>]*>.*?<\/\1>/m, '')
    line = line.gsub(/<[^>]+>/, '')
    line = line.gsub('&gt;', '>')
    line = line.gsub('&lt;', '<')
    line = line.gsub('&amp;', '&')
    return nil if line.gsub("\r\n", '').length < 1

    return line
  rescue
    $_CLIENT_.puts "--- Error: sf_to_wiz: #{$!}"
    $_CLIENT_.puts '$_SERVERSTRING_: ' + $_SERVERSTRING_.to_s
  end
end

def strip_xml(line)
  return line if line == "\r\n"

  if $strip_xml_multiline
    if $strip_xml_multiline =~ /^<pushStream id="atmospherics" \/>/ && line =~ /^<prompt time=/
      # Dragonrealms serves up malformed atmospherics, a lot.
      # If this multiline is for an atmospheric the next occurence of a prompt SHOULD be closing the stream.
      line = '<popStream id="atmospherics" />' + line
    end
    $strip_xml_multiline = $strip_xml_multiline + line
    line = $strip_xml_multiline
  end
  if (line.scan(/<pushStream[^>]*\/>/).length > line.scan(/<popStream[^>]*\/>/).length)
    $strip_xml_multiline = line
    return nil
  end
  $strip_xml_multiline = nil

  line = line.gsub(/<pushStream id=["'](?:spellfront|inv|bounty|society|speech|talk)["'][^>]*\/>.*?<popStream[^>]*>/m, '')
  line = line.gsub(/<stream id="Spells">.*?<\/stream>/m, '')
  line = line.gsub(/<(compDef|inv|component|right|left|spell|prompt)[^>]*>.*?<\/\1>/m, '')
  line = line.gsub(/<[^>]+>/, '')
  line = line.gsub('&gt;', '>')
  line = line.gsub('&lt;', '<')

  return nil if line.gsub("\n", '').gsub("\r", '').gsub(' ', '').length < 1

  return line
end

def monsterbold_start
  if $frontend =~ /^(?:wizard|avalon)$/
    "\034GSL\r\n"
  elsif $frontend =~ /^(?:stormfront|frostbite)$/
    '<pushBold/>'
  elsif $frontend == 'profanity'
    '<b>'
  else
    ''
  end
end

def monsterbold_end
  if $frontend =~ /^(?:wizard|avalon)$/
    "\034GSM\r\n"
  elsif $frontend =~ /^(?:stormfront|frostbite)$/
    '<popBold/>'
  elsif $frontend == 'profanity'
    '</b>'
  else
    ''
  end
end

def do_client(client_string)
  client_string.strip!
  #   Buffer.update(client_string, Buffer::UPSTREAM)
  client_string = UpstreamHook.run(client_string)
  #   Buffer.update(client_string, Buffer::UPSTREAM_MOD)
  return nil if client_string.nil?

  if client_string =~ /^(?:<c>)?#{$lich_char}(.+)$/
    cmd = $1
    if cmd =~ /^k$|^kill$|^stop$/
      if Script.running.empty?
        respond '--- Lich: no scripts to kill'
      else
        Script.running.last.kill
      end
    elsif cmd =~ /^p$|^pause$/
      if s = Script.running.reverse.find { |s| not s.paused? }
        s.pause
      else
        respond '--- Lich: no scripts to pause'
      end
      s = nil
    elsif cmd =~ /^u$|^unpause$/
      if s = Script.running.reverse.find { |s| s.paused? }
        s.unpause
      else
        respond '--- Lich: no scripts to unpause'
      end
      s = nil
    elsif cmd =~ /^ka$|^kill\s?all$|^stop\s?all$/
      did_something = false
      Script.running.find_all { |s| not s.no_kill_all }.each { |s| s.kill; did_something = true }
      respond('--- Lich: no scripts to kill') unless did_something
    elsif cmd =~ /^pa$|^pause\s?all$/
      did_something = false
      Script.running.find_all { |s| not s.paused? and not s.no_pause_all }.each { |s| s.pause; did_something = true }
      respond('--- Lich: no scripts to pause') unless did_something
    elsif cmd =~ /^ua$|^unpause\s?all$/
      did_something = false
      Script.running.find_all { |s| s.paused? and not s.no_pause_all }.each { |s| s.unpause; did_something = true }
      respond('--- Lich: no scripts to unpause') unless did_something
    elsif cmd =~ /^(k|kill|stop|p|pause|u|unpause)\s(.+)/
      action = $1
      target = $2
      script = Script.running.find { |s| s.name == target } || Script.hidden.find { |s| s.name == target } || Script.running.find { |s| s.name =~ /^#{target}/i } || Script.hidden.find { |s| s.name =~ /^#{target}/i }
      if script.nil?
        respond "--- Lich: #{target} does not appear to be running! Use ';list' or ';listall' to see what's active."
      elsif action =~ /^(?:k|kill|stop)$/
        script.kill
      elsif action =~ /^(?:p|pause)$/
        script.pause
      elsif action =~ /^(?:u|unpause)$/
        script.unpause
      end
      action = target = script = nil
    elsif cmd =~ /^list\s?(?:all)?$|^l(?:a)?$/i
      if cmd =~ /a(?:ll)?/i
        list = Script.running + Script.hidden
      else
        list = Script.running
      end
      if list.empty?
        respond '--- Lich: no active scripts'
      else
        respond "--- Lich: #{list.collect { |s| s.paused? ? "#{s.name} (paused)" : s.name }.join(", ")}"
      end
      list = nil
    elsif cmd =~ /^force\s+[^\s]+/
      if cmd =~ /^force\s+([^\s]+)\s+(.+)$/
        Script.start($1, $2, :force => true)
      elsif cmd =~ /^force\s+([^\s]+)/
        Script.start($1, :force => true)
      end
    elsif cmd =~ /^send |^s /
      if cmd.split[1] == "to"
        script = (Script.running + Script.hidden).find { |scr| scr.name == cmd.split[2].chomp.strip } || script = (Script.running + Script.hidden).find { |scr| scr.name =~ /^#{cmd.split[2].chomp.strip}/i }
        if script
          msg = cmd.split[3..-1].join(' ').chomp
          if script.want_downstream
            script.downstream_buffer.push(msg)
          else
            script.unique_buffer.push(msg)
          end
          respond "--- sent to '#{script.name}': #{msg}"
        else
          respond "--- Lich: '#{cmd.split[2].chomp.strip}' does not match any active script!"
        end
        script = nil
      else
        if Script.running.empty? and Script.hidden.empty?
          respond('--- Lich: no active scripts to send to.')
        else
          msg = cmd.split[1..-1].join(' ').chomp
          respond("--- sent: #{msg}")
          Script.new_downstream(msg)
        end
      end
    elsif cmd =~ /^(?:exec|e)(q)?(n)? (.+)$/
      cmd_data = $3
      ExecScript.start(cmd_data, flags={ :quiet => $1, :trusted => ($2.nil? and RUBY_VERSION =~ /^2\.[012]\./)  })
    elsif cmd =~ /^trust\s+(.*)/i
      script_name = $1
      if RUBY_VERSION =~ /^2\.[012]\./
        if File.exists?("#{SCRIPT_DIR}/#{script_name}.lic")
          if Script.trust(script_name)
            respond "--- Lich: '#{script_name}' is now a trusted script."
          else
            respond "--- Lich: '#{script_name}' is already trusted."
          end
        else
          respond "--- Lich: could not find script: #{script_name}"
        end
      else
        respond "--- Lich: this feature isn't available in this version of Ruby "
      end
    elsif cmd =~ /^(?:dis|un)trust\s+(.*)/i
      script_name = $1
      if RUBY_VERSION =~ /^2\.[012]\./
        if Script.distrust(script_name)
          respond "--- Lich: '#{script_name}' is no longer a trusted script."
        else
          respond "--- Lich: '#{script_name}' was not found in the trusted script list."
        end
      else
        respond "--- Lich: this feature isn't available in this version of Ruby "
      end
    elsif cmd =~ /^list\s?(?:un)?trust(?:ed)?$|^lt$/i
      if RUBY_VERSION =~ /^2\.[012]\./
        list = Script.list_trusted
        if list.empty?
          respond "--- Lich: no scripts are trusted"
        else
          respond "--- Lich: trusted scripts: #{list.join(', ')}"
        end
        list = nil
      else
        respond "--- Lich: this feature isn't available in this version of Ruby "
      end
    elsif cmd =~ /^set\s(.+)\s(on|off)/
      toggle_var = $1
      set_state = $2
      did_something = false
      begin
        Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) values(?,?);", toggle_var.to_s.encode('UTF-8'), set_state.to_s.encode('UTF-8'))
        did_something = true
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
      respond("--- Lich: toggle #{toggle_var} set #{set_state}") if did_something
      did_something = false
      nil
    elsif cmd =~ /^help$/i
      respond
      respond "Lich v#{LICH_VERSION}"
      respond
      respond 'built-in commands:'
      respond "   #{$clean_lich_char}<script name>             start a script"
      respond "   #{$clean_lich_char}force <script name>       start a script even if it's already running"
      respond "   #{$clean_lich_char}pause <script name>       pause a script"
      respond "   #{$clean_lich_char}p <script name>           ''"
      respond "   #{$clean_lich_char}unpause <script name>     unpause a script"
      respond "   #{$clean_lich_char}u <script name>           ''"
      respond "   #{$clean_lich_char}kill <script name>        kill a script"
      respond "   #{$clean_lich_char}k <script name>           ''"
      respond "   #{$clean_lich_char}pause                     pause the most recently started script that isn't aready paused"
      respond "   #{$clean_lich_char}p                         ''"
      respond "   #{$clean_lich_char}unpause                   unpause the most recently started script that is paused"
      respond "   #{$clean_lich_char}u                         ''"
      respond "   #{$clean_lich_char}kill                      kill the most recently started script"
      respond "   #{$clean_lich_char}k                         ''"
      respond "   #{$clean_lich_char}list                      show running scripts (except hidden ones)"
      respond "   #{$clean_lich_char}l                         ''"
      respond "   #{$clean_lich_char}pause all                 pause all scripts"
      respond "   #{$clean_lich_char}pa                        ''"
      respond "   #{$clean_lich_char}unpause all               unpause all scripts"
      respond "   #{$clean_lich_char}ua                        ''"
      respond "   #{$clean_lich_char}kill all                  kill all scripts"
      respond "   #{$clean_lich_char}ka                        ''"
      respond "   #{$clean_lich_char}list all                  show all running scripts"
      respond "   #{$clean_lich_char}la                        ''"
      respond
      respond "   #{$clean_lich_char}exec <code>               executes the code as if it was in a script"
      respond "   #{$clean_lich_char}e <code>                  ''"
      respond "   #{$clean_lich_char}execq <code>              same as #{$clean_lich_char}exec but without the script active and exited messages"
      respond "   #{$clean_lich_char}eq <code>                 ''"
      respond
      if (RUBY_VERSION =~ /^2\.[012]\./)
        respond "   #{$clean_lich_char}trust <script name>       let the script do whatever it wants"
        respond "   #{$clean_lich_char}distrust <script name>    restrict the script from doing things that might harm your computer"
        respond "   #{$clean_lich_char}list trusted              show what scripts are trusted"
        respond "   #{$clean_lich_char}lt                        ''"
        respond
      end
      respond "   #{$clean_lich_char}send <line>               send a line to all scripts as if it came from the game"
      respond "   #{$clean_lich_char}send to <script> <line>   send a line to a specific script"
      respond
      respond "   #{$clean_lich_char}set <variable> [on|off]   set a global toggle variable on or off"
      respond
      respond 'If you liked this help message, you might also enjoy:'
      respond "   #{$clean_lich_char}lnet help"
      respond "   #{$clean_lich_char}magic help     (infomon must be running)"
      respond "   #{$clean_lich_char}go2 help"
      respond "   #{$clean_lich_char}repository help"
      respond "   #{$clean_lich_char}alias help"
      respond "   #{$clean_lich_char}vars help"
      respond "   #{$clean_lich_char}autostart help"
      respond
    else
      if cmd =~ /^([^\s]+)\s+(.+)/
        Script.start($1, $2)
      else
        Script.start(cmd)
      end
    end
  else
    if $offline_mode
      respond "--- Lich: offline mode: ignoring #{client_string}"
    else
      client_string = "#{$cmd_prefix}bbs" if ($frontend =~ /^(?:wizard|avalon)$/) and (client_string == "#{$cmd_prefix}\egbbk\n") # launch forum
      Game._puts client_string
    end
    $_CLIENTBUFFER_.push client_string
  end
  Script.new_upstream(client_string)
end

def report_errors(&block)
  begin
    block.call
  rescue
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue SyntaxError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue SystemExit
    nil
  rescue SecurityError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue ThreadError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue SystemStackError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue Exception
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue ScriptError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue LoadError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue NoMemoryError
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  rescue
    respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
    Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
  end
end

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
  @@elevated_load = proc { SpellRanks.load }
  @@elevated_save = proc { SpellRanks.save }
  attr_reader :name
  attr_accessor :minorspiritual, :majorspiritual, :cleric, :minorelemental, :majorelemental, :minormental, :ranger, :sorcerer, :wizard, :bard, :empath, :paladin, :arcanesymbols, :magicitemuse, :monk

  def SpellRanks.load
    if $SAFE == 0
      if File.exists?("#{DATA_DIR}/#{XMLData.game}/spell-ranks.dat")
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
    else
      @@elevated_load.call
    end
  end

  def SpellRanks.save
    if $SAFE == 0
      begin
        File.open("#{DATA_DIR}/#{XMLData.game}/spell-ranks.dat", 'wb') { |f|
          f.write(Marshal.dump([@@timestamp, @@list]))
        }
      rescue
        respond "--- Lich: error: SpellRanks.save: #{$!}"
        Lich.log "error: SpellRanks.save: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      end
    else
      @@elevated_save.call
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
                #                        while $_SERVERSTRING_.scan('<pushStream').length > $_SERVERSTRING_.scan('<popStream').length
                #                           $_SERVERSTRING_.concat(@@socket.gets)
                #                        end
                $_SERVERBUFFER_.push($_SERVERSTRING_)
                if alt_string = DownstreamHook.run($_SERVERSTRING_)
                  #                           Buffer.update(alt_string, Buffer::DOWNSTREAM_MOD)
                  if alt_string =~ /<resource picture=.*roomName/
                    if (Lich.display_lichid =~ /on|true|yes/ && Lich.display_uid =~ /on|true|yes/) || (Lich.display_lichid.nil? && Lich.display_uid.nil?) #default on
                      alt_string.sub!(']') { " - #{Room.current.id}] (u#{XMLData.room_id})" }
                    elsif Lich.display_lichid =~ /on|true|yes/ || Lich.display_lichid.nil? # don't force an entry
                      alt_string.sub!(']') { " - #{Room.current.id}]" }
                    elsif Lich.display_uid =~ /on|true|yes/ || Lich.display_uid.nil? # don't force an entry
                      alt_string.sub!(']') { "] (u#{XMLData.room_id})" }
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
                  if $_SERVERSTRING_ =~ /^<settingsInfo .*?space not found /
                    $_SERVERSTRING_.sub!('space not found', '')
                  end
                  begin
                    REXML::Document.parse_stream($_SERVERSTRING_, XMLData)
                    # XMLData.parse($_SERVERSTRING_)
                  rescue
                    unless $!.to_s =~ /invalid byte sequence/
                      if $_SERVERSTRING_ =~ /<[^>]+='[^=>'\\]+'[^=>']+'[\s>]/
                        # Simu has a nasty habbit of bad quotes in XML.  <tag attr='this's that'>
                        $_SERVERSTRING_.gsub!(/(<[^>]+=)'([^=>'\\]+'[^=>']+)'([\s>])/) { "#{$1}\"#{$2}\"#{$3}" }
                        retry
                      end
                      $stdout.puts "--- error: server_thread: #{$!}"
                      Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                    end
                    XMLData.reset
                  end
                  Script.new_downstream_xml($_SERVERSTRING_)
                  stripped_server = strip_xml($_SERVERSTRING_)
                  stripped_server.split("\r\n").each { |line|
                    @@buffer.update(line) if TESTING
                    if !Map.last_seen_objects && line =~ /(You also see .*)$/
                      Map.last_seen_objects = $1
                    end
                    unless line =~ /^\s\*\s[A-Z][a-z]+ (?:returns home from a hard day of adventuring\.|joins the adventure\.|(?:is off to a rough start!  (?:H|She) )?just bit the dust!|was just incinerated!|was just vaporized!|has been vaporized!|has disconnected\.)$|^ \* The death cry of [A-Z][a-z]+ echoes in your mind!$|^\r*\n*$/
                      Script.new_downstream(line) unless line.empty?
                    end
                  }
                end
              rescue
                $stdout.puts "--- error: server_thread: #{$!}"
                Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              end
            end
          rescue Exception
            Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $stdout.puts "--- error: server_thread: #{$!}"
            sleep 0.2
            retry unless $_CLIENT_.closed? or @@socket.closed? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed|An established connection was aborted by the software in your host machine./i)
          rescue
            Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $stdout.puts "--- error: server_thread: #{$!}"
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

    # #updating PSM3 abilities via breakout - 20210801
    require_relative("./lib/armor.rb")
    require_relative("./lib/cman.rb")
    require_relative("./lib/feat.rb")
    require_relative("./lib/shield.rb")
    require_relative("./lib/weapon.rb")

    class Stats
      @@race ||= 'unknown'
      @@prof ||= 'unknown'
      @@gender ||= 'unknown'
      @@age ||= 0
      @@level ||= 0
      @@str ||= [0, 0]
      @@con ||= [0, 0]
      @@dex ||= [0, 0]
      @@agi ||= [0, 0]
      @@dis ||= [0, 0]
      @@aur ||= [0, 0]
      @@log ||= [0, 0]
      @@int ||= [0, 0]
      @@wis ||= [0, 0]
      @@inf ||= [0, 0]
      @@enhanced_str ||= [0, 0]
      @@enhanced_con ||= [0, 0]
      @@enhanced_dex ||= [0, 0]
      @@enhanced_agi ||= [0, 0]
      @@enhanced_dis ||= [0, 0]
      @@enhanced_aur ||= [0, 0]
      @@enhanced_log ||= [0, 0]
      @@enhanced_int ||= [0, 0]
      @@enhanced_wis ||= [0, 0]
      @@enhanced_inf ||= [0, 0]
      def Stats.race;         @@race; end

      def Stats.race=(val);   @@race = val; end

      def Stats.prof;         @@prof; end

      def Stats.prof=(val);   @@prof = val; end

      def Stats.gender;       @@gender; end

      def Stats.gender=(val); @@gender = val; end

      def Stats.age;          @@age; end

      def Stats.age=(val);    @@age = val; end

      def Stats.level;        @@level; end

      def Stats.level=(val);  @@level = val; end

      def Stats.str;          @@str; end

      def Stats.str=(val);    @@str = val; end

      def Stats.con;          @@con; end

      def Stats.con=(val);    @@con = val; end

      def Stats.dex;          @@dex; end

      def Stats.dex=(val);    @@dex = val; end

      def Stats.agi;          @@agi; end

      def Stats.agi=(val);    @@agi = val; end

      def Stats.dis;          @@dis; end

      def Stats.dis=(val);    @@dis = val; end

      def Stats.aur;          @@aur; end

      def Stats.aur=(val);    @@aur = val; end

      def Stats.log;          @@log; end

      def Stats.log=(val);    @@log = val; end

      def Stats.int;          @@int; end

      def Stats.int=(val);    @@int = val; end

      def Stats.wis;          @@wis; end

      def Stats.wis=(val);    @@wis = val; end

      def Stats.inf;          @@inf; end

      def Stats.inf=(val);    @@inf = val; end

      def Stats.enhanced_str;          @@enhanced_str; end

      def Stats.enhanced_str=(val);    @@enhanced_str = val; end

      def Stats.enhanced_con;          @@enhanced_con; end

      def Stats.enhanced_con=(val);    @@enhanced_con = val; end

      def Stats.enhanced_dex;          @@enhanced_dex; end

      def Stats.enhanced_dex=(val);    @@enhanced_dex = val; end

      def Stats.enhanced_agi;          @@enhanced_agi; end

      def Stats.enhanced_agi=(val);    @@enhanced_agi = val; end

      def Stats.enhanced_dis;          @@enhanced_dis; end

      def Stats.enhanced_dis=(val);    @@enhanced_dis = val; end

      def Stats.enhanced_aur;          @@enhanced_aur; end

      def Stats.enhanced_aur=(val);    @@enhanced_aur = val; end

      def Stats.enhanced_log;          @@enhanced_log; end

      def Stats.enhanced_log=(val);    @@enhanced_log = val; end

      def Stats.enhanced_int;          @@enhanced_int; end

      def Stats.enhanced_int=(val);    @@enhanced_int = val; end

      def Stats.enhanced_wis;          @@enhanced_wis; end

      def Stats.enhanced_wis=(val);    @@enhanced_wis = val; end

      def Stats.enhanced_inf;          @@enhanced_inf; end

      def Stats.enhanced_inf=(val);    @@enhanced_inf = val; end

      def Stats.exp
        if XMLData.next_level_text =~ /until next level/
          exp_threshold = [2500, 5000, 10000, 17500, 27500, 40000, 55000, 72500, 92500, 115000, 140000, 167000, 197500, 230000, 265000, 302000, 341000, 382000, 425000, 470000, 517000, 566000, 617000, 670000, 725000, 781500, 839500, 899000, 960000, 1022500, 1086500, 1152000, 1219000, 1287500, 1357500, 1429000, 1502000, 1576500, 1652500, 1730000, 1808500, 1888000, 1968500, 2050000, 2132500, 2216000, 2300500, 2386000, 2472500, 2560000, 2648000, 2736500, 2825500, 2915000, 3005000, 3095500, 3186500, 3278000, 3370000, 3462500, 3555500, 3649000, 3743000, 3837500, 3932500, 4028000, 4124000, 4220500, 4317500, 4415000, 4513000, 4611500, 4710500, 4810000, 4910000, 5010500, 5111500, 5213000, 5315000, 5417500, 5520500, 5624000, 5728000, 5832500, 5937500, 6043000, 6149000, 6255500, 6362500, 6470000, 6578000, 6686500, 6795500, 6905000, 7015000, 7125500, 7236500, 7348000, 7460000, 7572500]
          exp_threshold[XMLData.level] - XMLData.next_level_text.slice(/[0-9]+/).to_i
        else
          XMLData.next_level_text.slice(/[0-9]+/).to_i
        end
      end

      def Stats.exp=(val); nil; end

      def Stats.serialize
        [@@race, @@prof, @@gender, @@age, Stats.exp, @@level, @@str, @@con, @@dex, @@agi, @@dis, @@aur, @@log, @@int, @@wis, @@inf, @@enhanced_str, @@enhanced_con, @@enhanced_dex, @@enhanced_agi, @@enhanced_dis, @@enhanced_aur, @@enhanced_log, @@enhanced_int, @@enhanced_wis, @@enhanced_inf]
      end

      def Stats.load_serialized=(array)
        for i in 16..25
          array[i] ||= [0, 0]
        end
        @@race, @@prof, @@gender, @@age = array[0..3]
        @@level, @@str, @@con, @@dex, @@agi, @@dis, @@aur, @@log, @@int, @@wis, @@inf, @@enhanced_str, @@enhanced_con, @@enhanced_dex, @@enhanced_agi, @@enhanced_dis, @@enhanced_aur, @@enhanced_log, @@enhanced_int, @@enhanced_wis, @@enhanced_inf = array[5..25]
      end
    end

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
          expiry.to_i > Time.now.to_i
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
    class GameObj
      @@loot          = Array.new
      @@npcs          = Array.new
      @@npc_status    = Hash.new
      @@pcs           = Array.new
      @@pc_status     = Hash.new
      @@inv           = Array.new
      @@contents      = Hash.new
      @@right_hand    = nil
      @@left_hand     = nil
      @@room_desc     = Array.new
      @@fam_loot      = Array.new
      @@fam_npcs      = Array.new
      @@fam_pcs       = Array.new
      @@fam_room_desc = Array.new
      @@type_data     = Hash.new
      @@sellable_data = Hash.new
      @@elevated_load = proc { GameObj.load_data }

      attr_reader :id
      attr_accessor :noun, :name, :before_name, :after_name

      def initialize(id, noun, name, before = nil, after = nil)
        @id = id
        @noun = noun
        @noun = 'lapis' if @noun == 'lapis lazuli'
        @noun = 'hammer' if @noun == "Hammer of Kai"
        @noun = 'mother-of-pearl' if (@noun == 'pearl') and (@name =~ /mother\-of\-pearl/)
        @name = name
        @before_name = before
        @after_name = after
      end

      def type
        GameObj.load_data if @@type_data.empty?
        list = @@type_data.keys.find_all { |t| (@name =~ @@type_data[t][:name] or @noun =~ @@type_data[t][:noun]) and (@@type_data[t][:exclude].nil? or @name !~ @@type_data[t][:exclude]) }
        if list.empty?
          nil
        else
          list.join(',')
        end
      end

      def sellable
        GameObj.load_data if @@sellable_data.empty?
        list = @@sellable_data.keys.find_all { |t| (@name =~ @@sellable_data[t][:name] or @noun =~ @@sellable_data[t][:noun]) and (@@sellable_data[t][:exclude].nil? or @name !~ @@sellable_data[t][:exclude]) }
        if list.empty?
          nil
        else
          list.join(',')
        end
      end

      def status
        if @@npc_status.keys.include?(@id)
          @@npc_status[@id]
        elsif @@pc_status.keys.include?(@id)
          @@pc_status[@id]
        elsif @@loot.find { |obj| obj.id == @id } or @@inv.find { |obj| obj.id == @id } or @@room_desc.find { |obj| obj.id == @id } or @@fam_loot.find { |obj| obj.id == @id } or @@fam_npcs.find { |obj| obj.id == @id } or @@fam_pcs.find { |obj| obj.id == @id } or @@fam_room_desc.find { |obj| obj.id == @id } or (@@right_hand.id == @id) or (@@left_hand.id == @id) or @@contents.values.find { |list| list.find { |obj| obj.id == @id } }
          nil
        else
          'gone'
        end
      end

      def status=(val)
        if @@npcs.any? { |npc| npc.id == @id }
          @@npc_status[@id] = val
        elsif @@pcs.any? { |pc| pc.id == @id }
          @@pc_status[@id] = val
        else
          nil
        end
      end

      def to_s
        @noun
      end

      def empty?
        false
      end

      def contents
        @@contents[@id].dup
      end

      def GameObj.[](val)
        if val.class == String
          if val =~ /^\-?[0-9]+$/
            obj = @@inv.find { |o| o.id == val } || @@loot.find { |o| o.id == val } || @@npcs.find { |o| o.id == val } || @@pcs.find { |o| o.id == val } || [@@right_hand, @@left_hand].find { |o| o.id == val } || @@room_desc.find { |o| o.id == val }
          elsif val.split(' ').length == 1
            obj = @@inv.find { |o| o.noun == val } || @@loot.find { |o| o.noun == val } || @@npcs.find { |o| o.noun == val } || @@pcs.find { |o| o.noun == val } || [@@right_hand, @@left_hand].find { |o| o.noun == val } || @@room_desc.find { |o| o.noun == val }
          else
            obj = @@inv.find { |o| o.name == val } || @@loot.find { |o| o.name == val } || @@npcs.find { |o| o.name == val } || @@pcs.find { |o| o.name == val } || [@@right_hand, @@left_hand].find { |o| o.name == val } || @@room_desc.find { |o| o.name == val } || @@inv.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@loot.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@npcs.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@pcs.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || [@@right_hand, @@left_hand].find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@room_desc.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@inv.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || @@loot.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || @@npcs.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || @@pcs.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || [@@right_hand, @@left_hand].find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || @@room_desc.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i }
          end
        elsif val.class == Regexp
          obj = @@inv.find { |o| o.name =~ val } || @@loot.find { |o| o.name =~ val } || @@npcs.find { |o| o.name =~ val } || @@pcs.find { |o| o.name =~ val } || [@@right_hand, @@left_hand].find { |o| o.name =~ val } || @@room_desc.find { |o| o.name =~ val }
        end
      end

      def GameObj
        @noun
      end

      def full_name
        "#{@before_name}#{' ' unless @before_name.nil? or @before_name.empty?}#{name}#{' ' unless @after_name.nil? or @after_name.empty?}#{@after_name}"
      end

      def GameObj.new_npc(id, noun, name, status = nil)
        obj = GameObj.new(id, noun, name)
        @@npcs.push(obj)
        @@npc_status[id] = status
        obj
      end

      def GameObj.new_loot(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@loot.push(obj)
        obj
      end

      def GameObj.new_pc(id, noun, name, status = nil)
        obj = GameObj.new(id, noun, name)
        @@pcs.push(obj)
        @@pc_status[id] = status
        obj
      end

      def GameObj.new_inv(id, noun, name, container = nil, before = nil, after = nil)
        obj = GameObj.new(id, noun, name, before, after)
        if container
          @@contents[container].push(obj)
        else
          @@inv.push(obj)
        end
        obj
      end

      def GameObj.new_room_desc(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@room_desc.push(obj)
        obj
      end

      def GameObj.new_fam_room_desc(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@fam_room_desc.push(obj)
        obj
      end

      def GameObj.new_fam_loot(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@fam_loot.push(obj)
        obj
      end

      def GameObj.new_fam_npc(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@fam_npcs.push(obj)
        obj
      end

      def GameObj.new_fam_pc(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@fam_pcs.push(obj)
        obj
      end

      def GameObj.new_right_hand(id, noun, name)
        @@right_hand = GameObj.new(id, noun, name)
      end

      def GameObj.right_hand
        @@right_hand.dup
      end

      def GameObj.new_left_hand(id, noun, name)
        @@left_hand = GameObj.new(id, noun, name)
      end

      def GameObj.left_hand
        @@left_hand.dup
      end

      def GameObj.clear_loot
        @@loot.clear
      end

      def GameObj.clear_npcs
        @@npcs.clear
        @@npc_status.clear
      end

      def GameObj.clear_pcs
        @@pcs.clear
        @@pc_status.clear
      end

      def GameObj.clear_inv
        @@inv.clear
      end

      def GameObj.clear_room_desc
        @@room_desc.clear
      end

      def GameObj.clear_fam_room_desc
        @@fam_room_desc.clear
      end

      def GameObj.clear_fam_loot
        @@fam_loot.clear
      end

      def GameObj.clear_fam_npcs
        @@fam_npcs.clear
      end

      def GameObj.clear_fam_pcs
        @@fam_pcs.clear
      end

      def GameObj.npcs
        if @@npcs.empty?
          nil
        else
          @@npcs.dup
        end
      end

      def GameObj.loot
        if @@loot.empty?
          nil
        else
          @@loot.dup
        end
      end

      def GameObj.pcs
        if @@pcs.empty?
          nil
        else
          @@pcs.dup
        end
      end

      def GameObj.inv
        if @@inv.empty?
          nil
        else
          @@inv.dup
        end
      end

      def GameObj.room_desc
        if @@room_desc.empty?
          nil
        else
          @@room_desc.dup
        end
      end

      def GameObj.fam_room_desc
        if @@fam_room_desc.empty?
          nil
        else
          @@fam_room_desc.dup
        end
      end

      def GameObj.fam_loot
        if @@fam_loot.empty?
          nil
        else
          @@fam_loot.dup
        end
      end

      def GameObj.fam_npcs
        if @@fam_npcs.empty?
          nil
        else
          @@fam_npcs.dup
        end
      end

      def GameObj.fam_pcs
        if @@fam_pcs.empty?
          nil
        else
          @@fam_pcs.dup
        end
      end

      def GameObj.clear_container(container_id)
        @@contents[container_id] = Array.new
      end

      def GameObj.delete_container(container_id)
        @@contents.delete(container_id)
      end

      def GameObj.targets
        a = Array.new
        XMLData.current_target_ids.each { |id|
          if (npc = @@npcs.find { |n| n.id == id }) and (npc.status !~ /dead|gone/)
            a.push(npc)
          end
        }
        a
      end

      def GameObj.dead
        dead_list = Array.new
        for obj in @@npcs
          dead_list.push(obj) if obj.status == "dead"
        end
        return nil if dead_list.empty?

        return dead_list
      end

      def GameObj.containers
        @@contents.dup
      end

      def GameObj.load_data(filename = nil)
        if $SAFE == 0
          if filename.nil?
            if File.exists?("#{DATA_DIR}/gameobj-data.xml")
              filename = "#{DATA_DIR}/gameobj-data.xml"
            elsif File.exists?("#{SCRIPT_DIR}/gameobj-data.xml") # deprecated
              filename = "#{SCRIPT_DIR}/gameobj-data.xml"
            else
              filename = "#{DATA_DIR}/gameobj-data.xml"
            end
          end
          if File.exists?(filename)
            begin
              @@type_data = Hash.new
              @@sellable_data = Hash.new
              File.open(filename) { |file|
                doc = REXML::Document.new(file.read)
                doc.elements.each('data/type') { |e|
                  if type = e.attributes['name']
                    @@type_data[type] = Hash.new
                    @@type_data[type][:name]    = Regexp.new(e.elements['name'].text) unless e.elements['name'].text.nil? or e.elements['name'].text.empty?
                    @@type_data[type][:noun]    = Regexp.new(e.elements['noun'].text) unless e.elements['noun'].text.nil? or e.elements['noun'].text.empty?
                    @@type_data[type][:exclude] = Regexp.new(e.elements['exclude'].text) unless e.elements['exclude'].text.nil? or e.elements['exclude'].text.empty?
                  end
                }
                doc.elements.each('data/sellable') { |e|
                  if sellable = e.attributes['name']
                    @@sellable_data[sellable] = Hash.new
                    @@sellable_data[sellable][:name]    = Regexp.new(e.elements['name'].text) unless e.elements['name'].text.nil? or e.elements['name'].text.empty?
                    @@sellable_data[sellable][:noun]    = Regexp.new(e.elements['noun'].text) unless e.elements['noun'].text.nil? or e.elements['noun'].text.empty?
                    @@sellable_data[sellable][:exclude] = Regexp.new(e.elements['exclude'].text) unless e.elements['exclude'].text.nil? or e.elements['exclude'].text.empty?
                  end
                }
              }
              true
            rescue
              @@type_data = nil
              @@sellable_data = nil
              echo "error: GameObj.load_data: #{$!}"
              respond $!.backtrace[0..1]
              false
            end
          else
            @@type_data = nil
            @@sellable_data = nil
            echo "error: GameObj.load_data: file does not exist: #{filename}"
            false
          end
        else
          @@elevated_load.call
        end
      end

      def GameObj.type_data
        @@type_data
      end

      def GameObj.sellable_data
        @@sellable_data
      end
    end
    #
    # start deprecated stuff
    #
    class RoomObj < GameObj
    end
    #
    # end deprecated stuff
    #
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

class Spellsong
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
    puts "
   -h, --help               Display this message and exit
   -v, --version            Display version number and credits and exit

   --home=<directory>      Set home directory for Lich (default: location of this file)
   --scripts=<directory>   Set directory for script files (default: home/scripts)
   --data=<directory>      Set directory for data files (default: home/data)
   --temp=<directory>      Set directory for temp files (default: home/temp)
   --logs=<directory>      Set directory for log files (default: home/logs)
   --maps=<directory>      Set directory for map images (default: home/maps)
   --backup=<directory>    Set directory for backups (default: home/backup)

   --start-scripts=<script1,script2,etc>   Start the specified scripts after login

    "
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
    unless File.exists?(argv_options[:sal])
      if ARGV.join(' ') =~ /([A-Z]:\\.+?\.(?:sal|~xt))/i
        argv_options[:sal] = $1
      end
    end
    unless File.exists?(argv_options[:sal])
      if defined?(Wine)
        argv_options[:sal] = "#{Wine::PREFIX}/drive_c/#{argv_options[:sal][3..-1].split('\\').join('/')}"
      end
    end
    bad_args.clear
  else
    bad_args.push(arg)
  end
end

if ARGV.any? { |arg| (arg == '-h') or (arg == '--help') }
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
end

if arg = ARGV.find { |a| a == '--hosts-dir' }
  i = ARGV.index(arg)
  ARGV.delete_at(i)
  hosts_dir = ARGV[i]
  ARGV.delete_at(i)
  if hosts_dir and File.exists?(hosts_dir)
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
  unless File.exists?(argv_options[:sal])
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

  @launch_data = nil
  require_relative("./lib/eaccess.rb")

  if ARGV.include?('--login')
    if File.exists?("#{DATA_DIR}/entry.dat")
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
    else
      data = entry_data.find { |d| (d[:char_name] == char_name) }
    end
    unless data
      data = { char_name: char_name }
      data[:game_code] = "DR"
      user_id = ARGV[ARGV.index('--user_id')+1]
      data[:user_id] = user_id
      password = ARGV[ARGV.index('--password')+1]
      data[:password] = password
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
        @launch_data.push "CUSTOMLAUNCH=#{login_info[:custom_launch]}"
        if login_info[:custom_launch_dir]
          @launch_data.push "CUSTOMLAUNCHDIR=#{login_info[:custom_launch_dir]}"
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
      launcher_cmd = "open -n -b Avalon \"%1\""
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
        while File.exists?(sal_filename)
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

        if (RUBY_PLATFORM =~ /mingw|win/i) && (RUBY_PLATFORM !~ /darwin/i)
          system ("start #{launcher_cmd}")
        elsif defined?(Wine) and (game != 'AVALON') # Wine on linux
          spawn "#{Wine::BIN} #{launcher_cmd}"
        else # macOS and linux - does not account for WINE on linux
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

  #
  # drop superuser privileges
  #
  unless (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
    Lich.log "info: dropping superuser privileges..."
    begin
      Process.uid = `id -ru`.strip.to_i
      Process.gid = `id -rg`.strip.to_i
      Process.egid = `id -rg`.strip.to_i
      Process.euid = `id -ru`.strip.to_i
    rescue SecurityError
      Lich.log "error: failed to drop superuser privileges: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
    rescue SystemCallError
      Lich.log "error: failed to drop superuser privileges: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
    rescue
      Lich.log "error: failed to drop superuser privileges: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
    end
  end
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
        #
        $_CLIENT_.gets
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
        end
        if $_DETACHABLE_CLIENT_
          begin
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
