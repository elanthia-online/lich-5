require_relative "weapon_stats_brawling.rb"
require_relative "weapon_stats_hybrid.rb"
require_relative "weapon_stats_ranged.rb"
require_relative "weapon_stats_blunt.rb"
require_relative "weapon_stats_edged.rb"
require_relative "weapon_stats_natural.rb"
require_relative "weapon_stats_polearm.rb"
require_relative "weapon_stats_runestave.rb"
require_relative "weapon_stats_thrown.rb"
require_relative "weapon_stats_two_handed.rb"
require_relative "weapon_stats_unarmed.rb"

module Lich
  module Gemstone
    module Armaments
      # WeaponStats module contains metadata definitions for individual weapons,
      # including their category, base and alternate names, damage profiles,
      # effectiveness against armor, and attack speeds.
      module WeaponStats
        # Static array of weapon stats indexed by weapon identifiers. Each weapon
        # entry contains metadata such as category, base name, alternative names,
        # damage types, damage factors, armor avoidance by armor size group (ASG),
        # base roundtime (RT), and minimum RT.
        #
        # damage_types: Hash of damage type percentages or values.
        #   :slash    => % of slash damage (Float or nil)
        #   :crush    => % of crush damage (Float or nil)
        #   :puncture => % of puncture damage (Float or nil)
        #   :special  => Array of special damage types (or nil)
        #
        # damage factor array:
        #  [0] = nil (none)    [1] = Cloth    [2] = Leather    [3] = Scale    [4] = Chain    [5] = Plate
        #
        # avd_by_asg array:
        #  Cloth:   [1] ASG 1    [2] ASG 2      [3] nil      [4] nil
        #  Leather: [5] ASG 5    [6] ASG 6    [7] ASG 7    [8] ASG 8
        #  Scale:   [9] ASG 9    [10] ASG 10  [11] ASG 11  [12] ASG 12
        #  Chain:   [13] ASG 13  [14] ASG 14  [15] ASG 15  [16] ASG 16
        #  Plate:   [17] ASG 17  [18] ASG 18  [19] ASG 19  [20] ASG 20

        @@weapon_stats = {
          brawling: @@weapon_stats_brawling,
          hybrid: @@weapon_stats_hybrid,
          missile: @@weapon_stats_ranged,
          blunt: @@weapon_stats_blunt,
          edged: @@weapon_stats_edged,
          natural: @@weapon_stats_natural,
          polearm: @@weapon_stats_polearm,
          runestave: @@weapon_stats_runestave,
          thrown: @@weapon_stats_thrown,
          two_handed: @@weapon_stats_two_handed,
          unarmed: @@weapon_stats_unarmed,
        }

        Lich::Util.deep_freeze(@@weapon_stats)

        ##
        # Finds the category symbol (e.g., :edged, :polearm) for a given weapon name.
        #
        # @param name [String] The name or alias of the weapon.
        # @return [Symbol, nil] The category symbol if found, or nil.
        def self.find_category(name)
          name = name.downcase.strip

          @@weapon_stats.each do |category, weapons|
            weapons.each_value do |weapon_info|
              return category if weapon_info[:all_names]&.include?(name)
            end
          end

          nil
        end

        ##
        # Finds the weapon's stats hash by one of its names.
        #
        # @param name [String] The name or alias of the weapon.
        # @param category [Symbol, nil] (optional) The weapon category to narrow the search.
        # @return [Hash, nil] The stats hash of the matching weapon, or nil if not found.
        def self.find_weapon(name, category = nil)
          name = name.downcase.strip

          unless category.nil?
            weapons = @@weapon_stats[category]
            return nil unless weapons

            weapons.each_value do |weapon_info|
              return weapon_info if weapon_info[:all_names]&.include?(name)
            end
          else
            @@weapon_stats.each_value do |weapons|
              weapons.each_value do |weapon_info|
                return weapon_info if weapon_info[:all_names]&.include?(name)
              end
            end
          end
          nil
        end

        ##
        # Lists all weapon base names, optionally filtered by weapon category.
        #
        # @param category [Symbol, nil] the weapon category to limit the results (e.g., :edged, :polearm)
        # @return [Array<String>] an array of base weapon names
        def self.list_weapons(category = nil)
          result = []
          if category
            @@weapon_stats[category]&.each_value do |weapon_info|
              result << weapon_info[:base_name]
            end
          else
            @@weapon_stats.each_value do |weapons|
              weapons.each_value { |weapon_info| result << weapon_info[:base_name] }
            end
          end
          result.uniq
        end

        ##
        # Returns a list of all defined weapon categories.
        #
        # @return [Array<Symbol>] an array of weapon category symbols
        def self.categories
          @@weapon_stats.keys
        end

        ##
        # Returns a simplified hash of a weapon’s damage type breakdown.
        #
        # @param name [String] a weapon name or alias
        # @param category [Symbol, nil] optional category to narrow the search
        # @return [Hash, nil] damage type summary or nil if not found
        def self.damage_summary(name, category = nil)
          name = name.downcase.strip

          weapon = find_weapon(name, category)
          return nil unless weapon

          {
            base_name: weapon[:base_name],
            slash: weapon[:damage_types][:slash],
            crush: weapon[:damage_types][:crush],
            puncture: weapon[:damage_types][:puncture],
            special: weapon[:damage_types][:special]
          }
        end

        ##
        # Returns all recognized names for a given weapon.
        #
        # @param name [String] the base name or any alias of the weapon
        # @param category [Symbol, nil] optional category to limit the search
        # @return [Array<String>] an array of all recognized names for the weapon
        def self.aliases_for(name, category = nil)
          name = name.downcase.strip

          weapon = find_weapon(name, category)
          weapon ? weapon[:all_names] : []
        end

        ##
        # Compares two weapons and returns key stat differences.
        #
        # @param name1 [String] first weapon name or alias
        # @param name2 [String] second weapon name or alias
        # @param category1 [Symbol, nil] optional category for first weapon
        # @param category2 [Symbol, nil] optional category for second weapon
        # @return [Hash, nil] comparison data or nil if either weapon not found
        def self.compare_weapons(name1, name2, category1 = nil, category2 = nil)
          name1 = name1.downcase.strip
          name2 = name2.downcase.strip

          return nil if name1 == name2
          return nil if category1 == category2

          w1 = find_weapon(name1, category1)
          w2 = find_weapon(name2, category2)
          return nil unless w1 && w2

          {
            name1: w1[:base_name],
            name2: w2[:base_name],
            damage_types: [w1[:damage_types], w2[:damage_types]],
            damage_factors: [w1[:damage_factor], w2[:damage_factor]],
            avd_by_asg: [w1[:avd_by_asg], w2[:avd_by_asg]],
            base_rt: [w1[:base_rt], w2[:base_rt]],
            min_rt: [w1[:min_rt], w2[:min_rt]]
          }
        end

        ##
        # Searches the weapon stats using optional filters.
        #
        # @param filters [Hash] Filter options to apply (all must match)
        # @option filters [Symbol] :category          The weapon category (e.g., :edged, :polearm)
        # @option filters [Symbol] :damage_type       The damage type (:slash, :crush, :puncture, or :special)
        # @option filters [Integer] :max_base_rt      Maximum allowed base roundtime
        # @option filters [Hash]   :min_avd_by_asg    AVD requirement for a given ASG, e.g., { asg: 14, min: 25 }
        # @option filters [Hash]   :min_df_by_ag      DF requirement for a given armor group, e.g., { ag: 3, min: 0.200 }
        # @return [Array<Hash>] List of matching weapon stat hashes
        def self.search(filters = {})
          results = []

          @@weapon_stats.each do |category, weapons|
            next if filters[:category] && filters[:category] != category

            weapons.each_value do |weapon|
              # Filter by damage type (including special)
              if filters[:damage_type]
                damage_types = weapon[:damage_types]
                next unless damage_types

                if filters[:damage_type] == :special
                  specials = damage_types[:special]
                  next if !specials || specials.empty? || specials.include?(:none)
                else
                  value = damage_types[filters[:damage_type]] || 0.0
                  next if value <= 0.0
                end
              end

              # Filter by base roundtime
              if filters[:max_base_rt]
                base_rt = weapon[:base_rt]
                next if base_rt.nil? || base_rt > filters[:max_base_rt]
              end

              # Filter by AVD value at a specific ASG
              if filters[:min_avd_by_asg]
                asg = filters[:min_avd_by_asg][:asg]
                min = filters[:min_avd_by_asg][:min]
                avd = weapon[:avd_by_asg]
                next unless avd && asg.between?(1, 20)
                next if avd[asg].nil? || avd[asg] < min
              end

              # Filter by DF against a given armor group
              if filters[:min_df_by_ag]
                ag = filters[:min_df_by_ag][:ag]
                min = filters[:min_df_by_ag][:min]
                df = weapon[:damage_factor]
                next unless df && ag.between?(1, 5)
                next if df[ag].nil? || df[ag] < min
              end

              results << weapon
            end
          end

          results
        end

        ##
        # Returns all weapon data entries within a given category.
        #
        # @param category [Symbol, String] the weapon category (e.g., :OHE, :THW)
        # @return [Array<Hash>] array of weapon stat hashes for that category
        def self.all_weapons_in_category(category)
          category = category.to_sym
          return [] unless @@weapon_stats.key?(category)

          @@weapon_stats[category].values
        end

        ##
        # Returns a list of all defined weapon categories.
        #
        # @return [Array<Symbol>] an array of weapon category symbols (e.g., [:OHE, :THW])
        def self.all_categories
          @@weapon_stats.keys
        end

        ##
        # Determines whether the specified weapon is grippable (e.g., bastard sword).
        #
        # @param name [String] the name or alias of the weapon
        # @return [Boolean] true if the weapon is grippable, false otherwise
        def self.is_grippable?(name)
          name = name.downcase.strip

          weapon = find_weapon(name)

          weapon && weapon[:gripable?] == true
        end

        ##
        # Returns the weapon category for the given name.
        #
        # @param name [String] the weapon name or alias
        # @return [Symbol, nil] the category symbol (e.g., :OHE, :THW) or nil
        def self.category_for(name)
          weapon = find_weapon(name)
          weapon ? weapon[:category] : nil
        end
      end
    end
  end
end
