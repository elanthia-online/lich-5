# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load dependencies in correct order
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'
require_relative '../../../../lib/dragonrealms/drinfomon/drskill'

# Load the module under test
require_relative '../../../../lib/dragonrealms/drinfomon/drexpmonitor'

RSpec.describe Lich::DragonRealms::DRExpMonitor do
  # Reference the real DRSkill class for specs that need it
  let(:drskill_class) { Lich::DragonRealms::DRSkill }

  before(:each) do
    # Reset state before each test
    described_class.stop if described_class.active?
    described_class.reset!
    drskill_class.class_variable_set(:@@gained_skills, [])
    Lich::Messaging.clear_messages!
    Lich.db.reset! if Lich.db.respond_to?(:reset!)
    Lich.reset_display_expgains! if Lich.respond_to?(:reset_display_expgains!)
  end

  after(:each) do
    described_class.stop if described_class.active?
  end

  describe '.start' do
    it 'starts the reporter thread' do
      described_class.start
      expect(described_class.active?).to be true
    end

    it 'does not start if already running' do
      described_class.start
      Lich::Messaging.clear_messages!

      described_class.start

      expect(Lich::Messaging.messages.last[:message]).to include('already active')
    end

    it 'does not start if exp-monitor script is running' do
      allow(Script).to receive(:running?).with('exp-monitor').and_return(true)

      described_class.start

      expect(described_class.active?).to be false
      expect(Lich::Messaging.messages.last[:message]).to include('exp-monitor')
    end
  end

  describe '.stop' do
    it 'stops the reporter thread' do
      described_class.start
      expect(described_class.active?).to be true

      described_class.stop
      expect(described_class.active?).to be false
    end

    it 'handles stop when already stopped' do
      described_class.stop

      expect(Lich::Messaging.messages.last[:message]).to include('already inactive')
    end
  end

  describe '.active?' do
    it 'returns false when not started' do
      expect(described_class.active?).to be false
    end

    it 'returns true when started' do
      described_class.start
      expect(described_class.active?).to be true
    end
  end

  describe '.inline_display?' do
    it 'defaults to false when no DB value exists' do
      expect(described_class.inline_display?).to be false
    end

    it 'returns false when DB value is false' do
      Lich.db.execute("INSERT INTO lich_settings VALUES ('display_inline_exp', ?)", ['false'])
      described_class.reset!

      expect(described_class.inline_display?).to be false
    end

    it 'returns true when DB value is true' do
      Lich.db.execute("INSERT INTO lich_settings VALUES ('display_inline_exp', ?)", ['true'])
      described_class.reset!

      expect(described_class.inline_display?).to be true
    end
  end

  describe '.inline_display=' do
    it 'sets inline display to true' do
      described_class.inline_display = true
      expect(described_class.inline_display?).to be true
    end

    it 'sets inline display to false' do
      described_class.inline_display = false
      expect(described_class.inline_display?).to be false
    end

    it 'accepts string values' do
      described_class.inline_display = 'on'
      expect(described_class.inline_display?).to be true

      described_class.inline_display = 'off'
      expect(described_class.inline_display?).to be false
    end

    it 'persists to database' do
      described_class.inline_display = true
      expect(Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='display_inline_exp'")).to eq('true')
    end
  end

  describe 'constants' do
    describe 'MAX_SQLITE_RETRIES' do
      it 'is defined as 10 (BUG FIX: prevents infinite retry loops)' do
        expect(described_class::MAX_SQLITE_RETRIES).to eq(10)
      end
    end

    describe 'BOOLEAN_TRUE_PATTERN' do
      it 'matches "on" exactly' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('on')).to be true
      end

      it 'matches "true" exactly' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('true')).to be true
      end

      it 'matches "yes" exactly' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('yes')).to be true
      end

      it 'matches case-insensitively' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('ON')).to be true
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('TRUE')).to be true
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('YES')).to be true
      end

      it 'does not match partial strings (BUG FIX)' do
        # Before fix, /on|true|yes/ would match "money" or "trust"
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('money')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('trust')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('yesman')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('ongoing')).to be false
      end

      it 'does not match "off", "false", "no"' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('off')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('false')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('no')).to be false
      end
    end
  end

  describe '.format_briefexp_on' do
    before do
      described_class.inline_display = true
    end

    it 'appends gained exp to BRIEFEXP ON format' do
      allow(drskill_class).to receive(:gained_exp).with('Augmentation').and_return(0.15)
      line = '     Aug:  565 39%  [ 2/34]'

      result = described_class.format_briefexp_on(line, 'Augmentation')

      expect(result).to eq('     Aug:  565 39%  [ 2/34] 0.15')
    end

    it 'shows 0.00 when no gains' do
      allow(drskill_class).to receive(:gained_exp).with('Augmentation').and_return(0.00)
      line = '     Aug:  565 39%  [ 2/34]'

      result = described_class.format_briefexp_on(line, 'Augmentation')

      expect(result).to eq('     Aug:  565 39%  [ 2/34] 0.00')
    end

    it 'returns line unchanged when inline_display is off' do
      described_class.inline_display = false
      line = '     Aug:  565 39%  [ 2/34]'

      result = described_class.format_briefexp_on(line, 'Augmentation')

      expect(result).to eq(line)
    end

    it 'handles various skill mindstates' do
      allow(drskill_class).to receive(:gained_exp).with('Evasion').and_return(1.23)
      line = '    Evas:  800 75%  [34/34]'

      result = described_class.format_briefexp_on(line, 'Evasion')

      expect(result).to eq('    Evas:  800 75%  [34/34] 1.23')
    end
  end

  describe '.format_briefexp_off' do
    before do
      described_class.inline_display = true
    end

    it 'appends gained exp to BRIEFEXP OFF format' do
      allow(drskill_class).to receive(:gained_exp).with('Augmentation').and_return(0.15)
      line = '    Augmentation:  565 39% learning     '

      result = described_class.format_briefexp_off(line, 'Augmentation', 'learning')

      expect(result).to include('0.15')
    end

    it 'pads the learning rate word' do
      allow(drskill_class).to receive(:gained_exp).with('Augmentation').and_return(0.15)
      line = '    Augmentation:  565 39% clear        '

      result = described_class.format_briefexp_off(line, 'Augmentation', 'clear')

      # Should pad 'clear' to match longest rate word length
      expect(result).to include('clear')
      expect(result).to include('0.15')
    end

    it 'returns line unchanged when inline_display is off' do
      described_class.inline_display = false
      line = '    Augmentation:  565 39% learning     '

      result = described_class.format_briefexp_off(line, 'Augmentation', 'learning')

      expect(result).to eq(line)
    end
  end

  describe '.format_gains' do
    it 'formats single skill gain' do
      gains = [{ skill: 'Evasion', change: 2 }]

      result = described_class.format_gains(gains)

      expect(result).to eq(['Evasion(+2)'])
    end

    it 'formats multiple skill gains' do
      gains = [
        { skill: 'Evasion', change: 2 },
        { skill: 'Parry Ability', change: 1 }
      ]

      result = described_class.format_gains(gains)

      expect(result).to contain_exactly('Evasion(+2)', 'Parry Ability(+1)')
    end

    it 'aggregates multiple gains for same skill' do
      gains = [
        { skill: 'Evasion', change: 2 },
        { skill: 'Evasion', change: 3 },
        { skill: 'Parry Ability', change: 1 }
      ]

      result = described_class.format_gains(gains)

      expect(result).to contain_exactly('Evasion(+5)', 'Parry Ability(+1)')
    end

    it 'returns empty array for no gains' do
      result = described_class.format_gains([])

      expect(result).to eq([])
    end

    it 'sorts gains alphabetically by skill name' do
      gains = [
        { skill: 'Parry Ability', change: 1 },
        { skill: 'Evasion', change: 2 },
        { skill: 'Athletics', change: 3 }
      ]

      result = described_class.format_gains(gains)

      expect(result).to eq(['Athletics(+3)', 'Evasion(+2)', 'Parry Ability(+1)'])
    end
  end

  describe '.report_skill_gains' do
    it 'reports gains and clears the queue' do
      drskill_class.gained_skills << { skill: 'Evasion', change: 2 }
      drskill_class.gained_skills << { skill: 'Parry Ability', change: 1 }

      described_class.report_skill_gains

      expect(Lich::Messaging.messages.last[:message]).to include('DRExpMonitor:')
      expect(Lich::Messaging.messages.last[:message]).to include('Evasion(+2)')
      expect(drskill_class.gained_skills).to be_empty
    end

    it 'does not report when no gains' do
      Lich::Messaging.clear_messages!

      described_class.report_skill_gains

      expect(Lich::Messaging.messages).to be_empty
    end
  end

  describe 'thread safety' do
    # Use fully qualified name inside threads since described_class isn't available in thread scope
    let(:expmonitor) { Lich::DragonRealms::DRExpMonitor }

    it 'handles concurrent start calls without error' do
      klass = expmonitor
      threads = 5.times.map do
        Thread.new { klass.start }
      end

      expect { threads.each(&:join) }.not_to raise_error
      expect(described_class.active?).to be true
    end

    it 'handles concurrent stop calls without error' do
      described_class.start
      expect(described_class.active?).to be true

      klass = expmonitor
      threads = 5.times.map do
        Thread.new { klass.stop }
      end

      expect { threads.each(&:join) }.not_to raise_error
      expect(described_class.active?).to be false
    end

    it 'handles concurrent start and stop calls without error' do
      klass = expmonitor
      threads = []

      # Alternate start/stop calls from different threads
      5.times do |i|
        threads << Thread.new do
          if i.even?
            klass.start
          else
            klass.stop
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end

    it 'does not leave mutex locked after exception in start' do
      # Stub Script.running? to raise an exception
      allow(Script).to receive(:running?).and_raise(StandardError.new("test error"))

      expect { described_class.start rescue nil }.not_to raise_error

      # Should be able to call stop without deadlock
      expect { described_class.stop }.not_to raise_error
    end
  end
end
