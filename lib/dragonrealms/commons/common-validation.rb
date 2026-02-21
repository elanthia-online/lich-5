# frozen_string_literal: true

module Lich
  module DragonRealms
    class CharacterValidator
      LNET_SCRIPT_NAME = 'lnet'
      FIND_NOT_FOUND = 'There are no adventurers in the realms that match the names specified'

      def initialize(announce, should_sleep, greet, name)
        waitrt?
        fput('sleep') if should_sleep

        @lnet = (Script.running + Script.hidden).find { |val| val.name == LNET_SCRIPT_NAME }
        @validated_characters = []
        @greet = greet
        @name = name

        unless lnet_available?
          Lich::Messaging.msg("bold", "CharacterValidator: lnet is not running. Chat features will be unavailable.")
          return
        end

        send_chat("#{@name} is up and running in room #{Room.current.id}! Whisper me 'help' for more details.") if announce
      end

      def send_slack_token(character)
        return unless lnet_available?

        message = "slack_token: #{UserVars.slack_token || 'Not Found'}"
        Lich::Messaging.msg("plain", "CharacterValidator: Attempting to DM #{character} with message: #{message}")
        send_chat_to(character, message)
      end

      def validate(character)
        return if valid?(character)
        return unless lnet_available?

        Lich::Messaging.msg("plain", "CharacterValidator: Attempting to validate: #{character}")
        @lnet.unique_buffer.push("who #{character}")
      end

      def confirm(character)
        return if valid?(character)

        Lich::Messaging.msg("plain", "CharacterValidator: Successfully validated: #{character}")
        @validated_characters << character

        return unless @greet

        put "whisper #{character} Hi! I'm your friendly neighborhood #{@name}. Whisper me 'help' for more details. Don't worry, I've memorized your name so you won't see this message again."
      end

      def valid?(character)
        @validated_characters.include?(character)
      end

      def send_bankbot_balance(character, balance)
        return unless lnet_available?

        message = "Current Balance: #{balance}"
        Lich::Messaging.msg("plain", "CharacterValidator: Attempting to DM #{character} with message: #{message}")
        send_chat_to(character, message)
      end

      def send_bankbot_location(character)
        return unless lnet_available?

        message = "Current Location: #{Room.current.id}"
        Lich::Messaging.msg("plain", "CharacterValidator: Attempting to DM #{character} with message: #{message}")
        send_chat_to(character, message)
      end

      def send_bankbot_help(character, messages)
        return unless lnet_available?

        messages.each do |message|
          Lich::Messaging.msg("plain", "CharacterValidator: Attempting to DM #{character} with message: #{message}")
          send_chat_to(character, message)
        end
      end

      def in_game?(character)
        result = DRC.bput("find #{character}", FIND_NOT_FOUND, /^\s{2}#{character}\.$/, 'Unknown command')
        result =~ /^\s{2}#{character}\.$/
      end

      private

      def lnet_available?
        !@lnet.nil?
      end

      def send_chat(message)
        @lnet.unique_buffer.push("chat #{message}")
      end

      def send_chat_to(character, message)
        @lnet.unique_buffer.push("chat to #{character} #{message}")
      end
    end
  end
end
