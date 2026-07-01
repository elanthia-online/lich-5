# lib/gemcheck.rb
require 'bundler'

module Lich
  # Verifies bundled gems are installed at Lich startup and alerts the
  # user via a native OS dialog (with a log-file fallback) when any
  # are missing. Runs once during boot, before scripts load.
  module GemCheck
    WINDOWS_MESSAGE = "You're missing required Ruby gems!\n\n" \
                      "Please update to the latest Ruby version using the\n" \
                      "Ruby4Lich5 installer."
    UNIX_MESSAGE    = "You're missing required Ruby gems!\n\n" \
                      "Please run 'bundle install' from your Lich5 folder."
    TITLE           = 'Lich5: Missing Ruby Gems'
    RELEASE_URL     = 'https://github.com/elanthia-online/lich-5/releases/latest'
    LOG_FILENAME    = 'lich5-missing-gems.log'

    module_function

    # Runs Bundler.setup for the given groups; on failure, alerts the
    # user and exits.
    # @param groups [Array<Symbol>] Bundler groups to verify
    # @return [void]
    def verify!(*groups)
      groups = [:default] if groups.empty?
      Bundler.setup(*groups)
    rescue Bundler::GemNotFound, Bundler::GitError
      alert
      exit 1
    end

    # @return [void]
    def alert
      write_log
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then alert_windows
      when /darwin/             then alert_macos
      else                           alert_linux
      end
    end

    # @return [String] the message appropriate for the current platform
    def message
      case RUBY_PLATFORM
      when /mswin|mingw|cygwin/ then WINDOWS_MESSAGE
      else                           UNIX_MESSAGE
      end
    end

    # @return [void]
    def write_log
      log_path = File.join(TEMP_DIR, LOG_FILENAME)
      File.open(log_path, 'a') do |f|
        f.puts "[#{Time.now}] Missing required Ruby gems"
        f.puts message.gsub(/^/, '  ')
        f.puts "  Download: #{RELEASE_URL}" if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
        f.puts
      end
    rescue StandardError
      # Filesystem write failed; continue to GUI attempt.
    end

    # @return [void]
    def alert_windows
      require 'win32ole'
      shell = WIN32OLE.new('WScript.Shell')
      result = shell.Popup("#{WINDOWS_MESSAGE}\n\nClick OK to open the download page.",
                           0, TITLE, 1 + 64) # OK/Cancel + Information icon
      shell.Run(RELEASE_URL) if result == 1
    end

    # @return [void]
    def alert_macos
      as_message = UNIX_MESSAGE.split("\n").map(&:inspect).join(' & return & ')
      script = %(display dialog #{as_message} ) +
               %(with title #{TITLE.inspect} ) +
               %(buttons {"OK"} default button "OK" with icon caution)
      IO.popen(['osascript', '-'], 'r+') do |io|
        io.write(script)
        io.close_write
        io.read
      end
    end

    # @return [void]
    def alert_linux
      if cmd_available?('zenity')
        system('zenity', '--info', '--title', TITLE, '--text', UNIX_MESSAGE)
      elsif cmd_available?('kdialog')
        system('kdialog', '--title', TITLE, '--msgbox', UNIX_MESSAGE)
      elsif cmd_available?('xmessage')
        system('xmessage', '-center', UNIX_MESSAGE)
      else
        warn "!!ALERT!! #{UNIX_MESSAGE}"
      end
    end

    # @param cmd [String] executable name to probe
    # @return [Boolean]
    def cmd_available?(cmd)
      system('which', cmd, out: File::NULL, err: File::NULL)
    end
  end
end
