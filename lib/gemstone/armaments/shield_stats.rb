module Lich
  module Gemstone
    module Armaments
      # ShieldStats module provides utility methods for handling shield data,
      # including retrieving shield information based on alternative names and
      # categories.
      module ShieldStats
        # Static array of shield stats indexed by shield identifiers. Each shield
        # entry contains metadata such as category, alternative names, size and
        # evade modifiers, and base weight.
        @@shield_stats = {
          :small_shield  => {
            :category       => :small_shield,
            :base_name      => "small shield",
            :all_names      => ["buckler", "kidney shield", "small shield", "targe"],
            :size_modifier  => -0.15,
            :evade_modifier => -0.22,
            :base_weight    => 6,
          },
          :medium_shield => {
            :category       => :medium_shield,
            :base_name      => "medium shield",
            :all_names      => ["battle shield", "heater", "heater shield", "knight's shield", "krytze", "lantern shield", "medium shield", "parma", "target shield"],
            :size_modifier  => 0.0,
            :evade_modifier => -0.30,
            :base_weight    => 8,
          },
          :large_shield  => {
            :category       => :large_shield,
            :base_name      => "large shield",
            :all_names      => ["aegis", "kite shield", "large shield", "pageant shield", "round shield", "scutum"],
            :size_modifier  => 0.15,
            :evade_modifier => -0.38,
            :base_weight    => 9,
          },
          :tower_shield  => {
            :category       => :tower_shield,
            :base_name      => "tower shield",
            :all_names      => ["greatshield", "mantlet", "pavis", "tower shield", "wall shield"],
            :size_modifier  => 0.30,
            :evade_modifier => -0.50,
            :base_weight    => 12,
          },
        }

        Lich::Util.deep_freeze(@@shield_stats)

        ##
        # Finds the shield stats hash by category symbol.
        #
        # @param category [Symbol] The shield category (e.g., :small_shield, :tower_shield).
        # @return [Hash, nil] The stats hash of the matching shield, or nil if not found.
        #
        # @example
        #   ShieldStats.find_by_category(:small_shield)
        #   #=> { :category => :small_shield, :base_name => "small shield", ... }
        def self.find_by_category(category)
          _, shield_info = @@shield_stats.find { |_, stats| stats[:category] == category }
          shield_info
        end

        ##
        # Returns a list of all recognized shield names across all shield categories.
        #
        # @return [Array<String>] All valid shield names.
        #
        # @example
        #   ShieldStats.names
        #   #=> ["buckler", "kidney shield", "small shield", ...]
        def self.names
          @@shield_stats.map { |_, s| s[:all_names] }.flatten.uniq
        end

        ##
        # Finds a shield entry by name or alias.
        #
        # @param name [String] the name or alias of the shield (e.g., "aegis", "tower shield")
        # @return [Hash, nil] the shield stats hash if found, or nil
        #
        # @example
        #   ShieldStats.find("tower shield")
        #   #=> { :category => :tower_shield, :base_name => "tower shield", ... }
        def self.find(name)
          name = name.downcase.strip

          @@shield_stats.each_value do |shield|
            return shield if shield[:all_names]&.map(&:downcase)&.include?(name)
          end

          nil
        end

        ##
        # Lists all shields with an evade modifier between a given range.
        #
        # @param min [Float] Minimum evade modifier (inclusive).
        # @param max [Float] Maximum evade modifier (inclusive).
        # @return [Array<Hash>] Array of shield stat hashes matching the criteria.
        #
        # @example
        #   ShieldStats.list_shields_by_evade_modifier(min: -0.4, max: 0.0)
        #   #=> [ { :category => :large_shield, ... }, { :category => :medium_shield, ... } ]
        def self.list_shields_by_evade_modifier(min:, max:)
          @@shield_stats.map(&:last).select do |shield|
            shield[:evade_modifier].between?(min, max)
          end
        end

        ##
        # Returns all defined shield category keys.
        #
        # @return [Array<Symbol>] an array of shield categories (e.g., [:small_shield, :medium_shield, :large_shield, :tower_shield])
        #
        # @example
        #   ShieldStats.categories
        #   #=> [:small_shield, :medium_shield, :large_shield, :tower_shield]
        def self.categories
          @@shield_stats.keys
        end

        ##
        # Returns the category for the given shield name.
        #
        # @param name [String] the shield name or alias
        # @return [Symbol, nil] the category symbol (e.g., :small_shield) or nil
        #
        # @example
        #   ShieldStats.category_for("buckler")
        #   #=> :small_shield
        def self.category_for(name)
          name = name.downcase.strip

          shield = find_shield(name)
          shield ? shield[:category] : nil
        end

        ##
        # Prints a concise summary of shield metadata in a single block.
        #
        # @param name [String] the base name or alias of the shield
        # @return [String] formatted one-block summary or (no data) if not found
        #
        # @example
        #   puts ShieldStats.pretty("tower shield")
        #   #=> (prints formatted summary)
        def self.pretty(name)
          shield = find_shield(name)
          return "\n(no data)\n" unless shield.is_a?(Hash)

          lines = []
          lines << ""

          fields = {
            "Shield"      => shield[:base_name],
            "Category"    => shield[:category].to_s.gsub('_', ' ').capitalize,
            "Size Mod"    => format('%.2f', shield[:size_modifier]),
            "Evade Mod"   => format('%.2f', shield[:evade_modifier]),
            "Base Weight" => "#{shield[:base_weight]} lbs"
          }

          max_label = fields.keys.map(&:length).max

          fields.each do |label, value|
            lines << "%-#{max_label}s: %s" % [label, value]
          end

          if shield[:all_names]&.any?
            lines << "%-#{max_label}s: %s" % ["Alternate", shield[:all_names].join(", ")]
          end

          lines << ""
          lines.join("\n")
        end

        ##
        # Pretty-prints a shield's data in long format.
        # Currently identical to `.pretty`.
        #
        # @param name [String] the name or alias of the shield
        # @return [String] formatted display string
        #
        # @example
        #   puts ShieldStats.pretty_long("buckler")
        #   #=> (prints formatted summary)
        def self.pretty_long(name)
          pretty(name)
        end

        ##
        # Returns all known aliases for a given shield name or alias.
        #
        # @param name [String] the shield name or alias
        # @return [Array<String>] array of alternate names or [] if not found
        #
        # @example
        #   ShieldStats.aliases_for("kite shield")
        #   #=> ["aegis", "kite shield", "large shield", ...]
        def self.aliases_for(name)
          name = name.downcase.strip
          shield = find_shield(name)
          shield ? shield[:all_names] : []
        end

        ##
        # Compares two shields and returns key stat differences.
        #
        # @param name1 [String] first shield name
        # @param name2 [String] second shield name
        # @return [Hash, nil] comparison of shield properties, or nil if either is not found
        #
        # @example
        #   ShieldStats.compare("buckler", "tower shield")
        #   #=> { name1: "small shield", name2: "tower shield", ... }
        def self.compare(name1, name2)
          name1 = name1.downcase.strip
          name2 = name2.downcase.strip

          s1 = find(name1)
          s2 = find(name2)
          return nil unless s1 && s2

          {
            name1: s1[:base_name],
            name2: s2[:base_name],
            size_modifier: [s1[:size_modifier], s2[:size_modifier]],
            evade_modifier: [s1[:evade_modifier], s2[:evade_modifier]],
            base_weight: [s1[:base_weight], s2[:base_weight]],
            category: [s1[:category], s2[:category]],
            aliases: [s1[:all_names], s2[:all_names]]
          }
        end

        ##
        # Searches the shield stats using optional filters.
        #
        # @param filters [Hash] filtering criteria
        #   - :name [String] matches name/alias
        #   - :category [Symbol] e.g., :small_shield
        #   - :min_evade_modifier [Float]
        #   - :max_evade_modifier [Float]
        #   - :min_size_modifier [Float]
        #   - :max_size_modifier [Float]
        #   - :max_weight [Integer]
        # @return [Array<Hash>] array of matching shield stat hashes
        #
        # @example
        #   ShieldStats.search(category: :large_shield, max_weight: 10)
        #   #=> [ { :category => :large_shield, ... } ]
        def self.search(filters = {})
          @@shield_stats.values.select do |shield|
            next if filters[:name] && !shield[:all_names].include?(filters[:name].downcase.strip)
            next if filters[:category] && shield[:category] != filters[:category]
            next if filters[:min_evade_modifier] && shield[:evade_modifier] < filters[:min_evade_modifier]
            next if filters[:max_evade_modifier] && shield[:evade_modifier] > filters[:max_evade_modifier]
            next if filters[:min_size_modifier] && shield[:size_modifier] < filters[:min_size_modifier]
            next if filters[:max_size_modifier] && shield[:size_modifier] > filters[:max_size_modifier]
            next if filters[:max_weight] && shield[:base_weight] > filters[:max_weight]

            true
          end
        end

        ##
        # Checks if a given name is a valid shield name.
        #
        # @param name [String] the name or alias to check
        # @return [Boolean] true if the name is recognized, false otherwise
        #
        # @example
        #   ShieldStats.valid_name?("targe")
        #   #=> true
        def self.valid_name?(name)
          name = name.downcase.strip
          all_shield_names.include?(name)
        end
      end
    end
  end
end
