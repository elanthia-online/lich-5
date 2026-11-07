# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Lich::Genie::VariableDispatch: Remix FormMain.TriggerVariableChanged (FormMain.cs:4725-4989 R)
# over the REAL Triggers registry, TriggerRunner and interpreters. Flow goldens: t40 (eval
# #trigger chain), t124 (game variables, compass blocked, key == name), t125 (script list),
# t51 (the nesting cap, decided).
RSpec.describe Lich::Genie::VariableDispatch do
  let(:store) { Lich::Genie::GlobalStore.new }
  let(:vars) { Lich::Genie::Variables.new(global_store: store) }
  let(:triggers) { Lich::Genie::Triggers.new }
  let(:echoes) { [] }
  let(:sends) { [] }
  let(:errors) { [] }
  let(:overflows) { [] }
  let(:runner) do
    globals = Object.new
    globals.define_singleton_method(:key?) { |name| vars.global_key?(name) }
    game = Object.new
    sent = sends
    game.define_singleton_method(:send_command) { |text| sent << text }
    dispatch = self
    Lich::Genie::TriggerRunner.new(vars: vars, eval: Lich::Genie::Eval.new(globals: globals), game: game,
                                   launch: ->(_n, _a) {}, echo: ->(text) { echoes << text },
                                   var_changed: ->(name) { dispatch.broadcast(name) })
  end
  let(:recipients) { [] }

  def broadcast(names, queue_owner: false)
    described_class.broadcast(names, triggers: triggers, runner: runner, recipients: recipients,
                                     on_error: ->(e) { errors << e.message }, on_overflow: ->(m) { overflows << m },
                                     queue_owner: queue_owner)
  end

  # A recipient whose interpreter records deliveries (the owner path) and whose buffer
  # records queued changes; +wants+ = Interpreter#wants_variable_change? (true, false, or a callable(name)).
  def recipient(paused: false, wants: true)
    delivered = []
    interp = Object.new
    interp.define_singleton_method(:deliver_variable_change) { |name| delivered << name }
    interp.define_singleton_method(:wants_variable_change?) { |name| wants.respond_to?(:call) ? wants.call(name) : wants }
    buffer = []
    [Lich::Genie::ParseDispatch::Recipient.new(interpreter: interp, buffer: buffer, paused: paused), delivered, buffer]
  end

  describe 'eval #triggers (FormMain.cs:4936-4963 R)' do
    it 'fires a trigger whose key contains the name and evaluates true, with $globals expanded (t40 shape)' do
      triggers.add('e/$ta = 1/', '#echo fired-$ta')
      vars.global_set('ta', '1')
      broadcast('$ta')
      expect(echoes).to eq(['fired-1'])
    end

    it 'does not fire on "0" or an empty result, nor for a name the key does not contain' do
      triggers.add('e/$ta = 1/', '#echo no')
      triggers.add('e/$tb/', '#echo empty') # key == name fires unevaluated, so use another name
      vars.global_set('ta', '0')
      broadcast('$ta')
      broadcast('$zz')
      expect(echoes).to eq([])
    end

    it 'fires a key EQUAL to the name without evaluating it, even when the value is 0 (t124 TRIG-STANDING)' do
      triggers.add('e/$standing/', '#echo standing')
      vars.global_set('standing', '0')
      broadcast('$standing')
      expect(echoes).to eq(['standing'])
    end

    it 'matches by substring: a change of $t wakes a $tb key (String.Contains)' do
      triggers.add('eval $tb = 1', '#echo tb')
      vars.global_set('tb', '1')
      broadcast('$t')
      expect(echoes).to eq(['tb'])
    end

    it 'never fires an inactive trigger, nor a regex trigger' do
      triggers.add('e/$ta = 1/', '#echo off', klass: 'k')
      triggers.toggle_class('k', false)
      triggers.add('$ta', '#echo regex') # a regex trigger keyed "$ta" (no e/)
      vars.global_set('ta', '1')
      broadcast('$ta')
      expect(echoes).to eq([])
    end

    it 'runs a nested change from a trigger body synchronously (t40: the chain fires)' do
      triggers.add('e/$ta = 1/', '#var tb 1')
      triggers.add('e/$tb = 1/', '#echo tb-fired')
      vars.global_set('ta', '1')
      broadcast('$ta')
      expect(echoes).to eq(['tb-fired'])
    end

    it 'reports a failing condition (an invalid matchre pattern) and still fires the next trigger' do
      triggers.add('e/matchre("$ta", "(")/', '#echo bad')
      triggers.add('e/$ta = 1/', '#echo good')
      vars.global_set('ta', '1')
      broadcast('$ta')
      expect(echoes).to eq(%w[good])
      expect(errors.length).to eq(1)
    end
  end

  describe 'blocked names (FormMain.cs:4779-4795 R)' do
    it 'returns before triggers and scripts for compass and every direction (t124 NORTH)' do
      triggers.add('e/compass/', '#echo compass')
      triggers.add('e/$north/', '#echo north')
      entry, delivered, buffer = recipient
      recipients << entry
      described_class::BLOCKED.each { |name| broadcast(name) }
      expect([echoes, delivered, buffer]).to eq([[], [], []])
      expect(described_class::BLOCKED).to include('compass', '$north', '$out')
    end
  end

  describe 'the script loop (FormMain.cs:4964-4969 R)' do
    it 'queues a Change with the nesting depth for every unpaused script when no script owns the thread' do
      a, a_delivered, a_buffer = recipient
      b, _b_delivered, b_buffer = recipient(paused: true)
      recipients.push(a, b)
      broadcast('$health')
      triggers.add('e/$mana/', '#echo m')
      broadcast('$mana') # wakes a trigger: one dispatch level, carried by the queued change
      expect(a_delivered).to eq([])
      # the trigger's firing is a sibling of the script loop, not its ancestor: depth 0
      expect(a_buffer.map { |c| [c.class, c.entries, c.to_s] })
        .to eq([[described_class::Change, [['$health', 0]], '$health'], [described_class::Change, [['$mana', 0]], '$mana']])
      expect(b_buffer).to eq([]) # paused: nothing, and nothing replayed later (t125)
    end

    it 'stamps a change raised inside a firing with that firing\'s depth' do
      a, _a_delivered, a_buffer = recipient
      recipients << a
      triggers.add('e/$mana/', '#var nested 1')
      broadcast('$mana')
      expect(a_buffer.map(&:entries)).to eq([[['$nested', 1]], [['$mana', 0]]])
    end

    # Every queued entry takes a slot in the script's 400-line Lich buffer.
    it 'queues only the names a script can react to, but still hands the owner its own' do
      a, _a_delivered, a_buffer = recipient(wants: ->(name) { name == '$z' })
      b, b_delivered, b_buffer = recipient(wants: false)
      recipients.push(a, b)
      Lich::Genie::ParseDispatch.as_owner(b.interpreter) { broadcast('$x') }
      broadcast(%w[$y $z $w])
      expect([a_buffer.map(&:entries), b_delivered, b_buffer]).to eq([[[['$z', 0]]], ['$x'], []])
    end

    it 'coalesces the names of one call into ONE Change per script, in raise order' do
      a, _a_delivered, a_buffer = recipient
      b, _b_delivered, b_buffer = recipient
      recipients.push(a, b)
      broadcast(%w[$health compass $mana $prompt])
      expect([a_buffer, b_buffer].map { |buffer| buffer.map(&:entries) })
        .to eq([[[['$health', 0], ['$mana', 0], ['$prompt', 0]]]] * 2)
      expect(a_buffer.first.to_s).to eq('$health $mana $prompt')
    end

    it 'splits the batch where an eval #trigger fires, so its nested change keeps Remix\'s order' do
      a, _a_delivered, a_buffer = recipient
      recipients << a
      triggers.add('e/$mana/', '#var nested 1')
      broadcast(%w[$health $mana $prompt])
      expect(a_buffer.map(&:names)).to eq([%w[$health], %w[$nested], %w[$mana $prompt]])
    end

    it 'splits the batch at the owner\'s inline delivery, which may raise nested changes' do
      a, _a_delivered, a_buffer = recipient
      owner = Object.new
      seen = a_buffer
      dispatch = self
      owner.define_singleton_method(:wants_variable_change?) { |_name| true }
      owner.define_singleton_method(:deliver_variable_change) do |name|
        seen << :owner_before_nested if name == '$b'
        dispatch.broadcast('$nested') if name == '$b'
      end
      recipients.push(a, Lich::Genie::ParseDispatch::Recipient.new(interpreter: owner, buffer: [], paused: false))
      Lich::Genie::ParseDispatch.as_owner(owner) { broadcast(%w[$a $b $c]) }
      # "a" is listed before the owner: each name reaches it before the owner runs
      expect(a_buffer.map { |c| c.is_a?(Symbol) ? c : c.names }).to eq([%w[$a], %w[$b], :owner_before_nested, %w[$nested], %w[$c]])
    end

    it 'keeps the batch whole across an owner that cannot use a change (its delivery runs nothing)' do
      a, _a_delivered, a_buffer = recipient
      owner, owner_delivered, = recipient(wants: false)
      recipients.push(a, owner)
      Lich::Genie::ParseDispatch.as_owner(owner.interpreter) { broadcast(%w[lastinput lastcommand]) }
      expect([a_buffer.map(&:names), owner_delivered]).to eq([[%w[lastinput lastcommand]], %w[lastinput lastcommand]])
    end

    it 'queues for the owner too with queue_owner (a #goto walk\'s "scriptlist", read by its NEXT row)' do
      a, a_delivered, a_buffer = recipient
      recipients << a
      Lich::Genie::ParseDispatch.as_owner(a.interpreter) { broadcast('scriptlist', queue_owner: true) }
      expect([a_delivered, a_buffer.map(&:names)]).to eq([[], [%w[scriptlist]]])
    end

    it 'skips a recipient whose interpreter is not built yet' do
      recipients << Lich::Genie::ParseDispatch::Recipient.new(interpreter: nil, buffer: (buffer = []), paused: false)
      expect { broadcast('$x') }.not_to raise_error
      expect(buffer).to eq([])
    end

    it 'hands the change to the owner inline and queues the others in list order' do
      a, a_delivered, a_buffer = recipient
      b, b_delivered, b_buffer = recipient
      recipients.push(a, b)
      Lich::Genie::ParseDispatch.as_owner(b.interpreter) { broadcast('%x') }
      expect([a_delivered, a_buffer.map(&:names), b_delivered, b_buffer]).to eq([[], [['%x']], ['%x'], []])
    end

    it 'reads the paused flag when the change reaches the script (a callable)' do
      flag = [false]
      entry, _delivered, buffer = recipient(paused: -> { flag[0] })
      recipients << entry
      flag[0] = true
      broadcast('$x')
      expect(buffer).to eq([])
    end

    it 'fires the eval triggers before any script sees the change' do
      triggers.add('e/$x/', '#echo trigger')
      interp = Object.new
      seen = echoes
      interp.define_singleton_method(:deliver_variable_change) { |_n| seen << 'script' }
      interp.define_singleton_method(:wants_variable_change?) { |_name| true }
      recipients << Lich::Genie::ParseDispatch::Recipient.new(interpreter: interp, buffer: [], paused: false)
      Lich::Genie::ParseDispatch.as_owner(interp) { broadcast('$x') }
      expect(echoes).to eq(%w[trigger script])
    end
  end

  describe 'the nesting cap (decided; Remix crashes, t51)' do
    it 'stops a self-feeding eval trigger chain at LIMIT levels with one overflow report' do
      triggers.add('e/$loop/', '#var loop 1')
      broadcast('$loop')
      expect(overflows).to eq(['Script error: maximum nested dispatch depth (20) exceeded on: variable change $loop'])
      expect(Lich::Genie::DispatchDepth.current).to eq(0)
    end

    it 'counts FIRINGS, not checks: a 21st candidate whose condition is false is no level' do
      limit = Lich::Genie::DispatchDepth::LIMIT
      (1..limit).each { |i| triggers.add("e/$c#{i}x/", "#var c#{i + 1}x 1") }
      triggers.add("e/$c#{limit + 1}x = 2/", '#echo never') # checked at depth 20, false
      broadcast('$c1x')
      expect([overflows, echoes, errors]).to eq([[], [], []])
      expect(store.get("c#{limit + 1}x")).to eq('1')
    end

    it 'ends the broadcast at an outermost overflow: no later trigger, no script gets the change' do
      a, _a_delivered, a_buffer = recipient
      recipients << a
      triggers.add('e/$loop/', '#var loop 1')
      triggers.add('e/$loop = 1/', '#echo second')
      broadcast(%w[$loop $after])
      expect(overflows.length).to eq(1)
      expect(echoes).to eq([])
      expect(a_buffer.flat_map(&:names)).not_to include('$after')
    end

    it 'gives the overflow to the owning script instead of the host when one owns the thread' do
      owner = Object.new
      stopped = []
      owner.define_singleton_method(:dispatch_overflow) { |m| stopped << m }
      triggers.add('e/$loop/', '#var loop 1')
      Lich::Genie::ParseDispatch.as_owner(owner) { broadcast('$loop') }
      expect([stopped.length, overflows]).to eq([1, []])
    end

    it 'counts one level per broadcast that wakes a trigger: LIMIT such levels run, one more is capped' do
      # "$c1x" is no substring of "$c11x": each change wakes exactly one trigger.
      limit = Lich::Genie::DispatchDepth::LIMIT
      (1..limit + 1).each { |i| triggers.add("e/$c#{i}x/", "#var c#{i + 1}x 1") }
      broadcast('$c1x')
      expect(overflows).to eq(["Script error: maximum nested dispatch depth (#{limit}) exceeded on: variable change $c#{limit + 1}x"])
      expect(store.get("c#{limit + 1}x")).to eq('1') # set by level 20; its own broadcast is level 21
      overflows.clear
      triggers.remove("e/$c#{limit + 1}x/") # the change at depth 21 now wakes nothing: no level
      broadcast('$c1x')
      expect(overflows).to eq([])
      expect(store.get("c#{limit + 2}x")).to be_nil
    end

    it 're-raises the overflow through a failing-action rescue (not reported as a trigger error)' do
      triggers.add('e/$loop/', '#var loop 1')
      broadcast('$loop')
      expect(errors).to eq([])
    end
  end

  describe 'Change' do
    it 'is a String holding the names (Lich buffers and Script#gets carry it as a line)' do
      name = +'$x'
      change = described_class::Change.new(name, 3)
      name << 'y'
      expect(change).to be_a(String)
      expect([change.to_s, change.entries, change.names, change.entries.frozen?, change.names.first.frozen?])
        .to eq(['$x', [['$x', 3]], ['$x'], true, true])
    end

    it 'carries a batch in order, each name with its own depth' do
      change = described_class::Change.batch([['$a', 0], ['%b', 2]])
      expect([change.to_s, change.entries]).to eq(['$a %b', [['$a', 0], ['%b', 2]]])
    end

    # A game row's batch is part of its DR packet; the reading interpreter holds its
    # resumes until the packet ends.
    it 'says whether a game row raised it (false unless told, a boolean either way)' do
      expect(described_class::Change.new('$x', 0).game?).to be(false)
      expect(described_class::Change.new('$x', 0, game: 1).game?).to be(true)
      expect(described_class::Change.batch([['$a', 0], ['$b', 0]], game: true).game?).to be(true)
      expect(described_class::Change.batch([['$a', 0]]).game?).to be(false)
    end
  end

  describe 'a game row\'s broadcast' do
    it 'queues its batch as a game Change; any other broadcast queues a plain one; the owner still gets it inline' do
      queued, = recipient
      own, delivered, own_buffer = recipient
      recipients.push(queued, own)
      described_class.broadcast(%w[$health $mana], triggers: triggers, runner: runner, recipients: recipients,
                                                   on_error: ->(e) { errors << e }, on_overflow: ->(m) { overflows << m }, game: true)
      broadcast('lastcommand')
      expect(queued.buffer.map { |change| [change.names, change.game?] }).to eq([[%w[$health $mana], true], [['lastcommand'], false]])
      Lich::Genie::ParseDispatch.as_owner(own.interpreter) do
        described_class.broadcast('$spirit', triggers: triggers, runner: runner, recipients: [own],
                                             on_error: ->(e) { errors << e }, on_overflow: ->(m) { overflows << m }, game: true)
      end
      expect(delivered).to include('$spirit')
      expect(own_buffer.map(&:names).flatten).not_to include('$spirit')
    end
  end

  describe '.truthy?' do
    it 'is EvalString non-empty and not "0" (Script.cs:1386 R)' do
      expect(['1', 'x', '0.0', ' ', '', '0'].map { |t| described_class.truthy?(t) }).to eq([true, true, true, true, false, false])
    end
  end
end
