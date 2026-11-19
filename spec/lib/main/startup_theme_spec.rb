# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/main/startup_theme'

RSpec.describe Lich::Main::StartupTheme do
  before do
    allow(Lich).to receive(:track_dark_mode=)
  end

  it 'applies a persisted dark preference when no override is supplied' do
    allow(Lich).to receive(:track_dark_mode).and_return(true)

    expect(described_class.apply({})).to be true
    expect(Lich).not_to have_received(:track_dark_mode=)
  end

  it 'applies a persisted light preference when no override is supplied' do
    allow(Lich).to receive(:track_dark_mode).and_return(false)

    expect(described_class.apply({})).to be false
    expect(Lich).not_to have_received(:track_dark_mode=)
  end

  it 'persists and applies an explicit dark preference' do
    expect(described_class.apply(dark_mode: true)).to be true
    expect(Lich).to have_received(:track_dark_mode=).with(true)
  end

  it 'persists and applies an explicit light preference' do
    expect(described_class.apply(dark_mode: false)).to be false
    expect(Lich).to have_received(:track_dark_mode=).with(false)
  end

  it 'preserves the preference in a headless process' do
    expect(described_class.apply(dark_mode: true)).to be true
    expect(Lich).to have_received(:track_dark_mode=).with(true)
  end

  it 'rejects invalid options and theme values' do
    expect { described_class.apply(nil) }.to raise_error(ArgumentError, 'argv_options must be a Hash')
    expect { described_class.apply(dark_mode: nil) }.to raise_error(ArgumentError, 'dark_mode must be true or false')
  end
end
