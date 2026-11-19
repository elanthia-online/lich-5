# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

# Lich::Genie::NameList: the keys of Remix's Lists/Names.cs (R) and its RebuildIndex fault
# (genieflow: `#name red {bad[}` -> "Invalid pattern '\b(bad[)\b' at offset 10.
# Unterminated [] set.", and every later #name until #unname).
RSpec.describe Lich::Genie::NameList do
  subject(:names) { described_class.new }

  it 'builds \b(<keys in culture order>)\b, "" when empty, skipping empty keys' do
    expect(names.index_pattern).to eq('')
    names.add(['Bob', '', 'al', 'Zed'])
    expect(names.keys).to eq(%w[al Bob Zed])
    expect(names.index_pattern).to eq('\b(al|Bob|Zed)\b')
  end

  it 'raises with the index pattern when a key breaks it, keeping the key (Add runs before RebuildIndex)' do
    expect { names.add(['bad[']) }.to raise_error(Lich::Genie::Error, /\AInvalid pattern '\\b\(bad\[\)\\b'\. /)
    expect { names.add(['x']) }.to raise_error(Lich::Genie::Error)
    names.remove(['bad['])
    expect { names.add(['y']) }.not_to raise_error
    expect(names.keys).to eq(%w[x y])
  end

  it 'accepts keys that are regex text when the whole index is valid (a name is a pattern in Remix)' do
    expect { names.add(['a.b', '(x)']) }.not_to raise_error
  end

  it 'loads only three-token rows, merges, and faults after a load that breaks the index' do
    Dir.mktmpdir('genie-names') do |dir|
      path = File.join(dir, 'names.cfg')
      File.write(path, "#name {red} {Bob}\n#name Al\n#name {a} {b} {c}\n")
      names.add(['Zed'])
      expect(names.load(path)).to be(true)
      expect(names.keys).to eq(%w[Bob Zed])
      File.write(path, "#name {red} {(}\n")
      expect { names.load(path) }.to raise_error(Lich::Genie::Error, /Invalid pattern/)
      expect(names.keys).to include('(')
      expect(names.load(File.join(dir, 'missing.cfg'))).to be(false)
      expect(names.load(nil)).to be(false)
    end
  end

  it 'clears without rebuilding (a broken list empties fine)' do
    expect { names.add(['[']) }.to raise_error(Lich::Genie::Error)
    names.clear
    expect(names.keys).to eq([])
  end
end
