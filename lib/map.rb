class Map
  @@loaded                   = false
  @@load_mutex               = Mutex.new
  @@list                   ||= Array.new
  @@tags                   ||= Array.new
  @@current_room_mutex       = Mutex.new
  @@current_room_id        ||= -1
  @@current_room_count     ||= -1
  @@fuzzy_room_mutex         = Mutex.new
  @@fuzzy_room_id          ||= -1
  @@fuzzy_room_count       ||= -1
  @@current_location       ||= nil
  @@current_location_count ||= -1
  @@elevated_load            = proc { Map.load }
  @@elevated_load_dat        = proc { Map.load_dat }
  @@elevated_load_json       = proc { Map.load_json }
  @@elevated_load_xml        = proc { Map.load_xml }
  @@elevated_save            = proc { Map.save }
  @@elevated_save_xml        = proc { Map.save_xml }
  @@current_room_uid       ||= -1
  @@previous_room_id       ||= -1
  @@uids                     = {}
  @@last_seen_objects = nil
  attr_reader :id
  attr_accessor :title, :description, :paths, :uid, :location, :climate, :terrain, :wayto, :timeto, :image, :image_coords, :tags, :check_location, :unique_loot, :uid, :room_objects
  def initialize(id, title, description, paths, uid = [], location=nil, climate=nil, terrain=nil, wayto={}, timeto={}, image=nil, image_coords=nil, tags=[], check_location=nil, unique_loot=nil, room_objects=nil)
    @id, @title, @description, @paths, @uid, @location, @climate, @terrain, @wayto, @timeto, @image, @image_coords, @tags, @check_location, @unique_loot = id, title, description, paths, uid, location, climate, terrain, wayto, timeto, image, image_coords, tags, check_location, unique_loot
    @@list[@id] = self
  end
  def outside?
    @paths.first =~ /Obvious paths:/
  end
  def Map.last_seen_objects=(val)
    @@last_seen_objects = val
  end
  def Map.last_seen_objects
    @@last_seen_objects
  end
  def to_i
    @id
  end
  def to_s
    "##{@id} (#{@uid[-1]}):\n#{@title[-1]}\n#{@description[-1]}\n#{@paths[-1]}"
  end
  def inspect
    self.instance_variables.collect { |var| var.to_s + "=" + self.instance_variable_get(var).inspect }.join("\n")
  end
  def Map.fuzzy_room_id()
    return @@fuzzy_room_id
  end
  def Map.get_free_id
    Map.load unless @@loaded
    return @@list.compact.max_by{ |r| r.id}.id + 1
  end
  def Map.list
    Map.load unless @@loaded
    @@list
  end
  def Map.[](val)
    Map.load unless @@loaded
    if (val.class == Integer) or (val.class == Bignum) or val =~ /^[0-9]+$/
      @@list[val.to_i]
    elsif val =~ /^u(-?\d+)$/i
      uid_request = $1.dup.to_i
      @@list[(Map.ids_from_uid(uid_request)[0]).to_i]
    else
      chkre = /#{val.strip.sub(/\.$/, '').gsub(/\.(?:\.\.)?/, '|')}/i
      chk = /#{Regexp.escape(val.strip)}/i
      @@list.find { |room| room.title.find { |title| title =~ chk } } || @@list.find { |room| room.description.find { |desc| desc =~ chk } } || @@list.find { |room| room.description.find { |desc| desc =~ chkre } }
    end
  end
  def Map.get_location
    unless XMLData.room_count == @@current_location_count
      if script = Script.current
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
        nil
      end
    end
    @@current_location
  end
  def Map.previous
    return @@list[@@previous_room_id]
  end
  def Map.previous_uid
    return XMLData.previous_nav_rm
  end
  def Map.current
    Map.load unless @@loaded
    if script = Script.current
      @@current_room_mutex.synchronize {
        if XMLData.room_count == @@current_room_count
          if @@current_room_id.nil?
            return nil
          else
            return @@list[@@current_room_id]
          end
        else
          peer_history = Hash.new
          need_set_desc_off = false
          check_peer_tag = proc { |r|
            begin
              script.ignore_pause = true
              peer_room_count = XMLData.room_count
              if peer_tag = r.tags.find { |tag| tag =~ /^(set desc on; )?peer [a-z]+ =~ \/.+\/$/ }
                good = false
                need_desc, peer_direction, peer_requirement = /^(set desc on; )?peer ([a-z]+) =~ \/(.+)\/$/.match(peer_tag).captures
                need_desc = need_desc ? true : false
                if peer_history[peer_room_count][peer_direction][need_desc].nil?
                  if need_desc
                    unless last_roomdesc = $_SERVERBUFFER_.reverse.find { |line| line =~ /<style id="roomDesc"\/>/ } and (last_roomdesc =~ /<style id="roomDesc"\/>[^<]/)
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
                      if line = get?
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
            1.times {
              @@current_room_count = XMLData.room_count
              foggy_exits = (XMLData.room_exits_string =~ /^Obvious (?:exits|paths): obscured by a thick fog$/)
              shortlist = Map.ids_from_uid(XMLData.room_id)
              if shortlist.size > 0
                shortlist.each { |s|
                  r = @@list[s]
                  if  (!@@current_room_id.nil? and @@list[@@current_room_id].wayto.keys.include?(s.to_s)) or
                      (r.title.include?(XMLData.room_title) and 
                       r.description.include?(XMLData.room_description.strip) and 
                      (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and
                      (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths') and
                      (r.room_objects.nil? || r.room_objects.all?{|obj| /\b#{obj}\b/ =~ Map.last_seen_objects } ) )
                    )
                    room = r
                    @@previous_room_id = @@current_room_id
                    @@current_room_id = room.id
                    return room
                  end
                }
              end
              if room = @@list.find { |r| r.title.include?(XMLData.room_title) and 
                  r.description.include?(XMLData.room_description.strip) and 
                  (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and 
                  (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and
                  (not r.check_location or r.location == Map.get_location) and check_peer_tag.call(r) and
                  (r.room_objects.nil? || r.room_objects.all?{|obj| /\b#{obj}\b/ =~ Map.last_seen_objects } )
                }
                redo unless @@current_room_count == XMLData.room_count
                @@previous_room_id = @@current_room_id
                @@current_room_id = room.id
                return room
              else
                redo unless @@current_room_count == XMLData.room_count
                desc_regex = /#{Regexp.escape(XMLData.room_description.strip.sub(/\.+$/, '')).gsub(/\\\.(?:\\\.\\\.)?/, '|')}/
                if room = @@list.find { |r| r.title.include?(XMLData.room_title) and
                    (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and 
                    (XMLData.room_window_disabled or r.description.any? { |desc| desc =~ desc_regex }) and 
                    (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and 
                    (not r.check_location or r.location == Map.get_location) and check_peer_tag.call(r) and
                    (r.room_objects.nil? || r.room_objects.all?{|obj| /\b#{obj}\b/ =~ Map.last_seen_objects } )
                  }
                  redo unless @@current_room_count == XMLData.room_count
                  @@previous_room_id = @@current_room_id
                  @@current_room_id = room.id
                  return room
                else
                  redo unless @@current_room_count == XMLData.room_count
                  @@previous_room_id = @@current_room_id
                  @@current_room_id = nil
                  return nil
                end
              end
            }
          ensure
            put 'set description off' if need_set_desc_off
          end
        end
      }
    else
      @@fuzzy_room_mutex.synchronize {
        if XMLData.room_count == @@current_room_count
          if @@current_room_id.nil?
            return nil
          else
            return @@list[@@current_room_id]
          end
        elsif XMLData.room_count == @@fuzzy_room_count
          if @@fuzzy_room_id.nil?
            return nil
          else
            return @@list[@@fuzzy_room_id]
          end
        else
          @@fuzzy_room_count = XMLData.room_count
          1.times {
            foggy_exits = (XMLData.room_exits_string =~ /^Obvious (?:exits|paths): obscured by a thick fog$/)
            shortlist = [] + Map.ids_from_uid(XMLData.room_id)
            if shortlist.size > 0
              shortlist.each_with_index { |s,x|
                r = @@list[s]
                if ((r.title.include?(XMLData.room_title) and 
                      r.description.include?(XMLData.room_description.strip) and 
                     (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and
                     (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and
                     (r.room_objects.nil? || r.room_objects.all?{|obj| /\b#{obj}\b/ =~ Map.last_seen_objects } )
                    )
                  )
                  room = r
                  @@previous_room_id = @@current_room_id if x == 0
                  @@current_room_id = room.id            if x == 0
                  @@fuzzy_room_id = room.id
                  return room
                end
              }
            end
            if (room = @@list.find { |r| r.title.include?(XMLData.room_title) and 
                r.description.include?(XMLData.room_description.strip) and 
                (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and 
                (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and 
                (not r.check_location or r.location == Map.get_location) and
                (r.room_objects.nil? || r.room_objects.all?{|obj| /\b#{obj}\b/ =~ Map.last_seen_objects } )
              })
              redo unless @@fuzzy_room_count == XMLData.room_count
              if room.tags.any? { |tag| tag =~ /^(set desc on; )?peer [a-z]+ =~ \/.+\/$/ }
                @@fuzzy_room_id = nil
                return nil
              else
                @@fuzzy_room_id = room.id
                return room
              end
            else
              redo unless @@fuzzy_room_count == XMLData.room_count
              desc_regex = /#{Regexp.escape(XMLData.room_description.strip.sub(/\.+$/, '')).gsub(/\\\.(?:\\\.\\\.)?/, '|')}/
              if room = @@list.find { |r| r.title.include?(XMLData.room_title) and 
                  (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and 
                  (XMLData.room_window_disabled or r.description.any? { |desc| desc =~ desc_regex }) and 
                  (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and 
                  (not r.check_location or r.location == Map.get_location) and
                  (r.room_objects.nil? || r.room_objects.all?{|obj| /\b#{obj}\b/ =~ Map.last_seen_objects } )
                }
                redo unless @@fuzzy_room_count == XMLData.room_count
                if room.tags.any? { |tag| tag =~ /^(set desc on; )?peer [a-z]+ =~ \/.+\/$/ }
                  @@fuzzy_room_id = nil
                  return nil
                else
                  @@fuzzy_room_id = room.id
                  return room
                end
              else
                redo unless @@fuzzy_room_count == XMLData.room_count
                @@fuzzy_room_id = nil
                return nil
              end
            end
          }
        end
      }
    end
  end
  def Map.current_or_new
    return nil unless Script.current
    if XMLData.game =~ /DR/
      @@current_room_count = -1
      @@fuzzy_room_count = -1
      Map.current || Map.new(Map.get_free_id, [ XMLData.room_title ], [ XMLData.room_description.strip ], [ XMLData.room_exits_string.strip ], [XMLData.room_id] )
    else
      check_peer_tag = proc { |r|
        if peer_tag = r.tags.find { |tag| tag =~ /^(set desc on; )?peer [a-z]+ =~ \/.+\/$/ }
          good = false
          need_desc, peer_direction, peer_requirement = /^(set desc on; )?peer ([a-z]+) =~ \/(.+)\/$/.match(peer_tag).captures
          if need_desc
            unless last_roomdesc = $_SERVERBUFFER_.reverse.find { |line| line =~ /<style id="roomDesc"\/>/ } and (last_roomdesc =~ /<style id="roomDesc"\/>[^<]/)
              put 'set description on'
            end
          end
          script = Script.current
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
              if line = get?
                peer_results.push line
                break if line =~ /^Obvious/
              end
            }
            if peer_results.any? { |line| line =~ /#{peer_requirement}/ }
              good = true
            end
          end
          script.want_downstream = save_want_downstream
        else
          good = true
        end
        good
      }
      current_location = Map.get_location
      foggy_exits = (XMLData.room_exits_string =~ /^Obvious (?:exits|paths): obscured by a thick fog$/)
      shortlist = [] + Map.ids_from_uid(XMLData.room_id)
      if shortlist.size > 0
        shortlist.each { |s|
          r = @@list[s]
          if (r.wayto.keys.include?(@@current_room_id.to_s)) or
             (@@list[@@current_room_id].wayto.keys.include?(s.to_s)) or
             (r.title.include?(XMLData.room_title) and 
                r.description.include?(XMLData.room_description.strip) and 
               (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and
               (foggy_exits or r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths'))
             )
            room = r
            return room
          end
          }
      end
      if room = @@list.find { |r| (r.location == current_location) and r.title.include?(XMLData.room_title) and
          r.description.include?(XMLData.room_description.strip) and 
          (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and 
          (r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and 
          check_peer_tag.call(r) 
        }
        return room
      elsif room = @@list.find { |r| r.location.nil? and r.title.include?(XMLData.room_title) and 
          r.description.include?(XMLData.room_description.strip) and 
          (r.unique_loot.nil? or (r.unique_loot.to_a - GameObj.loot.to_a.collect { |obj| obj.name }).empty?) and 
          (r.paths.include?(XMLData.room_exits_string.strip) or r.tags.include?('random-paths')) and 
          check_peer_tag.call(r) 
        }
        room.location = current_location
        return room
      else
        title       = [ XMLData.room_title ]
        description = [ XMLData.room_description.strip ]
        paths       = [ XMLData.room_exits_string.strip ]
        uid         = [ XMLData.room_id ] 
        room        = Map.new(Map.get_free_id, title, description, paths, uid, current_location)
        identical_rooms = @@list.find_all { |r| (r.location != current_location) and 
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
        return room
      end
    end
  end
  def Map.tags
    Map.load unless @@loaded
    if @@tags.empty?
      @@list.each { |r| 
        r.tags.each { |t| 
          @@tags.push(t) unless @@tags.include?(t) 
        } 
      }
    end
    @@tags.dup
  end
  def Map.load_uids()
    Map.load unless @@loaded
    @@uids.clear
    @@list.each { |r| 
        r.uid.each { |u| 
        if @@uids[u].nil?
          @@uids[u] = [ r.id ]
        else
          @@uids[u] << r.id if !@@uids[u].include?(r.id)
        end
        }
       }
  end
  def Map.ids_from_uid(n)
    return (@@uids[n].nil? ? [] : @@uids[n])
  end
  def Map.clear
    @@load_mutex.synchronize {
      @@list.clear
      @@tags.clear
      @@loaded = false
      GC.start
    }
    true
  end
  def Map.reload
    Map.clear
    Map.load
  end
  def Map.load(filename=nil)
    if $SAFE == 0
      if filename.nil?
        file_list = Dir.entries("#{DATA_DIR}/#{XMLData.game}").find_all { |filename| filename =~ /^map\-[0-9]+\.(?:dat|xml|json)$/i }.collect { |filename| "#{DATA_DIR}/#{XMLData.game}/#{filename}" }.sort.reverse
      else
        file_list = [ filename ]
      end
      if file_list.empty?
        respond "--- Lich: error: no map database found"
        return false
      end
      while filename = file_list.shift
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
    else
      @@elevated_load.call
    end
  end
  def Map.load_json(filename=nil)
    if $SAFE == 0
      @@load_mutex.synchronize {
        if @@loaded
          return true
        else
          if filename
            file_list = [ filename ]
            #respond "--- loading #{filename}" #if error
          else
            file_list = Dir.entries("#{DATA_DIR}/#{XMLData.game}").find_all { |filename|
              filename =~ /^map\-[0-9]+\.json$/i
            }.collect { |filename|
              "#{DATA_DIR}/#{XMLData.game}/#{filename}"
            }.sort.reverse
            #respond "--- loading #{filename}" #if error
          end
          if file_list.empty?
            respond "--- Lich: error: no map database found"
            return false
          end
          error = false
          while filename = file_list.shift
            if File.exists?(filename)
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
                  room['tags'] ||= []
                  room['uid'] ||= []
                  Map.new(room['id'], room['title'], room['description'], room['paths'], room['uid'], room['location'], room['climate'], room['terrain'], room['wayto'], room['timeto'], room['image'], room['image_coords'], room['tags'], room['check_location'], room['unique_loot'])
                }
              }
              @@tags.clear
              respond "--- Map loaded #{filename}" #if error
              @@loaded = true
              Map.load_uids
              return true
            end
          end
        end
      }
    else
      @@elevated_load_json.call
    end
  end
  def Map.load_dat(filename=nil)
    if $SAFE == 0
      @@load_mutex.synchronize {
        if @@loaded
          return true
        else
          if filename.nil?
            file_list = Dir.entries("#{DATA_DIR}/#{XMLData.game}").find_all { |filename| filename =~ /^map\-[0-9]+\.dat$/ }.collect { |filename| "#{DATA_DIR}/#{XMLData.game}/#{filename}" }.sort.reverse
          else
            file_list = [ filename ]
            respond "--- file_list = #{filename.inspect}"
          end
          if file_list.empty?
            respond "--- Lich: error: no map database found"
            return false
          end
          error = false
          while filename = file_list.shift
            begin
              @@list = File.open(filename, 'rb') { |f| Marshal.load(f.read) }
              respond "--- Map loaded #{filename}" #if error
              
              @@loaded = true
              Map.load_uids
              return true
            rescue
              error = true
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
    else
      @@elevated_load_dat.call
    end
  end
  def Map.load_xml(filename="#{DATA_DIR}/#{XMLData.game}/map.xml")
    if $SAFE == 0
      @@load_mutex.synchronize {
        if @@loaded
          return true
        else
          unless File.exists?(filename)
            raise Exception.exception("MapDatabaseError"), "Fatal error: file `#{filename}' does not exist!"
          end
          missing_end = false
          current_tag = nil
          current_attributes = nil
          room = nil
          buffer = String.new
          unescape = { 'lt' => '<', 'gt' => '>', 'quot' => '"', 'apos' => "'", 'amp' => '&' }
          tag_start = proc { |element,attributes|
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
              room['room_objects'] = Array.new
            elsif element =~ /^(?:image|tsoran)$/ and attributes['name'] and attributes['x'] and attributes['y'] and attributes['size']
              room['image'] = attributes['name']
              room['image_coords'] = [ (attributes['x'].to_i - (attributes['size']/2.0).round), (attributes['y'].to_i - (attributes['size']/2.0).round), (attributes['x'].to_i + (attributes['size']/2.0).round), (attributes['y'].to_i + (attributes['size']/2.0).round) ]
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
            elsif current_tag =~ /^(?:title|description|paths|unique_loot|room_objects)$/
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
              room['room_objects'] = nil if room['room_objects'].empty?
              Map.new(room['id'], room['title'], room['description'], room['paths'], room['uid'], room['location'], room['climate'], room['terrain'], room['wayto'], room['timeto'], room['image'], room['image_coords'], room['tags'], room['check_location'], room['unique_loot'], room['room_objects'])
            elsif element == 'map'
              missing_end = false
            end
            current_tag = nil
          }
          begin
            File.open(filename) { |file|
              while line = file.gets
                buffer.concat(line)
                # fixme: remove   (?=<)   ?
                while str = buffer.slice!(/^<([^>]+)><\/\1>|^[^<]+(?=<)|^<[^<]+>/)
                  if str[0,1] == '<'
                    if str[1,1] == '/'
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
                        tag_end.call(element) if str[-2,1] == '/'
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
    else
      @@elevated_load_xml.call
    end
  end
  def Map.save(filename="#{DATA_DIR}/#{XMLData.game}/map-#{Time.now.to_i}.dat")
    if $SAFE == 0
      if File.exists?(filename)
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
    else
      @@elevated_save.call
    end
  end
  def Map.to_json(*args)
    @@list.delete_if { |r| r.nil? }
    @@list.to_json(args)
  end
  def to_json(*args)
    mapjson = ({
      :id => @id,
      :title => @title,
      :description => @description,
      :paths => @paths,
      :location => @location,
      :climate => @climate,
      :terrain => @terrain,
      :wayto => @wayto,
      :timeto => @timeto,
      :image => @image,
      :image_coords => @image_coords,
      :tags => @tags,
      :check_location => @check_location,
      :unique_loot => @unique_loot,
      :uid => @uid,
    }).delete_if { |a,b| b.nil? or (b.class == Array and b.empty?) };
    JSON.pretty_generate(mapjson);
  end
  def Map.save_json(filename="#{DATA_DIR}/#{XMLData.game}/map-#{Time.now.to_i}.json")
    if File.exists?(filename)
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
  end
  def Map.save_xml(filename="#{DATA_DIR}/#{XMLData.game}/map-#{Time.now.to_i}.xml")
    if $SAFE == 0
      if File.exists?(filename)
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
            room.room_objects.to_a.each { |loot| file.write "      <room_objects>#{loot.gsub(/(<|>|"|'|&)/) { escape[$1] }}</room_objects>\n" }
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
    else
      @@elevated_save_xml.call
    end
  end
  def Map.estimate_time(array)
    Map.load unless @@loaded
    unless array.class == Array
      raise Exception.exception("MapError"), "Map.estimate_time was given something not an array!"
    end
    time = 0.to_f
    until array.length < 2
      room = array.shift
      if t = Map[room].timeto[array.first.to_s]
        if t.class == Proc
          time += t.call.to_f
        else
          time += t.to_f
        end
      else
        time += "0.2".to_f
      end
    end
    time
  end
  def Map.dijkstra(source, destination=nil)
    if source.class == Map
      source.dijkstra(destination)
    elsif room = Map[source]
      room.dijkstra(destination)
    else
      echo "Map.dijkstra: error: invalid source room"
      nil
    end
  end
  def dijkstra(destination=nil)
    begin
      Map.load unless @@loaded
      source = @id
      visited = Array.new
      shortest_distances = Array.new
      previous = Array.new
      pq = [ source ]
      pq_push = proc { |val|
        for i in 0...pq.size
          if shortest_distances[val] <= shortest_distances[pq[i]]
            pq.insert(i, val)
            break
          end
        end
        pq.push(val) if i.nil? or (i == pq.size-1)
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
    elsif room = Map[source]
      room.path_to(destination)
    else
      echo "Map.findpath: error: invalid source room"
      nil
    end
  end
  def path_to(destination)
    Map.load unless @@loaded
    destination = destination.to_i
    previous, shortest_distances = dijkstra(destination)
    return nil unless previous[destination]
    path = [ destination ]
    path.push(previous[path[-1]]) until previous[path[-1]] == @id
    path.reverse!
    path.pop
    return path
  end
  def find_nearest_by_tag(tag_name)
    target_list = Array.new
    @@list.each { |room| target_list.push(room.id) if room.tags.include?(tag_name) }
    previous, shortest_distances = Map.dijkstra(@id, target_list)
    if target_list.include?(@id)
      @id
    else
      target_list.delete_if { |room_num| shortest_distances[room_num].nil? }
      target_list.sort { |a,b| shortest_distances[a] <=> shortest_distances[b] }.first
    end
  end
  def find_all_nearest_by_tag(tag_name)
    target_list = Array.new
    @@list.each { |room| target_list.push(room.id) if room.tags.include?(tag_name) }
    previous, shortest_distances = Map.dijkstra(@id)
    target_list.delete_if { |room_num| shortest_distances[room_num].nil? }
    target_list.sort { |a,b| shortest_distances[a] <=> shortest_distances[b] }
  end
  def find_nearest(target_list)
    target_list = target_list.collect { |num| num.to_i }
    if target_list.include?(@id)
      @id
    else
      previous, shortest_distances = Map.dijkstra(@id, target_list)
      target_list.delete_if { |room_num| shortest_distances[room_num].nil? }
      target_list.sort { |a,b| shortest_distances[a] <=> shortest_distances[b] }.first
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
  def desc
    @description
  end
  def map_name
    @image
  end
  def map_x
    if @image_coords.nil?
      nil
    else
      ((image_coords[0] + image_coords[2])/2.0).round
    end
  end
  def map_y
    if @image_coords.nil?
      nil
    else
      ((image_coords[1] + image_coords[3])/2.0).round
    end
  end
  def map_roomsize
    if @image_coords.nil?
      nil
    else
      image_coords[2] - image_coords[0]
    end
  end
  def geo
    nil
  end
end
