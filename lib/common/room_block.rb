# frozen_string_literal: true

module Lich
  module Common
    # The Saga-identity stream (Frontend::CLIENT_STRING since #1700) renders a
    # room in the main window as one inline element:
    #
    #   <room><name>[Area, Title] (230008)</name><description>...</description>
    #   <exists>You also see ...</exists><crtrStatus .../><players>Also here: ...</players>
    #   <exits>Obvious paths: <d>north</d>.</exits><extra></extra></room>
    #
    # where the legacy stream (front ends sending their own Wrayth handshake)
    # sends the roomName style, the roomDesc preset and one line per part. Saga
    # itself renders the block by re-emitting each child as styled story text,
    # i.e. the legacy layout. The room components (room desc/objs/players/exits)
    # are sent in both dialects and stay the parser's source of room state.
    module RoomBlock
      # A complete block; the body never spans another <room>, so a block cut
      # off before </room> cannot swallow the next one in a multi-line string.
      BLOCK = %r{<room>(?<body>(?:(?!<room>).)*?)</room>}m.freeze

      # The legacy stream's <compass> value for each exit name the game lists
      # in "Obvious paths:", in the exits line's order.
      COMPASS_DIRS = {
        'north' => 'n', 'northeast' => 'ne', 'east' => 'e', 'southeast' => 'se',
        'south' => 's', 'southwest' => 'sw', 'west' => 'w', 'northwest' => 'nw',
        'up' => 'up', 'down' => 'down', 'out' => 'out'
      }.freeze

      # The room number the game ends a room name with: "[Area, Title] (230008)".
      NAME_UID = /\((\d+)\)\s*\z/.freeze

      module_function

      # Rewrites a <room> block into the legacy stream's layout, so code written
      # for the legacy stream sees the same shape in both dialects.
      # Markup.strip_xml and reget run it, so scripts get the legacy room lines;
      # a client-bound rewrite can run it for front ends that do not understand
      # <room>:
      #
      #   <style id="roomName" />[Area, Title] (230008)
      #   <style id=""/><preset id='roomDesc'>description</preset>  You also see ...
      #   <crtrStatus .../>Also here: ...
      #   Obvious paths: <d>north</d>.
      #
      # Markup inside each part (object links, bold, <d>) is kept. The
      # description line is always sent, as in the legacy stream: an empty
      # description drops the roomDesc preset, and the two spaces before the
      # objects stay when there are none. Other parts the game sent empty are
      # omitted, as the legacy stream omits them. Every complete block in the
      # string is rewritten (reget joins many server strings); a string without
      # one (none, or only a block cut off before </room>) is returned unchanged.
      #
      # @param server_string [String]
      # @return [String]
      def legacy_shape(server_string)
        return server_string unless server_string.include?('<room>')

        server_string.gsub(BLOCK) { legacy_lines(Regexp.last_match(:body)) }
      end

      # The legacy layout for a front end, which also gets the line the
      # Saga-identity stream no longer sends: after a view of the character's
      # own room, the legacy stream followed the exits line with a top-level
      # compass built from those exits,
      #
      #   Obvious paths: <d>north</d>, <d>southeast</d>.
      #   <compass><dir value="n"/><dir value="se"/></compass>
      #
      # and front ends update their compass (and Frostbite its map) only from
      # that line. Here it ends a line of its own, as the game starts a new
      # line after </room>.
      # Exit names without a compass value are left out; a room without exits
      # gets an empty compass, which clears the last room's.
      #
      # The game also sends a <room> block for a room the character is not in
      # (a Moon Mage's Locate shows the target's room). The compass shows
      # where the character stands, so such a block gets none. A block is the
      # character's room when the room number its name ends with is room_id
      # (XMLData.room_id, from <nav>). A name without one (ShowRoomID off, or
      # "(**)" for a room without a number) counts when its exits are
      # room_exits (XMLData.room_exits, from the room exits component), so the
      # compass is never lit with any exits but the current room's.
      #
      # Only for the client: scripts, reget and the parser use legacy_shape
      # and never see the compass line.
      #
      # @param server_string [String]
      # @param room_id [Integer] the character's room number
      # @param room_exits [Array<String>] the character's room's exit names
      # @return [String]
      def legacy_shape_with_compass(server_string, room_id:, room_exits:)
        return server_string unless server_string.include?('<room>')

        server_string.gsub(BLOCK) do
          body = Regexp.last_match(:body)
          exits = exit_names(body)
          legacy_lines(body, compass: (compass(exits) if current_room?(body, exits, room_id, room_exits)))
        end
      end

      def legacy_lines(body, compass: nil)
        name = part(body, 'name')
        exists = part(body, 'exists')
        players = part(body, 'players')
        extra = part(body, 'extra')
        # Tags the game puts between the parts (the <crtrStatus> batch after
        # <exists>) lead the next line, where the legacy stream puts them.
        between = body.gsub(%r{<(name|description|exists|players|exits|extra)>.*?</\1>}m, '')

        lines = [%(<style id="roomName" />#{name})]
        description = part(body, 'description')
        description = %(<preset id='roomDesc'>#{description}</preset>) unless description.empty?
        lines << %(<style id=""/>#{description}  #{exists})
        lines << "#{between}#{players}" unless players.empty?
        exits = part(body, 'exits')
        exits = "#{between}#{exits}" if players.empty?
        lines << exits unless exits.empty?
        lines << compass if compass
        lines << extra unless extra.empty?
        lines.join("\r\n")
      end
      private_class_method :legacy_lines

      def exit_names(body)
        part(body, 'exits').scan(%r{<d(?:\s[^>]*)?>(.*?)</d>}m).flatten
      end
      private_class_method :exit_names

      def current_room?(body, exits, room_id, room_exits)
        uid = part(body, 'name')[NAME_UID, 1]
        uid ? uid.to_i == room_id : exits == room_exits
      end
      private_class_method :current_room?

      def compass(exits)
        dirs = exits.filter_map { |exit| %(<dir value="#{COMPASS_DIRS[exit]}"/>) if COMPASS_DIRS.key?(exit) }
        "<compass>#{dirs.join}</compass>"
      end
      private_class_method :compass

      def part(body, tag)
        body[%r{<#{tag}>(.*?)</#{tag}>}m, 1].to_s
      end
      private_class_method :part
    end
  end
end
