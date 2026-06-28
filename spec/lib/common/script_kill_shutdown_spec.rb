# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/feature_flags'
# Load the real hook classes so the ScriptDeath cleanup that the kill path runs
# resolves against real registries (matching production) rather than the
# top-level spec_helper mocks.
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

# Adversarial coverage for the shutdown kill path:
#   Fix 1 - the re-entrancy guard that stops a die_with cycle from recursively
#           locking the non-reentrant @killer_mutex on the inline cleanup path.
#   Fix 2 - inline (no Thread.new) cleanup when kill is called with
#           context: :shutdown, so a mass shutdown does not burst one cleanup
#           thread per dying script and exhaust the OS thread ceiling.
RSpec.describe 'Lich::Common::Script shutdown kill path' do
  let(:script_class) { Lich::Common::Script }

  before(:context) do
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    %i[ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  before do
    script_class.class_variable_set(:@@running, [])
    # Empty hook registries so the ScriptDeath cleanup has no stale state to act
    # on and nothing leaks across examples (these are class-level).
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hooks, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_sources, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_owners, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_persist, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hooks, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_sources, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_owners, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_persist, {})
    allow(Lich).to receive(:log)
    allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(false)
  end

  after do
    script_class.class_variable_set(:@@running, [])
  end

  describe 're-entrancy guard (Fix 1)' do
    it 'tears down a die_with cycle on the inline path without recursive locking' do
      cleanup_counts = Hash.new(0)
      a = build_script(name: 'cycle-a', die_with: ['cycle-b'])
      b = build_script(name: 'cycle-b', die_with: ['cycle-a'])
      a.at_exit { cleanup_counts[:a] += 1 }
      b.at_exit { cleanup_counts[:b] += 1 }
      script_class.class_variable_set(:@@running, [a, b])

      # Force the inline cleanup path for every kill in the cascade -- this is
      # the exact condition (thread allocation failing under exit pressure)
      # under which the recursive-lock deadlock manifested.
      allow(Thread).to receive(:new).and_raise(ThreadError, "can't alloc thread")

      expect { a.kill }.not_to raise_error

      # The recursive re-entry is skipped, not run: each script's cleanup body
      # (and therefore its at_exit proc) executes exactly once...
      expect(cleanup_counts).to eq(a: 1, b: 1)
      # ...the registry fully drains (without the guard the inner script never
      # reaches its @@running.delete and is left behind)...
      expect(script_class.list).to be_empty
      # ...and the "deadlock; recursive locking" symptom never surfaces (without
      # the guard it is raised and swallowed by the cleanup rescue, then logged).
      expect(Lich).not_to have_received(:log).with(/deadlock|recursive locking/)
    end

    it 'treats a re-kill of an already-drained script as a clean no-op' do
      cleanup_counts = Hash.new(0)
      script = build_script(name: 'idempotent')
      script.at_exit { cleanup_counts[:n] += 1 }
      script_class.class_variable_set(:@@running, [script])
      allow(Thread).to receive(:new) { |&block| block.call; instance_double(Thread) }

      script.kill
      expect(script_class.list).to be_empty
      expect(cleanup_counts[:n]).to eq(1)

      # Re-killing the same instance does nothing: it is gone from @@running, so
      # the cleanup body is skipped and the at_exit proc does not run again.
      expect { script.kill }.not_to raise_error
      expect(cleanup_counts[:n]).to eq(1)
      expect(script_class.list).to be_empty
    end
  end

  describe 'inline cleanup at shutdown (Fix 2)' do
    it 'runs cleanup inline without spawning a cleanup thread' do
      script = build_script(name: 'shutting-down')
      script_class.class_variable_set(:@@running, [script])
      expect(Thread).not_to receive(:new)

      expect(script.kill(context: :shutdown)).to eq('shutting-down')

      expect(script_class.list).to be_empty
    end

    it 'tears down a fleet of scripts at shutdown with no Thread.new burst' do
      scripts = Array.new(5) { |i| build_script(name: "shutdown-#{i}") }
      script_class.class_variable_set(:@@running, scripts.dup)
      expect(Thread).not_to receive(:new)

      scripts.each { |s| s.kill(context: :shutdown) }

      expect(script_class.list).to be_empty
    end
  end

  describe 'runtime kill regression' do
    it 'still runs cleanup asynchronously in a dedicated thread' do
      script = build_script(name: 'async-target')
      script_class.class_variable_set(:@@running, [script])
      expect(Thread).to receive(:new) { |&block| block.call; instance_double(Thread) }

      expect(script.kill).to eq('async-target')

      expect(script_class.list).to be_empty
    end
  end

  def build_script(name:, die_with: [])
    thread_group = instance_double(ThreadGroup, list: [], add: true)
    script_class.allocate.tap do |script|
      script.instance_variable_set(:@name, name)
      script.instance_variable_set(:@custom, false)
      script.instance_variable_set(:@quiet, true)
      script.instance_variable_set(:@thread_group, thread_group)
      script.instance_variable_set(:@die_with, die_with)
      script.instance_variable_set(:@paused, false)
      script.instance_variable_set(:@at_exit_procs, [])
      script.instance_variable_set(:@downstream_buffer, [])
      script.instance_variable_set(:@upstream_buffer, [])
      script.instance_variable_set(:@match_stack_labels, [])
      script.instance_variable_set(:@match_stack_strings, [])
      script.instance_variable_set(:@killer_mutex, Mutex.new)
      script.instance_variable_set(:@killed_externally, false)
      script.instance_variable_set(:@kill_source, nil)
      # report_errors lives in global_defs.rb (a Kernel-level helper) that the
      # isolated harness does not load; the kill path calls it to run each
      # at_exit proc. Stub it to just yield (its real behavior, minus the
      # rescue) so at_exit handlers actually fire and can be observed.
      allow(script).to receive(:report_errors) { |&blk| blk.call }
    end
  end
end
