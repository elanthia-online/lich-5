require 'singleton'
require 'ostruct'

module Lich
  module Gemstone
    # Static creature template data (ID-less reference information)
    class CreatureTemplate
      @@templates = {}
      @@loaded = false
      @@max_templates = 500 # Prevent unbounded template cache growth

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
        @level = data[:level].to_i
        @family = data[:family]
        @type = data[:type]
        @undead = data[:undead]
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
      def self.load_all
        return if @@loaded

        templates_dir = File.join(File.dirname(__FILE__), 'creatures')
        return unless File.directory?(templates_dir)

        template_count = 0
        Dir[File.join(templates_dir, '*.rb')].each do |path|
          next if File.basename(path) == '_creature_template.rb'

          # Check template limit
          if template_count >= @@max_templates
            respond "--- warning: Template cache limit (#{@@max_templates}) reached, skipping remaining templates" if $creature_debug
            break
          end

          template_name = File.basename(path, '.rb').tr('_', ' ')
          normalized_name = fix_template_name(template_name)

          begin
            # Safer loading with validation
            file_content = File.read(path)
            data = load_template_data(file_content, path)
            next unless data.is_a?(Hash)

            data[:name] = template_name
            template = new(data)
            @@templates[normalized_name] = template
            template_count += 1
          rescue => e
            respond "--- error loading template #{template_name}: #{e.message}" if $creature_debug
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

    # Individual creature instance (runtime tracking with ID)
    class CreatureInstance
      @@instances = {}
      @@max_size = 1000
      @@auto_register = true

      attr_accessor :id, :noun, :name, :status, :injuries, :health, :damage_taken, :created_at, :fatal_crit, :status_timestamps,
                    :ucs_smote, :ucs_updated
      attr_writer :ucs_position, :ucs_tierup

      BODY_PARTS = %w[abdomen back chest head leftArm leftEye leftFoot leftHand leftLeg neck nerves rightArm rightEye rightFoot rightHand rightLeg]

      UCS_TTL = 120        # UCS data expires after 2 minutes
      UCS_SMITE_TTL = 15   # Smite effect expires after 15 seconds

      # Status effect durations (in seconds) for auto-cleanup
      # nil = no auto-cleanup (waits for removal message)
      STATUS_DURATIONS = {
        'breeze'      => 6, # 6 seconds roundtime
        'bind'        => 10, # 10 seconds typical
        'web'         => 8, # 8 seconds typical
        'entangle'    => 10, # 10 seconds typical
        'hypnotism'   => 12, # 12 seconds typical
        'calm'        => 15, # 15 seconds typical
        'mass_calm'   => 15, # 15 seconds typical
        'sleep'       => 8, # 8 seconds typical (can wake early)
        # Statuses with reliable removal messages - no duration needed
        'stunned'     => nil, # Has removal messages
        'immobilized' => nil, # Has removal messages
        'prone'       => nil,         # Has removal messages
        'blind'       => nil,         # Has removal messages
        'sunburst'    => nil, # Has removal messages
        'webbed'      => nil, # Has removal messages
        'poisoned'    => nil # Has removal messages
      }.freeze

      def initialize(id, noun, name)
        @id = id.to_i
        @noun = noun
        @name = name
        @status = []
        @injuries = Hash.new(0)
        @health = nil
        @damage_taken = 0
        @created_at = Time.now
        @fatal_crit = false
        @status_timestamps = {}
        @ucs_position = nil
        @ucs_tierup = nil
        @ucs_smote = nil
        @ucs_updated = nil
      end

      # Get the template for this creature
      def template
        @template ||= CreatureTemplate[@name]
      end

      # Check if creature has template data
      def has_template?
        !template.nil?
      end

      # Add status to creature
      def add_status(status, duration = nil)
        return if @status.include?(status)

        @status << status

        # Set expiration timestamp for timed statuses
        status_key = status.to_s.downcase
        duration ||= STATUS_DURATIONS[status_key]
        if duration
          @status_timestamps[status] = Time.now + duration
          respond "  +status: #{status} (expires in #{duration}s)" if $creature_debug
        else
          respond "  +status: #{status} (no auto-expiry)" if $creature_debug
        end
      end

      # Remove status from creature
      def remove_status(status)
        @status.delete(status)
        @status_timestamps.delete(status)
        respond "  -status: #{status}" if $creature_debug
      end

      # Clean up expired status effects
      def cleanup_expired_statuses
        return unless @status_timestamps && !@status_timestamps.empty?

        now = Time.now
        @status_timestamps.select { |_status, expires_at| expires_at <= now }.keys.each do |expired_status|
          @status.delete(expired_status)
          @status_timestamps.delete(expired_status)
          respond "  ~status: #{expired_status} (auto-expired)" if $creature_debug
        end
      end

      # Check if creature has a specific status
      def has_status?(status)
        cleanup_expired_statuses # Clean up expired statuses first
        @status.include?(status.to_s)
      end

      # Get all current statuses
      def statuses
        cleanup_expired_statuses # Clean up expired statuses first
        @status.dup
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
        respond "  UCS: position=#{new_tier}" if $creature_debug
      end

      # Set UCS tierup vulnerability
      def set_ucs_tierup(attack_type)
        @ucs_tierup = attack_type
        @ucs_updated = Time.now
        respond "  UCS: tierup=#{attack_type}" if $creature_debug
      end

      # Mark creature as smote (crimson mist applied)
      def smite!
        @ucs_smote = Time.now
        @ucs_updated = Time.now
        respond "  UCS: smote!" if $creature_debug
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
        respond "  UCS: smote cleared" if $creature_debug
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

      # Add injury to body part
      def add_injury(body_part, amount = 1)
        unless BODY_PARTS.include?(body_part.to_s)
          raise ArgumentError, "Invalid body part: #{body_part}"
        end
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
          ucs_smote: smote?
        }
      end

      # Class methods for registry management
      class << self
        # Configure registry
        def configure(max_size: 1000, auto_register: true)
          @@max_size = max_size
          @@auto_register = auto_register
        end

        # Check if auto-registration is enabled
        def auto_register?
          @@auto_register
        end

        # Get current registry size
        def size
          @@instances.size
        end

        # Check if registry is full
        def full?
          size >= @@max_size
        end

        # Register a new creature instance
        def register(name, id, noun = nil)
          return nil unless auto_register?
          return @@instances[id.to_i] if @@instances[id.to_i] # Already exists

          # Auto-cleanup old instances if registry is full - get progressively more aggressive
          if full?
            # Try 15 minutes, then 10, then 5, then 2, then give up
            [900, 600, 300, 120].each do |age_threshold|
              removed = cleanup_old(age_threshold)
              respond "--- Auto-cleanup: removed #{removed} old creatures (threshold: #{age_threshold}s)" if removed > 0 && $creature_debug
              break unless full?
            end
            return nil if full? # Still full after all cleanup attempts
          end

          instance = new(id, noun, name)
          @@instances[id.to_i] = instance
          respond "--- Creature registered: #{name} (#{id})" if $creature_debug
          instance
        end

        # Lookup creature by ID
        def [](id)
          @@instances[id.to_i]
        end

        # Get all registered instances
        def all
          @@instances.values
        end

        # Clear all instances (session reset)
        def clear
          @@instances.clear
        end

        # Remove old instances (cleanup)
        def cleanup_old(max_age_seconds = 600)
          cutoff = Time.now - max_age_seconds
          removed = @@instances.select { |_id, instance| instance.created_at < cutoff }.size
          @@instances.reject! { |_id, instance| instance.created_at < cutoff }
          removed
        end
      end
    end

    # Main Creature module - provides the public API
    module Creature
      # Lookup creature instance by ID
      def self.[](id)
        CreatureInstance[id]
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
          max_size: CreatureInstance.class_variable_get(:@@max_size),
          auto_register: CreatureInstance.auto_register?
        }
      end

      # Clear all instances
      def self.clear
        CreatureInstance.clear
      end

      # Cleanup old instances
      def self.cleanup_old(**options)
        CreatureInstance.cleanup_old(**options)
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
