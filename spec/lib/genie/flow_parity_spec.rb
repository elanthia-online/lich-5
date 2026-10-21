# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/flow_harness'
require_relative 'support/js_library'

# Flow parity against Genie4 Remix v4.2.4, no dotnet needed.
#
# Each spec/fixtures/genie/flow/<name>.cmd (+ .trace/.args/.flags/.only, `_` files are
# helpers/includes) runs through OUR real engine headless (support/flow_harness.rb) and
# its send/echo/error/globalvar/expect-timeout/inputbox streams are compared with the
# frozen genieflow output in expected-remix/<name>.jsonl (Remix's real Script.cs,
# Command.cs, Game.cs, Globals.cs on a virtual clock).
#
# Provenance: copied verbatim from the genie-port lab's flow-oracle/tests and
# tests/expected-remix (recorded by `GENIE=remix ./run_tests.sh --record`). To change a
# test: edit it in the lab, re-record, run `GENIE=remix ./run_tests.sh` (0 DIFF), then
# copy the .cmd/.trace/.args/.flags/.only/_helper files and the .jsonl here, replacing
# the recording machine's paths in the .jsonl (the lab dir by `<lab>`, the Remix source
# dir by `<Genie4_Remix>`; the harness reads the scriptdir from the setup line). No flow
# case holds a tester's private script.
#
# Timing: aligned send/echo pairs may differ by up to Flow::TIMING_TOLERANCE_MS (60 ms);
# other streams compare text only. The waits resume at the end of the DR packet
# (Script.cs:1551, 1600, 2098-2104 R), so the old -10 ms deltas (t07/t48/t50) are gone;
# a resume caused by `#script resume` lands one tick late (t153: Remix resumes synchronously
# inside the command). The CommandQueue drains before the scripts on both sides
# (FormMain.cs:8324-8339 R).
#
# What a MATCH does NOT prove (see the harness header for every modelling assumption):
#   * game rows go through the production GameState's port of Remix's row parser and window
#     routing, delivered inline here; the glue delivers them on its
#     trigger worker, so a worker lagging behind the parser is not modelled (like Remix's own
#     trigger-Channel race, which is not emulated);
#   * a launched script's first run is synchronous here; the glue's launching script (or the
#     script whose thread runs the launching #trigger body, or the trigger / queue worker) waits
#     for it on another thread (bounded); the script list's tick end is a script's run end
#     (not a first run nested in its launcher's run; ScriptList), not a timer tick, so
#     cross-thread timing inside one Remix tick is not modelled (Remix's timing races are not
#     emulated);
#   * `#goto` is not exercised (genieflow has no AutoMapper plugin; GotoWalk has its own spec).
#
# RATCHET: a test listed in DIVERGENT is marked pending with the reason it differs
# (docs/genie-engine/open-items.md K1). Pending examples still run;
# when a change fixes the behaviour the example passes, RSpec reports "Expected
# pending ... to fail" and the suite goes red until the entry is removed here. Every
# other test is a hard expectation. ACCEPTED entries are decided divergences from Remix:
# they stay pending until the change that implements the decision replaces the Remix comparison with an assertion of the decided behaviour.
RSpec.describe 'Genie flow parity vs Remix v4.2.4 (frozen genieflow goldens)' do
  flow = GenieSpecSupport::Flow
  fixture_dir = File.expand_path('../../fixtures/genie/flow', __dir__)
  golden_dir = File.join(fixture_dir, 'expected-remix')
  cases = flow.discover(fixture_dir, tree: 'remix')
  lab_cases = %w[t227_js_arrays_jint t228_js_arrays_miner t233_js_skilldata t234_js_action t236_js_engine_reset
                 t238_js_uber_text_to_number t239_js_arrays_b249849 t240_js_arrays_0ad2095 t241_js_arrays_1bfe9a2
                 t242_js_arrays_9a9462a t243_js_arrays_a7f2496 t244_js_arrays_c878a96 t245_js_arrays_5e08eba].freeze

  divergent = {
    't39_trigger_input_loop'           => 'ACCEPTED (decided divergence: the nested-dispatch cap): with trigger-on-input Remix recurses until the client dies (FormMain.cs:4408, 4425 R); ' \
                                          'ours is asserted under "decided behaviour" below',
    't43_reserved_dirvars'             => 'ACCEPTED (decided divergence): $scriptdir/$logdir/$mapdir resolve to OUR engine dirs, not Remix Config paths (Globals.cs:237-242, 858-864 R)',
    't49_waitfor_lastrow_chunk'        => 'ACCEPTED (decided divergence: Remix timing races are not emulated): Remix trigger-Channel race, chunk-delivery extreme (FormMain.cs:6596, 141-152 R; Script.cs:2098-2104 R)',
    't51_evaltrigger_lastcommand_loop' => 'ACCEPTED (decided divergence: the nested-dispatch cap): Remix recursion through an eval trigger on $lastcommand kills the client ' \
                                          '(Game.cs:549-551, FormMain.cs:4725 R); ours is asserted under "decided behaviour" below'
  }.freeze

  it 'has a golden for every fixture and every golden has a fixture (or is a lab-only case)' do
    goldens = Dir.glob(File.join(golden_dir, '*.jsonl')).map { |p| File.basename(p, '.jsonl') }.sort
    expect((cases.map(&:name) + lab_cases).sort).to eq(goldens)
  end

  it 'keeps the lab-only cases out of the fixture dir (no third-party JavaScript in the repo)' do
    expect(cases.map(&:name) & lab_cases).to eq([])
    expect(Dir.glob(File.join(fixture_dir, '**', '*.js')).map { |p| File.basename(p) }).to eq(['_t235_tiny.js'])
  end

  it 'lists only existing tests in the divergence ratchet' do
    expect(divergent.keys - cases.map(&:name)).to eq([])
  end

  # Raised from 300 KB in v0.17.0: 13 new ParseCommand/CommandQueue cases took it to ~315 KB.
  # Raised to 450 KB in v0.20.0: the routing / trigger-on-input cases t171-t175 took it past 400 KB.
  # Raised to 500 KB in v0.22.0: the error / load-model cases t185-t210 took it past 450 KB.
  # Raised to 560 KB in v0.23.0: the #command-layer cases t212-t225 (the reserved-variable
  # listing of t216 alone is 25 KB) took it past 500 KB.
  # Raised to 650 KB in v0.24.1: the js cases t227-t247 (about 109 KB of goldens, the lab-only
  # cases below included; the largest is t247's 11 KB) took it past 600 KB.
  it 'keeps the frozen fixtures small (< 650 KB)' do
    bytes = Dir.glob(File.join(fixture_dir, '**', '*')).select { |p| File.file?(p) }.sum { |p| File.size(p) }
    expect(bytes).to be < 650_000
  end

  cases.each do |flow_case|
    it "#{flow_case.label}: our engine matches Remix" do
      pending(divergent[flow_case.name]) if divergent.key?(flow_case.name)
      golden = flow.load_golden(File.join(golden_dir, "#{flow_case.name}.jsonl"))
      report = flow.compare(golden, flow.run_ours(flow_case))
      expect(flow.divergent?(report)).to be(false), flow.format_report(flow_case.label, report)
    end
  end

  # Lab-only cases: their scripts include or contain
  # third-party JavaScript that stays out of this BSD-3-Clause repo -- the GPLv3 js_arrays.js
  # versions (DR-Genie-Scripts), SkillData.cmd's block (GPLv3) and ubercombat's TEXT_TO_NUMBER block
  # (all rights reserved). Only their Remix goldens are frozen here; the scripts run from the lab's
  # flow-oracle tests dir (GenieSpecSupport::JsLibrary::LAB_DIR) and skip when it is absent.
  describe 'lab-only cases (third-party JavaScript)' do
    lab_dir = GenieSpecSupport::JsLibrary::LAB_DIR
    lab_cases.each do |name|
      it "#{name}: our engine matches Remix (script from the lab)" do
        lab_case = File.directory?(lab_dir) && flow.discover(lab_dir, tree: 'remix').find { |c| c.name == name }
        skip(GenieSpecSupport::JsLibrary.lab_missing("#{name}.cmd")) unless lab_case

        golden = flow.load_golden(File.join(golden_dir, "#{name}.jsonl"))
        report = flow.compare(golden, flow.run_ours(lab_case))
        expect(flow.divergent?(report)).to be(false), flow.format_report(lab_case.label, report)
      end
    end
  end

  # Decided divergences with no Remix golden: Remix itself dies there, so the fixture
  # (spec/fixtures/genie/flow-decided) asserts OUR decided behaviour through the same harness.
  describe 'decided behaviour where Remix crashes' do
    decided_dir = File.expand_path('../../fixtures/genie/flow-decided', __dir__)

    # A decided divergence: Remix's Script Action catch
    # (Script.cs:1310 R) -> GenieError.Error -> Game.HandleGenieException -> GenieError.Error
    # (Game.cs:149-160, 3291-3294 R) recurses until the stack overflows, so `foo`/`bar`
    # never reach the game. Ours: one error line, the script stops, nothing else is sent.
    it 'g46_action_shift_fault: an in-action shift fault stops the script with one error line' do
      events = GenieSpecSupport::Flow::OurRun.new(decided_dir)
                                             .run('g46_action_shift_fault', %w[a b c],
                                                  flow.parse_trace(File.join(decided_dir, 'g46_action_shift_fault.trace')))
                                             .events
      visible = events.reject { |e| %w[setup var input].include?(e['ev']) }.map { |e| [e['ev'], e['text']].compact }
      expect(visible).to eq([%w[script-start], ['echo', '[Object reference not set to an instance of an object.]'], %w[script-finish], %w[end]])
    end

    # The nested-dispatch cap (a decided divergence): Remix has no re-entrancy or depth guard
    # in ParseTriggers (FormMain.cs:4425 R) and dies (genieflow `genie-crash`). Ours stops the chain at DispatchDepth::LIMIT nested #parse dispatches.
    d3_message = "[Script error: maximum nested dispatch depth (#{Lich::Genie::DispatchDepth::LIMIT}) exceeded on: #parse LOOP]"

    it 'd3_parse_action_recursion: an action re-#parsing its own trigger stops the script with one error line' do
      events = GenieSpecSupport::Flow::OurRun.new(decided_dir).run('d3_parse_action_recursion', [], []).events
      visible = events.reject { |e| %w[setup var input].include?(e['ev']) }.map { |e| [e['ev'], e['text']].compact }
      expect(visible).to eq([%w[script-start], ['echo', d3_message], %w[script-finish], %w[end]])
    end

    it 'd3_trigger_parse_recursion: a #trigger re-#parsing its own pattern stops the chain with one error line' do
      events = GenieSpecSupport::Flow::OurRun.new(decided_dir)
                                             .run('d3_trigger_parse_recursion', [],
                                                  flow.parse_trace(File.join(decided_dir, 'd3_trigger_parse_recursion.trace')))
                                             .events
      echoes = events.select { |e| e['ev'] == 'echo' }.map { |e| [e['script'], e['text']] }
      expect(echoes).to eq([['#trigger', d3_message.sub('LOOP', 'BOOM')]])
      expect(events.last).to include('ev' => 'end', 'live' => 1) # the waiting script is untouched
    end

    # A #parse ping-pong between two scripts (genieflow: genie-crash at ParseTriggers after 200
    # levels). Each hop is queued on the other script's thread with its
    # depth (ParseDispatch::Line) and the count continues there: PING at odd depths from the
    # helper, PONG at even depths from the issuer, so the helper's #parse at depth 21 is the
    # one past the cap -- it stops; the issuer counted its initial PING plus 9 queued ones.
    it 'd3_cross_script_parse: a #parse ping-pong between two scripts is capped on the receiving thread' do
      events = GenieSpecSupport::Flow::OurRun.new(decided_dir)
                                             .run('d3_cross_script_parse', [],
                                                  flow.parse_trace(File.join(decided_dir, 'd3_cross_script_parse.trace')))
                                             .events
      echoes = events.select { |e| e['ev'] == 'echo' }.map { |e| [e['script'], e['text']] }
      expect(echoes).to eq([['_d3_pong', d3_message.sub('LOOP', 'PING')], ['d3_cross_script_parse', 'a-done 10']])
      expect(events.last).to include('ev' => 'end', 'live' => 0)
    end

    # The nested-dispatch cap for variable-change dispatch: Remix's Script.TriggerVariableChanged recursion
    # (Script.cs:1358-1433 R) overflows the stack -- genieflow prints "Stack overflow." and
    # dies. Each re-entry is one dispatch level; level 21 stops the script.
    it 'd3_eval_action_recursion: an eval action re-setting its own variable stops the script with one error line' do
      events = GenieSpecSupport::Flow::OurRun.new(decided_dir).run('d3_eval_action_recursion', [], []).events
      visible = events.reject { |e| %w[setup var input].include?(e['ev']) }.map { |e| [e['ev'], e['text']].compact }
      expect(visible).to eq([%w[script-start], ['echo', d3_message.sub('#parse LOOP', 'variable change %x')], %w[script-finish], %w[end]])
    end

    # Two scripts' eval actions feeding each other through globals: each hop is queued on the
    # other script's thread with its depth (VariableDispatch::Change) and the count continues
    # there -- $a at odd depths in the issuer, $b at even ones in the helper -- so the issuer's
    # change at depth 21 stops it; the helper runs on. Remix: genie-crash.
    it 'd3_cross_script_var: an eval-action ping-pong over globals is capped on the receiving thread' do
      events = GenieSpecSupport::Flow::OurRun.new(decided_dir).run('d3_cross_script_var', [], []).events
      echoes = events.select { |e| e['ev'] == 'echo' }.map { |e| [e['script'], e['text']] }
      expect(echoes).to eq([['d3_cross_script_var', d3_message.sub('#parse LOOP', 'variable change $a')], ['_d3_var_pong', 'b-done']])
      sets = events.select { |e| e['ev'] == 'var' }.map { |e| e['name'] }
      expect(sets.length).to eq(Lich::Genie::DispatchDepth::LIMIT + 1)
    end

    # t51 (frozen Remix golden: genie-crash after 200 levels): an eval #trigger on $lastcommand
    # whose action sends `ping`. Each send raises "lastcommand" on the sending thread
    # (Game.cs:549-551 R) and the broadcast is one dispatch level, so the script's own send
    # plus LIMIT trigger sends go out, then the script whose send started the chain stops.
    it 't51_evaltrigger_lastcommand_loop: the $lastcommand chain is capped and the sending script stops' do
      case51 = cases.find { |c| c.name == 't51_evaltrigger_lastcommand_loop' }
      events = flow.run_ours(case51)
      sends = events.select { |e| e['ev'] == 'send' }.map { |e| [e['origin'], e['text']] }
      expect(sends).to eq([['t51_evaltrigger_lastcommand_loop', 'ping']] + Array.new(Lich::Genie::DispatchDepth::LIMIT) { %w[Trigger ping] })
      echoes = events.select { |e| e['ev'] == 'echo' }.map { |e| [e['script'], e['text']] }
      expect(echoes).to eq([['t51_evaltrigger_lastcommand_loop', d3_message.sub('#parse LOOP', 'variable change lastcommand')]])
      expect(events.last).to include('ev' => 'end', 'live' => 0) # `echo after` never ran
    end

    # t39 (frozen Remix golden: genie-crash): a #trigger whose body re-sends its own text, with
    # triggeroninput on (Config.cs:19 R default). Each send's text goes back through ParseTriggers
    # (FormMain.cs:4408-4410 R); every #trigger it fires is one dispatch level (ParseDispatch.input),
    # so the script's own send plus LIMIT trigger sends go out, then the script whose send started
    # the chain stops.
    it 't39_trigger_input_loop: the trigger-on-input chain is capped and the sending script stops' do
      case39 = cases.find { |c| c.name == 't39_trigger_input_loop' }
      events = flow.run_ours(case39)
      sends = events.select { |e| e['ev'] == 'send' }.map { |e| [e['origin'], e['text']] }
      expect(sends).to eq([%w[t39_trigger_input_loop ping]] + Array.new(Lich::Genie::DispatchDepth::LIMIT) { %w[Trigger ping] })
      echoes = events.select { |e| e['ev'] == 'echo' }.map { |e| [e['script'], e['text']] }
      expect(echoes).to eq([['t39_trigger_input_loop', d3_message.sub('#parse LOOP', 'input ping')]])
      expect(events.last).to include('ev' => 'end', 'live' => 0) # `echo after` never ran
    end
  end
end
