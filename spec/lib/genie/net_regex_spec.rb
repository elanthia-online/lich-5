# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# .NET Regex validity and semantics on Onigmo. Every validity expectation below is the
# Remix v4.2.4 answer from the genieoracle probe `matchre("", "<pattern>")` (.NET `new Regex`),
# recorded 2026-10-19; the corpus-wide gate is the genie-port lab's reference/harvest_regex.rb
# (6934 harvested patterns, 0 compile-ability diffs).
RSpec.describe Lich::Genie::NetRegex do
  def compiles?(pattern) = described_class.valid?(pattern)

  describe '.valid? -- patterns .NET rejects but Onigmo accepts raw' do
    {
      'unknown letter escape'   => ['x\\q', 'x\\h', 'x\\K', 'x\\Q', 'x\\y', 'x\\R', 'x\\X', 'x\\E', 'x\\g'],
      'escaped underscore'      => ['x\\_', '[\\_]'],
      'class-only rejections'   => ['[\\z]', '[\\A]', '[\\B]', '[\\G]', '[\\Z]', '[\\k]', '[\\8]', '[\\9]'],
      'short hex / bad control' => ['\\x4', '\\x4g', '\\c1'],
      'nested quantifier'       => ['a++', 'a*+', 'a?+', 'a**', 'a{2}+', 'a{2}*', 'a{2,}+', 'a???', 'a{2}??', 'a+?*', '(?:a)++', 'x{2}{3}'],
      'incomplete \\p'          => ['\\p', '\\pL']
    }.each do |kind, patterns|
      it "rejects #{kind}" do
        expect(patterns.select { |p| compiles?(p) }).to eq([])
      end
    end
  end

  describe '.valid? -- patterns both engines accept' do
    it 'accepts the escapes and quantifiers .NET knows' do
      ok = ['a+?', 'a*?', 'a??', 'a{2}', 'a{2}?', 'a{2,}', 'a{x}', '\\x41', '\\cA', '\\p{L}', '\\P{Lu}', '[\\1]', '[\\7]',
            '\\0', '(?<n>a)\\k<n>', '\\-', '[\\b]', 'x\\A\\B\\G\\Z\\z', '[\\a\\e\\f\\n\\r\\t\\v]', '(?i)a(?-i)b']
      expect(ok.reject { |p| compiles?(p) }).to eq([])
    end

    it 'never raises on bytes that are not valid UTF-8 (ValidateRegExp catches every exception)' do
      expect(compiles?("#{[0xFF].pack('C')}[ab".b.force_encoding('UTF-8'))).to be(false)
    end

    it 'rejects a trailing backslash and an unbalanced group like both engines' do
      expect([+'abc\\', '(a', 'a)', '[a'].select { |p| compiles?(p) }).to eq([])
    end
  end

  describe '.translate -- .NET meaning kept under Onigmo' do
    it 'escapes a hyphen that follows a class shorthand (ScrollSorter.cmd:46 [\\w-\'])' do
      expect(described_class.translate("([\\w-']+)")).to eq("([\\w\\-']+)")
      regex = described_class.compile("^@(?:an?|some).* ([\\w-']+)")
      expect(regex.match("@a tattered o'brien-scroll")[1]).to eq("o'brien-scroll")
    end

    it 'keeps a hyphen literal after \\d, \\s and \\p{..} too, and leaves a closing [\\w-] alone' do
      expect(described_class.compile('[\\d-z]+').match('1-z9')[0]).to eq('1-z9')
      expect(described_class.compile('[\\p{L}-]+').match('ab-c!')[0]).to eq('ab-c')
      expect(described_class.translate('[\\w-]')).to eq('[\\w-]')
    end

    it 'treats [ and && inside a class and a leading ] as literals, like .NET' do
      expect(described_class.compile('[[]').match('a[b')[0]).to eq('[')
      expect(described_class.compile('[a&&b]+').match('x&ab&')[0]).to eq('&ab&')
      expect(described_class.compile('[]a]+').match('x]a]')[0]).to eq(']a]')
    end

    it 'keeps {,n} literal (.NET) instead of a {0,n} quantifier (Onigmo)' do
      regex = described_class.compile('x{,3}')
      expect(regex.match?('x{,3}')).to be(true)
      expect(regex.match?('x')).to be(false)
    end

    # .NET reads `{n}?` as the lazy form of exactly-n (still n); Onigmo's Ruby syntax reads it
    # as `(?:x{n})?`. genieflow probe: matchre ^ba{2}?$ skips "b" and matches "baa".
    it 'keeps x{n}? an exactly-n quantifier (.NET lazy) instead of optional (Onigmo)' do
      regex = described_class.compile('^ba{2}?$')
      expect(regex.match?('b')).to be(false)
      expect(regex.match?('baa')).to be(true)
      expect(described_class.compile('a{1,}?').match('aaa')[0]).to eq('a') # ranges stay lazy
      expect(described_class.compile('a{1,3}?').match('aaa')[0]).to eq('a')
      expect(compiles?('a{2}??')).to be(false) # still a nested quantifier in .NET
      expect(compiles?('a{2}?+')).to be(false)
    end

    it 'leaves a lookbehind Onigmo compiles untouched (captures keep their text)' do
      expect(described_class.translate('(?<=(a))b')).to eq('(?<=(a))b')
      expect(described_class.compile('(?<=(a))b').match('ab').to_a).to eq(%w[b a])
    end

    it 'distributes the droughtman.cmd:273 capturing lookbehind and keeps .NET group numbers' do
      regex = described_class.compile('(?<=(field|fluted|full|half) )\\bplate\\b|(helm)')
      expect(regex.match('a suit of full plate').to_a).to eq(['plate', '', nil])
      expect(regex.match('a plate')).to be_nil
      expect(regex.match('rusty plate')).to be_nil
      expect(regex.match('iron helm').to_a).to eq(['helm', nil, 'helm']) # helm is still group 2, as in .NET
    end

    it 'rewrites a negative lookbehind with alternation the same way' do
      regex = described_class.compile('(?<!(a|bb) )x(\\w)')
      expect(regex.match('bb xy')).to be_nil
      expect(regex.match('cc xy').to_a).to eq(['xy', '', 'y'])
    end

    it 'compiles the whole droughtman.cmd:273 ARMOR pattern and matches like Remix (flow t77)' do
      corpus = File.expand_path('../../fixtures/genie/flow/t77_net_regex.cmd', __dir__)
      pattern = File.readlines(corpus, chomp: true).find { |l| l.start_with?('matchre ARMOR ') }.sub('matchre ARMOR ', '')
      expect(described_class.compile(pattern).match('You see a suit of full plate here.')[1]).to eq('plate')
    end

    it 'honours ignore_case' do
      expect(described_class.compile('orc', ignore_case: true).match?('An ORC')).to be(true)
      expect(described_class.compile('orc').match?('An ORC')).to be(false)
    end

    it 'keeps a quantifier after a rewritten capturing lookbehind on the lookbehind (not on its placeholder)' do
      # genieoracle rxmatch: (?<=(a|bb))?c on "xc" -> ["c", ""] (the lookbehind is optional)
      expect(described_class.translate('(?<=(a|bb))?c')).to eq('(?:(?<=(?:a|bb))())?c')
      expect(described_class.compile('(?<=(a|bb))?c').match('xc').to_a.map(&:to_s)).to eq(['c', ''])
    end
  end

  # Every expectation in the two groups below is the genieoracle `rxmatch` answer (Remix
  # build: new Regex(p, Multiline [| IgnoreCase])), recorded 2026-10-19; the randomized gate is
  # the lab's reference/fuzz_netregex.rb (0 diffs over 6 seeds x ~6000).
  describe 'inline options (?i) / (?-i) mid-branch: .NET scoping' do
    def groups(pattern, text, ignore_case: false)
      described_class.compile(pattern, ignore_case: ignore_case).match(text)&.to_a&.map(&:to_s)
    end

    it 'carries an option into the later alternatives of its group, not swallowing them (p21, flow t112)' do
      expect(described_class.translate('^a(?i)b|^c')).to eq('^a(?i:b)|(?i:^c)')
      expect(groups('^a(?i)b|^c', 'C')).to eq(['C'])
      expect(groups('^a(?i)b|^c', 'c')).to eq(['c'])
      expect(groups('^(?i)x(?-i)y|^q', 'Q')).to be_nil # the later (?-i) is carried too
      expect(groups('^(?i)x(?-i)y|^q', 'q')).to eq(['q'])
    end

    it 'ends the option with its enclosing group (p32, flow t113)' do
      expect(described_class.translate('^(a(?i)b|c)d$')).to eq('^(a(?i:b)|(?i:c))d$')
      expect(groups('^(a(?i)b|c)d$', 'Cd')).to eq(%w[Cd C])
      expect(groups('^(a(?i)b|c)d$', 'CD')).to be_nil
    end

    it 'keeps group numbers (the scopes are non-capturing)' do
      expect(groups('(a)(?i)(b)|(c)', 'C')).to eq(['C', '', '', 'C'])
    end

    it 'reads the corpus shape: (?i)name(?-i) inside one branch of many (flow t114)' do
      pattern = '^You notice (?i)\\bbob\\w*(?-i) attempting|(?i)\\bbob\\w*(?-i) just arrived\\.$|turns a cold stare\\.$'
      expect(groups(pattern, 'BOB just arrived.')).to eq(['BOB just arrived.'])
      expect(groups(pattern, 'It turns a cold stare.')).to eq(['turns a cold stare.'])
      expect(groups(pattern, 'IT TURNS A COLD STARE.')).to be_nil
    end

    it 'maps the option letters: s -> Onigmo m, m dropped (Multiline is always on), and validates like .NET' do
      expect(described_class.translate('(?s)a.b')).to eq('(?m:a.b)')
      expect(described_class.translate('(?im-s)a')).to eq('(?i-m:a)')
      expect(described_class.translate('(?s-i:a.)')).to eq('(?m-i:a.)')
      expect(compiles?('(?)a')).to be(false) # .NET: Unrecognized grouping construct
      expect(groups('(?-)a', 'a')).to eq(['a'])
      expect(compiles?('a(?i)*')).to be(false) # quantifier following nothing, both engines
    end

    it 'copies a (?#...) comment through without reading | or ( inside it' do
      expect(groups('(?#a|b)c', 'c')).to eq(['c'])
      expect(groups('(?#a|b)c', 'a')).to be_nil
      expect(groups('(?#a(b)c', 'c')).to eq(['c'])
      expect(compiles?('(?#abc')).to be(false)
      # what would be .NET-invalid outside a comment is text inside one
      expect(['(?#a++)c', '(?#\\q)c', '(?#[)c'].map { |p| groups(p, 'xc') }).to eq([['c'], ['c'], ['c']])
      expect(compiles?('(?#(?i)x)c')).to be(false) # the comment ends at the first ')'
    end
  end

  describe 'variable-length lookbehind (emulated, never an abort)' do
    def groups(pattern, text, ignore_case: false)
      described_class.compile(pattern, ignore_case: ignore_case).match(text)&.to_a&.map(&:to_s)
    end

    # GenieHunter hunt.cmd:309 through %critters (flow t111): .NET-valid, Onigmo-invalid.
    hunter = '(goblin|spirit|(?<!arisen \\S+ )zombie\\b|zombie (head-splitter|mauler)) attempting'

    it 'compiles the hunt.cmd:309 alternation and matches it like .NET' do
      expect(described_class.compile(hunter)).to be_a(described_class::Emulated)
      expect(groups(hunter, 'An arisen big zombie attempting')).to be_nil
      expect(groups(hunter, 'A big zombie attempting')).to eq(['zombie attempting', 'zombie', ''])
      expect(groups(hunter, 'An arisen zombie mauler attempting')).to eq(['zombie mauler attempting', 'zombie mauler', 'mauler'])
    end

    it 'answers positive and negative lookbehinds at every candidate start' do
      expect(groups('(?<=a+)b', 'xaab')).to eq(['b'])
      expect(groups('(?<=a+)b', 'xb')).to be_nil
      expect(groups('(?<!a+)b', 'aab b')).to eq(['b']) # first candidate fails, the next one holds
      expect(groups('(?<=\\bz+ )wolf', 'a zzwolf zz wolf')).to eq(['wolf'])
      expect(described_class.compile('(?<!a+)b', ignore_case: false).match('aab b').begin(0)).to eq(4)
    end

    it 'tries the next alternative at the same start when a lookbehind fails there (backtracking)' do
      expect(groups('(?<!a+)b|bc', 'abc')).to eq(['bc'])
    end

    it 'keeps group numbering and measures the lookbehind at its fixed distance from the start' do
      expect(groups('(x)(?<=x\\S+)(y)|(z)', 'xy')).to be_nil
      expect(groups('(x)(?<=x\\S+)(y)|(z)', 'z')).to eq(['z', '', '', 'z'])
      expect(groups('^You see (?<!big )(?<=\\w+ )wolf', 'You see wolf')).to eq(['You see wolf'])
      expect(groups('^You see (?<!big )(?<=\\w+ )wolf', 'You see a big wolf')).to be_nil
    end

    it 'gives the lookbehind body the whole line (anchors) and the case rules in force at its spot' do
      expect(groups('(?<=^\\w+ )b', 'aa b')).to eq(['b'])
      expect(groups('(?<=^\\w+ )b', 'aa c b')).to be_nil
      expect(groups('(?<=X\\S+)b', 'xAB', ignore_case: true)).to eq(['B'])
      expect(groups('(?<=X\\S+)b', 'xAB')).to be_nil
      expect(groups('(?i)(?<=X\\S+)b', 'xAb')).to eq(['b'])
      expect(groups('(?-i)(?<=X\\S+)b', 'xab', ignore_case: true)).to be_nil
      expect(groups('(?i:(?<=X\\S+)b)', 'xAb')).to eq(['b'])        # a scoped option group
      expect(groups('(?i)((?<=X\\S+)b)', 'xAb')).to eq(%w[b b])     # inherited by a nested group
    end

    it 'lets the body see the text after its end too (\\b, lookahead), like .NET' do
      expect(groups('(?<=a+\\b)c', 'aac')).to be_nil
      expect(groups('(?<=a+\\b)\\Wc', 'aa c')).to eq([' c'])
      expect(groups('(?<=a+(?=c))c', 'aac')).to eq(['c'])
    end

    it 'handles a quantified lookbehind (zero-width, optional) and an empty subject' do
      expect(groups('(?<=a+)?b', 'cb')).to eq(['b'])
      expect(groups('(?<!a+)$', '')).to eq([''])
      expect(groups('(?<=a+)$', '')).to be_nil
    end

    it 'still rejects a .NET-invalid pattern that also has a variable-length lookbehind' do
      expect(compiles?('(?<=a+)b++')).to be(false)
      expect(compiles?('(?<=a+)(b')).to be(false)
      expect(compiles?('(?<=a+\\q)b')).to be(false)
    end
  end

  # Every expectation is the genieoracle `rxmatch` answer (Remix build), recorded 2026-10-19.
  describe 'variable-length lookbehind: distance per alternative, negation, soundness' do
    def groups(pattern, text, ignore_case: false)
      described_class.compile(pattern, ignore_case: ignore_case).match(text)&.to_a&.map(&:to_s)
    end

    # hunt.cmd:309's %critters: `(armored )?warklin` (variable width) in an EARLIER alternative
    # than `(?<!arisen \S+ )zombie`. A '|' starts the distance over.
    critters = '(angiswaerd hatchling|(armored )?warklin( mauler)?|(?<!red )\\bbear\\b|' \
               '(?<!arisen \\S+ )zombie(?!\\s)|zombie (head-splitter|mauler)) attempting'

    it 'emulates a lookbehind that follows a variable-width part of an EARLIER alternative (hunt.cmd:309)' do
      expect(described_class.compile(critters)).to be_a(described_class::Emulated)
      expect(groups(critters, 'An arisen zombie mauler attempting'))
        .to eq(['zombie mauler attempting', 'zombie mauler', '', '', 'mauler'])
      expect(groups(critters, 'An armored warklin mauler attempting'))
        .to eq(['armored warklin mauler attempting', 'armored warklin mauler', 'armored ', ' mauler', ''])
      expect(groups(critters, 'An arisen big zombie attempting')).to be_nil
      expect(groups(critters, 'A red bear attempting')).to be_nil
    end

    it 'measures from the start of the lookbehind\'s own alternative, at any nesting level' do
      expect(groups('a\\w+|(?<!x\\S+ )b', 'z b')).to eq(['b'])
      expect(groups('a\\w+|(?<!x\\S+ )b', 'xy b')).to be_nil
      expect(groups('(?:a+|b)|(?<!x\\S+ )c', 'z c')).to eq(['c'])
      expect(groups('(?:a+|b)|(?<!x\\S+ )c', 'xy c')).to be_nil
      expect(groups('(a+|(?<!x\\S+ )c)', 'xy c')).to be_nil
      expect(groups('x+|b(?<=a+b)y|c', 'aby')).to eq(['by'])
      expect(groups('(?<!x\\S+ )c\\w+', 'cde')).to eq(['cde']) # a variable width AFTER it is fine
    end

    it 'still refuses a lookbehind with a variable-width part before it on its own path' do
      { '(a+|b)(?<!x\\S+ )c'    => 'after a variable-width part of the pattern',
        '(?:(a)|b)*(?<!q\\w+)z' => 'after a variable-width part of the pattern',
        'a+(?:b|(?<=a+)c)'      => 'after a variable-width part of the pattern' }.each do |pattern, why|
        compiled = described_class.compile(pattern)
        expect([pattern, compiled.class, compiled.reason]).to eq([pattern, described_class::Unsupported, "a variable-length lookbehind #{why}"])
      end
    end

    # The candidate search must stay a superset under a negative lookaround.
    it 'answers a lookbehind inside a negative lookahead (odd negation depth)' do
      expect(groups('(?!(?<=b\\w+)z)z', 'abz')).to eq(['z'])
      expect(groups('(?!(?<=b\\w+)z)z', 'bz')).to eq(['z'])
      expect(groups('(?!(?<=b\\w+)z)z', 'bxz')).to be_nil
      expect(groups('(?=(?<=a\\w+)z)z\\w', 'azz')).to be_nil
      expect(groups('(?=(?<=a\\w+)z)z\\w', 'axzz')).to eq(['zz'])
    end

    # Fixer's own fuzz (gen.rb opt profile): inside an atomic group a lookbehind that holds can
    # commit the group to a branch that fails later, so the relaxed variant is no superset;
    # every start is then tried.
    it 'answers a lookbehind inside an atomic group or a lookahead (no relaxed candidate search there)' do
      expect(groups('(?>(?<=(?i)ARISEN\\w*)|b){1}\\d', 'zb1z ')).to eq(['b1'])
      expect(groups('(?>(?<=(?i)ARISEN\\w*)|b){1}\\d', 'arisenb1')).to eq(['1'])
      expect(groups('(?>(?<!x\\w*)|b)\\d', 'xb1')).to eq(['b1'])
      expect(groups('(?=((?<=a\\w+)|x))\\1y', 'xy')).to eq(%w[xy x]) # a lookahead commits its captures too
    end

    # Only a plain ( or (?: alternation group is distributed to the top level.
    it 'never distributes a lookaround, scoped-option, atomic or named group inside a lookbehind' do
      expect(groups('(?<=x(?i:a|bb))c', 'xBBc')).to eq(['c'])
      expect(groups('(?<=x(?i:a|bb))c', 'xbc')).to be_nil
      expect(groups('(?<=x(?!a|bb)\\w)c', 'xzc')).to eq(['c'])
      expect(groups('(?<=x(?!a|bb)\\w)c', 'xac')).to be_nil
      expect(described_class.compile('(?<=x(?<n>a|bb))c')).to be_a(described_class::Unsupported)
      expect(described_class.compile('(?<=x(?>a|bb))c')).to be_a(described_class::Unsupported)
    end

    # .NET runs a lookbehind body right to left; atomic groups and
    # back-references read differently left to right, so they are not emulated.
    {
      '(?<=(?>a+)a)b'           => 'an atomic group',
      '(?<=(?<n>a)\\k<n>\\w*)x' => 'a named group',
      '(?<=\\1(a)\\w*)x'        => 'a back-reference',
      '(a)(?<=\\1\\w+)x'        => 'a back-reference',
      '(?<=x(?<n>a|bb)\\w*)c'   => 'a named group'
    }.each do |pattern, construct|
      it "#{pattern} -> Unsupported (#{construct} in an emulated lookbehind)" do
        compiled = described_class.compile(pattern)
        expect([compiled.class, compiled.reason])
          .to eq([described_class::Unsupported, "a variable-length lookbehind containing #{construct}"])
      end
    end

    # The placeholder group captures "" where .NET captured the lookbehind text.
    it 'refuses a back-reference to a capture that a rewritten lookbehind lost' do
      ['(?<=(field|full) )plate \\1', '(?<=(a|bb)\\w+)c(\\1)', '(?<=(a|bb) )c\\k<1>'].each do |pattern|
        compiled = described_class.compile(pattern)
        expect([pattern, compiled.class, compiled.reason])
          .to eq([pattern, described_class::Unsupported, 'a back-reference to a capture inside a rewritten lookbehind'])
      end
      expect(groups('(?<=(field|full) )(plate)\\2', 'full plateplate')).to eq(['plateplate', '', 'plate']) # not group 1
    end

    # .NET rejects a reference to an undefined group; never "Unsupported".
    it 'aborts (raises) on a .NET-invalid emulated lookbehind instead of calling it Unsupported' do
      expect { described_class.compile('(?<=\\2\\w+)x') }.to raise_error(RegexpError)
      expect(compiles?('(?<=\\2\\w+)x')).to be(false)
      expect(compiles?('(?<=\\1(a)\\w*)x')).to be(true) # a forward reference is defined in .NET
    end

    # No cap on the number of variable-length lookbehinds.
    it 'emulates any number of variable-length lookbehinds' do
      pattern = "#{'(?<=a+)' * 7}b"
      expect(described_class.compile(pattern)).to be_a(described_class::Emulated)
      expect(groups(pattern, 'aab')).to eq(['b'])
      expect(groups(pattern, 'xb')).to be_nil
    end

    # Mutation guards: the next candidate start and the \G anchor.
    it 'retries from the very next start after a failed candidate' do
      expect(groups('(?<=c\\w*)\\w', 'cab')).to eq(['a'])
    end

    it 'anchors the decided variant at the candidate start' do
      expect(groups('(?<!x\\w* )b|(?<!y\\w* )c', 'x b y c')).to be_nil
      expect(groups('(?<!x\\w* )b|(?<!y\\w* )c', 'x b z c')).to eq(['c'])
    end

    it 'matches from a start position with the text before it still visible to the lookbehind' do
      compiled = described_class.compile('(?<!x\\S+ )\\w')
      expect(compiled.match('xy ab', 3)&.begin(0)).to eq(4)
      expect(compiled.match('ab', 2)).to be_nil
    end
  end

  describe 'compile cache' do
    it 'compiles a pattern once per ignore_case and re-raises a cached .NET rejection every time' do
      first = described_class.compile('(?<!wp3r2 \\S+ )cache')
      expect(described_class.compile('(?<!wp3r2 \\S+ )cache')).to equal(first)
      expect(described_class.compile('(?<!wp3r2 \\S+ )cache', ignore_case: true)).not_to equal(first)
      2.times { expect { described_class.compile('wp3r2++') }.to raise_error(RegexpError, /Nested quantifier/) }
    end

    it 'compiles once across matchre\'s validate-then-compile and #trigger\'s three checks' do
      pattern = '(?<!wp3r2once \\S+ )x'
      allow(described_class).to receive(:compile_uncached).and_call_original
      expect(described_class.valid?(pattern)).to be(true)
      described_class.compile(pattern)
      expect(Lich::Genie::Triggers.valid_pattern?(pattern)).to be(true)
      expect(Lich::Genie::Triggers.unsupported(pattern)).to be_nil
      expect(described_class).to have_received(:compile_uncached).once
    end

    # The display gags/substitutes need a bounded match on Lich's parser thread.
    describe '#with_timeout' do
      let(:pattern) { '(?<!z\\S+ )(a+)+\\1b' }

      it 'returns a private timed copy that matches like the shared one; the shared one keeps no timeout' do
        shared = described_class.compile(pattern)
        timed = shared.with_timeout(0.5)
        expect([timed.timeout, shared.timeout, timed.equal?(shared)]).to eq([0.5, nil, false])
        expect([timed.match?('xaab'), timed.match?('zq aab'), shared.match?('zq aab')]).to eq([true, false, false])
      end

      it 'raises Regexp::TimeoutError from a catastrophic internal regex' do
        timed = described_class.compile(pattern).with_timeout(0.05)
        expect { timed.match?("#{'a' * 34}!") }.to raise_error(Regexp::TimeoutError)
      end

      it 'stops the walk over candidate starts at its deadline' do
        timed = described_class.compile('(?<=x\\S*)q').with_timeout(1.0)
        clock = [0.0, 0.5, 2.0].each
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { clock.next }
        expect(timed.match('xq')).not_to be_nil # (first deadline check at 0.5 s: in time)
        clock = [0.0, 0.5, 2.0].each
        expect { timed.match('q q q') }.to raise_error(Regexp::TimeoutError) # no x: every start fails
      end
    end

    it 'gives every thread the same answers from one shared Emulated (lazy regexes built under a lock)' do
      shared = described_class.compile('(?<!wp3r2t\\w* )(\\w)(?<=\\w+)')
      lines = ['wp3r2t a b', 'x y', 'wp3r2tt q', '', 'zz']
      expected = lines.map { |l| shared.match(l)&.to_a }
      results = Array.new(6) { Thread.new { Array.new(50) { lines.map { |l| shared.match(l)&.to_a } }.uniq } }.map(&:value)
      expect(results.uniq).to eq([[expected]])
    end
  end

  # Onigmo-only syntax .NET rejects (strict parity), and .NET-only syntax that now
  # translates or is Unsupported instead of aborting.
  describe '.NET grouping constructs and \\p{..} names' do
    it 'rejects Onigmo-only group syntax' do
      bad = ['(?a)x', '(?u)x', '(?d)x', '(?~a)', '(?ia)', '(?)', '(?<x-y>a)', '(?<-y>a)', '(?<a b>x)', '(?<x->a)',
             '(?<1a>x)', "(?'a-b'x)", '(?(a)b|c|d)', '(?(?#c)b|c)', '(?(1a)b|c)']
      expect(bad.select { |p| compiles?(p) }).to eq([])
    end

    it 'rejects \\p{..} names .NET does not know (scripts, POSIX, negation, wrong case)' do
      bad = ['\\p{^L}', '\\p{Alpha}', '\\p{Word}', '\\p{Hiragana}', '\\p{lu}', '\\p{LC}', '\\P{Greek}', '[\\p{Alnum}]']
      expect(bad.select { |p| compiles?(p) }).to eq([])
      expect(%w[Lu Ll Cn Zs Pd So].map { |c| compiles?("\\p{#{c}}") }.uniq).to eq([true])
    end

    it 'reads option letters case-insensitively like .NET' do
      expect(groups_of('(?I)a', 'A')).to eq(['A'])
      expect(groups_of('(?I:a)b', 'Ab')).to eq(['Ab'])
    end

    it 'translates a conditional on a group name, and keeps a numbered one' do
      expect(groups_of('(?<x>a)?(?(x)b|c)', 'c')).to eq(['c', nil])
      expect(groups_of('(?<x>a)?(?(x)b|c)', 'ab')).to eq(%w[ab a])
      expect(groups_of('(a)?(?(1)b|c)', 'c')).to eq(['c', nil])
      expect(compiles?('(?(1)a|b)')).to be(false) # undefined group: both reject
    end

    it 'keeps balancing groups, numbered names and expression conditionals as Unsupported (.NET-valid)' do
      { '(?<y>b)(?<x-y>a)' => 'a balancing group', '(b)(?<x-1>a)' => 'a balancing group',
        '(?<1>a)' => 'a numbered group name', '(?(?=a)ab|c)' => 'a conditional on an expression',
        '(?(x)a|b)' => 'a conditional on an expression', '(?<x>a)(?(<x>)b|c)' => 'a conditional on an expression' }
        .each do |pattern, reason|
          compiled = described_class.compile(pattern)
          expect([pattern, compiled.class, compiled.reason]).to eq([pattern, described_class::Unsupported, reason])
        end
    end

    def groups_of(pattern, text) = described_class.compile(pattern).match(text)&.to_a
  end

  describe 'Unsupported: .NET-valid, not expressible here -> registered, never fires, one warning' do
    {
      '(?:x(?<=a+)y)+' => 'a variable-length lookbehind inside a quantified group',
      '\\w+(?<=a+)y'   => 'a variable-length lookbehind after a variable-width part of the pattern',
      '(a)\\1(?<=a+)y' => 'a variable-length lookbehind after a variable-width part of the pattern',
      '(?n)(a)'        => 'the explicit-capture option n'
    }.each do |pattern, reason|
      it "#{pattern} -> #{reason}" do
        compiled = described_class.compile(pattern)
        expect(compiled).to be_a(described_class::Unsupported)
        expect(compiled.reason).to eq(reason)
        expect(compiles?(pattern)).to be(true) # .NET accepts it: never an "Invalid RegExp" abort
        expect([compiled.match('aaxy'), compiled.match?('aay')]).to eq([nil, false])
      end
    end

    it 'names the verb, the construct and the pattern in its warning' do
      expect(described_class.compile('\\w+(?<=a+)y').warning('action')).to eq(
        '[Genie: action pattern uses a variable-length lookbehind after a variable-width part of the pattern, ' \
        'which the in-Lich engine cannot match; it will never fire: \\w+(?<=a+)y]'
      )
    end
  end

  # .NET 10 compiles and matches 200,000 nested groups, even on a 1 MB thread. Onigmo recurses
  # once per level on the C stack: on a script thread about 1,500 levels raise SystemStackError,
  # and a second overflow on the same thread kills the process (SIGILL), so no rescue will do.
  # One thread per depth: before the cap each one overflowed (and two in one thread crashed).
  describe 'groups nested deeper than MAX_GROUP_DEPTH (.NET-valid, Onigmo never sees them)' do
    def nested(depth, open = '(') = "#{open * depth}a#{')' * depth}"
    def on_thread(&) = Thread.new(&).value

    let(:reason) { "groups nested more than #{described_class::MAX_GROUP_DEPTH} deep" }

    it 'is Unsupported on a script thread at any depth past the cap, never a stack error' do
      [1_500, 1_501, 5_000, 200_000].each do |depth|
        compiled = on_thread { described_class.compile(nested(depth)) }
        expect([depth, compiled.class, compiled.reason]).to eq([depth, described_class::Unsupported, reason])
        expect(on_thread { compiles?(nested(depth)) }).to be(true) # never an "Invalid RegExp" abort
      end
    end

    it 'survives several deep patterns on one thread (each one once overflowed Onigmo)' do
      results = on_thread { (1_500..1_504).map { |depth| described_class.compile(nested(depth)).class } }
      expect(results.uniq).to eq([described_class::Unsupported])
    end

    it 'compiles at the cap and counts every group kind, but not escaped, class or comment parens' do
      cap = described_class::MAX_GROUP_DEPTH
      expect(described_class.compile(nested(cap)).match('a')[0]).to eq('a')
      ['(', '(?:', '(?=', '(?<n>', '(?i:'].each do |open|
        compiled = described_class.compile("(#{nested(cap, open)})")
        expect([open, compiled.class]).to eq([open, described_class::Unsupported])
      end
      ["#{'\\(' * 300}a", "#{'[(]' * 300}a", "#{'(?#x)' * 300}a", "#{'(a)' * 300}"].each do |flat|
        expect([flat[0, 6], described_class.compile(flat)]).to match([flat[0, 6], an_instance_of(Regexp)])
      end
    end

    it 'names the depth in its warning' do
      expect(described_class.compile(nested(300)).warning('matchre'))
        .to start_with("[Genie: matchre pattern uses #{reason}, which the in-Lich engine cannot match; it will never fire: ((((")
    end
  end

  # Expectations: the rx oracle (.NET 8 Regex with Remix's options), 2026-10-19.
  describe 'emulated check form, cache bound, parse-aware scans' do
    def groups(pattern, text, ignore_case: false)
      described_class.compile(pattern, ignore_case: ignore_case).match(text)&.to_a&.map(&:to_s)
    end

    # The per-distance `(?<=\A(?m:.){at})` check raised RegexpError past Onigmo's
    # 100000 repeat limit (and cost ~cubic time); the body is now matched against the text
    # before the spot with a `\z` anchor.
    it 'decides a lookbehind beyond 100000 characters into the line (no repeat-limit RegexpError)' do
      line = "#{'a' * 100_001} q x q"
      expect(described_class.compile('(?<!x\\S* )q').match(line)&.begin(0)).to eq(100_002)
      expect(described_class.compile('(?<=x\\S* )q').match(line)&.begin(0)).to eq(100_006)
    end

    it 'keeps the whole-line form when the body looks past its end ($, \\z, \\Z, \\b, \\B, lookahead)' do
      expect(['(?<=a+$)b', '(?<=a+\\z)b', '(?<=a+\\Z)b', '(?<=a+\\b)b'].map { |p| groups(p, 'aab') }).to eq([nil] * 4)
      expect(groups('(?<=a+\\B)b', 'aab')).to eq(['b'])
      expect(groups('(?<=a+(?!b))b', 'aab')).to be_nil
      expect(groups('(?<=a+$)\\nb', "aa\nb")).to eq(["\nb"])
      expect(groups('(?<=[$]\\w+)b', '$ab')).to eq(['b']) # a $ inside a class is a literal
    end

    # A full cache dropped EVERY entry (uber.cmd alone registers more patterns than the
    # old limit, so the cache thrashed); it now drops the least recently used one.
    it 'evicts only the least recently used entry and never grows past its limit' do
      cache = described_class::Cache.new(2)
      built = []
      fetch = ->(key) { cache.fetch(key) { built << key; key.upcase } }
      %w[a b a c b a].each { |key| fetch.call(key) }
      expect(built).to eq(%w[a b c b a]) # a stays (used again), b goes first, then c... a
      expect(cache.size).to eq(2)
      expect(described_class::CACHE_LIMIT).to be >= 16_384
    end

    # The conditional check looked for "(?(" in the raw text, so an escaped `\(?(x)` or a
    # class `[(?(]` forced the slow every-start search.
    it 'finds a conditional by parsing, not in escapes or classes' do
      expect(described_class.non_monotone?('(?<!y\\S* )b|\\(?(x)', 0)).to be(false)
      expect(described_class.non_monotone?('(?<!y\\S* )b|[(?(]', 0)).to be(false)
      expect(described_class.non_monotone?('(?<!y\\S* )b|(a)?(?(1)c|d)', 0)).to be(true)
      expect(groups('(?<!y\\S* )b|\\(?(x)', 'yz b (x')).to eq(['(x', 'x'])
      expect(groups('(?<!y\\S* )b|\\(?(x)', 'z b (x')).to eq(['b', ''])
    end
  end

  describe '.NET group names, conditionals, \\k names and option syntax' do
    def groups_of(pattern, text) = described_class.compile(pattern).match(text)&.to_a

    it 'rejects group number 0 as a group name, like .NET' do
      expect(['(?<0>x)', '(?<00>x)', "(?'0'x)", '(?<0-1>x)()'].select { |p| compiles?(p) }).to eq([])
      expect(described_class.compile('(x)(?<-0>y)')).to be_a(described_class::Unsupported) # balancing on 0: .NET-valid
    end

    it 'calls a conditional on a group defined later Unsupported instead of rejecting it' do
      ['(?(n)a|b)(?<n>c)?', '(?(n)a|b)(?<n>c)'].each do |pattern|
        compiled = described_class.compile(pattern)
        expect([pattern, compiled.class, compiled.reason])
          .to eq([pattern, described_class::Unsupported, 'a conditional on a group defined later'])
      end
      expect(groups_of('(?<n>c)?(?(n)a|b)', 'cb')).to eq(['b', nil])
    end

    it 'rejects \\k names .NET does not accept: relative and +/-0 forms' do
      bad = ['\\k<-1>', "\\k'-1'", '(?<n>a)\\k<n+0>', '(?<n>a)\\k<n-0>', '(a)\\k<1+0>', "(a)\\k'1-0'"]
      expect(bad.select { |p| compiles?(p) }).to eq([])
      expect(groups_of('(?<n>a)\\k<n>', 'aa')).to eq(%w[aa a])
      expect(groups_of("(a)\\k'1'", 'aa')).to eq(%w[aa a])
    end

    it 'reads + and - anywhere in an option group, later letters winning, like .NET' do
      expect(%w[(?+i)A (?i+s)A (?+-+i)A (?-i+i)A (?i-+)A (?I+S)A (?+i:A) (?+)A (?-+)A].map { |p| groups_of(p, 'a')&.first })
        .to eq(['a', 'a', 'a', 'a', 'a', 'a', 'a', nil, nil])
      expect(%w[(?--i)A (?-i-s)A (?i-i+)A (?+:A)].map { |p| described_class.compile(p, ignore_case: false).match?('a') })
        .to eq([false] * 4)
      expect(described_class.compile('(?i-i+)A', ignore_case: true).match?('a')).to be(false)
      expect(groups_of('a(?+i)b|c', 'C')).to eq(['C']) # still scoped like (?i) (rest of the group)
    end

    it 'calls a conditional on group 0 Unsupported (.NET-valid, never true there)' do
      ['(?(0)a|b)', '(?(00)a|b)'].each do |pattern|
        compiled = described_class.compile(pattern)
        expect([pattern, compiled.class, compiled.reason]).to eq([pattern, described_class::Unsupported, 'a conditional on group 0'])
      end
    end
  end
end
