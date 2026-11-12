# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Curated Eval / MathEval golden recorded from Genie4 Remix v4.2.4's real Eval.cs and
# MathEval.cs (lab genieoracle), checked without dotnet. ~400 rows: real corpus conditions,
# evals, evalmath and harvested regexes (as matchre("", pattern)), plus synthetic rows for
# every MathEval function/operator, NaN/Infinity, mixed-case AND/OR/NOT and
# function-&&-comparison shapes, and matchre capture groups.
#
# Regenerate (never hand-edit expected values), from the genie-port lab dir:
#   GENIE=remix bundle exec ruby reference/corpus_oracle.rb --record
#   GENIE=remix bundle exec ruby reference/curate_oracle_golden.rb --write
# The full ~38k-row corpus golden and the fuzzers stay lab-side (lab README.md, "Lab tooling").
#
# RATCHET: rows whose `finding` column is set are where our engine currently differs from
# Remix; they run as pending. When a work package fixes one, RSpec reports "Expected pending
# ... to fail" until the finding is cleared (re-run the curation script, which re-derives
# the column from our engine, the narrow reference/fuzz_allowlist.tsv entries and the exact
# reference/goldens/corpus_oracle.accepted.remix.tsv keys; it refuses to tag a regression).
#
# ERR TOLERANCE: a Genie `ERR:<.NET exception>` row matches ANY Lich::Genie::Error we raise
# (RUBYERR:*). The exception TYPE is not compared (ERR:InvalidCastException and
# ERR:ArgumentOutOfRangeException are the same to this spec), nor the message, nor where in
# the expression it was raised: "both sides refuse the input" is all a row pins. A value on
# one side and an error on the other is always a mismatch.
RSpec.describe 'Genie Eval/MathEval vs Remix v4.2.4 oracle golden' do
  path = File.expand_path('../../fixtures/genie/oracle/eval_golden.tsv', __dir__)
  rows = File.readlines(path, chomp: true).reject { |l| l.start_with?('#') || l.empty? }.map { |l| l.split("\t", -1) }
  separator = 0x1F.chr

  # genieoracle prints NaN / Infinity / -Infinity with "R" InvariantCulture.
  parse_double = lambda do |text|
    { 'NaN' => Float::NAN, 'Infinity' => Float::INFINITY, '-Infinity' => -Float::INFINITY }.fetch(text) { Float(text, exception: false) }
  end

  # Our engine's answer in genieoracle's output format. Only the engine's own
  # Lich::Genie::Error is reported as RUBYERR (comparable with Genie's ERR:<Exception> rows);
  # any other Ruby exception (NoMethodError, ...) is a real bug and fails the example.
  ours = lambda do |mode, input|
    globals = Object.new.tap { |g| g.define_singleton_method(:key?) { |_| false } }
    ev = Lich::Genie::Eval.new(globals: globals)
    case mode
    when 'evalbool' then ev.do_eval(input) ? '1' : '0'
    when 'eval' then ev.eval_string(input)
    when 'math' then Lich::Genie::MathEval.evaluate(input)
    when 'evalmath' then Lich::Genie::Numeric.format_double(Lich::Genie::MathEval.evaluate(input))
    when 'matchrecaps'
      ev.eval_string(input)
      ([ev.result_list.length.to_s] + ev.result_list).join(separator)
    else raise ArgumentError, "unknown oracle mode #{mode.inspect}"
    end
  rescue Lich::Genie::Error => e
    "RUBYERR:#{e.class}"
  end

  same = lambda do |mode, got, genie|
    next got.to_s.start_with?('RUBYERR:') if genie.start_with?('ERR:')
    next false if got.to_s.start_with?('RUBYERR:')

    if mode == 'math'
      want = parse_double.call(genie)
      next false unless want && got.is_a?(Numeric)
      next got.to_f.nan? && want.nan? if want.nan? || got.to_f.nan?
      # genieoracle prints MathEval doubles with ToString("R") (oracle/Program.cs:52, .NET 8:
      # shortest round-trip text), so the parsed value has Remix's exact bits: compare the
      # IEEE-754 bits (also tells -0.0 from 0.0, which "R" prints as "-0" and "0").
      next [got.to_f].pack('G') == [want].pack('G')
    end
    got.to_s == genie
  end

  it 'parses a non-trivial fixture with five well-formed columns' do
    expect(rows.length).to be > 300
    expect(rows.map(&:length).uniq).to eq([5])
    expect(rows.map(&:first).uniq.sort).to eq(%w[eval evalbool evalmath math matchrecaps].sort)
  end

  it 'covers every Remix Eval.cs function and the mixed-case keywords' do
    inputs = rows.map { |r| r[1] }.join("\n")
    %w[contains count def defined element endswith indexof instr instring lastindexof len length match matchre
       replace replacere startswith substr substring tolower toupper trim].each do |fn|
      expect(inputs).to include("#{fn}("), "no golden row calls #{fn}()"
    end
    %w[AND OR NOT And Or Not && || != <> >= <= ==].each { |tok| expect(inputs).to include(tok) }
  end

  it 'covers every Remix MathEval function (m_funcs, MathEval.cs:63 R) and operator (MathEval.cs:69-138 R)' do
    maths = rows.select { |r| %w[math evalmath].include?(r[0]) }.map { |r| r[1] }
    %w[sin cos tan arcsin arccos arctan sqrt max min floor ceiling log log10 ln round abs neg pos].each do |fn|
      expect(maths.grep(/\b#{fn}\(/)).not_to be_empty, "no math/evalmath row calls #{fn}()"
    end
    ['-', '+', '*', '/', '\\', '%', '^', '!', '&', '(', ')'].each do |op|
      expect(maths.select { |i| i.include?(op) }).not_to be_empty, "no math/evalmath row uses operator #{op}"
    end
  end

  it 'tags every pending row with a finding id' do
    expect(rows.reject { |r| r[3].empty? }.map { |r| r[3] }).to all(match(/\A[GNT]\d{2}\z/))
  end

  describe 'the comparison rules themselves' do
    it 'reports only Lich::Genie::Error as RUBYERR; other Ruby exceptions propagate' do
      expect(ours.call('math', '(2 + 3')).to eq('RUBYERR:Lich::Genie::Error')
      expect(ours.call('eval', 'substr("x", 5, 3)')).to eq('RUBYERR:Lich::Genie::Eval::Fault')
      expect { ours.call('bogus', 'x') }.to raise_error(ArgumentError, /unknown oracle mode/)
    end

    it 'treats our raise as equal to a Genie exception, but not to a value' do
      expect(same.call('eval', 'RUBYERR:Lich::Genie::Error', 'ERR:InvalidCastException')).to be(true)
      expect(same.call('eval', 'RUBYERR:Lich::Genie::Error', '0')).to be(false)
      expect(same.call('eval', '0', 'ERR:InvalidCastException')).to be(false)
    end

    it 'compares math exactly (round-trip "R" text), NaN to NaN and infinities by sign' do
      expect(same.call('math', Float::NAN, 'NaN')).to be(true)
      expect(same.call('math', -Float::INFINITY, 'Infinity')).to be(false)
      expect(same.call('math', Float::INFINITY, 'Infinity')).to be(true)
      expect(same.call('math', 0.1 + 0.2, '0.30000000000000004')).to be(true)
      expect(same.call('math', 0.30000000000000004, '0.3')).to be(false)
      expect(same.call('math', 3, '3')).to be(true)
      expect(same.call('math', -0.0, '-0')).to be(true)
      expect(same.call('math', 0.0, '-0')).to be(false)
      expect(same.call('math', 0.31, '0.3')).to be(false)
      expect(same.call('math', 'x', '1')).to be(false)
    end
  end

  rows.each_with_index do |(mode, input, genie, finding, source), i|
    it "row #{i + 1} #{mode} #{input[0, 70]} (#{source})" do
      pending("#{finding}: our engine differs from Remix on this #{mode} row") unless finding.empty?
      want = genie.gsub('\\x1f', separator)
      got = ours.call(mode, input)
      expect(same.call(mode, got, want)).to be(true), "ours=#{got.inspect} genie=#{want.inspect}"
    end
  end
end
