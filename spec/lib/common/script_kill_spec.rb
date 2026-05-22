# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/script'

RSpec.describe Lich::Common::Script do
  def build_running_script
    script = described_class.allocate
    script.instance_variable_set(:@name, 'test-script')
    script.instance_variable_set(:@custom, false)
    script.instance_variable_set(:@quiet, true)
    script.instance_variable_set(:@killed_externally, false)
    script.instance_variable_set(:@kill_source, nil)
    script.instance_variable_set(:@killer_mutex, Mutex.new)
    script.instance_variable_set(:@thread_group, ThreadGroup.new)
    script.instance_variable_set(:@die_with, [])
    script.instance_variable_set(:@at_exit_procs, [])
    script.instance_variable_set(:@paused, false)
    script.instance_variable_set(:@downstream_buffer, [])
    script.instance_variable_set(:@upstream_buffer, [])
    script.instance_variable_set(:@match_stack_labels, [])
    script.instance_variable_set(:@match_stack_strings, [])
    described_class.class_variable_set(:@@running, [script])
    script
  end

  def wait_for_kill(script)
    50.times do
      break unless described_class.running.include?(script)

      sleep 0.01
    end
  end

  before do
    stub_const('Lich::Util::MemoryReleaser', Module.new)
    allow(Lich::Util::MemoryReleaser).to receive(:release)
    described_class.class_variable_set(:@@running, [])
  end

  after do
    described_class.class_variable_set(:@@running, [])
  end

  describe '#kill' do
    it 'releases memory for ordinary runtime kills' do
      script = build_running_script

      script.kill
      wait_for_kill(script)

      expect(Lich::Util::MemoryReleaser).to have_received(:release)
    end

    it 'skips memory release during process shutdown' do
      script = build_running_script

      script.kill(context: :shutdown)
      wait_for_kill(script)

      expect(Lich::Util::MemoryReleaser).not_to have_received(:release)
    end
  end
end
