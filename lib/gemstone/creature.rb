# frozen_string_literal: true

require 'singleton'
require 'ostruct'
require_relative '../common/creature/creature_base'

module Lich
  module Gemstone
    # Static creature template data (ID-less reference information)
    class CreatureTemplate
      @@templates = {}
      @@loaded = false

      attr_reader :name, :url, :picture, :level, :family, :type,
                  :undead, :otherclass, :areas, :bcs, :max_hp,
                  :speed, :height, :size, :attack_attributes,
                  :defense_attributes, :treasure, :messaging,
                  :special_other, :abilities, :alchemy

      BOON_ADJECTIVES = %w[
        adroit afflicted apt barbed belligerent blurry canny combative dazzling deft diseased drab
        dreary ethereal flashy flexile flickering flinty frenzied ghastly ghostly gleaming glittering
        glorious glowing grotesque hardy illustrious indistinct keen lanky luminous lustrous muculent
        nebulous oozing pestilent radiant raging ready resolute robust rune-covered shadowy shifting
        shimmering shining sickly green sinuous slimy sparkling spindly spiny stalwart steadfast stout
        tattoed tenebrous tough twinkling unflinching unyielding wavering wispy
      ]

      def initialize(data)
        @name = data[:name]
        @url = data[:url]
        @picture = data[:picture]
        @level = data[:level]&.to_i
        @family = data[:family]
        @type = data[:type]
        @undead = data[:undead]
        # Tri-state (true/false/nil) - nil means uncatalogued/unknown, not false.
        @has_blood = data[:has_blood]
        @has_bones = data[:has_bones]
        @muggable = data[:muggable]
        @otherclass = data[:otherclass] || []
        @areas = data[:areas] || []
        @bcs = data[:bcs]
        @max_hp = data[:max_hp]&.to_i || data[:hitpoints]&.to_i
        @speed = data[:speed]
        @height = data[:height].to_i
        @size = data[:size]

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
        @treasure = Treasure.new(data[:treasure] || {})
        @messaging = Messaging.new(data[:messaging] || {})
        @special_other = data[:special_other]
        @abilities = data[:abilities] || []
        @alchemy = data[:alchemy] || []
      end

      # Load all templates from files
      # dir defaults to the real templates directory; overridable so tests
      # can load an isolated fixture directory instead.
      def self.load_all(dir = File.join(File.dirname(__FILE__), 'creatures'))
        return if @@loaded
        return unless File.directory?(dir)

        template_count = 0
        Dir[File.join(dir, '*.rb')].each do |path|
          next if File.basename(path) == '_creature_template.rb'

          # Filename-derived name, used only as a fallback for files that
          # don't set their own :name - the file's own value takes priority
          # so a name with characters the filename can't represent (a
          # hyphen, an apostrophe) still round-trips correctly. Both the
          # display name and the lookup key come from the same source now;
          # previously both were overwritten from the filename regardless of
          # what the file itself said, silently breaking lookup for any
          # creature whose real name a slugified filename can't represent
          # exactly (e.g. "shield-maiden" -> "shield_maiden" -> "shield maiden").
          fallback_name = File.basename(path, '.rb').tr('_', ' ')

          begin
            # Safer loading with validation
            file_content = File.read(path)
            data = load_template_data(file_content, path)
            next unless data.is_a?(Hash)

            data[:name] = fallback_name if data[:name].to_s.strip.empty?
            normalized_name = fix_template_name(data[:name])
            if @@templates.key?(normalized_name) && $creature_debug
              respond "--- warning: '#{fallback_name}' collides with an already-loaded template on lookup key '#{normalized_name}' - one will silently overwrite the other"
            end
            template = new(data)
            @@templates[normalized_name] = template
            template_count += 1
          rescue StandardError, ScriptError => e
            # ScriptError (SyntaxError's parent) isn't a StandardError, so a
            # single template file with malformed Ruby would otherwise abort
            # load_all entirely instead of just being skipped.
            respond "--- error loading template #{fallback_name}: #{e.message}" if $creature_debug
          end
        end

        @@loaded = true
        respond "--- loaded #{template_count} creature templates" if $creature_debug
      end

      # Clean creature name by removing boon adjectives
      # Optimized to use single compiled regex instead of 50+ sequential matches
      BOON_REGEX = /^(#{BOON_ADJECTIVES.join('|')})\s+/i.freeze

      def self.fix_template_name(template_name)
        name = template_name.dup.downcase
        name.sub!(BOON_REGEX, '')
        name.strip
      end

      # Safer template loading with validation
      def self.load_template_data(file_content, path)
        # Use binding.eval for slightly better isolation
        data = binding.eval(file_content, path, 1)

        # Validate it's a hash
        unless data.is_a?(Hash)
          raise "Template must return a Hash, got #{data.class}"
        end

        data
      end
      private_class_method :load_template_data

      # Lookup template by name
      def self.[](name)
        load_all unless @@loaded
        return nil unless name

        # Try exact match first
        template = @@templates[name.downcase]
        return template if template

        # Try with boon adjectives removed
        normalized_name = fix_template_name(name)
        @@templates[normalized_name]
      end

      # Get all loaded templates
      def self.all
        load_all unless @@loaded
        @@templates.values.uniq
      end

      # Returns whether the bestiary template says the creature has blood.
      #
      # @return [Boolean, nil] true or false when catalogued; nil when unknown.
      def has_blood?
        @has_blood
      end

      # Returns whether the bestiary template says the creature has bones.
      #
      # @return [Boolean, nil] true or false when catalogued; nil when unknown.
      def has_bones?
        @has_bones
      end

      # Returns whether the bestiary template says the creature can be mugged.
      #
      # @return [Boolean, nil] true or false when catalogued; nil when unknown.
      def muggable?
        @muggable
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

        # Parse range strings without eval (safer)
        if val.is_a?(String) && val.match?(/\A(\d+)\.\.(\d+)\z/)
          start_val, end_val = val.split('..').map(&:to_i)
          return start_val..end_val
        end

        val
      end
    end

    # Individual GemStone creature instance (runtime tracking with ID).
    #
    # Shares its id-keyed registry, room roster and `<crtrStatus>` status/flag
    # handling with DragonRealms via the {Lich::Common::CreatureBase} mixin; the
    # GemStone-specific layer here adds bestiary templates, UCS (Unarmed Combat
    # System) tracking, HP/injury modelling and the GemStone `valid_target?`
    # exclusions.
    class CreatureInstance
      include Lich::Common::CreatureBase

      attr_accessor :id, :noun, :name, :status, :injuries, :health, :damage_taken, :created_at, :fatal_crit, :status_timestamps,
                    :ucs_smote, :ucs_updated
      attr_writer :ucs_position, :ucs_tierup

      BODY_PARTS = %w[abdomen back chest head leftArm leftEye leftFoot leftHand leftLeg neck nerves rightArm rightEye rightFoot rightHand rightLeg]

      UCS_TTL = 120        # UCS data expires after 2 minutes
      UCS_SMITE_TTL = 15   # Smite effect expires after 15 seconds

      # Seconds per stun round. Critical tables express stun in *rounds*
      # (a rank-5 crit's `stunned: 5` means five rounds), while their
      # `roundtime` field is already in seconds - the two units live side by
      # side in the same CritRanks hash, so never mix them.
      STUN_ROUND_SECONDS = 5

      def initialize(id, noun, name)
        @id = id.to_i
        @noun = noun
        @name = name
        initialize_status_tracking
        @injuries = Hash.new(0)
        @health = nil
        @damage_taken = 0
        @created_at = Time.now
        @fatal_crit = false
        @ucs_position = nil
        @ucs_tierup = nil
        @ucs_smote = nil
        @ucs_updated = nil
        @amputated = []
        @stun_rounds = nil
        @stun_estimated_until = nil
      end

      # Get the template for this creature. Sentinel-cached so a creature with
      # no template doesn't redo the name lookup (downcase + boon regex) on
      # every call the way `||=` would.
      def template
        return @template if defined?(@template_looked_up)

        @template_looked_up = true
        @template = CreatureTemplate[@name]
      end

      # Check if creature has template data
      def has_template?
        !template.nil?
      end

      # UCS (Unarmed Combat System) tracking methods

      # Convert position string/number to tier (1-3)
      def position_to_tier(pos)
        case pos
        when "decent", 1, "1" then 1
        when "good", 2, "2" then 2
        when "excellent", 3, "3" then 3
        else nil
        end
      end

      # Set UCS position tier
      def set_ucs_position(position)
        new_tier = position_to_tier(position)
        return unless new_tier

        # Clear tierup if tier changed
        @ucs_tierup = nil if new_tier != @ucs_position

        @ucs_position = new_tier
        @ucs_updated = Time.now
        debug_log("UCS: position=#{new_tier}")
      end

      # Set UCS tierup vulnerability
      def set_ucs_tierup(attack_type)
        @ucs_tierup = attack_type
        @ucs_updated = Time.now
        debug_log("UCS: tierup=#{attack_type}")
      end

      # Mark creature as smote (crimson mist applied)
      def smite!
        @ucs_smote = Time.now
        @ucs_updated = Time.now
        debug_log("UCS: smote!")
      end

      # Check if creature is currently smote
      def smote?
        return false unless @ucs_smote

        # Check if smite effect has expired
        if Time.now - @ucs_smote > UCS_SMITE_TTL
          @ucs_smote = nil
          return false
        end

        true
      end

      # Clear smote status
      def clear_smote
        @ucs_smote = nil
        @ucs_updated = Time.now
        debug_log("UCS: smote cleared")
      end

      # Check if UCS data has expired
      def ucs_expired?
        return true unless @ucs_updated
        (Time.now - @ucs_updated) > UCS_TTL
      end

      # Get UCS position tier (1-3, or nil if expired)
      def ucs_position
        return nil if ucs_expired?
        @ucs_position
      end

      # Get UCS tierup vulnerability (or nil if expired)
      def ucs_tierup
        return nil if ucs_expired?
        @ucs_tierup
      end

      # Records a crit-table stun estimate, in rounds.
      #
      # This is deliberately *not* stored as a timed entry in @status. The
      # authoritative stun boolean is owned by <crtrStatus> and the combat
      # message parser (see STATUS_DURATIONS, where 'stunned' is nil on
      # purpose); expiring it on a table-derived timer would clear stun while
      # a resisted-or-stacked creature is still stunned, and report
      # `muckled?` false when acting is still unsafe. So the estimate lives
      # alongside the boolean and is advisory only.
      #
      # Stun does not cleanly stack, so a new estimate extends but never
      # shortens an existing one.
      #
      # @param rounds [Integer] stun rounds from the critical table.
      # @param at [Time] when the game applied the crit (prompt time, not
      #   parse time - the async parser can lag the server).
      # @return [void]
      def add_stun_estimate(rounds, at: Time.now)
        rounds = rounds.to_i
        return if rounds <= 0

        expires_at = at + (rounds * STUN_ROUND_SECONDS)
        return if @stun_estimated_until && @stun_estimated_until >= expires_at

        @stun_rounds = rounds
        @stun_estimated_until = expires_at
        debug_log("+stun estimate: #{rounds} round#{'s' unless rounds == 1} (~#{rounds * STUN_ROUND_SECONDS}s)")
      end

      # Estimated stun rounds from the last crit, or nil when the estimate has
      # lapsed or stun is no longer active.
      #
      # @return [Integer, nil]
      def stun_rounds
        return nil unless stun_estimate_active?
        @stun_rounds
      end

      # Estimated seconds of stun remaining.
      #
      # Advisory: derived from the critical table, not observed. Returns 0.0
      # when no estimate is active. Callers deciding whether it is safe to act
      # should gate on `muckled?`/`has_status?('stunned')` and use this only to
      # size the window.
      #
      # @return [Float]
      def stunned_for
        return 0.0 unless stun_estimate_active?
        [@stun_estimated_until - Time.now, 0.0].max.round(1)
      end

      # Clears any crit-derived stun estimate (creature shook off the stun).
      #
      # @return [void]
      def clear_stun_estimate
        @stun_rounds = nil
        @stun_estimated_until = nil
      end

      # Marks a body part as amputated.
      #
      # Distinct from @injuries, which accumulates rank: an amputated limb is
      # gone rather than wounded, cannot be wounded further, and stays gone.
      #
      # @param body_part [String, Symbol] one of BODY_PARTS.
      # @return [void]
      def amputate!(body_part)
        unless BODY_PARTS.include?(body_part.to_s)
          raise ArgumentError, "Invalid body part: #{body_part}"
        end
        return if @amputated.include?(body_part.to_s)

        @amputated << body_part.to_s
        debug_log("+amputated: #{body_part}")
      end

      # @return [Boolean] whether a body part has been amputated.
      def amputated?(body_part)
        @amputated.include?(body_part.to_s)
      end

      # @return [Array<String>] every amputated body part.
      def amputated_parts
        @amputated.dup
      end

      # Add injury to body part
      def add_injury(body_part, amount = 1)
        unless BODY_PARTS.include?(body_part.to_s)
          raise ArgumentError, "Invalid body part: #{body_part}"
        end
        # An amputated limb cannot accrue further wound rank - it is gone.
        return if amputated?(body_part)

        @injuries[body_part.to_sym] += amount
      end

      # Check if injured at location
      def injured?(location, threshold = 1)
        @injuries[location.to_sym] >= threshold
      end

      # Mark creature as killed by fatal critical hit
      def mark_fatal_crit!
        @fatal_crit = true
      end

      # Check if creature died from fatal crit
      def fatal_crit?
        @fatal_crit
      end

      # Get all injured locations
      def injured_locations(threshold = 1)
        @injuries.select { |_, value| value >= threshold }.keys
      end

      # Add damage to creature
      def add_damage(amount)
        @damage_taken += amount.to_i
      end

      # Get maximum HP from template, with fallback
      def max_hp
        # Try template first
        hp = template&.max_hp
        return hp if hp && hp > 0

        # Fall back to combat tracker setting if available
        begin
          if defined?(Lich::Gemstone::Combat::Tracker) &&
             Lich::Gemstone::Combat::Tracker.respond_to?(:fallback_hp)
            fallback = Lich::Gemstone::Combat::Tracker.fallback_hp
            return fallback if fallback && fallback > 0
          end
        rescue
          # Ignore errors accessing tracker
        end

        # Last resort: hardcoded fallback
        400
      end

      # Calculate current HP (max_hp - damage_taken)
      def current_hp
        return nil unless max_hp
        [max_hp - @damage_taken, 0].max
      end

      # Calculate HP percentage (0-100)
      def hp_percent
        return nil unless max_hp && max_hp > 0
        ((current_hp.to_f / max_hp) * 100).round(1)
      end

      # Check if creature is below HP threshold
      def low_hp?(threshold = 25)
        return false unless hp_percent
        hp_percent <= threshold
      end

      # Check if creature is dead (0 HP)
      def dead?
        current_hp == 0
      end

      # Checks whether this creature should be considered attackable.
      #
      # Uses the same decoy and appendage exclusions as `GameObj.targets`, but
      # uses structured death data from <crtrStatus> and HP tracking instead of
      # regex-matching a status string.
      #
      # @return [Boolean]
      def valid_target?
        return false if crtr_flag?(:dead) || dead?
        return false if @name =~ /^animated\b/i && @name !~ /^animated slush/i
        return false if @noun =~ /^(?:arm|appendage|claw|limb|pincer|tentacle)s?$|^(?:palpus|palpi)$/i &&
                        @name !~ /(?:amaranthine|ghostly|grizzled|ancient) kraken tentacle/i

        true
      end

      # Creature-side analog of Lich::Gemstone::Status.muckled? (the player's
      # own "can't act right now" check). Deliberately narrower than
      # everything tracked in @status: excludes penalty-only conditions
      # (disoriented), positional ones (prone/kneeling/sitting/flying/
      # hovering), and calm (the player version excludes that too, tracking
      # it separately) - this is only the statuses that actually prevent
      # acting, not ones that merely penalize or reposition.
      def muckled?
        has_status?('webbed') || crtr_flag?(:dead) || dead? || has_status?('stunned') ||
          has_status?('sleeping') || has_status?('immobilized') || has_status?('rooted')
      end

      # Reset damage (creature healed or respawned)
      def reset_damage
        @damage_taken = 0
      end

      # Essential data for this instance
      def essential_data
        {
          id: @id,
          noun: @noun,
          name: @name,
          status: @status,
          injuries: @injuries,
          health: @health,
          damage_taken: @damage_taken,
          max_hp: max_hp,
          current_hp: current_hp,
          hp_percent: hp_percent,
          has_template: has_template?,
          created_at: @created_at,
          ucs_position: ucs_position,
          ucs_tierup: ucs_tierup,
          ucs_smote: smote?,
          amputated: amputated_parts,
          stun_rounds: stun_rounds,
          stunned_for: stunned_for
        }
      end

      private

      # Whether a crit-derived stun estimate is still meaningful.
      #
      # Gated on the authoritative status as well as the clock: once the feed
      # or a removal message says the creature is no longer stunned, the
      # estimate is stale regardless of remaining time.
      def stun_estimate_active?
        return false unless @stun_estimated_until
        return false if @stun_estimated_until <= Time.now
        has_status?('stunned')
      end
    end

    # Public Creature API for GemStone runtime creature tracking.
    #
    # A thin facade: every call delegates to {CreatureInstance}, which mixes in
    # the shared id-keyed registry, room roster and `targets`/`in_room` query
    # methods from {Lich::Common::CreatureBase}.
    module Creature
      # Toggles live echo of status, flag, and registration changes.
      #
      # @param level [Boolean, Symbol] false disables debug output; true or
      #   `:changes` reports changes only; `:all` reports every <crtrStatus>
      #   flag; `:active` reports only active <crtrStatus> flags.
      # @return [Boolean, Symbol] the configured debug value.
      def self.debug_on(level = :changes)
        $creature_debug = level
      end

      # Lookup creature instance by ID
      def self.[](id)
        CreatureInstance[id]
      end

      # Returns attackable hostile creatures currently in the room.
      #
      # @param filters [Array<String, Symbol>] optional ANDed status/classification filters.
      # @return [Array<CreatureInstance>]
      def self.targets(*filters)
        CreatureInstance.targets(*filters)
      end

      # Returns all tracked creatures currently in the room.
      #
      # @param filters [Array<String, Symbol>] optional ANDed status/classification filters.
      # @return [Array<CreatureInstance>]
      def self.in_room(*filters)
        CreatureInstance.in_room(*filters)
      end

      # Empties the current room roster.
      #
      # @return [void]
      def self.clear_room
        CreatureInstance.clear_room
      end

      # Register a new creature
      def self.register(name, id, noun = nil)
        CreatureInstance.register(name, id, noun)
      end

      # Configure the system
      def self.configure(**options)
        CreatureInstance.configure(**options)
      end

      # Get registry stats
      def self.stats
        {
          instances: CreatureInstance.size,
          templates: CreatureTemplate.all.size,
          max_size: CreatureInstance.max_size,
          auto_register: CreatureInstance.auto_register?
        }
      end

      # Clear all instances
      def self.clear
        CreatureInstance.clear
      end

      # Removes creatures older than the given age (in seconds).
      #
      # Positional to match {CreatureInstance#cleanup_old} (supplied by
      # {Lich::Common::CreatureBase}) and the positional call in
      # Combat::Tracker#cleanup_creatures. A keyword-only signature here raised
      # ArgumentError on every scheduled tracker cleanup, which the tracker's
      # rescue then swallowed - so registry cleanup silently never ran.
      #
      # @param max_age_seconds [Integer] age cutoff in seconds.
      # @return [Integer] number of instances removed.
      def self.cleanup_old(max_age_seconds = 600)
        CreatureInstance.cleanup_old(max_age_seconds)
      end

      # Generate damage report for HP analysis
      def self.damage_report(**options)
        CreatureInstance.damage_report(**options)
      end

      # Print formatted damage report
      def self.print_damage_report(**options)
        CreatureInstance.print_damage_report(**options)
      end

      # Get all creature instances
      def self.all
        CreatureInstance.all
      end
    end

    # Keep the supporting classes from the original system
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

        # Parse range strings without eval (safer)
        if val.is_a?(String) && val.match?(/\A(\d+)\.\.(\d+)\z/)
          start_val, end_val = val.split('..').map(&:to_i)
          return start_val..end_val
        end

        val
      end
    end

    class PlaceholderTemplate
      def initialize(template, placeholders = {})
        @template = template
        @placeholders = placeholders
        @regex_cache = {}
      end

      def template
        @template
      end

      def placeholders
        @placeholders
      end

      def to_display(subs = {})
        line = @template.dup
        @placeholders.each do |key, options|
          value = subs[key] || options.sample || ""
          line.gsub!("{#{key}}", value.to_s)
        end
        line
      end

      def to_regex(literals = {})
        # Use cache to avoid rebuilding regex on every call
        cache_key = literals.hash
        return @regex_cache[cache_key] if @regex_cache[cache_key]

        regex = if @template.is_a?(Array)
                  regexes = @template.map { |t| self.class.new(t, @placeholders).to_regex(literals) }
                  Regexp.union(*regexes)
                else
                  build_regex(literals)
                end

        @regex_cache[cache_key] = regex
      end

      private

      def build_regex(literals)
        pattern = Regexp.escape(@template)
        @placeholders.each do |key, options|
          if options == [:wildcard] || options.first&.start_with?('RAW:')
            raw = options.first.start_with?('RAW:') ? options.first[4..-1] : options.first
            pattern.gsub!(/\\\{#{key}\\\}/, raw)
          else
            regex_group = "(?<#{key}>#{(literals[key] || options).map { |opt| Regexp.escape(opt) }.join('|')})"
            pattern.gsub!(/\\\{#{key}\\\}/, regex_group)
          end
        end
        Regexp.new("#{pattern}")
      end

      def match(str, literals = {})
        regex = to_regex(literals)
        m = regex.match(str)
        return nil unless m
        m.names.any? ? m.named_captures.transform_keys(&:to_sym) : m.captures
      end
    end
  end
end
