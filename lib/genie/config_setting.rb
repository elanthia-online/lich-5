# frozen_string_literal: true

require 'fileutils'

module Lich
  module Genie
    # Port of Remix Config.SetSetting's runtime contract (Lists/Config.cs:569-1490 R) as the
    # `#config` command sees it (Command.cs:1491-1525 R): which keys exist, which values make it
    # throw, and the messages it returns -- "Set <key>: <value>" and "Don't forget to #save
    # config" for every recognized key (the key lower-cased: `switchExpr`, Config.cs:576, 1481 R),
    # after a directory key's ValidateDirectory line. The router echoes them; a throw becomes
    # "Invalid syntax: <row>" plus the message. The VALUES the engine reads live in
    # {GameState::Config} (applied separately); every other key is a front-end or launcher setting
    # Remix keeps and we only acknowledge.
    module ConfigSetting
      module_function

      # Keys whose value SetSetting stores without any check (Config.cs:579-1476 R): the
      # on/true/1 switches, the chars (first char of a non-empty value), the text settings and
      # the number settings parsed by StringToInteger / StringToDouble (which never throw).
      UNCHECKED = %w[
        scriptchar scriptextension triggeroninput separatorchar commandchar mycommandchar maxrowbuffer
        spelltimer autolog classicconnect servertimeoutcommand usertimeoutcommand prompt promptbreak
        promptforce condensed monstercountignorelist roundtimeoffset artrepo scriptrepo maprepo
        ignorescriptwarnings reconnect ignoreclosealert muted keepinputtext abortdupescript parsegameonly
        autoupdate autoupdatelamp checkforupdates connectstring cmdpath rubypath lichpath licharguments
        lichserver connectscript automapper showlinks showimages sizeinputtogame updatemapperscripts
        alwaysontop weblinksafety
      ].to_h { |key| [key, true] }.freeze

      # Conversions.ToInteger(Utility.StringToDouble(value)) for a non-empty value (Config.cs:743-781 R).
      ROUNDED_DOUBLE = %w[scripttimeout scriptmatchtimeout servertimeout usertimeout].freeze
      # Conversions.ToInteger(value) for a non-empty value (Config.cs:905-912, 1458-1476 R).
      VB_INTEGER = %w[maxgosubdepth historysize historyminlength].freeze
      # Convert.ToInt32(value) for a non-empty value (Config.cs:1262-1278, 1308-1317 R).
      INT32 = %w[lichstartpause lichport automapperalpha].freeze
      # LocalDirectory.ValidateDirectory(value) first, whatever the value (Config.cs:924-993 R).
      DIRECTORY = %w[artdir scriptdir mapdir sounddir plugindir configdir logdir].freeze

      # Convert.ToInt32(string) / int.Parse's messages (.NET 8+).
      FORMAT = "The input string '%s' was not in a correct format."
      INT32_OVERFLOW = 'Value was either too large or too small for an Int32.'

      # Config.SetSetting(key, value) at run time (bShowException true).
      # @param key [String]
      # @param value [String]
      # @param file_exists [#call] callable(path) => Boolean: File.Exists for `editor`
      # @param directory [#call] callable(path) => String: LocalDirectory.ValidateDirectory's
      #   message for a directory key (it may raise {Error} "Error Setting Directory: ...")
      # @return [Array<String>] the messages (none for an empty key)
      # @raise [Error] the exception SetSetting throws ("Config <key> was not recognized.", a
      #   conversion message, "Directory does not exist: <value>")
      def set(key, value, file_exists:, directory:)
        key = key.to_s
        value = value.to_s
        return [] if key.empty?

        name = Text.net_downcase(key)
        messages = []
        if UNCHECKED.key?(name) then nil
        elsif ROUNDED_DOUBLE.include?(name) then VbConversions.double_to_integer(Numeric.string_to_double(value)) unless value.empty?
        elsif VB_INTEGER.include?(name) then VbConversions.to_integer(value) unless value.empty?
        elsif INT32.include?(name) then value = int32_setting(name, value) unless value.empty?
        elsif DIRECTORY.include?(name) then messages << directory.call(value).to_s
        elsif name == 'editor' then raise Error, "Directory does not exist: #{value}" unless file_exists.call(value)
        else raise Error, "Config #{name} was not recognized."
        end
        messages << "Set #{name}: #{value}" << "Don't forget to #save config"
      end

      # Convert.ToInt32(value); `automapperalpha`'s setter clamps to 0..255 and the message shows
      # the clamped value (Config.cs:87-99, 1308-1317 R).
      # @return [String] the value the message shows
      def int32_setting(name, value)
        number = int32(value)
        return value unless name == 'automapperalpha'

        number.clamp(0, 255).to_s
      end

      # Convert.ToInt32(string): Int32.Parse with NumberStyles.Integer (current culture en-US).
      # @param text [String]
      # @return [Integer]
      # @raise [Error] FormatException / OverflowException messages
      def int32(text)
        match = text.match(Numeric::NET_INT32)
        raise Error, format(FORMAT, text) unless match

        number = Integer(match[2], 10) * (match[1] == '-' ? -1 : 1)
        raise Error, INT32_OVERFLOW unless VbConversions::INT32_RANGE.cover?(number)

        number
      end

      # LocalDirectory.ValidateDirectory (LocalDirectory.cs:34-51 R) over +base+ (Remix: the
      # Genie folder; ours: the engine's config tree): a path that is not rooted is taken
      # under +base+; an existing directory is "Diretory Found: <full>" (Remix's spelling), a
      # missing one is created and "Directory Created: <full>"; a failure raises "Error Setting
      # Directory: <message>". The full name keeps a trailing separator (DirectoryInfo.FullName).
      # @param path [String]
      # @param base [String]
      # @param create [Boolean] whether a missing directory is really created (the flow harness
      #   reports "Directory Created" without touching its fixture tree)
      # @return [String]
      # @raise [Error]
      def validate_directory(path, base:, create: true)
        full = rooted?(path) ? path : "#{base}#{File::SEPARATOR}#{path}"
        expanded = File.expand_path(full)
        expanded = "#{expanded}#{File::SEPARATOR}" if full.end_with?('/', '\\') && !expanded.end_with?(File::SEPARATOR)
        return "Diretory Found: #{expanded}" if File.directory?(expanded)

        FileUtils.mkdir_p(expanded) if create
        "Directory Created: #{expanded}"
      rescue SystemCallError, IOError, ArgumentError => e
        raise Error, "Error Setting Directory: #{e.message}"
      end

      # Path.IsPathRooted: a leading separator or a drive letter.
      def rooted?(path)
        path.start_with?('/', '\\') || path.match?(/\A[A-Za-z]:/)
      end
    end
  end
end
