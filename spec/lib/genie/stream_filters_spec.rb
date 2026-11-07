# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/save_ordering'
require_relative '../../../lib/genie'
require 'tmpdir'

# Lich::Genie::StreamFilters: Remix Globals.GagRegExp / SubstituteRegExp (Lists/Globals.cs:1414-1846
# R) and the display semantics of Game.PrintTextToWindow / ParseSubstitutions (Game.cs:3075-3103,
# 3173-3206 R). The display expectations are genieflow --verbose `game-print` results (probe
# p07).
RSpec.describe Lich::Genie::StreamFilters do
  subject(:filters) { described_class.new }

  describe 'gag list (GagRegExp.Add / Remove / ToggleClass)' do
    it 'suppresses a line an active gag matches (on Utility.Trim(text)), passes the rest' do
      filters.add_gag('a boring line')
      expect(filters.apply('this is a boring line indeed')).to be_nil
      expect(filters.apply('an exciting line')).to eq('an exciting line')
      filters.add_gag('^gagme')
      expect(filters.apply("\r\ngagme now\r\n")).to be_nil # CR/LF trimmed before the match
    end

    it 'refuses an invalid regex (Add returns false) instead of matching it literally' do
      expect(filters.add_gag('what (is this')).to be(false)
      expect(filters.gags).to eq([])
      expect(filters.apply('what (is this even')).to eq('what (is this even')
    end

    it 'strips /../ and /../i, the trailing /i meaning ignore case; ignore_case: is Add\'s IgnoreCase' do
      filters.add_gag('/^hidden/i')
      filters.add_gag('^Shout', ignore_case: true)
      expect(filters.gags.map { |g| [g.text, g.ignore_case] }).to eq([['^hidden', true], ['^Shout', true]])
      expect(filters.apply('HIDDEN thing')).to be_nil
      expect(filters.apply('shout loud')).to be_nil
    end

    it 'replaces an entry with the same text in place (list order = add order) and keeps an empty text' do
      filters.add_gag('b', klass: 'one')
      filters.add_gag('a')
      filters.add_gag('b', klass: 'two')
      expect(filters.gags.map { |g| [g.text, g.klass] }).to eq([%w[b two], ['a', '']])
      expect(filters.add_gag('')).to be(true) # a valid regex that matches every line
      expect(filters.apply('anything')).to be_nil
    end

    it 'removes every entry with exactly the text -- no /../i stripping on remove' do
      filters.add_gag('/spam/i')
      filters.remove_gag('/spam/i')
      expect(filters.gags.length).to eq(1)
      filters.remove_gag('spam')
      expect(filters.gags).to eq([])
    end

    it 'toggles by exact class name ("" = the class-less ones), case-sensitive unlike the triggers' do
      filters.add_gag('hush', klass: 'Combat')
      filters.add_gag('always')
      filters.toggle_class('combat', false)
      expect(filters.apply('hush now')).to be_nil # 'combat' is not 'Combat'
      filters.toggle_class('Combat', false)
      expect(filters.apply('hush now')).to eq('hush now')
      filters.toggle_class('', false)
      expect(filters.apply('always here')).to eq('always here')
    end

    it 'never gags the thoughts window' do
      filters.add_gag('secret')
      expect(filters.gagged?('a secret thought', :thoughts)).to be(false)
      expect(filters.apply("<pushStream id='thoughts'/>a secret thought<popStream/>")).to include('secret')
      expect(filters.gagged?('a secret thought', :main)).to be(true)
    end

    it 'tests a gag on the line\'s display text: tags dropped, entities decoded' do
      filters.add_gag('^You see a <thing>')
      expect(filters.apply('<pushBold/>You see a &lt;thing&gt;.<popBold/>')).to eq('<pushBold/><popBold/>')
    end
  end

  # Remix parses a row's markup -- stream, component, compass, prompt --
  # and a gag only skips the PRINTED piece (Game.cs:3075-3092 R), so the client must keep every tag
  # of a gagged line and lose only its text. Rows: the shapes of a tester's live capture and the
  # parity review's state rows.
  describe 'a gag hides text, never markup' do
    def tags(line) = line.scan(/<[^>]*>/).join

    {
      'percWindow push'           => ['^Ignite', %(<pushStream id="percWindow"/>Ignite  (11 roisaen)\r\n)],
      'room exits + compass'      => ['^Obvious paths', %(<component id='room exits'>Obvious paths: <d>north</d>, <d>southeast</d>.<compass></compass></component>\r\n)],
      'compass + room objs'       => ['^You also see', %(<compass><dir value="n"/><dir value="se"/></compass><component id='room objs'>You also see <pushBold/>a Shard sentinel<popBold/>.</component>\r\n)],
      'room players'              => ['^Also here', %(<compass><dir value="n"/><dir value="se"/></compass><component id='room players'>Also here: Tester.</component>\r\n)],
      'prompt (server time)'      => ['^>', %(<popStream/><prompt time="1790082256">&gt;</prompt>\r\n)],
      'match-all gag on a prompt' => ['', %(<prompt time="1790082257">&gt;</prompt>\r\n)],
      'clearStream + inv push'    => ['^Your worn', %(<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:\r\n)]
    }.each do |label, (gag, line)|
      it "keeps every tag of a gagged #{label} row and drops its text and line end" do
        filters.add_gag(gag)
        out = filters.apply(line)
        expect(out).to eq(tags(line))
        expect(out).not_to include("\r\n")
      end
    end

    it 'passes a tag-only line on unchanged even under ^\\s*$ or a match-all gag (Remix prints nothing for it)' do
      filters.add_gag('^\\s*$')
      filters.add_gag('.*')
      [%(<crtrStatus exist="89938897" hostile="0" disengaged="1"/><component id='room players'></component>\r\n),
       %(<streamWindow id='main' title='Story' subtitle=" - [Shard, Garden Crescent] (2010671)" location='center' target='drop'/>\r\n),
       %(<roundTime value='1790082300'/><dialogData id='minivitals'></dialogData>\r\n),
       "   \r\n"].each { |line| expect(filters.apply(line)).to equal(line) }
    end

    it 'suppresses (nil) only a line with no tag at all' do
      filters.add_gag('^The sentinel')
      expect(filters.apply("The sentinel nods.\r\n")).to be_nil
      expect(filters.apply("<pushBold/>The sentinel nods.\r\n")).to eq('<pushBold/>')
    end

    it 'keeps the tags of a gagged line on the whole session capture: no state tag is ever lost' do
      path = File.expand_path('../../fixtures/genie/game_state/session_capture_rows.txt', __dir__)
      lines = File.readlines(path).map { |row| "#{row.chomp}\r\n" }
      %w[^Ignite ^Obvious ^You ^Also ^> .*].each { |gag| filters.add_gag(gag) }
      gagged = lines.reject { |line| filters.apply(line).equal?(line) }
      expect(gagged.size).to be > 200
      gagged.each { |line| expect(filters.apply(line).to_s).to eq(tags(line)), line }
    end
  end

  # Lich's DownstreamHook.run deletes a hook that raises, for the rest of the
  # session (lib/common/downstreamhook.rb) -- every gag/sub and the queue kick would be gone.
  describe 'never raising into Lich' do
    ['&#55296;', '&#xD800;', '&#1114112;', '&#99999999999999999999;'].each do |ref|
      it "leaves #{ref} as written (no invalid String) and still filters the line" do
        filters.add_gag('^gag')
        filters.add_sub('swap', 'SWAPPED')
        expect(filters.apply("gag #{ref}")).to be_nil
        # the changed run is re-encoded: the kept reference's `&` too (the client shows it as written)
        expect(filters.apply("<b/>swap #{ref}")).to eq("<b/>SWAPPED &amp;#{ref.delete_prefix('&')}")
        expect(filters.apply("keep #{ref}")).to eq("keep #{ref}")
      end
    end

    it 'filters a line with invalid UTF-8 (scrubbed for the match) and passes it on untouched when nothing applies' do
      filters.add_gag('^gag')
      bad = "keep #{[0xFF, 0xFE].pack('C*')}".b
      expect(filters.apply(bad)).to equal(bad)
      expect(filters.apply("gag #{[0xFF].pack('C*')}".b)).to be_nil
      invalid = "gag #{[0xFF].pack('C*')}".b.force_encoding(Encoding::UTF_8) # a UTF-8 String with a bad byte
      expect(invalid.valid_encoding?).to be(false)
      expect(filters.apply(invalid)).to be_nil
      kept = "keep #{[0xFF].pack('C*')}".b.force_encoding(Encoding::UTF_8)
      expect(filters.apply(kept)).to equal(kept)
    end

    it 'fails open: an unexpected fault returns the line instead of raising' do
      filters.add_gag('x')
      allow(filters).to receive(:filter_line).and_raise(NoMethodError, 'boom')
      expect(filters.apply('a line')).to eq('a line')
    end
  end

  # A pattern Onigmo backtracks catastrophically must not stall Lich's parser
  # thread -- a lookbehind-emulated one (NetRegex::Emulated) included.
  describe 'match timeouts and the shut-off' do
    # Emulated (a variable-length lookbehind) with a backreference Ruby's match cache cannot memoize:
    # ~0.1 s at 22 characters, doubling per character.
    let(:slow) { '(?<!z\\S+ )(a+)+\\1b' }
    let(:line) { "#{'a' * 34}!" }

    before { stub_const('Lich::Genie::StreamFilters::MATCH_TIMEOUT_SECONDS', 0.05) }

    it 'gives an Emulated pattern a private timed copy (the shared cached one keeps none)' do
      filters.add_gag(slow)
      regex = filters.gags.first.regex
      expect(regex).to be_a(Lich::Genie::NetRegex::Emulated)
      expect(regex.timeout).to eq(0.05)
      expect(Lich::Genie::NetRegex.compile(slow).timeout).to be_nil
    end

    it 'bounds each gag match and shuts the gag off after 3 timeouts in a row, telling on_disabled once' do
      told = []
      filters.on_disabled = ->(kind, text) { told << [kind, text] }
      filters.add_gag(slow)
      expect(filters.hides_echo_of?('aab')).to be(true) # it matches a short text quickly
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      2.times { |i| expect(filters.gagged?("#{line}#{i}")).to be(false) }
      expect([filters.gags.first.disabled, told]).to eq([false, []])
      expect(filters.gagged?("#{line}x")).to be(false) # the third in a row
      expect([filters.gags.first.disabled, told]).to eq([true, [['gag', slow]]])
      expect(filters.gagged?("#{line}y")).to be(false) # no longer matched: no fourth timeout
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2.0
      expect(told).to eq([['gag', slow]])
      expect(filters.hides_echo_of?('aab')).to be(false) # a shut-off gag is not matched for the echo either
      expect(filters.gagged?('aab')).to be(false)
      filters.add_gag(slow) # added again: back on
      expect(filters.gags.first.disabled).to be(false)
    end

    it 'resets the count when a match completes' do
      filters.add_gag(slow)
      2.times { |i| filters.gagged?("#{line}#{i}") }
      filters.gagged?('ab') # completes
      2.times { |i| filters.gagged?("#{line}x#{i}") }
      expect(filters.gags.first.disabled).to be(false)
    end

    it 'shuts a substitute off too, and a plain Regexp gets the timeout as well' do
      told = []
      filters.on_disabled = ->(kind, _text) { told << kind }
      filters.add_sub(slow, 'x')
      3.times { |i| expect(filters.substitute("#{line}#{i}")).to eq("#{line}#{i}") }
      expect(told).to eq(['substitute'])
      filters.add_gag('^plain')
      expect(filters.gags.last.regex.timeout).to eq(0.05)
    end

    it 'keeps filtering when on_disabled raises' do
      filters.on_disabled = ->(*) { raise 'report failed' }
      filters.add_gag(slow)
      filters.add_gag('^hide')
      3.times { |i| filters.gagged?("#{line}#{i}") }
      expect(filters.apply('hide me')).to be_nil
    end
  end

  # The capture's test of a row's text and the client hook's test of the same line match once.
  describe 'the gag memo' do
    it 'matches a text once until the list changes' do
      filters.add_gag('^hide')
      regex = filters.instance_variable_get(:@gags).first.regex
      calls = 0
      regex.define_singleton_method(:match?) { |text| (calls += 1) && super(text) }
      expect(filters.displayed("hide me\r\n")).to be_nil
      expect(filters.apply("hide me\r\n")).to be_nil
      expect(calls).to eq(1)
      filters.toggle_class('', false) # a change forgets it
      expect(filters.apply("hide me\r\n")).to eq("hide me\r\n")
      filters.toggle_class('', true)
      expect(filters.apply("hide me\r\n")).to be_nil
    end

    it 'never answers for a text after an add or remove' do
      expect(filters.gagged?('new line')).to be(false)
      filters.add_gag('^new')
      expect(filters.gagged?('new line')).to be(true)
      filters.remove_gag('^new')
      expect(filters.gagged?('new line')).to be(false)
      filters.add_sub('^new', 'old')
      expect(filters.substitute('new line')).to eq('old line')
      filters.clear_subs
      filters.add_sub('line', 'row')
      expect(filters.substitute('new line')).to eq('new row')
    end

    # A list change landing while Lich's parser thread is matching
    # a text must not let that match's result -- computed against the old list -- be memoized.
    def block_first_match(entry, entered, release)
      first = true
      entry.regex.define_singleton_method(:match?) do |text|
        if first
          first = false
          entered << true
          release.pop
        end
        super(text)
      end
    end

    it 'does not memoize a gag result when an #ungag lands mid-match' do
      filters.add_gag('^x')
      entered = Queue.new
      release = Queue.new
      block_first_match(filters.instance_variable_get(:@gags).first, entered, release)
      matcher = Thread.new { filters.gagged?('x line') }
      entered.pop
      filters.remove_gag('^x')
      release << true
      expect(matcher.value).to be(true) # that match saw the old list
      expect(filters.gagged?('x line')).to be(false)
    ensure
      release << true
      matcher&.join(1)
    end

    it 'does not memoize a substitute miss when a #sub lands mid-match' do
      filters.add_sub('^nomatch', 'r')
      entered = Queue.new
      release = Queue.new
      block_first_match(filters.instance_variable_get(:@subs).first, entered, release)
      matcher = Thread.new { filters.substitute('x line') }
      entered.pop
      filters.add_sub('^x', 'y')
      release << true
      expect(matcher.value).to eq('x line') # that pass saw the old list
      expect(filters.substitute('x line')).to eq('y line')
    ensure
      release << true
      matcher&.join(1)
    end

    it 'stays bounded' do
      filters.add_gag('^zzz')
      (described_class::MEMO_LIMIT + 10).times { |i| filters.gagged?("text #{i}") }
      expect(filters.instance_variable_get(:@gag_memo).size).to be <= described_class::MEMO_LIMIT
    end
  end

  # ParseGlobalVars runs only for a substitute that matched.
  it 'expands a substitute\'s replacement only once its pattern matched' do
    expanded = []
    filters.globals = ->(text) { (expanded << text) && text.sub('$x', 'X') }
    filters.add_sub('^nomatch', 'a $x')
    filters.add_sub('^hit', 'b $x')
    expect(filters.substitute('hit it')).to eq('b X it')
    expect(expanded).to eq(['b $x'])
  end

  describe 'Game.SendText echo test (Game.cs:481-511 R)' do
    it 'hides a script\'s send echo when ANY gag -- active or not -- matches the script name' do
      filters.add_gag('^hunt', klass: 'x')
      filters.toggle_class('x', false)
      expect(filters.hides_echo_of?('hunter')).to be(true)
      expect(filters.hides_echo_of?('sc')).to be(false)
      expect(filters.hides_echo_of?('')).to be(false)
    end
  end

  describe 'substitute list and ParseSubstitutions' do
    it 'uses .NET replacement syntax: ${1}, $$, $&, $+, $_ (p07 game-print)' do
      filters.add_sub('^The (\\w+) door', 'A ${1}x door $$ $& $+ [$_]')
      expect(filters.apply('The oak door is open.')).to eq('A oakx door $ The oak door oak [The oak door is open.] is open.')
    end

    it 'ParseGlobalVars the replacement at display time (globals port)' do
      filters.globals = ->(text) { text.gsub('$roundtime', '7') }
      filters.add_sub('^Gold', '$roundtime gold')
      expect(filters.apply('Gold coins here.')).to eq('7 gold coins here.')
      expect(filters.substitute('Gold coins here.', expand: false)).to eq('$roundtime gold coins here.')
    end

    it 'replaces in Utility.Trim(text) and gives a changed text back its leading/trailing CRLF' do
      filters.add_sub('  spaced  ', 'S')
      expect(filters.substitute("\r\ntext with  spaced   words\r\n")).to eq("\r\ntext withS words\r\n")
      expect(filters.substitute("\ntext with  spaced  x")).to eq('text withSx') # a lone LF is trimmed, not restored
    end

    it 'leaves a blank text alone and a text no substitute matches unchanged' do
      filters.add_sub('x', 'y')
      expect(filters.substitute("  \r\n")).to eq("  \r\n")
      expect(filters.substitute('abc')).to eq('abc')
    end

    it 'applies subs in list order, each on the result of the last; a sub to empty empties the text' do
      filters.add_sub('foo', 'bar')
      filters.add_sub('bar', 'baz')
      filters.add_sub('^ab+$', '')
      expect(filters.apply('foo bar')).to eq('baz baz')
      expect(filters.substitute('abbb')).to eq('')
    end

    it 'refuses an invalid regex and gates by exact class; Remove takes every equal text' do
      expect(filters.add_sub('(bad', 'x')).to be(false)
      filters.add_sub('foo', 'BAR', klass: 'x')
      filters.add_sub('foo', 'BAZ', klass: 'x') # replaced in place
      expect(filters.apply('foo')).to eq('BAZ')
      filters.toggle_class('x', false)
      expect(filters.apply('foo')).to eq('foo')
      filters.remove_sub('foo')
      expect(filters.subs).to eq([])
    end

    it 'substitutes in each text run between tags, re-encoding a changed run' do
      filters.add_sub('goblin', '<g&o>')
      expect(filters.apply('A <pushBold/>goblin<popBold/> attacks.')).to eq('A <pushBold/>&lt;g&amp;o&gt;<popBold/> attacks.')
    end

    it '#displayed is nil for a gagged text, else the substituted text' do
      filters.add_gag('^gag')
      filters.add_sub('^ab+', '')
      expect(filters.displayed('gag me')).to be_nil
      expect(filters.displayed('abbb')).to eq('')
      expect(filters.displayed('gag me', :thoughts)).to eq('gag me')
    end
  end

  describe 'files (Load merges; Save writes Remix\'s rows)' do
    around { |example| Dir.mktmpdir('genie-filters') { |dir| @dir = dir; example.run } }

    it 'round-trips gags.cfg and substitutes.cfg, /x/i and classes included' do
      filters.add_gag('/^hidden/i', klass: 'cls')
      filters.add_gag('^plain')
      filters.add_sub('^a', 'b', klass: 'k')
      filters.add_sub('/^c/i', 'd')
      gags = File.join(@dir, 'gags.cfg')
      subs = File.join(@dir, 'substitutes.cfg')
      expect([filters.save_gags(gags), filters.save_subs(subs)]).to eq([true, true])
      expect(File.binread(gags)).to eq("#gag {/^hidden/i} {cls}\r\n#gag {^plain}\r\n")
      expect(File.binread(subs)).to eq("#subs {^a} {b} {k}\r\n#subs {/^c/i} {d}\r\n")
      fresh = described_class.new
      expect([fresh.load_gags(gags), fresh.load_subs(subs)]).to eq([true, true])
      expect(fresh.gags.map { |g| [g.text, g.ignore_case, g.klass] }).to eq([['^hidden', true, 'cls'], ['^plain', false, '']])
      expect(fresh.subs.map { |sub| [sub.text, sub.replacement, sub.klass] }).to eq([%w[^a b k], ['^c', 'd', '']])
    end

    it 'reports a missing file or no path as false and writes nothing without a path' do
      expect(filters.load_gags(File.join(@dir, 'none.cfg'))).to be(false)
      expect(filters.save_subs(nil)).to be(false)
    end

    it 'orders whole gag saves: an older snapshot never lands after a newer one' do
      extend GenieSpecSupport::SaveOrdering
      expect_ordered_saves(first: -> { filters.add_gag('^one') }, second: -> { filters.add_gag('^two') },
                           first_marker: '{^one}', second_marker: '{^two}',
                           save: -> { filters.save_gags(File.join(@dir, 'gags.cfg')) })
    end

    it 'orders whole substitute saves the same way' do
      extend GenieSpecSupport::SaveOrdering
      expect_ordered_saves(first: -> { filters.add_sub('^a', 'one') }, second: -> { filters.add_sub('^a', 'two') },
                           first_marker: '{^a} {one}', second_marker: '{^a} {two}',
                           save: -> { filters.save_subs(File.join(@dir, 'substitutes.cfg')) })
    end
  end
end
