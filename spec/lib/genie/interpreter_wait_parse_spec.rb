# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# #parse and the wait primitives on the REAL interpreter, headless.
#   #parse (FormMain.cs:4659-4667 -> ParseTriggers 4425-4512 R; Script.TriggerParse 1179-1316 R)
#   /re/ and /re/i delimiters (Script.cs:369-396, 517-535, 3395-3432 R)
#   waitforre $0..$n (Script.cs:1210-1217 R)
#   waitfor/match trimming + case (Script.cs:1198-1220, 3351-3366 R)
#   .NET pattern validity (NetRegex)
#   matchwait timeout checked on every pass (Script.cs:1598-1650 R)
#   the nested #parse cap (a decided divergence: Remix recurses until the client crashes)
RSpec.describe Lich::Genie::Interpreter do
  # Runs +source+ with a virtual clock. The queued lines arrive +line_dt+ apart (0 = one DR
  # packet, back to back); a timed read with no line arriving within its timeout advances the
  # clock by the timeout and returns nil (Lich's LimitedArray#wait_shift), and a wait with no
  # timeout and no more input raises. Returns echoes, game sends, the unread lines and the clock.
  def run(source, lines: [], line_dt: 0.0, broadcast: nil, endless: nil)
    clock = [0.0]
    queue = lines.dup
    idle = [0]
    arrival = [line_dt]
    input = Object.new
    input.define_singleton_method(:next_line) do |timeout: nil|
      more = endless || !queue.empty?
      if more && (timeout.nil? || arrival[0] <= clock[0] + timeout)
        clock[0] = [clock[0], arrival[0]].max
        arrival[0] = clock[0] + line_dt
        next endless ? endless.call : queue.shift
      end

      idle[0] += 1
      raise 'input exhausted (script waited with no more input)' if idle[0] > 1000 || timeout.nil?

      clock[0] += timeout
      nil
    end
    echoes = []
    sends = []
    game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |t| sends << t } }
    Lich::Genie::Engine.run(source, name: 't', game: game, input: input, echo: ->(t) { echoes << t },
                                    clock: -> { clock[0] }, broadcast: broadcast)
    { echoes: echoes, sends: sends, unread: queue, clock: clock[0] }
  end

  describe 'waitforre' do
    it 'strips /re/i but stays case-sensitive, matches the trimmed line, and sets $0..$n' do
      r = run("waitforre /^you (\\w+)/i\necho [$0] [$1] [$2]\n", lines: ['You hit it', '   you hit it  '])
      expect(r[:echoes]).to eq(['[you hit] [hit] []'])
    end

    it 'strips a trailing /i even without a leading slash (still case-sensitive)' do
      r = run("waitforre TROLL/i\necho [$0]\n", lines: ['the troll', 'THE TROLL'])
      expect(r[:echoes]).to eq(['[TROLL]'])
    end

    it 'aborts with Remix\'s message on a blank argument (EvalWaitString returns false)' do
      r = run("waitforre\necho NOT REACHED\n")
      expect(r[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in waitforre: ]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    it 'aborts on a pattern .NET rejects even though Onigmo accepts it' do
      r = run("waitforre a++\necho NOT REACHED\n", lines: ['aa'])
      expect(r[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in waitforre: a++]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    it 'keeps a waitforre pending across an action goto: a later line still sets $1 (flow t79)' do
      src = <<~GENIE
        action goto x when ^go$
        waitforre ^You (\\w+)
        echo not-here
        exit
        x:
        match y zzz
        matchwait 1
        echo after [$1]
        exit
        y:
        echo y
      GENIE
      r = run(src, lines: ['go', 'You foo'])
      expect(r[:echoes]).to eq(['after [foo]'])
    end
  end

  describe 'waitfor' do
    it 'is a case-sensitive ordinal Contains that keeps the argument\'s leading space' do
      # 20 ms apart: each line its own packet, so the resume comes before the next one
      r = run("waitfor  Stand\necho got\nwaitfor done\n", lines: ['you stand up', 'xStand', 'done', 'a Stand', 'done'], line_dt: 0.02)
      expect(r[:echoes]).to eq(['got'])
      expect(r[:unread]).to eq([])
    end

    it 'is a no-op with a blank argument (the script runs on)' do
      r = run("waitfor\necho ran-on\n")
      expect(r[:echoes]).to eq(['ran-on'])
    end
  end

  describe 'match / matchre' do
    it 'trims the match pattern (`match got  bar` waits for "bar")' do
      r = run("match got  bar\nmatchwait 1\necho timeout\nexit\ngot:\necho got-bar\n", lines: ['foobar'])
      expect(r[:echoes]).to eq(['got-bar'])
    end

    it 'clears only on the exact argument "clear"; ` clear` adds a match with label clear and an empty pattern' do
      cleared = run("match a x\nmatch clear\nmatchwait 1\necho timeout\nexit\na:\necho a\n", lines: ['x'])
      expect(cleared[:echoes]).to eq(['timeout'])
      label = run("match  clear\nmatchwait 1\necho timeout\nexit\nclear:\necho clear-label\n", lines: ['anything'])
      expect(label[:echoes]).to eq(['clear-label'])
    end

    it 'honours a trailing /i without a leading slash and sets $0..$n from the trimmed line' do
      r = run("matchre one ORC (\\w+)$/i\nmatchwait 1\necho none\nexit\none:\necho [$0] [$1]\n", lines: ['  an orc dies  '])
      expect(r[:echoes]).to eq(['[orc dies] [dies]'])
    end

    it 'validates the WHOLE argument, label included (EvalMatch Script.cs:3360 R)' do
      r = run("matchre a( x\nmatchwait 1\necho NOT REACHED\n", lines: ['x'])
      expect(r[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in matchre: a( x]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    it 'stops with one error line when only the bare pattern is invalid' do
      r = run("matchre ( x)\nmatchwait 1\necho NOT REACHED\n", lines: ['x'])
      expect(r[:echoes].length).to eq(1)
      expect(r[:echoes].first).to start_with("[Invalid pattern 'x)'")
    end

    it 'aborts on a matchre pattern .NET rejects' do
      r = run("matchre hit \\Qx\nmatchwait 1\necho NOT REACHED\n", lines: ['Qx'])
      expect(r[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in matchre: hit \\Qx]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    # TriggerParse matches matchre/waitforre on text.Trim() (Script.cs:1210, 1244 R): .NET Trim
    # removes NBSP but keeps NUL, the opposite of Ruby's strip on both.
    it 'matches matchre on the .NET-trimmed line: NUL kept, NBSP trimmed' do
      nbsp = [0xA0].pack('U')
      r = run("matchre m ^a$\nmatchwait 1\necho timeout\nexit\nm:\necho m\n", lines: ["a\0", "#{nbsp}a#{nbsp}"])
      expect(r[:echoes]).to eq(['m'])
      expect(r[:unread]).to eq([]) # the NUL line did not match; the NBSP one did
    end

    it 'matches waitforre on the .NET-trimmed line too' do
      nbsp = [0xA0].pack('U')
      r = run("waitforre ^a$\necho [$0]\n", lines: ["\0a", "#{nbsp}a", 'tail'], line_dt: 0.02)
      expect(r[:echoes]).to eq(['[a]'])
      expect(r[:unread]).to eq(['tail'])
    end

    it 'accepts the corpus .NET-only class [\\w-\'] (ScrollSorter.cmd:46)' do
      r = run("matchre got ([\\w-']+)$\nmatchwait 1\necho none\nexit\ngot:\necho [$1]\n", lines: ["an o'brien-scroll"])
      expect(r[:echoes]).to eq(["[o'brien-scroll]"])
    end
  end

  describe 'matchwait timeout' do
    it 'times out while non-matching lines keep arriving' do
      calls = 0
      endless = lambda do
        calls += 1
        raise 'never timed out' if calls > 50

        'noise'
      end
      r = run("match x never\nmatchwait 1\necho timeout\nexit\nx:\necho matched\n", line_dt: 0.3, endless: endless)
      expect(r[:echoes]).to eq(['timeout'])
      expect(calls).to eq(3) # 0.3/0.6/0.9 s; the read that would take the 1.2 s line ends at the 1 s deadline
    end

    it 'takes a match over the timeout on the same pass (match first, Script.cs:1598-1650 R)' do
      # the line at 0.995 s, its packet over (CHUNK_IDLE_SECONDS) past the 1 s deadline: both hold
      r = run("match x hit\nmatchwait 1\necho timeout\nexit\nx:\necho matched\n", lines: ['hit'], line_dt: 0.995)
      expect(r[:echoes]).to eq(['matched'])
    end
  end

  describe 'lines offered to a script (TriggerParse)' do
    it 'ignores a blank line entirely (no action fires on it)' do
      r = run("action echo X when .*\nwaitfor done\n", lines: ['   ', 'done'])
      expect(r[:echoes]).to eq(['X'])
    end

    # TriggerParse's blank check is text.Trim().Length == 0 (Script.cs:1189-1192 R): .NET Trim
    # removes NBSP but not NUL -- the opposite of Ruby's strip on both.
    it 'treats an NBSP-only line as blank but a NUL-only line as text (.NET Trim)' do
      nbsp = [0xA0].pack('U')
      src = "action echo nbsp when \\u00A0\naction echo nul when \\x00\nwaitfor done\n"
      r = run(src, lines: ["#{nbsp}#{nbsp}", "\0", 'done'])
      expect(r[:echoes]).to eq(['nul'])
    end

    it 'never fires an eval action on a line (it is a variable-change trigger)' do
      r = run("action echo E when eval 1 = 1\naction echo R when ^eval\nwaitfor done\n", lines: ['eval 1 = 1', 'done'])
      expect(r[:echoes]).to eq(['R'])
    end

    it 'fires a /re/i action case-insensitively' do
      r = run("action echo three $1 when /^an? (\\w+) dies/i\nwaitfor done\n", lines: ['An orc dies', 'done'])
      expect(r[:echoes]).to eq(['three orc'])
    end

    it 'removes an action by its normalized key (ClassActionList.Remove)' do
      r = run("action echo A when /^the (\\w+) falls/\naction remove ^the (\\w+) falls/i\nwaitfor done\n",
              lines: ['the orc falls', 'done'])
      expect(r[:echoes]).to eq([])
    end

    it 'aborts on an action pattern .NET rejects (Script.cs:3209-3213 R)' do
      r = run("action echo x when a++\necho NOT REACHED\n")
      expect(r[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in action: echo x when a++]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    # PrintError("Invalid RegExp in action: " + sText) shows EvalAction's sText as Remix holds
    # it (Script.cs:3122-3211 R): a (class) prefix raw, keyword `add`/`instant` removed only
    # without a class. genieflow probes, error text after the script-error prefix.
    it 'shows the raw action text in the invalid-action message' do
      expect(run("action (Foo)  echo x WHEN [\n")[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in action: (Foo)  echo x WHEN []', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
      expect(run("action  add echo x  when [\n")[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in action: echo x  when []', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
      expect(run("action (Foo) add echo x when [\n")[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in action: (Foo) add echo x when []', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end
  end

  describe '#parse issued by the script' do
    # The production host port shape: +before+ (a stand-in for the global #triggers and
    # the other scripts) runs, then the real ParseDispatch.broadcast over a script list
    # holding this interpreter -- the dispatch owner during the call -- which it hands the
    # line back to inline (Interpreter#deliver_parse), or skips while +paused+ says so.
    def host(before = ->(_t) {}, paused: -> { false })
      no_triggers = Object.new.tap { |t| t.define_singleton_method(:apply) { |_text| nil } }
      lambda do |t|
        before.call(t)
        me = Lich::Genie::ParseDispatch::Recipient.new(interpreter: Lich::Genie::ParseDispatch.owner, buffer: [],
                                                       paused: paused.call)
        Lich::Genie::ParseDispatch.broadcast(t, triggers: no_triggers, runner: nil, recipients: [me],
                                                on_error: ->(e) { raise e })
      end
    end

    it 'fires its own actions once it has waited, but not during its launch run (AddScripts)' do
      sent = []
      src = "action echo act $1 when ^PING (\\w+)\nput #parse PING early\npause 0.1\nput #parse PING late\necho done\n"
      r = run(src, broadcast: host(->(t) { sent << t }))
      expect(r[:echoes]).to eq(['act late', 'done'])
      expect(sent).to eq(['PING early', 'PING late']) # the other scripts get both
    end

    it 'is not offered to its own actions while it is paused (TriggerParse returns, Script.cs:1181 R)' do
      paused = false
      src = "action echo act $1 when ^PING (\\w+)\npause 0.1\nput #parse PING one\nput #parse PING two\necho done\n"
      r = run(src, broadcast: host(->(t) { paused = t.end_with?('two') }, paused: -> { paused }))
      expect(r[:echoes]).to eq(['act one', 'done'])
    end

    it 'is offered to itself only when there is no host port' do
      r = run("action echo act when ^PING\npause 0.1\nput #parse PING\necho done\n")
      expect(r[:echoes]).to eq(%w[act done])
    end

    it 'never buffers into its own input: a later matchwait does not see it' do
      r = run("pause 0.1\nput #parse GOTIT\nmatch bad GOTIT\nmatchwait 1\necho timeout\nexit\nbad:\necho buffered\n")
      expect(r[:echoes]).to eq(['timeout'])
    end

    it 'delivers to the #triggers and other scripts before its own actions (ParseTriggers order)' do
      log = []
      now = 0.0
      idle = Object.new.tap { |i| i.define_singleton_method(:next_line) { |timeout: nil| timeout && nil } }
      src = "action echo self when ^PING\npause 0.1\nput #parse PING\n"
      Lich::Genie::Engine.run(src, name: 't', echo: ->(t) { log << "echo:#{t}" }, input: idle,
                                   clock: -> { now += 0.05 }, broadcast: host(->(t) { log << "broadcast:#{t}" }))
      expect(log).to eq(['broadcast:PING', 'echo:self'])
    end

    it 'does not count time spent in the broadcast (a #trigger send waiting out RT) as a runaway loop' do
      now = 0.0
      idle = Object.new.tap { |i| i.define_singleton_method(:next_line) { |timeout: nil| timeout && nil } }
      echoes = []
      src = "put #parse PING\necho after-broadcast\n"
      Lich::Genie::Engine.run(src, name: 't', echo: ->(t) { echoes << t }, input: idle, clock: -> { now },
                                   broadcast: ->(_t) { now += 30.0 })
      expect(echoes).to eq(['after-broadcast'])
    end

    it 'takes an action goto fired by its own #parse after the row, resuming one tick later' do
      src = "action goto jumped when ^JUMP\npause 0.1\nput #parse JUMP\necho not-reached\nexit\njumped:\necho jumped\n"
      r = run(src)
      expect(r[:echoes]).to eq(['jumped'])
      expect(r[:clock]).to be_within(1e-9).of(0.1 + Lich::Genie::Interpreter::ACTION_RESUME_SECONDS)
    end

    it 'resolves the pending waitfor from inside an action body (nested, inline)' do
      r = run("action put #parse INNER when ^OUTER\nwaitfor INNER\necho got-inner\n", lines: ['OUTER'])
      expect(r[:echoes]).to eq(['got-inner'])
      expect(r[:sends]).to be_empty
    end

    it 'resolves a matchwait from inside an action body, $1 from the parsed text (MC_Pound pattern)' do
      src = "action put #parse TOOL $1 when ^use (\\w+)\nmatchre got ^TOOL (\\w+)\nmatchwait\ngot:\necho tool=$1\n"
      r = run(src, lines: ['use tongs'])
      expect(r[:echoes]).to eq(['tool=tongs'])
    end

    it 'stops a self-re-parsing action at the nesting cap with one error line and sends nothing' do
      count = 0
      src = "pause 0.1\naction put #parse LOOP when ^LOOP\nput #parse LOOP\necho NOT REACHED\nput NOT SENT\n"
      r = run(src, broadcast: host(->(_t) { count += 1 }))
      limit = Lich::Genie::DispatchDepth::LIMIT
      expect(count).to eq(limit)
      expect(r[:echoes]).to eq(["[Script error: maximum nested dispatch depth (#{limit}) exceeded on: #parse LOOP]"])
      expect(r[:sends]).to be_empty
      expect(Lich::Genie::DispatchDepth.current).to eq(0)
    end
    # A #parse queued from ANOTHER script carries its nesting depth (ParseDispatch::Line), so a
    # cross-script ping-pong is capped like the synchronous Remix recursion it models.
    it 'continues the nesting depth of a #parse line queued by another script' do
      limit = Lich::Genie::DispatchDepth::LIMIT
      line = ->(depth) { Lich::Genie::ParseDispatch::Line.new('PONG', depth) }
      count = 0
      src = "action put #parse PING when ^PONG\npause 5\necho NOT REACHED\n"
      r = run(src, lines: [line.call(limit - 1), line.call(limit), 'PONG'], broadcast: ->(_t) { count += 1 })
      expect(count).to eq(1) # depth LIMIT-1 -> its #parse runs at LIMIT; depth LIMIT -> the cap
      expect(r[:echoes]).to eq(["[Script error: maximum nested dispatch depth (#{limit}) exceeded on: #parse PING]"])
      expect(r[:unread]).to eq(['PONG'])
      expect(Lich::Genie::DispatchDepth.current).to eq(0)
    end

    it 'starts a fresh chain for a plain game line, whatever depth the previous line carried' do
      count = 0
      src = "action put #parse PING when ^PONG\npause 5\necho done\n"
      r = run(src, lines: [Lich::Genie::ParseDispatch::Line.new('PONG', 3), 'PONG', 'PONG'], broadcast: ->(_t) { count += 1 })
      expect(count).to eq(3)
      expect(r[:echoes]).to eq(['done'])
    end

    # A #trigger fired by this script's own #parse that itself #parses (TriggerRunner ->
    # ParseDispatch owner) reaches this script inline, before the row after the #parse, and
    # never lands in its input (FormMain.cs:4488-4489 R).
    def run_with_trigger_chain(source)
      vars = Lich::Genie::Variables.new
      globals = Object.new.tap { |g| g.define_singleton_method(:key?) { |n| vars.global_key?(n) } }
      runner = Lich::Genie::TriggerRunner.new(vars: vars, eval: Lich::Genie::Eval.new(globals: globals),
                                              game: nil, launch: ->(*) {}, parse: host)
      run(source, broadcast: host(->(t) { runner.fire('#parse Y', []) if t == 'X' }))
    end

    it "delivers a nested #trigger #parse to the issuer's actions inline" do
      r = run_with_trigger_chain("action echo act-Y when ^Y$\npause 0.1\nput #parse X\necho after-parse\n" \
                                 "match bad Y\nmatchwait 0.5\necho timeout\nexit\nbad:\necho buffered\n")
      expect(r[:echoes]).to eq(%w[act-Y after-parse timeout])
    end

    it 'drops the nested line during the launch run, like its own #parse (not yet in the ParseTriggers list)' do
      r = run_with_trigger_chain("action echo act-Y when ^Y$\nput #parse X\npause 0.1\necho done\n")
      expect(r[:echoes]).to eq(['done'])
    end
  end
end
