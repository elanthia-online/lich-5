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

        ##
        # Finds the shield stats hash by category symbol.
        #
        # @param category [Symbol] The shield category (e.g., :small_shield, :tower_shield).
        # @return [Hash, nil] The stats hash of the matching shield, or nil if not found.
        def self.find_shield_by_category(category)
          _, shield_info = @@shield_stats.find { |_, stats| stats[:category] == category }
          shield_info
        end

        ##
        # Returns a list of all recognized shield names across all shield categories.
        #
        # @return [Array<String>] All valid shield names.
        def self.all_shield_names
          @@shield_stats.map { |_, s| s[:all_names] }.flatten.uniq
        end

        ##
        # Returns the shield stats hash matching a given name (either base or alias).
        # WARNING: Matching by name may not return correct information due to historical name use
        #
        # @param name [String] The name or alias of the shield.
        # @return [Hash, nil] The full stats hash for the matching shield, or nil if not found.
        def self.find_shield(name)
          normalized = Lich::Util.normalize_name(name)

          _, shield_info = @@shield_stats.find { |_, stats| stats[:all_names].include?(normalized) }
          shield_info
        end

        ##
        # Lists all shields with an evade modifier between a given range.
        #
        # @param min [Float] Minimum evade modifier (inclusive).
        # @param max [Float] Maximum evade modifier (inclusive).
        # @return [Array<Hash>] Array of shield stat hashes matching the criteria.
        def self.list_shields_by_evade_modifier(min:, max:)
          @@shield_stats.map(&:last).select do |shield|
            shield[:evade_modifier].between?(min, max)
          end
        end
      end
    end
  end
end
