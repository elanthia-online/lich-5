# frozen_string_literal: true

module Lich
  module Genie
    # The forms of .NET `DateTime.Parse(text)` (en-US culture) that `timer setstart <date>` reads
    # (EvalTimer, Script.cs:3083-3093 R; 0 corpus uses), each checked against genieflow
    # probes: an optional weekday ("Tue", "Tuesday,", which must be the date's), a date as
    # M/d/yyyy, M/d/yy (yy <= 49 is 20yy), M-d-yyyy, yyyy-M-d, yyyy/M/d or with an English month
    # name ("October 20, 2026", "Oct. 20 2026", "20 October, 2026"), optionally followed by a time
    # (H:mm[:ss[.fff]] or "3 PM", with an AM/PM designator; after the ISO yyyy-M-d / yyyy/M/d
    # forms also `T` + H:mm[:ss[.fff]]), or a time alone (on the wall clock's date). The result
    # is DateTimeKind.Unspecified -- a naive wall-clock time, compared with DateTime.Now by its
    # fields alone -- so it is built as a UTC Time carrying exactly the parsed fields (never
    # Time.local: in the process zone's DST gap "3/8/2026 2:30 AM" would turn into 3:30, and the
    # result would depend on the machine's TZ; v0.26.2). Every other text is
    # nil -- Parse's FormatException. DateTime.Parse accepts still more (UTC offsets, month-year
    # forms, ...): tracked in open-items.md Q4 (0 corpus uses).
    module NetDate
      module_function

      MONTHS = %w[january february march april may june july august september october november december].freeze
      WEEKDAYS = %w[sun mon tue wed thu fri sat].freeze

      WEEKDAY = /(?:(?<wday>sun|mon|tue|wed|thu|fri|sat)[a-z]*\.?,?\s+)?/i
      CLOCK = /(?<hour>\d{1,2}):(?<min>\d{2})(?::(?<sec>\d{2})(?:\.(?<frac>\d{1,7}))?)?/
      # After H:mm an "am"/"pm" designator (a "." may follow) or a lone "a", which Parse accepts
      # but does not take as AM ("12:00 a" is noon); an hour alone needs a full "am"/"pm"; a lone
      # "p" is refused (genieflow probes).
      TIME = /(?:#{CLOCK}(?:\s*(?:(?<ampm>[ap]m)|a)\.?)?|(?<hour>\d{1,2})\s*(?<ampm>[ap]m)\.?)/i
      # Each date form with the time that may follow it: `T` + a bare clock time only after the
      # ISO yyyy-M-d / yyyy/M/d forms ("1/1/2026T11:00" is refused).
      DATES = [
        [%r{(?<month>\d{1,2})[/-](?<day>\d{1,2})[/-](?<year>\d{4}|\d{2})}, false],
        [%r{(?<year>\d{4})[/-](?<month>\d{1,2})[/-](?<day>\d{1,2})}, true],
        [/(?<mname>[a-z]{3,9})\.?\s+(?<day>\d{1,2}),?\s+(?<year>\d{4})/i, false],
        [/(?<day>\d{1,2})\s+(?<mname>[a-z]{3,9})\.?,?\s+(?<year>\d{4})/i, false]
      ].map do |date_form, iso|
        time = iso ? /(?:T#{CLOCK}|\s+#{TIME})/ : /\s+#{TIME}/
        /\A#{WEEKDAY}#{date_form}#{time}?\z/
      end.freeze

      # @param text [String]
      # @param today [Time] the date a time-only text falls on
      # @return [Time, nil] a UTC Time whose fields are the parsed naive wall-clock time
      def parse(text, today: Time.now)
        s = Text.net_trim(text.to_s)
        return nil if s.empty?

        DATES.each do |form|
          match = form.match(s)
          return build(match) if match
        end
        match = /\A#{TIME}\z/.match(s)
        match && build(match, today: today)
      end

      # @return [Time, nil] nil for an out-of-range field (year 0 included: DateTime starts at
      #   0001-01-01) or a weekday that is not the date's
      def build(match, today: nil)
        year, month, day = date_fields(match, today)
        return nil if year < 1 || month.nil? || !(1..12).cover?(month) || day < 1 || day > days_in(year, month)

        hour, min, sec, frac = time_fields(match)
        return nil if hour.nil?

        time = Time.utc(year, month, day, hour, min, sec + frac) # naive (Unspecified): no zone, no DST gap
        wday = match.names.include?('wday') && match[:wday]
        return nil if wday && WEEKDAYS.index(wday.downcase) != time.wday

        time
      end

      def date_fields(match, today)
        return [today.year, today.month, today.day] if today

        month = if match.names.include?('mname')
                  name = match[:mname].downcase
                  index = MONTHS.index { |full| full == name || (name.length == 3 && full.start_with?(name)) }
                  index && (index + 1)
                else
                  match[:month].to_i
                end
        year = match[:year].to_i
        year += year <= 49 ? 2000 : 1900 if match[:year].length == 2 # TwoDigitYearMax 2049
        [year, month, match[:day].to_i]
      end

      # A designator: 12 AM is 0, a PM hour below 12 gets 12 added, 13-23 stay (genieflow probes).
      def time_fields(match)
        return [0, 0, 0, 0] unless match.names.include?('hour') && match[:hour]

        hour = match[:hour].to_i
        min = match[:min].to_i
        sec = match[:sec].to_i
        frac = match[:frac] ? Rational(match[:frac].to_i, 10**match[:frac].length) : 0
        return nil if hour > 23 || min > 59 || sec > 59

        if match.names.include?('ampm') && match[:ampm]
          pm = match[:ampm].downcase.start_with?('p')
          hour = 0 if !pm && hour == 12
          hour += 12 if pm && hour < 12
        end
        [hour, min, sec, frac]
      end

      def days_in(year, month)
        return 29 if month == 2 && (year % 4).zero? && (!(year % 100).zero? || (year % 400).zero?)

        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
      end
    end
  end
end
