Lich::Util.install_gem_requirements({'kramdown' => true})

module Lich
  module Util
    # Utility module for stripping markup, HTML, and XML from text
    #
    # This module provides methods to remove various types of formatting
    # from text strings, including HTML tags, XML tags, and Markdown markup.
    # It uses the Kramdown library for parsing and processing.
    #
    # @example Basic usage
    #   TextStripper.strip("<p>Hello</p>", :html)
    #   # => "Hello"
    #
    # @example Stripping XML
    #   TextStripper.strip("<root>data</root>", :xml)
    #   # => "data"
    #
    # @example Stripping Markdown
    #   TextStripper.strip("**bold** text", :markup)
    #   # => "bold text"
    module TextStripper
      # Strip markup/code from text based on the specified mode
      #
      # This method provides a unified interface for removing different types
      # of markup from text. It handles HTML tags, XML tags, and Markdown
      # formatting based on the mode parameter.
      #
      # @param text [String] The text to process
      # @param mode [Symbol] The stripping mode to use. Valid options are:
      #   * `:html` - Strip HTML tags
      #   * `:xml` - Strip XML tags
      #   * `:markup` - Strip Markdown formatting
      #
      # @return [String] The stripped text with formatting removed
      # @return [String] Empty string if input text is nil or empty
      # @return [String] Original text if parsing fails
      #
      # @raise [ArgumentError] if mode is not one of :html, :xml, or :markup
      #
      # @example Stripping HTML
      #   TextStripper.strip("<p>Hello <strong>World</strong></p>", :html)
      #   # => "Hello World"
      #
      # @example Stripping XML
      #   TextStripper.strip("<root><item>data</item></root>", :xml)
      #   # => "data"
      #
      # @example Stripping Markdown
      #   TextStripper.strip("**bold** and *italic*", :markup)
      #   # => "bold and italic"
      #
      # @example Invalid mode
      #   TextStripper.strip("text", :invalid)
      #   # raises ArgumentError
      #
      # @note If Kramdown parsing fails, a warning is issued and the original
      #   text is returned unchanged
      def self.strip(text, mode)
        return "" if text.nil? || text.empty?
        case mode
        when :html
          strip_html(text)
        when :xml
          strip_xml(text)
        when :markup
          strip_markup(text)
        else
          raise ArgumentError, "Invalid mode: #{mode}. Use :html, :xml, or :markup"
        end
      rescue Kramdown::Error => e
        # If parsing fails, return the original text
        warn "TextStripper: Failed to parse #{mode} (#{e.message}). Returning original."
        text
      end

      # Strip HTML tags and return plain text
      #
      # Parses the input as HTML and removes all HTML tags, returning
      # only the text content.
      #
      # @param text [String] The HTML text to process
      #
      # @return [String] Plain text with HTML tags removed and whitespace trimmed
      #
      # @example Basic HTML stripping
      #   TextStripper.strip_html("<p>Hello</p>")
      #   # => "Hello"
      #
      # @example Nested tags
      #   TextStripper.strip_html("<div><p>Hello <strong>World</strong></p></div>")
      #   # => "Hello World"
      #
      # @note This method is called internally by {#strip} when mode is :html
      # @api private
      def self.strip_html(text)
        doc = Kramdown::Document.new(text, input: 'html')
        doc.to_remove_html_tags.strip
      end

      # Strip XML tags and return plain text
      #
      # Removes XML tags from the input text. Since Kramdown doesn't have
      # native XML parsing, this method treats the input as HTML for parsing
      # purposes, which works for basic XML stripping.
      #
      # @param text [String] The XML text to process
      #
      # @return [String] Plain text with XML tags removed and whitespace trimmed
      #
      # @example Basic XML stripping
      #   TextStripper.strip_xml("<root>content</root>")
      #   # => "content"
      #
      # @example Nested XML elements
      #   TextStripper.strip_xml("<root><item>data</item></root>")
      #   # => "data"
      #
      # @note This method treats XML as HTML for parsing purposes, which may
      #   not handle all XML-specific features correctly
      # @note This method is called internally by {#strip} when mode is :xml
      # @api private
      def self.strip_xml(text)
        # Kramdown doesn't have native XML parsing, so we wrap it as HTML
        # or use a simple regex approach for basic XML stripping
        doc = Kramdown::Document.new(text, input: 'html')
        doc.to_remove_html_tags.strip
      end

      # Strip Markdown formatting and return plain text
      #
      # Parses Markdown (GitHub Flavored Markdown) and removes all formatting,
      # returning only the plain text content.
      #
      # @param text [String] The Markdown text to process
      #
      # @return [String] Plain text with Markdown formatting removed and whitespace trimmed
      #
      # @example Bold and italic
      #   TextStripper.strip_markup("**bold** and *italic*")
      #   # => "bold and italic"
      #
      # @example Links
      #   TextStripper.strip_markup("[link text](http://example.com)")
      #   # => "link text"
      #
      # @example Headers
      #   TextStripper.strip_markup("# Heading")
      #   # => "Heading"
      #
      # @note Uses GitHub Flavored Markdown (GFM) as the input format
      # @note This method is called internally by {#strip} when mode is :markup
      # @api private
      def self.strip_markup(text)
        doc = Kramdown::Document.new(text, input: 'GFM')
        doc.to_remove_html_tags.strip
      end
    end
  end
end
