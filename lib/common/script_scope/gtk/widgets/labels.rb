# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Label < Widget
          # Retains explicit font choices as the baseline beneath temporary markup fonts.
          # @param font [Pango::FontDescription] bounded generic-family typography
          # @return [Label] self
          def override_font(font)
            session.synchronize do
              super
              @explicit_font_emphasis = font.weight == :bold ? :strong : :normal
              @markup_font_baseline&.each_key do |property|
                next unless font.properties.key?(property)

                @markup_font_baseline[property] = @props.fetch(property, Lich::WebUI::Adapter::UNSET)
              end
            end
            self
          end

          # A linked label's existing anchor supplies its keyboard focus target.
          # Plain focusable labels still require an unsupported interaction model.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [void] result is not part of the supported script contract
          def can_focus=(value)
            super unless @link_markup && value == true
          end
          alias set_can_focus can_focus=

          # Creates centered, nonwrapping literal text with GTK-compatible empty defaults.
          # @param text [Object] initial text, converted to a literal string
          def initialize(text = '')
            super()
            @props.merge!(content: text.to_s, align: :center, wrap: false)
          end

          # Reads the retained literal label content.
          # @return [String]
          def text = read(:content)

          # A literal, unwrapped single line uses browser font metrics. Native
          # Pango paragraph markers and multiline single-line-mode are outside
          # this bridge; refuse them instead of dropping or replacing text.
          # @param value [Boolean] single-line metric request
          # @return [Label] self
          def set_single_line_mode(value)
            session.refuse(self, :single_line_mode=) unless [true, false].include?(value)
            session.refuse(self, :single_line_mode=) if value && (@link_markup || @props[:wrap] || read(:content).match?(/[\r\n]|\p{Zl}|\p{Zp}/))
            @single_line_mode = value
            session.degrade(:single_line_metrics, 'single-line labels use browser font metrics') if value
            self
          end
          alias single_line_mode= set_single_line_mode

          # Writes literal label content through the shared text control.
          # @param value [Object] literal text converted with String before publication
          # @return [Label] self
          def text=(value)
            if @use_markup
              set_markup(String(value))
            else
              write(:content, String(value))
            end
          end
          alias set_text text=
          alias label= text=
          alias label text

          # Maps unit-interval fractions to start/center/end content alignment.
          # Independent setters preserve the other axis regardless of XML order.
          # @param horizontal [Numeric] horizontal content fraction, 0..1
          # @param vertical [Numeric] vertical content fraction, 0..1
          # @return [Label] self
          def set_alignment(horizontal, vertical)
            session.refuse(self, :set_alignment) unless [horizontal, vertical].all? { |value| value.is_a?(Numeric) && value.between?(0, 1) }
            self.xalign = horizontal
            self.yalign = vertical
            self
          end

          # Maps a horizontal alignment fraction to the shared presentation.
          # @param value [Numeric] horizontal content alignment, 0..1
          # @return [void] result is not part of the supported script contract
          def xalign=(value)
            session.refuse(self, :xalign=) unless value.is_a?(Numeric) && value.between?(0, 1)
            write(:align, value.zero? ? :start : (value == 1 ? :end : :center))
          end
          alias set_xalign xalign=

          # Maps a vertical alignment fraction to the shared presentation.
          # @param value [Numeric] vertical content alignment, 0..1
          # @return [void] result is not part of the supported script contract
          def yalign=(value)
            session.refuse(self, :yalign=) unless !@link_markup && value.is_a?(Numeric) && value.between?(0, 1)
            write(:content_vertical_align, value.zero? ? :start : (value == 1 ? :end : :center))
          end
          alias set_yalign yalign=

          # Quarter-turns retain literal text and participate in natural sizing.
          # Arbitrary angles and linked Markdown labels remain unsupported.
          # @param value [Numeric] counterclockwise degrees: 0, 90, 180 or 270
          # @return [void] result is not part of the supported script contract
          def angle=(value)
            session.refuse(self, :angle=) unless !@link_markup && [0, 90, 180, 270].include?(value)
            write(:rotation, value.to_i.to_s)
          end
          alias set_angle angle=

          # Validates selectability and reports that browser text remains selectable.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [Label] self
          def set_selectable(value)
            session.refuse(self, :set_selectable) unless [true, false].include?(value)
            session.degrade(:text_selection, 'browser text remains selectable') unless value
            self
          end

          alias selectable= set_selectable

          # Translates the measured markup subset into literal text and bounded emphasis/color.
          # Unknown tags are refused; source markup is never forwarded as browser HTML.
          # @param value [String] bounded markup translated to safe typed presentation
          # @return [Label] self
          # @raise [UnsupportedOperation] for unsupported tags
          def set_markup(value)
            session.refuse(self, :set_markup) unless value.is_a?(String)
            value = value.dup.force_encoding(Encoding::UTF_8)
            session.refuse(self, :set_markup) unless value.valid_encoding? && value.length <= Lich::WebUI::Contract::BOUNDS[:display_text]
            return set_link_markup(value) if value.include?('<a ') || @link_markup
            # Merchantical's located-item cue colors one entire literal label.
            # Reuse the shared background property, not raw HTML or fragment CSS.
            if (background = value.match(/\A<span background=(['"])([^'"<>]*)\1>([^<>]*)<\/span>\z/m))
              color = Color.parse_markup(background[2])
              session.refuse(self, :set_markup) unless color
              replace_markup_font(background: color)
              write(:font_style, :normal)
              return write(:content, CGI.unescapeHTML(background[3]))
            end
            if (italic = value.match(/\A<i>([^<>]*)<\/i>\z/m))
              text = italic[1].dup.force_encoding(Encoding::UTF_8)
              session.refuse(self, :set_markup) unless text.valid_encoding?
              replace_markup_font({})
              write(:font_style, :italic)
              return write(:content, CGI.unescapeHTML(text))
            end
            if value.include?('<i>') || value.include?('<u>') || value.include?('<small>') || value.match?(/<span\b[^>]*\bforeground=/) || value.match?(/<span\b[^>]*\bsize=['"][a-z-]+['"]/)
              return set_styled_markup(value)
            end
            if (sized_span = value.match(/\A<span size=(['"])([0-9]{1,6})\1>([^<>]*)<\/span>\z/m))
              points = sized_span[2].to_i / 1024.0
              session.refuse(self, :set_markup) unless points.between?(6, 96)
              text = sized_span[3].dup.force_encoding(Encoding::UTF_8)
              session.refuse(self, :set_markup) unless text.valid_encoding?
              replace_markup_font(font_size: points, font_unit: :pt)
              write(:font_style, :normal)
              return write(:content, CGI.unescapeHTML(text))
            end
            if (monospace = value.match(/\A<tt>([^<>]*)<\/tt>\z/m))
              replace_markup_font(font_family: 'monospace')
              write(:font_style, :normal)
              return write(:content, CGI.unescapeHTML(monospace[1]))
            end
            if (font_span = value.match(/\A\s*<span font_family="(monospace|sans-serif|serif)">([^<>]*)<\/span>\s*\z/m))
              replace_markup_font(font_family: font_span[1])
              write(:font_style, :normal)
              return write(:content, CGI.unescapeHTML(font_span[2]))
            end
            # Boon's measured blue bold tip maps to literal text and the native
            # bounded color record. Source markup never reaches the browser.
            if (tip = value.match(/\A<span color="blue" weight="bold">([^<>]*)<\/span>\z/m))
              replace_markup_font(foreground: Color.parse('blue'))
              write(:emphasis, :strong)
              write(:font_style, :normal)
              return write(:content, CGI.unescapeHTML(tip[1]))
            end
            # Other measured headings use only b/big wrappers. Unknown markup
            # fails at its source call rather than reaching the browser.
            tags = value.scan(/<[^>]*>/)
            # armor's charts use literal spans with colour and font metadata.
            # Preserve every character; never pass markup or CSS to the client.
            span = /\A<span(?: (?:color=(?:'[^'<>]*'|"[^"<>]*")|font_desc=(?:'[^'<>]*'|"[^"<>]*")))+>\z/
            session.refuse(self, :set_markup) if tags.any? { |tag| !%w[<b> <big> </b> </big> </span>].include?(tag) && !span.match?(tag) }
            replace_markup_font({})
            session.degrade(:markup_style, 'chart colours and font faces follow browser theme; chart text is retained') if tags.any? { |tag| tag.start_with?('<span') }
            write(:emphasis, value.include?('<b>') ? :strong : (@explicit_font_emphasis || :normal))
            write(:font_style, :normal)
            write(:content, CGI.unescapeHTML(value.gsub(/<[^>]*>/, '')))
          end
          alias markup= set_markup

          # Preserves mixed emphasis, italic and foreground spans using typed fragments.
          # Parsing completes before any live or shadow label state changes.
          # @param value [String] bounded markup translated to safe typed presentation
          # @return [Label] self
          # @api private
          def set_styled_markup(value)
            fragments = LabelMarkup.new(self).parse(value)
            content = fragments.map { |fragment| fragment[:content] }.join
            session.refuse(self, :set_markup) if @props[:ellipsize] == :middle
            session.refuse(self, :single_line_mode) if @single_line_mode && content.match?(/[\r\n]|\p{Zl}|\p{Zp}/)
            session.synchronize do
              replace_markup_font({})
              write(:font_style, :normal)
              write(:content, content)
              write(:fragments, fragments)
            end
            self
          end
          private :set_styled_markup

          # Builder markup uses the same bounded formatter as direct Label calls.
          # @param value [Boolean] enable markup before materialization
          # @return [void] result is not part of the supported script contract
          def use_markup=(value)
            session.refuse(self, :use_markup=) unless [true, false].include?(value) && !@handle && (value || !@link_markup)
            @use_markup = value
            set_markup(read(:content)) if value
          end
          alias set_use_markup use_markup=

          # Only literal text and HTTP(S) anchors with optional literal titles become typed Markdown.
          # Unsupported markup is refused, never passed to innerHTML or stripped.
          # @param value [String] bounded markup translated to safe typed presentation
          # @return [Label] self
          def set_link_markup(value)
            session.refuse(self, :set_markup) if @single_line_mode || @props.keys.intersect?(%i[rotation padding_x padding_y content_vertical_align line_justify max_width_chars ellipsize])
            session.refuse(self, :set_markup) if @handle && !@link_markup
            document = REXML::Document.new("<label>#{value}</label>")
            content = document.root.children.map do |part|
              if part.is_a?(REXML::Text)
                text = part.value
                session.refuse(self, :set_markup) if text.match?(/[\[\]]/)
                text
              elsif part.is_a?(REXML::Element)
                valid = part.name == 'a' && part.attributes.key?('href') && (part.attributes.keys - %w[href title]).empty? && part.children.all? { |child| child.is_a?(REXML::Text) }
                session.refuse(self, :set_markup) unless valid
                href, label = part.attributes['href'], part.texts.map(&:value).join
                uri = URI.parse(href)
                valid = %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo && !href.match?(/[\s<>]/) && !label.match?(/[\[\]]/)
                session.refuse(self, :set_markup) unless valid
                title = part.attributes['title']
                suffix = title ? ' "' + title.gsub(/["\\]/) { |character| "\\#{character}" } + '"' : ''
                "[#{label}](#{href.gsub('(', '%28').gsub(')', '%29')}#{suffix})"
              else
                session.refuse(self, :set_markup)
              end
            end.join
            @link_markup = true
            write(:content, content)
          rescue REXML::ParseException, URI::InvalidURIError
            session.refuse(self, :set_markup)
          end

          # Sets the shared text wrapping property.
          # @param value [Boolean] whether text wraps within its allocation
          # @return [Label] self
          def set_wrap(value) = write(:wrap, value)
          alias wrap= set_wrap
          alias set_line_wrap set_wrap
          alias line_wrap= set_wrap

          # Maps the supported Pango word/none wrapping modes to typed text wrap.
          # @param value [Symbol] supported GTK presentation or behavior token
          # @return [Label] self
          def set_wrap_mode(value)
            session.refuse(self, :wrap_mode=) unless %i[word none].include?(value)
            set_wrap(value == :word)
          end
          alias wrap_mode= set_wrap_mode
          alias set_line_wrap_mode set_wrap_mode
          alias line_wrap_mode= set_wrap_mode

          # Bounds visible wrapped lines; -1 retains the full label text.
          # @param value [Integer] -1 or 1..1024 visible lines
          # @return [Label] self
          def lines=(value)
            session.refuse(self, :lines=) unless value.is_a?(Integer) && (value == -1 || value.between?(1, 1024))
            write(:line_limit, value)
          end
          alias set_lines lines=

          # Justifies lines inside the label's text block, independently of
          # widget placement and xalign. A single line does not move the label.
          # Full justification and linked Markdown labels remain unsupported.
          # @param value [Symbol] :left, :center or :right
          # @return [void] result is not part of the supported script contract
          def justify=(value)
            session.refuse(self, :justify=) unless !@link_markup && %i[left center right].include?(value)
            write(:line_justify, value)
          end
          alias set_justify justify=

          # Text padding belongs inside the label and never overwrites margins.
          # @param x [Integer] left/right inset, 0..64
          # @param y [Integer] top/bottom inset, 0..64
          # @return [Label] self
          def set_padding(x, y)
            session.refuse(self, :set_padding) unless [x, y].all? { |value| value.is_a?(Integer) && value.between?(0, 64) }
            self.xpad = x
            self.ypad = y
            self
          end

          # Sets the horizontal text inset independently of widget margins.
          # @param value [Integer] horizontal padding, 0..64
          # @return [void] result is not part of the supported script contract
          def xpad=(value)
            session.refuse(self, :xpad=) unless !@link_markup && value.is_a?(Integer) && value.between?(0, 64)
            write(:padding_x, value)
          end

          # Sets the vertical text inset independently of widget margins.
          # @param value [Integer] vertical padding, 0..64
          # @return [void] result is not part of the supported script contract
          def ypad=(value)
            session.refuse(self, :ypad=) unless !@link_markup && value.is_a?(Integer) && value.between?(0, 64)
            write(:padding_y, value)
          end

          # Requests a minimum character width using the existing browser-font metric.
          # Packing may still allocate a larger width. Resetting a published property
          # requires a separate contract operation and is not accepted here.
          # @param count [Integer] 1..1024
          # @return [Label] self
          def set_width_chars(count)
            session.refuse(self, :set_width_chars) unless count.is_a?(Integer) && count.between?(1, 1024)
            write(:min_width_chars, count)
          end
          alias width_chars= set_width_chars

          # Caps natural label width using the core's existing character metric.
          # @param count [Integer] 1..1024; reset requests remain unsupported
          # @return [Label] self
          def set_max_width_chars(count)
            session.refuse(self, :set_max_width_chars) unless !@link_markup && count.is_a?(Integer) && count.between?(1, 1024)
            write(:max_width_chars, count)
          end
          alias max_width_chars= set_max_width_chars

          # End ellipsis preserves full literal content for accessibility and reads.
          # @param mode [Symbol] only :end is accepted by this label facade
          # @return [Label] self
          def set_ellipsize(mode)
            session.refuse(self, :set_ellipsize) unless !@link_markup && mode == :end
            write(:ellipsize, mode)
          end
          alias ellipsize= set_ellipsize

          protected

          # Exposes only the effective foreground used by Notebook's header projection.
          # @return [Hash] independent field map; link presentation may omit the field
          # @api private
          def header_presentation = component_props.slice(:foreground)

          # Reports whether a caption contains typed fragment styling.
          # @return [Boolean] whether a caption would omit typed fragment styling
          # @api private
          def caption_fragments? = !!@props[:fragments]

          # Applies a typed foreground cue, restoring authored/default color when
          # the matching class or provider disappears. Literal content is unchanged.
          # @param color [Hash, nil] typed foreground override; nil restores authored color
          # @return [void] result is not part of the supported script contract
          # @api private
          def apply_label_color(color)
            return if @link_markup
            before = @label_color || @props[:foreground]
            after = color || @props[:foreground]
            if @handle && !destroyed? && before != after
              session.port.set(@handle, :foreground, after || Lich::WebUI::Adapter::UNSET)
            end
            @label_color = color
          end

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = @link_markup ? :markdown : :text

          # Restores only properties owned by the previous markup, then applies
          # the next bounded font span. Explicit overrides remain the baseline.
          # @param properties [Hash] validated font properties for this markup
          # @return [void]
          # @api private
          def replace_markup_font(properties)
            session.synchronize do
              write(:emphasis, @explicit_font_emphasis || :normal)
              (@markup_font_baseline || {}).each do |property, baseline|
                if baseline.equal?(Lich::WebUI::Adapter::UNSET)
                  if @handle && !destroyed?
                    session.with_widget(self) { session.port.set(@handle, property, baseline) }
                  end
                  @props.delete(property)
                else
                  write(property, baseline)
                end
              end
              @markup_font_baseline = {}
              properties.each do |property, value|
                @markup_font_baseline[property] = @props.fetch(property, Lich::WebUI::Adapter::UNSET)
                write(property, value)
              end
            end
          end
          private :replace_markup_font

          # Preserve the declared single-line boundary on later text/markup writes.
          # @param property [Symbol] shared shadow or port property name
          # @param value [Object] property value accepted by the shared control contract
          # @return [Label] self
          # @api private
          def write(property, value)
            if @single_line_mode && ((property == :content && value.match?(/[\r\n]|\p{Zl}|\p{Zp}/)) || (property == :wrap && value))
              session.refuse(self, :single_line_mode)
            end
            session.synchronize do
              result = super
              if property == :content && @props.key?(:fragments)
                session.with_widget(self) { session.port.set(@handle, :fragments, Lich::WebUI::Adapter::UNSET) } if @handle && !destroyed?
                @props.delete(:fragments)
              end
              result
            end
          end

          # Combines shadow properties with the current shared presentation.
          # @return [Hash] shared presentation properties
          # @api private
          def component_props
            props = super
            props = props.merge(foreground: @label_color) if @label_color
            @link_markup ? props.slice(:content, :key, :hidden, :disabled, :align, :margin, :width) : props
          end
        end

        # Uses the existing literal HTTP(S) anchor projection with real sensitivity.
        class LinkButton < Label
          attr_reader :uri

          # Creates a validated link with a literal destination and optional caption.
          # @param uri [String] destination accepted by the existing label-link policy
          # @param label [String] literal link caption
          def initialize(uri, label = uri)
            super('')
            replace_link(uri, label)
          end

          # URI and caption update together; invalid replacements leave both unchanged.
          # @param value [String] bounded HTTP(S) destination
          # @return [LinkButton] self
          def uri=(value)
            replace_link(value, @link_label)
          end
          alias set_uri uri=

          # Reads retained literal caption text.
          # @return [String] literal caption
          def label = @link_label

          # Replaces literal caption text through the existing control contract.
          # @param value [String] replacement literal caption
          # @return [LinkButton] self
          def label=(value)
            replace_link(@uri, value)
          end
          alias set_label label=

          private

          # Validates a bounded HTTP(S) destination before replacing link content.
          # @param uri [String] bounded HTTP(S) destination
          # @param label [String, nil] literal link caption; nil uses the destination
          # @return [LinkButton] self
          # @api private
          def replace_link(uri, label)
            valid = [uri, label].all? { |value| value.is_a?(String) && value.valid_encoding? && value.encoding.ascii_compatible? }
            session.refuse(self, :link) unless valid
            session.synchronize do
              set_markup("<a href=\"#{CGI.escapeHTML(uri)}\">#{CGI.escapeHTML(label)}</a>")
              @uri, @link_label = uri.dup.freeze, label.dup.freeze
            end
            self
          end
        end
      end
    end
  end
end
