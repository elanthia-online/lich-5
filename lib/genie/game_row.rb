# frozen_string_literal: true

module Lich
  module Genie
    # The two pieces of Remix's game-row parser that decide what a reserved variable
    # sees, so {GameState} can be fed the raw server strings Lich receives and compute
    # the same values Remix does:
    #
    #   * {Scanner}: the character loop of Game.ParseGameRow (Game.cs:567-860 R). It cuts
    #     a row into complete XML buffers (handed to ProcessXML) and display text, with
    #     Remix's entity quirks: an entity of up to 6 characters is passed into the XML
    #     raw, a longer one is aborted (its '&' escaped) and its ';' dropped, and every
    #     ';' outside an entity is dropped.
    #   * {Fragment}: what `new XmlDocument().LoadXml("<data>" + buffer + "</data>")`
    #     builds from one buffer (Game.cs:950-965 R), reduced to what Game.cs reads:
    #     element names, attributes, InnerText and InnerXml. A buffer XmlDocument would
    #     reject (an undefined entity such as &nbsp;, a mismatched tag, a duplicate
    #     attribute) yields nil, as Remix's `catch (XmlException) { return ""; }` drops it.
    module GameRow
      # One element of a parsed buffer.
      class Node
        attr_reader :name, :attributes, :children, :parent

        # @param name [String]
        # @param attributes [Hash{String=>String}] in document order
        # @param parent [Node, nil]
        def initialize(name, attributes = {}, parent = nil)
          @name = name
          @attributes = attributes
          @children = [] # Node or String (text)
          @parent = parent
          @empty_tag = false
        end

        # Whether it was written `<x/>` (XmlElement.IsEmpty: serialized as `<x />`).
        attr_accessor :empty_tag

        # GetAttributeData (Game.cs:2725-2737 R): the value, or "" when absent.
        # @param name [String]
        # @return [String]
        def attr(name)
          @attributes.fetch(name, '')
        end

        # @return [Array<Node>]
        def elements
          @children.grep(Node)
        end

        # XmlNode.InnerText: every descendant text node, concatenated.
        # @return [String]
        def inner_text
          @children.map { |child| child.is_a?(Node) ? child.inner_text : child }.join
        end

        # XmlNode.InnerXml: the children re-serialized the way XmlDocument writes them
        # (`<pushBold />` for an empty element, attributes in double quotes, text with
        # & < > escaped). CountMonsters matches its regex against this (Game.cs:2681 R).
        # @return [String]
        def inner_xml
          @children.map { |child| child.is_a?(Node) ? child.outer_xml : Fragment.escape_text(child) }.join
        end

        # @return [String]
        def outer_xml
          attrs = @attributes.map { |key, value| %( #{key}="#{Fragment.escape_attribute(value)}") }.join
          return "<#{@name}#{attrs} />" if @empty_tag

          "<#{@name}#{attrs}>#{inner_xml}</#{@name}>"
        end
      end

      # Minimal XmlDocument.LoadXml for the fragments DragonRealms sends.
      module Fragment
        PREDEFINED = { 'lt' => '<', 'gt' => '>', 'amp' => '&', 'quot' => '"', 'apos' => "'" }.freeze
        NAME = /[A-Za-z_:][-A-Za-z0-9._:]*/.freeze
        ENTITY = /&(?:#(\d+)|#x(\h+)|([A-Za-z][A-Za-z0-9]*));/.freeze
        # XML whitespace (XmlDocument with PreserveWhitespace=false drops a text node made
        # only of these).
        XML_SPACE = /\A[ \t\r\n]*\z/.freeze

        # Thrown internally for anything XmlDocument would reject.
        class Malformed < StandardError; end

        module_function

        # @param buffer [String] one ProcessXML buffer
        # @return [Node, nil] the `<data>` wrapper, or nil if XmlDocument would throw
        def parse(buffer)
          root = Node.new('data')
          stack = [root]
          scanner = buffer.to_s
          pos = 0
          while pos < scanner.length
            lt = scanner.index('<', pos)
            if lt.nil?
              add_text(stack.last, scanner[pos..])
              break
            end
            add_text(stack.last, scanner[pos...lt]) if lt > pos
            pos = parse_tag(scanner, lt, stack)
          end
          raise Malformed, 'unclosed element' unless stack.length == 1

          root
        rescue Malformed, ArgumentError, RangeError, EncodingError
          nil
        end

        # @return [Integer] the position after the tag
        def parse_tag(text, lt, stack)
          gt = text.index('>', lt)
          raise Malformed, 'unterminated tag' if gt.nil?

          body = text[(lt + 1)...gt]
          if body.start_with?('/')
            name = body[1..].rstrip
            raise Malformed, 'mismatched end tag' unless stack.length > 1 && stack.last.name == name

            stack.pop
          else
            node = start_tag(body, stack.last)
            stack.last.children << node
            stack << node unless node.empty_tag
          end
          gt + 1
        end

        # @return [Node]
        def start_tag(body, parent)
          empty = body.end_with?('/')
          body = body[0...-1] if empty
          name = body[/\A#{NAME}/o]
          raise Malformed, 'bad element name' if name.nil?

          node = Node.new(name, parse_attributes(body[name.length..]), parent)
          node.empty_tag = empty
          node
        end

        # @return [Hash{String=>String}]
        def parse_attributes(text)
          attributes = {}
          rest = text
          until rest.strip.empty?
            match = rest.match(/\A[ \t\r\n]+(#{NAME})[ \t\r\n]*=[ \t\r\n]*(?:'([^'<]*)'|"([^"<]*)")/o)
            raise Malformed, 'bad attribute' if match.nil?
            raise Malformed, 'duplicate attribute' if attributes.key?(match[1])

            # LoadXml keeps tabs and line breaks in values as sent (probed on .NET 8).
            attributes[match[1]] = decode(match[2] || match[3])
            rest = match.post_match
          end
          attributes
        end

        def add_text(node, raw)
          text = decode(raw) # LoadXml keeps CR/LF as sent (probed on .NET 8)
          return if text.empty? || text.match?(XML_SPACE)

          node.children << text
        end

        # Expands the predefined and numeric entities; anything else is an XmlException.
        # @return [String]
        def decode(raw)
          return raw unless raw.include?('&')

          # A '&' that does not start a complete entity reference is an XmlException.
          raise Malformed, 'bare &' if raw.gsub(ENTITY, '').include?('&')

          raw.gsub(ENTITY) do
            dec, hex, named = Regexp.last_match.captures
            if named
              PREDEFINED.fetch(named) { raise Malformed, "undefined entity #{named}" }
            else
              code = dec ? dec.to_i : hex.to_i(16)
              # A reference to a character XML forbids is an XmlException too.
              raise Malformed, "invalid character reference #{code}" unless xml_char?(code)

              [code].pack('U')
            end
          end
        end

        # The XML 1.0 Char production.
        def xml_char?(code)
          [0x9, 0xA, 0xD].include?(code) || code.between?(0x20, 0xD7FF) || code.between?(0xE000, 0xFFFD) ||
            code.between?(0x10000, 0x10FFFF)
        end

        # @return [String]
        def escape_text(text)
          text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
        end

        # @return [String]
        def escape_attribute(text)
          text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('"', '&quot;')
        end
      end

      # Game.ParseGameRow's character loop (Game.cs:567-860 R), yielding what it hands on:
      #   [:xml, buffer]  -- a complete buffer at nesting depth 0 (ProcessXML)
      #   [:xml_end, buffer] -- the closed remainder ProcessXML'd at the row's end (Game.cs:
      #                      833-850 R): no stream flush / roomDesc / bold check follows it
      #   [:text, string] -- display text, entities translated (Utility.TranslateHTMLChar)
      # in row order. The XML carry (m_oXMLBuffer) persists across rows like Remix's
      # field; the depth counter, entity buffer and end-tag flag are per row.
      class Scanner
        # Utility.TranslateHTMLChar (Utility.cs:257-292 R): any other entity is blanked.
        HTML_CHARS = { '&quot;' => '"', '&amp;' => '&', '&lt;' => '<', '&gt;' => '>', '&nbsp;' => ' ' }.freeze
        GSL = 28.chr
        SPECIAL = /[<>&;\/\x1c]/.freeze

        def initialize
          @carry = +''
        end

        # @param row [String] one server string (with its CRLF)
        # @yieldparam kind [Symbol] :xml, :xml_end or :text
        # @yieldparam payload [String]
        # @return [Boolean] whether the row contained any '<' (hasXML)
        def scan(row)
          # Fast path: a row with no markup, entity, ';' or GSL char is all text.
          if !row.to_s.match?(SPECIAL) && @carry.empty?
            yield :text, row.to_s unless row.to_s.empty?
            return false
          end

          text = fix_dr_html(row.to_s)
          state = { xml: +'', depth: 0, end_tag: false, entity: nil, prev: nil, text: +'', has_xml: false }
          text.each_char do |c|
            step(c, state) { |kind, payload| yield kind, payload }
            state[:prev] = c
          end
          finish_row(state) { |kind, payload| yield kind, payload }
          state[:has_xml]
        end

        private

        # "Fix for DR html encoding problems" (Game.cs:582-591 R): a row starting with
        # "< " / "> " has every "< " / "> " turned into an entity.
        def fix_dr_html(row)
          row = row.gsub('< ', '&lt; ') if row.start_with?('< ')
          row = row.gsub('> ', '&gt; ') if row.start_with?('> ')
          row
        end

        def step(c, state, &block)
          case c
          when '<'
            state[:depth] += 1
            state[:has_xml] = true
            state[:xml] << c
          when '>' then close_bracket(c, state, &block)
          when '/' then slash(c, state)
          when '&'
            (state[:entity] ||= +'') << c
          when ';' then semicolon(c, state)
          when GSL then nil
          else other(c, state)
          end
        end

        def close_bracket(c, state)
          if state[:prev] == '/'
            state[:depth] -= 1
          elsif state[:end_tag]
            state[:depth] -= 2
            state[:end_tag] = false
          end
          state[:xml] << c
          return unless state[:depth].zero?

          @carry << state[:xml]
          flush_text(state) { |kind, payload| yield kind, payload }
          yield :xml, @carry.dup
          @carry = +''
          state[:xml] = +''
        end

        def slash(c, state)
          state[:end_tag] = true if state[:prev] == '<'
          if state[:depth].positive?
            state[:xml] << c
          else
            state[:text] << c
          end
        end

        def semicolon(c, state)
          return unless state[:entity] # a ';' outside an entity is dropped

          state[:entity] << c
          if state[:depth].positive?
            state[:xml] << state[:entity]
          else
            state[:text] << HTML_CHARS.fetch(state[:entity], '')
          end
          state[:entity] = nil
        end

        def other(c, state)
          if state[:entity]
            state[:entity] << c
            return unless state[:entity].length > 6 # abort

            if state[:depth].positive?
              state[:xml] << state[:entity].gsub('&', '&amp;')
            else
              state[:text] << state[:entity]
            end
            state[:entity] = nil
          elsif state[:depth].positive?
            state[:xml] << c
          else
            state[:text] << c
          end
        end

        def flush_text(state)
          return if state[:text].empty?

          yield :text, state[:text]
          state[:text] = +''
        end

        # Row end (Game.cs:833-850 R): an open element replaces the carry (it does not
        # append to it); a closed remainder is processed.
        def finish_row(state)
          unless state[:xml].empty?
            if state[:depth].positive?
              @carry = state[:xml]
            else
              @carry << state[:xml]
              flush_text(state) { |kind, payload| yield kind, payload }
              yield :xml_end, @carry.dup
              @carry = +''
            end
          end
          flush_text(state) { |kind, payload| yield kind, payload }
        end
      end
    end
  end
end
