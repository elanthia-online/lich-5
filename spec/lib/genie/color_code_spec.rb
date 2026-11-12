# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Lich::Genie::ColorCode: Remix Utility/ColorCode.cs IsHexString / StringToColor (R) and
# #echo's fg,bg test (Command.cs:295-310 R).
RSpec.describe Lich::Genie::ColorCode do
  describe '.hex_string?' do
    it 'accepts # plus six hex digits in either case' do
      expect(%w[#000000 #ABCDEF #abcdef #0a1B2c].map { |t| described_class.hex_string?(t) }).to all(be(true))
    end

    it 'rejects a missing #, wrong lengths, non-hex chars, and a padded text' do
      ['000000', '#00000', '#0000000', '#00000g', '##00000', '#00 000', '#abcdef ', ' #abcdef', '', nil]
        .each { |t| expect(described_class.hex_string?(t)).to be(false), t.inspect }
    end
  end

  describe '.echo_color?' do
    it 'tests the whole argument, or the trimmed fg of fg,bg' do
      expect(described_class.echo_color?('#cf2319')).to be(true)
      expect(described_class.echo_color?('#ff0000,#000000')).to be(true)
      expect(described_class.echo_color?('#ff0000, nonsense')).to be(true) # bg never decides
      expect(described_class.echo_color?('#ff0000 ,#000000')).to be(true) # fg Trim()med
    end

    it 'rejects a trailing comma (tested whole), a non-colour fg, @ names and non-web KnownColors' do
      ['#ff0000,', 'red,', 'x,#ff0000', 'zzz,red', '@#ff0000', '@red', '>Log', 'RebeccaPurple', 'Transparent',
       'ButtonFace', 'ControlText', 'grey', '']
        .each { |t| expect(described_class.echo_color?(t)).to be(false), t.inspect }
    end

    # ColorCode.IsColorString (ColorCode.cs:132-153 R): the KnownColor names between Transparent and
    # ButtonFace, any case (all 140 drop in genieflow).
    it 'accepts the 140 web colour names in any case, also as the fg of fg,bg' do
      expect(described_class::KNOWN_COLORS.length).to eq(140)
      expect(described_class::KNOWN_COLORS.first(2) + described_class::KNOWN_COLORS.last(2))
        .to eq(%w[AliceBlue AntiqueWhite Yellow YellowGreen])
      %w[red Red RED Crimson yellowgreen Lime].each { |t| expect(described_class.echo_color?(t)).to be(true), t }
      expect(described_class.echo_color?('RED,blue')).to be(true)
      expect(described_class.echo_color?('red,zzz')).to be(true) # the bg never decides
    end
  end
end
