# frozen_string_literal: true

module Lich
  module Genie
    # Reads a Genie settings.cfg the way Remix's Config.Load does (Lists/Config.cs:531-565
    # R): every line goes through ParseArgs and a line of exactly three arguments
    # (`#config {key} {value}`) sets key = value; anything else is skipped, and a row
    # ParseArgs throws on is skipped too ("No one cares", Config.cs:550-553 R). Only the
    # raw key/value pairs are returned; each consumer applies Remix's SetSetting rules for
    # the keys it owns ({GameState::Config.from_settings}).
    module SettingsFile
      module_function

      # @param path [String, nil]
      # @return [Array<Array(String, String)>] [key, value] pairs in file order (SetSetting
      #   runs once per row, so a consumer folds them in order); empty when the file is
      #   absent or unreadable
      def read(path)
        lines = ConfigFile.read_lines(path)
        return [] if lines.nil?

        lines.filter_map do |line|
          args = begin
            Text.parse_args(line)
          rescue Error
            next
          end
          [args[1], args[2]] if args.length == 3
        end
      rescue StandardError
        []
      end
    end
  end
end
