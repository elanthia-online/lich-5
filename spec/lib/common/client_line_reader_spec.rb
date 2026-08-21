# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/common/client_line_reader'

RSpec.describe Lich::Common::ClientLineReader do
  # A minimal double standing in for $_CLIENT_/SynchronizedSocket -- only
  # #gets is needed, matching exactly what ClientLineReader.read calls.
  let(:fake_client) { double('client') }

  describe '.read' do
    it 'decodes raw Windows-1252 bytes from #gets to a valid UTF-8 string (regression: the actual $_CLIENT_.gets -> decode boundary)' do
      # 0x92 = right single quotation mark on the wire -- this is what a
      # real frontend sends for a typed curly apostrophe.
      allow(fake_client).to receive(:gets).and_return("say chest\x92s lid\r\n".b) # rubocop:disable Custom/AsciiOnlySource
      result = described_class.read(fake_client)
      expect(result).to eq("say chest\u2019s lid\r\n") # rubocop:disable Custom/AsciiOnlySource
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

      expect(lines).to eq(["first\r\n", "second\u2019s\r\n"]) # rubocop:disable Custom/AsciiOnlySource
    end

    it 'does not raise on a raw byte that would be invalid if merely tagged as UTF-8 (the original bug this whole fix addresses)' do
      allow(fake_client).to receive(:gets).and_return("chest\x94 nice.\r\n".b) # rubocop:disable Custom/AsciiOnlySource
      expect { described_class.read(fake_client) }.not_to raise_error
    end
  end
end
