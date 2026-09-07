# frozen_string_literal: true

module Lich
  module Main
    # Resolves and applies Lich's persisted or explicitly requested startup theme.
    module StartupTheme
      # Apply the effective dark-mode setting for this process.
      #
      # An explicit command-line value takes precedence and becomes the new
      # persisted preference. Otherwise, the existing preference is used.
      #
      # @param argv_options [Hash] parsed command-line options
      # @return [Boolean] the effective dark-mode setting
      # @raise [ArgumentError] if the options or dark-mode value are invalid
      def self.apply(argv_options)
        raise ArgumentError, 'argv_options must be a Hash' unless argv_options.is_a?(Hash)

        explicit = argv_options.key?(:dark_mode)
        theme_state = explicit ? argv_options[:dark_mode] : Lich.track_dark_mode
        unless theme_state == true || theme_state == false
          raise ArgumentError, 'dark_mode must be true or false'
        end

        Lich.track_dark_mode = theme_state if explicit
        Gtk::Settings.default.gtk_application_prefer_dark_theme = theme_state if defined?(Gtk)
        theme_state
      end
    end
  end
end
