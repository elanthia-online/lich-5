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

  def build_script(name:, paused: false, ignore_pause: false)
    script_class.allocate.tap do |script|
      script.instance_variable_set(:@name, name)
      script.instance_variable_set(:@custom, false)
      script.instance_variable_set(:@quiet, true)
      script.instance_variable_set(:@thread_group, thread_group)
      script.instance_variable_set(:@die_with, [])
      script.instance_variable_set(:@paused, paused)
      script.instance_variable_set(:@ignore_pause, ignore_pause)
      script.instance_variable_set(:@at_exit_procs, [])
      script.instance_variable_set(:@downstream_buffer, [])
      script.instance_variable_set(:@upstream_buffer, [])
      script.instance_variable_set(:@match_stack_labels, [])
      script.instance_variable_set(:@match_stack_strings, [])
      script.instance_variable_set(:@killer_mutex, Mutex.new)
      script.instance_variable_set(:@killed_externally, false)
      script.instance_variable_set(:@kill_source, nil)
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
  end
end
