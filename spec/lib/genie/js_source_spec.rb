# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# A JavaScript program split into its top-level function declarations (fingerprinted
# by their normalised text) and the rest (handed to JsParser with columns intact). Synthetic
# sources only (the real ones are third-party GPL code); js_arrays_spec pins the fingerprints of
# the real js_arrays.js versions.
RSpec.describe Lich::Genie::JsSource do
  unsupported = Lich::Genie::JsRuntime::Unsupported

  def split(text) = described_class.split(text)

  def names(text) = split(text).first.map(&:name)

  def fingerprint(text) = described_class.fingerprint(text)

  describe '.fingerprint (normalised declaration text)' do
    it 'ignores comments, indentation and the length of white space runs' do
      base = fingerprint("function f(a, b) {\nvar x = a; // one\nreturn x;\n}")
      expect(fingerprint("function   f(a,\tb)  {\n   /* doc */ var x = a;\n\t\treturn x; /* c */\n}")).to eq(base)
      expect(fingerprint("function f(a, b) {\r\n\r\nvar x = a;\r\nreturn x;\r\n}")).to eq(base)
      expect(fingerprint("function f(a, b) { /* a\nline */ var x = a;\nreturn x;\n}")).to eq(base)
    end

    it 'keeps a line break apart from a space (automatic semicolon insertion) and adjacency apart from a space' do
      base = fingerprint("function f() { return\nx }")
      expect(fingerprint('function f() { return x }')).not_to eq(base)
      expect(fingerprint("function f() { return /* c\n */x }")).to eq(base) # a comment holding a line break is one
      expect(fingerprint('function f() { a == b }')).not_to eq(fingerprint('function f() { a = = b }'))
    end

    it 'keeps string and regular-expression literals verbatim' do
      expect(fingerprint('function f() { s("a  b") }')).not_to eq(fingerprint('function f() { s("a b") }'))
      expect(fingerprint('function f() { s("// not a comment") }')).not_to eq(fingerprint('function f() { s("") }'))
      expect(fingerprint('function f() { r(/a  b/g) }')).not_to eq(fingerprint('function f() { r(/a b/g) }'))
    end

    it 'is the SHA-256 of that text' do
      expect(fingerprint("function f() {\n  // c\n}")).to eq(Digest::SHA256.hexdigest("function f() {\n}"))
    end

    # Every construct the real js_arrays.js versions use (a regular expression after `(`,
    # "|" strings, tabs, a multi-line block comment, CR LF, a BOM), pinned to a literal SHA so CI ties the
    # normaliser to the stored FUNCTION_BODIES fingerprints without the lab files.
    it 'normalises a body built of the js_arrays.js constructs to a pinned text and SHA-256' do
      bom = [0xFEFF].pack('U')
      body = "function doThing(arrayname, item) {\r\n\t/*Function: multi-line\r\n\t  comment | with a bar\r\n\t*/\r\n" \
             "\tvar list = getVar(arrayname).toString().split(\"|\");\r\n\tif (item[0] == \"%\")\r\n\t\t{\r\n" \
             "\t\titem = getVar(item.replace(/%/,\"\"));\r\n\t\t}\r\n#{bom}\tsetVar(arrayname,list.join(\"|\")); // a | comment\r\n\t}"
      normalised = "function doThing(arrayname, item) {\nvar list = getVar(arrayname).toString().split(\"|\");\n" \
                   "if (item[0] == \"%\")\n{\nitem = getVar(item.replace(/%/,\"\"));\n}\nsetVar(arrayname,list.join(\"|\"));\n}"
      expect(described_class.new(body).normalise).to eq(normalised)
      expect(fingerprint(body)).to eq('2e0bca7b2d0b953a888cd3e3d74fb60aa85cc2ac015a04795a8d2cd11cda7a42')
    end

    it 'is nil for a text the scanner cannot follow' do
      expect(['function f() { `t` }', 'a /* open', 's("open'].map { |text| fingerprint(text) }).to all(be_nil)
    end
  end

  describe '.split' do
    it 'cuts out each top-level declaration, nested braces, strings, comments and regexes included' do
      text = "function a(x) { if (x) { s(\"}\"); } r(/[}]\\/}/); /* } */ }\nfunction b() {}\n// function c() {}\n"
      declarations, rest = split(text)
      expect(declarations.map { |d| [d.name, d.line] }).to eq([['a', 1], ['b', 2]])
      expect(declarations.first.fingerprint).to eq(fingerprint(text.lines.first.chomp))
      expect(rest).to eq("#{' ' * text.lines.first.chomp.length}\n#{' ' * 15}\n// function c() {}\n")
    end

    it 'leaves the rest with its lines and columns for JsParser' do
      _, rest = split("setVar(\"a\", 1);function f() {\n}\nsetVar(\"b\", 2)\n")
      expect(rest).to eq("setVar(\"a\", 1);#{' ' * 14}\n \nsetVar(\"b\", 2)\n")
    end

    it 'blanks a character beyond the BMP as two columns (UTF-16)' do
      _, rest = split(%(function f() { s("#{[0x1F600].pack('U')}") } x))
      expect(rest).to eq("#{' ' * 24} x")
    end

    it 'counts lines through CR LF, CR, U+2028, comments and string line continuations' do
      text = "a()\r\n/* x\r\ny */ b()\r\"p\\\nq\"#{[0x2028].pack('U')}function f() {}"
      expect(split(text).first.map(&:line)).to eq([6])
    end

    it 'finds a declaration only where a statement starts' do
      expect(names("a(); function f() {}\nfunction g() {}")).to eq(%w[f g])
      expect(names("{ x }\nfunction f() {}")).to eq(['f'])
      expect(names("x\nfunction f() {}\n\"s\"\nfunction g() {}\nh()\nfunction k() {}")).to eq(%w[f g k])
      expect(names('x function f() {}')).to eq([])
      expect(names("setVar(\"f\",\nfunction f() {})")).to eq([])
      expect(names('var f = function g() {}')).to eq([])
      expect(names('{ function f() {} }')).to eq([])
    end

    it 'needs `function NAME (`: no anonymous, generator, keyword-named or async declarations' do
      expect(names('function () {}')).to eq([])
      expect(names('function* g() {}')).to eq([])
      expect(names('function if() {}')).to eq([])
      expect(names('async function f() {}')).to eq([])
      expect(names('functional() {}')).to eq([])
      expect(names("function\n/* c */ f\n(a) {}")).to eq(['f'])
    end

    it 'reads a regular expression at the very start and through a character class holding a slash' do
      expect(names("/}/.test(a)\nfunction f() {}")).to eq(['f'])
      expect(names("function f() { r(/[/\"]/) }\nfunction g(a = {}) { }")).to eq(%w[f g])
    end

    it 'tells a regular expression from a division by the token before the slash' do
      expect(names("function f(a) { return a / 2 / 3; }\nfunction g() {}")).to eq(%w[f g])
      expect(names("function f(a) { x = (a) / 2; y = a[0] / 2 }\nfunction g() {}")).to eq(%w[f g])
      expect(names("function f() { return /}/.test(x) }\nfunction g() {}")).to eq(%w[f g])
    end

    it 'does not cut a declaration after a call or an index on the same line (a Remix syntax error, q19)' do
      expect(names('a() function f() {}')).to eq([])
      expect(names('a[0] function f() {}')).to eq([])
      expect(names("a()\nfunction f() {}\na[0]\nfunction g() {}")).to eq(%w[f g])
    end

    it 'does not cut a declaration out of an argument list or an array literal (q8)' do
      expect(names("setVar(\"r8\", \"v\"\nfunction bar(){}\n)")).to eq([])
      expect(names("x([1\nfunction f() {}\n])")).to eq([])
      expect(names("[1\nfunction f() {}\n]")).to eq([])
      expect(names("x(a)\nfunction f() {}\n[1]\nfunction g() {}")).to eq(%w[f g])
    end

    it 'divides after `)` of a parenthesised operand: `/ 2; }` is no regular expression' do
      expect(names("function f(x) { return (x) / 2; }\nfunction g() {}")).to eq(%w[f g])
      expect(names("function f(x) { return x[0] / 2; }\nfunction g() {}")).to eq(%w[f g])
      expect(names("function f(x) { return x(1) / 2; }\nfunction g() {}")).to eq(%w[f g])
    end

    it 'reads a regular expression after the `)` of an if/while/for/with head (genieflow q6/q6b)' do
      expect(names("function u2() { if (1) /}}/; }\nfunction g() {}")).to eq(%w[u2 g])
      expect(names("function f() { while (a(b)) /}/.test(x); for (i = 0; i < n(1); i++) /{/; with (o) /}/; }\nfunction g() {}"))
        .to eq(%w[f g])
      expect(names("function f() { if (a) { } /}/.test(x) }\nfunction g() {}")).to eq(%w[f g])
    end

    it 'does not take a declaration as the body of an if/while/for head for a top-level one' do
      expect(names("if (x)\nfunction f() {}")).to eq([])
      expect(names("while (x)\nfunction f() {}")).to eq([])
    end

    it 'decodes a \\u-escaped name (genieflow q23e); an escape it cannot decode to ASCII is unsupported' do
      expect(names('function \\u0066() {}')).to eq(['f'])
      expect(names('function a\\u{62}c() {}')).to eq(['abc'])
      expect(split('function \\u0066() {}').first.first.fingerprint).not_to eq(fingerprint('function f() {}'))
      ['function \\x66() {}', 'function \\u0028() {}', 'function \\u{110000}() {}', 'function \\u00E9() {}', 'function a\\u{62() {}']
        .each { |text| expect { split(text) }.to raise_error(unsupported, /escaped name/) }
      expect(names('function \\u0069f() {}')).to eq([]) # an escaped keyword is no declaration name
    end

    it 'is unsupported for a declaration it cannot scan to its end' do
      ['function f() { "open', 'function f() {', 'function f() { /* open', 'function f() { r(/open', 'function f() { `t` }',
       "function f() { s(\"a\nb\") }", 'function f() { ) }', 'function f() ) {}'].each do |text|
        expect { split(text) }.to raise_error(unsupported, /in a JavaScript function declaration/)
      end
    end

    it 'ends a declaration at its closing brace, whatever follows' do
      expect(split('function f() { }) }')).to eq([[described_class::Declaration.new('f', fingerprint('function f() { }'), 1)], "#{' ' * 16}) }"])
    end

    it 'stops quietly at the top level, leaving the rest for JsParser to report' do
      text = "setVar(\"a\nfunction f() {}"
      expect(split(text)).to eq([[], text])
      expect(split("`t`\nfunction f() {}")).to eq([[], "`t`\nfunction f() {}"])
      expect(split("a() /* open\nfunction f() {}")).to eq([[], "a() /* open\nfunction f() {}"])
    end

    it 'reads invalid UTF-8 as U+FFFD' do
      declarations, rest = split("function f() { s(\"#{[0xFF].pack('C')}\") }\n".dup.force_encoding(Encoding::UTF_8))
      expect(declarations.map(&:fingerprint)).to eq([fingerprint(%(function f() { s("#{[0xFFFD].pack('U')}") }))])
      expect(rest.strip).to eq('')
    end

    it 'scans a long non-ASCII source in linear time' do
      text = "function f() { s(\"#{[0xE9].pack('U') * 100_000}\") }\n#{'x();' * 20_000}"
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(names(text)).to eq(['f'])
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 10
    end
  end
end
