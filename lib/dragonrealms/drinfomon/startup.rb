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
            Lich::Messaging.msg('error', 'DRInfomon: Error in startup thread')
            Lich::Messaging.msg('error', "DRInfomon: #{e.inspect}")
            Lich::Messaging.msg('error', "DRInfomon: #{e.backtrace.join("\n")}")
          end
        end
      end

      def self.startup
        ExecScript.start(startup_script, { quiet: true, name: 'drinfomon_startup' })
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

          # Ensure ShowRoomID and MonsterBold flags are enabled (one-time per character)
          unless UserVars.dependency_setflags
            flags = Array(Lich::Util.issue_command("flag", /^Usage/, /^For other setting options, see AVOID, SET, and TOGGLE/, quiet: true, timeout: 1, usexml: false))
            required = ["ShowRoomID", "MonsterBold"]
            required.each do |flag|
              fput("flag \#{flag} on") unless flags.any? { |f| f.match?(/\#{Regexp.escape(flag)}\\s+ON/) }
            end
            # Re-query to verify flags applied; only mark sentinel if all confirmed
            flags = Array(Lich::Util.issue_command("flag", /^Usage/, /^For other setting options, see AVOID, SET, and TOGGLE/, quiet: true, timeout: 1, usexml: false))
            UserVars.dependency_setflags = Time.now if required.all? { |flag| flags.any? { |f| f.match?(/\#{Regexp.escape(flag)}\\s+ON/) } }
          end

          Lich::DragonRealms::DRInfomon.startup_completed!
        SCRIPT
      end

      def self.startup_completed!
        @@startup_complete = true
        PostLoad.game_loaded! if defined?(PostLoad)
        post_startup_checks
      end

      # Best-effort filesystem checks that run once after startup completes.
      # These don't need game commands, just file existence checks and warnings.
      # Failures are logged but do not block the PostLoad lifecycle.
      #
      # @return [void]
      def self.post_startup_checks
        warn_obsolete_scripts
        warn_obsolete_data_files
        warn_custom_scripts
        $setupfiles.reload if defined?($setupfiles) && $setupfiles
      rescue StandardError => e
        safe_message('error', "DRInfomon: post_startup_checks failed: #{e.message}")
        safe_log("DRInfomon: post_startup_checks error: #{e.inspect}\n\t#{e.backtrace&.first(5)&.join("\n\t")}")
      end

      # Guarded messaging -- safe to call if Lich::Messaging is unavailable.
      #
      # @param type [String] message type (e.g. 'error', 'info')
      # @param text [String] message text
      # @return [void]
      def self.safe_message(type, text)
        if defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:msg)
          Lich::Messaging.msg(type, text)
        else
          safe_log(text)
        end
      end

      # Guarded logging -- safe to call if Lich.log is unavailable.
      #
      # @param text [String] log message
      # @return [void]
      def self.safe_log(text)
        if defined?(Lich) && Lich.respond_to?(:log)
          Lich.log(text)
        else
          $stderr.puts(text)
        end
      end

      # Script names that are obsolete and should be deleted.
      # Checked on login to warn users about stale files.
      DR_OBSOLETE_SCRIPTS = %w[
        events slackbot spellmonitor exp-monitor
        common-travel common-validation common drinfomon equipmanager
        common-money common-moonmage common-summoning common-theurgy common-arcana
        bootstrap common-crafting common-healing-data common-healing common-items
        update-shops
      ].freeze

      # Data filenames that are obsolete and should be deleted.
      DR_OBSOLETE_DATA_FILES = %w[].freeze

      # Warns about obsolete .lic files still present in SCRIPT_DIR.
      #
      # @return [void]
      def self.warn_obsolete_scripts
        DR_OBSOLETE_SCRIPTS.each do |script_name|
          path = File.join(SCRIPT_DIR, "#{script_name}.lic")
          next unless File.exist?(path)

          _respond Lich::Messaging.monsterbold("--- Lich: '#{script_name}.lic' is obsolete and should be deleted from #{SCRIPT_DIR}. It is no longer needed and may cause problems.")
        end
      end

      # Warns about obsolete data files still present in SCRIPT_DIR/data.
      #
      # @return [void]
      def self.warn_obsolete_data_files
        data_dir = File.join(SCRIPT_DIR, 'data')
        DR_OBSOLETE_DATA_FILES.each do |filename|
          path = File.join(data_dir, filename)
          next unless File.exist?(path)

          _respond Lich::Messaging.monsterbold("--- Lich: '#{filename}' is obsolete and can be safely deleted from #{data_dir}.")
        end
      end

      # Warns when scripts/custom/ contains files that shadow curated scripts,
      # preventing the curated versions from receiving updates.
      #
      # @return [void]
      def self.warn_custom_scripts
        custom_dir = File.join(SCRIPT_DIR, 'custom')
        return unless File.directory?(custom_dir)

        custom_scripts = Dir.entries(custom_dir).select { |f| f.end_with?('.lic') }
        curated_scripts = Dir.entries(SCRIPT_DIR).select { |f| f.end_with?('.lic') }
        shadowed = custom_scripts.select { |script| curated_scripts.include?(script) }

        unless shadowed.empty?
          Lich::Messaging.msg("info", "NOTE: The following curated scripts are in your custom folder and will not receive updates")
          Lich::Messaging.msg("info", shadowed.join(', '))
        end
      end
    end
  end

  module Common
    CORE_DR_STARTUP = true
  end
end
