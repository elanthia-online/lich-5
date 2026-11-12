# frozen_string_literal: true

require 'fileutils'

module Lich
  module Genie
    # Port of Remix Utility/Log.cs (R), what `#log` writes (Command.cs:361-385 R): LogText
    # appends to the character's daily log, LogLine appends one line to a named file. The
    # directory is Remix's LogDirectory under its folder; ours is the engine's log dir
    # (Lich::Genie.directories['logdir']), created when missing as Remix's startup creates Logs
    # (FormMain.cs:2458 R) -- but no other directory: a file in a missing folder fails like
    # StreamWriter does. A failure reaches +on_error+ (Remix: GenieError.Error
    # ("LogText"/"LogLine", message), whose handler re-raises without end, Game.cs:3291-3294 R;
    # ours: the caller's one error line) and nothing reaches a script. One lock
    # (Remix's m_oThreadLock) makes the new-file test and its header write one step; Remix gives
    # up silently after 100 ms of waiting for it (Monitor.TryEnter), ours waits.
    module LogFile
      module_function

      CRLF = "\r\n"
      LOCK = Mutex.new

      # Log.LogText (Log.cs:13-55 R): nothing without a character name; the file is
      # "<character><instance>_<yyyy-MM-dd>.log" in +dir+, a new one starting with
      # "*** LOG CREATED AT <DateTime.Now> ***" and a blank line; the text is written as given.
      # @param text [String]
      # @param character [String] $charactername
      # @param instance [String] $game
      # @param dir [String]
      # @param now [Time] DateTime.Now
      # @param on_error [#call, nil] callable(section, message) for a failed write
      # @return [Boolean] whether it was written
      def log_text(text, character:, instance:, dir:, now: Time.now, on_error: nil)
        return false if character.to_s.empty?

        LOCK.synchronize do
          path = File.join(base(dir), "#{character}#{instance}_#{now.strftime('%Y-%m-%d')}.log")
          text = "*** LOG CREATED AT #{date_time(now)} ***#{CRLF}#{CRLF}#{text}" unless File.exist?(path)
          append(path, text, 'LogText', on_error)
        end
      end

      # Log.LogLine (Log.cs:57-94 R): +file_name+ under +dir+ unless it holds a `\` (then it is a
      # path of its own); a rooted name (`/x/y.log`) is its own path too, as Path.Combine makes
      # it; the text plus a line end.
      # @param text [String]
      # @param file_name [String]
      # @param dir [String]
      # @param on_error [#call, nil] callable(section, message) for a failed write
      # @return [Boolean]
      def log_line(text, file_name:, dir:, on_error: nil)
        LOCK.synchronize do
          path = if file_name.include?('\\') then file_name.tr('\\', File::SEPARATOR)
                 elsif File.absolute_path?(file_name) then file_name
                 else File.join(base(dir), file_name)
                 end
          append(path, "#{text}#{CRLF}", 'LogLine', on_error)
        end
      end

      # DateTime.ToString() in en-US: "M/d/yyyy h:mm:ss tt", where ICU's (CLDR 42+) long time pattern
      # puts a NARROW NO-BREAK SPACE (U+202F) before AM/PM -- what .NET 8+ prints with ICU (a genieflow
      # probe: "(1/1/2026 12:00:01<U+202F>PM)"; Remix on Windows uses ICU too).
      # @param time [Time]
      # @return [String]
      def date_time(time)
        hour = ((time.hour + 11) % 12) + 1
        "#{time.month}/#{time.day}/#{format('%04d', time.year)} #{hour}:#{time.strftime('%M:%S')}#{NARROW_NBSP}#{time.hour < 12 ? 'AM' : 'PM'}"
      end

      # U+202F (ASCII-only source).
      NARROW_NBSP = [0x202F].pack('U').freeze

      # The log dir itself, created when missing (Remix's startup CreateDirectory of Logs); a
      # failure there surfaces as the write's own error.
      def base(dir)
        FileUtils.mkdir_p(dir)
        dir
      rescue StandardError
        dir
      end

      def append(path, text, section, on_error)
        File.open(path, 'ab') { |file| file.write(text.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)) }
        true
      rescue StandardError => e
        begin
          on_error&.call(section, e.message)
        rescue StandardError
          nil
        end
        false
      end
    end
  end
end
