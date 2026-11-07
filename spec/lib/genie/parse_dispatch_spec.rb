# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# ParseDispatch: the `#parse` delivery shared by the Lich glue (GenieScript.parse_broadcast)
# and the flow harness. Remix ParseTriggers (FormMain.cs:4425-4512 R): the global #triggers,
# then every script's TriggerParse, all synchronous on the issuing thread.
RSpec.describe Lich::Genie::ParseDispatch do
  depth = Lich::Genie::DispatchDepth

  # A stand-in for the Triggers registry: yields [commands, captures] for every pattern that
  # matches, in order (the real registry's #apply contract).
  def triggers(*pairs)
    Object.new.tap do |t|
      t.define_singleton_method(:apply) do |text, &blk|
        pairs.each { |pattern, commands| (m = pattern.match(text)) && blk.call(commands, m.captures) }
      end
    end
  end

  def runner(log, raises: {})
    Object.new.tap do |r|
      r.define_singleton_method(:fire) do |commands, captures, **|
        raise raises[commands] if raises.key?(commands)

        log << [:fire, commands, captures]
      end
    end
  end

  def recipient(interpreter: Object.new, paused: false)
    described_class::Recipient.new(interpreter: interpreter, buffer: [], paused: paused)
  end

  def broadcast(text, recipients:, triggers: triggers(), log: [], errors: [], raises: {})
    described_class.broadcast(text, triggers: triggers, runner: runner(log, raises: raises),
                                    recipients: recipients, on_error: ->(e) { errors << e })
  end

  describe '.broadcast' do
    it 'fires the matching #triggers BEFORE queueing the text on the scripts' do
      log = []
      r = recipient
      r.buffer.define_singleton_method(:push) { |line| log << [:push, line.to_s] }
      broadcast('ring bell', recipients: [r], triggers: triggers([/^ring (\w+)/, '#echo x']), log: log)
      expect(log).to eq([[:fire, '#echo x', ['bell']], [:push, 'ring bell']])
    end

    it 'queues on every unpaused recipient, never on a paused one (TriggerParse returns when ScriptPaused, Script.cs:1181 R)' do
      live = recipient
      paused = recipient(paused: true)
      broadcast('PING', recipients: [live, paused])
      expect(live.buffer).to eq(['PING'])
      expect(paused.buffer).to be_empty
    end

    # Remix ParseTriggers walks m_oScriptList in order and calls each TriggerParse
    # synchronously, the issuing script's own at its position (FormMain.cs:4488-4489 R).
    describe 'script-list order with a dispatch owner' do
      def logging_recipient(log, name, interpreter: Object.new, paused: false)
        buffer = Object.new.tap { |b| b.define_singleton_method(:push) { |line| log << [:push, name, line.to_s] } }
        described_class::Recipient.new(interpreter: interpreter, buffer: buffer, paused: paused)
      end

      def owner_interpreter(log)
        Object.new.tap { |o| o.define_singleton_method(:deliver_parse) { |t| log << [:inline, t] } }
      end

      it 'queues on the scripts before the owner, delivers to the owner inline at its position, then queues on the rest' do
        log = []
        owner = owner_interpreter(log)
        list = [logging_recipient(log, 'a'), logging_recipient(log, 'own', interpreter: owner), logging_recipient(log, 'b')]
        described_class.as_owner(owner) { broadcast('PING', recipients: list) }
        expect(log).to eq([[:push, 'a', 'PING'], [:inline, 'PING'], [:push, 'b', 'PING']])
      end

      it 'never queues on the owner itself' do
        log = []
        owner = owner_interpreter(log)
        described_class.as_owner(owner) { broadcast('PING', recipients: [logging_recipient(log, 'own', interpreter: owner)]) }
        expect(log).to eq([[:inline, 'PING']])
      end

      it 'skips a paused owner (TriggerParse returns when ScriptPaused, Script.cs:1181 R)' do
        log = []
        owner = owner_interpreter(log)
        list = [logging_recipient(log, 'own', interpreter: owner, paused: true), logging_recipient(log, 'b')]
        described_class.as_owner(owner) { broadcast('PING', recipients: list) }
        expect(log).to eq([[:push, 'b', 'PING']])
      end

      it 'reads a callable paused flag when the line reaches the script (a #trigger of this line paused it)' do
        log = []
        owner = owner_interpreter(log)
        paused = false
        pausing = Object.new.tap { |r| r.define_singleton_method(:fire) { |_c, _caps, **| paused = true } }
        list = [logging_recipient(log, 'own', interpreter: owner, paused: -> { paused }),
                logging_recipient(log, 'b', paused: -> { paused })]
        described_class.as_owner(owner) do
          described_class.broadcast('PING', triggers: triggers([/PING/, '#script pause']), runner: pausing,
                                            recipients: list, on_error: ->(e) { raise e })
        end
        expect(log).to be_empty
      end

      it 'delivers nothing to an owner that is no longer in the script list' do
        log = []
        described_class.as_owner(owner_interpreter(log)) { broadcast('PING', recipients: [logging_recipient(log, 'b')]) }
        expect(log).to eq([[:push, 'b', 'PING']])
      end

      it 'lets the nesting-cap overflow from the owner unwind: the scripts after it get nothing' do
        log = []
        owner = Object.new.tap do |o|
          o.define_singleton_method(:deliver_parse) { |_t| raise Lich::Genie::DispatchDepth::Exceeded, 'cap' }
        end
        list = [logging_recipient(log, 'a'), logging_recipient(log, 'own', interpreter: owner), logging_recipient(log, 'b')]
        expect { described_class.as_owner(owner) { broadcast('PING', recipients: list) } }
          .to raise_error(Lich::Genie::DispatchDepth::Exceeded, 'cap')
        expect(log).to eq([[:push, 'a', 'PING']])
      end

      # Remix's TriggerParse of the owner faults
      # inside its own script (ours stops that script), but ParseTriggers still offers the line to
      # every script after it (FormMain.cs:4488-4489 R).
      def faulting_owner(log, error)
        Object.new.tap do |o|
          o.define_singleton_method(:deliver_parse) do |t|
            log << [:inline, t]
            raise error
          end
        end
      end

      it 'still queues on the scripts after an owner whose inline delivery faults, then re-raises the fault' do
        log = []
        owner = faulting_owner(log, RegexpError.new('end pattern with unmatched parenthesis'))
        list = [logging_recipient(log, 'a'), logging_recipient(log, 'own', interpreter: owner),
                logging_recipient(log, 'b'), logging_recipient(log, 'c')]
        expect { described_class.as_owner(owner) { broadcast('X', recipients: list) } }
          .to raise_error(RegexpError, /unmatched parenthesis/)
        expect(log).to eq([[:push, 'a', 'X'], [:inline, 'X'], [:push, 'b', 'X'], [:push, 'c', 'X']])
      end

      it 'keeps the nesting depth on the lines queued after a faulting owner and still skips paused scripts' do
        b = recipient
        paused = recipient(paused: true)
        owner = faulting_owner([], ArgumentError.new('boom'))
        own = described_class::Recipient.new(interpreter: owner, buffer: [], paused: false)
        expect do
          depth.nest('#parse X', on_overflow: ->(_m) {}) do
            described_class.as_owner(owner) { broadcast('X', recipients: [own, paused, b]) }
          end
        end.to raise_error(ArgumentError, 'boom')
        expect(described_class.depth_of(b.buffer.first)).to eq(1)
        expect(paused.buffer).to be_empty
        expect(own.buffer).to be_empty
      end
    end

    it 'queues on a script whose interpreter is not built yet when there is no owner (hook thread)' do
      unbuilt = recipient(interpreter: nil)
      broadcast('PING', recipients: [unbuilt])
      expect(unbuilt.buffer).to eq(['PING'])
    end

    it 'stamps every queued line with the nesting depth it was issued at, one object per recipient' do
      a = recipient
      b = recipient
      depth.nest('#parse PING', on_overflow: ->(_m) {}) do
        depth.nest('#parse PING', on_overflow: ->(_m) {}) { broadcast('PING', recipients: [a, b]) }
      end
      expect(a.buffer.first).to be_a(described_class::Line)
      expect(described_class.depth_of(a.buffer.first)).to eq(2)
      expect(a.buffer.first).not_to equal(b.buffer.first)
      expect(described_class.depth_of('a plain game line')).to eq(0)
    end

    # Remix: TriggerAction wraps each trigger's ParseCommand in its own try/catch
    # (FormMain.cs:4644-4654 R) and ParseCommand is an un-awaited async Task (Command.cs:219 R),
    # so a failing action only abandons ITS remaining commands; the trigger loop goes on.
    it 'reports a failing trigger action and still fires every remaining trigger, then reaches the scripts' do
      log = []
      errors = []
      r = recipient
      broadcast('PING', recipients: [r], log: log, errors: errors, raises: { 'bad' => RegexpError.new('boom') },
                        triggers: triggers([/PING/, 'bad'], [/PING/, 'good'], [/PING/, 'also']))
      expect(errors.map(&:message)).to eq(['boom'])
      expect(log).to eq([[:fire, 'good', []], [:fire, 'also', []]])
      expect(r.buffer).to eq(['PING'])
    end

    it 'reports every failing trigger action separately' do
      errors = []
      broadcast('PING', recipients: [], errors: errors,
                        raises: { 'a' => RegexpError.new('one'), 'b' => ArgumentError.new('two') },
                        triggers: triggers([/PING/, 'a'], [/PING/, 'b']))
      expect(errors.map(&:message)).to eq(%w[one two])
    end

    it 'never swallows the nesting-cap overflow: it must unwind to the outermost dispatcher' do
      r = recipient
      exceeded = Lich::Genie::DispatchDepth::Exceeded.new('cap')
      expect do
        broadcast('PING', recipients: [r], raises: { 'loop' => exceeded }, triggers: triggers([/PING/, 'loop']))
      end.to raise_error(Lich::Genie::DispatchDepth::Exceeded, 'cap')
      expect(r.buffer).to be_empty
    end
  end

  describe '.fire_trigger (one trigger action, shared with the downstream hook)' do
    it 'reports a failing action through on_error and returns normally' do
      errors = []
      described_class.fire_trigger(runner([], raises: { 'bad' => RegexpError.new('boom') }), 'bad', [],
                                   on_error: ->(e) { errors << e.message })
      expect(errors).to eq(['boom'])
    end

    it 'fires a good action with its captures and reports nothing' do
      log = []
      errors = []
      described_class.fire_trigger(runner(log), 'ok', ['x'], on_error: ->(e) { errors << e })
      expect(log).to eq([[:fire, 'ok', ['x']]])
      expect(errors).to be_empty
    end

    it 're-raises the nesting-cap overflow instead of reporting it' do
      errors = []
      exceeded = Lich::Genie::DispatchDepth::Exceeded.new('cap')
      expect do
        described_class.fire_trigger(runner([], raises: { 'loop' => exceeded }), 'loop', [], on_error: ->(e) { errors << e })
      end.to raise_error(Lich::Genie::DispatchDepth::Exceeded, 'cap')
      expect(errors).to be_empty
    end
  end

  # A line fed back from Lich's echo while a dispatch chain runs is stamped with the chain's
  # depth so the nesting cap stops an echo/#parse feedback loop.
  describe '.stamp' do
    it 'returns the plain text outside any dispatch' do
      line = described_class.stamp('PONG')
      expect(line).to eq('PONG')
      expect(line).not_to be_a(described_class::Line)
    end

    it 'stamps the current nesting depth inside a dispatch chain' do
      line = depth.nest('#parse A', on_overflow: ->(_m) {}) do
        depth.nest('#parse B', on_overflow: ->(_m) {}) { described_class.stamp('PONG') }
      end
      expect(line).to be_a(described_class::Line)
      expect(line).to eq('PONG')
      expect(described_class.depth_of(line)).to eq(2)
    end
  end

  # The glue's script-output feed (GenieScript.feed_script_output) is
  # this helper with the running genie scripts' downstream buffers, the global #triggers
  # and Lich's respond as +report+.
  describe '.feed_output' do
    def feed(text, buffers:, triggers: triggers(), log: [], errors: [], reports: [], raises: {})
      described_class.feed_output(text, buffers: buffers, triggers: triggers, runner: runner(log, raises: raises),
                                        on_error: ->(e) { errors << e }, report: ->(e) { reports << e })
    end

    it 'feeds the plain line to every buffer outside a dispatch chain, then fires the #triggers' do
      log = []
      a = []
      b = Object.new.tap { |buf| buf.define_singleton_method(:push) { |line| log << [:push, line] } }
      feed('Lich says hi', buffers: [a, b], triggers: triggers([/hi$/, '#echo t']), log: log)
      expect(a).to eq(['Lich says hi'])
      expect(a.first).not_to be_a(described_class::Line)
      expect(log).to eq([[:push, 'Lich says hi'], [:fire, '#echo t', []]])
    end

    it 'stamps the fed line with the running nesting depth inside a chain, one object per buffer' do
      a = []
      b = []
      depth.nest('#parse A', on_overflow: ->(_m) {}) do
        depth.nest('#parse B', on_overflow: ->(_m) {}) { feed('ECHO', buffers: [a, b]) }
      end
      expect(described_class.depth_of(a.first)).to eq(2)
      expect(described_class.depth_of(b.first)).to eq(2)
      expect(a.first).not_to equal(b.first)
    end

    it 'defers a nesting-cap overflow from the #triggers to the enclosing dispatch level (never reports it)' do
      reports = []
      overflows = []
      after = []
      exceeded = depth::Exceeded.new('cap')
      depth.nest('#echo LOOP', on_overflow: ->(m) { overflows << m }) do
        depth.nest('#echo LOOP', on_overflow: ->(_m) {}) do
          feed('LOOP', buffers: [], reports: reports, raises: { 'loop' => exceeded }, triggers: triggers([/LOOP/, 'loop']))
          after << :same_block
        end
        after << :outer_block
      end
      expect(reports).to be_empty
      expect(overflows).to eq(['cap'])
      expect(after).to eq([:same_block])
    end

    it 'reports a nesting-cap overflow itself when no dispatch chain encloses the feed' do
      reports = []
      exceeded = depth::Exceeded.new('cap')
      feed('LOOP', buffers: [], reports: reports, raises: { 'loop' => exceeded }, triggers: triggers([/LOOP/, 'loop']))
      expect(reports).to eq([exceeded])
      expect { depth.raise_pending! }.not_to raise_error
    end

    it 'reports a failing trigger action through on_error and fires the rest' do
      log = []
      errors = []
      feed('PING', buffers: [], log: log, errors: errors, raises: { 'bad' => RegexpError.new('boom') },
                   triggers: triggers([/PING/, 'bad'], [/PING/, 'good']))
      expect(errors.map(&:message)).to eq(['boom'])
      expect(log).to eq([[:fire, 'good', []]])
    end

    it 'still fires the #triggers when a buffer refuses the line' do
      log = []
      broken = Object.new.tap { |buf| buf.define_singleton_method(:push) { |_l| raise IOError, 'closed' } }
      feed('PING', buffers: [broken], log: log, triggers: triggers([/PING/, 'ok']))
      expect(log).to eq([[:fire, 'ok', []]])
    end
  end

  describe '.as_owner' do
    it 'restores the previous owner after the block, even when it raises' do
      outer = Object.new
      inner = Object.new
      described_class.as_owner(outer) do
        expect { described_class.as_owner(inner) { raise ArgumentError } }.to raise_error(ArgumentError)
        expect(described_class.owner).to equal(outer)
      end
      expect(described_class.owner).to be_nil
    end

    it 'is per fiber/thread: another script thread sees no owner' do
      seen = :unset
      described_class.as_owner(Object.new) { seen = Thread.new { described_class.owner }.value }
      expect(seen).to be_nil
    end
  end

  # Trigger-on-input. ClassCommand_SendText runs ParseTriggers(sText) after the send
  # (FormMain.cs:4391-4422 R) with bBufferWait = true (FormMain.cs:4425 R): the #triggers, then
  # every script's TriggerParse as a game line. No guard in Remix (flow t39): the nesting cap
  # counts each synchronous dispatch -- a #trigger fired, the sender's own inline TriggerParse.
  describe '.input' do
    def input(text, recipients:, triggers: triggers(), log: [], errors: [], overflows: [], runner: nil)
      described_class.input(text, triggers: triggers, runner: runner || runner(log), recipients: recipients,
                                  on_error: ->(e) { errors << e }, on_overflow: ->(m) { overflows << m })
    end

    it 'fires the #triggers, then queues the text on the scripts as a game line carrying the depth' do
      log = []
      r = recipient
      r.buffer.define_singleton_method(:push) { |line| log << [:push, line.to_s, line.game?, line.dispatch_depth] }
      input('ring bell', recipients: [r], triggers: triggers([/^ring (\w+)/, 'peer bell']), log: log)
      expect(log).to eq([[:fire, 'peer bell', ['bell']], [:push, 'ring bell', true, 0]])
    end

    it 'dispatches nothing for a Trim()-blank text (ParseTriggers: sText.Trim().Length > 0)' do
      log = []
      r = recipient
      input([0xA0].pack('U') + " \t", recipients: [r], triggers: triggers([/.*/, 'x']), log: log)
      expect([log, r.buffer]).to eq([[], []])
    end

    it 'skips a paused script (TriggerParse returns, Script.cs:1181 R)' do
      paused = recipient(paused: true)
      input('look', recipients: [paused])
      expect(paused.buffer).to eq([])
    end

    it "hands the sender's own copy inline as a game line, at its position" do
      log = []
      owner = Object.new
      owner.define_singleton_method(:deliver_parse) { |t, game: false| log << [:inline, t, game] }
      before = recipient
      before.buffer.define_singleton_method(:push) { |line| log << [:push, line.to_s] }
      described_class.as_owner(owner) do
        input('look', recipients: [before, described_class::Recipient.new(interpreter: owner, buffer: [], paused: false)])
      end
      expect(log).to eq([[:push, 'look'], [:inline, 'look', true]])
    end

    it 'counts one nesting level per #trigger it fires, not per send that fires none' do
      depths = []
      counting = Object.new
      counting.define_singleton_method(:fire) { |_c, _cap, **| depths << depth.current }
      input('look', recipients: [], triggers: triggers([/look/, 'a'], [/o/, 'b']), runner: counting)
      input('nothing', recipients: [], triggers: triggers([/look/, 'a']), runner: counting)
      expect([depths, depth.current]).to eq([[1, 1], 0])
    end

    it 'caps a trigger that re-sends its own text at LIMIT levels: one overflow, no more dispatch (flow t39)' do
      fired = [0]
      overflows = []
      pushed = []
      r = recipient
      r.buffer.define_singleton_method(:push) { |line| pushed << line }
      loop_triggers = triggers([/^ping$/, 'ping'])
      dispatch = described_class
      looping = Object.new
      looping.define_singleton_method(:fire) do |_c, _cap, **|
        fired[0] += 1
        dispatch.input('ping', triggers: loop_triggers, runner: self, recipients: [r], on_error: ->(e) { raise e },
                                      on_overflow: ->(m) { overflows << m })
      end
      input('ping', recipients: [r], triggers: loop_triggers, runner: looping, overflows: overflows)
      expect(fired[0]).to eq(depth::LIMIT)
      expect(overflows).to eq(["Script error: maximum nested dispatch depth (#{depth::LIMIT}) exceeded on: input ping"])
      expect(pushed).to eq([]) # the capped chain stops before any script gets the text
      expect(depth.current).to eq(0)
    end

    it "stops the owning script at the cap instead of printing (VariableDispatch.overflow_handler)" do
      stopped = []
      owner = Object.new
      owner.define_singleton_method(:dispatch_overflow) { |m| stopped << m }
      owner.define_singleton_method(:deliver_parse) { |*| nil }
      overflows = []
      loop_triggers = triggers([/^ping$/, 'ping'])
      dispatch = described_class
      looping = Object.new
      looping.define_singleton_method(:fire) do |_c, _cap, **|
        dispatch.input('ping', triggers: loop_triggers, runner: self, recipients: [], on_error: ->(e) { raise e },
                                      on_overflow: ->(m) { overflows << m })
      end
      described_class.as_owner(owner) { input('ping', recipients: [], triggers: loop_triggers, runner: looping, overflows: overflows) }
      expect([stopped.length, overflows]).to eq([1, []])
    end

    it "re-raises the sender's own inline fault after the scripts behind it got the text" do
      log = []
      owner = Object.new
      owner.define_singleton_method(:deliver_parse) { |*| raise ArgumentError, 'eval fault' }
      after = recipient
      after.buffer.define_singleton_method(:push) { |line| log << line.to_s }
      expect do
        described_class.as_owner(owner) do
          input('look', recipients: [described_class::Recipient.new(interpreter: owner, buffer: [], paused: false), after])
        end
      end.to raise_error(ArgumentError, 'eval fault')
      expect(log).to eq(['look'])
    end
  end
end
