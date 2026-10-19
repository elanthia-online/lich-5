# frozen_string_literal: true

require_relative '../../../spec_helper'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-travel.rb')

DRCT = Lich::DragonRealms::DRCT unless defined?(DRCT)

# walk_to from an unresolved room and after go2, against the DR map's own
# resolver (Lich::Common::Map.current with a script running) instead of a
# fake one.
#
# The map resolves a room by its title, description and exits, and a stored
# UID that excludes the live one vetoes the room. walk_to treats the
# character as being in a room only when Room.current resolves it, so from a
# room the map cannot resolve it fails at once without moving.
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

  def unresolved_message(target)
    "DRCT: Unable to resolve the current room, cannot walk to room #{target}."
  end

  describe 'starting in a room the map does not resolve' do
    it 'fails without moving when the start room is unique by text but its stored UID is stale' do
      corridor
      live[:uids][1] = 1777
      place(1)
      expect(Room.current).to be_nil

      expect(DRCT.walk_to(3)).to be(false)
      expect(sent).to be_empty
      expect(bold_messages).to eq([unresolved_message(3)])
    end

    it 'fails without moving when the target is a direct neighbour' do
      corridor
      live[:uids][1] = 1777
      place(1)

      expect(DRCT.walk_to(2)).to be(false)
      expect(sent).to be_empty
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

    it 'does not take a title and description match with the target as arrival' do
      corridor
      live[:uids][3] = 3777
      place(3)
      expect(Room.current).to be_nil

      expect(DRCT.walk_to(3)).to be(false)
      expect(sent).to be_empty
      expect(bold_messages).to eq([unresolved_message(3)])
    end

    it 'does not take an unmapped look-alike of the target, with different exits, as arrival' do
      corridor
      live[:uids][3] = 0
      live[:exits][3] = 'Obvious exits: west, up.'
      place(3)
      expect(Room.current).to be_nil

      expect(DRCT.walk_to(3)).to be(false)
      expect(sent).to be_empty
    end

    it 'sends nothing when the target is not in the map' do
      corridor
      live[:uids][1] = 1777
      place(1)

      expect(DRCT.walk_to(42)).to be(false)
      expect(sent).to be_empty
    end

    it 'does not call a StringProc exit toward the target' do
      corridor
      exit_proc = StringProc.new('nil')
      allow(exit_proc).to receive(:call)
      real_map[1].wayto['2'] = exit_proc
      live[:uids][1] = 1777
      place(1)

      expect(DRCT.walk_to(2)).to be(false)
      expect(exit_proc).not_to have_received(:call)
      expect(sent).to be_empty
    end

    it 'does not start go2' do
      corridor
      live[:uids][1] = 1777
      place(1)

      DRCT.walk_to(3)
      expect(DRCT).not_to have_received(:start_script)
    end
  end

  # The real DR fog line, which has no closing period. Lich mints a room with
  # the live exits string, so a room first mapped in fog stores this as its
  # paths.
  fog_lines = ['Obvious paths: obscured by a thick fog', 'Obvious exits: obscured by a thick fog']

  describe 'starting in fog' do
    fog_lines.each do |fog|
      it "fails without moving when a look-alike room stores the fogged exits (#{fog})" do
        # Room 1: where the character stands, with a stale stored UID.
        build_room(1, { '2' => 'north' }, uid: [7001], title: '[Fog Path]', description: 'A misty trail.')
        # Room 2: same text, mapped once in fog, no stored UID.
        build_room(2, { '1' => 'south' }, title: '[Fog Path]', description: 'A misty trail.', paths: fog)
        live[:uids][1] = 1001
        live[:exits][1] = fog
        place(1)
        expect(Room.current).to be_nil

        expect(DRCT.walk_to(2)).to be(false)
        expect(sent).to be_empty
        expect(bold_messages).to eq([unresolved_message(2)])
      end

      it "fails without moving from a room unique by text whose stored UID is stale (#{fog})" do
        build_room(1, { '2' => 'north' }, uid: [7001], title: '[Fog Path]', description: 'A misty trail.')
        build_room(2, { '1' => 'south' }, uid: [7002])
        live[:uids][1] = 1001
        live[:exits][1] = fog
        place(1)
        expect(Room.current).to be_nil

        expect(DRCT.walk_to(2)).to be(false)
        expect(sent).to be_empty
      end
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

    it 'returns true when the map resolves the target' do
      corridor
      place(1)

      expect(DRCT.walk_to(3)).to be(true)
      expect(bold_messages).to be_empty
    end

    it "returns false when the target's stored UID is stale (restart_on_fail false)" do
      corridor
      live[:uids][3] = 3777
      place(1)

      expect(DRCT.walk_to(3, false)).to be(false)
      expect(DRCT).to have_received(:start_script).once
      expect(bold_messages).to be_empty
    end

    it "returns false when the target's stored UID is stale, retrying once into the unresolved-room failure (restart_on_fail true)" do
      corridor
      live[:uids][3] = 3777
      place(1)

      expect(DRCT.walk_to(3, true)).to be(false)
      expect(DRCT).to have_received(:start_script).once
      expect(bold_messages).to eq(['DRCT: Failed to navigate to room 3, attempting again (1/3).', unresolved_message(3)])
    end

    [true, false].each do |restart|
      it "returns false when go2 ends in an unmapped look-alike of the target (restart_on_fail #{restart})" do
        corridor
        live[:uids][3] = 0
        live[:exits][3] = 'Obvious exits: west, up.'
        place(1)

        expect(DRCT.walk_to(3, restart)).to be(false)
        expect(sent).to be_empty
      end
    end
  end
end
