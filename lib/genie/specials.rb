# frozen_string_literal: true

module Lich
  module Genie
    # Resolver for Genie's `@...@` special variables: Remix Globals.ParseSpecialVariables
    # (Globals.cs:206-244 R) plus the Script-only @timer@.
    #
    # The clock and timer are injected so this is deterministic under test and so the
    # interpreter can supply the real elapsed-timer value. +source+ (a {Variables}) gives
    # the spell timer start ({ReservedState#spell_time_start}), the $casttime /
    # $spellstarttime globals the spell specials read, and nothing else.
    #
    # Formats are .NET's en-US custom formats, verbatim from Globals.cs:224-236 R:
    # "M/d/yyyy" has no zero padding, "HH:mm:ss tt" is a 24-hour clock WITH an AM/PM
    # designator, DayOfYear is unpadded, and "mm" (@month@) is MINUTES, not the month.
    class Specials
      # Remix replaces these in this order (Globals.cs:208-243 R).
      SPELL_TOKENS = %w[@spelltime@ @spellpreptime@ @casttimeremaining@].freeze
      DIR_TOKENS = %w[scriptdir mapdir plugindir artdir logdir sounddir].freeze

      # @param clock [#call] returns a Time (defaults to Time.now)
      # @param timer [#call] returns the script timer's @timer@ text (Script.ParseVariables,
      #   Script.cs:2350-2361 R; the interpreter's {Interpreter#timer_text}; defaults to "0")
      # @param source [Variables, nil] global variables + reserved game state
      # @param directories [Hash{String=>String}, nil] the engine's directories for
      #   @scriptdir@ ... (defaults to {Lich::Genie.directories})
      def initialize(clock: -> { Time.now }, timer: -> { '0' }, source: nil, directories: nil)
        @clock = clock
        @timer = timer
        @source = source
        @directories = directories
      end

      # @return [Hash{String=>String}] token => current value, computed now, in Remix's
      #   replacement order. A token absent from the hash stays literal (Remix leaves
      #   @spellpreptime@ alone when no spell is being prepared).
      def substitutions
        time = @clock.call
        out = { '@timer@' => @timer.call.to_s }
        out.merge!(spell_substitutions(time))
        out.merge!(time_substitutions(time))
        (@directories || Lich::Genie.directories).each { |name, path| out["@#{name}@"] = path.to_s }
        out
      end

      private

      def time_substitutions(time)
        hour12 = format('%02d', ((time.hour + 11) % 12) + 1)
        ampm = time.hour < 12 ? 'AM' : 'PM'
        clock12 = "#{hour12}:#{time.strftime('%M:%S')} #{ampm}"
        clock24 = "#{time.strftime('%H:%M:%S')} #{ampm}"
        date = "#{time.month}/#{time.day}/#{format('%04d', time.year)}"
        {
          '@time@'         => clock12,
          '@time24@'       => clock24,
          '@date@'         => date,
          '@datetime@'     => "#{date} #{clock12}",
          '@datetime24@'   => "#{date} #{clock24}",
          '@militarytime@' => time.strftime('%H%M'),
          '@unixtime@'     => time.to_i.to_s,
          '@year@'         => format('%04d', time.year),
          '@month@'        => time.strftime('%M'), # QUIRK: "mm" is minutes, not month
          '@dayofmonth@'   => time.strftime('%d'),
          '@dayofyear@'    => time.yday.to_s
        }
      end

      # Globals.cs:208-222 R. d = milliseconds since the spell timer started (TimeSpan
      # ticks / 10000); while it runs, @spellpreptime@ = int.Parse($casttime) -
      # int.Parse($spellstarttime) and @casttimeremaining@ = that minus d/1000, floored at
      # "0" (as the string "0"). With no spell timer both timers read "0".
      def spell_substitutions(time)
        start = @source&.game_state.respond_to?(:spell_time_start) ? @source.game_state.spell_time_start : nil
        elapsed_ms = start ? ((time - start) * 10_000_000).round / 10_000.0 : 0.0
        return { '@spelltime@' => '0', '@casttimeremaining@' => '0' } unless start && elapsed_ms.positive?

        seconds = elapsed_ms / 1000
        length = (parse_int('casttime') - parse_int('spellstarttime')).to_f
        remaining = length - seconds
        {
          '@spelltime@'         => Numeric.format_double(seconds),
          '@spellpreptime@'     => Numeric.format_double(length),
          '@casttimeremaining@' => remaining.positive? ? Numeric.format_double(remaining) : '0'
        }
      end

      # int.Parse(VariableList[name].ToString()): an unparsable value throws in Remix
      # (out of ParseSpecialVariables); ours raises a Genie error the same way.
      def parse_int(name)
        raw = @source.global_get(name)
        Numeric.net_int32(raw) || raise(Error, "Input string was not in a correct format. ($#{name} = #{raw.inspect})")
      end
    end
  end
end
