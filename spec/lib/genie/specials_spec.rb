# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Specials do
  subject(:specials) do
    described_class.new(clock: -> { Time.new(2026, 8, 18, 14, 5, 9) }, timer: -> { '42' })
  end

  let(:subs) { specials.substitutions }

  it 'exposes the script timer' do
    expect(subs['@timer@']).to eq('42')
  end

  # .NET custom formats verbatim from Globals.cs:224-236 R. Golden: the audit's C#
  # xmlprobe (evidence/reserved-state/xmlprobe) and genieflow t91_date_specials.
  it 'formats "HH:mm:ss tt" as a 24-hour clock WITH the designator, and HHmm' do
    expect(subs['@time24@']).to eq('14:05:09 PM')
    expect(subs['@militarytime@']).to eq('1405')
  end

  it 'formats "hh:mm:ss tt" and the unpadded "M/d/yyyy"' do
    expect(subs['@time@']).to eq('02:05:09 PM')
    expect(subs['@date@']).to eq('8/18/2026')
    expect(subs['@datetime@']).to eq('8/18/2026 02:05:09 PM')
    expect(subs['@datetime24@']).to eq('8/18/2026 14:05:09 PM')
  end

  it 'leaves DayOfYear unpadded and pads nothing else it should not' do
    jan5 = described_class.new(clock: -> { Time.new(2026, 1, 5, 9, 5, 7) }).substitutions
    # The xmlprobe's own instant: "09:05:07 AM | 09:05:07 AM | 1/5/2026 | ... | 0905 | 05 | 05 | 5"
    expect(jan5.values_at('@time@', '@time24@', '@date@', '@militarytime@', '@month@', '@dayofmonth@', '@dayofyear@'))
      .to eq(['09:05:07 AM', '09:05:07 AM', '1/5/2026', '0905', '05', '05', '5'])
  end

  it 'renders midnight and noon on the 12-hour clock as 12' do
    midnight = described_class.new(clock: -> { Time.new(2026, 12, 31, 0, 0, 0) }).substitutions
    noon = described_class.new(clock: -> { Time.new(2026, 12, 31, 12, 30, 0) }).substitutions
    expect([midnight['@time@'], midnight['@time24@'], midnight['@dayofyear@']]).to eq(['12:00:00 AM', '00:00:00 AM', '365'])
    expect([noon['@time@'], noon['@time24@']]).to eq(['12:30:00 PM', '12:30:00 PM'])
  end

  it 'preserves the Genie @month@ = minutes quirk' do
    # Genie's @month@ uses .NET "mm" which is MINUTES, not the calendar month.
    expect(subs['@month@']).to eq('05')
    expect(subs['@dayofmonth@']).to eq('18')
    expect(subs['@year@']).to eq('2026')
  end

  describe 'directory specials (our engine dirs, Globals.cs:237-242 R)' do
    it 'expands each Remix directory special to the given engine directory' do
      dirs = { 'scriptdir' => '/s', 'mapdir' => '/m', 'plugindir' => '/p', 'artdir' => '/a', 'logdir' => '/l', 'sounddir' => '/o' }
      subs = described_class.new(directories: dirs).substitutions
      expect(subs.values_at('@scriptdir@', '@mapdir@', '@plugindir@', '@artdir@', '@logdir@', '@sounddir@')).to eq(%w[/s /m /p /a /l /o])
    end

    it 'defaults to Lich::Genie.directories' do
      expect(described_class.new.substitutions['@scriptdir@']).to eq(Lich::Genie.directories['scriptdir'])
    end
  end

  # Globals.cs:206-222 R + FormMain.cs:6697-6707 R; genieflow golden t92_spell_specials.
  describe 'spell specials' do
    let(:start) { Time.new(2026, 1, 1, 12, 0, 1) }
    let(:spell_clock) { { start: nil } }
    let(:store) { Lich::Genie::GlobalStore.new }
    let(:game_state) do
      clock = spell_clock
      Object.new.tap { |o| o.define_singleton_method(:spell_time_start) { clock[:start] } }
    end
    let(:vars) { Lich::Genie::Variables.new(game_state: game_state, global_store: store) }

    def subs_at(time)
      described_class.new(clock: -> { time }, source: vars).substitutions
    end

    it 'reads "0", "0" and leaves @spellpreptime@ literal with no spell timer' do
      out = subs_at(start)
      expect(out['@spelltime@']).to eq('0')
      expect(out['@casttimeremaining@']).to eq('0')
      expect(out).not_to have_key('@spellpreptime@')
    end

    it 'gives elapsed seconds, castTime - spellstarttime and the remainder while the timer runs' do
      spell_clock[:start] = start + Rational(1, 100)
      store.set('casttime', '1767222006')
      store.set('spellstarttime', '1767222001')
      out = subs_at(start + 3)
      expect(out.values_at('@spelltime@', '@spellpreptime@', '@casttimeremaining@')).to eq(%w[2.99 5 2.01])
    end

    it 'floors the remainder at "0" once the prep time is past' do
      spell_clock[:start] = start
      store.set('casttime', '1767222006')
      store.set('spellstarttime', '1767222001')
      expect(subs_at(start + 7)['@casttimeremaining@']).to eq('0')
    end

    it 'treats a timer that has not advanced (d <= 0) as no timer, like Remix' do
      spell_clock[:start] = start
      out = subs_at(start)
      expect(out['@spelltime@']).to eq('0')
      expect(out).not_to have_key('@spellpreptime@')
    end

    it 'raises a Genie error when $casttime is not an Int32 (int.Parse throws in Remix)' do
      spell_clock[:start] = start
      store.set('casttime', 'soon')
      expect { subs_at(start + 1) }.to raise_error(Lich::Genie::Error, /casttime/)
    end
  end
end
