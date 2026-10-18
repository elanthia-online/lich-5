# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'timeout'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-travel.rb')

DRCT = Lich::DragonRealms::DRCT unless defined?(DRCT)

# walk_to from a room the map cannot resolve (Room.current is nil). The world
# below is a small fake map: rooms with title/description/paths arrays and
# wayto edges, a character position, and a set of rooms Room.current can
# resolve. move and StringProc exits change the position; the live room text
# and live UID (XMLData) always follow the position.
module WalkToUnknownRoomSpec
  FakeRoom = Struct.new(:id, :title, :description, :paths, :wayto, :uid, keyword_init: true)

  # Minimal map world. Rooms are keyed by id; +overrides+ maps [room_id, dir] to
  # the room a move actually lands in (defaults to following the wayto).
  class World
    attr_accessor :position, :resolvable, :fog, :blank
    attr_reader :rooms, :sent, :overrides, :live_uids

    def initialize(rooms, position:, resolvable: [])
      @rooms = rooms.to_h { |room| [room.id, room] }
      @position = position
      @resolvable = resolvable
      @sent = []
      @overrides = {}
      @fog = false
      # :title, :description or :exits: that live field reads as blank
      @blank = nil
      # room id -> the UID the game shows there; 0 (none) when absent
      @live_uids = Hash.new(0)
    end

    def room(id)
      @rooms[id]
    end

    def current_room
      @resolvable.include?(@position) ? room(@position) : nil
    end

    def live_title
      @blank == :title ? '' : room(@position).title.first
    end

    def live_description
      @blank == :description ? '' : "#{room(@position).description.first}  "
    end

    def live_exits
      return '' if @blank == :exits

      @fog ? 'Obvious paths: obscured by a thick fog.' : room(@position).paths.first
    end

    def live_uid
      @live_uids[@position]
    end

    # Plain breadth-first search over wayto, like the map's own pathfinding
    # returns it: the rooms after +source+, ending at +destination+. Like the
    # real Map.findpath, a nil destination is searched for as room 0.
    def findpath(source, destination)
      destination_id = destination.nil? ? 0 : destination.id
      previous = { source.id => nil }
      queue = [source.id]
      until queue.empty?
        id = queue.shift
        break if id == destination_id

        room(id).wayto.each_key do |key|
          next_id = key.to_i
          next if previous.key?(next_id) || room(next_id).nil?

          previous[next_id] = id
          queue << next_id
        end
      end
      return nil unless previous.key?(destination_id)

      path = [destination_id]
      path.unshift(previous[path.first]) until previous[path.first].nil?
      path.drop(1)
    end

    # @return [true, false, nil] the move result the stub hands back
    def move(dir)
      @sent << dir
      key = [@position, dir]
      if @overrides.key?(key)
        outcome = @overrides[key]
        return outcome unless outcome.is_a?(Integer)

        @position = outcome
        return true
      end
      edge = room(@position).wayto.find { |_id, way| way == dir }
      return false unless edge

      @position = edge.first.to_i
      true
    end
  end
end

RSpec.describe DRCT, '.walk_to from an unknown room' do
  def make_room(id, wayto, title: "[Room #{id}]", description: "Room #{id} description.", paths: 'Obvious paths: north, south.', uid: [])
    WalkToUnknownRoomSpec::FakeRoom.new(id: id, title: [title], description: [description], paths: [paths], wayto: wayto, uid: uid)
  end

  # A straight corridor 101 -> 102 -> ... -> (100 + length + 1), each room
  # reached by 'north'. Every room has distinct text.
  def corridor(length)
    (101..(101 + length)).map do |id|
      wayto = {}
      wayto[(id + 1).to_s] = 'north' if id < 101 + length
      wayto[(id - 1).to_s] = 'south' if id > 101
      make_room(id, wayto)
    end
  end

  def install(world, map_list: nil)
    list = map_list || world.rooms.values
    allow(Map).to receive(:list).and_return(list)
    allow(Map).to receive(:[]) { |id| world.room(id.to_i) }
    allow(Map).to receive(:findpath) { |source, destination| world.findpath(source, destination) }
    allow(Room).to receive(:current) { world.current_room }
    allow(XMLData).to receive(:room_title) { world.live_title }
    allow(XMLData).to receive(:room_description) { world.live_description }
    allow(XMLData).to receive(:room_exits_string) { world.live_exits }
    allow(XMLData).to receive(:room_id) { world.live_uid }
    allow(DRCT).to receive(:move) { |dir| world.move(dir) }
    # go2: walks straight to its target and exits at once.
    allow(DRCT).to receive(:start_script) do |_name, args, **_opts|
      world.position = args.first.to_i
      :go2_handle
    end
    world
  end

  def bold_messages
    Lich::Messaging.messages.select { |m| m[:type] == 'bold' }.map { |m| m[:message] }
  end

  def plain_messages
    Lich::Messaging.messages.select { |m| m[:type] == 'plain' }.map { |m| m[:message] }
  end

  before(:each) do
    Lich::Messaging.clear_messages!
    allow(DRC).to receive(:fix_standing)
    allow(Script).to receive(:running).and_return([])
    allow(Script).to receive(:running?).and_return(false)
  end

  describe 'arriving through a direct edge' do
    it 'returns true when the target resolves after the move' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(1), position: 101, resolvable: [102]))

      expect(DRCT.walk_to(102)).to be(true)
      expect(world.position).to eq(102)
      expect(world.sent).to eq(['north'])
    end

    it 'returns true when the target is still unresolved but matches on title, description and exits' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(1), position: 101))

      expect(DRCT.walk_to(102)).to be(true)
      expect(world.sent).to eq(['north'])
    end

    it 'follows the map path instead of a direct edge the pathfinder skips' do
      rooms = [
        make_room(101, { '102' => 'east', '103' => 'go gate' }),
        make_room(102, { '103' => 'north' }),
        make_room(103, {})
      ]
      world = install(WalkToUnknownRoomSpec::World.new(rooms, position: 101))
      # The pathfinder skips the 'go gate' edge (as it does one without a
      # usable timeto) and routes through 102, which go2 would also do.
      allow(Map).to receive(:findpath) do |source, destination|
        source.id == 101 ? [102, 103] : world.findpath(source, destination)
      end

      expect(DRCT.walk_to(103)).to be(true)
      expect(world.sent).to eq(%w[east north])
    end
  end

  describe 'arriving through several hops while the room stays unresolved' do
    [2, 4, 6].each do |hops|
      it "returns true after #{hops} hops" do
        world = install(WalkToUnknownRoomSpec::World.new(corridor(hops), position: 101))

        expect(DRCT.walk_to(101 + hops)).to be(true)
        expect(world.position).to eq(101 + hops)
        expect(world.sent).to eq(['north'] * hops)
      end
    end

    it 'does not spend retries on hops that make progress' do
      install(WalkToUnknownRoomSpec::World.new(corridor(6), position: 101))

      DRCT.walk_to(107)

      expect(bold_messages).to be_empty
    end

    it 'hands the walk to go2 once the room resolves again' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(4), position: 101, resolvable: [102, 105]))

      expect(DRCT.walk_to(105)).to be(true)
      expect(world.sent).to eq(['north'])
      expect(DRCT).to have_received(:start_script).with('go2', ['105'], force: true)
    end

    it 'recognises the target by its text when go2 arrives but the room does not resolve' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(4), position: 101, resolvable: [102]))

      expect(DRCT.walk_to(105)).to be(true)
      expect(world.position).to eq(105)
      expect(DRCT).to have_received(:start_script).once
      expect(bold_messages).to be_empty
    end

    it 'recognises an unresolved target after go2 even when restart_on_fail is false' do
      install(WalkToUnknownRoomSpec::World.new(corridor(4), position: 101, resolvable: [102]))

      expect(DRCT.walk_to(105, false)).to be(true)
    end

    it 'does not take a title and description match after go2 as arrival when the exits differ' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(4), position: 101, resolvable: [102]))
      allow(world).to receive(:live_exits) do
        world.position == 105 ? 'Obvious paths: east.' : world.room(world.position).paths.first
      end

      expect(DRCT.walk_to(105, false)).to be(false)
      expect(world.position).to eq(105)
    end
  end

  describe 'already standing in the target' do
    it 'returns true without moving when the room matches on all three' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(1), position: 102))

      expect(DRCT.walk_to(102)).to be(true)
      expect(world.sent).to be_empty
    end

    it 'does not count a title and description match with different exits as arrival' do
      rooms = corridor(1)
      # The map's room 102 lists other exits than the live room shows.
      target = make_room(102, { '101' => 'south' }, paths: 'Obvious paths: south.')
      world = WalkToUnknownRoomSpec::World.new([rooms.first, target], position: 102)
      install(world, map_list: [rooms.first, target])
      allow(world).to receive(:live_exits).and_return('Obvious paths: north, south, up.')

      expect(DRCT.walk_to(102)).to be(false)
      expect(world.sent).to be_empty
      expect(bold_messages).to include('DRCT: Failed to find a matching room from unknown location.')
    end
  end

  describe 'identifying the start room' do
    it 'tells apart rooms that share a title and description by their exits' do
      rooms = [
        make_room(101, { '103' => 'north' }, title: '[Maze]', description: 'Twisty passages.', paths: 'Obvious paths: north.'),
        make_room(102, { '103' => 'east' }, title: '[Maze]', description: 'Twisty passages.', paths: 'Obvious paths: east.'),
        make_room(103, {})
      ]
      world = install(WalkToUnknownRoomSpec::World.new(rooms, position: 102))

      expect(DRCT.walk_to(103)).to be(true)
      expect(world.sent).to eq(['east'])
    end

    it 'fails without moving when several rooms match on all three' do
      rooms = [
        make_room(101, { '103' => 'north' }, title: '[Maze]', description: 'Twisty passages.'),
        make_room(102, { '103' => 'north' }, title: '[Maze]', description: 'Twisty passages.'),
        make_room(103, {})
      ]
      world = install(WalkToUnknownRoomSpec::World.new(rooms, position: 101))

      expect(DRCT.walk_to(103)).to be(false)
      expect(world.sent).to be_empty
    end

    it 'fails without moving when fog hides the exits' do
      world = WalkToUnknownRoomSpec::World.new(corridor(1), position: 101)
      world.fog = true
      install(world)

      expect(DRCT.walk_to(102)).to be(false)
      expect(world.sent).to be_empty
    end

    # The start room's stored text also holds an empty string, so a blank
    # live field would pass the include? checks; only the blank-text guard
    # stops the match.
    %i[title description exits].each do |field|
      it "fails without moving when the live #{field} is blank, even if the map stores an empty one" do
        world = WalkToUnknownRoomSpec::World.new(corridor(1), position: 101)
        start = world.room(101)
        { title: start.title, description: start.description, exits: start.paths }.fetch(field) << ''
        world.blank = field
        install(world)

        expect(DRCT.walk_to(102)).to be(false)
        expect(world.sent).to be_empty
      end
    end

    it 'skips nil holes in the map list' do
      world = WalkToUnknownRoomSpec::World.new(corridor(1), position: 101)
      install(world, map_list: [nil, *world.rooms.values, nil])

      expect(DRCT.walk_to(102)).to be(true)
    end
  end

  describe 'a live UID the map rejects' do
    it 'does not take a look-alike the map rejects by UID as arrival after go2' do
      world = WalkToUnknownRoomSpec::World.new(corridor(4), position: 101, resolvable: [102])
      world.room(105).uid = [1105]
      world.live_uids[105] = 7777
      install(world)

      expect(DRCT.walk_to(105, false)).to be(false)
      expect(world.position).to eq(105)
    end

    it 'fails without moving when the only matching start room is rejected by its UID' do
      world = WalkToUnknownRoomSpec::World.new(corridor(1), position: 101)
      world.room(101).uid = [1101]
      world.live_uids[101] = 9101
      install(world)

      expect(DRCT.walk_to(102)).to be(false)
      expect(world.sent).to be_empty
      expect(bold_messages).to include('DRCT: Failed to find a matching room from unknown location.')
    end

    it 'does not count a move into a room the map rejects by UID as arrival' do
      world = WalkToUnknownRoomSpec::World.new(corridor(1), position: 101)
      world.room(102).uid = [1102]
      world.live_uids[102] = 7777
      install(world)

      expect(DRCT.walk_to(102, false)).to be(false)
      expect(world.sent).to eq(['north'])
    end

    # Room 100 looks exactly like room 101 and carries a stored UID; room 101
    # carries none. When the live UID is not room 100's, Map.current rejects
    # room 100 (its first match) and Room.current is nil. From here the
    # character may stand in room 101, or in room 100 whose stored UID list is
    # stale; both look the same, so neither is accepted.
    def look_alike_world(position:, live_uid:)
      look_alike = make_room(100, { '102' => 'north' }, title: '[Room 101]', description: 'Room 101 description.', uid: [1100])
      world = WalkToUnknownRoomSpec::World.new([look_alike, *corridor(1)], position: position)
      world.live_uids[position] = live_uid
      world
    end

    it 'fails without moving when a vetoed look-alike shares the text of a room with no stored UID' do
      world = install(look_alike_world(position: 101, live_uid: 5555))

      expect(DRCT.walk_to(102)).to be(false)
      expect(world.sent).to be_empty
      expect(bold_messages).to include('DRCT: Failed to find a matching room from unknown location.')
    end

    it 'does not take the look-alike as arrival when the vetoed room is the one we stand in (stale stored UID)' do
      world = install(look_alike_world(position: 100, live_uid: 5555))

      expect(DRCT.walk_to(101)).to be(false)
      expect(world.position).to eq(100)
      expect(world.sent).to be_empty
    end

    it 'does not take the look-alike as arrival when go2 ends in the vetoed room' do
      [false, true].each do |restart_on_fail|
        Lich::Messaging.clear_messages!
        world = look_alike_world(position: 100, live_uid: 5555)
        world.position = 102
        world.resolvable = [102]
        install(world)
        allow(DRCT).to receive(:start_script) do |_name, _args, **_opts|
          world.position = 100
          :go2_handle
        end

        expect(DRCT.walk_to(101, restart_on_fail)).to be(false), "restart_on_fail=#{restart_on_fail}"
        expect(world.position).to eq(100)
      end
    end

    it 'still matches a room with stored UIDs when the game shows no UID' do
      world = WalkToUnknownRoomSpec::World.new(corridor(1), position: 101)
      world.room(101).uid = [1101]
      install(world)

      expect(DRCT.walk_to(102)).to be(true)
      expect(world.sent).to eq(['north'])
    end

    it 'matches a room whose stored UIDs include the live UID' do
      world = WalkToUnknownRoomSpec::World.new(corridor(1), position: 101)
      world.room(101).uid = [1101, 2101]
      world.live_uids[101] = 2101
      install(world)

      expect(DRCT.walk_to(102)).to be(true)
    end
  end

  describe 'StringProc exits' do
    it 'calls a StringProc direct edge instead of sending it as a command' do
      world = WalkToUnknownRoomSpec::World.new(corridor(1), position: 101)
      way = StringProc.new('nil')
      allow(way).to receive(:call) { world.position = 102 }
      world.room(101).wayto['102'] = way
      install(world)

      expect(DRCT.walk_to(102)).to be(true)
      expect(way).to have_received(:call).once
      expect(world.sent).to be_empty
    end

    it 'calls a StringProc first hop of a longer path' do
      world = WalkToUnknownRoomSpec::World.new(corridor(2), position: 101)
      way = StringProc.new('nil')
      allow(way).to receive(:call) { world.position = 102 }
      world.room(101).wayto['102'] = way
      install(world)

      expect(DRCT.walk_to(103)).to be(true)
      expect(way).to have_received(:call).once
      expect(world.sent).to eq(['north'])
    end
  end

  describe 'a target the map cannot reach' do
    it 'fails without sending anything when the target is not in the map' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(1), position: 101))

      expect(DRCT.walk_to(999)).to be(false)
      expect(world.sent).to be_empty
      expect(bold_messages.last).to include('No map path from room 101 to room 999')
    end

    it 'does not walk toward room 0 when the target is not in the map' do
      rooms = corridor(2) << make_room(0, { '103' => 'east' })
      rooms[2].wayto['0'] = 'west'
      world = install(WalkToUnknownRoomSpec::World.new(rooms, position: 101))

      expect(DRCT.walk_to(999)).to be(false)
      expect(world.sent).to be_empty
      expect(Map).not_to have_received(:findpath)
      expect(bold_messages.last).to include('No map path from room 101 to room 999')
    end

    it 'does not walk toward the last room for a negative target id' do
      world = WalkToUnknownRoomSpec::World.new(corridor(2), position: 101)
      install(world)
      # The real Map[] indexes an Array, so a negative id is a real room.
      allow(Map).to receive(:[]) { |id| id.to_i.negative? ? world.rooms.values[id.to_i] : world.room(id.to_i) }

      expect(DRCT.walk_to(-1)).to be(false)
      expect(world.sent).to be_empty
      expect(Map).not_to have_received(:findpath)
      expect(bold_messages.last).to include('No map path from room 101 to room -1')
    end

    it 'fails without sending anything when findpath returns nil' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(2), position: 101))
      allow(Map).to receive(:findpath).and_return(nil)

      expect(DRCT.walk_to(103)).to be(false)
      expect(world.sent).to be_empty
    end

    it 'fails without sending anything when the path names a room with no edge from here' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(2), position: 101))
      allow(Map).to receive(:findpath).and_return([555, 103])

      expect(DRCT.walk_to(103)).to be(false)
      expect(world.sent).to be_empty
    end
  end

  describe 'moves that fail' do
    it 'retries a blocked move MAX_WALK_TO_RETRIES times, then gives up' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(1), position: 101))
      world.overrides[[101, 'north']] = nil

      expect(DRCT.walk_to(102)).to be(false)
      expect(world.sent).to eq(['north'] * (DRCT::MAX_WALK_TO_RETRIES + 1))
      expect(bold_messages.last).to include('giving up')
    end

    it 'does not retry a blocked move when restart_on_fail is false' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(1), position: 101))
      world.overrides[[101, 'north']] = nil

      expect(DRCT.walk_to(102, false)).to be(false)
      expect(world.sent).to eq(['north'])
    end

    it 'stops at once when the game rejects the exit' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(1), position: 101))
      world.overrides[[101, 'north']] = false

      expect(DRCT.walk_to(102)).to be(false)
      expect(world.sent).to eq(['north'])
      expect(bold_messages.last).to include("The exit 'north' from room 101 did not work")
    end

    it 'shares the retry budget already spent by walk_to' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(1), position: 101))
      world.overrides[[101, 'north']] = nil

      expect(DRCT.walk_to(102, true, retry_depth: DRCT::MAX_WALK_TO_RETRIES)).to be(false)
      expect(world.sent).to eq(['north'])
    end

    it 'counts a move into an unexpected room as a retry and walks on from there' do
      rooms = corridor(2) << make_room(104, { '102' => 'west' }, paths: 'Obvious paths: west.')
      world = install(WalkToUnknownRoomSpec::World.new(rooms, position: 101))
      world.overrides[[101, 'north']] = 104

      expect(DRCT.walk_to(103)).to be(true)
      expect(world.sent).to eq(%w[north west north])
    end
  end

  describe 'a room that resolves on one read and not the next' do
    # walk_to reads Room.current twice before it hands over (the arrival check
    # and the unknown-room check); the walker reads it once more first.
    it 'goes to go2 when the room resolves between walk_to and the walker' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(2), position: 101))
      reads = 0
      allow(Room).to receive(:current) do
        reads += 1
        reads <= 2 ? nil : world.room(world.position)
      end

      expect(DRCT.walk_to(103)).to be(true)
      expect(world.sent).to be_empty
      expect(DRCT).to have_received(:start_script).with('go2', ['103'], force: true).once
      expect(plain_messages).to include('DRCT: Room 101 resolved again without a move, handing back (retry 1/3).')
    end

    it 'gives up instead of bouncing between walk_to and the walker forever' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(2), position: 101))
      # nil for walk_to's second read, the room for the walker and for
      # walk_to's first read, over and over, with no move in between.
      reads = 0
      allow(Room).to receive(:current) do
        reads += 1
        ((reads - 2) % 3).zero? || reads == 1 ? nil : world.room(world.position)
      end

      result = Timeout.timeout(5) { DRCT.walk_to(103) }

      expect(result).to be(false)
      expect(world.sent).to be_empty
      expect(DRCT).not_to have_received(:start_script)
      expect(plain_messages.grep(/handing back/)).to eq(
        (1..DRCT::MAX_WALK_TO_RETRIES).map { |n| "DRCT: Room 101 resolved again without a move, handing back (retry #{n}/3)." }
      )
      expect(bold_messages.last).to eq('DRCT: Room 101 resolved again without a move; no retries left (3), giving up.')
    end

    it 'counts a bounce against the retries walk_to already spent' do
      world = install(WalkToUnknownRoomSpec::World.new(corridor(2), position: 101))
      reads = 0
      allow(Room).to receive(:current) do
        reads += 1
        reads <= 2 ? nil : world.room(world.position)
      end

      expect(DRCT.walk_to(103, true, retry_depth: DRCT::MAX_WALK_TO_RETRIES)).to be(false)
      expect(DRCT).not_to have_received(:start_script)
      # One bounce after walk_to spent the budget: the message must not claim
      # the room kept alternating, and no hand-back was logged.
      expect(bold_messages.last).to eq('DRCT: Room 101 resolved again without a move; no retries left (3), giving up.')
      expect(plain_messages.grep(/handing back/)).to be_empty
    end
  end

  describe 'a map that leads in circles' do
    it 'stops after the first path length plus MAX_WALK_TO_RETRIES moves' do
      rooms = [
        make_room(101, { '102' => 'north' }),
        make_room(102, { '103' => 'north' }),
        make_room(103, { '101' => 'north' }),
        make_room(104, {})
      ]
      world = install(WalkToUnknownRoomSpec::World.new(rooms, position: 101))
      # Every room claims the target is two rooms away through the next one.
      allow(Map).to receive(:findpath) do |source, _destination|
        [source.wayto.keys.first.to_i, 104]
      end

      result = Timeout.timeout(5) { DRCT.walk_to(104) }

      expect(result).to be(false)
      expect(world.sent.size).to eq(2 + DRCT::MAX_WALK_TO_RETRIES)
      expect(bold_messages.last).to include('within 5 moves')
    end
  end
end
