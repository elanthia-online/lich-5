# frozen_string_literal: true

# One Lich session for the DRBanking multi-session specs, run as its own OS
# process. It loads the real NilClass extensions, Settings stack and DRBanking
# against DATA_DIR/lich.db3, which every session shares. Only XMLData,
# Messaging, logging and the SQLite opener (lib/lich.rb can't be loaded) are
# stand-ins.
#
# Usage: ruby drbanking_session_worker.rb <lich_root> <data_dir> <game> <name>
# Reads one command per line on stdin and answers with one JSON line:
#   all | mine | reload | total_all       -> the method's return value
#   update <Town> <copper>                -> DRBanking.update_balance
#   parse <line...>                       -> DRBanking.parse (in a Crossings bank)
#   reset | reset_all                     -> reset_character! / reset_all!
#   messages                              -> Messaging lines since the last call
# Errors are reported as {"error": "..."} so the spec can show them.

require 'json'
require 'ostruct'

lich_root, data_dir, game, name = ARGV
DATA_DIR = data_dir

module Lich
  @logs = []
  class << self
    attr_reader :logs

    def log(msg)
      @logs << msg.to_s
    end

    def deprecated(*_args)
      nil
    end
  end

  module Messaging
    @lines = []
    class << self
      attr_reader :lines

      def msg(_type, text)
        @lines << text.to_s
      end
    end
  end
end

require File.join(lich_root, 'spec/support/lich_sqlite')
require File.join(lich_root, 'lib/common/class_exts/nilclass')
require File.join(lich_root, 'lib/common/settings')
require File.join(lich_root, 'lib/dragonrealms/drinfomon/drvariables')
require File.join(lich_root, 'lib/dragonrealms/drinfomon/drbanking')

Script = OpenStruct.new(current: OpenStruct.new(name: nil)) unless defined?(Script)
XMLData = OpenStruct.new(game: game, name: name, room_title: '')

banking = Lich::DragonRealms::DRBanking
$stdout.sync = true

while (line = $stdin.gets)
  command, rest = line.chomp.split(' ', 2)
  begin
    value = case command
            when 'all'       then banking.all_accounts
            when 'mine'      then banking.my_accounts
            when 'reload'    then banking.reload!
            when 'total_all' then banking.total_wealth_all
            when 'update'
              town, copper = rest.split(' ')
              banking.update_balance(town, copper.to_i)
              nil
            when 'parse'
              XMLData.room_title = '[[Provincial Bank, Teller]]'
              banking.parse(rest)
              nil
            when 'reset'     then banking.reset_character! && nil
            when 'reset_all' then banking.reset_all! && nil
            when 'messages'
              lines = Lich::Messaging.lines.dup
              Lich::Messaging.lines.clear
              lines
            else
              raise ArgumentError, "unknown command #{command.inspect}"
            end
    puts JSON.generate({ 'value' => value })
  rescue StandardError => e
    puts JSON.generate({ 'error' => "#{e.class}: #{e.message}" })
  end
end
