# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/genie'

# Eval actions, waiteval and variable-change dispatch on the REAL interpreter, headless.
# Remix references:
#   Script.TriggerVariableChanged Script.cs:1358-1433 R (eval actions, waiteval flag)
#   EvalWaitEval Script.cs:3439-3445 R, TickScript waiteval arm Script.cs:1573-1583 R
#   AddLocalVariable 3554-3558, eval 3275, evalmath 3244/3250, DoMath 3307, put 3465, save 3535,
#   goto 2465-2466, matchwait 1609-1610 R (raise "%name"); random 3119, shift 3005-3025,
#   deletevariable 3551 R (raise nothing)
# Expectations marked "(tNNN)" are the frozen Remix golden of that flow case.
RSpec.describe Lich::Genie::Interpreter do
  let(:change) { Lich::Genie::VariableDispatch::Change }

  # Runs +source+ on a virtual clock; +lines+ may hold VariableDispatch::Change entries (a
  # global change queued by another thread) and GameEvents items; they arrive +gap+ apart
  # (GenieSpecSupport::TimedInput; 0 = one DR packet). +var_broadcast+ is the host port (nil = none).
  def run(source, lines: [], var_broadcast: nil, game_state: nil, gap: 0.0)
    clock = [0.0]
    input = GenieSpecSupport::TimedInput.new(lines, clock: clock, gap: gap)
    echoes = []
    sends = []
    game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |t| sends << t } }
    interp = Lich::Genie::Engine.build(source, name: 't', game: game, input: input, game_state: game_state,
                                               echo: ->(t) { echoes << t }, clock: -> { clock[0] },
                                               var_broadcast: var_broadcast)
    interp.run
    { echoes: echoes, sends: sends, unread: input.items, interp: interp }
  end

  d3 = "[Script error: maximum nested dispatch depth (#{Lich::Genie::DispatchDepth::LIMIT}) exceeded on: variable change %s]"

  describe 'local variable changes (t121)' do
    it 'fires on exactly the verbs that raise "%name", in Remix order' do
      src = <<~GENIE
        action echo LOCAL %x when eval %x = 1
        action echo BARE when eval %y
        action echo ZERO $0 when eval %z = 2
        action echo AB %ab when eval %ab = 1
        action echo LBL %lastlabel when eval %lastlabel = here
        action echo SAVE when eval %s = hi
        action echo CNT %c when eval %c = 3
        action echo EM when eval %em = 4
        action echo EV when eval %ev = yes
        action echo LC when eval contains("%lastcommand", "#echo")
        action echo RND when eval %r > 0
        action echo UNV when eval %u = 0
        var x 0
        var x 1
        math x add 1
        var x 1
        var y 0
        var z 2
        var ab 1
        var a 7
        goto here
        here:
        save hi
        counter set 3
        evalmath em 2 + 2
        eval ev "yes"
        put #echo hello
        random 5 9
        var u 0
        unvar u
        echo end
      GENIE
      expect(run(src)[:echoes]).to eq(['LOCAL 1', 'LOCAL 1', 'BARE', 'ZERO 2', 'AB 1', 'AB 1', 'LBL here', 'SAVE',
                                       'CNT 3', 'EM', 'EV', 'hello', 'LC', 'UNV', 'end'])
    end

    it 'fires on an evalmath that fails (sets 0) and never for shift (Script.cs:3250, 3005-3025 R)' do
      src = <<~GENIE
        action echo EMZ %em when eval %em = 0
        action echo SH when eval %argcount
        evalmath em (1 +
        shift
        echo end
      GENIE
      # EvalEvalMath's catch (Script.cs:3246-3251 R): PrintError(message + ". Local Variable em
      # has been set to 0."), then the set. (`1 +` would be VB-numeric, i.e. 1.)
      expect(run(src)[:echoes]).to eq(['[Script error in t.cmd: Invalid expression: (1 +. Local Variable em has been set to 0.]', 'EMZ 0', 'end'])
    end

    it 'skips an inactive class and a removed action; a class turned on fires again (t121)' do
      src = <<~GENIE
        action (cls) echo CLS when eval %q = 1
        action echo RMV when eval %w = 1
        action (cls) off
        var q 1
        action (cls) on
        var q 1
        action remove eval %w = 1
        var w 1
        echo end
      GENIE
      expect(run(src)[:echoes]).to eq(%w[CLS end])
    end

    it 'never fires an eval action on a game line, and never a text action on a change' do
      src = <<~GENIE
        action echo EVAL when eval %x = 1
        action echo TEXT when %x
        var x 1
        waitfor done
        echo end
      GENIE
      expect(run(src, lines: ['%x', 'x = 1', 'done'])[:echoes]).to eq(%w[EVAL TEXT end])
    end

    it 'does not expand an `eval ` key at registration but does expand an `e/` key: e/ goes stale' do
      src = <<~GENIE
        var x 0
        action echo EVAL when eval %x = 1
        action echo ESLASH when e/%x = 1/
        var x 1
        echo end
      GENIE
      expect(run(src)[:echoes]).to eq(%w[EVAL end]) # "e/0 = 1/" never contains "%x"
    end
  end

  describe 'an abort inside the pass' do
    it 'ends the pass: a later matching eval action does not run (ScriptDone, Script.cs:1395-1396 R)' do
      src = "action exit when eval %x = 1\naction echo SECOND when eval %x > 0\nvar x 1\necho after\n"
      expect(run(src)[:echoes]).to eq([])
    end
  end

  describe 'chains and gotos (t122)' do
    it 'runs chained eval actions synchronously and an eval action goto stops the row loop' do
      src = <<~GENIE
        action var b 1 when eval %a = 1
        action echo B-FIRED %b when eval %b = 1
        action goto done when eval %flag = 1
        var a 1
        var flag 1
        echo not-here
        done:
        echo at-done %lastlabel
      GENIE
      expect(run(src)[:echoes]).to eq(['B-FIRED 1', 'at-done done'])
    end

    it 'lets an eval action on %lastlabel that jumps win over the matchwait label it fired on' do
      src = <<~GENIE
        action goto other when eval %lastlabel = hit
        match hit go
        matchwait
        hit:
        echo at-hit
        exit
        other:
        echo at-other
      GENIE
      expect(run(src, lines: ['go'])[:echoes]).to eq(['at-other'])
    end
  end

  describe 'the nesting cap (decided; Remix overflows its stack)' do
    it 'stops a self-feeding eval action with one script error and stops the script' do
      src = <<~GENIE
        action math n add 1;var x 1 when eval %x = 1
        var n 0
        var x 1
        echo after
      GENIE
      expect(run(src)[:echoes]).to eq([format(d3, '%x')])
    end

    it 'unwinds through math/counter/evalmath/eval instead of reporting a bad MATH expression' do
      %w[math\ n\ add\ 1 counter\ add\ 1 evalmath\ n\ 1\ +\ 1 eval\ n\ 1].each do |verb|
        name = verb.start_with?('counter') ? 'c' : 'n'
        src = "action #{verb} when eval %#{name}\n#{verb}\necho after\n"
        expect(run(src)[:echoes]).to eq([format(d3, "%#{name}")]), verb
      end
    end

    it 'continues the count of a queued change: one raised at depth 20 cannot nest again' do
      src = <<~GENIE
        action var y 1 when eval $g = 1
        action echo Y when eval %y = 1
        waitfor done
        echo end
      GENIE
      deep = run(src, lines: [change.new('$g', 20), 'done'], game_state: { 'g' => '1' })
      expect(deep[:echoes]).to eq([format(d3, '$g')])
      shallow = run(src, lines: [change.new('$g', 18), 'done'], game_state: { 'g' => '1' })
      expect(shallow[:echoes]).to eq(%w[Y end])
    end
  end

  describe 'global changes offered by the script loop (t125)' do
    it 'reaches the script only once it is listed (after its first wait) when no host is wired' do
      src = <<~GENIE
        action echo EARLY when eval $foo = 1
        put #var foo 1
        pause 0.1
        put #var foo 1
        echo end
      GENIE
      expect(run(src)[:echoes]).to eq(%w[EARLY end])
    end

    it 'hands its own `#var`/`#tvar`/`#svar`/`#math` to the host port with "$" + name' do
      seen = []
      src = "put #var a 1\nput #tvar b 2\nput #svar c 3\nput #math d add 4\nput #unvar a\n"
      run(src, var_broadcast: ->(name) { seen << name })
      expect(seen).to eq(%w[$a $b $c $d])
    end

    it 'processes a queued change in any wait, before the lines queued after it (t46)' do
      src = <<~GENIE
        action echo VAR $health when eval $health < 60
        action echo TEXT when ^Ouch
        pause 1
        echo end
      GENIE
      result = run(src, lines: [change.new('$health', 0), 'Ouch'], game_state: { 'health' => '50' })
      expect(result[:echoes]).to eq(['VAR 50', 'TEXT', 'end'])
    end

    it 'contains a fault of a listed change: one line, the script runs on (FormMain.cs:4970-4978 R)' do
      src = <<~GENIE
        action echo BAD when eval matchre("$g", "(")
        action echo GOOD when eval $g = 1
        waitfor done
        echo end
      GENIE
      # SortedList order: "$g = 1" sorts before "matchre(...": GOOD fires, BAD faults, the pass
      # ends there (Remix's exception leaves the foreach), the script goes on.
      result = run(src, lines: [change.new('$g', 0), 'done'], game_state: { 'g' => '1' })
      expect(result[:echoes].length).to eq(3)
      expect(result[:echoes].values_at(0, 2)).to eq(%w[GOOD end])
      expect(result[:echoes][1]).to start_with('[Error in TriggerVariableChange: ')
    end

    it 'is the dispatch owner of its thread while it runs, and only then' do
      owners = []
      result = run("put #var a 1\n", var_broadcast: ->(_name) { owners << Lich::Genie::ParseDispatch.owner })
      expect(owners).to eq([result[:interp]])
      expect(Lich::Genie::ParseDispatch.owner).to be_nil
    end

    it 'drops the change when the script has finished' do
      interp = run("echo x\n")[:interp]
      expect { interp.deliver_variable_change('%x') }.not_to raise_error
    end

    # The rest of a queued batch is a no-op once an eval action stopped the
    # script (an `exit` stops TickScript, Script.cs:1395-1396 R; nothing runs on a done script).
    it 'runs no eval action of a later name in the same queued batch once an earlier one stopped the script' do
      src = "action exit when eval $health = 40\naction echo AFTER-EXIT when eval $mana = 40\nwaiteval $spirit = 1\n"
      result = run(src, lines: [change.batch([['$health', 0], ['$mana', 0]]), 'unread'],
                        game_state: { 'health' => '40', 'mana' => '40' })
      expect([result[:echoes], result[:unread]]).to eq([[], ['unread']])
    end
  end

  describe 'waiteval (Script.cs:1407-1424, 1573-1583, 3439-3445 R; t123)' do
    it 'waits for a change even when the condition is already true; a game line never resumes it' do
      src = "var g 1\nwaiteval %g = 1\necho after\n"
      expect { run(src, lines: ['some text']) }.to raise_error(/input exhausted/)
    end

    it 'resumes on a queued change of a variable its text contains' do
      src = "waiteval $g = 1\necho after $g\n"
      result = run(src, lines: ['line', change.new('$h', 0), change.new('$g', 0), 'unread'], game_state: { 'g' => '1' }, gap: 0.02)
      expect(result[:echoes]).to eq(['after 1'])
      expect(result[:unread]).to eq(['unread'])
    end

    it 'stays armed while the expanded text evaluates to "0"' do
      src = "waiteval $g = 1\necho after\n"
      expect { run(src, lines: [change.new('$g', 0)], game_state: { 'g' => '0' }) }.to raise_error(/input exhausted/)
    end

    it 'resumes on a local set by an action, never on a random one (random raises nothing)' do
      echoes = []
      src = "action var x 1 when ^SETX\naction random r 5 9 when ^RAND\nwaiteval %x = 1\necho after-x\nwaiteval %r > 0\necho after-r\n"
      clock = [0.0]
      input = GenieSpecSupport::TimedInput.new(%w[RAND SETX RAND], clock: clock, gap: 0.02, limit: 50)
      expect do
        Lich::Genie::Engine.run(src, input: input, echo: ->(t) { echoes << t }, clock: -> { clock[0] })
      end.to raise_error(/input exhausted/)
      expect(echoes).to eq(['after-x'])
    end

    it 'evaluates its text no more once satisfied (m_bWaitForEvent stays true until the next waiteval)' do
      counting = lambda do |changes|
        reads = []
        state = Object.new
        state.define_singleton_method(:[]) { |name| name == 'g' ? (reads << name) && '1' : nil }
        state.define_singleton_method(:key?) { |name| name == 'g' }
        run("waiteval $g = 1\nwaitfor done\necho end\n", lines: Array.new(changes) { change.new('$g', 0) } + ['done'], game_state: state)
        reads.length
      end
      expect(counting.call(1)).to be_positive
      expect(counting.call(3)).to eq(counting.call(1))
    end

    it 'fires a text equal to the name without evaluating it' do
      src = "waiteval %v\necho after %v\n"
      result = run(src.sub('waiteval', "action var v 0 when ^GO\nwaiteval"), lines: ['GO'])
      expect(result[:echoes]).to eq(['after 0'])
    end
  end
  # Remix resumes `wait` on m_bWaitForPrompt and `move` on m_bWaitForMove
  # (Script.cs:1537-1546, 1585-1597 R); TriggerVariableChanged never touches either. Only
  # TriggerPrompt / TriggerMove (GameEvents::Prompt / ::Move) set them: a game line does not either.
  describe 'a queued change is no game line for wait/move' do
    let(:prompt) { Lich::Genie::GameEvents::Prompt.new('> ') }

    it 'does not resume a move or a wait on a change or a game line; the move/prompt event does' do
      %w[move\ north wait].each do |row|
        src = "#{row}\necho resumed\n"
        expect { run(src, lines: [change.new('$health', 0), change.batch([['lastcommand', 0], ['$prompt', 0]]), 'Obvious exits: north.']) }
          .to raise_error(/input exhausted/), row
      end
      result = run("move north\necho resumed\n", lines: [change.new('$health', 0), Lich::Genie::GameEvents::MOVE, 'unread'], gap: 0.02)
      expect([result[:echoes], result[:unread]]).to eq([['resumed'], ['unread']])
      expect(run("wait\necho resumed\n", lines: [change.new('$health', 0), prompt])[:echoes]).to eq(['resumed'])
    end

    it 'still runs the eval actions of a change that arrives during a move or a wait' do
      src = "action echo HP $health when eval $health < 50\nwait\necho resumed\n"
      result = run(src, lines: [change.new('$health', 0), prompt], game_state: { 'health' => '40' })
      expect(result[:echoes]).to eq(['HP 40', 'resumed'])
    end

    it 'does not resume a waitfor, but a later matching line does' do
      src = "waitfor done\necho resumed\n"
      expect { run(src, lines: [change.new('$x', 0)]) }.to raise_error(/input exhausted/)
      expect(run(src, lines: [change.new('$x', 0), 'done'])[:echoes]).to eq(['resumed'])
    end

    # A waitfor is no LINE_WAITS state -- the `#parse` of an eval action run by
    # a queued change satisfies it at once, with no game line after it (corpus mc_include.cmd:1054,
    # miner.cmd:79 shapes; TriggerParse sets m_bWaitForStringResume, Script.cs:1179-1316 R).
    it 'resumes a waitfor on the `#parse` of an eval action a queued change fires (no game line)' do
      src = "action put #parse YOU HAVE ARRIVED when eval $health = 40\nwaitfor YOU HAVE ARRIVED\necho WAITFOR-DONE\n"
      result = run(src, lines: [change.new('$health', 0)], game_state: { 'health' => '40' })
      expect(result[:echoes]).to eq(['WAITFOR-DONE'])
    end
  end

  # VariableDispatch queues a name only for a script that can react to it.
  describe '#wants_variable_change?' do
    def interpreter_for(source)
      Lich::Genie::Engine.build(source, name: 't', input: nil, echo: ->(_t) {})
    end

    it 'is false for every name in a program without a waiteval or an eval action' do
      src = "action echo hi when ^You see $health\nmatchre x when eval\nwait\nmove north\necho evaluate e/$health %x\n"
      interp = interpreter_for(src)
      expect(%w[$health %x lastcommand].map { |name| interp.wants_variable_change?(name) }).to eq([false, false, false])
    end

    it 'is true exactly for the names a waiteval or literal eval-action row contains, in any case/spacing' do
      {
        'waiteval $x = 1' => '$x', 'if 1 then WAITEVAL $x' => '$x', 'action echo x when eval $x' => '$x',
        'ACTION echo x WHEN  EVAL $x' => '$x', 'action echo x when e/$x/' => '$x',
        'action (c) instant echo x when eval %y' => '%y', 'action action y when eval %z when ^go' => '%z',
        'waiteval $roomid = %starter.room' => '%starter.room'
      }.each do |row, name|
        interp = interpreter_for("#{row}\n")
        expect([interp.wants_variable_change?(name), interp.wants_variable_change?('$other')]).to eq([true, false]), row
      end
    end

    it 'adds the key of an eval action registered at run time (an expanded e/ key, a substituted trigger)' do
      src = "var t e/$a = 1/\nvar u ^text $b\nvar v $health\naction echo T when %u\npause 1\n" \
            "action echo E when %t\npause 1\naction echo H when e/%v < 5/\npause 1\n"
      states = []
      interp = nil
      input = Object.new
      input.define_singleton_method(:next_line) do |timeout: nil|
        states << %w[$a $b $health].map { |name| interp.wants_variable_change?(name) }
        timeout && nil
      end
      interp = Lich::Genie::Engine.build(src, name: 't', input: input, echo: ->(_t) {}, clock: -> { states.length.to_f })
      interp.run
      expect(states.uniq).to eq([[false, false, false], [true, false, false], [true, false, true]])
    end
    # wants_variable_change? runs on Lich's parser thread for every change, so the
    # watch texts must not grow with each re-registration of an eval action in a loop (corpus
    # shape: `action ... when eval ...` inside a label loop). A key a watch text already contains
    # adds nothing (every name it contains is wanted already); a new key is still added.
    it 'adds a run-time key once, however often it is re-registered, and never one a row covers' do
      src = "var t e/$health = 1/\nvar m e/$mana = 1/\ncounter set 0\nloop:\naction echo E when %t\n" \
            "action echo L when eval $spirit = 1\ncounter add 1\nif %c < 300 then goto loop\n" \
            "action echo M when %m\naction echo M2 when %m\n"
      interp = run(src)[:interp]
      texts = interp.instance_variable_get(:@watch_texts)
      expect(texts.length).to eq(3) # the literal `when eval $spirit` row, "$health = 1", "$mana = 1"
      expect(%w[$health $mana $spirit $stamina].map { |name| interp.wants_variable_change?(name) })
        .to eq([true, true, true, false])
    end
  end

  # Remix golden: genieflow q09b prints "y-done 20".
  describe 'the nesting cap counts firings, not checks' do
    it 'runs 20 nested firings whose 21st check is false, and caps the 21st firing' do
      expect(run("action math y add 1 when eval %y < 20\nvar y 0\necho y-done %y\n")[:echoes]).to eq(['y-done 20'])
      expect(run("action math z add 1 when eval %z < 21\nvar z 0\necho z-done %z\n")[:echoes]).to eq([format(d3, '%z')])
    end
  end

  # EvalEval (Script.cs:3262-3275 R): the $-args are bound to Eval's result
  # list BEFORE the set raises "%r"; the eval action's check then clears that list -- and so the
  # $-args, which ARE it: Remix prints "caps1 [] []" (probe q12).
  describe 'eval binds its captures before the variable change' do
    it 'loses the new captures to the eval action check on the variable' do
      src = <<~'GENIE'
        action echo WATCH when eval %r = 1
        eval s matchre("old one", "(\w+) (\w+)")
        eval r matchre("abc def", "(\w+) (\w+)")
        echo caps1 [$1] [$2]
      GENIE
      expect(run(src)[:echoes]).to eq(['WATCH', 'caps1 [] []'])
    end
  end

  # The automapper's "$roomid" (GameState#mapper_room_update) reaches a
  # script queued -- hunt.cmd:7236 and hunt.cmd:228 shapes.
  describe '$roomid changes (hunt.cmd shapes)' do
    it 'resumes `waiteval $roomid = %starter.room` and fires `when eval $roomid != %starter.room`' do
      room = {}
      state = Object.new
      state.define_singleton_method(:[]) { |name| room[name] }
      state.define_singleton_method(:key?) { |name| room.key?(name) }
      src = <<~GENIE
        var starter.room 118
        waiteval $roomid = %starter.room
        echo home $roomid
        action goto SNEAKING when eval $roomid != %starter.room
        waitfor never
        SNEAKING:
        echo sneak $roomid
      GENIE
      # each step: the host's $roomid from then on, and the line Lich delivers
      # (a game row's batches, one packet each: 20 ms apart)
      steps = [['117', 'text'], ['118', change.new('$roomid', 0, game: true)], ['119', change.batch([['$prompt', 0], ['$roomid', 0]], game: true)]]
      clock = [0.0]
      arrival = [0.02]
      input = Object.new
      input.define_singleton_method(:next_line) do |timeout: nil|
        if !steps.empty? && (timeout.nil? || arrival[0] <= clock[0] + timeout)
          clock[0] = [clock[0], arrival[0]].max
          arrival[0] = clock[0] + 0.02
          step = steps.shift
          room['roomid'] = step[0]
          next step[1]
        end
        raise 'input exhausted' if timeout.nil?

        clock[0] += timeout
        nil
      end
      echoes = []
      Lich::Genie::Engine.run(src, input: input, game_state: state, echo: ->(t) { echoes << t }, clock: -> { clock[0] })
      expect([echoes, steps]).to eq([['home 118', 'sneak 119'], []])
    end
  end
end
