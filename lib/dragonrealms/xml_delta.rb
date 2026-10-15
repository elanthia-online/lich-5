# frozen_string_literal: true

require File.join(LIB_DIR, 'common', 'xmlparser', 'game_delta.rb')

module Lich
  module DragonRealms
    # DragonRealms' semantic deltas for the shared server-stream parser. See
    # Lich::Common::XMLParserDelta for the composition and the hook contracts.
    module XMLDelta
      extend Lich::Common::XMLParserDelta::Base

      SUBTITLE_ROOM = %r{(?<roomtitle>\[.*?\])(?:\s\((?<uid>\d+|\*+)\))?}.freeze

      # DragonRealms subtitles read " - [Bosque Deriel, Hermit's Shacks]", with a
      # trailing UID marker only when the game's ShowRoomID flag is ON: " (230008)"
      # for a room with a UID, " (**)" for one without. <nav rm=.../> is the
      # PRIMARY UID source; this marker is only a FALLBACK for arrivals where nav
      # arrived late, was absent, or was a bare no-uid <nav/>. When nav already
      # supplied a real UID this arrival (nav_uid_pending), room_id is left alone
      # so the subtitle never clobbers it; the subtitle consumes that flag either
      # way, so the next arrival's marker (if its nav is missing) can act as the
      # fallback. Without a nav UID, a numeric marker sets the UID and "(**)"
      # clears it to 0 (explicit "no UID"). A ShowRoomID-OFF subtitle has no
      # marker, so room_id is untouched (never write 0 blindly). The title stays
      # UID-free. A blank or identity-less subtitle (e.g. " - ") has no "[...]",
      # so nothing is updated and the prior title stands.
      #
      # show_room_id records whether the game displayed the RealID this arrival
      # (marker present == ShowRoomID ON), so the outbound room-name/subtitle
      # rewrite can preserve that choice GemStone-style.
      def self.main_subtitle(subtitle, nav_uid_pending:)
        room = subtitle.match(SUBTITLE_ROOM)
        return {} unless room

        update = { room_title: "[#{room[:roomtitle]}]", nav_uid_pending: false, show_room_id: !room[:uid].nil? }
        update[:room_id] = (room[:uid] =~ /\A\d+\z/ ? room[:uid].to_i : 0) if room[:uid] && !nav_uid_pending
        update
      end

      Lich::Common::XMLParserDelta.register(/^DR/, self)
    end
  end
end
