# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/genie'

# The runtime timing model on the REAL interpreter, headless (TickScript, Script.cs:1487-1664 R):
#   the roundtime gates every resume but delayed/actioninstant (Script.cs:1505-1511 R)
#   wait = prompt since entry AND N s (Script.cs:1537-1548, 3381-3393 R; Utility.cs:707-725 R);
#     move = send + room desc (Script.cs:1585-1597, 3447-3458 R); empty move / nextroom no-op
#   a paused script runs no row and takes no resume (Script.cs:1488-1492, 1731-1734 R)
#   no resume while a DR packet is arriving (m_bBufferEnd / genieflow's chunk ticks,
#     Script.cs:1551, 1600, 2098-2104 R); the packet ends at its prompt or after CHUNK_IDLE_SECONDS
#   the prompt text is offered like a game line (Game.cs:2397-2405, 3062-3069 R)
# Expectations marked "(tNNN)" are the frozen Remix golden of that flow case.
RSpec.describe Lich::Genie::Interpreter do
  let(:events) { Lich::Genie::GameEvents }
  let(:idle) { described_class::CHUNK_IDLE_SECONDS }

  # Runs +source+ on a virtual clock (GenieSpecSupport::TimedInput: +items+ arrive +gap+ apart).
  # +on_send+ is called with each game send and the clock (to model a slow send or flip a flag).
  # Returns timed echoes ([clock, text]), sends, the unread items and the clock.
  def run(source, items: [], gap: 0.0, paused: nil, on_send: nil, clock: [0.0], game_state: nil)
    input = GenieSpecSupport::TimedInput.new(items, clock: clock, gap: gap)
    echoes = []
    sends = []
    game = Object.new
    game.define_singleton_method(:send_command) do |text|
      sends << [clock[0].round(4), text]
      on_send&.call(text, clock)
    end
    queue = Lich::Genie::CommandQueue.new(clock: -> { Time.at(clock[0]) })
    Lich::Genie::Engine.run(source, name: 't', game: game, input: input, queue: queue, paused: paused, game_state: game_state,
                                    echo: ->(t) { echoes << [clock[0].round(4), t] }, clock: -> { clock[0] })
    { echoes: echoes, texts: echoes.map(&:last), sends: sends, unread: input.items, clock: clock[0],
      queued: queue.items.map(&:action) }
  end

  def rt(ends_at) = events::RoundTimeEnd.new(ends_at)
  def prompt(text = '> ') = events::Prompt.new(text)
  def game_change(name) = Lich::Genie::VariableDispatch::Change.new(name, 0, game: true)

  describe 'the roundtime gate' do
    it 'holds a pause that ends in roundtime until the roundtime ends (t08)' do
      r = run("pause 0.5\necho after\n", items: [rt(3.0), prompt], gap: 0.1)
      expect(r[:echoes]).to eq([[3.0, 'after']])
    end

    it 'does not hold delay, which TickScript resumes in roundtime (t20)' do
      r = run("delay 0.5\necho after\n", items: [rt(3.0), prompt], gap: 0.1)
      expect(r[:echoes]).to eq([[0.5, 'after']])
    end

    it 'holds a satisfied waitfor, a matched matchwait and a matchwait timeout alike (t20, t141)' do
      expect(run("waitfor go\necho w\n", items: ['go', rt(2.0), prompt], gap: 0.001)[:echoes]).to eq([[2.0, 'w']])
      expect(run("match m go\nmatchwait\nm:\necho m\n", items: ['go', rt(2.0), prompt], gap: 0.001)[:echoes]).to eq([[2.0, 'm']])
      expect(run("matchwait 1\necho t\n", items: [rt(3.0), prompt], gap: 0.1)[:echoes]).to eq([[3.0, 't']])
    end

    it 'holds a satisfied waiteval (Script.cs:1573-1583 R; t145)' do
      src = "action var x 1 when ^SET\nwaiteval %x = 1\necho e\n"
      expect(run(src, items: [rt(2.0), prompt, 'SET'], gap: 0.1)[:echoes]).to eq([[2.0, 'e']])
    end

    it 'holds an action goto (actionwait) but not an `action instant` goto (actioninstant; t142)' do
      normal = "action goto L when ^go\nwaitfor never\nL:\necho at-l\n"
      expect(run(normal, items: [rt(2.0), prompt, 'go'], gap: 0.1)[:echoes]).to eq([[2.0, 'at-l']])
      instant = normal.sub('action goto', 'action instant goto')
      expect(run(instant, items: [rt(2.0), prompt, 'go'], gap: 0.1)[:echoes].first[0]).to be < 0.4
    end

    it 'holds a move whose room desc arrives in roundtime (t152)' do
      r = run("move north\necho m\n", items: [events::MOVE, rt(2.0), prompt], gap: 0.01)
      expect(r[:echoes]).to eq([[2.0, 'm']])
      expect(r[:sends].map(&:last)).to eq(['north'])
    end

    it 'takes the latest roundtime, a shorter one too (m_oRoundTimeEnd is overwritten)' do
      r = run("pause 0.5\necho after\n", items: [rt(5.0), prompt, rt(1.5), prompt], gap: 0.1)
      expect(r[:echoes]).to eq([[1.5, 'after']])
    end

    it 'does not hold a resume at the very end of the roundtime (DateTime.Now < m_oRoundTimeEnd)' do
      r = run("pause 2\necho after\n", items: [rt(2.0), prompt], gap: 0.1)
      expect(r[:echoes]).to eq([[2.0, 'after']])
    end

    it 'never holds a send: `send` queues and `put` goes out at once in roundtime (t18, t35, t154)' do
      src = "action put react when ^go\naction send queued-react when go$\nwaitfor never2\n"
      r = run(src, items: [rt(9.0), prompt, 'go', 'never2'], gap: 0.1)
      expect(r[:sends]).to eq([[0.3, 'react']])
      expect(r[:queued]).to eq(['queued-react'])
    end
  end

  describe 'the end of a DR packet' do
    it 'fires a later line\'s action of the same packet before the matchwait jumps (t17)' do
      src = "action put react $1 when ^Then (\\w+) happens\nmatch go First line\nmatchwait\ngo:\nput after-match\n"
      r = run(src, items: ['First line here.', 'Then thunder happens.', prompt])
      expect(r[:sends].map(&:last)).to eq(['react thunder', 'after-match'])
    end

    it 'lets an action goto on line 2 beat a matchre hit on line 1 of the same packet (t115)' do
      src = "action goto ALBL when ^two\nmatchre MLBL ^one\nmatchwait 5\nexit\nMLBL:\necho at-mlbl\nexit\nALBL:\necho at-albl\n"
      expect(run(src, items: ['one', 'two', prompt])[:texts]).to eq(['at-albl'])
    end

    it 'lets a game row\'s variable change later in the packet fire an eval action goto first (t147)' do
      src = "action goto HURT when eval $health < 60\nwaitfor ZZEND\necho end\nexit\nHURT:\necho hurt $health\n"
      r = run(src, items: ['ZZEND', game_change('$health'), prompt], game_state: { 'health' => '50' })
      expect(r[:texts]).to eq(['hurt 50'])
    end

    it 'resumes at the prompt itself, and CHUNK_IDLE_SECONDS after the last row of a packet with none (t48)' do
      expect(run("waitfor go\necho w\n", items: ['go', prompt], gap: 0.004)[:echoes]).to eq([[0.008, 'w']])
      expect(run("waitfor go\necho w\n", items: ['go'], gap: 0.25)[:echoes]).to eq([[(0.25 + idle).round(4), 'w']])
      # rows further apart than CHUNK_IDLE_SECONDS are two packets: the prompt comes too late
      expect(run("waitfor go\necho w\n", items: ['go', prompt], gap: 0.25)[:echoes]).to eq([[(0.25 + idle).round(4), 'w']])
    end

    it 'keeps a game row read late (the script was busy past CHUNK_IDLE_SECONDS) in the packet' do
      src = "action put slow when ^go\naction echo tail-act when ^tail\nwaitfor go\necho resumed\n"
      slow = ->(_text, clock) { clock[0] += 0.05 } # a send that blocks 50 ms
      r = run(src, items: %w[go tail], gap: 0.005, on_send: slow)
      expect(r[:texts]).to eq(%w[tail-act resumed])
      expect(r[:unread]).to eq([])
    end

    it 'does not open a packet for a #parse line or another script\'s variable change' do
      parsed = run("waitfor go\necho w\n", items: [Lich::Genie::ParseDispatch::Line.new('go', 1)], gap: 0.1)
      expect(parsed[:echoes]).to eq([[0.1, 'w']])
      src = "action var x 1 when eval $g = 1\nwaiteval %x = 1\necho e\n"
      plain = Lich::Genie::VariableDispatch::Change.new('$g', 0)
      expect(run(src, items: [plain], gap: 0.1, game_state: { 'g' => '1' })[:echoes]).to eq([[0.1, 'e']])
      expect(run(src, items: [game_change('$g')], gap: 0.1, game_state: { 'g' => '1' })[:echoes]).to eq([[(0.1 + idle).round(4), 'e']])
    end

    it 'holds a matchwait timeout that falls inside a packet until the packet ends; a match of that packet wins' do
      # the 20 ms timeout passes while the packet (rows 9 ms apart) is still arriving
      r = run("match m hit\nmatchwait 0.02\necho timeout\nexit\nm:\necho matched\n", items: ['noise', 'hit', prompt], gap: 0.009)
      expect(r[:echoes]).to eq([[0.027, 'matched']])
      r = run("match m hit\nmatchwait 0.02\necho timeout\nexit\nm:\necho matched\n", items: ['noise', 'more', prompt], gap: 0.009)
      expect(r[:echoes]).to eq([[0.027, 'timeout']])
    end

    it 'ignores a Resumed wake-up: it is no line and opens no packet' do
      r = run("action echo any when .\nwaitfor go\necho w\n", items: [events::RESUMED, 'go', prompt], gap: 0.1)
      expect(r[:texts]).to eq(%w[any w])
    end
  end

  describe 'wait' do
    it 'resumes on a prompt seen since the wait began once its time has passed, 1 s by default (t05, t151)' do
      expect(run("wait\necho w\n", items: [prompt], gap: 0.1)[:echoes]).to eq([[1.0, 'w']])
      expect(run("wait 2\necho w\n", items: [prompt], gap: 2.5)[:echoes]).to eq([[2.5, 'w']])
    end

    it 'takes a blank, zero, negative or unparseable time as 1 s (EvalDoubleTime; t151 `wait 0`)' do
      ['wait 0', 'wait -1', 'wait abc', 'wait  '].each do |row|
        expect(run("#{row}\necho w\n", items: [prompt], gap: 0.1)[:echoes]).to eq([[1.0, 'w']]), row
      end
    end

    it 'ignores a prompt read before the wait (m_bWaitForPrompt is cleared at entry; t151)' do
      r = run("pause 0.5\nwait\necho w\n", items: [prompt, prompt], gap: 0.3)
      expect(r[:echoes]).to eq([[1.5, 'w']]) # the 0.3 s prompt came in the pause; the 0.6 s one counts, at 1.5
    end

    it 'never resumes on a game line, a variable change or a prompt-less packet' do
      expect { run("wait\necho w\n", items: ['> ', game_change('$prompt')], gap: 0.1) }.to raise_error(/input exhausted/)
    end
  end

  # Remix checks a timed wait only on its 10 ms timer tick (TickScript,
  # Script.cs:1513-1548, 1635-1650 R; TimerBgWorker.Interval = 10, FormMain.Designer.cs:1409 R), so a
  # wait entered on one tick resumes on a later one: never sooner than one tick after entry.
  describe 'the minimum resume granularity of a timed wait (one Remix tick)' do
    let(:tick) { described_class::TICK_SECONDS }

    it 'resumes a sub-tick pause, delay, matchwait timeout and wait one tick after entry' do
      expect(tick).to eq(0.01)
      %w[pause delay].each do |verb|
        expect(run("#{verb} 0.001\necho r\n")[:echoes]).to eq([[0.01, 'r']]), verb
      end
      expect(run("matchwait 0.001\necho t\n")[:echoes]).to eq([[0.01, 't']])
      expect(run("wait 0.001\necho w\n", items: [prompt], gap: 0.002)[:echoes]).to eq([[0.01, 'w']])
    end

    it 'leaves a wait of one tick or more exactly as long as asked' do
      expect(run("pause 0.01\necho r\n")[:echoes]).to eq([[0.01, 'r']])
      expect(run("delay 0.015\necho r\n")[:echoes]).to eq([[0.015, 'r']])
      expect(run("matchwait 0.5\necho t\n")[:echoes]).to eq([[0.5, 't']])
    end

    it 'paces a sub-tick delay loop one tick per pass instead of spinning (automapper.cmd WAVE_DO `delay 0.001`)' do
      src = "var n 0\nLOOP:\nmath n add 1\nif %n >= 5 then goto DONE\ndelay 0.001\ngoto LOOP\nDONE:\necho n=%n\n"
      expect(run(src)[:echoes]).to eq([[0.04, 'n=5']])
    end
  end

  describe 'move and nextroom' do
    it 'does nothing for an empty move or nextroom: no send, no wait (EvalMove; t152)' do
      r = run("move\necho a\nnextroom\necho b\nmove   \necho c\n")
      expect(r[:echoes]).to eq([[0.0, 'a'], [0.0, 'b'], [0.0, 'c']])
      expect(r[:sends]).to eq([])
    end

    it 'sends, then resumes on the next room desc only, not on a line or a prompt (t05, t152)' do
      r = run("move north\necho m\n", items: ['Obvious paths: north.', prompt, events::MOVE, prompt], gap: 0.005)
      expect(r[:sends]).to eq([[0.0, 'north']])
      expect(r[:echoes]).to eq([[0.02, 'm']]) # the room desc at 0.015, its packet's prompt at 0.02
    end

    it 'ignores a room desc read before the move, and needs a new one for the next move' do
      r = run("pause 0.5\nmove north\necho m1\nmove south\necho m2\n", items: [events::MOVE] * 3, gap: 0.3)
      # the 0.3 s room desc came in the pause; 0.6 s ends the first move, 0.9 s the second
      expect(r[:echoes]).to eq([[(0.6 + idle).round(4), 'm1'], [(0.9 + idle).round(4), 'm2']])
    end
  end

  describe 'pause' do
    it 'runs no row while the script is paused, and starts once it is resumed' do
      clock = [0.0]
      r = run("echo first\n", paused: -> { clock[0] < 1.0 }, clock: clock)
      expect(r[:echoes].first[0]).to be >= 1.0
    end

    it 'stops before the next row when paused mid-run and goes on from that row (t153)' do
      paused = [false]
      clock = [0.0]
      unpause_at = 0.7
      flag = -> { paused[0] && clock[0] < unpause_at }
      r = run("echo a\nput pause-me\necho b\n", paused: flag, clock: clock, on_send: ->(_t, _c) { paused[0] = true })
      expect(r[:texts]).to eq(%w[a b])
      expect(r[:echoes].last[0]).to be >= unpause_at
    end

    it 'takes no resume while paused even when the wait is ready, and resumes after' do
      clock = [0.0]
      r = run("pause 0.1\necho after\n", paused: -> { clock[0].between?(0.05, 0.9) }, items: [prompt], gap: 0.06, clock: clock)
      expect(r[:echoes].first[0]).to be > 0.9
    end

    it 'still handles what it reads while paused (it arrived before the pause): an action fires' do
      clock = [0.0]
      r = run("action echo act when ^go\npause 0.1\necho after\n", paused: -> { clock[0].between?(0.05, 0.5) }, items: ['go'], gap: 0.06,
                                                                                    clock: clock)
      expect(r[:echoes].map(&:last)).to eq(%w[act after])
      expect(r[:echoes].first[0]).to eq(0.06)
      expect(r[:echoes].last[0]).to be > 0.5
    end
  end

  describe 'the prompt text' do
    it 'is offered to actions, waitfor and matchre like a game line (t150)' do
      src = "action echo p1 when ^> $\naction echo p2 when ^R> $\nmatchre r ^R>\nmatchwait\nr:\necho r\n"
      r = run(src, items: [prompt('> '), prompt('R> ')], gap: 0.1)
      expect(r[:texts]).to eq(%w[p1 p2 r])
      expect(run("waitfor >\necho w\n", items: [prompt], gap: 0.1)[:texts]).to eq(['w'])
    end

    it 'offers nothing for a prompt Remix prints no text for, or a blank one, but still ends the packet' do
      src = "action echo any when .*\nwaitfor go\necho w\n"
      r = run(src, items: ['go', prompt(nil)], gap: 0.005)
      expect(r[:echoes]).to eq([[0.005, 'any'], [0.01, 'w']])
      expect(run(src, items: ['go', prompt(' ')], gap: 0.005)[:texts]).to eq(%w[any w])
    end
  end

  # A trigger-on-input line (ParseDispatch::Line#game?) goes through TriggerParse with
  # bBufferWait = true; a waitfor / matchwait it satisfies calls SetBufferWait and resumes only at
  # the next SetBufferEnd -- the end of the next game packet (Script.cs:1205-1265, 1551, 1600,
  # 2098-2104 R), never on its own (flow t171: the helper never resumes with no game data).
  describe 'trigger-on-input lines' do
    def input_line(text, depth = 0) = Lich::Genie::ParseDispatch::Line.new(text, depth, game: true)

    it 'holds a waitfor it satisfies until the end of the next game packet' do
      r = run("waitfor knock\necho w\n", items: [input_line('knock twice'), 'reply', prompt], gap: 0.004)
      expect(r[:echoes]).to eq([[0.012, 'w']]) # the prompt at 0.012 ends the reply's packet
    end

    it 'holds a matched matchwait the same way, and never resumes with no further game data' do
      src = "matchre m ^peer\nmatchwait\necho timeout\nexit\nm:\necho m\n"
      # held: the matched wait waits for a packet that never comes, so the input runs dry
      expect { run(src, items: [input_line('peer bell')], gap: 0.1) }.to raise_error(RuntimeError, /input exhausted/)
    end

    # Per genieflow, m_bBufferEnd gates only the waitfor and the
    # matchwait match resumes (Script.cs:1551, 1600 R) -- not the matchwait timeout arm, not an
    # action goto's actionwait, not a pause.
    it 'lets a held matchwait time out on its deadline' do
      src = "matchre m ^peer\nmatchwait 2\necho timeout\nexit\nm:\necho m\n"
      expect(run(src, items: [input_line('peer bell')], gap: 0.1)[:echoes]).to eq([[2.0, 'timeout']])
    end

    it 'resumes an action goto out of a held wait at once, and its pause on time' do
      %W[matchre\ mw\ ^knock\nmatchwait waitfor\ knock].each do |wait|
        src = "action goto act when ^knock\n#{wait}\necho w\nexit\nmw:\necho mw\nexit\nact:\necho act\npause 0.5\necho p\n"
        got = run(src, items: [input_line('knock')], gap: 0.1)[:echoes]
        expect(got).to eq([[0.11, 'act'], [0.61, 'p']]), "#{wait}: #{got}" # Remix: 510 / 1010 ms after a 500 ms send
      end
    end

    # Per genieflow, only SetBufferEnd resets m_bBufferEnd
    # (Script.cs:1021-1023 R), so a later waitfor satisfied by a #parse still waits for a packet end.
    it 'keeps the hold across an action goto until the next packet ends' do
      src = "action goto act when ^knock\nwaitfor knock\nexit\nact:\nwaitfor zzz\necho z\n"
      items = [input_line('knock'), Lich::Genie::ParseDispatch::Line.new('zzz', 0), 'reply', prompt]
      # zzz at 0.1 is held; the reply at 0.15 opens a packet that ends idle 10 ms later
      expect(run(src, items: items, gap: 0.05)[:echoes]).to eq([[(0.15 + idle).round(4), 'z']])
    end

    # An input line that arrives while a packet is arriving is
    # covered by that packet's end (Remix's next SetBufferEnd), not the next packet's.
    it 'resumes a waitfor an input line satisfied mid-packet at the end of that packet' do
      r = run("waitfor knock\necho w\n", items: ['row one', input_line('knock'), 'row two', prompt, 'later', prompt], gap: 0.004)
      expect(r[:echoes]).to eq([[0.016, 'w']]) # the first prompt
    end

    it 'resumes at the idle end of a following prompt-less packet' do
      r = run("waitfor knock\necho w\n", items: [input_line('knock'), 'reply'], gap: 0.2)
      expect(r[:echoes]).to eq([[(0.4 + idle).round(4), 'w']])
    end

    it 'does not hold anything it does not satisfy: an action fires, a pause ends on time' do
      r = run("action echo act when ^look\npause 0.5\necho p\n", items: [input_line('look')], gap: 0.1)
      expect(r[:echoes]).to eq([[0.1, 'act'], [0.5, 'p']])
    end

    it 'continues the nesting depth the line was sent at, like a queued #parse' do
      r = run("action put #parse x when ^look\nwaitfor never\n", items: [input_line('look', Lich::Genie::DispatchDepth::LIMIT)])
      expect(r[:texts].first).to start_with('[Script error: maximum nested dispatch depth')
    end

    it 'is no game item when not on a game line: a plain #parse line satisfies at once (bBufferWait false)' do
      parse = Lich::Genie::ParseDispatch::Line.new('knock', 0)
      r = run("waitfor knock\necho w\n", items: [parse], gap: 0.1)
      expect(r[:echoes]).to eq([[0.1, 'w']])
    end
  end
end
