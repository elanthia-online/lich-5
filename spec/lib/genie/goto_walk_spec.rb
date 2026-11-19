# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Lich::Genie::GotoWalk: Remix's AutoMapper goto arm (AutoMapper.cs:1140-1205, 1595-1609 R) with
# the walk done by the host on its own thread instead of automapper.cmd. The result
# lines are automapper.cmd's (DEAD.DONE / MOVE.FAILED: `#parse YOU HAVE ARRIVED!` +
# `#parse AUTOMAPPER: YOU HAVE ARRIVED!`, `#parse MOVE FAILED` + `#parse AUTOMAPPER: MOVEMENT FAILED!`).
RSpec.describe Lich::Genie::GotoWalk do
  let(:list) { Lich::Genie::ScriptList.new }
  let(:log) { [] }
  let(:spawned) { [] }
  let(:stopped) { [] }
  let(:rooms) { { '12' => 512, '7' => 7 } }
  let(:here) { [100] }
  let(:walks) { [] }
  let(:results) { [true] }
  let(:changes) { [0] }

  def host(abort_dupe: true)
    described_class::Host.new(
      resolve: ->(arg) { rooms[arg] }, here: -> { here[0] },
      walk: lambda { |target|
        walks << target
        results.shift
      },
      spawn: lambda { |&block|
        spawned << block
        "thread#{spawned.length}"
      },
      stop: ->(thread) { stopped << thread },
      echo: ->(text) { log << [:echo, text] }, set_var: ->(name, value) { log << [:var, name, value] },
      parse: ->(text) { log << [:parse, text] },
      list: list, abort_dupe: abort_dupe, changed: -> { changes[0] += 1 }
    )
  end

  def go(arg, launcher: nil, abort_dupe: true)
    described_class.go(arg, host: host(abort_dupe: abort_dupe), launcher: launcher)
  end

  # A listed script-list handle (the walker / a launcher).
  def walker
    Struct.new(:genie_file_name).new('walker.cmd').tap do |script|
      list.launched(script)
      list.run_ended(script)
    end
  end

  describe 'the goto arm (AutoMapper.cs:1144-1205 R)' do
    it 'asks for a room id when there is no argument (no #parse, $destination 0)' do
      expect(go('')).to be_nil
      expect(log).to eq([[:echo, '[AutoMapper] Goto - please specify a room id to travel to.'], [:var, 'destination', '0']])
    end

    it 'treats a non-number, a negative number and anything over 5 characters as a note name: not found' do
      %w[bank -12 123456 12x].each do |arg|
        log.clear
        expect(go(arg)).to be_nil
        expect(log).to eq([[:echo, %([AutoMapper] Destination ID "#{arg}" not found.)], [:var, 'destination', '0'],
                           [:parse, 'DESTINATION NOT FOUND']]), arg
      end
      expect(walks).to eq([])
    end

    it 'reports an id it cannot place with the "current location is unknown" wording' do
      expect(go('13')).to be_nil
      expect(log).to eq([[:echo, '[AutoMapper] Destination ID #13 not found - your current location is unknown.'],
                         [:var, 'destination', '0'], [:parse, 'DESTINATION NOT FOUND']])
    end

    it 'reads the id as int.TryParse does (" 12" -> 12, "012" -> 12, "+12" -> 12)' do
      expect([described_class.node_id(' 12'), described_class.node_id('012'), described_class.node_id('+12'),
              described_class.node_id('0'), described_class.node_id('1.5')]).to eq([12, 12, 12, 0, 0])
    end

    # m_Nodes.Find(iNodeID) looks up the PARSED id (AutoMapper.cs:1178 R),
    # while the echo is "#goto " + sArg, sArg as typed after the keyword's first space -- inner
    # spaces kept (AutoMapper.cs:955-965, 1182 R).
    it 'finds the room by the parsed id and echoes the argument as typed ("012", "+12", " 12")' do
      ['012', '+12', ' 12', '12 '].each do |arg|
        log.clear
        expect(go(arg)).to be_a(described_class::Handle), arg.inspect
        expect(log).to eq([[:echo, "#goto #{arg}"], [:var, 'destination', '12'], [:parse, 'DESTINATION FOUND']]), arg.inspect
      end
      expect(rooms.keys).to eq(%w[12 7]) # resolve never saw the raw text
    end

    it 'echoes "#goto <arg>", sets $destination and parses DESTINATION FOUND before the walk starts' do
      handle = go('12')
      expect(log).to eq([[:echo, '#goto 12'], [:var, 'destination', '12'], [:parse, 'DESTINATION FOUND']])
      expect([handle.genie_file_name, handle.name, spawned.length, walks]).to eq(['automapper.cmd', 'automapper', 1, []])
    end
  end

  describe 'WalkToNode (AutoMapper.cs:1595-1609 R) and the walk' do
    it 'starts nothing when the current room is unknown or is the destination (no result line ever)' do
      here[0] = nil
      expect(go('12')).to be_nil
      here[0] = 512
      expect(go('12')).to be_nil
      expect([spawned, list.listed]).to eq([[], []])
      expect(log.count { |entry| entry == [:parse, 'DESTINATION FOUND'] }).to eq(2)
    end

    it 'lists the walk at once with no launcher, walks, parses the ARRIVED pair, then leaves the list' do
      handle = go('12')
      expect(list.listed).to eq([handle])
      expect(list.value).to eq('automapper')
      log.clear
      spawned.shift.call
      expect(walks).to eq([512])
      expect(log).to eq([[:parse, 'YOU HAVE ARRIVED!'], [:parse, 'AUTOMAPPER: YOU HAVE ARRIVED!']])
      expect([list.listed, list.value, changes[0]]).to eq([[], 'none', 2])
    end

    it 'parses the MOVE FAILED pair when the walk does not arrive' do
      results[0] = false
      go('12')
      log.clear
      spawned.shift.call
      expect(log).to eq([[:parse, 'MOVE FAILED'], [:parse, 'AUTOMAPPER: MOVEMENT FAILED!']])
    end

    it 'is listed at the end of the run that launched it (Remix: the `.automapper` launch in the row, AddScripts at the tick end)' do
      script = walker
      handle = go('12', launcher: script)
      expect(list.listed?(handle)).to be(false)
      list.run_ended(script)
      expect(list.listed).to eq([script, handle])
      expect(list.value).to eq('walker|automapper')
    end

    it 'aborts the listed walk for a second #goto (abortdupescript), not with abortdupescript off' do
      first = go('12')
      second = go('7')
      expect([first.aborted?, stopped]).to eq([true, ['thread1']])
      go('12', abort_dupe: false)
      expect(second.aborted?).to be(false)
    end

    it 'parses no result line after an abort, and still leaves the list' do
      handle = go('12')
      handle.genie_abort
      log.clear
      spawned.shift.call
      expect([log, list.listed]).to eq([[], []])
    end

    # An abort between the listing and the runner's start is not lost.
    it 'stops a runner aborted before it was attached, and its body walks nothing' do
      aborting = described_class::Host.new(**host.to_h, spawn: lambda { |&block|
        spawned << block
        list.duplicates('automapper.cmd').each(&:genie_abort) # `#script abort automapper` meanwhile
        'thread1'
      })
      handle = described_class.go('12', host: aborting)
      expect([handle.aborted?, stopped]).to eq([true, ['thread1']])
      log.clear
      spawned.shift.call
      expect([walks, log, list.listed]).to eq([[], [], []])
    end

    it 'leaves the list at once when the runner could not start' do
      failing = described_class::Host.new(**host.to_h, spawn: ->(&_block) {})
      described_class.go('12', host: failing)
      expect([list.listed, list.value, changes[0]]).to eq([[], 'none', 2])
    end

    # A #trigger on the first result line that runs `#goto` (on the walk's
    # own runner) aborts this walk: the second line is not parsed, the new walk is listed.
    it 'parses no further result line once a #trigger on the first one started another walk' do
      chained = []
      chaining = described_class::Host.new(**host.to_h, parse: lambda { |text|
        log << [:parse, text]
        chained << described_class.go('7', host: host) if text == 'YOU HAVE ARRIVED!'
      })
      first = described_class.go('12', host: chaining)
      log.clear
      spawned.shift.call
      expect(log).to eq([[:parse, 'YOU HAVE ARRIVED!'], [:echo, '#goto 7'], [:var, 'destination', '7'], [:parse, 'DESTINATION FOUND']])
      expect([first.aborted?, stopped, list.listed]).to eq([true, ['thread1'], chained])
    end

    it 'leaves the list even when the walk raises' do
      handle = go('12')
      rooms.clear
      results[0] = nil
      boom = described_class::Host.new(**host.to_h, walk: ->(_target) { raise 'walk broke' })
      expect { described_class.walk(512, handle, boom) }.to raise_error('walk broke')
      expect(list.listed).to eq([])
    end
  end

  # A travel script waits for the automapper to leave $scriptlist after each `#goto`. In Remix
  # the `#goto` row launches automapper.cmd, which is listed only at the tick end, so the
  # waiteval right after it reads the old $scriptlist and goes on at once; a script that waits
  # (here: for the walk's ARRIVED line) sees it listed, and the waiteval then waits for its end.
  it 'lets a script waiteval on $scriptlist for the walk, on the real interpreter and script list' do
    script = walker
    script_list = list
    queue = []
    clock = [0.0]
    input = Object.new
    input.define_singleton_method(:next_line) do |timeout: nil|
      script_list.run_ended(script) # each read ends the script's run (GenieScript#genie_run_ended)
      next queue.shift unless queue.empty?

      clock[0] += timeout if timeout
      nil
    end
    reserved = Object.new
    reserved.define_singleton_method(:[]) { |name| name == 'scriptlist' ? script_list.value : nil }
    reserved.define_singleton_method(:key?) { |name| name == 'scriptlist' }
    walk_host = described_class::Host.new(**host.to_h,
                                           parse: ->(text) { queue << text },
                                           changed: -> { queue << Lich::Genie::VariableDispatch::Change.new('scriptlist', 0) })
    echoes = []
    src = <<~'GENIE'
      put #goto 12
      echo early $scriptlist
      waitfor DESTINATION FOUND
      echo walking $scriptlist
      waiteval !matchre("$scriptlist","automapper")
      echo done $scriptlist
    GENIE
    interp = Lich::Genie::Engine.build(src, name: 'walker', input: input, echo: ->(t) { echoes << t },
                                            game_state: reserved, clock: -> { clock[0] },
                                            mover: ->(room) { described_class.go(room, host: walk_host, launcher: script) })
    runner = Thread.new { interp.run }
    runner.report_on_exception = false
    Timeout.timeout(5) { Thread.pass until spawned.any? && echoes.length >= 2 }
    spawned.shift.call # the walk ends: ARRIVED parsed, the tick end's "scriptlist" change
    runner.join(5)
    expect(echoes).to eq(['early walker', 'walking walker|automapper', 'done walker'])
  end
end
