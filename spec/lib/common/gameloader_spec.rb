# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lich::Common::GameLoader do
  describe '.dragon_realms' do
    before do
      # Stub file requires to prevent actual loading
      allow(described_class).to receive(:common_before)
      allow(described_class).to receive(:common_after)
      allow(described_class).to receive(:require)
    end

    it 'loads DragonRealms-specific modules' do
      skip 'Requires LIB_DIR to be defined'
      # expect(described_class).to receive(:require).with(/drinfomon/)
      # described_class.dragon_realms
    end

    it 'calls DRInfomon.watch!' do
      # Mock DRInfomon to avoid loading the actual module
      stub_const('DRInfomon', Class.new do
        def self.watch!
          # no-op
        end
      end)

      expect(DRInfomon).to receive(:watch!)
      described_class.dragon_realms
    end

    it 'calls watch! after loading modules' do
      stub_const('DRInfomon', Class.new do
        def self.watch!
          # no-op
        end
      end)

      call_order = []
      allow(described_class).to receive(:common_before) { call_order << :common_before }
      allow(DRInfomon).to receive(:watch!) { call_order << :watch }
      allow(described_class).to receive(:common_after) { call_order << :common_after }

      described_class.dragon_realms

      expect(call_order).to eq([:common_before, :watch, :common_after])
    end
  end

  describe '.gemstone' do
    before do
      allow(described_class).to receive(:common_before)
      allow(described_class).to receive(:common_after)
      allow(described_class).to receive(:require)
    end

    it 'calls ActiveSpell.watch!' do
      stub_const('ActiveSpell', Class.new do
        def self.watch!
          # no-op
        end
      end)

      stub_const('Infomon', Class.new do
        def self.watch!
          # no-op
        end
      end)

      expect(ActiveSpell).to receive(:watch!)
      described_class.gemstone
    end

    it 'calls Infomon.watch!' do
      stub_const('ActiveSpell', Class.new do
        def self.watch!
          # no-op
        end
      end)

      stub_const('Infomon', Class.new do
        def self.watch!
          # no-op
        end
      end)

      expect(Infomon).to receive(:watch!)
      described_class.gemstone
    end

    it 'calls watch! methods in correct order' do
      stub_const('ActiveSpell', Class.new do
        def self.watch!
          # no-op
        end
      end)

      stub_const('Infomon', Class.new do
        def self.watch!
          # no-op
        end
      end)

      call_order = []
      allow(ActiveSpell).to receive(:watch!) { call_order << :activespell }
      allow(Infomon).to receive(:watch!) { call_order << :infomon }

      described_class.gemstone

      expect(call_order).to eq([:activespell, :infomon])
    end
  end

  describe '.load!' do
    it 'dispatches to dragon_realms when game is DR' do
      allow(XMLData).to receive(:game).and_return('DR')
      allow(described_class).to receive(:dragon_realms)

      expect(described_class).to receive(:dragon_realms)
      described_class.load!
    end

    it 'dispatches to gemstone when game is GS' do
      allow(XMLData).to receive(:game).and_return('GS')
      allow(described_class).to receive(:gemstone)

      expect(described_class).to receive(:gemstone)
      described_class.load!
    end
  end
end
