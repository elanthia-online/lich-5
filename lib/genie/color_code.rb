# frozen_string_literal: true

module Lich
  module Genie
    # The parts of Remix Utility/ColorCode.cs (R) the engine needs to decide what is a colour:
    # ParseCommand's default arm keeps a `#RRGGBB` row as its own result (Command.cs:2517-2526
    # R) and #echo drops a colour argument before ParseAllArgs (Command.cs:289-313 R). The
    # colour value itself is a front-end matter (the echo hook carries no colour).
    module ColorCode
      module_function

      # ColorCode.ValidHexChars (ColorCode.cs:112 R).
      VALID_HEX_CHARS = '1234567890aAbBcCdDeEfF'

      # ColorCode.IsColorString's ColorList (ColorCode.cs:132-153 R): the System.Drawing.KnownColor
      # names strictly between Transparent and ButtonFace -- the 140 web colours (.NET's later
      # RebeccaPurple sits after the system colours, so it is not one), listed lower-cased. Verified one
      # by one through genieflow `#echo <name> x` (all 140 drop, RebeccaPurple,
      # Transparent, ButtonFace, ControlText, grey stay in the text).
      # In KnownColor order (ListColors, Command.cs:2978-2993 R, prints them in this order).
      KNOWN_COLORS = %w[
        AliceBlue AntiqueWhite Aqua Aquamarine Azure Beige Bisque Black BlanchedAlmond Blue BlueViolet Brown
        BurlyWood CadetBlue Chartreuse Chocolate Coral CornflowerBlue Cornsilk Crimson Cyan DarkBlue DarkCyan
        DarkGoldenrod DarkGray DarkGreen DarkKhaki DarkMagenta DarkOliveGreen DarkOrange DarkOrchid DarkRed
        DarkSalmon DarkSeaGreen DarkSlateBlue DarkSlateGray DarkTurquoise DarkViolet DeepPink DeepSkyBlue
        DimGray DodgerBlue Firebrick FloralWhite ForestGreen Fuchsia Gainsboro GhostWhite Gold Goldenrod Gray
        Green GreenYellow Honeydew HotPink IndianRed Indigo Ivory Khaki Lavender LavenderBlush LawnGreen
        LemonChiffon LightBlue LightCoral LightCyan LightGoldenrodYellow LightGray LightGreen LightPink
        LightSalmon LightSeaGreen LightSkyBlue LightSlateGray LightSteelBlue LightYellow Lime LimeGreen Linen
        Magenta Maroon MediumAquamarine MediumBlue MediumOrchid MediumPurple MediumSeaGreen MediumSlateBlue
        MediumSpringGreen MediumTurquoise MediumVioletRed MidnightBlue MintCream MistyRose Moccasin
        NavajoWhite Navy OldLace Olive OliveDrab Orange OrangeRed Orchid PaleGoldenrod PaleGreen
        PaleTurquoise PaleVioletRed PapayaWhip PeachPuff Peru Pink Plum PowderBlue Purple Red RosyBrown
        RoyalBlue SaddleBrown Salmon SandyBrown SeaGreen SeaShell Sienna Silver SkyBlue SlateBlue SlateGray
        Snow SpringGreen SteelBlue Tan Teal Thistle Tomato Turquoise Violet Wheat White WhiteSmoke Yellow
        YellowGreen
      ].freeze
      COLOR_NAMES = KNOWN_COLORS.to_h { |name| [name.downcase, true] }.freeze

      # ColorCode.IsHexString (ColorCode.cs:114-130 R): starts with `#`, Trim()med length 7,
      # and every char after the `#` of the UNTRIMMED text a hex digit.
      # @param text [String]
      # @return [Boolean]
      def hex_string?(text)
        text = text.to_s
        return false unless text.start_with?('#') && Text.net_trim(text).length == 7

        text[1..].each_char.all? { |c| VALID_HEX_CHARS.include?(c) }
      end

      # ColorCode.IsColorString (ColorCode.cs:134-153 R): a {COLOR_NAMES} entry, compared on
      # ToLower().
      # @param text [String]
      # @return [Boolean]
      def color_string?(text)
        COLOR_NAMES.key?(Text.net_downcase(text.to_s))
      end

      # ColorCode.StringToColor is not Color.Empty (ColorCode.cs:27-50 R): a text starting with
      # `@` is the default colour (Empty); a `#RRGGBB` always converts (ColorTranslator.FromHtml
      # of a validated hex text); a {COLOR_NAMES} name converts (ColorConverter); anything else
      # is Empty.
      # @param text [String]
      # @return [Boolean]
      def color?(text)
        text = text.to_s
        return false if text.start_with?('@')

        hex_string?(text) || color_string?(text)
      end

      # #echo's test of its colour argument (Command.cs:295-313 R): `fg,bg` (a comma, not at
      # the end) tests the Trim()med fg part (the bg never decides), anything else the whole
      # argument; a colour (hex or name) is dropped from the text.
      # @param arg [String]
      # @return [Boolean] whether #echo drops the argument as its colour
      def echo_color?(arg)
        arg = arg.to_s
        return color?(arg) unless arg.include?(',') && !arg.end_with?(',')

        color?(Text.net_trim(arg[0...arg.index(',')]))
      end
    end
  end
end
