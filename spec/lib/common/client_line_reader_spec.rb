# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/common/client_line_reader'

RSpec.describe Lich::Common::ClientLineReader do
  # A minimal double standing in for $_CLIENT_/SynchronizedSocket -- only
  # #gets is needed, matching exactly what ClientLineReader.read calls.
  let(:fake_client) { double('client') }

  around do |example|
    original_frontend = $frontend
    example.run
    $frontend = original_frontend
  end

  describe '.read' do
    context 'when the frontend is unknown/unregistered (the default -- also --pipe with no --frontend given)' do
      before { $frontend = nil }

      it 'decodes raw Windows-1252 bytes from #gets to a valid UTF-8 string (regression: the actual $_CLIENT_.gets -> decode boundary)' do
        # 0x92 = right single quotation mark on the wire -- this is what a
        # real frontend sends for a typed curly apostrophe.
        allow(fake_client).to receive(:gets).and_return("say chest\x92s lid\r\n".b) # rubocop:disable Custom/AsciiOnlySource
        result = described_class.read(fake_client)
        expect(result).to eq("say chest’s lid\r\n") # rubocop:disable Custom/AsciiOnlySource
        expect(result.encoding).to eq(Encoding::UTF_8)
        expect(result.valid_encoding?).to be true
      end

      it 'passes plain ASCII input through unchanged' do
        allow(fake_client).to receive(:gets).and_return('look')
        expect(described_class.read(fake_client)).to eq('look')
      end

      it 'returns nil when #gets returns nil (client disconnected), matching #gets itself rather than raising' do
        allow(fake_client).to receive(:gets).and_return(nil)
        expect(described_class.read(fake_client)).to be_nil
      end

      it 'is safe to use directly as a while-loop condition, terminating on nil exactly like #gets would' do
        responses = ["first\r\n".b, "second\x92s\r\n".b, nil] # rubocop:disable Custom/AsciiOnlySource
        allow(fake_client).to receive(:gets) { responses.shift }

        lines = []
        while (line = described_class.read(fake_client))
          lines << line
        end

        expect(lines).to eq(["first\r\n", "second’s\r\n"]) # rubocop:disable Custom/AsciiOnlySource
      end

      it 'does not raise on a raw byte that would be invalid if merely tagged as UTF-8 (the original bug this whole fix addresses)' do
        allow(fake_client).to receive(:gets).and_return("chest\x94 nice.\r\n".b) # rubocop:disable Custom/AsciiOnlySource
        expect { described_class.read(fake_client) }.not_to raise_error
      end

      it 'treats bytes that would also validate as UTF-8 as CP1252 instead (regression: CodeRabbit-flagged ambiguity -- raw CP1252 bytes 0xC3 0xA9 are a legitimate two-character string, which must not be silently reinterpreted as the single accented character it also happens to spell in UTF-8)' do
        allow(fake_client).to receive(:gets).and_return("caf\xC3\xA9\r\n".b) # rubocop:disable Custom/AsciiOnlySource
        result = described_class.read(fake_client)
        expect(result).to eq("cafÃ©\r\n") # rubocop:disable Custom/AsciiOnlySource
      end
    end

    context 'when the frontend is registered utf8_input (ProfanityFE)' do
      before { $frontend = 'profanity' }

      it 'passes already-UTF-8 frontend input through untouched instead of double-decoding it as Windows-1252 (regression: a terminal-based frontend like ProfanityFE, which forwards its terminal locale rather than pre-encoding to CP1252 the way Wizard/StormFront/Saga do)' do
        # U+2019 (real right single quotation mark), sent as genuine UTF-8 bytes
        # rather than the single CP1252 byte 0x92 a legacy client would send.
        allow(fake_client).to receive(:gets).and_return("say chest’s lid\r\n") # rubocop:disable Custom/AsciiOnlySource
        result = described_class.read(fake_client)
        expect(result).to eq("say chest’s lid\r\n") # rubocop:disable Custom/AsciiOnlySource
        expect(result.encoding).to eq(Encoding::UTF_8)
      end

      it 'scrubs invalid UTF-8 rather than raising, on a genuinely corrupt/truncated read' do
        allow(fake_client).to receive(:gets).and_return("chest\x92s lid\r\n".b) # rubocop:disable Custom/AsciiOnlySource
        result = nil
        expect { result = described_class.read(fake_client) }.not_to raise_error
        expect(result.valid_encoding?).to be true
      end
    end
  end
end
