class Map
  @@loaded                   = false
  @@load_mutex               = Mutex.new
  @@list                   ||= Array.new
  @@images                 ||= Array.new
  @@locations              ||= Array.new
  @@tags                   ||= Array.new
  @@current_room_mutex       = Mutex.new
  @@current_room_id        ||= nil
  @@current_room_count     ||= -1
  @@fuzzy_room_mutex         = Mutex.new
  @@fuzzy_room_id          ||= nil
  @@fuzzy_room_count       ||= -1
  @@current_location       ||= nil
  @@current_location_count ||= -1
  @@previous_room_id       ||= nil
  @@uids                     = {}
  attr_reader :id
  attr_accessor :title, :description, :paths, :uid, :location, :climate, :terrain, :wayto, :timeto, :image, :image_coords, :tags, :check_location, :unique_loot

  def initialize(id, title, description, paths, uid = [], location = nil, climate = nil, terrain = nil, wayto = {}, timeto = {}, image = nil, image_coords = nil, tags = [], check_location = nil, unique_loot = nil)
    @id, @title, @description, @paths, @uid, @location, @climate, @terrain, @wayto, @timeto, @image, @image_coords, @tags, @check_location, @unique_loot = id, title, description, paths, uid, location, climate, terrain, wayto, timeto, image, image_coords, tags, check_location, unique_loot
    @@list[@id] = self
  end

  def Map.current_room_id; return @@current_room_id; end
  def Map.current_room_id=(id); return @@current_room_id = id; end
  def Map.loaded; return @@loaded; end
  def Map.previous_room_id; return @@previous_room_id; end
  def Map.previous_room_id=(id); return @@previous_room_id = id; end
  def fuzzy_room_id; return @@current_room_id; end
  def outside?; return @paths.last =~ /^Obvious paths:/ ? true : false; end
  def to_i; return @id; end

  def to_s
    return "##{@id} (u#{@uid[-1]}):\n#{@title[-1]} (#{@location})\n#{@description[-1]}\n#{@paths[-1]}"
  end

  def inspect
    return self.instance_variables.collect { |var| var.to_s + "=" + self.instance_variable_get(var).inspect }.join("\n")
  end

  def Map.fuzzy_room_id; return @@fuzzy_room_id; end

  def Map.get_free_id
    Map.load unless @@loaded
    return @@list.compact.max_by { |r| r.id }.id + 1
  end

  def Map.list
    Map.load unless @@loaded
    return @@list
  end

  def Map.[](val)
    Map.load unless @@loaded
    if (val.class == Integer or val =~ /^[0-9]+$/)
      return @@list[val.to_i]
    elsif val =~ /^u(-?\d+)$/i
      uid_request = $1.dup.to_i
      return @@list[(Map.ids_from_uid(uid_request)[0]).to_i]
    else
      chkre = /#{val.strip.sub(/\.$/, '').gsub(/\.(?:\.\.)?/, '|')}/i
      chk = /#{Regexp.escape(val.strip)}/i
      return @@list.find { |room| room.title.find { |title| title =~ chk } } || @@list.find { |room| room.description.find { |desc| desc =~ chk } } || @@list.find { |room| room.description.find { |desc| desc =~ chkre } }
    end
  end

  def Map.get_location
    unless XMLData.room_count == @@current_location_count
      if (script = Script.current)
        save_want_downstream = script.want_downstream
        script.want_downstream = true
        waitrt?
        location_result = dothistimeout 'location', 15, /^You carefully survey your surroundings and guess that your current location is .*? or somewhere close to it\.$|^You can't do that while submerged under water\.$|^You can't do that\.$|^It would be rude not to give your full attention to the performance\.$|^You can't do that while hanging around up here!$|^You are too distracted by the difficulty of staying alive in these treacherous waters to do that\.$|^You carefully survey your surroundings but are unable to guess your current location\.$|^Not in pitch darkness you don't\.$|^That is too difficult to consider here\.$/
        script.want_downstream = save_want_downstream
        @@current_location_count = XMLData.room_count
        if location_result =~ /^You can't do that while submerged under water\.$|^You can't do that\.$|^It would be rude not to give your full attention to the performance\.$|^You can't do that while hanging around up here!$|^You are too distracted by the difficulty of staying alive in these treacherous waters to do that\.$|^You carefully survey your surroundings but are unable to guess your current location\.$|^Not in pitch darkness you don't\.$|^That is too difficult to consider here\.$/
          @@current_location = false
        else
          @@current_location = /^You carefully survey your surroundings and guess that your current location is (.*?) or somewhere close to it\.$/.match(location_result).captures.first
        end
      else
        return nil
      end
    end
    return @@current_location
  end

  def Map.previous
    return nil if @@previous_room_id.nil?
    return @@list[@@previous_room_id]
  end

  def Map.previous_uid
    return XMLData.previous_nav_rm
  end

  def Map.current # returns Map/Room
    Map.load unless @@loaded
    if Script.current
      return @@list[@@current_room_id] if XMLData.room_count == @@current_room_count and !@@current_room_id.nil?;
    else
      return @@list[@@current_room_id] if XMLData.room_count == @@fuzzy_room_count and !@@current_room_id.nil?;
    end
    ids = Map.ids_from_uid(XMLData.room_id);
    return Map.set_current(ids[0]) if ids.size == 1;
    if ids.size > 1 and !@@current_room_id.nil? and (id = Map.match_multi_ids(ids))
      return Map.set_current(id)
    end
    return Map.match_no_uid()
  end

  def Map.set_current(id) # returns Map/Room
    @@previous_room_id = @@current_room_id if id != @@current_room_id;
    @@current_room_id  = id
    return nil if id.nil?
    return @@list[id]
  end

  def Map.set_fuzzy(id) # returns Map/Room
    @@previous_room_id = @@current_room_id if !id.nil? and id != @@current_room_id;
    @@current_room_id  = id
    return nil if id.nil?
    return @@list[id]
  end

  def Map.match_multi_ids(ids) # returns id
    matches = ids.find_all { |s| @@list[@@current_room_id].wayto.keys.include?(s.to_s) }
    return matches[0] if matches.size == 1;
    return nil;
  end

  def Map.match_no_uid() # returns Map/Room
    if (script = Script.current)
      return Map.set_current(Map.match_current(script))
    else
      return Map.set_fuzzy(Map.match_fuzzy())
    end
  end

  def Map.match_current(script) # returns id
    @@current_room_mutex.synchronize {
      peer_history = Hash.new
      need_set_desc_off = false
      check_peer_tag = proc { |r|
        begin
          script.ignore_pause = true
          peer_room_count = XMLData.room_count
          if (peer_tag = r.tags.find { |tag| tag =~ /^(set desc on; )?peer [a-z]+ =~ \/.+\/$/ })
            good = false
            need_desc, peer_direction, peer_requirement = /^(set desc on; )?peer ([a-z]+) =~ \/(.+)\/$/.match(peer_tag).captures
            need_desc = need_desc ? true : false
            if peer_history[peer_room_count][peer_direction][need_desc].nil?
              if need_desc
                unless (last_roomdesc = $_SERVERBUFFER_.reverse.find { |line| line =~ /<style id="roomDesc"\/>/ }) and (last_roomdesc =~ /<style id="roomDesc"\/>[^<]/)
                  put 'set description on'
                  need_set_desc_off = true
                end
              end
              save_want_downstream = script.want_downstream
              script.want_downstream = true
              squelch_started = false
              squelch_proc = proc { |server_string|
                if squelch_started
                  if server_string =~ /<prompt/
                    DownstreamHook.remove('squelch-peer')
                  end
                  nil
                elsif server_string =~ /^You peer/
                  squelch_started = true
                  nil
                else
                  server_string
                end
              }
              DownstreamHook.add('squelch-peer', squelch_proc)
              result = dothistimeout "peer #{peer_direction}", 3, /^You peer|^\[Usage: PEER/
              if result =~ /^You peer/
                peer_results = Array.new
                5.times {
                  if (line = get?)
                    peer_results.push line
                    break if line =~ /^Obvious/
                  end
                }
                if XMLData.room_count == peer_room_count
                  peer_history[peer_room_count] ||= Hash.new
                  peer_history[peer_room_count][peer_direction] ||= Hash.new
                  if need_desc
                    peer_history[peer_room_count][peer_direction][true] = peer_results
                    peer_history[peer_room_count][peer_direction][false] = peer_results
                  else
                    peer_history[peer_room_count][peer_direction][false] = peer_results
                  end
                end
              end
              script.want_downstream = save_want_downstream
            end
            if peer_history[peer_room_count][peer_direction][need_desc].any? { |line| line =~ /#{peer_requirement}/ }
              good = true
            else
              good = false
            end
          else
            good = true
          end
        ensure
          script.ignore_pause = false
        end
        good
      }
      begin
        begin
          @@current_room_count = XMLData.room_count
          foggy_exits = (XMLData.room_exits_string =~ /^Obvious (?:exits|paths): obscured by a thick fog$/)
          if (room = @@list.find { |r|
                r.title.include?(XMLData.room_title) and
                  r.description.include?(XMLData.room_description.strip) and
                  (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and
                  (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and
                  (not r.check_location or r.location == Map.get_location) and check_peer_tag.call(r)
              })
            redo unless @@current_room_count == XMLData.room_count
            return room.id
          else
            redo unless @@current_room_count == XMLData.room_count
            desc_regex = /#{Regexp.escape(XMLData.room_description.strip.sub(/\.+$/, '')).gsub(/\\\.(?:\\\.\\\.)?/, '|')}/
            if (room = @@list.find { |r|
                  r.title.include?(XMLData.room_title) and
                    (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and
                    (XMLData.room_window_disabled or r.description.any? { |desc| desc =~ desc_regex }) and
                    (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and
                    (not r.check_location or r.location == Map.get_location) and check_peer_tag.call(r)
                })
              redo unless @@current_room_count == XMLData.room_count
              return room.id
            else
              redo unless @@current_room_count == XMLData.room_count
              return nil
            end
          end
        end
      ensure
        put 'set description off' if need_set_desc_off
      end
    }
  end

  def Map.match_fuzzy() # returns id
    @@fuzzy_room_mutex.synchronize {
      @@fuzzy_room_count = XMLData.room_count
      begin
        foggy_exits = (XMLData.room_exits_string =~ /^Obvious (?:exits|paths): obscured by a thick fog$/)
        if (room = @@list.find { |r|
              r.title.include?(XMLData.room_title) and
                r.description.include?(XMLData.room_description.strip) and
                (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and
                (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and
                (not r.check_location or r.location == Map.get_location)
            })
          redo unless @@fuzzy_room_count == XMLData.room_count
          if room.tags.any? { |tag| tag =~ /^(set desc on; )?peer [a-z]+ =~ \/.+\/$/ }
            return nil
          else
            return room.id
          end
        else
          redo unless @@fuzzy_room_count == XMLData.room_count
          desc_regex = /#{Regexp.escape(XMLData.room_description.strip.sub(/\.+$/, '')).gsub(/\\\.(?:\\\.\\\.)?/, '|')}/
          if (room = @@list.find { |r|
                r.title.include?(XMLData.room_title) and
                (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and
                (XMLData.room_window_disabled or r.description.any? { |desc| desc =~ desc_regex }) and
                (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and
                (not r.check_location or r.location == Map.get_location)
              })
            redo unless @@fuzzy_room_count == XMLData.room_count
            if room.tags.any? { |tag| tag =~ /^(set desc on; )?peer [a-z]+ =~ \/.+\/$/ }
              return nil
            else
              return room.id
            end
          else
            redo unless @@fuzzy_room_count == XMLData.room_count
            return nil
          end
        end
      end
    }
  end

  def Map.current_or_new # returns Map/Room
    return nil unless Script.current
    Map.load unless @@loaded
    ids = Map.ids_from_uid(XMLData.room_id);
    room = nil
    id = ids[0] if ids.size == 1;
    id = Map.match_multi_ids(ids) if ids.size > 1;
    if id.nil?
      id = Map.match_current(Script.current)
      # prevent loading uids into existing rooms with a single id unless tagged meta:map:multi-uid
      if !id.nil? and Map[id].uid.size == 1 and !Map[id].tags.include?('meta:map:multi-uid')
        id = nil
      end
    end
    if !id.nil? # existing room
      room = Map[id]
      if !room.uid.include?(XMLData.room_id)
        room.uid << XMLData.room_id
        Map.uids_add(XMLData.room_id, room.id)
        echo "Map: Adding new uid for #{room.id}: #{XMLData.room_id}"
      end
      if (room.tags & ['meta:map:latest-only', 'meta:playershop']).empty?
        # update room if not meta:playershop or meta:map:latest-only
        if !room.title.include?(XMLData.room_title)
          room.title.unshift(XMLData.room_title)
          echo "Map: Adding new title for #{room.id}: '#{XMLData.room_title}'"
        end
        if !room.description.include?(XMLData.room_description.strip)
          room.description.unshift(XMLData.room_description.strip)
          echo "Map: Adding new description for #{room.id} : #{XMLData.room_description.strip.inspect}"
        end
        if !room.paths.include?(XMLData.room_exits_string.strip)
          room.paths.unshift(XMLData.room_exits_string.strip)
          echo "Map: Adding new path for #{room.id}: #{XMLData.room_exits_string.strip.inspect}"
        end
        if (room.location.nil? or room.location == false or room.location == '')
          current_location = Map.get_location
          room.location    = current_location
          echo "Map: Updating location for #{room.id}: #{current_location.inspect}"
        end
      elsif !(room.tags & ['meta:map:latest-only', 'meta:playershop']).empty?
        # update rooms tagged meta:playershop or meta:map:latest-only
        if room.title != [XMLData.room_title]
          room.title = [XMLData.room_title]
          echo "Map: Updating title for #{room.id}: #{XMLData.room_title.inspect}"
        end
        if room.description != [XMLData.room_description.strip]
          room.description = [XMLData.room_description.strip]
          echo "Map: Updating description for #{room.id}: #{XMLData.room_description.strip.inspect}"
        end
        if room.paths != [XMLData.room_exits_string.strip]
          room.paths = [XMLData.room_exits_string.strip]
          echo "Map: Updating path for #{room.id}: #{XMLData.room_exits_string.strip.inspect}"
        end
        if (room.location.nil? or room.location == false or room.location == '')
          current_location = Map.get_location
          room.location    = current_location
          echo "Map: Updating location for #{room.id}: #{current_location.inspect}"
        end
      end
      return Map.set_current(room.id)
    end
    # new room
    current_location = Map.get_location
    id               = Map.get_free_id
    title            = [XMLData.room_title]
    description      = [XMLData.room_description.strip]
    paths            = [XMLData.room_exits_string.strip]
    uid              = [XMLData.room_id]
    room             = Map.new(Map.get_free_id, title, description, paths, uid, current_location)
    Map.uids_add(XMLData.room_id, room.id)
    # flag identical rooms with different locations
    identical_rooms = @@list.find_all { |r|
      (r.location != current_location) and
        r.title.include?(XMLData.room_title) and
        r.description.include?(XMLData.room_description.strip) and
        (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and
        (r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and
        !r.uid.include?(XMLData.room_id)
    }
    if identical_rooms.length > 0
      room.check_location = true
      identical_rooms.each { |r| r.check_location = true }
    end
    echo "mapped new room, set current room to #{room.id}"
    return Map.set_current(id)
  end

  def Map.locations
    Map.load unless @@loaded
    @@locations = @@list.each_with_object({}) { |r, h| h[r.location] = nil if !h.key?(r.location) }.keys if @@locations.empty?;
    return @@locations.dup
  end

  def Map.images
    Map.load unless @@loaded
    @@images = @@list.each_with_object({}) { |r, h| h[r.image] = nil if !h.key?(r.image) }.keys if @@images.empty?;
    return @@images.dup
  end

  def Map.tags
    Map.load unless @@loaded
    @@tags = @@list.each_with_object({}) { |r, h| r.tags.each { |t| h[t] = nil if !h.key?(t) } }.keys if @@tags.empty?;
    return @@tags.dup
  end

  def Map.uids(); return @@uids; end
  def Map.uids_clear(); @@uids.clear; end
  def Map.ids_from_uid(n); return (@@uids[n].nil? ? [] : @@uids[n]); end

  def Map.uids_add(uid, id)
    if !@@uids.key?(uid)
      @@uids[uid] = [id]
    else
      @@uids[uid] << id if !@@uids[uid].include?(id)
    end
  end

  def Map.load_uids()
    Map.load unless @@loaded
    @@uids.clear
    @@list.each { |r|
      r.uid.each { |u| Map.uids_add(u, r.id) }
    }
  end

  def Map.clear
    @@load_mutex.synchronize {
      @@list.clear
      @@tags.clear
      @@locations.clear
      @@images.clear
      @@loaded = false
      GC.start
    }
    return true
  end

  def Map.reload
    Map.clear
    Map.load
  end

  def Map.load(filename = nil)
    if filename.nil?
      file_list = Dir.entries("#{DATA_DIR}/#{XMLData.game}").find_all { |fn| fn =~ /^map\-[0-9]+\.(?:dat|xml|json)$/i }.collect { |fn| "#{DATA_DIR}/#{XMLData.game}/#{fn}" }.sort.reverse
    else
      file_list = [filename]
    end
    if file_list.empty?
      respond "--- Lich: error: no map database found"
      return false
    end
    while (filename = file_list.shift)
      if filename =~ /\.json$/i
        if Map.load_json(filename)
          return true
        end
      elsif filename =~ /\.xml$/
        if Map.load_xml(filename)
          return true
        end
      else
        if Map.load_dat(filename)
          return true
        end
      end
    end
    return false
  end

  def Map.load_json(filename = nil)
    @@load_mutex.synchronize {
      if @@loaded
        return true
      else
        if filename
          file_list = [filename]
        else
          file_list = Dir.entries("#{DATA_DIR}/#{XMLData.game}").find_all { |fn|
            fn =~ /^map\-[0-9]+\.json$/i
          }.collect { |fn|
            "#{DATA_DIR}/#{XMLData.game}/#{fn}"
          }.sort.reverse
        end
        if file_list.empty?
          respond "--- Lich: error: no map database found"
          return false
        end
        while (filename = file_list.shift)
          if File.exist?(filename)
            File.open(filename) { |f|
              JSON.parse(f.read).each { |room|
                room['wayto'].keys.each { |k|
                  if room['wayto'][k][0..2] == ';e '
                    room['wayto'][k] = StringProc.new(room['wayto'][k][3..-1])
                  end
                }
                room['timeto'].keys.each { |k|
                  if (room['timeto'][k].class == String) and (room['timeto'][k][0..2] == ';e ')
                    room['timeto'][k] = StringProc.new(room['timeto'][k][3..-1])
                  end
                }
                room['wayto'] ||= {}
                room['timeto'] ||= {}
                room['title'] ||= []
                room['description'] ||= []
                room['tags']  ||= []
                room['uid']   ||= []
                Map.new(room['id'], room['title'], room['description'], room['paths'], room['uid'], room['location'], room['climate'], room['terrain'], room['wayto'], room['timeto'], room['image'], room['image_coords'], room['tags'], room['check_location'], room['unique_loot'])
              }
            }
            @@tags.clear
            respond "--- #{Script.current.name} Map loaded #{filename}"
            @@loaded = true
            Map.load_uids
            return true
          end
        end
      end
    }
  end

  def Map.load_dat(filename = nil)
    @@load_mutex.synchronize {
      if @@loaded
        return true
      else
        if filename.nil?
          file_list = Dir.entries("#{DATA_DIR}/#{XMLData.game}").find_all { |fn| fn =~ /^map\-[0-9]+\.dat$/ }.collect { |fn| "#{DATA_DIR}/#{XMLData.game}/#{fn}" }.sort.reverse
        else
          file_list = [filename]
          respond "--- file_list = #{filename.inspect}"
        end
        if file_list.empty?
          respond "--- Lich: error: no map database found"
          return false
        end
        while (filename = file_list.shift)
          begin
            @@list = File.open(filename, 'rb') { |f| Marshal.load(f.read) }
            respond "--- Map loaded #{filename}" # if error
            @@loaded = true
            Map.load_uids
            return true
          rescue
            if file_list.empty?
              respond "--- Lich: error: failed to load #{filename}: #{$!}"
            else
              respond "--- warning: failed to load #{filename}: #{$!}"
            end
          end
        end
        return false
      end
    }
  end

  def Map.load_xml(filename = "#{DATA_DIR}/#{XMLData.game}/map.xml")
    @@load_mutex.synchronize {
      if @@loaded
        return true
      else
        unless File.exist?(filename)
          raise Exception.exception("MapDatabaseError"), "Fatal error: file `#{filename}' does not exist!"
        end
        missing_end = false
        current_tag = nil
        current_attributes = nil
        room = nil
        buffer = String.new
        unescape = { 'lt' => '<', 'gt' => '>', 'quot' => '"', 'apos' => "'", 'amp' => '&' }
        tag_start = proc { |element, attributes|
          current_tag = element
          current_attributes = attributes
          if element == 'room'
            room = Hash.new
            room['id'] = attributes['id'].to_i
            room['location'] = attributes['location']
            room['climate'] = attributes['climate']
            room['terrain'] = attributes['terrain']
            room['wayto'] = Hash.new
            room['timeto'] = Hash.new
            room['title'] = Array.new
            room['description'] = Array.new
            room['paths'] = Array.new
            room['tags'] = Array.new
            room['unique_loot'] = Array.new
            room['uid'] = Array.new
          elsif element =~ /^(?:image|tsoran)$/ and attributes['name'] and attributes['x'] and attributes['y'] and attributes['size']
            room['image'] = attributes['name']
            room['image_coords'] = [(attributes['x'].to_i - (attributes['size'] / 2.0).round), (attributes['y'].to_i - (attributes['size'] / 2.0).round), (attributes['x'].to_i + (attributes['size'] / 2.0).round), (attributes['y'].to_i + (attributes['size'] / 2.0).round)]
          elsif (element == 'image') and attributes['name'] and attributes['coords'] and (attributes['coords'] =~ /[0-9]+,[0-9]+,[0-9]+,[0-9]+/)
            room['image'] = attributes['name']
            room['image_coords'] = attributes['coords'].split(',').collect { |num| num.to_i }
          elsif element == 'map'
            missing_end = true
          end
        }
        text = proc { |text_string|
          if current_tag == 'tag'
            room['tags'].push(text_string)
          elsif current_tag =~ /^(?:title|description|paths|unique_loot)$/
            room[current_tag].push(text_string)
          elsif current_tag =~ /^(?:uid)$/
            room[current_tag].push(text_string.to_i)
          elsif current_tag == 'exit' and current_attributes['target']
            if current_attributes['type'].downcase == 'string'
              room['wayto'][current_attributes['target']] = text_string
            else
              room['wayto'][current_attributes['target']] = StringProc.new(text_string)
            end
            if current_attributes['cost'] =~ /^[0-9\.]+$/
              room['timeto'][current_attributes['target']] = current_attributes['cost'].to_f
            elsif current_attributes['cost'].length > 0
              room['timeto'][current_attributes['target']] = StringProc.new(current_attributes['cost'])
            else
              room['timeto'][current_attributes['target']] = 0.2
            end
          end
        }
        tag_end = proc { |element|
          if element == 'room'
            room['unique_loot'] = nil if room['unique_loot'].empty?
            Map.new(room['id'], room['title'], room['description'], room['paths'], room['uid'], room['location'], room['climate'], room['terrain'], room['wayto'], room['timeto'], room['image'], room['image_coords'], room['tags'], room['check_location'], room['unique_loot'])
          elsif element == 'map'
            missing_end = false
          end
          current_tag = nil
        }
        begin
          File.open(filename) { |file|
            while (line = file.gets)
              buffer.concat(line)
              # fixme: remove   (?=<)   ?
              while (str = buffer.slice!(/^<([^>]+)><\/\1>|^[^<]+(?=<)|^<[^<]+>/))
                if str[0, 1] == '<'
                  if str[1, 1] == '/'
                    element = /^<\/([^\s>\/]+)/.match(str).captures.first
                    tag_end.call(element)
                  else
                    if str =~ /^<([^>]+)><\/\1>/
                      element = $1
                      tag_start.call(element)
                      text.call('')
                      tag_end.call(element)
                    else
                      element = /^<([^\s>\/]+)/.match(str).captures.first
                      attributes = Hash.new
                      str.scan(/([A-z][A-z0-9_\-]*)=(["'])(.*?)\2/).each { |attr| attributes[attr[0]] = attr[2].gsub(/&(#{unescape.keys.join('|')});/) { unescape[$1] } }
                      tag_start.call(element, attributes)
                      tag_end.call(element) if str[-2, 1] == '/'
                    end
                  end
                else
                  text.call(str.gsub(/&(#{unescape.keys.join('|')});/) { unescape[$1] })
                end
              end
            end
          }
          if missing_end
            respond "--- Lich: error: failed to load #{filename}: unexpected end of file"
            return false
          end
          @@tags.clear
          Map.load_uids
          @@loaded = true
          return true
        rescue
          respond "--- Lich: error: failed to load #{filename}: #{$!}"
          return false
        end
      end
    }
  end

  def Map.save(filename = "#{DATA_DIR}/#{XMLData.game}/map-#{Time.now.to_i}.dat")
    if File.exist?(filename)
      respond "--- Backing up map database"
      begin
        # fixme: does this work on all platforms? File.rename(filename, "#{filename}.bak")
        File.open(filename, 'rb') { |infile|
          File.open("#{filename}.bak", 'wb') { |outfile|
            outfile.write(infile.read)
          }
        }
      rescue
        respond "--- Lich: error: #{$!}"
      end
    end
    begin
      File.open(filename, 'wb') { |f| f.write(Marshal.dump(@@list)) }
      @@tags.clear
      respond "--- Map database saved"
    rescue
      respond "--- Lich: error: #{$!}"
    end
  end

  def Map.to_json(*args)
    @@list.delete_if { |r| r.nil? }
    @@list.to_json(args)
  end

  def to_json(*_args)
    mapjson = ({
      :id             => @id,
      :title          => @title,
      :description    => @description,
      :paths          => @paths,
      :location       => @location,
      :climate        => @climate,
      :terrain        => @terrain,
      :wayto          => @wayto,
      :timeto         => @timeto,
      :image          => @image,
      :image_coords   => @image_coords,
      :tags           => @tags,
      :check_location => @check_location,
      :unique_loot    => @unique_loot,
      :uid            => @uid,
    }).delete_if { |_a, b| b.nil? or (b.class == Array and b.empty?) };
    # can't remove empty wayto and timeto, fails test on repository server side
    JSON.pretty_generate(mapjson);
  end

  def Map.save_json(filename = "#{DATA_DIR}/#{XMLData.game}/map-#{Time.now.to_i}.json")
    if File.exist?(filename)
      respond "File exists!  Backing it up before proceeding..."
      begin
        File.open(filename, 'rb') { |infile|
          File.open("#{filename}.bak", "wb:UTF-8") { |outfile|
            outfile.write(infile.read)
          }
        }
      rescue
        respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
        Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      end
    end
    File.open(filename, 'wb:UTF-8') { |file|
      file.write(Map.to_json)
    }
    respond "#{filename} saved"
    Map.reload if Map[-1].id != Map[Map[-1].id].id
  end

  def Map.save_xml(filename = "#{DATA_DIR}/#{XMLData.game}/map-#{Time.now.to_i}.xml")
    if File.exist?(filename)
      respond "File exists!  Backing it up before proceeding..."
      begin
        File.open(filename, 'rb') { |infile|
          File.open("#{filename}.bak", "wb") { |outfile|
            outfile.write(infile.read)
          }
        }
      rescue
        respond "--- Lich: error: #{$!}\n\t#{$!.backtrace[0..1].join("\n\t")}"
        Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      end
    end
    begin
      escape = { '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => "&apos;", '&' => '&amp;' }
      File.open(filename, 'w') { |file|
        file.write "<map>\n"
        @@list.each { |room|
          next if room == nil
          if room.location
            location = " location=#{(room.location.gsub(/(<|>|"|'|&)/) { escape[$1] }).inspect}"
          else
            location = ''
          end
          if room.climate
            climate = " climate=#{(room.climate.gsub(/(<|>|"|'|&)/) { escape[$1] }).inspect}"
          else
            climate = ''
          end
          if room.terrain
            terrain = " terrain=#{(room.terrain.gsub(/(<|>|"|'|&)/) { escape[$1] }).inspect}"
          else
            terrain = ''
          end
          file.write "   <room id=\"#{room.id}\"#{location}#{climate}#{terrain}>\n"
          room.title.each { |title| file.write "      <title>#{title.gsub(/(<|>|"|'|&)/) { escape[$1] }}</title>\n" }
          room.description.each { |desc| file.write "      <description>#{desc.gsub(/(<|>|"|'|&)/) { escape[$1] }}</description>\n" }
          room.paths.each { |paths| file.write "      <paths>#{paths.gsub(/(<|>|"|'|&)/) { escape[$1] }}</paths>\n" }
          room.tags.each { |tag| file.write "      <tag>#{tag.gsub(/(<|>|"|'|&)/) { escape[$1] }}</tag>\n" }
          room.uid.each { |u| file.write "      <uid>#{u}</uid>\n" }
          room.unique_loot.to_a.each { |loot| file.write "      <unique_loot>#{loot.gsub(/(<|>|"|'|&)/) { escape[$1] }}</unique_loot>\n" }
          file.write "      <image name=\"#{room.image.gsub(/(<|>|"|'|&)/) { escape[$1] }}\" coords=\"#{room.image_coords.join(',')}\" />\n" if room.image and room.image_coords
          room.wayto.keys.each { |target|
            if room.timeto[target].class == Proc
              cost = " cost=\"#{room.timeto[target]._dump.gsub(/(<|>|"|'|&)/) { escape[$1] }}\""
            elsif room.timeto[target]
              cost = " cost=\"#{room.timeto[target]}\""
            else
              cost = ''
            end
            if room.wayto[target].class == Proc
              file.write "      <exit target=\"#{target}\" type=\"Proc\"#{cost}>#{room.wayto[target]._dump.gsub(/(<|>|"|'|&)/) { escape[$1] }}</exit>\n"
            else
              file.write "      <exit target=\"#{target}\" type=\"#{room.wayto[target].class}\"#{cost}>#{room.wayto[target].gsub(/(<|>|"|'|&)/) { escape[$1] }}</exit>\n"
            end
          }
          file.write "   </room>\n"
        }
        file.write "</map>\n"
      }
      @@tags.clear
      respond "--- map database saved to: #{filename}"
    rescue
      respond $!
    end
    GC.start
  end

  def Map.estimate_time(array)
    Map.load unless @@loaded
    unless array.class == Array
      raise Exception.exception("MapError"), "Map.estimate_time was given something not an array!"
    end
    time = 0.to_f
    until array.length < 2
      room = array.shift
      if (t = Map[room].timeto[array.first.to_s])
        if t.class == Proc
          time += t.call.to_f
        else
          time += t.to_f
        end
      else
        time += "0.2".to_f
      end
    end
    return time
  end

  def Map.dijkstra(source, destination = nil)
    if source.class == Map
      return source.dijkstra(destination)
    elsif (room = Map[source])
      return room.dijkstra(destination)
    else
      echo "Map.dijkstra: error: invalid source room"
      return nil
    end
  end

  def dijkstra(destination = nil)
    begin
      Map.load unless @@loaded
      source = @id
      visited = Array.new
      shortest_distances = Array.new
      previous = Array.new
      pq = [source]
      pq_push = proc { |val|
        for i in 0...pq.size
          if shortest_distances[val] <= shortest_distances[pq[i]]
            pq.insert(i, val)
            break
          end
        end
        pq.push(val) if i.nil? or (i == pq.size - 1)
      }
      visited[source] = true
      shortest_distances[source] = 0
      if destination.nil?
        until pq.size == 0
          v = pq.shift
          visited[v] = true
          @@list[v].wayto.keys.each { |adj_room|
            adj_room_i = adj_room.to_i
            unless visited[adj_room_i]
              if @@list[v].timeto[adj_room].class == Proc
                nd = @@list[v].timeto[adj_room].call
              else
                nd = @@list[v].timeto[adj_room]
              end
              if nd
                nd += shortest_distances[v]
                if shortest_distances[adj_room_i].nil? or (shortest_distances[adj_room_i] > nd)
                  shortest_distances[adj_room_i] = nd
                  previous[adj_room_i] = v
                  pq_push.call(adj_room_i)
                end
              end
            end
          }
        end
      elsif destination.class == Integer
        until pq.size == 0
          v = pq.shift
          break if v == destination
          visited[v] = true
          @@list[v].wayto.keys.each { |adj_room|
            adj_room_i = adj_room.to_i
            unless visited[adj_room_i]
              if @@list[v].timeto[adj_room].class == Proc
                nd = @@list[v].timeto[adj_room].call
              else
                nd = @@list[v].timeto[adj_room]
              end
              if nd
                nd += shortest_distances[v]
                if shortest_distances[adj_room_i].nil? or (shortest_distances[adj_room_i] > nd)
                  shortest_distances[adj_room_i] = nd
                  previous[adj_room_i] = v
                  pq_push.call(adj_room_i)
                end
              end
            end
          }
        end
      elsif destination.class == Array
        dest_list = destination.collect { |dest| dest.to_i }
        until pq.size == 0
          v = pq.shift
          break if dest_list.include?(v) and (shortest_distances[v] < 20)
          visited[v] = true
          @@list[v].wayto.keys.each { |adj_room|
            adj_room_i = adj_room.to_i
            unless visited[adj_room_i]
              if @@list[v].timeto[adj_room].class == Proc
                nd = @@list[v].timeto[adj_room].call
              else
                nd = @@list[v].timeto[adj_room]
              end
              if nd
                nd += shortest_distances[v]
                if shortest_distances[adj_room_i].nil? or (shortest_distances[adj_room_i] > nd)
                  shortest_distances[adj_room_i] = nd
                  previous[adj_room_i] = v
                  pq_push.call(adj_room_i)
                end
              end
            end
          }
        end
      end
      return previous, shortest_distances
    rescue
      echo "Map.dijkstra: error: #{$!}"
      respond $!.backtrace
      nil
    end
  end

  def Map.findpath(source, destination)
    if source.class == Map
      source.path_to(destination)
    elsif (room = Map[source])
      room.path_to(destination)
    else
      echo "Map.findpath: error: invalid source room"
      nil
    end
  end

  def path_to(destination)
    Map.load unless @@loaded
    destination = destination.to_i
    previous, _shortest_distances = dijkstra(destination)
    return nil unless previous[destination]
    path = [destination]
    path.push(previous[path[-1]]) until previous[path[-1]] == @id
    path.reverse!
    path.pop
    return path
  end

  def find_nearest_by_tag(tag_name)
    target_list = Array.new
    @@list.each { |room| target_list.push(room.id) if room.tags.include?(tag_name) }
    _previous, shortest_distances = Map.dijkstra(@id, target_list)
    if target_list.include?(@id)
      @id
    else
      target_list.delete_if { |room_num| shortest_distances[room_num].nil? }
      target_list.sort { |a, b| shortest_distances[a] <=> shortest_distances[b] }.first
    end
  end

  def find_all_nearest_by_tag(tag_name)
    target_list = Array.new
    @@list.each { |room| target_list.push(room.id) if room.tags.include?(tag_name) }
    _previous, shortest_distances = Map.dijkstra(@id)
    target_list.delete_if { |room_num| shortest_distances[room_num].nil? }
    target_list.sort { |a, b| shortest_distances[a] <=> shortest_distances[b] }
  end

  def find_nearest(target_list)
    target_list = target_list.collect { |num| num.to_i }
    if target_list.include?(@id)
      @id
    else
      _previous, shortest_distances = Map.dijkstra(@id, target_list)
      target_list.delete_if { |room_num| shortest_distances[room_num].nil? }
      target_list.sort { |a, b| shortest_distances[a] <=> shortest_distances[b] }.first
    end
  end
end

class Room < Map
  def Room.method_missing(*args)
    super(*args)
  end
end

# deprecated
class Map
  def desc; return @description; end
  def map_name; return @image; end
  def map_x; return @image_coords.nil? ? nil : ((image_coords[0] + image_coords[2]) / 2.0).round; end
  def map_y; return @image_coords.nil? ? nil : ((image_coords[1] + image_coords[3]) / 2.0).round; end
  def map_roomsize; return @image_coords.nil? ? nil : image_coords[2] - image_coords[0]; end
  def geo; return nil; end
end
