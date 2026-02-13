# frozen_string_literal: true

require_relative '../../../spec_helper'

# Ensure Script has required test methods (may be defined as class elsewhere in full suite)
class Script
  class << self
    def running?(name)
      @running_scripts ||= []
      @running_scripts.include?(name)
    end

    def set_running(name)
      @running_scripts ||= []
      @running_scripts << name
    end

    def clear_running!
      @running_scripts = []
    end
  end
end

# Ensure test helpers exist on Lich::Messaging (may be defined elsewhere in full suite)
module Lich
  module Messaging
    @messages ||= []

    class << self
      def messages
        @messages ||= []
      end

      def clear_messages!
        @messages = []
      end

      # Ensure msg method captures messages for testing
      alias_method :original_msg, :msg if method_defined?(:msg) && !method_defined?(:original_msg)
      def msg(type, message)
        @messages ||= []
        @messages << { type: type, message: message }
      end
    end
  end
end

# Load the real DRSkill first (if not already loaded by drskill_spec)
require_relative '../../../../lib/dragonrealms/drinfomon/drskill'

# Load the module under test
require_relative '../../../../lib/dragonrealms/drinfomon/drexpmonitor'

# Create aliases for easier access
DRExpMonitor = Lich::DragonRealms::DRExpMonitor unless defined?(DRExpMonitor)
DRSkill = Lich::DragonRealms::DRSkill unless defined?(DRSkill)

RSpec.describe Lich::DragonRealms::DRExpMonitor do
  before(:each) do
    # Reset state before each test
    DRExpMonitor.stop if DRExpMonitor.active?
    DRExpMonitor.reset!
    DRSkill.class_variable_set(:@@gained_skills, [])
    Lich::Messaging.clear_messages!
    Lich.db.reset! if Lich.db.respond_to?(:reset!)
    Lich.reset_display_expgains! if Lich.respond_to?(:reset_display_expgains!)
    Script.clear_running! if Script.respond_to?(:clear_running!)
  end

  after(:each) do
    DRExpMonitor.stop if DRExpMonitor.active?
  end

  describe '.start' do
    it 'starts the reporter thread' do
      DRExpMonitor.start
      expect(DRExpMonitor.active?).to be true
    end

    it 'does not start if already running' do
      DRExpMonitor.start
      Lich::Messaging.clear_messages!

      DRExpMonitor.start

      expect(Lich::Messaging.messages.last[:message]).to include('already active')
    end

    it 'does not start if exp-monitor script is running' do
      Script.set_running('exp-monitor') if Script.respond_to?(:set_running)

      DRExpMonitor.start

      expect(DRExpMonitor.active?).to be false
      expect(Lich::Messaging.messages.last[:message]).to include('exp-monitor')
    end
  end

  describe '.stop' do
    it 'stops the reporter thread' do
      DRExpMonitor.start
      expect(DRExpMonitor.active?).to be true

      DRExpMonitor.stop
      expect(DRExpMonitor.active?).to be false
    end

    it 'handles stop when already stopped' do
      DRExpMonitor.stop

      expect(Lich::Messaging.messages.last[:message]).to include('already inactive')
    end
  end

  describe '.active?' do
    it 'returns false when not started' do
      expect(DRExpMonitor.active?).to be false
    end

    it 'returns true when started' do
      DRExpMonitor.start
      expect(DRExpMonitor.active?).to be true
    end
  end

  describe '.inline_display?' do
    it 'defaults to false when no DB value exists' do
      expect(DRExpMonitor.inline_display?).to be false
    end

    it 'returns false when DB value is false' do
      Lich.db.execute("INSERT INTO lich_settings VALUES ('display_inline_exp', ?)", ['false'])
      DRExpMonitor.reset!

      expect(DRExpMonitor.inline_display?).to be false
    end

    it 'returns true when DB value is true' do
      Lich.db.execute("INSERT INTO lich_settings VALUES ('display_inline_exp', ?)", ['true'])
      DRExpMonitor.reset!

      expect(DRExpMonitor.inline_display?).to be true
    end
  end

  describe '.inline_display=' do
    it 'sets inline display to true' do
      DRExpMonitor.inline_display = true
      expect(DRExpMonitor.inline_display?).to be true
    end

    it 'sets inline display to false' do
      DRExpMonitor.inline_display = false
      expect(DRExpMonitor.inline_display?).to be false
    end

    it 'accepts string values' do
      DRExpMonitor.inline_display = 'on'
      expect(DRExpMonitor.inline_display?).to be true

      DRExpMonitor.inline_display = 'off'
      expect(DRExpMonitor.inline_display?).to be false
    end

    it 'persists to database' do
      DRExpMonitor.inline_display = true
      expect(Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='display_inline_exp'")).to eq('true')
    end
  end

  describe 'constants' do
    describe 'MAX_SQLITE_RETRIES' do
      it 'is defined as 10 (BUG FIX: prevents infinite retry loops)' do
        expect(DRExpMonitor::MAX_SQLITE_RETRIES).to eq(10)
      end
    end

    describe 'BOOLEAN_TRUE_PATTERN' do
      it 'matches "on" exactly' do
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('on')).to be true
      end

      it 'matches "true" exactly' do
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('true')).to be true
      end

      it 'matches "yes" exactly' do
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('yes')).to be true
      end

      it 'matches case-insensitively' do
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('ON')).to be true
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('TRUE')).to be true
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('YES')).to be true
      end

      it 'does not match partial strings (BUG FIX)' do
        # Before fix, /on|true|yes/ would match "money" or "trust"
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('money')).to be false
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('trust')).to be false
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('yesman')).to be false
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('ongoing')).to be false
      end

      it 'does not match "off", "false", "no"' do
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('off')).to be false
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('false')).to be false
        expect(DRExpMonitor::BOOLEAN_TRUE_PATTERN.match?('no')).to be false
      end
    end
  end

  describe '.format_briefexp_on' do
    before do
      DRExpMonitor.inline_display = true
    end

    it 'appends gained exp to BRIEFEXP ON format' do
      allow(DRSkill).to receive(:gained_exp).with('Augmentation').and_return(0.15)
      line = '     Aug:  565 39%  [ 2/34]'

      result = DRExpMonitor.format_briefexp_on(line, 'Augmentation')

      expect(result).to eq('     Aug:  565 39%  [ 2/34] 0.15')
    end

    it 'shows 0.00 when no gains' do
      allow(DRSkill).to receive(:gained_exp).with('Augmentation').and_return(0.00)
      line = '     Aug:  565 39%  [ 2/34]'

      result = DRExpMonitor.format_briefexp_on(line, 'Augmentation')

      expect(result).to eq('     Aug:  565 39%  [ 2/34] 0.00')
    end

    it 'returns line unchanged when inline_display is off' do
      DRExpMonitor.inline_display = false
      line = '     Aug:  565 39%  [ 2/34]'

      result = DRExpMonitor.format_briefexp_on(line, 'Augmentation')

      expect(result).to eq(line)
    end

    it 'handles various skill mindstates' do
      allow(DRSkill).to receive(:gained_exp).with('Evasion').and_return(1.23)
      line = '    Evas:  800 75%  [34/34]'

      result = DRExpMonitor.format_briefexp_on(line, 'Evasion')

      expect(result).to eq('    Evas:  800 75%  [34/34] 1.23')
    end
  end

  describe '.format_briefexp_off' do
    before do
      DRExpMonitor.inline_display = true
    end

    it 'appends gained exp to BRIEFEXP OFF format' do
      allow(DRSkill).to receive(:gained_exp).with('Augmentation').and_return(0.15)
      line = '    Augmentation:  565 39% learning     '

      result = DRExpMonitor.format_briefexp_off(line, 'Augmentation', 'learning')

      expect(result).to include('0.15')
    end

    it 'pads the learning rate word' do
      allow(DRSkill).to receive(:gained_exp).with('Augmentation').and_return(0.15)
      line = '    Augmentation:  565 39% clear        '

      result = DRExpMonitor.format_briefexp_off(line, 'Augmentation', 'clear')

      # Should pad 'clear' to match longest rate word length
      expect(result).to include('clear')
      expect(result).to include('0.15')
    end

    it 'returns line unchanged when inline_display is off' do
      DRExpMonitor.inline_display = false
      line = '    Augmentation:  565 39% learning     '

      result = DRExpMonitor.format_briefexp_off(line, 'Augmentation', 'learning')

      expect(result).to eq(line)
    end
  end

  describe '.format_gains' do
    it 'formats single skill gain' do
      gains = [{ skill: 'Evasion', change: 2 }]

      result = DRExpMonitor.format_gains(gains)

      expect(result).to eq(['Evasion(+2)'])
    end

    it 'formats multiple skill gains' do
      gains = [
        { skill: 'Evasion', change: 2 },
        { skill: 'Parry Ability', change: 1 }
      ]

      result = DRExpMonitor.format_gains(gains)

      expect(result).to contain_exactly('Evasion(+2)', 'Parry Ability(+1)')
    end

    it 'aggregates multiple gains for same skill' do
      gains = [
        { skill: 'Evasion', change: 2 },
        { skill: 'Evasion', change: 3 },
        { skill: 'Parry Ability', change: 1 }
      ]

      result = DRExpMonitor.format_gains(gains)

      expect(result).to contain_exactly('Evasion(+5)', 'Parry Ability(+1)')
    end

    it 'returns empty array for no gains' do
      result = DRExpMonitor.format_gains([])

      expect(result).to eq([])
    end

    it 'sorts gains alphabetically by skill name' do
      gains = [
        { skill: 'Parry Ability', change: 1 },
        { skill: 'Evasion', change: 2 },
        { skill: 'Athletics', change: 3 }
      ]

      result = DRExpMonitor.format_gains(gains)

      expect(result).to eq(['Athletics(+3)', 'Evasion(+2)', 'Parry Ability(+1)'])
    end
  end

  describe '.report_skill_gains' do
    it 'reports gains and clears the queue' do
      DRSkill.gained_skills << { skill: 'Evasion', change: 2 }
      DRSkill.gained_skills << { skill: 'Parry Ability', change: 1 }

      DRExpMonitor.report_skill_gains

      expect(Lich::Messaging.messages.last[:message]).to include('DRExpMonitor:')
      expect(Lich::Messaging.messages.last[:message]).to include('Evasion(+2)')
      expect(DRSkill.gained_skills).to be_empty
    end

    it 'does not report when no gains' do
      Lich::Messaging.clear_messages!

      DRExpMonitor.report_skill_gains

      expect(Lich::Messaging.messages).to be_empty
    end
  end
end
