# frozen_string_literal: true

require 'rexml/document'

module Lich
  module Common
    # Represents a game object (NPC, loot, inventory item, room description, etc.)
    # within the Lich game automation framework.
    #
    # GameObj tracks all in-game entities across categorized class-level registries
    # (loot, NPCs, PCs, inventory, room descriptions, familiar counterparts, and hands).
    # Each registry deduplicates entries by the composite key of +id+, +name+, and +noun+.
    #
    # @example Create a new NPC
    #   npc = GameObj.new_npc('1234', 'goblin', 'a snarling goblin')
    #
    # @example Look up an object by ID string
    #   obj = GameObj['1234']
    class GameObj
      # ---------------------------------------------------------------------------
      # Class-level registries
      # ---------------------------------------------------------------------------

      @@loot          = []
      @@npcs          = []
      @@npc_status    = {}
      @@pcs           = []
      @@pc_status     = {}
      @@inv           = []
      @@contents      = {}
      @@right_hand    = nil
      @@left_hand     = nil
      @@room_desc     = []
      @@fam_loot      = []
      @@fam_npcs      = []
      @@fam_pcs       = []
      @@fam_room_desc = []
      @@type_data     = {}
      @@type_cache    = {}
      @@sellable_data = {}

      # ---------------------------------------------------------------------------
      # Shared identity index — single persistent O(1) lookup pool with TTL.
      #
      # Maps composite key String <tt>"id|noun|name"</tt> to a two-element array
      # <tt>[GameObj, last_seen_at]</tt> where +last_seen_at+ is a Float timestamp
      # (from +Process.clock_gettime(Process::CLOCK_MONOTONIC)+) recording when
      # the entry was last accessed by +find_or_create+.
      #
      # All registries share this one index because a GameObj with the same
      # id, noun, and name is the same logical game entity regardless of which
      # registry it belongs to.
      #
      # The index is intentionally *not* flushed when a registry is cleared.
      # Room transitions call multiple +clear_*+ methods in quick succession;
      # flushing on every clear would cause every re-encountered object to be
      # needlessly reallocated. Instead, stale index entries self-heal: when
      # +find_or_create+ finds an entry for an object that was cleared from
      # its registry, it simply re-adds that same instance to the target
      # registry and refreshes its +last_seen_at+ timestamp.
      #
      # Garbage collection is handled by +prune_index!+, which removes entries
      # whose +last_seen_at+ is older than a given TTL (default 15 minutes).
      # Call it at natural session breakpoints (e.g. after a room transition or
      # from a script's idle loop). It is safe to call frequently — entries that
      # were just accessed will never be pruned regardless of how often it runs.
      #
      # Use +index_stats+ to inspect the current state of the index at any time.
      #
      # For very long automated sessions an alternative +LruIndex+ drop-in is
      # also available — see +Lich::Common::LruIndex+ below.
      # ---------------------------------------------------------------------------

      @@index = {}

      # ---------------------------------------------------------------------------
      # Instance interface
      # ---------------------------------------------------------------------------

      # @return [String] the unique string ID of this object
      attr_reader :id

      # @return [String, nil] noun used to refer to this object (e.g. "goblin")
      attr_accessor :noun

      # @return [String, nil] full descriptive name (e.g. "a snarling goblin")
      attr_accessor :name

      # @return [String, nil] text prepended before the name in full display
      attr_accessor :before_name

      # @return [String, nil] text appended after the name in full display
      attr_accessor :after_name

      # Initializes a new GameObj, normalizing certain irregular noun values.
      #
      # @param id     [Integer, String] the object's unique game ID
      # @param noun   [String, nil]     the object's noun
      # @param name   [String, nil]     the object's descriptive name
      # @param before [String, nil]     optional text before the name
      # @param after  [String, nil]     optional text after the name
      def initialize(id, noun, name, before = nil, after = nil)
        @id          = id.is_a?(Integer) ? id.to_s : id
        @noun        = normalize_noun(noun, name)
        @name        = name
        @before_name = before
        @after_name  = after
      end

      # Returns a human-readable representation of the object (its noun).
      #
      # @return [String, nil]
      def to_s
        @noun
      end

      # Legacy coercion method — returns the noun.
      # Kept for backwards-compatibility with scripts calling +obj.GameObj+.
      #
      # @return [String, nil]
      # @deprecated Use {#noun} or {#to_s} instead.
      def GameObj
        @noun
      end

      # Always returns +false+; GameObj instances are never considered empty.
      #
      # @return [false]
      def empty?
        false
      end

      # Returns a duplicated snapshot of the object's container contents.
      #
      # @return [Array<GameObj>, nil]
      def contents
        @@contents[@id]&.dup
      end

      # Returns the full display name, assembling before/name/after parts.
      #
      # @return [String]
      def full_name
        parts = [@before_name, @name, @after_name]
        parts.compact.reject(&:empty?).join(' ')
      end

      # ---------------------------------------------------------------------------
      # Type / sellable classification
      # ---------------------------------------------------------------------------

      # Returns a comma-separated string of matching type tags for this object,
      # or +nil+ if no types match.
      #
      # Results are memoized in +@@type_cache+ by name.
      #
      # @return [String, nil]
      def type
        GameObj.load_data if @@type_data.empty?
        return @@type_cache[@name] if @@type_cache.key?(@name)

        matches = matching_data_keys(@@type_data)
        @@type_cache[@name] = matches.empty? ? nil : matches.join(',')
      end

      # Returns whether this object matches the given type tag.
      #
      # @param type_to_check [String] a single type string (e.g. "herb")
      # @return [Boolean]
      def type?(type_to_check)
        type.to_s.split(',').include?(type_to_check)
      end

      # Returns a comma-separated string of sellable categories, or +nil+.
      #
      # @return [String, nil]
      def sellable
        GameObj.load_data if @@sellable_data.empty?
        matches = matching_data_keys(@@sellable_data)
        matches.empty? ? nil : matches.join(',')
      end

      # ---------------------------------------------------------------------------
      # Status
      # ---------------------------------------------------------------------------

      # Returns the current status string of this object, or +nil+ if present
      # but unstated, or +"gone"+ if not found in any registry.
      #
      # @return [String, nil]
      def status
        return @@npc_status[@id] if @@npc_status.key?(@id)
        return @@pc_status[@id]  if @@pc_status.key?(@id)

        present_in_any_registry? ? nil : 'gone'
      end

      # Sets the status of this NPC or PC by ID.
      #
      # @param val [String, nil] the new status value
      # @return [String, nil]
      def status=(val)
        if @@npcs.any? { |npc| npc.id == @id }
          @@npc_status[@id] = val
        elsif @@pcs.any? { |pc| pc.id == @id }
          @@pc_status[@id] = val
        end
      end

      # ---------------------------------------------------------------------------
      # Class-level factory methods
      # ---------------------------------------------------------------------------

      # Creates and registers a new NPC.
      #
      # @param id     [Integer, String]
      # @param noun   [String, nil]
      # @param name   [String, nil]
      # @param status [String, nil]
      # @return [GameObj]
      def self.new_npc(id, noun, name, status = nil)
        obj = find_or_create(@@npcs, id, noun, name)
        @@npc_status[obj.id] = status
        obj
      end

      # Creates and registers a new loot object.
      #
      # @param id   [Integer, String]
      # @param noun [String, nil]
      # @param name [String, nil]
      # @return [GameObj]
      def self.new_loot(id, noun, name)
        find_or_create(@@loot, id, noun, name)
      end

      # Creates and registers a new PC.
      #
      # @param id     [Integer, String]
      # @param noun   [String, nil]
      # @param name   [String, nil]
      # @param status [String, nil]
      # @return [GameObj]
      def self.new_pc(id, noun, name, status = nil)
        obj = find_or_create(@@pcs, id, noun, name)
        @@pc_status[obj.id] = status
        obj
      end

      # Creates and registers a new inventory item, optionally in a container.
      #
      # @param id        [Integer, String]
      # @param noun      [String, nil]
      # @param name      [String, nil]
      # @param container [String, nil]   ID of the containing object, or +nil+ for top-level inv
      # @param before    [String, nil]
      # @param after     [String, nil]
      # @return [GameObj]
      def self.new_inv(id, noun, name, container = nil, before = nil, after = nil)
        if container
          @@contents[container] ||= []
          find_or_create(@@contents[container], id, noun, name, before, after)
        else
          find_or_create(@@inv, id, noun, name, before, after)
        end
      end

      # Creates and registers a new room description object.
      #
      # @param id   [Integer, String]
      # @param noun [String, nil]
      # @param name [String, nil]
      # @return [GameObj]
      def self.new_room_desc(id, noun, name)
        find_or_create(@@room_desc, id, noun, name)
      end

      # Creates and registers a new familiar room description object.
      #
      # @param id   [Integer, String]
      # @param noun [String, nil]
      # @param name [String, nil]
      # @return [GameObj]
      def self.new_fam_room_desc(id, noun, name)
        find_or_create(@@fam_room_desc, id, noun, name)
      end

      # Creates and registers a new familiar loot object.
      #
      # @param id   [Integer, String]
      # @param noun [String, nil]
      # @param name [String, nil]
      # @return [GameObj]
      def self.new_fam_loot(id, noun, name)
        find_or_create(@@fam_loot, id, noun, name)
      end

      # Creates and registers a new familiar NPC.
      #
      # @param id   [Integer, String]
      # @param noun [String, nil]
      # @param name [String, nil]
      # @return [GameObj]
      def self.new_fam_npc(id, noun, name)
        find_or_create(@@fam_npcs, id, noun, name)
      end

      # Creates and registers a new familiar PC.
      #
      # @param id   [Integer, String]
      # @param noun [String, nil]
      # @param name [String, nil]
      # @return [GameObj]
      def self.new_fam_pc(id, noun, name)
        find_or_create(@@fam_pcs, id, noun, name)
      end

      # Sets the right-hand object, replacing any existing one.
      #
      # Routes through the shared identity index so the same item picked up
      # again returns the existing +GameObj+ instance rather than allocating
      # a new one. Replace semantics are preserved — +@@right_hand+ is always
      # overwritten with the result.
      #
      # @param id   [Integer, String]
      # @param noun [String, nil]
      # @param name [String, nil]
      # @return [GameObj]
      def self.new_right_hand(id, noun, name)
        @@right_hand = index_or_create(id, noun, name)
      end

      # Sets the left-hand object, replacing any existing one.
      #
      # Routes through the shared identity index so the same item picked up
      # again returns the existing +GameObj+ instance rather than allocating
      # a new one. Replace semantics are preserved — +@@left_hand+ is always
      # overwritten with the result.
      #
      # @param id   [Integer, String]
      # @param noun [String, nil]
      # @param name [String, nil]
      # @return [GameObj]
      def self.new_left_hand(id, noun, name)
        @@left_hand = index_or_create(id, noun, name)
      end

      # Looks up an existing +GameObj+ in the shared identity index by composite
      # key (+id+, +noun+, +name+), or creates and indexes a new one.
      #
      # Unlike +find_or_create+, this method does *not* push the object into any
      # registry array. It is intended for callers that manage their own storage
      # slot (e.g. +new_right_hand+/+new_left_hand+) or for external code that
      # constructs +GameObj+ instances via +GameObj.new+ but wants to participate
      # in the shared identity index so objects are reused and tracked for TTL-
      # based garbage collection.
      #
      # When a matching entry is found, +before_name+ and +after_name+ are
      # backfilled if they were previously +nil+ and the incoming values are
      # non-nil. Existing non-nil values are never overwritten.
      #
      # @example Replace a bare GameObj.new call
      #   # Before:
      #   obj = GameObj.new(id, noun, name, before, after)
      #
      #   # After — participates in the shared index:
      #   obj = GameObj.index_or_create(id, noun, name, before, after)
      #
      # @param id     [Integer, String]
      # @param noun   [String, nil]
      # @param name   [String, nil]
      # @param before [String, nil]   backfills +before_name+ if previously unset
      # @param after  [String, nil]   backfills +after_name+ if previously unset
      # @return [GameObj]
      def self.index_or_create(id, noun, name, before = nil, after = nil)
        str_id = id.is_a?(Integer) ? id.to_s : id
        key    = "#{str_id}|#{noun}|#{name}"
        now    = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        if (entry = @@index[key])
          existing, _ts        = entry
          @@index[key]         = [existing, now]
          existing.before_name = before if existing.before_name.nil? && !before.nil?
          existing.after_name  = after  if existing.after_name.nil?  && !after.nil?
          return existing
        end

        obj          = GameObj.new(id, noun, name, before, after)
        @@index[key] = [obj, now]
        obj
      end

      # ---------------------------------------------------------------------------
      # Class-level registry accessors (return dup or nil)
      # ---------------------------------------------------------------------------

      # @return [Array<GameObj>, nil]
      def self.right_hand  = @@right_hand&.dup

      # @return [Array<GameObj>, nil]
      def self.left_hand   = @@left_hand&.dup

      # @return [Array<GameObj>, nil]
      def self.npcs        = registry_or_nil(@@npcs)

      # @return [Array<GameObj>, nil]
      def self.loot        = registry_or_nil(@@loot)

      # @return [Array<GameObj>, nil]
      def self.pcs         = registry_or_nil(@@pcs)

      # @return [Array<GameObj>, nil]
      def self.inv         = registry_or_nil(@@inv)

      # @return [Array<GameObj>, nil]
      def self.room_desc   = registry_or_nil(@@room_desc)

      # @return [Array<GameObj>, nil]
      def self.fam_room_desc = registry_or_nil(@@fam_room_desc)

      # @return [Array<GameObj>, nil]
      def self.fam_loot    = registry_or_nil(@@fam_loot)

      # @return [Array<GameObj>, nil]
      def self.fam_npcs    = registry_or_nil(@@fam_npcs)

      # @return [Array<GameObj>, nil]
      def self.fam_pcs     = registry_or_nil(@@fam_pcs)

      # @return [Hash{String => Array<GameObj>}]
      def self.containers  = @@contents.dup

      # ---------------------------------------------------------------------------
      # Class-level clear methods
      # ---------------------------------------------------------------------------

      # @return [void]
      def self.clear_loot          = @@loot.clear

      # @return [void]
      def self.clear_npcs          = (@@npcs.clear; @@npc_status.clear)

      # @return [void]
      def self.clear_pcs           = (@@pcs.clear; @@pc_status.clear)

      # @return [void]
      def self.clear_inv           = @@inv.clear

      # @return [void]
      def self.clear_room_desc     = @@room_desc.clear

      # @return [void]
      def self.clear_fam_room_desc = @@fam_room_desc.clear

      # @return [void]
      def self.clear_fam_loot      = @@fam_loot.clear

      # @return [void]
      def self.clear_fam_npcs      = @@fam_npcs.clear

      # @return [void]
      def self.clear_fam_pcs       = @@fam_pcs.clear

      # Clears all container registries. The shared identity index is preserved
      # so previously seen objects are reused if re-encountered.
      #
      # @return [void]
      def self.clear_all_containers = @@contents.clear

      # Resets a single container's contents to an empty array.
      # The shared identity index is preserved.
      #
      # @param container_id [String]
      # @return [Array]
      def self.clear_container(container_id)
        @@contents[container_id] = []
      end

      # Removes a container and all its contents from the registry.
      # The shared identity index is preserved.
      #
      # @param container_id [String]
      # @return [GameObj, nil]
      def self.delete_container(container_id)
        @@contents.delete(container_id)
      end

      # ---------------------------------------------------------------------------
      # Lookup
      # ---------------------------------------------------------------------------

      # Finds a GameObj by ID (numeric string), noun (single word), or name.
      # Also accepts a +Regexp+ for name-based matching.
      #
      # @param val [String, Integer, Regexp]
      # @return [GameObj, nil]
      def self.[](val)
        unless val.is_a?(String) || val.is_a?(Regexp)
          respond "--- Lich: error: GameObj[] passed with #{val.class} #{val} via caller: #{caller[0]}"
          respond "--- Lich: error: GameObj[] supports String or Regexp only"
          Lich.log "--- Lich: error: GameObj[] passed with #{val.class} #{val} via caller: #{caller[0]}\n\t"
          Lich.log "--- Lich: error: GameObj[] supports String or Regexp only\n\t"

          if val.is_a?(Integer)
            respond "--- Lich: error: GameObj[] converted Integer #{val} to String to continue"
            val = val.to_s
          else
            return nil
          end
        end

        if val.is_a?(Regexp)
          return search_registries { |o| o.name =~ val }
        end

        if val =~ /^\-?[0-9]+$/
          # Numeric ID lookup (room_desc excluded from primary, appended last for completeness)
          search_registries { |o| o.id == val }
        elsif val.split(' ').length == 1
          # Single-word noun lookup
          search_registries { |o| o.noun == val }
        else
          # Name lookup — exact first, then suffix, then fuzzy suffix
          escaped     = Regexp.escape(val.strip)
          fuzzy       = Regexp.escape(val).sub(' ', ' .*')
          search_registries { |o| o.name == val } ||
            search_registries { |o| o.name =~ /\b#{escaped}$/i } ||
            search_registries { |o| o.name =~ /\b#{fuzzy}$/i }
        end
      end

      # ---------------------------------------------------------------------------
      # Targeting helpers
      # ---------------------------------------------------------------------------

      # Returns the list of active (non-dead, non-animated, non-appendage) NPCs
      # that are currently targeted via +XMLData.current_target_ids+.
      #
      # @return [Array<GameObj>]
      def self.targets
        XMLData.current_target_ids.filter_map do |id|
          npc = @@npcs.find { |n| n.id == id }
          next unless npc
          next if npc.status.to_s =~ /dead|gone/i
          next if npc.name  =~ /^animated\b/i && npc.name !~ /^animated slush/i
          next if npc.noun  =~ /^(?:arm|appendage|claw|limb|pincer|tentacle)s?$|^(?:palpus|palpi)$/i &&
                  npc.name !~ /(?:amaranthine|ghostly|grizzled|ancient) kraken tentacle/i
          npc
        end
      end

      # Returns IDs in the current target list that do not correspond to a known NPC.
      #
      # @return [Array<String>]
      def self.hidden_targets
        XMLData.current_target_ids.reject { |id| @@npcs.any? { |n| n.id == id } }
      end

      # Returns the single NPC or PC matching +XMLData.current_target_id+.
      #
      # @return [GameObj, nil]
      def self.target
        (@@npcs + @@pcs).find { |n| n.id == XMLData.current_target_id }
      end

      # Returns all NPCs with a status of +"dead"+, or +nil+ if none.
      #
      # @return [Array<GameObj>, nil]
      def self.dead
        dead_list = @@npcs.select { |obj| obj.status == 'dead' }
        dead_list.empty? ? nil : dead_list
      end

      # ---------------------------------------------------------------------------
      # Index lifecycle — pruning & diagnostics
      # ---------------------------------------------------------------------------

      # Removes entries from the shared identity index whose +last_seen_at+
      # timestamp is older than +ttl+ seconds ago **and** whose object is not
      # currently present in any active registry, then GC-hints Ruby.
      #
      # The live-registry check is the critical guard: an object that is still
      # held in +@@npcs+, +@@loot+, +@@inv+, or any other registry must never be
      # pruned regardless of how long ago it was last re-registered. Pruning a
      # live entry would cause the next +find_or_create+ call for that object to
      # allocate a brand-new instance, silently breaking the identity guarantee.
      #
      # An entry is only eligible for pruning when *both* conditions are true:
      #   1. +last_seen_at+ is older than +ttl+ seconds ago
      #   2. The object's ID is not present in any active registry
      #
      # Safe to call at any time and as frequently as desired. Entries that are
      # live in registries are always skipped. Entries accessed within the TTL
      # window are always skipped.
      #
      # Recommended call sites: after a room transition, in a script's idle loop,
      # or whenever +index_stats+ shows +:stale_entries+ growing large.
      #
      # When +verbose: true+, prints a before/after report to stdout showing:
      #   - GameObj count and estimated object memory before and after pruning
      #   - Ruby heap size before and after, with the net change
      #   - Number of entries pruned, skipped (live), and remaining
      #   - Time taken
      #
      # @example Silent prune (default)
      #   GameObj.prune_index!
      #
      # @example Prune with a 5-minute TTL and printed report
      #   GameObj.prune_index!(ttl: 300, verbose: true)
      #
      # @param ttl     [Integer] seconds since last access before a *stale* entry
      #   is eligible for eviction (default: 900 — 15 minutes)
      # @param verbose [Boolean] when +true+, prints a memory report to stdout
      #   (default: +false+)
      # @return [Hash] with the following keys:
      #   - +:pruned+               [Integer] — stale entries removed
      #   - +:skipped_live+         [Integer] — entries skipped because object is
      #       still present in at least one active registry
      #   - +:remaining+            [Integer] — entries still in the index
      #   - +:gameobj_bytes_before+ [Integer] — estimated GameObj memory before prune
      #   - +:gameobj_bytes_after+  [Integer] — estimated GameObj memory after prune
      #   - +:gameobj_bytes_freed+  [Integer] — difference (before - after)
      #   - +:heap_bytes_before+    [Integer] — Ruby heap size before GC hint
      #   - +:heap_bytes_after+     [Integer] — Ruby heap size after GC hint
      #   - +:heap_bytes_freed+     [Integer] — difference (before - after)
      #   - +:elapsed_ms+           [Float]   — wall time of the prune operation
      def self.prune_index!(ttl: 900, verbose: false)
        require 'objspace'
        t_start   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        cutoff    = t_start - ttl

        # Build the live-ID set once before the sweep so we do not repeatedly
        # iterate all registries inside the delete_if block.
        live_ids = live_registry_ids

        obj_before  = gameobj_memory_bytes
        heap_before = ruby_heap_bytes

        pruned       = 0
        skipped_live = 0

        @@index.delete_if do |_key, (obj, last_seen)|
          if live_ids.include?(obj.id)
            # Object is currently held in a registry — never prune regardless of age.
            skipped_live += 1
            false
          elsif last_seen < cutoff
            pruned += 1
            true
          else
            false
          end
        end

        GC.start(full_mark: false, immediate_sweep: false) if pruned.positive?

        obj_after  = gameobj_memory_bytes
        heap_after = ruby_heap_bytes
        elapsed    = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_start) * 1000

        result = {
          pruned: pruned,
          skipped_live: skipped_live,
          remaining: @@index.size,
          gameobj_bytes_before: obj_before,
          gameobj_bytes_after: obj_after,
          gameobj_bytes_freed: obj_before - obj_after,
          heap_bytes_before: heap_before,
          heap_bytes_after: heap_after,
          heap_bytes_freed: heap_before - heap_after,
          elapsed_ms: elapsed.round(3)
        }

        if verbose
          w = 28
          puts "=" * 52
          puts "  GameObj.prune_index! - TTL: #{ttl}s"
          puts "=" * 52
          puts format("  %-#{w}s %s -> %s  (%s)",
                      "GameObj object memory:",
                      format_bytes(obj_before),
                      format_bytes(obj_after),
                      format_delta(result[:gameobj_bytes_freed]))
          puts format("  %-#{w}s %s -> %s  (%s)",
                      "Ruby heap size:",
                      format_bytes(heap_before),
                      format_bytes(heap_after),
                      format_delta(result[:heap_bytes_freed]))
          puts format("  %-#{w}s %d removed, %d skipped (live), %d remaining",
                      "Index entries:",
                      pruned,
                      skipped_live,
                      @@index.size)
          puts format("  %-#{w}s %.3f ms", "Elapsed:", elapsed)
          puts "=" * 52
        end

        result
      end

      # Returns a Hash describing the current memory and age state of the index.
      #
      # Useful for diagnosing memory growth in long sessions. The +:age_buckets+
      # breakdown shows how many entries fall into each staleness window so you
      # can tune the TTL passed to +prune_index!+ accordingly.
      #
      # When +verbose: true+, prints a formatted report to stdout.
      #
      # @example Silent stats (default)
      #   stats = GameObj.index_stats
      #   puts stats[:stale_entries]
      #
      # @example Print a full formatted report
      #   GameObj.index_stats(verbose: true)
      #
      # @param verbose [Boolean] when +true+, prints a report to stdout
      #   (default: +false+)
      # @return [Hash] with the following keys:
      #   - +:total_entries+        [Integer] — total keys in +@@index+
      #   - +:live_in_registries+   [Integer] — objects in at least one registry
      #   - +:stale_entries+        [Integer] — objects in no active registry
      #   - +:oldest_entry_seconds+ [Float]   — age of the oldest entry in seconds
      #   - +:age_buckets+          [Hash{String => Integer}] — entry counts by
      #       last-seen age: under5m, 5-15m, 15-30m, 30-60m, over60m
      #   - +:gameobj_bytes+        [Integer] — estimated memory held by all indexed
      #       GameObj instances (via +ObjectSpace.memsize_of+)
      #   - +:heap_bytes+           [Integer] — current Ruby heap size
      def self.index_stats(verbose: false)
        require 'objspace'
        return empty_index_stats if @@index.empty?

        now        = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        live_ids   = live_registry_ids
        buckets    = { 'under5m' => 0, '5-15m' => 0,
                       '15-30m' => 0, '30-60m' => 0, 'over60m' => 0 }
        stale      = 0
        oldest_age = 0.0

        @@index.each_value do |obj, last_seen|
          age        = now - last_seen
          oldest_age = age if age > oldest_age
          stale     += 1 unless live_ids.include?(obj.id)

          buckets[case age
                  when 0...300    then 'under5m'
                  when 300...900  then '5-15m'
                  when 900...1800 then '15-30m'
                  when 1800...3600 then '30-60m'
                  else 'over60m'
                  end] += 1
        end

        obj_mem  = gameobj_memory_bytes
        heap_mem = ruby_heap_bytes

        result = {
          total_entries: @@index.size,
          live_in_registries: @@index.size - stale,
          stale_entries: stale,
          oldest_entry_seconds: oldest_age.round(1),
          age_buckets: buckets,
          gameobj_bytes: obj_mem,
          heap_bytes: heap_mem
        }

        if verbose
          oldest_fmt = if oldest_age < 60
                         "#{oldest_age.round(1)}s"
                       elsif oldest_age < 3600
                         "#{(oldest_age / 60).round(1)}m"
                       else
                         "#{(oldest_age / 3600).round(2)}h"
                       end

          w = 28
          puts "=" * 52
          puts "  GameObj.index_stats"
          puts "=" * 52
          puts format("  %-#{w}s %d", "Total index entries:",  @@index.size)
          puts format("  %-#{w}s %d", "Live in registries:",   result[:live_in_registries])
          puts format("  %-#{w}s %d", "Stale (index-only):",   stale)
          puts format("  %-#{w}s %s", "Oldest entry:",         oldest_fmt)
          puts "-" * 52
          puts "  Age distribution:"
          buckets.each do |label, count|
            bar = "#" * [count, 30].min
            puts format("  %-10s %4d  %s", label, count, bar)
          end
          puts "-" * 52
          puts format("  %-#{w}s %s", "GameObj object memory:", format_bytes(obj_mem))
          puts format("  %-#{w}s %s", "Ruby heap size:", format_bytes(heap_mem))
          puts "=" * 52
        end

        result
      end

      # ---------------------------------------------------------------------------
      # Data loading
      # ---------------------------------------------------------------------------

      # Reloads type and sellable data from disk.
      #
      # @param filename [String, nil] path to the XML data file, or +nil+ for default
      # @return [Boolean]
      def self.reload(filename = nil)
        load_data(filename)
      end

      # Merges two Regexp values via +Regexp.union+, or returns the new value
      # if the existing one is not yet a Regexp.
      #
      # @param existing  [Regexp, nil]
      # @param new_value [Regexp]
      # @return [Regexp]
      def self.merge_data(existing, new_value)
        existing.is_a?(Regexp) ? Regexp.union(existing, new_value) : new_value
      end

      # Loads type and sellable classification data from XML.
      # Merges custom overrides from +gameobj-custom/gameobj-data.xml+ if present.
      #
      # @param filename [String, nil] path override; defaults to +DATA_DIR/gameobj-data.xml+
      # @return [Boolean] +true+ on success, +false+ on failure
      def self.load_data(filename = nil)
        primary = filename || File.join(DATA_DIR, 'gameobj-data.xml')

        unless File.exist?(primary)
          @@type_data = @@sellable_data = nil
          echo "error: GameObj.load_data: file does not exist: #{primary}"
          return false
        end

        begin
          @@type_data     = {}
          @@sellable_data = {}
          @@type_cache    = {}
          parse_data_file(primary)
        rescue => e
          @@type_data = @@sellable_data = nil
          echo "error: GameObj.load_data: #{e}"
          respond e.backtrace[0..1]
          return false
        end

        custom = File.join(DATA_DIR, 'gameobj-custom', 'gameobj-data.xml')
        if File.exist?(custom)
          begin
            parse_data_file(custom, merge: true)
          rescue => e
            echo "error: Custom GameObj.load_data: #{e}"
            respond e.backtrace[0..1]
            return false
          end
        end

        true
      end

      # @return [Hash] the loaded type classification data
      def self.type_data     = @@type_data

      # @return [Hash] the memoized type lookup cache
      def self.type_cache    = @@type_cache

      # @return [Hash] the loaded sellable classification data
      def self.sellable_data = @@sellable_data

      # ---------------------------------------------------------------------------
      private

      # ---------------------------------------------------------------------------

      # Normalizes irregular noun values that the game provides inconsistently.
      #
      # @param noun [String, nil]
      # @param name [String, nil]
      # @return [String, nil]
      def normalize_noun(noun, name)
        case noun
        when 'lapis lazuli'   then 'lapis'
        when 'Hammer of Kai'  then 'hammer'
        when 'ball and chain' then 'ball'
        when 'pearl'
          (name =~ /mother\-of\-pearl/) ? 'mother-of-pearl' : noun
        else
          noun
        end
      end

      # Returns the keys from +data_hash+ whose +:name+ or +:noun+ patterns match
      # this object, subject to optional +:exclude+ filtering.
      #
      # @param data_hash [Hash]
      # @return [Array<String>]
      def matching_data_keys(data_hash)
        data_hash.keys.select do |t|
          entry = data_hash[t]
          matches = (@name =~ entry[:name] || @noun =~ entry[:noun])
          excluded = entry[:exclude] && @name =~ entry[:exclude]
          matches && !excluded
        end
      end

      # Returns +true+ if this object's ID is found in any active registry.
      #
      # @return [Boolean]
      def present_in_any_registry?
        all_flat_registries.any? { |obj| obj.id == @id } ||
          @@contents.values.any? { |list| list.any? { |obj| obj.id == @id } }
      end

      # Returns all flat (non-container) registries combined with hands as a
      # single array for iteration.
      #
      # @return [Array<GameObj>]
      def all_flat_registries
        [*@@loot, *@@inv, *@@room_desc,
         *@@fam_loot, *@@fam_npcs, *@@fam_pcs, *@@fam_room_desc,
         @@right_hand, @@left_hand].compact
      end

      # ---------------------------------------------------------------------------
      # Class-level private helpers
      # ---------------------------------------------------------------------------

      class << self
        private

        # All ordered search registries for +[]+, hands wrapped in an array to
        # use the same +#find+ interface.
        SEARCH_ORDER = proc do
          [@@inv, @@loot, @@npcs, @@pcs,
           [@@right_hand, @@left_hand].compact,
           @@room_desc,
           @@contents.values.flatten]
        end

        # Searches all registries in order, returning the first object satisfying
        # the given block.
        #
        # @yieldparam obj [GameObj]
        # @yieldreturn [Boolean]
        # @return [GameObj, nil]
        def search_registries(&block)
          SEARCH_ORDER.call.each do |registry|
            result = registry.find(&block)
            return result if result
          end
          nil
        end

        # Returns a dup of the registry, or +nil+ when empty.
        #
        # @param registry [Array<GameObj>]
        # @return [Array<GameObj>, nil]
        def registry_or_nil(registry)
          registry.empty? ? nil : registry.dup
        end

        # Finds an existing object matching the composite key (id + noun + name)
        # via an O(1) lookup in the shared +@@index+, or creates and registers
        # a new one.
        #
        # Each index entry stores a two-element array <tt>[GameObj, last_seen_at]</tt>.
        # +last_seen_at+ is refreshed on every hit using a monotonic clock, giving
        # +prune_index!+ an accurate staleness signal for garbage collection.
        #
        # All registries share a single persistent index. When +clear_*+ is
        # called, the registry array is emptied but the index is left intact.
        # If the same entity is encountered again (e.g. re-entering a room),
        # the existing +GameObj+ instance is returned, its timestamp refreshed,
        # and it is re-added to the cleared registry — no allocation required.
        #
        # When a duplicate is found, +before_name+ and +after_name+ are
        # backfilled if they were previously +nil+ and the incoming values are
        # non-nil. Existing non-nil values are never overwritten.
        #
        # @param registry [Array<GameObj>]  the target registry array
        # @param id       [Integer, String]
        # @param noun     [String, nil]
        # @param name     [String, nil]
        # @param before   [String, nil]   backfills +before_name+ if previously unset
        # @param after    [String, nil]   backfills +after_name+ if previously unset
        # @return [GameObj]
        def find_or_create(registry, id, noun, name, before = nil, after = nil)
          str_id = id.is_a?(Integer) ? id.to_s : id
          key    = "#{str_id}|#{noun}|#{name}"
          now    = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          if (entry = @@index[key])
            existing, _ts      = entry
            @@index[key]       = [existing, now] # refresh last-seen timestamp
            existing.before_name = before if existing.before_name.nil? && !before.nil?
            existing.after_name  = after  if existing.after_name.nil?  && !after.nil?
            registry.push(existing) unless registry.include?(existing)
            return existing
          end

          obj          = GameObj.new(id, noun, name, before, after)
          @@index[key] = [obj, now]
          registry.push(obj)
          obj
        end

        # Returns a Set (or Array if Set is unavailable) of all object IDs
        # currently present in any active registry, including the hand slots.
        # Used by +prune_index!+ as the live-guard check and by +index_stats+
        # to classify entries as live vs stale.
        #
        # @return [Set<String>, Array<String>]
        def live_registry_ids
          ids = [
            *@@loot, *@@npcs, *@@pcs, *@@inv,
            *@@room_desc, *@@fam_loot, *@@fam_npcs, *@@fam_pcs, *@@fam_room_desc,
            *@@contents.values.flatten,
            @@right_hand, @@left_hand
          ].compact.map(&:id)
          defined?(Set) ? Set.new(ids) : ids
        end

        # Returns the zero-state stats hash used when +@@index+ is empty.
        #
        # @return [Hash]
        def empty_index_stats
          {
            total_entries: 0,
            live_in_registries: 0,
            stale_entries: 0,
            oldest_entry_seconds: 0.0,
            age_buckets: { 'under5m' => 0, '5-15m' => 0,
                                    '15-30m' => 0, '30-60m' => 0, 'over60m' => 0 },
            gameobj_bytes: 0,
            heap_bytes: ruby_heap_bytes
          }
        end

        # Returns the sum of +ObjectSpace.memsize_of+ for every +GameObj+
        # currently held in +@@index+. This is an estimate of the memory
        # directly attributed to the GameObj instances themselves (not their
        # internal string fields, which Ruby may share via frozen literals).
        #
        # Requires +objspace+ — caller must +require 'objspace'+ first.
        #
        # @return [Integer] bytes
        def gameobj_memory_bytes
          @@index.sum { |_key, (obj, _ts)| ObjectSpace.memsize_of(obj) }
        end

        # Returns the current size of the Ruby heap in bytes, measured as
        # heap slots in use multiplied by the slot size reported by +GC.stat+.
        #
        # This is a process-level view — it reflects all live objects, not just
        # GameObjs — but is useful as a before/after marker around +prune_index!+
        # to confirm that a GC cycle reclaimed the expected working set.
        #
        # @return [Integer] bytes
        def ruby_heap_bytes
          stat      = GC.stat
          slot_size = stat[:heap_slot_size] || 40 # 40 bytes is the MRI default
          (stat[:heap_live_slots] || 0) * slot_size
        end

        # Formats +bytes+ as a human-readable string with an appropriate unit
        # (B, KB, MB, GB). Always shows two decimal places for KB and above.
        #
        # @param bytes [Integer]
        # @return [String]
        def format_bytes(bytes)
          abs = bytes.abs
          return "#{abs} B" if abs < 1024
          return format("%.2f KB", abs / 1024.0)        if abs < 1_048_576
          return format("%.2f MB", abs / 1_048_576.0)   if abs < 1_073_741_824
          format("%.2f GB", abs / 1_073_741_824.0)
        end

        # Formats a signed byte delta as a human-readable string, labelling
        # the direction as "freed" (positive) or "allocated" (negative).
        # Used in verbose output to correctly describe cases where Ruby
        # allocated slightly more memory during a prune than it reclaimed.
        #
        # @param delta [Integer] signed byte count (positive = freed, negative = allocated)
        # @return [String] e.g. "21.25 KB freed" or "720 B allocated"
        def format_delta(delta)
          label = delta >= 0 ? 'freed' : 'allocated'
          "#{format_bytes(delta.abs)} #{label}"
        end

        # Parses an XML data file, populating +@@type_data+ and +@@sellable_data+.
        # When +merge: true+, existing patterns are merged via +Regexp.union+.
        #
        # @param filename [String]
        # @param merge    [Boolean]
        # @return [void]
        def parse_data_file(filename, merge: false)
          File.open(filename) do |file|
            doc = REXML::Document.new(file.read)
            parse_data_section(doc, 'data/type',     @@type_data,     merge: merge)
            parse_data_section(doc, 'data/sellable', @@sellable_data, merge: merge)
          end
        end

        # Parses a named XPath section of the document into the given target hash.
        #
        # @param doc     [REXML::Document]
        # @param xpath   [String]
        # @param target  [Hash]
        # @param merge   [Boolean]
        # @return [void]
        def parse_data_section(doc, xpath, target, merge: false)
          doc.elements.each(xpath) do |e|
            key = e.attributes['name']
            next unless key

            target[key] ||= {}
            %i[name noun exclude].each do |field|
              text = e.elements[field.to_s]&.text
              next if text.nil? || text.empty?

              regexp = Regexp.new(text)
              target[key][field] = merge ? GameObj.merge_data(target[key][field], regexp) : regexp
            end
          end
        end
      end
    end

    # @deprecated Use {GameObj} directly.
    class RoomObj < GameObj; end

    # ---------------------------------------------------------------------------
    # Lich::Common::LruIndex — optional drop-in replacement for +@@index+
    #
    # A size-capped Least Recently Used (LRU) cache that stores the same
    # <tt>[GameObj, last_seen_at]</tt> tuple format as the default plain Hash,
    # making it a transparent drop-in replacement.
    #
    # Use when profiling shows +@@index+ growing too large in very long or
    # heavily automated sessions. Combines LRU eviction (by access recency)
    # with the same TTL-based +prune_older_than+ interface as +prune_index!+.
    #
    # Usage — swap the initializer inside GameObj:
    #
    #   @@index = Lich::Common::LruIndex.new(2000)
    #
    # How it works:
    #   Ruby Hashes preserve insertion order. On every read (+[]+) the accessed
    #   entry is moved to the end (most recently used). When the cap is reached
    #   on a write (+[]=+), the first entry (least recently used) is evicted.
    #   All operations remain O(1) amortized.
    #
    # Choosing a cap:
    #   A typical Lich session visits at most a few hundred unique room/NPC
    #   combinations. 2,000 is generous for normal play; raise to 5,000+ for
    #   marathon scripts that sweep large areas. Memory cost per entry is
    #   negligible (the key string + a two-element array).
    # ---------------------------------------------------------------------------
    class LruIndex
      # @param capacity [Integer] maximum number of entries before LRU eviction
      def initialize(capacity = 2000)
        @capacity = capacity
        @store    = {}
      end

      # Returns the +[GameObj, last_seen_at]+ tuple for +key+, promoting it to
      # most-recently-used position. Returns +nil+ if the key is not present.
      #
      # @param key [String]
      # @return [Array(GameObj, Float), nil]
      def [](key)
        return nil unless @store.key?(key)

        # Move to end (most recently used) by delete-and-reinsert
        value = @store.delete(key)
        @store[key] = value
        value
      end

      # Stores a +[GameObj, last_seen_at]+ tuple under +key+. Evicts the least
      # recently used entry first if the store is at capacity.
      #
      # @param key   [String]
      # @param value [Array(GameObj, Float)]
      # @return [Array(GameObj, Float)]
      def []=(key, value)
        @store.delete(key) if @store.key?(key)
        @store.shift if @store.size >= @capacity
        @store[key] = value
      end

      # Returns +true+ if +key+ is present without altering LRU order.
      #
      # @param key [String]
      # @return [Boolean]
      def key?(key)
        @store.key?(key)
      end

      # Removes entries whose +last_seen_at+ timestamp is older than +cutoff+
      # seconds (a monotonic Float). Mirrors the interface expected by
      # +prune_index!+ when +@@index+ is swapped for an +LruIndex+.
      #
      # @param cutoff [Float] monotonic timestamp; entries last seen before this
      #   time are removed
      # @return [Integer] the number of entries removed
      def prune_older_than(cutoff)
        pruned = 0
        @store.delete_if do |_key, (_obj, last_seen)|
          if last_seen < cutoff
            pruned += 1
            true
          else
            false
          end
        end
        pruned
      end

      # Iterates over all entries, yielding +[key, [GameObj, last_seen_at]]+ to
      # the block. Used by +index_stats+ when +@@index+ is an +LruIndex+.
      #
      # @yieldparam key   [String]
      # @yieldparam value [Array(GameObj, Float)]
      def each_value(&block)
        @store.each_value(&block)
      end

      # Removes all entries.
      #
      # @return [void]
      def clear
        @store.clear
      end

      # Removes entries using a block predicate, identical to +Hash#delete_if+.
      #
      # @yieldparam key   [String]
      # @yieldparam value [Array(GameObj, Float)]
      # @return [LruIndex]
      def delete_if(&block)
        @store.delete_if(&block)
        self
      end

      # Returns the current number of entries.
      #
      # @return [Integer]
      def size
        @store.size
      end
    end
  end
end
