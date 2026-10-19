# frozen_string_literal: true

require_relative '../../../spec_helper'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-travel.rb')

DRCT = Lich::DragonRealms::DRCT unless defined?(DRCT)

# walk_to from an unresolved room and after go2, against the DR map's own
# resolver (Lich::Common::Map.current with a script running) instead of a
# fake one.
#
# walk_to treats the character as being in a room only when Room.current
# resolves it, both for the start room and for arrival, and adds no matching
# of its own. It is therefore exactly as strict as that resolver, including
# the resolver's own looseness (in fog it ignores exits, it takes the first
# match with no uniqueness check, its second pass matches a single shared
# description sentence, and with the room window disabled it matches title
# and exits only). From a room the map cannot resolve, even after a short
# wait, walk_to fails without moving, for numeric and tag targets alike.
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
    allow(DRCT).to receive(:pause)

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
    allow(Map).to receive(:rooms_by_tag) { |tag| real_map.rooms_by_tag(tag) }

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

  def unresolved_tag_message(tag)
    "DRCT: Unable to resolve the current room, cannot walk to a room tagged '#{tag}'."
  end

  # Runs the block in a forked child that has loaded Lich's NilClass patch
  # (lib/common/class_exts/nilclass.rb), which the Lich runtime always loads
  # and rspec does not. The patch makes nil answer any method with nil, so
  # this is the behaviour players actually get. Forking keeps the patch out of
  # this process. Returns [:ok, block value] or [:raised, "Class: message"].
  def with_nilclass_patch
    skip 'needs Process.fork' unless Process.respond_to?(:fork)

    reader, writer = IO.pipe
    pid = fork do
      reader.close
      load File.join(LIB_DIR, 'common', 'class_exts', 'nilclass.rb')
      outcome = begin
        [:ok, yield]
      rescue Exception => e # rubocop:disable Lint/RescueException
        [:raised, "#{e.class}: #{e.message}"]
      end
      writer.write(Marshal.dump(outcome))
      writer.close
      exit!(0)
    end
    writer.close
    data = reader.read
    reader.close
    Process.wait(pid)
    Marshal.load(data)
  end

  # The corridor with room 3 tagged 'bank'.
  def tagged_corridor
    corridor
    real_map[3].tags = ['bank']
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

    it 'waits once for the room to resolve before failing' do
      corridor
      live[:uids][1] = 1777
      place(1)

      expect(DRCT.walk_to(3)).to be(false)
      expect(DRCT).to have_received(:pause).with(DRCT::WALK_TO_UNRESOLVED_WAIT).once
    end

    it 'does not stand the character up before failing' do
      corridor
      live[:uids][1] = 1777
      place(1)

      expect(DRCT.walk_to(3)).to be(false)
      expect(DRC).not_to have_received(:fix_standing)
    end

    it 'waits on every call, so a caller looping on walk_to without checking the result does not spin' do
      corridor
      live[:uids][2] = 2777
      place(2)

      results = Array.new(5) { [1, 3].map { |target| DRCT.walk_to(target) } }.flatten
      expect(results).to all(be(false))
      expect(DRCT).to have_received(:pause).with(DRCT::WALK_TO_UNRESOLVED_WAIT).exactly(10).times
      expect(bold_messages.size).to eq(10)
      expect(sent).to be_empty
    end

    it 'walks with go2 when the room resolves during the wait' do
      corridor
      live[:uids][1] = 1777
      place(1)
      allow(DRCT).to receive(:pause) do
        live[:uids][1] = 1001
        live[:count] += 1
      end

      expect(DRCT.walk_to(3)).to be(true)
      expect(DRCT).to have_received(:start_script).with('go2', ['3'], force: true).once
      expect(sent).to be_empty
      expect(bold_messages).to be_empty
    end

    it 'returns true without go2 when the room resolves to the target during the wait' do
      corridor
      live[:uids][3] = 3777
      place(3)
      allow(DRCT).to receive(:pause) do
        live[:uids][3] = 1003
        live[:count] += 1
      end

      expect(DRCT.walk_to(3)).to be(true)
      expect(DRCT).not_to have_received(:start_script)
      expect(bold_messages).to be_empty
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

  describe 'where the resolver itself is first-match' do
    # Pins the resolver's existing behaviour, which walk_to inherits: rooms 2
    # and 4 share title, description and exits; room 2, listed first, stores
    # a UID and room 4 has none. With a live UID the map does not know, the
    # resolver takes room 2, vetoes it and returns nil without trying room 4,
    # so walk_to fails even though only room 4 could be the live room. A
    # stricter per-candidate rule belongs in the resolver, not in walk_to.
    it 'fails without moving when a vetoed room hides an identical room with no stored UID' do
      build_room(1, { '4' => 'up' }, uid: [1001])
      build_room(2, { '1' => 'down' }, uid: [2002], title: '[Twin Loft]', description: 'A dusty loft.')
      build_room(4, { '1' => 'down' }, title: '[Twin Loft]', description: 'A dusty loft.')
      live[:uids][4] = 4777
      place(4)
      expect(Room.current).to be_nil

      expect(DRCT.walk_to(1)).to be(false)
      expect(sent).to be_empty
      expect(bold_messages).to eq([unresolved_message(1)])
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

    it "returns false when the target's stored UID is stale, with only the unresolved-room message (restart_on_fail true)" do
      corridor
      live[:uids][3] = 3777
      place(1)

      expect(DRCT.walk_to(3, true)).to be(false)
      expect(DRCT).to have_received(:start_script).once
      expect(DRCT).to have_received(:pause).with(DRCT::WALK_TO_UNRESOLVED_WAIT).once
      expect(bold_messages).to eq([unresolved_message(3)])
    end

    it 'returns true when the target resolves during the wait after go2' do
      corridor
      live[:uids][3] = 3777
      place(1)
      allow(DRCT).to receive(:pause) do
        live[:uids][3] = 1003
        live[:count] += 1
      end

      expect(DRCT.walk_to(3, true)).to be(true)
      expect(DRCT).to have_received(:start_script).once
      expect(bold_messages).to be_empty
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

  describe 'tag targets' do
    def walk_outcome(target)
      pauses = 0
      allow(DRCT).to receive(:pause) { pauses += 1 }
      result = DRCT.walk_to(target)
      { result: result, sent: sent.dup, bold: bold_messages, pauses: pauses, go2: go2_targets.dup }
    end

    # The rooms go2 was started toward, in order.
    let(:go2_targets) { [] }

    before do
      allow(DRCT).to receive(:start_script) do |_name, args, **_opts|
        go2_targets << args.first
        place(args.first.to_i)
        :go2_handle
      end
    end

    context 'from a room the map does not resolve' do
      before do
        tagged_corridor
        live[:uids][1] = 1777
        place(1)
      end

      it 'fails with the unresolved-room message after one wait, sending nothing' do
        expect(Room.current).to be_nil

        expect(walk_outcome('bank')).to eq(result: false, sent: [], bold: [unresolved_tag_message('bank')], pauses: 1, go2: [])
        expect(DRC).not_to have_received(:fix_standing)
      end

      it 'fails the same way with the NilClass patch loaded' do
        expect(with_nilclass_patch { walk_outcome('bank') })
          .to eq([:ok, { result: false, sent: [], bold: [unresolved_tag_message('bank')], pauses: 1, go2: [] }])
      end

      it 'tag_to_id returns nil with the unresolved-room message after one wait' do
        expect(DRCT.tag_to_id('bank')).to be_nil
        expect(bold_messages).to eq([unresolved_tag_message('bank')])
        expect(DRCT).to have_received(:pause).with(DRCT::WALK_TO_UNRESOLVED_WAIT).once
      end

      it 'tag_to_id returns nil with the unresolved-room message with the NilClass patch loaded' do
        expect(with_nilclass_patch { [DRCT.tag_to_id('bank'), bold_messages] })
          .to eq([:ok, [nil, [unresolved_tag_message('bank')]]])
      end

      it 'waits on every call, so a caller looping on a tag target does not spin' do
        outcomes = Array.new(3) { DRCT.walk_to('bank') }
        expect(outcomes).to all(be(false))
        expect(DRCT).to have_received(:pause).with(DRCT::WALK_TO_UNRESOLVED_WAIT).exactly(3).times
        expect(bold_messages).to eq([unresolved_tag_message('bank')] * 3)
        expect(sent).to be_empty
      end

      it 'reports an unknown tag without waiting' do
        expect(walk_outcome('nowhere'))
          .to eq(result: false, sent: [], bold: ["DRCT: No go2 targets matching 'nowhere' found."], pauses: 0, go2: [])
      end

      it 'reports an unknown tag without waiting with the NilClass patch loaded' do
        expect(with_nilclass_patch { walk_outcome('nowhere') })
          .to eq([:ok, { result: false, sent: [], bold: ["DRCT: No go2 targets matching 'nowhere' found."], pauses: 0, go2: [] }])
      end

      it 'walks to the tagged room with go2 when the room resolves during the wait' do
        allow(DRCT).to receive(:pause) do
          live[:uids][1] = 1001
          live[:count] += 1
        end

        expect(DRCT.walk_to('bank')).to be(true)
        expect(go2_targets).to eq(['3'])
        expect(bold_messages).to be_empty
        expect(sent).to be_empty
      end
    end

    it 'returns true without go2 when the room resolves to the tagged room during the wait' do
      tagged_corridor
      live[:uids][3] = 3777
      place(3)
      allow(DRCT).to receive(:pause) do
        live[:uids][3] = 1003
        live[:count] += 1
      end

      expect(DRCT.walk_to('bank')).to be(true)
      expect(go2_targets).to be_empty
      expect(bold_messages).to be_empty
    end

    it 'does not take an unresolved room carrying the tag as already there' do
      tagged_corridor
      live[:uids][3] = 3777
      place(3)
      expect(Room.current).to be_nil

      expect(walk_outcome('bank')).to eq(result: false, sent: [], bold: [unresolved_tag_message('bank')], pauses: 1, go2: [])
    end

    it 'walks to the nearest tagged room from a resolved room without waiting' do
      tagged_corridor
      place(1)

      expect(walk_outcome('bank')).to eq(result: true, sent: [], bold: [], pauses: 0, go2: ['3'])
    end
  end
end
