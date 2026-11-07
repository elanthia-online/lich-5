# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Remix Script/Trace.cs: a 20-entry ring printed oldest first (PrintTrace, Script.cs:1901-1905 R).
RSpec.describe Lich::Genie::Trace do
  it 'formats file and row like Trace.Add (Trace.cs:84-112 R)' do
    trace = described_class.new
    trace.add('goto a', '', 12)
    trace.add('gosub b', 'inc.cmd', 3)
    trace.add('action goto', 'inc.cmd', 0)
    trace.add('match c')
    expect(trace.to_s).to eq("\tgoto a (12)\n\tgosub b inc.cmd(3)\n\taction goto inc.cmd\n\tmatch c\n")
  end

  it 'keeps the last entries of a full ring, oldest first, and an empty one prints nothing' do
    trace = described_class.new(3)
    expect(trace.to_s).to eq('')
    %w[a b c d e].each { |v| trace.add(v) }
    expect(trace.to_s).to eq("\tc\n\td\n\te\n")
  end

  it 'clears the entries but keeps its position (Trace.Clear)' do
    trace = described_class.new(3)
    %w[a b].each { |v| trace.add(v) }
    trace.clear
    trace.add('z')
    expect(trace.to_s).to eq("\tz\n")
  end
end
