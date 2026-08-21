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
      raw = "chest\x92s lid opens\x97slowly\x85".b # rubocop:disable Custom/AsciiOnlySource
      expect(described_class.decode(raw)).to eq("chest\u2019s lid opens\u2014slowly\u2026") # rubocop:disable Custom/AsciiOnlySource
    end

    it 'passes 0xA0-0xFF through as their direct Latin-1-equivalent code point' do
      # 0xE9 = e-acute, identical in Windows-1252 and Latin-1/Unicode
      raw = "caf\xE9".b # rubocop:disable Custom/AsciiOnlySource
      expect(described_class.decode(raw)).to eq('café') # rubocop:disable Custom/AsciiOnlySource
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
      mistagged = "chest\x92 nice.\r\n".b.force_encoding('UTF-8') # invalid as tagged # rubocop:disable Custom/AsciiOnlySource
      expect(described_class.decode(mistagged)).to eq("chest\u2019 nice.\r\n") # rubocop:disable Custom/AsciiOnlySource
    end

    it 'returns a valid, UTF-8-tagged string' do
      result = described_class.decode("chest\x92s".b) # rubocop:disable Custom/AsciiOnlySource
      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to be true
    end

    it 'returns nil for nil input, matching IO#gets on disconnect, rather than raising' do
      expect(described_class.decode(nil)).to be_nil
    end
  end

  describe '.encode' do
    it 'passes plain ASCII through unchanged, as raw bytes' do
      expect(described_class.encode('say hello')).to eq('say hello'.b)
    end

    it 'encodes a curly apostrophe back to its single Windows-1252 byte' do
      expect(described_class.encode("say I\u2019m here")).to eq("say I\x92m here".b) # rubocop:disable Custom/AsciiOnlySource
    end

    it 'substitutes ASCII ? for a character with no Windows-1252 representation' do
      expect(described_class.encode("say \u4E2D")).to eq('say ?'.b) # a CJK character # rubocop:disable Custom/AsciiOnlySource
    end

    it 'returns nil for nil input rather than raising' do
      expect(described_class.encode(nil)).to be_nil
    end
  end

  describe 'Wizard marker code points' do
    # Regression coverage for a real bug: Wizard's legacy binary protocol
    # markers used to be spliced into strings as raw ASCII-8BIT bytes
    # (lib/main/main.rb's $link_highlight_start etc., before this fix).
    # Combining that with real server text broke two ways depending on
    # the text: raised Encoding::CompatibilityError for non-ASCII text,
    # or silently mangled the marker byte to "?" for ASCII-only text.
    # WIZARD_LINK_START etc. are Private Use Area code points precisely
    # so this combination is always just... valid UTF-8, no special
    # casing needed at the splice site.

    it 'does not raise when a marker is combined with real non-ASCII text (regression: previously Encoding::CompatibilityError)' do
      combined = "#{described_class::WIZARD_SPEECH_START}chest\u2019s words#{described_class::WIZARD_SPEECH_END}" # rubocop:disable Custom/AsciiOnlySource
      expect { described_class.encode(combined) }.not_to raise_error
    end

    it 'encodes a marker plus non-ASCII text to the correct wire bytes, both marker and text intact' do
      combined = "#{described_class::WIZARD_SPEECH_START}chest\u2019s words#{described_class::WIZARD_SPEECH_END}" # rubocop:disable Custom/AsciiOnlySource
      # \x8A = speech start marker byte, \x92 = correctly-transcoded curly
      # apostrophe, \xA0 = speech end marker byte.
      expect(described_class.encode(combined)).to eq("\x8Achest\x92s words\xA0".b) # rubocop:disable Custom/AsciiOnlySource
    end

    it 'preserves the marker byte for ASCII-only text (regression: previously silently became "?")' do
      combined = "#{described_class::WIZARD_SPEECH_START}hello there#{described_class::WIZARD_SPEECH_END}"
      result = described_class.encode(combined)
      expect(result.bytes.first).to eq(0x8A)
      expect(result.bytes.first).not_to eq(63) # not "?"
    end

    it 'encodes the link markers to their correct wire bytes' do
      combined = "#{described_class::WIZARD_LINK_START}a room description#{described_class::WIZARD_LINK_END}"
      result = described_class.encode(combined)
      expect(result.bytes.first).to eq(0x87)
      expect(result.bytes.last).to eq(0xA0)
    end
  end

  describe 'round-trip' do
    it 'decode(encode(text)) restores common typographic punctuation' do
      original = "chest\u2019s lid opens\u2014slowly\u2026" # rubocop:disable Custom/AsciiOnlySource
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
