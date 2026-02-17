# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GameBase::Game do
  describe '.autostarted?' do
    before do
      # Reset the class variable
      described_class.class_variable_set(:@@autostarted, false) if described_class.class_variable_defined?(:@@autostarted)
    end

    it 'returns false initially' do
      described_class.class_variable_set(:@@autostarted, false)
      expect(described_class.autostarted?).to be false
    end

    it 'returns true when @@autostarted is set to true' do
      described_class.class_variable_set(:@@autostarted, true)
      expect(described_class.autostarted?).to be true
    end

    it 'reflects the value of the @@autostarted class variable' do
      described_class.class_variable_set(:@@autostarted, false)
      expect(described_class.autostarted?).to be false

      described_class.class_variable_set(:@@autostarted, true)
      expect(described_class.autostarted?).to be true
    end
  end

  describe 'initialization state management' do
    before do
      described_class.class_variable_set(:@@autostarted, false) if described_class.class_variable_defined?(:@@autostarted)
    end

    context 'during startup lifecycle' do
      it 'starts with autostarted as false' do
        # Simulate fresh start
        described_class.send(:initialize_buffers) if described_class.respond_to?(:initialize_buffers)
        expect(described_class.autostarted?).to be false
      end

      it 'becomes true after handle_autostart is called' do
        skip 'Requires full Game environment to test handle_autostart'
        # This would need the full Lich environment loaded
        # described_class.send(:handle_autostart)
        # expect(described_class.autostarted?).to be true
      end
    end
  end

  describe '.settings_init_needed?' do
    before do
      described_class.class_variable_set(:@@settings_init_needed, false)
    end

    it 'returns false initially' do
      expect(described_class.settings_init_needed?).to be false
    end

    it 'returns true when @@settings_init_needed is set' do
      described_class.class_variable_set(:@@settings_init_needed, true)
      expect(described_class.settings_init_needed?).to be true
    end
  end

  describe 'class variable vs instance variable' do
    it 'uses a class variable (@@autostarted) not instance variable (@autostarted)' do
      # This test verifies the refactor from @ to @@
      expect(described_class.class_variable_defined?(:@@autostarted)).to be true

      # Set via class variable
      described_class.class_variable_set(:@@autostarted, true)

      # Should be readable via the method
      expect(described_class.autostarted?).to be true
    end
  end
end
