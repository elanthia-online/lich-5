=begin
messaging.rb: Core lich file for collection of various messaging Lich capabilities.
Entries added here should always be accessible from Lich::Messaging.feature namespace.
=end

module Lich
  module Messaging
    def self.xml_encode(msg)
      if $frontend =~ /^(wizard|avalon)$/i
        sf_to_wiz(msg.encode(:xml => :text), bypass_multiline: true)
      else
        msg.encode(:xml => :text)
      end
    end

    def self.monsterbold(msg, encode: true)
      # return monsterbold_start + self.xml_encode(msg) + monsterbold_end
      return msg_format("monster", msg, encode: encode)
    end

    def self.stream_window(msg, window = "familiar", encode: true)
      msg = xml_encode(msg) if encode
      if XMLData.game =~ /^GS/
        allowed_streams = ["familiar", "speech", "thoughts", "loot", "voln"]
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
        elsif window =~ /voln/i
          stream_window_before_txt = %{The Symbol of Thought begins to burn in your mind and you hear LICH-MESSAGE thinking, "}
          stream_window_after_txt = %{"\r\n}
        end
      end

      _respond stream_window_before_txt + msg + stream_window_after_txt
    end

    def self.msg_format(type = "info", msg = "", cmd_link: nil, encode: true)
      msg = xml_encode(msg) if encode
      preset_color_before = ""
      preset_color_after = ""

      wizard_color = { "white" => 128, "black" => 129, "dark blue" => 130, "dark green" => 131, "dark teal" => 132,
        "dark red" => 133, "purple" => 134, "gold" => 135, "light grey" => 136, "blue" => 137,
        "bright green" => 138, "teal" => 139, "red" => 140, "pink" => 141, "yellow" => 142 }

      if $frontend =~ /^(?:stormfront|frostbite|profanity|wrayth)$/
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
        when "cmd"
          preset_color_before = "<d cmd='#{xml_encode(cmd_link)}'>"
          preset_color_after = "</d>"
        end
      elsif $frontend =~ /^(?:wizard|avalon)$/
        case type
        when "error", "yellow", "bold", "monster", "creature"
          preset_color_before = monsterbold_start
          preset_color_after = (monsterbold_end + " ")
        when "warn", "orange", "gold", "thought"
          preset_color_before = wizard_color["gold"].chr.force_encoding(Encoding::ASCII_8BIT)
          preset_color_after = "\240".force_encoding(Encoding::ASCII_8BIT)
        when "info", "teal", "whisper"
          preset_color_before = wizard_color["teal"].chr.force_encoding(Encoding::ASCII_8BIT)
          preset_color_after = "\240".force_encoding(Encoding::ASCII_8BIT)
        when "green", "speech", "debug", "light green"
          preset_color_before = wizard_color["bright green"].chr.force_encoding(Encoding::ASCII_8BIT)
          preset_color_after = "\240".force_encoding(Encoding::ASCII_8BIT)
        when "link", "command", "selectedLink", "watching", "roomName"
          preset_color_before = ""
          preset_color_after = ""
        when "cmd" # these browsers can't handle links
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
        when "cmd" # these browsers can't handle links
          preset_color_before = ""
          preset_color_after = ""
        end
      end

      return (preset_color_before + msg + preset_color_after)
    end

    def self.msg(type = "info", msg = "", encode: true)
      return if type == "debug" && (Lich.debug_messaging.nil? || Lich.debug_messaging == "false" || Lich.debug_messaging == false)
      _respond msg_format(type, msg, encode: encode)
    end

    def self.make_cmd_link(link_text, link_action, encode: true)
      return msg_format("cmd", link_text, cmd_link: link_action, encode: encode)
    end

    # defaulting encoding here to false instead of true like other methods due to backwards compatibility that it never encoded before
    # whereas all the other methods were already encoding and therefor should default to allow for them.
    def self.mono(msg, encode: false)
      return raise StandardError.new 'Lich::Messaging.mono only works with String parameters!' unless msg.is_a?(String)
      msg = xml_encode(msg) if encode
      if $frontend =~ /^(?:stormfront|wrayth|genie)$/i
        _respond "<output class=\"mono\"/>\n" + msg + "\n<output class=\"\"/>"
      else
        _respond msg.split("\n")
      end
    end
  end
end
