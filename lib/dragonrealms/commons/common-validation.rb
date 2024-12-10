class CharacterValidator
  def initialize(announce, sleep, greet, name)
    waitrt?
    fput('sleep') if sleep

    @lnet = (Script.running + Script.hidden).find { |val| val.name == 'lnet' }
    @validated_characters = []
    @greet = greet
    @name = name

    @lnet.unique_buffer.push("chat #{@name} is up and running in room #{Room.current.id}! Whisper me 'help' for more details.") if announce
  end

  def send_slack_token(character)
    message = "slack_token: #{UserVars.slack_token || 'Not Found'}"
    echo "Attempting to DM #{character} with message: #{message}"
    @lnet.unique_buffer.push("chat to #{character} #{message}")
  end

  def validate(character)
    return if valid?(character)

    echo "Attempting to validate: #{character}"
    @lnet.unique_buffer.push("who #{character}")
  end

  def confirm(character)
    return if valid?(character)

    echo "Successfully validated: #{character}"
    @validated_characters << character

    return unless @greet

    put "whisper #{character} Hi! I'm your friendly neighborhood #{@name}. Whisper me 'help' for more details. Don't worry, I've memorized your name so you won't see this message again."
  end

  def valid?(character)
    @validated_characters.include?(character)
  end

  def send_bankbot_balance(character, balance)
    message = "Current Balance: #{balance}"
    echo "Attempting to DM #{character} with message: #{message}"
    @lnet.unique_buffer.push("chat to #{character} #{message}")
  end

  def send_bankbot_location(character)
    message = "Current Location: #{Room.current.id}"
    echo "Attempting to DM #{character} with message: #{message}"
    @lnet.unique_buffer.push("chat to #{character} #{message}")
  end

  def send_bankbot_help(character, messages)
    messages.each do |message|
      echo "Attempting to DM #{character} with message: #{message}"
      @lnet.unique_buffer.push("chat to #{character} #{message}")
    end
  end

  def in_game?(character)
    DRC.bput("find #{character}", 'There are no adventurers in the realms that match the names specified', "^  #{character}.$") == "  #{character}."
  end
end
