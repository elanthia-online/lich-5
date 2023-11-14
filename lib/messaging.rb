=begin
messaging.rb: Core lich file for collection of various messaging Lich capabilities.
Entries added here should always be accessible from Lich::Messaging.feature namespace.

    Maintainer: Elanthia-Online
    Original Author: LostRanger, Ondreian, various others
    game: Gemstone
    tags: CORE, util, utilities
    required: Lich > 5.4.0
    version: 1.2.0

  changelog:
    v1.2.0 (2023-08-02)
      Add Lich::Messaging.mono(msg) to send msg as mono spaced text
      Robocop code cleanup
    v1.1.0 (2022-10-28)
      Add loot window as an option
    v1.0.2 (2022-11-19)
      Bugfix for Wizard monsterbold new line
    v1.0.1 (2022-05-05)
      Bugfix for Wizard character encoding
    v1.0.0 (2022-03-15)
      Initial release
      Supports Lich::Messaging.stream_window(msg, window) SENDS msg to stream window
      Supports Lich::Messaging.msg(type, text) SENDS msg in colors, supports debug output
      Supports Lich::Messaging.msg_format(type, text) RETURNS msg in colors
      Supports Lich::Messaging.monsterbold(msg)  RETURNS msg in monsterbold
      Supports Lich::Messaging.xml_encode(msg)  RETURNS xml encoded text

=end

module Lich
  module Messaging
    def self.xml_encode(msg)
      msg.encode(:xml => :text)
    end

    def self.monsterbold(msg)
      return monsterbold_start + self.xml_encode(msg) + monsterbold_end
    end

    def self.stream_window(msg, window = "familiar")
      if XMLData.game =~ /^GS/
        allowed_streams = ["familiar", "speech", "thoughts", "loot"]
      elsif XMLData.game =~ /^DR/
        allowed_streams = ["familiar", "speech", "thoughts", "combat"]
      end

      stream_window_before_txt = ""
      stream_window_after_txt = ""
      if $frontend =~ /stormfront|profanity/i && allowed_streams.include?(window)
        stream_window_before_txt = "<pushStream id=\"#{window}\" ifClosedStyle=\"watching\"/>"
        stream_window_after_txt = "\r\n<popStream/>\r\n"
      else
        if window =~ /familiar/i
          stream_window_before_txt = "\034GSe\r\n"
          stream_window_after_txt = "\r\n\034GSf\r\n"
        elsif window =~ /thoughts/i
          stream_window_before_txt = "You hear the faint thoughts of LICH-MESSAGE echo in your mind:\r\n"
          stream_window_after_txt = ""
        end
      end

      _respond stream_window_before_txt + self.xml_encode(msg) + stream_window_after_txt
    end

    def self.msg_format(type = "info", msg = "")
      preset_color_before = ""
      preset_color_after = ""

      wizard_color = { "white" => 128, "black" => 129, "dark blue" => 130, "dark green" => 131, "dark teal" => 132,
        "dark red" => 133, "purple" => 134, "gold" => 135, "light grey" => 136, "blue" => 137,
        "bright green" => 138, "teal" => 139, "red" => 140, "pink" => 141, "yellow" => 142 }

      if $frontend =~ /^(?:stormfront|frostbite|profanity)$/
        case type
        when "error", "yellow", "bold", "monster", "creature"
          preset_color_before = monsterbold_start
          preset_color_after = monsterbold_end
        when "warn", "orange", "gold", "thought"
          preset_color_before = "<preset id='thought'>"
          preset_color_after = "</preset>"
        when "info", "teal", "whisper"
          preset_color_before = "<preset id='whisper'>"
          preset_color_after = "</preset>"
        when "green", "speech", "debug", "light green"
          preset_color_before = "<preset id='speech'>"
          preset_color_after = "</preset>"
        when "link", "command", "selectedLink", "watching", "roomName"
          preset_color_before = ""
          preset_color_after = ""
        end
      elsif $frontend =~ /^(?:wizard)$/
        case type
        when "error", "yellow", "bold", "monster", "creature"
          preset_color_before = monsterbold_start
          preset_color_after = (monsterbold_end + " ")
        when "warn", "orange", "gold", "thought"
          preset_color_before = wizard_color["gold"].chr.force_encoding(Encoding::ASCII_8BIT)
          preset_color_after = "\217".force_encoding(Encoding::ASCII_8BIT)
        when "info", "teal", "whisper"
          preset_color_before = wizard_color["teal"].chr.force_encoding(Encoding::ASCII_8BIT)
          preset_color_after = "\217".force_encoding(Encoding::ASCII_8BIT)
        when "green", "speech", "debug", "light green"
          preset_color_before = wizard_color["bright green"].chr.force_encoding(Encoding::ASCII_8BIT)
          preset_color_after = "\217".force_encoding(Encoding::ASCII_8BIT)
        when "link", "command", "selectedLink", "watching", "roomName"
          preset_color_before = ""
          preset_color_after = ""
        end
      else
        case type
        when "error", "yellow", "bold", "monster", "creature"
          preset_color_before = monsterbold_start
          preset_color_after = monsterbold_end
        when "warn", "orange", "gold", "thought"
          preset_color_before = "!! "
          preset_color_after = ""
        when "info", "teal", "whisper"
          preset_color_before = "-- "
          preset_color_after = ""
        when "green", "speech", "debug", "light green"
          preset_color_before = ">> "
          preset_color_after = ""
        when "link", "command", "selectedLink", "watching", "roomName"
          preset_color_before = ""
          preset_color_after = ""
        end
      end

      return (preset_color_before + xml_encode(msg) + preset_color_after)
    end

    def self.msg(type = "info", msg = "")
      return if type == "debug" && (Lich.debug_messaging.nil? || Lich.debug_messaging == "false")
      _respond msg_format(type, msg)
    end

    def self.mono(msg)
      return raise StandardError.new 'Lich::Messaging.mono only works with String paremeters!' unless msg.is_a?(String)
      if $frontend =~ /^(?:stormfront|wrayth|genie)$/i
        _respond "<output class=\"mono\"/>\n" + msg + "\n<output class=\"\"/>"
      else
        _respond msg.split("\n")
      end
    end
  end
end
