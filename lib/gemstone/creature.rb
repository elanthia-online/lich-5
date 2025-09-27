require 'singleton'
require 'ostruct'
module Lich
  module Gemstone
    class Creature
      module Template
        BOON_ADJECTIVES = %w[
          adroit afflicted apt barbed belligerent blurry canny combative dazzling deft diseased drab
          dreary ethereal flashy flexile flickering flinty frenzied ghastly ghostly gleaming glittering
          glorious glowing grotesque hardy illustrious indistinct keen lanky luminous lustrous muculent
          nebulous oozing pestilent radiant raging ready resolute robust rune-covered shadowy shifting
          shimmering shining sickly green sinous slimy sparkling spindly spiny stalwart steadfast stout
          tattoed tenebrous tough twinkling unflinching unyielding wavering wispy
        ]

        @template_cache ||= {}
        @missing_templates ||= Set.new

        def self.fix_template_name(template_name)
          name = template_name.dup.downcase
          BOON_ADJECTIVES.each { |adj| name.sub!(/^#{Regexp.escape(adj)}\s+/i, '') }
          name.strip.gsub(/\s+/, '_')
        end

        def self.load(template_name)
          key = fix_template_name(template_name)

          return nil if @missing_templates.include?(key)
          return @template_cache[key] if @template_cache.key?(key)

          base_dir = File.join(File.dirname(__FILE__), 'creatures')
          paths = [
            File.join(base_dir, "#{key}.rb"),
            File.join(base_dir, "#{template_name.strip.downcase.gsub(/\s+/, '_')}.rb")
          ]

          path = paths.find { |p| File.exist?(p) }

          unless path
            puts "--- error: Template file not found for: #{template_name}"
            @missing_templates << key
            return nil
          end

          @template_cache[key] = eval(File.read(path))
        rescue => e
          puts "--- error loading template #{template_name}: #{e.message}"
          @missing_templates << key
          nil
        end
      end

      class SpecialAbility
        attr_accessor :name, :note

        def initialize(data)
          @name = data[:name]
          @note = data[:note]
        end
      end

      class Treasure
        def initialize(data = {})
          @data = {
            coins: false,
            gems: false,
            boxes: false,
            skin: nil,
            magic_items: nil,
            other: nil,
            blunt_required: false
          }.merge(data)
        end

        def has_coins? = !!@data[:coins]
        def has_gems? = !!@data[:gems]
        def has_boxes? = !!@data[:boxes]
        def has_skin? = !!@data[:skin]
        def blunt_required? = !!@data[:blunt_required]

        def to_h = @data
      end

      class Messaging
        attr_accessor :description, :arrival, :flee, :death,
                      :spell_prep, :frenzy, :sympathy, :bite,
                      :claw, :attack, :enrage, :mstrike

        PLACEHOLDER_MAP = {
          Pronoun: %w[He Her His It She],
          pronoun: %w[he her his it she],
          direction: %w[north south east west up down northeast northwest southeast southwest],
          weapon: %w[RAW:.+?]
        }

        def initialize(data)
          data.each do |key, value|
            instance_variable_set("@#{key}", normalize(value))
          end
        end

        def normalize(value)
          if value.is_a?(Array)
            value.map { |v| normalize(v) }
          elsif value.is_a?(String) && value.match?(/\{[a-zA-Z_]+\}/)
            phs = value.scan(/\{([a-zA-Z_]+)\}/).flatten.map(&:to_sym)
            placeholders = phs.map { |ph| [ph, PLACEHOLDER_MAP[ph] || []] }.to_h
            PlaceholderTemplate.new(value, placeholders)
          else
            value
          end
        end

        def display(field, subs = {})
          msg = send(field)
          if msg.is_a?(Array)
            msg.map { |m| m.is_a?(PlaceholderTemplate) ? m.to_display(subs) : m }.join("\n")
          elsif msg.is_a?(PlaceholderTemplate)
            msg.to_display(subs)
          else
            msg
          end
        end

        def match(field, str)
          msg = send(field)
          if msg.is_a?(PlaceholderTemplate)
            msg.match(str)
          else
            msg == str ? {} : nil
          end
        end
      end

      class DefenseAttributes
        attr_accessor :asg, :melee, :ranged, :bolt, :udf,
                      :bar_td, :cle_td, :emp_td, :pal_td,
                      :ran_td, :sor_td, :wiz_td, :mje_td, :mne_td,
                      :mjs_td, :mns_td, :mnm_td, :immunities,
                      :defensive_spells, :defensive_abilities, :special_defenses

        def initialize(data)
          @asg = data[:asg]
          @melee = parse_td(data[:melee])
          @ranged = parse_td(data[:ranged])
          @bolt = parse_td(data[:bolt])
          @udf = parse_td(data[:udf])

          %i[bar_td cle_td emp_td pal_td ran_td sor_td wiz_td mje_td mne_td mjs_td mns_td mnm_td].each do |key|
            instance_variable_set("@#{key}", parse_td(data[key]))
          end

          @immunities = data[:immunities] || []
          @defensive_spells = data[:defensive_spells] || []
          @defensive_abilities = data[:defensive_abilities] || []
          @special_defenses = data[:special_defenses] || []
        end

        private

        def parse_td(val)
          return nil if val.nil?
          return val if val.is_a?(Range)
          return eval(val) if val.is_a?(String) && val.match?(/\A\d+\.\.\d+\z/)
          val
        end
      end

      class PlaceholderTemplate
        # Initialize with a template string and a placeholder map.
        # Example:
        #   template = "A stunted halfling bloodspeaker utters ... around {pronoun} gnarled hands."
        #   placeholders = { pronoun: %w[her his their] }
        def initialize(template, placeholders = {})
          @template = template
          @placeholders = placeholders
        end

        # Returns the raw template string
        def template
          @template
        end

        # Returns the placeholder map (symbol keys, array of options)
        def placeholders
          @placeholders
        end

        # Substitute placeholders for display (e.g., pick user’s preference)
        # Example: to_display(pronoun: "her")
        def to_display(subs = {})
          line = @template.dup
          @placeholders.each do |key, options|
            value = subs[key] || options.sample || ""
            line.gsub!("{#{key}}", value.to_s)
          end
          line
        end

        # Compile a regex for matching
        # Optionally pass a restricted set for each placeholder (default is all options)
        def to_regex(literals = {})
          if @template.is_a?(Array)
            regexes = @template.map { |t| self.class.new(t, @placeholders).to_regex(literals) }
            Regexp.union(*regexes)
          else
            pattern = Regexp.escape(@template)
            @placeholders.each do |key, options|
              if options == [:wildcard] || options.first&.start_with?('RAW:')
                # Insert as raw regex, NOT escaped!
                raw = options.first.start_with?('RAW:') ? options.first[4..-1] : options.first
                pattern.gsub!(/\\\{#{key}\\\}/, raw)
              else
                # Use named capture group!
                regex_group = "(?<#{key}>#{(literals[key] || options).map { |opt| Regexp.escape(opt) }.join('|')})"
                pattern.gsub!(/\\\{#{key}\\\}/, regex_group)
              end
            end
            Regexp.new("#{pattern}")
          end
        end

        # Match a given string against this template’s regex
        # Returns the matched groups as a hash if match, or nil
        def match(str, literals = {})
          regex = to_regex(literals)
          m = regex.match(str)
          return nil unless m
          m.names.any? ? m.named_captures.transform_keys(&:to_sym) : m.captures
        end
      end

      class Registry
        include Singleton

        def initialize
          @creatures_by_id = {}
          @creatures_by_name = {}
        end

        # Resets the registry data, clearing all creatures.
        #
        # @example
        #   Registry.instance.reset_data
        def reset_data
          @creatures_by_id.clear
          @creatures_by_name.clear
        end

        def add(creature)
          @creatures_by_id[creature.id.to_i] ||= creature if creature.id
          @creatures_by_name[creature.name.downcase] ||= creature if creature.name
        end

        # Retrieves all creatures in the registry.
        #
        # @return [Array<Creature>] An array of all registered creatures.
        # @example
        #   all_creatures = registry.instance.all_creatures
        def all_creatures
          @creatures_by_name.values
        end

        # Finds a creature by its ID.
        #
        # @param id [Integer] The ID of the creature to find.
        # @return [Creature, nil] The found creature instance or nil if not found.
        # @example
        #   creature = registry.instance.find_by_id(53262363)
        def find_by_id(id)
          @creatures_by_id[id.to_i]
        end

        def find_by_name(name)
          @creatures_by_name[name.downcase]
        end

        # Imports all creatures into the registry.
        #
        # @example
        #   registry.instance.import_all
        def import_all
          Creature.all.each { |c| add(c) if c }
        end
      end

      attr_accessor :name, :url, :picture, :level, :family, :type,
                    :undead, :otherclass, :areas, :bcs, :hitpoints,
                    :speed, :height, :size, :attack_attributes, :status,
                    :defense_attributes, :treasure, :messaging, :injuries,
                    :special_other, :abilities, :alchemy, :id, :update_log

      BODY_PARTS = %w[abdomen back chest head leftArm leftEye leftFoot leftHand leftLeg neck nerves rightArm rightEye rightFoot rightHand rightLeg]

      def initialize(data, id: nil)
        @name = data[:name]
        @url = data[:url]
        @picture = data[:picture]
        @level = data[:level].to_i
        @family = data[:family]
        @type = data[:type]
        @undead = data[:undead]
        @otherclass = data[:otherclass] || []
        @areas = data[:areas] || []
        @bcs = data[:bcs]
        @hitpoints = data[:hitpoints].to_i
        @speed = data[:speed]
        @height = data[:height].to_i
        @size = data[:size]
        @id = id.to_i if id
        @update_log = []
        @status = []
        @injuries = Hash.new(0)

        atk = data[:attack_attributes] || {}
        @attack_attributes = OpenStruct.new(
          physical_attacks: atk[:physical_attacks] || [],
          bolt_spells: atk[:bolt_spells] || [],
          warding_spells: normalize_spells(atk[:warding_spells]),
          offensive_spells: normalize_spells(atk[:offensive_spells]),
          maneuvers: atk[:maneuvers] || [],
          special_abilities: (atk[:special_abilities] || []).map { |s| SpecialAbility.new(s) }
        )

        @defense_attributes = DefenseAttributes.new(data[:defense_attributes] || {})
        @treasure = Treasure.new(data[:treasure])
        @messaging = Messaging.new(data[:messaging] || {})
        @special_other = data[:special_other]
        @abilities = data[:abilities] || []
        @alchemy = data[:alchemy] || []
      end

      def self.create(creature_name, creature_id)
        data = Template.load(creature_name)
        return nil unless data
        data[:name] = creature_name
        new(data, id: creature_id)
      end

      # Registers a creature by adding it to the registry.
      #
      # @param name [String] The name of the creature.
      # @param id [Integer] The ID of the creature.
      # @return [Creature] The registered creature instance.
      # @example
      #   creature = Creature.register_creature("Kobold", 35623463)
      def self.register_creature(name, id)
        creature = create(name, id)
        Registry.instance.add(creature) if creature
        creature
      end

      # Retrieves all creatures from the filesystem.
      #
      # @return [Array<Creature>] An array of all creature instances.
      # @example
      #   creatures = Creature.all
      def self.all
        Dir[File.join(File.dirname(__FILE__), 'creatures', '*.rb')].map do |path|
          name = File.basename(path, '.rb').tr('_', ' ')
          create(name, nil)
        end
      end

      def self.find_by_name(name)
        create(name, nil)
      rescue
        nil
      end

      def to_h
        instance_variables.each_with_object({}) do |var, hash|
          hash[var.to_s.delete('@').to_sym] = instance_variable_get(var)
        end
      end

      # Updates a specific field of the creature.
      #
      # @param key [Symbol] The attribute to update.
      # @param value [Object] The new value for the attribute.
      # @raise [RuntimeError] If there is no setter for the given key.
      # @example
      #   creature.update_field(:level, 5)
      def update_field(key, value)
        if respond_to?(key)
          current = send(key)
          current.is_a?(Array) ? current << value : send("#{key}=", value)
        elsif respond_to?("#{key}=")
          send("#{key}=", value)
        else
          raise "No setter for #{key}"
        end
        log_update({ key => value })
      end

      # Adds a status to the creature.
      #
      # @param status [String] The status to add.
      # @example
      #   creature.add_status("poisoned")
      def add_status(status)
        @status << status unless @status.include?(status)
        log_update({ status: "added #{status}" })
      end

      # Removes a status from the creature.
      #
      # @param status [String] The status to remove.
      # @example
      #   creature.remove_status("poisoned")
      def remove_status(status)
        if @status.delete(status)
          log_update({ status: "removed #{status}" })
        else
          log_update({ status: "status #{status} not found for removal" })
        end
      end

      # Appends an injury to a specific body part.
      #
      # @param body_part [String] The body part to append the injury to.
      # @param delta [Integer] The amount of injury to append.
      # @raise [ArgumentError] If the body part is invalid.
      # @example
      #   creature.append_injury("leftArm", 5)
      #   creature.append_injury(:leftArm, 5)
      def append_injury(body_part, delta)
        unless BODY_PARTS.include?(body_part.to_s)
          raise ArgumentError, "Invalid body part in append_injury: #{body_part}."
        end
        @injuries[body_part.to_sym] += delta # should this be + or += ?
        log_update({ injuries: { body_part => delta } })
      end

      # Checks if the creature is injured at a specific location.
      #
      # @param location [String] The body part to check for injury.
      # @param threshold [Integer] The injury threshold to check against.
      # @return [Boolean] True if injured, false otherwise.
      # @example
      #   is_injured = creature.injured?("leftArm", 1)
      def injured?(location, threshold = 1)
        @injuries[location.to_sym] >= threshold
      end

      # Retrieves all injured locations above a certain threshold.
      #
      # @param threshold [Integer] The injury threshold to check against.
      # @return [Array<Symbol>] An array of injured body parts.
      # @example
      #   injured_parts = creature.injured_locations(2)
      def injured_locations(threshold = 1)
        @injuries.select { |_, value| value >= threshold }.keys
      end

      def current_data
        to_h.reject { |k, _| k == :update_log }
      end

      def log_update(new_data)
        @update_log << { time: Time.now.to_i, data: new_data }
      end

      def [](key)
        current_data[key]
      end

      def []=(key, value)
        update_field(key, value)
      end

      # Retrieves a creature by its ID or name.
      #
      # @param creature_id_or_name [Integer, String] The ID or name of the creature.
      # @return [Creature, nil] The found creature instance or nil if not found.
      # @example
      #   creature = Creature[5323466] # by ID
      #   creature = Creature["immense gold-bristled hinterboar"] # by name
      def self.[](creature_id_or_name)
        if creature_id_or_name.is_a?(Integer)
          Registry.instance.find_by_id(creature_id_or_name)
        else
          Registry.instance.find_by_name(creature_id_or_name)
        end
      end

      private

      def normalize_spells(spells)
        (spells || []).map do |s|
          {
            name: s[:name].to_s.strip,
            cs: parse_td(s[:cs])
          }
        end
      end

      def parse_td(val)
        return nil if val.nil?
        return val if val.is_a?(Range)
        return eval(val) if val.is_a?(String) && val.match?(/\\A\\d+\\.\\.\\d+\\z/)
        val
      end
    end
  end
end

# Lich::Gemstone::Creature
#
# Gemstone IV Bestiary Creature Data System
#
# This module provides a flexible, extensible framework for managing creature definitions, behaviors,
# and messaging for Lich scripting in Gemstone IV. It supports structured creature data,
# advanced templating for combat/emote messages (with regex-ready placeholders and randomization),
# and a singleton-backed registry for efficient lookup.
#
# Features:
# ----------
# - Creature templates loaded from external files (with boon adjective normalization).
# - Central registry for creatures (lookup by name or instance ID).
# - Fully structured data: levels, stats, messaging, special abilities, loot, etc.
# - Advanced placeholder templating for creature messages—supporting named capture regex and randomization.
# - Robust methods for both display and pattern-matching of creature-generated text.
#
# Core Classes:
# -------------
# - Lich::Gemstone::Creature::Template
#     Loads and caches creature templates (see `/creatures/*.rb`).
#
# - Lich::Gemstone::Creature::Registry
#     Singleton registry for creature lookup by name and instance ID.
#
# - Lich::Gemstone::Creature
#     The main data structure for each creature.
#
# - Lich::Gemstone::Creature::Messaging
#     Manages all creature-related messages (arrival, flee, spell_prep, etc), with support for
#     placeholder substitution, array-of-lines randomization, and regex pattern building.
#
# - Lich::Gemstone::Creature::PlaceholderTemplate
#     A utility for representing templated lines with placeholders (e.g., "{pronoun}", "{direction}"),
#     supporting `.to_display` for text substitution and `.to_regex` for pattern-matching.
#
#
# Quick Usage:
# -------------
# Register or look up a creature:
#   creature = Lich::Gemstone::Creature.register_creature("Kobold", 12345)
#   creature = Lich::Gemstone::Creature[12345]              # by ID
#   creature = Lich::Gemstone::Creature["immense gold-bristled hinterboar"] # by name
#
# Access data:
#   puts creature.level
#   puts creature.treasure.has_gems?
#   puts creature.defense_attributes.asg
#
# Access and display templated messages:
#   msg = creature.messaging.flee
#   puts msg.to_display(direction: "north")          # Fill placeholders, or auto-random if not given
#
# Get a matching regex for a message:
#   regex = creature.messaging.flee.to_regex
#   if (match = regex.match("The panther flees north."))
#     puts match[:direction]                         # => "north"
#   end
#
# If the message is an array, .to_display samples all and joins with line breaks; .to_regex unions all patterns.
#
#
# Adding New Creatures:
# ---------------------
# - Place a new template Ruby file in `/creatures/`, named like "kobold.rb" (lowercase, underscores, boon adjectives stripped).
# - The file must return a Hash in the expected format (see other templates for examples).
#
# Placeholders for templating:
# ----------------------------
# - Placeholders in curly braces (e.g., "{pronoun}", "{direction}", "{weapon}") are automatically detected and substituted.
# - To use a raw regex for a placeholder (e.g., any weapon name), set its options to ["RAW:.+?"] in PLACEHOLDER_MAP.
#
# Example Placeholder Map:
#   PLACEHOLDER_MAP = {
#     pronoun: %w[he her his it she],
#     direction: %w[north south east west ...],
#     weapon: %w[RAW:.+?]
#   }
#
# Special Notes:
# --------------
# - Named capture groups are used in generated regex for easy extraction of placeholder values.
# - If the same placeholder appears multiple times in a string, only the last is available as a named group.
# - The system supports arrays of message lines (for randomization and flexible matching).
# - All registry, lookup, and normalization is case-insensitive.
#
# See code for further details or extension points.
