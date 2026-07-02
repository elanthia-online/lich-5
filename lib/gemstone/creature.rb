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

      # Tri-state predicates: true, false, or nil when the template hasn't
      # catalogued this trait. nil is not coerced to false - an uncatalogued
      # creature is unknown, not confirmed bloodless/boneless/unmuggable.
      def has_blood?
        @has_blood
      end

      def has_bones?
        @has_bones
      end

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

    # Individual creature instance (runtime tracking with ID)
    class CreatureInstance
      @@instances = {}
      @@max_size = 1000
      @@auto_register = true

      # Ids currently present in the room, independent of @@instances (which
      # deliberately keeps departed creatures around for wound reporting).
      # Cleared and rebuilt entirely from xmlparser's own nav/room-objs hooks -
      # not read from or written to GameObj, by design (see retirement plan).
      @@current_room_ids = []

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

      # <crtrStatus exist="..." hostile="1" stunned="1" .../> XML attribute names,
      # mapped to the canonical status strings used above and by
      # Combat::Definitions::Statuses (message-based detection), so both sources
      # reconcile into the same @status entries instead of diverging spellings
      # (XML's "immobile"/"calmed" vs the parser's "immobilized"/"calm").
      CRTR_STATUS_FLAGS = {
        'immobile'    => 'immobilized',
        'webbed'      => 'webbed',
        'sleeping'    => 'sleeping',
        'disoriented' => 'disoriented',
        'stunned'     => 'stunned',
        'rooted'      => 'rooted',
        'calmed'      => 'calm',
        'kneeling'    => 'kneeling',
        'prone'       => 'prone',
        'sitting'     => 'sitting',
        'flying'      => 'flying',
        'hovering'    => 'hovering'
      }.freeze

      # Remaining <crtrStatus> attributes are classification/relationship facts
      # rather than transient combat conditions, so they don't go through
      # @status/STATUS_DURATIONS - they're read via #crtr_flag?.
      CRTR_CLASSIFICATION_FLAGS = {
        'hostile'       => :hostile,
        'disengaged'    => :disengaged,
        'dead'          => :dead,
        'sympathetic'   => :sympathetic,
        'ascended'      => :ascended,
        'inferior'      => :inferior,
        'AscensionBoss' => :ascension_boss,
        'MiniBoss'      => :mini_boss,
        'challenging'   => :challenging,
        'rider'         => :rider,
        'mount'         => :mount
      }.freeze

      # Every <crtrStatus> attribute's canonical name, keyed by XML name - used
      # for the :all/:active debug snapshot, which reports both buckets
      # together since they're both just attributes of the same tag.
      ALL_CRTR_FLAGS = CRTR_STATUS_FLAGS.merge(CRTR_CLASSIFICATION_FLAGS).freeze

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
        @crtr_flags = {}
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
      # Normalizes to String so callers can pass symbols (as combat/processor.rb's
      # message-based Statuses parser does) or strings (as <crtrStatus> handling
      # does) and both land in the same @status entries - has_status? already
      # compares via to_s, so storage needs to match or lookups silently miss.
      def add_status(status, duration = nil)
        status = status.to_s
        return if @status.include?(status)

        @status << status

        # Set expiration timestamp for timed statuses
        duration ||= STATUS_DURATIONS[status.downcase]
        if duration
          @status_timestamps[status] = Time.now + duration
          debug_log("+status: #{status} (expires in #{duration}s)")
        else
          debug_log("+status: #{status} (no auto-expiry)")
        end
      end

      # Remove status from creature
      def remove_status(status)
        status = status.to_s
        @status.delete(status)
        @status_timestamps.delete(status)
        debug_log("-status: #{status}")
      end

      # Clean up expired status effects
      def cleanup_expired_statuses
        return unless @status_timestamps && !@status_timestamps.empty?

        now = Time.now
        @status_timestamps.select { |_status, expires_at| expires_at <= now }.keys.each do |expired_status|
          @status.delete(expired_status)
          @status_timestamps.delete(expired_status)
          debug_log("~status: #{expired_status} (auto-expired)")
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

      # Reconcile status/classification from a <crtrStatus> tag's attributes.
      # The tag is a full snapshot of what's currently active, not a delta -
      # a flag missing (or "0") means inactive even if it was active a moment
      # ago, so absent flags must clear rather than just be ignored.
      def sync_crtr_status(attrs)
        CRTR_STATUS_FLAGS.each do |xml_name, status|
          if attrs[xml_name] == '1'
            add_status(status)
          elsif @status.include?(status)
            remove_status(status)
          end
        end

        CRTR_CLASSIFICATION_FLAGS.each do |xml_name, key|
          new_value = (attrs[xml_name] == '1')
          debug_log("~flag: #{key}=#{new_value}") if debug_level == :changes && @crtr_flags[key] != new_value
          @crtr_flags[key] = new_value
        end

        report_crtr_snapshot(attrs) if %i[all active].include?(debug_level)
      end

      # Look up a classification flag captured from <crtrStatus> (hostile, dead,
      # ascended, ascension_boss, mini_boss, etc). Unlike the template's tri-state
      # has_blood?/has_bones?/muggable?, this is false (not nil) until a
      # <crtrStatus> tag has actually been seen - these are always-sent booleans
      # off a live feed, not catalogued-or-unknown template data.
      def crtr_flag?(key)
        @crtr_flags[key.to_sym] || false
      end

      # True if key names either an active status (has_status?) or an active
      # classification flag (crtr_flag?) - the two vocabularies are disjoint,
      # so trying both lets callers filter on any known name without caring
      # which bucket it lives in. Backs Creature.targets' filter arguments.
      def flag_active?(key)
        has_status?(key) || crtr_flag?(key)
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

      # Same exclusions GameObj.targets applies (animated decoys, appendage/limb
      # sub-targets), but the dead check is structured (crtrStatus's dead flag,
      # or HP hitting 0) instead of regex-matching a status string. Backs
      # Creature.targets and is also usable standalone on a single lookup.
      def valid_target?
        return false if crtr_flag?(:dead) || dead?
        return false if @name =~ /^animated\b/i && @name !~ /^animated slush/i
        return false if @noun =~ /^(?:arm|appendage|claw|limb|pincer|tentacle)s?$|^(?:palpus|palpi)$/i &&
                        @name !~ /(?:amaranthine|ghostly|grizzled|ancient) kraken tentacle/i

        true
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

      private

      # true (from old-style Creature.debug_on(true)) is treated as :changes so
      # existing callers/behavior aren't disrupted by the level split.
      def debug_level
        $creature_debug == true ? :changes : $creature_debug
      end

      # Every debug line carries this so simultaneous encounters (routine at
      # ascended levels) stay attributable to the right creature.
      def debug_header
        "--- #{@name} (#{@id}):"
      end

      def debug_log(message)
        respond "#{debug_header} #{message}" if $creature_debug
      end

      # :all reports every <crtrStatus> flag every time; :active reports only
      # the ones currently true. Read straight from the tag's attrs rather
      # than post-mutation state, so the snapshot reflects exactly what the
      # tag said regardless of how add_status/@crtr_flags applied it.
      def report_crtr_snapshot(attrs)
        flags = ALL_CRTR_FLAGS.map { |xml_name, key| [key, attrs[xml_name] == '1'] }
        flags = flags.select { |_, active| active } if debug_level == :active
        debug_log("crtrStatus: #{flags.map { |key, active| "#{key}=#{active}" }.join(', ')}")
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

        # Register a new creature instance. Also marks the id as present in
        # the room - called every time a bolded name is seen in room-objs,
        # which is exactly the event that means "this creature is here now",
        # whether or not it's a brand-new instance.
        def register(name, id, noun = nil)
          return nil unless auto_register?

          entered_room = mark_in_room(id)

          existing = @@instances[id.to_i]
          if existing
            respond "--- #{name} (#{id}): in room" if entered_room && $creature_debug
            return existing
          end

          # Auto-cleanup old instances if registry is full - get progressively more aggressive
          if full?
            # Try 120 minutes, then 15 minute intervals.
            [7200, 6300, 5400, 4500, 3600, 2700, 1800, 900].each do |age_threshold|
              removed = cleanup_old(age_threshold)
              respond "--- Auto-cleanup: removed #{removed} old creatures (threshold: #{age_threshold}s)" if removed > 0 && $creature_debug
              break unless full?
            end
            return nil if full? # Still full after all cleanup attempts
          end

          instance = new(id, noun, name)
          @@instances[id.to_i] = instance
          respond "--- #{name} (#{id}): registered" if $creature_debug
          instance
        end

        # Marks an id present in the room, returning true if it wasn't
        # already. Internal - called from register; not meant to be called
        # directly by scripts.
        def mark_in_room(id)
          id = id.to_i
          return false if @@current_room_ids.include?(id)

          @@current_room_ids << id
          true
        end

        # Empties the room roster. Internal - called from xmlparser's own
        # nav/room-objs-refresh hooks (mirroring, not reading, GameObj's
        # equivalent clears) so it's rebuilt fresh on every room-objs line,
        # same accuracy characteristic as GameObj.npcs without depending on it.
        def clear_room
          count = @@current_room_ids.size
          @@current_room_ids = []
          respond "--- room: roster cleared (#{count} creature#{'s' unless count == 1})" if $creature_debug && count > 0
        end

        # Ids currently present in the room (see #clear_room/#mark_in_room).
        def current_room_ids
          @@current_room_ids.dup
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
          clear_room
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
      # Toggle live echo of status/flag/registration changes as they happen.
      # level:
      #   false     - off
      #   true / :changes (default) - only what actually changed (current behavior)
      #   :all      - every <crtrStatus> flag, every time, true or false
      #   :active   - every <crtrStatus> flag, every time, active (true) only
      def self.debug_on(level = :changes)
        $creature_debug = level
      end

      # Lookup creature instance by ID
      def self.[](id)
        CreatureInstance[id]
      end

      # Authoritative hostile creatures currently in the room. Deliberately
      # independent of GameObj (no .npcs, no .targets, no .status) - room
      # membership comes from CreatureInstance's own roster (see
      # CreatureInstance.clear_room/mark_in_room, hooked directly into
      # xmlparser's nav/room-objs events), unioned with XMLData.current_target_ids
      # to also catch anything actively engaged that hasn't hit a room-objs
      # refresh yet. valid_target? drops the dead/decoy/appendage noise;
      # crtr_flag?(:hostile) is the structured hostility signal.
      #
      # Extra filters narrow further, ANDed together: any known status name
      # (:prone, :stunned, ...) or classification flag (:hostile, :ascended,
      # ...), or its not_ negation (:not_prone). Unknown names simply match
      # nothing (flag_active? degrades to false), so this stays open-ended as
      # more statuses/flags get tracked - no changes needed here for those.
      def self.targets(*filters)
        ids = (CreatureInstance.current_room_ids + XMLData.current_target_ids.map(&:to_i)).uniq

        candidates = ids.filter_map { |id| CreatureInstance[id] }
                        .select { |c| c.valid_target? && c.crtr_flag?(:hostile) }

        filters.each do |filter|
          negate = filter.to_s.start_with?('not_')
          key = negate ? filter.to_s.delete_prefix('not_') : filter.to_s
          candidates = candidates.select { |c| c.flag_active?(key) != negate }
        end

        candidates
      end

      # Empties the room roster. Internal - see CreatureInstance.clear_room.
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
