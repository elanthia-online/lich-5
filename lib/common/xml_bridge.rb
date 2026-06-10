# frozen_string_literal: true

require 'ox'

module Lich
  module Common
    # Adapts Ox::Sax callbacks to the REXML::StreamListener interface that XMLData
    # implements (tag_start(name, attributes) / text / tag_end), so Lich can use
    # Ox's fast, permissive parser without rewriting the large XMLData listener.
    #
    # Ox fires start_element, then attr for each attribute, then attrs_done, then
    # text and children, then end_element. Attributes are accumulated and flushed
    # to tag_start in attrs_done so it matches REXML's single tag_start(name, hash)
    # call. Names are passed as Strings (symbolize: false) and entities are decoded
    # (convert_special: true) to match REXML's behavior; see process_xml_data.
    class OxStreamBridge < ::Ox::Sax
      def initialize(listener)
        super()
        @listener = listener
        @name = nil
        @attributes = {}
      end

      def start_element(name)
        @name = name.to_s
        @attributes = {}
      end

      def attr(name, value)
        @attributes[name.to_s] = value.force_encoding(Encoding::WINDOWS_1252)
      end

      def attrs_done
        @listener.tag_start(@name, @attributes)
      end

      def text(value)
        @listener.text(value.force_encoding(Encoding::WINDOWS_1252))
      end

      # REXML routes CDATA content through the same text handling.
      def cdata(value)
        @listener.text(value.force_encoding(Encoding::WINDOWS_1252))
      end

      def end_element(name)
        @listener.tag_end(name.to_s)
      end
    end
  end
end
