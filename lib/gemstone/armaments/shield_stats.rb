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
        @@shield_stats = [
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
        ]

        # Finds the shield's stats hash by one of its alternative names.
        #
        # @param name [String] the name or alias of the shield to search for.
        # @return [Hash, nil] the stats hash of the matching shield, or nil if not found.
        def self.find_type_by_name(name)
          _, shield_info = @@shield_stats.find { |_, stats| stats[:all_names].include?(name) }
          return shield_info
        end

        # Finds the shield's stats hash by either base name or an alternative name.
        #
        # @param type [String] the base name or alias of the shield.
        # @return [Hash, nil] the stats hash of the matching shield, or nil if not found.
        def self.find_category_info(category)
          _, shield_info = @@shield_stats.find { |_, stats| stats[:category] == category }
          return shield_info
        end
      end
    end
  end
end
