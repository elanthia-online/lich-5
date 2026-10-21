# frozen_string_literal: true

require_relative 'support/example_timeout'
require 'fileutils'
require 'timeout'
require 'tmpdir'
require_relative 'support/flow_harness'

# The flow-parity harness is itself test code that decides "MATCH" for 14 hard parity
# expectations, so its parsing, alignment, tolerance and clock model are pinned here.
RSpec.describe GenieSpecSupport::Flow do
  flow = described_class
  fixture_dir = File.expand_path('../../fixtures/genie/flow', __dir__)

  # Write a throwaway script dir and run a trace through our engine.
  def run_script(source, trace_lines = [], name: 'h', extra: {})
    Dir.mktmpdir('genie-flow') do |dir|
      File.write(File.join(dir, "#{name}.cmd"), source)
      extra.each { |file, text| File.write(File.join(dir, file), text) }
      trace = File.join(dir, "#{name}.trace")
      File.write(trace, trace_lines.join("\n"))
      return GenieSpecSupport::Flow::OurRun.new(dir).run(name, [], GenieSpecSupport::Flow.parse_trace(trace)).events
    end
  end

  def texts(events, kind) = events.select { |e| e['ev'] == kind }.map { |e| [e['t'], e['text']] }

  describe '.parse_trace' do
    it 'drops blank and comment lines, upcases the keyword, keeps the rest verbatim, strips CR' do
      Dir.mktmpdir do |d|
        path = File.join(d, 'x.trace')
        File.write(path, "# c\n\n   # indented comment\nin  two  spaces\r\nPROMPT 3\nexpect /a b/ 100\n")
        got = flow.parse_trace(path).map { |x| [x.kw, x.rest, x.line] }
        expect(got).to eq([['IN', ' two  spaces', 4], ['PROMPT', '3', 5], ['EXPECT', '/a b/ 100', 6]])
      end
    end

    # Real capture rows can hold invalid UTF-8 (a truncated character, 0xFF).
    it 'keeps an invalid UTF-8 row byte for byte instead of raising, and the engine decodes it to U+FFFD' do
      trunc = "trunc #{[0xE2, 0x82].pack('C*')} end".b # a 3-byte character cut after 2 bytes
      cafe = "ok caf#{[0xC3, 0xA9].pack('C*')}".b # valid UTF-8
      Dir.mktmpdir do |d|
        path = File.join(d, 'x.trace')
        File.binwrite(path, "IN #{trunc}\r\nIN #{cafe}\nWAIT 10\n".b)
        got = flow.parse_trace(path)
        expect(got.map { |x| [x.kw, x.rest.b, x.rest.encoding] })
          .to eq([['IN', trunc, Encoding::UTF_8], ['IN', cafe, Encoding::UTF_8], ['WAIT', '10'.b, Encoding::UTF_8]])
      end
      events = run_script("action echo A:{$0} when end$\nwaitfor ZZZ\n", ["IN #{trunc}".b, 'WAIT 100'])
      expect(texts(events, 'echo').map(&:last)).to eq(["A:{trunc #{[0xFFFD].pack('U')} end}"])
    end

    it 'returns no directives for a nil or missing path' do
      expect(flow.parse_trace(nil)).to eq([])
      expect(flow.parse_trace('/nonexistent/x.trace')).to eq([])
    end
  end

  describe '.discover' do
    it 'skips _helpers, reads .args/.flags, and honours .only per tree' do
      remix = flow.discover(fixture_dir, tree: 'remix')
      upstream = flow.discover(fixture_dir, tree: 'upstream')
      expect(remix.map(&:name)).not_to include('_t19_helper', '_t30_waiter')
      expect(remix.find { |c| c.name == 't09_shift_args' }.args).to eq(%w[x y z])
      t49 = remix.find { |c| c.name == 't49_waitfor_lastrow_chunk' }
      expect(t49.flags).to eq(%w[--trigger-delivery chunk])
      expect(t49.label).to eq('t49_waitfor_lastrow_chunk [--trigger-delivery chunk]')
      expect(upstream.map(&:name)).not_to include('t49_waitfor_lastrow_chunk')
      expect(remix.length - upstream.length).to eq(1)
    end
  end

  describe '.parse_flags' do
    it 'accepts the supported genieflow options with their values' do
      expect(flow.parse_flags(%w[--trigger-delivery chunk --no-config])).to eq('--trigger-delivery' => 'chunk', '--no-config' => true)
      expect(flow.parse_flags([])).to eq({})
    end

    it 'raises on an option our side cannot honour instead of ignoring it' do
      expect { flow.parse_flags(%w[--tail 500]) }.to raise_error(ArgumentError, /unsupported \.flags option "--tail"/)
      expect { flow.parse_flags(%w[--trigger-delivery row --seed 3]) }.to raise_error(ArgumentError, /"--seed"/)
    end

    it 'raises when a valued option is last or followed by another option' do
      expect { flow.parse_flags(%w[--trigger-delivery]) }.to raise_error(ArgumentError, /needs a value/)
      expect { flow.parse_flags(%w[--config-dir --no-config]) }.to raise_error(ArgumentError, /--config-dir needs a value/)
    end

    it 'is applied by run_ours, and every frozen fixture passes it' do
      bad = flow::Case.new('t06_math', File.join(fixture_dir, 't06_math.cmd'), nil, [], %w[--maxms 10], nil, fixture_dir)
      expect { flow.run_ours(bad) }.to raise_error(ArgumentError, /--maxms/)
      expect { flow.discover(fixture_dir).each { |c| flow.parse_flags(c.flags) } }.not_to raise_error
    end

    it 'validates the --trigger-delivery value like genieflow (row|chunk|sync, any case; Program.cs:194-199)' do
      expect(flow.parse_flags(%w[--trigger-delivery SYNC])).to eq('--trigger-delivery' => 'SYNC')
      expect { flow.parse_flags(%w[--trigger-delivery rows]) }.to raise_error(ArgumentError, /must be row\|chunk\|sync \(got "rows"\)/)
      expect { flow.parse_flags(%w[--trigger-delivery x --no-config]) }.to raise_error(ArgumentError, /"x"/)
    end

    # genieflow --config-dir loads 11 files (flow-oracle/src/ConfigLoad.cs:62-72); ours models
    # variables.cfg, triggers.cfg, settings.cfg and the engine-owned lists aliases.cfg,
    # substitutes.cfg, gags.cfg, classes.cfg -- a front-end file (macros.cfg, ...) would be silently
    # ignored on our side.
    it 'raises when a .flags --config-dir holds a config file our side does not load' do
      Dir.mktmpdir('genie-flow') do |dir|
        Dir.mkdir(File.join(dir, 'cfg'))
        File.write(File.join(dir, 'cfg', 'variables.cfg'), "#var {cfgvar} {x}\n")
        File.write(File.join(dir, 'cfg', 'triggers.cfg'), "#trigger {a} {b}\n")
        File.write(File.join(dir, 'cfg', 'aliases.cfg'), "#alias {a} {b}\n")
        File.write(File.join(dir, 'cfg', 'macros.cfg'), "#macro {F1} {b}\n")
        File.write(File.join(dir, 'c.cmd'), "echo hi\n")
        flow_case = flow::Case.new('c', File.join(dir, 'c.cmd'), nil, [], %w[--config-dir cfg], nil, dir)
        expect { flow.run_ours(flow_case) }.to raise_error(ArgumentError, /not modelled on our side: macros\.cfg\z/)
      end
    end

    # The lists genieflow's startup loads from --config-dir reach our side too.
    it 'loads aliases.cfg, gags.cfg, substitutes.cfg and classes.cfg from a .flags --config-dir' do
      Dir.mktmpdir('genie-flow') do |dir|
        Dir.mkdir(File.join(dir, 'cfg'))
        File.write(File.join(dir, 'cfg', 'aliases.cfg'), "#alias {nx} {recall}\n")
        File.write(File.join(dir, 'cfg', 'classes.cfg'), "#class {k} {False}\n")
        File.write(File.join(dir, 'cfg', 'gags.cfg'), "#gag {^hide}\n")
        File.write(File.join(dir, 'cfg', 'substitutes.cfg'), "#subs {^a} {b}\n")
        File.write(File.join(dir, 'c.cmd'), "put nx\nput #class\nput #gag\nput #sub\n")
        flow_case = flow::Case.new('c', File.join(dir, 'c.cmd'), nil, [], %w[--config-dir cfg], nil, dir)
        events = flow.run_ours(flow_case)
        expect(events.select { |e| e['ev'] == 'send' }.map { |e| e['text'] }).to eq(['recall '])
        expect(events.select { |e| e['ev'] == 'echo' }.map { |e| e['text'] })
          .to eq(['Active classes: ', 'default=True', 'k=False', 'Active gags: ', '^hide', 'Active substitutes: ', '^a => b'])
      end
    end

    it 'accepts a --config-dir with no config files at all (genieflow skips missing files)' do
      Dir.mktmpdir('genie-flow') do |dir|
        Dir.mkdir(File.join(dir, 'cfg'))
        File.write(File.join(dir, 'cfg', 'README.txt'), "not a config file\n")
        File.write(File.join(dir, 'c.cmd'), "echo hi\n")
        events = flow.run_ours(flow::Case.new('c', File.join(dir, 'c.cmd'), nil, [], %w[--config-dir cfg], nil, dir))
        expect(texts(events, 'echo').map(&:last)).to eq(['hi'])
      end
    end

    it 'raises when the .flags --config-dir does not exist' do
      Dir.mktmpdir('genie-flow') do |dir|
        File.write(File.join(dir, 'c.cmd'), "echo hi\n")
        flow_case = flow::Case.new('c', File.join(dir, 'c.cmd'), nil, [], %w[--config-dir nope], nil, dir)
        expect { flow.run_ours(flow_case) }.to raise_error(ArgumentError, /--config-dir .*nope is not a directory/)
      end
    end

    it 'loads variables.cfg from a .flags --config-dir relative to the case dir' do
      Dir.mktmpdir('genie-flow') do |dir|
        Dir.mkdir(File.join(dir, 'cfg'))
        File.write(File.join(dir, 'cfg', 'variables.cfg'), "#var {cfgvar} {from-cfg}\n")
        File.write(File.join(dir, 'c.cmd'), "echo v=$cfgvar\n")
        events = flow.run_ours(flow::Case.new('c', File.join(dir, 'c.cmd'), nil, [], %w[--config-dir cfg], nil, dir))
        expect(texts(events, 'echo').map(&:last)).to eq(['v=from-cfg'])
      end
    end

    # variables.cfg goes through the production loader
    # (GlobalStore.new(file:), as Lich::Genie.global_store builds it), so a Remix-reserved row
    # is skipped (a decided approximation: Remix's next game update overwrites it) instead of shadowing the game value, and
    # `#var save` writes the run's private copy (genieflow: its sandboxed --config-dir copy),
    # never the case dir.
    it 'loads variables.cfg through the production loader and saves only to a private copy' do
      Dir.mktmpdir('genie-flow') do |dir|
        Dir.mkdir(File.join(dir, 'cfg'))
        original = "#var {roomname} {stale room}\r\n#var {cfgvar} {from-cfg}\r\n"
        File.binwrite(File.join(dir, 'cfg', 'variables.cfg'), original)
        File.write(File.join(dir, 'c.cmd'), "echo r=[$roomname] v=$cfgvar\nput #var added 1\nput #var save\necho done\n")
        saved = []
        allow(Lich::Genie::VariableFile).to receive(:save).and_wrap_original do |orig, target, rows|
          saved << [target, rows.keys.sort]
          orig.call(target, rows)
        end
        events = flow.run_ours(flow::Case.new('c', File.join(dir, 'c.cmd'), nil, [], %w[--config-dir cfg], nil, dir))
        expect(texts(events, 'echo').map(&:last)).to eq(['r=[] v=from-cfg', 'Variables Saved', 'done'])
        expect(saved.map(&:last)).to eq([%w[added cfgvar]])
        expect(File.dirname(saved.first.first)).not_to eq(File.join(dir, 'cfg'))
        expect(File.binread(File.join(dir, 'cfg', 'variables.cfg'))).to eq(original)
        expect(Dir.children(File.join(dir, 'cfg'))).to eq(['variables.cfg'])
      end
    end
    # genieflow loads settings.cfg (ConfigLoad.cs:62-72) into Remix's
    # Config; OurRun builds its GameState from it the way production does (SettingsFile.read
    # + Config.from_settings, Lich::Genie.build_game_state). A tester's monstercountignorelist
    # (storm-grey cat, leopard): Remix gives mc=1 on this row (probe genieflow tir.*).
    it "builds the GameState from a --config-dir's settings.cfg (monstercountignorelist, mc=1 like Remix)" do
      Dir.mktmpdir('genie-flow') do |dir|
        Dir.mkdir(File.join(dir, 'cfg'))
        FileUtils.cp(File.expand_path('../../fixtures/genie/game_state/tester_settings_excerpt.cfg', __dir__), File.join(dir, 'cfg', 'settings.cfg'))
        File.write(File.join(dir, 'c.cmd'), "waitfor MARK1\necho mc=[$monstercount] ml=[$monsterlist]\n")
        File.write(File.join(dir, 'c.trace'), <<~TRACE)
          IN <component id='room objs'>You also see <pushBold/>a goblin<popBold/>, <pushBold/>a ferret<popBold/> and <pushBold/>a tabby cat<popBold/>.</component>
          IN MARK1
          FLUSH
          WAIT 200
        TRACE
        events = flow.run_ours(flow::Case.new('c', File.join(dir, 'c.cmd'), File.join(dir, 'c.trace'), [], %w[--config-dir cfg], nil, dir))
        expect(texts(events, 'echo').map(&:last)).to eq(['mc=[1] ml=[a goblin]'])
      end
    end

    it 'keeps the default config without a settings.cfg (mc counts every bold noun)' do
      Dir.mktmpdir('genie-flow') do |dir|
        File.write(File.join(dir, 'c.cmd'), "waitfor MARK1\necho mc=[$monstercount]\n")
        File.write(File.join(dir, 'c.trace'), <<~TRACE)
          IN <component id='room objs'>You also see <pushBold/>a goblin<popBold/> and <pushBold/>a leopard<popBold/>.</component>
          IN MARK1
          FLUSH
          WAIT 200
        TRACE
        events = flow.run_ours(flow::Case.new('c', File.join(dir, 'c.cmd'), File.join(dir, 'c.trace'), [], [], nil, dir))
        expect(texts(events, 'echo').map(&:last)).to eq(['mc=[2]'])
      end
    end
  end

  # The harness trigger sink is the production Triggers#dispatch; `#trigger load` reads
  # genieflow's Config.ConfigDir (<scriptdir>/Config), `#trigger save` is not modelled.
  describe 'OurRun trigger hooks' do
    it '#trigger load reads <scriptdir>/Config/triggers.cfg, drops an invalid regex row, and save writes nothing' do
      Dir.mktmpdir('genie-flow') do |dir|
        Dir.mkdir(File.join(dir, 'Config'))
        cfg = File.join(dir, 'Config', 'triggers.cfg')
        File.write(cfg, "#trigger {[bad} {#echo bad}\r\n#trigger {^ping} {#echo pong}\r\n")
        File.write(File.join(dir, 'h.cmd'), "put #trigger load\nput #trigger save\npause 1\n")
        File.write(File.join(dir, 'h.trace'), "WAIT 200\nIN ping\nWAIT 100\nIN [bad\n")
        events = GenieSpecSupport::Flow::OurRun.new(dir).run('h', [], GenieSpecSupport::Flow.parse_trace(File.join(dir, 'h.trace'))).events
        expect(texts(events, 'echo').map(&:last)).to eq(['Triggers Loaded', 'Triggers Saved', 'pong'])
        expect(File.binread(cfg)).to eq("#trigger {[bad} {#echo bad}\r\n#trigger {^ping} {#echo pong}\r\n")
      end
    end
  end

  describe '.load_golden' do
    it 'replaces the recorded scriptdir with <scriptdir> in every string value' do
      events = flow.load_golden(File.join(fixture_dir, 'expected-remix', 't43_reserved_dirvars.jsonl'))
      echoes = events.select { |e| e['ev'] == 'echo' }.map { |e| e['text'] }
      expect(echoes).to include('sd=<scriptdir>\\', 'md=<scriptdir>\\Maps')
      expect(events.to_json).not_to include('genie-port-lab')
    end
  end

  describe '.align' do
    it 'finds the longest common subsequence with duplicates' do
      a = [[0, 'x'], [1, 'y'], [2, 'x']]
      b = [[5, 'x'], [6, 'x']]
      pairs, only_a, only_b = flow.align(a, b)
      expect(pairs.map { |pa, pb| [pa[0], pb[0]] }).to eq([[0, 5], [2, 6]])
      expect(only_a).to eq([[1, 'y']])
      expect(only_b).to eq([])
    end

    it 'handles empty sides' do
      expect(flow.align([], [])).to eq([[], [], []])
      expect(flow.align([[0, 'a']], [])).to eq([[], [[0, 'a']], []])
      expect(flow.align([], [[0, 'b']])).to eq([[], [], [[0, 'b']]])
    end
  end

  describe '.compare' do
    def send_at(time, text = 'look') = { 't' => time, 'ev' => 'send', 'text' => text }

    it 'tolerates exactly TIMING_TOLERANCE_MS (60 ms = six ticks) on send/echo and flags one ms more' do
      expect(flow::TIMING_TOLERANCE_MS).to eq(60)
      tol = flow::TIMING_TOLERANCE_MS
      expect(flow.divergent?(flow.compare([send_at(1000)], [send_at(1000 + tol)]))).to be(false)
      expect(flow.divergent?(flow.compare([send_at(1000)], [send_at(1000 - tol)]))).to be(false)
      report = flow.compare([send_at(1000)], [send_at(1001 + tol)])
      expect(report['send'][:timing].length).to eq(1)
    end

    it 'never compares timing for global variables' do
      g = [{ 't' => 0, 'ev' => 'var', 'name' => '$x', 'value' => '1', 'src' => 'cmd' }]
      o = [{ 't' => 9000, 'ev' => 'var', 'name' => '$x', 'value' => '1', 'src' => 'cmd' }]
      expect(flow.divergent?(flow.compare(g, o))).to be(false)
    end

    it 'ignores trace/game variable sets and non-error prints, keeps error prints and crashes' do
      genie = [
        { 't' => 0, 'ev' => 'var', 'name' => '$a', 'value' => '1', 'src' => 'trace' },
        { 't' => 0, 'ev' => 'var', 'name' => '$b', 'value' => '1', 'src' => 'game' },
        { 't' => 0, 'ev' => 'print', 'text' => '[Script loaded: x.cmd]' },
        { 't' => 0, 'ev' => 'print', 'text' => '[Script error: possible infinite loop]' },
        { 't' => 0, 'ev' => 'genie-crash', 'where' => 'ParseTriggers' }
      ]
      s = flow.streams(genie, :genie)
      expect(s['globalvar']).to eq([])
      expect(s['error'].map(&:last)).to eq(['[Script error: possible infinite loop]', 'genie-crash: ParseTriggers'])
    end

    it 'classifies our [...] engine messages as errors only on our side' do
      ev = [{ 't' => 0, 'ev' => 'echo', 'text' => '[Script error: maximum nested dispatch depth (20) exceeded on: #parse x]' }]
      expect(flow.streams(ev, :ours)['error'].length).to eq(1)
      expect(flow.streams(ev, :genie)['echo'].length).to eq(1)
    end

    # The echo key carries the window.
    it 'compares an echo by window and text: main vs a named window, and window names, differ' do
      main = { 't' => 0, 'ev' => 'cmdecho', 'text' => 'x', 'window' => '' }
      log = { 't' => 0, 'ev' => 'cmdecho', 'text' => 'x', 'window' => 'Log' }
      script_echo = { 't' => 0, 'ev' => 'echo', 'text' => 'x', 'script' => 's' }
      ours_log = { 't' => 0, 'ev' => 'hook', 'op' => 'echo', 'payload' => { 'window' => 'Log', 'text' => 'x' } }
      ours_main = { 't' => 0, 'ev' => 'echo', 'text' => 'x', 'script' => '#input' }
      expect(flow.divergent?(flow.compare([log], [ours_log]))).to be(false)
      expect(flow.divergent?(flow.compare([main], [ours_main]))).to be(false)
      expect(flow.divergent?(flow.compare([script_echo], [ours_main]))).to be(false)
      expect(flow.divergent?(flow.compare([log], [ours_main]))).to be(true)
      expect(flow.divergent?(flow.compare([main], [ours_log]))).to be(true)
      expect(flow.divergent?(flow.compare([log], [ours_log.merge('payload' => { 'window' => 'log', 'text' => 'x' })]))).to be(true)
      expect(flow.streams([log], :genie)['echo']).to eq([[0, '[>Log] x']])
    end

    it 'reports a missing send as divergent' do
      expect(flow.divergent?(flow.compare([send_at(0)], []))).to be(true)
      expect(flow.divergent?(flow.compare([], []))).to be(false)
    end
  end

  describe '.format_report' do
    it 'collapses identical consecutive lines with a repeat count' do
      report = flow.compare(Array.new(3) { { 't' => 0, 'ev' => 'send', 'text' => 'ping' } }, [])
      text = flow.format_report('t', report)
      expect(text).to include('"ping"  (x3)')
      expect(text.scan('ping').length).to eq(1)
    end
  end

  describe flow::FiberInput do
    it 'returns a buffered line without parking' do
      input = described_class.new
      input.buffer.push('a')
      expect(input.next_line(timeout: 5)).to eq('a')
    end

    it 'expires a sub-millisecond float residue inside the tick and nudges the clock just past it' do
      input = described_class.new
      expect(input.next_line(timeout: 2e-4)).to be_nil
      expect(input.skew).to eq(2e-4 + flow::CLOCK_NUDGE_S)
    end

    # A timed resume takes at least one 10 ms tick -- one nudge per tick at
    # most, so a sub-tick wait re-entered in the same resume parks instead of spinning in the tick.
    it 'nudges at most once per tick: a second near-expiry timeout before the next tick parks' do
      input = described_class.new
      expect(input.next_line(timeout: 1e-15)).to be_nil
      fiber = Fiber.new { input.next_line(timeout: 1e-4) }
      expect(fiber.resume).to eq(:park)
      expect(input.skew).to eq(1e-15 + flow::CLOCK_NUDGE_S)
      input.skew = 0.0 # the next tick (OurRun#tick)
      expect(input.next_line(timeout: 1e-4)).to be_nil
    end

    it 'parks for a timeout at the near-expiry threshold, a nil timeout, or a real wait' do
      [flow::NEAR_EXPIRY_S, 0.5, nil].each do |timeout|
        input = described_class.new
        fiber = Fiber.new { input.next_line(timeout: timeout) }
        expect(fiber.resume).to eq(:park)
        expect(input.skew).to eq(0.0)
      end
    end

    # The interpreter polls with a spent timeout (the chunk idle check): Lich's
    # LimitedArray#wait_shift(0) returns at once, with a buffered line or nil.
    it 'only looks for a zero or negative timeout: a buffered line, else nil, never a park' do
      [0, 0.0, -0.5].each do |timeout|
        input = described_class.new
        fiber = Fiber.new { input.next_line(timeout: timeout) }
        expect(fiber.resume).to be_nil
        expect(input.skew).to eq(0.0)
        input.buffer.push('x')
        expect(input.next_line(timeout: timeout)).to eq('x')
      end
    end
  end

  describe flow::OurRun do
    # The glue's `--- Lich: genie trigger error:` diagnostic (a decided divergence: Remix is
    # silent) is a Lich-echoed line, so it clears GameState#last_row_was_prompt like any respond line.
    # A trigger action that fails with a non-Genie exception (an engine bug: a Lich::Genie::Error
    # such as an evaluator fault ends that ParseCommand quietly, ParseCommand#run). No script
    # text reaches one, so MathEval.evaluate is made to raise for the `#evalmath` body.
    def break_evalmath
      allow(Lich::Genie::MathEval).to receive(:evaluate).and_raise(RuntimeError, 'boom')
    end

    it 'counts the glue\'s trigger-error line as main-window text: the next prompt is shown' do
      break_evalmath
      src = "action var seen %seen|$0 when ^R?>\nvar seen s\nput #trigger {^X} {#evalmath 1}\n" \
            "waitfor START\npause 0.2\nput #parse X\npause 0.5\necho seen=%seen\n"
      events = run_script(src, ['IN START', 'PROMPT', 'PROMPT', 'WAIT 500', 'PROMPT', 'PROMPT', 'WAIT 500'])
      expect(events.map { |e| e['ev'] }).to include('trigger-error')
      expect(texts(events, 'echo').map(&:last)).to eq(['seen=s|>|>'])
    end

    it 'treats WAIT as milliseconds (a regression would push later lines minutes out)' do
      events = run_script("waitfor go\necho got", ['WAIT 1000', 'IN go now'])
      expect(texts(events, 'echo')).to eq([[1020, 'got']]) # the IN at 1010, its chunk ends with the 1020 tick
      expect(events.last['t']).to be < 2000
    end

    it 'resumes 15 x pause 0.5 exactly every 500 ms (float tick drift was a harness artifact)' do
      src = "counter set 0\nloop:\npause 0.5\ncounter add 1\necho n=%c\nif %c < 15 then goto loop\n"
      events = run_script(src, ['WAIT 8000'])
      times = texts(events, 'echo').map(&:first)
      expect(times).to eq((1..15).map { |i| i * 500 })
    end

    # 0.1 s is not exactly representable: without the near-expiry rule every resume would
    # land one tick late (110, 220, ...). Pins the rule end-to-end (t38 uses pause 0.1).
    it 'resumes 20 x pause 0.1 exactly every 100 ms (near-expiry rule)' do
      src = "counter set 0\nloop:\npause 0.1\ncounter add 1\necho n=%c\nif %c < 20 then goto loop\n"
      events = run_script(src, ['WAIT 2500'])
      expect(texts(events, 'echo').map(&:first)).to eq((1..20).map { |i| i * 100 })
    end

    it 'routes a typed #trigger WITHOUT $-expansion and expands only when it fires' do
      events = run_script('pause 1', ['VAR lastcommand foo', 'INPUT #trigger {^ring$} {#echo got $lastcommand}', 'INPUT #trigger',
                                      'IN ring'])
      expect(texts(events, 'echo').map(&:last)).to include('^ring$=#echo got $lastcommand', 'got foo')
    end

    # Remix Command.ParseCommand(sText, bSendToGame: true, bUserInput: true) (FormMain.cs:4216 R;
    # genieflow Host.UserInput): ;/bug/sing rows go whole through Globals.ParseGlobalVars
    # (Command.cs:223-232 R); plain rows are ParseGlobalVars'd (Command.cs:2545 R); #arms
    # expand per arm (#echo Command.cs:319-324 R, #var 929-930 R, #send via Send 2604 R) except
    # the raw-storing arms (#trigger 1416-1418 R, #alias 1166 R, ...).
    # The #parse host port mirrors GenieScript.parse_broadcast: other live, unpaused
    # scripts get the text queued; the issuer handles its own copy inline.
    describe '#parse broadcast' do
      it 'queues the text on another waiting script and never on a paused one or the issuer' do
        extra = { '_w.cmd' => "waitfor PING\necho w-got\n", '_p.cmd' => "waitfor PING\necho p-got\n" }
        # the first pause lists _w and _p (a `#script pause` in the launching run misses them)
        src = "put ._w\nput ._p\npause 0.05\nput #script pause _p\npause 0.1\nput #parse PING\nmatch bad PING\nmatchwait 0.5\n" \
              "put #script resume _p\npause 0.3\necho issuer-done\nexit\nbad:\necho buffered\n"
        events = run_script(src, [], extra: extra)
        expect(texts(events, 'echo')).to eq([[150, 'w-got'], [950, 'issuer-done']]) # no p-got, no buffered
      end

      # The glue prints `--- Lich: genie trigger error:` where Remix is silent (a decided divergence):
      # the harness records it as a `trigger-error` event that no compared stream holds, and the
      # next trigger still fires (per-action catch, FormMain.cs:4644-4654 R).
      it 'records a failing trigger action as an uncompared trigger-error and fires the next trigger' do
        break_evalmath
        src = "put #trigger {^X} {#echo T1;#evalmath 1;#echo T1-end}\n" \
              "put #trigger {^X$} {#echo T2}\npause 0.5\n"
        events = run_script(src, ['WAIT 100', 'IN X'])
        expect(texts(events, 'echo').map(&:last)).to eq(%w[T1 T2])
        expect(events.count { |e| e['ev'] == 'trigger-error' }).to eq(1)
        expect(flow.streams(events, :ours)['error']).to be_empty
      end

      # An evaluator fault (Eval::Fault, a Lich::Genie::Error) ends the action's ParseCommand
      # quietly like Remix's per-action catch (FormMain.cs:4644-4654 R): no diagnostic at all.
      it 'ends a trigger action at an evaluator fault silently and fires the next trigger' do
        src = "put #trigger {^X} {#echo T1;#if {matchre(\"a\",\"(\")} {#echo no};#echo T1-end}\n" \
              "put #trigger {^X$} {#echo T2}\npause 0.5\n"
        events = run_script(src, ['WAIT 100', 'IN X'])
        expect(texts(events, 'echo').map(&:last)).to eq(%w[T1 T2])
        expect(events.count { |e| e['ev'] == 'trigger-error' }).to eq(0)
      end

      it 'reaches the global #triggers from a typed #parse (INPUT)' do
        events = run_script('pause 1', ['INPUT #trigger {^ring (\\w+)$} {#echo rang $1}', 'INPUT #parse ring bell'])
        expect(texts(events, 'echo').map(&:last)).to eq(['rang bell'])
      end
    end

    describe 'INPUT (user typing) expansion and splitting' do
      def sends(events) = texts(events, 'send').map(&:last)

      it 'expands $globals in plain text, #echo, #var and #send (p01_input_expand)' do
        events = run_script('pause 1', ['VAR foo bar', 'INPUT say $foo', 'INPUT #echo e=$foo',
                                        'INPUT #var copy $foo', 'INPUT #send s=$foo'])
        expect(sends(events)).to eq(['say bar', 's=bar'])
        expect(texts(events, 'echo').map(&:last)).to eq(['e=bar'])
        copy = events.find { |e| e['ev'] == 'var' && e['name'] == '$copy' }
        expect(copy['value']).to eq('bar')
      end

      it 'sends ;, bug and sing rows whole (case-insensitive) with $-expansion, never split (p06)' do
        events = run_script('pause 1', ['VAR foo bar', 'INPUT ;hello there;look', 'INPUT sing la;la',
                                        'INPUT BUG x;$foo', 'INPUT ;$foo'])
        expect(sends(events)).to eq([';hello there;look', 'sing la;la', 'BUG x;bar', ';bar'])
      end

      it 'still splits other rows on ; and expands each piece' do
        events = run_script('pause 1', ['VAR foo bar', 'INPUT say $foo;look;singer x'])
        expect(sends(events)).to eq(['say bar', 'look', 'singer x'])
      end

      # A backslash that survives to the send (e.g. `\\%x`) is NOT probed here: Remix
      # SendTextToGame strips it (Command.cs:2826-2839 R) and our engine does not.
      it 'keeps \\$ escaped, leaves % and unknown $names (incl. $1) literal: globals only, no args pass' do
        events = run_script('pause 1', ['VAR foo bar', 'INPUT say \\$foo 50% %foo $1 $nosuch'])
        expect(sends(events)).to eq(['say $foo 50% %foo $1 $nosuch'])
      end

      it 'turns a leading - into #send (quick send, Command.cs:247-253 R) with expansion' do
        events = run_script('pause 1', ['VAR foo bar', 'INPUT -say $foo'])
        expect(sends(events)).to eq(['say bar'])
      end

      # Remix tests the RAW row for quick-send (Command.cs:249 R), the script char
      # (Command.cs:2536 R) and the plain send (Command.cs:2545 R); only the # test trims
      # (Command.cs:256 R). Probe s01_input_space (genieflow, real Remix).
      it 'never trims a typed row: a leading space defeats quick-send and script launch (s01)' do
        events = run_script('pause 1', ['INPUT  look', 'INPUT  -north', 'INPUT  .other', 'INPUT east;  west'],
                            extra: { 'other.cmd' => 'echo other ran' })
        expect(sends(events)).to eq([' look', ' -north', ' .other', 'east', '  west'])
        expect(texts(events, 'echo').map(&:last)).not_to include('other ran')
      end

      it 'keeps a later ;-piece untrimmed, so "say a; -look" sends " -look" as text' do
        expect(sends(run_script('pause 1', ['INPUT say a; -look']))).to eq(['say a', ' -look'])
      end

      it 'folds an empty ;-segment into the next piece like Remix SafeSplit (look;;south -> ";south")' do
        expect(sends(run_script('pause 1', ['INPUT look;;south', 'INPUT a;']))).to eq(['look', ';south', 'a'])
      end

      it 'still routes a #command row with leading spaces (the # test trims, Command.cs:256 R)' do
        events = run_script('pause 1', ['VAR foo bar', 'INPUT   #echo e=$foo'])
        expect(texts(events, 'echo').map(&:last)).to eq(['e=bar'])
        expect(sends(events)).to eq([])
      end

      it 'routes raw-storing arms (#alias) unexpanded' do
        events = run_script('pause 1', ['VAR foo bar', 'INPUT #alias {zz} {say $foo}'])
        hook = events.find { |e| e['ev'] == 'hook' && e['op'] == 'alias' }
        expect(hook['payload'].values).to include('say $foo')
      end
    end

    # Production delivery of a game row: the glue's GameStateFeed tap feeds the
    # raw server string to the production GameState (Remix ParseGameRow, Game.cs:567-889 R), whose
    # printed texts (GameEvents::TextLine) go to the #triggers and then to the listed scripts --
    # never Lich's strip_xml lines. t52-t55 (stream routing, multi-row streams, Remix's entity
    # quirks, row splits) are hard expectations in flow_parity_spec since v0.20.0.
    describe 'IN (game rows) through the production GameState (Remix row routing)' do
      let(:rock_src) do
        "matchre ROCK shiny rock\nmatchre PLAIN plain text\nmatchwait 3\necho timeout\nexit\n" \
          "ROCK:\necho saw-rock\nexit\nPLAIN:\necho saw-plain\n"
      end

      def echoes(events) = texts(events, 'echo').map(&:last)

      # Remix excludes WindowTarget.Inv from TriggerParse (Game.cs:3063-3069 R): one row or many.
      it 'never shows scripts or #triggers an inv stream, single-row (t50) or multi-row' do
        events = run_script(rock_src, ['INPUT #trigger {shiny rock} {#echo trig-rock}',
                                       "IN <pushStream id='inv'/>a shiny rock<popStream/>",
                                       "IN <pushStream id='inv'/>a shiny rock", 'IN <popStream/>plain text', 'PROMPT'])
        expect(echoes(events)).to eq(['saw-plain'])
      end

      it 'drops GUI-only element content instead of gluing it on (<spell>None</spell>You gesture.)' do
        src = "matchre A ^You gesture\nmatchre B NoneYou\nmatchwait 2\necho none\nexit\nA:\necho got-A\nexit\nB:\necho got-B\n"
        events = run_script(src, ['INPUT #trigger {^You gesture} {#echo trig}', 'IN <spell>None</spell>You gesture.', 'PROMPT'])
        expect(echoes(events)).to eq(%w[trig got-A])
      end

      it 'decodes XML entities such as &quot; for scripts (Utility.TranslateHTMLChar)' do
        src = "matchre B said \"hi\"\nmatchwait 2\necho none\nexit\nB:\necho got-B\n"
        events = run_script(src, ['IN He said &quot;hi&quot; to you', 'PROMPT'])
        expect(echoes(events)).to eq(['got-B'])
      end

      it 'drops a row that is a lone CRLF after markup (a bare tag) without delivering an empty line' do
        src = "matchre E ^$\nmatchre P plain\nmatchwait 2\necho none\nexit\nE:\necho empty\nexit\nP:\necho got-P\n"
        events = run_script(src, ["IN <output class=''/>", 'IN plain', 'PROMPT'])
        expect(echoes(events)).to eq(['got-P'])
      end

      it "keeps a line's leading spaces for #triggers and scripts (Utility.Trim trims CR/LF only)" do
        # an action matches the line as given, a matchre its Trim() (Script.cs:1252, 1286 R)
        src = "action echo act-L when ^   Last login\nmatchre L ^Last login\nmatchwait 2\necho none\nexit\nL:\necho got-L\n"
        events = run_script(src, ['INPUT #trigger {^   Last login} {#echo trig-L}', 'IN    Last login: Monday', 'PROMPT'])
        expect(echoes(events)).to eq(%w[trig-L act-L got-L])
      end

      it 'never touches the process-global $strip_xml_multiline (no Lich strip on this path)' do
        before = $strip_xml_multiline
        snapshot = before.dup
        run_script('pause 1', ["IN <pushStream id='inv'/>left open"])
        expect($strip_xml_multiline).to equal(before)
        expect($strip_xml_multiline).to eq(snapshot)
      end
    end

    # The harness feeds the production GameState the rows genieflow feeds
    # Game.ParseGameRow (IN rows, and the <roundTime>/<prompt> and <streamWindow>/<component
    # id='room desc'> rows PROMPT and ROOM expand to, flow-oracle/src/Program.cs:272-288),
    # before the script sees the row, and records each send as Game.SendText does.
    describe 'game state model' do
      def echo_texts(events) = events.select { |e| e['ev'] == 'echo' }.map { |e| e['text'] }

      it 'gives PROMPT rt the genieflow game time base and the $roundtime snapshot' do
        events = run_script("waitfor go\necho [$gametime] [$roundtime] [$prompt]\n", ['WAIT 2000', 'PROMPT 3', 'WAIT 3500', 'IN go'])
        expect(echo_texts(events)).to eq(['[1700000002] [3] [R> ]'])
      end

      it 'turns ROOM into $roomdesc and clears the room components' do
        events = run_script("waitfor go\necho [$roomdesc] [$roomobjs]\n",
                            ["IN <component id='room objs'>You also see a rock.</component>", 'ROOM Town Green', 'IN go'])
        expect(echo_texts(events)).to eq(['[You are in Town Green.] []'])
      end

      it 'updates the game state before the row reaches the script' do
        events = run_script("waitfor rock\necho [$roomobjs]\n", ["IN <component id='room objs'>a rock</component>rock"])
        expect(echo_texts(events)).to eq(['[a rock]'])
      end

      it 'records sends as $lastcommand and typed input as $lastinput too' do
        events = run_script("put look\nwaitfor go\necho [$lastcommand] [$lastinput]\n", ['INPUT smile', 'IN go'])
        expect(echo_texts(events)).to eq(['[smile] [smile]'])
      end

      it 'reads the @-specials off genieflow\'s virtual wall clock' do
        events = run_script("pause 1\necho [@unixtime@] [$unixtime]\n")
        expect(echo_texts(events)).to eq(["[#{flow::WALL_EPOCH.to_i + 1}] [#{flow::WALL_EPOCH.to_i + 1}]"])
      end
    end

    # genieflow Runner.RunTrace chunk model (flow-oracle/src/Program.cs:245-344): IN/PROMPT/ROOM
    # open a chunk; PROMPT/FLUSH close it with one tick; every other directive first closes an
    # open chunk (one tick only if open); VAR then adds no tick and TICK n exactly n. The
    # waitfor resumes after the packet (its PROMPT, or CHUNK_IDLE_SECONDS with no further
    # row = the closing tick), so these resume times are genieflow's (they were 10 ms early).
    describe 'directive clock (genieflow chunk model)' do
      let(:src) { "put look\nwaitfor Ouch\necho got" }

      def got_at(events) = texts(events, 'echo').find { |_, t| t == 'got' }&.first

      it 'adds no tick for VAR lines (p04_var_then_in: Genie 20 ms, ours 20 ms)' do
        events = run_script(src, ['EXPECT look'] + Array.new(8) { |i| "VAR foo #{i}" } + ['IN Ouch', 'PROMPT'])
        expect(got_at(events)).to eq(20)
      end

      it 'adds no tick for ROOM lines, which only extend the open chunk (p08_room_chunk: Genie 20 ms, ours 20 ms)' do
        events = run_script(src, ['EXPECT look'] + %w[A B C D E F G H].map { |r| "ROOM #{r}" } + ['IN Ouch', 'PROMPT'])
        expect(got_at(events)).to eq(20)
      end

      it 'runs TICK 0 as zero ticks after a closed chunk' do
        events = run_script(src, ['EXPECT look'] + Array.new(7) { 'TICK 0' } + ['IN Ouch', 'PROMPT'])
        expect(got_at(events)).to eq(20)
      end

      it 'closes an open chunk with one tick before TICK n, then runs exactly n' do
        events = run_script("waitfor a\necho a\nwaitfor b\necho got", ['IN a', 'TICK 2', 'IN b'])
        expect(got_at(events)).to eq(50)
      end

      it 'closes an open chunk with one tick before WAIT, VAR and EXPECT' do
        events = run_script("waitfor a\nwaitfor b\necho got", ['IN a', 'VAR x 1', 'IN b'])
        expect(got_at(events)).to eq(30)
        events = run_script("waitfor a\nwaitfor b\necho got", ['IN a', 'WAIT 20', 'IN b'])
        expect(got_at(events)).to eq(50)
      end

      it 'ticks once on FLUSH even with no open chunk' do
        events = run_script(src, ['EXPECT look', 'FLUSH', 'FLUSH', 'IN Ouch'])
        expect(got_at(events)).to eq(40)
      end
    end

    it 'launches .name from INPUT and sends plain typed text to the game' do
      events = run_script('pause 1', ['INPUT .other a b', 'INPUT say hi'], extra: { 'other.cmd' => 'echo other %1 %2' })
      expect(texts(events, 'echo').map(&:last)).to include('other a b')
      expect(events.find { |e| e['ev'] == 'send' && e['text'] == 'say hi' }['origin']).to eq('')
    end

    it 'launches a RUN directive without arguments' do
      events = run_script('pause 1', ['RUN other'], extra: { 'other.cmd' => 'echo other ran' })
      expect(texts(events, 'echo').map(&:last)).to include('other ran')
    end

    it 'reports a missing script as a failed load, not an exception' do
      events = run_script('pause 1', ['INPUT .nosuch'])
      finish = events.find { |e| e['ev'] == 'script-finish' && e['script'] == 'nosuch' }
      expect(finish['loadfailed']).to be(true)
    end

    it 'makes a chunk roundtime visible from its first line (most-favourable model)' do
      events = run_script("waitfor go\nput swing", ['IN go', 'PROMPT 2', 'WAIT 3000'])
      expect(texts(events, 'send')).to eq([[2010, 'swing']])
    end

    it 'emits expect-timeout at the EXPECT limit (milliseconds)' do
      events = run_script('pause 5', ['EXPECT /never/ 100'])
      timeout = events.find { |e| e['ev'] == 'expect-timeout' }
      expect(timeout['t']).to be_between(100, 120)
    end

    # Hang guard: inside one resume the virtual clock is frozen, so the engine's own
    # SCRIPT_TIMEOUT (virtual) never trips and a row loop with no wait would spin forever.
    describe 'resume budget' do
      def exception_of(events) = events.find { |e| e['ev'] == 'engine-exception' }

      # Timeout: if the guard itself regresses, fail fast instead of hanging parallel_rspec.
      def run_guarded(...) = Timeout.timeout(60) { run_script(...) }

      it 'stops a tight goto loop with ResumeBudgetExceeded instead of hanging' do
        events = run_guarded("loop:\ngoto loop\n")
        expect(exception_of(events)['message']).to match(/ResumeBudgetExceeded: h: 200000 clock reads in one resume at 0 ms/)
        expect(events.last).to include('ev' => 'end', 'live' => 0)
      end

      # A smaller budget: 200k #var rows in one resume can outlast the example timeout on a
      # loaded host (seen as a flake); the budget's size is not what this example is about.
      it 'stops a later resume that loops on #var hooks, at that resume\'s virtual time' do
        stub_const('GenieSpecSupport::Flow::RESUME_CLOCK_BUDGET', 5_000)
        events = run_guarded("pause 0.1\nloop:\nput #var x 1\ngoto loop\n")
        expect(exception_of(events)['message']).to include('ResumeBudgetExceeded')
        expect(exception_of(events)['t']).to eq(100)
      end

      it 'is outside StandardError, so no engine `rescue StandardError` can swallow it' do
        expect(flow::ResumeBudgetExceeded.ancestors).not_to include(StandardError)
        expect(flow::FIBER_ERRORS).to include(flow::ResumeBudgetExceeded, SystemStackError)
      end

      # 300 paced iterations read the clock ~6400 times in total but at most ~25 times in one
      # resume, so a 1000-read budget only holds if the counter really resets every resume.
      it 'resets per resume, so a long paced loop never trips it' do
        stub_const('GenieSpecSupport::Flow::RESUME_CLOCK_BUDGET', 1_000)
        events = run_script("counter set 0\nloop:\ncounter add 1\npause 0.01\nif %c < 300 then goto loop\necho done\n", ['IDLE 10000'])
        expect(exception_of(events)).to be_nil
        expect(texts(events, 'echo').map(&:last)).to eq(['done'])
      end

      it 'lets non-engine exceptions such as Interrupt propagate out of the run' do
        Dir.mktmpdir('genie-flow') do |dir|
          File.write(File.join(dir, 'i.cmd'), "echo boom\n")
          run = flow::OurRun.new(dir)
          allow(run).to receive(:emit).and_wrap_original do |orig, ev, **kv|
            raise Interrupt if ev == 'echo'

            orig.call(ev, **kv)
          end
          expect { run.run('i', [], []) }.to raise_error(Interrupt)
        end
      end
    end

    it 'rejects an unknown trace directive' do
      expect { run_script('pause 1', ['BOGUS x']) }.to raise_error(ArgumentError, /unknown directive BOGUS/)
    end
  end

  # Engine side of the differential's old pause drift: on an exact fake clock the interpreter adds no per-iteration
  # latency to pause, so any drift in the differential comes from the harness clock.
  describe 'interpreter pause cadence on an exact clock' do
    it 'finishes 15 x pause 0.5 at 7.5 s' do
      clock = [0r]
      input = Object.new
      input.define_singleton_method(:next_line) do |timeout: nil|
        clock[0] += timeout.to_r if timeout
        nil
      end
      echoes = []
      src = "counter set 0\nloop:\npause 0.5\ncounter add 1\nif %c < 15 then goto loop\necho done\n"
      Lich::Genie::Engine.build(src, input: input, clock: -> { clock[0] }, echo: ->(t) { echoes << [clock[0], t] },
                                     game: Object.new.tap { |g| g.define_singleton_method(:send_command) { |_| nil } }).run
      expect(echoes).to eq([[7.5r, 'done']])
    end
  end
end
