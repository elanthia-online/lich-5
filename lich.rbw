#!/usr/bin/env ruby
# encoding: US-ASCII

######
# Lich - https://github.com/elanthia-online/lich-5
# Licensed under BSD 3-Clause License (see LICENSE file)
######

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

if defined? LIB_DIR
  require File.join(LIB_DIR, 'constants.rb')
else
  require_relative('./lib/constants.rb')
end
require File.join(LIB_DIR, 'version.rb')
require File.join(LIB_DIR, 'gemcheck.rb')
Lich::GemCheck.verify!(*Lich::GemCheck.startup_groups)

# Must run before lib/init.rb's `require 'gtk3'` -- install! sets up a
# wrapper around gobject-introspection's converter registration that has to
# be in place before gdk3/pango's own loaders run, or it can't do its job.
# Requiring the file alone does not install anything (deliberately -- see
# lib/util/gtk_compaction.rb); install! has to be called explicitly.
require File.join(LIB_DIR, 'util', 'gtk_compaction.rb')
Lich::Util::GtkCompaction.install!

# TODO: Move all local requires to top of file
require 'base64'
require 'digest/md5'
require 'digest/sha1'
require 'drb/drb'
require 'json'
require 'monitor'
require 'net/http'
require 'ostruct'
require 'ox'
require 'resolv'
require 'rexml/document'
require 'rexml/streamlistener'
require 'socket'
require 'stringio'
require 'terminal-table'
require 'time'
require 'yaml'
require 'zlib'

require File.join(LIB_DIR, 'lich.rb')
require File.join(LIB_DIR, 'init.rb')
require File.join(LIB_DIR, 'common', 'front-end.rb')
require File.join(LIB_DIR, 'internal_api', 'active_sessions.rb')
require File.join(LIB_DIR, 'api', 'active_sessions.rb')
require File.join(LIB_DIR, 'update.rb')

# TODO: Need to split out initiatilzation functions to move require to top of file
require File.join(LIB_DIR, 'common', 'gtk.rb')
# require File.join(LIB_DIR, 'common','gui-login.rb')
require File.join(LIB_DIR, 'common', 'db_store.rb')
# 2025-03-14 added extensions
require File.join(LIB_DIR, 'common', 'class_exts', 'hash.rb')
require File.join(LIB_DIR, 'common', 'class_exts', 'matchdata.rb')
# 2024-06-13 carve out
require File.join(LIB_DIR, 'common', 'class_exts', 'nilclass.rb')
require File.join(LIB_DIR, 'common', 'class_exts', 'numeric.rb')
require File.join(LIB_DIR, 'common', 'class_exts', 'string.rb')
require File.join(LIB_DIR, 'common', 'class_exts', 'stringproc.rb')
require File.join(LIB_DIR, 'common', 'class_exts', 'synchronizedsocket.rb')
require File.join(LIB_DIR, 'common', 'client_input_dispatcher.rb')
require File.join(LIB_DIR, 'common', 'detachable_client_registry.rb')
require File.join(LIB_DIR, 'common', 'limitedarray.rb')
require File.join(LIB_DIR, 'common', 'xmlparser.rb')
require File.join(LIB_DIR, 'common', 'upstreamhook.rb')
require File.join(LIB_DIR, 'common', 'downstreamhook.rb')
require File.join(LIB_DIR, 'common', 'socket_read_hook.rb')
require File.join(LIB_DIR, 'common', 'settings.rb')
require File.join(LIB_DIR, 'common', 'feature_flags.rb')
require File.join(LIB_DIR, 'common', 'settings', 'gamesettings.rb')
require File.join(LIB_DIR, 'common', 'settings', 'charsettings.rb')
require File.join(LIB_DIR, 'common', 'vars.rb')
require File.join(LIB_DIR, 'sessionvars.rb')

# Script classes move to lib 230305
require File.join(LIB_DIR, 'common', 'script.rb')
require File.join(LIB_DIR, 'common', 'watchfor.rb')

## adding util to the list of defs

require File.join(LIB_DIR, 'util', 'util.rb')
require File.join(LIB_DIR, 'util', 'opts.rb')
require File.join(LIB_DIR, 'util', 'memoryreleaser.rb')
require File.join(LIB_DIR, 'messaging.rb')
require File.join(LIB_DIR, 'global_defs.rb')
require File.join(LIB_DIR, 'common', 'buffer.rb')

require File.join(LIB_DIR, 'common', 'sharedbuffer.rb')

require File.join(LIB_DIR, 'gemstone', 'spellranks.rb')

require File.join(LIB_DIR, 'common', 'socketconfigurator.rb')
require File.join(LIB_DIR, 'common', 'reusable_tcp_server.rb')
require File.join(LIB_DIR, 'games.rb')
require File.join(LIB_DIR, 'common', 'gameobj.rb')
require File.join(LIB_DIR, 'common', 'arg_parser.rb')
require File.join(LIB_DIR, 'common', 'setup_files.rb')
require File.join(LIB_DIR, 'common', 'settings_transformer.rb')

#
# Program start
#
require File.join(LIB_DIR, 'main', 'argv_options.rb')
require File.join(LIB_DIR, 'main', 'main.rb')

include Lich::Common

XMLData = Lich::Common::XMLParser.new

#
# Start deprecated stuff
#
require File.join(LIB_DIR, 'deprecated.rb')
#
# End deprecated stuff
#
require File.join(LIB_DIR, 'common', 'uservars.rb')

## was here ##

if defined?(Gtk)
  Thread.current.priority = -10
  Gtk.main
  # Terminal teardown backstop: Gtk.main has returned, so we are on the GTK
  # thread with the loop unwound. Sweep any widgets a route that bypassed the
  # orchestrated exits left alive, before the interpreter finalizer disposes
  # them in an unsafe order and segfaults. Idempotent after a clean shutdown.
  Lich::Common.shutdown_gtk_before_exit(direct: true)
else
  @main_thread.join
end
exit
