# frozen_string_literal: true

require_relative 'map_base'

module Lich
  module Common
    # DragonRealms-specific Map implementation
    # Inherits shared functionality from MapBase
    class Map
      include Enumerable
      include MapBase

      @@loaded                   = false
      @@load_mutex               = Mutex.new
      @@list                   ||= []
      @@current_room_mutex       = Mutex.new
      @@current_room_id        ||= -1
      @@current_room_count     ||= -1
      @@fuzzy_room_mutex         = Mutex.new
      @@fuzzy_room_count       ||= -1
      @@current_location       ||= nil
      @@current_location_count ||= -1
      @@current_room_uid       ||= -1
      @@previous_room_id       ||= -1
      # The last two room resolutions, each [room_count, room id, live UID,
      # nav_count]. See {note_resolution} and {anchor_room}.
      @@resolution_mutex         = Mutex.new
      @@last_resolution        ||= nil
      @@prior_resolution       ||= nil
      @@uids                     = {}

      attr_reader :id
      attr_accessor :title, :description, :paths, :location, :climate, :terrain,
                    :wayto, :timeto, :image, :image_coords, :check_location,
                    :unique_loot, :uid, :room_objects,
                    :genie_id, :genie_zone, :genie_pos

      # @return [TagList] mutation-aware list of this room's tags
      attr_reader :tags

      def initialize(id, title, description, paths, uid = [], location = nil,
                     climate = nil, terrain = nil, wayto = {}, timeto = {},
                     image = nil, image_coords = nil, tags = [], check_location = nil,
                     unique_loot = nil, _room_objects = nil,
                     genie_id = nil, genie_zone = nil, genie_pos = nil)
        @id = id
        @title = title
        @description = description
        @paths = paths
        @uid = uid
        @location = location
        @climate = climate
        @terrain = terrain
        @wayto = wayto
        @timeto = timeto
        @image = image
        @image_coords = image_coords
        @tags = TagList.new(tags, self.class)
        @check_location = check_location
        @unique_loot = unique_loot
        @genie_id = genie_id
        @genie_zone = genie_zone
        @genie_pos = genie_pos
        @@list[@id] = self
        # Skipped during a bulk load: @@loaded is false throughout, load_json
        # clears the cache when it finishes, and any tag query while unloaded
        # goes through #list, which loads first. Saves one mutex per room.
        self.class.reset_tag_index if @@loaded
      end

      def to_s
        "##{@id} (#{@uid[-1]}):\n#{@title[-1]}\n#{@description[-1]}\n#{@paths[-1]}"
      end

      def json_extra_fields
        { genie_id: @genie_id, genie_zone: @genie_zone, genie_pos: @genie_pos }
      end

      # Class method accessors
      class << self
        # Accessors for the room-navigation state, matching GemStone, so the
        # shared MapBase implementations can reach it without touching class
        # variables directly.
        def current_room_id
          @@current_room_id
        end

        # Every resolution goes through here (set_current and set_fuzzy), so it
        # is also noted for {anchor_room}.
        def current_room_id=(id)
          note_resolution(id)
          @@current_room_id = id
        end

        def previous_room_id
          @@previous_room_id
        end

        def previous_room_id=(id)
          @@previous_room_id = id
        end

        def loaded?
          @@loaded
        end

        def list
          self.load unless @@loaded
          @@list
        end

        # The backing array without triggering a load. Only for use inside the
        # load path, where #list would re-enter the load mutex and deadlock.
        def raw_list
          @@list
        end

        def list=(value)
          @@list = value
          normalize_tag_lists(value)
        end

        def uids
          @@uids
        end

        def clear_tags_cache
          reset_tag_index
        end

        def mark_loaded
          @@loaded = true
        end

        def synchronize_load(&block)
          @@load_mutex.synchronize(&block)
        end
      end

      def self.by_genie_ref(zone_id, node_id)
        self.load unless @@loaded
        @@list.find { |r| r&.genie_zone == zone_id.to_s && r&.genie_id == node_id.to_s }
      end

      def self.previous
        @@list[@@previous_room_id]
      end

      # Remember which room the live display at the current room count resolved
      # to, the UID the game showed with it, and how many arrivals the game had
      # reported by then. A later resolution of the same display replaces the
      # record only with a room, never with nil: scriptless matching declines a
      # peer-tagged room that a script resolves.
      #
      # @param id [Integer, nil] the resolved room id
      # @return [void]
      def self.note_resolution(id)
        count = XMLData.room_count
        record = [count, id, XMLData.room_id.to_i, XMLData.nav_count]
        @@resolution_mutex.synchronize do
          if @@last_resolution && @@last_resolution[0] == count
            @@last_resolution = record unless id.nil?
          else
            @@prior_resolution = @@last_resolution
            @@last_resolution = record
          end
        end
      end

      # Forget the noted resolutions, so no room carries over as an anchor.
      #
      # @return [void]
      def self.reset_resolutions
        @@resolution_mutex.synchronize do
          @@last_resolution = nil
          @@prior_resolution = nil
        end
      end

      # The newest noted resolution made for a room count before the live one.
      # A resolution of the live display itself is never returned: it would make
      # the room its own anchor.
      #
      # @return [Array, nil] [room_count, room id, live UID, nav_count]
      def self.earlier_resolution
        count = XMLData.room_count
        records = @@resolution_mutex.synchronize { [@@last_resolution, @@prior_resolution] }
        records.find do |record|
          record && record[0].is_a?(Integer) && count.is_a?(Integer) && record[0] < count
        end
      end

      def self.current
        self.load unless @@loaded
        if Script.current
          return @@list[@@current_room_id] if XMLData.room_count == @@current_room_count && !@@current_room_id.nil?
        elsif XMLData.room_count == @@fuzzy_room_count && !@@current_room_id.nil?
          return @@list[@@current_room_id]
        end
        ids = XMLData.room_id.zero? ? [] : ids_from_uid(XMLData.room_id)
        return set_current(ids[0]) if ids.size == 1

        if ids.size > 1 && !@@current_room_id.nil? && (id = match_multi_ids(ids))
          return set_current(id)
        end
        match_no_uid
      end

      # Pattern for the live exits line when fog hides the exits. The exits
      # cannot be compared in that state, so text matching uses the title and
      # description alone.
      FOG_EXITS_PATTERN = /^Obvious (?:exits|paths): obscured by a thick fog$/

      # Pattern identifying a room whose disambiguation depends on a manual
      # +peer+ action (for example peering through a doorway to read an adjacent
      # room before committing to a match). Such rooms cannot be told apart
      # without a running script to perform the peer, so scriptless fuzzy
      # matching declines to resolve them. Kept verbatim from the historical
      # inline checks in {match_fuzzy}.
      PEER_TAG_PATTERN = /^(set desc on; )?peer [a-z]+ =~ \/.+\/$/

      # Whether +room+ carries a peer-disambiguation tag (see {PEER_TAG_PATTERN}).
      #
      # @param room [Lich::Common::Map] a room already matched on
      #   title/description/paths
      # @return [Boolean] +true+ when the room requires a manual peer to
      #   disambiguate, +false+ otherwise
      def self.peer_disambiguation_tag?(room)
        room.tags.any? { |tag| tag =~ PEER_TAG_PATTERN }
      end

      # The UIDs stored on +room+ that can identify it. A stored 0 is not a UID:
      # the parser reads 0 for a room the game shows without one (a bare
      # <nav/>), and {ids_from_uid} and {current} already treat it as none.
      #
      # @param room [Lich::Common::Map]
      # @return [Array<Integer>]
      def self.stored_uids(room)
        Array(room.uid) - [0]
      end

      # Whether the live game UID rules +room+ out: the game reports a UID and
      # the room stores UIDs, none of which is the live one.
      #
      # @param room [Lich::Common::Map]
      # @return [Boolean]
      def self.uid_vetoes?(room)
        return false if XMLData.room_id.zero?

        uids = stored_uids(room)
        uids.any? && !uids.include?(XMLData.room_id)
      end

      # Resolve a room that already matched on title/description/paths down to a
      # final room id, applying UID disambiguation.
      #
      # The governing invariant is that *a stored UID must never make a room less
      # resolvable than an otherwise identical room with no UID.*
      #
      # * When the game exposes a live UID (+XMLData.room_id+ is non-zero) and the
      #   matched room carries one or more UIDs, the match only stands if the live
      #   UID is among them (see {uid_vetoes?}). A stored UID of 0 counts as no
      #   UID (see {stored_uids}).
      # * When the game exposes *no* UID (+XMLData.room_id+ is zero), UID
      #   disambiguation is skipped and the title/description/paths match is
      #   trusted regardless of any UID stored on the room, so a UID stamped onto
      #   a room the game shows without one cannot make it unresolvable.
      #
      # @param room [Lich::Common::Map] the room matched on title/description/paths
      # @param honor_peer_tags [Boolean] when +true+, a room requiring a manual
      #   peer to disambiguate (see {peer_disambiguation_tag?}) resolves to +nil+
      #   unless the live UID confirms it; used by scriptless fuzzy matching,
      #   which cannot perform the peer. Exact ({match_current}) matching passes
      #   +false+ and never consults peer tags.
      # @return [Integer, nil] the resolved room id; +nil+ when the live UID
      #   vetoes the room, or when a peer-tagged room cannot be disambiguated
      def self.resolve_matched_room(room, honor_peer_tags:)
        return nil if uid_vetoes?(room)
        return room.id if !XMLData.room_id.zero? && stored_uids(room).any?
        return nil if honor_peer_tags && peer_disambiguation_tag?(room)

        room.id
      end

      # Every room whose title, description and exits all match the live room.
      # Under fog the live exits line carries no exits, so title and description
      # alone must match. The description is compared whole.
      #
      # @param rooms [Array<Lich::Common::Map>] rooms already matching the live
      #   title and exits (see {rooms_matching_live_title_and_exits})
      # @return [Array<Lich::Common::Map>] the matching rooms, in id order
      def self.text_candidates(rooms = rooms_matching_live_title_and_exits)
        description = XMLData.room_description.to_s.strip
        rooms.select { |r| Array(r.description).include?(description) }
      end

      # Fewest words a live description sentence needs to identify a room in
      # {tolerant_text_candidates}. Shorter fragments (a closing quote mark, an
      # abbreviation cut at its period, a two-word aside) occur in many stored
      # descriptions and say nothing about which room this is.
      TOLERANT_SENTENCE_MIN_WORDS = 4

      # The sentences of a live description that {tolerant_text_candidates}
      # looks for: split at each run of periods, stripped, keeping only those of
      # at least {TOLERANT_SENTENCE_MIN_WORDS} words. An empty description has
      # none.
      #
      # @param description [String, nil]
      # @return [Array<String>]
      def self.description_sentences(description)
        description.to_s.split(/\.+/).map(&:strip).select do |sentence|
          sentence.split.size >= TOLERANT_SENTENCE_MIN_WORDS
        end
      end

      # Every room whose title and exits match the live room exactly (title
      # alone under fog) and one of whose stored descriptions contains, word for
      # word, at least one sentence of the live description (see
      # {description_sentences}). This tolerates a description that has drifted
      # from the map: a typo fixed in one sentence, a sentence rewritten, a
      # day/night variant the map lacks. A live description with no usable
      # sentence, an empty one included, matches nothing.
      #
      # @param rooms [Array<Lich::Common::Map>] rooms already matching the live
      #   title and exits (see {rooms_matching_live_title_and_exits})
      # @return [Array<Lich::Common::Map>] the matching rooms, in id order
      def self.tolerant_text_candidates(rooms = rooms_matching_live_title_and_exits)
        sentences = description_sentences(XMLData.room_description)
        return [] if sentences.empty?

        rooms.select do |r|
          Array(r.description).any? { |stored| sentences.any? { |sentence| stored.to_s.include?(sentence) } }
        end
      end

      # The rooms that can be the live room by their text: those matching it
      # exactly (see {text_candidates}), or, only when no room does, those whose
      # description merely shares a sentence with it (see
      # {tolerant_text_candidates}). The tolerant rooms are never mixed with an
      # exact match, even an ambiguous or vetoed one.
      #
      # @return [Array<Lich::Common::Map>]
      def self.live_text_candidates
        rooms = rooms_matching_live_title_and_exits
        candidates = text_candidates(rooms)
        candidates.empty? ? tolerant_text_candidates(rooms) : candidates
      end

      # Every room whose title and exits match the live room, ignoring the
      # exits under fog. The map is scanned once for both description passes.
      # A room missing its title or exits (the map has a few) is skipped
      # without relying on Lich's NilClass patch.
      #
      # @return [Array<Lich::Common::Map>] the matching rooms, in id order
      def self.rooms_matching_live_title_and_exits
        title = XMLData.room_title
        exits = XMLData.room_exits_string.to_s
        foggy = exits.match?(FOG_EXITS_PATTERN)
        exits = exits.strip
        @@list.select do |r|
          # Skip nil holes without relying on Lich's NilClass patch.
          r &&
            Array(r.title).include?(title) &&
            (foggy || Array(r.paths).include?(exits))
        end
      end

      # The room the character was in before the live display, to judge which
      # of several identical rooms it can have reached.
      #
      # DR resolves a room only on demand, so the last resolved room can be
      # several moves old (go2 walks its whole path without asking) or can be
      # the live room itself (resolved a moment ago for the same display). The
      # game's own record of the room it left comes first: the UID of the
      # previous <nav>, when exactly one room has it. Otherwise the room
      # resolved for an earlier display is used, but only when it was resolved
      # in the room just left (one arrival ago, and shown with the UID the game
      # says that room had) or in the live room before any further arrival
      # (shown with the live UID). An older resolution is never used. Before
      # the first <nav> there is no previous room to check against, so no
      # earlier resolution is trusted.
      #
      # @return [Lich::Common::Map, nil] the anchor room, or +nil+ when none can
      #   be trusted
      def self.anchor_room
        previous_uid = XMLData.previous_nav_rm
        ids = previous_uid.to_i.positive? ? ids_from_uid(previous_uid.to_i) : []
        return @@list[ids.first] if ids.size == 1

        return nil if previous_uid.nil?

        _count, id, uid, nav = earlier_resolution
        return nil unless id.is_a?(Integer) && id >= 0 && nav.is_a?(Integer)

        arrivals = XMLData.nav_count.to_i - nav
        return @@list[id] if arrivals == 1 && uid == previous_uid.to_i
        return @@list[id] if arrivals.zero? && uid == XMLData.room_id.to_i

        nil
      end

      # Whether the game's own UIDs show the character has left +room+: the
      # previous <nav> carried a UID that +room+ stores, and the live room shows
      # another UID, or none, that +room+ does not store.
      #
      # @param room [Lich::Common::Map]
      # @return [Boolean]
      def self.left_room?(room)
        previous_uid = XMLData.previous_nav_rm.to_i
        live_uid = XMLData.room_id.to_i
        return false unless previous_uid.positive? && previous_uid != live_uid

        uids = stored_uids(room)
        uids.include?(previous_uid) && !uids.include?(live_uid)
      end

      # Of +candidates+, the single one the character can be standing in after
      # leaving the anchor room (see {anchor_room}): a room it has a wayto to,
      # or the anchor itself. The anchor counts because a fresh room display
      # does not always mean a move, so an identical neighbour must not win over
      # it; but not when the game's UIDs show the character has left it (see
      # {left_room?}), so an identical room just left is never taken for the
      # live one.
      #
      # @param candidates [Array<Lich::Common::Map>]
      # @return [Lich::Common::Map, nil] the one reachable candidate; +nil+ with
      #   no anchor room, or when none or several are reachable
      def self.adjacent_candidate(candidates)
        from = anchor_room
        return nil if from.nil?

        stayed = !left_room?(from)
        wayto = from.wayto || {}
        reachable = candidates.select { |r| (stayed && r.id == from.id) || wayto.key?(r.id.to_s) }
        reachable.size == 1 ? reachable.first : nil
      end

      # Pick the live room from the rooms matching its text.
      #
      # Every candidate the live UID vetoes is dropped. A lone survivor is the
      # room. Otherwise the room resolves only when exactly one candidate is
      # reachable from the anchor room (see {adjacent_candidate}) and
      # that candidate survived the veto; in every other case it is unresolved
      # rather than the first of them.
      #
      # When the veto dropped any candidate, reachability is judged over all the
      # candidates, vetoed ones included, and even a lone survivor must be the
      # one reachable. The game's UID then belongs to no candidate, so the live
      # room may be the vetoed room under a UID the map lacks: a look-alike copy
      # elsewhere in the map, or one sharing the vetoed room's neighbours, is not
      # taken for it.
      #
      # @param candidates [Array<Lich::Common::Map>] rooms matching the live text
      # @return [Lich::Common::Map, nil]
      def self.pick_text_candidate(candidates)
        survivors = candidates.reject { |r| uid_vetoes?(r) }
        return survivors.first if survivors.size == 1 && survivors.size == candidates.size

        room = adjacent_candidate(candidates)
        survivors.include?(room) ? room : nil
      end

      # Resolve the live room from its title, description and exits (see
      # {live_text_candidates}).
      #
      # @param honor_peer_tags [Boolean] see {resolve_matched_room}
      # @return [Integer, nil] the resolved room id, or +nil+ when no room, or
      #   more than one, can be the live room
      def self.match_live_text(honor_peer_tags:)
        room = pick_text_candidate(live_text_candidates)
        return nil if room.nil?

        resolve_matched_room(room, honor_peer_tags: honor_peer_tags)
      end

      # Resolve the current room by title/description/paths matching.
      #
      # Used when a script is running (see {match_no_uid}). Re-reads the room
      # whenever the live +room_count+ changes mid-match. See
      # {match_live_text}; peer tags are not honored on this path.
      #
      # @param _script [Object] the running script (unused; retained for the
      #   historical call signature)
      # @return [Integer, nil] the resolved room id, or +nil+ when no single
      #   room matches
      def self.match_current(_script)
        @@current_room_mutex.synchronize do
          loop do
            @@current_room_count = XMLData.room_count
            id = match_live_text(honor_peer_tags: false)
            return id if @@current_room_count == XMLData.room_count
          end
        end
      end

      # Resolve the current room by title/description/paths matching without a
      # script.
      #
      # Used when no script is running (see {match_no_uid}). Mirrors
      # {match_current} but honors peer-disambiguation tags: a room that would
      # need a manual peer to tell apart cannot be resolved without a script, so
      # it yields +nil+.
      #
      # @return [Integer, nil] the resolved room id, or +nil+ when no single
      #   room matches or the room needs a peer
      def self.match_fuzzy
        @@fuzzy_room_mutex.synchronize do
          loop do
            @@fuzzy_room_count = XMLData.room_count
            id = match_live_text(honor_peer_tags: true)
            return id if @@fuzzy_room_count == XMLData.room_count
          end
        end
      end

      def self.current_or_new
        return nil unless Script.current

        @@current_room_count = -1
        @@fuzzy_room_count = -1

        self.load unless @@loaded

        id = current&.id

        echo("Map: current room id is #{id.inspect}")
        unless id.nil?
          room = self[id]
          unless XMLData.room_id.zero? || room.uid.include?(XMLData.room_id)
            room.uid << XMLData.room_id
            uids_add(XMLData.room_id, room.id)
            echo "Map: Adding new uid for #{room.id}: #{XMLData.room_id}"
          end
          return set_current(room.id)
        end

        # Guard against a blank/incomplete arrival frame. DR occasionally streams a room whose
        # <nav> UID is delayed or absent (room_id 0) before the room text populates: the
        # description is only the "pitch dark" placeholder and there are no exits. Minting a
        # room here creates a junk stub (empty title, no UID) that orphans or duplicates the
        # real room. Keep the current room instead; the real room resolves by UID once the
        # delayed nav (or a re-look) provides it.
        if XMLData.room_id.zero? &&
           XMLData.room_exits_string.to_s.strip.empty? &&
           XMLData.room_description.to_s.strip == "It's pitch dark and you can't see a thing!"
          echo 'Map: skipped blank/incomplete room frame (no uid, pitch-dark, no exits)'
          # Keep the current room - but only if one has actually resolved.
          # @@current_room_id is the -1 sentinel before the first match; passing
          # that to set_current would index @@list[-1] (the last room) and make an
          # unrelated room current, so fall back to nil in that case instead.
          return set_current(@@current_room_id) if @@current_room_id.is_a?(Integer) && @@current_room_id >= 0

          return nil
        end

        # Several rooms fit the live text and none could be told apart from the
        # room before it. The room may be one of them or a new one; mapping it
        # as new keeps identical rooms with no UID mappable, so say so.
        twins = live_text_candidates.size
        if twins > 1
          echo "Map: #{twins} mapped rooms match this room and none can be told apart from the room before it; mapping it as a new room"
        end

        id = get_free_id
        title = [XMLData.room_title]
        description = [XMLData.room_description.strip]
        paths = [XMLData.room_exits_string.strip]
        uid = XMLData.room_id.zero? ? [] : [XMLData.room_id]
        room = new(id, title, description, paths, uid)
        uids_add(XMLData.room_id, room.id) unless XMLData.room_id.zero?
        echo "mapped new room, set current room to #{room.id}"
        set_current(id)
      end

      def self.load_uids
        self.load unless @@loaded
        @@uids.clear
        # compact rather than relying on Lich's NilClass patch to make r.uid on a
        # hole return nil; a sparse map should not need that to load.
        @@list.compact.each do |r|
          r.uid.each do |u|
            if @@uids[u].nil?
              @@uids[u] = [r.id]
            elsif !@@uids[u].include?(r.id)
              @@uids[u] << r.id
            end
          end
        end
      end

      def self.ids_from_uid(n)
        @@uids[n].nil? || n.zero? ? [] : @@uids[n]
      end

      def self.clear
        @@load_mutex.synchronize do
          @@list.clear
          clear_tags_cache
          reset_resolutions
          @@loaded = false
          GC.start
        end
        true
      end

      # Construct a room from a parsed JSON hash
      # @param room [Hash]
      # @return [Map] the registered room
      def self.room_from_json(room)
        new(
          room['id'], room['title'], room['description'], room['paths'],
          room['uid'], room['location'], room['climate'], room['terrain'],
          room['wayto'], room['timeto'], room['image'], room['image_coords'],
          room['tags'], room['check_location'], room['unique_loot'],
          nil, # _room_objects
          room['genie_id'], room['genie_zone'], room['genie_pos']
        )
      end
    end

    class Room < Map
    end
  end
end
