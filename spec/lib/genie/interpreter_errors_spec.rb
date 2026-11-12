# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/genie'

# The script error model on the REAL interpreter, headless. Remix references:
#   PrintError Script.cs:4340-4360 R (format + %lastscripterror), AbortOnScriptError
#   Script.cs:1109-1135 R, TickScript's scripterror arm Script.cs:1498-1503 R, PrintTrace
#   Script.cs:1901-1905 R + Trace.cs, the RunScriptRow error arms Script.cs:2451-2556 R,
#   EvalTimer Script.cs:3034-3105 R, EvalDo Script.cs:3477-3531 R, PrintDebug Script.cs:4388-4426 R.
# Expectations marked "(tNN)" are the frozen Remix golden of that flow case.
RSpec.describe Lich::Genie::Interpreter do
  # Runs +source+ on a virtual clock. Script echoes and engine print lines are kept apart:
  # out = [[kind, text], ...] with kind :echo or the print port's :error / :text / :debug.
  def run(source, lines: [], line_dt: 0.0, settings: [], wall: Time.new(2026, 1, 1, 12, 0, 0, '+13:00'), queue: nil,
          include_loader: nil, game_state: nil)
    clock = [0.0]
    input = GenieSpecSupport::TimedInput.new(lines, clock: clock, gap: line_dt)
    out = []
    sends = []
    game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |t| sends << t } }
    state = game_state || Lich::Genie::GameState.new(config: Lich::Genie::GameState::Config.from_settings(settings))
    vars = Lich::Genie::Variables.new(game_state: state)
    vars.global_set('repeatregex', Lich::Genie::ReservedState::DEFAULTS['repeatregex'], persist: false) # Globals.cs:915 R
    interp = Lich::Genie::Engine.build(source, name: 't', file_name: 't.cmd', variables: vars, game: game, input: input,
                                               echo: ->(t) { out << [:echo, t] }, print: ->(t, k) { out << [k, t] },
                                               clock: -> { clock[0] }, wall_clock: -> { wall + clock[0] }, queue: queue,
                                               include_loader: include_loader, ignore_warnings: state.config.ignore_script_warnings)
    interp.run
    { out: out, sends: sends, vars: vars, clock: clock[0], unread: input.items }
  end

  def texts(result, *kinds)
    result[:out].select { |kind, _| kinds.include?(kind) }.map(&:last)
  end

  describe 'PrintError and AbortOnScriptError' do
    it 'names the file and row, sets %lastscripterror, and ends a script with no scripterror label (t10)' do
      r = run("echo one\ngoto nowhere\necho NOT\n")
      expect(r[:out]).to eq([[:echo, 'one'], [:error, '[Script error in t.cmd(2): Unknown label from GOTO: nowhere]'],
                             [:text, '[Script aborted! (Run time: 0.00 seconds): t.cmd]']]) # AbortScript's line (t10)
      expect(r[:vars].local_get('lastscripterror')).to eq('Unknown label from GOTO: nowhere')
    end

    it 'names an include with its row (", inc.cmd(2)")' do
      loader = ->(name) { name == 'inc.cmd' ? "echo in-inc\ngoto missing\n" : nil }
      r = run("include inc.cmd\necho after\n", include_loader: loader)
      expect(texts(r, :error)).to eq(['[Script error in t.cmd, inc.cmd(2): Unknown label from GOTO: missing]'])
    end

    it 'moves to the scripterror label one tick later, the blocks cleared, the call stack kept (t185)' do
      src = <<~GENIE
        gosub sub
        exit
        sub:
        if 1 = 1 then
        {
        goto nowhere
        }
        scripterror:
        echo caught %lastscripterror
        return
      GENIE
      r = run(src)
      expect(r[:out]).to eq([[:error, '[Script error in t.cmd(6): Unknown label from GOTO: nowhere]'],
                             [:text, '[Script moving to scripterror label (t.cmd)]'],
                             [:echo, 'caught Unknown label from GOTO: nowhere']])
      expect(r[:clock]).to be_within(1e-9).of(Lich::Genie::Interpreter::TICK_SECONDS)
    end

    it 'resumes at the scripterror label ignoring the roundtime (the arm comes first in TickScript)' do
      rt = Lich::Genie::GameEvents::RoundTimeEnd.new(5.0)
      src = "action matchre x [ when ^boom\nwaitfor never\nscripterror:\necho caught\n"
      r = run(src, lines: [rt, 'boom', Lich::Genie::GameEvents::Prompt.new(nil)], line_dt: 0.0)
      expect(texts(r, :echo)).to eq(['caught'])
      expect(r[:clock]).to be_within(1e-9).of(Lich::Genie::Interpreter::TICK_SECONDS)
    end

    it 'aborts on a second error before the jump (already in the scripterror state)' do
      src = "action matchre a [;matchre b [;echo body-end when ^boom\nwaitfor never\nscripterror:\necho se\n"
      r = run(src, lines: %w[boom])
      expect(texts(r, :error)).to eq(['[Script error in t.cmd(1): Invalid RegExp in matchre: a []',
                                      '[Script error in t.cmd(1): Invalid RegExp in matchre: b []'])
      expect(texts(r, :echo)).to eq([]) # AbortScript: the body stops, the label never runs
    end

    it 'takes an unknown action goto label as an action goto to row 0 when the script goes on (t190)' do
      src = "echo top\naction goto nowhere when ^boom\nwaitfor never\nscripterror:\necho se\n"
      r = run(src, lines: %w[boom never], line_dt: 0.1)
      expect(r[:out]).to eq([[:echo, 'top'], [:error, '[Script error in t.cmd(2): Unknown label from GOTO: nowhere]'],
                             [:text, '[Script moving to scripterror label (t.cmd)]'], [:echo, 'top'], [:echo, 'se']])
    end

    it 'names no row for an unknown match label and still errors out (t192)' do
      r = run("match nolabel hello\nmatchwait 5\necho after\nexit\nscripterror:\necho se %lastscripterror\n", lines: ['hello'])
      expect(r[:out]).to eq([[:error, '[Script error in t.cmd: Unknown label from MATCH command: nolabel]'],
                             [:text, '[Script moving to scripterror label (t.cmd)]'],
                             [:echo, 'se Unknown label from MATCH command: nolabel']])
    end

    it 'refuses a label passed inside a { } block, counting the if block as one level (t28, t193)' do
      r = run("if (1 = 1) then\n{\ninside:\n  echo in\n}\necho out\n")
      expect(texts(r, :error)).to eq(['[Script error in t.cmd(3): Passing a LABEL from within a script block is not allowed: inside]'])
      expect(texts(run("{\ninside:\necho in\n}\n"), :echo)).to eq(['in']) # one bare block level is allowed
    end

    it 'sets the variable to 0 after an invalid math expression when the script goes on (t191)' do
      r = run("var c 5\nmath c bogus 1\nexit\nscripterror:\necho c=%c\n")
      expect(texts(r, :echo)).to eq(['c=0'])
    end
  end

  describe 'GOSUB depth, RETURN and the trace' do
    it 'stops past maxgosubdepth (50 by default) with the 20-entry trace (t186)' do
      r = run("var n 0\nrec:\nmath n add 1\ngosub rec %n\n")
      expect(texts(r, :error)).to eq(['[Script error in t.cmd(4): Maximum GOSUB depth (50) on: rec]'])
      trace = texts(r, :text)
      expect([trace.first, trace.last]).to eq(['Trace follows:', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
      expect(trace[-2].split("\n")).to eq(["\tgosub rec (4)"] * 20)
      expect(r[:vars].local_get('n')).to eq('50')
    end

    it 'reads maxgosubdepth from settings.cfg (t187)' do
      src = "gosub a\nexit\na:\ngosub b\nreturn\nb:\ngosub c\nreturn\nc:\necho deep\nreturn\n"
      r = run(src, settings: [%w[maxgosubdepth 3]])
      expect(texts(r, :error)).to eq(['[Script error in t.cmd(7): Maximum GOSUB depth (3) on: c]'])
      expect(texts(r, :text)).to eq(['Trace follows:', "\tgosub a (1)\n\tgosub b (4)\n\tgosub c (7)", '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    it 'applies a runtime #config maxgosubdepth at the next gosub' do
      game_state = Lich::Genie::GameState.new
      src = "gosub a\nexit\na:\nput #config maxgosubdepth 2\ngosub b\nreturn\nb:\necho deep\nreturn\n"
      r = run(src, game_state: game_state)
      expect(texts(r, :error)).to eq(['[Script error in t.cmd(5): Maximum GOSUB depth (2) on: b]'])
      expect(game_state.config.max_gosub_depth).to eq(2)
    end

    it 'prints the trace on a failed RETURN, oldest entry first (t188)' do
      r = run("echo one\ngoto two\ntwo:\ngosub three\necho after\nreturn\nthree:\nreturn\n")
      expect(texts(r, :error)).to eq(['[Script error in t.cmd(6): RETURN command failed. There are no more gosub bookmarks to return to!]'])
      expect(texts(r, :text)).to eq(['Trace follows:', "\tgoto two (2)\n\tgosub three (4)\n\treturn (8)", '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    it 'times out a wait-less loop after the configured scripttimeout, with the trace' do
      clock = [0.0]
      out = []
      state = Lich::Genie::GameState.new(config: Lich::Genie::GameState::Config.from_settings([%w[scripttimeout 300]]))
      Lich::Genie::Engine.run("loop:\necho x\ngoto loop\n", name: 't', file_name: 't.cmd',
                                                               variables: Lich::Genie::Variables.new(game_state: state),
                                                               echo: ->(_t) {}, print: ->(t, k) { out << [k, t, clock[0]] },
                                                               clock: -> { clock[0] += 0.1 })
      expect(out.first.first(2)).to match([:text, /\A\[Script timeout in t\.cmd\([23]\): Possible infinite loop\.\]\z/])
      expect(out[1].first(2)).to eq([:text, 'Trace follows:'])
      # at 300 ms of loop, not the 5000 ms default: the clock ticks 0.1 s per read
      expect(out.first.last).to be_between(0.3, 0.8)
    end
  end

  describe 'EvalTimer and @timer@' do
    it 'starts, stops into %t, resumes from the stopped time, clears, and ignores a bare timer (t27, t189)' do
      src = <<~GENIE
        echo t0=%t
        timer
        echo bare=%t
        timer start
        pause 1.5
        echo t=%t
        timer stop
        echo stopped=%t
        pause 1
        timer start
        pause 0.5
        echo resumed=%t
        timer start
        echo twice=%t
        timer clear
        echo cleared=%t
        timer start
        pause 2
        echo two=@timer@
      GENIE
      expect(texts(run(src), :echo)).to eq(['t0=%t', 'bare=%t', 't=1.5', 'stopped=1.5', 'resumed=2', 'twice=2', 'cleared=0', 'two=2'])
    end

    it 'stores "0" on a stop with no running timer, and sets %t without a variable change' do
      src = "action echo CHANGED when eval %t\ntimer stop\necho t=%t\n"
      expect(texts(run(src), :echo)).to eq(['t=0'])
    end

    # The wall clock's naive seconds in ITS OWN offset: the same wall time in two zones reads
    # the same (63_902_865_600 s from 0001-01-01 to 2026-01-01 12:00), a different instant.
    it 'reads @timer@ with no timer as the seconds since 0001-01-01 on the local wall clock' do
      %w[+13:00 -05:00 +05:30].each do |zone|
        wall = Time.new(2026, 1, 1, 12, 0, 0, zone)
        expect(texts(run("echo @timer@\n", wall: wall), :echo)).to eq(['63902865600'])
      end
    end

    # v0.26.2: `setstart` subtracts naive wall-clock fields (DateTime.Now - an Unspecified
    # DateTime ignores zones): 2:30 AM on a US spring-forward day is one naive hour before 3:30
    # EDT, in any process TZ (Time.local made it 3:30 under TZ=America/New_York, reading 0).
    it 'measures a setstart date inside a DST gap by naive wall-clock fields' do
      r = run("timer setstart 3/8/2026 2:30 AM\ntimer stop\necho t=%t\n", wall: Time.new(2026, 3, 8, 3, 30, 0, '-04:00'))
      expect(texts(r, :echo)).to eq(['t=3600'])
    end

    it 'starts the timer at a setstart date, and errors out on a text DateTime.Parse refuses (t189)' do
      wall = Time.new(2026, 1, 1, 12, 0, 0, '+13:00')
      r = run("timer setstart 1/1/2026 11:59:30 AM\necho t=%t @timer@\ntimer setstart notadate\necho no\n", wall: wall)
      expect(texts(r, :echo)).to eq(['t=30 30']) # %t holds "@timer@", which the @-pass then reads
      expect(texts(r, :error)).to eq(['[Script error in t.cmd(3): Invalid datetime format in TIMER SETSTART command: notadate]'])
    end
  end

  describe 'EvalTimer setstart 1/1/0001' do
    # DateTime.Parse("1/1/0001") == m_oBlankTimer (Script.cs:678 R), so EvalTimer then takes the
    # timer as never started: `stop` stores "0", `start` starts it afresh (genieflow probe s53).
    it 'treats a start at 0001-01-01 00:00:00 as the blank timer, a second later as a real start' do
      wall = Time.new(2026, 1, 1, 12, 0, 0, '+13:00')
      blank = 63_902_865_600 # naive seconds from 0001-01-01 to the wall's 2026-01-01 12:00
      src = "timer setstart 1/1/0001\necho A %t\ntimer stop\necho C %t\ntimer start\npause 0.25\necho D %t\n" \
            "timer clear\ntimer setstart 1/1/0001 00:00:01\ntimer stop\necho E %t\n"
      expect(texts(run(src, wall: wall), :echo)).to eq(["A #{blank}", 'C 0', 'D 0.25', "E #{blank - 1 + 0.25}"])
    end
  end

  describe 'small verbs' do
    it 'replaces every " = " of a % row, unvars the first word only, and ignores math with no variable (t207)' do
      r = run("%x = a = b\necho x=%x\nvar y 1\nvar z 2\nunvar y z\necho y=%y z=%z\nmath\necho done\n")
      expect(texts(r, :echo)).to eq(['x=a b', 'y=%y z=2', 'done'])
      expect(texts(r, :error)).to eq([])
    end

    describe 'do' do
      let(:queue) { Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) }) }

      def released(queue)
        out = []
        queue.drain(-> { Lich::Genie::CommandQueue::FREE }) { |action| out << action }
        out
      end

      it 'queues its command held while webbed or stunned and adds the $repeatregex match entry' do
        r = run("do 2 look\necho after\n", queue: queue)
        expect(texts(r, :echo)).to eq(['after'])
        item = queue.instance_variable_get(:@items).first
        expect(item.to_h.slice(:delay, :action, :wait_rt, :wait_webbed, :wait_stunned))
          .to eq(delay: 2, action: 'look', wait_rt: true, wait_webbed: true, wait_stunned: true)
      end

      it 'sends the command again when the matchwait sees the repeat pattern, keeping the earlier matches (t208)' do
        src = "match got You see\ndo look\nmatchwait 10\necho timeout\nexit\ngot:\necho got %lastlabel\n"
        r = run(src, lines: ['...wait 1 seconds.', 'You see a room.'], line_dt: 0.5, queue: queue)
        expect(released(queue)).to eq(%w[look look])
        expect(texts(r, :echo)).to eq(['got got'])
      end

      it 'takes the first {...} as the command and adds the second to the repeat pattern (t209)' do
        src = "do {look} {^Try again}\nmatchwait 1\necho done\n"
        r = run(src, lines: ['Try again', 'fine'], line_dt: 0.1, queue: queue)
        expect(released(queue)).to eq(%w[look look])
        expect(texts(r, :echo)).to eq(['done'])
      end

      it 'empties the match list on do clear and errors out on an invalid regex (t209)' do
        r = run("match x y\ndo clear\nmatchwait 1\necho t\ndo [bad\necho no\n", queue: queue)
        expect(texts(r, :echo)).to eq(['t'])
        expect(texts(r, :error)).to eq(['[Script error in t.cmd(5): Invalid RegExp in Do: [bad]'])
      end
    end
  end

  describe 'debug N (PrintDebug)' do
    it 'prints levels up to N to the print port with the file and row, and nothing at 0 (t210)' do
      src = "debug 3\nvar x 1\nif %x = 1 then echo yes\ngoto a\na:\npause 0.1\n"
      expect(texts(run(src), :debug)).to eq(['t.cmd: if evaluate: 1 = 1', 't.cmd: if returned: True', 't.cmd(4): goto a',
                                             't.cmd(6): pause 0.1'])
      expect(texts(run(src.sub('debug 3', 'debug 4')), :debug).first).to eq('t.cmd(2): setvariable x 1')
      expect(texts(run(src.sub('debug 3', 'debug 0')), :debug)).to eq([])
    end

    it 'prints only the exact level from 10 up (10 = every parsed row)' do
      expect(texts(run("debug 10\necho hi %x\n"), :debug)).to eq(['t.cmd(2): [echo hi %x]'])
      expect(texts(run("debug 15\necho hi\n"), :debug)).to eq(['t.cmd: echo hi (echo)'])
    end

    it "warns about an unassigned variable in an evaluation unless warnings are ignored (t210)" do
      warning = "[Script error in t.cmd(2): Eval (%nope = 1) contains variable character '%'. Did you use an unassigned variable?]"
      expect(texts(run("debug 1\nif %nope = 1 then echo no\n"), :error)).to eq([warning])
      expect(texts(run("debug 1\nif %nope = 1 then echo no\n", settings: [%w[ignorescriptwarnings on]]), :error)).to eq([])
      expect(texts(run("if %nope = 1 then echo no\n"), :error)).to eq([])
    end
  end
end
