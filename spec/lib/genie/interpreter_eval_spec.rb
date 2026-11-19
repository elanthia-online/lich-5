# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/genie'

# How the interpreter drives the literal Eval.cs / MathEval.cs ports, on the REAL
# interpreter, headless. Remix references:
#   EvalIfStatement Script.cs:3560-3585 R (cut at the first " then"; the ArgList binding)
#   EvalWhileStatement Script.cs:3587-3590 R (the whole argument)
#   EvalEval Script.cs:3254-3276 R, EvalEvalMath Script.cs:3220-3252 R
#   CurrentLine.ArgList Script.cs:85-98 R; Eval.cs:48, 877 R (Clear on every evaluation)
#   RunScript / TriggerParse catches Script.cs:1306-1309, 1885-1888 R (GenieError; ours: one error line)
#   Command's own m_oEval Command.cs:210 R
RSpec.describe Lich::Genie::Interpreter do
  def run(source, lines: [], game_state: nil)
    clock = [0.0]
    input = GenieSpecSupport::TimedInput.new(lines, clock: clock, gap: 0.0)
    echoes = []
    sends = []
    game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |t| sends << t } }
    interp = Lich::Genie::Engine.build(source, name: 't', game: game, input: input, game_state: game_state,
                                               echo: ->(t) { echoes << t }, clock: -> { clock[0] })
    interp.run
    { echoes: echoes, sends: sends, interp: interp }
  end

  describe 'the $-args bound to Eval\'s result list' do
    it 'shows a matched if its captures, then loses them to the next evaluation' do
      src = <<~'GENIE'
        if matchre("a b", "(\w) (\w)") then echo X [$1] [$2]
        echo A1 [$1] [$2]
        if 1 = 1 then echo Y [$1] [$2]
        echo A2 [$1] [$2]
      GENIE
      expect(run(src)[:echoes]).to eq(['X [a] [b]', 'A1 [a] [b]', 'Y [] []', 'A2 [] []'])
    end

    it 'empties a gosub caller\'s captures from inside the callee, and keeps the frame bound after return' do
      src = <<~'GENIE'
        eval q matchre("c d", "(\w) (\w)")
        gosub SUB x y
        echo B1 [$1] [$2]
        exit
        SUB:
        echo S0 [$1] [$2]
        eval z 1
        echo S1 [$1] [$2]
        return
      GENIE
      # The callee's own list is untouched (its `eval z 1` matched nothing, so no binding); the
      # caller's list IS Eval's, which that evaluation cleared.
      expect(run(src)[:echoes]).to eq(['S0 [x] [y]', 'S1 [x] [y]', 'B1 [] []'])
    end

    it 'writes a matchwait capture into the bound list, which the next if clears' do
      src = <<~'GENIE'
        if matchre("a", "(a)") then echo X [$1]
        matchre M (\w+) here
        matchwait 2
        M:
        echo M1 [$1]
        if 1 = 1 then echo M2 [$1]
        echo M3 [$1]
      GENIE
      expect(run(src, lines: ['foo here'])[:echoes]).to eq(['X [a]', 'M1 [foo]', 'M2 []', 'M3 []'])
    end

    it 'leaves the $-args alone when nothing matched' do
      src = <<~'GENIE'
        gosub SUB p q
        exit
        SUB:
        if matchre("a", "(z)") then echo no
        if 1 = 1 then echo S [$1] [$2]
        return
      GENIE
      expect(run(src)[:echoes]).to eq(['S [p] [q]'])
    end

    it 'never lets a #eval / #if (Command\'s own Eval) clear the script\'s captures' do
      src = <<~'GENIE'
        if matchre("a b", "(\w) (\w)") then put #var c #eval 1 = 1
        put #if {2 = 2} {#var d 1}
        echo C [$1] [$2] $c $d
      GENIE
      expect(run(src)[:echoes]).to eq(['C [a] [b] 1 1'])
    end
  end

  describe 'conditions' do
    # Remix cuts the SUBSTITUTED condition at its first " then".
    it 'cuts an if condition at the first " then" of the substituted text' do
      src = <<~GENIE
        var t 0 then (1)
        if %t then echo NOT-CUT
        var u 1 then 0
        if %u then echo CUT
      GENIE
      expect(run(src)[:echoes]).to eq(['CUT'])
    end

    it 'hands while its whole argument, " do" included' do
      src = <<~GENIE
        var n 5
        while %n > do echo NO
        while %n do echo YES
      GENIE
      # `5 > do` compares 5 with the word "do" (false); `5 do` holds the number 5 (true).
      expect(run(src)[:echoes]).to eq(['YES'])
    end
  end

  describe 'eval / evalmath' do
    it 'stores the Remix value of an eval / evalmath (literal ports)' do
      src = <<~GENIE
        var x 1
        eval r %xx = 1
        evalmath m 1+1 = 2
        evalmath z 2 & 3
        echo %r %m %z
      GENIE
      expect(run(src)[:echoes]).to eq(['1 2 0'])
    end

    it 'reports a failing evalmath and sets the variable to 0' do
      result = run("var em 5\nevalmath em (1 +\necho em=%em\n")
      expect(result[:echoes]).to eq(['[Script error in t.cmd: Invalid expression: (1 +. Local Variable em has been set to 0.]', 'em=0'])
    end

    it 'does nothing for an eval / evalmath without a variable name' do
      result = run("eval\nevalmath\necho done\n")
      expect(result[:echoes]).to eq(['done'])
      expect(result[:interp].instance_variable_get(:@vars).local_get('')).to be_nil
    end
  end

  # EvalRandom (Script.cs:2809, 3107-3120 R): min = the first word, max =
  # the word after it ("" -> "1" / "10"), each Utility.StringToInteger (<= 0 or not an Int32 ->
  # -1, Utility.cs:682-704 R), then Random.Next(min, max + 1) (Utility.cs:251-255 R; Int32
  # arithmetic), which throws when min > max + 1. The deterministic rows are genieflow's
  # (2026-10-20); a throw stack-overflows Remix (ours stops with the .NET message).
  describe 'random (EvalRandom)' do
    def draws(args, times = 300)
      Array.new(times) { run("random #{args}\necho %r\n")[:echoes].first }.uniq.sort_by(&:to_i)
    end

    it 'gives Remix\'s value wherever Random.Next has one choice' do
      src = "random 3 3\necho %r\nrandom 0, 0\necho %r\nrandom +2 +2\necho %r\nrandom -1 -1\necho %r\n" \
            "random 2 1\necho %r\nrandom 0 -5\necho %r\nrandom 4 4 junk\necho %r\n"
      expect(run(src)[:echoes]).to eq(%w[3 -1 2 -1 2 -1 4])
    end

    it 'draws from min..max with Remix\'s defaults and -1 for every unparsable bound' do
      expect(draws('')).to eq(%w[1 2 3 4 5 6 7 8 9 10])
      expect(draws('8')).to eq(%w[8 9 10])
      expect(draws('0, 2')).to eq(%w[-1 0 1 2])
      expect(draws('2.0 1')).to eq(%w[-1 0 1])
    end

    it 'stops the script where Random.Next throws (min > max + 1, Int32.MaxValue + 1 wrapping)' do
      swapped = "['minValue' cannot be greater than maxValue. (Parameter 'minValue')]"
      ['5 1', '1 0', '2147483647 2147483647'].each do |args|
        expect(run("random #{args}\necho NOT\n")[:echoes]).to eq([swapped]), args
      end
    end
  end

  # Remix's GenieError would re-raise without end; ours prints the .NET message
  # once and stops the script.
  describe 'evaluator faults' do
    start_index = "[startIndex cannot be larger than length of string. (Parameter 'startIndex')]"

    it 'stops the script at a fault in an eval row' do
      expect(run("echo one\neval r substr(\"x\", 5, 3)\necho NOT\n")[:echoes]).to eq(['one', start_index])
    end

    it 'stops the script at a fault in an if / while condition' do
      expect(run("if element(\"a\", x) then echo no\necho NOT\n")[:echoes])
        .to eq(["[The input string 'x' was not in a correct format.]"])
      expect(run("while count(\"a\", \"\") do echo no\necho NOT\n")[:echoes])
        .to eq(['[count() with an empty search text never returns (Remix loops forever)]'])
    end

    it 'stops the script at a fault in a text action body (TriggerParse catch)' do
      src = "action if substr(\"x\", 5, 3) = 1 then echo no when ^go\nwaitfor done\necho NOT\n"
      expect(run(src, lines: %w[go done])[:echoes]).to eq([start_index])
    end

    it 'stops the script at a fault in an eval action checked for its own local set' do
      src = "action echo A when eval substr(\"%q\", 5, 3)\nvar q x\necho NOT\n"
      expect(run(src)[:echoes]).to eq([start_index])
    end

    # The matchwait arm sets %lastlabel and runs TriggerVariableChanged
    # inside TickScript, whose catch is the GenieError (Script.cs:1608-1609, 1660-1664 R) -- not
    # inside a row, so the fault must not escape Interpreter#run.
    it 'stops the script at a fault in an eval action checked for a matchwait\'s %lastlabel (TickScript catch)' do
      src = <<~'GENIE'
        action echo fired when eval matchre("%lastlabel", "(")
        matchre M here
        matchwait 2
        M:
        echo NOT
      GENIE
      result = nil
      expect { result = run(src, lines: ['foo here']) }.not_to raise_error
      expect(result[:echoes].length).to eq(1)
      expect(result[:echoes].first).to start_with("[Invalid pattern '(':")
      expect(result[:interp].instance_variable_get(:@state)).to eq(:finished)
    end
  end

  # EvalDoubleTime's milliseconds go to DateTime.Now.AddMilliseconds in
  # EvalPauseScript / EvalDelayScript / EvalWait / EvalMatchWait (Script.cs:3339, 3372, 3378,
  # 3387 R), which throws past MaxMillis or past year 9999 -- a GenieError in RunScript /
  # TriggerParse (ours: one error line, the script stops). An Infinity (`1/0` since
  # string_to_double reads U+221E) must never reach Lich's input buffer: LimitedArray#wait_shift
  # hands it to ConditionVariable#wait, which raises RangeError out of Interpreter#run.
  describe 'timed waits past DateTime.AddMilliseconds' do
    out_of_range = "[Value to add was out of range. (Parameter 'value')]"
    unrepresentable = "[The added or subtracted value results in an un-representable DateTime. (Parameter 'value')]"

    # The interpreter on Lich's own input buffer and a wall clock, on a thread of its own:
    # returns the echoes once #run returns (re-raising whatever escaped it).
    def run_on_lich_buffer(source, lines: [])
      buffer = Lich::Common::LimitedArray.new
      buffer.push(*lines) unless lines.empty?
      input = Object.new
      input.define_singleton_method(:next_line) { |timeout: nil| buffer.wait_shift(timeout) }
      echoes = []
      game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |_t| nil } }
      interp = Lich::Genie::Engine.build(source, name: 't', game: game, input: input, echo: ->(t) { echoes << t },
                                                 clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      worker = Thread.new { interp.run }
      worker.report_on_exception = false
      unless worker.join(5)
        worker.kill
        raise "script still waiting: #{echoes.inspect}"
      end
      worker.value
      echoes
    end

    %w[pause delay wait matchwait].each do |verb|
      it "stops `#{verb}` on an infinite time with the AddMilliseconds message, no RangeError" do
        src = "evalmath r 1/0\nmatch done xyz\n#{verb} %r\necho NOT\ndone:\necho NOT\n"
        expect(run_on_lich_buffer(src, lines: ['xyz'])).to eq([out_of_range])
      end
    end

    it 'stops at MaxMillis + 1 ms (out of range) and at MaxMillis (past year 9999)' do
      expect(run_on_lich_buffer("pause 315537897600\necho NOT\n")).to eq([out_of_range])
      expect(run_on_lich_buffer("delay 315537897599.999\necho NOT\n")).to eq([unrepresentable])
      expect(run_on_lich_buffer("wait 1e12\necho NOT\n")).to eq([out_of_range])
    end

    it 'faults a matchwait timeout at entry even when a match is already waiting' do
      src = "match done xyz\nmatchwait 3e11\necho NOT\ndone:\necho NOT\n"
      expect(run_on_lich_buffer(src, lines: ['xyz'])).to eq([unrepresentable])
    end

    it 'keeps a long but representable timeout (31 years) and a negative infinity (the default 1 s)' do
      src = "match done xyz\nmatchwait 1e9\necho NOT\ndone:\necho matched\n"
      expect(run_on_lich_buffer(src, lines: ['xyz'])).to eq(['matched'])
      expect(run("evalmath r -1/0\npause %r\necho after\n")[:echoes]).to eq(['after'])
    end

    # v0.26.2: the year-9999 bound is DateTime.Now's, i.e. the injected wall clock's (in its own
    # offset), never a Time.now of the interpreter's own: on a virtual clock 2 s before year
    # 10000 a 5 s pause is un-representable, a minute earlier it is an ordinary pause.
    it 'checks the year-9999 bound against the injected wall clock, not the machine clock' do
      ['+00:00', '+13:00', '-09:30'].each do |zone|
        late = Time.new(9999, 12, 31, 23, 59, 58, zone)
        [late, late - 60].each do |wall|
          clock = [0.0]
          echoes = []
          game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |_t| nil } }
          Lich::Genie::Engine.build("pause 5\necho after\n", name: 't', game: game, echo: ->(t) { echoes << t },
                                                             input: GenieSpecSupport::TimedInput.new([], clock: clock, gap: 0.0),
                                                             clock: -> { clock[0] }, wall_clock: -> { wall + clock[0] }).run
          expect([zone, echoes]).to eq([zone, wall == late ? [unrepresentable] : ['after']])
        end
      end
    end

    it 'stops at an infinite pause in a text action body (TriggerParse catch)' do
      src = "evalmath r 1/0\naction pause %r when ^go\nwaitfor done\necho NOT\n"
      expect(run_on_lich_buffer(src, lines: %w[go done])).to eq([out_of_range])
    end
  end
end
