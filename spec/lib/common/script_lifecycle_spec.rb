# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/common/feature_flags'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

RSpec.describe 'Lich::Common::Script lifecycle extensions' do
  let(:script_class) { Lich::Common::Script }
  let(:subscript_class) { Lich::Common::SubScript }

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
    script_class.class_variable_set(:@@loaded_libraries, Set.new)
    allow(Lich).to receive(:log)
    allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(false)
    allow_any_instance_of(script_class).to receive(:report_errors) { |_script, &block| block.call }
  end

  after do
    script_class.list.each { |script| script.kill(context: :shutdown) if script.running? }
    script_class.class_variable_set(:@@running, [])
  end

  describe 'SubScript' do
    it 'runs a block with its own Script.current identity' do
      observed = Queue.new
      subscript = subscript_class.start { observed << script_class.current }

      expect(subscript.join(2)).to equal(subscript)
      expect(observed.pop(true)).to equal(subscript)
      expect(subscript).to be_a(subscript_class)
    end

    it 'unregisters itself when it exits naturally' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])

      child = subscript_class.start(:parent => parent) {}
      expect(child.join(2)).to equal(child)

      expect(parent.child_scripts).to be_empty
    end

    it 'is stopped with the parent using the parent kill context' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      child = subscript_class.start(:parent => parent) { Queue.new.pop }
      expect(child).to receive(:kill).with(:context => :shutdown).and_call_original
      expect(Thread).not_to receive(:new)

      parent.kill(:context => :shutdown)

      expect(parent).not_to be_running
      expect(child).not_to be_running
    end

    it 'inherits protection flags from its parent' do
      parent = build_script('daemon-parent')
      parent.hidden = true
      parent.no_kill_all = true
      parent.no_pause_all = true
      script_class.class_variable_set(:@@running, [parent])
      release = Queue.new
      child = subscript_class.start(:parent => parent) { release.pop }

      expect(child.hidden).to be(true)
      expect(child.no_kill_all).to be(true)
      expect(child.no_pause_all).to be(true)

      release << true
      child.join(2)
    end

    it 'rejects and stops a child registered after parent teardown begins' do
      parent = build_script('stopped-parent')
      script_class.class_variable_set(:@@running, [parent])
      parent.kill(:context => :shutdown)
      child = build_script('late-child')
      script_class.class_variable_set(:@@running, [child])

      expect(parent.register_child(child)).to be_nil
      expect(child).not_to be_running
    end
  end

  describe 'synchronous lifecycle methods' do
    it 'waits for exit handlers in kill_sync' do
      script = build_script('sync')
      script_class.class_variable_set(:@@running, [script])
      cleaned_up = false
      script.at_exit do
        sleep 0.02
        cleaned_up = true
      end

      expect(script.kill_sync).to equal(script)
      expect(cleaned_up).to be(true)
      expect(script).not_to be_running
    end

    it 'returns nil when join times out' do
      script = build_script('waiting')
      script_class.class_variable_set(:@@running, [script])

      expect(script.join(0.01)).to be_nil
    end
  end

  describe 'library loading' do
    let(:library_script) { instance_double(script_class, :name => 'libutil', :join => true) }

    before do
      allow(script_class).to receive(:exists?).and_return(true)
    end

    it 'starts a library only once across concurrent callers' do
      allow(script_class).to receive(:start).with('libutil').and_return(library_script)

      callers = Array.new(4) { Thread.new { script_class.loadlib('util') } }
      callers.each(&:join)

      expect(script_class).to have_received(:start).with('libutil').once
      expect(script_class.libs).to eq(Set['libutil'])
    end

    it 'allows retry when startup fails' do
      allow(script_class).to receive(:start).with('libutil').and_return(nil, library_script)

      expect { script_class.loadlib('util') }.to raise_error(LoadError, /failed to start/)
      expect(script_class.libs).to be_empty
      expect(script_class.loadlib('util')).to be(true)
    end

    it 'raises without recording a missing library' do
      allow(script_class).to receive(:exists?).with('libmissing').and_return(false)

      expect { script_class.loadlib('missing') }.to raise_error(LoadError, /not found/)
      expect(script_class.libs).to be_empty
    end

    it 'reloads a stable snapshot of loaded libraries' do
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil', 'libstatus'])
      allow(script_class).to receive(:run)

      expect(script_class.reloadlibs).to be(true)
      expect(script_class).to have_received(:run).with('libutil')
      expect(script_class).to have_received(:run).with('libstatus')
    end
  end

  describe '.kill_all' do
    it 'preserves protected and hidden scripts unless force is requested' do
      visible = build_script('visible')
      protected_script = build_script('protected')
      protected_script.no_kill_all = true
      hidden = build_script('hidden')
      hidden.hidden = true
      scripts = [visible, protected_script, hidden]
      script_class.class_variable_set(:@@running, scripts)
      scripts.each { |script| allow(script).to receive(:kill) }

      expect(script_class.kill_all).to eq(1)
      expect(visible).to have_received(:kill).with(:context => :runtime).once
      expect(protected_script).not_to have_received(:kill)
      expect(hidden).not_to have_received(:kill)

      expect(script_class.kill_all(:force => true)).to eq(3)
      expect(visible).to have_received(:kill).with(:context => :runtime).twice
      expect(protected_script).to have_received(:kill).with(:context => :runtime).once
      expect(hidden).to have_received(:kill).with(:context => :runtime).once
    end
  end

  def build_script(name)
    script_class.allocate.tap do |script|
      script.instance_variable_set(:@name, name)
      script.instance_variable_set(:@custom, false)
      script.instance_variable_set(:@quiet, true)
      script.instance_variable_set(:@thread_group, ThreadGroup.new)
      script.instance_variable_set(:@die_with, [])
      script.instance_variable_set(:@paused, false)
      script.instance_variable_set(:@at_exit_procs, [])
      script.instance_variable_set(:@downstream_buffer, [])
      script.instance_variable_set(:@upstream_buffer, [])
      script.instance_variable_set(:@match_stack_labels, [])
      script.instance_variable_set(:@match_stack_strings, [])
      script.instance_variable_set(:@killer_mutex, Mutex.new)
      script.instance_variable_set(:@killed_externally, false)
      script.instance_variable_set(:@kill_source, nil)
      script.instance_variable_set(:@hidden, false)
      script.instance_variable_set(:@no_kill_all, false)
      script.instance_variable_set(:@no_pause_all, false)
    end
  end
end
