# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/genie'

# The action subsystem on the REAL interpreter, headless. Remix references:
#   EvalAction Script.cs:3122-3220 R (trigger expansion, forms, aborts)
#   ClassActionList Script.cs:328-485 R (keyed registry + SortedList order, classes)
#   TriggerParse Script.cs:1281-1305 R (every matching action fires, last goto wins)
#   ParseAction Script.cs:2119-2270 R (bodies), GetFunctionType Script.cs:4090-4317 R
# Expectations marked "(tNN)" are the frozen Remix golden of that flow case.
RSpec.describe Lich::Genie::Interpreter do
  # Runs +source+ on a virtual clock (GenieSpecSupport::TimedInput: the lines arrive +line_dt+
  # apart, 0 = one DR packet; an empty read moves it by the requested timeout). Echoes are
  # recorded with the clock value.
  def run(source, lines: [], line_dt: 0.0, args: [])
    clock = [0.0]
    input = GenieSpecSupport::TimedInput.new(lines, clock: clock, gap: line_dt)
    echoes = []
    sends = []
    hooks = []
    game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |t| sends << t } }
    hook_sink = Object.new.tap { |h| h.define_singleton_method(:emit) { |op, payload| hooks << [op, payload] } }
    lists = Lich::Genie::Lists.new
    Lich::Genie::Engine.run(source, name: 't', args: args, game: game, input: input, hooks: hook_sink, lists: lists,
                                    echo: ->(t) { echoes << [clock[0].round(3), t] }, clock: -> { clock[0] })
    { echoes: echoes.map(&:last), timed: echoes, sends: sends, hooks: hooks, unread: input.items, lists: lists }
  end

  describe 'trigger expansion at registration' do
    it 'expands %locals once, when the action row runs (t98)' do
      src = <<~GENIE
        var foe goblin
        action echo SAW $1 when ^The %foe (\\w+)
        var foe orc
        waitfor done
      GENIE
      expect(run(src, lines: ['The orc snarls', 'The goblin snarls', 'done'])[:echoes]).to eq(['SAW snarls'])
    end

    it 'expands a variable holding a whole pattern (automapper %move_OK) and $globals (t98, t110)' do
      src = <<~GENIE
        var move_OK ^You go (\\w+)|^Obvious
        put #var myglob zzz
        action echo MOVED $1 when %move_OK
        action echo GLOBAL when ^gl $myglob
        waitfor done
      GENIE
      expect(run(src, lines: ['You go north', 'Obvious paths', 'gl zzz', 'done'])[:echoes]).to eq(['MOVED north', 'MOVED', 'GLOBAL'])
    end

    it "expands the script's current $-args (a gosub's), not the action's" do
      src = <<~GENIE
        gosub setup north
        waitfor done
        exit
        setup:
        action echo GOT when ^go $1$
        return
      GENIE
      expect(run(src, lines: ['go south', 'go north', 'done'])[:echoes]).to eq(['GOT'])
    end

    it 'expands the action remove argument too (t98)' do
      src = <<~GENIE
        var foe goblin
        action var x 1 when ^The %foe snarls
        action remove ^The %foe snarls
        waitfor done
        echo x=%x
      GENIE
      expect(run(src, lines: ['The goblin snarls', 'done'])[:echoes]).to eq(['x=%x'])
    end

    it 'splits at the FIRST literal " when " and trims the trigger' do
      src = <<~GENIE
        action echo hit when   ^a when b$
        waitfor done
      GENIE
      expect(run(src, lines: ['a when b', 'done'])[:echoes]).to eq(['hit'])
    end
  end

  describe 'registry: keyed, sorted, every match fires' do
    it 'registers an action re-run in a loop once, and the last of two same-key actions wins (t94)' do
      src = <<~GENIE
        var n 0
        loop:
        action math hits add 1 when ^hit
        action echo ONE when ^dup
        action echo TWO when ^dup
        math n add 1
        if %n < 3 then goto loop
        waitfor done
        echo hits=%hits
      GENIE
      expect(run(src, lines: %w[hit dup done])[:echoes]).to eq(%w[TWO hits=1])
    end

    it 'fires in SortedList (ICU) order, not registration order' do
      src = <<~GENIE
        action echo letters when b
        action echo symbol when ^b
        action echo upper when B?b
        action echo lower when b?b
        waitfor done
      GENIE
      expect(run(src, lines: %w[b done])[:echoes]).to eq(%w[symbol letters lower upper])
    end

    it 'skips the rest of a body after its goto, runs every later action, and the last goto wins (t95)' do
      src = <<~GENIE
        action echo a-before;goto first;echo a-after when ^go
        action echo b-before;goto second;echo b-after when go
        action echo c-after-gotos when o$
        waitfor never
        first:
        echo at-first %lastlabel
        exit
        second:
        echo at-second %lastlabel
      GENIE
      expect(run(src, lines: ['go'])[:echoes]).to eq(['a-before', 'b-before', 'c-after-gotos', 'at-second second'])
    end

    it 'does not fire an action a body removed earlier in the same pass (Remix would throw)' do
      src = <<~GENIE
        action action remove go$ when ^go$
        action echo removed-one when go$
        waitfor done
        echo end
      GENIE
      expect(run(src, lines: %w[go done])[:echoes]).to eq(['end'])
    end

    # A body can only register an action through a group: its own " when " would split the
    # outer row. Remix's enumerator throws on the modified list (a GenieError); ours offers
    # the new action from the next line on.
    it 'offers an action a body registered only from the next line on' do
      src = <<~GENIE
        action action $1;echo first when ^reg (.*)
        waitfor done
      GENIE
      lines = ['reg echo late when ^reg', 'reg echo late when ^reg', 'done']
      expect(run(src, lines: lines)[:echoes]).to eq(%w[first late first]) # `^reg` sorts before `^reg (.*)`
    end

    it 'fires a re-registered action under its new body even after the list was walked' do
      src = <<~GENIE
        action echo old when ^go
        waitfor go
        action echo new when ^go
        waitfor done
      GENIE
      expect(run(src, lines: %w[go go done], line_dt: 0.02)[:echoes]).to eq(%w[old new]) # one packet each
    end
  end

  describe 'classes (t97)' do
    it 'keeps the FIRST state each class was seen with for later actions' do
      src = <<~GENIE
        action (c1) off
        action (c1) echo c1-fired when ^ping$
        action (c1) on
        action (c1) echo c1b-fired when ^pin
        action (c2) echo c2-fired when ^ping
        action (c2) off
        action (c2) echo c2b-fired when pi
        waitfor done
      GENIE
      expect(run(src, lines: %w[ping done])[:echoes]).to eq(%w[c1-fired c2b-fired])
    end

    it 'lets a body toggle a class with a nested action row (shopper.cmd)' do
      src = <<~GENIE
        action action (shop) off when ^stop
        action (shop) echo shopping when ^item
        waitfor done
      GENIE
      expect(run(src, lines: %w[item stop item done])[:echoes]).to eq(['shopping'])
    end

    it 'reads add/instant before the class: with a (class) prefix they stay in the body (t101)' do
      src = <<~GENIE
        action instant (cA) echo iA when ^ping
        action (cB) instant echo iB when ^ping$
        action (cC) add echo iC when ^pi
        action  (cD) echo iD when ^p
        action add (cE) echo iE when p
        waitfor done
      GENIE
      expect(run(src, lines: %w[ping done])[:echoes]).to eq(%w[iA iE])
    end
  end

  describe 'action bodies' do
    it 'runs every verb through the row executor and ignores unknown or wrong-case words (t99)' do
      src = <<~GENIE
        var bar BAR
        action %w = 5;$gv = 7;eval z len("%bar");evalmath m 1+1;counter add 2;unvar bar;Put SHOULDNOT;frobnicate x;#var hv 1;echo e=%w g=$gv z=%z m=%m c=%c b=%bar when ^go
        waitfor done
        echo hv=$hv
      GENIE
      r = run(src, lines: %w[go done])
      expect(r[:echoes]).to eq(['e=5 g=7 z=3 m=2 c=2 b=%bar', 'hv=$hv'])
      expect(r[:sends]).to eq([])
    end

    it 'replaces every " = " of a %row' do
      expect(run("action %x = a = b when ^go\nwaitfor done\necho [%x]\n", lines: %w[go done])[:echoes]).to eq(['[a b]'])
    end

    it 'routes put #command but ignores a bare #command row' do
      r = run("action #class panic on;put #class calm on when ^go\nwaitfor done\n", lines: %w[go done])
      expect(r[:lists].classes.entries).to eq([['calm', true], ['default', true]])
    end

    it 'sets $0 to the whole line and $n to the groups, quotes removed, "" when unmatched (t100)' do
      src = <<~GENIE
        action echo full=[$0] g1=[$1] g2=[$2] g3=[$3] when ^(\\w+) says, "(.*)"
        action echo opt=[$1][$2] when ^opt(x)?(y)?
        waitfor done
      GENIE
      expect(run(src, lines: ['Bob says, "hello there"', 'opty', 'done'])[:echoes])
        .to eq(['full=[Bob says, hello there] g1=[Bob] g2=[hello there] g3=[]', 'opt=[][y]'])
    end

    # The group itself holds the quotes. genieflow Remix probe
    # m6: `Bob says, "hi there"` -> g2=[hi there].
    it 'strips the quotes a group captured, not only those of $0' do
      src = "action echo g1=[$1] g2=[$2] when ^(\\w+) says, (.*)\nwaitfor done\n"
      expect(run(src, lines: ['Bob says, "hi there"', 'done'])[:echoes]).to eq(['g1=[Bob] g2=[hi there]'])
    end

    it 'replaces $1 before $10 and keeps an escaped \\$1 literal (t100)' do
      src = <<~GENIE
        action echo ten=[$10] when ^(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)
        action echo esc=[\\$1] when ^(esc)
        waitfor done
      GENIE
      expect(run(src, lines: %w[abcdefghij esc done])[:echoes]).to eq(['ten=[a0]', 'esc=[$1]'])
    end

    it 'keeps a backslash sequence of a group literal' do
      expect(run("action echo [$1] when ^x (.*)\nwaitfor done\n", lines: ['x a\\0b\\\\c', 'done'])[:echoes]).to eq(['[a\\0b\\\\c]'])
    end

    it 'expands a group again in the row executor (p04 / t106)' do
      src = <<~GENIE
        var loc LOCAL
        action echo A3 [$1] when ^X(.*)$
        waitfor done
      GENIE
      expect(run(src, lines: ['X %loc', 'done'])[:echoes]).to eq(['A3 [ LOCAL]'])
    end

    it 'splits the body like SafeSplit: an empty segment swallows the next command (uber.cmd, t105)' do
      src = <<~GENIE
        action var a $1;;var b $2;echo "c;d";echo {e;f};echo g\\;h when ^go (\\w+) (\\w+)
        waitfor done
        echo a=%a b=%b
      GENIE
      expect(run(src, lines: ['go x y', 'done'])[:echoes]).to eq(['"c;d"', '{e;f}', 'g\\;h', 'a=x b=%b'])
    end

    it 'evaluates if ... then <row> and runs the row; IF in capitals is no verb (t103)' do
      src = <<~GENIE
        var a 1
        action if (%a = 1) then echo yes $1;if (%a = 2) then echo no;IF (%a = 1) then echo upper;if (%a = 1) then goto lbl;echo skipped when ^go (\\w+)
        waitfor never
        lbl:
        echo at-lbl %lastlabel
      GENIE
      expect(run(src, lines: ['go north'])[:echoes]).to eq(['yes north', 'at-lbl lbl'])
    end

    it 'stops the script with a GenieError-style line for an if row without " then "' do
      src = "action if (1 = 1)then echo x;echo NOT when ^go\nwaitfor done\necho NOT EITHER\n"
      expect(run(src, lines: %w[go done])[:echoes]).to eq(["[Length cannot be less than zero. (Parameter 'length')]"])
    end

    # (A bare `{`/`}` would change SafeSplit's brace depth and merge the rows around it.)
    {
      'gosub sub' => 'GOSUB', 'return' => 'RETURN', '{ }' => 'BLOCK START', 'begin' => 'BLOCK START',
      '} {' => 'BLOCK END', 'end' => 'BLOCK END'
    }.each do |row, verb|
      it "aborts on a #{row.inspect} row and runs nothing after it (t96)" do
        src = <<~GENIE
          action echo before;#{row};echo after when ^go
          action echo later when g
          waitfor done
          echo not-reached
          exit
          sub:
          echo in-sub
          return
        GENIE
        expect(run(src, lines: %w[go done])[:echoes]).to eq(['before', "[Script error in t.cmd: #{verb} is not allowed from an ACTION command!]", '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
      end
    end

    it 'treats a gosub reached through if ... then as a jump that clears the call stack' do
      src = <<~GENIE
        action if (1 = 1) then gosub sub when ^go
        waitfor never
        sub:
        echo in-sub
        return
      GENIE
      expect(run(src, lines: %w[go])[:echoes]).to eq(['in-sub', '[Script error in t.cmd(5): RETURN command failed. There are no more gosub bookmarks to return to!]',
                                                      'Trace follows:', "\tgosub sub (1)\n\taction goto (1)\n\tpassing label sub (3)",
                                                      '[Script aborted! (Run time: 0.01 seconds): t.cmd]']) # the line's 10 ms
    end

    it 'aborts on an unknown goto label; neither the rest nor a later action runs' do
      src = "action echo pre;goto nowhere;echo post when ^go\naction echo later when g\nwaitfor done\necho not-reached\n"
      expect(run(src, lines: %w[go done])[:echoes]).to eq(['pre', '[Script error in t.cmd(1): Unknown label from GOTO: nowhere]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    it 'aborts on an invalid math expression in an action and in a script row' do
      expect(run("action echo pre;math x frob 1;echo post when ^go\nwaitfor done\n", lines: %w[go done])[:echoes])
        .to eq(['pre', '[Script error in t.cmd(1): Invalid MATH expression: frob 1]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
      expect(run("counter frob 1\necho not-reached\n")[:echoes]).to eq(['[Script error in t.cmd(1): Invalid MATH expression: frob 1]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    it 'ends the script on exit; later actions do not run' do
      expect(run("action echo pre;exit;echo post when ^go\naction echo later when g\nwaitfor done\n", lines: %w[go done])[:echoes])
        .to eq(['pre'])
    end
  end

  describe 'EvalAction forms and errors' do
    it 'aborts with "Invalid ACTION command" when there is no " when " (t102)' do
      expect(run("echo start\naction echo x\necho not-reached\n")[:echoes]).to eq(['start', '[Script error in t.cmd(2): Invalid ACTION command: echo x]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
      expect(run("action echo x\twhen y\necho not-reached\n")[:echoes]).to eq(["[Script error in t.cmd(1): Invalid ACTION command: echo x\twhen y]", '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
      expect(run("action (c) remove ^x\necho not-reached\n")[:echoes]).to eq(['[Script error in t.cmd(1): Invalid ACTION command: (c) remove ^x]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    it 'shows the text without add/instant, but the whole text with a class, in the regex error' do
      expect(run("action add echo x when (\n")[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in action: echo x when (]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
      expect(run("action (c) add echo x when (\n")[:echoes]).to eq(['[Script error in t.cmd(1): Invalid RegExp in action: (c) add echo x when (]', '[Script aborted! (Run time: 0.00 seconds): t.cmd]'])
    end

    it 'clears every action but keeps the class states' do
      src = <<~GENIE
        action (c) off
        action echo a when ^go
        action clear
        action (c) echo b when ^go
        waitfor done
        echo end
      GENIE
      expect(run(src, lines: %w[go done])[:echoes]).to eq(['end'])
    end
  end

  # A .NET-valid pattern never aborts. A
  # variable-length lookbehind is emulated (GenieHunter hunt.cmd:309 through %critters, flow
  # t111/t116); one NetRegex cannot express is registered, never fires, and warns ONCE.
  describe '.NET-valid patterns Onigmo cannot compile' do
    it 'registers and fires the hunt.cmd:309 action whose trigger expands to a variable-length lookbehind (t111)' do
      src = <<~GENIE
        var undead4 spirit|(?<!arisen \\S+ )zombie(?!\\s)|zombie (head-splitter|mauler)
        var critters goblin|%undead4
        action (point) echo POINT $1 when (%critters) attempting to stealthily advance upon you
        echo registered
        waitfor done
        echo end
      GENIE
      lines = ['A spirit attempting to stealthily advance upon you', 'An arisen big zombie attempting to stealthily advance upon you',
               'A zombie mauler attempting to stealthily advance upon you', 'done']
      expect(run(src, lines: lines)[:echoes]).to eq(['registered', 'POINT spirit', 'POINT zombie mauler', 'end'])
    end

    it 'warns once per pattern for an Unsupported action re-registered in a loop, and keeps running' do
      src = <<~GENIE
        var n 0
        top:
        action echo never when (?:x(?<=a+)y)+
        math n add 1
        if %n < 3 then goto top
        echo n=%n
        waitfor done
        echo end
      GENIE
      expect(run(src, lines: %w[aaxy done])[:echoes]).to eq(
        ['[Genie: action pattern uses a variable-length lookbehind inside a quantified group, which the in-Lich ' \
         'engine cannot match; it will never fire: (?:x(?<=a+)y)+]', 'n=3', 'end']
      )
    end

    it 'warns for an Unsupported matchre and waitforre instead of an Invalid RegExp abort' do
      src = <<~GENIE
        action exit when ^stop
        matchre L \\w+(?<=a+)y
        matchwait 1
        echo timed-out
        waitforre \\w+(?<=b+)y
        echo never
      GENIE
      r = run(src, lines: ['aay', nil, 'bby', 'stop'], line_dt: 0.6)
      expect(r[:echoes].map { |e| e[/\A\[Genie: (\w+) pattern/, 1] || e }).to eq(%w[matchre timed-out waitforre])
    end

    # Eval's matchre()/replacere() with an Unsupported pattern were
    # silent (false / the subject unchanged); now one warning per function and pattern.
    it 'warns once per pattern for an Unsupported pattern in if/eval matchre() and replacere()' do
      src = <<~GENIE
        var n 0
        top:
        if matchre("aay", "\\w+(?<=a+)y") then echo hit
        eval r replacere("aay", "\\w+(?<=a+)y", "Z")
        math n add 1
        if %n < 2 then goto top
        echo r=%r n=%n
      GENIE
      why = 'a variable-length lookbehind after a variable-width part of the pattern, which the in-Lich engine cannot ' \
            'match; it will never fire: \\w+(?<=a+)y]'
      expect(run(src)[:echoes]).to eq(["[Genie: matchre() pattern uses #{why}", "[Genie: replacere() pattern uses #{why}", 'r=aay n=2'])
    end
  end

  describe 'state model' do
    it 'resumes at the label one tick after an action goto in a wait, %lastlabel set (t11)' do
      src = "action goto out when ^go\nwaitfor never\nout:\necho at %lastlabel\n"
      expect(run(src, lines: %w[go], line_dt: 0.5)[:timed]).to eq([[0.51, 'at out']])
    end

    it 'falls through to the row after a matchwait an action paused (t104)' do
      src = "action echo got;pause 0.5 when ^go\nmatch never nomatch\nmatchwait\necho fell-through\n"
      expect(run(src, lines: %w[go], line_dt: 0.1)[:timed]).to eq([[0.1, 'got'], [0.6, 'fell-through']])
    end

    it 'restarts a running pause from an action pause' do
      src = "action pause 2 when ^go\npause 1\necho done\n"
      expect(run(src, lines: %w[go], line_dt: 0.5)[:timed]).to eq([[2.5, 'done']])
    end

    it 'stops the row loop after a row whose own #parse fired an action goto (p19 / t108)' do
      src = <<~GENIE
        action put #parse INNER;echo after-inner when ^OUTER
        action goto lbl when ^INNER
        pause 0.1
        put #parse OUTER
        echo row-after-parse
        exit
        lbl:
        echo at-lbl
      GENIE
      expect(run(src)[:echoes]).to eq(%w[after-inner at-lbl])
    end

    it 'runs the rest of the outer body and later actions after a nested #parse goto (p18 / t107)' do
      src = <<~GENIE
        action put #parse INNER;echo after-inner when ^OUTER
        action goto lbl when ^INNER
        action echo third when OUTER
        waitfor never
        lbl:
        echo at-lbl [%lastlabel]
      GENIE
      expect(run(src, lines: %w[OUTER])[:echoes]).to eq(['after-inner', 'third', 'at-lbl [lbl]'])
    end

    # The jump clears the match list (Script.cs:2247-2268 R).
    # genieflow Remix probe m9: after the goto only GOOD is armed, so `x` does nothing.
    it 'clears the pending match list on an action goto' do
      src = <<~GENIE
        action goto L when ^go
        match BAD x
        matchwait
        echo fell
        exit
        L:
        match GOOD y
        matchwait 1
        echo timeout
        exit
        BAD:
        echo bad
        exit
        GOOD:
        echo good
      GENIE
      # nil = a quiet tick: the actionwait resumes at L and arms GOOD before x arrives
      expect(run(src, lines: ['go', nil, nil, 'x', 'y'], line_dt: 0.1)[:echoes]).to eq(%w[good])
    end

    # The action's pause replaces the wait even though the
    # same line satisfies it (TickScript looks at the CURRENT state, Script.cs:1487-1664 R).
    # genieflow Remix probe m4: after-waitfor and after-move each come 1 s after the line.
    it 'lets an action pause win over a waitfor or a move the same line satisfies' do
      waitfor = run("action pause 1 when ^done\nwaitfor done\necho after\n", lines: %w[done])
      expect(waitfor[:timed]).to eq([[1.0, 'after']])
      move = run("action pause 1 when ^moved\nmove north\necho after\n", lines: %w[moved])
      expect([move[:sends], move[:timed]]).to eq([['north'], [[1.0, 'after']]])
    end

    it 'resumes once at the goto label after a later action in the same pass paused the script' do
      src = "action goto lbl when ^A\naction pause 1 when ^B|^A\necho start\nwaitfor never\necho fell\nlbl:\necho atlabel\necho two\n"
      expect(run(src, lines: %w[A])[:timed]).to eq([[0.0, 'start'], [1.0, 'atlabel'], [1.0, 'two']])
    end

    it 'continues with the next row after gosub clear (t109)' do
      expect(run("echo a\ngosub clear\necho b\n")[:echoes]).to eq(%w[a b])
    end
  end
end
