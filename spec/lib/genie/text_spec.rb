# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Text do
  # Utility.SafeSplit (Utility.cs:782-844 R). The action-body forms are proven on Remix by
  # flow case t105_action_safesplit (`a;;echo b` drops `;echo b`, `\;` and `{...}` and "..."
  # protect, a leading space is kept).
  describe '.remix_safe_split' do
    def split(text) = described_class.remix_safe_split(text, ';')

    it 'never yields an empty piece: an empty segment folds into the next one' do
      expect(split('look;;south')).to eq(['look', ';south'])
      expect(split('a;;;b')).to eq(['a', ';', 'b'])
      expect(split(';a')).to eq([';a'])
      expect(split('a;')).to eq(['a'])
      expect(split(';')).to eq([';'])
      expect(split('')).to eq([])
    end

    it 'trims nothing' do
      expect(split(' a ; ;b')).to eq([' a ', ' ', 'b'])
    end

    it 'keeps quoted and braced separators and the delimiters themselves' do
      expect(split('echo "c;d";echo {e;f};x')).to eq(['echo "c;d"', 'echo {e;f}', 'x'])
    end

    it 'keeps an escaped separator, backslash included; a doubled backslash escapes nothing' do
      expect(split('g\\;h;i')).to eq(['g\\;h', 'i'])
      expect(split('g\\\\;h')).to eq(['g\\\\', 'h'])
      expect(split('g\\\\\\;h')).to eq(['g\\\\\\;h'])
    end

    it 'closes a string at any quote, escaped or not, and an escaped quote opens none' do
      expect(split('"a\\";b')).to eq(['"a\\"', 'b'])
      expect(split('\\"a;b')).to eq(['\\"a', 'b'])
    end

    it 'lets a stray } drive the depth negative, so nothing after it splits' do
      expect(split('}x;y;{z')).to eq(['}x;y;{z'])
      expect(split('a;}b;c')).to eq(['a', '}b;c'])
    end

    it 'honours the separator argument' do
      expect(described_class.remix_safe_split('a|b;c', '|')).to eq(['a', 'b;c'])
    end
  end

  # Every expected value below was confirmed against Genie4's real Utility.ParseArgs
  # via the differential oracle (genie-port-lab/oracle, `parseargs` mode). These are
  # regressions for divergences the pre-port char-buffer implementation got wrong.
  describe '.parse_args' do
    it 'splits on spaces and collapses leading/trailing/multiple spaces' do
      expect(described_class.parse_args('a b c')).to eq(%w[a b c])
      expect(described_class.parse_args('  a   b  ')).to eq(%w[a b])
    end

    it 'returns [] for an empty string' do
      expect(described_class.parse_args('')).to eq([])
    end

    it 'strips wrapping double quotes but not interior/unbalanced ones' do
      expect(described_class.parse_args('"hello world"')).to eq(['hello world'])
      expect(described_class.parse_args('a"b"c')).to eq(['a"b"c'])
      expect(described_class.parse_args('"hello')).to eq(['"hello'])
    end

    it 'strips wrapping single quotes but not interior/unbalanced ones' do
      expect(described_class.parse_args("'hello'")).to eq(['hello'])
      expect(described_class.parse_args("a'b")).to eq(["a'b"])
    end

    it 'strips both wrapping layers when a token is single- and double-quoted' do
      expect(described_class.parse_args(%q("'x'"))).to eq(['x'])
    end

    it 'raises on a lone-quote token (matches Genie AddArrayItem throw)' do
      expect { described_class.parse_args('"') }.to raise_error(Lich::Genie::Error)
      expect { described_class.parse_args("'") }.to raise_error(Lich::Genie::Error)
      expect { described_class.parse_args('a "') }.to raise_error(Lich::Genie::Error)
    end

    it 'treats a pair of quotes as one empty token' do
      expect(described_class.parse_args('""')).to eq([''])
      expect(described_class.parse_args("''")).to eq([''])
    end

    it 'keeps backslash escapes literally and does not split on an escaped space' do
      expect(described_class.parse_args('a\\ b')).to eq(['a\\ b'])
      expect(described_class.parse_args('a\\')).to eq(['a\\'])
    end

    it 'keeps a backslash-escaped brace/quote and the backslash itself' do
      expect(described_class.parse_args('a\\{b}')).to eq(['a\\{b}'])
      expect(described_class.parse_args('\\{a b\\}')).to eq(['\\{a', 'b\\}'])
    end

    it 'does not treat tab as a delimiter (Genie splits on space only)' do
      expect(described_class.parse_args("a\tb")).to eq(["a\tb"])
    end

    it 'strips outer braces, keeps inner, and treats a brace as a token boundary' do
      expect(described_class.parse_args('{a b} c')).to eq(['a b', 'c'])
      expect(described_class.parse_args('{a{b}c}')).to eq(['a{b}c'])
      expect(described_class.parse_args('x{y}z')).to eq(%w[x y z])
      expect(described_class.parse_args('{a}{b}')).to eq(%w[a b])
    end

    it 'yields one empty token for empty braces' do
      expect(described_class.parse_args('{}')).to eq([''])
    end

    it 'lets a stray } drive depth negative so later spaces stop splitting' do
      expect(described_class.parse_args('a}b c')).to eq(['a}b c'])
    end

    it 'keeps quote toggling active inside braces (a } inside quotes does not close)' do
      expect(described_class.parse_args('{a"}"b}')).to eq(['a"}"b'])
    end

    it 'unclosed open brace keeps its literal brace and stops splitting' do
      expect(described_class.parse_args('a{b')).to eq(['a', '{b'])
      expect(described_class.parse_args('{a b')).to eq(['{a b'])
    end

    it 'replaces _ with space in every token but the first when underscore flag set' do
      expect(described_class.parse_args('a_b c_d', treat_underscore_as_space: true))
        .to eq(['a_b', 'c d'])
      expect(described_class.parse_args('a_b c_d')).to eq(%w[a_b c_d])
    end
  end

  # GetKeywordString / GetArgumentString Trim() the row with .NET's whitespace set first
  # (Utility.cs:957-983 R).
  describe '.keyword_string / .argument_string' do
    let(:nbsp) { [0xA0].pack('U') }

    it 'trims .NET whitespace (NBSP) before splitting at the first space' do
      expect(described_class.keyword_string("#{nbsp}put a b#{nbsp}")).to eq('put')
      expect(described_class.argument_string("#{nbsp}put a b#{nbsp}")).to eq('a b')
    end

    it 'keeps a NUL, which Ruby strip would remove' do
      expect(described_class.keyword_string("\0put a")).to eq("\0put")
      expect(described_class.argument_string("put a\0")).to eq("a\0")
    end

    it 'does not re-trim the argument and returns "" with no space' do
      expect(described_class.argument_string("  put   a  ")).to eq('  a')
      expect(described_class.argument_string('put')).to eq('')
      expect(described_class.keyword_string("\tput\t")).to eq('put')
    end
  end

  # .NET String.Trim (char.IsWhiteSpace), used by TriggerParse/EvalMatch.
  # The evaluators' boundary: the text .NET would hold after decoding.
  describe '.net_string' do
    fffd = [0xFFFD].pack('U')

    it 'returns ASCII and valid UTF-8 text itself' do
      ascii = 'x'.b
      utf8 = "caf#{[0xE9].pack('U')}"
      expect([described_class.net_string(ascii), described_class.net_string(utf8)]).to eq(['x', utf8])
      expect(described_class.net_string(ascii)).to equal(ascii)
      expect(described_class.net_string(nil)).to eq('')
    end

    it 'decodes invalid UTF-8 and raw bytes as UTF-8, each bad sequence one U+FFFD' do
      expect(described_class.net_string([0x35, 0xFF].pack('C*').force_encoding(Encoding::UTF_8))).to eq("5#{fffd}")
      raw = [0x61, 0xC3, 0xA9, 0xFF].pack('C*') # BINARY: a valid "e acute" and a bad byte
      expect(described_class.net_string(raw)).to eq("a#{[0xE9].pack('U')}#{fffd}")
      expect(described_class.net_string(raw).encoding).to eq(Encoding::UTF_8)
    end

    it 'transcodes another encoding to UTF-8' do
      latin1 = [0x63, 0xE9].pack('C*').force_encoding(Encoding::ISO_8859_1)
      expect(described_class.net_string(latin1)).to eq("c#{[0xE9].pack('U')}")
    end
  end

  describe '.net_trim' do
    let(:nbsp) { [0xA0].pack('U') }
    let(:ideographic) { [0x3000].pack('U') }

    it 'trims the Unicode whitespace .NET trims (NBSP, U+3000, U+2000-200A, ...)' do
      wide = [0x2003, 0x2028, 0x85].pack('U*')
      expect(described_class.net_trim("#{nbsp}\t #{wide}a b#{ideographic}\r\n")).to eq('a b')
    end

    it 'keeps NUL, which Ruby strip removes but .NET Trim does not' do
      expect(described_class.net_trim("\0 a \0")).to eq("\0 a \0")
      expect(" a \0".strip).to eq('a') # the Ruby behaviour this guards against
    end

    it 'keeps inner whitespace and handles empty/nil' do
      expect(described_class.net_trim('  a   b  ')).to eq('a   b')
      expect(described_class.net_trim('')).to eq('')
      expect(described_class.net_trim(nil)).to eq('')
    end

    it 'trims only ASCII whitespace from bytes that are not valid UTF-8, without raising' do
      ff = [0xFF].pack('C')
      fe = [0xFE].pack('C')
      bad = "\t#{ff} a #{fe} ".b.force_encoding('UTF-8')
      expect(described_class.net_trim(bad).bytes).to eq("#{ff} a #{fe}".b.bytes)
      expect(described_class.net_trim(" #{ff} ".b)).to eq(ff)
    end
  end

  # String.TrimStart() ($roomobjs, Game.cs:1786-1795 R).
  describe '.net_trim_start' do
    it 'trims .NET white space at the start only, NUL kept, Unicode spaces trimmed' do
      nbsp = [0xA0].pack('U')
      expect(described_class.net_trim_start(" \t\r\n  x  ")).to eq('x  ')
      expect(described_class.net_trim_start("\0 x")).to eq("\0 x")
      expect(described_class.net_trim_start("#{nbsp} x")).to eq('x')
    end

    it 'trims only ASCII white space on invalid UTF-8' do
      ff = [0xFF].pack('C')
      bad = " #{ff} x".b.force_encoding('UTF-8')
      expect(described_class.net_trim_start(bad).bytes).to eq([0xFF, 0x20, 0x78])
    end
  end

  # Utility.ArrayToString(oList, iStartIndex) (Utility.cs:766-780 R; #config's value).
  describe '.array_to_string' do
    it 'joins from the start index, a space after each item that is not blank, then trims' do
      expect(described_class.array_to_string(%w[config key a b], 2)).to eq('a b')
      expect(described_class.array_to_string(['c', 'k', 'a', '', 'b'], 2)).to eq('a b')
      expect(described_class.array_to_string(['c', 'k', 'a', ' ', 'b'], 2)).to eq('a  b') # " " kept, no extra space
      expect(described_class.array_to_string(['c', 'k', ' x '], 2)).to eq('x')
    end

    it 'is empty past the end or for nothing but blanks' do
      expect(described_class.array_to_string(%w[c k], 2)).to eq('')
      expect(described_class.array_to_string(%w[c], 5)).to eq('')
      expect(described_class.array_to_string(['c', 'k', '', '  '], 2)).to eq('')
    end
  end

  # Utility.Trim (Utility.cs:847-861 R): what PrintTextToWindow hands TriggerParse.
  describe '.trim_crlf' do
    it 'trims CR and LF from both ends and nothing else' do
      expect(described_class.trim_crlf("\r\n   Last login\t \r\n")).to eq("   Last login\t ")
      expect(described_class.trim_crlf("a\r\nb\n")).to eq("a\r\nb")
      expect(described_class.trim_crlf("\r\n\n")).to eq('')
      expect(described_class.trim_crlf("#{[0xA0].pack('U')}x\r")).to eq("#{[0xA0].pack('U')}x")
    end

    it 'handles an invalid byte sequence without raising, keeping its encoding' do
      text = described_class.trim_crlf([0xFF, 0x78, 0x0D, 0x0A].pack('C*').force_encoding(Encoding::UTF_8))
      expect([text.bytes, text.encoding]).to eq([[0xFF, 0x78], Encoding::UTF_8])
    end
  end
  # String.ToUpper/ToLower (en-US) map one character to one character (genieoracle
  # toupper()/tolower() answers).
  describe '.net_upcase / .net_downcase' do
    u = ->(*codes) { codes.pack('U*') }

    it 'keeps the length: sharp s, ligatures and n-apostrophe stay; ypogegrammeni maps to one character' do
      expect(described_class.net_upcase(u.call(0x1F80, 0xDF, 0xFB01, 0x149))).to eq(u.call(0x1F88, 0xDF, 0xFB01, 0x149))
      expect(described_class.net_upcase(u.call(0x131, 0x17F, 0x1C5))).to eq('IS' + u.call(0x1C4))
      expect(described_class.net_upcase('abc')).to eq('ABC')
    end

    it 'lowercases the dotted capital I to a plain i' do
      expect(described_class.net_downcase(u.call(0x130, 0x3A3, 0x1F88))).to eq(u.call(0x69, 0x3C3, 0x1F80))
      expect(described_class.net_downcase("ABC#{u.call(0xC9)}")).to eq("abc#{u.call(0xE9)}")
    end

    it 'leaves invalid UTF-8 to the byte-wise ASCII mapping' do
      broken = [0xFF, 0x61].pack('C*').force_encoding(Encoding::UTF_8)
      expect(described_class.net_upcase(broken).bytes).to eq([0xFF, 0x41])
    end
  end
end
