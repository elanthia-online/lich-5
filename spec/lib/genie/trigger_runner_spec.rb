# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::TriggerRunner do
  let(:vars) { Lich::Genie::Variables.new(game_state: { 'unixtime' => '1000' }) }
  let(:evaluator) do
    globals = Object.new
    globals.define_singleton_method(:key?) { |name| vars.global_key?(name) }
    Lich::Genie::Eval.new(globals: globals)
  end
  let(:sent) { [] }
  let(:launched) { [] }
  let(:hooks) { [] }
  let(:game) { Object.new.tap { |o| s = sent; o.define_singleton_method(:send_command) { |t| s << t } } }
  let(:hook_sink) { Object.new.tap { |o| h = hooks; o.define_singleton_method(:emit) { |op, pl| h << [op, pl] } } }
  let(:lists) { Lich::Genie::Lists.new }
  let(:runner) do
    described_class.new(
      vars: vars, eval: evaluator, game: game,
      launch: ->(name, args) { launched << [name, args] },
      hooks: hook_sink, echo: ->(_t) {}, lists: lists
    )
  end

  it 'marks the body\'s sends with the origin "Trigger" while it runs, and restores the previous one' do
    origins = []
    game.define_singleton_method(:send_command) { |_t| origins << Thread.current[Lich::Genie::TriggerRunner::ORIGIN_KEY] }
    Thread.current[described_class::ORIGIN_KEY] = 'outer'
    runner.fire('look;smile', [])
    expect([origins, Thread.current[described_class::ORIGIN_KEY]]).to eq([%w[Trigger Trigger], 'outer'])
    runner.run_command('bow') # a queue release: origin as the caller left it
    expect(origins.last).to eq('outer')
  ensure
    Thread.current[described_class::ORIGIN_KEY] = nil
  end

  # PR #1813 review item 3: the glue's gate (the engine on for the character), asked per body.
  it 'runs no body while +active+ says no -- the origin of the caller untouched -- and runs it again once it says yes' do
    on = [false]
    gated = described_class.new(vars: vars, eval: evaluator, game: game, launch: ->(*) {}, lists: lists, active: -> { on[0] })
    Thread.current[described_class::ORIGIN_KEY] = 'outer'
    gated.fire('look', [])
    expect([sent, Thread.current[described_class::ORIGIN_KEY]]).to eq([[], 'outer'])
    on[0] = true
    gated.fire('look', [])
    expect(sent).to eq(['look'])
  ensure
    Thread.current[described_class::ORIGIN_KEY] = nil
  end

  # Only author-written text may issue a Lich command (security; a decided divergence): an
  # authored body is the user's own text; the captures are another player's words.
  it 'makes a row of an authored body the user wrote with a leading , a Lich command, never one a capture brings' do
    queue = Lich::Genie::CommandQueue.new
    queued = described_class.new(vars: vars, eval: evaluator, game: game, launch: ->(*) {}, lists: lists, queue: queue)
    queued.fire(',go2 $1;$2;#send $2', ['12', ',e 1'], authored: true)
    queue.drain(-> { Lich::Genie::CommandQueue::FREE }) { |action| queued.run_command(action) }
    expect(sent.map { |t| [t.to_s, t.is_a?(Lich::Genie::LichCommand)] }).to eq([[',go2 12', true], [',e 1', false], [',e 1', false]])
  end

  # Provenance is the trigger's, decided when it was defined; the default is not authored.
  it 'sends every , row of a body that is not authored (the default) as game text' do
    runner.fire(',go2 1;,kill x', [])
    expect(sent.map { |t| [t.to_s, t.is_a?(Lich::Genie::LichCommand)] }).to eq([[',go2 1', false], [',kill x', false]])
  end

  # No #trigger body runs code, authored or not.
  it 'sends a code-running Lich command of an authored body as game text, a plain one as a Lich command' do
    runner.fire(',e 1;,eq 2;,exec 3;,execname n 4;,l5u --branch=x:y;,go2 5', [], authored: true)
    expect(sent.map { |t| [t.to_s, t.is_a?(Lich::Genie::LichCommand)] })
      .to eq([[',e 1', false], [',eq 2', false], [',exec 3', false], [',execname n 4', false], [',l5u --branch=x:y', false],
              [',go2 5', true]])
  end

  # What a body defines is authored only when the body is and no
  # capture went into it.
  it 'defines an authored #trigger/#alias only from an authored body that no capture changed' do
    runner.fire('#trigger {^a} {,go2 1};#alias {,x} {,go2 2}', [], authored: true)
    runner.fire('#trigger {^b} {$1};#alias {,y} {$1}', [',go2 3'], authored: true)
    runner.fire('#trigger {^c} {,go2 4}', [], authored: false)
    runner.fire('#trigger {^d} {,go2 5};#nop $1', [''], authored: true) # a $n replaced by "" changes the body too
    expect(%w[^a ^b ^c ^d ^none].map { |key| lists.triggers.authored?(key) }).to eq([true, false, false, false, nil])
    expect([lists.aliases.authored?(',x'), lists.aliases.authored?(',y')]).to eq([true, false])
  end

  it 'defines nothing authored from a queue release or a typed command (run_command)' do
    runner.run_command('#trigger {^q} {,go2 1}')
    expect(lists.triggers.authored?('^q')).to be(false)
  end

  it 'leaves the definition context of its caller as it was' do
    Lich::Genie::AuthoredCommand.defining(true) do
      runner.fire('look', [], authored: false)
      expect(Lich::Genie::AuthoredCommand.authored_definitions?).to be(true)
    end
    expect(Lich::Genie::AuthoredCommand.authored_definitions?).to be(false)
  end

  it 'sends a plain game command with captures substituted' do
    runner.fire('put attack $1', ['kobold'])
    expect(sent).to eq(['put attack kobold'])
  end

  it 'runs a #command (updates a global via #var)' do
    runner.fire('#var mode hunting', [])
    expect(vars.global_get('mode')).to eq('hunting')
  end

  it 'evaluates an inline #evalmath over a reserved var (the corpus pattern)' do
    runner.fire('#var deadline #evalmath ($unixtime + 20)', [])
    expect(vars.global_get('deadline')).to eq('1020')
  end

  it 'runs several ;-separated commands, not splitting inside braces' do
    runner.fire('#var a 1;#if {1 = 1} {#var b 2};put done', [])
    expect(vars.global_get('a')).to eq('1')
    expect(vars.global_get('b')).to eq('2')
    expect(sent).to eq(['put done'])
  end

  it 'launches a script when a command starts with the script char' do
    runner.fire('.helper $1', ['now'])
    expect(launched).to eq([['helper', 'now']])
    expect(sent).to be_empty
  end

  it 'names the launched script by ParseArgs token 0, lower-cased (FormMain.cs:4683-4684 R)' do
    runner.fire('._PC{a_b} c', [])
    expect(launched).to eq([['_pc', '{a_b} c']])
    expect(Lich::Genie::ScriptArgs.parse_launch(*launched.first)).to eq(['a b', 'c'])
  end

  it 'switches a class from within a trigger body (the class event re-applies the list)' do
    lists.triggers.add('^x', 'y', klass: 'combat')
    runner.fire('#class combat off', [])
    expect(lists.classes['combat']).to be(false)
    expect(lists.triggers.entries.first[4]).to be(false)
    expect(hooks).to eq([['class', { 'classes' => { 'combat' => false, 'default' => true } }]])
  end

  # A corpus casting trigger (shape in spec/fixtures/genie/trigger_setup.cmd) wraps its whole
  # reset block -- ending in `#class casting off` -- inside a single `#if` branch.
  # Before the do_if ;-split fix only the first sub-command ran, so `charges` never
  # cleared and `#class casting off` never fired: "triggers/#class do not work".
  it 'runs the full reset block of an #if-wrapped trigger body (the casting-reset pattern)' do
    vars.global_set('alt', '0')
    vars.global_set('charges', '3')
    vars.global_set('abilityready', '1')
    action = '#if {($alt = 0)} {#if {($charges != 0)} {#var charges 0};' \
             '#if {($abilityready != 0)} {#var abilityready 0};#var prepping 0;#class casting off}'
    runner.fire(action, [])
    expect(vars.global_get('charges')).to eq('0')
    expect(vars.global_get('abilityready')).to eq('0')
    expect(vars.global_get('prepping')).to eq('0')
    expect(lists.classes['casting']).to be(false)
  end

  # FormMain.TriggerAction (FormMain.cs:4615-4657 R; flow t139_trigger_action_args, t133).
  describe 'TriggerAction ($n pass, then ParseCommand with bSendToGame)' do
    it 'replaces $1..$15 low to high with quotes removed, "" past the groups, then $0 with the FIRST group' do
      out = described_class.substitute_captures('[$0] [$1] [$2] [$3] [$10] [$15] [$16]', ['"quoted"', 'word'])
      expect(out).to eq('[quoted] [quoted] [word] [] [quoted0] [quoted5] [quoted6]') # $1 goes first: $10/$15/$16 are $1 + a digit
    end

    it 'leaves a body without $ untouched and $0 empty with no groups; a value is never a backreference' do
      expect(described_class.substitute_captures('look', ['x'])).to eq('look')
      expect(described_class.substitute_captures('say [$0]', [])).to eq('say []')
      expect(described_class.substitute_captures('say $1', ['a\\0b'])).to eq('say a\\0b')
    end

    it 'expands $globals per row at run time (not the body first), never %locals' do
      vars.global_set('probe', 'late')
      vars.local_set('l', 'LOCAL')
      runner.fire('say $1 and $probe %l;#var copy $probe', ['x'])
      expect(sent).to eq(['say x and late %l'])
      expect(vars.global_get('copy')).to eq('late')
    end

    it 'splits a capture holding the separator like Remix (captures go in before the split)' do
      runner.fire('#var semi $1', ['a;look'])
      expect(vars.global_get('semi')).to eq('a')
      expect(sent).to eq(['look'])
    end

    it "queues a #send (a tester's login trigger shape `lang switch com;#send 2 .startup`)" do
      now = [Time.at(0)]
      queue = Lich::Genie::CommandQueue.new(clock: -> { now[0] })
      r = described_class.new(vars: vars, eval: evaluator, game: game, launch: ->(n, a) { launched << [n, a] }, queue: queue)
      r.fire('lang switch com;#send 2 .startup', [])
      expect(sent).to eq(['lang switch com'])
      expect(queue.items.map { |i| [i.delay, i.action, i.wait_rt] }).to eq([[2.0, '.startup', true]])
      now[0] = Time.at(2) # RunQueueCommand when it is due: the queued `.startup` launches
      queue.drain(-> { Lich::Genie::CommandQueue::FREE }) { |action| r.run_command(action) }
      expect(launched).to eq([['startup', '']])
    end

    it 'ends the body quietly at a fault (the ParseCommand Task is not awaited, FormMain.cs:4645-4655 R)' do
      expect { runner.fire("#var ok 1;#var {'} {2};say never", []) }.not_to raise_error
      expect(vars.global_get('ok')).to eq('1')
      expect(sent).to be_empty
    end
  end

  # A trigger body's #parse (TriggerAction -> ParseCommand -> ParseTriggers, FormMain.cs:
  # 4615-4655, 4425 R) and the nesting cap on a trigger chain.
  describe '#parse in a trigger body' do
    let(:echoes) { [] }

    it 'hands the text, captures substituted, to the parse port' do
      parsed = []
      r = described_class.new(vars: vars, eval: evaluator, game: game, launch: ->(*) {}, echo: ->(t) { echoes << t },
                              parse: ->(t) { parsed << t })
      r.fire('#parse MOVE $1;look', ['SUCCESSFUL'])
      expect(parsed).to eq(['MOVE SUCCESSFUL'])
      expect(sent).to eq(['look'])
    end

    it 'stops a self-re-firing trigger chain at the nesting cap with one error line' do
      fired = 0
      r = nil
      r = described_class.new(vars: vars, eval: evaluator, game: game, launch: ->(*) {}, echo: ->(t) { echoes << t },
                              parse: lambda { |t|
                                fired += 1
                                r.fire('#parse BOOM;after', []) if t == 'BOOM' # the trigger re-matches its own text
                              })
      r.fire('#parse BOOM;first', [])
      limit = Lich::Genie::DispatchDepth::LIMIT
      expect(fired).to eq(limit)
      expect(echoes).to eq(["[Script error: maximum nested dispatch depth (#{limit}) exceeded on: #parse BOOM]"])
      expect(sent).to eq(['first']) # the overflow unwinds every level: no inner `after` is sent
      expect(Lich::Genie::DispatchDepth.current).to eq(0)
    end
    # Remix's ParseTriggers offers the nested text to EVERY script synchronously in list
    # order, the script whose own #parse started the chain included at its own position
    # (FormMain.cs:4488-4489 R). That is the host port's job (ParseDispatch.broadcast calls
    # the owner's deliver_parse there); the runner must not deliver it a second time.
    it 'hands a nested #parse to the host port only, never straight to the dispatching script' do
      log = []
      owner = Object.new.tap { |o| o.define_singleton_method(:deliver_parse) { |t| log << [:inline, t] } }
      r = described_class.new(vars: vars, eval: evaluator, game: game, launch: ->(*) {}, echo: ->(t) { echoes << t },
                              parse: ->(t) { log << [:host, t, Lich::Genie::DispatchDepth.current] })
      Lich::Genie::ParseDispatch.as_owner(owner) { r.fire('#parse Y $1', ['z']) }
      expect(log).to eq([[:host, 'Y z', 1]])
    end

    it 'delivers nothing inline when no script is dispatching (a game-line trigger on the hook thread)' do
      parsed = []
      r = described_class.new(vars: vars, eval: evaluator, game: game, launch: ->(*) {}, echo: ->(t) { echoes << t },
                              parse: ->(t) { parsed << t })
      expect { r.fire('#parse Y', []) }.not_to raise_error
      expect(parsed).to eq(['Y'])
    end
  end

  # FormMain's eval-trigger condition (FormMain.cs:4946-4957 R).
  describe '#eval_true?' do
    it 'holds for a key equal to the name without evaluating it' do
      expect(runner.eval_true?('$nope', '$nope')).to be(true)
    end

    it 'evaluates ParseGlobalVars(key): $globals and @specials, never %locals' do
      vars.global_set('hp', '40')
      expect(runner.eval_true?('$hp < 50', '$hp')).to be(true)
      expect(runner.eval_true?('$hp > 50', '$hp')).to be(false)
      expect(runner.eval_true?('$unixtime = 1000', '$unixtime')).to be(true) # the reserved value
      vars.local_set('l', '1')
      expect(runner.eval_true?('%l = 1', '%l')).to be(false) # "%l = 1" stays literal
    end

    it 'is false for "0" and for an empty result, true for any other text' do
      expect(runner.eval_true?('0', 'x')).to be(false)
      expect(runner.eval_true?('', 'x')).to be(false)
      expect(runner.eval_true?('abc', 'x')).to be(true)
    end

    it 'hands a body\'s #var to the var_changed port' do
      seen = []
      wired = described_class.new(vars: vars, eval: evaluator, game: game, launch: ->(_n, _a) {},
                                  var_changed: ->(name) { seen << name })
      wired.fire('#var tb 1;#math tb add 1', [])
      expect(seen).to eq(%w[$tb $tb])
    end
  end
end
