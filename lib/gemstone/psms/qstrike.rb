# frozen_string_literal: true

module Lich
  module Gemstone
    # QStrike module calculates optimal QSTRIKE roundtime reduction
    # while avoiding negative stamina. Accounts for weapon speeds,
    # attack costs, and Striking Asp stance discounts.
    #
    # @example Basic calculation
    #   QStrike.calculate(reserve: 1, attack_name: :cripple)
    #   # => { seconds: 2, stamina_cost: 30, qstrike_cmd: "qstrike -2", ... }
    #
    # @example Get just the command string
    #   QStrike.command(attack_name: :tackle, reserve: 5)
    #   # => "qstrike -3"
    #
    # @example Execute qstrike + attack
    #   QStrike.use(reduction: -3, attack: "cripple", target: "kobold")
    #   # Executes: put "qstrike -3" then CMan.use("cripple", "kobold")
    #
    # @example Absolute RT mode (reduce to 2 second RT)
    #   QStrike.use(reduction: 2, attack: "attack", target: "troll")
    #
    # @example Set defaults
    #   QStrike.set_default(:reserve, 5)
    #   QStrike.set_default(:adaptive, true)
    #
    module QStrike
      # Speed multipliers by weapon category
      # Applied per-weapon to calculate Equipment Speed
      SPEED_MULTIPLIERS = {
        two_handed: 1.5,
        polearm: 1.5,
        ranged: 2.5,
        # All others default to 1.0
      }.freeze
      DEFAULT_MULTIPLIER = 1.0

      # Striking Asp stance cost multipliers by rank
      # Rank 1 = 2/3 cost, Rank 2 = 1/2 cost, Rank 3 = 1/3 cost
      STRIKING_ASP_MULTIPLIERS = {
        1 => 2.0 / 3.0,  # 0.667
        2 => 1.0 / 2.0,  # 0.500
        3 => 1.0 / 3.0,  # 0.333
      }.freeze

      # Base cost constant from formula
      BASE_COST = 10

      # Maximum seconds of RT reduction (reasonable upper bound)
      MAX_REDUCTION = 8

      # Valid combat actions that can use QSTRIKE
      VALID_ACTIONS = %w[
        ascension ambush attack cheapshot cman cock disarm feat fire
        grapple hurl jab kill kick mstrike punch shield smite
        stunman subdue sweep tackle trip weapon wtricks
      ].freeze

      # Default settings
      DEFAULT_SETTINGS = {
        reserve: 1,
        adaptive: false
      }.freeze

      # === DEFAULTS MANAGEMENT (Persisted via DB_Store) ===

      # Get current defaults
      # @return [Hash] Current default settings
      def self.defaults
        load_settings
        {
          reserve: @settings[:reserve],
          adaptive: @settings[:adaptive]
        }
      end

      # Set all defaults at once
      # @param new_defaults [Hash] New default values
      def self.defaults=(new_defaults)
        load_settings
        @settings.merge!(new_defaults)
        save_settings
      end

      # Set a single default value (persists to DB_Store for per-character storage)
      # @param key [Symbol] Setting name (:reserve, :adaptive)
      # @param value [Object] New value
      def self.set_default(key, value)
        load_settings
        @settings[key.to_sym] = value
        save_settings
      end

      # Get a default value
      # @param key [Symbol] Setting name
      # @return [Object] Current value
      def self.default(key)
        load_settings
        @settings.fetch(key.to_sym, DEFAULT_SETTINGS[key.to_sym])
      end

      # Reset defaults to factory values
      def self.reset_defaults
        @settings = DEFAULT_SETTINGS.dup
        save_settings
      end

      # Load settings from DB_Store (per-character)
      # @return [void]
      def self.load_settings
        return if @settings_loaded

        if defined?(Lich::Common::DB_Store) && defined?(XMLData) && !XMLData.game.to_s.empty? && !XMLData.name.to_s.empty?
          scope = "#{XMLData.game}:#{XMLData.name}"
          stored = Lich::Common::DB_Store.read(scope, 'lich_qstrike')
          @settings = DEFAULT_SETTINGS.merge(stored || {})
          @settings_loaded = true
        else
          # Fallback to in-memory defaults
          @settings ||= DEFAULT_SETTINGS.dup
        end
      end

      # Save settings to DB_Store (per-character)
      # @return [void]
      def self.save_settings
        if defined?(Lich::Common::DB_Store) && defined?(XMLData) && !XMLData.game.to_s.empty? && !XMLData.name.to_s.empty?
          scope = "#{XMLData.game}:#{XMLData.name}"
          Lich::Common::DB_Store.save(scope, 'lich_qstrike', @settings)
        end
      end

      # Reset settings loaded flag (for testing)
      # @return [void]
      def self.reset_settings_cache
        @settings_loaded = false
        @settings = nil
      end

      # === PRIMARY API ===

      # Calculate optimal QSTRIKE reduction that won't cause negative stamina
      #
      # @param reserve [Integer, nil] Minimum stamina to keep after QSTRIKE + attack (uses default if nil)
      # @param attack_cost [Integer] Stamina cost of attack being performed (default: 0)
      # @param attack_name [String, Symbol] Name of CMan/Weapon technique to look up cost (optional)
      # @param attack_rt [Integer, nil] The attack's actual roundtime (caps max useful reduction)
      # @return [Hash] Result hash with :seconds, :stamina_cost, :qstrike_cmd, etc.
      def self.calculate(reserve: nil, attack_cost: 0, attack_name: nil, attack_rt: nil)
        reserve ||= default(:reserve)
        # Look up attack cost if name provided
        if attack_name && attack_cost.zero?
          attack_cost = lookup_attack_cost(attack_name)
        end

        current_stamina = Char.stamina
        available = current_stamina - reserve - attack_cost

        if available <= 0
          return {
            seconds: 0,
            stamina_cost: 0,
            qstrike_cmd: nil,
            reason: :insufficient_stamina,
            current_stamina: current_stamina,
            available_stamina: available,
            attack_cost: attack_cost,
            reserve: reserve
          }
        end

        cost_per_second = cost_per_second_reduction
        max_seconds = find_max_seconds(available, cost_per_second)

        # Cap reduction based on attack's RT (can't reduce below 1 second)
        if attack_rt && attack_rt > 1
          max_useful = attack_rt - 1
          max_seconds = [max_seconds, max_useful].min
        end

        if max_seconds.positive?
          total_cost = cost_per_second * max_seconds
          {
            seconds: max_seconds,
            stamina_cost: total_cost,
            qstrike_cmd: "qstrike -#{max_seconds}",
            current_stamina: current_stamina,
            available_stamina: available,
            attack_cost: attack_cost,
            attack_rt: attack_rt,
            reserve: reserve,
            cost_per_second: cost_per_second,
            striking_asp_active: striking_asp_active?
          }
        else
          {
            seconds: 0,
            stamina_cost: 0,
            qstrike_cmd: nil,
            reason: :too_expensive,
            current_stamina: current_stamina,
            available_stamina: available,
            attack_cost: attack_cost,
            attack_rt: attack_rt,
            reserve: reserve,
            cost_per_second: cost_per_second
          }
        end
      end

      # Convenience method: returns just the command string
      #
      # @param reserve [Integer, nil] Minimum stamina to keep (uses default if nil)
      # @param attack_cost [Integer] Stamina cost of attack
      # @param attack_name [String, Symbol] Name of attack to look up cost
      # @param attack_rt [Integer, nil] The attack's actual roundtime (caps max useful reduction)
      # @return [String, nil] "qstrike -N" or nil if can't afford any reduction
      def self.command(reserve: nil, attack_cost: 0, attack_name: nil, attack_rt: nil)
        calculate(reserve: reserve, attack_cost: attack_cost, attack_name: attack_name, attack_rt: attack_rt)[:qstrike_cmd]
      end

      # Check if any QSTRIKE reduction is affordable
      #
      # @param reserve [Integer, nil] Minimum stamina to keep (uses default if nil)
      # @param attack_cost [Integer] Stamina cost of attack
      # @param attack_name [String, Symbol] Name of attack to look up cost
      # @param attack_rt [Integer, nil] The attack's actual roundtime (caps max useful reduction)
      # @return [Boolean] true if at least 1 second of reduction is affordable
      def self.affordable?(reserve: nil, attack_cost: 0, attack_name: nil, attack_rt: nil)
        result = calculate(reserve: reserve, attack_cost: attack_cost, attack_name: attack_name, attack_rt: attack_rt)
        result[:seconds].positive?
      end

      # === EXECUTION API ===

      # Execute QSTRIKE with an attack command
      #
      # @param reduction [Integer] RT reduction: negative = reduce by N seconds,
      #                            positive = target absolute RT
      # @param attack [String, Symbol] Attack to perform (e.g., "cripple", "attack", "mstrike")
      # @param target [String, nil] Target for the attack (optional)
      # @param reserve [Integer, nil] Stamina to reserve (uses default if nil)
      # @param adaptive [Boolean, nil] If true, use max affordable when can't afford requested (uses default if nil)
      # @return [Hash] Result with :success, :reduction_used, :reason, etc.
      #
      # @example Reduce RT by 3 seconds
      #   QStrike.use(reduction: -3, attack: "cripple", target: "kobold")
      #
      # @example Target absolute 2 second RT
      #   QStrike.use(reduction: 2, attack: "attack", target: "troll")
      #
      # @example Use maximum affordable reduction
      #   QStrike.use(reduction: :max, attack: "mstrike")
      #
      def self.use(reduction:, attack:, target: nil, reserve: nil, adaptive: nil)
        reserve ||= default(:reserve)
        adaptive = default(:adaptive) if adaptive.nil?

        attack_name = normalize_attack_name(attack)
        attack_cost = lookup_attack_cost(attack_name)

        # Determine the actual reduction to attempt
        actual_reduction = resolve_reduction(reduction, reserve, attack_cost)

        if actual_reduction.nil? || actual_reduction.zero?
          max_affordable = calculate(reserve: reserve, attack_cost: attack_cost)[:seconds]
          respond "[QStrike] Cannot afford any reduction. Stamina: #{Char.stamina}, Reserve: #{reserve}, Attack cost: #{attack_cost}"
          return {
            success: false,
            reason: :cannot_afford,
            requested_reduction: reduction,
            max_affordable: max_affordable
          }
        end

        # Check if we can afford the requested reduction
        qstrike_cost = cost_for_reduction(actual_reduction)
        available = Char.stamina - reserve - attack_cost

        if qstrike_cost > available
          if adaptive
            # Calculate what we can actually afford
            max_affordable = calculate(reserve: reserve, attack_cost: attack_cost)[:seconds]
            if max_affordable.positive?
              actual_reduction = max_affordable
              qstrike_cost = cost_for_reduction(actual_reduction)
            else
              respond "[QStrike] Insufficient stamina. Need: #{qstrike_cost}, Available: #{available} (after #{reserve} reserve + #{attack_cost} attack)"
              return {
                success: false,
                reason: :insufficient_stamina,
                requested_reduction: reduction,
                available_stamina: available,
                qstrike_cost: qstrike_cost
              }
            end
          else
            max_affordable = calculate(reserve: reserve, attack_cost: attack_cost)[:seconds]
            respond "[QStrike] Insufficient stamina for #{actual_reduction}s reduction. Need: #{qstrike_cost}, Available: #{available}. Max affordable: #{max_affordable}s"
            return {
              success: false,
              reason: :insufficient_stamina,
              requested_reduction: reduction,
              available_stamina: available,
              qstrike_cost: qstrike_cost,
              max_affordable: max_affordable
            }
          end
        end

        # Execute the qstrike and attack
        execute_qstrike(actual_reduction)
        execute_attack(attack, target)

        {
          success: true,
          reduction_used: actual_reduction,
          qstrike_cost: qstrike_cost,
          attack_cost: attack_cost,
          total_cost: qstrike_cost + attack_cost,
          stamina_after: Char.stamina - qstrike_cost - attack_cost
        }
      end

      # Calculate stamina cost for a specific reduction amount
      #
      # @param seconds [Integer] Seconds of RT reduction
      # @return [Integer] Stamina cost
      def self.cost_for_reduction(seconds)
        return 0 if seconds.nil? || seconds <= 0

        cost_per_second_reduction * seconds
      end

      # Get base RT for current weapon setup
      # Uses the primary weapon's base RT
      #
      # @return [Integer] Base roundtime in seconds
      def self.base_rt
        hand = ranged_weapon? ? GameObj.left_hand : GameObj.right_hand
        weapon_speed_for(hand)[:base_rt]
      end

      # Calculate reduction needed to achieve target absolute RT
      #
      # @param target_rt [Integer] Desired final roundtime
      # @return [Integer] Seconds of reduction needed (0 if target >= base)
      def self.reduction_for_target_rt(target_rt)
        current_base = base_rt
        return 0 if target_rt >= current_base

        [current_base - target_rt, MAX_REDUCTION].min
      end

      # === EQUIPMENT ANALYSIS ===

      # Find weapon stats using multiple lookup strategies
      # Tries: noun, then extracts weapon type from full name
      #
      # @param hand [GameObj] The hand to check
      # @return [Hash, nil] WeaponStats data or nil if not found
      def self.find_weapon_stats(hand)
        return nil if hand.nil?

        # Strategy 1: Try the noun directly (works for "dagger", "broadsword", etc.)
        stats = Armaments::WeaponStats.find(hand.noun)
        return stats if stats

        # Strategy 2: Try the full name (works for "slim short sword" -> finds "short sword")
        stats = Armaments::WeaponStats.find(hand.name)
        return stats if stats

        # Strategy 3: Extract weapon type from name by removing common adjectives
        # e.g., "slim short sword" -> try "short sword"
        name = hand.name.to_s.downcase
        adjectives = %w[slim gleaming steel iron silver gold mithril vultite golvern
                        ora krodera drakar rhimar gornar zorchar eonake faenor invar
                        kelyn laje razern rolaren vaalorn veil imflass alexandrite
                        black white red blue green small large heavy light ornate
                        polished rusted ancient old new fine]

        words = name.split
        # Remove leading adjectives
        while words.length > 1 && adjectives.include?(words.first)
          words.shift
        end

        # Try progressively shorter suffixes: "short sword", then "sword"
        while words.length > 0
          attempt = words.join(' ')
          stats = Armaments::WeaponStats.find(attempt)
          return stats if stats
          words.shift
        end

        nil
      end

      # Determine if using ranged weapon (bow/crossbow in LEFT hand)
      # @return [Boolean] true if ranged weapon detected in left hand
      def self.ranged_weapon?
        left = GameObj.left_hand
        return false if left.nil? || left.name == "Empty"

        stats = find_weapon_stats(left)
        stats&.dig(:category) == :ranged
      end

      # Get weapon stats and equipment speed for a hand
      #
      # @param hand [GameObj] The hand to check
      # @return [Hash] { base_rt: N, category: :sym, equipment_speed: N }
      def self.weapon_speed_for(hand)
        empty_result = { base_rt: 0, category: nil, equipment_speed: 0 }
        return empty_result if hand.nil? || hand.name == "Empty"

        stats = find_weapon_stats(hand)
        return empty_result unless stats

        base_rt = stats[:base_rt]
        base_rt = base_rt.first if base_rt.is_a?(Array)
        base_rt = base_rt.to_i

        category = stats[:category]
        multiplier = SPEED_MULTIPLIERS[category] || DEFAULT_MULTIPLIER

        # Equipment Speed = Weapon Base RT * Speed Modifier
        equipment_speed = (base_rt * multiplier).to_i

        { base_rt: base_rt, category: category, equipment_speed: equipment_speed }
      end

      # Get primary hand equipment speed
      # For ranged: LEFT hand is primary
      # For melee: RIGHT hand is primary
      #
      # @return [Integer] Equipment speed (base_rt * multiplier)
      def self.primary_equipment_speed
        hand = ranged_weapon? ? GameObj.left_hand : GameObj.right_hand
        weapon_speed_for(hand)[:equipment_speed]
      end

      # Get secondary hand equipment speed
      # For ranged: RIGHT hand is secondary
      # For melee: LEFT hand is secondary
      # Only weapons count - shields and non-weapons = 0
      #
      # @return [Integer] Equipment speed (base_rt * multiplier), or 0 if not a weapon
      def self.secondary_equipment_speed
        hand = ranged_weapon? ? GameObj.right_hand : GameObj.left_hand
        weapon_speed_for(hand)[:equipment_speed]
      end

      # Calculate stamina cost per second of RT reduction
      # Formula: (10 + primary_equipment_speed + (secondary_equipment_speed / 2)) * asp_multiplier
      #
      # @return [Integer] Cost per second (with Striking Asp discount if active)
      def self.cost_per_second_reduction
        # Check memoization cache
        return @cached_cost if valid_cache?

        primary = primary_equipment_speed
        secondary = secondary_equipment_speed

        # Base formula: 10 + primary + (secondary / 2)
        base_cost = BASE_COST + primary + (secondary / 2)

        # Apply Striking Asp discount if active
        final_cost = (base_cost * striking_asp_multiplier).to_i

        # Cache the result
        cache_cost(final_cost)

        final_cost
      end

      # Display detailed calculation breakdown for debugging
      # Shows all intermediate values used in cost calculation
      #
      # @return [void]
      def self.debug_calculation
        respond "=== QStrike Debug Calculation ==="

        # Right hand
        right = GameObj.right_hand
        respond "Right hand: #{right&.name || 'Empty'} (noun: #{right&.noun || 'nil'}, id: #{right&.id || 'nil'})"
        if right && right.name != "Empty"
          stats = find_weapon_stats(right)
          if stats
            respond "  Weapon found: #{stats[:base_name]} (category: #{stats[:category]})"
            respond "  base_rt: #{stats[:base_rt]}"
            multiplier = SPEED_MULTIPLIERS[stats[:category]] || DEFAULT_MULTIPLIER
            respond "  multiplier: #{multiplier}"
            equip_speed = (stats[:base_rt].to_i * multiplier).to_i
            respond "  equipment_speed: #{equip_speed}"
          else
            respond "  WARNING: No weapon stats found!"
          end
        end

        # Left hand
        left = GameObj.left_hand
        respond "Left hand: #{left&.name || 'Empty'} (noun: #{left&.noun || 'nil'}, id: #{left&.id || 'nil'})"
        if left && left.name != "Empty"
          stats = find_weapon_stats(left)
          if stats
            respond "  Weapon found: #{stats[:base_name]} (category: #{stats[:category]})"
            respond "  base_rt: #{stats[:base_rt]}"
            multiplier = SPEED_MULTIPLIERS[stats[:category]] || DEFAULT_MULTIPLIER
            respond "  multiplier: #{multiplier}"
            equip_speed = (stats[:base_rt].to_i * multiplier).to_i
            respond "  equipment_speed: #{equip_speed}"
          else
            respond "  WARNING: No weapon stats found!"
          end
        end

        # Primary/Secondary determination
        is_ranged = ranged_weapon?
        respond "Ranged mode: #{is_ranged}"
        respond "Primary hand: #{is_ranged ? 'LEFT' : 'RIGHT'}"
        respond "Secondary hand: #{is_ranged ? 'RIGHT' : 'LEFT'}"

        # Calculated values
        primary = primary_equipment_speed
        secondary = secondary_equipment_speed
        respond "Primary equipment_speed: #{primary}"
        respond "Secondary equipment_speed: #{secondary}"
        respond "Secondary / 2 (integer division): #{secondary / 2}"

        # Formula
        base_cost = BASE_COST + primary + (secondary / 2)
        respond "Formula: BASE_COST(#{BASE_COST}) + primary(#{primary}) + secondary/2(#{secondary / 2}) = #{base_cost}"

        # Striking Asp
        asp_mult = striking_asp_multiplier
        if (asp_mult - 1.0).abs > Float::EPSILON
          respond "Striking Asp multiplier: #{asp_mult}"
          final_cost = (base_cost * asp_mult).to_i
          respond "Final cost (with Asp): #{base_cost} * #{asp_mult} = #{final_cost}"
        else
          respond "Striking Asp: not active"
          respond "Final cost per second: #{base_cost}"
        end

        respond "=== End Debug ==="
      end

      # === STRIKING ASP SUPPORT ===

      # Check if Striking Asp stance is active
      # @return [Boolean]
      def self.striking_asp_active?
        return false unless defined?(Effects::Buffs)

        Effects::Buffs.active?('Striking Asp')
      rescue StandardError
        false
      end

      # Get Striking Asp rank (1, 2, or 3)
      # @return [Integer] Rank, or 0 if not known
      def self.striking_asp_rank
        return 0 unless defined?(CMan)

        CMan['striking_asp'].to_i
      rescue StandardError
        0
      end

      # Get the cost multiplier based on Striking Asp status
      # @return [Float] 1.0 if not active, or discounted multiplier if active
      def self.striking_asp_multiplier
        return 1.0 unless striking_asp_active?

        rank = striking_asp_rank
        STRIKING_ASP_MULTIPLIERS[rank] || 1.0
      end

      # === MEMOIZATION ===

      # Get a cache key for a hand (handles empty hands)
      # @param hand [GameObj, nil] The hand object
      # @return [String] Cache key representing this hand state
      def self.hand_cache_key(hand)
        return "empty" if hand.nil?
        return "empty" if hand.name.nil? || hand.name.empty? || hand.name == "Empty"
        return "empty" if hand.id.nil?

        "#{hand.id}:#{hand.noun}"
      end

      # Check if cached value is still valid (hands haven't changed)
      # @return [Boolean]
      def self.valid_cache?
        return false unless @cached_cost

        current_right = hand_cache_key(GameObj.right_hand)
        current_left = hand_cache_key(GameObj.left_hand)

        @cached_right_hand == current_right && @cached_left_hand == current_left
      rescue StandardError
        false
      end

      # Store cost in cache with current hand state
      # @param cost [Integer] The calculated cost to cache
      def self.cache_cost(cost)
        @cached_cost = cost
        @cached_right_hand = hand_cache_key(GameObj.right_hand)
        @cached_left_hand = hand_cache_key(GameObj.left_hand)
      rescue StandardError
        # Ignore caching errors
      end

      # Clear the cache (call if you know equipment changed)
      def self.clear_cache
        @cached_cost = nil
        @cached_right_hand = nil
        @cached_left_hand = nil
      end

      # === ATTACK COST LOOKUP ===

      # Module lookup configuration: [Module, class_var, type_symbol]
      TECHNIQUE_MODULES = [
        [:CMan, :@@combat_mans, :cman],
        [:Weapon, :@@weapon_techniques, :weapon],
        [:Shield, :@@shield_techniques, :shield],
      ].freeze

      # Look up stamina cost for a CMan or Weapon technique
      #
      # @param name [String, Symbol] Attack name
      # @return [Integer] Stamina cost, or 0 if not found
      def self.lookup_attack_cost(name)
        name = name.to_s.downcase.gsub(/[\s-]+/, '_')

        # Handle explicit type prefixes for disambiguation
        TECHNIQUE_MODULES.each do |_, _, type|
          prefix = "#{type}_"
          return lookup_technique_cost(name.sub(prefix, ''), type) if name.start_with?(prefix)
        end

        # Try each module in order until we find a cost
        TECHNIQUE_MODULES.each do |_, _, type|
          cost = lookup_technique_cost(name, type)
          return cost if cost.positive?
        end

        0
      end

      # Generic technique cost lookup
      # @param name [String] Normalized attack name
      # @param type [Symbol] Technique type (:cman, :weapon, :shield)
      # @return [Integer] Stamina cost, or 0 if not found
      def self.lookup_technique_cost(name, type)
        mod_name, class_var, = TECHNIQUE_MODULES.find { |_, _, t| t == type }
        return 0 unless mod_name && defined_module?(mod_name)

        mod = Object.const_get(mod_name)
        data = mod.class_variable_get(class_var)
        entry = data[name] || data.values.find { |v| v[:short_name] == name }
        entry&.dig(:cost, :stamina).to_i
      rescue StandardError
        0
      end

      # Check if a module is defined
      # @param mod_name [Symbol] Module name
      # @return [Boolean]
      def self.defined_module?(mod_name)
        Object.const_defined?(mod_name)
      rescue StandardError
        false
      end

      # Find maximum seconds of reduction affordable
      #
      # @param available_stamina [Integer] Stamina available for QSTRIKE
      # @param cost_per_second [Integer] Cost per second of reduction
      # @return [Integer] Max seconds (0 if can't afford any)
      def self.find_max_seconds(available_stamina, cost_per_second)
        return 0 if cost_per_second <= 0

        # Simple division - how many full seconds can we afford?
        max = available_stamina / cost_per_second

        # Cap at reasonable maximum
        [max, MAX_REDUCTION].min
      end

      # === EXECUTION HELPERS (PRIVATE) ===

      # Resolve reduction value to actual seconds
      # Handles :max, negative (reduce by N), and positive (target RT)
      #
      # @param reduction [Integer, Symbol] Reduction specification
      # @param reserve [Integer] Stamina reserve
      # @param attack_cost [Integer] Attack stamina cost
      # @return [Integer, nil] Actual seconds of reduction, or nil if invalid
      def self.resolve_reduction(reduction, reserve, attack_cost)
        case reduction
        when :max, :optimal
          calculate(reserve: reserve, attack_cost: attack_cost)[:seconds]
        when Integer
          if reduction.negative?
            # Negative = reduce by that many seconds
            reduction.abs
          elsif reduction.positive?
            # Positive = target absolute RT
            reduction_for_target_rt(reduction)
          else
            0
          end
        else
          nil
        end
      end

      # Normalize attack name for lookup
      #
      # @param attack [String, Symbol] Attack name or command
      # @return [String] Normalized name
      def self.normalize_attack_name(attack)
        attack.to_s.downcase.gsub(/[\s-]+/, '_').gsub(/[^a-z0-9_]/, '')
      end

      # Execute the qstrike command
      #
      # @param reduction [Integer] Seconds of reduction
      def self.execute_qstrike(reduction)
        return if reduction.nil? || reduction <= 0

        fput "qstrike -#{reduction}"
      end

      # Execute the attack command using appropriate method
      #
      # @param attack [String, Symbol] Attack name or command
      # @param target [String, nil] Target for the attack
      def self.execute_attack(attack, target = nil)
        attack_str = attack.to_s
        normalized = normalize_attack_name(attack)

        # Detect and execute based on attack type
        attack_type = detect_attack_type(normalized)

        case attack_type
        when :cman
          if defined?(CMan) && CMan.respond_to?(:use)
            CMan.use(normalized, target)
          else
            fput build_attack_command(attack_str, target)
          end
        when :weapon
          if defined?(Weapon) && Weapon.respond_to?(:use)
            Weapon.use(normalized, target)
          else
            fput build_attack_command(attack_str, target)
          end
        when :shield
          if defined?(Shield) && Shield.respond_to?(:use)
            Shield.use(normalized, target)
          else
            fput build_attack_command(attack_str, target)
          end
        else
          # Basic command - just send it
          fput build_attack_command(attack_str, target)
        end
      end

      # Detect what type of attack this is
      #
      # @param name [String] Normalized attack name
      # @return [Symbol] :cman, :weapon, :shield, or :basic
      def self.detect_attack_type(name)
        TECHNIQUE_MODULES.each do |mod_name, class_var, type|
          next unless defined_module?(mod_name)

          begin
            mod = Object.const_get(mod_name)
            data = mod.class_variable_get(class_var)
            return type if data.key?(name) || data.values.any? { |v| v[:short_name] == name }
          rescue StandardError
            next
          end
        end

        :basic
      end

      # Build attack command string
      #
      # @param attack [String] Attack command
      # @param target [String, nil] Target
      # @return [String] Full command string
      def self.build_attack_command(attack, target = nil)
        if target && !target.empty?
          "#{attack} #{target}"
        else
          attack
        end
      end
    end
  end
end

# Top-level convenience alias
QStrike = Lich::Gemstone::QStrike unless defined?(QStrike)
