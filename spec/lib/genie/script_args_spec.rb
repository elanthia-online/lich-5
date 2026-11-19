# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Genie script-launch arguments + shift (Remix v4.2.4): ParseArgs(".name args", true)
# (FormMain.cs:4683 R, Utility.cs:390-517 R), LoadFile(al) seeding (Script.cs:2064-2082 R)
# and EvalShift (Script.cs:3003-3027 R). Expected values were checked against the real
# Remix code: genieoracle `parseargs_` and genieflow t57-t63 (flow_parity_spec).
RSpec.describe Lich::Genie::ScriptArgs do
  let(:vars) { Lich::Genie::Variables.new }

  def locals(*keys) = keys.to_h { |key| [key, vars.local_get(key)] }

  describe '.parse_launch' do
    it 'groups a quoted argument and turns underscores into spaces (first argument included)' do
      expect(described_class.parse_launch('holy', '"two words" c_d')).to eq(['two words', 'c d'])
      expect(described_class.parse_launch('x', 'a_b')).to eq(['a b'])
    end

    it 'never underscore-expands the script name it rebuilds (only arguments come back)' do
      expect(described_class.parse_launch('my_script', 'a_b')).to eq(['a b'])
    end

    it 'unwraps braces and single quotes, keeping the content underscore-expanded' do
      expect(described_class.parse_launch('x', "{e_f g} 'h_i'")).to eq(['e f g', 'h i'])
    end

    it 'keeps an empty quoted argument as an empty string' do
      expect(described_class.parse_launch('x', 'a "" c')).to eq(['a', '', 'c'])
    end

    it 'keeps an unterminated quote and an escaped space verbatim' do
      expect(described_class.parse_launch('x', '"a b')).to eq(['"a b'])
      expect(described_class.parse_launch('x', 'a\\ b')).to eq(['a\\ b'])
    end

    it 'collapses runs of spaces and ignores leading/trailing blanks' do
      expect(described_class.parse_launch('x', '  a   b  ')).to eq(%w[a b])
    end

    it 'returns no arguments for nil, "", blanks and an empty Array' do
      [nil, '', '   ', []].each { |cli| expect(described_class.parse_launch('x', cli)).to eq([]) }
    end

    it 'joins an Array with spaces before parsing (Lich start_script passes words)' do
      expect(described_class.parse_launch('x', ['"two', 'words"', 'c_d'])).to eq(['two words', 'c d'])
    end

    it 'does not treat a leading "quiet" word as a Lich flag (Remix has no such convention)' do
      expect(described_class.parse_launch('x', 'quiet foo')).to eq(%w[quiet foo])
    end

    it 'raises with the rebuilt launch text on a lone quote, like Remix RunScript' do
      expect { described_class.parse_launch('t15', '"') }
        .to raise_error(Lich::Genie::Error, 'Invalid string in Parse Arguments: .t15 "')
    end

    # Lich can resolve a file whose name Genie could never type as one token (its prefix
    # resolver matches `pc{1}.cmd`, `my script.cmd`); the name must not leak into al[1..].
    it 'does not let ParseArgs metacharacters in the script name change the arguments' do
      ['pc{1}', 'my script', 'a"b', 'x\\', "x\\ ", '{', '_'].each do |name|
        expect(described_class.parse_launch(name, 'a "b c" d_e')).to eq(['a', 'b c', 'd e']), name.inspect
        expect(described_class.parse_launch(name, '')).to eq([]), name.inspect
      end
    end

    it 'still names the real script in the malformed-string error' do
      expect { described_class.parse_launch('my script', 'a "') }
        .to raise_error(Lich::Genie::Error, 'Invalid string in Parse Arguments: .my script a "')
    end
  end

  describe '.split_launch' do
    # Name = ParseArgs token al[0], lower-cased, Trim'd, minus the script char
    # (FormMain.cs:4683-4684 R); the raw rest is what parse_launch re-tokenizes.
    {
      '.helper foo bar' => ['helper', 'foo bar'],
      '.setup'          => ['setup', ''],
      '._pc{a_b} c'     => ['_pc', '{a_b} c'],     # t66: a depth-0 { ends the name
      '._PC up_per'     => ['_pc', 'up_per'],      # t66: lower-cased like Remix
      '.x{y}{z} "q r"'  => ['x', '{y}{z} "q r"'],
      '.a\ b c'         => ['a\ b', 'c'], # an escaped space does not end it
      '.a"b c" d'       => ['a"b c"', 'd'],        # nor does a space inside a "string"
      '.x}{y} z'        => ['x}{y} z', ''],        # stray } : depth never returns to 0
      ".tab\t"          => ['tab', ''], # C# Trim on the name
      '.'               => ['', ''],
      '.a   b'          => ['a', '  b']
    }.each do |row, expected|
      it "splits #{row.inspect} into #{expected.inspect}" do
        expect(described_class.split_launch(row)).to eq(expected)
      end
    end

    it 'round-trips: parse_launch(name, rest) == ParseArgs(row, true)[1..], errors included (random rows)' do
      rng = Random.new(20_261_018)
      alphabet = ['a', 'B', '_', ' ', ' ', '"', "'", '{', '}', '\\', '.']
      600.times do
        row = ".#{Array.new(rng.rand(0..14)) { alphabet[rng.rand(alphabet.length)] }.join}"
        name, rest = described_class.split_launch(row)
        full = begin
          Lich::Genie::Text.parse_args(row, treat_underscore_as_space: true)
        rescue Lich::Genie::Error
          :error
        end
        ours = begin
          described_class.parse_launch('n', rest)
        rescue Lich::Genie::Error
          :error
        end
        expect(ours).to eq(full == :error ? :error : full.drop(1)), "row #{row.inspect}"
        next if full == :error

        expect(name).to eq(full.first.downcase.strip[1..].to_s), "row #{row.inspect}"
      end
    end
  end

  describe '.seed' do
    it 'seeds %1..%9 empty, %0 empty and %argcount 0 with no arguments' do
      described_class.seed(vars, [])
      expect(locals('0', '1', '9', 'argcount')).to eq('0' => '', '1' => '', '9' => '', 'argcount' => '0')
      expect(vars.local_key?('10')).to be(false)
    end

    it 'treats nil like no arguments' do
      described_class.seed(vars, nil)
      expect(locals('1', 'argcount')).to eq('1' => '', 'argcount' => '0')
    end

    it 'overlays given arguments and blanks the rest up to 9' do
      described_class.seed(vars, ['p x', 'q r'])
      expect(locals('0', '1', '2', '3', '9', 'argcount'))
        .to eq('0' => 'p x q r', '1' => 'p x', '2' => 'q r', '3' => '', '9' => '', 'argcount' => '2')
    end

    it 'keeps an inner empty argument as a double space in %0 but trims trailing blanks' do
      described_class.seed(vars, ['a', '', 'c'])
      expect(vars.local_get('0')).to eq('a  c')
      described_class.seed(vars, ['a', ''])
      expect(locals('0', 'argcount')).to eq('0' => 'a', 'argcount' => '2')
    end

    it 'keeps leading blanks in %0 (TrimEnd only)' do
      described_class.seed(vars, ['', 'b'])
      expect(vars.local_get('0')).to eq(' b')
    end

    it 'seeds keys above 9 only when that many arguments were given' do
      args = (1..11).map { |i| "a#{i}" }
      described_class.seed(vars, args)
      expect(locals('9', '10', '11', 'argcount')).to eq('9' => 'a9', '10' => 'a10', '11' => 'a11', 'argcount' => '11')
      expect(vars.local_key?('12')).to be(false)
    end

    it 'stringifies non-String arguments' do
      described_class.seed(vars, [1, :b])
      expect(locals('0', '1', '2')).to eq('0' => '1 b', '1' => '1', '2' => 'b')
    end
  end

  describe '.shift' do
    it 'drops %1, moves the rest down, blanks the old last slot and rebuilds %0' do
      described_class.seed(vars, %w[x y z])
      described_class.shift(vars)
      expect(locals('0', '1', '2', '3', 'argcount')).to eq('0' => 'y z', '1' => 'y', '2' => 'z', '3' => '', 'argcount' => '2')
    end

    it 'skips empty values when rebuilding %0 (t57: a "" c -> shift -> %0 "c")' do
      described_class.seed(vars, ['a', '', 'c'])
      described_class.shift(vars)
      expect(locals('0', '1', '2', 'argcount')).to eq('0' => 'c', '1' => '', '2' => 'c', 'argcount' => '2')
    end

    it 'skips an EMPTY value in the middle when rebuilding %0 (t65: a b "" d -> "b d", not "b  d")' do
      described_class.seed(vars, ['a', 'b', '', 'd'])
      described_class.shift(vars)
      expect(locals('0', '1', '2', '3', '4', 'argcount')).to eq('0' => 'b d', '1' => 'b', '2' => '', '3' => 'd', '4' => '', 'argcount' => '3')
    end

    it 'skips empty values on both ends and between (t65: "" a "" b "" -> "a b")' do
      described_class.seed(vars, ['', 'a', '', 'b', ''])
      described_class.shift(vars)
      expect(locals('0', '1', '2', '3', '4', 'argcount')).to eq('0' => 'a b', '1' => 'a', '2' => '', '3' => 'b', '4' => '', 'argcount' => '4')
    end

    it 'keeps a multi-word argument whole' do
      described_class.seed(vars, ['p x', 'q r', 's t'])
      described_class.shift(vars)
      expect(locals('0', '1', '2')).to eq('0' => 'q r s t', '1' => 'q r', '2' => 's t')
    end

    it 'empties everything on the last shift and is a no-op at %argcount 0' do
      described_class.seed(vars, %w[only])
      described_class.shift(vars)
      expect(locals('0', '1', 'argcount')).to eq('0' => '', '1' => '', 'argcount' => '0')
      described_class.shift(vars)
      expect(locals('0', '1', 'argcount')).to eq('0' => '', '1' => '', 'argcount' => '0')
    end

    it 'leaves locals above %argcount alone (the loop runs from %argcount down)' do
      described_class.seed(vars, %w[a b])
      vars.local_set('5', 'kept')
      described_class.shift(vars)
      expect(locals('1', '2', '5')).to eq('1' => 'b', '2' => '', '5' => 'kept')
    end

    it 'follows a script-assigned %argcount, including a negative one (no-op)' do
      described_class.seed(vars, %w[a b c])
      vars.local_set('argcount', '1')
      described_class.shift(vars)
      expect(locals('0', '1', '2', 'argcount')).to eq('0' => '', '1' => '', '2' => 'b', 'argcount' => '0')
      vars.local_set('argcount', '-3')
      expect { described_class.shift(vars) }.not_to(change { locals('0', '1', 'argcount') })
    end

    it 'rounds a decimal %argcount half-to-even like Conversions.ToInteger' do
      described_class.seed(vars, %w[a b c])
      vars.local_set('argcount', '2.5')
      described_class.shift(vars)
      expect(locals('1', '2', '3', 'argcount')).to eq('1' => 'b', '2' => '', '3' => 'c', 'argcount' => '1')
    end

    it 'raises on a non-numeric %argcount without touching the locals (C# throws first)' do
      described_class.seed(vars, %w[a b])
      vars.local_set('argcount', 'abc')
      expect { described_class.shift(vars) }.to raise_error(Lich::Genie::Error, /not valid/)
      expect(locals('1', 'argcount')).to eq('1' => 'a', 'argcount' => 'abc')
    end

    it 'is a no-op when %argcount is missing (unvar argcount: null -> ToInteger(Nothing) = 0, t64)' do
      described_class.seed(vars, %w[a b c])
      vars.local_delete('argcount')
      expect { described_class.shift(vars) }.not_to(change { locals('0', '1', '2', '3', 'argcount') })
      expect(locals('0', '1', 'argcount')).to eq('0' => 'a b c', '1' => 'a', 'argcount' => nil)
    end

    it 'is a no-op on a store that was never seeded' do
      expect { described_class.shift(vars) }.not_to raise_error
      expect(locals('0', '1', 'argcount')).to eq('0' => nil, '1' => nil, 'argcount' => nil)
    end

    it 'converts %argcount with the VB grammar: &H hex and thousands separators shift (t67)' do
      described_class.seed(vars, %w[a b c])
      vars.local_set('argcount', '&H2')
      described_class.shift(vars)
      expect(locals('0', '1', '2', '3', 'argcount')).to eq('0' => 'b', '1' => 'b', '2' => '', '3' => 'c', 'argcount' => '1')
      vars.local_set('argcount', '1,')
      described_class.shift(vars)
      expect(locals('0', '1', 'argcount')).to eq('0' => '', '1' => '', 'argcount' => '0')
    end

    it 'treats a parenthesised %argcount as negative (VB "(1)" = -1): no-op (t67)' do
      described_class.seed(vars, %w[a b])
      vars.local_set('argcount', '(1)')
      expect { described_class.shift(vars) }.not_to(change { locals('0', '1', '2', 'argcount') })
    end

    ['0x2', '1_0', '', ' ', 'Infinity'].each do |bad|
      it "raises InvalidCast text on #{bad.inspect}, which Ruby Float() or a blank would mis-take" do
        described_class.seed(vars, %w[a b])
        vars.local_set('argcount', bad)
        expect { described_class.shift(vars) }
          .to raise_error(Lich::Genie::Error, "Conversion from string \"#{bad}\" to type 'Integer' is not valid.")
        expect(locals('1', 'argcount')).to eq('1' => 'a', 'argcount' => bad)
      end
    end

    it 'raises the .NET overflow text on NaN and beyond Int32 (checked cast)' do
      described_class.seed(vars, %w[a])
      %w[NaN 2147483648 &HFFFFFFFF].each do |big|
        vars.local_set('argcount', big)
        expect { described_class.shift(vars) }.to raise_error(Lich::Genie::Error, 'Arithmetic operation resulted in an overflow.')
      end
    end

    it 'raises when a slot below %argcount was removed with unvar (no %argcount assignment involved)' do
      described_class.seed(vars, %w[a b c])
      vars.local_delete('2')
      expect { described_class.shift(vars) }.to raise_error(Lich::Genie::Error, 'Object reference not set to an instance of an object.')
    end

    it 'raises when a slot below %argcount is missing, after the C# side effects' do
      described_class.seed(vars, %w[a b])
      vars.local_set('argcount', '11')
      expect { described_class.shift(vars) }.to raise_error(Lich::Genie::Error, 'Object reference not set to an instance of an object.')
      # EvalShift already wrote %argcount and %11 before the null dereference.
      expect(locals('argcount', '11', '10', '1')).to eq('argcount' => '10', '11' => '', '10' => nil, '1' => 'a')
    end
  end
end
