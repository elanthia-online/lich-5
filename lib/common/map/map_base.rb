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
    # index whenever it is mutated, so Map.rooms_by_tag cannot go stale behind
    # a caller's back. Reads are plain Array reads with no added indirection.
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
          @owner.reset_tag_index if @owner.respond_to?(:reset_tag_index)
          result
        end
      end
    end

    # Base module containing shared map functionality
    # Include this in game-specific Map classes
    module MapBase
      def self.included(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
      end

      # Class methods shared across all Map implementations
      module ClassMethods
        # Get the next available room ID
        def get_free_id
          self.load unless loaded?
          list.compact.max_by(&:id).id + 1
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
        # @return [Hash{String => Array<Integer>}]
        def tag_index
          self.load unless loaded?
          cached = @tag_index
          return cached unless cached.nil?

          generation = tag_index_generation
          built = build_tag_index
          # Discard the build if the index was invalidated while it was running,
          # so a concurrent tag change cannot be clobbered by a stale rebuild.
          @tag_index = built if generation == tag_index_generation
          built
        end

        # @return [Integer]
        def tag_index_generation
          @tag_index_generation ||= 0
        end

        # @return [Hash{String => Array<Integer>}]
        def build_tag_index
          index = {}
          list.compact.each do |room|
            room.tags.each { |tag| (index[tag] ||= []) << room.id }
          end
          index
        end

        private :tag_index, :tag_index_generation, :build_tag_index

        # Explain why an old map database no longer loads. The Marshal (.dat) and
        # XML formats were deprecated for years and support has been removed, so
        # "no map database found" on its own would be misleading for anyone whose
        # data directory still holds one.
        # @return [nil]
        def report_legacy_map_files
          directory = File.join(DATA_DIR, XMLData.game)
          return unless Dir.exist?(directory)

          legacy = Dir.entries(directory).grep(/^map(?:-[0-9]+)?\.(?:dat|xml)$/i).sort
          return if legacy.empty?

          respond "--- Lich: found map data in a format that is no longer supported: #{legacy.join(', ')}"
          respond '--- Lich: download the current JSON map database to continue.'
          nil
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
          @tag_index_generation = tag_index_generation + 1
          @tag_index = nil
        end

        # Re-wrap plain Array tags as TagList. Rooms restored by Marshal skip the
        # constructor, so their tags cannot invalidate the index on mutation.
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
          return nil unless previous[destination]

          path = [destination]
          path.push(previous[path[-1]]) until previous[path[-1]] == @id
          path.reverse
        end

        # Find nearest room with a specific tag
        # @param tag_name [String] Tag to search for
        # @return [Integer, nil] Room ID of nearest tagged room
        def find_nearest_by_tag(tag_name)
          target_list = self.class.rooms_by_tag(tag_name)
          _, shortest_distances = dijkstra_hashes(target_list)
          if target_list.include?(@id)
            @id
          else
            target_list.delete_if { |room_num| shortest_distances[room_num].nil? }
            target_list.sort { |a, b| shortest_distances[a] <=> shortest_distances[b] }.first
          end
        end

        # Find all rooms with a specific tag, sorted by distance
        # @param tag_name [String] Tag to search for
        # @return [Array<Integer>] Room IDs sorted by distance
        def find_all_nearest_by_tag(tag_name)
          target_list = self.class.rooms_by_tag(tag_name)
          _, shortest_distances = dijkstra_hashes
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
