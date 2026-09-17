# frozen_string_literal: true

module Lich
  # Which login launcher this process presents: the browser WebUI or the
  # native GTK window.
  #
  # Resolved once and read everywhere else. init.rb reads it to decide
  # whether gtk3 is loaded at all, main.rb to decide which login runs,
  # lich.rbw to decide whether the main thread is handed to Gtk.main, and
  # SessionLauncher to give a child session the same answer its parent had.
  # Before this the choice was smeared across those four files as a flag
  # each one re-derived, and flipping one without the others left the
  # process half in each world.
  #
  # Priority, highest first:
  #   1. an explicit flag on the command line: --webui or --gtk
  #      (--webui-dev is kept as an alias of --webui for one release)
  #   2. the persisted setting `launcher` in lich_settings, which the
  #      launcher UI can write
  #   3. DEFAULT
  #
  # Changing the project's default launcher is changing DEFAULT: one word,
  # one commit, one spec line. It does not remove GTK; only deleting the
  # :gtk choice does that.
  module LauncherChoice
    # The launchers a process can present.
    CHOICES = %i[webui gtk].freeze
    # The launcher used when neither a flag nor a persisted setting decides.
    DEFAULT = :webui
    # Name of the row in lich_settings that persists the choice.
    SETTING = 'launcher'
    # Command-line flags and the choice each one selects.
    FLAGS = { '--webui' => :webui, '--webui-dev' => :webui, '--gtk' => :gtk }.freeze
    # How many times {.setting} retries a locked database before giving up.
    BUSY_RETRIES = 20

    module_function

    # Resolves the launcher: the command-line flag, else the persisted setting, else the default.
    #
    # @param argv [Array<String>] the command line
    # @param setting [#call] reads the persisted choice; nil when there is none
    # @param default [Symbol] the fallback when neither argv nor the setting decides
    # @return [Symbol] :webui or :gtk
    def resolve(argv: ARGV, setting: method(:setting), default: DEFAULT)
      flag(argv) || setting.call || default
    end

    # The last launcher flag on the command line, or nil.
    #
    # The last one wins so a wrapper script can append its own choice after the user's.
    #
    # @param argv [Array<String>, String, nil] the command line; a non-array is wrapped with +Array()+
    # @return [Symbol, nil] :webui or :gtk, or nil when no launcher flag is present
    def flag(argv)
      Array(argv).reverse_each do |argument|
        choice = FLAGS[argument.to_s.downcase]
        return choice if choice
      end
      nil
    end

    # The persisted choice, or nil when there is none or it cannot be read yet.
    #
    # init.rb asks before the data directory necessarily exists (a first
    # run), so an unreadable setting is "no setting", never an error: the
    # flag or the default decides.
    #
    # @return [Symbol, nil] :webui or :gtk, or nil when unset, unreadable, or not a known choice
    def setting
      return nil unless Lich.respond_to?(:db) && defined?(DATA_DIR) && File.directory?(DATA_DIR)

      retries = 0
      begin
        normalize(Lich.db.get_first_value('SELECT value FROM lich_settings WHERE name=?;', [SETTING]))
      rescue SQLite3::BusyException
        retries += 1
        raise if retries > BUSY_RETRIES

        sleep 0.1
        retry
      end
    rescue StandardError
      nil
    end

    # Persists the choice; nil or an unknown value clears it.
    #
    # (An assignment evaluates to its right-hand side in Ruby; read `setting` back to see
    # what was stored.)
    #
    # @param value [Symbol, String, nil] :webui, :gtk (any case), or nil to clear
    # @return [void]
    def setting=(value)
      choice = normalize(value)
      if choice
        Lich.db.execute('INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);', [SETTING, choice.to_s])
      else
        Lich.db.execute('DELETE FROM lich_settings WHERE name=?;', [SETTING])
      end
    end

    # Coerces a flag, setting or symbol to one of {CHOICES}.
    #
    # @param value [Symbol, String, nil] the raw value; whitespace and case are ignored
    # @return [Symbol, nil] :webui or :gtk, or nil when the value is nil or not a known choice
    def normalize(value)
      return nil if value.nil?

      choice = value.to_s.strip.downcase.to_sym
      CHOICES.include?(choice) ? choice : nil
    end

    # The persisted choice as the launcher UI sees it: "the native launcher next time" or not.
    #
    # The launcher never names a toolkit, so the core boundary check has
    # nothing to find there.
    #
    # @return [Boolean] true when the persisted setting is :gtk
    def native_next?
      setting == :gtk
    end

    # Persists "the native launcher next time" (true) or the WebUI (false).
    #
    # @param wanted [Boolean] whether the native launcher should open next time
    # @return [void]
    def native_next=(wanted)
      self.setting = wanted ? :gtk : :webui
    end
  end

  # The launcher this process runs, resolved on first use and then fixed.
  #
  # @return [Symbol] :webui or :gtk
  def self.launcher
    @launcher ||= LauncherChoice.resolve
  end

  # Forgets the resolved choice so the next read resolves again.
  #
  # For specs and for a launcher UI that has just written the setting.
  #
  # @return [void]
  def self.reset_launcher!
    @launcher = nil
  end
end
