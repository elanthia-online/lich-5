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
#2024-06-13 carve out
require File.join(LIB_DIR, 'class_exts', 'nilclass.rb')
require File.join(LIB_DIR, 'class_exts', 'numeric.rb')
require File.join(LIB_DIR, 'class_exts', 'string.rb')
require File.join(LIB_DIR, 'class_exts', 'stringproc.rb')
require File.join(LIB_DIR, 'class_exts', 'synchronizedsocket.rb')
require File.join(LIB_DIR, 'limitedarray.rb')
require File.join(LIB_DIR, 'xmlparser.rb')
require File.join(LIB_DIR, 'upstreamhook.rb')
require File.join(LIB_DIR, 'downstreamhook.rb')
require File.join(LIB_DIR, 'settings', 'settings.rb')
require File.join(LIB_DIR, 'settings', 'gamesettings.rb')

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
require File.join(LIB_DIR, 'vars.rb')

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

require File.join(LIB_DIR, 'games.rb')
require File.join(LIB_DIR, 'gameobj.rb')

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
