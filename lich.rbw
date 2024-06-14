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

# process ARGV for constants before loading constants.rb: issue #304
for arg in ARGV
  if arg =~ /^--(?:home)=(.+)[\\\/]?$/i
    LICH_DIR = $1
  elsif arg =~ /^--temp=(.+)[\\\/]?$/i
    TEMP_DIR = $1
  elsif arg =~ /^--scripts=(.+)[\\\/]?$/i
    SCRIPT_DIR = $1
  elsif arg =~ /^--maps=(.+)[\\\/]?$/i
    MAP_DIR = $1
  elsif arg =~ /^--logs=(.+)[\\\/]?$/i
    LOG_DIR = $1
  elsif arg =~ /^--backup=(.+)[\\\/]?$/i
    BACKUP_DIR = $1
  elsif arg =~ /^--data=(.+)[\\\/]?$/i
    DATA_DIR = $1
  elsif arg =~ /^--lib=(.+)[\\\/]?$/i
    LIB_DIR = $1
  end
end

require 'time'
require 'socket'
require 'rexml/document'
require 'rexml/streamlistener'
require 'stringio'
require 'zlib'
require 'drb/drb'
require 'resolv'
require 'digest/md5'
require 'json'
require 'terminal-table'

# TODO: Move all local requires to top of file
if defined? LIB_DIR
  require File.join(LIB_DIR, 'constants.rb')
else
  require_relative('./lib/constants.rb')
end
require File.join(LIB_DIR, 'version.rb')

require File.join(LIB_DIR, 'lich.rb')
require File.join(LIB_DIR, 'init.rb')
require File.join(LIB_DIR, 'front-end.rb')
require File.join(LIB_DIR, 'update.rb')

# TODO: Need to split out initiatilzation functions to move require to top of file
require File.join(LIB_DIR, 'gtk.rb')
require File.join(LIB_DIR, 'gui-login.rb')
require File.join(LIB_DIR, 'db_store.rb')
class NilClass
  def dup
    nil
  end

  def method_missing(*_args)
    nil
  end

  def split(*_val)
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

  def call(*_a)
    proc { eval(@string) }.call
  end

  def _dump(_d = nil)
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
      @delegate.puts(*args, &block)
    }
  end

  def puts_if(*args)
    @mutex.synchronize {
      if yield
        @delegate.puts(*args)
        return true
      else
        return false
      end
    }
  end

  def write(*args, &block)
    @mutex.synchronize {
      @delegate.write(*args, &block)
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

require File.join(LIB_DIR, 'xmlparser.rb')

class UpstreamHook
  @@upstream_hooks ||= Hash.new
  @@upstream_hook_sources ||= Hash.new

  def UpstreamHook.add(name, action)
    unless action.class == Proc
      echo "UpstreamHook: not a Proc (#{action})"
      return false
    end
    @@upstream_hook_sources[name] = (Script.current.name || "Unknown")
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
    @@upstream_hook_sources.delete(name)
    @@upstream_hooks.delete(name)
  end

  def UpstreamHook.list
    @@upstream_hooks.keys.dup
  end

  def UpstreamHook.sources
    info_table = Terminal::Table.new :headings => ['Hook', 'Source'],
                                     :rows => @@upstream_hook_sources.to_a,
                                     :style => {:all_separators => true}
    Lich::Messaging.mono(info_table.to_s)
  end

  def UpstreamHook.hook_sources
    @@upstream_hook_sources
  end

end

class DownstreamHook
  @@downstream_hooks ||= Hash.new
  @@downstream_hook_sources ||= Hash.new

  def DownstreamHook.add(name, action)
    unless action.class == Proc
      echo "DownstreamHook: not a Proc (#{action})"
      return false
    end
    @@downstream_hook_sources[name] = (Script.current.name || "Unknown")
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
    @@downstream_hook_sources.delete(name)
    @@downstream_hooks.delete(name)
  end

  def DownstreamHook.list
    @@downstream_hooks.keys.dup
  end

  def DownstreamHook.sources
    info_table = Terminal::Table.new :headings => ['Hook', 'Source'],
                                     :rows => @@downstream_hook_sources.to_a,
                                     :style => {:all_separators => true}
    Lich::Messaging.mono(info_table.to_s)
  end

  def DownstreamHook.hook_sources
    @@downstream_hook_sources
  end

end

module Settings
  settings    = Hash.new
  md5_at_load = Hash.new
  @@settings = proc { |scope|
    unless (script = Script.current)
      respond '--- error: Settings: unknown calling script'
      next nil
    end
    unless scope =~ /^#{XMLData.game}\:#{XMLData.name}$|^#{XMLData.game}$|^\:$/
      respond '--- error: Settings: invalid scope'
      next nil
    end
    Lich.db_mutex.synchronize {
      unless settings[script.name] and settings[script.name][scope]
        begin
          marshal_hash = Lich.db.get_first_value('SELECT hash FROM script_auto_settings WHERE script=? AND scope=?;', [script.name.encode('UTF-8'), scope.encode('UTF-8')])
        rescue SQLite3::BusyException
          sleep 0.1
          retry
        end
        settings[script.name] ||= Hash.new
        if marshal_hash.nil?
          settings[script.name][scope] = Hash.new
        else
          begin
            hash = Marshal.load(marshal_hash)
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
    Lich.db_mutex.synchronize {
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
              Lich.db.execute('INSERT OR REPLACE INTO script_auto_settings(script,scope,hash) VALUES(?,?,?);', [script_name.encode('UTF-8'), scope.encode('UTF-8'), blob])
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
  @@loaded = false
  @@load = proc {
    Lich.db_mutex.synchronize {
      unless @@loaded
        begin
          h = Lich.db.get_first_value('SELECT hash FROM uservars WHERE scope=?;', ["#{XMLData.game}:#{XMLData.name}".encode('UTF-8')])
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
    Lich.db_mutex.synchronize {
      if @@loaded
        if Digest::MD5.hexdigest(@@vars.to_s) != md5
          md5 = Digest::MD5.hexdigest(@@vars.to_s)
          blob = SQLite3::Blob.new(Marshal.dump(@@vars))
          begin
            Lich.db.execute('INSERT OR REPLACE INTO uservars(scope,hash) VALUES(?,?);', ["#{XMLData.game}:#{XMLData.name}".encode('UTF-8'), blob])
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
require File.join(LIB_DIR, 'script.rb')
require File.join(LIB_DIR, 'watchfor.rb')

## adding util to the list of defs

require File.join(LIB_DIR, 'util.rb')
require File.join(LIB_DIR, 'messaging.rb')
require File.join(LIB_DIR, 'global_defs.rb')
require File.join(LIB_DIR, 'buffer.rb')

require File.join(LIB_DIR, 'sharedbuffer.rb')

require File.join(LIB_DIR, 'spellranks.rb')

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
      @@infomon_loaded = false

      def self.clean_gs_serverstring(server_string)
        # The Rift, Scatter is broken...
        if server_string =~ /<compDef id='room text'><\/compDef>/
          server_string.sub!(/(.*)\s\s<compDef id='room text'><\/compDef>/) { "<compDef id='room desc'>#{$1}</compDef>" }
        end
        return server_string
      end

      @atmospherics = false
      @combat_count = 0
      @end_combat_tags = ["<prompt", "<clearStream", "<component", "<pushStream id=\"percWindow"]

      def self.clean_dr_serverstring(server_string)
        ## Clear out superfluous tags
        server_string = server_string.gsub("<pushStream id=\"combat\" /><popStream id=\"combat\" />", "")
        server_string = server_string.gsub("<popStream id=\"combat\" /><pushStream id=\"combat\" />", "")

        # DR occasionally has poor encoding in text, which causes parsing errors.
        # One example of this is in the discern text for the spell Membrach's Greed
        # which gets sent as Membrach\x92s Greed. This fixes the bad encoding until
        # Simu fixes it.
        if server_string =~ /\x92/
          Lich.log "Detected poorly encoded apostrophe: #{server_string.inspect}"
          server_string.gsub!("\x92", "'")
          Lich.log "Changed poorly encoded apostrophe to: #{server_string.inspect}"
        end

        ## Fix combat wrapping components - Why, DR, Why?
        server_string = server_string.gsub("<pushStream id=\"combat\" /><component id=", "<component id=")
        # server_string = server_string.gsub("<pushStream id=\"combat\" /><prompt ","<prompt ")

        # Fixes xml with \r\n in the middle of it like:
        # <component id='room exits'>Obvious paths: clockwise, widdershins.\r\n
        # <compass></compass></component>\r\n
        # We close the first line and in the next segment, we remove the trailing bits
        # Because we can only match line by line, this couldn't be fixed in one matching block...
        if server_string == "<component id='room exits'>Obvious paths: clockwise, widdershins.\r\n"
          Lich.log "Unclosed component tag detected: #{server_string.inspect}"
          server_string = "<component id='room exits'>Obvious paths: <d>clockwise</d>, <d>widdershins</d>.<compass></compass></component>"
          Lich.log "Unclosed component tag fixed to: #{server_string.inspect}"
          # retry
        end
        # This is an actual DR line "<compass></compass></component>\r\n" which happens when the above is sent... subbing it out since we fix the tag above.
        if server_string == "<compass></compass></component>\r\n"
          Lich.log "Extraneous closed tag detected: #{server_string.inspect}"
          server_string = ""
          Lich.log "Extraneous closed tag fixed: #{server_string.inspect}"
        end

        # "<component id='room objs'>  You also see a granite altar with several candles and a water jug on it, and a granite font.\r\n"
        # "<component id='room extra'>Placed around the interior, you see: some furniture and other bits of interest.\r\n
        # Followed by in a new line.
        # "</component>\r\n"
        if server_string =~ /^<component id='room (?:objs|extra)'>[^<]*(?!<\/component>)\r\n/
          Lich.log "Open-ended room objects component id tag: #{server_string.inspect}"
          server_string.gsub!("\r\n", "</component>")
          Lich.log "Open-ended room objects component id tag fixed to: #{server_string.inspect}"
        end
        # "</component>\r\n"
        if server_string == "</component>\r\n"
          Lich.log "Extraneous closing tag detected and deleted: #{server_string.inspect}"
          server_string = ""
        end

        ## Fix duplicate pushStrings
        while server_string.include?("<pushStream id=\"combat\" /><pushStream id=\"combat\" />")
          server_string = server_string.gsub("<pushStream id=\"combat\" /><pushStream id=\"combat\" />", "<pushStream id=\"combat\" />")
        end

        if @combat_count > 0
          @end_combat_tags.each do |tag|
            # server_string = "<!-- looking for tag: #{tag}" + server_string
            if server_string.include?(tag)
              server_string = server_string.gsub(tag, "<popStream id=\"combat\" />" + tag) unless server_string.include?("<popStream id=\"combat\" />")
              @combat_count -= 1
            end
            if server_string.include?("<pushStream id=\"combat\" />")
              server_string = server_string.gsub("<pushStream id=\"combat\" />", "")
            end
          end
        end

        @combat_count += server_string.scan("<pushStream id=\"combat\" />").length
        @combat_count -= server_string.scan("<popStream id=\"combat\" />").length
        @combat_count = 0 if @combat_count < 0

        if @atmospherics
          @atmospherics = false
          server_string.prepend('<popStream id="atmospherics" />') unless server_string =~ /<popStream id="atmospherics" \/>/
        end
        if server_string =~ /<pushStream id="familiar" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # Cry For Help spell is broken...
          server_string.sub!('<pushStream id="familiar" />', '')
        elsif server_string =~ /<pushStream id="atmospherics" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # pet pigs in DragonRealms are broken...
          server_string.sub!('<pushStream id="atmospherics" />', '')
        elsif (server_string =~ /<pushStream id="atmospherics" \/>/)
          @atmospherics = true
        end

        return server_string
      end

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
            while ($_SERVERSTRING_ = @@socket.gets)
              @@last_recv = Time.now
              @@_buffer.update($_SERVERSTRING_) if TESTING
              begin
                $cmd_prefix = String.new if $_SERVERSTRING_ =~ /^\034GSw/

                unless (XMLData.game.nil? or XMLData.game.empty?) 
                  unless Module.const_defined?(:GameLoader)
                    require File.join(LIB_DIR, 'game-loader.rb')
                    GameLoader.load!
                  end
                end

                if XMLData.game =~ /^GS/
                  $_SERVERSTRING_ = self.clean_gs_serverstring($_SERVERSTRING_)
                else
                  $_SERVERSTRING_ = self.clean_dr_serverstring($_SERVERSTRING_)
                end

                $_SERVERBUFFER_.push($_SERVERSTRING_)

                if !@@autostarted and $_SERVERSTRING_ =~ /<app char/
                  Script.start('autostart') if Script.exists?('autostart')
                  @@autostarted = true
                  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(RECOMMENDED_RUBY)
                    ruby_warning = Terminal::Table.new
                    ruby_warning.title = "Ruby Recommended Version Warning"
                    ruby_warning.add_row(["Please update your Ruby installation."])
                    ruby_warning.add_row(["You're currently running Ruby v#{Gem::Version.new(RUBY_VERSION)}!"])
                    ruby_warning.add_row(["It's recommended to run Ruby v#{Gem::Version.new(RECOMMENDED_RUBY)} or higher!"])
                    ruby_warning.add_row(["Future Lich5 releases will soon require this newer version."])
                    ruby_warning.add_row([" "])
                    ruby_warning.add_row(["Visit the following link for info on updating:"])
                    if XMLData.game =~ /^GS/
                      ruby_warning.add_row(["https://gswiki.play.net/Lich:Software/Installation"])
                    elsif XMLData.game =~ /^DR/
                      ruby_warning.add_row(["https://github.com/elanthia-online/lich-5/wiki/Documentation-for-Installing-and-Upgrading-Lich"])
                    else
                      ruby_warning.add_row(["Unknown game type #{XMLData.game} detected."])
                      ruby_warning.add_row(["Unsure of proper documentation, please seek assistance via discord!"])
                    end
                    ruby_warning.to_s.split("\n").each { |row|
                      Lich::Messaging.mono(Lich::Messaging.monsterbold(row))
                    }
                  end
                end

                if !@@infomon_loaded && defined?(Infomon) && !XMLData.name.empty?
                  ExecScript.start("Infomon.redo!", { :quiet => true, :name => "infomon_reset" }) if XMLData.game !~ /^DR/ && Infomon.db_refresh_needed?
                  @@infomon_loaded = true
                end

                if @@autostarted and !@@cli_scripts and $_SERVERSTRING_ =~ /roomDesc/
                  if (arg = ARGV.find { |a| a =~ /^\-\-start\-scripts=/ })
                    for script_name in arg.sub('--start-scripts=', '').split(',')
                      Script.start(script_name)
                    end
                  end
                  @@cli_scripts = true
                  Lich.log("info: logged in as #{XMLData.game}:#{XMLData.name}")
                end

                if (alt_string = DownstreamHook.run($_SERVERSTRING_))
                  #                           Buffer.update(alt_string, Buffer::DOWNSTREAM_MOD)
                  if (Lich.display_lichid == true or Lich.display_uid == true) and XMLData.game =~ /^GS/ and alt_string =~ /^<resource picture=.*roomName/
                    if (Lich.display_lichid == true and Lich.display_uid == true)
                      alt_string.sub!(']') { " - #{Map.current.id}] (u#{XMLData.room_id})" }
                    elsif Lich.display_lichid == true
                      alt_string.sub!(']') { " - #{Map.current.id}]" }
                    elsif Lich.display_uid == true
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
                      while (data = $_SERVERSTRING_.match(/'([^=>]*'[^=>]*)'/))
                        Lich.log "Invalid nested single quotes XML tags detected: #{$_SERVERSTRING_.inspect}"
                        $_SERVERSTRING_.gsub!(data[1], data[1].gsub!(/'/, '&apos;'))
                        Lich.log "Invalid nested single quotes XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                        retry
                      end
                      # Fixes invalid XML with nested double quotes in it such as:
                      # <subtitle=" - [Avlea's Bows, "The Straight and Arrow"]">
                      while (data = $_SERVERSTRING_.match(/"([^=]*"[^=]*)"/))
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
                  if Module.const_defined?(:GameLoader) && XMLData.game =~ /^GS/
                    infomon_serverstring = $_SERVERSTRING_.dup
                    Infomon::XMLParser.parse(infomon_serverstring)
                    stripped_infomon_serverstring = strip_xml(infomon_serverstring, type: 'infomon')
                    stripped_infomon_serverstring.split("\r\n").each { |line|
                      unless line.empty?
                        Infomon::Parser.parse(line)
                      end
                    }
                  end
                  Script.new_downstream_xml($_SERVERSTRING_)
                  stripped_server = strip_xml($_SERVERSTRING_, type: 'main')
                  stripped_server.split("\r\n").each { |line|
                    @@buffer.update(line) if TESTING
                    if defined?(Map) and Map.method_defined?(:last_seen_objects) and !Map.last_seen_objects and line =~ /(You also see .*)$/
                      Map.last_seen_objects = $1 # DR only: copy loot line to Map.last_seen_objects
                    end

                    Script.new_downstream(line) if !line.empty?
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
        if (script = Script.current)
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

    require File.join(LIB_DIR, 'gameobj.rb')

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

      def Wounds.method_missing(_arg = nil)
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

      def Scars.method_missing(_arg = nil)
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

XMLData = XMLParser.new

#
# Start deprecated stuff
#

$version = LICH_VERSION
$room_count = 0
$psinet = false
$stormfront = true

def survivepoison?
  echo 'survivepoison? called, but there is no XML for poison rate'
  return true
end

def survivedisease?
  echo 'survivepoison? called, but there is no XML for disease rate'
  return true
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

module Settings
  def Settings.load; Lich.deprecated('Settings.load', 'not using, not applicable,', caller[0]); end

  def Settings.save_all; Lich.deprecated('Settings.save_all', 'not using, not applicable,', caller[0]); end

  def Settings.clear; Lich.deprecated('Settings.clear', 'not using, not applicable,', caller[0]); end

  def Settings.auto=(val); Lich.deprecated('Settings.auto=(val)', 'not using, not applicable,', caller[0]); end

  def Settings.auto; Lich.deprecated('Settings.auto', 'not using, not applicable,', caller[0]); end

  def Settings.autoload; Lich.deprecated('Settings.autoload', 'not using, not applicable,', caller[0]); end
end

module GameSettings
  def GameSettings.load; Lich.deprecated('GameSettings.load', 'not using, not applicable,', caller[0]); end

  def GameSettings.save; Lich.deprecated('GameSettings.save', 'not using, not applicable,', caller[0]); end

  def GameSettings.save_all; Lich.deprecated('GameSettings.save_all', 'not using, not applicable,', caller[0]); end

  def GameSettings.clear; Lich.deprecated('GameSettings.clear', 'not using, not applicable,', caller[0]); end

  def GameSettings.auto=(val); Lich.deprecated('GameSettings.auto=(val)', 'not using, not applicable,', caller[0]); end

  def GameSettings.auto; Lich.deprecated('GameSettings.auto', 'not using, not applicable,', caller[0]); end

  def GameSettings.autoload; Lich.deprecated('GameSettings.autoload', 'not using, not applicable,', caller[0]); end
end

module CharSettings
  def CharSettings.load; Lich.deprecated('CharSettings.load', 'not using, not applicable,', caller[0]); end

  def CharSettings.save; Lich.deprecated('CharSettings.save', 'not using, not applicable,', caller[0]); end

  def CharSettings.save_all; Lich.deprecated('CharSettings.save_all', 'not using, not applicable,', caller[0]); end

  def CharSettings.clear; Lich.deprecated('CharSettings.clear', 'not using, not applicable,', caller[0]); end

  def CharSettings.auto=(val); Lich.deprecated('CharSettings.auto=(val)', 'not using, not applicable,', caller[0]); end

  def CharSettings.auto; Lich.deprecated('CharSettings.auto', 'not using, not applicable,', caller[0]); end

  def CharSettings.autoload; Lich.deprecated('CharSettings.autoload', 'not using, not applicable,', caller[0]); end
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
require File.join(LIB_DIR, 'uservars.rb')

#
# Program start
#
require File.join(LIB_DIR, 'main', 'argv_options.rb')
require File.join(LIB_DIR, 'main', 'main.rb')

if defined?(Gtk)
  Thread.current.priority = -10
  Gtk.main
else
  @main_thread.join
end
exit
