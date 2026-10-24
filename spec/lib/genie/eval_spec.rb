# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Eval do
  subject(:evaluator) { described_class.new(globals: globals) }

  let(:globals) { { 'knownvar' => 'x' } }

  def truthy(expr)
    evaluator.do_eval(expr)
  end

  def str(expr)
    evaluator.eval_string(expr)
  end

  describe 'numeric comparisons' do
    it 'compares numbers' do
      expect(truthy('100 > 50')).to be(true)
      expect(truthy('50 >= 50')).to be(true)
      expect(truthy('10 < 5')).to be(false)
      expect(truthy('5 = 5')).to be(true)
      expect(truthy('5 == 5')).to be(true)
      expect(truthy('5 != 6')).to be(true)
      expect(truthy('5 <> 6')).to be(true)
    end
  end

  describe 'string comparisons' do
    it 'compares strings case-sensitively for equality' do
      expect(truthy('"foo" = "foo"')).to be(true)
      expect(truthy('"foo" = "FOO"')).to be(false)
      expect(truthy('"foo" != "bar"')).to be(true)
    end

    it 'always yields false for relational operators on strings' do
      expect(truthy('"foo" > "bar"')).to be(false)
      expect(truthy('"foo" < "bar"')).to be(false)
    end

    it 'uses string (not numeric) comparison when either side is quoted' do
      # "05" vs 5 is string comparison ("05" != "5"); numerically they'd be equal.
      expect(truthy('"05" = 5')).to be(false)
      expect(truthy('05 = 5')).to be(true) # both numeric tokens -> numeric comparison
      expect(truthy('"5" = "5"')).to be(true)
    end

    # An unquoted value with a leading '.' (e.g. a script name like ".sc") must be a
    # STRING token, not a malformed number -- a tester's `if $looptask != 0` where
    # $looptask = ".sc" relies on this being true. Regression for the .sc split bug.
    it 'treats a leading-dot bareword (".sc") as a string, not a number' do
      expect(truthy('.sc != 0')).to be(true)
      expect(truthy('.sc = 0')).to be(false)
      expect(truthy('3x != 0')).to be(true) # digits+letters -> string too
    end

    # Remix oracle (reference/specxcheck.rb): `.sc = .sc` is FALSE in Genie -- EvalString(".sc")
    # tokenizes to "." -- so the old `be(true)` expectation locked in a divergence.
    it 'compares two leading-dot barewords the way Remix tokenizes them' do
      expect(truthy('.sc = .sc')).to be(false)
      expect(str('.sc')).to eq('.') # "." is a number section, "sc" a word after it
    end

    it 'still parses genuine numbers with leading dot / minus' do
      expect(truthy('.5 > 0')).to be(true)
      expect(truthy('-3 < 0')).to be(true)
    end
  end

  describe 'keyword aliases' do
    it 'maps eq/and/or/not/true/false' do
      expect(truthy('5 eq 5')).to be(true)
      expect(truthy('1 and 1')).to be(true)
      expect(truthy('0 or 1')).to be(true)
      expect(truthy('true')).to be(true)
      expect(truthy('false')).to be(false)
      expect(truthy('not 0')).to be(true)
    end

    it 'does not substitute keywords inside quoted strings' do
      expect(str('"true or false"')).to eq('true or false')
    end

    # Remix compiles the keyword regex with RegexOptions.IgnoreCase | options (Eval.cs:92 R) and
    # lowercases the match before mapping it (Eval.cs:102 R); upstream's `IgnoreCase & options`
    # is RegexOptions.None, i.e. lowercase only. Expected values are Remix genieoracle answers.
    describe 'keyword case (Remix: case-insensitive)' do
      it 'translates upper- and mixed-case AND/OR/NOT' do
        expect(truthy('1 = 1 AND 2 = 3')).to be(false)
        expect(truthy('1 = 2 oR 2 = 2')).to be(true)
        expect(truthy('NOT 1 = 2')).to be(true)
        expect(truthy('nOt 1 = 1')).to be(false)
        expect(truthy('5 > 10 OR 5 = 5')).to be(true)
      end

      it 'translates upper- and mixed-case TRUE/FALSE/EQ' do
        expect(truthy('TRUE')).to be(true)
        expect(truthy('FALSE')).to be(false)
        expect(truthy('TRUE AND FALSE')).to be(false)
        expect(truthy('TRUE OR FALSE')).to be(true)
        expect(truthy('1 EQ 1')).to be(true)
        expect(truthy('1 Eq 2')).to be(false)
        expect(str('True')).to eq('1')
      end

      it 'leaves upper-case keywords inside quotes alone' do
        expect(str('"a AND b"')).to eq('a AND b')
        expect(truthy('"a" = "a" AND "AND" = "AND"')).to be(true)
        expect(str('tolower("NOT")')).to eq('not')
      end

      it 'needs a word boundary on both sides (ANDY, x_AND are not keywords)' do
        expect(str('ANDY')).to eq('ANDY')
        expect(str('x_AND')).to eq('x_AND')
      end

      # Ruby's /i folds U+017F LATIN SMALL LETTER LONG S to 's'; .NET's IgnoreCase regex
      # (Eval.cs:92 R) does not, so Remix leaves such a word untouched. genieoracle answers.
      it 'does not treat a non-ASCII case fold (long s) as a keyword' do
        long_s = [0x017F].pack('U')
        expect(str("fal#{long_s}e")).to eq("fal#{long_s}e")
        expect(str("FAL#{long_s}E OR 1")).to eq('0')
        expect(str("1 #{long_s}and 1")).to eq('1')
      end

      # Eval.cs:78 R runs ReplaceKeyWordsSection on the trailing segment unconditionally, so
      # the body of an unclosed string literal is keyword-translated. genieoracle answers.
      it 'translates keywords inside an unterminated quote, as Remix does' do
        expect(str('"unterminated AND 1')).to eq('"unterminated && 1')
        expect(str('"unterminated and 1')).to eq('"unterminated && 1')
        expect(str('x "q" AND "r')).to eq('x')
        expect(str('"a" AND "b TRUE')).to eq('0')
        expect(str('"x" = "x" AND "y TRUE')).to eq('0')
        expect(str('"AND" AND "OR"')).to eq('0')
      end
    end
  end

  describe 'logical operators and precedence' do
    it 'evaluates comparisons before and/or' do
      expect(truthy('100 > 50 && 80 > 20')).to be(true)
      expect(truthy('100 > 50 && 10 > 20')).to be(false)
      expect(truthy('0 > 1 || 5 > 1')).to be(true)
    end

    it 'treats only strictly-positive numbers as truthy in and/or' do
      expect(truthy('1 && 1')).to be(true)
      expect(truthy('1 && 0')).to be(false)
      expect(truthy('0 || 0')).to be(false)
    end

    it 'honours parentheses' do
      expect(truthy('(0 || 1) && 1')).to be(true)
      expect(truthy('0 || 1 && 0')).to be(false) # equal precedence, left-assoc
    end
  end

  describe 'truthiness of bare values' do
    it 'treats a bare non-empty string as false' do
      expect(truthy('"hello"')).to be(false)
      expect(truthy('hello')).to be(false)
    end

    it 'treats positive numbers as true and zero/negatives as false' do
      expect(truthy('1')).to be(true)
      expect(truthy('42')).to be(true)
      expect(truthy('0')).to be(false)
    end
  end

  describe 'functions' do
    it 'contains / instr' do
      expect(truthy('contains("hello world", "world")')).to be(true)
      expect(truthy('contains("hello", "xyz")')).to be(false)
    end

    it 'indexof (1-based, 0 when missing)' do
      expect(str('indexof("hello", "l")')).to eq('3')
      expect(str('indexof("hello", "z")')).to eq('0')
    end

    it 'startswith / endswith / match' do
      expect(truthy('startswith("hello", "he")')).to be(true)
      expect(truthy('endswith("hello", "lo")')).to be(true)
      expect(truthy('match("hello", "hello")')).to be(true)
    end

    it 'replace / tolower / toupper / trim' do
      expect(str('replace("a-b-c", "-", "+")')).to eq('a+b+c')
      expect(str('tolower("ABC")')).to eq('abc')
      expect(str('toupper("abc")')).to eq('ABC')
      expect(str('trim("  hi  ")')).to eq('hi')
    end

    it 'len / count' do
      expect(str('len("hello")')).to eq('5')
      expect(str('count("a.b.c.d", ".")')).to eq('3')
    end

    it 'substr with 2 and 3 args' do
      expect(str('substr("hello", 1)')).to eq('ello')
      expect(str('substr("hello", 1, 3)')).to eq('ell')
    end

    it 'element (pipe-delimited, 0-based)' do
      expect(str('element("a|b|c", 1)')).to eq('b')
      expect(str('element("a|b|c", 5)')).to eq('c') # clamp to last
    end

    it 'matchre exposes capture groups' do
      expect(truthy('matchre("HP: 42/100", "(\\d+)/(\\d+)")')).to be(true)
      expect(evaluator.result_list).to eq(['42/100', '42', '100'])
    end

    # Genie's matchre does NOT trim the subject (Eval.cs:1149); we used to match against
    # subject.strip, diverging on leading/trailing whitespace (bool AND captures).
    it 'matchre does not strip the subject before matching' do
      expect(truthy('matchre("  pad  ", "^\\s+")')).to be(true)
      expect(truthy('matchre(" lead", "\\s")')).to be(true)
      evaluator.eval_string('matchre("  pad  ", ".+")')
      expect(evaluator.result_list).to eq(['  pad  '])
    end

    # Genie's replacere is .NET Regex.Replace (Eval.cs:1176): full substitution grammar,
    # not just $digits. Verified byte-for-byte against the oracle via fuzz_regex.rb.
    it 'replacere honors .NET substitution metacharacters' do
      expect(str('replacere("abc", "(b)", "[${1}]")')).to eq('a[b]c')
      expect(str('replacere("abc", "b", "[$&]")')).to eq('a[b]c')
      expect(str('replacere("abc", "b", "x$$y")')).to eq('ax$yc')
      expect(str('replacere("abc", "(b)", "$`|$1|$\'")')).to eq('aa|b|cc')
      expect(str('replacere("abc", "b", "[$_]")')).to eq('a[abc]c')
      expect(str('replacere("abc", "(a)(b)(c)", "$+")')).to eq('c')
    end

    # matchre()/replacere() compile through NetRegex like the script
    # verbs. GenieHunter hunt.cmd:4071 `matchre("$monsterlist", "(%nonskinnablecritters)")`
    # expands to the variable-length lookbehind of hunt.cmd:309, which Onigmo cannot compile
    # raw (it used to stop the script; Remix matches). Expectations: genieoracle rxmatch.
    it 'matchre matches a variable-length lookbehind (hunt.cmd:4071 shape) like .NET' do
      hunt = '(spirit|(?<!arisen \\S+ )zombie(?!\\s)|zombie (head-splitter|mauler))'
      expect(truthy(%(matchre("an arisen big zombie and a spirit", "#{hunt}")))).to be(true)
      expect(evaluator.result_list).to eq(%w[spirit spirit] + [''])
      expect(truthy(%(matchre("an arisen big zombie", "#{hunt}")))).to be(false)
      expect(truthy(%(matchre("a zombie.", "#{hunt}")))).to be(true)
      expect(evaluator.result_list).to eq(['zombie', 'zombie', ''])
    end

    # The recorded Unsupported divergence: .NET answers true / "Z" here.
    it 'matchre/replacere: Unsupported never matches, .NET-invalid is a Fault' do
      expect(truthy('matchre("aay", "\\w+(?<=a+)y")')).to be(false)
      expect(str('replacere("aay", "\\w+(?<=a+)y", "Z")')).to eq('aay')
      # .NET rejects (RegexParseException); Onigmo would not
      expect { truthy('matchre("aa", "a++")') }.to raise_error(described_class::Fault, /\AInvalid pattern 'a\+\+'/)
      expect { str('replacere("aa", "\\q", "b")') }.to raise_error(described_class::Fault, /\AInvalid pattern/)
    end

    it 'replacere walks an emulated lookbehind match by match, the text before each still visible' do
      expect(str('replacere("x1 22 x333 4", "(?<!x\\d*)\\d+", "<$&>")')).to eq('x1 <22> x333 <4>')
      expect(str('replacere("ab", "(?<!z\\w*)", "-")')).to eq('-a-b-') # empty matches step on by one
      expect(str('replacere("big zombie, zombie", "(?<!big \\w*)zombie", "Z")')).to eq('big zombie, Z')
    end

    # Adjacent emulated matches, the second starting where
    # the first ended. rx oracle: Regex.Replace("abb", "(?<=a\w*)b", "X") = "aXX".
    it 'replacere replaces adjacent emulated matches back to back' do
      expect(str('replacere("abb", "(?<=a\\w*)b", "X")')).to eq('aXX')
      expect(str('replacere("a bb", "(?<!x\\w*)b", "<$&>")')).to eq('a <b><b>')
    end

    # The owner (the interpreter) is told about an Unsupported pattern.
    it 'reports an Unsupported matchre()/replacere() pattern to on_unsupported, with the function name' do
      seen = []
      ev = described_class.new(globals: globals, on_unsupported: ->(compiled, where) { seen << [compiled.class, where] })
      ev.do_eval('matchre("aay", "\\w+(?<=a+)y")')
      ev.eval_string('replacere("aay", "\\w+(?<=a+)y", "Z")')
      ev.do_eval('matchre("aay", "a+y")')
      expect(seen).to eq([[Lich::Genie::NetRegex::Unsupported, 'matchre()'], [Lich::Genie::NetRegex::Unsupported, 'replacere()']])
    end

    it 'replacere leaves invalid/out-of-range group refs literal' do
      expect(str('replacere("abc", "(b)", "[$2]")')).to eq('a[$2]c') # only 1 group
      expect(str('replacere("Xb", "(b)", "$12")')).to eq('X$12')     # maximal digit run, invalid
      expect(str('replacere("abc", "b", "$z")')).to eq('a$zc')
    end

    it 'def/defined against the globals lookup' do
      expect(truthy('def("knownvar")')).to be(true)
      expect(truthy('defined("missingvar")')).to be(false)
    end
  end

  # --- Literal Eval.cs port (flat section list, pass by pass). Every literal below is a
  # genieoracle (Remix v4.2.4 Eval.cs) answer; reference/specxcheck.rb re-checks them. ---
  describe 'the flat section model (Parse, ParseQueue, ParseSection, GetStringResult)' do
    # Parse (Eval.cs:202-269 R): a letter after a number flushes the number section.
    it 'splits a number from the word after it' do
      expect(str('1x = 1')).to eq('1')
      expect(str('2x = 1')).to eq('2')
      expect(str('1 1 = 2')).to eq('1')
    end

    # ParseQueue (Eval.cs:374-397 R): a top-level ")" parses what precedes it and stops.
    it 'stops at a top-level closing paren, leaving the rest raw' do
      expect(str('(3 + 5) = 10')).to eq('3') # `+ 5` is one word: (3 "+ 5"), then = 10 is lost
      expect(truthy('1 > 0)')).to be(true)
      expect(str('1 > 0) x')).to eq('1')
      expect(str('5 = 5) && 0')).to eq('1')
    end

    # GetStringResult (Eval.cs:400-422 R) takes a section only while the result is empty;
    # GetBooleanResult (Eval.cs:425-455 R) is true when ANY unparsed number section is.
    it 'returns the first non-empty result and is true when any number section is' do
      expect(str('"" x')).to eq('x')
      expect(str('x ""')).to eq('x')
      expect(str('"a" "b"')).to eq('a')
      expect(truthy('0 1')).to be(true)
      expect(truthy('(1) (0)')).to be(true)
      expect(truthy('1 = 1 && 2')).to be(true)
    end

    # ParseSection (Eval.cs:500-551 R): a comparison missing an operand leaves the other one.
    it 'keeps a lone operand when a comparison lacks the other' do
      expect(truthy(' > 9')).to be(true)
      expect(truthy(' < 40')).to be(true)
      expect(truthy('5 >')).to be(true)
      expect(truthy('0 >')).to be(false)
      expect(truthy('= 1')).to be(true)
      expect(str('3 > 2 || x')).to eq('0') # && / || of a number and a word is 0
    end

    # "{" and "}" are word characters; the parenthesized ranges still evaluate.
    it 'evaluates a brace-wrapped condition' do
      expect(truthy('{(1 = 1) && (2 = 2)}')).to be(true)
      expect(truthy('{(1 = 1) && (2 = 3)}')).to be(false)
    end

    # An unclosed "(" parses its range to the end, so its function is still called.
    it 'calls a function whose paren is never closed' do
      expect(str('len("abc"')).to eq('3')
      expect(str('tolower("ABC"')).to eq('abc')
      expect(truthy('contains("abc", "b"')).to be(true)
    end

    # The "not" pass flips a section's TEXT but keeps its TYPE; only number sections are
    # conditions (Eval.cs:432, 553-590 R).
    it 'judges truth by section type: a negated or quoted value stays a string' do
      expect(truthy('!"abc"')).to be(false)
      expect(str('!"abc"')).to eq('1')
      expect(truthy('!""')).to be(false)
      expect(truthy('"1"')).to be(false)
      expect(truthy('!abc')).to be(false)
      expect(truthy('!0')).to be(true)
      expect(truthy('not 0 and not 0')).to be(true)
    end

    # ParseFunction (Eval.cs:900-1261 R): BuildArgs consumes the arguments first, then a
    # wrong count leaves the function section (never a result) as it was.
    it 'makes a wrong-arity call a silent no-op that swallows its arguments' do
      expect(str('contains("a")')).to eq('')
      expect(str('contains("a", "b", "c")')).to eq('')
      expect(str('len("a", "b")')).to eq('')
      expect(str('matchre("abc", "b", "c")')).to eq('') # three args never reach Regex
      expect(evaluator.result_list).to eq([])
    end

    # SectionEnqueue (Eval.cs:285, 345 R): the Functions list is matched case-sensitively
    # and lacks a closing "|" after "defined"; IsSectionTrue uses int.Parse (Eval.cs:1293 R).
    it 'keeps Remix function-name and truthiness quirks' do
      expect(str('Len("abc")')).to eq('Len')
      expect(str('defined(x)')).to eq('defined')
      expect(str('x contains("a")')).to eq('x contains') # a space keeps a word going
      expect(truthy('09')).to be(true)
      expect(truthy('2147483648')).to be(false) # Int32 overflow
      expect(truthy('1.5')).to be(false)
      expect(truthy('+5')).to be(false) # "+" starts a word
      expect(truthy('dead man = dead man')).to be(true)
      expect(truthy('"abc" = abc')).to be(true)
    end
  end

  describe '.NET string semantics' do
    it 'maps case one character at a time, like String.ToUpper/ToLower' do
      sharp_s = [0xDF].pack('U')
      expect(str(%(toupper("stra#{sharp_s}e")))).to eq("STRA#{sharp_s}E") # Ruby's upcase: "STRASSE"
      expect(str(%(tolower("#{[0x130].pack('U')}x")))).to eq('ix') # Ruby's downcase: i + U+0307
    end

    it 'counts positions in UTF-16 code units' do
      emoji = [0x1F600].pack('U')
      expect(str(%(len("#{emoji}")))).to eq('2')
      expect(str(%(indexof("#{emoji}ab", "a")))).to eq('3')
      expect(str(%(substr("#{emoji}ab", 2)))).to eq('ab')
      expect(str(%(substr("#{emoji}ab", 1, 2)))).to eq("#{[0xFFFD].pack('U')}a") # a cut surrogate pair
    end

    it 'reads invalid UTF-8 the way .NET decoded it (U+FFFD), never raising' do
      broken = [0xFF, 0x61].pack('C*').force_encoding(Encoding::UTF_8)
      expect(str(%(len("#{broken}")))).to eq('2')
      expect(str(%(toupper("#{broken}")))).to eq("#{[0xFFFD].pack('U')}A")
      expect(truthy(%(contains("#{broken}", "a")))).to be(true)
      # raw bytes too (a BINARY string), where a UTF-8 pattern would raise on a Ruby match
      expect(str([0x35, 0xFF].pack('C*'))).to eq('5') # genieoracle: "5<FF>" -> "5"
      expect(str(%(len("#{[0xFF].pack('C*')}")).b)).to eq('1')
    end

    it 'replaces literally (String.Replace), never as a Ruby gsub template' do
      expect(str('replace("aXbXc", "X", "$0")')).to eq('a$0b$0c')
      expect(str('replace("ab", "b", "\\\\0")')).to eq('a\\\\0') # "\\0" stays two characters
    end

    it 'runs substr/substring and element exactly like the C# (negative lengths, clamps)' do
      expect(str('substr("hello", -2, 2)')).to eq('he')
      expect(str('substr("hello", 3, -2)')).to eq('el')
      expect(str('substr("hello", 1, -5)')).to eq('h')
      expect(str('substr("hello", 9)')).to eq('') # 2 args out of range: a no-op
      expect(str('substr("hello", 2.5)')).to eq('llo') # VB ToInteger rounds half to even
      expect(str('substr("hello", 1, 10)')).to eq('ello')
      expect(str('element("a|b|c", -1)')).to eq('c')
      expect(str('element("(a|b)", 5)')).to eq('b')
      expect(str('element("", 0)')).to eq('')
    end

    # Parse's number branch is Information.IsNumeric(ch) (Eval.cs:205 R), true
    # for 0-9 and U+221E (a BMP scan through genieoracle); the comparison's StringToDouble reads a
    # signed U+221E as an infinity (Eval.cs:656-657 R). `evalmath r 1/0` stores that sign. Every
    # row is genieoracle's (2026-10-20).
    it 'reads the infinity sign as a number character and an infinity in a comparison' do
      inf = [0x221E].pack('U')
      expect([truthy("#{inf} > 1"), truthy("-#{inf} < 0"), truthy("#{inf} > 999999"), truthy("-#{inf} < -999999"),
              truthy("#{inf} = #{inf}"), truthy("-#{inf} = -#{inf}"), truthy("#{inf} >= #{inf}")]).to all(be(true))
      # a number section that is not exactly [+-]<sign> is StringToDouble's -1
      expect([truthy("--#{inf} < 0"), truthy("1#{inf} > 0"), truthy("#{inf}- > 1"), truthy(".#{inf} > 0"),
              truthy("#{inf}#{inf} > 1"), truthy("-#{inf} > -999999"), truthy("+#{inf} > 1")]).to eq([true] + [false] * 6)
      expect([str("1#{inf}1"), str("-#{inf}"), str("#{inf} > 1"), str("a#{inf}b")]).to eq(["1#{inf}1", "-#{inf}", '1', "a#{inf}b"])
      expect(truthy(inf)).to be(false) # a lone number is a condition only when it is a positive Int32
    end
  end

  # What .NET throws inside Eval.cs escapes EvalString/DoEval (Remix: GenieError; ours:
  # the interpreter prints the message and stops the script). Messages are .NET 8's.
  describe 'faults' do
    it 'raises a Fault with the .NET message' do
      {
        'substr("x", 5, 3)'          => "startIndex cannot be larger than length of string. (Parameter 'startIndex')",
        'substr("x", "y", 1)'        => "Conversion from string \"y\" to type 'Integer' is not valid.",
        'substr("x", 1, 3000000000)' => 'Arithmetic operation resulted in an overflow.',
        'element("a|b", x)'          => "The input string 'x' was not in a correct format.",
        'element("a|b", 3000000000)' => 'Value was either too large or too small for an Int32.',
        'replace("abc", "", "x")'    => "The value cannot be an empty string. (Parameter 'oldValue')",
        'count("abc", "")'           => 'count() with an empty search text never returns (Remix loops forever)'
      }.each do |expr, message|
        expect { str(expr) }.to raise_error(described_class::Fault, message), expr
        expect { truthy(expr) }.to raise_error(described_class::Fault, message), expr
      end
    end

    it 'is a Lich::Genie::Error, so every Error rescue still sees it' do
      expect(described_class::Fault.ancestors).to include(Lich::Genie::Error)
    end
  end

  # m_RegExpResultList (Eval.cs:48, 872-889, 1177-1179 R): one list per evaluator, cleared
  # at the start of every evaluation; the interpreter binds a frame's $-args to it.
  describe '#result_list identity' do
    it 'is the same array object across evaluations, cleared by each one' do
      list = evaluator.result_list
      evaluator.eval_string('matchre("HP 42", "(\\d+)")')
      expect(list).to equal(evaluator.result_list)
      expect(list).to eq(%w[42 42])
      evaluator.do_eval('1 = 1')
      expect(list).to eq([])
      expect(evaluator.result_list).to equal(list)
    end

    it 'keeps the last hit when a later matchre() of the same evaluation misses' do
      evaluator.eval_string('matchre("ab", "(a)") && matchre("ab", "(z)")')
      expect(evaluator.result_list).to eq(%w[a a])
      evaluator.eval_string('matchre("ab", "(a)") && matchre("ab", "(b)")')
      expect(evaluator.result_list).to eq(%w[b b])
    end

    it 'is cleared even when the evaluation then faults' do
      evaluator.eval_string('matchre("ab", "(a)")')
      expect { evaluator.eval_string('substr("x", 5, 3)') }.to raise_error(described_class::Fault)
      expect(evaluator.result_list).to eq([])
    end
  end

  describe 'edge cases' do
    it 'returns false / empty for an empty expression' do
      expect(truthy('')).to be(false)
      expect(str('')).to eq('')
    end

    it 'tolerates an unbalanced closing paren' do
      expect(truthy('1 > 0)')).to be(true)
    end
  end
end
