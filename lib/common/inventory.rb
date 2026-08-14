# frozen_string_literal: true

require 'ox'

module Lich
  module Common
    # A read-only snapshot model of the Saga "extended feed" +inventoryManager+
    # stream (confirmed live on both GemStone and DragonRealms).
    #
    # Where {GameObj} exposes only the containers the passive stream has already
    # streamed (hands, worn, a pack you just opened), a single +inventoryManager+
    # response returns the player's ENTIRE nested item tree at once -- every
    # container's contents, each item's +weight+, container load (+in_encum+),
    # and +closed+/+locked+ state -- none of which {GameObj} carries. That makes
    # "find item X anywhere," "audit my whole inventory," and weight budgeting
    # answerable in one request.
    #
    # ## When to reach for this vs {GameObj}
    #
    # - **Use {Inventory}** for whole-inventory questions: find-anywhere, total
    #   carried weight, per-container used/free weight, container flags.
    # - **Use {GameObj}** for "what is in my hand / worn / in the pack I just
    #   opened" -- it is live and this model is a point-in-time snapshot.
    #
    # ## Freshness contract
    #
    # A snapshot reflects the moment its +inventoryManager+ response was produced.
    # It does NOT track later get/put/loot/hand changes. Call {.refresh} when you
    # need current data, and judge staleness from {.last_updated} / {.age}.
    #
    # ## Threading
    #
    # {.observe} is a passive, read-only tap driven from the game PARSER thread;
    # it never sends upstream and never raises. {.refresh} runs on the CALLER
    # (script) thread and sends the load verb itself. Never call {.refresh} from a
    # Downstream/Upstream hook proc -- it blocks waiting for {.observe} to run on
    # the parser thread and would stall the client pipeline.
    #
    # @example Find an item anywhere and read its container's free weight
    #   snap = Inventory.refresh
    #   if snap && (sword = snap.find('claymore'))
    #     pack = sword.parent_item
    #     Lich.log "claymore is in #{pack&.noun}, #{pack&.space_left} lb free"
    #   end
    #
    # @see GameObj Live, lazily-streamed hand/worn/opened-container view.
    module Inventory
      # Maximum tree depth walked by recursive traversals. Bounds a malformed or
      # cyclic +loc+ chain so traversal can never run away.
      MAX_TREE_DEPTH = 64

      # +in_max+/+on_max+ value the feed uses to mean "no weight limit" (it is
      # sent verbatim on count-limited containers, which carry no weight cap).
      # Treated as an unknown capacity ({Item#capacity_lbs} => nil).
      NO_WEIGHT_LIMIT_SENTINEL = 99_990

      # Consecutive {.refresh} timeouts (never seen a response) before the feed is
      # treated as structurally absent. More than one so a single slow first load
      # does not disable the feature.
      REFRESH_TIMEOUTS_BEFORE_ABSENT = 2

      # First feed-absent re-probe delay, in seconds; doubles per miss up to
      # {PROBE_BACKOFF_MAX_SECONDS} so a permanently-absent feed is not re-probed
      # forever and never stalls a caller for the full timeout on every call.
      PROBE_BACKOFF_BASE_SECONDS = 30

      # Ceiling for the feed-absent re-probe backoff, in seconds.
      PROBE_BACKOFF_MAX_SECONDS = 300

      # The five standard XML entities; the feed only escapes these (chiefly
      # +&quot;+ inside +long+ descriptions).
      XML_ENTITIES = { 'amp' => '&', 'lt' => '<', 'gt' => '>', 'quot' => '"', 'apos' => "'" }.freeze

      # Sentinel pushed to a pending {.refresh} latch when a response for that id
      # is incomplete (truncated/continuation), so the caller fails closed
      # promptly instead of waiting out the full timeout.
      FAILED = Object.new
      private_constant :FAILED

      # A single item from an +inventoryManager+ response: one exist id, its
      # identity, physical data, container facets, and links into the tree.
      #
      # Weight is intrinsic (location-independent -- a nodachi weighs the same in
      # a pocket or in a weight-nullifying eddy). Container load is read from the
      # wire via {#in_encum} when present, else summed from direct children.
      class Item
        # Leading article peeled into +before_name+ for the GameObj bridge so
        # {GameObj#full_name} reconstructs the whole phrase (matches the classic
        # inv stream's before/name split).
        LEADING_ARTICLE = /\A(an?|some|the)\s+/i
        # @return [String] the exist id (game object id) as a string
        attr_reader :id

        # @return [String] leading article/pre-noun words (e.g. "a scuffed")
        attr_reader :article

        # @return [String] the adjective segment (may be empty)
        attr_reader :adjective

        # @return [String] the noun (e.g. "pack"); used for classification
        attr_reader :noun

        # @return [String] assembled short display name (e.g. "a scuffed pack")
        attr_reader :name

        # @return [String, nil] the long description, entity-decoded, or nil
        attr_reader :long

        # @return [String, nil] the +loc+ relation: "worn", "in", "on", "room"
        attr_reader :relation

        # @return [String, nil] parent exist id, "player", "room", or nil
        attr_reader :parent_id

        # @return [Integer] intrinsic weight in pounds (0 when absent)
        attr_reader :weight

        # @return [Integer, nil] weight capacity in pounds, or nil when unknown
        #   (no in_max/on_max, or the {NO_WEIGHT_LIMIT_SENTINEL})
        attr_reader :capacity_lbs

        # @return [Integer, nil] raw container load from the wire (0 for a
        #   weight-nullifying container), or nil when the wire omits it
        attr_reader :in_encum

        # @return [String, nil] the container's +in_selector+ verb hint, or nil
        attr_reader :in_selector

        # @return [Array<String>] flag tokens, e.g. ["closed", "locked"]
        attr_reader :flags

        # @return [Array<Item>] direct children (both "in" and "on")
        attr_reader :children

        # @return [Item, nil] the parent {Item}, or nil for a top-level item
        attr_reader :parent_item

        # @param fields [Hash] pre-parsed, coerced attribute values
        # @api private
        def initialize(fields)
          @id           = fields[:id]
          @article      = fields[:article]
          @adjective    = fields[:adjective]
          @noun         = fields[:noun]
          @name         = fields[:name]
          @long         = fields[:long]
          @relation     = fields[:relation]
          @parent_id    = fields[:parent_id]
          @weight       = fields[:weight]
          @capacity_lbs = fields[:capacity_lbs]
          @in_encum     = fields[:in_encum]
          @in_selector  = fields[:in_selector]
          @flags        = fields[:flags]
          @has_max      = fields[:has_max]
          @children     = []
        end

        # Whether this item can hold other items: it either has children or
        # advertises a weight cap. (A max-less holder -- e.g. a ring-holder with
        # rings ON it -- is still a container.)
        #
        # @return [Boolean]
        # @example
        #   Inventory['40236126'].container? #=> true
        def container?
          !@children.empty? || @has_max
        end

        # @return [Boolean] whether the container is closed (still enumerated)
        def closed?
          @flags.include?('closed')
        end

        # @return [Boolean] whether the container is locked
        def locked?
          @flags.include?('locked')
        end

        # Whether the interior is unknown. A LOCKED container emits zero children
        # by game design (treasure boxes populate only on open; gem pouches
        # aggregate), so it is opaque -- never conclude it is empty.
        #
        # @return [Boolean]
        def opaque?
          locked?
        end

        # @return [Boolean] whether the item is worn on the player
        def worn?
          @parent_id == 'player'
        end

        # @return [Boolean] whether the item is on the ground in the room
        def in_room?
          @relation == 'room' || @parent_id == 'room'
        end

        # Direct children, optionally filtered by relation. An opaque (locked)
        # container returns +[]+ (contents unknown), never a false "empty".
        #
        # @param relation [Symbol, String, nil] :in, :on, or nil for all
        # @return [Array<Item>]
        # @example List only what is worn ON a ring-holder
        #   Inventory['40235982'].contents(:on)
        def contents(relation = nil)
          return [] if opaque?
          return @children.dup if relation.nil?

          @children.select { |child| child.relation == relation.to_s }
        end

        # Weight currently used by this container, in pounds: {#in_encum} when
        # the wire provides it (authoritative for magical containers), else the
        # sum of direct children's intrinsic {#weight}. +nil+ for a non-container
        # or an opaque (locked) container, where it is not meaningful.
        #
        # @return [Integer, nil]
        # @example
        #   Inventory['40236126'].used_lbs #=> 84
        def used_lbs
          return nil unless container?
          return nil if opaque?
          return @in_encum unless @in_encum.nil?

          @children.sum(&:weight)
        end

        # Remaining weight capacity in pounds, or +nil+ when either capacity or
        # used weight is unknown (never raises on a nil operand). Not clamped --
        # may be negative if a container is overfull.
        #
        # @return [Integer, nil]
        # @example
        #   Inventory['40236126'].space_left #=> 86
        def space_left
          return nil if @capacity_lbs.nil? || used_lbs.nil?

          @capacity_lbs - used_lbs
        end

        # Total effective weight of this item and everything it carries, in
        # pounds. A container subtree contributes the container's own {#weight}
        # plus ({#in_encum} when present, else the recursive contribution of its
        # children) -- so a weight-nullifying eddy adds only its own weight, not
        # the heavy contents inside it. Cycle-safe (visited set + depth cap).
        #
        # @return [Integer]
        # @example The eddy weighs 10 lb regardless of its contents
        #   Inventory['40235966'].total_weight #=> 10
        def total_weight(visited = Set.new, depth = 0)
          return 0 if depth > MAX_TREE_DEPTH || visited.include?(@id)

          visited.add(@id)
          own = @weight
          return own unless container?
          return own if opaque?
          return own + @in_encum unless @in_encum.nil?

          own + @children.sum { |child| child.total_weight(visited, depth + 1) }
        end

        # Type classification (e.g. "weapon,edged"), derived from this item's own
        # noun/name via {#bridge_gameobj} -- NOT +GameObj[id]+, which is nil for
        # delta items in unopened containers.
        #
        # @return [String, nil] comma-joined type tags, or nil if none match
        # @example
        #   Inventory.refresh.find('sword')&.type #=> "weapon"
        def type
          bridge_gameobj.type
        end

        # Sellable classification, derived like {#type} from the item's own
        # noun/name via {#bridge_gameobj}.
        #
        # @return [String, nil] comma-joined sellable tags, or nil if none match
        # @example
        #   Inventory.refresh.find('diamond')&.sellable #=> "gem"
        def sellable
          bridge_gameobj.sellable
        end

        # Attaches a child during tree construction.
        #
        # @param child [Item]
        # @return [void]
        # @api private
        def add_child(child)
          @children << child
        end

        # Records the parent item during tree construction.
        #
        # @param parent [Item]
        # @return [void]
        # @api private
        def link_parent(parent)
          @parent_item = parent
        end

        # Freezes the child list once the tree is fully wired.
        #
        # @return [void]
        # @api private
        def finalize!
          @children.freeze
        end

        private

        # A pooled {GameObj} carrying this item's identity, used only to borrow
        # {GameObj#type}/{GameObj#sellable} classification.
        #
        # Built with {GameObj.index_or_create} (never a bare {GameObj.new}), so it
        # reuses an existing instance for the same +id|noun|name+ and joins the
        # shared identity index and its TTL. It is deliberately NOT pushed into any
        # registry, so Inventory stays a non-writer of GameObj's query surfaces
        # (+GameObj[]+ still won't resolve a delta item). The name fed to the
        # matchers is the full descriptive name (the item's {#long} when present)
        # with the leading article split into +before_name+, so {GameObj#full_name}
        # reconstructs the whole phrase and classification matches as it would for
        # a live GameObj.
        #
        # @return [GameObj]
        # @api private
        def bridge_gameobj
          @bridge_gameobj ||= begin
            before, name = bridge_name_parts
            GameObj.index_or_create(@id, @noun, name, before)
          end
        end

        # Splits the full descriptive name for {#bridge_gameobj}: prefer {#long},
        # else the assembled short {#name}, then peel a leading a/an/some/the into
        # +before_name+.
        #
        # @return [Array(String, nil), Array(String, String)] before_name, name
        # @api private
        def bridge_name_parts
          source = @long && !@long.empty? ? @long : @name
          if (match = source.match(LEADING_ARTICLE))
            [match[1], source.sub(LEADING_ARTICLE, '')]
          else
            [nil, source]
          end
        end
      end

      # An immutable, point-in-time inventory snapshot. Returned by {.refresh} so
      # a caller has a consistent view even as passive absorption swaps the global
      # snapshot. Query it directly rather than re-reading the global accessors.
      class Snapshot
        # @return [Time] wall-clock time the snapshot was built
        attr_reader :last_updated

        # @return [String, nil] the room id from the response envelope
        attr_reader :room_id

        # @param items [Hash{String => Item}] id-keyed items (wire order)
        # @param room_id [String, nil] envelope room id
        # @api private
        def initialize(items:, room_id:)
          @items    = items.freeze
          @room_id  = room_id
          @worn     = items.values.select(&:worn?).freeze
          @room     = items.values.select(&:in_room?).freeze
          @built_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @last_updated = Time.now
          freeze
        end

        # @return [Array<Item>] every item in the snapshot
        def all
          @items.values
        end

        # Looks up an item by exist id.
        #
        # @param id [String, Integer] the exist id
        # @return [Item, nil]
        # @example
        #   Inventory.refresh['40236126']
        def [](id)
          @items[id.to_s]
        end

        # Finds the first item whose noun, name, or long matches.
        #
        # @param pattern [String, Regexp] substring (case-insensitive) or regexp
        # @return [Item, nil]
        # @example
        #   Inventory.refresh.find('lootpouch')
        def find(pattern)
          rx = pattern.is_a?(Regexp) ? pattern : Regexp.new(Regexp.escape(pattern.to_s), Regexp::IGNORECASE)
          all.find { |item| item.noun =~ rx || item.name =~ rx || (item.long && item.long =~ rx) }
        end

        # Filters items by exact noun and/or exact display name.
        #
        # @param noun [String, nil] exact noun to match
        # @param name [String, nil] exact display name to match
        # @return [Array<Item>]
        # @example
        #   Inventory.refresh.where(noun: 'ring')
        def where(noun: nil, name: nil)
          result = all
          result = result.select { |item| item.noun == noun } if noun
          result = result.select { |item| item.name == name } if name
          result
        end

        # @return [Array<Item>] every item that is a container
        def containers
          all.select(&:container?)
        end

        # @return [Array<Item>] items worn on the player (top-level carried)
        def worn
          @worn
        end

        # @return [Array<Item>] items on the ground in the room
        def room
          @room
        end

        # Total carried encumbrance in pounds: the recursive {Item#total_weight}
        # of every worn item (with the +in_encum+ short-circuit).
        #
        # @return [Integer]
        def total_weight
          @worn.sum(&:total_weight)
        end

        # Seconds elapsed since the snapshot was built (monotonic).
        #
        # @return [Float]
        # @example
        #   Inventory.refresh.age #=> 0.0
        def age
          Process.clock_gettime(Process::CLOCK_MONOTONIC) - @built_at
        end
      end

      # Ox SAX handler for a SINGLE isolated +inventoryManager+ line. Collects
      # decoded item attribute hashes and any parse errors, and flags a
      # continuation (paginated) response. Mirrors the +error+-callback pattern
      # in {XMLParser} because Ox never raises on malformed input -- it
      # auto-closes and reports damage only through {#error}.
      #
      # @api private
      class Handler
        # @return [Array<Hash>] raw attribute hashes, one per <i>
        attr_reader :items

        # @return [Array<String>] collected Ox parse-error messages
        attr_reader :errors

        # @return [String, nil] the envelope +room+ attribute
        attr_reader :room_id

        # @return [String, nil] the envelope +id+ (request id)
        attr_reader :manager_id

        def initialize
          @items        = []
          @errors       = []
          @room_id      = nil
          @manager_id   = nil
          @continuation = false
          @element      = nil
          @attributes   = nil
        end

        # @param name [String] element name
        # @return [void]
        def start_element(name)
          @element = name
          @attributes = {}
        end

        # @param name [String] attribute name
        # @param value [String] raw attribute value (not entity-decoded)
        # @return [void]
        def attr(name, value)
          @attributes[name] = value if @attributes
        end

        # Flush accumulated attributes for the current element.
        #
        # @return [void]
        def attrs_done
          case @element
          when 'inventoryManager'
            @manager_id   = @attributes['id']
            @room_id      = @attributes['room']
            @continuation = true if @attributes.key?('root') || @attributes.key?('after')
          when 'i'
            @items << @attributes
          when 'continuation'
            @continuation = true
          end
        end

        # @param _name [String] element name
        # @return [void]
        def end_element(_name); end

        # @param _value [String] text content (ignored)
        # @return [void]
        def text(_value); end

        # @param _value [String] CDATA content (ignored)
        # @return [void]
        def cdata(_value); end

        # @param message [String] Ox error message
        # @param line [Integer] line number
        # @param column [Integer] column number
        # @return [void]
        def error(message, line, column)
          @errors << "#{message} (line #{line}, column #{column})"
        end

        # @return [Boolean] whether this was a continuation/paginated response
        def continuation?
          @continuation
        end
      end

      @mutex         = Mutex.new
      @refresh_mutex = Mutex.new

      class << self
        # Passively taps a server line: if it is a COMPLETE initial
        # +inventoryManager+ response, absorb it as the new snapshot; otherwise
        # keep the prior snapshot. Always returns the input unchanged and NEVER
        # raises (an uncaught error here would kill the game parser thread and
        # drop the player's session), and never sends upstream.
        #
        # Fails closed on: an Ox parse error, a line that does not structurally
        # close, a continuation/paginated response, or a zero-item PASSIVE
        # response over a non-empty snapshot.
        #
        # @param server_string [String] a raw line from the game server
        # @return [String] +server_string+, unchanged
        # @note Runs on the game PARSER thread. Do not call from scripts; use
        #   {.refresh} for an explicit, returned snapshot.
        # @example Wired into the parser path (games.rb)
        #   Inventory.observe(server_string)
        def observe(server_string)
          return server_string unless server_string.is_a?(String) && server_string.include?('<inventoryManager')

          begin
            handler = parse(server_string)
            if response_complete?(handler, server_string)
              commit(handler, build_snapshot(handler))
            else
              reject(handler)
            end
          rescue StandardError => e
            log("Inventory.observe error: #{e.class}: #{e.message}")
          end

          server_string
        end

        # Requests a fresh inventory load and returns the resulting snapshot.
        # Sends +_inventory manager {id}+, then waits (on the CALLER thread) up to
        # +timeout+ seconds for {.observe} to signal that id complete.
        #
        # Returns +nil+ on timeout, on a truncated/continuation response, or when
        # the feed is known-absent (fast-fails without sending, re-probing on a
        # capped exponential backoff). Callers should use the RETURNED object for
        # a consistent view, since passive absorption may swap the global
        # snapshot at any time.
        #
        # @param timeout [Numeric] seconds to wait (5s matches the official client)
        # @return [Snapshot, nil] the fresh snapshot, or nil on failure/absence
        # @note MUST run on a script thread. Never call from a Downstream/Upstream
        #   hook proc -- it would block waiting on the parser thread.
        # @example
        #   snap = Inventory.refresh
        #   snap&.find('backpack')
        def refresh(timeout: 5)
          return @snapshot unless probe_allowed?

          @refresh_mutex.synchronize do
            id = generate_id
            latch = Queue.new
            @mutex.synchronize { @pending[id] = latch }

            begin
              Game._puts("_inventory manager #{id}")
              result = latch.pop(timeout: timeout)
            ensure
              @mutex.synchronize { @pending.delete(id) }
            end

            if result.nil?
              register_timeout!
              nil
            elsif result.equal?(FAILED)
              nil
            else
              result
            end
          end
        end

        # @return [Array<Item>] all items in the current snapshot (empty if none)
        def all
          @snapshot ? @snapshot.all : []
        end

        # @param id [String, Integer] exist id
        # @return [Item, nil] the item from the current snapshot
        # @example
        #   Inventory['40236126']
        def [](id)
          @snapshot && @snapshot[id]
        end

        # @param pattern [String, Regexp] substring or regexp
        # @return [Item, nil] first match in the current snapshot
        # @example
        #   Inventory.find('lootpouch')
        def find(pattern)
          @snapshot && @snapshot.find(pattern)
        end

        # @param noun [String, nil] exact noun
        # @param name [String, nil] exact display name
        # @return [Array<Item>] matching items in the current snapshot
        # @example
        #   Inventory.where(noun: 'ring')
        def where(noun: nil, name: nil)
          @snapshot ? @snapshot.where(noun: noun, name: name) : []
        end

        # @return [Array<Item>] container items in the current snapshot
        def containers
          @snapshot ? @snapshot.containers : []
        end

        # @return [Array<Item>] worn items in the current snapshot
        def worn
          @snapshot ? @snapshot.worn : []
        end

        # @return [Array<Item>] room (ground) items in the current snapshot
        def room
          @snapshot ? @snapshot.room : []
        end

        # @return [String, nil] the current snapshot's envelope room id
        def room_id
          @snapshot && @snapshot.room_id
        end

        # @return [Integer] total carried weight of the current snapshot
        def total_weight
          @snapshot ? @snapshot.total_weight : 0
        end

        # @return [Time, nil] when the current snapshot was built
        def last_updated
          @snapshot && @snapshot.last_updated
        end

        # @return [Float, nil] seconds since the current snapshot was built
        def age
          @snapshot && @snapshot.age
        end

        # Whether an +inventoryManager+ response has ever been observed. False
        # until the first response and while the feed is treated as absent, so a
        # non-Saga session leaves the feature inert.
        #
        # @return [Boolean]
        # @example
        #   return unless Inventory.feed_available? || Inventory.refresh
        def feed_available?
          @feed_seen == true
        end

        # @return [Snapshot, nil] the current global snapshot object
        def current
          @snapshot
        end

        # Clears all snapshot and feed state. Intended for a session reset /
        # reconnect; also used to isolate tests.
        #
        # @return [void]
        def reset!
          @snapshot           = nil
          @feed_seen          = false
          @consecutive_timeouts = 0
          @feed_absent_until  = nil
          @absent_backoff     = PROBE_BACKOFF_BASE_SECONDS
          @id_counter         = 0
          (@pending ||= {}).clear
        end

        private

        # Parses one isolated line with a dedicated Ox SAX handler (never the live
        # XMLData). +convert_special: false+ keeps Ox in bytes-land, mirroring the
        # main parser; entities are decoded in {.build_item}.
        #
        # @param server_string [String]
        # @return [Handler]
        # @api private
        def parse(server_string)
          handler = Handler.new
          Ox.sax_parse(handler, server_string, convert_special: false, symbolize: false, skip: :skip_none)
          handler
        end

        # A response is usable only if Ox reported no errors, the line
        # structurally closed, and it is not a continuation/paginated fragment.
        #
        # @param handler [Handler]
        # @param server_string [String]
        # @return [Boolean]
        # @api private
        def response_complete?(handler, server_string)
          return false unless handler.errors.empty?
          return false if handler.continuation?

          structurally_closed?(server_string)
        end

        # Whether the line contains a real closing tag or is self-closing. A
        # string-level check, independent of Ox's silent auto-close on truncation.
        #
        # @param server_string [String]
        # @return [Boolean]
        # @api private
        def structurally_closed?(server_string)
          server_string.include?('</inventoryManager>') ||
            server_string.match?(%r{<inventoryManager\b[^>]*/>})
        end

        # Builds an immutable {Snapshot} from a completed parse: coerce items,
        # wire the parent/child tree (order-independent), then freeze.
        #
        # @param handler [Handler]
        # @return [Snapshot]
        # @api private
        def build_snapshot(handler)
          items = {}
          handler.items.each do |raw|
            item = build_item(raw)
            items[item.id] = item
          end
          wire_tree(items)
          Snapshot.new(items: items, room_id: handler.room_id)
        end

        # Coerces one raw <i> attribute hash into an {Item}.
        #
        # @param raw [Hash] raw string attributes
        # @return [Item]
        # @api private
        def build_item(raw)
          relation, parent_id = parse_loc(raw['loc'])
          article, adjective, noun, name = parse_name(raw['name'])

          Item.new(
            id: raw['id'],
            article: article,
            adjective: adjective,
            noun: noun,
            name: name,
            long: decode_entities(raw['long']),
            relation: relation,
            parent_id: parent_id,
            weight: raw['weight'].to_i,
            capacity_lbs: capacity_from(raw),
            in_encum: raw.key?('in_encum') ? raw['in_encum'].to_i : nil,
            in_selector: decode_entities(raw['in_selector']),
            flags: raw['flags'].to_s.split(','),
            has_max: raw.key?('in_max') || raw.key?('on_max')
          )
        end

        # Splits a +loc+ value into [relation, parent]. Forms seen on the wire:
        # "worn,player", "in,{id}", "on,{id}", and a bare "room".
        #
        # @param loc [String, nil]
        # @return [Array(String, String), Array(nil, nil)]
        # @api private
        def parse_loc(loc)
          parts = loc.to_s.split(',')
          case parts.size
          when 0 then [nil, nil]
          when 1 then parts.first == 'room' ? ['room', 'room'] : [parts.first, nil]
          else [parts[0], parts[1]]
          end
        end

        # Splits a +name+ ("article,adjective,noun") into its parts and a joined
        # display name. Empty segments are dropped from the display form.
        #
        # @param raw [String, nil]
        # @return [Array(String, String, String, String)] article, adjective, noun, display
        # @api private
        def parse_name(raw)
          parts = decode_entities(raw).to_s.split(',')
          noun = parts.last.to_s.strip
          article = parts.size > 1 ? parts.first.to_s.strip : ''
          adjective = parts[1..-2].to_a.map(&:strip).reject(&:empty?).join(' ')
          display = [article, adjective, noun].reject(&:empty?).join(' ')
          [article, adjective, noun, display]
        end

        # Weight capacity in pounds from +in_max+ (or +on_max+), or nil when
        # absent or the {NO_WEIGHT_LIMIT_SENTINEL}.
        #
        # @param raw [Hash]
        # @return [Integer, nil]
        # @api private
        def capacity_from(raw)
          value = raw['in_max'] || raw['on_max']
          return nil if value.nil?

          number = value.to_i
          return nil if number == NO_WEIGHT_LIMIT_SENTINEL

          number / 10
        end

        # Wires each item into its parent's children (order-independent). Items
        # whose parent is player/room/absent stay top-level or index-only; an
        # orphan (unknown parent id) remains findable but is placed in no bucket.
        #
        # @param items [Hash{String => Item}]
        # @return [void]
        # @api private
        def wire_tree(items)
          items.each_value do |item|
            pid = item.parent_id
            next if pid.nil? || pid == 'player' || pid == 'room'

            parent = items[pid]
            next unless parent

            parent.add_child(item)
            item.link_parent(parent)
          end
          items.each_value(&:finalize!)
        end

        # Decodes the five standard XML entities. Numeric entities are left
        # literal (rare in item names) to avoid encoding hazards.
        #
        # @param str [String, nil]
        # @return [String, nil]
        # @api private
        def decode_entities(str)
          return str if str.nil? || !str.include?('&')

          str.gsub(/&(amp|lt|gt|quot|apos);/) { XML_ENTITIES[Regexp.last_match(1)] }
        end

        # Commits a completed snapshot under the mutex: the feed is now known
        # present; swap the snapshot in atomically LAST, except a zero-item
        # PASSIVE response must not clobber a non-empty snapshot; then signal any
        # {.refresh} waiting on this id.
        #
        # @param handler [Handler]
        # @param snapshot [Snapshot]
        # @return [void]
        # @api private
        def commit(handler, snapshot)
          id = handler.manager_id
          @mutex.synchronize do
            mark_feed_present!
            solicited = @pending.key?(id)

            if snapshot.all.empty? && !solicited && @snapshot && !@snapshot.all.empty?
              log("Inventory: ignoring empty passive inventoryManager response (id=#{id})")
            else
              @snapshot = snapshot
            end

            deliver_locked(id, snapshot)
          end
        end

        # Handles an incomplete/continuation response: keep the prior snapshot and
        # fail a waiting {.refresh} for this id closed.
        #
        # @param handler [Handler]
        # @return [void]
        # @api private
        def reject(handler)
          log("Inventory: discarding incomplete/continuation inventoryManager response (id=#{handler.manager_id})")
          @mutex.synchronize { deliver_locked(handler.manager_id, FAILED) }
        end

        # Pushes a value to a pending refresh latch. Caller must hold {@mutex}.
        #
        # @param id [String, nil]
        # @param value [Snapshot, Object] a snapshot or the {FAILED} sentinel
        # @return [void]
        # @api private
        def deliver_locked(id, value)
          return if id.nil?

          latch = @pending[id]
          latch << value if latch
        end

        # Marks the feed present and resets absence/backoff bookkeeping.
        #
        # @return [void]
        # @api private
        def mark_feed_present!
          @feed_seen            = true
          @consecutive_timeouts = 0
          @feed_absent_until    = nil
          @absent_backoff       = PROBE_BACKOFF_BASE_SECONDS
        end

        # Whether {.refresh} may send a probe now: always once the feed has been
        # seen; otherwise only outside the feed-absent backoff window.
        #
        # @return [Boolean]
        # @api private
        def probe_allowed?
          return true if @feed_seen
          return true if @feed_absent_until.nil?

          monotonic_now >= @feed_absent_until
        end

        # Records a refresh timeout; after enough consecutive misses with no
        # response ever seen, marks the feed absent until a backoff deadline and
        # grows the backoff toward {PROBE_BACKOFF_MAX_SECONDS}.
        #
        # @return [void]
        # @api private
        def register_timeout!
          @consecutive_timeouts += 1
          return if @feed_seen
          return if @consecutive_timeouts < REFRESH_TIMEOUTS_BEFORE_ABSENT

          @feed_absent_until = monotonic_now + @absent_backoff
          @absent_backoff = [@absent_backoff * 2, PROBE_BACKOFF_MAX_SECONDS].min
        end

        # A Saga-style request id: "im" + base36 monotonic seconds + counter.
        #
        # @return [String]
        # @api private
        def generate_id
          @id_counter += 1
          "im#{monotonic_now.to_i.to_s(36)}#{@id_counter.to_s(36)}"
        end

        # @return [Float] a monotonic clock reading in seconds
        # @api private
        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        # Logs through {Lich} when available (a no-op in isolation).
        #
        # @param message [String]
        # @return [void]
        # @api private
        def log(message)
          Lich.log(message) if defined?(Lich) && Lich.respond_to?(:log)
        end
      end

      reset!
    end
  end
end

# Guarded top-level alias so scripts can say +Inventory+ without the full
# namespace, without clobbering a script that defines its own +Inventory+.
Inventory = Lich::Common::Inventory unless defined?(Inventory)
