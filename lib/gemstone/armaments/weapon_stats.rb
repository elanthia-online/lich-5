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
        # Finds the weapon's stats hash by one of its names.
        #
        # @param name [String] The name or alias of the weapon.
        # @param category [Symbol, nil] (optional) The weapon category to narrow the search.
        # @return [Hash, nil] The stats hash of the matching weapon, or nil if not found.
        def self.find(name, category = nil)
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
        # Returns a list of weapon stat hashes, optionally filtered by category.
        #
        # @param category [Symbol, nil] the weapon category to limit results (e.g., :edged, :polearm)
        # @return [Array<Hash>] array of weapon stat hashes
        def self.list(category = nil)
          result = []
          if category
            result.concat(@@weapon_stats[category]&.values || [])
          else
            @@weapon_stats.each_value do |weapons|
              result.concat(weapons.values)
            end
          end
          result
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

          weapon = self.find(name, category)
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

          weapon = self.find(name, category)
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
        def self.compare(name1, name2, category1 = nil, category2 = nil)
          name1 = name1.downcase.strip
          name2 = name2.downcase.strip

          return nil if name1 == name2 && category1 == category2

          w1 = self.find(name1, category1)
          w2 = self.find(name2, category2)
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
        def self.weapons_in_category(category)
          category = category.to_sym
          return [] unless @@weapon_stats.key?(category)

          @@weapon_stats[category].values
        end

        ##
        # Returns all recognized weapon names and aliases across all categories.
        #
        # @return [Array<String>] all valid weapon names (including base names and aliases)
        def self.names
          @@weapon_stats.values.flat_map do |weapons|
            weapons.values.map { |w| w[:all_names] }
          end.flatten.compact.uniq
        end

        ##
        # Determines whether the specified weapon is grippable (e.g., bastard sword).
        #
        # @param name [String] the name or alias of the weapon
        # @return [Boolean] true if the weapon is grippable, false otherwise
        def self.is_grippable?(name)
          name = name.downcase.strip

          weapon = self.find(name)

          weapon && weapon[:grippable?] == true
        end

        ##
        # Returns the weapon category for the given name.
        #
        # @param name [String] the weapon name or alias
        # @return [Symbol, nil] the category symbol (e.g., :OHE, :THW) or nil
        def self.category_for(name)
          name = name.downcase.strip

          weapon = self.find(name)
          weapon ? weapon[:category] : nil
        end

        ##
        # Pretty-prints a weapon's data by name in long format.
        #
        # @param name [String] the name or alias of the weapon
        # @return [String] formatted weapon display string
        def self.pretty_long(name)
          weapon = self.find(name)
          return "\n(no data)\n" unless weapon.is_a?(Hash)

          lines = []

          core_fields = [
            :category, :base_name, :all_names, :base_rt, :min_rt,
            :grippable?, :weighting_type, :weighting_amount
          ]

          # Field labels for max width calc
          top_labels = core_fields.map(&:to_s) + ["damage_types", "damage_factor", "avd_by_asg"]
          nested_labels = %w[slash crush puncture special] +
                          Armaments::AG_INDEX_TO_NAME.values +
                          Armaments::ASG_INDEX_TO_NAME.values

          indent = 2
          max_label_width = (top_labels + nested_labels.map { |s| " " * indent + s })
                            .map(&:length).max

          # Print top-level fields
          core_fields.each do |key|
            next unless weapon.key?(key)
            val = weapon[key]
            str_val = val.is_a?(Array) ? val.join(", ") : val.to_s
            lines << "%-#{max_label_width}s : %s" % [key.to_s, str_val]
          end

          # Damage Types
          if weapon[:damage_types].is_a?(Hash)
            lines << "%-#{max_label_width}s :" % "damage_types"
            sub_indent = 2
            sub_label_width = max_label_width - sub_indent
            weapon[:damage_types].each do |type, value|
              val_str = (type == :special) ? (value.empty? ? "(none)" : value.join(", ")) : value.to_s
              lines << "%s%-#{sub_label_width}s : %s" % [" " * sub_indent, type.to_s, val_str]
            end
          end

          # Damage Factor
          if weapon[:damage_factor].is_a?(Array)
            lines << "%-#{max_label_width}s :" % "damage_factor"
            weapon[:damage_factor][1..].each_with_index do |df, i|
              ag_index = i + 1
              label = Armaments::AG_INDEX_TO_NAME[ag_index] || "AG #{ag_index}"
              lines << "  %-#{max_label_width - indent}s : %s" % [label, df]
            end
          end

          # AvD by ASG
          if weapon[:avd_by_asg].is_a?(Array)
            lines << "%-#{max_label_width}s :" % "avd_by_asg"
            weapon[:avd_by_asg][1..].each_with_index do |avd, i|
              next unless avd
              label = Armaments::ASG_INDEX_TO_NAME[i + 1] || "ASG #{i + 1}"
              lines << "  %-#{max_label_width - indent}s : %s" % [label, avd]
            end
          end

          lines.join("\n")
        end

        ##
        # Pretty-prints a weapon's data by name in long format.
        #
        # @param name [String] the name or alias of the weapon
        # @return [String] formatted weapon display string
        def self.pretty(name)
          weapon = self.find(name)
          return "\n(no data)\n" unless weapon.is_a?(Hash)

          lines = []
          lines << "" # leading blank

          [:category, :base_name, :all_names, :base_rt, :min_rt, :grippable?, :weighting_type, :weighting_amount].each do |key|
            next unless weapon.key?(key)
            val = weapon[key]
            str_val = val.is_a?(Array) ? val.join(", ") : val.to_s
            lines << "%-18s: %s" % [key.to_s, str_val]
          end

          # damage types inline (always show, hash style)
          if weapon[:damage_types].is_a?(Hash)
            damage_str = weapon[:damage_types].map do |type, val|
              if type == :special
                "special=[#{val.join(", ")}]"
              else
                "#{type}=#{val}"
              end
            end.join(", ")
            lines << "% -18s: %s" % ["damage_types", damage_str]
          end

          # damage_factor inline
          if weapon[:damage_factor].is_a?(Array)
            df = weapon[:damage_factor][1..] || []
            df_str = df.each_with_index.map { |v, i| "AG%-2d=%0.3f" % [i + 1, v] }.join("  ")
            lines << "%-18s: %s" % ["damage_factor", df_str]
          end

          # AVD in aligned two-line block
          if weapon[:avd_by_asg].is_a?(Array)
            avds = weapon[:avd_by_asg][1..] || []

            col_width = 4
            header = avds.each_index.map { |i| i + 1 }.map { |asg| asg.to_s.rjust(col_width) }.join
            values = avds.map { |v| v.nil? ? '--'.rjust(col_width) : v.to_s.rjust(col_width) }.join

            lines << "%-18s: %s" % ["avd_by_asg", header]
            lines << " " * 20 + values
          end

          lines << "" # trailing blank
          lines.join("\n")
        end

        ##
        # Checks if the provided name is a valid weapon alias.
        #
        # @param name [String] the weapon name or alias
        # @return [Boolean] true if recognized, false otherwise
        def self.valid_name?(name)
          name = name.downcase.strip
          @@weapon_stats.values.any? do |weapons|
            weapons.values.any? { |w| w[:all_names].include?(name) }
          end
        end
      end
    end
  end
end
