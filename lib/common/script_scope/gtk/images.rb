# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # File-backed display values, not decoded or mutable pixel buffers.
        class FileImage
          attr_reader :session, :source, :width, :height

          # Only format identity is exposed; no native decoder/format object is loaded.
          Format = Data.define(:name)

          # Resolves and authorizes the file before reading any image bytes.
          # @param path [String] local filename subject to the existing file-root policy
          # @return [Array<Format, Integer, Integer>] format name descriptor, width, height
          # @raise [UnsupportedOperation] for invalid arguments or filesystem resolution
          # @raise [Lich::WebUI::Error] for refused roots
          # @raise [ArgumentError] for unsupported, truncated, or oversized headers
          def self.get_file_info(path)
            session = Gtk.session
            session.refuse(self, :get_file_info) unless path.is_a?(String)
            begin
              real = File.realpath(path)
            rescue SystemCallError
              session.refuse(self, :file)
            end
            session.image_source(real)
            info = Lich::WebUI::ImageSize.info(real)
            [Format.new(name: info.format), info.width, info.height].freeze
          end

          # Reads supported image headers after the existing file-root policy accepts them.
          # Width/height specify display bounds; aspect ratio is preserved by default.
          # @param path [String, nil] legacy positional filename
          # @param file [String, nil] filename keyword
          # @param width [Integer, nil] requested width
          # @param height [Integer, nil] requested height
          # @param preserve_aspect_ratio [Boolean] fit within requested bounds
          # @raise [UnsupportedOperation] for invalid arguments, dimensions or filesystem resolution
          # @raise [Lich::WebUI::Error] when the existing file-root policy refuses the source
          # @raise [ArgumentError] for unsupported or malformed image headers
          def initialize(path = nil, file: path, width: nil, height: nil, preserve_aspect_ratio: true)
            @session = Gtk.session
            session.refuse(self, :new) unless file.is_a?(String) && [true, false].include?(preserve_aspect_ratio)
            begin
              real = File.realpath(file)
            rescue SystemCallError
              session.refuse(self, :file)
            end
            @source = session.image_source(real).freeze
            original_width, original_height = Lich::WebUI::ImageSize.read(real)
            [width, height].compact.each { |number| dimension!(number) }
            @width, @height = width || original_width, height || original_height
            if preserve_aspect_ratio && (width || height)
              ratios = []
              ratios << width.fdiv(original_width) if width
              ratios << height.fdiv(original_height) if height
              ratio = ratios.min
              @width = [(original_width * ratio).round, 1].max
              @height = [(original_height * ratio).round, 1].max
            end
            dimension!(@width)
            dimension!(@height)
            freeze
          end

          # Returns a new display-size value. Browser interpolation is explicit;
          # this operation never creates resampled pixels or a writable image.
          # @param width [Integer, Float] display width, 1..65,536; fractions truncate
          # @param height [Integer, Float] display height, 1..65,536; fractions truncate
          # @param interpolation [Symbol] only :bilinear is accepted as a browser hint
          # @return [FileImage]
          def scale_simple(width, height, interpolation = :bilinear)
            width, height = [width, height].map { |value| scale_dimension(value) }
            session.refuse(self, :scale_simple) unless interpolation == :bilinear
            scaled = dup
            scaled.instance_variable_set(:@width, width)
            scaled.instance_variable_set(:@height, height)
            scaled.freeze
          end
          alias scale scale_simple

          # Unsupported pixel/drawing/export operations never fall through to native code.
          def method_missing(name, *, **, &)
            session.refuse(self, name)
          end

          # Native pixel operations remain absent from capability introspection.
          def respond_to_missing?(*args) = super

          private

          # Matches native integer display dimensions without admitting NaN or coercions.
          def scale_dimension(value)
            valid = value.is_a?(Integer) || (value.is_a?(Float) && value.finite?)
            session.refuse(self, :dimensions) unless valid && value.between?(1, 65_536)
            value.to_i
          end

          # Enforces the shared image-size bound before retaining a display dimension.
          # @raise [UnsupportedOperation] for noninteger, zero or excessive dimensions
          def dimension!(value)
            session.refuse(self, :dimensions) unless value.is_a?(Integer) && value.between?(1, 65_536)
          end
        end

        # An empty image is legitimate state; clearing removes the source request.
        module IconSize
          SMALL_TOOLBAR = :small_toolbar
          BUTTON = :button
        end

        class Image < Widget
          attr_reader :directional_caption

          # Creates an empty image or one source; conflicting source forms refuse.
          # @param source [String, FileImage, nil] legacy positional file or display value
          # @param file [String, nil] file resolved through the authenticated file service
          # @param pixbuf [FileImage, nil] immutable same-session display value
          def initialize(source = nil, file: nil, pixbuf: nil, icon_name: nil, icon_size: nil)
            super()
            if icon_name
              direction = { 'go-up' => 'Up', 'go-down' => 'Down' }[icon_name]
              palette = icon_name == 'preferences-desktop-color-symbolic' && icon_size == IconSize::SMALL_TOOLBAR
              session.refuse(self, :icon_name) unless (palette || (direction && icon_size == IconSize::BUTTON)) && [source, file, pixbuf].all?(&:nil?)
              @symbolic_icon = true
              @directional_caption = direction&.freeze
              caption = direction || 'Palette'
              @props.merge!(content: caption, wrap: false, a11y_label: caption)
              if direction
                session.degrade(:direction_icon, 'directional symbolic icons use literal Up/Down captions')
              else
                session.degrade(:palette_icon, 'symbolic palette icon uses an ASCII Palette caption')
              end
              return
            end
            session.refuse(self, :icon_size) unless icon_size.nil?
            session.refuse(self, :new) if [source, file, pixbuf].compact.length > 1
            @props[:src] = ''
            source ||= file || pixbuf
            source.is_a?(String) ? set_from_file(source) : set_pixbuf(source) if source
          end

          # Replaces the image using the bounded file-backed compatibility value.
          # @param value [FileImage, nil] same-session value; nil clears the image
          # @return [Image] self
          def set_pixbuf(value)
            return clear if value.nil?
            session.refuse(self, :set_pixbuf) unless value.is_a?(FileImage) && value.session.equal?(session)
            session.synchronize do
              write(:width, value.width)
              write(:height, value.height)
              write(:src, value.source)
              @pixbuf = value
            end
            self
          end
          alias pixbuf= set_pixbuf
          alias set_from_pixbuf set_pixbuf
          attr_reader :pixbuf

          # Resolves a supported file through the existing authenticated route service.
          # @param path [String] local path subject to the existing file-root policy
          # @return [Image] self
          def set_from_file(path) = set_pixbuf(FileImage.new(file: path))
          alias file= set_from_file

          # Clears visible pixels and retained source without unregistering other images.
          # @return [Image] self; the next render omits a source request
          def clear
            write(:src, '')
            @pixbuf = nil
            self
          end

          # The renderer already recomputes image layout on source/dimension changes.
          # @return [Image] self; no extra resize queue is created
          def queue_resize = self

          protected

          # @return [Symbol] existing file-backed image component
          def component_type = @symbolic_icon ? :text : :image
        end
      end

      module GdkPixbuf
        Pixbuf = Gtk::FileImage
        module InterpType
          BILINEAR = :bilinear
        end

        # Refuses native loaders and pixel utilities instead of loading GdkPixbuf.
        # @raise [Gtk::UnsupportedOperation] always
        def self.const_missing(name)
          Gtk.session.refuse(self, name)
        end
      end

      module Gdk
        Pixbuf = Gtk::FileImage
        InterpType = GdkPixbuf::InterpType
      end
    end
  end
end
