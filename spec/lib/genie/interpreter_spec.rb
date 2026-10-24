# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/genie'

# Namespaced, not top-level: a top-level FakeGame/FakeInput would collide with any other
# spec file that defines the same name in the same rspec process.
module GenieSpecSupport
  module InterpreterSpecFakes
    # Records commands sent to the "game".
    class FakeGame
      attr_reader :commands

      def initialize = (@commands = [])
      def send_command(text) = (@commands << text)
    end

    # Feeds queued downstream lines on the virtual clock, each its own DR packet (20 ms apart,
    # above Interpreter::CHUNK_IDLE_SECONDS); a timed wait with nothing arriving moves the
    # clock by its timeout so pause/matchwait-timeout resume deterministically instead of hanging.
    class FakeInput < GenieSpecSupport::TimedInput
      def initialize(lines, clock_ref)
        super(lines, clock: clock_ref, gap: 0.02)
      end
    end
  end
end

# End-to-end tests: real Genie scripts compiled and run through the full pipeline
# (Lexer -> Interpreter -> Substitution/Eval/MathCalc) against fake ports.
RSpec.describe Lich::Genie::Interpreter do
  def run_script(source, input_lines: [], game_state: nil, include_loader: nil, clock: nil, mover: nil, args: [])
    clock_ref = [0.0]
    clock_proc = clock || -> { clock_ref[0] }
    game = GenieSpecSupport::InterpreterSpecFakes::FakeGame.new
    echoes = []
    hooks = []
    launches = []
    moves = []
    hook_sink = Object.new.tap do |o|
      o.define_singleton_method(:emit) { |op, payload| hooks << [op, payload] }
    end
    launch = ->(name, args) { launches << [name, args] }
    queue = Lich::Genie::CommandQueue.new(clock: -> { Time.at(clock_ref[0]) })
    lists = Lich::Genie::Lists.new
    Lich::Genie::Engine.run(
      source,
      name: 'test',
      args: args,
      game_state: game_state,
      include_loader: include_loader,
      game: game,
      input: GenieSpecSupport::InterpreterSpecFakes::FakeInput.new(input_lines, clock_ref),
      echo: ->(text) { echoes << text },
      hooks: hook_sink,
      launch: launch,
      mover: mover || ->(room) { moves << room },
      clock: clock_proc,
      queue: queue,
      lists: lists
    )
    release_queue(queue, clock_ref, game: game, hooks: hook_sink, launch: launch, echoes: echoes, lists: lists)
    { commands: game.commands, echoes: echoes, hooks: hooks, launches: launches, moves: moves, lists: lists }
  end

  # The `send` verb queues: after the run, release every queued command the way the
  # glue's CommandQueue::Worker does (RunQueueCommand through a global-scope runner), stepping
  # the fake clock past each delay.
  def release_queue(queue, clock_ref, game:, hooks:, launch:, echoes:, lists:)
    vars = Lich::Genie::Variables.new
    globals = Object.new.tap { |o| o.define_singleton_method(:key?) { |name| vars.global_key?(name) } }
    runner = Lich::Genie::TriggerRunner.new(vars: vars, eval: Lich::Genie::Eval.new(globals: globals), game: game, launch: launch,
                                            hooks: hooks, echo: ->(text) { echoes << text }, queue: queue, lists: lists)
    100.times do
      break if queue.empty?

      queue.drain(-> { Lich::Genie::CommandQueue::FREE }) { |action| runner.run_command(action) }
      clock_ref[0] += 0.01
    end
  end

  describe 'control flow, variables, expressions (no waits)' do
    it 'runs assignments, eval, math and a conditional' do
      source = <<~GENIE
        setvariable x 5
        eval y %x > 3
        echo x=%x y=%y
        math x add 10
        echo x=%x
        if %x = 15 then echo fifteen
        exit
      GENIE
      result = run_script(source)
      expect(result[:echoes]).to eq(['x=5 y=1', 'x=15', 'fifteen'])
    end

    it 'skips the body of a false block-if' do
      source = <<~GENIE
        setvariable hp 20
        if %hp > 50 then
        {
          echo healthy
        }
        echo done
        exit
      GENIE
      expect(run_script(source)[:echoes]).to eq(['done'])
    end
  end

  describe 'gosub / return' do
    it 'calls a subroutine and returns' do
      source = <<~GENIE
        put start
        gosub greet World
        put end
        exit
        greet:
        echo hello $1
        return
      GENIE
      result = run_script(source)
      expect(result[:commands]).to eq(%w[start end])
      expect(result[:echoes]).to eq(['hello World'])
    end
  end

  describe 'matchwait hunting loop' do
    it 'attacks on each kobold and stops after two' do
      source = <<~GENIE
        top:
        match found kobold
        match none nothing
        matchwait
        found:
        put attack
        counter add 1
        if %c >= 2 then goto done
        goto top
        none:
        goto top
        done:
        echo killed %c
        exit
      GENIE
      result = run_script(source, input_lines: ['a hungry kobold lurks', 'you wait', 'another kobold appears'])
      expect(result[:commands]).to eq(%w[attack attack])
      expect(result[:echoes]).to eq(['killed 2'])
    end
  end

  describe 'pause' do
    it 'resumes after the pause window elapses' do
      source = <<~GENIE
        put before
        pause 2
        put after
        exit
      GENIE
      expect(run_script(source)[:commands]).to eq(%w[before after])
    end
  end

  describe 'async actions' do
    it 'hijacks control to a label when a trigger fires during matchwait' do
      source = <<~GENIE
        action goto danger when you are bleeding
        match ok all clear
        matchwait
        danger:
        put flee
        exit
      GENIE
      result = run_script(source, input_lines: ['you are bleeding badly'])
      expect(result[:commands]).to eq(['flee'])
    end

    it 'stops firing a trigger after action remove (one-shot action pattern)' do
      source = <<~GENIE
        action var flag 1 when you feel woozy
        action remove you feel woozy
        match ok all clear
        matchwait 1
        echo flag is %flag
        exit
      GENIE
      # The removed action must NOT fire, so %flag stays undefined (literal).
      result = run_script(source, input_lines: ['you feel woozy suddenly'])
      expect(result[:echoes]).to eq(['flag is %flag'])
    end
  end

  describe 'class-scoped actions' do
    # Defines a class-scoped action that sets %hits when it fires, waits (so input can
    # trigger it), then echoes %hits. When the action is suppressed %hits stays literal.
    def watch_result(setup)
      source = <<~GENIE
        #{setup}
        match ok all clear
        matchwait 1
        echo hits=%hits
        exit
      GENIE
      run_script(source, input_lines: ['ping'])[:echoes]
    end

    it 'fires a class-scoped action while its class is on (the default)' do
      expect(watch_result('action (watch) var hits fired when ^ping')).to eq(['hits=fired'])
    end

    it 'does not fire after action (class) off' do
      expect(watch_result("action (watch) var hits fired when ^ping\naction (watch) off")).to eq(['hits=%hits'])
    end

    it 'starts inactive when defined while its class is already off' do
      expect(watch_result("action (watch) off\naction (watch) var hits fired when ^ping")).to eq(['hits=%hits'])
    end

    it 're-enables with action (class) on' do
      setup = "action (watch) var hits fired when ^ping\naction (watch) off\naction (watch) on"
      expect(watch_result(setup)).to eq(['hits=fired'])
    end

    it 'accepts on/off synonyms (false then 1)' do
      setup = "action (watch) var hits fired when ^ping\naction (watch) false\naction (watch) 1"
      expect(watch_result(setup)).to eq(['hits=fired'])
    end

    it 'leaves other classes unaffected when one is toggled' do
      source = <<~GENIE
        action (a) var ha yes when ^ping
        action (b) var hb yes when ^ping
        action (a) off
        match ok all clear
        matchwait 1
        echo a=%ha b=%hb
        exit
      GENIE
      expect(run_script(source, input_lines: ['ping'])[:echoes]).to eq(['a=%ha b=yes'])
    end

    it 'lets a firing action disable its own class (the mapper idiom)' do
      source = <<~GENIE
        action (loop) var last $1;action (loop) off when ^ping(\\d)
        match ok all clear
        matchwait 1
        echo last=%last
        exit
      GENIE
      # First ping fires (last=1) then turns the class off; the second must not fire.
      expect(run_script(source, input_lines: %w[ping1 ping2])[:echoes]).to eq(['last=1'])
    end
  end

  describe 'reserved game-state globals' do
    it 'resolves $globals from the injected game state' do
      source = <<~GENIE
        echo hp is $health at $roomname
        exit
      GENIE
      result = run_script(source, game_state: { 'health' => '75', 'roomname' => 'Town Square' })
      expect(result[:echoes]).to eq(['hp is 75 at Town Square'])
    end

    # EvalPut (Script.cs:3460-3467 R): put, and only put, sets %lastcommand -- for a
    # #command too; send/move leave it. Golden: genieflow t89_lastcommand.
    it 'sets %lastcommand on put only, including a #command, never on send or move' do
      source = <<~GENIE
        echo [%lastcommand]
        put look
        send smile
        move north
        echo [%lastcommand]
        put #var x 1
        echo [%lastcommand]
        put
        echo [%lastcommand]
        exit
      GENIE
      result = run_script(source, input_lines: [Lich::Genie::GameEvents::MOVE]) # the room desc ends the move
      expect(result[:echoes]).to eq(['[%lastcommand]', '[look]', '[#var x 1]', '[#var x 1]'])
      expect(result[:commands]).to eq(%w[look north smile]) # send queues: out on the next tick
    end

    it 'expands $time-style reserved specials through the @-pass and the spell timer via the game state' do
      capture = Lich::Genie::GameState.new
      reserved = Lich::Genie::ReservedState.new(game_state: capture)
      result = run_script("echo [$spelltime] [$spellpreptime] [$dayofyear]\nexit\n", game_state: reserved)
      expect(result[:echoes].first).to match(/\A\[0\] \[@spellpreptime@\] \[\d{1,3}\]\z/)
    end
  end

  describe 'include' do
    it 'loads a helper file and gosubs into its label across files' do
      source = <<~GENIE
        gosub greetlib Sun
        echo back
        exit
        include lib.cmd
      GENIE
      loader = ->(name) { name == 'lib.cmd' ? "greetlib:\necho hi $1\nreturn" : nil }
      result = run_script(source, include_loader: loader)
      expect(result[:echoes]).to eq(['hi Sun', 'back'])
    end
  end

  describe 'front-end hooks' do
    it 'emits a genieHook for a front-end bar command' do
      source = <<~GENIE
        put #highlight line red {a kobold}
        exit
      GENIE
      result = run_script(source)
      expect(result[:hooks]).to eq([['highlight', {
        'kind' => 'line', 'whole_row' => true, 'color' => 'red',
                                     'pattern' => 'a kobold', 'case_sensitive' => false,
                                     'sound' => '', 'class' => '', 'active' => true
      }]])
      expect(result[:commands]).to be_empty
    end

    it 'sets a global variable via #var and reads it back' do
      source = <<~GENIE
        put #var mode hunt
        echo mode is $mode
        exit
      GENIE
      expect(run_script(source)[:echoes]).to eq(['mode is hunt'])
    end

    it 'evaluates an inline #evalmath over a reserved var into a #var (corpus pattern)' do
      source = <<~GENIE
        put #var hpsnapshot #evalmath ($health + 5)
        echo snapshot is $hpsnapshot
        exit
      GENIE
      result = run_script(source, game_state: { 'health' => '75' })
      expect(result[:echoes]).to eq(['snapshot is 80'])
    end

    it 'sets classes and registers triggers in the session lists like a trigger-setup include' do
      source = <<~GENIE
        put #class recovery on
        put #trigger {^You are knocked out} {#send .recover} {recovery}
        put #class alertstart off
        exit
      GENIE
      result = run_script(source)
      expect(result[:lists].classes.entries).to eq([['alertstart', false], ['default', true], ['recovery', true]])
      expect(result[:lists].triggers.entries).to eq([['^You are knocked out', '^You are knocked out', '#send .recover', 'recovery', true]])
      expect(result[:hooks].map(&:first)).to eq(%w[class class]) # the front end's class list, per class event
      expect(result[:commands]).to be_empty
    end

    it 'aborts a pure-FE goto loop via the per-run script-timeout deadline' do
      # A goto loop that only emits hooks must be caught by the wall-clock deadline
      # (Genie iScriptTimeout, Script.cs:1819-1830 R). Clock advances 1s
      # per call so the 5s deadline trips deterministically without real waiting.
      ticking = [0.0]
      source = <<~GENIE
        spin:
        put #class churn on
        goto spin
      GENIE
      result = run_script(source, clock: -> { ticking[0] += 1.0 })
      expect(result[:commands]).to be_empty
      # PrintText of the timeout, then PrintTrace: "Trace follows:" and the entries (Script.cs:1822-1824 R)
      expect(result[:echoes].last(3)).to match([/\A\[Script timeout in test\.cmd\([23]\): Possible infinite loop\.\]\z/, 'Trace follows:',
                                                /\A\tpassing label spin \(1\)\n(\tgoto spin \(3\)\n)*\tgoto spin \(3\)\z/])
      # It emitted some class hooks before the deadline, then stopped (did not hang).
      expect(result[:hooks].map(&:first).uniq).to eq(['class'])
    end

    it 'does not trip the wall-clock deadline while a game send blocks on a long RT' do
      # Regression: LichGamePort#send_command calls waitrt? and BLOCKS for the whole
      # roundtime before sending. A 20s invoke / long barrage would then push the next
      # runaway check past the 5s deadline and falsely kill the script mid-combat.
      # Model that block by advancing the clock 6s (> the 5s deadline) inside each send;
      # all three sequential sends must still go through, with no timeout.
      clock_ref = [0.0]
      sent = []
      rt_game = Object.new.tap do |g|
        g.define_singleton_method(:send_command) do |text|
          sent << text
          clock_ref[0] += 6.0 # simulate a 6s roundtime block inside the send (waitrt?)
        end
      end
      echoes = []
      no_hooks = Object.new.tap { |o| o.define_singleton_method(:emit) { |_op, _p| } }
      source = <<~GENIE
        put invoke my sword
        put retreat
        put sheath my sword
        exit
      GENIE
      Lich::Genie::Engine.run(
        source, name: 'test', game: rt_game, input: GenieSpecSupport::InterpreterSpecFakes::FakeInput.new([], clock_ref),
        echo: ->(text) { echoes << text }, hooks: no_hooks,
        launch: ->(_n, _a) {}, mover: ->(_r) {}, clock: -> { clock_ref[0] }
      )
      expect(sent).to eq(['invoke my sword', 'retreat', 'sheath my sword'])
      expect(echoes.join).not_to match(/Possible infinite loop/)
    end

    it 'sends every command of a combat loop that waits each cycle' do
      # 40 attacks paced by a 0.1s pause must all fire (each wait resumes into a fresh
      # run_rows, which restarts the script-timeout deadline, Script.cs:1819-1830 R).
      source = <<~GENIE
        setvariable i 0
        top:
        put attack
        math i add 1
        pause 0.1
        if %i < 40 then goto top
        exit
      GENIE
      result = run_script(source)
      expect(result[:commands].length).to eq(40)
      expect(result[:commands].uniq).to eq(['attack'])
      expect(result[:echoes].join).not_to match(/infinite loop/i)
    end

    # Remix SendText keeps no send history (Script.cs:4438-4441 R); the only runaway guard
    # is the per-RunScript wall-clock scripttimeout (Script.cs:1819-1830 R). The upstream-only
    # "10 identical / 30 total sends in 10 s" guard (4.5.0.3) is gone. Flow oracle t13 (Remix
    # sends 15 x look and echoes "done 15").
    describe 'no send-history loop guard (Remix parity)' do
      it 'runs a wait-less loop of 15 identical sends to completion' do
        source = <<~GENIE
          start:
          put look
          counter add 1
          if %c < 15 then goto start
          echo done %c
        GENIE
        result = run_script(source)
        expect(result[:commands]).to eq(['look'] * 15)
        expect(result[:echoes]).to eq(['done 15'])
      end

      it 'runs a wait-less burst of 60 distinct sends to completion' do
        source = <<~GENIE
          start:
          counter add 1
          put glance %c
          if %c < 60 then goto start
          echo done %c
        GENIE
        result = run_script(source)
        expect(result[:commands]).to eq((1..60).map { |n| "glance #{n}" })
        expect(result[:echoes]).to eq(['done 60'])
      end

      it 'aborts an endless wait-less send loop through the script timeout, not a hang' do
        # Remix: the loop never yields, so iScriptTimeout fires (Script.cs:1819-1830 R).
        # Ours must too: only time BLOCKED inside send_command (a roundtime wait) is excluded
        # from the deadline, the loop's own time still counts. The clock moves 0.25 s per read;
        # the game refuses to go past 10_000 sends so a regression fails instead of hanging.
        clock_ref = [0.0]
        sent = []
        capped_game = Object.new.tap do |g|
          g.define_singleton_method(:send_command) do |text|
            raise 'runaway: script was never stopped' if sent.length >= 10_000

            sent << text
          end
        end
        echoes = []
        no_hooks = Object.new.tap { |o| o.define_singleton_method(:emit) { |_op, _p| } }
        source = <<~GENIE
          start:
          put look
          goto start
        GENIE
        Lich::Genie::Engine.run(
          source, name: 'test', game: capped_game, input: GenieSpecSupport::InterpreterSpecFakes::FakeInput.new([], clock_ref),
          echo: ->(text) { echoes << text }, hooks: no_hooks,
          launch: ->(_n, _a) {}, mover: ->(_r) {}, clock: -> { clock_ref[0] += 0.25 }
        )
        expect(sent).not_to be_empty
        expect(sent.uniq).to eq(['look'])
        expect(sent.length).to be < 100
        expect(echoes[-3]).to match(/\A\[Script timeout in test\.cmd\([1-3]\): Possible infinite loop\.\]\z/)
        expect(echoes[-2]).to eq('Trace follows:')
      end

      it 'excludes only the time blocked inside send_command from the deadline' do
        # Each send blocks 6 s (> the 5 s deadline) and the rows between sends cost nothing,
        # so the script must finish; this is the RT exclusion kept from the old reset-on-send.
        clock_ref = [0.0]
        sent = []
        rt_game = Object.new.tap do |g|
          g.define_singleton_method(:send_command) do |text|
            sent << text
            clock_ref[0] += 6.0
          end
        end
        echoes = []
        no_hooks = Object.new.tap { |o| o.define_singleton_method(:emit) { |_op, _p| } }
        source = <<~GENIE
          start:
          put advance
          counter add 1
          if %c < 12 then goto start
          echo done %c
        GENIE
        Lich::Genie::Engine.run(
          source, name: 'test', game: rt_game, input: GenieSpecSupport::InterpreterSpecFakes::FakeInput.new([], clock_ref),
          echo: ->(text) { echoes << text }, hooks: no_hooks,
          launch: ->(_n, _a) {}, mover: ->(_r) {}, clock: -> { clock_ref[0] }
        )
        expect(sent).to eq(['advance'] * 12)
        expect(echoes).to eq(['done 12'])
      end
    end

    it 'keeps running after math/counter divide 0 and mod 0 (flow oracle t56)' do
      # Remix: divide by 0 leaves the value (Utility.cs:928 R); mod 0 is C# NaN (Utility.cs:932-946 R).
      source = <<~GENIE
        var x 10
        math x divide 0
        var y 7
        math y mod 0
        counter set 9
        counter mod -1
        echo x=%x y=%y c=%c
        math y add 1
        echo y=%y
      GENIE
      result = run_script(source)
      expect(result[:echoes]).to eq(['x=10 y=NaN c=NaN', 'y=NaN'])
    end

    it 'launches another script with put .name (Genie ScriptChar), not a game command' do
      source = <<~GENIE
        put .helper foo bar
        exit
      GENIE
      result = run_script(source)
      expect(result[:launches]).to eq([['helper', 'foo bar']])
      expect(result[:commands]).to be_empty
    end

    it 'ends the launched name at a depth-0 { and lower-cases it, like ParseArgs token 0 (t66)' do
      result = run_script("put ._PC{a_b} c\nput .x{y}{z} \"q r\"\nexit")
      expect(result[:launches]).to eq([['_pc', '{a_b} c'], ['x', '{y}{z} "q r"']])
      expect(result[:launches].map { |n, a| Lich::Genie::ScriptArgs.parse_launch(n, a) })
        .to eq([['a b', 'c'], ['y', 'z', 'q r']])
      expect(result[:commands]).to be_empty
    end

    it 'launches a script with send .name and with no args' do
      source = <<~GENIE
        send .setup
        exit
      GENIE
      result = run_script(source)
      expect(result[:launches]).to eq([['setup', '']])
      expect(result[:commands]).to be_empty
    end

    it "launches a script held in a variable (a tester's `put \$looptask` = `.sc`)" do
      # $looptask = ".sc"; a guarded `put $looptask` must (a) evaluate the guard
      # true and (b) launch the .sc script, not send ".sc" to the game.
      source = <<~GENIE
        $looptask = .sc
        if $looptask != 0 then put $looptask
        exit
      GENIE
      result = run_script(source)
      expect(result[:launches]).to eq([['sc', '']])
      expect(result[:commands]).to be_empty
    end

    it 'still sends ordinary commands to the game' do
      source = <<~GENIE
        put attack kobold
        exit
      GENIE
      result = run_script(source)
      expect(result[:commands]).to eq(['attack kobold'])
      expect(result[:launches]).to be_empty
    end

    it 'routes #commands issued via send and do (not only put) through the queue, like Genie ParseCommand' do
      # send #class / do #class are queued (EvalSend / EvalDo -> AddToQueue, FormMain.cs:6826-6845
      # R) and the release runs them through ParseCommand: they route, NOT go to the game as
      # literal text. Tester's #class toggles rely on this. The echo runs before the release.
      source = <<~GENIE
        send #class combat on
        do #class loot off
        echo queued
        exit
      GENIE
      result = run_script(source)
      expect(result[:lists].classes.entries).to eq([['combat', true], ['default', true], ['loot', false]])
      expect(result[:echoes]).to eq(['queued'])
      expect(result[:commands]).to be_empty # nothing leaked to the game
    end

    it 'launches a script via send .name and do .name, both when the queue releases them, in order' do
      result = run_script("send .helper\ndo .other\nexit")
      expect(result[:launches]).to eq([['helper', ''], ['other', '']])
      expect(result[:commands]).to be_empty
    end

    it 'routes #goto <room> to the mover, not the game' do
      source = <<~GENIE
        put #goto 93
        exit
      GENIE
      result = run_script(source)
      expect(result[:moves]).to eq(['93'])
      expect(result[:commands]).to be_empty
    end

    it 'drives the automove pattern: #goto then matchwait on the arrival line' do
      # Mirrors mastercraft automove: set matches, #goto, matchwait for the mapper
      # result. The mover walks and (in Lich) injects YOU HAVE ARRIVED downstream;
      # here we pre-queue that line to stand in for the injected shim message.
      source = <<~GENIE
        top:
        match arrived YOU HAVE ARRIVED
        match failed YOU HAVE FAILED
        put #goto 93
        matchwait
        arrived:
        echo made it to %c
        exit
        failed:
        echo lost
        exit
      GENIE
      moves = []
      result = run_script(source, input_lines: ['YOU HAVE ARRIVED'], mover: ->(r) { moves << r })
      expect(moves).to eq(['93'])
      expect(result[:echoes]).to eq(['made it to %c'])
    end

    # ParseAction looks a row's verb up with GetFunctionType (Script.cs:2154, 4090-4317 R):
    # `#class` is no verb, so a bare `#command` row in an action body is a silent no-op; only
    # `put #class ...` reaches the command layer.
    it 'ignores a bare #command row in an action body but routes put #command' do
      source = <<~GENIE
        action #class panic on;put #class calm on when you are bleeding
        match ok all clear
        matchwait 1
        exit
      GENIE
      result = run_script(source, input_lines: ['you are bleeding badly'])
      expect(result[:lists].classes.entries).to eq([['calm', true], ['default', true]])
    end
  end

  describe 'waiteval + richer action bodies' do
    it 'waiteval blocks until its condition becomes true (re-evaluated per line)' do
      # A per-line action bumps %n; waiteval was a SILENT no-op before, racing past.
      source = <<~GENIE
        %n = 0
        action math n add 1 when .
        waiteval (%n > 2)
        echo done %n
        exit
      GENIE
      result = run_script(source, input_lines: %w[a b c d])
      expect(result[:echoes]).to eq(['done 3'])
    end

    it 'runs math/if inside action bodies instead of sending them to the game' do
      source = <<~GENIE
        %n = 0
        action if (1 = 1) then math n add 5 when ^bump
        match done ok
        matchwait 1
        done:
        echo n=%n
        exit
      GENIE
      result = run_script(source, input_lines: %w[bump ok])
      expect(result[:echoes]).to eq(['n=5'])
      expect(result[:commands]).to be_empty # math/if handled locally, nothing leaked to the game
    end

    # $scriptlist carries extension-less names (Genie's GetFileNameWithoutExtension), so a
    # `foo\.cmd` pattern never matches it -- in Genie too. This locks that parity quirk and
    # guards against a well-meaning "fix" that adds .cmd to the list. A travel script's
    # `waiteval !matchre("$scriptlist","automapper\.cmd")` is therefore true at once, but a
    # waiteval only resumes on a variable change it names (Script.cs:1407-1424 R): Remix's
    # tick-end "scriptlist" change after a script starts, stops or is paused (FormMain.cs:
    # 4516-4541 R). A game line alone never resumes it.
    it 'waiteval reads $scriptlist, whose extension-less names a .cmd pattern cannot match' do
      source = <<~'GENIE'
        waiteval !matchre("$scriptlist", "automapper\.cmd")
        echo done
        exit
      GENIE
      change = Lich::Genie::VariableDispatch::Change.new('scriptlist', 0)
      result = run_script(source, input_lines: ['tick', change], game_state: { 'scriptlist' => 'automapper|hunt' })
      expect(result[:echoes]).to eq(['done'])
      expect { run_script(source, input_lines: ['tick'], game_state: { 'scriptlist' => 'automapper|hunt' }) }
        .to raise_error(/input exhausted/)
    end
  end

  # Runtime crash hardening surfaced by the corpus execute-sweep: three unguarded
  # sites that would raise on a live game line. Genie guards all three (Script.cs).
  describe 'match/waitfor robustness (runtime crash hardening)' do
    it 'aborts gracefully when a match targets an undefined label' do
      source = "match hit a goblin\nmatchwait\nexit\n"
      result = run_script(source, input_lines: ['you see a goblin here'])
      expect(result[:echoes].join).to match(/Unknown label from MATCH command: hit/)
    end

    # Remix: ValidateRegExp false -> PrintError + AbortOnScriptError (Script.cs:2676-2684,
    # 2753-2760 R). The message format itself is PrintError's.
    it 'stops with Remix\'s message on a malformed matchre pattern instead of crashing' do
      source = "matchre done (unbalanced\nmatchwait 1\ndone:\necho ok\nexit\n"
      result = run_script(source, input_lines: ['some line'])
      expect(result[:echoes]).to eq(['[Script error in test.cmd(1): Invalid RegExp in matchre: done (unbalanced]', '[Script aborted! (Run time: 0.00 seconds): test.cmd]'])
    end

    it 'stops with Remix\'s message on a malformed waitforre pattern instead of crashing' do
      source = "waitforre (nope\nexit\n"
      result = run_script(source, input_lines: ['a line'])
      expect(result[:echoes]).to eq(['[Script error in test.cmd(1): Invalid RegExp in waitforre: (nope]', '[Script aborted! (Run time: 0.00 seconds): test.cmd]'])
    end
  end

  describe 'script arguments + shift (Remix LoadFile/EvalShift)' do
    it 'seeds %1..%9, %0 and %argcount with zero args; top-level $-args are empty, $argcount -1' do
      source = <<~GENIE
        echo [%1] [%9] [%0] [%argcount] [$0] [$1] [$argcount]
        if ("%1" = "") then echo one-empty
        else echo one-set
        if_1 echo if1
      GENIE
      result = run_script(source)
      expect(result[:echoes]).to eq(['[] [] [] [0] [] [] [-1]', 'one-empty'])
    end

    it 'keeps launch args out of the $-arg list (flow t61 sends on %1, not $1)' do
      source = <<~GENIE
        if ("%1" != "") then send pour my blue vial on %1
        else send pour my blue vial on Tester
        echo top=[$1] argc=$argcount
      GENIE
      result = run_script(source, args: ['Bob'])
      expect(result[:commands]).to eq(['pour my blue vial on Bob'])
      expect(result[:echoes]).to eq(['top=[] argc=-1'])
    end

    it 'shifts the %-locals, not the gosub frame $-args' do
      source = <<~GENIE
        gosub sub a b
        echo top argc=%argcount 1=[%1] 0=[%0]
        exit
        sub:
        shift
        echo sub $1 $2 argc=$argcount local=[%1]
        return
      GENIE
      result = run_script(source, args: %w[x y z])
      expect(result[:echoes]).to eq(['sub a b argc=2 local=[y]', 'top argc=2 1=[y] 0=[y z]'])
    end

    it 'shifts the %-locals from an action body (put.cmd move loop pattern)' do
      source = <<~GENIE
        action shift when ^go now$
        waitfor done
        echo argc=%argcount 1=[%1] 0=[%0] dargc=$argcount
      GENIE
      result = run_script(source, args: %w[a b c], input_lines: ['go now', 'go now', 'done'])
      expect(result[:echoes]).to eq(['argc=1 1=[c] 0=[c] dargc=-1'])
    end

    it 'runs put.cmd: `.put my sword` drops the leading "my" via shift' do
      source = <<~GENIE
        If ("%1" = "my") then goto Shift
        BagCheck:
        send put my %0 in my backpack
        exit
        Shift:
        shift
        goto BagCheck
      GENIE
      result = run_script(source, args: %w[my sword])
      expect(result[:commands]).to eq(['put my sword in my backpack'])
    end

    it 'launches a child with the expanded %0 (the child re-parses it)' do
      source = <<~GENIE
        put .child %0
        put .child %3
      GENIE
      result = run_script(source, args: ['p x', 'q'])
      expect(result[:launches]).to eq([['child', 'p x q'], ['child', '']])
    end

    it 'stops the script on a shift fault after a script-assigned bad %argcount' do
      source = <<~GENIE
        var argcount abc
        shift
        echo NOT REACHED
      GENIE
      result = run_script(source, args: %w[a])
      expect(result[:echoes].length).to eq(1)
      expect(result[:echoes].first).to match(/\A\[Conversion from string "abc".*not valid\.\]\z/)
    end

    # A shift fault stops the script with one error line. Remix itself never
    # gets further (GenieError <-> Game.HandleGenieException recursion, Game.cs:3291-3294 R),
    # so nothing after the fault -- not the rest of the action's ';' list, not a later
    # matching action -- may reach the game. (`go$` is a different key that sorts after
    # `^go$`: the same trigger twice would just replace the first action.)
    it 'sends nothing after an in-action shift fault (oversize %argcount)' do
      source = <<~GENIE
        setvariable argcount 12
        action shift;put foo;echo NOT REACHED when ^go$
        action put bar when go$
        waitfor done
        echo NOT REACHED EITHER
      GENIE
      result = run_script(source, args: %w[a b c], input_lines: %w[go done])
      expect(result[:commands]).to be_empty
      expect(result[:echoes].length).to eq(1)
      expect(result[:echoes].first).to start_with('[')
    end

    it 'sends nothing after an in-action shift fault (unconvertible %argcount, via if-then)' do
      source = <<~GENIE
        var argcount abc
        action if (1 = 1) then shift;put foo when ^go$
        waitfor done
      GENIE
      result = run_script(source, args: %w[a], input_lines: %w[go done])
      expect(result[:commands]).to be_empty
      expect(result[:echoes]).to contain_exactly(match(/\A\[Conversion from string "abc".*not valid\.\]\z/))
    end

    it 'stays stopped when the faulting line also satisfies the pending waitfor' do
      source = <<~GENIE
        var argcount 12
        action shift when ^go$
        waitfor go
        put NOT REACHED
      GENIE
      result = run_script(source, args: %w[a], input_lines: %w[go])
      expect(result[:commands]).to be_empty
      expect(result[:echoes]).to eq(['[Object reference not set to an instance of an object.]'])
    end

    it 'stays stopped when the faulting line also satisfies the pending matchwait' do
      source = <<~GENIE
        var argcount 12
        action shift when ^go$
        match Hit go
        matchwait
        Hit:
        put NOT REACHED
      GENIE
      result = run_script(source, args: %w[a], input_lines: %w[go])
      expect(result[:commands]).to be_empty
      expect(result[:echoes].length).to eq(1)
    end

    it 'keeps running the action list after a shift that does not fault' do
      source = <<~GENIE
        action shift;put foo %1 when ^go$
        waitfor done
      GENIE
      result = run_script(source, args: %w[a b], input_lines: %w[go done])
      expect(result[:commands]).to eq(['foo b'])
    end
  end

  # Every put/move/do row goes through Command.ParseCommand as a top-level,
  # un-awaited Task (Script_EventSendText, FormMain.cs:6812-6823 R); the `send` verb queues
  # (FormMain.cs:6826-6845 R). Goldens: flow t127, t134, t136.
  describe 'ParseCommand and the send queue' do
    it 'a put row starting with # sends none of its plain rows (bSendToGame false; a corpus row shape)' do
      source = <<~GENIE
        put #var flagready 0;put #class alertstart off;put #class alertend off
        put #echo hi;look
        put look;#var q 1
        echo fr=$flagready q=$q
        exit
      GENIE
      result = run_script(source)
      expect(result[:commands]).to eq(['look'])
      expect(result[:hooks]).to be_empty # the `put #class` rows are text, never run
      expect(result[:echoes]).to eq(['hi', 'fr=0 q=1'])
    end

    it 'ends a faulting put row quietly and runs on (also from an action body)' do
      source = <<~GENIE
        action put #var {'} {206};put after-fault;echo action-goes-on when ^Fault now
        put #var {'} {206};put never
        echo top-goes-on
        waitfor done
        echo finished
      GENIE
      result = run_script(source, input_lines: ['Fault now', 'done'])
      expect(result[:echoes]).to eq(%w[top-goes-on action-goes-on finished])
      expect(result[:commands]).to eq(['after-fault'])
    end

    it 'queues send with an int delay and the rest trimmed; a delay that is not an Int32 is a host error' do
      host = []
      queue = Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) })
      source = "send 2  look\nsend 0.5 half\nsend 1. x\nsend .5 y\nsend 99999999999 big\nsend . dot\nsend  spaced\nsend 3\nexit\n"
      Lich::Genie::Engine.run(source, queue: queue, host_error: ->(section, msg) { host << [section, msg] }, echo: ->(_t) {})
      expect(queue.items.map { |i| [i.delay, i.action, i.wait_rt] })
        .to eq([[2, 'look', true], [0, '. dot', true], [0, ' spaced', true], [3, '', true]])
      expect(host).to eq([['SendText', "The input string '0.5' was not in a correct format."],
                          ['SendText', "The input string '1.' was not in a correct format."],
                          ['SendText', "The input string '.5' was not in a correct format."],
                          ['SendText', 'Value was either too large or too small for an Int32.']])
    end

    it 'expands $globals into the queued text and echoes a host error by default' do
      echoes = []
      queue = Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) })
      Lich::Genie::Engine.run("$tgt = goblin\nsend attack $tgt \\$tgt\nsend 0.5 x\nexit\n", queue: queue, echo: ->(t) { echoes << t })
      expect(queue.items.map(&:action)).to eq(['attack goblin goblin']) # ParseVariables, then ParseGlobalVars again
      expect(echoes).to eq(["[SendText: The input string '0.5' was not in a correct format.]"])
    end

    # The script's handle rides with every item it queues (the `send`
    # verb and the router's #send / #queue / - quick send) so the host sends it as this script.
    it 'stores queue_owner with the items it queues (send verb, #send, #queue, - quick send)' do
      queue = Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) })
      source = "send 1 verb\nput #send 1 hash;#queue 1 que;-quick\nexit\n"
      Lich::Genie::Engine.run(source, queue: queue, queue_owner: :me, echo: ->(_t) {})
      expect(queue.items.map { |i| [i.action, i.owner] })
        .to eq([['verb', :me], ['hash', :me], ['que', :me], ['quick', :me]])
    end

    # A callable queue is read at each use, so a script running across a
    # hot reload (which rebuilds Lich::Genie.command_queue) fills the live queue.
    it 'queues into the current queue when given a callable' do
      first = Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) })
      second = Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) })
      current = [first]
      source = "send one\nput #var swap 1\nsend two\nput #send three\nexit\n"
      vars = Lich::Genie::Variables.new
      swap = ->(_name) { current[0] = second }
      Lich::Genie::Engine.run(source, queue: -> { current[0] }, variables: vars, var_broadcast: swap, echo: ->(_t) {})
      expect([first.items.map(&:action), second.items.map(&:action)]).to eq([['one'], %w[two three]])
    end

    # Remix gates a script's RESUMES on roundtime, never its sends (EvalSend queues and
    # returns, Script.cs:3469-3475 R). The v0.17.1 stop-gap that blocked a script row's `send` in
    # the rt_wait port is gone: the send queues at once, the next row runs, an action body's
    # send queues the same way.
    it 'queues a script row send at once and runs on, and an action body send the same way' do
      events = []
      queue = Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) })
      queue.define_singleton_method(:add) { |_d, action, **_kw| events << [:queued, action] }
      source = "action send from-action when ^go\nsend look\necho after\nwaitfor go\nexit\n"
      clock = [0.0]
      Lich::Genie::Engine.run(source, queue: queue, input: GenieSpecSupport::InterpreterSpecFakes::FakeInput.new(['go'], clock), clock: -> { clock[0] },
                                      echo: ->(t) { events << [:echo, t] })
      expect(events).to eq([[:queued, 'look'], [:echo, 'after'], [:queued, 'from-action']])
    end

    it 'has no rt_wait port any more (the stop-gap is deleted, not merely unused)' do
      expect { Lich::Genie::Engine.build("echo x\n", rt_wait: -> {}) }.to raise_error(ArgumentError, /rt_wait/)
    end

    it 'splits an action body on the configured separator char (Script.cs:2135 R; flow t138)' do
      capture = Lich::Genie::GameState.new.tap { |state| state.apply_setting('separatorchar', '|') }
      source = <<~GENIE
        action put a;b|put c when ^Act now
        waitfor done
        exit
      GENIE
      result = run_script(source, input_lines: ['Act now', 'done'], game_state: Lich::Genie::ReservedState.new(game_state: capture))
      expect(result[:commands]).to eq(['a;b', 'c'])
    end
  end
end
