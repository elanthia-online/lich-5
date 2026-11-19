# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# The DateTime.Parse (en-US) forms `timer setstart` reads (EvalTimer, Script.cs:3083-3093 R).
RSpec.describe Lich::Genie::NetDate do
  let(:today) { Time.new(2026, 10, 20, 9, 0, 0, '+13:00') } # its wall-clock date is what counts

  def parse(text) = described_class.parse(text, today: today)

  # Each form below was checked against genieflow's real DateTime.Parse (`timer setstart <text>`,
  # probes): accepted or "Invalid datetime format", and the value through @timer@.
  it 'reads M/d/yyyy, M/d/yy, M-d-yyyy, yyyy-M-d, yyyy/M/d and month-name dates with an optional time' do
    expect(parse('10/20/2026')).to eq(Time.utc(2026, 10, 20))
    expect(parse('1/2/2026 3:04:05 PM')).to eq(Time.utc(2026, 1, 2, 15, 4, 5))
    expect(parse('2026-10-20T13:45')).to eq(Time.utc(2026, 10, 20, 13, 45))
    expect(parse('2026-10-20 13:45:30.25')).to eq(Time.utc(2026, 10, 20, 13, 45, 30.25r))
    expect(parse('2026/10/20 1:02:03')).to eq(Time.utc(2026, 10, 20, 1, 2, 3))
    expect(parse('10-20-2026')).to eq(Time.utc(2026, 10, 20))
    expect([parse('12/31/49').year, parse('1/1/50').year]).to eq([2049, 1950]) # TwoDigitYearMax 2049
    expect(parse('October 20, 2026 12:00 AM')).to eq(Time.utc(2026, 10, 20, 0, 0))
    expect([parse('20 Oct 2026'), parse('Oct. 20, 2026'), parse('20 October, 2026'), parse('Oct 20 2026')].uniq)
      .to eq([Time.utc(2026, 10, 20)])
  end

  it 'accepts a weekday only when it is the date\'s' do
    expect(parse('Tuesday, October 20, 2026')).to eq(Time.utc(2026, 10, 20))
    expect(parse('Tue Oct 20 2026')).to eq(Time.utc(2026, 10, 20))
    expect(parse('Monday, October 20, 2026')).to be_nil
  end

  it 'reads the AM/PM designator: 12 AM is 0, a PM hour below 12 gets 12, 13-23 stay; an hour alone needs one' do
    expect(parse('  11:30 pm ')).to eq(Time.utc(2026, 10, 20, 23, 30))
    expect(parse('12:30 AM')).to eq(Time.utc(2026, 10, 20, 0, 30))
    expect(parse('0:10 PM')).to eq(Time.utc(2026, 10, 20, 12, 10))
    expect(parse('1/2/2026 15:04:05 PM')).to eq(Time.utc(2026, 1, 2, 15, 4, 5))
    expect(parse('1/2/2026 3 PM')).to eq(Time.utc(2026, 1, 2, 15))
    expect(parse('3')).to be_nil
  end

  # genieflow probes nd/nd2/nd3: `T` joins only an ISO yyyy-M-d / yyyy/M/d
  # date to a clock time with no designator; an hour alone needs "am"/"pm" (a lone "a"/"p" is
  # refused); after H:mm a lone "a" is accepted but is NOT the AM designator ("12:00 a" is noon),
  # a lone "p" is refused; a "." may follow a designator.
  it 'joins a date and time with T only in the ISO forms, and reads the designator forms Parse reads' do
    expect([parse('2026/1/1T11:00'), parse('2026-1-1T11:00')].uniq).to eq([Time.utc(2026, 1, 1, 11)])
    ['1/1/2026T11:00', 'Jan 1, 2026T11:00', '1-1-2026T11:00', '1/1/26T11:00', '2026-01-01T11', '2026-1-1T11:00 am',
     '2026-1-1T11:00 a'].each { |text| expect(parse(text)).to be_nil, text }
    ['11 a', '11 p', '11a', '11 A', '11 P.', '11 a.', '11:00 p', '11:00p', '1/1/2026 11 a', '1/1/2026 11:00 P', '1/1/2026 11:00 ap',
     '1/1/2026 11:00 a b'].each { |text| expect(parse(text)).to be_nil, text }
    expect(parse('1/1/2026 11:00 a')).to eq(Time.utc(2026, 1, 1, 11))
    expect([parse('1/1/2026 12:00 a'), parse('1/1/2026 12:00:00 A.')].uniq).to eq([Time.utc(2026, 1, 1, 12)])
    expect(parse('1/1/2026 1:00a')).to eq(Time.utc(2026, 1, 1, 1))
    expect([parse('1/1/2026 11 am.'), parse('1/1/2026 11:00 am.'), parse('1/1/2026 11AM')].uniq).to eq([Time.utc(2026, 1, 1, 11)])
    expect([parse('1/1/2026 11 pm'), parse('1/1/2026 11:00 pM.')].uniq).to eq([Time.utc(2026, 1, 1, 23)])
  end

  it 'refuses year 0 (DateTime starts at year 1) and reads 0001-01-01, the blank timer value' do
    expect([parse('1/1/0000'), parse('0000-01-01')]).to eq([nil, nil])
    expect(parse('1/1/0001')).to eq(Time.utc(1, 1, 1))
    expect(parse('1/1/00')).to eq(Time.utc(2000, 1, 1))
  end

  # v0.26.2: DateTime.Parse gives an Unspecified (naive) time -- its fields, no zone. Times in the
  # US / NZ spring-forward gaps and the doubled fall-back hour keep their fields in any process TZ
  # (Time.local turned 2:30 into 3:30 inside a gap); a time-only text takes the date of the
  # wall clock IN ITS OWN OFFSET (09:00 +13:00 on 10/20 is 10/19 in UTC).
  it 'returns the naive parsed fields whatever the process zone (DST gaps, doubled hour)' do
    ['3/8/2026 2:30 AM', '9/27/2026 2:30 AM', '11/1/2026 1:30 AM', '4/5/2026 2:30 AM'].each do |text|
      result = parse(text)
      expect([text, result.utc?, result.hour, result.min]).to eq([text, true, text.end_with?('1:30 AM') ? 1 : 2, 30])
    end
    expect(parse('11:30 pm')).to eq(Time.utc(2026, 10, 20, 23, 30))
    expect(described_class.parse('0:05', today: Time.new(2026, 12, 31, 23, 0, 0, '-10:00'))).to eq(Time.utc(2026, 12, 31, 0, 5))
  end

  it 'refuses what DateTime.Parse refuses: no date, bad fields, out-of-range values' do
    ['', 'notadate', '13/1/2026', '2/30/2026', '2/29/2025', '24:00', '1/1/2026 10:60', 'Smarch 1, 2026', '20.10.2026']
      .each { |text| expect(parse(text)).to be_nil, text }
    expect(parse('2/29/2024')).to eq(Time.utc(2024, 2, 29))
  end
end
