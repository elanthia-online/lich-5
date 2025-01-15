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

# Lich is maintained by Matt Lowe (tillmen@lichproject.org
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

require 'base64'
require 'digest/md5'
require 'digest/sha1'
require 'drb/drb'
require 'json'
require 'monitor'
require 'net/http'
require 'ostruct'
require 'resolv'
require 'rexml/document'
require 'rexml/streamlistener'
require 'socket'
require 'stringio'
require 'terminal-table'
require 'time'
require 'yaml'
require 'zlib'

# TODO: Move all local requires to top of file
if defined? LIB_DIR
  require_relative 'constants'
else
  require_relative './lib/constants'
end
require_relative 'lib/version'

require_relative 'lib/lich'
require_relative 'lib/init'
require_relative 'lib/common/front-end'
require_relative 'lib/util/update'

# TODO: Need to split out initiatilzation functions to move require to top of file
require_relative 'lib/common/gtk'
require_relative 'lib/common/db_store'
# 2024-06-13 carve out
require_relative 'lib/common/class_exts/nilclass'
require_relative 'lib/common/class_exts/numeric'
require_relative 'lib/common/class_exts/string'
require_relative 'lib/common/class_exts/stringproc'
require_relative 'lib/common/class_exts/synchronizedsocket'
require_relative 'lib/common/limitedarray'
require_relative 'lib/common/xmlparser'
require_relative 'lib/common/upstreamhook'
require_relative 'lib/common/downstreamhook'
require_relative 'lib/common/settings/settings'
require_relative 'lib/common/settings/gamesettings'
require_relative 'lib/common/settings/charsettings'
require_relative 'lib/common/uservars'
require_relative 'lib/common/vars'
require_relative 'lib/sessionvars'

# Script classes move to lib 230305
require_relative 'lib/common/script'
require_relative 'lib/common/watchfor'

## adding util to the list of defs
require_relative 'lib/util/util'
require_relative 'lib/messaging'
require_relative 'lib/global_defs'
require_relative 'lib/common/buffer'
require_relative 'lib/common/sharedbuffer'
require_relative 'lib/gemstone/spellranks'
require_relative 'lib/games'
require_relative 'lib/common/gameobj'

#
# Program start
#
require_relative 'lib/main/argv_options'
require_relative 'lib/main/main'

include Lich::Common
XMLData = Lich::Common::XMLParser.new

#
# Start deprecated stuff
#
JUMP = Exception.exception('JUMP')
JUMP_ERROR = Exception.exception('JUMP_ERROR')
require_relative 'lib/deprecated'
#
# End deprecated stuff
#

if defined?(Gtk)
  Thread.current.priority = -10
  Gtk.main
else
  @main_thread.join
end
exit
