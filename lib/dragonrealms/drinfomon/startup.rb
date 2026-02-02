# frozen_string_literal: true

require_relative '../../common/watchable'

module Lich
  module DragonRealms
    module DRInfomon
      extend Lich::Common::Watchable
      # Populates initial game state after login by issuing
      # game commands whose output is parsed by DRParser.
      #
      # Uses ExecScript so that fput blocks until the game
      # responds, guaranteeing DRParser.parse has processed
      # every response line before the next command is sent.
      #
      # Called once from the game lifecycle hook in games.rb
      # after the character name is known and the session is ready.
      #
      # Detection from scripts:
      #   DRInfomon.startup_complete? - true after all startup commands have finished.
      #     Use this to avoid sending duplicate info/played/exp/ability commands.
      @@startup_complete = false

      def self.startup_complete?
        @@startup_complete
      end

      # Self-watching thread that triggers startup when ready
      # Follows the ActiveSpell.watch! pattern for lifecycle management
      def self.watch!
        @startup_thread ||= Thread.new do
          begin
            # Wait for character to be ready
            sleep 0.1 until GameBase::Game.autostarted? && XMLData.name && !XMLData.name.empty?

            # Run startup once
            startup
          rescue StandardError => e
            respond 'Error in DRInfomon startup thread'
            respond e.inspect
            respond e.backtrace.join("\n")
          end
        end
      end

      def self.startup
        ExecScript.start(startup_script, { quiet: true, name: "drinfomon_startup" })
      end

      def self.startup_script
        <<~SCRIPT
          # Populate stats, race, guild, circle, etc.
          Lich::Util.issue_command("info", /^Name/, /^<output class=""/, quiet: true, timeout: 1) unless dead?

          # Populate account name and subscription level
          Lich::Util.issue_command("played", /^Account Info for/, quiet: true, timeout: 1)

          # Populate all skill ranks and learning rates
          Lich::Util.issue_command("exp all 0", /^Circle: \\d+/, /^EXP HELP/, quiet: true, timeout: 1)

          # Populate known spells/abilities/khri
          # The `ability` command works for all guilds:
          #   - Magic guilds: proxies to `spells`, parsed by check_known_spells
          #   - Barbarians: parsed by check_known_barbarian_abilities
          #   - Thieves: parsed by check_known_thief_khri
          Lich::Util.issue_command("ability", /^You (?:know the Berserks|recall the spells you have learned from your training)|^From (?:your apprenticeship you remember practicing|the \\w+ tree)/, /^You (?:recall that you have \\d+ training sessions|can use SPELL STANCE \\[HELP\\]|have \\d+ available slot)/, quiet: true, timeout: 1)

          Lich::DragonRealms::DRInfomon.startup_completed!
        SCRIPT
      end

      def self.startup_completed!
        @@startup_complete = true
        PostLoad.game_loaded! if defined?(PostLoad)
      end
    end
  end
end
