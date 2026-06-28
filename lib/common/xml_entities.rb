# frozen_string_literal: true

module Lich
  module Common
    # Decodes the five standard XML entities. The SAX parsers run Ox with
    # convert_special: false (so Ox never turns a numeric entity into UTF-8 that
    # would then be mis-encoded), which means Ox leaves the standard entities
    # literal -- this restores them. Shared by Lich::Common::XMLParser and
    # Lich::DragonRealms::DRParser.
    module XmlEntities
      # &amp; is decoded last so an already-encoded entity such as &amp;gt;
      # round-trips to the literal &gt; rather than being double-decoded to >.
      def self.decode(str)
        return str unless str.include?('&')

        str.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"').gsub('&apos;', "'").gsub('&amp;', '&')
      end
    end
  end
end
