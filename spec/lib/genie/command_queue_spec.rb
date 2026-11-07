# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Lich::Genie::CommandQueue: Remix Lists/CommandQueue.cs (R) and FormMain's drain
# (TimerBgWorker_Tick, FormMain.cs:8313-8339 R). Timings are the genieflow goldens of flow
# t130_queue_sequence / t131_queue_rt_trigger / t132_queue_webbed_stunned, replayed here on a
# fake clock.
RSpec.describe Lich::Genie::CommandQueue do
  let(:epoch) { Time.at(1_000_000) }
  let(:now) { [epoch] }
  let(:queue) { Lich::Genie::CommandQueue.new(clock: -> { now[0] }) }
  let(:free) { Lich::Genie::CommandQueue::FREE }

  def at(seconds) = now[0] = epoch + seconds

  def state(in_rt: false, webbed: false, stunned: false)
    Lich::Genie::CommandQueue::State.new(in_rt: in_rt, webbed: webbed, stunned: stunned)
  end

  # Tick every 10 ms from +from+ to +to+ seconds, collecting [time, action] like the timer does.
  def run_ticks(from, to, state_proc = -> { free })
    out = []
    (from * 100).round.upto((to * 100).round) do |cs|
      at(cs / 100.0)
      queue.drain(state_proc) { |action| out << [cs * 10, action] }
    end
    out
  end

  describe 'timing (AddToQueue / Poll / SetNextTime)' do
    it 'counts each delay from the previous release, not from the add (t130: look 2 s, smile 3 s, bow+wave 4 s)' do
      queue.add(2, 'look', wait_rt: true)
      queue.add(1, 'smile', wait_rt: true)
      queue.add(1.0, 'bow', wait_rt: true)
      queue.add(0, 'wave', wait_rt: true)
      expect(run_ticks(0, 5)).to eq([[2000, 'look'], [3000, 'smile'], [4000, 'bow'], [4000, 'wave']])
    end

    it 'starts the clock only when the queue was empty: a later add behind items changes nothing' do
      queue.add(2, 'a', wait_rt: false)
      at(1.5)
      queue.add(0, 'b', wait_rt: false)
      expect(run_ticks(1.5, 3)).to eq([[2000, 'a'], [2000, 'b']])
    end

    it 'keeps the stale time on clear; the next add to the emptied queue restarts it (t130: after-clear)' do
      queue.add(3, 'never1', wait_rt: true)
      queue.add(0, 'never2', wait_rt: true)
      queue.clear
      queue.add(1, 'after-clear', wait_rt: true)
      expect(run_ticks(0, 4)).to eq([[1000, 'after-clear']])
    end

    # The queuing script's host handle rides with its item and comes back
    # with the action, so the host sends (and echoes) a released command as that script.
    it 'hands each released action back with the owner it was queued with (nil when none)' do
      queue.add(0, 'mine', wait_rt: false, owner: :script_a)
      queue.add(0, 'trigger', wait_rt: false)
      queue.add(0, 'theirs', wait_rt: false, owner: :script_b)
      expect(queue.items.map(&:owner)).to eq([:script_a, nil, :script_b])
      out = []
      queue.drain(-> { free }) { |action, owner| out << [action, owner] }
      expect(out).to eq([['mine', :script_a], ['trigger', nil], ['theirs', :script_b]])
    end

    # A `send ,go2 x` row's author-marked text is what the release runs; the listing (and the
    # #queue filter) see the clean action.
    it 'releases an item\'s route (drain and poll) and lists its clean action' do
      queue.add(0, ',go2 1', wait_rt: false, route: ',<mark>go2 1')
      queue.add(0, 'look', wait_rt: false)
      queue.add(0, ',go2 2', wait_rt: false, route: ',<mark>go2 2')
      expect(queue.items.map(&:action)).to eq([',go2 1', 'look', ',go2 2'])
      out = []
      queue.drain(-> { free }) { |action, _owner| out << action }
      expect(out).to eq([',<mark>go2 1', 'look', ',<mark>go2 2'])
      queue.add(0, ',x', wait_rt: false, route: ',<m>x')
      expect(queue.poll(free)).to eq(',<m>x')
    end

    it 'keeps an owned empty action a pause: the drain stops there and poll returns ""' do
      queue.add(0, '', wait_rt: false, owner: :script_a)
      queue.add(0, 'after', wait_rt: false, owner: :script_a)
      out = []
      expect(queue.drain(-> { free }) { |action, owner| out << [action, owner] }).to eq(0)
      expect(out).to be_empty
      expect(queue.poll(free)).to eq('after')
    end

    it 'releases a negative delay (StringToDouble -1) at once' do
      queue.add(-1, 'now', wait_rt: false)
      expect(queue.poll(free)).to eq('now')
    end

    it 'lets an empty action end that tick\'s drain like any release; the next one goes a tick later (t130)' do
      queue.add(2, '', wait_rt: true)
      queue.add(0, 'gap-after-empty', wait_rt: true)
      expect(run_ticks(0, 2.5)).to eq([[2010, 'gap-after-empty']])
    end
  end

  # SetNextTime's DateTime.Now.AddSeconds(delay) (CommandQueue.cs:160-174 R; .NET 10, Remix's
  # target): |delay| > MaxSeconds throws "Value to add was out of range", a result past year
  # 9999 throws from AddTicks, NaN saturates to 0 ticks (= now). AddToQueue has already
  # appended the item (CommandQueue.cs:77-81 R), so the fault leaves it queued under the stale
  # m_oNextTime (default(DateTime) before any set = long past). Goldens: genieflow probes.
  describe 'delay range (DateTime.AddSeconds)' do
    it 'raises after appending an infinite delay and releases the item under the stale (initial) time' do
      expect { queue.add(Float::INFINITY, 'qinf', wait_rt: false) }
        .to raise_error(Lich::Genie::Error, "Value to add was out of range. (Parameter 'value')")
      expect(queue.items.map(&:action)).to eq(['qinf'])
      expect(queue.poll(free)).to eq('qinf')
    end

    it 'keeps the previous next time on a fault: 1e20 behind a cleared 3 s item waits out the 3 s' do
      queue.add(3, 'gone', wait_rt: false)
      queue.clear
      expect { queue.add(1e20, 'q20', wait_rt: false) }.to raise_error(Lich::Genie::Error)
      queue.add(0, 'after', wait_rt: false)
      expect(run_ticks(0, 4)).to eq([[3000, 'q20'], [3000, 'after']])
    end

    it 'treats NaN as 0 ticks (saturating double -> long): released at once, no fault' do
      expect { queue.add(Float::NAN, 'qnan', wait_rt: false) }.not_to raise_error
      expect(queue.poll(free)).to eq('qnan')
    end

    it 'faults at the MaxSeconds boundary (315537897599 s) and past year 9999 below it' do
      expect { queue.add(-315_537_897_600, 'neg', wait_rt: false) }
        .to raise_error(Lich::Genie::Error, /Value to add was out of range/)
      queue.clear
      expect { queue.add(315_537_897_599.5, 'half-past', wait_rt: false) }
        .to raise_error(Lich::Genie::Error, /Value to add was out of range/)
      queue.clear
      expect { queue.add(315_537_897_599, 'at-max', wait_rt: false) } # passes AddUnits, fails AddTicks
        .to raise_error(Lich::Genie::Error, /un-representable DateTime/)
      queue.clear
      expect { queue.add(3e11, 'y11532', wait_rt: false) }
        .to raise_error(Lich::Genie::Error, /un-representable DateTime/)
      queue.clear
      expect { queue.add(2.5e11, 'y9892', wait_rt: false) }.not_to raise_error
      expect(queue.poll(free)).to eq('')
    end

    it 'never raises out of poll when the NEW head\'s delay is out of range (Remix: the timer tick ' \
       'crashes, Poll throws after RemoveAt) -- the head is released and the next waits the stale time' do
      queue.add(0, 'a', wait_rt: false)
      queue.add(Float::INFINITY, 'b', wait_rt: false) # behind a: no SetNextTime at add
      queue.add(0, 'c', wait_rt: false)
      expect(run_ticks(0, 0.02)).to eq([[0, 'a'], [0, 'b'], [0, 'c']])
    end

    it 'survives the parity probe inputs (NaN, 1e400, 400 digits, 1e20) through #queue/#send' do
      router = Lich::Genie::CommandRouter.new(vars: Lich::Genie::Variables.new, eval: nil, echo: ->(_t) {},
                                              send: ->(_t) {}, hooks: nil, queue: queue)
      { '#queue NaN qnan' => 'qnan', '#queue 1e400 qinf' => 'qinf', "#send #{'9' * 400} s400" => 's400',
        '#send 99999999999999999999 s20' => 's20' }.each do |row, action|
        queue.clear
        expect { router.route(row) }.not_to raise_error
        expect(queue.items.map(&:action)).to eq([action])
        expect(queue.poll(free)).to eq(action)
      end
    end
  end

  describe 'restrictions (EventItem.IsRestricted) and head-of-line blocking' do
    it 'holds a roundtime-gated head until the roundtime ends, then releases everything due (t131)' do
      queue.add(0, 'rtsend', wait_rt: true)
      queue.add(0, 'qfree', wait_rt: false)
      rt_until = 3.01
      expect(run_ticks(0.5, 4, -> { state(in_rt: now[0] < epoch + rt_until) })).to eq([[3010, 'rtsend'], [3010, 'qfree']])
    end

    it 'releases an unrestricted item during roundtime when nothing restricted is ahead of it' do
      queue.add(0, 'qfree', wait_rt: false)
      expect(queue.poll(state(in_rt: true))).to eq('qfree')
    end

    it 'gates webbed and stunned only for items that ask (#do), never a #send (t132)' do
      queue.add(0, 'push', wait_rt: true)
      expect(queue.poll(state(webbed: true, stunned: true))).to eq('push')
      queue.add(0, 'grab', wait_rt: true, wait_webbed: true, wait_stunned: true)
      expect(queue.poll(state(webbed: true))).to eq('')
      expect(queue.poll(state(stunned: true))).to eq('')
      expect(queue.poll(state(in_rt: true))).to eq('')
      expect(queue.poll(free)).to eq('grab')
    end

    it 're-reads the state before every poll of one drain' do
      %w[a b c].each { |c| queue.add(0, c, wait_rt: true) }
      polls = [state, state, state(in_rt: true)]
      out = []
      queue.drain(-> { polls.shift || free }) { |action| out << action }
      expect(out).to eq(%w[a b])
      expect(queue.items.map(&:action)).to eq(%w[c])
    end
  end

  describe 'introspection' do
    it 'lists a snapshot that later changes do not touch' do
      queue.add(2, 'look', wait_rt: true)
      snapshot = queue.items
      queue.clear
      expect(snapshot.map { |i| [i.delay, i.action, i.wait_rt] }).to eq([[2, 'look', true]])
      expect(queue).to be_empty
    end

    it 'wait_for_items returns at once when items are queued and times out when none are' do
      expect(queue.wait_for_items(0.01)).to be(false)
      queue.add(0, 'x', wait_rt: false)
      expect(queue.wait_for_items(5)).to be(true)
    end
  end

  # The glue's stand-in for FormMain's timer (CommandQueue::Worker): tick = one drain; the
  # thread sleeps on the queue while it is empty. Driven step by step through the sleeper.
  describe described_class::Worker do
    let(:ran) { [] }
    let(:reports) { [] }

    it 'runs each released action, reports a fault the runner lets through and goes on' do
      worker = described_class.new(queue: queue, state: -> { free }, report: ->(e) { reports << e.message },
                                   run: ->(action, _owner) { action == 'bad' ? raise(ArgumentError, 'boom') : ran << action })
      %w[a bad b].each { |c| queue.add(0, c, wait_rt: false) }
      expect(worker.tick).to eq(3)
      expect(ran).to eq(%w[a b])
      expect(reports).to eq(['boom'])
    end

    it 'passes each released action\'s owner to run' do
      worker = described_class.new(queue: queue, state: -> { free }, report: ->(e) { reports << e },
                                   run: ->(action, owner) { ran << [action, owner] })
      queue.add(0, 'a', wait_rt: false, owner: :s1)
      queue.add(0, 'b', wait_rt: false)
      expect(worker.tick).to eq(2)
      expect(ran).to eq([['a', :s1], ['b', nil]])
      expect(reports).to be_empty
    end

    it 'names its thread genie-command-queue' do
      worker = described_class.new(queue: queue, state: -> { free }, run: ->(_a, _owner) {}, report: ->(_e) {})
      thread = worker.start
      expect(thread.name).to eq('genie-command-queue')
    ensure
      thread&.kill&.join
    end

    it 'never runs anything while the state restricts the head' do
      worker = described_class.new(queue: queue, state: -> { state(in_rt: true) }, run: ->(a, _owner) { ran << a }, report: ->(_e) {})
      queue.add(0, 'x', wait_rt: true)
      expect(worker.tick).to eq(0)
      expect(ran).to be_empty
    end

    it 'drains on its own thread once items arrive, one sleeper step per tick, and restarts a dead thread' do
      steps = Thread::Queue.new
      done = Thread::Queue.new
      worker = described_class.new(queue: queue, state: -> { free }, report: ->(_e) {},
                                   run: ->(action, _owner) { done << action }, sleeper: ->(_s) { steps.pop })
      first = worker.start
      expect(worker.start).to be(first) # idempotent while alive
      queue.add(0, 'hello', wait_rt: false)
      steps << :tick
      expect(done.pop).to eq('hello')
      first.kill
      first.join
      expect(worker.alive?).to be(false)
      second = worker.start
      expect(second).not_to be(first)
      queue.add(0, 'again', wait_rt: false)
      steps << :tick
      expect(done.pop).to eq('again')
      second.kill
      second.join
    end

    # A thread born on a Lich script thread joins that script's
    # ThreadGroup and dies when Lich kills the group (script.rb:2212-2214, 2747-2753); the
    # worker moves itself to ThreadGroup::Default like Lich's own cleanup thread (script.rb:1982).
    it 'puts its thread in ThreadGroup::Default even when started from a thread in another group' do
      group = ThreadGroup.new
      worker = described_class.new(queue: queue, state: -> { free }, run: ->(_a, _owner) {}, report: ->(_e) {})
      thread = nil
      starter = Thread.new { thread = worker.start }
      group.add(starter)
      starter.join
      expect(thread.group).to be(ThreadGroup::Default)
      expect(group.list).not_to include(thread)
    ensure
      thread&.kill&.join
    end

    it 'keeps its thread in the starter\'s group when that group is enclosed (ThreadError) and still runs' do
      group = ThreadGroup.new
      done = Thread::Queue.new
      worker = described_class.new(queue: queue, state: -> { free }, run: ->(a, _owner) { done << a }, report: ->(_e) {},
                                   sleeper: ->(_s) {})
      thread = nil
      starter = Thread.new do
        Thread.stop
        thread = worker.start
      end
      Thread.pass until starter.stop?
      group.add(starter)
      group.enclose
      starter.run
      starter.join
      expect(thread.group).to be(group)
      queue.add(0, 'enclosed', wait_rt: false)
      expect(done.pop).to eq('enclosed')
    ensure
      thread&.kill&.join
    end

    # A non-StandardError a released command raises (deep recursion ->
    # SystemStackError, a ScriptError) is reported and the worker goes on; so is a fault in its
    # own state read. Exceptions it must not eat (SignalException, SystemExit) still end it.
    it 'reports a SystemStackError / NotImplementedError from a command and keeps draining' do
      worker = described_class.new(queue: queue, state: -> { free }, report: ->(e) { reports << e.class },
                                   run: lambda { |action, _owner|
                                     raise SystemStackError, 'deep' if action == 'stack'
                                     raise NotImplementedError, 'ni' if action == 'ni'

                                     ran << action
                                   })
      %w[a stack b ni c].each { |c| queue.add(0, c, wait_rt: false) }
      expect(worker.tick).to eq(5)
      expect(ran).to eq(%w[a b c])
      expect(reports).to eq([SystemStackError, NotImplementedError])
    end

    it 'survives a fault outside the command (the state read) on its thread, reports it and drains later' do
      steps = Thread::Queue.new
      done = Thread::Queue.new
      calls = 0
      naps = []
      worker = described_class.new(queue: queue, report: ->(e) { done << "report:#{e.message}" }, idle_timeout: 0.5,
                                   state: lambda {
                                     calls += 1
                                     raise SystemStackError, 'state' if calls == 1

                                     free
                                   },
                                   run: ->(action, _owner) { done << action }, sleeper: lambda { |s|
                                     naps << s
                                     steps.pop
                                   })
      thread = worker.start
      queue.add(0, 'x', wait_rt: false)
      steps << :tick
      expect(done.pop).to eq('report:state')
      steps << :backoff # one idle wait after a loop-level fault
      steps << :tick
      expect(done.pop).to eq('x')
      expect(naps).to eq([described_class::TICK_SECONDS, 0.5, described_class::TICK_SECONDS])
      expect(worker.alive?).to be(true)
    ensure
      thread&.kill&.join
    end

    it 'does not swallow SystemExit: the thread ends and start replaces it' do
      steps = Thread::Queue.new
      worker = described_class.new(queue: queue, state: -> { free }, report: ->(_e) {},
                                   run: ->(_a, _owner) { raise SystemExit }, sleeper: ->(_s) { steps.pop })
      first = worker.start
      first.report_on_exception = false
      queue.add(0, 'exit', wait_rt: false)
      steps << :tick
      expect { first.join }.to raise_error(SystemExit)
      expect(worker.alive?).to be(false)
      expect(worker.start).not_to be(first)
    ensure
      # Kill only a REPLACEMENT: joining the SystemExit-ended first thread again would re-raise
      # SystemExit here, in rspec's main thread, and rspec would exit 0 mid-suite.
      replacement = worker.start
      replacement.kill.join unless replacement.equal?(first)
    end

    # A hot reload of lib/genie.rb resets Lich::Genie's @command_queue,
    # so the scripts fill a NEW queue; the worker reads its queue through the callable on every
    # pass (and its idle wait times out) so it follows.
    it 'follows a replaced queue when built with a callable' do
      current = [queue]
      replacement = Lich::Genie::CommandQueue.new(clock: -> { now[0] })
      done = Thread::Queue.new
      worker = described_class.new(queue: -> { current[0] }, state: -> { free }, report: ->(_e) {},
                                   run: ->(action, _owner) { done << action }, sleeper: ->(_s) {}, idle_timeout: 0.01)
      thread = worker.start
      queue.add(0, 'old', wait_rt: false)
      expect(done.pop).to eq('old')
      current[0] = replacement
      replacement.add(0, 'new', wait_rt: false)
      expect(done.pop).to eq('new')
    ensure
      thread&.kill&.join
    end
  end

  # Globals.Events (Lists/Events.cs R; `#event`, Command.cs:1103-1132 R): absolute due times,
  # sorted, one released per tick before the CommandQueue (FormMain.cs:8321-8339 R; flow t220).
  describe 'the #event queue' do
    it 'sorts by due time (equal times keep add order); a non-positive or bad delay is due at once' do
      queue.add_event(1.0, 'one')
      queue.add_event(0.5, 'half')
      queue.add_event(-1.0, 'bad')
      queue.add_event(0.5, 'half2')
      queue.add_event(Float::NAN, 'nan')
      expect(queue.events.map(&:action)).to eq(%w[bad nan half half2 one])
      expect(queue.events.map { |e| e.due - epoch }).to eq([0.0, 0.0, 0.5, 0.5, 1.0])
    end

    it 'releases one due event per poll, nothing early, and clears' do
      queue.add_event(0.5, 'a')
      queue.add_event(0.5, 'b')
      queue.add_event(2.0, 'c')
      expect(queue.poll_event).to eq('')
      at(0.5)
      expect([queue.poll_event, queue.poll_event, queue.poll_event]).to eq(['a', 'b', ''])
      queue.clear_events
      at(5)
      expect(queue.poll_event).to eq('')
    end

    it 'refuses an infinite delay (DateTime.AddMilliseconds) and adds nothing' do
      expect { queue.add_event(Float::INFINITY, 'x') }.to raise_error(Lich::Genie::Error, /out of range/)
      expect(queue.events).to eq([])
    end

    it 'wakes an idle worker wait and is ticked before the command queue, ownerless' do
      ran = []
      worker = described_class::Worker.new(queue: queue, state: -> { free }, run: ->(action, owner) { ran << [action, owner] },
                                           report: ->(_e) {}, sleeper: ->(_s) {})
      queue.add(0, 'cmd', wait_rt: false, owner: :me)
      queue.add_event(0, 'ev')
      expect(queue.wait_for_items(0)).to be(true)
      expect(worker.tick).to eq(2)
      expect(ran).to eq([['ev', nil], ['cmd', :me]])
      queue.clear
      queue.add_event(0, 'only')
      expect(queue.wait_for_items(0)).to be(true)
    end
  end
end
