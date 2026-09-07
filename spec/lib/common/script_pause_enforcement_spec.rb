# frozen_string_literal: true

require 'timeout'
require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/common/feature_flags'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

# wait_while/wait_until live in global_defs.rb, which can't be required
# wholesale in spec context (it pulls in many unrelated global dependencies).
# Extract just those two definitions, mirroring the technique used in
# global_defs_spec.rb.
global_defs_path = File.join(File.dirname(__FILE__), '..', '..', '..', 'lib', 'global_defs.rb')
global_defs_lines = File.readlines(global_defs_path)
%w[wait_until wait_while].each do |method_name|
  fn_start = global_defs_lines.index { |l| l =~ /^def #{method_name}\(/ }
  raise "#{method_name} not found in #{global_defs_path}" unless fn_start

  fn_end = global_defs_lines[fn_start + 1..].index { |l| l =~ /^end\s*$/ }
  # Avoid depending on a top-level `Script` constant alias (only set up by
  # `include Lich::Common` in the real lich.rbw boot path) -- reference the
  # real class directly instead.
  source = global_defs_lines[fn_start..fn_start + 1 + fn_end].join.gsub(/\bScript\./, 'Lich::Common::Script.')
  eval(source, TOPLEVEL_BINDING, global_defs_path, fn_start + 1)
end

RSpec.describe 'Lich::Common::Script pause enforcement' do
  let(:thread_group) { ThreadGroup.new }
  let(:script_class) { Lich::Common::Script }

  before(:context) do
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  before do
    script_class.class_variable_set(:@@running, [])
    script_class.class_variable_set(:@@stopping, [])
    allow(Lich).to receive(:log)
  end

  after do
    script_class.class_variable_set(:@@running, [])
    script_class.class_variable_set(:@@stopping, [])
  end

  def build_script(name:, paused: false, ignore_pause: false, no_pause_all: false, die_with: [])
    script_class.allocate.tap do |script|
      script.instance_variable_set(:@name, name)
      script.instance_variable_set(:@custom, false)
      script.instance_variable_set(:@quiet, true)
      script.instance_variable_set(:@thread_group, thread_group)
      script.instance_variable_set(:@die_with, die_with)
      script.instance_variable_set(:@paused, paused)
      script.instance_variable_set(:@ignore_pause, ignore_pause)
      script.instance_variable_set(:@no_pause_all, no_pause_all)
      script.instance_variable_set(:@at_exit_procs, [])
      script.instance_variable_set(:@downstream_buffer, [])
      script.instance_variable_set(:@upstream_buffer, [])
      script.instance_variable_set(:@match_stack_labels, [])
      script.instance_variable_set(:@match_stack_strings, [])
      script.instance_variable_set(:@killer_mutex, Mutex.new)
      script.instance_variable_set(:@killed_externally, false)
      script.instance_variable_set(:@kill_source, nil)
      allow(script).to receive(:report_errors) { |&blk| blk.call }
    end
  end

  describe '#wait_while_paused!' do
    it 'blocks while paused and returns once unpaused' do
      script = build_script(name: 'watcher', paused: true)

      waiter = Thread.new { script.wait_while_paused! }
      sleep 0.1
      expect(waiter).to be_alive

      script.paused = false
      waiter.join(2)
      expect(waiter).not_to be_alive
    end

    it 'returns immediately for a paused script with ignore_pause set' do
      script = build_script(name: 'watcher', paused: true, ignore_pause: true)

      expect(Timeout.timeout(1) { script.wait_while_paused! }).to be_nil
    end
  end

  describe 'the bigshot regression: a paused script mutating another script via a helper' do
    it 'does not let Script.kill take effect until the calling script is unpaused' do
      caller_script = build_script(name: 'bigshot', paused: true)
      target_script = build_script(name: 'eloot')
      script_class.class_variable_set(:@@running, [caller_script, target_script])
      allow(target_script).to receive(:kill)

      kill_thread = Thread.new do
        Thread.current.thread_variable_set(Lich::Common::Script::CLEANUP_SCRIPT_THREAD_KEY, caller_script)
        script_class.kill(target_script.name)
      end

      sleep 0.1
      expect(target_script).not_to have_received(:kill)
      expect(kill_thread).to be_alive

      caller_script.paused = false
      kill_thread.join(2)

      expect(kill_thread).not_to be_alive
      expect(target_script).to have_received(:kill)
    end

    it 'does not let Script.running? observe state changes until the calling script is unpaused' do
      caller_script = build_script(name: 'bigshot', paused: true)
      script_class.class_variable_set(:@@running, [caller_script])

      check_thread = Thread.new do
        Thread.current.thread_variable_set(Lich::Common::Script::CLEANUP_SCRIPT_THREAD_KEY, caller_script)
        script_class.running?('eloot')
      end

      sleep 0.1
      expect(check_thread).to be_alive

      caller_script.paused = false
      expect(check_thread.value).to eq(false)
    end

    it 'does not let Script.kill_all take effect until the calling script is unpaused' do
      caller_script = build_script(name: 'bigshot', paused: true)
      target_script = build_script(name: 'eloot')
      script_class.class_variable_set(:@@running, [caller_script, target_script])
      allow(script_class).to receive(:running).and_return([caller_script, target_script])
      allow(target_script).to receive(:kill)
      allow(caller_script).to receive(:kill)

      kill_all_thread = Thread.new do
        Thread.current.thread_variable_set(Lich::Common::Script::CLEANUP_SCRIPT_THREAD_KEY, caller_script)
        script_class.kill_all
      end

      sleep 0.1
      expect(target_script).not_to have_received(:kill)
      expect(kill_all_thread).to be_alive

      caller_script.paused = false
      kill_all_thread.join(2)

      expect(kill_all_thread).not_to be_alive
      expect(target_script).to have_received(:kill)
    end
  end

  describe 'no_pause_all is preserved and not conflated with a checkpoint bypass' do
    it 'is still excluded from the bulk pause-all/unpause-all selection, unaffected by this change' do
      normal = build_script(name: 'normal-script')
      exempt = build_script(name: 'exempt-script', no_pause_all: true)
      script_class.class_variable_set(:@@running, [normal, exempt])

      # Mirrors the `pause all` selection in global_defs.rb / DRC common.rb:
      # `Script.running.find_all { |s| not s.paused? and not s.no_pause_all }`
      to_pause = script_class.running.find_all { |s| !s.paused? && !s.no_pause_all }
      expect(to_pause).to contain_exactly(normal)

      to_pause.each(&:pause)
      expect(normal.paused?).to be true
      expect(exempt.paused?).to be false
    end

    it 'does not exempt a no_pause_all script from wait_while_paused! if it is individually paused' do
      script = build_script(name: 'watcher', paused: true, no_pause_all: true)

      waiter = Thread.new { script.wait_while_paused! }
      sleep 0.1
      expect(waiter).to be_alive

      script.paused = false
      waiter.join(2)
      expect(waiter).not_to be_alive
    end

    it 'does not exempt a no_pause_all caller from the Script.kill checkpoint' do
      caller_script = build_script(name: 'bigshot', paused: true, no_pause_all: true)
      target_script = build_script(name: 'eloot')
      script_class.class_variable_set(:@@running, [caller_script, target_script])
      allow(target_script).to receive(:kill)

      kill_thread = Thread.new do
        Thread.current.thread_variable_set(Lich::Common::Script::CLEANUP_SCRIPT_THREAD_KEY, caller_script)
        script_class.kill(target_script.name)
      end

      sleep 0.1
      expect(target_script).not_to have_received(:kill)
      expect(kill_thread).to be_alive

      caller_script.paused = false
      kill_thread.join(2)

      expect(kill_thread).not_to be_alive
      expect(target_script).to have_received(:kill)
    end
  end

  describe 'a paused script tearing down its own die_with dependents' do
    it 'does not deadlock cleanup on its own pause state (coderabbit review, PR #1537)' do
      # If a paused script is killed and has die_with dependents, its cleanup
      # thread identifies as itself (CLEANUP_SCRIPT_THREAD_KEY), so the
      # Script.kill checkpoint added for the bigshot fix would otherwise wait
      # on the script's own pause state -- which nothing will ever clear,
      # since the script is dying. This must complete promptly instead.
      parent = build_script(name: 'paused-parent', paused: true, die_with: ['dependent'])
      dependent = build_script(name: 'dependent')
      script_class.class_variable_set(:@@running, [parent, dependent])

      expect(Timeout.timeout(2) { parent.kill(context: :shutdown) }).to eq('paused-parent')

      expect(script_class.list).to be_empty
    end
  end

  describe 'wait_while / wait_until' do
    it 'wait_while re-checks pause state on every iteration, not just at entry' do
      script = build_script(name: 'waiter', paused: false)
      allow(script_class).to receive(:current).and_return(script)
      condition = true

      wait_thread = Thread.new { wait_while { condition } }
      sleep 0.1

      script.paused = true
      sleep 0.1
      condition = false # condition alone would exit the loop; pause must still hold it
      sleep 0.1
      expect(wait_thread).to be_alive

      script.paused = false
      wait_thread.join(2)
      expect(wait_thread).not_to be_alive
    end

    # Astra review, PR #1537 (finding 1): the entry/per-iteration pause check
    # happens *before* the predicate is evaluated, so a script paused while
    # the predicate itself is blocked or yielding control would previously
    # fall straight through to the caller the instant the predicate
    # resolved, without ever re-checking pause. Deterministic via Queue
    # hand-off rather than sleep timing, per that review's testability note.
    it 'does not return to the caller if the script is paused while wait_while\'s predicate is resolving' do
      script = build_script(name: 'waiter', paused: false)
      allow(script_class).to receive(:current).and_return(script)
      predicate_entered = Queue.new
      release_predicate = Queue.new
      keep_waiting = true

      wait_thread = Thread.new do
        wait_while do
          predicate_entered << true
          release_predicate.pop
          keep_waiting
        end
      end

      predicate_entered.pop # the predicate is now blocked, mid-evaluation
      script.paused = true  # pause while control is inside the predicate
      keep_waiting = false  # predicate will return false -- wait_while's exit condition
      release_predicate << true

      sleep 0.1
      expect(wait_thread).to be_alive

      script.paused = false
      wait_thread.join(2)
      expect(wait_thread).not_to be_alive
    end

    it 'does not return to the caller if the script is paused while wait_until\'s predicate is resolving' do
      script = build_script(name: 'waiter', paused: false)
      allow(script_class).to receive(:current).and_return(script)
      predicate_entered = Queue.new
      release_predicate = Queue.new
      condition_met = false

      wait_thread = Thread.new do
        wait_until do
          predicate_entered << true
          release_predicate.pop
          condition_met
        end
      end

      predicate_entered.pop # the predicate is now blocked, mid-evaluation
      script.paused = true  # pause while control is inside the predicate
      condition_met = true  # predicate will return true -- wait_until's exit condition
      release_predicate << true

      sleep 0.1
      expect(wait_thread).to be_alive

      script.paused = false
      wait_thread.join(2)
      expect(wait_thread).not_to be_alive
    end
  end

  describe 'Script.run' do
    # Astra review, PR #1537 (finding 2): Script.start gained a pause
    # checkpoint but the adjacent Script.run -- a separate public entry point
    # used by e.g. lib/common/spell.rb -- called the same start primitive
    # directly, bypassing it.
    it 'does not let Script.run initiate a new script until the calling script is unpaused' do
      caller_script = build_script(name: 'bigshot', paused: true)
      script_class.class_variable_set(:@@running, [caller_script])
      started_script = instance_double(script_class, join: 'child-name')
      original_start = script_class.class_variable_get(:@@elevated_script_start)
      script_class.class_variable_set(:@@elevated_script_start, proc { |_args, _parent| started_script })

      begin
        run_thread = Thread.new do
          Thread.current.thread_variable_set(Lich::Common::Script::CLEANUP_SCRIPT_THREAD_KEY, caller_script)
          script_class.run('child')
        end

        sleep 0.1
        expect(run_thread).to be_alive

        caller_script.paused = false
        run_thread.join(2)

        expect(run_thread).not_to be_alive
        expect(run_thread.value).to eq('child-name')
      ensure
        script_class.class_variable_set(:@@elevated_script_start, original_start)
      end
    end
  end
end
