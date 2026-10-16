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
    # and the Description row of the bare FLAG listing, which the
    # Saga-identity stream links (the first row of the table leads with
    # <popBold/>; a stream without links sends the bare name):
    #
    #   <d cmd="flag Description off">Description</d>        ON   Display room descriptions.
    #
    # The state is the Status column; the link's cmd is the toggle, the
    # opposite of it. A front end that clicks the link sends FLAG DESCRIPTION
    # and gets the same reply as a typed command.
    #
    # While the flag is off, the filter empties the description of each block
    # for the character's own room (RoomBlock.without_description). The legacy
    # rewrite then sends the legacy stream's line, and a front end that
    # renders <room> gets an empty <description>. A block for another room (a
    # Moon Mage's Locate) keeps its description. The room desc component is
    # left alone: the legacy stream sends it with the flag off too.
    #
    # Opt-in (Lich.follow_description_flag, ";display descflag"), and only on
    # the way to the client: scripts, XMLParser and the downstream hooks keep
    # the description. Until the game has answered the flag or listed it in
    # this session its state is unknown, and descriptions are shown.
    module RoomDescriptionFilter
      REPLY = /^You will (?<reply>no longer|now) see room descriptions\.\r?$/.freeze
      REPLY_TEXT = ' see room descriptions.'
      # The listing's Description row, linked or bare, read up to the Status
      # column; the text after it is not read.
      LISTING_ROW = %r{^(?:<popBold/>)?  (?:<d cmd="[^"]*">Description</d>|Description) +(?<status>ON|OFF)(?: |\r?$)}.freeze
      LISTING_TEXT = 'Description'
      STATE = Regexp.union(REPLY, LISTING_ROW).freeze

      @descriptions_off = false

      class << self
        # Follows the game's reply to FLAG DESCRIPTION, or the Description row
        # of the FLAG listing, in a server string; the later one wins. Each
        # must start a line, so one quoted inside another line (speech) does
        # not count.
        #
        # @param server_string [String]
        # @return [void]
        def observe(server_string)
          return unless server_string.include?(REPLY_TEXT) || server_string.include?(LISTING_TEXT)

          server_string.scan(STATE) do
            match = Regexp.last_match
            @descriptions_off = match[:reply] ? match[:reply] == 'no longer' : match[:status] == 'OFF'
          end
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
