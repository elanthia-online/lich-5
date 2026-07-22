# frozen_string_literal: true

# Unit spec for Lich::Gemstone::Experience.
#
# Experience is a thin facade: the field/normal/ascension experience and the
# lumnis/rpa/fashlonae bonuses are read live from the mindState progressBar via
# XMLData, while fame/lte/deeds/deaths_sting and the freshness helpers read from
# Infomon. Both collaborators are stubbed here so the delegation and arithmetic
# are exercised in isolation (no game stream, no SQLite database).
#
# XMLData is the shared spec_helper mock module; the experience accessors are not
# defined on it, so they are stubbed per example (partial doubles are unverified
# in this suite, so this is allowed).

require_relative '../../spec_helper'

# Mirror the load sequence infomon_spec uses: the Infomon parser references
# Lich::Common::Spell at load time, so spell data and its dependencies must be
# loaded before requiring infomon/experience.
load_spell_data
require 'common/sharedbuffer'
require 'common/buffer'
require 'games'
require 'gemstone/overwatch'
require 'gemstone/infomon'
require 'common/class_exts/numeric'
require 'gemstone/experience'

RSpec.describe Lich::Gemstone::Experience do
  let(:infomon) { Lich::Gemstone::Infomon }

  describe 'experience values sourced from the mindState bar' do
    before do
      allow(XMLData).to receive(:exp).and_return(53_915_957)
      allow(XMLData).to receive(:ascension_exp).and_return(5_438)
    end

    it 'exposes normal experience via .exp' do
      expect(described_class.exp).to eq(53_915_957)
    end

    it 'exposes ascension experience via .axp' do
      expect(described_class.axp).to eq(5_438)
    end

    it 'derives total experience as normal + ascension' do
      expect(described_class.txp).to eq(53_915_957 + 5_438)
    end

    it 'exposes experience until the next level (under lvl 100) or next TP (lvl 100)' do
      allow(XMLData).to receive(:until_next).and_return(1_543)
      expect(described_class.until_next).to eq(1_543)
    end
  end

  describe 'ascension training points (next_atp)' do
    it 'reports the ascension experience remaining until the next ATP' do
      allow(XMLData).to receive(:ascension_exp).and_return(5_438)
      expect(described_class.next_atp).to eq(44_562)
    end

    it 'requires a full 50k interval from zero ascension experience' do
      allow(XMLData).to receive(:ascension_exp).and_return(0)
      expect(described_class.next_atp).to eq(50_000)
    end

    it 'accounts for partial progress past already-earned points' do
      allow(XMLData).to receive(:ascension_exp).and_return(120_000)
      expect(described_class.next_atp).to eq(30_000)
    end

    it 'reports a full interval immediately after crossing a threshold' do
      allow(XMLData).to receive(:ascension_exp).and_return(100_000)
      expect(described_class.next_atp).to eq(50_000)
    end
  end

  describe 'field experience' do
    before do
      allow(XMLData).to receive(:field_exp).and_return(1_077)
      allow(XMLData).to receive(:max_field_exp).and_return(1_500)
    end

    it 'exposes current and max field experience' do
      expect(described_class.fxp_current).to eq(1_077)
      expect(described_class.fxp_max).to eq(1_500)
    end

    it 'computes field experience as a percentage of the mind pool' do
      expect(described_class.percent_fxp).to be_within(0.001).of(71.8)
    end
  end

  describe 'experience percentages against total' do
    before do
      allow(XMLData).to receive(:exp).and_return(90)
      allow(XMLData).to receive(:ascension_exp).and_return(10)
    end

    it 'computes normal experience as a percentage of total' do
      expect(described_class.percent_exp).to eq(90.0)
    end

    it 'computes ascension experience as a percentage of total' do
      expect(described_class.percent_axp).to eq(10.0)
    end
  end

  describe 'lumnis bonus' do
    it 'is active and returns its value when present' do
      allow(XMLData).to receive(:lumnis).and_return(3)
      expect(described_class.lumnis?).to be(true)
      expect(described_class.lumnis).to eq(3)
    end

    it 'is inactive and nil when absent' do
      allow(XMLData).to receive(:lumnis).and_return(nil)
      expect(described_class.lumnis?).to be(false)
      expect(described_class.lumnis).to be_nil
    end
  end

  describe 'rpa bonus' do
    it 'is active and preserves a fractional value when present' do
      allow(XMLData).to receive(:rpa).and_return(1.5)
      expect(described_class.rpa?).to be(true)
      expect(described_class.rpa).to eq(1.5)
    end

    it 'returns a whole-number multiplier as sent' do
      allow(XMLData).to receive(:rpa).and_return(2.0)
      expect(described_class.rpa).to eq(2.0)
    end

    it 'is inactive and nil when absent' do
      allow(XMLData).to receive(:rpa).and_return(nil)
      expect(described_class.rpa?).to be(false)
      expect(described_class.rpa).to be_nil
    end
  end

  describe 'fashlonae bonus (absent / redeemed / active states)' do
    it 'is active and redeemed when the bar reports it as active (2)' do
      allow(XMLData).to receive(:fashlonae).and_return(2)
      expect(described_class.fashlonae?).to be(true)
      expect(described_class.fashlonae_redeemed?).to be(true)
    end

    it 'is redeemed but not active when reported as inactive (1)' do
      allow(XMLData).to receive(:fashlonae).and_return(1)
      expect(described_class.fashlonae?).to be(false)
      expect(described_class.fashlonae_redeemed?).to be(true)
    end

    it 'is neither active nor redeemed when the bar omits it' do
      allow(XMLData).to receive(:fashlonae).and_return(nil)
      expect(described_class.fashlonae?).to be(false)
      expect(described_class.fashlonae_redeemed?).to be(false)
    end
  end

  describe 'Infomon-backed values' do
    it 'reads fame from Infomon' do
      allow(infomon).to receive(:get).with('experience.fame').and_return(4_804_958)
      expect(described_class.fame).to eq(4_804_958)
    end

    it 'reads long-term experience from Infomon' do
      allow(infomon).to receive(:get).with('experience.long_term_experience').and_return(26_266)
      expect(described_class.lte).to eq(26_266)
    end

    it 'reads deeds from Infomon' do
      allow(infomon).to receive(:get).with('experience.deeds').and_return(20)
      expect(described_class.deeds).to eq(20)
    end

    it "reads death's sting from Infomon" do
      allow(infomon).to receive(:get).with('experience.deaths_sting').and_return('None')
      expect(described_class.deaths_sting).to eq('None')
    end
  end

  describe 'freshness helpers (keyed off the total_experience timestamp)' do
    context 'with a recent total_experience timestamp' do
      before do
        allow(infomon).to receive(:get_updated_at).with('experience.total_experience').and_return(Time.now.to_i)
      end

      it 'returns a Time from updated_at' do
        expect(described_class.updated_at).to be_within(2).of(Time.now)
      end

      it 'is not stale' do
        expect(described_class.stale?).to be(false)
      end

      it 'is recently updated' do
        expect(described_class.recently_updated?).to be(true)
      end
    end

    context 'with an old total_experience timestamp' do
      before do
        allow(infomon).to receive(:get_updated_at).with('experience.total_experience').and_return((Time.now - (26 * 60 * 60)).to_i)
      end

      it 'is stale' do
        expect(described_class.stale?).to be(true)
      end

      it 'is not recently updated' do
        expect(described_class.recently_updated?).to be(false)
      end
    end

    context 'when total_experience has never been recorded' do
      before do
        allow(infomon).to receive(:get_updated_at).with('experience.total_experience').and_return(nil)
      end

      it 'has a nil updated_at' do
        expect(described_class.updated_at).to be_nil
      end

      it 'is treated as stale' do
        expect(described_class.stale?).to be(true)
      end

      it 'is not recently updated' do
        expect(described_class.recently_updated?).to be(false)
      end
    end
  end
end
