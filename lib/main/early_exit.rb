# frozen_string_literal: true

require_relative 'help_text'

module Lich
  module Main
    # Commands that print to stdout and exit without starting a session.
    #
    # lich.rbw dispatches these before Lich::GemCheck.verify! and before
    # lib/init.rb requires GTK, so they stay usable on a runtime that cannot
    # load a toolkit. Without that ordering, `--help` cannot report the very
    # options that make a headless launch work.
    #
    # The allow-list is deliberately syntactic. It reads ARGV and nothing else.
    # DISPLAY, TTY, and cron state never select a launch mode here, which keeps
    # the guarantee that #1439 introduced.
    #
    # Membership is limited to commands that need no directory, no log file,
    # and no database. lib/init.rb creates all three after the GTK require, so
    # a command that needs any of them cannot move into this module.
    module EarlyExit
      HELP_FLAGS = ['-h', '--help'].freeze
      HELP_TOPIC_PREFIX = '--help='
      VERSION_FLAGS = ['-v', '--version'].freeze

      module_function

      # Prints the first selected command and exits. Returns when the arguments
      # select no command handled here.
      #
      # @param argv [Array<String>] command-line arguments
      # @return [void]
      def dispatch!(argv = ARGV)
        argv = Array(argv)
        argv.each do |arg|
          if help?(arg)
            print_help(HelpText.topic_from_argv(argv, arg))
            exit
          elsif version?(arg)
            print_version
            exit
          end
        end
      end

      # @param argv [Array<String>] command-line arguments
      # @return [Boolean] whether the arguments select a command handled here
      def requested?(argv = ARGV)
        Array(argv).any? { |arg| help?(arg) || version?(arg) }
      end

      # @param arg [String] one command-line argument
      # @return [Boolean]
      def help?(arg)
        HELP_FLAGS.include?(arg) || arg.to_s.start_with?(HELP_TOPIC_PREFIX)
      end

      # @param arg [String] one command-line argument
      # @return [Boolean]
      def version?(arg)
        VERSION_FLAGS.include?(arg)
      end

      # @param topic [String, nil] optional help topic
      # @return [void]
      def print_help(topic = nil)
        puts HelpText.render(topic)
      end

      # @return [void]
      def print_version
        puts "The Lich, version #{LICH_VERSION}"
        puts ' (an implementation of the Ruby interpreter by Yukihiro Matsumoto designed to be a \'script engine\' for text-based MUDs)'
        puts ''
        puts '- The Lich program and all material collectively referred to as "The Lich project" is copyright (C) 2005-2006 Murray Miron.'
        puts '- The Gemstone IV and DragonRealms games are copyright (C) Simutronics Corporation.'
        puts '- The Wizard front-end and the StormFront front-end are also copyrighted by the Simutronics Corporation.'
        puts '- Ruby is (C) Yukihiro \'Matz\' Matsumoto.'
        puts ''
        puts 'Thanks to all those who\'ve reported bugs and helped me track down problems on both Windows and Linux.'
      end
    end
  end
end
