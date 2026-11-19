# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# The glue's game-state plumbing, headless: a stub class
# stands in for Lich::Common::Script (its singleton new_downstream_xml records what reaches
# Lich), a plain Array for $_SERVERBUFFER_.
RSpec.describe Lich::Genie::GameStateFeed do
  let(:globals) { Lich::Genie::GlobalStore.new }
  let(:capture) { Lich::Genie::GameState.new(write_clock: Lich::Genie::WriteClock.new, globals: globals) }
  let(:errors) { [] }
  let(:upstream_errors) { [] }
  let(:feed) do
    state = capture
    described_class.new(game_state: -> { state }, report: ->(e) { errors << e }, upstream_report: ->(e) { upstream_errors << e })
  end
  let(:lich) do
    Class.new do
      class << self
        def received = (@received ||= [])

        def new_downstream_xml(line) = received << line
      end
    end
  end
  let(:room_a) { %(<streamWindow id='room' subtitle=" - [Room A] (1)"/>\r\n) }
  let(:room_b) { %(<streamWindow id='room' subtitle=" - [Room B] (2)"/>\r\n) }

  # The tap marks the thread that calls it as Lich's game parser thread (READER_KEY); in a spec
  # that is the example's own thread, so the mark is put back after each example.
  around do |example|
    previous = Thread.current[described_class::READER_KEY]
    example.run
  ensure
    Thread.current[described_class::READER_KEY] = previous
  end

  def raising_feed(error = RuntimeError.new('capture broke'))
    described_class.new(game_state: -> { raise error }, report: ->(e) { errors << e }, upstream_report: ->(e) { upstream_errors << e })
  end

  describe 'the live feed (Script.new_downstream_xml tap)' do
    it 'feeds each raw server string to the capture, then hands it on to Lich' do
      feed.install(lich, buffer: -> { [] })
      lich.new_downstream_xml(room_b)
      expect(capture['roomname']).to eq('Room B')
      expect(lich.received).to eq([room_b])
    end

    # The genie InputBuffer drops what Lich pushes from that thread (its strip_xml lines).
    it 'marks the calling thread as the game parser thread, and only that one' do
      feed.install(lich, buffer: -> { [] })
      other = Thread.new { Thread.current[described_class::READER_KEY] }.value
      lich.new_downstream_xml(room_b)
      expect([Thread.current[described_class::READER_KEY], other]).to eq([true, nil])
    end

    it "contains a capture error: Lich's parser loop still gets the row and nothing raises (games.rb:1136)" do
      broken = raising_feed
      lich.singleton_class.prepend(broken.tap)
      expect { lich.new_downstream_xml(room_b) }.not_to raise_error
      expect(lich.received).to eq([room_b])
      expect(errors.map(&:message)).to eq(['capture broke'])
    end

    it 'ignores what is not a String' do
      expect { feed.feed(nil) }.not_to raise_error
      expect(errors).to be_empty
    end

    it 'builds one tap per feed, so installing twice prepends it once' do
      2.times { feed.install(lich, buffer: -> { [] }) }
      expect(lich.singleton_class.ancestors.count(feed.tap)).to eq(1)
      lich.new_downstream_xml(room_b)
      expect(lich.received).to eq([room_b])
    end
  end

  # Installed at Lich load, gated on the engine being on for the logged-in character.
  describe 'the gated install (Lich load)' do
    let(:open_flag) { [false] }
    let(:opened) { [] }

    def gated(buffer)
      flag = open_flag
      seen = opened
      feed.install(lich, buffer: -> { buffer }, gate: -> { flag[0] }, on_open: -> { seen << capture['roomname'] })
    end

    it 'feeds nothing while the gate is shut, then replays the buffer once and starts the engine on the first open row' do
      buffer = [room_a]
      gated(buffer)
      expect(feed.installed?(lich)).to be(true)
      lich.new_downstream_xml(room_a)
      expect([capture['roomname'], opened]).to eq([nil, []])
      open_flag[0] = true
      buffer << room_b # Lich pushes the row into its buffer before the tap sees it (games.rb:1001, 1136)
      lich.new_downstream_xml(room_b)
      # the engine starts after the replay of the rows BEFORE the in-flight one, which is fed live then
      expect([capture['roomname'], opened]).to eq(['Room B', ['Room A']])
      lich.new_downstream_xml(room_a)
      expect([capture['roomname'], opened.length]).to eq(['Room A', 1]) # opened once
      expect(lich.received).to eq([room_a, room_b, room_a]) # Lich always gets the row
    end

    # v0.26.3: the row that opens the feed is a row of the open session -- applied once, live, with
    # its changes (the first #trigger match after a turn-on is not swallowed by the replay).
    it 'replays the rows before the in-flight one silently, then feeds the in-flight row live, once' do
      batches = []
      capture.listener = ->(batch) { batches << batch.to_a }
      open_flag[0] = true
      gated([room_a, room_b])
      lich.new_downstream_xml(room_b) # the snapshot's last row, on its way
      expect([capture['roomname'], batches]).to eq(['Room B', [%w[$roomname $uid]]])
    end

    it 'leaves out only that very row (by identity): an equal row earlier in the buffer is replayed' do
      open_flag[0] = true
      gated([room_b.dup, room_b])
      lich.new_downstream_xml(room_b)
      expect([capture['roomname'], opened]).to eq(['Room B', ['Room B']]) # the copy was replayed before the start
    end

    # Review item 3 (v0.26.3): the gate is asked on every row, not only until the first open.
    it 'closes when the gate shuts mid-session and re-opens (replaying again) when it allows again' do
      buffer = [room_a]
      gated(buffer)
      open_flag[0] = true
      lich.new_downstream_xml(room_a)
      expect([capture['roomname'], opened]).to eq(['Room A', [nil]]) # the in-flight row is not replayed
      open_flag[0] = false
      buffer << room_b
      lich.new_downstream_xml(room_b) # Lich parses it while the engine is off
      expect(capture['roomname']).to eq('Room A')
      open_flag[0] = true
      room_c = %(<streamWindow id='room' subtitle=" - [Room C] (3)"/>\r\n)
      buffer << room_c
      batches = []
      capture.listener = ->(batch) { batches << batch.to_a }
      lich.new_downstream_xml(room_c)
      # re-open: the replay catches up on Room B (parsed while closed), then Room C is fed live
      expect([capture['roomname'], opened, batches]).to eq(['Room C', [nil, 'Room B'], [%w[$roomname $uid]]])
      expect(lich.received).to eq([room_a, room_b, room_c])
    end

    # A re-open must not apply again the rows the capture applied before the
    # turn-off (a replay of the whole buffer did: Lich's buffer still holds them).
    context 'when re-opened after a turn-off' do
      let(:applied) { [] }
      let(:recording) do
        log = applied
        recorder = Object.new
        recorder.define_singleton_method(:feed) { |row| log << row }
        recorder.define_singleton_method(:seed) { |&rows| log.concat(rows.call) }
        described_class.new(game_state: -> { recorder }, report: ->(e) { raise e })
      end
      let(:buffer) { [] }
      let(:rows) { Array.new(7) { |i| +"row#{i}\r\n" } }

      def push(row)
        buffer << row # Lich pushes the row into its buffer before the tap sees it
        lich.new_downstream_xml(row)
      end

      before do
        flag = open_flag
        rows_buffer = buffer
        recording.install(lich, buffer: -> { rows_buffer }, gate: -> { flag[0] })
      end

      it 'applies just the rows parsed while closed, each row exactly once' do
        open_flag[0] = true
        push(rows[0])
        push(rows[1])
        open_flag[0] = false
        push(rows[2])
        push(rows[3])
        open_flag[0] = true
        push(rows[4]) # re-open: rows 2 and 3 replayed, row 4 live
        open_flag[0] = false
        open_flag[0] = true
        push(rows[5]) # never closed in between (no row was refused): fed live
        expect(applied).to eq(rows[0..5])
        expect(applied.map(&:object_id).uniq.length).to eq(6)
      end

      it 'replays every row left when the buffer has dropped the last applied one meanwhile (all of them are newer)' do
        open_flag[0] = true
        push(rows[0])
        push(rows[1])
        open_flag[0] = false
        push(rows[2])
        buffer.shift(2) # Lich's buffer is bounded: rows 0 and 1 fall out
        open_flag[0] = true
        push(rows[3])
        expect(applied).to eq(rows[0..3])
      end

      it 'tells two equal rows apart by identity: an equal copy parsed while closed is applied' do
        open_flag[0] = true
        push(rows[0])
        open_flag[0] = false
        copy = rows[0].dup
        push(copy)
        open_flag[0] = true
        push(rows[1])
        expect(applied.map(&:object_id)).to eq([rows[0], copy, rows[1]].map(&:object_id))
      end
    end

    it 'makes a later ungated install of the same class a no-op (the first script after Lich load)' do
      gated([])
      feed.install(lich, buffer: -> { raise 'not read' })
      expect(errors).to eq([])
      lich.new_downstream_xml(room_b)
      expect(capture['roomname']).to be_nil # still gated
    end

    it 'contains a failing gate under its report and feeds nothing' do
      feed.install(lich, buffer: -> { [] }, gate: -> { raise 'gate broke' })
      expect { lich.new_downstream_xml(room_b) }.not_to raise_error
      expect([errors.map(&:message), capture['roomname'], lich.received]).to eq([['gate broke'], nil, [room_b]])
    end
  end

  describe '#install (the start-up replay)' do
    it "replays the server buffer's snapshot, oldest first" do
      feed.install(lich, buffer: -> { [room_a, room_b] })
      expect(capture['roomname']).to eq('Room B')
    end

    it 'lands a row Lich parses while the snapshot is taken after the replay' do
      live = nil
      buffer = lambda do
        live = Thread.new { lich.new_downstream_xml(room_b) } # the parser thread, through the tap
        Thread.pass until live.status == 'sleep' || !live.alive?
        [room_a]
      end
      feed.install(lich, buffer: buffer)
      live.join
      expect([capture['roomname'], capture['uid']]).to eq(['Room B', '2'])
      expect(lich.received).to eq([room_b])
    end

    it "applies once the snapshot's last row when it reaches the tap after the replay" do
      rt = "<roundTime value='110'/>\r\n"
      prompt = %(<prompt time="100">&gt;</prompt>\r\n)
      feed.install(lich, buffer: -> { [rt, prompt] })
      lich.new_downstream_xml(prompt) # pushed before the snapshot, tapped after it
      expect(capture['roundtime']).to eq('10')
    end

    it 'replays a copy of the buffer (Lich keeps pushing into the live one meanwhile)' do
      live_buffer = Object.new
      snapshot = [room_a]
      live_buffer.define_singleton_method(:dup) { snapshot.dup } # LimitedArray#dup: a synchronized copy
      feed.install(lich, buffer: -> { live_buffer })
      expect(capture['roomname']).to eq('Room A')
    end

    it 'installs the tap even with no buffer, and reports a buffer that raises' do
      feed.install(lich, buffer: -> {})
      expect(lich.singleton_class.ancestors).to include(feed.tap)
      other = Class.new { def self.new_downstream_xml(_line) = nil }
      feed.install(other, buffer: -> { raise IOError, 'gone' })
      expect(other.singleton_class.ancestors).to include(feed.tap)
      expect(errors.map(&:message)).to eq(['gone'])
    end

    # Reloading genie_script.rb resets the glue's own flags; the feed (kept
    # in Lich::Genie) must not replay the older buffer over the live state a second time.
    it 'replays only at the first install into a class: a second install never re-seeds over live rows' do
      feed.install(lich, buffer: -> { [room_a] })
      lich.new_downstream_xml(room_b)
      replays = 0
      feed.install(lich, buffer: -> { (replays += 1) && [room_a] })
      expect([capture['roomname'], replays]).to eq(['Room B', 0])
      expect(feed.installed?(lich)).to be(true)
    end

    it 'counts an install whose replay failed as installed (the tap is in), one whose prepend failed as not' do
      feed.install(lich, buffer: -> { raise IOError, 'gone' })
      expect(feed.installed?(lich)).to be(true)
      broken = raising_feed
      broken.install(lich, buffer: -> { [] })
      expect(broken.installed?(lich)).to be(false)
    end

    it 'reports a capture that cannot be built and raises nothing' do
      expect { raising_feed.install(lich, buffer: -> { [] }) }.not_to raise_error
      expect(errors.map(&:message)).to eq(['capture broke'])
    end
  end

  describe '.typed_command (what Remix SendText gets for typed input)' do
    it 'returns the command typed, without the <c> prefix or the trailing newline' do
      expect(described_class.typed_command('<c>look')).to eq('look')
      expect(described_class.typed_command("get my sword\n")).to eq('get my sword')
    end

    # Remix behind Lich sees a typed Lich command as an ordinary command (Game.cs:521-552 R).
    it 'keeps a Lich command, which only Lich intercepts downstream of Remix' do
      ['<c>;go2 1', ',kill sc', '; spaced', ',,', ';'].each do |input|
        expect(described_class.typed_command(input)).to eq(input.delete_prefix('<c>')), input
      end
    end

    it 'ignores blank input' do
      ['', '<c>', '   ', "<c>\n"].each { |input| expect(described_class.typed_command(input)).to be_nil, input.inspect }
    end
  end

  describe '#upstream (the UpstreamHook body)' do
    it 'sets $lastcommand and $lastinput, hands the text to on_input, and returns the very same string' do
      input = +'<c>look'
      typed = []
      expect(feed.upstream(input, on_input: ->(text) { typed << text })).to equal(input)
      expect([capture['lastcommand'], globals.get('lastinput'), typed]).to eq(['look', 'look', ['look']])
    end

    it 'records a typed Lich command too (Remix SendText behind Lich)' do
      feed.upstream('<c>;go2 1')
      expect([capture['lastcommand'], globals.get('lastinput')]).to eq([';go2 1', ';go2 1'])
    end

    it "skips a Lich command the engine hands to do_client itself (a script's send)" do
      Thread.current[described_class::ENGINE_CLIENT_KEY] = true
      typed = []
      feed.upstream(',go2 1', on_input: ->(text) { typed << text })
      expect([globals.get('lastinput'), typed]).to eq([nil, []])
    ensure
      Thread.current[described_class::ENGINE_CLIENT_KEY] = nil
    end

    # The glue hands the work to its trigger worker.
    it 'hands the recording and on_input to +post+ as one job, and reports a fault inside it' do
      jobs = []
      typed = []
      feed.upstream('<c>look', on_input: ->(text) { typed << text }, post: ->(&job) { jobs << job })
      expect([capture['lastcommand'], typed, jobs.length]).to eq([nil, [], 1])
      jobs.shift.call
      expect([capture['lastcommand'], typed]).to eq(['look', ['look']])
      feed.upstream('<c>x', on_input: ->(_text) { raise IOError, 'input broke' }, post: ->(&job) { jobs << job })
      expect { jobs.shift.call }.not_to raise_error
      expect(upstream_errors.map(&:message)).to eq(['input broke'])
      feed.upstream('   ', post: ->(&job) { jobs << job })
      expect(jobs).to eq([])
    end

    it 'contains an error (UpstreamHook.run would remove the hook) under its own report' do
      input = +'look'
      expect(raising_feed.upstream(input)).to equal(input)
      expect([upstream_errors.map(&:message), errors]).to eq([['capture broke'], []])
    end
  end
end

RSpec.describe Lich::Genie::ErrorReport do
  let(:lines) { [] }
  let(:report) { described_class.new('game-state feed', emit: ->(text) { lines << text }, first: 2, every: 5) }

  it 'shows the first errors, then every Nth with its count' do
    12.times { |i| report.call(RuntimeError.new("e#{i + 1}")) }
    expect(lines).to eq(['--- Lich: genie game-state feed error: e1',
                         '--- Lich: genie game-state feed error: e2 (further game-state feed errors: every 5th shown)',
                         '--- Lich: genie game-state feed error: e5 (5 game-state feed errors so far)',
                         '--- Lich: genie game-state feed error: e10 (10 game-state feed errors so far)'])
    expect(report.count).to eq(12)
  end

  it 'never raises, even when the emitter does' do
    broken = described_class.new('x', emit: ->(_text) { raise NameError, 'no respond' })
    expect { broken.call(RuntimeError.new('boom')) }.not_to raise_error
    expect(broken.count).to eq(1)
  end

  it 'names its path, so the feed, the typed-command tap and the script-output feed are told apart' do
    described_class.new('typed-command tap', emit: ->(text) { lines << text }).call(RuntimeError.new('bad'))
    expect(lines).to eq(['--- Lich: genie typed-command tap error: bad'])
  end
end
