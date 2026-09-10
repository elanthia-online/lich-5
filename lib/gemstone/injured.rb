# frozen_string_literal: true

module Lich
  module Gemstone
    # Injured class for checking ability to perform actions based on wounds and scars
    class Injured < Gemstone::CharacterStatus
      BODY_PART_GROUPS = {
        eyes: %i[leftEye rightEye],
        arms: %i[leftArm rightArm],
        hands: %i[leftHand rightHand],
        legs: %i[leftLeg rightLeg],
        feet: %i[leftFoot rightFoot],
        head_and_nerves: %i[head nsys]
      }.freeze

      # Cache variables. These must live on Injured itself (the class body),
      # not inside `class << self`, where they would land on the singleton
      # class and the methods below would read nil.
      @injury_cache_key = nil
      @wounds_cache = nil
      @scars_cache = nil
      @cache_mutex = Mutex.new

      class << self
        # Build an immutable fingerprint of the current injury state.
        # XMLData.injuries is mutated in place by the parser, so the hash itself
        # cannot serve as a cache key: it would always compare equal to itself.
        # Note: this runs in injury mode 2 ('both'), where a scar underneath an
        # active wound is not visible, so such a scar changing will not invalidate
        # the cache. That is a narrow case and acceptable given each cache miss
        # costs two _injury round trips in Scars.all_scars.
        def injury_fingerprint
          XMLData.injuries.map { |part, v| [part, v['wound'], v['scar']] }.freeze
        end

        # Get cached or fresh injury data
        def get_injury_data
          current_key = injury_fingerprint

          # Fast path: return cached data if key hasn't changed
          if @injury_cache_key == current_key && @wounds_cache && @scars_cache
            return [@wounds_cache, @scars_cache]
          end

          # Slow path: fetch new data with mutex protection
          @cache_mutex.synchronize do
            # Double-check after acquiring lock (another thread may have updated)
            if @injury_cache_key == current_key && @wounds_cache && @scars_cache
              return [@wounds_cache, @scars_cache]
            end

            # Fetch fresh data
            wounds = Wounds.all_wounds
            scars = Scars.all_scars

            # Update cache
            @wounds_cache = wounds
            @scars_cache = scars
            @injury_cache_key = current_key

            [wounds, scars]
          end
        end

        # Helper method to calculate effective injury level from hash data
        # Rank 1 scars are ignored, and wounds take precedence over scars
        def effective_injury_from_hashes(body_part, wounds_hash, scars_hash)
          scar = scars_hash[body_part.to_s] || 0
          wound = wounds_hash[body_part.to_s] || 0
          effective_scar = (scar == 1) ? 0 : scar

          [wound, effective_scar].max
        end

        # Check if any of the given body parts have an injury at exactly a specific rank
        def injuries_at_rank?(rank, wounds_hash, scars_hash, *parts)
          parts.flatten.any? do |part|
            effective_injury_from_hashes(part, wounds_hash, scars_hash) == rank
          end
        end

        # Check if any of the given body parts have an injury of a specific rank or higher
        def injuries_at_or_above_rank?(rank, wounds_hash, scars_hash, *parts)
          parts.flatten.any? do |part|
            effective_injury_from_hashes(part, wounds_hash, scars_hash) >= rank
          end
        end

        # Check for the presence of a buff that bypasses rank 2 or lower injuries
        def bypasses_injuries?
          Effects::Buffs.active?("Sigil of Determination")
        end

        # NOTE: every able_to_*? predicate calls fix_injury_mode('both') and, on a
        # cache miss, Scars.all_scars toggles the injury mode. Each of those can
        # send an _injury command and block for up to 7.5 seconds waiting on the
        # game. These are not instantaneous checks; avoid calling them in tight loops.

        # Check if character is able to cast spells
        def able_to_cast?
          fix_injury_mode("both")

          # Fetch cached or fresh injury data
          wounds, scars = get_injury_data

          # Rank 3 critical injuries prevent casting (Sigil cannot bypass)
          return false if injuries_at_rank?(3, wounds, scars, :head, :nsys, *BODY_PART_GROUPS[:eyes])

          # Check for rank 3 in arms/hands (worst of arm vs hand per side)
          left_arm = effective_injury_from_hashes(:leftArm, wounds, scars)
          left_hand = effective_injury_from_hashes(:leftHand, wounds, scars)
          right_arm = effective_injury_from_hashes(:rightArm, wounds, scars)
          right_hand = effective_injury_from_hashes(:rightHand, wounds, scars)

          left_side = [left_arm, left_hand].max
          right_side = [right_arm, right_hand].max

          return false if left_side == 3 || right_side == 3

          # Sigil of Determination bypasses rank 2 or lower injuries
          return true if bypasses_injuries?

          # Head or nerve injuries > rank 1 prevent casting
          return false if injuries_at_or_above_rank?(2, wounds, scars, *BODY_PART_GROUPS[:head_and_nerves])

          # Cumulative injuries >= 3 prevent casting
          eyes_total = BODY_PART_GROUPS[:eyes].sum { |part| effective_injury_from_hashes(part, wounds, scars) }
          return false if eyes_total >= 3

          arms_total = left_side + right_side
          return false if arms_total >= 3

          true
        end

        # Check if character is able to sneak
        def able_to_sneak?
          fix_injury_mode("both")

          wounds, scars = get_injury_data

          # Rank 3 leg/foot injuries always prevent sneaking, but these are NOT critical
          # (Sigil cannot bypass, but they're not in the critical list for other actions)
          return false if injuries_at_rank?(3, wounds, scars, *BODY_PART_GROUPS[:legs], *BODY_PART_GROUPS[:feet])

          # Sigil of Determination bypasses rank 2 or lower injuries
          return true if bypasses_injuries?

          # Any leg or foot injury > rank 1 prevents sneaking
          return false if injuries_at_or_above_rank?(2, wounds, scars, *BODY_PART_GROUPS[:legs], *BODY_PART_GROUPS[:feet])

          true
        end

        # Check if character is able to search
        def able_to_search?
          fix_injury_mode("both")

          wounds, scars = get_injury_data

          # Rank 3 critical injuries prevent searching (Sigil cannot bypass)
          return false if injuries_at_rank?(3, wounds, scars, :head, :nsys, *BODY_PART_GROUPS[:eyes])

          # Sigil of Determination bypasses rank 2 or lower injuries
          return true if bypasses_injuries?

          # Rank 2+ head or nerve injury prevents searching
          return false if injuries_at_or_above_rank?(2, wounds, scars, *BODY_PART_GROUPS[:head_and_nerves])

          true
        end

        # Check if character is able to use ranged weapons
        def able_to_use_ranged?
          fix_injury_mode("both")

          wounds, scars = get_injury_data

          # Rank 3 critical injuries prevent ranged weapon use (Sigil cannot bypass)
          return false if injuries_at_rank?(3, wounds, scars, :head, :nsys, *BODY_PART_GROUPS[:eyes], *BODY_PART_GROUPS[:arms], *BODY_PART_GROUPS[:hands])

          # Sigil of Determination bypasses rank 2 or lower injuries
          return true if bypasses_injuries?

          # Any single arm or hand injury >= rank 2 prevents ranged weapon use
          return false if injuries_at_or_above_rank?(2, wounds, scars, *BODY_PART_GROUPS[:arms], *BODY_PART_GROUPS[:hands], :nsys)

          true
        end
      end
    end
  end
end
