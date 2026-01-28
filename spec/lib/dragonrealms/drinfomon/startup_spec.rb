# frozen_string_literal: true

require_relative '../../../spec_helper'

# Mock ExecScript for testing startup behavior
class ExecScript
  @last_cmd = nil
  @last_options = nil

  class << self
    attr_reader :last_cmd, :last_options

    def start(cmd_data, options = {})
      @last_cmd = cmd_data
      @last_options = options
      true
    end

    def reset!
      @last_cmd = nil
      @last_options = nil
    end
  end
end unless defined?(ExecScript)

# Load the module under test
require_relative '../../../../lib/dragonrealms/drinfomon/startup'

DRInfomon = Lich::DragonRealms::DRInfomon unless defined?(DRInfomon)

RSpec.describe Lich::DragonRealms::DRInfomon do
  before(:each) do
    ExecScript.reset! if ExecScript.respond_to?(:reset!)
  end

  describe '.startup' do
    it 'starts an ExecScript named drinfomon_startup' do
      DRInfomon.startup

      expect(ExecScript.last_options).to include(name: "drinfomon_startup")
    end

    it 'passes the startup script to ExecScript' do
      DRInfomon.startup

      expect(ExecScript.last_cmd).to eq(DRInfomon.startup_script)
    end
  end

  describe '.startup_complete?' do
    it 'is false before startup runs' do
      DRInfomon.class_variable_set(:@@startup_complete, false)

      expect(DRInfomon.startup_complete?).to be false
    end

    it 'is true after startup_completed! is called' do
      DRInfomon.startup_completed!

      expect(DRInfomon.startup_complete?).to be true
    end
  end

  describe '.startup_script' do
    subject(:script) { DRInfomon.startup_script }

    it 'issues info command guarded by dead? check' do
      expect(script).to include('issue_command("info"')
      expect(script).to include('unless dead?')
    end

    it 'issues played command' do
      expect(script).to include('issue_command("played"')
    end

    it 'issues exp all 0 command' do
      expect(script).to include('issue_command("exp all 0"')
    end

    it 'issues ability command' do
      expect(script).to include('issue_command("ability"')
    end

    it 'issues info before played, exp, and ability' do
      info_pos = script.index('issue_command("info"')
      played_pos = script.index('issue_command("played"')
      exp_pos = script.index('issue_command("exp all 0"')
      ability_pos = script.index('issue_command("ability"')

      expect(info_pos).to be < played_pos
      expect(played_pos).to be < exp_pos
      expect(exp_pos).to be < ability_pos
    end

    it 'signals startup_completed! after all commands' do
      ability_pos = script.index('issue_command("ability"')
      signal_pos = script.index("startup_completed!")

      expect(signal_pos).to be > ability_pos
    end
  end
end
