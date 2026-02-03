# frozen_string_literal: true

require "ostruct"

module Lich
  module Gemstone
    module Enhancive
      # Stats - all 10 stats including influence
      STATS = %i[strength constitution dexterity agility discipline aura logic intuition wisdom influence].freeze
      STAT_ABBREV = {
        'STR' => :strength, 'CON' => :constitution, 'DEX' => :dexterity,
        'AGI' => :agility, 'DIS' => :discipline, 'AUR' => :aura,
        'LOG' => :logic, 'INT' => :intuition, 'WIS' => :wisdom,
        'INF' => :influence
      }.freeze
      STAT_CAP = 40

      # Skills that appear as "Bonus" in output (same as Skills module list)
      BONUS_SKILLS = %i[
        two_weapon_combat armor_use shield_use combat_maneuvers edged_weapons
        blunt_weapons two_handed_weapons ranged_weapons thrown_weapons polearm_weapons
        brawling ambush multi_opponent_combat physical_fitness dodging arcane_symbols
        magic_item_use spell_aiming harness_power elemental_mana_control mental_mana_control
        spirit_mana_control elemental_lore_air elemental_lore_earth elemental_lore_fire
        elemental_lore_water spiritual_lore_blessings spiritual_lore_religion
        spiritual_lore_summoning sorcerous_lore_demonology sorcerous_lore_necromancy
        mental_lore_divination mental_lore_manipulation mental_lore_telepathy
        mental_lore_transference mental_lore_transformation survival disarming_traps
        picking_locks stalking_and_hiding perception climbing swimming first_aid
        trading pickpocketing
      ].freeze
      SKILL_CAP = 50

      # Resources
      RESOURCES = %i[max_mana max_health max_stamina mana_recovery stamina_recovery].freeze
      RESOURCE_CAPS = {
        max_mana: 600, max_health: 300, max_stamina: 300,
        mana_recovery: 50, stamina_recovery: 50
      }.freeze

      # Mapping from game output names to internal names
      SKILL_NAME_MAP = {
        'Two Weapon Combat'            => :two_weapon_combat,
        'Armor Use'                    => :armor_use,
        'Shield Use'                   => :shield_use,
        'Combat Maneuvers'             => :combat_maneuvers,
        'Edged Weapons'                => :edged_weapons,
        'Blunt Weapons'                => :blunt_weapons,
        'Two-Handed Weapons'           => :two_handed_weapons,
        'Ranged Weapons'               => :ranged_weapons,
        'Thrown Weapons'               => :thrown_weapons,
        'Polearm Weapons'              => :polearm_weapons,
        'Brawling'                     => :brawling,
        'Ambush'                       => :ambush,
        'Multi Opponent Combat'        => :multi_opponent_combat,
        'Physical Fitness'             => :physical_fitness,
        'Dodging'                      => :dodging,
        'Arcane Symbols'               => :arcane_symbols,
        'Magic Item Use'               => :magic_item_use,
        'Spell Aiming'                 => :spell_aiming,
        'Harness Power'                => :harness_power,
        'Elemental Mana Control'       => :elemental_mana_control,
        'Mental Mana Control'          => :mental_mana_control,
        'Spirit Mana Control'          => :spirit_mana_control,
        'Elemental Lore - Air'         => :elemental_lore_air,
        'Elemental Lore - Earth'       => :elemental_lore_earth,
        'Elemental Lore - Fire'        => :elemental_lore_fire,
        'Elemental Lore - Water'       => :elemental_lore_water,
        'Spiritual Lore - Blessings'   => :spiritual_lore_blessings,
        'Spiritual Lore - Religion'    => :spiritual_lore_religion,
        'Spiritual Lore - Summoning'   => :spiritual_lore_summoning,
        'Sorcerous Lore - Demonology'  => :sorcerous_lore_demonology,
        'Sorcerous Lore - Necromancy'  => :sorcerous_lore_necromancy,
        'Mental Lore - Divination'     => :mental_lore_divination,
        'Mental Lore - Manipulation'   => :mental_lore_manipulation,
        'Mental Lore - Telepathy'      => :mental_lore_telepathy,
        'Mental Lore - Transference'   => :mental_lore_transference,
        'Mental Lore - Transformation' => :mental_lore_transformation,
        'Survival'                     => :survival,
        'Disarming Traps'              => :disarming_traps,
        'Picking Locks'                => :picking_locks,
        'Stalking and Hiding'          => :stalking_and_hiding,
        'Perception'                   => :perception,
        'Climbing'                     => :climbing,
        'Swimming'                     => :swimming,
        'First Aid'                    => :first_aid,
        'Trading'                      => :trading,
        'Pickpocketing'                => :pickpocketing
      }.freeze

      RESOURCE_NAME_MAP = {
        'Max Mana'         => :max_mana,
        'Max Health'       => :max_health,
        'Max Stamina'      => :max_stamina,
        'Mana Recovery'    => :mana_recovery,
        'Stamina Recovery' => :stamina_recovery
      }.freeze

      # Martial Knowledge Skills (CMan-based enhancives)
      # These appear as "+X ranks" in the output rather than bonus format
      # Derived dynamically from CMan module at runtime to stay DRY
      MARTIAL_SKILL_CAP = 5 # Most martial skills cap at 5 ranks

      # Special display name mappings for CMan skills with apostrophes
      # These can't be auto-generated from the symbol name
      MARTIAL_SPECIAL_NAMES = {
        :acrobats_leap       => "Acrobat's Leap",
        :executioners_stance => "Executioner's Stance",
        :griffins_voice      => "Griffin's Voice",
        :predators_eye       => "Predator's Eye"
      }.freeze

      # Convert symbol to display name (e.g., :combat_focus => "Combat Focus")
      def self.martial_symbol_to_display(symbol)
        return MARTIAL_SPECIAL_NAMES[symbol] if MARTIAL_SPECIAL_NAMES.key?(symbol)

        symbol.to_s.split('_').map(&:capitalize).join(' ')
      end

      # Convert display name to symbol (e.g., "Combat Focus" => :combat_focus)
      def self.martial_display_to_symbol(display_name)
        # Check special names first (reverse lookup)
        special = MARTIAL_SPECIAL_NAMES.key(display_name)
        return special if special

        # Standard conversion: lowercase, replace spaces with underscores
        display_name.downcase.gsub(' ', '_').to_sym
      end

      # Get list of all martial skill symbols from CMan module
      # Returns empty array if CMan not yet loaded
      def self.martial_skills_list
        return [] unless defined?(Lich::Gemstone::CMan)

        Lich::Gemstone::CMan.cman_lookups.map { |cman| cman[:long_name].to_sym }
      end

      # === STAT ACCESSORS ===
      # Returns OpenStruct with :value and :cap
      STATS.each do |stat|
        define_singleton_method(stat) do
          OpenStruct.new(
            value: Infomon.get("enhancive.stat.#{stat}").to_i,
            cap: STAT_CAP
          )
        end
      end

      # Shorthand aliases (str, con, dex, etc.)
      %i[str con dex agi dis aur log int wis inf].each do |shorthand|
        long_hand = STATS.find { |s| s.to_s.start_with?(shorthand.to_s) }
        define_singleton_method(shorthand) do
          send(long_hand).value
        end
      end

      # === SKILL ACCESSORS ===
      # Skills return OpenStruct with :ranks, :bonus, :value (combined), and :cap
      BONUS_SKILLS.each do |skill|
        define_singleton_method(skill) do
          ranks = Infomon.get("enhancive.skill.#{skill}.ranks").to_i
          bonus = Infomon.get("enhancive.skill.#{skill}.bonus").to_i
          OpenStruct.new(
            ranks: ranks,
            bonus: bonus,
            value: ranks + bonus,
            cap: SKILL_CAP
          )
        end
      end

      # Shorthand aliases matching Skills module
      {
        twoweaponcombat: :two_weapon_combat,
        armoruse: :armor_use,
        shielduse: :shield_use,
        combatmaneuvers: :combat_maneuvers,
        edgedweapons: :edged_weapons,
        bluntweapons: :blunt_weapons,
        twohandedweapons: :two_handed_weapons,
        rangedweapons: :ranged_weapons,
        thrownweapons: :thrown_weapons,
        polearmweapons: :polearm_weapons,
        multiopponentcombat: :multi_opponent_combat,
        physicalfitness: :physical_fitness,
        arcanesymbols: :arcane_symbols,
        magicitemuse: :magic_item_use,
        spellaiming: :spell_aiming,
        harnesspower: :harness_power,
        disarmingtraps: :disarming_traps,
        pickinglocks: :picking_locks,
        stalkingandhiding: :stalking_and_hiding,
        firstaid: :first_aid,
        emc: :elemental_mana_control,
        mmc: :mental_mana_control,
        smc: :spirit_mana_control,
        elair: :elemental_lore_air,
        elearth: :elemental_lore_earth,
        elfire: :elemental_lore_fire,
        elwater: :elemental_lore_water,
        slblessings: :spiritual_lore_blessings,
        slreligion: :spiritual_lore_religion,
        slsummoning: :spiritual_lore_summoning,
        sldemonology: :sorcerous_lore_demonology,
        slnecromancy: :sorcerous_lore_necromancy,
        mldivination: :mental_lore_divination,
        mlmanipulation: :mental_lore_manipulation,
        mltelepathy: :mental_lore_telepathy,
        mltransference: :mental_lore_transference,
        mltransformation: :mental_lore_transformation
      }.each do |shorthand, long_hand|
        define_singleton_method(shorthand) do
          send(long_hand)
        end
      end

      # === RESOURCE ACCESSORS ===
      RESOURCES.each do |resource|
        define_singleton_method(resource) do
          OpenStruct.new(
            value: Infomon.get("enhancive.resource.#{resource}").to_i,
            cap: RESOURCE_CAPS[resource]
          )
        end
      end

      # === MARTIAL KNOWLEDGE SKILL ACCESSORS ===
      # Dynamic accessor for any martial skill by symbol
      # Returns OpenStruct with :ranks and :cap
      def self.martial_skill(skill_symbol)
        OpenStruct.new(
          ranks: Infomon.get("enhancive.martial.#{skill_symbol}").to_i,
          cap: MARTIAL_SKILL_CAP
        )
      end

      # Get all martial skills with non-zero values
      # Scans all CMan skills from the CMan module
      def self.martial_skills
        martial_skills_list.select { |s| martial_skill(s).ranks > 0 }
                           .map { |s| { name: s, ranks: martial_skill(s).ranks } }
      end

      # Convenience aliases
      def self.mana
        max_mana
      end

      def self.health
        max_health
      end

      def self.stamina
        max_stamina
      end

      # === SPELL ACCESSORS ===
      # Returns array of spell numbers that enhancives grant self-knowledge of
      def self.spells
        raw = Infomon.get("enhancive.spells")
        return [] if raw.nil? || raw.empty?

        raw.to_s.split(',').map(&:to_i)
      end

      # Check if enhancives grant knowledge of a specific spell
      def self.knows_spell?(spell_num)
        spells.include?(spell_num.to_i)
      end

      # === STATISTICS ACCESSORS ===
      def self.item_count
        Infomon.get("enhancive.stats.item_count").to_i
      end

      def self.property_count
        Infomon.get("enhancive.stats.property_count").to_i
      end

      def self.total_amount
        Infomon.get("enhancive.stats.total_amount").to_i
      end

      # === ACTIVE STATE ===
      # Whether enhancives are currently active (toggled on)
      def self.active?
        Infomon.get("enhancive.active") == true
      end

      # Returns Time when active state was last updated, or nil if never
      def self.active_last_updated
        timestamp = Infomon.get_updated_at("enhancive.active")
        timestamp ? Time.at(timestamp) : nil
      end

      # Number of enhancive pauses available
      def self.pauses
        Infomon.get("enhancive.pauses").to_i
      end

      # === LAST UPDATED ===
      # Returns Time when enhancive data was last refreshed, or nil if never
      def self.last_updated
        timestamp = Infomon.get_updated_at("enhancive.stats.item_count")
        timestamp ? Time.at(timestamp) : nil
      end

      # === UTILITY METHODS ===
      # Check if a stat is over cap
      def self.stat_over_cap?(stat)
        send(stat).value > STAT_CAP
      end

      # Check if a skill is over cap
      def self.skill_over_cap?(skill)
        s = send(skill)
        s.bonus > SKILL_CAP
      end

      # Get all over-cap stats
      def self.over_cap_stats
        STATS.select { |s| stat_over_cap?(s) }
      end

      # Get all over-cap skills
      def self.over_cap_skills
        BONUS_SKILLS.select { |s| skill_over_cap?(s) rescue false }
      end

      # Trigger refresh of enhancive data (status + full totals)
      # Blocks until complete, output is hidden from user
      def self.refresh
        respond "Refreshing enhancive data..."
        # First get status (active state + pauses)
        Lich::Util.issue_command(
          "invento enh",
          /^You are (?:currently|not currently|now|already|no longer)/,
          /<prompt/,
          include_end: true, timeout: 5, silent: false, usexml: true, quiet: true
        )
        # Then get full totals
        # TODO: Update start pattern once GM adds proper start message to invento enhancive totals
        # Current pattern is fragile - if player has no stat enhancives, output starts with Skills/Resources
        Lich::Util.issue_command(
          "invento enhancive totals",
          /^<pushBold\/>(?:Stats:|Skills:|Resources:)|^No enhancive item bonuses found\./,
          /<prompt/,
          include_end: true, timeout: 5, silent: false, usexml: true, quiet: true
        )
        respond "Enhancive data refreshed."
      end

      # Trigger refresh of active state and pauses only (lightweight)
      # Blocks until complete, output is hidden from user
      def self.refresh_status
        Lich::Util.issue_command(
          "invento enh",
          /^You are (?:currently|not currently|now|already|no longer)/,
          /<prompt/,
          include_end: true, timeout: 5, silent: false, usexml: true, quiet: true
        )
      end

      # === RESET METHOD (called by parser before populating new data) ===
      # Resets all enhancive values to 0/empty
      # Critical because game output only shows non-zero values
      def self.reset_all
        batch = []

        # Reset all stats to 0
        STATS.each do |stat|
          batch.push(["enhancive.stat.#{stat}", 0])
        end

        # Reset all skills to 0
        BONUS_SKILLS.each do |skill|
          batch.push(["enhancive.skill.#{skill}.ranks", 0])
          batch.push(["enhancive.skill.#{skill}.bonus", 0])
        end

        # Reset all resources to 0
        RESOURCES.each do |resource|
          batch.push(["enhancive.resource.#{resource}", 0])
        end

        # Reset all martial knowledge skills to 0
        # Uses CMan module to get full list of possible martial skills
        martial_skills_list.each do |skill|
          batch.push(["enhancive.martial.#{skill}", 0])
        end

        # Reset spells to empty array
        batch.push(["enhancive.spells", ""])

        # Reset statistics to 0
        batch.push(["enhancive.stats.item_count", 0])
        batch.push(["enhancive.stats.property_count", 0])
        batch.push(["enhancive.stats.total_amount", 0])

        Infomon.upsert_batch(batch)
      end
    end
  end
end
