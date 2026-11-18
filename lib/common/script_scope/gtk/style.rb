# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Only the normal-state foreground override is projected by this facade.
        module StateFlags
          NORMAL = :normal

          # @raise [UnsupportedOperation] for unimplemented native state combinations
          def self.const_missing(name) = Gtk.session.refuse(self, name)
        end

        STATE_NORMAL = StateFlags::NORMAL

        module StyleProvider
          PRIORITY_APPLICATION = 600
          PRIORITY_USER = 800
        end

        class Settings
          # Returns a lightweight preference facade; no native GTK settings object exists.
          # @return [Settings]
          def self.default = new

          # Native theme names cannot select browser themes. Retain host styling
          # and report the omission; unknown settings remain explicit refusals.
          # @param name [String] only gtk-theme-name
          # @param value [String] bounded native theme name
          def set_property(name, value)
            session = Gtk.session
            session.refuse(self, :set_property) unless name == 'gtk-theme-name' && value.is_a?(String) && value.ascii_only? && value.length.between?(1, 128)
            session.degrade(:native_theme, 'native GTK theme names are omitted; browser uses the application theme')
            self
          end

          # Reports the same preference as native pages so scripts can choose
          # their original light/dark palettes without GTK runtime dependencies.
          # @return [Boolean] whether the application prefers the dark theme
          def gtk_application_prefer_dark_theme?
            Lich::WebUI::Theme.current == :dark
          end
        end

        # Preserve measured progress declarations and bounded label foreground cues.
        # The browser receives bounded color/geometry values, never source CSS.
        class CssProvider
          attr_reader :session, :fill_color, :state, :label_rules

          # Captures the creating owner; retained providers cannot cross sessions.
          def initialize
            @session = Gtk.session
            @contexts = Lich::WebUI::WeakIdentityMap.new
            @state = :unloaded
            @label_rules = []
          end

          # Recognizes bounded progress/label styling; omitted decoration gets a notice.
          # Omitted CSS is inert and is not retained, parsed further or sent to the renderer.
          # @param data [String] stylesheet, at most 8,192 characters
          # @return [Boolean] true on recognized or omitted decoration
          # @raise [UnsupportedOperation] for invalid input or owner/lifetime violations
          def load(data:)
            session.style_operation(self, :load) do
              valid = data.is_a?(String) && data.valid_encoding? && data.encoding.ascii_compatible? && data.length <= 8192
              session.refuse(self, :load) unless valid
              match = data.match(/\Alabel\s*\{\s*font-weight:\s*bold;\s*\}\s*trough\s*\{\s*font-weight:\s*bold;\s*min-height:\s*22px;\s*\}\s*progress\s*\{\s*font-weight:\s*bold;\s*min-height:\s*20px;\s*background-image:\s*none;\s*background-color:\s*(#[0-9a-fA-F]{6}|[a-z]+)\s*;?\s*\}\z/)
              color = Color.parse(match[1]) if match
              @label_rules = parse_label_rules(data)
              @fill_color = color
              @state = color || !@label_rules.empty? ? :recognized : :omitted
              session.omit_css(self) unless color
              @contexts.each_key { |context| context.send(:refresh) }
              session.refresh_label_styles
              true
            end
          end

          # Positional GTK spelling; shares validation and reload notification.
          # @param data [String] bounded stylesheet
          # @return [Boolean] true on successful load
          def load_from_data(data)
            load(data: data)
          end

          # Reports a completed load, including explicitly omitted decoration.
          # @return [Boolean]
          def loaded? = @state != :unloaded

          # Refuses style APIs outside the bounded compatibility surface.
          # @raise [UnsupportedOperation] always
          def method_missing(name, *, **, &)
            session.refuse(self, name)
          end

          # Keeps unsupported methods absent from reflection.
          def respond_to_missing?(*args) = super

          private

          # Only class-qualified label foreground cues are translated. Other
          # selectors/declarations remain omitted, including URLs and functions.
          # Rules are flat and bounded by the provider's existing input limit.
          def parse_label_rules(data)
            clean = data.gsub(%r{/\*.*?\*/}m, '')
            return [] unless clean.gsub(/[^{}]+\{[^{}]*\}/, '').strip.empty?
            clean.scan(/([^{}]+)\{([^{}]*)\}/).flat_map do |selectors, body|
              declarations = body.split(';').filter_map do |declaration|
                match = declaration.strip.match(/\Acolor\s*:\s*(#[0-9a-fA-F]{6}|[a-z]+)\z/)
                Color.parse(match[1]) if match
              end
              next [] if declarations.empty?
              selectors.split(',').filter_map do |selector|
                tokens = selector.strip.split(/\s+/)
                next unless tokens.last&.match?(/\Alabel\.[a-zA-Z_][\w-]*\z/)
                next unless tokens[0...-1].all? { |token| token.match?(/\A(?:#[a-zA-Z_][\w-]*|[a-zA-Z][\w-]*)\z/) }
                { ancestors: tokens[0...-1].freeze, class: tokens.last.delete_prefix('label.').freeze,
                  color: declarations.last, specificity: [tokens.count { |token| token.start_with?('#') }, 1, tokens.count { |token| !token.start_with?('#') }] }.freeze
              end
            end.freeze
          end

          def attach(context)
            @contexts[context] = true
          end

          def detach(context)
            @contexts.delete(context)
          end
        end

        class StyleContext
          # Records an owner-scoped screen provider for bounded label foreground cues.
          # @return [nil]
          def self.add_provider_for_screen(screen, provider, priority = StyleProvider::PRIORITY_APPLICATION)
            session = Gtk.session
            session.screen_style_operation(self, :add_provider_for_screen, screen, provider) do |providers|
              valid = priority.is_a?(Integer) && [StyleProvider::PRIORITY_APPLICATION, StyleProvider::PRIORITY_USER].include?(priority)
              session.refuse(self, :add_provider_for_screen) unless valid && (providers.key?(provider) || providers.size < 64)
              providers.delete(provider)
              providers[provider] = priority
              session.refresh_label_styles
              session.omit_css(self)
            end
            nil
          end

          # Removes an owner-scoped attachment; repeating removal is harmless.
          # @return [nil]
          def self.remove_provider_for_screen(screen, provider)
            Gtk.session.screen_style_operation(self, :remove_provider_for_screen, screen, provider) do |providers|
              providers.delete(provider)
              Gtk.session.refresh_label_styles
            end
            nil
          end

          # Refuses class APIs outside the explicit screen-provider surface.
          def self.method_missing(name, *, **, &)
            Gtk.session.refuse(self, name)
          end

          def self.respond_to_missing?(*args) = super

          # Binds the restricted style facade to its compatibility widget.
          def initialize(widget)
            @session = Gtk.session
            @session.refuse(self, :new) unless widget.is_a?(Widget) && widget.session.equal?(@session) && !widget.destroyed?
            @widget = widget
            @providers = {}.compare_by_identity
            @classes = {}
            @session.register_style_context(self)
          end

          # Attaches before or after load. Higher priority wins; the most recent
          # attachment breaks ties. Reattaching replaces the existing registration.
          # @param provider [CssProvider] provider from this owner
          # @param priority [Integer] APPLICATION (default) or USER
          # @return [StyleContext] self
          def add_provider(provider, priority = StyleProvider::PRIORITY_APPLICATION)
            operation(:add_provider) do
              validate_provider(provider, :add_provider)
              valid = priority.is_a?(Integer) && [StyleProvider::PRIORITY_APPLICATION, StyleProvider::PRIORITY_USER].include?(priority)
              @session.refuse(self, :add_provider) unless valid && (@providers.key?(provider) || @providers.size < 64)
              @providers.delete(provider)
              @providers[provider] = priority
              provider.send(:attach, self)
              @session.omit_css(self) unless @widget.is_a?(ProgressBar)
              refresh
            end
            self
          end

          # Retains up to 64 local class names, never DOM classes or CSS selectors.
          # @return [StyleContext] self
          def add_class(name)
            operation(:add_class) do
              validate_class(name, :add_class)
              @session.refuse(self, :add_class) unless @classes.key?(name) || @classes.size < 64
              @classes[name.dup.freeze] = true
              refresh
              @session.omit_css(self)
            end
            self
          end

          # Removes only this widget's metadata; an absent class is harmless.
          # @return [StyleContext] self
          def remove_class(name)
            operation(:remove_class) do
              validate_class(name, :remove_class)
              @classes.delete(name)
              refresh
            end
            self
          end

          # Queries bounded class metadata without applying any styling.
          # @return [Boolean]
          def has_class?(name)
            operation(:has_class?) do
              validate_class(name, :has_class?)
              @classes.key?(name)
            end
          end

          # Returns an independent snapshot of local class names.
          # @return [Array<String>]
          def list_classes
            operation(:list_classes) { @classes.keys.map(&:dup) }
          end

          # Removes only this context's registration; missing same-owner providers
          # are harmless. Remaining providers or authored/default values reappear.
          # @return [StyleContext] self
          def remove_provider(provider)
            operation(:remove_provider) do
              validate_provider(provider, :remove_provider)
              @providers.delete(provider)
              provider.send(:detach, self)
              refresh
            end
            self
          end

          # Unknown style behavior remains an attributed hard stop.
          # @raise [UnsupportedOperation] always
          def method_missing(name, *, **, &)
            @session.refuse(self, name)
          end

          # Keeps unsupported methods absent from reflection.
          def respond_to_missing?(*args) = super

          private

          def operation(name, &block)
            @session.style_operation(self, name) do
              @session.refuse(self, name) unless @widget && !@widget.destroyed?
              block.call
            end
          end

          def validate_provider(provider, operation)
            @session.refuse(self, operation) unless provider.is_a?(CssProvider) && provider.session.equal?(@session)
          end

          def validate_class(name, operation)
            valid = name.is_a?(String) && name.valid_encoding? && name.encoding.ascii_compatible? && name.length.between?(1, 512)
            @session.refuse(self, operation) unless valid
          end

          def refresh
            return unless @widget
            refresh_label if @widget.is_a?(Label)
            return unless @widget.is_a?(ProgressBar)

            candidates = @providers.each_with_index.select { |(provider, _priority), _index| provider.fill_color }
            selected = candidates.max_by { |(_provider, priority), index| [priority, index] }
            provider = selected&.first&.first
            # GTK's 22px trough content includes a one-pixel border on each side.
            @widget.send(:apply_progress_style, provider ? { fill_color: provider.fill_color, height: 24 } : {})
          end

          # Match script-local metadata only; no selector or class reaches DOM.
          def refresh_label
            candidates = []
            providers = @session.screen_style_providers.to_a + @providers.to_a
            providers.each_with_index do |(provider, priority), order|
              provider.label_rules.each_with_index do |rule, index|
                next unless @classes.key?(rule[:class]) && ancestors_match?(rule[:ancestors])
                candidates << [[priority, *rule[:specificity], order, index], rule[:color]]
              end
            end
            @widget.send(:apply_label_color, candidates.max_by(&:first)&.last)
          end

          def ancestors_match?(tokens)
            ancestor = @widget.parent
            tokens.reverse_each do |token|
              ancestor = ancestor.parent while ancestor && !(token.start_with?('#') ? ancestor.name == token.delete_prefix('#') : ancestor.class.name.split('::').last.downcase == token)
              return false unless ancestor
              ancestor = ancestor.parent
            end
            true
          end

          def close
            @session.synchronize do
              @providers.each_key { |provider| provider.send(:detach, self) }
              @providers.clear
              @classes.clear
              @widget = nil
              @session.forget_style_context(self)
            end
          end
        end

        # Named colors are the CSS set, matched without regard to case.
        # No browser CSS parsing, URLs, functions, or arbitrary style strings.
        module Color
          # Markup spans also use three-digit RGB literals; other color APIs
          # retain their existing accepted spellings.
          # @return [Hash, nil] bounded literal color, never CSS
          def self.parse_markup(value)
            value = '#' + value.delete_prefix('#').chars.map { |digit| digit * 2 }.join if value.match?(/\A#[0-9a-fA-F]{3}\z/)
            parse(value)
          end

          # CSS named colors, which Pango also accepts in markup.
          NAMES = {
            'aliceblue' => 'f0f8ff', 'antiquewhite' => 'faebd7', 'aqua' => '00ffff', 'aquamarine' => '7fffd4',
            'azure' => 'f0ffff', 'beige' => 'f5f5dc', 'bisque' => 'ffe4c4', 'black' => '000000', 'blanchedalmond' => 'ffebcd',
            'blue' => '0000ff', 'blueviolet' => '8a2be2', 'brown' => 'a52a2a', 'burlywood' => 'deb887', 'cadetblue' => '5f9ea0',
            'chartreuse' => '7fff00', 'chocolate' => 'd2691e', 'coral' => 'ff7f50', 'cornflowerblue' => '6495ed',
            'cornsilk' => 'fff8dc', 'crimson' => 'dc143c', 'cyan' => '00ffff', 'darkblue' => '00008b', 'darkcyan' => '008b8b',
            'darkgoldenrod' => 'b8860b', 'darkgray' => 'a9a9a9', 'darkgreen' => '006400', 'darkgrey' => 'a9a9a9',
            'darkkhaki' => 'bdb76b', 'darkmagenta' => '8b008b', 'darkolivegreen' => '556b2f', 'darkorange' => 'ff8c00',
            'darkorchid' => '9932cc', 'darkred' => '8b0000', 'darksalmon' => 'e9967a', 'darkseagreen' => '8fbc8f',
            'darkslateblue' => '483d8b', 'darkslategray' => '2f4f4f', 'darkslategrey' => '2f4f4f', 'darkturquoise' => '00ced1',
            'darkviolet' => '9400d3', 'deeppink' => 'ff1493', 'deepskyblue' => '00bfff', 'dimgray' => '696969',
            'dimgrey' => '696969', 'dodgerblue' => '1e90ff', 'firebrick' => 'b22222', 'floralwhite' => 'fffaf0',
            'forestgreen' => '228b22', 'fuchsia' => 'ff00ff', 'gainsboro' => 'dcdcdc', 'ghostwhite' => 'f8f8ff',
            'gold' => 'ffd700', 'goldenrod' => 'daa520', 'gray' => '808080', 'green' => '008000', 'greenyellow' => 'adff2f',
            'grey' => '808080', 'honeydew' => 'f0fff0', 'hotpink' => 'ff69b4', 'indianred' => 'cd5c5c', 'indigo' => '4b0082',
            'ivory' => 'fffff0', 'khaki' => 'f0e68c', 'lavender' => 'e6e6fa', 'lavenderblush' => 'fff0f5',
            'lawngreen' => '7cfc00', 'lemonchiffon' => 'fffacd', 'lightblue' => 'add8e6', 'lightcoral' => 'f08080',
            'lightcyan' => 'e0ffff', 'lightgoldenrodyellow' => 'fafad2', 'lightgray' => 'd3d3d3', 'lightgreen' => '90ee90',
            'lightgrey' => 'd3d3d3', 'lightpink' => 'ffb6c1', 'lightsalmon' => 'ffa07a', 'lightseagreen' => '20b2aa',
            'lightskyblue' => '87cefa', 'lightslategray' => '778899', 'lightslategrey' => '778899', 'lightsteelblue' => 'b0c4de',
            'lightyellow' => 'ffffe0', 'lime' => '00ff00', 'limegreen' => '32cd32', 'linen' => 'faf0e6', 'magenta' => 'ff00ff',
            'maroon' => '800000', 'mediumaquamarine' => '66cdaa', 'mediumblue' => '0000cd', 'mediumorchid' => 'ba55d3',
            'mediumpurple' => '9370db', 'mediumseagreen' => '3cb371', 'mediumslateblue' => '7b68ee',
            'mediumspringgreen' => '00fa9a', 'mediumturquoise' => '48d1cc', 'mediumvioletred' => 'c71585',
            'midnightblue' => '191970', 'mintcream' => 'f5fffa', 'mistyrose' => 'ffe4e1', 'moccasin' => 'ffe4b5',
            'navajowhite' => 'ffdead', 'navy' => '000080', 'oldlace' => 'fdf5e6', 'olive' => '808000', 'olivedrab' => '6b8e23',
            'orange' => 'ffa500', 'orangered' => 'ff4500', 'orchid' => 'da70d6', 'palegoldenrod' => 'eee8aa',
            'palegreen' => '98fb98', 'paleturquoise' => 'afeeee', 'palevioletred' => 'db7093', 'papayawhip' => 'ffefd5',
            'peachpuff' => 'ffdab9', 'peru' => 'cd853f', 'pink' => 'ffc0cb', 'plum' => 'dda0dd', 'powderblue' => 'b0e0e6',
            'purple' => '800080', 'rebeccapurple' => '663399', 'red' => 'ff0000', 'rosybrown' => 'bc8f8f',
            'royalblue' => '4169e1', 'saddlebrown' => '8b4513', 'salmon' => 'fa8072', 'sandybrown' => 'f4a460',
            'seagreen' => '2e8b57', 'seashell' => 'fff5ee', 'sienna' => 'a0522d', 'silver' => 'c0c0c0', 'skyblue' => '87ceeb',
            'slateblue' => '6a5acd', 'slategray' => '708090', 'slategrey' => '708090', 'snow' => 'fffafa',
            'springgreen' => '00ff7f', 'steelblue' => '4682b4', 'tan' => 'd2b48c', 'teal' => '008080', 'thistle' => 'd8bfd8',
            'tomato' => 'ff6347', 'turquoise' => '40e0d0', 'violet' => 'ee82ee', 'wheat' => 'f5deb3', 'white' => 'ffffff',
            'whitesmoke' => 'f5f5f5', 'yellow' => 'ffff00', 'yellowgreen' => '9acd32',
          }.freeze

          # Maps an allowed name or six-/twelve-digit RGB literal to numeric contract channels.
          # @return [Hash, nil] frozen RGBA record, or nil for an unsupported color
          def self.parse(value)
            hex = value.match?(/\A#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{12})\z/) ? value.delete_prefix('#') : NAMES[value.to_s.downcase]
            return unless hex

            width = hex.length / 3
            r, g, b = hex.scan(/.{#{width}}/).map { |channel| (channel.to_i(16) * 255.0 / (16**width - 1)).round }
            { r: r, g: g, b: b, a: 1.0 }.freeze
          end
        end
        private_constant :Color
      end

      module Gdk
        # Legacy opaque colors reuse the bounded literal parser and typed RGBA values.
        class Color
          # @param value [String] supported name or six-/twelve-digit RGB literal
          # @return [Color] immutable color token
          def self.parse(value)
            valid = value.is_a?(String) && value.valid_encoding? && value.ascii_only? && value.length <= 64
            parsed = Gtk.const_get(:Color, false).parse(value) if valid
            Gtk.session.refuse(self, :parse) unless parsed
            new(parsed)
          end

          # @api private
          def initialize(parsed)
            @rgba = RGBA.new(*%i[r g b].map { |key| parsed.fetch(key) / 255.0 }, 1.0)
            freeze
          end
          private_class_method :new

          # @return [RGBA] typed value for the existing background-color disposition
          def to_rgba = @rgba
        end

        # Utility windows remain ordinary owned WebUI pages; native classification is host-controlled.
        module WindowTypeHint
          UTILITY = :utility

          # @raise [Gtk::UnsupportedOperation] for unimplemented native window classes
          def self.const_missing(name) = Gtk.session.refuse(self, name)
        end

        # Colour values are validated locally and never interpreted as CSS.
        class RGBA
          # Validates four finite channels for bounded color overrides. GTK
          # clamps a channel outside 0..1 when it draws, so the record holds
          # the clamped value and the clamp is logged once.
          # The immutable record contains no native color state or source CSS.
          # @raise [UnsupportedOperation] for invalid channels
          def initialize(*channels)
            Gtk.session.refuse(self, :new) unless channels.length == 4 && channels.all? { |channel| channel.is_a?(Numeric) && channel.real? && channel.finite? }
            unless channels.all? { |channel| channel.between?(0, 1) }
              Gtk.session.degrade(:rgba_range, 'colour channels outside 0..1 are clamped, as GTK draws them')
              channels = channels.map { |channel| channel.clamp(0, 1) }
            end
            @rgba = %i[r g b a].zip(channels.each_with_index.map { |channel, i| i == 3 ? channel.to_f : (channel * 255).round }).to_h.freeze
          end

          # @return [Hash] immutable numeric RGBA record, never source CSS
          def to_h = @rgba

          # Accepts measured red/green names and bounded six-/twelve-digit RGB literals.
          # @return [RGBA]
          # @raise [UnsupportedOperation] for other values
          def self.parse(value)
            channels = { 'green' => [0, 1, 0, 1], 'red' => [1, 0, 0, 1] }[value]
            if value.is_a?(String) && value.match?(/\A#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{12})\z/)
              color = Gtk.const_get(:Color, false).parse(value)
              channels = %i[r g b].map { |key| color[key] / 255.0 } + [color[:a]]
            end
            Gtk.session.refuse(self, :parse) unless channels
            new(*channels)
          end
        end

        # Owner-bound screen facade; display_geometry supplies measured dimension hints.
        class Screen
          attr_reader :session

          # Captures the owner without querying an OS display until dimensions are read.
          def initialize
            @session = Gtk.session
          end

          # Returns an owner-bound token; geometry is not read by CSS attachment.
          # @return [Screen] initial-size hint provider
          def self.default = new
        end

        # Refuses GDK facilities outside the bounded compatibility constants.
        # @raise [Gtk::UnsupportedOperation] always
        def self.const_missing(name)
          Gtk.session.refuse(self, name)
        end
      end

      # These value objects translate measured style requests to contract tokens.
      # They do not load Pango or expose arbitrary browser CSS.
      module Pango
        class FontDescription
          WEIGHT_BOLD = :bold

          attr_reader :weight, :properties

          # Parses generic families and bounded point sizes without loading Pango.
          # @param description [String, nil] e.g. Monospace 10 or 12; nil keeps theme typography
          # @raise [Gtk::UnsupportedOperation] for descriptions outside this subset
          def initialize(description = nil)
            @weight = :normal
            @properties = {}.freeze
            return if description.nil?

            if description.is_a?(String) && description.length <= 512 && description.match?(/\A[0-9]+(?:\.[0-9]+)?\z/)
              size = description.to_f
              Gtk.session.refuse(self, :new) unless size.between?(6, 48)
              @properties = { font_size: size, font_unit: :pt }.freeze
              return
            end

            match = description.is_a?(String) && description.length <= 512 && description.match(/\A(Monospace|Sans|Serif) ([0-9]+(?:\.[0-9]+)?)\z/i)
            Gtk.session.refuse(self, :new) unless match && match[2].to_f.between?(6, 48)
            family = { 'monospace' => 'monospace', 'sans' => 'sans-serif', 'serif' => 'serif' }.fetch(match[1].downcase)
            @properties = { font_family: family, font_size: match[2].to_f, font_unit: :pt }.freeze
          end

          # Parses generic-family/size strings; other bounded names retain theme typography.
          # @return [FontDescription] parsed typography or normal-weight theme token
          # @raise [Gtk::UnsupportedOperation] for an invalid description
          def self.from_string(value)
            Gtk.session.refuse(self, :from_string) unless value.is_a?(String) && value.length.between?(1, 512)
            return new(value) if value.match?(/\A(?:(?:Monospace|Sans|Serif) )?[0-9]+(?:\.[0-9]+)?\z/i)

            Gtk.session.degrade(:font_face, 'unparsed font family and size follow browser theme')
            new
          end

          def weight=(value)
            Gtk.session.refuse(self, :weight=) unless %i[normal bold].include?(value)
            @weight = value
          end

          # Refuses font operations outside the supported typography token.
          # @raise [Gtk::UnsupportedOperation] always
          def method_missing(name, *, **, &)
            Gtk.session.refuse(self, name)
          end

          # Does not advertise native font methods beyond this compatibility object's implementation.
          # @return [Boolean]
          def respond_to_missing?(*args)
            super
          end
        end

        # Refuses unsupported Pango types without loading its native library.
        # @raise [Gtk::UnsupportedOperation] always
        def self.const_missing(name)
          Gtk.session.refuse(self, name)
        end
      end
    end
  end
end
