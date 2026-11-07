# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

RSpec.describe Lich::Genie::CommandRouter do
  let(:vars) { Lich::Genie::Variables.new }
  let(:evaluator) { Lich::Genie::Eval.new(globals: globals_adapter) }
  let(:globals_adapter) do
    Object.new.tap { |o| o.define_singleton_method(:key?) { |name| vars.global_key?(name) } }
  end
  let(:echoes) { [] }
  let(:sends) { [] }
  let(:hooks) { [] }
  let(:hook_sink) do
    collected = hooks
    Object.new.tap { |o| o.define_singleton_method(:emit) { |op, payload| collected << [op, payload] } }
  end
  let(:moves) { [] }
  let(:lists) { Lich::Genie::Lists.new }
  let(:router) do
    described_class.new(
      vars: vars, eval: evaluator, hooks: hook_sink,
      echo: ->(t) { echoes << t }, send: ->(t) { sends << t },
      mover: ->(room) { moves << room }, lists: lists
    )
  end

  describe 'engine-side variables' do
    it 'sets and persists a #var' do
      router.route('#var mode hunt')
      expect(vars.global_get('mode')).to eq('hunt')
    end

    it 'evaluates an inline #evalmath in a #var value (the 275x corpus pattern)' do
      router.route('#var timer #evalmath (100 + 20)')
      expect(vars.global_get('timer')).to eq('120')
    end

    # Command.EvalMath / Eval let MathEval's and Eval's exceptions out (Command.cs:2669-2672,
    # 2907-2916 R), ending the whole ParseCommand -- quietly (genieflow: swallowed-fault, flow t182).
    it 'sets nothing when an inline #evalmath / #eval / #if condition faults' do
      router.route('#var k #evalmath (1 +')
      router.route('#var k2 #eval substr("x",5,3)')
      router.route('#if {substr("x",5,3)} {#var k3 1} {#var k3 2}')
      expect(%w[k k2 k3].map { |name| vars.global_key?(name) }).to eq([false, false, false])
      expect { router.command('#evalmath (1 +') }.to raise_error(Lich::Genie::Error, 'Invalid expression: (1 +')
      expect { router.command('#eval substr("x",5,3)') }.to raise_error(Lich::Genie::Eval::Fault)
    end

    it 'evaluates #evalmath / #eval with the literal ports' do
      router.route('#var k4 #evalmath 1+1 = 2')
      router.route('#var j4 #eval 1+1 = 2')
      expect([vars.global_get('k4'), vars.global_get('j4')]).to eq(%w[2 1])
    end

    it 'evaluates an inline #eval in a #var value' do
      router.route('#var flag #eval (3 > 1)')
      expect(vars.global_get('flag')).to eq('1')
    end

    it 'strips braces around a #var value like Genie ParseArgs' do
      router.route('#var greeting {hello there}')
      expect(vars.global_get('greeting')).to eq('hello there')
    end

    it '#tvar does not persist but is readable in-session' do
      router.route('#tvar scratch 7')
      expect(vars.global_get('scratch')).to eq('7')
    end

    it 'deletes a var with #unvar' do
      router.route('#var doomed 1')
      router.route('#unvar doomed')
      expect(vars.global_get('doomed')).to be_nil
    end
  end

  # Remix's persistence model (save only on an explicit save): Command.cs:488-822 (#save/#load), 874-937 (#var),
  # 960-991 (#svar), 1366-1430 (#trigger) R. Echo text = Remix's EchoText lines.
  describe 'persistence commands (Remix #var/#trigger/#save/#load)' do
    around { |example| Dir.mktmpdir('genie-router') { |dir| @dir = dir; example.run } }

    let(:cfg) { File.join(@dir, 'Config', 'variables.cfg') }
    let(:triggers_cfg) { File.join(@dir, 'Config', 'triggers.cfg') }
    let(:store) { Lich::Genie::GlobalStore.new(file: cfg) }
    let(:vars) { Lich::Genie::Variables.new(global_store: store) }
    let(:lists) { Lich::Genie::Lists.new(config_dir: File.join(@dir, 'Config')) }

    it '#var save echoes then writes; a plain #var writes nothing' do
      router.route('#var mode hunt')
      expect(File.exist?(cfg)).to be(false)
      router.route('#var save')
      expect(echoes).to eq(['Variables Saved'])
      expect(File.binread(cfg)).to eq("#var {mode} {hunt}\r\n")
    end

    it '#var SAVE / #var {save} are the subcommand too (keyword lower-cased, braces stripped)' do
      router.route('#var x 1')
      router.route('#var SAVE')
      router.route('#var {save}')
      expect(echoes).to eq(['Variables Saved', 'Variables Saved'])
    end

    it '#var save extra is an ordinary assignment of a variable named "save"' do
      router.route('#var save extra')
      expect(echoes).to eq([])
      expect(vars.global_get('save')).to eq('extra')
      expect(File.exist?(cfg)).to be(false)
    end

    it '#var load / #load vars of an unreadable variables.cfg echo and do not raise (Load catch, Globals.cs:757-762 R)' do
      Lich::Genie::ConfigFile.write_lines(cfg, ['#var {disk} {1}'])
      router.route('#var mine 2')
      allow(File).to receive(:binread).and_call_original
      allow(File).to receive(:binread).with(cfg).and_raise(Errno::EACCES, cfg)
      expect { router.route('#var load') }.not_to raise_error
      expect(vars.global_get('mine')).to eq('2')
      expect { router.route('#load vars') }.not_to raise_error
      expect(vars.global_get('mine')).to be_nil # ClearUser ran, then Load failed
      expect(echoes).to eq(['Variables Loaded', 'Variables Loaded'])
    end

    it '#var load merges the file in; #var clear drops persistent keys but not #tvar' do
      Lich::Genie::ConfigFile.write_lines(cfg, ['#var {disk} {1}'])
      router.route('#var mine 2')
      router.route('#tvar temp 3')
      router.route('#var load')
      expect(%w[disk mine temp].map { |k| vars.global_get(k) }).to eq(%w[1 2 3])
      router.route('#var clear')
      expect(%w[disk mine temp].map { |k| vars.global_get(k) }).to eq([nil, nil, '3'])
      expect(echoes).to eq(['Variables Loaded', 'Variables Cleared'])
    end

    # ListVariables (Command.cs:918-922, 3002-3079 R; genieflow probe p05): the filter is
    # ArrayToString(oArgs, 1), an ordinal Contains on the name.
    it '#var with one unknown word lists the variables whose name contains it; no change' do
      router.route('#var x 1')
      router.route('#var xy 2')
      router.route('#tvar tx 3')
      router.route('#var x')
      router.route('#var X')
      expect(echoes).to eq(['Active variables: ', 'Filter: x', '$x=1', '$xy=2', '(temporary) $tx=3',
                            'Active variables: ', 'Filter: X', 'None.'])
      expect(vars.global_get('x')).to eq('1')
    end

    it '#tvar save / #svar load are NOT subcommands: with fewer than 3 args they list everything' do
      router.route('#tvar save')
      router.route('#svar load')
      expect(echoes).to eq(['Active variables: ', 'None.', 'Active variables: ', 'None.'])
      expect(store.keys).to eq([])
    end

    it '#svar is VariableType.Server: readable, never saved' do
      router.route('#svar srv 10')
      router.route('#var save')
      expect(vars.global_get('srv')).to eq('10')
      expect(File.binread(cfg)).to eq('')
    end

    it '#save vars triggers bogus: one echo + save per known word, unknown words ignored' do
      router.route('#var k v')
      router.route('#trigger {^a} {b}')
      router.route('#save vars triggers bogus')
      expect(echoes).to eq(['Variables Saved', 'Triggers Saved'])
      expect(hooks).to eq([])
      expect(File.binread(cfg)).to eq("#var {k} {v}\r\n")
      expect(File.binread(triggers_cfg)).to eq("#trigger {^a} {b}\r\n")
    end

    it '#save all echoes every Remix line in order, saves the engine lists, and hands the rest to the front end' do
      router.route('#class foo off')
      router.route('#gag {^x} {c}')
      router.route('#sub {^y} {z}')
      router.route('#alias {k} {kneel}')
      hooks.clear
      router.route('#save all')
      expect(echoes).to eq(['Variables Saved', 'Aliases Saved', 'Classes Saved', 'Triggers Saved', 'Settings Saved',
                            'Macros Saved', 'Substitutes Saved', 'Gags Saved', 'Highlights Saved', 'Names Saved',
                            'Presets Saved'])
      expect(File.exist?(cfg)).to be(true)
      dir = File.join(@dir, 'Config')
      expect(%w[classes gags substitutes aliases].map { |f| File.binread(File.join(dir, "#{f}.cfg")) })
        .to eq(["#class {default} {True}\r\n#class {foo} {False}\r\n", "#gag {^x} {c}\r\n", "#subs {^y} {z}\r\n",
                "#alias {k} {kneel}\r\n"])
      expect(hooks).to eq([['save', { 'args' => ['all'], 'raw' => 'all' }]])
    end

    it '#load all clears and reloads vars and the engine lists (no class event: Command.cs:780-816 R)' do
      Lich::Genie::ConfigFile.write_lines(cfg, ['#var {disk} {1}'])
      Lich::Genie::ConfigFile.write_lines(triggers_cfg, ['#trigger {^d} {e} {k}'])
      router.route('#var gone 1')
      router.route('#trigger {^gone} {x}')
      router.route('#load all')
      expect(echoes.first(4)).to eq(['Variables Loaded', 'Aliases Loaded', 'Classes Loaded', 'Triggers Loaded'])
      expect(echoes.length).to eq(11)
      expect(vars.global_get('gone')).to be_nil
      expect(vars.global_get('disk')).to eq('1')
      expect(lists.triggers.entries.map(&:first)).to eq(['^d'])
      expect(hooks.map(&:first)).to eq(['load'])
    end

    it '#load classes clears, loads and raises the class event (Command.cs:674-681 R)' do
      Lich::Genie::ConfigFile.write_lines(File.join(@dir, 'Config', 'classes.cfg'), ['#class {k} {False}'])
      router.route('#trigger {^d} {e} {k}')
      router.route('#class extra on')
      router.route('#load classes')
      expect(lists.classes.entries).to eq([['default', true], ['k', false]])
      expect(lists.triggers.entries.first[4]).to be(false)
    end

    it '#save / #load with no argument do nothing; #save macros only echoes and passes it on' do
      router.route('#save')
      router.route('#load')
      expect([echoes, hooks]).to eq([[], []])
      router.route('#save macros')
      expect(echoes).to eq(['Macros Saved'])
      expect(hooks).to eq([['save', { 'args' => ['macros'], 'raw' => 'macros' }]])
    end

    it '#trigger save / load / clear echo first, then act (#trigger load merges)' do
      Lich::Genie::ConfigFile.write_lines(triggers_cfg, ['#trigger {^disk} {d}'])
      router.route('#trigger {^mine} {m}')
      router.route('#trigger load')
      expect(lists.triggers.entries.map(&:first)).to eq(['^disk', '^mine'])
      router.route('#trigger save')
      router.route('#trigger clear')
      expect(echoes).to eq(['Triggers Loaded', 'Triggers Saved', 'Triggers Cleared'])
      expect(lists.triggers.count).to eq(0)
      expect(File.binread(triggers_cfg)).to eq("#trigger {^disk} {d}\r\n#trigger {^mine} {m}\r\n")
    end

    it '#action / #actions are #trigger (Command.cs:1366-1369 R): add, save, clear and the listing all route' do
      router.route('#action {^w} {#echo w}')
      router.route('#actions')
      router.route('#actions save')
      router.route('#actions CLEAR')
      router.route('#actions')
      expect(echoes).to eq(['Active triggers: ', '^w=#echo w', 'Triggers Saved', 'Triggers Cleared', 'Active triggers: ', 'None.'])
      expect(hooks).to eq([])
    end

    it '#trigger with an invalid regexp echoes Remix\'s line with the raw pattern (Command.cs:1418-1421 R)' do
      router.route('#trigger {[abc} {#echo x}')
      router.route('#action {/^ok(/i} {#echo y} {cls}')
      router.route('#trigger {e/[eval/} {#echo z}')
      router.route('#trigger {^fine} {#echo z}')
      expect(echoes).to eq(['Invalid regexp in trigger: [abc', 'Invalid regexp in trigger: /^ok(/i'])
    end

    # Probe s07_regex_validity, genieflow Remix: `[\w-']` and `(?<=a+)b` are accepted and
    # saved by Remix (no echo); a++ and \Qx are echoed as invalid (NetRegex).
    it '#trigger echoes invalid exactly for the patterns .NET Regex rejects' do
      ["[\\w-']", 'a++', '\\Qx'].each { |p| router.route("#trigger {#{p}} {p}") }
      expect(echoes).to eq(['Invalid regexp in trigger: a++', 'Invalid regexp in trigger: \\Qx'])
    end

    it '#trigger accepts a variable-length lookbehind silently, like Remix (NetRegex::Emulated)' do
      router.route('#trigger {(?<=a+)b} {p}')
      expect(echoes).to eq([])
    end

    it '#trigger adds an Unsupported (.NET-valid) pattern with one warning instead of "Invalid regexp"' do
      router.route('#trigger {(?:x(?<=a+)y)+} {p}')
      expect(lists.triggers.count).to eq(1)
      expect(echoes).to eq(['[Genie: #trigger pattern uses a variable-length lookbehind inside a quantified group, which the ' \
                            'in-Lich engine cannot match; it will never fire: (?:x(?<=a+)y)+]'])
    end

    it '#trigger with a class trims it (Command.cs:1425-1429 R)' do
      router.route('#trigger {^a} {b} {  spaced  }')
      expect(lists.triggers.entries).to eq([['^a', '^a', 'b', 'spaced', true]])
    end

    # Globals.AddTrigger (Globals.cs:920-936 R): a non-eval pattern is ParseGlobalVars'd when it is
    # added; the "Invalid regexp" echo shows the raw argument.
    it '#trigger expands $globals in a regex pattern at add time, never in an eval pattern' do
      vars.global_set('who', 'Bob')
      vars.global_set('bad', '(')
      router.route('#trigger {^$who says} {x}')
      router.route('#trigger {e/$who = 1/} {y}')
      router.route('#trigger {a$bad} {z}')
      expect(lists.triggers.entries.map(&:first)).to eq(['^Bob says', '$who = 1'])
      expect(echoes).to eq(['Invalid regexp in trigger: a$bad'])
    end

    # 'list' is only a listing word in the two-argument branch (Command.cs:1395-1402 R);
    # with 3+ args Remix always calls AddTrigger (Command.cs:1408-1423 R).
    it '#trigger/#action whose pattern is the word list (any case) adds a trigger when commands are given' do
      router.route('#trigger {list} {#echo L1}')
      router.route('#trigger {List} {#echo L2} {cls}')
      router.route('#action {LIST} {#echo L3}')
      expect(lists.triggers.entries.map { |key, _, commands, klass| [key, commands, klass] })
        .to eq([['list', '#echo L1', ''], ['List', '#echo L2', 'cls'], ['LIST', '#echo L3', '']])
      expect(echoes).to be_empty
    end

    # ListTriggers (Command.cs:1407-1411, 3428-3466 R; genieflow probe p06): one word is a filter on the
    # KEY (ordinal Contains), `list` included; keys in SortedList order.
    it '#trigger <word> lists the triggers whose key contains it, `list` being a filter too' do
      router.route('#trigger {^zeta} {#echo z}')
      router.route('#trigger {/^Beta/i} {#echo b}')
      router.route('#trigger {e/$x = 1/} {#echo e}')
      router.route('#trigger eta')
      router.route('#trigger LIST')
      router.route('#trigger')
      expect(echoes).to eq(['Active triggers: ', 'Filter: eta', '^Beta=#echo b', '^zeta=#echo z',
                            'Active triggers: ', 'Filter: LIST', 'None.',
                            'Active triggers: ', '^Beta=#echo b', '^zeta=#echo z', '$x = 1=#echo e'])
    end
  end

  describe 'engine-side computation' do
    # A #command's result is never sent (Command.cs:256-2535 R; only the plain-row arm
    # sends, 2540-2550 R) -- it is the value of `#var x #evalmath ...` (ParseAllArgs).
    it 'never sends the result of a top-level #evalmath / #eval, but returns it (flow t135)' do
      router.route('#evalmath (6 * 7)')
      router.route('#eval 3 > 2')
      expect(sends).to be_empty
      expect(router.command('#evalmath (6 * 7)')).to eq('42')
      expect(router.command('#eval 3 > 2')).to eq('1')
      expect(router.command('#evalmath')).to eq('') # oArgs.Count > 1 guard
    end

    it '#math applies keyword arithmetic into a global' do
      router.route('#var n 5')
      router.route('#math n add 10')
      expect(vars.global_get('n')).to eq('15')
    end

    it '#math divide by 0 or a negative divisor keeps the value (Utility.cs:928 R, flow t56 G2)' do
      router.route('#var gd 9')
      router.route('#math gd divide 0')
      expect(vars.global_get('gd')).to eq('9')
      router.route('#math gd divide -3')
      expect(vars.global_get('gd')).to eq('9')
    end

    it '#math mod 0 stores NaN instead of raising (Utility.cs:932-946 R, flow t56 G1)' do
      router.route('#var gm 9')
      expect { router.route('#math gm mod 0') }.not_to raise_error
      expect(vars.global_get('gm')).to eq('NaN')
    end

    # Command.cs:1033-1034 R: the current value is double.TryParse'd, a failure is 0 -- not
    # StringToDouble's -1 (genieflow probe p_math: "abc" + 1 = 1, "1x" + 2 = 2, "" + 1 = 1).
    it '#math starts from 0 when the current value does not parse (double.TryParse)' do
      { 'mx' => 'abc', 'my' => '1x', 'mz' => "\0 5", 'mn' => '-1' }.each { |key, value| vars.global_set(key, value) }
      router.route('#math mx add 1')
      router.route('#math my add 2')
      router.route('#math mz add 3')
      router.route('#math unset add 4')
      router.route('#math mn add 6')
      expect(%w[mx my mz unset mn].map { |key| vars.global_get(key) }).to eq(%w[1 2 3 4 5])
    end

    it '#math echoes Remix\'s catch text for an unknown keyword and leaves the value (Command.cs:1044-1047 R)' do
      router.route('#var a 3')
      router.route('#math a bogus 1')
      router.route('#math a') # oArgs.Count > 1: an empty expression is a bad keyword too
      router.route('#math')
      expect(echoes).to eq(['Invalid #math expression: a bogus 1', 'Invalid #math expression: a'])
      expect(vars.global_get('a')).to eq('3')
    end

    it '#if routes the then-branch when true and the else-branch when false' do
      router.route('#if {1 > 0} {#var picked then} {#var picked else}')
      expect(vars.global_get('picked')).to eq('then')
      router.route('#if {1 > 2} {#var picked then} {#var picked else}')
      expect(vars.global_get('picked')).to eq('else')
    end

    # A plain branch runs as ParseCommand(ArrayToString(oArgs, 2)) WITHOUT bSendToGame: the
    # then-branch carries the else-branch with it and nothing reaches the game (t135).
    it '#if never sends a plain branch: it is the result, joined with the args after it' do
      router.route('#if {1 = 1} {attack} {flee}')
      expect(sends).to be_empty
      expect(router.command('#if {1 = 1} {attack} {flee}')).to eq('attack flee')
      expect(router.command('#if {1 = 2} {attack} {flee}')).to eq('flee')
      expect(router.command('#if {1 = 2} {attack}')).to eq('')
      expect(router.command('#if {1}')).to eq('') # oArgs.Count > 2 guard
    end

    it '#if replaces a #-condition by its ParseCommand result and expands $globals in it' do
      vars.global_set('lim', '5')
      expect(router.command('#if {#evalmath 2+2} {#var hit yes}')).to eq('')
      expect(vars.global_get('hit')).to eq('yes')
      expect(router.command('#if {$lim > 4} {#evalmath 1+1}')).to eq('2')
    end

    it '#if runs EVERY ;-separated sub-command in the taken branch, not just the first' do
      # Genie's ParseCommand splits the branch on ';' -- a corpus casting trigger relies on
      # this (its whole reset block, ending in #class casting off, lives inside one #if
      # branch). Regression for "triggers/#class do not work".
      router.route('#var charges 3')
      router.route('#if {1 = 1} {#var a 1;#var charges 0;#class casting off} {#var b 2}')
      expect(vars.global_get('a')).to eq('1')
      expect(vars.global_get('charges')).to eq('0')
      expect(vars.global_get('b')).to be_nil # else-branch not taken
      expect(lists.classes['casting']).to be(false)
    end

    it '#if evaluates nested #if sub-commands inside a taken branch' do
      router.route('#var charges 5')
      router.route('#if {1 = 1} {#if {($charges != 0)} {#var charges 0};#var done 1} {}')
      expect(vars.global_get('charges')).to eq('0')
      expect(vars.global_get('done')).to eq('1')
    end

    it '#if returns the LAST row of a multi-command branch as its result (Genie sResult), never sent' do
      expect(router.command('#if {1 = 1} {#var q 1;north} {south}')).to eq('north')
      expect(vars.global_get('q')).to eq('1')
      expect(sends).to be_empty
    end

    it '#goto routes to the mover (not the game); #mapper is a no-op' do
      router.route('#goto 93')
      router.route('#mapper reset')
      expect(moves).to eq(['93'])
      expect(sends).to be_empty
      expect(hooks).to be_empty
    end

    # Command.cs:2441-2449 R turns each of these rows into `#mapper <keyword>
    # ...`; the AutoMapper's goto arm takes goto/go/g/walk/walkto (AutoMapper.cs:1140-1144 R), a
    # bare one included ("please specify", AutoMapper.cs:1196-1200 R: the mover's job).
    it 'routes #go, #g, #walk, #walkto and a bare #goto to the mover, and #path to nothing' do
      ['#go 12', '#G 13', '#walk 14', '#walkto  15 ', '#goto', '#GOTO   ', '#path 16'].each { |row| router.route(row) }
      # The mover gets sArg -- the row after the keyword's first space, inner
      # spaces kept (AutoMapper.cs:955-965 R: "#walkto  15" -> " 15", echoed "#goto  15")
      expect([moves, sends, hooks, echoes]).to eq([['12', '13', '14', ' 15', '', ''], [], [], []])
    end
  end

  # The timed CommandQueue: Command.Send / Command.Do (Command.cs:2561-2640 R) and #queue
  # (Command.cs:1134-1162 R). The router only fills the queue; releasing it is CommandQueue's.
  describe '#send / #do / #queue (the timed CommandQueue)' do
    let(:queue) { Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) }) }
    let(:router) do
      described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t }, send: ->(t) { sends << t },
                          queue: queue)
    end

    def queued = queue.items.map { |item| [item.delay, item.action, item.wait_rt, item.wait_webbed, item.wait_stunned] }

    it 'queues #send with a double delay, roundtime-gated; #do also webbed/stunned-gated; nothing is sent' do
      router.route('#send 2 look')
      router.route('#send .5 half')
      router.route('#send 2. two')
      router.route('#do 1 grab')
      router.route('#send now')
      expect(queued).to eq([[2.0, 'look', true, false, false], [0.5, 'half', true, false, false], [2.0, 'two', true, false, false],
                            [1.0, 'grab', true, true, true], [0.0, 'now', true, false, false]])
      expect(sends).to be_empty
    end

    it '#send expands $globals after re-parsing its argument, and a lone number queues nothing' do
      vars.global_set('tgt', 'goblin')
      router.route('#send 1 attack $tgt')
      router.route('#send 3')
      router.route('#send')
      expect(queued).to eq([[1.0, 'attack goblin', true, false, false]])
    end

    # ParseAllArgs re-parses with quick send on: `#send -1 x` queues x itself and then has an
    # empty argument (flow t129); `{a;b}` is the last row "b".
    it '#send re-parses its argument: an inner quick send queues, a braced ; keeps the last row' do
      router.route('#send -1 inner')
      router.route('#send {a;b}')
      expect(queued).to eq([[1.0, 'inner', true, false, false], [0.0, 'b', true, false, false]])
    end

    it 'raises double.Parse\'s FormatException for a bad delay (1.2.3), queueing nothing' do
      expect { router.command('#send 1.2.3 bad') }.to raise_error(Lich::Genie::Error, "The input string '1.2.3' was not in a correct format.")
      expect { router.route('#send 1.2.3 bad;#var after 1') }.not_to raise_error # top level: swallowed, rest skipped
      expect(vars.global_get('after')).to be_nil
      expect(queue).to be_empty
    end

    it '#send clear / #do clear / #queue clear empty the queue (any case of "clear" for #send)' do
      %w[a b].each { |c| router.route("#send #{c}") }
      router.route('#send CLEAR')
      expect(queue).to be_empty
      router.route('#do 1 x')
      router.route('#do clear')
      expect(queue).to be_empty
      router.route('#queue 1 y')
      router.route('#queue Clear')
      expect(queue).to be_empty
    end

    it '#queue / #que add unexpanded with no restriction; a bad delay is StringToDouble\'s -1' do
      vars.global_set('x', 'X')
      router.route('#queue 1.5 say $x  now')
      router.route('#que abc go')
      expect(queued).to eq([[1.5, 'say $x now', false, false, false], [-1.0, 'go', false, false, false]])
    end

    it 'lists the queue for #queue and #queue <filter> (ListCommandQueue)' do
      router.route('#queue')
      router.route('#send 2 look')
      router.route('#queue 0.5 smile')
      router.route('#queue')
      router.route('#queue mil')
      router.route('#queue zzz')
      expect(echoes).to eq(['Active command queue: ', 'None.',
                            'Active command queue: ', '(2) look', '(0.5) smile',
                            'Active command queue: ', 'Filter: mil', '(0.5) smile',
                            'Active command queue: ', 'Filter: zzz', 'None.'])
    end

    # Every item the router queues carries the issuing script's handle.
    it 'stores queue_owner with #send, #do, #queue and the - quick send items (nil without one)' do
      owned = described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t },
                                  send: ->(t) { sends << t }, queue: queue, queue_owner: :caller)
      owned.run('#send 1 a;#do 1 b;#queue 1 c;-d', send_to_game: true)
      router.route('#send 1 e')
      expect(queue.items.map { |item| [item.action, item.owner] })
        .to eq([['a', :caller], ['b', :caller], ['c', :caller], ['d', :caller], ['e', nil]])
    end

    # A hot reload rebuilds Lich::Genie.command_queue; a router built with
    # a callable fills, clears and lists the CURRENT queue, never the one it was built with.
    it 'follows a replaced queue when built with a callable (fill, list, clear)' do
      current = [queue]
      replacement = Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) })
      lazy = described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t },
                                 send: ->(t) { sends << t }, queue: -> { current[0] })
      lazy.route('#send 1 old')
      current[0] = replacement
      lazy.route('#send 1 new')
      lazy.route('#queue')
      expect([queue.items.map(&:action), replacement.items.map(&:action)]).to eq([['old'], ['new']])
      expect(echoes).to eq(['Active command queue: ', '(1) new'])
      expect(lazy.queue).to be(replacement)
      lazy.route('#queue clear')
      expect([queue.empty?, replacement.empty?]).to eq([false, true])
    end
  end

  describe 'engine-side echo' do
    it 'echoes plain text locally' do
      router.route('#echo hello world')
      expect(echoes).to eq(['hello world'])
      expect(hooks).to be_empty
    end

    it 'routes #echo >window to a front-end echo hook' do
      router.route('#echo >thoughts pathing to bank')
      expect(hooks).to eq([['echo', { 'window' => 'thoughts', 'text' => 'pathing to bank' }]])
    end

    # The colour index step (Command.cs:269-313 R): arg 2 after a `>window` arg 1, arg 1 when
    # the window is arg 2 or absent; ColorCode.StringToColor (ColorCode.cs:27-50, 114-130 R)
    # of a `#RRGGBB` (or the fg of `fg,bg`) is a colour, so that arg is dropped before
    # ParseAllArgs -- else ParseAllArgs re-parses "#cf2319 ..." as a command row (flow t140).
    it 'drops a hex colour before the text: main window, >window first, colour first, fg,bg' do
      router.route('#echo #00FF00 Hello there')
      router.route('#echo >Log #cf2319 ** Error! setup')
      router.route('#echo #ABCDEF >Log colour first')
      router.route('#echo #ff0000,#000000 fg and bg')
      expect(echoes).to eq(['Hello there', 'fg and bg'])
      expect(hooks).to eq([['echo', { 'window' => 'Log', 'text' => '** Error! setup' }],
                           ['echo', { 'window' => 'Log', 'text' => 'colour first' }]])
    end

    it 'echoes an empty line for a lone colour (ParseAllArgs of only nulls)' do
      router.route('#echo #00ff00')
      router.route('#echo >Log #00ff00')
      expect(echoes).to eq([''])
      expect(hooks).to eq([['echo', { 'window' => 'Log', 'text' => '' }]])
    end

    it 'keeps a colour word in the text when the window is arg 1 and there is no arg 2 (iColorIndex 0)' do
      router.route('#echo >Log')
      expect(hooks).to eq([['echo', { 'window' => 'Log', 'text' => '' }]])
    end
  end

  # ParseCommand's default arm (Command.cs:2517-2526 R): a row whose first arg is `#RRGGBB`
  # (ColorCode.IsHexString, ColorCode.cs:114-130 R) is not a command: its result is the row
  # itself, with no effect -- so `#var hx #ff0000` stores the colour, `put #000000 x` does
  # nothing, and no hook is emitted.
  describe 'a hex colour row (the default arm)' do
    it 'returns the raw row as its result and has no effect' do
      expect(router.parse_command('#ff0000 x  y')).to eq('#ff0000 x  y')
      router.route('#000000 x')
      router.route('#AbCdEf')
      expect([echoes, hooks, sends]).to eq([[], [], []])
    end

    it 'is a value for ParseAllArgs: #var hx #ff0000' do
      router.route('#var hx #ff0000')
      expect(vars.global_get('hx')).to eq('#ff0000')
    end

    it 'leaves a non-hex first arg to the unknown-command echo (6 chars but a non-hex letter, 5 or 7 chars)' do
      %w[#00ff0g #00ff0 #00ff000].each { |row| router.route(row) }
      expect(echoes).to eq(['Unknown command: #00ff0g', 'Unknown command: #00ff0', 'Unknown command: #00ff000'])
      expect(hooks).to eq([])
    end
  end

  describe 'front-end effects (structured payloads)' do
    it '#class name on|off sets the class list and hands the front end the whole list (class event)' do
      router.route('#class recovery on')
      router.route('#class alertstart off')
      expect(lists.classes.entries).to eq([['alertstart', false], ['default', true], ['recovery', true]])
      expect(hooks.last).to eq(['class', { 'classes' => { 'alertstart' => false, 'default' => true, 'recovery' => true } }])
    end

    it '#class +a -b toggles multiple classes, lower-cased' do
      router.route('#class +Combat -IDLE')
      expect(lists.classes.entries).to eq([['combat', true], ['default', true], ['idle', false]])
    end

    it '#trigger adds pattern/commands/class to the registry' do
      router.route('#trigger {^You feel ready} {#var cdtimer 0;#class cooldown off} {cooldown}')
      expect(lists.triggers.entries).to eq([['^You feel ready', '^You feel ready', '#var cdtimer 0;#class cooldown off', 'cooldown', true]])
      expect(hooks).to eq([])
    end

    it '#untrigger removes by the raw pattern (normalized like Add)' do
      router.route('#trigger {/^You feel ready/i} {x}')
      router.route('#untrigger {^You feel ready}')
      expect(lists.triggers.count).to eq(0)
    end

    it '#gag and #sub fill the engine-owned lists (Model A downstream)' do
      router.route('#gag {a boring line} {spam}')
      router.route('#sub {kobold} {KOBOLD}')
      expect(lists.filters.gags.map { |g| [g.text, g.klass, g.ignore_case] }).to eq([['a boring line', 'spam', false]])
      expect(lists.filters.subs.map { |sub| [sub.text, sub.replacement, sub.klass] }).to eq([%w[kobold KOBOLD] + ['']])
      expect(hooks).to eq([])
    end

    it '#highlight (line) emits full self-describing payload' do
      router.route('#highlight line yellow {a hungry kobold}')
      expect(hooks).to eq([['highlight', {
        'kind' => 'line', 'whole_row' => true, 'color' => 'yellow',
                            'pattern' => 'a hungry kobold', 'case_sensitive' => false,
                            'sound' => '', 'class' => '', 'active' => true
      }]])
    end

    # Remix's argument order (Command.cs:1982-2004 R) -- class oArgs[4], sound oArgs[5], case oArgs[6] ==
    # TRUE, active oArgs[7] == TRUE (default true); the delta oracle d4 shows '[TRUE:ON] ...' for
    # `#highlight string ... TRUE snd.wav cls` (TRUE is the class).
    it '#highlight regex normalizes kind and reads class/sound/case/active in Remix order' do
      router.route('#highlight regexp red {^You die} combat alarm.wav TRUE')
      _, p = hooks.first
      expect(p.values_at('kind', 'whole_row', 'class', 'sound', 'case_sensitive', 'active'))
        .to eq(['regex', false, 'combat', 'alarm.wav', true, true])
      router.route('#highlight string red {two words} TRUE snd.wav cls false')
      expect(hooks.last[1].values_at('class', 'sound', 'case_sensitive', 'active')).to eq(['TRUE', 'snd.wav', false, false])
    end

    it '#highlight regexp with an invalid pattern echoes Remix\'s line and adds nothing' do
      router.route('#highlight regexp red (bad tail')
      expect(echoes).to eq(['Invalid RegExp in highlight: (bad tail'])
      expect(hooks).to eq([])
    end

    # Each highlight list's Add strips Genie's /../ and /../i delimiters, /i turning
    # case sensitivity off, and refuses an empty text (Highlights.cs:116-149 R StripCaseMarker for
    # line/string: only a `/`-led text longer than the markers; Globals.cs:1240-1262, 1361-1383 R for
    # beginswith/regex: a leading `/` and a trailing `/i` or `/` independently). The regex is validated
    # BEFORE the strip (Command.cs:1979-1981 R).
    it '#highlight strips /x/ and /x/i per list like Remix\'s Add, /i clearing case sensitivity' do
      [
        '#highlight regexp red {/^Foo bar/i} c x TRUE', '#highlight regexp red {/^Foo/}', '#highlight regexp red {^Foo/i}',
        '#highlight beginswith red {/Begin} c x TRUE', '#highlight line red {/^Foo bar/i} c x TRUE',
        '#highlight string red {two/i}', '#highlight string red {/i}', '#highlight line red {//}', '#highlight string red {//i}',
        '#highlight regexp red {}', '#highlight string red {}'
      ].each { |row| router.route(row) }
      expect(hooks.map { |_, p| [p['kind'], p['pattern'], p['case_sensitive']] }).to eq(
        [['regex', '^Foo bar', false], ['regex', '^Foo', false], ['regex', '^Foo', false],
         ['beginswith', 'Begin', true], ['line', '^Foo bar', false],
         ['string', 'two/i', false], ['string', '/i', false], ['line', '//', false], ['string', '//i', false]]
      )
    end

    # NameList.Add then RebuildIndex compiles
    # `\b(<sorted keys>)\b` (Names.cs:41-112 R); a key that makes it invalid throws on that #name and
    # every later one until #unname removes it -- the rest of the ParseCommand is skipped. An empty key
    # adds nothing and does not fault.
    it '#name faults while a listed key breaks the name index; #unname clears it; an empty key is fine' do
      router.route('#name red {};#var a 1')
      router.route('#name red {bad[};#var b 1')
      router.route('#name red x;#var c 1')
      router.route('#unname bad[;#var d 1')
      router.route('#name red y;#var e 1')
      expect(%w[a b c d e].map { |name| vars.global_get(name) }).to eq(['1', nil, nil, '1', '1'])
      expect(lists.names.keys).to eq(%w[x y])
      expect(hooks.select { |op, _| op == 'name' }.map { |_, p| p['name'] }).to eq(%w[y])
      expect { router.command('#name red {(}') }.to raise_error(Lich::Genie::Error, /Invalid pattern '\\b\(\(\|x\|y\)\\b'/)
      router.route('#name clear')
      router.route('#name red z;#var f 1')
      expect(vars.global_get('f')).to eq('1')
    end

    it '#name load / #load names read names.cfg keys (three-token rows) and fault on a bad one' do
      Dir.mktmpdir('genie-names') do |dir|
        File.write(File.join(dir, 'names.cfg'), "#name {red} {Bob}\n#name {blue} {bad[}\n#name x\n")
        named = described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t },
                                    send: ->(t) { sends << t }, lists: Lich::Genie::Lists.new(config_dir: dir))
        named.route('#name load;#var g 1')
        expect([echoes, vars.global_get('g'), named.lists.names.keys]).to eq([['Names Loaded'], nil, ['bad[', 'Bob']]) # culture order
        File.write(File.join(dir, 'names.cfg'), "#name {red} {Al}\n")
        named.route('#load names;#var h 1') # Clear + Load (Command.cs:751-752 R)
        expect([vars.global_get('h'), named.lists.names.keys]).to eq(['1', %w[Al]])
      end
    end

    it '#highlight clear emits a clear event' do
      router.route('#highlight clear')
      expect(hooks).to eq([['highlight', { 'clear' => true }]])
    end

    it 'emits macro/alias/preset/name pairs' do
      router.route('#macro {ctrl+a} {attack}')
      router.route('#alias {kk} {attack kobold}')
      router.route('#preset {roomname} {#00ff00}')
      router.route('#name combat {a goblin} {an orc}')
      expect(hooks).to eq([
                            ['macro', { 'key' => 'ctrl+a', 'command' => 'attack' }],
                            ['alias', { 'pattern' => 'kk', 'command' => 'attack kobold' }],
                            ['preset', { 'name' => 'roomname', 'value' => '#00ff00' }],
                            ['name', { 'name' => 'a goblin', 'value' => 'combat' }],
                            ['name', { 'name' => 'an orc', 'value' => 'combat' }]
                          ])
    end

    it 'emits window/playsound/link/image/flash payloads' do
      router.route('#window add {thoughts}')
      router.route('#playsound alert.wav')
      router.route('#playsound stop')
      router.route('#link >map {bank} {go bank}')
      router.route('#image >combat w:64 h:32 sword.png')
      router.route('#flash')
      expect(hooks).to eq([
                            ['window', { 'action' => 'add', 'name' => 'thoughts',
                                         'width' => 300, 'height' => 200, 'top' => 10, 'left' => 10 }],
                            ['playsound', { 'file' => 'alert.wav' }],
                            ['playsound', { 'stop' => true }],
                            ['link', { 'window' => 'map', 'text' => 'bank', 'command' => 'go bank' }],
                            ['image', { 'filename' => 'sword.png', 'window' => 'combat',
                                        'width' => 64, 'height' => 32 }],
                            ['flash', {}]
                          ])
    end

    # #beep/#bell (Command.cs:1538-1548 R),
    # #play/#playwave/#playsound on GetArgumentString, "stop" after ToLower, nothing for an empty
    # argument (Command.cs:1550-1568 R), #layout (Command.cs:2303-2329 R): no subcommand loads
    # "@windowsize@", load/save any case with ParseGlobalVars over ParseAllArgs(2), anything else
    # nothing. The front end decides whether sounds play (Config.bPlaySounds is its setting).
    it 'emits beep, play and layout payloads with Remix\'s argument rules' do
      vars.global_set('lay', 'hunting')
      ['#beep', '#bell extra', '#play {a b.wav}', '#playwave STOP', '#play', '#playsound  ding.wav ',
       '#layout', '#layout LOAD {my $lay}', '#layout save x y', '#layout frob x', '#layout load'].each { |row| router.route(row) }
      expect(hooks).to eq([
                            ['beep', {}], ['beep', {}],
                            ['playsound', { 'file' => '{a b.wav}' }], ['playsound', { 'stop' => true }],
                            ['playsound', { 'file' => ' ding.wav' }], # Substring after the FIRST space of the trimmed row
                            ['layout', { 'action' => 'load', 'name' => '@windowsize@' }],
                            ['layout', { 'action' => 'load', 'name' => 'my hunting' }],
                            ['layout', { 'action' => 'save', 'name' => 'x y' }],
                            ['layout', { 'action' => 'load', 'name' => '' }]
                          ])
      expect(echoes).to eq([])
    end

    # The default arm (Command.cs:2518-2530 R; genieflow probe p01): the row as split, untrimmed.
    it 'echoes "Unknown command: <row>" for a genuinely unknown op, `# echo`, a bare `#` and #automapper' do
      ['#frobnicate {a} {b}', '# echo x', '#  var a 1', '#', '#automapper reset', '#ping'].each { |row| router.route(row) }
      expect(echoes).to eq(['Unknown command: #frobnicate {a} {b}', 'Unknown command: # echo x', 'Unknown command: #  var a 1',
                            'Unknown command: #', 'Unknown command: #automapper reset', 'Unknown command: #ping'])
      expect(hooks).to eq([])
      expect(vars.global_key?('a')).to be(false)
    end
  end

  describe '#script host control' do
    let(:calls) { [] }
    let(:running) { %w[sc chl cl] }
    let(:fake_control) do
      log = calls
      names = running
      Object.new.tap do |o|
        o.define_singleton_method(:names) { names }
        %i[abort pause resume pauseorresume reload].each do |action|
          o.define_singleton_method(action) { |name| log << [action, name] }
        end
      end
    end
    # A router that knows its own script name ('sc') so we can assert self-abort order.
    let(:controlled_router) do
      described_class.new(
        vars: vars, eval: evaluator, hooks: hook_sink,
        echo: ->(t) { echoes << t }, send: ->(t) { sends << t },
        script_control: fake_control, script_name: 'sc'
      )
    end

    it 'aborts every running script on #script abort all' do
      controlled_router.route('#script abort all')
      expect(calls).to contain_exactly([:abort, 'chl'], [:abort, 'cl'], [:abort, 'sc'])
    end

    # Command_ScriptAbort walks m_oScriptList in order and aborts each match, the caller included
    # where it stands (FormMain.cs:5806-5823 R); a self-abort is cooperative, so the rest
    # of an `abort all` still runs.
    it 'aborts in list order, the issuing script where it stands' do
      controlled_router.route('#script abort all')
      expect(calls).to eq([[:abort, 'sc'], [:abort, 'chl'], [:abort, 'cl']])
    end

    # The port acts on EVERY listed script of a name, so each name goes to it once: two listed
    # copies are each toggled once, as Remix's per-script walk does (FormMain.cs:5783-6080 R).
    it 'hands each matching name to the port once, however many listed scripts share it' do
      running.replace(%w[dup sc dup])
      controlled_router.route('#script pauseorresume dup')
      controlled_router.route('#script abort all except sc')
      expect(calls).to eq([[:pauseorresume, 'dup'], [:abort, 'dup']])
    end

    it 'spares the named script on #script abort all except <name>' do
      controlled_router.route('#script abort all except sc')
      expect(calls).to contain_exactly([:abort, 'chl'], [:abort, 'cl'])
    end

    it 'aborts only the named script on #script abort <name>' do
      controlled_router.route('#script abort chl')
      expect(calls).to eq([[:abort, 'chl']])
    end

    it 'pauses every running script on #script pause all' do
      controlled_router.route('#script pause all')
      expect(calls).to contain_exactly([:pause, 'sc'], [:pause, 'chl'], [:pause, 'cl'])
    end

    it 'resumes only the named script on #script resume <name>' do
      controlled_router.route('#script resume cl')
      expect(calls).to eq([[:resume, 'cl']])
    end

    it 'reloads only the named script on #script reload <name>' do
      controlled_router.route('#script reload chl')
      expect(calls).to eq([[:reload, 'chl']])
    end

    it 'never sends a #script command to the game' do
      controlled_router.route('#script abort all')
      expect(sends).to be_empty
    end

    it 'ignores a name that is not currently running' do
      controlled_router.route('#script abort nonexistent')
      expect(calls).to be_empty
    end

    it 'routes an informational subcommand (list) to a front-end tag, not the port' do
      controlled_router.route('#script list')
      expect(hooks).to eq([['script', { 'args' => ['list'], 'raw' => 'list' }]])
      expect(calls).to be_empty
    end

    it 'treats a bare #script as a front-end effect, not a mass abort' do
      controlled_router.route('#script')
      expect(calls).to be_empty
    end

    # Faithful-but-dangerous: Genie's Command_ScriptAbort gets "" for the arg, whose
    # (+" ") form does NOT start with "all " but IS length 0, so it matches ALL. Lock
    # this in so a future refactor can't quietly turn `#script abort` into a no-op.
    it 'aborts ALL scripts on a bare "#script abort" (empty arg), matching Genie' do
      controlled_router.route('#script abort')
      expect(calls).to eq([[:abort, 'sc'], [:abort, 'chl'], [:abort, 'cl']]) # list order, caller included
    end

    it 'never aborts the caller when it is the excepted script' do
      controlled_router.route('#script abort all except sc')
      expect(calls.map(&:last)).not_to include('sc')
      expect(calls).to contain_exactly([:abort, 'chl'], [:abort, 'cl'])
    end

    it 'matches the subcommand keyword case-insensitively' do
      controlled_router.route('#script ABORT ALL EXCEPT sc')
      expect(calls).to contain_exactly([:abort, 'chl'], [:abort, 'cl'])
    end

    it 'spares an except name even if it is not currently running (no-op except)' do
      controlled_router.route('#script abort all except ghost')
      expect(calls).to contain_exactly([:abort, 'sc'], [:abort, 'chl'], [:abort, 'cl'])
    end

    it 'does not reorder the caller for a non-abort action (pause leaves it in place)' do
      controlled_router.route('#script pause all')
      expect(calls.first).to eq([:pause, 'sc']) # port enumeration order preserved
    end

    it 'makes #script a safe no-op when no host port is wired (default)' do
      expect { router.route('#script abort all') }.not_to raise_error
    end
  end

  # #parse (Command.cs:1530-1535 R -> FormMain.ClassCommand_ParseText 4659-4667 R).
  describe '#parse' do
    let(:parsed) { [] }
    let(:router) do
      described_class.new(
        vars: vars, eval: evaluator, hooks: hook_sink,
        echo: ->(t) { echoes << t }, send: ->(t) { sends << t },
        parse: ->(t) { parsed << t }
      )
    end

    it 'hands the ParseGlobalVars-expanded argument to the parse port, and nothing to the game or front end' do
      vars.global_set('indirect', '$dest')
      router.route('#parse $indirect SUCCESSFUL %local')
      expect(parsed).to eq(['$dest SUCCESSFUL %local']) # single level: the inserted $dest is not rescanned
      expect(sends).to be_empty
      expect(hooks).to be_empty
      expect(echoes).to be_empty
    end

    it 'expands $globals and keeps %locals literal (ParseGlobalVars is $-only)' do
      vars.global_set('dest', 'MOVE')
      router.route('#parse $dest %x')
      expect(parsed).to eq(['MOVE %x'])
    end

    it 'keeps the text untrimmed past the first separator space (GetArgumentString)' do
      router.route('#parse   two leading')
      expect(parsed).to eq(['  two leading'])
    end

    it 'ignores a blank line, including .NET-only whitespace (ClassCommand_ParseText Trim check)' do
      router.route('#parse')
      router.route("#parse   #{[0xA0].pack('U')}")
      expect(parsed).to be_empty
    end

    it 'is a silent no-op without a parse port (headless), never a front-end hook' do
      headless = described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t }, send: ->(t) { sends << t })
      headless.route('#parse anything')
      expect(hooks).to be_empty
      expect(sends).to be_empty
    end

    it 'matches the keyword case-insensitively like every ParseCommand arm' do
      router.route('#PARSE Hello')
      expect(parsed).to eq(['Hello'])
    end
  end
  # Remix's Config changes at once (Config.cs:569-1100 R; #config arm
  # Command.cs:1457-1527 R), so uber.cmd's own settings (uber.cmd:1043, 1048 in the
  # ubercombat corpus, verbatim below) reach the next $monstercount/$roundtime.
  describe '#config (Config.SetSetting at runtime)' do
    let(:capture) { Lich::Genie::GameState.new(write_clock: Lich::Genie::WriteClock.new) }
    let(:vars) { Lich::Genie::Variables.new(game_state: Lich::Genie::ReservedState.new(game_state: capture)) }
    let(:uber_ignore_list) do
      '#config monstercountignorelist appears dead|(dead)|shadowling|black squirrel|' \
      'despondent Elothean|Riverhaven Warden|Shadow Servant|shadowling|the bartender Masul|alfar|' \
      'shadow servent|human-sized construct|dirt construct|arisen|the Bacon Man|' \
      'a cheerful Elven peddler|Estate Holder representative|town guard|domesticated gelapod|' \
      'massive great horned owl with a disfigured beak|chubby bear|hazy phantom thrall|Shalvard|' \
      'Elys|Quentin|Atladene|Yrisa|Tanalae|Onsuwayo|Yolesi|Amrillora|Srela|Fraethis|Gaktrhn|Dokt|' \
      'Arthianna|Kaiva|Martyr Saedelthorp|Brokk|stony spawn|forest spawn|water spawn|plague spawn|' \
      'grass spawn|harvest spawn|slimy spawn|thorny spawn|sandy spawn|glum watchsoul|' \
      'scraggly watchsoul|house spirit|phantom thrall'
    end

    it "applies uber.cmd's monstercountignorelist and roundtimeoffset lines to the live capture" do
      router.route(uber_ignore_list)
      router.route('#config roundtimeoffset 0.1')
      expect(capture.config.ignore_monster_list).to eq(uber_ignore_list.delete_prefix('#config monstercountignorelist '))
      expect(capture.config.rt_offset).to eq(0.1)
      capture.feed("<component id='room objs'>You also see <pushBold/>a shadowling<popBold/>, <pushBold/>a black squirrel<popBold/> " \
                   "and <pushBold/>a goblin<popBold/>.</component>\r\n")
      expect([vars.global_get('monstercount'), vars.global_get('monsterlist')]).to eq(['1', 'a goblin'])
    end

    # Config.SetSetting's messages (Config.cs:1481-1482 R) echoed by Command.cs:1514-1518 R; the front
    # end still hears about the setting.
    it 'echoes SetSetting\'s two lines and passes the setting on to the front end' do
      router.route('#config roundtimeoffset 0.1')
      expect(echoes).to eq(['Set roundtimeoffset: 0.1', "Don't forget to #save config"])
      expect(hooks).to eq([['config', { 'key' => 'roundtimeoffset', 'value' => '0.1' }]])
    end

    it 'joins the value like ArrayToString (Utility.cs:766-780 R) and takes #set/#setting/#settings too' do
      router.route('#set monstercountignorelist {a  b}   c')
      expect(capture.config.ignore_monster_list).to eq('a  b c')
      router.route('#set monstercountignorelist x "" y') # a blank item adds no space
      expect(capture.config.ignore_monster_list).to eq('x y')
      router.route('#SETTINGS prompt off')
      router.route('#setting promptforce 0')
      expect([capture.config.prompt, capture.config.prompt_force]).to eq(['', false])
    end

    it 'runs SetSetting(key, "") for a lone key, but not for load/save/edit' do
      router.route('#config prompt') # the default branch: sPrompt = ""
      expect(capture.config.prompt).to eq('')
      %w[load save edit LOAD].each { |word| router.route("#config #{word}") }
      router.route('#config')
      expect(capture.config.to_h).to eq(prompt: '', prompt_force: true, ignore_monster_list: 'appears dead|(dead)', rt_offset: 0.0,
                                        separator_char: ';', command_char: '#', script_char: '.', condensed: false,
                                        parse_game_only: false, show_links: false, trigger_on_input: true,
                                        script_timeout: 5000, max_gosub_depth: 50, ignore_script_warnings: false, abort_dupe_script: true, my_command_char: '/')
    end

    it 'is a no-op for the capture with no game state behind the variables' do
      plain = described_class.new(vars: Lich::Genie::Variables.new, eval: evaluator, hooks: hook_sink,
                                  echo: ->(t) { echoes << t }, send: ->(t) { sends << t })
      expect { plain.route('#config roundtimeoffset 2') }.not_to raise_error
      expect(hooks.map(&:first)).to eq(['config'])
    end
  end

  # Command.VariableChanged("$" + oArgs[1]) after #var/#tvar/#svar and a good #math
  # (Command.cs:931-933, 952-954, 983-985, 1040-1042 R); #unvar and #var clear raise nothing.
  describe 'the var_changed port' do
    let(:changed) { [] }
    let(:router) do
      described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t },
                          send: ->(t) { sends << t }, var_changed: ->(name) { changed << [name, vars.global_get(name[1..])] })
    end

    it 'raises "$name" after the value is stored, for each setting arm' do
      %w[#var\ a\ 1 #tvar\ b\ 2 #svar\ c\ 3 #setvariable\ d\ 4 #math\ a\ add\ 5].each { |row| router.route(row) }
      expect(changed).to eq([%w[$a 1], %w[$b 2], %w[$c 3], %w[$d 4], %w[$a 6]])
    end

    it 'raises nothing for #unvar, #var clear|save|load, a short #var, or a bad #math' do
      vars.global_set('a', '1')
      ['#unvar a', '#var clear', '#var x', '#math a bogus 1', '#math a'].each { |row| router.route(row) }
      expect(changed).to eq([])
    end
  end

  # The #command layer. Every expectation is Remix's (genieflow probes p01-p14 =
  # flow t212-t224); Command.cs lines on each example.
  describe 'the #command layer' do
    let(:queue) { Lich::Genie::CommandQueue.new(clock: -> { Time.new(2026, 1, 1, 0, 0, 0) }) }
    let(:script_calls) { [] }
    let(:control) do
      calls = script_calls
      Object.new.tap do |o|
        o.define_singleton_method(:names) { %w[a b a] }
        o.define_singleton_method(:debug) { |level, name| calls << [level, name] }
      end
    end
    let(:router) do
      described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t },
                          send: ->(t) { sends << t }, queue: queue, lists: lists, script_control: control)
    end

    # Command.cs:259-265 R: the keyword is ParseArgs(row)[0] minus its first char, lower-cased.
    it 'dispatches on ParseArgs(row)[0], so a leading space is fine and `# var` is unknown' do
      router.route('  #VAR big 1')
      router.route('#  var small 2')
      expect([vars.global_get('big'), vars.global_key?('small')]).to eq(['1', false])
      expect(echoes).to eq(['Unknown command: #  var small 2'])
    end

    # Command.cs:825-835, 865-872 R.
    it 'has the cheap verbs: #nop and #push are "", #cr is the Windows newline' do
      expect(%w[#nop #push #cr].map { |row| router.command(row) }).to eq(['', '', "\r\n"])
      router.route('#var cr #cr')
      expect(vars.global_get('cr')).to eq("\r\n")
    end

    # Command.cs:361-385, 355-359, 993-1015 R: an arm that indexes a missing argument faults.
    it 'faults on a lone #log / #icon / #unvar (ArgumentOutOfRange), ending the ParseCommand' do
      %w[#log #icon #unvar].each do |row|
        expect { router.command(row) }.to raise_error(Lich::Genie::Error, described_class::INDEX_FAULT)
      end
      router.route('#log;#var after 1')
      expect(vars.global_key?('after')).to be(false)
    end

    # Command.cs:851-863 R: ParseGlobalVars(ParseAllArgs(oArgs, 1)) through SendTextToGame.
    it '#put sends its argument through ParseAllArgs and SendTextToGame' do
      vars.global_set('t', 'goblin')
      router.route('#put look at $t')
      router.route('#put a\;b')
      router.route('#put #echo inner')
      expect(sends).to eq(['look at goblin', 'a;b'])
      expect(echoes).to eq(['inner'])
    end

    # Command.cs:1441-1455 R; Utility.cs:251-255 R.
    it '#random draws Random.Next(min, max + 1) over parsed bounds, 1..1000 without both, and faults on min > max + 1' do
      expect(router.command('#random 5 5')).to eq('5')
      expect(router.command('#random {#evalmath 2+1} 4').to_i).to be_between(3, 4)
      expect(router.command('#random').to_i).to be_between(1, 1000)
      expect(router.command('#random 7 6')).to eq('7') # min == max + 1: one choice
      expect { router.command('#random 9 5') }.to raise_error(Lich::Genie::Error, described_class::RANDOM_SWAPPED)
    end

    # Command.cs:1103-1132, 3548-3586 R.
    it '#event queues ArrayToString(oArgs, 2) unexpanded, lists with a filter, and clears' do
      router.route('#event 2 #echo $x')
      router.route('#event 1 b')
      router.route('#events b')
      router.route('#event clear')
      router.route('#event')
      nnbsp = [0x202F].pack('U')
      expect(echoes).to eq(['Active event queue: ', 'Filter: b', "(1/1/2026 12:00:01#{nnbsp}AM) b",
                            'Active event queue: ', 'None.'])
    end

    # Command.cs:2229-2238 R -> FormMain.Command_ScriptDebugLevel (FormMain.cs:6083 R).
    it '#script debug|debuglevel sets the level (ToInteger of StringToDouble) for each matching name once' do
      router.route('#script debug 10.6 a')
      router.route('#script DEBUGLEVEL 3 all')
      router.route('#script debug abc b')
      router.route('#script debug 4') # no name: "" = every script (Command_ScriptDebugLevel)
      expect(script_calls).to eq([[11, 'a'], [3, 'a'], [3, 'b'], [-1, 'b'], [4, 'a'], [4, 'b']])
    end

    # Command.cs:2995-3000, 2978-2993 R.
    it 'lists the key codes and the colours' do
      router.route('#keys')
      router.route('#colours')
      expect(echoes.first(3)).to eq(['Available keycodes: ', 'Cancel', 'Back'])
      expect(echoes.count('Available colors: ')).to eq(1)
      expect(echoes.last(2)).to eq(%w[Yellow YellowGreen])
      expect(echoes.length).to eq(1 + described_class::KEY_NAMES.length + 1 + 140)
    end

    # Command.cs:2348-2374 R.
    it '#window position echoes its syntax errors, the IndexOutOfRange of a lone width included' do
      ['#window position', '#window position main 100', '#window position main x 5',
       '#window position main 10 20 30 40 50', '#window position main x 2 3 4 5 6'].each { |row| router.route(row) }
      expect(echoes).to eq(['Syntax Error: Window Name, and one of (Width, Height, Top, or Left) are required.',
                            described_class::INDEX_FAULT,
                            'Syntax Error: Width (x) and/or Height (5) are not formatted correctly.',
                            'Error in command: #window position main 10 20 30 40 50: 1 too many Args in Position command.',
                            'Error in command: #window position main x 2 3 4 5 6: 2 too many Args in Position command. ' \
                            'Window names with spaces need to be "enclosed" in double quotes'])
      router.route('#window position main 0 20 5')
      expect(hooks.last).to eq(['window', { 'action' => 'position', 'name' => 'main', 'width' => nil, 'height' => 20, 'top' => 5, 'left' => nil }])
    end

    # Command.cs:392-416, 2638-2667, 418-446 R.
    it 'echoes #img, #connect and #lc (profile not found) like Remix' do
      ['#img', '#img w:x h:5 >win', '#image #1 width:12 height:zz pic.png', '#connect', '#connect a b c',
       '#lc {Two Words}'].each { |row| router.route(row) }
      expect(echoes).to eq(['No File Name was specified for the Image Command.', 'Invalid Width Specified: w:x',
                            'No File Name was specified for the Image Command.', 'Invalid Height Specified: height:zz',
                            'Invalid number of arguments in #connect command. Syntax: #connect account password character game',
                            'Profile "Two Words" not found. Lich was not started.'])
      expect(hooks.map(&:first)).to eq(%w[image connect])
    end

    it 'hands #lc to the launcher when the profile exists' do
      Dir.mktmpdir('genie-lc') do |dir|
        FileUtils.mkdir_p(File.join(dir, 'Profiles'))
        File.write(File.join(dir, 'Profiles', 'Me.xml'), '<x/>')
        lc = described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t },
                                 send: ->(t) { sends << t }, lists: Lich::Genie::Lists.new(config_dir: dir))
        lc.route('#lc Me')
        expect([echoes, hooks.map(&:first)]).to eq([[], ['lc']])
      end
    end

    # Command.cs:361-385 R; Log.cs R.
    it '#log writes a line to >file or the character\'s daily log, nothing without a log dir' do
      Dir.mktmpdir('genie-log') do |dir|
        logger = described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t },
                                     send: ->(t) { sends << t }, log_dir: -> { dir })
        vars.global_set('charactername', 'Tester')
        vars.global_set('game', 'DR')
        vars.global_set('t', 'X')
        logger.route('#log >out.csv a,$t')
        logger.route('#log missing {match} $t')
        expect(File.binread(File.join(dir, 'out.csv'))).to eq("a,X\r\n")
        log = Dir.glob(File.join(dir, 'TesterDR_*.log')).first
        expect(File.binread(log).force_encoding('UTF-8')).to end_with("missing match X\r\n")
      end
      expect { router.route('#log >f x') }.not_to raise_error
    end

    # v0.26.2: the daily log's date and "LOG CREATED AT" header come from the injected wall clock
    # (Remix's DateTime.Now) in ITS OWN offset -- 23:30 -10:00 on 12/31 is already 1/1 in UTC.
    it '#log names and heads the daily log from the injected wall clock, in its own offset' do
      Dir.mktmpdir('genie-log') do |dir|
        logger = described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t },
                                     send: ->(t) { sends << t }, log_dir: -> { dir },
                                     wall_clock: -> { Time.new(2026, 12, 31, 23, 30, 5, '-10:00') })
        vars.global_set('charactername', 'Tester')
        vars.global_set('game', 'DR')
        logger.route('#log hi')
        expect(Dir.children(dir)).to eq(['TesterDR_2026-12-31.log'])
        expect(File.binread(File.join(dir, 'TesterDR_2026-12-31.log')).force_encoding('UTF-8'))
          .to eq("*** LOG CREATED AT 12/31/2026 11:30:05#{[0x202F].pack('U')}PM ***\r\n\r\nhi\r\n")
      end
    end

    # These arms run their argument text back through ParseAllArgs (a ParseCommand,
    # not sent: its rows run, the LAST row's result is the value) and ParseGlobalVars it
    # (Command.cs:482-486, 2269-2300, 2407-2414 R).
    it '#clear / #status / #statusbar / #comment re-parse their text through ParseAllArgs' do
      vars.global_set('hp', '97')
      router.route('#clear {#var c1 1;main}')
      router.route('#clear')
      router.route('#status 3 {#var c2 2;HP $hp}')
      router.route('#statusbar {HP $hp}')
      router.route('#status 11 x')
      router.route('#status') # one arg: nothing
      router.route('#comment {main} {#var c3 3;Hunting $hp}')
      router.route('#comment main') # two args: nothing
      expect(hooks.map { |op, payload| [op, payload.except('args', 'raw')] }).to eq(
        [['clear', { 'window' => 'main' }], ['clear', { 'window' => '' }],
         ['status', { 'text' => 'HP 97', 'index' => 3 }], ['statusbar', { 'text' => 'HP 97', 'index' => 1 }],
         ['status', { 'text' => '11 x', 'index' => 1 }], ['comment', { 'window' => 'main', 'text' => 'Hunting 97' }]]
      )
      expect(%w[c1 c2 c3].map { |name| vars.global_get(name) }).to eq(%w[1 2 3])
    end

    # No folder is created but the log dir itself (Remix creates Logs at
    # startup, FormMain.cs:2458 R; StreamWriter throws on a missing folder, Log.cs:75 R) -- the failure
    # is one error line (Remix's GenieError) and the row goes on.
    it '#log creates only the log dir: a file in a missing folder echoes the error and writes nothing' do
      Dir.mktmpdir('genie-log') do |root|
        dir = File.join(root, 'Logs')
        logger = described_class.new(vars: vars, eval: evaluator, hooks: hook_sink, echo: ->(t) { echoes << t },
                                     send: ->(t) { sends << t }, log_dir: -> { dir })
        logger.route('#log >sub/x.log a;#var after 1')
        expect(echoes).to eq(["[LogLine: No such file or directory @ rb_sysopen - #{File.join(dir, 'sub', 'x.log')}]"])
        expect([Dir.exist?(dir), Dir.exist?(File.join(dir, 'sub')), vars.global_get('after')]).to eq([true, false, '1'])
        echoes.clear
        rooted = File.join(root, 'abs.log')
        logger.route("#log >#{rooted} b") # rooted: its own path (Path.Combine)
        expect([File.binread(rooted), echoes]).to eq(["b\r\n", []])
        vars.global_set('charactername', 'Tester')
        FileUtils.rm_rf(dir)
        File.write(dir, '') # the log dir is a file: LogText fails
        logger.route('#log text')
        expect(echoes.first).to start_with('[LogText: ')
      end
    end

    # Command.cs:1234-1354 R; Classes.cs R.
    it '#class: all on|off echo, all <other> changes nothing, clear raises no class event, filters are ordinal' do
      router.route('#class foo on')
      router.route('#class all whatever')
      router.route('#class all OFF')
      router.route('#class Foo')
      router.route('#class clear')
      router.route('#class')
      expect(echoes).to eq(['All Classes InActivated', 'Active classes: ', 'Filter: Foo', 'None.', 'Classes Cleared',
                            'Active classes: ', 'default=True'])
      expect(hooks.map(&:first)).to eq(%w[class class class class]) # foo on, all whatever, all OFF, the listing
    end

    # Command.cs:1744-1804, 1872-1884, 1661-1742 R; flow t218.
    it '#gag/#sub: list words, the TRUE-is-IgnoreCase quirk, the echoed texts, exact removes' do
      router.route('#gag {/^x/} {cls} TRUE')
      router.route('#gag list')
      router.route('#gag {(bad} {x}')
      router.route('#sub {(bad} {x}')
      router.route('#sub keep')
      router.route('#ungag ^x')
      router.route('#unsub nothing')
      expect(lists.filters.gags.map { |g| [g.text, g.ignore_case, g.klass] }).to eq([['list', false, '']])
      expect(echoes).to eq(['Invalid regexp in gag: (bad x', 'Invalid regexp in substitute: (bad',
                            'Active substitutes: ', 'Filter: keep', 'None.'])
    end

    # Command.cs:1166-1232, 235-241, 2746-2777 R; flow t221.
    it '#alias fills the engine\'s list a put expands; #unalias and #unclass remove from it' do
      router.route('#alias {nx} {recall nexus list}')
      router.route('nx')
      router.route('#unclass nx')
      router.route('nx')
      router.route('#alias {k} {kneel}')
      router.route('#alias k')
      expect(sends).to eq(['recall nexus list ', 'nx'])
      expect(echoes).to eq(['Active aliases: ', 'Filter: k', 'k=kneel'])
    end

    # Command.cs:1491-1525 R; Config.cs:1478-1489 R.
    it '#config echoes "Invalid syntax: <row>" and the exception message, applying nothing' do
      router.route('#config bogus 1')
      router.route('#settings maxgosubdepth abc')
      expect(echoes).to eq(['Invalid syntax: #config bogus 1', 'Config bogus was not recognized.',
                            'Invalid syntax: #settings maxgosubdepth abc',
                            "Conversion from string \"abc\" to type 'Integer' is not valid."])
      expect(hooks).to eq([])
    end

    # Command.cs:1806-1870, 1595-1630 R.
    it '#preset refuses an unknown key; the front-end list words echo their line' do
      ['#preset foo bar', '#preset roomname #00ff00', '#macro clear', '#names load', '#highlight save'].each { |row| router.route(row) }
      expect(echoes).to eq(['Invalid #preset keyword.', 'Macros Cleared', 'Names Loaded', 'Highlights Saved'])
      expect(hooks.map(&:first)).to eq(%w[preset macro name highlight])
    end

    # Command.cs:295-313 R; ColorCode.cs:27-50, 132-153 R; flow t215.
    it '#echo drops a colour name (any case, or the fg of fg,bg) but keeps a non-colour word' do
      ['#echo red text', '#echo RED,blue a', '#echo zzz,red b', '#echo RebeccaPurple c', '#echo Crimson >Log d'].each { |row| router.route(row) }
      expect(echoes).to eq(['text', 'a', 'zzz,red b', 'RebeccaPurple c'])
      expect(hooks).to eq([['echo', { 'window' => 'Log', 'text' => 'd' }]])
    end
  end
end
