# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRInfomon
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

      def self.startup
        ExecScript.start(startup_script, { quiet: false, name: "drinfomon_startup" })
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
      end
    end
  end
end
