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
      # Creature name normalization patterns (creatures with variant descriptions)
      ALFAR_WARRIOR_PATTERN = /.*alfar warrior.*/.freeze
      SINEWY_LEOPARD_PATTERN = /.*sinewy leopard.*/.freeze
      LESSER_NAGA_PATTERN = /.*lesser naga.*/.freeze
    end

    # Converts an amount and denomination to copper.
    # @param amt [Integer, String] The amount to convert
    # @param denomination [String] The denomination (platinum, gold, silver, bronze, copper)
    # @return [Integer] The value in copper
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

    # Issues the 'exp mods' command and parses skill modifiers.
    # @return [Array<String>, nil] The captured output lines or nil on timeout
    def check_exp_mods
      Lich::Util.issue_command("exp mods", /The following skills are currently under the influence of a modifier/, /^<output class=""/, quiet: true, include_end: false, usexml: false)
    end

    # Converts copper to a readable currency string with denominations.
    # @param copper [Integer] Amount in copper
    # @return [String] Formatted string like "5 platinum, 3 gold, 2 silver"
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

    # Cleans room objects string and splits into array.
    # Removes "You also see" prefix and mount descriptions.
    # @param room_objs [String] Raw room objects string from game output
    # @return [Array<String>] Array of individual object strings
    def clean_and_split(room_objs)
      room_objs.sub(DRDefsPattern::YOU_ALSO_SEE, '')
               .sub(DRDefsPattern::MOUNT_DESCRIPTION, '')
               .strip
               .split(DRDefsPattern::COMMA_OR_AND)
    end

    # Normalizes "X and Y" to "X, Y" for consistent splitting.
    # Used to handle the lack of Oxford comma in game output.
    # @param text [String] Text that may end with "and X"
    # @return [String] Text with trailing "and X" replaced by ", X"
    def normalize_trailing_and(text)
      if (match = text.match(DRDefsPattern::TRAILING_AND))
        text.sub(DRDefsPattern::TRAILING_AND, ", #{match[:last]}")
      else
        text
      end
    end

    # Extract player names from room player string
    # @param room_players [String] The room players string from game output
    # @param filter_pattern [Regexp, nil] Optional pattern to filter players (e.g., LYING_DOWN, SITTING)
    # @param status_pattern [Regexp] Pattern to remove status text (defaults to PLAYER_STATUS)
    # @return [Array<String>] List of player names
    def extract_pcs(room_players, filter_pattern: nil, status_pattern: DRDefsPattern::PLAYER_STATUS)
      return [] if room_players.nil? || room_players.empty?

      players = normalize_trailing_and(room_players).split(', ')
      players = players.select { |obj| filter_pattern.match?(obj) } if filter_pattern

      players
        .map { |obj| obj.sub(status_pattern, '').sub(DRDefsPattern::PARENTHETICAL, '') }
        .map { |obj| obj.strip.scan(DRDefsPattern::PLAYER_NAME).first }
        .compact
    end

    # Finds all player names in the room.
    # @param room_players [String] The "Also here:" room players string
    # @return [Array<String>] List of player names
    def find_pcs(room_players)
      extract_pcs(room_players)
    end

    # Finds players who are lying down in the room.
    # @param room_players [String] The "Also here:" room players string
    # @return [Array<String>] List of prone player names
    def find_pcs_prone(room_players)
      extract_pcs(room_players, filter_pattern: DRDefsPattern::LYING_DOWN, status_pattern: DRDefsPattern::WHO_STATUS)
    end

    # Finds players who are sitting in the room.
    # @param room_players [String] The "Also here:" room players string
    # @return [Array<String>] List of sitting player names
    def find_pcs_sitting(room_players)
      extract_pcs(room_players, filter_pattern: DRDefsPattern::SITTING, status_pattern: DRDefsPattern::WHO_STATUS)
    end

    # Finds all NPC strings (both living and dead) in room objects.
    # @param room_objs [String] Raw room objects string from game output
    # @return [Array<String>] Array of raw NPC strings with XML tags
    def find_all_npcs(room_objs)
      room_objs.sub(DRDefsPattern::YOU_ALSO_SEE, '')
               .sub(DRDefsPattern::MOUNT_DESCRIPTION, '')
               .strip
               .scan(DRDefsPattern::NPC_SCAN)
    end

    # Cleans and normalizes NPC strings to creature names.
    # Handles XML tag removal, name normalization, and ordinal numbering.
    # @param npc_string [Array<String>] Array of raw NPC strings
    # @return [Array<String>] Array of cleaned creature names with ordinals
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

    # Normalizes creature names that have variant descriptions.
    # Maps "a sinewy leopard that..." to just "sinewy leopard".
    # @param text [String] Text containing creature description
    # @return [String] Text with normalized creature name
    def normalize_creature_names(text)
      text
        .sub(DRDefsPattern::ALFAR_WARRIOR_PATTERN, 'alfar warrior')
        .sub(DRDefsPattern::SINEWY_LEOPARD_PATTERN, 'sinewy leopard')
        .sub(DRDefsPattern::LESSER_NAGA_PATTERN, 'lesser naga')
    end

    # Removes pushBold/popBold XML tags from text.
    # @param text [String] Text with potential XML tags
    # @return [String] Text with tags removed
    def remove_html_tags(text)
      text
        .sub('<pushBold/>', '')
        .sub(%r{<popBold/>.*}, '')
    end

    # Extracts the last creature from an "X and Y" string.
    # Removes modifiers like "glowing with a holy aura".
    # @param text [String] Text potentially containing multiple creatures
    # @return [String] The last creature name portion
    def extract_last_creature(text)
      # Get the last creature name after "and", removing modifiers like "glowing with"
      text.split(/\sand\s/).last.sub(DRDefsPattern::GLOWING_WITH, '')
    end

    # Extracts just the creature name (letters, hyphens, apostrophes).
    # @param text [String] Text containing creature name
    # @return [String, nil] The final creature name or nil
    def extract_final_name(text)
      # Extract just the creature name (letters, hyphens, apostrophes)
      text.strip.scan(DRDefsPattern::CREATURE_NAME).first
    end

    # Adds ordinal prefixes to duplicate NPCs (e.g., "second goblin").
    # @param npc_list [Array<String>] Array of NPC names
    # @return [Array<String>] Array with ordinals added to duplicates
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

    # Extract NPCs from room objects
    # @param room_objs [String] The room objects string from game output
    # @param select_dead [Boolean] If true, select only dead NPCs; if false, reject dead NPCs
    # @return [Array<String>] List of NPC names
    def extract_npcs(room_objs, select_dead: false)
      all_npcs = find_all_npcs(room_objs)
      filtered = if select_dead
                   all_npcs.select { |obj| DRDefsPattern::DEAD_NPC.match?(obj) }
                 else
                   all_npcs.reject { |obj| DRDefsPattern::DEAD_NPC.match?(obj) }
                 end
      clean_npc_string(filtered)
    end

    # Finds living NPCs in the room.
    # @param room_objs [String] Raw room objects string from game output
    # @return [Array<String>] Array of living NPC names
    def find_npcs(room_objs)
      extract_npcs(room_objs, select_dead: false)
    end

    # Finds dead NPCs in the room.
    # @param room_objs [String] Raw room objects string from game output
    # @return [Array<String>] Array of dead NPC names
    def find_dead_npcs(room_objs)
      extract_npcs(room_objs, select_dead: true)
    end

    # Finds non-NPC objects in the room (items, furniture, etc.).
    # @param room_objs [String] Raw room objects string from game output
    # @return [Array<String>] Array of object names
    def find_objects(room_objs)
      # Use sub instead of sub! to avoid mutating frozen strings
      processed_objs = room_objs.sub(DRDefsPattern::GELAPOD, DRDefsPattern::GELAPOD_REPLACEMENT)
      clean_and_split(processed_objs)
        .reject { |obj| DRDefsPattern::PUSH_BOLD.match?(obj) }
        .map { |obj| obj.sub(DRDefsPattern::TRAILING_PERIOD, '').strip.sub(DRDefsPattern::LEADING_ARTICLE, '').strip }
    end
  end
end
