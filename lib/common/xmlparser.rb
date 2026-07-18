=begin
xmlparser.rb: Core lich file that defines the data extracted from SIMU's XML.
=end

require File.join(LIB_DIR, 'common', 'xml_entities.rb')

module Lich
  module Common
    class XMLParser
      attr_reader :mana, :max_mana, :health, :max_health, :spirit, :max_spirit, :last_spirit,
                  :stamina, :max_stamina, :stance_text, :stance_value, :mind_text, :mind_value,
                  :prepared_spell, :encumbrance_text, :encumbrance_full_text, :encumbrance_value,
                  :indicator, :injuries, :injury_mode, :room_count, :room_name, :room_title, :room_description,
                  :room_exits, :room_exits_string, :familiar_room_title, :familiar_room_description,
                  :familiar_room_exits, :bounty_task, :server_time, :server_time_offset,
                  :dr_active_spells, :dr_active_spells_stellar_percentage, :dr_active_spells_slivers,
                  :roundtime_end, :cast_roundtime_end, :last_pulse, :level, :next_level_value,
                  :next_level_text, :society_task, :stow_container_id, :name, :game, :in_stream,
                  :player_id, :prompt, :current_target_ids, :current_target_id, :room_window_disabled,
                  :dialogs, :room_id, :previous_nav_rm, :concentration, :max_concentration,
                  :arrival_pcs, :room_player_hidden, :field_exp, :max_field_exp,
                  :ascension_exp, :exp, :until_next, :fashlonae, :lumnis, :rpa,
                  :room_climate, :room_terrain, :room_weather, :room_bonfire,
                  :room_inside, :room_water, :room_sanctuary, :room_realm, :assess
      attr_accessor :send_fake_tags

      @@warned_deprecated_spellfront = 0

      def initialize
        @buffer = String.new
        # @unescape = { 'lt' => '<', 'gt' => '>', 'quot' => '"', 'apos' => "'", 'amp' => '&' }
        @bold = false
        @active_tags = Array.new
        @active_ids = Array.new
        @last_tag = String.new
        @last_id = String.new
        @current_stream = String.new
        @current_style = String.new
        @stow_container_id = nil
        @obj_location = nil
        @obj_exist = nil
        @obj_noun = nil
        @obj_before_name = nil
        @obj_name = nil
        @obj_after_name = nil
        @pc = nil
        @last_obj = nil
        @in_stream = false
        @player_status = nil
        @fam_mode = String.new
        @room_window_disabled = false
        @wound_gsl = String.new
        @scar_gsl = String.new
        @send_fake_tags = false
        @prompt = String.new
        @nerve_tracker_num = 0
        @nerve_tracker_active = 'no'
        @server_time = Time.now.to_i
        @server_time_offset = 0.0
        @roundtime_end = 0
        @cast_roundtime_end = 0
        @last_pulse = Time.now.to_i
        @level = 0
        @next_level_value = 0
        @next_level_text = String.new
        @current_target_ids = Array.new
        @pending_crtr_status = Hash.new

        @room_count = 0
        @room_title = String.new
        @room_name = String.new
        @room_description = String.new
        @room_exits = Array.new
        @room_exits_string = String.new
        @room_climate = 0
        @room_terrain = 0
        @room_weather = 0
        @room_bonfire = 0
        @room_inside = 0
        @room_water = 0
        @room_sanctuary = 0
        @room_realm = 0

        @familiar_room_title = String.new
        @familiar_room_description = String.new
        @familiar_room_exits = Array.new

        @bounty_task = String.new
        @society_task = String.new

        @dr_active_spells = Hash.new
        @dr_active_spells_clear = false
        @dr_active_spells_tmp = Hash.new
        @dr_active_spell_tracking = false
        @dr_active_spells_stellar_percentage = 0
        @dr_active_spells_slivers = false
        @name = String.new
        @game = String.new
        @player_id = String.new
        @mana = 0
        @max_mana = 0
        @health = 0
        @max_health = 0
        @spirit = 0
        @max_spirit = 0
        @last_spirit = nil
        @stamina = 0
        @max_stamina = 0
        @concentration = 0
        @max_concentration = 0
        @stance_text = String.new
        @stance_value = 0
        @mind_text = String.new
        @mind_value = 0
        @field_exp = 0
        @max_field_exp = 0
        @ascension_exp = 0
        @exp = 0
        @until_next = 0
        @fashlonae = nil
        @lumnis = nil
        @rpa = nil
        @prepared_spell = 'None'
        @encumbrance_text = String.new
        @encumbrance_full_text = String.new
        @encumbrance_value = 0
        @indicator = Hash.new
        @injuries = { 'back' => { 'scar' => 0, 'wound' => 0 }, 'leftHand' => { 'scar' => 0, 'wound' => 0 }, 'rightHand' => { 'scar' => 0, 'wound' => 0 }, 'head' => { 'scar' => 0, 'wound' => 0 }, 'rightArm' => { 'scar' => 0, 'wound' => 0 }, 'abdomen' => { 'scar' => 0, 'wound' => 0 }, 'leftEye' => { 'scar' => 0, 'wound' => 0 }, 'leftArm' => { 'scar' => 0, 'wound' => 0 }, 'chest' => { 'scar' => 0, 'wound' => 0 }, 'leftFoot' => { 'scar' => 0, 'wound' => 0 }, 'rightFoot' => { 'scar' => 0, 'wound' => 0 }, 'rightLeg' => { 'scar' => 0, 'wound' => 0 }, 'neck' => { 'scar' => 0, 'wound' => 0 }, 'leftLeg' => { 'scar' => 0, 'wound' => 0 }, 'nsys' => { 'scar' => 0, 'wound' => 0 }, 'rightEye' => { 'scar' => 0, 'wound' => 0 } }
        @injury_mode = 0

        # psm 3.0 dialogdata updates
        @dialogs = {}

        # real id updates
        @room_id = nil
        @previous_nav_rm = nil

        # Lich::Claim update
        @arrival_pcs = []
        @check_obvious_hiding = false
        @room_player_hidden = false

        # assess (combat situation) stream tracking
        @assess = []
        @assess_buffer = nil
        @assess_ids = []

        # Ox SAX bridge state (see start_element/attr/attrs_done/error below):
        # the element/attributes being accumulated and parse errors for the
        # fragment currently being parsed.
        @sax_element = nil
        @sax_attributes = {}
        @sax_parse_errors = []
      end

      # for backwards compatibility
      def active_spells
        z = {}
        XMLData.dialogs.sort.each do |a, b|
          b.each do |k, v|
            case a
            when /Active Spells|Buffs/
              z.merge!(k => v) if k.instance_of?(String)
            when /Cooldowns/
              if k.to_s =~ /Recovery/
                z.merge!(k => v) if k.instance_of?(String)
              else
                z.merge!("#{k} Cooldown" => v) if k.instance_of?(String)
              end
            when /Debuffs/

              # need to deal with that pesky 'Silenced' versus 'Silence' from XML
              if k == "Silenced"
                k = 'Silence'
              end
              z.merge!(k => v) if k.instance_of?(String)
            end
          end
        end
        z
      end

      def reset
        @active_tags = Array.new
        @active_ids = Array.new
        @current_stream = String.new
        @current_style = String.new
        @sax_parse_errors = []
        # A <crtrStatus> tag can be fully parsed and cached here while the
        # matching bold <a> text is still in an as-yet-unparsed remainder of
        # the fragment. If a malformed/truncated fragment forces a reset in
        # that window, an uncleared entry would sit here indefinitely and
        # could misapply to an unrelated creature that later reuses the same
        # exist id (ids are recycled - see Creature.targets' notes).
        @pending_crtr_status.clear
      end

      def safe_to_respond?
        if @game =~ /^DR/
          !in_stream && !@bold && (!@current_style || @current_style.empty?)
        else
          return true
        end
      end

      def make_wound_gsl
        @wound_gsl = sprintf("0b0%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b", @injuries['nsys']['wound'], @injuries['leftEye']['wound'], @injuries['rightEye']['wound'], @injuries['back']['wound'], @injuries['abdomen']['wound'], @injuries['chest']['wound'], @injuries['leftHand']['wound'], @injuries['rightHand']['wound'], @injuries['leftLeg']['wound'], @injuries['rightLeg']['wound'], @injuries['leftArm']['wound'], @injuries['rightArm']['wound'], @injuries['neck']['wound'], @injuries['head']['wound'])
      end

      def make_scar_gsl
        @scar_gsl = sprintf("0b0%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b%02b", @injuries['nsys']['scar'], @injuries['leftEye']['scar'], @injuries['rightEye']['scar'], @injuries['back']['scar'], @injuries['abdomen']['scar'], @injuries['chest']['scar'], @injuries['leftHand']['scar'], @injuries['rightHand']['scar'], @injuries['leftLeg']['scar'], @injuries['rightLeg']['scar'], @injuries['leftArm']['scar'], @injuries['rightArm']['scar'], @injuries['neck']['scar'], @injuries['head']['scar'])
      end

      # def parse(line)
      #   @buffer.concat(line)
      #   loop {
      #     if (str = @buffer.slice!(/^[^<]+/))
      #       text(str.gsub(/&(lt|gt|quot|apos|amp)/) { @unescape[$1] })
      #     elsif (str = @buffer.slice!(/^<\/[^<]+>/))
      #       element = /^<\/([^\s>\/]+)/.match(str).captures.first
      #       tag_end(element)
      #     elsif (str = @buffer.slice!(/^<[^<]+>/))
      #       element = /^<([^\s>\/]+)/.match(str).captures.first
      #       attributes = Hash.new
      #       str.scan(/([A-z][A-z0-9_\-]*)=(["'])(.*?)\2/).each { |attr| attributes[attr[0]] = attr[2] }
      #       tag_start(element, attributes)
      #       tag_end(element) if str =~ /\/>$/
      #     else
      #       break
      #     end
      #   }
      # end

      DECADE = 10 * 31_536_000

      def parse_psm3_progressbar(kind, attributes)
        @dialogs[kind] ||= {}
        id = attributes["id"].to_i
        name = attributes["text"]
        value = attributes["time"]
        return unless name && value
        # set the expiry for a decade for infinite duration effects
        return @dialogs[kind][name] = @dialogs[kind][id] = Time.now + DECADE if value.downcase.eql?("indefinite")

        # in psm 3.0 progress bars now have second precision!
        hour, minute, second = value.split(':')
        @dialogs[kind][name] = @dialogs[kind][id] = Time.now + (hour.to_i * 3600) + (minute.to_i * 60) + second.to_i
      end

      PSM_3_DIALOG_IDS = ["Buffs", "Active Spells", "Debuffs", "Cooldowns"]

      # assess stream parsing
      ASSESS_RANGES = { 'melee' => :melee, 'pole weapon' => :pole, 'missile' => :missile }.freeze
      ASSESS_RELATION = /^(?<relation>moving to flank|flanking|facing|behind|in front of|beside|advancing on|next to|to (?:the )?(?:left|right) of)\s+(?<target>.+)$/.freeze

      # Parse a single reconstructed line from the 'assess' (combat situation) stream
      # into a structured entry. `ids` is the ordered list of look-target ids pulled
      # from the line's <d cmd='look #id'> tags (subject first, then target).
      # Returns a Hash, or nil for the header / unparseable lines.
      def parse_assess_line(text, ids)
        text = text.to_s.strip
        return nil if text.empty?
        return nil if text =~ /assess your combat situation/i

        # drop the trailing "  | F" face-hint (the F lives in a <d cmd='face #id'> tag);
        # anchored to the pipe + trailing token so a stray '|' mid-line can't eat text
        text = text.sub(/\s+\|\s+\S+\s*$/, '').strip

        m = text.match(/^(?<name>.+?)\s+\((?:(?<number>\d+):\s*)?(?<status>[^)]*)\)\s+(?:is|are)\s+(?<rest>.+?)\s+at\s+(?<range>melee|pole weapon|missile)\s+range\b/i)
        return nil unless m

        name   = m[:name].strip
        number = m[:number] && m[:number].to_i
        status = m[:status].strip
        range  = ASSESS_RANGES[m[:range].downcase]
        rest   = m[:rest].strip

        # the target may carry its own assess number, e.g. "facing a jeol moradu (2)"
        target_number = nil
        if rest =~ /\((\d+)\)\s*$/
          target_number = $1.to_i
          rest = rest.sub(/\s*\(\d+\)\s*$/, '').strip
        end

        if (rm = rest.match(ASSESS_RELATION))
          relation = rm[:relation]
          target   = rm[:target].strip
        else
          relation = rest
          target   = nil
        end
        relation = 'flanking' if relation == 'moving to flank'

        is_self = name.casecmp?('you')
        if is_self
          subject_id = nil
          target_id  = ids[0]
        else
          subject_id = ids[0]
          target_id  = (target && target =~ /^you$/i) ? nil : ids[1]
        end
        is_pc = subject_id.to_s.start_with?('-')

        {
          name: name, id: subject_id, number: number, status: status,
          relation: relation, target: target, target_id: target_id,
          target_number: target_number, range: range, self: is_self, pc: is_pc
        }
      end

      # convenience: just the creatures (positive ids; excludes self and PCs)
      def assess_creatures
        @assess.reject { |e| e[:self] || e[:pc] }
      end

      # Ox::Sax interface: Ox parses the server stream directly into XMLData (see
      # Game.process_xml_data). Ox fires start_element, then attr per attribute,
      # then attrs_done, then text/children, then end_element. Attributes are
      # accumulated and flushed to tag_start (matching the old REXML-style single
      # tag_start(name, hash) call). The game stream is Windows-1252, so byte
      # content is tagged with that encoding; names are ASCII.
      def start_element(name)
        @sax_element = name
        @sax_attributes = {}
      end

      # Values are left in Ox's native encoding rather than retagged: REXML handed
      # these callbacks UTF-8 (effectively ASCII for the scrubbed game stream), so
      # force-tagging Windows-1252 was both a divergence from the pre-Ox behavior
      # and the source of the entity corruption. Ox runs with convert_special:
      # false, so XmlEntities.decode restores the standard entities here.
      def attr(name, value)
        @sax_attributes[name] = XmlEntities.decode(value)
      end

      def attrs_done
        tag_start(@sax_element, @sax_attributes)
      end

      def end_element(name)
        tag_end(name)
      end

      # REXML routed CDATA through text handling; do the same.
      def cdata(value)
        text(value)
      end

      # Ox reports parse problems here instead of raising, then keeps parsing,
      # auto-balancing whatever was malformed. Collect the messages so
      # Game.process_xml_data can tell Simu's routine almost-XML from a
      # genuinely truncated (desynced) fragment once the parse completes.
      # The caller clears this between fragments.
      attr_reader :sax_parse_errors

      def error(message, line, column)
        @sax_parse_errors << "#{message} (line #{line}, column #{column})"
      end

      def tag_start(name, attributes)
        # This is called once per element by REXML in games.rb
        # https://ruby-doc.org/stdlib-2.6.1/libdoc/rexml/rdoc/REXML/StreamListener.html
        begin
          @active_tags.push(name)
          @active_ids.push(attributes['id'].to_s)

          if name == 'nav'
            Lich::Claim.lock if defined?(Lich::Claim)
            Lich::Gemstone::Overwatch.room_with_hiders_reset if defined?(Lich::Gemstone::Overwatch)
            GameObj.clear_loot
            GameObj.clear_npcs
            GameObj.clear_pcs
            GameObj.clear_room_desc
            # Creature tracks its own room roster independently of GameObj
            # (see lib/gemstone/creature.rb) - not loaded for DR sessions.
            Lich::Gemstone::Creature.clear_room if defined?(Lich::Gemstone::Creature)
            # Any <crtrStatus> cached for the room being left is scoped to
            # that room - don't let it survive to misapply if the id gets
            # reused elsewhere.
            @pending_crtr_status.clear
            @check_obvious_hiding = true
            unless XMLData.game =~ /^DR/
              @previous_nav_rm = @room_id
              @room_id = attributes['rm'].to_i
            end
            @arrival_pcs = []
            $nav_seen = true
          end

          if name == 'compass'
            if defined?(Lich::Claim) && Lich::Claim::Lock.owned?
              if @room_id == 0
                @room_id = Digest::MD5.hexdigest([@room_title, @room_description, @room_exits_string].to_s).to_i(16)
              end
              if @room_player_hidden
                @arrival_pcs.push(:hidden)
                @room_player_hidden = false
              end
              @check_obvious_hiding = false
              Lich::Claim.parser_handle(@room_id, @arrival_pcs)
              Lich::Claim.unlock
            end
            if @current_stream == 'familiar'
              @fam_mode = String.new
            elsif @room_window_disabled
              @room_exits = Array.new
            end
          end

          if (name == 'compDef') or (name == 'component')
            if attributes['id'] == 'room objs'
              GameObj.clear_loot
              GameObj.clear_npcs
              Lich::Gemstone::Creature.clear_room if defined?(Lich::Gemstone::Creature)
              @pending_crtr_status.clear
            elsif attributes['id'] == 'room players'
              GameObj.clear_pcs
            elsif attributes['id'] == 'room exits'
              @room_exits = Array.new
              @room_exits_string = String.new
            elsif attributes['id'] == 'room desc'
              @room_description = String.new
              GameObj.clear_room_desc
            end
          end

          if name =~ /^(?:a|right|left)$/
            @obj_exist = attributes['exist']
            @obj_noun = attributes['noun']
          end
          if name == 'crtrStatus'
            # Self-closing and self-contained (carries its own id), so it needs
            # no surrounding-tag context, unlike the bolded <a> name path below.
            # Always stash rather than applying directly even when the
            # creature is already known: Creature.register (and the room-in
            # marking it does) only ever runs from the <a> text path below, so
            # syncing here and skipping that path would update the instance's
            # flags correctly while silently leaving it out of the room
            # roster after the next clear_room - it would sync but never
            # reappear in Creature.targets/.in_room. Deferring to the text()
            # handler keeps registration/room-marking and flag application on
            # the same path for both new and already-known creatures.
            crtr_id = attributes['exist']
            @pending_crtr_status[crtr_id] = attributes.reject { |k, _| k == 'exist' } if crtr_id
          end
          if name == 'inv'
            if attributes['id'] == 'stow'
              @obj_location = @stow_container_id
            else
              @obj_location = attributes['id']
            end
            @obj_exist = nil
            @obj_noun = nil
            @obj_name = nil
            @obj_before_name = nil
            @obj_after_name = nil
          end
          if name == 'dialogData' and attributes['clear'] == 't' and PSM_3_DIALOG_IDS.include?(attributes["id"])
            @dialogs[attributes["id"]] ||= {}
            @dialogs[attributes["id"]].clear
            # detect a clear board request for effects, and send to activespell
            ActiveSpell.request_update
          end
          if name == 'resource'
            nil
          end
          if name == 'roommeta'
            @room_weather = attributes['weather'].to_i if attributes['weather']
            @room_bonfire = attributes['bonfire'].to_i if attributes['bonfire']
            @room_inside = attributes['inside'].to_i if attributes['inside']
            @room_water = attributes['water'].to_i if attributes['water']
            @room_sanctuary = attributes['sanctuary'].to_i if attributes['sanctuary']
            @room_realm = attributes['realm'].to_i if attributes['realm']
            @room_climate = attributes['climate'].to_i if attributes['climate']
            @room_terrain = attributes['terrain'].to_i if attributes['terrain']
          end
          if name == 'pushStream'
            @in_stream = true
            @current_stream = attributes['id'].to_s
            if attributes['id'].to_s == 'assess'
              @assess_buffer = String.new
              @assess_ids = []
            end
            if XMLData.game =~ /^GS/
              GameObj.clear_inv if attributes['id'].to_s == 'inv'
              GameObj.clear_reserve if attributes['id'].to_s == 'reserve'
            end
          end

          if name == 'd' && @current_stream == 'assess'
            @assess_ids << $1 if attributes['cmd'].to_s =~ /look #(-?\d+)/
          end
          if name == 'popStream'
            if @current_stream == 'assess' && @assess_buffer
              entry = parse_assess_line(@assess_buffer, @assess_ids)
              @assess << entry if entry
              @assess_buffer = nil
            end
            if attributes['id'] == 'room'
              unless @room_window_disabled
                @room_count += 1
                $room_count += 1
              end
            end
            @in_stream = false
            if attributes['id'] == 'bounty'
              @bounty_task.strip!
            end
            @current_stream = String.new
          end
          if name == 'pushBold'
            @bold = true
          end
          if name == 'popBold'
            @bold = false
          end
          if (name == 'streamWindow')
            if (attributes['id'] == 'main') and attributes['subtitle']
              unless attributes['subtitle'].empty? || attributes['subtitle'].nil?
                if XMLData.game =~ /^GS/
                  if Lich.display_uid == false && attributes['subtitle'][3..-1] =~ / - \d+$/
                    Lich.display_uid = true
                  end
                  @room_title = '[' + attributes['subtitle'][3..-1].gsub(/ - \d+$/, '') + ']'
                elsif XMLData.game =~ /^DR/
                  # - [Bosque Deriel, Hermit's Shacks] (230008)
                  room = attributes['subtitle'].match(/(?<roomtitle>\[.*?\])(?:\s\((?<uid>\d+)\))?/)
                  @room_title = "[#{room[:roomtitle]}]"
                  @room_id = room[:uid].to_i
                else
                  @room_title = String.new
                end
              end
            end
          end
          if name == 'style'
            @current_style = attributes['id']
          end
          if (name == 'clearStream' && attributes['id'] == 'percWindow')
            @dr_active_spells_clear = true
          end

          if (name == 'pushStream' && attributes['id'] == 'percWindow')
            @dr_active_spell_tracking = true
            @dr_active_spells_clear = false
          end

          if name == 'prompt'
            @server_time = attributes['time'].to_i
            @server_time_offset = (Time.now.to_f - @server_time)
            $_CLIENT_.puts "\034GSq#{sprintf('%010d', @server_time)}\r\n" if @send_fake_tags

            if @dr_active_spell_tracking
              @dr_active_spell_tracking = false
              @dr_active_spells_slivers = false
              @dr_active_spells = @dr_active_spells_tmp
              @dr_active_spells_tmp = {}
            elsif @dr_active_spells_clear
              @dr_active_spells = {}
            end
          end

          if name == 'clearContainer'
            if attributes['id'] == 'stow'
              GameObj.clear_container(@stow_container_id)
            else
              GameObj.clear_container(attributes['id'])
            end
          end
          if name == 'deleteContainer'
            GameObj.delete_container(attributes['id'])
          end
          if name == 'progressBar'
            if attributes['id'] == 'pbarStance'
              @stance_text = attributes['text'].split.first
              @stance_value = attributes['value'].to_i
              $_CLIENT_.puts "\034GSg#{sprintf('%010d', @stance_value)}\r\n" if @send_fake_tags
            elsif attributes['id'] == 'mana'
              last_mana = @mana
              @mana, @max_mana = attributes['text'].scan(/-?\d+/).collect { |num| num.to_i }
              difference = @mana - last_mana
              # fixme: enhancives screw this up
              unless XMLData.name.empty?
                if (difference == noded_pulse) or (difference == unnoded_pulse) or ((@mana == @max_mana) and (last_mana + noded_pulse > @max_mana))
                  @last_pulse = Time.now.to_i
                  if @send_fake_tags
                    $_CLIENT_.puts "\034GSZ#{sprintf('%010d', (@mana + 1))}\n"
                    $_CLIENT_.puts "\034GSZ#{sprintf('%010d', @mana)}\n"
                  end
                end
              end
              if @send_fake_tags
                $_CLIENT_.puts "\034GSV#{sprintf('%010d%010d%010d%010d%010d%010d%010d%010d', @max_health.to_i, @health.to_i, @max_spirit.to_i, @spirit.to_i, @max_mana.to_i, @mana.to_i, @wound_gsl, @scar_gsl)}\r\n"
              end
            elsif attributes['id'] == 'stamina'
              @stamina, @max_stamina = attributes['text'].scan(/-?\d+/).collect { |num| num.to_i }
            elsif attributes['id'] == 'mindState'
              @mind_text = attributes['text']
              @mind_value = attributes['value'].to_i
              @field_exp = attributes['field_exp'].to_i if attributes['field_exp']
              @max_field_exp = attributes['max_field_exp'].to_i if attributes['max_field_exp']
              @ascension_exp = attributes['ascension_exp'].to_i if attributes['ascension_exp']
              @exp = attributes['exp'].to_i if attributes['exp']
              @until_next = attributes['until_next'].to_i if attributes['until_next']
              # lumnis and rpa are only sent while active; fashlonae is sent
              # whenever an orb is redeemed (1 = redeemed/inactive, 2 = active).
              # All three are cleared back to nil whenever a fresh mindState
              # progressBar omits them. rpa can be fractional (e.g. 1.5), so it
              # is parsed as a float.
              @fashlonae = attributes['fashlonae'] ? attributes['fashlonae'].to_i : nil
              @lumnis = attributes['lumnis'] ? attributes['lumnis'].to_i : nil
              @rpa = attributes['rpa'] ? attributes['rpa'].to_f : nil
              $_CLIENT_.puts "\034GSr#{MINDMAP[@mind_text]}\r\n" if @send_fake_tags
            elsif attributes['id'] == 'health'
              @health, @max_health = attributes['text'].scan(/-?\d+/).collect { |num| num.to_i }
              $_CLIENT_.puts "\034GSV#{sprintf('%010d%010d%010d%010d%010d%010d%010d%010d', @max_health.to_i, @health.to_i, @max_spirit.to_i, @spirit.to_i, @max_mana.to_i, @mana.to_i, @wound_gsl, @scar_gsl)}\r\n" if @send_fake_tags
            elsif attributes['id'] == 'spirit'
              @last_spirit = @spirit if @last_spirit
              @spirit, @max_spirit = attributes['text'].scan(/-?\d+/).collect { |num| num.to_i }
              @last_spirit = @spirit unless @last_spirit
              $_CLIENT_.puts "\034GSV#{sprintf('%010d%010d%010d%010d%010d%010d%010d%010d', @max_health.to_i, @health.to_i, @max_spirit.to_i, @spirit.to_i, @max_mana.to_i, @mana.to_i, @wound_gsl, @scar_gsl)}\r\n" if @send_fake_tags
            elsif attributes['id'] == 'nextLvlPB'
              Gift.pulse unless @next_level_text == attributes['text']
              @next_level_value = attributes['value'].to_i
              @next_level_text = attributes['text']
            elsif attributes['id'] == 'encumlevel'
              @encumbrance_value = attributes['value'].to_i
              @encumbrance_text = attributes['text']
            elsif attributes['id'] == 'concentration'
              @concentration, @max_concentration = attributes['text'].scan(/-?\d+/).collect { |num| num.to_i }
            elsif PSM_3_DIALOG_IDS.include?(@active_ids[-2])
              # puts "kind=(%s) name=%s attributes=%s" % [@active_ids[-2], name, attributes]
              self.parse_psm3_progressbar(@active_ids[-2], attributes)
              # since we received an updated spell duration, let's signal infomon to update
              ActiveSpell.request_update
            end
          end
          if name == 'roundTime'
            @roundtime_end = attributes['value'].to_i
            $_CLIENT_.puts "\034GSQ#{sprintf('%010d', @roundtime_end)}\r\n" if @send_fake_tags
          end
          if name == 'castTime'
            @cast_roundtime_end = attributes['value'].to_i
          end
          if name == 'dropDownBox'
            if attributes['id'] == 'dDBTarget'
              @current_target_ids.clear
              attributes['content_value'].split(',').each { |t|
                if t =~ /^\#(\-?\d+)(?:,|$)/
                  @current_target_ids.push($1)
                end
              }
              if attributes['content_value'] =~ /^\#(\-?\d+)(?:,|$)/
                @current_target_id = $1
              else
                @current_target_id = nil
              end
            end
          end
          if name == 'indicator'
            @indicator[attributes['id']] = attributes['visible']
            if @send_fake_tags
              if attributes['id'] == 'IconPOISONED'
                if attributes['visible'] == 'y'
                  $_CLIENT_.puts "\034GSJ0000000000000000000100000000001\r\n"
                else
                  $_CLIENT_.puts "\034GSJ0000000000000000000000000000000\r\n"
                end
              elsif attributes['id'] == 'IconDISEASED'
                if attributes['visible'] == 'y'
                  $_CLIENT_.puts "\034GSK0000000000000000000100000000001\r\n"
                else
                  $_CLIENT_.puts "\034GSK0000000000000000000000000000000\r\n"
                end
              else
                gsl_prompt = String.new; ICONMAP.keys.each { |icon| gsl_prompt += ICONMAP[icon] if @indicator[icon] == 'y' }
                $_CLIENT_.puts "\034GSP#{sprintf('%-30s', gsl_prompt)}\r\n"
              end
            end
          end
          if (name == 'image') and @active_ids.include?('injuries')
            if @injuries.keys.include?(attributes['id'])
              if attributes['name'] =~ /Injury/i
                @injuries[attributes['id']]['wound'] = attributes['name'].slice(/\d/).to_i
              elsif attributes['name'] =~ /Scar/i
                @injuries[attributes['id']]['wound'] = 0
                @injuries[attributes['id']]['scar'] = attributes['name'].slice(/\d/).to_i
              elsif attributes['name'] =~ /Nsys/i
                rank = attributes['name'].slice(/\d/).to_i
                if rank == 0
                  @injuries['nsys']['wound'] = 0
                  @injuries['nsys']['scar'] = 0
                else
                  Thread.new {
                    wait_while { dead? }
                    action = proc { |server_string|
                      if (@nerve_tracker_active == 'maybe')
                        if @nerve_tracker_active == 'maybe'
                          if server_string =~ /^You/
                            @nerve_tracker_active = 'yes'
                            @injuries['nsys']['wound'] = 0
                            @injuries['nsys']['scar'] = 0
                          else
                            @nerve_tracker_active = 'no'
                          end
                        end
                      end
                      if @nerve_tracker_active == 'yes'
                        if server_string =~ /<output class=['"]['"]\/>/
                          @nerve_tracker_active = 'no'
                          @nerve_tracker_num -= 1
                          DownstreamHook.remove('nerve_tracker') if @nerve_tracker_num < 1
                          $_CLIENT_.puts "\034GSV#{sprintf('%010d%010d%010d%010d%010d%010d%010d%010d', @max_health.to_i, @health.to_i, @max_spirit.to_i, @spirit.to_i, @max_mana.to_i, @mana.to_i, make_wound_gsl, make_scar_gsl)}\r\n" if @send_fake_tags
                          server_string
                        elsif server_string =~ /a case of uncontrollable convulsions/
                          @injuries['nsys']['wound'] = 3
                          nil
                        elsif server_string =~ /a case of sporadic convulsions/
                          @injuries['nsys']['wound'] = 2
                          nil
                        elsif server_string =~ /a strange case of muscle twitching/
                          @injuries['nsys']['wound'] = 1
                          nil
                        elsif server_string =~ /a very difficult time with muscle control/
                          @injuries['nsys']['scar'] = 3
                          nil
                        elsif server_string =~ /constant muscle spasms/
                          @injuries['nsys']['scar'] = 2
                          nil
                        elsif server_string =~ /developed slurred speech/
                          @injuries['nsys']['scar'] = 1
                          nil
                        end
                      else
                        if server_string =~ /<output class=['"]mono['"]\/>/
                          @nerve_tracker_active = 'maybe'
                        end
                        server_string
                      end
                    }
                    @nerve_tracker_num += 1
                    DownstreamHook.add('nerve_tracker', action, persist: true) # engine-managed, toggled by the parser
                    Game._puts "#{$cmd_prefix}health"
                  }
                end
              else
                @injuries[attributes['id']]['wound'] = 0
                @injuries[attributes['id']]['scar'] = 0
              end
            end
            $_CLIENT_.puts "\034GSV#{sprintf('%010d%010d%010d%010d%010d%010d%010d%010d', @max_health.to_i, @health.to_i, @max_spirit.to_i, @spirit.to_i, @max_mana.to_i, @mana.to_i, make_wound_gsl, make_scar_gsl)}\r\n" if @send_fake_tags
          end
          if @room_window_disabled and (name == 'dir') and @active_tags.include?('compass')
            @room_exits.push(LONGDIR[attributes['value']])
          end
          if name == 'radio'
            if attributes['id'] == 'injrRad'
              @injury_mode = 0 if attributes['value'] == '1'
            elsif attributes['id'] == 'scarRad'
              @injury_mode = 1 if attributes['value'] == '1'
            elsif attributes['id'] == 'bothRad'
              @injury_mode = 2 if attributes['value'] == '1'
            end
          end
          if name == 'label'
            if attributes['id'] == 'yourLvl'
              @level = attributes['value'].slice(/\d+/).to_i
            elsif attributes['id'] == 'encumblurb'
              @encumbrance_full_text = attributes['value']
            end
          end
          if (name == 'container') and (attributes['id'] == 'stow')
            @stow_container_id = attributes['target'].sub('#', '')
          end
          if (name == 'clearStream')
            if attributes['id'] == 'bounty'
              @bounty_task = String.new
            elsif attributes['id'] == 'assess'
              @assess = []
            end
          end
          if (name == 'playerID')
            @player_id = attributes['id']
            unless Frontend.supports_gsl?
              if Lich.inventory_boxes(@player_id)
                DownstreamHook.remove('inventory_boxes_off')
              end
            end
          end
          if name == 'settingsInfo'
            if (game = attributes['instance'])
              if game == 'GS4'
                @game = 'GSIV'
              elsif (game == 'GSX') or (game == 'GS4X')
                @game = 'GSPlat'
              else
                @game = game # covers DR, DRT, DRF, GST, GSF
              end
            end
          end
          if (name == 'app') and (@name = attributes['char'])
            if @game.nil? or @game.empty?
              @game = 'unknown'
            end
            unless File.exist?("#{DATA_DIR}/#{@game}")
              Dir.mkdir("#{DATA_DIR}/#{@game}")
            end
            unless File.exist?("#{DATA_DIR}/#{@game}/#{@name}")
              Dir.mkdir("#{DATA_DIR}/#{@game}/#{@name}")
            end
            if Frontend.supports_gsl?
              Game._puts "#{$cmd_prefix}_flag Display Dialog Boxes 0"
              sleep 0.05
              Game._puts "#{$cmd_prefix}_injury 2"
              sleep 0.05
              # fixme: game name hardcoded as Gemstone IV; maybe doesn't make any difference to the client
              $_CLIENT_.puts "\034GSB0000000000#{attributes['char']}\r\n\034GSA#{Time.now.to_i}GemStone IV\034GSD\r\n"
              # Sending fake GSL tags to the Wizard FE is disabled until now, because it doesn't accept the tags and just gives errors until initialized with the above line
              @send_fake_tags = true
              # Send all the tags we missed out on
              $_CLIENT_.puts "\034GSV#{sprintf('%010d%010d%010d%010d%010d%010d%010d%010d', @max_health.to_i, @health.to_i, @max_spirit.to_i, @spirit.to_i, @max_mana.to_i, @mana.to_i, make_wound_gsl, make_scar_gsl)}\r\n"
              $_CLIENT_.puts "\034GSg#{sprintf('%010d', @stance_value)}\r\n"
              $_CLIENT_.puts "\034GSr#{MINDMAP[@mind_text]}\r\n"
              gsl_prompt = String.new
              @indicator.keys.each { |icon| gsl_prompt += ICONMAP[icon] if @indicator[icon] == 'y' }
              $_CLIENT_.puts "\034GSP#{sprintf('%-30s', gsl_prompt)}\r\n"
              gsl_prompt = nil
              gsl_exits = String.new
              @room_exits.each { |exit| gsl_exits.concat(DIRMAP[SHORTDIR[exit]].to_s) }
              $_CLIENT_.puts "\034GSj#{sprintf('%-20s', gsl_exits)}\r\n"
              gsl_exits = nil
              $_CLIENT_.puts "\034GSn#{sprintf('%-14s', @prepared_spell)}\r\n"
              $_CLIENT_.puts "\034GSm#{sprintf('%-45s', GameObj.right_hand.name)}\r\n"
              $_CLIENT_.puts "\034GSl#{sprintf('%-45s', GameObj.left_hand.name)}\r\n"
              $_CLIENT_.puts "\034GSq#{sprintf('%010d', @server_time)}\r\n"
              $_CLIENT_.puts "\034GSQ#{sprintf('%010d', @roundtime_end)}\r\n" if @roundtime_end > 0
            end
            Game._puts("#{$cmd_prefix}_flag Display Inventory Boxes 1")
          end
        rescue
          Lich.log "error: XMLParser.tag_start: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          sleep 0.1
          reset
        end
      end

      def text(text_string)
        # Called by Ox once per text node. Decode the standard XML entities (Ox
        # runs with convert_special: false; see Lich::Common::XmlEntities).
        text_string = XmlEntities.decode(text_string)
        begin
          # fixme: /<stream id="Spells">.*?<\/stream>/m
          # $_CLIENT_.write(text_string) unless ($frontend != 'suks') or (@current_stream =~ /^(?:spellfront|inv|bounty|society)$/) or @active_tags.any? { |tag| tag =~ /^(?:compDef|inv|component|right|left|spell)$/ } or (@active_tags.include?('stream') and @active_ids.include?('Spells')) or (text_string == "\n" and (@last_tag =~ /^(?:popStream|prompt|compDef|dialogData|openDialog|switchQuickBar|component)$/))

          # DR Active Spell tracking and handling
          if @dr_active_spell_tracking
            spell = nil
            duration = nil
            case text_string
            when /(?<spell>^[^\(]+)\((?<duration>\d+|Indefinite|OM|Fading)\s*(?:%|roisae?n)?\)/i
              # Spell with known duration remaining
              # XML looks like:
              # Hydra Hex  (Indefinite)
              # Persistence of Mana  (OM)
              # Cure Disease  (Fading)
              # Osrel Meraud  (94%)
              # Landslide (4 roisaen)
              # Khri Sagacity  (1 roisan)
              spell = Regexp.last_match[:spell]
              duration = Regexp.last_match[:duration]

              if duration.match?(/Indefinite|OM/)
                duration = 1000
              elsif duration.match?(/Fading/)
                duration = 0
              else
                duration = duration.to_i
              end
            when /(?<spell>Stellar Collector)\s+\((?<percentage>\d+)%,\s*(?<duration>\d+)?\s*(?<unit>(?:roisae?n|anlaen|fading))/
              # Stellar collector special case
              # XML looks like:
              # Stellar Collector  (0%, 4 anlaen)
              # Stellar Collector  (0%, fading)
              spell = Regexp.last_match[:spell]
              duration = Regexp.last_match[:duration].to_i
              @dr_active_spells_stellar_percentage = Regexp.last_match[:percentage].to_i
              unit = Regexp.last_match[:unit]
              duration = unit == 'anlaen' ? duration * 30 : duration
            when /(?<spell>^[^\(]+)\(.+\)/i
              # Spells with inexact duration verbiage, such as with
              # Barbarians without knowledge of Power Monger mastery
              spell = Regexp.last_match[:spell]
              duration = 1000
            when /.*orbiting sliver.*/i
              # Moon Mage slivers
              @dr_active_spells_slivers = true
            end
            spell.strip!
            if spell
              @dr_active_spells_tmp[spell] = duration
            end
          end

          if @current_style == 'roomName'
            @room_name = text_string.match(/(?<roomname>\[.*?\])/)[:roomname]
          end

          if @active_tags.include?('inv')
            if @active_tags[-1] == 'a'
              @obj_name = text_string
            elsif @obj_name.nil?
              @obj_before_name = text_string.strip
            else
              @obj_after_name = text_string.strip
            end
          elsif @active_tags.last == 'prompt'
            @prompt = text_string
          elsif @active_tags.include?('right')
            GameObj.new_right_hand(@obj_exist, @obj_noun, text_string)
            $_CLIENT_.puts "\034GSm#{sprintf('%-45s', text_string)}\r\n" if @send_fake_tags
          elsif @active_tags.include?('left')
            GameObj.new_left_hand(@obj_exist, @obj_noun, text_string)
            $_CLIENT_.puts "\034GSl#{sprintf('%-45s', text_string)}\r\n" if @send_fake_tags
          elsif @active_tags.include?('spell')
            @prepared_spell = text_string
            $_CLIENT_.puts "\034GSn#{sprintf('%-14s', text_string)}\r\n" if @send_fake_tags
          elsif @active_tags.include?('compDef') or @active_tags.include?('component')
            if @active_ids.include?('room objs')
              if @active_tags.include?('a')
                if @bold
                  GameObj.new_npc(@obj_exist, @obj_noun, text_string)
                  if XMLData.current_target_ids.include?(@obj_exist) || @pending_crtr_status.key?(@obj_exist)
                    creature = Creature.register(text_string, @obj_exist, @obj_noun)
                    if creature && (pending_flags = @pending_crtr_status.delete(@obj_exist))
                      creature.sync_crtr_status(pending_flags)
                    end
                  end
                else
                  GameObj.new_loot(@obj_exist, @obj_noun, text_string)
                end
              elsif (text_string =~ /that (?:is|appears) ([\w\s]+)(?:,| and|\.)/) or (text_string =~ / \(([^\(]+)\)/)
                GameObj.npcs[-1].status = $1
              end
            elsif @active_ids.include?('room players')
              if @active_tags.include?('a')
                if @obj_exist.to_s.start_with?('-')
                  @pc = GameObj.new_pc(@obj_exist, @obj_noun, "#{@player_title}#{text_string}", @player_status)
                  @arrival_pcs.push(@pc.noun) if (defined?(Lich::Claim) && Lich::Claim::Lock.owned?)
                else
                  @pc = nil
                end
                @player_status = nil
                @player_title = nil
              else
                if @game =~ /^DR/
                  GameObj.clear_pcs
                  text_string.sub(/^Also here\: /, '').sub(/ and ([^,]+)\./) { ", #{$1}" }.split(', ').each { |player|
                    if player =~ / who is (.+)/
                      status = $1
                      player.sub!(/ who is .+/, '')
                    elsif player =~ / \((.+)\)/
                      status = $1
                      player.sub!(/ \(.+\)/, '')
                    else
                      status = nil
                    end
                    noun = player.slice(/\b[A-Z][a-z]+$/)
                    if player =~ /the body of /
                      player.sub!('the body of ', '')
                      if status
                        status.concat ' dead'
                      else
                        status = 'dead'
                      end
                    end
                    if player =~ /a stunned /
                      player.sub!('a stunned ', '')
                      if status
                        status.concat ' stunned'
                      else
                        status = 'stunned'
                      end
                    end
                    GameObj.new_pc(nil, noun, player, status)
                  }
                else
                  if @pc && ((text_string =~ /^ who (?:is|appears) ([\w\s]+)(?:,| and|\.|$)/) || (text_string =~ / \(([\w\s]+)\)(?: \(([\w\s]+)\))?/))
                    if @pc.status
                      @pc.status.concat " #{$1}"
                    else
                      @pc.status = $1
                    end
                    @pc.status.concat " #{$2}" if $2
                  end
                  if text_string =~ /(?:^Also here: |, )(?:a )?([a-z\s]+)?([\w\s\-!\?',]+)?$/
                    @player_status = ($1.strip.gsub('the body of', 'dead')) if $1
                    @player_title = $2
                  end
                end
              end
            elsif @active_ids.include?('room desc')
              if text_string == '[Room window disabled at this location.]'
                @room_window_disabled = true
              else
                @room_window_disabled = false
                @room_description.concat(text_string)
                if @active_tags.include?('a')
                  GameObj.new_room_desc(@obj_exist, @obj_noun, text_string)
                end
              end
            elsif @active_ids.include?('room exits')
              @room_exits_string.concat(text_string)
              @room_exits.push(text_string) if @active_tags.include?('d')
            end
          elsif @current_stream == 'bounty'
            @bounty_task += text_string
          elsif @current_stream == 'society'
            @society_task = text_string
          elsif @current_stream == 'assess'
            @assess_buffer.concat(text_string) if @assess_buffer
          elsif (@current_stream == 'inv') and @active_tags.include?('a')
            GameObj.new_inv(@obj_exist, @obj_noun, text_string, nil)
          elsif (@current_stream == 'reserve') and @active_tags.include?('a')
            GameObj.new_reserve(@obj_exist, @obj_noun, text_string)
          elsif @check_obvious_hiding && text_string =~ /obvious signs of someone hiding/
            @room_player_hidden = true
          elsif @current_stream == 'familiar'
            # fixme: familiar room tracking does not (can not?) auto update, status of pcs and npcs isn't tracked at all, titles of pcs aren't tracked
            if @current_style == 'roomName'
              @familiar_room_title = text_string
              @familiar_room_description = String.new
              @familiar_room_exits = Array.new
              GameObj.clear_fam_room_desc
              GameObj.clear_fam_loot
              GameObj.clear_fam_npcs
              GameObj.clear_fam_pcs
              @fam_mode = String.new
            elsif @current_style == 'roomDesc'
              @familiar_room_description.concat(text_string)
              if @active_tags.include?('a')
                GameObj.new_fam_room_desc(@obj_exist, @obj_noun, text_string)
              end
            elsif text_string =~ /^You also see/
              @fam_mode = 'things'
            elsif text_string =~ /^Also here/
              @fam_mode = 'people'
            elsif text_string =~ /Obvious (?:paths|exits)/
              @fam_mode = 'paths'
            elsif @fam_mode == 'things'
              if @active_tags.include?('a')
                if @bold
                  GameObj.new_fam_npc(@obj_exist, @obj_noun, text_string)
                else
                  GameObj.new_fam_loot(@obj_exist, @obj_noun, text_string)
                end
              end
              # puts 'things: ' + text_string
            elsif @fam_mode == 'people' and @active_tags.include?('a')
              GameObj.new_fam_pc(@obj_exist, @obj_noun, text_string)
              # puts 'people: ' + text_string
            elsif (@fam_mode == 'paths') and @active_tags.include?('a')
              @familiar_room_exits.push(text_string)
            end
          elsif @room_window_disabled
            if @current_style == 'roomDesc'
              @room_description.concat(text_string)
              if @active_tags.include?('a')
                GameObj.new_room_desc(@obj_exist, @obj_noun, text_string)
              end
            elsif text_string =~ /^Obvious (?:paths|exits): (?:none)?$/
              @room_exits_string = text_string.strip
            end
          end
        rescue
          Lich.log "error: XMLParser.text: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          sleep 0.1
          reset
        end
      end

      def tag_end(name)
        # Called once per element close. Ox synthesizes an end for a stray closing
        # tag -- a close with no matching open (e.g. a desynced </prompt> whose
        # <prompt> was in a prior, truncated read). tag_start never pushed it (Ox
        # fires no attrs_done for a synthetic start), so popping here would remove
        # the wrong element and the inv/compass end-handlers would fire spuriously.
        # Ignore any close that does not match the currently-open tag.
        return unless @active_tags.last == name

        begin
          if @game =~ /^DR/
            if name == 'compass' and $nav_seen
              $nav_seen = false
              @second_compass = true
            end
            if name == 'compass' and @second_compass
              @second_compass = false
              @room_count += 1
              $room_count += 1
            end
          end

          if name == 'inv'
            if @obj_exist == @obj_location
              if @obj_after_name == 'is closed.'
                GameObj.delete_container(@stow_container_id)
              end
            elsif @obj_exist
              GameObj.new_inv(@obj_exist, @obj_noun, @obj_name, @obj_location, @obj_before_name, @obj_after_name)
            end
          elsif @send_fake_tags and (@active_ids.last == 'room exits')
            gsl_exits = String.new
            @room_exits.each { |exit| gsl_exits.concat(DIRMAP[SHORTDIR[exit]].to_s) }
            $_CLIENT_.puts "\034GSj#{sprintf('%-20s', gsl_exits)}\r\n"
            gsl_exits = nil
          elsif @room_window_disabled and (name == 'compass')
            if defined?(Lich::Claim) && Lich::Claim::Lock.owned?
              if @room_id == 0
                @room_id = Digest::MD5.hexdigest([@room_title, @room_description, @room_exits_string].to_s).to_i(16)
              end
              if @room_player_hidden
                @arrival_pcs.push(:hidden)
                @room_player_hidden = false
              end
              @check_obvious_hiding = false
              Lich::Claim.parser_handle(@room_id, @arrival_pcs)
              Lich::Claim.unlock
            end
            @room_description = @room_description.strip
            @room_exits_string.concat " #{@room_exits.join(', ')}" unless @room_exits.empty?
            if @send_fake_tags
              gsl_exits = String.new
              @room_exits.each { |exit| gsl_exits.concat(DIRMAP[SHORTDIR[exit]].to_s) }
              $_CLIENT_.puts "\034GSj#{sprintf('%-20s', gsl_exits)}\r\n"
              gsl_exits = nil
            end
            @room_count += 1
            $room_count += 1
          end
          @last_tag = @active_tags.pop
          @last_id = @active_ids.pop
        rescue
          Lich.log "error: XMLParser.tag_end: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          sleep 0.1
          reset
        end
      end

      # here for backwards compatibility, but spellfront xml isn't sent by the game anymore
      def spellfront
        if (Time.now.to_i - @@warned_deprecated_spellfront) > 300
          @@warned_deprecated_spellfront = Time.now.to_i
          unless (script_name = Script.current.name)
            script_name = 'unknown script'
          end
          respond "--- warning: #{script_name} is using deprecated method XMLData.spellfront; this method will be removed in a future version of Lich"
        end
        @active_spells.keys
      end
    end
  end
end
