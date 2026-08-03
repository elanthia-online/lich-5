# frozen_string_literal: true

# Common map functionality shared between GemStone and DragonRealms
# This module provides the core pathfinding, file I/O, and room management
# functionality that is identical across games.

module Lich
  module Common
    CORE_MAP_OVERRIDES = true

    # MinHeap for efficient Dijkstra priority queue
    # Extracted to be shared across all game implementations
    class MinHeap
      def initialize
        @heap = []
      end

      def push(priority, value)
        @heap << [priority, value]
        bubble_up(@heap.size - 1)
      end

      def pop
        return nil if @heap.empty?

        swap(0, @heap.size - 1)
        min = @heap.pop
        bubble_down(0) unless @heap.empty?
        min
      end

      def empty?
        @heap.empty?
      end

      private

      def bubble_up(index)
        while index.positive?
          parent_index = (index - 1) / 2
          break if @heap[index][0] >= @heap[parent_index][0]

          swap(index, parent_index)
          index = parent_index
        end
      end

      def bubble_down(index)
        loop do
          left_child = (2 * index) + 1
          right_child = (2 * index) + 2
          break if left_child >= @heap.size

          min_child = if right_child >= @heap.size || @heap[left_child][0] < @heap[right_child][0]
                        left_child
                      else
                        right_child
                      end

          break if @heap[index][0] <= @heap[min_child][0]

          swap(index, min_child)
          index = min_child
        end
      end

      def swap(i, j)
        @heap[i], @heap[j] = @heap[j], @heap[i]
      end
    end

    # An Array of tag names that tells its owning Map class to drop the tag
    # index whenever the list is structurally mutated. Stored names are frozen
    # copies, so renaming a tag in place raises rather than silently leaving the
    # index describing the old name. Reads are plain Array reads with no added
    # indirection.
    class TagList < Array
      # Array mutators that do not end in a bang. This is a closed set, unlike
      # the bang methods, which are derived below so that a mutator added by a
      # future Ruby is covered without editing this list.
      NON_BANG_MUTATORS = %i[
        << []= append clear concat delete delete_at delete_if fill insert
        keep_if pop prepend push replace shift unshift
      ].freeze

      # Every Array method that changes the receiver's contents.
      MUTATORS = (
        Array.public_instance_methods(false).select { |name| name.to_s.end_with?('!') } +
        NON_BANG_MUTATORS
      ).uniq.freeze

      # Array's own writer, used to replace entries without re-entering the
      # interceptor. Held unbound so nothing is allocated per mutation.
      ARRAY_WRITER = Array.instance_method(:[]=)
      private_constant :ARRAY_WRITER

      # @param contents [Array, nil] initial tag names
      # @param owner [Class, nil] Map class notified on mutation
      def initialize(contents = nil, owner = nil)
        super()
        # Order matters: concat is an intercepted mutator, so the initial fill
        # has to happen while @owner is still nil. Construction must not
        # invalidate the index, or a full map load would fire once per room.
        concat(contents.to_a) unless contents.nil?
        @owner = owner
      end

      MUTATORS.each do |name|
        define_method(name) do |*args, &block|
          result = super(*args, &block)
          freeze_contents
          @owner.reset_tag_index if @owner.respond_to?(:reset_tag_index)
          result
        end
      end

      private

      # Replace any unfrozen name with a frozen copy. Without this a caller
      # could do tags.first.replace('bank'), which changes the tag without
      # touching the list and so never reaches the interceptor above. Copies
      # rather than freezing in place, so the caller's own strings are left
      # alone. Uses Array's writer directly to avoid re-entering the
      # interceptor.
      # @return [nil]
      def freeze_contents
        each_with_index do |tag, index|
          next unless tag.is_a?(String) && !tag.frozen?

          ARRAY_WRITER.bind_call(self, index, tag.dup.freeze)
        end
        nil
      end
    end

    # Base module containing shared map functionality
    # Include this in game-specific Map classes
    module MapBase
      def self.included(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
        # The tag cache lives on class-instance variables, which subclasses do
        # not share. Room subclasses Map and inherits these class methods, so
        # without a single owner a query through Room would memoize a second
        # cache that Map's invalidations never reach. Mark the includer as owner
        # and resolve to it from any subclass, see #tag_cache_host.
        base.instance_variable_set(:@tag_cache_owner, true)
      end

      # Class methods shared across all Map implementations
      module ClassMethods
        # Get the next available room ID
        # @return [Integer] one past the highest room id in use, or 1 when the
        #   map holds no rooms
        def get_free_id
          rooms = list.compact
          # An empty map yields 1, which is what nil.id + 1 produced via Lich's
          # NilClass patch. Stating it means this no longer depends on that.
          return 1 if rooms.empty?

          rooms.max_by(&:id).id + 1
        end

        # Tag names present anywhere in the room list
        # @return [Array<String>]
        def tags
          tag_names
        end

        # The uid the game last navigated away from
        # @return [Integer, nil]
        def previous_uid
          XMLData.previous_nav_rm
        end

        # Resolve the current room when the game gave no usable uid. Delegates to
        # the game-specific matchers.
        # @return [Object, nil] the resolved room
        def match_no_uid
          if (script = Script.current)
            set_current(match_current(script))
          else
            set_fuzzy(match_fuzzy)
          end
        end

        # Narrow a set of candidate ids to the one reachable from the current room
        # @param ids [Array] candidate room ids
        # @return [Integer, nil] the single reachable id, or nil unless exactly
        #   one candidate is reachable from the current room
        def match_multi_ids(ids)
          matches = ids.find_all { |s| list[current_room_id].wayto.keys.include?(s.to_s) }
          return matches[0] if matches.size == 1

          nil
        end

        # Record the room the game moved to, remembering the one it left
        # @param id [Integer, nil] the new current room id
        # @return [Object, nil] the room, or nil when given nil
        def set_current(id)
          self.previous_room_id = current_room_id if id != current_room_id
          self.current_room_id = id
          return nil if id.nil?

          list[id]
        end

        # As #set_current, but a nil id leaves the previous room untouched
        # @param id [Integer, nil] the fuzzily matched room id
        # @return [Object, nil] the room, or nil when given nil
        def set_fuzzy(id)
          self.previous_room_id = current_room_id if !id.nil? && id != current_room_id
          self.current_room_id = id
          return nil if id.nil?

          list[id]
        end

        # Estimate total travel time for a path
        # @param array [Array<Integer>] Array of room IDs representing the path
        # @return [Float] Total estimated time in seconds
        def estimate_time(array)
          self.load unless loaded?
          unless array.is_a?(Array)
            raise Exception.exception('MapError'), 'Map.estimate_time was given something not an array!'
          end

          time = 0.0
          until array.length < 2
            room = array.shift
            t = self[room].timeto[array.first.to_s]
            if t
              time += t.is_a?(StringProc) ? t.call.to_f : t.to_f
            else
              time += 0.2
            end
          end
          time
        end

        # Tag name => Array of room ids. Private: callers must go through
        # #rooms_by_tag or #tag_names so the memo cannot be mutated in place.
        #
        # Rebuild attempts before giving up on caching the result.
        TAG_INDEX_BUILD_ATTEMPTS = 3

        # Serialises publishing the memo against invalidating it. Only ever held
        # across a couple of assignments, never across a build or a load, so it
        # cannot invert the ordering against the load mutex.
        TAG_INDEX_MUTEX = Mutex.new

        # The single class that owns the tag cache. Map is the owner; Room, which
        # subclasses it, resolves to Map so both see one cache.
        # @return [Class]
        def tag_cache_host
          @tag_cache_host ||= begin
            klass = self
            klass = klass.superclass until klass.instance_variable_defined?(:@tag_cache_owner)
            klass
          end
        end

        # @return [Hash{String => Array<Integer>}] tag name => room ids
        def tag_index
          # No explicit load here: build_tag_index reads through #list, which
          # loads when needed. Loading here as well made a single Map.tags call
          # attempt the load twice, doubling the failure message.
          host = tag_cache_host
          TAG_INDEX_BUILD_ATTEMPTS.times do
            cached = host.instance_variable_get(:@tag_index)
            return cached unless cached.nil?

            # Build outside the mutex. build_tag_index reads through #list, which
            # can take the load mutex, and taking the two in that order here
            # would invert the ordering every other path uses.
            generation = tag_index_generation
            built = build_tag_index

            published = TAG_INDEX_MUTEX.synchronize do
              # Validate and publish as one step, and never publish a value that
              # failed validation. Publishing first and undoing afterwards would
              # let another reader take the cached fast path and consume the
              # stale index before the undo landed.
              next false unless generation == tag_index_generation

              host.instance_variable_set(:@tag_index, built)
              true
            end
            return built if published
          end
          # Tags are changing faster than the index can settle. Answer from this
          # build without caching it. It reflects a recent state, not necessarily
          # the current one.
          build_tag_index
        end

        # @return [Integer]
        def tag_index_generation
          tag_cache_host.instance_variable_get(:@tag_index_generation) || 0
        end

        # @return [Hash{String => Array<Integer>}]
        def build_tag_index
          index = {}
          list.compact.each do |room|
            room.tags.each { |tag| (index[tag] ||= []) << room.id }
          end
          index
        end

        private :tag_index, :tag_index_generation, :build_tag_index, :tag_cache_host

        # Load the newest usable JSON map database, falling back to older
        # candidates when one is unreadable. The two game classes differ only in
        # how a parsed room is constructed and what they announce, so those are
        # hooks: #room_from_json and #map_loaded_message.
        # @param filename [String, nil] a specific database, or nil to search
        # @return [Boolean] true once a database loaded
        def load_json(filename = nil)
          synchronize_load do
            return true if loaded?

            file_list = filename ? [filename] : json_map_files
            if file_list.empty?
              respond '--- Lich: error: no map database found'
              return false
            end

            while (filename = file_list.shift)
              next unless File.exist?(filename)
              next unless parse_map_json(filename)

              clear_tags_cache
              respond map_loaded_message(filename)
              mark_loaded
              load_uids
              return true
            end
            false
          end
        end

        # @param filename [String] database to read
        # @return [Boolean] false when the file was unusable
        def parse_map_json(filename)
          File.open(filename) do |f|
            JSON.parse(f.read).each do |room|
              validate_room_json!(room, filename)
              # Defaulted before the loops below read .keys on them.
              room['wayto'] ||= {}
              room['timeto'] ||= {}
              room['tags'] ||= []
              room['uid'] ||= []
              room['wayto'].keys.each do |k|
                room['wayto'][k] = StringProc.new(room['wayto'][k][3..]) if room['wayto'][k][0..2] == ';e '
              end
              room['timeto'].keys.each do |k|
                if room['timeto'][k].is_a?(String) && room['timeto'][k][0..2] == ';e '
                  room['timeto'][k] = StringProc.new(room['timeto'][k][3..])
                end
              end
              room_from_json(room)
            end
          end
          true
        rescue StandardError => e
          # A corrupt or unreadable database must not abort the load or leave a
          # half-built map behind. Report it, drop whatever was registered, and
          # let the caller try an older candidate. raw_list because the load
          # mutex is held and #list would re-enter it.
          respond "--- Lich: error: failed to load #{filename}: #{e.message}"
          raw_list.clear
          clear_tags_cache
          false
        end

        # Fields a room needs to be usable. A database missing any of them loads
        # without complaint and then fails later at lookup or matching time, so
        # reject the file and let the caller fall back to an older one. tags, uid,
        # wayto and timeto are genuinely optional and are defaulted instead.
        # @param room [Hash] one parsed room
        # @param filename [String] database being read, for the message
        # @raise [RuntimeError] when a required field is missing or the wrong type
        # @return [nil]
        def validate_room_json!(room, filename)
          id = room['id']
          raise "#{File.basename(filename)}: room id is not an Integer: #{id.inspect}" unless id.is_a?(Integer)

          %w[title description paths].each do |field|
            next if room[field].is_a?(Array)

            raise "#{File.basename(filename)}: room #{id} has no #{field}"
          end
          nil
        end

        # JSON map databases in the data directory, newest first
        # @return [Array<String>] full paths, empty when the directory is absent
        def json_map_files
          directory = File.join(DATA_DIR, XMLData.game)
          return [] unless Dir.exist?(directory)

          Dir.entries(directory)
             .find_all { |fn| fn =~ /^map-[0-9]+\.json$/i }
             .collect { |fn| File.join(directory, fn) }
             .sort
             .reverse
        end

        # Legacy map files sitting in the data directory, basenames only
        # @return [Array<String>]
        def legacy_map_files
          directory = File.join(DATA_DIR, XMLData.game)
          return [] unless Dir.exist?(directory)

          Dir.entries(directory).grep(/^map(?:-[0-9]+)?\.(?:dat|xml)$/i).sort
        end

        # Explain why an old map database no longer loads. The Marshal (.dat) and
        # XML formats were deprecated for years and support has been removed, so
        # "no map database found" on its own would be misleading for anyone whose
        # data directory still holds one.
        # @param files [Array<String>] legacy file names to name in the message
        # @return [nil]
        def report_unsupported_map_files(files)
          return if files.empty?

          respond "--- Lich: found map data in a format that is no longer supported: #{files.sort.join(', ')}"
          respond '--- Lich: download the current JSON map database to continue.'
          nil
        end

        # Look up a room by id, uid string, or fuzzy title/description text
        # @param val [Integer, String] room id, "u<uid>", or search text
        # @return [Object, nil] the matching room
        def [](val)
          # One load attempt via the accessor, then work off that array; calling
          # #list again would retry the load on every lookup when it failed.
          rooms = list
          if val.is_a?(Integer) || val =~ /^[0-9]+$/
            rooms[val.to_i]
          elsif val =~ /^u(-?\d+)$/i
            uid_request = ::Regexp.last_match(1).dup.to_i
            # nil.to_i is 0, so an unknown uid used to resolve to room 0.
            id = ids_from_uid(uid_request)[0]
            id.nil? ? nil : rooms[id.to_i]
          else
            chkre = /#{val.strip.sub(/\.$/, '').gsub(/\.(?:\.\.)?/, '|')}/i
            chk = /#{Regexp.escape(val.strip)}/i
            # Title and exact-description matches share one pass; the loose
            # regex pass only runs when neither found anything. Same precedence
            # as the three sequential scans this replaces.
            live = rooms.compact
            by_title = nil
            by_desc = nil
            live.each do |room|
              if room.title.find { |title| title =~ chk }
                by_title = room
                break
              end
              by_desc = room if by_desc.nil? && room.description.find { |desc| desc =~ chk }
            end
            by_title || by_desc ||
              live.find { |room| room.description.find { |desc| desc =~ chkre } }
          end
        end

        # Load the newest JSON map database, or a specific file
        # @param filename [String, nil] explicit path, or nil to search DATA_DIR
        # @return [Boolean] whether a map was loaded
        def load(filename = nil)
          file_list = filename.nil? ? json_map_files : [filename]

          # An explicitly named .dat or .xml would otherwise reach load_json and
          # raise a parse error rather than saying why it cannot be loaded.
          unsupported, file_list = file_list.partition { |fn| fn =~ /\.(?:dat|xml)\z/i }

          if file_list.empty?
            if unsupported.empty?
              respond '--- Lich: error: no map database found'
              report_unsupported_map_files(legacy_map_files)
            else
              report_unsupported_map_files(unsupported.map { |fn| File.basename(fn) })
            end
            return false
          end

          while (filename = file_list.shift)
            return true if load_json(filename)
          end
          false
        end

        # Class-level dijkstra dispatcher
        def dijkstra(source, destination = nil)
          if source.is_a?(self)
            source.dijkstra(destination)
          elsif (room = self[source])
            room.dijkstra(destination)
          else
            echo 'Map.dijkstra: error: invalid source room'
            nil
          end
        end

        # Class-level dispatcher for the hash-returning variant of #dijkstra
        def dijkstra_hashes(source, destination = nil)
          if source.is_a?(self)
            source.dijkstra_hashes(destination)
          elsif (room = self[source])
            room.dijkstra_hashes(destination)
          else
            echo 'Map.dijkstra: error: invalid source room'
            nil
          end
        end

        # Tag names present anywhere in the room list, in room id order
        # @return [Array<String>]
        def tag_names
          tag_index.keys
        end

        # Room ids carrying a tag, nearest-agnostic and in room id order
        # @param tag_name [String] Tag to look up
        # @return [Array<Integer>] a copy, empty when the tag is unknown
        def rooms_by_tag(tag_name)
          (tag_index[tag_name] || []).dup
        end

        # Drop the tag memo. Call after mutating any room's tags in place.
        # @return [nil]
        def reset_tag_index
          host = tag_cache_host
          TAG_INDEX_MUTEX.synchronize do
            # Under the same mutex as publication: bumping the generation outside
            # it could land between a publisher's validation and its assignment.
            host.instance_variable_set(:@tag_index_generation,
                                       (host.instance_variable_get(:@tag_index_generation) || 0) + 1)
            host.instance_variable_set(:@tag_index, nil)
          end
          nil
        end

        # Re-wrap plain Array tags as TagList. Rooms that reach the list without
        # going through the constructor, such as a caller assigning a list it
        # built itself, otherwise hold tags that cannot invalidate the index.
        #
        # Callers inside a load must pass the rooms explicitly, because the #list
        # accessor triggers #load when the map is not yet loaded, and #load holds
        # a non-reentrant mutex.
        # @param rooms [Array] rooms to normalize; defaults to the current list
        # @return [nil]
        def normalize_tag_lists(rooms = list)
          rooms.compact.each do |room|
            existing = room.tags
            next if existing.is_a?(TagList)

            # Round trip through the writer, which is what rewraps the plain
            # Array as a TagList bound to this class.
            room.tags = existing
          end
          reset_tag_index
        end

        # Find path between two rooms
        def findpath(source, destination)
          if source.is_a?(self)
            source.path_to(destination)
          elsif (room = self[source])
            room.path_to(destination)
          else
            echo 'Map.findpath: error: invalid source room'
            nil
          end
        end

        # Reload the map database
        def reload
          clear
          load
        end

        # Add a UID mapping
        def uids_add(uid, id)
          uids[uid] ||= []
          uids[uid] << id unless uids[uid].include?(id)
        end

        # Get room IDs from a UID
        def ids_from_uid(uid)
          uids[uid] || []
        end

        # Convert map to JSON
        def to_json(*args)
          list.delete_if(&:nil?)
          list.sort_by(&:id).to_json(args)
        end

        # Save map as JSON file
        def save_json(filename = nil)
          filename ||= File.join(DATA_DIR, XMLData.game, "map-#{Time.now.to_i}.json")
          if File.exist?(filename)
            respond 'File exists!  Backing it up before proceeding...'
            begin
              File.open(filename, 'rb') do |infile|
                File.open("#{filename}.bak", 'wb:UTF-8') do |outfile|
                  outfile.write(infile.read)
                end
              end
            rescue StandardError => e
              respond "--- Lich: error: #{e}\n\t#{e.backtrace[0..1].join("\n\t")}"
              Lich.log "error: #{e}\n\t#{e.backtrace.join("\n\t")}"
            end
          end
          File.open(filename, 'wb:UTF-8') { |file| file.write(to_json) }
          respond "#{filename} saved"
          # Reload if map index appears corrupted
          reload if self[-1].id != self[self[-1].id].id
        end

        alias_method :save, :save_json

        # Applies personal map wayto overrides and custom targets from YAML settings.
        # Reads base_wayto_overrides, personal_wayto_overrides, and personal_map_targets
        # from the user's profile via get_settings. Ensures the map is loaded before
        # accessing room data, consistent with other ClassMethods.
        #
        # @return [void]
        def apply_wayto_overrides
          self.load unless loaded?
          settings = get_settings
          base_overrides = settings.base_wayto_overrides || {}
          personal_overrides = settings.personal_wayto_overrides || {}
          wayto_overrides = base_overrides.merge(personal_overrides)

          wayto_overrides.each do |_key, values|
            next unless values.is_a?(Hash) && values['start_room'] && values['end_room']

            start_room_id = values['start_room'].to_i
            end_room_id = values['end_room'].to_s
            start_room = list[start_room_id]
            next unless start_room

            if values['str_proc']
              start_room.wayto[end_room_id] = StringProc.new(values['str_proc'].to_s)
            end
            if values['travel_time']
              new_timeto = Float(values['travel_time'], exception: false)
              new_timeto ||= StringProc.new(values['travel_time'].to_s)
              start_room.timeto[end_room_id] = new_timeto
            end
          end

          personal_map_targets = settings.personal_map_targets
          if personal_map_targets.is_a?(Hash)
            custom_targets = (GameSettings['custom targets'] || {})
            custom_targets.merge!(personal_map_targets)
            GameSettings['custom targets'] = custom_targets
          end
        end
      end

      # Instance methods for Room/Map objects
      module InstanceMethods
        # Replace this room's tags and drop the tag index
        # @param value [Array, nil] new tag names
        # @return [nil] Ruby ignores a writer's return value, so `room.tags = x`
        #   evaluates to x regardless of what this returns
        def tags=(value)
          @tags = TagList.new(value, self.class)
          self.class.reset_tag_index
        end

        # Convert room to integer (room ID)
        def to_i
          @id
        end

        # Check if room is outdoors
        # Works for both GemStone and DragonRealms:
        # - "Obvious paths:" indicates outdoor
        # - "Obvious exits:" indicates indoor
        # @return [Boolean] true if room is outdoors
        def outside?
          return false if @paths.nil? || @paths.empty?

          @paths.last =~ /^Obvious paths:/ ? true : false
        end

        # Check if room is indoors
        # @return [Boolean] true if room is indoors
        def inside?
          !outside?
        end

        # Inspect room details
        def inspect
          instance_variables.collect do |var|
            "#{var}=#{instance_variable_get(var).inspect}"
          end.join("\n")
        end

        # Override in subclasses to add game-specific fields to JSON output.
        # Must return a Hash. Nil/empty values are filtered automatically.
        def json_extra_fields
          {}
        end

        # Convert room to JSON
        def to_json(*_args)
          mapjson = {
            id: @id,
            title: @title,
            description: @description,
            paths: @paths,
            location: @location,
            climate: @climate,
            terrain: @terrain,
            wayto: @wayto&.sort_by { |k, _v| k.to_i }&.to_h,
            timeto: @timeto&.sort_by { |k, _v| k.to_i }&.to_h,
            image: @image,
            image_coords: @image_coords,
            tags: @tags&.sort_by { |tag| [tag.downcase, tag] },
            check_location: @check_location,
            unique_loot: @unique_loot,
            uid: @uid
          }
          mapjson.merge!(json_extra_fields)
          mapjson.delete_if { |_a, b| b.nil? || (b.is_a?(Array) && b.empty?) }
          JSON.pretty_generate(mapjson)
        end

        # Run Dijkstra's algorithm from this room
        # @param destination [Integer, Array, nil] Target room(s) or nil for full graph
        # @return [Array, nil] [previous, distances] as Arrays indexed by room id
        def dijkstra(destination = nil)
          previous_hash, shortest_distances_hash = dijkstra_hashes(destination)
          return nil if previous_hash.nil?

          # Convert hashes back to arrays for backward compatibility
          max_room_id = [previous_hash.keys.max, shortest_distances_hash.keys.max].compact.max || 0
          previous = Array.new(max_room_id + 1)
          shortest_distances = Array.new(max_room_id + 1)

          previous_hash.each { |key, value| previous[key] = value }
          shortest_distances_hash.each { |key, value| shortest_distances[key] = value }

          [previous, shortest_distances]
        end

        # Same search as #dijkstra, returning the raw hashes keyed by room id.
        # Internal callers use this so nothing allocates arrays sized by the
        # highest room id in the database.
        # @param destination [Integer, Array, nil] Target room(s) or nil for full graph
        # @return [Array, nil] [previous_hash, distances_hash], or nil on error
        def dijkstra_hashes(destination = nil)
          self.class.load unless self.class.loaded?
          source = @id
          visited = {}
          shortest_distances_hash = {}
          previous_hash = {}

          pq = MinHeap.new
          pq.push(0, source)
          shortest_distances_hash[source] = 0

          check_destination = proc do |v, dist|
            case destination
            when Integer
              v == destination
            when Array
              destination.include?(v) && dist < 20
            else
              false
            end
          end

          until pq.empty?
            current_dist, v = pq.pop

            next if visited[v]
            break if check_destination.call(v, current_dist)

            visited[v] = true

            self.class.list[v].wayto.keys.each do |adj_room|
              adj_room_i = adj_room.to_i
              next if visited[adj_room_i]

              edge_weight = if self.class.list[v].timeto[adj_room].is_a?(StringProc)
                              self.class.list[v].timeto[adj_room].call
                            else
                              self.class.list[v].timeto[adj_room]
                            end

              next unless edge_weight

              new_distance = current_dist + edge_weight

              if !shortest_distances_hash[adj_room_i] || shortest_distances_hash[adj_room_i] > new_distance
                shortest_distances_hash[adj_room_i] = new_distance
                previous_hash[adj_room_i] = v
                pq.push(new_distance, adj_room_i)
              end
            end
          end

          [previous_hash, shortest_distances_hash]
        rescue StandardError => e
          echo "Map.dijkstra: error: #{e}"
          respond e.backtrace
          nil
        end

        # Find path from this room to destination
        # @param destination [Integer] Target room ID
        # @return [Array<Integer>, nil] Array of room IDs representing rooms to traverse (excluding source, including destination)
        def path_to(destination)
          self.class.load unless self.class.loaded?
          destination = destination.to_i
          previous, = dijkstra_hashes(destination)
          # dijkstra_hashes returns nil when the search itself failed.
          return nil if previous.nil?
          return nil unless previous[destination]

          path = [destination]
          seen = { destination => true }
          until previous[path[-1]] == @id
            step = previous[path[-1]]
            # A chain that never reaches this room is not a usable path. The
            # hash yields nil for a missing predecessor, and a chain that
            # revisits a room is a cycle; either would loop forever. Dijkstra
            # should not produce either, but path_to is a public entry point and
            # dijkstra_hashes is overridable.
            return nil if step.nil? || seen[step]

            seen[step] = true
            path.push(step)
          end
          path.reverse
        end

        # Find nearest room with a specific tag
        # @param tag_name [String] Tag to search for
        # @return [Integer, nil] Room ID of nearest tagged room
        def find_nearest_by_tag(tag_name)
          target_list = self.class.rooms_by_tag(tag_name)
          return @id if target_list.include?(@id)

          _, shortest_distances = dijkstra_hashes(target_list)
          return nil if shortest_distances.nil?

          target_list.delete_if { |room_num| shortest_distances[room_num].nil? }
          target_list.sort { |a, b| shortest_distances[a] <=> shortest_distances[b] }.first
        end

        # Find all rooms with a specific tag, sorted by distance
        # @param tag_name [String] Tag to search for
        # @return [Array<Integer>] Room IDs sorted by distance
        def find_all_nearest_by_tag(tag_name)
          target_list = self.class.rooms_by_tag(tag_name)
          _, shortest_distances = dijkstra_hashes
          return [] if shortest_distances.nil?

          target_list.delete_if { |room_num| shortest_distances[room_num].nil? }
          target_list.sort { |a, b| shortest_distances[a] <=> shortest_distances[b] }
        end

        # Find nearest room from a list
        # @param target_list [Array<Integer>] List of room IDs to search
        # @return [Integer, nil] Nearest room ID
        def find_nearest(target_list)
          target_list = target_list.collect(&:to_i)
          if target_list.include?(@id)
            @id
          else
            _, shortest_distances = dijkstra_hashes(target_list)
            return nil if shortest_distances.nil?

            valid_rooms = target_list.select { |room_num| shortest_distances[room_num].is_a?(Numeric) }
            valid_rooms.min_by { |room_num| shortest_distances[room_num] }
          end
        end

        # Deprecated methods for backward compatibility
        def desc
          @description
        end

        def map_name
          @image
        end

        def map_x
          return nil if @image_coords.nil?

          ((image_coords[0] + image_coords[2]) / 2.0).round
        end

        def map_y
          return nil if @image_coords.nil?

          ((image_coords[1] + image_coords[3]) / 2.0).round
        end

        def map_roomsize
          return nil if @image_coords.nil?

          image_coords[2] - image_coords[0]
        end

        def geo
          nil
        end
      end
    end
  end
end
