# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/genie'

# Interpreter#abort_script = Script.AbortScript (Script.cs:1137-1176 R): ScriptDone + the finished
# state. RunScript's loop checks the state before every row (Script.cs:1726-1730 R), so a script
# aborting itself stops right after that row (e.g. a corpus stop label's `put #script abort all` then
# `put .cleanup`), and TriggerParse returns for a done script (Script.cs:1181 R). Remix golden:
# flow t158 / t164.
RSpec.describe Lich::Genie::Interpreter do
  let(:clock) { [0.0] }
  let(:aborted_line) { '[Script aborted! (Run time: 0.00 seconds): me.cmd]' }
  let(:sends) { [] }
  let(:echoes) { [] }
  let(:launches) { [] }

  # A host whose `#script abort <name>` aborts the named interpreter (the glue's
  # LichScriptControl -> GenieScript#genie_abort -> Interpreter#abort_script).
  let(:control) do
    registry = interpreters
    Object.new.tap do |o|
      o.define_singleton_method(:names) { registry.keys }
      o.define_singleton_method(:abort) { |name| registry[name]&.abort_script }
      %i[pause resume pauseorresume reload].each { |verb| o.define_singleton_method(verb) { |_name| nil } }
    end
  end
  let(:interpreters) { {} }

  def build(source, name: 'me', input: [])
    log = sends
    game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |text| log << text } }
    Lich::Genie::Engine.build(
      source, name: name, game: game, input: GenieSpecSupport::TimedInput.new(input, clock: clock, gap: 0.02),
              echo: ->(text) { echoes << text }, launch: ->(n, a) { launches << [n, a] }, script_control: control,
              clock: -> { clock[0] }
    ).tap { |interp| interpreters[name] = interp }
  end

  it 'stops a script that aborts itself right after the aborting row (no launch, no send, no echo)' do
    interp = build("put #script abort all\nput .cleanup\nput look\necho after\n")
    interp.run
    expect([launches, sends, echoes, interp.aborted?]).to eq([[], [], [aborted_line], true])
  end

  it 'stops after `#script abort <self>` in an if-then row and an action body alike' do
    build("if 1 = 1 then put #script abort me\necho after-if\n").run
    action = build("action put #script abort act;echo body-after when ^STOP$\nwaitfor never\necho after-wait\n",
                   name: 'act', input: ['STOP'])
    action.run
    expect(echoes).to eq([aborted_line, '[Script aborted! (Run time: 0.02 seconds): act.cmd]']) # the STOP line's 20 ms
    expect(action.aborted?).to be(true)
  end

  it 'aborts another script that is waiting: it handles no further line and runs no row' do
    victim = build("action echo saw $0 when .\nwaitfor never\necho victim-after\n", name: 'victim', input: %w[one])
    killer = build("put #script abort victim\necho killer-after\n", name: 'killer')
    killer.run
    victim.run
    expect(echoes).to eq(['[Script aborted! (Run time: 0.00 seconds): victim.cmd]', 'killer-after'])
    expect(victim.aborted?).to be(true)
  end

  it 'ignores a line, a #parse delivery and a variable change once aborted' do
    interp = build("action echo hit when ^x$\naction echo var when eval $foo = 1\nwaitfor never\n", input: [])
    interp.abort_script
    interp.trigger_parse('x')
    interp.deliver_parse('x')
    interp.deliver_variable_change('foo')
    interp.run
    expect(echoes).to eq([aborted_line]) # aborted before its first run: no run time yet
  end

  it 'cannot be revived by a state the script thread sets after the abort (cross-thread abort)' do
    interp = build("pause 0.05\necho resumed\n")
    interp.abort_script
    interp.instance_variable_set(:@state, :running) # what resume_ready would do on the script thread
    interp.run
    expect(echoes).to eq([aborted_line])
  end

  it 'is not aborted before abort_script' do
    interp = build("echo hi\n")
    interp.run
    expect([interp.aborted?, interp.abort_announced?, echoes]).to eq([false, false, ['hi']])
  end

  # AbortScript's line (Script.cs:1143-1158 R): only while the script is not finished, once; the
  # run time since the load, F2 under 10 s, F0 from 10 s (Remix golden t158 / t164 / t10).
  describe "Remix's \"[Script aborted! ...]\" line" do
    def waiting(seconds)
      build("pause #{seconds}\nput #script abort me\necho not-here\n").tap(&:run)
    end

    # .NET's F formats round half to even on the exact binary value (probed on .NET 10: 0.125 ->
    # 0.12, 0.375 -> 0.38, 2.675 -> 2.67, 9.995 -> 9.99, 10.5 -> 10, 11.5 -> 12, 12.5 -> 12); Ruby's
    # format('%.2f') gives 2.68 for 2.675 and 10.00 for 9.995.
    it 'formats the run time F2 under 10 s and F0 from 10 s, rounding the exact value half-even like .NET' do
      [0.125, 0.375, 2.675, 9.994, 9.995, 9.999, 10.0, 10.5, 11.5, 12.5, 123.456].each do |t|
        clock[0] = 0.0 # each script's run time is exactly its pause
        waiting(t)
      end
      expect(echoes.map { |line| line[/Run time: (\S+) /, 1] }).to eq(%w[0.12 0.38 2.67 9.99 9.99 10.00 10 10 12 12 123])
    end

    it 'prints nothing for a finished script, and only once for a repeated abort' do
      done = build("echo hi\n")
      done.run
      done.abort_script
      twice = waiting(1.5)
      twice.abort_script
      expect([echoes, done.abort_announced?, twice.abort_announced?]).to eq([['hi', '[Script aborted! (Run time: 1.50 seconds): me.cmd]'], false, true])
    end

    # The check-then-set runs under the interpreter's lock, so a cross-thread
    # abort (GenieScript#genie_abort) racing the script thread's own claim cannot print twice.
    it 'claims the line under a lock: an abort blocked behind a claim made meanwhile prints nothing' do
      interp = build("waitfor never\n")
      lock = interp.instance_variable_get(:@abort_lock)
      lock.lock
      racer = Thread.new { interp.abort_script }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      Thread.pass until racer.status == 'sleep' || !racer.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      blocked = racer.status == 'sleep'
      interp.instance_variable_set(:@abort_announced, true) # the other thread's claim, under the lock
      lock.unlock
      racer.join(5)
      expect([blocked, echoes, interp.aborted?]).to eq([true, [], true])
    end

    it 'prints it for a script error with no scripterror label, not when moving to the label' do
      build("goto nowhere\n").run
      build("goto nowhere\nscripterror:\necho handled\n", name: 'held').run
      expect(echoes.grep(/aborted|moving|handled/)).to eq([aborted_line, '[Script moving to scripterror label (held.cmd)]', 'handled'])
    end
  end
end
