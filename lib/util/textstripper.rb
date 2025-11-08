Lich::Util.install_gem_requirements({ 'kramdown' => true })

module Lich
  module Util
    # Utility module for stripping markup, HTML, and XML from text
    #
    # This module provides methods to remove various types of formatting
    # from text strings, including HTML tags, XML tags, and Markdown markup.
    # It uses the Kramdown library for HTML and Markdown parsing, and REXML
    # for proper XML parsing.
    #
    # @example Basic usage
    #   TextStripper.strip("<p>Hello</p>", TextStripper::Mode::HTML)
    #   # => "Hello"
    #
    # @example Stripping XML
    #   TextStripper.strip("<root>data</root>", TextStripper::Mode::XML)
    #   # => "data"
    #
    # @example Stripping Markdown
    #   TextStripper.strip("**bold** text", TextStripper::Mode::MARKUP)
    #   # => "bold text"
    #
    # @example Using symbol shortcuts (backward compatible)
    #   TextStripper.strip("<p>Hello</p>", :html)
    #   # => "Hello"
    module TextStripper
      # Enumeration of stripping modes
      #
      # Provides a type-safe way to specify which type of content stripping
      # to perform. Each mode is represented as a symbol constant.
      #
      # @example Using mode constants
      #   TextStripper.strip(text, TextStripper::Mode::HTML)
      #
      # @example Checking valid modes
      #   TextStripper::Mode.valid?(:html)  # => true
      #   TextStripper::Mode.valid?(:pdf)   # => false
      module Mode
        # Strip HTML tags
        HTML = :html

        # Strip XML tags
        XML = :xml

        # Strip Markdown/markup formatting
        MARKUP = :markup

        # All valid modes
        #
        # @return [Array<Symbol>] List of all supported stripping modes
        ALL = [HTML, XML, MARKUP].freeze

        # Check if a mode is valid
        #
        # @param mode [Symbol, String] The mode to validate
        # @return [Boolean] true if the mode is valid, false otherwise
        #
        # @example
        #   Mode.valid?(:html)     # => true
        #   Mode.valid?('markup')  # => true
        #   Mode.valid?(:invalid)  # => false
        def self.valid?(mode)
          ALL.include?(mode.to_sym)
        end

        # Get a human-readable list of valid modes
        #
        # @return [String] Comma-separated list of valid modes
        #
        # @example
        #   Mode.list  # => "html, xml, markup"
        def self.list
          ALL.join(', ')
        end
      end

      # Map of modes to their corresponding Kramdown input formats
      #
      # @return [Hash<Symbol, String>] Mapping of modes to Kramdown input types
      # @note XML mode does not use Kramdown; it uses REXML instead
      # @api private
      MODE_TO_INPUT_FORMAT = {
        Mode::HTML   => 'html',
        Mode::MARKUP => 'GFM'
      }.freeze

      # Strip markup/code from text based on the specified mode
      #
      # This method provides a unified interface for removing different types
      # of markup from text. It handles HTML tags, XML tags, and Markdown
      # formatting based on the mode parameter.
      #
      # @param text [String] The text to process
      # @param mode [Symbol, Mode constant] The stripping mode to use. Valid options are:
      #   * `Mode::HTML` or `:html` - Strip HTML tags using Kramdown
      #   * `Mode::XML` or `:xml` - Strip XML tags using REXML
      #   * `Mode::MARKUP` or `:markup` - Strip Markdown formatting (GitHub Flavored Markdown) using Kramdown
      #
      # @return [String] The stripped text with formatting removed
      # @return [String] Empty string if input text is nil or empty
      # @return [String] Original text if parsing fails
      #
      # @raise [ArgumentError] if mode is not one of the valid modes
      #
      # @example Stripping HTML with constant
      #   TextStripper.strip("<p>Hello <strong>World</strong></p>", Mode::HTML)
      #   # => "Hello World"
      #
      # @example Stripping HTML with symbol (backward compatible)
      #   TextStripper.strip("<p>Hello <strong>World</strong></p>", :html)
      #   # => "Hello World"
      #
      # @example Stripping XML
      #   TextStripper.strip("<root><item>data</item></root>", Mode::XML)
      #   # => "data"
      #
      # @example Stripping XML with namespaces
      #   TextStripper.strip("<root xmlns='http://example.com'><item>data</item></root>", Mode::XML)
      #   # => "data"
      #
      # @example Stripping Markdown
      #   TextStripper.strip("**bold** and *italic*", Mode::MARKUP)
      #   # => "bold and italic"
      #
      # @example Invalid mode
      #   TextStripper.strip("text", :invalid)
      #   # raises ArgumentError: Invalid mode: invalid. Use one of: html, xml, markup
      #
      # @note If Kramdown or REXML parsing fails, a warning is issued and the original
      #   text is returned unchanged
      def self.strip(text, mode)
        return "" if text.nil? || text.empty?

        # Validate mode before attempting to parse
        validated_mode = validate_mode(mode)

        # Route to appropriate parsing method based on mode
        case validated_mode
        when Mode::XML
          strip_xml_with_rexml(text)
        else
          strip_with_kramdown(text, validated_mode)
        end
      rescue Kramdown::Error => e
        # Handle Kramdown parsing errors (HTML/MARKUP modes)
        log_error("Failed to parse #{validated_mode}", e)
        text
      rescue REXML::ParseException => e
        # Handle REXML parsing errors (XML mode)
        log_error("Failed to parse #{validated_mode}", e)
        text
      rescue StandardError => e
        # Catch any other unexpected errors during parsing
        log_error("Unexpected error during #{validated_mode} parsing", e)
        text
      end

      # Validate and normalize a mode value
      #
      # @param mode [Symbol, String] The mode to validate
      #
      # @return [Symbol] The validated and normalized mode
      #
      # @raise [ArgumentError] if mode is not valid
      #
      # @api private
      def self.validate_mode(mode)
        # Normalize mode to symbol for compatibility
        normalized_mode = mode.to_sym if mode.is_a?(String)
        normalized_mode ||= mode

        unless Mode.valid?(normalized_mode)
          raise ArgumentError,
                "Invalid mode: #{mode}. Use one of: #{Mode.list}"
        end

        normalized_mode
      end

      # Log an error message to both the response output and Lich log
      #
      # @param message [String] The base error message
      # @param exception [Exception] The exception that occurred
      #
      # @return [void]
      #
      # @api private
      def self.log_error(message, exception)
        full_message = "TextStripper: #{message} (#{exception.class}: #{exception.message}). Returning original."
        respond(full_message)
        Lich.log(full_message)
      end

      # Strip tags using Kramdown based on the input format
      #
      # This is a shared helper method that handles the actual parsing and
      # tag removal for HTML and MARKUP modes. It converts the parsed document
      # to plain text using Kramdown's standard conversion methods.
      #
      # @param text [String] The text to process
      # @param mode [Symbol] The stripping mode, which determines the input format
      #
      # @return [String] Plain text with tags/formatting removed and whitespace trimmed
      #
      # @note This method uses Kramdown's conversion chain to ensure proper
      #   text extraction. The process is:
      #   1. Parse input according to format (HTML/GFM)
      #   2. Convert internal representation to plain text
      #   3. Strip leading/trailing whitespace
      #
      # @note For HTML mode, Kramdown's HTML parser extracts text content
      #   while preserving text nodes and ignoring markup. For markup mode,
      #   the GFM parser processes Markdown syntax and then extracts plain text.
      #
      # @api private
      def self.strip_with_kramdown(text, mode)
        input_format = MODE_TO_INPUT_FORMAT[mode]
        doc = Kramdown::Document.new(text, input: input_format)

        # Extract plain text from the parsed document by traversing the element tree
        extract_text(doc.root).strip
      end

      # Strip XML tags using REXML and return plain text
      #
      # This method uses REXML to properly parse XML content and extract all
      # text nodes. Unlike the HTML parser, REXML correctly handles XML-specific
      # features like namespaces, CDATA sections, and processing instructions.
      #
      # @param text [String] The XML text to process
      #
      # @return [String] Plain text with XML tags removed and whitespace trimmed
      #
      # @note This method handles:
      #   * XML namespaces
      #   * CDATA sections (content is preserved as text)
      #   * Nested elements
      #   * Mixed content (text and elements)
      #
      # @api private
      def self.strip_xml_with_rexml(text)
        # Parse the XML document
        doc = REXML::Document.new(text)

        # Extract all text content from the document
        extract_xml_text(doc.root).strip
      end

      # Extract plain text from a REXML element tree
      #
      # Recursively traverses the REXML element tree and extracts all
      # text content, including CDATA sections.
      #
      # @param element [REXML::Element] The root element to extract text from
      #
      # @return [String] The extracted plain text
      #
      # @note This method processes all child nodes including:
      #   * Text nodes
      #   * CDATA sections
      #   * Nested elements (recursively)
      #
      # @api private
      def self.extract_xml_text(element)
        return '' if element.nil?

        text_parts = []

        # Iterate through all child nodes
        element.each do |node|
          case node
          when REXML::Text
            # Regular text node
            text_parts << node.value
          when REXML::CData
            # CDATA section - extract the content
            text_parts << node.value
          when REXML::Element
            # Nested element - recursively extract text
            text_parts << extract_xml_text(node)
          end
          # Ignore other node types (comments, processing instructions, etc.)
        end

        text_parts.join
      end

      # Extract plain text from a Kramdown element tree
      #
      # Recursively traverses the Kramdown element tree and extracts all
      # text content, ignoring markup and formatting.
      #
      # @param element [Kramdown::Element] The root element to extract text from
      #
      # @return [String] The extracted plain text
      #
      # @note This method handles different element types:
      #   * `:text` - Returns the text value directly
      #   * `:entity` - Converts HTML entities to characters
      #   * `:smart_quote` - Converts smart quotes to regular quotes
      #   * `:codeblock`, `:codespan` - Returns code content as plain text
      #   * `:br` - Converts line breaks to newlines
      #   * `:blank` - Converts blank lines to newlines
      #   * All other elements - Recursively processes children
      #
      # @api private
      def self.extract_text(element)
        return '' if element.nil?

        case element.type
        when :text
          element.value
        when :entity
          # Convert HTML entities (e.g., &nbsp; -> space)
          entity_to_char(element.value)
        when :smart_quote
          # Convert smart quotes to regular quotes
          smart_quote_to_char(element.value)
        when :codeblock, :codespan
          # Return code content as plain text
          element.value
        when :br
          # Convert line breaks to newlines
          "\n"
        when :blank
          # Blank lines become newlines
          "\n"
        else
          # For all other elements (p, div, span, etc.), recursively process children
          if element.children
            element.children.map { |child| extract_text(child) }.join
          else
            ''
          end
        end
      end

      # Convert HTML entity codes to characters
      #
      # @param entity [Kramdown::Utils::Entities::Entity, Symbol] The entity to convert
      # @return [String] The character representation
      #
      # @api private
      def self.entity_to_char(entity)
        if entity.respond_to?(:char)
          entity.char
        else
          # Fallback for symbol entities
          case entity
          when :nbsp then ' '
          when :lt then '<'
          when :gt then '>'
          when :amp then '&'
          when :quot then '"'
          else entity.to_s
          end
        end
      end

      # Convert smart quote symbols to regular characters
      #
      # @param quote_type [Symbol] The smart quote type (:lsquo, :rsquo, :ldquo, :rdquo)
      # @return [String] The quote character
      #
      # @api private
      def self.smart_quote_to_char(quote_type)
        case quote_type
        when :lsquo, :rsquo then "'"
        when :ldquo, :rdquo then '"'
        else quote_type.to_s
        end
      end

      # Strip HTML tags and return plain text
      #
      # Parses the input as HTML and removes all HTML tags, returning
      # only the text content. This is a convenience wrapper around
      # {#strip_with_kramdown}.
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
      # @note This method is called internally by {#strip} when mode is Mode::HTML
      # @note Uses Kramdown for HTML parsing
      # @see #strip
      # @api private
      def self.strip_html(text)
        strip_with_kramdown(text, Mode::HTML)
      end

      # Strip XML tags and return plain text
      #
      # Removes XML tags from the input text using REXML for proper XML parsing.
      # This method correctly handles XML-specific features like namespaces,
      # CDATA sections, and processing instructions. This is a convenience
      # wrapper around {#strip_xml_with_rexml}.
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
      # @example XML with CDATA
      #   TextStripper.strip_xml("<root><![CDATA[Special <characters>]]></root>")
      #   # => "Special <characters>"
      #
      # @example XML with namespaces
      #   TextStripper.strip_xml("<root xmlns='http://example.com'><item>data</item></root>")
      #   # => "data"
      #
      # @note This method uses REXML for proper XML parsing, which correctly
      #   handles XML-specific features (CDATA, namespaces, etc.)
      # @note This method is called internally by {#strip} when mode is Mode::XML
      # @see #strip
      # @api private
      def self.strip_xml(text)
        strip_xml_with_rexml(text)
      end

      # Strip Markdown formatting and return plain text
      #
      # Parses Markdown (GitHub Flavored Markdown) and removes all formatting,
      # returning only the plain text content. This is a convenience wrapper
      # around {#strip_with_kramdown}.
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
      # @note Uses Kramdown for Markdown parsing
      # @note This method is called internally by {#strip} when mode is Mode::MARKUP
      # @see #strip
      # @api private
      def self.strip_markup(text)
        strip_with_kramdown(text, Mode::MARKUP)
      end
    end
  end
end
