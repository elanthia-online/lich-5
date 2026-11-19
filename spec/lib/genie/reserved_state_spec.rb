# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# ReservedState: captured value, then host value, then Remix's SetDefaultGlobalVars default
# (Globals.cs:825-919 R), exact case.
RSpec.describe Lich::Genie::ReservedState do
  let(:capture) { Lich::Genie::GameState.new(write_clock: Lich::Genie::WriteClock.new) }
  let(:host) { {} }
  let(:statics) { {} }
  subject(:reserved) { described_class.new(game_state: capture, statics: statics, host: host) }

  it "starts from Remix's defaults, the @-specials as literals" do
    expect(%w[health preparedspell lefthand roomobjs zoneid scriptlist connected north].map { |n| reserved[n] })
      .to eq(['100', 'None', 'Empty', '', '0', 'none', '0', '0'])
    expect(%w[time unixtime spelltime spellpreptime casttimeremaining scriptdir].map { |n| reserved[n] })
      .to eq(%w[@time@ @unixtime@ @spelltime@ @spellpreptime@ @casttimeremaining@ @scriptdir@])
  end

  it 'is Genie Remix Client 4 / 4.2.4.0 (Globals.cs:890-891 R; Genie4.csproj Product)' do
    expect([reserved['client'], reserved['version']]).to eq(['Genie Remix Client 4', '4.2.4.0'])
  end

  it "copies Remix's repeatregex verbatim, backslash-quote included" do
    expect(reserved['repeatregex']).to eq("^\\.\\.\\.wait|^Sorry\\, you may only type ahead|^You are still stunned|" \
                                          "^You can\\'t do that while|^You don\\'t seem to be able")
  end

  it 'leaves names Remix only creates on a game update undefined until then ($uid, hand ids, bar text)' do
    %w[uid lefthandid righthandid healthBarText lastinput].each { |name| expect(reserved.key?(name)).to be(false), name }
    capture.feed(%(<streamWindow id='room' subtitle=" - [Crossing, Town Green] (12345)"/>\r\n))
    expect([reserved['uid'], reserved['roomname']]).to eq(['12345', 'Crossing, Town Green'])
  end

  it 'has none of the non-Remix supersets and is case-sensitive' do
    %w[inside gameroomid name level maxhealth roomtitle Mana Bleeding Health RoomObjs].each do |name|
      expect(reserved.key?(name)).to be(false), name
    end
  end

  it 'gives $unixtime the special until the first prompt, then the snapshot' do
    expect(reserved['unixtime']).to eq('@unixtime@')
    capture.feed(%(<prompt time="1">&gt;</prompt>\r\n))
    expect(reserved['unixtime']).to match(/\A\d+\z/)
  end

  context 'with host values and statics' do
    let(:statics) { { 'connected' => '1' } }
    let(:host) { { 'health' => -> { 77 }, 'zoneid' => -> {}, 'roomid' => -> { '42' }, 'mana' => -> { raise 'mid-reset' } } }

    it 'prefers a captured value, then the host value, then the static/default' do
      expect([reserved['health'], reserved['connected'], reserved['roomid']]).to eq(%w[77 1 42])
      capture.feed("<progressBar id='health' value='55' text='health 55%'/>\r\n")
      expect(reserved['health']).to eq('55')
    end

    it 'falls through to the default when the host has no value or raises' do
      expect([reserved['zoneid'], reserved['mana']]).to eq(%w[0 100])
    end
  end

  # A tester's real variables.cfg holds `#var {roomid} {118}` and
  # `#var {game} {DR}`; Remix's automapper and connect overwrite both (AutoMapper.cs:857 R,
  # Game.cs:403 R), so the stored copy never shadows the live value.
  context "with the host values that stand for a Remix writer (a tester's variables.cfg)" do
    let(:write_clock) { Lich::Genie::WriteClock.new }
    let(:store) do
      Lich::Genie::GlobalStore.new(file: File.expand_path('../../fixtures/genie/game_state/tester_variables.cfg', __dir__),
                                   write_clock: write_clock)
    end
    let(:readings) { { 'roomid' => '42', 'zone' => '1', 'game' => 'DRT' } }
    let(:capture) do
      store # variables.cfg is read at engine start, before the capture starts
      Lich::Genie::GameState.new(write_clock: write_clock)
    end
    let(:host) do
      now = readings
      { 'roomid' => -> { now['roomid'] }, 'zoneid' => -> { now['zone'] }, 'game' => -> { now['game'] },
        'zonename' => -> { Lich::Genie::ZONE_NAMES[now['zone']] } }
    end
    subject(:reserved) { described_class.new(game_state: capture, host: host, host_stamps: described_class::HOST_STAMPS) }

    let(:vars) { Lich::Genie::Variables.new(game_state: reserved, global_store: store) }

    def room_update(name = 'Room')
      capture.feed(%(<streamWindow id='room' subtitle=" - [#{name}] (1)"/>\r\n))
      capture.feed(%(<prompt time="1">&gt;</prompt>\r\n))
    end

    it 'reads the live $roomid and $game over the stored 118 and DR' do
      expect([store.get('roomid'), store.get('game')]).to eq(%w[118 DR])
      expect([vars.global_get('roomid'), vars.global_get('game')]).to eq(%w[42 DRT])
    end

    it "keeps a script's #var roomid until the automapper's next room update, then the live value" do
      vars.global_set('roomid', '5')
      capture.feed(%(<prompt time="1">&gt;</prompt>\r\n)) # a prompt alone is no room update
      expect(vars.global_get('roomid')).to eq('5')
      readings['roomid'] = '43'
      room_update
      expect(vars.global_get('roomid')).to eq('43')
    end

    it "keeps a script's #var game for good (Remix writes $game at connect only)" do
      vars.global_set('game', 'XX')
      room_update
      expect(vars.global_get('game')).to eq('XX')
    end

    it "keeps a script's #var zoneid through room updates in the same zone, not past a zone change" do
      expect([vars.global_get('zoneid'), vars.global_get('zonename')]).to eq(%w[1 Crossing])
      vars.global_set('zoneid', '99')
      vars.global_set('zonename', 'Nowhere')
      room_update
      expect([vars.global_get('zoneid'), vars.global_get('zonename')]).to eq(%w[99 Nowhere])
      readings['zone'] = '67'
      room_update
      expect([vars.global_get('zoneid'), vars.global_get('zonename')]).to eq(%w[67 Shard])
    end

    it 'notes the zone when a script writes it, so a later same-zone room update is not a change' do
      vars.global_set('zoneid', '99') # nothing read $zoneid before
      room_update
      expect(vars.global_get('zoneid')).to eq('99')
      readings['zone'] = '7a'
      room_update
      expect([vars.global_get('zoneid'), vars.global_get('zonename')]).to eq(%w[7a Vineyard])
    end

    it "keeps a #var made after the room update that changed the zone (the change predates it)" do
      readings['zone'] = '67'
      room_update
      vars.global_set('zoneid', '99') # before anything read the new zone
      expect(vars.global_get('zoneid')).to eq('99')
    end

    # Lich's map places the new room as soon as the
    # room title arrives, but Remix's automapper loads the new map (and writes $zoneid)
    # only at the room update on the next prompt (AutoMapper.cs:269-278, 1925-1933 R). A
    # zone reading first seen in that window belongs to that room update, so whether a
    # script happened to read $zoneid between the title and the prompt changes nothing.
    [false, true].each do |read_between|
      it "lets a zone change override a #var zoneid at the next room update (read between title and prompt: #{read_between})" do
        room_update
        expect(vars.global_get('zoneid')).to eq('1')
        vars.global_set('zoneid', '5')
        capture.feed(%(<streamWindow id='room' subtitle=" - [Wilds, B] (2)"/>\r\n))
        readings['zone'] = '67'
        expect(vars.global_get('zoneid')).to eq('5') if read_between # the map load has not happened yet
        capture.feed(%(<prompt time="2">&gt;</prompt>\r\n))
        expect([vars.global_get('zoneid'), vars.global_get('zonename')]).to eq(%w[67 Shard])
        room_update('Wilds, C')
        expect(vars.global_get('zoneid')).to eq('67')
      end
    end

    it 'drops a zone reading that reverts before the room update (no map load, the #var holds)' do
      room_update
      vars.global_get('zoneid')
      vars.global_set('zoneid', '5')
      capture.feed(%(<streamWindow id='room' subtitle=" - [Wilds, B] (2)"/>\r\n))
      readings['zone'] = '67'
      expect(vars.global_get('zoneid')).to eq('5')
      readings['zone'] = '1'
      expect(vars.global_get('zoneid')).to eq('5')
      capture.feed(%(<prompt time="2">&gt;</prompt>\r\n))
      expect(vars.global_get('zoneid')).to eq('5')
    end

    it 'reads the host value for a :zone stamp only (a $roomid/$game stamp or #var reads no map)' do
      calls = Hash.new(0)
      counting = described_class.new(game_state: capture, host_stamps: described_class::HOST_STAMPS,
                                     host: %w[roomid game zoneid].to_h { |n| [n, -> { calls[n] += 1 }] })
      %w[roomid game zoneid].each { |name| counting.stamp(name) && counting.observe(name) }
      expect(calls).to eq('zoneid' => 2)
    end

    it 'gives a host name without a policy no stamp, and a captured name its capture stamp' do
      plain = described_class.new(game_state: capture, host: host)
      expect(plain.stamp('roomid')).to be_nil
      capture.feed("<indicator id='IconHIDDEN' visible='y'/>\r\n")
      expect(reserved.stamp('hidden')).to eq(capture.stamp('hidden'))
    end
  end

  it 'passes a runtime #config to the capture' do
    reserved.apply_setting('monstercountignorelist', 'goblin')
    expect(capture.config.ignore_monster_list).to eq('goblin')
  end

  it 'exposes the capture stamp and spell timer' do
    capture.feed("<spell>Shadows</spell>\r\n")
    expect(reserved.stamp('preparedspell')).to be_a(Integer)
    expect(reserved.spell_time_start).to be_a(Time)
    expect(reserved.stamp('health')).to be_nil
  end
end

RSpec.describe 'Lich::Genie::ZONE_NAMES' do
  # Generated from the Genie-Maps Map*.xml <zone name id> (genie-port-lab/reference/
  # gen_zone_names.rb); Remix's $zonename is the loaded map's zone name (MapForm.cs:650-662 R).
  it 'names every Genie map zone by its id, letters and quotes included' do
    names = Lich::Genie::ZONE_NAMES
    expect(names.size).to eq(90)
    expect(names.values_at('1', '67', '7a', '106', 'TF990', '150'))
      .to eq(['Crossing', 'Shard', 'Vineyard', "Hara'jaal", 'The Extreme Shop (TF)', 'Fang Cove'])
    expect(names.key?('0')).to be(false)
    expect(names).to be_frozen
  end
end

RSpec.describe Lich::Genie::StickyValue do
  it 'keeps the last non-empty reading through unknown (nil/empty) readings ($zoneid)' do
    zone = described_class.new
    expect(zone.update(nil)).to be_nil
    expect(zone.update('66')).to eq('66')
    expect(zone.update(nil)).to eq('66')
    expect(zone.update('')).to eq('66')
    expect(zone.update(7)).to eq('7')
  end
end

# $zoneid/$zonename from the zone Lich's map stamps on the current room. Remix's
# automapper writes both only when it loads a map (AutoMapper.cs:1925-1933 R), and a map
# with an empty <zone name> keeps the previous name (MapForm.cs:658-668 R); for a zone with
# no Genie map (festival maps) Remix loads nothing, so the name stays.
RSpec.describe Lich::Genie::ZoneTracker do
  subject(:zone) { described_class.new }

  it 'is unknown (nil: the "0" default) before any zone' do
    expect([zone.id(nil), zone.name(nil)]).to eq([nil, nil])
  end

  it 'names a zone from the Genie maps and keeps both through an unmapped room' do
    expect([zone.id('1'), zone.name('1')]).to eq(%w[1 Crossing])
    expect([zone.id(nil), zone.name(nil)]).to eq(%w[1 Crossing])
    expect([zone.id(''), zone.name('')]).to eq(%w[1 Crossing])
  end

  it 'keeps the previous name for a zone id with no Genie map, then names the next known one' do
    zone.name('1')
    expect([zone.id('501f'), zone.name('501f')]).to eq(%w[501f Crossing])
    expect(zone.name('7a')).to eq('Vineyard')
  end

  it 'has no name for an unknown first zone (the "0" default stays)' do
    expect([zone.id('501f'), zone.name('501f')]).to eq(['501f', nil])
  end

  it 'reads names from the table it is given' do
    expect(described_class.new(names: { 'x' => 'Ex' }).name('x')).to eq('Ex')
  end

  # The names ListVariables shows as "(reserved)" (Command.cs:3041-3051 R).
  describe '#names' do
    it 'holds SetDefaultGlobalVars\' names, the captured ones and the host names with a value' do
      capture = Lich::Genie::GameState.new(write_clock: Lich::Genie::WriteClock.new)
      capture.feed(%(<left exist="1" noun="sword">a sword</left>\r\n))
      reserved = Lich::Genie::ReservedState.new(game_state: capture, host: { 'roomid' => -> { '7' }, 'gone' => -> {} })
      names = reserved.names
      expect(names).to include('health', 'client', 'version', 'time', 'lefthandid', 'roomid')
      expect(names).not_to include('gone')
      expect(names.uniq).to eq(names)
    end
  end
end

# The display port's host values. A substitute's replacement is ParseGlobalVars'd on
# Lich's parser thread, which must never run host code that can wait on another thread (Lich's Map
# loads under a lock its loader holds while it prints): live reads record what they return, and the
# display port's resolver answers from those recordings only.
RSpec.describe Lich::Genie::HostReadings do
  subject(:readings) { described_class.new }

  let(:calls) { [] }
  let(:live) do
    log = calls
    {
      'roomid' => lambda {
        log << :roomid
        '118'
      },
      'zoneid' => lambda {
        log << :zoneid
        nil
      },
      'broken' => -> { raise 'map reset' }
    }
  end

  it 'records each live read (nil too: the replay then falls back to the default like the live read)' do
    readings.record('zoneid', '7')
    recording = readings.recording(live)
    expect([recording['roomid'].call, recording['zoneid'].call]).to eq(['118', nil])
    expect([readings['roomid'], readings['zoneid']]).to eq(['118', nil])
  end

  it 'keeps the previous reading when a live read raises (the raise reaches the caller)' do
    readings.record('broken', '7')
    expect { readings.recording(live)['broken'].call }.to raise_error(RuntimeError, 'map reset')
    expect(readings['broken']).to eq('7')
  end

  it 'replays the last reading without calling the host, nil before any' do
    replay = readings.replaying(live.keys)
    expect(replay['roomid'].call).to be_nil
    readings.recording(live)['roomid'].call
    readings.record('roomid', '200')
    expect(replay['roomid'].call).to eq('200')
    expect(calls).to eq([:roomid])
  end

  it 'gives a ReservedState over the replay the last reading and its stamp, with no host call' do
    capture = Lich::Genie::GameState.new(write_clock: Lich::Genie::WriteClock.new)
    readings.recording(live)['roomid'].call
    reserved = Lich::Genie::ReservedState.new(game_state: capture, host: readings.replaying(live.keys),
                                              host_stamps: Lich::Genie::ReservedState::HOST_STAMPS)
    expect([reserved['roomid'], reserved.stamp('roomid'), reserved['zoneid']]).to eq(['118', capture.host_stamp('roomid', :room), '0'])
    expect(calls).to eq([:roomid])
  end
end
