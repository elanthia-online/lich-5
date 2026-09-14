# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/common/xml_entities'

RSpec.describe Lich::Common::XmlEntities do
  describe '.encode' do
    it 'encodes the three markup-significant characters' do
      expect(described_class.encode('a & b < c > d')).to eq('a &amp; b &lt; c &gt; d')
    end

    it 'encodes ampersands before the ones introduced by < and >, so nothing double-encodes' do
      expect(described_class.encode('<tag>')).to eq('&lt;tag&gt;')
      expect(described_class.encode('&amp;')).to eq('&amp;amp;')
    end

    it 'leaves a value with no markup characters untouched' do
      expect(described_class.encode('a rune-etched short sword')).to eq('a rune-etched short sword')
    end

    it 'coerces non-string values via to_s' do
      expect(described_class.encode(nil)).to eq('')
      expect(described_class.encode(42)).to eq('42')
    end
  end

  describe '.decode' do
    it 'decodes the five standard entities' do
      expect(described_class.decode('&lt;a&gt; &amp; &quot;b&quot; &apos;c&apos;'))
        .to eq('<a> & "b" \'c\'')
    end

    it 'returns the input unchanged when there is no ampersand' do
      expect(described_class.decode('no entities here')).to eq('no entities here')
    end
  end

  describe 'round-trip' do
    it 'decode(encode(str)) restores the three encoded characters' do
      original = 'a & b < c > d'
      expect(described_class.decode(described_class.encode(original))).to eq(original)
    end
  end
end
