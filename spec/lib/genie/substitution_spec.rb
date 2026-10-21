# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Substitution do
  subject(:substitution) { described_class.new(variables: variables, specials: specials) }

  let(:variables) do
    v = Lich::Genie::Variables.new(game_state: { 'health' => '100' })
    v.local_set('name', 'Grocha')
    v.local_set('list', 'a|b|c')
    v.local_set('foo', 'X')
    v.global_set('gold', '500')
    v
  end

  let(:specials) do
    Lich::Genie::Specials.new(clock: -> { Time.new(2026, 8, 18, 14, 5, 9) }, timer: -> { '42' })
  end

  describe 'local (%) and global ($) variables' do
    it 'expands local variables' do
      expect(substitution.expand('%name says hi')).to eq('Grocha says hi')
    end

    it 'expands global variables from the store and from game state' do
      expect(substitution.expand('You have $gold coins')).to eq('You have 500 coins')
      expect(substitution.expand('hp is $health')).to eq('hp is 100')
    end

    it 'leaves undefined variables literally in place' do
      expect(substitution.expand('%unknown here')).to eq('%unknown here')
    end

    it 'matches the longest defined prefix of an identifier' do
      # 'foobar' is undefined but 'foo' is defined -> 'X' + 'bar'
      expect(substitution.expand('%foobar')).to eq('Xbar')
    end
  end

  describe 'array and .length forms' do
    it 'accesses a pipe-delimited element by 0-based index' do
      expect(substitution.expand('%list(1)')).to eq('b')
    end

    it 'reports element count via .length' do
      expect(substitution.expand('%list.length')).to eq('3')
    end

    # int.TryParse (Script.cs:2391, Globals.cs:269 R). Golden: genieflow
    # t90_array_index_tryparse.
    it 'parses the index like int.TryParse: a sign is fine, an Int32 overflow is no index' do
      expect(substitution.expand('[%list(+1)] [%list(-0)] [%list(3)] [%list(-1)]')).to eq('[b] [a] [] []')
      expect(substitution.expand('[%list(2147483648)] [%list(1x)]')).to eq('[a|b|c(2147483648)] [a|b|c(1x)]')
      variables.global_set('gl', 'x|y|z')
      expect(substitution.expand('[$gl(+1)] [$gl(3)] [$gl(99999999999)]')).to eq('[y] [x|y|z(3)] [x|y|z(99999999999)]')
    end
  end

  describe 'right-to-left, single-level expansion' do
    it 'does not re-scan the text a variable expands into' do
      variables.local_set('a', '%b')
      variables.local_set('b', 'DEEP')
      expect(substitution.expand('%a')).to eq('%b')
    end
  end

  describe '$-argument substitution' do
    it 'replaces $0 (full string) and numbered args' do
      args = ['spell target', 'spell', 'target']
      expect(substitution.expand('do $0', args: args)).to eq('do spell target')
      expect(substitution.expand('cast $1 at $2', args: args)).to eq('cast spell at target')
    end

    it 'replaces $argcount with the token count' do
      expect(substitution.expand('n=$argcount', args: ['a b', 'a', 'b'])).to eq('n=2')
    end

    it 'gives $argcount -1 and blank $0..$9 for an empty arg list (Count - 1, Script.cs:2289-2299 R)' do
      expect(substitution.expand('n=$argcount [$0] [$1] [$9]', args: [])).to eq('n=-1 [] [] []')
    end

    it 'gives $argcount 0 for a $0-only list (a matchre with no groups)' do
      expect(substitution.expand('n=$argcount [$0]', args: ['whole'])).to eq('n=0 [whole]')
    end

    it 'reproduces the naive "$1 hits $10" quirk' do
      # low-to-high Replace means "$1" is substituted before "$10"
      expect(substitution.expand('$10', args: ['', 'ONE'])).to eq('ONE0')
    end

    # Config.iArgumentCount = 15 (Config.cs:18 R): $0..$14, so a $1n produced by an earlier
    # replacement is still replaced; $15 is not (flow t117: Remix echoes "[] [a3] [a4x]").
    it 'replaces $0..$14 (iArgumentCount 15), reaching a $12 that $2 produced but not $15' do
      args = ['a $1 c', 'a', '$1', 'c']
      expect(substitution.expand('[$22] [$13] [$14x]', args: args)).to eq('[] [a3] [a4x]')
      expect(substitution.expand('[$24] [$25]', args: ['x', 'y', '$1'])).to eq('[] [$15]') # $14 blank, $15 kept
    end

    # String.Replace is literal: a backslash sequence in the value is not a backreference.
    it 'inserts a value holding \\0, \\& or \\\\ verbatim' do
      expect(substitution.expand('x=$1', args: ['all', 'a\\0b\\&c\\\\d'])).to eq('x=a\\0b\\&c\\\\d')
    end
  end

  describe 'escaping' do
    it 'treats \\% as a literal percent' do
      expect(substitution.expand('100\% done')).to eq('100% done')
    end
  end

  describe '@-special variables' do
    it 'expands date/time specials and the timer' do
      expect(substitution.expand('t=@time24@')).to eq('t=14:05:09 PM') # "HH:mm:ss tt"
      expect(substitution.expand('elapsed @timer@')).to eq('elapsed 42')
    end
  end

  # Globals.ParseGlobalVars (Globals.cs:150-202 R), used by #parse and the flow
  # harness INPUT model.
  describe '#expand_globals' do
    it 'expands $globals but leaves %locals, \\% and the $0..$9 args alone' do
      expect(substitution.expand_globals('%name has $gold $1 \\%name')).to eq('%name has 500 $1 \\%name')
    end

    it 'treats \\$ as an escaped literal $ (backslash removed)' do
      expect(substitution.expand_globals('cost \\$gold')).to eq('cost $gold')
    end

    it 'is single-level: a value holding $other is not expanded again' do
      variables.global_set('indirect', '$gold')
      expect(substitution.expand_globals('$indirect')).to eq('$gold')
    end

    it 'replaces the @specials of ParseSpecialVariables but not the script-only @timer@' do
      expect(substitution.expand_globals('@unixtime@ @timer@')).to eq("#{Time.new(2026, 8, 18, 14, 5, 9).to_i} @timer@")
    end

    it 'leaves an undefined $name literal' do
      expect(substitution.expand_globals('$nosuchvar x')).to eq('$nosuchvar x')
    end
  end
end
