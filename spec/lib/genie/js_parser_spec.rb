# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# The JavaScript slice the Jint 4 stand-in runs, and Acornima's syntax-error texts as Jint 4
# reports them. Every message/position below is Remix's (genieflow: frozen t229/t232 goldens and the
# probes p1/p6/p7).
RSpec.describe Lich::Genie::JsParser do
  js_error = Lich::Genie::JsRuntime::JsError
  unsupported = Lich::Genie::JsRuntime::Unsupported
  literal = described_class::Literal
  call = described_class::Call
  ref = described_class::Ref

  def parse(text) = described_class.parse(text)

  def value(text) = parse(text).first.value

  describe 'statements' do
    it 'parses calls with string, number and literal-word arguments' do
      expect(parse('doPush("arr", \'b\', 5, -1.5, true, null)'))
        .to eq([call.new('doPush', 1, 1, [literal.new('arr'), literal.new('b'), literal.new(5.0), literal.new(-1.5),
                                          literal.new(true), literal.new(Lich::Genie::JsValue::NULL)])])
    end

    it 'parses nested calls, identifiers, an empty and a trailing-comma argument list' do
      expect(parse('a(b(), c, d,)')).to eq([call.new('a', 1, 1, [call.new('b', 1, 3, []), ref.new('c', 1, 8), ref.new('d', 1, 11)])])
    end

    it 'separates statements by ; and by a line break before a token that cannot continue (ASI)' do
      expect(parse(%(;a();; "x"\nb()\n'y';)).map(&:class)).to eq([call, literal, call, literal])
    end

    it 'skips comments, a block comment with a line break counting as one' do
      expect(parse("/* c\n */ a() // tail\n/* x */ b()").map(&:name)).to eq(%w[a b])
      expect(parse('a() /* a comment ending the source */').map(&:name)).to eq(%w[a])
    end

    it 'is empty for blank text' do
      expect([parse(''), parse("  \n\t "), parse(';;')]).to eq([[], [], []])
    end
  end

  describe 'literals' do
    {
      '017' => 15.0, '08' => 8.0, '019' => 19.0, '0x1F' => 31.0, '0o17' => 15.0, '0B101' => 5.0, '1_000' => 1000.0,
      '.5' => 0.5, '5.' => 5.0, '1e3' => 1000.0, '1.5E-2' => 0.015, '0' => 0.0, '-0' => -0.0, '+3' => 3.0
    }.each do |text, number|
      it "reads #{text} as #{number}" do
        expect(value(text)).to eql(number)
      end
    end

    it 'decodes every string escape (t229 l14)' do
      expect(value(%q('it\'s \x41B\u{43}\101'))).to eq("it's ABCA")
      expect(value('"\\n\\r\\t\\b\\f\\v\\0\\8\\q\\"\\\\\\u0041"')).to eq("\n\r\t\b\f\v\u00008q\"\\A")
      expect(value('"\\101\\08\\400"')).to eq("A\u{0}8 0")
    end

    it 'joins a line continuation and replaces a lone surrogate' do
      expect(value("\"a\\\nb\"")).to eq('ab')
      expect(value('"\\uD800"')).to eq([0xFFFD].pack('U'))
    end
  end

  describe 'syntax errors (Acornima texts with <anonymous>:line:column)' do
    {
      'doPush("arr", "z'                  => 'Invalid or unexpected token (<anonymous>:1:15)',
      'doPush("arr",'                     => 'Unexpected end of input (<anonymous>:1:14)',
      'doPush("arr" "b")'                 => 'Unexpected string (<anonymous>:1:14)',
      'doPush("arr", 1 2)'                => 'Unexpected number (<anonymous>:1:17)',
      'doPush("arr", x y)'                => "Unexpected identifier 'y' (<anonymous>:1:17)",
      ')'                                 => "Unexpected token ')' (<anonymous>:1:1)",
      'setVar("a" ; "b")'                 => "Unexpected token ';' (<anonymous>:1:12)",
      'setVar("x", "a\x4")'               => 'Invalid hexadecimal escape sequence (<anonymous>:1:15)',
      'setVar("x", "a\u00")'              => 'Invalid Unicode escape sequence (<anonymous>:1:15)',
      "setVar(\"x\", \"a\\u{110000}\")"   => 'Undefined Unicode code-point (<anonymous>:1:15)',
      'setVar("x", 5abc)'                 => 'Invalid or unexpected token (<anonymous>:1:13)',
      'setVar("x", 0x)'                   => 'Invalid or unexpected token (<anonymous>:1:13)',
      'setVar("x", 1e)'                   => 'Invalid or unexpected token (<anonymous>:1:13)',
      'foo bar'                           => "Unexpected identifier 'bar' (<anonymous>:1:5)",
      'setVar("x", "y") setVar("z", "w")' => "Unexpected identifier 'setVar' (<anonymous>:1:18)",
      '"trail\\'                          => 'Invalid or unexpected token (<anonymous>:1:1)',
      'doPush('                           => 'Unexpected end of input (<anonymous>:1:8)',
      'doPush("a", "b"))'                 => "Unexpected token ')' (<anonymous>:1:17)",
      'setVar("cap2", "a\")'              => 'Invalid or unexpected token (<anonymous>:1:16)'
    }.each do |text, message|
      it "reports #{text.inspect} as #{message}" do
        expect { parse(text) }.to raise_error(js_error, message)
      end
    end

    it 'counts lines and columns inside a block (t232: the empty %> row ends it)' do
      expect { parse("setVar(\"a\", \"1\");\nsetVar(\"b\",\n\n") }.to raise_error(js_error, 'Unexpected end of input (<anonymous>:4:1)')
      expect { parse("a()\n  \"x\n\"") }.to raise_error(js_error, 'Invalid or unexpected token (<anonymous>:2:3)')
    end

    it 'counts a character beyond the BMP as two columns (UTF-16)' do
      expect { parse(%("#{[0x1F600].pack('U')}" x)) }.to raise_error(js_error, "Unexpected identifier 'x' (<anonymous>:1:6)")
    end

    it 'reports a bad token before a grammar error behind it (one-token lookahead)' do
      expect { parse('a("b" "c\x")') }.to raise_error(js_error, 'Invalid hexadecimal escape sequence (<anonymous>:1:9)')
    end

    it 'reports a raw line break inside a string at the string start' do
      expect { parse("a(\"x\ny\")") }.to raise_error(js_error, 'Invalid or unexpected token (<anonymous>:1:3)')
    end
  end

  describe 'numeric separators, legacy literals and BigInt suffixes (t247)' do
    {
      '1_'                => 'Numeric separators are not allowed at the end of numeric literals (<anonymous>:1:2)',
      '1_e5'              => 'Numeric separators are not allowed at the end of numeric literals (<anonymous>:1:2)',
      '1e5_'              => 'Numeric separators are not allowed at the end of numeric literals (<anonymous>:1:4)',
      '1.5_'              => 'Numeric separators are not allowed at the end of numeric literals (<anonymous>:1:4)',
      '5_.5'              => 'Numeric separators are not allowed at the end of numeric literals (<anonymous>:1:2)',
      '0x1_'              => 'Numeric separators are not allowed at the end of numeric literals (<anonymous>:1:4)',
      '0o7_'              => 'Numeric separators are not allowed at the end of numeric literals (<anonymous>:1:4)',
      '1_2_3_'            => 'Numeric separators are not allowed at the end of numeric literals (<anonymous>:1:6)',
      '1_n'               => 'Numeric separators are not allowed at the end of numeric literals (<anonymous>:1:2)',
      '1__1'              => 'Only one underscore is allowed as numeric separator (<anonymous>:1:3)',
      '0x1__2'            => 'Only one underscore is allowed as numeric separator (<anonymous>:1:5)',
      '1e1__0'            => 'Only one underscore is allowed as numeric separator (<anonymous>:1:5)',
      '1.0__1'            => 'Only one underscore is allowed as numeric separator (<anonymous>:1:5)',
      '0_1'               => 'Numeric separator can not be used after leading 0 (<anonymous>:1:2)',
      '0_'                => 'Numeric separator can not be used after leading 0 (<anonymous>:1:2)',
      '08_1'              => 'Invalid or unexpected token (<anonymous>:1:3)',
      '07_7'              => 'Invalid or unexpected token (<anonymous>:1:3)',
      '00_1'              => 'Invalid or unexpected token (<anonymous>:1:3)',
      '1._5'              => 'Invalid or unexpected token (<anonymous>:1:1)',
      '1e_5'              => 'Invalid or unexpected token (<anonymous>:1:1)',
      '1e+_1'             => 'Invalid or unexpected token (<anonymous>:1:1)',
      '0x_1'              => 'Invalid or unexpected token (<anonymous>:1:1)',
      '1.5n'              => 'Invalid or unexpected token (<anonymous>:1:1)',
      '1e5n'              => 'Invalid or unexpected token (<anonymous>:1:1)',
      '.5n'               => 'Invalid or unexpected token (<anonymous>:1:1)',
      '08n'               => 'Invalid or unexpected token (<anonymous>:1:1)',
      '0xn'               => 'Invalid or unexpected token (<anonymous>:1:1)',
      'getVar("a", 1__0)' => 'Only one underscore is allowed as numeric separator (<anonymous>:1:15)'
    }.each do |text, message|
      it "reports #{text} as #{message}" do
        expect { parse(text) }.to raise_error(js_error, message)
      end
    end

    { '1_000_000' => 1_000_000.0, '1.5_5' => 1.55, '0b1_0' => 2.0, '1e1_0' => 1e10, '0.0_1' => 0.01, '0.' => 0.0 }.each do |text, number|
      it "reads #{text} as #{number}" do
        expect(value(text)).to eql(number)
      end
    end

    it 'does not run a BigInt (no CLR conversion; Jint would store "10")' do
      %w[0n 10n 1_0n 0x1n].each { |text| expect { parse(text) }.to raise_error(unsupported) }
    end
  end

  describe 'tokens that cannot start an expression' do
    {
      '.e1' => "Unexpected token '.' (<anonymous>:1:1)", '.x' => "Unexpected token '.' (<anonymous>:1:1)",
      '...x' => "Unexpected token '...' (<anonymous>:1:1)", 'getVar(.x)' => "Unexpected token '.' (<anonymous>:1:8)"
    }.each do |text, message|
      it "reports #{text} as #{message} (t247)" do
        expect { parse(text) }.to raise_error(js_error, message)
      end
    end

    it 'does not run a spread argument (valid: Jint evaluates `getVar(1, ...a)` to "a is not defined")' do
      expect { parse('getVar(1, ...a)') }.to raise_error(unsupported)
    end
  end

  describe 'the %> a one-line <% .. %> block keeps (t246)' do
    it "is Unexpected token '>' at the > after a complete statement" do
      expect { parse(%( setVar("a", "2") %>\necho r1 [%a]\n)) }.to raise_error(js_error, "Unexpected token '>' (<anonymous>:1:20)")
      expect { parse(%(doPush("a", "b"); undefinedThing %>)) }.to raise_error(js_error, "Unexpected token '>' (<anonymous>:1:35)")
      expect { parse(%(setVar("q", "1") %\n> 1\n)) }.to raise_error(js_error, "Unexpected token '>' (<anonymous>:2:1)")
    end

    it 'leaves other operator sequences unmodelled' do
      ['a() %= 1', 'a() %>> 1', 'a() %>= 1', 'a() % 2', 'a() * >'].each do |text|
        expect { parse(text) }.to raise_error(unsupported)
      end
    end
  end

  describe 'robustness' do
    it "caps call nesting at #{described_class::MAX_NESTING} levels (no SystemStackError; Jint runs 3000)" do
      depth = described_class::MAX_NESTING
      ok = "#{'a(' * depth}1#{')' * depth}"
      expect(parse(ok).first.name).to eq('a')
      expect { parse("#{'a(' * (depth + 1)}1#{')' * (depth + 1)}") }.to raise_error(unsupported, /nested deeper than #{depth}/)
      expect { parse("#{'a(' * 5000}1#{')' * 5000}") }.to raise_error(unsupported)
      siblings = "a(#{Array.new(depth * 2) { 'b(c())' }.join(', ')})"
      expect(parse(siblings).first.args.length).to eq(depth * 2) # the depth, not the number of calls
    end

    it 'reads invalid UTF-8 as U+FFFD instead of raising' do
      bad = "setVar(\"x\", \"a#{[0xFF].pack('C')}b\")".dup.force_encoding(Encoding::UTF_8)
      expect(parse(bad).first.args.last.value).to eq("a#{[0xFFFD].pack('U')}b")
      expect { parse("#{[0xFF].pack('C')}{".dup.force_encoding(Encoding::UTF_8)) }.to raise_error(unsupported)
    end

    it 'scans a long non-ASCII source in linear time' do
      long = %("#{[0xE9].pack('U') * 200_000}")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(value(long).length).to eq(200_000)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
    end
  end

  describe 'valid JavaScript outside the slice' do
    ['1+2', 'setVar("x", "a" + "b")', 'a.b()', 'a()()', 'a[0]', 'var x = 1', 'function f() {}', 'x = 1', '(a)',
     'a(), b()', '!a', 'typeof a', "a()\n(b)", "a()\n-1", '`t`', '5n', '/re/.test(a)', 'if (a) b()', 'a(1 + 2)',
     '/* open', 'a(function () {})', 'caf' + [0xE9].pack('U') + '()', 'a("x" in b)', 'a() if'].each do |text|
      it "does not run #{text.inspect}" do
        expect { parse(text) }.to raise_error(unsupported)
      end
    end
  end
end
