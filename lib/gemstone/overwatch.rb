# frozen_string_literal: true

module Lich
  module Gemstone
    # Manages hidden creature detection and tracking in Gemstone IV.
    # Automatically tracks when creatures hide and reveals them when they emerge.
    # Integrates with GameObj and XMLData to maintain accurate target lists.
    #
    # @example Check if current room has hidden creatures
    #   Overwatch.hiders? #=> true or false
    #
    # @example Get room ID where hiders were detected
    #   room_id = Overwatch.room_with_hiders #=> 12345 or nil
    #
    # @example Enable debug output
    #   Overwatch.debug = true
    #
    class Overwatch
      @@hidden_targets ||= nil
      @@debug          ||= false

      # Clears the hidden targets tracking.
      #
      # @return [nil]
      def self.clear
        @@hidden_targets = nil
      end

      # Gets the room ID where hidden targets were last detected.
      #
      # @return [Integer, nil] room ID or nil if no hidden targets tracked
      def self.room_with_hiders
        @@hidden_targets
      end

      # Checks if the current room has hidden targets.
      #
      # @return [Boolean] true if current room matches tracked hider room
      def self.hiders?
        return false if @@hidden_targets.nil?
        @@hidden_targets.eql?(XMLData.room_id)
      end

      # Sets the room where hidden targets were detected.
      #
      # @param room_id [Integer] the room ID to track
      # @return [Integer] the room_id
      def self.track_hidden_targets(room_id)
        @@hidden_targets = room_id
      end

      # Clears hidden targets tracking.
      # Alias for clear method.
      #
      # @return [nil]
      def self.room_with_hiders_reset
        clear
      end

      # Enables or disables debug output.
      #
      # @param value [Boolean] true to enable debug output
      # @return [Boolean] the debug value
      def self.debug=(value)
        @@debug = value
      end

      # Checks if debug mode is enabled.
      #
      # @return [Boolean] true if debug is enabled
      def self.debug?
        @@debug
      end

      # Adds a revealed target to GameObj and XMLData if not already present.
      # Handles silent strike detection by checking recent game output.
      #
      # @param target_id [String] the target's game object ID
      # @param target_noun [String] the target's noun
      # @param target_name [String] the target's full name
      # @param silent_strike [Boolean] whether to check for silent strike rehide
      # @return [void]
      def self.push_revealed_targets(target_id, target_noun, target_name, silent_strike: false)
        @@hidden_targets = nil

        if silent_strike
          respond "Checking for silent strike against #{target_id} #{target_name}." if @@debug
          result = reget(10, /fades into the surroundings\./, /slips into the shadows\./, /botch an attempt at concealing\./, /The figure quickly disappears from view\./, core: true)
          respond result if @@debug

          unless result.empty?
            case result[0]
            when /With a (?:barely audible hiss|sibilant exhalation), <pushBold\/>\w+ <a exist="(\d+)" noun=" ?\w+">[^<]+<\/a><popBold\/> (?:fades into the surroundings|slips into the shadows)\./
              if target_id == Regexp.last_match[1]
                respond "Silent Strike Detected. Target #{target_id} #{target_name} is hidden." if @@debug
                return
              end
            when /The figure quickly disappears from view\./
              respond "Silent Strike Detected. Target is hidden." if @@debug
              return
            when /You notice <pushBold\/>\w+ <a exist="(\d+)" noun=" ?\w+">[^<]+<\/a><popBold\/> botch an attempt at concealing <pushBold\/><a exist="\d+" noun=" ?\w+">\w+<\/a><popBold\/>\./
              if target_id == Regexp.last_match[1]
                respond "Silent Strike Botched. Target #{target_id} #{target_name}." if @@debug
              end
            end
          end
        end

        respond "push_revealed_targets(#{target_id}, #{target_noun}, #{target_name}, silent_strike: #{silent_strike})" if @@debug

        # Add to GameObj.npcs if not already present
        unless GameObj.npcs.any? { |npc| npc.id == target_id }
          GameObj.new_npc(target_id, target_noun, target_name.gsub(/  /, " "))
          respond "#{target_id} added to GameObj.npcs." if @@debug
        end

        # Add to XMLData.current_target_ids if not already present
        unless XMLData.current_target_ids.include?(target_id)
          XMLData.current_target_ids.unshift(target_id)
          respond "#{target_id} added to XMLData.current_target_ids." if @@debug
        end
      end

      # Observer module handles parsing of game output for Overwatch.
      # Integrates with Infomon::XMLParser for pattern matching.
      #
      # @api private
      module Observer
        # Term module contains all regex patterns for detecting hiding and revealing.
        module Term
          # Patterns for creatures entering hiding
          HIDING = Regexp.union(
            /<pushBold\/>\w+ <a exist="\d+" noun="\w+">[^<]+<\/a><popBold\/> slips into hiding\./,
            /flies out of the shadows toward you\!/,
            /A faint silvery light flickers from the shadows\./,
            /Suddenly, a tiny shard of jet black crystal flies from the shadows toward you!/,
            /With a barely audible hiss, <pushBold\/>\w+ <a exist="\d+" noun=" ?\w+">[^<]+<\/a><popBold\/> fades into the surroundings\./,
            /With a sibilant exhalation, <pushBold\/>\w+ <a exist="\d+" noun=" ?\w+">[^<]+<\/a><popBold\/> slips into the shadows\./,
            /flies out of the shadows toward <a exist="\-\d+" noun="\w+">[^<]+<\/a>\!/,
            /flies out of the shadows toward <pushBold\/>\w+ <a exist="\d+" noun="\w+">[^<]+<\/a><popBold\/>\!/,
            /<pushBold\/>\w+ <a exist="\d+" noun=" ?\w+">[^<]+<\/a><popBold\/> darts into the shadows\./,
            /As you move to attack <pushBold\/>\w+ <a exist="\d+" noun=" ?\w+">[^<]+<\/a><popBold\/>, <pushBold\/>\w+ <a exist="\d+" noun=" ?\w+">[^<]+<\/a><popBold\/> shrinks away from you, baring sharpened teeth as <pushBold\/><a exist="\d+" noun=" ?\w+">\w+<\/a><popBold\/> darts into the shadows!/,
            /As you move to attack <pushBold\/>\w+ <a exist="\d+" noun=" ?\w+">[^<]+<\/a><popBold\/>, <pushBold\/><a exist="\d+" noun=" ?\w+">\w+<\/a><popBold\/> disperses into roiling shadows!/,
            /Something stirs in the shadows\./,
            /The figure quickly disappears from view\./,
            /<pushBold\/>\w+ <a exist="\d+" noun=" ?\w+">[^<]+<\/a><popBold\/> blends with the shadows, moving too swiftly for the eye to follow\./,
            /You notice the hiding place of <pushBold\/>\w+ <a exist="\d+" noun=" ?\w+">[^<]+<\/a><popBold\/>, but do not reveal your hidden position./
          )

          # Patterns for creatures being revealed from hiding
          REVEALED_DISCOVERY = /<pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> is revealed from hiding\./
          REVEALED_FORCED = /<pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> is forced from hiding\!/
          REVEALED_COMES_OUT = /<pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> comes out of hiding\./
          REVEALED_LEAPS_OUT = /<pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> leaps out of <pushBold\/><a exist="\d+" noun="\w+">\w+<\/a><popBold\/> hiding place\!/
          REVEALED_SUDDENLY_LEAPS = /<pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> suddenly leaps from <pushBold\/><a exist="\d+" noun=" ?\w+">\w+<\/a><popBold\/> hiding place\!/
          REVEALED_SHADOWS_MELT = /The shadows melt away to reveal <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/>!/
          REVEALED_YOU_DISCOVER = /You discover the hiding place of <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/>\!/
          REVEALED_YOU_REVEAL = /You reveal <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> from hiding\!/
          REVEALED_WALL_THORNS = /The thorny barrier surrounding you blocks the attack from the <pushBold\/><a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/>\!/
          REVEALED_FLAMING_AURA = /The flaming aura surrounding you lashes out at <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/>, who is forced into view!/

          # Animal companion reveals
          REVEALED_AC_CAT = /<pushBold\/>\w+ <a exist="\d+" noun="\w+">[^<]+<\/a><popBold\/> leaps suddenly forward, uncovering <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/>, who was hidden\!/
          REVEALED_AC_CANINE = /<pushBold\/>\w+ <a exist="\d+" noun="\w+">[^<]+<\/a><popBold\/> takes a pointed step forward, revealing <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/>, who was hidden\!/
          REVEALED_AC_AVIAN = /<pushBold\/>\w+ <a exist="\d+" noun=" ?\w+">[^<]+<\/a><popBold\/> dives ahead while flapping <pushBold\/><a exist="\d+" noun="\w+">\w+<\/a><popBold\/> wings, exposing <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/>, who was hidden\!/

          # Kiramon stalker specific reveals
          REVEALED_STALKER_BITE = /Without warning, <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> glides from the shadows and aims a preternaturally swift bite at you\!/
          REVEALED_STALKER_STINGER = /<pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> twists fluidly to spear you with <pushBold\/><a exist="\d+" noun=" ?\w+">\w+<\/a><popBold\/> barbed stinger\!/
          REVEALED_STALKER_SLASH = /Without warning, <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> glides from the shadows and skitters mercilessly forward to slash at you with a razor-sharp foreleg\!/
          REVEALED_STALKER_INTERPOSE = /As you attempt to hide, <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> glides past you in a single fluid motion, interposing between you and the safety of the shadows\./
          REVEALED_STALKER_MISS = /Caught unaware, you can only stare in fascination as <pushBold\/><a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">\w+<\/a><popBold\/> manages to completely miss you while nearly dropping <pushBold\/><a exist="\d+" noun=" ?\w+">\w+<\/a><popBold\/>  in the process\./

          # Silent strike patterns - attacks that may result in immediate rehiding
          SILENT_CUTTHROAT = /<pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> springs upon you from behind and attempts to grasp you by the chin while bringing <pushBold\/><a exist="\d+" noun=" ?\w+">\w+<\/a><popBold\/> <a exist="\d+" noun="[^"]+">[^<]+<\/a> up to slit your throat\!/
          SILENT_CANNIBAL_SWING = /With an ululating shriek, <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> leaps from the shadows and hurtles at you, swinging wildly with a <a exist="\d+" noun="[^"]+">[^<]+<\/a>!/
          SILENT_CANNIBAL_GRAPPLE = /With an ululating shriek, <pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> leaps from the shadows and throws <pushBold\/><a exist="\d+" noun="[^"]+">(?:his|her)<\/a><popBold\/> wiry arms around you, fueled by panicked hunger!/
          SILENT_LEAP_ATTACK = /<pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> leaps from hiding to attack\!/
          SILENT_SUBDUE = /<pushBold\/>\w+ <a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">(?<name>[^<]+)<\/a><popBold\/> springs upon you from behind and aims a blow to your head\!/
          SILENT_STALKER_SAVAGE = /Catching you unaware, <pushBold\/><a exist="(?<id>\d+)" noun=" ?(?<noun>\w+)">\w+<\/a><popBold\/> carves into you with cruel and ruthless savagery\!/

          # Combined patterns for efficient matching
          ANY_REVEALED = Regexp.union(
            REVEALED_DISCOVERY,
            REVEALED_FORCED,
            REVEALED_COMES_OUT,
            REVEALED_LEAPS_OUT,
            REVEALED_SUDDENLY_LEAPS,
            REVEALED_SHADOWS_MELT,
            REVEALED_YOU_DISCOVER,
            REVEALED_YOU_REVEAL,
            REVEALED_WALL_THORNS,
            REVEALED_FLAMING_AURA,
            REVEALED_AC_CAT,
            REVEALED_AC_CANINE,
            REVEALED_AC_AVIAN,
            REVEALED_STALKER_BITE,
            REVEALED_STALKER_STINGER,
            REVEALED_STALKER_SLASH,
            REVEALED_STALKER_INTERPOSE,
            REVEALED_STALKER_MISS
          )

          ANY_SILENT_STRIKE = Regexp.union(
            SILENT_CUTTHROAT,
            SILENT_CANNIBAL_SWING,
            SILENT_CANNIBAL_GRAPPLE,
            SILENT_LEAP_ATTACK,
            SILENT_SUBDUE,
            SILENT_STALKER_SAVAGE
          )

          ANY = Regexp.union(HIDING, ANY_REVEALED, ANY_SILENT_STRIKE)
        end

        # Checks if a line contains Overwatch-related information.
        #
        # @param line [String] line of game output
        # @return [Boolean, MatchData] match data if line matches, false otherwise
        def self.wants?(line)
          line.match(Term::ANY)
        end

        # Processes a line of Overwatch-related game output.
        # Updates hidden target tracking and reveals creatures as appropriate.
        #
        # @param line [String] line of game output
        # @param match_data [MatchData] regex match data from the line
        # @return [void]
        def self.consume(line, match_data)
          case line
          when Term::HIDING
            Overwatch.track_hidden_targets(XMLData.room_id)
          when Term::ANY_REVEALED
            Overwatch.push_revealed_targets(
              match_data[:id],
              match_data[:noun],
              match_data[:name]
            )
          when Term::ANY_SILENT_STRIKE
            # Handle special case for unknown assailant
            name = match_data[:name] || "unknown assailant"
            Overwatch.push_revealed_targets(
              match_data[:id],
              match_data[:noun],
              name,
              silent_strike: true
            )
          end
        end
      end
    end
  end
end
