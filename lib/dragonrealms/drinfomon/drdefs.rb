# frozen_string_literal: true

module Lich
  module DragonRealms
    # Pattern constants for room/NPC parsing
    module DRDefsPattern
      # Pattern to extract the final "and X" portion of room player lists
      TRAILING_AND = / and (?<last>.*)$/.freeze
      # Pattern to match player status descriptions
      PLAYER_STATUS = / (who|whose body)? ?(has|is|appears|glows) .+/.freeze
      # Pattern to match parenthetical info after player names
      PARENTHETICAL = / \(.+\)/.freeze
      # Pattern to extract player name (word characters at end)
      PLAYER_NAME = /\w+$/.freeze
      # Pattern for lying down players
      LYING_DOWN = /who is lying down/i.freeze
      # Pattern for sitting players
      SITTING = /who is sitting/i.freeze
      # Pattern for "You also see" prefix
      YOU_ALSO_SEE = /You also see/.freeze
      # Pattern for mount descriptions
      MOUNT_DESCRIPTION = / with a [\w\s]+ sitting astride its back/.freeze
      # Pattern to find NPCs in room objects (bold tags indicate creatures)
      NPC_SCAN = %r{<pushBold/>[^<>]*<popBold/> which appears dead|<pushBold/>[^<>]*<popBold/> \(dead\)|<pushBold/>[^<>]*<popBold/>}.freeze
      # Pattern for dead NPCs
      DEAD_NPC = /which appears dead|\(dead\)/.freeze
      # Pattern for pushBold tags (indicates creature, not object)
      PUSH_BOLD = /pushBold/.freeze
      # Pattern for leading articles
      LEADING_ARTICLE = /^(a|some) /.freeze
      # Pattern for trailing period
      TRAILING_PERIOD = /\.$/.freeze
      # Pattern for splitting on comma or "and"
      COMMA_OR_AND = /,|\sand\s/.freeze
      # Pattern for extracting creature name (letters, hyphens, apostrophes only)
      # Note: Using [A-Za-z] instead of [A-z] to avoid matching [\]^_` characters
      CREATURE_NAME = /[A-Za-z'-]+$/.freeze
      # Pattern for "who has/is" descriptions
      WHO_STATUS = / who (has|is) .+/.freeze
      # Pattern for "glowing with" modifiers
      GLOWING_WITH = /(?:\sglowing)?\swith\s.*/.freeze
      # Gelapod replacement pattern
      GELAPOD = "<pushBold/>a domesticated gelapod<popBold/>".freeze
      GELAPOD_REPLACEMENT = 'domesticated gelapod'.freeze
    end

    def convert2copper(amt, denomination)
      if denomination =~ /platinum/
        (amt.to_i * 10_000)
      elsif denomination =~ /gold/
        (amt.to_i * 1000)
      elsif denomination =~ /silver/
        (amt.to_i * 100)
      elsif denomination =~ /bronze/
        (amt.to_i * 10)
      else
        amt
      end
    end

    def check_exp_mods
      Lich::Util.issue_command("exp mods", /The following skills are currently under the influence of a modifier/, /^<output class=""/, quiet: true, include_end: false, usexml: false)
    end

    def convert2plats(copper)
      denominations = [[10_000, 'platinum'], [1000, 'gold'], [100, 'silver'], [10, 'bronze'], [1, 'copper']]
      denominations.inject([copper, []]) do |result, denomination|
        remaining = result.first
        display = result.last
        if remaining / denomination.first > 0
          display << "#{remaining / denomination.first} #{denomination.last}"
        end
        [remaining % denomination.first, display]
      end.last.join(', ')
    end

    def clean_and_split(room_objs)
      room_objs.sub(DRDefsPattern::YOU_ALSO_SEE, '')
               .sub(DRDefsPattern::MOUNT_DESCRIPTION, '')
               .strip
               .split(DRDefsPattern::COMMA_OR_AND)
    end

    # Helper to normalize "X and Y" to "X, Y" for consistent splitting
    def normalize_trailing_and(text)
      if (match = text.match(DRDefsPattern::TRAILING_AND))
        text.sub(DRDefsPattern::TRAILING_AND, ", #{match[:last]}")
      else
        text
      end
    end

    def find_pcs(room_players)
      return [] if room_players.nil? || room_players.empty?

      normalize_trailing_and(room_players)
        .split(', ')
        .map { |obj| obj.sub(DRDefsPattern::PLAYER_STATUS, '').sub(DRDefsPattern::PARENTHETICAL, '') }
        .map { |obj| obj.strip.scan(DRDefsPattern::PLAYER_NAME).first }
        .compact
    end

    def find_pcs_prone(room_players)
      return [] if room_players.nil? || room_players.empty?

      normalize_trailing_and(room_players)
        .split(', ')
        .select { |obj| DRDefsPattern::LYING_DOWN.match?(obj) }
        .map { |obj| obj.sub(DRDefsPattern::WHO_STATUS, '').sub(DRDefsPattern::PARENTHETICAL, '') }
        .map { |obj| obj.strip.scan(DRDefsPattern::PLAYER_NAME).first }
        .compact
    end

    def find_pcs_sitting(room_players)
      return [] if room_players.nil? || room_players.empty?

      normalize_trailing_and(room_players)
        .split(', ')
        .select { |obj| DRDefsPattern::SITTING.match?(obj) }
        .map { |obj| obj.sub(DRDefsPattern::WHO_STATUS, '').sub(DRDefsPattern::PARENTHETICAL, '') }
        .map { |obj| obj.strip.scan(DRDefsPattern::PLAYER_NAME).first }
        .compact
    end

    def find_all_npcs(room_objs)
      room_objs.sub(DRDefsPattern::YOU_ALSO_SEE, '')
               .sub(DRDefsPattern::MOUNT_DESCRIPTION, '')
               .strip
               .scan(DRDefsPattern::NPC_SCAN)
    end

    def clean_npc_string(npc_string)
      # Normalize NPC names
      normalized_npcs = npc_string
                        .map { |obj| normalize_creature_names(obj) }
                        .map { |obj| remove_html_tags(obj) }
                        .map { |obj| extract_last_creature(obj) }
                        .map { |obj| extract_final_name(obj) }
                        .compact
                        .sort

      # Count occurrences and add ordinals
      add_ordinals_to_duplicates(normalized_npcs)
    end

    def normalize_creature_names(text)
      text
        .sub(/.*alfar warrior.*/, 'alfar warrior')
        .sub(/.*sinewy leopard.*/, 'sinewy leopard')
        .sub(/.*lesser naga.*/, 'lesser naga')
    end

    def remove_html_tags(text)
      text
        .sub('<pushBold/>', '')
        .sub(%r{<popBold/>.*}, '')
    end

    def extract_last_creature(text)
      # Get the last creature name after "and", removing modifiers like "glowing with"
      text.split(/\sand\s/).last.sub(DRDefsPattern::GLOWING_WITH, '')
    end

    def extract_final_name(text)
      # Extract just the creature name (letters, hyphens, apostrophes)
      text.strip.scan(DRDefsPattern::CREATURE_NAME).first
    end

    def add_ordinals_to_duplicates(npc_list)
      flat_npcs = []

      npc_list.uniq.each do |npc|
        # Count how many times this NPC appears
        count = npc_list.count(npc)

        # Create entries with ordinals for duplicates
        count.times do |index|
          if index.zero?
            flat_npcs << npc
          else
            # Use ordinal from $ORDINALS if available, otherwise generate one
            ordinal = $ORDINALS[index] || "#{index + 1}th"
            flat_npcs << "#{ordinal} #{npc}"
          end
        end
      end

      flat_npcs
    end

    def find_npcs(room_objs)
      npcs = find_all_npcs(room_objs).reject { |obj| DRDefsPattern::DEAD_NPC.match?(obj) }
      clean_npc_string(npcs)
    end

    def find_dead_npcs(room_objs)
      dead_npcs = find_all_npcs(room_objs).select { |obj| DRDefsPattern::DEAD_NPC.match?(obj) }
      clean_npc_string(dead_npcs)
    end

    def find_objects(room_objs)
      # Use sub instead of sub! to avoid mutating frozen strings
      processed_objs = room_objs.sub(DRDefsPattern::GELAPOD, DRDefsPattern::GELAPOD_REPLACEMENT)
      clean_and_split(processed_objs)
        .reject { |obj| DRDefsPattern::PUSH_BOLD.match?(obj) }
        .map { |obj| obj.sub(DRDefsPattern::TRAILING_PERIOD, '').strip.sub(DRDefsPattern::LEADING_ARTICLE, '').strip }
    end
  end
end
