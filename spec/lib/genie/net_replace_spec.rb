# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Lich::Genie::NetReplace: .NET Regex.Replace's replacement language (RegexReplacement), shared by
# Eval's replacere() (Eval.cs:1195-1209 R) and the display substitutes (Game.cs:3173-3206 R).
RSpec.describe Lich::Genie::NetReplace do
  def replace(pattern, subject, replacement)
    described_class.replace(Lich::Genie::NetRegex.compile(pattern), subject, replacement)
  end

  it 'returns nil when nothing matches (Regex.Replace hands back the input instance)' do
    expect(replace('zzz', 'abc', 'x')).to be_nil
  end

  it 'expands $$ $& $` $\' $_ $+ ${n} ${name} and the maximal $digits' do
    expect(replace('(b)(c)', 'abcd', "[$$|$&|$`|$'|$_|$+|${1}x|$2]")).to eq("a[$|bc|a|d|abcd|c|bx|c]d")
    expect(replace('(?<w>b)', 'abc', '<${w}>')).to eq('a<b>c')
    expect(replace('(b)', 'abc', '$10')).to eq('a$10c') # group 10 does not exist: literal
    expect(replace('(b)', 'abc', '$1$')).to eq('ab$c')
    expect(replace('(b)', 'abc', '${2}${zz}$x')).to eq('a${2}${zz}$xc')
  end

  it 'walks an emulated lookbehind match by match and advances past an empty match' do
    expect(replace('(?<=a+)b', 'aab xb ab', '#')).to eq('aa# xb a#')
    expect(replace('x*', 'ab', '-')).to eq('-a-b-')
  end
end
