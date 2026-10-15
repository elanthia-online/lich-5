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

      module_function

      # @param server_string [String]
      # @return [Boolean] whether +server_string+ carries a complete <room> block
      def block?(server_string)
        server_string.include?('<room>') && server_string.match?(BLOCK)
      end

      # Rewrites a <room> block into the legacy stream's layout, so code written
      # for the legacy stream (script line matching, room-number display, the
      # Wizard converter, front ends that do not understand <room>) sees the
      # same shape in both dialects:
      #
      #   <style id="roomName" />[Area, Title] (230008)
      #   <style id=""/><preset id='roomDesc'>description</preset>  You also see ...
      #   <crtrStatus .../>Also here: ...
      #   Obvious paths: <d>north</d>.
      #
      # Markup inside each part (object links, bold, <d>) is kept. Parts the game
      # sent empty are omitted, as the legacy stream omits them. Every complete
      # block in the string is rewritten (reget joins many server strings); a
      # string without one (none, or only a block cut off before </room>) is
      # returned unchanged.
      #
      # @param server_string [String]
      # @return [String]
      def legacy_shape(server_string)
        return server_string unless server_string.include?('<room>')

        server_string.gsub(BLOCK) { legacy_lines(Regexp.last_match(:body)) }
      end

      def legacy_lines(body)
        name = part(body, 'name')
        exists = part(body, 'exists')
        players = part(body, 'players')
        extra = part(body, 'extra')
        # Tags the game puts between the parts (the <crtrStatus> batch after
        # <exists>) lead the next line, where the legacy stream puts them.
        between = body.gsub(%r{<(name|description|exists|players|exits|extra)>.*?</\1>}m, '')

        lines = [%(<style id="roomName" />#{name})]
        description = %(<style id=""/><preset id='roomDesc'>#{part(body, 'description')}</preset>)
        description += "  #{exists}" unless exists.empty?
        lines << description
        lines << "#{between}#{players}" unless players.empty?
        exits = part(body, 'exits')
        exits = "#{between}#{exits}" if players.empty?
        lines << exits
        lines << extra unless extra.empty?
        lines.join("\r\n")
      end
      private_class_method :legacy_lines

      def part(body, tag)
        body[%r{<#{tag}>(.*?)</#{tag}>}m, 1].to_s
      end
      private_class_method :part
    end
  end
end
