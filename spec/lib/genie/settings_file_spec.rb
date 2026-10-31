# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

# Remix Config.Load (Lists/Config.cs:531-565 R): ParseArgs each line, exactly three args
# set oArgs[1] = oArgs[2], anything else (or a row ParseArgs throws on) is skipped.
RSpec.describe Lich::Genie::SettingsFile do
  def read(text)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'settings.cfg')
      File.binwrite(path, text)
      described_class.read(path)
    end
  end

  it "returns [key, value] pairs in file order from a tester's settings rows" do
    path = File.expand_path('../../fixtures/genie/game_state/tester_settings_excerpt.cfg', __dir__)
    pairs = described_class.read(path)
    expect(pairs.first).to eq(%w[autolog False])
    expect(pairs.assoc('prompt')).to eq(['prompt', '> '])
    expect(pairs.assoc('roundtimeoffset')).to eq(%w[roundtimeoffset 0])
    expect(pairs.length).to eq(16)
  end

  it 'skips rows without exactly three arguments and rows ParseArgs throws on' do
    expect(read(%(#config {a} {1}\r\n#config {b}\r\n#config {c} {2} {3}\r\nnoise\r\n#config {'} {x}\r\n#config {d} {}\r\n)))
      .to eq([%w[a 1], ['d', '']])
  end

  it 'is empty for a missing file' do
    expect(described_class.read('/nonexistent/settings.cfg')).to eq([])
    expect(described_class.read(nil)).to eq([])
  end
end
