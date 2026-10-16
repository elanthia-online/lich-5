# frozen_string_literal: true

require_relative 'room_block'

module Lich
  module Common
    # Works around a DragonRealms game bug for the client: the Saga-identity
    # stream ignores FLAG DESCRIPTION OFF.
    #
    # With the flag off, the legacy stream sends the room view without its
    # description (the line after the room name starts with the two spaces
    # before the objects, and has no roomDesc preset). The Saga-identity
    # stream (Frontend::CLIENT_STRING since #1700) fills the <description> of
    # every <room> block whatever the flag says. GemStone follows its setting
    # and sends no <room> block.
    #
    # The filter follows the game's replies to the flag,
    #
    #   You will no longer see room descriptions.
    #   You will now see room descriptions.
    #
    # and, while the flag is off, empties the description of each block for
    # the character's own room (RoomBlock.without_description). The legacy
    # rewrite then sends the legacy stream's line, and a front end that
    # renders <room> gets an empty <description>. A block for another room (a
    # Moon Mage's Locate) keeps its description. The room desc component is
    # left alone: the legacy stream sends it with the flag off too.
    #
    # Opt-in (Lich.follow_description_flag, ";display descflag"), and only on
    # the way to the client: scripts, XMLParser and the downstream hooks keep
    # the description. Until the game has answered the flag in this session
    # its state is unknown, and descriptions are shown.
    module RoomDescriptionFilter
      REPLY = /^You will (no longer|now) see room descriptions\.\r?$/.freeze
      REPLY_TEXT = ' see room descriptions.'

      @descriptions_off = false

      class << self
        # Follows the game's reply to FLAG DESCRIPTION in a server string. A
        # reply quoted inside another line (speech) does not count.
        #
        # @param server_string [String]
        # @return [void]
        def observe(server_string)
          return unless server_string.include?(REPLY_TEXT)

          last = server_string.scan(REPLY).last
          @descriptions_off = (last.first == 'no longer') if last
        end

        # @return [Boolean] whether the game last said descriptions are off
        def descriptions_off?
          @descriptions_off
        end

        # Back to the unknown state (descriptions shown).
        # @return [void]
        def reset
          @descriptions_off = false
        end

        # @param server_string [String] a server string on its way to the client
        # @param room_id [Integer] the character's room number (XMLData.room_id)
        # @param room_exits [Array<String>] its exit names (XMLData.room_exits)
        # @return [String] the string with the description of the character's
        #   room emptied while the flag is off; otherwise the same object
        def apply(server_string, room_id:, room_exits:)
          return server_string unless @descriptions_off

          RoomBlock.without_description(server_string, room_id: room_id, room_exits: room_exits)
        end
      end
    end
  end
end
