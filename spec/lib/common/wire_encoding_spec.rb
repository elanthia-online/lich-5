# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/common/wire_encoding'

RSpec.describe Lich::Common::WireEncoding do
  describe '.decode' do
    it 'passes plain ASCII through unchanged' do
      expect(described_class.decode('You see a small chest.')).to eq('You see a small chest.')
    end

    it 'decodes the common Windows-1252 typographic bytes to their correct Unicode code points' do
      # 0x92 = right single quotation mark, 0x97 = em-dash, 0x85 = ellipsis
      raw = "chest\x92s lid opens\x97slowly\x85".b
      expect(described_class.decode(raw)).to eq("chest\u2019s lid opens\u2014slowly\u2026")
    end

    it 'passes 0xA0-0xFF through as their direct Latin-1-equivalent code point' do
      # 0xE9 = e-acute, identical in Windows-1252 and Latin-1/Unicode
      raw = "caf\xE9".b
      expect(described_class.decode(raw)).to eq('café')
    end

    it 'does not raise on the five officially-undefined Windows-1252 byte positions' do
      # Regression coverage: Ruby's built-in Windows-1252 transcoder raises
      # Encoding::UndefinedConversionError on these five bytes. Saga passes
      # them through as their raw byte value instead, and this module must
      # match that rather than crash the reader thread on a rare byte.
      [0x81, 0x8D, 0x8F, 0x90, 0x9D].each do |byte|
        raw = [byte].pack('C').b
        expect { described_class.decode(raw) }.not_to raise_error
        expect(described_class.decode(raw).codepoints.first).to eq(byte)
      end
    end

    it 'ignores any encoding tag already on the input and only looks at the bytes' do
      mistagged = "chest\x92 nice.\r\n".b.force_encoding('UTF-8') # invalid as tagged
      expect(described_class.decode(mistagged)).to eq("chest\u2019 nice.\r\n")
    end

    it 'returns a valid, UTF-8-tagged string' do
      result = described_class.decode("chest\x92s".b)
      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to be true
    end
  end

  describe '.encode' do
    it 'passes plain ASCII through unchanged, as raw bytes' do
      expect(described_class.encode('say hello')).to eq('say hello'.b)
    end

    it 'encodes a curly apostrophe back to its single Windows-1252 byte' do
      expect(described_class.encode("say I\u2019m here")).to eq("say I\x92m here".b)
    end

    it 'substitutes ASCII ? for a character with no Windows-1252 representation' do
      expect(described_class.encode("say \u4E2D")).to eq('say ?'.b) # a CJK character
    end
  end

  describe 'round-trip' do
    it 'decode(encode(text)) restores common typographic punctuation' do
      original = "chest\u2019s lid opens\u2014slowly\u2026"
      expect(described_class.decode(described_class.encode(original))).to eq(original)
    end

    it 'encode(decode(byte)) restores every one of the 256 possible wire bytes' do
      (0x00..0xFF).each do |byte|
        raw = [byte].pack('C').b
        round_tripped = described_class.encode(described_class.decode(raw))
        expect(round_tripped.bytes).to eq([byte])
      end
    end
  end
end
