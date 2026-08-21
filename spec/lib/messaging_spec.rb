# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/messaging'

RSpec.describe Lich::Messaging do
  describe '.msg_format' do
    # These three branches ("warn"/"info"/"green") are the only ones
    # reachable without global_defs.rb's monsterbold_start/_end or
    # sf_to_wiz, so encode: false is used throughout to isolate the
    # Wizard/GSL color-marker logic under test without pulling in that
    # larger dependency chain.
    before do
      allow(Frontend).to receive(:supports_xml?).and_return(false)
      allow(Frontend).to receive(:supports_gsl?).and_return(true)
    end

    it 'wraps "info" text in the correct Wizard color marker code points (regression: previously a raw ASCII-8BIT byte)' do
      result = described_class.msg_format('info', 'hello there', encode: false)
      expect(result).to eq(
        "#{Lich::Common::WireEncoding::WIZARD_COLOR_START['teal']}hello there#{Lich::Common::WireEncoding::WIZARD_COLOR_END}"
      )
    end

    it 'does not raise when the message contains real non-ASCII text (regression: previously Encoding::CompatibilityError)' do
      expect { described_class.msg_format('info', "chest\u2019s words", encode: false) }.not_to raise_error # rubocop:disable Custom/AsciiOnlySource
    end

    it 'produces text that WireEncoding.encode turns into correct wire bytes, marker and text both intact' do
      result = described_class.msg_format('green', "chest\u2019s words", encode: false) # rubocop:disable Custom/AsciiOnlySource
      wire = Lich::Common::WireEncoding.encode(result)
      # \x8A = bright green start marker, \x92 = correctly-transcoded curly
      # apostrophe, \xA0 = color end marker.
      expect(wire).to eq("\x8Achest\x92s words\xA0".b) # rubocop:disable Custom/AsciiOnlySource
    end

    it 'uses a distinct marker per color (gold for warn, teal for info, bright green for speech)' do
      warn_result = described_class.msg_format('warn', 'x', encode: false)
      info_result = described_class.msg_format('info', 'x', encode: false)
      speech_result = described_class.msg_format('green', 'x', encode: false)

      expect(warn_result).to start_with(Lich::Common::WireEncoding::WIZARD_COLOR_START['gold'])
      expect(info_result).to start_with(Lich::Common::WireEncoding::WIZARD_COLOR_START['teal'])
      expect(speech_result).to start_with(Lich::Common::WireEncoding::WIZARD_COLOR_START['bright green'])
    end
  end
end
