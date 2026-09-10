# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/infomon/status'
require 'gemstone/stance'

# Stance reads through Char, which spec_helper only gives a name. Add the two
# readers it needs, backed by plain accessors so examples can set them.
module Char
  class << self
    attr_accessor :stance, :percent_stance
  end
end

module Kernel
  def dothistimeout(_action, _timeout, _success_line); end unless method_defined?(:dothistimeout)
end

RSpec.describe Lich::Gemstone::Stance do
  before do
    Char.stance = 'offensive'
    Char.percent_stance = 0
    allow(described_class).to receive(:checkcastrt).and_return(0)
    allow(described_class).to receive(:waitrt?)
    allow(described_class).to receive(:fput)
    allow(described_class).to receive(:dothistimeout)
    allow(described_class).to receive(:perfection?).and_return(false)
    allow(Lich::Gemstone::Status).to receive(:dead?).and_return(false)
  end

  describe '.normalize' do
    it 'accepts full names' do
      expect(described_class.normalize('defensive')).to eq(['defensive', nil])
    end

    it 'accepts three-letter prefixes, any case' do
      expect(described_class.normalize('DEF')).to eq(['defensive', nil])
      expect(described_class.normalize('adv')).to eq(['advance', nil])
      expect(described_class.normalize('gua')).to eq(['guarded', nil])
    end

    it 'accepts symbols' do
      expect(described_class.normalize(:off)).to eq(['offensive', nil])
    end

    it 'maps a percent to its band and keeps the percent' do
      expect(described_class.normalize(0)).to eq(['offensive', 0])
      expect(described_class.normalize(20)).to eq(['advance', 20])
      expect(described_class.normalize(40)).to eq(['forward', 40])
      expect(described_class.normalize(60)).to eq(['neutral', 60])
      expect(described_class.normalize(80)).to eq(['guarded', 80])
      expect(described_class.normalize(90)).to eq(['defensive', 90])
      expect(described_class.normalize('100')).to eq(['defensive', 100])
    end

    it 'rejects percents that are not multiples of ten in range' do
      expect { described_class.normalize(55) }.to raise_error(ArgumentError)
      expect { described_class.normalize(110) }.to raise_error(ArgumentError)
    end

    it 'rejects unknown names and types' do
      expect { described_class.normalize('sideways') }.to raise_error(ArgumentError)
      expect { described_class.normalize('') }.to raise_error(ArgumentError)
      expect { described_class.normalize(nil) }.to raise_error(ArgumentError)
    end
  end

  describe '.at?' do
    it 'compares names' do
      Char.stance = 'guarded'
      expect(described_class.at?('gua')).to be true
      expect(described_class.at?('defensive')).to be false
    end

    it 'compares exact percent for numeric targets' do
      Char.stance = 'guarded'
      Char.percent_stance = 70
      expect(described_class.at?(70)).to be true
      expect(described_class.at?(80)).to be false
    end
  end

  describe '.safest' do
    it 'is defensive with no cast roundtime' do
      expect(described_class.safest).to eq('defensive')
    end

    it 'is guarded during cast roundtime' do
      allow(described_class).to receive(:checkcastrt).and_return(2)
      expect(described_class.safest).to eq('guarded')
    end
  end

  describe '.change' do
    it 'does nothing when already in the stance' do
      Char.stance = 'defensive'
      expect(described_class).not_to receive(:dothistimeout)
      expect(described_class.change('defensive')).to be true
    end

    it 'sends anyway when forced' do
      Char.stance = 'defensive'
      expect(described_class).to receive(:dothistimeout)
        .with('stance defensive', described_class::DEFAULT_TIMEOUT, described_class::CONFIRM)
        .and_return('You are now in a defensive stance.')
      expect(described_class.change('defensive', force: true)).to be true
    end

    it 'waits out roundtime, sends, and confirms' do
      expect(described_class).to receive(:waitrt?).ordered
      expect(described_class).to receive(:dothistimeout)
        .with('stance guarded', 3, described_class::CONFIRM).ordered
        .and_return('You move into a guarded stance.')
      expect(described_class.change(:guarded)).to be true
    end

    it 'accepts the fall-back phrasing' do
      allow(described_class).to receive(:dothistimeout).and_return('You fall back into a guarded stance.')
      expect(described_class.change('guarded')).to be true
    end

    it 'returns false when the game refuses' do
      allow(described_class).to receive(:dothistimeout).and_return('You are unable to change your stance.')
      expect(described_class.change('guarded')).to be false
    end

    it 'returns false on cast roundtime refusal' do
      allow(described_class).to receive(:dothistimeout).and_return('Cast Roundtime in effect.')
      expect(described_class.change('defensive')).to be false
    end

    it 'returns false when nothing confirms within the timeout' do
      allow(described_class).to receive(:dothistimeout).and_return(nil)
      expect(described_class.change('defensive')).to be false
    end

    it 'returns false without sending when dead' do
      allow(Lich::Gemstone::Status).to receive(:dead?).and_return(true)
      expect(described_class).not_to receive(:dothistimeout)
      expect(described_class.change('defensive')).to be false
    end

    it 'fires through fput and does not wait when wait is false' do
      expect(described_class).to receive(:fput).with('stance neutral')
      expect(described_class).not_to receive(:dothistimeout)
      expect(described_class.change('neutral', wait: false)).to be true
    end

    it 'honours a custom timeout' do
      expect(described_class).to receive(:dothistimeout).with('stance forward', 7, anything).and_return('You move into a forward stance.')
      described_class.change('forward', timeout: 7)
    end

    context 'with a percent target' do
      it 'uses cman stance when Stance Perfection is known' do
        allow(described_class).to receive(:perfection?).and_return(true)
        expect(described_class).to receive(:dothistimeout).with('cman stance 80', anything, anything).and_return('You move into a guarded stance.')
        expect(described_class.change(80)).to be true
      end

      it 'falls back to the band name without Stance Perfection' do
        expect(described_class).to receive(:dothistimeout).with('stance guarded', anything, anything).and_return('You move into a guarded stance.')
        expect(described_class.change(80)).to be true
      end

      it 'is a no-op when already at that exact percent' do
        Char.stance = 'guarded'
        Char.percent_stance = 80
        expect(described_class).not_to receive(:dothistimeout)
        expect(described_class.change(80)).to be true
      end

      it 'still sends when in the band but not at the percent' do
        Char.stance = 'guarded'
        Char.percent_stance = 70
        allow(described_class).to receive(:perfection?).and_return(true)
        expect(described_class).to receive(:dothistimeout).with('cman stance 80', anything, anything).and_return('You move into a guarded stance.')
        described_class.change(80)
      end
    end

    it 'raises on an unknown stance before touching the game' do
      expect(described_class).not_to receive(:dothistimeout)
      expect { described_class.change('sideways') }.to raise_error(ArgumentError)
    end
  end

  describe 'CONFIRM' do
    it 'matches every line the game answers with' do
      [
        'You are now in an offensive stance.',
        'You move into a guarded stance.',
        'You fall back into a defensive stance.',
        'You are unable to change your stance.',
        'Cast Roundtime in effect.  Stance change not allowed.',
      ].each do |line|
        expect(line).to match(described_class::CONFIRM)
      end
    end
  end
end
