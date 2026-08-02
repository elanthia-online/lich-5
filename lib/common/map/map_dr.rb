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
      @@uids                     = {}

      attr_reader :id
      attr_accessor :title, :description, :paths, :location, :climate, :terrain,
                    :wayto, :timeto, :image, :image_coords, :check_location,
                    :unique_loot, :uid, :room_objects,
                    :genie_id, :genie_zone, :genie_pos

      # @return [TagList] mutation-aware list of this room's tags
      attr_reader :tags

      # Replace this room's tags and drop the tag index
      # @param value [Array, nil] new tag names
      # @return [Array, nil] the assigned value, per Ruby writer semantics
      def tags=(value)
        @tags = TagList.new(value, self.class)
        self.class.reset_tag_index
      end

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
        self.class.reset_tag_index
      end

      def to_s
        "##{@id} (#{@uid[-1]}):\n#{@title[-1]}\n#{@description[-1]}\n#{@paths[-1]}"
      end

      def json_extra_fields
        { genie_id: @genie_id, genie_zone: @genie_zone, genie_pos: @genie_pos }
      end

      # Class method accessors
      class << self
        def loaded?
          @@loaded
        end

        def list
          self.load unless @@loaded
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

      def self.get_free_id
        self.load unless @@loaded
        @@list.compact.max_by(&:id).id + 1
      end

      def self.previous
        @@list[@@previous_room_id]
      end

      def self.previous_uid
        XMLData.previous_nav_rm
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

      def self.match_no_uid
        if (script = Script.current)
          set_current(match_current(script))
        else
          set_fuzzy(match_fuzzy)
        end
      end

      def self.set_fuzzy(id)
        @@previous_room_id = @@current_room_id if !id.nil? && id != @@current_room_id
        @@current_room_id = id
        return nil if id.nil?

        @@list[id]
      end

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

      # Resolve a room that already matched on title/description/paths down to a
      # final room id, applying UID disambiguation.
      #
      # The governing invariant is that *a stored UID must never make a room less
      # resolvable than an otherwise identical room with no UID.*
      #
      # * When the game exposes a live UID (+XMLData.room_id+ is non-zero) and the
      #   matched room carries one or more UIDs, the match only stands if the live
      #   UID is among them. This is what keeps distinct rooms that share a
      #   title/description/paths (day/night variants, look-alike maze cells) from
      #   collapsing onto one another.
      # * When the game exposes *no* UID (+XMLData.room_id+ is zero, a room the
      #   server does not surface a UID for), UID disambiguation is skipped and the
      #   title/description/paths match is trusted regardless of any UID stored on
      #   the room. Previously such a room returned +nil+ here (a stored UID can
      #   never include the zero live id), so a UID accidentally or provisionally
      #   stamped onto a no-UID room made that room permanently unresolvable
      #   (+Map.current+ became +nil+). Trusting the text match in the no-UID case
      #   removes that failure mode without weakening disambiguation when the game
      #   does expose a UID.
      #
      # @param room [Lich::Common::Map] the room matched on title/description/paths
      # @param honor_peer_tags [Boolean] when +true+, a room requiring a manual
      #   peer to disambiguate (see {peer_disambiguation_tag?}) resolves to +nil+;
      #   used by scriptless fuzzy matching, which cannot perform the peer. Exact
      #   ({match_current}) matching passes +false+ and never consults peer tags.
      # @return [Integer, nil] the resolved room id; +nil+ when a UID'd room's
      #   stored UIDs exclude the live game UID, or when a peer-tagged room cannot
      #   be disambiguated
      def self.resolve_matched_room(room, honor_peer_tags:)
        if room.uid.any? && !XMLData.room_id.zero?
          return room.uid.include?(XMLData.room_id) ? room.id : nil
        end
        return nil if honor_peer_tags && peer_disambiguation_tag?(room)

        room.id
      end

      # Resolve the current room by exact title/description/paths matching.
      #
      # Used when a script is running (see {match_no_uid}). Tries an exact
      # description match first, then a punctuation-tolerant regex description
      # match, re-reading the room whenever the live +room_count+ changes
      # mid-match. Final UID disambiguation is delegated to
      # {resolve_matched_room} (peer tags are not honored on this path).
      #
      # @param _script [Object] the running script (unused; retained for the
      #   historical call signature)
      # @return [Integer, nil] the resolved room id, or +nil+ when nothing matches
      #   or UID disambiguation rejects the match
      def self.match_current(_script)
        @@current_room_mutex.synchronize do
          need_set_desc_off = false
          begin
            loop do
              @@current_room_count = XMLData.room_count
              foggy_exits = XMLData.room_exits_string =~ /^Obvious (?:exits|paths): obscured by a thick fog$/
              room = @@list.find do |r|
                r.title.include?(XMLData.room_title) &&
                  r.description.include?(XMLData.room_description.strip) &&
                  (foggy_exits || r.paths.include?(XMLData.room_exits_string.strip))
              end

              if room
                redo unless @@current_room_count == XMLData.room_count
                return resolve_matched_room(room, honor_peer_tags: false)
              else
                redo unless @@current_room_count == XMLData.room_count
                desc_regex = /#{Regexp.escape(XMLData.room_description.strip.sub(/\.+$/, '')).gsub(/\\\.(?:\\\.\\\.)?/, '|')}/
                room = @@list.find do |r|
                  r.title.include?(XMLData.room_title) &&
                    (foggy_exits || r.paths.include?(XMLData.room_exits_string.strip)) &&
                    (XMLData.room_window_disabled || r.description.any? { |desc| desc =~ desc_regex })
                end

                if room
                  redo unless @@current_room_count == XMLData.room_count
                  return resolve_matched_room(room, honor_peer_tags: false)
                else
                  redo unless @@current_room_count == XMLData.room_count
                  return nil
                end
              end
            end
          ensure
            put 'set description off' if need_set_desc_off
          end
        end
      end

      # Resolve the current room by fuzzy title/description/paths matching.
      #
      # Used when no script is running (see {match_no_uid}). Mirrors
      # {match_current} but honors peer-disambiguation tags: a room that would
      # need a manual peer to tell apart cannot be resolved without a script, so
      # it yields +nil+. Final UID disambiguation is delegated to
      # {resolve_matched_room} with +honor_peer_tags: true+.
      #
      # @return [Integer, nil] the resolved room id, or +nil+ when nothing
      #   matches, UID disambiguation rejects the match, or the room needs a peer
      def self.match_fuzzy
        @@fuzzy_room_mutex.synchronize do
          @@fuzzy_room_count = XMLData.room_count
          loop do
            foggy_exits = XMLData.room_exits_string =~ /^Obvious (?:exits|paths): obscured by a thick fog$/
            room = @@list.find do |r|
              r.title.include?(XMLData.room_title) &&
                r.description.include?(XMLData.room_description.strip) &&
                (foggy_exits || r.paths.include?(XMLData.room_exits_string.strip))
            end

            if room
              redo unless @@fuzzy_room_count == XMLData.room_count

              return resolve_matched_room(room, honor_peer_tags: true)
            else
              redo unless @@fuzzy_room_count == XMLData.room_count
              desc_regex = /#{Regexp.escape(XMLData.room_description.strip.sub(/\.+$/, '')).gsub(/\\\.(?:\\\.\\\.)?/, '|')}/
              room = @@list.find do |r|
                r.title.include?(XMLData.room_title) &&
                  (foggy_exits || r.paths.include?(XMLData.room_exits_string.strip)) &&
                  (XMLData.room_window_disabled || r.description.any? { |desc| desc =~ desc_regex })
              end

              if room
                redo unless @@fuzzy_room_count == XMLData.room_count

                return resolve_matched_room(room, honor_peer_tags: true)
              else
                redo unless @@fuzzy_room_count == XMLData.room_count
                return nil
              end
            end
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

      def self.set_current(id)
        @@previous_room_id = @@current_room_id if id != @@current_room_id
        @@current_room_id = id
        return nil if id.nil?

        @@list[id]
      end

      def self.match_multi_ids(ids)
        matches = ids.find_all { |s| @@list[@@current_room_id].wayto.keys.include?(s.to_s) }
        return matches[0] if matches.size == 1

        nil
      end

      def self.load_uids
        self.load unless @@loaded
        @@uids.clear
        @@list.each do |r|
          r.uid.each do |u|
            if @@uids[u].nil?
              @@uids[u] = [r.id]
            elsif !@@uids[u].include?(r.id)
              @@uids[u] << r.id
            end
          end
        end
      end

      def self.tags
        self.load unless @@loaded
        tag_names
      end

      def self.ids_from_uid(n)
        @@uids[n].nil? || n.zero? ? [] : @@uids[n]
      end

      def self.clear
        @@load_mutex.synchronize do
          @@list.clear
          clear_tags_cache
          @@loaded = false
          GC.start
        end
        true
      end

      def self.load_json(filename = nil)
        @@load_mutex.synchronize do
          return true if @@loaded

          file_list = if filename
                        [filename]
                      else
                        Dir.entries(File.join(DATA_DIR, XMLData.game))
                           .find_all { |fn| fn =~ /^map-[0-9]+\.json$/i }
                           .collect { |fn| File.join(DATA_DIR, XMLData.game, fn) }
                           .sort
                           .reverse
                      end

          if file_list.empty?
            respond '--- Lich: error: no map database found'
            return false
          end

          while (filename = file_list.shift)
            next unless File.exist?(filename)

            File.open(filename) do |f|
              JSON.parse(f.read).each do |room|
                room['wayto'].keys.each do |k|
                  if room['wayto'][k][0..2] == ';e '
                    room['wayto'][k] = StringProc.new(room['wayto'][k][3..])
                  end
                end
                room['timeto'].keys.each do |k|
                  if room['timeto'][k].is_a?(String) && room['timeto'][k][0..2] == ';e '
                    room['timeto'][k] = StringProc.new(room['timeto'][k][3..])
                  end
                end
                room['tags'] ||= []
                room['uid'] ||= []
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
            clear_tags_cache
            respond "--- Map loaded #{filename}"
            @@loaded = true
            load_uids
            return true
          end
        end
      end
    end

    class Room < Map
      def self.method_missing(*args)
        super
      end

      def self.respond_to_missing?(*args)
        super
      end
    end
  end
end
