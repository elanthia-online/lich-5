# frozen_string_literal: true

require_relative '../../../spec_helper'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-travel.rb')

DRCT = Lich::DragonRealms::DRCT unless defined?(DRCT)

# walk_to from an unresolved room, against the DR map's own resolver
# (Lich::Common::Map.current with a script running) instead of a fake one.
#
# The map resolves a room by its first title/description/exits match, unless
# that room's stored UIDs exclude the live UID. walk_to's own match
# (match_unknown_room) only accepts a room when it is the single
# title/description/exits match and is not excluded by UID, so any room it
# accepts is one Room.current has already resolved. From a room Room.current
# cannot resolve, walk_to therefore fails at once without moving.
RSpec.describe DRCT, '.walk_to with the map resolver' do
  let(:real_map) { Lich::Common::Map }

  before { MapLoader.use(:dr) }

  # Live game state: which room the character stands in, the UID the game shows
  # there (0 when absent), and live exits that differ from the map.
  let(:live) { { position: nil, uids: Hash.new(0), exits: {}, count: 0 } }
  let(:sent) { [] }

  def build_room(id, wayto, uid: [], title: "[Room #{id}]", description: "Room #{id} description.", paths: nil)
    paths ||= "Obvious exits: #{wayto.values.join(', ')}."
    room = real_map.new(id, [title], [description], [paths], uid, nil, nil, nil,
                        wayto, wayto.transform_values { 0.2 }, nil, nil, [])
    uid.each { |u| real_map.uids_add(u, id) }
    room
  end

  # 1 -east-> 2 -east-> 3, each room with distinct text and its own stored UID,
  # which the game also shows unless an example changes it.
  def corridor
    build_room(1, { '2' => 'east' }, uid: [1001])
    build_room(2, { '1' => 'west', '3' => 'east' }, uid: [1002])
    build_room(3, { '2' => 'west' }, uid: [1003])
    live[:uids].merge!(1 => 1001, 2 => 1002, 3 => 1003)
  end

  def place(id)
    live[:position] = id
    live[:count] += 1
  end

  def live_room
    real_map[live[:position]]
  end

  before(:each) do
    real_map.class_variable_set(:@@list, [])
    real_map.class_variable_set(:@@uids, {})
    real_map.class_variable_set(:@@previous_room_id, -1)
    real_map.class_variable_set(:@@current_room_id, nil)
    real_map.class_variable_set(:@@current_room_count, -1)
    real_map.class_variable_set(:@@fuzzy_room_count, -1)
    real_map.class_variable_set(:@@loaded, true)

    Lich::Messaging.clear_messages!
    allow(Script).to receive(:current).and_return(:running_script)
    allow(Script).to receive(:running).and_return([])
    allow(Script).to receive(:running?).and_return(false)
    allow(DRC).to receive(:fix_standing)

    allow(XMLData).to receive(:room_title) { live_room.title.first }
    allow(XMLData).to receive(:room_description) { live_room.description.first }
    allow(XMLData).to receive(:room_exits_string) { live[:exits][live[:position]] || live_room.paths.first }
    allow(XMLData).to receive(:room_id) { live[:uids][live[:position]] }
    allow(XMLData).to receive(:room_count) { live[:count] }
    allow(XMLData).to receive(:room_window_disabled).and_return(false)

    allow(Room).to receive(:current) { real_map.current }
    allow(Map).to receive(:list) { real_map.list }
    allow(Map).to receive(:[]) { |id| real_map[id] }
    allow(Map).to receive(:findpath) { |source, destination| real_map.findpath(source, destination) }
    allow(Map).to receive(:resolve_matched_room) { |room, **opts| real_map.resolve_matched_room(room, **opts) }

    allow(DRCT).to receive(:move) do |dir|
      sent << dir
      target = live_room.wayto.key(dir)
      next false unless target

      place(target.to_i)
      true
    end
    # go2: walks straight to its target and exits at once.
    allow(DRCT).to receive(:start_script) do |_name, args, **_opts|
      place(args.first.to_i)
      :go2_handle
    end
  end

  after(:each) do
    real_map.class_variable_set(:@@list, [])
    real_map.class_variable_set(:@@uids, {})
    real_map.class_variable_set(:@@current_room_id, nil)
  end

  def bold_messages
    Lich::Messaging.messages.select { |m| m[:type] == 'bold' }.map { |m| m[:message] }
  end

  describe 'starting in a room the map does not resolve' do
    it 'fails without moving when the start room is unique by text but its stored UID is stale' do
      corridor
      live[:uids][1] = 1777
      place(1)
      expect(Room.current).to be_nil

      expect(DRCT.walk_to(3)).to be(false)
      expect(sent).to be_empty
      expect(bold_messages).to include('DRCT: Failed to find a matching room from unknown location.')
    end

    it 'fails without moving when the live exits differ from the map' do
      corridor
      live[:uids][1] = 9999
      live[:exits][1] = 'Obvious exits: east, out.'
      place(1)
      expect(Room.current).to be_nil

      expect(DRCT.walk_to(3)).to be(false)
      expect(sent).to be_empty
    end
  end

  describe 'go2 ending in the target' do
    it 'returns true when the target has no stored UID, because the map resolves it by text' do
      corridor
      real_map[3].uid.clear
      real_map.class_variable_set(:@@uids, { 1001 => [1], 1002 => [2] })
      live[:uids][3] = 3777
      place(1)

      expect(DRCT.walk_to(3, false)).to be(true)
    end

    [true, false].each do |restart|
      it "returns false when the target's stored UID is stale (restart_on_fail #{restart})" do
        corridor
        live[:uids][3] = 3777
        place(1)

        expect(DRCT.walk_to(3, restart)).to be(false)
      end
    end
  end

  # The property the walk_to docs rest on: with a script running, a room
  # match_unknown_room accepts is always one Room.current resolves. Small random
  # worlds with look-alike text, missing, correct and stale stored UIDs, a live
  # UID or none, and a random cached previous room.
  it 'never accepts a room by its own match that Room.current leaves unresolved' do
    titles = ['[A]', '[B]']
    descriptions = ['Desc one.', 'Desc two.']
    exits = ['Obvious paths: north.', 'Obvious paths: south.']
    rng = Random.new(20_261_018)
    matched = 0

    2_000.times do
      real_map.class_variable_set(:@@list, [])
      real_map.class_variable_set(:@@uids, {})
      live[:uids].clear
      rooms = rng.rand(1..5)
      rooms.times do |id|
        live[:uids][id] = rng.rand(4).zero? ? 0 : 1000 + id
        uid = case rng.rand(3)
              when 0 then []
              when 1 then [live[:uids][id].zero? ? 5000 + id : live[:uids][id]]
              else [9000 + rng.rand(3)]
              end
        build_room(id, {}, uid: uid, title: titles.sample(random: rng),
                           description: descriptions.sample(random: rng), paths: exits.sample(random: rng))
      end
      real_map.class_variable_set(:@@current_room_id, rng.rand(3).zero? ? nil : rng.rand(rooms))
      real_map.class_variable_set(:@@current_room_count, -1)
      place(rng.rand(rooms))

      match = DRCT.send(:match_unknown_room)
      next if match.nil?

      matched += 1
      expect(Room.current).not_to be_nil, "room #{match.id} matched but Room.current is nil"
    end
    # The sweep must actually exercise accepted matches.
    expect(matched).to be > 100
  end
end
