=begin
messaging.rb: Core lich file for collection of various messaging Lich capabilities.
Entries added here should always be accessible from Lich::Messaging.feature namespace.

    Maintainer: Elanthia-Online
    Original Author: LostRanger, Ondreian, various others
    game: Gemstone
    tags: CORE, util, utilities
    required: Lich > 5.4.0
    version: 1.0.0

  changelog:
    v1.0.0 (2022-03-15)
      Initial release
      Supports Lich::Messaging.stream_window(msg, window) SENDS msg to stream window
      Supports Lich::Messaging.monsterbold(msg)  RETURNS msg in monsterbold

=end

module Lich
  module Messaging
    
    def self.stream_window(msg, window = "familiar")
      
      if XMLData.game =~ /^GS/
        allowed_streams = ["familiar", "speech", "thoughts"]
      elsif XMLData.game =~ /^DR/
        allowed_streams = ["familiar", "speech", "thoughts", "combat"]
      end
      
      stream_window_before_txt = ""
      stream_window_after_txt = ""
      if $frontend =~ /stormfront|profanity/i && allowed_streams.include?(window)
        stream_window_before_txt = "<pushStream id=\"#{window}\" ifClosedStyle=\"watching\"/>"
        stream_window_after_txt = "<popStream/>\r\n"
      else
        if window =~ /familiar/i
          stream_window_before_txt = "\034GSe\r\n"
          stream_window_after_txt = "\034GSf\r\n"
        end
      end
      
      _respond stream_window_before_txt + msg + stream_window_after_txt
    end
    
    def self.monsterbold(msg)
      if $frontend =~ /^(?:stormfront|frostbite)$/
        "<pushBold/>" + msg + "<popBold/>"
      elsif $frontend =~ /^(?:wizard|avalon)$/
        "\034GSL\r\n" + msg + "\034GSM\r\n"
      elsif $frontend == "profanity"
        "<b>" + msg + "</b>" 
      else
        msg
      end
    end
    
  end
end
