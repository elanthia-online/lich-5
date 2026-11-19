# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

RSpec.describe Lich::Genie::Triggers do
  subject(:triggers) { described_class.new }

  # Collect what would fire for a line.
  def fired(line)
    out = []
    triggers.apply(line) { |commands, captures| out << [commands, captures] }
    out
  end

  it 'fires an active trigger and passes regex captures' do
    triggers.add('You hit (\\w+) for (\\d+)', 'echo hit $1 for $2')
    expect(fired('You hit kobold for 25')).to eq([['echo hit $1 for $2', %w[kobold 25]]])
  end

  it 'does not fire a non-matching line' do
    triggers.add('^You die', 'put stand')
    expect(fired('You feel fine')).to eq([])
  end

  it 'fires multiple matching triggers' do
    triggers.add('kobold', 'put attack')
    triggers.add('kobold', 'echo seen') # same pattern replaces
    triggers.add('goblin', 'put flee')
    expect(fired('a kobold and a goblin').map(&:first)).to contain_exactly('echo seen', 'put flee')
  end

  describe 'class gating' do
    it 'does not fire a trigger whose class is off, and resumes when on' do
      triggers.add('rest', 'put stand', klass: 'combat')
      triggers.toggle_class('combat', false)
      expect(fired('you rest')).to eq([])
      triggers.toggle_class('combat', true)
      expect(fired('you rest')).to eq([['put stand', []]])
    end

    it 'always fires a classless trigger' do
      triggers.add('rest', 'put stand')
      triggers.toggle_class('combat', false)
      expect(fired('you rest')).to eq([['put stand', []]])
    end

    it 'is case-insensitive on the class name' do
      triggers.add('rest', 'put stand', klass: 'Combat')
      triggers.toggle_class('combat', false)
      expect(fired('you rest')).to eq([])
    end
  end

  describe 'management' do
    it 'removes a trigger by pattern (#untrigger)' do
      triggers.add('spam', 'echo x')
      triggers.remove('spam')
      expect(fired('spam spam')).to eq([])
    end

    it 'clears all triggers' do
      triggers.add('a', 'echo a')
      triggers.add('b', 'echo b')
      triggers.clear
      expect(triggers.count).to eq(0)
    end

    it 'lists triggers with class + active state' do
      triggers.add('a', 'put x', klass: 'combat')
      triggers.toggle_class('combat', false)
      expect(triggers.list).to eq([{ 'pattern' => 'a', 'class' => 'combat', 'active' => false, 'commands' => 'put x' }])
    end

    it 'returns true when it adds a trigger' do
      expect(triggers.add('^ok', 'echo ok')).to be(true)
    end
  end

  # Triggers.Add (Globals.cs:1001-1037 R): the registry key is the pattern with its
  # `e/`/`eval `/leading `/` prefix and `/i`/`/` suffix stripped; a non-eval key must
  # compile (ValidateRegExp, Globals.cs:1025-1028 R) or nothing is added.
  describe 'Remix pattern normalization and validation' do
    it 'rejects a non-eval pattern that is not a valid regex, adding nothing (no literal fallback)' do
      triggers.add('^keep', 'echo keep')
      expect(triggers.add('what (is', 'echo hi')).to be(false)
      expect(triggers.add('/[abc/i', 'echo hi')).to be(false)
      expect(triggers.list.map { |t| t['pattern'] }).to eq(['^keep'])
      expect(fired('what (is this [abc')).to eq([])
    end

    it 'does not let an invalid pattern replace an existing trigger with the same key' do
      triggers.add('(', 'old')
      expect(triggers.count).to eq(0)
      triggers.add('^a', 'old')
      expect(triggers.add('/^a(/', 'new')).to be(false)
      expect(fired('a')).to eq([['old', []]])
    end

    it 'keeps an eval trigger whose body is not a regex, and never fires it (eval semantics)' do
      expect(triggers.add('e/[x/', 'echo e')).to be(true)
      expect(triggers.add('eval $y > (', 'echo v')).to be(true)
      expect(triggers.count).to eq(2)
      expect(fired('[x')).to eq([])
      expect(fired('e/[x/')).to eq([])
      expect(triggers.diagnose('[x')).to eq([])
    end

    it 'replaces by normalized key, last writer wins (foo, /foo/i, foo -> foo {c})' do
      triggers.add('foo', 'a')
      triggers.add('/foo/i', 'b')
      triggers.add('foo', 'c')
      expect(triggers.list).to eq([{ 'pattern' => 'foo', 'class' => '', 'active' => true, 'commands' => 'c' }])
      expect(fired('FOO')).to eq([])
      expect(fired('foo')).to eq([['c', []]])
    end

    it '/re/i replaces the plain trigger and matches case-insensitively (q14)' do
      triggers.add('^foo', 'A')
      triggers.add('/^foo/i', 'B')
      expect(fired('foo')).to eq([['B', []]])
      expect(fired('FOO')).to eq([['B', []]])
    end

    it 'strips /re/ delimiters before compiling, and an eval trigger is replaced by a plain one' do
      triggers.add('/^bar/', 'slashed')
      expect(fired('bar')).to eq([['slashed', []]])
      triggers.add('e/baz/', 'd')
      triggers.add('baz', 'e')
      expect(triggers.list.map { |t| [t['pattern'], t['commands']] }).to eq([%w[/^bar/ slashed], %w[baz e]])
      expect(fired('baz')).to eq([['e', []]])
    end

    it 'adds an empty pattern, which matches every line (Remix keeps key "")' do
      expect(triggers.add('', 'every')).to be(true)
      expect(fired('anything')).to eq([['every', []]])
      triggers.add('/', 'slash') # normalizes to the same empty key
      expect(triggers.list.map { |t| t['commands'] }).to eq(['slash'])
    end

    it 'removes by normalized key (Triggers.Remove, Globals.cs:1039-1066 R)' do
      triggers.add('/foo/i', 'x')
      triggers.add('e/bar/', 'y')
      triggers.add('baz', 'z')
      triggers.remove('foo')
      triggers.remove('eval bar')
      triggers.remove('/baz/i')
      expect(triggers.count).to eq(0)
    end

    it 'rejects a pattern with invalid UTF-8 bytes instead of raising' do
      bad = "ab#{[0xFF].pack('C')}c".dup.force_encoding(Encoding::UTF_8)
      expect(triggers.add(bad, 'x')).to be(false)
      expect(described_class.valid_pattern?(bad)).to be(false)
      expect { triggers.remove(bad) }.not_to raise_error
      expect(triggers.add("EVAL #{bad}", 'y')).to be(true) # eval: stored, not compiled
      triggers.add('zz', 'q')
      Dir.mktmpdir do |dir| # every row is written, the bad byte as U+FFFD (Remix strings are never invalid)
        file = File.join(dir, 'triggers.cfg')
        expect(triggers.save(file)).to be(true)
        expect(File.binread(file)).to eq("#trigger {e/ab#{[0xFFFD].pack('U').b}c/} {y}\r\n#trigger {zz} {q}\r\n".b)
      end
    end

    it 'valid_pattern? mirrors what add accepts' do
      expect(described_class.valid_pattern?('^ok(')).to be(false)
      expect(described_class.valid_pattern?('/[a/i')).to be(false)
      expect(described_class.valid_pattern?('e/[a/')).to be(true)
      expect(described_class.valid_pattern?('')).to be(true)
      expect(described_class.valid_pattern?('/^ok/i')).to be(true)
    end

    # Remix's ValidateRegExp is `new Regex(s)` (Utility.cs:113-126 R) -- the .NET
    # grammar. Validity now goes through NetRegex; evidence: probe
    # s07_regex_validity (genieflow Remix vs ours). (`a**` is also Remix-invalid; it is
    # left out because Onigmo prints a "redundant nested repeat" warning for it.)
    it 'rejects patterns .NET Regex rejects but Onigmo accepts' do
      remix_invalid = ['a++', '\\Qx', '\\h', '\\R', '\\y', '\\K', '\\X', 'a?+']
      expect(remix_invalid.select { |p| described_class.valid_pattern?(p) }).to eq([])
      remix_invalid.each { |p| expect(triggers.add(p, 'x')).to be(false) }
      expect(triggers.count).to eq(0)
    end

    it 'accepts the corpus .NET-only patterns Onigmo rejects raw ([\\w-\'], capturing lookbehind)' do
      remix_valid = ["[\\w-']", '(?<=(field|full) )\\bplate\\b']
      expect(remix_valid.reject { |p| described_class.valid_pattern?(p) }).to eq([])
      remix_valid.each { |p| expect(triggers.add(p, 'x')).to be(true) }
      expect(triggers.count).to eq(2)
      fired = []
      triggers.apply("o'brien and full plate") { |_commands, captures| fired << captures }
      # SortedList order of the keys ('(' before '['); the lookbehind group is a placeholder "" (NetRegex doc)
      expect(fired).to eq([[''], []])
    end

    it 'accepts and fires a variable-length lookbehind like Remix (NetRegex::Emulated)' do
      expect(described_class.valid_pattern?('(?<=a+)b')).to be(true)
      expect(described_class.unsupported('(?<=a+)b')).to be_nil
      expect(triggers.add('(?<=a+)(b)', 'x')).to be(true)
      fired = []
      triggers.apply('cb aab') { |_commands, captures| fired << captures }
      expect(fired).to eq([['b']])
    end

    it 'stores an Unsupported pattern (valid in .NET) that never fires, and reports it' do
      expect(described_class.valid_pattern?('(?:x(?<=a+)y)+')).to be(true)
      expect(described_class.unsupported('(?:x(?<=a+)y)+').reason).to eq('a variable-length lookbehind inside a quantified group')
      expect(described_class.unsupported('e/$x > 1/')).to be_nil
      expect(described_class.unsupported('^plain')).to be_nil
      expect(triggers.add('(?:x(?<=a+)y)+', 'x')).to be(true)
      fired = []
      triggers.apply('aaxy') { |commands, _captures| fired << commands }
      expect([fired, triggers.count]).to eq([[], 1])
    end
  end

  describe '#diagnose' do
    it 'reports matching triggers with class + active state, without firing' do
      triggers.add('^You wave', 'put x', klass: 'casting')
      triggers.add('^You prime', 'put y', klass: 'charging')
      triggers.toggle_class('casting', false) # class off -> would not fire

      result = triggers.diagnose('You wave.')
      expect(result).to eq([{ 'pattern' => '^You wave', 'class' => 'casting', 'active' => false }])
    end

    it 'returns an empty array when nothing matches' do
      triggers.add('^You gesture', 'put x')
      expect(triggers.diagnose('nothing here')).to eq([])
    end

    it 'matches outside the registry lock, so a slow pattern does not hold other callers' do
      triggers.add('^slow', 'put x')
      entered = Queue.new
      release = Queue.new
      blocking = Object.new
      blocking.define_singleton_method(:match?) do |_line|
        entered << true
        release.pop
        true
      end
      triggers.instance_variable_get(:@triggers).each_value { |t| t.regex = blocking }
      worker = Thread.new { triggers.diagnose('slow line') }
      begin
        entered.pop
        other = Thread.new { triggers.count } # takes the lock
        expect(other.join(2)&.value).to eq(1)
      ensure
        release << true
      end
      expect(worker.value.map { |m| m['pattern'] }).to eq(['^slow'])
    end
  end

  # triggers.cfg (Globals.cs:1077-1182 R).
  describe 'save / load / dispatch' do
    around { |example| Dir.mktmpdir('genie-triggers') { |dir| @dir = dir; example.run } }

    def path = File.join(@dir, 'Config', 'triggers.cfg')

    it 'saves every trigger, active or not, and a fresh registry loads them back active' do
      triggers.add('^b', 'put b', klass: 'cls')
      triggers.add('^a', 'put a')
      triggers.toggle_class('cls', false)
      expect(triggers.save(path)).to be(true)
      expect(File.binread(path)).to eq("#trigger {^a} {put a}\r\n#trigger {^b} {put b} {cls}\r\n")

      fresh = described_class.new
      expect(fresh.load(path)).to be(true)
      expect(fresh.list).to contain_exactly(
        { 'pattern' => '^a', 'class' => '', 'active' => true, 'commands' => 'put a' },
        { 'pattern' => '^b', 'class' => 'cls', 'active' => true, 'commands' => 'put b' }
      )
    end

    it 'load merges into the registry and replaces same-pattern triggers' do
      Lich::Genie::ConfigFile.write_lines(path, ['#trigger {^a} {from disk}'])
      triggers.add('^a', 'live')
      triggers.add('^z', 'kept')
      triggers.load(path)
      expect(triggers.list.to_h { |t| [t['pattern'], t['commands']] }).to eq('^a' => 'from disk', '^z' => 'kept')
    end

    it 'returns false for a missing file, a nil path, or an unwritable target' do
      expect(triggers.load(path)).to be(false)
      expect(triggers.load(nil)).to be(false)
      expect(triggers.save(nil)).to be(false)
      File.write(File.join(@dir, 'Config'), 'a file where the directory should be')
      expect(triggers.save(path)).to be(false)
    end

    it 'load skips rows whose pattern is not a valid regex and keeps the rest (LoadRow ignores Add)' do
      Lich::Genie::ConfigFile.write_lines(path, ['#trigger {[bad} {#echo bad}', '#trigger {^ok} {#echo ok}'])
      expect(triggers.load(path)).to be(true)
      expect(triggers.list.map { |t| t['pattern'] }).to eq(['^ok'])
      expect(fired('[bad')).to eq([])
      triggers.save(path)
      expect(File.binread(path)).to eq("#trigger {^ok} {#echo ok}\r\n")
    end

    it 'load of a file that cannot be read returns false, keeps the registry and does not raise' do
      Lich::Genie::ConfigFile.write_lines(path, ['#trigger {^disk} {x}'])
      triggers.add('^live', 'y')
      allow(File).to receive(:binread).and_call_original
      allow(File).to receive(:binread).with(path).and_raise(Errno::EACCES, path)
      expect(triggers.load(path)).to be(false)
      expect(triggers.list.map { |t| t['pattern'] }).to eq(['^live'])
    end

    it 'save returns false instead of raising on any error (Save is catch (Exception), Globals.cs:1176-1181 R)' do
      allow(Lich::Genie::TriggerFile).to receive(:save).and_raise(ArgumentError, 'input string invalid')
      triggers.add('^a', 'b')
      expect(triggers.save(path)).to be(false)
    end

    # Batch-1 deferred item: two threads saving at once (a script's `#trigger save`, a trigger
    # body's) must not let the older snapshot land last. Without @save_mutex the second save
    # snapshots and writes while the first is still writing, and the first then overwrites it.
    it 'serializes concurrent saves so an older snapshot never lands after a newer one' do
      triggers.add('^a', 'one')
      order = Queue.new
      entered = Queue.new
      release = Queue.new
      allow(Lich::Genie::TriggerFile).to receive(:save) do |_target, rows|
        commands = rows.map { |t| t['commands'] }
        entered << commands
        release.pop if commands == ['one']
        order << commands
      end
      first = Thread.new { triggers.save(path) }
      begin
        expect(entered.pop).to eq(['one'])
        triggers.add('^a', 'two') # the registry lock is free while the first save writes
        second = Thread.new { triggers.save(path) }
        expect(second.join(0.2)).to be_nil # still waiting for the first write
        expect(entered.size).to eq(0)
      ensure
        release << true
      end
      expect([first, second].compact.map { |t| t.join(2)&.value }).to eq([true, true])
      expect(Array.new(order.size) { order.pop }).to eq([['one'], ['two']])
    end
  end

  # The eval triggers FormMain.TriggerVariableChanged wakes (FormMain.cs:4940-4946 R).
  describe '#eval_candidates' do
    subject(:triggers) { described_class.new }

    it 'returns active eval triggers whose normalized key contains the name, never regex ones' do
      triggers.add('e/$ta = 1/', 'cmd-a')
      triggers.add('eval $tab', 'cmd-b')
      triggers.add('$ta', 'cmd-regex')
      triggers.add('e/$tb/', 'cmd-c', klass: 'k')
      triggers.toggle_class('k', false)
      expect(triggers.eval_candidates('$ta')).to eq([['$ta = 1', 'cmd-a', false], ['$tab', 'cmd-b', false]])
      expect(triggers.eval_candidates('$tb')).to eq([])
      expect(triggers.eval_candidates('lastcommand')).to eq([])
    end

    it 'is a snapshot: a trigger added while walking it is not in it' do
      triggers.add('e/$x/', 'a')
      list = triggers.eval_candidates('$x')
      triggers.add('e/$xy/', 'b')
      expect(list.map { |_key, commands, _authored| commands }).to eq(['a'])
    end
  end

  # Onigmo backtracks catastrophically on some patterns .NET runs fast; a
  # #trigger is matched against every game line on the trigger worker, so a plain-Regexp pattern
  # gets a match timeout and a timed-out match is no match (the others still fire). As a
  # decided divergence, TIMEOUT_LIMIT consecutive timeouts shut the trigger off, with ONE report.
  describe 'match timeout' do
    let(:registry) { described_class.new }
    let(:disabled) { [] }
    let(:slow) { "#{'a' * 28}!" } # catastrophic for (a+)+\1c

    before do
      stub_const("#{described_class}::MATCH_TIMEOUT_SECONDS", 0.05)
      registry.add('^a', 'fast')
      registry.add('(a+)+\\1c', 'slow2')
      registry.on_disabled = ->(pattern) { disabled << pattern }
    end

    def fired(line)
      [].tap { |out| registry.apply(line) { |commands, _captures| out << commands } }
    end

    it 'gives a compiled plain pattern a timeout' do
      expect(described_class.compile(Lich::Genie::TriggerFile.normalize('^a')).timeout).to eq(described_class::MATCH_TIMEOUT_SECONDS)
    end

    it 'treats a timed-out match as no match and fires the others, reporting nothing below the limit' do
      expect(fired(slow)).to eq(['fast'])
      expect(fired(slow)).to eq(['fast'])
      expect(disabled).to eq([])
      expect(fired('aac')).to eq(%w[slow2 fast]) # still matched (SortedList order: '(' before '^')
      expect(registry.diagnose(slow).map { |m| m['pattern'] }).to eq(['^a'])
    end

    it 'shuts a trigger off at the third timeout in a row, reporting it once; it is never matched again' do
      3.times { fired(slow) }
      expect(disabled).to eq(['(a+)+\\1c'])
      expect(fired('aac')).to eq(['fast']) # would match: no longer tried
      fired(slow)
      expect(disabled.length).to eq(1)
      expect(registry.diagnose('aac').map { |m| m['pattern'] }).to eq(['^a'])
      expect(registry.list.map { |t| t['pattern'] }).to include('(a+)+\\1c') # still listed (and saved)
    end

    it 'counts only consecutive timeouts: a completed match (hit or miss) resets the count' do
      2.times { fired(slow) }
      fired('b') # completes, no match
      2.times { fired(slow) }
      fired('aac') # completes, a match
      2.times { fired(slow) }
      expect(disabled).to eq([])
      fired(slow)
      expect(disabled).to eq(['(a+)+\\1c'])
    end

    it 'enables a shut-off trigger again when it is added again' do
      3.times { fired(slow) }
      registry.add('(a+)+\\1c', 'slow2')
      expect(fired('aac')).to eq(%w[slow2 fast])
    end
  end

  # ParseTriggers walks the SortedList (FormMain.cs:4431-4457 R; Globals.cs:939 R) and
  # reads IsActive as it reaches each trigger, so an earlier action's #class decides later ones on
  # the same line (flow t219_trigger_order_class).
  describe 'firing order and the per-pass IsActive read' do
    it 'fires in SortedList order of the key, not insertion order' do
      %w[^go o$ ^(g)(o) go$ ^g].each { |pattern| triggers.add(pattern, pattern) }
      order = []
      triggers.apply('go') { |commands, _| order << commands }
      expect(order).to eq(%w[^(g)(o) ^g ^go go$ o$])
    end

    it 'reads each trigger\'s state when the loop reaches it (an earlier action switches a later one)' do
      triggers.add('x1', 't1')
      triggers.add('x2', 't2', klass: 'c2')
      triggers.add('x3', 't3', klass: 'c3')
      triggers.toggle_class('c3', false)
      seen = []
      triggers.apply('x1 x2 x3') do |commands, _|
        seen << commands
        next unless commands == 't1'

        triggers.toggle_class('c2', false) # x2 not reached yet: skipped
        triggers.toggle_class('c3', true) # x3 off when the pass began: fires
      end
      expect(seen).to eq(%w[t1 t3])
    end

    it 'does not fire a trigger an earlier action added on the same line (Remix: the add fails)' do
      triggers.add('^a', 'adder')
      seen = []
      triggers.apply('ab') do |commands, _|
        seen << commands
        triggers.add('b', 'new') if commands == 'adder'
      end
      expect(seen).to eq(['adder'])
      triggers.apply('ab') { |commands, _| seen << commands }
      expect(seen).to eq(%w[adder adder new])
    end

    it 'toggles "" (Command_EventClassChange\'s `default`) on the class-less triggers, lower-cased names' do
      triggers.add('^a', 'plain')
      triggers.add('^b', 'mixed', klass: 'MiXed')
      triggers.toggle_class('', false)
      triggers.toggle_class('mixed', false)
      expect(triggers.entries.map { |e| e[4] }).to eq([false, false])
    end
  end
end
