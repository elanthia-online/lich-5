# frozen_string_literal: true

# One Lich session per OS process, for the cross-process Settings specs.
#
# Usage: ruby settings_session_worker.rb <data_dir> <game> <char> <script>
#
# Loads the real lib/lich.rb (open_sequel_sqlite and init_db, so the table has
# the production PRIMARY KEY), class_exts/nilclass.rb (always loaded by the
# Lich runtime), and the real Settings stack: settings.rb with its
# DatabaseAdapter, gamesettings.rb and charsettings.rb. Only the game and IO
# boundary is stubbed: XMLData (game and name), Script.current.name, Lich.log
# and Lich::Messaging.msg (both captured so a spec can inspect them).
#
# Reads one command per line on stdin and answers with one JSON line on stdout.
# Values are JSON so a spec can write false, nil, numbers and hashes.
#
#   set   <api> <key> <json>    api[key] = value               => "ok"
#   get   <api> <key>           api[key], proxies unwrapped     => value
#   nset  <api> <key> <sub> <json>
#                               api[key][sub] = value (through the proxy)
#                                                               => "ok"
#   push  <api> <key> <json>    api[key].push(value)            => "ok"
#   burst <api> <prefix> <n>    api["<prefix>_<i>"] = i, i < n  => "ok"
#   row   <api>                 the row as stored in the database
#   threads <api> <prefix> <t> <n> <f>
#                               like several scripts of one session: stores a
#                               filler key of f entries (so each write takes
#                               a while), then t threads each set
#                               api["<prefix>_<thread>_<i>"] = i for i < n,
#                               while another thread keeps writing the uservars
#                               table through Lich.db           => "ok"
#   nburst <api> <key> <prefix> <n>
#                               api[key]["<prefix>_<i>"] = i, i < n, each through
#                               a fresh proxy                   => "ok"
#   pburst <api> <key> <prefix> <n>
#                               api[key].push("<prefix>_<i>"), i < n => "ok"
#   msgs                        Messaging and log lines so far  => [[kind, text], ...]
#
# A script may keep a proxy and write through it later. These commands keep
# one under a name and use it:
#
#   keep  <name> <api> <key>    kept[name] = api[key]           => "ok"
#   keep  <name> <api> <key> <sub>
#                               kept[name] = api[key][sub]      => "ok"
#   keeproot <name> <api>       kept[name] = the root proxy: to_hash for G and
#                               C, character_proxy for I, game_proxy for IG
#                                                               => "ok"
#   keepfind <name> <api> <key> <field> <json>
#                               kept[name] = api[key].find { |e| e[field] == value }
#                                                               => "ok"
#   kset  <name> <sub> <json>   kept[name][sub] = value         => "ok"
#   kcall <name> <method> <json array>
#                               kept[name].<method>(*args)      => result
#   kdelete_if <name> <json>    kept[name].delete_if { |e| e == value } => "ok"
#   kget  <name>                kept[name], unwrapped           => value
#   keach <name> <field> <json> kept[name].each { |e| e[field] = value } => "ok"
#   kveach <name> <field> <json>
#                               kept[name].each { |_k, v| v[field] = value } => "ok"
#   ksortpush <name> <json>     kept[name].sort.push(value)     => "ok"
#
# <api> is G (GameSettings), C (CharSettings), S (Settings), I (InstanceSettings)
# or IG (InstanceSettings.game, which reads and writes through a root proxy).
# Set LICH_SPEC_BUSY_TIMEOUT_MS to shorten the SQLite busy timeout.
# Set LICH_SPEC_STORE_LOG to a file path to have the worker append one line to
# it each time update_settings is about to try its conditional store (after it
# has read the row), so a spec can tell that a write has read the row and is
# waiting for the lock.

require 'json'
require 'sequel'
require 'sqlite3'

data_dir, game, char, script_name = ARGV
abort 'usage: settings_session_worker.rb <data_dir> <game> <char> <script>' unless script_name

DATA_DIR = data_dir
LIB_ROOT = File.expand_path('../../lib', __dir__)

require File.join(LIB_ROOT, 'lich.rb')

$captured = []

module Lich
  def self.log(msg)
    $captured << ['log', msg.to_s]
  end

  def self.deprecated(*_args); end

  if ENV['LICH_SPEC_BUSY_TIMEOUT_MS']
    def self.sqlite_busy_timeout_ms
      ENV['LICH_SPEC_BUSY_TIMEOUT_MS'].to_i
    end
  end

  module Messaging
    def self.msg(kind, text)
      $captured << [kind.to_s, text.to_s]
    end
  end
end

require File.join(LIB_ROOT, 'common/class_exts/nilclass')

module XMLData
  class << self
    attr_accessor :game, :name
  end
end
XMLData.game = game
XMLData.name = char

class Script
  Current = Struct.new(:name)

  class << self
    attr_accessor :current
  end
end
Script.current = Script::Current.new(script_name)

Lich.init_db

require File.join(LIB_ROOT, 'common/settings')
require File.join(LIB_ROOT, 'common/settings/gamesettings')
require File.join(LIB_ROOT, 'common/settings/charsettings')

if ENV['LICH_SPEC_STORE_LOG']
  Lich::Common::DatabaseAdapter.prepend(Module.new do
    private

    def store_if_unchanged(*args)
      File.open(ENV['LICH_SPEC_STORE_LOG'], 'a') { |f| f.puts('store') }
      super
    end
  end)
end

APIS = {
  'G'  => Lich::Common::GameSettings,
  'C'  => Lich::Common::CharSettings,
  'S'  => Lich::Common::Settings,
  'I'  => Lich::Common::InstanceSettings,
  'IG' => Lich::Common::InstanceSettings.game,
}.freeze

def row_for(api)
  scope, script = case api
                  when 'G' then [XMLData.game, Script.current.name]
                  when 'C' then ["#{XMLData.game}:#{XMLData.name}", Script.current.name]
                  when 'S' then [':', Script.current.name]
                  when 'I' then ["#{XMLData.game}:#{XMLData.name}", Lich::Common::InstanceSettings::SCRIPT_NAME]
                  when 'IG' then [XMLData.game, Lich::Common::InstanceSettings::SCRIPT_NAME]
                  end
  Lich::Common::Settings.instance_variable_get(:@db_adapter).get_settings(script, scope)
end

def run_threads(api, prefix, thread_count, writes, filler)
  api["#{prefix}_filler"] = (0...filler).to_h { |i| ["f#{i}", 'x' * 50] }
  done = false
  raw_writer = Thread.new do
    blob = SQLite3::Blob.new(Marshal.dump({ 'v' => 'x' * 2000 }))
    until done
      begin
        Lich.db.execute('INSERT OR REPLACE INTO uservars (scope, hash) VALUES (?, ?)', ["#{XMLData.game}:#{XMLData.name}", blob])
      rescue SQLite3::Exception => e
        $captured << ['error', "uservars writer: #{e.class}: #{e.message}"]
      end
      sleep 0.001
    end
  end
  writers = Array.new(thread_count) do |t|
    Thread.new { writes.times { |i| api["#{prefix}_#{t}_#{i}"] = i } }
  end
  writers.each(&:join)
  done = true
  raw_writer.join
  'ok'
end

KEPT = {}

def keep_root(api)
  case api
  when 'G' then Lich::Common::GameSettings.to_hash
  when 'C' then Lich::Common::CharSettings.to_hash
  when 'I' then Lich::Common::InstanceSettings.character_proxy
  when 'IG' then Lich::Common::InstanceSettings.game_proxy
  end
end

def plain(value)
  value.is_a?(Lich::Common::SettingsProxy) ? JSON.parse(JSON.generate(value.target)) : value
end

$stdout.sync = true
while (line = $stdin.gets)
  cmd, api, key, rest = line.chomp.split(' ', 4)
  out = begin
    case cmd
    when 'set'
      APIS.fetch(api)[key] = JSON.parse(rest)
      'ok'
    when 'get'
      plain(APIS.fetch(api)[key])
    when 'nset'
      sub, json = rest.split(' ', 2)
      APIS.fetch(api)[key][sub] = JSON.parse(json)
      'ok'
    when 'push'
      APIS.fetch(api)[key].push(JSON.parse(rest))
      'ok'
    when 'burst'
      Integer(rest).times { |i| APIS.fetch(api)["#{key}_#{i}"] = i }
      'ok'
    when 'nburst'
      sub_prefix, count = rest.split
      Integer(count).times { |i| APIS.fetch(api)[key]["#{sub_prefix}_#{i}"] = i }
      'ok'
    when 'pburst'
      sub_prefix, count = rest.split
      Integer(count).times { |i| APIS.fetch(api)[key].push("#{sub_prefix}_#{i}") }
      'ok'
    when 'keep'
      source_key, sub = rest.split
      KEPT[api] = sub ? APIS.fetch(key)[source_key][sub] : APIS.fetch(key)[source_key]
      'ok'
    when 'keeproot'
      KEPT[api] = keep_root(key)
      'ok'
    when 'keepfind'
      source_key, field, json = rest.split(' ', 3)
      wanted = JSON.parse(json)
      KEPT[api] = APIS.fetch(key)[source_key].find { |e| e[field] == wanted }
      'ok'
    when 'kset'
      KEPT.fetch(api)[key] = JSON.parse(rest)
      'ok'
    when 'kcall'
      plain(KEPT.fetch(api).public_send(key.to_sym, *JSON.parse(rest)))
    when 'kdelete_if'
      wanted = JSON.parse([key, rest].compact.join(' '))
      KEPT.fetch(api).delete_if { |e| e == wanted }
      'ok'
    when 'kget'
      plain(KEPT.fetch(api))
    when 'keach'
      value = JSON.parse(rest)
      KEPT.fetch(api).each { |e| e[key] = value }
      'ok'
    when 'kveach'
      value = JSON.parse(rest)
      KEPT.fetch(api).each { |_k, v| v[key] = value }
      'ok'
    when 'ksortpush'
      KEPT.fetch(api).sort.push(JSON.parse([key, rest].compact.join(' ')))
      'ok'
    when 'row'
      row_for(api)
    when 'threads'
      run_threads(APIS.fetch(api), key, *rest.split.map { |v| Integer(v) })
    when 'msgs'
      $captured
    else
      { 'error' => "unknown command #{cmd.inspect}" }
    end
  rescue StandardError => e
    { 'error' => "#{e.class}: #{e.message}" }
  end
  puts JSON.generate([out])
end
